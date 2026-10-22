local I = Iris
I.UI = {}
local U = I.UI

-- ==========================================
-- FABLENEON THEME (cosmetic only)
-- ==========================================
local FN_ACCENT = { 0.706, 0.361, 1.0, 1.0 } -- arcane purple

local function GetToolkit()
    return rawget(_G, "FabledUI_UIToolkit")
end

local function StyleButton(b)
    local TK = GetToolkit()
    if b and TK and TK.Themes and TK.Themes.StyleFlatButton then
        TK.Themes:StyleFlatButton(b, "FableNeon", FN_ACCENT)
    end
end

local function SaveWindowSoon()
    if not (I.Storage and I.Storage.SaveWindowState) then
        return
    end

    if I.Util and I.Util.SaveSoon then
        I.Util:SaveSoon("iris.window", function()
            I.Storage:SaveWindowState()
        end)
    else
        I.Storage:SaveWindowState()
    end
end

local COPY_ICON_FILE_ID = 134400

local function GetChatFrame(index)
    return _G["ChatFrame" .. tostring(index)]
end

local function GetChatTab(chatFrame)
    if not chatFrame or not chatFrame.GetName then
        return nil
    end

    return _G[chatFrame:GetName() .. "Tab"]
end

local function GetActiveChatFrame()
    if FCF_GetCurrentChatFrame then
        return FCF_GetCurrentChatFrame()
    end
    return DEFAULT_CHAT_FRAME
end

local function GetCopyLineLimit()
    local value = tonumber(I.settings and I.settings.copyLineLimit) or 250
    value = math.floor(value)
    if value < 25 then
        return 25
    end
    if value > 1000 then
        return 1000
    end
    return value
end

