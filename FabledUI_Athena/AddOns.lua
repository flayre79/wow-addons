local A = Athena

local CAdd = rawget(_G, "C_AddOns")

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function CurrentCharacter()
    return A.GetCharacterID()
end

local function NumAddons()
    local api = CAdd and CAdd.GetNumAddOns
    if type(api) ~= "function" then
        return 0
    end
    local ok, count = pcall(api)
    return ok and tonumber(count) or 0
end

local function AddonInfo(target)
    local api = CAdd and CAdd.GetAddOnInfo
    if type(api) ~= "function" then
        return nil
    end

    local result = Pack(pcall(api, target))
    if not result[1] then
        return nil
    end

    local name, title, notes = result[2], result[3], result[4]
    local loadable, reason, security = result[5], result[6], result[7]
    if type(name) ~= "string" or name == "" or reason == "MISSING" then
        return nil
    end
    return name, title, notes, loadable, reason, security
end

local function Dependencies(name)
    local api = CAdd and CAdd.GetAddOnDependencies
    if type(api) ~= "function" then
        return {}
    end

    local result = Pack(pcall(api, name))
    if not result[1] then
        return {}
    end

    local dependencies = {}
    for index = 2, result.n do
        local dependency = result[index]
        if type(dependency) == "string" and dependency ~= "" then
            dependencies[#dependencies + 1] = dependency
        end
    end
    return dependencies
end

local function EnableState(name, character)
    character = character or CurrentCharacter()
    if CAdd and type(CAdd.GetAddOnEnableState) == "function" then
        local ok, state = pcall(CAdd.GetAddOnEnableState, name, character)
        if ok then
            return tonumber(state) or 0
        end
    end
    return 0
end

local function IsEnabled(name, character)
    return EnableState(name, character) > 0
end

local function Enable(name, character)
    character = character or CurrentCharacter()
    if CAdd and type(CAdd.EnableAddOn) == "function" then
        local ok, err = pcall(CAdd.EnableAddOn, name, character)
        return ok, ok and nil or err
    end
    return false, "C_AddOns.EnableAddOn is unavailable"
end

local function Disable(name, character)
    character = character or CurrentCharacter()
    if CAdd and type(CAdd.DisableAddOn) == "function" then
        local ok, err = pcall(CAdd.DisableAddOn, name, character)
        return ok, ok and nil or err
    end
    return false, "C_AddOns.DisableAddOn is unavailable"
end

local function Save()
    local api = CAdd and CAdd.SaveAddOns
    if type(api) ~= "function" then
        return false, "C_AddOns.SaveAddOns is unavailable"
    end
    local ok, err = pcall(api)
    return ok, ok and nil or err
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function ListAddOns()
    local addons = {}
    for index = 1, NumAddons() do
        local name, title, notes, loadable, reason, security = AddonInfo(index)
        if name then
            addons[#addons + 1] = {
                index = index,
                name = name,
                title = title,
                notes = notes,
                loadable = loadable,
                reason = reason,
                security = security,
            }
        end
    end
    return addons
end

A._AddonAPI = {
    CurrentCharacter = CurrentCharacter,
    NumAddons = NumAddons,
    AddonInfo = AddonInfo,
    GetDependencies = Dependencies,
    IsEnabled = IsEnabled,
    Enable = Enable,
    Disable = Disable,
    Save = Save,
    ListAddOns = ListAddOns,
    InCombat = InCombat,
}

local function IsSecureAddon(addon)
    return addon and addon.security == "SECURE"
end

function A:IsProtectedAddOn(addonName, addon)
    if type(addonName) ~= "string" or addonName == "" then
        return true, "invalid addon"
    end
    if IsSecureAddon(addon) then
        return true, "Blizzard secure addon"
    end
    if addonName == self.ADDON_NAME or addonName == "FabledUI_Athena" or addonName == "FlayreDev_Athena" then
        return true, "Athena manages the profile"
    end
    if self.Storage and self.Storage:IsDataVaultBackend()
        and (addonName == "FabledUI_DataVault" or addonName == "FlayreDev_DataVault") then
        return true, "DataVault stores the profile"
    end
    return false, nil
end

function A.IterateAddOns()
    local addons = A._AddonAPI.ListAddOns()
    local index = 0
    return function()
        index = index + 1
        local addon = addons[index]
        if not addon then
            return nil
        end
        return addon.index, addon.name, addon.title, addon.notes, addon.loadable, addon.reason, addon.security
    end
end

function A.GetAddOnEnabledMap()
    local enabledAddons = {}
    local character = A._AddonAPI.CurrentCharacter()
    for _, addon in ipairs(A._AddonAPI.ListAddOns()) do
        if not IsSecureAddon(addon) then
            enabledAddons[addon.name] = A._AddonAPI.IsEnabled(addon.name, character) == true
        end
    end
    return enabledAddons
end

local function SortedNames(set)
    local names = {}
    for name, included in pairs(set or {}) do
        if included then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

function A:ApplyAddOnEnabledSet(requested)
    local desired = {}
    for addonName, enabled in pairs(type(requested) == "table" and requested or {}) do
        if type(addonName) == "string" and addonName ~= "" and type(enabled) == "boolean" then
            desired[addonName] = enabled
        end
    end

    local api = self._AddonAPI
    local installed, addons = {}, api.ListAddOns()
    for _, addon in ipairs(addons) do
        if type(addon.name) == "string" and addon.name ~= "" then
            installed[addon.name] = addon
        end
    end

    local summary = {
        changed = 0,
        enabled = {},
        disabled = {},
        failed = {},
        missing = {},
        protected = {},
        dependencyOverrides = {},
        missingDependencies = {},
        rollbackFailed = {},
        character = api.CurrentCharacter(),
        blocked = false,
        saveFailed = false,
        rolledBack = false,
    }

    local function AddFailure(name, action, err)
        summary.failed[#summary.failed + 1] = {
            name = name,
            action = action,
            error = tostring(err or "unknown error"),
        }
    end

    if api.InCombat and api.InCombat() then
        summary.blocked = true
        AddFailure("C_AddOns", "preflight", "addon changes are unavailable during combat")
        return false, summary
    end

    for _, addon in ipairs(addons) do
        local protected, reason = self:IsProtectedAddOn(addon.name, addon)
        if protected then
            if IsSecureAddon(addon) then
                if desired[addon.name] ~= nil then
                    summary.protected[#summary.protected + 1] = { name = addon.name, reason = reason }
                end
            else
                if desired[addon.name] ~= true then
                    summary.protected[#summary.protected + 1] = { name = addon.name, reason = reason }
                end
                desired[addon.name] = true
            end
        end
    end

    local missingSet, missingDependencySet = {}, {}
    local function AddMissing(addonName)
        if not missingSet[addonName] then
            missingSet[addonName] = true
            summary.missing[#summary.missing + 1] = addonName
        end
    end
    local function AddMissingDependency(addonName)
        AddMissing(addonName)
        if not missingDependencySet[addonName] then
            missingDependencySet[addonName] = true
            summary.missingDependencies[#summary.missingDependencies + 1] = addonName
        end
    end

    for addonName in pairs(desired) do
        if not installed[addonName] then
            AddMissing(addonName)
        end
    end

    local resolving, resolved, dependencyOrder = {}, {}, {}
    local function IncludeDependencies(addonName)
        if resolved[addonName] or resolving[addonName] then
            return
        end
        resolving[addonName] = true

        local dependencies = api.GetDependencies(addonName)
        if type(dependencies) ~= "table" then
            dependencies = {}
        end
        table.sort(dependencies)
        for _, dependency in ipairs(dependencies) do
            if type(dependency) == "string" and dependency ~= "" then
                local dependencyAddon = installed[dependency]
                if not dependencyAddon then
                    AddMissingDependency(dependency)
                elseif not IsSecureAddon(dependencyAddon) then
                    if desired[dependency] ~= true then
                        desired[dependency] = true
                        summary.dependencyOverrides[#summary.dependencyOverrides + 1] = dependency
                    end
                    IncludeDependencies(dependency)
                end
            end
        end

        resolving[addonName] = nil
        resolved[addonName] = true
        dependencyOrder[#dependencyOrder + 1] = addonName
    end

    for _, addonName in ipairs(SortedNames(desired)) do
        local addon = installed[addonName]
        if addon and not IsSecureAddon(addon) then
            IncludeDependencies(addonName)
        end
    end

    table.sort(summary.missing)
    table.sort(summary.missingDependencies)
    table.sort(summary.dependencyOverrides)
    if #summary.missingDependencies > 0 then
        summary.blocked = true
        for _, dependency in ipairs(summary.missingDependencies) do
            AddFailure(dependency, "preflight", "required dependency is not installed")
        end
        return false, summary
    end

    local enableQueue, disableQueue = {}, {}
    for _, addonName in ipairs(dependencyOrder) do
        local addon = installed[addonName]
        if addon and desired[addonName] == true
            and not IsSecureAddon(addon)
            and api.IsEnabled(addonName, summary.character) ~= true then
            enableQueue[#enableQueue + 1] = addonName
        end
    end
    for _, addon in ipairs(addons) do
        if not IsSecureAddon(addon) and desired[addon.name] == false
            and api.IsEnabled(addon.name, summary.character) == true then
            disableQueue[#disableQueue + 1] = addon.name
        end
    end
    table.sort(disableQueue)

    local applied = {}
    local function ApplyOne(addonName, enabled)
        local before = api.IsEnabled(addonName, summary.character) == true
        local ok, err
        if enabled then
            ok, err = api.Enable(addonName, summary.character)
        else
            ok, err = api.Disable(addonName, summary.character)
        end

        local after = api.IsEnabled(addonName, summary.character) == true
        if after ~= before then
            applied[#applied + 1] = { name = addonName, previous = before }
        end
        if not ok or after ~= enabled then
            AddFailure(addonName, enabled and "enable" or "disable", err or "state did not change")
            return false
        end

        summary.changed = summary.changed + 1
        local bucket = enabled and summary.enabled or summary.disabled
        bucket[#bucket + 1] = addonName
        return true
    end

    local function RollBack()
        local rollbackOK = true
        for index = #applied, 1, -1 do
            local change = applied[index]
            local current = api.IsEnabled(change.name, summary.character) == true
            if current ~= change.previous then
                local restored, err
                if change.previous then
                    restored, err = api.Enable(change.name, summary.character)
                else
                    restored, err = api.Disable(change.name, summary.character)
                end
                if not restored or api.IsEnabled(change.name, summary.character) ~= change.previous then
                    rollbackOK = false
                    summary.rollbackFailed[#summary.rollbackFailed + 1] = {
                        name = change.name,
                        error = tostring(err or "state did not restore"),
                    }
                end
            end
        end

        summary.rolledBack = rollbackOK
        if rollbackOK then
            summary.changed = 0
            summary.enabled = {}
            summary.disabled = {}
        end
        return rollbackOK
    end

    for _, addonName in ipairs(enableQueue) do
        if not ApplyOne(addonName, true) then
            RollBack()
            return false, summary
        end
    end
    for _, addonName in ipairs(disableQueue) do
        if not ApplyOne(addonName, false) then
            RollBack()
            return false, summary
        end
    end

    if summary.changed > 0 then
        local saved, err = api.Save()
        if not saved then
            summary.saveFailed = true
            AddFailure("C_AddOns.SaveAddOns", "save", err or "save failed")
            RollBack()
            return false, summary
        end
        self._reloadRequired = true
    end

    return true, summary
end

function A:SetAddOnEnabled(name, enabled)
    local targetAddon
    for _, addon in ipairs(self._AddonAPI.ListAddOns()) do
        if addon.name == name then
            targetAddon = addon
            break
        end
    end
    if not targetAddon then
        return false, "Addon not found"
    end

    enabled = enabled and true or false
    local protected, reason = self:IsProtectedAddOn(name, targetAddon)
    if protected and not enabled then
        self.Print("Cannot disable " .. name .. ": " .. tostring(reason) .. ".")
        return false, reason
    end
    if IsSecureAddon(targetAddon) then
        return false, "Blizzard secure addon"
    end

    local ok, summary = self:ApplyAddOnEnabledSet({ [name] = enabled })
    if not ok then
        local failure = summary.failed[1]
        return false, failure and failure.error or "Addon state could not be changed", summary
    end
    return true, summary.changed > 0, summary
end
