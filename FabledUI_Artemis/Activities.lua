-- Activities.lua -- tracked Traveler's Log activities ("monthly activities").
--
-- Default-tracker parity: Blizzard lists tracked activities and we hide
-- Blizzard's tracker, so without this section they vanish. Kaliel's Tracker
-- covers them in Core/MonthlyActivitiesObjectiveTracker.lua; this is the
-- Artemis equivalent and the second of the three gaps blocking retirement of
-- !KalielsTracker.
--
-- ---------------------------------------------------------------------------
-- WHICH API.
--
-- Unlike endeavors, the tracked list IS the right source here -- Blizzard's own
-- tracker builds from it (LayoutContents in the file above). But note the
-- shape: GetTrackedPerksActivities() returns a TABLE with a `trackedIDs` field,
-- not a plain array. Treating the return as the list itself yields nothing and
-- looks exactly like "you have nothing tracked".
--
-- Activity shape, from GetPerksActivityInfo(activityID):
--   ID, activityName, requirementsList, completed
-- Each requirementsList entry carries requirementText and completed -- the same
-- shape InitiativeTaskInfo uses, so the rows render through the same path.
--
-- Blizzard skips completed activities entirely. We follow the tracker's own
-- "Show Completed Objectives" switch instead, so the behaviour matches the rest
-- of Artemis rather than only this section.
-- ---------------------------------------------------------------------------

local A = FabledUI_Artemis or Artemis

A.Activities = A.Activities or {}
local V = A.Activities

-- A month's log is well under this; the cap only stops a pathological tracked
-- list from crowding out every other section.
V.MAX_ACTIVITIES = 20

V._entries = V._entries or {}
V._dirty = true

---------------------------------------------------------------------
-- Availability
---------------------------------------------------------------------

local function API()
    return rawget(_G, "C_PerksActivities")
end

function V:IsAvailable()
    local api = API()
    return type(api) == "table"
        and type(api.GetTrackedPerksActivities) == "function"
        and type(api.GetPerksActivityInfo) == "function"
end

function V:IsSectionEnabled()
    if not self:IsAvailable() then
        return false
    end
    if not A.profile then
        return false
    end
    if A.profile.trackActivities == false then
        return false
    end
    return A:IsModuleEnabled("activities") ~= false
end

function V:SetSectionEnabled(enabled)
    if not A.profile then
        return
    end
    A.profile.trackActivities = enabled and true or false
    self:Invalidate()
end

---------------------------------------------------------------------
-- Cache control
---------------------------------------------------------------------

function V:Invalidate()
    self._dirty = true
end

---------------------------------------------------------------------
-- API reads
---------------------------------------------------------------------

-- pcall does not protect its own argument expression: pcall(api.Foo) with a nil
-- api raises while building the call. Check the namespace and function first --
-- the offline simulator has neither.
local function TrackedIDs()
    local api = API()
    if type(api) ~= "table" or type(api.GetTrackedPerksActivities) ~= "function" then
        return nil
    end
    local ok, result = pcall(api.GetTrackedPerksActivities)
    if not ok or type(result) ~= "table" then
        return nil
    end
    -- The documented return is { trackedIDs = { ... } }. Accept a bare array
    -- too, so a future shape change degrades to "works" rather than "silently
    -- empty".
    if type(result.trackedIDs) == "table" then
        return result.trackedIDs
    end
    return result
end

local function ActivityInfo(activityID)
    local api = API()
    if type(api) ~= "table" or type(api.GetPerksActivityInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(api.GetPerksActivityInfo, activityID)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return info
end

---------------------------------------------------------------------
-- Entry construction
---------------------------------------------------------------------

-- One header row per activity, then one row per requirement. Same flat shape
-- Endeavors.lua and Recipes.lua produce, so the renderer treats them alike.
function V:_AppendActivity(entries, activityID)
    local info = ActivityInfo(activityID)
    if not info then
        return false
    end

    local id = info.ID or activityID
    local name = info.activityName
    if type(name) ~= "string" or name == "" then
        name = "Activity " .. tostring(id)
    end

    local header = {
        id = "activity:" .. tostring(id),
        text = name,
        isName = true,
        taskID = id,
        completed = info.completed == true,
    }
    entries[#entries + 1] = header

    local done, total = 0, 0
    for _, requirement in ipairs(info.requirementsList or {}) do
        local text = requirement.requirementText
        if type(text) == "string" and text ~= "" then
            -- Blizzard pads the fraction as "3 / 5"; its own tracker tightens
            -- it the same way, and the panel is narrow.
            text = text:gsub(" / ", "/")
            total = total + 1
            if requirement.completed then
                done = done + 1
            end
            entries[#entries + 1] = {
                id = "activity:" .. tostring(id) .. ":" .. total,
                text = text,
                completed = requirement.completed == true,
                taskID = id,
            }
        end
    end

    header.requirementsDone = done
    header.requirementsTotal = total
    return true
end

function V:BuildEntries()
    if not self:IsSectionEnabled() then
        self._entries = {}
        self._dirty = false
        return self._entries
    end

    if not self._dirty then
        return self._entries
    end

    local ids = TrackedIDs()
    if not ids then
        -- Leave _dirty set so the next refresh retries rather than caching an
        -- empty section over data that has not arrived.
        self._lastReason = "api unavailable"
        return self._entries
    end
    self._lastReason = nil

    local showCompleted = A.profile.showCompletedObjectives == true

    local entries = {}
    local rendered = 0
    for _, activityID in ipairs(ids) do
        if rendered >= self.MAX_ACTIVITIES then
            break
        end
        if type(activityID) == "number" then
            local info = ActivityInfo(activityID)
            if info and (showCompleted or info.completed ~= true) then
                if self:_AppendActivity(entries, activityID) then
                    rendered = rendered + 1
                end
            end
        end
    end

    self._entries = entries
    self._dirty = false
    return entries
end

function V:GetTrackedCount()
    local count = 0
    for _, entry in ipairs(self._entries or {}) do
        if entry.isName then
            count = count + 1
        end
    end
    return count
end

-- Diagnostics for /artemis status: how many are tracked, how many complete,
-- and why the list was unavailable if it was.
function V:GetDiagnostics()
    if not self:IsAvailable() then
        return nil, nil, "api missing"
    end
    local ids = TrackedIDs()
    if not ids then
        return nil, nil, "call failed"
    end
    local complete = 0
    for _, activityID in ipairs(ids) do
        local info = ActivityInfo(activityID)
        if info and info.completed then
            complete = complete + 1
        end
    end
    return #ids, complete, nil
end

---------------------------------------------------------------------
-- Row actions
---------------------------------------------------------------------

-- Stop tracking, mirroring the default tracker's right-click. A user action and
-- a setter, not a poll.
function V:Untrack(activityID)
    local api = API()
    if not (api and type(api.RemoveTrackedPerksActivity) == "function") then
        return false
    end
    local ok = pcall(api.RemoveTrackedPerksActivity, activityID)
    if ok then
        self:Invalidate()
    end
    return ok
end

function V:GetChatLink(activityID)
    local api = API()
    if not (api and type(api.GetPerksActivityChatLink) == "function") then
        return nil
    end
    local ok, link = pcall(api.GetPerksActivityChatLink, activityID)
    if ok and type(link) == "string" and link ~= "" then
        return link
    end
    return nil
end