local function CaptureChatFrameLines(chatFrame)
    if not chatFrame or type(chatFrame.GetNumMessages) ~= "function" then
        return {}
    end

    local lineCount = chatFrame:GetNumMessages()
    local startIndex = math.max(1, lineCount - GetCopyLineLimit() + 1)
    local lines = {}

    for i = startIndex, lineCount do
        local message = chatFrame:GetMessageInfo(i)
        local safeMessage = I.Text and I.Text.SafeString and I.Text:SafeString(message) or ""
        if safeMessage ~= "" then
            lines[#lines + 1] = safeMessage
        end
    end

    return lines
end

function U:UpdateCountText(text)
    if not self.countText then
        return
    end

    local total = 0
    text = tostring(text or "")
    if text ~= "" then
        total = select(2, text:gsub("\n", "\n")) + 1
    end

    local label = string.format("Lines: %d", total)
    self.countText:SetText(label)
    if self.frame and self.frame.SetShellStatus then
        self.frame:SetShellStatus(label)
    end
end

function U:SetEditorText(text, highlightAll)
    self.edit:SetText(text or "")
    self.edit:SetCursorPosition(0)
    self:UpdateCountText(text)

    if highlightAll then
        self.edit:SetFocus()
        self.edit:HighlightText()
    else
        self.edit:ClearFocus()
        self.edit:HighlightText(0, 0)
    end
end

function U:BuildTextForMode(lines, mode)
    if mode == "raw" then
        return I.Text:BuildRawText(lines)
    elseif mode == "urls" then
        return I.Text:BuildURLText(lines)
    end

    return I.Text:BuildCleanText(lines)
end

-- The export editor and the settings surface occupy the same region, so exactly
-- one of them is visible at a time. The export-only footer buttons follow the
-- editor. Every tab is enabled except the active one.
function U:SetSurface(mode)
    self.mode = mode
    local showSettings = mode == "settings"

    self.scroll:SetShown(not showSettings)
    if self.settingsScroll then
        self.settingsScroll:SetShown(showSettings)
    end
    self.countText:SetShown(not showSettings)
    self.btnSelectAll:SetShown(not showSettings)
    self.btnCopyCurrent:SetShown(not showSettings)
    -- Already on the settings surface: the footer shortcut to it is noise.
    self.btnSettings:SetShown(not showSettings)

    self.tabRaw:SetEnabled(mode ~= "raw")
    self.tabClean:SetEnabled(mode ~= "clean")
    self.tabUrls:SetEnabled(mode ~= "urls")
    self.tabHistory:SetEnabled(mode ~= "history")
    self.tabSettings:SetEnabled(mode ~= "settings")

    local showSearch = mode == "history"
    self.search:SetShown(showSearch)
    self.searchLabel:SetShown(showSearch)
end

function U:ApplyChatFrameMode(chatFrame, mode)
    self.sourceChatFrame = chatFrame or GetActiveChatFrame()

    local frameName = self.sourceChatFrame and self.sourceChatFrame:GetName() or "Unknown"
    local lines = CaptureChatFrameLines(self.sourceChatFrame)
    local text = self:BuildTextForMode(lines, mode)

    self:SetSurface(mode)

    if mode == "raw" then
        self.hint:SetText("|cffaaaaaaRaw copy mode: original chat strings as captured from the frame.|r")
        self.frame:SetShellSubtitle(tostring(frameName) .. " / Raw")
    elseif mode == "urls" then
        self.hint:SetText("|cffaaaaaaURLs mode: extracts web links and email-style addresses from the captured chat.|r")
        self.frame:SetShellSubtitle(tostring(frameName) .. " / URLs")
    else
        self.hint:SetText("|cffaaaaaaClean copy mode: strips chat markup, icons, and link wrappers for readable text export.|r")
        self.frame:SetShellSubtitle(tostring(frameName) .. " / Clean")
    end

    self:SetEditorText(text, true)
    self.frame:ShowExpanded()
    self.frame:Raise()
end

function U:Create()
    if self.frame then
        return self.frame
    end

    local TK = GetToolkit()
    if not (TK and TK.Shell and type(TK.Shell.CreateWindow) == "function") then
        if not self._missingToolkitReported then
            self._missingToolkitReported = true
            I:Print("FabledUI_UIToolkit is unavailable; the Iris copy window cannot open.")
        end
        return nil
    end

    local frame = TK.Shell:CreateWindow("FabledUI_IrisFrame", {
        title = "FabledUI - Iris",
        subtitle = "Chat Utility Lite",
        theme = "FableNeon",
        accentColor = FN_ACCENT,
        frameStrata = "DIALOG",
        width = 840,
        height = 560,
        minWidth = 700,
        minHeight = 440,
        maxWidth = 1500,
        maxHeight = 1000,
        state = I.settings and I.settings.windowState or {},
        ribbon = false,
        resizable = true,
        onBoundsChanged = SaveWindowSoon,
        onDisplayStateChanged = SaveWindowSoon,
        onSizeChanged = function(_, width)
            if tonumber(width) then
                local inner = math.max(200, width - 70)
                if U.edit then
                    U.edit:SetWidth(inner)
                end
                if U.settingsPanel then
                    U.settingsPanel:SetWidth(inner)
                end
            end
        end,
    })
    if not frame then
        return nil
    end
    frame:SetToplevel(true)
    self.frame = frame
    self.title = frame.TitleText

    local content = frame.Content

    -- Five tabs share the row with the history search box, so they are narrower
    -- than the four-tab layout was.
    local TAB_WIDTH = 96

    self.tabRaw = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.tabRaw:SetSize(TAB_WIDTH, 22)
    self.tabRaw:SetPoint("TOPLEFT", 0, 0)
    self.tabRaw:SetText("Raw Copy")
    StyleButton(self.tabRaw)

    self.tabClean = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.tabClean:SetSize(TAB_WIDTH, 22)
    self.tabClean:SetPoint("LEFT", self.tabRaw, "RIGHT", 6, 0)
    self.tabClean:SetText("Clean Copy")
    StyleButton(self.tabClean)

    self.tabUrls = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.tabUrls:SetSize(TAB_WIDTH, 22)
    self.tabUrls:SetPoint("LEFT", self.tabClean, "RIGHT", 6, 0)
    self.tabUrls:SetText("URLs Only")
    StyleButton(self.tabUrls)

    self.tabHistory = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.tabHistory:SetSize(TAB_WIDTH, 22)
    self.tabHistory:SetPoint("LEFT", self.tabUrls, "RIGHT", 6, 0)
    self.tabHistory:SetText("History")
    StyleButton(self.tabHistory)

    self.tabSettings = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.tabSettings:SetSize(TAB_WIDTH, 22)
    self.tabSettings:SetPoint("LEFT", self.tabHistory, "RIGHT", 6, 0)
    self.tabSettings:SetText("Settings")
    StyleButton(self.tabSettings)

    -- 170 wide, not 230: the search box shares row one with the tab strip, and
    -- at the window's 700px minimum the two would otherwise overlap. Narrowing
    -- it keeps the five-tab row shorter overall than the old four-tab row.
    self.search = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    self.search:SetSize(170, 24)
    self.search:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 2)
    self.search:SetAutoFocus(false)

    self.searchLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.searchLabel:SetPoint("RIGHT", self.search, "LEFT", -8, 0)
    self.searchLabel:SetText("Search:")

    self.hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.hint:SetPoint("TOPLEFT", 0, -34)
    self.hint:SetJustifyH("LEFT")

    self.countText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countText:SetPoint("TOPRIGHT", 0, -34)
    self.countText:SetText("Lines: 0")

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -56)
    scroll:SetPoint("BOTTOMRIGHT", -20, 34)
    self.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetMaxLetters(0)
    edit:SetAutoFocus(false)
    edit:EnableMouse(true)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(math.max(200, frame:GetWidth() - 70))
    edit:SetScript("OnEscapePressed", function()
        frame:HideShell()
    end)
    edit:SetScript("OnTextChanged", function()
        scroll:UpdateScrollChildRect()
    end)
    scroll:SetScrollChild(edit)
    self.edit = edit

    -- Settings live on their own scrollable surface stacked in the same region
    -- as the export editor. Scrolled because the channel grid is taller than the
    -- window's minimum height.
    local settingsScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    settingsScroll:SetPoint("TOPLEFT", 0, -56)
    settingsScroll:SetPoint("BOTTOMRIGHT", -20, 34)
    settingsScroll:Hide()
    self.settingsScroll = settingsScroll

    local settingsPanel = CreateFrame("Frame", nil, settingsScroll)
    settingsPanel:SetSize(math.max(200, frame:GetWidth() - 70), 1)
    settingsScroll:SetScrollChild(settingsPanel)
    self.settingsPanel = settingsPanel

    if I.Settings and I.Settings.BuildPanel then
        I.Settings:BuildPanel(settingsPanel, {
            theme = "FableNeon",
            accent = FN_ACCENT,
        })
        settingsScroll:UpdateScrollChildRect()
    end

    local btnSelectAll = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnSelectAll:SetSize(120, 22)
    btnSelectAll:SetPoint("BOTTOMLEFT", 0, 0)
    btnSelectAll:SetText("Select All")
    btnSelectAll:SetScript("OnClick", function()
        self.edit:SetFocus()
        self.edit:HighlightText()
    end)
    StyleButton(btnSelectAll)
    self.btnSelectAll = btnSelectAll

    local btnCopyCurrent = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnCopyCurrent:SetSize(120, 22)
    btnCopyCurrent:SetPoint("LEFT", btnSelectAll, "RIGHT", 6, 0)
    btnCopyCurrent:SetText("Copy Active")
    btnCopyCurrent:SetScript("OnClick", function()
        local defaultMode = tostring(I.settings.defaultCopyMode or "clean")
        if defaultMode ~= "raw" and defaultMode ~= "clean" and defaultMode ~= "urls" then
            defaultMode = "clean"
        end
        self:ApplyChatFrameMode(GetActiveChatFrame(), defaultMode)
    end)
    StyleButton(btnCopyCurrent)
    self.btnCopyCurrent = btnCopyCurrent

    local btnSettings = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnSettings:SetSize(120, 22)
    btnSettings:SetPoint("BOTTOMRIGHT", 0, 0)
    btnSettings:SetText("Settings")
    btnSettings:SetScript("OnClick", function()
        self:OpenSettings()
    end)
    StyleButton(btnSettings)
    self.btnSettings = btnSettings

    self.tabRaw:SetScript("OnClick", function()
        self:OpenRawFromActiveChat()
    end)

    self.tabClean:SetScript("OnClick", function()
        self:OpenCleanFromActiveChat()
    end)

    self.tabUrls:SetScript("OnClick", function()
        self:OpenUrlsFromActiveChat()
    end)

    self.tabHistory:SetScript("OnClick", function()
        self:OpenHistory()
    end)

    self.tabSettings:SetScript("OnClick", function()
        self:OpenSettings()
    end)

    self.search:HookScript("OnTextChanged", function()
        if self.mode == "history" then
            self:RefreshHistory()
        end
    end)

    return frame
