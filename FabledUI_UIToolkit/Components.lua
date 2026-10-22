-- FabledUI UIToolkit — Neon Components (SVC-005)
-- Purpose-built FableNeon widgets. These are bare frames (NO Blizzard templates
-- like UIPanelButtonTemplate), so no native art bleeds through and we control
-- sizing/anchoring exactly. Backgrounds/borders use nine-sliced rounded pill
-- textures. Addon panels are rebuilt on these. Validate the look via /fuineon.

local T = FabledUI_UIToolkit
T.Components = T.Components or {}
local C = T.Components

local function theme()
    return T.Themes:Resolve(T.Themes.DEFAULT)
end

local function neonFont(fs, size)
    if T.Themes and T.Themes.ApplyFont then
        T.Themes:ApplyFont(fs, nil, size or 13)
    end
end

local E -- resolved lazily so load order can't bite us
local function fx() E = E or T.Effects; return E end

-- ── Button ──────────────────────────────────────────────────────────────────
-- opts: text, width, height, primary (cyan fill), onClick, accent (spectrum key)
function C:CreateButton(parent, opts)
    opts = opts or {}
    local th = theme()
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(opts.width or 120, opts.height or 28)

    local fill = opts.accent and fx():Spectrum(opts.accent) or th.accent
    local bg = fx():RoundedFill(b)
    b.__bg = bg
    local function paint(state)
        if opts.primary then
            bg:SetVertexColor(fill[1], fill[2], fill[3], 1)
        else
            local c = state == "hover" and th.buttonHover or th.button
            bg:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        end
    end
    paint("normal")
    fx():RoundedStroke(b, opts.primary and fill or th.border)

    local fs = b:CreateFontString(nil, "OVERLAY")
    neonFont(fs, opts.fontSize or 13)
    fs:SetPoint("CENTER")
    fs:SetText(opts.text or "Button")
    if opts.primary then
        local ink = fx():InkFor(fill)
        fs:SetTextColor(ink[1], ink[2], ink[3], 1)
    else
        fs:SetTextColor(th.text[1], th.text[2], th.text[3], 1)
    end
    b.__text = fs

    fx():StyleNeonButton(b, T.Themes.DEFAULT)
    b:HookScript("OnEnter", function()
        paint("hover")
        fx():RoundedStroke(b, opts.primary and fill or th.borderStrong)
    end)
    b:HookScript("OnLeave", function()
        paint("normal")
        fx():RoundedStroke(b, opts.primary and fill or th.border)
    end)
    if opts.onClick then b:SetScript("OnClick", opts.onClick) end
    function b:SetLabel(t) fs:SetText(t) end
    -- Compat shims so component buttons drop into code written for
    -- UIPanelButtonTemplate: SetText routes to our fontstring, and
    -- enable/disable gets a visible dim.
    b.SetText = b.SetLabel
    b:HookScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    b:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
    return b
end

