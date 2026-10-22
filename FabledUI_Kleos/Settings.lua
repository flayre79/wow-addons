local K = Kleos
K.Settings = K.Settings or {}
local W = K.Widgets

-- ============================================================================
-- Settings
-- 12.0 Settings API: build a canvas frame by hand, then register it.
-- Settings.CreateSettingsCategoryFrame() does not exist, so the panel is a
-- plain Frame with `name` set.
--
-- Chat announcing is the one option that stays off until the player turns it
-- on: section 6 of the PRD forbids broadcasting without explicit initiation,
-- and the checkbox is that initiation.
-- ============================================================================

local function Setting(path, fallback)
    local node = K.db and K.db.settings
    if type(node) ~= "table" then return fallback end
    for index = 1, #path - 1 do
        node = node[path[index]]
        if type(node) ~= "table" then return fallback end
    end
    local value = node[path[#path]]
    if value == nil then return fallback end
    return value
end

local function SetSetting(path, value)
    local node = K.db and K.db.settings
    if type(node) ~= "table" then return false end
    for index = 1, #path - 1 do
        if type(node[path[index]]) ~= "table" then node[path[index]] = {} end
        node = node[path[index]]
    end
    node[path[#path]] = value
    K.Storage:CommitSoon()
    return true
end

K.Settings.Get = Setting
K.Settings.Set = SetSetting

local function BuildPanel()
    local panel = CreateFrame("Frame", "FabledUI_KleosSettingsPanel", UIParent)
    panel.name = "FabledUI - Kleos"

    local title = W:Label(panel, "FabledUI - Kleos v" .. (K.VERSION or "?"), "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local subtitle = W:Label(panel, "", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    subtitle:SetText(("%s  •  %s: %s"):format(
        K.L.SUBTITLE or "Achievement suite",
        K.L.STORAGE or "Storage", tostring(K._storageBackend or "Unknown")))
    panel.subtitle = subtitle

    local anchor = subtitle
    local offset = -16

    local function AddCheckbox(label, tooltip, path, onChange)
        local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
        checkbox.Text:SetText(label)
        checkbox.tooltipText = label
        checkbox.tooltipRequirement = tooltip
        checkbox:SetChecked(Setting(path, false) and true or false)
        checkbox:SetScript("OnClick", function(self)
            local value = self:GetChecked() and true or false
            SetSetting(path, value)
            if onChange then onChange(value) end
        end)
        anchor = checkbox
        offset = -4
        return checkbox
    end

    panel.lockFrames = AddCheckbox(
        K.L.OPT_LOCK or "Lock window positions",
        "Prevent Kleos windows from being dragged or resized.",
        { "lockFrames" },
        function()
            if K.UI and K.UI.frame and K.UI.frame.ApplyLockState then K.UI.frame:ApplyLockState() end
        end)

    panel.tooltips = AddCheckbox(
        K.L.OPT_TOOLTIPS or "Enhanced achievement tooltips",
        "Add progress, reward typing and meta relationships to achievement tooltips.",
        { "tooltips" })

    panel.unitItemTooltips = AddCheckbox(
        K.L.OPT_UNIT_TOOLTIPS or "Unit and item tooltips",
        "Show which achievements need a mob or item. Builds a criteria index the first time it is used.",
        { "unitItemTooltips" },
        function(value)
            if value then K.Catalog:BuildAssetIndexAsync() end
        end)

    panel.reminders = AddCheckbox(
        K.L.OPT_REMINDERS or "Event reminders",
        "Remind me when a world event with outstanding achievements is active or about to start.",
        { "reminders" })

    panel.announce = AddCheckbox(
        K.L.OPT_ANNOUNCE or "Announce achievement progress to group chat",
        "Off by default. When enabled, Kleos posts tracked/met/missed lines and mob counts to party, raid or instance chat.",
        { "announce" })

    panel.trackerEnabled = AddCheckbox(
        K.L.OPT_TRACKER or "Enable the instance tracker overlay",
        "Show the Kleos tracker automatically in dungeons and raids.",
        { "tracker", "enabled" },
        function(value)
            if not K.Tracker then return end
            if value then
                K.Tracker:Init()
                if K.Tracker.frame then K.Tracker.frame:Show() end
                K.Tracker:Refresh()
            elseif K.Tracker.frame then
                K.Tracker.frame:Hide()
            end
        end)

    panel.trackerAutoShow = AddCheckbox(
        K.L.OPT_TRACKER_AUTO or "Pop the tracker on entering an instance",
        "Only applies when the tracker overlay is enabled.",
        { "tracker", "autoShow" })

    -- Skin selector
    local skinLabel = W:Label(panel, K.L.OPT_SKIN or "Window skin", "GameFontNormal")
    skinLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)

    local skinDrop = W:Dropdown(panel, K.Skins.MODES, {
        AUTO = (K.L.AUTO or "Automatic"),
        NONE = (K.L.NONE or "FabledUI only"),
        ELVUI = "ElvUI",
        GW2 = "GW2 UI",
    }, function(mode)
        SetSetting({ "skin" }, mode)
        K.Skins:Reapply()
        panel.skinStatus:SetText(("%s: %s"):format(K.L.DETECTED or "Detected", K.Skins:Status().detected))
    end, 160)
    skinDrop:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 0, -6)
    skinDrop:SetSelected(K.Skins:Mode())
    panel.skinDrop = skinDrop

    panel.skinStatus = W:Label(panel, ("%s: %s"):format(K.L.DETECTED or "Detected", K.Skins:Status().detected), "GameFontHighlightSmall")
    panel.skinStatus:SetPoint("LEFT", skinDrop, "RIGHT", 10, 0)

    -- Reminder lookahead
    local reminderLabel = W:Label(panel, "", "GameFontNormal")
    reminderLabel:SetPoint("TOPLEFT", skinDrop, "BOTTOMLEFT", 0, -18)
    panel.reminderLabel = reminderLabel

    -- OptionsSliderTemplate is a FrameXML template; fall back to a bare slider
    -- rather than letting a missing template abort the whole panel build.
    local okSlider, slider = pcall(CreateFrame, "Slider", "FabledUI_KleosReminderSlider", panel, "OptionsSliderTemplate")
    if not okSlider or not slider then
        slider = CreateFrame("Slider", "FabledUI_KleosReminderSlider", panel)
        slider:SetOrientation("HORIZONTAL")
        slider:SetHeight(16)
    end
    slider:SetPoint("TOPLEFT", reminderLabel, "BOTTOMLEFT", 4, -12)
    slider:SetWidth(200)
    slider:SetMinMaxValues(1, 21)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetValue(tonumber(Setting({ "reminderDays" }, 7)) or 7)
    if slider.Low then slider.Low:SetText("1") end
    if slider.High then slider.High:SetText("21") end
    local function UpdateReminderLabel(value)
        reminderLabel:SetText((K.L.OPT_REMINDER_DAYS or "Remind me this many days ahead: %d"):format(value))
    end
    UpdateReminderLabel(slider:GetValue())
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(tonumber(value) or 7)
        SetSetting({ "reminderDays" }, value)
        UpdateReminderLabel(value)
    end)
    panel.reminderSlider = slider

    -- Buttons
    panel.openButton = W:Button(panel, K.L.OPEN_ACTION or "Open Kleos", 140, 22, function()
        if K.UI then K.UI:Show() end
    end)
    panel.openButton:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, -24)

    panel.tutorialButton = W:Button(panel, K.L.TUTORIAL or "Show tutorial", 140, 22, function()
        if K.Tutorial then K.Tutorial:Show() end
    end)
    panel.tutorialButton:SetPoint("LEFT", panel.openButton, "RIGHT", 8, 0)

    panel.reindexButton = W:Button(panel, K.L.REINDEX or "Rebuild index", 140, 22, function()
        K.Catalog:Build(true)
        K.Rewards.cache = {}
        K.Rewards._index = nil
        K.Meta._parentIndex = nil
        K.Meta._childCache = {}
        K.Catalog.assetIndex = nil
        K:Print((K.L.REINDEX_DONE or "Rebuilt: %d achievements indexed."):format(K.Catalog:Count()))
        if K.UI then K.UI:Refresh() end
    end)
    panel.reindexButton:SetPoint("LEFT", panel.tutorialButton, "RIGHT", 8, 0)

    panel.checkRemindersButton = W:Button(panel, K.L.OPT_REMINDERS or "Check events now", 140, 22, function()
        local fired = K.Reminders:Check(true)
        if #fired == 0 then K:Print(K.L.NO_EVENTS or "No events with outstanding achievements right now.") end
    end)
    panel.checkRemindersButton:SetPoint("TOPLEFT", panel.openButton, "BOTTOMLEFT", 0, -8)

    panel.status = W:Label(panel, "", "GameFontDisableSmall")
    panel.status:SetPoint("TOPLEFT", panel.checkRemindersButton, "BOTTOMLEFT", 0, -16)
    panel.status:SetPoint("RIGHT", panel, "RIGHT", -16, 0)

    panel:SetScript("OnShow", function(self)
        local stats = K.Catalog:Stats()
        self.status:SetText(("%s: %d  •  %s: %d  •  %s: %d"):format(
            K.L.CATALOG or "Catalog", stats.total,
            K.L.HIDDEN or "Hidden", stats.hidden,
            K.L.STATISTICS or "Statistics", stats.statistics))
    end)

    return panel
end

function K.Settings:Register()
    if self._registered then return end
    local panel = BuildPanel()
    self.panel = panel

    local categoryID
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and category then
            Settings.RegisterAddOnCategory(category)
            categoryID = category:GetID()
        end
    else
        -- Pre-Dragonflight options API; only present on older clients.
        local legacyAdd = rawget(_G, "InterfaceOptions_AddCategory")
        if type(legacyAdd) == "function" then legacyAdd(panel) end
    end

    K._settingsCategoryID = categoryID
    self._registered = true
end

function K.Settings:Open()
    if not self._registered then self:Register() end
    if K._settingsCategoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(K._settingsCategoryID)
    elseif self.panel then
        local legacyOpen = rawget(_G, "InterfaceOptionsFrame_OpenToCategory")
        if type(legacyOpen) == "function" then
            legacyOpen(self.panel)
            legacyOpen(self.panel) -- twice on purpose for a legacy quirk
        end
    end
end
