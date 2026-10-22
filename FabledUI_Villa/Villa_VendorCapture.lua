local Villa = _G.FabledUI_Villa
local Capture = {}
Villa.VendorCapture = Capture
Villa:RegisterModule("VendorCapture", Capture)

-- 12.1.5 deletes the global GetCoinTextureString. This is what Blizzard's
-- removed shim pointed it at (Deprecated_CurrencyScript.lua).
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString

-- Ground-truth housing vendor capture. Housing decor is sold through the classic
-- MerchantFrame (NOT a separate catalog store), so we scan the live merchant on
-- MERCHANT_SHOW/UPDATE: real itemIDs, real costs (gold + currencies + item costs),
-- each mapped to a decorID via C_Housing.GetDecorItemInfoFromItemID. This is
-- Villa's OWN verified data — the source of truth that will progressively replace
-- the unreliable imported donor datasets. Stored in FabledUI_VillaCaptureDB.

-- SavedVariable root (declared in the .toc). Lazily initialized + shape-guarded.
local function DB()
    FabledUI_VillaCaptureDB = FabledUI_VillaCaptureDB or {}
    local db = FabledUI_VillaCaptureDB
    db.vendors       = db.vendors or {}        -- [vendorKey] = { key, npcID, name, uiMapID, lastScan, items = { [itemID] = {...} } }
    db.itemToDecor   = db.itemToDecor or {}    -- [itemID]  = decorID
    db.decorToVendor = db.decorToVendor or {}  -- [decorID] = { vendorKey, itemID }
    return db
end

-- ── Taint-safe npcID from the merchant unit GUID ─────────────────────────────
-- In 12.0 a GUID can be a "secret" value; string-splitting a secret throws. Guard
-- with issecretvalue/canaccessvalue and pcall the split (pattern from HomeDecor's
-- VendorChecks). Falls back to nil so callers use the name#map composite key.
local function SafeNpcID(guid)
    if not guid then return nil end
    if issecretvalue and issecretvalue(guid) then return nil end
    if canaccessvalue and not canaccessvalue(guid) then return nil end
    local ok, unitType, _, _, _, _, npcID = pcall(strsplit, "-", guid)
    if not ok then return nil end
    if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "Pet" then
        return nil
    end
    return npcID and tonumber(npcID) or nil
end

local function VendorIdentity()
    local npcID = SafeNpcID(UnitGUID and UnitGUID("npc"))
    -- The name needs the same guard as the GUID: it lands in a table key below
    -- ("name:"..name.."#"..map), and secrets cannot be concatenated or used as keys.
    local name = UnitName and UnitName("npc")
    if name and issecretvalue and issecretvalue(name) then name = nil end
    name = name or "Unknown Vendor"
    local uiMapID = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or nil
    local key
    if npcID then
        key = "npc:" .. tostring(npcID)
    else
        key = "name:" .. tostring(name) .. "#" .. tostring(uiMapID or 0)
    end
    return key, name, uiMapID, npcID
end

