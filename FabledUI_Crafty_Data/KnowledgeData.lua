-- FabledUI_Crafty_Data/KnowledgeData.lua
--
-- Slim namespace stub. The 31,714-line per-profession knowledge corpus that
-- used to live here was split into 11 sibling LoadOnDemand addons:
--
--   FabledUI_Crafty_Data_Alchemy        / Knowledge.lua
--   FabledUI_Crafty_Data_Blacksmithing  / Knowledge.lua
--   FabledUI_Crafty_Data_Enchanting     / Knowledge.lua
--   FabledUI_Crafty_Data_Engineering    / Knowledge.lua
--   FabledUI_Crafty_Data_Herbalism      / Knowledge.lua
--   FabledUI_Crafty_Data_Inscription    / Knowledge.lua
--   FabledUI_Crafty_Data_Jewelcrafting  / Knowledge.lua
--   FabledUI_Crafty_Data_Leatherworking / Knowledge.lua
--   FabledUI_Crafty_Data_Mining         / Knowledge.lua
--   FabledUI_Crafty_Data_Skinning       / Knowledge.lua
--   FabledUI_Crafty_Data_Tailoring      / Knowledge.lua
--
-- Each profession's slice is loaded on-demand via M:EnsureProfessionKnowledgeLoaded(prof)
-- (see FabledUI_Crafty/Core.lua) so a Skinner never pays the parse cost of
-- 4k lines of Tailoring data, etc.

local M = _G.FabledUI_Crafty
if not M then return end
M.KnowledgeData = M.KnowledgeData or {}

-- ============================================================================
-- Midnight knowledge treasures (P1-6) -- FRAMEWORK ONLY
-- Source: ProfessionKnowledgeTreasures/PKT_Data.lua:64-322 (~250 entries
-- across 11 Midnight gathering + crafting professions).
--
-- The bulk import is deferred to the offline pipeline. This block establishes
-- the schema and the mount point so Knowledge.lua can be written against it
-- without waiting on the full data drop.
--
-- Schema:
--   M.KnowledgeData.MidnightTreasures[skillLineID] = {
--       { name, mapID, x, y, questID, notes },
--       ...
--   }
--
-- Skill line IDs from PKT_Data (canonical, do not edit without re-checking
-- against the donor file):
--   2906 = Midnight Alchemy        2912 = Midnight Leatherworking
--   2907 = Midnight Blacksmithing  2913 = Midnight Tailoring
--   2909 = Midnight Enchanting     2914 = Midnight Herbalism
--   2910 = Midnight Engineering    2915 = Midnight Mining
--   2911 = Midnight Inscription    2916 = Midnight Skinning
--                                  2917 = Midnight Jewelcrafting
-- Zone shortcuts (from donor):
--   SC=2393 (Silvermoon)  EW=2395 (Eversong Woods)   ZA=2437 (Zul'Aman)
--   AT=2536 (Atal'aman)   HR=2413 (Har'athir)        VS=2405 (Voidstorm)
--   SR=2444 (Shenzar Refinery)
-- ============================================================================

M.KnowledgeData.MidnightTreasures = M.KnowledgeData.MidnightTreasures or {
    -- [2906] = { -- Midnight Alchemy
    --     { name = "Pristine Potion", mapID = 2393, x = 47.80, y = 51.60,
    --       questID = 89117,
    --       notes = "Roof of Silvermoon Alchemy & Enchants building - fly up." },
    --     ...
    -- },
    -- [2907] = { -- Midnight Blacksmithing
    --     ...
    -- },
}

M.KnowledgeData.MidnightTreasureZones = M.KnowledgeData.MidnightTreasureZones or {
    SilvermoonCity   = 2393,
    EversongWoods    = 2395,
    ZulAman          = 2437,
    AtalAman         = 2536,
    Harathir         = 2413,
    Voidstorm        = 2405,
    ShenzarRefinery  = 2444,
}
