-- ============================================================
-- Nemesis_Respawn.lua
--
-- Per-entity respawn-timer tracking and stale-sighting cleanup.
--
-- Records every sighting (timestamp + rolling-average respawn
-- window) and exposes helpers used by Alerts.lua and Explorer.lua
-- to display "~12m" / "last killed: 3h ago" style strings.
--
-- Auto-clears stale sightings whose lastSeen exceeds a configurable
-- threshold (default 7 days) AND whose typical respawn is short
-- (<2h). RareScanner-inspired pattern: short-cycle rares that
-- haven't been seen in a week were almost certainly killed and
-- the cached sighting is no longer informative.
-- ============================================================

local N = Nemesis
N.Respawn = {}
local R = N.Respawn

-- Default tuning (override via N.settings.respawn.*)
R.DEFAULT_THRESHOLD_DAYS = 7
R.DEFAULT_SHORT_RESPAWN_SECONDS = 2 * 60 * 60   -- "<2 hours" rule
R.MAX_SAMPLES = 12                              -- rolling window depth
R.MIN_SAMPLES_FOR_AVG = 2

-- Sanity bounds: ignore deltas outside [30s, 7d] when updating the rolling
-- average. Server hiccups, log-out gaps, and same-frame double-fires
-- otherwise corrupt the average.
R.MIN_DELTA = 30
R.MAX_DELTA = 7 * 24 * 60 * 60

local function EnsureSettings()
    N.settings = N.settings or {}
    if type(N.settings.respawn) ~= "table" then
        N.settings.respawn = {}
    end
    local s = N.settings.respawn
    if s.autoClearStale == nil then s.autoClearStale = true end
    if type(s.staleThresholdDays) ~= "number" or s.staleThresholdDays <= 0 then
        s.staleThresholdDays = R.DEFAULT_THRESHOLD_DAYS
    end
    if type(s.shortRespawnSeconds) ~= "number" or s.shortRespawnSeconds <= 0 then
        s.shortRespawnSeconds = R.DEFAULT_SHORT_RESPAWN_SECONDS
    end
    return s
end

local function EnsureRespawnTable()
    N.db = N.db or {}
    if type(N.db.respawn) ~= "table" then
        N.db.respawn = {}
    end
    return N.db.respawn
end

-- ------------------------------------------------------------
-- Recording
-- ------------------------------------------------------------

