local P = _G.FabledUI_Poseidon
if not P then return end

P.Counters = P.Counters or {}
local C = P.Counters

local function DayKey()
    local t = date("*t", time())
    return (t.year * 10000) + (t.month * 100) + t.day
end

function P:GetWeeklyResetId()
    local now = (GetServerTime and GetServerTime()) or time()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local untilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if type(untilReset) == "number" and untilReset >= 0 then
            return math.floor((now + untilReset) / 604800)
        end
    end
    return math.floor(now / 604800)
end

function C:Increment(fishName)
    if type(fishName) ~= "string" or fishName == "" then
        return
    end

    local counts = P.db and P.db.counts
    if not counts then
        return
    end

    local dayKey = DayKey()
    local weekKey = P:GetWeeklyResetId()

    counts[dayKey] = counts[dayKey] or {}
    counts[dayKey][fishName] = (counts[dayKey][fishName] or 0) + 1

    counts[weekKey] = counts[weekKey] or {}
    counts[weekKey][fishName] = (counts[weekKey][fishName] or 0) + 1

    counts.lifetime = counts.lifetime or {}
    counts.lifetime[fishName] = (counts.lifetime[fishName] or 0) + 1
    P:MarkDirty()
end

function C:GetStats(fishName)
    local counts = P.db and P.db.counts
    if not counts or type(fishName) ~= "string" then
        return 0, 0, 0
    end

    local day = counts[DayKey()] and counts[DayKey()][fishName] or 0
    local week = counts[P:GetWeeklyResetId()] and counts[P:GetWeeklyResetId()][fishName] or 0
    local lifetime = counts.lifetime and counts.lifetime[fishName] or 0
    return day, week, lifetime
end
