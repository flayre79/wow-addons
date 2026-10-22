local Villa = _G.FabledUI_Villa
local AcquiredAlert = {}
Villa.AcquiredAlert = AcquiredAlert
Villa:RegisterModule("AcquiredAlert", AcquiredAlert)

-- ============================================================
-- Storage helpers (per-character "already alerted" set)
-- ============================================================

local function GetCharKey()
    local name = (UnitName and UnitName("player")) or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "Realm"
    return name .. "-" .. realm
end

local function GetSeenTable()
    local db = Villa.db
    if not db then return nil end
    db.acquiredSeen = db.acquiredSeen or {}
    local key = GetCharKey()
    db.acquiredSeen[key] = db.acquiredSeen[key] or {}
    return db.acquiredSeen[key]
end

-- ============================================================
-- Bag scanning
-- ============================================================

local function GetItemNameAndIcon(itemID)
    -- Call C_Item.GetItemInfo directly. Wrapping a multi-return call in
    -- parentheses or an and/or chain truncates it to its FIRST value, so the
    -- previous form left `icon` nil on every call and item icons never drew.
    -- (The legacy global GetItemInfo is gone in modern retail anyway.)
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return name or ("Item #" .. tostring(itemID)), icon
end

-- Snapshot of itemID -> count from current bag contents.
local function ScanBagsItemIDs()
    local out = {}
    local containers = (C_Container and C_Container.GetContainerNumSlots) and 1 or 0
    if C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerNumSlots then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    out[info.itemID] = (out[info.itemID] or 0) + (info.stackCount or 1)
                end
            end
        end
    elseif GetContainerNumSlots and GetContainerItemID then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local slots = GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local id = GetContainerItemID(bag, slot)
                if id then
                    out[id] = (out[id] or 0) + 1
                end
            end
        end
    end
    return out
end

AcquiredAlert._lastSnapshot = nil
AcquiredAlert._initialScanDone = false

-- ============================================================
-- Toast helpers
-- ============================================================

local function ShowAcquiredToast(itemID, isWishlist)
    local TK = rawget(_G, "FabledUI_UIToolkit")
    if not (TK and TK.Toast and TK.Toast.Show) then return end
    local name, icon = GetItemNameAndIcon(itemID)
    local message
    if isWishlist then
        message = "|cffffd866Wishlisted item acquired:|r " .. name
    else
        message = "|cff66cc99Added to your collection:|r " .. name
    end
    TK.Toast:Show(message, icon or itemID, 4.5)
end

-- ============================================================
-- Core handler
-- ============================================================

function AcquiredAlert:HandleNewlyAcquired(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    if not Villa.settings or Villa.settings.showAcquiredAlerts == false then return end

    local isHousing = Villa.IsHousingRelevantItem and Villa:IsHousingRelevantItem(itemID)
    if not isHousing then return end

    local onWishlist = false
    if Villa.Wishlist and Villa.Wishlist.Contains then
        onWishlist = Villa.Wishlist:Contains(itemID) and true or false
    end

    if Villa.settings.acquiredAlertsWishlistOnly and not onWishlist then
        return
    end

    -- One-shot per character per item, so re-stacking the same item doesn't spam toasts.
    local seen = GetSeenTable()
    if seen and seen[itemID] then return end
    if seen then seen[itemID] = time() end

    ShowAcquiredToast(itemID, onWishlist)
end

function AcquiredAlert:DiffSnapshot()
    local now = ScanBagsItemIDs()
    if not self._lastSnapshot then
        self._lastSnapshot = now
        return
    end
    for itemID, count in pairs(now) do
        local prev = self._lastSnapshot[itemID] or 0
        if count > prev then
            self:HandleNewlyAcquired(itemID)
        end
    end
    self._lastSnapshot = now
end

function AcquiredAlert:OnBagUpdateDelayed()
    if not self._initialScanDone then
        -- First scan after login: just record current bag state, do not toast.
        self._lastSnapshot = ScanBagsItemIDs()
        self._initialScanDone = true
        return
    end
    self:DiffSnapshot()
end

function AcquiredAlert:OnLootOpened()
    -- Bag changes will fire BAG_UPDATE_DELAYED next; we don't need to scan loot slots directly.
    -- (Looking at LOOT_SLOT_CHANGED would let us pre-announce, but bag-confirmed pickups are cleaner.)
end

-- ============================================================
-- Lifecycle
-- ============================================================

function AcquiredAlert:OnInitialize()
    if Villa.settings then
        if Villa.settings.showAcquiredAlerts == nil then
            Villa.settings.showAcquiredAlerts = true
        end
        if Villa.settings.acquiredAlertsWishlistOnly == nil then
            Villa.settings.acquiredAlertsWishlistOnly = false
        end
    end
end

function AcquiredAlert:OnEnable()
    local f = CreateFrame("Frame")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("LOOT_OPENED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE_DELAYED" then
            AcquiredAlert:OnBagUpdateDelayed()
        elseif event == "LOOT_OPENED" then
            AcquiredAlert:OnLootOpened()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Reset snapshot on world load so we don't toast on existing bag contents.
            AcquiredAlert._initialScanDone = false
            AcquiredAlert._lastSnapshot = nil
        end
    end)
end
