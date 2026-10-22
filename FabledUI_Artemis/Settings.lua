local A = FabledUI_Artemis or Artemis

A.Settings = A.Settings or {}
local S = A.Settings

local TAB_ORDER = { "general", "wq", "odyssey", "checklist", "currency", "modules" }
local TAB_LABELS = {
    general = "General",
    wq = "World Quests",
    odyssey = "Odyssey",
    checklist = "Checklist",
    currency = "Currency",
    modules = "Modules",
}

local THEME = "FableNeon"
local ACCENT = { 0.227, 0.914, 1.0, 1.0 }  -- cyan, matches the Artemis tracker
local WINDOW_NAME = "FabledUI_ArtemisSettings"

local function GetToolkit()
    return rawget(_G, "FabledUI_UIToolkit")
end

local function StyleButton(button)
    local T = GetToolkit()
    if T and T.Themes and type(T.Themes.StyleFlatButton) == "function" then
        T.Themes:StyleFlatButton(button, THEME, ACCENT)
    end
end

local function MakeSection(parent, titleText, helpText, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetWidth(width)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.03, 0.03, 0.03, 0.60)
        frame:SetBackdropBorderColor(0.35, 0.28, 0.10, 0.95)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText(titleText)
    frame.titleText = title

    if helpText then
        local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        help:SetWidth(width - 24)
        help:SetJustifyH("LEFT")
        help:SetJustifyV("TOP")
        help:SetText(helpText)
        frame.helpText = help
    end

    return frame
end

local function MakePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    page.scroll = scroll
    page.content = content
    return page
end

local function SetPageHeight(page, height)
    if page and page.content then
        page.content:SetHeight(math.max(1, height or 1))
    end
end

local function MakeCheck(parent, label, get, set, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    -- Pin the box to 24px so the row step matches the section-height math
    -- (48 + n*28 + 12) and the last checkboxes don't spill outside the card.
    cb:SetSize(24, 24)
    cb.Text:SetText(label)
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked())
    end)
    cb:SetScript("OnShow", function(self)
        self:SetChecked(get())
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    return cb
end

local function MakeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 220, 24)
    button:SetText(text)
    StyleButton(button)
    button:SetScript("OnClick", onClick)
    return button
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

function S:EnsureDefaults()
    A.db = A.db or {}
    A.db.settingsWindow = A.db.settingsWindow or {}
    self.activeTab = self.activeTab or "general"
end

-- Deliberately does NOT register a Blizzard settings category. Binding
-- SavedVariables into Blizzard settings tainted this suite, which is the whole
-- reason Artemis moved to a standalone FableNeon window.
function S:Register()
    self:EnsureDefaults()
end

function S:Open()
    local frame = self:BuildShell()
    if not frame then
        return false
    end
    self:RefreshAll()
    frame:ShowExpanded()
    return true
end

-- ---------------------------------------------------------------------------
-- Shell
-- ---------------------------------------------------------------------------

function S:BuildShell()
    if self.window then
        return self.window
    end

    self:EnsureDefaults()

    local T = GetToolkit()
    if not T or not T.Shell or type(T.Shell.CreateWindow) ~= "function" then
        A:Print("FabledUI_UIToolkit is required for Artemis settings.")
        return nil
    end

    local frame = T.Shell:CreateWindow(WINDOW_NAME, {
        title = "FabledUI - Artemis",
        subtitle = "Tracker settings - no Blizzard options detour.",
        theme = THEME,
        accentColor = ACCENT,
        width = 820,
        height = 640,
        minWidth = 720,
        minHeight = 520,
        maxWidth = 1500,
        maxHeight = 1200,
        state = A.db.settingsWindow,
        ribbon = false,
        resizable = true,
    })

    self.window = frame
    self.pages = {}
    self.tabButtons = {}

    local content = frame.Content

    local tabs = CreateFrame("Frame", nil, content)
    tabs:SetPoint("TOPLEFT", 0, 0)
    tabs:SetPoint("TOPRIGHT", 0, 0)
    tabs:SetHeight(30)
    self.tabBar = tabs

    local last
    for _, key in ipairs(TAB_ORDER) do
        local button = CreateFrame("Button", nil, tabs, "UIPanelButtonTemplate")
        button:SetSize(118, 24)
        button:SetText(TAB_LABELS[key])
        StyleButton(button)
        if last then
            button:SetPoint("LEFT", last, "RIGHT", 8, 0)
        else
            button:SetPoint("TOPLEFT", 0, 0)
        end
        button:SetScript("OnClick", function()
            S:ShowTab(key)
        end)
        self.tabButtons[key] = button
        last = button
    end

    local pageHost = CreateFrame("Frame", nil, content)
    pageHost:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, -12)
    pageHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    self.pageHost = pageHost

    for _, key in ipairs(TAB_ORDER) do
        self.pages[key] = MakePage(pageHost)
    end

    self:BuildGeneralPage()
    self:BuildWorldQuestPage()
    self:BuildOdysseyPage()
    self:BuildChecklistPage()
    self:BuildCurrencyPage()
    self:BuildModulesPage()

    self:ShowTab(self.activeTab or "general")
    if frame.SetShellStatus then
        frame:SetShellStatus("Ready")
    end
    return frame
