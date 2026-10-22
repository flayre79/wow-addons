local M = _G.FabledUI_Crafty
M.Materials = M.Materials or {}
local MT = M.Materials

-- 12.1.5 deletes the global GetCoinTextureString. This is what Blizzard's
-- removed shim pointed it at (Deprecated_CurrencyScript.lua).
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString

local function buildOpts()
    return {
        recursive = (M.settings and M.settings.useCraftSimQueuePlanner == true)
            or (M.filters and M.filters.powerCrafting == true) or nil,
    }
end

-- P0-3: cached single-pass bag scan. Callers that aggregate inventory across
-- many itemIDs can pull from this map instead of calling C_Item.GetItemCount
-- once per row (which iterates every bag slot internally). The cache lives
-- for the duration of one event-driven snapshot pass and is invalidated by
-- the BAG_UPDATE_DELAYED debounce in Core.lua.
local _bagCountsCache = nil
local _bagCountsCachedAt = 0

function MT:GetBagCounts(forceRefresh)
    if not forceRefresh and _bagCountsCache and (GetTime() - _bagCountsCachedAt) < 0.5 then
        return _bagCountsCache
    end
    if M.Util and M.Util.BuildBagCounts then
        _bagCountsCache = M.Util:BuildBagCounts()
    else
        _bagCountsCache = {}
    end
    _bagCountsCachedAt = GetTime()
    return _bagCountsCache
end

function MT:InvalidateBagCounts()
    _bagCountsCache = nil
    _bagCountsCachedAt = 0
end

function MT:GetBagCount(itemID)
    if not itemID then return 0 end
    return self:GetBagCounts()[tonumber(itemID)] or 0
end

-- P2-18: async item-info request. When C_Item.GetItemInfo returns nil on
-- cold login, ask Blizzard to resolve the item and re-fire the row render
-- once the data is cached. Pattern from PSL/TrackingWindow.lua:1925-1929.
local _pendingItemRequests = {}

function MT:RequestItemInfoAsync(itemID, onLoaded)
    itemID = tonumber(itemID)
    if not itemID or not C_Item then return end
    if _pendingItemRequests[itemID] then return end
    if C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(itemID) then
        return
    end

    _pendingItemRequests[itemID] = true
    if C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    if Item and Item.CreateFromItemID then
        local item = Item:CreateFromItemID(itemID)
        if item and item.ContinueOnItemLoad then
            item:ContinueOnItemLoad(function()
                _pendingItemRequests[itemID] = nil
                if onLoaded then
                    pcall(onLoaded, itemID)
                end
                if M.Fire then
                    M:Fire("DataChanged")
                end
            end)
        end
    end
end

function MT:CalculateTotals()
    return (M.Shopping and M.Shopping.BuildMaterialGraph and M.Shopping:BuildMaterialGraph(nil, buildOpts())) or {}
end

function MT:GetSortedTotals(shortageOnly)
    return (M.Shopping and M.Shopping.GetSortedRows and M.Shopping:GetSortedRows(shortageOnly, nil, buildOpts())) or {}
end

function MT:GetSummary()
    return (M.Shopping and M.Shopping.GetSummary and M.Shopping:GetSummary(nil, buildOpts())) or {
        totalItems = 0,
        shortageItems = 0,
        totalNeed = 0,
        totalHave = 0,
        totalQueuedProduced = 0,
        totalShortage = 0,
    }
end

function MT:IsRawMode()
    local opts = buildOpts()
    return opts.recursive == true
end

function MT:GetLumberCount()
    if M.Lumber and M.Lumber.GetTotalLumberCount then
        return M.Lumber:GetTotalLumberCount()
    end
    return 0
end

function MT:GetProducerSummary(itemID, professionFilter)
    local producer = M.Recipes and M.Recipes.GetPrimaryProducerRecipe and M.Recipes:GetPrimaryProducerRecipe(itemID, professionFilter) or nil
    if not producer then
        return nil
    end
    return {
        recipeID = producer.recipeID,
        name = producer.name,
        profession = producer.profession,
        outputQuantity = producer.outputQuantity or 1,
    }
end

function MT:QueueProducer(itemID, quantityNeeded)
    local producer = M.Recipes and M.Recipes.GetPrimaryProducerRecipe and M.Recipes:GetPrimaryProducerRecipe(itemID) or nil
    if not producer then
        return false
    end

    local craftsNeeded = math.max(1, math.ceil((tonumber(quantityNeeded) or 1) / math.max(1, tonumber(producer.outputQuantity) or 1)))
    return M.Queue:Add(producer.recipeID, craftsNeeded, nil, {
        engine = (M.settings and M.settings.useCraftSimQueuePlanner) and "CraftSim-like" or "Crafty",
    })
end

function MT:BuildShoppingListText()
    return (M.Shopping and M.Shopping.BuildShoppingListText and M.Shopping:BuildShoppingListText()) or "Crafty Shopping List\nAll queued materials are already covered."
end