-- ── Dropdown (pill button + MenuUtil context menu) ───────────────────────────
-- opts: width, height, defaultText, getOptions() -> { {text, value, isSelected()} },
--       onSelect(value, text). Exposes .Text (FontString) for external label sync.
function C:CreateDropdown(parent, opts)
    opts = opts or {}
    local th = theme()
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(opts.width or 160, opts.height or 30)
    fx():RoundedFill(f, th.button)
    fx():RoundedStroke(f, th.border)

    local fs = f:CreateFontString(nil, "OVERLAY")
    neonFont(fs, 12)
    fs:SetPoint("LEFT", 12, 0)
    fs:SetPoint("RIGHT", -22, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(opts.defaultText or "Select")
    fs:SetTextColor(th.text[1], th.text[2], th.text[3], 1)
    f.Text = fs

    -- Texture arrow — the "▼" glyph is missing from WoW's default fonts and
    -- renders as a tofu box.
    local arrow = f:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(10, 6)
    arrow:SetPoint("RIGHT", -9, 0)
    arrow:SetTexture("Interface\\AddOns\\FabledUI_UIToolkit\\Textures\\arrow-down.tga")
    arrow:SetVertexColor(th.accent[1], th.accent[2], th.accent[3], 0.9)

    f:HookScript("OnEnter", function() fx():RoundedStroke(f, th.borderStrong) end)
    f:HookScript("OnLeave", function() fx():RoundedStroke(f, th.border) end)

    f:SetScript("OnClick", function()
        local options = opts.getOptions and opts.getOptions() or {}
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(f, function(_, rootDescription)
                for _, option in ipairs(options) do
                    local text, value = option.text, option.value
                    local isSelected = option.isSelected
                    rootDescription:CreateRadio(text, function()
                        return isSelected and isSelected() or false
                    end, function()
                        if opts.onSelect then opts.onSelect(value, text) end
                        fs:SetText(text)
                    end)
                end
            end)
        else
            -- No MenuUtil: cycle to the next option on click.
            local currentIndex = 0
            for i, option in ipairs(options) do
                if option.isSelected and option.isSelected() then currentIndex = i; break end
            end
            local nextOption = options[(currentIndex % #options) + 1]
            if nextOption then
                if opts.onSelect then opts.onSelect(nextOption.value, nextOption.text) end
                fs:SetText(nextOption.text)
            end
        end
    end)

    function f:SetLabel(t) fs:SetText(t) end
    f.SetText = f.SetLabel
    return f
end

-- ── Toggle (pill) ────────────────────────────────────────────────────────────
-- opts: text, checked, fill (spectrum key), onToggle(state)
function C:CreateToggle(parent, opts)
    opts = opts or {}
    local th = theme()
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(opts.width or 112, opts.height or 28)
    b.__on = opts.checked and true or false
    b.__fill = opts.fill or "cyan"

    local bg = fx():RoundedFill(b); b.__bg = bg
    local dot = b:CreateTexture(nil, "ARTWORK"); dot:SetSize(8, 8); dot:SetPoint("LEFT", 11, 0)
    local fs = b:CreateFontString(nil, "OVERLAY"); neonFont(fs, 12)
    fs:SetPoint("LEFT", dot, "RIGHT", 8, 0); fs:SetText(opts.text or "Toggle")

    local function paint()
        local col = fx():Spectrum(b.__fill)
        if b.__on then
            bg:SetVertexColor(col[1], col[2], col[3], 1)          -- solid neon fill
            local ink = fx():InkFor(col)
            fs:SetTextColor(ink[1], ink[2], ink[3], 1)
            dot:SetColorTexture(ink[1], ink[2], ink[3], 1)
            fx():RoundedStroke(b, col)
        else
            bg:SetVertexColor(th.button[1], th.button[2], th.button[3], 1)
            fs:SetTextColor(th.textMuted[1], th.textMuted[2], th.textMuted[3], 1)
            dot:SetColorTexture(0.22, 0.19, 0.31, 1)
            fx():RoundedStroke(b, th.border)
        end
    end
    paint()

    b:SetScript("OnClick", function()
        b.__on = not b.__on; paint()
        if opts.onToggle then opts.onToggle(b.__on) end
    end)
    function b:SetChecked(v) self.__on = v and true or false; paint() end
    function b:GetChecked() return self.__on end
    return b
end

-- ── Segmented control (e.g. Current | All) ────────────────────────────────────
function C:CreateSegmented(parent, opts)
    opts = opts or {}
    local th = theme()
    local options = opts.options or {}
    local segW, h = opts.segWidth or 66, opts.height or 28
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(segW * #options, h)
    f.buttons = {}; f.selected = opts.selected or 1
    fx():RoundedFill(f, th.button)
    local x = 0
    for i, name in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(segW, h); b:SetPoint("LEFT", x, 0); x = x + segW
        local sel = b:CreateTexture(nil, "ARTWORK"); sel:SetPoint("TOPLEFT", 2, -2); sel:SetPoint("BOTTOMRIGHT", -2, 2)
        b.__sel = sel
        local fs = b:CreateFontString(nil, "OVERLAY"); neonFont(fs, 12); fs:SetPoint("CENTER"); fs:SetText(name); b.__text = fs
        b:SetScript("OnClick", function() f:Select(i); if opts.onSelect then opts.onSelect(i, name) end end)
        f.buttons[i] = b
    end
    fx():RoundedStroke(f, th.border)
    function f:refresh()
        local t = theme()
        for i, b in ipairs(self.buttons) do
            if i == self.selected then
                b.__sel:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 0.14)
                b.__text:SetTextColor(t.accent[1], t.accent[2], t.accent[3], 1)
            else
                b.__sel:SetColorTexture(0, 0, 0, 0)
                b.__text:SetTextColor(t.textMuted[1], t.textMuted[2], t.textMuted[3], 1)
            end
        end
    end
    function f:Select(i) self.selected = i; self:refresh() end
    f:refresh()
    return f
end

-- ── Search box ────────────────────────────────────────────────────────────────
function C:CreateSearchBox(parent, opts)
    opts = opts or {}
    local th = theme()
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(opts.width or 220, opts.height or 30)
    fx():RoundedFill(f, { 0.055, 0.043, 0.10, 1 })
    fx():RoundedStroke(f, th.border)

    local icon = f:CreateTexture(nil, "ARTWORK"); icon:SetSize(14, 14); icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon"); icon:SetVertexColor(th.textMuted[1], th.textMuted[2], th.textMuted[3], 1)

    local eb = CreateFrame("EditBox", nil, f); eb:SetAutoFocus(false)
    eb:SetPoint("LEFT", 29, 0); eb:SetPoint("RIGHT", -10, 0); eb:SetHeight(f:GetHeight())
    neonFont(eb, 13); eb:SetTextColor(th.text[1], th.text[2], th.text[3], 1)

    local ph = f:CreateFontString(nil, "OVERLAY"); neonFont(ph, 13)
    ph:SetPoint("LEFT", eb, "LEFT", 2, 0); ph:SetText(opts.placeholder or "Search…")
    ph:SetTextColor(th.textMuted[1], th.textMuted[2], th.textMuted[3], 1)

    eb:SetScript("OnTextChanged", function(self)
        ph:SetShown(self:GetText() == "")
        if opts.onChange then opts.onChange(self:GetText()) end
    end)
    eb:SetScript("OnEditFocusGained", function() fx():RoundedStroke(f, th.borderStrong) end)
    eb:SetScript("OnEditFocusLost", function() fx():RoundedStroke(f, th.border) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.editBox = eb
    return f
end

-- ── Tab strip (glowing underline, no boxes) ───────────────────────────────────
function C:CreateTabStrip(parent, opts)
    opts = opts or {}
    local th = theme()
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(opts.height or 34)
    strip.tabs = {}; strip.selected = opts.selected or 1

    local underline = strip:CreateTexture(nil, "OVERLAY"); underline:SetHeight(2)
    underline:SetColorTexture(1, 1, 1, 1)
    if underline.SetGradient and CreateColor then
        local a2 = th.accent2 or th.accent
        underline:SetGradient("HORIZONTAL", CreateColor(th.accent[1], th.accent[2], th.accent[3], 1),
            CreateColor(a2[1], a2[2], a2[3], 1))
    end
    strip.__underline = underline

    local x = 0
    for i, name in ipairs(opts.tabs or {}) do
        local t = CreateFrame("Button", nil, strip)
        local fs = t:CreateFontString(nil, "OVERLAY"); neonFont(fs, 13); fs:SetPoint("CENTER"); fs:SetText(name)
        t.__text = fs
        local w = (fs:GetStringWidth() or 40) + 26
        t:SetSize(w, strip:GetHeight()); t:SetPoint("LEFT", x, 0); x = x + w + 2
        t:SetScript("OnClick", function() strip:Select(i); if opts.onSelect then opts.onSelect(i, name) end end)
        t:HookScript("OnEnter", function() if strip.selected ~= i then fs:SetTextColor(th.text[1], th.text[2], th.text[3], 1) end end)
        t:HookScript("OnLeave", function() strip:refresh() end)
        strip.tabs[i] = t
    end
    strip:SetWidth(x)

    function strip:refresh()
        local t = theme()
        for i, tab in ipairs(self.tabs) do
            if i == self.selected then tab.__text:SetTextColor(t.text[1], t.text[2], t.text[3], 1)
            else tab.__text:SetTextColor(t.textMuted[1], t.textMuted[2], t.textMuted[3], 1) end
        end
        local sel = self.tabs[self.selected]
        if sel then
            self.__underline:ClearAllPoints()
            self.__underline:SetPoint("BOTTOMLEFT", sel, "BOTTOMLEFT", 9, 0)
            self.__underline:SetPoint("BOTTOMRIGHT", sel, "BOTTOMRIGHT", -9, 0)
        end
    end
    function strip:Select(i) self.selected = i; self:refresh() end
    strip:refresh()
    return strip
end

-- ── Progress bar (cyan->purple glow) ──────────────────────────────────────────
function C:CreateProgressBar(parent, opts)
    opts = opts or {}
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(opts.width or 150, opts.height or 6)
    bar:SetMinMaxValues(0, opts.max or 100); bar:SetValue(opts.value or 0)
    fx():StyleProgressBar(bar, T.Themes.DEFAULT)
    return bar
end

-- ── Tag pill (spectrum-colored) ───────────────────────────────────────────────
function C:CreateTag(parent, opts)
    opts = opts or {}
    local col = fx():Spectrum(opts.color or "cyan")
    local f = CreateFrame("Frame", nil, parent)
    local fs = f:CreateFontString(nil, "OVERLAY"); neonFont(fs, 11); fs:SetPoint("CENTER")
    fs:SetText(opts.text or "Tag"); fs:SetTextColor(col[1], col[2], col[3], 1)
    f:SetSize((fs:GetStringWidth() or 20) + 16, opts.height or 18)
    fx():RoundedFill(f, { col[1], col[2], col[3], 0.12 })
    fx():RoundedStroke(f, { col[1], col[2], col[3], 0.40 })
    return f
end

-- ── Storybook gallery: /fuineon ───────────────────────────────────────────────
function C:ShowGallery()
    if self._gallery then self._gallery:Show(); return self._gallery end
    if not (T.Shell and T.Shell.CreateWindow) then
        print("|cff8888ff[FabledUI]|r UIToolkit Shell unavailable — cannot open gallery.")
        return
    end
    local win = T.Shell:CreateWindow("FabledUI_NeonGallery", {
        title = "FableNeon — Components", subtitle = "storybook", width = 580, height = 600, theme = "FableNeon",
    })
    local th = theme()
    local pad = CreateFrame("Frame", nil, win)
    pad:SetPoint("TOPLEFT", 16, -44); pad:SetPoint("BOTTOMRIGHT", -16, 40)

    local y = 0
    local function header(txt)
        local fs = pad:CreateFontString(nil, "OVERLAY"); neonFont(fs, 11)
        fs:SetPoint("TOPLEFT", 0, y); fs:SetText(txt:upper())
        fs:SetTextColor(th.textMuted[1], th.textMuted[2], th.textMuted[3], 1)
        y = y - 20
    end
    local function place(frame, x) frame:SetParent(pad); frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", x or 0, y) end

    header("Buttons")
    place(self:CreateButton(pad, { text = "Add Ready (70)", primary = true, width = 130 }), 0)
    place(self:CreateButton(pad, { text = "Shopping Export", width = 130 }), 142)
    place(self:CreateButton(pad, { text = "Rescan", width = 90 }), 284)
    y = y - 42

    header("Toggles")
    place(self:CreateToggle(pad, { text = "+ Mats", checked = true, fill = "cyan" }), 0)
    place(self:CreateToggle(pad, { text = "Uncollected", checked = true, fill = "purple", width = 128 }), 122)
    place(self:CreateToggle(pad, { text = "Ready only", fill = "cyan" }), 262)
    y = y - 42

    header("Segmented / Search")
    place(self:CreateSegmented(pad, { options = { "Current", "All" } }), 0)
    place(self:CreateSearchBox(pad, { placeholder = "Search recipes…", width = 240 }), 150)
    y = y - 44

    header("Tabs")
    place(self:CreateTabStrip(pad, { tabs = { "Recipes", "Queue", "Materials", "Alts" }, selected = 1 }), 0)
    y = y - 44

    header("Progress")
    local pb = self:CreateProgressBar(pad, { value = 85, max = 100, width = 220 }); place(pb, 0)
    local pfs = pad:CreateFontString(nil, "OVERLAY"); neonFont(pfs, 11)
    pfs:SetPoint("LEFT", pb, "RIGHT", 10, 0); pfs:SetText("829 / 974 · 85%")
    pfs:SetTextColor(th.textMuted[1], th.textMuted[2], th.textMuted[3], 1)
    y = y - 34

    header("Tags")
    local tx = 0
    for _, t in ipairs({ { "Enchanting", "cyan" }, { "Midnight", "purple" }, { "Rank 3", "amber" }, { "Jewelcrafting", "pink" }, { "Herbalism", "green" } }) do
        local tag = self:CreateTag(pad, { text = t[1], color = t[2] }); place(tag, tx); tx = tx + tag:GetWidth() + 8
    end
    y = y - 34

    self._gallery = win
    if win.Show then win:Show() end
    if win.SetFrameStrata then win:SetFrameStrata("DIALOG") end
    if win.Raise then win:Raise() end
    if win.ClearAllPoints and win.SetPoint then
        win:ClearAllPoints(); win:SetPoint("CENTER", UIParent, "CENTER", 140, 80)
    end
    print("|cff3ae9ff[FabledUI]|r Neon component gallery opened.")
    return win
end

print("|cff3ae9ff[FabledUI]|r UIToolkit components loaded — type /fuineon for the gallery.")

SLASH_FUINEON1 = "/fuineon"
SlashCmdList["FUINEON"] = function() C:ShowGallery() end
