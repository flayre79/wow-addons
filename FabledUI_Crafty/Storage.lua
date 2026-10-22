
local M = _G.FabledUI_Crafty

local NAMESPACE_KEY = "crafty"

local DV_DB_PATH = "db"
local DV_SETTINGS_PATH = "settings"
local DV_FILTERS_PATH = "filters"

local defaults = {
    db = {
        alts = {},
        queue = {},
        history = {
            crafting = {},
            farming = {},
            acquisitions = {},
            prices = {},
            sessions = {},
        },
        cache = {
            recipes = {},
            prices = {},
            snapshots = {},
            scanMeta = {},
            exports = {},
        },
        window = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 1180,
            height = 700,
            scale = 1,
            alpha = 1,
            displayState = "expanded",
            ribbonPoint = "TOP",
            ribbonRelativePoint = "TOP",
            ribbonX = 0,
            ribbonY = -160,
            ribbonWidth = 260,
            ribbonHeight = 24,
        },
        exportWindow = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 760,
            height = 500,
        },
        advisor = {
            enabled = true,
        },
        knowledge = {
            selectedCategory = "ALL",
        },
        hud = {
            pinned = false,
            visible = false,
            window = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 420,
                y = 140,
            },
            session = {
                active = false,
                startedAt = 0,
                gathered = 0,
                nodes = {},
                resourceKey = "lumber",
            },
        },
        -- P2-7 / P2-15: per-character settings keyed by characterKey
        -- ("Name-Realm"). Hosts the moved-to-char tooltip profession filter
        -- bitmask and the Skillet-style ignored-mats opt-out set.
        charSettings = {},
    },
    settings = {
        showUncollectedOnly = false,
        showReadyOnly = false,
        showAltKnowledge = true,
        showMaterialTotals = true,
        groupByCharacter = true,
        showProfitAnalysis = true,
        -- Module enable/disable flags. See ModuleRegistry.lua for the full
        -- catalog. Each module's default state lives in its manifest;
        -- this table only holds explicit user overrides. Legacy donor-named
        -- flags (craftSimFeatures, simpleCraftSimEnabled, mkptModuleEnabled,
        -- pktModuleEnabled, craftSimModuleEnabled) are migrated into this
        -- table on first load by ModuleRegistry:MigrateLegacySettings().
        modules = {},
        showOnlyCurrentExpansion = false,
        showMatsInSearch = true,
        pinHUD = false,
        autoRefresh = true,
        tooltipProfessionIconsEnabled = true,
        tooltipProfIncludeVendor = true,
        tooltipProfClassicIcons = false,
        tooltipProfIconSize = 18,
        tooltipProfFilterMask = 0x3FF,
        -- P2-6: tooltip modifier-key gate. "OFF" / "SHIFT" / "CTRL" / "ALT".
        tooltipModifier = "OFF",
        upgradeIconsOnTooltip = true,
        upgradeIconsOnContainers = false,
        upgradeIconLocation = 1,
        upgradeIconScale = 1,
        upgradeIconOffsetX = 1,
        upgradeIconOffsetY = 1,
        concentrationNotificationsEnabled = true,
        concentrationForecastTarget = 1000,
        tokenTooltipDetailsEnabled = true,
        tokenTooltipOnlyForEligible = false,
        tooltipExpansionInfoEnabled = true,
        tooltipProfessionTextEnabled = false,
        tooltipAssistanceEnabled = true,
        tooltipAssistanceShowIcons = true,
        tooltipAssistanceLocationsEnabled = true,
        tooltipAssistanceMillingEnabled = true,
        tooltipAssistanceProspectingEnabled = true,
        tooltipAssistanceDisenchantEnabled = true,
        knowledgeShowFirstCraft = false,
        knowledgeShowUnique = true,
        knowledgeShowTreasure = true,
        knowledgeShowGathering = true,
        knowledgeShowWeekly = true,
        shoppingListModePSL = false,
        guideShowAllSteps = false,
        guideShowKnowledgeSources = true,
        useCraftSimQueuePlanner = false,
        useCraftSimProfitModel = false,
        profitIncludeAHCut = true,
        profitUseSubcraftCost = true,
        profitIncludeResourcefulness = true,
        autoDecrementQueueOnCraft = true,
        activityCraftLogEnabled = true,
        -- HousingLumberHelper-inspired farming options
        farmAutoPauseEnabled = true,
        farmScanWarbandBank = true,
        farmTrackEnabled = true,
        filterProfession = "ALL",
        filterExpansion = "ALL",
        filterCollected = "ALL",
        -- CR-006b: global UI text/scale option for the Crafty main window.
        -- Applied via frame:SetScale on Init and on slider change.
        uiScale = 1.0,
    },
    filters = {
        text = "",
        profession = "ALL",
        expansion = "ALL",
        collected = "ALL",
        readyOnly = false,
        searchMats = true,
        uncollectedOnly = false,
        powerCrafting = false,
        -- Default-ON: show the recipes the current character actually knows
        -- first. Toggle off (or type a search) to surface the unlearned
        -- catalog. This keeps the Recipes tab tractable on first open and
        -- reflects the workflow ("what can I craft?") most users want.
        knownOnly = true,
        -- CR-006: Queue tab Materials column display mode.
        -- false = legacy text "Name xN, ..." rendering.
        -- true  = compact icon row with stack-count overlays + tooltips.
        materialsAsIcons = false,
    },
}

