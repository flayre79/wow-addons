local M = _G.FabledUI_Crafty
M.Hooks = M.Hooks or {}
local H = M.Hooks

local UPDATE_INTERVAL = 0.35

local function GetCraftingForm()
    if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then
        return nil
    end
    return ProfessionsFrame.CraftingPage.SchematicForm
end

local function GetOpenRecipeInfo()
    local form = GetCraftingForm()
    if not form or not form:IsVisible() or type(form.GetRecipeInfo) ~= "function" then
        return nil
    end
    return form:GetRecipeInfo()
end

local function UpdateBridgeState()
    if not H.bridge then
        return
    end

    local bridge = H.bridge
    local recipeInfo = GetOpenRecipeInfo()
    if not ProfessionsFrame or not ProfessionsFrame:IsVisible() or not recipeInfo or not recipeInfo.recipeID then
        bridge:Hide()
        return
    end

    local recipe = M.Recipes and M.Recipes:Get(recipeInfo.recipeID) or nil
    local name = (recipe and recipe.name) or recipeInfo.name or "Recipe"
    local craftable, craftableCount = M.Recipes and M.Recipes:IsCraftable(recipe) or false, 0
    if M.Recipes then
        craftable, craftableCount = M.Recipes:IsCraftable(recipe)
    end
    local queuedQuantity = M.Queue and M.Queue:GetRecipeQueuedQuantity(recipeInfo.recipeID) or 0

    bridge.title:SetText("Crafty")
    bridge.status:SetText(string.format("%s · queued %d%s", name, queuedQuantity, craftable and (" · ready " .. tostring(craftableCount)) or ""))
    bridge.queueOne:SetEnabled(recipe ~= nil)
    bridge.queueFive:SetEnabled(recipe ~= nil)
    bridge.shopping:SetEnabled(true)
    bridge.recipeID = recipeInfo.recipeID
    bridge:Show()
end

function H:CreateBridge()
    if self.bridge or not ProfessionsFrame then
        return
    end

    local parent = GetCraftingForm()
    if not parent then
        return
    end

    local bridge = CreateFrame("Frame", "FabledUI_CraftyBridge", parent, "BackdropTemplate")
    bridge:SetSize(242, 56)
    bridge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -18)
    bridge:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bridge:SetBackdropColor(0.03, 0.05, 0.07, 0.92)

    bridge.title = bridge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bridge.title:SetPoint("TOPLEFT", 10, -8)
    bridge.title:SetText("Crafty")

    bridge.status = bridge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bridge.status:SetPoint("TOPLEFT", bridge.title, "BOTTOMLEFT", 0, -2)
    bridge.status:SetWidth(220)
    bridge.status:SetJustifyH("LEFT")

    bridge.queueOne = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
    bridge.queueOne:SetSize(66, 20)
    bridge.queueOne:SetPoint("BOTTOMLEFT", 8, 8)
    bridge.queueOne:SetText("+Queue")
    bridge.queueOne:SetScript("OnClick", function()
        if bridge.recipeID then
            M.Queue:Add(bridge.recipeID, 1)
            UpdateBridgeState()
            if M.UI and M.UI.frame and M.UI.frame:IsShown() then
                M.UI:RefreshActiveTab()
            end
        end
    end)

    bridge.queueFive = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
    bridge.queueFive:SetSize(44, 20)
    bridge.queueFive:SetPoint("LEFT", bridge.queueOne, "RIGHT", 4, 0)
    bridge.queueFive:SetText("+5")
    bridge.queueFive:SetScript("OnClick", function()
        if bridge.recipeID then
            M.Queue:Add(bridge.recipeID, 5)
            UpdateBridgeState()
            if M.UI and M.UI.frame and M.UI.frame:IsShown() then
                M.UI:RefreshActiveTab()
            end
        end
    end)

    bridge.shopping = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
    bridge.shopping:SetSize(66, 20)
    bridge.shopping:SetPoint("LEFT", bridge.queueFive, "RIGHT", 4, 0)
    bridge.shopping:SetText("List")
    bridge.shopping:SetScript("OnClick", function()
        if M.UI then
            M.UI:ShowExportDialog("shopping")
        end
    end)

    if M.Toolkit then
        M.Toolkit:ApplyPanel(bridge, true)
        M.Toolkit:ApplyTitleText(bridge.title)
        M.Toolkit:ApplyBodyText(bridge.status, true)
        M.Toolkit:StyleFlatButton(bridge.queueOne)
        M.Toolkit:StyleFlatButton(bridge.queueFive)
        M.Toolkit:StyleFlatButton(bridge.shopping)
    end

    self.bridge = bridge
