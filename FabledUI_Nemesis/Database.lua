local N = Nemesis
N.Database = {}
local DB = N.Database

DB.NPCs = {}
DB.Containers = {}
DB.Events = {}
DB.Loot = {}
DB.Index = {}
-- ============================================================
-- Starter data (intentionally empty).
--
-- This table previously seeded ~51 hand-authored rares, treasures and events
-- so the map and Explorer were pre-populated before the imported data loaded.
-- Audited 2026-08-12 against the RareScanner 12.0.0.9 tables the pipeline
-- imports from: 43 of those 51 entries carried NPC/object IDs that exist in
-- no rare database, and several paired a real rare's name with an invented ID
-- and zone (e.g. Arachnoid Harvester listed as 155432; it is 151934). The
-- Loot table was equally unreliable -- 35189 is Skoll, not the Time-Lost
-- Proto-Drake; 50009 is Mobus, not Aeonaxx.
--
-- Because ApplyStarterData() populates self.Index BEFORE MergeImportedData()
-- fills it in (which only writes `if not self.Index[npcID]`), those entries
-- won every collision and surfaced as phantom map pins at invented
-- coordinates -- and duplicate pins for the real-name/wrong-ID cases.
--
-- FabledUI_Nemesis_Data supplies 3,606 verified rares plus loot from the same
-- RareScanner import, so nothing is lost by leaving this empty. Do not
-- repopulate it by hand: add data through tools/data-pipeline so it stays
-- traceable to a source.
-- ============================================================
DB.StarterData = {
    NPCs = {},
    Containers = {},
    Events = {},
    Loot = {},
}

local function CopyTable(source)
	if type(source) ~= "table" then
		return source
	end
	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = CopyTable(value)
		else
			result[key] = value
		end
	end
	return result
end

local function NormalizeEntry(entityID, entityType, data)
	local entry = CopyTable(data or {})
	entry.id = tonumber(entityID)
	entry.type = entityType
	entry.name = entry.name or (entityType == "treasure" and ("Treasure " .. tostring(entityID)) or ("Entity " .. tostring(entityID)))
	entry.displayName = entry.displayName or entry.name
	entry.mapID = tonumber(entry.mapID)
	entry.x = tonumber(entry.x)
	entry.y = tonumber(entry.y)
	return entry
end

function DB:ApplyStarterData()
	self.NPCs = CopyTable(self.StarterData.NPCs or {})
	self.Containers = CopyTable(self.StarterData.Containers or {})
	self.Events = CopyTable(self.StarterData.Events or {})
	self.Loot = CopyTable(self.StarterData.Loot or {})
end

-- RareScanner / MountCollector imports use centi-coords (x = 4028 -> 40.28%);
-- normalize to the 0..1 fractional space the rest of Nemesis expects.
local function normalizeCentiCoord(value)
	value = tonumber(value)
	if not value then return nil end
	if value > 1 then
		return value / 10000
	end
	return value
end

local function isMetaKey(key)
	return type(key) == "string" and key:sub(1, 2) == "__"
end

-- Build a one-shot index of {npcID -> first-known display info} from the
-- MountCollector snapshot so we can backfill names / coords / mapIDs onto
-- otherwise-anonymous RareScanner NPC rows.
function DB:BuildMountSourceBackfill()
	local backfill = {}
	local sources = N.Data and N.Data.MountSources
	if type(sources) ~= "table" then return backfill end
	for _, row in pairs(sources) do
		if type(row) == "table" and type(row.from) == "table" then
			for _, src in ipairs(row.from) do
				local npcID = tonumber(src.npcID)
				if npcID and not backfill[npcID] then
					backfill[npcID] = {
						name = src.name,
						mapID = tonumber(src.coordZone or src.zoneID),
						x = src.x and (src.x > 1 and src.x / 100 or src.x) or nil,
						y = src.y and (src.y > 1 and src.y / 100 or src.y) or nil,
						expansion = src.expansion,
					}
				end
			end
		end
	end
	return backfill
end

