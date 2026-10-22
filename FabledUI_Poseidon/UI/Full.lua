local P = _G.FabledUI_Poseidon
if not P then return end

local UI = P.UI

local NAV_ITEMS = {
    { key = "overview", label = "Overview" },
    { key = "zones", label = "Zones" },
    { key = "fish", label = "Fish" },
    { key = "nodes", label = "Nodes" },
    { key = "sharing", label = "Sharing" },
}

function UI:CreateFullWindow()
    if self.full then
        return self.full
    end

    local frame = self:CreateToolkitWindow("FabledUI_PoseidonJournal", {
        title = "FabledUI - Poseidon",
        subtitle = "Fishing browser and node intelligence",
        width = P.settings.full.width,
        height = P.settings.full.height,
        minWidth = 880,
        minHeight = 620,
        maxWidth = 1800,
        maxHeight = 1400,
        state = P.settings.full,
        ribbon = false,
        frameStrata = "HIGH",
    })
    if not frame then
        return nil
    end

    local content = frame.Content

    frame.pageBar = CreateFrame("Frame", nil, content)
    frame.pageBar:SetPoint("TOPLEFT", 14, -10)
    frame.pageBar:SetPoint("TOPRIGHT", -14, -10)
    frame.pageBar:SetHeight(28)

    frame.pageButtons = {}
    local anchor = nil
    for _, item in ipairs(NAV_ITEMS) do
        local button = self:CreateActionButton(frame.pageBar, item.label, 88, 24)
        if not anchor then
            button:SetPoint("LEFT", 0, 0)
        else
            button:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
        end
        anchor = button
        button.key = item.key
        button:SetScript("OnClick", function()
            UI.state.page = item.key
            P.settings.full.selectedPage = item.key
            UI:RefreshFull()
        end)
        frame.pageButtons[item.key] = button
    end

    frame.settingsButton = self:CreateActionButton(frame.pageBar, "Settings", 82, 24)
    frame.settingsButton:SetPoint("RIGHT", 0, 0)
    frame.settingsButton:SetScript("OnClick", function()
        P:OpenSettings()
    end)

    frame.scroll, frame.scrollContent = self:CreateScrollArea(content, -48, 12, 0, -26)
    frame.scrollContent:SetWidth(math.max(780, (P.settings.full.width or 940) - 70))

    self.full = frame
    self:ApplyRuntimeState(frame, P.settings.full)
    return frame
end

function UI:RefreshFullNav()
    if not self.full or not self.full.pageButtons then
        return
    end

    local selected = self.state.page or P.settings.full.selectedPage or "overview"
    for key, button in pairs(self.full.pageButtons) do
        button:SetEnabled(key ~= selected)
        if key == selected then
            button:GetFontString():SetTextColor(UI.Colors.gold[1], UI.Colors.gold[2], UI.Colors.gold[3])
        else
            button:GetFontString():SetTextColor(1, 1, 1)
        end
    end
end

function UI:RenderFullPage()
    local frame = self:CreateFullWindow()
    if not frame then
        return
    end

    local page = self.state.page or P.settings.full.selectedPage or "overview"
    self.state.page = page
    P.settings.full.selectedPage = page

    local width = math.max(760, math.floor((frame.scroll:GetWidth() > 0 and frame.scroll:GetWidth() or frame:GetWidth() - 80) - 34))
    frame.scrollContent:SetWidth(width)

    if page == "zones" then
        self:RenderZonesPage(frame.scrollContent, width)
    elseif page == "fish" then
        self:RenderFishPage(frame.scrollContent, width)
    elseif page == "nodes" then
        self:RenderNodesPage(frame.scrollContent, width)
    elseif page == "sharing" then
        self:RenderSharingPage(frame.scrollContent, width)
    else
        self:RenderOverviewPage(frame.scrollContent, width)
    end

    self:RefreshFullNav()
end
