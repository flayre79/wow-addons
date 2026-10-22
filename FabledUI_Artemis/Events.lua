local A = FabledUI_Artemis or Artemis

A.Events = A.Events or {}
local E = A.Events

local IMPORTANT_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true,
}

function E:QueueRefresh(fullRefresh)
    if not A.Tracker then
        return
    end

    if A.profile and A.profile.enabled == false then
        return
    end

    self._queuedFullRefresh = self._queuedFullRefresh or fullRefresh == true
    self._lastQueueAt = GetTime and GetTime() or 0
    if self._refreshPending then
        return
    end

    self._refreshPending = true
    C_Timer.After(0.75, function()
        self._refreshPending = false
        local wantsFull = self._queuedFullRefresh == true
        self._queuedFullRefresh = false
        if A.Tracker and A.Tracker.frame and A.Tracker.frame:IsShown() then
            A.Tracker:Refresh(wantsFull)
        end
    end)
end

-- Guarded registration. Two failures are invisible to the offline harness and
-- both abort the rest of Init when they happen inline: an event name the
-- running client does not have ("Attempt to register unknown event") and an
-- event that is protected for addons (ADDON_ACTION_FORBIDDEN -- 12.0 made
-- COMBAT_LOG_EVENT_UNFILTERED one of these). Registering the whole list before
-- attaching OnEvent means one refusal leaves a frame with live registrations
-- and no handler at all, so the tracker stops updating with nothing logged.
--
-- Register one at a time, through pcall, and only after the handler is
-- attached. Refusals are recorded for /artemis status. Same shape as
-- Kleos:RegisterEvents (FabledUI_Kleos/Core.lua).
function E:RegisterEvents(frame, events)
    if not frame or type(frame.RegisterEvent) ~= "function" then
        return {}, {}
    end

    local registered, refused = {}, {}
    for _, event in ipairs(events or {}) do
        local ok, err = pcall(frame.RegisterEvent, frame, event)
        if ok then
            registered[#registered + 1] = event
        else
            refused[#refused + 1] = event
            self._refusedEvents = self._refusedEvents or {}
            self._refusedEvents[event] = tostring(err)
        end
    end

    frame._artemisEvents = registered
    frame._artemisRefusedEvents = refused
    return registered, refused
end

function E:RefusedEvents()
    return self._refusedEvents or {}
end

function E:Init()
    self.frame = self.frame or CreateFrame("Frame")

    local events = {
        "PLAYER_ENTERING_WORLD",
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED",
        "SUPER_TRACKING_CHANGED",
        "TASK_PROGRESS_UPDATE",
        "TRACKED_ACHIEVEMENT_LIST_CHANGED",
        "PLAYER_REGEN_ENABLED",
        -- Scenario/instance objective tracking (delves, dungeons, raids, M+, events).
        "SCENARIO_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "SCENARIO_COMPLETED",
        "CRITERIA_UPDATE",
        -- Tracked profession recipes: the tracked list itself, the bag counts
        -- behind every reagent row, and the item cache that supplies reagent
        -- names on a cold login.
        "TRACKED_RECIPE_UPDATE",
        -- Tracked endeavors. Getter-only reads happen in Endeavors:BuildEntries;
        -- this event just marks the cache dirty. Never register a housing
        -- Request* call against it -- see the rule at the top of Endeavors.lua.
        "INITIATIVE_TASKS_TRACKED_LIST_CHANGED",
        "NEIGHBORHOOD_INITIATIVE_UPDATED",
        -- Traveler's Log. Getter-only reads happen in Activities:BuildEntries;
        -- these just mark the cache dirty.
        "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED",
        "PERKS_ACTIVITIES_TRACKED_UPDATED",
        "PERKS_ACTIVITY_COMPLETED",
        "BAG_UPDATE_DELAYED",
        "GET_ITEM_INFO_RECEIVED",
    }

    -- Handler first, then one event at a time -- see RegisterEvents above.
    self.frame:SetScript("OnEvent", function(_, eventName)
        if eventName == "PLAYER_REGEN_ENABLED" and A.Tracker then
            if A.Tracker.pendingTrackerToggle then
                A.Tracker:ManageDefaultTracker()
            end
            -- Quest-item buttons are secure, so every call that positions them
            -- is blocked in combat. Replay whatever combat refused.
            if A.Tracker._pendingHide then
                A.Tracker._pendingHide = false
                A.Tracker:Hide()
            elseif A.Tracker.FlushDeferredItemButtons then
                A.Tracker:FlushDeferredItemButtons()
            end
        end

        -- Re-assert "Hide Blizzard Tracker" after every loading screen.
        --
        -- ManageDefaultTracker ran at PLAYER_LOGIN and on show/hide/toggle, but
        -- never on PLAYER_ENTERING_WORLD, and it bails when ObjectiveTrackerFrame
        -- does not exist yet. Blizzard also re-parents its own tracker as part of
        -- loading, so a single reparent at login does not hold. That is why the
        -- setting stayed checked while the Blizzard tracker came back -- and why
        -- it was intermittent rather than every time.
        if eventName == "PLAYER_ENTERING_WORLD" and A.Tracker then
            A.Tracker:ManageDefaultTracker()
        end

        if eventName == "QUEST_LOG_UPDATE" and A.QuestScan then
            A.QuestScan:Invalidate()
        end

        if (eventName == "INITIATIVE_TASKS_TRACKED_LIST_CHANGED"
            or eventName == "NEIGHBORHOOD_INITIATIVE_UPDATED") and A.Endeavors then
            A.Endeavors:Invalidate()
        end

        if (eventName == "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED"
            or eventName == "PERKS_ACTIVITIES_TRACKED_UPDATED"
            or eventName == "PERKS_ACTIVITY_COMPLETED") and A.Activities then
            A.Activities:Invalidate()
        end

        -- GET_ITEM_INFO_RECEIVED fires hundreds of times as the item cache
        -- fills on a cold login, and almost none of them concern us. Only the
        -- recipe section ever waits on it, so ignore the event unless a reagent
        -- row actually rendered without a name.
        if eventName == "GET_ITEM_INFO_RECEIVED" then
            if not (A.Recipes and A.Recipes:IsAwaitingItemData()) then
                return
            end
        end

        local wantsFull = IMPORTANT_EVENTS[eventName] == true
        self:QueueRefresh(wantsFull)
    end)

    self:RegisterEvents(self.frame, events)
end
