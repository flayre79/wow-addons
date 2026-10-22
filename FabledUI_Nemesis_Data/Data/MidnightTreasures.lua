-- ============================================================
-- HandyNotes_Midnight treasure import (sample)
--
-- Pending offline pipeline import from HandyNotes_Midnight zones/.
-- See [.sample-addons/HandyNotes_Midnight/zones/delves.lua] for the
-- canonical SturdyChest source format. Coordinates are 0..1 normalized,
-- same encoding as MidnightRares.lua.
--
-- Schema:
--   N.Data.MidnightTreasures[treasureID] = {
--       name        = "Display Name",
--       mapID       = <wow uiMapID>,
--       x, y        = 0..1 normalized,
--       quest       = <questID flagged on loot>,
--       achievement = <optional achievementID>,
--   }
-- treasureID is synthesised from the questID where the source data only
-- exposes a quest flag (HandyNotes does not expose distinct gameobject
-- IDs for Sturdy Chests). The pipeline will replace these placeholders
-- once the real GameObject IDs are scraped from wowhead.
-- ============================================================

local N = FabledUI_Nemesis or Nemesis
if not N then return end
N.Data = N.Data or {}

N.Data.MidnightTreasures = {
    __source  = "sample",
    __version = "2026-05-04-handynotes_midnight-sample",
    __notes   = "Sturdy Chest delve treasures. Replace via tools/data-pipeline/sources/handynotes-midnight-importer.py.",

    -- ============================================================
    -- Atal'Aman delve (mapID 2535) — Sturdy Chests #1-3
    -- ============================================================
    [94014] = { name = "Sturdy Chest #1 (Atal'Aman)", mapID = 2535, x = 0.4834, y = 0.5051, quest = 94014, achievement = 61863 },
    [94000] = { name = "Sturdy Chest #2 (Atal'Aman)", mapID = 2535, x = 0.5306, y = 0.5795, quest = 94000, achievement = 61863 },
    [94038] = { name = "Sturdy Chest #3 (Atal'Aman)", mapID = 2535, x = 0.5300, y = 0.6534, quest = 94038, achievement = 61863 },

    -- ============================================================
    -- The Shadow Enclave delve (mapID 2502)
    -- ============================================================
    [94001] = { name = "Sturdy Chest #1 (Shadow Enclave)", mapID = 2502, x = 0.5459, y = 0.8488, quest = 94001, achievement = 61892 },
    [94002] = { name = "Sturdy Chest #2 (Shadow Enclave)", mapID = 2502, x = 0.5463, y = 0.4885, quest = 94002, achievement = 61892 },

    -- ============================================================
    -- Parhelion Plaza delve (mapID 2545)
    -- ============================================================
    [94019] = { name = "Sturdy Chest #1 (Parhelion Plaza)", mapID = 2545, x = 0.0963, y = 0.5031, quest = 94019, achievement = 61893 },
    [94033] = { name = "Sturdy Chest #2 (Parhelion Plaza)", mapID = 2545, x = 0.4116, y = 0.8679, quest = 94033, achievement = 61893 },

    -- ============================================================
    -- Collegiate Calamity delve (mapID 2547)
    -- ============================================================
    [94018] = { name = "Sturdy Chest #1 (Collegiate Calamity)", mapID = 2547, x = 0.3095, y = 0.1246, quest = 94018, achievement = 61894 },
    [94030] = { name = "Sturdy Chest #2 (Collegiate Calamity)", mapID = 2547, x = 0.2954, y = 0.5397, quest = 94030, achievement = 61894 },

    -- ============================================================
    -- The Darkway delve (mapID 2525)
    -- ============================================================
    [94026] = { name = "Sturdy Chest #1 (The Darkway)", mapID = 2525, x = 0.5310, y = 0.4305, quest = 94026, achievement = 61895 },
    [94045] = { name = "Sturdy Chest #2 (The Darkway)", mapID = 2525, x = 0.4581, y = 0.4550, quest = 94045, achievement = 61895 },

    -- ============================================================
    -- Twilight Crypts delve (mapID 2504)
    -- ============================================================
    [94020] = { name = "Sturdy Chest #1 (Twilight Crypts)", mapID = 2504, x = 0.5682, y = 0.8579, quest = 94020, achievement = 61896 },
    [94034] = { name = "Sturdy Chest #2 (Twilight Crypts)", mapID = 2504, x = 0.2174, y = 0.3629, quest = 94034, achievement = 61896 },

    -- ============================================================
    -- The Grudge Pit delve (mapID 2510)
    -- ============================================================
    [94022] = { name = "Sturdy Chest #1 (The Grudge Pit)", mapID = 2510, x = 0.6976, y = 0.3165, quest = 94022, achievement = 61897 },
    [94039] = { name = "Sturdy Chest #2 (The Grudge Pit)", mapID = 2510, x = 0.3697, y = 0.2865, quest = 94039, achievement = 61897 },
}
