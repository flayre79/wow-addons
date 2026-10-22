local shardKey = "FabledUI_DataVault_Nemesis"
FabledUI_NemesisDB = FabledUI_NemesisDB or {}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(shardKey, FabledUI_NemesisDB)
    end
end)