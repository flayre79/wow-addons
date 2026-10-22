-- ============================================================================
-- FabledUI_DataVault_Crafty - Shard
-- High-volume sharded storage for Crafty's optimized-cost cache. Mirrors the
-- pattern in FabledUI_DataVault_Harvest/Shard.lua: declare the SavedVariables
-- bucket, register with the DataVault on PLAYER_LOGIN, done. The actual
-- read/write API lives in Crafty's Profit.lua (Agent A owns that file); this
-- shard exists so the routing target is in place ahead of time.
--
-- Donor schema (CraftSim/DB/itemOptimizedCostsDB.lua:48-90):
--   FabledUI_DataVault_CraftyDB[itemID][crafterUID] = {
--       qualityID,                -- 1..5 quality of the produced item
--       expectedCostsPerItem,     -- gold cost per output item
--       expectedYieldPerCraft,    -- avg items produced per craft attempt
--       profession,               -- enum (Enum.Profession.*)
--       concentration,            -- bool: result depends on concentration
--       concentrationCost,        -- concentration spent per craft
--   }
--
-- crafterUID is the canonical "Name-Realm" string used elsewhere in Crafty
-- (see M:GetCurrentCharacterKey in Core.lua). itemID is the produced item's
-- numeric ID (NOT the recipe ID), so per-quality variants get their own row.
-- ============================================================================

local shardKey = "FabledUI_DataVault_Crafty"

FabledUI_DataVault_CraftyDB = FabledUI_DataVault_CraftyDB or {}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(shardKey, FabledUI_DataVault_CraftyDB)
    end
end)
