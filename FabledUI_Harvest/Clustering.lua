-- =============================================================================
-- FabledUI Harvest: Pin clustering
-- =============================================================================
-- Greedy radius-based grouper adapted from CityGuide's Clustering.lua
-- (see .sample-addons/CityGuide/Clustering.lua:78-112).
--
-- Strategy:
--   * For each pin, if not yet assigned to a cluster, anchor a new cluster on it.
--   * Walk the remaining pins. If a pin is within `radius` of the anchor (and
--     does not opt out via `noCluster`), add it to the cluster.
--   * `pin.noCluster` always renders solo (single-element cluster).
--
-- The grouper is type-aware via an optional `groupBy` arg — by default we cluster
-- pins of the same node type together, leaving e.g. herbs and ore as separate
-- clusters even when they overlap on the map.
-- =============================================================================

local H = FabledUI_Harvest
if not H then return end

H.Clustering = H.Clustering or {}
local C = H.Clustering

-- Default cluster radius (map units, normalised 0..1 are tiny — we treat these
-- as raw pixel distance on a 1000-unit map. Tuneable per map zoom by passing a
-- second arg to ClusterPins).
C.DEFAULT_RADIUS = 60

-- Map normalised 0..1 coords are too small for euclidean comparison at radius=60,
-- so we operate in a virtual "1000px" space when pins arrive in [0,1] form.
local function NormaliseScale(pin)
    -- Heuristic: if both coords look like normalised 0..1, scale up.
    if pin.x and pin.y and pin.x <= 1 and pin.y <= 1 then
        return pin.x * 1000, pin.y * 1000
    end
    return pin.x or 0, pin.y or 0
end

local function Distance(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

-- ClusterPins(pins, radius[, groupBy])
--   pins:    array of pin tables. Each must have x, y (and optionally type, noCluster).
--   radius:  cluster radius in scaled units (defaults to DEFAULT_RADIUS).
--   groupBy: optional field name (e.g. "type"). When set, only pins sharing that
--            field value cluster together.
-- Returns an array of clusters; each cluster is itself an array of pins, plus
-- aggregate fields:
--    .x, .y     — anchor pin coordinates (canonical render position)
--    .type      — anchor type (for color coding)
--    .count     — number of pins in the cluster
--    .pins      — same array (alias for clarity)
function C:ClusterPins(pins, radius, groupBy)
    radius = radius or C.DEFAULT_RADIUS
    local clusters = {}
    if not pins or #pins == 0 then return clusters end

    local assigned = {}

    for i = 1, #pins do
        local pin = pins[i]
        if pin and not assigned[i] then
            -- Solo pins (noCluster flag) always emit a 1-pin cluster.
            if pin.noCluster then
                local cluster = { pin }
                cluster.x = pin.x
                cluster.y = pin.y
                cluster.type = pin.type
                cluster.count = 1
                cluster.pins = cluster
                table.insert(clusters, cluster)
                assigned[i] = true
            else
                local cluster = { pin }
                assigned[i] = true

                local ax, ay = NormaliseScale(pin)
                local groupKey = groupBy and pin[groupBy] or nil

                for j = i + 1, #pins do
                    local other = pins[j]
                    if other and not assigned[j] and not other.noCluster then
                        local groupOk = true
                        if groupBy then
                            groupOk = (other[groupBy] == groupKey)
                        end
                        if groupOk then
                            local bx, by = NormaliseScale(other)
                            if Distance(ax, ay, bx, by) < radius then
                                table.insert(cluster, other)
                                assigned[j] = true
                            end
                        end
                    end
                end

                cluster.x = pin.x
                cluster.y = pin.y
                cluster.type = pin.type
                cluster.count = #cluster
                cluster.pins = cluster
                table.insert(clusters, cluster)
            end
        end
    end

    return clusters
end

-- Convenience: build the "(N)" badge text for a cluster.
function C:GetClusterLabel(cluster)
    if not cluster or cluster.count <= 1 then return nil end
    return "(" .. cluster.count .. ")"
end
