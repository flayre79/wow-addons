local M = _G.FabledUI_Crafty
M.Recipes = M.Recipes or {}
local R = M.Recipes

local expansionSkillLines = {
    [2823] = "TWW",
    [2824] = "TWW",
    [2827] = "TWW",
    [2871] = "Midnight",
    [2872] = "Midnight",
    [2873] = "Midnight",
    [2874] = "Midnight",
}

-- Map any expansion-like string returned by Blizzard APIs or shipped in the
-- HDG donor import down to the canonical short name used in M.EXPANSION_ORDER
-- and the dropdown filter. The HDG importer concatenated profession into the
-- expansion column ("Khaz Algar Cooking", "Dragon Isles Engineering") and
-- Blizzard's API answers in long form ("Khaz Algar"), so without this layer
-- the expansion filter only ever matches a few rows.
local EXPANSION_PATTERNS = {
    -- Order matters: longest / most-specific patterns first.
    { pattern = "midnight",                 canonical = "Midnight" },
    { pattern = "khaz algar",               canonical = "TWW" },
    { pattern = "war within",               canonical = "TWW" },
    { pattern = "thaldraszus",              canonical = "Dragonflight" },
    { pattern = "dragon isles",             canonical = "Dragonflight" },
    { pattern = "dragonflight",             canonical = "Dragonflight" },
    { pattern = "shadowlands",              canonical = "Shadowlands" },
    { pattern = "kul tiran",                canonical = "BfA" },
    { pattern = "zandalari",                canonical = "BfA" },
    { pattern = "battle for azeroth",       canonical = "BfA" },
    { pattern = "legion",                   canonical = "Legion" },
    { pattern = "draenor",                  canonical = "WoD" },
    { pattern = "warlords of draenor",      canonical = "WoD" },
    { pattern = "pandaria",                 canonical = "MoP" },
    { pattern = "mists of pandaria",        canonical = "MoP" },
    { pattern = "cataclysm",                canonical = "Cataclysm" },
    { pattern = "northrend",                canonical = "WotLK" },
    { pattern = "wrath",                    canonical = "WotLK" },
    { pattern = "outland",                  canonical = "TBC" },
    { pattern = "burning crusade",          canonical = "TBC" },
    { pattern = "classic",                  canonical = "Classic" },
}

-- Memoized: this function is pure on input and called per-recipe per-render.
-- Without the cache, profit recursion causes 21-pattern × thousands of calls
-- per frame, which blows the game's "script ran too long" budget.
local _expansionCache = {}
local function NormalizeExpansion(value)
    if type(value) ~= "string" or value == "" then
        return "Current"
    end
    local cached = _expansionCache[value]
    if cached ~= nil then
        return cached
    end
    local lowered = value:lower()
    local result
    for _, entry in ipairs(EXPANSION_PATTERNS) do
        if lowered:find(entry.pattern, 1, true) then
            result = entry.canonical
            break
        end
    end
    if not result then
        for _, name in ipairs(M.EXPANSION_ORDER or {}) do
            if name and name:lower() == lowered then
                result = name
                break
            end
        end
    end
    result = result or value
    _expansionCache[value] = result
    return result
end
R.NormalizeExpansion = NormalizeExpansion

local REQUIRED_REAGENT_TYPE = 1

function R:NormalizeExpansion(value)
    return NormalizeExpansion(value)
end

-- Cached context from the most recent successful resolve. Used as a fallback
-- when the live API call returns nil — which happens in 12.0.5 when the
-- player is mid-tab-switch in the profession window or the trade skill is
-- not yet "ready". Without this cache the Rescan button frequently reports
-- "no profession window is open" when one clearly is.
local lastContext = nil

