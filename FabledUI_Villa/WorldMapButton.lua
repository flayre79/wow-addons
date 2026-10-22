local Villa = _G.FabledUI_Villa
local WorldMapButton = {}
Villa.WorldMapButton = WorldMapButton
Villa:RegisterModule("WorldMapButton", WorldMapButton)

function WorldMapButton:EnsureButton()
    if self.button and self.button:GetParent() == WorldMapFrame then
        return self.button
    end
    if not WorldMapFrame then
        return nil
    end

    local button = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
    button:SetSize(72, 22)
    button:SetText("Villa")
    button:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -92, -30)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            Villa:OpenSettings()
        else
            Villa:OpenPanel("vendors")
        end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.button = button
    return button
end

function WorldMapButton:RefreshVisibility()
    local button = self:EnsureButton()
    if not button then
        return
    end
    button:SetShown(Villa.settings.showWorldMapButton and WorldMapFrame and WorldMapFrame:IsShown())
end

function WorldMapButton:OnEnable()
    C_Timer.After(1.5, function()
        local button = self:EnsureButton()
        if not button or not WorldMapFrame then
            return
        end
        WorldMapFrame:HookScript("OnShow", function()
            self:RefreshVisibility()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            self:RefreshVisibility()
        end)
        self:RefreshVisibility()
    end)
end
