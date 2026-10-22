local addonName, _ = ...
DataVault = DataVault or {}
local DV = DataVault

DV.VERSION = "1.0.0"
DV.dirtyFlags = {}
DV.shards = {} -- Registry of active shard addons

-- Root Storage
DataVaultDB = DataVaultDB or { addons = {}, tags = {}, importState = {} }
DataVaultCharDB = DataVaultCharDB or { addons = {} }

function DV:Print(...)
    print("|cff00ccff[DataVault]|r", ...)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        DV.isLoaded = true
    elseif event == "PLAYER_LOGIN" then
        DV:Print("Core Storage Online. Version", DV.VERSION)
    end
end)

-- Slash Commands
SLASH_DATAVAULT1 = "/datavault"
SLASH_DATAVAULT2 = "/dv"
-- /dv checkpoint calls ReloadUI() to force every addon to flush its
-- SavedVariables. That's destructive — anything mid-typing dies. Surface a
-- standard popup confirmation so the user can bail.
-- Do NOT reassign the global StaticPopupDialogs (e.g. `= StaticPopupDialogs or {}`).
-- Writing the *global* from insecure addon code taints it, and then EVERY Blizzard
-- popup's OnAccept inherits the taint — which is exactly what broke
-- AcceptSpellConfirmationPrompt() (spell learn) and UpgradeItem() (item upgrade).
-- Adding our own KEY is safe; StaticPopupDialogs always exists (Blizzard global).
StaticPopupDialogs["FABLEDUI_DATAVAULT_CHECKPOINT"] = {
    text         = "DataVault: Checkpoint will trigger /reload.\n\nAny unsaved typing or open dialogs will be lost. Continue?",
    button1      = "Reload",
    button2      = "Cancel",
    OnAccept     = function() DV:Checkpoint(nil, { force = true }) end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3, -- avoid taint from the default visible-frame index
}

SlashCmdList["DATAVAULT"] = function(msg)
    local cmd = string.lower(strtrim(msg))
    if cmd == "checkpoint" then
        StaticPopup_Show("FABLEDUI_DATAVAULT_CHECKPOINT")
    elseif cmd == "checkpoint!" or cmd == "checkpoint-force" then
        -- Power-user escape hatch: skip the popup. Documented in the help
        -- line below so it's discoverable.
        DV:Checkpoint(nil, { force = true })
    elseif cmd == "stats" then
        DV:PrintStats()
    elseif cmd == "ui" then
        DV:ToggleUI()
    elseif cmd == "minimap" then
        DV:ToggleMinimapIcon()
    else
        DV:Print("Commands: /dv ui | /dv checkpoint [!] | /dv stats | /dv minimap")
    end
end

function DV:IsAvailable()
    return true
end