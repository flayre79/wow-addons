local N = Nemesis
N.Explorer = {}

local ROW_HEIGHT = 22
local VISIBLE_ROWS = 15
local RECENT_ROWS = 5
local TOOLKIT_THEME = "FableNeon"
local TOOLKIT_ACCENT = { 0.860, 0.290, 0.360, 1.0 }

local function Lower(value)
	return type(value) == "string" and value:lower() or ""
end

local function FormatType(entityType)
	if entityType == "treasure" then
		return "Treasure"
	elseif entityType == "event" then
		return "Event"
	end
	return "Rare"
end

local function FormatTimestamp(epoch)
	if type(epoch) ~= "number" or epoch <= 0 then
		return "Never"
	end
	return date("%Y-%m-%d %H:%M", epoch)
end


local function GetToolkit()
	return rawget(_G, "FabledUI_UIToolkit")
end

local function StyleButton(button)
	local T = GetToolkit()
	if T and T.Themes and T.Themes.StyleFlatButton then
		T.Themes:StyleFlatButton(button, TOOLKIT_THEME, TOOLKIT_ACCENT)
	end
end

local function StylePanel(frame)
	local T = GetToolkit()
	-- ApplyPanel is the real name. This probed ApplyPanelChrome and then
	-- StyleFrame, neither of which has ever existed on T.Themes, so both
	-- branches were skipped and every Explorer panel rendered unthemed --
	-- silently, because the whole block is guarded by existence checks.
	if T and T.Themes and T.Themes.ApplyPanel then
		T.Themes:ApplyPanel(frame, TOOLKIT_THEME, TOOLKIT_ACCENT)
	end
end

local function CreateButton(parent, width, height, text, point, relativeTo, relativePoint, x, y, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height)
	button:SetPoint(point, relativeTo, relativePoint, x, y)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	StyleButton(button)
	return button
end

local function GetEntityName(entityData)
	return entityData and (entityData.displayName or entityData.name or ("Entity " .. tostring(entityData.id))) or "Unknown"
end

function N.Explorer:Init()
	self.offset = 0
	self.selectedEntityID = nil
	self.searchText = Lower(N.settings.explorer.search or "")
	self.filterMode = N.settings.explorer.filterMode or "all"
	self.onlyVisible = N.settings.explorer.onlyVisible == true
	self.showSeenOnly = N.settings.explorer.showSeenOnly == true
	self.sortMode = N.settings.explorer.sortMode or "recent"
	self.filterMissingMounts = false
	self.filterMissingPets = false

	-- Quest-gated visibility filter is per-character (Feature 2).
	-- Persists in db.charPrefs[<name-realm>].hideLockedRares.
	self.hideLockedRares = (N.GetCharPref and N:GetCharPref("hideLockedRares", false)) or false
end

function N.Explorer:PersistLocalState()
	N:SetExplorerPref("search", self.searchText or "")
	N:SetExplorerPref("filterMode", self.filterMode or "all")
	N:SetExplorerPref("onlyVisible", self.onlyVisible == true)
	N:SetExplorerPref("showSeenOnly", self.showSeenOnly == true)
	N:SetExplorerPref("sortMode", self.sortMode or "recent")
end

function N.Explorer:SetSortMode(mode)
	self.sortMode = mode or "recent"
	self.offset = 0
	self:PersistLocalState()
	self:Refresh(false)
end

function N.Explorer:UpdateShellStatus(filteredCount, summary)
	if not self.frame or not self.frame.SetShellStatus then
		return
	end

	local status = string.format(
		"Filtered %d | Visible %d | Suppressed %d | Seen %d",
		tonumber(filteredCount) or 0,
		tonumber(summary and summary.visible) or 0,
		tonumber(summary and summary.suppressed) or 0,
		tonumber(summary and summary.seen) or 0
	)
	self.frame:SetShellStatus(status)
end

function N.Explorer:BuildSummary(entities)
	local summary = {
		tracked = 0,
		visible = 0,
		suppressed = 0,
		rare = 0,
		treasure = 0,
		event = 0,
		seen = 0,
		custom = 0,
		rep = 0,
	}

	for _, entityData in ipairs(entities) do
		summary.tracked = summary.tracked + 1
		if entityData.type == "rare" then
			summary.rare = summary.rare + 1
		elseif entityData.type == "treasure" then
			summary.treasure = summary.treasure + 1
		elseif entityData.type == "event" then
			summary.event = summary.event + 1
		end

		if entityData.custom then
			summary.custom = summary.custom + 1
		end
		if entityData.isRep then
			summary.rep = summary.rep + 1
		end

		local hidden = N:IsEntitySuppressed(entityData.id, "all") or N:IsEntitySuppressed(entityData.id, "explorer")
		if hidden then
			summary.suppressed = summary.suppressed + 1
		else
			summary.visible = summary.visible + 1
		end

		if N:GetSighting(entityData.id) then
			summary.seen = summary.seen + 1
		end
	end

	return summary
end

function N.Explorer:SortEntities(entities)
	table.sort(entities, function(a, b)
		local aName = Lower(GetEntityName(a))
		local bName = Lower(GetEntityName(b))
		local aSighting = N:GetSighting(a.id)
		local bSighting = N:GetSighting(b.id)
		local aSeen = aSighting and tonumber(aSighting.lastSeen) or 0
		local bSeen = bSighting and tonumber(bSighting.lastSeen) or 0
		local aCount = aSighting and tonumber(aSighting.count) or 0
		local bCount = bSighting and tonumber(bSighting.count) or 0

		if self.sortMode == "name" then
			if aName == bName then
				return (a.id or 0) < (b.id or 0)
			end
			return aName < bName
		elseif self.sortMode == "type" then
			if a.type == b.type then
				if aName == bName then
					return (a.id or 0) < (b.id or 0)
				end
				return aName < bName
			end
			return (a.type or "") < (b.type or "")
		elseif self.sortMode == "seen" then
			if aCount == bCount then
				if aName == bName then
					return (a.id or 0) < (b.id or 0)
				end
				return aName < bName
			end
			return aCount > bCount
		end

		if aSeen == bSeen then
			if aName == bName then
				return (a.id or 0) < (b.id or 0)
			end
			return aName < bName
		end
		return aSeen > bSeen
	end)
