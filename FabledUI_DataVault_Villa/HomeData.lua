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
local HomeData = Providers["home"] or {}
Providers["home"] = HomeData
Villa.HomeData = HomeData
Villa:RegisterModule("HomeData", HomeData)



-- Imported Housing Codex donor data: vendor source hierarchy and NPC locations.
-- This is used as a donor-engine fallback so Villa can actually render real housing-source data
-- while the consolidation platform is still being rebuilt.
local CodexVendorSourceData = {
    ["EXPANSION_LEGION"] = {
        ["Dalaran"] = {
            { npcId = 251042, npcName = "Domelius", cost = 30000, currencyName = "Bronze", decorIds = {7610, 7620, 7621, 7622, 7623, 7624, 7625, 7658, 7686, 7687, 7690, 8810, 8811, 9165, 11278, 11279, 11942} },
            { npcId = 252043, npcName = "Halenthos Brightstride", cost = 200, decorIds = {947, 9267} },
            { npcId = 105333, npcName = "Val'zuun", cost = 3000, currencyName = "Order Resources", decorIds = {7622, 11279} },
            { npcId = 112716, npcName = "Rasil Fireborne", cost = 15000, decorIds = {2517} },
        },
    },
    ["EXPANSION_MIDNIGHT"] = {
        ["Silvermoon City"] = {
            { npcId = 258181, npcName = "Construct Ali'a", decorIds = {17439, 17440, 17441, 17442, 17443, 17444, 17446, 17447, 17449, 17450, 17452, 17453, 17454, 17455, 17456, 17457, 17458, 17459, 17460, 17462, 17464, 17465, 17467, 17469, 17472, 17474, 17518, 17519, 17520, 17521, 17522, 17523} },
        },
    },
    ["Unknown"] = {
        ["Acherus: Ebon Hold"] = {
            { npcId = 93550, npcName = "Quartermaster Ozorg", cost = 3000, currencyName = "Order Resources", decorIds = {14361} },
        },
        ["Acherus: The Ebon Hold"] = {
            { npcId = 93550, npcName = "Quartermaster Ozorg", cost = 500, currencyName = "Order Resources", decorIds = {5879, 5880, 5881, 5882, 5888, 5889} },
        },
        ["All Dragonflight Zones, moves with the Dreamsurge Event"] = {
            { npcId = 210608, npcName = "Celestine of the Harvest", cost = 500, decorIds = {10888} },
        },
        ["Amirdrassil"] = {
            { npcId = 216284, npcName = "Mythrin'dir", cost = 250, currencyName = "Dragon Isles Supplies", decorIds = {1989, 4561} },
            { npcId = 216285, npcName = "Ellandrieth", cost = 250, currencyName = "Dragon Isles Supplies", decorIds = {1834, 1861, 1888, 1987, 1990, 4423, 7896} },
            { npcId = 216286, npcName = "Moon Priestess Lasara", cost = 300, currencyName = "Dragon Isles Supplies", decorIds = {11454} },
        },
        ["Arcantina"] = {
            { npcId = 252873, npcName = "Morta Gage", cost = 750, currencyName = "Voidlight Marl", decorIds = {9248, 9249, 9250, 9251, 9252, 9253, 9439, 9440, 9441, 9475, 9624} },
        },
        ["Azsuna"] = {
            { npcId = 89939, npcName = "Berazus", cost = 1000, currencyName = "Order Resources", decorIds = {2530} },
        },
        ["Blackrock Depths"] = {
            { npcId = 144129, npcName = "Plugger Spazzring", decorIds = {1120} },
        },
        ["Boralus"] = {
            { npcId = 135808, npcName = "Provisioner Fray", cost = 100, currencyName = "War Resources", decorIds = {2091, 8984, 9036, 9037, 9051} },
        },
        ["Boralus Harbor"] = {
            { npcId = 142115, npcName = "Fiona", cost = 3000, decorIds = {4813} },
        },
        ["Borean Tundra"] = {
            { npcId = 25206, npcName = "Ahlurglgr", decorIds = {11906} },
        },
        ["Brawl'gar Arena"] = {
            { npcId = 145695, npcName = "\"Bad Luck\" Symmes", cost = 500, decorIds = {10913, 12263, 14815} },
        },
        ["Burning Steppes"] = {
            { npcId = 115805, npcName = "Hoddruc Bladebender", cost = 4500000, decorIds = {11131} },
        },
        ["Chamber of Heart"] = {
            { npcId = 152194, npcName = "MOTHER", cost = 10000, currencyName = "Echoes of Ny'alotha", decorIds = {3837, 3838} },
        },
        ["City of Threads"] = {
            { npcId = 218202, npcName = "Thripps", cost = 1500, currencyName = "Kej", decorIds = {2532} },
        },
        ["Darnassus"] = {
            { npcId = 50307, npcName = "Lord Candren", cost = 350, decorIds = {858, 1794, 1796, 1829} },
        },
        ["Deeprun Tram"] = {
            { npcId = 151941, npcName = "Dershway the Triggered", cost = 500, decorIds = {10913, 12263, 14815} },
        },
        ["Dornogal"] = {
            { npcId = 252312, npcName = "Second Chair Pawdo", decorIds = {1693, 1861, 2330, 2433, 4022, 4029, 4172, 5111, 9247, 10962} },
            { npcId = 252910, npcName = "Garnett", cost = 900, currencyName = "Resonance Crystals", decorIds = {9168, 9169, 9181, 9182, 9185, 9186, 9237} },
            { npcId = 223728, npcName = "Auditor Balwurz", cost = 1, decorIds = {760, 761, 762, 1750, 9242} },
            { npcId = 219318, npcName = "Jorid", cost = 750, currencyName = "Resonance Crystals", decorIds = {2533} },
        },
        ["Dragonscale Basecamp"] = {
            { npcId = 189226, npcName = "Cataloger Jakes", cost = 400, currencyName = "Dragon Isles Supplies", decorIds = {716, 717, 718, 720, 1177, 1181} },
            { npcId = 188265, npcName = "Rae'ana", cost = 400, currencyName = "Dragon Isles Supplies", decorIds = {716, 717, 718, 720, 1177, 1181} },
        },
        ["Dreadscar Rift"] = {
            { npcId = 112434, npcName = "Gigi Gigavoid", cost = 1000, currencyName = "Order Resources", decorIds = {5117, 5120, 5127, 5128, 5292, 11307, 15477} },
        },
        ["Dun Morogh"] = {
            { npcId = 253235, npcName = "Dedric Sleetshaper", cost = 700, decorIds = {1118, 1216, 2243, 2333, 2334, 8982, 11133, 11160} },
            { npcId = 1247, npcName = "Innkeeper Belm", cost = 190, decorIds = {11130} },
            { npcId = 50309, npcName = "Captain Stonehelm", cost = 950, decorIds = {2243, 8982, 11133} },
        },
        ["Duskwood"] = {
            { npcId = 44114, npcName = "Wilkinson", cost = 175, decorIds = {1833, 11305} },
        },
        ["Eon's Fringe, Thaldraszus"] = {
            { npcId = 209220, npcName = "Ironus Coldsteel", cost = 150, currencyName = "Dragon Isles Supplies", decorIds = {4161} },
        },
        ["Eversong Woods"] = {
            { npcId = 240838, npcName = "Caeris Fairdawn", decorIds = {1198, 1896, 1901, 5564, 10944, 11502, 11503, 14971, 14972, 14979, 14985, 15059, 15060, 15063, 15065, 15499, 15500} },
            { npcId = 242726, npcName = "Neriv", cost = 100, currencyName = "Brimming Arcana", decorIds = {2459, 7782} },
            { npcId = 259864, npcName = "Sathren Azuredawn", decorIds = {1159, 1160, 1173, 1195, 1442, 1489, 1908, 8872, 8874, 8875, 10542, 11470, 14635, 14977, 15062, 15483, 15895} },
            { npcId = 242724, npcName = "Ranger Allorn", cost = 100, currencyName = "Brimming Arcana", decorIds = {14978, 14979} },
            { npcId = 242723, npcName = "Apprentice Diell", cost = 100, currencyName = "Brimming Arcana", decorIds = {14995, 15013} },
            { npcId = 242725, npcName = "Armorer Goldcrest", cost = 100, currencyName = "Brimming Arcana", decorIds = {14970} },
            { npcId = 257633, npcName = "Chel the Chip", decorIds = {15489} },
        },
        ["Founder's Point"] = {
            { npcId = 255221, npcName = "Trevor Grenner", cost = 50, decorIds = {520, 521, 771, 772, 773, 1864, 1865, 1866, 1867, 4406, 4407, 4408, 4461, 4465, 4466, 4467, 4468, 4469, 4470, 4471, 4472, 4473, 4474, 4475, 4822, 4823, 4845, 10855, 10856, 12189, 12190, 17868, 17869, 17870, 17871, 17872, 17873, 17874, 17918, 17919} },
            { npcId = 255230, npcName = "\"Yen\" Malone", cost = 100, decorIds = {4451, 4452, 4453, 4454, 4455, 4456, 4457, 4458, 4459, 4460, 4462, 4463, 4464, 4476, 11461, 11479, 11481, 11482, 14382, 14383, 17863, 17864, 17865, 17866, 17867, 17873, 17874, 17918, 17919} },
            { npcId = 255216, npcName = "Balen Starfinder", cost = 50, decorIds = {80, 984, 985, 987, 988, 989, 994, 1153, 1162, 1163, 1245, 1246, 1329, 1487, 1770, 1771, 1772, 1773, 1774, 1775, 1776, 1844, 2104, 2105, 2106, 2107, 2108, 2109, 2110, 2111, 2112, 2113, 2254, 2458, 2474, 2590, 3826, 4562, 5563, 8917, 8918, 9254, 9255, 10860, 11719, 15454} },
            { npcId = 255213, npcName = "Faarden the Builder", cost = 100, decorIds = {479, 480, 481, 482, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 496, 497, 770, 1122, 1280, 1457, 1742, 1862, 1863, 1878, 1992, 1994, 1995, 1996, 1997, 1999, 2089, 2385, 2496, 9472, 14814} },
            { npcId = 256750, npcName = "Klasa", cost = 10, decorIds = {721, 722, 723, 724, 725} },
            { npcId = 257897, npcName = "Harlowe Marl", cost = 5, currencyName = "Community Coupons", decorIds = {16227, 16228, 16229, 16230, 16231, 16232, 16233, 16234, 16235, 16236, 16237, 16315, 16962} },
            { npcId = 255203, npcName = "Xiao Dan", cost = 10, decorIds = {379, 388, 478, 483, 484, 498, 527, 533, 1044, 1244, 1434, 1454, 1455, 1456, 1701, 1702, 2102, 2103, 9064, 9144, 9473, 9474, 12199} },
            { npcId = 255218, npcName = "Argan Hammerfist", cost = 100, decorIds = {986, 990, 991, 992, 1155, 1165, 1350, 1356, 1486, 1488, 3827, 4484, 11720, 11721} },
            { npcId = 255222, npcName = "\"High Tides\" Ren", cost = 50, decorIds = {522, 526, 534, 535, 536, 1451, 1452, 1453, 1698, 1699, 1978, 1979, 2092, 2094, 2117, 2118, 2439, 2440, 2441, 2442, 2445, 2545, 5853, 5854, 7836, 8771, 8910, 8911, 8912, 9143, 10324, 10367, 10952, 11480, 11874} },
            { npcId = 257307, npcName = "\"Den\" Nightshade", cost = 5, currencyName = "Community Coupons", decorIds = {14677, 14678, 14679, 14680, 14793, 14800, 14829, 14830, 14831, 14832, 14833, 14834} },
            { npcId = 255228, npcName = "\"Len\" Splinthoof", cost = 25, decorIds = {1436, 1439, 1724, 1737, 2087, 2088, 2090, 2098, 2443, 2444, 2447, 2448, 2534, 2546, 2547, 2548, 2549, 2550, 5561, 8236, 8769, 8770, 10791, 10892, 11139, 11437} },
        },
        ["Freywold Village, Isle of Dorn"] = {
            { npcId = 252901, npcName = "Cinnabar", cost = 400, currencyName = "Resonance Crystals", decorIds = {9179, 9183, 9240} },
        },
        ["Frostwall"] = {
            { npcId = 87015, npcName = "Kil'rip", cost = 500, currencyName = "Apexis Crystal", decorIds = {1317, 1322} },
            { npcId = 86776, npcName = "Ribchewer", cost = 150, currencyName = "Garrison Resources", decorIds = {1354, 1355, 1413, 1414} },
            { npcId = 79774, npcName = "Sergeant Grimjaw", cost = 240, currencyName = "Garrison Resources", decorIds = {1318, 1353, 1407, 1408, 1412, 1443} },
            { npcId = 79812, npcName = "Moz'def", cost = 75, decorIds = {1326, 1352} },
            { npcId = 76872, npcName = "Supplymaster Eri", cost = 150, currencyName = "Garrison Resources", decorIds = {1416} },
            { npcId = 87312, npcName = "Vora Strongarm", cost = 50, currencyName = "Garrison Resources", decorIds = {751} },
        },
        ["Ghostlands"] = {
            { npcId = 16528, npcName = "Provisioner Vredigar", cost = 5000, decorIds = {10950, 11500} },
        },
        ["Grizzly Hills"] = {
            { npcId = 27391, npcName = "Woodsman Drake", cost = 500, decorIds = {4448} },
        },
        ["Gundargaz, Ringing Deeps"] = {
            { npcId = 221390, npcName = "Waxmonger Squick", cost = 600, currencyName = "Resonance Crystals", decorIds = {9236} },
        },
        ["Hall of the Guardian"] = {
            { npcId = 112440, npcName = "Jackson Watkins", cost = 5000, currencyName = "Order Resources", decorIds = {750, 5894, 5895, 5896, 7579, 7609, 11275} },
        },
        ["Hallowfall"] = {
            { npcId = 217642, npcName = "Nalina Ironsong", cost = 500, currencyName = "Resonance Crystals", decorIds = {14360} },
            { npcId = 240852, npcName = "Lars Bronsmaelt", cost = 1200, currencyName = "Resonance Crystals", decorIds = {763} },
        },
        ["Harandar"] = {
            { npcId = 255114, npcName = "Maku", decorIds = {1080, 1147, 1726, 2224, 2232, 2233, 2605, 8993, 10327, 10778, 14639, 14799, 14809, 14823, 14827, 14968, 15155, 15463, 15494, 15497, 15501, 17516, 17886} },
            { npcId = 248658, npcName = "Chel the Chip", decorIds = {11323, 15484, 15851} },
            { npcId = 251259, npcName = "Mothkeeper Wew'tam", decorIds = {14824, 15478, 15480} },
            { npcId = 240407, npcName = "Naynar", decorIds = {2219, 2225, 2588, 2589, 5651, 8916, 14808, 14825, 14965, 14967, 15502, 15503, 15504} },
            { npcId = 258507, npcName = "Mowaia", decorIds = {15407} },
            { npcId = 258480, npcName = "Amwa'ana", decorIds = {15410} },
            { npcId = 258540, npcName = "Hawli", decorIds = {15457} },
        },
        ["Highmountain"] = {
            { npcId = 108537, npcName = "Crafty Palu", cost = 175, currencyName = "Order Resources", decorIds = {11905, 11907, 11909} },
            { npcId = 106902, npcName = "Ransa Greyfeather", cost = 800, currencyName = "Order Resources", decorIds = {1231, 1252, 1292, 1293, 1295, 1297, 1703, 5136} },
        },
        ["Hillsbrad Foothills"] = {
            { npcId = 13217, npcName = "Thanthaldis Snowgleam", cost = 1, decorIds = {2241} },
        },
        ["Ironforge"] = {
            { npcId = 50309, npcName = "Captain Stonehelm", cost = 142, decorIds = {2333, 2334} },
        },
        ["Isle of Dorn"] = {
            { npcId = 226205, npcName = "Cendvin", cost = 100, decorIds = {2470} },
        },
        ["K'aresh"] = {
            { npcId = 235252, npcName = "Om'sirik", cost = 800, currencyName = "Resonance Crystals", decorIds = {3891, 11948, 11952, 12195, 12196, 12197, 12198, 12211, 12212, 12217, 12218, 12220} },
        },
        ["Kun-Lai Summit"] = {
            { npcId = 59698, npcName = "Brother Furtrim", cost = 1000, decorIds = {15595} },
        },
        ["Liberation of Undermine"] = {
            { npcId = 235621, npcName = "Ando the Gat", decorIds = {828, 1121} },
        },
        ["Lunarfall"] = {
            { npcId = 78564, npcName = "Sergeant Crowler", cost = 1500, currencyName = "Garrison Resources", decorIds = {126, 4403, 4485, 4818, 4844} },
            { npcId = 85427, npcName = "Maaria", cost = 500, currencyName = "Apexis Crystal", decorIds = {931, 8235} },
            { npcId = 86779, npcName = "Krixel Pinchwhistle", cost = 150, currencyName = "Garrison Resources", decorIds = {1354, 1355, 1413, 1414} },
            { npcId = 88223, npcName = "Sergeant Crowler", decorIds = {126, 4404, 4486, 4816} },
            { npcId = 88220, npcName = "Peter", cost = 50, currencyName = "Garrison Resources", decorIds = {751} },
        },
        ["Mandori Village"] = {
            { npcId = 112338, npcName = "Caydori Brightstar", cost = 2000, currencyName = "Order Resources", decorIds = {5112, 5113, 5119, 5126, 11280, 14644} },
        },
        ["Masters' Perch"] = {
            { npcId = 258328, npcName = "Thraxadar", decorIds = {3922, 15488, 15585} },
        },
        ["Mechagon"] = {
            { npcId = 150716, npcName = "Stolen Royal Vendorbot", cost = 800, decorIds = {2322, 2323, 2326, 2327, 2337, 2338, 2339, 2341, 2343, 2430, 2433, 2435, 2437, 2467} },
        },
        ["Mechagon Island"] = {
            { npcId = 150716, npcName = "Stolen Royal Vendorbot", cost = 2000000, decorIds = {2466} },
        },
        ["Mudsprocket, Dustwallow Marsh"] = {
            { npcId = 23995, npcName = "Axle", cost = 250, decorIds = {1674} },
        },
        ["Nazmir"] = {
            { npcId = 135459, npcName = "Provisioner Lija", cost = 400, currencyName = "War Resources", decorIds = {1170, 1178, 1199, 1218, 11484} },
        },
        ["Netherlight Temple"] = {
            { npcId = 112401, npcName = "Meridelle Lightspark", cost = 500, currencyName = "Order Resources", decorIds = {7606, 7607, 7608, 7821, 7822, 7823, 7824, 8768} },
        },
        ["Orgrimmar"] = {
            { npcId = 254606, npcName = "Joruh", cost = 5, decorIds = {3867, 3880, 3881, 3885, 3887, 3890, 3893, 3896, 3897, 3898, 3899, 3900, 3902, 3903, 3905, 3906, 3907, 9244, 11296} },
            { npcId = 256119, npcName = "Lonalo", cost = 2000, decorIds = {766, 768, 2511, 2513, 2514, 2526} },
        },
        ["Port of Zandalar, Dazar'alor"] = {
            { npcId = 251921, npcName = "Arcanist Peroleth", cost = 300, currencyName = "War Resources", decorIds = {837, 838, 862, 863, 865, 933, 934, 935, 936, 941, 942, 944, 945, 946} },
            { npcId = 148923, npcName = "Captain Zen'taga", cost = 250, currencyName = "Seafarer's Dubloon", decorIds = {943} },
        },
        ["Razorwind Shores"] = {
            { npcId = 252917, npcName = "Hesta Forlath", cost = 5, currencyName = "Community Coupons", decorIds = {9419, 9420, 9421, 9422, 9423, 9476, 9477, 9478, 10273} },
            { npcId = 250820, npcName = "Hordranin", cost = 15, currencyName = "Community Coupons", decorIds = {7668, 7691, 7692, 7693, 7694, 7695, 7696, 7697, 7698, 7699, 7700, 7701} },
            { npcId = 255319, npcName = "\"Yen\" Malone", cost = 50, decorIds = {520, 521, 771, 772, 773, 1864, 1865, 1866, 1867, 4461, 4465, 4466, 4467, 4468, 4469, 4470, 4471, 4472, 4473, 4474, 4475, 4822, 4823, 4845, 10855, 10856, 12189, 12190, 17868, 17869, 17870, 17871, 17872} },
            { npcId = 255301, npcName = "Botanist Boh'an", cost = 100, decorIds = {4406, 4407, 4408, 4451, 4452, 4453, 4454, 4455, 4456, 4457, 4458, 4459, 4460, 4462, 4463, 4464, 4476, 11461, 11479, 11481, 11482, 14382, 14383} },
            { npcId = 255298, npcName = "Jehzar Starfall", cost = 50, decorIds = {989, 1245, 1246, 1487, 1773, 1775, 2106, 2107, 2111, 2112, 2254, 2458, 2474, 2590, 3826, 5563, 8918, 9254, 15454} },
            { npcId = 248525, npcName = "Pascal-K1N6", cost = 5, currencyName = "Community Coupons", decorIds = {10339, 10340, 10341, 10342, 10343, 10344, 10345, 10346, 10347, 10348, 10349, 10350, 10351, 10352, 10354, 10355, 10537} },
            { npcId = 240465, npcName = "Lonomia", cost = 10, decorIds = {721, 722, 723, 724, 725} },
            { npcId = 249684, npcName = "Brother Dovetail", cost = 5, currencyName = "Community Coupons", decorIds = {2453, 2495, 2510, 4424, 4425, 4427, 4428, 4429, 8179, 8180, 8181, 8182, 8987, 8988, 8989} },
            { npcId = 255325, npcName = "\"High Tides\" Ren", cost = 100, decorIds = {373, 374, 377, 378, 379, 383, 388, 389, 390, 478, 483, 484, 495, 498, 527, 528, 529, 530, 533, 726, 1044, 1123, 1244, 1434, 1435, 1454, 1455, 1456, 1482, 1701, 1702, 1738, 1739, 1745, 1991, 1993, 2099, 2100, 2101, 2102, 2103, 2342, 9064, 9144, 9471, 9473, 9474, 12199} },
            { npcId = 255278, npcName = "Gronthul", cost = 50, decorIds = {81, 522, 523, 524, 525, 526, 534, 535, 536, 1437, 1438, 1451, 1452, 1453, 1698, 1699, 1700, 1723, 1736, 1744, 1879, 1977, 1978, 1979, 2092, 2093, 2094, 2114, 2115, 2116, 2117, 2118, 2384, 2439, 2440, 2441, 2442, 2445, 2446, 2454, 2535, 2545, 2592, 4386, 5853, 5854, 7836, 7842, 8771, 8907, 8910, 8911, 8912, 9143, 10324, 10367, 10952, 11480, 11874} },
            { npcId = 255326, npcName = "\"Len\" Splinthoof", cost = 100, decorIds = {479, 480, 481, 482, 485, 486, 487, 488, 489, 490, 491, 492, 493, 497, 770, 1457, 1742, 1862, 1863, 1995, 1999, 2089, 2385, 9472, 14814} },
            { npcId = 252605, npcName = "Aeeshna", cost = 5, currencyName = "Community Coupons", decorIds = {14677, 14678, 14679, 14680, 14793, 14800, 14829, 14830, 14831, 14832, 14833, 14834} },
            { npcId = 255299, npcName = "Lefton Farrer", cost = 75, decorIds = {986, 990, 991, 992, 1155, 1165, 1350, 3827, 4484} },
            { npcId = 253596, npcName = "The Last Architect", cost = 500, decorIds = {14583} },
            { npcId = 255297, npcName = "Shon'ja", cost = 150, decorIds = {1439, 2090, 2443, 2444, 2447, 2448, 2547, 2550, 5561, 8236, 8769, 8770, 10791, 10892, 11139, 11437} },
        },
        ["Ruins of Gilneas"] = {
            { npcId = 216888, npcName = "Samantha Buckley", cost = 100, decorIds = {859, 860, 1795, 1826, 11944} },
        },
        ["Sanctum of Light"] = {
            { npcId = 100196, npcName = "Eadric the Pure", cost = 5000, currencyName = "Order Resources", decorIds = {7571, 7572, 7573, 7574, 7575, 7576, 7577} },
        },
        ["Satheril's Haven, Eversong Woods"] = {
            { npcId = 242725, npcName = "Armorer Goldcrest", cost = 100, currencyName = "Brimming Arcana", decorIds = {5564} },
        },
        ["Searing Gorge"] = {
            { npcId = 14624, npcName = "Master Smith Burninate", cost = 700, decorIds = {1315, 2226} },
        },
        ["Shadowmoon Valley (Draenor)"] = {
            { npcId = 81133, npcName = "Artificer Kallaes", cost = 200, currencyName = "Garrison Resources", decorIds = {11451} },
        },
        ["Sholazar Basin"] = {
            { npcId = 28038, npcName = "Purser Boulian", cost = 500, decorIds = {4839} },
        },
        ["Shrine of Two Moons, Vale of Eternal Blossoms"] = {
            { npcId = 64001, npcName = "Sage Lotusbloom", cost = 240, decorIds = {3869} },
        },
        ["Silvermoon City"] = {
            { npcId = 242399, npcName = "Telemancer Astrandis", cost = 10, currencyName = "Voidlight Marl", decorIds = {15399, 15400, 15401, 15412, 15413, 15455, 15460} },
            { npcId = 252916, npcName = "Hesta Forlath", cost = 1500, decorIds = {1446, 9483, 9486, 9487, 9488, 9489, 9490, 9628, 9629} },
            { npcId = 256828, npcName = "Dennia Silvertongue", decorIds = {1458, 1894, 2231, 4843, 9149, 9150, 9151, 9152, 15070, 15072, 15073, 15074, 15142, 15143, 15144, 15145, 15146, 15147, 15148, 15149, 15150, 15151, 15152, 15153, 16027, 16028, 16029, 16030, 16031, 16032, 16033, 16034, 16035, 16036, 16037, 16038, 16811, 16812, 16813, 16814, 16815, 16816, 16817, 16818, 16819, 16820, 16821, 16822, 16964, 16965, 16966, 16967, 16968, 16969, 16970, 16971, 16972, 16973} },
            { npcId = 242398, npcName = "Naleidea Rivergleam", decorIds = {2503, 7780} },
            { npcId = 243359, npcName = "Melaris", decorIds = {15402} },
            { npcId = 241451, npcName = "Eriden", decorIds = {15403} },
            { npcId = 257914, npcName = "Quelis", decorIds = {15404} },
            { npcId = 243350, npcName = "Lyna", decorIds = {15405} },
            { npcId = 241453, npcName = "Yatheon", decorIds = {15406} },
            { npcId = 256026, npcName = "Irodalmin", decorIds = {15408} },
            { npcId = 243555, npcName = "Lelorian", decorIds = {15409} },
            { npcId = 243353, npcName = "Deynna", decorIds = {15459} },
        },
        ["Silverpine Forest"] = {
            { npcId = 2140, npcName = "Edwin Harly", cost = 142, decorIds = {11498} },
        },
        ["Sinfall"] = {
            { npcId = 174710, npcName = "Chachi the Artiste", cost = 1500, currencyName = "Reservoir Anima", decorIds = {756} },
        },
        ["Skyhold"] = {
            { npcId = 112392, npcName = "Quartermaster Durnolf", cost = 5000, currencyName = "Order Resources", decorIds = {5526, 5528, 5529, 5532, 5534, 5562, 11486} },
        },
        ["Spires of Arak"] = {
            { npcId = 87775, npcName = "Ruuan the Seer", cost = 8, decorIds = {12200, 12201, 12205, 12208, 12209} },
        },
        ["Stormglen Village, Gilneas"] = {
            { npcId = 211065, npcName = "Marie Allen", cost = 100, decorIds = {857, 859, 860, 1795, 1826, 11944} },
        },
        ["Stormshield"] = {
            { npcId = 85946, npcName = "Shadow-Sage Brakoss", cost = 8, decorIds = {12203, 12206, 12207} },
            { npcId = 85950, npcName = "Trader Caerel", cost = 500, currencyName = "Garrison Resources", decorIds = {928, 8177, 8186, 8187, 8239, 8240, 8772, 8785, 8786} },
        },
        ["Stormshield, Ashran"] = {
            { npcId = 85932, npcName = "Vindicator Nuurem", cost = 1000, currencyName = "Garrison Resources", decorIds = {927, 8185, 8188, 8190, 8192, 8193, 8194, 8242} },
        },
        ["Stormsong Valley"] = {
            { npcId = 252313, npcName = "Caspian", cost = 125, currencyName = "War Resources", decorIds = {1900, 9043, 9044, 9045, 9047, 9139, 9142} },
        },
        ["Stormwind City"] = {
            { npcId = 254603, npcName = "Riica", cost = 600, currencyName = "Honor", decorIds = {3880, 3881, 3884, 3886, 3890, 3893, 3894, 3895, 3898, 3899, 3900, 3902, 3903, 3905, 3906, 3907, 9244, 11296} },
            { npcId = 49877, npcName = "Captain Lancy Revshon", cost = 47, decorIds = {4402, 4405, 4443, 4444, 4445, 4446, 4447, 4487, 4490, 4811, 4812, 4814, 4815, 4819, 5115, 5116, 11274} },
            { npcId = 256071, npcName = "Solelo", cost = 2000, decorIds = {766, 768, 2511, 2513, 2514, 2526} },
        },
        ["Stranglethorn Vale"] = {
            { npcId = 2483, npcName = "Jaquilina Dramet", cost = 450, decorIds = {4841} },
        },
        ["Suramar"] = {
            { npcId = 115736, npcName = "First Arcanist Thalyssra", cost = 560, currencyName = "Order Resources", decorIds = {1440, 2516, 3983, 3984, 3985, 4024, 4035, 4038} },
            { npcId = 97140, npcName = "First Arcanist Thalyssra", decorIds = {1440, 2516, 3983, 3984, 3985, 4024, 4035, 4038} },
            { npcId = 252969, npcName = "Jocenna", cost = 400, currencyName = "Order Resources", decorIds = {752, 1747, 3981, 3982, 4025, 4028, 4031, 4040} },
            { npcId = 253434, npcName = "Sileas Duskvine", cost = 175, currencyName = "Order Resources", decorIds = {1885} },
            { npcId = 93971, npcName = "Leyweaver Inondra", cost = 250, currencyName = "Ancient Mana", decorIds = {4026, 4033} },
            { npcId = 248594, npcName = "Sundries Merchant", cost = 200, currencyName = "Ancient Mana", decorIds = {1444, 1464, 1465, 1466, 1919, 1920} },
            { npcId = 256826, npcName = "Mrgrgrl", cost = 600, currencyName = "Order Resources", decorIds = {11908} },
            { npcId = 255101, npcName = "Mynde", cost = 50, currencyName = "Ancient Mana", decorIds = {11483, 11708} },
        },
        ["Surwich, Blasted Lands"] = {
            { npcId = 44337, npcName = "Maurice Essman", cost = 1100, decorIds = {1481} },
        },
        ["Talador"] = {
            { npcId = 256946, npcName = "Duskcaller Erthix", cost = 10, decorIds = {12202} },
        },
        ["Tazavesh, the Veiled Market, K'aresh"] = {
            { npcId = 235314, npcName = "Ta'sam", cost = 500, currencyName = "Resonance Crystals", decorIds = {14359} },
        },
        ["Teldrassil"] = {
            { npcId = 252520, npcName = "Ripley Kiefer", cost = 50, decorIds = {1829} },
        },
        ["Thaldraszus"] = {
            { npcId = 209192, npcName = "Provisioner Aristta", cost = 4000, currencyName = "Mysterious Fragment", decorIds = {4173} },
        },
        ["The Bazaar, Silvermoon City"] = {
            { npcId = 252915, npcName = "Corlen Hordralin", cost = 5000, decorIds = {9479, 9480, 9481, 9482, 9484, 9485, 9491, 9492, 9493, 9494, 9495, 9496, 9497} },
        },
        ["The Dreamgrove"] = {
            { npcId = 112323, npcName = "Amurra Thistledew", cost = 1500, currencyName = "Order Resources", decorIds = {1741, 2086, 5878, 5897, 5898, 7873, 14358} },
        },
        ["The Fel Hammer"] = {
            { npcId = 112407, npcName = "Falara Nightsong", cost = 2000, currencyName = "Order Resources", decorIds = {5525, 5527, 5530, 5531, 5555, 5575, 11276} },
        },
        ["The Forbidden Reach"] = {
            { npcId = 253086, npcName = "Jolinth", cost = 1500, currencyName = "Elemental Overflow", decorIds = {4482} },
        },
        ["The Hall of Shadows"] = {
            { npcId = 105986, npcName = "Kelsey Steelspark", cost = 5000, currencyName = "Order Resources", decorIds = {7815, 7816, 7817, 7818, 7819, 7820, 14461} },
        },
        ["The Jade Forest"] = {
            { npcId = 58414, npcName = "San Redscale", cost = 400, decorIds = {3870, 3872} },
        },
        ["The Library, Ironforge"] = {
            { npcId = 253232, npcName = "Inge Brightview", cost = 700, decorIds = {2228, 2229} },
        },
        ["The Maelstrom"] = {
            { npcId = 112318, npcName = "Flamesmith Lanying", cost = 2000, currencyName = "Order Resources", decorIds = {7837, 7838, 7839, 7841, 7874, 7875, 11493} },
        },
        ["The Maw"] = {
            { npcId = 162804, npcName = "Ve'nari", cost = 10000, currencyName = "Stygia", decorIds = {4181} },
        },
        ["The Ringing Deeps"] = {
            { npcId = 256783, npcName = "Gabbun", cost = 10, decorIds = {11930, 11931, 11932, 11933} },
            { npcId = 252887, npcName = "Chert", cost = 650, currencyName = "Resonance Crystals", decorIds = {9178, 9188, 9236, 9246} },
        },
        ["The Vindicaar"] = {
            { npcId = 127151, npcName = "Toraan the Revered", cost = 640, decorIds = {930, 8189} },
        },
        ["The Waking Shores"] = {
            { npcId = 190155, npcName = "Caretaker Azkra", decorIds = {2529} },
        },
        ["Thelsamar, Loch Modan"] = {
            { npcId = 1465, npcName = "Drac Roughcut", cost = 285, decorIds = {2239} },
        },
        ["Thunder Bluff"] = {
            { npcId = 50483, npcName = "Brave Tuho", cost = 160, decorIds = {1281} },
        },
        ["Thunder Totem"] = {
            { npcId = 108017, npcName = "Torv Dubstomp", cost = 85000, decorIds = {15741} },
        },
        ["Thunder Totem, Highmountain"] = {
            { npcId = 108017, npcName = "Torv Dubstomp", cost = 300, currencyName = "Order Resources", decorIds = {1235, 1251, 1287, 1291, 1294, 1307, 1309, 11315, 11487, 11491, 11751, 11752, 11753, 14379} },
        },
        ["Tiragarde Sound"] = {
            { npcId = 252345, npcName = "Pearl Barlow", cost = 550, currencyName = "War Resources", decorIds = {1704, 9035, 9049, 9052, 9055, 9140, 9141, 9166} },
            { npcId = 252316, npcName = "Delphine", cost = 250, currencyName = "War Resources", decorIds = {9041, 9054} },
            { npcId = 246721, npcName = "Janey Forrest", cost = 300, currencyName = "War Resources", decorIds = {9039, 9040, 9042, 9053, 12210} },
        },
        ["Trade District, Stormwind"] = {
            { npcId = 49877, npcName = "Captain Lancy Revshon", cost = 95, decorIds = {9242} },
        },
        ["Trueshot Lodge"] = {
            { npcId = 103693, npcName = "Outfitter Reynolds", cost = 1000, currencyName = "Order Resources", decorIds = {1740, 4042, 5877, 5890, 5891, 5892, 5893} },
        },
        ["Twilight Highlands"] = {
            { npcId = 253227, npcName = "Breana Bitterbrand", cost = 1000, decorIds = {1998, 2242, 2244, 2245} },
            { npcId = 49386, npcName = "Craw MacGraw", cost = 2000, decorIds = {1998, 2242} },
            { npcId = 249196, npcName = "Materialist Ophinell", cost = 50, currencyName = "Twilight's Blade Insignia", decorIds = {714, 1227, 1236} },
        },
        ["Undercity, Orgrimmar"] = {
            { npcId = 50304, npcName = "Captain Donald Adams", cost = 127, decorIds = {923, 924} },
        },
        ["Undermine"] = {
            { npcId = 251911, npcName = "Stacks Topskimmer", cost = 1000, currencyName = "Resonance Crystals", decorIds = {825, 827, 1257, 1258, 1262, 1263, 1266, 1267, 1271, 1274, 1276, 11455, 14381} },
            { npcId = 231406, npcName = "Rocco Razzboom", cost = 450, currencyName = "Resonance Crystals", decorIds = {1259, 10889} },
            { npcId = 239333, npcName = "Street Food Vendor", cost = 350, currencyName = "Resonance Crystals", decorIds = {11128} },
            { npcId = 231396, npcName = "Sitch Lowdown", cost = 450, currencyName = "Resonance Crystals", decorIds = {1268, 11127} },
            { npcId = 231405, npcName = "Boatswain Hardee", cost = 900, currencyName = "Resonance Crystals", decorIds = {4560, 10853} },
            { npcId = 231408, npcName = "Lab Assistant Laszly", cost = 400, currencyName = "Resonance Crystals", decorIds = {1265, 10852} },
            { npcId = 226994, npcName = "Blair Bass", cost = 15, decorIds = {1277} },
            { npcId = 231407, npcName = "Shredz the Scrapper", cost = 650, currencyName = "Resonance Crystals", decorIds = {1269, 10857} },
            { npcId = 231409, npcName = "Smaks Topskimmer", decorIds = {1257, 1258, 1262, 1263} },
        },
        ["Val'sharah"] = {
            { npcId = 252498, npcName = "Corbin Branbell", cost = 350, currencyName = "Order Resources", decorIds = {1801, 1802} },
            { npcId = 253387, npcName = "Selfira Ambergrove", cost = 1000, currencyName = "Order Resources", decorIds = {675, 676, 677, 1695, 1881, 1884, 1886, 1887, 1889, 8195, 15453} },
            { npcId = 106901, npcName = "Sylvia Hartshorn", cost = 800, currencyName = "Order Resources", decorIds = {675, 677, 1695, 8195, 15453} },
            { npcId = 112634, npcName = "Hilseth Travelstride", cost = 400, currencyName = "Order Resources", decorIds = {679, 1694} },
            { npcId = 109306, npcName = "Myria Glenbrook", decorIds = {1692, 1882, 1883} },
        },
        ["Valdrakken"] = {
            { npcId = 196637, npcName = "Tethalash", cost = 250, decorIds = {5556, 5558, 5559, 5560, 5689} },
            { npcId = 193659, npcName = "Provisioner Thom", cost = 600, currencyName = "Dragon Isles Supplies", decorIds = {7835} },
            { npcId = 253067, npcName = "Silvrath", cost = 600, currencyName = "Dragon Isles Supplies", decorIds = {2469, 2594, 4159, 4160, 4168, 4477, 4478, 4479, 4481, 10963, 11164} },
            { npcId = 193015, npcName = "Unatos", cost = 10, currencyName = "Dragon Isles Supplies", decorIds = {4159, 4168, 4478, 10962, 10963} },
            { npcId = 199605, npcName = "Evantkis", cost = 7500, currencyName = "Dragon Isles Supplies", decorIds = {4180} },
        },
        ["Vale of Eternal Blossoms"] = {
            { npcId = 64605, npcName = "Tan Shin Tiao", cost = 800, decorIds = {1172, 3832, 3833, 3993, 3995, 11873} },
            { npcId = 64001, npcName = "Sage Lotusbloom", cost = 500, decorIds = {15605} },
            { npcId = 62088, npcName = "Lali the Assistant", cost = 2000, decorIds = {767, 11453, 11456, 11457} },
        },
        ["Valley of the Four Winds"] = {
            { npcId = 58706, npcName = "Gina Mudclaw", cost = 800, decorIds = {1201, 3840, 3874, 3877, 4488} },
        },
        ["Voidstorm"] = {
            { npcId = 257632, npcName = "Chel the Chip", decorIds = {11323, 15484, 15489, 15851} },
            { npcId = 259922, npcName = "Void Researcher Aemely", decorIds = {14554, 14602, 14631, 15071, 15579, 15597, 15757, 15768, 15890, 15891, 15894, 18617, 18800} },
            { npcId = 248328, npcName = "Void Researcher Anomander", decorIds = {5132, 14592, 14593, 14596, 14603, 14632, 14634, 15260, 15575, 15578, 15581, 15584, 15597, 15769} },
        },
        ["Warspear"] = {
            { npcId = 86037, npcName = "Ravenspeaker Skeega", cost = 8, decorIds = {12203, 12206, 12207} },
        },
        ["Wetlands"] = {
            { npcId = 3178, npcName = "Stuart Fleming", decorIds = {11495} },
        },
        ["Zul'Aman"] = {
            { npcId = 260180, npcName = "Depthdiver Tu'nakit", decorIds = {12140, 12141, 12142, 12143, 15486, 15487} },
            { npcId = 240279, npcName = "Magovu", decorIds = {11324, 11326, 11327, 11333, 11334, 11936, 12154, 14204, 14350, 14351, 14352, 15158, 15160, 15571, 15596} },
            { npcId = 254944, npcName = "Tajaka Sawtusk", decorIds = {1148, 10858, 11325, 11328, 15490, 15492, 15572, 15573, 15743, 15744, 15745, 16092} },
            { npcId = 255098, npcName = "Jan'zel", decorIds = {15411} },
            { npcId = 255095, npcName = "Kuvahn", decorIds = {15458} },
        },
        ["Zuldazar"] = {
            { npcId = 252326, npcName = "T'lama", cost = 400, currencyName = "War Resources", decorIds = {1175, 1179, 1180, 1183, 1185, 1188, 1189, 1191, 1192, 1193, 1196, 1197, 1205, 1310, 1417, 1418, 1697, 11319, 11489} },
            { npcId = 148924, npcName = "Provisioner Mukra", cost = 150, currencyName = "War Resources", decorIds = {839, 932, 937, 938, 939, 940, 949} },
            { npcId = 251921, npcName = "Arcanist Peroleth", cost = 200, currencyName = "War Resources", decorIds = {864} },
        },
    },
}
local CodexNPCLocationData = {
    [1247] = { uiMapId = 27, x = 54.4, y = 50.8, faction = "Alliance" },
    [1465] = { uiMapId = 48, x = 35.4, y = 48.8, faction = "Alliance" },
    [2140] = { uiMapId = 21, x = 44.0, y = 39.8, faction = "Horde" },
    [2483] = { uiMapId = 50, x = 43.6, y = 23.0 },
    [3178] = { uiMapId = 56, x = 6.2, y = 57.4, faction = "Alliance" },
    [13217] = { uiMapId = 25, x = 44.6, y = 46.4 },
    [14624] = { uiMapId = 32, x = 38.4, y = 28.4 },
    [16528] = { uiMapId = 95, x = 47.4, y = 32.0, faction = "Horde" },
    [23995] = { uiMapId = 70, x = 41.8, y = 74.0 },
    [25206] = { uiMapId = 114, x = 43.0, y = 13.8 },
    [27391] = { uiMapId = 116, x = 32.4, y = 60.0, faction = "Alliance" },
    [28038] = { uiMapId = 119, x = 26.8, y = 59.2 },
    [44114] = { uiMapId = 47, x = 20.2, y = 58.2, faction = "Alliance" },
    [44337] = { uiMapId = 17, x = 45.8, y = 88.4, faction = "Alliance" },
    [49386] = { uiMapId = 241, x = 48.6, y = 30.4, faction = "Alliance" },
    [49877] = { uiMapId = 84, x = 67.4, y = 72.4, faction = "Alliance" },
    [50304] = {
        { uiMapId = 90, x = 63.0, y = 48.2, faction = "Horde" },
        { uiMapId = 85, x = 56.4, y = 90.0, faction = "Horde" },
    },
    [50307] = {
        { uiMapId = 84, x = 56.2, y = 13.4, faction = "Alliance" },
        { uiMapId = 89, x = 37.0, y = 47.4, faction = "Alliance" },
    },
    [50309] = { uiMapId = 87, x = 55.4, y = 47.4, faction = "Alliance" },
    [50483] = { uiMapId = 88, x = 46.4, y = 51.0, faction = "Horde" },
    [58414] = { uiMapId = 371, x = 56.6, y = 44.4 },
    [58706] = { uiMapId = 376, x = 52.2, y = 48.6 },
    [59698] = { uiMapId = 379, x = 57.2, y = 61.0 },
    [62088] = {
        { uiMapId = 390, x = 82.4, y = 30.4 },
        { uiMapId = 1530, x = 83.2, y = 28.2 },
    },
    [64001] = { uiMapId = 390, x = 62.6, y = 23.2 },
    [64605] = { uiMapId = 390, x = 82.2, y = 29.4 },
    [76872] = { uiMapId = 590, x = 36.4, y = 40.4, faction = "Horde" },
    [78564] = { uiMapId = 584, x = 38.0, y = 33.2, faction = "Alliance" },
    [79774] = { uiMapId = 590, x = 43.4, y = 47.0, faction = "Horde" },
    [79812] = { uiMapId = 590, x = 59.4, y = 49.8, faction = "Horde" },
    [81133] = { uiMapId = 539, x = 46.2, y = 39.2, faction = "Alliance" },
    [85427] = { uiMapId = 584, x = 33.4, y = 49.4, faction = "Alliance" },
    [85932] = { uiMapId = 622, x = 46.4, y = 76.2, faction = "Alliance" },
    [85946] = { uiMapId = 622, x = 44.4, y = 75.2, faction = "Alliance" },
    [85950] = { uiMapId = 622, x = 41.2, y = 60.6, faction = "Alliance" },
    [86037] = { uiMapId = 624, x = 52.4, y = 58.8, faction = "Horde" },
    [86776] = { uiMapId = 590, x = 51.4, y = 61.4, faction = "Horde" },
    [86779] = { uiMapId = 590, x = 51.4, y = 61.4, faction = "Horde" },
    [87015] = { uiMapId = 590, x = 51.2, y = 61.4, faction = "Horde" },
    [87312] = { uiMapId = 590, x = 51.2, y = 64.4, faction = "Horde" },
    [87775] = { uiMapId = 542, x = 46.6, y = 45.0 },
    [88220] = { uiMapId = 584, x = 31.8, y = 49.4, faction = "Alliance" },
    [88223] = { uiMapId = 584, x = 36.2, y = 36.0, faction = "Alliance" },
    [89939] = { uiMapId = 630, x = 47.8, y = 23.2 },
    [93550] = { uiMapId = 646, x = 99.4, y = 57.2 },
    [93971] = { uiMapId = 680, x = 40.2, y = 69.6 },
    [97140] = { uiMapId = 680, x = 36.4, y = 46.8 },
    [100196] = { uiMapId = 23, x = 75.4, y = 49.0 },
    [103693] = { uiMapId = 739, x = 44.0, y = 47.2 },
    [105333] = { uiMapId = 627, x = 67.0, y = 60.2 },
    [105986] = { uiMapId = 627, x = 26.2, y = 33.8 },
    [106901] = { uiMapId = 641, x = 54.6, y = 73.2 },
    [106902] = { uiMapId = 650, x = 38.2, y = 45.4 },
    [108017] = { uiMapId = 650, x = 46.8, y = 61.8 },
    [108537] = { uiMapId = 650, x = 41.6, y = 10.4 },
    [109306] = { uiMapId = 641, x = 60.0, y = 84.8 },
    [112318] = { uiMapId = 726, x = 30.4, y = 60.4 },
    [112323] = { uiMapId = 747, x = 39.8, y = 25.8 },
    [112338] = { uiMapId = 709, x = 50.4, y = 59.0 },
    [112392] = { uiMapId = 695, x = 55.8, y = 24.0 },
    [112401] = { uiMapId = 702, x = 38.4, y = 24.2 },
    [112407] = { uiMapId = 720, x = 57.0, y = 43.4 },
    [112634] = { uiMapId = 641, x = 56.4, y = 80.2 },
    [112716] = { uiMapId = 627, x = 43.4, y = 49.4 },
    [115736] = { uiMapId = 680, x = 36.4, y = 45.8 },
    [127151] = {
        { uiMapId = 830, x = 63.8, y = 89.4 },
        { uiMapId = 882, x = 53.4, y = 90.8 },
        { uiMapId = 885, x = 78.0, y = 34.8 },
    },
    [135459] = { uiMapId = 863, x = 39.0, y = 79.4, faction = "Horde" },
    [142115] = { uiMapId = 1161, x = 67.4, y = 41.2 },
    [144129] = { uiMapId = 242, x = 50.0, y = 32.2, faction = "Alliance" },
    [145695] = { uiMapId = 503, x = 46.4, y = 27.4, faction = "Horde" },
    [148923] = { uiMapId = 1165, x = 44.4, y = 94.4, faction = "Horde" },
    [148924] = { uiMapId = 1165, x = 51.2, y = 95.2, faction = "Horde" },
    [150716] = { uiMapId = 1462, x = 73.6, y = 36.4 },
    [151941] = { uiMapId = 499, x = 49.6, y = 27.2, faction = "Alliance" },
    [152194] = { uiMapId = 1473, x = 46.4, y = 70.4 },
    [162804] = { uiMapId = 1543, x = 46.8, y = 41.6 },
    [174710] = { uiMapId = 1699, x = 53.4, y = 24.4 },
    [188265] = { uiMapId = 2022, x = 47.8, y = 82.0 },
    [189226] = { uiMapId = 2022, x = 47.0, y = 82.4 },
    [190155] = { uiMapId = 2022, x = 55.0, y = 30.8 },
    [193015] = { uiMapId = 2112, x = 58.0, y = 35.4 },
    [193659] = { uiMapId = 2112, x = 36.4, y = 50.4 },
    [196637] = { uiMapId = 2112, x = 25.4, y = 33.4 },
    [199605] = { uiMapId = 2112, x = 58.2, y = 57.4 },
    [209192] = {
        { uiMapId = 2024, x = 27.0, y = 46.4 },
        { uiMapId = 2025, x = 61.4, y = 31.4 },
    },
    [209220] = { uiMapId = 2025, x = 52.2, y = 80.8 },
    [210608] = {
        { uiMapId = 2022, x = 58.4, y = 67.8 },
        { uiMapId = 2023, x = 64.0, y = 41.6 },
        { uiMapId = 2024, x = 45.6, y = 39.8 },
        { uiMapId = 2025, x = 51.2, y = 43.2 },
    },
    [211065] = { uiMapId = 217, x = 60.4, y = 92.4 },
    [216284] = { uiMapId = 2239, x = 54.0, y = 60.4, faction = "Alliance" },
    [216285] = { uiMapId = 2239, x = 48.2, y = 53.6, faction = "Alliance" },
    [216286] = { uiMapId = 2239, x = 46.4, y = 70.4, faction = "Alliance" },
    [216888] = { uiMapId = 217, x = 65.2, y = 47.2 },
    [217642] = { uiMapId = 2215, x = 42.8, y = 55.8 },
    [218202] = { uiMapId = 2213, x = 50.0, y = 31.6 },
    [219318] = { uiMapId = 2339, x = 57.0, y = 60.4 },
    [221390] = { uiMapId = 2214, x = 43.2, y = 32.8 },
    [223728] = { uiMapId = 2339, x = 39.2, y = 24.2 },
    [226205] = { uiMapId = 2248, x = 74.4, y = 45.2 },
    [226994] = { uiMapId = 2346, x = 34.0, y = 71.4 },
    [231396] = { uiMapId = 2346, x = 30.4, y = 38.8 },
    [231405] = { uiMapId = 2346, x = 63.2, y = 16.2 },
    [231406] = { uiMapId = 2346, x = 39.0, y = 22.0 },
    [231407] = { uiMapId = 2346, x = 53.2, y = 72.4 },
    [231408] = { uiMapId = 2346, x = 27.2, y = 72.4 },
    [231409] = { uiMapId = 2346, x = 43.6, y = 50.2 },
    [235252] = { uiMapId = 2472, x = 40.6, y = 29.2 },
    [235314] = { uiMapId = 2472, x = 43.2, y = 35.2 },
    [239333] = { uiMapId = 2346, x = 26.0, y = 43.0 },
    [240465] = { uiMapId = 2351, x = 68.2, y = 75.4 },
    [240852] = { uiMapId = 2215, x = 28.2, y = 56.2 },
    [246721] = { uiMapId = 1161, x = 56.2, y = 46.0, faction = "Alliance" },
    [248525] = {
        { uiMapId = 2351, x = 54.2, y = 56.0, faction = "Horde" },
        { uiMapId = 2352, x = 52.8, y = 37.8, faction = "Alliance" },
    },
    [248594] = { uiMapId = 680, x = 50.8, y = 77.8 },
    [249196] = { uiMapId = 241, x = 49.8, y = 81.2 },
    [249684] = {
        { uiMapId = 2351, x = 54.2, y = 56.2, faction = "Horde" },
        { uiMapId = 2352, x = 53.0, y = 38.0, faction = "Alliance" },
    },
    [250820] = {
        { uiMapId = 2351, x = 54.2, y = 56.0, faction = "Horde" },
        { uiMapId = 2352, x = 53.0, y = 38.0, faction = "Alliance" },
    },
    [251042] = { uiMapId = 619, x = 45.8, y = 67.8 },
    [251911] = { uiMapId = 2346, x = 43.2, y = 50.4 },
    [251921] = { uiMapId = 862, x = 58.0, y = 62.4, faction = "Horde" },
    [252043] = { uiMapId = 627, x = 66.4, y = 33.0, faction = "Horde" },
    [252312] = {
        { uiMapId = 84, x = 56.0, y = 76.4, faction = "Alliance" },
        { uiMapId = 85, x = 52.6, y = 88.4, faction = "Horde" },
        { uiMapId = 2339, x = 52.8, y = 68.6 },
    },
    [252313] = { uiMapId = 942, x = 59.4, y = 69.4 },
    [252316] = { uiMapId = 895, x = 53.4, y = 31.2, faction = "Alliance" },
    [252326] = { uiMapId = 862, x = 32.4, y = 65.4, faction = "Horde" },
    [252345] = { uiMapId = 1161, x = 70.8, y = 15.4, faction = "Alliance" },
    [252498] = { uiMapId = 641, x = 42.0, y = 59.4 },
    [252520] = { uiMapId = 57, x = 55.2, y = 89.2, faction = "Alliance" },
    [252605] = {
        { uiMapId = 2351, x = 54.4, y = 56.2, faction = "Horde" },
        { uiMapId = 2352, x = 53.0, y = 38.2, faction = "Alliance" },
    },
    [252887] = { uiMapId = 2214, x = 43.2, y = 32.8 },
    [252901] = { uiMapId = 2248, x = 42.0, y = 73.0 },
    [252910] = { uiMapId = 2339, x = 54.4, y = 57.2 },
    [252969] = { uiMapId = 680, x = 49.6, y = 62.8 },
    [253067] = { uiMapId = 2112, x = 71.4, y = 49.4 },
    [253086] = { uiMapId = 2151, x = 35.2, y = 56.8 },
    [253227] = { uiMapId = 241, x = 49.6, y = 29.4 },
    [253232] = { uiMapId = 87, x = 75.4, y = 9.4, faction = "Alliance" },
    [253235] = { uiMapId = 87, x = 24.2, y = 42.4, faction = "Alliance" },
    [253387] = { uiMapId = 641, x = 54.2, y = 72.4 },
    [253434] = { uiMapId = 680, x = 26.2, y = 32.2 },
    [253596] = { uiMapId = 2351, x = 53.6, y = 57.4 },
    [254603] = { uiMapId = 84, x = 77.2, y = 65.8, faction = "Alliance" },
    [254606] = { uiMapId = 85, x = 38.8, y = 72.0, faction = "Horde" },
    [255101] = { uiMapId = 680, x = 45.4, y = 69.2 },
    [255203] = { uiMapId = 2352, x = 52.0, y = 38.2 },
    [255213] = { uiMapId = 2352, x = 52.0, y = 38.4 },
    [255216] = { uiMapId = 2352, x = 52.2, y = 37.8 },
    [255218] = { uiMapId = 2352, x = 52.2, y = 37.8 },
    [255221] = { uiMapId = 2352, x = 53.4, y = 40.8 },
    [255222] = { uiMapId = 2352, x = 62.4, y = 80.0 },
    [255228] = { uiMapId = 2352, x = 61.6, y = 79.0 },
    [255230] = { uiMapId = 2352, x = 62.2, y = 80.2 },
    [255278] = { uiMapId = 2351, x = 54.0, y = 59.0 },
    [255297] = { uiMapId = 2351, x = 54.0, y = 59.0 },
    [255298] = { uiMapId = 2351, x = 53.4, y = 58.4 },
    [255299] = { uiMapId = 2351, x = 53.4, y = 58.4 },
    [255301] = { uiMapId = 2351, x = 53.6, y = 57.4 },
    [255319] = { uiMapId = 2351, x = 39.8, y = 73.2 },
    [255325] = { uiMapId = 2351, x = 39.8, y = 72.8 },
    [255326] = { uiMapId = 2351, x = 39.8, y = 70.2 },
    [256071] = { uiMapId = 84, x = 49.4, y = 80.2, faction = "Alliance" },
    [256119] = { uiMapId = 85, x = 58.4, y = 50.4, faction = "Horde" },
    [256750] = { uiMapId = 2352, x = 58.2, y = 61.6 },
    [256783] = { uiMapId = 2214, x = 43.4, y = 33.2 },
    [256826] = { uiMapId = 680, x = 15.0, y = 53.4 },
    [256946] = { uiMapId = 535, x = 70.4, y = 57.4 },
    [257307] = { uiMapId = 2352, x = 61.4, y = 79.2, faction = "Alliance" },
    [257897] = {
        { uiMapId = 2351, x = 54.2, y = 56.2, faction = "Horde" },
        { uiMapId = 2352, x = 53.0, y = 38.0, faction = "Alliance" },
    },
}

