-- FabledUI_Poseidon/Data/FishingBuffs.lua
-- =====================================================================
-- P0 (May-04 audit): aura-spellID dataset that powers the BuffTracker.
-- Sources synthesized in .audit-2026-05-04/Group4_Fishing.md (P0-1):
--   * FishingTracker_BuffData.lua (FT_FishingToys/Skill/PerceptionBuffIDs)
--   * Angleur items/items_mists.lua (consumable bait possibilities)
--   * Angleur toys/toys_base.lua (raft + bobber + crate-bobber toys)
--   * MidnightLureTracker_Data.lua (Midnight skinning lure auras, kept
--     here so a player running them while fishing still sees them)
--
-- Schema:
--   P.Data.FishingBuffs[spellID] = {
--       source = "lure" | "toy" | "bobber" | "raft" | "consumable"
--                | "perception" | "midnight_lure" | "session",
--       label  = display name (string),
--       bonus  = optional integer fishing-skill / perception bonus,
--       duration = optional aura duration (seconds),
--       item = optional itemID for cross-reference,
--       effect = optional descriptor for non-skill effects,
--   }
--
-- BuffTracker.lua:91 only checks truthiness, so the boot-time merge at
-- the end of this file populates P.FishingBuffSpells[spellID] = label
-- (string) so LabelFor() can render the friendly name without a live
-- C_Spell.GetSpellName lookup for the common case.
-- =====================================================================

local addonName, ns = ...
local P = _G.FabledUI_Poseidon
if not P then return end

P.Data = P.Data or {}

