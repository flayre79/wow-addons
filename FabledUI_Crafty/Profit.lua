local M = _G.FabledUI_Crafty
M.Profit = M.Profit or {}
local P = M.Profit

local PERCENT_DIVISORS = {
    multicraft = 1100,
    resourcefulness = 900,
    ingenuity = 1000,
    craftingspeed = 2650,
}

-- P2-17: NaN/Inf guard. Auctionator/TSM occasionally return 0/0 (NaN) or
-- Inf when their stats DBs roll over a bucket boundary. Treating those as
-- 0 prevents profit math from cascading garbage into every dependent recipe.
local function sanitizePrice(value)
    if type(value) ~= "number" then
        return 0
    end
    if value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    return value
end

-- P0-2: Memoize Profit:CalculateRecipe results. The Goblin tab repaints the
-- full row list on every DataChanged, and a single repaint can hit
-- CalculateRecipe thousands of times via GetRecursiveUnitCost. Without a
-- result cache this re-walks the producer DAG for every single render pass.
-- Pattern lifted from CraftSim's relativeProfitCached
-- (.sample-addons/CraftSim/Classes/RecipeData.lua:7-58). The cache key is a
-- coarse fingerprint of "things that change the answer" — recipe ID, the
-- current crafter's gear stat block, the reagent set, and the engine
-- toggles. Anything subtler than that is correctly handled by InvalidateCache
-- being called from BAG_UPDATE_DELAYED, settings save, and StorageReady.
local _profitCache = {}
local _profitCacheHits, _profitCacheMisses = 0, 0

local function settingsHash()
    local s = M.settings or {}
    return string.format("%s:%s:%s:%s:%s",
        s.useCraftSimProfitModel and "1" or "0",
        s.profitIncludeAHCut == false and "0" or "1",
        s.profitUseSubcraftCost == false and "0" or "1",
        s.profitIncludeResourcefulness == false and "0" or "1",
        s.shoppingListModePSL and "1" or "0")
end

local function gearHash(gear)
    if type(gear) ~= "table" then
        return "0"
    end
    return string.format("%d:%d:%d:%d",
        tonumber(gear.multicraft) or 0,
        tonumber(gear.resourcefulness) or 0,
        tonumber(gear.ingenuity) or 0,
        tonumber(gear.craftingspeed) or 0)
end

local function reagentHash(materials)
    if type(materials) ~= "table" then
        return "0"
    end
    local parts = {}
    for i = 1, #materials do
        local mat = materials[i]
        if type(mat) == "table" and mat.itemID then
            parts[#parts + 1] = string.format("%d*%d", tonumber(mat.itemID) or 0, tonumber(mat.qty) or 0)
        end
    end
    return table.concat(parts, "|")
end

function P:InvalidateCache()
    _profitCache = {}
    _profitCacheHits, _profitCacheMisses = 0, 0
end

function P:GetCacheStats()
    return {
        hits = _profitCacheHits,
        misses = _profitCacheMisses,
        size = (function()
            local n = 0
            for _ in pairs(_profitCache) do n = n + 1 end
            return n
        end)(),
    }
end

-- Wire cache invalidation to module load so StorageReady fires drop any
-- stale entries that may have been computed before settings/db were ready.
-- Guarded by pcall — Core.lua sets up M.callbacks before any sub-module
-- file is loaded, but a future TOC reorder shouldn't break this module.
if type(M.RegisterCallback) == "function" then
    pcall(M.RegisterCallback, M, "CraftyProfitCache", "StorageReady", function()
        P:InvalidateCache()
    end)
end

function P:GetItemPrice(itemID)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    itemID = tonumber(itemID)
    if not itemID then
        return 0
    end

    if TSM_API and TSM_API.GetCustomPriceValue then
        local ok, price = pcall(TSM_API.GetCustomPriceValue, 'DBMarket', 'i:' .. itemID)
        if ok and type(price) == 'number' then
            return sanitizePrice(price)
        end
    end

    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, 'Crafty', itemID)
        if ok and type(price) == 'number' then
            return sanitizePrice(price)
        end
    end

    return sanitizePrice(M.db.history.prices[itemID] or 0)
end

