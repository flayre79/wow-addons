local addonName, ns = ...
local O = ns.Odyssey

-- Odyssey's options live on the Settings tab of its own window, not in
-- Blizzard's Options > AddOns list. That matches the rest of the suite
-- (FabledUI_Iris/UI.lua is the reference), and it retires the taint problem
-- the old registration existed to work around.
--
-- History worth keeping: this file used to call
-- Settings.RegisterAddOnSetting(category, key, variableKey, self.db.settings, ...)
-- which bound the SavedVariable straight into the Settings framework and
-- tainted the panel-commit path (ExitWithCommit -> ToggleGameMenu ->
-- ClearTarget()), producing a recurring protected-function error and a tainted
-- logout dialog. That was then worked around with RegisterProxySetting
-- closures. Building the controls ourselves removes the framework from the
-- path altogether, so there is nothing left to taint.

O.Settings = O.Settings or {}

-- Kept as a no-op entry point because Core:Initialize calls it through
-- SafeCall, and because deleting a name other code still calls is how this
-- suite has previously ended up with silently dead wiring.
function O:RegisterSettings()
    -- Deliberately empty: no Blizzard category is registered any more. The
    -- panel is built by UI/MainFrame.lua:BuildSettingsPanel.
    self.categoryID = nil
end

-- Open Odyssey on its Settings tab.
--
-- This is the hook other addons use to reach an addon's options when it has no
-- Blizzard category -- FabledUI_Nexus/Registry.lua resolves Iris the same way
-- via `settingsPath = "Settings.Open"`.
function O.Settings:Open()
    if not O.UI or not O.UI.MainFrame then
        return false
    end

    O.UI.MainFrame:Toggle(true)
    O.UI.MainFrame:ShowTab("Settings")
    return true
end
