local Providers = _G.FabledUI_DataVault_VillaProviders or {}
_G.FabledUI_DataVault_VillaProviders = Providers
local function _CurrentVilla()
    return _G.FabledUI_Villa or {}
end
local Villa = setmetatable({}, {
    __index = function(_, key)
        local current = _CurrentVilla()
        local value = current[key]
        if value ~= nil then
            return value
        end
        if key == "RegisterModule" or key == "RegisterEngine" then
            return function() end
        end
        if key == "engineRegistry" then
            return {}
        end
        return nil
    end,
    __newindex = function(_, key, value)
        local current = _G.FabledUI_Villa
        if current then
            current[key] = value
        end
    end,
})
local CodexData = Providers["codex"] or {}
Providers["codex"] = CodexData
Villa.CodexData = CodexData
Villa:RegisterModule("CodexData", CodexData)



local function activeMode(domain)
    return Villa.GetActiveMode and Villa:GetActiveMode(domain) or "codex"
end

CodexData.AchievementSourceData = {
    [158] = { achievementName = "Me and the Cappin' Makin' It Happen", category = "PvP", decorIds = {3894} },
    [167] = { achievementName = "Warsong Gulch Veteran", category = "PvP", decorIds = {3887} },
    [200] = { achievementName = "Persistent Defender", category = "PvP", decorIds = {3886} },
    [212] = { achievementName = "Storm Capper", category = "PvP", decorIds = {3898} },
    [213] = { achievementName = "Stormtrooper", category = "PvP", decorIds = {3899} },
    [221] = { achievementName = "Alterac Grave Robber", category = "PvP", decorIds = {3895} },
    [222] = { achievementName = "Tower Defense", category = "PvP", decorIds = {3897} },
    [229] = { achievementName = "The Grim Reaper", category = "PvP", decorIds = {3885} },
    [231] = { achievementName = "Wrecking Ball", category = "PvP", decorIds = {3884} },
    [938] = { achievementName = "The Snows of Northrend", category = "Exploration", decorIds = {4839} },
    [940] = { achievementName = "The Green Hills of Stranglethorn", category = "Exploration", decorIds = {4841} },
    [1153] = { achievementName = "Overly Defensive", category = "PvP", decorIds = {3896} },
    [1157] = { achievementName = "Duel-icious", category = "PvP", decorIds = {3893} },
    [4405] = { achievementName = "More Dots! (25 player)", category = "Dungeons", decorIds = {1674} },
    [4859] = { achievementName = "Kings Under the Mountain", category = "Dungeons", decorIds = {1216} },
    [5223] = { achievementName = "Master of Twin Peaks", category = "PvP", decorIds = {3867} },
    [5245] = { achievementName = "Battle for Gilneas Victory", category = "PvP", decorIds = {11296} },
    [5442] = { achievementName = "Full Caravan", category = "Quests", decorIds = {4813} },
    [6981] = { achievementName = "Master of Temple of Kotmogu", category = "PvP", decorIds = {3880, 3881} },
    [8316] = { achievementName = "Blood in the Snow", category = "Dungeons", decorIds = {11160} },
    [9415] = { achievementName = "Secrets of Skettis", category = "Exploration", decorIds = {12200} },
    [10398] = { achievementName = "Drum Circle", category = "Quests", decorIds = {11751} },
    [10698] = { achievementName = "That's Val'sharah Folks!", category = "Quests", decorIds = {1881} },
    [10996] = { achievementName = "Got to Ketchum All", category = "Dungeons", decorIds = {11315} },
    [11124] = { achievementName = "Good Suramaritan", category = "Quests", decorIds = {752} },
    [11257] = { achievementName = "Treasures of Highmountain", category = "Exploration", decorIds = {1307} },
    [11258] = { achievementName = "Treasures of Val'sharah", category = "Exploration", decorIds = {1887} },
    [11340] = { achievementName = "Insurrection", category = "Quests", decorIds = {3982} },
    [11699] = { achievementName = "Grand Fin-ale", category = "Quests", decorIds = {11909} },
    [12479] = { achievementName = "Zandalar Forever!", category = "Quests", decorIds = {1183} },
    [12509] = { achievementName = "Ready for War", category = "Quests", decorIds = {944} },
    [12582] = { achievementName = "Come Sail Away", category = "Quests", decorIds = {1704} },
    [12614] = { achievementName = "Loa Expectations", category = "Quests", decorIds = {1188} },
    [12733] = { achievementName = "Professional Zandalari Master", category = "Professions", decorIds = {1191} },
    [12746] = { achievementName = "The Zandalari Menu", category = "Professions", decorIds = {1417} },
    [12867] = { achievementName = "Azeroth at War: The Barrens", category = "Quests", decorIds = {838} },
    [12869] = { achievementName = "Azeroth at War: After Lordaeron", category = "Quests", decorIds = {837} },
    [12870] = { achievementName = "Azeroth at War: Kalimdor on Fire", category = "Quests", decorIds = {933} },
    [12997] = { achievementName = "The Pride of Kul Tiras", category = "Quests", decorIds = {9141} },
    [13018] = { achievementName = "Dune Rider", category = "Quests", decorIds = {1418} },
    [13038] = { achievementName = "Raptari Rider", category = "Quests", decorIds = {1175} },
    [13039] = { achievementName = "Paku'ai", category = "Quests", decorIds = {1185} },
    [13049] = { achievementName = "The Long Con", category = "Quests", decorIds = {9140} },
    [13284] = { achievementName = "Frontline Warrior", category = "PvP", decorIds = {937} },
    [13473] = { achievementName = "Diversified Investments", category = "Exploration", decorIds = {2326} },
    [13475] = { achievementName = "Junkyard Scavenger", category = "Exploration", decorIds = {2435} },
    [13477] = { achievementName = "Junkyard Apprentice", category = "Exploration", decorIds = {2430} },
    [13723] = { achievementName = "M.C., Hammered", category = "Dungeons", decorIds = {2322} },
    [17529] = { achievementName = "Forbidden Spoils", category = "Exploration", decorIds = {4482} },
    [17773] = { achievementName = "A Blue Dawn", category = "Quests", decorIds = {4160} },
    [19408] = { achievementName = "Professional Algari Master", category = "Professions", decorIds = {9237} },
    [19458] = { achievementName = "A World Awoken", category = "Quests", decorIds = {4180} },
    [19507] = { achievementName = "Fringe Benefits", category = "Quests", decorIds = {4161} },
    [19719] = { achievementName = "Reclamation of Gilneas", category = "PvP", decorIds = {857} },
    [20501] = { achievementName = "Back from the Beyond", category = "Quests", decorIds = {4181} },
    [20595] = { achievementName = "Sojourner of Isle of Dorn", category = "Quests", decorIds = {9169} },
    [40210] = { achievementName = "Deephaul Ravine Victory", category = "PvP", decorIds = {9244} },
    [40504] = { achievementName = "Rocked to Sleep", category = "Exploration", decorIds = {9181} },
    [40542] = { achievementName = "Smelling History", category = "Exploration", decorIds = {2532} },
    [40612] = { achievementName = "Sprinting in the Ravine", category = "PvP", decorIds = {3890} },
    [40859] = { achievementName = "We're Here All Night", category = "Exploration", decorIds = {9185} },
    [40894] = { achievementName = "Sojourner of Undermine", category = "Quests", decorIds = {1271} },
    [40953] = { achievementName = "A Farewell to Arms", category = "Expansion Features", decorIds = {3837, 3838} },
    [41119] = { achievementName = "One Rank Higher", category = "Dungeons", decorIds = {1121} },
    [41186] = { achievementName = "Slate of the Union", category = "Exploration", decorIds = {2533} },
    [42187] = { achievementName = "Lorewalking: Ethereal Wisdom", category = "Expansion Features", decorIds = {11456} },
    [42188] = { achievementName = "Lorewalking: Blade's Bane", category = "Expansion Features", decorIds = {11457} },
    [42189] = { achievementName = "Lorewalking: The Lich King", category = "Expansion Features", decorIds = {11453} },
    [42270] = { achievementName = "The Deathlord's Campaign", category = "Class Hall", decorIds = {5882} },
    [42271] = { achievementName = "The Slayer's Campaign", category = "Class Hall", decorIds = {5527} },
    [42272] = { achievementName = "The Archdruid's Campaign", category = "Class Hall", decorIds = {14358} },
    [42274] = { achievementName = "The Archmage's Campaign", category = "Class Hall", decorIds = {750} },
    [42275] = { achievementName = "The Grandmaster's Campaign", category = "Class Hall", decorIds = {5126} },
    [42276] = { achievementName = "The Highlord's Campaign", category = "Class Hall", decorIds = {7575} },
    [42277] = { achievementName = "The High Priest's Campaign", category = "Class Hall", decorIds = {7824} },
    [42279] = { achievementName = "The Shadowblade's Campaign", category = "Class Hall", decorIds = {14461} },
    [42280] = { achievementName = "The Farseer's Campaign", category = "Class Hall", decorIds = {11493} },
    [42281] = { achievementName = "The Netherlord's Campaign", category = "Class Hall", decorIds = {5128} },
    [42282] = { achievementName = "The Battlelord's Campaign", category = "Class Hall", decorIds = {5534} },
    [42287] = { achievementName = "Hidden Potential of the Deathlord", category = "Class Hall", decorIds = {5888} },
    [42288] = { achievementName = "Hidden Potential of the Slayer", category = "Class Hall", decorIds = {5525} },
    [42289] = { achievementName = "Hidden Potential of the Archdruid", category = "Class Hall", decorIds = {5898} },
    [42290] = { achievementName = "Hidden Potential of the Huntmaster", category = "Class Hall", decorIds = {5890} },
    [42291] = { achievementName = "Hidden Potential of the Archmage", category = "Class Hall", decorIds = {7609} },
    [42292] = { achievementName = "Hidden Potential of the Grandmaster", category = "Class Hall", decorIds = {14644} },
    [42293] = { achievementName = "Hidden Potential of the Highlord", category = "Class Hall", decorIds = {7571} },
    [42294] = { achievementName = "Hidden Potential of the High Priest", category = "Class Hall", decorIds = {7822} },
    [42295] = { achievementName = "Hidden Potential of the Shadowblade", category = "Class Hall", decorIds = {7819} },
    [42296] = { achievementName = "Hidden Potential of the Farseer", category = "Class Hall", decorIds = {7837} },
    [42297] = { achievementName = "Hidden Potential of the Netherlord", category = "Class Hall", decorIds = {5117} },
    [42298] = { achievementName = "Hidden Potential of the Battlelord", category = "Class Hall", decorIds = {5526} },
    [42318] = { achievementName = "Court of Farondis", category = "Reputation", decorIds = {7610} },
    [42321] = { achievementName = "Legion Remix Raids", category = "Timewalking", decorIds = {7624} },
    [42547] = { achievementName = "Highmountain Tribe", category = "Reputation", decorIds = {11942} },
    [42619] = { achievementName = "Dreamweavers", category = "Reputation", decorIds = {7625} },
    [42627] = { achievementName = "Argussian Reach", category = "Reputation", decorIds = {7687} },
    [42628] = { achievementName = "The Nightfallen", category = "Reputation", decorIds = {11278} },
    [42655] = { achievementName = "The Armies of Legionfall", category = "Reputation", decorIds = {9165} },
    [42658] = { achievementName = "Valarjar", category = "Reputation", decorIds = {7620} },
    [42674] = { achievementName = "Broken Isles World Quests V", category = "Quests", decorIds = {7690} },
    [42675] = { achievementName = "Defending the Broken Isles III", category = "Quests", decorIds = {7658} },
    [42689] = { achievementName = "Timeworn Keystone Master", category = "Timewalking", decorIds = {8811} },
    [42692] = { achievementName = "Broken Isles Dungeoneer", category = "Dungeons", decorIds = {7621} },
    [42786] = { achievementName = "Leatherworking at Midnight", category = "Professions", decorIds = {15411} },
    [42787] = { achievementName = "Enchanting at Midnight", category = "Professions", decorIds = {15405} },
    [42788] = { achievementName = "Alchemizing at Midnight", category = "Professions", decorIds = {15402} },
    [42789] = { achievementName = "Jewelcrafting at Midnight", category = "Professions", decorIds = {15410} },
    [42790] = { achievementName = "Skinning at Midnight", category = "Professions", decorIds = {15458} },
    [42791] = { achievementName = "Mining at Midnight", category = "Professions", decorIds = {15457} },
    [42792] = { achievementName = "Blacksmithing at Midnight", category = "Professions", decorIds = {15403} },
    [42793] = { achievementName = "Herbalism at Midnight", category = "Professions", decorIds = {15408} },
    [42794] = { achievementName = "Tailoring at Midnight", category = "Professions", decorIds = {15459} },
    [42795] = { achievementName = "Cooking at Midnight", category = "Professions", decorIds = {15404} },
    [42796] = { achievementName = "Inscribing at Midnight", category = "Professions", decorIds = {15409} },
    [42797] = { achievementName = "Fishing at Midnight", category = "Professions", decorIds = {15407} },
    [42798] = { achievementName = "Engineering at Midnight", category = "Professions", decorIds = {15406} },
    [60962] = { achievementName = "Legendary Research of the Ebon Blade", category = "Class Hall", decorIds = {14361} },
    [60963] = { achievementName = "Legendary Research of the Illidari", category = "Class Hall", decorIds = {5575} },
    [60964] = { achievementName = "Legendary Research of the Dreamgrove", category = "Class Hall", decorIds = {5878} },
    [60965] = { achievementName = "Legendary Research of the Unseen Path", category = "Class Hall", decorIds = {5892} },
    [60966] = { achievementName = "Legendary Research of the Tirisgarde", category = "Class Hall", decorIds = {11275} },
    [60967] = { achievementName = "Legendary Research of Five Dawns", category = "Class Hall", decorIds = {11280} },
    [60968] = { achievementName = "Legendary Research of the Silver Hand", category = "Class Hall", decorIds = {7574} },
    [60969] = { achievementName = "Legendary Research of the Netherlight Conclave", category = "Class Hall", decorIds = {7823} },
    [60970] = { achievementName = "Legendary Research of the Uncrowned", category = "Class Hall", decorIds = {7820} },
    [60971] = { achievementName = "Legendary Research of the Maelstrom", category = "Class Hall", decorIds = {7838} },
    [60972] = { achievementName = "Legendary Research of the Black Harvest", category = "Class Hall", decorIds = {11307} },
    [60973] = { achievementName = "Legendary Research of the Valarjar", category = "Class Hall", decorIds = {11486} },
    [60981] = { achievementName = "Raise an Army for Acherus", category = "Class Hall", decorIds = {5879} },
    [60982] = { achievementName = "Raise an Army for the Fel Hammer", category = "Class Hall", decorIds = {5555} },
    [60983] = { achievementName = "Raise an Army for the Dreamgrove", category = "Class Hall", decorIds = {7873} },
    [60984] = { achievementName = "Raise an Army for the Trueshot Lodge", category = "Class Hall", decorIds = {5891} },
    [60985] = { achievementName = "Raise an Army for the Hall of the Guardian", category = "Class Hall", decorIds = {5895} },
    [60986] = { achievementName = "Raise an Army for the Temple of Five Dawns", category = "Class Hall", decorIds = {5119} },
    [60987] = { achievementName = "Raise an Army for the Sanctum of Light", category = "Class Hall", decorIds = {7577} },
    [60988] = { achievementName = "Raise an Army for the Netherlight Temple", category = "Class Hall", decorIds = {8768} },
    [60989] = { achievementName = "Raise an Army for the Hall of Shadows", category = "Class Hall", decorIds = {7818} },
    [60990] = { achievementName = "Raise an Army for the Maelstrom", category = "Class Hall", decorIds = {7874} },
    [60991] = { achievementName = "Raise an Army for the Dreadscar Rift", category = "Class Hall", decorIds = {15477} },
    [60992] = { achievementName = "Raise an Army for Skyhold", category = "Class Hall", decorIds = {5529} },
    [61054] = { achievementName = "Heroic Broken Isles World Quests III", category = "Quests", decorIds = {7686} },
    [61060] = { achievementName = "Power of the Obelisks II", category = "Dungeons", decorIds = {7623} },
    [61218] = { achievementName = "The Wardens", category = "Reputation", decorIds = {8810} },
    [61264] = { achievementName = "Leaf None Behind", category = "Exploration", decorIds = {15501} },
    [61451] = { achievementName = "Worldsoul-Searching", category = "Quests", decorIds = {11455} },
    [61467] = { achievementName = "Lorewalking: The Elves of Quel'Thalas", category = "Expansion Features", decorIds = {767} },
    [61507] = { achievementName = "A Bloody Song", category = "Exploration", decorIds = {11470} },
    [61683] = { achievementName = "Entering Battle", category = "PvP", decorIds = {3900} },
    [61684] = { achievementName = "Progressing in Battle", category = "PvP", decorIds = {3905} },
    [61685] = { achievementName = "Proficient in Battle", category = "PvP", decorIds = {3906} },
    [61686] = { achievementName = "Expert in Battle", category = "PvP", decorIds = {3907} },
    [61687] = { achievementName = "Champion in Battle", category = "PvP", decorIds = {3902} },
    [61688] = { achievementName = "Master in Battle", category = "PvP", decorIds = {3903} },
    [62122] = { achievementName = "Tallest Tree in the Forest", category = "Exploration", decorIds = {15573} },
    [62130] = { achievementName = "The Ultimate Predator", category = "Delves", decorIds = {15757} },
    [62144] = { achievementName = "Prey: Mad Magisters (Hard)", category = "Delves", decorIds = {17455} },
    [62153] = { achievementName = "Prey: Insane Inventors (Hard)", category = "Delves", decorIds = {17456} },
    [62154] = { achievementName = "Prey: A Different Kind of Void (Hard)", category = "Delves", decorIds = {17522} },
    [62155] = { achievementName = "Prey: Ethereal Assassins (Hard)", category = "Delves", decorIds = {17457} },
    [62156] = { achievementName = "Prey: Anger Management (Hard)", category = "Delves", decorIds = {17458} },
    [62157] = { achievementName = "Prey: Sadistic Shamans (Hard)", category = "Delves", decorIds = {17459} },
    [62158] = { achievementName = "Prey: The Fallen Farstriders (Hard)", category = "Delves", decorIds = {17523} },
    [62159] = { achievementName = "Prey: Bloody Green Thumbs (Hard)", category = "Delves", decorIds = {17460} },
    [62160] = { achievementName = "Prey: Blinded By The Light (Hard)", category = "Delves", decorIds = {17462} },
    [62161] = { achievementName = "Prey: Outsmarting the Schemers (Hard)", category = "Delves", decorIds = {17464} },
    [62162] = { achievementName = "Prey: Dominating the Void (Hard)", category = "Delves", decorIds = {17465} },
    [62163] = { achievementName = "Prey: Chasing Death (Hard)", category = "Delves", decorIds = {17467} },
    [62164] = { achievementName = "Prey: No Rest for the Wretched (Hard)", category = "Delves", decorIds = {17469} },
    [62165] = { achievementName = "Prey: A Thorn in the Side (Hard)", category = "Delves", decorIds = {17472} },
    [62166] = { achievementName = "Prey: Breaking the Blade (Hard)", category = "Delves", decorIds = {17474} },
    [62167] = { achievementName = "Prey: Mad Magisters (Nightmare)", category = "Delves", decorIds = {17439} },
    [62168] = { achievementName = "Prey: Insane Inventors (Nightmare)", category = "Delves", decorIds = {17440} },
    [62169] = { achievementName = "Prey: A Different Kind of Void (Nightmare)", category = "Delves", decorIds = {17520} },
    [62173] = { achievementName = "Prey: Ethereal Assassins (Nightmare)", category = "Delves", decorIds = {17441} },
    [62174] = { achievementName = "Prey: Anger Management (Nightmare)", category = "Delves", decorIds = {17442} },
    [62175] = { achievementName = "Prey: Sadistic Shamans (Nightmare)", category = "Delves", decorIds = {17443} },
    [62176] = { achievementName = "Prey: The Fallen Farstriders (Nightmare)", category = "Delves", decorIds = {17521} },
    [62177] = { achievementName = "Prey: Bloody Green Thumbs (Nightmare)", category = "Delves", decorIds = {17444} },
    [62178] = { achievementName = "Prey: Blinded By The Light (Nightmare)", category = "Delves", decorIds = {17446} },
    [62179] = { achievementName = "Prey: Outsmarting the Schemers (Nightmare)", category = "Delves", decorIds = {17447} },
    [62180] = { achievementName = "Prey: Dominating the Void (Nightmare)", category = "Delves", decorIds = {17449} },
    [62181] = { achievementName = "Prey: Chasing Death (Nightmare)", category = "Delves", decorIds = {17450} },
    [62182] = { achievementName = "Prey: No Rest for the Wretched (Nightmare)", category = "Delves", decorIds = {17452} },
    [62183] = { achievementName = "Prey: A Thorn in the Side (Nightmare)", category = "Delves", decorIds = {17453} },
    [62184] = { achievementName = "Prey: Breaking the Blade (Nightmare)", category = "Delves", decorIds = {17454} },
    [62185] = { achievementName = "Ever Painting", category = "Exploration", decorIds = {1446} },
    [62186] = { achievementName = "The Party Must Go On", category = "Exploration", decorIds = {8872} },
    [62288] = { achievementName = "Eversong Woods: The Highest Peaks", category = "Exploration", decorIds = {10542} },
    [62289] = { achievementName = "Zul'Aman: The Highest Peaks", category = "Exploration", decorIds = {11325} },
    [62290] = { achievementName = "Harandar: The Highest Peaks", category = "Exploration", decorIds = {17516} },
    [62291] = { achievementName = "Voidstorm: The Highest Peaks", category = "Exploration", decorIds = {15890} },
    [62387] = { achievementName = "It's Nearly Midnight", category = "Expansion Features", decorIds = {14467} },
}

