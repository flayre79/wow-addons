-- Imported node locations: on-demand loading and lookup.
--
-- The generated dataset is ~196k nodes, far too much to keep resident. It is
-- split into LoadOnDemand band addons by map ID, with a small always-loaded
-- routing table (Data/NodeIndex.lua) saying which band owns a map and how many
-- nodes of each layer it holds. Entering a zone loads at most one band.
--
-- The index carries per-layer counts so the runtime can answer "is there
-- anything here?" without paying for the addon load at all -- which matters for
-- the majority of maps that have no data.
--
-- Imported nodes are strictly read-only reference data. They are never written
-- into the player's own database: a capture the player made carries a real
-- lastSeen and survives export, and blending a quarter million imported
-- coordinates into that would destroy both properties.

local H = FabledUI_Harvest
if not H then return end

-- [mapID] = { herb = { x, y, x, y, ... }, ore = { ... } }
-- Populated by the band addons' zone files as they load.
H.NodeData = H.NodeData or {}

local loadedBands = {}
local failedBands = {}

--- The index entry for a map, or nil when the map has no imported data.
function H:GetNodeIndexEntry(mapID)
    if not mapID then return nil end
    local index = self.NodeIndex
    if not (index and index.zones) then return nil end
    return index.zones[mapID]
end

--- True when a map has imported nodes, whether or not they are loaded yet.
function H:HasImportedNodes(mapID)
    return self:GetNodeIndexEntry(mapID) ~= nil
end

--- Load the band addon owning `mapID`. Returns loaded, reason.
---
--- Safe to call repeatedly: an already-loaded or already-failed band short
--- circuits, so this can sit directly on a zone-change event.
function H:LoadNodeDataForMap(mapID)
    local entry = self:GetNodeIndexEntry(mapID)
    if not entry then return false, "no data for map" end

    local addon = entry.addon
    if not addon then return false, "index entry has no addon" end
    if loadedBands[addon] then return true, "already loaded" end
    if failedBands[addon] then return false, failedBands[addon] end

    local loader = C_AddOns and C_AddOns.LoadAddOn
    if not loader then return false, "no addon loader" end

    local ok, loaded, reason = pcall(loader, addon)
    if not ok then
        failedBands[addon] = tostring(loaded)
        return false, tostring(loaded)
    end
    if not loaded then
        -- Remember the refusal. A band the player has disabled or deleted
        -- would otherwise be retried on every zone change forever.
        failedBands[addon] = tostring(reason or "refused")
        return false, failedBands[addon]
    end

    loadedBands[addon] = true
    return true, "loaded"
end

--- The imported layers for a map, or nil. Does not trigger a load.
function H:GetImportedNodes(mapID)
    if not mapID then return nil end
    return self.NodeData[mapID]
end

--- Call `fn(x, y)` for each imported node of `layer` on `mapID`.
---
--- The generated files store flat x,y pairs rather than a table per node --
--- a quarter of a million two-field tables is a great deal of allocation for
--- data only ever read positionally -- so iteration steps in twos.
function H:ForEachImportedNode(mapID, layer, fn)
    local zone = self:GetImportedNodes(mapID)
    if not zone then return 0 end
    local coords = zone[layer]
    if not coords then return 0 end

    local count = 0
    for index = 1, #coords - 1, 2 do
        local x, y = coords[index], coords[index + 1]
        if x and y then
            count = count + 1
            fn(x, y)
        end
    end
    return count
end

--- Total imported nodes on a map across every layer the player has enabled.
function H:CountImportedNodes(mapID)
    local entry = self:GetNodeIndexEntry(mapID)
    if not entry then return 0 end
    local layers = self.settings and self.settings.layers
    local total = 0
    for key, value in pairs(entry) do
        if key ~= "addon" and type(value) == "number" then
            if not layers or layers[key] then
                total = total + value
            end
        end
    end
    return total
end

-- Load the band for whatever zone the player is standing in. Handler before
-- registration: a frame must never hold a live registration with no handler.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function()
    if H.settings and H.settings.showImportedNodes == false then return end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    if not H:HasImportedNodes(mapID) then return end

    local loaded = H:LoadNodeDataForMap(mapID)
    if loaded then
        if H.MapProvider then H.MapProvider:RefreshPins() end
        if H.RadarHUD and H.RadarHUD.RebuildPoints then H.RadarHUD:RebuildPoints(mapID) end
    end
end)
watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")

H._nodeDataWatcher = watcher
