local Villa = _G.FabledUI_Villa
local Tabs = {}
Villa.Tabs = Tabs
Villa:RegisterModule("Tabs", Tabs)

local UI = Villa.UI

-- Villa now lives in its OWN resizable FableNeon window (built on the shared
-- UIToolkit Shell) rather than being crammed into Blizzard's Housing Dashboard.
-- A launcher on the dashboard (Dashboard.lua) and /villa open it. The window
-- hosts a scrollable left rail of tabs + a content host that every panel factory
-- parents into (unchanged: each panel does CreateFrame + SetAllPoints(host)).
Tabs.window = nil
Tabs.rail = nil
Tabs.railChild = nil
Tabs.contentHost = nil
Tabs.panels = {}
Tabs.buttons = {}
Tabs.activeKey = nil

local RAIL_WIDTH = 156
local RAIL_BTN_H = 33

local PANEL_ORDER = {
    { key = "vendors", label = "Vendors", tooltip = "Villa Vendors", atlas = "auctionhouse-icon-favorite" },
    { key = "quests", label = "Quests", tooltip = "Housing quest sources", icon = "Interface\\Icons\\INV_Misc_Book_08" },
    { key = "achievements", label = "Achievements", tooltip = "Housing achievement sources", icon = "Interface\\Icons\\Achievement_General" },
    { key = "drops", label = "Drops", tooltip = "Drop and encounter sources", icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue" },
    { key = "pvp", label = "PvP", tooltip = "PvP decoration sources", icon = "Interface\\Icons\\achievement_bg_killxenemies_generalsroom" },
    { key = "professions", label = "Professions", tooltip = "Crafting and recipe sources", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { key = "progress", label = "Progress", tooltip = "Coverage dashboard", icon = "Interface\\Icons\\Spell_Holy_BorrowedTime" },
    { key = "wishlist", label = "Wishlist", tooltip = "Tracked donor entries", icon = "Interface\\Icons\\INV_ValentinesCard01" },
    { key = "treasures", label = "Treasures", tooltip = "BetterHomes treasure routes", icon = "Interface\\Icons\\INV_Chest_Wooden_17" },
    { key = "catalog", label = "Catalog", tooltip = "HousingDecorGuide catalog donor", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "styles", label = "Styles", tooltip = "HousingDecorGuide styles donor", icon = "Interface\\Icons\\INV_Inscription_ScrollOfWisdom_01" },
    { key = "trainers", label = "Trainers", tooltip = "HousingDecorGuide profession trainers", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "tracker", label = "Tracker", tooltip = "HousingItemTracker donor systems", icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01" },
    { key = "reputation", label = "Reputation", tooltip = "HousingVendor reputation donor", icon = "Interface\\Icons\\Achievement_Reputation_08" },
    { key = "materials", label = "Materials", tooltip = "HousingVendor materials donor", icon = "Interface\\Icons\\INV_Ore_Copper_01" },
    { key = "planning", label = "Planning", tooltip = "HousingVendor planning donor", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "statistics", label = "Statistics", tooltip = "HousingVendor statistics donor", icon = "Interface\\Icons\\INV_Misc_Book_11" },
    { key = "preview", label = "Preview Tuning", tooltip = "Camera/model tuning data (dev). For 3D previews use a vendor item's Preview button.", icon = "Interface\\Icons\\INV_Misc_Spyglass_03" },
    { key = "trainers_hv",   label = "Trainers+",      tooltip = "HousingVendor trainer donor",     icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "shoppinglist", label = "Shopping List",  tooltip = "Custom shopping lists for vendor runs", icon = "Interface\\Icons\\INV_Misc_Note_06" },
    { key = "checklist", label = "Checklist", tooltip = "Completionist checklist: collected vs missing", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "achdecor", label = "Achievement Decor", tooltip = "Achievements that award housing decor (reverse lookup)", icon = "Interface\\Icons\\Achievement_General" },
}

local function GetPanelOwner(key)
    local map = {
        vendors = Villa.Vendors,
        quests = Villa.Quests,
        achievements = Villa.Achievements,
        drops = Villa.Drops,
        pvp = Villa.PvP,
        professions = Villa.Professions,
        progress = Villa.Progress,
        wishlist = Villa.Wishlist,
        treasures = Villa.Treasures,
        catalog = Villa.Catalog,
        styles = Villa.Styles,
        trainers = Villa.Trainers,
        tracker = Villa.Tracker,
        reputation = Villa.Reputation,
        materials = Villa.Materials,
        planning = Villa.Planning,
        statistics = Villa.Statistics,
        preview = Villa.Preview,
        trainers_hv  = Villa.HVTrainers,
        shoppinglist = Villa.ShoppingList,
        checklist    = Villa.Checklist,
        achdecor     = Villa.AchievementDecor,
    }
    return map[key]
end

-- ── Rail button (icon + label, cyan selection) ───────────────────────────────
local function CreateRailButton(parent, index, info)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(RAIL_WIDTH - 8, RAIL_BTN_H)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2 - ((index - 1) * RAIL_BTN_H))
    button.customAtlas = info.atlas

    local baseBG = { 0, 0, 0, 0 }
    local hoverBG = (UI and UI.RowBG) and { UI.RowBG[1], UI.RowBG[2], UI.RowBG[3], 0.9 } or { 0.09, 0.11, 0.19, 0.9 }
    local ga = (UI and UI.Accent) or { 0.227, 0.914, 1.0 }
    local selBG = { ga[1], ga[2], ga[3], 0.12 }
    button.__baseBG, button.__hoverBG, button.__selBG = baseBG, hoverBG, selBG

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(baseBG[1], baseBG[2], baseBG[3], baseBG[4])
    button.Bg = bg

    -- cyan selection bar on the left edge
    local sel = button:CreateTexture(nil, "ARTWORK")
    sel:SetPoint("TOPLEFT", 0, 0)
    sel:SetPoint("BOTTOMLEFT", 0, 0)
    sel:SetWidth(3)
    sel:SetColorTexture(ga[1], ga[2], ga[3], 1)
    sel:Hide()
    button.Highlight = sel

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 11, 0)
    if info.atlas then
        icon:SetAtlas(info.atlas)
    elseif info.icon then
        icon:SetTexture(info.icon)
    end
    icon:SetDesaturated(true)
    icon:SetAlpha(0.8)
    button.Icon = icon

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 9, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")
    label:SetText(info.label)
    if UI and UI.TextMuted then label:SetTextColor(UI.Unpack(UI.TextMuted)) end
    button.Label = label

    button:SetScript("OnEnter", function(self)
        if not self.__selected then
            self.Bg:SetColorTexture(self.__hoverBG[1], self.__hoverBG[2], self.__hoverBG[3], self.__hoverBG[4])
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(info.label)
        if info.tooltip then
            GameTooltip:AddLine(info.tooltip, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if not self.__selected then
            self.Bg:SetColorTexture(self.__baseBG[1], self.__baseBG[2], self.__baseBG[3], self.__baseBG[4])
        end
        GameTooltip_Hide()
    end)
    return button
end

function Tabs:UpdateButtonStates()
    for key, button in pairs(self.buttons) do
        local selected = (key == self.activeKey)
        button.__selected = selected
        if button.Icon then
            if button.customAtlas then button.Icon:SetAtlas(button.customAtlas) end
            button.Icon:SetDesaturated(not selected)
            button.Icon:SetAlpha(selected and 1 or 0.8)
        end
        if button.Highlight then
            button.Highlight:SetShown(selected)
        end
        if button.Label and UI then
            button.Label:SetTextColor(UI.Unpack(selected and UI.Text or UI.TextMuted))
        end
        if button.Bg then
            local c = selected and button.__selBG or button.__baseBG
            if c then button.Bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
        end
    end
end

-- ── The window (built once, lazily) ──────────────────────────────────────────
function Tabs:EnsureWindow()
    if self.window then
        return self.window
    end

    local T = rawget(_G, "FabledUI_UIToolkit")
    if not (T and T.Shell and type(T.Shell.CreateWindow) == "function") then
        if Villa and Villa.Print then
            Villa:Print("UIToolkit shell unavailable — cannot open the Villa window.")
        end
        return nil
    end

    if Villa.db and Villa.db.ui then
        Villa.db.ui.window = Villa.db.ui.window or {}
    end

    local win = T.Shell:CreateWindow("FabledUI_VillaMain", {
        title = "FabledUI - Villa",
        width = 1060,
        height = 684,
        minWidth = 900,
        minHeight = 560,
        theme = "FableNeon",
        ribbon = false,
        state = (Villa.db and Villa.db.ui and Villa.db.ui.window) or nil,
    })
    -- Shell does not order its windows (no SetToplevel, no frame-level
    -- management), so each addon opts in individually -- Athena, DataVault,
    -- Harvest, Iris, Kleos, Nemesis and Odyssey all do. Villa and Nexus were
    -- the two that did not, which is why they interleaved on screen instead of
    -- raising when clicked, with Villa's sidebar drawing behind Nexus's content
    -- while its vendor list drew in front. Stopgap until the toolkit owns this
    -- centrally -- see docs/UIToolkit/Lane_Requests.md.
    if win.SetToplevel then
        win:SetToplevel(true)
    end

    self.window = win

    local content = win.Content or win

    -- Left rail container (recessed well + cyan/purple seam on its inner edge).
    local rail = CreateFrame("Frame", nil, content, "BackdropTemplate")
    rail:SetPoint("TOPLEFT", 0, 0)
    rail:SetPoint("BOTTOMLEFT", 0, 0)
    rail:SetWidth(RAIL_WIDTH)
    if UI then
        UI:ApplyBackdrop(rail, UI.InsetBG, UI.PanelBorder)
    end
    self.rail = rail

    local seam = rail:CreateTexture(nil, "OVERLAY")
    seam:SetPoint("TOPRIGHT", 0, 0)
    seam:SetPoint("BOTTOMRIGHT", 0, 0)
    seam:SetWidth(2)
    if seam.SetGradient and CreateColor and UI and UI.Accent then
        seam:SetColorTexture(1, 1, 1, 1)
        seam:SetGradient("VERTICAL", CreateColor(UI.Unpack(UI.Accent2)), CreateColor(UI.Unpack(UI.Accent)))
    elseif UI and UI.Accent then
        seam:SetColorTexture(UI.Unpack(UI.Accent))
    end

    -- Scrollable rail interior (22 tabs overflow a normal window height).
    local railScroll = CreateFrame("ScrollFrame", nil, rail)
    railScroll:SetPoint("TOPLEFT", 3, -4)
    railScroll:SetPoint("BOTTOMRIGHT", -4, 4)
    local railChild = CreateFrame("Frame", nil, railScroll)
    railChild:SetSize(RAIL_WIDTH - 7, (#PANEL_ORDER * RAIL_BTN_H) + 8)
    railScroll:SetScrollChild(railChild)
    railScroll:EnableMouseWheel(true)
    railScroll:SetScript("OnMouseWheel", function(s, delta)
        local range = s:GetVerticalScrollRange() or 0
        local nv = math.max(0, math.min(range, (s:GetVerticalScroll() or 0) - delta * 40))
        s:SetVerticalScroll(nv)
    end)
    self.railChild = railChild

    -- Content host (right of rail) with a per-panel header + gradient seam.
    -- Panels SetAllPoints(host) and start their own content at y=-62, clearing
    -- this header — identical contract to the old dashboard content host.
    local host = CreateFrame("Frame", nil, content)
    host:SetPoint("TOPLEFT", rail, "TOPRIGHT", 12, 0)
    host:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    host:SetClipsChildren(true)

    local title = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 4, -6)
    title:SetJustifyH("LEFT")
    host.Title = title

    local subtitle = host:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", host, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    if UI and UI.TextMuted then
        subtitle:SetTextColor(UI.Unpack(UI.TextMuted))
    else
        subtitle:SetTextColor(0.78, 0.80, 0.95)
    end
    host.Subtitle = subtitle

    local divider = host:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(2)
    divider:SetPoint("TOPLEFT", host, "TOPLEFT", 2, -44)
    divider:SetPoint("TOPRIGHT", host, "TOPRIGHT", -6, -44)
    if divider.SetGradient and CreateColor and UI and UI.Accent then
        divider:SetColorTexture(1, 1, 1, 1)
        divider:SetGradient("HORIZONTAL", CreateColor(UI.Unpack(UI.Accent)), CreateColor(UI.Unpack(UI.Accent2)))
    else
        divider:SetColorTexture(0.53, 0.47, 0.96, 0.35)
    end
    self.contentHost = host

    -- Build the rail buttons.
    for index, info in ipairs(PANEL_ORDER) do
        local button = CreateRailButton(railChild, index, info)
        button:SetScript("OnClick", function()
            self:ShowPanel(info.key)
        end)
        self.buttons[info.key] = button
    end

    return win
end

function Tabs:GetContentHost()
    if not self.contentHost then
        self:EnsureWindow()
    end
    return self.contentHost
end

function Tabs:EnsurePanels()
    local host = self:GetContentHost()
    if not host then
        return
    end
    for _, info in ipairs(PANEL_ORDER) do
        local owner = GetPanelOwner(info.key)
        if owner and not self.panels[info.key] and type(owner.CreatePanel) == "function" then
            self.panels[info.key] = owner:CreatePanel(host)
        end
    end
end

function Tabs:ShowPanel(key)
    key = key or "vendors"
    if not self:EnsureWindow() then
        return
    end
    self:EnsurePanels()

    local panel = self.panels[key]
    local owner = GetPanelOwner(key)
    local host = self.contentHost
    if not panel or not owner or not host then
        return
    end

    Villa.state.villaMode = true
    self.activeKey = key
    if Villa.db and Villa.db.ui and Villa.db.ui.tabs then
        Villa.db.ui.tabs.lastPanel = key
        Villa.db.ui.tabs.wasVillaMode = true
    end

    if self.window.ShowExpanded then
        self.window:ShowExpanded()
    else
        self.window:Show()
    end

    host.Title:SetText(owner.panelTitle or ("Villa " .. key:gsub("^%l", string.upper)))
    host.Subtitle:SetText(owner.panelSubtitle or "Housing intelligence")

    for panelKey, otherPanel in pairs(self.panels) do
        if otherPanel then
            otherPanel:SetShown(panelKey == key)
        end
    end

    if type(owner.InitUI) == "function" then
        owner:InitUI(panel)
    end
    if UI then
        UI:StyleDescendants(host)
        UI:StyleDescendants(panel)
    end
    if type(owner.Refresh) == "function" then
        owner:Refresh()
    end
    -- Re-skin buttons that Refresh created after the first StyleDescendants pass.
    if UI then
        UI:StyleDescendants(panel)
    end
    self:UpdateButtonStates()
end

function Tabs:HideAllPanels(silent)
    Villa.state.villaMode = false
    self.activeKey = nil
    if self.window then
        if self.window.HideShell then
            self.window:HideShell()
        else
            self.window:Hide()
        end
    end
    if Villa.db and Villa.db.ui and Villa.db.ui.tabs then
        Villa.db.ui.tabs.wasVillaMode = false
    end
    self:UpdateButtonStates()
end

function Tabs:IsShown()
    return self.window and self.window.IsShown and self.window:IsShown() or false
end