local function getOpenProfessionContext()
    -- Only return cached context if the profession frame is actually open;
    -- otherwise the user has closed it and we shouldn't pretend it's there.
    local frameOpen = _G.ProfessionsFrame and _G.ProfessionsFrame.IsVisible and _G.ProfessionsFrame:IsVisible()
    if not C_TradeSkillUI then
        return frameOpen and lastContext or nil
    end

    -- Modern 12.0 API. GetChildProfessionInfo returns the currently-displayed
    -- expansion variant (e.g. Midnight Tailoring); GetBaseProfessionInfo
    -- returns the base profession (Tailoring). Both can be available even
    -- when the legacy GetTradeSkillLine returns nil.
    local childInfo, baseInfo
    if type(C_TradeSkillUI.GetChildProfessionInfo) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
        if ok and type(info) == "table" then childInfo = info end
    end
    if type(C_TradeSkillUI.GetBaseProfessionInfo) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and type(info) == "table" then baseInfo = info end
    end

    -- Legacy GetTradeSkillLine path. Some 12.0 builds still return values.
    local legacySkillLineID, legacyDisplayName, legacyRank, legacyMaxRank
    local legacyParentID, legacyParentDisplay
    if type(C_TradeSkillUI.GetTradeSkillLine) == "function" then
        local ok, a, b, c, d, _e, f, g = pcall(C_TradeSkillUI.GetTradeSkillLine)
        if ok and a then
            legacySkillLineID, legacyDisplayName, legacyRank, legacyMaxRank, _, legacyParentID, legacyParentDisplay = a, b, c, d, _e, f, g
        end
    end

    local skillLineID = legacySkillLineID
        or (childInfo and (childInfo.skillLineID or childInfo.professionID))
        or (baseInfo and (baseInfo.skillLineID or baseInfo.professionID))

    -- Last-resort fallback: read the skill line off whatever recipe is
    -- currently selected in the Blizzard form. Works even when every
    -- C_TradeSkillUI.* call has returned nil (which we've seen on 12.0.5
    -- during tab transitions).
    if not skillLineID and _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage then
        local form = _G.ProfessionsFrame.CraftingPage.SchematicForm
        if form and type(form.GetRecipeInfo) == "function" then
            local ok, recipeInfo = pcall(form.GetRecipeInfo, form)
            if ok and type(recipeInfo) == "table" then
                skillLineID = recipeInfo.tradeSkillLineID
                    or recipeInfo.parentTradeSkillLineID
                    or recipeInfo.recipeID
            end
        end
    end

    if not skillLineID then
        -- ProfessionsFrame might be open on Specializations/Crafting Orders
        -- where no tradeskill line is active. Return cached so Rescan still
        -- has a sensible target — but only if the frame is actually visible.
        return frameOpen and lastContext or nil
    end

    local info = type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID) or nil
    -- Empty-string-aware coalesce: on Midnight builds GetChildProfessionInfo
    -- can return professionName == "" (truthy!), which used to win the chain
    -- and store blank profession names on every scanned recipe. Also prefer
    -- the BASE profession name ("Tailoring") over expansion-variant names
    -- ("Midnight Tailoring") — filters, tag pills, and the profession color
    -- map all key on the base name.
    local function nz(value)
        if type(value) == "string" and value ~= "" then return value end
        return nil
    end
    local professionName = nz(baseInfo and baseInfo.professionName)
        or nz(info and info.parentProfessionName)
        or nz(info and info.professionName)
        or nz(childInfo and childInfo.parentProfessionName)
        or nz(childInfo and childInfo.professionName)
        or nz(legacyParentDisplay)
        or nz(legacyDisplayName)
        or "Current Profession"
    local professionID = (info and info.professionID)
        or (baseInfo and baseInfo.professionID)
        or legacyParentID
        or skillLineID
    local skillLevel = (childInfo and childInfo.skillLevel)
        or (info and info.skillLevel)
        or legacyRank
        or 0
    local maxSkillLevel = (childInfo and childInfo.maxSkillLevel)
        or (info and info.maxSkillLevel)
        or legacyMaxRank
        or 0
    local rawExpansion = expansionSkillLines[skillLineID]
        or (childInfo and nz(childInfo.expansionName) and childInfo.expansionName ~= "Unknown" and childInfo.expansionName)
        or (info and nz(info.expansionName) and info.expansionName ~= "Unknown" and info.expansionName)
        or nz(legacyDisplayName)
        or "Current"
    local expansionName = NormalizeExpansion(rawExpansion)

    local context = {
        tradeSkillLineID = skillLineID,
        parentTradeSkillLineID = legacyParentID or (baseInfo and baseInfo.professionID),
        professionName = professionName,
        professionID = professionID,
        skillLevel = skillLevel,
        maxSkillLevel = maxSkillLevel,
        expansion = expansionName,
    }
    lastContext = context
    return context
end

local function getItemName(itemID)
    if not itemID then
        return nil
    end
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(itemID)
        if name then
            return name
        end
    end
    return string.format("Item %s", tostring(itemID))
end

local function pickRepresentativeReagent(slot)
    if type(slot) ~= "table" or type(slot.reagents) ~= "table" then
        return nil
    end

    local best
    for _, reagent in pairs(slot.reagents) do
        if type(reagent) == "table" and reagent.itemID then
            best = reagent
            if type(reagent.quality) == "number" and reagent.quality == 1 then
                return reagent
            end
        end
    end
    return best
end

local function extractMaterials(recipeID)
    local materials = {}
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetRecipeSchematic) ~= "function" then
        return materials
    end

    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or type(schematic) ~= "table" then
        return materials
    end

    for _, slot in pairs(schematic.reagentSlotSchematics or {}) do
        if (slot.reagentType == REQUIRED_REAGENT_TYPE) and tonumber(slot.quantityRequired or 0) > 0 then
            local reagent = pickRepresentativeReagent(slot)
            if reagent and reagent.itemID then
                materials[#materials + 1] = {
                    itemID = reagent.itemID,
                    name = getItemName(reagent.itemID),
                    qty = tonumber(slot.quantityRequired) or 0,
                    source = "Raw",
                    quality = reagent.quality,
                    slotText = slot.slotText,
                }
            end
        end
    end

    return materials
