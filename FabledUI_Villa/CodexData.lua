local Villa = _G.FabledUI_Villa
        local module = (Villa and Villa.GetProviderStore and Villa:GetProviderStore("codex")) or {}
        Villa.CodexData = module
        Villa:RegisterModule("CodexData", module)
        if Villa and Villa.RegisterModeStub then
    Villa:RegisterModeStub("achievements", "codex")
    Villa:RegisterModeStub("achievements", "hybrid")
    Villa:RegisterModeStub("achievements", "decorvendor")
    Villa:RegisterModeStub("achievements", "hit")
    Villa:RegisterModeStub("quests", "codex")
    Villa:RegisterModeStub("quests", "hybrid")
    Villa:RegisterModeStub("quests", "decorvendor")
    Villa:RegisterModeStub("quests", "hit")
    Villa:RegisterModeStub("drops", "codex")
    Villa:RegisterModeStub("drops", "hybrid")
    Villa:RegisterModeStub("professions", "codex")
    Villa:RegisterModeStub("professions", "hybrid")
    Villa:RegisterModeStub("professions", "decorvendor")
    Villa:RegisterModeStub("professions", "hit")
    Villa:RegisterModeStub("professions", "housingvendor")
end