local function deepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local out = {}
    for key, value in pairs(src) do
        out[key] = deepCopy(value)
    end
    return out
end

local function applyDefaults(target, template)
    if type(target) ~= "table" or type(template) ~= "table" then
        return
    end
    for key, value in pairs(template) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function getDataVault()
    local dv = DataVault
    if dv and dv.IsAvailable and dv:IsAvailable() and dv.Get and dv.Set then
        return dv
    end
    return nil
end

local function dvGetTable(dv, addonKey, path)
    if not dv then
        return nil
    end
    local ok, value = pcall(dv.Get, dv, "account", addonKey, path, nil)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function dvSetTable(dv, addonKey, path, value)
    if not dv then
        return false
    end
    return pcall(dv.Set, dv, "account", addonKey, path, value)
end

function M:EnsureStorageTables()
    self.db = type(self.db) == "table" and self.db or {}
    self.settings = type(self.settings) == "table" and self.settings or {}
    self.filters = type(self.filters) == "table" and self.filters or {}

    applyDefaults(self.db, defaults.db)
    applyDefaults(self.settings, defaults.settings)
    applyDefaults(self.filters, defaults.filters)

    self.db.alts = type(self.db.alts) == "table" and self.db.alts or {}
    self.db.queue = type(self.db.queue) == "table" and self.db.queue or {}
    self.db.history = type(self.db.history) == "table" and self.db.history or {}
    self.db.cache = type(self.db.cache) == "table" and self.db.cache or {}
    self.db.cache.recipes = type(self.db.cache.recipes) == "table" and self.db.cache.recipes or {}
    self.db.cache.scanMeta = type(self.db.cache.scanMeta) == "table" and self.db.cache.scanMeta or {}
    self.db.cache.exports = type(self.db.cache.exports) == "table" and self.db.cache.exports or {}
    self.db.window = type(self.db.window) == "table" and self.db.window or {}
    self.db.exportWindow = type(self.db.exportWindow) == "table" and self.db.exportWindow or {}
    self.db.hud = type(self.db.hud) == "table" and self.db.hud or {}
    self.db.hud.window = type(self.db.hud.window) == "table" and self.db.hud.window or {}
    self.db.history.acquisitions = type(self.db.history.acquisitions) == "table" and self.db.history.acquisitions or {}
    self.db.history.prices = type(self.db.history.prices) == "table" and self.db.history.prices or {}
    self.db.history.crafting = type(self.db.history.crafting) == "table" and self.db.history.crafting or {}
    self.db.history.sessions = type(self.db.history.sessions) == "table" and self.db.history.sessions or {}
    self.db.knowledge = type(self.db.knowledge) == "table" and self.db.knowledge or {}
    self.db.cooldowns = type(self.db.cooldowns) == "table" and self.db.cooldowns or {}
    self.db.charSettings = type(self.db.charSettings) == "table" and self.db.charSettings or {}
end

function M:GetDataVault()
    return getDataVault()
end

