-- FabledUI_Crafty/ModuleRegistry.lua
--
-- Crafty Suite module registry.
--
-- Crafty is a "suite within a suite": a thin shell container that bootstraps,
-- persists data, hosts the main window, and registers/coordinates a fleet of
-- toggleable feature modules. Each module owns one feature domain (profit,
-- top-gear, knowledge, allocator, etc.) and can be enabled/disabled
-- independently from the Crafty Settings panel.
--
-- A module manifest looks like:
--   {
--     key            = "knowledge",     -- canonical, lowercase key
--     label          = "Knowledge Codex",
--     description    = "...",
--     order          = 30,              -- display order in Settings + tab strip
--     defaultEnabled = true,
--     addonName      = "FabledUI_Crafty_Knowledge",  -- optional: sibling LoD addon
--     dependencies   = { "tooltips" },                -- other module keys required
--     dataShards     = { "FabledUI_Crafty_Data_Alchemy", ... },  -- optional
--     replaces       = "MKPT",          -- legacy donor name (for setting migration)
--   }
--
-- Modules with `addonName` set are external sibling addons (LoadOnDemand);
-- the registry calls LoadAddOn(addonName) when the user enables them.
-- Modules without `addonName` are still loaded inside FabledUI_Crafty for
-- now; over time they will migrate to sibling addons.

local M = _G.FabledUI_Crafty
if not M then return end

M.Modules = M.Modules or {}
local R = M.Modules
R._defs = R._defs or {}
R._tabs = R._tabs or {}
R._slashHandlers = R._slashHandlers or {}

-- ----------------------------------------------------------------------------
-- Registration / lookup
-- ----------------------------------------------------------------------------

function R:Register(manifest)
    if type(manifest) ~= "table" or type(manifest.key) ~= "string" then return end
    self._defs[manifest.key] = manifest
end

function R:Get(key)
    return self._defs[key]
end

function R:Each()
    local keys = {}
    for k in pairs(self._defs) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local oa = (self._defs[a].order or 100)
        local ob = (self._defs[b].order or 100)
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    local i = 0
    return function()
        i = i + 1
        return self._defs[keys[i]]
    end
end

-- ----------------------------------------------------------------------------
-- Enable / disable
-- ----------------------------------------------------------------------------

local function settingsTable()
    if not M.settings then return nil end
    M.settings.modules = M.settings.modules or {}
    return M.settings.modules
end

function R:IsEnabled(key)
    local def = self._defs[key]
    if not def then return false end
    local s = settingsTable()
    if s then
        if s[key] == false then return false end
        if s[key] == true then return true end
    end
    return def.defaultEnabled ~= false
end

function R:SetEnabled(key, enabled)
    local def = self._defs[key]
    if not def then return end
    local s = settingsTable()
    if not s then return end
    s[key] = enabled and true or false
    if M.SaveSettings then M:SaveSettings() end
    if M.Fire then M:Fire("DataChanged") end
    -- If the user enabled a sibling-addon module, kick the LoadAddOn now so
    -- it lights up without /reload (when possible — some addons need a
    -- restart for hooks to install cleanly, in which case we'll surface a
    -- "/reload to apply" hint in the Settings panel).
    if enabled and def.addonName then
        self:EnsureLoaded(key)
        -- Modules that hook Blizzard_Professions install in ADDON_LOADED for
        -- that addon. If the user toggles them on after PLAYER_LOGIN, the
        -- ADDON_LOADED event has already fired and Hooks/Init won't re-run
        -- on its own. Trigger a one-shot init pass so the bridge / side tabs
        -- appear without /reload.
        if key == "overlay" and M.Hooks and M.Hooks.Init
            and C_AddOns and C_AddOns.IsAddOnLoaded
            and C_AddOns.IsAddOnLoaded("Blizzard_Professions")
        then
            pcall(function() M.Hooks:Init() end)
        end
    end
end

-- Resolve a sibling-addon module (LoadAddOn). In-process modules return true
-- immediately. Returns true on success, false if loading failed.
function R:EnsureLoaded(key)
    local def = self._defs[key]
    if not def then return false end
    if not def.addonName then return true end
    if not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(def.addonName) then
        return true
    end
    local ok, loaded = pcall(C_AddOns.LoadAddOn, def.addonName)
    return ok and (loaded or (C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(def.addonName)) or false) or false
