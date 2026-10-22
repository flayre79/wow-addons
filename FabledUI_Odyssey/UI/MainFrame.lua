local addonName, ns = ...
local O = ns.Odyssey

local MainFrame = {}
O.UI.MainFrame = MainFrame

local ROW_HEIGHT = 24

-- ==========================================
-- FABLENEON THEME (cosmetic only)
-- ==========================================
local TK = rawget(_G, "FabledUI_UIToolkit")
local FN_ACCENT = { 0.31, 0.72, 0.91, 1.0 } -- azure (journey/wayfinding)

local function StyleButton(b)
    if b and TK and TK.Themes and TK.Themes.StyleFlatButton then
        TK.Themes:StyleFlatButton(b, "FableNeon", FN_ACCENT)
    end
end

local function StylePanel(frame)
    if frame and TK and TK.Themes and TK.Themes.ApplyPanel then
        TK.Themes:ApplyPanel(frame, "FableNeon", FN_ACCENT)
    end
end

local function CreateButton(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 80, height or 22)
    button:SetText(text or "Button")
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    StyleButton(button)
    return button
end

local function CreateInput(parent, width, height)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetSize(width or 120, height or 24)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    return input
end

-- The row controls are 20px squares labelled with a single character, so what
-- each one does is only discoverable from a tooltip.
local function AddButtonTooltip(button, text)
    if not button then
        return
    end
    button:HookScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

-- Atlas-backed icon button.
--
-- The suite catalogues Blizzard's atlas names in FabledUI_Toolkit_AssetBrowser
-- (Data_AtlasMainline.lua); drawing from those keeps the row controls legible
-- instead of falling back to a single ASCII letter per button, and avoids the
-- missing-glyph problem that made the old "≡" drag handle render as an empty
-- box in the default UI font.
local function CreateIconButton(parent, atlas, size, tooltipText, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 20, size or 20)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    -- pcall: an atlas missing from the running client (or from the simulator,
    -- which has no atlas table) must leave a blank button, not raise.
    if atlas and icon.SetAtlas then
        pcall(icon.SetAtlas, icon, atlas)
    end
    button.icon = icon

    button:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")

    -- Plain buttons have no template art, so disabled state has to be shown by
    -- hand or a greyed-out control looks identical to a live one.
    function button:SetIconEnabled(enabled)
        self:SetEnabled(enabled and true or false)
        self.icon:SetAlpha(enabled and 1 or 0.35)
        if self.icon.SetDesaturated then
            pcall(self.icon.SetDesaturated, self.icon, not enabled)
        end
    end

    if onClick then
        button:SetScript("OnClick", onClick)
    end
    if tooltipText then
        AddButtonTooltip(button, tooltipText)
    end
    return button
end

-- A real placeholder: greyed-out text drawn *over* an empty box, rather than
-- SetText'ing the hint into the box itself. The old approach seeded the box
-- with "New waypoint title", so GetText() returned the hint and every saved
-- waypoint was literally named after it.
local function SetPlaceholder(input, text)
    local hint = input:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", input, "LEFT", 4, 0)
    hint:SetText(text)
    hint:SetJustifyH("LEFT")
    input.placeholder = hint

    local function update()
        hint:SetShown((input:GetText() or "") == "")
    end
    -- Exposed as well as hooked. The live client fires OnTextChanged from
    -- SetText, but nothing should depend on that: any code path that sets the
    -- text programmatically calls this directly so the hint can never be left
    -- stranded over text the user can see.
    input.UpdatePlaceholder = update

    input:HookScript("OnTextChanged", update)
    input:HookScript("OnEditFocusGained", function() hint:Hide() end)
    input:HookScript("OnEditFocusLost", update)
    update()
    return input
end

-- Every scroll child in this file is created 1x1 and afterwards only ever
-- given a height, so its width stays at one pixel. Rows anchored TOPLEFT and
-- TOPRIGHT to that child are one pixel wide too, which puts anything anchored
-- to a row's RIGHT edge off the left-hand side of the row -- that is why the
-- per-row up/down/delete buttons were invisible in the list even though they
-- were being created and wired up correctly.
--
-- Panels are hidden when Create() runs, so GetWidth() is 0 at build time.
-- Bind on size change and re-sync from each Refresh, which runs whenever a tab
-- is shown.
local function SyncScrollChild(scrollFrame, content)
    if not scrollFrame or not content then
        return
    end
    local width = scrollFrame:GetWidth()
    if not width or width <= 0 then
        return
    end
    if math.abs((content:GetWidth() or 0) - width) > 0.5 then
        content:SetWidth(width)
    end
end

local function BindScrollChild(scrollFrame, content, fallbackWidth)
    -- A sane starting width so the first frame drawn is not one pixel wide.
    content:SetSize(fallbackWidth or 760, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:HookScript("OnSizeChanged", function()
        SyncScrollChild(scrollFrame, content)
    end)
    SyncScrollChild(scrollFrame, content)
end

local function CreateSectionLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetText(text)
    return label
end

function O:InitializeMainFrame()
    MainFrame:Create()
end

function MainFrame:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "FabledUI_OdysseyFrame", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(820, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.11, 0.92)
    frame:SetBackdropBorderColor(0.1, 0.5, 0.8, 1)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        self:SaveWindowState()
    end)
    frame:Hide()

    -- Resizable, with the geometry persisted. db.ui.mainWindow has carried
    -- point/size/scale since the first version but nothing ever read or wrote
    -- it, so the window reset to 820x560 in the middle of the screen every
    -- login.
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(700, 440)
    elseif frame.SetMinResize then
        -- Pre-10.0 clients split this across two calls.
        frame:SetMinResize(700, 440)
    end

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveWindowState()
        self:RefreshAll()
    end)
    self.resizeGrip = grip

    -- Re-skin the plain container with the shared FableNeon panel styling.
    StylePanel(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("|cff4fb8e8Odyssey|r - Waypoints, Tours, Audit, Gaps")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    if TK and TK.Themes and TK.Themes.StyleCloseButton then TK.Themes:StyleCloseButton(closeButton) end

    local tabNames = { "Waypoints", "Tours", "Audit", "Gaps", "Settings" }
    self.tabs = {}
    self.panels = {}
    self.currentTab = "Waypoints"

    for index, tabName in ipairs(tabNames) do
        local tabButton = CreateButton(frame, tabName, 90, 24, function()
            self:ShowTab(tabName)
        end)
        tabButton:SetPoint("TOPLEFT", 12 + ((index - 1) * 96), -38)
        self.tabs[tabName] = tabButton

        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 12, -70)
        panel:SetPoint("BOTTOMRIGHT", -12, 12)
        panel:Hide()
        self.panels[tabName] = panel
    end

    self:BuildWaypointsPanel(self.panels.Waypoints)
    self:BuildToursPanel(self.panels.Tours)
    self:BuildAuditPanel(self.panels.Audit)
    self:BuildGapsPanel(self.panels.Gaps)
    self:BuildSettingsPanel(self.panels.Settings)
    self:CreateToastFrame()
    self:RestoreWindowState()
    self:ShowTab("Waypoints")
