local T = FabledUI_UIToolkit
T.Shell = T.Shell or {}

local Shell = T.Shell

local function CreateColorTexture(parent, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    return texture
end

local function CreateHeaderButton(parent, width, labelText, tooltipText)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 20, 20)

    local bg = CreateColorTexture(button, "BACKGROUND")
    bg:SetAllPoints()
    button.Background = bg

    local border = CreateColorTexture(button, "BORDER")
    border:SetPoint("TOPLEFT")
    border:SetPoint("TOPRIGHT")
    border:SetHeight(1)
    button.BorderTop = border

    local borderBottom = CreateColorTexture(button, "BORDER")
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetHeight(1)
    button.BorderBottom = borderBottom

    local borderLeft = CreateColorTexture(button, "BORDER")
    borderLeft:SetPoint("TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT")
    borderLeft:SetWidth(1)
    button.BorderLeft = borderLeft

    local borderRight = CreateColorTexture(button, "BORDER")
    borderRight:SetPoint("TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT")
    borderRight:SetWidth(1)
    button.BorderRight = borderRight

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(labelText or "")
    button.Label = label

    if tooltipText then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return button
end

-- FableNeon brand wordmark: per-letter gradient "FABLED" + muted subname.
-- WoW fonts can't gradient a FontString, so the cyan->purple->pink sweep is
-- baked per letter. "FabledUI - Crafty" renders as [F] FABLED / CRAFTY.
local BRAND_WORD = "|cff3ae9ffF|r|cff71c9ffA|r|cff9fa9ffB|r|cffc58bffL|r|cffe273d9E|r|cffff5aa6D|r"
local function BrandTitle(themeName, rawTitle)
    if themeName ~= "FableNeon" then
        return rawTitle
    end
    local sub = tostring(rawTitle or "Window")
    sub = sub:gsub("^FabledUI%s*[-:]%s*", "")
    return BRAND_WORD .. " |cff615e86/ " .. sub:upper() .. "|r"
end

local function StyleHeaderButton(button, themeName, accentColor)
    if not button then
        return
    end

    local theme = T.Themes:Resolve(themeName, accentColor)

    local function ApplyState(state)
        if state == "pressed" then
            button.Background:SetColorTexture(unpack(theme.buttonPressed))
        elseif state == "hover" then
            button.Background:SetColorTexture(unpack(theme.buttonHover))
        else
            button.Background:SetColorTexture(unpack(theme.button))
        end

        button.BorderTop:SetColorTexture(unpack(theme.borderStrong))
        button.BorderBottom:SetColorTexture(unpack(theme.borderStrong))
        button.BorderLeft:SetColorTexture(unpack(theme.borderStrong))
        button.BorderRight:SetColorTexture(unpack(theme.borderStrong))
        button.Label:SetTextColor(unpack(theme.titleText))
    end

    button:HookScript("OnEnter", function()
        ApplyState("hover")
    end)
    button:HookScript("OnLeave", function()
        ApplyState("normal")
    end)
    button:HookScript("OnMouseDown", function()
        ApplyState("pressed")
    end)
    button:HookScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            ApplyState("hover")
        else
            ApplyState("normal")
        end
    end)

    ApplyState("normal")
end

