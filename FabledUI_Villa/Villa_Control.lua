local Villa = _G.FabledUI_Villa
local Control = {}
Villa.Control = Control
Villa:RegisterModule("Control", Control)

local UI = Villa.UI

-- Villa's live control window.
--
-- This is Villa's real settings surface. It replaces two things:
--
--  1. The Blizzard canvas panel Villa used to register (Settings.lua). Opening
--     that throws up the full-screen settings frame, which covers the world,
--     the map and the housing UI -- the exact things you need to SEE while
--     changing a domain mode or toggling the zone overlay. The canvas category
--     stays registered so the Game Menu entry keeps working, but it is now a
--     stub that points back here.
--  2. The "Control Center" tab in FabledUI_Nexus, which reached directly into
--     Villa's globals, settings table and submodules because Villa had no
--     Shell-based window of its own. Nexus is the suite launcher; hardcoding
--     one addon's internals into it bypassed the registry contract and meant
--     Villa's controls only existed while Nexus was installed. See
--     docs/Villa/Lane_Requests.md for the inventory this carries over.
--
-- Notably NOT carried over from the Nexus version: the installed/loaded
-- plumbing (inside Villa that is always true), the "Load Villa" button, the
-- self-referential "Open Villa Settings" button, and the direct
-- `villa.settings.domainModes[domain] = mode` fallback. That fallback wrote
-- past the setter, so it skipped the per-domain refresh SetMode fires and left
-- the UI showing a mode nothing had actually applied. In here it is just the
-- setter.

local WINDOW_NAME = "FabledUI_VillaControl"

-- Fixed content column. The window resizes, but wrapping is computed against
-- this width rather than the live frame width so a resize can never leave a
-- half-laid-out row behind.
local CONTENT_W = 496
local BTN_W, BTN_H, BTN_GAP = 88, 22, 6
local ACTION_W = 152

local DOMAINS = {
    { key = "vendors",      label = "Vendor Browser" },
    { key = "zoneOverlay",  label = "Zone Overlay" },
    { key = "mapPins",      label = "Vendor Map Pins" },
    { key = "achievements", label = "Achievements" },
    { key = "quests",       label = "Quests" },
    { key = "professions",  label = "Professions" },
}
Control.DOMAINS = DOMAINS

-- The three canonical modes lead, in the order the Nexus panel used them;
-- donor-specific engines (hdg, hit, betterhomes, ...) follow alphabetically.
-- Nexus only ever showed the first three, so the donor modes were reachable
-- solely through the old canvas panel's blind "Cycle" button.
local MODE_RANK = { hybrid = 1, codex = 2, villa = 3 }

local ACTIONS = {
    { key = "toggle",          label = "Toggle Villa" },
    { key = "open_vendors",    label = "Open Vendors" },
    { key = "dashboard",       label = "Housing Dashboard" },
    { key = "refresh_vendors", label = "Refresh Vendors" },
    { key = "refresh_overlay", label = "Refresh Overlay" },
    { key = "refresh_pins",    label = "Refresh Pins" },
}
Control.ACTIONS = ACTIONS

-- The immediate refresh is what makes this panel "live" -- the whole reason it
-- is a Shell window and not a Blizzard canvas category.
local TOGGLES = {
    { key = "showZoneOverlay",             label = "Show zone overlay",                          refresh = "overlay" },
    { key = "showMapPins",                 label = "Show vendor map pins",                       refresh = "pins" },
    { key = "includeCollectedVendorDecor", label = "Include collected decor in overlay",         refresh = "overlay" },
    { key = "showWorldMapButton",          label = "Show the Villa button on the world map",     refresh = "worldmap" },
    { key = "restoreLastPanel",            label = "Restore last Villa panel on reopen" },
    { key = "zoneToasts",                  label = "Zone entry toasts for uncollected vendors" },
    { key = "autoAcceptHousingQuests",     label = "Auto-accept housing quests" },
    { key = "showMarketValue",             label = "Show market value in tooltips (TSM/Auctionator)" },
    { key = "trackVendorVisits",           label = "Track vendor visits" },
    { key = "showAcquiredAlerts",          label = "Show acquired-item alerts" },
    { key = "acquiredAlertsWishlistOnly",  label = "Acquired alerts: wishlist items only" },
}
Control.TOGGLES = TOGGLES

-- ── Behaviour (no frames below this line until BuildWindow) ──────────────────

