local addonName, _ = ...

Nexus = Nexus or {}
local N = Nexus
_G.FabledUI_Nexus = N

N.VERSION = "1.02.03"

function N:Print(...)
    print("|cff00d4ff[Nexus]|r", ...)
end

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return
    end

    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

function N:ResolveStorage()
    local DEFAULTS = {
        anchor = "TOPRIGHT",
        x = -100,
        y = -100,
        locked = false,
        collapsed = false,
        layout = "VERTICAL",
        showNames = false,
        showSettings = true,
        showMinimap = true,
        iconSize = 32,
        settingsIconSize = 16,
        addonConfig = {},
        customRegistry = {},
        detectedRegistry = {},
        autoDetectEnabled = false,
        autoDetectIncludeLoadedOnly = false,
        autoDetectEnabledOnly = true,
        scanIgnoreDataStore = true,
        favorites = {},
        groupAssignments = {},
        collapsedGroups = {},
        compactMode = false,
        showDescriptions = false,
        descriptionMode = "SHORT",
        rowWidth = 188,
        settingsWindow = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 1020,
            height = 760,
            scale = 1,
            alpha = 1,
            displayState = "expanded",
        },
        widgetConfig = {
            time = { enabled = true, group = "Widgets", favorite = false },
            location = { enabled = true, group = "Widgets", favorite = false },
            coords = { enabled = true, group = "Widgets", favorite = false },
            gold = { enabled = false, group = "Widgets", favorite = false },
            xp = { enabled = false, group = "Widgets", favorite = false },
            reputation = { enabled = false, group = "Widgets", favorite = false },
            housefavor = { enabled = false, group = "Widgets", favorite = false },
            durability = { enabled = false, group = "Widgets", favorite = false },
            performance = { enabled = false, group = "Widgets", favorite = false },
            volume = { enabled = false, group = "Widgets", favorite = false },
        },
    }

    if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
        DataVault:EnsureNamespace("nexus")
        -- Seed on first run, and also replace a stored value that is not a
        -- table -- a corrupt scalar there would break every later db access.
        -- Branching instead of reassigning keeps the local's inferred type
        -- stable, which DataVault:Get alone does not pin down.
        local stored = DataVault:Get("account", "nexus", "db")
        if type(stored) == "table" then
            self.db = stored
        else
            local seeded = {}
            CopyDefaults(seeded, DEFAULTS)
            DataVault:Set("account", "nexus", "db", seeded)
            self.db = seeded
        end
    else
        _G.FabledUI_NexusDB = _G.FabledUI_NexusDB or {}
        self.db = _G.FabledUI_NexusDB
    end

    CopyDefaults(self.db, DEFAULTS)
    self.db.addonConfig = self.db.addonConfig or {}
    self.db.customRegistry = self.db.customRegistry or {}
    self.db.detectedRegistry = self.db.detectedRegistry or {}
    self.db.favorites = self.db.favorites or {}
    self.db.groupAssignments = self.db.groupAssignments or {}
    self.db.collapsedGroups = self.db.collapsedGroups or {}
    self.db.widgetConfig = self.db.widgetConfig or {}
end

function N:MarkDirty()
    if DataVault and DataVault.dirtyFlags then
        DataVault.dirtyFlags["nexus"] = true
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    N:ResolveStorage()
    if N.Settings then
        N.Settings:Register()
    end
    N.Registry:Init()
    if N.UI then
        N.UI:Create()
    end
    if N.Widgets and N.Widgets.StartTicker then
        N.Widgets:StartTicker()
    end
    if N.Integrations then
        N.Integrations:Init()
    end

    SLASH_FABLEDUI_NEXUS1 = "/nexus"
    SlashCmdList["FABLEDUI_NEXUS"] = function(msg)
        local cmd = (msg or ""):lower():match("^%s*(%S+)")
        if cmd == "reset" then
            N.db.anchor, N.db.x, N.db.y = "TOPRIGHT", -100, -100
            if N.UI and N.UI.anchor then
                N.UI.anchor:ClearAllPoints()
                N.UI.anchor:SetPoint(N.db.anchor, UIParent, N.db.anchor, N.db.x, N.db.y)
            end
            N:MarkDirty()
        elseif cmd == "settings" then
            if N.Registry then
                N.Registry:OpenNexusSettings()
            end
        elseif cmd == "scan" then
            if N.Registry then
                local found, added = N.Registry:AutoDetectThirdPartyAddons(true)
                N.Registry:Init()
                if N.UI then
                    N.UI:Refresh()
                end
                N:Print("Scan complete:", found, "candidate(s),", added, "new detection(s). Review them in Nexus settings.")
            end
        else
            if N.UI then
                N.UI:ToggleCollapse()
            end
        end
    end
end)


