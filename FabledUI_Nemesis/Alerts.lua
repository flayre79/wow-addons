local N = FabledUI_Nemesis or Nemesis
N.Alerts = {}
local A = N.Alerts

local alertFrame
local recentAlerts = {}

local ICONS = {
	rare = "Interface\\Icons\\Achievement_Boss_Archimonde",
	treasure = "Interface\\Icons\\INV_Misc_Chest_01",
	event = "Interface\\Icons\\INV_Misc_Note_01",
}

local TYPE_LABELS = {
	rare = "Rare NPC",
	treasure = "Treasure",
	event = "Event",
}

local function TypeLabel(typeKey)
	return TYPE_LABELS[typeKey] or "Entity"
end

-- ----------------------------------------------------------
-- Sound pack dispatcher (Feature 4)
--
-- Picks a file based on N.settings.soundPack:
--   "default" -> single legacy soundID for everything
--   "variety" -> different per-type Blizzard sound files
--   "custom"  -> user-supplied path per type (settings.customSounds.<type>)
--
-- Volume = settings.volumes.master * settings.volumes[<type>], clamped
-- to [0, 1]. The Sound_MasterVolume CVar still applies on top of this
-- because PlaySoundFile honors it.
-- ----------------------------------------------------------

local SOUND_PACKS = {
	-- Single-file pack: all alerts play the same sound (legacy behavior).
	default = {
		rare     = "Sound\\Interface\\RaidWarning.ogg",
		treasure = "Sound\\Interface\\RaidWarning.ogg",
		event    = "Sound\\Interface\\RaidWarning.ogg",
	},
	-- Per-type sound files for easier audio identification.
	variety = {
		rare     = "Sound\\Creature\\AlgalonTheObserver\\UR_Algalon_Aggro01.ogg",
		treasure = "Sound\\Interface\\AuctionWindowOpen.ogg",
		event    = "Sound\\Interface\\LevelUp.ogg",
	},
}

local LEGACY_DEFAULT_SOUND_ID = 12867

local function ClampVolume(v)
	v = tonumber(v) or 1.0
	if v < 0 then return 0 end
	if v > 1 then return 1 end
	return v
end

local function ResolveSoundFile(entityType)
	entityType = entityType or "rare"
	local pack = (N.settings and N.settings.soundPack) or "default"

	if pack == "custom" then
		local cs = N.settings.customSounds or {}
		return cs[entityType] or cs.rare
	end

	local table = SOUND_PACKS[pack] or SOUND_PACKS.default
	return table[entityType] or table.rare
end

local function PlayAlertSound(entityType)
	if not (N.settings and N.settings.enableAudio) then return end

	local volumes = N.settings.volumes or {}
	local master  = ClampVolume(volumes.master)
	local perType = ClampVolume(volumes[entityType or "rare"])
	local effective = master * perType

	if effective <= 0 then return end

	-- "default" pack falls back to the legacy PlaySound id when no
	-- override is set, so existing users hear the exact same alert.
	if (N.settings.soundPack or "default") == "default" and not (N.settings.customSounds and N.settings.customSounds[entityType or "rare"]) then
		-- PlaySound() doesn't take a volume arg; use PlaySoundFile if
		-- the user has tuned volumes off the default 1.0.
		if effective < 0.99 then
			PlaySoundFile(SOUND_PACKS.default[entityType or "rare"], "Master")
		else
			PlaySound(LEGACY_DEFAULT_SOUND_ID)
		end
		return
	end

	local file = ResolveSoundFile(entityType)
	if not file or file == "" then return end

	-- PlaySoundFile honors Sound_MasterVolume CVar. The "Master" channel
	-- ensures alerts aren't gated by the music/sfx mute toggle.
	if type(file) == "number" then
		PlaySound(file, "Master")
	else
		PlaySoundFile(file, "Master")
	end
end

N.PlayAlertSound = PlayAlertSound

