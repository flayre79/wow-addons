-- Endeavors.lua -- Neighborhood Initiative tasks ("endeavors").
--
-- Default-tracker parity: Blizzard lists endeavors and we hide Blizzard's
-- tracker, so without this section they vanish. Kaliel's Tracker covers them in
-- Modules/Endeavors.lua; this is the Artemis equivalent and one of the three
-- gaps that block retiring !KalielsTracker.
--
-- ---------------------------------------------------------------------------
-- WHICH API. Read this before "fixing" the source of the task list.
--
-- C_NeighborhoodInitiative.GetTrackedInitiativeTasks() is NOT the endeavor
-- list. It returns only tasks explicitly pushed into the objective tracker,
-- which is almost always empty -- the first version of this file used it and
-- the section never appeared once, even with a full dashboard of endeavors on
-- screen. /artemis status said "0 tracked by the API" while the Housing
-- Dashboard showed a dozen tasks, which is what gave it away.
--
-- The real list is GetNeighborhoodInitiativeInfo().tasks. Guard on
-- info.isLoaded: the call returns a table before the data has arrived, and
-- treating that as "no endeavors" caches an empty section over a live one.
--
-- Task shape is InitiativeTaskInfo -- note the capitalised ID:
--   ID, taskName, description, requirementsList, completed, tracked,
--   isRepeatable, timesCompleted, taskType, rewardQuestID, xpReward
-- Each requirementsList entry carries requirementText and completed.
-- Cross-checked against HousingCodex/Core/EndeavorsData.lua, which annotates
-- these field names against the API type.
-- ---------------------------------------------------------------------------
--
-- ---------------------------------------------------------------------------
-- HOUSING API RULE.
--
-- Never read the housing API on a timer, and never call a Request* function
-- from here. Polling C_Housing every 2s from a Nexus widget left Blizzard's
-- Housing Dashboard "House Information" tab blank except the house dropdown:
-- InitiativesFrame:OnHouseSelected indexes self.playerHouseList with no nil
-- check, and once it throws the forwarder never reaches HouseUpgradeFrame and
-- the dropdown's tCompare guard swallows every identical reply after that.
-- Owner-bisected 2026-09-03; see CLAUDE.md "Rules learned the hard way ->
-- Events".
--
-- So this module calls ONLY getters, rebuilds on the initiative events via a
-- dirty flag rather than on every tracker refresh, and serves the cache
-- untouched while the Housing Dashboard is on screen -- that being exactly
-- when Blizzard is mid-build off the same data.
-- ---------------------------------------------------------------------------

local A = FabledUI_Artemis or Artemis

A.Endeavors = A.Endeavors or {}
local E = A.Endeavors

-- An initiative cycle ships well under this; the cap only stops a pathological
-- list from crowding every other section out of the tracker.
E.MAX_TASKS = 20

E._entries = E._entries or {}
E._dirty = true

---------------------------------------------------------------------
-- Availability
---------------------------------------------------------------------

local function API()
    return rawget(_G, "C_NeighborhoodInitiative")
end

function E:IsAvailable()
    local api = API()
    return type(api) == "table"
        and type(api.GetNeighborhoodInitiativeInfo) == "function"
end

function E:IsSectionEnabled()
    if not self:IsAvailable() then
        return false
    end
    if not A.profile then
        return false
    end
    if A.profile.trackEndeavors == false then
        return false
    end
    return A:IsModuleEnabled("endeavors") ~= false
end

function E:SetSectionEnabled(enabled)
    if not A.profile then
        return
    end
    A.profile.trackEndeavors = enabled and true or false
    self:Invalidate()
end

---------------------------------------------------------------------
-- Cache control
---------------------------------------------------------------------

-- Called from Events.lua when the initiative or its tracked list changes.
function E:Invalidate()
    self._dirty = true
end

