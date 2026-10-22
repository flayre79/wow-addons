local Villa = _G.FabledUI_Villa
local LiveCounts = {}
Villa.LiveCounts = LiveCounts
Villa:RegisterModule("LiveCounts", LiveCounts)

-- ============================================================
-- Local bag/bank count caches (rebuilt on scan; not persisted)
-- ============================================================

local bagCache  = {}  -- itemID -> count from bags
local bankCache = {}  -- itemID -> count from bank

-- ============================================================
-- Helpers
-- ============================================================

local function GetDB()
    local db = Villa.db
    if not db then return nil end
    db.ownedCounts  = db.ownedCounts  or {}
    db.placedCounts = db.placedCounts or {}
    return db
end

-- ============================================================
-- Scanning
-- ============================================================

function LiveCounts:ScanBags()
    wipe(bagCache)
    if not C_Container or not C_Container.GetContainerNumSlots then return end
    -- Bags: 0 (backpack) through 4, plus reagent bag (5) if present
    local bagIDs = { 0, 1, 2, 3, 4, 5 }
    for _, bagID in ipairs(bagIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID then
                bagCache[info.itemID] = (bagCache[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    local db = GetDB()
    if db then
        wipe(db.ownedCounts)
        -- Merge bag + bank into ownedCounts
        for itemID, count in pairs(bagCache) do
            db.ownedCounts[itemID] = (db.ownedCounts[itemID] or 0) + count
        end
        for itemID, count in pairs(bankCache) do
            db.ownedCounts[itemID] = (db.ownedCounts[itemID] or 0) + count
        end
    end
end

function LiveCounts:ScanBank()
    wipe(bankCache)
    if not C_Container or not C_Container.GetContainerNumSlots then return end
    -- Bank: -1 (main bank), plus bank bags 6-12
    local bankBagIDs = { -1, 6, 7, 8, 9, 10, 11, 12 }
    for _, bagID in ipairs(bankBagIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID then
                bankCache[info.itemID] = (bankCache[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    -- Re-merge into db.ownedCounts now that bank is known
    local db = GetDB()
    if db then
        wipe(db.ownedCounts)
        for itemID, count in pairs(bagCache) do
            db.ownedCounts[itemID] = (db.ownedCounts[itemID] or 0) + count
        end
        for itemID, count in pairs(bankCache) do
            db.ownedCounts[itemID] = (db.ownedCounts[itemID] or 0) + count
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

function LiveCounts:GetOwned(itemID)
    local db = GetDB()
    if not db then return 0 end
    return db.ownedCounts[itemID] or 0
end

-- C_Housing.GetPlacedItemCount / C_Decoration.GetPlacedItemCount were
-- speculative on the 12.0.7 PTR — not all builds expose them. Probe both,
-- fall back to the SV-backed cache that HOUSING_DECOR_PLACED/REMOVED
-- events maintain. pcall around every call so a renamed/removed function
-- doesn't taint the housing UI for downstream consumers.
function LiveCounts:GetPlaced(itemID)
    if C_Housing and type(C_Housing.GetPlacedItemCount) == "function" then
        local ok, count = pcall(C_Housing.GetPlacedItemCount, itemID)
        if ok and type(count) == "number" then
            return count
        end
    end
    if C_Decoration and type(C_Decoration.GetPlacedItemCount) == "function" then
        local ok, count = pcall(C_Decoration.GetPlacedItemCount, itemID)
        if ok and type(count) == "number" then
            return count
        end
    end
    local db = GetDB()
    if not db then return 0 end
    return db.placedCounts[itemID] or 0
end

function LiveCounts:SetPlaced(itemID, count)
    local db = GetDB()
    if not db then return end
    db.placedCounts[itemID] = count
end

-- Called from Core.lua's event dispatcher on HOUSING_DECOR_PLACED /
-- HOUSING_DECOR_REMOVED. Updates the local SV-backed counter so
-- GetPlaced has a useful fallback when the C_Housing query API isn't
-- available on this build. The event payload's exact arg shape varies
-- per PTR cycle; we accept (itemID) or (itemID, count) without assuming.
function LiveCounts:OnDecorChanged(event, ...)
    local itemID = ...
    if type(itemID) ~= "number" then return end
    local current = self:GetPlaced(itemID) or 0
    if event == "HOUSING_DECOR_PLACED" then
        self:SetPlaced(itemID, current + 1)
    elseif event == "HOUSING_DECOR_REMOVED" then
        self:SetPlaced(itemID, math.max(0, current - 1))
    end
    if Villa.Dashboard and Villa.Dashboard.RefreshDecorCounts then
        Villa.Dashboard:RefreshDecorCounts()
    end
end

-- ============================================================
-- Event frame
-- ============================================================

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        LiveCounts:ScanBags()
    elseif event == "BAG_UPDATE_DELAYED" then
        LiveCounts:ScanBags()
    elseif event == "BANKFRAME_OPENED" then
        LiveCounts:ScanBank()
    end
end)

-- Hook placed-item update event if the housing API exposes one
if C_Housing then
    -- Attempt to hook any known placed-item event; guard against nil
    local placedEvent = (C_Housing.PLACED_ITEM_UPDATED) or "HOUSING_PLACED_ITEM_UPDATED"
    pcall(function()
        eventFrame:RegisterEvent(placedEvent)
    end)
end

-- ============================================================
-- Module lifecycle (OnEnable wires the tooltip line)
-- ============================================================

function LiveCounts:OnEnable()
    -- Tooltip decoration: append "Owned: X  |  Placed: Y" for housing items
    if not TooltipDataProcessor or not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Item then
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if not tooltip or not tooltip.GetItem then return end
        local _, itemLink = tooltip:GetItem()
        if not itemLink then return end
        local itemID = tonumber(itemLink:match("item:(%d+)"))
        if not itemID then return end

        -- Only decorate housing-relevant items
        if not Villa:IsHousingRelevantItem(itemID) then return end

        local owned  = LiveCounts:GetOwned(itemID)
        local placed = LiveCounts:GetPlaced(itemID)
        if owned > 0 or placed > 0 then
            tooltip:AddLine(
                "|cFFFFD100Owned: " .. owned .. "  |  Placed: " .. placed .. "|r",
                1, 1, 1, false
            )
        end
    end)
end