end

-- Window geometry, through UIToolkit's WindowState when the toolkit is loaded.
-- It is an OptionalDep, so both of these fall back to doing the same job by
-- hand rather than silently not persisting.
function MainFrame:SaveWindowState()
    if not self.frame or not O.db or type(O.db.ui) ~= "table" then
        return
    end
    local state = O.db.ui.mainWindow
    if type(state) ~= "table" then
        return
    end

    if TK and TK.WindowState and TK.WindowState.Capture then
        TK.WindowState:Capture(self.frame, state)
    else
        local point, _, relativePoint, x, y = self.frame:GetPoint(1)
        state.point = point or "CENTER"
        state.relativePoint = relativePoint or "CENTER"
        state.x = x or 0
        state.y = y or 0
        state.width = math.floor(self.frame:GetWidth() + 0.5)
        state.height = math.floor(self.frame:GetHeight() + 0.5)
    end
    O:MarkDirty()
end

function MainFrame:RestoreWindowState()
    if not self.frame or not O.db or type(O.db.ui) ~= "table" then
        return
    end
    local state = O.db.ui.mainWindow
    if type(state) ~= "table" then
        return
    end

    if TK and TK.WindowState and TK.WindowState.Apply then
        TK.WindowState:Apply(self.frame, state)
    else
        self.frame:ClearAllPoints()
        self.frame:SetPoint(state.point or "CENTER", UIParent, state.relativePoint or "CENTER", state.x or 0, state.y or 0)
        if state.width and state.height then
            self.frame:SetSize(state.width, state.height)
        end
    end

    -- Never restore a window smaller than the resize floor: a saved size from
    -- an older layout can be narrower than the controls need.
    if self.frame:GetWidth() < 700 or self.frame:GetHeight() < 440 then
        self.frame:SetSize(math.max(700, self.frame:GetWidth()), math.max(440, self.frame:GetHeight()))
    end
end

function MainFrame:CreateToastFrame()
    local toast = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    toast:SetSize(280, 56)
    -- Anchored to the bottom edge, not the top. At TOP -72 it sat exactly over
    -- the panel content area and covered the first lines of the audit report.
    toast:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 16)
    toast:SetFrameStrata("FULLSCREEN_DIALOG")
    toast:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    toast:SetBackdropColor(0.02, 0.05, 0.08, 0.96)
    toast:SetBackdropBorderColor(0, 0.7, 1, 0.85)
    toast:Hide()

    toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.title:SetPoint("TOPLEFT", 10, -10)
    toast.body = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.body:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
    toast.body:SetWidth(260)
    toast.body:SetJustifyH("LEFT")
    self.toastFrame = toast
end

function MainFrame:Toast(title, body)
    local toast = self.toastFrame
    if not toast then
        return
    end
    toast.title:SetText(title or "")
    toast.body:SetText(body or "")
    toast:Show()
    if toast._timer then
        toast._timer:Cancel()
    end
    toast._timer = C_Timer.NewTimer(2.5, function()
        toast:Hide()
    end)
end

function MainFrame:Toggle(forceShow)
    if not self.frame then
        self:Create()
    end

    if forceShow then
        self.frame:Show()
    else
        self.frame:SetShown(not self.frame:IsShown())
    end

    if self.frame:IsShown() then
        self:RefreshAll()
    end
end

function MainFrame:ShowTab(tabName)
    self.currentTab = tabName
    for name, panel in pairs(self.panels) do
        panel:SetShown(name == tabName)
        if self.tabs[name] then
            self.tabs[name]:SetEnabled(name ~= tabName)
        end
    end

    if tabName == "Waypoints" then
        self:RefreshWaypointsPanel()
    elseif tabName == "Tours" then
        self:RefreshToursPanel()
    elseif tabName == "Audit" then
        self:RefreshAuditPanel()
    elseif tabName == "Gaps" then
        self:RefreshGapsPanel()
    elseif tabName == "Settings" then
        self:RefreshSettingsPanel()
    end
end

function MainFrame:RefreshAll()
    self:RefreshWaypointsPanel()
    self:RefreshToursPanel()
    self:RefreshAuditPanel()
    self:RefreshGapsPanel()
    self:RefreshSettingsPanel()
end

