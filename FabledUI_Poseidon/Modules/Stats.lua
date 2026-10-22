local P = _G.FabledUI_Poseidon
if not P then return end

P.Stats = P.Stats or {}
local S = P.Stats

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, nested in pairs(value) do
        out[key] = DeepCopy(nested)
    end
    return out
end

local function NewBucket(label, mapID)
    return {
        name = label,
        mapID = mapID,
        casts = 0,
        catches = 0,
        fish = {},
        items = {},
        pools = {},
        startedAt = time(),
        updatedAt = time(),
    }
end

local function EnsureRoot()
    local root = P.db.stats or {}
    P.db.stats = root
    root.lifetime = root.lifetime or NewBucket("Lifetime", nil)
    root.session = root.session or NewBucket("Session", nil)
    root.zones = root.zones or {}
    root.pools = root.pools or {}
    root.sessions = root.sessions or {}
    return root
end

local function NormalizePool(poolName)
    if type(poolName) ~= "string" or poolName == "" then
        return "Open Water"
    end
    return poolName
end

local function GetZoneInfo(mapID)
    mapID = mapID or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or nil
    local mapName = P:GetMapName(mapID)
    local subZone = GetSubZoneText and GetSubZoneText() or nil
    local label = (type(subZone) == "string" and subZone ~= "") and subZone or mapName
    return {
        key = tostring(mapID or 0) .. ":" .. tostring(label or "Unknown"),
        mapID = mapID,
        mapName = mapName,
        subZone = subZone,
        label = label,
    }
end

local function EnsureZoneBucket(info)
    local root = EnsureRoot()
    local bucket = root.zones[info.key]
    if not bucket then
        bucket = NewBucket(info.label, info.mapID)
        root.zones[info.key] = bucket
    end
    bucket.name = info.label
    bucket.mapID = info.mapID
    bucket.mapName = info.mapName
    bucket.subZone = info.subZone
    return bucket
end

local function EnsurePoolBucket(poolName)
    local root = EnsureRoot()
    poolName = NormalizePool(poolName)
    local bucket = root.pools[poolName]
    if not bucket then
        bucket = NewBucket(poolName, nil)
        root.pools[poolName] = bucket
    end
    bucket.name = poolName
    return bucket
end

local function BumpBucket(bucket, mode, itemName, poolName, isFish)
    if not bucket then
        return
    end
    if mode == "cast" then
        bucket.casts = (bucket.casts or 0) + 1
    elseif mode == "catch" then
        bucket.catches = (bucket.catches or 0) + 1
        if type(itemName) == "string" and itemName ~= "" then
            local target = isFish and bucket.fish or bucket.items
            target[itemName] = (target[itemName] or 0) + 1
        end
        local normalizedPool = NormalizePool(poolName)
        bucket.pools[normalizedPool] = (bucket.pools[normalizedPool] or 0) + 1
    end
    bucket.updatedAt = time()
end

function S:Init()
    EnsureRoot()
end