end

function H:RefreshBridge()
    if not self.bridge then
        self:CreateBridge()
    end
    UpdateBridgeState()
end

-- =============================================================================
-- ProfessionsFrame side-tab strip (ATT-style) — Phase 1
-- =============================================================================
-- Anchors a vertical strip of icons on the right edge of the Blizzard profession
-- window. Each icon toggles a slide-out panel that hosts a Crafty side view
-- (Alts, Trainers, Timers, etc). Phase 1 ships only the framework and the Alts
-- panel; Phase 3 will port the rest.
-- =============================================================================

local SIDE_TAB_SIZE = 36
local SIDE_TAB_SPACING = 4
local SIDE_PANEL_WIDTH = 380

local SIDE_TAB_DEFS = {
    {
        key = "alts",
        label = "Alts",
        icon = "Interface/Icons/INV_Misc_GroupNeedMore",
        tooltipTitle = "Alt professions",
        tooltipBody = "Account-wide profession matrix. See which alts know which recipes and at what skill level.",
    },
    {
        key = "trainers",
        label = "Trainers",
        icon = "Interface/Icons/INV_Scroll_08",
        tooltipTitle = "Profession trainers",
        tooltipBody = "Trainer locations across every expansion with one-click waypoints.",
    },
    {
        key = "timers",
        label = "Timers",
        icon = "Interface/Icons/Spell_Holy_BorrowedTime",
        tooltipTitle = "Concentration & cooldowns",
        tooltipBody = "Concentration recharge and per-recipe cooldowns for the open profession.",
    },
    {
        key = "gearing",
        label = "Gear",
        icon = "Interface/Icons/INV_Engineering_Toolbox",
        tooltipTitle = "Profession gear",
        tooltipBody = "Equipped profession gear and crafting stat totals for the current character.",
    },
    {
        key = "advisor",
        label = "Advisor",
        icon = "Interface/Icons/INV_Misc_Book_09",
        tooltipTitle = "Advisor",
        tooltipBody = "Contextual recommendations for the current profession session.",
    },
    {
        key = "data",
        label = "Data",
        icon = "Interface/Icons/INV_Misc_NoteBook_01",
        tooltipTitle = "Recent crafts",
        tooltipBody = "Last logged crafts: outcome, multicraft, resourcefulness, profit.",
    },
}

local function styleSideTabIcon(button)
    if M.Toolkit and M.Toolkit.StyleFlatButton then
        M.Toolkit:StyleFlatButton(button)
    end
end