function MainFrame:BuildWaypointsPanel(panel)
    panel.selectedLabel = CreateSectionLabel(panel, "Active Waypoints")
    panel.selectedLabel:SetPoint("TOPLEFT", 0, 0)

    panel.trackButton = CreateButton(panel, "Track Selected", 120, 24, function()
        if self.selectedWaypointID then
            O.Services.WaypointService:TrackWaypoint(self.selectedWaypointID)
        end
    end)
    panel.trackButton:SetPoint("TOPLEFT", 0, -24)

    panel.untrackButton = CreateButton(panel, "Untrack", 90, 24, function()
        O.Services.WaypointService:UntrackWaypoint()
    end)
    panel.untrackButton:SetPoint("LEFT", panel.trackButton, "RIGHT", 8, 0)

    panel.clearButton = CreateButton(panel, "Clear All", 90, 24, function()
        O.Services.WaypointService:ClearAllWaypoints()
    end)
    panel.clearButton:SetPoint("LEFT", panel.untrackButton, "RIGHT", 8, 0)

    panel.importExportBox = CreateInput(panel, 360, 26)
    panel.importExportBox:SetPoint("TOPLEFT", 0, -60)

    panel.exportButton = CreateButton(panel, "Export", 80, 24, function()
        panel.importExportBox:SetText(O.Services.WaypointService:ExportWaypoints("all"))
        panel.importExportBox:HighlightText()
    end)
    panel.exportButton:SetPoint("LEFT", panel.importExportBox, "RIGHT", 8, 0)

    panel.importButton = CreateButton(panel, "Import", 80, 24, function()
        local count = O.Services.WaypointService:ImportWaypoints(panel.importExportBox:GetText() or "", { trackNewest = false })
        self:Toast("Import complete", string.format("Imported %d waypoint(s).", count))
        panel.importExportBox:SetText("")
    end)
    panel.importButton:SetPoint("LEFT", panel.exportButton, "RIGHT", 8, 0)

    panel.newTitleInput = CreateInput(panel, 180, 24)
    panel.newTitleInput:SetPoint("TOPLEFT", 0, -96)
    SetPlaceholder(panel.newTitleInput, "New waypoint title")

    local function addCurrentPosition()
        local title = O:Trim(panel.newTitleInput:GetText())
        local waypointID, err = O.Services.WaypointService:CapturePlayerPosition(title ~= "" and title or nil, {
            source = "Manual",
            tags = { "manual" },
            autoTrack = false,
        })
        if not waypointID then
            self:Toast("Unable to add waypoint", err or "Player position could not be resolved here.")
            return
        end
        -- Clear on success so the next capture does not silently reuse the
        -- previous name for a different spot.
        panel.newTitleInput:SetText("")
        panel.newTitleInput:ClearFocus()
        if panel.newTitleInput.UpdatePlaceholder then
            panel.newTitleInput.UpdatePlaceholder()
        end
    end

    -- Enter in the title box does the same thing as the button.
    panel.newTitleInput:SetScript("OnEnterPressed", addCurrentPosition)

    panel.addCurrentButton = CreateButton(panel, "Add Current Position", 160, 24, addCurrentPosition)
    panel.addCurrentButton:SetPoint("LEFT", panel.newTitleInput, "RIGHT", 8, 0)

    panel.saveBlizzardButton = CreateButton(panel, "Save Blizzard Waypoint", 160, 24, function()
        O:CaptureCurrentUserWaypoint(false)
    end)
    panel.saveBlizzardButton:SetPoint("TOPLEFT", 0, -126)

    panel.saveQuestButton = CreateButton(panel, "Save Supertracked Quest", 160, 24, function()
        O:CaptureCurrentSuperTrackedQuest(O.db.settings.autoTrackImportedQuest)
    end)
    panel.saveQuestButton:SetPoint("LEFT", panel.saveBlizzardButton, "RIGHT", 8, 0)

    panel.saveMapButton = CreateButton(panel, "Save Map Cursor", 140, 24, function()
        local waypointID, err = O:CaptureWaypointFromWorldMapCursor(false)
        if not waypointID and err then
            self:Toast("Map capture failed", err)
        end
    end)
    panel.saveMapButton:SetPoint("LEFT", panel.saveQuestButton, "RIGHT", 8, 0)

    panel.providerText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.providerText:SetPoint("LEFT", panel.saveQuestButton, "RIGHT", 12, 0)

    -- Column headers, at the same x offsets the row builder uses below, so a
    -- bare list of numbers reads as distance/ETA rather than as mystery
    -- columns.
    local function header(text, xOffset, width, justify)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", xOffset, -150)
        label:SetWidth(width)
        label:SetJustifyH(justify or "LEFT")
        label:SetText("|cff8fa3b8" .. text .. "|r")
        return label
    end
    panel.headerTitle = header("Waypoint", 30, 250)
    panel.headerDistance = header("Distance", 286, 80)
    panel.headerETA = header("ETA", 372, 80)
    panel.headerSource = header("Source", 458, 90)

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -166)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 0)
    panel.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    BindScrollChild(scrollFrame, content)
    panel.content = content
    panel.rows = {}

    panel.dragState = {
        draggedWaypointID = nil,
        proxy = nil,
    }
end

function MainFrame:EnsureWaypointDragProxy(panel)
    if panel.dragState.proxy then
        return panel.dragState.proxy
    end

    local proxy = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    proxy:SetSize(260, 24)
    proxy:SetFrameStrata("TOOLTIP")
    proxy:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    proxy:SetBackdropColor(0.05, 0.10, 0.18, 0.95)
    proxy.text = proxy:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    proxy.text:SetPoint("CENTER")
    proxy:Hide()
    panel.dragState.proxy = proxy
    return proxy
end

function MainFrame:BeginWaypointDrag(panel, waypoint)
    panel.dragState.draggedWaypointID = waypoint.id
    local proxy = self:EnsureWaypointDragProxy(panel)
    proxy.text:SetText("Dragging: " .. (waypoint.title or "Waypoint"))
    proxy:Show()
    proxy:SetScript("OnUpdate", function(f)
        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale + 20)
    end)
end

-- Which row index the cursor is currently over.
--
-- Worked out from geometry rather than from the frame under the mouse: rows
-- are pooled and repositioned on every refresh, and the drag proxy sits under
-- the cursor while dragging, so asking the client what is beneath the pointer
-- gives the proxy, not the row.
function MainFrame:ResolveWaypointDropIndex(panel)
    local content = panel and panel.content
    if not content or not content.GetTop then
        return nil
    end

    local top = content:GetTop()
    local scale = content:GetEffectiveScale()
    if not top or not scale or scale <= 0 then
        return nil
    end

    local _, cursorY = GetCursorPosition()
    if not cursorY then
        return nil
    end

    local count = #O.db.waypoints
    if count == 0 then
        return nil
    end

    local offset = top - (cursorY / scale)
    local index = math.floor(offset / ROW_HEIGHT) + 1
    return math.max(1, math.min(count, index))
end

