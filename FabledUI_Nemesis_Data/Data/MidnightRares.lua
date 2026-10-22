-- ============================================================
-- HandyNotes_Midnight rare NPC import (sample)
--
-- Pending offline pipeline import from HandyNotes_Midnight zones/.
-- See [.sample-addons/HandyNotes_Midnight/zones/eversong_woods.lua]
-- for source format. The full pipeline (TODO: tools/data-pipeline/
-- sources/handynotes-midnight-importer.py) will populate this table
-- with the complete ~4,300 LOC of zone data; this file ships a
-- representative 5-rares-per-zone sample so the schema, normalization,
-- and Database:MergeMidnightImports() merge path can be validated end-
-- to-end against live runtime data before the bulk import.
--
-- Schema:
--   N.Data.MidnightRares[npcID] = {
--       name    = "Display Name",
--       mapID   = <wow uiMapID>,
--       x, y    = 0..1 normalized fractional coords,
--       quest   = <questID flagged on kill / completion>,
--       rewards = {
--           { type = "Achievement", id = <id>, criteria = <id> },
--           { type = "Reputation",  id = <factionID>, gain = 50, quest = <questID> },
--           { type = "Transmog",    item = <itemID>, kind = "shield"|"cloth"|... },
--           { type = "Mount",       item = <itemID>, mountID = <id> },
--           { type = "Pet",         item = <itemID>, petID  = <id> },
--           { type = "Toy",         item = <itemID> },
--       },
--   }
-- HandyNotes encodes coords as a single integer (XXYYxxyy) where the
-- first two digit-pairs are the percentage x and y (0-99). Example:
--   51927380 -> x = 51.92, y = 73.80 -> {x = 0.5192, y = 0.7380}
-- ============================================================

local N = FabledUI_Nemesis or Nemesis
if not N then return end
N.Data = N.Data or {}

