local M = _G.FabledUI_Crafty

local sampleRecipes = {
    [56269] = {
        recipeID = 56269,
        name = "Apothecary's Worktable",
        spellID = 1262829,
        itemID = 257100,
        decorID = 11438,
        profession = "Alchemy",
        expansion = "Classic",
        category = "Furniture",
        style = "Apothecary",
        size = "Large",
        collected = false,
        materials = {
            { itemID = 245586, name = "Ironwood Lumber", qty = 40, source = "Raw" },
            { itemID = 12808, name = "Essence of Undeath", qty = 16, source = "Raw" },
            { itemID = 12360, name = "Arcanite Bar", qty = 12, source = "Crafted", profession = "Alchemy" },
            { itemID = 13468, name = "Black Lotus", qty = 8, source = "Raw" },
            { itemID = 3371, name = "Crystal Vial", qty = 6, source = "Vendor" },
        },
    },
    [56118] = {
        recipeID = 56118,
        name = "Stoppered Black Potion",
        spellID = 1261495,
        itemID = 257041,
        decorID = 11376,
        profession = "Alchemy",
        expansion = "Classic",
        category = "Decor",
        style = "Potion",
        size = "Small",
        collected = true,
        materials = {
            { itemID = 245586, name = "Ironwood Lumber", qty = 10, source = "Raw" },
            { itemID = 20520, name = "Dark Rune", qty = 2, source = "Raw" },
            { itemID = 2325, name = "Black Dye", qty = 2, source = "Vendor" },
            { itemID = 3371, name = "Crystal Vial", qty = 1, source = "Vendor" },
        },
    },
    [57002] = {
        recipeID = 57002,
        name = "Glazed Sin'dorei Vial",
        spellID = 1272712,
        itemID = 264705,
        decorID = 16082,
        profession = "Alchemy",
        expansion = "TBC",
        category = "Decor",
        style = "Sin'dorei",
        size = "Small",
        collected = false,
        materials = {
            { itemID = 242691, name = "Olemba Lumber", qty = 6, source = "Raw" },
            { itemID = 34440, name = "Mad Alchemist's Potion", qty = 5, source = "Crafted", profession = "Alchemy" },
            { itemID = 23449, name = "Khorium Bar", qty = 4, source = "Raw" },
            { itemID = 3371, name = "Crystal Vial", qty = 1, source = "Vendor" },
        },
    },
    [56368] = {
        recipeID = 56368,
        name = "Icecrown Plague Canister",
        spellID = 1263559,
        itemID = 258213,
        decorID = 11901,
        profession = "Alchemy",
        expansion = "WotLK",
        category = "Decor",
        style = "Scourge",
        size = "Medium",
        collected = false,
        materials = {
            { itemID = 251762, name = "Coldwind Lumber", qty = 40, source = "Raw" },
            { itemID = 40077, name = "Crazy Alchemist's Potion", qty = 5, source = "Crafted", profession = "Alchemy" },
            { itemID = 33447, name = "Runic Healing Potion", qty = 10, source = "Crafted", profession = "Alchemy" },
            { itemID = 36908, name = "Frost Lotus", qty = 5, source = "Raw" },
            { itemID = 35625, name = "Eternal Life", qty = 2, source = "Raw" },
            { itemID = 43102, name = "Frozen Orb", qty = 1, source = "Raw" },
        },
    },
    [56070] = {
        recipeID = 56070,
        name = "Gilnean Cauldron",
        spellID = 1261255,
        itemID = 245517,
        decorID = 855,
        profession = "Alchemy",
        expansion = "Cataclysm",
        category = "Furniture",
        style = "Gilnean",
        size = "Large",
        collected = false,
        materials = {
            { itemID = 251764, name = "Ashwood Lumber", qty = 30, source = "Raw" },
            { itemID = 54849, name = "Obsidium Bar", qty = 16, source = "Raw" },
            { itemID = 52326, name = "Volatile Water", qty = 40, source = "Raw" },
            { itemID = 56850, name = "Deepstone Oil", qty = 6, source = "Crafted", profession = "Alchemy" },
            { itemID = 69237, name = "Living Ember", qty = 1, source = "Raw" },
        },
    },
    [60110] = {
        recipeID = 60110,
        name = "Surveyor's Lamp Post",
        spellID = 1280011,
        itemID = 275110,
        decorID = 18801,
        profession = "Engineering",
        expansion = "TWW",
        category = "Lighting",
        style = "Explorer",
        size = "Medium",
        collected = false,
        materials = {
            { itemID = 246000, name = "Khaz Algar Lumber", qty = 16, source = "Raw" },
            { itemID = 210796, name = "Bismuth", qty = 12, source = "Raw" },
            { itemID = 228231, name = "Stormcharged Gear", qty = 4, source = "Crafted", profession = "Engineering" },
        },
    },
    [60111] = {
        recipeID = 60111,
        name = "Nightfall Loom Divider",
        spellID = 1280012,
        itemID = 275111,
        decorID = 18802,
        profession = "Tailoring",
        expansion = "Midnight",
        category = "Divider",
        style = "Elven",
        size = "Large",
        collected = false,
        materials = {
            { itemID = 246100, name = "Duskwoven Cloth", qty = 22, source = "Raw" },
            { itemID = 246101, name = "Starthread Spool", qty = 10, source = "Crafted", profession = "Tailoring" },
            { itemID = 245586, name = "Ironwood Lumber", qty = 14, source = "Raw" },
        },
    },
    [60112] = {
        recipeID = 60112,
        name = "Gemwright's Study Shelf",
        spellID = 1280013,
        itemID = 275112,
        decorID = 18803,
        profession = "Jewelcrafting",
        expansion = "Dragonflight",
        category = "Storage",
        style = "Arcane",
        size = "Large",
        collected = true,
        materials = {
            { itemID = 194123, name = "Fractured Glass", qty = 8, source = "Raw" },
            { itemID = 194545, name = "Dragon Isles Diamond", qty = 4, source = "Raw" },
            { itemID = 245586, name = "Ironwood Lumber", qty = 20, source = "Raw" },
        },
    },
}