end

-- ----------------------------------------------------------------------------
-- Tab registry — modules contribute tabs to the main Crafty window
-- ----------------------------------------------------------------------------
-- Tab def: { key, label, order, onRender(parentFrame), tooltip? }

function R:RegisterTab(moduleKey, tabDef)
    if type(tabDef) ~= "table" or type(tabDef.key) ~= "string" then return end
    self._tabs[#self._tabs + 1] = { module = moduleKey, def = tabDef }
end

function R:EachTab()
    table.sort(self._tabs, function(a, b)
        return (a.def.order or 100) < (b.def.order or 100)
    end)
    local i = 0
    return function()
        i = i + 1
        local entry = self._tabs[i]
        if not entry then return nil end
        if not self:IsEnabled(entry.module) then
            -- Skip tabs whose owning module is disabled. The iterator
            -- recurses to the next entry by repeating itself. Bounded by
            -- the for-loop's own termination so this can't infinite loop.
            return self:EachTab()()
        end
        return entry.def
    end
end

-- ----------------------------------------------------------------------------
-- Slash command registry — modules contribute /crafty <subcommand> handlers
-- ----------------------------------------------------------------------------

function R:RegisterSlash(moduleKey, command, handler)
    if type(command) ~= "string" or type(handler) ~= "function" then return end
    self._slashHandlers[command:lower()] = { module = moduleKey, fn = handler }
end

function R:DispatchSlash(command, rest)
    if type(command) ~= "string" then return false end
    local entry = self._slashHandlers[command:lower()]
    if not entry then return false end
    if not self:IsEnabled(entry.module) then return false end
    -- Auto-load sibling-addon module if it isn't loaded yet, so /crafty <cmd>
    -- "just works" even before the user opens the main window.
    self:EnsureLoaded(entry.module)
    local ok, err = pcall(entry.fn, rest)
    if not ok and M.Print then
        M:Print("|cffff5555slash error (" .. tostring(command) .. "):|r " .. tostring(err))
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Hardcoded manifest catalog — the universe of Crafty modules.
--
-- Modules with `addonName` are sibling LoadOnDemand addons. The rest are
-- in-process for now and will migrate to sibling addons over time. Their
-- "promotion" requires only adding the addonName field + creating the
-- sibling-addon directory; the registry API doesn't change.
-- ----------------------------------------------------------------------------

local CATALOG = {
    -- Crafting engines (CraftSim-style domain)
    {
        key = "profit", label = "Profit Engine", order = 10,
        description = "Profit-per-craft calculation including multicraft, resourcefulness, and concentration cost amortization.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Profit",
        replaces = "craftSimFeatures.profit",
    },
    {
        key = "reagentPicker", label = "Reagent Picker", order = 11,
        description = "Recommends optional and finishing reagents to hit a quality target with minimum cost.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_ReagentPicker",
        replaces = "craftSimFeatures.reagentOptimizer",
    },
    {
        key = "topGear", label = "Top Gear", order = 12,
        description = "Scans bags / bank / equipped slots for crafting-stat gear and recommends the best combination per recipe.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_TopGear",
        replaces = "craftSimFeatures.gearOptimizer",
    },
    {
        key = "specs", label = "Specializations", order = 13,
        description = "Per-character spec node cache for Khaz Algar and Midnight profession trees.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Specs",
        replaces = "craftSimFeatures.specs",
    },
    {
        key = "concentration", label = "Concentration", order = 14,
        description = "Tracks concentration recharge timers and warns when a profession is at full concentration.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Concentration",
        replaces = "craftSimFeatures.concentration",
    },

    -- Profession-window integration
    {
        key = "overlay", label = "Live Profession Overlay", order = 20,
        description = "Bridge panel + side-tab strip + bottom Queue/Materials/Goblin/Guide/Knowledge tabs inside Blizzard's profession window.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Overlay",
        replaces = "craftSimFeatures.hooks",
    },
    {
        key = "allocator", label = "Reagent Allocator", order = 21,
        description = "Adds an Unlock checkbox under Track Recipe so reagent allocations aren't blocked by inventory state — useful for queue planning.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Allocator",
        replaces = "simpleCraftSimEnabled",
    },

    -- Knowledge / treasure
    {
        key = "knowledge", label = "Knowledge Codex", order = 30,
        description = "Knowledge tab + per-profession KP source data shards + Midnight treasure auto-supertrack on vignette match.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Knowledge",
        replaces = "mkptModuleEnabled",
    },

    -- Information layers
    {
        key = "tooltips", label = "Tooltip Enrichment", order = 40,
        description = "Profession icons, upgrade indicators, raid token details, milling/prospecting yields in item tooltips.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Tooltips",
    },
    {
        key = "trainers", label = "Trainer Codex", order = 41,
        description = "Trainer locations + skill-up paths across every expansion with one-click waypoints.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Trainers",
    },
    {
        key = "roster", label = "Alt Roster", order = 42,
        description = "Account-wide profession matrix + cooldown timers across all alts.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Roster",
    },
    {
        key = "history", label = "Craft History", order = 43,
        description = "Craft log, capture (loot / vendor), farm session telemetry.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_History",
    },
    {
        key = "lumber", label = "Lumber Tracker", order = 44,
        description = "Lumber-specific HUD + woodcutting node telemetry. Niche — disabled by default.",
        defaultEnabled = false,
        addonName = "FabledUI_Crafty_Lumber",
    },
    {
        key = "advisor", label = "Profession Advisor", order = 45,
        description = "Contextual recommendations for the open profession session.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Advisor",
    },
    {
        key = "guild", label = "Guild Crafters", order = 46,
        description = "Query guild members for known recipes; show online crafters per recipe.",
        defaultEnabled = true,
        addonName = "FabledUI_Crafty_Guild",
    },
}

function R:RegisterDefaults()
    for _, manifest in ipairs(CATALOG) do
        self:Register(manifest)
    end
end

R:RegisterDefaults()

-- ----------------------------------------------------------------------------
-- Settings migration: legacy donor-named flags -> modules{} table
-- ----------------------------------------------------------------------------
-- Called from Storage.lua after settings load. One-shot conversion: reads
-- old keys (craftSimFeatures, simpleCraftSimEnabled, mkptModuleEnabled,
-- pktModuleEnabled, craftSimModuleEnabled) into M.settings.modules{} and
-- nukes the originals so they don't drift.
function R:MigrateLegacySettings()
    if not M.settings then return end
    M.settings.modules = M.settings.modules or {}
    local m = M.settings.modules

    -- CraftSim umbrella (old craftSimFeatures table)
    local cf = M.settings.craftSimFeatures
    if type(cf) == "table" then
        if m.profit         == nil then m.profit         = cf.profit ~= false end
        if m.reagentPicker  == nil then m.reagentPicker  = cf.reagentOptimizer ~= false end
        if m.topGear        == nil then m.topGear        = cf.gearOptimizer ~= false end
        if m.specs          == nil then m.specs          = cf.specs ~= false end
        if m.concentration  == nil then m.concentration  = cf.concentration ~= false end
        if m.overlay        == nil then m.overlay        = cf.hooks ~= false end
    end
    if M.settings.craftSimModuleEnabled == false then
        -- Master kill switch overrode everything. Honor that intent.
        m.profit, m.reagentPicker, m.topGear = false, false, false
        m.specs, m.concentration, m.overlay = false, false, false
    end

    -- Donor-named modules
    if M.settings.simpleCraftSimEnabled ~= nil and m.allocator == nil then
        m.allocator = M.settings.simpleCraftSimEnabled ~= false
    end
    if M.settings.mkptModuleEnabled ~= nil and m.knowledge == nil then
        m.knowledge = M.settings.mkptModuleEnabled ~= false
    end
    if M.settings.pktModuleEnabled == false then
        -- PKT-disabled translates to knowledge-disabled (per the design
        -- decision to fold PKT into the Knowledge module).
        m.knowledge = false
    end

    -- Drop legacy keys so they don't reappear in saved variables.
    M.settings.craftSimFeatures      = nil
    M.settings.craftSimModuleEnabled = nil
    M.settings.simpleCraftSimEnabled = nil
    M.settings.mkptModuleEnabled     = nil
    M.settings.pktModuleEnabled      = nil
end