function Shell:CreateWindow(frameName, options)
    options = options or {}

    local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    frame:SetFrameStrata(options.frameStrata or "MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetResizable(options.resizable ~= false)

    local minWidth = options.minWidth or options.width or 900
    local minHeight = options.minHeight or options.height or 600
    local maxWidth = options.maxWidth or 1800
    local maxHeight = options.maxHeight or 1200
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    else
        if frame.SetMinResize then
            frame:SetMinResize(minWidth, minHeight)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(maxWidth, maxHeight)
        end
    end

    local state = T.WindowState:Ensure(options.state or {}, {
        width = options.width or minWidth,
        height = options.height or minHeight,
    })

    -- Repair a saved height that is below the window's own minimum. Before the
    -- rollup capture guard below existed, minimising and then dragging (or
    -- closing) the window persisted the 44px title-bar height as the window
    -- size, and every later open drew the full content inside that bar --
    -- reported as "massively squished and overlapping". Anyone who already hit
    -- it has the bad number in their SavedVariables, so clamp on load rather
    -- than only preventing new occurrences.
    if type(state.height) == "number" and state.height < minHeight then
        state.height = minHeight
    end
    if type(state.width) == "number" and state.width < minWidth then
        state.width = minWidth
    end

    frame.FabledUIShell = {
        state = state,
        themeName = options.theme or (T.Themes and T.Themes.DEFAULT) or "Dark",
        accentColor = options.accentColor,
        titleText = options.title or "Window",
    }

    T.Themes:Apply(frame, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor)

    local shadow = CreateColorTexture(frame, "BACKGROUND")
    shadow:SetPoint("TOPLEFT", -6, 6)
    shadow:SetPoint("BOTTOMRIGHT", 6, -6)
    local shadowTheme = T.Themes:Resolve(frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor)
    shadow:SetColorTexture(unpack(shadowTheme.shadow))
    frame.Shadow = shadow

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    T.Themes:ApplyPanel(titleBar, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor, true)
    frame.TitleBar = titleBar

    local accent = CreateColorTexture(titleBar, "ARTWORK")
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", 0, 0)
    accent:SetHeight(2)
    T.Themes:ApplyTextureColor(accent, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor, "accent")
    frame.AccentStrip = accent

    -- FableNeon identity: soft outer halo + crisp neon edge, and upgrade the
    -- title accent strip to the cyan->purple gradient seam. Other themes stay flat.
    if T.Effects and frame.FabledUIShell.themeName == "FableNeon" then
        local th = T.Themes:Resolve(frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor)
        T.Effects:AddOuterGlow(frame, th.accent2 or th.accent, 22, 0.38)
        T.Effects:AddNeonBorder(frame, th.borderStrong or th.accent, 1)
        if accent.SetGradient and CreateColor then
            accent:SetColorTexture(1, 1, 1, 1)
            accent:SetGradient("HORIZONTAL", CreateColor(unpack(th.accent)), CreateColor(unpack(th.accent2 or th.accent)))
        end
    end

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetText(BrandTitle(frame.FabledUIShell.themeName, options.title or "Window"))
    T.Themes:ApplyTitleText(titleText, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor)
    frame.TitleText = titleText

    -- FableNeon: gradient glyph chip ahead of the wordmark ([F] FABLED / X).
    if frame.FabledUIShell.themeName == "FableNeon" then
        local glyph = titleBar:CreateTexture(nil, "ARTWORK")
        glyph:SetSize(16, 16)
        glyph:SetPoint("LEFT", 10, 0)
        glyph:SetTexture("Interface\\AddOns\\FabledUI_UIToolkit\\Textures\\pill-fill.tga")
        if glyph.SetGradient and CreateColor then
            glyph:SetGradient("HORIZONTAL",
                CreateColor(0.227, 0.914, 1.0, 1),
                CreateColor(0.706, 0.361, 1.0, 1))
        else
            glyph:SetVertexColor(0.227, 0.914, 1.0, 1)
        end
        local glyphLetter = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        glyphLetter:SetPoint("CENTER", glyph, "CENTER", 0.5, 0)
        glyphLetter:SetText("|cff0a0714F|r")
        frame.BrandGlyph = glyph
        titleText:ClearAllPoints()
        titleText:SetPoint("LEFT", glyph, "RIGHT", 7, 0)
    end

    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("TOPLEFT", 16, -34)
    subtitleText:SetPoint("TOPRIGHT", -16, -34)
    subtitleText:SetJustifyH("LEFT")
    subtitleText:SetMaxLines(1)
    subtitleText:SetText(options.subtitle or "")
    T.Themes:ApplyBodyText(subtitleText, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor, true)
    frame.SubtitleText = subtitleText
    subtitleText:SetShown((options.subtitle or "") ~= "")

    local headerButtons = CreateFrame("Frame", nil, titleBar)
    headerButtons:SetPoint("TOPRIGHT", -6, -4)
    headerButtons:SetHeight(20)
    headerButtons:SetWidth(80)
    frame.HeaderButtons = headerButtons

    local closeButton = CreateHeaderButton(headerButtons, 20, "×", CLOSE)
    closeButton:SetPoint("RIGHT")
    StyleHeaderButton(closeButton, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor)
    frame.CloseButton = closeButton

    local minimizeTooltip = options.ribbon == false and "Roll up / expand" or "Collapse to ribbon"
    local minimizeButton = CreateHeaderButton(headerButtons, 20, "—", minimizeTooltip)
    minimizeButton:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
    StyleHeaderButton(minimizeButton, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor)
    frame.MinimizeButton = minimizeButton

    local statusBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    statusBar:SetPoint("BOTTOMLEFT", 1, 1)
    statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
    statusBar:SetHeight(24)
    T.Themes:ApplyPanel(statusBar, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor, false)
    frame.StatusBar = statusBar

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", 10, 0)
    statusText:SetPoint("RIGHT", -10, 0)
    statusText:SetJustifyH("LEFT")
    T.Themes:ApplyBodyText(statusText, frame.FabledUIShell.themeName, frame.FabledUIShell.accentColor, true)
    frame.StatusText = statusText

    local content = CreateFrame("Frame", nil, frame)
    -- Reclaim the empty subtitle band when there's no subtitle.
    local contentTop = ((options.subtitle or "") ~= "") and -62 or -44
    content:SetPoint("TOPLEFT", 16, contentTop)
    content:SetPoint("BOTTOMRIGHT", -16, 34)
    frame.Content = content

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(14, 14)
    resize:SetPoint("BOTTOMRIGHT", -4, 4)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        if InCombatLockdown() then
            return
        end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        T.WindowState:Capture(frame, state)
    end)
    frame.ResizeButton = resize

    -- The rolled-up frame is 44px tall and that height must NEVER reach the
    -- persisted window size -- restoring a window to 44px draws the whole
    -- content inside the title bar.
    --
    -- OnSizeChanged guarded on _rolledUp, but it was the only caller that did.
    -- CaptureWindowState is also reached from OnDragStop (moving the minimised
    -- bar) and HideShell (closing while minimised), and both wrote height=44.
    -- The guard belongs in here, where no future call site can forget it.
    local function CaptureWindowState()
        T.WindowState:Capture(frame, state)
        if frame._rolledUp then
            state.height = math.max(frame._preRollupHeight or minHeight, minHeight)
        end
        if type(options.onBoundsChanged) == "function" then
            options.onBoundsChanged(frame, state)
        end
    end

    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then
            return
        end
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        CaptureWindowState()
    end)

    frame:SetScript("OnSizeChanged", function(self, width, height)
        -- While rolled up to the title bar, ignore the transient height so it is
        -- never captured/persisted as the real window size.
        if self._rolledUp then return end
        if width and height and width > 0 and height > 0 then
            CaptureWindowState()
        end
        if type(options.onSizeChanged) == "function" then
            options.onSizeChanged(self, width, height)
        end
    end)

    function frame:SetShellTitle(text)
        self.TitleText:SetText(BrandTitle(self.FabledUIShell and self.FabledUIShell.themeName, text or ""))
        self.FabledUIShell.titleText = text or ""
        if self.RibbonFrame then
            self.RibbonFrame:SetLabelText(text or "")
        end
    end

    function frame:SetShellSubtitle(text)
        self.SubtitleText:SetText(text or "")
        self.SubtitleText:SetShown((text or "") ~= "")
    end

    function frame:SetShellStatus(text)
        self.StatusText:SetText(text or "")
        if self.RibbonFrame then
            self.RibbonFrame:SetDetailText(text or "")
        end
    end

    function frame:IsShellVisible()
        return self:IsShown() or (self.RibbonFrame and self.RibbonFrame:IsShown()) or false
    end

    function frame:ShowExpanded()
        if self.RibbonFrame then
            self.RibbonFrame:Hide()
        end
        -- Never reopen stuck in the rolled-up state. ShowExpanded means the
        -- caller explicitly wants the window open, so this also clears the
        -- persisted rollup -- otherwise the next load would re-minimise it.
        self:SetRolledUp(false)
        state.rolledUp = false
        T.WindowState:Apply(self, state)
        self:Show()
        T.WindowState:SetDisplayState(state, "expanded")
        if type(options.onDisplayStateChanged) == "function" then
            options.onDisplayStateChanged(self, "expanded")
        end
    end

    -- Show the window the way the user left it. ShowExpanded always expands,
    -- which is right for a click but wrong for a reload: minimising and then
    -- reloading brought the window back full size. Load paths call this.
    function frame:ShowPersisted()
        if state.rolledUp then
            T.WindowState:Apply(self, state)
            self:Show()
            self:SetRolledUp(true)
            T.WindowState:SetDisplayState(state, "expanded")
            return
        end
        self:ShowExpanded()
    end

    function frame:ShowRibbon()
        if not self.RibbonFrame then
            -- Ribbon disabled for this window: fall back to hiding the shell so the
            -- minimize button still does something visible to the user.
            self:HideShell()
            return
        end
        CaptureWindowState()
        self:Hide()
        T.WindowState:ApplyRibbon(self.RibbonFrame, state)
        self.RibbonFrame:Show()
        T.WindowState:SetDisplayState(state, "ribbon")
        if type(options.onDisplayStateChanged) == "function" then
            options.onDisplayStateChanged(self, "ribbon")
        end
    end

    function frame:HideShell()
        CaptureWindowState()
        self:Hide()
        if self.RibbonFrame then
            self.RibbonFrame:Hide()
        end
        T.WindowState:SetDisplayState(state, "hidden")
        if type(options.onDisplayStateChanged) == "function" then
            options.onDisplayStateChanged(self, "hidden")
        end
        if type(options.onHide) == "function" then
            options.onHide(self)
        end
    end

    function frame:ToggleShell(forceShow)
        if forceShow then
            self:ShowExpanded()
            return
        end

        if self:IsShellVisible() then
            self:HideShell()
        else
            self:ShowExpanded()
        end
    end

    -- Roll the window up to just its title bar and back. Used for windows with no
    -- ribbon, where minimize would otherwise hide the whole thing. _rolledUp is
    -- set before SetHeight so OnSizeChanged skips persisting the collapsed height.
    -- Put the window into (or out of) the rolled-up state. Split out of
    -- ToggleRollup so the same code can restore the state on load: rollup used
    -- to live only in the runtime `_rolledUp` field, so a /reload or loading
    -- screen brought the window back expanded.
    function frame:SetRolledUp(rolled)
        if rolled then
            if self._rolledUp then return end
            self._preRollupHeight = self:GetHeight()
            self._rolledUp = true
            if self.Content then self.Content:Hide() end
            if self.StatusBar then self.StatusBar:Hide() end
            if self.ResizeButton then self.ResizeButton:Hide() end
            if self.SetResizeBounds then
                self:SetResizeBounds(minWidth, 44, maxWidth, maxHeight)
            end
            self:SetHeight(44)
            state.rolledUp = true
            state.preRollupHeight = self._preRollupHeight
        else
            if not self._rolledUp then return end
            -- Order matters. OnSizeChanged skips persisting the window size
            -- while _rolledUp is set, and BOTH calls below fire it. Clearing the
            -- flag first therefore let the rolled-up height be captured as the
            -- window's real size, so the window reopened squashed against its
            -- minimum with the content drawn over the header. Restore the
            -- geometry while still guarded, and clear the flag last.
            if self.SetResizeBounds then
                self:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
            end
            self:SetHeight(self._preRollupHeight or minHeight)
            if self.Content then self.Content:Show() end
            if self.StatusBar then self.StatusBar:Show() end
            if self.ResizeButton then self.ResizeButton:Show() end
            self._rolledUp = false
            state.rolledUp = false
        end
        if type(options.onDisplayStateChanged) == "function" then
            options.onDisplayStateChanged(self, rolled and "rolledup" or "expanded")
        end
    end

    -- Roll the window up to just its title bar and back. Used for windows with no
    -- ribbon, where minimize would otherwise hide the whole thing.
    function frame:ToggleRollup()
        self:SetRolledUp(not self._rolledUp)
    end

    function frame:IsRolledUp()
        return self._rolledUp == true
    end

    closeButton:SetScript("OnClick", function()
        frame:HideShell()
    end)

    minimizeButton:SetScript("OnClick", function()
        if frame.RibbonFrame then
            frame:ShowRibbon()
        else
            frame:ToggleRollup()
        end
    end)

    if options.ribbon ~= false then
        T.Ribbon:Attach(frame, {
            label = options.ribbonLabel or options.title or "Window",
            icon = options.ribbonIcon,
        })
    end

    T.WindowState:Apply(frame, state)
    frame:Hide()

    local displayState = T.WindowState:GetDisplayState(state)
    if displayState == "ribbon" and frame.RibbonFrame then
        T.WindowState:ApplyRibbon(frame.RibbonFrame, state)
        frame.RibbonFrame:Show()
        frame:Hide()
    else
        if frame.RibbonFrame then
            frame.RibbonFrame:Hide()
        end
        frame:Hide()
    end

    return frame
end
