local shardKey = "FabledUI_DataVault_Harvest"
FabledUI_HarvestDB = FabledUI_HarvestDB or {}

local ev = CreateFrame("Frame")
-- SetScript before RegisterEvent: a frame must never hold a live registration
-- with no handler attached.
ev:SetScript("OnEvent", function()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(shardKey, FabledUI_HarvestDB)
    end
end)
ev:RegisterEvent("PLAYER_LOGIN")