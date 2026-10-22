local N = Nemesis
N.Settings = {}

local ADDON_SETTINGS_PREFIX = "FabledUI_Nemesis_"

local function RefreshViews()
	if N.Map then
		N.Map:RefreshPins()
	end
	if N.Explorer then
		N.Explorer:Refresh(false)
	end
end

-- TAINT SAFETY (2026-07-13): these controls formerly used
-- Settings.RegisterAddOnSetting bound to the SavedVariable N.settings
-- (FabledUI_NemesisSettings). Binding a SavedVariable into the Settings
-- framework taints the panel-commit path (ExitWithCommit -> ToggleGameMenu ->
-- ClearTarget()), the recurring protected-function / tainted-logout bug. We now
-- use RegisterProxySetting with getter/setter closures so the SavedVariable is
-- only ever touched by our own insecure code.
-- Reference impl: FabledUI_Poseidon/Modules/Settings.lua.
local function RegisterBooleanSetting(category, variableKey, displayName, tooltip)
	local default = N.settings[variableKey]
	if default == nil then default = false end
	local setting = Settings.RegisterProxySetting(
		category,
		ADDON_SETTINGS_PREFIX .. variableKey,
		type(false),
		displayName,
		default,
		function()
			local v = N.settings[variableKey]
			if v == nil then return false end
			return v
		end,
		function(value)
			N.settings[variableKey] = value
			N:PersistSettings()
			RefreshViews()
		end)

	return Settings.CreateCheckbox(category, setting, tooltip)
end

local function RegisterNestedBooleanSetting(category, tableKey, variableKey, displayName, tooltip)
	local variableTable = N.settings[tableKey]
	local default = variableTable[variableKey]
	if default == nil then default = false end
	local setting = Settings.RegisterProxySetting(
		category,
		ADDON_SETTINGS_PREFIX .. tableKey .. "_" .. variableKey,
		type(false),
		displayName,
		default,
		function()
			local v = variableTable[variableKey]
			if v == nil then return false end
			return v
		end,
		function(value)
			variableTable[variableKey] = value
			N:PersistSettings()
			RefreshViews()
		end)

	return Settings.CreateCheckbox(category, setting, tooltip)
end

