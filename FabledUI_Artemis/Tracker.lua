local A = FabledUI_Artemis or Artemis
local U = A.Util

A.Tracker = A.Tracker or {}
local T = A.Tracker

-- Suite-aligned palette: cyan primary (matches the FableNeon chrome) instead of
-- the old disconnected gold. Section headers each get their own spectrum colour
-- so the tracker reads as "rainbow with flair", not a wall of yellow.
local ARTEMIS_ACCENT = { 0.227, 0.914, 1.0, 1.0 }
local ACCENT_HEX = "3ae9ff"
local SECTION_HEX = {
    FOCUS        = "b45cff", -- arcane purple (the star of the show)
    EXPIRING     = "ff6b9d", -- hot pink (urgency)
    CAMPAIGN     = "5aa9ff", -- azure
    CURRENT_ZONE = "58d3a6", -- green
    WORLD        = "3ae9ff", -- cyan
    DAILY        = "ffb454", -- amber
    WEEKLY       = "a67bff", -- violet
    MONTHLY      = "3ad0c0", -- teal
    QUESTS       = "6ea8ff", -- periwinkle
    BONUS        = "ff8fd0", -- pink
    CHECKLIST    = "6fe0a0", -- mint
    RECIPES      = "e08c5a", -- copper (professions)
    ENDEAVORS    = "9ad46a", -- moss (housing/neighborhood)
    ACTIVITIES   = "d9a441", -- amber (Traveler's Log)
    ACHIEVEMENTS = "ffd35a", -- gold (one deliberate gold accent)
    CURRENCIES   = "3ae9ff", -- cyan
}
-- Dynamic "By Zone" sections rotate through the spectrum (keyed on mapID so a
-- given zone keeps a stable colour) instead of all reading as one cyan block.
local ZONE_PALETTE = { "3ae9ff", "b45cff", "5cf0a0", "ffb454", "5aa9ff", "ff6b9d", "3ad0c0", "a67bff" }

-- Font sizing. Every row font is a Blizzard font object ("GameFontHighlightSmall"
-- and friends), which is fixed at 10pt and read as slightly too small in the
-- tracker at normal UI scale. Rather than fork a dozen custom font objects,
-- apply the object first (so colour and outline stay Blizzard-consistent) then
-- nudge the point size by profile.fontDelta. Delta 0 is exactly the old
-- behaviour, so this cannot regress anyone who sets it back.
-- Base metrics come from the GLOBAL font object, never from the fontstring.
--
-- SetFontObject does not clear a font previously set with SetFont -- the
-- explicit font keeps winning -- so reading size back off the fontstring
-- returns the size this function set last time, not the Blizzard base. Adding
-- delta to that compounds: every refresh grew the text by another point, and
-- resizing the window fires a refresh per frame, so dragging the edge inflated
-- the tracker to headline type in about a second. Reading the immutable font
-- object instead makes this idempotent however often it runs.
local BASE_FONT = {}

local function BaseFont(objectName)
    local cached = BASE_FONT[objectName]
    if cached then
        return cached[1], cached[2], cached[3]
    end

    local object = rawget(_G, objectName)
    if type(object) ~= "table" and type(object) ~= "userdata" then
        return nil
    end
    if type(object.GetFont) ~= "function" then
        return nil
    end

    local ok, path, size, flags = pcall(object.GetFont, object)
    -- GetFont returns nil on a font object that has not resolved yet (cold
    -- login, a font file still loading). Do not cache that -- leave the object
    -- font in place and try again on the next pass.
    if not ok or not path or not size then
        return nil
    end

    BASE_FONT[objectName] = { path, size, flags }
    return path, size, flags
end

local function ApplyLineFont(fontString, objectName)
    if not fontString then
        return
    end
    fontString:SetFontObject(objectName)

    local delta = A.profile and tonumber(A.profile.fontDelta) or 0
    if not delta or delta == 0 then
        return
    end

    local path, size, flags = BaseFont(objectName)
    if not path then
        return
    end
    pcall(fontString.SetFont, fontString, path, math.max(6, size + delta), flags)
end

-- Exposed for tests/font_sizing.lua. The compounding bug this guards against
-- is invisible on a single call and only shows after several refreshes, so it
-- needs a test that can call it repeatedly.
T._ApplyLineFont = ApplyLineFont
T._BaseFontCache = BASE_FONT

local function HexForSection(sectionKey)
    local fixed = SECTION_HEX[sectionKey]
    if fixed then return fixed end
    local zid = tostring(sectionKey):match("^ZONE_(%d+)$")
    if zid then
        return ZONE_PALETTE[(tonumber(zid) % #ZONE_PALETTE) + 1]
    end
    -- Category/zone groups (GROUP_<name>): hash the name into the palette so each
    -- header gets a stable, varied colour instead of all sharing the accent.
    local gname = tostring(sectionKey):match("^GROUP_(.+)$")
    if gname then
        local sum = 0
        for i = 1, #gname do
            sum = sum + gname:byte(i)
        end
        return ZONE_PALETTE[(sum % #ZONE_PALETTE) + 1]
    end
    return ACCENT_HEX
end

local function GetToolkit()
    return rawget(_G, "FabledUI_UIToolkit")
end

local function HasToolkitShell()
    local toolkit = GetToolkit()
    return type(toolkit) == "table" and type(toolkit.Shell) == "table" and type(toolkit.Shell.CreateWindow) == "function"
end

local function GetThemeName()
    -- Suite default is FableNeon; upgrade legacy "Dark" profiles to it while
    -- still respecting an explicit Classic/Transparent choice.
    local t = A.profile and A.profile.theme
    if not t or t == "Dark" then return "FableNeon" end
    return t
end

local function GetWindowState()
    A.db.window = A.db.window or {
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -350,
        y = -260,
        width = 340,
        height = 620,
        scale = 1,
        alpha = 1,
        displayState = "expanded",
        -- AR-004: persisted tracker visibility (default shown so first-run users see it).
        shown = true,
        ribbonPoint = "TOP",
        ribbonRelativePoint = "TOP",
        ribbonX = 0,
        ribbonY = -160,
        ribbonWidth = 280,
        ribbonHeight = 24,
    }
    if A.db.window.shown == nil then
        A.db.window.shown = true
    end
    return A.db.window
end

local function ApplyFallbackTheme(frame)
    if not frame._fallbackBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame._fallbackBackdrop = true
    end
    frame:SetBackdropColor(0.05, 0.05, 0.07, 0.94)
end

local function StyleButton(button)
    local toolkit = GetToolkit()
    if toolkit and toolkit.Themes and type(toolkit.Themes.StyleFlatButton) == "function" then
        toolkit.Themes:StyleFlatButton(button, GetThemeName(), ARTEMIS_ACCENT)
    end
end

function T:IsShellVisible()
    if not self.frame then
        return false
    end
    if self.frame.IsShellVisible then
        return self.frame:IsShellVisible()
    end
    return self.frame:IsShown()
end

function T:IsExpandedVisible()
    if not self.frame then
        return false
    end
    return self.frame:IsShown()
end

function T:ManageDefaultTracker()
    if InCombatLockdown() then
        self.pendingTrackerToggle = true
        return
    end

    self.pendingTrackerToggle = false
    if not ObjectiveTrackerFrame then
        return
    end

    -- AR-004: honour "Hide Blizzard Tracker" whenever the preference is enabled,
    -- not just while our shell is visible. Previously, after /reload the
    -- Blizzard tracker would be re-parented to UIParent until the user opened
    -- Artemis, which made the setting feel broken.
    if A.profile.hideDefaultTracker then
        if ObjectiveTrackerFrame:GetParent() ~= A.hiddenFrame then
            ObjectiveTrackerFrame:SetParent(A.hiddenFrame)
        end
    else
        if ObjectiveTrackerFrame:GetParent() == A.hiddenFrame then
            ObjectiveTrackerFrame:SetParent(UIParent)
        end
    end
end

function T:CreateHeaderButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    StyleButton(button)
    return button
end

-- Compact 24px icon button for the mode/config toolbar row. Hover shows a
-- tooltip (title + description). Toggle buttons call :SetActive(bool) to light
-- up in the accent colour so the active state reads at a glance.
function T:CreateIconButton(parent, texture, title, desc, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(28, 28)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.05)

    local glow = button:CreateTexture(nil, "BORDER")
    glow:SetPoint("TOPLEFT", -1, 1)
    glow:SetPoint("BOTTOMRIGHT", 1, -1)
    glow:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.30)
    glow:Hide()
    button.glow = glow

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(texture)
    -- Near-native colour with a faint cool cast. We intentionally do NOT tint
    -- toward the accent here: vertex colour multiplies the texture, which turns
    -- colourful icons muddy. The accent shows through the glow/hover instead.
    icon:SetVertexColor(0.92, 0.95, 1.0)
    button.icon = icon

    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.20)

    button.tooltipTitle = title
    button.tooltipDesc = desc
    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        GameTooltip:SetText(selfBtn.tooltipTitle or "")
        if selfBtn.tooltipDesc then
            GameTooltip:AddLine(selfBtn.tooltipDesc, 0.8, 0.85, 1, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if onClick then
        button:SetScript("OnClick", onClick)
    end

    function button:SetActive(active)
        self._active = active and true or false
        if self._active then
            self.glow:Show()
            self.icon:SetVertexColor(1, 1, 1)          -- full-bright when on
        else
            self.glow:Hide()
            self.icon:SetVertexColor(0.68, 0.72, 0.82) -- dimmed when off
        end
    end

    return button
end

-- Flat segmented filter tab. Active tab gets an accent underline + fill + bright
-- text; inactive tabs are dim. State is driven centrally by T:UpdateFilterTabs.
-- `iconTexture` makes an icon tab instead of a text one. Everything else --
-- underline, active fill, hover -- stays identical so the row reads as one
-- control group rather than a text strip with a button bolted on the end.
function T:CreateFilterTab(parent, label, width, mode, onClick, iconTexture)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(width, 22)
    tab._mode = mode

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    tab.bg = bg

    local underline = tab:CreateTexture(nil, "ARTWORK")
    underline:SetPoint("BOTTOMLEFT", 2, 0)
    underline:SetPoint("BOTTOMRIGHT", -2, 0)
    underline:SetHeight(2)
    underline:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 1)
    underline:Hide()
    tab.underline = underline

    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(label or "")
    tab.text = text

    if iconTexture then
        text:Hide()
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER", 0, 0)
        icon:SetSize(14, 14)
        icon:SetTexture(iconTexture)
        -- Trim the icon border so it reads as a glyph next to the text tabs
        -- rather than a framed inventory icon.
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.icon = icon
    end

    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.15)

    tab:SetScript("OnClick", onClick)

    -- An icon tab carries no label, so it needs a tooltip to be discoverable
    -- at all. Text tabs are self-describing and keep the hover area clean.
    if iconTexture then
        tab:SetScript("OnEnter", function(selfTab)
            GameTooltip:SetOwner(selfTab, "ANCHOR_TOP")
            GameTooltip:SetText(selfTab.tooltipTitle or "")
            if selfTab.tooltipText then
                GameTooltip:AddLine(selfTab.tooltipText, 0.8, 0.85, 1, true)
            end
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    function tab:SetActive(active)
        if active then
            self.underline:Show()
            self.bg:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.16)
            self.text:SetTextColor(1, 1, 1)
            -- An icon tab has no text to brighten, so carry the same state on
            -- the icon: full colour when active, dimmed when not.
            if self.icon then self.icon:SetVertexColor(1, 1, 1) end
        else
            self.underline:Hide()
            self.bg:SetColorTexture(1, 1, 1, 0.04)
            self.text:SetTextColor(0.68, 0.70, 0.80)
            if self.icon then self.icon:SetVertexColor(0.68, 0.70, 0.80) end
        end
    end
    tab:SetActive(false)
    return tab
end

-- Light the tab that matches the current filter mode.
function T:UpdateFilterTabs()
    if not self.filterTabs then return end
    local mode = A.profile.filterMode or "ALL"
    for _, tab in ipairs(self.filterTabs) do
        tab:SetActive(tab._mode == mode)
    end
end

function T:CreateShellFrame()
    local state = GetWindowState()
    local toolkit = GetToolkit()
    local frame = toolkit.Shell:CreateWindow("FabledUI_ArtemisTracker", {
        title = "FabledUI - Artemis",
        subtitle = "",
        theme = GetThemeName(),
        accentColor = ARTEMIS_ACCENT,
        width = state.width,
        height = state.height,
        minWidth = 260,
        minHeight = 380,
        maxWidth = 760,
        -- Allow the tracker to grow to the full screen height (clamped on-screen
        -- by the Shell) instead of the old fixed 900px ceiling (~75% of a screen).
        maxHeight = math.max(900, math.floor((UIParent and UIParent:GetHeight()) or 1200)),
        state = state,
        ribbon = false,
        ribbonLabel = "Artemis",
        ribbonIcon = 134400,
        onSizeChanged = function()
            if self.content then
                C_Timer.After(0, function()
                    if self.content then
                        self:UpdateContentWidth()
                        self:Refresh(true)
                    end
                end)
            end
        end,
        onDisplayStateChanged = function()
            self:ManageDefaultTracker()
            if self:IsExpandedVisible() then
                self:Refresh(true)
            end
        end,
        onHide = function()
            self:ManageDefaultTracker()
        end,
    })
    return frame
end

function T:CreateFallbackFrame()
    local frame = CreateFrame("Frame", "FabledUI_ArtemisTracker", UIParent, "BackdropTemplate")
    frame:SetSize(A.profile.width or 340, A.profile.height or 620)
    frame:SetPoint(A.profile.anchor or "TOPRIGHT", UIParent, A.profile.anchor or "TOPRIGHT", A.profile.x or -350, A.profile.y or -260)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")

    if frame.SetResizeBounds then
        frame:SetResizeBounds(260, 380)
    else
        frame:SetMinResize(260, 380)
    end

    frame:SetScript("OnDragStart", function()
        if not A.profile.locked then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        local state = GetWindowState()
        state.point, state.relativePoint, state.x, state.y = point, relativePoint, x, y
        A.profile.anchor, A.profile.x, A.profile.y = point, x, y
    end)

    ApplyFallbackTheme(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOPLEFT", 12, -10)
    frame.title:SetText("|cff3ae9ffArtemis|r")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.subtitle:SetText("")

    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", -6, -6)

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.status:SetPoint("BOTTOMLEFT", 12, 10)
    frame.status:SetPoint("BOTTOMRIGHT", -12, 10)
    frame.status:SetJustifyH("LEFT")

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        if not A.profile.locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        local width, height = frame:GetSize()
        local state = GetWindowState()
        state.point, state.relativePoint, state.x, state.y = point, relativePoint, x, y
        state.width, state.height = width, height
        A.profile.anchor, A.profile.x, A.profile.y = point, x, y
        A.profile.width, A.profile.height = width, height
        self:UpdateContentWidth()
        self:Refresh(true)
    end)

    return frame
end

function T:UpdateContentWidth()
    if not self.content then
        return
    end

    local width
    if self.scrollFrame and self.scrollFrame.GetWidth then
        width = math.max(1, self.scrollFrame:GetWidth() - 20)
    elseif self.frame and self.frame.Content and self.frame.Content.GetWidth then
        width = math.max(1, self.frame.Content:GetWidth() - 28)
    elseif self.frame and self.frame.GetWidth then
        width = math.max(1, self.frame:GetWidth() - 48)
    end

    if width then
        self.content:SetWidth(width)
    end
    self:LayoutToolbars()
end

-- Flow the two toolbar rows into as many lines as the current width needs so
-- the window can shrink well below the old single-row button footprint.
function T:LayoutToolbars()
    local function flow(buttons, container)
        if not container then return 24 end
        local avail = container:GetWidth()
        if not avail or avail < 1 then
            return container:GetHeight() or 24
        end
        local gap, x, rowY, rowH = 4, 0, 0, 0
        for _, b in ipairs(buttons) do
            if b then
                local w = b:GetWidth() or 60
                if x > 0 and (x + w) > avail then
                    x = 0
                    rowY = rowY - (rowH + 4)
                    rowH = 0
                end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", container, "TOPLEFT", x, rowY)
                x = x + w + gap
                local bh = b:GetHeight() or 22
                if bh > rowH then rowH = bh end
            end
        end
        return (-rowY) + rowH
    end

    if self.toolbar1 then
        self.toolbar1:SetHeight(flow(self.toolbar1Buttons or {}, self.toolbar1))
    end
    if self.toolbar2 then
        self.toolbar2:SetHeight(flow(self.toolbar2Buttons or {}, self.toolbar2))
    end
end

-- Recover from an over-large / off-screen window: snap back to the compact
-- default size and the default TOPRIGHT position. Wired to /artemis reset.
function T:ResetWindow()
    local state = GetWindowState()
    state.point, state.relativePoint, state.x, state.y = "TOPRIGHT", "TOPRIGHT", -350, -260
    state.width, state.height = 340, 620
    A.profile.anchor, A.profile.x, A.profile.y = "TOPRIGHT", -350, -260
    A.profile.width, A.profile.height = 340, 620
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -350, -260)
        self.frame:SetSize(340, 620)
        self:UpdateContentWidth()
        if self:IsExpandedVisible() then
            self:Refresh(true)
        end
    end
    if A.Print then A:Print("Tracker reset to default size and position.") end
end

-- Snap the tracker to the left or right edge, at the top of the screen so there's
-- full vertical room to resize downward.
function T:AnchorToSide(side)
    side = (side == "LEFT") and "LEFT" or "RIGHT"
    local point = (side == "LEFT") and "TOPLEFT" or "TOPRIGHT"
    local x = (side == "LEFT") and 20 or -20
    local y = -40
    local state = GetWindowState()
    state.point, state.relativePoint, state.x, state.y = point, point, x, y
    A.profile.anchor, A.profile.x, A.profile.y = point, x, y
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point, UIParent, point, x, y)
        if self:IsExpandedVisible() then
            self:Refresh(true)
        end
    end
    if A.Print then A:Print("Tracker anchored to the " .. side:lower() .. " edge.") end
