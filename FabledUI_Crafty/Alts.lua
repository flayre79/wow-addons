local M = _G.FabledUI_Crafty
M.Alts = M.Alts or {}
local A = M.Alts

local expansionSkillLines = {
    [2823] = "TWW",
    [2824] = "TWW",
    [2827] = "TWW",
    [2871] = "Midnight",
    [2872] = "Midnight",
    [2873] = "Midnight",
    [2874] = "Midnight",
}

local function EnsureAltStorage()
    if M.EnsureStorageTables then
        M:EnsureStorageTables()
    end
    M.db.alts = type(M.db.alts) == "table" and M.db.alts or {}
    return M.db.alts
end

local function GetOpenProfessionContext()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetTradeSkillLine then
        return nil
    end

    local skillLineID, skillLineDisplayName, skillLineRank, skillLineMaxRank, _, parentSkillLineID, parentSkillLineDisplayName = C_TradeSkillUI.GetTradeSkillLine()
    if not skillLineID then
        return nil
    end

    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID) or nil
    local professionName = (info and info.professionName) or parentSkillLineDisplayName or skillLineDisplayName
    local professionID = (info and info.professionID) or parentSkillLineID or skillLineID
    local skillLevel = (info and info.skillLevel) or skillLineRank or 0
    local maxSkillLevel = (info and info.maxSkillLevel) or skillLineMaxRank or 0
    local expansionName = expansionSkillLines[skillLineID] or ((info and info.expansionName and info.expansionName ~= "Unknown") and info.expansionName or nil) or "Unknown"

    return {
        tradeSkillLineID = skillLineID,
        parentTradeSkillLineID = parentSkillLineID,
        professionName = professionName,
        professionID = professionID,
        skillLevel = skillLevel,
        maxSkillLevel = maxSkillLevel,
        expansion = expansionName,
    }
end

local function BuildSpellToRecipeMap()
    local map = {}
    for recipeID, recipe in pairs(M.RecipeDB or {}) do
        if recipe and recipe.spellID then
            map[recipe.spellID] = tonumber(recipeID)
        end
    end
    return map
end

-- Collect recipe IDs the open profession exposes. We try a sequence of API calls
-- because each WoW build gives different coverage:
--   1. GetCategories()/GetRecipesForCategory() — enumerates every category.
--   2. GetFilteredRecipeIDs(true) — known + favorite recipes (newer API).
--   3. GetAllRecipeIDs() — every recipe Blizzard knows about for the open line.
local function CollectOpenProfessionRecipeIDs(context)
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

-- Read per-recipe live data and stamp characters that know each recipe.
-- IMPORTANT: only `recipeInfo.learned` is per-recipe truth.
-- `C_TradeSkillUI.IsRecipeProfessionLearned` only tells whether the *profession*
-- is learned, so it cannot be used to decide whether a character knows a recipe.
local function GetKnownRecipesForOpenProfession(context)
    local known = {}
    if not context or not C_TradeSkillUI or type(C_TradeSkillUI.GetRecipeInfo) ~= "function" then
        return known
    end

    local spellToRecipe = BuildSpellToRecipeMap()
    local ids = CollectOpenProfessionRecipeIDs(context)

    for _, recipeID in ipairs(ids) do
        local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if okInfo and type(info) == "table" and info.learned then
            known[recipeID] = {
                learned = true,
                name = info.name,
                categoryID = info.categoryID,
                skillLineAbilityID = info.skillLineAbilityID,
                craftable = info.craftable and true or false,
                tradeSkillLineID = context.tradeSkillLineID,
                professionID = context.professionID,
                professionName = context.professionName,
                lastSeen = time(),
            }
            if info.skillLineAbilityID then
                local mappedID = spellToRecipe[info.skillLineAbilityID]
                if mappedID and not known[mappedID] then
                    -- Mirror onto the static-record id so static-keyed lookups also resolve.
                    known[mappedID] = known[recipeID]
                end
            end
        end
    end

    return known
end

function A:RegisterCurrentCharacter()
    local alts = EnsureAltStorage()
    local charKey = M:GetCurrentCharacterKey()
    alts[charKey] = alts[charKey] or {
        name = UnitName("player"),
        realm = GetRealmName(),
        class = select(2, UnitClass("player")),
        level = UnitLevel("player"),
        recipes = {},
        professions = {},
        concentration = {},
        lastSeen = 0,
    }
    local entry = alts[charKey]
    entry.name = UnitName("player")
    entry.realm = GetRealmName()
    entry.class = select(2, UnitClass("player"))
    entry.level = UnitLevel("player")
    entry.lastSeen = time()
    entry.recipes = type(entry.recipes) == "table" and entry.recipes or {}
    entry.professions = type(entry.professions) == "table" and entry.professions or {}
    entry.concentration = type(entry.concentration) == "table" and entry.concentration or {}
    return charKey, entry
end

function A:GetCharacterData(characterKey)
    local alts = EnsureAltStorage()
    return alts[characterKey]
end

