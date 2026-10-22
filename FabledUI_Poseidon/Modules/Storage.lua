local P = _G.FabledUI_Poseidon
if not P then return end

local SHARD_KEY = "FabledUI_DataVault_Poseidon"
local ADDON_KEY = "poseidon"

local DEFAULT_SETTINGS = {
    enableMapPins = true,
    enableAutoLog = true,
    learnPools = true,
    tooltipIntel = true,
    showDerbyTracker = true,
    countTrash = false,
    autoShowHUDWhileFishing = true,
    pinSize = 16,
    sessionTimeoutMinutes = 20,
    -- P1: Fish catalog "Rare only" filter.
    fishRareOnly = false,
    -- P2: Fish catalog junk filter (hide Poor / grey-quality fish).
    fishHideJunk = false,
    -- P3: Buff tracker visibility on the HUD.
    showBuffTracker = true,
    -- P2-1 (May-04 audit): rare-catch toast popup. Set to false to suppress.
    showRareCatchToast = true,
    minimap = {
        hide = false,
        minimapPos = 220,
    },
    hud = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = -360,
        y = 40,
        width = 420,
        -- P3: HUD grew a buff strip; default height bumps so existing
        -- recent-activity slots stay visible without forcing a resize.
        height = 420,
        scale = 1,
        alpha = 1,
        displayState = "expanded",
        ribbonPoint = "TOP",
        ribbonRelativePoint = "TOP",
        ribbonX = 0,
        ribbonY = -160,
        ribbonWidth = 240,
        ribbonHeight = 24,
        locked = false,
    },
    full = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 140,
        y = 20,
        width = 1040,
        height = 720,
        scale = 1,
        alpha = 1,
        displayState = "expanded",
        ribbonPoint = "TOP",
        ribbonRelativePoint = "TOP",
        ribbonX = 0,
        ribbonY = -160,
        ribbonWidth = 280,
        ribbonHeight = 24,
        locked = false,
        selectedPage = "overview",
    },
}

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, nested in pairs(value) do
        out[key] = DeepCopy(nested)
    end
    return out
end

local function MergeDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function P:ResolveStorage()
    if DataVault and DataVault.ShardAvailable and DataVault:ShardAvailable(SHARD_KEY) then
        self.db = DataVault:ShardGet("account", SHARD_KEY, ADDON_KEY, nil, {})
        self._storageBackend = "DataVault Shard"
    else
        _G.FabledUI_PoseidonDB = _G.FabledUI_PoseidonDB or {}
        self.db = _G.FabledUI_PoseidonDB
        self._storageBackend = "Local SVs"
    end

    self.db.nodes = self.db.nodes or {}
    self.db.learned = self.db.learned or {}
    self.db.stats = self.db.stats or {}
    self.db.counts = self.db.counts or {}
    self.db.meta = self.db.meta or {
        schemaVersion = 6,
        lastImportAt = nil,
        lastExportAt = nil,
    }

    if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
        DataVault:EnsureNamespace(ADDON_KEY)
        local settings = DataVault:Get("account", ADDON_KEY, "settings", nil)
        if type(settings) ~= "table" then
            settings = DeepCopy(DEFAULT_SETTINGS)
            DataVault:Set("account", ADDON_KEY, "settings", settings)
        end
        self.settings = MergeDefaults(settings, DEFAULT_SETTINGS)
    else
        _G.FabledUI_PoseidonSettings = MergeDefaults(_G.FabledUI_PoseidonSettings or {}, DEFAULT_SETTINGS)
        self.settings = _G.FabledUI_PoseidonSettings
    end

    self.settings.hud = MergeDefaults(self.settings.hud, DEFAULT_SETTINGS.hud)
    self.settings.full = MergeDefaults(self.settings.full, DEFAULT_SETTINGS.full)
    self.settings.minimap = MergeDefaults(self.settings.minimap, DEFAULT_SETTINGS.minimap)
end
