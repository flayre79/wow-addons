local I = Iris
I.Settings = {}
local S = I.Settings

-- Iris settings live entirely inside the Iris window. Nothing is registered
-- with Blizzard's options canvas: FabledUI_Nexus reaches this panel through
-- `settingsPath = "Settings.Open"` on its Iris registry entry, so the AddOns
-- options list carries no FabledUI page at all.

local CHANNEL_ORDER = {
    "SAY", "YELL", "EMOTE", "WHISPER", "BNET",
    "PARTY", "RAID", "RAID_WARNING", "INSTANCE", "GUILD",
    "OFFICER", "CHANNEL", "SYSTEM", "CREATURE",
}

local COPY_MODES = {
    { value = "raw", label = "Raw" },
    { value = "clean", label = "Clean" },
    { value = "urls", label = "URLs" },
}

local LEFT_MARGIN = 8
local BOX_SIZE = 22
local LABEL_GAP = 7
local ROW_HEIGHT = 27
local CHANNEL_COLUMNS = 3
local CHANNEL_COLUMN_WIDTH = 178
local CHANNEL_ROW_HEIGHT = 26

local function GetToolkit()
    return rawget(_G, "FabledUI_UIToolkit")
end

local function StyleText(fontString, style, muted)
    local TK = GetToolkit()
    if fontString and TK and TK.Themes and TK.Themes.ApplyBodyText then
        TK.Themes:ApplyBodyText(fontString, style.theme, style.accent, muted)
    end
end

-- Tint the tick/dot only. Effects:StyleCheckbox recolors the *normal* texture
-- with SetColorTexture, which replaces the box art with a flat accent fill and
-- turns every checkbox into a solid block, so it is deliberately not used here.
local function TintCheckMark(button, style)
    local accent = style.accent
    if type(accent) ~= "table" then
        return
    end

    local checkedTexture = button.GetCheckedTexture and button:GetCheckedTexture()
    if checkedTexture then
        checkedTexture:SetVertexColor(accent[1], accent[2], accent[3], accent[4] or 1)
    end
end

local function MakeCheckbox(parent, label, style, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(BOX_SIZE, BOX_SIZE)

    -- The template anchors its label flush against the box edge, which reads as
    -- overlapping text at this box size.
    cb.Text:ClearAllPoints()
    cb.Text:SetPoint("LEFT", cb, "RIGHT", LABEL_GAP, 0)
    cb.Text:SetText(label)
    StyleText(cb.Text, style)

    TintCheckMark(cb, style)
    cb:SetChecked(getValue() and true or false)
    cb:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
    end)

    cb.IrisRefresh = function(self)
        self:SetChecked(getValue() and true or false)
    end
    return cb
end

local function MakeRadio(parent, label, style, selectedValue, getValue, setValue)
    local button = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("LEFT", button, "RIGHT", LABEL_GAP, 0)
    button.text:SetText(label)
    StyleText(button.text, style)

    TintCheckMark(button, style)
    button:SetChecked(getValue() == selectedValue)
    button:SetScript("OnClick", function()
        setValue(selectedValue)
        S:Refresh()
    end)

    button.IrisRefresh = function(self)
        self:SetChecked(getValue() == selectedValue)
    end
    return button
end

