local T = FabledUI_UIToolkit
T.Themes = T.Themes or {}

local Themes = T.Themes

local function CloneColor(color)
    if type(color) ~= "table" then
        return { 1, 1, 1, 1 }
    end

    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        color[4] == nil and 1 or color[4],
    }
end

local function ApplyColor(target, color)
    if not target or type(color) ~= "table" then
        return
    end
    target:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
end

-- FableNeon — the suite's signature identity (2026-07). Dark indigo ground,
-- electric-cyan + arcane-purple signatures, spectrum accents used as meaning.
-- Glow is layered on separately via Effects.lua (additive textures); the tokens
-- here define the palette every addon inherits.
local PRESETS = {
    FableNeon = {
        background = { 0.031, 0.027, 0.059, 0.965 },
        surface = { 0.070, 0.063, 0.118, 0.975 },
        surfaceRaised = { 0.090, 0.075, 0.153, 0.985 },
        border = { 0.360, 0.310, 0.620, 0.34 },
        borderStrong = { 0.227, 0.882, 1.000, 0.50 },
        accent = { 0.227, 0.914, 1.000, 1.0 },        -- electric cyan #3AE9FF
        accentSoft = { 0.227, 0.914, 1.000, 0.16 },
        accent2 = { 0.706, 0.361, 1.000, 1.0 },       -- arcane purple #B45CFF
        accent2Soft = { 0.706, 0.361, 1.000, 0.16 },
        titleBar = { 0.055, 0.047, 0.102, 0.985 },
        titleText = { 0.925, 0.922, 0.980, 1.0 },
        text = { 0.925, 0.922, 0.980, 1.0 },
        textMuted = { 0.612, 0.600, 0.761, 1.0 },
        button = { 0.059, 0.047, 0.110, 1.0 },
        buttonHover = { 0.106, 0.086, 0.188, 1.0 },
        buttonPressed = { 0.141, 0.118, 0.235, 1.0 },
        success = { 0.361, 0.941, 0.627, 1.0 },       -- neon green #5CF0A0
        warning = { 1.000, 0.761, 0.294, 1.0 },       -- amber #FFC24B
        danger = { 1.000, 0.302, 0.416, 1.0 },        -- red-pink #FF4D6A
        shadow = { 0.0, 0.0, 0.0, 0.55 },
        -- Spectrum: categorical hues for tags, gems, per-profession accents.
        -- Keyed so consumers can map a category -> a stable color.
        spectrum = {
            cyan = { 0.227, 0.914, 1.000, 1.0 },
            purple = { 0.706, 0.361, 1.000, 1.0 },
            pink = { 1.000, 0.353, 0.651, 1.0 },
            green = { 0.361, 0.941, 0.627, 1.0 },
            amber = { 1.000, 0.761, 0.294, 1.0 },
            azure = { 0.357, 0.616, 1.000, 1.0 },
        },
    },
    Dark = {
        background = { 0.050, 0.058, 0.078, 0.965 },
        surface = { 0.075, 0.086, 0.110, 0.975 },
        surfaceRaised = { 0.105, 0.120, 0.152, 0.985 },
        border = { 0.165, 0.188, 0.235, 1.0 },
        borderStrong = { 0.235, 0.270, 0.345, 1.0 },
        accent = { 0.290, 0.635, 1.000, 1.0 },
        accentSoft = { 0.290, 0.635, 1.000, 0.18 },
        titleBar = { 0.082, 0.094, 0.122, 0.985 },
        titleText = { 0.965, 0.972, 1.000, 1.0 },
        text = { 0.910, 0.930, 0.980, 1.0 },
        textMuted = { 0.655, 0.710, 0.810, 1.0 },
        button = { 0.105, 0.120, 0.150, 1.0 },
        buttonHover = { 0.135, 0.154, 0.195, 1.0 },
        buttonPressed = { 0.165, 0.188, 0.235, 1.0 },
        success = { 0.290, 0.835, 0.525, 1.0 },
        warning = { 1.000, 0.790, 0.335, 1.0 },
        danger = { 0.980, 0.380, 0.420, 1.0 },
        shadow = { 0.0, 0.0, 0.0, 0.45 },
    },
    Classic = {
        background = { 0.055, 0.045, 0.034, 0.965 },
        surface = { 0.100, 0.082, 0.060, 0.980 },
        surfaceRaised = { 0.130, 0.108, 0.078, 0.985 },
        border = { 0.372, 0.302, 0.188, 1.0 },
        borderStrong = { 0.560, 0.454, 0.286, 1.0 },
        accent = { 0.855, 0.680, 0.282, 1.0 },
        accentSoft = { 0.855, 0.680, 0.282, 0.18 },
        titleBar = { 0.115, 0.090, 0.062, 0.985 },
        titleText = { 1.000, 0.925, 0.760, 1.0 },
        text = { 0.930, 0.900, 0.840, 1.0 },
        textMuted = { 0.760, 0.700, 0.600, 1.0 },
        button = { 0.150, 0.118, 0.078, 1.0 },
        buttonHover = { 0.188, 0.145, 0.098, 1.0 },
        buttonPressed = { 0.228, 0.176, 0.116, 1.0 },
        success = { 0.420, 0.820, 0.540, 1.0 },
        warning = { 1.000, 0.820, 0.420, 1.0 },
        danger = { 0.950, 0.420, 0.420, 1.0 },
        shadow = { 0.0, 0.0, 0.0, 0.45 },
    },
    Transparent = {
        background = { 0.020, 0.024, 0.032, 0.78 },
        surface = { 0.055, 0.062, 0.082, 0.82 },
        surfaceRaised = { 0.078, 0.086, 0.112, 0.88 },
        border = { 0.180, 0.205, 0.255, 0.85 },
        borderStrong = { 0.235, 0.270, 0.345, 0.95 },
        accent = { 0.380, 0.760, 1.000, 1.0 },
        accentSoft = { 0.380, 0.760, 1.000, 0.16 },
        titleBar = { 0.048, 0.056, 0.074, 0.84 },
        titleText = { 0.965, 0.972, 1.000, 1.0 },
        text = { 0.910, 0.930, 0.980, 1.0 },
        textMuted = { 0.690, 0.735, 0.820, 1.0 },
        button = { 0.090, 0.104, 0.135, 0.88 },
        buttonHover = { 0.115, 0.132, 0.170, 0.92 },
        buttonPressed = { 0.140, 0.162, 0.205, 0.96 },
        success = { 0.290, 0.835, 0.525, 1.0 },
        warning = { 1.000, 0.790, 0.335, 1.0 },
        danger = { 0.980, 0.380, 0.420, 1.0 },
        shadow = { 0.0, 0.0, 0.0, 0.40 },
    },
}

