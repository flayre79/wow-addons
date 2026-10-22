local K = Kleos
K.UI = K.UI or {}
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI — window shell and tab host
--
-- The shell comes from FabledUI_UIToolkit (Shell:CreateWindow) when the toolkit
-- is loaded: that gives the suite-standard chrome plus WindowState persistence
-- for free. When it is absent the hand-rolled CCM-derived chrome below is used
-- instead. Both paths publish the same fields, so nothing downstream needs to
-- know which one built the window:
--
--   frame.body            content container the tabs are parented to
--   frame.resize          resize grip
--   frame.lockButton      Kleos-specific lock toggle
--   frame.minimizeButton  minimize / roll-up
--
-- Tab panels are built by the UI_* modules, which register themselves into
-- U.builders / U.renderers. Panels are built lazily on first selection so
-- opening the window does not construct nine tabs' worth of frames.
-- ============================================================================

U.builders = U.builders or {}
U.renderers = U.renderers or {}
U.internalTabFrames = U.internalTabFrames or {}
U.internalTabButtons = U.internalTabButtons or {}

-- Tab order. `mode` marks the tabs served by the shared browse panel.
U.TABS = {
    { key = "BROWSE",   label = "BROWSE",   mode = "ALL" },
    { key = "WATCH",    label = "WATCH",    mode = "WATCH" },
    { key = "TRACKED",  label = "TRACKED",  mode = "TRACKED" },
    { key = "EXCLUDED", label = "EXCLUDED", mode = "EXCLUDED" },
    { key = "CURATED",  label = "SPECIALS", mode = "CURATED" },
    { key = "REWARDS",  label = "REWARDS" },
    { key = "SUMMARY",  label = "SUMMARY" },
    { key = "CALENDAR", label = "CALENDAR" },
    { key = "DATA",     label = "DATA" },
}

local TAB_WIDTH = 96
local TAB_GAP = 3

local function Filters()
    return (K.GetFilters and K:GetFilters()) or {}
end

U.Filters = Filters

local function IsLocked()
    return K.db and K.db.settings and K.db.settings.lockFrames == true
end

local function IsMinimized()
    return K.db and K.db.settings and K.db.settings.main and K.db.settings.main.minimized == true
end

local function WindowStateTable()
    K.db.settings.main = K.db.settings.main or {}
    K.db.settings.main.windowState = K.db.settings.main.windowState or { width = 1040, height = 700 }
    return K.db.settings.main.windowState
end

-- ----------------------------------------------------------------------------
-- Lock button (both chrome paths)
-- ----------------------------------------------------------------------------
local function PickFirstTexture(candidates, fallback)
    local function TexturePathExists(path)
        if type(GetFileIDFromPath) ~= "function" then return false end
        local fileID = GetFileIDFromPath(path)
        return fileID and fileID ~= -2
    end
    for _, path in ipairs(candidates) do
        if TexturePathExists(path) then return path end
    end
    return fallback
end

local LOCK_CANDIDATES = {
    "Interface/Buttons/LockButton-Locked-Up",
    "Interface/Buttons/UI-LockButton-Locked-Up",
    "Interface/Buttons/UI-LockButton-Locked",
    "Interface/Buttons/LockButton-Locked",
    "Interface/Buttons/UI-Panel-LockButton-Up",
}
local UNLOCK_CANDIDATES = {
    "Interface/Buttons/LockButton-Unlocked-Up",
    "Interface/Buttons/UI-LockButton-Unlocked-Up",
    "Interface/Buttons/UI-LockButton-Unlocked",
    "Interface/Buttons/LockButton-Unlocked",
    "Interface/Buttons/UI-Panel-UnlockButton-Up",
}
local FALLBACK_LOCK = "Interface/Icons/INV_Misc_Lockbox_01"
local FALLBACK_UNLOCK = "Interface/Icons/INV_Misc_Key_13"