-- =============================================================================
-- Source description (CR-009)
-- =============================================================================
-- Walk the suite's three-tier data strategy to expand a "Raw" / "Vendor" /
-- "Drop" base source into something actionable.
--   1. Live API resolution (already handled upstream by Shopping for crafted
--      chains; not re-checked here)
--   2. In-game capture (M.Capture)
--   3. Snapshot data (M.Data.MaterialSources / M.Data.VendorSources)
-- Returns a table { tier = "captured"|"snapshot"|"none", lines = {...},
-- summary = "short string for the Source column" }.
-- =============================================================================
local function ZoneNameFromMapID(mapID)
    if mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name then return info.name end
    end
    return "Unknown zone"
end

function MT:DescribeSource(itemID, baseSource)
    itemID = tonumber(itemID)
    if not itemID then
        return { tier = "none", summary = baseSource or "Raw", lines = {} }
    end

    local lines = {}

    -- Tier 2: in-game capture
    local capturedVendors = (M.Capture and M.Capture.GetVendorsSelling and M.Capture:GetVendorsSelling(itemID)) or {}
    local capturedDrops   = (M.Capture and M.Capture.GetSourcesDropping and M.Capture:GetSourcesDropping(itemID)) or {}

    if #capturedVendors > 0 or #capturedDrops > 0 then
        for _, vendor in ipairs(capturedVendors) do
            local zone = ZoneNameFromMapID(vendor.mapID)
            local price = (vendor.items and vendor.items[itemID] and vendor.items[itemID].priceCopper) or nil
            local priceText = price and string.format(" — %s", GetCoinTextureString and GetCoinTextureString(price) or (price .. "c")) or ""
            lines[#lines + 1] = string.format("Vendor: %s in %s%s |cff8c8c8c(observed)|r",
                vendor.name or ("Vendor " .. (vendor.npcID or "?")), zone, priceText)
        end
        for _, src in ipairs(capturedDrops) do
            local zone = ZoneNameFromMapID(src.mapID)
            lines[#lines + 1] = string.format("Drops from: %s in %s — seen %dx |cff8c8c8c(observed)|r",
                src.name or (src.sourceType .. " " .. src.sourceID), zone, src.observedCount or 1)
        end
        local summary = (#capturedVendors > 0 and #capturedDrops > 0)
            and string.format("%s · %d vendor(s), %d drop(s) seen", baseSource or "Raw", #capturedVendors, #capturedDrops)
            or  (#capturedVendors > 0
                and string.format("%s · %d vendor(s) seen", baseSource or "Raw", #capturedVendors)
                or  string.format("%s · %d drop(s) seen", baseSource or "Raw", #capturedDrops))
        return { tier = "captured", summary = summary, lines = lines }
    end

    -- Tier 3: snapshot data
    local snap = M.Data and M.Data.MaterialSources and M.Data.MaterialSources[itemID]
    if snap then
        local version = (M.Data.MaterialSources.__version) or "unknown"
        if snap.zones and #snap.zones > 0 then
            for _, z in ipairs(snap.zones) do
                local prof = snap.profession and (" — requires " .. snap.profession) or ""
                local density = z.density and (" [" .. z.density .. "]") or ""
                lines[#lines + 1] = string.format("Gather in %s%s%s", z.name or "?", density, prof)
            end
        end
        if snap.vendors and #snap.vendors > 0 then
            for _, v in ipairs(snap.vendors) do
                local zone = v.mapID and ZoneNameFromMapID(v.mapID) or v.zone or "?"
                local price = v.priceCopper and (GetCoinTextureString and GetCoinTextureString(v.priceCopper) or (v.priceCopper .. "c")) or "?"
                lines[#lines + 1] = string.format("Vendor: %s in %s — %s",
                    v.name or ("NPC " .. (v.npcID or "?")), zone, price)
            end
        end
        if snap.dropFrom and #snap.dropFrom > 0 then
            for _, d in ipairs(snap.dropFrom) do
                local zone = d.mapID and ZoneNameFromMapID(d.mapID) or "?"
                local chance = d.dropChance and string.format(" (%.1f%%)", d.dropChance * 100) or ""
                lines[#lines + 1] = string.format("Drops from %s in %s%s",
                    d.name or ("Mob " .. (d.npcID or "?")), zone, chance)
            end
        end
        if snap.bopOnly then
            lines[#lines + 1] = "|cffd95f5fBoP — must be crafted/looted personally|r"
        end

        local summary
        if #lines > 0 then
            summary = string.format("%s · snapshot %s", baseSource or "Raw", version)
        else
            summary = baseSource or "Raw"
        end
        return { tier = "snapshot", summary = summary, lines = lines, version = version }
    end

    -- Tier 4: nothing
    return { tier = "none", summary = (baseSource or "Raw") .. " · no source data", lines = {} }
end


-- ── Reagent inventory ────────────────────────────────────────────────────────
-- What the Materials tab is NOT: that view answers "what does my queue still
-- need", so it is empty with an empty queue and its rows are shortages. This
-- one answers "what crafting stock am I actually holding", independent of any
-- queue -- the reagent-bag view of the world.

local TRADEGOODS_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7

-- Every itemID the recipe corpus consumes, so reagents that are not classed as
-- Tradegoods (a few quest/consumable-classed items are used as reagents) still
-- count as crafting stock. Rebuilt only when the recipe corpus changes.
local _reagentIndex, _reagentIndexStamp = nil, nil

local function ReagentIndex()
    local corpus = M.Recipes and M.Recipes:GetAll() or {}
    -- Cheap identity check: the merged corpus table is replaced wholesale by
    -- Recipes:InvalidateMerged, so comparing the table itself is enough.
    if _reagentIndex and _reagentIndexStamp == corpus then
        return _reagentIndex
    end

    local index = {}
    for recipeID, recipe in pairs(corpus) do
        if type(recipe) == "table" and type(recipe.materials) == "table" then
            for _, mat in ipairs(recipe.materials) do
                local itemID = tonumber(mat.itemID)
                if itemID then
                    local entry = index[itemID]
                    if not entry then
                        entry = { recipes = {}, count = 0 }
                        index[itemID] = entry
                    end
                    if not entry.recipes[recipeID] then
                        entry.recipes[recipeID] = true
                        entry.count = entry.count + 1
                    end
                end
            end
        end
    end

    _reagentIndex = index
    _reagentIndexStamp = corpus
    return index
end

MT.ReagentIndex = ReagentIndex

-- Total held across bags, bank and the warband bank. GetItemCount answers for
-- the bank without it being open, which BuildBagCounts cannot do -- that only
-- walks the bags the client currently has slots for.
local function TotalHeld(itemID)
    if not (C_Item and C_Item.GetItemCount) then return 0 end
    local ok, total = pcall(C_Item.GetItemCount, itemID, true, false, true, true)
    if ok and type(total) == "number" then return total end
    -- Older signature: (itemID, includeBank, includeCharges, includeAccountBank)
    local ok2, fallback = pcall(C_Item.GetItemCount, itemID, true)
    return (ok2 and type(fallback) == "number") and fallback or 0
end

-- Every crafting reagent the player is currently holding.
--
-- Returns a list of { itemID, name, icon, quality, category, bags, total,
-- usedIn }, sorted by category then name. `usedIn` is how many recipes in the
-- corpus consume it, which is what makes a pile of 400 Weavercloth read as
-- useful rather than as clutter.
function MT:GetInventory()
    local bagCounts = self:GetBagCounts(true)
    local reagents = ReagentIndex()

    -- Union of "in my bags" and "known reagent I hold somewhere": the first
    -- catches stock the corpus has never heard of, the second catches reagents
    -- sitting in the bank with none in bags.
    local candidates = {}
    for itemID in pairs(bagCounts) do candidates[itemID] = true end
    for itemID in pairs(reagents) do candidates[itemID] = true end

    local rows = {}
    for itemID in pairs(candidates) do
        local isReagent = reagents[itemID] ~= nil
        local classID, subclassID, itemType, itemSubType
        if C_Item and C_Item.GetItemInfoInstant then
            local ok, _, iType, iSubType, _, _, cID, scID = pcall(C_Item.GetItemInfoInstant, itemID)
            if ok then
                itemType, itemSubType, classID, subclassID = iType, iSubType, cID, scID
            end
        end

        if isReagent or classID == TRADEGOODS_CLASS then
            local total = TotalHeld(itemID)
            if total > 0 then
                local name, _, quality, _, _, _, _, _, _, icon
                if C_Item and C_Item.GetItemInfo then
                    local ok, n, _, q, _, _, _, _, _, _, ic = pcall(C_Item.GetItemInfo, itemID)
                    if ok then name, quality, icon = n, q, ic end
                end
                -- Cold cache: ask Blizzard for the item and let the async
                -- callback re-fire the render rather than showing a blank row.
                if not name then
                    self:RequestItemInfoAsync(itemID)
                end
                -- ProfessionsHelper authored which professions consume each
                -- reagent. Where the recipe corpus has no row referencing an
                -- item, that authored list still answers "is this useful", so
                -- the material reads as belonging to a profession rather than
                -- as unused clutter.
                local meta = M.GetReagentMetadata and M:GetReagentMetadata(itemID) or nil
                local consumers = meta and meta.processingProfs or nil

                rows[#rows + 1] = {
                    itemID   = itemID,
                    name     = name or ("Item " .. itemID),
                    resolved = name ~= nil,
                    icon     = icon,
                    quality  = quality,
                    category = itemSubType or itemType or "Other",
                    bags     = bagCounts[itemID] or 0,
                    total    = total,
                    usedIn   = reagents[itemID] and reagents[itemID].count or 0,
                    consumers = consumers,
                    gatheringProf = meta and meta.gatheringProf or nil,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return a.name < b.name
    end)
    return rows
end

-- Roll-up for the tab's status line.
function MT:GetInventorySummary(rows)
    rows = rows or self:GetInventory()
    local categories, seen = 0, {}
    local units, unused = 0, 0
    for _, row in ipairs(rows) do
        if not seen[row.category] then
            seen[row.category] = true
            categories = categories + 1
        end
        units = units + row.total
        if row.usedIn == 0 then unused = unused + 1 end
    end
    return { stacks = #rows, categories = categories, units = units, unused = unused }
end
