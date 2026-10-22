----------------------------------------------------------------------------------------------------
-- Add your special fish entries here
-- Format: [itemID] = true,
----------------------------------------------------------------------------------------------------
-- Default quality colors table (matches WoW's quality colors)
local FISH_QUALITY_COLORS = {
    [0]  = {r = 0.61, g = 0.61, b = 0.61, hex = "|cFF9C9C9C"}, -- Poor (gray)
    [1]  = {r = 1.00, g = 1.00, b = 1.00, hex = "|cFFFFFFFF"}, -- Common (white)
    [2]  = {r = 0.12, g = 1.00, b = 0.00, hex = "|cFF1EFF00"}, -- Uncommon (green)
    [3]  = {r = 0.00, g = 0.44, b = 0.87, hex = "|cFF0070FF"}, -- Rare (blue)
    [4]  = {r = 0.64, g = 0.21, b = 0.93, hex = "|cFFA335EE"}, -- Epic (purple)
    [5]  = {r = 1.00, g = 0.50, b = 0.00, hex = "|cFFFF8000"}, -- Legendary (orange)
    [6]  = {r = 0.90, g = 0.80, b = 0.50, hex = "|cFFE6CC80"}, -- Artifact (gold)
    [7]  = {r = 0.00, g = 0.80, b = 1.00, hex = "|cFF00CCFF"}, -- Heirloom (light blue)
    [8]  = {r = 0.00, g = 0.80, b = 1.00, hex = "|cFFFFFF00"}, -- RARE_FISH (yellow)
    [9]  = {r = 1.00, g = 0.90, b = 0.70, hex = "|cFFFDE8A8"}, -- SPECIAL_FISH (light yellow)
    [10] = {r = 1.00, g = 0.80, b = 0.80, hex = "|cFFFFC0CB"}, -- Quest Item (light pink)
}

local RARE_FISH_IDS = {
-- Classic
[19807] = true, -- Speckled Tastyfish (Stranglethorn Fishing Extravaganza)
[19902] = true, -- Swiftness Potion (from "Zulian Mudskunk," rare ZG fish)
[19807] = true, -- Speckled Tastyfish
[19806] = true, -- Dezian Queenfish
[19805] = true, -- Keefer's Angelfish
[19804] = true, -- Pale Ghoulfish
[19803] = true, -- Brownell's Blue Striped Racer

-- Cataclysm
[53080] = true, -- Murglesnout (Twilight Highlands, unique catch)

-- Mists of Pandaria
[86546] = true, -- Ancient Pandaren Fishing Charm (from rare Pandaria fish)

-- Legion
[133732] = true, -- Oodelfjisk (Stormheim, rare for feasts)
[133731] = true, -- Ancient Highmountain Salmon (Highmountain, rare)

-- Battle for Azeroth
[152553] = true, -- Ionized Minnow (Mechagon, rare)
[152557] = true, -- Deadeye Wally (Stormsong Valley, unique for achievement)
[152560] = true, -- Shadowfin, Heart of the Swarm (Nazjatar, rare)
[152571] = true, -- Ancient Black Barracuda (Nazjatar, rare)

-- Hourly Rare Fish
[13759] = true, -- Raw Nightfin Snapper
[13760] = true, -- Raw Sunscale Salmon

-- Weekly Rare Fish
[13756] = true, -- Raw Summer Bass
[13755] = true, -- Winter Squid
}

----------------------------------------------------------------------------------------------------
local SPECIAL_FISH_IDS = {
-- Classic
[6292] = true, -- 10 Pound Mud Snapper
[6294] = true, -- 12 Pound Mud Snapper
[6295] = true, -- 15 Pound Mud Snapper
[6309] = true, -- 17 Pound Catfish
[6310] = true, -- 19 Pound Catfish
[6311] = true, -- 22 Pound Catfish
[6360] = true, -- Steelscale Crushfish
[6363] = true, -- 26 Pound Catfish
[6364] = true, -- 32 Pound Catfish
[13883] = true, -- 45 Pound Redgill
[13884] = true, -- 49 Pound Redgill
[13885] = true, -- 34 Pound Redgill
[13886] = true, -- 37 Pound Redgill
[13887] = true, -- 52 Pound Redgill
[13901] = true, -- 15 Pound Salmon
[13902] = true, -- 18 Pound Salmon
[13903] = true, -- 22 Pound Salmon
[13904] = true, -- 25 Pound Salmon
[13905] = true, -- 29 Pound Salmon
[13906] = true, -- 32 Pound Salmon
[13907] = true, -- 7 Pound Lobster
[13908] = true, -- 9 Pound Lobster
[13909] = true, -- 12 Pound Lobster
[13910] = true, -- 15 Pound Lobster
[13911] = true, -- 19 Pound Lobster
[13912] = true, -- 21 Pound Lobster
[13913] = true, -- 22 Pound Lobster
[13914] = true, -- 70 Pound Mightfish
[13915] = true, -- 85 Pound Mightfish
[13916] = true, -- 92 Pound Mightfish
[13917] = true, -- 103 Pound Mightfish
[16967] = true, -- Feralas Ahi
[19808] = true, -- Rockhide Strongfish
[27515] = true, -- Huge Spotted Feltail
[27516] = true, -- Enormous Barbed Gill Trout
[34484] = true, -- Old Ironjaw
[34486] = true, -- Old Crafty
[44703] = true, -- Dark Herring
}

----------------------------------------------------------------------------------------------------
local JUNK_ITEMS_IDS = {
-- Khaz Algar
[228387] = true, -- Crumbling Bismuth
[228391] = true, -- Right Boot
[228396] = true, -- Dead Fish
[228386] = true, -- Decaying Rope
[228430] = true, -- Mucky Rock
[228399] = true, -- Sad Rock
}

local NOT_JUNK_ITEMS_IDS = {
-- Classic
[6307] = true, -- Message in a Bottle
[6353] = true, -- Small Chest
[20708] = true, -- Tightly Sealed Trunk
[21113] = true, -- Watertight Trunk
[21150] = true, -- Iron Bound Trunk
[21228] = true, -- Mithril Bound Trunk

-- Darkmoon Faire / Darkmoon Island / Darkmoon Boardwalk
[124670] = true, -- Sealed Darkmoon Crate
[127141] = true, -- Bloated Thresher
[164972] = true, -- Severed Crimsonscale Head
[164973] = true, -- Severed Azurefin Head

-- Warlords of Draenor
[116158] = true, -- Lunarfall Carp (Use: Throw this fish into the Garrison fishing pond to summon a Cavedweller.)
}

FT_QualityColorsIDs = FISH_QUALITY_COLORS
FT_RareFishIDs = RARE_FISH_IDS
FT_SpecialFishIDs = SPECIAL_FISH_IDS
FT_JunkItemsIDs = JUNK_ITEMS_IDS
FT_NotJunkItemsIDs = NOT_JUNK_ITEMS_IDS