end

local function buildLiveRecipeRecord(recipeID, context)
    local recipeInfo = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID) or nil
    if type(recipeInfo) ~= "table" or not recipeInfo.name then
        return nil
    end

    local schematic = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local okSchematic, result = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        if okSchematic then
            schematic = result
        end
    end

    local outputInfo = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData then
        local okOutput, result = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
        if okOutput then
            outputInfo = result
        end
    end

    local itemID = outputInfo and outputInfo.itemID or nil
    if not itemID and recipeInfo.hyperlink and C_Item and C_Item.GetItemInfoInstant then
        itemID = select(1, C_Item.GetItemInfoInstant(recipeInfo.hyperlink))
    end

    -- IMPORTANT: only `recipeInfo.learned` means "this character knows this recipe".
    -- `C_TradeSkillUI.IsRecipeProfessionLearned` only checks whether the profession
    -- itself is learned, so it must NOT be used here (it would mark every recipe in
    -- a learned profession as collected, hiding the real "Unknown" rows).
    local learned = recipeInfo.learned and true or false

    local outputQuantity = 1
    if type(schematic) == "table" then
        outputQuantity = math.max(1, tonumber(schematic.quantityMax or schematic.quantityMin or 1) or 1)
    end

    local categoryName = recipeInfo.categoryName or recipeInfo.recipeType or (recipeInfo.isGatheringRecipe and "Gathering") or "Live"
    local sizeText = outputQuantity > 1 and ("x" .. tostring(outputQuantity)) or (recipeInfo.maxQuality and ("Q" .. tostring(recipeInfo.maxQuality))) or "Single"

    return {
        recipeID = recipeID,
        name = recipeInfo.name,
        spellID = recipeInfo.recipeID or recipeID,
        itemID = itemID,
        itemName = itemID and getItemName(itemID) or recipeInfo.name,
        profession = context.professionName,
        expansion = context.expansion,
        category = tostring(categoryName),
        style = recipeInfo.supportsQualities and "Quality" or "Live",
        size = sizeText,
        collected = learned,
        learned = learned,
        supportsQualities = recipeInfo.supportsQualities and true or false,
        maxQuality = recipeInfo.maxQuality,
        outputQuantity = outputQuantity,
        sourceType = "LIVE",
        tradeSkillLineID = context.tradeSkillLineID,
        professionID = context.professionID,
        skillUp = recipeInfo.numSkillUps or 0,
        materials = extractMaterials(recipeID),
        lastScanned = time(),
    }
end