function H:CreateSideTabStrip()
    if self.sideStrip or not ProfessionsFrame then return end

    local strip = CreateFrame("Frame", "FabledUI_CraftySideStrip", ProfessionsFrame)
    strip:SetSize(SIDE_TAB_SIZE, (SIDE_TAB_SIZE + SIDE_TAB_SPACING) * #SIDE_TAB_DEFS)
    -- Anchor below the typical ATT bookmark cluster (~150-200px from top).
    -- ATT and similar addons squat the upper-right corner of the profession
    -- frame; starting Crafty's strip lower gives both rooms to coexist.
    strip:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 4, -210)
    strip:SetFrameStrata("HIGH")
    self.sideStrip = strip
    self.sideTabs = {}

    for index, def in ipairs(SIDE_TAB_DEFS) do
        local btn = CreateFrame("Button", nil, strip, "BackdropTemplate")
        btn:SetSize(SIDE_TAB_SIZE, SIDE_TAB_SIZE)
        btn:SetPoint("TOPLEFT", 0, -((index - 1) * (SIDE_TAB_SIZE + SIDE_TAB_SPACING)))
        -- Match the chrome of CraftSim's / ATT's side tab strips: subtle
        -- dark fill with a 1px purple border, brighter highlight on hover,
        -- so a stack of tabs from multiple addons reads as one column.
        btn:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        btn:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
        btn:SetBackdropBorderColor(0.42, 0.40, 0.55, 0.95)

        -- Icon: trim only 2px from each edge (was 4) so the texture is
        -- visually similar to CraftSim/ATT side-tab icons. SetTexCoord
        -- crops the typical Blizzard icon border that otherwise looks
        -- like a chunky frame around the inner art.
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(def.icon)
        tex:SetPoint("TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", -2, 2)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = tex

        -- Highlight overlay: brightens the icon on hover without changing
        -- the layout. Selected state gets a brighter border (handled in
        -- ToggleSidePanel), so the user can see which tab is active.
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetColorTexture(1, 1, 1, 0.10)
        highlight:SetAllPoints(btn)

        btn:SetScript("OnClick", function() H:ToggleSidePanel(def.key) end)
        btn:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.tooltipTitle or def.label)
            if def.tooltipBody then
                GameTooltip:AddLine(def.tooltipBody, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        styleSideTabIcon(btn)
        self.sideTabs[def.key] = btn
    end
end

function H:CreateSidePanel()
    if self.sidePanel or not ProfessionsFrame then return end

    local panel = CreateFrame("Frame", "FabledUI_CraftySidePanel", ProfessionsFrame, "BackdropTemplate")
    panel:SetSize(SIDE_PANEL_WIDTH, 600)
    panel:SetPoint("TOPLEFT", self.sideStrip, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMLEFT", self.sideStrip, "BOTTOMRIGHT", 4, -480)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.05, 0.10, 0.94)
    panel:SetBackdropBorderColor(0.40, 0.40, 0.48, 0.85)
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 14, -12)

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -2)
    panel.subtitle:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.subtitle:SetJustifyH("LEFT")

    panel.body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.body:SetPoint("TOPLEFT", panel.subtitle, "BOTTOMLEFT", 0, -10)
    panel.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 48)
    panel.body:SetJustifyH("LEFT")
    panel.body:SetJustifyV("TOP")
    panel.body:SetWordWrap(true)

    panel.openInCrafty = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.openInCrafty:SetSize(160, 24)
    panel.openInCrafty:SetPoint("BOTTOMLEFT", 14, 14)
    panel.openInCrafty:SetText("Open in Crafty")
    panel.openInCrafty:SetScript("OnClick", function()
        if M.UI then
            M.UI:OpenToTab(panel.activeKey or "recipes")
        end
    end)
    if M.Toolkit and M.Toolkit.StyleFlatButton then
        M.Toolkit:StyleFlatButton(panel.openInCrafty)
    end

    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.closeButton:SetSize(80, 24)
    panel.closeButton:SetPoint("BOTTOMRIGHT", -14, 14)
    panel.closeButton:SetText("Close")
    panel.closeButton:SetScript("OnClick", function() H:HideSidePanel() end)
    if M.Toolkit and M.Toolkit.StyleFlatButton then
        M.Toolkit:StyleFlatButton(panel.closeButton)
    end

    self.sidePanel = panel
end

function H:HideSidePanel()
    if self.sidePanel then
        self.sidePanel:Hide()
        self.sidePanel.activeKey = nil
    end
    -- Reset the strip-button highlight state.
    for _, btn in pairs(self.sideTabs or {}) do
        if btn.SetBackdropColor then
            btn:SetBackdropColor(0.10, 0.10, 0.14, 0.85)
        end
    end
end

function H:ShowSidePanel(key)
    if not self.sidePanel then self:CreateSidePanel() end
    local panel = self.sidePanel
    if not panel then return end
    panel.activeKey = key
    panel:Show()

    -- Highlight the active strip button.
    for tabKey, btn in pairs(self.sideTabs or {}) do
        if btn.SetBackdropColor then
            if tabKey == key then
                btn:SetBackdropColor(0.36, 0.27, 0.55, 0.95)
            else
                btn:SetBackdropColor(0.10, 0.10, 0.14, 0.85)
            end
        end
    end

    self:RenderSidePanel(key)
end

function H:ToggleSidePanel(key)
    if self.sidePanel and self.sidePanel:IsShown() and self.sidePanel.activeKey == key then
        self:HideSidePanel()
        return
    end
    self:ShowSidePanel(key)
