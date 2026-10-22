local P = _G.FabledUI_Poseidon
if not P then return end

P.Journal = P.Journal or {}
local J = P.Journal

function J:Init()
    if self.initialized then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:SetScript("OnEvent", function()
        if P.UI and P.UI.frame and P.UI.frame:IsShown() then
            P.UI:SetStatus("Free-floating fishing companion.", P.UI:GetModeLabel())
        end
    end)

    self.frame = frame
    self.initialized = true
end

function J:ShowCompanion()
    if P.UI then
        P.UI:Show()
    end
end

function J:Toggle()
    P:OpenFishingJournal()
    self:ShowCompanion()
end