CodexData.CraftingSourceData = {
    ["Alchemy"] = {
        { decorId = 11438, recipeId = 1262829, recipeName = "Alchemy", skillLine = "Classic Alchemy", skillNeeded = 240 },
        { decorId = 16220, recipeId = 1273064, recipeName = "Alchemy", skillLine = "Outland Alchemy", skillNeeded = 60 },
        { decorId = 16219, recipeId = 1273070, recipeName = "Alchemy", skillLine = "Outland Alchemy", skillNeeded = 60 },
        { decorId = 11281, recipeId = 1262154, recipeName = "Alchemy", skillLine = "Legion Alchemy", skillNeeded = 80 },
        { decorId = 11381, recipeId = 1262005, recipeName = "Alchemy", skillLine = "Battle for Azeroth Alchemy", skillNeeded = 140 },
        { decorId = 9170, recipeId = 1259673, recipeName = "Alchemy", skillLine = "Khaz Algar Alchemy", skillNeeded = 80 },
        { decorId = 11387, recipeId = 1261882, recipeName = "Alchemy", skillLine = "Dragon Isles Alchemy", skillNeeded = 80 },
        { decorId = 14558, recipeId = 1233132, recipeName = "Alchemy", skillLine = "Midnight Alchemy", skillNeeded = 10 },
        { decorId = 855, recipeId = 1261255, recipeName = "Alchemy", skillLine = "Cataclysm Alchemy", skillNeeded = 60 },
        { decorId = 11723, recipeId = 1269506, recipeName = "Alchemy", skillLine = "Cataclysm Alchemy", skillNeeded = 60 },
        { decorId = 16082, recipeId = 1272712, recipeName = "Alchemy", skillLine = "Outland Alchemy", skillNeeded = 60 },
        { decorId = 14559, recipeId = 1233137, recipeName = "Alchemy", skillLine = "Midnight Alchemy", skillNeeded = 10 },
        { decorId = 11901, recipeId = 1263559, recipeName = "Alchemy", skillLine = "Northrend Alchemy", skillNeeded = 60 },
        { decorId = 11440, recipeId = 1261878, recipeName = "Alchemy", skillLine = "Khaz Algar Alchemy", skillNeeded = 80 },
        { decorId = 11379, recipeId = 1262011, recipeName = "Alchemy", skillLine = "Draenor Alchemy", skillNeeded = 80 },
        { decorId = 11902, recipeId = 1263548, recipeName = "Alchemy", skillLine = "Pandaria Alchemy", skillNeeded = 60 },
        { decorId = 11378, recipeId = 1261233, recipeName = "Alchemy", skillLine = "Pandaria Alchemy", skillNeeded = 60 },
        { decorId = 14557, recipeId = 1233136, recipeName = "Alchemy", skillLine = "Midnight Alchemy", skillNeeded = 10 },
        { decorId = 1247, recipeId = 1233133, recipeName = "Alchemy", skillLine = "Midnight Alchemy", skillNeeded = 10 },
        { decorId = 11900, recipeId = 1263558, recipeName = "Alchemy", skillLine = "Northrend Alchemy", skillNeeded = 60 },
        { decorId = 16083, recipeId = 1272723, recipeName = "Alchemy", skillLine = "Outland Alchemy", skillNeeded = 60 },
        { decorId = 11501, recipeId = 1233138, recipeName = "Alchemy", skillLine = "Midnight Alchemy", skillNeeded = 10 },
        { decorId = 11386, recipeId = 1261972, recipeName = "Alchemy", skillLine = "Shadowlands Alchemy", skillNeeded = 140 },
        { decorId = 11380, recipeId = 1262152, recipeName = "Alchemy", skillLine = "Legion Alchemy", skillNeeded = 80 },
        { decorId = 11376, recipeId = 1261495, recipeName = "Alchemy", skillLine = "Classic Alchemy", skillNeeded = 240 },
        { decorId = 16086, recipeId = 1272715, recipeName = "Alchemy", skillLine = "Outland Alchemy", skillNeeded = 60 },
        { decorId = 11138, recipeId = 1233135, recipeName = "Alchemy", skillLine = "Midnight Alchemy", skillNeeded = 10 },
        { decorId = 11385, recipeId = 1261958, recipeName = "Alchemy", skillLine = "Shadowlands Alchemy", skillNeeded = 140 },
        { decorId = 4167, recipeId = 1261885, recipeName = "Alchemy", skillLine = "Dragon Isles Alchemy", skillNeeded = 80 },
        { decorId = 1410, recipeId = 1260985, recipeName = "Alchemy", skillLine = "Draenor Alchemy", skillNeeded = 80 },
        { decorId = 11382, recipeId = 1262151, recipeName = "Alchemy", skillLine = "Battle for Azeroth Alchemy", skillNeeded = 140 },
    },
    ["Blacksmithing"] = {
        { decorId = 11383, recipeId = 1261982, recipeName = "Blacksmithing", skillLine = "Shadowlands Blacksmithing", skillNeeded = 80 },
        { decorId = 11384, recipeId = 1261980, recipeName = "Blacksmithing", skillLine = "Shadowlands Blacksmithing", skillNeeded = 80 },
        { decorId = 1325, recipeId = 1260988, recipeName = "Blacksmithing", skillLine = "Draenor Blacksmithing", skillNeeded = 80 },
        { decorId = 9046, recipeId = 1260691, recipeName = "Blacksmithing", skillLine = "Battle for Azeroth Blacksmithing", skillNeeded = 140 },
        { decorId = 11370, recipeId = 1261347, recipeName = "Blacksmithing", skillLine = "Outland Blacksmithing", skillNeeded = 60 },
        { decorId = 11375, recipeId = 1261327, recipeName = "Blacksmithing", skillLine = "Northrend Blacksmithing", skillNeeded = 60 },
        { decorId = 16012, recipeId = 1272662, recipeName = "Blacksmithing", skillLine = "Northrend Blacksmithing", skillNeeded = 60 },
        { decorId = 16087, recipeId = 1272614, recipeName = "Blacksmithing", skillLine = "Northrend Blacksmithing", skillNeeded = 60 },
        { decorId = 11374, recipeId = 1261359, recipeName = "Blacksmithing", skillLine = "Outland Blacksmithing", skillNeeded = 60 },
        { decorId = 11371, recipeId = 1261383, recipeName = "Blacksmithing", skillLine = "Outland Blacksmithing", skillNeeded = 60 },
        { decorId = 1791, recipeId = 1260987, recipeName = "Blacksmithing", skillLine = "Draenor Blacksmithing", skillNeeded = 80 },
        { decorId = 14581, recipeId = 1276108, recipeName = "Blacksmithing", skillLine = "Midnight Blacksmithing" },
        { decorId = 14587, recipeId = 1276110, recipeName = "Blacksmithing", skillLine = "Midnight Blacksmithing" },
        { decorId = 11377, recipeId = 1261256, recipeName = "Blacksmithing", skillLine = "Cataclysm Blacksmithing", skillNeeded = 60 },
        { decorId = 14582, recipeId = 1276112, recipeName = "Blacksmithing", skillLine = "Midnight Blacksmithing" },
        { decorId = 14586, recipeId = 1276109, recipeName = "Blacksmithing", skillLine = "Midnight Blacksmithing" },
        { decorId = 3892, recipeId = 1261234, recipeName = "Blacksmithing", skillLine = "Pandaria Blacksmithing", skillNeeded = 60 },
        { decorId = 3831, recipeId = 1261235, recipeName = "Blacksmithing", skillLine = "Pandaria Blacksmithing", skillNeeded = 60 },
        { decorId = 14590, recipeId = 1276111, recipeName = "Blacksmithing", skillLine = "Midnight Blacksmithing" },
        { decorId = 1260, recipeId = 1259675, recipeName = "Blacksmithing", skillLine = "Khaz Algar Blacksmithing", skillNeeded = 80 },
        { decorId = 2001, recipeId = 1261497, recipeName = "Blacksmithing", skillLine = "Classic Blacksmithing", skillNeeded = 240 },
        { decorId = 1270, recipeId = 1259681, recipeName = "Blacksmithing", skillLine = "Khaz Algar Blacksmithing", skillNeeded = 80 },
        { decorId = 11497, recipeId = 1262308, recipeName = "Blacksmithing", skillLine = "Cataclysm Blacksmithing", skillNeeded = 60 },
        { decorId = 2332, recipeId = 1261499, recipeName = "Blacksmithing", skillLine = "Classic Blacksmithing", skillNeeded = 240 },
        { decorId = 9048, recipeId = 1260692, recipeName = "Blacksmithing", skillLine = "Battle for Azeroth Blacksmithing", skillNeeded = 140 },
        { decorId = 4036, recipeId = 1260693, recipeName = "Blacksmithing", skillLine = "Legion Blacksmithing", skillNeeded = 80 },
        { decorId = 4023, recipeId = 1260695, recipeName = "Blacksmithing", skillLine = "Legion Blacksmithing", skillNeeded = 80 },
        { decorId = 1314, recipeId = 1260698, recipeName = "Blacksmithing", skillLine = "Legion Blacksmithing", skillNeeded = 80 },
        { decorId = 11165, recipeId = 1261892, recipeName = "Blacksmithing", skillLine = "Dragon Isles Blacksmithing", skillNeeded = 80 },
        { decorId = 11162, recipeId = 1261896, recipeName = "Blacksmithing", skillLine = "Dragon Isles Blacksmithing", skillNeeded = 80 },
    },
    ["Cooking"] = {
        { decorId = 755, recipeId = 1260337, recipeName = "Cooking", skillLine = "Battle for Azeroth Cooking", skillNeeded = 140 },
        { decorId = 2596, recipeId = 1260333, recipeName = "Cooking", skillLine = "Dragon Isles Cooking", skillNeeded = 80 },
        { decorId = 2468, recipeId = 1260334, recipeName = "Cooking", skillLine = "Shadowlands Cooking", skillNeeded = 60 },
        { decorId = 759, recipeId = 1245993, recipeName = "Cooking", skillLine = "Khaz Algar Cooking", skillNeeded = 80 },
        { decorId = 2471, recipeId = 1245995, recipeName = "Cooking", skillLine = "Khaz Algar Cooking", skillNeeded = 80 },
        { decorId = 2593, recipeId = 1266555, recipeName = "Cooking", skillLine = "Dragon Isles Cooking", skillNeeded = 80 },
        { decorId = 2472, recipeId = 1245994, recipeName = "Cooking", skillLine = "Khaz Algar Cooking", skillNeeded = 80 },
        { decorId = 749, recipeId = 1266560, recipeName = "Cooking", skillLine = "Draenor Cooking", skillNeeded = 80 },
        { decorId = 765, recipeId = 1266541, recipeName = "Cooking", skillLine = "Khaz Algar Cooking", skillNeeded = 80 },
        { decorId = 2591, recipeId = 1266563, recipeName = "Cooking", skillLine = "Pandaria Cooking", skillNeeded = 60 },
        { decorId = 2595, recipeId = 1260331, recipeName = "Cooking", skillLine = "Dragon Isles Cooking", skillNeeded = 80 },
    },
    ["Enchanting"] = {
        { decorId = 11431, recipeId = 1262828, recipeName = "Enchanting", skillLine = "Outland Enchanting", skillNeeded = 60 },
        { decorId = 1792, recipeId = 1260990, recipeName = "Enchanting", skillLine = "Draenor Enchanting", skillNeeded = 80 },
        { decorId = 14589, recipeId = 1246906, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 14588, recipeId = 1246902, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 11918, recipeId = 1263238, recipeName = "Enchanting", skillLine = "Shadowlands Enchanting", skillNeeded = 90 },
        { decorId = 14816, recipeId = 1270459, recipeName = "Enchanting", skillLine = "Classic Enchanting", skillNeeded = 240 },
        { decorId = 9187, recipeId = 1259715, recipeName = "Enchanting", skillLine = "Khaz Algar Enchanting", skillNeeded = 80 },
        { decorId = 10964, recipeId = 1261933, recipeName = "Enchanting", skillLine = "Dragon Isles Enchanting", skillNeeded = 80 },
        { decorId = 11372, recipeId = 1261331, recipeName = "Enchanting", skillLine = "Outland Enchanting", skillNeeded = 60 },
        { decorId = 11373, recipeId = 1261340, recipeName = "Enchanting", skillLine = "Outland Enchanting", skillNeeded = 60 },
        { decorId = 8787, recipeId = 1261008, recipeName = "Enchanting", skillLine = "Draenor Enchanting", skillNeeded = 80 },
        { decorId = 12164, recipeId = 1263877, recipeName = "Enchanting", skillLine = "Battle for Azeroth Enchanting", skillNeeded = 140 },
        { decorId = 19229, recipeId = 1281342, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 19231, recipeId = 1281348, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 19234, recipeId = 1281349, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 14580, recipeId = 1246904, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 80 },
        { decorId = 10965, recipeId = 1261919, recipeName = "Enchanting", skillLine = "Dragon Isles Enchanting", skillNeeded = 80 },
        { decorId = 14585, recipeId = 1246905, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 80 },
        { decorId = 11435, recipeId = 1262302, recipeName = "Enchanting", skillLine = "Pandaria Enchanting", skillNeeded = 60 },
        { decorId = 11432, recipeId = 1262824, recipeName = "Enchanting", skillLine = "Northrend Enchanting", skillNeeded = 60 },
        { decorId = 11282, recipeId = 1262238, recipeName = "Enchanting", skillLine = "Legion Enchanting", skillNeeded = 80 },
        { decorId = 11434, recipeId = 1262306, recipeName = "Enchanting", skillLine = "Pandaria Enchanting", skillNeeded = 60 },
        { decorId = 11494, recipeId = 1262331, recipeName = "Enchanting", skillLine = "Cataclysm Enchanting", skillNeeded = 60 },
        { decorId = 14598, recipeId = 1246903, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 9245, recipeId = 1259690, recipeName = "Enchanting", skillLine = "Khaz Algar Enchanting", skillNeeded = 80 },
        { decorId = 14616, recipeId = 1246908, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 2460, recipeId = 1246909, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 14600, recipeId = 1246907, recipeName = "Enchanting", skillLine = "Midnight Enchanting", skillNeeded = 50 },
        { decorId = 11439, recipeId = 1262825, recipeName = "Enchanting", skillLine = "Northrend Enchanting", skillNeeded = 60 },
        { decorId = 4037, recipeId = 1260700, recipeName = "Enchanting", skillLine = "Legion Enchanting", skillNeeded = 80 },
        { decorId = 12163, recipeId = 1263870, recipeName = "Enchanting", skillLine = "Battle for Azeroth Enchanting", skillNeeded = 140 },
        { decorId = 9266, recipeId = 1261501, recipeName = "Enchanting", skillLine = "Classic Enchanting", skillNeeded = 240 },
        { decorId = 11433, recipeId = 1262318, recipeName = "Enchanting", skillLine = "Cataclysm Enchanting", skillNeeded = 60 },
        { decorId = 11436, recipeId = 1261998, recipeName = "Enchanting", skillLine = "Shadowlands Enchanting", skillNeeded = 90 },
    },
    ["Engineering"] = {
        { decorId = 2301, recipeId = 1248612, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 11928, recipeId = 1263240, recipeName = "Engineering", skillLine = "Shadowlands Engineering", skillNeeded = 80 },
        { decorId = 11912, recipeId = 1263319, recipeName = "Engineering", skillLine = "Legion Engineering", skillNeeded = 80 },
        { decorId = 2227, recipeId = 1261509, recipeName = "Engineering", skillLine = "Classic Engineering", skillNeeded = 240 },
        { decorId = 2436, recipeId = 1260349, recipeName = "Engineering", skillLine = "Battle for Azeroth Engineering", skillNeeded = 140 },
        { decorId = 11881, recipeId = 1263654, recipeName = "Engineering", skillLine = "Outland Engineering", skillNeeded = 60 },
        { decorId = 8191, recipeId = 1261025, recipeName = "Engineering", skillLine = "Draenor Engineering", skillNeeded = 80 },
        { decorId = 11884, recipeId = 1263663, recipeName = "Engineering", skillLine = "Outland Engineering", skillNeeded = 60 },
        { decorId = 11911, recipeId = 1263338, recipeName = "Engineering", skillLine = "Legion Engineering", skillNeeded = 80 },
        { decorId = 1406, recipeId = 1261027, recipeName = "Engineering", skillLine = "Draenor Engineering", skillNeeded = 80 },
        { decorId = 1793, recipeId = 1261258, recipeName = "Engineering", skillLine = "Cataclysm Engineering", skillNeeded = 60 },
        { decorId = 2465, recipeId = 1261504, recipeName = "Engineering", skillLine = "Classic Engineering", skillNeeded = 240 },
        { decorId = 2329, recipeId = 1260352, recipeName = "Engineering", skillLine = "Battle for Azeroth Engineering", skillNeeded = 140 },
        { decorId = 3873, recipeId = 1261236, recipeName = "Engineering", skillLine = "Pandaria Engineering", skillNeeded = 60 },
        { decorId = 16085, recipeId = 1272688, recipeName = "Engineering", skillLine = "Northrend Engineering", skillNeeded = 60 },
        { decorId = 16088, recipeId = 1272676, recipeName = "Engineering", skillLine = "Northrend Engineering", skillNeeded = 60 },
        { decorId = 11921, recipeId = 1263239, recipeName = "Engineering", skillLine = "Shadowlands Engineering", skillNeeded = 80 },
        { decorId = 2340, recipeId = 1260425, recipeName = "Engineering", skillLine = "Battle for Azeroth Engineering", skillNeeded = 140 },
        { decorId = 11904, recipeId = 1263551, recipeName = "Engineering", skillLine = "Pandaria Engineering", skillNeeded = 60 },
        { decorId = 14642, recipeId = 1248615, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 14835, recipeId = 1248611, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 14595, recipeId = 1248613, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 14643, recipeId = 1248610, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 14627, recipeId = 1248616, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 9268, recipeId = 1259778, recipeName = "Engineering", skillLine = "Khaz Algar Engineering", skillNeeded = 80 },
        { decorId = 16084, recipeId = 1272707, recipeName = "Engineering", skillLine = "Northrend Engineering", skillNeeded = 60 },
        { decorId = 1984, recipeId = 1259724, recipeName = "Engineering", skillLine = "Khaz Algar Engineering", skillNeeded = 80 },
        { decorId = 11718, recipeId = 1262340, recipeName = "Engineering", skillLine = "Cataclysm Engineering", skillNeeded = 60 },
        { decorId = 14730, recipeId = 1248614, recipeName = "Engineering", skillLine = "Midnight Engineering" },
        { decorId = 11882, recipeId = 1263643, recipeName = "Engineering", skillLine = "Outland Engineering", skillNeeded = 60 },
        { decorId = 4169, recipeId = 1259404, recipeName = "Engineering", skillLine = "Dragon Isles Engineering", skillNeeded = 80 },
        { decorId = 11929, recipeId = 1263237, recipeName = "Engineering", skillLine = "Dragon Isles Engineering", skillNeeded = 80 },
    },
    ["Inscription"] = {
        { decorId = 11887, recipeId = 1263810, recipeName = "Inscription", skillLine = "Outland Inscription", skillNeeded = 60 },
        { decorId = 9238, recipeId = 1260005, recipeName = "Inscription", skillLine = "Khaz Algar Inscription", skillNeeded = 80 },
        { decorId = 9239, recipeId = 1260044, recipeName = "Inscription", skillLine = "Khaz Algar Inscription", skillNeeded = 80 },
        { decorId = 11924, recipeId = 1263247, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 11917, recipeId = 1263272, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 8983, recipeId = 1260583, recipeName = "Inscription", skillLine = "Battle for Azeroth Inscription", skillNeeded = 140 },
        { decorId = 9050, recipeId = 1260596, recipeName = "Inscription", skillLine = "Battle for Azeroth Inscription", skillNeeded = 140 },
        { decorId = 854, recipeId = 1261572, recipeName = "Inscription", skillLine = "Classic Inscription", skillNeeded = 240 },
        { decorId = 922, recipeId = 1261549, recipeName = "Inscription", skillLine = "Classic Inscription", skillNeeded = 240 },
        { decorId = 11923, recipeId = 1263241, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 11927, recipeId = 1263243, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 4030, recipeId = 1260711, recipeName = "Inscription", skillLine = "Legion Inscription", skillNeeded = 80 },
        { decorId = 11885, recipeId = 1263813, recipeName = "Inscription", skillLine = "Outland Inscription", skillNeeded = 60 },
        { decorId = 11910, recipeId = 1263344, recipeName = "Inscription", skillLine = "Legion Inscription", skillNeeded = 80 },
        { decorId = 11892, recipeId = 1263575, recipeName = "Inscription", skillLine = "Northrend Inscription", skillNeeded = 60 },
        { decorId = 11895, recipeId = 1263570, recipeName = "Inscription", skillLine = "Northrend Inscription", skillNeeded = 60 },
        { decorId = 11898, recipeId = 1263564, recipeName = "Inscription", skillLine = "Northrend Inscription", skillNeeded = 60 },
        { decorId = 9180, recipeId = 1259796, recipeName = "Inscription", skillLine = "Khaz Algar Inscription", skillNeeded = 80 },
        { decorId = 14594, recipeId = 1248621, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 9241, recipeId = 1259784, recipeName = "Inscription", skillLine = "Khaz Algar Inscription", skillNeeded = 80 },
        { decorId = 9184, recipeId = 1259818, recipeName = "Inscription", skillLine = "Khaz Algar Inscription", skillNeeded = 80 },
        { decorId = 1725, recipeId = 1261032, recipeName = "Inscription", skillLine = "Draenor Inscription", skillNeeded = 80 },
        { decorId = 11886, recipeId = 1263811, recipeName = "Inscription", skillLine = "Outland Inscription", skillNeeded = 60 },
        { decorId = 14622, recipeId = 1248625, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 1217, recipeId = 1260577, recipeName = "Inscription", skillLine = "Battle for Azeroth Inscription", skillNeeded = 140 },
        { decorId = 11725, recipeId = 1269534, recipeName = "Inscription", skillLine = "Cataclysm Inscription", skillNeeded = 60 },
        { decorId = 11724, recipeId = 1269540, recipeName = "Inscription", skillLine = "Cataclysm Inscription", skillNeeded = 60 },
        { decorId = 1832, recipeId = 1261278, recipeName = "Inscription", skillLine = "Cataclysm Inscription", skillNeeded = 60 },
        { decorId = 1831, recipeId = 1261288, recipeName = "Inscription", skillLine = "Cataclysm Inscription", skillNeeded = 60 },
        { decorId = 1830, recipeId = 1261259, recipeName = "Inscription", skillLine = "Cataclysm Inscription", skillNeeded = 60 },
        { decorId = 11903, recipeId = 1263812, recipeName = "Inscription", skillLine = "Outland Inscription", skillNeeded = 60 },
        { decorId = 3871, recipeId = 1261237, recipeName = "Inscription", skillLine = "Pandaria Inscription", skillNeeded = 60 },
        { decorId = 1328, recipeId = 1248630, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 11922, recipeId = 1263293, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 14620, recipeId = 1248622, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 14621, recipeId = 1248627, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 2237, recipeId = 1261587, recipeName = "Inscription", skillLine = "Classic Inscription", skillNeeded = 240 },
        { decorId = 11897, recipeId = 1263574, recipeName = "Inscription", skillLine = "Northrend Inscription", skillNeeded = 60 },
        { decorId = 11925, recipeId = 1263278, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 4174, recipeId = 1259422, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 4175, recipeId = 1259433, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 4176, recipeId = 1259429, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 14641, recipeId = 1248623, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 4164, recipeId = 1259461, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 3839, recipeId = 1261241, recipeName = "Inscription", skillLine = "Pandaria Inscription", skillNeeded = 60 },
        { decorId = 3875, recipeId = 1261240, recipeName = "Inscription", skillLine = "Pandaria Inscription", skillNeeded = 60 },
        { decorId = 14820, recipeId = 1248631, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 9243, recipeId = 1259805, recipeName = "Inscription", skillLine = "Khaz Algar Inscription", skillNeeded = 80 },
        { decorId = 4032, recipeId = 1260719, recipeName = "Inscription", skillLine = "Legion Inscription", skillNeeded = 80 },
        { decorId = 14623, recipeId = 1248624, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 1409, recipeId = 1261066, recipeName = "Inscription", skillLine = "Draenor Inscription" },
        { decorId = 1405, recipeId = 1269500, recipeName = "Inscription", skillLine = "Draenor Inscription", skillNeeded = 80 },
        { decorId = 1351, recipeId = 1269501, recipeName = "Inscription", skillLine = "Draenor Inscription", skillNeeded = 80 },
        { decorId = 1187, recipeId = 1261238, recipeName = "Inscription", skillLine = "Pandaria Inscription", skillNeeded = 60 },
        { decorId = 9038, recipeId = 1260593, recipeName = "Inscription", skillLine = "Battle for Azeroth Inscription", skillNeeded = 140 },
        { decorId = 14731, recipeId = 1248620, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 11891, recipeId = 1263562, recipeName = "Inscription", skillLine = "Northrend Inscription", skillNeeded = 60 },
        { decorId = 14640, recipeId = 1248626, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 1169, recipeId = 1261239, recipeName = "Inscription", skillLine = "Pandaria Inscription", skillNeeded = 60 },
        { decorId = 14637, recipeId = 1248619, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 1219, recipeId = 1260737, recipeName = "Inscription", skillLine = "Legion Inscription", skillNeeded = 80 },
        { decorId = 4039, recipeId = 1260730, recipeName = "Inscription", skillLine = "Legion Inscription", skillNeeded = 80 },
        { decorId = 11880, recipeId = 1263814, recipeName = "Inscription", skillLine = "Outland Inscription", skillNeeded = 60 },
        { decorId = 1308, recipeId = 1260704, recipeName = "Inscription", skillLine = "Legion Inscription", skillNeeded = 80 },
        { decorId = 11935, recipeId = 1269495, recipeName = "Inscription", skillLine = "Classic Inscription", skillNeeded = 240 },
        { decorId = 11920, recipeId = 1263285, recipeName = "Inscription", skillLine = "Shadowlands Inscription", skillNeeded = 80 },
        { decorId = 4162, recipeId = 1259441, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 4163, recipeId = 1259451, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 16015, recipeId = 1272572, recipeName = "Inscription", skillLine = "Dragon Isles Inscription", skillNeeded = 80 },
        { decorId = 14626, recipeId = 1248628, recipeName = "Inscription", skillLine = "Midnight Inscription", skillNeeded = 50 },
        { decorId = 2240, recipeId = 1261644, recipeName = "Inscription", skillLine = "Classic Inscription", skillNeeded = 240 },
        { decorId = 1411, recipeId = 1261045, recipeName = "Inscription", skillLine = "Draenor Inscription", skillNeeded = 80 },
        { decorId = 1313, recipeId = 1260564, recipeName = "Inscription", skillLine = "Battle for Azeroth Inscription", skillNeeded = 140 },
        { decorId = 1312, recipeId = 1260508, recipeName = "Inscription", skillLine = "Battle for Azeroth Inscription", skillNeeded = 140 },
    },
    ["Jewelcrafting"] = {
        { decorId = 14601, recipeId = 1246891, recipeName = "Jewelcrafting", skillLine = "Midnight Jewelcrafting", skillNeeded = 50 },
        { decorId = 2230, recipeId = 1261667, recipeName = "Jewelcrafting", skillLine = "Classic Jewelcrafting", skillNeeded = 240 },
        { decorId = 14599, recipeId = 1246895, recipeName = "Jewelcrafting", skillLine = "Midnight Jewelcrafting", skillNeeded = 80 },
        { decorId = 14553, recipeId = 1269496, recipeName = "Jewelcrafting", skillLine = "Outland Jewelcrafting", skillNeeded = 60 },
        { decorId = 8241, recipeId = 1261075, recipeName = "Jewelcrafting", skillLine = "Draenor Jewelcrafting", skillNeeded = 80 },
        { decorId = 8196, recipeId = 1261071, recipeName = "Jewelcrafting", skillLine = "Draenor Jewelcrafting", skillNeeded = 80 },
        { decorId = 9269, recipeId = 1260172, recipeName = "Jewelcrafting", skillLine = "Khaz Algar Jewelcrafting", skillNeeded = 80 },
        { decorId = 2331, recipeId = 1261659, recipeName = "Jewelcrafting", skillLine = "Classic Jewelcrafting", skillNeeded = 240 },
        { decorId = 3876, recipeId = 1261242, recipeName = "Jewelcrafting", skillLine = "Pandaria Jewelcrafting", skillNeeded = 60 },
        { decorId = 11899, recipeId = 1263577, recipeName = "Jewelcrafting" },
        { decorId = 11896, recipeId = 1263605, recipeName = "Jewelcrafting", skillLine = "Northrend Jewelcrafting", skillNeeded = 60 },
        { decorId = 14676, recipeId = 1269502, recipeName = "Jewelcrafting", skillLine = "Shadowlands Jewelcrafting", skillNeeded = 80 },
        { decorId = 14380, recipeId = 1269504, recipeName = "Jewelcrafting", skillLine = "Shadowlands Jewelcrafting", skillNeeded = 80 },
        { decorId = 1748, recipeId = 1260096, recipeName = "Jewelcrafting", skillLine = "Khaz Algar Jewelcrafting", skillNeeded = 80 },
        { decorId = 3868, recipeId = 1261244, recipeName = "Jewelcrafting", skillLine = "Pandaria Jewelcrafting", skillNeeded = 60 },
        { decorId = 1194, recipeId = 1261243, recipeName = "Jewelcrafting", skillLine = "Pandaria Jewelcrafting", skillNeeded = 60 },
        { decorId = 14638, recipeId = 1246893, recipeName = "Jewelcrafting", skillLine = "Midnight Jewelcrafting", skillNeeded = 50 },
        { decorId = 5133, recipeId = 1246892, recipeName = "Jewelcrafting", skillLine = "Midnight Jewelcrafting", skillNeeded = 50 },
        { decorId = 1746, recipeId = 1260757, recipeName = "Jewelcrafting", skillLine = "Legion Jewelcrafting", skillNeeded = 80 },
        { decorId = 11889, recipeId = 1263815, recipeName = "Jewelcrafting", skillLine = "Outland Jewelcrafting", skillNeeded = 60 },
        { decorId = 11888, recipeId = 1263817, recipeName = "Jewelcrafting", skillLine = "Outland Jewelcrafting", skillNeeded = 60 },
        { decorId = 14584, recipeId = 1246894, recipeName = "Jewelcrafting", skillLine = "Midnight Jewelcrafting", skillNeeded = 50 },
        { decorId = 1161, recipeId = 1260501, recipeName = "Jewelcrafting", skillLine = "Battle for Azeroth Jewelcrafting", skillNeeded = 140 },
        { decorId = 11496, recipeId = 1262357, recipeName = "Jewelcrafting", skillLine = "Cataclysm Jewelcrafting", skillNeeded = 60 },
        { decorId = 5342, recipeId = 1261305, recipeName = "Jewelcrafting", skillLine = "Cataclysm Jewelcrafting", skillNeeded = 60 },
        { decorId = 11913, recipeId = 1263351, recipeName = "Jewelcrafting", skillLine = "Legion Jewelcrafting", skillNeeded = 80 },
        { decorId = 14591, recipeId = 1246889, recipeName = "Jewelcrafting", skillLine = "Midnight Jewelcrafting", skillNeeded = 80 },
        { decorId = 4165, recipeId = 1259384, recipeName = "Jewelcrafting", skillLine = "Dragon Isles Jewelcrafting", skillNeeded = 80 },
        { decorId = 4166, recipeId = 1259386, recipeName = "Jewelcrafting", skillLine = "Dragon Isles Jewelcrafting", skillNeeded = 80 },
        { decorId = 4480, recipeId = 1259369, recipeName = "Jewelcrafting", skillLine = "Dragon Isles Jewelcrafting", skillNeeded = 80 },
        { decorId = 1200, recipeId = 1260492, recipeName = "Jewelcrafting", skillLine = "Battle for Azeroth Jewelcrafting", skillNeeded = 140 },
    },
    ["Junkyard Tinkering"] = {
        { decorId = 2325, recipeId = 1243788, recipeName = "Junkyard Tinkering", skillLine = "Junkyard Tinkering", skillNeeded = 1 },
        { decorId = 2328, recipeId = 1243803, recipeName = "Junkyard Tinkering", skillLine = "Junkyard Tinkering", skillNeeded = 1 },
        { decorId = 2427, recipeId = 1243783, recipeName = "Junkyard Tinkering", skillLine = "Junkyard Tinkering", skillNeeded = 1 },
        { decorId = 2428, recipeId = 1243780, recipeName = "Junkyard Tinkering", skillLine = "Junkyard Tinkering", skillNeeded = 1 },
        { decorId = 2429, recipeId = 1243793, recipeName = "Junkyard Tinkering", skillLine = "Junkyard Tinkering", skillNeeded = 1 },
        { decorId = 2438, recipeId = 1243801, recipeName = "Junkyard Tinkering", skillLine = "Junkyard Tinkering", skillNeeded = 1 },
    },
    ["Leatherworking"] = {
        { decorId = 11879, recipeId = 1263818, recipeName = "Leatherworking", skillLine = "Outland Leatherworking", skillNeeded = 60 },
        { decorId = 1321, recipeId = 1261081, recipeName = "Leatherworking", skillLine = "Draenor Leatherworking", skillNeeded = 80 },
        { decorId = 11755, recipeId = 1263633, recipeName = "Leatherworking", skillLine = "Classic Leatherworking", skillNeeded = 240 },
        { decorId = 4170, recipeId = 1259195, recipeName = "Leatherworking", skillLine = "Dragon Isles Leatherworking", skillNeeded = 80 },
        { decorId = 14579, recipeId = 1246937, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 80 },
        { decorId = 16089, recipeId = 1272580, recipeName = "Leatherworking", skillLine = "Cataclysm Leatherworking", skillNeeded = 60 },
        { decorId = 17515, recipeId = 1246939, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 50 },
        { decorId = 11490, recipeId = 1262273, recipeName = "Leatherworking", skillLine = "Legion Leatherworking", skillNeeded = 80 },
        { decorId = 1142, recipeId = 1246938, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 80 },
        { decorId = 1119, recipeId = 1261672, recipeName = "Leatherworking", skillLine = "Classic Leatherworking", skillNeeded = 240 },
        { decorId = 11919, recipeId = 1263313, recipeName = "Leatherworking", skillLine = "Shadowlands Leatherworking", skillNeeded = 80 },
        { decorId = 11926, recipeId = 1263308, recipeName = "Leatherworking", skillLine = "Shadowlands Leatherworking", skillNeeded = 80 },
        { decorId = 1415, recipeId = 1261122, recipeName = "Leatherworking", skillLine = "Draenor Leatherworking", skillNeeded = 80 },
        { decorId = 11878, recipeId = 1263819, recipeName = "Leatherworking", skillLine = "Outland Leatherworking", skillNeeded = 60 },
        { decorId = 15479, recipeId = 1246943, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 50 },
        { decorId = 16013, recipeId = 1272588, recipeName = "Leatherworking", skillLine = "Cataclysm Leatherworking", skillNeeded = 60 },
        { decorId = 12162, recipeId = 1263859, recipeName = "Leatherworking", skillLine = "Battle for Azeroth Leatherworking", skillNeeded = 140 },
        { decorId = 11779, recipeId = 1269550, recipeName = "Leatherworking", skillLine = "Cataclysm Leatherworking", skillNeeded = 60 },
        { decorId = 3994, recipeId = 1261245, recipeName = "Leatherworking", skillLine = "Pandaria Leatherworking", skillNeeded = 60 },
        { decorId = 14615, recipeId = 1246940, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 80 },
        { decorId = 11722, recipeId = 1269499, recipeName = "Leatherworking", skillLine = "Northrend Leatherworking", skillNeeded = 60 },
        { decorId = 14625, recipeId = 1246941, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 50 },
        { decorId = 1157, recipeId = 1246942, recipeName = "Leatherworking", skillLine = "Midnight Leatherworking", skillNeeded = 50 },
        { decorId = 1243, recipeId = 1260765, recipeName = "Leatherworking", skillLine = "Legion Leatherworking", skillNeeded = 80 },
        { decorId = 1242, recipeId = 1260762, recipeName = "Leatherworking", skillLine = "Legion Leatherworking", skillNeeded = 80 },
        { decorId = 4483, recipeId = 1259233, recipeName = "Leatherworking", skillLine = "Dragon Isles Leatherworking", skillNeeded = 80 },
        { decorId = 829, recipeId = 1270836, recipeName = "Leatherworking", skillLine = "Khaz Algar Leatherworking", skillNeeded = 80 },
        { decorId = 3904, recipeId = 1261248, recipeName = "Leatherworking", skillLine = "Pandaria Leatherworking", skillNeeded = 60 },
        { decorId = 11893, recipeId = 1263613, recipeName = "Leatherworking", skillLine = "Northrend Leatherworking", skillNeeded = 60 },
        { decorId = 1241, recipeId = 1260485, recipeName = "Leatherworking", skillLine = "Battle for Azeroth Leatherworking", skillNeeded = 140 },
        { decorId = 1273, recipeId = 1260328, recipeName = "Leatherworking", skillLine = "Khaz Algar Leatherworking", skillNeeded = 80 },
    },
    ["Tailoring"] = {
        { decorId = 8237, recipeId = 1261231, recipeName = "Tailoring", skillLine = "Draenor Tailoring", skillNeeded = 80 },
        { decorId = 16014, recipeId = 1272578, recipeName = "Tailoring", skillLine = "Shadowlands Tailoring", skillNeeded = 80 },
        { decorId = 11946, recipeId = 1263360, recipeName = "Tailoring", skillLine = "Draenor Tailoring", skillNeeded = 80 },
        { decorId = 12161, recipeId = 1263858, recipeName = "Tailoring", skillLine = "Legion Tailoring", skillNeeded = 80 },
        { decorId = 14619, recipeId = 1246919, recipeName = "Tailoring", skillLine = "Midnight Tailoring", skillNeeded = 50 },
        { decorId = 4034, recipeId = 1260774, recipeName = "Tailoring", skillLine = "Legion Tailoring", skillNeeded = 80 },
        { decorId = 9167, recipeId = 1260215, recipeName = "Tailoring", skillLine = "Khaz Algar Tailoring", skillNeeded = 80 },
        { decorId = 4177, recipeId = 1259247, recipeName = "Tailoring", skillLine = "Dragon Isles Tailoring", skillNeeded = 80 },
        { decorId = 11883, recipeId = 1263692, recipeName = "Tailoring", skillLine = "Outland Tailoring", skillNeeded = 60 },
        { decorId = 2452, recipeId = 1261695, recipeName = "Tailoring", skillLine = "Classic Tailoring", skillNeeded = 240 },
        { decorId = 1282, recipeId = 1261688, recipeName = "Tailoring", skillLine = "Classic Tailoring", skillNeeded = 240 },
        { decorId = 11894, recipeId = 1263620, recipeName = "Tailoring", skillLine = "Northrend Tailoring", skillNeeded = 60 },
        { decorId = 11890, recipeId = 1263669, recipeName = "Tailoring", skillLine = "Outland Tailoring", skillNeeded = 60 },
        { decorId = 16090, recipeId = 1272575, recipeName = "Tailoring", skillLine = "Shadowlands Tailoring", skillNeeded = 80 },
        { decorId = 929, recipeId = 1261232, recipeName = "Tailoring", skillLine = "Draenor Tailoring", skillNeeded = 80 },
        { decorId = 11941, recipeId = 1263627, recipeName = "Tailoring", skillLine = "Northrend Tailoring", skillNeeded = 60 },
        { decorId = 12165, recipeId = 1263853, recipeName = "Tailoring", skillLine = "Shadowlands Tailoring", skillNeeded = 80 },
        { decorId = 14555, recipeId = 1229001, recipeName = "Tailoring", skillLine = "Midnight Tailoring", skillNeeded = 50 },
        { decorId = 14617, recipeId = 1229002, recipeName = "Tailoring", skillLine = "Midnight Tailoring", skillNeeded = 50 },
        { decorId = 11945, recipeId = 1263553, recipeName = "Tailoring", skillLine = "Pandaria Tailoring", skillNeeded = 60 },
        { decorId = 3878, recipeId = 1261250, recipeName = "Tailoring", skillLine = "Pandaria Tailoring", skillNeeded = 60 },
        { decorId = 14618, recipeId = 1229003, recipeName = "Tailoring", skillLine = "Midnight Tailoring", skillNeeded = 50 },
        { decorId = 1168, recipeId = 1260458, recipeName = "Tailoring", skillLine = "Battle for Azeroth Tailoring", skillNeeded = 140 },
        { decorId = 4041, recipeId = 1260769, recipeName = "Tailoring", skillLine = "Legion Tailoring", skillNeeded = 80 },
        { decorId = 14624, recipeId = 1229000, recipeName = "Tailoring", skillLine = "Midnight Tailoring", skillNeeded = 50 },
        { decorId = 1827, recipeId = 1261317, recipeName = "Tailoring", skillLine = "Cataclysm Tailoring", skillNeeded = 60 },
        { decorId = 11388, recipeId = 1261940, recipeName = "Tailoring", skillLine = "Dragon Isles Tailoring", skillNeeded = 80 },
        { decorId = 1275, recipeId = 1260326, recipeName = "Tailoring", skillLine = "Khaz Algar Tailoring", skillNeeded = 80 },
        { decorId = 11492, recipeId = 1262370, recipeName = "Tailoring", skillLine = "Cataclysm Tailoring", skillNeeded = 60 },
        { decorId = 14636, recipeId = 1246929, recipeName = "Tailoring", skillLine = "Midnight Tailoring", skillNeeded = 50 },
        { decorId = 1311, recipeId = 1260475, recipeName = "Tailoring", skillLine = "Battle for Azeroth Tailoring", skillNeeded = 140 },
    },
}

