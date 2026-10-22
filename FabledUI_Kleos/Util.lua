local K = Kleos

-- ============================================================================
-- Util: DebouncedSave
-- Lifted from VGC (VamoosesGuildCraft/Core/Store.lua:75-95).
-- Coalesces rapid SV mutations into a single save per `delay` (default 1s).
-- Each save is identified by `name`; calling DebouncedSave with the same name
-- cancels any pending timer for that key. PLAYER_LOGOUT flushes everything.
-- ============================================================================

K.Util = K.Util or {}
local U = K.Util

local timers = {}   -- name -> C_Timer.NewTimer handle
local pending = {}  -- name -> last queued function

local DEFAULT_DELAY = 1.0

local function NewTimer(seconds, fn)
    if C_Timer and C_Timer.NewTimer then
        return C_Timer.NewTimer(seconds, fn)
    end
    -- Last-resort fallback: invoke synchronously (no debounce available)
    fn()
    return nil
end

function U:DebouncedSave(name, delay, fn)
    if type(name) ~= "string" or name == "" then return end
    if type(fn) ~= "function" then return end
    delay = tonumber(delay) or DEFAULT_DELAY

    -- Cancel any existing timer for this key
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
            if not ok and K and K.Print then
                K:Print("|cffff5555DebouncedSave error (" .. name .. "):|r " .. tostring(err))
            end
        end
    end)
end

-- Flush all pending debounced saves immediately.
function U:Flush()
    for name, timer in pairs(timers) do
        if timer and timer.Cancel then timer:Cancel() end
        timers[name] = nil
        local fn = pending[name]
        pending[name] = nil
        if fn then pcall(fn) end
    end
end

-- Convenience: route a Kleos SV save through the debouncer.
-- Pass a save-name and the function that performs the actual flush.
function U:SaveSoon(name, fn)
    self:DebouncedSave(name, DEFAULT_DELAY, fn)
end

-- ============================================================================
-- Util: secret values (12.x / Midnight)
-- Unit tokens, GUIDs and names read from a tainted execution path arrive as
-- "secret" values. They report type "string" but throw the moment they are
-- split, concatenated, used as a table key, or passed to a unit API. There is
-- no way to unwrap one -- the only correct move is to stop. Guard here so
-- callers only ever see a real string or nil.
-- Shimmed so the file still loads on pre-12.x clients.
-- ============================================================================

local issecretvalue = _G.issecretvalue or function() return false end

function U.IsSecret(value)
    return issecretvalue(value) and true or false
end

-- True when `value` is a plain, usable string (not nil, not secret).
--
-- Order matters and is not negotiable: issecretvalue has to be the first thing
-- that touches the value. Even `value ~= ""` raises on a secret string
-- ("attempt to compare ... a secret string value"), so a guard that tests
-- emptiness first throws inside the very function written to stop throwing.
-- type() is the one other operation that is safe on one -- it answers "string".
function U.IsUsableString(value)
    if issecretvalue(value) then return false end
    if type(value) ~= "string" then return false end
    return value ~= ""
end

-- UnitGUID(unit) that returns nil instead of throwing when either the unit
-- token or the resulting GUID is secret.
function U.SafeUnitGUID(unit)
    if not U.IsUsableString(unit) then return nil end
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not U.IsUsableString(guid) then return nil end
    return guid
end

-- Returns `value` when it is a plain string, otherwise `fallback` (default
-- ""). For display sites: tostring() on a secret value throws exactly the way
-- concatenation does, so it is not the safe wrapper it looks like.
function U.SafeText(value, fallback)
    if U.IsUsableString(value) then return value end
    if type(value) == "number" then return tostring(value) end
    return fallback or ""
end
