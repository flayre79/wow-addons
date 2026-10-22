local addonName, addon = ...

-- Consumer Setup
local DV_ADDON_KEY = string.lower(addonName)
local DV_SHARD_KEY = "FabledUI_DataVault_" .. addonName

--- Minimal Compatibility Wrapper
--- Automatically routes to Shard > Core > Local SVs safely
function addon:ResolveStorageRoot()
    -- 1. Try Shard
    if DataVault and DataVault.ShardAvailable and DataVault:ShardAvailable(DV_SHARD_KEY) then
        addon._storageBackend = "DataVault_Shard"
        return DataVault:ShardGet("account", DV_SHARD_KEY, DV_ADDON_KEY, nil, {})
    end
    
    -- 2. Try Core
    if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
        DataVault:EnsureNamespace(DV_ADDON_KEY)
        addon._storageBackend = "DataVault_Core"
        return DataVault:Get("account", DV_ADDON_KEY, nil, {})
    end
    
    -- 3. Legacy Fallback (No DataVault installed)
    local localDBName = addonName .. "DB"
    _G[localDBName] = _G[localDBName] or { data = {} }
    addon._storageBackend = "Local_SavedVariables"
    return _G[localDBName]
end