local N = Nemesis

local SHARD_KEY = "FabledUI_DataVault_Nemesis"
local ADDON_KEY = "nemesis"

local DEFAULTS = {
	settings = {
		enableAlerts = true,
		enableAudio = true,
		enableMapPins = true,
		showLootOnAlert = true,
		showLootOnPins = true,
		highlightReputation = true,
		showSuppressedInExplorer = false,
		scale = 1.0,
		filters = {
			rares = true,
			treasures = true,
			events = true,
			reputation = true,
			custom = true,
		},
		explorer = {
			search = "",
			filterMode = "all",
			onlyVisible = false,
			showSeenOnly = false,
			sortMode = "recent",
		},
	},
	db = {
		history = {},
		customNPCs = {},
		killed = {},
		entityRules = {},
		sightings = {},
		window = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = 0,
			width = 1140,
			height = 700,
			scale = 1,
			alpha = 1,
			displayState = "expanded",
			ribbonPoint = "TOP",
			ribbonRelativePoint = "TOP",
			ribbonX = 0,
			ribbonY = -180,
			ribbonWidth = 280,
			ribbonHeight = 24,
		},
		meta = {
			schemaVersion = 5,
		},
	},
}

local function DeepCopy(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = DeepCopy(value)
	end
	return copy
end

local function EnsureTable(parent, key)
	if type(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

function N:MarkShardDirty()
	if DataVault and type(DataVault.dirtyFlags) == "table" then
		DataVault.dirtyFlags[SHARD_KEY] = true
	end
end

function N:PersistSettings()
	if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
		DataVault:Set("account", ADDON_KEY, "settings", self.settings)
	end
end

function N:ResolveStorage()
	if DataVault and DataVault.ShardAvailable and DataVault:ShardAvailable(SHARD_KEY) then
		self.db = DataVault:ShardGet("account", SHARD_KEY, ADDON_KEY, nil, DeepCopy(DEFAULTS.db))
	else
		_G.FabledUI_NemesisDB = _G.FabledUI_NemesisDB or DeepCopy(DEFAULTS.db)
		self.db = _G.FabledUI_NemesisDB
	end

	if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
		DataVault:EnsureNamespace(ADDON_KEY)
		if not DataVault:Get("account", ADDON_KEY, "settings", nil) then
			DataVault:Set("account", ADDON_KEY, "settings", DeepCopy(DEFAULTS.settings))
		end
		self.settings = DataVault:Get("account", ADDON_KEY, "settings", DeepCopy(DEFAULTS.settings))
	else
		_G.FabledUI_NemesisSettings = _G.FabledUI_NemesisSettings or DeepCopy(DEFAULTS.settings)
		self.settings = _G.FabledUI_NemesisSettings
	end

	self.db.history = self.db.history or {}
	self.db.customNPCs = self.db.customNPCs or {}
	self.db.killed = self.db.killed or {}
	self.db.meta = self.db.meta or {}
	self.db.entityRules = self.db.entityRules or {}
	self.db.sightings = self.db.sightings or {}
	self.db.respawn = self.db.respawn or {}
	self.db.charPrefs = self.db.charPrefs or {}
	self.db.window = self.db.window or DeepCopy(DEFAULTS.db.window)

	self.settings.filters = self.settings.filters or {}
	self.settings.explorer = self.settings.explorer or {}

	-- ----------------------------------------------------------
	-- Sound pack defaults (Feature 4)
	-- ----------------------------------------------------------
	if type(self.settings.soundPack) ~= "string" then
		self.settings.soundPack = "default"
	end
	if type(self.settings.volumes) ~= "table" then
		self.settings.volumes = {}
	end
	local v = self.settings.volumes
	v.master   = tonumber(v.master)   or 0.7
	v.rare     = tonumber(v.rare)     or 1.0
	v.treasure = tonumber(v.treasure) or 1.0
	v.event    = tonumber(v.event)    or 1.0
	if type(self.settings.customSounds) ~= "table" then
		self.settings.customSounds = {}
	end
	local cs = self.settings.customSounds
	cs.rare     = tostring(cs.rare     or "Sound\\Interface\\RaidWarning.ogg")
	cs.treasure = tostring(cs.treasure or "Sound\\Interface\\AuctionWindowOpen.ogg")
	cs.event    = tostring(cs.event    or "Sound\\Interface\\LevelUp.ogg")

	self.settings.filters.rares = self.settings.filters.rares ~= false
	self.settings.filters.treasures = self.settings.filters.treasures ~= false
	self.settings.filters.events = self.settings.filters.events ~= false
	self.settings.filters.reputation = self.settings.filters.reputation ~= false
	self.settings.filters.custom = self.settings.filters.custom ~= false
	self.settings.showLootOnPins = self.settings.showLootOnPins ~= false
	self.settings.showSuppressedInExplorer = self.settings.showSuppressedInExplorer == true
	self.settings.explorer.search = tostring(self.settings.explorer.search or "")
	self.settings.explorer.filterMode = tostring(self.settings.explorer.filterMode or "all")
	self.settings.explorer.onlyVisible = self.settings.explorer.onlyVisible == true
	self.settings.explorer.showSeenOnly = self.settings.explorer.showSeenOnly == true
	self.settings.explorer.sortMode = tostring(self.settings.explorer.sortMode or "recent")

	self.db.window.point = tostring(self.db.window.point or "CENTER")
	self.db.window.relativePoint = tostring(self.db.window.relativePoint or "CENTER")
	self.db.window.x = tonumber(self.db.window.x) or 0
	self.db.window.y = tonumber(self.db.window.y) or 0
	self.db.window.width = tonumber(self.db.window.width) or 1140
	self.db.window.height = tonumber(self.db.window.height) or 700
	self.db.window.scale = tonumber(self.db.window.scale) or 1
	self.db.window.alpha = tonumber(self.db.window.alpha) or 1
	self.db.window.displayState = tostring(self.db.window.displayState or "expanded")
	self.db.window.ribbonPoint = tostring(self.db.window.ribbonPoint or "TOP")
	self.db.window.ribbonRelativePoint = tostring(self.db.window.ribbonRelativePoint or "TOP")
	self.db.window.ribbonX = tonumber(self.db.window.ribbonX) or 0
	self.db.window.ribbonY = tonumber(self.db.window.ribbonY) or -180
	self.db.window.ribbonWidth = tonumber(self.db.window.ribbonWidth) or 280
	self.db.window.ribbonHeight = tonumber(self.db.window.ribbonHeight) or 24

	self:MigrateStorage()
end

function N:MigrateStorage()
	self.db.meta.schemaVersion = tonumber(self.db.meta.schemaVersion) or 1

	if type(self.db.filteredEntities) == "table" then
		for entityID, isFiltered in pairs(self.db.filteredEntities) do
			if isFiltered then
				local rule = EnsureTable(self.db.entityRules, tonumber(entityID))
				rule.all = true
			end
		end
		self.db.filteredEntities = nil
		self.db.meta.schemaVersion = 2
		self:MarkShardDirty()
	end

	if self.db.meta.schemaVersion < 3 then
		self.db.sightings = self.db.sightings or {}
		self.db.meta.schemaVersion = 3
		self:MarkShardDirty()
	end

	if self.db.meta.schemaVersion < 4 then
		self.settings.explorer = self.settings.explorer or {}
		self.settings.explorer.sortMode = self.settings.explorer.sortMode or "recent"
		self.db.meta.schemaVersion = 4
		self:PersistSettings()
		self:MarkShardDirty()
	end

	if self.db.meta.schemaVersion < 5 then
		self.db.window = self.db.window or DeepCopy(DEFAULTS.db.window)
		self.db.meta.schemaVersion = 5
		self:MarkShardDirty()
	end
end

function N:GetEntityRule(entityID)
	entityID = tonumber(entityID)
	if not entityID then
		return nil
	end

	local rule = self.db.entityRules[entityID]
	if type(rule) ~= "table" then
		rule = {}
		self.db.entityRules[entityID] = rule
	end

	return rule
end

function N:IsEntitySuppressed(entityID, channel)
	entityID = tonumber(entityID)
	if not entityID then
		return false
	end

	local rule = self.db.entityRules[entityID]
	if type(rule) ~= "table" then
		return false
	end

	if rule.all == true then
		return true
	end

	if channel and rule[channel] == true then
		return true
	end

	return false
end

function N:SetEntitySuppressed(entityID, state, channel)
	entityID = tonumber(entityID)
	if not entityID then
		return
	end

	channel = channel or "all"
	local rule = self:GetEntityRule(entityID)
	if not rule then
		return
	end

	if state then
		rule[channel] = true
	else
		rule[channel] = nil
	end

	if not next(rule) then
		self.db.entityRules[entityID] = nil
	end

	self:MarkShardDirty()
	self:RefreshAll()
end

function N:IsTypeEnabled(typeKey)
	local filters = self.settings.filters or {}
	if typeKey == "rare" then
		return filters.rares ~= false
	elseif typeKey == "treasure" then
		return filters.treasures ~= false
	elseif typeKey == "event" then
		return filters.events ~= false
	end
	return true
end

function N:SetTypeEnabled(typeKey, state)
	local filters = self.settings.filters or {}
	if typeKey == "rare" then
		filters.rares = state and true or false
	elseif typeKey == "treasure" then
		filters.treasures = state and true or false
	elseif typeKey == "event" then
		filters.events = state and true or false
	end

	self.settings.filters = filters
	self:PersistSettings()
	self:RefreshAll()
end

function N:ShouldShowEntity(entityID, entityType, channel, entityData)
	if not entityID then
		return false
	end

	if entityType and not self:IsTypeEnabled(entityType) then
		return false
	end

	if entityData and entityData.isRep and self.settings.filters.reputation == false then
		return false
	end

	if entityData and entityData.custom and self.settings.filters.custom == false then
		return false
	end

	if self:IsEntitySuppressed(entityID, "all") then
		return false
	end

	if channel and self:IsEntitySuppressed(entityID, channel) then
		return false
	end

	return true
end

function N:AddCustomNPC(npcID, name)
	npcID = tonumber(npcID)
	if not npcID or type(name) ~= "string" or name == "" then
		return false
	end

	self.db.customNPCs[npcID] = name
	self:MarkShardDirty()
	return true
end

function N:RemoveCustomNPC(npcID)
	npcID = tonumber(npcID)
	if not npcID or self.db.customNPCs[npcID] == nil then
		return false
	end

	self.db.customNPCs[npcID] = nil
	self.db.sightings[npcID] = nil
	self.db.entityRules[npcID] = nil
	self:MarkShardDirty()
	return true
end

function N:RecordSighting(entityID, source, mapID)
	entityID = tonumber(entityID)
	if not entityID then
		return
	end

	local sighting = EnsureTable(self.db.sightings, entityID)
	sighting.count = (tonumber(sighting.count) or 0) + 1
	sighting.lastSeen = time()
	sighting.source = source or sighting.source or "unknown"
	sighting.mapID = mapID or sighting.mapID
	self:MarkShardDirty()
end

function N:GetSighting(entityID)
	entityID = tonumber(entityID)
	if not entityID then
		return nil
	end
	return self.db.sightings[entityID]
end

function N:GetRecentSightings(limit)
	limit = tonumber(limit) or 5
	local results = {}

	for entityID, sighting in pairs(self.db.sightings or {}) do
		if type(sighting) == "table" and tonumber(sighting.lastSeen) then
			results[#results + 1] = {
				entityID = tonumber(entityID),
				count = tonumber(sighting.count) or 0,
				lastSeen = tonumber(sighting.lastSeen) or 0,
				source = sighting.source,
				mapID = sighting.mapID,
			}
		end
	end

	table.sort(results, function(a, b)
		if a.lastSeen == b.lastSeen then
			return (a.entityID or 0) < (b.entityID or 0)
		end
		return a.lastSeen > b.lastSeen
	end)

	while #results > limit do
		table.remove(results)
	end

	return results
end

function N:SetExplorerPref(key, value)
	self.settings.explorer[key] = value
	self:PersistSettings()
end

function N:IsEntityAudioMuted(entityID)
	entityID = tonumber(entityID)
	if not entityID then return false end
	local rule = self.db.entityRules[entityID]
	return type(rule) == "table" and rule.muteAudio == true
end

function N:SetEntityAudioMuted(entityID, state)
	entityID = tonumber(entityID)
	if not entityID then return end
	local rule = self:GetEntityRule(entityID)
	if not rule then return end
	rule.muteAudio = state and true or nil
	if not next(rule) then
		self.db.entityRules[entityID] = nil
	end
	self:MarkShardDirty()
	self:RefreshAll()
end

-- ----------------------------------------------------------
-- Per-character preferences (Feature 2: quest-gated filter etc.)
-- ----------------------------------------------------------
function N:GetCharKey()
	local name = UnitName and UnitName("player") or "Unknown"
	local realm = GetRealmName and GetRealmName() or "Unknown"
	return tostring(name) .. "-" .. tostring(realm)
end

function N:GetCharPrefs()
	self.db.charPrefs = self.db.charPrefs or {}
	local key = self:GetCharKey()
	if type(self.db.charPrefs[key]) ~= "table" then
		self.db.charPrefs[key] = {}
	end
	return self.db.charPrefs[key]
end

function N:GetCharPref(key, default)
	local prefs = self:GetCharPrefs()
	if prefs[key] == nil then
		return default
	end
	return prefs[key]
end

function N:SetCharPref(key, value)
	local prefs = self:GetCharPrefs()
	prefs[key] = value
	self:MarkShardDirty()
end

function N:IsEntityVisualMuted(entityID)
	entityID = tonumber(entityID)
	if not entityID then return false end
	local rule = self.db.entityRules[entityID]
	return type(rule) == "table" and rule.muteVisual == true
end

function N:SetEntityVisualMuted(entityID, state)
	entityID = tonumber(entityID)
	if not entityID then return end
	local rule = self:GetEntityRule(entityID)
	if not rule then return end
	rule.muteVisual = state and true or nil
	if not next(rule) then
		self.db.entityRules[entityID] = nil
	end
	self:MarkShardDirty()
	self:RefreshAll()
end
