-- FabledUI_Villa_Recipes -- which recipes make decor, whether you know them,
-- and where the rest are learned.
--
-- Three questions, each answered by the game first and an import second:
--
--   Does recipe R make decor?   GetRecipeOutputItemData(R).itemID ->
--                               C_Housing.GetDecorItemInfoFromItemID, then the
--                               static DecorIndex (itemID -> decorID), then
--                               Crafty's RecipeSources import (recipeID -> decorID).
--   Do I know it?               C_TradeSkillUI.GetRecipeInfo(R).learned
--   Where is it learned?        C_TradeSkillUI.GetRecipeSourceText(R) -- the
--                               same text Blizzard shows on an unlearned recipe
--                               in the profession window. Live, never stale.
--
-- The one thing only the import can do is go the other way, decorID -> recipeID,
-- which the tooltip needs when you hover a decor item rather than a recipe.
-- Crafty's RecipeSources shard (244 rows, HousingDecorGuide 2.2.0) supplies it
-- when FabledUI_Crafty_Data is installed; it is LoadOnDemand, loaded on first
-- ask.
--
-- Nothing here runs on a timer. Per-recipe answers are cached for the session;
-- a session cache is right for "makes decor" (fixed) and wrong for "learned"
-- (changes when you train), so only the first is cached.

local addonName = ...

local Recipes = {}
_G.FabledUI_VillaRecipes = Recipes

Recipes.VERSION = "0.1.0"
Recipes.ADDON_NAME = addonName or "FabledUI_Villa_Recipes"

local issecretvalue = _G.issecretvalue or function() return false end

local function usableNumber(value)
    if issecretvalue(value) then return nil end
    return tonumber(value)
end

local function usableString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

-- -----------------------------------------------------------------------------
-- API seam (tests replace these)
-- -----------------------------------------------------------------------------

Recipes.Api = {
    OutputItemID = function(recipeID)
        if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData) then return nil end
        local ok, info = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
        if ok and type(info) == "table" then return usableNumber(info.itemID) end
        return nil
    end,

    DecorIDForItem = function(itemID)
        if C_Housing and C_Housing.GetDecorItemInfoFromItemID then
            local ok, info = pcall(C_Housing.GetDecorItemInfoFromItemID, itemID)
            if ok and type(info) == "table" then
                local decorID = usableNumber(info.decorID)
                if decorID then return decorID end
            end
        end
        local providers = rawget(_G, "FabledUI_DataVault_VillaProviders")
        local index = type(providers) == "table" and providers["codex"] and providers["codex"].DecorIndex
        if type(index) == "table" and type(index.ItemToDecor) == "table" then
            return tonumber(index.ItemToDecor[itemID])
        end
        return nil
    end,

    -- learned (true/false/nil), name
    RecipeInfo = function(recipeID)
        if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then return nil end
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and type(info) == "table" then
            local learned
            if not issecretvalue(info.learned) then
                if info.learned == true then learned = true elseif info.learned == false then learned = false end
            end
            return learned, usableString(info.name)
        end
        return nil
    end,

    SourceText = function(recipeID)
        if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSourceText) then return nil end
        local ok, text = pcall(C_TradeSkillUI.GetRecipeSourceText, recipeID)
        if ok then return usableString(text) end
        return nil
    end,

    -- Crafty's import, loaded on demand. nil when Crafty is not installed.
    CraftyRecipeSources = function()
        local crafty = rawget(_G, "FabledUI_Crafty")
        if type(crafty) ~= "table" then return nil end
        local data = crafty.Data and crafty.Data.RecipeSources
        if type(data) ~= "table" and C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "FabledUI_Crafty_Data")
            data = crafty.Data and crafty.Data.RecipeSources
        end
        return type(data) == "table" and data or nil
    end,
}

-- -----------------------------------------------------------------------------
-- Makes decor?
-- -----------------------------------------------------------------------------

Recipes._decorByRecipe = {}   -- recipeID -> decorID | false
Recipes._recipeByDecor = nil  -- decorID -> recipeID, from the import

function Recipes:Reset()
    self._decorByRecipe = {}
    self._recipeByDecor = nil
end

function Recipes:_ImportedIndex()
    if self._recipeByDecor then return self._recipeByDecor end
    self._recipeByDecor = {}
    local sources = self.Api.CraftyRecipeSources()
    if type(sources) == "table" then
        for recipeID, record in pairs(sources) do
            if type(recipeID) == "number" and type(record) == "table" then
                local decorID = tonumber(record.decorID)
                if decorID then
                    self._recipeByDecor[decorID] = recipeID
                    if self._decorByRecipe[recipeID] == nil then self._decorByRecipe[recipeID] = decorID end
                end
            end
        end
    end
    return self._recipeByDecor
end

-- decorID or nil. Cached: what a recipe makes does not change mid-session.
function Recipes:DecorIDForRecipe(recipeID)
    recipeID = tonumber(recipeID)
    if not recipeID then return nil end
    local cached = self._decorByRecipe[recipeID]
    if cached ~= nil then return cached or nil end

    local decorID
    local itemID = self.Api.OutputItemID(recipeID)
    if itemID then decorID = self.Api.DecorIDForItem(itemID) end
    if not decorID then
        self:_ImportedIndex()
        decorID = self._decorByRecipe[recipeID] or nil
    end
    self._decorByRecipe[recipeID] = decorID or false
    return decorID
end

function Recipes:IsDecorRecipe(recipeID)
    return self:DecorIDForRecipe(recipeID) ~= nil
end

function Recipes:RecipeIDForDecor(decorID)
    decorID = tonumber(decorID)
    if not decorID then return nil end
    return self:_ImportedIndex()[decorID]
end

-- -----------------------------------------------------------------------------
-- Known? Where from?
-- -----------------------------------------------------------------------------

-- Returns { recipeID, name, learned = true/false/nil, source = text|nil }, or
-- nil when no recipe is known for this decor.
function Recipes:CraftInfoForDecor(decorID)
    local recipeID = self:RecipeIDForDecor(decorID)
    if not recipeID then return nil end
    local learned, name = self.Api.RecipeInfo(recipeID)
    local info = { recipeID = recipeID, name = name, learned = learned }
    if learned == false then
        info.source = self.Api.SourceText(recipeID)
    end
    return info
end