function P:GetBestCrafterStats(recipe)
    if not recipe or not M.Alts then
        return nil, nil
    end
    local characterKey = M.Alts:GetBestCrafterForRecipe(recipe)
    if not characterKey then
        return nil, nil
    end
    local gearTotals = M.Gear and M.Gear:GetTotals(characterKey, recipe.profession) or nil
    local specSnapshot = M.Specs and M.Specs:GetSnapshot(characterKey, recipe.profession) or nil
    return characterKey, {
        gear = gearTotals,
        specs = specSnapshot,
    }
end

-- Maximum depth for sub-craft cost recursion. The visited table prevents
-- direct cycles (A -> A) but a long DAG (A -> B -> C -> ... -> Z) could
-- still chew tens of thousands of recipe lookups per top-level craft.
-- Capping depth keeps profit math finite even on malformed reagent graphs.
local PROFIT_MAX_DEPTH = 8

function P:GetRecursiveUnitCost(itemID, professionFilter, visited, depth)
    visited = visited or {}
    depth = depth or 0
    if depth >= PROFIT_MAX_DEPTH then
        return self:GetItemPrice(itemID)
    end
    local visitKey = tostring(itemID) .. ':' .. tostring(professionFilter or '')
    if visited[visitKey] then
        return self:GetItemPrice(itemID)
    end
    -- P0-6: Skillet's `visited[id] = true ... walk ... visited[id] = nil`
    -- pattern (.sample-addons/Skillet/SkilletQueue.lua:172-225). Clearing
    -- the entry after the walk lets sibling sub-recipes correctly re-enter
    -- the same producer once we've returned from this branch. Without the
    -- clear, two reagents that both expand into the same crafted producer
    -- silently fall back to GetItemPrice on the second reagent.
    visited[visitKey] = true
    local producer = M.Recipes:GetPrimaryProducerRecipe(itemID, professionFilter)
    if not producer then
        visited[visitKey] = nil
        return self:GetItemPrice(itemID)
    end
    local result = self:CalculateRecipe(producer.recipeID, {
        visited = visited,
        depth = depth + 1,
        forceCraftSimLike = true,
    })
    visited[visitKey] = nil
    if result and (result.expectedCostPerOutput or 0) > 0 then
        return result.expectedCostPerOutput
    end
    return self:GetItemPrice(itemID)
end

-- P2-15 helper: per-character "don't auto-craft, use raw price" reagent set.
local function isIgnoredMat(itemID)
    if not itemID then
        return false
    end
    local charKey = M.GetCurrentCharacterKey and M:GetCurrentCharacterKey() or nil
    local charSettings = M.db and M.db.charSettings or nil
    local entry = charSettings and charKey and charSettings[charKey] or nil
    local list = entry and entry.ignoredMats or nil
    return list and list[tonumber(itemID)] == true or false
end