function Themes:GetList()
    local names = {}
    for name in pairs(PRESETS) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function Themes:GetNextTheme(currentTheme)
    local list = self:GetList()
    for index, name in ipairs(list) do
        if name == currentTheme then
            return list[index + 1] or list[1]
        end
    end
    return list[1]
end

-- FableNeon is the suite default; unknown/empty theme names resolve to it.
Themes.DEFAULT = "FableNeon"

function Themes:Resolve(themeName, accentColor)
    local preset = PRESETS[themeName] or PRESETS[Themes.DEFAULT] or PRESETS.Dark
    local resolved = {}

    for key, value in pairs(preset) do
        if key == "spectrum" and type(value) == "table" then
            -- Nested map of named colors — clone each entry, not the wrapper.
            local s = {}
            for name, color in pairs(value) do
                s[name] = CloneColor(color)
            end
            resolved[key] = s
        else
            resolved[key] = CloneColor(value)
        end
    end

    if type(accentColor) == "table" then
        resolved.accent = CloneColor(accentColor)
        resolved.accentSoft = {
            resolved.accent[1],
            resolved.accent[2],
            resolved.accent[3],
            0.18,
        }
    end

    return resolved
end

function Themes:Apply(frame, themeName, accentColor)
    if not frame or not frame.SetBackdrop then
        return
    end

    local theme = self:Resolve(themeName, accentColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(theme.background))
    frame:SetBackdropBorderColor(unpack(theme.border))
end

