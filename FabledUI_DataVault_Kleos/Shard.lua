-- ============================================================================
-- FabledUI_DataVault_Kleos — Kleos storage shard
--
-- Holds the bulk data Kleos derives from the client so it does not sit in the
-- main addon's saved variables: the criteria asset index (creature id / item id
-- -> achievements), which is what makes "this mob is needed for X" tooltips
-- possible. Building it is a walk over every criterion of every achievement, so
-- it is computed once per client build and then read from here.
--
-- The shard owns FabledUI_KleosShardDB. It deliberately does NOT declare
-- FabledUI_KleosDB: that variable belongs to FabledUI_Kleos, and two addons
-- declaring the same SavedVariable means whichever loads second overwrites the
-- other's copy on logout.
-- ============================================================================

-- The shard key must be this addon's name: DataVault:ShardAvailable() feeds it
-- straight into C_AddOns.IsAddOnLoaded, so any other value reports the shard as
-- unavailable (or, worse, reports a different addon's load state).
local SHARD_KEY = "FabledUI_DataVault_Kleos"
local SCHEMA = 1

FabledUI_KleosShardDB = FabledUI_KleosShardDB or {}

local Shard = {}
_G.KleosShard = Shard

local function Root()
    if type(FabledUI_KleosShardDB) ~= "table" then FabledUI_KleosShardDB = {} end
    local root = FabledUI_KleosShardDB
    if root.schema ~= SCHEMA then
        -- Any schema change invalidates the derived caches rather than
        -- migrating them: they are reproducible from the client in one pass.
        wipe(root)
        root.schema = SCHEMA
    end
    root.caches = root.caches or {}
    return root
end

function Shard:IsAvailable()
    return type(FabledUI_KleosShardDB) == "table"
end

-- Client build stamp. A cache keyed by anything coarser than this survives a
-- patch that adds achievements, and then silently under-reports.
function Shard:BuildStamp()
    if type(GetBuildInfo) ~= "function" then return "unknown" end
    local version, build, _, tocVersion = GetBuildInfo()
    return ("%s.%s.%s"):format(tostring(version), tostring(build), tostring(tocVersion))
end

function Shard:Get(name, expectedStamp)
    local cache = Root().caches[tostring(name or "")]
    if type(cache) ~= "table" then return nil end
    if expectedStamp and cache.stamp ~= expectedStamp then return nil end
    return cache.data, cache.stamp
end

function Shard:Set(name, data, stamp)
    name = tostring(name or "")
    if name == "" or type(data) ~= "table" then return false end
    Root().caches[name] = {
        data = data,
        stamp = stamp or self:BuildStamp(),
        written = (type(GetServerTime) == "function") and GetServerTime() or nil,
    }
    if DataVault and type(DataVault.Dirty) == "function" then
        pcall(DataVault.Dirty, DataVault, "kleos")
    end
    return true
end

function Shard:Invalidate(name)
    local caches = Root().caches
    if name then
        caches[tostring(name)] = nil
    else
        Root().caches = {}
    end
    return true
end

function Shard:Stats()
    local root = Root()
    local names, count = {}, 0
    for name, cache in pairs(root.caches) do
        count = count + 1
        local entries = 0
        for _ in pairs(type(cache.data) == "table" and cache.data or {}) do entries = entries + 1 end
        names[#names + 1] = ("%s(%d)"):format(name, entries)
    end
    table.sort(names)
    return { caches = count, detail = table.concat(names, ",") , stamp = self:BuildStamp() }
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function()
    Root()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard(SHARD_KEY, FabledUI_KleosShardDB)
    end
end)
-- Script first so a refused registration cannot leave this frame handler-less.
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
