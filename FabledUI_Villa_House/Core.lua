-- FabledUI_Villa_House -- house level and House XP.
--
-- Carved out of FabledUI_Villa (Villa_Endeavors.lua) on 2026-09-19 so the House
-- XP bar works with Villa switched off. Narrow on purpose: this addon knows
-- which house is yours, what level it is and how much favor it has. Nothing
-- else.
--
-- How the numbers are read is copied from Blizzard's own dashboard
-- (Blizzard_HousingDashboardHouseUpgrade.lua), not inferred:
--
--   * HOUSE_LEVEL_FAVOR_UPDATED carries { houseGUID, houseLevel, houseFavor }.
--     The payload IS the data; there is no getter to call afterwards.
--   * houseFavor is CUMULATIVE. Progress through the current level is
--       (favor - ForLevel(level)) / (ForLevel(level + 1) - ForLevel(level))
--     with ForLevel = C_Housing.GetHouseLevelFavorForLevel, a static lookup.
--   * C_Housing.GetCurrentHouseLevelFavor(guid) and GetPlayerOwnedHouses() are
--     REQUESTS. They return nothing; the answer arrives as an event.
--
-- WHICH HOUSE. A house GUID on this client is an opaque per-session handle --
-- the saved variables showed "Opaque-4". Blizzard's own dropdown compares them
-- across events, so a token is stable for one house within a session, but it
-- means nothing after a reload. 0.2.0 saved the token and trusted it: the first
-- house list of the next session did not contain "Opaque-4", VillaHouse concluded
-- the house was gone, adopted another and wiped good numbers, and the bar fell
-- back to "waiting" the moment the dashboard was opened (owner, 2026-09-21).
-- So:
--
--   * The token (state.houseGUID) is never treated as identity. A saved one is
--     restored only as a hint (state.tokenIsHint), see the request policy.
--   * Across sessions a house is "<neighborhoodName>#<plotID>" (state.houseKey).
--   * Known numbers are only ever replaced by a favor payload, or dropped when
--     the house list proves a house with a DIFFERENT key is now ours. Learning
--     or changing a token never wipes anything.
--
-- The request policy (see CLAUDE.md, "Never read the housing API on a timer").
--
--   * VILLA HOUSE NEVER REQUESTS THE HOUSE LIST. Not once, not early, not guarded.
--     0.2.1 called C_Housing.GetPlayerOwnedHouses() a single time at login,
--     "safely" before Blizzard_HousingDashboard was loaded -- and the House
--     Information tab came up blank (owner, 2026-09-21). The dashboard's house
--     dropdown requests the list from its own OnLoad, which runs BEFORE its
--     parent panel's OnLoad registers the HouseDropdown.* callbacks. Untouched,
--     that first reply is a server round trip and lands after everything is
--     wired. Primed by an earlier request, it comes straight back from cache
--     inside the dropdown's OnLoad, fires HouseListUpdated / HouseSelected at
--     nobody, and every later reply is identical so the dropdown's tCompare
--     guard drops it. Blank until reload. An early request is not the safe
--     case; it is the cause. The list is only ever HEARD, when Blizzard asks.
--   * There is no repeating timer anywhere in this addon. Every request hangs
--     off a discrete game event or a slash command, through a one-shot debounce.
--   * The favor request is the safe one: HousingUpgradeFrameMixin:OnEvent
--     nil-checks self.houseInfo before using the payload, and 0.2.0 made it at
--     every login with the tab intact. It is still never issued while the
--     dashboard is on screen.
--   * VillaHouse does not hook or touch any Blizzard housing frame. 0.2.1 also
--     hooked the dashboard's OnHide; that was the other difference from the
--     known-good 0.2.0, so it went too. It was never shown to be at fault.
--
-- Where a token comes from, then: the tracked-house API, a favor payload, a
-- house list Blizzard asked for, or last session's token kept as a HINT (it
-- survives a /reload, not a client restart). A hint is only ever used to ask
-- for favor; it is never compared against a list and never filters a payload.

local addonName = ...

local VillaHouse = {}
_G.FabledUI_Villa_House = VillaHouse

VillaHouse.VERSION = "0.2.2"
VillaHouse.ADDON_NAME = addonName or "FabledUI_Villa_House"

local PREFIX = "|cffffb81c[Villa House]|r "
local FAVOR_DEBOUNCE = 1.0
local BOOTSTRAP_DELAY = 3.0

local issecretvalue = _G.issecretvalue or function() return false end

function VillaHouse.Print(...)
    print(PREFIX, ...)
end

