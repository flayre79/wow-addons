local Villa = _G.FabledUI_Villa
local VendorVisits = {}
Villa.VendorVisits = VendorVisits
Villa:RegisterModule("VendorVisits", VendorVisits)

-- 12.x (Midnight) secret values. Unit identity read from a tainted execution
-- path -- which any addon event handler is -- can come back as a "secret
-- string": it may be passed around, but indexing it (guid:match(...)), using it
-- as a table key, or concatenating it throws. Guard every unit-derived value
-- before touching it. Shimmed so the file still loads on pre-12.x clients.
local issecretvalue = _G.issecretvalue or function() return false end

-- ============================================================
-- Storage helpers (per-character vendor visit log)
-- ============================================================

local function GetCharKey()
    local name = (UnitName and UnitName("player")) or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "Realm"
    return name .. "-" .. realm
end

local function GetVisitsTable()
    local db = Villa.db
    if not db then return nil end
    db.vendorsVisited = db.vendorsVisited or {}
    local key = GetCharKey()
    db.vendorsVisited[key] = db.vendorsVisited[key] or {}
    return db.vendorsVisited[key], key
end

local function VendorIdentityKey(vendor)
    if not vendor then return nil end
    if vendor.vendorKey then return tostring(vendor.vendorKey) end
    if vendor.npcID then return "npc:" .. tostring(vendor.npcID) end
    return string.format("name:%s|zone:%s", tostring(vendor.name or "?"), tostring(vendor.zone or "?"))
end

VendorVisits._npcIndex = nil
VendorVisits._mapIndex = nil

-- Vendor coords arrive on two scales depending on provider: the raw data tables
-- use 0-100, NormalizedData emits 0-1. Fold both onto 0-1.
local function NormalizeCoord(v)
    v = tonumber(v)
    if not v then return nil end
    if v > 1.5 then return v / 100 end
    return v
end

local function RebuildNpcIndex()
    local idx, byMap = {}, {}

    local function Add(vendor, allowOverwrite)
        local npcID = tonumber(vendor.npcID)
        if npcID and (allowOverwrite or not idx[npcID]) then
            idx[npcID] = vendor
        end
        local mapID = tonumber(vendor.mapID)
        local x, y = NormalizeCoord(vendor.x), NormalizeCoord(vendor.y)
        if mapID and x and y then
            byMap[mapID] = byMap[mapID] or {}
            byMap[mapID][#byMap[mapID] + 1] = { vendor = vendor, x = x, y = y }
        end
    end

    if Villa.HomeData and Villa.HomeData.GetMergedVendorList then
        local list = Villa.HomeData:GetMergedVendorList() or {}
        for _, vendor in ipairs(list) do
            Add(vendor, true)
        end
    end
    -- Also scan provider lists; they may include vendors not in HomeData merged result.
    if Villa.NormalizedData and Villa.NormalizedData.GetVendorsByProvider then
        for _, providerKey in ipairs({ "betterhomes", "hit", "decorvendor", "housingvendor", "codex" }) do
            local list = Villa.NormalizedData:GetVendorsByProvider(providerKey) or {}
            for _, vendor in ipairs(list) do
                Add(vendor, false)
            end
        end
    end

    VendorVisits._npcIndex = idx
    VendorVisits._mapIndex = byMap
end

function VendorVisits:LookupVendorByNpcID(npcID)
    npcID = tonumber(npcID)
    if not npcID then return nil end
    if not self._npcIndex then RebuildNpcIndex() end
    return self._npcIndex and self._npcIndex[npcID] or nil
end

-- Fallback identification for when the merchant's GUID is a secret value and the
-- NPC ID is therefore unreadable (see OnMerchantShow). The merchant frame is
-- open, so the player is standing on top of the vendor: the nearest known vendor
-- on this map, within a tight radius, is the one we are talking to.
local MAX_MATCH_DISTANCE = 0.025 -- normalized map units

function VendorVisits:LookupVendorByPosition()
    if not self._mapIndex then RebuildNpcIndex() end
    if not self._mapIndex then return nil end

    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local candidates = self._mapIndex[mapID]
    if not candidates then return nil end

    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    if not px or not py then return nil end

    local best, bestDist
    for _, entry in ipairs(candidates) do
        local dx, dy = entry.x - px, entry.y - py
        local dist = (dx * dx) + (dy * dy)
        if not bestDist or dist < bestDist then
            best, bestDist = entry.vendor, dist
        end
    end

    if best and bestDist <= (MAX_MATCH_DISTANCE * MAX_MATCH_DISTANCE) then
        return best
    end
    return nil
end

-- ============================================================
-- Public API
-- ============================================================

function VendorVisits:MarkVisited(vendor)
    if not Villa.settings or Villa.settings.trackVendorVisits == false then return end
    local key = VendorIdentityKey(vendor)
    if not key then return end
    local visits = GetVisitsTable()
    if not visits then return end
    visits[key] = time()
end

function VendorVisits:IsVisited(vendor)
    local key = VendorIdentityKey(vendor)
    if not key then return false end
    local visits = GetVisitsTable()
    if not visits then return false end
    return visits[key] ~= nil
end

function VendorVisits:GetVisitTime(vendor)
    local key = VendorIdentityKey(vendor)
    if not key then return nil end
    local visits = GetVisitsTable()
    if not visits then return nil end
    return visits[key]
end

function VendorVisits:ClearAll()
    local visits, key = GetVisitsTable()
    if visits then
        local db = Villa.db
        db.vendorsVisited[key] = {}
    end
end

-- ============================================================
-- Event hookup
-- ============================================================

function VendorVisits:OnMerchantShow()
    if Villa.settings and Villa.settings.trackVendorVisits == false then return end
    -- On 12.x these GUIDs are frequently secret values, and a secret string
    -- cannot be indexed -- guid:match(...) is what threw here. Take the exact
    -- NPC ID whenever the GUID is readable, and fall back to position matching
    -- when it is not, so visit tracking keeps working either way.
    local vendor
    for _, unit in ipairs({ "npc", "target" }) do
        local guid = UnitGUID(unit)
        if guid and not issecretvalue(guid) then
            local npcID = tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
            if npcID then
                vendor = self:LookupVendorByNpcID(npcID)
                if vendor then break end
            end
        end
    end

    vendor = vendor or self:LookupVendorByPosition()
    if not vendor then return end
    self:MarkVisited(vendor)

    -- If the vendors panel is currently visible, refresh it so the checkmark appears.
    if Villa.Vendors and Villa.Vendors.frame and Villa.Vendors.frame:IsShown() and type(Villa.Vendors.Refresh) == "function" then
        Villa.Vendors:Refresh()
    end
end

-- ============================================================
-- Lifecycle
-- ============================================================

function VendorVisits:OnInitialize()
    if Villa.settings and Villa.settings.trackVendorVisits == nil then
        Villa.settings.trackVendorVisits = true
    end
end

function VendorVisits:OnEnable()
    local f = CreateFrame("Frame")
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            VendorVisits:OnMerchantShow()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Defer index build so HomeData/NormalizedData are populated.
            C_Timer.After(2.0, RebuildNpcIndex)
        end
    end)
end
