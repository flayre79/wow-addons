local I = Iris

-- ============================================================================
-- Util: DebouncedSave
-- Lifted from VGC (VamoosesGuildCraft/Core/Store.lua:75-95).
-- Coalesces rapid SV mutations into a single save per `delay` (default 1s).
-- PLAYER_LOGOUT flushes everything.
-- ============================================================================

I.Util = I.Util or {}
local U = I.Util

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
            if not ok and I and I.Print then
                I:Print("|cffff5555DebouncedSave error (" .. name .. "):|r " .. tostring(err))
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
