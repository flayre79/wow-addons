local P = _G.FabledUI_Poseidon
if not P then return end

P.UI = P.UI or {}
local UI = P.UI

local C_Timer = C_Timer
local UIParent = UIParent

local FULL_WIDTH = 940
local FULL_HEIGHT = 680
local COMPACT_WIDTH = 340
local COMPACT_HEIGHT = 390

local NAV_ITEMS = {
    { key = "overview", label = "Overview", icon = "Interface\\Icons\\Trade_Fishing" },
    { key = "zones", label = "Zones", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "fish", label = "Fish Index", icon = "Interface\\Icons\\INV_Misc_Fish_33" },
    { key = "nodes", label = "Nodes", icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman" },
    { key = "import", label = "Sharing", icon = "Interface\\Icons\\INV_Misc_Note_01" },
}

local COMPACT_ITEMS = {
    { key = "overview", label = "Overview", icon = "Interface\\Icons\\Trade_Fishing" },
    { key = "nodes", label = "Nodes", icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman" },
    { key = "fish", label = "Fish", icon = "Interface\\Icons\\INV_Misc_Fish_33" },
}

local CARD_TEXTURE = "Interface\\FrameGeneral\\UI-Background-Marble"
local PANEL_BG = { 0.030, 0.050, 0.095, 0.92 }
local CARD_BG = { 0.045, 0.070, 0.125, 0.95 }
local CARD_BORDER = { 0.240, 0.520, 0.620, 0.95 }
local CARD_SHADOW = { 0.000, 0.000, 0.000, 0.70 }
local GOLD = { 1.000, 0.840, 0.250 }
local TEAL = { 0.290, 0.910, 0.890 }
local SOFT = { 0.860, 0.910, 0.960 }
local MUTED = { 0.640, 0.760, 0.860 }
local ACCENT = { 0.480, 0.270, 0.780 }

local GetAttachMode

local function CopyColor(color)
    return color[1], color[2], color[3], color[4]
end

local function EnsureWidgets(container)
    container._poseidonWidgets = container._poseidonWidgets or {}
    return container._poseidonWidgets
end

local function Track(container, widget)
    local widgets = EnsureWidgets(container)
    widgets[#widgets + 1] = widget
    return widget
end

local function ClearContent(container)
    local widgets = container and container._poseidonWidgets
    if not widgets then
        return
    end
    for _, widget in ipairs(widgets) do
        if widget.Hide then widget:Hide() end
        if widget.SetParent then widget:SetParent(nil) end
    end
    wipe(widgets)
end

local function CreateBackdropFrame(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = CARD_TEXTURE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(CopyColor(CARD_BG))
    frame:SetBackdropBorderColor(CopyColor(CARD_BORDER))
    return frame
end

local function StyleFrameShell(frame)
    if not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop({
        bgFile = CARD_TEXTURE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 128,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(CopyColor(PANEL_BG))
    frame:SetBackdropBorderColor(0.20, 0.58, 0.68, 0.95)
end

local function JoinList(items)
    if type(items) ~= "table" or #items == 0 then
        return "None"
    end
    return table.concat(items, ", ")
end

local function GetSavedModeSize(mode)
    local ui = P.settings.ui
    if mode == "compact" then
        return ui.compactWidth or COMPACT_WIDTH, ui.compactHeight or COMPACT_HEIGHT
    end
    return ui.fullWidth or ui.width or FULL_WIDTH, ui.fullHeight or ui.height or FULL_HEIGHT
end

GetAttachMode = function()
    local mode = P.settings and P.settings.ui and P.settings.ui.attachMode
    if mode == "compact" then
        return "compact"
    end
    return "full"
end

local function IsCompactMode()
    return GetAttachMode() == "compact"
end

local function GetSavedPosition()
    local ui = P.settings.ui
    return ui.point or "CENTER", ui.relativePoint or "CENTER", ui.x or 0, ui.y or 0
end

local function SetFramePosition(frame)
    local point, relativePoint, x, y = GetSavedPosition()
    local width, height = GetSavedModeSize(GetAttachMode())
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:SetSize(width, height)
end

local function SaveFramePosition(frame)
    if not frame or not frame.GetPoint then
        return
    end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local ui = P.settings.ui
    ui.point = point
    ui.relativePoint = relativePoint
    ui.x = x
    ui.y = y
    local width = math.floor(frame:GetWidth() + 0.5)
    local height = math.floor(frame:GetHeight() + 0.5)
    if GetAttachMode() == "compact" then
        ui.compactWidth = width
        ui.compactHeight = height
    else
        ui.fullWidth = width
        ui.fullHeight = height
        ui.width = width
        ui.height = height
    end
    P:MarkDirty()
end

local function SafeDate(ts)
    if not ts or ts <= 0 then
        return "Unknown"
    end
    return date("%Y-%m-%d %H:%M", ts)
end

local function GetZoneInfo()
    return P.Stats and P.Stats.GetZoneInfo and P.Stats:GetZoneInfo() or {}
end

local function GetCurrentMapID()
    local info = GetZoneInfo()
    return info.mapID or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or nil
end

local function GetMapName(mapID)
    return P:GetMapName(mapID)
end

local function GetRecentCatchLines(limit)
    if not (P.Stats and P.Stats.GetTopEntries and P.db and P.db.stats and P.db.stats.session) then
        return { "No catches recorded yet." }
    end
    local lines = {}
    for _, entry in ipairs(P.Stats:GetTopEntries(P.db.stats.session.fish, limit or 4)) do
        lines[#lines + 1] = string.format("%s × %d", entry.name, entry.count)
    end
    if #lines == 0 then
        lines[1] = "No fish caught this session yet."
    end
    return lines
end

local function FormatTopList(entries, total, emptyText)
    if type(entries) ~= "table" or #entries == 0 then
        return emptyText or "Nothing logged yet."
    end
    local lines = {}
    local denominator = math.max(1, total or 0)
    for index, entry in ipairs(entries) do
        lines[#lines + 1] = string.format("%d. %s — %d (%.1f%%)", index, entry.name, entry.count, (entry.count / denominator) * 100)
    end
    return table.concat(lines, "\n")
end

local function GetActivePoolName()
    return P.State.activePool or P.State.lastPoolHover or (P.db and P.db.stats and P.db.stats.session and P.db.stats.session.lastPool) or "Open Water"
end

local function GetElapsedTextSafe(bucket)
    if P.Stats and P.Stats.GetElapsedText then
        return P.Stats:GetElapsedText(bucket)
    end
    return "0m"
end

local function GetViewportWidth(frame, compact)
    if not frame then
        return compact and 260 or 520
    end
    local shell = frame.contentShell
    local shellWidth = shell and shell.GetWidth and shell:GetWidth() or 0
    if shellWidth and shellWidth > 120 then
        local inner = math.floor(shellWidth - (compact and 28 or 42))
        if compact then
            return math.max(248, inner)
        end
        return math.max(500, inner)
    end
    local scrollWidth = frame.scroll and frame.scroll.GetWidth and frame.scroll:GetWidth() or 0
    if scrollWidth and scrollWidth > 80 then
        local inner = math.floor(scrollWidth - 30)
        if compact then
            return math.max(248, inner)
        end
        return math.max(500, inner)
    end
    return compact and 260 or 540
end

local function GetPoolVisual(poolName)
    local lower = type(poolName) == "string" and string.lower(poolName) or ""
    local icon = "Interface\\Icons\\Trade_Fishing"
    if lower:find("void") then
        icon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell"
    elseif lower:find("bloom") or lower:find("blossom") then
        icon = "Interface\\Icons\\INV_Misc_Herb_AncientLichen"
    elseif lower:find("treasure") or lower:find("cargo") then
        icon = "Interface\\Icons\\INV_Crate_04"
    elseif lower:find("surge") or lower:find("torrent") or lower:find("waves") then
        icon = "Interface\\Icons\\Ability_Shaman_HealingRain"
    elseif lower:find("school") or lower:find("swarm") or lower:find("ripple") then
        icon = "Interface\\Icons\\INV_Misc_Fish_33"
    end
    return icon
end

local function CreateText(parent, layer, template, text, color)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
    if text then
        fs:SetText(text)
    end
    if color then
        fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    return fs
end

local function AddWrappedText(container, parent, text, point, rel, relPoint, x, y, width, template, color)
    local fs = Track(container, CreateText(parent, "OVERLAY", template or "GameFontHighlight", text or "", color or SOFT))
    fs:SetPoint(point, rel or parent, relPoint or point, x or 0, y or 0)
    fs:SetWidth(width or 300)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    fs:SetNonSpaceWrap(true)
    return fs
end

local function CreateAccentBar(parent, height, color)
    local bar = parent:CreateTexture(nil, "BORDER")
    bar:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    bar:SetPoint("TOPLEFT", 6, -6)
    bar:SetPoint("TOPRIGHT", -6, -6)
    bar:SetHeight(height or 3)
    return bar
end

local function CreateSoftGlow(parent, color)
    local glow = parent:CreateTexture(nil, "BACKGROUND")
    glow:SetColorTexture(color[1], color[2], color[3], 0.10)
    glow:SetPoint("TOPLEFT", 8, -8)
    glow:SetPoint("BOTTOMRIGHT", -8, 8)
    return glow
end

local function CreateCard(container, parent, x, y, width, height, title, icon, accentColor)
    local card = Track(container, CreateBackdropFrame(parent))
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    CreateSoftGlow(card, accentColor or TEAL)
    CreateAccentBar(card, 3, accentColor or TEAL)

    local iconTex = Track(container, card:CreateTexture(nil, "ARTWORK"))
    iconTex:SetSize(20, 20)
    iconTex:SetPoint("TOPLEFT", 14, -14)
    iconTex:SetTexture(icon or "Interface\\Icons\\Trade_Fishing")

    local titleFS = Track(container, CreateText(card, "OVERLAY", "GameFontNormalLarge", title or "", GOLD))
    titleFS:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
    titleFS:SetJustifyH("LEFT")

    card.icon = iconTex
    card.titleFS = titleFS
    card.accentColor = accentColor or TEAL
    return card
end

local function CreateStyledButton(parent, width, height, label, icon, accent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({
        bgFile = CARD_TEXTURE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.050, 0.070, 0.110, 0.98)
    button:SetBackdropBorderColor(0.160, 0.330, 0.420, 0.95)

    local glow = button:CreateTexture(nil, "BACKGROUND")
    glow:SetColorTexture((accent or TEAL)[1], (accent or TEAL)[2], (accent or TEAL)[3], 0.14)
    glow:SetPoint("TOPLEFT", 6, -6)
    glow:SetPoint("BOTTOMRIGHT", -6, 6)
    button.glow = glow

    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture((accent or TEAL)[1], (accent or TEAL)[2], (accent or TEAL)[3], 0.16)
    hl:SetPoint("TOPLEFT", 2, -2)
    hl:SetPoint("BOTTOMRIGHT", -2, 2)

    local iconTex = button:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(16, 16)
    iconTex:SetPoint("LEFT", 10, 0)
    iconTex:SetTexture(icon or "Interface\\Icons\\Trade_Fishing")
    button.icon = iconTex

    local text = CreateText(button, "OVERLAY", "GameFontNormal", label or "", SOFT)
    text:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    button.text = text

    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropBorderColor((accent or TEAL)[1], (accent or TEAL)[2], (accent or TEAL)[3], 1)
    end)
    button:SetScript("OnMouseUp", function(self)
        if self._selected then
            self:SetBackdropBorderColor((accent or TEAL)[1], (accent or TEAL)[2], (accent or TEAL)[3], 1)
        else
            self:SetBackdropBorderColor(0.160, 0.330, 0.420, 0.95)
        end
    end)

    function button:SetSelected(selected)
        self._selected = selected and true or false
        if self._selected then
            self:SetBackdropColor(0.070, 0.090, 0.160, 1)
            self:SetBackdropBorderColor((accent or TEAL)[1], (accent or TEAL)[2], (accent or TEAL)[3], 1)
            self.glow:SetAlpha(0.24)
            self.text:SetTextColor(1.0, 0.94, 0.60)
        else
            self:SetBackdropColor(0.050, 0.070, 0.110, 0.98)
            self:SetBackdropBorderColor(0.160, 0.330, 0.420, 0.95)
            self.glow:SetAlpha(1)
            self.text:SetTextColor(SOFT[1], SOFT[2], SOFT[3])
        end
    end

    button:SetSelected(false)
    return button
end

local function SetButtonText(button, text)
    if button and button.text then
        button.text:SetText(text)
    elseif button and button.SetText then
        button:SetText(text)
    end
end

local function MakeActionButton(parent, label, icon, accent, onClick)
    local button = CreateStyledButton(parent, 112, 26, label, icon, accent)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

local function CreateBadge(parent, text, color)
    local badge = CreateBackdropFrame(parent)
    badge:SetHeight(22)
    local fs = CreateText(badge, "OVERLAY", "GameFontNormalSmall", text or "", SOFT)
    fs:SetPoint("CENTER")
    badge.text = fs
    badge:SetBackdropColor(0.080, 0.100, 0.160, 0.95)
    badge:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    badge:SetWidth(math.max(72, fs:GetStringWidth() + 18))
    CreateSoftGlow(badge, color)
    return badge
end

function UI:GetModeLabel()
    return IsCompactMode() and "Compact" or "Full"
end

function UI:SetStatus(message, mode)
    if not self.frame then
        return
    end
    if self.frame.statusText then
        self.frame.statusText:SetText(message or "")
    end
    if self.frame.modeText then
        self.frame.modeText:SetText(mode or self:GetModeLabel())
    end
end

function UI:UpdateAttachButton()
    return
end

function UI:ApplySettings()
    if not self.frame then
        return
    end
    self.frame:SetScale(P.settings.uiScale or 1)
    self.frame:SetAlpha(P.settings.uiAlpha or 1)
    self.frame:SetMovable(not P.settings.ui.locked)
end

function UI:ApplyLayoutMode()
    if not self.frame then
        return
    end

    local frame = self.frame
    local compact = IsCompactMode()
    local width, height = GetSavedModeSize(compact and "compact" or "full")
    frame:SetSize(width, height)

    if compact then
        frame.navShell:Hide()
        frame.compactTabs:Show()
        frame.actionBar:Hide()
        frame.modeText:Hide()
        frame.statusText:SetWidth(math.max(160, width - 120))
        frame.contentShell:ClearAllPoints()
        frame.contentShell:SetPoint("TOPLEFT", 14, -122)
        frame.contentShell:SetPoint("BOTTOMRIGHT", -14, 16)
        frame.compactTabs:ClearAllPoints()
        frame.compactTabs:SetPoint("TOPLEFT", 14, -88)
        frame.compactTabs:SetPoint("TOPRIGHT", -14, -88)
        frame.compactTabs:SetHeight(34)
        if self.modeButton then SetButtonText(self.modeButton, "Open Full") end
    else
        frame.navShell:Show()
        frame.compactTabs:Hide()
        frame.actionBar:Show()
        frame.modeText:Show()
        frame.statusText:SetWidth(420)
        frame.contentShell:ClearAllPoints()
        frame.contentShell:SetPoint("TOPLEFT", frame.navShell, "TOPRIGHT", 10, 0)
        frame.contentShell:SetPoint("BOTTOMRIGHT", -20, 16)
        if self.modeButton then SetButtonText(self.modeButton, "Compact") end
    end

    if frame.content then
        frame.content:SetWidth(GetViewportWidth(frame, compact))
    end
end

function UI:WatchHost(host)
    return
end

function UI:FindVisibleHostFrame()
    return nil
end

function UI:TryAttachToHost(force)
    if self.frame then
        SetFramePosition(self.frame)
        self:SetStatus("Free-floating fishing companion.", self:GetModeLabel())
    end
    return false
end

function UI:QueueAttachRetries()
    if self.frame then
        SetFramePosition(self.frame)
        self:SetStatus("Free-floating fishing companion.", self:GetModeLabel())
    end
end

local function SetSelectedViewForCompact(key)
    if key ~= "overview" and key ~= "nodes" and key ~= "fish" then
        return "overview"
    end
    return key
end

function UI:ShowTab(key)
    self:Init()
    if IsCompactMode() then
        key = SetSelectedViewForCompact(key)
    end
    P.settings.ui.selectedView = key
    self.frame:Show()
    self:ApplyLayoutMode()
    SetFramePosition(self.frame)
    self:SetStatus("Free-floating fishing companion.", self:GetModeLabel())
    self:Refresh()
    P:MarkDirty()
end

function UI:ShowNode(mapID, coordKey)
    self.selectedMapID = mapID
    self.selectedCoordKey = coordKey
    self:ShowTab("nodes")
end

function UI:Show()
    self:Init()
    self.frame:Show()
    self:ApplyLayoutMode()
    self:ApplySettings()
    SetFramePosition(self.frame)
    self:SetStatus("Free-floating fishing companion.", self:GetModeLabel())
    self:Refresh()
end

function UI:Toggle()
    self:Init()
    self.frame:SetShown(not self.frame:IsShown())
    if self.frame:IsShown() then
        self:ApplyLayoutMode()
        self:ApplySettings()
        SetFramePosition(self.frame)
        self:SetStatus("Free-floating fishing companion.", self:GetModeLabel())
        self:Refresh()
    end
end

local function AddDetailRows(container, card, rows, width)
    local y = -42
    for _, row in ipairs(rows) do
        local label = Track(container, CreateText(card, "OVERLAY", "GameFontNormalSmall", row.label, GOLD))
        label:SetPoint("TOPLEFT", 16, y)
        local value = Track(container, CreateText(card, "OVERLAY", row.template or "GameFontHighlight", row.value or "", row.color or SOFT))
        value:SetPoint("TOPLEFT", 16, y - 16)
        value:SetWidth(width or (card:GetWidth() - 32))
        value:SetJustifyH("LEFT")
        value:SetJustifyV("TOP")
        value:SetWordWrap(true)
        value:SetNonSpaceWrap(true)
        y = y - (row.height or 44)
    end
end

local function AddStatPill(container, parent, x, y, width, title, value, accent, icon)
    local pill = CreateCard(container, parent, x, y, width, 72, title, icon, accent)
    local valueFS = AddWrappedText(container, pill, tostring(value or "0"), "TOPLEFT", pill, "TOPLEFT", 16, -40, width - 32, "GameFontNormalLarge", SOFT)
    valueFS:SetJustifyH("LEFT")
    return pill
end

function UI:RenderOverview()
    local content = self.frame.content
    local compact = IsCompactMode()
    local zoneInfo = GetZoneInfo()
    local currentMapID = zoneInfo.mapID or GetCurrentMapID()
    local mapName = zoneInfo.subZone or zoneInfo.mapName or GetMapName(currentMapID) or "Unknown Waters"
    local overview = P.Stats and P.Stats.GetOverviewData and P.Stats:GetOverviewData() or {}
    local session = overview.session or {}
    local lifetime = overview.lifetime or {}
    local totalNodes, totalFishLinks = P.Nodes:GetNodeTotals()
    local currentMapNodes = currentMapID and #(P.Nodes:IterateNodes(currentMapID)) or 0
    local currentPool = GetActivePoolName()
    local poolStats = P.Nodes:GetPoolStats(currentPool, currentMapID)
    local poolData = P.MapTooltip and P.MapTooltip.GetPoolData and P.MapTooltip:GetPoolData(currentPool, currentMapID) or nil
    local width = GetViewportWidth(self.frame, compact)
    local gap = compact and 10 or 12
    local y = -8
    local success = P.Stats and P.Stats:GetSuccessRate(session) or 0
    local fishHour = P.Stats and P.Stats:GetFishPerHour(session) or 0
    local learned = (poolStats and poolStats.learned and #poolStats.learned > 0) and table.concat(poolStats.learned, ", ") or "Nothing learned here yet"
    local possible = (poolData and poolData.possible and #poolData.possible > 0) and table.concat(poolData.possible, ", ") or "No static data yet"

    if compact then
        local hero = CreateCard(content, content, 0, y, width, 78, mapName, GetPoolVisual(currentPool), ACCENT)
        AddWrappedText(content, hero, string.format("%d casts  ·  %d catches  ·  %.1f%% success", session.casts or 0, session.catches or 0, success), "TOPLEFT", hero, "TOPLEFT", 16, -40, width - 32, "GameFontHighlight", SOFT)
        y = y - hero:GetHeight() - gap

        local sessionCard = CreateCard(content, content, 0, y, width, 134, "Session", "Interface\\Icons\\Ability_Hunter_FocusedAim", TEAL)
        AddDetailRows(content, sessionCard, {
            { label = "Fish / Hour", value = string.format("%.1f", fishHour), height = 32 },
            { label = "Elapsed", value = GetElapsedTextSafe(session), height = 32 },
            { label = "Top Catch", value = GetRecentCatchLines(1)[1] or "None yet", height = 36 },
        }, width - 32)
        y = y - sessionCard:GetHeight() - gap

        local poolCard = CreateCard(content, content, 0, y, width, 170, currentPool, GetPoolVisual(currentPool), ACCENT)
        AddDetailRows(content, poolCard, {
            { label = "Seen Here", value = tostring(poolStats and poolStats.seenCount or 0), height = 30 },
            { label = "Learned", value = learned, height = 46 },
            { label = "Possible", value = possible, height = 54 },
        }, width - 32)
        y = y - poolCard:GetHeight() - gap

        local activityCard = CreateCard(content, content, 0, y, width, 126, "Recent Activity", "Interface\\Icons\\INV_Misc_Note_01", TEAL)
        AddDetailRows(content, activityCard, {
            { label = "Recent Fish", value = table.concat(GetRecentCatchLines(3), "\n"), height = 42 },
            { label = "Recent Pools", value = (#P.State.recentNodes > 0 and string.format("• %s", P.State.recentNodes[1].name or "Unknown")) or "• No pools logged yet.", height = 32 },
        }, width - 32)
        y = y - activityCard:GetHeight() - gap

        local footer = CreateCard(content, content, 0, y, width, 62, "Open Full Window", "Interface\\Icons\\INV_Misc_Book_11", TEAL)
        local btn = Track(content, MakeActionButton(footer, "Open Full", "Interface\\Icons\\INV_Misc_Book_11", ACCENT, function()
            P.settings.ui.attachMode = "full"
            UI:ApplyLayoutMode()
            UI:Refresh()
            P:MarkDirty()
        end))
        btn:SetPoint("TOPLEFT", 16, -28)
        y = y - footer:GetHeight() - gap
    else
        local hero = CreateCard(content, content, 0, y, width, 94, mapName, GetPoolVisual(currentPool), ACCENT)
        AddWrappedText(content, hero, "Arcane-water intelligence for your current fishing run.", "TOPLEFT", hero, "TOPLEFT", 16, -40, width - 32, "GameFontHighlightSmall", MUTED)
        local statsLine = string.format("Casts %d   ·   Catches %d   ·   Success %.1f%%   ·   Fish/Hour %.1f", session.casts or 0, session.catches or 0, success, fishHour)
        AddWrappedText(content, hero, statsLine, "TOPLEFT", hero, "TOPLEFT", 16, -64, width - 32, "GameFontHighlight", SOFT)
        y = y - hero:GetHeight() - gap

        local left = math.floor((width - gap) * 0.50)
        local right = width - gap - left

        local sessionCard = CreateCard(content, content, 0, y, left, 190, "Session Snapshot", "Interface\\Icons\\Ability_Hunter_FocusedAim", TEAL)
        AddDetailRows(content, sessionCard, {
            { label = "Zone", value = mapName, height = 34 },
            { label = "Casts / Catches", value = string.format("%d / %d", session.casts or 0, session.catches or 0), height = 34 },
            { label = "Success", value = string.format("%.1f%%", success), height = 34 },
            { label = "Elapsed", value = GetElapsedTextSafe(session), height = 34 },
        }, left - 32)

        local poolCard = CreateCard(content, content, left + gap, y, right, 190, currentPool, GetPoolVisual(currentPool), ACCENT)
        AddDetailRows(content, poolCard, {
            { label = "Seen on this map", value = tostring(poolStats and poolStats.seenCount or 0), height = 32 },
            { label = "Learned Here", value = learned, height = 52 },
            { label = "Possible Here", value = possible, height = 58 },
        }, right - 32)
        y = y - 190 - gap

        local zoneCard = CreateCard(content, content, 0, y, left, 176, "Zone Totals", "Interface\\Icons\\INV_Misc_Map_01", TEAL)
        AddDetailRows(content, zoneCard, {
            { label = "Current Zone", value = mapName, height = 34 },
            { label = "Tracked Nodes on This Map", value = tostring(currentMapNodes), height = 34 },
            { label = "All Nodes", value = tostring(totalNodes), height = 30 },
            { label = "Learned Fish Links", value = tostring(totalFishLinks), height = 30 },
        }, left - 32)

        local activityCard = CreateCard(content, content, left + gap, y, right, 176, "Recent Activity", "Interface\\Icons\\INV_Misc_Note_01", ACCENT)
        local recentPools = {}
        for index = 1, math.min(4, #P.State.recentNodes) do
            local entry = P.State.recentNodes[index]
            recentPools[#recentPools + 1] = string.format("• %s", entry.name or "Unknown")
        end
        if #recentPools == 0 then recentPools[1] = "• No recent pools logged yet." end
        AddDetailRows(content, activityCard, {
            { label = "Recent Fish", value = table.concat(GetRecentCatchLines(4), "\n"), height = 50 },
            { label = "Recent Pools", value = table.concat(recentPools, "\n"), height = 54 },
        }, right - 32)
        y = y - 176 - gap

        local derbyHeight = 116
        local derbyCard = CreateCard(content, content, 0, y, left, derbyHeight, "Tournament Watch", "Interface\\Icons\\Achievement_Zone_ArgentTournament", GOLD)
        local derbyActive = P.Derby and P.Derby.IsActive and P.Derby:IsActive()
        local derbyTop = (P.Derby and next(P.Derby.catches or {})) and FormatTopList(P.Stats and P.Stats.GetTopEntries and P.Stats:GetTopEntries(P.Derby.catches, 3) or {}, nil, "No derby catches logged yet.") or "No derby catches logged yet."
        AddDetailRows(content, derbyCard, {
            { label = "Status", value = derbyActive and "Active now" or "Idle", height = 28 },
            { label = "Buff", value = (P.Data and P.Data.DERBY_BUFF) or "Derby Dasher", height = 28 },
            { label = "Tracked Derby Fish", value = derbyTop, height = 48 },
        }, left - 32)

        local lifeCard = CreateCard(content, content, left + gap, y, right, derbyHeight, "Lifetime Ledger", "Interface\\Icons\\INV_Misc_Fish_13", TEAL)
        AddDetailRows(content, lifeCard, {
            { label = "Lifetime Casts / Catches", value = string.format("%d / %d", lifetime.casts or 0, lifetime.catches or 0), height = 28 },
            { label = "Lifetime Success", value = string.format("%.1f%%", P.Stats and P.Stats:GetSuccessRate(lifetime) or 0), height = 28 },
            { label = "Top Lifetime Catches", value = FormatTopList(P.Stats and P.Stats.GetTopEntries and P.Stats:GetTopEntries(lifetime.fish, 3) or {}, lifetime.catches, "No fish logged yet."), height = 48 },
        }, right - 32)
        y = y - derbyHeight - gap
    end

    content:SetHeight(math.max(1, math.abs(y) + 24))
end

function UI:RenderZones()
    local content = self.frame.content
    local compact = IsCompactMode()
    local data = P.Data.Midnight or {}
    local width = GetViewportWidth(self.frame, compact)
    local cardWidth = compact and width or math.floor((width - 12) / 2)
    local y = -8

    local intro = CreateCard(content, content, 0, y, width, 94, "Midnight Zone Progression", "Interface\\Icons\\INV_Misc_Map_01", ACCENT)
    AddWrappedText(content, intro, "Fish smarter by staying in the right bracket longer. These cards are tuned for the actual leveling rhythm you described instead of Blizzard's vague little shrug.", "TOPLEFT", intro, "TOPLEFT", 16, -42, width - 32, "GameFontHighlight", SOFT)
    y = y - intro:GetHeight() - 12

    local skillBrackets = data.skillBrackets or {}
    local col = 0
    local rowHeight = 132
    for index, bracket in ipairs(skillBrackets) do
        local x = compact and 0 or ((col == 0) and 0 or (cardWidth + 12))
        local card = CreateCard(content, content, x, y, cardWidth, rowHeight, bracket.zone or "Unknown Zone", "Interface\\Icons\\Achievement_Zone_Quelthalas_01", TEAL)
        AddDetailRows(content, card, {
            { label = "Skill Bracket", value = string.format("%d - %d", bracket.minSkill or 0, bracket.maxSkill or 0) },
            { label = "Recommendation", value = bracket.note or "No note yet.", height = 62 },
        }, cardWidth - 32)
        if compact or col == 1 then
            y = y - rowHeight - 12
        end
        col = compact and 0 or ((col + 1) % 2)
    end

    local zoneOrder = { "Eversong Woods", "Zul'Aman", "Harandar", "Voidstorm", "The Coiled Isle" }
    for _, zoneName in ipairs(zoneOrder) do
        local zone = data.zones and data.zones[zoneName]
        if zone then
            local card = CreateCard(content, content, 0, y, width, 148, zoneName, "Interface\\Icons\\INV_Misc_Map_01", ACCENT)
            AddDetailRows(content, card, {
                { label = "Recommended Window", value = zone.recommended or "Unknown" },
                { label = "Known Pools", value = JoinList(zone.pools), height = 50 },
                { label = "Field Notes", value = table.concat(zone.notes or {}, "\n"), height = 64 },
            }, width - 32)
            y = y - card:GetHeight() - 12
        end
    end

    local specials = data.specialPools or {}
    if #specials > 0 then
        local header = CreateCard(content, content, 0, y, width, 84, "Rare & Special Pools", "Interface\\Icons\\INV_Crate_04", TEAL)
        AddWrappedText(content, header, "Treasure pools, void pools, and oddities worth stalking when they appear.", "TOPLEFT", header, "TOPLEFT", 16, -42, width - 32, "GameFontHighlight", SOFT)
        y = y - header:GetHeight() - 12
        for _, pool in ipairs(specials) do
            local card = CreateCard(content, content, 0, y, width, 108, pool.name or "Unknown Pool", GetPoolVisual(pool.name), ACCENT)
            AddDetailRows(content, card, {
                { label = "Contains", value = pool.contains or "Unknown" },
                { label = "Notes", value = pool.notes or "No notes.", height = 52 },
            }, width - 32)
            y = y - card:GetHeight() - 12
        end
    end

    content:SetHeight(math.max(1, math.abs(y) + 24))
end

function UI:RenderFish()
    local content = self.frame.content
    local compact = IsCompactMode()
    local data = P.Data.Midnight or {}
    local width = GetViewportWidth(self.frame, compact)
    local y = -8

    local snapshot = CreateCard(content, content, 0, y, width, 108, "Catalog Snapshot", "Interface\\Icons\\INV_Misc_Fish_33", TEAL)
    local lifetime = P.db and P.db.stats and P.db.stats.lifetime or {}
    AddWrappedText(content, snapshot,
        string.format("Lifetime catches: %d\nUnique fish tracked: %d\nTop catches:\n%s",
            lifetime.catches or 0,
            lifetime.fish and (function(t) local c=0 for _ in pairs(t) do c=c+1 end return c end)(lifetime.fish) or 0,
            FormatTopList(P.Stats and P.Stats.GetTopEntries and P.Stats:GetTopEntries(lifetime.fish, 3) or {}, lifetime.catches, "No fish logged yet.")
        ),
        "TOPLEFT", snapshot, "TOPLEFT", 16, -42, width - 32, "GameFontHighlight", SOFT)
    y = y - snapshot:GetHeight() - 12

    local groups = {
        { key = "common", label = "Common Fish", accent = TEAL },
        { key = "uncommon", label = "Uncommon Fish", accent = ACCENT },
        { key = "rare", label = "Rare Fish", accent = GOLD },
        { key = "cursed", label = "Cursed Fish", accent = ACCENT },
    }

    for _, group in ipairs(groups) do
        local list = (data.fish and data.fish[group.key]) or {}
        if #list > 0 then
            local titleCard = CreateCard(content, content, 0, y, width, 72, group.label, "Interface\\Icons\\INV_Misc_Fish_13", group.accent)
            AddWrappedText(content, titleCard, string.format("%d entries in this rarity band.", #list), "TOPLEFT", titleCard, "TOPLEFT", 16, -42, width - 32, "GameFontHighlightSmall", MUTED)
            y = y - titleCard:GetHeight() - 10
            for _, fish in ipairs(list) do
                local cardHeight = fish.special and 176 or 160
                local card = CreateCard(content, content, 0, y, width, cardHeight, fish.name or "Unknown Fish", "Interface\\Icons\\INV_Misc_Fish_33", group.accent)
                local catches = lifetime.fish and lifetime.fish[fish.name] or 0
                AddDetailRows(content, card, {
                    { label = "Zones", value = JoinList(fish.zones), height = 48 },
                    { label = "Pools", value = JoinList(fish.pools), height = 68 },
                    { label = fish.special and "Special" or "Lifetime Catches", value = fish.special or tostring(catches), height = fish.special and 44 or 30 },
                }, width - 32)
                y = y - card:GetHeight() - 10
            end
        end
    end

    local notes = data.valueNotes or {}
    if #notes > 0 then
        local noteCard = CreateCard(content, content, 0, y, width, 138, "Market & Utility Notes", "Interface\\Icons\\INV_Misc_Coin_01", ACCENT)
        AddWrappedText(content, noteCard, table.concat(notes, "\n"), "TOPLEFT", noteCard, "TOPLEFT", 16, -42, width - 32, "GameFontHighlight", SOFT)
        y = y - noteCard:GetHeight() - 12
    end

    content:SetHeight(math.max(1, math.abs(y) + 24))
end

function UI:RenderNodes()
    local content = self.frame.content
    local compact = IsCompactMode()
    local width = GetViewportWidth(self.frame, compact)
    local y = -8
    local currentMapID = GetCurrentMapID()
    local mapID = self.selectedMapID or currentMapID
    local nodes = P.Nodes:IterateNodes(mapID)

    local header = CreateCard(content, content, 0, y, width, 88, "Tracked Nodes", "Interface\\Icons\\Ability_Hunter_MasterMarksman", TEAL)
    AddWrappedText(content, header, string.format("Browsing %s. Pick a node to inspect its learned fish, seen count, and notes.", GetMapName(mapID)), "TOPLEFT", header, "TOPLEFT", 16, -42, width - 32, "GameFontHighlight", SOFT)
    y = y - header:GetHeight() - 12

    local toolbar = CreateCard(content, content, 0, y, width, 68, "Actions", "Interface\\Icons\\INV_Misc_Gear_01", ACCENT)
    local allBtn = Track(content, MakeActionButton(toolbar, "All Maps", "Interface\\Icons\\INV_Misc_Map_01", TEAL, function()
        UI.selectedMapID = nil
        UI.selectedCoordKey = nil
        UI:Refresh()
    end))
    allBtn:SetPoint("TOPLEFT", 16, -34)
    local refreshBtn = Track(content, MakeActionButton(toolbar, "Refresh", "Interface\\Icons\\INV_Misc_Refresh", ACCENT, function() UI:Refresh() end))
    refreshBtn:SetPoint("LEFT", allBtn, "RIGHT", 8, 0)
    local exportBtn = Track(content, MakeActionButton(toolbar, "Export", "Interface\\Icons\\INV_Misc_Note_01", TEAL, function()
        if P.ImportExport then
            P.ImportExport:OpenExportWindow()
            if P.ImportExport.editBox then
                P.ImportExport.editBox:SetText(P.ImportExport:SerializeNodes(UI.selectedMapID))
                P.ImportExport.editBox:HighlightText()
            end
        end
    end))
    exportBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
    y = y - toolbar:GetHeight() - 12

    local listHeight = math.max(180, math.min(260, 68 + (#nodes * 28)))
    local listCard = CreateCard(content, content, 0, y, width, listHeight, "Node List", "Interface\\Icons\\Ability_Hunter_MasterMarksman", TEAL)
    local listFrame = Track(content, CreateBackdropFrame(listCard))
    listFrame:SetPoint("TOPLEFT", 14, -42)
    listFrame:SetPoint("BOTTOMRIGHT", -14, 12)
    listFrame:SetBackdropColor(0.030, 0.050, 0.090, 0.88)
    y = y - listCard:GetHeight() - 12

    local selected = nil
    local top = -14
    if #nodes == 0 then
        AddWrappedText(content, listFrame, "No nodes recorded for this map yet. Go fish something suspicious.", "TOPLEFT", listFrame, "TOPLEFT", 12, top, width - 60, "GameFontHighlight", MUTED)
    else
        for index, entry in ipairs(nodes) do
            local btn = Track(content, CreateStyledButton(listFrame, width - 60, 24, string.format("%d. %s — %s (%.1f, %.1f)", index, entry.name or "Unknown", entry.mapName or GetMapName(entry.mapID), (entry.x or 0) * 100, (entry.y or 0) * 100), GetPoolVisual(entry.name), (entry.coordKey == self.selectedCoordKey) and ACCENT or TEAL))
            btn:SetPoint("TOPLEFT", 12, top)
            btn:SetPoint("RIGHT", -12, 0)
            btn:SetScript("OnClick", function()
                UI.selectedMapID = entry.mapID
                UI.selectedCoordKey = entry.coordKey
                UI:Refresh()
            end)
            btn:SetSelected(entry.coordKey == self.selectedCoordKey)
            top = top - 28
            if entry.coordKey == self.selectedCoordKey or (not selected and index == 1) then
                selected = entry
            end
        end
    end

    if selected then
        local detailHeight = compact and 252 or 232
        local detail = CreateCard(content, content, 0, y, width, detailHeight, selected.name or "Node Details", GetPoolVisual(selected.name), ACCENT)
        local fishNames = {}
        if selected.fishNames then
            for name in pairs(selected.fishNames) do
                fishNames[#fishNames + 1] = name
            end
            table.sort(fishNames)
        end
        AddDetailRows(content, detail, {
            { label = "Map", value = selected.mapName or GetMapName(selected.mapID) },
            { label = "Coords", value = string.format("%.1f, %.1f", (selected.x or 0) * 100, (selected.y or 0) * 100) },
            { label = "Seen", value = tostring(selected.seenCount or 0) },
            { label = "Last Seen", value = SafeDate(selected.lastSeen) },
            { label = "Learned Fish", value = (#fishNames > 0 and table.concat(fishNames, ", ")) or "None yet", height = 52 },
        }, width - 32)

        local noteBox = Track(content, CreateBackdropFrame(detail))
        noteBox:SetPoint("TOPLEFT", 16, compact and -172 or -152)
        noteBox:SetSize(width - 170, compact and 56 or 64)
        noteBox:SetBackdropColor(0.020, 0.040, 0.080, 0.92)
        local edit = Track(content, CreateFrame("EditBox", nil, noteBox))
        edit:SetPoint("TOPLEFT", 8, -8)
        edit:SetPoint("BOTTOMRIGHT", -8, 8)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetText(selected.note or "")
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetTextColor(SOFT[1], SOFT[2], SOFT[3])

        local saveBtn = Track(content, MakeActionButton(detail, "Save Note", "Interface\\Icons\\INV_Misc_Note_01", TEAL, function()
            P.Nodes:SetNodeNote(selected.mapID, selected.coordKey, edit:GetText())
            UI:Refresh()
        end))
        saveBtn:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -16, compact and -172 or -152)
        local exportBtn2 = Track(content, MakeActionButton(detail, "Export Map", "Interface\\Icons\\INV_Misc_Note_01", ACCENT, function()
            if P.ImportExport then
                P.ImportExport:OpenExportWindow()
                if P.ImportExport.editBox then
                    P.ImportExport.editBox:SetText(P.ImportExport:SerializeNodes(selected.mapID))
                    P.ImportExport.editBox:HighlightText()
                end
            end
        end))
        exportBtn2:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -16, compact and -206 or -186)
        y = y - detail:GetHeight() - 12
    end

    content:SetHeight(math.max(1, math.abs(y) + 24))
end

function UI:RenderImportExport()
    local content = self.frame.content
    local width = GetViewportWidth(self.frame, IsCompactMode())
    local y = -8
    local meta = P.db.meta or {}

    local share = CreateCard(content, content, 0, y, width, 152, "Share Node Sets", "Interface\\Icons\\INV_Misc_Note_01", ACCENT)
    AddWrappedText(content, share, "Use Poseidon's dedicated import/export window for backups, migration, and trading route libraries with your future self. This build serializes map identity, node coordinates, notes, timestamps, and learned fish links.", "TOPLEFT", share, "TOPLEFT", 16, -42, width - 32, "GameFontHighlight", SOFT)
    local importBtn = Track(content, MakeActionButton(share, "Open Import", "Interface\\Icons\\INV_Misc_Note_01", TEAL, function() P.ImportExport:OpenImportWindow() end))
    importBtn:SetPoint("TOPLEFT", 16, -110)
    local exportBtn = Track(content, MakeActionButton(share, "Open Export", "Interface\\Icons\\INV_Misc_Note_01", ACCENT, function() P.ImportExport:OpenExportWindow() end))
    exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    local currentBtn = Track(content, MakeActionButton(share, "Export Current Map", "Interface\\Icons\\INV_Misc_Map_01", TEAL, function()
        local mapID = GetCurrentMapID()
        P.ImportExport:OpenExportWindow()
        if P.ImportExport.editBox then
            P.ImportExport.editBox:SetText(P.ImportExport:SerializeNodes(mapID))
            P.ImportExport.editBox:HighlightText()
        end
    end))
    currentBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    y = y - share:GetHeight() - 12

    local audit = CreateCard(content, content, 0, y, width, 126, "Activity", "Interface\\Icons\\INV_Misc_Gear_01", TEAL)
    AddDetailRows(content, audit, {
        { label = "Last Import", value = meta.lastImportAt and SafeDate(meta.lastImportAt) or "Never" },
        { label = "Last Export", value = meta.lastExportAt and SafeDate(meta.lastExportAt) or "Never" },
        { label = "Storage Backend", value = P._storageBackend or "Unknown" },
    }, width - 32)
    y = y - audit:GetHeight() - 12

    content:SetHeight(math.max(1, math.abs(y) + 24))
end

function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local frame = self.frame
    ClearContent(frame.content)
    frame.content:SetWidth(GetViewportWidth(frame, IsCompactMode()))

    local view = P.settings.ui.selectedView or "overview"
    if IsCompactMode() then
        view = SetSelectedViewForCompact(view)
    end

    for key, button in pairs(self.navButtons or {}) do
        if button.SetSelected then
            button:SetSelected(key == view)
        end
    end
    for key, button in pairs(self.compactButtons or {}) do
        if button.SetSelected then
            button:SetSelected(key == view)
        end
    end

    if view == "zones" then
        self:RenderZones()
    elseif view == "fish" then
        self:RenderFish()
    elseif view == "nodes" then
        self:RenderNodes()
    elseif view == "import" then
        self:RenderImportExport()
    else
        self:RenderOverview()
    end
end

function UI:Init()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "FabledUI_PoseidonCompanion", UIParent, "PortraitFrameTemplate,BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not P.settings.ui.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePosition(self)
    end)
    frame:SetScript("OnSizeChanged", function(self)
        if self.content and self.scroll then
            self.content:SetWidth(GetViewportWidth(self, IsCompactMode()))
        end
        SaveFramePosition(self)
    end)
    frame:Hide()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(420, 460)
    elseif frame.SetMinResize then
        frame:SetMinResize(420, 460)
    end
    StyleFrameShell(frame)

    local portrait = frame.Portrait or (frame.PortraitContainer and (frame.PortraitContainer.portrait or frame.PortraitContainer.Portrait))
    if portrait and portrait.SetTexture then
        portrait:SetTexture("Interface\\Icons\\Trade_Fishing")
    end

    local titleText = frame.TitleText or (frame.TitleContainer and (frame.TitleContainer.TitleText or frame.TitleContainer.titleText))
    if not titleText then
        titleText = CreateText(frame, "OVERLAY", "GameFontNormal", "Poseidon Companion", GOLD)
        titleText:SetPoint("TOP", 0, -16)
        frame.TitleText = titleText
    end
    titleText:SetText("Poseidon Companion")

    local headerGlow = frame:CreateTexture(nil, "BACKGROUND")
    headerGlow:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.15)
    headerGlow:SetPoint("TOPLEFT", 24, -24)
    headerGlow:SetPoint("TOPRIGHT", -24, -24)
    headerGlow:SetHeight(34)

    local statusText = CreateText(frame, "OVERLAY", "GameFontNormalSmall", "", MUTED)
    statusText:SetPoint("TOPLEFT", 58, -36)
    statusText:SetWidth(420)
    statusText:SetJustifyH("LEFT")

    local modeText = CreateText(frame, "OVERLAY", "GameFontNormalSmall", "", SOFT)
    modeText:SetPoint("TOPRIGHT", -44, -36)
    modeText:SetJustifyH("RIGHT")

    local actionBar = CreateBackdropFrame(frame)
    actionBar:SetPoint("TOPLEFT", 222, -52)
    actionBar:SetPoint("TOPRIGHT", -34, -52)
    actionBar:SetHeight(34)
    actionBar:SetBackdropColor(0.035, 0.055, 0.100, 0.92)

    local navShell = CreateBackdropFrame(frame)
    navShell:SetPoint("TOPLEFT", 14, -88)
    navShell:SetPoint("BOTTOMLEFT", 14, 16)
    navShell:SetWidth(168)
    navShell:SetBackdropColor(0.030, 0.050, 0.095, 0.92)

    local contentShell = CreateBackdropFrame(frame)
    contentShell:SetPoint("TOPLEFT", navShell, "TOPRIGHT", 10, 0)
    contentShell:SetPoint("BOTTOMRIGHT", -14, 16)
    contentShell:SetBackdropColor(0.025, 0.045, 0.085, 0.94)

    local scroll = CreateFrame("ScrollFrame", nil, contentShell, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -40, 10)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = self.ScrollBar
        if scrollBar then
            scrollBar:SetValue(scrollBar:GetValue() - (delta * 36))
        end
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(640, 1)
    content._poseidonWidgets = {}
    scroll:SetScrollChild(content)

    local compactTabs = CreateBackdropFrame(frame)
    compactTabs:SetPoint("TOPLEFT", 14, -88)
    compactTabs:SetPoint("TOPRIGHT", -14, -88)
    compactTabs:SetHeight(48)
    compactTabs:SetBackdropColor(0.030, 0.050, 0.095, 0.92)

    frame.statusText = statusText
    frame.modeText = modeText
    frame.navShell = navShell
    frame.contentShell = contentShell
    frame.scroll = scroll
    frame.content = content
    frame.compactTabs = compactTabs
    frame.actionBar = actionBar
    frame.defaultNavWidth = 168

    self.frame = frame
    self.navButtons = {}
    self.compactButtons = {}

    self.modeButton = MakeActionButton(actionBar, "Compact", "Interface\\Icons\\Ability_Spy", ACCENT, function()
        P.settings.ui.attachMode = IsCompactMode() and "full" or "compact"
        UI:ApplyLayoutMode()
        SetFramePosition(UI.frame)
        UI:Refresh()
        UI:SetStatus("Free-floating fishing companion.", UI:GetModeLabel())
        P:MarkDirty()
    end)
    self.modeButton:SetPoint("LEFT", actionBar, "LEFT", 8, 0)

    self.journalButton = MakeActionButton(actionBar, "Fishing Journal", "Interface\\Icons\\INV_Misc_Book_11", ACCENT, function()
        P:OpenFishingJournal()
    end)
    self.journalButton:SetPoint("LEFT", self.modeButton, "RIGHT", 8, 0)

    self.settingsButton = MakeActionButton(actionBar, "Settings", "Interface\\Icons\\INV_Misc_Gear_01", TEAL, function()
        if Settings and Settings.OpenToCategory and P.CategoryID then
            Settings.OpenToCategory(P.CategoryID)
        end
    end)
    self.settingsButton:SetPoint("LEFT", self.journalButton, "RIGHT", 8, 0)

    for index, item in ipairs(NAV_ITEMS) do
        local btn = CreateStyledButton(navShell, 150, 34, item.label, item.icon, (item.key == "overview" or item.key == "fish") and TEAL or ACCENT)
        btn:SetPoint("TOPLEFT", 16, -18 - ((index - 1) * 42))
        btn:SetScript("OnClick", function() UI:ShowTab(item.key) end)
        self.navButtons[item.key] = btn
    end

    for index, item in ipairs(COMPACT_ITEMS) do
        local btn = CreateStyledButton(compactTabs, 96, 24, item.label, item.icon, (item.key == "overview" or item.key == "fish") and TEAL or ACCENT)
        btn:SetPoint("TOPLEFT", 10 + ((index - 1) * 102), -6)
        btn:SetScript("OnClick", function() UI:ShowTab(item.key) end)
        self.compactButtons[item.key] = btn
    end

    local closeButton = frame.CloseButton or CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    SetFramePosition(frame)
    self:ApplyLayoutMode()
    self:ApplySettings()
    self:UpdateAttachButton()
    self:SetStatus("Free-floating fishing companion.", self:GetModeLabel())
end