N.Data.MidnightRares = {
    __source  = "sample",
    __version = "2026-05-04-handynotes_midnight-sample",
    __notes   = "5-per-zone sample. Replace via tools/data-pipeline/sources/handynotes-midnight-importer.py.",

    -- ============================================================
    -- Eversong Woods (mapID 2395)
    -- ============================================================
    [246332] = {
        name = "Warden of Weeds", mapID = 2395, x = 0.5192, y = 0.7380, quest = 91280,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110166 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94681 },
            { type = "Transmog",    item = 264613, kind = "shield" },
            { type = "Transmog",    item = 264520, kind = "staff" },
            { type = "Mount",       item = 257156, mountID = 2762 },
            { type = "Mount",       item = 257147, mountID = 2758 },
        },
    },
    [246633] = {
        name = "Harried Hawkstrider", mapID = 2395, x = 0.4505, y = 0.7825, quest = 91315,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110167 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94682 },
            { type = "Transmog",    item = 264522, kind = "cloth" },
            { type = "Transmog",    item = 264521, kind = "offhand" },
        },
    },
    [240129] = {
        name = "Overfester Hydra", mapID = 2395, x = 0.5470, y = 0.6018, quest = 92392,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110168 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94684 },
            { type = "Transmog",    item = 264524, kind = "leather" },
            { type = "Transmog",    item = 264523, kind = "1h_sword" },
        },
    },
    [250582] = {
        name = "Bloated Snapdragon", mapID = 2395, x = 0.3656, y = 0.6408, quest = 92366,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110169 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94685 },
            { type = "Transmog",    item = 264560, kind = "mail" },
            { type = "Transmog",    item = 264543, kind = "leather" },
        },
    },
    [250719] = {
        name = "Cre'van", mapID = 2395, x = 0.6274, y = 0.4907, quest = 92391,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110170 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94686 },
            { type = "Transmog",    item = 264573, kind = "plate" },
            { type = "Transmog",    item = 264647, kind = "1h_mace" },
        },
    },

    -- ============================================================
    -- Harandar (mapID 2413)
    -- ============================================================
    [248741] = {
        name = "Rhazul", mapID = 2413, x = 0.5116, y = 0.4535, quest = 91832,
        rewards = {
            { type = "Achievement", id = 61264, criteria = 109039 },
            { type = "Reputation",  id = 2704,  gain = 50, quest = 94712 },
            { type = "Transmog",    item = 264530, kind = "cloth" },
            { type = "Transmog",    item = 264622, kind = "dagger" },
            { type = "Mount",       item = 246735, mountID = 2615 },
            { type = "Mount",       item = 252012, mountID = 2708 },
        },
    },
    [249844] = {
        name = "Chironex", mapID = 2413, x = 0.6871, y = 0.4070, quest = 92137,
        rewards = {
            { type = "Achievement", id = 61264, criteria = 109040 },
            { type = "Reputation",  id = 2704,  gain = 50, quest = 94713 },
            { type = "Transmog",    item = 264544, kind = "leather" },
            { type = "Transmog",    item = 264538, kind = "cloth" },
        },
    },
    [249849] = {
        name = "Ha'kalawe", mapID = 2413, x = 0.6917, y = 0.5986, quest = 92142,
        rewards = {
            { type = "Achievement", id = 61264, criteria = 109041 },
            { type = "Reputation",  id = 2704,  gain = 50, quest = 94714 },
            { type = "Transmog",    item = 264553, kind = "leather" },
            { type = "Transmog",    item = 264592, kind = "cloak" },
        },
    },
    [249902] = {
        name = "Tallcap the Truthspreader", mapID = 2413, x = 0.7263, y = 0.6928, quest = 92148,
        rewards = {
            { type = "Achievement", id = 61264, criteria = 109042 },
            { type = "Reputation",  id = 2704,  gain = 50, quest = 94715 },
            { type = "Transmog",    item = 264532, kind = "cloth" },
            { type = "Transmog",    item = 264650, kind = "1h_mace" },
        },
    },
    [249962] = {
        name = "Queen Lashtongue", mapID = 2413, x = 0.5993, y = 0.4684, quest = 92154,
        rewards = {
            { type = "Achievement", id = 61264, criteria = 109043 },
            { type = "Reputation",  id = 2704,  gain = 50, quest = 94716 },
            { type = "Transmog",    item = 264571, kind = "plate" },
            { type = "Transmog",    item = 264566, kind = "mail" },
        },
    },

    -- ============================================================
    -- Voidstorm (mapID 2405)
    -- ============================================================
    [244272] = {
        name = "Sundereth the Caller", mapID = 2405, x = 0.2951, y = 0.5008, quest = 90805,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111877 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94728 },
            { type = "Transmog",    item = 264539, kind = "cloth" },
            { type = "Transmog",    item = 264619, kind = "1h_sword" },
            { type = "Mount",       item = 257085, mountID = 2751 },
            { type = "Mount",       item = 260635, mountID = 2827 },
        },
    },
    [238498] = {
        name = "Territorial Voidscythe", mapID = 2405, x = 0.3405, y = 0.8198, quest = 91050,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111878 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94729 },
            { type = "Transmog",    item = 264565, kind = "mail" },
            { type = "Transmog",    item = 264642, kind = "1h_axe" },
        },
    },
    [241443] = {
        name = "Tremora", mapID = 2405, x = 0.3616, y = 0.8355, quest = 91048,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111879 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94730 },
            { type = "Transmog",    item = 264646, kind = "bow" },
        },
    },
    [256922] = {
        name = "Screammaxa the Matriarch", mapID = 2405, x = 0.4366, y = 0.5154, quest = 93966,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111880 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94731 },
            { type = "Transmog",    item = 264583, kind = "plate" },
            { type = "Transmog",    item = 264545, kind = "leather" },
        },
    },
    [256923] = {
        name = "Bane of the Vilebloods", mapID = 2405, x = 0.4705, y = 0.8063, quest = 93946,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111881 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94732 },
            { type = "Transmog",    item = 264572, kind = "plate" },
            { type = "Transmog",    item = 264558, kind = "mail" },
        },
    },

    -- ============================================================
    -- Zul'Aman (mapID 2437)
    -- ============================================================
    [242023] = {
        name = "Necrohexxer Raz'ka", mapID = 2437, x = 0.3441, y = 0.3305, quest = 89569,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111839 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94683 },
            { type = "Transmog",    item = 264527, kind = "cloth" },
            { type = "Mount",       item = 257152, mountID = 2760 },
            { type = "Mount",       item = 257200, mountID = 2775 },
        },
    },
    [242024] = {
        name = "The Snapping Scourge", mapID = 2437, x = 0.5180, y = 0.1862, quest = 89570,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111840 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94697 },
            { type = "Transmog",    item = 264585, kind = "plate" },
            { type = "Transmog",    item = 264617, kind = "1h_sword" },
        },
    },
    [242025] = {
        name = "Skullcrusher Harak", mapID = 2437, x = 0.5185, y = 0.7291, quest = 89571,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111841 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94698 },
            { type = "Transmog",    item = 264542, kind = "leather" },
            { type = "Transmog",    item = 264631, kind = "2h_sword" },
        },
    },
    [242028] = {
        name = "Lightwood Borer", mapID = 2437, x = 0.2895, y = 0.2444, quest = 89575,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111842 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94699 },
            { type = "Transmog",    item = 264557, kind = "mail" },
            { type = "Transmog",    item = 264640, kind = "1h_axe" },
        },
    },
    [245975] = {
        name = "Mrrlokk", mapID = 2437, x = 0.5087, y = 0.6514, quest = 91174,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111843 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94700 },
            { type = "Transmog",    item = 264580, kind = "plate" },
            { type = "Transmog",    item = 264570, kind = "mail" },
        },
    },

    -- ============================================================
    -- Slayer's Rise (mapID 2444) — Voidstorm sub-zone parent
    -- ============================================================
    [245182] = {
        name = "Eruundi", mapID = 2444, x = 0.4088, y = 0.8899, quest = 91047,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111888 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94754 },
            { type = "Transmog",    item = 264563, kind = "mail" },
        },
    },
    [256925] = {
        name = "Lotus Darkblossom", mapID = 2444, x = 0.3789, y = 0.7177, quest = 93947,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111883 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94758 },
            { type = "Transmog",    item = 264548, kind = "leather" },
            { type = "Transmog",    item = 264632, kind = "staff" },
        },
    },
    [245044] = {
        name = "Nightbrood", mapID = 2444, x = 0.4017, y = 0.4130, quest = 91051,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111889 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94759 },
            { type = "Transmog",    item = 264574, kind = "plate" },
            { type = "Transmog",    item = 264551, kind = "leather" },
        },
    },
    [256926] = {
        name = "Queen o' War", mapID = 2444, x = 0.5572, y = 0.7945, quest = 93934,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111884 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94761 },
            { type = "Transmog",    item = 264533, kind = "cloth" },
        },
    },
    [256770] = {
        name = "Bilemaw the Gluttonous", mapID = 2405, x = 0.3549, y = 0.5023, quest = 93884,
        rewards = {
            { type = "Achievement", id = 62130, criteria = 111887 },
            { type = "Reputation",  id = 2699,  gain = 50, quest = 94752 },
            { type = "Transmog",    item = 264579, kind = "plate" },
            { type = "Transmog",    item = 264623, kind = "dagger" },
        },
    },

    -- ============================================================
    -- Atal'Aman (mapID 2536) — Zul'Aman sub-zone parent
    -- ============================================================
    [247976] = {
        name = "Poacher Rav'ik", mapID = 2536, x = 0.3899, y = 0.4997, quest = 91634,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111844 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94701 },
            { type = "Transmog",    item = 264911, kind = "bow" },
            { type = "Transmog",    item = 264627, kind = "polearm" },
        },
    },
    [242031] = {
        name = "Spinefrill", mapID = 2437, x = 0.3048, y = 0.4456, quest = 89578,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111845 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94702 },
            { type = "Transmog",    item = 264554, kind = "leather" },
            { type = "Transmog",    item = 264620, kind = "dagger" },
        },
    },
    [242032] = {
        name = "Oophaga", mapID = 2437, x = 0.4629, y = 0.5113, quest = 89579,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111846 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94703 },
            { type = "Transmog",    item = 264541, kind = "leather" },
            { type = "Transmog",    item = 264528, kind = "cloth" },
        },
    },
    [242033] = {
        name = "Tiny Vermin", mapID = 2437, x = 0.4777, y = 0.3422, quest = 89580,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111847 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94704 },
            { type = "Transmog",    item = 264648, kind = "1h_mace" },
        },
    },
    [242034] = {
        name = "Voidtouched Crustacean", mapID = 2437, x = 0.2130, y = 0.7055, quest = 89581,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111848 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94705 },
            { type = "Transmog",    item = 264586, kind = "plate" },
            { type = "Transmog",    item = 264564, kind = "mail" },
        },
    },

    -- ============================================================
    -- Isle of Quel'Danas (mapID 2424) — Eversong sub-zone parent
    -- ============================================================
    [250683] = {
        name = "Coralfang", mapID = 2424, x = 0.3638, y = 0.3637, quest = 92389,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110171 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94687 },
            { type = "Transmog",    item = 264629, kind = "2h_sword" },
        },
    },
    [250754] = {
        name = "Aged Farstrider", mapID = 2424, x = 0.3665, y = 0.7718, quest = 92393,
        rewards = {
            { type = "Achievement", id = 61507, criteria = 110172 },
            { type = "Reputation",  id = 2710,  gain = 50, quest = 94688 },
            { type = "Transmog",    item = 264645, kind = "bow" },
        },
    },
    [242026] = {
        name = "Elder Oaktalon", mapID = 2437, x = 0.3371, y = 0.8897, quest = 89572,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111850 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94707 },
            { type = "Transmog",    item = 264547, kind = "leather" },
            { type = "Transmog",    item = 264529, kind = "cloth" },
        },
    },
    [242035] = {
        name = "The Devouring Invader", mapID = 2437, x = 0.3959, y = 0.2097, quest = 89583,
        rewards = {
            { type = "Achievement", id = 62122, criteria = 111849 },
            { type = "Reputation",  id = 2696,  gain = 50, quest = 94706 },
            { type = "Transmog",    item = 264559, kind = "mail" },
            { type = "Transmog",    item = 264638, kind = "warglaive" },
        },
    },
    [249997] = {
        name = "Truth-Bearer of Harandar", mapID = 2413, x = 0.6457, y = 0.4794, quest = 92161,
        rewards = {
            { type = "Achievement", id = 61264, criteria = 109044 },
            { type = "Reputation",  id = 2704,  gain = 50, quest = 94717 },
            { type = "Transmog",    item = 264626, kind = "offhand" },
        },
    },
}

