local AddonFolderName, private = ...
private = private or {}
private.zoneExpansionSkillMap = {
    -- Continents / Zones
    [0] = { expansion = "Classic", skillLineID = 2592 }, -- Eastern Kingdoms
    [1] = { expansion = "Classic", skillLineID = 2592 }, -- Kalimdor
    [30] = { expansion = "Classic", skillLineID = 2592 }, -- Alterac Valley
    [33] = { expansion = "Classic", skillLineID = 2592 }, -- Shadowfang Keep
    [34] = { expansion = "Classic", skillLineID = 2592 }, -- The Stockade
    [36] = { expansion = "Classic", skillLineID = 2592 }, -- The Deadmines
    [43] = { expansion = "Classic", skillLineID = 2592 }, -- Wailing Caverns
    [47] = { expansion = "Classic", skillLineID = 2592 }, -- Razorfen Kraul
    [48] = { expansion = "Classic", skillLineID = 2592 }, -- Blackfathom Deeps
    [70] = { expansion = "Classic", skillLineID = 2592 }, -- Uldaman
    [90] = { expansion = "Classic", skillLineID = 2592 }, -- Gnomeregan
    [109] = { expansion = "Classic", skillLineID = 2592 }, -- The Temple of Atal'Hakkar
    [129] = { expansion = "Classic", skillLineID = 2592 }, -- Razorfen Downs
    [209] = { expansion = "Classic", skillLineID = 2592 }, -- Zul'Farrak
    [229] = { expansion = "Classic", skillLineID = 2592 }, -- Blackrock Spire
    [230] = { expansion = "Classic", skillLineID = 2592 }, -- Blackrock Depths
    [249] = { expansion = "Northrend", skillLineID = 2590 }, -- Onyxia's Lair
    [269] = { expansion = "Outland", skillLineID = 2591 }, -- The Black Morass
    [329] = { expansion = "Classic", skillLineID = 2592 }, -- Stratholme
    [349] = { expansion = "Classic", skillLineID = 2592 }, -- Maraudon
    [389] = { expansion = "Classic", skillLineID = 2592 }, -- Ragefire Chasm
    [409] = { expansion = "Classic", skillLineID = 2592 }, -- Molten Core
    [429] = { expansion = "Classic", skillLineID = 2592 }, -- Dire Maul
    [469] = { expansion = "Classic", skillLineID = 2592 }, -- Blackwing Lair
    [489] = { expansion = "Classic", skillLineID = 2592 }, -- Warsong Gulch
    [509] = { expansion = "Classic", skillLineID = 2592 }, -- Ruins of Ahn'Qiraj
    [529] = { expansion = "Classic", skillLineID = 2592 }, -- Arathi Basin (Classic)
    [530] = { expansion = "Outland", skillLineID = 2591 }, -- Ghostlands
    [531] = { expansion = "Classic", skillLineID = 2592 }, -- Temple of Ahn'Qiraj
    [532] = { expansion = "Outland", skillLineID = 2591 }, -- Karazhan
    [533] = { expansion = "Northrend", skillLineID = 2590 }, -- Naxxramas
    [534] = { expansion = "Outland", skillLineID = 2591 }, -- Hyjal Summit
    [540] = { expansion = "Outland", skillLineID = 2591 }, -- The Shattered Halls
    [542] = { expansion = "Outland", skillLineID = 2591 }, -- The Blood Furnace
    [543] = { expansion = "Outland", skillLineID = 2591 }, -- Hellfire Ramparts
    [544] = { expansion = "Outland", skillLineID = 2591 }, -- Magtheridon's Lair
    [545] = { expansion = "Outland", skillLineID = 2591 }, -- The Steamvault
    [546] = { expansion = "Outland", skillLineID = 2591 }, -- The Underbog
    [547] = { expansion = "Outland", skillLineID = 2591 }, -- The Slave Pens
    [548] = { expansion = "Outland", skillLineID = 2591 }, -- Serpentshrine Cavern
    [550] = { expansion = "Outland", skillLineID = 2591 }, -- Tempest Keep
    [552] = { expansion = "Outland", skillLineID = 2591 }, -- The Arcatraz
    [553] = { expansion = "Outland", skillLineID = 2591 }, -- The Botanica
    [554] = { expansion = "Outland", skillLineID = 2591 }, -- The Mechanar
    [555] = { expansion = "Outland", skillLineID = 2591 }, -- Shadow Labyrinth
    [556] = { expansion = "Outland", skillLineID = 2591 }, -- Sethekk Halls
    [557] = { expansion = "Outland", skillLineID = 2591 }, -- Mana-Tombs
    [558] = { expansion = "Outland", skillLineID = 2591 }, -- Auchenai Crypts
    [560] = { expansion = "Outland", skillLineID = 2591 }, -- Old Hillsbrad Foothills
    [564] = { expansion = "Outland", skillLineID = 2591 }, -- Black Temple
    [565] = { expansion = "Outland", skillLineID = 2591 }, -- Gruul's Lair
    [566] = { expansion = "Outland", skillLineID = 2591 }, -- Eye of the Storm
    [568] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Zul'Aman
    [571] = { expansion = "Northrend", skillLineID = 2590 }, -- Northrend
    [572] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Ruins of Lordaeron
    [574] = { expansion = "Northrend", skillLineID = 2590 }, -- Utgarde Keep
    [575] = { expansion = "Northrend", skillLineID = 2590 }, -- Utgarde Pinnacle
    [576] = { expansion = "Northrend", skillLineID = 2590 }, -- The Nexus
    [578] = { expansion = "Northrend", skillLineID = 2590 }, -- The Oculus
    [580] = { expansion = "Outland", skillLineID = 2591 }, -- Sunwell Plateau
    [585] = { expansion = "Outland", skillLineID = 2591 }, -- Magisters' Terrace
    [595] = { expansion = "Northrend", skillLineID = 2590 }, -- The Culling of Stratholme
    [599] = { expansion = "Northrend", skillLineID = 2590 }, -- Halls of Stone
    [600] = { expansion = "Northrend", skillLineID = 2590 }, -- Drak'Tharon Keep
    [601] = { expansion = "Northrend", skillLineID = 2590 }, -- Azjol-Nerub
    [602] = { expansion = "Northrend", skillLineID = 2590 }, -- Halls of Lightning
    [603] = { expansion = "Northrend", skillLineID = 2590 }, -- Ulduar
    [604] = { expansion = "Northrend", skillLineID = 2590 }, -- Gundrak
    [607] = { expansion = "Fishing", skillLineID = 356 }, -- Strand of the Ancients
    [608] = { expansion = "Northrend", skillLineID = 2590 }, -- The Violet Hold
    [615] = { expansion = "Northrend", skillLineID = 2590 }, -- The Obsidian Sanctum
    [616] = { expansion = "Northrend", skillLineID = 2590 }, -- The Eye of Eternity
    [617] = { expansion = "Fishing", skillLineID = 356 }, -- Dalaran Arena
    [618] = { expansion = "Fishing", skillLineID = 356 }, -- The Ring of Valor
    [619] = { expansion = "Northrend", skillLineID = 2590 }, -- Ahn'kahet: The Old Kingdom
    [624] = { expansion = "Northrend", skillLineID = 2590 }, -- Vault of Archavon
    [628] = { expansion = "Fishing", skillLineID = 356 }, -- Isle of Conquest
    [631] = { expansion = "Northrend", skillLineID = 2590 }, -- Icecrown Citadel
    [632] = { expansion = "Northrend", skillLineID = 2590 }, -- The Forge of Souls
    [643] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Throne of the Tides
    [644] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Halls of Origination
    [645] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Blackrock Caverns
    [646] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Deepholm
    [649] = { expansion = "Northrend", skillLineID = 2590 }, -- Trial of the Crusader
    [650] = { expansion = "Northrend", skillLineID = 2590 }, -- Trial of the Champion
    [657] = { expansion = "Cataclysm", skillLineID = 2589 }, -- The Vortex Pinnacle
    [658] = { expansion = "Northrend", skillLineID = 2590 }, -- Pit of Saron
    [668] = { expansion = "Northrend", skillLineID = 2590 }, -- Halls of Reflection
    [669] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Blackwing Descent
    [670] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Grim Batol
    [671] = { expansion = "Cataclysm", skillLineID = 2589 }, -- The Bastion of Twilight
    [720] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Firelands
    [724] = { expansion = "Northrend", skillLineID = 2590 }, -- The Ruby Sanctum
    [725] = { expansion = "Cataclysm", skillLineID = 2589 }, -- The Stonecore
    [726] = { expansion = "Fishing", skillLineID = 356 }, -- Twin Peaks
    [727] = { expansion = "Fishing", skillLineID = 356 }, -- Silvershard Mines
    [730] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Maelstrom Zone
    [732] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Tol Barad
    [754] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Throne of the Four Winds
    [755] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Lost City of the Tol'vir
    [757] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Baradin Hold
    [761] = { expansion = "Fishing", skillLineID = 356 }, -- The Battle for Gilneas
    [859] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Zul'Gurub
    [860] = { expansion = "Pandaria", skillLineID = 2588 }, -- The Wandering Isle
    [870] = { expansion = "Pandaria", skillLineID = 2588 }, -- Pandaria
    [938] = { expansion = "Cataclysm", skillLineID = 2589 }, -- End Time
    [939] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Well of Eternity
    [940] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Hour of Twilight
    [959] = { expansion = "Pandaria", skillLineID = 2588 }, -- Shado-pan Monastery
    [960] = { expansion = "Pandaria", skillLineID = 2588 }, -- Temple of the Jade Serpent
    [961] = { expansion = "Pandaria", skillLineID = 2588 }, -- Stormstout Brewery
    [962] = { expansion = "Pandaria", skillLineID = 2588 }, -- Gate of the Setting Sun
    [967] = { expansion = "Cataclysm", skillLineID = 2589 }, -- Dragon Soul
    [968] = { expansion = "Fishing", skillLineID = 356 }, -- Eye of the Storm (Rated)
    [974] = { expansion = "Classic", skillLineID = 2592 }, -- Darkmoon Faire
    [980] = { expansion = "Fishing", skillLineID = 356 }, -- Tol'Viron Arena
    [994] = { expansion = "Pandaria", skillLineID = 2588 }, -- Mogu'Shan Palace
    [996] = { expansion = "Pandaria", skillLineID = 2588 }, -- Terrace of Endless Spring
    [998] = { expansion = "Fishing", skillLineID = 356 }, -- Temple of Kotmogu
    [1001] = { expansion = "Classic", skillLineID = 2592 }, -- Scarlet Halls
    [1004] = { expansion = "Classic", skillLineID = 2592 }, -- Scarlet Monastery
    [1007] = { expansion = "Pandaria", skillLineID = 2588 }, -- Scholomance(Pandaria)
    [1008] = { expansion = "Pandaria", skillLineID = 2588 }, -- Mogu'shan Vaults
    [1009] = { expansion = "Pandaria", skillLineID = 2588 }, -- Heart of Fear
    [1011] = { expansion = "Pandaria", skillLineID = 2588 }, -- Siege of Niuzao Temple
    [1064] = { expansion = "Pandaria", skillLineID = 2588 }, -- Isle of Thunder
    [1098] = { expansion = "Pandaria", skillLineID = 2588 }, -- Throne of Thunder
    [1105] = { expansion = "Fishing", skillLineID = 356 }, -- Deepwind Gorge
    [1116] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor
    [1134] = { expansion = "Fishing", skillLineID = 356 }, -- Tiger's Peak
    [1136] = { expansion = "Pandaria", skillLineID = 2588 }, -- Siege of Orgrimmar
    [1152] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor / FW Horde Garrison Level 1
    [1153] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor / FW Horde Garrison Level 3
    [1154] = { expansion = "Draenor", skillLineID = 2587 }, -- FW Horde Garrison Level 4
    [1158] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor / SMV Alliance Garrison Level 1
    [1159] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor / SMV Alliance Garrison Level 3
    [1160] = { expansion = "Draenor", skillLineID = 2587 }, -- SMV Alliance Garrison Level 4
    [1161] = { expansion = "Pandaria", skillLineID = 2588 }, -- Celestial Tournament
    [1175] = { expansion = "Draenor", skillLineID = 2587 }, -- Bloodmaul Slag Mines
    [1176] = { expansion = "Draenor", skillLineID = 2587 }, -- Shadowmoon Burial Grounds
    [1182] = { expansion = "Draenor", skillLineID = 2587 }, -- Auchindoun
    [1191] = { expansion = "Draenor", skillLineID = 2587 }, -- Ashran
    [1195] = { expansion = "Draenor", skillLineID = 2587 }, -- Iron Docks
    [1205] = { expansion = "Draenor", skillLineID = 2587 }, -- Blackrock Foundry
    [1208] = { expansion = "Draenor", skillLineID = 2587 }, -- Grimrail Depot
    [1209] = { expansion = "Draenor", skillLineID = 2587 }, -- Skyreach
    [1220] = { expansion = "Legion", skillLineID = 2586 }, -- Broken Isles
    [1228] = { expansion = "Draenor", skillLineID = 2587 }, -- Highmaul
    [1232] = { expansion = "Draenor", skillLineID = 2587 }, -- GOR Horde Garrison Level 0
    [1233] = { expansion = "Draenor", skillLineID = 2587 }, -- GOR Horde Garrison Level 3
    [1234] = { expansion = "Draenor", skillLineID = 2587 }, -- TAL Alliance Garrison Level 0
    [1235] = { expansion = "Draenor", skillLineID = 2587 }, -- TAL Alliance Garrison Level 3
    [1236] = { expansion = "Draenor", skillLineID = 2587 }, -- TAL Horde Garrison Level 0
    [1237] = { expansion = "Draenor", skillLineID = 2587 }, -- TAL Horde Garrison Level 3
    [1238] = { expansion = "Draenor", skillLineID = 2587 }, -- SOA Alliance Garrison Level 0
    [1239] = { expansion = "Draenor", skillLineID = 2587 }, -- SOA Alliance Garrison Level 3
    [1240] = { expansion = "Draenor", skillLineID = 2587 }, -- SOA Horde Garrison Level 0
    [1241] = { expansion = "Draenor", skillLineID = 2587 }, -- SOA Horde Garrison Level 3
    [1242] = { expansion = "Draenor", skillLineID = 2587 }, -- NAG Alliance Garrison Level 0
    [1243] = { expansion = "Draenor", skillLineID = 2587 }, -- NAG Alliance Garrison Level 3
    [1244] = { expansion = "Draenor", skillLineID = 2587 }, -- NAG Horde Garrison Level 0
    [1245] = { expansion = "Draenor", skillLineID = 2587 }, -- NAG Horde Garrison Level 3
    [1279] = { expansion = "Draenor", skillLineID = 2587 }, -- The Everbloom
    [1330] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor / FW Horde Garrison Level 2
    [1331] = { expansion = "Draenor", skillLineID = 2587 }, -- Draenor / SMV Alliance Garrison Level 2
    [1358] = { expansion = "Draenor", skillLineID = 2587 }, -- Upper Blackrock Spire
    [1448] = { expansion = "Draenor", skillLineID = 2587 }, -- Hellfire Citadel
    [1456] = { expansion = "Legion", skillLineID = 2586 }, -- Eye of Azshara
    [1458] = { expansion = "Legion", skillLineID = 2586 }, -- Neltharion's Lair
    [1463] = { expansion = "Legion", skillLineID = 2586 }, -- Helhiem Exterior Area
    [1464] = { expansion = "Draenor", skillLineID = 2587 }, -- Tanaan Jungle
    [1466] = { expansion = "Legion", skillLineID = 2586 }, -- Darkheart Thicket
    [1477] = { expansion = "Legion", skillLineID = 2586 }, -- Halls of Valor
    [1492] = { expansion = "Legion", skillLineID = 2586 }, -- Maw of Souls
    [1493] = { expansion = "Legion", skillLineID = 2586 }, -- Vault of the Wardens
    [1501] = { expansion = "Legion", skillLineID = 2586 }, -- Black Rook Hold
    [1505] = { expansion = "Fishing", skillLineID = 356 }, -- Nagrand Arena
    [1513] = { expansion = "Legion", skillLineID = 2586 }, -- Hall of the Guardian
    [1514] = { expansion = "Legion", skillLineID = 2586 }, -- The Wandering Isle
    [1516] = { expansion = "Legion", skillLineID = 2586 }, -- The Arcway
    [1520] = { expansion = "Legion", skillLineID = 2586 }, -- The Emerald Nightmare
    [1530] = { expansion = "Legion", skillLineID = 2586 }, -- The Nighthold
    [1544] = { expansion = "Legion", skillLineID = 2586 }, -- Violet Hold
    [1553] = { expansion = "Legion", skillLineID = 2586 }, -- Gloaming Reef
    [1571] = { expansion = "Legion", skillLineID = 2586 }, -- Court of Stars
    [1594] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- The MOTHERLODE!!
    [1642] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Zandalar
    [1643] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Kul Tiras
    [1648] = { expansion = "Legion", skillLineID = 2586 }, -- Trial of Valor
    [1651] = { expansion = "Legion", skillLineID = 2586 }, -- Return to Karazhan
    [1662] = { expansion = "Legion", skillLineID = 2586 }, -- Suramar
    [1669] = { expansion = "Legion", skillLineID = 2586 }, -- Argus
    [1672] = { expansion = "Fishing", skillLineID = 356 }, -- Blade's Edge Arena
    [1676] = { expansion = "Legion", skillLineID = 2586 }, -- Tomb of Sargeras
    [1677] = { expansion = "Legion", skillLineID = 2586 }, -- Cathedral of Eternal Night
    [1681] = { expansion = "Fishing", skillLineID = 356 }, -- Arathi Basin (Winter)
    [1712] = { expansion = "Legion", skillLineID = 2586 }, -- Antorus, the Burning Throne
    [1718] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Nazjatar
    [1750] = { expansion = "Legion", skillLineID = 2586 }, -- Azuremyst Isle
    [1737] = { expansion = "Legion", skillLineID = 2586 }, -- Pocket Dimension Akazamzaraks Hat Scenario
    [1753] = { expansion = "Legion", skillLineID = 2586 }, -- Seat of the Triumvirate
    [1754] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Freehold
    [1762] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Kings' Rest
    [1763] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Atal'Dazar
    [1771] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Tol Dagor
    [1803] = { expansion = "Fishing", skillLineID = 356 }, -- Seething Shore
    [1822] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Siege of Boralus
    [1841] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- The Underrot
    [1861] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Uldir
    [1862] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Waycrest Manor
    [1864] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Shrine of the Storm
    [1877] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Temple of Sethraliss
    [2070] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Battle of Dazar'alor
    [2096] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Crucible of Storms
    [2097] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Operation: Mechagon
    [2107] = { expansion = "Fishing", skillLineID = 356 }, -- Arathi Basin
    [2127] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Siren Isle
    [2164] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- The Eternal Palace
    [2167] = { expansion = "Fishing", skillLineID = 356 }, -- The Robodrome
    [2175] = { expansion = "Fishing", skillLineID = 356 }, -- Exile's Reah
    [2177] = { expansion = "Fishing", skillLineID = 356 }, -- Arathi Basin Comp Stomp
    [2217] = { expansion = "Kul Tiran", skillLineID = 2585 }, -- Ny'alotha
    [2222] = { expansion = "Shadowlands", skillLineID = 2754 }, -- The Shadowlands
    [2284] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Sanguine Depths
    [2285] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Spires of Ascension
    [2286] = { expansion = "Shadowlands", skillLineID = 2754 }, -- The Necrotic Wake
    [2287] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Halls of Atonement
    [2289] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Plaguefall
    [2290] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Mists of Tirna Scithe
    [2291] = { expansion = "Shadowlands", skillLineID = 2754 }, -- De Other Side
    [2293] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Theater of Pain
    [2296] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Castle Nathria
    [2374] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Zereth Mortis
    [2441] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Tazavesh the Veiled Market
    [2444] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Dragon Isles
    [2450] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Sanctum of Domination
    [2451] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Uldaman: Legacy of Tyr
    [2454] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Zaralek Cavern
    [2481] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Sepulcher of the First Ones
    [2515] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- The Azure Vault
    [2516] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- The Nokhud Offensive
    [2519] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Neltharus
    [2520] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Brackenhide Hollow
    [2521] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Ruby Life Pools
    [2522] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Vault of the Incarnates
    [2526] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Algeth'ar Academy
    [2527] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Halls of Infusion
    [2532] = { expansion = "Shadowlands", skillLineID = 2754 }, -- Tirisfal Glades
    [2548] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Emerald Dream
    [2552] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Khaz Algar (Surface)
    [2569] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Aberrus, the Shadowed Crucibleas
    [2579] = { expansion = "Dragon Isle", skillLineID = 2826 }, -- Dawn of the Infinite
    [2601] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The Ringing Deeps
    [2648] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / The Rookery
    [2649] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Priory of the Sacred Flame
    [2651] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Darkflame Cleft
    [2652] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / The Stonevault
    [2656] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Deephaul Ravine
    [2657] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Nerub-ar Palace
    [2660] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Ara-Kara, City of Echoes
    [2661] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Cinderbrew Meadery
    [2662] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / The Dawnbreaker
    [2664] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Khaz Algar / Isle of Dorn / Fungal Folly
    [2669] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / City of Threads
    [2679] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Mycomancer Cavern
    [2680] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Earthcrawl Mines
    [2681] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Kriegval's Rest
    [2685] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Skittering Breachs
    [2686] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Nightfall Sanctum
    [2687] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The Sinkhole
    [2706] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Deephaul Ravine
    [2731] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Dalaran (11.0 Dalaran Scenario)
    [2735] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Founder's Point
    [2736] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Razorwind Shores
    [2759] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Cage of Carnage
    [2769] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Liberation of Undermine
    [2773] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- The War Within / Operation: Floodgate
    [2815] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Excavation Site 9
    [2827] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Horrific Vision of Stormwind
    [2828] = { expansion = "Khaz Algar", skillLineID = 2876 }, -- Horrific Vision of Orgrimmar
}
