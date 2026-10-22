local M = _G.FabledUI_Crafty

M.Toolkit = M.Toolkit or {}
local TK = M.Toolkit

TK.THEME = "FableNeon"
TK.ACCENT = { 0.227, 0.914, 1.000, 1.0 }  -- FableNeon electric cyan (#3AE9FF)

function TK:GetRuntime()
    local toolkit = rawget(_G, "FabledUI_UIToolkit")
    if type(toolkit) == "table" then
        return toolkit
    end
    return nil
end

function TK:HasShell()
    local toolkit = self:GetRuntime()
    return toolkit and toolkit.Shell and type(toolkit.Shell.CreateWindow) == "function"
end

function TK:EnsureWindowState(state)
    state = type(state) == "table" and state or {}
    local defaults = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 1180,
        height = 700,
        scale = 1,
        alpha = 1,
        displayState = "expanded",
        ribbonPoint = "TOP",
        ribbonRelativePoint = "TOP",
        ribbonX = 0,
        ribbonY = -160,
        ribbonWidth = 260,
        ribbonHeight = 24,
    }

    local toolkit = self:GetRuntime()
    if toolkit and toolkit.WindowState and type(toolkit.WindowState.Ensure) == "function" then
        return toolkit.WindowState:Ensure(state, defaults)
    end

    for key, value in pairs(defaults) do
        if state[key] == nil then
            state[key] = value
        end
    end
    return state
end

function TK:ApplyPanel(frame, useRaisedSurface)
    local toolkit = self:GetRuntime()
    if not frame or not toolkit or not toolkit.Themes or type(toolkit.Themes.ApplyPanel) ~= "function" then
        return
    end
    toolkit.Themes:ApplyPanel(frame, self.THEME, self.ACCENT, useRaisedSurface == true)
end

function TK:ApplyBodyText(fontString, muted)
    local toolkit = self:GetRuntime()
    if not fontString or not toolkit or not toolkit.Themes or type(toolkit.Themes.ApplyBodyText) ~= "function" then
        return
    end
    toolkit.Themes:ApplyBodyText(fontString, self.THEME, self.ACCENT, muted == true)
end

function TK:ApplyTitleText(fontString)
    local toolkit = self:GetRuntime()
    if not fontString or not toolkit or not toolkit.Themes or type(toolkit.Themes.ApplyTitleText) ~= "function" then
        return
    end
    toolkit.Themes:ApplyTitleText(fontString, self.THEME, self.ACCENT)
end

function TK:StyleFlatButton(button)
    local toolkit = self:GetRuntime()
    if not button or not toolkit or not toolkit.Themes or type(toolkit.Themes.StyleFlatButton) ~= "function" then
        return
    end
    toolkit.Themes:StyleFlatButton(button, self.THEME, self.ACCENT)
    -- FableNeon: recolor default gold/white button text to the theme ink, and
    -- add a hover glow so buttons read as neon rather than flat.
    local fs = button.GetFontString and button:GetFontString()
    if fs and type(toolkit.Themes.ApplyBodyText) == "function" then
        toolkit.Themes:ApplyBodyText(fs, self.THEME, self.ACCENT, false)
    end
    if toolkit.Effects and type(toolkit.Effects.StyleNeonButton) == "function" then
        toolkit.Effects:StyleNeonButton(button, self.THEME, self.ACCENT)
    end
end

function TK:StyleCheckbox(check)
    local toolkit = self:GetRuntime()
    if not check or not toolkit or not toolkit.Effects or type(toolkit.Effects.StyleCheckbox) ~= "function" then
        return
    end
    toolkit.Effects:StyleCheckbox(check, self.THEME, self.ACCENT)
end

return TK


