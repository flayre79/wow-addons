local shardKey = "FabledUI_DataVault_Tekne"
FabledUI_TekneDB = FabledUI_TekneDB or {}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(shardKey, FabledUI_TekneDB)
    end
end)