local DV = DataVault

--- Shards register themselves when they load
function DV:RegisterShard(shardKey, shardTable)
    -- Guard against duplicate registration (e.g. shard fires on both
    -- ADDON_LOADED and PLAYER_LOGIN). DV-002: Villa was registering
    -- twice during startup; first call wins, subsequent calls are no-ops.
    if self.shards[shardKey] then
        return
    end
    self.shards[shardKey] = shardTable
    self:Print("Registered Shard:", shardKey)
end

function DV:ShardAvailable(shardKey)
    -- Verify the shard addon is loaded and registered
    local isLoaded = false
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, shardKey)
        isLoaded = ok and loaded or false
    end
    return (isLoaded and self.shards[shardKey] ~= nil) or false
end

function DV:ShardGet(scope, shardKey, addonKey, ...)
    local path, defaultValue = self._SplitPathAndDefault(...)
    if self:ShardAvailable(shardKey) then
        local shardDB = self.shards[shardKey]
        if #path == 0 then
            return shardDB or defaultValue
        end
        local value = self._TraverseGet(shardDB, path)
        if value == nil then
            return defaultValue
        end
        return value
    end
    -- Fallback to core if shard isn't installed
    if #path == 0 then
        return self:Get(scope, addonKey, nil, defaultValue)
    end
    return self:Get(scope, addonKey, unpack(path), defaultValue)
end

function DV:ShardSet(scope, shardKey, addonKey, ...)
    local count = select("#", ...)
    if count < 2 then
        return false
    end

    local args = { ... }
    local value = args[count]
    local path = {}
    for index = 1, count - 1 do
        if args[index] ~= nil then
            path[#path + 1] = args[index]
        end
    end

    if self:ShardAvailable(shardKey) then
        local shardDB = self.shards[shardKey]
        if #path == 0 then
            return false
        end
        self._TraverseSet(shardDB, path, value)
        return true
    end
    if #path == 0 then
        return false
    end
    return self:Set(scope, addonKey, unpack(path), value)
end
