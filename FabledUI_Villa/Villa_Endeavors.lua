-- Villa_Endeavors — runtime endeavors / house-favor / initiative state machine.
--
-- There is no catalog behind this and there never was. The header here used to
-- say the houseLevels/initiatives/tasks tables "live in the DataVault shard and
-- are populated by the offline pipeline" -- they were empty, nothing read them,
-- and no importer ever mentioned them. No donor has a static endeavors dataset
-- either, because initiative cycles rotate server-side and arrive in the event
-- payload. See FabledUI_DataVault_Villa/EndeavorsData.lua for the full note.
--
-- So this file is the whole of Endeavors: the live state plus the WoW 12.0.7
-- housing-event handlers Core.lua dispatches into.

local Villa = _G.FabledUI_Villa
if not Villa then return end

Villa.Endeavors = Villa.Endeavors or {}
local E = Villa.Endeavors

-- The state shape is defined once, in the shard, and built from there. It used
-- to be written out in full in both places; two copies of a contract is how the
-- two quietly stop matching. The shard is an OptionalDep, so fall back to a
-- bare table when it is not installed rather than coming up with no state at
-- all -- every field below is filled from the live APIs anyway.
local function newState()
    local providers = _G.FabledUI_DataVault_VillaProviders
    local codex = providers and providers["codex"]
    if codex and type(codex.NewEndeavorState) == "function" then
        return codex:NewEndeavorState()
    end
    return {
        isInNeighborhood = false,
        hasHouse         = false,
        houseLevel       = 0,
        houseFavor       = 0,
        taskSnapshots    = {},
        sessionProgress  = {},
    }
end

E.state = newState()

-- ----------------------------------------------------------------------------
-- WoW API helpers — guarded so a missing 12.0.7 surface doesn't crash on
-- /reload before the full client ships.
-- ----------------------------------------------------------------------------