function M:ResolveStorage()
    local dv = getDataVault()
    local db, settings, filters

    if dv and dv.EnsureNamespace then
        pcall(dv.EnsureNamespace, dv, NAMESPACE_KEY)
        if dv.EnableProfiles then
            pcall(dv.EnableProfiles, dv, NAMESPACE_KEY)
        end
    end

    if dv then
        db = dvGetTable(dv, NAMESPACE_KEY, DV_DB_PATH)
        if type(db) ~= "table" then
            db = deepCopy(defaults.db)
            dvSetTable(dv, NAMESPACE_KEY, DV_DB_PATH, db)
        end

        settings = dvGetTable(dv, NAMESPACE_KEY, DV_SETTINGS_PATH)
        if type(settings) ~= "table" then
            settings = deepCopy(defaults.settings)
            dvSetTable(dv, NAMESPACE_KEY, DV_SETTINGS_PATH, settings)
        end

        filters = dvGetTable(dv, NAMESPACE_KEY, DV_FILTERS_PATH)
        if type(filters) ~= "table" then
            filters = deepCopy(defaults.filters)
            dvSetTable(dv, NAMESPACE_KEY, DV_FILTERS_PATH, filters)
        end

        self._storageBackend = "DataVault Core"
    else
        _G.FabledUI_CraftyDB = _G.FabledUI_CraftyDB or {}
        db = _G.FabledUI_CraftyDB

        _G.FabledUI_CraftySettings = _G.FabledUI_CraftySettings or {}
        applyDefaults(_G.FabledUI_CraftySettings, {
            settings = defaults.settings,
            filters = defaults.filters,
        })
        settings = _G.FabledUI_CraftySettings.settings
        filters = _G.FabledUI_CraftySettings.filters
        self._storageBackend = "SavedVariables"
    end

    self.db = type(db) == "table" and db or deepCopy(defaults.db)
    self.settings = type(settings) == "table" and settings or deepCopy(defaults.settings)
    self.filters = type(filters) == "table" and filters or deepCopy(defaults.filters)

    self:EnsureStorageTables()

    -- The db table may have just been swapped for the DataVault-backed one;
    -- any merged-recipe memo built before this point is stale (it was the
    -- root cause of "recipes show 0 at login despite a persisted cache").
    if self.Recipes and self.Recipes.InvalidateMerged then
        self.Recipes:InvalidateMerged()
    end

    -- Sanitize filter values persisted during the empty-profession-name bug
    -- era: an "" profession/expansion filter silently hides every record
    -- once recipes carry real names again.
    if type(self.filters) == "table" then
        if self.filters.profession == "" then self.filters.profession = "ALL" end
        if self.filters.expansion == "" then self.filters.expansion = "ALL" end
    end

    -- Suite-rename migration: convert legacy donor-named module flags
    -- (craftSimFeatures, simpleCraftSimEnabled, mkptModuleEnabled,
    -- pktModuleEnabled, craftSimModuleEnabled) into the new modules{}
    -- table keyed by suite-canonical names (profit / reagentPicker /
    -- topGear / specs / concentration / overlay / allocator / knowledge).
    -- See ModuleRegistry.lua:MigrateLegacySettings.
    if self.Modules and self.Modules.MigrateLegacySettings then
        self.Modules:MigrateLegacySettings()
    end

    -- One-time migration: switch existing users to "Known recipes only" as
    -- the default lens, and reset any prior auto-applied "Midnight only"
    -- expansion cap so users see their full known recipe set. Future
    -- explicit choices are honored.
    if not self.settings._knownOnlyDefaultMigrated then
        self.filters.knownOnly = true
        if self.filters.expansion == "Midnight" then
            self.filters.expansion = "ALL"
        end
        self.settings._knownOnlyDefaultMigrated = true
    end

    self:MarkDirty()
    self:Fire("StorageReady")
end

function M:SaveSettings()
    local dv = getDataVault()
    if dv then
        pcall(dv.Set, dv, "account", NAMESPACE_KEY, DV_SETTINGS_PATH, self.settings)
        pcall(dv.Set, dv, "account", NAMESPACE_KEY, DV_FILTERS_PATH, self.filters)
        pcall(dv.Set, dv, "account", NAMESPACE_KEY, DV_DB_PATH, self.db)
    else
        _G.FabledUI_CraftySettings = _G.FabledUI_CraftySettings or {}
        _G.FabledUI_CraftySettings.settings = self.settings
        _G.FabledUI_CraftySettings.filters = self.filters
        _G.FabledUI_CraftyDB = self.db
    end
    -- P0-2: profit settings can change here (engine toggles, AH-cut, etc.).
    -- Drop the memoized profit cache so the next render recomputes against
    -- the new toggles instead of replaying stale results.
    if self.Profit and self.Profit.InvalidateCache then
        self.Profit:InvalidateCache()
    end
    self:MarkDirty()
    self:Fire("RecipeFiltersChanged")
end
