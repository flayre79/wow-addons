-- "Where do I go to find X?" — zone search over both node sources.
--
-- Two datasets answer this and they have very different shapes. The imported
-- reference set is large but its *counts* live in the always-loaded routing
-- index, so "which zones have the most herbs" is answerable instantly without
-- loading a single band addon. The player's own captures are small but carry
-- node names, so they are the only thing that can answer "where did I see a
-- Copper Vein".
--
-- Search therefore reads counts from the index and names from the player's
-- database, and never needs the bulk coordinates at all.

local H = FabledUI_Harvest
if not H then return end

H.Search = {}
local S = H.Search

-- Every layer Harvest renders, in display order.
S.LAYERS = { "herb", "ore", "lumber", "fish", "treasure", "skin" }

-- Words a player is likely to type for each layer. Matching these lets "mining"
-- or "wood" work without the player learning our internal layer keys.
local LAYER_ALIASES = {
    herb     = { "herb", "herbs", "herbalism", "herbing", "flower", "flowers" },
    ore      = { "ore", "ores", "mining", "mine", "mines", "metal", "vein" },
    lumber   = { "lumber", "timber", "wood", "logging", "log", "tree", "trees" },
    fish     = { "fish", "fishing", "pool", "pools" },
    treasure = { "treasure", "treasures", "chest", "chests", "loot" },
    skin     = { "skin", "skinning", "leather", "hide", "pelt" },
}

local aliasToLayer = {}
for layer, words in pairs(LAYER_ALIASES) do
    for _, word in ipairs(words) do
        aliasToLayer[word] = layer
    end
end

-- Zone names come from the client, not from our data files: baking them in
-- would mean shipping a name table that goes stale and needs localising.
local nameCache = {}

--- Resolve a map ID to a zone name. Overridable so tests need not depend on
--- whatever map data the environment happens to expose.
function S:ResolveMapName(mapID)
    if not mapID then return nil end
    if nameCache[mapID] ~= nil then
        return nameCache[mapID] or nil
    end

    local name
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info and info.name and info.name ~= "" then
            name = info.name
        end
    end
    -- Cache the miss too, as false: an unresolvable map is usually unresolvable
    -- for the whole session and this runs per row per keystroke.
    nameCache[mapID] = name or false
    return name
end

function S:ClearNameCache()
    nameCache = {}
end

--- The layer a search term names, or nil if it names no layer.
function S:LayerForTerm(term)
    if type(term) ~= "string" then return nil end
    return aliasToLayer[term:lower()]
end

--- Merge imported counts and player captures into one row per map.
---
--- Rows look like:
---   { mapID, imported = {layer=n}, captured = {layer=n}, names = {["Copper Vein"]=true} }
function S:BuildIndex()
    local rows = {}

    local index = H.NodeIndex and H.NodeIndex.zones
    if index then
        for mapID, entry in pairs(index) do
            local row = rows[mapID] or { mapID = mapID, imported = {}, captured = {}, names = {} }
            for key, value in pairs(entry) do
                if key ~= "addon" and type(value) == "number" then
                    row.imported[key] = (row.imported[key] or 0) + value
                end
            end
            rows[mapID] = row
        end
    end

    local nodes = H.db and H.db.nodes
    if nodes then
        for mapID, zone in pairs(nodes) do
            local row = rows[mapID] or { mapID = mapID, imported = {}, captured = {}, names = {} }
            for _, node in pairs(zone) do
                if type(node) == "table" and node.type then
                    row.captured[node.type] = (row.captured[node.type] or 0) + 1
                    if node.name and node.name ~= "" then
                        row.names[node.name] = true
                    end
                end
            end
            rows[mapID] = row
        end
    end

    return rows
end

local function countFor(row, layers)
    local imported, captured = 0, 0
    for layer, n in pairs(row.imported) do
        if not layers or layers[layer] then imported = imported + n end
    end
    for layer, n in pairs(row.captured) do
        if not layers or layers[layer] then captured = captured + n end
    end
    return imported, captured
end

--- Search for zones worth travelling to.
---
--- text  -- free text: a layer word ("mining"), a zone name, or a node name
--- opts  -- { layers = {herb=true,...}, limit = n }
---
--- Returns an array of result rows sorted by node count, richest first. An
--- empty query is a valid search: it means "rank everywhere I could go".
function S:Query(text, opts)
    opts = opts or {}
    local query = type(text) == "string" and text:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""

    -- Default to the layers the player actually has switched on, so the search
    -- cannot recommend a zone for a resource their map is hiding.
    local layers = opts.layers
    if layers == nil then
        layers = H.settings and H.settings.layers or nil
    end

    -- A query naming a layer narrows to that layer rather than filtering rows:
    -- "mining" means "rank zones by ore", not "zones whose name says mining".
    local termLayer = self:LayerForTerm(query)
    if termLayer then
        layers = { [termLayer] = true }
    end

    local results = {}
    for _, row in pairs(self:BuildIndex()) do
        local imported, captured = countFor(row, layers)
        local total = imported + captured
        if total > 0 then
            local name = self:ResolveMapName(row.mapID)
            local matched, matchedNames = false, nil

            if query == "" or termLayer then
                matched = true
            else
                if name and name:lower():find(query, 1, true) then
                    matched = true
                end
                -- Node names only exist for the player's own captures, so this
                -- is the branch that answers "where have I seen this before".
                for nodeName in pairs(row.names) do
                    if nodeName:lower():find(query, 1, true) then
                        matched = true
                        matchedNames = matchedNames or {}
                        matchedNames[#matchedNames + 1] = nodeName
                    end
                end
            end

            if matched then
                if matchedNames then table.sort(matchedNames) end
                results[#results + 1] = {
                    mapID = row.mapID,
                    name = name,
                    total = total,
                    imported = imported,
                    captured = captured,
                    layers = row.imported,
                    capturedLayers = row.captured,
                    matchedNames = matchedNames,
                }
            end
        end
    end

    table.sort(results, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        -- Stable tail-break so the list does not reshuffle between identical
        -- queries; an unnamed map sorts after a named one.
        local an, bn = a.name or "", b.name or ""
        if an ~= bn then return an < bn end
        return a.mapID < b.mapID
    end)

    local limit = opts.limit
    if limit and #results > limit then
        for index = #results, limit + 1, -1 do
            results[index] = nil
        end
    end

    return results
end

--- One-line summary of a result's layer breakdown, richest layer first.
function S:DescribeLayers(result)
    if not result then return "" end
    local parts = {}
    for _, layer in ipairs(self.LAYERS) do
        local n = (result.layers and result.layers[layer] or 0)
            + (result.capturedLayers and result.capturedLayers[layer] or 0)
        if n > 0 then
            parts[#parts + 1] = { layer = layer, n = n }
        end
    end
    table.sort(parts, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.layer < b.layer
    end)

    local out = {}
    for _, part in ipairs(parts) do
        out[#out + 1] = string.format("%s %d", part.layer, part.n)
    end
    return table.concat(out, "  ")
end
