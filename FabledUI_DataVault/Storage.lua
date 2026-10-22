local DV = DataVault

-- Per-realm storage is held in a third SavedVariable that the user can
-- migrate with their character across factions / accounts independently
-- of the account-wide and character-bound stores. Declared in the TOC
-- under SavedVariables; allocated lazily here so the first realm write
-- doesn't fail if PLAYER_LOGIN order shifts.
DataVaultRealmDB = DataVaultRealmDB or { addons = {} }

local function realmKey()
    local realm = GetRealmName and GetRealmName() or "Realm"
    return tostring(realm)
end

local function GetRoot(scope)
    if scope == "character" or scope == "char" then
        return DataVaultCharDB
    end
    if scope == "realm" then
        -- Bucket realm data so realm A can't read realm B's keys. Lazy-init
        -- the per-realm sub-table; the addon walks 'addons.<addonKey>' below.
        local k = realmKey()
        DataVaultRealmDB[k] = DataVaultRealmDB[k] or { addons = {} }
        return DataVaultRealmDB[k]
    end
    return DataVaultDB
end

local function NormalizeAddonKey(addonKey)
    if addonKey == nil then
        return nil
    end
    return string.lower(tostring(addonKey))
end

local function IsPathSegment(value)
    local valueType = type(value)
    return valueType == "string" or valueType == "number"
end

