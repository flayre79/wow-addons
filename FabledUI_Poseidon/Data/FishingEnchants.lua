-- FabledUI_Poseidon/Data/FishingEnchants.lua
-- =====================================================================
-- P2-22 (May-04 audit): fishing-pole enchantment IDs. These are NOT aura
-- spell IDs (so they do not belong in FishingBuffs.lua); they are the
-- enchantmentID slot read from the item link string when a pole carries
-- a permanent fishing-skill enchant.
--
-- Source: FishingTracker-1.68/FishingTracker.lua lines 919-925
-- (function GetFishingPoleEnchantBonus, FISHING_ENCHANTS table).
--
-- Schema:
--   P.FishingEnchants[enchantID] = { bonus = N, label = "..." }
--
-- Use:
--   local _,_,_,_,_,_,_,_,_,_, enchantID = strsplit(":", itemLink)
--   local def = P.FishingEnchants[tonumber(enchantID)]
--   if def then totalBonus = totalBonus + def.bonus end
-- =====================================================================

local addonName, ns = ...
local P = _G.FabledUI_Poseidon
if not P then return end

P.FishingEnchants = {
    [5930] = { bonus = 6, label = "Undercurrent" },
    [5931] = { bonus = 5, label = "Angler" },
    [846]  = { bonus = 3, label = "Minor Fishing" },
    [849]  = { bonus = 2, label = "Lesser Fishing" },
    [851]  = { bonus = 1, label = "Fishing" },
}