function Themes:ApplyPanel(frame, themeName, accentColor, useRaisedSurface)
    if not frame or not frame.SetBackdrop then
        return
    end

    local theme = self:Resolve(themeName, accentColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(useRaisedSurface and theme.surfaceRaised or theme.surface))
    frame:SetBackdropBorderColor(unpack(theme.border))
end

--- Locale-safe font application.
-- Priority: explicit customFont > _G.STANDARD_TEXT_FONT (locale-aware).
-- Hard-coded English-only font paths (e.g. FRIZQT__.TTF) break non-Latin
-- locales (ruRU, koKR, zhCN, zhTW). Always route font assignments through
-- this helper so client font fallback is preserved.
-- Pattern adapted from VamoosesGuildCraft/UI/ThemeEngine.lua (lines 76-94).
---@param fontString table FontString-like object with SetFont
---@param customFont string? optional override font path
---@param size number? font size (defaults to current size or 12)
---@param flags string? font flags (defaults to "")
---@return boolean applied
function Themes:ApplyFont(fontString, customFont, size, flags)
    if not fontString or not fontString.SetFont then
        return false
    end

    local hasCustom = type(customFont) == "string" and customFont ~= ""
    local file
    if hasCustom then
        file = customFont
    else
        file = _G.STANDARD_TEXT_FONT
    end

    if not file then
        return false
    end

    if not size then
        if fontString.GetFont then
            local _, currentSize = fontString:GetFont()
            size = currentSize or 12
        else
            size = 12
        end
    end

    fontString:SetFont(file, size, flags or "")
    return true
end

function Themes:ApplyTitleText(fontString, themeName, accentColor, customFont, size, flags)
    if not fontString then
        return
    end

    local theme = self:Resolve(themeName, accentColor)
    fontString:SetTextColor(unpack(theme.titleText))
    if customFont or size or flags then
        self:ApplyFont(fontString, customFont, size, flags)
    end
end

function Themes:ApplyBodyText(fontString, themeName, accentColor, muted, customFont, size, flags)
    if not fontString then
        return
    end

    local theme = self:Resolve(themeName, accentColor)
    fontString:SetTextColor(unpack(muted and theme.textMuted or theme.text))
    if customFont or size or flags then
        self:ApplyFont(fontString, customFont, size, flags)
    end
end