-- ── Cost extraction for one merchant slot ────────────────────────────────────
-- Broken into structured fields (gold copper + currencies[] + itemCosts[]) so it
-- stays queryable, not a pre-formatted string.
local function CaptureCost(index, price, extendedCost)
    local cost = { gold = nil, currencies = {}, itemCosts = {} }
    if not extendedCost and price and price > 0 then
        cost.gold = price -- copper
    end
    if extendedCost and type(GetMerchantItemCostInfo) == "function"
        and type(GetMerchantItemCostItem) == "function" then
        local count = GetMerchantItemCostInfo(index) or 0
        for c = 1, count do
            local _, value, link = GetMerchantItemCostItem(index, c)
            if link then
                local currencyID = link:match("currency:(%d+)")
                local costItemID = link:match("item:(%d+)")
                if currencyID then
                    cost.currencies[#cost.currencies + 1] = { currencyID = tonumber(currencyID), amount = value }
                elseif costItemID then
                    cost.itemCosts[#cost.itemCosts + 1] = { itemID = tonumber(costItemID), amount = value }
                end
            end
        end
    end
    return cost
end

-- Map a merchant itemID -> decorID (nil if the item isn't housing decor, so
-- non-decor merchant stock is skipped).
local function DecorIDForItem(itemID)
    if not itemID then return nil end
    if C_Housing and type(C_Housing.GetDecorItemInfoFromItemID) == "function" then
        local ok, di = pcall(C_Housing.GetDecorItemInfoFromItemID, itemID)
        if ok and type(di) == "table" and di.decorID then
            return di.decorID
        end
    end
    if C_HousingCatalog and type(C_HousingCatalog.GetCatalogEntryInfoByItem) == "function" then
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID, true)
        if ok and type(info) == "table" and info.entryID and info.entryID.recordID then
            return info.entryID.recordID
        end
    end
    return nil
end

-- ── Merchant slot readers (12.x) ─────────────────────────────────────────────
-- Midnight (12.0) removed the global GetMerchantItemInfo in favour of
-- C_MerchantFrame.GetItemInfo, which returns a table. Because ScanMerchant is
-- pcall'd by the event handler, calling the dead global here did not surface an
-- error -- it silently captured nothing, which is why vendor tours banked no
-- data. Same shim FabledUI_Crafty_History/Capture.lua uses.
local function MerchantSlotInfo(index)
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" then
            return info.name, info.texture, info.price, info.stackCount,
                   info.numAvailable, info.hasExtendedCost
        end
        return nil
    end
    if type(GetMerchantItemInfo) == "function" then
        local nm, tex, price, qty, avail, _, _, ext = GetMerchantItemInfo(index)
        return nm, tex, price, qty, avail, ext
    end
    return nil
end

-- itemID for a merchant slot. GetMerchantItemID is not guaranteed on 12.x, so
-- fall back to parsing the item link (the approach HousingVendor and
-- Crafty_History both use).
local function MerchantSlotItemID(index)
    if type(GetMerchantItemID) == "function" then
        local ok, id = pcall(GetMerchantItemID, index)
        if ok and id then return id end
    end
    if type(GetMerchantItemLink) == "function" then
        local ok, link = pcall(GetMerchantItemLink, index)
        if ok and link then
            return tonumber(link:match("item:(%d+)"))
        end
    end
    return nil
end

-- ── The scan ─────────────────────────────────────────────────────────────────
function Capture:ScanMerchant(announce)
    if type(GetMerchantNumItems) ~= "function" then return 0 end
    local n = GetMerchantNumItems() or 0
    if n <= 0 then return 0 end

    local key, name, uiMapID, npcID = VendorIdentity()
    local db = DB()

    local vendor = db.vendors[key]
    if not vendor then
        vendor = { key = key, npcID = npcID, name = name, uiMapID = uiMapID, items = {} }
        db.vendors[key] = vendor
    end
    vendor.name = name or vendor.name
    vendor.uiMapID = uiMapID or vendor.uiMapID
    vendor.npcID = npcID or vendor.npcID
    vendor.lastScan = (time and time()) or vendor.lastScan
    vendor.items = vendor.items or {}

    local decorCount = 0
    local newCount = 0
    for i = 1, n do
        local itemID = MerchantSlotItemID(i)
        if itemID then
            local decorID = DecorIDForItem(itemID)
            if decorID then
                local iname, texture, price, quantity, numAvailable, extendedCost = MerchantSlotInfo(i)
                local cost = CaptureCost(i, price, extendedCost == true)
                -- Was this slot already banked for THIS vendor? Every scan
                -- re-reads the full stock, so decorCount is "how much decor this
                -- vendor sells", not "how much we learned". Announcing on the
                -- former made a re-visit to a fully-captured vendor look like a
                -- fresh capture. Only newCount is worth telling the player about.
                if vendor.items[itemID] == nil then
                    newCount = newCount + 1
                end
                vendor.items[itemID] = {
                    itemID = itemID,
                    decorID = decorID,
                    name = iname,
                    texture = texture,
                    gold = cost.gold,
                    currencies = cost.currencies,
                    itemCosts = cost.itemCosts,
                    stackCount = quantity,
                    numAvailable = numAvailable,
                }
                db.itemToDecor[itemID] = decorID
                db.decorToVendor[decorID] = { vendorKey = key, itemID = itemID }
                decorCount = decorCount + 1
            end
        end
    end

    self._lastCapture = { key = key, name = name, count = decorCount, newCount = newCount }
    if announce and newCount > 0 and Villa.Print then
        Villa:Print(string.format("Captured %d new verified decor item%s from |cff5cf0a0%s|r.",
            newCount, newCount == 1 and "" or "s", name or "vendor"))
    end

    -- Refresh the open vendor list so it can reflect verified data immediately.
    if decorCount > 0 and Villa.Vendors and Villa.Vendors.Refresh and Villa.state and Villa.state.villaMode then
        pcall(Villa.Vendors.Refresh, Villa.Vendors)
    end
    -- decorCount = everything this vendor stocks (callers use it to ask "does
    -- this merchant carry decor at all"); newCount = what this scan added.
    return decorCount, newCount
end

-- ── Public API ───────────────────────────────────────────────────────────────
function Capture:GetVendorByNpcID(npcID)
    if not npcID then return nil end
    return DB().vendors["npc:" .. tostring(npcID)]
end

function Capture:GetItemsForVendor(npcID, name, uiMapID)
    local db = DB()
    if npcID and db.vendors["npc:" .. tostring(npcID)] then
        return db.vendors["npc:" .. tostring(npcID)].items
    end
    if name then
        local v = db.vendors["name:" .. tostring(name) .. "#" .. tostring(uiMapID or 0)]
        return v and v.items or nil
    end
    return nil
end

-- Captured cost for a decorID (from wherever we last scanned it).
function Capture:GetCost(decorID)
    if not decorID then return nil end
    local db = DB()
    local ref = db.decorToVendor[decorID]
    if not ref then return nil end
    local vendor = db.vendors[ref.vendorKey]
    if vendor and vendor.items and vendor.items[ref.itemID] then
        local it = vendor.items[ref.itemID]
        return { gold = it.gold, currencies = it.currencies, itemCosts = it.itemCosts }
    end
    return nil
end

-- True if we've verified this decor at a real vendor.
function Capture:IsVerified(decorID)
    return decorID ~= nil and DB().decorToVendor[decorID] ~= nil
end

function Capture:GetStats()
    local db = DB()
    local vendors, items = 0, 0
    for _, v in pairs(db.vendors) do
        vendors = vendors + 1
        for _ in pairs(v.items or {}) do items = items + 1 end
    end
    return vendors, items
end

-- Format a captured cost table into a short display string (gold + currencies + items).
function Capture:FormatCost(cost)
    if type(cost) ~= "table" then return nil end
    local parts = {}
    if cost.gold and cost.gold > 0 then
        if GetCoinTextureString then
            parts[#parts + 1] = GetCoinTextureString(cost.gold)
        else
            parts[#parts + 1] = tostring(math.floor(cost.gold / 10000)) .. "g"
        end
    end
    for _, c in ipairs(cost.currencies or {}) do
        local cname
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local ok, ci = pcall(C_CurrencyInfo.GetCurrencyInfo, c.currencyID)
            if ok and type(ci) == "table" then cname = ci.name end
        end
        parts[#parts + 1] = tostring(c.amount) .. " " .. (cname or ("currency #" .. tostring(c.currencyID)))
    end
    for _, ic in ipairs(cost.itemCosts or {}) do
        local iname = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(ic.itemID)) or ("item #" .. tostring(ic.itemID))
        parts[#parts + 1] = tostring(ic.amount) .. "x " .. iname
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

-- Convenience: formatted captured cost for a decorID, or nil.
function Capture:GetCostText(decorID)
    return self:FormatCost(self:GetCost(decorID))
end

function Capture:PrintStats()
    local vendors, items = self:GetStats()
    Villa:Print(string.format("Vendor capture: |cff5cf0a0%d|r vendors, |cff5cf0a0%d|r verified decor items.", vendors, items))
    if MerchantFrame and MerchantFrame:IsShown() then
        -- Explicit user command, so always answer -- silence here would read as
        -- the scan having failed.
        local n, added = self:ScanMerchant(true)
        if n == 0 then
            Villa:Print("This merchant has no housing decor to capture.")
        elseif added == 0 then
            Villa:Print(string.format("Already captured all |cff5cf0a0%d|r decor item%s from this vendor.",
                n, n == 1 and "" or "s"))
        end
    else
        Villa:Print("Visit a housing vendor to capture its stock.")
    end
end

-- ── Events ───────────────────────────────────────────────────────────────────
function Capture:OnEnable()
    if self._frame then return end
    local f = CreateFrame("Frame")
    self._frame = f
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("MERCHANT_UPDATE")
    f:RegisterEvent("MERCHANT_CLOSED")
    f:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then
            self._announced = false
            return
        end
        -- Defer a tick so merchant item + cost data is fully populated.
        C_Timer.After(0.1, function()
            local announce = not self._announced
            local ok, count, newCount = pcall(self.ScanMerchant, self, announce)
            -- Latch only when something was actually said. Latching on any decor
            -- (the old `count > 0`) meant a MERCHANT_UPDATE that introduced new
            -- stock mid-session could be silently swallowed.
            if ok and announce and (newCount or 0) > 0 then
                self._announced = true
            elseif not ok then
                -- Surface this once per session rather than only under debug.
                -- A silently-swallowed scan error is exactly how the 12.0
                -- GetMerchantItemInfo removal cost a full vendor run before
                -- anyone noticed capture had stopped working.
                if not self._errorReported then
                    self._errorReported = true
                    Villa:Print("|cffff5555Vendor capture failed:|r " .. tostring(count))
                end
            end
        end)
    end)
end
