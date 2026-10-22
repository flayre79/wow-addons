local addonName, ns = ...
local O = ns.Odyssey

-- Real route-order optimizer for Odyssey tours / routes.
-- Strategy: convert each waypoint to world coordinates once via HereBeDragons-2.0,
-- run a greedy nearest-neighbor tour starting at the player position, then
-- improve the result with 2-opt edge swaps until no improvement (or 5 passes).
--
-- The functions intentionally accept and return *plain waypoint records* so
-- the caller can substitute in waypoint IDs (Tours module) or raw {x,y,mapID}
-- entries (external integrations) without coupling to a particular schema.

local Optimizer = {}
O.Services.RouteOptimizer = Optimizer

local function GetHBD()
    if LibStub and LibStub.GetLibrary then
        local ok, hbd = pcall(LibStub.GetLibrary, LibStub, "HereBeDragons-2.0", true)
        if ok then
            return hbd
        end
    end
    return nil
end

-- Returns world coordinates (wx, wy, instanceID) or nil. Caches the result on
-- the waypoint record under `_worldX` / `_worldY` / `_worldInstance` to avoid
-- repeated HBD calls on every distance probe.
local function ToWorldCoords(waypoint, hbd)
    if type(waypoint) ~= "table" then
        return nil
    end

    if waypoint._worldX and waypoint._worldY then
        return waypoint._worldX, waypoint._worldY, waypoint._worldInstance
    end

    local x = tonumber(waypoint.x) or 0
    local y = tonumber(waypoint.y) or 0
    local mapID = tonumber(waypoint.mapID) or 0

    if hbd and hbd.GetWorldCoordinatesFromZone and mapID > 0 then
        local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(x, y, mapID)
        if wx and wy then
            waypoint._worldX, waypoint._worldY, waypoint._worldInstance = wx, wy, inst
            return wx, wy, inst
        end
    end

    -- Fallback when HBD is missing or returns nil: treat normalized zone
    -- coordinates as if they were world space. Routes within a single zone
    -- still optimize correctly because the relative ordering is preserved.
    waypoint._worldX, waypoint._worldY, waypoint._worldInstance = x, y, mapID
    return x, y, mapID
end