function S:ResetSession()
    local root = EnsureRoot()
    local session = root.session
    if (session.casts or 0) > 0 or (session.catches or 0) > 0 then
        root.sessions[#root.sessions + 1] = DeepCopy(session)
        while #root.sessions > 20 do
            table.remove(root.sessions, 1)
        end
    end
    root.session = NewBucket("Session", nil)
    P:MarkDirty()
    return root.session
end

function S:TouchSession()
    local root = EnsureRoot()
    local session = root.session
    local timeoutMinutes = tonumber(P.settings.sessionTimeoutMinutes) or 20
    timeoutMinutes = math.max(5, math.min(timeoutMinutes, 120))
    local now = time()
    local lastActivity = session.updatedAt or session.startedAt or now
    if ((session.casts or 0) > 0 or (session.catches or 0) > 0) and (now - lastActivity) > (timeoutMinutes * 60) then
        session = self:ResetSession()
    end
    session.updatedAt = now
    return session
end

function S:RecordCast(context)
    local root = EnsureRoot()
    local session = self:TouchSession()
    local zoneInfo = GetZoneInfo(context and context.mapID)
    local zoneBucket = EnsureZoneBucket(zoneInfo)
    local poolBucket = EnsurePoolBucket(context and context.poolName)

    BumpBucket(root.lifetime, "cast")
    BumpBucket(session, "cast")
    BumpBucket(zoneBucket, "cast")
    BumpBucket(poolBucket, "cast")

    session.zoneName = zoneInfo.label
    session.mapID = zoneInfo.mapID
    session.mapName = zoneInfo.mapName
    session.lastPool = NormalizePool(context and context.poolName)
    P:MarkDirty()
end

function S:RecordCatch(itemName, context)
    if type(itemName) ~= "string" or itemName == "" then
        return
    end

    local root = EnsureRoot()
    local session = self:TouchSession()
    local zoneInfo = GetZoneInfo(context and context.mapID)
    local zoneBucket = EnsureZoneBucket(zoneInfo)
    local poolBucket = EnsurePoolBucket(context and context.poolName)
    local isFish = context and context.isFish == true

    BumpBucket(root.lifetime, "catch", itemName, context and context.poolName, isFish)
    BumpBucket(session, "catch", itemName, context and context.poolName, isFish)
    BumpBucket(zoneBucket, "catch", itemName, context and context.poolName, isFish)
    BumpBucket(poolBucket, "catch", itemName, context and context.poolName, isFish)

    session.zoneName = zoneInfo.label
    session.mapID = zoneInfo.mapID
    session.mapName = zoneInfo.mapName
    session.lastPool = NormalizePool(context and context.poolName)
    P:MarkDirty()
end

function S:GetCurrentZoneBucket()
    local info = GetZoneInfo()
    local root = EnsureRoot()
    return root.zones[info.key], info
end

function S:GetSuccessRate(bucket)
    bucket = type(bucket) == "table" and bucket or {}
    local casts = bucket.casts or 0
    local catches = bucket.catches or 0
    if casts <= 0 then
        return 0
    end
    return (catches / casts) * 100
end

function S:GetFishPerHour(bucket)
    bucket = type(bucket) == "table" and bucket or {}
    local startedAt = bucket.startedAt or time()
    local updatedAt = bucket.updatedAt or time()
    local elapsed = math.max(60, updatedAt - startedAt)
    return ((bucket.catches or 0) / elapsed) * 3600
end

function S:GetElapsedText(bucket)
    bucket = type(bucket) == "table" and bucket or {}
    local startedAt = bucket.startedAt or time()
    local updatedAt = bucket.updatedAt or time()
    local elapsed = math.max(0, updatedAt - startedAt)
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

function S:GetTopEntries(source, limit)
    local out = {}
    if type(source) ~= "table" then
        return out
    end
    for name, count in pairs(source) do
        out[#out + 1] = { name = name, count = count }
    end
    table.sort(out, function(a, b)
        if a.count == b.count then
            return a.name < b.name
        end
        return a.count > b.count
    end)
    if limit and #out > limit then
        while #out > limit do
            table.remove(out)
        end
    end
    return out
end

function S:GetOverviewData()
    local root = EnsureRoot()
    local zoneBucket, zoneInfo = self:GetCurrentZoneBucket()
    return {
        lifetime = root.lifetime,
        session = root.session,
        zone = zoneBucket or NewBucket(zoneInfo.label, zoneInfo.mapID),
        zoneInfo = zoneInfo,
    }
end

function S:GetZoneCards()
    local root = EnsureRoot()
    local out = {}
    for _, bucket in pairs(root.zones) do
        out[#out + 1] = bucket
    end
    table.sort(out, function(a, b)
        return (a.updatedAt or 0) > (b.updatedAt or 0)
    end)
    return out
end

function S:GetFishCards()
    local root = EnsureRoot()
    return self:GetTopEntries(root.lifetime.fish, 999)
end
