local M = _G.FabledUI_Crafty
M.UI = M.UI or {}
local UI = M.UI
local TK = M.Toolkit

local ROW_HEIGHT = 24
local WINDOW_SUBTITLE = "Your account-wide crafting command center — recipes, queue, materials, knowledge & more"

-- Default per-row button geometry. Individual render paths resize these (the
-- Trainers tab uses a 110px primary; the Recipes tab used a 58px "Optimize"),
-- and rows are pooled across every tab -- so ResetRow has to put the sizes back
-- or a recycled row keeps the previous tab's widths and the right edge lands in
-- a different place row to row.
local ACTION_BUTTON_WIDTH  = 78
local ACTION_BUTTON_HEIGHT = 20
local MINI_BUTTON_WIDTH    = 24

-- Horizontal space reserved at the right edge of every row for its action
-- buttons. Columns are laid out left-to-right with no knowledge of the buttons,
-- which are anchored to the right edge, so without a reserved gutter a wide
-- column simply runs underneath them. Tabs size their columns against
-- UI:GetContentWidth(), which subtracts this.
local ACTIONS_GUTTER = 96

local function CreateLabel(parent, width, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWidth(width)
    -- Lock columns to a single line so overflowing text truncates with an
    -- ellipsis instead of wrapping into the next row's render box.
    fs:SetWordWrap(false)
    if fs.SetMaxLines then
        fs:SetMaxLines(1)
    end
    if fs.SetNonSpaceWrap then
        fs:SetNonSpaceWrap(false)
    end
    return fs
end

local function EnsureCheckboxLabel(checkButton, text)
    local label = checkButton.Text or checkButton.text
    if not label then
        label = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", checkButton, "RIGHT", 4, 1)
        checkButton.Text = label
    end
    label:SetText(text or "")
    if TK then
        TK:ApplyBodyText(label)
    end
    return label
end

local function SafeWidgetText(widget, text)
    if widget and widget.SetText then
        pcall(widget.SetText, widget, text or "")
    end
end

local function SetDropdownText(dropdown, text, fallback)
    if not dropdown then
        return
    end

    local finalText = text or fallback or ""
    if dropdown.OverrideText then
        pcall(dropdown.OverrideText, dropdown, finalText)
    end
    if dropdown.SetSelectionText then
        pcall(dropdown.SetSelectionText, dropdown, finalText)
    end
    if dropdown.SetDefaultText then
        pcall(dropdown.SetDefaultText, dropdown, finalText)
    end

    SafeWidgetText(dropdown.Text, finalText)
    SafeWidgetText(dropdown.Label, finalText)
    SafeWidgetText(dropdown.SelectedText, finalText)
    if dropdown.GetFontString then
        SafeWidgetText(dropdown:GetFontString(), finalText)
    end
end

local function StyleActionButton(button)
    if not button then
        return
    end
    if TK then
        TK:StyleFlatButton(button)
    end
end

-- Apply theme paint to UICheckButtonTemplate-derived checkboxes so the
-- filter row matches the rest of the suite chrome rather than reading as
-- raw Blizzard widgets.
local function StyleFilterCheckbox(check)
    if not check or not TK then return end
    if TK.StyleCheckbox then
        TK:StyleCheckbox(check)
    end
    local label = check.Text or check.text
    if label and TK.ApplyBodyText then
        TK:ApplyBodyText(label)
    end
    if label and label.SetTextColor then
        label:SetTextColor(0.92, 0.92, 1.00)
    end
end

-- Tighten dropdown chrome: even though the Blizzard WowStyle1 dropdown is
-- the canonical retail style, we still want the visible text aligned and
-- the surrounding highlight matching the suite accent.
local function StyleFilterDropdown(dropdown)
    if not dropdown or not TK then return end
    if TK.StyleDropdown then
        TK:StyleDropdown(dropdown)
    elseif TK.StyleFlatButton then
        TK:StyleFlatButton(dropdown)
    end
    if dropdown.Text and dropdown.Text.SetJustifyH then
        dropdown.Text:SetJustifyH("LEFT")
    end
end

local function FormatKnowledgeText(recipeID)
    local state = M.Recipes:GetKnowledgeState(recipeID)
    local display, knownBy = M.Recipes:GetKnownByDisplay(recipeID)
    -- No glyph prefixes: ★/☆ are missing from WoW's default fonts and render
    -- as tofu boxes. Color alone carries the state (teal = you, grey = alt).
    if state == "CURRENT" then
        return "|cff5cf0a0" .. display .. "|r", knownBy
    elseif state == "ALT" then
        return "|cffb8b8b8" .. display .. "|r", knownBy
    end
    return "|cffd95f5fUnknown|r", knownBy
end

local function BuildMaterialSummary(recipe, quantity)
    if not recipe or not recipe.materials then
        return ""
    end
    local parts = {}
    for _, mat in ipairs(recipe.materials) do
        parts[#parts + 1] = string.format("%s x%d", mat.name or "Material", (mat.qty or 0) * (quantity or 1))
    end
    return table.concat(parts, ", ")
end

-- CR-006: Builds a compact icon row for a recipe's materials inside the
-- Queue tab's "Materials" column. Each icon is a 20x20 button with a
-- stack-count overlay and an OnEnter tooltip that shows full item name
-- + total count. Uses Item:CreateFromItemID async loader so missing item
-- cache entries fill in once the client receives the item info event.
local MAT_ICON_SIZE = 20
local MAT_ICON_SPACING = 2

local function ReleaseMaterialIcons(row)
    if not row or not row.matIcons then
        return
    end
    for _, icon in ipairs(row.matIcons) do
        icon:Hide()
        icon:ClearAllPoints()
        icon:SetScript("OnEnter", nil)
        icon:SetScript("OnLeave", nil)
        if icon.texture then icon.texture:SetTexture(nil) end
        if icon.count then icon.count:SetText("") end
    end
end

local function GetMaterialIcon(row, parent, index)
    row.matIcons = row.matIcons or {}
    local icon = row.matIcons[index]
    if icon then
        icon:SetParent(parent)
        return icon
    end
    icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(MAT_ICON_SIZE, MAT_ICON_SIZE)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
    icon.count:SetJustifyH("RIGHT")
    row.matIcons[index] = icon
    return icon
end

local function RenderMaterialIcons(row, parentColumn, recipe, quantity)
    ReleaseMaterialIcons(row)
    if not parentColumn or not recipe or not recipe.materials then
        return
    end
    -- Hide the column FontString text since we are drawing icons over it.
    parentColumn:SetText("")
    local x = 0
    for index, mat in ipairs(recipe.materials) do
        local icon = GetMaterialIcon(row, parentColumn, index)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", parentColumn, "LEFT", x, 0)
        icon:Show()
        local total = (mat.qty or 0) * (quantity or 1)
        if icon.count then
            if total and total > 1 then
                icon.count:SetText(tostring(total))
            else
                icon.count:SetText("")
            end
        end
        local matName = mat.name or ("Material " .. tostring(mat.itemID or "?"))
        local matItemID = mat.itemID
        -- Async-load both the icon texture and the canonical item name. We
        -- wrap in pcall because Item:CreateFromItemID is unavailable in
        -- some classic clients; if so, fall back to GetItemInfoInstant.
        if matItemID and Item and Item.CreateFromItemID then
            local ok, itemRef = pcall(Item.CreateFromItemID, Item, matItemID)
            if ok and itemRef and itemRef.ContinueOnItemLoad then
                itemRef:ContinueOnItemLoad(function()
                    if not icon:IsShown() then return end
                    if icon.texture and itemRef.GetItemIcon then
                        local texPath = itemRef:GetItemIcon()
                        if texPath then icon.texture:SetTexture(texPath) end
                    end
                    if itemRef.GetItemName then
                        local resolved = itemRef:GetItemName()
                        if resolved and resolved ~= "" then
                            icon._tooltipName = resolved
                        end
                    end
                end)
            end
        end
        -- C_Item.GetItemIconByID: the global GetItemIcon is gone in 12.1.5.
        if icon.texture and (not icon.texture:GetTexture()) and matItemID and C_Item and C_Item.GetItemIconByID then
            local fallback = C_Item.GetItemIconByID(matItemID)
            if fallback then icon.texture:SetTexture(fallback) end
        end
        icon._tooltipName = icon._tooltipName or matName
        local resolvedName = matName
        local totalCount = total
        local matItemIDLocal = matItemID
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if matItemIDLocal then
                -- Prefer Blizzard's full hyperlink tooltip when possible.
                local link = (C_Item and C_Item.GetItemLinkByID and C_Item.GetItemLinkByID(matItemIDLocal)) or nil
                if link then
                    GameTooltip:SetHyperlink(link)
                else
                    GameTooltip:SetItemByID(matItemIDLocal)
                end
                GameTooltip:AddLine(string.format("Required: %d", totalCount or 0), 0.85, 0.85, 0.85, true)
            else
                GameTooltip:AddLine(self._tooltipName or resolvedName, 1, 1, 1)
                GameTooltip:AddLine(string.format("Required: %d", totalCount or 0), 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        x = x + MAT_ICON_SIZE + MAT_ICON_SPACING
    end
end

local function SortedCharacterKeys(grouped)
    local keys = {}
    for key in pairs(grouped or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function SortProfessionParts(parts)
    table.sort(parts, function(a, b)
        return a.sortKey < b.sortKey
    end)
    local textParts = {}
    for _, part in ipairs(parts) do
        textParts[#textParts + 1] = part.text
    end
    return table.concat(textParts, "  |  ")
end

function UI:SetWindowStatus(text)
    self._statusText = text or ""
    if self.frame and self.frame.SetShellStatus then
        self.frame:SetShellStatus(self._statusText)
    end
end

function UI:UpdateFilterControlState()
    if not self.frame then
        return
    end

    if self.searchBox and self.searchBox:GetText() ~= (M.filters.text or "") then
        self.searchBox:SetText(M.filters.text or "")
    end
    if self.matsCheck then
        self.matsCheck:SetChecked(M.filters.searchMats == true)
    end
    if self.readyCheck then
        self.readyCheck:SetChecked(M.filters.readyOnly == true)
    end
    if self.uncollectedCheck then
        self.uncollectedCheck:SetChecked(M.filters.uncollectedOnly == true)
    end
    if self.powerCraftingCheck then
        local enabled = (M.filters.powerCrafting == true) or (M.settings and M.settings.useCraftSimQueuePlanner == true)
        self.powerCraftingCheck:SetChecked(enabled)
    end
    if self.knownOnlyCheck then
        self.knownOnlyCheck:SetChecked(M.filters.knownOnly == true)
    end

    local professionText = (M.filters.profession == "ALL") and "All professions" or (M.filters.profession or "Profession")
    local expansionText = (M.filters.expansion == "ALL") and "All expansions" or (M.filters.expansion or "Expansion")
    local collectionText = ({ ALL = "All", COLLECTED = "Collected", UNCOLLECTED = "Uncollected" })[M.filters.collected or "ALL"] or "Collection"
    SetDropdownText(self.professionDrop, professionText, "Profession")
    SetDropdownText(self.expansionDrop, expansionText, "Expansion")
    SetDropdownText(self.collectedDrop, collectionText, "Collection")

    if self.tabs and self.tabs.profit then
        self.tabs.profit:SetShown(M.settings.showProfitAnalysis ~= false)
        if self.currentTab == "profit" and M.settings.showProfitAnalysis == false then
            self.currentTab = "recipes"
        end
    end
end

function UI:UpdateToolbarForTab()
    if not self.frame then
        return
    end

    self.addAllButton:Hide()
    self.exportButton:Hide()

    local currentTab = self.currentTab or "recipes"
    if currentTab == "recipes" then
        local stats = M.Recipes:GetSummaryStats()
        self.addAllButton:Show()
        self.addAllButton:SetText(string.format("Add Ready (%d)", stats.craftable or 0))
        self.addAllButton:SetEnabled((stats.craftable or 0) > 0)
        self.addAllButton:SetScript("OnClick", function()
            local added = M.Queue:AddAllFiltered()
            M:Print(string.format("Added %d craftable recipe(s) to the queue.", added or 0))
            UI:RefreshActiveTab()
        end)

        self.exportButton:Show()
        self.exportButton:SetText("Shopping Export")
        self.exportButton:SetEnabled(true)
        self.exportButton:SetScript("OnClick", function()
            UI:ShowExportDialog("shopping")
        end)
    elseif currentTab == "queue" then
        local summary = M.Queue:GetSummary()
        self.addAllButton:Show()
        self.addAllButton:SetText("Clear Queue")
        self.addAllButton:SetEnabled((summary.entries or 0) > 0)
        self.addAllButton:SetScript("OnClick", function()
            M.Queue:Clear()
            UI:RefreshActiveTab()
        end)

        self.exportButton:Show()
        self.exportButton:SetText("Shopping Export")
        self.exportButton:SetEnabled(true)
        self.exportButton:SetScript("OnClick", function()
            UI:ShowExportDialog("shopping")
        end)
    elseif currentTab == "materials" then
        self.exportButton:Show()
        self.exportButton:SetText("Shopping Export")
        self.exportButton:SetEnabled(true)
        self.exportButton:SetScript("OnClick", function()
            UI:ShowExportDialog("shopping")
        end)
    elseif currentTab == "knowledge" then
        self.addAllButton:Show()
        self.addAllButton:SetText("Refresh")
        self.addAllButton:SetEnabled(true)
        self.addAllButton:SetScript("OnClick", function()
            M:RefreshAll()
            UI:RefreshActiveTab()
        end)
    elseif currentTab == "guide" then
        self.addAllButton:Show()
        self.addAllButton:SetText("Show Nearby")
        self.addAllButton:SetEnabled(true)
        self.addAllButton:SetScript("OnClick", function()
            if M.settings then
                M.settings.guideShowAllSteps = not M.settings.guideShowAllSteps
                M:SaveSettings()
                UI:RefreshActiveTab()
            end
        end)
    elseif currentTab == "timers" then
        self.addAllButton:Show()
        self.addAllButton:SetText("Refresh Snapshot")
        self.addAllButton:SetEnabled(true)
        self.addAllButton:SetScript("OnClick", function()
            M:RefreshAll()
            UI:RefreshActiveTab()
        end)

        self.exportButton:Show()
        self.exportButton:SetText("Timers Export")
        self.exportButton:SetEnabled(true)
        self.exportButton:SetScript("OnClick", function()
            UI:ShowExportDialog("timers")
        end)
    elseif currentTab == "data" then
        self.exportButton:Show()
        self.exportButton:SetText("CSV Export")
        self.exportButton:SetEnabled(true)
        self.exportButton:SetScript("OnClick", function()
            UI:ShowExportDialog("history")
        end)
    end

    StyleActionButton(self.addAllButton)
    StyleActionButton(self.exportButton)
end

function UI:ApplyToolkitAppearance()
    if not self.frame then
        return
    end

    if TK then
        TK:ApplyPanel(self.filterBar, true)
        TK:ApplyPanel(self.tabBar, false)
        TK:ApplyPanel(self.listHost, false)
        TK:ApplyBodyText(self.emptyState, true)
        if self.header and self.header.columns then
            for _, column in ipairs(self.header.columns) do
                TK:ApplyTitleText(column)
            end
        end
    end

    StyleActionButton(self.addAllButton)
    StyleActionButton(self.exportButton)
    if self.rows then
        for _, row in pairs(self.rows) do
            if row.actionButton then StyleActionButton(row.actionButton) end
            if row.secondaryButton then StyleActionButton(row.secondaryButton) end
            if row.tertiaryButton then StyleActionButton(row.tertiaryButton) end
        end
    end
end

function UI:CreateShellWindow()
    if self.frame then
        return self.frame
    end
    if M.EnsureStorageTables then
        M:EnsureStorageTables()
    end

    local toolkit = TK and TK:GetRuntime() or nil
    if not toolkit or not toolkit.Shell or type(toolkit.Shell.CreateWindow) ~= "function" then
        M:Print("FabledUI_UIToolkit is missing or not ready, so the Crafty shell could not be created.")
        return nil
    end

    M.db.window = TK:EnsureWindowState(M.db.window)

    local frame = toolkit.Shell:CreateWindow("FabledUI_CraftyMain", {
        title = "FabledUI - Crafty",
        subtitle = WINDOW_SUBTITLE,
        theme = TK.THEME,
        accentColor = TK.ACCENT,
        width = M.db.window.width,
        height = M.db.window.height,
        minWidth = 1160,
        minHeight = 680,
        maxWidth = 1800,
        maxHeight = 1200,
        state = M.db.window,
        ribbon = false,
        -- Debounce resize: re-render only after the user stops dragging.
        -- Otherwise every pixel of resize triggers a full tab rebuild over
        -- 247+ rows, which lags the game.
        onSizeChanged = function()
            if not (UI.frame and UI.frame:IsShown()) then return end
            UI._resizePending = (UI._resizePending or 0) + 1
            local token = UI._resizePending
            C_Timer.After(0.18, function()
                if UI._resizePending == token and UI.frame and UI.frame:IsShown() then
                    UI:RefreshActiveTab()
                end
            end)
        end,
    })

    self.frame = frame
    self.content = frame.Content
    frame:SetShellStatus(self._statusText or "Ready")

    -- CR-006b: apply persisted UI text scale to the main shell on creation.
    -- The slider in the Crafty Settings panel re-applies this via UI:ApplyUIScale().
    if self.ApplyUIScale then
        self:ApplyUIScale()
    end

    return frame
end

-- CR-006b: applies the M.settings.uiScale value to the main Crafty window.
-- Called on shell creation and whenever the Settings slider changes.
function UI:ApplyUIScale()
    if not self.frame then
        return
    end
    local scale = (M.settings and tonumber(M.settings.uiScale)) or 1.0
    if scale < 0.85 then scale = 0.85 end
    if scale > 1.4 then scale = 1.4 end
    if self.frame.SetScale then
        pcall(self.frame.SetScale, self.frame, scale)
    end
end

-- Tiny inline profiler hook so /crafty profile can attribute first-open cost.
local function _profileStep(label, fn)
    local start = (debugprofilestop and debugprofilestop()) or 0
    fn()
    local elapsed = ((debugprofilestop and debugprofilestop()) or 0) - start
    if M and M._bootProfile then
        M._bootProfile[#M._bootProfile + 1] = { label = label, ms = elapsed, ok = true }
    end
    return elapsed
end

function UI:Init()
    if self.frame then
        return
    end

    -- The donor data pack (FabledUI_Crafty_Data, ~50k LOC) is now pre-loaded
    -- ~8s after PLAYER_LOGIN by Core.lua, so opening the UI no longer blocks
    -- on a 60s LoD parse. If the user happens to open before the deferred
    -- preload fires, EnsureDataLoaded() is still a one-shot — calling it
    -- here as a fallback guarantees data is present without a second hit.
    if M.EnsureDataLoaded and not M._dataLoaded then
        _profileStep("UI:Init: EnsureDataLoaded", function() M:EnsureDataLoaded() end)
    end

    local frame
    _profileStep("UI:Init: CreateShellWindow", function() frame = self:CreateShellWindow() end)
    if not frame then
        return
    end

    local content = self.content

    local filterBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    filterBar:SetPoint("TOPLEFT", 0, -2)
    filterBar:SetPoint("TOPRIGHT", 0, -2)
    filterBar:SetHeight(90)
    self.filterBar = filterBar

    -- FableNeon component toolbar. NC = the UIToolkit neon component kit;
    -- Crafty hard-depends on FabledUI_UIToolkit so this is always present.
    local NC = (rawget(_G, "FabledUI_UIToolkit") or {}).Components

    local searchFrame = NC:CreateSearchBox(filterBar, {
        width = 280, height = 30,
        placeholder = "Search recipes or materials…",
        onChange = function(text)
            -- No-op when unchanged: the component fires OnTextChanged for the
            -- initial SetText during window construction, before tabs exist.
            if (M.filters.text or "") == (text or "") then return end
            M.filters.text = text or ""
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    searchFrame:SetPoint("TOPLEFT", 14, -14)
    searchFrame.editBox:SetText(M.filters.text or "")
    self.searchBoxFrame = searchFrame
    -- Compat: existing refresh code calls self.searchBox:GetText()/SetText().
    self.searchBox = searchFrame.editBox
    local searchBox = searchFrame

    -- Filter toggles as neon pills (replaces UICheckButtonTemplate checkboxes).
    -- Each keeps the old self.* field name and a SetChecked method so the
    -- RefreshActiveTab sync code (lines ~283-297) keeps working unchanged.
    local function attachTooltip(widget, title, lines)
        widget:HookScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
            end
            GameTooltip:Show()
        end)
        widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local matsCheck = NC:CreateToggle(filterBar, {
        text = "+ Mats", width = 84, fill = "cyan",
        checked = M.filters.searchMats,
        onToggle = function(state)
            M.filters.searchMats = state
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    matsCheck:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    self.matsCheck = matsCheck

    local readyCheck = NC:CreateToggle(filterBar, {
        text = "Ready only", width = 104, fill = "green",
        checked = M.filters.readyOnly,
        onToggle = function(state)
            M.filters.readyOnly = state
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    readyCheck:SetPoint("LEFT", matsCheck, "RIGHT", 8, 0)
    self.readyCheck = readyCheck

    local uncollectedCheck = NC:CreateToggle(filterBar, {
        text = "Uncollected", width = 112, fill = "purple",
        checked = M.filters.uncollectedOnly == true,
        onToggle = function(state)
            M.filters.uncollectedOnly = state
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    uncollectedCheck:SetPoint("LEFT", readyCheck, "RIGHT", 8, 0)
    attachTooltip(uncollectedCheck, "Uncollected Only", {
        { "Hide recipes whose decor output is already collected (uses Villa catalog when available, otherwise inventory check).", 0.85, 0.85, 0.85 },
    })
    self.uncollectedCheck = uncollectedCheck

    local knownOnlyCheck = NC:CreateToggle(filterBar, {
        text = "Known only", width = 108, fill = "azure",
        checked = M.filters.knownOnly == true,
        onToggle = function(state)
            M.filters.knownOnly = state
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    knownOnlyCheck:SetPoint("LEFT", uncollectedCheck, "RIGHT", 8, 0)
    attachTooltip(knownOnlyCheck, "Known recipes only", {
        { "Hide recipes that this character (and their alts) doesn't know yet.", 0.85, 0.85, 0.85 },
        { "Typing in the search box temporarily widens to all recipes.", 0.65, 0.85, 0.95 },
    })
    self.knownOnlyCheck = knownOnlyCheck

    local powerCraftingCheck = NC:CreateToggle(filterBar, {
        text = "Power Crafting", width = 128, fill = "pink",
        checked = (M.filters.powerCrafting == true) or (M.settings and M.settings.useCraftSimQueuePlanner == true),
        onToggle = function(state)
            M.filters.powerCrafting = state
            if M.settings then
                M.settings.useCraftSimQueuePlanner = state
            end
            M:SaveSettings()
            if M.Fire then M:Fire("DataChanged") end
            UI:RefreshActiveTab()
        end,
    })
    powerCraftingCheck:SetPoint("LEFT", knownOnlyCheck, "RIGHT", 8, 0)
    attachTooltip(powerCraftingCheck, "Power Crafting (Raw Materials)", {
        { "Resolve materials through the full DAG to raw inputs (CraftSim-like queue planner).", 0.85, 0.85, 0.85 },
        { "When off: materials list shows direct ingredients only.", 0.85, 0.85, 0.85 },
        { "Synced with the 'Use CraftSim-Like Queue Planner' setting.", 0.65, 0.85, 0.95 },
    })
    self.powerCraftingCheck = powerCraftingCheck

    -- Filter dropdowns as neon pills (replaces WowStyle1FilterDropdownTemplate).
    -- Same options/menu logic (MenuUtil radio menus); the component exposes
    -- .Text so the SetDropdownText label sync at RefreshActiveTab still works.
    local professionDrop = NC:CreateDropdown(filterBar, {
        width = 170, height = 30, defaultText = "Profession",
        getOptions = function()
            local options = {{
                text = "All professions",
                value = "ALL",
                isSelected = function() return M.filters.profession == "ALL" end,
            }}
            for _, name in ipairs(M.PROFESSION_ORDER or {}) do
                local optionName = name
                options[#options + 1] = {
                    text = optionName,
                    value = optionName,
                    isSelected = function() return M.filters.profession == optionName end,
                }
            end
            return options
        end,
        onSelect = function(value)
            M.filters.profession = value
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    professionDrop:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -8)
    self.professionDrop = professionDrop

    local expansionDrop = NC:CreateDropdown(filterBar, {
        width = 170, height = 30, defaultText = "Expansion",
        getOptions = function()
            local options = {{
                text = "All expansions",
                value = "ALL",
                isSelected = function() return M.filters.expansion == "ALL" end,
            }}
            for _, name in ipairs(M.EXPANSION_ORDER or {}) do
                local optionName = name
                options[#options + 1] = {
                    text = optionName,
                    value = optionName,
                    isSelected = function() return M.filters.expansion == optionName end,
                }
            end
            return options
        end,
        onSelect = function(value)
            M.filters.expansion = value
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    expansionDrop:SetPoint("LEFT", professionDrop, "RIGHT", 12, 0)
    self.expansionDrop = expansionDrop

    local collectedDrop = NC:CreateDropdown(filterBar, {
        width = 160, height = 30, defaultText = "Collection",
        getOptions = function()
            local states = {
                { text = "All", value = "ALL" },
                { text = "Collected", value = "COLLECTED" },
                { text = "Uncollected", value = "UNCOLLECTED" },
            }
            local options = {}
            for _, state in ipairs(states) do
                local optionText = state.text
                local optionValue = state.value
                options[#options + 1] = {
                    text = optionText,
                    value = optionValue,
                    isSelected = function() return M.filters.collected == optionValue end,
                }
            end
            return options
        end,
        onSelect = function(value)
            M.filters.collected = value
            M:SaveSettings()
            UI:RefreshActiveTab()
        end,
    })
    collectedDrop:SetPoint("LEFT", expansionDrop, "RIGHT", 12, 0)
    self.collectedDrop = collectedDrop

    -- Action buttons as neon components. "Add Ready" is the toolbar's one
    -- primary (cyan-filled) action; the rest are quiet secondaries.
    -- FabledUIStyled=true stops the legacy StyleActionButton re-style calls
    -- in UpdateToolbarForTab from stacking flat textures on top of the pills.
    local addAllButton = NC:CreateButton(filterBar, { text = "Add Ready (0)", width = 160, height = 28, primary = true })
    addAllButton.FabledUIStyled = true
    addAllButton:SetPoint("LEFT", collectedDrop, "RIGHT", 16, 0)
    self.addAllButton = addAllButton

    local exportButton = NC:CreateButton(filterBar, { text = "Shopping Export", width = 128, height = 28 })
    exportButton.FabledUIStyled = true
    exportButton:SetPoint("LEFT", addAllButton, "RIGHT", 8, 0)
    self.exportButton = exportButton

    -- Manual rescan button: opens or pings the Blizzard profession window
    -- so TRADE_SKILL_LIST_UPDATE fires and the live recipe scan repopulates
    -- M.db.cache.recipes. Provides a clear out-of-band path when the user
    -- expects to see learned recipes that aren't showing up.
    local rescanButton = NC:CreateButton(filterBar, { text = "Rescan", width = 100, height = 28 })
    rescanButton.FabledUIStyled = true
    rescanButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
    rescanButton:SetScript("OnClick", function()
        local context
        if M.Recipes and M.Recipes.GetOpenProfessionContext then
            context = M.Recipes:GetOpenProfessionContext()
        end
        if M.RefreshAll then
            M:RefreshAll()
        end
        local scanned = 0
        if M.Recipes and M.Recipes.ScanOpenProfession then
            scanned = M.Recipes:ScanOpenProfession(true) or 0
        end
        -- Sync the filter dropdowns to whatever profession was scanned so the
        -- user actually sees the freshly-cached recipes instead of having
        -- their previous filter quietly hide them.
        if context and context.professionName then
            M.filters.profession = context.professionName
        end
        if context and context.expansion and M.Recipes and M.Recipes.NormalizeExpansion then
            M.filters.expansion = M.Recipes:NormalizeExpansion(context.expansion)
        end
        if M.SaveSettings then M:SaveSettings() end
        UI:RefreshActiveTab()
        if context then
            UI:SetWindowStatus(string.format("Rescanned %s · %s · %d recipes cached. Filter snapped to match.",
                tostring(context.professionName or "?"),
                tostring(context.expansion or "?"),
                scanned))
        else
            UI:SetWindowStatus("Rescan: no profession window is open. Open Tailoring/Enchanting/etc. and click Rescan.")
        end
    end)
    rescanButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Rescan recipes")
        GameTooltip:AddLine("Re-pulls live recipe data from whichever profession window is currently open.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("If your known recipes aren't showing, open the profession window and click this.", 0.65, 0.85, 0.95, true)
        GameTooltip:Show()
    end)
    rescanButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.rescanButton = rescanButton

    local tabBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -10)
    tabBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -10)
    tabBar:SetHeight(32)
    self.tabBar = tabBar

    local tabs = {
        { key = "recipes", text = "Recipes" },
        { key = "queue", text = "Queue" },
        { key = "materials", text = "Materials" },
        -- Inventory answers "what stock do I hold"; Materials answers "what is
        -- my queue still short of". Adjacent because users reach for one when
        -- the other turns out not to be the question they had.
        { key = "inventory", text = "Inventory" },
        { key = "advisor", text = "Advisor" },
        { key = "knowledge", text = "Knowledge" },
        { key = "guide", text = "Guide" },
        { key = "alts", text = "Alts" },
        { key = "timers", text = "Timers" },
        { key = "gearing", text = "Gearing" },
        { key = "profit", text = "Goblin" },
        { key = "trainers", text = "Trainers" },
        { key = "data", text = "Data" },
    }
    self.tabs = {}
    self.tabIndexMap = {}

    -- Suite-themed tab buttons. Replaces Blizzard's PanelTabButtonTemplate
    -- so the tab strip matches the rest of the UIToolkit chrome (theme paint,
    -- accent colors, consistent height).
    local TAB_HEIGHT = 26
    local TAB_PAD_X = 14
    local tabX = 6
    for index, tabData in ipairs(tabs) do
        local buttonName = frame:GetName() .. "Tab" .. index
        -- FableNeon tab: no box — muted text with a cyan->purple gradient
        -- underline on the active tab (matches the component kit's TabStrip).
        local btn = CreateFrame("Button", buttonName, tabBar)
        btn:SetID(index)
        btn:SetHeight(TAB_HEIGHT)
        btn:SetPoint("TOPLEFT", tabX, -2)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER")
        label:SetText(tabData.text)
        btn.Text = label

        local labelWidth = label:GetStringWidth() + TAB_PAD_X * 2
        btn:SetWidth(math.max(labelWidth, 56))

        local underline = btn:CreateTexture(nil, "OVERLAY")
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT", 8, 0)
        underline:SetPoint("BOTTOMRIGHT", -8, 0)
        underline:SetColorTexture(1, 1, 1, 1)
        if underline.SetGradient and CreateColor then
            underline:SetGradient("HORIZONTAL",
                CreateColor(0.227, 0.914, 1.0, 1),
                CreateColor(0.706, 0.361, 1.0, 1))
        end
        underline:Hide()
        btn.Underline = underline

        btn:SetScript("OnEnter", function()
            if UI.currentTab ~= tabData.key then
                label:SetTextColor(0.925, 0.922, 0.980)
            end
        end)
        btn:SetScript("OnLeave", function()
            UI:UpdateTabSelection()
        end)
        btn:SetScript("OnClick", function()
            UI:OpenToTab(tabData.key)
        end)
        self.tabs[tabData.key] = btn
        self.tabIndexMap[tabData.key] = index
        tabX = tabX + btn:GetWidth() + 4
    end
    self.tabCount = #tabs

    -- Paint helper: active tab gets bright text + the gradient underline,
    -- inactive tabs sit muted with no box chrome.
    function self:UpdateTabSelection()
        local active = self.currentTab
        for key, btn in pairs(self.tabs or {}) do
            if btn.Text then
                if key == active then
                    btn.Text:SetTextColor(0.925, 0.922, 0.980)
                else
                    btn.Text:SetTextColor(0.612, 0.600, 0.761)
                end
            end
            if btn.Underline then
                btn.Underline:SetShown(key == active)
            end
        end
    end

    local listHost = CreateFrame("Frame", nil, content, "BackdropTemplate")
    listHost:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
    listHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    self.listHost = listHost

    local header = CreateFrame("Frame", nil, listHost)
    header:SetPoint("TOPLEFT", 12, -12)
    header:SetPoint("TOPRIGHT", -30, -12)
    header:SetHeight(24)
    self.header = header

    local emptyState = listHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyState:SetPoint("CENTER", listHost, "CENTER", 0, -8)
    emptyState:SetText("Nothing to show here yet.")
    emptyState:Hide()
    self.emptyState = emptyState

    local scrollFrame = CreateFrame("ScrollFrame", nil, listHost, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    self.scrollChild = scrollChild
    scrollFrame:SetScrollChild(scrollChild)

    -- Virtualization scroll hook: when the viewport moves, repaint just the
    -- newly-visible rows from the cached active list. No-op when the active
    -- tab doesn't populate _activeListCache (e.g. Queue, Materials, Knowledge).
    -- Throttled with C_Timer.NewTicker via a debounce flag so a fast scroll
    -- coalesces into one repaint per frame instead of per-pixel.
    scrollFrame:HookScript("OnVerticalScroll", function()
        if not UI._activeListCache then return end
        if UI._scrollPending then return end
        UI._scrollPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                UI._scrollPending = false
                if UI._activeListCache then
                    UI:_VirtualizePaint()
                end
            end)
        else
            UI._scrollPending = false
            UI:_VirtualizePaint()
        end
    end)

    self.rows = {}
    self.currentTab = self.currentTab or "recipes"

    M:RegisterCallback(self, "DataChanged", function() UI:RefreshActiveTab() end)
    M:RegisterCallback(self, "QueueChanged", function() UI:RefreshActiveTab() end)
    M:RegisterCallback(self, "AltDataChanged", function() UI:RefreshActiveTab() end)
    M:RegisterCallback(self, "HistoryChanged", function() UI:RefreshActiveTab() end)

    self:ApplyToolkitAppearance()
    self:UpdateFilterControlState()
    self:UpdateToolbarForTab()
    self:SetWindowStatus("Ready")
end

-- ── FableNeon row furniture ──────────────────────────────────────────────────
-- Spectrum color keys per profession/expansion: the rainbow carries meaning
-- (category), not decoration. Resolved through UIToolkit Effects:Spectrum.
local PROF_SPECTRUM = {
    Tailoring = "purple", Enchanting = "cyan", Jewelcrafting = "pink",
    Engineering = "amber", Blacksmithing = "amber", Leatherworking = "green",
    Inscription = "azure", Alchemy = "green", Cooking = "amber",
    Herbalism = "green", Mining = "amber", Skinning = "pink",
}

local function SpectrumColor(key)
    local toolkit = rawget(_G, "FabledUI_UIToolkit")
    if toolkit and toolkit.Effects and toolkit.Effects.Spectrum then
        return toolkit.Effects:Spectrum(key)
    end
    return { 0.227, 0.914, 1.0, 1.0 }
end

local function ExpansionSpectrumKey(expansion)
    if expansion == "Midnight" then return "purple" end
    if expansion == "The War Within" or expansion == "TWW" then return "azure" end
    return "amber"
end

-- Pooled tag pills per row (rows are recycled by the virtualizer, so pills
-- must be acquire/paint/hide, never created per paint).
local function AcquireTagPill(row, index)
    row.tagPills = row.tagPills or {}
    local pill = row.tagPills[index]
    if not pill then
        pill = CreateFrame("Frame", nil, row)
        pill:SetHeight(16)
        pill.text = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pill.text:SetPoint("CENTER", 0, 0)
        row.tagPills[index] = pill
    end
    pill:Show()
    return pill
end

local function PaintTagPill(pill, text, colorKey)
    local col = SpectrumColor(colorKey)
    pill.text:SetText(text)
    pill.text:SetTextColor(col[1], col[2], col[3], 1)
    pill:SetWidth((pill.text:GetStringWidth() or 20) + 12)
    local toolkit = rawget(_G, "FabledUI_UIToolkit")
    if toolkit and toolkit.Effects then
        toolkit.Effects:RoundedFill(pill, { col[1], col[2], col[3], 0.10 })
        toolkit.Effects:RoundedStroke(pill, { col[1], col[2], col[3], 0.35 })
    end
end

local function HideTagPills(row)
    for _, pill in ipairs(row.tagPills or {}) do
        pill:Hide()
    end
end

function UI:GetRow(index)
    if self.rows[index] then
        return self.rows[index]
    end

    local row = CreateFrame("Button", nil, self.scrollChild, "BackdropTemplate")
    -- Row width tracks the scroll viewport so resize keeps columns + buttons
    -- inside the visible area instead of spilling past the scrollbar.
    local viewportWidth = (self.scrollFrame and self.scrollFrame:GetWidth()) or 1098
    row:SetSize(math.max(viewportWidth - 4, 800), ROW_HEIGHT)
    row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    row:SetBackdropColor(1, 1, 1, 0.03)

    row.actionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.actionButton:SetSize(78, 20)
    row.actionButton:SetPoint("RIGHT", -4, 0)
    row.actionButton:Hide()

    row.secondaryButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.secondaryButton:SetSize(24, 20)
    row.secondaryButton:SetPoint("RIGHT", row.actionButton, "LEFT", -4, 0)
    row.secondaryButton:Hide()

    row.tertiaryButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.tertiaryButton:SetSize(24, 20)
    row.tertiaryButton:SetPoint("RIGHT", row.secondaryButton, "LEFT", -4, 0)
    row.tertiaryButton:Hide()

    -- Quaternary slot: used by features like the Gear Optimizer / Reagent
    -- Picker that need a fourth per-row action button without disturbing
    -- the established 3-button right-edge layout.
    row.quaternaryButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.quaternaryButton:SetSize(24, 20)
    row.quaternaryButton:SetPoint("RIGHT", row.tertiaryButton, "LEFT", -4, 0)
    row.quaternaryButton:Hide()

    StyleActionButton(row.actionButton)
    StyleActionButton(row.secondaryButton)
    StyleActionButton(row.tertiaryButton)
    StyleActionButton(row.quaternaryButton)

    -- FableNeon row chrome. Native HIGHLIGHT texture = automatic hover wash;
    -- the left accent edge shows via HookScript so it coexists with the
    -- tooltip's OnEnter/OnLeave main handlers set by AttachTooltip.
    local hoverWash = row:CreateTexture(nil, "HIGHLIGHT")
    hoverWash:SetAllPoints()
    hoverWash:SetColorTexture(0.227, 0.914, 1.0, 0.05)

    row.edge = row:CreateTexture(nil, "OVERLAY")
    row.edge:SetWidth(2)
    row.edge:SetPoint("TOPLEFT", 0, -3)
    row.edge:SetPoint("BOTTOMLEFT", 0, 3)
    row.edge:SetColorTexture(1, 1, 1, 1)
    if row.edge.SetGradient and CreateColor then
        row.edge:SetGradient("VERTICAL",
            CreateColor(0.706, 0.361, 1.0, 1),
            CreateColor(0.227, 0.914, 1.0, 1))
    else
        row.edge:SetColorTexture(0.227, 0.914, 1.0, 1)
    end
    row.edge:Hide()
    row:HookScript("OnEnter", function() row.edge:Show() end)
    row:HookScript("OnLeave", function() row.edge:Hide() end)

    -- Quality gem: small rotated square tinted by profession spectrum color.
    row.gem = row:CreateTexture(nil, "ARTWORK")
    row.gem:SetSize(8, 8)
    row.gem:SetTexture("Interface\\Buttons\\WHITE8X8")
    if row.gem.SetRotation then
        row.gem:SetRotation(math.pi / 4)
    end
    row.gem:SetPoint("LEFT", 10, 0)
    row.gem:Hide()

    -- Collection progress bar (replaces the "1027/1334 (77%)" text cell).
    row.progressBar = CreateFrame("StatusBar", nil, row)
    row.progressBar:SetSize(56, 5)
    row.progressBar:SetMinMaxValues(0, 100)
    do
        local toolkit = rawget(_G, "FabledUI_UIToolkit")
        if toolkit and toolkit.Effects and toolkit.Effects.StyleProgressBar then
            toolkit.Effects:StyleProgressBar(row.progressBar)
        end
    end
    row.progressBar:Hide()
    row.progressPct = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.progressPct:SetTextColor(0.612, 0.600, 0.761, 1)
    row.progressPct:Hide()

    self.rows[index] = row
    return row
end

function UI:ResetRow(row)
    row:Hide()
    row.isSection = false
    row:SetBackdropColor(1, 1, 1, 0.03)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:SetScript("OnMouseUp", nil)

    row.actionButton:Hide()
    row.actionButton:SetScript("OnClick", nil)
    row.secondaryButton:Hide()
    row.secondaryButton:SetScript("OnClick", nil)
    row.tertiaryButton:Hide()
    row.tertiaryButton:SetScript("OnClick", nil)
    if row.quaternaryButton then
        row.quaternaryButton:Hide()
        row.quaternaryButton:SetScript("OnClick", nil)
        row.quaternaryButton:SetScript("OnEnter", nil)
        row.quaternaryButton:SetScript("OnLeave", nil)
    end

    -- Restore default button GEOMETRY as well as placement. Render paths call
    -- SetSize on these (Trainers 110px, the old Recipes "Optimize" 58px) and
    -- rows are pooled across tabs, so without this a row recycled from another
    -- tab kept the old width and every row's buttons started at a different x.
    -- That is what made the action column read as ragged rather than aligned.
    row.actionButton:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    row.secondaryButton:SetSize(MINI_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    row.tertiaryButton:SetSize(MINI_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    if row.quaternaryButton then
        row.quaternaryButton:SetSize(MINI_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    end

    -- CR-005: Restore the default right-anchored button layout each render.
    -- The Queue tab re-anchors these buttons into a dedicated Actions column,
    -- so we must restore the standard layout here for tabs that rely on the
    -- original RIGHT-edge placement (Recipes, Materials, Knowledge, etc.).
    row.actionButton:ClearAllPoints()
    row.actionButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.secondaryButton:ClearAllPoints()
    row.secondaryButton:SetPoint("RIGHT", row.actionButton, "LEFT", -4, 0)
    row.tertiaryButton:ClearAllPoints()
    row.tertiaryButton:SetPoint("RIGHT", row.secondaryButton, "LEFT", -4, 0)
    if row.quaternaryButton then
        row.quaternaryButton:ClearAllPoints()
        row.quaternaryButton:SetPoint("RIGHT", row.tertiaryButton, "LEFT", -4, 0)
    end

    if row.columns then
        for _, fs in ipairs(row.columns) do
            fs:SetText("")
            fs:Hide()
        end
    end

    -- CR-006: hide any pooled material-icon frames so they don't leak
    -- between Queue tab renders or onto other tabs (Recipes, Materials, etc.).
    if row.matIcons then
        ReleaseMaterialIcons(row)
    end

    -- FableNeon row furniture: recycled rows must not leak the Recipes tab's
    -- gem/progress/pills onto other tabs.
    if row.gem then row.gem:Hide() end
    if row.edge then row.edge:Hide() end
    if row.progressBar then row.progressBar:Hide() end
    if row.progressPct then row.progressPct:Hide() end
    HideTagPills(row)
end

function UI:ClearRows()
    self.emptyState:Hide()
    -- Sync pooled-row widths to the current viewport on every render so
    -- resizing the window doesn't leave rows wider/narrower than the
    -- scrollable area.
    local viewportWidth = (self.scrollFrame and self.scrollFrame:GetWidth()) or 1098
    local rowWidth = math.max(viewportWidth - 4, 800)
    for _, row in pairs(self.rows) do
        row:SetWidth(rowWidth)
        self:ResetRow(row)
    end
end

-- Width a tab may spend on columns before it starts running under the action
-- buttons. Callers scale their column set against this instead of hard-coding
-- totals that only happened to fit at the default window size.
function UI:GetContentWidth()
    local viewportWidth = (self.scrollFrame and self.scrollFrame:GetWidth()) or 1098
    return math.max(viewportWidth - ACTIONS_GUTTER - 16, 600)
end

-- Distribute a column set across the available content width, holding the
-- listed columns at their natural size and giving the remainder to `flexIndex`.
-- Returns the resolved widths, so the same call can feed SetHeaders and
-- BuildColumns and the two can never drift apart.
function UI:ResolveColumns(widths, flexIndex, firstOffset)
    local resolved = {}
    local fixedTotal = 0
    for i, w in ipairs(widths) do
        resolved[i] = w
        if i ~= flexIndex then
            fixedTotal = fixedTotal + w
        end
    end
    if flexIndex and resolved[flexIndex] then
        local gaps = (#widths - 1) * 12 + (firstOffset or 8)
        local slack = self:GetContentWidth() - fixedTotal - gaps
        resolved[flexIndex] = math.max(80, slack)
    end
    return resolved
end

function UI:BuildColumns(row, widths, firstOffset)
    row.columns = row.columns or {}
    local previous
    local left = firstOffset or 8
    for i, width in ipairs(widths) do
        if not row.columns[i] then
            row.columns[i] = CreateLabel(row, width)
            if TK then
                TK:ApplyBodyText(row.columns[i])
            end
        end
        local column = row.columns[i]
        column:ClearAllPoints()
        column:SetWidth(width)
        if i == 1 then
            column:SetPoint("TOPLEFT", row, "TOPLEFT", left, -5)
        else
            column:SetPoint("TOPLEFT", previous, "TOPRIGHT", 12, 0)
        end
        column:Show()
        previous = column
    end
    for i = #widths + 1, #row.columns do
        row.columns[i]:Hide()
    end
end

-- Right-click menu for a list row.
--
-- `actions` is a flat list of { text, onClick, hidden?, divider? }. Hidden
-- entries let callers say "this action does not apply to this row" inline
-- instead of assembling a different list per case; any divider left stranded at
-- an edge, or doubled up, by those omissions is dropped here rather than in
-- every caller.
-- Split out from ShowRowMenu so the filtering rules are testable on their own:
-- once MenuUtil takes over, what it was handed is no longer observable.
function UI:ResolveMenuActions(actions)
    local visible = {}
    for _, action in ipairs(actions or {}) do
        if not action.hidden then
            local isDivider = action.divider == true
            local previous = visible[#visible]
            -- Skip a divider that would lead, or follow another divider.
            if not (isDivider and (previous == nil or previous.divider)) then
                visible[#visible + 1] = action
            end
        end
    end
    while #visible > 0 and visible[#visible].divider do
        visible[#visible] = nil
    end
    return visible
end

function UI:ShowRowMenu(owner, title, actions)
    local visible = self:ResolveMenuActions(actions)
    if #visible == 0 then return end

    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, rootDescription)
            if title and title ~= "" then
                rootDescription:CreateTitle(title)
            end
            for _, action in ipairs(visible) do
                if action.divider then
                    rootDescription:CreateDivider()
                else
                    rootDescription:CreateButton(action.text, action.onClick)
                end
            end
        end)
        if ok then return end
    end

    -- No MenuUtil, or it threw: run the first real action so a right-click still
    -- does something instead of silently nothing.
    for _, action in ipairs(visible) do
        if not action.divider and type(action.onClick) == "function" then
            action.onClick()
            return
        end
    end
end

function UI:SetActionsHeader(text)
    if not self.header.actionsColumn then
        local fs = self.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("RIGHT")
        fs:SetWidth(ACTIONS_GUTTER)
        if TK then TK:ApplyTitleText(fs) end
        self.header.actionsColumn = fs
    end
    local fs = self.header.actionsColumn
    fs:ClearAllPoints()
    -- Anchored to the same right edge the buttons use, so the label sits over
    -- them at any window width.
    fs:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -10, -4)
    fs:SetText(text or "")
    fs:SetShown((text or "") ~= "")
end

-- `actionsLabel` (optional) puts a right-aligned header over the action-button
-- gutter, so the buttons read as a real column instead of floating furniture.
function UI:SetHeaders(headers, widths, actionsLabel)
    self:SetActionsHeader(actionsLabel)
    self.header.columns = self.header.columns or {}
    local previous
    for i, text in ipairs(headers) do
        if not self.header.columns[i] then
            self.header.columns[i] = CreateLabel(self.header, widths[i], "GameFontNormalSmall")
            if TK then
                TK:ApplyTitleText(self.header.columns[i])
            end
        end
        local column = self.header.columns[i]
        column:ClearAllPoints()
        column:SetText(text)
        column:SetWidth(widths[i])
        if i == 1 then
            column:SetPoint("TOPLEFT", self.header, "TOPLEFT", 6, -4)
        else
            column:SetPoint("TOPLEFT", previous, "TOPRIGHT", 12, 0)
        end
        column:Show()
        previous = column
    end
    for i = #headers + 1, #(self.header.columns or {}) do
        self.header.columns[i]:Hide()
    end
end

-- AttachTooltip accepts either a static lines array OR a builder function
-- that returns the lines on demand. The builder form lets renderers defer
-- expensive line construction (Profit calculation, knownBy formatting,
-- material summaries) to OnEnter so we don't pay that cost for thousands of
-- never-hovered rows during first paint.
function UI:AttachTooltip(row, title, linesOrBuilder)
    if not row then
        return
    end
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:AddLine(title, 1, 1, 1)
        end
        local lines = linesOrBuilder
        if type(lines) == "function" then
            local ok, result = pcall(lines)
            lines = ok and result or nil
        end
        for _, line in ipairs(lines or {}) do
            GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function UI:PrepareSectionRow(row, y, title, subtitle)
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()
    row.isSection = true
    row:SetBackdropColor(0.38, 0.32, 0.12, 0.18)
    self:BuildColumns(row, { 250, 760 }, 8)
    row.columns[1]:SetText(title or "")
    row.columns[2]:SetText(subtitle or "")
end

function UI:FinishRender(rowCount, totalHeight)
    self.scrollChild:SetHeight(math.max(1, totalHeight))
    self.emptyState:SetShown(rowCount == 0)
    if rowCount == 0 then
        self.emptyState:SetText("No matching rows for the current filters.")
    end
end

-- Render a "module disabled" placeholder for tabs whose owning module is
-- toggled off in the Modules section of Settings. Each RenderXxx function
-- below this point checks IsModuleEnabled at its entry and short-circuits
-- to this helper rather than nil-dereffing M.<Module>:Method().
function UI:RenderModuleDisabled(label, moduleKey)
    self:SetHeaders({ label or "Tab" }, { 800 })
    self:SetWindowStatus(string.format(
        "%s is a companion module — enable it under Crafty Settings → Modules.",
        label or moduleKey or "This tab"))
    self.scrollChild:SetHeight(1)
    self.emptyState:SetShown(true)
    -- On-theme, non-alarming empty state: cyan heading + purple call-to-action,
    -- framed as "enable the companion module" rather than a red error.
    self.emptyState:SetText(string.format(
        "|cff3ae9ff%s|r\n\nThis feature ships as a companion module.\nEnable it under |cffb45cffCrafty Settings → Modules|r to light up this tab.",
        label or moduleKey or "This tab"))
end

-- Returns true when the named module is enabled (or when the registry is
-- absent — fallback to allow rendering so a corrupt/missing registry can't
-- silently blank the whole UI).
local function isModuleEnabled(key)
    if not M.Modules or not M.Modules.IsEnabled then return true end
    return M.Modules:IsEnabled(key)
end
UI._isModuleEnabled = isModuleEnabled

function UI:RenderRecipes()
    local stats = M.Recipes:GetSummaryStats()
    -- One button on the row (Queue); +5, 3D Preview and Optimize moved to the
    -- row's right-click menu. Four buttons per row across hundreds of rows read
    -- as noise, and the widest of them ("Optimize") set the right edge for every
    -- other tab through the shared row pool.
    --
    -- Tags flexes into whatever is left rather than being pinned at 200px, so
    -- the set fills the window at any width instead of only at the default one.
    local widths = self:ResolveColumns({ 280, 150, 100, 200, 90 }, 4, 24)
    self:SetHeaders({ "Recipe", "Knowledge", "Progress", "Tags", "Craftable" }, widths, "Actions")

    -- Status line surfaces the active lens (known/all + which expansion +
    -- whether search is widening) so users who see fewer recipes than
    -- expected understand why and how to widen.
    local query = M.filters.text or ""
    local activeExpansion = M.filters.expansion or "ALL"
    local knownOnly = M.filters.knownOnly == true
    local lensHint
    if query ~= "" then
        lensHint = "Search · all recipes, all expansions"
    elseif knownOnly and activeExpansion ~= "ALL" then
        lensHint = "Known · " .. activeExpansion
    elseif knownOnly then
        lensHint = "Known recipes (toggle Known only off to see catalog)"
    elseif activeExpansion ~= "ALL" then
        lensHint = activeExpansion .. " · all recipes (pick All Expansions to widen)"
    else
        lensHint = "All recipes, all expansions"
    end
    local statusLine = string.format("%s  |  Filtered %d | Known %d | Alt only %d | Unknown %d | Ready %d",
        lensHint, stats.filtered, stats.knownCurrent, stats.knownAltOnly, stats.unknown, stats.craftable)
    -- Self-diagnosing empty state: when the view is 0, show how much data the
    -- corpus actually holds so "no data" and "filters hid everything" are
    -- distinguishable at a glance (and from a single screenshot).
    if (stats.filtered or 0) == 0 then
        local live, static = 0, 0
        for _, r in pairs(M.Recipes:GetAll()) do
            if r.sourceType == "LIVE" then live = live + 1 else static = static + 1 end
        end
        statusLine = statusLine .. string.format("  |  Cache holds %d live + %d static — if these are >0, the filters above are hiding them", live, static)
    end
    self:SetWindowStatus(statusLine)

    local rows = M.Recipes:GetFilteredList()
    -- P0: Pre-memoize collection progress per profession. The previous
    -- implementation called GetCollectionProgress (an O(N) walk over the
    -- full recipe corpus) once per rendered row — that's O(N²) and was
    -- the dominant cost in the first-open profile (~14.7s for ~1300
    -- recipes). Computing once per profession is O(P) lookups, where
    -- P ≤ 11.
    local _progressByProf = {}
    local function getProgress(prof)
        local hit = _progressByProf[prof]
        if hit then return hit[1], hit[2], hit[3] end
        local c, t, p = M.Recipes:GetCollectionProgress(prof)
        _progressByProf[prof] = { c, t, p }
        return c, t, p
    end

    -- P0: Virtualization — extract per-row paint into a closure invoked only
    -- for rows currently in the scroll viewport (plus a small buffer). The
    -- previous loop ran ~50 frame ops per row × 1334 rows = ~67k frame ops
    -- per render. With virtualization we only paint ~30-40 visible rows on
    -- first paint; rows that scroll into view are painted by the scroll
    -- handler. Stride is ROW_HEIGHT + 2 for the row gap.
    local stride = ROW_HEIGHT + 2
    local function paintRow(index, rowData, y)
        local row = self:GetRow(index)
        local recipe = rowData.recipe
        local knowledgeText, knownBy = FormatKnowledgeText(rowData.recipeID)
        local collected, total, percent = getProgress(recipe.profession)
        local sourceTag = recipe.sourceType == "LIVE" and "Live" or "Decor"
        local tags = string.format("%s · %s · %s · %s", recipe.profession, recipe.expansion, recipe.style or "Style", sourceTag)
        local craftableText = rowData.craftable and string.format("%d ready", rowData.craftableCount) or "Not ready"
        local queuedQuantity = M.Queue:GetRecipeQueuedQuantity(rowData.recipeID)

        -- CR-002 #2/#3: badges + alt-awareness stars inline with the recipe name.
        local knowsCurrent = (rowData.knowledgeState == "CURRENT")
        local knowsAltOnly = (rowData.knowledgeState == "ALT")
        local decorCollected = rowData.decorCollected == true
        -- Clean name cell — no glyph badges (●/★ tofu-box in WoW fonts).
        -- State lives in the profession gem, the Knowledge column color, and
        -- a gold name tint when the decor output is already collected.
        local nameDisplay = recipe.name or "?"
        if decorCollected then
            nameDisplay = "|cffffd100" .. nameDisplay .. "|r"
        end

        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        -- firstOffset 24 leaves room for the profession gem at LEFT 10.
        -- Same resolved widths the header used, so the two cannot drift.
        self:BuildColumns(row, widths, 24)

        row.columns[1]:SetText(nameDisplay)
        row.columns[2]:SetText(knowledgeText)

        -- Profession gem (rotated square, spectrum-tinted by profession).
        local profKey = PROF_SPECTRUM[recipe.profession] or "cyan"
        local gemColor = SpectrumColor(profKey)
        row.gem:SetVertexColor(gemColor[1], gemColor[2], gemColor[3], 1)
        row.gem:Show()

        -- Collection progress: glowing cyan->purple bar + compact percent.
        -- Full "collected/total" detail lives in the row tooltip.
        row.columns[3]:SetText("")
        row.progressBar:ClearAllPoints()
        row.progressBar:SetPoint("TOPLEFT", row.columns[3], "TOPLEFT", 0, -3)
        row.progressBar:SetValue(percent or 0)
        row.progressBar:Show()
        row.progressPct:ClearAllPoints()
        row.progressPct:SetPoint("LEFT", row.progressBar, "RIGHT", 6, 0)
        row.progressPct:SetText(string.format("%d%%", percent or 0))
        row.progressPct:Show()

        -- Tags as spectrum pills: profession · expansion · queued badge.
        row.columns[4]:SetText("")
        local pillIndex, pillX = 0, 0
        local function addPill(text, colorKey)
            pillIndex = pillIndex + 1
            local pill = AcquireTagPill(row, pillIndex)
            pill:ClearAllPoints()
            pill:SetPoint("LEFT", row.columns[4], "LEFT", pillX, 0)
            PaintTagPill(pill, text, colorKey)
            pillX = pillX + pill:GetWidth() + 6
        end
        addPill(recipe.profession or "?", profKey)
        addPill(recipe.expansion or "?", ExpansionSpectrumKey(recipe.expansion))
        if queuedQuantity and queuedQuantity > 0 then
            addPill(string.format("Q ×%d", queuedQuantity), "green")
        end
        for i = pillIndex + 1, #(row.tagPills or {}) do
            row.tagPills[i]:Hide()
        end

        -- Craftable status chip: lit green when ready, dim when not.
        if rowData.craftable then
            row.columns[5]:SetText(string.format("|cff5cf0a0%d ready|r", rowData.craftableCount or 0))
        else
            row.columns[5]:SetText("|cff615e86Not ready|r")
        end

        -- The row carries its single most-used action. Everything else lives on
        -- the right-click menu, built fresh per click so a module that loaded
        -- (or unloaded) since the row was painted is reflected correctly.
        row.actionButton:Show()
        row.actionButton:SetText("Queue")
        row.actionButton:SetScript("OnClick", function()
            M.Queue:Add(recipe.recipeID, 1)
            UI:RefreshActiveTab()
        end)

        local menuRecipeID = rowData.recipeID
        local menuItemID = recipe.itemID
        local menuName = recipe.name
        local menuProfession = recipe.profession
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnMouseUp", function(self, button)
            if button ~= "RightButton" then return end
            UI:ShowRowMenu(self, menuName, {
                { text = "Queue ×1",  onClick = function() M.Queue:Add(menuRecipeID, 1);  UI:RefreshActiveTab() end },
                { text = "Queue ×5",  onClick = function() M.Queue:Add(menuRecipeID, 5);  UI:RefreshActiveTab() end },
                { text = "Queue ×20", onClick = function() M.Queue:Add(menuRecipeID, 20); UI:RefreshActiveTab() end },
                { divider = true },
                {
                    text = "3D Preview",
                    hidden = not (menuItemID and menuItemID > 0),
                    onClick = function()
                        local Toolkit = rawget(_G, "FabledUI_UIToolkit")
                        if Toolkit and Toolkit.Preview then
                            Toolkit.Preview:Show(menuItemID, self)
                        end
                    end,
                },
                {
                    text = "Optimize Gear",
                    -- Re-checked at click time, not paint time: GearOptimizer is
                    -- LoadOnDemand and can be enabled or disabled in between.
                    hidden = not menuProfession,
                    onClick = function()
                        if M.GearOptimizer then
                            M.GearOptimizer:ShowRecommendationPopup(menuRecipeID)
                        else
                            M:Print("Gear Optimizer module is not enabled.")
                        end
                    end,
                },
            })
        end)

        -- P0: Defer tooltip line construction to OnEnter via a builder
        -- closure. The previous implementation eagerly built ~13 string
        -- lines per row, including a double Profit:CalculateRecipe call
        -- and a BuildMaterialSummary walk, for every recipe — even the
        -- thousands the user never hovers. Captures everything the lines
        -- need by closure so the build only runs when the tooltip shows.
        local capturedRecipeID = rowData.recipeID
        local capturedKnownBy = knownBy
        local capturedQueued = queuedQuantity
        local capturedSourceTag = sourceTag
        local capturedKnowsAltOnly = knowsAltOnly
        local capturedDecorCollected = decorCollected
        self:AttachTooltip(row, recipe.name, function()
            local knownDisplay = M.Recipes:GetKnownByDisplay(capturedRecipeID)
            local altNames = {}
            local currentCharacter = M.GetCurrentCharacterKey and M:GetCurrentCharacterKey() or nil
            for _, characterKey in ipairs(capturedKnownBy or {}) do
                if characterKey ~= currentCharacter then
                    altNames[#altNames + 1] = M.GetShortCharacterName and M:GetShortCharacterName(characterKey) or tostring(characterKey)
                end
            end

            local lines = {
                string.format("Item ID: %s   Recipe ID: %s", tostring(recipe.itemID or "-"), tostring(recipe.recipeID or "-")),
                string.format("Source: %s", capturedSourceTag),
                string.format("Collected: %s", M.Recipes:IsCollected(recipe) and "Yes" or "No"),
                string.format("Decor collected: %s", capturedDecorCollected and "|cffffd100Yes|r" or "No"),
                string.format("Known by: %s", #capturedKnownBy > 0 and knownDisplay or "Nobody yet"),
            }
            if capturedKnowsAltOnly and #altNames > 0 then
                lines[#lines + 1] = "Known by alts: " .. table.concat(altNames, ", ")
            end
            lines[#lines + 1] = "Colors: |cff5cf0a0green|r = known on this character · |cffffd100gold name|r = decor collected · |cffb8b8b8grey|r = alt-only"
            lines[#lines + 1] = string.format("Queued total: %d", capturedQueued)
            lines[#lines + 1] = (recipe.outputQuantity and recipe.outputQuantity > 1) and ("Output quantity: " .. tostring(recipe.outputQuantity)) or "Output quantity: 1"

            local profitInfo = M.Profit and M.Profit:CalculateRecipe(capturedRecipeID) or nil
            lines[#lines + 1] = profitInfo
                and ("Projected profit: " .. M.Util:MoneyToString(profitInfo.profit or 0))
                or "Projected profit: -"

            lines[#lines + 1] = (M.settings and M.settings.useCraftSimProfitModel) and "Profit engine: CraftSim-like" or "Profit engine: Crafty"
            lines[#lines + 1] = "Materials: " .. BuildMaterialSummary(recipe, 1)
            return lines
        end)
    end

    -- Stash the active list so scroll handlers can re-virtualize without
    -- re-running GetFilteredList (which itself walks 1300+ recipes). Cleared
    -- by tab-switch / filter-change so we don't paint stale data.
    self._activeListCache = {
        rows = rows,
        paintRow = paintRow,
        stride = stride,
        totalHeight = #rows * stride,
    }
    self:_VirtualizePaint()
end

-- Paint only the rows that are visible in the scrollFrame viewport (plus a
-- small over-render buffer above and below to make scrolling feel smooth).
-- Hides any pooled rows that are outside the visible window. Cheap to call
-- from OnVerticalScroll because it skips GetFilteredList entirely.
function UI:_VirtualizePaint()
    local cache = self._activeListCache
    if not cache then return end
    local rows = cache.rows
    local paintRow = cache.paintRow
    local stride = cache.stride or (ROW_HEIGHT + 2)
    local total = #rows

    self.scrollChild:SetHeight(math.max(1, cache.totalHeight or (total * stride)))
    self.emptyState:SetShown(total == 0)
    if total == 0 then
        self.emptyState:SetText("No matching rows for the current filters.")
        for _, row in pairs(self.rows) do row:Hide() end
        return
    end

    local first, last = self:_GetVisibleRowRange(stride, total)

    -- Hide any pooled rows that are now outside the visible window. We walk
    -- self.rows (sparse pool) instead of iterating 1..total so this stays
    -- cheap even when the list is huge.
    for index, row in pairs(self.rows) do
        if index < first or index > last or index > total then
            row:Hide()
        end
    end

    -- Paint only the visible window.
    for index = first, math.min(last, total) do
        local rowData = rows[index]
        local y = (index - 1) * stride
        paintRow(index, rowData, y)
    end
end

-- Compute [first, last] row indices visible in the scrollFrame viewport
-- given the row stride. Adds a 5-row buffer above and 10-row buffer below
-- so a small scroll movement doesn't expose unpainted rows.
function UI:_GetVisibleRowRange(stride, total)
    if not self.scrollFrame or stride <= 0 then return 1, total end
    local scrollOffset = self.scrollFrame:GetVerticalScroll() or 0
    local viewportHeight = self.scrollFrame:GetHeight() or 600
    local first = math.max(1, math.floor(scrollOffset / stride) - 5)
    local last = math.ceil((scrollOffset + viewportHeight) / stride) + 10
    if last > total then last = total end
    return first, last
end

-- CR-006: Ensures the "Icons" toggle exists in the Queue tab header strip.
-- Lazy-created on first Queue render so it does not clutter other tabs.
-- Anchored to the tabBar's right edge so it lives inline with the Queue tab
-- and does not overlap the data column headers below it.
function UI:EnsureQueueMaterialsIconsToggle()
    if self.queueIconsToggle then
        return self.queueIconsToggle
    end
    if not self.tabBar then
        return nil
    end
    local toggle = CreateFrame("CheckButton", nil, self.tabBar, "UICheckButtonTemplate")
    toggle:SetSize(20, 20)
    toggle:SetPoint("RIGHT", self.tabBar, "RIGHT", -64, 0)
    toggle:SetHitRectInsets(0, -56, 0, 0)
    EnsureCheckboxLabel(toggle, "Icons")
    toggle:SetChecked((M.filters and M.filters.materialsAsIcons) == true)
    toggle:SetScript("OnClick", function(btn)
        if not M.filters then return end
        M.filters.materialsAsIcons = btn:GetChecked() and true or false
        if M.SaveSettings then M:SaveSettings() end
        UI:RefreshActiveTab()
    end)
    toggle:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("Materials Display")
        GameTooltip:AddLine("Toggle the Queue tab Materials column between text (Name xN, ...) and a compact icon row with stack-count overlays.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("Hover an icon for the full item name and required count.", 0.65, 0.85, 0.95, true)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.queueIconsToggle = toggle
    return toggle
end

function UI:RenderQueue()
    -- CR-005: Added a dedicated rightmost "Actions" column so the per-row
    -- -/+/Remove buttons no longer overlap with the Status column header.
    local QUEUE_COLUMN_WIDTHS = { 260, 130, 50, 300, 110, 150 }
    self:SetHeaders({ "Recipe", "Crafter", "Qty", "Materials", "Status", "Actions" }, QUEUE_COLUMN_WIDTHS)
    local summary = M.Queue:GetSummary()
    self:SetWindowStatus(string.format("%d queued entries | %d total crafts | %d crafter buckets | %d recraft/order-aware | %d CraftSim-like", summary.entries or 0, summary.totalQuantity or 0, summary.characters or 0, (summary.recrafts or 0) + (summary.orders or 0), summary.craftSimLike or 0))

    -- CR-006: surface the per-tab "Icons" toggle in the Queue header.
    local iconsToggle = self:EnsureQueueMaterialsIconsToggle()
    if iconsToggle then
        iconsToggle:Show()
        iconsToggle:SetChecked((M.filters and M.filters.materialsAsIcons) == true)
    end
    local iconsMode = (M.filters and M.filters.materialsAsIcons) == true

    local rowIndex = 1
    local y = 0

    local function renderEntry(entry, indent)
        local row = self:GetRow(rowIndex)
        local recipe = M.Recipes:Get(entry.recipeID)
        local craftable, craftableCount = M.Recipes:IsCraftable(recipe)
        local statusText
        if craftable and (craftableCount or 0) >= (entry.quantity or 0) then
            statusText = "|cff5cf0a0Ready|r"
        elseif craftable then
            statusText = string.format("|cffffd05aShort %d|r", math.max(0, (entry.quantity or 0) - (craftableCount or 0)))
        else
            statusText = "|cffd95f5fMissing mats|r"
        end

        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, QUEUE_COLUMN_WIDTHS, indent or 8)
        row.columns[1]:SetText(recipe and recipe.name or ("Recipe " .. tostring(entry.recipeID)))
        row.columns[2]:SetText(M:GetShortCharacterName(entry.character))
        row.columns[3]:SetText(tostring(entry.quantity or 0))
        -- CR-006: Materials column rendering switches between text and icons.
        if iconsMode then
            RenderMaterialIcons(row, row.columns[4], recipe, entry.quantity)
        else
            ReleaseMaterialIcons(row)
            row.columns[4]:SetText(BuildMaterialSummary(recipe, entry.quantity))
        end
        if entry.recraft then
            statusText = statusText .. " · Recraft"
        elseif entry.orderID then
            statusText = statusText .. " · Order"
        end
        row.columns[5]:SetText(statusText)
        -- The 6th column (Actions) is left empty for text; the action buttons
        -- below are anchored into it so they line up with the header.
        if row.columns[6] then
            row.columns[6]:SetText("")
        end

        -- CR-005: Anchor the per-row -/+/Remove buttons to the LEFT edge of
        -- the Actions column instead of the row's RIGHT edge so they sit
        -- under the new "Actions" header rather than over the Status column.
        row.tertiaryButton:ClearAllPoints()
        if row.columns[6] then
            row.tertiaryButton:SetPoint("LEFT", row.columns[6], "LEFT", 0, 0)
        else
            row.tertiaryButton:SetPoint("RIGHT", row, "RIGHT", -4 - 78 - 4 - 24 - 4, 0)
        end
        row.tertiaryButton:Show()
        row.tertiaryButton:SetText("-")
        row.tertiaryButton:SetScript("OnClick", function()
            M.Queue:ChangeQuantity(entry.recipeID, entry.character, -1, entry.orderID)
            UI:RefreshActiveTab()
        end)

        row.secondaryButton:ClearAllPoints()
        row.secondaryButton:SetPoint("LEFT", row.tertiaryButton, "RIGHT", 4, 0)
        row.secondaryButton:Show()
        row.secondaryButton:SetText("+")
        row.secondaryButton:SetScript("OnClick", function()
            M.Queue:ChangeQuantity(entry.recipeID, entry.character, 1, entry.orderID)
            UI:RefreshActiveTab()
        end)

        row.actionButton:ClearAllPoints()
        row.actionButton:SetPoint("LEFT", row.secondaryButton, "RIGHT", 4, 0)
        row.actionButton:Show()
        row.actionButton:SetText("Remove")
        row.actionButton:SetScript("OnClick", function()
            M.Queue:Remove(entry.recipeID, entry.character, entry.orderID)
            UI:RefreshActiveTab()
        end)

        -- CraftSim ReagentOptimization-style "Reagent Picker" button.
        -- Per-row entry so users can plan optional reagents for each queued
        -- recipe individually. Lives on the quaternaryButton slot, anchored
        -- to the right of Remove.
        if M.ReagentOptimizer and row.quaternaryButton then
            local capturedRecipeID = entry.recipeID
            row.quaternaryButton:ClearAllPoints()
            row.quaternaryButton:SetPoint("LEFT", row.actionButton, "RIGHT", 4, 0)
            row.quaternaryButton:SetSize(58, 20)
            row.quaternaryButton:Show()
            row.quaternaryButton:SetText("Reagent")
            row.quaternaryButton:SetScript("OnClick", function()
                M.ReagentOptimizer:ShowRecommendationPopup(capturedRecipeID, 3)
            end)
            row.quaternaryButton:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
                GameTooltip:SetText("Reagent Picker")
                GameTooltip:AddLine("Recommends the cheapest optional/finishing reagent tiers for the target quality.", 0.85, 0.85, 0.85, true)
                GameTooltip:AddLine("Click Q1/Q2/Q3 in the popup to switch target quality.", 0.65, 0.85, 0.95, true)
                GameTooltip:Show()
            end)
            row.quaternaryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        local tooltipLines = {
            string.format("Assigned crafter: %s", entry.character or "Unknown"),
            string.format("Queued quantity: %d", entry.quantity or 0),
            string.format("Craftable now: %d", craftableCount or 0),
            string.format("Engine: %s", entry.engine or "Crafty"),
            entry.recraft and "Recraft: Yes" or "Recraft: No",
            entry.orderID and ("Order ID: " .. tostring(entry.orderID)) or "Order ID: -",
            "Materials: " .. BuildMaterialSummary(recipe, entry.quantity),
        }
        self:AttachTooltip(row, recipe and recipe.name or "Queued recipe", tooltipLines)
        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1
    end

    if M.settings.groupByCharacter ~= false then
        local grouped = M.Queue:GetGroupedByCharacter()
        for _, characterKey in ipairs(SortedCharacterKeys(grouped)) do
            local entries = grouped[characterKey]
            local totalQuantity = 0
            for _, entry in ipairs(entries) do
                totalQuantity = totalQuantity + (entry.quantity or 0)
            end
            local sectionRow = self:GetRow(rowIndex)
            self:PrepareSectionRow(sectionRow, y, M:GetShortCharacterName(characterKey), string.format("%d queued recipe(s) · %d total crafts", #entries, totalQuantity))
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1
            for _, entry in ipairs(entries) do
                renderEntry(entry, 20)
            end
        end
    else
        for _, entry in ipairs(M.Queue:GetAll()) do
            renderEntry(entry, 8)
        end
    end

    self:FinishRender(summary.entries or 0, y)
end

function UI:RenderMaterials()
    self:SetHeaders({ "Material", "Have", "Need", "Shortage", "Source" }, { 320, 110, 110, 110, 330 })
    -- Parity with the sibling-module tabs: degrade gracefully if the core
    -- Materials engine failed to load rather than erroring on nil. (Fix B5)
    if not M.Materials then
        self:SetWindowStatus("Materials engine unavailable.")
        self:FinishRender(0, 0)
        return
    end
    local summary = M.Materials:GetSummary()
    local rawMode = (M.Materials.IsRawMode and M.Materials:IsRawMode()) or false
    self:SetWindowStatus(string.format(
        "%d materials | %d shortages | %d total missing units | Mode: %s",
        summary.totalItems or 0, summary.shortageItems or 0, summary.totalShortage or 0,
        rawMode and "Power Crafting (raw materials)" or "Direct ingredients"
    ))

    local rows = M.Materials:GetSortedTotals(false)
    local y = 0
    for index, data in ipairs(rows) do
        local row = self:GetRow(index)
        local producer = data.producerRecipeID and M.Recipes:Get(data.producerRecipeID) or nil
        local baseSource = producer and string.format("Craft via %s (%s)", producer.name or "recipe", producer.profession or "profession")
            or (data.source == "Crafted" and string.format("Craft chain via %s", data.profession or "profession") or (data.source or "Raw"))

        -- CR-009: enrich the Source column with capture + snapshot expansion.
        -- For producer-driven (live) crafts, baseSource is already authoritative
        -- and we don't reach into the snapshot tiers.
        local sourceText = baseSource
        local sourceLines = nil
        local sourceTier = nil
        if not producer and M.Materials.DescribeSource then
            local desc = M.Materials:DescribeSource(data.itemID, baseSource)
            if desc then
                sourceText = desc.summary or baseSource
                sourceLines = desc.lines
                sourceTier = desc.tier
            end
        end

        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, { 320, 110, 110, 110, 330 }, 8)
        row.columns[1]:SetText(data.name)
        row.columns[2]:SetText(tostring(data.have or 0))
        row.columns[3]:SetText(tostring(data.need or 0))
        row.columns[4]:SetText((data.shortage or 0) > 0 and ("|cffd95f5f" .. data.shortage .. "|r") or "|cff5cf0a00|r")
        row.columns[5]:SetText(sourceText)

        if producer and (data.shortage or 0) > 0 then
            row.actionButton:Show()
            row.actionButton:SetText("Craft")
            row.actionButton:SetScript("OnClick", function()
                M.Materials:QueueProducer(data.itemID, data.shortage)
                UI:RefreshActiveTab()
            end)
        end

        local tooltipLines = {
            string.format("Need: %d", data.need or 0),
            string.format("Have: %d", data.have or 0),
            string.format("Shortage: %d", data.shortage or 0),
        }
        if producer then
            tooltipLines[#tooltipLines + 1] = "Producer: " .. producer.name .. " [" .. (producer.profession or "Profession") .. "]"
        else
            tooltipLines[#tooltipLines + 1] = "Source: " .. (data.source or "Raw")
        end
        if sourceLines and #sourceLines > 0 then
            tooltipLines[#tooltipLines + 1] = " "
            for _, line in ipairs(sourceLines) do
                tooltipLines[#tooltipLines + 1] = line
            end
            if sourceTier == "snapshot" then
                tooltipLines[#tooltipLines + 1] = "|cff8c8c8c(snapshot data — visit a vendor in-game to override with live observation)|r"
            end
        elseif sourceTier == "none" and not producer then
            tooltipLines[#tooltipLines + 1] = " "
            tooltipLines[#tooltipLines + 1] = "|cff8c8c8cNo capture or snapshot data for this material yet.|r"
        end
        self:AttachTooltip(row, data.name, tooltipLines)
        y = y + ROW_HEIGHT + 2
    end

    -- HousingLumberHelper-style "Best Zones" subsection. Surfaces the top
    -- 5 lumber-yielding zones the player has gathered in. Reads from
    -- M.Lumber:GetBestZones() which is backed by the FarmSession per-zone
    -- counters (M.db.lumberByZone) populated on every successful gather.
    local rowIndex = #rows + 1
    if M.Lumber and M.Lumber.GetBestZones then
        local zoneRows = M.Lumber:GetBestZones(5)
        if #zoneRows > 0 then
            local divider = self:GetRow(rowIndex)
            self:PrepareSectionRow(divider, y,
                "Lumber · Best Zones",
                "Top zones by gathers/hour (this account). Captured automatically from your farming sessions.")
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1
            for _, zone in ipairs(zoneRows) do
                local row = self:GetRow(rowIndex)
                row:SetPoint("TOPLEFT", 0, -y)
                row:Show()
                row:SetBackdropColor(0.10, 0.18, 0.12, 0.20)
                self:BuildColumns(row, { 320, 110, 110, 110, 330 }, 8)
                row.columns[1]:SetText(zone.zoneName or "Unknown zone")
                row.columns[2]:SetText(tostring(zone.count or 0))
                row.columns[3]:SetText(tostring(zone.ratePerHour or 0) .. "/hr")
                row.columns[4]:SetText(string.format("%dm", math.floor((zone.sessionTime or 0) / 60)))
                row.columns[5]:SetText(zone.lastSeen and zone.lastSeen > 0 and date("%Y-%m-%d %H:%M", zone.lastSeen) or "-")
                self:AttachTooltip(row, zone.zoneName or "Zone", {
                    string.format("Map ID: %s", tostring(zone.mapID or "?")),
                    string.format("Total gathers: %d", zone.count or 0),
                    string.format("Rate: %d/hr", zone.ratePerHour or 0),
                    string.format("Tracked time: %dm", math.floor((zone.sessionTime or 0) / 60)),
                })
                y = y + ROW_HEIGHT + 2
                rowIndex = rowIndex + 1
            end
        end
    end

    self:FinishRender(rowIndex - 1, y)
end

-- Inventory: every crafting reagent currently held, grouped by category.
--
-- Deliberately queue-independent. The Materials tab reports what the queue is
-- short of, so it reads empty with an empty queue; this one reports stock on
-- hand and is useful before any plan exists.
function UI:RenderInventory()
    if not M.Materials or not M.Materials.GetInventory then
        self:SetHeaders({ "Material" }, { 320 })
        self:SetWindowStatus("Materials engine unavailable.")
        self:FinishRender(0, 0)
        return
    end

    local widths = self:ResolveColumns({ 300, 170, 110, 110, 200 }, 5, 8)
    self:SetHeaders({ "Material", "Category", "In Bags", "Total", "Used In" }, widths, "Actions")

    local rows = M.Materials:GetInventory()
    local summary = M.Materials:GetInventorySummary(rows)

    local query = (M.filters.text or ""):lower()
    if query ~= "" then
        local filtered = {}
        for _, data in ipairs(rows) do
            if data.name:lower():find(query, 1, true) or data.category:lower():find(query, 1, true) then
                filtered[#filtered + 1] = data
            end
        end
        rows = filtered
    end

    self:SetWindowStatus(string.format(
        "%d stacks across %d categories | %d total units | %d not used by any known recipe%s",
        summary.stacks, summary.categories, summary.units, summary.unused,
        query ~= "" and string.format(" | filtered to %d by search", #rows) or ""))

    local rowIndex, y = 1, 0
    local currentCategory = nil

    for _, data in ipairs(rows) do
        -- Category band, emitted lazily as the sort order crosses into a new
        -- one, so an empty category can never produce a stranded header.
        if data.category ~= currentCategory then
            currentCategory = data.category
            local sectionRow = self:GetRow(rowIndex)
            local held, stacks = 0, 0
            for _, other in ipairs(rows) do
                if other.category == currentCategory then
                    held = held + other.total
                    stacks = stacks + 1
                end
            end
            self:PrepareSectionRow(sectionRow, y, currentCategory,
                string.format("%d item%s · %d units", stacks, stacks == 1 and "" or "s", held))
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1
        end

        local row = self:GetRow(rowIndex)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, widths, 8)

        local nameText = data.name
        if data.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[data.quality] then
            local hex = ITEM_QUALITY_COLORS[data.quality].hex
            if hex then nameText = hex .. data.name .. "|r" end
        end
        row.columns[1]:SetText(nameText)
        row.columns[2]:SetText(data.category)
        -- Dim a zero so "none in bags, plenty in the bank" reads at a glance.
        row.columns[3]:SetText(data.bags > 0 and tostring(data.bags) or "|cff615e860|r")
        row.columns[4]:SetText(tostring(data.total))
        if data.usedIn > 0 then
            row.columns[5]:SetText(string.format("%d recipe%s", data.usedIn, data.usedIn == 1 and "" or "s"))
        elseif data.consumers and #data.consumers > 0 then
            -- No recipe in the corpus references it, but ProfessionsHelper
            -- recorded which professions do. Naming them beats "unused".
            local shown = data.consumers[1]
            if #data.consumers > 1 then
                shown = string.format("%s +%d", shown, #data.consumers - 1)
            end
            row.columns[5]:SetText("|cff8f8ab8" .. shown .. "|r")
        else
            row.columns[5]:SetText("|cff615e86unused|r")
        end

        local capturedName = data.name
        local capturedItemID = data.itemID
        if data.usedIn > 0 then
            row.actionButton:Show()
            row.actionButton:SetText("Recipes")
            row.actionButton:SetScript("OnClick", function()
                -- Reuse the existing search: it already matches on materials
                -- when "+ Mats" is on, which is exactly this question.
                M.filters.text = capturedName
                M.filters.searchMats = true
                if UI.searchBox then UI.searchBox:SetText(capturedName) end
                UI:OpenToTab("recipes")
            end)
            StyleActionButton(row.actionButton)
        end

        self:AttachTooltip(row, data.name, {
            string.format("Item ID: %d", capturedItemID),
            string.format("In bags: %d", data.bags),
            string.format("Total (bags + bank + warband): %d", data.total),
            data.usedIn > 0
                and string.format("Used by %d known recipe%s", data.usedIn, data.usedIn == 1 and "" or "s")
                or "Not used by any recipe in the current corpus",
            " ",
            "Click Recipes to search every recipe that consumes this.",
        })

        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1
    end

    self:FinishRender(rowIndex - 1, y)
    if rowIndex == 1 then
        self.emptyState:SetText(query ~= ""
            and "No crafting materials match that search."
            or "No crafting materials found in your bags, bank, or warband bank.")
    end
end

-- CR-011: Knowledge completion tracking and grouping helpers.
-- A "source ID" is synthesized from row fields (KnowledgeData entries don't ship one).
local function GetKnowledgeSourceID(data)
    if not data then return nil end
    return string.format("%s|%s|%s|%s|%s",
        tostring(data.profession or ""),
        tostring(data.expansion or ""),
        tostring(data.category or ""),
        tostring(data.itemID or 0),
        tostring((data.quests and data.quests[1]) or data.hint or ""))
end

local function GetKnowledgeCompletedTable(autoCreate)
    if not M.db then return nil end
    if autoCreate and type(M.db.knowledgeCompleted) ~= "table" then
        M.db.knowledgeCompleted = {}
    end
    if type(M.db.knowledgeCompleted) ~= "table" then
        return nil
    end
    local charKey = (M.GetCurrentCharacterKey and M:GetCurrentCharacterKey()) or "ACCOUNT"
    if autoCreate and type(M.db.knowledgeCompleted[charKey]) ~= "table" then
        M.db.knowledgeCompleted[charKey] = {}
    end
    return M.db.knowledgeCompleted[charKey], charKey
end

local function IsKnowledgeRowCompleted(data)
    local table_, _ = GetKnowledgeCompletedTable(false)
    if not table_ then return false end
    local id = GetKnowledgeSourceID(data)
    return id and table_[id] == true
end

local function ToggleKnowledgeRowCompleted(data)
    local table_, _ = GetKnowledgeCompletedTable(true)
    if not table_ then return end
    local id = GetKnowledgeSourceID(data)
    if not id then return end
    if table_[id] then
        table_[id] = nil
    else
        table_[id] = true
    end
    if M.MarkDirty then M:MarkDirty() end
    if M.Fire then M:Fire("DataChanged") end
end

-- Returns the configured "current expansion" for default-expanded sections.
-- Uses the last entry in EXPANSION_ORDER (most recent shipping expansion).
local function GetCurrentKnowledgeExpansion()
    local order = M.EXPANSION_ORDER or {}
    return order[#order]
end

-- Per-(profession+expansion) collapse state, persisted in M.db so the user's
-- expand/collapse choices survive a /reload.
local function GetKnowledgeCollapseTable()
    if not M.db then return {} end
    if type(M.db.knowledgeCollapsed) ~= "table" then
        M.db.knowledgeCollapsed = {}
    end
    return M.db.knowledgeCollapsed
end

local function GetKnowledgeGroupKey(profession, expansion)
    return string.format("%s||%s", tostring(profession or ""), tostring(expansion or ""))
end

local function IsKnowledgeGroupCollapsed(profession, expansion)
    local table_ = GetKnowledgeCollapseTable()
    local key = GetKnowledgeGroupKey(profession, expansion)
    -- If the user has explicitly set a state, honour it.
    if table_[key] ~= nil then
        return table_[key] == true
    end
    -- Default: current expansion expanded; everything else collapsed.
    local currentExp = GetCurrentKnowledgeExpansion()
    if currentExp and expansion == currentExp then
        return false
    end
    return true
end

local function ToggleKnowledgeGroupCollapsed(profession, expansion)
    local table_ = GetKnowledgeCollapseTable()
    local key = GetKnowledgeGroupKey(profession, expansion)
    table_[key] = not IsKnowledgeGroupCollapsed(profession, expansion)
    if M.MarkDirty then M:MarkDirty() end
end

function UI:RenderKnowledge()
    if not isModuleEnabled("knowledge") or not (M.Knowledge and M.KnowledgeData) then
        return self:RenderModuleDisabled("Knowledge", "knowledge")
    end

    -- Lazy-load the player's profession knowledge slices the first time the
    -- Knowledge tab is rendered. The 31,714-line corpus was split into 11
    -- per-profession LoD addons (see Core.lua:EnsureProfessionKnowledgeLoaded);
    -- this call only loads the slices for trained professions on the active
    -- character, so a Skinner avoids ~28k LOC of irrelevant data.
    if M.WarmProfessionKnowledgeForCurrentCharacter then
        M:WarmProfessionKnowledgeForCurrentCharacter()
    end

    -- CR-011: Add a "Done" column at the start, group rows into collapsible
    -- Profession + Expansion sections, and tint completed rows.
    local KNOWLEDGE_WIDTHS = { 50, 130, 110, 130, 70, 90, 510 }
    self:SetHeaders({ "Done", "Profession", "Expansion", "Category", "Points", "Item", "Location" }, KNOWLEDGE_WIDTHS)
    self:SetWindowStatus("Profession Knowledge Sources. Use Waypoint to navigate, right-click any row to mark complete/incomplete.")

    local rowIndex = 1
    local y = 0

    -- Top-of-tab title + subtitle row.
    local titleRow = self:GetRow(rowIndex)
    self:PrepareSectionRow(titleRow, y,
        "Profession Knowledge Sources",
        "Find profession knowledge points by completing treatises, hunting treasures, and visiting unique objects across expansions. Click Waypoint to navigate to a known source.")
    y = y + ROW_HEIGHT + 2
    rowIndex = rowIndex + 1

    local detailRows = M.Knowledge and M.Knowledge:GetRows() or {}
    -- Group the detail rows by (profession, expansion). The flat list from
    -- M.Knowledge:GetRows() is already sorted by profession then expansion,
    -- so iterating it preserves the grouping order while letting us inject
    -- a section row when the (prof, exp) pair changes.
    local lastProfession, lastExpansion = nil, nil
    local groupCollapsed = false

    -- We also need to count rows per group AHEAD of time so the section
    -- header can show the totals correctly. Build a quick index now.
    local groupMeta = {}
    for _, data in ipairs(detailRows) do
        local key = GetKnowledgeGroupKey(data.profession, data.expansion)
        local meta = groupMeta[key]
        if not meta then
            meta = { total = 0, completed = 0, points = 0 }
            groupMeta[key] = meta
        end
        meta.total = meta.total + 1
        meta.points = meta.points + (data.points or 0)
        if IsKnowledgeRowCompleted(data) then
            meta.completed = meta.completed + 1
        end
    end

    local shown = 0
    local currentExpansion = GetCurrentKnowledgeExpansion()
    for _, data in ipairs(detailRows) do
        if shown > 200 then
            break
        end

        local profession = data.profession or "Profession"
        local expansion = data.expansion or "Expansion"

        -- Emit a section header whenever the (prof, exp) pair changes.
        if profession ~= lastProfession or expansion ~= lastExpansion then
            local key = GetKnowledgeGroupKey(profession, expansion)
            local meta = groupMeta[key] or { total = 0, completed = 0, points = 0 }
            groupCollapsed = IsKnowledgeGroupCollapsed(profession, expansion)
            local marker = groupCollapsed and "[+]" or "[-]"
            local currentTag = (currentExpansion and expansion == currentExpansion) and "  (current)" or ""
            local subtitle = string.format("%s %d/%d sources marked complete  %d total points%s",
                marker, meta.completed or 0, meta.total or 0, meta.points or 0, currentTag)

            local sectionRow = self:GetRow(rowIndex)
            self:PrepareSectionRow(sectionRow, y,
                profession .. " - " .. expansion,
                subtitle)
            -- Make the section row clickable so the user can collapse/expand it.
            sectionRow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local capturedProf, capturedExp = profession, expansion
            sectionRow:SetScript("OnMouseUp", function()
                ToggleKnowledgeGroupCollapsed(capturedProf, capturedExp)
                UI:RefreshActiveTab()
            end)
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1

            lastProfession, lastExpansion = profession, expansion
        end

        if not groupCollapsed then
            shown = shown + 1
            local row = self:GetRow(rowIndex)
            row:SetPoint("TOPLEFT", 0, -y)
            row:Show()

            local completed = IsKnowledgeRowCompleted(data)
            if completed then
                -- Subtle green tint for completed rows.
                row:SetBackdropColor(0.18, 0.30, 0.18, 0.18)
            else
                row:SetBackdropColor(1, 1, 1, 0.03)
            end

            self:BuildColumns(row, KNOWLEDGE_WIDTHS, 8)
            -- Done column: green checkmark when completed, dim dash otherwise.
            if completed then
                row.columns[1]:SetText("|cff5cf0a0✔ Done|r")
            else
                row.columns[1]:SetText("|cff666666—|r")
            end

            local function applyTint(text)
                if completed then
                    return "|cff888888" .. (text or "") .. "|r"
                end
                return text or ""
            end
            row.columns[2]:SetText(applyTint(profession))
            row.columns[3]:SetText(applyTint(expansion))
            row.columns[4]:SetText(applyTint(M.Knowledge:GetLabel(data.category)))
            row.columns[5]:SetText(applyTint(tostring(data.points or 0)))
            row.columns[6]:SetText(applyTint((data.itemID or 0) > 0 and tostring(data.itemID) or "-"))
            row.columns[7]:SetText(applyTint(data.hint or ""))

            if data.mapID and data.x and data.y then
                row.actionButton:ClearAllPoints()
                row.actionButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.actionButton:SetSize(78, 20)
                row.actionButton:Show()
                row.actionButton:SetText("Waypoint")
                row.actionButton:SetScript("OnClick", function()
                    if M.Knowledge:SetWaypoint(data) then
                        M:Print("Waypoint set for " .. (data.profession or "knowledge"))
                    end
                end)
                StyleActionButton(row.actionButton)
            end

            -- Right-click toggles completed; left-click is reserved for tooltip / waypoint.
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local capturedData = data
            row:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" then
                    ToggleKnowledgeRowCompleted(capturedData)
                    UI:RefreshActiveTab()
                end
            end)

            local tooltipLines = M.Knowledge:BuildTooltipLines(data)
            tooltipLines[#tooltipLines + 1] = completed and "Right-click: Mark Incomplete" or "Right-click: Mark Complete"
            self:AttachTooltip(row, (profession) .. " · " .. M.Knowledge:GetLabel(data.category), tooltipLines)
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1
        end
    end

    self:FinishRender(rowIndex - 1, y)
end

function UI:RenderGuide()
    self:SetHeaders({ "Range", "Focus", "Notes", "Materials" }, { 100, 420, 320, 280 })
    local rows, status
    if M.Training then
        rows, status = M.Training:GetRows()
    end
    rows = rows or {}
    status = status or "No retail guide available."
    self:SetWindowStatus(status)

    local y = 0
    for index, data in ipairs(rows) do
        local row = self:GetRow(index)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        if data.isActive then
            row:SetBackdropColor(0.20, 0.30, 0.18, 0.35)
        elseif data.kind == "knowledge" then
            row:SetBackdropColor(0.18, 0.22, 0.28, 0.25)
        else
            row:SetBackdropColor(1, 1, 1, 0.03)
        end
        self:BuildColumns(row, { 100, 420, 320, 280 }, 8)
        row.columns[1]:SetText(data.skill or "")
        row.columns[2]:SetText(data.title or "")
        row.columns[3]:SetText(data.note or "")
        row.columns[4]:SetText(data.materials or "")
        self:AttachTooltip(row, data.title or "Guide", {
            data.note or "",
            data.materials or "",
        })
        y = y + ROW_HEIGHT + 2
    end

    self:FinishRender(#rows, y)
end

function UI:RenderAlts()
    if not isModuleEnabled("roster") or not M.Alts then
        return self:RenderModuleDisabled("Alt Roster", "roster")
    end
    self:SetHeaders({ "Name", "Focus", "Coverage", "Known", "Last Seen" }, { 200, 160, 450, 180, 120 })
    local characters = M.Alts:GetAllCharacters()
    self:SetWindowStatus(string.format("%d tracked character(s) | Queue grouping is %s | gear/spec snapshots piggyback on profession scans", #characters, M.settings.groupByCharacter ~= false and "enabled" or "disabled"))

    local rowIndex = 1
    local y = 0
    local matrix = M.Recipes:GetProfessionExpansionMatrix()

    local summaryRows = {}
    for _, profession in ipairs(M.PROFESSION_ORDER or {}) do
        local buckets = matrix[profession] or {}
        local details = {}
        local known, collected, total, ready = 0, 0, 0, 0
        for _, expansion in ipairs(M.EXPANSION_ORDER or {}) do
            local bucket = buckets[expansion]
            if bucket and (bucket.total or 0) > 0 then
                details[#details + 1] = string.format("%s %d/%d", expansion, bucket.known or 0, bucket.total or 0)
                known = known + (bucket.known or 0)
                collected = collected + (bucket.collected or 0)
                total = total + (bucket.total or 0)
                ready = ready + (bucket.ready or 0)
            end
        end
        if total > 0 then
            summaryRows[#summaryRows + 1] = {
                profession = profession,
                details = table.concat(details, "  |  "),
                totals = string.format("%d known · %d collected · %d ready", known, collected, ready),
                total = total,
            }
        end
    end

    if #summaryRows > 0 then
        local section = self:GetRow(rowIndex)
        self:PrepareSectionRow(section, y, "Profession Summary", "Account-wide recipe coverage by profession and expansion.")
        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1

        for _, summaryRow in ipairs(summaryRows) do
            local row = self:GetRow(rowIndex)
            row:SetPoint("TOPLEFT", 0, -y)
            row:Show()
            row:SetBackdropColor(1, 1, 1, 0.03)
            self:BuildColumns(row, { 200, 160, 450, 180, 120 }, 8)
            row.columns[1]:SetText(summaryRow.profession)
            row.columns[2]:SetText("Summary")
            row.columns[3]:SetText(summaryRow.details)
            row.columns[4]:SetText(summaryRow.totals)
            row.columns[5]:SetText(string.format("%d total", summaryRow.total))
            self:AttachTooltip(row, summaryRow.profession, {
                "Known count reflects any tracked character who knows the recipe.",
                summaryRow.details,
                summaryRow.totals,
            })
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1
        end

        local divider = self:GetRow(rowIndex)
        self:PrepareSectionRow(divider, y, "Characters", "Tracked alt profession skill, recipe knowledge, concentration, gear, cooldown, and specialization snapshots.")
        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1
    end

    for _, characterKey in ipairs(characters) do
        local row = self:GetRow(rowIndex)
        local data = M.Alts:GetCharacterData(characterKey) or {}
        local professionParts = {}
        local loadoutBits = {}
        for professionName, profData in pairs(data.professions or {}) do
            local skill = profData.skillLevel or 0
            local maxSkill = profData.maxSkillLevel or 0
            local color
            if skill <= 0 then
                color = "|cffffffff"
            elseif maxSkill > 0 and skill < maxSkill then
                color = "|cffffd05a"
            else
                color = "|cff5cf0a0"
            end
            professionParts[#professionParts + 1] = {
                sortKey = professionName,
                text = string.format("%s%s %d/%d|r", color, professionName, skill, maxSkill),
            }
            local gearSummary = M.Alts:GetGearSummary(characterKey, professionName)
            if gearSummary then
                loadoutBits[#loadoutBits + 1] = string.format("%s [%s]", professionName, gearSummary)
            end
        end

        local knownCount = 0
        for _ in pairs(data.recipes or {}) do
            knownCount = knownCount + 1
        end

        local concentrationSummary = M.Alts:GetConcentrationSummary(characterKey)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, { 200, 160, 450, 180, 120 }, 8)
        row.columns[1]:SetText(M:GetShortCharacterName(characterKey))
        row.columns[2]:SetText(concentrationSummary)
        row.columns[3]:SetText(SortProfessionParts(professionParts))
        row.columns[4]:SetText(string.format("%d recipes%s", knownCount, (#loadoutBits > 0) and (" · " .. #loadoutBits .. " loadouts") or ""))
        row.columns[5]:SetText(date("%Y-%m-%d", data.lastSeen or time()))
        local tooltipLines = {
            string.format("Level %s %s", tostring(data.level or "?"), tostring(data.class or "Unknown")),
            string.format("Known recipes: %d", knownCount),
            string.format("Last seen: %s", date("%Y-%m-%d %H:%M", data.lastSeen or time())),
        }
        for _, line in ipairs(M.Concentration and M.Concentration:BuildTooltipLines(characterKey) or {}) do
            tooltipLines[#tooltipLines + 1] = line
        end
        for professionName, profData in pairs(data.professions or {}) do
            local gearSummary = M.Alts:GetGearSummary(characterKey, professionName)
            if gearSummary then
                tooltipLines[#tooltipLines + 1] = string.format("%s gear: %s", professionName, gearSummary)
            end
            local specSummary = M.Alts:GetSpecSummary(characterKey, professionName)
            if specSummary then
                tooltipLines[#tooltipLines + 1] = string.format("%s specs: %s", professionName, specSummary)
            end
            local cooldowns = profData.cooldowns or {}
            local cdCount = 0
            for _ in pairs(cooldowns) do cdCount = cdCount + 1 end
            if cdCount > 0 then
                tooltipLines[#tooltipLines + 1] = string.format("%s cooldowns tracked: %d", professionName, cdCount)
            end
        end
        self:AttachTooltip(row, characterKey, tooltipLines)
        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1
    end

    self:FinishRender(#characters + #summaryRows, y)
end

-- CR-010: Map an advisor row (title/action) to a real click action.
-- Returns: actionLabel (button text) and onClick handler, or nil/nil when the row has no jump target.
local function ResolveAdvisorAction(data)
    local title = (data and data.title) or ""
    local actionTag = (data and data.action) or ""

    local function openProfessionsWindow()
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_Professions")
        end

        local opened = false
        if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
            -- If a profession filter is selected, jump straight to that pro.
            if M.Gear and M.Gear.GetProfessionEnum and M.filters and M.filters.profession and M.filters.profession ~= "ALL" then
                local enum = M.Gear:GetProfessionEnum(M.filters.profession)
                if enum then
                    local ok = pcall(C_TradeSkillUI.OpenTradeSkill, enum)
                    if ok then opened = true end
                end
            end
        end

        -- Fallback: open the spellbook to the professions tab so the user can pick one.
        if not opened and ToggleSpellBook and BOOKTYPE_PROFESSIONS then
            pcall(ToggleSpellBook, BOOKTYPE_PROFESSIONS)
        end
    end

    -- Title-driven mapping (most reliable - Advisor.lua sets these literally).
    if title == "Open a profession" then
        return "Open", openProfessionsWindow
    elseif title:find("^Queue pressure") then
        return "Open Queue", function() UI:OpenToTab("queue") end
    elseif title:find("^Shopping pressure") then
        return "Open Materials", function() UI:OpenToTab("materials") end
    elseif title == "Tooltip compositor" then
        return "Settings", function()
            if M.OpenSettings then M:OpenSettings() end
        end
    elseif title:find("^Knowledge") then
        return "Open", function() UI:OpenToTab("knowledge") end
    elseif title:find("^Guide") then
        return "Open", function() UI:OpenToTab("guide") end
    elseif title:find("^Trainer") then
        return "Open", function() UI:OpenToTab("trainers") end
    elseif title:find("^Gearing") then
        return "Open", function() UI:OpenToTab("gearing") end
    elseif title:find("^Best timer") or title:find("^Cooldown") then
        return "Open", function() UI:OpenToTab("timers") end
    elseif title:find("^Craft session") then
        return "Open", function() UI:OpenToTab("data") end
    elseif title:find("browser snapshot") then
        return "Open", function() UI:OpenToTab("recipes") end
    end

    -- Fallback: route by the action tag string from Advisor.lua.
    local tagToTab = {
        Recipes = "recipes",
        Queue = "queue",
        Materials = "materials",
        Knowledge = "knowledge",
        Guide = "guide",
        Trainers = "trainers",
        Gearing = "gearing",
        Timers = "timers",
        Data = "data",
    }
    local tabKey = tagToTab[actionTag]
    if tabKey then
        return "Open", function() UI:OpenToTab(tabKey) end
    end

    if actionTag == "Open Blizzard Professions" then
        return "Open", openProfessionsWindow
    end
    if actionTag == "Tooltips" then
        return "Settings", function()
            if M.OpenSettings then M:OpenSettings() end
        end
    end

    return nil, nil
end

function UI:RenderAdvisor()
    if not isModuleEnabled("advisor") or not M.Advisor then
        return self:RenderModuleDisabled("Advisor", "advisor")
    end
    -- CR-010: Add a description row at the top, then wire the Action column
    -- to a real button instead of static text.
    -- The Action column used to be a real 4th column at a fixed 120px, which
    -- put the column run at ~1134px inside a ~1094px row: the button started
    -- past the right edge and its label was cut off ("Open Que", "Open Mate").
    -- It now uses the shared right-hand action gutter like every other tab,
    -- with Details flexing into whatever is left.
    local widths = self:ResolveColumns({ 260, 560, 130 }, 2, 8)
    self:SetHeaders({ "Focus", "Details", "Status" }, widths, "Action")
    self:SetWindowStatus("Crafty's contextual recommendations. Click an Action to jump to the relevant tab or workflow.")

    local rowIndex = 1
    local y = 0

    -- Top-of-tab description row (uses the section row backdrop for emphasis).
    local descRow = self:GetRow(rowIndex)
    self:PrepareSectionRow(descRow, y,
        "Advisor",
        "Crafty's contextual recommendations. Click an Action to jump to the relevant tab or workflow.")
    y = y + ROW_HEIGHT + 2
    rowIndex = rowIndex + 1

    local rows = M.Advisor and M.Advisor:GetRows() or {}
    for _, data in ipairs(rows) do
        local row = self:GetRow(rowIndex)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, widths, 8)
        row.columns[1]:SetText(data.title or "")
        row.columns[2]:SetText(data.detail or "")
        row.columns[3]:SetText(data.status or "")

        local label, onClick = ResolveAdvisorAction(data)
        if label and onClick then
            -- Default right-edge placement, inside the reserved gutter, so the
            -- button lands under the "Action" header at any window width.
            row.actionButton:Show()
            row.actionButton:SetText(label)
            row.actionButton:SetScript("OnClick", function()
                local ok, err = pcall(onClick)
                if not ok then
                    M:Print("Advisor action failed: " .. tostring(err))
                end
            end)
            StyleActionButton(row.actionButton)
        end

        self:AttachTooltip(row, data.title or "Advisor", { data.detail or "", data.status or "", data.action or "" })
        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1
    end

    self:FinishRender(rowIndex - 1, y)
end

function UI:RenderTimers()
    if not isModuleEnabled("concentration") or not M.Concentration then
        return self:RenderModuleDisabled("Timers", "concentration")
    end
    local widths = { 110, 150, 300, 160, 90, 170, 140 }
    self:SetHeaders({ "Type", "Character", "Focus", "State", "Charges", "Forecast", "Ready At" }, widths)
    local target = tonumber(M.settings.concentrationForecastTarget) or 1000
    self:SetWindowStatus((M.Timers and M.Timers.GetStatusText and M.Timers:GetStatusText(target, M.filters.profession)) or "No timers tracked yet.")

    local rows = M.Timers and M.Timers:GetRows(M.filters.profession) or {}
    local y = 0
    for index, data in ipairs(rows) do
        local row = self:GetRow(index)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor((data.kind == "Cooldown") and 0.18 or 1, (data.kind == "Cooldown") and 0.20 or 1, (data.kind == "Cooldown") and 0.28 or 1, (data.kind == "Cooldown") and 0.18 or 0.03)
        self:BuildColumns(row, widths, 8)
        row.columns[1]:SetText(data.kind)
        row.columns[2]:SetText(M:GetShortCharacterName(data.characterKey))
        row.columns[3]:SetText((data.kind == "Cooldown") and string.format("%s - %s", data.professionName or "Profession", data.recipeName or "Recipe") or (data.professionName or "Profession"))
        row.columns[4]:SetText(data.state or "")
        row.columns[5]:SetText(data.charges or "")
        if data.kind == "Cooldown" then
            if (data.forecastSeconds or 0) <= 0 then
                row.columns[6]:SetText("|cff5cf0a0Ready now|r")
            else
                row.columns[6]:SetText("Time: " .. M.Concentration:FormatTimer(data.forecastSeconds or 0))
            end
            row.columns[7]:SetText(data.nextAt or "")
        else
            if data.forecastSeconds == nil then
                row.columns[6]:SetText(string.format("Target %d unreachable", target))
            elseif (data.forecastSeconds or 0) <= 0 then
                row.columns[6]:SetText(string.format("At target %d", target))
            else
                row.columns[6]:SetText(M.Concentration:FormatTimer(data.forecastSeconds or 0))
            end
            row.columns[7]:SetText(data.nextAt or "")
        end
        self:AttachTooltip(row, M:GetShortCharacterName(data.characterKey) .. " - " .. (data.professionName or data.recipeName or data.kind), data.tooltip or {})
        y = y + ROW_HEIGHT + 2
    end

    self:FinishRender(#rows, y)
end

-- CR-015: Format the per-character crafting stat totals into a compact string
-- suitable for the "Stats" column. Skill is intentionally omitted from the
-- summary stats here because that's the profession-skill bonus, not a
-- crafting outcome stat.
local function FormatGearingStatTotals(totals)
    if not totals then
        return "|cff666666No statted gear|r"
    end
    local parts = {}
    if (totals.ingenuity or 0) > 0 then
        parts[#parts + 1] = string.format("Ing %d", totals.ingenuity)
    end
    if (totals.multicraft or 0) > 0 then
        parts[#parts + 1] = string.format("MC %d", totals.multicraft)
    end
    if (totals.resourcefulness or 0) > 0 then
        parts[#parts + 1] = string.format("RF %d", totals.resourcefulness)
    end
    if (totals.craftingspeed or 0) > 0 then
        parts[#parts + 1] = string.format("Spd %d", totals.craftingspeed)
    end
    if (totals.skill or 0) > 0 then
        parts[#parts + 1] = string.format("Skill +%d", totals.skill)
    end
    if #parts == 0 then
        return "|cff666666No statted gear|r"
    end
    return table.concat(parts, "  ")
end

-- CR-015: Build the per-character rows for the Gearing tab. Iterates every
-- tracked character and emits one row per profession that has been seen.
-- Characters with no professions yet get a single placeholder row prompting
-- the user to log on with that alt to capture data.
local function BuildGearingCharacterRows()
    local out = {}
    if not M.Alts or not M.Alts.GetAllCharacters then
        return out
    end
    for _, characterKey in ipairs(M.Alts:GetAllCharacters()) do
        local char = M.Alts:GetCharacterData(characterKey) or {}
        local professions = char.professions or {}
        local hadAny = false
        for professionName, profData in pairs(professions) do
            local hasGear = type(profData.gear) == 'table'
            local hasSpec = type(profData.specialization) == 'table'
            if hasGear or hasSpec or (profData.skillLevel or 0) > 0 then
                hadAny = true
                local gearText = hasGear and (M.Gear and M.Gear.DescribeTotals and M.Gear:DescribeTotals(profData.gear.totals)) or 'No profession gear snapshot'
                local specText = hasSpec and (M.Specs and M.Specs.GetSummaryText and M.Specs:GetSummaryText(profData.specialization)) or 'No specialization snapshot'
                local statsText = hasGear and FormatGearingStatTotals(profData.gear.totals) or "|cff666666--|r"
                local tooltip = (M.Gear and M.Gear.GetTooltipLines and M.Gear:GetTooltipLines(characterKey, professionName)) or { 'No profession gear snapshot.' }
                out[#out + 1] = {
                    characterKey = characterKey,
                    professionName = professionName,
                    skillLevel = profData.skillLevel or 0,
                    maxSkillLevel = profData.maxSkillLevel or 0,
                    gearText = gearText,
                    specText = specText,
                    statsText = statsText,
                    tooltip = tooltip,
                    isPlaceholder = false,
                }
            end
        end
        if not hadAny then
            out[#out + 1] = {
                characterKey = characterKey,
                professionName = "-",
                gearText = "Log on to capture gear data.",
                specText = "Log on to capture specialization.",
                statsText = "|cff666666--|r",
                tooltip = { "No profession data has been captured for this character yet.",
                            "Log onto this alt and open a profession window to populate the snapshot." },
                isPlaceholder = true,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.characterKey ~= b.characterKey then
            return a.characterKey < b.characterKey
        end
        return (a.professionName or "") < (b.professionName or "")
    end)
    return out
end

function UI:RenderGearing()
    if not isModuleEnabled("topGear") or not (M.Gear or M.GearOptimizer or M.GearingOverview) then
        return self:RenderModuleDisabled("Gearing", "topGear")
    end
    -- CR-015: Reimagined as a per-character gear viewer. Title + subtitle at
    -- the top, character/profession rows in the middle, and the legacy
    -- "System" rows demoted to an optional debug section at the bottom.
    local GEARING_WIDTHS = { 130, 140, 280, 250, 200 }
    self:SetHeaders({ "Character", "Profession", "Gear (Ilvl/Skill)", "Specialization", "Crafting Stats" }, GEARING_WIDTHS)
    self:SetWindowStatus("Profession Gear & Specialization. Equipped tools and accessories per character, plus specialization summary and crafting stat totals.")

    local rowIndex = 1
    local y = 0

    -- Top-of-tab title + subtitle.
    local titleRow = self:GetRow(rowIndex)
    self:PrepareSectionRow(titleRow, y,
        "Profession Gear & Specialization",
        "Equipped tools and accessories per character, plus specialization summary and crafting stat totals.")
    y = y + ROW_HEIGHT + 2
    rowIndex = rowIndex + 1

    -- Per-character gearing rows.
    local rows = BuildGearingCharacterRows()
    for _, data in ipairs(rows) do
        local row = self:GetRow(rowIndex)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        if data.isPlaceholder then
            row:SetBackdropColor(0.30, 0.20, 0.10, 0.18)
        else
            row:SetBackdropColor(1, 1, 1, 0.03)
        end
        self:BuildColumns(row, GEARING_WIDTHS, 8)
        row.columns[1]:SetText(M:GetShortCharacterName(data.characterKey))
        local profLabel = data.professionName or ""
        if not data.isPlaceholder and (data.skillLevel or 0) > 0 then
            profLabel = string.format("%s %d/%d", profLabel, data.skillLevel or 0, data.maxSkillLevel or 0)
        end
        row.columns[2]:SetText(profLabel)
        row.columns[3]:SetText(data.gearText or "")
        row.columns[4]:SetText(data.specText or "")
        row.columns[5]:SetText(data.statsText or "")
        self:AttachTooltip(row,
            string.format("%s · %s", M:GetShortCharacterName(data.characterKey), data.professionName or "Profession"),
            data.tooltip or {})
        y = y + ROW_HEIGHT + 2
        rowIndex = rowIndex + 1
    end

    -- Optional debug "System" rows behind a settings toggle. Default off so
    -- the tab actually shows gear info; users who want the architecture
    -- summary can enable M.settings.gearingShowSystemRows.
    if M.settings and M.settings.gearingShowSystemRows then
        local sysList = (M.GearingOverview and M.GearingOverview.GetSystemRows and M.GearingOverview:GetSystemRows()) or {}
        if #sysList > 0 then
            local divider = self:GetRow(rowIndex)
            self:PrepareSectionRow(divider, y,
                "Debug: System Surfaces",
                "Architecture diagnostics. Toggle off via M.settings.gearingShowSystemRows = false.")
            y = y + ROW_HEIGHT + 2
            rowIndex = rowIndex + 1

            for _, sysRow in ipairs(sysList) do
                local row = self:GetRow(rowIndex)
                row:SetPoint("TOPLEFT", 0, -y)
                row:Show()
                row:SetBackdropColor(0.18, 0.22, 0.28, 0.25)
                self:BuildColumns(row, GEARING_WIDTHS, 8)
                row.columns[1]:SetText("System")
                row.columns[2]:SetText(sysRow.title or "")
                row.columns[3]:SetText(sysRow.detail or "")
                row.columns[4]:SetText("")
                row.columns[5]:SetText(sysRow.status or "")
                y = y + ROW_HEIGHT + 2
                rowIndex = rowIndex + 1
            end
        end
    end

    self:FinishRender(rowIndex - 1, y)
end

function UI:RenderProfit()
    if not isModuleEnabled("profit") or not M.Profit then
        return self:RenderModuleDisabled("Goblin (Profit)", "profit")
    end
    self:SetHeaders({ "Recipe", "Sell", "Mats", "Profit", "Margin" }, { 420, 150, 150, 150, 140 })
    self:SetWindowStatus(string.format("Profit view uses %s engine with TSM/Auctionator when present, otherwise the local history cache.", (M.settings and M.settings.useCraftSimProfitModel) and "CraftSim-like" or "Crafty"))

    local rows = M.Profit:GetSortedRows()
    local y = 0
    for index, data in ipairs(rows) do
        local row = self:GetRow(index)
        local recipe = M.Recipes:Get(data.recipeID)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, { 420, 150, 150, 150, 140 }, 8)
        row.columns[1]:SetText(data.recipeName)
        row.columns[2]:SetText(M.Util:MoneyToString(data.salePrice))
        row.columns[3]:SetText(M.Util:MoneyToString((data.engine == "CraftSim-like") and (data.effectiveMaterialCost or data.materialCost) or data.materialCost))
        row.columns[4]:SetText(data.profit >= 0 and ("|cff5cf0a0" .. M.Util:MoneyToString(data.profit) .. "|r") or ("|cffd95f5f" .. M.Util:MoneyToString(data.profit) .. "|r"))
        row.columns[5]:SetText(string.format("%.1f%%", data.margin))
        self:AttachTooltip(row, data.recipeName, {
            string.format("Sale price: %s", M.Util:MoneyToString(data.salePrice)),
            string.format("Raw material cost: %s", M.Util:MoneyToString(data.materialCost)),
            string.format("Effective material cost: %s", M.Util:MoneyToString(data.effectiveMaterialCost or data.materialCost)),
            string.format("Profit: %s", M.Util:MoneyToString(data.profit)),
            string.format("Engine: %s", data.engine or "Crafty"),
            data.crafter and ("Best crafter: " .. M:GetShortCharacterName(data.crafter)) or "Best crafter: none",
            recipe and ("Materials: " .. BuildMaterialSummary(recipe, 1)) or "",
        })
        y = y + ROW_HEIGHT + 2
    end

    self:FinishRender(#rows, y)
end

function UI:RenderTrainers()
    if not isModuleEnabled("trainers") or not M.Trainers then
        return self:RenderModuleDisabled("Trainers", "trainers")
    end
    self:SetHeaders({ "Trainer", "Profession", "Expansion", "Zone", "Coords" }, { 280, 180, 140, 250, 120 })
    self:SetWindowStatus("Trainer routing with native waypoint support and alt awareness for missing profession coverage.")

    local rows = M.Trainers:GetFiltered()
    local y = 0
    for index, trainer in ipairs(rows) do
        local row = self:GetRow(index)
        local needs = M.Trainers:GetCharactersNeedingTraining(trainer.profession)
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, { 280, 180, 140, 250, 120 }, 8)
        row.columns[1]:SetText(trainer.name)
        row.columns[2]:SetText(#needs > 0 and (trainer.profession .. " · Needs: " .. table.concat(needs, ", ")) or trainer.profession)
        row.columns[3]:SetText(trainer.expansion)
        row.columns[4]:SetText(trainer.zone)
        row.columns[5]:SetText(string.format("%.1f, %.1f", trainer.x * 100, trainer.y * 100))
        row.actionButton:Show()
        row.actionButton:SetText("Waypoint")
        row.actionButton:SetScript("OnClick", function()
            if M.Trainers:SetWaypoint(trainer) then
                M:Print("Waypoint set for " .. trainer.name)
            else
                M:Print("Unable to set waypoint here.")
            end
        end)
        self:AttachTooltip(row, trainer.name, {
            string.format("Profession: %s", trainer.profession),
            string.format("Expansion: %s", trainer.expansion),
            string.format("Zone: %s", trainer.zone),
            #needs > 0 and ("Characters missing this profession: " .. table.concat(needs, ", ")) or "No tracked alts are missing this profession.",
        })
        y = y + ROW_HEIGHT + 2
    end

    self:FinishRender(#rows, y)
end

function UI:RenderData()
    if not isModuleEnabled("history") or not (M.History or M.CraftLog) then
        return self:RenderModuleDisabled("History", "history")
    end
    self:SetHeaders({ "When", "Type", "Subject", "Qty", "Notes" }, { 170, 120, 360, 90, 390 })
    self:SetWindowStatus("Recent activity merges queue changes with captured craft-result events. Export creates CSV text.")

    local rows = M.History:GetRecentRows()
    local y = 0
    for index, eventRow in ipairs(rows) do
        local row = self:GetRow(index)
        local recipe = M.Recipes:Get(eventRow.recipeID)
        local subject = eventRow.recipeName or (recipe and recipe.name) or tostring(eventRow.recipeID or '-')
        local qty = tonumber(eventRow.quantity or eventRow.outputQuantity or eventRow.crafts or 0) or 0
        local notes
        if eventRow.kind == 'craft' then
            notes = string.format('Profit %s · Mats %s · Sale %s%s', M.Util:MoneyToString(eventRow.profit or 0), M.Util:MoneyToString(eventRow.actualMaterialCost or 0), M.Util:MoneyToString(eventRow.saleValue or 0), (eventRow.concentrationSpent or 0) > 0 and (' · Conc ' .. tostring(eventRow.concentrationSpent or 0)) or '')
        else
            notes = string.format('Character: %s', M:GetShortCharacterName(eventRow.character))
        end
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        row:SetBackdropColor(1, 1, 1, 0.03)
        self:BuildColumns(row, { 170, 120, 360, 90, 390 }, 8)
        row.columns[1]:SetText(date("%Y-%m-%d %H:%M", eventRow.ts or time()))
        row.columns[2]:SetText(eventRow.kind or '')
        row.columns[3]:SetText(subject)
        row.columns[4]:SetText(tostring(qty))
        row.columns[5]:SetText(notes)
        local tooltip = {
            string.format('Event type: %s', tostring(eventRow.kind or '')),
            string.format('Character: %s', tostring(eventRow.character or '')),
            string.format('Quantity: %d', qty),
        }
        if eventRow.kind == 'craft' then
            tooltip[#tooltip + 1] = string.format('Profit: %s', M.Util:MoneyToString(eventRow.profit or 0))
            tooltip[#tooltip + 1] = string.format('Material cost: %s', M.Util:MoneyToString(eventRow.actualMaterialCost or 0))
            tooltip[#tooltip + 1] = string.format('Sale value: %s', M.Util:MoneyToString(eventRow.saleValue or 0))
        end
        self:AttachTooltip(row, subject or 'History Event', tooltip)
        y = y + ROW_HEIGHT + 2
    end

    self:FinishRender(#rows, y)
end

function UI:RefreshActiveTab()
    if not self.frame then
        return
    end

    self:UpdateFilterControlState()
    self:UpdateToolbarForTab()

    if self.frame.IsShellVisible and not self.frame:IsShellVisible() then
        if M.HUD then
            M.HUD:Refresh()
        end
        return
    end

    -- Clear the virtualization cache before each tab render. Renderers that
    -- support virtualization (currently RenderRecipes) re-populate it; other
    -- tab renderers leave it nil so the OnVerticalScroll hook no-ops.
    self._activeListCache = nil

    self:ClearRows()
    self:UpdateTabSelection()

    -- CR-006: only show the Queue tab's "Icons" toggle while the Queue tab
    -- is active. RenderQueue() ensures it exists and re-shows it.
    if self.queueIconsToggle and self.currentTab ~= "queue" then
        self.queueIconsToggle:Hide()
    end

    if self.currentTab == "recipes" then
        self:RenderRecipes()
    elseif self.currentTab == "queue" then
        self:RenderQueue()
    elseif self.currentTab == "materials" then
        self:RenderMaterials()
    elseif self.currentTab == "inventory" then
        self:RenderInventory()
    elseif self.currentTab == "advisor" then
        self:RenderAdvisor()
    elseif self.currentTab == "knowledge" then
        self:RenderKnowledge()
    elseif self.currentTab == "guide" then
        self:RenderGuide()
    elseif self.currentTab == "alts" then
        self:RenderAlts()
    elseif self.currentTab == "timers" then
        self:RenderTimers()
    elseif self.currentTab == "gearing" then
        self:RenderGearing()
    elseif self.currentTab == "profit" then
        self:RenderProfit()
    elseif self.currentTab == "trainers" then
        self:RenderTrainers()
    elseif self.currentTab == "data" then
        self:RenderData()
    else
        self:SetWindowStatus("Ready")
    end

    if M.HUD then
        M.HUD:Refresh()
    end
end

function UI:OpenToTab(tabKey)
    if not self.frame then
        self:Init()
    end
    if not self.frame then
        return
    end
    if M.settings.showProfitAnalysis == false and tabKey == "profit" then
        tabKey = "recipes"
    end
    self.currentTab = tabKey or self.currentTab or "recipes"
    if self.frame.ShowExpanded then
        self.frame:ShowExpanded()
    else
        self.frame:Show()
    end
    self:RefreshActiveTab()
end

function UI:Toggle(forceShow)
    -- Profile the first-open path end-to-end so /crafty profile can attribute
    -- the cost across Init / RefreshActiveTab / shell show.
    local toggleStart = (debugprofilestop and debugprofilestop()) or 0
    local firstOpen = (self.frame == nil)

    if not self.frame then
        _profileStep("UI:Toggle: UI:Init (first open)", function() self:Init() end)
    end
    if not self.frame then
        return
    end

    if self.frame.ToggleShell then
        self.frame:ToggleShell(forceShow)
        if not self.frame.IsShellVisible or self.frame:IsShellVisible() then
            _profileStep("UI:Toggle: RefreshActiveTab", function() self:RefreshActiveTab() end)
        end
    else
        if self.frame:IsShown() then
            self.frame:Hide()
        else
            self.frame:Show()
            _profileStep("UI:Toggle: RefreshActiveTab", function() self:RefreshActiveTab() end)
        end
    end

    if firstOpen then
        local elapsed = ((debugprofilestop and debugprofilestop()) or 0) - toggleStart
        if M and M._bootProfile then
            M._bootProfile[#M._bootProfile + 1] = { label = "UI:Toggle TOTAL (first open)", ms = elapsed, ok = true }
        end
        -- Auto-print the profile after the very first /crafty open so the
        -- user sees what's hot without typing /crafty profile.
        if M and M.PrintBootProfile and not M._bootProfilePrinted then
            M._bootProfilePrinted = true
            M:PrintBootProfile()
        end
    end
end

function UI:ShowExportDialog(mode)
    if not self.frame then
        self:Init()
    end
    if not self.frame then
        return
    end

    if not self.exportFrame then
        local frame = CreateFrame("Frame", "FabledUI_CraftyExportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(M.db.exportWindow.width or 760, M.db.exportWindow.height or 500)
        frame:SetPoint(M.db.exportWindow.point or "CENTER", UIParent, M.db.exportWindow.relativePoint or "CENTER", M.db.exportWindow.x or 0, M.db.exportWindow.y or 0)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetClampedToScreen(true)
        frame:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then
                self:StartMoving()
            end
        end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relativePoint, x, y = self:GetPoint(1)
            M.db.exportWindow.point = point
            M.db.exportWindow.relativePoint = relativePoint
            M.db.exportWindow.x = x
            M.db.exportWindow.y = y
            M:MarkDirty()
        end)
        frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        frame:SetBackdropColor(0.02, 0.02, 0.03, 0.95)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOPLEFT", 12, -12)
        if TK then
            TK:ApplyTitleText(frame.title)
        end

        frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.closeButton:SetPoint("TOPRIGHT", 0, 0)

        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 12, -36)
        scrollFrame:SetPoint("BOTTOMRIGHT", -32, 14)
        if scrollFrame.CharCount then
            scrollFrame.CharCount:Hide()
        end
        frame.scrollFrame = scrollFrame
        frame.editBox = scrollFrame.EditBox

        if not frame.editBox then
            frame.editBox = CreateFrame("EditBox", nil, scrollFrame)
            frame.editBox:SetMultiLine(true)
            frame.editBox:SetFontObject(ChatFontNormal)
            frame.editBox:SetWidth(680)
            scrollFrame:SetScrollChild(frame.editBox)
        end

        frame.editBox:SetMultiLine(true)
        frame.editBox:SetAutoFocus(false)
        frame.editBox:SetFontObject(ChatFontNormal)
        frame.editBox:SetWidth(680)
        frame.editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

        if TK then
            TK:ApplyPanel(frame, true)
        end

        self.exportFrame = frame
    end

    local text
    if mode == "history" then
        self.exportFrame.title:SetText("Crafty CSV Export")
        text = M.History:BuildCSV()
    elseif mode == "timers" then
        self.exportFrame.title:SetText("Crafty Timers Export")
        local function stripColors(s)
            s = tostring(s or "")
            s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
            s = s:gsub("|r", "")
            return s
        end
        local lines = { "Type,Character,Profession,Name,State,Charges,Next" }
        for _, row in ipairs((M.Timers and M.Timers.GetRows and M.Timers:GetRows()) or {}) do
            lines[#lines + 1] = string.format("%s,%s,%s,%s,%s,%s,%s",
                row.kind or "",
                M:GetShortCharacterName(row.characterKey),
                row.professionName or "",
                row.recipeName or "",
                stripColors(row.state),
                stripColors(row.charges),
                row.nextAt or "")
        end
        text = table.concat(lines, "\n")
    else
        self.exportFrame.title:SetText("Crafty Shopping List")
        text = M.Materials:BuildShoppingListText()
    end

    self.exportFrame.editBox:SetText(text or "")
    if self.exportFrame.editBox.HighlightText then
        self.exportFrame.editBox:HighlightText()
    end
    self.exportFrame:Show()
    self.exportFrame:SetFrameStrata("DIALOG")
end


