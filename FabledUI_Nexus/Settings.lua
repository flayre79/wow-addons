local N = FabledUI_Nexus
N.Settings = N.Settings or {}
local S = N.Settings

local TAB_ORDER = { "general", "modules", "review" }
local ACCENT = { 0.320, 0.635, 1.000, 1.0 }
local THEME = "FableNeon"
local WINDOW_NAME = "FabledUI_NexusSettingsFrame"
local DEFAULT_WINDOW_STATE = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 1040,
    height = 760,
    scale = 1,
    alpha = 1,
    displayState = "expanded",
}

local function GetToolkit()
    return rawget(_G, "FabledUI_UIToolkit")
end

local function SanitizeText(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return
    end
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local function GetAddonMetadataSafe(addonName, field)
    if type(addonName) ~= "string" or addonName == "" then
        return nil
    end
    local value
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        value = C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function NormalizeTitle(value)
    value = SanitizeText(value)
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("^FabledUI%s*%-%s*", "")
    value = value:gsub("^FlayreDev%s*%-%s*", "")
    value = value:gsub("^FabledUI%s+", "")
    value = value:gsub("^FlayreDev%s+", "")
    return SanitizeText(value)
end

local function IsTopLevelSuiteAddon(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end
    local suffix = addonName:match("^FabledUI_(.+)$") or addonName:match("^FlayreDev_(.+)$")
    if not suffix or suffix == "" then
        return false
    end
    return not suffix:find("_", 1, true)
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

local function MakeCheck(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.Text:SetText(label)
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked())
    end)
    return cb
end

local function MakeSlider(parent, label, minVal, maxVal, get, set)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(get())
    if slider.Low then slider.Low:SetText(minVal) end
    if slider.High then slider.High:SetText(maxVal) end
    if slider.Text then slider.Text:SetText(label .. " (" .. math.floor(get()) .. ")") end
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        set(value)
        if self.Text then
            self.Text:SetText(label .. " (" .. value .. ")")
        end
    end)
    return slider
end

local function MakeEditBox(parent, width)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 24)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    return editBox
end

local function StyleButton(button)
    local T = GetToolkit()
    if T and T.Themes and type(T.Themes.StyleFlatButton) == "function" then
        T.Themes:StyleFlatButton(button, THEME, ACCENT)
    end
end

function S:EnsureDefaults()
    N.db = N.db or {}
    N.db.addonConfig = N.db.addonConfig or {}
    N.db.customRegistry = N.db.customRegistry or {}
    N.db.detectedRegistry = N.db.detectedRegistry or {}
    N.db.widgetConfig = N.db.widgetConfig or {}
    N.db.settingsWindow = N.db.settingsWindow or {}

    CopyDefaults(N.db.settingsWindow, DEFAULT_WINDOW_STATE)

    if N.db.showNames == nil then N.db.showNames = true end
    if N.db.showSettings == nil then N.db.showSettings = true end
    if N.db.showDescriptions == nil then N.db.showDescriptions = false end
    if N.db.descriptionMode == nil then N.db.descriptionMode = "SHORT" end
    if N.db.showMinimap == nil then N.db.showMinimap = true end
    if N.db.iconSize == nil then N.db.iconSize = 32 end
    if N.db.settingsIconSize == nil then N.db.settingsIconSize = 16 end
    if N.db.rowWidth == nil then N.db.rowWidth = 188 end
    if N.db.autoDetectIncludeLoadedOnly == nil then N.db.autoDetectIncludeLoadedOnly = false end
    if N.db.autoDetectEnabledOnly == nil then N.db.autoDetectEnabledOnly = true end
    if N.db.scanIgnoreDataStore == nil then N.db.scanIgnoreDataStore = true end
end

function S:Register()
    self:EnsureDefaults()
    self.activeTab = self.activeTab or "general"
end

function S:ApplyLiveOptions(rebuildRegistry)
    if rebuildRegistry and N.Registry and type(N.Registry.Init) == "function" then
        N.Registry:Init()
    end
    if N.UI then
        if type(N.UI.ApplyLiveOptions) == "function" then
            N.UI:ApplyLiveOptions()
        elseif type(N.UI.Refresh) == "function" then
            N.UI:Refresh()
        end
    end
    if N.Integrations and type(N.Integrations.Init) == "function" then
        pcall(function() N.Integrations:Init() end)
        local libStub = _G.LibStub
        if type(libStub) == "function" then
            local icon = libStub("LibDBIcon-1.0", true)
            if icon and N._ldb then
                if N.db.showMinimap then
                    icon:Show("Nexus")
                else
                    icon:Hide("Nexus")
                end
            end
        end
    end