local function ApplyLockIconTexCoord(icon, texture)
    if not icon or not texture then return end
    icon:SetTexture(texture)
    if texture:find("Interface/Icons/") then
        icon:SetTexCoord(0.11, 0.89, 0.11, 0.89)
    elseif texture:find("UI%-Panel%-LockButton") or texture:find("UI%-Panel%-UnlockButton") then
        icon:SetTexCoord(0.23, 0.77, 0.23, 0.77)
    elseif texture:find("LockButton") or texture:find("UnlockButton") or texture:find("UI%-LockButton") then
        icon:SetTexCoord(0.17, 0.83, 0.17, 0.83)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function AttachLockButton(frame, parent, anchorTo, size)
    local lockButton = CreateFrame("Button", nil, parent)
    lockButton:SetSize(size, size)
    if anchorTo then
        lockButton:SetPoint("RIGHT", anchorTo, "LEFT", -4, 0)
    else
        lockButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -4)
    end
    lockButton:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
    lockButton.icon = lockButton:CreateTexture(nil, "ARTWORK")
    lockButton.icon:SetAllPoints(lockButton)

    local lockTexture = PickFirstTexture(LOCK_CANDIDATES, FALLBACK_LOCK)
    local unlockTexture = PickFirstTexture(UNLOCK_CANDIDATES, FALLBACK_UNLOCK)

    function frame:ApplyLockState()
        local locked = IsLocked()
        ApplyLockIconTexCoord(lockButton.icon, locked and lockTexture or unlockTexture)
        if self.titleButton then self.titleButton:EnableMouse(not locked) end
        if self.resize then
            local hide = locked or IsMinimized()
            if hide then
                self.resize:Hide(); self.resize:EnableMouse(false)
            else
                self.resize:Show(); self.resize:EnableMouse(true)
            end
        end
        -- Toolkit shell drags from the frame itself.
        if self._shellDrag ~= nil then
            self:SetMovable(not locked)
        end
    end

    lockButton:SetScript("OnClick", function()
        K.db.settings.lockFrames = not IsLocked()
        frame:ApplyLockState()
        K.Storage:CommitSoon()
    end)
    lockButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(IsLocked() and (K.L.UNLOCK_WINDOW or "Unlock window") or (K.L.LOCK_WINDOW or "Lock window"), 1, 1, 1)
        GameTooltip:AddLine(K.L.LOCK_HINT or "When locked, the window cannot be moved or resized.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    lockButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.lockButton = lockButton
    return lockButton
end

-- ----------------------------------------------------------------------------
-- Toolkit shell
-- ----------------------------------------------------------------------------
local function BuildToolkitShell()
    local TK = W:Toolkit()
    if not (TK and TK.Shell and TK.Shell.CreateWindow) then return nil end

    local state = WindowStateTable()
    local ok, frame = pcall(function()
        return TK.Shell:CreateWindow("FabledUI_KleosMain", {
            title = K.L.ADDON_NAME or "FabledUI - Kleos",
            subtitle = K.L.SUBTITLE or "",
            theme = W.THEME,
            accentColor = W.ACCENT,
            width = state.width or 1040,
            height = state.height or 700,
            minWidth = 900,
            minHeight = 520,
            state = state,
            ribbon = false,
        })
    end)
    if not ok or not frame then return nil end

    frame.body = frame.Content
    frame.resize = frame.ResizeButton
    frame.minimizeButton = frame.MinimizeButton
    frame._shellDrag = true
    frame._toolkitShell = true

    AttachLockButton(frame, frame.HeaderButtons or frame.TitleBar or frame,
        frame.MinimizeButton, 18)

    -- The header button row is sized for two buttons; widen it for three.
    if frame.HeaderButtons and frame.HeaderButtons.SetWidth then
        frame.HeaderButtons:SetWidth(110)
    end

    return frame
end

-- ----------------------------------------------------------------------------
-- Fallback chrome (CCM lift: title drag overlay, lock/minimize/close cluster,
-- resize handle). Used when the toolkit is not installed.
-- ----------------------------------------------------------------------------
local function SaveFramePosition(frame)
    if not frame or not K.db or not K.db.settings or not K.db.settings.main then return end
    local centerX, centerY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if centerX and centerY and parentX and parentY then
        K.db.settings.main.x = math.floor(centerX - parentX + 0.5)
        K.db.settings.main.y = math.floor(centerY - parentY + 0.5)
    end
end

local function BuildFallbackChrome()
    local frame = W:Panel(UIParent, "FabledUI_KleosMain")

    local settings = K.db.settings.main
    frame:SetSize(settings.w or 1040, settings.h or 700)
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.x or 0, settings.y or 0)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    frame:SetResizable(true)
    -- Drag is owned by the title overlay, not the frame.
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    tinsert(UISpecialFrames, "FabledUI_KleosMain")

    frame.title = W:Label(frame, "|cff4fd1c5" .. (K.L.ADDON_NAME or "FabledUI - Kleos") .. "|r", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 12, -10)
    if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end

    local titleButton = CreateFrame("Button", nil, frame)
    frame.titleButton = titleButton
    titleButton:SetHeight(24)
    titleButton:EnableMouse(true)
    titleButton:RegisterForClicks("AnyUp")
    titleButton:RegisterForDrag("LeftButton")
    titleButton:SetFrameLevel(frame:GetFrameLevel() + 1)
    titleButton:SetScript("OnDragStart", function()
        if IsLocked() then return end
        frame:StartMoving()
        frame._kleosMoving = true
    end)
    titleButton:SetScript("OnDragStop", function()
        if frame._kleosMoving then
            frame:StopMovingOrSizing()
            frame._kleosMoving = false
            SaveFramePosition(frame)
        end
    end)
    titleButton:SetScript("OnHide", function()
        if frame._kleosMoving then
            frame:StopMovingOrSizing()
            frame._kleosMoving = false
        end
    end)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeButton:SetFrameLevel((titleButton:GetFrameLevel() or frame:GetFrameLevel()) + 1)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    local TK = W:Toolkit()
    if TK and TK.Themes and TK.Themes.StyleCloseButton then TK.Themes:StyleCloseButton(closeButton) end
    frame.closeButton = closeButton

    local minimizeButton = W:Button(frame, "+ / -", 40, 18)
    frame.minimizeButton = minimizeButton
    minimizeButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    minimizeButton:SetFrameLevel((titleButton:GetFrameLevel() or frame:GetFrameLevel()) + 1)

    AttachLockButton(frame, frame, minimizeButton, 18)
    local lockButton = frame.lockButton
    lockButton:SetFrameLevel(minimizeButton:GetFrameLevel())

    titleButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    titleButton:SetPoint("TOPRIGHT", lockButton, "TOPLEFT", -4, 0)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    frame.title:SetPoint("TOPRIGHT", lockButton, "TOPLEFT", -4, -2)

    local body = CreateFrame("Frame", nil, frame)
    frame.body = body
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -32)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    body:SetClipsChildren(true)

    if frame.SetResizeBounds then frame:SetResizeBounds(900, 520, 1600, 1200) end

    local ok, resize = pcall(CreateFrame, "Button", nil, frame, "PanelResizeButtonTemplate")
    if ok and resize then
        resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        if resize.Init then pcall(resize.Init, resize, frame, 900, 520, 1600, 1200) end
        if resize.SetOnResizeStoppedCallback then
            resize:SetOnResizeStoppedCallback(function()
                K.db.settings.main.w = math.floor(frame:GetWidth() + 0.5)
                K.db.settings.main.h = math.floor(frame:GetHeight() + 0.5)
                SaveFramePosition(frame)
                U:OnResized()
            end)
        end
    else
        resize = CreateFrame("Button", nil, frame)
        resize:SetSize(16, 16)
        resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        resize:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
        resize:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
        resize:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
        resize:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" and not IsLocked() and not IsMinimized() then
                frame:StartSizing("BOTTOMRIGHT")
            end
        end)
        resize:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            K.db.settings.main.w = math.floor(frame:GetWidth() + 0.5)
            K.db.settings.main.h = math.floor(frame:GetHeight() + 0.5)
            SaveFramePosition(frame)
            U:OnResized()
        end)
    end
    frame.resize = resize

    function frame:ApplyMinimizedState()
        local minimized = IsMinimized()
        local topBefore = self:GetTop()
        if minimized then
            body:Hide()
            self:SetHeight(78)
        else
            body:Show()
            self:SetHeight(K.db.settings.main.h or 700)
        end
        self:ApplyLockState()
        local topAfter = self:GetTop()
        if topBefore and topAfter and math.abs(topAfter - topBefore) > 0.001 then
            local point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint()
            self:ClearAllPoints()
            self:SetPoint(point or "CENTER", relativeTo or UIParent, relativePoint or "CENTER",
                xOffset or 0, (yOffset or 0) + (topBefore - topAfter))
            SaveFramePosition(self)
        end
    end

    minimizeButton:SetScript("OnClick", function()
        K.db.settings.main.minimized = not IsMinimized()
        frame:ApplyMinimizedState()
    end)

    frame:ApplyLockState()
    return frame