end

function N.Explorer:CreateFrame()
	if self.frame then
		return
	end

	-- Keep the window at a sane size. A stretched drag / old saved state could
	-- balloon this near 1800px (huge empty middle gap); clamp to the range the
	-- two-pane layout actually wants.
	N.db.window = N.db.window or {}
	N.db.window.width = math.min(math.max(tonumber(N.db.window.width) or 1180, 1150), 1240)
	N.db.window.height = math.min(math.max(tonumber(N.db.window.height) or 780, 750), 900)

	local T = GetToolkit()
	local frame
	local content

	if T and T.Shell and T.Shell.CreateWindow then
		frame = T.Shell:CreateWindow("FabledUI_NemesisExplorer", {
			title = "FabledUI - Nemesis",
			subtitle = "Rare, treasure, and event hunting without the usual UI tax.",
			theme = TOOLKIT_THEME,
			accentColor = TOOLKIT_ACCENT,
			width = N.db.window.width,
			height = N.db.window.height,
			minWidth = 1150,
			minHeight = 750,
			maxWidth = 1240,
			maxHeight = 900,
			state = N.db.window,
			ribbonLabel = "Nemesis",
			ribbonIcon = 463450,
			onSizeChanged = function()
				if self.frame and self.frame:IsShown() then
					self:Refresh(false)
				end
			end,
		})
		content = frame.Content or frame
		frame:SetShellStatus("Awaiting sightings")
	else
		frame = CreateFrame("Frame", "FabledUI_NemesisExplorer", UIParent, "BackdropTemplate")
		frame:SetSize(N.db.window.width or 1140, N.db.window.height or 700)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("DIALOG")
		frame:SetToplevel(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetClampedToScreen(true)
		frame:SetBackdrop({
			bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
			edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})
		frame:SetScript("OnDragStart", function(selfFrame) selfFrame:StartMoving() end)
		frame:SetScript("OnDragStop", function(selfFrame) selfFrame:StopMovingOrSizing() end)

		frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		frame.title:SetPoint("TOP", 0, -16)
		frame.title:SetText("Nemesis Explorer")

		frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)
		frame.subtitle:SetText("Manage tracked entities, activity, suppression, and custom NPCs.")

		local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		closeButton:SetPoint("TOPRIGHT", -5, -5)
		content = frame
	end

	frame.contentRoot = content

	frame.searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	frame.searchBox:SetSize(220, 24)
	frame.searchBox:SetPoint("TOPLEFT", 20, -18)
	frame.searchBox:SetAutoFocus(false)
	frame.searchBox:SetText(self.searchText or "")
	frame.searchBox:SetScript("OnTextChanged", function(box)
		self.searchText = Lower(box:GetText() or "")
		self.offset = 0
		self:PersistLocalState()
		self:Refresh(false)
	end)

	frame.searchLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.searchLabel:SetPoint("BOTTOMLEFT", frame.searchBox, "TOPLEFT", 0, 2)
	frame.searchLabel:SetText("Search")

	local function MakeFilterButton(label, mode, xOffset)
		return CreateButton(content, 80, 22, label, "TOPLEFT", frame.searchBox, "TOPRIGHT", xOffset, 0, function()
			self.filterMode = mode
			self.offset = 0
			self:PersistLocalState()
			self:Refresh(false)
		end)
	end

	frame.filterAll = MakeFilterButton("All", "all", 12)
	frame.filterRares = MakeFilterButton("Rares", "rare", 96)
	frame.filterTreasures = MakeFilterButton("Treasures", "treasure", 180)
	frame.filterEvents = MakeFilterButton("Events", "event", 264)

	frame.visibleOnly = CreateButton(content, 100, 22, "Visible Only", "TOPLEFT", frame.filterEvents, "TOPRIGHT", 12, 0, function()
		self.onlyVisible = not self.onlyVisible
		self:PersistLocalState()
		self:Refresh(false)
	end)

	frame.seenOnly = CreateButton(content, 100, 22, "Seen Only", "TOPLEFT", frame.visibleOnly, "TOPRIGHT", 8, 0, function()
		self.showSeenOnly = not self.showSeenOnly
		self:PersistLocalState()
		self:Refresh(false)
	end)

	-- Row 2 of the filter bar starts here (wraps under the search box, left-aligned)
	-- so the whole bar fits without forcing a ~1500px-wide window.
	frame.filterMissingMounts = CreateButton(content, 118, 22, "Missing Mounts", "TOPLEFT", frame.searchBox, "BOTTOMLEFT", 0, -8, function()
		self.filterMissingMounts = not self.filterMissingMounts
		self.offset = 0
		self:Refresh(false)
	end)

	frame.filterMissingPets = CreateButton(content, 100, 22, "Missing Pets", "TOPLEFT", frame.filterMissingMounts, "TOPRIGHT", 6, 0, function()
		self.filterMissingPets = not self.filterMissingPets
		self.offset = 0
		self:Refresh(false)
	end)

	frame.filterHideLocked = CreateButton(content, 118, 22, "Hide Locked", "TOPLEFT", frame.filterMissingPets, "TOPRIGHT", 6, 0, function()
		self.hideLockedRares = not self.hideLockedRares
		self.offset = 0
		if N.SetCharPref then
			N:SetCharPref("hideLockedRares", self.hideLockedRares)
		end
		self:Refresh(false)
	end)
	if frame.filterHideLocked then
		frame.filterHideLocked:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_TOP")
			GameTooltip:SetText("Hide quest-locked rares")
			GameTooltip:AddLine("Hide entries gated behind a quest this character hasn't completed.", 0.85, 0.85, 0.85, true)
			GameTooltip:Show()
		end)
		frame.filterHideLocked:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	frame.sortRecent = CreateButton(content, 72, 22, "Recent", "TOPLEFT", frame.filterHideLocked, "TOPRIGHT", 10, 0, function() self:SetSortMode("recent") end)
	frame.sortName = CreateButton(content, 72, 22, "Name", "TOPLEFT", frame.sortRecent, "TOPRIGHT", 6, 0, function() self:SetSortMode("name") end)
	frame.sortType = CreateButton(content, 72, 22, "Type", "TOPLEFT", frame.sortName, "TOPRIGHT", 6, 0, function() self:SetSortMode("type") end)
	frame.sortSeen = CreateButton(content, 86, 22, "Most Seen", "TOPLEFT", frame.sortType, "TOPRIGHT", 6, 0, function() self:SetSortMode("seen") end)

	frame.summaryBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
	frame.summaryBar:SetSize(1096, 48)
	frame.summaryBar:SetPoint("TOPLEFT", 20, -78)
	frame.summaryBar:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame.summaryBar:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
	StylePanel(frame.summaryBar)
	frame.summaryBar.text = frame.summaryBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.summaryBar.text:SetPoint("LEFT", 12, 0)
	frame.summaryBar.text:SetPoint("RIGHT", -12, 0)
	frame.summaryBar.text:SetJustifyH("LEFT")

	frame.listPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
	frame.listPanel:SetSize(650, 545)
	frame.listPanel:SetPoint("TOPLEFT", 18, -132)
	frame.listPanel:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame.listPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
	StylePanel(frame.listPanel)

	frame.detailPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
	frame.detailPanel:SetSize(436, 360)
	frame.detailPanel:SetPoint("TOPRIGHT", -18, -132)
	frame.detailPanel:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame.detailPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
	StylePanel(frame.detailPanel)

	frame.recentPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
	frame.recentPanel:SetSize(436, 177)
	frame.recentPanel:SetPoint("TOPRIGHT", -18, -508)
	frame.recentPanel:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame.recentPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
	StylePanel(frame.recentPanel)

	frame.footer = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.footer:SetPoint("BOTTOMLEFT", 22, 12)
	frame.footer:SetWidth(1098)
	frame.footer:SetJustifyH("LEFT")

	frame.headerName = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.headerName:SetPoint("TOPLEFT", 12, -10)
	frame.headerName:SetText("Entity")

	frame.headerType = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.headerType:SetPoint("TOPLEFT", 360, -10)
	frame.headerType:SetText("Type")

	frame.headerState = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.headerState:SetPoint("TOPLEFT", 444, -10)
	frame.headerState:SetText("State")

	frame.headerSeen = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.headerSeen:SetPoint("TOPLEFT", 548, -10)
	frame.headerSeen:SetText("Seen")

	frame.headerRespawn = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.headerRespawn:SetPoint("TOPLEFT", 588, -10)
	frame.headerRespawn:SetText("Respawn")

	frame.scrollUp = CreateButton(frame.listPanel, 32, 20, "Up", "BOTTOMRIGHT", frame.listPanel, "BOTTOMRIGHT", -50, 10, function()
		self.offset = math.max(0, self.offset - 1)
		self:Refresh(false)
	end)
	frame.scrollUp:SetText("Up")
	if frame.scrollUp.tooltipText ~= nil then frame.scrollUp.tooltipText = "Scroll list up" end
	frame.scrollUp:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText("Scroll list up")
		GameTooltip:Show()
	end)
	frame.scrollUp:SetScript("OnLeave", function() GameTooltip:Hide() end)

	frame.scrollDown = CreateButton(frame.listPanel, 32, 20, "Down", "BOTTOMRIGHT", frame.listPanel, "BOTTOMRIGHT", -12, 10, function()
		self.offset = self.offset + 1
		self:Refresh(false)
	end)
	frame.scrollDown:SetText("Down")
	frame.scrollDown:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText("Scroll list down")
		GameTooltip:Show()
	end)
	frame.scrollDown:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Divider separating list rows from bottom bulk-action row (clarifies hierarchy)
	frame.bulkDivider = frame.listPanel:CreateTexture(nil, "ARTWORK")
	frame.bulkDivider:SetColorTexture(0.35, 0.35, 0.4, 0.7)
	frame.bulkDivider:SetHeight(1)
	frame.bulkDivider:SetPoint("BOTTOMLEFT", frame.listPanel, "BOTTOMLEFT", 10, 38)
	frame.bulkDivider:SetPoint("BOTTOMRIGHT", frame.listPanel, "BOTTOMRIGHT", -10, 38)

	frame.bulkSectionLabel = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.bulkSectionLabel:SetPoint("BOTTOMLEFT", frame.bulkDivider, "TOPLEFT", 0, 2)
	frame.bulkSectionLabel:SetText("|cffaaaaaaBulk actions (apply to all visible rows):|r")

	frame.bulkUnsuppress = CreateButton(frame.listPanel, 110, 20, "Unsuppress Visible", "BOTTOMLEFT", frame.listPanel, "BOTTOMLEFT", 10, 10, function()
		for _, entityData in ipairs(self:GetVisibleEntities()) do
			N:SetEntitySuppressed(entityData.id, false, "all")
			N:SetEntitySuppressed(entityData.id, false, "alert")
			N:SetEntitySuppressed(entityData.id, false, "map")
			N:SetEntitySuppressed(entityData.id, false, "explorer")
		end
		self:Refresh(false)
	end)
	frame.bulkHideAlerts = CreateButton(frame.listPanel, 120, 20, "Mute Visible Alerts", "LEFT", frame.bulkUnsuppress, "RIGHT", 8, 0, function()
		for _, entityData in ipairs(self:GetVisibleEntities()) do
			N:SetEntitySuppressed(entityData.id, true, "alert")
		end
		self:Refresh(false)
	end)
	frame.bulkHideMap = CreateButton(frame.listPanel, 112, 20, "Hide Visible Map", "LEFT", frame.bulkHideAlerts, "RIGHT", 8, 0, function()
		for _, entityData in ipairs(self:GetVisibleEntities()) do
			N:SetEntitySuppressed(entityData.id, true, "map")
		end
		self:Refresh(false)
	end)

	-- Empty-state message shown when no entities match the current filters
	frame.emptyState = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.emptyState:SetPoint("CENTER", frame.listPanel, "CENTER", 0, 20)
	frame.emptyState:SetWidth(560)
	frame.emptyState:SetJustifyH("CENTER")
	frame.emptyState:SetJustifyV("MIDDLE")
	frame.emptyState:SetText("|cffcccccfNo entities match the current filters.|r\n|cff888888Try clearing the search box or switching to All / Visible Only off.|r")
	frame.emptyState:Hide()

	frame.rows = {}
	for index = 1, VISIBLE_ROWS do
		local row = CreateFrame("Button", nil, frame.listPanel, "BackdropTemplate")
		row:SetSize(620, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 12, -34 - ((index - 1) * (ROW_HEIGHT + 4)))
		row:SetBackdrop({
			bgFile = "Interface/ChatFrame/ChatFrameBackground",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 8,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		row:SetBackdropColor(0.08, 0.08, 0.11, 0.85)
		row:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)
		StylePanel(row)
		row:RegisterForClicks("AnyUp")

		row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.nameText:SetPoint("LEFT", 8, 0)
		row.nameText:SetWidth(340)
		row.nameText:SetJustifyH("LEFT")

		row.typeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.typeText:SetPoint("LEFT", 356, 0)
		row.typeText:SetWidth(78)
		row.typeText:SetJustifyH("LEFT")

		row.stateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.stateText:SetPoint("LEFT", 440, 0)
		row.stateText:SetWidth(96)
		row.stateText:SetJustifyH("LEFT")

		row.seenText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.seenText:SetPoint("LEFT", 546, 0)
		row.seenText:SetWidth(36)
		row.seenText:SetJustifyH("LEFT")

		row.respawnText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.respawnText:SetPoint("LEFT", 584, 0)
		row.respawnText:SetWidth(70)
		row.respawnText:SetJustifyH("LEFT")

		row.muteIndicator = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.muteIndicator:SetPoint("RIGHT", -6, 0)
		row.muteIndicator:SetWidth(48)
		row.muteIndicator:SetJustifyH("RIGHT")

		row:SetScript("OnClick", function(button, mouseButton)
			if not button.entityID then return end
			if mouseButton == "RightButton" then
				self:ShowEntityContextMenu(button, button.entityID)
			else
				self:SelectEntity(button.entityID)
			end
		end)

		row:SetScript("OnEnter", function(button)
			if not button.entityID or not button.entityData then
				return
			end
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(GetEntityName(button.entityData))
			GameTooltip:AddLine("ID: " .. tostring(button.entityID), 0.75, 0.75, 0.75)
			GameTooltip:AddLine("Type: " .. FormatType(button.entityData.type), 1, 1, 1)
			local sighting = N:GetSighting(button.entityID)
			if sighting then
				GameTooltip:AddLine("Seen: " .. tostring(sighting.count) .. " time(s)", 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Last seen: " .. FormatTimestamp(sighting.lastSeen), 0.8, 0.8, 0.8)
			end
			if N.Respawn and N.Respawn.GetExplorerStrings then
				local avgStr, agoStr = N.Respawn:GetExplorerStrings(button.entityID)
				if avgStr ~= "-" then
					GameTooltip:AddLine("Avg respawn: " .. avgStr, 0.7, 0.85, 1.0)
				end
				if agoStr ~= "-" then
					GameTooltip:AddLine(agoStr, 0.7, 0.85, 1.0)
				end
			end
			local loot = N.Database:GetEntityLoot(button.entityID)
			if #loot > 0 then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Loot", 1, 0.82, 0)
				for i = 1, math.min(#loot, 6) do
					GameTooltip:AddLine(C_Item.GetItemInfo(loot[i]) or ("Item " .. tostring(loot[i])), 1, 1, 1)
				end
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)

		frame.rows[index] = row
	end

	frame.detailTitle = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.detailTitle:SetPoint("TOPLEFT", 12, -12)
	frame.detailTitle:SetPoint("RIGHT", -12, 0)
	frame.detailTitle:SetJustifyH("LEFT")
	frame.detailTitle:SetText("Select an entity")

	frame.detailMeta = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.detailMeta:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 0, -8)
	frame.detailMeta:SetWidth(402)
	frame.detailMeta:SetJustifyH("LEFT")
	frame.detailMeta:SetText("Choose an entry on the left to manage it.")

	frame.detailSeen = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailSeen:SetPoint("TOPLEFT", frame.detailMeta, "BOTTOMLEFT", 0, -8)
	frame.detailSeen:SetWidth(402)
	frame.detailSeen:SetJustifyH("LEFT")

	frame.detailStatus = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailStatus:SetPoint("TOPLEFT", frame.detailSeen, "BOTTOMLEFT", 0, -8)
	frame.detailStatus:SetWidth(402)
	frame.detailStatus:SetJustifyH("LEFT")

	frame.detailLoot = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailLoot:SetPoint("TOPLEFT", frame.detailStatus, "BOTTOMLEFT", 0, -10)
	frame.detailLoot:SetWidth(402)
	frame.detailLoot:SetJustifyH("LEFT")

	frame.manageAlert = CreateButton(frame.detailPanel, 108, 22, "Mute Alert", "TOPLEFT", frame.detailLoot, "BOTTOMLEFT", 0, -14, function()
		if self.selectedEntityID then
			N:SetEntitySuppressed(self.selectedEntityID, true, "alert")
			self:Refresh(false)
		end
	end)
	frame.manageMap = CreateButton(frame.detailPanel, 108, 22, "Hide Map Pin", "LEFT", frame.manageAlert, "RIGHT", 8, 0, function()
		if self.selectedEntityID then
			N:SetEntitySuppressed(self.selectedEntityID, true, "map")
			self:Refresh(false)
		end
	end)
	frame.manageExplorer = CreateButton(frame.detailPanel, 112, 22, "Hide Explorer", "LEFT", frame.manageMap, "RIGHT", 8, 0, function()
		if self.selectedEntityID then
			N:SetEntitySuppressed(self.selectedEntityID, true, "explorer")
			self:Refresh(false)
		end
	end)

	frame.ignoreAll = CreateButton(frame.detailPanel, 108, 22, "Ignore All", "TOPLEFT", frame.manageAlert, "BOTTOMLEFT", 0, -8, function()
		if self.selectedEntityID then
			N:SetEntitySuppressed(self.selectedEntityID, true, "all")
			self:Refresh(false)
		end
	end)
	frame.restoreAll = CreateButton(frame.detailPanel, 108, 22, "Restore All", "LEFT", frame.ignoreAll, "RIGHT", 8, 0, function()
		if self.selectedEntityID then
			N:SetEntitySuppressed(self.selectedEntityID, false, "all")
			N:SetEntitySuppressed(self.selectedEntityID, false, "alert")
			N:SetEntitySuppressed(self.selectedEntityID, false, "map")
			N:SetEntitySuppressed(self.selectedEntityID, false, "explorer")
			self:Refresh(false)
		end
	end)
	frame.openSettings = CreateButton(frame.detailPanel, 108, 22, "Settings", "LEFT", frame.restoreAll, "RIGHT", 8, 0, function()
		N:OpenSettings()
	end)

	-- Generate Macro (Feature 3): builds a /target + /way macro and shows
	-- a copy-friendly popup. Disabled until an entity is selected.
	frame.generateMacro = CreateButton(frame.detailPanel, 132, 22, "Generate Macro", "TOPLEFT", frame.ignoreAll, "BOTTOMLEFT", 0, -8, function()
		if not self.selectedEntityID then return end
		if N.Macro and N.Macro.ShowCopyPopup then
			N.Macro:ShowCopyPopup(self.selectedEntityID)
		else
			N:Print("Macro module not loaded.")
		end
	end)
	frame.generateMacro:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText("Generate Macro")
		GameTooltip:AddLine("Build a /target + /way macro for the selected entity and open a copy-friendly popup.", 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	frame.generateMacro:SetScript("OnLeave", function() GameTooltip:Hide() end)

	frame.customHeader = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.customHeader:SetPoint("TOPLEFT", frame.generateMacro, "BOTTOMLEFT", 0, -16)
	frame.customHeader:SetText("Custom NPC")

	frame.customIDLabel = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.customIDLabel:SetPoint("TOPLEFT", frame.customHeader, "BOTTOMLEFT", 0, -6)
	frame.customIDLabel:SetText("NPC ID")

	frame.customIDBox = CreateFrame("EditBox", nil, frame.detailPanel, "InputBoxTemplate")
	frame.customIDBox:SetSize(90, 24)
	frame.customIDBox:SetPoint("TOPLEFT", frame.customIDLabel, "BOTTOMLEFT", 6, -4)
	frame.customIDBox:SetAutoFocus(false)
	frame.customIDBox:SetNumeric(true)

	frame.customNameLabel = frame.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.customNameLabel:SetPoint("BOTTOMLEFT", frame.customIDLabel, "BOTTOMRIGHT", 102, 0)
	frame.customNameLabel:SetText("Display Name")

	frame.customNameBox = CreateFrame("EditBox", nil, frame.detailPanel, "InputBoxTemplate")
	frame.customNameBox:SetSize(170, 24)
	frame.customNameBox:SetPoint("LEFT", frame.customIDBox, "RIGHT", 8, 0)
	frame.customNameBox:SetAutoFocus(false)

	frame.addCustom = CreateButton(frame.detailPanel, 94, 22, "Add / Update", "LEFT", frame.customNameBox, "RIGHT", 8, 0, function()
		local npcID = tonumber(frame.customIDBox:GetText() or "")
		local name = frame.customNameBox:GetText() or ""
		name = name:match("^%s*(.-)%s*$") or ""
		if npcID and name ~= "" and N:AddCustomNPC(npcID, name) then
			N:RefreshAll()
			self:SelectEntity(npcID)
			frame.customIDBox:SetText("")
			frame.customNameBox:SetText("")
		end
	end)

	frame.removeCustom = CreateButton(frame.detailPanel, 94, 22, "Remove", "TOPLEFT", frame.customIDBox, "BOTTOMLEFT", 0, -8, function()
		local targetID = self.selectedEntityID or tonumber(frame.customIDBox:GetText() or "")
		if targetID and N:RemoveCustomNPC(targetID) then
			self.selectedEntityID = nil
			N:RefreshAll()
			self:Refresh(false)
		end
	end)

	frame.recentTitle = frame.recentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.recentTitle:SetPoint("TOPLEFT", 12, -12)
	frame.recentTitle:SetText("Recent Activity")

	frame.recentSubtitle = frame.recentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.recentSubtitle:SetPoint("TOPLEFT", frame.recentTitle, "BOTTOMLEFT", 0, -4)
	frame.recentSubtitle:SetWidth(402)
	frame.recentSubtitle:SetJustifyH("LEFT")
	frame.recentSubtitle:SetText("Most recent sightings recorded by Nemesis.")

	frame.recentRows = {}
	for index = 1, RECENT_ROWS do
		local rowText = frame.recentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		rowText:SetPoint("TOPLEFT", 12, -42 - ((index - 1) * 24))
		rowText:SetPoint("RIGHT", -12, 0)
		rowText:SetJustifyH("LEFT")
		rowText:SetText("-")
		frame.recentRows[index] = rowText
	end

	self.frame = frame
end

-- -------------------------------------------------------
-- Per-entity audio/visual context menu
-- -------------------------------------------------------

function N.Explorer:ShowEntityContextMenu(anchor, entityID)
	entityID = tonumber(entityID)
	if not entityID then return end

	local audioMuted  = N:IsEntityAudioMuted(entityID)
	local visualMuted = N:IsEntityVisualMuted(entityID)

	local menuList = {
		{
			text     = audioMuted and "Unmute Audio" or "Mute Audio",
			func     = function()
				N:SetEntityAudioMuted(entityID, not audioMuted)
				self:Refresh(false)
			end,
		},
		{
			text     = visualMuted and "Show Visual Alert" or "Hide Visual Alert",
			func     = function()
				N:SetEntityVisualMuted(entityID, not visualMuted)
				self:Refresh(false)
			end,
		},
	}

	-- 12.0.5: EasyMenu removed; prefer MenuUtil with EasyMenu fallback.
	if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
		local ok = pcall(MenuUtil.CreateContextMenu, anchor, function(_, rootDescription)
			for _, item in ipairs(menuList) do
				rootDescription:CreateButton(item.text, item.func)
			end
		end)
		if ok then return end
	end
	if _G.EasyMenu then
		local menuFrame = _G["FabledUI_NemesisEntityMenu"]
		if not menuFrame then
			menuFrame = CreateFrame("Frame", "FabledUI_NemesisEntityMenu", UIParent, "UIDropDownMenuTemplate")
		end
		for _, item in ipairs(menuList) do item.notCheckable = true end
		EasyMenu(menuList, menuFrame, anchor, 0, 0, "MENU")
	end
end

-- -------------------------------------------------------
-- Mount / Pet loot filter helpers
-- -------------------------------------------------------

-- Build a set of all mount spell IDs the player already owns
local function BuildOwnedMountSet()
	local owned = {}
	if C_MountJournal and C_MountJournal.GetMountIDs then
		for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
			local _, spellID, _, _, _, _, _, _, _, _, isOwned = C_MountJournal.GetMountInfoByID(mountID)
			if isOwned and spellID then
				owned[spellID] = true
			end
		end
	end
	return owned
end

-- Build a set of all battle pet species IDs the player owns at least one of.
-- C_PetJournal.GetPetGUIDByIndex was removed in WoW 12.x; guard accordingly.
local function BuildOwnedPetSet()
	local owned = {}
	if not (C_PetJournal and C_PetJournal.GetNumPets) then return owned end
	if not C_PetJournal.GetPetGUIDByIndex then return owned end

	local numPets = C_PetJournal.GetNumPets()
	for i = 1, numPets do
		local petGUID = C_PetJournal.GetPetGUIDByIndex(i)
		if petGUID then
			local _, speciesID = C_PetJournal.GetPetInfoByGUID(petGUID)
			if speciesID then
				owned[speciesID] = true
			end
		end
	end
	return owned
end

-- Return true if any item in the loot list grants a mount the player is missing
local function LootHasMissingMount(loot, ownedMounts)
	for _, itemID in ipairs(loot) do
		-- Loot entries may be raw itemIDs (number) or item names (string from older data).
		-- Both Script_GetPetInfoByItemID and GetItemSpell require numeric item IDs.
		local id = tonumber(itemID)
		if not id then
			-- Skip non-numeric loot entries (legacy data using item name strings)
		else
			-- GetItemSpell returns the spell triggered on use; mount items return the mount spell.
			-- C_Item's: the global GetItemSpell is gone in 12.1.5.
			local spellName, spellID
			if C_Item and C_Item.GetItemSpell then
				spellName, spellID = C_Item.GetItemSpell(id)
			end
			if spellID and C_MountJournal then
				-- Check all mounts for a match against this spell
				for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
					local _, mSpellID = C_MountJournal.GetMountInfoByID(mountID)
					if mSpellID == spellID and not ownedMounts[mSpellID] then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Return true if any item in the loot list grants a pet species the player is missing
local function LootHasMissingPet(loot, ownedPets)
	if not C_PetJournal then return false end
	for _, itemID in ipairs(loot) do
		local id = tonumber(itemID)
		-- C_PetJournal.GetPetInfoByItemID returns speciesID if the item teaches a pet
		if id and C_PetJournal.GetPetInfoByItemID then
			local speciesID = C_PetJournal.GetPetInfoByItemID(id)
			if speciesID and not ownedPets[speciesID] then
				return true
			end
		end
	end
	return false
end

function N.Explorer:GetFilteredEntities()
	local query = self.searchText or ""
	local entities = {}

	-- Pre-build ownership sets once per filter pass (only when filters are active)
	local ownedMounts = (self.filterMissingMounts) and BuildOwnedMountSet() or nil
	local ownedPets   = (self.filterMissingPets)   and BuildOwnedPetSet()   or nil

	for _, entityData in ipairs(N.Database:GetAllEntities()) do
		local suppressedAnywhere = N:IsEntitySuppressed(entityData.id, "all") or N:IsEntitySuppressed(entityData.id, "explorer")
		local sighting = N:GetSighting(entityData.id)
		local searchable = table.concat({
			Lower(GetEntityName(entityData)),
			tostring(entityData.id or ""),
			Lower(entityData.type),
			entityData.custom and "custom" or "",
			entityData.isRep and "reputation" or "",
		}, " ")

		local passesQuery = (query == "") or searchable:find(query, 1, true)
		local passesType = (self.filterMode == "all") or (entityData.type == self.filterMode)
		local passesVisible = (not self.onlyVisible) or (not suppressedAnywhere)
		local passesSeen = (not self.showSeenOnly) or (sighting ~= nil)
		local passesSuppression = N.settings.showSuppressedInExplorer or (not N:IsEntitySuppressed(entityData.id, "explorer"))

		-- Quest-gated visibility filter (Feature 2)
		local passesQuestGate = true
		if self.hideLockedRares and N.Database.IsEntityQuestLocked then
			if N.Database:IsEntityQuestLocked(entityData.id) then
				passesQuestGate = false
			end
		end

		-- Mount / pet loot filters
		local passesMountFilter = true
		local passesPetFilter   = true
		if self.filterMissingMounts or self.filterMissingPets then
			local loot = N.Database:GetEntityLoot(entityData.id)
			if self.filterMissingMounts then
				passesMountFilter = LootHasMissingMount(loot, ownedMounts)
			end
			if self.filterMissingPets then
				passesPetFilter = LootHasMissingPet(loot, ownedPets)
			end
		end

		if passesQuery and passesType and passesVisible and passesSeen and passesSuppression
				and passesMountFilter and passesPetFilter and passesQuestGate then
			entities[#entities + 1] = entityData
		end
	end

	self:SortEntities(entities)
	return entities
end

function N.Explorer:GetVisibleEntities()
	local entities = self:GetFilteredEntities()
	local result = {}
	for index = self.offset + 1, math.min(#entities, self.offset + VISIBLE_ROWS) do
		result[#result + 1] = entities[index]
	end
	return result
end

function N.Explorer:SelectEntity(entityID)
	self.selectedEntityID = tonumber(entityID)
	self:Refresh(false)
end

function N.Explorer:Refresh(forceCreate)
	if forceCreate then
		self:CreateFrame()
	end
	if not self.frame then
		return
	end

	local shellVisible = self.frame.IsShellVisible and self.frame:IsShellVisible()
	if self.frame.IsShellVisible and not shellVisible then
		return
	elseif not self.frame.IsShellVisible and not self.frame:IsShown() then
		return
	end

	local allEntities = N.Database:GetAllEntities()
	local summary = self:BuildSummary(allEntities)
	local entities = self:GetFilteredEntities()
	local maxOffset = math.max(0, #entities - VISIBLE_ROWS)
	if self.offset > maxOffset then
		self.offset = maxOffset
	end

	-- Show empty-state message when no entities pass filters; otherwise hide it
	if self.frame.emptyState then
		if #entities == 0 then
			self.frame.emptyState:Show()
		else
			self.frame.emptyState:Hide()
		end
	end

	for rowIndex = 1, VISIBLE_ROWS do
		local entityData = entities[self.offset + rowIndex]
		local row = self.frame.rows[rowIndex]
		if entityData then
			local suppressed = N:IsEntitySuppressed(entityData.id, "all") or N:IsEntitySuppressed(entityData.id, "explorer")
			local sighting = N:GetSighting(entityData.id)
			row.entityID = entityData.id
			row.entityData = entityData
			row.nameText:SetText(GetEntityName(entityData) .. " |cff808080(" .. tostring(entityData.id) .. ")|r")
			row.typeText:SetText(FormatType(entityData.type))
			row.stateText:SetText(suppressed and "|cff999999Muted|r" or "|cff66ff66Active|r")
			row.seenText:SetText(sighting and tostring(sighting.count) or "-")

			-- Respawns column: rolling avg + "last killed" hint
			if row.respawnText then
				if N.Respawn and N.Respawn.GetExplorerStrings then
					local avgStr, agoStr = N.Respawn:GetExplorerStrings(entityData.id)
					if avgStr ~= "-" or agoStr ~= "-" then
						row.respawnText:SetText("|cffaaccff" .. avgStr .. "|r")
						row.respawnText.tooltipAgo = agoStr
					else
						row.respawnText:SetText("-")
						row.respawnText.tooltipAgo = nil
					end
				else
					row.respawnText:SetText("-")
				end
			end

			local audioMuted  = N:IsEntityAudioMuted(entityData.id)
			local visualMuted = N:IsEntityVisualMuted(entityData.id)
			local indicators = {}
			if audioMuted  then indicators[#indicators + 1] = "|cffff8800[M]|r" end
			if visualMuted then indicators[#indicators + 1] = "|cff888888[H]|r" end
			row.muteIndicator:SetText(table.concat(indicators, " "))
			if entityData.id == self.selectedEntityID then
				row:SetBackdropColor(0.15, 0.08, 0.18, 0.95)
				row:SetBackdropBorderColor(1, 0.2, 0.8, 0.95)
			else
				row:SetBackdropColor(0.08, 0.08, 0.11, 0.85)
				row:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)
			end
			row:Show()
		else
			row.entityID = nil
			row.entityData = nil
			row.muteIndicator:SetText("")
			if row.respawnText then row.respawnText:SetText("") end
			row:Hide()
		end
	end

	self.frame.visibleOnly:SetText(self.onlyVisible and "Visible Only*" or "Visible Only")
	self.frame.seenOnly:SetText(self.showSeenOnly and "Seen Only*" or "Seen Only")
	self.frame.filterMissingMounts:SetText(self.filterMissingMounts and "Missing Mounts*" or "Missing Mounts")
	self.frame.filterMissingPets:SetText(self.filterMissingPets and "Missing Pets*" or "Missing Pets")
	if self.frame.filterHideLocked then
		self.frame.filterHideLocked:SetText(self.hideLockedRares and "Hide Locked*" or "Hide Locked")
	end
	self.frame.sortRecent:SetText(self.sortMode == "recent" and "Recent*" or "Recent")
	self.frame.sortName:SetText(self.sortMode == "name" and "Name*" or "Name")
	self.frame.sortType:SetText(self.sortMode == "type" and "Type*" or "Type")
	self.frame.sortSeen:SetText(self.sortMode == "seen" and "Most Seen*" or "Most Seen")

	self.frame.summaryBar.text:SetText(string.format(
		"Tracked: %d   Visible: %d   Suppressed: %d   Rares: %d   Treasures: %d   Events: %d   Seen: %d   Custom: %d   Rep-tagged: %d",
		summary.tracked,
		summary.visible,
		summary.suppressed,
		summary.rare,
		summary.treasure,
		summary.event,
		summary.seen,
		summary.custom,
		summary.rep
	))

	local selected = self.selectedEntityID and N.Database:GetEntityData(self.selectedEntityID) or nil
	if selected then
		local sighting = N:GetSighting(self.selectedEntityID)
		local statusLines = {
			"Alert muted: " .. ((N:IsEntitySuppressed(self.selectedEntityID, "alert") or N:IsEntitySuppressed(self.selectedEntityID, "all")) and "Yes" or "No"),
			"Map hidden: " .. ((N:IsEntitySuppressed(self.selectedEntityID, "map") or N:IsEntitySuppressed(self.selectedEntityID, "all")) and "Yes" or "No"),
			"Explorer hidden: " .. ((N:IsEntitySuppressed(self.selectedEntityID, "explorer") or N:IsEntitySuppressed(self.selectedEntityID, "all")) and "Yes" or "No"),
			"Audio muted: " .. (N:IsEntityAudioMuted(self.selectedEntityID) and "Yes" or "No"),
			"Visual muted: " .. (N:IsEntityVisualMuted(self.selectedEntityID) and "Yes" or "No"),
		}
		local loot = N.Database:GetEntityLoot(self.selectedEntityID)
		local metaLine = string.format("ID: %s\nType: %s", tostring(self.selectedEntityID), FormatType(selected.type))
		if selected.custom then
			metaLine = metaLine .. "\nTag: Custom NPC"
		end
		if selected.isRep then
			metaLine = metaLine .. "\nTag: Reputation"
		end
		if selected.mapID then
			metaLine = metaLine .. "\nMap ID: " .. tostring(selected.mapID)
		end
		if selected.x and selected.y then
			metaLine = metaLine .. string.format("\nCoords: %.3f, %.3f", selected.x, selected.y)
		end
		self.frame.detailTitle:SetText(GetEntityName(selected))
		self.frame.detailMeta:SetText(metaLine)
		local respawnLine = ""
		if N.Respawn and N.Respawn.GetExplorerStrings then
			local avgStr, agoStr = N.Respawn:GetExplorerStrings(self.selectedEntityID)
			if avgStr ~= "-" or agoStr ~= "-" then
				respawnLine = string.format("\nAvg respawn: %s\n%s",
					avgStr ~= "-" and avgStr or "(insufficient samples)",
					agoStr ~= "-" and agoStr or "")
			end
		end
		self.frame.detailSeen:SetText(string.format("Seen count: %s\nLast seen: %s\nSource: %s%s",
			sighting and tostring(sighting.count) or "0",
			sighting and FormatTimestamp(sighting.lastSeen) or "Never",
			sighting and tostring(sighting.source or "unknown") or "-",
			respawnLine
		))
		self.frame.detailStatus:SetText(table.concat(statusLines, "\n"))
		self.frame.detailLoot:SetText("Loot entries: " .. tostring(#loot))
		self.frame.customIDBox:SetText(tostring(self.selectedEntityID))
		self.frame.customNameBox:SetText(selected.custom and (selected.displayName or selected.name or "") or "")
	else
		self.frame.detailTitle:SetText("Select an entity")
		self.frame.detailMeta:SetText("Choose an entry on the left to manage it.")
		self.frame.detailSeen:SetText("")
		self.frame.detailStatus:SetText("")
		self.frame.detailLoot:SetText("")
	end

	local recent = N:GetRecentSightings(RECENT_ROWS)
	for index = 1, RECENT_ROWS do
		local rowText = self.frame.recentRows[index]
		local entry = recent[index]
		if entry and entry.entityID then
			local entityData = N.Database:GetEntityData(entry.entityID)
			rowText:SetText(string.format("%s |cff808080(%d)|r — %s via %s — seen %d",
				entityData and GetEntityName(entityData) or ("Entity " .. tostring(entry.entityID)),
				entry.entityID,
				FormatTimestamp(entry.lastSeen),
				tostring(entry.source or "unknown"),
				entry.count or 0
			))
		else
			rowText:SetText("-")
		end
	end

	self.frame.footer:SetText(string.format(
		"Showing %d of %d filtered entities | Sort: %s | Filter: %s | Search: %s",
		math.min(VISIBLE_ROWS, math.max(0, #entities - self.offset)),
		#entities,
		self.sortMode,
		self.filterMode,
		(self.searchText and self.searchText ~= "") and self.searchText or "none"
	))

	self:UpdateShellStatus(#entities, summary)
end

function N.Explorer:Show(entityID)
	-- Pull the LoD data pack on first Explorer open so the entity list is
	-- populated with the ~9.5K imported rares/treasures rather than just
	-- the curated starter table.
	if N.EnsureDataLoaded then
		N:EnsureDataLoaded()
	end
	self:CreateFrame()
	if self.frame.ShowExpanded then
		self.frame:ShowExpanded()
	else
		self.frame:Show()
	end
	if entityID then
		self.selectedEntityID = tonumber(entityID)
	end
	self:Refresh(false)
end