CodexData.DropSourceData = {
    ["drop"] = {
        { sourceName = "Darkshore (BfA phase) Rare Drop", decorIds = {840, 948, 1836, 2000} },
        { sourceName = "Highmountain Tauren Paragon Chest", decorIds = {11754} },
        { sourceName = "Login Reward (Midnight)", decorIds = {14467} },
        { sourceName = "Midnight Delves", decorIds = {8889, 14822, 14828, 15064, 15493, 15567, 15568, 15582, 18485} },
        { sourceName = "Self-Assembling Homeware Kit (Mechagon)", decorIds = {2324, 2431, 2432, 2434} },
        { sourceName = "Shadowmoon Valley (Draenor) Missives", decorIds = {8176} },
        { sourceName = "Strange Recycling Requisition (Mechagon)", decorIds = {11814} },
        { sourceName = "Theater Troupe event chest (Isle of Dorn)", decorIds = {764} },
        { sourceName = "Twitch Drop", decorIds = {15151} },
        { sourceName = "Undermine Jobs", decorIds = {1261} },
        { sourceName = "Zillow for Warcraft Promotion", decorIds = {15668} },
    },
    ["encounter"] = {
        { sourceName = "Advisor Melandrus (Court of Stars)", decorIds = {4027} },
        { sourceName = "Belo'ren, Child of Al'ar", decorIds = {15467} },
        { sourceName = "Charonus (Voidscar Arena)", decorIds = {15574} },
        { sourceName = "Chimaerus the Undreamt God", decorIds = {15481, 17629, 18397, 19197} },
        { sourceName = "Crown of the Cosmos (The Voidspire)", decorIds = {15764, 17630, 18398, 19252, 20632} },
        { sourceName = "Dargrul the Underking", decorIds = {1232} },
        { sourceName = "Degentrius (Magisters' Terrace)", decorIds = {15061} },
        { sourceName = "Echo of Doragosa (Algeth'ar Academy)", decorIds = {14330} },
        { sourceName = "Emperor Dagran Thaurissan (Blackrock Depths)", decorIds = {2246} },
        { sourceName = "Fallen-King Salhadaar (The Voidspire)", decorIds = {15758} },
        { sourceName = "Garrosh Hellscream (Siege of Orgrimmar)", decorIds = {9263} },
        { sourceName = "Goldie Baronbottom (Cinderbrew Meadery)", decorIds = {1749} },
        { sourceName = "Harlan Sweete (Freehold)", decorIds = {2238} },
        { sourceName = "High Sage Viryx (Skyreach)", decorIds = {12204} },
        { sourceName = "Imperator Averzian (The Voidspire)", decorIds = {15761} },
        { sourceName = "King Mechagon", decorIds = {10887} },
        { sourceName = "Kyrakka and Erkhart Stormvein", decorIds = {11163} },
        { sourceName = "L'ura (The Seat of the Triumvirate)", decorIds = {926} },
        { sourceName = "Lightblinded Vanguard", decorIds = {14806} },
        { sourceName = "Lithiel Cinderfury (Murder Row)", decorIds = {15069} },
        { sourceName = "Lord Godfrey (Shadowfang Keep)", decorIds = {1445} },
        { sourceName = "Lothraxion (Nexus-Point Xenas)", decorIds = {15576} },
        { sourceName = "Midnight Falls (March on Quel'Danas)", decorIds = {15756, 17628, 18396, 19198} },
        { sourceName = "Nalorakk", decorIds = {15570} },
        { sourceName = "Prioress Murrpray (Priory of the Sacred Flame)", decorIds = {1893} },
        { sourceName = "Rak'tul, Vessel of Souls", decorIds = {16094} },
        { sourceName = "Scourgelord Tyrannus (Pit of Saron)", decorIds = {18483} },
        { sourceName = "Sha of Doubt (Temple of the Jade Serpent)", decorIds = {2512} },
        { sourceName = "Shade of Xavius (Darkheart Thicket)", decorIds = {673} },
        { sourceName = "Skulloc (Iron Docks)", decorIds = {1323} },
        { sourceName = "Spellblade Aluriel (The Nighthold)", decorIds = {11283} },
        { sourceName = "Teron'gor", decorIds = {8178} },
        { sourceName = "The Darkness", decorIds = {11934} },
        { sourceName = "The Restless Cabal", decorIds = {18484} },
        { sourceName = "The Restless Heart", decorIds = {11284} },
        { sourceName = "Vaelgor & Ezzorak", decorIds = {15755} },
        { sourceName = "Vanessa VanCleef", decorIds = {4401} },
        { sourceName = "Viz'aduum the Watcher (Karazhan)", decorIds = {2531} },
        { sourceName = "Vol'zith the Whisperer (Shrine of the Storm)", decorIds = {1880} },
        { sourceName = "Vorasius (The Voidspire)", decorIds = {15762} },
        { sourceName = "Warlord Sargha (Neltharus)", decorIds = {11137} },
        { sourceName = "Warlord Zaela", decorIds = {1324} },
        { sourceName = "Ziekket (The Blinding Vale)", decorIds = {1137} },
    },
    ["treasure"] = {
        { sourceName = "Gift of the Phoenix (Eversong Woods)", decorIds = {14977} },
        { sourceName = "Golden Cloud Serpent Treasure Chest (Jade Forest)", decorIds = {5111} },
        { sourceName = "Incomplete Book of Sonnets (Eversong Woods)", decorIds = {1195} },
        { sourceName = "Malignant Chest (Voidstorm)", decorIds = {15746} },
        { sourceName = "Stellar Stash (Slayer's Rise)", decorIds = {14597} },
        { sourceName = "Stone Vat (Eversong Woods)", decorIds = {8875} },
        { sourceName = "Triple-Locked Safebox (Eversong Woods)", decorIds = {1173} },
        { sourceName = "Undermine", decorIds = {1272} },
        { sourceName = "World Glimmering Treasure Chest Drop", decorIds = {674} },
    },
}