local function DistSq(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end

local function ResolveStartCoords(playerX, playerY, mapID, hbd)
    if playerX and playerY then
        if mapID and mapID > 0 and hbd and hbd.GetWorldCoordinatesFromZone then
            local wx, wy = hbd:GetWorldCoordinatesFromZone(playerX, playerY, mapID)
            if wx and wy then
                return wx, wy
            end
        end
        return playerX, playerY
    end

    if O and O.GetPlayerMapPosition then
        local pMap, px, py = O:GetPlayerMapPosition()
        if pMap and px and py then
            if hbd and hbd.GetWorldCoordinatesFromZone then
                local wx, wy = hbd:GetWorldCoordinatesFromZone(px, py, pMap)
                if wx and wy then
                    return wx, wy
                end
            end
            return px, py
        end
    end
    return nil, nil
end

-- Greedy nearest-neighbor reorder.
-- Inputs: array of waypoint records ({x, y, mapID, ...}); optional player
-- starting position in zone-normalized coords against `mapID`.
-- Returns: a new array with the same elements re-ordered, or nil if the
-- input was malformed.
function Optimizer.NearestNeighbor(waypoints, playerX, playerY, mapID)
    if type(waypoints) ~= "table" or #waypoints < 2 then
        return waypoints
    end

    local hbd = GetHBD()

    -- Pre-compute world coords on every waypoint so DistSq calls stay O(1).
    for _, wp in ipairs(waypoints) do
        ToWorldCoords(wp, hbd)
    end

    local startX, startY = ResolveStartCoords(playerX, playerY, mapID, hbd)
    -- If player position can't be resolved, anchor on the first waypoint.
    if not (startX and startY) then
        startX, startY = ToWorldCoords(waypoints[1], hbd)
    end

    local n = #waypoints
    local visited = {}
    local result = {}
    local cx, cy = startX, startY

    for _ = 1, n do
        local bestIdx, bestDist = nil, math.huge
        for i = 1, n do
            if not visited[i] then
                local wx, wy = waypoints[i]._worldX, waypoints[i]._worldY
                local d = DistSq(cx, cy, wx, wy)
                if d < bestDist then
                    bestDist = d
                    bestIdx = i
                end
            end
        end
        if not bestIdx then
            break
        end
        visited[bestIdx] = true
        local picked = waypoints[bestIdx]
        result[#result + 1] = picked
        cx, cy = picked._worldX, picked._worldY
    end

    return result
end

-- 2-opt improvement: for every pair (i, j) try reversing the segment
-- result[i+1 .. j] and keep it if it shortens the route. Loops until no
-- improvement is found or after `maxPasses` (default 5) iterations.
function Optimizer.TwoOpt(orderedList, maxPasses)
    if type(orderedList) ~= "table" then
        return orderedList
    end
    local n = #orderedList
    if n < 4 then
        return orderedList
    end

    maxPasses = tonumber(maxPasses) or 5
    local pass = 0
    local improved = true
    while improved and pass < maxPasses do
        improved = false
        pass = pass + 1
        for i = 1, n - 2 do
            for j = i + 2, n - 1 do
                local a = orderedList[i]
                local b = orderedList[i + 1]
                local c = orderedList[j]
                local d = orderedList[j + 1]
                if a and b and c and d then
                    local before = DistSq(a._worldX, a._worldY, b._worldX, b._worldY)
                                 + DistSq(c._worldX, c._worldY, d._worldX, d._worldY)
                    local after = DistSq(a._worldX, a._worldY, c._worldX, c._worldY)
                                + DistSq(b._worldX, b._worldY, d._worldX, d._worldY)
                    if after < before - 1e-9 then
                        local left, right = i + 1, j
                        while left < right do
                            orderedList[left], orderedList[right] = orderedList[right], orderedList[left]
                            left = left + 1
                            right = right - 1
                        end
                        improved = true
                    end
                end
            end
        end
    end
    return orderedList
end

-- Convenience: run NN then 2-opt and return the optimized list.
function Optimizer.Optimize(waypoints, playerX, playerY, mapID)
    local ordered = Optimizer.NearestNeighbor(waypoints, playerX, playerY, mapID)
    if type(ordered) == "table" and #ordered >= 4 then
        Optimizer.TwoOpt(ordered, 5)
    end
    return ordered
end

-- Strip the per-record world-coord cache so optimizer state isn't persisted
-- back into the saved DB by accident.
function Optimizer.StripCache(list)
    if type(list) ~= "table" then
        return list
    end
    for _, wp in ipairs(list) do
        if type(wp) == "table" then
            wp._worldX = nil
            wp._worldY = nil
            wp._worldInstance = nil
        end
    end
    return list
end

-- Optimize an active tour's waypoint list in-place by reordering its
-- waypointIDs. Returns true when reordering changed something.
function Optimizer:OptimizeTour(tour)
    if type(tour) ~= "table" or type(tour.waypointIDs) ~= "table" or #tour.waypointIDs < 3 then
        return false
    end
    if not O.Services or not O.Services.WaypointService then
        return false
    end

    local svc = O.Services.WaypointService
    local resolved = {}
    for _, wpID in ipairs(tour.waypointIDs) do
        local wp = svc:GetWaypointByID(wpID)
        if wp then
            resolved[#resolved + 1] = {
                id = wp.id,
                x = wp.x,
                y = wp.y,
                mapID = wp.mapID,
            }
        end
    end

    if #resolved < 3 then
        return false
    end

    local pMap, px, py = O:GetPlayerMapPosition()
    local optimized = Optimizer.Optimize(resolved, px, py, pMap)
    if type(optimized) ~= "table" or #optimized ~= #resolved then
        Optimizer.StripCache(resolved)
        return false
    end

    local changed = false
    for index, entry in ipairs(optimized) do
        if tour.waypointIDs[index] ~= entry.id then
            changed = true
            break
        end
    end

    if changed then
        local newOrder = {}
        for index, entry in ipairs(optimized) do
            newOrder[index] = entry.id
        end
        tour.waypointIDs = newOrder
        tour.updatedAt = time()
        if O.MarkDirty then
            O:MarkDirty()
        end
    end

    Optimizer.StripCache(resolved)
    Optimizer.StripCache(optimized)
    return changed
end

-- Optimize an arbitrary list of {x, y, mapID, ...} payloads (used by
-- Core:ReplaceRoute when routeOptimizationMode == "auto"). Returns the
-- reordered list, never nil.
function Optimizer:OptimizeEntries(entries, playerX, playerY, mapID)
    if type(entries) ~= "table" or #entries < 3 then
        return entries
    end

    local probes = {}
    for index, entry in ipairs(entries) do
        local payload = (type(entry) == "table" and type(entry.payload) == "table") and entry.payload or entry
        probes[index] = {
            _origin = entry,
            x = tonumber(payload.x) or 0,
            y = tonumber(payload.y) or 0,
            mapID = tonumber(payload.mapID) or tonumber(payload.uiMapID) or 0,
        }
    end

    local optimized = Optimizer.Optimize(probes, playerX, playerY, mapID)
    if type(optimized) ~= "table" or #optimized ~= #entries then
        Optimizer.StripCache(probes)
        return entries
    end

    local result = {}
    for index, probe in ipairs(optimized) do
        result[index] = probe._origin
    end

    Optimizer.StripCache(probes)
    return result
end

function Optimizer:IsAutoMode()
    return O.db and O.db.settings and O.db.settings.routeOptimizationMode == "auto" or false
end
