local M = _G.FabledUI_Crafty
M.Settings = M.Settings or {}
local S = M.Settings

-- TAINT SAFETY (2026-07-13): these helpers formerly used
-- Settings.RegisterAddOnSetting(category, key, variableKey, storageTable, ...)
-- with storageTable being a SavedVariable (M.settings / M.filters). Binding a
-- SavedVariable directly into the Settings framework taints the panel-commit
-- path — ExitWithCommit -> TransitionBackOpeningPanel -> ToggleGameMenu ->
-- ClearTarget() — producing the recurring "tried to call protected function
-- ClearTarget()" error and a tainted logout dialog. We now use
-- RegisterProxySetting with getter/setter closures, so our SavedVariable is
-- only ever read/written by our own insecure closures, never by the secure
-- settings-commit frame. Reference impl: FabledUI_Poseidon/Modules/Settings.lua.

local function readSetting(storageTable, variableKey, defaultValue)
    local v = storageTable[variableKey]
    if v == nil then
        return defaultValue
    end
    return v
end

local function registerBoolean(category, uniqueKey, variableKey, storageTable, name, tooltip, defaultValue, callback)
    local setting = Settings.RegisterProxySetting(category, uniqueKey, Settings.VarType.Boolean, name, defaultValue,
        function() return readSetting(storageTable, variableKey, defaultValue) and true or false end,
        function(value)
            storageTable[variableKey] = value
            if callback then
                callback(value)
            end
        end)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
end

local function registerSlider(category, uniqueKey, variableKey, storageTable, name, tooltip, defaultValue, minValue, maxValue, step, callback)
    local setting = Settings.RegisterProxySetting(category, uniqueKey, Settings.VarType.Number, name, defaultValue,
        function() return readSetting(storageTable, variableKey, defaultValue) end,
        function(value)
            storageTable[variableKey] = value
            if callback then
                callback(value)
            end
        end)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, setting, options, tooltip)
    return setting
end

local function registerStringDropdown(category, uniqueKey, variableKey, storageTable, name, tooltip, defaultValue, options, callback)
    local setting = Settings.RegisterProxySetting(category, uniqueKey, Settings.VarType.String, name, defaultValue,
        function() return readSetting(storageTable, variableKey, defaultValue) end,
        function(value)
            storageTable[variableKey] = value
            if callback then
                callback(value)
            end
        end)
    local function getOptions()
        local container = Settings.CreateControlTextContainer()
        for _, entry in ipairs(options) do
            container:Add(entry.value, entry.label)
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, setting, getOptions, tooltip)
    return setting
end

