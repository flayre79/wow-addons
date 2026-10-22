-- DataVault Settings panel — registers under the modern Settings
-- (Interface Options) so the suite-wide DataVault has a discoverable
-- knob alongside Nexus/Nemesis/Poseidon. We keep the controls minimal
-- (open UI, toggle minimap icon, suggest checkpoint); the heavy
-- introspection lives in /dv ui.

local DV = DataVault
if not DV then return end

DV.Settings = DV.Settings or {}
local S = DV.Settings

function S:Register()
    -- INTENTIONALLY DISABLED (2026-07-06) — taint fix.
    --
    -- Binding a DataVault table (the minimap SavedVariable) into the Blizzard
    -- Settings framework tainted the panel-commit path. Every time the
    -- Settings panel closed, the commit read DataVault's tainted setting and
    -- carried that taint into ExitWithCommit -> TransitionBackOpeningPanel ->
    -- ToggleGameMenu -> ClearTarget(), producing the recurring
    --   "AddOn 'FabledUI_DataVault' tried to call the protected function 'ClearTarget()'"
    -- and the sibling CancelLogout() block on the logout dialog.
    --
    -- DataVault is fully controllable via /dv (ui / minimap / stats /
    -- checkpoint) and the LibDBIcon right-click menu, so the redundant Blizzard
    -- options-panel entry is dropped rather than made taint-safe. If we ever
    -- want it back, register it backed by a clean (non-SV) proxy and apply the
    -- LibDBIcon change via C_Timer.After(0, ...) so nothing touches addon state
    -- inside the secure settings-commit frame.
    self._registered = true
end

function S:Open()
    if self.cat and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.cat:GetID())
    end
end

-- Bootstrap: register on PLAYER_LOGIN (same point storage is initialised).
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    -- Ensure DataVaultDB.minimapIcon exists before Register touches it.
    DataVaultDB.minimapIcon = DataVaultDB.minimapIcon or { hide = false }
    S:Register()
end)