end

function T:InitUI()
    if self.frame then
        return
    end

    local useToolkit = HasToolkitShell()
    local frame = useToolkit and self:CreateShellFrame() or self:CreateFallbackFrame()
    self.frame = frame
    if frame.HideShell then
        frame:HideShell()
    else
        frame:Hide()
    end

    local shellContent = frame.Content or frame
    self.shellContent = shellContent

    self.summary = shellContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.summary:SetPoint("TOPLEFT", 6, -6)
    self.summary:SetPoint("TOPRIGHT", -6, -6)
    self.summary:SetJustifyH("LEFT")
    self.summary:SetJustifyV("TOP")
    self.summary:SetText("Scanning quests…")

    local toolbar1 = CreateFrame("Frame", nil, shellContent)
    toolbar1:SetPoint("TOPLEFT", self.summary, "BOTTOMLEFT", 0, -8)
    toolbar1:SetPoint("RIGHT", shellContent, "RIGHT", -6, 0)
    toolbar1:SetHeight(24)
    self.toolbar1 = toolbar1

    -- AR-005: add a faint horizontal divider between the filter row and the
    -- mode/config row so the two groups read as distinct clusters.
    local toolbarDivider = shellContent:CreateTexture(nil, "ARTWORK")
    toolbarDivider:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.25)
    toolbarDivider:SetPoint("TOPLEFT", toolbar1, "BOTTOMLEFT", 4, -4)
    toolbarDivider:SetPoint("TOPRIGHT", toolbar1, "BOTTOMRIGHT", -4, -4)
    toolbarDivider:SetHeight(1)
    self.toolbarDivider = toolbarDivider

    local toolbar2 = CreateFrame("Frame", nil, shellContent)
    -- AR-005: increase the gap between toolbars (was -6) so the divider has
    -- breathing room and the filter/mode groups feel separated.
    toolbar2:SetPoint("TOPLEFT", toolbar1, "BOTTOMLEFT", 0, -12)
    toolbar2:SetPoint("RIGHT", shellContent, "RIGHT", -6, 0)
    toolbar2:SetHeight(24)
    self.toolbar2 = toolbar2

    frame.filterAll = self:CreateFilterTab(toolbar1, "All", 44, "ALL", function()
        A.profile.filterMode = "ALL"
        A.profile.showCurrentZoneOnly = false
        self:Refresh(true)
    end)
    frame.filterAll:SetPoint("LEFT", 0, 0)

    frame.filterFocus = self:CreateFilterTab(toolbar1, "Focus", 52, "FOCUS", function()
        A.profile.filterMode = "FOCUS"
        A.profile.showCurrentZoneOnly = false
        self:Refresh(true)
    end)
    frame.filterFocus:SetPoint("LEFT", frame.filterAll, "RIGHT", 4, 0)

    frame.filterWorld = self:CreateFilterTab(toolbar1, "World", 54, "WORLD", function()
        A.profile.filterMode = "WORLD"
        A.profile.showCurrentZoneOnly = false
        self:Refresh(true)
    end)
    frame.filterWorld:SetPoint("LEFT", frame.filterFocus, "RIGHT", 4, 0)

    frame.filterZone = self:CreateFilterTab(toolbar1, "Zone", 48, "ZONE", function()
        A.profile.filterMode = "ZONE"
        A.profile.showCurrentZoneOnly = true
        self:Refresh(true)
    end)
    frame.filterZone:SetPoint("LEFT", frame.filterWorld, "RIGHT", 4, 0)

    frame.filterChecklist = self:CreateFilterTab(toolbar1, "Checklist", 74, "CHECKLIST", function()
        A.profile.filterMode = "CHECKLIST"
        A.profile.showCurrentZoneOnly = false
        A.profile.showChecklist = true
        self:Refresh(true)
    end)
    frame.filterChecklist:SetPoint("LEFT", frame.filterZone, "RIGHT", 4, 0)

    -- Endeavors-only. An icon rather than a sixth word: the row is already
    -- crowded, and a house reads faster than "Endeavors" at this size.
    frame.filterEndeavors = self:CreateFilterTab(toolbar1, nil, 28, "ENDEAVORS", function()
        A.profile.filterMode = "ENDEAVORS"
        A.profile.showCurrentZoneOnly = false
        self:Refresh(true)
    end, "Interface\\Icons\\INV_Misc_House_01")
    frame.filterEndeavors:SetPoint("LEFT", frame.filterChecklist, "RIGHT", 4, 0)
    frame.filterEndeavors.tooltipTitle = "Endeavors Only"
    frame.filterEndeavors.tooltipText = "Show only Neighborhood Initiative tasks."

    self.filterTabs = { frame.filterAll, frame.filterFocus, frame.filterWorld, frame.filterZone, frame.filterChecklist, frame.filterEndeavors }
    self:UpdateFilterTabs()

    -- AR: mode/config row is now a compact icon strip (hover for the label).
    -- Toggle icons (Solo Focus, By Zone) glow in the accent colour when active.
    frame.filterMenuButton = self:CreateIconButton(toolbar2,
        "Interface\\Icons\\INV_Misc_Spyglass_02",
        "World Quest Filters",
        "Filter world quests by reward type, faction, and more.",
        function(selfButton)
            if not (A.Menus and A.Menus:OpenWorldQuestFilterMenu(selfButton)) then
                A:Print("Blizzard_Menu is unavailable; advanced WQ filters could not open.")
            end
        end)
    frame.filterMenuButton:SetPoint("LEFT", 0, 0)

    frame.presetButton = self:CreateIconButton(toolbar2,
        "Interface\\Icons\\INV_Misc_Book_09",
        "Tracking Preset",
        "Switch which quest types the tracker shows.",
        function(selfButton)
            if not (A.Menus and A.Menus:OpenPresetMenu(selfButton)) then
                local keys = A.DataModel:GetPresetKeys()
                local current = A.profile.activePreset or "STANDARD"
                local index = 1
                for i, key in ipairs(keys) do
                    if key == current then
                        index = i
                        break
                    end
                end
                A:SetActivePreset(keys[(index % #keys) + 1])
            end
        end)
    frame.presetButton:SetPoint("LEFT", frame.filterMenuButton, "RIGHT", 4, 0)

    frame.odysseyButton = self:CreateIconButton(toolbar2,
        "Interface\\Icons\\Ability_Hunter_Pathfinding",
        "Route Mode",
        "Choose how quests are sent to Odyssey routing (Append / Replace).",
        function(selfButton)
            if not (A.Menus and A.Menus:OpenOdysseyModeMenu(selfButton)) then
                local keys = A.DataModel:GetOdysseyRouteModeKeys()
                local current = A.profile.odysseyRouteMode or "APPEND"
                local index = 1
                for i, key in ipairs(keys) do
                    if key == current then
                        index = i
                        break
                    end
                end
                A.profile.odysseyRouteMode = keys[(index % #keys) + 1]
                self:Refresh(true)
            end
        end)
    frame.odysseyButton:SetPoint("LEFT", frame.presetButton, "RIGHT", 4, 0)

    frame.checklistButton = self:CreateIconButton(toolbar2,
        "Interface\\Icons\\INV_Misc_Book_17",
        "Checklist Rules",
        "Choose which checklist templates are active.",
        function(selfButton)
            if not (A.Menus and A.Menus:OpenChecklistTemplateMenu(selfButton)) then
                A.profile.showChecklist = not A.profile.showChecklist
                self:Refresh(true)
            end
        end)
    frame.checklistButton:SetPoint("LEFT", frame.odysseyButton, "RIGHT", 12, 0)

    -- AR-A3: Solo Focus toggle. When active, only the focused quest renders;
    -- everything else is suppressed (not just dimmed). State persists per
    -- character so different alts can have different focus styles.
    frame.soloFocusButton = self:CreateIconButton(toolbar2,
        "Interface\\Icons\\Ability_Hunter_SniperShot",
        "Solo Focus",
        "Show only your focused quest and hide everything else. Click to toggle.",
        function(selfButton)
            local nextValue = not A:IsSoloFocusActive()
            A:SetSoloFocusActive(nextValue)
            selfButton:SetActive(nextValue)
        end)
    frame.soloFocusButton:SetPoint("LEFT", frame.checklistButton, "RIGHT", 4, 0)
    frame.soloFocusButton:SetActive(A:IsSoloFocusActive())

    -- Group the tracker into per-zone sections (current zone first) instead of by
    -- quest type. The glow marks the toggle active.
    frame.byZoneButton = self:CreateIconButton(toolbar2,
        "Interface\\Icons\\INV_Misc_Map02",
        "Group by Zone / Category",
        "Group quests under the quest log's own headers (zones + Dungeon / Raid / Weekly Event / Neighborhood). Click to toggle.",
        function(selfButton)
            A.profile.groupByZone = not A.profile.groupByZone
            selfButton:SetActive(A.profile.groupByZone)
            self:Refresh(true)
        end)
    frame.byZoneButton:SetPoint("LEFT", frame.soloFocusButton, "RIGHT", 4, 0)
    frame.byZoneButton:SetActive(A.profile.groupByZone)

    frame.settingsButton = self:CreateIconButton(toolbar2,
        "Interface\\Buttons\\UI-OptionsButton",
        "Settings",
        "Open Artemis settings.",
        function()
            if A.Settings and A.Settings.Open then
                A.Settings:Open()
            end
        end)
    frame.settingsButton:SetPoint("LEFT", frame.byZoneButton, "RIGHT", 4, 0)

    -- AR: button rosters for the wrapping toolbar layout. LayoutToolbars() flows
    -- these into as many rows as the current window width needs, so the tracker
    -- can shrink to ~260px (Blizzard-tracker width) instead of the old 560 floor.
    self.toolbar1Buttons = { frame.filterAll, frame.filterFocus, frame.filterWorld, frame.filterZone, frame.filterChecklist }
    self.toolbar2Buttons = { frame.filterMenuButton, frame.presetButton, frame.odysseyButton, frame.checklistButton, frame.soloFocusButton, frame.byZoneButton, frame.settingsButton }

    local scrollParent = shellContent
    local scrollFrame = CreateFrame("ScrollFrame", nil, scrollParent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", toolbar2, "BOTTOMLEFT", 0, -10)
    -- Reserve only a thin gutter on the right for our slim custom scrollbar
    -- (was -30 for the chunky default bar).
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollParent, "BOTTOMRIGHT", -10, 4)
    self.scrollFrame = scrollFrame

    -- Hide the default UIPanelScrollFrameTemplate scrollbar (wide track + arrow
    -- buttons). We drive scrolling with the mouse wheel and a slim custom thumb.
    local defaultBar = scrollFrame.ScrollBar or (scrollFrame:GetName() and _G[scrollFrame:GetName() .. "ScrollBar"])
    if defaultBar then
        defaultBar:SetAlpha(0)
        defaultBar:EnableMouse(false)
        defaultBar.Show = defaultBar.Hide -- stop the template from re-showing it
        defaultBar:Hide()
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    self.content = content

    -- Slim custom scrollbar: a 4px track on the window's right edge with a
    -- draggable accent thumb (~1/8 the width of the old bar). T:UpdateScrollThumb
    -- keeps size + position in sync, and hides the whole thing when nothing scrolls.
    local track = CreateFrame("Frame", nil, scrollParent)
    track:SetPoint("TOP", scrollFrame, "TOP", 0, 0)
    track:SetPoint("BOTTOM", scrollFrame, "BOTTOM", 0, 0)
    track:SetPoint("RIGHT", scrollParent, "RIGHT", -3, 0)
    track:SetWidth(4)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints()
    trackTex:SetColorTexture(1, 1, 1, 0.05)
    self.scrollTrack = track

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    thumb:SetHeight(40)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.55)
    thumb:SetScript("OnEnter", function() thumbTex:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.9) end)
    thumb:SetScript("OnLeave", function() thumbTex:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.55) end)
    self.scrollThumb = thumb

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
        local viewH = sf:GetHeight() or 1
        local contentH = (self.content and self.content:GetHeight()) or 1
        local maxScroll = math.max(0, contentH - viewH)
        local newVal = math.min(maxScroll, math.max(0, (sf:GetVerticalScroll() or 0) - delta * 42))
        sf:SetVerticalScroll(newVal)
        self:UpdateScrollThumb()
    end)

    -- Drag the thumb: track the cursor's frame-to-frame delta and scroll by the
    -- same proportion of the content (delta-based = no fragile absolute math).
    thumb:SetScript("OnMouseDown", function(selfThumb)
        selfThumb._dragging = true
        local _, cy = GetCursorPosition()
        selfThumb._lastY = cy
    end)
    thumb:SetScript("OnMouseUp", function(selfThumb) selfThumb._dragging = false end)
    thumb:SetScript("OnUpdate", function(selfThumb)
        if not selfThumb._dragging then return end
        if not IsMouseButtonDown("LeftButton") then
            selfThumb._dragging = false -- released off-thumb; stop dragging
            return
        end
        local sf = self.scrollFrame
        if not sf then return end
        local _, cy = GetCursorPosition()
        local dy = (selfThumb._lastY or cy) - cy
        selfThumb._lastY = cy
        if dy == 0 then return end
        local scale = selfThumb:GetEffectiveScale()
        local trackH = self.scrollTrack:GetHeight() or 1
        local usable = math.max(1, trackH - selfThumb:GetHeight())
        local maxScroll = math.max(0, ((self.content and self.content:GetHeight()) or 1) - (sf:GetHeight() or 1))
        local newVal = math.min(maxScroll, math.max(0, (sf:GetVerticalScroll() or 0) + (dy / scale) / usable * maxScroll))
        sf:SetVerticalScroll(newVal)
        self:UpdateScrollThumb()
    end)

    self:UpdateContentWidth()
    self:UpdateScrollThumb()
end

-- Size + place the slim scroll thumb from the current content/scroll geometry.
function T:UpdateScrollThumb()
    local sf, track, thumb = self.scrollFrame, self.scrollTrack, self.scrollThumb
    if not sf or not track or not thumb then return end
    local viewH = sf:GetHeight() or 1
    local contentH = (self.content and self.content:GetHeight()) or 1
    local trackH = track:GetHeight() or 1
    if contentH <= viewH + 1 then
        track:Hide() -- nothing to scroll
        return
    end
    track:Show()
    local maxScroll = contentH - viewH
    local cur = sf:GetVerticalScroll() or 0
    if cur > maxScroll then
        cur = maxScroll
        sf:SetVerticalScroll(cur)
    end
    local thumbH = math.max(20, math.floor(trackH * (viewH / contentH)))
    thumb:SetHeight(thumbH)
    local frac = maxScroll > 0 and math.max(0, math.min(1, cur / maxScroll)) or 0
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, -((trackH - thumbH) * frac))
end

