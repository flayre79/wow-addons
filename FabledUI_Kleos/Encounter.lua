local K = Kleos

-- ============================================================================
-- Encounter — instance achievement tracking
-- The engine behind the "Instance Achievement Tracker", "Mob Count Tracking"
-- and "Boss Tactics Announcement" scope rows.
--
-- Everything is derived from live Blizzard data rather than a donor database:
--
--   which achievements matter here   the achievement category whose name
--        matches the instance, resolved through Catalog's category tree
--   which mobs to count              criteria of type 0 (kill creature) give
--        the creature id in assetID and the target count in reqQuantity
--   met / failed                     the criteria snapshot taken at
--        ENCOUNTER_START compared against the state at ENCOUNTER_END
--
-- Mob counting reads unit tokens, not the combat log. Midnight (12.0) made
-- COMBAT_LOG_EVENT_UNFILTERED a protected event: registering it raises
-- ADDON_ACTION_FORBIDDEN. Nameplate units are the sanctioned source and are
-- actually a better fit for "are enough of them up right now", because a
-- nameplate is removed when the mob dies or despawns, where a combat-log
-- sighting only ever aged out of a window. The combat-log path is kept behind a
-- version gate for clients that still allow it (the same gate IAT 6.11 uses at
-- AchievementTrackerCore.lua:705).
--
-- Chat output is opt-in. Section 6 of the PRD forbids broadcasting without
-- explicit user initiation, so Announce() refuses unless the player turned the
-- announce setting on, and every automatic call routes through it.
-- ============================================================================

K.Encounter = K.Encounter or {}
local E = K.Encounter

-- encounter is deliberately absent from this literal rather than set to nil:
-- it is assigned a table at ENCOUNTER_START and cleared at ENCOUNTER_END.
E.state = E.state or {
    inInstance = false,
    instanceID = nil,
    instanceName = nil,
    difficultyID = nil,
    difficultyName = nil,
    categoryID = nil,
    achievements = {},      -- ordered achievement ids relevant to this instance
    snapshot = {},          -- achievementID -> { [criteriaIndex] = quantity }
    results = {},           -- achievementID -> "met" | "failed" | "pending"
    mobRules = {},          -- npcID -> { { achievementID, criteriaIndex, required, label } }
    mobSeen = {},           -- npcID -> { [guid] = timestamp }
    mobCounts = {},         -- npcID -> distinct guids seen inside the window
    announced = {},
}

E.MOB_WINDOW = 45          -- seconds a sighting stays counted when nothing retires it
E.ANNOUNCE_MIN_GAP = 3     -- seconds between two automatic announcements

local CRITERIA_KILL_CREATURE = 0

-- The client version at which COMBAT_LOG_EVENT_UNFILTERED became protected.
local COMBAT_LOG_PROTECTED_FROM = 12

-- ----------------------------------------------------------------------------
-- Small helpers
-- ----------------------------------------------------------------------------
local function Now()
    if type(GetTime) == "function" then return GetTime() end
    if type(GetServerTime) == "function" then return GetServerTime() end
    return 0
end

-- Anything a game API hands back while addon code is on the stack can be a
-- secret value. Plain() reduces one to nil at the boundary, so nothing further
-- down has to remember that comparing, lowering or tostring-ing it raises.
local function Plain(value)
    if K.Util and K.Util.IsUsableString(value) then return value end
    return nil
end

local function NPCIDFromGUID(guid)
    -- A secret GUID still reports type "string"; strsplit on one throws, and
    -- there is no way to read the NPC ID back out. Give up quietly.
    if not (K.Util and K.Util.IsUsableString(guid)) then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    return tonumber(npcID)
end

E.NPCIDFromGUID = NPCIDFromGUID

local function Settings()
    return (K.db and K.db.settings) or {}
end

local function EncounterSettings()
    local settings = Settings()
    settings.encounter = settings.encounter or {}
    return settings.encounter
end

-- ----------------------------------------------------------------------------
-- Chat output
-- Returns false (and does nothing) unless the player opted in. `force` is for
-- output the player asked for by clicking a button this frame.
-- ----------------------------------------------------------------------------
function E:AnnounceChannel()
    if type(IsInRaid) == "function" and IsInRaid() then
        if type(IsInInstance) == "function" then
            local _, instanceType = IsInInstance()
            instanceType = Plain(instanceType)
            if instanceType == "raid" or instanceType == "party" then return "INSTANCE_CHAT" end
        end
        return "RAID"
    end
    if type(IsInGroup) == "function" and IsInGroup() then
        if type(IsInInstance) == "function" then
            local _, instanceType = IsInInstance()
            instanceType = Plain(instanceType)
            if instanceType == "party" or instanceType == "raid" then return "INSTANCE_CHAT" end
        end
        return "PARTY"
    end
    return nil