function MainFrame:EndWaypointDrag(panel)
    local draggedWaypointID = panel.dragState.draggedWaypointID
    local proxy = panel.dragState.proxy

    if proxy then
        proxy:SetScript("OnUpdate", nil)
        proxy:Hide()
    end

    panel.dragState.draggedWaypointID = nil
    if not draggedWaypointID then
        return false
    end

    -- The drop target is wherever the cursor ended up. The old version was
    -- handed the dragged row's *own* id as the target, so the equality guard
    -- below always tripped and the reorder never ran; the OnReceiveDrag path
    -- that was meant to supply a real target never fired either, because
    -- OnReceiveDrag only triggers for genuine cursor payloads (items, spells)
    -- and a custom frame drag sets none.
    local targetIndex = self:ResolveWaypointDropIndex(panel)
    if not targetIndex then
        return false
    end

    return O.Services.WaypointService:ReorderWaypoint(draggedWaypointID, targetIndex) and true or false
end

function MainFrame:RefreshWaypointsPanel()
    local panel = self.panels.Waypoints
    if not panel then
        return
    end

    panel.providerText:SetText("Provider: " .. (O:GetPreferredProviderName() or "None"))
    SyncScrollChild(panel.scrollFrame, panel.content)

    local content = panel.content
    local yOffset = 0
    for index, waypoint in ipairs(O.db.waypoints) do
        local row = panel.rows[index]
        if not row then
            row = CreateFrame("Button", nil, content)
            row:SetHeight(ROW_HEIGHT)
            row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            row:EnableMouse(true)
            row:RegisterForClicks("LeftButtonUp")
            row:RegisterForDrag("LeftButton")

            -- Grip drawn from three bars rather than a glyph: the default UI
            -- font has no character for "≡", so the old handle rendered as an
            -- empty tofu box.
            row.dragHandle = CreateFrame("Button", nil, row)
            row.dragHandle:SetSize(16, 20)
            row.dragHandle:SetPoint("LEFT", 4, 0)
            row.dragHandle:RegisterForDrag("LeftButton")
            for bar = 1, 3 do
                local line = row.dragHandle:CreateTexture(nil, "ARTWORK")
                line:SetColorTexture(0.55, 0.62, 0.72, 0.85)
                line:SetSize(10, 1)
                line:SetPoint("CENTER", row.dragHandle, "CENTER", 0, (bar - 2) * 4)
            end
            row.dragHandle:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
            AddButtonTooltip(row.dragHandle, "Drag to reorder")

            row.titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.titleText:SetPoint("LEFT", row.dragHandle, "RIGHT", 6, 0)
            row.titleText:SetWidth(250)
            row.titleText:SetJustifyH("LEFT")

            row.distanceText = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            row.distanceText:SetPoint("LEFT", row.titleText, "RIGHT", 6, 0)
            row.distanceText:SetWidth(80)

            row.etaText = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            row.etaText:SetPoint("LEFT", row.distanceText, "RIGHT", 6, 0)
            row.etaText:SetWidth(80)

            row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.sourceText:SetPoint("LEFT", row.etaText, "RIGHT", 6, 0)
            row.sourceText:SetWidth(90)
            row.sourceText:SetJustifyH("LEFT")

            row.trackButton = CreateIconButton(row, "Waypoint-MapPin-Untracked", 18, "Track this waypoint")
            row.trackButton:SetPoint("RIGHT", -94, 0)

            row.upButton = CreateIconButton(row, "Adventures-Scroll-Arrow-Up", 18, "Move up")
            row.upButton:SetPoint("RIGHT", -70, 0)

            row.downButton = CreateIconButton(row, "Adventures-Scroll-Arrow-Down", 18, "Move down")
            row.downButton:SetPoint("RIGHT", -46, 0)

            row.deleteButton = CreateIconButton(row, "common-icon-redx", 18, "Delete this waypoint")
            row.deleteButton:SetPoint("RIGHT", -22, 0)

            panel.rows[index] = row
        end

        local tracked = tonumber(O.db.trackedWaypointID) == tonumber(waypoint.id)
        local distance = O:GetDistanceToWaypoint(waypoint)
        local eta = O:GetETAForDistance(distance)
        -- Tracked state reads off the pin icon plus the title colour, rather
        -- than an inline texture escape in the string.
        if row.trackButton.icon.SetAtlas then
            pcall(row.trackButton.icon.SetAtlas, row.trackButton.icon,
                tracked and "Waypoint-MapPin-Tracked" or "Waypoint-MapPin-Untracked")
        end
        row.titleText:SetText((tracked and "|cff4fb8e8" or "") .. (waypoint.title or "Waypoint") .. (tracked and "|r" or ""))
        row.distanceText:SetText(O.db.settings.showDistance and O:FormatDistance(distance) or "")
        row.etaText:SetText(O.db.settings.showETA and O:FormatTime(eta) or "")
        local sourceLabel = ""
        if O.db.settings.showSourceLabels then
            sourceLabel = waypoint.source or ""
            if waypoint.questID then
                sourceLabel = sourceLabel ~= "" and (sourceLabel .. " • Q" .. waypoint.questID) or ("Q" .. waypoint.questID)
            end
        end
        row.sourceText:SetText(sourceLabel)
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", 0, -yOffset)
        row:SetAlpha((tonumber(self.selectedWaypointID) == tonumber(waypoint.id)) and 1 or 0.75)
        row:Show()

        row:SetScript("OnClick", function()
            self.selectedWaypointID = waypoint.id
            self:RefreshWaypointsPanel()
        end)
        row.trackButton:SetScript("OnClick", function()
            O.Services.WaypointService:TrackWaypoint(waypoint.id)
        end)
        -- Both the grip and the row body start a drag, so the list can be
        -- reordered without having to hit a 16px target.
        local function beginDrag()
            self:BeginWaypointDrag(panel, waypoint)
        end
        local function endDrag()
            self:EndWaypointDrag(panel)
        end

        row:SetScript("OnDragStart", beginDrag)
        row:SetScript("OnDragStop", endDrag)
        row.dragHandle:SetScript("OnDragStart", beginDrag)
        row.dragHandle:SetScript("OnDragStop", endDrag)
        row.upButton:SetScript("OnClick", function()
            O.Services.WaypointService:MoveWaypoint(waypoint.id, -1)
        end)
        row.downButton:SetScript("OnClick", function()
            O.Services.WaypointService:MoveWaypoint(waypoint.id, 1)
        end)
        row.deleteButton:SetScript("OnClick", function()
            O.Services.WaypointService:RemoveWaypoint(waypoint.id)
        end)
        row.upButton:SetIconEnabled(index > 1)
        row.downButton:SetIconEnabled(index < #O.db.waypoints)

        yOffset = yOffset + ROW_HEIGHT
    end

    for index = #O.db.waypoints + 1, #panel.rows do
        panel.rows[index]:Hide()
    end

    content:SetHeight(math.max(1, yOffset))
end

function MainFrame:BuildToursPanel(panel)
    panel.header = CreateSectionLabel(panel, "Tours")
    panel.header:SetPoint("TOPLEFT", 0, 0)

    panel.nameInput = CreateInput(panel, 180, 24)
    panel.nameInput:SetPoint("TOPLEFT", 0, -24)

    panel.createButton = CreateButton(panel, "Create Tour", 100, 24, function()
        local name = O:Trim(panel.nameInput:GetText())
        if name ~= "" then
            local tourID = O.Modules.Tours:CreateTour(name, {})
            if tourID then
                O.Modules.Tours:StartTour(tourID)
                panel.nameInput:SetText("")
            end
        end
    end)
    panel.createButton:SetPoint("LEFT", panel.nameInput, "RIGHT", 8, 0)

    panel.addCurrentButton = CreateButton(panel, "Add Current Pos", 120, 24, function()
        O.Modules.Tours:AddCurrentPositionToActiveTour("")
    end)
    panel.addCurrentButton:SetPoint("LEFT", panel.createButton, "RIGHT", 8, 0)

    panel.startButton = CreateButton(panel, "Start Selected", 110, 24, function()
        if self.selectedTourID then
            O.Modules.Tours:StartTour(self.selectedTourID)
        end
    end)
    panel.startButton:SetPoint("LEFT", panel.addCurrentButton, "RIGHT", 8, 0)

    panel.prevButton = CreateButton(panel, "Prev", 70, 24, function()
        O.Modules.Tours:AdvanceTour(-1)
    end)
    panel.prevButton:SetPoint("TOPLEFT", 0, -58)

    panel.nextButton = CreateButton(panel, "Next", 70, 24, function()
        O.Modules.Tours:AdvanceTour(1)
    end)
    panel.nextButton:SetPoint("LEFT", panel.prevButton, "RIGHT", 8, 0)

    panel.exportButton = CreateButton(panel, "Export Active Tour", 140, 24, function()
        panel.importExportBox:SetText(O.Services.WaypointService:ExportWaypoints("tour"))
        panel.importExportBox:HighlightText()
    end)
    panel.exportButton:SetPoint("LEFT", panel.nextButton, "RIGHT", 16, 0)

    panel.importExportBox = CreateInput(panel, 340, 24)
    panel.importExportBox:SetPoint("TOPLEFT", 0, -92)
    panel.importButton = CreateButton(panel, "Import", 80, 24, function()
        local count = O.Services.WaypointService:ImportWaypoints(panel.importExportBox:GetText() or "", { trackNewest = false })
        self:Toast("Tour import", string.format("Imported %d waypoint(s).", count))
        panel.importExportBox:SetText("")
    end)
    panel.importButton:SetPoint("LEFT", panel.importExportBox, "RIGHT", 8, 0)

    panel.activeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.activeText:SetPoint("LEFT", panel.importButton, "RIGHT", 12, 0)

    local toursScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    toursScroll:SetPoint("TOPLEFT", 0, -130)
    toursScroll:SetSize(320, 380)
    panel.toursScroll = toursScroll

    local toursContent = CreateFrame("Frame", nil, toursScroll)
    BindScrollChild(toursScroll, toursContent, 320)
    panel.toursContent = toursContent
    panel.tourRows = {}

    local pointsScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    pointsScroll:SetPoint("TOPLEFT", toursScroll, "TOPRIGHT", 24, 0)
    pointsScroll:SetPoint("BOTTOMRIGHT", -28, 0)
    panel.pointsScroll = pointsScroll

    local pointsContent = CreateFrame("Frame", nil, pointsScroll)
    BindScrollChild(pointsScroll, pointsContent, 400)
    panel.pointsContent = pointsContent
    panel.pointRows = {}
end

function MainFrame:RefreshToursPanel()
    local panel = self.panels.Tours
    if not panel then
        return
    end

    SyncScrollChild(panel.toursScroll, panel.toursContent)
    SyncScrollChild(panel.pointsScroll, panel.pointsContent)

    local activeTour = O.Modules.Tours:GetActiveTour()
    panel.activeText:SetText(activeTour and ("Active: " .. activeTour.name .. " [" .. (tonumber(O.db.activeTourIndex) or 1) .. "/" .. #activeTour.waypointIDs .. "]") or "Active: none")

    local yOffset = 0
    for index, tour in ipairs(O.db.tours) do
        local row = panel.tourRows[index]
        if not row then
            row = CreateFrame("Button", nil, panel.toursContent)
            row:SetHeight(ROW_HEIGHT)
            row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", 4, 0)
            row.text:SetWidth(220)
            row.text:SetJustifyH("LEFT")
            row.count = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            row.count:SetPoint("LEFT", row.text, "RIGHT", 6, 0)
            row.deleteButton = CreateButton(row, "X", 20, 20)
            row.deleteButton:SetPoint("RIGHT", -2, 0)
            panel.tourRows[index] = row
        end

        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", 0, -yOffset)
        row.text:SetText((tonumber(O.db.activeTourID) == tonumber(tour.id) and "|TInterface\\Common\\FavoritesIcon:12|t " or "") .. tour.name)
        row.count:SetText(string.format("%d pts", #tour.waypointIDs))
        row:SetAlpha((tonumber(self.selectedTourID) == tonumber(tour.id)) and 1 or 0.75)
        row:Show()

        row:SetScript("OnClick", function()
            self.selectedTourID = tour.id
            self:RefreshToursPanel()
        end)
        row.deleteButton:SetScript("OnClick", function()
            O.Modules.Tours:DeleteTour(tour.id)
        end)

        yOffset = yOffset + ROW_HEIGHT
    end
    for index = #O.db.tours + 1, #panel.tourRows do
        panel.tourRows[index]:Hide()
    end
    panel.toursContent:SetHeight(math.max(1, yOffset))

    local selectedTour = self.selectedTourID and O.Modules.Tours:GetTourByID(self.selectedTourID) or activeTour
    local pointOffset = 0
    local selectedTourID = selectedTour and selectedTour.id or nil
    for pointIndex = 1, (selectedTour and #selectedTour.waypointIDs or 0) do
        local row = panel.pointRows[pointIndex]
        if not row then
            row = CreateFrame("Button", nil, panel.pointsContent)
            row:SetHeight(ROW_HEIGHT)
            row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.title:SetPoint("LEFT", 4, 0)
            row.title:SetWidth(220)
            row.title:SetJustifyH("LEFT")
            row.trackButton = CreateButton(row, "Go", 32, 20)
            row.trackButton:SetPoint("RIGHT", -70, 0)
            row.upButton = CreateButton(row, "^", 20, 20)
            row.upButton:SetPoint("RIGHT", -46, 0)
            row.downButton = CreateButton(row, "v", 20, 20)
            row.downButton:SetPoint("RIGHT", -22, 0)
            panel.pointRows[pointIndex] = row
        end

        local waypointID = selectedTour.waypointIDs[pointIndex]
        local waypoint = O.Services.WaypointService:GetWaypointByID(waypointID)
        row:SetPoint("TOPLEFT", 0, -pointOffset)
        row:SetPoint("TOPRIGHT", 0, -pointOffset)
        row.title:SetText(((tonumber(O.db.activeTourID) == tonumber(selectedTourID) and tonumber(O.db.activeTourIndex) == pointIndex) and "|TInterface\\Common\\FavoritesIcon:12|t " or "") .. (waypoint and waypoint.title or ("Missing #" .. waypointID)))
        row:Show()

        row.trackButton:SetScript("OnClick", function()
            if tonumber(O.db.activeTourID) ~= tonumber(selectedTourID) then
                O.Modules.Tours:StartTour(selectedTourID)
            end
            O.db.activeTourIndex = pointIndex
            if waypointID then
                O.Services.WaypointService:TrackWaypoint(waypointID)
            end
            self:RefreshToursPanel()
        end)
        row.upButton:SetScript("OnClick", function()
            O.Modules.Tours:MoveWaypointWithinTour(selectedTourID, pointIndex, -1)
        end)
        row.downButton:SetScript("OnClick", function()
            O.Modules.Tours:MoveWaypointWithinTour(selectedTourID, pointIndex, 1)
        end)
        row.upButton:SetEnabled(pointIndex > 1)
        row.downButton:SetEnabled(pointIndex < #selectedTour.waypointIDs)

        pointOffset = pointOffset + ROW_HEIGHT
    end
    for index = (selectedTour and #selectedTour.waypointIDs or 0) + 1, #panel.pointRows do
        panel.pointRows[index]:Hide()
    end
    panel.pointsContent:SetHeight(math.max(1, pointOffset))
end

function MainFrame:BuildAuditPanel(panel)
    panel.runButton = CreateButton(panel, "Run Audit", 120, 24, function()
        O.Modules.Audit:Run(true)
        self:RefreshAuditPanel()
    end)
    panel.runButton:SetPoint("TOPLEFT", 0, 0)

    panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.summary:SetPoint("LEFT", panel.runButton, "RIGHT", 12, 0)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -36)
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    BindScrollChild(scroll, content)
    panel.content = content
    panel.scroll = scroll

    panel.report = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.report:SetPoint("TOPLEFT", 0, 0)
    panel.report:SetWidth(740)
    panel.report:SetJustifyH("LEFT")
end

function MainFrame:RefreshAuditPanel()
    local panel = self.panels.Audit
    if not panel then
        return
    end

    SyncScrollChild(panel.scroll, panel.content)
    panel.summary:SetText("Last run: " .. (O.db.audit.lastSummary or "Never run"))
    panel.report:SetText(O.Modules.Audit:GetRenderedReport())
    panel.content:SetHeight(math.max(1, panel.report:GetStringHeight() + 20))
end

local PRIORITY_COLORS = {
    P0 = "|cffff4444",
    P1 = "|cffff9900",
    P2 = "|cffffff00",
    P3 = "|cffaaaaaa",
}
local STATUS_COLORS = {
    Open     = "|cff88ddff",
    Done     = "|cff44ff44",
    Deferred = "|cffaaaaaa",
}

function MainFrame:BuildGapsPanel(panel)
    -- Row 1: title input + priority selector + add button
    panel.titleInput = CreateInput(panel, 240, 24)
    panel.titleInput:SetPoint("TOPLEFT", 0, 0)

    local priorityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priorityLabel:SetPoint("LEFT", panel.titleInput, "RIGHT", 8, 0)
    priorityLabel:SetText("Priority:")

    panel._addPriority = "P2"
    local priCycle = CreateButton(panel, "P2", 46, 24, function(btn)
        local order = { "P0", "P1", "P2", "P3" }
        local cur = panel._addPriority
        for i, v in ipairs(order) do
            if v == cur then
                panel._addPriority = order[(i % #order) + 1]
                btn:SetText(panel._addPriority)
                return
            end
        end
        panel._addPriority = "P2"
        btn:SetText("P2")
    end)
    priCycle:SetPoint("LEFT", priorityLabel, "RIGHT", 4, 0)
    panel.priCycle = priCycle

    panel.addButton = CreateButton(panel, "Add Gap", 90, 24, function()
        local title = O:Trim(panel.titleInput:GetText())
        if title ~= "" then
            O.Modules.Gaps:Add(title, panel._addPriority, "", "")
            panel.titleInput:SetText("")
        end
    end)
    panel.addButton:SetPoint("LEFT", priCycle, "RIGHT", 8, 0)

    -- Row 2: status filter + summary
    local filterLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", 0, -32)
    filterLabel:SetText("Show:")

    local filters = { "All", "Open", "Done", "Deferred" }
    panel._statusFilter = "Open"
    local filterCycle = CreateButton(panel, "Open", 70, 22, function(btn)
        local cur = panel._statusFilter
        for i, v in ipairs(filters) do
            if v == cur then
                panel._statusFilter = filters[(i % #filters) + 1]
                btn:SetText(panel._statusFilter)
                self:RefreshGapsPanel()
                return
            end
        end
    end)
    filterCycle:SetPoint("LEFT", filterLabel, "RIGHT", 4, -32)
    panel.filterCycle = filterCycle

    panel.summaryText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.summaryText:SetPoint("LEFT", filterCycle, "RIGHT", 16, 0)
    panel.summaryText:SetText("")

    -- Scrollable list
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -62)
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    BindScrollChild(scroll, content)
    panel.content = content
    panel.scroll = scroll
    panel.rows = {}
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
-- Odyssey's options live here rather than in Blizzard's AddOns panel, which
-- is where the rest of the suite keeps them (see FabledUI_Iris/UI.lua). It
-- also sidesteps the taint problem the old Blizzard registration had to work
-- around: nothing in this panel is bound into the Settings framework's
-- commit path, so the SavedVariable is only ever touched by our own code.

-- Booleans. Every one writes straight to db.settings and marks the store dirty.
local SETTING_SECTIONS = {
    {
        title = "Waypoint Service",
        rows = {
            { key = "autoTrackOnAdd", label = "Auto-track On Add", tip = "Immediately track a waypoint when it is created." },
            { key = "suppressDuplicates", label = "Suppress Duplicate Waypoints", tip = "Avoid storing another waypoint when the same spot is already saved." },
            { key = "showDistance", label = "Show Distance", tip = "Show live distance in the waypoint list." },
            { key = "showETA", label = "Show ETA", tip = "Show ETA estimates based on sampled movement speed." },
            { key = "showSourceLabels", label = "Show Source Labels", tip = "Show where each waypoint came from." },
        },
    },
    {
        title = "Capture & Sync",
        rows = {
            { key = "autoCaptureUserWaypoint", label = "Auto-capture Blizzard Waypoint", tip = "Import Blizzard user waypoints into Odyssey when they change." },
            { key = "autoImportSuperTrackedQuest", label = "Auto-import Supertracked Quest", tip = "Import the current supertracked quest destination." },
            { key = "autoTrackImportedQuest", label = "Auto-track Imported Quest", tip = "Immediately track quest waypoints that Odyssey imports." },
            { key = "captureQuestOnAccept", label = "Capture On Quest Accept", tip = "Capture a waypoint when you accept a quest that already has one." },
            { key = "showWorldMapButton", label = "Show World Map Buttons", tip = "Show Odyssey capture buttons on the world map." },
            { key = "mapClickCaptureEnabled", label = "Show Save Map Cursor", tip = "Store a waypoint where the cursor sits on the world map." },
        },
    },
    {
        title = "World Map",
        rows = {
            { key = "showMapPins", label = "Show Waypoint Pins", tip = "Draw a pin on the world map for every stored waypoint." },
            { key = "pulsePlayerOnMap", label = "Pulse Player Location", tip = "Pulse your character's pin on the world map." },
        },
    },
    {
        title = "HUD & Arrival",
        rows = {
            { key = "showHUD", label = "Enable HUD", tip = "Show the arrow HUD for the tracked waypoint." },
            { key = "lockHUD", label = "Lock HUD", tip = "Prevent dragging the HUD. Clicking it still works." },
            { key = "announceArrival", label = "Announce Arrival", tip = "Tell you when you reach the tracked waypoint." },
            { key = "untrackOnArrival", label = "Stop Tracking On Arrival", tip = "Clear the arrow once you arrive." },
            { key = "autoAdvanceTours", label = "Auto-advance Tours", tip = "Move to the next stop when you reach the current one." },
        },
    },
    {
        title = "Diagnostics",
        rows = {
            { key = "autoAuditOnLogin", label = "Auto-run Audit On Login", tip = "Run the tours audit at login." },
            { key = "debug", label = "Enable Debug Prints", tip = "Print internal diagnostics to chat." },
        },
    },
}

-- Enums, cycled by a button. Same shape the Gaps filter already uses, rather
-- than pulling in dropdown machinery for five settings.
local SETTING_CHOICES = {
    { key = "providerMode", label = "Provider", values = { "auto", "blizzard", "tomtom" },
      tip = "Which provider receives the tracked waypoint." },
    { key = "routeOptimizationMode", label = "Route Optimization", values = { "manual", "auto" },
      tip = "Auto reorders injected routes with nearest-neighbor + 2-opt." },
    { key = "mapClickCaptureModifier", label = "Track Modifier", values = { "ALT", "SHIFT", "CTRL" },
      tip = "Held while clicking Save Map Cursor to also track the new waypoint." },
    { key = "arrivalDistanceYards", label = "Arrival Radius", values = { 5, 10, 15, 20, 25, 35, 50, 75, 100 },
      tip = "How close counts as having arrived.", suffix = " yd" },
}

function MainFrame:BuildSettingsPanel(panel)
    panel.header = CreateSectionLabel(panel, "Odyssey Settings")
    panel.header:SetPoint("TOPLEFT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -26)
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    BindScrollChild(scroll, content)
    panel.scroll = scroll
    panel.content = content

    panel.checkboxes = {}
    panel.choiceButtons = {}

    local y = -4
    for _, section in ipairs(SETTING_SECTIONS) do
        local heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 4, y)
        heading:SetText("|cff4fb8e8" .. section.title .. "|r")
        y = y - 22

        for _, row in ipairs(section.rows) do
            local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            check:SetSize(22, 22)
            check:SetPoint("TOPLEFT", 12, y)

            local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", check, "RIGHT", 4, 0)
            label:SetText(row.label)

            check:SetScript("OnClick", function(button)
                O.db.settings[row.key] = button:GetChecked() and true or false
                O:MarkDirty()
                self:OnSettingChanged(row.key)
            end)
            AddButtonTooltip(check, row.tip or row.label)

            panel.checkboxes[row.key] = check
            y = y - 24
        end
        y = y - 8
    end

    local choiceHeading = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    choiceHeading:SetPoint("TOPLEFT", 4, y)
    choiceHeading:SetText("|cff4fb8e8Choices|r")
    y = y - 22

    for _, choice in ipairs(SETTING_CHOICES) do
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 12, y - 6)
        label:SetWidth(150)
        label:SetJustifyH("LEFT")
        label:SetText(choice.label)

        local button = CreateButton(content, "", 110, 22, function(btn)
            local current = O.db.settings[choice.key]
            local nextValue = choice.values[1]
            for index, value in ipairs(choice.values) do
                if value == current then
                    nextValue = choice.values[(index % #choice.values) + 1]
                    break
                end
            end
            O.db.settings[choice.key] = nextValue
            O:MarkDirty()
            btn:SetText(tostring(nextValue) .. (choice.suffix or ""))
            self:OnSettingChanged(choice.key)
        end)
        button:SetPoint("TOPLEFT", 170, y)
        AddButtonTooltip(button, choice.tip or choice.label)

        panel.choiceButtons[choice.key] = button
        y = y - 26
    end

    y = y - 12
    panel.resetButton = CreateButton(content, "Reset Window Size", 150, 22, function()
        self.frame:SetSize(900, 620)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER")
        self:SaveWindowState()
        self:RefreshAll()
    end)
    panel.resetButton:SetPoint("TOPLEFT", 12, y)
    y = y - 30

    panel.contentHeight = math.abs(y) + 10
end

-- Side effects a setting needs beyond being stored.
function MainFrame:OnSettingChanged(key)
    if key == "showHUD" or key == "showSourceLabels" then
        if O.UI.HUD then O.UI.HUD:Refresh() end
    elseif key == "lockHUD" then
        if O.UI.HUD then O.UI.HUD:RefreshLockState() end
    elseif key == "showMapPins" then
        if O.UI.MapPins then O.UI.MapPins:Render() end
    elseif key == "pulsePlayerOnMap" then
        if O.UI.MapPins then
            if O.db.settings.pulsePlayerOnMap then
                O.UI.MapPins:StartPulse()
            else
                O.UI.MapPins:StopPulse()
            end
        end
    elseif key == "showWorldMapButton" or key == "mapClickCaptureEnabled" or key == "mapClickCaptureModifier" then
        if O.RefreshWorldMapButtons then O:RefreshWorldMapButtons() end
    elseif key == "arrivalDistanceYards" then
        O.db.settings.arrivalDistanceYards =
            math.max(5, math.min(100, math.floor(tonumber(O.db.settings.arrivalDistanceYards) or 25)))
    end

    if key == "showDistance" or key == "showETA" or key == "showSourceLabels" then
        self:RefreshWaypointsPanel()
    end
end

function MainFrame:RefreshSettingsPanel()
    local panel = self.panels.Settings
    if not panel or not panel.checkboxes then
        return
    end

    SyncScrollChild(panel.scroll, panel.content)

    for key, check in pairs(panel.checkboxes) do
        check:SetChecked(O.db.settings[key] and true or false)
    end

    for key, button in pairs(panel.choiceButtons) do
        local value = O.db.settings[key]
        local suffix = ""
        for _, choice in ipairs(SETTING_CHOICES) do
            if choice.key == key then
                suffix = choice.suffix or ""
                break
            end
        end
        button:SetText(tostring(value == nil and "?" or value) .. suffix)
    end

    panel.content:SetHeight(math.max(1, panel.contentHeight or 1))
end

function MainFrame:RefreshGapsPanel()
    local panel = self.panels.Gaps
    if not panel then return end

    SyncScrollChild(panel.scroll, panel.content)

    local filter = panel._statusFilter or "Open"
    local allGaps = O.db.gaps
    local counts = { Open = 0, Done = 0, Deferred = 0 }
    local visible = {}
    for _, gap in ipairs(allGaps) do
        counts[gap.status] = (counts[gap.status] or 0) + 1
        if filter == "All" or gap.status == filter then
            visible[#visible + 1] = gap
        end
    end

    if panel.summaryText then
        panel.summaryText:SetText(string.format(
            "|cffff8888%d open|r  |cff88ff88%d done|r  |cffaaaaaa%d deferred|r  — %d total",
            counts.Open, counts.Done, counts.Deferred, #allGaps))
    end

    local yOffset = 0
    for index, gap in ipairs(visible) do
        local row = panel.rows[index]
        if not row then
            row = CreateFrame("Button", nil, panel.content)
            row:SetHeight(ROW_HEIGHT)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", 4, 0)
            row.text:SetWidth(500)
            row.text:SetJustifyH("LEFT")
            row.toggleButton = CreateButton(row, "Done", 44, 20)
            row.toggleButton:SetPoint("RIGHT", -48, 0)
            row.deleteButton = CreateButton(row, "X", 20, 20)
            row.deleteButton:SetPoint("RIGHT", -22, 0)
            panel.rows[index] = row
        end

        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", 0, -yOffset)

        local priColor = PRIORITY_COLORS[gap.priority] or ""
        local sColor   = STATUS_COLORS[gap.status]   or ""
        row.text:SetText(string.format("%s[%s]|r %s[%s]|r #%d %s",
            priColor, gap.priority, sColor, gap.status, gap.id, gap.title))
        row:Show()

        row.toggleButton:SetText(gap.status == "Done" and "Reopen" or "Done")
        row.toggleButton:SetScript("OnClick", function()
            O.Modules.Gaps:Update(gap.id, { status = gap.status == "Done" and "Open" or "Done" })
        end)
        row.deleteButton:SetScript("OnClick", function()
            O.Modules.Gaps:Remove(gap.id)
        end)

        yOffset = yOffset + ROW_HEIGHT
    end

    for index = #visible + 1, #panel.rows do
        panel.rows[index]:Hide()
    end
    panel.content:SetHeight(math.max(1, yOffset))
end