-- Record a sighting and update the rolling-average respawn window.
-- Called by Alerts.lua whenever a vignette fires (in addition to the
-- existing N:RecordSighting call which only stores last/count).
function R:RecordSighting(entityID, mapID)
    entityID = tonumber(entityID)
    if not entityID then return end

    local respawnDB = EnsureRespawnTable()
    local now = time()

    local record = respawnDB[entityID]
    if type(record) ~= "table" then
        record = {
            firstSeen = now,
            lastSeen  = now,
            killCount = 1,
            samples   = {},
            avgRespawn = 0,
            mapID = mapID,
        }
        respawnDB[entityID] = record
        if N.MarkShardDirty then N:MarkShardDirty() end
        return record
    end

    local previous = tonumber(record.lastSeen) or 0
    local delta = now - previous

    record.killCount = (tonumber(record.killCount) or 0) + 1
    record.lastSeen  = now
    if mapID then record.mapID = mapID end

    if previous > 0 and delta >= R.MIN_DELTA and delta <= R.MAX_DELTA then
        record.samples = record.samples or {}
        record.samples[#record.samples + 1] = delta
        while #record.samples > R.MAX_SAMPLES do
            table.remove(record.samples, 1)
        end

        if #record.samples >= R.MIN_SAMPLES_FOR_AVG then
            local sum = 0
            for _, v in ipairs(record.samples) do sum = sum + v end
            record.avgRespawn = math.floor(sum / #record.samples)
        end
    end

    if N.MarkShardDirty then N:MarkShardDirty() end
    return record
end

-- ------------------------------------------------------------
-- Read accessors
-- ------------------------------------------------------------

function R:GetRecord(entityID)
    entityID = tonumber(entityID)
    if not entityID then return nil end
    local respawnDB = EnsureRespawnTable()
    return respawnDB[entityID]
end

function R:GetAverageRespawn(entityID)
    local record = self:GetRecord(entityID)
    if record and tonumber(record.avgRespawn) and record.avgRespawn > 0 then
        return record.avgRespawn
    end
    return nil
end

function R:GetLastSeen(entityID)
    local record = self:GetRecord(entityID)
    return record and tonumber(record.lastSeen) or nil
end

-- ------------------------------------------------------------
-- Formatting helpers (used by Explorer column)
-- ------------------------------------------------------------

local function FormatDuration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "-" end
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 60 * 60 then
        return string.format("~%dm", math.floor(seconds / 60 + 0.5))
    elseif seconds < 24 * 60 * 60 then
        local h = seconds / 3600
        return string.format("~%.1fh", h)
    else
        local d = seconds / (24 * 3600)
        return string.format("~%.1fd", d)
    end
end

local function FormatAgo(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "just now" end
    if seconds < 60 then
        return string.format("%ds ago", seconds)
    elseif seconds < 60 * 60 then
        return string.format("%dm ago", math.floor(seconds / 60))
    elseif seconds < 24 * 60 * 60 then
        return string.format("%dh ago", math.floor(seconds / 3600))
    else
        return string.format("%dd ago", math.floor(seconds / 86400))
    end
end

R.FormatDuration = FormatDuration
R.FormatAgo = FormatAgo

-- Returns ("~12m", "last killed: 3h ago") for the Explorer "Respawns" column.
-- Either component may be "-" if data is missing.
function R:GetExplorerStrings(entityID)
    local record = self:GetRecord(entityID)
    if not record then
        return "-", "-"
    end

    local avgStr = "-"
    if tonumber(record.avgRespawn) and record.avgRespawn > 0 then
        avgStr = FormatDuration(record.avgRespawn)
    end

    local agoStr = "-"
    if tonumber(record.lastSeen) and record.lastSeen > 0 then
        agoStr = "last killed: " .. FormatAgo(time() - record.lastSeen)
    end

    return avgStr, agoStr
end

-- ------------------------------------------------------------
-- Stale-sighting cleanup
-- ------------------------------------------------------------

-- A sighting is stale when:
--   1. It has not been refreshed within `thresholdSeconds` AND
--   2. Its average respawn is short (< shortRespawnSeconds) OR we
--      lack any average and the entity is presumed short-cycle.
--
-- We deliberately preserve long-cycle rares (Time-Lost Proto-Drake
-- scale) because their cached coords remain useful for weeks.
function R:IsRecordStale(entityID, settings, now)
    local record = self:GetRecord(entityID)
    if not record then return false end

    settings = settings or EnsureSettings()
    now = now or time()

    local thresholdSeconds = (tonumber(settings.staleThresholdDays) or R.DEFAULT_THRESHOLD_DAYS) * 86400
    local shortRespawn     = tonumber(settings.shortRespawnSeconds) or R.DEFAULT_SHORT_RESPAWN_SECONDS

    local lastSeen = tonumber(record.lastSeen) or 0
    if lastSeen <= 0 then return false end

    if (now - lastSeen) < thresholdSeconds then
        return false
    end

    local avg = tonumber(record.avgRespawn) or 0
    if avg > 0 and avg >= shortRespawn then
        -- Long-cycle rare; keep the cached sighting around.
        return false
    end

    return true
end

-- Clears stale sightings from db.respawn AND db.sightings (so that the
-- Map and Explorer no longer show "Seen N times" for rares we lost
-- track of). Returns the number of records cleared.
function R:CleanupStaleSightings(force)
    local settings = EnsureSettings()
    if not force and not settings.autoClearStale then
        return 0
    end

    local respawnDB = EnsureRespawnTable()
    local now = time()
    local cleared = 0

    for entityID, _ in pairs(respawnDB) do
        if self:IsRecordStale(entityID, settings, now) then
            respawnDB[entityID] = nil
            if N.db and N.db.sightings then
                N.db.sightings[tonumber(entityID)] = nil
            end
            cleared = cleared + 1
        end
    end

    if cleared > 0 then
        if N.MarkShardDirty then N:MarkShardDirty() end
        if N.Map and N.Map.RefreshPins then N.Map:RefreshPins() end
        if N.Explorer and N.Explorer.Refresh then N.Explorer:Refresh(false) end
    end

    return cleared
end

-- ------------------------------------------------------------
-- Init
-- ------------------------------------------------------------

function R:Init()
    EnsureSettings()
    EnsureRespawnTable()

    -- One sweep at login; cheap (just a pairs walk).
    self:CleanupStaleSightings(false)

    -- Hourly maintenance keeps the data warm without spamming the
    -- player. The repeating timer is GC-rooted by C_Timer.
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(60 * 60, function()
            R:CleanupStaleSightings(false)
        end)
    end
end
