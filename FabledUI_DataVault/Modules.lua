local DV = DataVault

DV.Tags = DV.Tags or {}

local function GetTagRoot(addonKey, domain, entityID, createMissing)
    addonKey = DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey
    if not addonKey or domain == nil or entityID == nil then
        return nil
    end

    DataVaultDB.tags = DataVaultDB.tags or {}

    if createMissing then
        DataVaultDB.tags[addonKey] = DataVaultDB.tags[addonKey] or {}
        DataVaultDB.tags[addonKey][domain] = DataVaultDB.tags[addonKey][domain] or {}
        DataVaultDB.tags[addonKey][domain][entityID] = DataVaultDB.tags[addonKey][domain][entityID] or {}
    end

    return DataVaultDB.tags[addonKey]
        and DataVaultDB.tags[addonKey][domain]
        and DataVaultDB.tags[addonKey][domain][entityID]
end

function DV:AddTag(addonKey, domain, entityID, tagKey)
    if tagKey == nil then
        return false
    end

    local tags = GetTagRoot(addonKey, domain, entityID, true)
    if not tags then
        return false
    end

    tags[tagKey] = true
    self.dirtyFlags[DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey] = true
    return true
end

function DV:RemoveTag(addonKey, domain, entityID, tagKey)
    local tags = GetTagRoot(addonKey, domain, entityID, false)
    if not tags or tags[tagKey] == nil then
        return false
    end

    tags[tagKey] = nil
    if not next(tags) then
        local normalizedKey = DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey
        DataVaultDB.tags[normalizedKey][domain][entityID] = nil
        if not next(DataVaultDB.tags[normalizedKey][domain]) then
            DataVaultDB.tags[normalizedKey][domain] = nil
        end
        if not next(DataVaultDB.tags[normalizedKey]) then
            DataVaultDB.tags[normalizedKey] = nil
        end
    end
    self.dirtyFlags[DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey] = true
    return true
end

function DV:HasTag(addonKey, domain, entityID, tagKey)
    local tags = GetTagRoot(addonKey, domain, entityID, false)
    return tags and tags[tagKey] == true or false
end

function DV:ListTags(addonKey, domain, entityID)
    local tags = GetTagRoot(addonKey, domain, entityID, false)
    local results = {}
    if not tags then
        return results
    end

    for tagKey in pairs(tags) do
        results[#results + 1] = tagKey
    end
    table.sort(results)
    return results
end

-- Import State
function DV:GetImportState(addonKey, flagKey)
    addonKey = DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey
    DataVaultDB.importState[addonKey] = DataVaultDB.importState[addonKey] or {}
    return DataVaultDB.importState[addonKey][flagKey]
end

function DV:SetImportState(addonKey, flagKey, value)
    addonKey = DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey
    DataVaultDB.importState[addonKey] = DataVaultDB.importState[addonKey] or {}
    DataVaultDB.importState[addonKey][flagKey] = value
    self.dirtyFlags[addonKey] = true
    return true
end

-- Migrations
function DV:Migrate(addonKey, fromVersion, toVersion, migrationFunc)
    self:EnsureNamespace(addonKey)
    addonKey = DV._NormalizeAddonKey and DV._NormalizeAddonKey(addonKey) or addonKey
    local root = DataVaultDB.addons[addonKey]
    local currentVer = root.schemaVersion or 1

    if type(fromVersion) == "number" and type(toVersion) == "function" and migrationFunc == nil then
        migrationFunc = toVersion
        toVersion = fromVersion
        fromVersion = currentVer
    elseif type(fromVersion) ~= "number" then
        fromVersion = currentVer
    end
    
    if currentVer < (tonumber(toVersion) or currentVer) then
        self:Print("Migrating", addonKey, "from", currentVer, "to", toVersion)
        local success = type(migrationFunc) == "function" and migrationFunc(root.data, fromVersion, toVersion) or false
        if success then
            root.schemaVersion = toVersion
            self.dirtyFlags[addonKey] = true
        end
        return success
    end
    return true
end

DV.Tags.IsAvailable = function()
    return true
end

DV.Tags.Add = function(_, scope, addonKey, domain, entityID, tagKey)
    if scope ~= "account" and scope ~= nil then
        return false
    end
    return DV:AddTag(addonKey, domain, entityID, tagKey)
end

DV.Tags.Remove = function(_, scope, addonKey, domain, entityID, tagKey)
    if scope ~= "account" and scope ~= nil then
        return false
    end
    return DV:RemoveTag(addonKey, domain, entityID, tagKey)
end

DV.Tags.Has = function(_, scope, addonKey, domain, entityID, tagKey)
    if scope ~= "account" and scope ~= nil then
        return false
    end
    return DV:HasTag(addonKey, domain, entityID, tagKey)
end

DV.Tags.List = function(_, scope, addonKey, domain, entityID)
    if scope ~= "account" and scope ~= nil then
        return {}
    end
    return DV:ListTags(addonKey, domain, entityID)
end
