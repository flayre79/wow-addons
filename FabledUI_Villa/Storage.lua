local Villa = _G.FabledUI_Villa

local SHARD_KEY = "FabledUI_DataVault_Villa"
local NAMESPACE = "villa"

local DEFAULT_SETTINGS = {
    showMapPins = true,
    showZoneOverlay = true,
    zoneOverlayMinimized = false,
    zoneOverlayPosition = "topLeft",
    zoneOverlayAlpha = 0.9,
    includeCollectedVendorDecor = false,
    showWorldMapButton = true,
    restoreLastPanel = true,
    zoneToasts = true,
    autoAcceptHousingQuests = false,
    showMarketValue = true,
    trackVendorVisits = true,
    showAcquiredAlerts = true,
    acquiredAlertsWishlistOnly = false,
    domainModes = {
        vendors = "hybrid",
        zoneOverlay = "hybrid",
        mapPins = "hybrid",
        professions = "hybrid",
        achievements = "hybrid",
        quests = "hybrid",
        drops = "hybrid",
        catalog = "hdg",
        treasures = "betterhomes",
        styles = "hdg",
        trainers = "hdg",
        tracker = "hit",
        reputation = "housingvendor",
        materials = "housingvendor",
        planning = "housingvendor",
        preview = "housingvendor",
        statistics = "housingvendor",
    },
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- ── Bulk catalog data (LoadOnDemand) ────────────────────────────────────────
-- HITData, HousingVendorData, DecorVendorData, HDGData, BetterHomesData and
-- NormalizedData total ~176,000 lines. They used to load at login inside
-- FabledUI_DataVault_Villa whether or not the player ever opened Villa, which
-- is a large share of the client's Lua memory for data most sessions never
-- touch. They now live in FabledUI_DataVault_Villa_Catalog and load the first
-- time anything actually asks for one of their providers.
local CATALOG_ADDON = "FabledUI_DataVault_Villa_Catalog"
local CATALOG_PROVIDERS = {
    hit = true, housingvendor = true, decorvendor = true,
    hdg = true, betterhomes = true, normalized = true,
}

function Villa:EnsureCatalogData()
    if self._catalogLoaded then
        return true
    end
    if not (C_AddOns and C_AddOns.LoadAddOn) then
        return false
    end
    if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(CATALOG_ADDON) then
        self._catalogLoaded = true
        return true
    end
    local ok, loaded = pcall(C_AddOns.LoadAddOn, CATALOG_ADDON)
    self._catalogLoaded = (ok and (loaded ~= false)) and true or false
    return self._catalogLoaded
end

function Villa:GetProviderStore(providerKey)
    if providerKey and CATALOG_PROVIDERS[providerKey] then
        self:EnsureCatalogData()
    end
    local providers = _G.FabledUI_DataVault_VillaProviders
    if not providers or not providerKey then
        return nil
    end
    return providers[providerKey]
end

-- A stand-in for a provider table that resolves on first use.
--
-- The alias files (Villa.HITData and friends) run at Villa load and used to
-- capture the provider table directly. With the catalog deferred that capture
-- would be an empty table forever -- the silent-empty failure this suite has
-- hit repeatedly. The proxy keeps `Villa.HITData:Method(...)` working
-- unchanged while deferring the load to the first real access.
function Villa:MakeProviderProxy(providerKey)
    local bound = {}
    return setmetatable({}, {
        __index = function(_, key)
            local store = Villa:GetProviderStore(providerKey)
            if type(store) ~= "table" then
                return nil
            end
            local value = store[key]
            if type(value) ~= "function" then
                return value
            end
            -- Rebind `self` to the real store: callers use method syntax, and
            -- passing the proxy as self would hide every field the method reads.
            local wrapper = bound[key]
            if not wrapper then
                wrapper = function(_, ...) return value(store, ...) end
                bound[key] = wrapper
            end
            return wrapper
        end,
    })
end

function Villa:ResolveStorage()
    local usingShard = DataVault and type(DataVault.ShardAvailable) == "function" and DataVault:ShardAvailable(SHARD_KEY) and type(DataVault.ShardGet) == "function"
    if usingShard then
        self.db = DataVault:ShardGet("account", SHARD_KEY, NAMESPACE, nil, {})
    else
        _G.FabledUI_VillaDB = _G.FabledUI_VillaDB or {}
        self.db = _G.FabledUI_VillaDB
    end

    self.db.schemaVersion = self.db.schemaVersion or 1
    self.db.customVendors = self.db.customVendors or {}
    self.db.wishlist = self.db.wishlist or {}
    self.db.wishlist.entries = self.db.wishlist.entries or {}
    self.db.ui = self.db.ui or {}
    self.db.ui.tabs = self.db.ui.tabs or {}
    self.db.ui.tabs.lastPanel = self.db.ui.tabs.lastPanel or "vendors"
    self.db.ui.tabs.wasVillaMode = self.db.ui.tabs.wasVillaMode or false
    self.db.settings = self.db.settings or {}
    self.db.shoppingLists = self.db.shoppingLists or {}
    self.db.itemNotes = self.db.itemNotes or {}
    self.db.toastCooldowns = self.db.toastCooldowns or {}
    self.db.ownedCounts = self.db.ownedCounts or {}
    self.db.placedCounts = self.db.placedCounts or {}
    self.db.wishlists = self.db.wishlists or {}
    self.db.vendorsVisited = self.db.vendorsVisited or {}
    self.db.acquiredSeen = self.db.acquiredSeen or {}

    local legacyState = _G.FabledUI_VillaDB
    local legacySettings = _G.FabledUI_VillaSettings
    if usingShard and not self.db._migratedFromLegacy then
        if type(legacyState) == "table" then
            if next(self.db.customVendors) == nil and type(legacyState.customVendors) == "table" then
                self.db.customVendors = legacyState.customVendors
            end
            if (not self.db.wishlist or not next(self.db.wishlist.entries or {})) and type(legacyState.wishlist) == "table" then
                self.db.wishlist = legacyState.wishlist
                self.db.wishlist.entries = self.db.wishlist.entries or {}
            end
            if (not self.db.ui or not next(self.db.ui.tabs or {})) and type(legacyState.ui) == "table" then
                self.db.ui = legacyState.ui
                self.db.ui.tabs = self.db.ui.tabs or {}
            end
        end
        if type(legacySettings) == "table" then
            for k, v in pairs(legacySettings) do
                if self.db.settings[k] == nil then
                    self.db.settings[k] = v
                end
            end
        end
        self.db._migratedFromLegacy = true
    end

    self.settings = self.db.settings
    _G.FabledUI_VillaSettings = self.settings
    CopyDefaults(self.settings, DEFAULT_SETTINGS)
end