local addonName, _ = ...
local DV = DataVault

DataVaultDB.profileEnabled = DataVaultDB.profileEnabled or {}
DataVaultDB.profileActive = DataVaultDB.profileActive or {}
DataVaultDB.profiles = DataVaultDB.profiles or {}

local function NormalizeAddonKey(addonKey)
    return DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey
end

local function GetProfileRoot(addonKey, createMissing)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then
        return nil, nil
    end

    local activeProfile = DV:GetProfile(addonKey)
    DataVaultDB.profiles[addonKey] = DataVaultDB.profiles[addonKey] or {}
    if createMissing then
        DataVaultDB.profiles[addonKey][activeProfile] = DataVaultDB.profiles[addonKey][activeProfile] or {}
    end
    return DataVaultDB.profiles[addonKey][activeProfile], activeProfile
end

--- Opt-in to the Profile system
function DV:EnableProfiles(addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    self:EnsureNamespace(addonKey)
    DataVaultDB.profileEnabled[addonKey] = true
    
    -- Set default profile if none exists
    if not DataVaultDB.profileActive[addonKey] then
        DataVaultDB.profileActive[addonKey] = "Default"
    end
end

function DV:ProfilesEnabled(addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    return addonKey and DataVaultDB.profileEnabled[addonKey] == true or false
end

function DV:GetProfile(addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    return DataVaultDB.profileActive[addonKey] or "Default"
end

function DV:SetProfile(addonKey, profileName)
    addonKey = NormalizeAddonKey(addonKey)
    if not self:ProfilesEnabled(addonKey) then return false end
    
    DataVaultDB.profileActive[addonKey] = profileName
    self.dirtyFlags[addonKey] = true
    self:Print("Profile changed for " .. addonKey .. " to: " .. profileName)
    return true
end

function DV:ListProfiles(addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    local keys = {}
    for profileKey in pairs(DataVaultDB.profiles[addonKey] or {}) do
        keys[#keys + 1] = profileKey
    end
    table.sort(keys)
    return keys
end

--- Retrieves profile-specific data (bypasses standard Get)
function DV:GetProfileData(addonKey, ...)
    addonKey = NormalizeAddonKey(addonKey)
    local path, defaultValue = self._SplitPathAndDefault(...)
    if not self:ProfilesEnabled(addonKey) then return defaultValue end

    local profileRoot = GetProfileRoot(addonKey, true)
    if type(profileRoot) ~= "table" then
        return defaultValue
    end

    if #path == 0 then
        return profileRoot
    end

    local value = self._TraverseGet(profileRoot, path)
    if value == nil then
        return defaultValue
    end
    return value
end

function DV:SetProfileData(addonKey, ...)
    addonKey = NormalizeAddonKey(addonKey)
    if not self:ProfilesEnabled(addonKey) then return false end

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

    local profileRoot = GetProfileRoot(addonKey, true)
    if type(profileRoot) ~= "table" or #path == 0 then
        return false
    end

    self._TraverseSet(profileRoot, path, value)
    self.dirtyFlags[addonKey] = true
    return true
end
