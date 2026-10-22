local M = _G.FabledUI_Crafty
M.Util = M.Util or {}
local U = M.Util

function U:TableCount(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do
        n = n + 1
    end
    return n
end

function U:SortedKeys(tbl, sortFunc)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, sortFunc)
    return keys
end

function U:MoneyToString(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%dg %ds %dc", gold, silver, c)
end

function U:ColorText(text, color)
    if not color then
        return tostring(text)
    end
    return color:WrapTextInColorCode(tostring(text))
end

function U:SafeString(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

function U:Now()
    return time()
end

function U:StartsWith(str, prefix)
    return type(str) == "string" and type(prefix) == "string" and str:sub(1, #prefix) == prefix
end

-- P0-4: named, debounced one-shot snapshot. Pattern lifted from
-- ThendarsLumberTracker.lua:12349-12366. Multiple events that could fire
-- in rapid succession (BAG_UPDATE_DELAYED, PLAYER_EQUIPMENT_CHANGED,
-- TRADE_SKILL_LIST_UPDATE) should land a single deferred refresh, not
-- one refresh per event. Each named slot collapses concurrent calls.
local _pendingSnapshots = {}

function U:DebounceSnapshot(name, delay, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then
        return
    end
    delay = tonumber(delay) or 0
    -- Bump the token so any in-flight C_Timer callback sees its token is
    -- stale and bails out cheaply. Combined with the early-return below,
    -- a burst of N calls fires fn exactly once `delay` seconds after the
    -- last call.
    local token = (_pendingSnapshots[name] or 0) + 1
    _pendingSnapshots[name] = token

    if not C_Timer or not C_Timer.After then
        fn()
        return
    end

    C_Timer.After(delay, function()
        if _pendingSnapshots[name] ~= token then
            return
        end
        _pendingSnapshots[name] = nil
        local ok, err = pcall(fn)
        if not ok and err and M.Print then
            M:Print("DebounceSnapshot(" .. name .. ") failed: " .. tostring(err))
        end
    end)
end

function U:CancelDebouncedSnapshot(name)
    _pendingSnapshots[name] = nil
end

-- P2-16: 5-arg vs 4-arg shim around C_Item.GetItemCount. The 5-arg form
-- (with includeAccountBank) is post-11.0; older builds throw. Pattern from
-- .sample-addons/CraftingOrders++/Core.lua:108-120.
function U:GetItemCountSafe(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank)
    if not itemID or not C_Item or not C_Item.GetItemCount then
        return 0
    end
    if includeBank == nil then includeBank = true end
    if includeReagentBank == nil then includeReagentBank = true end
    if includeAccountBank == nil then includeAccountBank = true end

    local ok, count = pcall(C_Item.GetItemCount, itemID, includeBank, includeUses or false, includeReagentBank, includeAccountBank)
    if ok and type(count) == "number" then
        return count
    end
    ok, count = pcall(C_Item.GetItemCount, itemID, includeBank, includeUses or false, includeReagentBank)
    if ok and type(count) == "number" then
        return count
    end
    ok, count = pcall(C_Item.GetItemCount, itemID, includeBank)
    if ok and type(count) == "number" then
        return count
    end
    return 0
end

-- P0-3 helper: scan all bags into a single { [itemID] = count } map. Lets
-- callers replace per-row C_Item.GetItemCount loops (which iterate all bag
-- slots internally) with a single bag walk + table lookup. Pattern from
-- ThendarsLumberTracker.lua:7121-7145.
function U:BuildBagCounts()
    local counts = {}
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
        return counts
    end
    -- BACKPACK_CONTAINER (0) ... NUM_BAG_SLOTS, plus the reagent bag.
    local lastBag = NUM_BAG_SLOTS or 4
    for bag = 0, lastBag + 1 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            -- pcall — GetContainerItemInfo can throw on transitory bag state
            -- (e.g. mid-bag-swap), and a single error in this scan would
            -- abort the entire bag-counts pass. Match FarmSession's guard.
            local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end

-- P2-19: weak-key cache helper. Wraps any cache table with `__mode = "k"`
-- so frame-keyed entries don't pin frames once the row pool drops them.
function U:WeakKeyCache(tbl)
    return setmetatable(tbl or {}, { __mode = "k" })
end