local function MakeSectionHeader(parent, text, style, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", LEFT_MARGIN, y)
    fs:SetText(text)
    StyleText(fs, style)

    local accent = style.accent
    if type(accent) == "table" then
        fs:SetTextColor(accent[1], accent[2], accent[3], 1)
    end
    return fs
end

-- Build the real controls into `parent` (the Iris window's settings surface).
-- Returns the panel and the total laid-out height so the caller can size its
-- scroll child.
function S:BuildPanel(parent, style)
    if self.controls then
        return self.controls, self.contentHeight or 0
    end
    if not parent then
        return nil, 0
    end

    style = style or {}
    self.controls = parent
    self._refreshers = {}

    local function track(widget)
        if widget and widget.IrisRefresh then
            self._refreshers[#self._refreshers + 1] = widget
        end
        return widget
    end

    local y = -6

    local cbHistory = track(MakeCheckbox(parent, "Enable Global History Capture", style,
        function() return I.settings.enableHistory end,
        function(value) I.Storage:SetSetting("enableHistory", value) end))
    cbHistory:SetPoint("TOPLEFT", LEFT_MARGIN, y)
    y = y - ROW_HEIGHT

    local cbButtons = track(MakeCheckbox(parent, "Show Chat Tab Buttons", style,
        function() return I.settings.showCopyButton end,
        function(value)
            I.Storage:SetSetting("showCopyButton", value)
            if I.UI then
                I.UI:RefreshButtons()
            end
        end))
    cbButtons:SetPoint("TOPLEFT", LEFT_MARGIN, y)
    y = y - ROW_HEIGHT

    local cbTimestamps = track(MakeCheckbox(parent, "Include Timestamps In Saved History", style,
        function() return I.settings.includeTimestamps end,
        function(value) I.Storage:SetSetting("includeTimestamps", value) end))
    cbTimestamps:SetPoint("TOPLEFT", LEFT_MARGIN, y)
    y = y - 38

    MakeSectionHeader(parent, "Default Left-Click Copy Mode", style, y)
    y = y - 26

    local radioX = LEFT_MARGIN + 4
    for _, mode in ipairs(COPY_MODES) do
        local radio = track(MakeRadio(parent, mode.label, style, mode.value,
            function() return I.settings.defaultCopyMode end,
            function(value) I.Storage:SetSetting("defaultCopyMode", value) end))
        radio:SetPoint("TOPLEFT", radioX, y)
        radioX = radioX + 92
    end
    y = y - 38

    -- The slider's own value label is anchored above the bar, where it collides
    -- with this header, so the header carries the value and the label is blanked.
    local sizeHeader = MakeSectionHeader(parent, "History Size", style, y)
    y = y - 30

    local slider = CreateFrame("Slider", "FabledUIIrisHistorySizeSlider", parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", LEFT_MARGIN + 8, y)
    slider:SetWidth(280)
    slider:SetMinMaxValues(50, 5000)
    slider:SetValueStep(50)
    slider:SetObeyStepOnDrag(true)

    _G[slider:GetName() .. "Low"]:SetText("50")
    _G[slider:GetName() .. "High"]:SetText("5000")
    _G[slider:GetName() .. "Text"]:SetText("")

    local function SetSizeHeader(value)
        sizeHeader:SetText(string.format("History Size  -  %d stored lines", value))
    end

    -- SetValue before SetScript: assigning the stored value must not look like a
    -- user edit and write it straight back out.
    slider:SetValue(tonumber(I.settings.historySize) or 1000)
    SetSizeHeader(slider:GetValue())

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor((value / 50) + 0.5) * 50
        I.Storage:SetSetting("historySize", rounded)
        SetSizeHeader(rounded)

        if I.History then
            I.History:RingSetMax()
            -- Slider drag fires many OnValueChanged events; route through the
            -- debouncer so we land at most one SV write per second.
            if I.History.SaveSoon then
                I.History:SaveSoon()
            else
                I.History:Save()
            end
        end
    end)

    slider.IrisRefresh = function(self)
        local stored = tonumber(I.settings.historySize) or 1000
        if self:GetValue() ~= stored then
            self:SetValue(stored)
        end
        SetSizeHeader(stored)
    end
    track(slider)
    self.slider = slider
    y = y - 52

    MakeSectionHeader(parent, "Capture Channels", style, y)
    y = y - 26

    for index, channelKey in ipairs(CHANNEL_ORDER) do
        local cb = track(MakeCheckbox(parent, channelKey, style,
            function() return I.settings.channels and I.settings.channels[channelKey] end,
            function(value) I.Storage:SetChannel(channelKey, value) end))

        local col = (index - 1) % CHANNEL_COLUMNS
        local row = math.floor((index - 1) / CHANNEL_COLUMNS)
        cb:SetPoint("TOPLEFT", LEFT_MARGIN + (col * CHANNEL_COLUMN_WIDTH), y - (row * CHANNEL_ROW_HEIGHT))
    end

    local rows = math.ceil(#CHANNEL_ORDER / CHANNEL_COLUMNS)
    y = y - (rows * CHANNEL_ROW_HEIGHT) - 10

    self.contentHeight = math.abs(y)
    parent:SetHeight(self.contentHeight)

    return parent, self.contentHeight
end

-- Re-read every control from I.settings. Called when the settings surface is
-- shown, so a change made by a slash command or another panel is never stale.
function S:Refresh()
    if not self._refreshers then
        return
    end
    for _, widget in ipairs(self._refreshers) do
        local ok, err = pcall(widget.IrisRefresh, widget)
        if not ok then
            I:Print("settings refresh failed: " .. tostring(err))
        end
    end
end

-- Nexus calls this through its registry `settingsPath`. Keep the name stable.
function S:Open()
    if I.UI and I.UI.OpenSettings then
        I.UI:OpenSettings()
    end
end