-- Folds HandyNotes_Midnight rare/treasure imports into the runtime Index.
-- Schema (see Data/MidnightRares.lua and Data/MidnightTreasures.lua):
--   N.Data.MidnightRares[npcID] = { name, mapID, x, y, quest, rewards }
--   N.Data.MidnightTreasures[treasureID] = { name, mapID, x, y, quest }
--   N.Data.MidnightPatrols[npcID] = { {x,y}, {x,y}, ... }
-- Coordinates are already 0..1 normalized (no centi-coord rescaling needed).
-- Existing Index entries (curated starter data, RareScanner imports) win on
-- conflict; we only fill empty slots and enrich existing ones with rewards
-- and patrol-path data.
function DB:MergeMidnightImports()
	if not (N.Data and type(N.Data.MidnightRares) == "table") then
		return
	end

	-- Sample-data guard: the synthetic IDs in the 5-per-zone placeholder
	-- imports can collide with real GameObject IDs, so we skip the merge
	-- entirely until the offline pipeline ships authoritative data. The
	-- import file marks itself with __source = "sample"; we honor that and
	-- print a one-time hint so the user knows why their Midnight rare
	-- alerts aren't recognising the placeholder rows.
	local raresSample = (N.Data.MidnightRares.__source == "sample")
	local treasuresSample = (N.Data.MidnightTreasures and N.Data.MidnightTreasures.__source == "sample")
	if raresSample and treasuresSample then
		if not self._sampleSkipNoted then
			self._sampleSkipNoted = true
			if N.Print then
				N:Print("Midnight rare/treasure data is still sample-only; auto-merge skipped to avoid placeholder-ID collisions with live vignettes.")
			end
		end
		return
	end

	for entityID, data in pairs(N.Data.MidnightRares) do
		if not isMetaKey(entityID) and type(data) == "table" then
			local npcID = tonumber(entityID)
			if npcID then
				local existing = self.Index[npcID]
				if not existing then
					self.Index[npcID] = NormalizeEntry(entityID, "rare", {
						name           = data.name or ("Rare " .. tostring(npcID)),
						mapID          = tonumber(data.mapID),
						x              = tonumber(data.x),
						y              = tonumber(data.y),
						requiredQuest  = tonumber(data.quest),
						rewards        = data.rewards,
						_imported      = "handynotes_midnight",
					})
				else
					-- Enrich curated/RareScanner entries with rewards and
					-- requiredQuest from the Midnight import without
					-- clobbering coords/names that may have been hand-tuned.
					if not existing.requiredQuest and data.quest then
						existing.requiredQuest = tonumber(data.quest)
					end
					if not existing.rewards and data.rewards then
						existing.rewards = data.rewards
					end
				end
			end
		end
	end

	if type(N.Data.MidnightTreasures) == "table" then
		for entityID, data in pairs(N.Data.MidnightTreasures) do
			if not isMetaKey(entityID) and type(data) == "table" then
				local treasureID = tonumber(entityID)
				if treasureID and not self.Index[treasureID] then
					self.Index[treasureID] = NormalizeEntry(entityID, "treasure", {
						name           = data.name or ("Treasure " .. tostring(treasureID)),
						mapID          = tonumber(data.mapID),
						x              = tonumber(data.x),
						y              = tonumber(data.y),
						requiredQuest  = tonumber(data.quest),
						_imported      = "handynotes_midnight",
					})
				end
			end
		end
	end
end