-- ============================================================
-- Patrol paths
-- Stored separately so the main rare table stays compact and
-- the patrol vertices can be rendered as a Map polyline overlay
-- without bloating every Index entry. Coordinates are 0..1
-- normalized; same encoding as Rare.x / Rare.y above.
-- ============================================================
N.Data.MidnightPatrols = {
    __source  = "sample",
    __version = "2026-05-04-handynotes_midnight-sample",

    -- Warden of Weeds (Eversong Woods 2395)
    [246332] = {
        { x = 0.5139, y = 0.7508 },
        { x = 0.5152, y = 0.7435 },
        { x = 0.5192, y = 0.7380 },
        { x = 0.5258, y = 0.7399 },
        { x = 0.5280, y = 0.7469 },
        { x = 0.5258, y = 0.7536 },
    },
    -- Ha'kalawe (Harandar 2413)
    [249849] = {
        { x = 0.6954, y = 0.6295 },
        { x = 0.6880, y = 0.6295 },
        { x = 0.6814, y = 0.6280 },
        { x = 0.6769, y = 0.6231 },
        { x = 0.6747, y = 0.6167 },
        { x = 0.6746, y = 0.6099 },
        { x = 0.6807, y = 0.6071 },
        { x = 0.6863, y = 0.6028 },
        { x = 0.6917, y = 0.5986 },
        { x = 0.6966, y = 0.6044 },
        { x = 0.7007, y = 0.6098 },
        { x = 0.7022, y = 0.6166 },
        { x = 0.7019, y = 0.6238 },
        { x = 0.6954, y = 0.6295 },
    },
    -- Eruundi (Slayer's Rise 2444)
    [245182] = {
        { x = 0.4103, y = 0.8872 },
        { x = 0.4088, y = 0.8899 },
        { x = 0.4102, y = 0.8949 },
        { x = 0.4105, y = 0.8986 },
        { x = 0.4113, y = 0.9032 },
        { x = 0.4116, y = 0.9061 },
        { x = 0.4147, y = 0.9058 },
        { x = 0.4171, y = 0.9037 },
        { x = 0.4155, y = 0.9005 },
        { x = 0.4142, y = 0.8975 },
        { x = 0.4103, y = 0.8872 },
    },
}