end

function S:IsMinimapAvailable()
    local libStub = _G.LibStub
    if type(libStub) ~= "function" then
        return false
    end
    return libStub("LibDataBroker-1.1", true) ~= nil and libStub("LibDBIcon-1.0", true) ~= nil
end

function S:GetSuiteEntries()
    local results = {}
    local seen = {}

    local function addEntry(entry)
        if not entry or not entry.addonName or seen[entry.addonName] then
            return
        end
        seen[entry.addonName] = true
        results[#results + 1] = entry
    end

    local suiteModules = nil
    if N.Registry and type(N.Registry.GetSuiteModules) == "function" then
        suiteModules = N.Registry:GetSuiteModules()
    elseif N.Registry and type(N.Registry.GetNativeModules) == "function" then
        suiteModules = N.Registry:GetNativeModules()
    else
        suiteModules = {}
    end

    for _, mod in ipairs(suiteModules or {}) do
        local addonName = type(N.Registry.ResolveInstalledAddon) == "function" and N.Registry:ResolveInstalledAddon(mod) or nil
        addonName = addonName or ((mod.addonCandidates and mod.addonCandidates[1]) or mod.id)
        if addonName and IsTopLevelSuiteAddon(addonName) then
            local cfgKey = mod.id or addonName
            local cfg = N.db.addonConfig[cfgKey] or N.db.addonConfig[addonName] or {}
            local defaultName = (type(N.Registry.GetResolvedModuleLabel) == "function" and N.Registry:GetResolvedModuleLabel(mod, addonName))
                or NormalizeTitle(GetAddonMetadataSafe(addonName, "X-Nexus-ShortName") or GetAddonMetadataSafe(addonName, "Title") or addonName)
            addEntry({
                addonName = addonName,
                configKey = cfgKey,
                defaultName = defaultName ~= "" and defaultName or addonName,
                customName = cfg.customLabel,
                customIcon = cfg.customIcon,
                visible = cfg.visible ~= false,
            })
        end
    end

    table.sort(results, function(a, b)
        local aName = tostring(a.customName or a.defaultName or a.addonName):lower()
        local bName = tostring(b.customName or b.defaultName or b.addonName):lower()
        return aName < bName
    end)

    return results
end

function S:GetManualEntries()
    local entries = {}
    for key, data in pairs(N.db.customRegistry or {}) do
        if type(data) == "table" and not data.autoDetected then
            entries[#entries + 1] = {
                key = key,
                addonName = data.addonName,
                label = data.label or data.addonName or key,
                slash = data.launchSlash or data.slash or "",
            }
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.label or a.addonName or a.key):lower() < tostring(b.label or b.addonName or b.key):lower()
    end)
    return entries
end

