local addonName, ns = ...

Nemesis = Nemesis or {}
local N = Nemesis
_G.FabledUI_Nemesis = N

N.VERSION = "1.5.0"
N.TOOLKIT = rawget(_G, "FabledUI_UIToolkit")

function N:Print(...)
	print("|cffff33cc[Nemesis]|r", ...)
end

local function Trim(value)
	if type(value) ~= "string" then
		return ""
	end

	return value:match("^%s*(.-)%s*$") or ""
end

function N:OpenSettings()
	if Settings and Settings.OpenToCategory and self.CategoryID then
		Settings.OpenToCategory(self.CategoryID)
	end
end

-- Loads the on-demand data pack (FabledUI_Nemesis_Data) the first time any
-- consumer needs it. Parsing the ~9.5K-line RareScanner / MountCollector /
-- HandyNotes_Midnight donor tables eagerly at game start was costing every
-- player a multi-hundred-millisecond login hitch even if they never opened
-- Explorer. Deferring until first Explorer open / first vignette match /
-- first map refresh keeps boot fast for casual users.
function N:EnsureDataLoaded()
	if self._dataLoaded then return true end
	if not (C_AddOns and C_AddOns.LoadAddOn) then
		self._dataLoaded = true
		return false
	end
	local ok, loaded = pcall(C_AddOns.LoadAddOn, "FabledUI_Nemesis_Data")
	local resolved = false
	if ok then
		if loaded then
			resolved = true
		elseif C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FabledUI_Nemesis_Data") then
			resolved = true
		end
	end
	self._dataLoaded = resolved
	-- When called from a context other than Database:RebuildRuntimeCaches
	-- itself (Explorer:Show, Alerts:HandleVignette, refresh slash command),
	-- rebuild the runtime caches so the freshly-attached N.Data tables are
	-- folded into Database.Index in the same frame. The _rebuildingCaches
	-- guard prevents the double-rebuild that would otherwise occur when
	-- RebuildRuntimeCaches is the caller.
	if resolved and self.Database then
		-- Mark dirty so the next rebuild call does not skip out via the
		-- "nothing changed" gate added with the rebuild-gate fix.
		if self.Database.MarkDataDirty then self.Database:MarkDataDirty() end
		if self.Database.RebuildRuntimeCaches and not self.Database._rebuildingCaches then
			self.Database:RebuildRuntimeCaches()
		end
	end
	return self._dataLoaded
end

function N:RefreshAll()
	if self.Database then
		self.Database:RebuildRuntimeCaches()
	end
	if self.Map then
		self.Map:RefreshPins()
	end
	if self.Explorer then
		self.Explorer:Refresh(true)
	end
end

function N:OpenExplorer(entityID)
	if self.Explorer then
		self.Explorer:Show(entityID)
	end
end

function N:HandleSlash(msg)
	local input = Trim(msg or "")
	local command, rest = input:match("^(%S+)%s*(.-)$")
	command = command and command:lower() or ""

	if command == "" then
		self:OpenExplorer()
		return
	end

	if command == "explorer" then
		self:OpenExplorer()
		return
	end

	if command == "settings" then
		self:OpenSettings()
		return
	end

	if command == "filter" or command == "unfilter" then
		local idText, channel = rest:match("^(%d+)%s*(%S*)$")
		local entityID = tonumber(idText)
		channel = Trim(channel):lower()
		if not entityID then
			self:Print("Usage: /nemesis " .. command .. " <id> [all|alert|map|explorer]")
			return
		end

		if channel == "" then
			channel = "all"
		end

		if channel ~= "all" and channel ~= "alert" and channel ~= "map" and channel ~= "explorer" then
			self:Print("Invalid channel. Use all, alert, map, or explorer.")
			return
		end

		local state = command == "filter"
		self:SetEntitySuppressed(entityID, state, channel)
		self:Print((state and "Suppressed " or "Unsuppressed ") .. entityID .. " for " .. channel .. ".")
		return
	end

	if command == "addnpc" then
		local idText, name = rest:match("^(%d+)%s+(.+)$")
		local npcID = tonumber(idText)
		name = Trim(name)
		if not npcID or name == "" then
			self:Print("Usage: /nemesis addnpc <npcID> <name>")
			return
		end

		self:AddCustomNPC(npcID, name)
		self:RefreshAll()
		self:OpenExplorer(npcID)
		self:Print("Added custom NPC " .. npcID .. ": " .. name)
		return
	end

	if command == "removenpc" then
		local npcID = tonumber(rest:match("^(%d+)$"))
		if not npcID then
			self:Print("Usage: /nemesis removenpc <npcID>")
			return
		end

		if self:RemoveCustomNPC(npcID) then
			self:RefreshAll()
			self:Print("Removed custom NPC " .. npcID .. ".")
		else
			self:Print("Custom NPC " .. npcID .. " was not registered.")
		end
		return
	end

	self:Print("Unknown command. Opening Explorer instead.")
	self:OpenExplorer()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
	N:ResolveStorage()

	if N.Database then
		N.Database:Init()
	end

	if N.Alerts then
		N.Alerts:Init()
	end

	if N.Respawn then
		N.Respawn:Init()
	end

	if N.Map then
		N.Map:Init()
	end

	if N.Explorer then
		N.Explorer:Init()
	end

	if N.Settings then
		N.Settings:Register()
	end

	SLASH_FABLEDUI_NEMESIS1 = "/nemesis"
	SlashCmdList["FABLEDUI_NEMESIS"] = function(msg)
		N:HandleSlash(msg)
	end

	if N.TOOLKIT then
		N:Print("v" .. N.VERSION .. " online. Toolkit shell active.")
	else
		N:Print("v" .. N.VERSION .. " online. Toolkit missing, using fallback shell.")
	end
end)
