local T = FabledUI_UIToolkit
T.Ribbon = T.Ribbon or {}

local Ribbon = T.Ribbon

local function CreateFlatFrame(parent)
    return CreateFrame("Frame", nil, parent, "BackdropTemplate")
end

local function ShowContextMenu(owner, actions)
    if not owner then return end

    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, rootDescription)
            rootDescription:CreateTitle(actions.title or "Window")
            rootDescription:CreateDivider()

            if actions.onOpen then
                rootDescription:CreateButton("Open", actions.onOpen)
            end
            if actions.onHide then
                rootDescription:CreateButton("Hide", actions.onHide)
            end
            if actions.onReset then
                rootDescription:CreateButton("Reset Position", actions.onReset)
            end
        end)
        if ok then return end
    end

    -- Fallback: no MenuUtil available. Default action is "Open" on right-click.
    if actions.onOpen then
        actions.onOpen()
    end
end

function Ribbon:Attach(window, options)
    if not window or window.RibbonFrame then
        return window and window.RibbonFrame or nil
    end

    local shell = window.FabledUIShell
    local state = shell and shell.state
    local themeName = shell and shell.themeName or "Dark"
    local accentColor = shell and shell.accentColor or nil
    local theme = T.Themes:Resolve(themeName, accentColor)

    local ribbon = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    ribbon:SetFrameStrata("MEDIUM")
    ribbon:SetClampedToScreen(true)
    ribbon:SetMovable(true)
    ribbon:EnableMouse(true)
    ribbon:RegisterForDrag("LeftButton")
    ribbon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ribbon:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    ribbon:SetBackdropColor(unpack(theme.surfaceRaised))
    ribbon:SetBackdropBorderColor(unpack(theme.borderStrong))

    local accent = ribbon:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(unpack(theme.accent))
    ribbon.Accent = accent

    local icon = ribbon:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 8, 0)
    icon:SetSize(14, 14)
    if options and options.icon then
        icon:SetTexture(options.icon)
    else
        icon:SetTexture(134400)
    end
    ribbon.Icon = icon

    local label = ribbon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(unpack(theme.titleText))
    label:SetText((options and options.label) or (shell and shell.titleText) or "Window")
    ribbon.Label = label

    local detail = ribbon:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detail:SetPoint("LEFT", label, "RIGHT", 8, 0)
    detail:SetPoint("RIGHT", -28, 0)
    detail:SetJustifyH("LEFT")
    detail:SetTextColor(unpack(theme.textMuted))
    ribbon.Detail = detail

    local chevron = ribbon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chevron:SetPoint("RIGHT", -8, 0)
    chevron:SetTextColor(unpack(theme.accent))
    chevron:SetText("▴")
    ribbon.Chevron = chevron

    T.WindowState:ApplyRibbon(ribbon, state)

    ribbon:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then
            return
        end
        self:StartMoving()
    end)

    ribbon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        T.WindowState:CaptureRibbon(self, state)
    end)

    ribbon:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(theme.buttonHover))
    end)

    ribbon:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(theme.surfaceRaised))
    end)

    ribbon:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowContextMenu(self, {
                title = label:GetText(),
                onOpen = function()
                    if window.ShowExpanded then
                        window:ShowExpanded()
                    end
                end,
                onHide = function()
                    if window.HideShell then
                        window:HideShell()
                    end
                end,
                onReset = function()
                    if state then
                        state.ribbonPoint = "TOP"
                        state.ribbonRelativePoint = "TOP"
                        state.ribbonX = 0
                        state.ribbonY = -160
                        T.WindowState:ApplyRibbon(self, state)
                    end
                end,
            })
            return
        end

        if window.ShowExpanded then
            window:ShowExpanded()
        end
    end)

    function ribbon:SetLabelText(text)
        label:SetText(text or "Window")
    end

    function ribbon:SetDetailText(text)
        detail:SetText(text or "")
    end

    window.RibbonFrame = ribbon
    return ribbon
end