end

function E:Announce(text, force)
    text = tostring(text or "")
    if text == "" then return false end

    local settings = Settings()
    if not force and not settings.announce then return false end

    local now = Now()
    if not force then
        local gap = tonumber(settings.announceThrottleSec) or 60
        -- No previous announcement means no minimum gap to respect. Defaulting
        -- the timestamp to 0 instead would swallow the first line of a session
        -- on any client whose clock starts near zero.
        if self._lastAnnounce and (now - self._lastAnnounce) < math.max(self.ANNOUNCE_MIN_GAP, 0) then
            return false
        end
        self._lastAnnounceKeys = self._lastAnnounceKeys or {}
        local last = self._lastAnnounceKeys[text]
        if last and (now - last) < gap then return false end
        self._lastAnnounceKeys[text] = now
    end
    self._lastAnnounce = now

    local channel = self:AnnounceChannel()
    if not channel or type(SendChatMessage) ~= "function" then
        -- Solo, or no chat API: still surface it locally so the feature is not
        -- silently dead outside a group.
        K:Print(text)
        return true
    end

    local ok = pcall(SendChatMessage, "[Kleos] " .. text, channel)
    if not ok then K:Print(text) end
    return true
end

-- ----------------------------------------------------------------------------
-- Instance resolution
-- ----------------------------------------------------------------------------
function E:ResolveInstanceCategory(instanceName)
    instanceName = Plain(instanceName)
    if not instanceName then return nil end
    K.Catalog:Build()

    local wanted = instanceName:lower()
    local bestID, bestLength
    for catID, node in pairs(K.Catalog.categories) do
        local name = type(node.name) == "string" and node.name:lower() or nil
        if name and name ~= "" then
            -- Prefer the most specific (longest) matching category name so
            -- "Ulduar" wins over "Dungeons & Raids".
            if wanted:find(name, 1, true) or name:find(wanted, 1, true) then
                local length = #name
                if not bestLength or length > bestLength then
                    bestID, bestLength = catID, length
                end
            end
        end
    end
    return bestID
end

function E:CollectInstanceAchievements(categoryID)
    if not categoryID then return {} end
    K.Catalog:Build()
    local ids = {}
    for _, id in ipairs(K.Catalog.order) do
        local entry = K.Catalog.entries[id]
        if entry and not entry.isStatistic and K.Catalog:CategoryMatches(entry, categoryID) then
            ids[#ids + 1] = id
        end
    end
    return ids
end

-- npcID -> criteria that need it. Built from the achievements in scope, so no
-- static mob table is required.
function E:BuildMobRules(achievementIDs)
    local rules = {}
    for _, achievementID in ipairs(achievementIDs or {}) do
        local count = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(achievementID)) or 0
        for index = 1, count do
            local criteriaString, criteriaType, _, _, requiredQuantity, _, _, assetID = GetAchievementCriteriaInfo(achievementID, index)
            if tonumber(criteriaType) == CRITERIA_KILL_CREATURE then
                local npcID = tonumber(assetID)
                if npcID and npcID > 0 then
                    rules[npcID] = rules[npcID] or {}
                    local bucket = rules[npcID]
                    bucket[#bucket + 1] = {
                        achievementID = achievementID,
                        criteriaIndex = index,
                        required = tonumber(requiredQuantity) or 1,
                        label = type(criteriaString) == "string" and criteriaString or nil,
                    }
                end
            end
        end
    end
    return rules
end