local trainers = {
    -- ============================================================
    -- THE WAR WITHIN (TWW) — Dornogal (mapID 2339)
    -- ============================================================
    { id = 1001, name = "Auralia Flaskbinder",    profession = "Alchemy",        expansion = "TWW",          mapID = 2339, x = 0.47, y = 0.44, faction = "Neutral", zone = "Dornogal" },
    { id = 1002, name = "Branik Gearloom",         profession = "Engineering",    expansion = "TWW",          mapID = 2339, x = 0.54, y = 0.37, faction = "Neutral", zone = "Dornogal" },
    { id = 1005, name = "Durrak Stonecarver",      profession = "Blacksmithing",  expansion = "TWW",          mapID = 2339, x = 0.51, y = 0.48, faction = "Neutral", zone = "Dornogal" },
    { id = 1006, name = "Silviana Moonweave",      profession = "Tailoring",      expansion = "TWW",          mapID = 2339, x = 0.50, y = 0.56, faction = "Neutral", zone = "Dornogal" },
    { id = 1007, name = "Kalos Embertrace",        profession = "Enchanting",     expansion = "TWW",          mapID = 2339, x = 0.49, y = 0.50, faction = "Neutral", zone = "Dornogal" },
    { id = 1008, name = "Mira Gemcutter",          profession = "Jewelcrafting",  expansion = "TWW",          mapID = 2339, x = 0.52, y = 0.45, faction = "Neutral", zone = "Dornogal" },
    { id = 1009, name = "Ferryn Patchwork",        profession = "Leatherworking", expansion = "TWW",          mapID = 2339, x = 0.48, y = 0.54, faction = "Neutral", zone = "Dornogal" },
    { id = 1010, name = "Thalia Inkwright",        profession = "Inscription",    expansion = "TWW",          mapID = 2339, x = 0.46, y = 0.52, faction = "Neutral", zone = "Dornogal" },
    { id = 1011, name = "Grenda Ironpan",          profession = "Cooking",        expansion = "TWW",          mapID = 2339, x = 0.45, y = 0.48, faction = "Neutral", zone = "Dornogal" },
    -- ============================================================
    -- MIDNIGHT — Lunastre (mapID 2462)
    -- ============================================================
    { id = 1003, name = "Talya Threadmoon",        profession = "Tailoring",      expansion = "Midnight",     mapID = 2462, x = 0.41, y = 0.55, faction = "Neutral", zone = "Lunastre" },
    { id = 1012, name = "Verenath Distillum",      profession = "Alchemy",        expansion = "Midnight",     mapID = 2462, x = 0.44, y = 0.51, faction = "Neutral", zone = "Lunastre" },
    { id = 1013, name = "Kael'dan Forgepeak",      profession = "Blacksmithing",  expansion = "Midnight",     mapID = 2462, x = 0.47, y = 0.49, faction = "Neutral", zone = "Lunastre" },
    { id = 1014, name = "Solenne Sparkwright",     profession = "Engineering",    expansion = "Midnight",     mapID = 2462, x = 0.50, y = 0.53, faction = "Neutral", zone = "Lunastre" },
    { id = 1015, name = "Auren Glyphbind",         profession = "Inscription",    expansion = "Midnight",     mapID = 2462, x = 0.43, y = 0.58, faction = "Neutral", zone = "Lunastre" },
    { id = 1016, name = "Elarys Gemspire",         profession = "Jewelcrafting",  expansion = "Midnight",     mapID = 2462, x = 0.46, y = 0.56, faction = "Neutral", zone = "Lunastre" },
    { id = 1017, name = "Tharielle Surebind",      profession = "Leatherworking", expansion = "Midnight",     mapID = 2462, x = 0.49, y = 0.60, faction = "Neutral", zone = "Lunastre" },
    { id = 1018, name = "Sylvenar Runeweave",      profession = "Enchanting",     expansion = "Midnight",     mapID = 2462, x = 0.52, y = 0.57, faction = "Neutral", zone = "Lunastre" },
    -- ============================================================
    -- DRAGONFLIGHT — Valdrakken (mapID 2025)
    -- ============================================================
    { id = 1004, name = "Rhemi Gemfuse",           profession = "Jewelcrafting",  expansion = "Dragonflight", mapID = 2025, x = 0.45, y = 0.80, faction = "Neutral", zone = "Valdrakken" },
    { id = 1019, name = "Lydiara Whisperfeather",  profession = "Alchemy",        expansion = "Dragonflight", mapID = 2025, x = 0.48, y = 0.53, faction = "Neutral", zone = "Valdrakken" },
    { id = 1020, name = "Zareth Stonefall",        profession = "Blacksmithing",  expansion = "Dragonflight", mapID = 2025, x = 0.50, y = 0.58, faction = "Neutral", zone = "Valdrakken" },
    { id = 1021, name = "Frizz Buzzcrank",         profession = "Engineering",    expansion = "Dragonflight", mapID = 2025, x = 0.54, y = 0.55, faction = "Neutral", zone = "Valdrakken" },
    { id = 1022, name = "Glyros the Inscribed",    profession = "Inscription",    expansion = "Dragonflight", mapID = 2025, x = 0.46, y = 0.57, faction = "Neutral", zone = "Valdrakken" },
    { id = 1023, name = "Khadin",                  profession = "Leatherworking", expansion = "Dragonflight", mapID = 2025, x = 0.44, y = 0.61, faction = "Neutral", zone = "Valdrakken" },
    { id = 1024, name = "Sif Galeweave",           profession = "Tailoring",      expansion = "Dragonflight", mapID = 2025, x = 0.52, y = 0.62, faction = "Neutral", zone = "Valdrakken" },
    { id = 1025, name = "Ravel Earthvine",         profession = "Enchanting",     expansion = "Dragonflight", mapID = 2025, x = 0.43, y = 0.55, faction = "Neutral", zone = "Valdrakken" },
    -- ============================================================
    -- SHADOWLANDS — Oribos (mapID 1670)
    -- ============================================================
    { id = 1026, name = "Distributor Au'nabl",     profession = "Alchemy",        expansion = "Shadowlands",  mapID = 1670, x = 0.39, y = 0.28, faction = "Neutral", zone = "Oribos" },
    { id = 1027, name = "Smith Au'berk",           profession = "Blacksmithing",  expansion = "Shadowlands",  mapID = 1670, x = 0.42, y = 0.26, faction = "Neutral", zone = "Oribos" },
    { id = 1028, name = "Imbuer Au'vanya",         profession = "Enchanting",     expansion = "Shadowlands",  mapID = 1670, x = 0.40, y = 0.29, faction = "Neutral", zone = "Oribos" },
    { id = 1029, name = "Technician Au'frul",      profession = "Engineering",    expansion = "Shadowlands",  mapID = 1670, x = 0.43, y = 0.27, faction = "Neutral", zone = "Oribos" },
    { id = 1030, name = "Scribe Au'tehshi",        profession = "Inscription",    expansion = "Shadowlands",  mapID = 1670, x = 0.41, y = 0.30, faction = "Neutral", zone = "Oribos" },
    { id = 1031, name = "Faceter Au'dalok",        profession = "Jewelcrafting",  expansion = "Shadowlands",  mapID = 1670, x = 0.38, y = 0.27, faction = "Neutral", zone = "Oribos" },
    { id = 1032, name = "Tanner Au'khem",          profession = "Leatherworking", expansion = "Shadowlands",  mapID = 1670, x = 0.44, y = 0.31, faction = "Neutral", zone = "Oribos" },
    { id = 1033, name = "Weaver Au'von",           profession = "Tailoring",      expansion = "Shadowlands",  mapID = 1670, x = 0.37, y = 0.29, faction = "Neutral", zone = "Oribos" },
    -- ============================================================
    -- BATTLE FOR AZEROTH — Boralus (Alliance, mapID 1161)
    -- ============================================================
    { id = 1034, name = "Elric Whalgrene",         profession = "Alchemy",        expansion = "BfA",          mapID = 1161, x = 0.38, y = 0.28, faction = "Alliance", zone = "Boralus" },
    { id = 1035, name = "Layla Evenkeel",          profession = "Blacksmithing",  expansion = "BfA",          mapID = 1161, x = 0.40, y = 0.26, faction = "Alliance", zone = "Boralus" },
    { id = 1036, name = "Katharina Maier",         profession = "Enchanting",     expansion = "BfA",          mapID = 1161, x = 0.42, y = 0.27, faction = "Alliance", zone = "Boralus" },
    { id = 1037, name = "Brann Sparksocket",       profession = "Engineering",    expansion = "BfA",          mapID = 1161, x = 0.37, y = 0.29, faction = "Alliance", zone = "Boralus" },
    { id = 1038, name = "Zooey Inksworth",         profession = "Inscription",    expansion = "BfA",          mapID = 1161, x = 0.41, y = 0.30, faction = "Alliance", zone = "Boralus" },
    { id = 1039, name = "Penelope Sievers",        profession = "Tailoring",      expansion = "BfA",          mapID = 1161, x = 0.39, y = 0.32, faction = "Alliance", zone = "Boralus" },
    -- ============================================================
    -- BATTLE FOR AZEROTH — Dazar'alor (Horde, mapID 1165)
    -- ============================================================
    { id = 1040, name = "Koda Steelclaw",          profession = "Blacksmithing",  expansion = "BfA",          mapID = 1165, x = 0.52, y = 0.46, faction = "Horde", zone = "Dazar'alor" },
    { id = 1041, name = "Juba Hexbind",            profession = "Enchanting",     expansion = "BfA",          mapID = 1165, x = 0.54, y = 0.44, faction = "Horde", zone = "Dazar'alor" },
    { id = 1042, name = "Nixie Boltcrank",         profession = "Engineering",    expansion = "BfA",          mapID = 1165, x = 0.50, y = 0.47, faction = "Horde", zone = "Dazar'alor" },
    { id = 1043, name = "Belloc Brightblade",      profession = "Inscription",    expansion = "BfA",          mapID = 1165, x = 0.53, y = 0.48, faction = "Horde", zone = "Dazar'alor" },
    { id = 1044, name = "Xanjo",                   profession = "Tailoring",      expansion = "BfA",          mapID = 1165, x = 0.51, y = 0.50, faction = "Horde", zone = "Dazar'alor" },
    -- ============================================================
    -- LEGION — Dalaran (mapID 1612)
    -- ============================================================
    { id = 1045, name = "Milena Moonsorrow",       profession = "Alchemy",        expansion = "Legion",       mapID = 1612, x = 0.41, y = 0.38, faction = "Neutral", zone = "Dalaran" },
    { id = 1046, name = "Alard Schmied",           profession = "Blacksmithing",  expansion = "Legion",       mapID = 1612, x = 0.45, y = 0.38, faction = "Neutral", zone = "Dalaran" },
    { id = 1047, name = "Enchantress Ilanya",      profession = "Enchanting",     expansion = "Legion",       mapID = 1612, x = 0.42, y = 0.40, faction = "Neutral", zone = "Dalaran" },
    { id = 1048, name = "Deucus Valdera",          profession = "Engineering",    expansion = "Legion",       mapID = 1612, x = 0.47, y = 0.36, faction = "Neutral", zone = "Dalaran" },
    { id = 1049, name = "Quill Inksworth",         profession = "Inscription",    expansion = "Legion",       mapID = 1612, x = 0.40, y = 0.42, faction = "Neutral", zone = "Dalaran" },
    { id = 1050, name = "Robert Allen",            profession = "Jewelcrafting",  expansion = "Legion",       mapID = 1612, x = 0.43, y = 0.41, faction = "Neutral", zone = "Dalaran" },
    { id = 1051, name = "Una Greenfield",          profession = "Leatherworking", expansion = "Legion",       mapID = 1612, x = 0.39, y = 0.43, faction = "Neutral", zone = "Dalaran" },
    { id = 1052, name = "Elysa Ravenwood",         profession = "Tailoring",      expansion = "Legion",       mapID = 1612, x = 0.46, y = 0.43, faction = "Neutral", zone = "Dalaran" },
    -- ============================================================
    -- WARLORDS OF DRAENOR — Stormshield (Alliance, mapID 949)
    -- ============================================================
    { id = 1053, name = "Tormmok",                 profession = "Blacksmithing",  expansion = "WoD",          mapID = 949,  x = 0.60, y = 0.27, faction = "Alliance", zone = "Stormshield" },
    { id = 1054, name = "Sliverscale",             profession = "Leatherworking", expansion = "WoD",          mapID = 949,  x = 0.58, y = 0.29, faction = "Alliance", zone = "Stormshield" },
    { id = 1055, name = "Thasril",                 profession = "Tailoring",      expansion = "WoD",          mapID = 949,  x = 0.62, y = 0.26, faction = "Alliance", zone = "Stormshield" },
    -- ============================================================
    -- WARLORDS OF DRAENOR — Warspear (Horde, mapID 941)
    -- ============================================================
    { id = 1056, name = "Kaelik",                  profession = "Blacksmithing",  expansion = "WoD",          mapID = 941,  x = 0.49, y = 0.38, faction = "Horde", zone = "Warspear" },
    { id = 1057, name = "Kezzig",                  profession = "Engineering",    expansion = "WoD",          mapID = 941,  x = 0.47, y = 0.40, faction = "Horde", zone = "Warspear" },
    { id = 1058, name = "Surkha",                  profession = "Leatherworking", expansion = "WoD",          mapID = 941,  x = 0.51, y = 0.37, faction = "Horde", zone = "Warspear" },
    -- ============================================================
    -- MISTS OF PANDARIA — Shrine of Seven Stars (Alliance, mapID 807)
    -- ============================================================
    { id = 1059, name = "Lynnna Skyseeker",        profession = "Alchemy",        expansion = "MoP",          mapID = 807,  x = 0.36, y = 0.31, faction = "Alliance", zone = "Shrine of Seven Stars" },
    { id = 1060, name = "Jonn Thunderhoof",        profession = "Blacksmithing",  expansion = "MoP",          mapID = 807,  x = 0.38, y = 0.30, faction = "Alliance", zone = "Shrine of Seven Stars" },
    -- ============================================================
    -- MISTS OF PANDARIA — Shrine of Two Moons (Horde, mapID 808)
    -- ============================================================
    { id = 1061, name = "Mei Rosecutter",          profession = "Alchemy",        expansion = "MoP",          mapID = 808,  x = 0.61, y = 0.32, faction = "Horde", zone = "Shrine of Two Moons" },
    { id = 1062, name = "Cullen Hammerbrow",       profession = "Blacksmithing",  expansion = "MoP",          mapID = 808,  x = 0.63, y = 0.31, faction = "Horde", zone = "Shrine of Two Moons" },
    -- ============================================================
    -- CATACLYSM — Stormwind City (Alliance, mapID 84)
    -- ============================================================
    { id = 1063, name = "Linzy Blackbolt",         profession = "Alchemy",        expansion = "Cataclysm",    mapID = 84,   x = 0.34, y = 0.74, faction = "Alliance", zone = "Stormwind City" },
    { id = 1064, name = "Alexi Barov",             profession = "Blacksmithing",  expansion = "Cataclysm",    mapID = 84,   x = 0.34, y = 0.63, faction = "Alliance", zone = "Stormwind City" },
    { id = 1065, name = "Lucan Cordell",           profession = "Enchanting",     expansion = "Cataclysm",    mapID = 84,   x = 0.50, y = 0.73, faction = "Alliance", zone = "Stormwind City" },
    { id = 1066, name = "Lilliam Sparkspindle",    profession = "Engineering",    expansion = "Cataclysm",    mapID = 84,   x = 0.43, y = 0.68, faction = "Alliance", zone = "Stormwind City" },
    { id = 1067, name = "Catarina Stanford",       profession = "Inscription",    expansion = "Cataclysm",    mapID = 84,   x = 0.50, y = 0.73, faction = "Alliance", zone = "Stormwind City" },
    { id = 1068, name = "Timothy Jones",           profession = "Jewelcrafting",  expansion = "Cataclysm",    mapID = 84,   x = 0.52, y = 0.65, faction = "Alliance", zone = "Stormwind City" },
    { id = 1069, name = "Simon Tanner",            profession = "Leatherworking", expansion = "Cataclysm",    mapID = 84,   x = 0.42, y = 0.63, faction = "Alliance", zone = "Stormwind City" },
    { id = 1070, name = "Georgio Bolero",          profession = "Tailoring",      expansion = "Cataclysm",    mapID = 84,   x = 0.50, y = 0.72, faction = "Alliance", zone = "Stormwind City" },
    -- ============================================================
    -- CATACLYSM — Orgrimmar (Horde, mapID 85)
    -- ============================================================
    { id = 1071, name = "Serge Hinott",            profession = "Alchemy",        expansion = "Cataclysm",    mapID = 85,   x = 0.33, y = 0.57, faction = "Horde", zone = "Orgrimmar" },
    { id = 1072, name = "Saru Steelfury",          profession = "Blacksmithing",  expansion = "Cataclysm",    mapID = 85,   x = 0.44, y = 0.59, faction = "Horde", zone = "Orgrimmar" },
    { id = 1073, name = "Godan",                   profession = "Engineering",    expansion = "Cataclysm",    mapID = 85,   x = 0.64, y = 0.29, faction = "Horde", zone = "Orgrimmar" },
    { id = 1074, name = "Ildine Sorrowspell",      profession = "Enchanting",     expansion = "Cataclysm",    mapID = 85,   x = 0.36, y = 0.51, faction = "Horde", zone = "Orgrimmar" },
    { id = 1075, name = "Nerog",                   profession = "Inscription",    expansion = "Cataclysm",    mapID = 85,   x = 0.33, y = 0.57, faction = "Horde", zone = "Orgrimmar" },
    { id = 1076, name = "Ketchua",                 profession = "Jewelcrafting",  expansion = "Cataclysm",    mapID = 85,   x = 0.47, y = 0.35, faction = "Horde", zone = "Orgrimmar" },
    { id = 1077, name = "Karolek",                 profession = "Leatherworking", expansion = "Cataclysm",    mapID = 85,   x = 0.35, y = 0.59, faction = "Horde", zone = "Orgrimmar" },
    { id = 1078, name = "Magar",                   profession = "Tailoring",      expansion = "Cataclysm",    mapID = 85,   x = 0.35, y = 0.60, faction = "Horde", zone = "Orgrimmar" },
    -- ============================================================
    -- WRATH OF THE LICH KING — Dalaran (mapID 535)
    -- ============================================================
    { id = 1079, name = "Linzy Blackbolt",         profession = "Alchemy",        expansion = "WotLK",        mapID = 535,  x = 0.41, y = 0.36, faction = "Horde", zone = "Dalaran" },
    { id = 1080, name = "Wilhelmina Renel",        profession = "Alchemy",        expansion = "WotLK",        mapID = 535,  x = 0.40, y = 0.38, faction = "Alliance", zone = "Dalaran" },
    { id = 1081, name = "Jorin Doombringer",       profession = "Blacksmithing",  expansion = "WotLK",        mapID = 535,  x = 0.43, y = 0.36, faction = "Horde", zone = "Dalaran" },
    { id = 1082, name = "Argo Strongbeard",        profession = "Blacksmithing",  expansion = "WotLK",        mapID = 535,  x = 0.43, y = 0.38, faction = "Alliance", zone = "Dalaran" },
    { id = 1083, name = "Enchantress Volali",      profession = "Enchanting",     expansion = "WotLK",        mapID = 535,  x = 0.47, y = 0.32, faction = "Neutral", zone = "Dalaran" },
    { id = 1084, name = "Professor Felblast",      profession = "Engineering",    expansion = "WotLK",        mapID = 535,  x = 0.56, y = 0.50, faction = "Neutral", zone = "Dalaran" },
    { id = 1085, name = "Professor Pallin",        profession = "Inscription",    expansion = "WotLK",        mapID = 535,  x = 0.39, y = 0.53, faction = "Alliance", zone = "Dalaran" },
    { id = 1086, name = "Tiffany Cartier",         profession = "Jewelcrafting",  expansion = "WotLK",        mapID = 535,  x = 0.45, y = 0.48, faction = "Neutral", zone = "Dalaran" },
    { id = 1087, name = "Diane Cannings",          profession = "Leatherworking", expansion = "WotLK",        mapID = 535,  x = 0.41, y = 0.45, faction = "Alliance", zone = "Dalaran" },
    { id = 1088, name = "Charles Worth",           profession = "Tailoring",      expansion = "WotLK",        mapID = 535,  x = 0.39, y = 0.44, faction = "Alliance", zone = "Dalaran" },
    -- ============================================================
    -- THE BURNING CRUSADE — Shattrath City (mapID 476)
    -- ============================================================
    { id = 1089, name = "Lorokeem",                profession = "Alchemy",        expansion = "TBC",          mapID = 476,  x = 0.40, y = 0.41, faction = "Neutral", zone = "Shattrath City" },
    { id = 1090, name = "Zula Slagfury",           profession = "Blacksmithing",  expansion = "TBC",          mapID = 476,  x = 0.73, y = 0.63, faction = "Neutral", zone = "Shattrath City" },
    { id = 1091, name = "Enchantress Volali",      profession = "Enchanting",     expansion = "TBC",          mapID = 476,  x = 0.69, y = 0.30, faction = "Neutral", zone = "Shattrath City" },
    { id = 1092, name = "K. Lee Smallfry",         profession = "Engineering",    expansion = "TBC",          mapID = 476,  x = 0.55, y = 0.45, faction = "Neutral", zone = "Shattrath City" },
    { id = 1093, name = "Tatiana",                 profession = "Jewelcrafting",  expansion = "TBC",          mapID = 476,  x = 0.31, y = 0.54, faction = "Neutral", zone = "Shattrath City" },
    { id = 1094, name = "Xerintha Ravenoak",       profession = "Leatherworking", expansion = "TBC",          mapID = 476,  x = 0.44, y = 0.50, faction = "Neutral", zone = "Shattrath City" },
    { id = 1095, name = "Andrion Darkspinner",     profession = "Tailoring",      expansion = "TBC",          mapID = 476,  x = 0.67, y = 0.30, faction = "Neutral", zone = "Shattrath City" },
    -- ============================================================
    -- CLASSIC — Stormwind City (Alliance, mapID 84)
    -- ============================================================
    { id = 1096, name = "Lilyssia Nightbreeze",    profession = "Alchemy",        expansion = "Classic",      mapID = 84,   x = 0.34, y = 0.74, faction = "Alliance", zone = "Stormwind City" },
    { id = 1097, name = "Dane Lindgren",           profession = "Blacksmithing",  expansion = "Classic",      mapID = 84,   x = 0.43, y = 0.76, faction = "Alliance", zone = "Stormwind City" },
    { id = 1098, name = "Lucan Cordell",           profession = "Enchanting",     expansion = "Classic",      mapID = 84,   x = 0.50, y = 0.73, faction = "Alliance", zone = "Stormwind City" },
    { id = 1099, name = "Lilliam Sparkspindle",    profession = "Engineering",    expansion = "Classic",      mapID = 84,   x = 0.43, y = 0.68, faction = "Alliance", zone = "Stormwind City" },
    { id = 1100, name = "Simon Tanner",            profession = "Leatherworking", expansion = "Classic",      mapID = 84,   x = 0.42, y = 0.63, faction = "Alliance", zone = "Stormwind City" },
    { id = 1101, name = "Georgio Bolero",          profession = "Tailoring",      expansion = "Classic",      mapID = 84,   x = 0.50, y = 0.72, faction = "Alliance", zone = "Stormwind City" },
    -- ============================================================
    -- CLASSIC — Orgrimmar (Horde, mapID 85)
    -- ============================================================
    { id = 1102, name = "Serge Hinott",            profession = "Alchemy",        expansion = "Classic",      mapID = 85,   x = 0.33, y = 0.57, faction = "Horde", zone = "Orgrimmar" },
    { id = 1103, name = "Saru Steelfury",          profession = "Blacksmithing",  expansion = "Classic",      mapID = 85,   x = 0.44, y = 0.59, faction = "Horde", zone = "Orgrimmar" },
    { id = 1104, name = "Godan",                   profession = "Engineering",    expansion = "Classic",      mapID = 85,   x = 0.64, y = 0.29, faction = "Horde", zone = "Orgrimmar" },
    { id = 1105, name = "Ildine Sorrowspell",      profession = "Enchanting",     expansion = "Classic",      mapID = 85,   x = 0.36, y = 0.51, faction = "Horde", zone = "Orgrimmar" },
    { id = 1106, name = "Karolek",                 profession = "Leatherworking", expansion = "Classic",      mapID = 85,   x = 0.35, y = 0.59, faction = "Horde", zone = "Orgrimmar" },
    { id = 1107, name = "Magar",                   profession = "Tailoring",      expansion = "Classic",      mapID = 85,   x = 0.35, y = 0.60, faction = "Horde", zone = "Orgrimmar" },
    -- ============================================================
    -- CLASSIC — Ironforge (Alliance, mapID 87)
    -- ============================================================
    { id = 1108, name = "Tally Berryfizz",        profession = "Alchemy",        expansion = "Classic",      mapID = 87,   x = 0.53, y = 0.29, faction = "Alliance", zone = "Ironforge" },
    { id = 1109, name = "Tognus Flintfire",        profession = "Blacksmithing",  expansion = "Classic",      mapID = 87,   x = 0.55, y = 0.28, faction = "Alliance", zone = "Ironforge" },
    { id = 1110, name = "Tharynn Bouden",          profession = "Engineering",    expansion = "Classic",      mapID = 87,   x = 0.56, y = 0.30, faction = "Alliance", zone = "Ironforge" },
    { id = 1111, name = "Nissa Firestone",         profession = "Leatherworking", expansion = "Classic",      mapID = 87,   x = 0.53, y = 0.32, faction = "Alliance", zone = "Ironforge" },
    { id = 1112, name = "Adele Fielder",           profession = "Tailoring",      expansion = "Classic",      mapID = 87,   x = 0.53, y = 0.30, faction = "Alliance", zone = "Ironforge" },
}

