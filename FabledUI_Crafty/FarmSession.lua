local M = _G.FabledUI_Crafty
M.FarmSession = M.FarmSession or {}
local FS = M.FarmSession

local SESSION_IDLE_TIMEOUT = 180  -- 3 minutes idle ends session
local MAX_RADAR_NODES      = 50   -- blips kept on radar
local MAX_SESSION_HISTORY  = 20

-- Gathering spell IDs across expansions (herbalism, mining, skinning)
-- Updated for TWW / Midnight (12.x).  Fallback LOOT_OPENED path also handles
-- unknown IDs so missing entries still get captured.
local GATHER_SPELLS = {
    -- Herbalism
    [2366]   = "herb",  [11993]  = "herb",  [28695]  = "herb",
    [50300]  = "herb",  [80243]  = "herb",  [693933] = "herb",
    -- Mining
    [2575]   = "mine",  [10248]  = "mine",  [29354]  = "mine",
    [50310]  = "mine",  [80244]  = "mine",  [693934] = "mine",
    -- Skinning
    [8613]   = "skin",  [8617]   = "skin",  [8618]   = "skin",
    [50305]  = "skin",  [80245]  = "skin",  [693935] = "skin",
    -- Logging (Dragonflight+ Forestry)
    [374819] = "log",   [383070] = "log",
}

-- ----------------------------------------------------------------
-- Internal helpers
-- ----------------------------------------------------------------

local function GetPlayerMapPos()
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil, nil end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID, nil, nil end
    return mapID, pos:GetXY()
end

local function CloseSession(session)
    if not session then return end
    session.endTime    = session.lastActivity
    session.durationSec = session.endTime - session.startTime
    if M.db and M.db.history and M.db.history.sessions then
        local list = M.db.history.sessions
        list[#list + 1] = {
            startTime   = session.startTime,
            endTime     = session.endTime,
            durationSec = session.durationSec,
            gathers     = session.gathers,
            mapID       = session.mapID,
        }
        while #list > MAX_SESSION_HISTORY do table.remove(list, 1) end
    end
end

local function EnsureSession()
    local now  = time()
    local active = FS.activeSession

    if active then
        local idle = now - active.lastActivity
        if idle <= SESSION_IDLE_TIMEOUT then
            active.lastActivity = now
            active.gathers      = active.gathers + 1
            return active
        else
            CloseSession(active)
            FS.activeSession = nil
        end
    end

    -- Start a fresh session
    local mapID, x, y = GetPlayerMapPos()
    FS.activeSession = {
        startTime    = now,
        lastActivity = now,
        gathers      = 1,
        mapID        = mapID,
    }
    return FS.activeSession
end

-- ----------------------------------------------------------------
-- Public API
-- ----------------------------------------------------------------

-- Auto-pause flag: when true, RecordGather still tracks the gather but does
-- NOT update session timing/rate. Triggered by AFK / instance / mailbox.
function FS:IsPaused()
    return self._autoPaused == true
end

function FS:SetPaused(value, reason)
    self._autoPaused = value and true or false
    self._pausedReason = self._autoPaused and (reason or "auto") or nil
    if M.HUD and M.HUD.Refresh then M.HUD:Refresh() end
end