-- True while Blizzard's Housing Dashboard is on screen. Reading the housing
-- API into an open dashboard is what broke the House Information tab, so the
-- cache is served untouched for as long as it is up. Endeavors going stale
-- while the dashboard covers the tracker is not something anyone can see.
local function HousingDashboardIsOpen()
    local frame = rawget(_G, "HousingDashboardFrame")
        or rawget(_G, "PlayerHousingFrame")
        or rawget(_G, "HousingFrame")
    if not frame or type(frame.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown and true or false
end

---------------------------------------------------------------------
-- API reads
---------------------------------------------------------------------

-- pcall does not protect its own argument expression: pcall(api.Foo) with a
-- nil api raises while building the call, before pcall ever sees it. Check the
-- namespace and the function first -- the offline simulator has neither.
local function InitiativeInfo()
    local api = API()
    if type(api) ~= "table" or type(api.GetNeighborhoodInitiativeInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(api.GetNeighborhoodInitiativeInfo)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return info
end

function E:_TaskList()
    local info = InitiativeInfo()
    if not info then
        return nil, "no initiative"
    end
    -- The call answers before the data lands. Reporting "not loaded" separately
    -- from "no tasks" keeps the caller able to retry rather than cache a blank.
    if info.isLoaded == false then
        return nil, "not loaded"
    end
    if type(info.tasks) ~= "table" then
        return nil, "no tasks field"
    end
    return info.tasks, nil
end

---------------------------------------------------------------------
-- Entry construction
---------------------------------------------------------------------

local function TaskID(task)
    -- InitiativeTaskInfo spells it ID; tolerate id in case a future build or a
    -- shim hands back the lowercase form.
    return task.ID or task.id
end

local function TaskIsComplete(task)
    if task.completed ~= nil then
        return task.completed == true
    end
    return task.isComplete == true
end

-- One header row per task, then one row per requirement. Same flat shape
-- Recipes.lua produces, so the renderer treats them the same way.
function E:_AppendTask(entries, task)
    local taskID = TaskID(task)
    if not taskID then
        return false
    end

    local name = task.taskName
    if type(name) ~= "string" or name == "" then
        name = "Endeavor " .. tostring(taskID)
    end

    local timesCompleted = tonumber(task.timesCompleted) or 0

    local header = {
        id = "endeavor:" .. tostring(taskID),
        text = name,
        isName = true,
        taskID = taskID,
        description = (type(task.description) == "string" and task.description ~= "") and task.description or nil,
        repeatable = task.isRepeatable == true,
        timesCompleted = timesCompleted,
        tracked = task.tracked == true,
        completed = TaskIsComplete(task),
        rewardQuestID = task.rewardQuestID,
    }
    entries[#entries + 1] = header

    local done, total = 0, 0
    for _, requirement in ipairs(task.requirementsList or {}) do
        local text = requirement.requirementText
        if type(text) == "string" and text ~= "" then
            -- Blizzard pads the fraction as "3 / 5"; the tracker is narrow and
            -- the default tracker tightens it the same way.
            text = text:gsub(" / ", "/")
            total = total + 1
            if requirement.completed then
                done = done + 1
            end
            entries[#entries + 1] = {
                id = "endeavor:" .. tostring(taskID) .. ":" .. total,
                text = text,
                completed = requirement.completed == true,
                taskID = taskID,
            }
        end
    end

    header.requirementsDone = done
    header.requirementsTotal = total
    return true
end

function E:BuildEntries()
    if not self:IsSectionEnabled() then
        self._entries = {}
        self._dirty = false
        return self._entries
    end

    -- Cache is authoritative unless something actually changed. See the housing
    -- API rule above.
    if not self._dirty or HousingDashboardIsOpen() then
        return self._entries
    end

    local tasks, reason = self:_TaskList()
    if not tasks then
        -- Leave _dirty set so the next refresh retries. Data that has not
        -- arrived yet must not be cached as an empty section.
        self._lastReason = reason
        return self._entries
    end
    self._lastReason = nil

    -- Completed endeavors stay visible only when completed objectives do --
    -- the same switch that governs finished quest objectives, so the tracker
    -- behaves consistently rather than growing its own private rule.
    local showCompleted = A.profile.showCompletedObjectives == true

    local entries = {}
    local rendered = 0
    for _, task in ipairs(tasks) do
        if rendered >= self.MAX_TASKS then
            break
        end
        if type(task) == "table" then
            local complete = TaskIsComplete(task)
            if not complete or showCompleted then
                if self:_AppendTask(entries, task) then
                    rendered = rendered + 1
                end
            end
        end
    end

    self._entries = entries
    self._dirty = false
    return entries
end

function E:GetTrackedCount()
    local count = 0
    for _, entry in ipairs(self._entries or {}) do
        if entry.isName then
            count = count + 1
        end
    end
    return count
end

-- Diagnostics for /artemis status. Returns total tasks the API reports, how
-- many are complete, and why the list was unavailable if it was.
function E:GetDiagnostics()
    if not self:IsAvailable() then
        return nil, nil, "api missing"
    end
    local tasks, reason = self:_TaskList()
    if not tasks then
        return nil, nil, reason
    end
    local complete = 0
    for _, task in ipairs(tasks) do
        if type(task) == "table" and TaskIsComplete(task) then
            complete = complete + 1
        end
    end
    return #tasks, complete, nil
end

---------------------------------------------------------------------
-- Row actions
---------------------------------------------------------------------

-- Stop tracking. Only meaningful for a task that is actually in the objective
-- tracker's list; a user action, and a setter rather than a Request*.
function E:Untrack(taskID)
    local api = API()
    if not (api and type(api.RemoveTrackedInitiativeTask) == "function") then
        return false
    end
    local ok = pcall(api.RemoveTrackedInitiativeTask, taskID)
    if ok then
        self:Invalidate()
    end
    return ok
end

-- Shift-click chat link, matching every other trackable thing in the game.
function E:GetChatLink(taskID)
    local api = API()
    if not (api and type(api.GetInitiativeTaskChatLink) == "function") then
        return nil
    end
    local ok, link = pcall(api.GetInitiativeTaskChatLink, taskID)
    if ok and type(link) == "string" and link ~= "" then
        return link
    end
    return nil
end
