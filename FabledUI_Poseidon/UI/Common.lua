local P = _G.FabledUI_Poseidon
if not P then return end

P.UI = P.UI or {}
local UI = P.UI

UI.ACCENT = { 0.160, 0.700, 0.760, 1.0 }
UI.Colors = {
    bg = { 0.070, 0.095, 0.130, 0.94 },
    bgAlt = { 0.090, 0.120, 0.165, 0.95 },
    border = { 0.160, 0.700, 0.760, 0.65 },
    title = { 0.930, 0.970, 1.000, 1.0 },
    text = { 0.880, 0.920, 0.980, 1.0 },
    subtext = { 0.640, 0.720, 0.840, 1.0 },
    gold = { 0.980, 0.830, 0.360, 1.0 },
    good = { 0.420, 0.920, 0.720, 1.0 },
}

function UI:GetToolkit()
    if self.T == nil then
        self.T = rawget(_G, "FabledUI_UIToolkit")
    end
    return self.T
end

function UI:IsToolkitReady()
    local T = self:GetToolkit()
    return type(T) == "table" and type(T.Shell) == "table" and type(T.Shell.CreateWindow) == "function"
end

function UI:CreateToolkitWindow(frameName, options)
    local T = self:GetToolkit()
    if not T or not T.Shell or not T.Shell.CreateWindow then
        return nil
    end

    options = options or {}
    options.theme = options.theme or "FableNeon"
    options.accentColor = options.accentColor or self.ACCENT
    options.onSizeChanged = options.onSizeChanged or function()
        P:MarkDirty()
    end
    options.onBoundsChanged = options.onBoundsChanged or function()
        P:MarkDirty()
    end
    options.onDisplayStateChanged = options.onDisplayStateChanged or function()
        P:MarkDirty()
    end
    options.onHide = options.onHide or function()
        P:MarkDirty()
    end

    return T.Shell:CreateWindow(frameName, options)
end

function UI:IsWindowVisible(frame)
    if not frame then
        return false
    end
    if type(frame.IsShellVisible) == "function" then
        local ok, visible = pcall(frame.IsShellVisible, frame)
        if ok then
            return visible == true
        end
    end
    return frame:IsShown()
end

function UI:ShowWindow(frame)
    if not frame then
        return
    end
    if type(frame.ShowExpanded) == "function" then
        frame:ShowExpanded()
    else
        frame:Show()
    end
end

function UI:HideWindow(frame)
    if not frame then
        return
    end
    if type(frame.HideShell) == "function" then
        frame:HideShell()
    else
        frame:Hide()
    end
end

function UI:ToggleWindow(frame, forceShow)
    if not frame then
        return
    end
    if type(frame.ToggleShell) == "function" then
        frame:ToggleShell(forceShow)
        return
    end
    if forceShow == true then
        frame:Show()
    elseif forceShow == false then
        frame:Hide()
    elseif frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

function UI:ApplyRuntimeState(frame, state)
    if not frame or type(state) ~= "table" then
        return
    end
    if type(state.scale) == "number" and frame.SetScale then
        frame:SetScale(state.scale)
    end
    if type(state.alpha) == "number" and frame.SetAlpha then
        frame:SetAlpha(state.alpha)
    end
end

function UI:StyleButton(button)
    local T = self:GetToolkit()
    if T and T.Themes and type(T.Themes.StyleFlatButton) == "function" then
        pcall(T.Themes.StyleFlatButton, T.Themes, button, "FableNeon", self.ACCENT)
    end
end

function UI:CreateActionButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 96, height or 24)
    button:SetText(text or "Button")
    self:StyleButton(button)
    return button
end

