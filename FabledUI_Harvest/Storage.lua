local H = Harvest
local SHARD_KEY = "FabledUI_DataVault_Harvest"
local ADDON_KEY = "harvest"

local DEFAULTS = {
    settings = {
        layers = { herb = true, ore = true, fish = true, treasure = true, lumber = true, skin = true },
        radar = { enabled = true, locked = false, x = 0, y = -150, anchor = "CENTER" },
        pruneAgeDays = 30,
        -- How close, in yards, a stored node of the same type has to be for a
        -- new capture to count as the same node rather than a new one. Without
        -- this, dedup happened only on an exact 3-decimal coordinate match, so
        -- gathering the same vein from a slightly different standing position
        -- left a second pin a few yards away. Values follow GatherMate2's
        -- cleanupRange; lumber is looser because tree trunks are large.
        cleanupRange = {
            herb = 15, ore = 15, fish = 15,
            treasure = 15, skin = 15, lumber = 20,
        },
        cleanupRangeDefault = 15,
        -- Record nodes the player walked up to but lacked the skill to gather.
        -- These are worth remembering precisely because you come back for them.
        captureFailedGathers = true,
        -- Show the imported reference dataset alongside the player's own
        -- captures. Turning this off also stops the band addons being loaded
        -- at all, so it is a memory switch as well as a display one.
        showImportedNodes = true,
        -- Cluster radius for the world-map pin grouper (configurable per-zoom).
        -- Pattern lifted from CityGuide/Clustering.lua. 60 ~= "small icon stack"
        -- on a continent map; lower it for crowded zones.
        clusterRadius = 60,
    }
}

-- DEFAULTS is a module-level table, so handing it out directly makes the live
-- settings table *be* the defaults: the first layer toggle or radar drag then
-- writes straight into DEFAULTS, and the forward-compat merge below starts
-- reading the player's own choices back as the "defaults" it merges in. Every
-- consumer gets a private copy instead.
local function CopyDefaults(source)
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CopyDefaults(value)
        else
            copy[key] = value
        end
    end
    return copy
end