M.PROFESSION_ORDER = {
    "Alchemy",
    "Blacksmithing",
    "Enchanting",
    "Engineering",
    "Inscription",
    "Jewelcrafting",
    "Leatherworking",
    "Tailoring",
    "Cooking",
    "Herbalism",
    "Mining",
    "Skinning",
    "Fishing",
    "Archaeology",
}

M.EXPANSION_ORDER = {
    "Classic",
    "TBC",
    "WotLK",
    "Cataclysm",
    "MoP",
    "WoD",
    "Legion",
    "BfA",
    "Shadowlands",
    "Dragonflight",
    "TWW",
    "Midnight",
}

function M:InitializeStaticData()
    self.RecipeDB = self.RecipeDB or sampleRecipes
    self.TrainerDB = self.TrainerDB or trainers
end

-- ============================================================================
-- HomeDecor cross-domain expansion key mappings (P1-4)
-- Source: HomeDecor/UI/Alts/AltsProfessions_Opportunities.lua:25-55
--
-- These complement ExpansionData.lua. ExpansionData.lua is the canonical
-- numeric enum (0..11). The tables below are STRING-keyed and cover four
-- cross-domain shapes that the donor data uses to talk about an expansion:
--   * abbreviation list (display order)
--   * skill key (Crafty internal -- matches EXPANSION_ORDER short forms)
--   * scanner key (zone/scanner-style label, e.g. "Outland", "Khaz Algar")
--   * data key (storage key used in donor DBs)
-- DATA_ALT_KEYS is a fuzzy fallback set for legacy storage layouts.
-- ============================================================================

