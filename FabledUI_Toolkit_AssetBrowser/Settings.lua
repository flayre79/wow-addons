local addonName, ns = ...

function ns:RegisterSettings()
    if self.SettingsCategory or not self.DB or not self.DB.assetBrowser then
        return
    end
    if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterProxySetting then
        return
    end

    local category = Settings.RegisterVerticalLayoutCategory("FabledUI: Asset Browser")
    self.SettingsCategory = category

    local function refresh()
        if ns.AssetBrowser and ns.AssetBrowser.frame and ns.AssetBrowser.frame:IsShown() then
            ns.AssetBrowser:RefreshAllData()
        end
    end

    -- TAINT SAFETY (2026-07-13): the three checkboxes formerly used
    -- Settings.RegisterAddOnSetting bound to the SavedVariable ns.DB.assetBrowser
    -- (FabledUI_Toolkit_AssetBrowserDB). Binding a SavedVariable into the Settings
    -- framework taints the panel-commit path (ExitWithCommit -> ToggleGameMenu ->
    -- ClearTarget()) — the recurring protected-function / tainted-logout bug. We
    -- now use RegisterProxySetting with getter/setter closures so the SavedVariable
    -- is only ever touched by our own insecure code.
    -- Reference impl: FabledUI_Poseidon/Modules/Settings.lua.
    local db = ns.DB.assetBrowser
    local function proxyBool(uniqueKey, variableKey, name, default, tooltip)
        local setting = Settings.RegisterProxySetting(category, addonName .. "_" .. uniqueKey, type(true), name, default,
            function()
                local v = db[variableKey]
                if v == nil then return default end
                return v
            end,
            function(value)
                db[variableKey] = value
                refresh()
            end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    proxyBool("Enabled", "enabled", "Enable Asset Browser", true,
        "Allows the Asset Browser to open and register with suite tools.")
    proxyBool("OpenOnLogin", "openOnLogin", "Open on Login", false,
        "Opens the browser automatically on login.")
    proxyBool("IncludeMissingAtlases", "includeMissingAtlases", "Include Database-only Atlases", false,
        "Shows atlas entries from the bundled database even if the live API does not expose them.")

    Settings.RegisterAddOnCategory(category)
end
