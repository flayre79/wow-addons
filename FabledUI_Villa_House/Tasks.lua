-- VillaHouse's endeavor task data: what each task will REALLY pay next.
--
-- Blizzard's Endeavors tab prints task.progressContributionAmount in the green
-- banner. That number never moves. What a repeatable task actually awards
-- shrinks each time you do it, and only the tooltip shows it. The tooltip gets
-- it like this (QuestUtils_AddQuestRewardsToTooltip, live source):
--
--   favor = C_QuestInfoSystem.GetQuestLogRewardFavor(rewardQuestID, clampToCap)
--   favor = C_NeighborhoodInitiative.GetInitiativeTaskRewardScaling(taskID, favor)
--
-- and runs currency amounts through the same scaling call. This file does
-- exactly that per task, so the list can be sorted by the real number.
-- C_QuestLog.GetQuestRewardCurrencies alone is NOT enough: it returns base
-- amounts and no House XP at all (owner-dumped 2026-09-19: 5/5 where the
-- tooltip said 4/4).
--
-- Request policy, same spirit as Core.lua: no repeating timer. Initiative info
-- is requested when the task window opens and after a task completes while it
-- is open -- never while Blizzard's dashboard is on screen, where Blizzard is
-- already asking and we just listen. Blizzard's Initiatives tab only registers
-- for these events while it is shown, so a request made while it is hidden
-- never reaches it.

local VillaHouse = _G.FabledUI_Villa_House
if not VillaHouse then return end

local Tasks = {}
VillaHouse.Tasks = Tasks

local REBUILD_DEBOUNCE = 0.2
local REQUEST_DEBOUNCE = 0.5
local COMMUNITY_COUPONS = 3363

-- Enum.NeighborhoodInitiativeTaskType. Read from the client when present.
local TASK_TYPE = rawget(_G, "Enum") and Enum.NeighborhoodInitiativeTaskType or nil
local REPEATABLE_INFINITE = (TASK_TYPE and TASK_TYPE.RepeatableInfinite) or 2

local function callNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and type(value) == "number" then return value end
    return nil
end

