-- FabledUI_Prey_Journey -- Preyhunter's Journey level and progress.
--
-- Narrow on purpose: this addon knows which major faction is the Prey journey,
-- what level it is at and how far into that level you are. Nothing else. The
-- achievement lines on the hunt map belong to FabledUI_Prey_Tooltip.
--
-- How the numbers are read is copied from Blizzard's own Journeys page
-- (Blizzard_EncounterJournal/Mainline/Blizzard_Journeys.lua,
-- JourneyProgressFrameMixin:SetupProgressDetails, live source 2026-10-06), not
-- inferred:
--
--   * Prey is a major faction that C_MajorFactions.ShouldDisplayMajorFactionAsJourney
--     says to draw as a journey (Blizzard's comment: "Currently: Prey, Delves").
--   * Below max: level = renownLevel, progress = renownReputationEarned out of
--     renownLevelThreshold. That is the page's "Current Progress: 1475 / 4000".
--   * At max with paragon: level = renownLevel + paragon storage level,
--     progress = value - threshold * storageLevel, out of threshold.
--   * At max without paragon: a full bar.
--
-- WHICH FACTION. 2808, taken from HousingCodex's renown import
-- (FabledUI_DataVault_Villa/RenownData.lua lists [2808] "Preyhunter's
-- Journey"). It is only trusted when the client both knows that id and says to
-- draw it as a journey. Otherwise the current expansion's journeys are searched
-- for a name containing "Prey". A faction id is a database id, stable across
-- sessions (unlike a housing GUID), so the answer is saved.
--
-- THE HUNT IN PROGRESS (0.2.0). C_QuestLog.GetActivePreyQuest() is the quest
-- Blizzard's own prey widget reads. Its title carries target and difficulty
-- ("Prey: Praetor Singularis (Hard)"); its zone is GetQuestUiMapID(questID,
-- true), as the widget's click asks it. Shown as one line above the bar.
--
-- No timer anywhere. Every read hangs off a game event through a one-shot
-- debounce, or off a hover or slash command.

local addonName = ...

local Journey = {}
_G.FabledUI_Prey_Journey = Journey

Journey.VERSION = "0.2.0"
Journey.ADDON_NAME = addonName or "FabledUI_Prey_Journey"
Journey.KNOWN_FACTION_ID = 2808
Journey.NAME_HINT = "prey"

local PREFIX = "|cffd1333f[Prey Journey]|r "
local READ_DEBOUNCE = 0.5

local issecretvalue = _G.issecretvalue or function() return false end

function Journey.Print(...)
    print(PREFIX, ...)
end

-- Secret check first, then type, then anything else (CLAUDE.md, secret values).
local function usableString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

local function usableNumber(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

-- -----------------------------------------------------------------------------
-- API seam. Every game call goes through this table so tests can substitute
-- it: the simulator shadows its own globals, so a test cannot stub
-- C_MajorFactions, but it can replace these.
-- -----------------------------------------------------------------------------

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

Journey.Api = {
    FactionData = function(factionID)
        local ok, data = call(C_MajorFactions and C_MajorFactions.GetMajorFactionData, factionID)
        if ok and type(data) == "table" then return data end
        return nil
    end,

    IsJourney = function(factionID)
        local ok, value = call(C_MajorFactions and C_MajorFactions.ShouldDisplayMajorFactionAsJourney, factionID)
        return ok and value == true
    end,

    CurrentExpansionFactionIDs = function()
        local expansion = rawget(_G, "LE_EXPANSION_LEVEL_CURRENT")
        local ok, ids = call(C_MajorFactions and C_MajorFactions.GetMajorFactionIDs, expansion)
        if ok and type(ids) == "table" then return ids end
        return {}
    end,

    HasMaxRenown = function(factionID)
        local ok, value = call(C_MajorFactions and C_MajorFactions.HasMaximumRenown, factionID)
        return ok and value == true
    end,

    WeeklyCapped = function(factionID)
        local ok, value = call(C_MajorFactions and C_MajorFactions.IsWeeklyRenownCapped, factionID)
        return ok and value == true
    end,

    -- value, threshold, storageLevel -- or nil when the faction is not paragon.
    Paragon = function(factionID)
        local reputation = rawget(_G, "C_Reputation")
        if type(reputation) ~= "table" then return nil end
        local ok, isParagon = call(reputation.IsFactionParagon, factionID)
        if not ok or not isParagon then return nil end
        local ok2, value, threshold, _, _, _, storageLevel = call(reputation.GetFactionParagonInfo, factionID)
        if not ok2 then return nil end
        return usableNumber(value), usableNumber(threshold), usableNumber(storageLevel)
    end,

    -- questID, title of the hunt in progress, or nil.
    ActiveHunt = function()
        local questLog = rawget(_G, "C_QuestLog")
        if type(questLog) ~= "table" then return nil end
        local ok, questID = call(questLog.GetActivePreyQuest)
        questID = ok and usableNumber(questID) or nil
        if not questID or questID <= 0 then return nil end
        local ok2, title = call(questLog.GetTitleForQuestID, questID)
        return questID, ok2 and usableString(title) or nil
    end,

    -- The quest's map, asked the way Blizzard's prey widget asks it
    -- (GetQuestUiMapID(questID, true)), walked up to its zone. mapID, zoneName.
    QuestZone = function(questID)
        local ok, mapID = call(rawget(_G, "GetQuestUiMapID"), questID, true)
        mapID = ok and usableNumber(mapID) or nil
        if not mapID or mapID <= 0 then return nil end
        local map = rawget(_G, "C_Map")
        if type(map) ~= "table" then return mapID, nil end
        local cursor, guard = mapID, 0
        while cursor and cursor > 0 and guard < 6 do
            local okInfo, info = call(map.GetMapInfo, cursor)
            if not okInfo or type(info) ~= "table" then break end
            local mapType = usableNumber(info.mapType)
            if mapType and mapType <= 3 then -- Enum.UIMapType.Zone
                return mapID, usableString(info.name)
            end
            cursor = usableNumber(info.parentMapID)
            guard = guard + 1
        end
        return mapID, nil
    end,

    -- { text, done } per objective.
    QuestObjectives = function(questID)
        local questLog = rawget(_G, "C_QuestLog")
        local list = {}
        if type(questLog) ~= "table" then return list end
        local ok, objectives = call(questLog.GetQuestObjectives, questID)
        if not ok or type(objectives) ~= "table" then return list end
        for _, objective in ipairs(objectives) do
            local text = type(objective) == "table" and usableString(objective.text)
            if text then list[#list + 1] = { text = text, done = objective.finished == true } end
        end
        return list
    end,

    -- What clicking Blizzard's prey widget does: open the world map on the
    -- hunt's map and ping the quest.
    OpenHuntMap = function(questID, mapID)
        local open = rawget(_G, "OpenWorldMap")
        if type(open) ~= "function" then return false end
        if not pcall(open, mapID) then return false end
        local registry = rawget(_G, "EventRegistry")
        if type(registry) == "table" and type(registry.TriggerEvent) == "function" then
            pcall(registry.TriggerEvent, registry, "MapCanvas.PingQuestID", questID)
        end
        return true
    end,

    InCombat = function()
        return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
    end,

    OpenJourney = function(factionID)
        if type(rawget(_G, "EncounterJournal_OpenToJourney")) ~= "function" then
            local load = rawget(_G, "EncounterJournal_LoadUI")
            if type(load) == "function" then pcall(load) end
        end
        local open = rawget(_G, "EncounterJournal_OpenToJourney")
        if type(open) ~= "function" then return false end
        local ok = pcall(open, factionID)
        return ok
    end,
}

-- -----------------------------------------------------------------------------
-- Saved variables
-- -----------------------------------------------------------------------------

function Journey:DB()
    local db = rawget(_G, "FabledUI_PreyJourneyDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_PreyJourneyDB = db
    end
    if type(db.bar) ~= "table" then db.bar = {} end
    return db
end

-- -----------------------------------------------------------------------------
-- Which faction
-- -----------------------------------------------------------------------------

local function nameLooksLikePrey(data)
    local name = type(data) == "table" and usableString(data.name)
    return name and name:lower():find(Journey.NAME_HINT, 1, true) ~= nil or false
end

-- A candidate is accepted when the client knows it AND draws it as a journey.
local function isPreyJourney(id)
    if type(id) ~= "number" then return false end
    if not Journey.Api.FactionData(id) then return false end
    return Journey.Api.IsJourney(id)
end

function Journey:ResolveFaction()
    if self.factionID then return self.factionID end
    local db = self:DB()

    local saved = tonumber(db.factionID)
    if saved and isPreyJourney(saved) then
        self.factionID = saved
        return saved
    end

    if isPreyJourney(self.KNOWN_FACTION_ID) then
        self.factionID = self.KNOWN_FACTION_ID
        db.factionID = self.factionID
        return self.factionID
    end

    for _, id in ipairs(self.Api.CurrentExpansionFactionIDs()) do
        if self.Api.IsJourney(id) and nameLooksLikePrey(self.Api.FactionData(id)) then
            self.factionID = id
            db.factionID = id
            return id
        end
    end
    return nil
end

-- -----------------------------------------------------------------------------
-- Reading
-- -----------------------------------------------------------------------------

-- One snapshot of the journey, or nil when the client has no Prey journey.
function Journey:Read()
    local id = self:ResolveFaction()
    if not id then return nil end
    local data = self.Api.FactionData(id)
    if not data then return nil end

    local snap = {
        factionID = id,
        name      = usableString(data.name) or "Preyhunter's Journey",
        unlocked  = data.isUnlocked == true,
        level     = usableNumber(data.renownLevel) or 0,
        maxLevel  = usableNumber(data.maxLevel) or 0,
        earned    = usableNumber(data.renownReputationEarned) or 0,
        threshold = usableNumber(data.renownLevelThreshold) or 0,
        paragon   = false,
        paragonLevel = 0,
    }
    snap.isMax = self.Api.HasMaxRenown(id) or (snap.maxLevel > 0 and snap.level >= snap.maxLevel)
    snap.displayLevel = snap.level

    if snap.isMax then
        local value, threshold, storageLevel = self.Api.Paragon(id)
        if value and threshold and threshold > 0 then
            snap.paragon = true
            snap.threshold = threshold
            if storageLevel then
                snap.paragonLevel = storageLevel
                snap.earned = value - threshold * storageLevel
            else
                snap.paragonLevel = math.floor(value / threshold)
                snap.earned = value % threshold
            end
            snap.displayLevel = snap.level + snap.paragonLevel
        else
            snap.earned = snap.threshold
        end
    end

    snap.weeklyCapped = self.Api.WeeklyCapped(id)
    return snap
end

-- "Prey: Praetor Singularis (Hard)" -> "Praetor Singularis", "Hard". The hunt
-- quests are titled that way (Wowhead: quest 91113 "Prey: Praetor Singularis
-- (Normal)", 91258 "... (Nightmare)"). A title in another shape comes back
-- whole, with no difficulty.
function Journey.ParseHuntTitle(title)
    title = usableString(title)
    if not title then return nil, nil end
    local body = title:match("^[^:]+:%s*(.+)$") or title
    local target, difficulty = body:match("^(.-)%s*%(([^()]+)%)%s*$")
    if target and target ~= "" then return target, difficulty end
    return body, nil
end

-- The hunt in progress: { questID, target, difficulty, mapID, zone,
-- objectives }, or nil when there is none.
function Journey:ReadHunt()
    local questID, title = self.Api.ActiveHunt()
    if not questID then return nil end
    local target, difficulty = self.ParseHuntTitle(title)
    local mapID, zone = self.Api.QuestZone(questID)
    return {
        questID    = questID,
        title      = title,
        target     = target or ("Quest " .. questID),
        difficulty = difficulty,
        mapID      = mapID,
        zone       = zone,
        objectives = self.Api.QuestObjectives(questID),
    }
end

-- -----------------------------------------------------------------------------
-- State and public read API. Other addons (Nexus) read these; they never call
-- C_MajorFactions for the journey themselves.
-- -----------------------------------------------------------------------------

function Journey.NewState()
    return {
        snap        = nil,
        hunt        = nil,
        sessionGain = 0,
        lastGain    = 0,
    }
end

Journey.state = Journey.NewState()

-- Gain between two readings. Journey thresholds are flat per level (Blizzard's
-- reward-track bar multiplies one threshold by the level count), so the
-- distance is levels * threshold + the difference in earned. Readings with
-- different thresholds are not compared rather than guessed at.
function Journey.GainBetween(old, new)
    if type(old) ~= "table" or type(new) ~= "table" then return 0 end
    if old.factionID ~= new.factionID then return 0 end
    if old.threshold ~= new.threshold or new.threshold <= 0 then return 0 end
    local gain = (new.displayLevel - old.displayLevel) * new.threshold + (new.earned - old.earned)
    if gain < 0 then return 0 end
    return gain
end

function Journey:Refresh()
    local snap = self:Read()
    local s = self.state
    if snap and s.snap then
        local gain = self.GainBetween(s.snap, snap)
        if gain > 0 then
            s.lastGain = gain
            s.sessionGain = s.sessionGain + gain
        end
    end
    s.snap = snap
    s.hunt = self:ReadHunt()
    self:Fire()
    return snap
end

-- The hunt in progress, or nil.
function Journey:GetHunt()
    return self.state.hunt
end

-- "Praetor Singularis (Hard) - Eversong Woods", or nil with no hunt.
function Journey:GetHuntText()
    local hunt = self.state.hunt
    if not hunt then return nil end
    local text = hunt.target
    if hunt.difficulty then text = text .. " (" .. hunt.difficulty .. ")" end
    if hunt.zone then text = text .. " - " .. hunt.zone end
    return text
end

-- Returns nil when nothing is known yet.
function Journey:GetProgress()
    local snap = self.state.snap
    if not snap then return nil end

    local progress = {
        factionID    = snap.factionID,
        name         = snap.name,
        unlocked     = snap.unlocked,
        level        = snap.displayLevel,
        renownLevel  = snap.level,
        maxLevel     = snap.maxLevel,
        isMax        = snap.isMax,
        paragon      = snap.paragon,
        weeklyCapped = snap.weeklyCapped,
        into         = 0,
        span         = 0,
        remaining    = 0,
        fraction     = 0,
    }

    if snap.isMax and not snap.paragon then
        progress.into, progress.span, progress.fraction = snap.threshold, snap.threshold, 1
        return progress
    end

    if snap.threshold > 0 then
        local into = math.max(0, math.min(snap.earned, snap.threshold))
        progress.into = into
        progress.span = snap.threshold
        progress.remaining = snap.threshold - into
        progress.fraction = into / snap.threshold
    end
    return progress
end

function Journey:GetSummaryText()
    local p = self:GetProgress()
    if not p then return "Prey: waiting" end
    if not p.unlocked then return "Prey: locked" end
    if p.isMax and not p.paragon then
        return string.format("Prey %d | Max", p.level)
    end
    if p.span <= 0 then
        return string.format("Prey %d", p.level)
    end
    return string.format("Prey %d | %d%% | %d to go", p.level, math.floor(p.fraction * 100), p.remaining)
end

Journey._callbacks = {}

function Journey:RegisterCallback(owner, fn)
    if owner == nil or type(fn) ~= "function" then return end
    self._callbacks[owner] = fn
end

-- A listener's failure is isolated but never silent.
function Journey._Report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

function Journey:Fire()
    for _, fn in pairs(self._callbacks) do
        local ok, err = pcall(fn, self.state)
        if not ok then Journey._Report(err) end
    end
end

-- One-shot debounce: a burst of reputation events becomes one read, and the
-- read leaves whatever Blizzard call stack the triggering event came from.
function Journey:RefreshSoon()
    if self._readPending then return end
    if not (C_Timer and C_Timer.After) then
        self:Refresh()
        return
    end
    self._readPending = true
    C_Timer.After(READ_DEBOUNCE, function()
        Journey._readPending = false
        local ok, err = pcall(Journey.Refresh, Journey)
        if not ok then Journey._Report(err) end
    end)
end

function Journey:Open()
    local id = self:ResolveFaction()
    if not id then
        self.Print("No Preyhunter's Journey on this character yet.")
        return false
    end
    if self.Api.InCombat() then
        self.Print("Can't open the journal in combat.")
        return false
    end
    return self.Api.OpenJourney(id)
end

function Journey:OpenHunt()
    local hunt = self:ReadHunt()
    if not hunt then
        self.Print("No Prey hunt in progress.")
        return false
    end
    if self.Api.InCombat() then
        self.Print("Can't open the map in combat.")
        return false
    end
    return self.Api.OpenHuntMap(hunt.questID, hunt.mapID)
end

-- -----------------------------------------------------------------------------
-- Wiring
-- -----------------------------------------------------------------------------

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "UPDATE_FACTION",
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "MAJOR_FACTION_UNLOCKED",
    "QUEST_TURNED_IN",
    -- The hunt line: taken, dropped, objectives moved.
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_LOG_UPDATE",
}

Journey._refusedEvents = {}

local function onEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == Journey.ADDON_NAME then
            if Journey.Bar and Journey.Bar.Build then Journey.Bar:Build() end
            Journey:RefreshSoon()
        end
    else
        Journey:RefreshSoon()
    end
end

-- SetScript before RegisterEvent, one event at a time: an event this client
-- refuses must not leave the frame half-registered with no handler.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", onEvent)
for _, event in ipairs(EVENTS) do
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then
        Journey._refusedEvents[#Journey._refusedEvents + 1] = event
    end
end
Journey._eventFrame = eventFrame

-- -----------------------------------------------------------------------------
-- Slash
-- -----------------------------------------------------------------------------

function Journey:PrintStatus()
    self.Print(self:GetSummaryText())
    local snap = self.state.snap
    self.Print(string.format("faction: %s (saved %s, known id %d)",
        tostring(self.factionID), tostring(self:DB().factionID), self.KNOWN_FACTION_ID))
    if snap then
        self.Print(string.format("%s | unlocked %s | renown %d/%d | earned %d of %d | max %s | paragon %s (+%d) | weekly cap %s",
            snap.name, tostring(snap.unlocked), snap.level, snap.maxLevel, snap.earned, snap.threshold,
            tostring(snap.isMax), tostring(snap.paragon), snap.paragonLevel, tostring(snap.weeklyCapped)))
    end
    local s = self.state
    self.Print(string.format("session gain: +%d (last +%d)", s.sessionGain, s.lastGain))
    local hunt = self:ReadHunt()
    if hunt then
        self.Print(string.format("hunt: quest %d \"%s\" -> target %s | difficulty %s | map %s | zone %s",
            hunt.questID, tostring(hunt.title), hunt.target, tostring(hunt.difficulty),
            tostring(hunt.mapID), tostring(hunt.zone)))
        for _, objective in ipairs(hunt.objectives) do
            self.Print("  " .. objective.text .. (objective.done and " (done)" or ""))
        end
    else
        self.Print("hunt: none")
    end
    if #self._refusedEvents > 0 then
        self.Print("refused events: " .. table.concat(self._refusedEvents, ", "))
    end
end

SLASH_FABLEDUI_PREYJOURNEY1 = "/prey"
SlashCmdList["FABLEDUI_PREYJOURNEY"] = function(msg)
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local bar = Journey.Bar

    if cmd == "open" then
        Journey:Open()
    elseif cmd == "map" then
        Journey:OpenHunt()
    elseif cmd == "lock" or cmd == "unlock" then
        if bar then bar:SetLocked(cmd == "lock") end
        Journey.Print("Bar " .. (cmd == "lock" and "locked." or "unlocked. Drag it where you want it."))
    elseif cmd == "show" or cmd == "hide" then
        if bar then bar:SetShown(cmd == "show") end
    elseif cmd == "reset" then
        if bar then bar:ResetPosition() end
        Journey.Print("Bar position reset.")
    elseif cmd == "refresh" then
        Journey.factionID = nil
        Journey:Refresh()
        Journey:PrintStatus()
    elseif cmd == "status" or cmd == "debug" then
        Journey:PrintStatus()
    else
        Journey.Print("/prey open | map | lock | unlock | show | hide | reset | refresh | status")
    end
end