CodexData.QuestSourceData = {
    ["Amirdrassil"] = {
        { questId = 78864, questName = "The Returning", decorIds = {7896} },
    },
    ["Arcantina"] = {
        { questId = 92322, questName = "Timear Foresees a Proof of Demise!", decorIds = {9250} },
        { questId = 92321, questName = "A Frostbitten Tally", decorIds = {9475} },
        { questId = 92327, questName = "A Generational Moment", decorIds = {9248, 9440} },
        { questId = 92323, questName = "Where the Fire Once Burned", decorIds = {9249} },
        { questId = 92320, questName = "Still Behind Enemy Portals", decorIds = {9252} },
        { questId = 92326, questName = "The Fragrance of the Dunes", decorIds = {9253, 9624} },
        { questId = 92324, questName = "Uncrowned's Cold Case", decorIds = {9251} },
        { questId = 92319, questName = "A Favor to Axe", decorIds = {9439} },
        { questId = 92325, questName = "Hellscream's Heritage", decorIds = {9441} },
    },
    ["Azsuna"] = {
        { questId = 37470, questName = "The Head of the Snake", decorIds = {2530} },
    },
    ["Blackrock Depths"] = {
        { questId = 53566, questName = "Dark Iron Dwarves", decorIds = {1118} },
        { questId = 54, questName = "Report to Goldshire", decorIds = {4815} },
        { questId = 26390, questName = "Ending the Invasion!", decorIds = {4447} },
        { questId = 7604, questName = "A Binding Contract", decorIds = {11274} },
    },
    ["Boralus Harbor"] = {
        { questId = 53720, questName = "Allegiance of Kul Tiras", decorIds = {9052} },
    },
    ["Borean Tundra"] = {
        { questId = 11566, questName = "Surrender... Not!", decorIds = {11906} },
    },
    ["Burning Steppes"] = {
        { questId = nil, questName = "Return to Keeshan", decorIds = {11131} },
    },
    ["Dalaran"] = {
        { questId = 92322, questName = "Timear Foresees a Proof of Demise!", decorIds = {9250} },
        { questId = nil, questName = "Cheese for Glowergold", decorIds = {11872} },
        { questId = 44004, questName = "Bringer of the Light", decorIds = {8189} },
    },
    ["Dornogal"] = {
        { questId = nil, questName = "Spare A Chair", decorIds = {2330} },
        { questId = 92572, questName = "Furniture Favor", decorIds = {9247} },
        { questId = nil, questName = "Dreamy Inspiration", decorIds = {1693} },
        { questId = nil, questName = "Last Light", decorIds = {4029} },
        { questId = nil, questName = "Draconic Decor", decorIds = {4172} },
    },
    ["Drustvar"] = {
        { questId = 51985, questName = "Return to Zuldazar", decorIds = {935} },
    },
    ["Duskwood"] = {
        { questId = 26754, questName = "Morbent's Bane", decorIds = {11305} },
        { questId = 26760, questName = "Cry For The Moon", decorIds = {1833} },
    },
    ["Dustwallow Marsh"] = {
        { questId = 55045, questName = "My Brother's Keeper", decorIds = {9166} },
    },
    ["Elwynn Forest"] = {
        { questId = 114, questName = "The Escape", decorIds = {9424} },
        { questId = 60, questName = "Kobold Candles", decorIds = {5115} },
        { questId = 54, questName = "Report to Goldshire", decorIds = {4815} },
        { questId = 26390, questName = "Ending the Invasion!", decorIds = {4447} },
    },
    ["Emerald Dream"] = {
        { questId = 77283, questName = "A Multi-Front Battle", decorIds = {11454} },
    },
    ["Eredath"] = {
        { questId = 47691, questName = "A Non-Prophet Organization", decorIds = {930} },
    },
    ["Eversong Woods"] = {
        { questId = 90493, questName = "The Heart of Tranquillien", decorIds = {1159, 1160} },
        { questId = 90907, questName = "The First to Know", decorIds = {1489} },
        { questId = 86741, questName = "Lightbloom Looming", decorIds = {1908} },
        { questId = 92025, questName = "Flowers for Amalthea", decorIds = {11499} },
    },
    ["Felwood"] = {
        { questId = 28337, questName = "The Shredders of Irontree", decorIds = {11301} },
        { questId = 76213, questName = "Honor of the Goddess", decorIds = {4423} },
    },
    ["Founder's Point"] = {
        { questId = 92991, questName = "Decor Treasure Hunt", decorIds = {2109} },
        { questId = 92992, questName = "Decor Treasure Hunt", decorIds = {1772} },
        { questId = 92994, questName = "Decor Treasure Hunt", decorIds = {1770} },
        { questId = 93009, questName = "Decor Treasure Hunt", decorIds = {2110} },
        { questId = 92993, questName = "Decor Treasure Hunt", decorIds = {1771} },
        { questId = 92990, questName = "Decor Treasure Hunt", decorIds = {2113} },
        { questId = 92999, questName = "Decor Treasure Hunt", decorIds = {1878} },
        { questId = 92971, questName = "Decor Treasure Hunt", decorIds = {1994} },
        { questId = 92996, questName = "Decor Treasure Hunt", decorIds = {2342} },
        { questId = 93004, questName = "Decor Treasure Hunt", decorIds = {1486} },
        { questId = 92983, questName = "Decor Treasure Hunt", decorIds = {496} },
        { questId = 93002, questName = "Decor Treasure Hunt", decorIds = {1162} },
        { questId = 93003, questName = "Decor Treasure Hunt", decorIds = {11719} },
        { questId = 93000, questName = "Decor Treasure Hunt", decorIds = {985} },
        { questId = 92995, questName = "Decor Treasure Hunt", decorIds = {10860} },
        { questId = 93001, questName = "Decor Treasure Hunt", decorIds = {1488} },
        { questId = 93007, questName = "Decor Treasure Hunt", decorIds = {9255} },
        { questId = 92963, questName = "Decor Treasure Hunt", decorIds = {389} },
        { questId = 93005, questName = "Decor Treasure Hunt", decorIds = {994} },
        { questId = 92977, questName = "Decor Treasure Hunt", decorIds = {1739} },
        { questId = 92980, questName = "Decor Treasure Hunt", decorIds = {1745} },
        { questId = 92998, questName = "Decor Treasure Hunt", decorIds = {1992} },
        { questId = 92997, questName = "Decor Treasure Hunt", decorIds = {1997} },
        { questId = 93008, questName = "Decor Treasure Hunt", decorIds = {80} },
        { questId = 92978, questName = "Decor Treasure Hunt", decorIds = {1280} },
        { questId = 92989, questName = "Decor Treasure Hunt", decorIds = {9471} },
        { questId = 93006, questName = "Decor Treasure Hunt", decorIds = {1153} },
        { questId = 92972, questName = "Decor Treasure Hunt", decorIds = {1993} },
        { questId = 92973, questName = "Decor Treasure Hunt", decorIds = {1991} },
        { questId = 92976, questName = "Decor Treasure Hunt", decorIds = {2099} },
        { questId = 92967, questName = "Decor Treasure Hunt", decorIds = {530} },
        { questId = 92966, questName = "Decor Treasure Hunt", decorIds = {528} },
        { questId = 92968, questName = "Decor Treasure Hunt", decorIds = {529} },
        { questId = 92974, questName = "Decor Treasure Hunt", decorIds = {2101} },
        { questId = 92975, questName = "Decor Treasure Hunt", decorIds = {2100} },
        { questId = 92982, questName = "Decor Treasure Hunt", decorIds = {1435} },
        { questId = 92984, questName = "Decor Treasure Hunt", decorIds = {495} },
        { questId = 92969, questName = "Decor Treasure Hunt", decorIds = {1122} },
        { questId = 92437, questName = "Decor Treasure Hunt", decorIds = {373} },
        { questId = 92965, questName = "Decor Treasure Hunt", decorIds = {494} },
        { questId = 92962, questName = "Decor Treasure Hunt", decorIds = {378} },
        { questId = 92961, questName = "Decor Treasure Hunt", decorIds = {374} },
        { questId = 92964, questName = "Decor Treasure Hunt", decorIds = {390} },
        { questId = 92970, questName = "Decor Treasure Hunt", decorIds = {2496} },
        { questId = 92988, questName = "Decor Treasure Hunt", decorIds = {377} },
        { questId = 92979, questName = "Decor Treasure Hunt", decorIds = {1123} },
        { questId = 92981, questName = "Decor Treasure Hunt", decorIds = {1738} },
        { questId = 92985, questName = "Decor Treasure Hunt", decorIds = {1996} },
        { questId = 92986, questName = "Decor Treasure Hunt", decorIds = {726} },
        { questId = 92987, questName = "Decor Treasure Hunt", decorIds = {383} },
    },
    ["Frostfire Ridge"] = {
        { questId = nil, questName = "Last Steps", decorIds = {1318} },
        { questId = 34586, questName = "Establish Your Garrison", decorIds = {1353} },
        { questId = 36592, questName = "Bigger is Better", decorIds = {1443} },
        { questId = 36614, questName = "My Very Own Fortress", decorIds = {1407} },
        { questId = nil, questName = "Pool of Visions", decorIds = {1412} },
    },
    ["Frostwall"] = {
        { questId = 34586, questName = "Establish Your Garrison", decorIds = {1353} },
        { questId = 36592, questName = "Bigger is Better", decorIds = {1443} },
        { questId = 36614, questName = "My Very Own Fortress", decorIds = {1407} },
        { questId = 34192, questName = "Things Are Not Goren Our Way", decorIds = {1408} },
    },
    ["Gilneas"] = {
        { questId = 14402, questName = "Ready to Go", decorIds = {1829} },
        { questId = 24675, questName = "Last Meal", decorIds = {858} },
    },
    ["Grizzly Hills"] = {
        { questId = 12227, questName = "Doing Your Duty", decorIds = {4448} },
    },
    ["Harandar"] = {
        { questId = nil, questName = "The Foundation of Aln", decorIds = {17886} },
        { questId = nil, questName = "The Cauldron of Echoes", decorIds = {15155} },
        { questId = nil, questName = "Herding Manifestations", decorIds = {8993} },
        { questId = nil, questName = "Russula's Outreach", decorIds = {14799} },
        { questId = nil, questName = "Root Dash Delivery", decorIds = {15463} },
        { questId = nil, questName = "Aln'hara's Bloom", decorIds = {14968} },
        { questId = nil, questName = "The Traveling Flowers", decorIds = {14639} },
        { questId = nil, questName = "The Echoless Flame", decorIds = {15497} },
        { questId = nil, questName = "Root of the World", decorIds = {14827} },
        { questId = nil, questName = "Sky's Hope", decorIds = {1080} },
        { questId = nil, questName = "Wey'nan's Ward", decorIds = {14823} },
        { questId = nil, questName = "Can We Heal This?", decorIds = {10327} },
        { questId = nil, questName = "A Last Resort", decorIds = {10778} },
        { questId = nil, questName = "Echoes and Memories", decorIds = {2232} },
        { questId = nil, questName = "Light Finds a Way", decorIds = {2605} },
        { questId = nil, questName = "Into the Lightbloom", decorIds = {1147} },
        { questId = nil, questName = "Descent into the Rift", decorIds = {2224} },
        { questId = nil, questName = "Halting Harm in Har'mara", decorIds = {1726} },
        { questId = nil, questName = "From this Point Forward", decorIds = {14809} },
    },
    ["Highmountain"] = {
        { questId = 40230, questName = "Oh, the Clawdacity!", decorIds = {11907} },
        { questId = 39487, questName = "Crystal Fury", decorIds = {15741} },
        { questId = 39496, questName = "The Flow of the River", decorIds = {1309} },
        { questId = 39426, questName = "Blood Debt", decorIds = {11752} },
        { questId = 39772, questName = "Can't Hold a Candle To You", decorIds = {14379} },
        { questId = 42622, questName = "Ceremonial Drums", decorIds = {1251} },
        { questId = 39614, questName = "Fish Out of Water", decorIds = {1294} },
        { questId = 39387, questName = "The Skies of Highmountain", decorIds = {11491} },
        { questId = 39305, questName = "Empty Nest", decorIds = {11753} },
        { questId = 39992, questName = "Huln's War - The Nathrezim", decorIds = {11487} },
        { questId = 39780, questName = "The Underking", decorIds = {1291} },
        { questId = 39579, questName = "The Backdoor", decorIds = {1287} },
        { questId = 42590, questName = "Moozy's Reunion", decorIds = {1235} },
    },
    ["Isle of Dorn"] = {
        { questId = 79565, questName = "Janky Candles", decorIds = {11933} },
        { questId = 82895, questName = "The Weight of Duty", decorIds = {9182} },
        { questId = 78999, questName = "Heart of a Hero", decorIds = {9179} },
        { questId = 78759, questName = "To Wake a Giant", decorIds = {9240} },
        { questId = 79703, questName = "Hope, An Anomaly", decorIds = {9183} },
    },
    ["Kun-Lai Summit"] = {
        { questId = 30612, questName = "The Leader Hozen", decorIds = {15595} },
        { questId = 32816, questName = "Path of the Last Emperor", decorIds = {3995} },
    },
    ["Loch Modan"] = {
        { questId = 26868, questName = "Axis of Awful", decorIds = {2239} },
    },
    ["Lunarfall"] = {
        { questId = 36615, questName = "My Very Own Castle", decorIds = {4818} },
        { questId = 36592, questName = "Bigger is Better", decorIds = {4486} },
        { questId = 35176, questName = "Keeping it Together", decorIds = {4844} },
        { questId = 36404, questName = "Clearing the Garden", decorIds = {4403} },
        { questId = 34192, questName = "Things Are Not Goren Our Way", decorIds = {4485} },
        { questId = 34586, questName = "Establish Your Garrison", decorIds = {4816} },
    },
    ["Mechagon"] = {
        { questId = 55736, questName = "Welcome to the Resistance", decorIds = {2467} },
    },
    ["Mulgore"] = {
        { questId = 26397, questName = "Walk With The Earth Mother", decorIds = {1281} },
    },
    ["Nagrand"] = {
        { questId = 35396, questName = "The Dark Heart of Oshu'gun", decorIds = {928} },
    },
    ["Nazmir"] = {
        { questId = 50808, questName = "Halting the Empire's Fall", decorIds = {1179} },
        { questId = 47188, questName = "The Aid of the Loa", decorIds = {1170} },
        { questId = 47250, questName = "We'll Meet Again", decorIds = {1192} },
    },
    ["Northshire"] = {
        { questId = 54, questName = "Report to Goldshire", decorIds = {4815} },
        { questId = 26390, questName = "Ending the Invasion!", decorIds = {4447} },
    },
    ["Orgrimmar"] = {
        { questId = nil, questName = "Spare A Chair", decorIds = {2330} },
        { questId = 92572, questName = "Furniture Favor", decorIds = {9247} },
        { questId = nil, questName = "Dreamy Inspiration", decorIds = {1693} },
        { questId = nil, questName = "Last Light", decorIds = {4029} },
        { questId = nil, questName = "Draconic Decor", decorIds = {4172} },
    },
    ["Razorwind Shores"] = {
        { questId = 93147, questName = "Decor Treasure Hunt", decorIds = {1163} },
        { questId = 93105, questName = "Decor Treasure Hunt", decorIds = {2549} },
        { questId = 93084, questName = "Decor Treasure Hunt", decorIds = {1737} },
        { questId = 93148, questName = "Decor Treasure Hunt", decorIds = {1356} },
        { questId = 93151, questName = "Decor Treasure Hunt", decorIds = {11721} },
        { questId = 93141, questName = "Decor Treasure Hunt", decorIds = {8917} },
        { questId = 93143, questName = "Decor Treasure Hunt", decorIds = {984} },
        { questId = 93149, questName = "Decor Treasure Hunt", decorIds = {1329} },
        { questId = 93150, questName = "Decor Treasure Hunt", decorIds = {987} },
        { questId = 93108, questName = "Decor Treasure Hunt", decorIds = {8907} },
        { questId = 93091, questName = "Decor Treasure Hunt", decorIds = {1977} },
        { questId = 93104, questName = "Decor Treasure Hunt", decorIds = {2546} },
        { questId = 93102, questName = "Decor Treasure Hunt", decorIds = {7842} },
        { questId = 93078, questName = "Decor Treasure Hunt", decorIds = {1437} },
        { questId = 93098, questName = "Decor Treasure Hunt", decorIds = {2088} },
        { questId = 93079, questName = "Decor Treasure Hunt", decorIds = {1438} },
        { questId = 93080, questName = "Decor Treasure Hunt", decorIds = {1700} },
        { questId = 93099, questName = "Decor Treasure Hunt", decorIds = {2093} },
        { questId = 93133, questName = "Decor Treasure Hunt", decorIds = {2548} },
        { questId = 93134, questName = "Decor Treasure Hunt", decorIds = {4562} },
        { questId = 93142, questName = "Decor Treasure Hunt", decorIds = {11720} },
        { questId = 93085, questName = "Decor Treasure Hunt", decorIds = {2114} },
        { questId = 93109, questName = "Decor Treasure Hunt", decorIds = {1879} },
        { questId = 93081, questName = "Decor Treasure Hunt", decorIds = {1723} },
        { questId = 93073, questName = "Decor Treasure Hunt", decorIds = {523} },
        { questId = 93074, questName = "Decor Treasure Hunt", decorIds = {524} },
        { questId = 93088, questName = "Decor Treasure Hunt", decorIds = {2116} },
        { questId = 93083, questName = "Decor Treasure Hunt", decorIds = {1736} },
        { questId = 93075, questName = "Decor Treasure Hunt", decorIds = {525} },
        { questId = 93087, questName = "Decor Treasure Hunt", decorIds = {2115} },
        { questId = 93111, questName = "Decor Treasure Hunt", decorIds = {1744} },
        { questId = 93115, questName = "Decor Treasure Hunt", decorIds = {2446} },
        { questId = 93107, questName = "Decor Treasure Hunt", decorIds = {4386} },
        { questId = 93132, questName = "Decor Treasure Hunt", decorIds = {2535} },
        { questId = 93082, questName = "Decor Treasure Hunt", decorIds = {1724} },
        { questId = 93077, questName = "Decor Treasure Hunt", decorIds = {1436} },
        { questId = 93097, questName = "Decor Treasure Hunt", decorIds = {2087} },
        { questId = 93100, questName = "Decor Treasure Hunt", decorIds = {2384} },
        { questId = 93140, questName = "Decor Treasure Hunt", decorIds = {2104} },
        { questId = 93137, questName = "Decor Treasure Hunt", decorIds = {1844} },
        { questId = 93136, questName = "Decor Treasure Hunt", decorIds = {1776} },
        { questId = 93138, questName = "Decor Treasure Hunt", decorIds = {2105} },
        { questId = 93135, questName = "Decor Treasure Hunt", decorIds = {1774} },
        { questId = 93139, questName = "Decor Treasure Hunt", decorIds = {2108} },
        { questId = 93152, questName = "Decor Treasure Hunt", decorIds = {988} },
        { questId = 93106, questName = "Decor Treasure Hunt", decorIds = {2592} },
        { questId = 93103, questName = "Decor Treasure Hunt", decorIds = {2098} },
        { questId = 93101, questName = "Decor Treasure Hunt", decorIds = {2454} },
        { questId = 93110, questName = "Decor Treasure Hunt", decorIds = {81} },
        { questId = 93131, questName = "Decor Treasure Hunt", decorIds = {2534} },
    },
    ["Ruins of Gilneas"] = {
        { questId = 14402, questName = "Ready to Go", decorIds = {1829} },
    },
    ["Searing Gorge"] = {
        { questId = 28064, questName = "Welcome to the Brotherhood", decorIds = {2226} },
        { questId = 28035, questName = "The Mountain-Lord's Support", decorIds = {1315} },
    },
    ["Shadowmoon Valley"] = {
        { questId = 36615, questName = "My Very Own Castle", decorIds = {4818} },
        { questId = 34792, questName = "The Traitor's True Name", decorIds = {8177, 8239} },
        { questId = 36169, questName = "The Trial of Champions", decorIds = {8186} },
        { questId = 33256, questName = "The Defense of Karabor", decorIds = {8786} },
        { questId = 36592, questName = "Bigger is Better", decorIds = {4486} },
        { questId = 35176, questName = "Keeping it Together", decorIds = {4844} },
        { questId = 35196, questName = "Forging Ahead", decorIds = {8187} },
        { questId = 36202, questName = "Anglin' In Our Garrison", decorIds = {4404} },
        { questId = 34586, questName = "Establish Your Garrison", decorIds = {4816} },
        { questId = 37322, questName = "The Prophet's Final Message", decorIds = {8240} },
    },
    ["Silvermoon City"] = {
        { questId = 86735, questName = "Paved in Ash", decorIds = {15062} },
    },
    ["Silverpine Forest"] = {
        { questId = 27098, questName = "Lordaeron", decorIds = {923, 924} },
        { questId = 27550, questName = "Pyrewood's Fall", decorIds = {11498} },
    },
    ["Spires of Arak"] = {
        { questId = 35704, questName = "When All Is Aligned", decorIds = {12205} },
        { questId = 35273, questName = "Hot Seat", decorIds = {12208} },
        { questId = 35896, questName = "The Avatar of Terokk", decorIds = {12209} },
        { questId = 35671, questName = "A Gathering of Shadows", decorIds = {12201} },
    },
    ["Stormheim"] = {
        { questId = 39801, questName = "The Splintered Fleet", decorIds = {9267} },
        { questId = 38882, questName = "A New Life for Undeath", decorIds = {947} },
    },
    ["Stormsong Valley"] = {
        { questId = 53720, questName = "Allegiance of Kul Tiras", decorIds = {9052} },
        { questId = 51401, questName = "Carry On", decorIds = {9044} },
        { questId = 50611, questName = "Storm's Vengeance", decorIds = {9142} },
        { questId = 52122, questName = "To Be Forsaken", decorIds = {864} },
        { questId = 51986, questName = "Return to Zuldazar", decorIds = {862} },
        { questId = 52122, questName = "To Be Forsaken", decorIds = {934} },
        { questId = 50783, questName = "The Abyssal Council", decorIds = {1900} },
    },
    ["Stormwind City"] = {
        { questId = 53720, questName = "Allegiance of Kul Tiras", decorIds = {9052} },
        { questId = 53566, questName = "Dark Iron Dwarves", decorIds = {1118} },
        { questId = nil, questName = "Spare A Chair", decorIds = {2330} },
        { questId = 543, questName = "The Perenolde Tiara", decorIds = {4487} },
        { questId = 92572, questName = "Furniture Favor", decorIds = {9247} },
        { questId = 76213, questName = "Honor of the Goddess", decorIds = {4423} },
        { questId = nil, questName = "Dreamy Inspiration", decorIds = {1693} },
        { questId = nil, questName = "Last Light", decorIds = {4029} },
        { questId = nil, questName = "Draconic Decor", decorIds = {4172} },
        { questId = 59583, questName = "Welcome to Stormwind", decorIds = {4405} },
    },
    ["Suramar"] = {
        { questId = 44052, questName = "And They Will Tremble", decorIds = {4028} },
        { questId = 41915, questName = "The Master's Legacy", decorIds = {4031} },
        { questId = 44955, questName = "Visitor in Shal'Aran", decorIds = {1747} },
        { questId = 40321, questName = "Feathersong's Redemption", decorIds = {1885} },
        { questId = 44756, questName = "Sign of the Dusk Lily", decorIds = {3981} },
        { questId = 43318, questName = "Ly'leth's Champion", decorIds = {4025} },
        { questId = 41143, questName = "Mglrgrs Of Our Grmlgrlr", decorIds = {11908} },
        { questId = 42489, questName = "Thalyssra's Drawers", decorIds = {4040} },
    },
    ["Talador"] = {
        { questId = 35685, questName = "Socrethar's Demise", decorIds = {8785} },
        { questId = 34099, questName = "The Battle for Shattrath", decorIds = {8772} },
        { questId = 33582, questName = "Kura's Vengeance", decorIds = {12202} },
        { questId = 36685, questName = "Assault on the Heart of Shattrath", decorIds = {8238} },
        { questId = 38201, questName = "Missive: Assault on Shattrath Harbor", decorIds = {925} },
    },
    ["Thaldraszus"] = {
        { questId = 72935, questName = "Archives Return", decorIds = {4477} },
        { questId = 70745, questName = "Enforced Relaxation", decorIds = {11164} },
    },
    ["The Azure Span"] = {
        { questId = nil, questName = "On New Wings", decorIds = {7835} },
        { questId = 67047, questName = "Warm Away These Shivers", decorIds = {2469} },
        { questId = 71097, questName = "A Helping Claw", decorIds = {4479} },
    },
    ["The Forbidden Reach"] = {
        { questId = nil, questName = "Augmenting a Dragon", decorIds = {5560} },
    },
    ["The Great Sea"] = {
        { questId = 52978, questName = "With Prince in Tow", decorIds = {936} },
    },
    ["The Jade Forest"] = {
        { questId = nil, questName = "The Jade Serpent", decorIds = {15605} },
        { questId = 31230, questName = "Welcome to Dawn's Blossom", decorIds = {3869} },
    },
    ["The Ringing Deeps"] = {
        { questId = 83160, questName = "Cinderbrew Reserve", decorIds = {9246} },
        { questId = 78642, questName = "New Candle, New Hope", decorIds = {11931} },
        { questId = 79510, questName = "The Wickless Candle", decorIds = {11930} },
        { questId = 80516, questName = "Bump off the Boss", decorIds = {11932} },
        { questId = 82144, questName = "On the Road", decorIds = {9188} },
        { questId = 78761, questName = "Into the Machine", decorIds = {9178} },
        { questId = 79530, questName = "Bad Business", decorIds = {9168} },
    },
    ["The Waking Shores"] = {
        { questId = 67063, questName = "10,000 Years of Roasting", decorIds = {2594} },
        { questId = 66001, questName = "A Last Hope", decorIds = {2529} },
    },
    ["Tiragarde Sound"] = {
        { questId = 51401, questName = "Carry On", decorIds = {9044} },
        { questId = nil, questName = "Learn From the Best", decorIds = {9065} },
        { questId = 55045, questName = "My Brother's Keeper", decorIds = {9166} },
        { questId = 53887, questName = "War Marches On", decorIds = {9049} },
        { questId = 51984, questName = "Return to Zuldazar", decorIds = {863} },
        { questId = 48089, questName = "Mountain Sounds", decorIds = {9041} },
        { questId = 50972, questName = "Proudmoore's Parley", decorIds = {9035} },
        { questId = 47489, questName = "Stow and Go", decorIds = {9055} },
    },
    ["Twilight Highlands"] = {
        { questId = 28244, questName = "Eye Spy", decorIds = {2244} },
        { questId = 28655, questName = "Wild, Wild, Wildhammer Wedding", decorIds = {2245} },
    },
    ["Undermine"] = {
        { questId = 87297, questName = "Cashing the Check", decorIds = {1267} },
        { questId = 86408, questName = "My Hole in the Wall", decorIds = {825} },
        { questId = 87008, questName = "Ad-Hoc Wedding Planner", decorIds = {1274} },
        { questId = 84675, questName = "Showdown in the Attic", decorIds = {14381} },
        { questId = 83176, questName = "Just a Hunch", decorIds = {1276} },
        { questId = 85780, questName = "Right Where We Want Him", decorIds = {827} },
        { questId = 85711, questName = "Unsolicited Feedback", decorIds = {1266} },
    },
    
    ["Val'sharah"] = {
        { questId = 39117, questName = "Shriek No More", decorIds = {1801} },
        { questId = 46107, questName = "Source of the Corruption", decorIds = {1802} },
        { questId = 40890, questName = "The Tears of Elune", decorIds = {1889} },
        { questId = 38663, questName = "The Die is Cast", decorIds = {1884} },
        { questId = 40573, questName = "The Nightmare Lord", decorIds = {1882, 1883} },
        { questId = 38147, questName = "Entangled Dreams", decorIds = {1886} },
        { questId = 42751, questName = "Moon Reaver", decorIds = {1692} },
    },
    ["Valdrakken"] = {
        { questId = 70880, questName = "To Cook With Finery", decorIds = {4481} },
    },
    ["Valley of the Four Winds"] = {
        { questId = 30526, questName = "Lost and Lonely", decorIds = {4488} },
    },
    ["Voidstorm"] = {
        { questId = nil, questName = "Face the Tide", decorIds = {14554} },
        { questId = nil, questName = "Nothing Stands Forever", decorIds = {15895} },
        { questId = nil, questName = "Nexus-Point Xenas: Eclipse", decorIds = {14631} },
        { questId = nil, questName = "Two Tons of Metal and Holy Fire", decorIds = {14635} },
    },
    ["Vol'dun"] = {
        { questId = 47874, questName = "Clearing the Fog", decorIds = {1310} },
        { questId = 48554, questName = "The Source of the Problem", decorIds = {1697} },
    },
    ["Westfall"] = {
        { questId = 26229, questName = "\"I TAKE Candle!\"", decorIds = {4814} },
        { questId = 26297, questName = "The Dawning of a New Day", decorIds = {4819} },
        { questId = 26270, questName = "You Have Our Thanks", decorIds = {4444} },
    },
    ["Zul'Aman"] = {
        { questId = 91087, questName = "Reports Returned", decorIds = {11328} },
        { questId = nil, questName = "Den of Nalorakk: A Taste of Vengeance", decorIds = {15743, 15744, 15745} },
        { questId = nil, questName = "Rescue from the Shadows", decorIds = {1148} },
        { questId = nil, questName = "De Legend of de Hash'ey", decorIds = {10858} },
        { questId = nil, questName = "Embers to a Flame", decorIds = {16092} },
    },
    ["Zuldazar"] = {
        { questId = 46931, questName = "Speaker of the Horde", decorIds = {865} },
        { questId = nil, questName = "To Mechagon!", decorIds = {2466} },
        { questId = 50963, questName = "Of Dark Deeds and Dark Days", decorIds = {1205} },
        { questId = nil, questName = "The Bargain is Struck", decorIds = {1193} },
        { questId = 47741, questName = "To Sacrifice a Loa", decorIds = {1196} },
    },
}

