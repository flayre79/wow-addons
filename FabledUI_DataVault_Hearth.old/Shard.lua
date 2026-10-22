local shardKey = "FabledUI_DataVault_Hearth"
FabledUI_HearthDB = FabledUI_HearthDB or {}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(shardKey, FabledUI_HearthDB)
    end
end)