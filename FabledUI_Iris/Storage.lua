local I = Iris

I.Storage = I.Storage or {}
local S = I.Storage

local ACCOUNT_SCOPE = "account"
local ADDON_KEY = "iris"

local DEFAULTS = {
    historySize = 1000,
    enableHistory = true,
    showCopyButton = true,
    includeTimestamps = true,
    copyLineLimit = 250,
    defaultCopyMode = "clean",
    windowState = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 840,
        height = 560,
        scale = 1,
        alpha = 1,
        displayState = "hidden",
    },
    channels = {
        SAY = true,
        YELL = true,
        EMOTE = true,
        WHISPER = true,
        BNET = true,
        PARTY = true,
        RAID = true,
        RAID_WARNING = true,
        INSTANCE = true,
        GUILD = true,
        OFFICER = true,
        CHANNEL = true,
        SYSTEM = true,
        CREATURE = true,
    },
}

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, child in pairs(value) do
        out[key] = DeepCopy(child)
    end
    return out
end

local function DeepMergeMissing(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return false
    end

    local changed = false
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
                changed = true
            end
            if DeepMergeMissing(dst[key], value) then
                changed = true
            end
        elseif dst[key] == nil then
            dst[key] = value
            changed = true
        end
    end
    return changed
end

local function GetLocalRoot()
    if type(_G.FabledUI_IrisDB) ~= "table" then
        _G.FabledUI_IrisDB = {}
    end
    return _G.FabledUI_IrisDB
end

-- Read the local table without creating it. Callers use the nil result to tell
-- "no prior install" apart from "an older session left data here", so they must
-- not trip GetLocalRoot's side effect just to look.
local function PeekLocalRoot()
    local root = rawget(_G, "FabledUI_IrisDB")
    if type(root) ~= "table" then
        return nil
    end
    return root
end

-- Return the vault only after its availability contract has succeeded. Every
-- Get/Set/Mutate below calls this immediately before touching DataVault so the
-- optional dependency can disappear or fail closed without breaking Iris.
function S:GetAvailableVault()
    local vault = rawget(_G, "DataVault")
    if type(vault) ~= "table" or type(vault.IsAvailable) ~= "function" then
        return nil
    end

    local ok, available = pcall(vault.IsAvailable, vault)
    if not ok or not available then
        return nil
    end
    return vault
end

function S:VaultGet(...)
    local vault = self:GetAvailableVault()
    if not vault or type(vault.Get) ~= "function" then
        return nil, false
    end

    local path = { ... }
    local ok, value = pcall(function()
        return vault:Get(ACCOUNT_SCOPE, ADDON_KEY, unpack(path))
    end)
    if not ok then
        return nil, false
    end
    return value, true
end

function S:VaultSet(...)
    local vault = self:GetAvailableVault()
    if not vault or type(vault.Set) ~= "function" then
        return false, false
    end

    local args = { ... }
    local ok, result = pcall(function()
        return vault:Set(ACCOUNT_SCOPE, ADDON_KEY, unpack(args))
    end)
    if not ok then
        return false, false
    end
    return result ~= false, true
end

function S:VaultMutate(...)
    local vault = self:GetAvailableVault()
    if not vault or type(vault.Mutate) ~= "function" then
        return nil, false
    end

    local args = { ... }
    local ok, result = pcall(function()
        return vault:Mutate(ACCOUNT_SCOPE, ADDON_KEY, unpack(args))
    end)
    if not ok then
        return nil, false
    end
    return result, true
end

function S:Resolve()
    local stored, usingVault = self:VaultGet("settings")
    if usingVault then
        if type(stored) ~= "table" then
            -- First login on the vault. Version 1.3 wrote its settings (and its
            -- savedHistory array) straight into FabledUI_IrisDB, so adopt that
            -- table instead of seeding defaults; otherwise installing DataVault
            -- silently resets everyone's configuration. history is a 1.4 local
            -- payload and belongs under its own vault key, not under settings.
            stored = DeepCopy(PeekLocalRoot()) or {}
            stored.history = nil
            DeepMergeMissing(stored, DEFAULTS)
            local wrote = self:VaultSet("settings", stored)
            if not wrote then
                usingVault = false
            end
        elseif DeepMergeMissing(stored, DEFAULTS) then
            local wrote = self:VaultSet("settings", stored)
            if not wrote then
                usingVault = false
            end
        end
    end

    if usingVault then
        I.settings = stored
        I._storageBackend = "DataVault"
        return
    end

    local root = GetLocalRoot()
    DeepMergeMissing(root, DEFAULTS)
    I.settings = root
    I._storageBackend = "Local SVs"
end

function S:SetSetting(key, value)
    if type(key) ~= "string" or key == "" then
        return false
    end

    I.settings = I.settings or {}
    I.settings[key] = value

    local wrote, usingVault = self:VaultSet("settings", key, value)
    if usingVault then
        return wrote
    end

    GetLocalRoot()[key] = value
    return true
end

function S:SetChannel(channelKey, value)
    if type(channelKey) ~= "string" or channelKey == "" then
        return false
    end

    I.settings = I.settings or {}
    I.settings.channels = I.settings.channels or {}
    I.settings.channels[channelKey] = value

    local wrote, usingVault = self:VaultSet("settings", "channels", channelKey, value)
    if usingVault then
        return wrote
    end

    local root = GetLocalRoot()
    root.channels = root.channels or {}
    root.channels[channelKey] = value
    return true
end

function S:SaveWindowState()
    local state = I.settings and I.settings.windowState
    if type(state) ~= "table" then
        return false
    end

    local wrote, usingVault = self:VaultSet("settings", "windowState", state)
    if usingVault then
        return wrote
    end

    GetLocalRoot().windowState = state
    return true
end

function S:LoadHistory()
    local stored, usingVault = self:VaultGet("history")
    if usingVault and type(stored) == "table" then
        return stored, false
    end

    local root = PeekLocalRoot()

    -- A 1.4 payload the local fallback wrote while the vault was missing beats
    -- the 1.3 line array. Report it as a migration only when the vault is back,
    -- so it gets rewritten into the vault instead of read from here forever.
    if root and type(root.history) == "table" then
        return root.history, usingVault
    end

    -- Version 1.3 stored the line array under settings.savedHistory. Return it
    -- as a migration source and remove it only after the versioned write wins.
    local legacy = I.settings and I.settings.savedHistory
    if type(legacy) ~= "table" and root then
        legacy = root.savedHistory
    end
    if type(legacy) == "table" then
        return legacy, true
    end

    return nil, false
end

function S:SaveHistory(payload)
    if type(payload) ~= "table" then
        return false
    end

    local wrote, usingVault = self:VaultSet("history", payload)
    if usingVault then
        if wrote then
            self:VaultMutate("settings", function(settings)
                if type(settings) ~= "table" then
                    settings = I.settings or {}
                end
                settings.savedHistory = nil
                return settings
            end)
            if I.settings then
                I.settings.savedHistory = nil
            end
            -- Retire the fully migrated 1.3 array locally too. root.history is
            -- deliberately left alone: it is the same schema and the only thing
            -- left to read if DataVault is ever disabled again.
            local root = PeekLocalRoot()
            if root then
                root.savedHistory = nil
            end
        end
        return wrote
    end

    local root = GetLocalRoot()
    root.history = payload
    root.savedHistory = nil
    if I.settings then
        I.settings.savedHistory = nil
    end
    return true
end

function I:ResolveStorage()
    S:Resolve()
end