function T:AcquireLine(index, isHeader)
    self.lines = self.lines or {}
    local line = self.lines[index]
    if line then
        -- Rows are pooled and reused across renders, so per-row tooltip state
        -- has to be cleared on acquire. A stale questID here means a header or
        -- a currency row inherits the previous occupant's rewards and ID.
        line.tooltipQuestID = nil
        return line
    end

    line = CreateFrame("Button", nil, self.content)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    line:SetHeight(isHeader and 22 or 20)
    line:SetPoint("LEFT", self.content, "LEFT", 0, 0)
    line:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)

    line.text = line:CreateFontString(nil, "OVERLAY", isHeader and "GameFontNormalSmall" or "GameFontHighlightSmall")
    line.text:SetPoint("LEFT", 8, 0)
    line.text:SetPoint("RIGHT", -52, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)

    line.routeButton = CreateFrame("Button", nil, line)
    line.routeButton:SetSize(18, 18)
    line.routeButton:SetPoint("RIGHT", -24, 0)
    line.routeButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    line.routeButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- Hover-reveal: the route arrow only appears while the row (or the arrow
    -- itself) is hovered, so it no longer forms a persistent "column of arrows".
    line.routeButton:SetScript("OnEnter", function(selfBtn)
        selfBtn:Show()
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Send to Odyssey route")
        GameTooltip:Show()
    end)
    line.routeButton:SetScript("OnLeave", function(selfBtn)
        GameTooltip:Hide()
        if not line:IsMouseOver() then
            selfBtn:Hide()
        end
    end)

    -- Find Group: opens the Premade Group Finder searched for this quest (world
    -- bosses, elite/dungeon/raid world quests). Shown only when the quest is
    -- group-eligible (see RenderQuestLine). Left of the route button.
    line.findGroupButton = CreateFrame("Button", nil, line)
    line.findGroupButton:SetSize(18, 18)
    line.findGroupButton:SetPoint("RIGHT", -46, 0)
    line.findGroupButton:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    line.findGroupButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    line.findGroupButton:Hide()
    line.findGroupButton:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Find Group")
        GameTooltip:AddLine("Search the Premade Group Finder for this quest.", 0.8, 0.85, 1, true)
        GameTooltip:Show()
    end)
    line.findGroupButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- line.itemButton (quest-item indicator) is created lazily by
    -- EnsureItemButton the first time an item needs to show, not here.

    line:SetScript("OnEnter", function(selfLine)
        if selfLine._routeEnabled and selfLine.routeButton then
            selfLine.routeButton:Show()
        end
        if selfLine.tooltipTitle or selfLine.tooltipText then
            GameTooltip:SetOwner(selfLine, "ANCHOR_RIGHT")
            if selfLine.tooltipTitle then
                GameTooltip:SetText(selfLine.tooltipTitle, 1, 0.85, 0)
            end
            if selfLine.tooltipText then
                GameTooltip:AddLine(selfLine.tooltipText, 0.95, 0.95, 0.95, true)
            end

            -- Quest rows get the metadata block: objectives, then Blizzard's
            -- own reward preview, then the quest ID. Kaliel's parity -- its
            -- "Show Rewards" and "Show ID" options are the two toggles below.
            local questID = selfLine.tooltipQuestID
            if questID then
                -- Objectives are fetched here rather than read off the row:
                -- the row only carries them when the quest is expanded, and a
                -- hover should not require expanding first. GetQuestObjectives
                -- is cached, so repeated hovers are cheap.
                if A.profile.tooltipShowObjectives ~= false then
                    local ok, objectives = pcall(A.Util.GetQuestObjectives, A.Util, questID)
                    if ok and type(objectives) == "table" and #objectives > 0 then
                        GameTooltip:AddLine(" ")
                        for _, objective in ipairs(objectives) do
                            if objective.finished then
                                GameTooltip:AddLine("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. (objective.text or ""), 0.35, 0.85, 0.55, true)
                            else
                                GameTooltip:AddLine("- " .. (objective.text or ""), 0.95, 0.95, 0.95, true)
                            end
                        end
                    end
                end

                if A.profile.tooltipShowRewards ~= false then
                    local addRewards = rawget(_G, "GameTooltip_AddQuestRewardsToTooltip")
                    if type(addRewards) == "function" then
                        -- Blizzard's own renderer: money, currencies, items and
                        -- their icons, already localized. Reimplementing it
                        -- would drift the moment a reward type is added.
                        pcall(addRewards, GameTooltip, questID)
                    end
                end

                if A.profile.tooltipShowID ~= false then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine(" ", "Quest ID: |cffffffff" .. tostring(questID) .. "|r")
                end
            end

            GameTooltip:Show()
        end
    end)
    line:SetScript("OnLeave", function(selfLine)
        GameTooltip:Hide()
        if selfLine.routeButton and not selfLine.routeButton:IsMouseOver() then
            selfLine.routeButton:Hide()
        end
    end)

    self.lines[index] = line
    return line
end

function T:HideUnusedLines(fromIndex)
    if not self.lines then
        return
    end
    for index = fromIndex, #self.lines do
        self.lines[index]:Hide()
    end
end

-- AR-A1: hide any leftover currency value from a recycled line. Also resets the
-- Find Group button (RenderQuestLine re-shows it when the quest is group-eligible).
local function HideCurrencyValue(line)
    if line.currencyValue then
        line.currencyValue:Hide()
    end
    if line.currencyReset then
        line.currencyReset:Hide()
    end
    if line.findGroupButton then
        line.findGroupButton:Hide()
    end
    if line.progressBar then
        line.progressBar:Hide()
    end
    -- Only quest rows carry a super-track pin; a recycled row must not keep one
    -- on a header, objective or checklist line.
    if line.trackButton then
        line.trackButton:Hide()
    end
    -- Reset hover-reveal state so a recycled row doesn't flash a stale route arrow.
    line._routeEnabled = false
end

-- Quest progress bar for "progressbar" objectives (e.g. "Collect ingredients"
-- 70%). Created lazily; occupies its own band under the row's title.
--
-- This used to be a 3px hairline pinned to the row's bottom edge with the
-- percentage buried in the title text, which was close to invisible next to
-- Blizzard's -- and these are exactly the quests whose only feedback IS the
-- bar. It is now a proper 11px bar with its own dark trough, a border, and the
-- percentage centred inside it.
local PROGRESS_BAR_HEIGHT = 11

local function EnsureProgressBar(line)
    if line.progressBar then
        return line.progressBar
    end
    local bar = CreateFrame("StatusBar", nil, line)
    bar:SetHeight(PROGRESS_BAR_HEIGHT)
    bar:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 8, 2)
    bar:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -8, 2)
    bar:SetMinMaxValues(0, 100)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 1)

    -- Dark trough so an empty bar still reads as a bar. At 0% -- which is what
    -- most of these show most of the time -- the fill alone is nothing at all.
    local trough = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    trough:SetAllPoints()
    trough:SetColorTexture(0, 0, 0, 0.55)

    local border = bar:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.35)

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", bar, "CENTER", 0, 0)
    label:SetTextColor(1, 1, 1, 1)
    if label.SetShadowOffset then
        label:SetShadowOffset(1, -1)
        label:SetShadowColor(0, 0, 0, 1)
    end
    bar.label = label

    line.progressBar = bar
    return bar