-- Aggregate every recipe ID the open profession exposes by combining all
-- available enumeration APIs. See Alts.lua for the same pattern.
local function collectOpenProfessionRecipeIDs()
    local seen, ids = {}, {}
    if not C_TradeSkillUI then
        return ids
    end

    local function add(recipeID)
        recipeID = tonumber(recipeID)
        if recipeID and not seen[recipeID] then
            seen[recipeID] = true
            ids[#ids + 1] = recipeID
        end
    end

    if type(C_TradeSkillUI.GetCategories) == "function" then
        local okCats, categories = pcall(C_TradeSkillUI.GetCategories)
        if okCats and type(categories) == "table" then
            for _, categoryID in ipairs(categories) do
                if type(C_TradeSkillUI.GetRecipesForCategory) == "function" then
                    local okRecipes, recipes = pcall(C_TradeSkillUI.GetRecipesForCategory, categoryID)
                    if okRecipes and type(recipes) == "table" then
                        for _, recipeID in ipairs(recipes) do
                            add(recipeID)
                        end
                    end
                end
            end
        end
    end

    if type(C_TradeSkillUI.GetFilteredRecipeIDs) == "function" then
        local okFiltered, filtered = pcall(C_TradeSkillUI.GetFilteredRecipeIDs, true)
        if okFiltered and type(filtered) == "table" then
            for _, recipeID in ipairs(filtered) do
                add(recipeID)
            end
        end
    end

    if type(C_TradeSkillUI.GetAllRecipeIDs) == "function" then
        local okAll, allIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if okAll and type(allIDs) == "table" then
            for _, recipeID in ipairs(allIDs) do
                add(recipeID)
            end
        end
    end

    return ids
end

function R:GetOpenProfessionContext()
    return getOpenProfessionContext()
end

-- Apply a freshly-scanned recipe set to the persisted cache.
--
-- Replaces the LIVE rows belonging to `tradeSkillLineID` with `fresh`, leaving
-- other skill lines and every imported (non-LIVE) row untouched. Returns true
-- if anything was written.
--
-- The one rule that matters: an EMPTY `fresh` deletes nothing. ScanOpenProfession
-- is driven by SKILL_LINES_CHANGED / TRADE_SKILL_LIST_UPDATE, which also fire as
-- the Blizzard profession window closes and during login. At those moments
-- C_TradeSkillUI still answers GetBaseProfessionInfo -- so a context resolves and
-- the scan looks legitimate -- but the recipe list is already gone. Pruning first
-- and writing second turned each of those no-op events into a full wipe of the
-- persisted cache: Crafty went blank the instant the profession window closed and
-- stayed blank until a manual rescan. An empty answer is not evidence that the
-- character knows no recipes.
--
-- Kept pure and separate from the scan so the rule is testable offline: the bug
-- only fires when the live API is unavailable, which is precisely when no
-- API-driven test can reach it.
function R:CommitScan(existing, fresh, tradeSkillLineID)
    if type(existing) ~= "table" or type(fresh) ~= "table" then
        return false
    end
    if next(fresh) == nil then
        return false
    end

    for recipeID, recipe in pairs(existing) do
        if recipe and recipe.sourceType == "LIVE" and recipe.tradeSkillLineID == tradeSkillLineID then
            existing[recipeID] = nil
        end
    end
    for recipeID, record in pairs(fresh) do
        existing[recipeID] = record
    end
    return true
end

function R:ScanOpenProfession(markDirty)
    if M.EnsureStorageTables then
        M:EnsureStorageTables()
    end
    if not C_TradeSkillUI then
        return 0
    end

    -- P1-A10: linked-trade-skill / guild-trade-skill rejection guard.
    -- When the player Shift-clicks a guildie's profession or opens a guild
    -- profession via the Communities UI, C_TradeSkillUI returns *that*
    -- character's recipe list, and a naive scan would overwrite our own
    -- alt's cached recipe set with someone else's data. Bail before any
    -- mutation happens. Pattern from
    -- .sample-addons/HousingCraftTracker/HousingCraftTracker.lua:4076-4082.
    if (C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked())
        or (C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild()) then
        return 0
    end

    local context = getOpenProfessionContext()
    if not context then
        return 0
    end

    M.db.cache = type(M.db.cache) == "table" and M.db.cache or {}
    M.db.cache.recipes = type(M.db.cache.recipes) == "table" and M.db.cache.recipes or {}
    M.db.cache.scanMeta = type(M.db.cache.scanMeta) == "table" and M.db.cache.scanMeta or {}

    -- Build the new set BEFORE touching the stored one.
    --
    -- This scan is driven by SKILL_LINES_CHANGED / TRADE_SKILL_LIST_UPDATE,
    -- which also fire as the profession window *closes* and during login. At
    -- those moments C_TradeSkillUI still answers GetBaseProfessionInfo -- so a
    -- context resolves and we look "open" -- but its recipe list is already
    -- gone, so the scan collects nothing. The old order pruned every LIVE row
    -- for the skill line first and wrote the results second, which turned each
    -- of those no-op events into a full wipe of the persisted cache: the
    -- Recipes tab went blank the instant the Blizzard window was closed, and
    -- stayed blank until a manual rescan.
    --
    -- An empty answer is not evidence that the character knows no recipes, so
    -- it must never be allowed to delete anything.
    -- Stamp who saw this. db.cache is account-wide, so `learned` alone cannot
    -- answer "does THIS character know it" -- without the stamp the only
    -- per-character record is the Alt Roster mirror, and that module is
    -- LoadOnDemand and user-disableable. See R:IsKnownByCurrentCharacter.
    local scannedBy = M:GetCurrentCharacterKey()

    local recipeIDs = collectOpenProfessionRecipeIDs()
    local fresh, count = {}, 0
    for _, recipeID in ipairs(recipeIDs) do
        local record = buildLiveRecipeRecord(recipeID, context)
        if record then
            record.scannedBy = scannedBy
            fresh[recipeID] = record
            count = count + 1
        end
    end

    -- P0-5: belt-and-suspenders — invalidate the merged cache before mutating
    -- so any cross-module call that lands during the commit (e.g. an event
    -- handler firing R:Get(id) mid-mutation) doesn't cement a half-built
    -- view. The InvalidateMerged() at the end of the scan is the primary
    -- correctness flip; this one defends against re-entrant readers.
    self:InvalidateMerged()

    if not self:CommitScan(M.db.cache.recipes, fresh, context.tradeSkillLineID) then
        return 0
    end

    -- Mirror the scan into the current character's alt record so the Recipes tab
    -- can resolve "known by current character" without the trade-skill window open.
    local altRecipes
    if M.Alts and M.Alts.RegisterCurrentCharacter then
        local _, charEntry = M.Alts:RegisterCurrentCharacter()
        if type(charEntry) == "table" then
            charEntry.recipes = type(charEntry.recipes) == "table" and charEntry.recipes or {}
            altRecipes = charEntry.recipes
        end
    end

    local learnedCount = 0
    if altRecipes then
        for recipeID, record in pairs(fresh) do
            if record.learned then
                local existing = altRecipes[recipeID]
                if type(existing) ~= "table" then
                    existing = {}
                end
                existing.learned = true
                existing.name = record.name
                existing.tradeSkillLineID = context.tradeSkillLineID
                existing.professionID = context.professionID
                existing.professionName = context.professionName
                existing.lastSeen = record.lastScanned
                altRecipes[recipeID] = existing
                learnedCount = learnedCount + 1
            end
        end
    end

    M.db.cache.scanMeta[context.professionName] = {
        tradeSkillLineID = context.tradeSkillLineID,
        professionID = context.professionID,
        professionName = context.professionName,
        expansion = context.expansion,
        count = count,
        lastScanned = time(),
    }

    -- The merged map just changed; force GetAll to rebuild on next read.
    self:InvalidateMerged()

    if markDirty then
        M:MarkDirty()
    end

    -- Always notify listeners — UI tabs need to refresh whether or not we
    -- pushed a dirty flag to DataVault.
    if M.Fire then
        M:Fire("DataChanged")
    end

    if M._craftyScanDebug then
        local catCount = 0
        if C_TradeSkillUI and type(C_TradeSkillUI.GetCategories) == "function" then
            local okCats, cats = pcall(C_TradeSkillUI.GetCategories)
            if okCats and type(cats) == "table" then
                catCount = #cats
            end
        end
        M:Print(string.format("scan %s (sl=%s): %d categories, %d ids -> %d stored, %d learned",
            tostring(context.professionName), tostring(context.tradeSkillLineID), catCount,
            #(recipeIDs or {}), count, learnedCount))
    end

    return count
end

-- Normalize a HousingDecorGuide-imported row (Data/RecipeSources.lua) into the
-- RecipeDB shape used elsewhere. The importer ships `reagents = {itemID, qty}`
-- whereas the rest of Crafty consumes `materials = {itemID, qty}`; mirror to
-- keep tooltip / queue / shopping math working unchanged.
local function NormalizeImportedRecipe(recipeID, row)
    local materials = row.materials
    if (not materials) and type(row.reagents) == "table" then
        materials = {}
        for index, reagent in ipairs(row.reagents) do
            materials[index] = {
                itemID = reagent.itemID,
                qty    = reagent.qty,
                name   = reagent.name,
                source = reagent.source,
            }
        end
    end
    return {
        recipeID   = tonumber(recipeID) or row.recipeID,
        name       = row.name,
        spellID    = row.spellID,
        itemID     = row.itemID,
        decorID    = row.decorID,
        profession = row.profession,
        expansion  = NormalizeExpansion(row.expansion),
        category   = row.category,
        style      = row.style,
        size       = row.size,
        materials  = materials or {},
        learned    = nil,
        collected  = nil,
        _source    = "import",
    }
end

-- Memoized merged map. Profit recursion calls `Recipes:Get` thousands of
-- times per render; without this cache each call rebuilt the merged table
-- from scratch (247+ HDG rows × normalize) and the script-time budget got
-- blown after a few render passes. Invalidated by any code path that
-- mutates RecipeDB, the imported corpus, or the live cache.
local _mergedCache = nil
local _mergedDirty = true

function R:InvalidateMerged()
    _mergedDirty = true
    _mergedCache = nil
end

function R:GetAll()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    -- Self-heal: never let an EMPTY memo stick. If the first build ran before
    -- storage resolved / data packs loaded, it memoized {} and the UI showed
    -- 0 recipes all session despite a populated persisted cache. Rebuilding
    -- an empty corpus is nearly free, so retry until something exists.
    if _mergedCache and not _mergedDirty and next(_mergedCache) ~= nil then
        return _mergedCache
    end

    local merged = {}

    -- Imported HDG corpus first; live RecipeDB and runtime cache override on top
    -- so per-character `learned`/`collected` state always wins over the snapshot.
    if M.Data and type(M.Data.RecipeSources) == "table" then
        for recipeID, row in pairs(M.Data.RecipeSources) do
            if type(recipeID) == "number" and type(row) == "table" then
                merged[recipeID] = NormalizeImportedRecipe(recipeID, row)
            end
        end
    end

    -- ProfessionsHelper's RecipeDB: the only Midnight/TWW reagent data in the
    -- corpus. The housing-decor import above covers older expansions only, so
    -- without this every current-expansion recipe had an empty material list
    -- and the shopping/queue math silently costed them at zero.
    if M.Data and type(M.Data.RecipeReagents) == "table" then
        for recipeID, row in pairs(M.Data.RecipeReagents) do
            if type(recipeID) == "number" and type(row) == "table" then
                local materials = {}
                for _, material in ipairs(row.materials or {}) do
                    materials[#materials + 1] = {
                        itemID = material.itemID,
                        qty = material.qty,
                        -- Quality tiers of the same reagent. Bag counting has
                        -- to consider all of them, not just the base item.
                        variants = material.variants,
                    }
                end
                merged[recipeID] = {
                    recipeID = recipeID,
                    name = row.name or ("Recipe " .. recipeID),
                    profession = row.profession,
                    expansion = row.expansion,
                    outputQuantity = row.yield or 1,
                    materials = materials,
                    sourceType = "IMPORT",
                    category = "Reagents",
                }
            end
        end
    end
    for recipeID, recipe in pairs(M.RecipeDB or {}) do
        merged[tonumber(recipeID) or recipeID] = recipe
    end
    for recipeID, recipe in pairs((M.db and M.db.cache and M.db.cache.recipes) or {}) do
        merged[tonumber(recipeID) or recipeID] = recipe
    end

    _mergedCache = merged
    _mergedDirty = false
    return merged
end

function R:Get(recipeID)
    return self:GetAll()[tonumber(recipeID)]
end

function R:IsCollected(recipe)
    if not recipe then
        return false
    end
    return recipe.collected == true or recipe.learned == true
end

-- Decor-output collection check.
-- Prefers Villa's catalog if loaded; otherwise falls back to inventory check.
function R:IsDecorCollected(recipe)
    if not recipe then
        return false
    end
    local itemID = tonumber(recipe.itemID)
    if not itemID or itemID <= 0 then
        return false
    end

    local villa = rawget(_G, "FabledUI_Villa")
    if villa and type(villa.IsKnownDecorItem) == "function" then
        local ok, known = pcall(villa.IsKnownDecorItem, villa, itemID)
        if ok and known then
            return true
        end
    end
    if villa and type(villa.GetCollectionState) == "function" then
        local ok, state = pcall(villa.GetCollectionState, villa, itemID)
        if ok and type(state) == "table" and state.known then
            return true
        end
    end

    -- Fallback: check current character's bags/bank/reagent bank for the output item.
    -- P2-16: route through the warband-bank-aware safe shim.
    if M.Util and M.Util.GetItemCountSafe then
        local count = M.Util:GetItemCountSafe(itemID, true, false, true, true)
        if (tonumber(count) or 0) > 0 then
            return true
        end
    elseif C_Item and C_Item.GetItemCount then
        local okCount, count = pcall(C_Item.GetItemCount, itemID, true, false, true)
        if okCount and (tonumber(count) or 0) > 0 then
            return true
        end
    end

    return false
end

-- Does the CURRENT character know this recipe?
--
-- Every source here can only answer "yes"; none of them may answer "no" on
-- another's behalf. That asymmetry is the whole point. The live API used to be
-- consulted first and trusted in both directions:
--
--     if info.learned ~= nil then return info.learned and true or false end
--
-- With the profession window closed, C_TradeSkillUI answers learned=false for
-- recipes the character demonstrably knows, so that early return short-circuited
-- both persisted sources below and the Recipes tab reported "Known 0 · Alt only 0
-- · Unknown 674" for a fully-scanned profession. Since every persisted source
-- only ever records positives, falling through on a negative is safe.
function R:IsKnownByCurrentCharacter(recipeID)
    recipeID = tonumber(recipeID) or recipeID
    local currentCharacter = M:GetCurrentCharacterKey()

    -- Live truth, in the affirmative only.
    if C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and type(info) == "table" and info.learned == true then
            return true
        end
    end

    -- Persisted per-character mirror, written by ScanOpenProfession.
    if M.Alts and M.Alts.IsRecipeKnownByCharacter
        and M.Alts:IsRecipeKnownByCharacter(recipeID, currentCharacter) then
        return true
    end

    -- The scan's own record. The mirror above lives in FabledUI_Crafty_Roster,
    -- which is LoadOnDemand and can be switched off in Settings; when it is,
    -- the mirror simply does not exist and knowledge would otherwise read as
    -- zero forever. The scan still banked what it saw, stamped with the
    -- character that saw it, so it can answer for itself.
    local cached = M.db and M.db.cache and M.db.cache.recipes and M.db.cache.recipes[recipeID]
    if type(cached) == "table" and cached.learned == true and cached.scannedBy == currentCharacter then
        return true
    end

    return false
end

function R:IsKnownByAnyAlt(recipeID)
    local knownBy = (M.Alts and M.Alts:GetKnownBy(recipeID)) or {}
    return #knownBy > 0, knownBy
end

function R:GetKnowledgeState(recipeID)
    local currentKnown = self:IsKnownByCurrentCharacter(recipeID)
    local knownBy = (M.Alts and M.Alts:GetKnownBy(recipeID)) or {}
    local currentCharacter = M:GetCurrentCharacterKey()

    if currentKnown then
        return "CURRENT", knownBy
    end

    for _, characterKey in ipairs(knownBy) do
        if characterKey ~= currentCharacter then
            return "ALT", knownBy
        end
    end

    return "UNKNOWN", knownBy
end

function R:MatchesSearch(recipe, query, searchMats)
    query = (query or ""):lower()
    if query == "" then
        return true
    end

    local haystacks = {
        recipe.name,
        recipe.itemName,
        recipe.profession,
        recipe.expansion,
        recipe.category,
        recipe.style,
        recipe.size,
        recipe.sourceType,
        recipe.slotText,
    }

    for _, value in ipairs(haystacks) do
        if type(value) == "string" and value:lower():find(query, 1, true) then
            return true
        end
    end

    if searchMats and recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            local matName = mat.name
            if (not matName) and mat.itemID and getItemName then
                matName = getItemName(mat.itemID)
            end
            if type(matName) == "string" and matName:lower():find(query, 1, true) then
                return true
            end
            if type(mat.profession) == "string" and mat.profession:lower():find(query, 1, true) then
                return true
            end
            if type(mat.source) == "string" and mat.source:lower():find(query, 1, true) then
                return true
            end
            if mat.itemID and tostring(mat.itemID):find(query, 1, true) then
                return true
            end
        end
    end

    return false
end

function R:IsCraftable(recipe)
    if not recipe or not recipe.materials or #recipe.materials == 0 then
        return false, 0
    end

    -- P0-3: pull from the cached single-pass bag-counts map when available.
    -- IsCraftable is called once per recipe per filtered-list render; with
    -- 2,000+ recipes that's 2,000+ * (reagents-per-recipe) GetItemCount
    -- calls, each scanning every bag slot. The map collapses that to one
    -- bag walk per snapshot pass.
    local bagCounts = M.Materials and M.Materials.GetBagCounts and M.Materials:GetBagCounts() or nil

    local maxCraftable
    for _, mat in ipairs(recipe.materials) do
        local have
        if bagCounts then
            have = bagCounts[tonumber(mat.itemID) or -1] or 0
        elseif M.Util and M.Util.GetItemCountSafe then
            have = M.Util:GetItemCountSafe(mat.itemID, true, false, true, true)
        elseif C_Item and C_Item.GetItemCount then
            have = C_Item.GetItemCount(mat.itemID, true) or 0
        else
            have = 0
        end
        local perCraft = math.max(1, mat.qty or 1)
        local possible = math.floor(have / perCraft)
        if maxCraftable == nil or possible < maxCraftable then
            maxCraftable = possible
        end
    end

    maxCraftable = maxCraftable or 0
    return maxCraftable > 0, maxCraftable
end

function R:GetFilteredList()
    local list = {}
    local query = M.filters.text or ""
    local searchMats = M.filters.searchMats
    local filterProfession = M.filters.profession or "ALL"
    local filterExpansion = M.filters.expansion or "ALL"
    local filterCollected = M.filters.collected or "ALL"
    local readyOnly = M.filters.readyOnly == true
    local uncollectedOnly = M.filters.uncollectedOnly == true
    -- Default-ON filter: show only recipes the current character actually
    -- knows (or has on an alt). Players overwhelmingly want "what I can
    -- craft" first; the catalog is reachable by toggling this off.
    local knownOnly = M.filters.knownOnly == true

    -- Search overrides expansion AND known-only caps so a query reaches the
    -- full corpus — users searching for "Tent" or "Sunfire Silk" expect
    -- their query to find matches even in unlearned recipes / other expansions.
    if query ~= "" then
        filterExpansion = "ALL"
        knownOnly = false
    end

    for recipeID, recipe in pairs(self:GetAll()) do
        local knowledgeState = self:GetKnowledgeState(recipeID)
        local craftable, craftableCount = self:IsCraftable(recipe)
        local collected = self:IsCollected(recipe)
        local decorCollected = self:IsDecorCollected(recipe)

        local passes = true
        passes = passes and self:MatchesSearch(recipe, query, searchMats)
        passes = passes and (filterProfession == "ALL" or recipe.profession == filterProfession)
        -- Normalize on the way out so legacy cached rows that were stored with
        -- raw API strings (e.g. "Khaz Algar") still match the canonical filter.
        passes = passes and (filterExpansion == "ALL" or NormalizeExpansion(recipe.expansion) == filterExpansion)
        passes = passes and (not readyOnly or craftable)
        passes = passes and (not uncollectedOnly or not decorCollected)
        passes = passes and (not knownOnly or knowledgeState == "CURRENT" or knowledgeState == "ALT")

        if filterCollected == "COLLECTED" then
            passes = passes and collected
        elseif filterCollected == "UNCOLLECTED" then
            passes = passes and not collected
        end

        if passes then
            list[#list + 1] = {
                recipeID = recipeID,
                recipe = recipe,
                knowledgeState = knowledgeState,
                craftable = craftable,
                craftableCount = craftableCount,
                decorCollected = decorCollected,
            }
        end
    end

    local professionOrder = {}
    local expansionOrder = {}
    for index, name in ipairs(M.PROFESSION_ORDER or {}) do
        professionOrder[name] = index
    end
    for index, name in ipairs(M.EXPANSION_ORDER or {}) do
        expansionOrder[name] = index
    end

    table.sort(list, function(a, b)
        local ap = professionOrder[a.recipe.profession] or 999
        local bp = professionOrder[b.recipe.profession] or 999
        if ap ~= bp then
            return ap < bp
        end
        local ae = expansionOrder[a.recipe.expansion] or 999
        local be = expansionOrder[b.recipe.expansion] or 999
        if ae ~= be then
            return ae < be
        end
        return a.recipe.name < b.recipe.name
    end)

    return list
end

function R:GetCollectionProgress(profession)
    local total, collected = 0, 0
    for _, recipe in pairs(self:GetAll()) do
        if not profession or recipe.profession == profession then
            total = total + 1
            if self:IsCollected(recipe) then
                collected = collected + 1
            end
        end
    end

    local percent = total > 0 and math.floor((collected / total) * 100 + 0.5) or 0
    return collected, total, percent
end

function R:GetSummaryStats(professionFilter)
    local filtered = self:GetFilteredList()
    local knownCurrent, knownAltOnly, unknown, craftable = 0, 0, 0, 0
    for _, row in ipairs(filtered) do
        if (not professionFilter) or row.recipe.profession == professionFilter then
            if row.knowledgeState == "CURRENT" then
                knownCurrent = knownCurrent + 1
            elseif row.knowledgeState == "ALT" then
                knownAltOnly = knownAltOnly + 1
            else
                unknown = unknown + 1
            end
            if row.craftable then
                craftable = craftable + 1
            end
        end
    end
    return {
        filtered = #filtered,
        knownCurrent = knownCurrent,
        knownAltOnly = knownAltOnly,
        unknown = unknown,
        craftable = craftable,
    }
end

function R:GetProfessionExpansionMatrix()
    local matrix = {}
    for _, profession in ipairs(M.PROFESSION_ORDER or {}) do
        matrix[profession] = {}
    end

    for recipeID, recipe in pairs(self:GetAll()) do
        matrix[recipe.profession] = matrix[recipe.profession] or {}
        local bucket = matrix[recipe.profession][recipe.expansion] or { total = 0, collected = 0, known = 0, ready = 0 }
        bucket.total = bucket.total + 1
        if self:IsCollected(recipe) then
            bucket.collected = bucket.collected + 1
        end
        local known = self:IsKnownByAnyAlt(recipeID)
        if known then
            bucket.known = bucket.known + 1
        end
        local craftable = self:IsCraftable(recipe)
        if craftable then
            bucket.ready = bucket.ready + 1
        end
        matrix[recipe.profession][recipe.expansion] = bucket
    end
    return matrix
end

function R:GetKnownByDisplay(recipeID)
    local knownBy = (M.Alts and M.Alts:GetKnownBy(recipeID)) or {}
    if #knownBy == 0 then
        return "Unknown", knownBy
    end

    local currentCharacter = M:GetCurrentCharacterKey()
    local altNames = {}
    local currentKnown = false
    for _, characterKey in ipairs(knownBy) do
        if characterKey == currentCharacter then
            currentKnown = true
        else
            altNames[#altNames + 1] = M:GetShortCharacterName(characterKey)
        end
    end

    if currentKnown then
        if #altNames > 0 then
            return "You + " .. table.concat(altNames, ", "), knownBy
        end
        return "You", knownBy
    end

    return table.concat(altNames, ", "), knownBy
end

function R:GetRecipeQueuedQuantity(recipeID)
    local total = 0
    for _, entry in ipairs(M.Queue and M.Queue:GetAll() or {}) do
        if tonumber(entry.recipeID) == tonumber(recipeID) then
            total = total + (tonumber(entry.quantity) or 0)
        end
    end
    return total
end

function R:GetProducerRecipes(itemID, professionFilter)
    itemID = tonumber(itemID)
    if not itemID then
        return {}
    end

    local recipes = {}
    for recipeID, recipe in pairs(self:GetAll()) do
        if tonumber(recipe.itemID) == itemID and (not professionFilter or recipe.profession == professionFilter) then
            recipes[#recipes + 1] = {
                recipeID = recipeID,
                recipe = recipe,
                knownState = self:GetKnowledgeState(recipeID),
            }
        end
    end

    table.sort(recipes, function(a, b)
        local aCurrent = a.knownState == "CURRENT" and 1 or (a.knownState == "ALT" and 2 or 3)
        local bCurrent = b.knownState == "CURRENT" and 1 or (b.knownState == "ALT" and 2 or 3)
        if aCurrent ~= bCurrent then
            return aCurrent < bCurrent
        end
        local aSkill = (M.Alts and select(2, M.Alts:GetBestCrafterForRecipe(a.recipe))) or 0
        local bSkill = (M.Alts and select(2, M.Alts:GetBestCrafterForRecipe(b.recipe))) or 0
        if aSkill ~= bSkill then
            return aSkill > bSkill
        end
        return (a.recipe.name or tostring(a.recipeID)) < (b.recipe.name or tostring(b.recipeID))
    end)

    return recipes
end

function R:GetPrimaryProducerRecipe(itemID, professionFilter)
    local producers = self:GetProducerRecipes(itemID, professionFilter)
    return producers[1] and producers[1].recipe or nil
end