local function callTable(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and type(value) == "table" then return value end
    return nil
end

-- -----------------------------------------------------------------------------
-- API seam (extends VillaHouse.Api; tests replace these)
-- -----------------------------------------------------------------------------

local Api = VillaHouse.Api

-- Cached read of whatever the last request brought back. No server round trip.
Api.InitiativeInfo = function()
    return callTable(C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo)
end

-- Answers with NEIGHBORHOOD_INITIATIVE_UPDATED. The info that comes back is for
-- the "viewing" neighborhood, so point that at the active one first, the way
-- the dashboard does on house select. Only called while the dashboard is
-- hidden; it sets its own context again whenever a house is picked there.
Api.RequestInitiativeInfo = function()
    local NI = C_NeighborhoodInitiative
    if not (NI and NI.RequestNeighborhoodInitiativeInfo) then return end
    if NI.IsViewingActiveNeighborhood and NI.GetActiveNeighborhood and NI.SetViewingNeighborhood then
        local okViewing, viewing = pcall(NI.IsViewingActiveNeighborhood)
        if okViewing and not viewing then
            local okActive, active = pcall(NI.GetActiveNeighborhood)
            if okActive and active then
                pcall(NI.SetViewingNeighborhood, active)
            end
        end
    end
    pcall(NI.RequestNeighborhoodInitiativeInfo)
end

Api.RewardFavor = function(questID, clampToCycleCap)
    return callNumber(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestLogRewardFavor, questID, clampToCycleCap)
end

-- nil when this client has no scaling call; the caller then shows the unscaled
-- number and says so, rather than presenting a base value as the real one.
Api.ScaleReward = function(taskID, amount)
    return callNumber(C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetInitiativeTaskRewardScaling, taskID, amount)
end

Api.RewardCurrencies = function(questID)
    return callTable(C_QuestLog and C_QuestLog.GetQuestRewardCurrencies, questID)
end

Api.HaveRewardData = function(questID)
    local fn = rawget(_G, "HaveQuestRewardData")
    if type(fn) ~= "function" then return true end
    local ok, have = pcall(fn, questID)
    return ok and have and true or false
end

-- Answers with QUEST_DATA_LOAD_RESULT.
Api.RequestQuestLoad = function(questID)
    if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        pcall(C_QuestLog.RequestLoadQuestByID, questID)
    end
end

Api.SetTaskTracked = function(taskID, tracked)
    local NI = C_NeighborhoodInitiative
    if not NI then return end
    local fn = tracked and NI.AddTrackedInitiativeTask or NI.RemoveTrackedInitiativeTask
    if type(fn) == "function" then pcall(fn, taskID) end
end

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

Tasks.rows = {}
Tasks.meta = { loaded = false, title = nil, viewingActive = true, scaled = true }
Tasks._questLoadRequested = {}
Tasks._pendingQuests = {}
Tasks._callbacks = {}

function Tasks:Settings()
    local db = VillaHouse:DB()
    if type(db.tasks) ~= "table" then db.tasks = {} end
    local s = db.tasks
    if s.hideFinished == nil then s.hideFinished = true end
    if s.repeatableOnly == nil then s.repeatableOnly = false end
    if type(s.sortKey) ~= "string" then s.sortKey = "xp" end
    if s.sortDesc == nil then s.sortDesc = true end
    return s
end

function Tasks:RegisterCallback(owner, fn)
    if owner == nil or type(fn) ~= "function" then return end
    self._callbacks[owner] = fn
end

function Tasks:Fire()
    for _, fn in pairs(self._callbacks) do
        pcall(fn, self)
    end
end

-- -----------------------------------------------------------------------------
-- Building rows
-- -----------------------------------------------------------------------------

local function wholeNumber(value)
    if type(value) ~= "number" then return nil end
    return math.floor(value + 0.0001)
end

-- The real reward for one task. Returns xp, xpUncapped, coupons, pending, scaled.
function Tasks:ReadReward(taskID, questID)
    if type(questID) ~= "number" or questID <= 0 then
        return 0, 0, 0, false, true
    end

    if not Api.HaveRewardData(questID) then
        self._pendingQuests[questID] = true
        if not self._questLoadRequested[questID] then
            self._questLoadRequested[questID] = true
            Api.RequestQuestLoad(questID)
        end
        return nil, nil, nil, true, true
    end
    self._pendingQuests[questID] = nil

    local scaledOK = true
    local function scale(amount)
        if type(amount) ~= "number" or amount <= 0 then return 0 end
        local scaled = Api.ScaleReward(taskID, amount)
        if scaled == nil then
            scaledOK = false
            return amount
        end
        return scaled
    end

    -- nil (not 0) when the favor call itself is missing: "unknown", not "pays nothing".
    local function favor(clampToCycleCap)
        local raw = Api.RewardFavor(questID, clampToCycleCap)
        if raw == nil then return nil end
        return wholeNumber(scale(raw))
    end
    local xp = favor(true)
    local xpUncapped = favor(false)

    local coupons = 0
    local currencies = Api.RewardCurrencies(questID)
    if currencies then
        for _, currency in ipairs(currencies) do
            if type(currency) == "table" and currency.currencyID == COMMUNITY_COUPONS then
                coupons = wholeNumber(scale(currency.totalRewardAmount)) or 0
            end
        end
    end

    return xp, xpUncapped, coupons, false, scaledOK
end

-- A task that supersedes another is a later stage of a chain. It is doable now
-- only once the stage before it is complete -- the same promotion rule
-- InitiativesTabMixin:RefreshTaskList applies when it builds its tree.
local function isCurrentStage(task, byID)
    local previous = task.supersedes
    if type(previous) ~= "number" or previous == 0 then return true end
    local parent = byID[previous]
    if not parent then return true end
    return parent.completed and true or false
end

function Tasks:BuildRows(info)
    local rows = {}
    if type(info) ~= "table" or type(info.tasks) ~= "table" then return rows end

    local byID = {}
    for _, task in ipairs(info.tasks) do
        if type(task) == "table" and task.ID then byID[task.ID] = task end
    end

    local allScaled = true
    for _, task in ipairs(info.tasks) do
        if type(task) == "table" and task.ID and isCurrentStage(task, byID) then
            local repeatable = task.taskType == REPEATABLE_INFINITE
            local xp, xpUncapped, coupons, pending, scaled = self:ReadReward(task.ID, task.rewardQuestID)
            if not scaled then allScaled = false end

            local requirements = {}
            if type(task.requirementsList) == "table" then
                for _, req in ipairs(task.requirementsList) do
                    if type(req) == "table" and type(req.requirementText) == "string" then
                        requirements[#requirements + 1] = {
                            text = (req.requirementText:gsub(" / ", "/")),
                            completed = req.completed and true or false,
                        }
                    end
                end
            end

            rows[#rows + 1] = {
                id             = task.ID,
                name           = type(task.taskName) == "string" and task.taskName or "?",
                description    = type(task.description) == "string" and task.description or "",
                banner         = tonumber(task.progressContributionAmount) or 0,
                timesCompleted = tonumber(task.timesCompleted) or 0,
                repeatable     = repeatable,
                -- Blizzard's checkmark rule: an infinitely repeatable task is
                -- never "finished", whatever its completed flag says.
                finished       = (task.completed and not repeatable) and true or false,
                tracked        = task.tracked and true or false,
                sortOrder      = tonumber(task.sortOrder) or 999,
                requirements   = requirements,
                xp             = xp,
                xpUncapped     = xpUncapped,
                capped         = (xp ~= nil and xpUncapped ~= nil and xp < xpUncapped) and true or false,
                coupons        = coupons,
                pending        = pending,
            }
        end
    end

    self.meta.scaled = allScaled
    return rows
end

-- -----------------------------------------------------------------------------
-- Sorting and filtering
-- -----------------------------------------------------------------------------

local SORT_VALUE = {
    xp      = function(row) return row.xp or -1 end,
    banner  = function(row) return row.banner end,
    coupons = function(row) return row.coupons or -1 end,
    done    = function(row) return row.timesCompleted end,
    name    = function(row) return row.name:lower() end,
}
Tasks.SORT_KEYS = { "name", "done", "banner", "xp", "coupons" }

function Tasks:Compare(a, b, key, descending)
    -- Finished tasks sink regardless of the sort, as in Blizzard's list.
    if a.finished ~= b.finished then return not a.finished end

    local value = SORT_VALUE[key] or SORT_VALUE.xp
    local av, bv = value(a), value(b)
    if av ~= bv then
        if descending then return av > bv end
        return av < bv
    end
    if a.sortOrder ~= b.sortOrder then return a.sortOrder < b.sortOrder end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

function Tasks:GetVisibleRows()
    local settings = self:Settings()
    local visible = {}
    for _, row in ipairs(self.rows) do
        local keep = true
        if settings.hideFinished and row.finished then keep = false end
        if settings.repeatableOnly and not row.repeatable then keep = false end
        if keep then visible[#visible + 1] = row end
    end
    local key, descending = settings.sortKey, settings.sortDesc
    table.sort(visible, function(a, b) return Tasks:Compare(a, b, key, descending) end)
    return visible
end

function Tasks:SetSort(key)
    if not SORT_VALUE[key] then return end
    local settings = self:Settings()
    if settings.sortKey == key then
        settings.sortDesc = not settings.sortDesc
    else
        settings.sortKey = key
        settings.sortDesc = key ~= "name"
    end
    self:Fire()
end

-- -----------------------------------------------------------------------------
-- Refreshing
-- -----------------------------------------------------------------------------

function Tasks:Rebuild()
    local info = Api.InitiativeInfo()
    local meta = self.meta
    if type(info) == "table" and info.isLoaded ~= false and (tonumber(info.initiativeID) or 0) ~= 0 then
        meta.loaded = true
        meta.title = type(info.title) == "string" and info.title or nil
        self.rows = self:BuildRows(info)
    else
        meta.loaded = false
        meta.title = nil
        self.rows = {}
    end
    self:Fire()
end

local function debounced(flag, delay, fn)
    if Tasks[flag] then return end
    if not (C_Timer and C_Timer.After) then
        fn()
        return
    end
    Tasks[flag] = true
    C_Timer.After(delay, function()
        Tasks[flag] = false
        fn()
    end)
end

function Tasks:RebuildSoon()
    debounced("_rebuildPending", REBUILD_DEBOUNCE, function() Tasks:Rebuild() end)
end

function Tasks:_RequestNow()
    if Api.DashboardShown() then return false end
    Api.RequestInitiativeInfo()
    return true
end

function Tasks:RequestSoon()
    debounced("_requestPending", REQUEST_DEBOUNCE, function() Tasks:_RequestNow() end)
end

function Tasks:ToggleTracked(row)
    if type(row) ~= "table" or not row.id or row.finished then return end
    Api.SetTaskTracked(row.id, not row.tracked)
end

-- Is anyone looking? Set by the task window. Nothing is requested for a list
-- nobody can see; the cached read on open is enough to paint, and the request
-- that follows brings it up to date.
Tasks.watching = false

function Tasks:SetWatching(watching)
    self.watching = watching and true or false
    if self.watching then
        self:Rebuild()
        self:RequestSoon()
    end
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------

local EVENTS = {
    "NEIGHBORHOOD_INITIATIVE_UPDATED",
    "INITIATIVE_TASKS_TRACKED_LIST_CHANGED",
    "INITIATIVE_TASKS_TRACKED_UPDATED",
    "INITIATIVE_TASK_COMPLETED",
    "QUEST_DATA_LOAD_RESULT",
}

local function onEvent(_, event, ...)
    if event == "QUEST_DATA_LOAD_RESULT" then
        local questID = ...
        if questID and Tasks._pendingQuests[questID] and Tasks.watching then
            Tasks:RebuildSoon()
        end
    elseif event == "INITIATIVE_TASK_COMPLETED" then
        -- The next payout just shrank; ask for the new numbers if shown.
        if Tasks.watching then Tasks:RequestSoon() end
    elseif Tasks.watching then
        Tasks:RebuildSoon()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", onEvent)
for _, event in ipairs(EVENTS) do
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then
        VillaHouse._refusedEvents[#VillaHouse._refusedEvents + 1] = event
    end
end
Tasks._eventFrame = eventFrame