-- Returns true when the refresh actually ran, so callers can report a dead
-- button rather than silently claiming success.
local function RunRefresh(kind)
    if kind == "overlay" then
        if Villa.ZoneOverlay and type(Villa.ZoneOverlay.Refresh) == "function" then
            Villa.ZoneOverlay:Refresh()
            return true
        end
    elseif kind == "pins" then
        if Villa.MapPins and type(Villa.MapPins.RefreshAllData) == "function" then
            Villa.MapPins:RefreshAllData()
            return true
        end
    elseif kind == "vendors" then
        if Villa.Vendors and type(Villa.Vendors.Refresh) == "function" then
            Villa.Vendors:Refresh()
            return true
        end
    elseif kind == "worldmap" then
        if Villa.WorldMapButton and type(Villa.WorldMapButton.RefreshVisibility) == "function" then
            Villa.WorldMapButton:RefreshVisibility()
            return true
        end
    end
    return false
end

function Control:GetDomainModes(domain)
    local engines = Villa:GetRegisteredEngines(domain)
    local ordered = {}
    for key in pairs(engines) do
        ordered[#ordered + 1] = key
    end
    table.sort(ordered, function(a, b)
        local rankA, rankB = MODE_RANK[a] or 99, MODE_RANK[b] or 99
        if rankA ~= rankB then
            return rankA < rankB
        end
        return a < b
    end)
    return ordered
end

function Control:GetSummary()
    local summary = {
        version = Villa.VERSION,
        modes = {},
        toggles = {},
    }
    for _, info in ipairs(DOMAINS) do
        summary.modes[info.key] = Villa:GetActiveMode(info.key) or "none"
    end
    local settings = Villa.settings or {}
    for _, info in ipairs(TOGGLES) do
        summary.toggles[info.key] = settings[info.key] == true
    end
    return summary
end

-- Straight through the real setter. SetMode validates the engine is registered
-- and fires that domain's refresh itself, so there is nothing to duplicate.
function Control:SetDomainMode(domain, mode)
    if not domain or not mode then
        return false
    end
    local changed = Villa:SetMode(domain, mode) == true
    if changed then
        -- SetMode refreshes this window too (Core.lua), so this is belt and
        -- braces. Kept because a mode row that does not repaint leaves two
        -- buttons enabled and no way to tell which mode is live.
        self:Refresh()
    end
    return changed
end

function Control:SetToggle(settingKey, enabled)
    if not settingKey or type(Villa.settings) ~= "table" then
        return false
    end
    Villa.settings[settingKey] = enabled and true or false
    for _, info in ipairs(TOGGLES) do
        if info.key == settingKey then
            RunRefresh(info.refresh)
            break
        end
    end
    self:Refresh()
    return true
end

function Control:TriggerAction(action)
    local handled = false
    if action == "toggle" and type(Villa.ToggleUI) == "function" then
        Villa:ToggleUI()
        handled = true
    elseif action == "open_vendors" and type(Villa.OpenPanel) == "function" then
        Villa:OpenPanel("vendors")
        handled = true
    elseif action == "dashboard" and type(Villa.ShowDashboard) == "function" then
        Villa:ShowDashboard()
        handled = true
    elseif action == "refresh_vendors" then
        handled = RunRefresh("vendors")
    elseif action == "refresh_overlay" then
        handled = RunRefresh("overlay")
    elseif action == "refresh_pins" then
        handled = RunRefresh("pins")
    end
    if handled then
        self:Refresh()
    end
    return handled
end

-- ── Frames ──────────────────────────────────────────────────────────────────

local function MakeSection(parent, titleText, width)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetWidth(width)
    box:SetHeight(1)
    if UI then
        UI:ApplyBackdrop(box, UI.InsetBG, UI.PanelBorder)
        UI:AddNeonSeam(box)
    end

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetJustifyH("LEFT")
    title:SetText(titleText)
    box.Title = title
    return box
end

-- The template's own `Text` is not something to rely on -- the offline
-- simulator does not build template children, and the label is the only thing
-- distinguishing eleven otherwise identical checkboxes. Own the FontString.
local function MakeCheck(parent, info)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)

    local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 2, 0)
    label:SetJustifyH("LEFT")
    label:SetText(info.label)
    if box.Text and type(box.Text.SetText) == "function" then
        box.Text:SetText("")
    end

    box.VillaLabel = label
    box.settingKey = info.key
    box:SetScript("OnClick", function(self)
        Control:SetToggle(info.key, self:GetChecked() and true or false)
    end)
    return box