local function SplitPathAndDefault(...)
    local count = select("#", ...)
    if count == 0 then
        return {}, nil
    end

    local args = { ... }
    if count == 1 then
        if args[1] == nil then
            return {}, nil
        end
        return { args[1] }, nil
    end

    if args[1] == nil then
        return {}, args[2]
    end

    local last = args[count]
    if not IsPathSegment(last) then
        local path = {}
        for index = 1, count - 1 do
            path[#path + 1] = args[index]
        end
        return path, last
    end

    return args, nil
end

local function TraverseGet(root, path)
    local node = root
    for _, segment in ipairs(path) do
        if type(node) ~= "table" then
            return nil
        end
        node = node[segment]
        if node == nil then
            return nil
        end
    end
    return node
end

local function TraverseSet(root, path, value)
    if type(root) ~= "table" then
        return false
    end

    if #path == 0 then
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

local function TraverseDelete(root, path)
    if type(root) ~= "table" or #path == 0 then
        return false
    end

    local node = root
    for index = 1, #path - 1 do
        local next = node[path[index]]
        if type(next) ~= "table" then
            return false
        end
        node = next
    end

    local leaf = path[#path]
    if node[leaf] == nil then
        return false
    end

    node[leaf] = nil
    return true
end

DV._NormalizeAddonKey = NormalizeAddonKey
DV._SplitPathAndDefault = SplitPathAndDefault
DV._TraverseGet = TraverseGet
DV._TraverseSet = TraverseSet
DV._TraverseDelete = TraverseDelete

local function GetNamespaceData(scope, addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then
        return nil
    end

    local root = GetRoot(scope).addons
    if not root[addonKey] then
        root[addonKey] = { data = {}, schemaVersion = 1 }
    elseif type(root[addonKey].data) ~= "table" then
        root[addonKey].data = {}
    end

    return root[addonKey].data
end

function DV:EnsureNamespace(addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then return false end
    
    local accRoot = DataVaultDB.addons
    local charRoot = DataVaultCharDB.addons
    
    if not accRoot[addonKey] then accRoot[addonKey] = { data = {}, schemaVersion = 1 } end
    if not charRoot[addonKey] then charRoot[addonKey] = { data = {} } end
    
    return accRoot[addonKey].data
end

function DV:Get(scope, addonKey, ...)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then
        return nil
    end

    local path, defaultValue = SplitPathAndDefault(...)
    self:EnsureNamespace(addonKey)
    local root = GetNamespaceData(scope, addonKey)
    if type(root) ~= "table" then
        return defaultValue
    end

    if #path == 0 then
        return root
    end

    local value = TraverseGet(root, path)
    if value == nil then
        return defaultValue
    end
    return value
end

function DV:Set(scope, addonKey, ...)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then
        return false
    end

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

    self:EnsureNamespace(addonKey)
    local namespaceRoot = GetRoot(scope).addons
    local dataRoot = namespaceRoot[addonKey] and namespaceRoot[addonKey].data or nil
    if type(dataRoot) ~= "table" then
        return false
    end

    if #path == 0 then
        if type(value) ~= "table" then
            return false
        end
        namespaceRoot[addonKey].data = value
    else
        TraverseSet(dataRoot, path, value)
    end

    self.dirtyFlags[addonKey] = true
    return true
end

function DV:Mutate(scope, addonKey, ...)
    local count = select("#", ...)
    if count < 1 then
        return nil
    end

    local args = { ... }
    local fn = args[count]
    if type(fn) ~= "function" then
        return nil
    end

    local path = {}
    for index = 1, count - 1 do
        path[#path + 1] = args[index]
    end

    local current = self:Get(scope, addonKey, unpack(path))
    local updated = fn(current)
    if #path == 0 then
        if type(updated) == "table" then
            addonKey = DV._NormalizeAddonKey(addonKey)
            if addonKey then
                self:EnsureNamespace(addonKey)
                local root = GetRoot(scope).addons
                if root[addonKey] then
                    root[addonKey].data = updated
                    self.dirtyFlags[addonKey] = true
                end
            end
        end
        return updated
    end
    self:Set(scope, addonKey, unpack(path), updated)
    return updated
end

function DV:Delete(scope, addonKey, ...)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then
        return false
    end

    local path = { ... }
    while #path > 0 and path[#path] == nil do
        table.remove(path)
    end

    if #path == 0 then
        return false
    end

    local root = self:Get(scope, addonKey, nil)
    if TraverseDelete(root, path) then
        self.dirtyFlags[addonKey] = true
        return true
    end
    return false
end

function DV:Dirty(addonKey)
    addonKey = NormalizeAddonKey(addonKey)
    if not addonKey then return false end
    return self.dirtyFlags[addonKey] == true
end

-- ============================================================
-- Tagging API
-- Tags are global to the DataVault account scope and can be
-- applied to any entity using a "type:id" key convention.
-- entityKey  — caller-defined string, e.g. "item:12345" or "npc:67890"
-- tagName    — arbitrary lowercase string, e.g. "favorite", "wanted"
-- ============================================================

local function GetTagsRoot()
    DataVaultDB.tags = DataVaultDB.tags or {}
    return DataVaultDB.tags
end

function DV:TagEntity(entityKey, tagName)
    if type(entityKey) ~= "string" or type(tagName) ~= "string" then return false end
    tagName = tagName:lower()
    if type(self.AddTag) == "function" then
        return self:AddTag("__global", "entities", entityKey, tagName)
    end
    return false
end

function DV:UntagEntity(entityKey, tagName)
    if type(entityKey) ~= "string" or type(tagName) ~= "string" then return false end
    tagName = tagName:lower()
    if type(self.RemoveTag) == "function" then
        return self:RemoveTag("__global", "entities", entityKey, tagName)
    end
    return false
end

function DV:HasEntityTag(entityKey, tagName)
    if type(entityKey) ~= "string" or type(tagName) ~= "string" then return false end
    local tags = GetTagsRoot()
    local globalTags = tags.__global and tags.__global.entities or {}
    local entityTags = globalTags[entityKey]
    return type(entityTags) == "table" and entityTags[tagName:lower()] == true or false
end

function DV:GetTags(entityKey)
    if type(entityKey) ~= "string" then return {} end
    if type(self.ListTags) == "function" then
        return self:ListTags("__global", "entities", entityKey)
    end
    return {}
end

function DV:GetTaggedEntities(tagName)
    if type(tagName) ~= "string" then return {} end
    tagName = tagName:lower()
    local tags = GetTagsRoot()
    local result = {}
    local globalTags = tags.__global and tags.__global.entities or {}
    for entityKey, entityTags in pairs(globalTags) do
        if type(entityTags) == "table" and entityTags[tagName] then
            result[#result + 1] = tostring(entityKey)
        end
    end
    table.sort(result)
    return result
end

function DV:ClearTag(tagName)
    if type(tagName) ~= "string" then return 0 end
    tagName = tagName:lower()
    local tags = GetTagsRoot()
    local removed = 0
    local globalTags = tags.__global and tags.__global.entities or {}
    for entityKey, entityTags in pairs(globalTags) do
        if type(entityTags) == "table" and entityTags[tagName] then
            entityTags[tagName] = nil
            removed = removed + 1
            if not next(entityTags) then
                globalTags[entityKey] = nil
            end
        end
    end
    if removed > 0 then
        self.dirtyFlags["__tags"] = true
    end
    return removed
end

function DV:GetAllTagNames()
    local seen = {}
    local result = {}
    local tags = GetTagsRoot()
    local globalTags = tags.__global and tags.__global.entities or {}
    for _, entityTags in pairs(globalTags) do
        for tagName in pairs(entityTags) do
            if not seen[tagName] then
                seen[tagName] = true
                result[#result + 1] = tagName
            end
        end
    end
    table.sort(result)
    return result
end

function DV:Checkpoint(addonKey, opts)
    if opts and opts.force then
        ReloadUI() -- Forces WoW to write SavedVariables to disk
        return true -- Won't reach here, but signals intent
    else
        StaticPopupDialogs["DATAVAULT_CHECKPOINT"] = {
            text = "DataVault requires a UI Reload to save data safely. Reload now?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3, -- avoid taint from the default visible-frame index
        }
        StaticPopup_Show("DATAVAULT_CHECKPOINT")
    end
    return false -- Dialog shown; user hasn't confirmed yet
end