M.EXPANSION_ABBREVS = {
    "Classic", "TBC", "WotLK", "Cata", "MoP",
    "WoD", "Legion", "BfA", "SL", "DF", "TWW", "Mid",
}

M.EXP_TO_SKILL_KEY = {
    Classic = "Classic", TBC    = "TBC",    WotLK  = "WotLK",
    Cata    = "Cata",    MoP    = "MoP",    WoD    = "WoD",
    Legion  = "Legion",  BfA    = "BfA",    SL     = "SL",
    DF      = "DF",      TWW    = "TWW",    Mid    = "Mid",
}

M.EXP_TO_SCANNER_KEY = {
    Classic = "Classic",      TBC = "Outland",      WotLK = "Northrend",
    Cata    = "Cataclysm",    MoP = "Pandaria",     WoD   = "Draenor",
    Legion  = "Legion",       BfA = "Kul Tiran",    SL    = "Shadowlands",
    DF      = "Dragon Isles", TWW = "Khaz Algar",   Mid   = "Midnight",
}

M.EXP_TO_DATA_KEY = {
    Classic = "Classic",      TBC = "Outland",      WotLK = "Northrend",
    Cata    = "Cataclysm",    MoP = "Pandaria",     WoD   = "Draenor",
    Legion  = "Legion",       BfA = "Kul Tiran",    SL    = "Shadowlands",
    DF      = "Dragon Isles", TWW = "Khaz Algar",   Mid   = "Midnight",
}

M.DATA_ALT_KEYS = {
    ["Dragon Isles"] = { "Dragon" },
    ["Kul Tiran"]    = { "Kul" },
    ["Khaz Algar"]   = { "Khaz" },
    ["Draenor"]      = { "Warlords" },
    ["Pandaria"]     = { "Pandaren" },
    ["Midnight"]     = { "Midnight" },
}