local PVP_VENDOR_NPC_IDS = {
    [254603] = true,
    [254606] = true,
    [145695] = true,
    [151941] = true,
    [13217]  = true,
}

local PVP_DROP_KEYWORDS = { "Voidscar Arena" }

local decorItemCache = nil

local function decorToItemMap()
    if decorItemCache then return decorItemCache end
    local map = {}
    local home = Villa.HomeData
    for itemID, meta in pairs((home and home.decorMeta) or {}) do
        if meta and meta.decorID then
            map[meta.decorID] = itemID
        end
    end
    decorItemCache = map
    return map
end

local function isDecorCollected(decorID)
    local itemID = decorToItemMap()[tonumber(decorID)]
    return itemID and Villa:IsKnownDecorItem(itemID) or false
end

local function buildDecorText(decorIds, limit)
    local parts = {}
    local max = limit or 18
    for i, decorID in ipairs(decorIds or {}) do
        if i > max then
            parts[#parts+1] = string.format("… +%d more", #decorIds - max)
            break
        end
        parts[#parts+1] = tostring(decorID)
    end
    return table.concat(parts, ", ")
end

local function collectionSummary(decorIds)
    local owned, total = 0, 0
    for _, decorID in ipairs(decorIds or {}) do
        total = total + 1
        if isDecorCollected(decorID) then owned = owned + 1 end
    end
    return owned, total
end

function CodexData:GetQuestEntries()
    local mode = activeMode("quests")
    if mode == "hybrid" and Villa.NormalizedData and Villa.NormalizedData.GetQuestEntries then return Villa.NormalizedData:GetQuestEntries() end
    if mode == "decorvendor" and Villa.DecorVendorData then return Villa.DecorVendorData:GetQuestEntries() end
    if mode == "hit" and Villa.HITData then return Villa.HITData:GetQuestEntries() end
    if self._questEntries then return self._questEntries end
    local entries = {}
    for zoneName, quests in pairs(self.QuestSourceData or {}) do
        for _, quest in ipairs(quests or {}) do
            local owned, total = collectionSummary(quest.decorIds)
            entries[#entries+1] = {
                entryType = "quest",
                key = tostring(quest.questId or quest.questName or (zoneName .. #entries)),
                title = quest.questName or (quest.questId and ("Quest #"..quest.questId)) or "Unknown Quest",
                subtitle = zoneName,
                detail = string.format("Zone: %s\nQuest ID: %s\nDecor IDs: %s\nCollection: %d/%d", zoneName, tostring(quest.questId or "n/a"), buildDecorText(quest.decorIds), owned, total),
                decorIds = quest.decorIds or {},
                questId = quest.questId,
                owned = owned, total = total,
            }
        end
    end
    table.sort(entries, function(a,b) if a.subtitle ~= b.subtitle then return a.subtitle < b.subtitle end return a.title < b.title end)
    self._questEntries = entries
    return entries
end

function CodexData:GetAchievementEntries()
    local mode = activeMode("achievements")
    if mode == "hybrid" and Villa.NormalizedData and Villa.NormalizedData.GetAchievementEntries then return Villa.NormalizedData:GetAchievementEntries() end
    if mode == "decorvendor" and Villa.DecorVendorData then return Villa.DecorVendorData:GetAchievementEntries() end
    if mode == "hit" and Villa.HITData then return Villa.HITData:GetAchievementEntries() end
    if self._achievementEntries then return self._achievementEntries end
    local entries = {}
    for achievementId, info in pairs(self.AchievementSourceData or {}) do
        local owned, total = collectionSummary(info.decorIds)
        entries[#entries+1] = {
            entryType = "achievement",
            key = tostring(achievementId),
            title = info.achievementName or ("Achievement #"..achievementId),
            subtitle = info.category or "Unknown",
            detail = string.format("Category: %s\nAchievement ID: %s\nDecor IDs: %s\nCollection: %d/%d", tostring(info.category or "Unknown"), tostring(achievementId), buildDecorText(info.decorIds), owned, total),
            decorIds = info.decorIds or {},
            achievementId = achievementId,
            owned = owned, total = total,
        }
    end
    table.sort(entries, function(a,b) if a.subtitle ~= b.subtitle then return a.subtitle < b.subtitle end return a.title < b.title end)
    self._achievementEntries = entries
    return entries
end

function CodexData:GetDropEntries()
    local mode = activeMode("drops")
    if mode == "hybrid" and Villa.NormalizedData and Villa.NormalizedData.GetDropEntries then return Villa.NormalizedData:GetDropEntries() end
    if self._dropEntries then return self._dropEntries end
    local entries = {}
    for category, sources in pairs(self.DropSourceData or {}) do
        for _, source in ipairs(sources or {}) do
            local owned, total = collectionSummary(source.decorIds)
            entries[#entries+1] = {
                entryType = "drop",
                key = tostring(category)..":"..tostring(source.sourceName),
                title = source.sourceName or "Unknown Drop Source",
                subtitle = category:gsub("^%l", string.upper),
                detail = string.format("Category: %s\nDecor IDs: %s\nCollection: %d/%d", tostring(category), buildDecorText(source.decorIds), owned, total),
                decorIds = source.decorIds or {},
                sourceCategory = category,
                owned = owned, total = total,
            }
        end
    end
    table.sort(entries, function(a,b) if a.subtitle ~= b.subtitle then return a.subtitle < b.subtitle end return a.title < b.title end)
    self._dropEntries = entries
    return entries
end

function CodexData:GetProfessionEntries()
    local mode = activeMode("professions")
    if mode == "hybrid" and Villa.NormalizedData and Villa.NormalizedData.GetProfessionEntries then return Villa.NormalizedData:GetProfessionEntries() end
    if mode == "decorvendor" and Villa.DecorVendorData then return Villa.DecorVendorData:GetProfessionEntries() end
    if mode == "hit" and Villa.HITData then return Villa.HITData:GetProfessionEntries() end
    if self._professionEntries then return self._professionEntries end
    local entries = {}
    for professionName, crafts in pairs(self.CraftingSourceData or {}) do
        local grouped = {}
        for _, craft in ipairs(crafts or {}) do
            local key = string.format("%s|%s|%s", professionName, tostring(craft.skillLine or professionName), tostring(craft.recipeName or professionName))
            local entry = grouped[key]
            if not entry then
                entry = {
                    entryType = "profession",
                    key = key,
                    title = craft.recipeName or professionName,
                    subtitle = string.format("%s • %s", professionName, tostring(craft.skillLine or professionName)),
                    decorIds = {},
                    skillNeeded = craft.skillNeeded,
                    recipeId = craft.recipeId,
                }
                grouped[key] = entry
                entries[#entries+1] = entry
            end
            entry.decorIds[#entry.decorIds+1] = craft.decorId
        end
    end
    for _, entry in ipairs(entries) do
        local owned,total = collectionSummary(entry.decorIds)
        entry.owned, entry.total = owned,total
        entry.detail = string.format("Recipe ID: %s\nSkill needed: %s\nDecor IDs: %s\nCollection: %d/%d", tostring(entry.recipeId or "n/a"), tostring(entry.skillNeeded or "n/a"), buildDecorText(entry.decorIds), owned, total)
    end
    table.sort(entries, function(a,b) if a.subtitle ~= b.subtitle then return a.subtitle < b.subtitle end return a.title < b.title end)
    self._professionEntries = entries
    return entries
end

function CodexData:GetPvPEntries()
    if Villa.NormalizedData and Villa.NormalizedData.GetPvPEntries and activeMode("pvp") == "hybrid" then return Villa.NormalizedData:GetPvPEntries() end
    if self._pvpEntries then return self._pvpEntries end
    local entries = {}
    for _, info in ipairs(self:GetAchievementEntries()) do
        if info.subtitle == "PvP" then
            local copy = CopyTable(info)
            copy.entryType = "pvp"
            copy.subtitle = "Achievements"
            entries[#entries+1] = copy
        end
    end
    for _, vendor in ipairs((Villa.HomeData and Villa.HomeData:GetMergedVendorList()) or {}) do
        if vendor.npcID and PVP_VENDOR_NPC_IDS[vendor.npcID] then
            local decorIds = {}
            for _, item in ipairs(vendor.items or {}) do
                if item.decorID then decorIds[#decorIds+1] = item.decorID end
            end
            local owned,total = collectionSummary(decorIds)
            entries[#entries+1] = {
                entryType = "pvp",
                key = "vendor:"..tostring(vendor.npcID),
                title = vendor.name or "PvP Vendor",
                subtitle = "Vendors",
                detail = string.format("Zone: %s\nNPC ID: %s\nDecor IDs: %s\nCollection: %d/%d", tostring(vendor.zone or "Unknown"), tostring(vendor.npcID), buildDecorText(decorIds), owned, total),
                decorIds = decorIds,
                owned = owned, total = total, npcID = vendor.npcID,
            }
        end
    end
    for _, drop in ipairs(self:GetDropEntries()) do
        local title = drop.title or ""
        for _, kw in ipairs(PVP_DROP_KEYWORDS) do
            if title:find(kw, 1, true) then
                local copy = CopyTable(drop)
                copy.entryType = "pvp"
                copy.subtitle = "Drops"
                entries[#entries+1] = copy
                break
            end
        end
    end
    table.sort(entries, function(a,b) if a.subtitle ~= b.subtitle then return a.subtitle < b.subtitle end return a.title < b.title end)
    self._pvpEntries = entries
    return entries
end

function CodexData:GetProgressEntries()
    local entries = {}
    local matrix = (Villa.NormalizedData and Villa.NormalizedData.GetDuplicateMatrix and Villa.NormalizedData:GetDuplicateMatrix()) or {}
    local audit = {}
    for _, row in ipairs(matrix) do
        audit[row.domain] = row
    end

    local function summary(domain, fallbackCount, subtitle)
        local row = audit[domain]
        if row then
            return {
                count = row.normalizedCount,
                detail = string.format("%s\nRaw donor rows: %d\nNormalized rows: %d\nDuplicates removed: %d\nProviders: %s", subtitle, row.rawCount or 0, row.normalizedCount or 0, row.duplicateCount or 0, (row.providerSummary and row.providerSummary ~= "" and row.providerSummary) or "n/a"),
            }
        end
        return {
            count = fallbackCount,
            detail = string.format("%s\nTotal entries: %d", subtitle, fallbackCount or 0),
        }
    end

    local vendorSummary = summary("vendors", #((Villa.HomeData and Villa.HomeData:GetMergedVendorList()) or {}), "Vendor sources merged into Villa")
    local questSummary = summary("quests", #(self:GetQuestEntries()), "Quest source entries")
    local achievementSummary = summary("achievements", #(self:GetAchievementEntries()), "Achievement source entries")
    local dropSummary = summary("drops", #(self:GetDropEntries()), "Drop and encounter sources")
    local professionSummary = summary("professions", #(self:GetProfessionEntries()), "Crafting and recipe sources")
    local pvpSummary = summary("pvp", #(self:GetPvPEntries()), "PvP-tagged source entries")
    local trainerSummary = summary("trainers", (Villa.NormalizedData and Villa.NormalizedData.GetTrainerEntries and #(Villa.NormalizedData:GetTrainerEntries()) or 0), "Trainer records after normalization")
    local materialSummary = summary("materials", (Villa.NormalizedData and Villa.NormalizedData.GetMaterialsEntries and #(Villa.NormalizedData:GetMaterialsEntries()) or 0), "Material source rows after normalization")
    local previewSummary = summary("preview", (Villa.NormalizedData and Villa.NormalizedData.GetPreviewEntries and #(Villa.NormalizedData:GetPreviewEntries()) or 0), "Preview/model tuning rows after normalization")

    local sources = {
        { title = "Vendors", count = vendorSummary.count, detail = vendorSummary.detail, subtitle = "Vendor sources merged into Villa" },
        { title = "Quests", count = questSummary.count, detail = questSummary.detail, subtitle = "Quest source entries" },
        { title = "Achievements", count = achievementSummary.count, detail = achievementSummary.detail, subtitle = "Achievement source entries" },
        { title = "Drops", count = dropSummary.count, detail = dropSummary.detail, subtitle = "Drop and encounter sources" },
        { title = "Professions", count = professionSummary.count, detail = professionSummary.detail, subtitle = "Crafting and recipe sources" },
        { title = "PvP", count = pvpSummary.count, detail = pvpSummary.detail, subtitle = "PvP-tagged source entries" },
        { title = "Trainers", count = trainerSummary.count, detail = trainerSummary.detail, subtitle = "Trainer records after normalization" },
        { title = "Materials", count = materialSummary.count, detail = materialSummary.detail, subtitle = "Material source rows after normalization" },
        { title = "Preview", count = previewSummary.count, detail = previewSummary.detail, subtitle = "Preview/model tuning rows after normalization" },
        { title = "Housing Tracker", count = (Villa.HITData and (function() local c=0 for _ in pairs(Villa.HITData.DecorItems or {}) do c=c+1 end return c end)() or 0), subtitle = "HousingItemTracker donor decor records" },
        { title = "DecorVendor Previews", count = (Villa.DecorVendorData and Villa.DecorVendorData:GetPreviewCount() or 0), subtitle = "DecorVendor model tuning records" },
        { title = "Wishlist", count = #(self:GetWishlistEntries()), subtitle = "Tracked donor entries" },
    }
    for _, row in ipairs(sources) do
        row.entryType = "progress"
        row.key = row.title
        row.detail = row.detail or string.format("%s\nTotal entries: %d", row.subtitle, row.count or 0)
        entries[#entries+1] = row
    end
    return entries
end

function CodexData:IsWishlisted(entryType, key)
    local db = Villa.db
    db.wishlist = db.wishlist or { entries = {} }
    return db.wishlist.entries[(entryType or "")..":"..tostring(key)] == true
end

function CodexData:ToggleWishlist(entryType, key)
    local db = Villa.db
    db.wishlist = db.wishlist or { entries = {} }
    local storageKey = (entryType or "")..":"..tostring(key)
    db.wishlist.entries[storageKey] = not db.wishlist.entries[storageKey] or nil
end

function CodexData:GetWishlistEntries()
    local db = Villa.db
    db.wishlist = db.wishlist or { entries = {} }
    local wanted = db.wishlist.entries
    local catalog = {}
    for _, list in ipairs({ self:GetQuestEntries(), self:GetAchievementEntries(), self:GetDropEntries(), self:GetProfessionEntries(), self:GetPvPEntries() }) do
        for _, entry in ipairs(list) do
            catalog[(entry.entryType or "")..":"..tostring(entry.key)] = entry
        end
    end
    local results = {}
    for storageKey in pairs(wanted) do
        local entry = catalog[storageKey]
        if entry then
            results[#results+1] = entry
        end
    end
    table.sort(results, function(a,b) return (a.title or "") < (b.title or "") end)
    return results
end