function DB:MergeImportedData()
	local mountBackfill = self:BuildMountSourceBackfill()

	-- Imported rare NPCs. Many ship without coords (zoneID-only); the entry
	-- still earns a place in the Explorer + loot tooltip pipeline. When the
	-- mount snapshot has approximate coords we fold those in.
	if N.Data and type(N.Data.RareNPCs) == "table" then
		for entityID, data in pairs(N.Data.RareNPCs) do
			if not isMetaKey(entityID) then
				local npcID = tonumber(entityID)
				if npcID and not self.Index[npcID] then
					local backfill = mountBackfill[npcID]
					local name = (type(data) == "table" and data.name)
						or (backfill and backfill.name)
						or ("Rare " .. tostring(npcID))
					self.Index[npcID] = NormalizeEntry(entityID, "rare", {
						name = name,
						mapID = (type(data) == "table" and tonumber(data.zoneID))
							or (backfill and backfill.mapID),
						x = (type(data) == "table" and normalizeCentiCoord(data.x))
							or (backfill and backfill.x),
						y = (type(data) == "table" and normalizeCentiCoord(data.y))
							or (backfill and backfill.y),
						displayID = type(data) == "table" and data.displayID or nil,
						_imported = "rarescanner",
					})
				end
			end
		end
	end

	-- Imported treasures. Centi-coords -> 0..1; ship a fallback questID via
	-- requiredQuest so the quest-gating filter starts working immediately.
	if N.Data and type(N.Data.Containers) == "table" then
		for entityID, data in pairs(N.Data.Containers) do
			if not isMetaKey(entityID) and type(data) == "table" then
				local containerID = tonumber(entityID)
				if containerID and not self.Index[containerID] then
					local requiredQuest
					if type(data.questID) == "table" then
						requiredQuest = tonumber(data.questID[1])
					else
						requiredQuest = tonumber(data.questID)
					end
					self.Index[containerID] = NormalizeEntry(entityID, "treasure", {
						name = data.name or ("Treasure " .. tostring(containerID)),
						mapID = tonumber(data.zoneID),
						x = normalizeCentiCoord(data.x),
						y = normalizeCentiCoord(data.y),
						requiredQuest = requiredQuest,
						_imported = "rarescanner",
					})
				end
			end
		end
	end

	-- RareScanner per-NPC loot tables enrich the existing Loot index. Loot
	-- ships as a flat list of itemIDs which Alerts.lua surfaces verbatim.
	if N.Data and type(N.Data.RareLoot) == "table" then
		for entityID, items in pairs(N.Data.RareLoot) do
			if not isMetaKey(entityID) and type(items) == "table" then
				local npcID = tonumber(entityID)
				if npcID and not self.Loot[npcID] then
					self.Loot[npcID] = items
				end
			end
		end
	end

	-- Imported world events (RareScanner EVENT_INFO). These were previously
	-- supplied only by the hand-authored starter table; that table is gone, so
	-- this is now the sole source. Multi-zone events collapse to their first
	-- zone during import, which matches the one-position-per-entity model the
	-- Index uses.
	if N.Data and type(N.Data.Events) == "table" then
		for entityID, data in pairs(N.Data.Events) do
			if not isMetaKey(entityID) and type(data) == "table" then
				local eventID = tonumber(entityID)
				if eventID and not self.Index[eventID] then
					self.Index[eventID] = NormalizeEntry(entityID, "event", {
						name = data.name or ("Event " .. tostring(eventID)),
						mapID = tonumber(data.zoneID),
						x = normalizeCentiCoord(data.x),
						y = normalizeCentiCoord(data.y),
						requiredQuest = data.questID and data.questID[1] or nil,
					})
				end
			end
		end
	end
end

-- MarkDataDirty signals that the Index must be rebuilt on next read. Settings
-- toggles (filter masks, suppression clears) only need a view refresh, not a
-- full data rebuild — they call N:RefreshViews instead. Data imports / shard
-- loads / customNPCs mutations call MarkDataDirty so the next RebuildRuntimeCaches
-- actually does work.
function DB:MarkDataDirty()
	self._dataDirty = true
end