function S:GetFilteredCandidates()
    local search = SanitizeText(self.candidateSearch or ""):lower()
    local list = {}
    if not N.Registry or type(N.Registry.GetDetectedCandidates) ~= "function" then
        return list
    end
    for _, entry in ipairs(N.Registry:GetDetectedCandidates()) do
        local haystack = table.concat({
            tostring(entry.label or ""),
            tostring(entry.addonName or ""),
            tostring(entry.launchSlash or ""),
            tostring(entry.settingsSlash or ""),
        }, " "):lower()

        local keep = search == "" or haystack:find(search, 1, true)
        if keep and self.reviewRequireLauncher and not (entry.launchPath or entry.launchFrameName or entry.launchSlash) then
            keep = false
        end
        if keep then
            list[#list + 1] = entry
        end
    end
    return list
end

function S:BuildShell()
    if self.window then
        return self.window
    end

    self:EnsureDefaults()

    local T = GetToolkit()
    if not T or not T.Shell then
        N:Print("FabledUI_UIToolkit is required for Nexus settings.")
        return nil
    end

    local frame = T.Shell:CreateWindow(WINDOW_NAME, {
        title = "FabledUI - Nexus Settings",
        subtitle = "Toolkit-backed standalone settings. No more Game Menu clownery.",
        theme = THEME,
        accentColor = ACCENT,
        width = N.db.settingsWindow.width,
        height = N.db.settingsWindow.height,
        minWidth = 920,
        minHeight = 620,
        maxWidth = 1700,
        maxHeight = 1200,
        state = N.db.settingsWindow,
        ribbon = false,
        resizable = true,
    })

    -- Shell does not order its windows (no SetToplevel, no frame-level
    -- management), so each addon opts in individually -- Athena, DataVault,
    -- Harvest, Iris, Kleos, Nemesis and Odyssey all do this on their own
    -- windows. Nexus and Villa were the two that did not, which is why those
    -- two interleaved instead of raising. Stopgap until the toolkit owns it;
    -- see docs/UIToolkit/Lane_Requests.md.
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end

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
    local labels = {
        general = "General",
        modules = "Modules",
        review = "Review Queue",
    }
    for _, key in ipairs(TAB_ORDER) do
        local button = CreateFrame("Button", nil, tabs, "UIPanelButtonTemplate")
        button:SetSize(key == "review" and 170 or 150, 24)
        button:SetText(labels[key])
        StyleButton(button)
        if last then
            button:SetPoint("LEFT", last, "RIGHT", 12, 0)
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
    self:BuildModulesPage()
    self:BuildReviewPage()
    self:ShowTab(self.activeTab or "general")
    frame:SetShellStatus("Ready")
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
end

function S:OpenWindow()
    local frame = self:BuildShell()
    if not frame then
        return false
    end
    self:RefreshAll()
    frame:ShowExpanded()
    return true
end

function S:BuildGeneralPage()
    local page = self.pages.general
    local content = page.content
    local width = 930
    local y = 0

    local general = MakeSection(content, "General", "Core Nexus behavior and compact appearance controls.", width)
    general:SetPoint("TOPLEFT", 8, -y)
    general:SetHeight(200)
    local gLeft = 18
    local cbLock = MakeCheck(general, "Lock Nexus Hub Position", function() return N.db.locked == true end, function(v)
        N.db.locked = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    cbLock:SetPoint("TOPLEFT", gLeft, -48)

    local cbNames = MakeCheck(general, "Show Addon Names", function() return N.db.showNames ~= false end, function(v)
        N.db.showNames = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    cbNames:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -8)

    local cbSettings = MakeCheck(general, "Show Settings Buttons", function() return N.db.showSettings == true end, function(v)
        N.db.showSettings = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    cbSettings:SetPoint("TOPLEFT", cbNames, "BOTTOMLEFT", 0, -8)

    local cbDescriptions = MakeCheck(general, "Show Descriptions", function() return N.db.showDescriptions == true end, function(v)
        N.db.showDescriptions = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    cbDescriptions:SetPoint("TOPLEFT", cbSettings, "BOTTOMLEFT", 0, -8)

    local cbMinimap = nil

    local sliderIcon = MakeSlider(general, "Main Icon Size", 20, 64, function() return N.db.iconSize or 32 end, function(v)
        N.db.iconSize = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    sliderIcon:SetPoint("TOPRIGHT", -34, -12)
    sliderIcon:SetWidth(260)

    local sliderSettings = MakeSlider(general, "Settings Icon Size", 12, 28, function() return N.db.settingsIconSize or 16 end, function(v)
        N.db.settingsIconSize = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    sliderSettings:SetPoint("TOPRIGHT", -34, -54)
    sliderSettings:SetWidth(260)

    local sliderWidth = MakeSlider(general, "Hub Width", 120, 280, function() return N.db.rowWidth or 188 end, function(v)
        N.db.rowWidth = v
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    sliderWidth:SetPoint("TOPRIGHT", -34, -108)
    sliderWidth:SetWidth(260)

    y = y + general:GetHeight() + 12

    local desc = MakeSection(content, "Description Style", "Keep row text informative without turning the sidebar into a novella.", width)
    desc:SetPoint("TOPLEFT", 8, -y)
    desc:SetHeight(74)
    local modeLabel = desc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", 18, -46)
    modeLabel:SetText("Description Mode")

    local shortBtn = CreateFrame("Button", nil, desc, "UIPanelButtonTemplate")
    shortBtn:SetSize(86, 24)
    shortBtn:SetText("Short")
    shortBtn:SetPoint("LEFT", modeLabel, "RIGHT", 18, 0)
    StyleButton(shortBtn)
    shortBtn:SetScript("OnClick", function()
        N.db.descriptionMode = "SHORT"
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)

    local fullBtn = CreateFrame("Button", nil, desc, "UIPanelButtonTemplate")
    fullBtn:SetSize(86, 24)
    fullBtn:SetText("Full")
    fullBtn:SetPoint("LEFT", shortBtn, "RIGHT", 8, 0)
    StyleButton(fullBtn)
    fullBtn:SetScript("OnClick", function()
        N.db.descriptionMode = "FULL"
        N:MarkDirty()
        S:ApplyLiveOptions(false)
    end)
    self.shortDescButton = shortBtn
    self.fullDescButton = fullBtn

    y = y + desc:GetHeight() + 12

    local scan = MakeSection(content, "Scan Defaults", "These shape third-party scanning behavior without flooding the hub like a cursed yard sale.", width)
    scan:SetPoint("TOPLEFT", 8, -y)
    scan:SetHeight(150)
    local cbLoaded = MakeCheck(scan, "Only Scan Loaded AddOns", function() return N.db.autoDetectIncludeLoadedOnly == true end, function(v)
        N.db.autoDetectIncludeLoadedOnly = v
        N:MarkDirty()
    end)
    cbLoaded:SetPoint("TOPLEFT", 18, -48)

    local cbEnabled = MakeCheck(scan, "Only Scan Enabled AddOns", function() return N.db.autoDetectEnabledOnly ~= false end, function(v)
        N.db.autoDetectEnabledOnly = v
        N:MarkDirty()
    end)
    cbEnabled:SetPoint("TOPLEFT", cbLoaded, "BOTTOMLEFT", 0, -8)

    local cbIgnoreData = MakeCheck(scan, "Ignore DataStore AddOns", function() return N.db.scanIgnoreDataStore ~= false end, function(v)
        N.db.scanIgnoreDataStore = v
        N:MarkDirty()
    end)
    cbIgnoreData:SetPoint("TOPLEFT", cbEnabled, "BOTTOMLEFT", 0, -8)

    if self:IsMinimapAvailable() then
        local cbMinimap = MakeCheck(scan, "Show Minimap Icon", function() return N.db.showMinimap ~= false end, function(v)
            N.db.showMinimap = v
            N:MarkDirty()
            S:ApplyLiveOptions(false)
        end)
        cbMinimap:SetPoint("LEFT", 420, 0)
        cbMinimap:SetPoint("TOP", cbLoaded, "TOP", 0, 0)
    end

    y = y + scan:GetHeight() + 12

    local widgets = MakeSection(content, "Widgets", "Optional Titan-style mini widgets. Disable them and the core hub behaves exactly the same.", width)
    widgets:SetPoint("TOPLEFT", 8, -y)
    widgets:SetHeight(200)

    local widgetRows = {
        { "durability", "Durability / repair" },
        { "performance", "FPS / latency" },
        { "time", "Time (local & server)" },
        { "gold", "Gold" },
        { "location", "Location" },
        { "coords", "Coordinates" },
        { "xp", "XP to next level" },
        { "reputation", "Reputation (watched)" },
        { "housefavor", "House XP / favor" },
        { "volume", "Volume" },
    }
    for index, info in ipairs(widgetRows) do
        local key, label = info[1], info[2]
        local cb = MakeCheck(widgets, label, function()
            return N.db.widgetConfig[key] and N.db.widgetConfig[key].enabled == true
        end, function(v)
            N.db.widgetConfig[key] = N.db.widgetConfig[key] or { enabled = false, group = "Widgets", favorite = false }
            N.db.widgetConfig[key].enabled = v
            N:MarkDirty()
            S:ApplyLiveOptions(true)
        end)
        local col = (index % 2 == 1) and 0 or 1
        local row = math.floor((index - 1) / 2)
        cb:SetPoint("TOPLEFT", 18 + (col * 340), -48 - (row * 28))
    end

    y = y + widgets:GetHeight() + 12
    SetPageHeight(page, y)
end

function S:RefreshModulesPage()
    if not self.pages or not self.pages.modules or not self.modulesRowsAnchor then
        return
    end

    local page = self.pages.modules
    local content = page.content
    local anchor = self.modulesRowsAnchor
    local rows = self.moduleRows or {}
    local suiteEntries = self:GetSuiteEntries()
    local width = 930

    for _, row in ipairs(rows) do
        row.frame:Hide()
    end

    local y = 0
    if #suiteEntries == 0 then
        if not self.noSuiteText then
            self.noSuiteText = self.modulesSection:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
            self.noSuiteText:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            self.noSuiteText:SetText("No installed FabledUI suite addons were discovered.")
        end
        self.noSuiteText:Show()
    else
        if self.noSuiteText then self.noSuiteText:Hide() end
    end

    for index, entry in ipairs(suiteEntries) do
        local row = rows[index]
        if not row then
            row = {}
            row.frame = CreateFrame("Frame", nil, self.modulesSection)
            row.frame:SetHeight(46)

            row.check = CreateFrame("CheckButton", nil, row.frame, "UICheckButtonTemplate")
            row.check:SetPoint("LEFT", 0, 0)

            row.title = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.title:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 6, 6)
            row.title:SetWidth(250)
            row.title:SetJustifyH("LEFT")

            row.meta = row.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
            row.meta:SetWidth(250)
            row.meta:SetJustifyH("LEFT")

            row.nameInput = MakeEditBox(row.frame, 180)
            row.nameInput:SetPoint("LEFT", 300, 0)

            row.iconInput = MakeEditBox(row.frame, 150)
            row.iconInput:SetPoint("LEFT", row.nameInput, "RIGHT", 14, 0)

            row.save = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
            row.save:SetSize(60, 24)
            row.save:SetText("Save")
            row.save:SetPoint("LEFT", row.iconInput, "RIGHT", 14, 0)
            StyleButton(row.save)

            row.reset = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
            row.reset:SetSize(60, 24)
            row.reset:SetText("Reset")
            row.reset:SetPoint("LEFT", row.save, "RIGHT", 8, 0)
            StyleButton(row.reset)

            rows[index] = row
        end

        row.frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -y)
        row.frame:SetPoint("RIGHT", -18, 0)
        row.frame:Show()
        row.title:SetText(entry.defaultName)
        row.meta:SetText(entry.addonName)

        local cfg = N.db.addonConfig[entry.configKey] or {}
        row.check:SetChecked(cfg.visible ~= false)
        row.nameInput:SetText(cfg.customLabel or "")
        row.iconInput:SetText(cfg.customIcon or "")

        row.check:SetScript("OnClick", function(self)
            N.db.addonConfig[entry.configKey] = N.db.addonConfig[entry.configKey] or {}
            N.db.addonConfig[entry.configKey].visible = self:GetChecked()
            N:MarkDirty()
            S:ApplyLiveOptions(true)
        end)

        row.save:SetScript("OnClick", function()
            N.db.addonConfig[entry.configKey] = N.db.addonConfig[entry.configKey] or {}
            local customName = SanitizeText(row.nameInput:GetText())
            local customIcon = SanitizeText(row.iconInput:GetText())
            N.db.addonConfig[entry.configKey].customLabel = customName ~= "" and customName or nil
            if customIcon == "" then
                N.db.addonConfig[entry.configKey].customIcon = nil
            else
                N.db.addonConfig[entry.configKey].customIcon = tonumber(customIcon) or customIcon
            end
            if N.Registry and type(N.Registry.SetNativeLabel) == "function" then
                N.Registry:SetNativeLabel(entry.configKey, N.db.addonConfig[entry.configKey].customLabel)
            end
            if N.Registry and type(N.Registry.SetNativeIcon) == "function" then
                N.Registry:SetNativeIcon(entry.configKey, N.db.addonConfig[entry.configKey].customIcon)
            else
                N:MarkDirty()
                S:ApplyLiveOptions(true)
            end
            S:RefreshModulesPage()
        end)

        row.reset:SetScript("OnClick", function()
            N.db.addonConfig[entry.configKey] = N.db.addonConfig[entry.configKey] or {}
            N.db.addonConfig[entry.configKey].customLabel = nil
            N.db.addonConfig[entry.configKey].customIcon = nil
            row.nameInput:SetText("")
            row.iconInput:SetText("")
            if N.Registry and type(N.Registry.SetNativeLabel) == "function" then
                N.Registry:SetNativeLabel(entry.configKey, nil)
            else
                N:MarkDirty()
            end
            if N.Registry and type(N.Registry.SetNativeIcon) == "function" then
                N.Registry:SetNativeIcon(entry.configKey, nil)
            else
                S:ApplyLiveOptions(true)
            end
            S:RefreshModulesPage()
        end)

        y = y + 50
    end

    self.moduleRows = rows

    local suiteHeight = math.max(140, 62 + y + 12)
    self.modulesSection:SetHeight(suiteHeight)
    self.manualSection:SetPoint("TOPLEFT", self.modulesSection, "BOTTOMLEFT", 0, -12)
    self.manualListSection:SetPoint("TOPLEFT", self.manualSection, "BOTTOMLEFT", 0, -12)

    self:RefreshManualList()
    local totalHeight = suiteHeight + self.manualSection:GetHeight() + self.manualListSection:GetHeight() + 36
    SetPageHeight(page, totalHeight)
end

function S:RefreshManualList()
    if not self.manualEntriesAnchor then
        return
    end

    local entries = self:GetManualEntries()
    local rows = self.manualRows or {}
    for _, row in ipairs(rows) do
        row.frame:Hide()
    end

    local y = 0
    if not self.noManualText then
        self.noManualText = self.manualListSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        self.noManualText:SetPoint("TOPLEFT", self.manualEntriesAnchor, "TOPLEFT", 0, 0)
        self.noManualText:SetText("No manual registrations yet.")
    end
    if #entries == 0 then
        self.noManualText:Show()
    else
        self.noManualText:Hide()
    end

    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = {}
            row.frame = CreateFrame("Frame", nil, self.manualListSection)
            row.frame:SetHeight(24)
            row.text = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 0, 0)
            row.text:SetWidth(700)
            row.text:SetJustifyH("LEFT")
            row.remove = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
            row.remove:SetSize(72, 22)
            row.remove:SetText("Remove")
            row.remove:SetPoint("RIGHT", 0, 0)
            StyleButton(row.remove)
            rows[index] = row
        end
        row.frame:SetPoint("TOPLEFT", self.manualEntriesAnchor, "TOPLEFT", 0, -y)
        row.frame:SetPoint("RIGHT", -16, 0)
        row.frame:Show()
        row.text:SetText(string.format("%s (%s)%s", entry.label or entry.key, entry.addonName or "?", entry.slash ~= "" and ("  -  " .. entry.slash) or ""))
        row.remove:SetScript("OnClick", function()
            if N.Registry and type(N.Registry.RemoveCustomAddon) == "function" then
                N.Registry:RemoveCustomAddon(entry.key)
            else
                N.db.customRegistry[entry.key] = nil
                N:MarkDirty()
            end
            S:ApplyLiveOptions(true)
            S:RefreshManualList()
        end)
        y = y + 26
    end

    self.manualRows = rows
    local sectionHeight = math.max(82, 52 + y + 12)
    self.manualListSection:SetHeight(sectionHeight)
end

function S:BuildModulesPage()
    local page = self.pages.modules
    local content = page.content
    local width = 930

    local suite = MakeSection(content, "FabledUI Suite AddOns", "Installed FabledUI addons are discovered automatically. Default names come from metadata; custom names and icons override them here.", width)
    suite:SetPoint("TOPLEFT", 8, 0)
    suite:SetHeight(360)
    self.modulesSection = suite

    local visHeader = suite:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visHeader:SetPoint("TOPLEFT", 18, -44)
    visHeader:SetText("Visible")
    local nameHeader = suite:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader:SetPoint("TOPLEFT", 56, -44)
    nameHeader:SetText("Name / AddOn")
    local customNameHeader = suite:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customNameHeader:SetPoint("TOPLEFT", 300, -44)
    customNameHeader:SetText("Custom Name")
    local customIconHeader = suite:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customIconHeader:SetPoint("TOPLEFT", 504, -44)
    customIconHeader:SetText("Custom Icon")

    local assetsBtn = CreateFrame("Button", nil, suite, "UIPanelButtonTemplate")
    assetsBtn:SetSize(108, 22)
    assetsBtn:SetText("Asset Browser")
    assetsBtn:SetPoint("TOPRIGHT", -16, -14)
    StyleButton(assetsBtn)
    assetsBtn:SetScript("OnClick", function()
        if type(SlashCmdList) == "table" and type(SlashCmdList["FUIASSETBROWSER"]) == "function" then
            SlashCmdList["FUIASSETBROWSER"]("")
        elseif type(SlashCmdList) == "table" and type(SlashCmdList["FUIASSETS"]) == "function" then
            SlashCmdList["FUIASSETS"]("")
        elseif type(SlashCmdList) == "table" and type(SlashCmdList["FUIASSETSETTINGS"]) == "function" then
            SlashCmdList["FUIASSETSETTINGS"]("")
        else
            N:Print("Asset Browser slash command was not found.")
        end
    end)

    local rowsAnchor = CreateFrame("Frame", nil, suite)
    rowsAnchor:SetPoint("TOPLEFT", 18, -66)
    rowsAnchor:SetPoint("TOPRIGHT", -18, -66)
    rowsAnchor:SetHeight(1)
    self.modulesRowsAnchor = rowsAnchor

    local manual = MakeSection(content, "Manual Registration", "Useful for addons that hide their UI behind a slash command or otherwise resist civilized discovery.", width)
    manual:SetPoint("TOPLEFT", suite, "BOTTOMLEFT", 0, -12)
    manual:SetHeight(112)
    self.manualSection = manual

    local addonBox = MakeEditBox(manual, 210)
    addonBox:SetPoint("TOPLEFT", 18, -60)
    local addonLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonLabel:SetPoint("BOTTOMLEFT", addonBox, "TOPLEFT", 0, 2)
    addonLabel:SetText("Addon Folder")

    local labelBox = MakeEditBox(manual, 210)
    labelBox:SetPoint("LEFT", addonBox, "RIGHT", 16, 0)
    local labelLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelLabel:SetPoint("BOTTOMLEFT", labelBox, "TOPLEFT", 0, 2)
    labelLabel:SetText("Display Label")

    local slashBox = MakeEditBox(manual, 210)
    slashBox:SetPoint("LEFT", labelBox, "RIGHT", 16, 0)
    local slashLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slashLabel:SetPoint("BOTTOMLEFT", slashBox, "TOPLEFT", 0, 2)
    slashLabel:SetText("Slash Command")

    local addBtn = CreateFrame("Button", nil, manual, "UIPanelButtonTemplate")
    addBtn:SetSize(110, 24)
    addBtn:SetText("Add to Hub")
    addBtn:SetPoint("LEFT", slashBox, "RIGHT", 14, 0)
    StyleButton(addBtn)
    addBtn:SetScript("OnClick", function()
        local addonName = SanitizeText(addonBox:GetText())
        local displayLabel = SanitizeText(labelBox:GetText())
        local slash = SanitizeText(slashBox:GetText())
        if addonName == "" then
            N:Print("Addon folder name is required.")
            return
        end
        if N.Registry and type(N.Registry.RegisterCustomAddon) == "function" then
            local ok, err = N.Registry:RegisterCustomAddon(addonName, slash, displayLabel)
            if not ok then
                N:Print(err or "Failed to register addon.")
                return
            end
        else
            local key = "manual_" .. addonName
            N.db.customRegistry[key] = {
                addonName = addonName,
                label = displayLabel ~= "" and displayLabel or addonName,
                slash = slash ~= "" and slash or nil,
                visible = true,
            }
            N:MarkDirty()
        end
        addonBox:SetText("")
        labelBox:SetText("")
        slashBox:SetText("")
        S:ApplyLiveOptions(true)
        S:RefreshManualList()
    end)

    local manualList = MakeSection(content, "Manual Entries", "Anything you add by hand lives here. Remove the junk with prejudice.", width)
    manualList:SetPoint("TOPLEFT", manual, "BOTTOMLEFT", 0, -12)
    manualList:SetHeight(90)
    self.manualListSection = manualList

    local manualEntriesAnchor = CreateFrame("Frame", nil, manualList)
    manualEntriesAnchor:SetPoint("TOPLEFT", 18, -44)
    manualEntriesAnchor:SetPoint("TOPRIGHT", -18, -44)
    manualEntriesAnchor:SetHeight(1)
    self.manualEntriesAnchor = manualEntriesAnchor

    self:RefreshModulesPage()
end

function S:RefreshCandidateList()
    if not self.reviewEntriesAnchor then
        return
    end
    local entries = self:GetFilteredCandidates()
    local rows = self.candidateRows or {}
    for _, row in ipairs(rows) do
        row.frame:Hide()
    end

    local y = 0
    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = {}
            row.frame = CreateFrame("Frame", nil, self.reviewSection)
            row.frame:SetHeight(42)
            row.check = CreateFrame("CheckButton", nil, row.frame, "UICheckButtonTemplate")
            row.check:SetPoint("TOPLEFT", 0, -6)
            row.title = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.title:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 6, 6)
            row.title:SetWidth(600)
            row.title:SetJustifyH("LEFT")
            row.badges = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.badges:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -1)
            row.badges:SetWidth(600)
            row.badges:SetJustifyH("LEFT")
            row.meta = row.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.meta:SetPoint("TOPLEFT", row.badges, "BOTTOMLEFT", 0, -1)
            row.meta:SetWidth(760)
            row.meta:SetJustifyH("LEFT")
            rows[index] = row
        end

        row.frame:SetPoint("TOPLEFT", self.reviewEntriesAnchor, "TOPLEFT", 0, -y)
        row.frame:SetPoint("RIGHT", -16, 0)
        row.frame:Show()
        row.check:SetChecked(entry.inHub == true)
        row.title:SetText(string.format("%s (%s)", entry.label or entry.addonName or entry.key, entry.addonName or "?"))

        local badges = {}
        if entry.launchPath or entry.launchFrameName then badges[#badges + 1] = "|cff4fd1ffUI|r" end
        if entry.launchSlash then badges[#badges + 1] = "|cffffd15fSlash|r" end
        if entry.settingsCategoryID or entry.settingsPath or entry.settingsSlash then badges[#badges + 1] = "|cff80ff80Settings|r" end
        row.badges:SetText(table.concat(badges, "  "))
        row.meta:SetText(string.format("Launch: %s    Settings: %s", tostring(entry.launchMethod or "None"), tostring(entry.settingsMethod or "None")))
        row.check:SetScript("OnClick", function(self)
            if N.Registry and type(N.Registry.SetDetectedAddonEnabled) == "function" then
                N.Registry:SetDetectedAddonEnabled(entry.key, self:GetChecked())
                S:ApplyLiveOptions(true)
                S:RefreshCandidateList()
            end
        end)
        y = y + 46
    end

    self.candidateRows = rows
    self.reviewSection:SetHeight(math.max(220, 72 + y + 12))
    local totalHeight = self.scanSection:GetHeight() + self.filterSection:GetHeight() + self.reviewSection:GetHeight() + 36
    SetPageHeight(self.pages.review, totalHeight)
end

function S:BuildReviewPage()
    local page = self.pages.review
    local content = page.content
    local width = 930

    local scan = MakeSection(content, "Scan & Review", "Scanning builds a candidate list only. Nothing is added to the hub until its checkbox is enabled.", width)
    scan:SetPoint("TOPLEFT", 8, 0)
    scan:SetHeight(100)
    self.scanSection = scan

    local scanBtn = CreateFrame("Button", nil, scan, "UIPanelButtonTemplate")
    scanBtn:SetSize(220, 28)
    scanBtn:SetText("Scan Installed AddOns")
    scanBtn:SetPoint("TOPLEFT", 18, -42)
    StyleButton(scanBtn)
    scanBtn:SetScript("OnClick", function()
        if N.Registry and type(N.Registry.AutoDetectThirdPartyAddons) == "function" then
            local found, added = N.Registry:AutoDetectThirdPartyAddons(true)
            if N.Registry.Init then N.Registry:Init() end
            N:Print("Scan complete:", found or 0, "candidate(s),", added or 0, "new detection(s).")
            S:RefreshCandidateList()
        end
    end)

    local filters = MakeSection(content, "Review Filters", "These only affect the review list display. They do not delete detections.", width)
    filters:SetPoint("TOPLEFT", scan, "BOTTOMLEFT", 0, -12)
    filters:SetHeight(88)
    self.filterSection = filters

    local searchBox = MakeEditBox(filters, 280)
    searchBox:SetPoint("TOPLEFT", 18, -42)
    searchBox:SetScript("OnTextChanged", function(self)
        S.candidateSearch = self:GetText()
        S:RefreshCandidateList()
    end)

    local launcherOnly = MakeCheck(filters, "Require a UI launcher", function() return S.reviewRequireLauncher == true end, function(v)
        S.reviewRequireLauncher = v
        S:RefreshCandidateList()
    end)
    launcherOnly:SetPoint("LEFT", searchBox, "RIGHT", 30, 0)
    launcherOnly:SetPoint("TOP", searchBox, "TOP", 0, 0)

    local review = MakeSection(content, "3rd-Party Review Queue", "Only checked entries are shown in the Nexus hub. This keeps scans from flooding the launcher with every tiny library goblin in your AddOns folder.", width)
    review:SetPoint("TOPLEFT", filters, "BOTTOMLEFT", 0, -12)
    review:SetHeight(260)
    self.reviewSection = review

    local entriesAnchor = CreateFrame("Frame", nil, review)
    entriesAnchor:SetPoint("TOPLEFT", 18, -58)
    entriesAnchor:SetPoint("TOPRIGHT", -18, -58)
    entriesAnchor:SetHeight(1)
    self.reviewEntriesAnchor = entriesAnchor

    self:RefreshCandidateList()
end

function S:RefreshGeneralState()
    if self.shortDescButton and self.fullDescButton then
        local mode = tostring(N.db.descriptionMode or "SHORT"):upper()
        self.shortDescButton:SetEnabled(mode ~= "SHORT")
        self.fullDescButton:SetEnabled(mode ~= "FULL")
    end
end

function S:RefreshAll()
    self:EnsureDefaults()
    self:RefreshGeneralState()
    self:RefreshModulesPage()
    self:RefreshCandidateList()
    if self.window and self.window.SetShellStatus then
        local suiteCount = #self:GetSuiteEntries()
        local customCount = #self:GetManualEntries()
        self.window:SetShellStatus(string.format("Suite: %d  |  Manual: %d  |  Review candidates: %d", suiteCount, customCount, #self:GetFilteredCandidates()))
    end
end
