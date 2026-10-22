local A = Athena

A.Storage = A.Storage or {}
local S = A.Storage

local SCHEMA_VERSION = 2
local PROFILE_METHODS = {
    "EnableProfiles",
    "GetProfile",
    "SetProfile",
    "ListProfiles",
    "GetProfileData",
    "SetProfileData",
}

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function NormalizePath(path)
    if path == nil then
        return {}
    end
    if type(path) == "table" then
        local copy = {}
        for index = 1, #path do
            copy[index] = path[index]
        end
        return copy
    end
    return { path }
end

local function ResolveDataVault()
    local dv = rawget(_G, "DataVault")
    if type(dv) ~= "table" or type(dv.IsAvailable) ~= "function" then
        return nil
    end

    local ok, available = pcall(dv.IsAvailable, dv)
    if not ok or available ~= true then
        return nil
    end
    return dv
end

local function EnsureLocalRoots()
    if type(_G.FabledUI_AthenaDB) ~= "table" then
        _G.FabledUI_AthenaDB = {}
    end
    if type(_G.FabledUI_AthenaCharDB) ~= "table" then
        _G.FabledUI_AthenaCharDB = {}
    end
end

local function GetLocalRoot(scope)
    EnsureLocalRoots()
    if scope == "character" or scope == "char" then
        return _G.FabledUI_AthenaCharDB
    end
    return _G.FabledUI_AthenaDB
end

local function SetLocalRoot(scope, value)
    if scope == "character" or scope == "char" then
        _G.FabledUI_AthenaCharDB = value
    else
        _G.FabledUI_AthenaDB = value
    end
end

local function TraverseGet(root, path)
    local node = root
    for index = 1, #path do
        if type(node) ~= "table" then
            return nil
        end
        node = node[path[index]]
        if node == nil then
            return nil
        end
    end
    return node
end

