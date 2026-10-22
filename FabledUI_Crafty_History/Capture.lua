-- =============================================================================
-- FabledUI_Crafty :: Capture
-- =============================================================================
-- In-game data capture (Tier 2 of the suite's hybrid data strategy).
--
-- Captures things Blizzard does NOT expose via the addon API but the player
-- naturally encounters during play:
--   * Vendor inventories (when the player opens a merchant frame)
--   * Mob/object loot drops (when the player loots a corpse or object)
--
-- Stored under FabledUI_Crafty's DataVault namespace so it survives reloads and
-- character swaps, and exposed through a cross-addon read API at
-- _G.FabledUI_Crafty.Capture so Villa/Nemesis/Materials can use the data
-- without re-implementing capture logic.
--
-- Provenance: every record carries firstSeen / lastSeen timestamps so consumers
-- can mark stale entries or sort by freshness.
-- =============================================================================

local M = FabledUI_Crafty
if not M then return end

M.Capture = M.Capture or {}
local C = M.Capture

C.SCHEMA_VERSION = 1

-- ----------------------------------------------------------------------------
-- Storage init
-- ----------------------------------------------------------------------------
local function EnsureDB()
    M.db = M.db or {}
    M.db.capture = M.db.capture or {
        schema = C.SCHEMA_VERSION,
        vendors = {},      -- [npcID] = { npcID, name, mapID, x, y, items = { [itemID] = {...} }, firstSeen, lastSeen }
        dropSources = {},  -- [type..":"..id] = { sourceID, sourceType, name?, items = { [itemID] = { count, firstSeen, lastSeen } }, firstSeen, lastSeen }
    }
    return M.db.capture
end

function C:GetDB()
    return EnsureDB()
end

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------
-- 12.x (Midnight) secret values: unit identity read from a tainted execution
-- path can be a "secret string" that throws when split, indexed, concatenated,
-- or used as a table key. Guard at the helpers so callers just see nil.
local issecretvalue = _G.issecretvalue or function() return false end

local function SafeUnitName(unit)
    local name = UnitName and UnitName(unit)
    if not name or issecretvalue(name) then return nil end
    return name
end

local function ExtractIDFromGUID(guid)
    if not guid or issecretvalue(guid) then return nil, nil end
    -- Creature-0-realmID-mapID-instanceID-creatureID-spawnUID
    -- GameObject-0-realmID-mapID-instanceID-objectID-spawnUID
    local guidType, _, _, _, _, id = strsplit("-", guid)
    return guidType, tonumber(id)
end

local function CurrentMapPosition()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID end
    local x, y = pos:GetXY()
    return mapID, x, y
end

local function ExtractItemIDFromLink(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- ----------------------------------------------------------------------------
-- Vendor capture
-- ----------------------------------------------------------------------------
function C:RecordVendor()
    local guid = UnitGUID("npc")
    if not guid then return end
    local guidType, npcID = ExtractIDFromGUID(guid)
    if not npcID or guidType ~= "Creature" then return end

    local db = EnsureDB()
    local key = tostring(npcID)
    local existing = db.vendors[key]
    local now = time()

    local vendor = {
        npcID     = npcID,
        name      = SafeUnitName("npc") or (existing and existing.name) or "Unknown Vendor",
        items     = existing and existing.items or {},
        firstSeen = (existing and existing.firstSeen) or now,
        lastSeen  = now,
    }
    local mapID, x, y = CurrentMapPosition()
    if mapID then
        vendor.mapID = mapID
        vendor.x = x
        vendor.y = y
    end

    -- Walk merchant slots
    local count = (GetMerchantNumItems and GetMerchantNumItems()) or 0
    for i = 1, count do
        local link = GetMerchantItemLink and GetMerchantItemLink(i)
        local itemID = ExtractItemIDFromLink(link)
        if itemID then
            -- Midnight (12.0) removed the global GetMerchantItemInfo in favour of
            -- C_MerchantFrame.GetItemInfo (a table). Prefer it; fall back to the
            -- global on older clients.
            local name, price, quantity, numAvailable, hasExtendedCost
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local info = C_MerchantFrame.GetItemInfo(i)
                if type(info) == "table" then
                    name, price, quantity, numAvailable, hasExtendedCost =
                        info.name, info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
                end
            elseif type(GetMerchantItemInfo) == "function" then
                local n, _, p, q, avail, _, _, ext = GetMerchantItemInfo(i)
                name, price, quantity, numAvailable, hasExtendedCost = n, p, q, avail, ext
            end

            -- Capture extended currency cost (token vendors, currency vendors).
            -- Guarded so a missing cost API just skips this detail, never errors.
            local currencies = nil
            if hasExtendedCost and type(GetMerchantItemCostInfo) == "function"
                and type(GetMerchantItemCostItem) == "function" then
                local numCurrencies = GetMerchantItemCostInfo(i) or 0
                if numCurrencies > 0 then
                    currencies = {}
                    for j = 1, numCurrencies do
                        local _, amount, costLink = GetMerchantItemCostItem(i, j)
                        if costLink then
                            local cID = tonumber(costLink:match("item:(%d+)") or costLink:match("currency:(%d+)"))
                            currencies[#currencies + 1] = {
                                id     = cID,
                                amount = amount,
                                link   = costLink,
                            }
                        end
                    end
                end
            end

            vendor.items[itemID] = {
                name        = name,
                priceCopper = price,
                quantity    = quantity,
                stock       = numAvailable,  -- -1 = unlimited
                currencies  = currencies,
                lastSeen    = now,
            }
        end
    end

    db.vendors[key] = vendor

    if M.MarkDirty then M:MarkDirty() end
end

-- ----------------------------------------------------------------------------
-- Loot capture (mobs + objects)
-- ----------------------------------------------------------------------------
function C:RecordLoot()
    if not GetNumLootItems then return end
    local db = EnsureDB()
    local now = time()

    local numItems = GetNumLootItems()
    if numItems == 0 then return end

    for slot = 1, numItems do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local itemID = ExtractItemIDFromLink(link)
        if itemID and GetLootSourceInfo then
            -- GetLootSourceInfo returns alternating GUID, quantity pairs
            local sources = { GetLootSourceInfo(slot) }
            for i = 1, #sources, 2 do
                local guid = sources[i]
                local guidType, sourceID = ExtractIDFromGUID(guid)
                if sourceID and (guidType == "Creature" or guidType == "Vehicle" or guidType == "GameObject") then
                    local key = guidType .. ":" .. sourceID
                    local entry = db.dropSources[key]
                    if not entry then
                        entry = {
                            sourceID   = sourceID,
                            sourceType = guidType,
                            items      = {},
                            firstSeen  = now,
                        }
                        db.dropSources[key] = entry
                    end
                    -- No name capture here: correlating the loot source to a unit
                    -- needs UnitGUID("target"), a "secret" value in Midnight that
                    -- throws when compared. The Creature/GameObject:sourceID key is
                    -- the stable identifier; consumers show the ID when the name
                    -- isn't known.

                    local itemEntry = entry.items[itemID]
                    if not itemEntry then
                        itemEntry = { count = 0, firstSeen = now }
                        entry.items[itemID] = itemEntry
                    end
                    itemEntry.count = (itemEntry.count or 0) + 1
                    itemEntry.lastSeen = now
                    entry.lastSeen = now
                end
            end
        end
    end

    if M.MarkDirty then M:MarkDirty() end
end

-- ----------------------------------------------------------------------------
-- Read API (used by Materials tab and cross-addon consumers)
-- ----------------------------------------------------------------------------

--- Return a list of captured vendors that sell `itemID`.
function C:GetVendorsSelling(itemID)
    itemID = tonumber(itemID)
    if not itemID then return {} end
    local db = EnsureDB()
    local results = {}
    for _, vendor in pairs(db.vendors) do
        if vendor.items and vendor.items[itemID] then
            results[#results + 1] = vendor
        end
    end
    return results
end

--- Return a list of captured mob/object sources that drop `itemID`.
function C:GetSourcesDropping(itemID)
    itemID = tonumber(itemID)
    if not itemID then return {} end
    local db = EnsureDB()
    local results = {}
    for _, src in pairs(db.dropSources) do
        if src.items and src.items[itemID] then
            local copy = {}
            for k, v in pairs(src) do copy[k] = v end
            copy.observedCount = src.items[itemID].count
            copy.itemFirstSeen = src.items[itemID].firstSeen
            copy.itemLastSeen = src.items[itemID].lastSeen
            results[#results + 1] = copy
        end
    end
    return results
end

--- Quick stats for /crafty stats output.
function C:GetSummary()
    local db = EnsureDB()
    local vendorCount, dropSourceCount = 0, 0
    for _ in pairs(db.vendors) do vendorCount = vendorCount + 1 end
    for _ in pairs(db.dropSources) do dropSourceCount = dropSourceCount + 1 end
    return {
        vendors    = vendorCount,
        sources    = dropSourceCount,
        schema     = db.schema,
    }
end

-- ----------------------------------------------------------------------------
-- Event wiring
-- ----------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:RegisterEvent("LOOT_OPENED")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        -- Defer one frame so GetMerchantNumItems is populated
        C_Timer.After(0.05, function() C:RecordVendor() end)
    elseif event == "LOOT_OPENED" then
        C:RecordLoot()
    end
end)