function UI:CreateIconButton(parent, icon, tooltipText)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(24, 24)
    self:ApplyPanelBackdrop(button, true)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(14, 14)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexture(icon)
    if tooltipText then
        button:SetScript("OnEnter", function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    return button
end

function UI:ApplyPanelBackdrop(frame, alt)
    frame:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    local color = alt and self.Colors.bgAlt or self.Colors.bg
    frame:SetBackdropColor(color[1], color[2], color[3], color[4])
    frame:SetBackdropBorderColor(self.Colors.border[1], self.Colors.border[2], self.Colors.border[3], self.Colors.border[4])
end

function UI:CreatePanel(parent, title, icon, alt)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    self:ApplyPanelBackdrop(panel, alt)

    panel.accent = panel:CreateTexture(nil, "ARTWORK")
    panel.accent:SetPoint("TOPLEFT", 0, 0)
    panel.accent:SetPoint("TOPRIGHT", 0, 0)
    panel.accent:SetHeight(3)
    panel.accent:SetColorTexture(self.ACCENT[1], self.ACCENT[2], self.ACCENT[3], 0.90)

    if icon then
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(16, 16)
        panel.icon:SetPoint("TOPLEFT", 10, -10)
        panel.icon:SetTexture(icon)
    end

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if panel.icon then
        panel.title:SetPoint("LEFT", panel.icon, "RIGHT", 6, 0)
    else
        panel.title:SetPoint("TOPLEFT", 10, -10)
    end
    panel.title:SetJustifyH("LEFT")
    panel.title:SetTextColor(self.Colors.gold[1], self.Colors.gold[2], self.Colors.gold[3])
    panel.title:SetText(title or "Panel")

    return panel
end

function UI:CreateScrollArea(parent, top, bottom, left, right)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", left or 0, top or 0)
    scroll:SetPoint("BOTTOMRIGHT", right or 0, bottom or 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    return scroll, content
end

function UI:TrackChild(parent, child)
    parent._poseidonChildren = parent._poseidonChildren or {}
    table.insert(parent._poseidonChildren, child)
    return child
end

function UI:WipeChildren(parent)
    if not parent or not parent._poseidonChildren then
        return
    end
    for _, child in ipairs(parent._poseidonChildren) do
        child:Hide()
        child:SetParent(nil)
    end
    wipe(parent._poseidonChildren)
end

function UI:AddWrappedText(parent, text, x, y, width, fontObject, color)
    local fs = self:TrackChild(parent, parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal"))
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    if color then
        fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    fs:SetText(text or "")
    return fs
end

function UI:AddLabelValue(parent, label, value, x, y, width)
    local left = self:AddWrappedText(parent, label, x, y, math.floor(width * 0.45), "GameFontNormalSmall", self.Colors.subtext)
    local right = self:AddWrappedText(parent, value, x + math.floor(width * 0.45), y, math.floor(width * 0.55), "GameFontHighlightSmall", self.Colors.text)
    right:SetJustifyH("RIGHT")
    return left, right
end

function UI:GetFishIcon(fishName)
    local itemID = P:GetFishItemID(fishName)
    -- C_Item.GetItemIconByID: the global GetItemIcon is gone in 12.1.5.
    if itemID and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID) or "Interface/Icons/Trade_Fishing"
    end
    return "Interface/Icons/Trade_Fishing"
end

function UI:Truncate(text, maxLen)
    if type(text) ~= "string" then
        return ""
    end
    maxLen = tonumber(maxLen) or 120
    if #text <= maxLen then
        return text
    end
    return text:sub(1, maxLen - 3) .. "..."
end

function UI:JoinList(list, maxItems, maxLen)
    if type(list) ~= "table" or #list == 0 then
        return "None"
    end
    local out = {}
    local limit = math.min(#list, maxItems or #list)
    for index = 1, limit do
        out[#out + 1] = tostring(list[index])
    end
    local text = table.concat(out, ", ")
    if #list > limit then
        text = text .. " +" .. tostring(#list - limit) .. " more"
    end
    return self:Truncate(text, maxLen or 100)
end

function UI:FormatRelativeTime(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return "Never"
    end
    local seconds = math.max(0, time() - timestamp)
    if seconds < 60 then
        return string.format("%ds ago", seconds)
    elseif seconds < 3600 then
        return string.format("%dm ago", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%dh ago", math.floor(seconds / 3600))
    end
    return date("%Y-%m-%d", timestamp)
end
