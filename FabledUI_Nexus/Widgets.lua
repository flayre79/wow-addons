local N = FabledUI_Nexus
N.Widgets = N.Widgets or {}
local W = N.Widgets

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    for key, value in pairs(src) do
        dst[key] = DeepCopy(value)
    end
    return dst
end

local function fmtCoord(v)
    if type(v) ~= "number" then
        return "--.-"
    end
    return string.format("%.1f", v * 100)
end

local function coin(amount)
    amount = tonumber(amount) or 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(amount, 12)
    end
    return tostring(amount)
end

local function shortNumber(value)
    value = tonumber(value) or 0
    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    end
    if value >= 1000 then
        return string.format("%dK", math.floor((value / 1000) + 0.5))
    end
    return tostring(value)
end

local function getMaxPlayerLevel()
    if type(GetMaxLevelForLatestExpansion) == "function" then
        return GetMaxLevelForLatestExpansion()
    end
    return 80
end

local function safeAPI(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, result = pcall(api, ...)
    if not ok then return nil end
    return result
end

local function clip(text, maxChars)
    text = tostring(text or "")
    maxChars = tonumber(maxChars) or 999
    if #text <= maxChars then return text end
    return text:sub(1, math.max(1, maxChars - 2)) .. ".."
end

-- Watched-faction / reputation progress. Prefers the modern C_Reputation
-- surface, falls back to the legacy global. Handles paragon / exalted (no
-- next threshold) by reporting "Max".
local function reputationSummary()
    local name, within, needed
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = safeAPI(C_Reputation.GetWatchedFactionData)
        if type(data) == "table" and data.name and data.name ~= "" then
            name = data.name
            local base = data.currentReactionThreshold or 0
            within = (data.currentStanding or 0) - base
            needed = (data.nextReactionThreshold or 0) - base
        end
    end
    if not name then
        return "No rep tracked"
    end
    if not needed or needed <= 0 then
        return string.format("%s: Max", clip(name, 18))
    end
    local pct = math.floor((within / needed) * 100 + 0.5)
    return string.format("%s %d%%", clip(name, 14), pct)
end

-- Housing "House XP": current house level + favor progress toward the next
-- level.
--
-- This widget makes NO C_Housing calls. It used to read the housing API
-- directly, on the 2s StartTicker() poll, "so it works without Villa loaded".
-- That poll broke Blizzard's Housing Dashboard: with only UIToolkit + Nexus
-- enabled the House Information tab came up blank except the house dropdown,
-- and disabling Nexus fixed it every time (owner-bisected, 2026-09-03). A
-- guard that skipped the poll only while the dashboard was *shown* was not
-- enough, because the dashboard is load-on-demand and the damage lands before
-- it is ever opened.
--
-- Blizzard's side is genuinely fragile here -- InitiativesFrame:OnHouseSelected
-- indexes self.playerHouseList with no nil check, and once it throws, the
-- forwarder never reaches HouseUpgradeFrame and the dropdown's tCompare guard
-- swallows every identical reply afterwards, so the pane stays blank until a
-- reload. But fragile or not, we are the ones poking it, so we stop poking it.
--
-- FabledUI_Villa_House owns house level and House XP (carved out of Villa on
-- 2026-09-19 so this works with Villa off; it was called Hestia until
-- 2026-10-02). It holds the request guards and does the cumulative-favor
-- maths; ask it for the finished line. The old Villa monolith's state is the
-- fallback for an install that predates Villa House. With neither, the widget
-- reports "n/a" -- a dead widget is a fair price for not breaking a Blizzard
-- panel, and the fix is to enable Villa House.
local function houseAddonSummary()
    local house = rawget(_G, "FabledUI_Villa_House")
    if type(house) == "table" and type(house.GetSummaryText) == "function" then
        local ok, text = pcall(house.GetSummaryText, house)
        if ok and type(text) == "string" then
            return text
        end
    end
    return nil
end

local function villaHouseState()
    local villa = rawget(_G, "FabledUI_Villa")
    local endeavors = villa and villa.Endeavors
    local state = endeavors and endeavors.state
    if type(state) == "table" then
        return state
    end
    return nil
end

local function houseFavorSummary()
    local fromHouseAddon = houseAddonSummary()
    if fromHouseAddon then
        return fromHouseAddon
    end

    local state = villaHouseState()
    if not state then
        return "House: n/a"
    end
    if not state.hasHouse then
        return "House: none"
    end

    local level = state.houseLevel
    local levelText = (type(level) == "number" and level > 0) and ("Lv " .. level) or "Lv --"

    if state.isMaxLevel then
        return string.format("House %s | Max", levelText)
    end

    local cur = tonumber(state.houseFavor) or 0
    local need = tonumber(state.houseFavorNeeded) or 0
    if need <= 0 then
        return string.format("House %s", levelText)
    end

    local pct = math.floor((cur / need) * 100 + 0.5)
    return string.format("House %s | %d%%", levelText, pct)
end

local function durabilitySummary()
    local current, maximum = 0, 0
    for slot = 1, 17 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            current = current + cur
            maximum = maximum + max
        end
    end

    if maximum <= 0 then
        return "Dur -- | --"
    end

    local pct = math.floor((current / maximum) * 100 + 0.5)
    local repairText = "--"
    if type(CanMerchantRepair) == "function" and CanMerchantRepair() and type(GetRepairAllCost) == "function" then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost and cost > 0 then
            repairText = coin(cost)
        else
            repairText = "0"
        end
    end

    return string.format("Dur %d%% | %s", pct, repairText)
end

-- MyPerfMonitor parity intentionally stops at the useful, low-cost surface:
-- current FPS plus home/world latency. Logging, combat timing, and a second
-- movable frame do not belong in Nexus's optional widget layer.
local function wholeNumberText(value)
    if type(value) ~= "number" then return "--" end
    local ok, rounded = pcall(math.floor, value)
    return ok and tostring(rounded) or "--"
end

local function performanceSummary()
    local fps
    if type(GetFramerate) == "function" then
        local ok, value = pcall(GetFramerate)
        if ok then fps = value end
    end

    local home, world
    if type(GetNetStats) == "function" then
        local ok, _, _, homeValue, worldValue = pcall(GetNetStats)
        if ok then
            home = homeValue
            world = worldValue
        end
    end

    return string.format("%s FPS | %s/%s ms", wholeNumberText(fps), wholeNumberText(home), wholeNumberText(world))
end

W.Definitions = {
    time = {
        id = "widget_time",
        label = "Time",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        desc = "Local and server time.",
        text = function()
            local h, m = GetGameTime()
            return string.format("%s (S %02d:%02d)", date("%H:%M"), h or 0, m or 0)
        end,
    },
    location = {
        id = "widget_location",
        label = "Location",
        icon = "Interface\\Icons\\INV_Misc_Map08",
        desc = "Current zone and subzone.",
        text = function()
            local zone = GetZoneText() or "Unknown"
            local subzone = GetSubZoneText() or ""
            if subzone ~= "" and subzone ~= zone then
                return zone .. string.char(10) .. subzone
            end
            return zone
        end,
    },
    coords = {
        id = "widget_coords",
        label = "Coordinates",
        icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
        desc = "Player map coordinates.",
        text = function()
            local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                return string.format("Coords %s, %s", fmtCoord(pos.x), fmtCoord(pos.y))
            end
            return "Coords --.-, --.-"
        end,
    },
    gold = {
        id = "widget_gold",
        label = "Gold",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        desc = "Current character gold.",
        text = function()
            return coin(GetMoney())
        end,
    },
    xp = {
        id = "widget_xp",
        label = "XP",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        desc = "XP remaining and rested bonus.",
        text = function()
            local level = UnitLevel("player") or 0
            local maxLevel = getMaxPlayerLevel()
            local maxXP = UnitXPMax and UnitXPMax("player") or 0
            if level >= maxLevel or not maxXP or maxXP <= 0 then
                return "XP Max level"
            end
            local current = UnitXP("player") or 0
            local remaining = math.max(0, maxXP - current)
            local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
            local pct = math.floor((current / maxXP) * 100 + 0.5)
            local restedPct = 0
            if rested > 0 then
                restedPct = math.floor((rested / maxXP) * 100 + 0.5)
            end
            return string.format("XP %d%% | R %d%% | %s", pct, restedPct, shortNumber(remaining))
        end,
    },
    reputation = {
        id = "widget_reputation",
        label = "Reputation",
        icon = "Interface\\Icons\\Achievement_Reputation_01",
        desc = "Progress on your currently watched faction.",
        text = reputationSummary,
        onClick = function(_, button)
            if button == "LeftButton" and type(ToggleCharacter) == "function" then
                ToggleCharacter("ReputationFrame")
            end
        end,
    },
    housefavor = {
        id = "widget_housefavor",
        label = "House XP",
        icon = "Interface\\Icons\\INV_Misc_House_01",
        desc = "Your house level and favor toward the next level.",
        text = houseFavorSummary,
    },
    durability = {
        id = "widget_durability",
        label = "Durability",
        icon = "Interface\\Icons\\Ability_Repair",
        desc = "Equipment durability and repair cost.",
        text = durabilitySummary,
    },
    performance = {
        id = "widget_performance",
        label = "Performance",
        icon = "Interface\\Icons\\INV_Gizmo_GoblinBoomBox_01",
        desc = "Current framerate and home/world latency.",
        text = performanceSummary,
    },
    volume = {
        id = "widget_volume",
        label = "Volume",
        icon = "Interface\\Icons\\INV_Misc_Horn_04",
        desc = "Master sound state and volume.",
        text = function()
            local enabled = GetCVarBool and GetCVarBool("Sound_EnableAllSound")
            local master = tonumber((GetCVar and GetCVar("Sound_MasterVolume")) or 0) or 0
            return string.format("Volume: %d%%%s", math.floor(master * 100 + 0.5), enabled and "" or " (Muted)")
        end,
        onClick = function(entry, button)
            if button == "RightButton" and type(SetCVar) == "function" then
                local enabled = GetCVarBool and GetCVarBool("Sound_EnableAllSound")
                SetCVar("Sound_EnableAllSound", enabled and 0 or 1)
                return
            end
            -- NX-001: Left-click opens the volume slider popup.
            if button == "LeftButton" and W.ShowVolumePopup then
                W:ShowVolumePopup(entry)
            end
        end,
        -- NX-002: Scroll the volume row to nudge master volume by 5% either way
        -- (Titan-style). This is the discoverable "slider" most people reach for.
        onScroll = function(_, delta)
            if type(SetCVar) ~= "function" or type(GetCVar) ~= "function" then return end
            local step = 0.05
            local master = tonumber(GetCVar("Sound_MasterVolume") or 0) or 0
            local target = master + ((delta or 0) > 0 and step or -step)
            target = math.floor((target / step) + 0.5) * step
            if target < 0 then target = 0 elseif target > 1 then target = 1 end
            SetCVar("Sound_MasterVolume", tostring(target))
            -- Un-mute on scroll-up so raising the volume actually does something.
            if (delta or 0) > 0 and GetCVarBool and not GetCVarBool("Sound_EnableAllSound") then
                SetCVar("Sound_EnableAllSound", 1)
            end
            if W._volumePopup and W._volumePopup:IsShown() then
                W._volumePopup:UpdateDisplay()
            end
        end,
    },
}

-- NX-001: Volume slider popup. Self-contained UI for adjusting Sound_MasterVolume
-- with a horizontal slider (0.0 - 1.0, step 0.05), a percentage readout, and a
-- mute toggle button. The popup polls the CVars on OnUpdate and hooks the
-- SOUND_OPTIONS_BUTTON_PRESSED event so external changes (system menu, other
-- addons) are reflected immediately.
local function BuildVolumePopup()
    if W._volumePopup then return W._volumePopup end

    local popup = CreateFrame("Frame", "FabledUI_Nexus_VolumePopup", UIParent, "BackdropTemplate")
    popup:SetSize(220, 60)
    popup:SetFrameStrata("DIALOG")
    popup:Hide()
    popup:EnableMouse(true)
    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end

    -- Mute toggle button (left edge of slider).
    local mute = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    mute:SetSize(40, 20)
    mute:SetPoint("TOPLEFT", 10, -10)
    mute:SetText("Mute")
    mute:SetScript("OnClick", function()
        if type(SetCVar) ~= "function" then return end
        local enabled = GetCVarBool and GetCVarBool("Sound_EnableAllSound")
        SetCVar("Sound_EnableAllSound", enabled and 0 or 1)
        if W._volumePopup then W._volumePopup:UpdateDisplay() end
    end)
    popup.muteButton = mute

    -- Horizontal volume slider.
    local slider = CreateFrame("Slider", "FabledUI_Nexus_VolumeSlider", popup, "OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.0, 1.0)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetPoint("LEFT", mute, "RIGHT", 12, 0)
    slider:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    slider:SetHeight(16)
    -- Hide the default OptionsSliderTemplate Low/High/Text labels.
    if _G[slider:GetName() .. "Low"] then _G[slider:GetName() .. "Low"]:SetText("") end
    if _G[slider:GetName() .. "High"] then _G[slider:GetName() .. "High"]:SetText("") end
    if _G[slider:GetName() .. "Text"] then _G[slider:GetName() .. "Text"]:SetText("") end
    popup.slider = slider

    -- Percentage label below slider.
    local label = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    popup.label = label

    -- Guard so OnValueChanged from external sync doesn't recurse SetCVar.
    popup._syncing = false

    slider:SetScript("OnValueChanged", function(self, value)
        if popup._syncing then return end
        if type(SetCVar) ~= "function" then return end
        -- Snap to step (defensive — OnValueChanged can fire with raw values).
        local step = self:GetValueStep() or 0.05
        local snapped = math.floor((value / step) + 0.5) * step
        if snapped < 0 then snapped = 0 elseif snapped > 1 then snapped = 1 end
        SetCVar("Sound_MasterVolume", tostring(snapped))
        popup:UpdateDisplay()
    end)

    function popup:UpdateDisplay()
        local enabled = GetCVarBool and GetCVarBool("Sound_EnableAllSound")
        local master = tonumber((GetCVar and GetCVar("Sound_MasterVolume")) or 0) or 0
        self._syncing = true
        self.slider:SetValue(master)
        self._syncing = false
        self.label:SetText(string.format("Volume: %d%%%s",
            math.floor(master * 100 + 0.5),
            enabled and "" or " (Muted)"))
        self.muteButton:SetText(enabled and "Mute" or "Unmute")
    end

    -- Poll CVars so external changes (system menu, /console) update the slider.
    popup:SetScript("OnUpdate", function(self, elapsed)
        self._poll = (self._poll or 0) + elapsed
        if self._poll < 0.25 then return end
        self._poll = 0
        local master = tonumber((GetCVar and GetCVar("Sound_MasterVolume")) or 0) or 0
        if math.abs((self.slider:GetValue() or 0) - master) > 0.001 then
            self:UpdateDisplay()
        end
    end)

    -- Event hook: SOUND_OPTIONS_BUTTON_PRESSED fires when the user toggles
    -- master sound via the system options panel.
    popup:RegisterEvent("SOUND_OPTIONS_BUTTON_PRESSED")
    popup:RegisterEvent("CVAR_UPDATE")
    popup:SetScript("OnEvent", function(self, event, arg1)
        if event == "SOUND_OPTIONS_BUTTON_PRESSED" then
            self:UpdateDisplay()
        elseif event == "CVAR_UPDATE" and (arg1 == "Sound_MasterVolume" or arg1 == "Sound_EnableAllSound" or arg1 == "MASTERVOLUME" or arg1 == "ENABLE_ALL_SOUND") then
            self:UpdateDisplay()
        end
    end)

    -- Auto-close when the user clicks elsewhere. Use a hidden global click
    -- catcher pattern: hide on mouse leave after a short grace period.
    popup:SetScript("OnLeave", function(self)
        self._closeTimer = 0.6
    end)
    popup:SetScript("OnEnter", function(self)
        self._closeTimer = nil
    end)
    -- Extend OnUpdate to honor close timer (rebind to a combined handler).
    local baseOnUpdate = popup:GetScript("OnUpdate")
    popup:SetScript("OnUpdate", function(self, elapsed)
        if baseOnUpdate then baseOnUpdate(self, elapsed) end
        if self._closeTimer then
            self._closeTimer = self._closeTimer - elapsed
            if self._closeTimer <= 0 then
                self._closeTimer = nil
                self:Hide()
            end
        end
    end)

    W._volumePopup = popup
    return popup
end

function W:ShowVolumePopup(entry)
    local popup = BuildVolumePopup()
    popup:ClearAllPoints()
    -- Anchor near cursor so the slider appears next to the clicked row.
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 8, (y / scale) - 8)
    popup:UpdateDisplay()
    popup:Show()
end

function W:GetActiveEntries()
    local entries = {}
    local cfg = (N.db and N.db.widgetConfig) or {}
    for key, def in pairs(self.Definitions) do
        if cfg[key] and cfg[key].enabled then
            local entry = DeepCopy(def)
            entry.key = def.id
            entry.moduleType = "widget"
            entry.group = cfg[key].group or "Widgets"
            entry.isFavorite = cfg[key].favorite or false
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    return entries
end

function W:GetText(entry)
    local def
    for _, v in pairs(self.Definitions) do
        if v.id == entry.id then
            def = v
            break
        end
    end
    if not def or type(def.text) ~= "function" then
        return entry.label or "Widget"
    end
    local ok, text = pcall(def.text)
    if ok and type(text) == "string" then
        return text
    end
    return entry.label or "Widget"
end

function W:RefreshVisibleRows()
    if not N.UI or type(N.UI.rows) ~= "table" then return end
    for _, row in ipairs(N.UI.rows) do
        local entry = row.entry
        local visible = type(row.IsVisible) ~= "function" or row:IsVisible()
        if visible and entry and entry.moduleType == "widget" and row.label then
            row.label:SetText(self:GetText(entry))
        end
    end
end

function W:StartTicker()
    if self._ticker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then return end
    self._ticker = C_Timer.NewTicker(2, function()
        W:RefreshVisibleRows()
    end)
end

function W:HandleClick(entry, button)
    for _, def in pairs(self.Definitions) do
        if def.id == entry.id and type(def.onClick) == "function" then
            local ok = pcall(def.onClick, entry, button)
            return ok
        end
    end
    return false
end

function W:HandleScroll(entry, delta)
    for _, def in pairs(self.Definitions) do
        if def.id == entry.id and type(def.onScroll) == "function" then
            pcall(def.onScroll, entry, delta)
            return true
        end
    end
    return false
end
