local N = FabledUI_Nexus
N.Registry = {}
local R = N.Registry

local NEXUS_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local SETTINGS_ICON = "Interface\\Buttons\\UI-OptionsButton"
local THIRD_PARTY_DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

N.NEXUS_ICON = NEXUS_ICON
N.SETTINGS_ICON = SETTINGS_ICON
N.THIRD_PARTY_DEFAULT_ICON = THIRD_PARTY_DEFAULT_ICON

local NATIVE_MODULES = {
    {
        id = "Nexus",
        label = "Nexus",
        addonCandidates = { "FabledUI_Nexus", "FlayreDev_Nexus" },
        globalCandidates = { "FabledUI_Nexus", "Nexus" },
        icon = NEXUS_ICON,
        desc = "Suite launcher and addon hub.",
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI", "Settings.OpenWindow", "Registry.OpenNexusSettings" },
        settingsFields = { "CategoryID", "categoryID" },
        settingsPath = "Registry.OpenNexusSettings",
    },
    {
        id = "DataVault",
        label = "DataVault",
        addonCandidates = { "FabledUI_DataVault", "FlayreDev_DataVault" },
        globalCandidates = { "FabledUI_DataVault", "DataVault" },
        icon = 133994,
        desc = "Persistence backbone and shared data services.",
        uiPaths = { "ToggleUI", "UI.Toggle", "Toggle", "Open", "ShowUI" },
        settingsFields = { "CategoryID", "categoryID" },
    },
    {
        id = "Villa",
        label = "Villa",
        addonCandidates = { "FabledUI_Villa", "FlayreDev_Villa" },
        globalCandidates = { "FabledUI_Villa", "FlayreDev_Villa", "Villa" },
        icon = 134414,
        desc = "Housing intelligence and donor-consolidation platform.",
        uiPaths = { "ToggleUI", "Toggle", "OpenPanel", "Open", "ShowUI", "Show" },
        settingsFields = { "CategoryID", "categoryID" },
        settingsPath = "OpenSettings",
    },
    {
        id = "Crafty",
        label = "Crafty",
        addonCandidates = { "FabledUI_Crafty", "FlayreDev_Crafty" },
        globalCandidates = { "FabledUI_Crafty", "FlayreDev_Crafty" },
        icon = 134708,
        desc = "Professions, reagents, and crafting queue tools.",
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI" },
        settingsFields = { "CategoryID", "categoryID" },
    },
    {
        id = "Athena",
        label = "Athena",
        addonCandidates = { "FabledUI_Athena", "FlayreDev_Athena" },
        globalCandidates = { "FabledUI_Athena", "FlayreDev_Athena", "Athena" },
        icon = 134063,
        desc = "Addon profile and configuration tools.",
        uiPaths = { "ToggleMain", "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/athena",
        settingsFields = { "CategoryID", "categoryID" },
    },
    {
        id = "Artemis",
        label = "Artemis",
        addonCandidates = { "FabledUI_Artemis", "FlayreDev_Artemis" },
        globalCandidates = { "FabledUI_Artemis", "FlayreDev_Artemis", "Artemis" },
        icon = 236396,
        desc = "Quest and world quest tools.",
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/artemis",
        settingsFields = { "CategoryID", "categoryID" },
        settingsPath = "Settings.Open",
    },
    {
        id = "Odyssey",
        label = "Odyssey",
        addonCandidates = { "FabledUI_Odyssey", "FlayreDev_Odyssey" },
        globalCandidates = { "FabledUI_Odyssey", "FlayreDev_Odyssey", "Odyssey" },
        icon = 237436,
        desc = "Waypoints, routes, and travel tools.",
        uiPaths = { "UI.MainFrame.Toggle", "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/odyssey",
        settingsFields = { "CategoryID", "categoryID" },
        -- Odyssey's options moved onto a Settings tab inside its own window and
        -- it no longer registers a Blizzard options category, so
        -- ResolveCategoryID returns nil and ExecuteSettings falls through to
        -- this path -- same arrangement as Iris below.
        settingsPath = "Settings.Open",
    },
    {
        id = "Kleos",
        label = "Kleos",
        addonCandidates = { "FabledUI_Kleos", "FlayreDev_Kleos" },
        globalCandidates = { "FabledUI_Kleos", "FlayreDev_Kleos", "Kleos" },
        icon = 134089,
        desc = "Achievement and collection tools.",
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/kleos",
        settingsFields = { "CategoryID", "categoryID" },
        settingsPath = "Settings.Open",
    },
    {
        id = "Harvest",
        label = "Harvest",
        addonCandidates = { "FabledUI_Harvest", "FlayreDev_Harvest" },
        globalCandidates = { "FabledUI_Harvest", "FlayreDev_Harvest", "Harvest" },
        icon = 134296,
        desc = "Gathering and node tracking.",
        -- Harvest is a HUD/map-layer addon: it ships a radar and map overlays
        -- but no main window (H.UI has Init, no Toggle). The uiPaths stay for
        -- forward compatibility; until one lands, the launcher honestly
        -- reports no launch method and the cog carries the entry.
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI" },
        settingsSlash = "/harvest settings",
        settingsFields = { "CategoryID", "categoryID" },
    },
    {
        id = "Nemesis",
        label = "Nemesis",
        addonCandidates = { "FabledUI_Nemesis", "FlayreDev_Nemesis" },
        globalCandidates = { "FabledUI_Nemesis", "FlayreDev_Nemesis", "Nemesis" },
        icon = 134133,
        desc = "Rare scanner and nearby entity tools.",
        uiPaths = { "OpenExplorer", "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/nemesis",
        settingsFields = { "CategoryID", "categoryID" },
    },
    {
        id = "Poseidon",
        label = "Poseidon",
        addonCandidates = { "FabledUI_Poseidon", "FlayreDev_Poseidon" },
        globalCandidates = { "FabledUI_Poseidon", "FlayreDev_Poseidon", "Poseidon" },
        icon = 134366,
        desc = "Fishing, pools, and aquatic tracking.",
        uiPaths = { "UI.ToggleHUD", "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/poseidon",
        settingsFields = { "CategoryID", "categoryID" },
    },
    {
        id = "Iris",
        label = "Iris",
        addonCandidates = { "FabledUI_Iris", "FlayreDev_Iris" },
        globalCandidates = { "FabledUI_Iris", "FlayreDev_Iris", "Iris" },
        icon = 132144,
        desc = "Chat utility, copy tools, and history helpers.",
        uiPaths = { "UI.OpenHistory", "UI.Toggle", "Toggle", "Open", "ShowUI" },
        launchSlash = "/iris",
        settingsFields = { "CategoryID", "categoryID" },
        -- Iris registers no Blizzard options category, so ResolveCategoryID
        -- returns nil and ExecuteSettings falls through to this path.
        settingsPath = "Settings.Open",
    },
    {
        id = "UIToolkit",
        label = "Toolkit",
        addonCandidates = { "FabledUI_UIToolkit", "FlayreDev_UIToolkit" },
        globalCandidates = { "FabledUI_UIToolkit", "UIToolkit" },
        icon = 134406, -- generic gear icon; the toolkit doesn't ship its own
        desc = "Shared chrome primitives, themes, toasts, and preview frames used by every other suite addon.",
        -- The toolkit has no user-facing main window — these paths are
        -- forward-compatible if one is added; until then the entry is
        -- mostly informational with a no-op launch.
        uiPaths = { "Toggle", "ShowPreview" },
        -- No settingsFields: the toolkit registers no options panel, and
        -- listing them made the row render a cog that only ever printed
        -- "No settings entry point found". Informational row, no controls.
        informational = true,
    },
}


local EXCLUDED_PREFIXES = {
    "Blizzard_",
    "!BugGrabber",
    "BugSack",
    "Details",
    "MRT",
    "WeakAuras",
    "Ace3",
    "Lib",
    "SharedMedia",
}

local OPTIONAL_EXCLUDED_PREFIXES = {
    "DataStore",
}

local function StartsWith(str, prefix)
    return type(str) == "string" and type(prefix) == "string" and str:sub(1, #prefix) == prefix
end

local function CopyTable(src)
    local dst = {}
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyTable(value)
        else
            dst[key] = value
        end
    end
    return dst
end

local function SanitizeToken(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function NormalizeMatchString(value)
    return SanitizeToken(value):lower():gsub("[%s%p_%-]", "")
end

local function ResolvePath(root, path)
    if type(root) ~= "table" or type(path) ~= "string" or path == "" then
        return nil
    end

    local current = root
    for segment in path:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[segment]
        if current == nil then
            return nil
        end
    end

    return current
end

local function GetGlobalCandidates(addonName)
    local candidates = {}
    if type(addonName) ~= "string" or addonName == "" then
        return candidates
    end

    candidates[#candidates + 1] = addonName
    candidates[#candidates + 1] = addonName:gsub("^FabledUI_", "")
    candidates[#candidates + 1] = addonName:gsub("^FlayreDev_", "")
    candidates[#candidates + 1] = addonName:gsub("[%s%-]", "_")
    candidates[#candidates + 1] = addonName:gsub("[%s_%-]", "")

    local deduped, seen = {}, {}
    for _, entry in ipairs(candidates) do
        entry = SanitizeToken(entry)
        if entry ~= "" and not seen[entry] then
            seen[entry] = true
            deduped[#deduped + 1] = entry
        end
    end
    return deduped
end

local function GetFirstExistingGlobal(candidates)
    for _, name in ipairs(candidates or {}) do
        local value = _G[name]
        if value ~= nil then
            return value, name
        end
    end
    return nil, nil
end

local function ResolveCategoryID(globalObj, fields)
    if type(globalObj) ~= "table" then
        return nil
    end

    for _, fieldName in ipairs(fields or {}) do
        local value = globalObj[fieldName]
        if type(value) == "number" then
            return value
        elseif type(value) == "table" and type(value.GetID) == "function" then
            local ok, result = pcall(value.GetID, value)
            if ok and type(result) == "number" then
                return result
            end
        end
    end

    if type(globalObj.optionsFrame) == "table" then
        if type(globalObj.optionsFrame.GetID) == "function" then
            local ok, result = pcall(globalObj.optionsFrame.GetID, globalObj.optionsFrame)
            if ok and type(result) == "number" then
                return result
            end
        end
        if type(globalObj.optionsFrame.name) == "string" and globalObj.optionsFrame.name ~= "" then
            return globalObj.optionsFrame.name
        end
    end

    return nil
end


local function SortByLabel(a, b)
    return tostring(a.label or a.id or a.key or ""):lower() < tostring(b.label or b.id or b.key or ""):lower()
end

local function GetGroupOrder(name)
    local order = { Favorites = 1, Suite = 2, Widgets = 3, ["3rd-Party"] = 4 }
    return order[name] or 10
end

local function ResolveEntryKey(entry)
    if entry.moduleType == "widget" then
        return entry.id
    elseif entry.isCustom then
        return entry.id
    end
    return "native_" .. tostring(entry.id)
end

local function ResolveLaunchPath(globalObj, uiPaths)
    if type(globalObj) ~= "table" then
        return nil
    end

    for _, path in ipairs(uiPaths or {}) do
        local func = ResolvePath(globalObj, path)
        if type(func) == "function" then
            return path
        end
    end

    return nil
end


local function IsAddonEnabled(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end

    -- GetAddOnEnableState semantics in 12.0+:
    --   0 = disabled for this character
    --   1 = disabled for this character but enabled for others
    --   2 = enabled for this character
    -- The previous "state > 0" check treated state==1 (disabled here, enabled
    -- on other chars) as enabled, so the dashboard would show "ON" for an
    -- addon that wouldn't actually load on the current character.
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, addonName)
        return ok and type(state) == "number" and state == 2
    end

    return true
end

local function GetSlashMap()
    local slashMap = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string" then
            local hash = key:match("^SLASH_(.-)%d+$")
            if hash and value:match("^/") then
                slashMap[value:lower()] = hash
            end
        end
    end
    return slashMap
end

local function ResolveSlashHandler(commandText)
    if type(commandText) ~= "string" or commandText == "" then
        return nil, nil, nil
    end

    local slashMap = GetSlashMap()
    local fullCommand = SanitizeToken(commandText)
    local baseCommand = fullCommand:match("^(%S+)")
    if not baseCommand then
        return nil, nil, nil
    end

    local hash = slashMap[baseCommand:lower()] or baseCommand:upper():gsub("^/", "")
    local handler = hash and SlashCmdList[hash] or nil
    return handler, hash, fullCommand:sub(#baseCommand + 2)
end

function R:OpenNexusSettings()
    if N.Settings and type(N.Settings.OpenWindow) == "function" then
        N.Settings:OpenWindow()
        return true
    end
    return false
end

function R:GetNativeModules()
    return NATIVE_MODULES
end

function R:IsExcludedAddon(addonName, title)
    addonName = addonName or ""
    title = title or ""

    if addonName == "FabledUI_Nexus" then
        return true
    end

    for _, prefix in ipairs(EXCLUDED_PREFIXES) do
        if StartsWith(addonName, prefix) or StartsWith(title, prefix) then
            return true
        end
    end

    if N.db and N.db.scanIgnoreDataStore then
        for _, prefix in ipairs(OPTIONAL_EXCLUDED_PREFIXES) do
            if StartsWith(addonName, prefix) or StartsWith(title, prefix) then
                return true
            end
        end
    end

    if StartsWith(addonName, "FabledUI_") or StartsWith(addonName, "FlayreDev_") then
        return true
    end

    return false
end

local function GetAddonInfoSafe(target)
    if (type(target) ~= "string" and type(target) ~= "number") or target == "" then
        return nil
    end

    local name, title, notes, loadable, reason, security
    if not C_AddOns or type(C_AddOns.GetAddOnInfo) ~= "function" then
        return nil
    end
    local ok
    ok, name, title, notes, loadable, reason, security = pcall(C_AddOns.GetAddOnInfo, target)
    if not ok then
        return nil
    end

    if reason == "MISSING" or type(name) ~= "string" or name == "" then
        return nil
    end
    return name, title, notes, loadable, reason, security
end

local function GetNumAddOnsSafe()
    local api = C_AddOns and C_AddOns.GetNumAddOns
    if type(api) ~= "function" then
        return 0
    end
    local ok, total = pcall(api)
    return ok and total or 0
end

function R:ResolveInstalledAddon(module)
    for _, addonName in ipairs(module.addonCandidates or {}) do
        if GetAddonInfoSafe(addonName) then
            return addonName
        end
    end
    return nil
end

local function StripColorCodes(value)
    value = tostring(value or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return value
end

local function GetAddonMetadataValue(addonName, fieldName)
    if type(addonName) ~= "string" or addonName == "" then
        return nil
    end
    if type(fieldName) ~= "string" or fieldName == "" then
        return nil
    end

    local value
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        value = C_AddOns.GetAddOnMetadata(addonName, fieldName)
    end

    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function NormalizeAddonTitle(title)
    title = StripColorCodes(title)
    title = SanitizeToken(title)
    if title == "" then
        return nil
    end

    title = title:gsub("^FabledUI%s*%-%s*", "")
    title = title:gsub("^FlayreDev%s*%-%s*", "")
    title = title:gsub("^FabledUI%s+", "")
    title = title:gsub("^FlayreDev%s+", "")
    title = title:gsub("%s+$", "")
    return title ~= "" and title or nil
end

local function GetAddonTitle(addonName)
    local title = GetAddonMetadataValue(addonName, "X-Nexus-ShortName") or GetAddonMetadataValue(addonName, "Title")
    if title then
        return title
    end

    local name, infoTitle = GetAddonInfoSafe(addonName)
    if type(infoTitle) == "string" and infoTitle ~= "" then
        return infoTitle
    end
    if type(name) == "string" and name ~= "" then
        return name
    end

    return addonName
end

function R:GetResolvedModuleLabel(module, addonName)
    addonName = addonName or self:ResolveInstalledAddon(module)

    if addonName then
        local title = NormalizeAddonTitle(GetAddonTitle(addonName))
        if title and title ~= "" then
            return title
        end

        local folderFallback = NormalizeAddonTitle(addonName:gsub("^FabledUI_", ""):gsub("^FlayreDev_", ""))
        if folderFallback and folderFallback ~= "" then
            return folderFallback
        end
    end

    return module.label or module.id or addonName or "Addon"
end

function R:DescribeLaunchMethod(mod)
    if mod.launchSlash then
        return "Slash"
    elseif mod.launchFrameName then
        return "Frame"
    elseif mod.launchPath then
        return "API"
    end
    return "None"
end

function R:DescribeSettingsMethod(mod)
    if mod.settingsCategoryID then
        return "Settings"
    elseif mod.settingsPath then
        return "API"
    elseif mod.settingsSlash then
        return "Slash"
    end
    return "None"
end

function R:ResolveModuleCapabilities(mod)
    local resolved = CopyTable(mod)
    resolved.icon = resolved.icon or THIRD_PARTY_DEFAULT_ICON
    resolved.label = resolved.label or resolved.id or resolved.addon
    resolved.hasUI = false
    resolved.hasSettings = false
    if resolved.moduleType == "widget" then
        resolved.installed = true
        resolved.installationState = "installed"
        resolved.launchMethod = "Widget"
        resolved.settingsMethod = "Nexus"
        resolved.showSettingsButton = false
        return resolved
    end
    resolved.installationState = resolved.installed and "installed" or "missing"

    if not resolved.installed then
        resolved.launchMethod = "Missing"
        resolved.settingsMethod = "Missing"
        return resolved
    end

    local globalObj, globalName = GetFirstExistingGlobal(resolved.globalCandidates or GetGlobalCandidates(resolved.addon))
    resolved.globalObj = globalObj
    resolved.globalName = globalName

    if not resolved.launchPath then
        resolved.launchPath = ResolveLaunchPath(globalObj, resolved.uiPaths)
    end

    if not resolved.settingsCategoryID then
        local categoryValue = ResolveCategoryID(globalObj, resolved.settingsFields)
        if type(categoryValue) == "number" or type(categoryValue) == "string" then
            resolved.settingsCategoryID = categoryValue
        end
    end

    if not resolved.launchFrameName then
        local frameCandidates = resolved.frameCandidates or {}
        if #frameCandidates == 0 then
            frameCandidates = {
                resolved.addon and (resolved.addon .. "Frame") or nil,
                resolved.label and (resolved.label .. "Frame") or nil,
                globalName and (globalName .. "Frame") or nil,
            }
        end
        for _, frameName in ipairs(frameCandidates) do
            if type(frameName) == "string" and type(_G[frameName]) == "table" then
                resolved.launchFrameName = frameName
                break
            end
        end
    end

    resolved.hasUI = resolved.launchPath ~= nil or resolved.launchSlash ~= nil or resolved.launchFrameName ~= nil
    resolved.hasSettings = resolved.settingsCategoryID ~= nil or resolved.settingsPath ~= nil or resolved.settingsSlash ~= nil
    resolved.launchMethod = self:DescribeLaunchMethod(resolved)
    resolved.settingsMethod = self:DescribeSettingsMethod(resolved)
    return resolved
end

function R:IsFavorite(entryKey)
    return N.db.favorites and N.db.favorites[entryKey] == true or false
end

function R:ToggleFavorite(entryKey)
    if type(entryKey) ~= "string" or entryKey == "" then
        return false
    end
    N.db.favorites[entryKey] = not N.db.favorites[entryKey] or nil
    N:MarkDirty()
    self:Init()
    return true
end

function R:GetAssignedGroup(entryKey, fallback)
    local groupName = N.db.groupAssignments and N.db.groupAssignments[entryKey]
    if type(groupName) == "string" and groupName ~= "" then
        return groupName
    end
    return fallback
end

function R:SetAssignedGroup(entryKey, groupName)
    if type(entryKey) ~= "string" or entryKey == "" then
        return false
    end
    groupName = SanitizeToken(groupName)
    if groupName == "" then
        N.db.groupAssignments[entryKey] = nil
    else
        N.db.groupAssignments[entryKey] = groupName
    end
    N:MarkDirty()
    self:Init()
    return true
end

function R:IsGroupCollapsed(groupName)
    return N.db.collapsedGroups and N.db.collapsedGroups[groupName] == true or false
end

function R:ToggleGroupCollapsed(groupName)
    if type(groupName) ~= "string" or groupName == "" then
        return false
    end
    N.db.collapsedGroups[groupName] = not N.db.collapsedGroups[groupName] or nil
    N:MarkDirty()
    return true
end

-- Suite naming convention:
--   FabledUI_<Parent>            = top-level / user-facing addon (e.g. Crafty,
--                                  Artemis, DataVault, Iris, Kleos, Nemesis,
--                                  Odyssey, Poseidon, Villa, Harvest, Athena,
--                                  UIToolkit).
--   FabledUI_<Parent>_<Suffix>   = child / sub-module (e.g. Crafty_Advisor,
--                                  Crafty_Allocator, Crafty_Data_Alchemy,
--                                  DataVault_Crafty, Artemis_Checklist,
--                                  Toolkit_AssetBrowser, Nemesis_Data).
--                                  Managed through the parent's settings;
--                                  should NOT appear on the Nexus dashboard.
--
-- Rule: strip the "FabledUI_" prefix; if any underscore remains in the rest,
-- the addon is a child sub-module and we hide it. Catches every current
-- sub-addon naming pattern in the suite without an exception list.
local function IsSubAddon(addonName)
    if type(addonName) ~= "string" or addonName == "" then return false end
    local rest = addonName:match("^FabledUI_(.+)$") or addonName:match("^FlayreDev_(.+)$")
    if not rest then return false end
    return rest:find("_") ~= nil
end

local function EnumerateInstalledSuiteAddons()
    local results = {}
    local total = GetNumAddOnsSafe()

    for index = 1, total do
        local addonName = GetAddonInfoSafe(index)
        if type(addonName) == "string" and addonName ~= "" then
            if StartsWith(addonName, "FabledUI_") or StartsWith(addonName, "FlayreDev_") then
                if addonName ~= "FabledUI_Nexus" and not IsSubAddon(addonName) then
                    results[#results + 1] = addonName
                end
            end
        end
    end

    table.sort(results)
    return results
end

local function BuildDynamicSuiteModule(addonName)
    local suffix = addonName:gsub("^FabledUI_", ""):gsub("^FlayreDev_", "")
    return {
        id = addonName,
        label = suffix,
        addonCandidates = { addonName },
        globalCandidates = { addonName, suffix },
        icon = GetAddonMetadataValue(addonName, "IconTexture") or GetAddonMetadataValue(addonName, "X-Nexus-Icon") or THIRD_PARTY_DEFAULT_ICON,
        desc = GetAddonMetadataValue(addonName, "Notes") or "Suite addon",
        uiPaths = { "UI.Toggle", "ToggleUI", "Toggle", "OpenPanel", "Open", "ShowUI", "Show" },
        settingsFields = { "CategoryID", "categoryID" },
        settingsPath = "OpenSettings",
    }
end

function R:GetSuiteModules()
    local list, seen = {}, {}
    for _, mod in ipairs(NATIVE_MODULES) do
        seen[mod.id] = true
        for _, addonName in ipairs(mod.addonCandidates or {}) do
            seen[addonName] = true
        end
        list[#list + 1] = mod
    end

    for _, addonName in ipairs(EnumerateInstalledSuiteAddons()) do
        if not seen[addonName] then
            list[#list + 1] = BuildDynamicSuiteModule(addonName)
        end
    end

    table.sort(list, function(a, b)
        local aInstalled = self:ResolveInstalledAddon(a) or a.addonCandidates and a.addonCandidates[1] or a.id
        local bInstalled = self:ResolveInstalledAddon(b) or b.addonCandidates and b.addonCandidates[1] or b.id
        local aLabel = self:GetResolvedModuleLabel(a, aInstalled)
        local bLabel = self:GetResolvedModuleLabel(b, bInstalled)
        return tostring(aLabel):lower() < tostring(bLabel):lower()
    end)

    return list
end

function R:BuildActiveModule(entry)
    local resolved = self:ResolveModuleCapabilities(entry)
    local entryKey = ResolveEntryKey(resolved)
    local defaultGroup = resolved.moduleType == "widget" and "Widgets" or (resolved.isCustom and "3rd-Party" or "Suite")
    local assignedGroup = self:GetAssignedGroup(entryKey, defaultGroup)
    local isFavorite = self:IsFavorite(entryKey) or resolved.isFavorite == true
    return {
        id = resolved.id,
        key = entryKey,
        group = isFavorite and "Favorites" or assignedGroup,
        baseGroup = assignedGroup,
        isFavorite = isFavorite,
        moduleType = resolved.moduleType or (resolved.isCustom and "custom" or "native"),
        label = resolved.label,
        addon = resolved.addon,
        icon = resolved.icon,
        desc = resolved.desc,
        isCustom = resolved.isCustom,
        installed = resolved.installed,
        installationState = resolved.installationState,
        informational = resolved.informational,
        hasUI = resolved.hasUI,
        hasSettings = resolved.hasSettings,
        showSettingsButton = resolved.installed and (resolved.hasSettings or (type(resolved.settingsFields) == "table" and #resolved.settingsFields > 0) or resolved.settingsPath ~= nil or resolved.settingsSlash ~= nil),
        launchPath = resolved.launchPath,
        launchSlash = resolved.launchSlash,
        launchFrameName = resolved.launchFrameName,
        settingsCategoryID = resolved.settingsCategoryID,
        settingsPath = resolved.settingsPath,
        settingsSlash = resolved.settingsSlash,
        launchMethod = resolved.launchMethod,
        settingsMethod = resolved.settingsMethod,
        globalName = resolved.globalName,
        globalCandidates = resolved.globalCandidates,
        uiPaths = resolved.uiPaths,
        settingsFields = resolved.settingsFields,
        settingsLabel = resolved.settingsLabel,
    }
end

function R:Init()
    self.ActiveList = {}

    local nativeSeen = {}
    for _, mod in ipairs(NATIVE_MODULES) do
        local addonName = self:ResolveInstalledAddon(mod)
        mod.addon = addonName or mod.addonCandidates[1]
        mod.installed = addonName ~= nil
        nativeSeen[mod.id] = true
        for _, candidate in ipairs(mod.addonCandidates or {}) do
            nativeSeen[candidate] = true
        end

        if N.db.addonConfig[mod.id] == nil then
            N.db.addonConfig[mod.id] = { visible = true, customIcon = nil, customLabel = nil }
        end

        local visible = N.db.addonConfig[mod.id].visible ~= false
        if visible then
            local entry = CopyTable(mod)
            entry.label = N.db.addonConfig[mod.id].customLabel or self:GetResolvedModuleLabel(mod, addonName)
            entry.icon = N.db.addonConfig[mod.id].customIcon or mod.icon
            entry.globalCandidates = CopyTable(mod.globalCandidates or {})
            entry.isCustom = false
            entry.moduleType = "native"
            self.ActiveList[#self.ActiveList + 1] = self:BuildActiveModule(entry)
        end
    end

    for _, addonName in ipairs(EnumerateInstalledSuiteAddons()) do
        if not nativeSeen[addonName] then
            local mod = BuildDynamicSuiteModule(addonName)
            mod.addon = addonName
            mod.installed = true
            if N.db.addonConfig[mod.id] == nil then
                N.db.addonConfig[mod.id] = { visible = true, customIcon = nil, customLabel = nil }
            end
            local visible = N.db.addonConfig[mod.id].visible ~= false
            if visible then
                local entry = CopyTable(mod)
                entry.label = N.db.addonConfig[mod.id].customLabel or self:GetResolvedModuleLabel(mod, addonName)
                entry.icon = N.db.addonConfig[mod.id].customIcon or mod.icon
                entry.globalCandidates = CopyTable(mod.globalCandidates or {})
                entry.isCustom = false
                entry.moduleType = "native"
                self.ActiveList[#self.ActiveList + 1] = self:BuildActiveModule(entry)
            end
        end
    end

    if N.Widgets and N.Widgets.GetActiveEntries then
        for _, widget in ipairs(N.Widgets:GetActiveEntries()) do
            self.ActiveList[#self.ActiveList + 1] = self:BuildActiveModule(widget)
        end
    end

    for id, data in pairs(N.db.customRegistry) do
        if data.visible ~= false then
            local entry = {
                id = id,
                label = data.label or data.addonName or id,
                addon = data.addonName,
                icon = data.icon or THIRD_PARTY_DEFAULT_ICON,
                desc = data.desc or "3rd-party addon",
                isCustom = true,
                moduleType = "custom",
                installed = data.addonName and GetAddonInfoSafe(data.addonName) ~= nil,
                globalCandidates = data.globalCandidates or GetGlobalCandidates(data.addonName),
                uiPaths = data.uiPaths or { "UI.Toggle", "Toggle", "Open", "ShowUI", "Show" },
                settingsFields = data.settingsFields or { "CategoryID", "categoryID" },
                launchPath = data.launchPath,
                launchSlash = data.launchSlash or data.slash,
                launchFrameName = data.launchFrameName,
                settingsCategoryID = data.settingsCategoryID,
                settingsPath = data.settingsPath,
                settingsSlash = data.settingsSlash,
            }
            self.ActiveList[#self.ActiveList + 1] = self:BuildActiveModule(entry)
        end
    end

    table.sort(self.ActiveList, function(a, b)
        local aGroup = tostring(a.group or "")
        local bGroup = tostring(b.group or "")
        if aGroup ~= bGroup then
            local ao, bo = GetGroupOrder(aGroup), GetGroupOrder(bGroup)
            if ao ~= bo then
                return ao < bo
            end
            return aGroup:lower() < bGroup:lower()
        end
        return SortByLabel(a, b)
    end)
end

function R:CallPath(globalObj, path)
    local func = ResolvePath(globalObj, path)
    if type(func) ~= "function" then
        return false
    end

    local owner = globalObj
    local lastDot = path:match("^(.*)%.([^.]+)$")
    if lastDot then
        owner = ResolvePath(globalObj, lastDot) or globalObj
    end

    local ok, err = pcall(func, owner)
    if not ok then
        N:Print("Launcher path failed:", tostring(err))
        return false
    end

    return true
end

function R:CallSlash(commandText)
    local handler, _, args = ResolveSlashHandler(commandText)
    if type(handler) ~= "function" then
        return false
    end

    local ok, err = pcall(handler, args)
    if not ok then
        N:Print("Slash handler failed:", tostring(err))
        return false
    end

    return true
end

function R:ToggleFrame(frameName)
    local frame = type(frameName) == "string" and _G[frameName] or nil
    if type(frame) ~= "table" then
        return false
    end

    if type(frame.IsShown) == "function" and frame:IsShown() then
        if type(frame.Hide) == "function" then
            frame:Hide()
            return true
        end
    elseif type(frame.Show) == "function" then
        frame:Show()
        return true
    end

    return false
end

function R:EnsureLoaded(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end

    if not C_AddOns or type(C_AddOns.IsAddOnLoaded) ~= "function" or type(C_AddOns.LoadAddOn) ~= "function" then
        return false
    end

    local okLoaded, isLoaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
    if okLoaded and isLoaded then
        return true
    end

    local okLoad, loadResult, reason = pcall(C_AddOns.LoadAddOn, addonName)
    if not okLoad then
        N:Print("Failed to load", addonName .. ":", tostring(loadResult))
        return false
    end
    if not loadResult then
        N:Print("Failed to load", addonName .. ":", tostring(reason))
        return false
    end

    return true
end

function R:ExecuteToggle(mod)
    if not self:EnsureLoaded(mod.addon) then
        return
    end

    local refreshed = self:ResolveModuleCapabilities(mod)
    local globalObj = refreshed.globalObj

    if refreshed.launchPath and self:CallPath(globalObj, refreshed.launchPath) then
        return
    end

    if refreshed.launchSlash and self:CallSlash(refreshed.launchSlash) then
        return
    end

    if refreshed.launchFrameName and self:ToggleFrame(refreshed.launchFrameName) then
        return
    end

    N:Print("Module loaded, but Nexus could not find a usable UI launcher for", refreshed.label .. ".")
end

function R:ExecuteSettings(mod)
    if not self:EnsureLoaded(mod.addon) then
        return
    end

    local refreshed = self:ResolveModuleCapabilities(mod)
    local globalObj = refreshed.globalObj

    if refreshed.settingsCategoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(refreshed.settingsCategoryID)
        return
    end

    if refreshed.settingsPath and self:CallPath(globalObj, refreshed.settingsPath) then
        return
    end

    if refreshed.settingsSlash and self:CallSlash(refreshed.settingsSlash) then
        return
    end

    N:Print("No settings entry point found for", refreshed.label .. ".")
end

function R:AutoDetectEntryExists(addonName)
    local key = type(addonName) == "string" and ("auto_" .. addonName) or nil
    return key and N.db.detectedRegistry and N.db.detectedRegistry[key] ~= nil or false
end

function R:GetDetectedCandidates()
    local list = {}
    for key, data in pairs(N.db.detectedRegistry or {}) do
        if type(data) == "table" then
            local entry = CopyTable(data)
            entry.key = key
            entry.inHub = N.db.customRegistry[key] ~= nil
            list[#list + 1] = entry
        end
    end

    table.sort(list, function(a, b)
        local aLabel = tostring(a.label or a.addonName or a.key or "")
        local bLabel = tostring(b.label or b.addonName or b.key or "")
        return aLabel:lower() < bLabel:lower()
    end)

    return list
end

function R:GuessSlashForAddon(addonName, title)
    local slashMap = GetSlashMap()
    local targets = {
        NormalizeMatchString(addonName),
        NormalizeMatchString(title),
        NormalizeMatchString(type(addonName) == "string" and addonName:gsub("^FabledUI_", "") or nil),
        NormalizeMatchString(type(addonName) == "string" and addonName:gsub("^FlayreDev_", "") or nil),
    }

    local filteredTargets = {}
    for _, target in ipairs(targets) do
        if type(target) == "string" and target ~= "" then
            filteredTargets[#filteredTargets + 1] = target
        end
    end

    for slash, _ in pairs(slashMap) do
        if type(slash) == "string" and slash ~= "" then
            local normSlash = NormalizeMatchString(slash)
            if normSlash ~= "" then
                for _, target in ipairs(filteredTargets) do
                    if normSlash:find(target, 1, true) or target:find(normSlash, 1, true) then
                        return slash
                    end
                end
            end
        end
    end

    return nil
end

function R:DetectThirdPartyAddon(addonName)
    local name, title = GetAddonInfoSafe(addonName)
    if not name then
        return nil
    end
    if self:IsExcludedAddon(addonName, title) then
        return nil
    end

    if N.db.autoDetectIncludeLoadedOnly then
        local loaded = false
        if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
            local okLoaded, isLoaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
            loaded = okLoaded and isLoaded or false
        end
        if not loaded then
            return nil
        end
    end

    if N.db.autoDetectEnabledOnly and not IsAddonEnabled(addonName) then
        return nil
    end

    local globalCandidates = GetGlobalCandidates(addonName)
    local globalObj, globalName = GetFirstExistingGlobal(globalCandidates)
    local launchPath = ResolveLaunchPath(globalObj, { "UI.Toggle", "Toggle", "Open", "ShowUI", "Show" })
    local settingsCategoryID = ResolveCategoryID(globalObj, { "CategoryID", "categoryID" })
    local launchFrameName

    for _, frameName in ipairs({ addonName .. "Frame", title and (title:gsub("[%s%-]", "") .. "Frame") or nil, globalName and (globalName .. "Frame") or nil }) do
        if type(frameName) == "string" and type(_G[frameName]) == "table" then
            launchFrameName = frameName
            break
        end
    end

    local launchSlash = self:GuessSlashForAddon(addonName, title)
    if not launchPath and not launchSlash and not launchFrameName and not settingsCategoryID then
        return nil
    end

    return {
        addonName = addonName,
        label = title or addonName,
        desc = "Detected 3rd-party addon candidate",
        icon = THIRD_PARTY_DEFAULT_ICON,
        autoDetected = true,
        visible = false,
        globalCandidates = globalCandidates,
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI", "Show" },
        settingsFields = { "CategoryID", "categoryID" },
        launchPath = launchPath,
        launchSlash = launchSlash,
        launchFrameName = launchFrameName,
        settingsCategoryID = settingsCategoryID,
    }
end

function R:AutoDetectThirdPartyAddons(verbose)
    local found = 0
    local added = 0
    local total = GetNumAddOnsSafe()
    for index = 1, total do
        local addonName = GetAddonInfoSafe(index)
        if type(addonName) == "string" and addonName ~= "" then
            local detected = self:DetectThirdPartyAddon(addonName)
            if detected then
                found = found + 1
                local key = "auto_" .. addonName
                if not N.db.detectedRegistry[key] then
                    N.db.detectedRegistry[key] = detected
                    added = added + 1
                else
                    local existing = N.db.detectedRegistry[key]
                    detected.visible = existing.visible or false
                    N.db.detectedRegistry[key] = detected
                end
            end
        end
    end

    if added > 0 then
        N:MarkDirty()
    end

    if verbose and found == 0 then
        N:Print("Auto-detect found no compatible 3rd-party addons.")
    end

    return found, added
end

function R:RemoveCustomAddon(key)
    if type(key) ~= "string" or key == "" then
        return false
    end

    if N.db.customRegistry[key] == nil then
        return false
    end

    N.db.customRegistry[key] = nil
    N:MarkDirty()
    self:Init()
    return true
end

function R:SetCustomEntryIcon(key, iconValue)
    if type(key) ~= "string" or key == "" then
        return false
    end
    local entry = N.db.customRegistry[key]
    if type(entry) ~= "table" then
        return false
    end
    if iconValue == "" or iconValue == nil then
        entry.icon = nil
    else
        entry.icon = tonumber(iconValue) or iconValue
    end
    N:MarkDirty()
    self:Init()
    return true
end

function R:SetNativeLabel(moduleID, labelValue)
    if type(moduleID) ~= "string" or moduleID == "" then
        return false
    end
    N.db.addonConfig[moduleID] = N.db.addonConfig[moduleID] or { visible = true }
    labelValue = SanitizeToken(labelValue)
    N.db.addonConfig[moduleID].customLabel = labelValue ~= "" and labelValue or nil
    N:MarkDirty()
    self:Init()
    return true
end

function R:SetCustomEntryLabel(key, labelValue)
    if type(key) ~= "string" or key == "" then
        return false
    end
    local entry = N.db.customRegistry[key]
    if type(entry) ~= "table" then
        return false
    end
    labelValue = SanitizeToken(labelValue)
    entry.label = labelValue ~= "" and labelValue or (entry.addonName or key)
    N:MarkDirty()
    self:Init()
    return true
end

function R:SetNativeIcon(moduleID, iconValue)
    if type(moduleID) ~= "string" or moduleID == "" then
        return false
    end
    N.db.addonConfig[moduleID] = N.db.addonConfig[moduleID] or { visible = true }
    if iconValue == "" or iconValue == nil then
        N.db.addonConfig[moduleID].customIcon = nil
    else
        N.db.addonConfig[moduleID].customIcon = tonumber(iconValue) or iconValue
    end
    N:MarkDirty()
    self:Init()
    return true
end

function R:SetDetectedAddonEnabled(key, enabled)
    if type(key) ~= "string" or key == "" then
        return false
    end

    local detected = N.db.detectedRegistry[key]
    if type(detected) ~= "table" then
        return false
    end

    if enabled then
        N.db.customRegistry[key] = {
            addonName = detected.addonName,
            label = detected.label or detected.addonName or key,
            desc = detected.desc or "Detected 3rd-party addon candidate",
            icon = detected.icon or THIRD_PARTY_DEFAULT_ICON,
            autoDetected = true,
            visible = true,
            globalCandidates = CopyTable(detected.globalCandidates or GetGlobalCandidates(detected.addonName)),
            uiPaths = CopyTable(detected.uiPaths or { "UI.Toggle", "Toggle", "Open", "ShowUI", "Show" }),
            settingsFields = CopyTable(detected.settingsFields or { "CategoryID", "categoryID" }),
            launchPath = detected.launchPath,
            launchSlash = detected.launchSlash,
            launchFrameName = detected.launchFrameName,
            settingsCategoryID = detected.settingsCategoryID,
            settingsPath = detected.settingsPath,
            settingsSlash = detected.settingsSlash,
        }
    else
        local existing = N.db.customRegistry[key]
        if existing and existing.autoDetected then
            N.db.customRegistry[key] = nil
        end
    end

    N:MarkDirty()
    return true
end

function R:RegisterCustomAddon(addonName, slash, label)
    addonName = SanitizeToken(addonName)
    slash = SanitizeToken(slash)
    label = SanitizeToken(label)

    if addonName == "" then
        return false, "Missing addon name."
    end

    local key = "manual_" .. addonName
    N.db.customRegistry[key] = {
        addonName = addonName,
        label = label ~= "" and label or addonName,
        desc = "Manually registered 3rd-party addon",
        icon = THIRD_PARTY_DEFAULT_ICON,
        autoDetected = false,
        visible = true,
        globalCandidates = GetGlobalCandidates(addonName),
        uiPaths = { "UI.Toggle", "Toggle", "Open", "ShowUI", "Show" },
        settingsFields = { "CategoryID", "categoryID" },
        launchSlash = slash ~= "" and slash or nil,
    }

    N:MarkDirty()
    return true, nil
end