-- Add any key present in `defaults` but missing from `target`, recursively.
-- Never overwrites a value the player already has: a merge that clobbers resets
-- every setting on the login after a new default lands.
local function FillMissing(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            FillMissing(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function H:ResolveStorage()
    -- 1. Get Node Data (Routes to Shard)
    if DataVault and DataVault.ShardAvailable and DataVault:ShardAvailable(SHARD_KEY) then
        self.db = DataVault:ShardGet("account", SHARD_KEY, ADDON_KEY, nil, {})
        self._storageBackend = "DataVault Shard"
    else
        _G.FabledUI_HarvestDB = _G.FabledUI_HarvestDB or {}
        self.db = _G.FabledUI_HarvestDB
        self._storageBackend = "Local Backup"
    end
    self.db.nodes = self.db.nodes or {}

    -- Stamp the node store so a future format change (packed integer coords,
    -- per-zone shards) has something to migrate *from*. Without a version on
    -- disk the only safe migration is none, since old and new records are
    -- indistinguishable. Existing saved data predates the stamp and is
    -- version 1 by definition.
    self.db.schemaVersion = self.db.schemaVersion or H.SCHEMA_VERSION

    -- 2. Get Settings (Maintained in core DataVault so UI config doesn't require Shard)
    if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
        DataVault:EnsureNamespace(ADDON_KEY)
        if not DataVault:Get("account", ADDON_KEY, "settings", nil) then
            DataVault:Set("account", ADDON_KEY, "settings", CopyDefaults(DEFAULTS.settings))
        end
        self.settings = DataVault:Get("account", ADDON_KEY, "settings", CopyDefaults(DEFAULTS.settings))
    else
        _G.FabledUI_HarvestSettings = _G.FabledUI_HarvestSettings or CopyDefaults(DEFAULTS.settings)
        self.settings = _G.FabledUI_HarvestSettings
    end

    -- Forward-compat: add every default the player's saved settings are missing.
    --
    -- This used to enumerate the keys by hand -- the layer loop plus a check for
    -- clusterRadius -- which meant each new setting silently failed to reach
    -- anyone with existing saved data until someone remembered to extend the
    -- block. Walking DEFAULTS instead makes that structural.
    FillMissing(self.settings, DEFAULTS.settings)
end

-- Find an already-stored node of the same type within `yards` of (x, y).
--
-- Rounding to 3 decimals only collapses captures from almost exactly the same
-- spot; a few steps to either side still produced a separate key, so a node
-- gathered repeatedly accumulated a small cluster of near-duplicate pins. The
-- yard conversion needs the zone's real dimensions -- normalised distance is
-- meaningless across zones of different sizes -- so when C_Map.GetMapWorldSize
-- is unavailable this returns nil and the exact-key behaviour stands.
function H:FindNearbyNode(mapID, x, y, nodeType, yards)
    local nodes = self.db and self.db.nodes and self.db.nodes[mapID]
    if not nodes or not yards or yards <= 0 then return nil end
    if not (C_Map and C_Map.GetMapWorldSize) then return nil end

    local ok, width, height = pcall(C_Map.GetMapWorldSize, mapID)
    if not ok or not width or not height or width == 0 or height == 0 then
        return nil
    end

    -- Compare in yards on both axes rather than in normalised units, so the
    -- radius stays circular on non-square maps.
    local radiusSq = yards * yards
    for coordKey, node in pairs(nodes) do
        if node and node.type == nodeType then
            local sx, sy = strsplit(",", coordKey)
            local nx, ny = tonumber(sx), tonumber(sy)
            if nx and ny then
                local dx = (nx - x) * width
                local dy = (ny - y) * height
                if dx * dx + dy * dy <= radiusSq then
                    return coordKey
                end
            end
        end
    end
    return nil
end

-- =============================================================================
-- Pruning
-- =============================================================================
-- The prune used to walk every node on every map inside the options panel's
-- OnClick. On a database that has been collecting for a season that is a long
-- single-frame stall, and it grows with exactly the data the addon is designed
-- to accumulate. Same fix GatherMate2 uses for its sweep: run it as a coroutine
-- that yields periodically, driven by an OnUpdate.

local PRUNE_YIELD_EVERY = 500

-- Yields (false, removedSoFar) periodically; returns (true, removed) at the end.
local function PruneWorker(self)
    local days = (self.settings and self.settings.pruneAgeDays) or 30
    local cutoff = time() - (days * 86400)
    local removed, scanned = 0, 0

    for _, nodes in pairs(self.db.nodes) do
        -- Clearing keys during pairs() is defined behaviour in Lua as long as
        -- nothing is *added*, and the coroutine keeps the iteration state across
        -- yields.
        for key, data in pairs(nodes) do
            if type(data) == "table" and data.lastSeen and data.lastSeen < cutoff then
                nodes[key] = nil
                removed = removed + 1
            end
            scanned = scanned + 1
            if scanned % PRUNE_YIELD_EVERY == 0 then
                coroutine.yield(false, removed)
            end
        end
    end

    return true, removed
end

local pruneFrame = CreateFrame("Frame")
pruneFrame.running = false

function H:IsPruneRunning()
    return pruneFrame.running == true
end

--- Abandon an in-flight prune and release the guard.
---
--- The running flag is what stops two prunes interleaving over the same tables,
--- but it is only cleared by the OnUpdate that drives the coroutine. If that
--- driver never runs to completion the flag stays set and pruning is disabled
--- for the rest of the session with no way to recover it. Nodes already removed
--- stay removed; this only stops the walk.
function H:CancelPrune()
    if not pruneFrame.running then return false end
    pruneFrame:SetScript("OnUpdate", nil)
    pruneFrame.running = false
    return true
end

-- Drain the prune to completion without yielding to the frame. Used by tests,
-- and as the fallback when there is no db to walk incrementally.
function H:PruneNodesSync()
    if not (self.db and self.db.nodes) then return 0 end
    local co = coroutine.create(PruneWorker)
    local removed = 0
    while true do
        local ok, done, count = coroutine.resume(co, self)
        if not ok then error(done, 0) end
        removed = count or removed
        if done then return removed end
    end
end

-- Start an incremental prune. Returns false if one is already running.
function H:PruneNodes(onComplete)
    if pruneFrame.running then return false end
    if not (self.db and self.db.nodes) then return false end

    local co = coroutine.create(PruneWorker)
    pruneFrame.running = true
    pruneFrame:SetScript("OnUpdate", function()
        local ok, done, removed = coroutine.resume(co, self)
        if not ok or done then
            pruneFrame:SetScript("OnUpdate", nil)
            pruneFrame.running = false
            if not ok then
                if self.Print then self:Print("Prune failed: " .. tostring(done)) end
                return
            end
            if DataVault and DataVault.dirtyFlags then
                DataVault.dirtyFlags[SHARD_KEY] = true
            end
            if self.MapProvider then self.MapProvider:RefreshPins() end
            if onComplete then onComplete(removed or 0) end
        end
    end)
    return true
end

function H:SaveNode(mapID, x, y, type, id, name)
    if not mapID or not x or not y then return end

    self.db.nodes[mapID] = self.db.nodes[mapID] or {}
    -- Create a fuzzy coordinate key (rounds to 3 decimal places to prevent micro-dupes)
    local coordKey = string.format("%.3f,%.3f", x, y)

    -- Collapse onto a nearby node of the same type when there is one, so the
    -- repeat capture refreshes the existing entry instead of adding a pin a few
    -- yards from the one already there.
    local ranges = (self.settings and self.settings.cleanupRange) or nil
    local radius = ranges and ranges[type]
    if radius == nil and self.settings then
        radius = self.settings.cleanupRangeDefault
    end
    local nearbyKey = self:FindNearbyNode(mapID, x, y, type, radius)
    if nearbyKey then
        coordKey = nearbyKey
    end

    local existed = self.db.nodes[mapID][coordKey] ~= nil

    self.db.nodes[mapID][coordKey] = {
        type = type,
        id = id,
        name = name,
        lastSeen = time()
    }

    if DataVault and DataVault.dirtyFlags then DataVault.dirtyFlags[SHARD_KEY] = true end
    if self.MapProvider then self.MapProvider:RefreshPins() end

    -- Update session counter immediately (cheap), but throttle the full
    -- radar rebuild — it walks every node on the current map and runs once
    -- per capture, which during a herb-rich run fires several times per
    -- second. C_Timer.After(0.5) coalesces bursts into one rebuild per
    -- 500ms while preserving "fresh < 300s" colour fidelity.
    --
    -- Only the *point list* is throttled here. Redrawing the blips against the
    -- player's moving position is the radar's own ticker, so the display keeps
    -- tracking between captures.
    if self.RadarHUD then
        if self.RadarHUD.UpdateSession then
            self.RadarHUD:UpdateSession(type, 1)
        end
        if self.RadarHUD.RebuildPoints and not self._radarRebuildPending then
            self._radarRebuildPending = true
            local function rebuild()
                self._radarRebuildPending = nil
                self.RadarHUD:RebuildPoints(mapID)
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, rebuild)
            else
                rebuild()
            end
        end
    end

    -- Quiet confirmation in chat the first time we capture a node at this coord
    if not existed and self.Print then
        self:Print(string.format("Captured %s node at %.1f, %.1f", type or "node", (x or 0) * 100, (y or 0) * 100))
    end
end