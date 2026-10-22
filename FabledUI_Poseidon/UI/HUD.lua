local P = _G.FabledUI_Poseidon
if not P then return end

local UI = P.UI

local function CreateMetricBlock(parent, titleText)
    local block = UI:CreatePanel(parent, titleText)
    block:SetHeight(74)

    block.line1L, block.line1R = UI:AddLabelValue(block, "Casts", "0", 12, -34, 220)
    block.line2L, block.line2R = UI:AddLabelValue(block, "Catches", "0", 12, -50, 220)
    block.line3L, block.line3R = UI:AddLabelValue(block, "Success", "0%", 12, -66, 220)
    return block
end

function UI:CreateHUDWindow()
    if self.hud then
        return self.hud
    end

    local frame = self:CreateToolkitWindow("FabledUI_PoseidonHUD", {
        title = "FabledUI - Poseidon",
        subtitle = "Fishing HUD",
        width = P.settings.hud.width,
        height = P.settings.hud.height,
        minWidth = 360,
        minHeight = 320,
        maxWidth = 720,
        maxHeight = 860,
        state = P.settings.hud,
        ribbon = false,
        frameStrata = "HIGH",
    })
    if not frame then
        return nil
    end

    local content = frame.Content
    content:SetFrameStrata("HIGH")

    frame.zoneTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.zoneTitle:SetPoint("TOPLEFT", 14, -10)
    frame.zoneTitle:SetJustifyH("LEFT")
    frame.zoneTitle:SetTextColor(self.Colors.title[1], self.Colors.title[2], self.Colors.title[3])

    frame.zoneSub = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.zoneSub:SetPoint("TOPLEFT", frame.zoneTitle, "BOTTOMLEFT", 0, -2)
    frame.zoneSub:SetJustifyH("LEFT")
    frame.zoneSub:SetTextColor(self.Colors.subtext[1], self.Colors.subtext[2], self.Colors.subtext[3])

    frame.settingsButton = self:CreateIconButton(content, "Interface/Buttons/UI-OptionsButton", "Open Poseidon settings")
    frame.settingsButton:SetPoint("TOPRIGHT", -14, -10)
    frame.settingsButton:SetScript("OnClick", function()
        P:OpenSettings()
    end)

    frame.fullButton = self:CreateActionButton(content, "Open Full", 90, 24)
    frame.fullButton:SetPoint("RIGHT", frame.settingsButton, "LEFT", -8, 0)
    frame.fullButton:SetScript("OnClick", function()
        UI:ShowFull()
    end)

    frame.sessionPanel = CreateMetricBlock(content, "Session Snapshot")
    frame.sessionPanel:SetPoint("TOPLEFT", frame.zoneSub, "BOTTOMLEFT", 0, -12)
    frame.sessionPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -62)

    frame.sessionPanel.extraL, frame.sessionPanel.extraR = UI:AddLabelValue(frame.sessionPanel, "Fish / Hr", "0.0", 12, -82, 220)
    frame.sessionPanel.timeL, frame.sessionPanel.timeR = UI:AddLabelValue(frame.sessionPanel, "Elapsed", "0m", 12, -98, 220)
    frame.sessionPanel:SetHeight(118)

    frame.poolPanel = self:CreatePanel(content, "Current Pool", "Interface/Icons/Trade_Fishing", true)
    frame.poolPanel:SetPoint("TOPLEFT", frame.sessionPanel, "BOTTOMLEFT", 0, -10)
    frame.poolPanel:SetPoint("TOPRIGHT", frame.sessionPanel, "TOPRIGHT", 0, -10)
    frame.poolPanel:SetHeight(110)
    frame.poolPanel.poolName = frame.poolPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.poolPanel.poolName:SetPoint("TOPLEFT", 12, -34)
    frame.poolPanel.poolName:SetPoint("TOPRIGHT", -12, -34)
    frame.poolPanel.poolName:SetJustifyH("LEFT")
    frame.poolPanel.poolName:SetTextColor(self.Colors.text[1], self.Colors.text[2], self.Colors.text[3])

    frame.poolPanel.learned = frame.poolPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.poolPanel.learned:SetPoint("TOPLEFT", frame.poolPanel.poolName, "BOTTOMLEFT", 0, -8)
    frame.poolPanel.learned:SetPoint("TOPRIGHT", -12, -58)
    frame.poolPanel.learned:SetJustifyH("LEFT")
    frame.poolPanel.learned:SetWordWrap(true)
    frame.poolPanel.learned:SetTextColor(self.Colors.subtext[1], self.Colors.subtext[2], self.Colors.subtext[3])

    frame.poolPanel.possible = frame.poolPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.poolPanel.possible:SetPoint("TOPLEFT", frame.poolPanel.learned, "BOTTOMLEFT", 0, -6)
    frame.poolPanel.possible:SetPoint("TOPRIGHT", -12, -84)
    frame.poolPanel.possible:SetJustifyH("LEFT")
    frame.poolPanel.possible:SetWordWrap(true)
    frame.poolPanel.possible:SetTextColor(self.Colors.subtext[1], self.Colors.subtext[2], self.Colors.subtext[3])

    -- P3: Buff tracker strip. Sits between the pool panel and the recent
    -- activity panel so the fishing buff status is always visible without
    -- requiring the player to scroll. Uses a thin one-line FontString so
    -- it doesn't push the recent-activity panel off the screen.
    frame.buffPanel = self:CreatePanel(content, "Active Buff", "Interface/Icons/INV_Misc_Fish_05", true)
    frame.buffPanel:SetPoint("TOPLEFT", frame.poolPanel, "BOTTOMLEFT", 0, -8)
    frame.buffPanel:SetPoint("TOPRIGHT", frame.poolPanel, "TOPRIGHT", 0, -8)
    frame.buffPanel:SetHeight(54)
    frame.buffPanel.statusLine = frame.buffPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.buffPanel.statusLine:SetPoint("TOPLEFT", 12, -30)
    frame.buffPanel.statusLine:SetPoint("TOPRIGHT", -12, -30)
    frame.buffPanel.statusLine:SetJustifyH("LEFT")
    frame.buffPanel.statusLine:SetWordWrap(false)

    frame.recentPanel = self:CreatePanel(content, "Recent Activity", "Interface/Icons/Achievement_General_StayClassy")
    frame.recentPanel:SetPoint("TOPLEFT", frame.buffPanel, "BOTTOMLEFT", 0, -10)
    frame.recentPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 14)

    frame.recentLines = {}
    local anchorY = -34
    for index = 1, 5 do
        local line = frame.recentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", 12, anchorY)
        line:SetPoint("TOPRIGHT", -12, anchorY)
        line:SetJustifyH("LEFT")
        line:SetTextColor(self.Colors.text[1], self.Colors.text[2], self.Colors.text[3])
        frame.recentLines[index] = line
        anchorY = anchorY - 18
    end

    self.hud = frame
    self:ApplyRuntimeState(frame, P.settings.hud)
    return frame