function Themes:StyleFlatButton(button, themeName, accentColor)
    if not button or button.FabledUIStyled then
        return
    end

    local theme = self:Resolve(themeName, accentColor)

    -- Strip Blizzard template art (UIPanelButtonTemplate etc.) so its native
    -- red/tan textures don't bleed through our flat/neon skin — but ONLY on
    -- templated buttons. Icon buttons (plain SetNormalTexture art, e.g. the
    -- profession-overlay side tabs) must keep their textures.
    local isTemplated = button.Left or button.Right or button.Middle
        or button.Center or button.NineSlice or button.TopLeft
    if isTemplated then
        if button.SetNormalTexture then pcall(button.SetNormalTexture, button, nil) end
        if button.SetPushedTexture then pcall(button.SetPushedTexture, button, nil) end
        if button.SetDisabledTexture then pcall(button.SetDisabledTexture, button, nil) end
        if button.SetHighlightTexture then pcall(button.SetHighlightTexture, button, nil) end
        local ht = button.GetHighlightTexture and button:GetHighlightTexture()
        if ht then pcall(ht.SetTexture, ht, nil); pcall(ht.SetAtlas, ht, nil); if ht.Hide then ht:Hide() end end
        for _, region in ipairs({ "Left", "Right", "Middle", "Center", "NineSlice",
            "TopLeft", "TopRight", "BottomLeft", "BottomRight",
            "TopMiddle", "BottomMiddle", "MiddleLeft", "MiddleRight",
            "LeftSeparator", "RightSeparator" }) do
            local r = button[region]
            if r and r.Hide then r:Hide() end
        end
    end

    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetPushedTextOffset(0, 0)
    if button.SetTextInsets then
        button:SetTextInsets(6, 6, 0, 0)
    end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    button.__fuiBackground = bg

    local borderTop = button:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetHeight(1)
    button.__fuiBorderTop = borderTop

    local borderBottom = button:CreateTexture(nil, "BORDER")
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetHeight(1)
    button.__fuiBorderBottom = borderBottom

    local borderLeft = button:CreateTexture(nil, "BORDER")
    borderLeft:SetPoint("TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT")
    borderLeft:SetWidth(1)
    button.__fuiBorderLeft = borderLeft

    local borderRight = button:CreateTexture(nil, "BORDER")
    borderRight:SetPoint("TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT")
    borderRight:SetWidth(1)
    button.__fuiBorderRight = borderRight

    local accent = button:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(1)
    button.__fuiAccent = accent

    local function UpdateVisual(state)
        local activeTheme = Themes:Resolve(themeName, accentColor)
        -- Hover/press must be unmissable: we stripped Blizzard's highlight
        -- textures, so state feedback comes entirely from bg + border shifts.
        local borderColor = activeTheme.border
        if state == "pressed" then
            ApplyColor(bg, activeTheme.accentSoft or activeTheme.buttonPressed)
            borderColor = activeTheme.accent
        elseif state == "hover" then
            ApplyColor(bg, activeTheme.buttonHover)
            borderColor = activeTheme.borderStrong or activeTheme.accent
        else
            ApplyColor(bg, activeTheme.button)
        end
        ApplyColor(button.__fuiBorderTop, borderColor)
        ApplyColor(button.__fuiBorderBottom, borderColor)
        ApplyColor(button.__fuiBorderLeft, borderColor)
        ApplyColor(button.__fuiBorderRight, borderColor)
        ApplyColor(accent, activeTheme.accent)
    end

    button:HookScript("OnEnter", function()
        UpdateVisual("hover")
    end)
    button:HookScript("OnLeave", function()
        UpdateVisual("normal")
    end)
    button:HookScript("OnMouseDown", function()
        UpdateVisual("pressed")
    end)
    button:HookScript("OnMouseUp", function()
        if button:IsMouseOver() then
            UpdateVisual("hover")
        else
            UpdateVisual("normal")
        end
    end)

    UpdateVisual("normal")
    button.FabledUIStyled = true
end

-- Restyle a stock UIPanelCloseButton (the jarring red ×) to match the suite:
-- a flat dark square with a muted × glyph that flushes red-pink on hover. The
-- close button is texture-based (not a templated button), so StyleFlatButton
-- can't catch it — this strips the stock textures and paints our own.
function Themes:StyleCloseButton(button, themeName, accentColor)
    if not button or button.FabledUICloseStyled then
        return
    end
    themeName = themeName or "FableNeon"

    for _, setter in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture" }) do
        if button[setter] then pcall(button[setter], button, nil) end
    end
    local ht = button.GetHighlightTexture and button:GetHighlightTexture()
    if ht then pcall(ht.SetTexture, ht, nil); pcall(ht.SetAtlas, ht, nil); if ht.Hide then ht:Hide() end end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    button.__fuiCloseBg = bg

    local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    glyph:SetPoint("CENTER", 0, 0)
    glyph:SetText("\195\151") -- × (U+00D7)
    button.__fuiCloseGlyph = glyph

    local function paint(state)
        local t = Themes:Resolve(themeName, accentColor)
        if state == "hover" then
            ApplyColor(bg, t.danger or t.buttonHover)
            local c = t.text or { 1, 1, 1, 1 }
            glyph:SetTextColor(c[1], c[2], c[3])
        else
            ApplyColor(bg, t.button)
            local c = t.textMuted or { 0.7, 0.7, 0.75, 1 }
            glyph:SetTextColor(c[1], c[2], c[3])
        end
    end

    button:HookScript("OnEnter", function() paint("hover") end)
    button:HookScript("OnLeave", function() paint("normal") end)
    paint("normal")
    button.FabledUICloseStyled = true
end

function Themes:ApplyTextureColor(texture, themeName, accentColor, tokenName)
    if not texture then
        return
    end

    local theme = self:Resolve(themeName, accentColor)
    ApplyColor(texture, theme[tokenName] or theme.accent)
end
