local N = FabledUI_Nemesis or Nemesis
N.Map = {}

local ICON_BY_TYPE = {
	rare = "Interface\\Minimap\\ObjectIconsAtlas",
	treasure = "Interface\\AddOns\\Blizzard_SharedMapDataProviders\\UI-WorldMapTreasureChest_64",
	event = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
}

local COLOR_BY_TYPE = {
	rare = { 1.0, 0.2, 0.8 },
	treasure = { 1.0, 0.82, 0.2 },
	event = { 0.3, 0.8, 1.0 },
	rep = { 0.2, 1.0, 0.2 },
}

local function AddLootLines(entityID)
	if not N.settings.showLootOnPins then
		return
	end
	local loot = N.Database:GetEntityLoot(entityID)
	if #loot == 0 then
		return
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Loot", 1, 0.82, 0)
	for i = 1, math.min(#loot, 6) do
		local itemID = loot[i]
		GameTooltip:AddLine(C_Item.GetItemInfo(itemID) or ("Item " .. tostring(itemID)), 1, 1, 1)
	end
end

local function ApplyColor(pin, data)
	if data.isRep and N.settings.highlightReputation then
		pin.texture:SetVertexColor(unpack(COLOR_BY_TYPE.rep))
		return
	end
	pin.texture:SetVertexColor(unpack(COLOR_BY_TYPE[data.type] or COLOR_BY_TYPE.rare))
end

local function CreateNemesisPin()
	local pin = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
	-- 12.x MapCanvas contract: pins are mixed with MapCanvasPinMixin (gives
	-- SetPosition / OnLoad / OnAcquired / SetOwningMap) and must NOT set
	-- OnEnter/OnLeave/OnClick scripts directly. AcquirePin asserts those scripts
	-- are nil, then wires the frame's OnEnter/OnLeave/OnMouseUp scripts to the
	-- pin's OnMouseEnter/OnMouseLeave/OnClick *methods* itself. Setting the
	-- scripts here is what tripped Blizzard_MapCanvas.lua:280 "assertion failed!".
	-- Stash the real C method before we shadow it with the no-op below.
	pin._origSetPassThroughButtons = pin.SetPassThroughButtons
	Mixin(pin, MapCanvasPinMixin)
	pin:SetSize(18, 18)
	pin:EnableMouse(true)

	-- 12.x taint guard. Blizzard's AcquirePin calls pin:CheckMouseButtonPassthrough
	-- (MapCanvas_DataProviderBase.lua:290), which calls the *protected*
	-- Frame:SetPassThroughButtons(). Protected functions are blocked for insecure
	-- callers while in combat lockdown, so any refresh that reaches AcquirePin from
	-- our own code during combat throws ADDON_ACTION_BLOCKED. Same workaround
	-- HandyNotes / Plumber / HereBeDragons use: shadow the method with a no-op so
	-- Blizzard's unconditional call is inert, and invoke the real one ourselves
	-- exactly once, only when out of combat.
	pin.SetPassThroughButtons = function() end

	-- Let right-click fall through to the map so Blizzard's right-click-to-zoom-out
	-- keeps working over our pins; left-click + hover stay ours.
	function pin:ApplyPassThrough()
		if self._passThroughApplied or InCombatLockdown() then
			return
		end
		local orig = self._origSetPassThroughButtons
		if orig then
			self._passThroughApplied = true
			orig(self, "RightButton")
		end
	end
	pin:ApplyPassThrough()

	pin.texture = pin:CreateTexture(nil, "ARTWORK")
	pin.texture:SetAllPoints()

	function pin:OnMouseEnter()
		if not self.entityData then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.entityData.displayName or self.entityData.name or ("Entity " .. tostring(self.entityID)))
		GameTooltip:AddLine(self.entityData.type == "treasure" and "Treasure" or self.entityData.type == "event" and "Event" or "Rare NPC", 0.85, 0.85, 0.85)
		if self.entityData.isRep then
			GameTooltip:AddLine("Awards reputation", 0.2, 1.0, 0.2)
		end
		if self.entityData.custom then
			GameTooltip:AddLine("Custom NPC", 0.4, 0.8, 1.0)
		end
		local sighting = N:GetSighting(self.entityID)
		if sighting then
			GameTooltip:AddLine("Seen: " .. tostring(sighting.count) .. " time(s)", 0.8, 0.8, 0.8)
		end
		GameTooltip:AddLine("Left-click: Manage", 0.75, 0.75, 0.75)
		AddLootLines(self.entityID)
		GameTooltip:Show()
	end

	function pin:OnMouseLeave()
		GameTooltip:Hide()
	end

	function pin:OnClick(button)
		if not self.entityID then
			return
		end
		if button == "RightButton" then
			N:SetEntitySuppressed(self.entityID, true, "all")
			return
		end
		N:OpenExplorer(self.entityID)
	end

	-- OnPinMouseUp (Blizzard's OnMouseUp wiring) calls pin:OnMouseUp before
	-- pin:OnClick, so these must exist to avoid a nil-call. Base map pins treat
	-- them as no-ops; we don't need any drag/press behavior.
	function pin:OnMouseUp() end
	function pin:OnMouseDown() end

	return pin
end

local function ResetNemesisPin(_, pin)
	pin:Hide()
	pin:ClearAllPoints()
	pin.entityID = nil
	pin.entityData = nil
end

function N.Map:CreatePinPool()
	if not WorldMapFrame or WorldMapFrame.pinPools["FabledUI_NemesisPin"] then
		return
	end

	-- 12.x (Midnight): world-map pins MUST come from an *unsecured region pool*
	-- so the map canvas can iterate them under secureexecuterange. A plain
	-- CreateObjectPool pin trips Blizzard_MapCanvas.lua:280 "assertion failed!"
	-- on every RefreshAllData (fires whenever the world map opens/changes).
	-- This mirrors HereBeDragons-Pins-2.0's 11.x+ path.
	local pool
	if CreateUnsecuredRegionPoolInstance then
		pool = CreateUnsecuredRegionPoolInstance("FabledUI_NemesisPin")
	else
		pool = CreateObjectPool(CreateNemesisPin, ResetNemesisPin)
	end

	pool.parent = WorldMapFrame:GetCanvas()
	pool.createFunc = CreateNemesisPin
	pool.resetFunc = ResetNemesisPin
	-- pre-11.x field names (harmless on modern clients)
	pool.creationFunc = CreateNemesisPin
	pool.resetterFunc = ResetNemesisPin

	WorldMapFrame.pinPools["FabledUI_NemesisPin"] = pool
end

function N.Map:Init()
	if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
		return
	end

	self:CreatePinPool()
	local provider = CreateFromMixins(MapCanvasDataProviderMixin)

	function provider:RefreshAllData()
		local map = self:GetMap()
		if not map then
			return
		end

		map:RemoveAllPinsByTemplate("FabledUI_NemesisPin")
		if not N.settings.enableMapPins then
			return
		end

		local mapID = map:GetMapID()
		if not mapID then
			return
		end

		for _, entityData in ipairs(N.Database:IterateEntitiesOnMap(mapID)) do
			if N:ShouldShowEntity(entityData.id, entityData.type, "map", entityData) then
				local pin = map:AcquirePin("FabledUI_NemesisPin")
				-- Retry for pins whose first acquire happened during combat lockdown.
				if pin.ApplyPassThrough then pin:ApplyPassThrough() end
				pin.entityID = entityData.id
				pin.entityData = entityData
				pin:SetPosition(entityData.x, entityData.y)
				pin.texture:SetTexture(ICON_BY_TYPE[entityData.type] or ICON_BY_TYPE.rare)
				ApplyColor(pin, entityData)
				pin:Show()
			end
		end
	end

	WorldMapFrame:AddDataProvider(provider)
	self.provider = provider
end

function N.Map:RefreshPins()
	if self.provider then
		self.provider:RefreshAllData()
	end
end
