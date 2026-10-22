local shardKey = "FabledUI_DataVault_Poseidon"
FabledUI_PoseidonDB = FabledUI_PoseidonDB or {}

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(shardKey, FabledUI_PoseidonDB)
    end
end)