HomeData.CodexVendorSourceData = CodexVendorSourceData
HomeData.CodexNPCLocationData = CodexNPCLocationData

HomeData.vendorCatalog = {
    [245603] = { vendorName = "Archivist Ta'lora", zone = "Azj-Kahet", mapID = 2256, x = 56.2, y = 43.8, sourceType = "vendor", requirementLabel = "Reputation" },
    [245605] = { vendorName = "Archivist Ta'lora", zone = "Azj-Kahet", mapID = 2256, x = 56.2, y = 43.8, sourceType = "vendor", requirementLabel = "Reputation" },
    [245620] = { vendorName = "Quartermaster Rallia", zone = "Isle of Dorn", mapID = 2248, x = 52.4, y = 38.6, sourceType = "vendor", requirementLabel = "Quest" },
    [245624] = { vendorName = "Quartermaster Rallia", zone = "Isle of Dorn", mapID = 2248, x = 52.4, y = 38.6, sourceType = "vendor", requirementLabel = "Quest" },
    [246426] = { vendorName = "Militant Brenna", zone = "Hallowfall", mapID = 2255, x = 47.8, y = 55.2, sourceType = "vendor", requirementLabel = "Reputation" },
    [246490] = { vendorName = "Militant Brenna", zone = "Hallowfall", mapID = 2255, x = 47.8, y = 55.2, sourceType = "vendor", requirementLabel = "Reputation" },
    [246491] = { vendorName = "Militant Brenna", zone = "Hallowfall", mapID = 2255, x = 47.8, y = 55.2, sourceType = "vendor", requirementLabel = "Reputation" },
    [248796] = { vendorName = "Curator Alvid", zone = "Dornogal", mapID = 2339, x = 43.1, y = 49.7, sourceType = "vendor", requirementLabel = "Achievement" },
    [250230] = { vendorName = "Renown Steward", zone = "Dornogal", mapID = 2339, x = 46.7, y = 48.1, sourceType = "vendor", requirementLabel = "Achievement" },
    [256425] = { vendorName = "Glory Broker", zone = "Dornogal", mapID = 2339, x = 49.8, y = 39.1, sourceType = "vendor", requirementLabel = "Achievement" },
    [256896] = { vendorName = "Glory Broker", zone = "Dornogal", mapID = 2339, x = 49.8, y = 39.1, sourceType = "vendor", requirementLabel = "Achievement" },
}