end

function UI:RenderHUD()
    local frame = self:CreateHUDWindow()
    if not frame then
        return
    end

    local overview = P.Stats:GetOverviewData()
    local session = overview.session or {}
    local zoneInfo = overview.zoneInfo or {}
    local currentPool = session.lastPool or P.State.lastPoolHover or "Open Water"
    local poolData = P.MapTooltip and P.MapTooltip.BuildPoolData and P.MapTooltip:BuildPoolData(currentPool, zoneInfo.mapID, nil) or nil

    frame.zoneTitle:SetText(zoneInfo.mapName or "Unknown Zone")
    frame.zoneSub:SetText(string.format("%s  •  %s", (zoneInfo.subZone and zoneInfo.subZone ~= "" and zoneInfo.subZone) or "No sub-zone", currentPool))

    frame.sessionPanel.line1R:SetText(tostring(session.casts or 0))
    frame.sessionPanel.line2R:SetText(tostring(session.catches or 0))
    frame.sessionPanel.line3R:SetText(string.format("%.0f%%", P.Stats:GetSuccessRate(session)))
    frame.sessionPanel.extraR:SetText(string.format("%.1f", P.Stats:GetFishPerHour(session)))
    frame.sessionPanel.timeR:SetText(P.Stats:GetElapsedText(session))

    frame.poolPanel.poolName:SetText(currentPool)
    local learned = poolData and poolData.learned or {}
    local possible = poolData and poolData.possible or {}
    frame.poolPanel.learned:SetText("Learned: " .. UI:JoinList(learned, 3, 92))
    frame.poolPanel.possible:SetText("Possible: " .. UI:JoinList(possible, 4, 110))

    local catches = P.State.recentCatches or {}
    for index, line in ipairs(frame.recentLines) do
        local entry = catches[index]
        if entry then
            line:SetText(UI:Truncate(string.format("%s  •  %s", entry.itemName or "Unknown", entry.poolName or "Open Water"), 60))
            line:SetTextColor(self.Colors.text[1], self.Colors.text[2], self.Colors.text[3])
            line:Show()
        else
            line:SetText(index == 1 and "No catches recorded yet." or "")
            line:SetTextColor(self.Colors.subtext[1], self.Colors.subtext[2], self.Colors.subtext[3])
        end
    end

    local status
    if P.settings.showDerbyTracker and P.Derby and P.Derby.IsActive and P.Derby:IsActive() then
        status = "Tournament active"
    elseif currentPool and currentPool ~= "Open Water" then
        status = currentPool
    else
        status = string.format("Session %d casts / %d catches", session.casts or 0, session.catches or 0)
    end

    if frame.SetShellStatus then
        frame:SetShellStatus(status)
    end

    -- P3: keep the buff strip in sync on every HUD render.
    self:RenderHUDBuffStatus()
end

-- P3: dedicated render so UNIT_AURA-driven updates can refresh just the
-- buff slot without rebuilding the entire HUD.
function UI:RenderHUDBuffStatus()
    local frame = self.hud
    if not frame or not frame.buffPanel then return end

    if P.settings and P.settings.showBuffTracker == false then
        frame.buffPanel:Hide()
        return
    end
    frame.buffPanel:Show()

    local statusLine = frame.buffPanel.statusLine
    if not statusLine then return end

    local text
    if P.BuffTracker and P.BuffTracker.GetStatusLine then
        text = P.BuffTracker:GetStatusLine()
    end
    if type(text) ~= "string" or text == "" then
        text = "No active fishing buff"
    end
    statusLine:SetText(text)

    -- Color tint: green when a buff is up, dim when none is active.
    local active = P.BuffTracker and P.BuffTracker.GetActiveBuff and P.BuffTracker:GetActiveBuff() or nil
    if active then
        statusLine:SetTextColor(0.45, 0.95, 0.55)
    else
        statusLine:SetTextColor(self.Colors.subtext[1], self.Colors.subtext[2], self.Colors.subtext[3])
    end
end