end

local function BuildModeRow(parent, info, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(width)
    row.domain = info.key

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(info.label)

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", title, "RIGHT", 10, 0)
    value:SetJustifyH("LEFT")
    if UI and UI.TextMuted then
        value:SetTextColor(UI.Unpack(UI.TextMuted))
    end
    row.Value = value

    row.buttons = {}
    local modes = Control:GetDomainModes(info.key)
    local perLine = math.max(1, math.floor((width + BTN_GAP) / (BTN_W + BTN_GAP)))
    local lines = 0
    for index, mode in ipairs(modes) do
        local column = (index - 1) % perLine
        local line = math.floor((index - 1) / perLine)
        lines = line + 1

        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(BTN_W, BTN_H)
        button:SetPoint("TOPLEFT", column * (BTN_W + BTN_GAP), -18 - (line * (BTN_H + 4)))
        -- Parenthesised: gsub returns (string, count) and the count would land
        -- in SetText's second argument.
        button:SetText((mode:gsub("^%l", string.upper)))
        button:SetScript("OnClick", function()
            Control:SetDomainMode(info.key, mode)
        end)
        if UI then
            UI:StyleButton(button)
        end
        row.buttons[mode] = button
    end

    if lines == 0 then
        -- A domain with nothing registered is a data problem, not an empty row.
        -- Say so rather than drawing a label with no controls under it.
        value:SetText("no providers registered")
        row:SetHeight(20)
    else
        row:SetHeight(18 + (lines * (BTN_H + 4)))
    end
    return row
end

function Control:EnsureWindow()
    if self.window then
        return self.window
    end

    local T = rawget(_G, "FabledUI_UIToolkit")
    if not (T and T.Shell and type(T.Shell.CreateWindow) == "function") then
        if Villa.Print then
            Villa:Print("UIToolkit shell unavailable -- cannot open the Villa control window.")
        end
        return nil
    end

    if Villa.db and Villa.db.ui then
        Villa.db.ui.controlWindow = Villa.db.ui.controlWindow or {}
    end

    local win = T.Shell:CreateWindow(WINDOW_NAME, {
        title = "FabledUI - Villa Controls",
        subtitle = "Live cockpit. Change a mode and watch the map, overlay and world update behind this window.",
        width = 566,
        height = 640,
        minWidth = 566,
        minHeight = 420,
        maxWidth = 900,
        maxHeight = 1100,
        theme = "FableNeon",
        ribbon = false,
        state = (Villa.db and Villa.db.ui and Villa.db.ui.controlWindow) or nil,
    })
    if not win then
        return nil
    end

    -- Shell does not order its windows, so each addon opts in individually.
    -- Villa was the last suite window that did not, which is why it interleaved
    -- with Nexus instead of raising when clicked. Stopgap until the toolkit
    -- owns this centrally -- see docs/UIToolkit/Lane_Requests.md.
    if win.SetToplevel then
        win:SetToplevel(true)
    end

    self.window = win
    local content = win.Content or win

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -26, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    self.scroll, self.child = scroll, child

    local y = 0

    -- Status ------------------------------------------------------------------
    local status = MakeSection(child, "Status", CONTENT_W)
    status:SetPoint("TOPLEFT", 0, -y)

    local statusText = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", status.Title, "BOTTOMLEFT", 0, -6)
    statusText:SetPoint("RIGHT", status, "RIGHT", -12, 0)
    statusText:SetJustifyH("LEFT")
    self.statusText = statusText
    status:SetHeight(62)
    y = y + status:GetHeight() + 10

    -- Quick actions -----------------------------------------------------------
    local actions = MakeSection(child, "Quick Actions", CONTENT_W)
    actions:SetPoint("TOPLEFT", 0, -y)

    local actionPerLine = math.max(1, math.floor((CONTENT_W - 24 + BTN_GAP) / (ACTION_W + BTN_GAP)))
    local actionLines = 0
    for index, info in ipairs(ACTIONS) do
        local column = (index - 1) % actionPerLine
        local line = math.floor((index - 1) / actionPerLine)
        actionLines = line + 1

        local button = CreateFrame("Button", nil, actions, "UIPanelButtonTemplate")
        button:SetSize(ACTION_W, 24)
        button:SetPoint("TOPLEFT", 12 + (column * (ACTION_W + BTN_GAP)), -32 - (line * 28))
        button:SetText(info.label)
        button:SetScript("OnClick", function()
            Control:TriggerAction(info.key)
        end)
        if UI then
            UI:StyleButton(button)
        end
    end
    actions:SetHeight(38 + (actionLines * 28))
    y = y + actions:GetHeight() + 10

    -- Domain modes ------------------------------------------------------------
    local modes = MakeSection(child, "Domain Modes", CONTENT_W)
    modes:SetPoint("TOPLEFT", 0, -y)

    self.modeRows = {}
    local rowY = 32
    for _, info in ipairs(DOMAINS) do
        local row = BuildModeRow(modes, info, CONTENT_W - 24)
        row:SetPoint("TOPLEFT", 12, -rowY)
        rowY = rowY + row:GetHeight() + 8
        self.modeRows[#self.modeRows + 1] = row
    end
    modes:SetHeight(rowY + 8)
    y = y + modes:GetHeight() + 10

    -- Display toggles ---------------------------------------------------------
    local display = MakeSection(child, "Display", CONTENT_W)
    display:SetPoint("TOPLEFT", 0, -y)

    self.checkboxes = {}
    local checkY = 32
    for _, info in ipairs(TOGGLES) do
        local box = MakeCheck(display, info)
        box:SetPoint("TOPLEFT", 12, -checkY)
        checkY = checkY + 26
        self.checkboxes[#self.checkboxes + 1] = box
    end

    local positionButton = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    positionButton:SetSize(180, 24)
    positionButton:SetPoint("TOPLEFT", 14, -(checkY + 6))
    positionButton:SetScript("OnClick", function()
        local settings = Villa.settings
        if type(settings) ~= "table" then
            return
        end
        settings.zoneOverlayPosition = (settings.zoneOverlayPosition == "topLeft") and "bottomRight" or "topLeft"
        RunRefresh("overlay")
        Control:Refresh()
    end)
    if UI then
        UI:StyleButton(positionButton)
    end
    self.positionButton = positionButton
    display:SetHeight(checkY + 40)
    y = y + display:GetHeight() + 10

    child:SetHeight(math.max(1, y))

    if UI then
        UI:StyleDescendants(child)
    end
    return win
end

function Control:Refresh()
    if not self.window then
        return
    end

    local summary = self:GetSummary()

    if self.statusText then
        local parts = {}
        for _, info in ipairs(DOMAINS) do
            parts[#parts + 1] = info.label .. ": " .. tostring(summary.modes[info.key])
        end
        self.statusText:SetText(("Villa v%s\n%s"):format(tostring(summary.version or "unknown"), table.concat(parts, "  |  ")))
    end

    for _, row in ipairs(self.modeRows or {}) do
        local active = summary.modes[row.domain] or Villa:GetActiveMode(row.domain) or "none"
        if row.Value and next(row.buttons or {}) ~= nil then
            row.Value:SetText("Active: " .. tostring(active))
        end
        for key, button in pairs(row.buttons or {}) do
            -- The active mode's button is disabled, so the current state reads
            -- off the row without a separate indicator.
            button:SetEnabled(key ~= active)
        end
    end

    for _, box in ipairs(self.checkboxes or {}) do
        box:SetChecked(summary.toggles[box.settingKey] == true)
    end

    if self.positionButton then
        local settings = Villa.settings or {}
        self.positionButton:SetText("Overlay corner: " .. tostring(settings.zoneOverlayPosition or "topLeft"))
    end

    if type(self.window.SetShellStatus) == "function" then
        self.window:SetShellStatus("Villa v" .. tostring(summary.version or "unknown"))
    end
end

function Control:Open()
    local win = self:EnsureWindow()
    if not win then
        return false
    end
    self:Refresh()
    if type(win.ShowExpanded) == "function" then
        win:ShowExpanded()
    else
        win:Show()
    end
    return true
end

function Control:IsShown()
    if not self.window then
        return false
    end
    if type(self.window.IsShellVisible) == "function" then
        return self.window:IsShellVisible() and true or false
    end
    return self.window:IsShown() and true or false
end

function Control:Close()
    if not self.window then
        return
    end
    if type(self.window.HideShell) == "function" then
        self.window:HideShell()
    else
        self.window:Hide()
    end
end

function Control:Toggle()
    if self:IsShown() then
        self:Close()
        return false
    end
    return self:Open()
end
