local K = Kleos

-- ============================================================================
-- GroupScan
-- "Scans group for missing achievements, announces to chat."
--
-- Blizzard's comparison API is a single shared slot: you point it at one unit,
-- wait for INSPECT_ACHIEVEMENT_READY, read as many achievements as you like,
-- then clear it. So the scan is a serial queue with a timeout per unit — two
-- overlapping scans would silently read the wrong player's data.
--
-- The result is only announced when the player asks for it (the scan itself is
-- always started by a click or a slash command), which is what section 6 of
-- the PRD requires.
-- ============================================================================

K.GroupScan = K.GroupScan or {}
local G = K.GroupScan

G.state = G.state or { running = false, queue = {}, results = {}, achievements = {}, unit = nil }

local UNIT_TIMEOUT = 5

local function GroupUnits()
    local units = {}
    if type(IsInRaid) == "function" and IsInRaid() then
        local size = (type(GetNumGroupMembers) == "function") and (GetNumGroupMembers() or 0) or 0
        for index = 1, size do
            local unit = "raid" .. index
            if not (type(UnitIsUnit) == "function" and UnitIsUnit(unit, "player")) then
                units[#units + 1] = unit
            end
        end
    elseif type(IsInGroup) == "function" and IsInGroup() then
        local size = (type(GetNumGroupMembers) == "function") and (GetNumGroupMembers() or 0) or 0
        for index = 1, math.max(0, size - 1) do
            units[#units + 1] = "party" .. index
        end
    end
    return units
end

G.GroupUnits = GroupUnits

local function UnitScannable(unit)
    if type(UnitExists) == "function" and not UnitExists(unit) then return false end
    if type(UnitIsConnected) == "function" and not UnitIsConnected(unit) then return false end
    if type(CanInspect) == "function" and not CanInspect(unit) then return false end
    return true
end

-- ----------------------------------------------------------------------------
-- Scan
-- achievementIDs defaults to the achievements the current instance cares about,
-- which is the case the feature exists for ("who still needs this raid meta").
-- ----------------------------------------------------------------------------
function G:Scan(achievementIDs, onComplete)
    if self.state.running then
        K:Print("A group scan is already running.")
        return false
    end

    local ids = {}
    for _, id in ipairs(type(achievementIDs) == "table" and achievementIDs or {}) do
        local numeric = tonumber(id)
        if numeric then ids[#ids + 1] = numeric end
    end
    if #ids == 0 and K.Encounter then
        ids = K.Encounter:AchievementsInPlay()
    end
    if #ids == 0 then
        K:Print("No achievements selected to scan for.")
        return false
    end

    local units = {}
    for _, unit in ipairs(GroupUnits()) do
        if UnitScannable(unit) then units[#units + 1] = unit end
    end
    if #units == 0 then
        K:Print("No inspectable group members found.")
        return false
    end

    self.state = {
        running = true,
        queue = units,
        results = {},
        achievements = ids,
        unit = nil,
        onComplete = onComplete,
        startedAt = (type(GetTime) == "function") and GetTime() or 0,
    }

    self:Init()
    self:Next()
    return true
end

function G:Next()
    if not self.state.running then return end

    if self.state.unit then
        if type(ClearAchievementComparisonUnit) == "function" then
            pcall(ClearAchievementComparisonUnit)
        end
        self.state.unit = nil
    end

    local unit = table.remove(self.state.queue, 1)
    if not unit then return self:Finish() end

    if not UnitScannable(unit) then return self:Next() end

    self.state.unit = unit
    -- UnitName read here can be secret, and unitName is used as a results table
    -- key and concatenated into the scan token -- both raise on a secret value.
    -- Fall back to the unit token, which this addon constructed itself.
    local name = (type(UnitName) == "function") and UnitName(unit) or nil
    self.state.unitName = (K.Util and K.Util.IsUsableString(name)) and name or unit

    if type(SetAchievementComparisonUnit) ~= "function" then
        -- No comparison API: record the whole group as unknown rather than
        -- pretending everyone has everything.
        self.state.results[self.state.unitName] = { unknown = true }
        return self:Next()
    end

    local ok = pcall(SetAchievementComparisonUnit, unit)
    if not ok then return self:Next() end

    local token = unit .. tostring(self.state.startedAt) .. tostring(#self.state.queue)
    self.state.token = token
    if C_Timer and C_Timer.After then
        C_Timer.After(UNIT_TIMEOUT, function()
            -- Timed out waiting for INSPECT_ACHIEVEMENT_READY for this unit.
            if self.state.running and self.state.token == token then
                self.state.results[self.state.unitName] = { unknown = true }
                self:Next()
            end
        end)
    end
end

function G:OnComparisonReady()
    if not self.state.running or not self.state.unit then return end
    self.state.token = nil

    local missing = {}
    for _, achievementID in ipairs(self.state.achievements) do
        local completed
        if type(GetAchievementComparisonInfo) == "function" then
            completed = GetAchievementComparisonInfo(achievementID)
        end
        if not completed then missing[#missing + 1] = achievementID end
    end

    self.state.results[self.state.unitName or self.state.unit] = { missing = missing }
    self:Next()
end

function G:Finish()
    if not self.state.running then return end
    self.state.running = false
    if type(ClearAchievementComparisonUnit) == "function" then pcall(ClearAchievementComparisonUnit) end

    local summary = self:Summarise()
    if self.state.onComplete then
        local callback = self.state.onComplete
        self.state.onComplete = nil
        pcall(callback, summary)
    end
    return summary
end

-- achievementID -> list of player names missing it, plus the raw per-player rows.
function G:Summarise()
    local byAchievement = {}
    local unknown = {}
    for name, row in pairs(self.state.results or {}) do
        if row.unknown then
            unknown[#unknown + 1] = name
        else
            for _, achievementID in ipairs(row.missing or {}) do
                byAchievement[achievementID] = byAchievement[achievementID] or {}
                local bucket = byAchievement[achievementID]
                bucket[#bucket + 1] = name
            end
        end
    end
    for _, names in pairs(byAchievement) do table.sort(names) end
    table.sort(unknown)
    return { byAchievement = byAchievement, unknown = unknown, results = self.state.results }
end

-- Explicit user action: this is the "announce to chat" half of the feature.
function G:AnnounceSummary(summary)
    summary = summary or self:Summarise()
    local lines = 0
    for achievementID, names in pairs(summary.byAchievement or {}) do
        if lines >= 5 then break end
        K.Encounter:Announce(("%s: missing for %s"):format(K.Meta.AchievementName(achievementID), table.concat(names, ", ")), true)
        lines = lines + 1
    end
    if lines == 0 then
        K.Encounter:Announce("group scan: nobody is missing the tracked achievements", true)
    end
    if #(summary.unknown or {}) > 0 then
        K:Print("Could not inspect: " .. table.concat(summary.unknown, ", "))
    end
    return lines
end

function G:Init()
    if self._frame then return end
    local frame = CreateFrame("Frame")
    self._frame = frame
    -- Handler before registration, and registration through the guarded helper:
    -- a refused event must not leave the scan waiting for a reply that can
    -- never arrive.
    frame:SetScript("OnEvent", function(_, event)
        if event == "INSPECT_ACHIEVEMENT_READY" then
            K:SafeCall(function() G:OnComparisonReady() end)
        end
    end)
    K:RegisterEvents(frame, { "INSPECT_ACHIEVEMENT_READY" })
end
