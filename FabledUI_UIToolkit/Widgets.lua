local T = FabledUI_UIToolkit
T.Widgets = {}

--- SVC-005: Safe Tab Injection
--- Appends a tab safely to a Blizzard UI frame without causing taint errors.
function T.Widgets:InjectTab(parentFrame, tabText, onClick)
    if not parentFrame then return nil end
    
    -- Count existing tabs
    local numTabs = parentFrame.numTabs or 0
    local newTabId = numTabs + 1
    
    -- 12.0 UI standards require CharacterFrameTabButtonTemplate or specific PanelTabButtonTemplate
    local tabName = parentFrame:GetName() .. "Tab" .. newTabId
    local tab = CreateFrame("Button", tabName, parentFrame, "CharacterFrameTabButtonTemplate")
    
    tab:SetID(newTabId)
    tab:SetText(tabText)
    
    -- Position relative to the previous tab
    if newTabId == 1 then
        tab:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 15, -30)
    else
        local prevTab = _G[parentFrame:GetName() .. "Tab" .. (newTabId - 1)]
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", -15, 0)
        else
            -- Fallback
            tab:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 15 + ((newTabId-1)*80), -30)
        end
    end
    
    if onClick then
        tab:SetScript("OnClick", onClick)
    end
    
    -- Register the new tab count with the frame so Blizzard functions know it exists
    parentFrame.numTabs = newTabId
    if PanelTemplates_UpdateTabs then
        PanelTemplates_UpdateTabs(parentFrame)
    end
    
    return tab
end