-- Secret check first, then type, then anything else (CLAUDE.md, secret values).
local function usableGUID(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" then return nil end
    if value == "" then return nil end
    return value
end

local function usableString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

-- -----------------------------------------------------------------------------
-- API seam. Every housing call goes through this table so the policy above is
-- auditable in one place, and so tests can substitute it: the simulator shadows
-- C_Housing, so a test cannot stub the global, but it can replace these.
-- -----------------------------------------------------------------------------

local function callNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and type(value) == "number" then return value end
    return nil
end

local function callGUID(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return usableGUID(value)
end

VillaHouse.Api = {
    -- Cumulative favor needed to REACH `level`. Static, no server round trip.
    LevelFavor = function(level)
        return callNumber(C_Housing and C_Housing.GetHouseLevelFavorForLevel, level)
    end,

    MaxLevel = function()
        return callNumber(C_Housing and C_Housing.GetMaxHouseLevel)
    end,

    -- The house ticked "Show as Experience Bar" in the dashboard. Synchronous.
    TrackedHouse = function()
        return callGUID(C_Housing and C_Housing.GetTrackedHouseGuid)
    end,

    -- The neighborhood whose endeavor you are working on. Synchronous.
    ActiveNeighborhood = function()
        return callGUID(C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetActiveNeighborhood)
    end,

    -- Answers with HOUSE_LEVEL_FAVOR_UPDATED.
    RequestFavor = function(houseGUID)
        if C_Housing and C_Housing.GetCurrentHouseLevelFavor then
            pcall(C_Housing.GetCurrentHouseLevelFavor, houseGUID)
        end
    end,

    -- There is deliberately no RequestHouseList here. See the header.

    DashboardShown = function()
        local frame = rawget(_G, "HousingDashboardFrame")
        if not frame or type(frame.IsShown) ~= "function" then return false end
        local ok, shown = pcall(frame.IsShown, frame)
        return ok and shown and true or false
    end,

    -- What Blizzard's Endeavors tab shows on its House XP icon. Read on hover
    -- only, never on a schedule.
    AvailableEndeavorXP = function()
        return callNumber(C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetAvailableHouseXP)
    end,

    Now = function()
        return (GetServerTime and GetServerTime()) or 0
    end,
}

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

function VillaHouse.NewState()
    return {
        houseGUID   = nil,   -- opaque token; good for asking, never for identity
        tokenIsHint = false, -- true while houseGUID is only last session's saved token
        houseKey    = nil,   -- "<neighborhoodName>#<plotID>", the durable identity
        houseName   = nil,
        houseLevel  = 0,
        houseFavor  = 0,     -- cumulative
        levelFloor  = nil,   -- cumulative favor at the start of houseLevel
        levelCeil   = nil,   -- cumulative favor at houseLevel + 1
        maxLevel    = nil,
        isMaxLevel  = false,
        known       = false, -- any data at all, including last session's
        confirmed   = false, -- a live payload has arrived this session
        sessionGain = 0,
        lastGain    = 0,
        lastUpdate  = 0,
    }
end

VillaHouse.state = VillaHouse.NewState()

function VillaHouse:DB()
    local db = rawget(_G, "FabledUI_VillaHouseDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_VillaHouseDB = db
    end
    if type(db.house) ~= "table" then db.house = {} end
    if type(db.bar) ~= "table" then db.bar = {} end
    return db
end

function VillaHouse:Save()
    local house = self:DB().house
    local s = self.state
    house.guid = nil -- 0.2.0's field; it was read back as identity. Gone.
    house.tokenHint = s.houseGUID
    house.key = s.houseKey
    house.name = s.houseName
    house.level = s.houseLevel
    house.favor = s.houseFavor
    house.floor = s.levelFloor
    house.ceil = s.levelCeil
    house.time = s.lastUpdate
end

-- Last session's numbers, so the bar has something to show before the first
-- live payload. Marked unconfirmed; the bar draws it greyed. The saved token
-- comes back as a hint only: it is still valid after a /reload, which is the
-- common case, and without it the bar could not refresh until the dashboard
-- had been opened. After a client restart it is stale and simply gets no reply.
function VillaHouse:LoadSaved()
    local house = self:DB().house
    if type(house.level) ~= "number" or type(house.favor) ~= "number" then
        return false
    end
    local s = self.state
    s.houseGUID = usableGUID(house.tokenHint)
    s.tokenIsHint = s.houseGUID ~= nil
    s.houseKey = usableString(house.key)
    s.houseName = usableString(house.name)
    s.houseLevel = house.level
    s.houseFavor = house.favor
    s.levelFloor = tonumber(house.floor)
    s.levelCeil = tonumber(house.ceil)
    s.lastUpdate = tonumber(house.time) or 0
    s.known = true
    s.confirmed = false
    self:RecomputeThresholds()
    return true
end

function VillaHouse:RecomputeThresholds()
    local s = self.state
    local level = s.houseLevel
    if type(level) ~= "number" or level <= 0 then return end

    -- Keep the saved thresholds when the lookup is unavailable, rather than
    -- blanking a bar that was rendering fine.
    local floor = self.Api.LevelFavor(level)
    local ceil = self.Api.LevelFavor(level + 1)
    if floor then s.levelFloor = floor end
    if ceil then s.levelCeil = ceil end

    local maxLevel = self.Api.MaxLevel()
    if maxLevel then s.maxLevel = maxLevel end
    s.isMaxLevel = (s.maxLevel ~= nil and level >= s.maxLevel) and true or false
end

-- -----------------------------------------------------------------------------
-- Public read API. Other addons (Nexus, Villa) read these; they never call the
-- housing API themselves.
-- -----------------------------------------------------------------------------

-- Returns nil when nothing is known yet.
function VillaHouse:GetProgress()
    local s = self.state
    if not s.known then return nil end

    local progress = {
        level     = s.houseLevel,
        favor     = s.houseFavor,
        isMax     = s.isMaxLevel,
        confirmed = s.confirmed,
        into      = 0,
        span      = 0,
        remaining = 0,
        fraction  = 0,
    }

    if s.isMaxLevel then
        progress.fraction = 1
        return progress
    end

    local floor, ceil = s.levelFloor, s.levelCeil
    if type(floor) == "number" and type(ceil) == "number" and ceil > floor then
        local into = s.houseFavor - floor
        if into < 0 then into = 0 end
        local span = ceil - floor
        progress.into = into
        progress.span = span
        progress.remaining = math.max(0, ceil - s.houseFavor)
        progress.fraction = math.min(1, into / span)
    end
    return progress
end

function VillaHouse:GetSummaryText()
    local p = self:GetProgress()
    if not p then return "House: waiting" end
    if p.isMax then
        return string.format("House Lv %d | Max", p.level)
    end
    if p.span <= 0 then
        return string.format("House Lv %d", p.level)
    end
    return string.format("House Lv %d | %d%% | %d to go",
        p.level, math.floor(p.fraction * 100), p.remaining)
end

VillaHouse._callbacks = {}

function VillaHouse:RegisterCallback(owner, fn)
    if owner == nil or type(fn) ~= "function" then return end
    self._callbacks[owner] = fn
end

-- A listener's failure is isolated but never silent (the same bare pcall hid a
-- paint error in Villa_Decor 0.1.0).
function VillaHouse._Report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

function VillaHouse:Fire()
    for _, fn in pairs(self._callbacks) do
        local ok, err = pcall(fn, self.state)
        if not ok then VillaHouse._Report(err) end
    end
end

-- -----------------------------------------------------------------------------
-- Which house
-- -----------------------------------------------------------------------------

local function houseKeyOf(info)
    if type(info) ~= "table" then return nil end
    local plot = tonumber(info.plotID)
    local neighborhood = usableString(info.neighborhoodName)
    if not plot or not neighborhood then return nil end
    return neighborhood .. "#" .. plot
end
VillaHouse._HouseKeyOf = houseKeyOf

-- Point at a house. `key` may be nil when only a token is known (the tracked
-- house API gives no plot or name). Returns true when anything changed.
--
-- The one rule: numbers are dropped ONLY when both the old and the new key are
-- known and they differ -- that is a different house. A new or changed token
-- for the same (or an unidentified) house keeps the numbers and marks them
-- unconfirmed until the next payload.
function VillaHouse:SetHouse(houseGUID, key, name)
    local guid = usableGUID(houseGUID)
    if not guid then return false end
    local s = self.state

    local differentHouse = key ~= nil and s.houseKey ~= nil and key ~= s.houseKey
    if differentHouse then
        local fresh = self.NewState()
        fresh.sessionGain = s.sessionGain
        self.state = fresh
        s = fresh
    end

    local changed = differentHouse or guid ~= s.houseGUID
    if guid ~= s.houseGUID then
        s.houseGUID = guid
        s.confirmed = false
    end
    s.tokenIsHint = false -- whatever it was, this one came from the live client
    if key and key ~= s.houseKey then
        s.houseKey = key
        changed = true
    end
    if name and name ~= s.houseName then
        s.houseName = name
        changed = true
    end
    return changed
end

-- Same order of preference as Blizzard's dashboard dropdown, with the explicit
-- "Show as Experience Bar" house in front: tracked, the house we already had
-- (by durable key, then by this session's token), the house in the active
-- endeavor neighborhood, then the first.
function VillaHouse:ChooseHouse(houseInfos)
    if type(houseInfos) ~= "table" then return nil end
    local tracked = self.Api.TrackedHouse()
    local active = self.Api.ActiveNeighborhood()
    local s = self.state

    local byTracked, byKey, byToken, byActive, first
    for _, info in ipairs(houseInfos) do
        local guid = type(info) == "table" and usableGUID(info.houseGUID) or nil
        if guid then
            first = first or info
            if tracked and guid == tracked then byTracked = byTracked or info end
            if s.houseKey and houseKeyOf(info) == s.houseKey then byKey = byKey or info end
            -- A hint is never compared against a list; that was the 0.2.0 bug.
            if s.houseGUID and not s.tokenIsHint and guid == s.houseGUID then byToken = byToken or info end
            if active and usableGUID(info.neighborhoodGUID) == active then byActive = byActive or info end
        end
    end
    return byTracked or byKey or byToken or byActive or first
end

-- -----------------------------------------------------------------------------
-- Requests
-- -----------------------------------------------------------------------------

function VillaHouse:_RequestFavorNow()
    local guid = self.state.houseGUID
    if not guid then return false end
    if self.Api.DashboardShown() then
        -- Dropped, not queued. While it is open Blizzard is asking for favor
        -- itself and the payload reaches us anyway; the next task or decor
        -- event asks again once it is shut.
        self._favorWanted = true
        return false
    end
    self._favorWanted = false
    self.Api.RequestFavor(guid)
    return true
end

-- One-shot debounce: a burst of decor purchases becomes one request, and the
-- request leaves whatever Blizzard call stack the triggering event came from.
function VillaHouse:RequestFavorSoon()
    if self._favorPending then return end
    if not (C_Timer and C_Timer.After) then
        self:_RequestFavorNow()
        return
    end
    self._favorPending = true
    C_Timer.After(FAVOR_DEBOUNCE, function()
        VillaHouse._favorPending = false
        VillaHouse:_RequestFavorNow()
    end)
end

function VillaHouse:Bootstrap()
    local tracked = self.Api.TrackedHouse()
    if tracked and self:SetHouse(tracked) then
        self:Fire()
    end

    -- A real token or last session's hint: either is worth one favor request.
    -- With neither there is nothing to ask with, and nothing is asked -- the
    -- bar shows last session's numbers until the dashboard is opened once and
    -- Blizzard's own house list is overheard. See the header for why VillaHouse
    -- does not go and fetch that list itself.
    if self.state.houseGUID then
        self:RequestFavorSoon()
    end
end

-- -----------------------------------------------------------------------------
-- Event handlers. Payload only -- none of these call back into the housing API
-- except through the guarded requests above.
-- -----------------------------------------------------------------------------

function VillaHouse:OnHouseListUpdated(houseInfos)
    local chosen = self:ChooseHouse(houseInfos)
    if not chosen then return end

    if self:SetHouse(chosen.houseGUID, houseKeyOf(chosen), usableString(chosen.houseName)) then
        self:Fire()
    end
    if not self.state.confirmed then
        self:RequestFavorSoon()
    end
end

function VillaHouse:OnFavorUpdated(info)
    if type(info) ~= "table" then return end
    local level = tonumber(info.houseLevel)
    local favor = tonumber(info.houseFavor)
    if not level or not favor then return end

    local guid = usableGUID(info.houseGUID)
    local s = self.state
    local haveRealToken = s.houseGUID ~= nil and not s.tokenIsHint
    if haveRealToken and guid and guid ~= s.houseGUID then
        -- Another of your houses, picked in the dashboard dropdown.
        return
    end
    if (guid and guid ~= s.houseGUID) or s.tokenIsHint then
        -- No token yet, or only a hint: the payload's own token is the real one.
        self:SetHouse(guid or s.houseGUID)
        s = self.state
    end

    -- Gains only count between two live readings. The first payload of a
    -- session is compared against last session's number, which is not a gain.
    if s.confirmed and favor > s.houseFavor then
        s.lastGain = favor - s.houseFavor
        s.sessionGain = s.sessionGain + s.lastGain
    end

    s.houseLevel = level
    s.houseFavor = favor
    s.known = true
    s.confirmed = true
    s.lastUpdate = self.Api.Now()
    self:RecomputeThresholds()
    self:Save()
    self:Fire()
end

function VillaHouse:OnTrackedHouseChanged(trackedHouse)
    -- The tracked-house API gives a token and nothing else, so this cannot tell
    -- whether it is a different house. Keep the numbers, grey them, and let the
    -- next payload (or the next house list) settle it.
    if self:SetHouse(trackedHouse) then
        self:Fire()
        self:RequestFavorSoon()
    end
end

-- -----------------------------------------------------------------------------
-- Wiring
-- -----------------------------------------------------------------------------

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_HOUSE_LIST_UPDATED",
    "HOUSE_LEVEL_FAVOR_UPDATED",
    "HOUSE_LEVEL_CHANGED",
    "TRACKED_HOUSE_CHANGED",
    -- The two things that award House XP while the dashboard is shut: finishing
    -- an endeavor task, and collecting a decor item for the first time.
    "INITIATIVE_TASK_COMPLETED",
    "NEW_HOUSING_ITEM_ACQUIRED",
}

VillaHouse._refusedEvents = {}

local function onEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == VillaHouse.ADDON_NAME then
            VillaHouse:LoadSaved()
            if VillaHouse.Bar and VillaHouse.Bar.Build then VillaHouse.Bar:Build() end
            VillaHouse:Fire()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if (isLogin or isReload) and C_Timer and C_Timer.After then
            C_Timer.After(BOOTSTRAP_DELAY, function() VillaHouse:Bootstrap() end)
        end
    elseif event == "PLAYER_HOUSE_LIST_UPDATED" then
        VillaHouse:OnHouseListUpdated(...)
    elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" then
        VillaHouse:OnFavorUpdated(...)
    elseif event == "TRACKED_HOUSE_CHANGED" then
        VillaHouse:OnTrackedHouseChanged(...)
    elseif event == "HOUSE_LEVEL_CHANGED"
        or event == "INITIATIVE_TASK_COMPLETED"
        or event == "NEW_HOUSING_ITEM_ACQUIRED" then
        VillaHouse:RequestFavorSoon()
    end
end

-- SetScript before RegisterEvent, one event at a time: an event this client
-- refuses must not leave the frame half-registered with no handler.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", onEvent)
for _, event in ipairs(EVENTS) do
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then
        VillaHouse._refusedEvents[#VillaHouse._refusedEvents + 1] = event
    end
end
VillaHouse._eventFrame = eventFrame

-- -----------------------------------------------------------------------------
-- Slash
-- -----------------------------------------------------------------------------

function VillaHouse:PrintStatus()
    local s = self.state
    self.Print(self:GetSummaryText())
    self.Print(string.format("house: %s (%s) | token: %s%s | tracked: %s",
        tostring(s.houseName), tostring(s.houseKey), tostring(s.houseGUID),
        s.tokenIsHint and " (hint from last session)" or "", tostring(self.Api.TrackedHouse())))
    self.Print(string.format("favor %s | level floor %s | next level at %s | max level %s",
        tostring(s.houseFavor), tostring(s.levelFloor), tostring(s.levelCeil), tostring(s.maxLevel)))
    self.Print(string.format("live this session: %s | session gain: +%d (last +%d) | last request held back by open dashboard: %s",
        tostring(s.confirmed), s.sessionGain, s.lastGain, tostring(self._favorWanted and true or false)))
    if #self._refusedEvents > 0 then
        self.Print("refused events: " .. table.concat(self._refusedEvents, ", "))
    end
end

SLASH_FABLEDUI_VILLAHOUSE1 = "/vhouse"
SlashCmdList["FABLEDUI_VILLAHOUSE"] = function(msg)
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local bar = VillaHouse.Bar

    if cmd == "tasks" or cmd == "list" then
        if VillaHouse.TaskList then VillaHouse.TaskList:Toggle() end
    elseif cmd == "lock" or cmd == "unlock" then
        if bar then bar:SetLocked(cmd == "lock") end
        VillaHouse.Print("Bar " .. (cmd == "lock" and "locked." or "unlocked. Drag it where you want it."))
    elseif cmd == "show" or cmd == "hide" then
        if bar then bar:SetShown(cmd == "show") end
    elseif cmd == "reset" then
        if bar then bar:ResetPosition() end
        VillaHouse.Print("Bar position reset.")
    elseif cmd == "refresh" then
        if VillaHouse.state.houseGUID then
            VillaHouse:RequestFavorSoon()
            VillaHouse.Print("Asked for fresh House XP.")
        else
            VillaHouse.Print("No house token yet this session. Open the Housing Dashboard once and it will be picked up.")
        end
    elseif cmd == "status" or cmd == "debug" then
        VillaHouse:PrintStatus()
    else
        VillaHouse.Print("/vhouse tasks | lock | unlock | show | hide | reset | refresh | status")
    end
end