function E:EnterInstance()
    if type(GetInstanceInfo) ~= "function" then return false end
    local name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    -- Read under addon taint, so these can come back secret: keeping one would
    -- poison every later :lower(), tostring() and concatenation that touches it.
    -- Drop them at the boundary and let the display fall back.
    name, difficultyName, instanceType = Plain(name), Plain(difficultyName), Plain(instanceType)
    -- A secret instanceType cannot be matched against anything, so treat it the
    -- same as being outside an instance rather than guessing.
    if not instanceType then return self:LeaveInstance() end
    if instanceType ~= "party" and instanceType ~= "raid" and instanceType ~= "scenario" then
        return self:LeaveInstance()
    end

    local state = self.state
    if state.inInstance and state.instanceID == instanceID and state.difficultyID == difficultyID then
        return true
    end

    state.inInstance = true
    state.instanceID = instanceID
    state.instanceName = name
    state.difficultyID = difficultyID
    state.difficultyName = difficultyName
    state.categoryID = self:ResolveInstanceCategory(name)
    state.achievements = self:CollectInstanceAchievements(state.categoryID)
    state.mobRules = self:BuildMobRules(state.achievements)
    state.mobSeen, state.mobCounts, state.results, state.announced = {}, {}, {}, {}

    -- Guidance data is only worth its load time inside an instance.
    self:LoadGuidance()

    if K.Tracker and K.Tracker.OnInstanceChanged then K.Tracker:OnInstanceChanged() end
    return true
end

function E:LeaveInstance()
    local state = self.state
    if not state.inInstance then return false end
    state.inInstance = false
    state.instanceID, state.instanceName, state.categoryID = nil, nil, nil
    state.achievements, state.mobRules, state.mobSeen, state.mobCounts = {}, {}, {}, {}
    state.encounter = nil
    if K.Tracker and K.Tracker.OnInstanceChanged then K.Tracker:OnInstanceChanged() end
    return true
end

-- LoadOnDemand sibling: criteria guidance and tactics phrasing. Absent in a
-- stripped install, so every read of it is guarded.
function E:LoadGuidance()
    if self._guidanceRequested then return false end
    self._guidanceRequested = true
    if C_AddOns and C_AddOns.LoadAddOn then
        local ok, loaded = pcall(C_AddOns.LoadAddOn, "FabledUI_Kleos_Encounters")
        return ok and loaded and true or false
    elseif type(rawget(_G, "LoadAddOn")) == "function" then
        local ok, loaded = pcall(_G.LoadAddOn, "FabledUI_Kleos_Encounters")
        return ok and loaded and true or false
    end
    return false
end

-- Guidance providers turn an achievement's criteria into readable steps. The
-- encounter sibling registers one; the open API can add more.
E.guidanceProviders = E.guidanceProviders or {}