end

function U:RefreshHistory()
    if not I.History then
        return
    end

    local lines = I.History:Search(self.search:GetText() or "")
    self:SetEditorText(table.concat(lines, "\n"), false)
end

function U:OpenRawFromChatFrame(chatFrame)
    if not self:Create() then
        return
    end
    self:ApplyChatFrameMode(chatFrame, "raw")
end

function U:OpenCleanFromChatFrame(chatFrame)
    if not self:Create() then
        return
    end
    self:ApplyChatFrameMode(chatFrame, "clean")
end

function U:OpenUrlsFromChatFrame(chatFrame)
    if not self:Create() then
        return
    end
    self:ApplyChatFrameMode(chatFrame, "urls")
end

function U:OpenRawFromActiveChat()
    self:OpenRawFromChatFrame(GetActiveChatFrame())
end

function U:OpenCleanFromActiveChat()
    self:OpenCleanFromChatFrame(GetActiveChatFrame())
end

function U:OpenUrlsFromActiveChat()
    self:OpenUrlsFromChatFrame(GetActiveChatFrame())
end

function U:OpenHistory()
    if not self:Create() then
        return
    end

    self:SetSurface("history")
    self.hint:SetText("|cffaaaaaaHistory mode: search your locally stored capture buffer across supported chat buckets.|r")
    self.frame:SetShellSubtitle("History")

    self:RefreshHistory()
    self.frame:ShowExpanded()
    self.frame:Raise()