local function AddLootTooltipLines(entityID)
	if not N.settings.showLootOnAlert then
		return
	end

	local loot = N.Database:GetEntityLoot(entityID)
	if #loot == 0 then
		return
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Loot", 1, 0.82, 0)
	for i = 1, math.min(#loot, 8) do
		local itemID = loot[i]
		GameTooltip:AddLine(C_Item.GetItemInfo(itemID) or ("Item " .. tostring(itemID)), 1, 1, 1)
	end
end

local function ShowAlertTooltip(owner, entityID, entityData)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(entityData and (entityData.displayName or entityData.name) or ("Entity " .. tostring(entityID)))
	GameTooltip:AddLine(TypeLabel(entityData and entityData.type or "rare"), 0.85, 0.85, 0.85)
	if entityData and entityData.isRep then
		GameTooltip:AddLine("Awards reputation", 0.2, 1, 0.2)
	end
	if entityData and entityData.custom then
		GameTooltip:AddLine("Custom NPC", 0.4, 0.8, 1)
	end

	local sighting = N:GetSighting(entityID)
	if sighting then
		GameTooltip:AddLine("Seen: " .. tostring(sighting.count) .. " time(s)", 0.8, 0.8, 0.8)
	end

	AddLootTooltipLines(entityID)
	GameTooltip:Show()
end

local function StyleButton(button)
	local T = rawget(_G, "FabledUI_UIToolkit")
	if T and T.Themes and T.Themes.StyleFlatButton then
		T.Themes:StyleFlatButton(button, "FableNeon", { 0.860, 0.290, 0.360, 1.0 })
	end
end

local function CreateActionButton(parent, width, text, point, relativeTo, relativePoint, x, y, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 20)
	button:SetPoint(point, relativeTo, relativePoint, x, y)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	StyleButton(button)
	return button
end

local function CreateAlertUI()
	if alertFrame then
		return
	end

	alertFrame = CreateFrame("Frame", "FabledUI_NemesisAlert", UIParent, "BackdropTemplate")
	alertFrame:SetSize(350, 118)
	alertFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
	alertFrame:SetFrameStrata("HIGH")
	alertFrame:SetMovable(true)
	alertFrame:EnableMouse(true)
	alertFrame:RegisterForDrag("LeftButton")
	alertFrame:SetClampedToScreen(true)
	alertFrame:SetBackdrop({
		bgFile = "Interface/ChatFrame/ChatFrameBackground",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	alertFrame:SetBackdropColor(0.08, 0.08, 0.12, 0.94)
	alertFrame:SetBackdropBorderColor(1, 0.2, 0.8, 1)
	alertFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	alertFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	alertFrame.icon = alertFrame:CreateTexture(nil, "ARTWORK")
	alertFrame.icon:SetSize(42, 42)
	alertFrame.icon:SetPoint("TOPLEFT", 14, -16)

	alertFrame.title = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	alertFrame.title:SetPoint("TOPLEFT", alertFrame.icon, "TOPRIGHT", 10, -2)
	alertFrame.title:SetPoint("RIGHT", -14, 0)
	alertFrame.title:SetJustifyH("LEFT")

	alertFrame.desc = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	alertFrame.desc:SetPoint("TOPLEFT", alertFrame.title, "BOTTOMLEFT", 0, -6)
	alertFrame.desc:SetPoint("RIGHT", -14, 0)
	alertFrame.desc:SetJustifyH("LEFT")

	alertFrame.closeButton = CreateFrame("Button", nil, alertFrame, "UIPanelCloseButton")
	alertFrame.closeButton:SetPoint("TOPRIGHT", -4, -4)

	alertFrame.manageButton = CreateActionButton(alertFrame, 76, "Manage", "BOTTOMLEFT", alertFrame, "BOTTOMLEFT", 12, 10, function(self)
		local parent = self:GetParent()
		if parent.entityID then
			N:OpenExplorer(parent.entityID)
		end
	end)

	alertFrame.alertMuteButton = CreateActionButton(alertFrame, 84, "Mute Alert", "LEFT", alertFrame.manageButton, "RIGHT", 6, 0, function(self)
		local parent = self:GetParent()
		if parent.entityID then
			N:SetEntitySuppressed(parent.entityID, true, "alert")
			parent:Hide()
		end
	end)

	alertFrame.ignoreButton = CreateActionButton(alertFrame, 88, "Ignore All", "LEFT", alertFrame.alertMuteButton, "RIGHT", 6, 0, function(self)
		local parent = self:GetParent()
		if parent.entityID then
			N:SetEntitySuppressed(parent.entityID, true, "all")
			parent:Hide()
		end
	end)

	alertFrame:SetScript("OnEnter", function(self)
		if self.entityID and self.entityData then
			ShowAlertTooltip(self, self.entityID, self.entityData)
		end
	end)
	alertFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	alertFrame:Hide()
end

local function InferEntityType(vignetteObjectType, entityID)
	local data = N.Database:GetEntityData(entityID)
	if data then
		return data.type, data
	end

	if vignetteObjectType == "GameObject" then
		return "treasure", nil
	end
	if vignetteObjectType == "Creature" or vignetteObjectType == "Vehicle" then
		return "rare", nil
	end
	return "event", nil
end

function A:TriggerAlert(entityID, entityName, entityType, entityData, mapID)
	if not N.settings.enableAlerts then
		return
	end
	if not N:ShouldShowEntity(entityID, entityType, "alert", entityData) then
		return
	end

	local now = time()
	if recentAlerts[entityID] and (now - recentAlerts[entityID]) < 300 then
		return
	end
	recentAlerts[entityID] = now
	N:RecordSighting(entityID, "alert", mapID)
	if N.Respawn and N.Respawn.RecordSighting then
		N.Respawn:RecordSighting(entityID, mapID)
	end

	CreateAlertUI()
	alertFrame.entityID = entityID
	alertFrame.entityData = entityData or N.Database:GetEntityData(entityID) or {
		id = entityID,
		name = entityName,
		displayName = entityName,
		type = entityType,
	}

	alertFrame.icon:SetTexture(ICONS[entityType] or ICONS.rare)
	alertFrame.title:SetText(entityName or N.Database:GetEntityName(entityID))

	local desc = "Found: " .. TypeLabel(entityType)
	if entityData and entityData.isRep and N.settings.highlightReputation then
		desc = desc .. " |cff00ff00(Reputation)|r"
	end
	if entityData and entityData.custom then
		desc = desc .. " |cff66ccff(Custom)|r"
	end
	alertFrame.desc:SetText(desc)
	alertFrame:SetScale(N.settings.scale or 1.0)
	if not N:IsEntityVisualMuted(entityID) then
		alertFrame:Show()
	end
	if not N:IsEntityAudioMuted(entityID) then
		PlayAlertSound(entityType)
	end

	C_Timer.After(15, function()
		if alertFrame and alertFrame:IsShown() and alertFrame.entityID == entityID then
			alertFrame:Hide()
		end
	end)
end

function A:HandleVignette(vignetteGUID)
	if not vignetteGUID then
		return
	end

	local info = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
	if not info or not info.objectGUID then
		return
	end

	local objectType, _, _, _, entityID = strsplit("-", info.objectGUID)
	entityID = tonumber(entityID)
	if not entityID then
		return
	end

	-- First vignette match in the session triggers the LoD data pack so the
	-- alert can name and classify imported rares. Subsequent calls are a
	-- no-op thanks to the _dataLoaded flag.
	if N.EnsureDataLoaded then
		N:EnsureDataLoaded()
	end

	local entityType, entityData = InferEntityType(objectType, entityID)
	local entityName = info.name or (entityData and entityData.displayName) or (entityData and entityData.name) or ("Entity " .. tostring(entityID))
	-- Vignettes carry their own mapID — prefer it so cross-zone sightings
	-- (e.g. an alert fired while you're scouting a neighbouring map) record
	-- the vignette's actual location rather than the player's. Falls back
	-- to the player's current map when the vignette payload omits mapID,
	-- which still beats the previous "nil unless atlasName is set" guard
	-- that silently dropped mapID for atlas-less vignettes.
	local mapID = info.mapID
	if not mapID and C_Map and C_Map.GetBestMapForUnit then
		mapID = C_Map.GetBestMapForUnit("player")
	end
	self:TriggerAlert(entityID, entityName, entityType, entityData, mapID)
end

function A:Init()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
	local _alertsErrCount = 0
	frame:SetScript("OnEvent", function(_, event, vignetteGUID)
		local ok, err = pcall(function()
			if event == "VIGNETTE_MINIMAP_UPDATED" then
				self:HandleVignette(vignetteGUID)
			end
		end)
		if not ok then
			_alertsErrCount = _alertsErrCount + 1
			if _alertsErrCount <= 3 then
				print("|cffff5555[Nemesis.Alerts]|r " .. tostring(err))
			end
		end
	end)
end