end

function S:ShowTab(tabKey)
    self.activeTab = tabKey
    for key, page in pairs(self.pages or {}) do
        page:SetShown(key == tabKey)
        if key == tabKey and page.scroll then
            page.scroll:SetVerticalScroll(0)
        end
    end
    for key, button in pairs(self.tabButtons or {}) do
        local active = key == tabKey
        button:SetEnabled(not active)
        if button.Left then button.Left:SetAlpha(active and 1 or 0.7) end
        if button.Middle then button.Middle:SetAlpha(active and 1 or 0.7) end
        if button.Right then button.Right:SetAlpha(active and 1 or 0.7) end
    end
    if tabKey == "modules" then
        self:RefreshModuleStatus()
    end
end

function S:RefreshAll()
    self:EnsureDefaults()
    self:RefreshModuleStatus()
end

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------

function S:BuildGeneralPage()
    local page = self.pages.general
    local content = page.content
    local width = 760
    local y = 0

    local section = MakeSection(content, "General",
        "Core Artemis tracker behavior and what the tracker window shows.", width)
    section:SetPoint("TOPLEFT", 8, -y)

    local left = 18
    local top = -48
    local step = -28

    local checks = {
        {
            label = "Enable Artemis",
            tooltip = "Shows or hides the Artemis tracker window.",
            get = function() return A.profile.enabled end,
            set = function(v)
                A.profile.enabled = v
                if A.Tracker then
                    if v then A.Tracker:Show() else A.Tracker:Hide() end
                end
            end,
        },
        {
            label = "Lock Tracker",
            tooltip = "Prevents dragging and resizing the tracker.",
            get = function() return A.profile.locked end,
            set = function(v) A.profile.locked = v end,
        },
        {
            label = "Hide Blizzard Tracker",
            tooltip = "Moves the default Objective Tracker off-screen while Artemis is active.",
            get = function() return A.profile.hideDefaultTracker end,
            set = function(v)
                A.profile.hideDefaultTracker = v
                if A.Tracker then A.Tracker:ManageDefaultTracker() end
            end,
        },
        {
            label = "Compact Mode",
            tooltip = "Reduces row heights and hides objective lines for a smaller footprint.",
            get = function() return A.profile.compactMode end,
            set = function(v)
                A.profile.compactMode = v
                if A.Tracker then A.Tracker:Refresh(true) end
            end,
        },
        {
            label = "Show Objectives",
            tooltip = "Displays quest objectives beneath each quest row.",
            get = function() return A.profile.showObjectives end,
            set = function(v)
                A.profile.showObjectives = v
                if A.Tracker then A.Tracker:Refresh(true) end
            end,
        },
        {
            label = "Show Completed Objectives",
            tooltip = "Keeps completed objective lines visible instead of hiding them.",
            get = function() return A.profile.showCompletedObjectives end,
            set = function(v)
                A.profile.showCompletedObjectives = v
                if A.Tracker then A.Tracker:Refresh(true) end
            end,
        },
        {
            label = "Show WQ Timers",
            tooltip = "Displays world quest expiration timers inside quest rows.",
            get = function() return A.profile.showWorldQuestTimers end,
            set = function(v)
                A.profile.showWorldQuestTimers = v
                if A.Tracker then A.Tracker:Refresh(true) end
            end,
        },
        {
            label = "Show Checklist",
            tooltip = "Displays checklist entries generated from templates and custom rules.",
            get = function() return A.profile.showChecklist end,
            set = function(v)
                A.profile.showChecklist = v
                if A.Tracker then A.Tracker:Refresh(true) end
            end,
        },
        {
            label = "Show Tracked Recipes",
            tooltip = "Displays profession recipes you have tracked, with a have/need count per required reagent. This is the Blizzard tracker's Professions section; turning it off while the Blizzard tracker is hidden means tracked recipes appear nowhere.",
            get = function() return A.Recipes and A.Recipes:IsSectionEnabled() or false end,
            set = function(v)
                if A.Recipes then
                    A.Recipes:SetSectionEnabled(v)
                    if A.Tracker then A.Tracker:Refresh(true) end
                end
            end,
        },
        {
            label = "Show Endeavors",
            tooltip = "Displays tracked Neighborhood Initiative tasks (endeavors) with a tick per completed requirement. This is the Blizzard tracker's endeavor section; turning it off while the Blizzard tracker is hidden means tracked endeavors appear nowhere. Reads only when the tracked list changes -- it never polls the housing API.",
            get = function() return A.Endeavors and A.Endeavors:IsSectionEnabled() or false end,
            set = function(v)
                if A.Endeavors then
                    A.Endeavors:SetSectionEnabled(v)
                    if A.Tracker then A.Tracker:Refresh(true) end
                end
            end,
        },
        {
            label = "Show Traveler's Log",
            tooltip = "Displays tracked Traveler's Log (monthly) activities with a tick per completed requirement. This is the Blizzard tracker's Monthly Activities section; turning it off while the Blizzard tracker is hidden means tracked activities appear nowhere. Track an activity from the Traveler's Log itself.",
            get = function() return A.Activities and A.Activities:IsSectionEnabled() or false end,
            set = function(v)
                if A.Activities then
                    A.Activities:SetSectionEnabled(v)
                    if A.Tracker then A.Tracker:Refresh(true) end
                end
            end,
        },
        {
            label = "Tooltip: Objectives",
            tooltip = "Hovering a quest lists its objectives, with a tick on the ones you have finished. Reads them on hover, so you do not have to expand the quest first.",
            get = function() return A.profile.tooltipShowObjectives ~= false end,
            set = function(v) A.profile.tooltipShowObjectives = v and true or false end,
        },
        {
            label = "Tooltip: Rewards",
            tooltip = "Hovering a quest shows its rewards -- money, currencies and items -- using Blizzard's own reward renderer, so it stays correct as reward types are added.",
            get = function() return A.profile.tooltipShowRewards ~= false end,
            set = function(v) A.profile.tooltipShowRewards = v and true or false end,
        },
        {
            label = "Tooltip: Quest ID",
            tooltip = "Adds the quest ID to the bottom of the tooltip. Off by default -- useful for bug reports and Wowhead lookups, noise the rest of the time.",
            get = function() return A.profile.tooltipShowID == true end,
            set = function(v) A.profile.tooltipShowID = v and true or false end,
        },
        {
            label = "Group by zone",
            tooltip = "Organize the tracker into one section per zone (current zone first) instead of by quest type. Same as the 'By Zone' toolbar toggle.",
            get = function() return A.profile.groupByZone end,
            set = function(v)
                A.profile.groupByZone = v
                if A.Tracker then A.Tracker:Refresh(true) end
            end,
        },
    }

    local last
    for _, info in ipairs(checks) do
        local cb = MakeCheck(section, info.label, info.get, info.set, info.tooltip)
        if last then
            cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
        else
            cb:SetPoint("TOPLEFT", left, top)
        end
        last = cb
    end

    -- Recover an off-screen / oversized tracker without needing /artemis reset.
    local resetBtn = MakeButton(section, "Reset Tracker Window", 200, function()
        if A.Tracker and A.Tracker.ResetWindow then
            A.Tracker:ResetWindow()
        end
    end)
    if last then
        resetBtn:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -14)
    else
        resetBtn:SetPoint("TOPLEFT", left, top)
    end

    -- Snap the tracker to a screen edge (at the top, so there's full height to resize).
    local anchorLeftBtn = MakeButton(section, "Anchor Left", 96, function()
        if A.Tracker and A.Tracker.AnchorToSide then A.Tracker:AnchorToSide("LEFT") end
    end)
    anchorLeftBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -8)
    local anchorRightBtn = MakeButton(section, "Anchor Right", 96, function()
        if A.Tracker and A.Tracker.AnchorToSide then A.Tracker:AnchorToSide("RIGHT") end
    end)
    anchorRightBtn:SetPoint("LEFT", anchorLeftBtn, "RIGHT", 8, 0)

    section:SetHeight(48 + (#checks * 28) + 96)
    y = y + section:GetHeight() + 12
    SetPageHeight(page, y)
end

-- ---------------------------------------------------------------------------
-- World Quests
-- ---------------------------------------------------------------------------

function S:BuildWorldQuestPage()
    local page = self.pages.wq
    local content = page.content
    local width = 760
    local y = 0

    local section = MakeSection(content, "World Quest Filters",
        "Filter which world quests reach the tracker by reward, remaining time, and tracked status.", width)
    section:SetPoint("TOPLEFT", 8, -y)

    local function GetFilters()
        A.profile.worldQuestFilters = A.profile.worldQuestFilters or {}
        return A.profile.worldQuestFilters
    end

    local function RewardLabel(key)
        if A.DataModel then
            return A.DataModel:GetWorldQuestRewardFilterLabel(key)
        end
        return tostring(key or "ALL")
    end

    local function TimeLabel(key)
        if A.DataModel then
            return A.DataModel:GetWorldQuestTimeFilterLabel(key)
        end
        return tostring(key or "ALL")
    end

    local rewardButton
    rewardButton = MakeButton(section, "Reward: " .. RewardLabel((A.profile.worldQuestFilters or {}).reward), 240, function(selfBtn)
        if not A.DataModel then return end
        local keys = A.DataModel:GetSortedRewardFilterKeys()
        local filters = GetFilters()
        local current = filters.reward or "ALL"
        local index = 1
        for i, key in ipairs(keys) do
            if key == current then
                index = i
                break
            end
        end
        local nextKey = keys[(index % #keys) + 1]
        filters.reward = nextKey
        selfBtn:SetText("Reward: " .. RewardLabel(nextKey))
        if A.Tracker then A.Tracker:Refresh(true) end
    end)
    rewardButton:SetPoint("TOPLEFT", 18, -48)

    local timeButton
    timeButton = MakeButton(section, "Time: " .. TimeLabel((A.profile.worldQuestFilters or {}).time), 240, function(selfBtn)
        if not A.DataModel then return end
        local keys = A.DataModel:GetSortedTimeFilterKeys()
        local filters = GetFilters()
        local current = filters.time or "ALL"
        local index = 1
        for i, key in ipairs(keys) do
            if key == current then
                index = i
                break
            end
        end
        local nextKey = keys[(index % #keys) + 1]
        filters.time = nextKey
        selfBtn:SetText("Time: " .. TimeLabel(nextKey))
        if A.Tracker then A.Tracker:Refresh(true) end
    end)
    timeButton:SetPoint("TOPLEFT", rewardButton, "BOTTOMLEFT", 0, -8)

    local trackedOnly
    trackedOnly = MakeCheck(section, "Tracked or Pinned Only",
        function() return (A.profile.worldQuestFilters or {}).trackedOnly == true end,
        function(v)
            local filters = GetFilters()
            filters.trackedOnly = v
            if A.Tracker then A.Tracker:Refresh(true) end
        end,
        "Only show world quests that are watched or manually pinned.")
    trackedOnly:SetPoint("TOPLEFT", timeButton, "BOTTOMLEFT", -2, -10)

    local resetButton = MakeButton(section, "Reset WQ Filters", 160, function()
        A.profile.worldQuestFilters = { reward = "ALL", time = "ALL", trackedOnly = false }
        if A.Tracker then A.Tracker:Refresh(true) end
        rewardButton:SetText("Reward: " .. RewardLabel("ALL"))
        timeButton:SetText("Time: " .. TimeLabel("ALL"))
        trackedOnly:SetChecked(false)
    end)
    resetButton:SetPoint("TOPLEFT", trackedOnly, "BOTTOMLEFT", 2, -12)

    section:SetHeight(190)
    y = y + section:GetHeight() + 12
    SetPageHeight(page, y)
end

-- ---------------------------------------------------------------------------
-- Odyssey
-- ---------------------------------------------------------------------------

function S:BuildOdysseyPage()
    local page = self.pages.odyssey
    local content = page.content
    local width = 760
    local y = 0

    local section = MakeSection(content, "Odyssey Routing",
        "Control how Artemis hands focus quests over to Odyssey and how routes are built.", width)
    section:SetPoint("TOPLEFT", 8, -y)

    local checkAutoRoute = MakeCheck(section, "Auto-route Focus",
        function() return A.profile.autoRouteFocusToOdyssey end,
        function(v) A.profile.autoRouteFocusToOdyssey = v end,
        "When a focus quest is set, Artemis sends it to Odyssey.")
    checkAutoRoute:SetPoint("TOPLEFT", 18, -48)

    local checkOpenMap = MakeCheck(section, "Open Map on Focus",
        function() return A.profile.odysseyOpenMapOnFocus end,
        function(v) A.profile.odysseyOpenMapOnFocus = v end,
        "Asks Odyssey to open the map when focus routing updates.")
    checkOpenMap:SetPoint("TOPLEFT", checkAutoRoute, "BOTTOMLEFT", 0, -4)

    local function RouteLabel(key)
        if A.DataModel then
            return A.DataModel:GetOdysseyRouteModeLabel(key)
        end
        return tostring(key or "APPEND")
    end

    local routeButton = MakeButton(section, "Route Mode: " .. RouteLabel(A.profile.odysseyRouteMode), 240, function(selfBtn)
        if not A.DataModel then return end
        local keys = A.DataModel:GetOdysseyRouteModeKeys()
        local current = A.profile.odysseyRouteMode or "APPEND"
        local index = 1
        for i, key in ipairs(keys) do
            if key == current then
                index = i
                break
            end
        end
        local nextKey = keys[(index % #keys) + 1]
        A.profile.odysseyRouteMode = nextKey
        selfBtn:SetText("Route Mode: " .. RouteLabel(nextKey))
        if A.Tracker then A.Tracker:Refresh(true) end
    end)
    routeButton:SetPoint("TOPLEFT", checkOpenMap, "BOTTOMLEFT", 2, -12)

    section:SetHeight(150)
    y = y + section:GetHeight() + 12
    SetPageHeight(page, y)
end

-- ---------------------------------------------------------------------------
-- Checklist
-- ---------------------------------------------------------------------------

function S:BuildChecklistPage()
    local page = self.pages.checklist
    local content = page.content
    local width = 760
    local y = 0

    local section = MakeSection(content, "Checklist Templates",
        "Enable the recurring checklist templates you want Artemis to generate entries from.", width)
    section:SetPoint("TOPLEFT", 8, -y)

    local keys = {}
    if A.DataModel then
        keys = A.DataModel:GetChecklistTemplateKeys() or {}
    end

    local count = 0
    local last
    for _, key in ipairs(keys) do
        local label = A.DataModel:GetChecklistTemplateLabel(key)
        local cb = MakeCheck(section, label,
            function() return A:IsChecklistTemplateEnabled(key) end,
            function(v)
                A:SetChecklistTemplateEnabled(key, v)
                if A.Tracker then A.Tracker:Refresh(true) end
            end)
        if last then
            cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
        else
            cb:SetPoint("TOPLEFT", 18, -48)
        end
        last = cb
        count = count + 1
    end

    if count == 0 then
        local empty = section:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
        empty:SetPoint("TOPLEFT", 18, -48)
        empty:SetText("No checklist templates were found.")
        section:SetHeight(90)
    else
        section:SetHeight(48 + (count * 28) + 12)
    end

    y = y + section:GetHeight() + 12
    SetPageHeight(page, y)
end

-- ---------------------------------------------------------------------------
-- Currency
-- ---------------------------------------------------------------------------

function S:BuildCurrencyPage()
    local page = self.pages.currency
    local content = page.content
    local width = 760
    local y = 0

    local section = MakeSection(content, "Currency Tracker",
        "Toggle the entire Currencies section and curate which currencies Artemis tracks.", width)
    section:SetPoint("TOPLEFT", 8, -y)

    local sectionToggle = MakeCheck(section, "Show Currency Section",
        function() return A.Currency and A.Currency:IsSectionEnabled() or false end,
        function(v)
            if A.Currency then
                A.Currency:SetSectionEnabled(v)
                if A.Tracker then A.Tracker:Refresh(true) end
            end
        end,
        "Toggles the entire Currencies section in the tracker.")
    sectionToggle:SetPoint("TOPLEFT", 18, -48)

    local count = 0
    local last = sectionToggle
    if A.Currency then
        for _, def in ipairs(A.Currency:GetDefinitions()) do
            local key = def.key
            local labelText = def.label
            if def.speculative then
                labelText = labelText .. "  (verify ID)"
            end
            local cb = MakeCheck(section, labelText,
                function() return A.Currency:IsEnabled(key) end,
                function(v)
                    A.Currency:SetEnabled(key, v)
                    if A.Tracker then A.Tracker:Refresh(true) end
                end)
            cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
            last = cb
            count = count + 1
        end
    end

    -- One row for the section toggle plus one per currency definition.
    section:SetHeight(48 + ((count + 1) * 28) + 12)
    y = y + section:GetHeight() + 12
    SetPageHeight(page, y)
end

-- ---------------------------------------------------------------------------
-- Modules
-- ---------------------------------------------------------------------------

function S:RefreshModuleStatus()
    local status = self.moduleStatusText
    if not status then
        return
    end

    if not A.Modules then
        status:SetText("Modules: unavailable")
        return
    end

    status:SetText(table.concat({
        "Loaded Children:",
        string.format("Checklist: %s (%s)", A.Modules:GetStatus("checklist"), A.Modules:GetProviderLabel("checklist")),
        string.format("Odyssey: %s (%s)", A.Modules:GetStatus("odyssey"), A.Modules:GetProviderLabel("odyssey")),
        string.format("World Quests: %s (%s)", A.Modules:GetStatus("worldQuests"), A.Modules:GetProviderLabel("worldQuests")),
    }, "\n"))
end

function S:BuildModulesPage()
    local page = self.pages.modules
    local content = page.content
    local width = 760
    local y = 0

    -- Core runtime toggles ---------------------------------------------------
    local toggleSection = MakeSection(content, "Core Runtime Toggles",
        "Enable or disable Artemis subsystems. Off means the feature does no work at all.", width)
    toggleSection:SetPoint("TOPLEFT", 8, -y)

    local modules = {
        { "World Quests", "worldQuests" },
        { "Checklist", "checklist" },
        { "Objectives", "objectives" },
        { "Quest Items", "questItems" },
        { "Reward Enrichment", "rewards" },
        { "Odyssey Routing", "odyssey" },
        { "Tracked Recipes", "recipes" },
    }

    local last
    for _, info in ipairs(modules) do
        local label, moduleKey = info[1], info[2]
        local button = MakeButton(toggleSection, "", 200, function(selfBtn)
            local enabled = not A:IsModuleEnabled(moduleKey)
            A:SetModuleEnabled(moduleKey, enabled)
            selfBtn:SetText(string.format("%s: %s", label, enabled and "On" or "Off"))
            S:RefreshModuleStatus()
        end)
        button:SetText(string.format("%s: %s", label, A:IsModuleEnabled(moduleKey) and "On" or "Off"))
        if last then
            button:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
        else
            button:SetPoint("TOPLEFT", 18, -48)
        end
        last = button
    end

    toggleSection:SetHeight(48 + (#modules * 30) + 12)
    y = y + toggleSection:GetHeight() + 12

    -- Loaded child module status --------------------------------------------
    local statusSection = MakeSection(content, "Loaded Child Modules",
        "Live status of the addons Artemis hands work off to.", width)
    statusSection:SetPoint("TOPLEFT", 8, -y)
    statusSection:SetHeight(120)

    local statusText = statusSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 18, -48)
    statusText:SetPoint("TOPRIGHT", -18, -48)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    self.moduleStatusText = statusText
    self:RefreshModuleStatus()

    y = y + statusSection:GetHeight() + 12

    -- Utilities --------------------------------------------------------------
    local utilSection = MakeSection(content, "Utilities",
        "One-shot maintenance actions for focus and pinned quests.", width)
    utilSection:SetPoint("TOPLEFT", 8, -y)

    local clearFocus = MakeButton(utilSection, "Clear Focus", 160, function()
        A:ClearFocusQuest()
    end)
    clearFocus:SetPoint("TOPLEFT", 18, -48)

    local clearPins = MakeButton(utilSection, "Clear All Pins", 160, function()
        if A.character and A.character.pinnedQuestIDs then
            wipe(A.character.pinnedQuestIDs)
        end
        if A.Tracker then A.Tracker:Refresh(true) end
    end)
    clearPins:SetPoint("TOPLEFT", clearFocus, "BOTTOMLEFT", 0, -8)

    utilSection:SetHeight(48 + (2 * 32) + 12)
    y = y + utilSection:GetHeight() + 12

    SetPageHeight(page, y)
end