end

function U:OpenSettings()
    if not self:Create() then
        return
    end

    self:SetSurface("settings")
    self.hint:SetText("|cffaaaaaaSettings mode: changes apply immediately and are saved automatically.|r")
    self.frame:SetShellSubtitle("Settings")
    self.frame:SetShellStatus("Settings")

    -- Re-read the stored values: a slash command or the launcher may have
    -- changed them since this surface was last shown.
    if I.Settings and I.Settings.Refresh then
        I.Settings:Refresh()
    end

    self.frame:ShowExpanded()
    self.frame:Raise()
end

function U:CreateLauncherForChatFrame(chatFrame)
    if not chatFrame then
        return nil
    end

    local tab = GetChatTab(chatFrame)
    local parent = tab or chatFrame
    if not parent then
        return nil
    end

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(14, 14)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local normalTexture = button:CreateTexture(nil, "ARTWORK")
    normalTexture:SetAllPoints()
    normalTexture:SetTexture(COPY_ICON_FILE_ID)
    button:SetNormalTexture(normalTexture)

    local highlightTexture = button:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints()
    highlightTexture:SetTexture("Interface/Buttons/ButtonHilight-Square")
    highlightTexture:SetBlendMode("ADD")
    button:SetHighlightTexture(highlightTexture)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            self:OpenHistory()
        else
            local defaultMode = tostring(I.settings.defaultCopyMode or "clean")
            if defaultMode == "raw" then
                self:OpenRawFromChatFrame(chatFrame)
            elseif defaultMode == "urls" then
                self:OpenUrlsFromChatFrame(chatFrame)
            else
                self:OpenCleanFromChatFrame(chatFrame)
            end
        end
    end)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
        GameTooltip:AddLine("Iris", 0.0, 0.83, 1.0)
        GameTooltip:AddLine("Left-click: open default copy mode for this chat frame", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open global history", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    chatFrame.IrisCopyButton = button
    return button
end

function U:RefreshButtons()
    local shouldShow = I.settings.showCopyButton

    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = GetChatFrame(i)
        if chatFrame then
            local button = chatFrame.IrisCopyButton or self:CreateLauncherForChatFrame(chatFrame)
            local tab = GetChatTab(chatFrame)

            if button then
                button:ClearAllPoints()

                if tab then
                    button:SetParent(tab)
                    button:SetPoint("LEFT", tab, "RIGHT", 2, 0)
                    button:SetShown(shouldShow and tab:IsShown())
                else
                    button:SetParent(chatFrame)
                    button:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 2, 2)
                    button:SetShown(shouldShow)
                end
            end
        end
    end
end

function U:Init()
    if self._inited then
        return
    end
    self._inited = true

    self:Create()
    self:RefreshButtons()

    -- ChatFrame behavior is taint-sensitive. These are post-hooks only and do
    -- not replace Blizzard handlers, but the simulator has no secure boundary;
    -- opening/renaming chat windows still requires an in-game combat smoke test.
    hooksecurefunc("FCF_OpenNewWindow", function()
        self:RefreshButtons()
    end)

    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        self:RefreshButtons()
    end)

    -- FCFDock_UpdateTabs fires many times per Blizzard chat repaint (every
    -- tab anchor, every drag, every fade). Refreshing buttons inside that
    -- hot path re-parents every Iris button each invocation, which on a
    -- 10-window setup wastes a measurable chunk of frame budget. Coalesce
    -- to one refresh per frame via a "_buttonRefreshScheduled" flag.
    local function scheduleRefresh()
        if self._buttonRefreshScheduled then return end
        self._buttonRefreshScheduled = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                self._buttonRefreshScheduled = nil
                self:RefreshButtons()
            end)
        else
            self._buttonRefreshScheduled = nil
            self:RefreshButtons()
        end
    end

    hooksecurefunc("FCFDock_UpdateTabs", scheduleRefresh)
    hooksecurefunc("FCF_SetWindowName", scheduleRefresh)
end
