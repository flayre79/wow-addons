local addonName, ns = ...

_G.FabledUI_VillaShardDB = _G.FabledUI_VillaShardDB or {
    schemaVersion = 1,
    customVendors = {},
    wishlist = { entries = {} },
    ui = { tabs = { lastPanel = "vendors", wasVillaMode = false } },
    settings = {},
    meta = { providersLoaded = false },
}

_G.FabledUI_DataVault_VillaProviders = _G.FabledUI_DataVault_VillaProviders or {}

local runtime = _G.FabledUI_VillaShardDB
runtime.schemaVersion = runtime.schemaVersion or 1
runtime.customVendors = runtime.customVendors or {}
runtime.wishlist = runtime.wishlist or { entries = {} }
runtime.wishlist.entries = runtime.wishlist.entries or {}
runtime.ui = runtime.ui or {}
runtime.ui.tabs = runtime.ui.tabs or { lastPanel = "vendors", wasVillaMode = false }
runtime.settings = runtime.settings or {}
runtime.meta = runtime.meta or {}
runtime.providers = _G.FabledUI_DataVault_VillaProviders
runtime.meta.providersLoaded = true

local function registerShard()
    if DataVault and type(DataVault.RegisterShard) == "function" then
        DataVault:RegisterShard("FabledUI_DataVault_Villa", runtime)
    end
end

-- DV-002: Previously registered on both ADDON_LOADED and PLAYER_LOGIN,
-- causing a duplicate "Registered Shard" line during startup. PLAYER_LOGIN
-- now only acts as a fallback in case Core wasn't ready at ADDON_LOADED.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        registerShard()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        registerShard()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
