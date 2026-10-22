-- Fishing poles and their skill bonuses
local FISHING_POLES = {
    [6256] = 0,		-- Fishing Pole
    [6365] = 5,		-- Strong Fishing Pole
    [45120] = 0,	-- Basic Fishing Pole
    [177030] = 0,	-- Aquatic Extractor
    [12225] = 3,	-- Blump Family Fishing Pole
    [46337] = 3,	-- Staat's Fishing Pole
    [52678] = 3,	-- Jonathan's Fishing Pole
    [120163] = 3,	-- Thruk's Fishing Rod
    [180136] = 5,	-- The Brokers Angle'r
    [198225] = 0,	-- Draconium Fisherfriend (Equip: +6 Dragon Isles Fishing Skill)
    [84660] = 7,	-- Pandaren Fishing Pole
    [6366] = 8,		-- Darkwood Fishing Pole
    [221790] = 8,	-- Bismuth Fisherfriend (+152 Perception)
    [6367] = 10,	-- Big Iron Fishing Pole
    [19022] = 10,	-- Nat Pagle's Extreme Angler FC-5000
    [25978] = 10,	-- Seth's Graphite Fishing Pole
    [44050] = 13,	-- Mastercraft Kalu'ak Fishing Pole
    [45858] = 12,	-- Nat's Lucky Fishing Pole
    [45991] = 13,	-- Bone Fishing Pole
    [45992] = 13,	-- Jeweled Fishing Pole
    [84661] = 13,	-- Dragon Fishing Pole
    [116825] = 13,	-- Savage Fishing Pole
    [116826] = 13,	-- Draenic Fishing Pole
    [19970] = 14,	-- Arcanite Fishing Pole
    [118381] = 14,	-- Ephemeral Fishing Pole
    [173044] = 14,	-- Wreathed Fishing Pole
    [133755] = 15,	-- Underlight Angler
    [168804] = 15,	-- Powered Piscine Procurement Pole
    [198226] = 15,	-- Khaz'gorite Fisherfriend (+90 Perception)
    [200218] = 15,	-- Charred Fishing Pole
    [221791] = 18,	-- Aqirite Fisherfriend (+152 Perception)
    [43651] = 1000	-- Crafty's Pole
}

local FISHING_HAT_BUFF = {
    [19972] = 5,   -- Lucky Fishing Hat (Equip: On Equip: +5 Fishing Skill.)
    [33820] = 5,   -- Weather-Beaten Fishing Hat (Equip: On Equip: +5 Fishing Skill.)
    [88710] = 5,   -- Nat's Hat (Equip: On Equip: +5 Fishing Skill.)
    [93732] = 5,   -- Darkmoon Fishing Cap (Equip: On Equip: +5 Fishing Skill.)
    [117405] = 8,  -- Nat's Drinking Hat (Equip: +8 Fishing Skill.)
    [118380] = 5,  -- Hightfish Cap (Equip: +5 Fishing Skill.) / Duration: 7 days
    [118393] = 5,  -- Tentacled Hat (Equip: +5 Fishing Skill.) / Duration: 7 days
    [193529] = 0,  -- Wildercloth Fishing Cap (Equip: +4 Dragon Isles Fishing Skill.)
}

local FISHING_TOYS_BUFF = {
    [251216] = 4,  -- Trawler Totem (+4 Fishing skill for 2 min)
    [125167] = 0,  -- Ancient Pandaren Fishing Charm (Additional fish from pools in Pandaria for 1 hour.)
}

local FISHING_SKILL_BUFF = {
    [128357] = 5,   -- Sharpened Tuskarr Spear (+5 Fishing skill for 10 min)
    [456156] = 10,  -- Chum (Gain 10 Fishing for 30 sec.)
}

local FISHING_PERCEPTION_BUFF = {
    [456586] = 45,  -- Algari Perception (Gain 45 Perception for 30 sec.)
    [456596] = 45,  -- Goldengill Blessing (Perception increased by 45.)
}

FT_FishingPolesIDs = FISHING_POLES
FT_FishingHatBuffIDs = FISHING_HAT_BUFF
FT_FishingToysBuffIDs = FISHING_TOYS_BUFF
FT_FishingSkillBuffIDs = FISHING_SKILL_BUFF
FT_FishingPerceptionBuffIDs = FISHING_PERCEPTION_BUFF
