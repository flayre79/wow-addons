-- FabledUI UIToolkit — Effects layer (SVC-005)
-- Turns the flat theme tokens into the FableNeon look: additive-blend glow,
-- neon borders, gradient seams, and glowing controls. WoW has no CSS box-shadow,
-- so every "glow" here is an additive texture (SetBlendMode("ADD")) tinted at
-- runtime via SetVertexColor. All helpers are idempotent (guarded by a marker)
-- so re-applying on refresh is safe.

local T = FabledUI_UIToolkit
T.Effects = T.Effects or {}
local E = T.Effects

local GLOW = "Interface\\AddOns\\FabledUI_UIToolkit\\Textures\\glow-soft.tga"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function themeOf(themeName, accentColor)
    return T.Themes:Resolve(themeName, accentColor)
end

local function rgba(c, aOverride)
    return c[1] or 1, c[2] or 1, c[3] or 1, aOverride or (c[4] == nil and 1 or c[4])
end

-- Relative luminance of a 0..1 color; used to pick readable ink on a neon fill.
function E:Luminance(c)
    return 0.2126 * (c[1] or 0) + 0.7152 * (c[2] or 0) + 0.0722 * (c[3] or 0)
end

-- On-fill text rule: bright fills take near-black ink, dark fills take white.
-- (Cyan reads fine with dark text; purple needs white — the rule David locked.)
function E:InkFor(fillColor)
    if self:Luminance(fillColor) >= 0.55 then
        return { 0.03, 0.05, 0.09, 1.0 }
    end
    return { 1, 1, 1, 1 }
end

-- Soft outer glow around a rectangular frame: 4 corner blobs + 4 edge bars of
-- the radial glow texture, additive and tinted. Approximates a neon halo without
-- per-pixel edge textures. Returns the container table of textures (cached).
function E:AddOuterGlow(frame, color, size, alpha)
    if not frame or not frame.CreateTexture then return end
    size = size or 20
    alpha = alpha or 0.45
    local r, g, b = color[1], color[2], color[3]
    local g8 = frame.__fuiGlow
    if not g8 then
        g8 = {}
        local layers = { "tl", "tr", "bl", "br", "t", "b", "l", "rt" }
        for _, k in ipairs(layers) do
            local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
            tex:SetTexture(GLOW)
            tex:SetBlendMode("ADD")
            g8[k] = tex
        end
        frame.__fuiGlow = g8
    end
    for _, k in pairs(g8) do k:SetVertexColor(r, g, b, alpha); k:ClearAllPoints() end
    local s = size
    -- corners (square blobs centered on each corner)
    g8.tl:SetSize(s * 2, s * 2); g8.tl:SetPoint("CENTER", frame, "TOPLEFT")
    g8.tr:SetSize(s * 2, s * 2); g8.tr:SetPoint("CENTER", frame, "TOPRIGHT")
    g8.bl:SetSize(s * 2, s * 2); g8.bl:SetPoint("CENTER", frame, "BOTTOMLEFT")
    g8.br:SetSize(s * 2, s * 2); g8.br:SetPoint("CENTER", frame, "BOTTOMRIGHT")
    -- edges (stretched blobs along each side)
    g8.t:SetHeight(s * 2); g8.t:SetPoint("LEFT", g8.tl, "CENTER"); g8.t:SetPoint("RIGHT", g8.tr, "CENTER")
    g8.b:SetHeight(s * 2); g8.b:SetPoint("LEFT", g8.bl, "CENTER"); g8.b:SetPoint("RIGHT", g8.br, "CENTER")
    g8.l:SetWidth(s * 2); g8.l:SetPoint("TOP", g8.tl, "CENTER"); g8.l:SetPoint("BOTTOM", g8.bl, "CENTER")
    g8.rt:SetWidth(s * 2); g8.rt:SetPoint("TOP", g8.tr, "CENTER"); g8.rt:SetPoint("BOTTOM", g8.br, "CENTER")
    return g8
end

-- Crisp 1px neon border (4 thin bright textures). The definition line; pair with
-- AddOuterGlow for the soft halo.
function E:AddNeonBorder(frame, color, thickness)
    if not frame or not frame.CreateTexture then return end
    thickness = thickness or 1
    local b = frame.__fuiBorder
    if not b then
        b = {}
        for _, k in ipairs({ "t", "b", "l", "r" }) do
            b[k] = frame:CreateTexture(nil, "OVERLAY")
            b[k]:SetTexture(WHITE)
        end
        frame.__fuiBorder = b
    end
    for _, k in pairs(b) do k:SetVertexColor(rgba(color)); k:ClearAllPoints() end
    b.t:SetHeight(thickness); b.t:SetPoint("TOPLEFT"); b.t:SetPoint("TOPRIGHT")
    b.b:SetHeight(thickness); b.b:SetPoint("BOTTOMLEFT"); b.b:SetPoint("BOTTOMRIGHT")
    b.l:SetWidth(thickness); b.l:SetPoint("TOPLEFT"); b.l:SetPoint("BOTTOMLEFT")
    b.r:SetWidth(thickness); b.r:SetPoint("TOPRIGHT"); b.r:SetPoint("BOTTOMRIGHT")
    return b
end

local PILL_FILL = "Interface\\AddOns\\FabledUI_UIToolkit\\Textures\\pill-fill.tga"
local PILL_BORDER = "Interface\\AddOns\\FabledUI_UIToolkit\\Textures\\pill-border.tga"
local SLICE = 10