local function safeCallAPI(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, result = pcall(api, ...)
    if not ok then return nil end
    return result
end

local function isOnNeighborhoodMap()
    if C_Housing and C_Housing.IsOnNeighborhoodMap then
        return safeCallAPI(C_Housing.IsOnNeighborhoodMap) and true or false
    end
    return false
end

local function isInsideHouse()
    if C_Housing and C_Housing.IsInsideHouseOrPlot then
        return safeCallAPI(C_Housing.IsInsideHouseOrPlot) and true or false
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Event handlers — called from Core.lua's event dispatcher.
-- ----------------------------------------------------------------------------

-- Is Blizzard's Housing Dashboard on screen right now?
--
-- While it is, Villa stays passive. The dashboard builds its House Information
-- tab from the same housing events and the same C_Housing calls this module
-- uses, and an addon requesting on those frames left the panel built but
-- EMPTY -- the frame resolved fine (`/villa debug` reported HouseInfo: true),
-- its data provider just never populated. Reading is fine; issuing requests
-- into a flow Blizzard is mid-way through consuming is not.
local function dashboardIsOpen()
    local frame = _G.HousingDashboardFrame or _G.PlayerHousingFrame or _G.HousingFrame
    if not frame or type(frame.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown and true or false
end
E._DashboardIsOpen = dashboardIsOpen

-- Ask the server for favor data, but never from inside a housing event handler.
--
-- RequestHouseLevelFavor re-fires PLAYER_HOUSE_LIST_UPDATED *synchronously* on
-- 12.0.7. Calling it from the handler for that event recursed until the C stack
-- overflowed and took the dashboard's tab pool down with it. A re-entrancy flag
-- stopped the overflow but left the request landing mid-build. Deferring to the
-- next frame takes it out of Blizzard's call stack entirely, which is the
-- structural fix rather than a guard around the symptom.
function E:RequestFavorSoon(houseGUID)
    if not houseGUID or self._favorRequestPending then return end
    if not (C_Housing and C_Housing.RequestHouseLevelFavor) then return end
    self._favorRequestPending = true
    C_Timer.After(0, function()
        E._favorRequestPending = false
        -- Re-check on arrival: the dashboard may have opened in between.
        if dashboardIsOpen() then return end
        if E.state.houseGUID ~= houseGUID then return end
        pcall(C_Housing.RequestHouseLevelFavor, houseGUID)
    end)
end

function E:OnHouseListUpdated()
    if not C_Housing then return end
    -- Belt and braces: the deferred request below means this should no longer
    -- be reachable re-entrantly, but the recursion it guards against crashed
    -- the client, so the flag stays.
    if self._inHouseListUpdate then return end
    self._inHouseListUpdate = true

    local houses = safeCallAPI(C_Housing.GetPlayerOwnedHouses)
    if type(houses) == "table" and houses[1] then
        local previousGUID = self.state.houseGUID
        self.state.hasHouse = true
        self.state.houseGUID = houses[1]
        -- Only when the house actually changed, never inside this call stack,
        -- and never while the dashboard is building.
        if houses[1] ~= previousGUID and not dashboardIsOpen() then
            self:RequestFavorSoon(houses[1])
        end
    else
        self.state.hasHouse = false
        self.state.houseGUID = nil
    end

    self._inHouseListUpdate = false
end

function E:OnHouseLevelUpdated()
    if not (C_Housing and self.state.houseGUID) then return end

    local level = safeCallAPI(C_Housing.GetHouseLevel, self.state.houseGUID)
    if type(level) == "number" then
        self.state.houseLevel = level
    end

    -- Favor data: prefer the canonical getter, fall back to RequestHouseLevelFavor's
    -- async dispatch. Names follow the documented C_Housing surface.
    local favorInfo = safeCallAPI(C_Housing.GetHouseLevelFavor, self.state.houseGUID)
    if type(favorInfo) == "table" then
        self.state.houseFavor = favorInfo.currentFavor or self.state.houseFavor
        self.state.houseFavorNeeded = favorInfo.favorNeeded or self.state.houseFavorNeeded
        self.state.houseFavorTotal = favorInfo.totalFavor or self.state.houseFavorTotal
        self.state.houseFavorTotalNeeded = favorInfo.totalFavorNeeded or self.state.houseFavorTotalNeeded
        self.state.isMaxLevel = favorInfo.isMaxLevel and true or false
    end

    if Villa.Dashboard and Villa.Dashboard.RefreshFavorBar then
        Villa.Dashboard:RefreshFavorBar()
    end
end

function E:OnInitiativeUpdated()
    if not C_NeighborhoodInitiative then return end

    local info = safeCallAPI(C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo)
    if not info then return end
    self.state.initiativeInfo = info
    self.state.initiativeDataFresh = true
    self.state.lastCycleID = info.cycleID or self.state.lastCycleID

    -- Snapshot task progress for delta tracking. Task IDs that already had a
    -- recorded snapshot get a session-progress delta entry so the UI can
    -- highlight "you advanced X by N this session".
    self.state.taskSnapshots = self.state.taskSnapshots or {}
    if type(info.tasks) == "table" then
        for _, task in ipairs(info.tasks) do
            local id = task.taskID
            if id then
                local prev = self.state.taskSnapshots[id]
                if prev then
                    local delta = (task.current or 0) - (prev.current or 0)
                    if delta ~= 0 then
                        self.state.sessionProgress = self.state.sessionProgress or {}
                        self.state.sessionProgress[id] = {
                            taskName = task.taskName,
                            current = task.current,
                            max = task.max,
                            delta = (self.state.sessionProgress[id] and self.state.sessionProgress[id].delta or 0) + delta,
                            lastChangedTime = (GetServerTime and GetServerTime()) or 0,
                            completed = (task.current or 0) >= (task.max or 0),
                        }
                    end
                end
                self.state.taskSnapshots[id] = { current = task.current, max = task.max }
            end
        end
    end

    if Villa.Dashboard and Villa.Dashboard.RefreshEndeavorsBar then
        Villa.Dashboard:RefreshEndeavorsBar()
    end
end

function E:Refresh()
    -- Called manually (e.g. from a /villa endeavors slash) to re-query
    -- everything. Useful when the user toggles back to the neighborhood map
    -- without the addon catching the corresponding update event.
    self.state.isInNeighborhood = isOnNeighborhoodMap() or isInsideHouse()
    if not self.state.isInNeighborhood then return end

    self:OnHouseListUpdated()
    self:OnHouseLevelUpdated()

    -- Same rule as the favor request: no server requests while Blizzard is
    -- building its dashboard off the same event flow.
    if not dashboardIsOpen()
        and C_NeighborhoodInitiative
        and C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo then
        pcall(C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo)
    end
end