P.Data.FishingBuffs = {
    -- ----- CONSUMABLE LURES (Angleur baitPossibilities + classic) -----
    -- These ARE auras - applied to the pole, give +N fishing skill for 10m.
    -- spellID is the *aura* spellID, NOT the itemID. (item = itemID for ref.)
    [6529]   = { source = "lure", item = 6529,   label = "Shiny Bauble",                bonus = 25,  duration = 600 },
    [6530]   = { source = "lure", item = 6530,   label = "Nightcrawlers",               bonus = 50,  duration = 600 },
    [6532]   = { source = "lure", item = 6532,   label = "Bright Baubles",              bonus = 75,  duration = 600 },
    [6533]   = { source = "lure", item = 6533,   label = "Aquadynamic Fish Attractor",  bonus = 100, duration = 600 },
    [7307]   = { source = "lure", item = 7307,   label = "Flesh Eating Worm",           bonus = 75,  duration = 600 },
    [34861]  = { source = "lure", item = 34861,  label = "Sharpened Fish Hook",         bonus = 100, duration = 600 },
    [46006]  = { source = "lure", item = 46006,  label = "Glow Worm",                   bonus = 100, duration = 600 },
    [62673]  = { source = "lure", item = 62673,  label = "Feathered Lure",              bonus = 100, duration = 600 },
    [68049]  = { source = "lure", item = 68049,  label = "Heat-Treated Spinning Lure",  bonus = 150, duration = 900 },

    -- ----- TOY BUFFS (FT_FishingToysBuffIDs from FishingTracker) -----
    [251216] = { source = "toy",  label = "Trawler Totem",                  bonus = 4, duration = 120 },
    [125167] = { source = "toy",  label = "Ancient Pandaren Fishing Charm", bonus = 0, duration = 3600,
                 effect = "additional_fish_pandaria" },

    -- ----- BOBBER TOYS (Angleur crateBobberPossibilities) -----
    -- These are visual toys, no skill bonus, but the BuffTracker should still
    -- recognize them so "Buff: Squeaky Duck" doesn't render as a junk fallback.
    [231291] = { source = "bobber", label = "Crate of Bobbers: Can of Worms" },
    [231319] = { source = "bobber", label = "Crate of Bobbers: Cat Head" },
    [231349] = { source = "bobber", label = "Crate of Bobbers: Murloc Head" },
    [231338] = { source = "bobber", label = "Crate of Bobbers: Tugboat" },
    [231341] = { source = "bobber", label = "Crate of Bobbers: Squeaky Duck" },
    [232613] = { source = "bobber", label = "Crate of Bobbers: Wooden Pepe" },
    [240800] = { source = "bobber", label = "Crate of Bobbers: Enchanted Bobber" },
    [240801] = { source = "bobber", label = "Crate of Bobbers: Demon Noggin" },
    [240802] = { source = "bobber", label = "Crate of Bobbers: Floating Totem" },
    [240803] = { source = "bobber", label = "Crate of Bobbers: Carved Wooden Helm" },
    [240804] = { source = "bobber", label = "Crate of Bobbers: Replica Gondola" },
    [240806] = { source = "bobber", label = "Crate of Bobbers: Face of the Forest" },
    [335484] = { source = "bobber", label = "Bat Visage Bobber" },
    [397827] = { source = "bobber", label = "Reusable Oversized Bobber",  bonus = 0, duration = 60 },
    [1222880] = { source = "bobber", label = "Limited Edition Rocket Bobber" },
    [1222884] = { source = "bobber", label = "Artisan Beverage Goblet Bobber" },
    [1222888] = { source = "bobber", label = "Organically-Sourced Wellington Bobber" },

    -- ----- RAFT TOYS (Angleur raftPossibilities) -----
    [124036]  = { source = "raft",   label = "Anglers Fishing Raft", duration = 600 },
    [288758]  = { source = "raft",   label = "Gnarlwood Waveboard" },
    [383268]  = { source = "raft",   label = "Tuskarr Dinghy" },
    [1218420] = { source = "raft",   label = "Personal Fishing Barge" },

    -- ----- SKILL BUFFS (FT_FishingSkillBuffIDs) -----
    [128357] = { source = "consumable", label = "Sharpened Tuskarr Spear", bonus = 5,  duration = 600 },
    [456156] = { source = "consumable", label = "Chum",                    bonus = 10, duration = 30  },

    -- ----- PERCEPTION BUFFS (FT_FishingPerceptionBuffIDs) -----
    [456586] = { source = "perception", label = "Algari Perception",   bonus = 45, duration = 30 },
    [456596] = { source = "perception", label = "Goldengill Blessing", bonus = 45, duration = 30 },

    -- ----- MIDNIGHT (auraIDs from MidnightLureTracker_Data) -----
    -- The MLT addon tracks these as skinning lures. For fishing we keep them
    -- so Poseidon can show "Buff: Eversong Lure (4:32)" if the player happens
    -- to have one running while fishing - they are PLAYER auras either way.
    [1239058] = { source = "midnight_lure", label = "Eversong Ghostclaw Lure" },
    [1239120] = { source = "midnight_lure", label = "Zul'Aman Silverscale Lure" },
    [1239121] = { source = "midnight_lure", label = "Harandar Lumenfin Lure" },
    [1239122] = { source = "midnight_lure", label = "Voidstorm Umbrafang Lure" },
    [1239151] = { source = "midnight_lure", label = "Grand Beast Netherscythe Lure" },

    -- ----- ATTENTION / ERA BUFFS -----
    [394009]  = { source = "session", label = "Fishing for Attention", bonus = 0, duration = nil,
                  effect = "afk_marker" },
    [1214848] = { source = "session", label = "Winds of Mysterious Fortune", bonus = 0,
                  effect = "midnight_random_buff" },
}

-- Boot-time merge into the placeholder declared by Core.lua. This mirrors
-- the pattern used for P.Data.RareFish -> P.RareFishIDs.
P.FishingBuffSpells = P.FishingBuffSpells or {}
for spellID, def in pairs(P.Data.FishingBuffs) do
    -- BuffTracker.lua:91 only checks truthiness, so we keep that contract.
    -- LabelFor() at BuffTracker.lua:46-50 prefers a string override; pass
    -- the friendly label so the HUD shows readable text without a live
    -- C_Spell.GetSpellName lookup for the hot path.
    P.FishingBuffSpells[spellID] = def.label or true
end