function DB:RebuildRuntimeCaches(force)
	-- Skip the rebuild when nothing has changed since the last pass. The
	-- previous implementation rebuilt the full Index (~9k entries) every
	-- time any settings toggle fired — burning ~50ms per click.
	if not force and not self._dataDirty and next(self.Index or {}) then
		return
	end

	-- Pull the LoD data pack lazily so the imported rare/treasure tables
	-- are visible when this function runs. _rebuildingCaches signals to
	-- N:EnsureDataLoaded that we're already mid-rebuild so it shouldn't
	-- recursively re-call this function after the addon resolves.
	self._rebuildingCaches = true
	if N.EnsureDataLoaded and not N._dataLoaded then
		N:EnsureDataLoaded()
	end

	self.Index = {}
	self:ApplyStarterData()

	for entityID, data in pairs(self.NPCs) do
		self.Index[tonumber(entityID)] = NormalizeEntry(entityID, "rare", data)
	end

	for entityID, data in pairs(self.Containers) do
		self.Index[tonumber(entityID)] = NormalizeEntry(entityID, "treasure", data)
	end

	for entityID, data in pairs(self.Events) do
		self.Index[tonumber(entityID)] = NormalizeEntry(entityID, "event", data)
	end

	-- Tier-3 imports merge after the curated starter data so hand-tuned
	-- entries always win on conflict. New entityIDs only.
	self:MergeImportedData()
	self:MergeMidnightImports()

	for npcID, name in pairs(N.db.customNPCs or {}) do
		npcID = tonumber(npcID)
		if npcID then
			local existing = self.Index[npcID]
			if existing then
				existing.custom = true
				existing.name = existing.name or name
				existing.displayName = existing.name
			else
				self.Index[npcID] = {
					id = npcID,
					type = "rare",
					name = name,
					displayName = name,
					custom = true,
				}
			end
		end
	end

	self._rebuildingCaches = nil
	self._dataDirty = false
end

function DB:Init()
	self:RebuildRuntimeCaches(true)
end

function DB:GetEntityData(entityID)
	entityID = tonumber(entityID)
	if not entityID then
		return nil
	end
	return self.Index[entityID]
end

function DB:GetEntityName(entityID)
	local data = self:GetEntityData(entityID)
	return data and (data.displayName or data.name) or ("Entity " .. tostring(entityID))
end

-- ============================================================
-- Quest gating (Feature 2)
--
-- Returns:
--   true  -> entity is locked behind an unfinished quest for this char
--   false -> not gated, OR gate already cleared, OR no quest data yet
--
-- Data wiring is intentional: we read entry.requiredQuest, which the
-- starter table doesn't yet ship. Once the RareScanner-derived data
-- lands, every gated entity will have requiredQuest = <questID> and
-- this helper begins reporting useful results without further code
-- changes.
-- ============================================================
function DB:GetRequiredQuest(entityID)
    local entry = self:GetEntityData(entityID)
    if type(entry) ~= "table" then return nil end
    return tonumber(entry.requiredQuest)
end

function DB:IsEntityQuestLocked(entityID)
    local questID = self:GetRequiredQuest(entityID)
    if not questID then return false end
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then
        return false
    end
    return not C_QuestLog.IsQuestFlaggedCompleted(questID)
end

function DB:GetEntityLoot(entityID)
	entityID = tonumber(entityID)
	if not entityID then
		return {}
	end
	local loot = self.Loot[entityID]
	if type(loot) ~= "table" then
		return {}
	end
	return loot
end

function DB:IterateEntitiesOnMap(mapID)
	local entities = {}
	mapID = tonumber(mapID)
	for _, data in pairs(self.Index) do
		if data.mapID == mapID and type(data.x) == "number" and type(data.y) == "number" then
			entities[#entities + 1] = data
		end
	end

	table.sort(entities, function(a, b)
		local aName = a.displayName or a.name or ""
		local bName = b.displayName or b.name or ""
		if aName == bName then
			return (a.id or 0) < (b.id or 0)
		end
		return aName < bName
	end)

	return entities
end

function DB:GetAllEntities()
	local entities = {}
	for _, data in pairs(self.Index) do
		entities[#entities + 1] = data
	end

	table.sort(entities, function(a, b)
		local aName = a.displayName or a.name or ""
		local bName = b.displayName or b.name or ""
		if aName == bName then
			return (a.id or 0) < (b.id or 0)
		end
		return aName < bName
	end)

	return entities
end