function N.Settings:Register()
	if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterProxySetting then
		N:Print("Settings API unavailable.")
		return
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("FabledUI - Nemesis")
	Settings.RegisterAddOnCategory(category)
	N.CategoryID = category:GetID()

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Alerts"))
	RegisterBooleanSetting(category, "enableAlerts", "Enable alerts", "Show nearby entity alerts from vignettes.")
	RegisterBooleanSetting(category, "enableAudio", "Play audio on alert", "Play a warning sound when an alert appears.")
	RegisterBooleanSetting(category, "showLootOnAlert", "Show loot tooltip on alerts", "Show notable loot in the alert tooltip.")
	RegisterBooleanSetting(category, "showLootOnPins", "Show loot on map pins", "Include loot preview lines on world map pin tooltips.")

	-- ----------------------------------------------------------
	-- Sound packs (Feature 4)
	-- ----------------------------------------------------------
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Sound Packs"))

	-- Sound pack dropdown
	do
		local function GetOptions()
			local container = Settings.CreateControlTextContainer()
			container:Add("default", "Default", "Single legacy sound for every alert.")
			container:Add("variety", "Variety", "Different sounds for rares, treasures, and events.")
			container:Add("custom",  "Custom",  "User-supplied sound file paths per type.")
			return container:GetData()
		end

		local setting = Settings.RegisterProxySetting(
			category,
			ADDON_SETTINGS_PREFIX .. "soundPack",
			type(""),
			"Sound pack",
			N.settings.soundPack or "default",
			function() return N.settings.soundPack or "default" end,
			function(value)
				N.settings.soundPack = value
				N:PersistSettings()
			end)
		Settings.CreateDropdown(category, setting, GetOptions, "Choose which sound set is used for alerts.")
	end

	-- Per-channel volume sliders. Master applies on top of per-type.
	N.settings.volumes = N.settings.volumes or {}
	N.settings.volumes.master   = tonumber(N.settings.volumes.master)   or 0.7
	N.settings.volumes.rare     = tonumber(N.settings.volumes.rare)     or 1.0
	N.settings.volumes.treasure = tonumber(N.settings.volumes.treasure) or 1.0
	N.settings.volumes.event    = tonumber(N.settings.volumes.event)    or 1.0

	local function RegisterVolumeSlider(volKey, label, tooltip)
		local options = Settings.CreateSliderOptions(0, 1, 0.05)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
			return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
		end)
		local setting = Settings.RegisterProxySetting(
			category,
			ADDON_SETTINGS_PREFIX .. "volumes_" .. volKey,
			type(1.0),
			label,
			N.settings.volumes[volKey] or 1.0,
			function() return N.settings.volumes[volKey] or 1.0 end,
			function(value)
				N.settings.volumes[volKey] = value
				N:PersistSettings()
			end)
		Settings.CreateSlider(category, setting, options, tooltip)
	end

	RegisterVolumeSlider("master",   "Master volume",   "Multiplier applied to all Nemesis alert sounds.")
	RegisterVolumeSlider("rare",     "Rare volume",     "Volume for rare-NPC alerts.")
	RegisterVolumeSlider("treasure", "Treasure volume", "Volume for treasure / container alerts.")
	RegisterVolumeSlider("event",    "Event volume",    "Volume for event alerts.")

	-- Test buttons play each channel so the user can verify levels.
	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Test Rare Sound",
		"Play",
		function() if N.PlayAlertSound then N.PlayAlertSound("rare") end end,
		"Plays the rare alert sound at the current pack/volume.",
		true
	))
	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Test Treasure Sound",
		"Play",
		function() if N.PlayAlertSound then N.PlayAlertSound("treasure") end end,
		"Plays the treasure alert sound at the current pack/volume.",
		true
	))
	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Test Event Sound",
		"Play",
		function() if N.PlayAlertSound then N.PlayAlertSound("event") end end,
		"Plays the event alert sound at the current pack/volume.",
		true
	))

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Map"))
	RegisterBooleanSetting(category, "enableMapPins", "Enable world map pins", "Show tracked entities on the world map.")
	RegisterBooleanSetting(category, "highlightReputation", "Highlight reputation sources", "Tint reputation entities green on the map.")
	RegisterBooleanSetting(category, "showSuppressedInExplorer", "Show explorer-suppressed entities", "Keep explorer-hidden entities visible for management.")

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tracking Filters"))
	RegisterNestedBooleanSetting(category, "filters", "rares", "Track rares", "Enable rare NPC tracking.")
	RegisterNestedBooleanSetting(category, "filters", "treasures", "Track treasures", "Enable treasure and container tracking.")
	RegisterNestedBooleanSetting(category, "filters", "events", "Track events", "Enable event tracking.")
	RegisterNestedBooleanSetting(category, "filters", "reputation", "Track reputation sources", "Allow reputation-granting entities to appear.")
	RegisterNestedBooleanSetting(category, "filters", "custom", "Track custom NPCs", "Allow user-added custom NPC entries to appear.")

	-- ----------------------------------------------------------
	-- Respawn tracking (Feature 1)
	-- ----------------------------------------------------------
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Respawn Tracking"))

	N.settings.respawn = N.settings.respawn or {}
	if N.settings.respawn.autoClearStale == nil then
		N.settings.respawn.autoClearStale = true
	end
	if type(N.settings.respawn.staleThresholdDays) ~= "number" or N.settings.respawn.staleThresholdDays <= 0 then
		N.settings.respawn.staleThresholdDays = 7
	end

	do
		local setting = Settings.RegisterProxySetting(
			category,
			ADDON_SETTINGS_PREFIX .. "respawn_autoClearStale",
			type(false),
			"Auto-clear stale sightings",
			N.settings.respawn.autoClearStale,
			function()
				local v = N.settings.respawn.autoClearStale
				if v == nil then return true end
				return v
			end,
			function(value)
				N.settings.respawn.autoClearStale = value
				N:PersistSettings()
				if N.Respawn and value then
					N.Respawn:CleanupStaleSightings(true)
				end
				RefreshViews()
			end)
		Settings.CreateCheckbox(category, setting, "Auto-prune sightings older than the threshold for short-cycle rares.")
	end

	do
		local options = Settings.CreateSliderOptions(1, 30, 1)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
			return string.format("%d day%s", value, value == 1 and "" or "s")
		end)
		local setting = Settings.RegisterProxySetting(
			category,
			ADDON_SETTINGS_PREFIX .. "respawn_staleThresholdDays",
			type(1),
			"Stale threshold (days)",
			N.settings.respawn.staleThresholdDays,
			function() return N.settings.respawn.staleThresholdDays or 7 end,
			function(value)
				N.settings.respawn.staleThresholdDays = value
				N:PersistSettings()
				if N.Respawn and N.settings.respawn.autoClearStale then
					N.Respawn:CleanupStaleSightings(true)
				end
			end)
		Settings.CreateSlider(category, setting, options, "How long without a sighting before a short-cycle rare is auto-cleared.")
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Utilities"))
	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Nemesis Explorer",
		"Open Explorer",
		function() N:OpenExplorer() end,
		"Open the Explorer management window.",
		true
	))

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Reset Explorer Filters",
		"Reset Explorer State",
		function()
			N.settings.explorer.search = ""
			N.settings.explorer.filterMode = "all"
			N.settings.explorer.onlyVisible = false
			N.settings.explorer.showSeenOnly = false
			N.settings.explorer.sortMode = "recent"
			N:PersistSettings()
			if N.Explorer then
				N.Explorer.searchText = ""
				N.Explorer.filterMode = "all"
				N.Explorer.onlyVisible = false
				N.Explorer.showSeenOnly = false
				N.Explorer.sortMode = "recent"
				if N.Explorer.frame and N.Explorer.frame.searchBox then
					N.Explorer.frame.searchBox:SetText("")
				end
				N.Explorer:Refresh(false)
			end
		end,
		"Reset search, filters, and sorting in Explorer.",
		true
	))

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Clear Suppression",
		"Unsuppress All Entities",
		function()
			wipe(N.db.entityRules)
			N:MarkShardDirty()
			RefreshViews()
			N:Print("Cleared all entity suppression rules.")
		end,
		"Remove all per-entity suppression rules.",
		true
	))
end