function A:GetAllCharacters()
    local alts = EnsureAltStorage()
    local keys = {}
    for key in pairs(alts) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function A:ScanCurrentCharacterProfessions(markDirty)
    local charKey, entry = self:RegisterCurrentCharacter()

    local context = GetOpenProfessionContext()
    if context and context.professionName then
        entry.professions[context.professionName] = entry.professions[context.professionName] or {}
        local p = entry.professions[context.professionName]
        p.professionID = context.professionID
        p.tradeSkillLineID = context.tradeSkillLineID
        p.parentTradeSkillLineID = context.parentTradeSkillLineID
        p.expansion = context.expansion
        p.skillLevel = context.skillLevel or p.skillLevel or 0
        p.maxSkillLevel = context.maxSkillLevel or p.maxSkillLevel or 0
        p.lastScanned = time()

        local scanned = GetKnownRecipesForOpenProfession(context)
        local stored = 0
        for recipeID, record in pairs(scanned) do
            -- Persist a rich record so we can resolve learned state without
            -- needing the trade-skill window open. Keep a `true` shape compatible
            -- with older callers that did `if recipes[recipeID] then`.
            local existing = entry.recipes[recipeID]
            if type(existing) ~= "table" then
                existing = {}
            end
            for k, v in pairs(record) do
                existing[k] = v
            end
            entry.recipes[recipeID] = existing
            stored = stored + 1
        end
        p.recipeCount = stored
    end

    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    for _, profIndex in ipairs({ prof1, prof2, cooking, fishing, archaeology }) do
        if profIndex then
            local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(profIndex)
            if name then
                entry.professions[name] = entry.professions[name] or {}
                local p = entry.professions[name]
                p.professionID = skillLine
                p.skillLevel = rank or 0
                p.maxSkillLevel = maxRank or 0
                p.expansion = p.expansion or "Account"
                p.lastScanned = time()
            end
        end
    end

    if M.Concentration and M.Concentration.CaptureOpenProfession then
        M.Concentration:CaptureOpenProfession(false)
    end
    if M.Gear and M.Gear.ScanOpenProfessionGear then
        M.Gear:ScanOpenProfessionGear(false)
    end
    if M.Specs and M.Specs.CaptureOpenProfession then
        M.Specs:CaptureOpenProfession(false)
    end
    if M.Cooldowns and M.Cooldowns.ScanOpenProfession then
        M.Cooldowns:ScanOpenProfession(false)
    end

    if markDirty then
        M:MarkDirty()
        M:Fire("AltDataChanged")
        -- Also notify generic data listeners — the Recipes tab subscribes to
        -- DataChanged, and the recipe-known state changes when this scan runs.
        M:Fire("DataChanged")
    end

    return charKey
end

function A:GetConcentrationSummary(characterKey)
    local data = self:GetCharacterData(characterKey) or {}
    local concentration = data.concentration or {}
    local bestProfession, bestCurrent, bestMax = nil, -1, 0
    for professionName, professionData in pairs(concentration) do
        local current = M.Concentration and M.Concentration.GetEstimatedCurrent and M.Concentration:GetEstimatedCurrent(professionData) or 0
        if current > bestCurrent then
            bestProfession = professionName
            bestCurrent = current
            bestMax = tonumber(professionData.maxQuantity) or 0
        end
    end
    if not bestProfession then
        return "No concentration", 0, 0
    end
    return string.format("%s %d/%d", bestProfession, math.floor(bestCurrent), bestMax), bestCurrent, bestMax
end

local function recipeKnownEntry(charData, recipeID)
    if not charData or type(charData.recipes) ~= "table" then
        return nil
    end
    local entry = charData.recipes[recipeID] or charData.recipes[tonumber(recipeID)] or charData.recipes[tostring(recipeID)]
    if entry == nil or entry == false then
        return nil
    end
    if type(entry) == "table" then
        if entry.learned == false then
            return nil
        end
        return entry
    end
    -- Legacy boolean storage shape.
    return entry
end

function A:IsRecipeKnownByCharacter(recipeID, characterKey)
    local alts = EnsureAltStorage()
    local char = alts[characterKey]
    return recipeKnownEntry(char, recipeID) ~= nil
end

function A:GetKnownBy(recipeID)
    local alts = EnsureAltStorage()
    local knownBy = {}
    for characterKey, charData in pairs(alts) do
        if recipeKnownEntry(charData, recipeID) ~= nil then
            knownBy[#knownBy + 1] = characterKey
        end
    end
    table.sort(knownBy)
    return knownBy
end

function A:GetRecipeRecord(recipeID, characterKey)
    local alts = EnsureAltStorage()
    local char = alts[characterKey]
    local entry = recipeKnownEntry(char, recipeID)
    return type(entry) == "table" and entry or nil
end

function A:GetBestCrafterForRecipe(recipe)
    local alts = EnsureAltStorage()
    if not recipe then
        return nil
    end

    local bestCharacter, bestSkill = nil, -1
    for characterKey, charData in pairs(alts) do
        local professionData = charData.professions and charData.professions[recipe.profession]
        if professionData and recipeKnownEntry(charData, recipe.recipeID) ~= nil then
            local skill = professionData.skillLevel or 0
            if skill > bestSkill then
                bestSkill = skill
                bestCharacter = characterKey
            end
        end
    end

    return bestCharacter, bestSkill
end




function A:GetGearSummary(characterKey, professionName)
    local totals = M.Gear and M.Gear:GetTotals(characterKey, professionName) or nil
    return totals and M.Gear:DescribeTotals(totals) or nil
end

function A:GetSpecSummary(characterKey, professionName)
    local snapshot = M.Specs and M.Specs:GetSnapshot(characterKey, professionName) or nil
    return snapshot and M.Specs:GetSummaryText(snapshot) or nil
end