function FS:RecordGather(spellID, kind)
    if not M.settings or M.settings.farmTrackEnabled == false then return end

    local mapID, x, y = GetPlayerMapPos()
    if not x or not y then return end

    -- Auto-pause respects user setting; defaults ON.
    if self._autoPaused and (not M.settings or M.settings.farmAutoPauseEnabled ~= false) then
        -- Still record the gather node for radar display, but skip session
        -- accounting so the rate stays sensible across breaks.
        local node = { t = time(), kind = kind or GATHER_SPELLS[spellID] or "node",
                       mapID = mapID, x = x, y = y }
        self.recentNodes = self.recentNodes or {}
        self.recentNodes[#self.recentNodes + 1] = node
        while #self.recentNodes > MAX_RADAR_NODES do
            table.remove(self.recentNodes, 1)
        end
        return
    end

    EnsureSession()

    local node = {
        t      = time(),
        kind   = kind or GATHER_SPELLS[spellID] or "node",
        mapID  = mapID,
        x      = x,
        y      = y,
    }

    self.recentNodes = self.recentNodes or {}
    local rn = self.recentNodes
    rn[#rn + 1] = node
    while #rn > MAX_RADAR_NODES do table.remove(rn, 1) end

    -- Mirror into the hud session schema (used by the HUD refresh)
    if M.db and M.db.hud and M.db.hud.session then
        local hs = M.db.hud.session
        hs.active     = true
        hs.gathered   = (hs.gathered or 0) + 1
        hs.nodes      = rn
    end

    -- HousingLumberHelper: per-zone yield tracking. Persisted in db so the
    -- Lumber tab can rank "best zones" across sessions.
    if mapID and M.db then
        M.db.lumberByZone = type(M.db.lumberByZone) == "table" and M.db.lumberByZone or {}
        local zoneRow = M.db.lumberByZone[mapID]
        if type(zoneRow) ~= "table" then
            zoneRow = { count = 0, sessionTime = 0, lastSeen = 0 }
            M.db.lumberByZone[mapID] = zoneRow
        end
        zoneRow.count = (zoneRow.count or 0) + 1
        zoneRow.lastSeen = time()
        local active = self.activeSession
        if active and active.mapID == mapID then
            zoneRow.sessionTime = (active.lastActivity - active.startTime)
        end
    end

    M:MarkDirty()

    if M.HUD and M.HUD.Refresh then
        M.HUD:Refresh()
    end
end

function FS:GetActiveSession()
    return self.activeSession
end

function FS:GetRecentNodes()
    return self.recentNodes or {}
end

--- Returns gathers-per-hour for the active session, or 0.
function FS:GetSessionRate()
    local s = self.activeSession
    if not s then return 0 end
    local elapsed = time() - s.startTime
    if elapsed < 1 then return 0 end
    return math.floor((s.gathers / elapsed) * 3600)
end

-- HousingLumberHelper-style bank scanning. Walks bank + warband bank slots
-- when BANKFRAME_OPENED fires, totals matching lumber items, and writes them
-- into M.db.lumberBank so the Lumber tab can include bank stockpiles.
local function GetLumberItemSet()
    local set = {}
    if M.LumberData and M.LumberData.categories then
        for _, category in ipairs(M.LumberData.categories) do
            for _, itemID in ipairs(category.items or {}) do
                set[itemID] = true
            end
        end
    end
    return set
end

function FS:ScanBankForLumber()
    if not M.settings or M.settings.farmScanWarbandBank == false then
        return 0
    end
    if not C_Container or not C_Container.GetContainerNumSlots then
        return 0
    end
    local lumberItems = GetLumberItemSet()
    M.db = M.db or {}
    M.db.lumberBank = type(M.db.lumberBank) == "table" and M.db.lumberBank or {}
    local total = 0
    -- Standard bank bags: BANK_CONTAINER (-1) plus the 7 bank slots that come
    -- after the player's main bags.
    local bankBags = { -1 }
    local startBag = (NUM_BAG_SLOTS or 4) + 1
    local endBag = startBag + (NUM_BANKBAGSLOTS or 7) - 1
    for bag = startBag, endBag do
        bankBags[#bankBags + 1] = bag
    end
    -- Warband bank, if the API exposes the constant in this build.
    if Enum and Enum.BagIndex then
        local wbStart = Enum.BagIndex.AccountBankTab_1 or Enum.BagIndex.CharacterBankTab_1
        local wbCount = 6
        if wbStart then
            for i = 0, wbCount - 1 do
                bankBags[#bankBags + 1] = wbStart + i
            end
        end
    end
    for _, bag in ipairs(bankBags) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.itemID and lumberItems[info.itemID] then
                total = total + (info.stackCount or 1)
                M.db.lumberBank[info.itemID] = (M.db.lumberBank[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    if total > 0 then
        M:MarkDirty()
        if M.HUD and M.HUD.Refresh then M.HUD:Refresh() end
    end
    return total
end

function FS:StopSession()
    CloseSession(self.activeSession)
    self.activeSession = nil
    if M.db and M.db.hud and M.db.hud.session then
        M.db.hud.session.active  = false
        M.db.hud.session.gathered = 0
        M.db.hud.session.nodes   = {}
    end
    self.recentNodes = {}
    if M.HUD and M.HUD.Refresh then M.HUD:Refresh() end
end

-- ----------------------------------------------------------------
-- Initialisation
-- ----------------------------------------------------------------

function FS:Init()
    if self._initialized then return end
    self._initialized = true
    self.recentNodes  = {}
    self.activeSession = nil

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ev:RegisterEvent("LOOT_OPENED")
    -- HousingLumberHelper-inspired: auto-pause triggers
    ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("MAIL_SHOW")
    ev:RegisterEvent("MAIL_CLOSED")
    -- Bank/warband bank scanning hooks
    ev:RegisterEvent("BANKFRAME_OPENED")
    ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            spellID = tonumber(spellID)
            if unit == "player" and GATHER_SPELLS[spellID] then
                FS:RecordGather(spellID, nil)
            end
        elseif event == "LOOT_OPENED" then
            -- Fallback: detect game-object (node) looting by GUID type
            if GetLootSourceInfo then
                local guid = GetLootSourceInfo(1)
                if type(guid) == "string" then
                    local guidType = strsplit("-", guid)
                    if guidType == "GameObject" then
                        FS:RecordGather(0, "node")
                    end
                end
            end
        elseif event == "PLAYER_FLAGS_CHANGED" then
            local unit = ...
            if unit == "player" and UnitIsAFK and UnitIsAFK("player") then
                FS:SetPaused(true, "afk")
            elseif unit == "player" then
                FS:SetPaused(false)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            local inInstance, instanceType = IsInInstance()
            if inInstance and instanceType ~= "none" then
                FS:SetPaused(true, "instance")
            else
                FS:SetPaused(false)
            end
        elseif event == "MAIL_SHOW" then
            FS:SetPaused(true, "mail")
        elseif event == "MAIL_CLOSED" then
            FS:SetPaused(false)
        elseif event == "BANKFRAME_OPENED"
            or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            FS:ScanBankForLumber()
        end
    end)
    self._evFrame = ev
end