function S:Register()
    if self._registered then
        return
    end
    if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnCategory or not Settings.RegisterProxySetting or not Settings.CreateCheckbox then
        return
    end

    if M.EnsureStorageTables then
        M:EnsureStorageTables()
    end

    self._registered = true

    local category, layout = Settings.RegisterVerticalLayoutCategory("FabledUI Crafty")

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Crafty"))
    end

    -- CR-006b: global UI text/scale slider for the main Crafty window.
    -- Re-applies via UI:ApplyUIScale() so the change is visible immediately;
    -- a /reload is only required for users who want it to apply on cold start.
    registerSlider(category, M.ADDON_NAME .. "_uiScale", "uiScale", M.settings,
        "UI Text Scale",
        "Scales the main Crafty window (and all text inside it) for accessibility. Applies immediately; persists between sessions.",
        1.0, 0.85, 1.4, 0.05,
        function()
            M:SaveSettings()
            if M.UI and M.UI.ApplyUIScale then
                M.UI:ApplyUIScale()
            end
        end)

    registerBoolean(category, M.ADDON_NAME .. "_showAltKnowledge", "showAltKnowledge", M.settings,
        "Show Alt Knowledge", "Show alt recipe awareness in the main browser", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_showProfitAnalysis", "showProfitAnalysis", M.settings,
        "Show Goblin Tab", "Enable the profit analysis tab", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_groupByCharacter", "groupByCharacter", M.settings,
        "Group Queue by Character", "Keep queue rows grouped by the best crafter or assigned alt", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_pinHUD", "pinHUD", M.settings,
        "Pin Lumber HUD", "Keep the lumber radar HUD visible", false,
        function(value)
            M:SaveSettings()
            if M.HUD and M.HUD.frame then
                M.HUD.frame:SetShown(value and true or false)
                M.HUD:Refresh()
            end
        end)

    registerBoolean(category, M.ADDON_NAME .. "_searchMats", "searchMats", M.filters,
        "Search Materials", "Include material names in recipe search", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_readyOnly", "readyOnly", M.filters,
        "Ready Only", "Only show craftable recipes in the browser", false,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    -- ---------------------------------------------------------------------
    -- Modules — populated from M.Modules (ModuleRegistry.lua)
    -- ---------------------------------------------------------------------
    -- Crafty is a "suite within a suite": the core shell hosts a fleet of
    -- togglable modules. This section iterates the module catalog and
    -- renders one checkbox per module. Each module's settings entry lives
    -- in M.settings.modules[<key>] so legacy donor-named flags are
    -- already migrated by ModuleRegistry:MigrateLegacySettings.
    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Modules"))
    end

    if M.Modules and M.Modules.Each then
        M.settings.modules = M.settings.modules or {}
        local moduleStore = M.settings.modules
        for manifest in M.Modules:Each() do
            local label = manifest.label or manifest.key
            local desc = manifest.description or ""
            -- Annotate sibling-addon modules with a hint that toggling them
            -- on may auto-load (or require /reload) the LoD addon.
            if manifest.addonName then
                desc = desc .. " |cff888888[external addon: " .. manifest.addonName .. "]|r"
            end
            registerBoolean(
                category,
                M.ADDON_NAME .. "_module_" .. manifest.key,
                manifest.key,
                moduleStore,
                label,
                desc,
                manifest.defaultEnabled ~= false,
                function()
                    M:SaveSettings()
                    if M.Modules and M.Modules.SetEnabled then
                        -- SetEnabled handles EnsureLoaded for sibling addons
                        -- and the DataChanged fire.
                        M.Modules:SetEnabled(manifest.key, moduleStore[manifest.key] ~= false)
                    end
                end)
        end
    end

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tooltips"))
    end

    registerBoolean(category, M.ADDON_NAME .. "_tooltipProfessionIconsEnabled", "tooltipProfessionIconsEnabled", M.settings,
        "Show Profession Icons In Item Tooltips", "Icons mode for profession-use display. Combine with Profession Text Labels for BOTH mode.", true,
        function()
            if M.Tooltip and M.Tooltip.SetDisplayMode then
                local mode = ((M.settings.tooltipProfessionIconsEnabled ~= false) and (M.settings.tooltipProfessionTextEnabled == true)) and "BOTH" or ((M.settings.tooltipProfessionIconsEnabled ~= false) and "ICONS" or ((M.settings.tooltipProfessionTextEnabled == true) and "TEXT" or "OFF"))
                M.Tooltip:SetDisplayMode(mode)
            else
                M:SaveSettings()
            end
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipProfIncludeVendor", "tooltipProfIncludeVendor", M.settings,
        "Include Vendor Items", "Also show profession icons on vendor-purchased reagents and supplies.", true,
        function()
            if M.Tooltip and M.Tooltip.RebuildTextures then
                M.Tooltip:RebuildTextures()
            end
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipProfClassicIcons", "tooltipProfClassicIcons", M.settings,
        "Use Classic Profession Icons", "Switch tooltip profession icons to the donor addon's classic texture set.", false,
        function()
            if M.Tooltip and M.Tooltip.RebuildTextures then
                M.Tooltip:RebuildTextures()
            end
            M:SaveSettings()
        end)

    registerSlider(category, M.ADDON_NAME .. "_tooltipProfIconSize", "tooltipProfIconSize", M.settings,
        "Tooltip Profession Icon Size", "Adjust profession icon size in item tooltips.", 18, 8, 32, 1,
        function()
            -- P2-13: rebuild the cached texture array on size change.
            if M.Tooltip and M.Tooltip.RebuildTextures then
                M.Tooltip:RebuildTextures()
            end
            M:SaveSettings()
        end)

    -- P2-6: tooltip modifier-key gate. Default OFF preserves existing behavior.
    if pcall(function() return Settings.CreateDropdown end) and Settings.CreateDropdown then
        registerStringDropdown(category, M.ADDON_NAME .. "_tooltipModifier", "tooltipModifier", M.settings,
            "Tooltip Modifier Key",
            "Optionally only show Crafty's tooltip enrichment while a modifier is held.",
            "OFF",
            {
                { value = "OFF",   label = "Always Show" },
                { value = "SHIFT", label = "Shift" },
                { value = "CTRL",  label = "Ctrl" },
                { value = "ALT",   label = "Alt" },
            },
            function()
                M:SaveSettings()
            end)
    end

    if M.Tooltip and M.Tooltip.GetProfessionOptions then
        for _, info in ipairs(M.Tooltip:GetProfessionOptions()) do
            local variableKey = "tooltipProfFlag_" .. info.flag
            if M.settings[variableKey] == nil then
                M.settings[variableKey] = M.Tooltip:IsFlagEnabled(info.flag)
            end
            registerBoolean(category, M.ADDON_NAME .. "_" .. variableKey, variableKey, M.settings,
                "Tooltip: " .. info.label,
                "Allow the tooltip profession-icon feature to include " .. info.label .. ".",
                M.Tooltip:IsFlagEnabled(info.flag),
                function(value)
                    M.Tooltip:SetFilterFlag(info.flag, value)
                end)
        end
    end

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Gearing"))
    end

    registerBoolean(category, M.ADDON_NAME .. "_upgradeIconsOnTooltip", "upgradeIconsOnTooltip", M.settings,
        "Show Upgrade Track Icons In Tooltips", "Adds Explorer/Adventurer/Veteran/Champion/Hero/Myth markers to upgrade tooltip lines.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_upgradeIconsOnContainers", "upgradeIconsOnContainers", M.settings,
        "Show Upgrade Track Icons On Inventory And Bags", "Overlay upgrade-track icons on gear in character slots, bags, loot, bank, and flyouts.", false,
        function()
            M:SaveSettings()
            if M.UpgradeIcons then
                M.UpgradeIcons:RefreshAll()
            end
        end)

    registerSlider(category, M.ADDON_NAME .. "_upgradeIconScale", "upgradeIconScale", M.settings,
        "Upgrade Track Icon Scale", "Resize overlay icons for bag and equipment slots.", 1, 0.5, 1.5, 0.1,
        function()
            M:SaveSettings()
            if M.UpgradeIcons then
                M.UpgradeIcons:RefreshAll()
            end
        end)

    registerSlider(category, M.ADDON_NAME .. "_upgradeIconLocation", "upgradeIconLocation", M.settings,
        "Upgrade Icon Location", "1=TopLeft … 10=None. Matches the donor addon positioning grid.", 1, 1, 10, 1,
        function()
            M:SaveSettings()
            if M.UpgradeIcons then
                M.UpgradeIcons:RefreshAll()
            end
        end)

    registerSlider(category, M.ADDON_NAME .. "_upgradeIconOffsetX", "upgradeIconOffsetX", M.settings,
        "Upgrade Icon Horizontal Offset", "Move overlay icons left or right.", 1, -10, 10, 1,
        function()
            M:SaveSettings()
            if M.UpgradeIcons then
                M.UpgradeIcons:RefreshAll()
            end
        end)

    registerSlider(category, M.ADDON_NAME .. "_upgradeIconOffsetY", "upgradeIconOffsetY", M.settings,
        "Upgrade Icon Vertical Offset", "Move overlay icons up or down.", 1, -10, 10, 1,
        function()
            M:SaveSettings()
            if M.UpgradeIcons then
                M.UpgradeIcons:RefreshAll()
            end
        end)

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Knowledge + Guides"))
    end

    registerBoolean(category, M.ADDON_NAME .. "_knowledgeShowWeekly", "knowledgeShowWeekly", M.settings,
        "Show Weekly Knowledge Sources", "Include weekly quests, treatises, catch-up, and Darkmoon objectives in the Knowledge tab.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_knowledgeShowTreasure", "knowledgeShowTreasure", M.settings,
        "Show Treasure Sources", "Include one-time treasure knowledge items.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_knowledgeShowUnique", "knowledgeShowUnique", M.settings,
        "Show Unique Sources", "Include one-time vendor, renown, and hidden unique knowledge items.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_knowledgeShowFirstCraft", "knowledgeShowFirstCraft", M.settings,
        "Show First Craft Rows", "Enable the massive first-craft donor checklist in the Knowledge tab.", false,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_guideShowKnowledgeSources", "guideShowKnowledgeSources", M.settings,
        "Show Guide Knowledge Tips", "Include PTG knowledge-source notes above the leveling steps.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_guideShowAllSteps", "guideShowAllSteps", M.settings,
        "Show Full Retail Guide", "Display the full PTG step list instead of focusing around the current skill range.", false,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Donor Compare"))
    end

    registerBoolean(category, M.ADDON_NAME .. "_shoppingListModePSL", "shoppingListModePSL", M.settings,
        "Use PSL-Like Shopping Mode", "Keeps order/recraft-aware queue metadata and donor-style shopping compatibility paths.", false,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_useCraftSimQueuePlanner", "useCraftSimQueuePlanner", M.settings,
        "Use CraftSim-Like Queue Planner", "When enabled, queueing a recipe also tries to queue missing crafted subcomponents recursively.", false,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_useCraftSimProfitModel", "useCraftSimProfitModel", M.settings,
        "Use CraftSim-Like Profit Engine", "Switch the Goblin tab to recursive reagent costing and expected savings/extra-yield estimates.", false,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_profitUseSubcraftCost", "profitUseSubcraftCost", M.settings,
        "Profit: Use Subcraft Costs", "When the CraftSim-like engine is enabled, value crafted reagents by their producer recipes instead of raw market price.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_profitIncludeResourcefulness", "profitIncludeResourcefulness", M.settings,
        "Profit: Include Resourcefulness Savings", "Apply a donor-style expected savings estimate using tracked profession gear stats.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_autoDecrementQueueOnCraft", "autoDecrementQueueOnCraft", M.settings,
        "Auto-Decrement Queue On Craft", "When craft-result events are captured, reduce the most recent matching queue entry automatically.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_activityCraftLogEnabled", "activityCraftLogEnabled", M.settings,
        "Enable Craft Result Logging", "Capture TRADE_SKILL_ITEM_CRAFTED_RESULT events into the Data tab and CSV export.", true,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tokenTooltipDetailsEnabled", "tokenTooltipDetailsEnabled", M.settings,
        "Show Token Transmog Tooltip Data", "Adds raid, class-family, slot-family, and difficulty information for supported token items.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tokenTooltipOnlyForEligible", "tokenTooltipOnlyForEligible", M.settings,
        "Only Show Eligible Token Tooltips", "Hide token family details for tokens that do not match your current class.", false,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipExpansionInfoEnabled", "tooltipExpansionInfoEnabled", M.settings,
        "Show Expansion Era Text", "Adds an ItemEra-style expansion line to item tooltips.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipProfessionTextEnabled", "tooltipProfessionTextEnabled", M.settings,
        "Show Profession Text Labels", "Text mode for profession-use display. Combine with Profession Icons for BOTH mode.", false,
        function()
            if M.Tooltip and M.Tooltip.SetDisplayMode then
                local mode = ((M.settings.tooltipProfessionIconsEnabled ~= false) and (M.settings.tooltipProfessionTextEnabled == true)) and "BOTH" or ((M.settings.tooltipProfessionIconsEnabled ~= false) and "ICONS" or ((M.settings.tooltipProfessionTextEnabled == true) and "TEXT" or "OFF"))
                M.Tooltip:SetDisplayMode(mode)
            else
                M:SaveSettings()
            end
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipAssistanceEnabled", "tooltipAssistanceEnabled", M.settings,
        "Show Profession Assistance Tooltips", "Adds milling, prospecting, and disenchant helper lines to supported item tooltips.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipAssistanceLocationsEnabled", "tooltipAssistanceLocationsEnabled", M.settings,
        "Show Assistance Locations", "Adds source-zone information for herb and ore helper tooltips when donor data has locations.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipAssistanceShowIcons", "tooltipAssistanceShowIcons", M.settings,
        "Show Assistance Item Icons", "Adds item icons to Profession Assistance tooltip result rows.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipAssistanceMillingEnabled", "tooltipAssistanceMillingEnabled", M.settings,
        "Enable Milling Helper", "Shows herb milling outcome and pigment source helper data.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipAssistanceProspectingEnabled", "tooltipAssistanceProspectingEnabled", M.settings,
        "Enable Prospecting Helper", "Shows ore prospecting outcome and gem source helper data.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_tooltipAssistanceDisenchantEnabled", "tooltipAssistanceDisenchantEnabled", M.settings,
        "Enable Disenchant Helper", "Shows disenchant result/source helper data for supported items.", true,
        function()
            M:SaveSettings()
        end)

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Timers"))
    end

    registerBoolean(category, M.ADDON_NAME .. "_concentrationNotificationsEnabled", "concentrationNotificationsEnabled", M.settings,
        "Enable Full Concentration Notifications", "Shows a raid-warning style alert and sound when a tracked profession refills.", true,
        function()
            M:SaveSettings()
        end)

    registerSlider(category, M.ADDON_NAME .. "_concentrationForecastTarget", "concentrationForecastTarget", M.settings,
        "Forecast Target", "Used by the Timers tab to show who reaches the target first.", 1000, 1, 1000, 1,
        function()
            M:SaveSettings()
            M:Fire("DataChanged")
        end)

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Lumber & Farming"))
    end

    registerBoolean(category, M.ADDON_NAME .. "_farmAutoPauseEnabled", "farmAutoPauseEnabled", M.settings,
        "Auto-pause on AFK", "Pause farm session timing while AFK, in instances, or when the mailbox is open.", true,
        function()
            M:SaveSettings()
        end)

    registerBoolean(category, M.ADDON_NAME .. "_farmScanWarbandBank", "farmScanWarbandBank", M.settings,
        "Scan warband bank", "When the bank UI opens, count lumber items in your bank/warband bank into Lumber tab totals.", true,
        function()
            M:SaveSettings()
            if M.FarmSession and M.FarmSession.ScanBankForLumber then
                M.FarmSession:ScanBankForLumber()
            end
        end)

    Settings.RegisterAddOnCategory(category)
    M.categoryID = (category.GetID and category:GetID()) or category.ID or nil
end