local function TraverseSet(root, path, value)
    if type(root) ~= "table" or #path == 0 then
        return false
    end

    local node = root
    for index = 1, #path - 1 do
        local segment = path[index]
        if type(node[segment]) ~= "table" then
            node[segment] = {}
        end
        node = node[segment]
    end
    node[path[#path]] = value
    return true
end

local function NormalizeEnabledAddons(enabledAddons)
    local normalized = {}
    if type(enabledAddons) == "table" then
        for addonName, enabled in pairs(enabledAddons) do
            if type(addonName) == "string" and addonName ~= "" and type(enabled) == "boolean" then
                normalized[addonName] = enabled
            end
        end
    end
    return normalized
end

local function NormalizeLegacyBundle(profile)
    if type(profile) ~= "table" then
        return nil
    end

    local source = type(profile.bundle) == "table" and profile.bundle or profile
    if type(source.enabledAddons) ~= "table" then
        return nil
    end

    return {
        schema = SCHEMA_VERSION,
        savedAt = tonumber(source.savedAt) or (type(time) == "function" and time() or 0),
        enabledAddons = NormalizeEnabledAddons(source.enabledAddons),
    }
end

local function MergeLegacyMetadata(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    target.categories = type(target.categories) == "table" and target.categories or {}
    for key, category in pairs(source.categories or {}) do
        if target.categories[key] == nil and type(category) == "table" then
            target.categories[key] = A.DeepCopy(category)
        end
    end

    target.addonCategoryMap = type(target.addonCategoryMap) == "table" and target.addonCategoryMap or {}
    for addonName, categorySet in pairs(source.addonCategoryMap or {}) do
        if type(categorySet) == "table" then
            local targetSet = target.addonCategoryMap[addonName]
            if type(targetSet) ~= "table" then
                targetSet = {}
                target.addonCategoryMap[addonName] = targetSet
            end
            for categoryKey, assigned in pairs(categorySet) do
                if assigned then
                    targetSet[categoryKey] = true
                end
            end
        end
    end

    target.legacyDefaultsV1 = type(target.legacyDefaultsV1) == "table" and target.legacyDefaultsV1 or {}
    for characterKey, profileName in pairs(source.defaults or {}) do
        if target.legacyDefaultsV1[characterKey] == nil and type(profileName) == "string" then
            target.legacyDefaultsV1[characterKey] = profileName
        end
    end
    for characterKey, profileName in pairs(source.legacyDefaultsV1 or {}) do
        if target.legacyDefaultsV1[characterKey] == nil and type(profileName) == "string" then
            target.legacyDefaultsV1[characterKey] = profileName
        end
    end

    target.meta = type(target.meta) == "table" and target.meta or {}
    if target.meta.debug == nil and type(source.meta) == "table" then
        target.meta.debug = source.meta.debug == true
    end
end

function S:_RecordError(operation, err)
    self.lastError = tostring(operation) .. ": " .. tostring(err)
    if A._ready and A.Print then
        A.Print("|cffff5555Storage error:|r " .. self.lastError)
    end
end

function S:_GetDataVault(requiredMethods)
    local dv = ResolveDataVault()
    if not dv then
        return nil
    end

    for _, methodName in ipairs(requiredMethods or {}) do
        if type(dv[methodName]) ~= "function" then
            return nil
        end
    end
    return dv
end

function S:IsDataVaultBackend()
    return self.backend == "datavault" and self:_GetDataVault({ "Get", "Set", "Mutate" }) ~= nil
end

function S:Get(scope, path, defaultValue)
    path = NormalizePath(path)

    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "Get" })
        if not dv then
            return defaultValue
        end

        local result = Pack(pcall(dv.Get, dv, scope, A.STORE_KEY, unpack(path, 1, #path)))
        if not result[1] then
            self:_RecordError("Get", result[2])
            return defaultValue
        end
        return result[2] == nil and defaultValue or result[2]
    end

    local value = TraverseGet(GetLocalRoot(scope), path)
    return value == nil and defaultValue or value
end

function S:Set(scope, path, value)
    path = NormalizePath(path)

    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "Set" })
        if not dv then
            return false
        end

        local args, argumentCount = {}, #path + 1
        if #path == 0 then
            -- DataVault uses the explicit (nil, table) form to replace a
            -- namespace root; a lone table is rejected as a malformed Set.
            args[1] = nil
            args[2] = value
            argumentCount = 2
        else
            for index = 1, #path do
                args[index] = path[index]
            end
            args[argumentCount] = value
        end

        local ok, stored = pcall(dv.Set, dv, scope, A.STORE_KEY, unpack(args, 1, argumentCount))
        if not ok then
            self:_RecordError("Set", stored)
            return false
        end
        return stored == true
    end

    if #path == 0 then
        if type(value) ~= "table" then
            return false
        end
        SetLocalRoot(scope, value)
        return true
    end
    return TraverseSet(GetLocalRoot(scope), path, value)
end

function S:Mutate(scope, path, fn)
    path = NormalizePath(path)
    if type(fn) ~= "function" then
        return nil, false
    end

    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "Mutate" })
        if not dv then
            return nil, false
        end

        if #path == 0 then
            local ok, updated = pcall(dv.Mutate, dv, scope, A.STORE_KEY, fn)
            if not ok then
                self:_RecordError("Mutate", updated)
                return nil, false
            end
            return updated, true
        end

        -- DataVault 1.0's nested Mutate ends with
        --     Set(..., unpack(path), updated)
        -- and WoW Lua truncates unpack's multi-return because it is not the
        -- final expression. Mutate the namespace root instead, keeping the
        -- entire nested read/change/write inside DataVault's callback.
        local callbackResult
        local function MutateRoot(root)
            root = type(root) == "table" and root or {}
            callbackResult = fn(TraverseGet(root, path))
            TraverseSet(root, path, callbackResult)
            return root
        end

        local ok, updatedRoot = pcall(dv.Mutate, dv, scope, A.STORE_KEY, MutateRoot)
        if not ok then
            self:_RecordError("Mutate", updatedRoot)
            return nil, false
        end
        return callbackResult, true
    end

    local root = GetLocalRoot(scope)
    local current = #path == 0 and root or TraverseGet(root, path)
    local ok, updated = pcall(fn, current)
    if not ok then
        self:_RecordError("Local Mutate", updated)
        return nil, false
    end

    if #path == 0 then
        if type(updated) ~= "table" then
            return updated, false
        end
        SetLocalRoot(scope, updated)
    else
        TraverseSet(root, path, updated)
    end
    return updated, true
end

function S:EnableProfiles()
    if self.backend == "datavault" then
        local dv = self:_GetDataVault(PROFILE_METHODS)
        if not dv then
            return false
        end
        local ok, err = pcall(dv.EnableProfiles, dv, A.STORE_KEY)
        if not ok then
            self:_RecordError("EnableProfiles", err)
            return false
        end
        return true
    end

    local root = GetLocalRoot("account")
    root.profiles = type(root.profiles) == "table" and root.profiles or {}
    root.profileActive = type(root.profileActive) == "string" and root.profileActive or "Default"
    return true
end

function S:GetProfile()
    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "GetProfile" })
        if not dv then
            return "Default"
        end
        local ok, profileName = pcall(dv.GetProfile, dv, A.STORE_KEY)
        if not ok then
            self:_RecordError("GetProfile", profileName)
            return "Default"
        end
        return type(profileName) == "string" and profileName or "Default"
    end

    local root = GetLocalRoot("account")
    return type(root.profileActive) == "string" and root.profileActive or "Default"
