local A = Athena

-- ============================================================================
-- Util: DebouncedSave
-- Lifted from VGC (VamoosesGuildCraft/Core/Store.lua:75-95).
-- Coalesces rapid SV mutations into a single save per `delay` (default 1s).
-- PLAYER_LOGOUT flushes everything.
-- ============================================================================

A.Util = A.Util or {}
local U = A.Util

local timers = {}
local pending = {}
local DEFAULT_DELAY = 1.0

local function NewTimer(seconds, fn)
    if C_Timer and C_Timer.NewTimer then
        return C_Timer.NewTimer(seconds, fn)
    end
    fn()
    return nil
end

function U:DebouncedSave(name, delay, fn)
    if type(name) ~= "string" or name == "" then return end
    if type(fn) ~= "function" then return end
    delay = tonumber(delay) or DEFAULT_DELAY

    local existing = timers[name]
    if existing and existing.Cancel then
        existing:Cancel()
        timers[name] = nil
    end

    pending[name] = fn

    timers[name] = NewTimer(delay, function()
        timers[name] = nil
        local pendingFn = pending[name]
        pending[name] = nil
        if pendingFn then
            local ok, err = pcall(pendingFn)
            if not ok and A and A.Print then
                A.Print("|cffff5555DebouncedSave error (" .. name .. "):|r " .. tostring(err))
            end
        end
    end)
end

function U:Flush()
    for name, timer in pairs(timers) do
        if timer and timer.Cancel then timer:Cancel() end
        timers[name] = nil
        local fn = pending[name]
        pending[name] = nil
        if fn then pcall(fn) end
    end
end

function U:SaveSoon(name, fn)
    self:DebouncedSave(name, DEFAULT_DELAY, fn)
end

function A.DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[A.DeepCopy(key, seen)] = A.DeepCopy(item, seen)
    end
    return copy
end
