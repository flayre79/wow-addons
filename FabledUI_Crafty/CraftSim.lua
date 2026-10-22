-- FabledUI_Crafty/CraftSim.lua
--
-- CraftSim Module facade.
--
-- Bundles the CraftSim-derived feature surface (profit calculation, reagent
-- optimization, top-gear recommendations, specialization tracking, live
-- crafting-form overlay, concentration curves) into a single togglable
-- module. Users can disable the entire CraftSim Module if they only want
-- core Crafty (recipe browser, queue, materials, alts, knowledge tabs) and
-- prefer the standalone CraftSim addon for the heavyweight features.
--
-- Per-feature toggles let users keep some pieces (e.g. profit engine) and
-- drop others (e.g. live overlay) without losing the rest.
--
-- Public API:
--   M.CraftSim:IsEnabled()                  -> bool   master toggle
--   M.CraftSim:IsFeatureEnabled(key)        -> bool   per-feature gate
--   M.CraftSim:SetEnabled(bool)                       master toggle setter
--   M.CraftSim:SetFeatureEnabled(key, bool)           per-feature setter
--   M.CraftSim:Features()                   -> table  iteration over feature defs
--
-- Each consumer (Profit / ReagentOptimizer / GearOptimizer / Specs /
-- Concentration / Hooks) calls IsFeatureEnabled at its public entry point
-- and bails cleanly when disabled. Disabling the module never breaks core
-- Crafty (Recipes / Queue / Materials / Alts / Knowledge / Settings).

local M = _G.FabledUI_Crafty
if not M then return end

M.CraftSim = M.CraftSim or {}
local CS = M.CraftSim

CS.VERSION = "0.1.0"

-- Feature catalog. Order matters for the Settings panel rendering.
CS.FEATURE_ORDER = {
    "profit",
    "reagentOptimizer",
    "gearOptimizer",
    "specs",
    "concentration",
    "hooks",
}

CS.FEATURES = {
    profit = {
        name = "Profit Engine",
        desc = "CraftSim-style profit-per-craft calculation including multicraft, resourcefulness, and concentration cost amortization.",
    },
    reagentOptimizer = {
        name = "Reagent Optimizer",
        desc = "Recommends optional and finishing reagents to hit a quality target with minimum cost or maximum profit.",
    },
    gearOptimizer = {
        name = "Top Gear",
        desc = "Scans bags, bank, and equipped slots for crafting-stat gear and recommends the best combination per recipe.",
    },
    specs = {
        name = "Specialization Tracker",
        desc = "Per-character spec node cache for Khaz Algar and Midnight profession trees, with per-recipe stat readout.",
    },
    concentration = {
        name = "Concentration",
        desc = "Tracks concentration recharge timers and warns when a profession is at full concentration.",
    },
    hooks = {
        name = "Live Craft Overlay",
        desc = "Adds a Crafty bridge panel inside Blizzard's profession window showing queue status, +Queue / +5 quick actions, and shopping list shortcut.",
    },
}

-- ----------------------------------------------------------------------------
-- Toggle helpers
-- ----------------------------------------------------------------------------

local function settings()
    return M.settings or {}
end

local function featureMap()
    local s = settings()
    s.craftSimFeatures = s.craftSimFeatures or {}
    return s.craftSimFeatures
end

function CS:IsEnabled()
    -- Default ON: only false if the user explicitly disabled the module.
    return settings().craftSimModuleEnabled ~= false
end

-- Detects whether the standalone CraftSim addon is loaded. When it is, our
-- live-overlay (`hooks`) feature steps aside so the user doesn't get two
-- bridge panels and two side-tab strips fighting for the same right-edge.
function CS:IsStandaloneCraftSimLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "CraftSim")
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, "CraftSim")
        if ok and loaded then return true end
    end
    return false
end

function CS:IsFeatureEnabled(featureKey)
    if type(featureKey) ~= "string" then return false end
    if not self:IsEnabled() then return false end
    if not self.FEATURES[featureKey] then return false end
    -- Per-feature toggle: nil = on (default), explicit false = off.
    local override = featureMap()[featureKey]
    if override == false then return false end
    -- Auto step-aside: if standalone CraftSim is loaded, suppress the live
    -- overlay so we don't double up on the ProfessionsFrame chrome. Other
    -- features (profit / reagent / gear / specs / concentration) still run
    -- because they're internal to Crafty's own UI.
    if featureKey == "hooks" and self:IsStandaloneCraftSimLoaded() then
        return false
    end
    return true
end

function CS:SetEnabled(enabled)
    local s = settings()
    s.craftSimModuleEnabled = enabled and true or false
    if M.SaveSettings then M:SaveSettings() end
    if M.Fire then M:Fire("DataChanged") end
end

function CS:SetFeatureEnabled(featureKey, enabled)
    if type(featureKey) ~= "string" or not self.FEATURES[featureKey] then return end
    featureMap()[featureKey] = enabled and true or false
    if M.SaveSettings then M:SaveSettings() end
    if M.Fire then M:Fire("DataChanged") end
end

function CS:Features()
    local out = {}
    for _, key in ipairs(self.FEATURE_ORDER) do
        local def = self.FEATURES[key]
        if def then
            out[#out + 1] = {
                key = key,
                name = def.name,
                desc = def.desc,
                enabled = self:IsFeatureEnabled(key),
            }
        end
    end
    return out
end

-- Convenience: invoke `fn(...)` only when the named feature is enabled.
-- Returns whatever the callback returns, or nil when gated off.
function CS:GuardFeature(featureKey, fn, ...)
    if not self:IsFeatureEnabled(featureKey) then return nil end
    if type(fn) ~= "function" then return nil end
    return fn(...)
end