end

function S:SetProfile(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return false
    end

    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "SetProfile" })
        if not dv then
            return false
        end
        local ok, selected = pcall(dv.SetProfile, dv, A.STORE_KEY, profileName)
        if not ok then
            self:_RecordError("SetProfile", selected)
            return false
        end
        return selected == true
    end

    local root = GetLocalRoot("account")
    root.profileActive = profileName
    return true
end

function S:ListProfiles()
    local profiles
    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "ListProfiles" })
        if not dv then
            return {}
        end
        local ok, listed = pcall(dv.ListProfiles, dv, A.STORE_KEY)
        if not ok then
            self:_RecordError("ListProfiles", listed)
            return {}
        end
        profiles = listed
    else
        profiles = {}
        for profileName in pairs(GetLocalRoot("account").profiles or {}) do
            profiles[#profiles + 1] = profileName
        end
    end

    local result = {}
    for _, profileName in ipairs(type(profiles) == "table" and profiles or {}) do
        if type(profileName) == "string" and profileName ~= "" then
            result[#result + 1] = profileName
        end
    end
    table.sort(result)
    return result
end

function S:GetProfileData(path, defaultValue)
    path = NormalizePath(path)

    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "GetProfileData" })
        if not dv then
            return defaultValue
        end
        local result = Pack(pcall(dv.GetProfileData, dv, A.STORE_KEY, unpack(path, 1, #path)))
        if not result[1] then
            self:_RecordError("GetProfileData", result[2])
            return defaultValue
        end
        return result[2] == nil and defaultValue or result[2]
    end

    local root = GetLocalRoot("account")
    root.profiles = type(root.profiles) == "table" and root.profiles or {}
    local profileName = self:GetProfile()
    root.profiles[profileName] = type(root.profiles[profileName]) == "table" and root.profiles[profileName] or {}
    local value = #path == 0 and root.profiles[profileName] or TraverseGet(root.profiles[profileName], path)
    return value == nil and defaultValue or value
end

function S:SetProfileData(path, value)
    path = NormalizePath(path)
    if #path == 0 then
        return false
    end

    if self.backend == "datavault" then
        local dv = self:_GetDataVault({ "SetProfileData" })
        if not dv then
            return false
        end

        local args = {}
        for index = 1, #path do
            args[index] = path[index]
        end
        local argumentCount = #path + 1
        args[argumentCount] = value

        local ok, stored = pcall(dv.SetProfileData, dv, A.STORE_KEY, unpack(args, 1, argumentCount))
        if not ok then
            self:_RecordError("SetProfileData", stored)
            return false
        end
        return stored == true
    end

    local profileRoot = self:GetProfileData({}, {})
    return TraverseSet(profileRoot, path, value)
end

function S:_EnsureDefaults()
    self:Mutate("account", {}, function(root)
        root = type(root) == "table" and root or {}
        root.meta = type(root.meta) == "table" and root.meta or {}
        root.meta.debug = root.meta.debug == true
        root.categories = type(root.categories) == "table" and root.categories or {}
        root.addonCategoryMap = type(root.addonCategoryMap) == "table" and root.addonCategoryMap or {}
        root.legacyDefaultsV1 = type(root.legacyDefaultsV1) == "table" and root.legacyDefaultsV1 or {}
        if self.backend == "local" then
            root.profiles = type(root.profiles) == "table" and root.profiles or {}
            root.profileActive = type(root.profileActive) == "string" and root.profileActive or "Default"
        end
        return root
    end)

    self:Mutate("character", {}, function(root)
        return type(root) == "table" and root or {}
    end)
end

function S:_MigrateLegacyData()
    local accountSnapshot = A.DeepCopy(self:Get("account", {}, {}))
    local snapshots = { accountSnapshot }

    if self.backend == "datavault" and type(_G.FabledUI_AthenaDB) == "table" then
        snapshots[#snapshots + 1] = A.DeepCopy(_G.FabledUI_AthenaDB)
    end

    local legacyProfiles = {}
    for _, snapshot in ipairs(snapshots) do
        for profileName, profile in pairs(snapshot.profiles or {}) do
            if type(profileName) == "string" and profileName ~= "" and legacyProfiles[profileName] == nil then
                legacyProfiles[profileName] = A.DeepCopy(profile)
            end
        end
        for profileName, profile in pairs(snapshot.legacyProfilesV1 or {}) do
            if type(profileName) == "string" and profileName ~= "" and legacyProfiles[profileName] == nil then
                legacyProfiles[profileName] = A.DeepCopy(profile)
            end
        end
    end

    local meta = type(accountSnapshot.meta) == "table" and accountSnapshot.meta or {}
    local migrationVersion = tonumber(meta.migrationVersion) or 0
    local migrationNeeded = migrationVersion < SCHEMA_VERSION

    if self.backend == "datavault" then
        -- A legacy Athena profile has to reach DataVault's profile service
        -- before its namespace copy is removed or the migration is marked
        -- complete. The separate completion flag also repairs installs that
        -- briefly ran the early v2 migration, which marked success too soon.
        local profileMigrationNeeded = migrationNeeded or meta.profileMigrationComplete ~= true
        if migrationNeeded or profileMigrationNeeded then
            local _, prepared = self:Mutate("account", {}, function(root)
                root = type(root) == "table" and root or {}
                for _, snapshot in ipairs(snapshots) do
                    MergeLegacyMetadata(root, snapshot)
                end
                root.meta = type(root.meta) == "table" and root.meta or {}
                root.meta.schema = SCHEMA_VERSION
                if next(legacyProfiles) then
                    root.legacyProfilesV1 = A.DeepCopy(legacyProfiles)
                end
                return root
            end)

            local copied = prepared
            if copied and profileMigrationNeeded and next(legacyProfiles) then
                local previousProfile = self:GetProfile()
                for _, profileName in ipairs(A.SortedKeys(legacyProfiles)) do
                    local bundle = NormalizeLegacyBundle(legacyProfiles[profileName])
                    if bundle then
                        if not self:SetProfile(profileName) then
                            copied = false
                            break
                        end
                        local existing = self:GetProfileData({ "bundle" }, nil)
                        if type(existing) ~= "table"
                            and not self:SetProfileData({ "bundle" }, bundle) then
                            copied = false
                            break
                        end
                    end
                end
                if not self:SetProfile(previousProfile) then
                    copied = false
                end
            end

            if copied then
                self:Mutate("account", {}, function(root)
                    root = type(root) == "table" and root or {}
                    root.meta = type(root.meta) == "table" and root.meta or {}
                    root.meta.schema = SCHEMA_VERSION
                    root.meta.migrationVersion = SCHEMA_VERSION
                    root.meta.profileMigrationComplete = true
                    if next(legacyProfiles) then
                        root.legacyProfilesV1 = A.DeepCopy(legacyProfiles)
                    end
                    root.profiles = nil
                    root.defaults = nil
                    return root
                end)
            end
        end
    elseif migrationNeeded then
        self:Mutate("account", {}, function(root)
            root = type(root) == "table" and root or {}
            for _, snapshot in ipairs(snapshots) do
                MergeLegacyMetadata(root, snapshot)
            end

            local converted = {}
            for profileName, profile in pairs(legacyProfiles) do
                local bundle = NormalizeLegacyBundle(profile)
                if bundle then
                    converted[profileName] = { bundle = bundle }
                end
            end

            root.meta = type(root.meta) == "table" and root.meta or {}
            root.meta.schema = SCHEMA_VERSION
            root.meta.migrationVersion = SCHEMA_VERSION
            root.meta.profileMigrationComplete = true
            root.profiles = converted
            root.defaults = nil
            return root
        end)
    end

    local currentDefault = self:Get("character", { "defaultProfile" }, nil)
    if type(currentDefault) ~= "string" or currentDefault == "" then
        local legacyDefaults = self:Get("account", { "legacyDefaultsV1" }, {})
        local profileName = type(legacyDefaults) == "table" and legacyDefaults[A.GetCharacterKey()] or nil
        if type(profileName) == "string" and profileName ~= "" then
            self:Set("character", { "defaultProfile" }, profileName)
        end
    end
end

function S:Initialize()
    EnsureLocalRoots()

    local required = { "Get", "Set", "Mutate" }
    for _, methodName in ipairs(PROFILE_METHODS) do
        required[#required + 1] = methodName
    end

    local dv = self:_GetDataVault(required)
    if dv then
        self.backend = "datavault"
        if type(dv.EnsureNamespace) == "function" then
            local ok, err = pcall(dv.EnsureNamespace, dv, A.STORE_KEY)
            if not ok then
                self:_RecordError("EnsureNamespace", err)
            end
        end
    else
        self.backend = "local"
    end

    self:_EnsureDefaults()
    if not self:EnableProfiles() and self.backend == "datavault" then
        self.backend = "local"
        self:_EnsureDefaults()
        self:EnableProfiles()
    end
    self:_MigrateLegacyData()
    self:_EnsureDefaults()

    A._storageBackend = self.backend == "datavault" and "DataVault" or "Local SVs"
    return true
end

function A:InitStorage()
    return S:Initialize()
end