end

-- Extra row height a progress-bar quest needs so its bar sits below the title
-- instead of on top of it.
local function ProgressRowHeight(baseHeight)
    return baseHeight + PROGRESS_BAR_HEIGHT + 3
end

-- Super-track toggle, one per row. Insecure and safe to keep as a row child:
-- C_SuperTrack.SetSuperTrackedQuestID is a normal API, not a protected action,
-- so unlike the quest-item button this needs no secure plumbing.
function T:EnsureTrackButton(line)
    if line.trackButton then
        return line.trackButton
    end
    local btn = CreateFrame("Button", nil, line)
    btn:SetSize(14, 14)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    -- Texture and colour are set per row in ApplyQuestIcon: the icon carries
    -- completion state, so it cannot be fixed at construction time.

    -- The icon expands the quest's objectives inline, the way the default
    -- tracker does. Super-tracking moved to the row's right-click menu -- an
    -- icon that navigated on click meant the most obvious target on the row
    -- did the least obvious thing, and every quest looked identical besides.
    btn:SetScript("OnClick", function(selfBtn)
        if not selfBtn._questID then return end
        A:ToggleQuestExpanded(selfBtn._questID)
        T:Refresh(true)
    end)
    btn:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        local expanded = A:IsQuestExpanded(selfBtn._questID)
        GameTooltip:SetText(expanded and "Hide objectives" or "Show objectives")
        if selfBtn._isComplete then
            GameTooltip:AddLine("Ready to turn in.", 1, 0.82, 0, true)
        end
        GameTooltip:AddLine(selfBtn._isTracked
            and "Currently navigated. Right-click the quest to stop."
            or "Right-click the quest to navigate here.", 0.8, 0.85, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    line.trackButton = btn
    return btn
end

-- ── Quest-item buttons (secure) ──────────────────────────────────────────────
--
-- Using a quest item is a protected action: only a SecureActionButton fired by
-- a real hardware click can do it. The catch is that an addon-created secure
-- button becomes protected the moment you enter combat, and Artemis re-lays-out
-- its pooled rows on every quest update -- which fire constantly in combat.
--
-- The first version of this was therefore display-only: an insecure icon with a
-- tooltip and no OnClick, because a secure button parented to a pooled row made
-- PlaceLine throw "Cannot anchor protected frames to regions" mid-combat and
-- took the whole render down with it.
--
-- The fix is to keep the secure buttons OUT of the row hierarchy entirely. They
-- live in a flat pool parented to a dedicated overlay frame and are merely
-- *anchored* to the row they belong to. Anchoring is a layout relationship, not
-- a call, so rows can be moved, hidden and recycled in combat without ever
-- touching a protected frame -- and the button still follows its row.
--
-- Every mutation of a secure button (SetPoint, Show, Hide, SetAttribute) is
-- gated on InCombatLockdown and replayed on PLAYER_REGEN_ENABLED.
--
-- Known limitation, shared with Blizzard's own tracker: a quest item that first
-- appears mid-combat gets no button until combat ends, and if the tracked set
-- reshuffles during a fight a button can sit on the wrong row until then.

local function ClearItemButton(frame)
    -- Legacy per-row buttons no longer exist; kept as a no-op guard because the
    -- render paths call it defensively in a dozen places.
    local btn = frame and frame.itemButton
    if not btn then
        return
    end
    btn:Hide()
    frame.itemButton = nil
end

function T:EnsureItemOverlay()
    if self.itemOverlay then
        return self.itemOverlay
    end
    -- Parented to UIParent. Not to a row, not to the scroll content, not even
    -- to the tracker frame.
    --
    -- This took four attempts. A protected frame cannot be positioned while it
    -- lives inside a ScrollFrame's scroll-child hierarchy -- every variant of
    -- that threw "Cannot anchor protected frames to regions", including one
    -- with no relativeTo argument at all, and none of them only in combat.
    --
    -- KalielsTracker is the working precedent on this client and does exactly
    -- this: KTF.Buttons is a child of UIParent, repositioned in screen
    -- coordinates to sit over the tracker (System/QuestButtons.lua:425), with
    -- its buttons placed by `SetPoint("TOP", 0, yOfs)` inside it.
    --
    -- The overlay itself is insecure, so anchoring IT to the scroll frame is
    -- fine and keeps it tracking the tracker's position and size. The cost is
    -- that it no longer clips: buttons scrolled out of view have to be hidden
    -- explicitly, which LayoutItemButtons does.
    local overlay = CreateFrame("Frame", nil, UIParent)
    local anchorTo = self.scrollFrame or self.content or self.frame
    overlay:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", 0, 0)
    overlay:SetFrameStrata(self.frame and self.frame:GetFrameStrata() or "MEDIUM")
    overlay:SetFrameLevel((self.frame and self.frame:GetFrameLevel() or 1) + 10)
    self.itemOverlay = overlay
    self.itemButtons = {}

    -- Buttons are positioned from the row's offset in the content, so a scroll
    -- moves every one of them. Nothing else recomputes on scroll.
    if self.scrollFrame and not self._itemScrollHooked then
        self._itemScrollHooked = true
        self.scrollFrame:HookScript("OnVerticalScroll", function()
            if not InCombatLockdown() then
                pcall(T.LayoutItemButtons, T, T._pendingItemRequests or {})
            end
        end)
    end

    return overlay
end

function T:AcquireItemButton(index)
    local overlay = self:EnsureItemOverlay()
    if self.itemButtons[index] then
        return self.itemButtons[index]
    end

    local btn = CreateFrame("Button", "FabledUIArtemisQuestItem" .. index, overlay,
        "SecureActionButtonTemplate")
    btn:SetSize(20, 20)
    btn:RegisterForClicks("AnyUp")
    btn:SetAttribute("type", "item")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.cooldown:SetDrawEdge(false)

    btn:SetScript("OnEnter", function(b)
        if not b._questID then return end
        local logIndex = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
            and C_QuestLog.GetLogIndexForQuestID(b._questID)
        if logIndex and GameTooltip.SetQuestLogSpecialItem then
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetQuestLogSpecialItem, GameTooltip, logIndex)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()

    self.itemButtons[index] = btn
    return btn
end

-- Vertical offset of a row inside the scrolling content, recorded by PlaceLine.
local ITEM_BUTTON_SIZE = 20

-- `requests` is a list of { line, quest } gathered during the render pass.
function T:LayoutItemButtons(requests)
    self._pendingItemRequests = requests

    if InCombatLockdown() then
        -- Leave the existing buttons exactly as they are: every call that could
        -- fix them is blocked right now. PLAYER_REGEN_ENABLED replays this.
        self._itemLayoutDeferred = true
        return false
    end

    -- Fail-safe. Positioning a protected frame has thrown here three times in a
    -- row for three different reasons, each only visible on a live client, and
    -- each producing a wall of repeated errors. If it throws again, disable the
    -- secure buttons for the session and say so once, rather than spamming.
    if self._secureItemsBlocked then
        return false
    end

    local overlay = self:EnsureItemOverlay()

    local scroll = self.scrollFrame
    local scrollOffset = (scroll and scroll.GetVerticalScroll and scroll:GetVerticalScroll()) or 0
    local viewportHeight = (scroll and scroll:GetHeight()) or 0

    for index, request in ipairs(requests) do
        local btn = self:AcquireItemButton(index)
        local quest = request.quest
        local line = request.line
        btn._questID = quest.questID

        -- Positioned with POINT + OFFSETS ONLY -- no relativeTo argument.
        --
        -- This is the rule, and it took three attempts to land. A protected
        -- frame cannot be given an explicit anchor target at all: not the row
        -- (tried first), and not even its own parent (tried second). Both throw
        -- "Cannot anchor protected frames to regions", and neither is a combat
        -- restriction -- the first fired at login, the second on a filter-tab
        -- click. Passing only a point and x/y anchors implicitly to the parent,
        -- which is permitted. KalielsTracker does exactly this
        -- (System/QuestButtons.lua: `button:SetPoint("TOP", 0, yOfs)`), which is
        -- the working precedent on this client build.
        --
        -- ClearAllPoints is likewise avoided: reusing the same anchor point
        -- every time means each SetPoint simply replaces the previous one.
        local rowY = line._layoutY or 0
        local rowHeight = line:GetHeight()
        if not rowHeight or rowHeight <= 0 then rowHeight = 18 end
        -- Offset within the VIEWPORT, not the content: the overlay is anchored
        -- to the scroll frame and does not scroll with the rows, so the scroll
        -- position has to come out of the maths by hand.
        local centred = rowY - scrollOffset + (rowHeight - ITEM_BUTTON_SIZE) / 2

        -- The overlay does not clip either, so a row scrolled out of view would
        -- leave its button floating over the toolbar or status bar.
        local visible = viewportHeight <= 0
            or (centred >= -2 and centred + ITEM_BUTTON_SIZE <= viewportHeight + 2)

        local ok = pcall(function()
            btn:SetPoint("TOPRIGHT", -2, -centred)
        end)
        if not ok then
            self._secureItemsBlocked = true
            for _, spare in ipairs(self.itemButtons or {}) do
                pcall(spare.Hide, spare)
            end
            if A.Print then
                A:Print("|cffff5555Quest item buttons disabled this session|r "
                    .. "(the client blocked positioning a secure button). "
                    .. "Quest text and objectives are unaffected.")
            end
            return false
        end

        btn:SetShown(visible)
        btn.icon:SetTexture(quest.itemTexture)

        if quest.itemID then
            btn:SetAttribute("item", "item:" .. quest.itemID)
        else
            -- No resolved ID (cold item cache): the name still works for the
            -- secure attribute, it is just ambiguous across duplicates.
            btn:SetAttribute("item", quest.itemName)
        end

        if type(GetQuestLogSpecialItemCooldown) == "function" and C_QuestLog
            and C_QuestLog.GetLogIndexForQuestID then
            local logIndex = C_QuestLog.GetLogIndexForQuestID(quest.questID)
            if logIndex then
                local start, duration = GetQuestLogSpecialItemCooldown(logIndex)
                if start and duration then
                    btn.cooldown:SetCooldown(start, duration)
                end
            end
        end
        -- Visibility was already decided by the clipping test above; an
        -- unconditional Show here would put scrolled-off buttons back on screen.
    end

    for index = #requests + 1, #(self.itemButtons or {}) do
        self.itemButtons[index]:Hide()
        self.itemButtons[index]._questID = nil
    end

    self._itemLayoutDeferred = false

    return true
end

-- Called from PLAYER_REGEN_ENABLED.
function T:FlushDeferredItemButtons()
    if not self._itemLayoutDeferred then
        return false
    end
    return self:LayoutItemButtons(self._pendingItemRequests or {})
end

-- The row icon carries quest state, so it is set per row rather than once at
-- construction:
--   complete and ready to turn in -> the gold "?" every NPC turn-in uses
--   everything else               -> the greyed map "?" this row already had
-- Super-tracking no longer changes the icon; it changes the title colour, so
-- one glyph means one thing.
function T:ApplyQuestIcon(button, quest, isSuperTracked)
    local complete = quest.isComplete == true

    if complete then
        button.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
        -- That texture is a whole-file icon, not a quadrant of a sheet.
        if button.icon.SetTexCoord then
            button.icon:SetTexCoord(0, 1, 0, 1)
        end
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
        return
    end

    button.icon:SetTexture("Interface\\WorldMap\\UI-WorldMap-QuestIcon")
    if button.icon.SetTexCoord then
        button.icon:SetTexCoord(0, 0.5, 0, 0.5)
    end
    -- Desaturated by default; a navigated quest keeps full colour so the row
    -- still reads as active without borrowing the completion glyph.
    button.icon:SetDesaturated(not isSuperTracked)
    button.icon:SetAlpha(isSuperTracked and 0.9 or 0.45)
end

function T:RenderQuestLine(line, quest)
    HideCurrencyValue(line)
    local icon = U:GetQuestPrefixIcon(quest)
    -- Prefix with Blizzard's own content-tag icon (dungeon/raid/group/elite) so
    -- group/instanced quests are called out at a glance.
    local title = U:GetQuestTagMarkup(quest) .. icon .. quest.title
    local totalObjectives, remainingObjectives = U:CountIncompleteObjectives(quest.objectives)

    if quest.timeLeftText and A.profile.showWorldQuestTimers then
        title = title .. " |cffaaaaaa[" .. quest.timeLeftText .. "]|r"
    end

    if totalObjectives > 0 and remainingObjectives > 0 and not A.profile.compactMode then
        title = title .. string.format(" |cffaaaaaa(%d/%d)|r", totalObjectives - remainingObjectives, totalObjectives)
    end

    -- No % suffix in the title for progress-bar quests any more -- the bar
    -- itself carries the number now, and duplicating it just crowded the row.

    -- Super-track ("navigate here") toggle, mirroring the pin the Blizzard
    -- tracker puts in front of each quest. Sets the same C_SuperTrack target
    -- the world-map POI does, which is what the navigation arrow follows.
    local trackButton = self:EnsureTrackButton(line)
    local isSuperTracked = U:IsSuperTracked(quest.questID)
    trackButton:SetShown(quest.questID ~= nil)
    trackButton._questID = quest.questID
    trackButton._isTracked = isSuperTracked
    trackButton._isComplete = quest.isComplete == true
    self:ApplyQuestIcon(trackButton, quest, isSuperTracked)

    -- AR-002: make the focused quest stand out with a gold accent bar on the
    -- left edge, a subtle row background, and bright accent-coloured title.
    local isFocused = A.character and A.character.focusQuestID == quest.questID
    line.focusBar = line.focusBar or line:CreateTexture(nil, "ARTWORK")
    line.focusBar:ClearAllPoints()
    line.focusBar:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.focusBar:SetSize(3, line:GetHeight() > 0 and line:GetHeight() - 2 or 16)
    line.focusBg = line.focusBg or line:CreateTexture(nil, "BACKGROUND")
    line.focusBg:ClearAllPoints()
    line.focusBg:SetPoint("TOPLEFT", line, "TOPLEFT", 4, 0)
    line.focusBg:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)
    -- One left offset, computed once: the track button, the focus accent and
    -- the progress bar all shift the title, and three separate SetPoint sites
    -- disagreeing is how rows end up misaligned with each other.
    local textLeft = (isFocused and 12 or 8) + (trackButton:IsShown() and 17 or 0)
    trackButton:ClearAllPoints()
    trackButton:SetPoint("TOPLEFT", line, "TOPLEFT", isFocused and 11 or 7, -2)

    line.text:ClearAllPoints()
    if quest.progressPct ~= nil then
        -- Top-anchored so the bar has the bottom band of a taller row to itself.
        line.text:SetPoint("TOPLEFT", line, "TOPLEFT", textLeft, -2)
    else
        line.text:SetPoint("LEFT", line, "LEFT", textLeft, 0)
    end
    line.text:SetPoint("RIGHT", line, "RIGHT", -52, 0)

    -- Title colour encodes one thing each, in this order:
    --   gold  -- complete, ready to turn in (the actionable state, so it wins)
    --   cyan  -- focused (also carries the accent bar and row background, so it
    --            stays obvious even when completion takes the colour)
    --   green -- super-tracked, i.e. the navigation arrow points here
    --   plain -- everything else
    local titleColour
    if quest.isComplete then
        titleColour = "ffd100"
    elseif isFocused then
        titleColour = "3ae9ff"
    elseif isSuperTracked then
        titleColour = "3aff8c"
    end

    if isFocused then
        line.focusBar:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 1)
        line.focusBar:Show()
        line.focusBg:SetColorTexture(ARTEMIS_ACCENT[1], ARTEMIS_ACCENT[2], ARTEMIS_ACCENT[3], 0.12)
        line.focusBg:Show()
        ApplyLineFont(line.text, "GameFontNormal")
    else
        line.focusBar:Hide()
        line.focusBg:Hide()
        ApplyLineFont(line.text, "GameFontHighlightSmall")
    end

    if titleColour then
        line.text:SetText("|cff" .. titleColour .. title .. "|r")
    else
        line.text:SetText(title)
    end

    -- Find Group button for group-eligible quests (Blizzard decides eligibility).
    local canGroup = false
    if quest.questID and C_LFGList and C_LFGList.CanCreateQuestGroup then
        local ok, res = pcall(C_LFGList.CanCreateQuestGroup, quest.questID)
        canGroup = ok and res == true
    end
    if canGroup then
        line.findGroupButton:Show()
        line.findGroupButton:SetScript("OnClick", function()
            if type(LFGListUtil_FindQuestGroup) == "function" then
                pcall(LFGListUtil_FindQuestGroup, quest.questID)
            elseif A.Print then
                A:Print("Premade Group Finder is unavailable right now.")
            end
        end)
        line.text:SetPoint("RIGHT", -74, 0) -- reserve room for the extra button
    else
        line.findGroupButton:Hide()
    end

    line.tooltipTitle = quest.title
    -- Drives the objectives / rewards / quest-ID block in the row's OnEnter.
    line.tooltipQuestID = quest.questID

    local tooltipParts = {}
    local rewardBadge = U:GetRewardBadge(quest)
    local mapName = quest.mapName or (quest.mapID and U:GetMapName(quest.mapID))
    if mapName then
        tooltipParts[#tooltipParts + 1] = "Zone: " .. mapName
    end
    if rewardBadge then
        tooltipParts[#tooltipParts + 1] = "Reward Type: " .. rewardBadge
    end
    if quest.rewardText then
        tooltipParts[#tooltipParts + 1] = "Rewards: " .. quest.rewardText
    end
    if quest.timeLeftText then
        tooltipParts[#tooltipParts + 1] = "Expires: " .. quest.timeLeftText
    end
    if #tooltipParts == 0 then
        tooltipParts[#tooltipParts + 1] = "Left-click opens it on the map. Right-click for waypoint / focus / more. Middle-click routes to Odyssey."
    end
    line.tooltipText = table.concat(tooltipParts, "\n")

    line:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            -- Left-click opens the quest on the world map. The waypoint /
            -- super-track action lives on the right-click menu.
            U:OpenQuestDetails(quest.questID)
        elseif button == "RightButton" then
            if not (A.Menus and A.Menus:OpenQuestMenu(line, quest)) then
                if A.character.focusQuestID == quest.questID then
                    A:ClearFocusQuest()
                else
                    A:SetFocusQuest(quest.questID)
                end
            end
        elseif button == "MiddleButton" and A.profile.routeOnMiddleClick then
            if not A.Odyssey:PushQuest(quest.questID) then
                A:Print("Odyssey bridge not available for quest routing.")
            end
        end
    end)

    if A:IsModuleEnabled("odyssey") and A.Odyssey and A.Odyssey.IsAvailable and A.Odyssey:IsAvailable() then
        line._routeEnabled = true
        line.routeButton:Hide() -- hover-reveal: shown while the row is hovered
        line.routeButton:SetScript("OnClick", function()
            if not A.Odyssey:PushQuest(quest.questID) then
                A:Print("Odyssey bridge not available for quest routing.")
            end
        end)
    else
        line._routeEnabled = false
        line.routeButton:Hide()
        line.routeButton:SetScript("OnClick", nil)
    end

    -- Progress bar for progressbar-objective quests (e.g. "Collect ingredients").
    -- The row was already grown to fit it by the render loop; pull the title up
    -- into the top half so the two don't overlap.
    if quest.progressPct ~= nil then
        local bar = EnsureProgressBar(line)
        bar:SetValue(quest.progressPct)
        bar.label:SetText(string.format("%d%%", quest.progressPct))
        bar:Show()
    elseif line.progressBar then
        line.progressBar:Hide()
    end

    -- Collected rather than created here: the secure buttons live in a flat
    -- overlay pool that is laid out once, after the render pass, so no
    -- protected frame is ever touched inside the row loop.
    if A:IsModuleEnabled("questItems") and quest.itemName and quest.itemTexture then
        self._itemRequests = self._itemRequests or {}
        self._itemRequests[#self._itemRequests + 1] = { line = line, quest = quest }
    end
end

function T:RenderChecklistLine(line, entry)
    HideCurrencyValue(line)
    local left = string.format("|TInterface\\Buttons\\UI-CheckBox-Up:14|t %s", entry.label or entry.id)
    if entry.timeLeftText then
        left = left .. " |cffaaaaaa[" .. entry.timeLeftText .. "]|r"
    end
    -- AR-002: ensure no leftover focus visuals from quest-line reuse.
    if line.focusBar then line.focusBar:Hide() end
    if line.focusBg then line.focusBg:Hide() end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", 8, 0)
    line.text:SetPoint("RIGHT", -52, 0)
    ApplyLineFont(line.text, "GameFontHighlightSmall")
    line.text:SetText(left)
    line.tooltipTitle = entry.label or entry.id
    line.tooltipText = entry.rewardText or "Middle-click routes this item in Odyssey. Right-click opens checklist actions."

    line:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and entry.questID then
            U:OpenQuestDetails(entry.questID)
        elseif button == "RightButton" then
            if not (A.Menus and A.Menus:OpenChecklistMenu(line, entry)) and entry.source == "custom" then
                A.Checklist:ToggleManualEntry(entry.id)
            end
        elseif button == "MiddleButton" then
            if not A.Odyssey:PushChecklist(entry) then
                A:Print("Odyssey bridge not available for checklist routing.")
            end
        end
    end)

    if A:IsModuleEnabled("odyssey") and A.Odyssey and A.Odyssey.IsAvailable and A.Odyssey:IsAvailable() then
        line._routeEnabled = true
        line.routeButton:Hide() -- hover-reveal: shown while the row is hovered
        line.routeButton:SetScript("OnClick", function()
            if not A.Odyssey:PushChecklist(entry) then
                A:Print("Odyssey bridge not available for checklist routing.")
            end
        end)
    else
        line._routeEnabled = false
        line.routeButton:Hide()
        line.routeButton:SetScript("OnClick", nil)
    end
    ClearItemButton(line)
end

-- Render path for the Scenario section: the scenario/delve name, the current
-- step, and each criterion (with a checkmark, an X/Y count, or a % progress bar
-- for weighted criteria).
function T:RenderScenarioLine(line, entry)
    HideCurrencyValue(line)
    if line.focusBar then line.focusBar:Hide() end
    if line.focusBg then line.focusBg:Hide() end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", 8, 0)
    line.text:SetPoint("RIGHT", -8, 0)
    line.text:SetWordWrap(false)

    local text = entry.text or ""
    if entry.isName then
        ApplyLineFont(line.text, "GameFontNormalSmall")
        line.text:SetText("|cff3ae9ff" .. text .. "|r")
    elseif entry.isStep then
        ApplyLineFont(line.text, "GameFontHighlightSmall")
        line.text:SetText("|cffffd100" .. text .. "|r")
    else
        ApplyLineFont(line.text, "GameFontHighlightSmall")
        local prefix = "   "
        if entry.completed then
            prefix = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t "
        elseif entry.failed then
            prefix = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t "
        end
        local suffix = ""
        if entry.progressText and entry.progressText ~= "" then
            suffix = "  |cff3ae9ff" .. entry.progressText .. "|r"
        elseif entry.quantity and entry.totalQuantity then
            suffix = string.format("  |cffaaaaaa%d/%d|r", entry.quantity, entry.totalQuantity)
        end
        line.text:SetText(prefix .. text .. suffix)
        if entry.progressPct then
            local bar = EnsureProgressBar(line)
            bar:SetValue(entry.progressPct)
            bar:Show()
        end
    end

    line.tooltipTitle = nil
    line.tooltipText = nil
    line._routeEnabled = false
    line.routeButton:Hide()
    ClearItemButton(line)
    line:SetScript("OnClick", nil)
end

-- AR-A1: lightweight render path for the Currency section. We reuse the
-- generic line widget but skip click handlers so the row reads as a
-- read-only status indicator. The right-aligned value text is rendered
-- via a secondary FontString that is created lazily.
function T:RenderCurrencyLine(line, entry)
    if line.focusBar then line.focusBar:Hide() end
    if line.focusBg then line.focusBg:Hide() end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", 8, 0)
    ApplyLineFont(line.text, "GameFontHighlightSmall")
    line.text:SetWordWrap(false)
    line.text:SetText(entry.label or entry.id or "Currency")

    line.currencyValue = line.currencyValue or line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.currencyValue:ClearAllPoints()
    line.currencyValue:SetJustifyH("RIGHT")
    line.currencyValue:SetWordWrap(false)

    line.currencyReset = line.currencyReset or line:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    line.currencyReset:ClearAllPoints()
    line.currencyReset:SetJustifyH("RIGHT")
    line.currencyReset:SetWordWrap(false)

    if entry.resetShort then
        -- name | value | reset. The reset gets its own compact, right-aligned
        -- column (amber "2d 17h") so it reads clearly and stops eating the name.
        line.currencyReset:SetPoint("RIGHT", -8, 0)
        line.currencyReset:SetWidth(48)
        line.currencyReset:SetText("|cffc9a94f" .. entry.resetShort .. "|r")
        line.currencyReset:Show()

        line.currencyValue:SetPoint("RIGHT", line.currencyReset, "LEFT", -6, 0)
        line.currencyValue:SetWidth(56)
        line.text:SetPoint("RIGHT", line.currencyValue, "LEFT", -6, 0)
    else
        -- No reset (e.g. gold): hand the value the full right column.
        line.currencyReset:Hide()
        line.currencyValue:SetPoint("RIGHT", -8, 0)
        line.currencyValue:SetWidth(150)
        line.text:SetPoint("RIGHT", line.currencyValue, "LEFT", -6, 0)
    end
    line.currencyValue:SetText(entry.valueText or "?")
    line.currencyValue:Show()

    line.tooltipTitle = entry.label or entry.id
    line.tooltipText = entry.rewardText
    line._routeEnabled = false
    line.routeButton:Hide()
    if line.progressBar then line.progressBar:Hide() end
    ClearItemButton(line)
    line:SetScript("OnClick", nil)
end

-- Tracked profession recipes. Two row shapes share this path: the recipe name
-- (entry.isName) and one row per required reagent slot. Reagent rows read
-- "12/20 Ironclaw Ore" and turn green once the count is met, matching how the
-- default tracker signals a satisfied slot.
function T:RenderRecipeLine(line, entry)
    HideCurrencyValue(line)
    if line.focusBar then line.focusBar:Hide() end
    if line.focusBg then line.focusBg:Hide() end
    if line.progressBar then line.progressBar:Hide() end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", 8, 0)
    line.text:SetPoint("RIGHT", -8, 0)
    line.text:SetWordWrap(false)

    local text = entry.text or ""

    if entry.isName then
        ApplyLineFont(line.text, "GameFontNormalSmall")
        line.text:SetText("|cff" .. SECTION_HEX.RECIPES .. text .. "|r")
        line.tooltipTitle = text
        line.tooltipText = "Left-click opens the recipe. Right-click untracks it."
        line:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if A.Recipes:Untrack(entry.recipeID, entry.isRecraft) then
                    -- TRACKED_RECIPE_UPDATE will fire and queue a refresh, but
                    -- refresh here too so the row disappears on the click rather
                    -- than up to a debounce interval later.
                    self:Refresh(true)
                end
                return
            end
            A.Recipes:OpenRecipe(entry.recipeID)
        end)
    else
        ApplyLineFont(line.text, "GameFontHighlightSmall")
        local prefix = "   "
        local count = ""
        if entry.rangeText then
            -- Variable-quantity slot: the required amount is a player choice
            -- made in the crafting form and is not persisted, so there is no
            -- honest have/need to show. Mirror the default tracker's range.
            count = "|cffaaaaaa" .. entry.rangeText .. "|r "
        elseif entry.totalQuantity then
            if entry.completed then
                prefix = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t "
                count = string.format("|cff33ff99%d/%d|r ", entry.quantity or 0, entry.totalQuantity)
            else
                count = string.format("|cffffff99%d/%d|r ", entry.quantity or 0, entry.totalQuantity)
            end
        end
        line.text:SetText(prefix .. count .. text)
        line.tooltipTitle = text
        line.tooltipText = nil
        line:SetScript("OnClick", nil)
    end

    line._routeEnabled = false
    line.routeButton:Hide()
    ClearItemButton(line)
end

-- Endeavor rows. Same flat header + child-row shape as RenderRecipeLine: one
-- bold row per tracked task, then one dimmed row per requirement with a tick
-- when it is met.
-- Shared renderer for provider sections that produce a flat "header row plus
-- requirement rows" list -- endeavors and Traveler's Log activities today. They
-- differ only in section colour, which module owns untrack/chat-link, and the
-- untrack wording, so those are parameters rather than a second copy of sixty
-- lines. RenderRecipeLine stays separate: its child rows carry reagent counts
-- and a different click contract.
--
-- `opts` = { sectionKey, provider, untrackHint }
function T:RenderProviderLine(line, entry, opts)
    HideCurrencyValue(line)
    if line.focusBar then line.focusBar:Hide() end
    if line.focusBg then line.focusBg:Hide() end
    if line.progressBar then line.progressBar:Hide() end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", 8, 0)
    line.text:SetPoint("RIGHT", -8, 0)
    line.text:SetWordWrap(false)

    local text = entry.text or ""
    local provider = opts.provider

    if entry.isName then
        local suffix = ""
        if entry.requirementsTotal and entry.requirementsTotal > 0 then
            suffix = string.format(" |cffaaaaaa%d/%d|r", entry.requirementsDone or 0, entry.requirementsTotal)
        end
        -- A repeatable task that has been finished before shows its count, the
        -- way the housing dashboard's own tooltip does.
        if entry.repeatable and entry.timesCompleted and entry.timesCompleted > 0 then
            suffix = suffix .. string.format(" |cff8888aa(x%d)|r", entry.timesCompleted)
        end

        -- A completed row only reaches here when "Show Completed Objectives" is
        -- on, so mark it rather than letting it read as outstanding work.
        local prefix = ""
        if entry.completed then
            prefix = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "
        elseif entry.tracked then
            -- Also pushed into Blizzard's objective tracker; worth showing
            -- because it is the difference between this list and that one.
            prefix = "|cff3ae9ff*|r "
        end

        ApplyLineFont(line.text, "GameFontNormalSmall")
        line.text:SetText(prefix .. "|cff" .. (SECTION_HEX[opts.sectionKey] or "ffffff") .. text .. "|r" .. suffix)
        line.tooltipTitle = text
        line.tooltipText = entry.description or opts.untrackHint
        line:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if provider and provider:Untrack(entry.taskID) then
                    -- The tracked-list event queues a refresh anyway, but
                    -- repaint now so the row goes on the click rather than up
                    -- to a debounce interval later.
                    self:Refresh(true)
                end
                return
            end
            -- Shift-click links it in chat, matching every other trackable
            -- thing. No plain-click action: for endeavors that would mean
            -- opening housing UI we deliberately leave alone (see the rule at
            -- the top of Endeavors.lua).
            if IsModifiedClick and IsModifiedClick("CHATLINK") then
                local link = provider and provider:GetChatLink(entry.taskID)
                local insert = rawget(_G, "ChatEdit_InsertLink")
                if link and type(insert) == "function" then
                    pcall(insert, link)
                end
            end
        end)
    else
        ApplyLineFont(line.text, "GameFontHighlightSmall")
        local prefix = "   "
        if entry.completed then
            prefix = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t "
            line.text:SetText(prefix .. "|cff33ff99" .. text .. "|r")
        else
            line.text:SetText(prefix .. "|cffffff99" .. text .. "|r")
        end
        line.tooltipTitle = nil
        line.tooltipText = nil
        line:SetScript("OnClick", nil)
    end
end

-- Thin wrappers so the render dispatch stays a flat section-key lookup and
-- tests/render_contract.lua can assert each method exists on the table.
function T:RenderEndeavorLine(line, entry)
    self:RenderProviderLine(line, entry, {
        sectionKey = "ENDEAVORS",
        provider = A.Endeavors,
        untrackHint = "Right-click to stop tracking this endeavor.",
    })
end

function T:RenderActivityLine(line, entry)
    self:RenderProviderLine(line, entry, {
        sectionKey = "ACTIVITIES",
        provider = A.Activities,
        untrackHint = "Right-click to stop tracking this activity.",
    })
end

function T:RenderAchievementLine(line, achievementID)
    HideCurrencyValue(line)
    local _, achievementName = GetAchievementInfo(achievementID)
    -- AR-002: clear any focus visuals carried over from a recycled quest line.
    if line.focusBar then line.focusBar:Hide() end
    if line.focusBg then line.focusBg:Hide() end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", 8, 0)
    line.text:SetPoint("RIGHT", -52, 0)
    ApplyLineFont(line.text, "GameFontHighlightSmall")
    line.text:SetText("|TInterface\\Icons\\UI_Achievement_Shield:14|t " .. (achievementName or ("Achievement " .. achievementID)))
    line.tooltipTitle = achievementName
    line.tooltipText = "Left-click opens the achievement. Right-click untracks it."
    line:SetScript("OnClick", function(btn, button)
        if button == "LeftButton" then
            ToggleAchievementFrame()
            if AchievementFrame_SelectAchievement then
                AchievementFrame_SelectAchievement(achievementID)
            end
        elseif button == "RightButton" then
            if not A.Menus:OpenAchievementMenu(btn, achievementID) then
                -- Fallback for clients without MenuUtil
                U:UntrackAchievement(achievementID)
                self:Refresh(true)
            end
        end
    end)
    line.routeButton:Hide()
    ClearItemButton(line)
end

function T:Render()
    if not self.frame or not self:IsExpandedVisible() or A.profile.enabled == false then
        return
    end

    if self._rendering then
        local startedAt = self._renderingStartedAt or 0
        local now = GetTime and GetTime() or 0
        if startedAt > 0 and (now - startedAt) >= 5 then
            self._rendering = false
            self._renderingStartedAt = nil
        else
            self._rerenderRequested = true
            return
        end
    end

    self._rendering = true
    self._renderingStartedAt = GetTime and GetTime() or 0

    local ok, err = xpcall(function()
        local state = GetWindowState()
        if self.frame.Content then
            self.frame:SetShellTitle("FabledUI - Artemis")
            self.frame:SetShellSubtitle("")
        else
            ApplyFallbackTheme(self.frame)
            self.frame:SetSize(state.width or A.profile.width or 340, state.height or A.profile.height or 620)
        end
        self:UpdateContentWidth()

        local scan = A.QuestScan:Run(false)
        self.lastScan = scan
        local sections, order = A.Sections:Build(scan)

        local totalQuests = #scan.quests
        local worldCount, dailyCount, weeklyCount = 0, 0, 0
        local dailyEnum = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily
        local weeklyEnum = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly
        for _, quest in ipairs(scan.quests) do
            if quest.isWorldQuest then
                worldCount = worldCount + 1
            end
            if dailyEnum and quest.frequency == dailyEnum then
                dailyCount = dailyCount + 1
            elseif weeklyEnum and quest.frequency == weeklyEnum then
                weeklyCount = weeklyCount + 1
            end
        end

        local checklistCount = (A:IsModuleEnabled("checklist") and sections.CHECKLIST and #sections.CHECKLIST.items) or 0
        -- Compact, adaptive summary: only surface counts that are non-zero so the
        -- line stays short at narrow widths (the focus quest already shows in its
        -- own section, so it's dropped from here).
        local parts = { string.format("|cff3ae9ff%d|r tracked", totalQuests) }
        if worldCount > 0 then parts[#parts + 1] = string.format("%d WQ", worldCount) end
        if dailyCount > 0 then parts[#parts + 1] = string.format("%d daily", dailyCount) end
        if weeklyCount > 0 then parts[#parts + 1] = string.format("%d weekly", weeklyCount) end
        if checklistCount > 0 then parts[#parts + 1] = string.format("%d checklist", checklistCount) end
        self.summary:SetText(table.concat(parts, "  |cff5a5872·|r  "))
        self.frame.presetButton:SetText(A.profile.activePreset or "Preset")
        if self.frame.odysseyButton then
            if A:IsModuleEnabled("odyssey") then
                self.frame.odysseyButton:SetText((A.profile.odysseyRouteMode or "APPEND"):sub(1, 6))
                self.frame.odysseyButton:Enable()
            else
                self.frame.odysseyButton:SetText("Route-")
                self.frame.odysseyButton:Disable()
            end
        end
        -- AR-A3: keep the Solo Focus button label in sync with persisted state.
        if self.frame.soloFocusButton then
            self.frame.soloFocusButton:SetText(A:IsSoloFocusActive() and "Solo Focus*" or "Solo Focus")
        end
        if self.frame.checklistButton then
            if A:IsModuleEnabled("checklist") then
                self.frame.checklistButton:SetText(A.profile.showChecklist and "Rules*" or "Rules")
                self.frame.checklistButton:Enable()
            else
                self.frame.checklistButton:SetText("Rules-")
                self.frame.checklistButton:Disable()
            end
        end
        if self.frame.filterMenuButton then
            if A:IsModuleEnabled("worldQuests") then
                local filters = A.profile.worldQuestFilters or {}
                local wqLabel = string.format("WQ %s/%s", filters.reward or "ALL", filters.time or "ALL")
                if filters.trackedOnly then
                    wqLabel = wqLabel .. "*"
                end
                self.frame.filterMenuButton:SetText(wqLabel)
                self.frame.filterMenuButton:Enable()
                self.frame.filterWorld:Enable()
            else
                self.frame.filterMenuButton:SetText("WQ Off")
                self.frame.filterMenuButton:Disable()
                self.frame.filterWorld:Disable()
            end
        end

        local lineIndex = 1
        local previousLine
        -- Reset before the row loop; RenderQuestLine appends to this and
        -- LayoutItemButtons consumes it once the loop is done.
        self._itemRequests = {}
        -- Rows are no longer a uniform height (progress-bar quests are taller),
        -- so the scroll height has to be accumulated rather than multiplied.
        local usedHeight = 0

        local function PlaceLine(line)
            line:ClearAllPoints()
            if previousLine then
                line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, 0)
                line:SetPoint("TOPRIGHT", previousLine, "BOTTOMRIGHT", 0, 0)
            else
                line:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
                line:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, 0)
            end
            line:Show()
            -- Distance from the top of the scrolling content. The secure
            -- quest-item buttons cannot be anchored to a row (see
            -- LayoutItemButtons), so they are positioned from this offset.
            line._layoutY = usedHeight
            previousLine = line
            usedHeight = usedHeight + (line:GetHeight() or 0)
        end

        for _, sectionKey in ipairs(order) do
            local section = sections[sectionKey]
            local itemCount = section and #section.items or 0
            if section and (itemCount > 0 or sectionKey == "FOCUS") then
                local header = self:AcquireLine(lineIndex, true)
                lineIndex = lineIndex + 1
                header:SetHeight(22)
                -- AR-002: header lines never carry focus visuals.
                if header.focusBar then header.focusBar:Hide() end
                if header.focusBg then header.focusBg:Hide() end
                -- AR-A1: hide any currency value text inherited from line reuse.
                HideCurrencyValue(header)
                header.text:ClearAllPoints()
                header.text:SetPoint("LEFT", 8, 0)
                header.text:SetPoint("RIGHT", -52, 0)
                ApplyLineFont(header.text, "GameFontNormalSmall")
                local collapseState = A:GetCollapsed(sectionKey)
                local collapseIcon = collapseState and "+" or "-"
                local sectionHex = HexForSection(sectionKey)
                header.text:SetText(string.format("|cffaaaaaa%s|r |cff%s%s|r |cffaaaaaa(%d)|r", collapseIcon, sectionHex, section.meta.label, itemCount))
                header.tooltipTitle = section.meta.label
                header.tooltipText = "Click to expand or collapse this group."
                header.routeButton:Hide()
                ClearItemButton(header)
                header:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then
                        if not (A.Menus and A.Menus:OpenSectionMenu(header, sectionKey, itemCount, section.meta and section.meta.label)) then
                            A:SetCollapsed(sectionKey, not A:GetCollapsed(sectionKey))
                            self:Refresh(true)
                        end
                        return
                    end
                    A:SetCollapsed(sectionKey, not A:GetCollapsed(sectionKey))
                    self:Refresh(true)
                end)
                PlaceLine(header)

                if not collapseState then
                    if sectionKey == "FOCUS" and itemCount == 0 then
                        local hint = self:AcquireLine(lineIndex, false)
                        lineIndex = lineIndex + 1
                        hint:SetHeight(18)
                        -- AR-002: hint rows never carry focus visuals.
                        if hint.focusBar then hint.focusBar:Hide() end
                        if hint.focusBg then hint.focusBg:Hide() end
                        HideCurrencyValue(hint)
                        hint.text:ClearAllPoints()
                        hint.text:SetPoint("LEFT", 8, 0)
                        hint.text:SetPoint("RIGHT", -52, 0)
                        ApplyLineFont(hint.text, "GameFontDisableSmall")
                        hint.text:SetText("Right-click any quest to make it your focus target.")
                        hint.tooltipTitle = nil
                        hint.tooltipText = nil
                        hint.routeButton:Hide()
                        ClearItemButton(hint)
                        hint:SetScript("OnClick", nil)
                        PlaceLine(hint)
                    else
                        for _, item in ipairs(section.items) do
                            local line = self:AcquireLine(lineIndex, false)
                            lineIndex = lineIndex + 1
                            local baseHeight = A.profile.compactMode and 16 or 18
                            -- Progress-bar quests get a taller row so the bar
                            -- occupies its own band instead of overlapping the
                            -- title. Set before RenderQuestLine, which anchors
                            -- the title against the final height.
                            local wantsProgressBar = sectionKey ~= "CHECKLIST"
                                and sectionKey ~= "ACHIEVEMENTS"
                                and sectionKey ~= "CURRENCIES"
                                and sectionKey ~= "SCENARIO"
                                and sectionKey ~= "RECIPES"
                                and sectionKey ~= "ENDEAVORS"
                                and sectionKey ~= "ACTIVITIES"
                                and item.progressPct ~= nil
                            line:SetHeight(wantsProgressBar and ProgressRowHeight(baseHeight) or baseHeight)
                            line.routeButton:Hide()
                            ClearItemButton(line)
                            line.findGroupButton:Hide()
                            if sectionKey == "CHECKLIST" then
                                self:RenderChecklistLine(line, item)
                            elseif sectionKey == "ACHIEVEMENTS" then
                                self:RenderAchievementLine(line, item)
                            elseif sectionKey == "SCENARIO" then
                                self:RenderScenarioLine(line, item)
                            elseif sectionKey == "RECIPES" then
                                self:RenderRecipeLine(line, item)
                            elseif sectionKey == "ENDEAVORS" then
                                self:RenderEndeavorLine(line, item)
                            elseif sectionKey == "ACTIVITIES" then
                                self:RenderActivityLine(line, item)
                            elseif sectionKey == "CURRENCIES" then
                                -- AR-A1: render currency status rows.
                                self:RenderCurrencyLine(line, item)
                            else
                                self:RenderQuestLine(line, item)
                            end
                            PlaceLine(line)

                            -- Objectives are per-quest expandable. An explicit
                            -- expand wins over the "Show Objectives" default
                            -- and over compact mode -- clicking a row's icon is
                            -- a request for that row specifically, and having
                            -- it silently do nothing because a global switch is
                            -- off is worse than a slightly taller row.
                            local questExpanded = item.questID ~= nil
                                and (A:IsQuestExpanded(item.questID)
                                    or (A.character and A.character.focusQuestID == item.questID)
                                    or (A.profile.showObjectives and not A.profile.compactMode))

                            if questExpanded and sectionKey ~= "CHECKLIST" and sectionKey ~= "ACHIEVEMENTS" and sectionKey ~= "CURRENCIES" and sectionKey ~= "ENDEAVORS" and sectionKey ~= "ACTIVITIES" then
                                for _, objective in ipairs(item.objectives or {}) do
                                    if A.profile.showCompletedObjectives or not objective.finished then
                                        local objectiveLine = self:AcquireLine(lineIndex, false)
                                        lineIndex = lineIndex + 1
                                        objectiveLine:SetHeight(16)
                                        -- AR-002: objective rows never carry focus visuals.
                                        if objectiveLine.focusBar then objectiveLine.focusBar:Hide() end
                                        if objectiveLine.focusBg then objectiveLine.focusBg:Hide() end
                                        HideCurrencyValue(objectiveLine)
                                        objectiveLine.text:ClearAllPoints()
                                        objectiveLine.text:SetPoint("LEFT", 8, 0)
                                        objectiveLine.text:SetPoint("RIGHT", -52, 0)
                                        -- Texture, not "✓": the default UI font
                                        -- has no glyph for U+2713 and renders a
                                        -- missing-glyph box instead.
                                        local bullet = objective.finished
                                            and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
                                            or "|cff8a82a0-|r"
                                        ApplyLineFont(objectiveLine.text, "GameFontDisableSmall")
                                        objectiveLine.text:SetText(string.format("   %s %s", bullet, objective.text or "Objective"))
                                        objectiveLine.tooltipTitle = item.title
                                        objectiveLine.tooltipText = objective.text
                                        objectiveLine.routeButton:Hide()
                                        ClearItemButton(objectiveLine)
                                        objectiveLine:SetScript("OnClick", function()
                                            U:OpenQuestDetails(item.questID)
                                        end)
                                        PlaceLine(objectiveLine)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        self:HideUnusedLines(lineIndex)

        -- Position the secure quest-item buttons now that every row has its
        -- final anchor. No-ops (and defers to PLAYER_REGEN_ENABLED) in combat.
        self:LayoutItemButtons(self._itemRequests)

        self.content:SetHeight(math.max(1, usedHeight + 32))

        local odysseyStatus = A:IsModuleEnabled("odyssey") and (A.Odyssey:IsAvailable() and "Odyssey linked" or "Odyssey unavailable") or "Odyssey disabled"
        local wqStatus = A:IsModuleEnabled("worldQuests") and ((A.WorldQuests and A.WorldQuests.IsAvailable and A.WorldQuests:IsAvailable()) and "WQ ready" or "WQ shell") or "WQ disabled"
        local wqSummary = (A.WorldQuests and A.WorldQuests.GetFilterSummary and A.WorldQuests:GetFilterSummary()) or "ALL / ALL"
        local statusText = string.format("Storage: %s  •  %s  •  %s  •  Filter: %s  •  WQ: %s", A._storageBackend or "Unknown", odysseyStatus, wqStatus, A.profile.filterMode or "ALL", wqSummary)
        if self.frame.SetShellStatus then
            self.frame:SetShellStatus(statusText)
        elseif self.frame.status then
            self.frame.status:SetText(statusText)
        end
    end, function(message)
        if type(geterrorhandler) == "function" and type(geterrorhandler()) == "function" then
            geterrorhandler()(message)
        end
        return tostring(message)
    end)

    self._rendering = false
    self._renderingStartedAt = nil

    if not ok then
        self._rerenderRequested = false
        if A and A.Print then
            A:Print("Render failure:", err)
        end
        return
    end

    if self._rerenderRequested then
        self._rerenderRequested = false
        C_Timer.After(0, function()
            if self.frame and self:IsExpandedVisible() then
                self:Render()
            end
        end)
    end
end

function T:Refresh(forceRender)
    if not self.frame or A.profile.enabled == false then
        return
    end

    if forceRender or self:IsExpandedVisible() then
        self:Render()
    end
    if self.UpdateFilterTabs then self:UpdateFilterTabs() end
    if self.UpdateScrollThumb then self:UpdateScrollThumb() end
end

function T:Show()
    if not self.frame then
        self:InitUI()
    end
    if A.profile.enabled == false then
        return
    end
    if self.frame.ShowExpanded then
        self.frame:ShowExpanded()
    else
        self.frame:Show()
    end
    -- AR-004: record that the user has the tracker open so /reload can restore it.
    local state = GetWindowState()
    state.shown = true
    self:ManageDefaultTracker()
    self:Refresh(true)
end

-- Load-time counterpart to Show(). Show() means "the user asked for it", so it
-- always expands; this restores whatever state the tracker was left in, so
-- minimising it and then reloading no longer brings it back full size.
function T:Restore()
    if not self.frame then
        self:InitUI()
    end
    if A.profile.enabled == false then
        return
    end
    if self.frame.ShowPersisted then
        self.frame:ShowPersisted()
    elseif self.frame.ShowExpanded then
        self.frame:ShowExpanded()
    else
        self.frame:Show()
    end
    local state = GetWindowState()
    state.shown = true
    self:ManageDefaultTracker()
    self:Refresh(true)
end

function T:Hide()
    if not self.frame then
        return
    end
    -- The quest-item buttons are secure, and hiding an ancestor of a protected
    -- frame is blocked in combat. Defer rather than fire a blocked action --
    -- PLAYER_REGEN_ENABLED replays it.
    if InCombatLockdown() and self.itemButtons and next(self.itemButtons) ~= nil then
        self._pendingHide = true
        return
    end
    self._pendingHide = false
    if self.frame.HideShell then
        self.frame:HideShell()
    else
        self.frame:Hide()
    end
    -- AR-004: record that the tracker is hidden so we do not auto-show after /reload.
    local state = GetWindowState()
    state.shown = false
    self:ManageDefaultTracker()
end

function T:Toggle(forceShow)
    if not self.frame then
        self:InitUI()
    end

    if self.frame.ToggleShell then
        self.frame:ToggleShell(forceShow)
        -- AR-004: capture visibility after the toolkit shell finishes its toggle.
        local state = GetWindowState()
        state.shown = self:IsExpandedVisible() and true or false
        self:ManageDefaultTracker()
        if self:IsExpandedVisible() then
            self:Refresh(true)
        end
        return
    end

    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function T:PrewarmLinePool(count)
    if not self.content then return end
    for i = 1, count do
        self:AcquireLine(i, false)
    end
end

function T:Init()
    self:InitUI()
    self:PrewarmLinePool(80)
    if A.profile.enabled ~= false then
        -- AR-004: restore the tracker if the user had it open before /reload.
        -- We default to shown for first-run installs (see GetWindowState defaults).
        local state = GetWindowState()
        if state.shown ~= false then
            -- Restore, not Show: Show() forces the window expanded, which threw
            -- away a minimised window on every /reload.
            self:Restore()
        end
        -- ManageDefaultTracker now honours the "Hide Blizzard Tracker" preference
        -- regardless of our shell visibility, so the Blizzard tracker stays hidden
        -- across /reload when the preference is enabled.
        self:ManageDefaultTracker()
    end
end