-- Rounded fill background (nine-sliced so corners stay round at any size).
-- Tint via the color arg. Cached on the frame so it's idempotent.
function E:RoundedFill(frame, color, layer, subLevel)
    local t = frame.__fuiFill
    if not t then
        t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
        t:SetAllPoints()
        t:SetTexture(PILL_FILL)
        if t.SetTextureSliceMargins then t:SetTextureSliceMargins(SLICE, SLICE, SLICE, SLICE) end
        frame.__fuiFill = t
    end
    if color then t:SetVertexColor(rgba(color)) end
    return t
end

-- Rounded stroke (outline) matching the rounded fill. Replaces AddNeonBorder for
-- pill-shaped widgets.
function E:RoundedStroke(frame, color)
    local t = frame.__fuiStroke
    if not t then
        t = frame:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture(PILL_BORDER)
        if t.SetTextureSliceMargins then t:SetTextureSliceMargins(SLICE, SLICE, SLICE, SLICE) end
        frame.__fuiStroke = t
    end
    if color then t:SetVertexColor(rgba(color)) end
    return t
end

-- The signature gradient seam (cyan -> purple) under a title bar or as a divider.
-- Height 2px by default. Anchors itself across the parent unless points are given.
function E:AddSeam(parent, fromColor, toColor, height)
    if not parent or not parent.CreateTexture then return end
    local seam = parent.__fuiSeam
    if not seam then
        seam = parent:CreateTexture(nil, "OVERLAY")
        seam:SetTexture(WHITE)
        parent.__fuiSeam = seam
    end
    seam:SetHeight(height or 2)
    if seam.SetGradient and CreateColor then
        local a = CreateColor(rgba(fromColor))
        local c = CreateColor(rgba(toColor))
        seam:SetGradient("HORIZONTAL", a, c)
    else
        seam:SetVertexColor(rgba(fromColor))
    end
    return seam
end

-- Apply the full neon chrome to a shell window: cyan edge + purple halo + seam.
-- `anchorSeamTo` (optional) is the title-bar frame the seam sits under.
function E:StyleWindow(frame, themeName, accentColor, anchorSeamTo)
    if not frame then return end
    local th = themeOf(themeName, accentColor)
    self:AddOuterGlow(frame, th.accent2 or th.accent, 22, 0.40)   -- purple halo
    self:AddNeonBorder(frame, th.borderStrong or th.accent, 1)     -- cyan edge
    if anchorSeamTo then
        local seam = self:AddSeam(frame, th.accent, th.accent2 or th.accent, 2)
        seam:ClearAllPoints()
        seam:SetPoint("BOTTOMLEFT", anchorSeamTo, "BOTTOMLEFT", 1, -1)
        seam:SetPoint("BOTTOMRIGHT", anchorSeamTo, "BOTTOMRIGHT", -1, -1)
    end
    return frame
end

-- Add a hover glow to an already-created button (composes with StyleFlatButton).
-- Lights an additive halo + accent underline on enter; clears on leave.
function E:StyleNeonButton(button, themeName, accentColor)
    if not button or button.__fuiNeon then return end
    local th = themeOf(themeName, accentColor)
    local glow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetTexture(GLOW); glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -8, 8); glow:SetPoint("BOTTOMRIGHT", 8, -8)
    glow:SetVertexColor(th.accent[1], th.accent[2], th.accent[3], 0)
    button:HookScript("OnEnter", function() glow:SetAlpha(0.5) end)
    button:HookScript("OnLeave", function() glow:SetAlpha(0) end)
    glow:SetAlpha(0)
    button.__fuiNeonGlow = glow
    button.__fuiNeon = true
    return button
end

-- Style a StatusBar as a glowing cyan->purple progress bar. `bar` is a StatusBar.
function E:StyleProgressBar(bar, themeName, accentColor)
    if not bar or not bar.SetStatusBarTexture then return end
    local th = themeOf(themeName, accentColor)
    bar:SetStatusBarTexture(WHITE)
    local tex = bar:GetStatusBarTexture()
    if tex and tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(rgba(th.accent)), CreateColor(rgba(th.accent2 or th.accent)))
    end
    if not bar.__fuiTrack then
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        track:SetColorTexture(0.13, 0.11, 0.21, 1)
        bar.__fuiTrack = track
    end
    return bar
end

-- Neon-ify a CheckButton: dark box, cyan additive check, neon border, hover glow.
function E:StyleCheckbox(check, themeName, accentColor)
    if not check or check.__fuiCheck then return end
    local th = themeOf(themeName, accentColor)
    self:AddNeonBorder(check, th.borderStrong or th.accent, 1)
    local normal = check.GetNormalTexture and check:GetNormalTexture()
    if normal then normal:SetColorTexture(th.button[1], th.button[2], th.button[3], 0.9) end
    local pushed = check.GetPushedTexture and check:GetPushedTexture()
    if pushed then pushed:SetColorTexture(th.buttonPressed[1], th.buttonPressed[2], th.buttonPressed[3], 1) end
    local checked = check.GetCheckedTexture and check:GetCheckedTexture()
    if checked then
        checked:SetColorTexture(rgba(th.accent, 0.95))
        checked:SetBlendMode("ADD")
    end
    local hi = check.GetHighlightTexture and check:GetHighlightTexture()
    if hi then hi:SetColorTexture(rgba(th.accent, 0.20)); hi:SetBlendMode("ADD") end
    check.__fuiCheck = true
    return check
end

-- Resolve a named spectrum color from the theme (cyan/purple/pink/green/amber/azure).
-- Falls back to accent if the name is unknown.
function E:Spectrum(name, themeName, accentColor)
    local th = themeOf(themeName, accentColor)
    local s = th.spectrum
    return (s and s[name]) or th.accent
end