function E:RegisterGuidance(name, fn)
    if type(name) ~= "string" or name == "" or type(fn) ~= "function" then return false end
    for _, provider in ipairs(self.guidanceProviders) do
        if provider.name == name then
            provider.fn = fn
            return true
        end
    end
    self.guidanceProviders[#self.guidanceProviders + 1] = { name = name, fn = fn }
    return true
end

-- Ask every provider for objectives for this achievement and register the
-- result so the detail pane and the tracker show it like any other step list.
function E:ApplyGuidance(achievementID)
    achievementID = tonumber(achievementID)
    if not achievementID then return 0 end
    if #self.guidanceProviders == 0 then return 0 end
    if K.Objectives:HasRegistered(achievementID) then return 0 end

    local objectives = {}
    for _, provider in ipairs(self.guidanceProviders) do
        local ok, result = pcall(provider.fn, achievementID)
        if ok and type(result) == "table" then
            for _, objective in ipairs(result) do objectives[#objectives + 1] = objective end
        end
    end
    if #objectives == 0 then return 0 end
    K.Objectives:Register(achievementID, objectives, "guidance")
    return #objectives
end

-- ----------------------------------------------------------------------------
-- Criteria snapshots
-- ----------------------------------------------------------------------------
function E:SnapshotAchievement(achievementID)
    local snapshot = {}
    local count = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(achievementID)) or 0
    for index = 1, count do
        local _, _, completed, quantity = GetAchievementCriteriaInfo(achievementID, index)
        snapshot[index] = { quantity = tonumber(quantity) or 0, completed = completed and true or false }
    end
    local _, _, _, achievementCompleted = GetAchievementInfo(achievementID)
    snapshot.achievementCompleted = achievementCompleted and true or false
    return snapshot
end

function E:Snapshot(achievementIDs)
    local snapshot = {}
    for _, achievementID in ipairs(achievementIDs or {}) do
        snapshot[achievementID] = self:SnapshotAchievement(achievementID)
    end
    return snapshot
end

-- Which of the instance's achievements are actually in play for this pull:
-- the incomplete ones the player has not already earned, plus anything on the
-- watch list (a completed achievement can still be tracked for an alt).
function E:AchievementsInPlay()
    local inPlay = {}
    for _, achievementID in ipairs(self.state.achievements) do
        local state = K.Catalog:GetState(achievementID)
        local watched = K.IsWatched and K:IsWatched(achievementID)
        if watched or not (state and state.completed) then
            inPlay[#inPlay + 1] = achievementID
        end
    end
    return inPlay
end

-- ----------------------------------------------------------------------------
-- Encounter lifecycle
-- ----------------------------------------------------------------------------
function E:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    -- ENCOUNTER_START delivers this straight into tainted execution, so it can
    -- be secret. Drop it here and every use below -- the tracker headline, the
    -- announce lines, the tactics lookup -- is safe by construction.
    encounterName = Plain(encounterName)
    if not self.state.inInstance then self:EnterInstance() end

    local inPlay = self:AchievementsInPlay()
    self.state.encounter = {
        id = tonumber(encounterID),
        name = encounterName,
        difficultyID = tonumber(difficultyID),
        groupSize = tonumber(groupSize),
        startedAt = Now(),
        achievements = inPlay,
    }
    self.state.snapshot = self:Snapshot(inPlay)
    self.state.results = {}
    self.state.announced = {}
    self.state.mobSeen, self.state.mobCounts = {}, {}

    for _, achievementID in ipairs(inPlay) do
        self.state.results[achievementID] = "pending"
        self:ApplyGuidance(achievementID)
    end

    if #inPlay > 0 then
        local names = {}
        for index = 1, math.min(3, #inPlay) do
            names[#names + 1] = K.Meta.AchievementName(inPlay[index])
        end
        local suffix = (#inPlay > #names) and ((" +%d"):format(#inPlay - #names)) or ""
        self:Announce(("%s: tracking %s%s"):format(tostring(encounterName or "Encounter"), table.concat(names, ", "), suffix))
    end

    local tactics = self:GetTactics(encounterID, encounterName)
    if tactics and tactics ~= "" then
        self:Announce(("%s tactics: %s"):format(tostring(encounterName or "Encounter"), tactics))
    end

    if K.Tracker and K.Tracker.OnEncounterStart then K.Tracker:OnEncounterStart(self.state.encounter) end
    return self.state.encounter
end

function E:EvaluateAchievement(achievementID)
    local before = self.state.snapshot and self.state.snapshot[achievementID]
    local after = self:SnapshotAchievement(achievementID)
    if after.achievementCompleted and not (before and before.achievementCompleted) then return "met" end
    if after.achievementCompleted then return "met" end

    local count = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(achievementID)) or 0
    if count == 0 then return "failed" end

    local allComplete = true
    local regressed = false
    for index = 1, count do
        local current = after[index]
        local previous = before and before[index]
        if not (current and current.completed) then allComplete = false end
        if previous and current and current.quantity < previous.quantity then regressed = true end
    end
    if allComplete then return "met" end
    if regressed then return "failed" end
    return "failed"
end

function E:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    encounterName = Plain(encounterName)
    local encounter = self.state.encounter
    if not encounter then return nil end

    local met, failed = {}, {}
    for _, achievementID in ipairs(encounter.achievements or {}) do
        local result = success == 1 or success == true
        if result then
            local verdict = self:EvaluateAchievement(achievementID)
            self.state.results[achievementID] = verdict
            if verdict == "met" then
                met[#met + 1] = K.Meta.AchievementName(achievementID)
            else
                failed[#failed + 1] = K.Meta.AchievementName(achievementID)
            end
        else
            self.state.results[achievementID] = "pending"
        end
    end

    if #met > 0 then self:Announce(("%s: earned %s"):format(tostring(encounterName or "Encounter"), table.concat(met, ", "))) end
    if #failed > 0 then self:Announce(("%s: missed %s"):format(tostring(encounterName or "Encounter"), table.concat(failed, ", "))) end

    local summary = { met = met, failed = failed, success = (success == 1 or success == true) }
    self.state.lastResult = summary
    self.state.encounter = nil

    if K.Tracker and K.Tracker.OnEncounterEnd then K.Tracker:OnEncounterEnd(summary) end
    return summary
end

-- ----------------------------------------------------------------------------
-- Mob counting
-- Distinct creature GUIDs seen inside a rolling window. Counting GUIDs rather
-- than events is what makes "enough of them have spawned" answerable: the same
-- mob taking twenty hits is one mob.
-- ----------------------------------------------------------------------------
function E:NoteMob(npcID, guid, timestamp)
    npcID = tonumber(npcID)
    if not npcID then return nil end
    local rules = self.state.mobRules[npcID]
    if not rules then return nil end

    timestamp = tonumber(timestamp) or Now()
    local seen = self.state.mobSeen[npcID]
    if not seen then
        seen = {}
        self.state.mobSeen[npcID] = seen
    end

    local isNew = seen[guid] == nil
    seen[guid] = timestamp

    -- Expire sightings outside the window.
    local live = 0
    for existingGUID, stamp in pairs(seen) do
        if (timestamp - stamp) > self.MOB_WINDOW then
            seen[existingGUID] = nil
        else
            live = live + 1
        end
    end
    self.state.mobCounts[npcID] = live

    if isNew then
        for _, rule in ipairs(rules) do
            if live >= rule.required and not self.state.announced["mob:" .. npcID .. ":" .. rule.achievementID] then
                self.state.announced["mob:" .. npcID .. ":" .. rule.achievementID] = true
                self:Announce(("%s: %d/%d up — go now (%s)"):format(
                    rule.label or K.Meta.AchievementName(rule.achievementID),
                    live, rule.required, K.Meta.AchievementName(rule.achievementID)))
            end
        end
    end

    return live
end

-- A mob whose nameplate went away is dead or gone: drop it from the live count
-- rather than waiting for the window to age it out.
function E:ForgetMob(npcID, guid)
    npcID = tonumber(npcID)
    if not npcID then return nil end
    local seen = self.state.mobSeen[npcID]
    if not seen then return nil end
    seen[guid] = nil

    local live = 0
    for _ in pairs(seen) do live = live + 1 end
    self.state.mobCounts[npcID] = live
    if live == 0 then
        -- Let the next wave announce again once this one is fully gone.
        for _, rule in ipairs(self.state.mobRules[npcID] or {}) do
            self.state.announced["mob:" .. npcID .. ":" .. rule.achievementID] = nil
        end
    end
    return live
end

function E:MobCount(npcID)
    return self.state.mobCounts[tonumber(npcID) or -1] or 0
end

-- Resolver indirection so a test can drive the unit path without a live unit;
-- production always uses UnitGUID.
E.UnitGUIDResolver = nil

function E:ResolveUnitGUID(unit)
    local resolver = self.UnitGUIDResolver
    if type(resolver) ~= "function" then resolver = rawget(_G, "UnitGUID") end
    if type(resolver) ~= "function" then return nil end
    -- UnitGUID itself rejects a secret unit token ("secret values are only
    -- allowed during untainted execution"), so never hand one over.
    if not (K.Util and K.Util.IsUsableString(unit)) then return nil end
    local ok, guid = pcall(resolver, unit)
    if not ok or not K.Util.IsUsableString(guid) then return nil end
    return guid
end

-- added = the unit appeared (nameplate added, targeted, moused over);
-- false = it went away.
function E:TrackUnit(unit, added)
    if not self.state.inInstance then return nil end
    if not next(self.state.mobRules) then return nil end
    -- Not `unit == ""`: comparing a secret unit token raises before the guard
    -- below ever runs. IsUsableString tests secrecy first.
    if not (K.Util and K.Util.IsUsableString(unit)) then return nil end

    local guid = self:ResolveUnitGUID(unit)
    local npcID = NPCIDFromGUID(guid)
    if not npcID then return nil end

    if added then return self:NoteMob(npcID, guid) end
    return self:ForgetMob(npcID, guid)
end

-- Kept for clients where the combat log is still available to addons; unused on
-- 12.x, where Init does not register the event at all.
function E:OnCombatLogEvent(...)
    if not self.state.inInstance then return end
    if not next(self.state.mobRules) then return end

    local timestamp, subevent, _, sourceGUID, _, _, _, destGUID = ...
    if type(subevent) ~= "string" then return end

    local sourceNPC = NPCIDFromGUID(sourceGUID)
    if sourceNPC then self:NoteMob(sourceNPC, sourceGUID, timestamp) end
    local destNPC = NPCIDFromGUID(destGUID)
    if destNPC then self:NoteMob(destNPC, destGUID, timestamp) end
end

-- Is the combat log available to addons on this client?
function E:CombatLogAllowed()
    local major = K.ClientMajorVersion and K:ClientMajorVersion() or 0
    return major > 0 and major < COMBAT_LOG_PROTECTED_FROM
end

function E:MobSource()
    return self:CombatLogAllowed() and "combatlog" or "nameplates"
end

-- ----------------------------------------------------------------------------
-- Tactics / guidance
-- Priority: the player's own note (K:SetTactic), then a registered pack from
-- the LoadOnDemand sibling or the open API.
-- ----------------------------------------------------------------------------
E.tactics = E.tactics or {}         -- key -> text

function E:RegisterTactics(key, text)
    if type(text) ~= "string" or text == "" then return false end
    key = tostring(key or ""):lower()
    if key == "" then return false end
    self.tactics[key] = text
    return true
end

function E:GetTactics(encounterID, encounterName)
    local numericID = tonumber(encounterID)
    if numericID and K.db and type(K.db.tactics) == "table" and K.db.tactics[numericID] then
        return K.db.tactics[numericID]
    end
    if numericID and self.tactics[tostring(numericID)] then return self.tactics[tostring(numericID)] end
    encounterName = Plain(encounterName)
    if encounterName then
        local byName = self.tactics[encounterName:lower()]
        if byName then return byName end
    end
    return nil
end

-- Manual "announce what we are tracking" for a button/slash command. This is
-- an explicit user action, so it bypasses the opt-in gate by design.
function E:AnnounceTracked()
    local encounter = self.state.encounter
    local ids = encounter and encounter.achievements or self:AchievementsInPlay()
    if #ids == 0 then
        K:Print(K.L.NO_RESULTS or "Nothing to announce here.")
        return false
    end
    local names = {}
    for index = 1, math.min(6, #ids) do names[#names + 1] = K.Meta.AchievementName(ids[index]) end
    return self:Announce(("tracking: %s"):format(table.concat(names, ", ")), true)
end

-- ----------------------------------------------------------------------------
-- Events
-- ----------------------------------------------------------------------------
function E:EventList()
    local events = {
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA",
        "ENCOUNTER_START",
        "ENCOUNTER_END",
        "CRITERIA_UPDATE",
        -- Mob counting: nameplates are the primary source, target and mouseover
        -- fill in when the player has nameplates turned off.
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
        "PLAYER_TARGET_CHANGED",
        "UPDATE_MOUSEOVER_UNIT",
    }
    if self:CombatLogAllowed() then
        events[#events + 1] = "COMBAT_LOG_EVENT_UNFILTERED"
    end
    return events
end

function E:Init()
    if self._frame then return end
    local frame = CreateFrame("Frame")
    self._frame = frame

    -- The OnEvent handler is attached before any registration: a refused event
    -- must never be able to leave this frame listening with no handler.
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            K:SafeCall(function() E:EnterInstance() end)
        elseif event == "ENCOUNTER_START" then
            local encounterID, encounterName, difficultyID, groupSize = ...
            K:SafeCall(function() E:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize) end)
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            K:SafeCall(function() E:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success) end)
        elseif event == "CRITERIA_UPDATE" then
            if K.Tracker and K.Tracker.Refresh then K:SafeCall(function() K.Tracker:Refresh() end) end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            local unit = ...
            K:SafeCall(function() E:TrackUnit(unit, true) end)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local unit = ...
            K:SafeCall(function() E:TrackUnit(unit, false) end)
        elseif event == "PLAYER_TARGET_CHANGED" then
            K:SafeCall(function() E:TrackUnit("target", true) end)
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            K:SafeCall(function() E:TrackUnit("mouseover", true) end)
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local readEvent = rawget(_G, "CombatLogGetCurrentEventInfo")
            if type(readEvent) == "function" then
                E:OnCombatLogEvent(readEvent())
            end
        end
    end)

    local _, refused = K:RegisterEvents(frame, self:EventList())
    if #refused > 0 then
        K:Print(("|cffff9955This client refused %d event(s):|r %s"):format(#refused, table.concat(refused, ", ")))
    end

    -- A /reload inside an instance fires no zone change, so resolve now too.
    K:SafeCall(function() E:EnterInstance() end)
end

function E:Status()
    local state = self.state
    return {
        inInstance = state.inInstance,
        instanceName = state.instanceName,
        difficultyName = state.difficultyName,
        achievements = #state.achievements,
        mobRules = (function()
            local count = 0
            for _ in pairs(state.mobRules) do count = count + 1 end
            return count
        end)(),
        encounter = state.encounter and state.encounter.name or nil,
        mobSource = self:MobSource(),
        refusedEvents = K.RefusedEvents and K:RefusedEvents() or {},
    }
end
