-- ============================================================================
-- FabledUI_Crafty - Data/Specializations (P1-7) -- FRAMEWORK ONLY
-- Source: CraftSim/Data/SpecializationData/Midnight/<Profession>.lua
--   Alchemy.lua, Blacksmithing.lua, Enchanting.lua, Engineering.lua,
--   Inscription.lua, Jewelcrafting.lua, Leatherworking.lua, Tailoring.lua
--
-- The full eight-profession spec tree (recipeMapping + perk/node trees)
-- is bulk imported in a separate sprint via the offline pipeline. This file
-- declares the schema and the mount point used by the simulation mode in
-- Specs.lua / Profit.lua so consumers can compile against a stable shape.
--
-- Schema:
--   M.Specializations[professionEnum] = {
--       [nodeID] = {
--           rank, maxRank,
--           edges = { childNodeID1, childNodeID2, ... },
--           modifiers = {                    -- effect bag, optional
--               { type, value, scope, ... },
--           },
--       },
--       ...
--   }
--   M.SpecializationsRecipeMapping[professionEnum] = {
--       [perkSpellID] = { recipeSpellID1, recipeSpellID2, ... },
--   }
--
-- professionEnum follows Enum.Profession.* (Alchemy=1, Blacksmithing=2, ...)
-- so Crafty's existing PROFESSION_ORDER continues to work unchanged.
-- ============================================================================

local M = _G.FabledUI_Crafty
if not M then return end

M.Specializations = M.Specializations or {
    -- [Enum.Profession.Alchemy]        = { -- nodes pending offline import },
    -- [Enum.Profession.Blacksmithing]  = { },
    -- [Enum.Profession.Enchanting]     = { },
    -- [Enum.Profession.Engineering]    = { },
    -- [Enum.Profession.Inscription]    = { },
    -- [Enum.Profession.Jewelcrafting]  = { },
    -- [Enum.Profession.Leatherworking] = { },
    -- [Enum.Profession.Tailoring]      = { },
}

M.SpecializationsRecipeMapping = M.SpecializationsRecipeMapping or {
    -- [Enum.Profession.Alchemy] = {
    --     [471040]  = { 107284, 107280, 107279, 107277, 107275 },
    --     [1230854] = { 107101, 107064, 107063, ... },
    --     ...
    -- },
}

-- Lookup helper: get the perk-spell entry that gates a recipe (returns the
-- perk spell ID if mapped). Used by Profit/Recipes when surfacing "this
-- recipe is unlocked by spec node X" hints. Safe no-op pre-import.
function M:GetSpecPerkForRecipe(professionEnum, recipeSpellID)
    local mapping = self.SpecializationsRecipeMapping and self.SpecializationsRecipeMapping[professionEnum]
    if type(mapping) ~= "table" then return nil end
    for perkSpellID, recipeIDs in pairs(mapping) do
        for _, rid in ipairs(recipeIDs) do
            if rid == recipeSpellID then
                return perkSpellID
            end
        end
    end
    return nil
end