function P:CalculateRecipe(recipeID, opts)
    -- CraftSim Module gate. When the module (or this feature) is disabled,
    -- callers get nil and skip rendering profit-derived UI.
    if M.CraftSim and not M.CraftSim:IsFeatureEnabled("profit") then
        return nil
    end
    opts = type(opts) == 'table' and opts or {}
    local recipe = M.Recipes:Get(recipeID)
    if not recipe then
        return nil
    end

    -- Propagate the visited set + depth from the caller so the recursion
    -- guard actually works across the CalculateRecipe -> GetRecursiveUnitCost
    -- -> CalculateRecipe boundary. Previously this was reset on every entry,
    -- which made the visited set useless for anything below the top frame.
    local visited = opts.visited or {}
    local depth = opts.depth or 0

    local characterKey, crafterStats = self:GetBestCrafterStats(recipe)
    local gear = crafterStats and crafterStats.gear or nil
    local useCraftSimLike = opts.forceCraftSimLike or (M.settings and M.settings.useCraftSimProfitModel)
    local applyAHCut = M.settings == nil or M.settings.profitIncludeAHCut ~= false
    local useSubcraftCost = M.settings == nil or M.settings.profitUseSubcraftCost ~= false
    local includeResourcefulness = M.settings == nil or M.settings.profitIncludeResourcefulness ~= false

    -- P0-2: result memo. Only at the top frame (depth == 0) — sub-craft
    -- calls inherit a unique visited set and shouldn't pull a top-level
    -- cached entry. Cache key fingerprints recipeID + crafter + gear stats
    -- + reagent set + settings, so any of those rolling over invalidates.
    if depth == 0 then
        local key = string.format("%s|%s|%s|%s|%s|%s",
            tostring(recipeID),
            tostring(characterKey or ""),
            gearHash(gear),
            reagentHash(recipe.materials),
            settingsHash(),
            useCraftSimLike and "cs" or "cr")
        local cached = _profitCache[key]
        if cached then
            _profitCacheHits = _profitCacheHits + 1
            return cached
        end
        _profitCacheMisses = _profitCacheMisses + 1
        opts._memoKey = key
    end

    local materialCost = 0
    local recursiveCost = 0
    for _, mat in ipairs(recipe.materials or {}) do
        local rawPrice = sanitizePrice(self:GetItemPrice(mat.itemID))
        materialCost = materialCost + (rawPrice * (mat.qty or 0))

        local unitCost = rawPrice
        -- P2-15: ignored-mats opt-out from sub-craft recursion.
        if useCraftSimLike and useSubcraftCost and depth < PROFIT_MAX_DEPTH and not isIgnoredMat(mat.itemID) then
            unitCost = sanitizePrice(self:GetRecursiveUnitCost(mat.itemID, mat.profession, visited, depth + 1))
        end
        recursiveCost = recursiveCost + (unitCost * (mat.qty or 0))
    end

    local outputQuantity = math.max(1, tonumber(recipe.outputQuantity) or 1)
    local salePricePerItem = self:GetItemPrice(recipe.itemID)
    local saleValue = salePricePerItem * outputQuantity
    if applyAHCut then
        saleValue = saleValue * 0.95
    end

    local chosenMaterialCost = useCraftSimLike and recursiveCost or materialCost
    local multicraftChance = gear and math.max(0, (gear.multicraft or 0) / PERCENT_DIVISORS.multicraft) or 0
    local resourcefulnessChance = gear and math.max(0, (gear.resourcefulness or 0) / PERCENT_DIVISORS.resourcefulness) or 0
    local expectedExtraItems = useCraftSimLike and (outputQuantity * 0.20 * multicraftChance) or 0
    local expectedSaleValue = saleValue + (salePricePerItem * expectedExtraItems * (applyAHCut and 0.95 or 1))
    local expectedSavings = (useCraftSimLike and includeResourcefulness) and (chosenMaterialCost * 0.30 * resourcefulnessChance) or 0
    local effectiveCost = math.max(0, chosenMaterialCost - expectedSavings)
    local profit = (useCraftSimLike and expectedSaleValue or saleValue) - effectiveCost
    local marginBase = useCraftSimLike and expectedSaleValue or saleValue
    local margin = marginBase > 0 and (profit / marginBase) * 100 or 0

    -- P2-17: scrub final outputs for NaN/Inf one last time, in case any
    -- intermediate division produced one (e.g. divide-by-zero on a 0-output
    -- recipe). Clamping to 0 here keeps the table sortable and the UI sane.
    local result = {
        recipeID = recipeID,
        itemID = recipe.itemID,
        recipeName = recipe.name,
        crafter = characterKey,
        salePrice = sanitizePrice(saleValue),
        salePricePerItem = sanitizePrice(salePricePerItem),
        materialCost = sanitizePrice(materialCost),
        recursiveMaterialCost = sanitizePrice(recursiveCost),
        effectiveMaterialCost = sanitizePrice(effectiveCost),
        expectedCostPerOutput = sanitizePrice(effectiveCost / outputQuantity),
        expectedSavings = sanitizePrice(expectedSavings),
        multicraftChance = sanitizePrice(multicraftChance),
        expectedExtraItems = sanitizePrice(expectedExtraItems),
        profit = sanitizePrice(profit),
        margin = sanitizePrice(margin),
        engine = useCraftSimLike and 'CraftSim-like' or 'Crafty',
    }

    if depth == 0 and opts._memoKey then
        _profitCache[opts._memoKey] = result
    end

    return result
end

function P:GetSortedRows()
    local rows = {}
    for recipeID in pairs(M.RecipeDB or {}) do
        local result = self:CalculateRecipe(recipeID)
        if result then
            rows[#rows + 1] = result
        end
    end
    for recipeID, recipe in pairs((M.db and M.db.cache and M.db.cache.recipes) or {}) do
        if not M.RecipeDB[recipeID] then
            local result = self:CalculateRecipe(recipeID)
            if result then
                rows[#rows + 1] = result
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.profit ~= b.profit then
            return a.profit > b.profit
        end
        return a.recipeName < b.recipeName
    end)
    return rows
end