HomeData.decorMeta = {
    [245603] = { decorID = 1794, reqRep = true, sourceType = "vendor", expansion = "tww" },
    [245605] = { decorID = 1796, reqRep = true, sourceType = "vendor", expansion = "tww" },
    [245620] = { decorID = 1829, reqQuest = true, sourceType = "vendor", expansion = "tww" },
    [245624] = { decorID = 1833, reqQuest = true, sourceType = "vendor", expansion = "tww" },
    [246426] = { decorID = 2243, reqRep = true, sourceType = "vendor", expansion = "tww" },
    [246490] = { decorID = 2333, reqRep = true, sourceType = "vendor", expansion = "tww" },
    [246491] = { decorID = 2334, reqRep = true, sourceType = "vendor", expansion = "tww" },
    [248796] = { decorID = 4813, reqAchiev = true, sourceType = "vendor", expansion = "tww" },
    [250230] = { decorID = 7571, reqAchiev = true, sourceType = "vendor", expansion = "tww" },
    [256425] = { decorID = 11160, reqAchiev = true, sourceType = "vendor", expansion = "midnight" },
    [256896] = { decorID = 11296, reqAchiev = true, sourceType = "vendor", expansion = "midnight" },
}

local sourceTypeLabels = {
    vendor = "Vendor",
    achievement = "Achievement",
    quest = "Quest",
    treasure = "Treasure",
    profession = "Profession",
}