end

-- =============================================================================
-- Side panel renderers — one per registered SIDE_TAB_DEFS key.
-- =============================================================================
-- Each renderer keeps the panel compact (top-N entries) and points at the
-- standalone Crafty window for the full view via the "Open in Crafty" button
-- already attached to the panel chrome.
-- =============================================================================

local function shortChar(charKey)
    if M.GetShortCharacterName then
        return M:GetShortCharacterName(charKey)
    end
    return tostring(charKey or "?"):match("^([^%-]+)") or tostring(charKey or "?")
end

local function getActiveContext()
    if M.Recipes and M.Recipes.GetOpenProfessionContext then
        return M.Recipes:GetOpenProfessionContext()
    end
    return nil
end

local function setSubtitleForContext(panel, fallback)
    local ctx = getActiveContext()
    if ctx and ctx.professionName then
        panel.subtitle:SetText(string.format("%s · skill %s/%s", ctx.professionName, tostring(ctx.skillLevel or "?"), tostring(ctx.maxSkillLevel or "?")))
    else
        panel.subtitle:SetText(fallback or "No profession window currently open.")
    end
    return ctx
end

local function renderAltsPanel(panel)
    panel.title:SetText("Alts · Profession Matrix")
    local context = setSubtitleForContext(panel)
    local lines = {}
    if M.Alts and M.Alts.GetAllCharacters and M.Alts.GetCharacterData then
        local activeProf = context and context.professionName
        for _, charKey in ipairs(M.Alts:GetAllCharacters() or {}) do
            local entry = M.Alts:GetCharacterData(charKey) or {}
            local short = shortChar(charKey)
            local prof = activeProf and entry.professions and entry.professions[activeProf]
            if prof then
                local skill = (prof.skillLevel or 0) .. "/" .. (prof.maxSkillLevel or 0)
                lines[#lines + 1] = string.format("|cff5de0b5%s|r — %s · %s", short, activeProf, skill)
            elseif activeProf then
                lines[#lines + 1] = string.format("|cff888888%s|r — no %s data", short, activeProf)
            else
                local profCount = 0
                for _ in pairs(entry.professions or {}) do profCount = profCount + 1 end
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %d professions tracked", short, profCount)
            end
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No alt data captured yet. Log into your alts and open their profession windows once."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderTrainersPanel(panel)
    panel.title:SetText("Trainers")
    local context = setSubtitleForContext(panel, "All trainers across all professions:")
    local lines = {}
    if M.Trainers and M.Trainers.GetFiltered then
        local filterProf = context and context.professionName or nil
        local rows = M.Trainers:GetFiltered() or {}
        local count = 0
        for _, t in ipairs(rows) do
            if (not filterProf) or t.profession == filterProf then
                count = count + 1
                if count <= 10 then
                    local zone = t.zone or "Unknown"
                    local exp = t.expansion or "?"
                    lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s · %s · %s", t.name or "Trainer", t.profession or "?", exp, zone)
                end
            end
        end
        if count > 10 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", count - 10)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No trainer data available."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderTimersPanel(panel)
    panel.title:SetText("Concentration & Cooldowns")
    local context = setSubtitleForContext(panel)
    local lines = {}
    if M.Timers and M.Timers.GetRows then
        local rows = M.Timers:GetRows(context and context.professionName or nil) or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 12 then
                local label = row.label or row.name or row.recipeName or "Timer"
                local value = row.statusText or row.timeLeftText or row.value or ""
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s", label, value)
            end
        end
        if shown > 12 then
            lines[#lines + 1] = string.format("|cff888888… and %d more.|r", shown - 12)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No active concentration / cooldown data. Open a profession window to scan."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderGearingPanel(panel)
    panel.title:SetText("Profession Gear")
    local context = setSubtitleForContext(panel)
    local lines = {}
    if M.Gear and context and context.professionName then
        local charKey = M.GetCurrentCharacterKey and M:GetCurrentCharacterKey() or nil
        if charKey then
            local totals = M.Gear:GetTotals(charKey, context.professionName)
            local description = M.Gear:DescribeTotals(totals)
            if description and description ~= "" then
                lines[#lines + 1] = "|cff5de0b5Stats|r — " .. description
            end
            local tooltipLines = M.Gear:GetTooltipLines(charKey, context.professionName) or {}
            for i = 1, math.min(#tooltipLines, 12) do
                lines[#lines + 1] = tooltipLines[i]
            end
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "Open the profession window so Crafty can scan equipped tools and accessories."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderAdvisorPanel(panel)
    panel.title:SetText("Advisor")
    setSubtitleForContext(panel, "Recommendations for your current session.")
    local lines = {}
    if M.Advisor and M.Advisor.GetRows then
        local rows = M.Advisor:GetRows() or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 8 then
                local label = row.label or row.title or "Advisor"
                local status = row.statusText or row.summary or ""
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s", label, status)
            end
        end
        if shown > 8 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 8)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No advisor data yet. Open a profession window to populate context."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderDataPanel(panel)
    panel.title:SetText("Recent Crafts")
    setSubtitleForContext(panel, "Last logged crafts across all sessions.")
    local lines = {}
    if M.History and M.History.GetRecentRows then
        local rows = M.History:GetRecentRows() or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 12 then
                local name = row.recipeName or row.itemName or row.label or "Craft"
                local outcome = row.outcomeText or row.qualityText or ""
                local profit = row.profitText or ""
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s %s", name, outcome, profit)
            end
        end
        if shown > 12 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 12)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No craft history yet. Crafts you make in this session will appear here."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local SIDE_PANEL_RENDERERS = {
    alts     = renderAltsPanel,
    trainers = renderTrainersPanel,
    timers   = renderTimersPanel,
    gearing  = renderGearingPanel,
    advisor  = renderAdvisorPanel,
    data     = renderDataPanel,
}

function H:RenderSidePanel(key)
    local panel = self.sidePanel
    if not panel then return end

    local renderer = SIDE_PANEL_RENDERERS[key]
    if renderer then
        local ok, err = pcall(renderer, panel)
        if not ok then
            panel.title:SetText(key)
            panel.subtitle:SetText("(render error)")
            panel.body:SetText(tostring(err))
        end
    else
        panel.title:SetText(key)
        panel.subtitle:SetText("Unknown side panel.")
        panel.body:SetText("This side panel key has no renderer registered. Click 'Open in Crafty' for the full view.")
    end
end

-- =============================================================================
-- Bottom-tab integration — Phase 2
-- =============================================================================
-- Adds Crafty's profession-specific tabs alongside Blizzard's
-- Recipes / Specializations / Crafting Orders strip. Each tab swaps the
-- main content area with a Crafty overlay panel; clicking any Blizzard tab
-- dismisses our overlay so Blizzard's view is restored cleanly.
-- =============================================================================

local BOTTOM_TAB_DEFS = {
    { key = "queue",     label = "Queue",     tooltipBody = "Active crafting queue with material totals." },
    { key = "materials", label = "Materials", tooltipBody = "Have/Need/Shortage rollup for queued recipes." },
    { key = "goblin",    label = "Goblin",    tooltipBody = "Profit and margin analysis for craftable recipes." },
    { key = "guide",     label = "Guide",     tooltipBody = "Skill-up route for the open profession." },
    { key = "knowledge", label = "Knowledge", tooltipBody = "Profession knowledge sources for the open profession." },
}

local function findBlizzardTabStrip()
    if not ProfessionsFrame then return nil, nil end

    -- Modern retail TabSystem (preferred when available).
    if ProfessionsFrame.TabSystem and ProfessionsFrame.TabSystem.tabs then
        local tabs = ProfessionsFrame.TabSystem.tabs
        if #tabs > 0 then
            return ProfessionsFrame.TabSystem, tabs[#tabs]
        end
    end

    -- Fallback: scan global named tab buttons. Their order in Blizzard's
    -- frame is usually Recipes / Specializations / Crafting Orders, so the
    -- highest-indexed one is our anchor point.
    local lastTab, lastIndex
    for i = 1, 8 do
        local tab = _G["ProfessionsFrameTab" .. i]
        if tab and tab:IsObjectType("Button") then
            lastTab, lastIndex = tab, i
        end
    end
    if lastTab then
        return lastTab:GetParent() or ProfessionsFrame, lastTab
    end

    return nil, nil
end

function H:CreateBottomTabs()
    if self.bottomTabs or not ProfessionsFrame then return end

    local stripParent, lastBlizzardTab = findBlizzardTabStrip()
    if not stripParent or not lastBlizzardTab then return end

    self.bottomTabs = {}
    self.bottomTabsParent = stripParent
    local prevAnchor = lastBlizzardTab

    for _, def in ipairs(BOTTOM_TAB_DEFS) do
        -- Use Blizzard's PanelTopTabButtonTemplate when available so the
        -- buttons visually match the existing Recipes/Specializations
        -- /Crafting Orders chrome. Fall back to our themed flat button if
        -- the template can't be applied (older builds).
        local btn
        local templateOk = pcall(function()
            btn = CreateFrame("Button", "FabledUI_CraftyBottomTab_" .. def.key, stripParent, "PanelTopTabButtonTemplate")
        end)
        if not (templateOk and btn) then
            btn = CreateFrame("Button", "FabledUI_CraftyBottomTab_" .. def.key, stripParent, "BackdropTemplate")
            btn:SetSize(96, 26)
            if M.Toolkit and M.Toolkit.StyleFlatButton then
                M.Toolkit:StyleFlatButton(btn)
            end
        end

        btn:SetText(def.label)
        -- Blizzard's tabs auto-size to their text via PanelTemplates_TabResize.
        -- Use the canonical 0 padding so our tabs match the surrounding
        -- Recipes / Specializations / Crafting Orders sizing exactly.
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, btn, 0)
        end
        -- Ensure the visual state starts deselected — TabSystem manages
        -- selection on Blizzard tabs but our overlay tabs are separate.
        if PanelTemplates_DeselectTab then
            pcall(PanelTemplates_DeselectTab, btn)
        end
        -- The Blizzard tab textures have ~16px of side overhang. Anchoring
        -- with -16 on the left puts our tab flush against the previous tab's
        -- right edge with no visible gap, matching the native chain spacing.
        btn:SetPoint("LEFT", prevAnchor, "RIGHT", -16, 0)

        btn:SetScript("OnClick", function()
            H:ToggleBottomPanel(def.key)
        end)
        btn:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(def.label)
            GameTooltip:AddLine(def.tooltipBody or "", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        self.bottomTabs[def.key] = btn
        prevAnchor = btn
    end
end

function H:CreateBottomOverlay()
    if self.bottomOverlay or not ProfessionsFrame then return end

    local anchor = ProfessionsFrame.CraftingPage or ProfessionsFrame
    local overlay = CreateFrame("Frame", "FabledUI_CraftyBottomOverlay", ProfessionsFrame, "BackdropTemplate")
    overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", 12, -12)
    overlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -12, 40)
    overlay:SetFrameStrata("HIGH")
    overlay:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    overlay:SetBackdropColor(0.04, 0.05, 0.10, 0.96)
    overlay:SetBackdropBorderColor(0.40, 0.40, 0.48, 0.85)
    overlay:Hide()

    overlay.title = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    overlay.title:SetPoint("TOPLEFT", 16, -14)

    overlay.subtitle = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.subtitle:SetPoint("TOPLEFT", overlay.title, "BOTTOMLEFT", 0, -2)
    overlay.subtitle:SetPoint("RIGHT", overlay, "RIGHT", -16, 0)
    overlay.subtitle:SetJustifyH("LEFT")

    overlay.body = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.body:SetPoint("TOPLEFT", overlay.subtitle, "BOTTOMLEFT", 0, -10)
    overlay.body:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -16, 56)
    overlay.body:SetJustifyH("LEFT")
    overlay.body:SetJustifyV("TOP")
    overlay.body:SetWordWrap(true)

    overlay.openInCrafty = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    overlay.openInCrafty:SetSize(160, 24)
    overlay.openInCrafty:SetPoint("BOTTOMLEFT", 16, 16)
    overlay.openInCrafty:SetText("Open in Crafty")
    overlay.openInCrafty:SetScript("OnClick", function()
        if M.UI then
            M.UI:OpenToTab(overlay.activeKey or "queue")
        end
    end)

    overlay.closeButton = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    overlay.closeButton:SetSize(80, 24)
    overlay.closeButton:SetPoint("BOTTOMRIGHT", -16, 16)
    overlay.closeButton:SetText("Close")
    overlay.closeButton:SetScript("OnClick", function() H:HideBottomOverlay() end)

    if M.Toolkit and M.Toolkit.StyleFlatButton then
        M.Toolkit:StyleFlatButton(overlay.openInCrafty)
        M.Toolkit:StyleFlatButton(overlay.closeButton)
    end

    self.bottomOverlay = overlay
end

local function renderQueuePanel(panel)
    panel.title:SetText("Crafting Queue")
    setSubtitleForContext(panel, "Add recipes from the Recipes tab to populate this view.")
    local lines = {}
    if M.Queue and M.Queue.GetAll then
        local entries = M.Queue:GetAll() or {}
        local shown = 0
        for _, entry in ipairs(entries) do
            shown = shown + 1
            if shown <= 12 then
                local recipe = M.Recipes and M.Recipes:Get(entry.recipeID) or nil
                local name = (recipe and recipe.name) or entry.name or ("Recipe " .. tostring(entry.recipeID))
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — qty %d", name, entry.quantity or 1)
            end
        end
        if shown > 12 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 12)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "Queue is empty. Add recipes from the Recipes tab or via /crafty queue."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderMaterialsPanel(panel)
    panel.title:SetText("Materials Rollup")
    setSubtitleForContext(panel, "Aggregated material requirements across the queue.")
    local lines = {}
    if M.Materials and M.Materials.GetRows then
        local rows = M.Materials:GetRows() or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 12 then
                local name = row.name or ("Item " .. tostring(row.itemID))
                local need = row.need or 0
                local have = row.have or 0
                local short = math.max(0, need - have)
                local color = (short == 0) and "ff5de0b5" or "ffe09f5d"
                lines[#lines + 1] = string.format("|c%s%s|r — have %d / need %d", color, name, have, need)
            end
        end
        if shown > 12 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 12)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No queued materials. Queue a recipe to populate."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderGoblinPanel(panel)
    panel.title:SetText("Goblin · Profit Analysis")
    local context = setSubtitleForContext(panel, "Profit estimates require an open profession + AH price source (TSM/Auctionator).")
    local lines = {}
    if M.Profit and M.Profit.GetRows and context and context.professionName then
        local rows = M.Profit:GetRows(context.professionName) or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 10 then
                local name = row.name or ("Recipe " .. tostring(row.recipeID))
                local profit = row.profitText or "—"
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s", name, profit)
            end
        end
        if shown > 10 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 10)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No profit data yet. Make sure TSM or Auctionator is loaded and a profession is open."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderGuidePanel(panel)
    panel.title:SetText("Skill-up Guide")
    local context = setSubtitleForContext(panel, "Open a profession window to see its leveling steps.")
    local lines = {}
    if M.Training and M.Training.GetRows and context and context.professionName then
        local rows = M.Training:GetRows() or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 10 then
                local label = row.label or row.name or "Step"
                local value = row.statusText or row.notes or row.text or ""
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s", label, value)
            end
        end
        if shown > 10 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 10)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No guide data for this profession/expansion."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function renderKnowledgePanel(panel)
    panel.title:SetText("Knowledge Sources")
    local context = setSubtitleForContext(panel, "Knowledge sources are loaded on first profession-window open.")
    local lines = {}
    if M.Knowledge and M.Knowledge.GetRows and context and context.professionName then
        local rows = M.Knowledge:GetRows(context.professionName, context.expansion) or {}
        local shown = 0
        for _, row in ipairs(rows) do
            shown = shown + 1
            if shown <= 12 then
                local label = row.label or row.title or row.name or "Source"
                local note = row.statusText or row.note or row.summary or ""
                lines[#lines + 1] = string.format("|cffd0d0e0%s|r — %s", label, note)
            end
        end
        if shown > 12 then
            lines[#lines + 1] = string.format("|cff888888… and %d more in Crafty.|r", shown - 12)
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "No knowledge data yet. Open the profession window so the data pack loads."
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local BOTTOM_PANEL_RENDERERS = {
    queue     = renderQueuePanel,
    materials = renderMaterialsPanel,
    goblin    = renderGoblinPanel,
    guide     = renderGuidePanel,
    knowledge = renderKnowledgePanel,
}

function H:HideBottomOverlay()
    if self.bottomOverlay then
        self.bottomOverlay:Hide()
        self.bottomOverlay.activeKey = nil
    end
end

function H:ShowBottomPanel(key)
    if not self.bottomOverlay then self:CreateBottomOverlay() end
    local overlay = self.bottomOverlay
    if not overlay then return end

    -- Overlay sits on top of Blizzard's CraftingPage via FrameStrata HIGH +
    -- a solid backdrop. We don't touch Blizzard's page visibility — when
    -- the user clicks any Blizzard tab, our hook just hides this overlay
    -- and Blizzard's existing tab logic handles its own page swap.

    overlay.activeKey = key
    overlay:Show()

    local renderer = BOTTOM_PANEL_RENDERERS[key]
    if renderer then
        local ok, err = pcall(renderer, overlay)
        if not ok then
            overlay.title:SetText(key)
            overlay.subtitle:SetText("(render error)")
            overlay.body:SetText(tostring(err))
        end
    else
        overlay.title:SetText(key)
        overlay.subtitle:SetText("Unknown panel.")
        overlay.body:SetText("No renderer registered for key '" .. tostring(key) .. "'.")
    end
end

function H:ToggleBottomPanel(key)
    if self.bottomOverlay and self.bottomOverlay:IsShown() and self.bottomOverlay.activeKey == key then
        self:HideBottomOverlay()
        return
    end
    self:ShowBottomPanel(key)
end

-- Hook every Blizzard tab in the strip so clicking Recipes / Specializations
-- / Crafting Orders dismisses our overlay automatically.
function H:HookBlizzardTabs()
    local hooked = 0
    for i = 1, 8 do
        local tab = _G["ProfessionsFrameTab" .. i]
        if tab and not tab._fabledHooked then
            tab._fabledHooked = true
            tab:HookScript("OnClick", function() H:HideBottomOverlay() end)
            hooked = hooked + 1
        end
    end
    -- Also handle modern TabSystem callback if available.
    if ProfessionsFrame and ProfessionsFrame.TabSystem and ProfessionsFrame.TabSystem.tabs then
        for _, tab in ipairs(ProfessionsFrame.TabSystem.tabs) do
            if tab and not tab._fabledHooked then
                tab._fabledHooked = true
                tab:HookScript("OnClick", function() H:HideBottomOverlay() end)
                hooked = hooked + 1
            end
        end
    end
end

function H:Init()
    if self._initialized then
        return
    end

    if not ProfessionsFrame then
        return
    end

    -- CraftSim Module gate. The live profession-window overlay is part of
    -- the CraftSim feature surface; when disabled, none of the bridge /
    -- side-tab / bottom-tab / hooked-tab UI is created so the user gets a
    -- vanilla ProfessionsFrame experience.
    if M.CraftSim and not M.CraftSim:IsFeatureEnabled("hooks") then
        return
    end

    self._initialized = true
    self:CreateBridge()
    self:CreateSideTabStrip()
    self:CreateBottomTabs()
    self:HookBlizzardTabs()

    ProfessionsFrame:HookScript("OnShow", function()
        if H.bridge then
            H.bridge.elapsed = 0
            H.bridge:SetScript("OnUpdate", function(frame, elapsed)
                frame.elapsed = (frame.elapsed or 0) + elapsed
                if frame.elapsed >= UPDATE_INTERVAL then
                    frame.elapsed = 0
                    UpdateBridgeState()
                end
            end)
        end
        H:RefreshBridge()
        if H.sideStrip then H.sideStrip:Show() end
    end)

    ProfessionsFrame:HookScript("OnHide", function()
        if H.bridge then
            H.bridge:SetScript("OnUpdate", nil)
            H.bridge:Hide()
        end
        if H.sideStrip then H.sideStrip:Hide() end
        H:HideSidePanel()
        H:HideBottomOverlay()
    end)

    if ProfessionsFrame:IsVisible() then
        self:RefreshBridge()
    end
end
