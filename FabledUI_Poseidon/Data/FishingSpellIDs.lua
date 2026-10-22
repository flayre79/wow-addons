-- FabledUI_Poseidon/Data/FishingSpellIDs.lua
-- =====================================================================
-- P1-11 (May-04 audit): unified fishing-channel spell-ID lookup. Replaces
-- the 14-keyword channel-name regex previously used to detect fishing.
--
-- Sources synthesized from:
--   * BetterFishing/BetterFishing.lua FishingIDs (lines 36-51, 14 entries)
--   * Angleur/init.lua AngleurRetail_FishingSpellTable (lines 300-319,
--     19 entries) - the canonical retail list with Compressed Ocean,
--     Skumblade Spear, Hot-Spring Gulper, Disgusting Vat, Void Hole.
--
-- De-duplicated union. Any spellID present here means "the player is
-- channelling a fishing spell"; Modules/Events.lua keeps a textual
-- fallback for unknown / future spell IDs so older clients still work.
-- =====================================================================

local addonName, ns = ...
local P = _G.FabledUI_Poseidon
if not P then return end

P.Data = P.Data or {}

P.Data.FishingSpellIDs = {
    -- Classic / TBC / WotLK / Cata main fishing channels
    [7620]    = { label = "Fishing",                era = "Classic" },
    [7731]    = { label = "Fishing (TBC)",          era = "TBC" },
    [7732]    = { label = "Fishing (TBC alt)",      era = "TBC" },
    [18248]   = { label = "Fishing (Northrend)",    era = "WotLK" },
    [33095]   = { label = "Fishing (TBC alt 2)",    era = "TBC" },
    [51294]   = { label = "Fishing (Outland)",      era = "TBC" },
    [88868]   = { label = "Fishing (Cataclysm)",    era = "Cata" },

    -- MoP main + variant cast IDs
    [110410]  = { label = "Fishing (MoP)",          era = "MoP" },
    [131474]  = { label = "Fishing (MoP/Live)",     era = "MoP" },
    [131476]  = { label = "Fishing (Live cast)",    era = "MoP" },
    [131490]  = { label = "Fishing (MoP+ pole)",    era = "MoP" },
    [131491]  = { label = "Fishing (MoP variant)",  era = "MoP" },

    -- WoD / Legion / BfA / Shadowlands / DF
    [158743]  = { label = "Fishing (Draenor)",      era = "WoD" },

    -- Special-channel fishing (sub-types)
    [295727]  = { label = "Compressed Ocean Fishing", era = "BfA",     subtype = "compressed" },
    [139505]  = { label = "Skumblade Spear Fishing",  era = "MoP",     subtype = "spear" },
    [377895]  = { label = "Ice Fishing",              era = "DF",      subtype = "ice" },
    [405274]  = { label = "Disgusting Vat Fishing",   era = "DF",      subtype = "vat" },
    [301092]  = { label = "Hot-Spring Gulper Fishing", era = "BfA",    subtype = "hotspring" },
    [1252746] = { label = "[DNT] Fishing (Brain channel)", era = "TWW", subtype = "brain" },
    [1224771] = { label = "Void Fishing",             era = "Midnight", subtype = "void" },
    [392270]  = { label = "Looking for Lunkers",      era = "BfA",     subtype = "lunker" },

    -- DF placeholder per audit brief
    [393997]  = { label = "Fishing (Dragonflight)",   era = "DF" },
}

-- Boot-time fanout to a flat truthy lookup so the hot path in
-- Modules/Events.lua stays a single table read:
--     if P.FishingSpellIDs[spellID] then ... end
P.FishingSpellIDs = P.FishingSpellIDs or {}
for spellID, def in pairs(P.Data.FishingSpellIDs) do
    P.FishingSpellIDs[spellID] = def.label or true
end