end

-- ----------------------------------------------------------------------------
-- Tab bar
-- ----------------------------------------------------------------------------
function U:BuildTabBar(parent)
    local tabBar = CreateFrame("Frame", nil, parent)
    tabBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    tabBar:SetHeight(24)

    local underline = tabBar:CreateTexture(nil, "ARTWORK")
    underline:SetColorTexture(0.5, 0.5, 0.5, 0.3)
    underline:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", 0, -1)
    underline:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", 0, -1)
    underline:SetHeight(1)

    local x = 0
    for _, tab in ipairs(self.TABS) do
        local button = W:Button(tabBar, K.L[tab.label] or tab.label, TAB_WIDTH, 22, function()
            U:SelectInternalTab(tab.key)
        end)
        button:SetPoint("LEFT", tabBar, "LEFT", x, 0)
        button:SetScript("OnEnter", function(self)
            local binding = U:BindingKeyForTab(tab.key)
            if not binding then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText((K.L[tab.label] or tab.label) .. "  |cffffd100" .. binding .. "|r", 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.internalTabButtons[tab.key] = button
        x = x + TAB_WIDTH + TAB_GAP
    end

    self.internalTabBar = tabBar
    return tabBar
end

function U:EnsureInternalTabsUI()
    if self._internalTabsBuilt then return end
    if not self.frame or not self.frame.body then return end

    local parent = self.frame.body
    self:BuildTabBar(parent)

    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT", self.internalTabBar, "BOTTOMLEFT", 0, -6)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.internalTabContent = content

    for _, tab in ipairs(self.TABS) do
        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints(content)
        panel:Hide()
        panel._tabKey = tab.key
        panel._mode = tab.mode
        self.internalTabFrames[tab.key] = panel
    end

    -- ZONE reuses the specials panel; register the alias so Refresh("ZONE")
    -- and the world-map button have somewhere to draw.
    self.internalTabFrames.ZONE = self.internalTabFrames.CURATED

    self._internalTabsBuilt = true

    local startTab = (K.db and K.db.settings and K.db.settings.filters and K.db.settings.filters.tab) or "BROWSE"
    if not self.internalTabFrames[startTab] then startTab = "BROWSE" end
    self:SelectInternalTab(startTab)
end

function U:EnsurePanelBuilt(key)
    local panel = self.internalTabFrames[key]
    if not panel then return nil end
    if panel._built then return panel end
    panel._built = true
    local builder = self.builders[key]
    if builder then
        K:SafeCall(function() builder(self, panel, panel._mode or key) end)
    else
        local label = W:Label(panel, (K.L[key] or key) .. " — " .. (K.L.UNKNOWN or "not available"), "GameFontDisableLarge", "CENTER")
        label:SetPoint("TOP", 0, -40)
    end
    return panel
end

function U:SelectInternalTab(key)
    if not self.internalTabFrames or not self.internalTabFrames[key] then return end

    self.activeInternalTab = key
    local filters = Filters()
    if filters then filters.tab = key end
    if self.frame then self.frame.tab = key end

    self:EnsurePanelBuilt(key)

    for tabKey, panel in pairs(self.internalTabFrames) do
        if panel and panel.Show and panel.Hide then
            -- ZONE aliases CURATED, so compare the panel's own key.
            if panel._tabKey == key then panel:Show() else panel:Hide() end
        end
    end

    for tabKey, button in pairs(self.internalTabButtons) do
        if button and button.SetEnabled then button:SetEnabled(tabKey ~= key) end
    end

    self:RenderTab(key)
    K.Storage:CommitSoon()
end

function U:RenderTab(key)
    local renderer = self.renderers[key]
    local panel = self.internalTabFrames[key]
    if renderer and panel then
        K:SafeCall(function() renderer(self, panel, panel._mode or key) end)
    end
end

function U:Refresh()
    if not self.frame then return end
    local key = self.activeInternalTab or self.frame.tab or "BROWSE"
    self:RenderTab(key)
end

function U:OnResized()
    if not self.frame then return end
    self:Refresh()
end

function U:OnCategoriesChanged()
    if not self.frame then return end
    if self.activeInternalTab == "CURATED" or self.activeInternalTab == "BROWSE" then self:Refresh() end
end

-- Legacy render entry points. The old UI exposed one function per tab and the
-- criteria/tracker modules still call them.
function U:RenderWatch() self:RenderTab("WATCH") end
function U:RenderCurated() self:RenderTab("CURATED") end
function U:RenderExcluded() self:RenderTab("EXCLUDED") end
function U:RenderBrowse() self:RenderTab("BROWSE") end

-- ----------------------------------------------------------------------------
-- Init / visibility
-- ----------------------------------------------------------------------------
function U:Init()
    if self.frame then return end

    local frame = BuildToolkitShell() or BuildFallbackChrome()
    self.frame = frame
    frame.tab = (K.db and K.db.settings and K.db.settings.filters and K.db.settings.filters.tab) or "BROWSE"
    frame:Hide()

    self:EnsureInternalTabsUI()
    if frame.ApplyMinimizedState then frame:ApplyMinimizedState() end
    if K.Skins then K:SafeCall(function() K.Skins:Apply(frame) end) end
end

function U:Show()
    if not self.frame then self:Init() end
    if self.frame.ShowExpanded then self.frame:ShowExpanded() else self.frame:Show() end
    self:Refresh()
    if K.Tutorial then K:SafeCall(function() K.Tutorial:MaybeShow() end) end
end

function U:Hide()
    if not self.frame then return end
    if self.frame.HideShell then self.frame:HideShell() else self.frame:Hide() end
end

function U:IsShown()
    if not self.frame then return false end
    if self.frame.IsShellVisible then return self.frame:IsShellVisible() and true or false end
    return self.frame:IsShown() and true or false
end

function U:Toggle()
    if not self.frame then self:Init() end
    if self:IsShown() then self:Hide() else self:Show() end
end

-- Jump straight to an achievement: used by the API, the tooltip links and the
-- tracker rows.
function U:ShowAchievement(id)
    id = tonumber(id)
    if not id then return false end
    if not self.frame then self:Init() end
    self:Show()
    self:SelectInternalTab("BROWSE")
    local panel = self.internalTabFrames.BROWSE
    if panel then
        self:SelectAchievement(id, panel)
        if self.FocusAchievement then self:FocusAchievement(id, panel) end
    end
    return true
end

function U:SelectAchievement(id, panel)
    panel = panel or (self.internalTabFrames and self.internalTabFrames[self.activeInternalTab or "BROWSE"])
    if not panel then return end
    if self.RenderDetail then self:RenderDetail(panel, id) end
end

-- ----------------------------------------------------------------------------
-- Keybindable tabs
-- ----------------------------------------------------------------------------
U.BINDING_TABS = { "BROWSE", "WATCH", "REWARDS", "SUMMARY" }

function U:BindingKeyForTab(key)
    if type(GetBindingKey) ~= "function" then return nil end
    for index, tabKey in ipairs(self.BINDING_TABS) do
        if tabKey == key then
            local binding = GetBindingKey("FABLEDUI_KLEOS_TAB" .. index)
            if binding and binding ~= "" then return binding end
        end
    end
    return nil
end

function U:SelectTabByIndex(index)
    local key = self.BINDING_TABS[tonumber(index) or 0]
    if not key then return false end
    if not self.frame then self:Init() end
    if not self:IsShown() then self:Show() end
    self:SelectInternalTab(key)
    return true
end

function U:CycleTab(step)
    if not self.frame then self:Init() end
    if not self:IsShown() then self:Show() end
    local current = self.activeInternalTab or "BROWSE"
    local position = 1
    for index, tab in ipairs(self.TABS) do
        if tab.key == current then position = index end
    end
    position = position + (tonumber(step) or 1)
    if position < 1 then position = #self.TABS end
    if position > #self.TABS then position = 1 end
    self:SelectInternalTab(self.TABS[position].key)
    return true
end

-- ----------------------------------------------------------------------------
-- Reminder toast
-- A small self-dismissing panel; the reminder text also goes to chat so the
-- information is not lost if the toast is missed.
-- ----------------------------------------------------------------------------
function U:ShowReminderToast(rows)
    if type(rows) ~= "table" or #rows == 0 then return end

    local toast = self._toast
    if not toast then
        toast = W:Panel(UIParent, "FabledUI_KleosReminder")
        toast:SetSize(320, 90)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -180)
        toast:SetFrameStrata("DIALOG")
        toast:EnableMouse(true)
        toast:SetScript("OnMouseDown", function(self) self:Hide() end)

        toast.title = W:Label(toast, "", "GameFontNormalLarge")
        toast.title:SetPoint("TOPLEFT", 12, -10)

        toast.body = W:Label(toast, "", "GameFontHighlightSmall")
        toast.body:SetPoint("TOPLEFT", 12, -34)
        toast.body:SetPoint("TOPRIGHT", -12, -34)
        toast.body:SetJustifyH("LEFT")

        toast.open = W:Button(toast, K.L.OPEN_ACTION or "Open", 90, 20, function()
            toast:Hide()
            U:Show()
            U:SelectInternalTab("BROWSE")
        end)
        toast.open:SetPoint("BOTTOMRIGHT", -10, 8)

        self._toast = toast
    end

    local lines = {}
    for index, row in ipairs(rows) do
        if index > 3 then break end
        local suffix = row.outstanding and row.outstanding > 0 and ((" — %d %s"):format(row.outstanding, K.L.INCOMPLETE or "incomplete")) or ""
        lines[#lines + 1] = ("%s (%s)%s"):format(row.name, row.state == "ACTIVE" and (K.L.ACTIVE or "active") or ("+" .. tostring(row.daysUntil or 0) .. "d"), suffix)
    end

    toast.title:SetText("|cffffd100" .. (K.L.EVENTS or "Events") .. "|r")
    toast.body:SetText(table.concat(lines, "\n"))
    toast:Show()

    if C_Timer and C_Timer.After then
        C_Timer.After(20, function() if toast then toast:Hide() end end)
    end
end

-- ----------------------------------------------------------------------------
-- World map button
-- ----------------------------------------------------------------------------
function U:InitWorldMapButton()
    if self._mapButton then return end
    if not WorldMapFrame then return end

    -- Blizzard reshuffles WorldMap chrome between patches, so fall through to
    -- whatever exists rather than crashing when MaximizeMinimizeFrame goes away.
    local anchor = (WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame)
                or WorldMapFrame.BorderFrame
                or WorldMapFrame
    local parent = WorldMapFrame.BorderFrame or WorldMapFrame

    -- Named frame: the keybind help and other addons look this button up.
    local button = CreateFrame("Button", "KleosWorldMapButton", parent, "UIPanelButtonTemplate")
    W:StyleButton(button)
    button:SetSize(100, 22)
    button:SetText("Kleos")
    button:SetScript("OnClick", function()
        local mapID = WorldMapFrame:GetMapID()
        if not mapID then K:Print(K.L.NO_ZONE or "No map zone selected."); return end
        self:ShowZoneAchievements(mapID)
    end)
    button:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, -2)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Kleos: " .. (K.L.SELECTED_ZONE or "Selected Zone"))
        GameTooltip:AddLine(K.L.ZONE_BUTTON_HINT or "Show achievements for the current map zone.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self._mapButton = button
end

-- Zone achievements: matched through the catalog's category tree so the result
-- respects the same expansion/kind classification as every other list.
function U:ShowZoneAchievements(mapID)
    if not self.frame then self:Init() end

    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or ("Zone " .. tostring(mapID))

    K.Catalog:Build()
    local found = {}
    local wanted = zoneName:lower()
    for catID, node in pairs(K.Catalog.categories) do
        local name = type(node.name) == "string" and node.name:lower() or nil
        if name and (name == wanted or name:find(wanted, 1, true)) then
            for _, id in ipairs(K.Catalog.order) do
                local entry = K.Catalog.entries[id]
                if entry and entry.category == catID then found[#found + 1] = id end
            end
        end
    end

    if #found == 0 then
        K:Print((K.L.NO_ZONE_RESULTS or "No achievements found for %s."):format(zoneName))
        return
    end

    K.Data._zoneResults = found
    K.Data._zoneName = zoneName
    self:Show()
    self:SelectInternalTab("CURATED")
    self:RenderTab("ZONE")

    K:Print(("%d %s: %s"):format(#found, K.L.ACHIEVEMENTS or "achievements", zoneName))
end