local function shallowCopy(src)
    local out = {}
    if type(src) == "table" then
        for k, v in pairs(src) do
            out[k] = v
        end
    end
    return out
end

local function buildRequirementParts(meta)
    if type(meta) ~= "table" then
        return {}
    end
    local parts = {}
    if meta.reqQuest then parts[#parts + 1] = "Quest gated" end
    if meta.reqRep then parts[#parts + 1] = "Reputation gated" end
    if meta.reqAchiev then parts[#parts + 1] = "Achievement gated" end
    return parts
end

function HomeData:GetMeta(itemID)
    return self.decorMeta[tonumber(itemID)]
end

function HomeData:GetSourceInfo(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local source = self.vendorCatalog[itemID]
    local meta = self.decorMeta[itemID]
    if not source and not meta then
        if Villa.HITData and Villa.HITData.DecorItems and Villa.HITData.DecorItems[itemID] then
            local hit = Villa.HITData.DecorItems[itemID]
            return { decorID = itemID, sourceType = "vendor", sourceLabel = "HousingItemTracker", requirementText = hit.quest or hit.achievement or hit.profession, category = hit.category, subcategory = hit.subcategory, name = hit.name }
        end
        return nil
    end

    local info = shallowCopy(source)
    if meta then
        for k, v in pairs(meta) do
            if info[k] == nil then info[k] = v end
        end
    end

    info.requirementParts = buildRequirementParts(info)
    info.requirementText = #info.requirementParts > 0 and table.concat(info.requirementParts, " • ") or nil
    info.sourceLabel = sourceTypeLabels[info.sourceType] or "Unknown"
    if info.requirementLabel and not info.requirementText then
        info.requirementText = info.requirementLabel .. " gated"
    end
    return info
end

function HomeData:GetRequirementText(itemID)
    local info = self:GetSourceInfo(itemID)
    return info and info.requirementText or nil
end

function HomeData:GetDecorDisplayName(entry)
    if type(entry) ~= "table" then
        return tostring(entry)
    end
    if entry.name and entry.name ~= "" then
        return entry.name
    end
    if entry.decorID and Villa.HITData and Villa.HITData.DecorItems and Villa.HITData.DecorItems[entry.decorID] and Villa.HITData.DecorItems[entry.decorID].name then
        return Villa.HITData.DecorItems[entry.decorID].name
    end
    if entry.itemID and C_Item and C_Item.GetItemNameByID then
        local itemName = C_Item.GetItemNameByID(entry.itemID)
        if itemName and itemName ~= "" then
            return itemName
        end
    end
    if entry.decorID then
        return "Decor #" .. tostring(entry.decorID)
    end
    if entry.itemID then
        return "Item " .. tostring(entry.itemID)
    end
    return "Unknown Decor"
end

function HomeData:IsEntryCollected(entry)
    if type(entry) ~= "table" then
        return false
    end
    -- decorID IS the catalog recordID — the canonical, reliable ownership key.
    -- Prefer it over itemID (many donor entries only carry a decorID, and some
    -- stuff a decorID into the itemID field). Villa:IsDecorRecordCollected uses
    -- C_HousingCatalog.GetCatalogEntryInfoByRecordID + C_Housing.IsDecorCollected.
    if entry.decorID and Villa.IsDecorRecordCollected then
        if Villa:IsDecorRecordCollected(entry.decorID) then
            return true
        end
    end
    if entry.itemID and Villa.IsKnownDecorItem then
        if Villa:IsKnownDecorItem(entry.itemID) then
            return true
        end
    end
    return entry.isCollected == true
end

function HomeData:GetZoneRootMapID(mapID)
    mapID = tonumber(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then return mapID end
    local last = mapID
    local seen = {}
    local cursor = mapID
    while cursor and not seen[cursor] do
        seen[cursor] = true
        local info = C_Map.GetMapInfo(cursor)
        if not info or not info.parentMapID or info.parentMapID == 0 then break end
        last = info.parentMapID
        cursor = info.parentMapID
    end
    return last or mapID
end

local function appendVendorRecord(results, grouped, vendorName, mapID, x, y, zone, currency, requirementLabel, itemEntry, cityName, npcID, sourceTag)
    local key = table.concat({ vendorName or "Unknown Vendor", tostring(mapID or 0), tostring(math.floor((x or 0) * 10)), tostring(math.floor((y or 0) * 10)), tostring(npcID or 0), sourceTag or "villa" }, "|")
    local entry = grouped[key]
    if not entry then
        entry = {
            npcID = npcID,
            name = vendorName or "Unknown Vendor",
            zone = zone or "Unknown Zone",
            mapID = mapID,
            x = x,
            y = y,
            currency = currency or requirementLabel or "unknown",
            requirementLabel = requirementLabel,
            items = {},
            cityName = cityName,
            sourceTag = sourceTag,
        }
        grouped[key] = entry
        results[#results + 1] = entry
    end
    entry.items[#entry.items + 1] = itemEntry
end

function HomeData:GetMergedVendorList()
    local results = {}
    local grouped = {}

    local function appendExistingVendor(vendor)
        if type(vendor) ~= "table" then
            return
        end
        local clone = shallowCopy(vendor)
        clone.items = {}
        clone.locations = {}
        for _, loc in ipairs(vendor.locations or {}) do
            clone.locations[#clone.locations + 1] = shallowCopy(loc)
        end
        if #clone.locations == 0 and (clone.mapID or clone.x or clone.y) then
            clone.locations[1] = { mapID = clone.mapID, x = clone.x, y = clone.y, zone = clone.zone, cityName = clone.cityName }
        end
        for _, item in ipairs(vendor.items or {}) do
            local row = shallowCopy(item)
            row.name = self:GetDecorDisplayName(row)
            row.isCollected = self:IsEntryCollected(row)
            clone.items[#clone.items + 1] = row
        end
        clone.locationCount = #(clone.locations or {})
        local key = clone.vendorKey or table.concat({ clone.name or "Unknown Vendor", tostring(clone.npcID or 0), tostring(clone.sourceTag or "hybrid") }, "|")
        grouped[key] = clone
        results[#results + 1] = clone
    end

    if Villa.NormalizedData and Villa.NormalizedData.GetVendorList then
        for _, vendor in ipairs(Villa.NormalizedData:GetVendorList()) do
            appendExistingVendor(vendor)
        end
    else
        -- Fallback for transition safety if normalized provider data is unavailable.
        for itemID, source in pairs(self.vendorCatalog) do
            local meta = self.decorMeta[itemID] or {}
            local itemEntry = {
                itemID = itemID,
                decorID = meta.decorID,
                sourceType = source.sourceType or meta.sourceType or "vendor",
                requirementText = self:GetRequirementText(itemID),
                sourceLabel = sourceTypeLabels[source.sourceType or meta.sourceType] or "Vendor",
                zone = source.zone,
                cityName = source.cityName,
                mapID = source.mapID,
                x = source.x,
                y = source.y,
            }
            itemEntry.name = self:GetDecorDisplayName(itemEntry)
            itemEntry.isCollected = self:IsEntryCollected(itemEntry)
            appendVendorRecord(results, grouped, source.vendorName, source.mapID, source.x, source.y, source.zone, source.requirementLabel, source.requirementLabel, itemEntry, source.cityName, source.npcID, "villa")
        end
    end

    for _, vendor in ipairs(Villa.db and Villa.db.customVendors or {}) do
        local customEntry = { itemID = nil, decorID = nil, name = "Manual vendor record", sourceType = "vendor", sourceLabel = "Vendor" }
        appendVendorRecord(results, grouped, vendor.name, vendor.mapID, vendor.x, vendor.y, vendor.zone, vendor.currency, vendor.requirementLabel, customEntry, vendor.cityName, vendor.npcID, "custom")
    end

    for _, vendor in ipairs(results) do
        table.sort(vendor.items, function(a, b)
            return tostring(HomeData:GetDecorDisplayName(a)):lower() < tostring(HomeData:GetDecorDisplayName(b)):lower()
        end)
    end
    table.sort(results, function(a, b)
        if (a.zone or "") ~= (b.zone or "") then
            return (a.zone or "") < (b.zone or "")
        end
        return (a.name or "") < (b.name or "")
    end)
    return results
end

function HomeData:IterVendorSourcesForMap(mapID, includeParentMatches)
    local results = {}
    mapID = tonumber(mapID)
    if not mapID then return results end

    local function mapMatches(sourceMapID)
        sourceMapID = tonumber(sourceMapID)
        if sourceMapID == mapID then return true end
        if not includeParentMatches or not sourceMapID then return false end
        local cursor, seen = sourceMapID, {}
        while cursor and not seen[cursor] do
            seen[cursor] = true
            local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(cursor)
            cursor = info and info.parentMapID or nil
            if cursor == mapID then return true end
        end
        return false
    end

    for _, vendor in ipairs(self:GetMergedVendorList()) do
        local locations = vendor.locations or {}
        if #locations == 0 then
            locations = { { mapID = vendor.mapID, x = vendor.x, y = vendor.y, zone = vendor.zone, cityName = vendor.cityName } }
        end
        for _, location in ipairs(locations) do
            if mapMatches(location.mapID) then
                for _, item in ipairs(vendor.items or {}) do
                    local row = shallowCopy(item)
                    row.vendorName = vendor.name
                    row.vendorKey = vendor.vendorKey
                    row.mapID = row.mapID or location.mapID or vendor.mapID
                    row.x = row.x or location.x or vendor.x
                    row.y = row.y or location.y or vendor.y
                    row.zone = row.zone or location.zone or vendor.zone
                    row.cityName = row.cityName or location.cityName or vendor.cityName
                    row.requirementText = row.requirementText or vendor.requirementLabel
                    row.isCollected = self:IsEntryCollected(row)
                    row.name = self:GetDecorDisplayName(row)
                    results[#results + 1] = row
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if (a.vendorName or "") ~= (b.vendorName or "") then
            return (a.vendorName or "") < (b.vendorName or "")
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return results
end


function HomeData:GetVendorWaypoint(vendor)
    if type(vendor) ~= "table" then
        return nil, nil, nil
    end
    local locations = vendor.locations or {}
    local primary = locations[1]
    if primary then
        return primary.mapID or vendor.mapID, primary.x or vendor.x, primary.y or vendor.y
    end
    return vendor.mapID, vendor.x, vendor.y
end

function HomeData:GetVendorProgress(vendor)
    local owned, total = 0, 0
    local missingNames = {}
    for _, item in ipairs((vendor and vendor.items) or {}) do
        total = total + 1
        if self:IsEntryCollected(item) then
            owned = owned + 1
        elseif #missingNames < 8 then
            missingNames[#missingNames + 1] = self:GetDecorDisplayName(item)
        end
    end
    return owned, total, missingNames
end

function HomeData:GetZoneSummary(mapID, includeParentMatches)
    local summary = {
        mapID = tonumber(mapID),
        vendorCount = 0,
        sourceCount = 0,
        collectedCount = 0,
        missingCount = 0,
    }
    if not summary.mapID then
        return summary
    end

    local vendorsSeen = {}
    for _, entry in ipairs(self:IterVendorSourcesForMap(summary.mapID, includeParentMatches)) do
        summary.sourceCount = summary.sourceCount + 1
        if entry.isCollected then
            summary.collectedCount = summary.collectedCount + 1
        else
            summary.missingCount = summary.missingCount + 1
        end
        local vendorKey = tostring(entry.vendorKey or (tostring(entry.vendorName or "Unknown") .. "|" .. tostring(entry.mapID or 0) .. "|" .. tostring(entry.x or 0) .. "|" .. tostring(entry.y or 0)))
        if not vendorsSeen[vendorKey] then
            vendorsSeen[vendorKey] = true
            summary.vendorCount = summary.vendorCount + 1
        end
    end
    return summary
end