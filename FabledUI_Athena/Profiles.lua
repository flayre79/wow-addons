local A = Athena

local PROFILE_SCHEMA = 2
local MAX_PROFILE_NAME = 64

local function ValidateProfileName(profileName)
    profileName = A.Trim(profileName)
    if profileName == "" then
        return nil, "Profile name is required."
    end
    if #profileName > MAX_PROFILE_NAME then
        return nil, "Profile names may not exceed " .. MAX_PROFILE_NAME .. " characters."
    end
    if profileName:find("[%c]") then
        return nil, "Profile names may not contain control characters."
    end
    return profileName, nil
end

local function ProfileExists(profileName)
    for _, existing in ipairs(A.Storage:ListProfiles()) do
        if existing == profileName then
            return true
        end
    end
    return false
end

local function NormalizeBundle(bundle)
    if type(bundle) ~= "table" or type(bundle.enabledAddons) ~= "table" then
        return nil
    end

    local enabledAddons = {}
    for addonName, enabled in pairs(bundle.enabledAddons) do
        if type(addonName) == "string" and addonName ~= "" and type(enabled) == "boolean" then
            enabledAddons[addonName] = enabled
        end
    end

    return {
        schema = tonumber(bundle.schema) or PROFILE_SCHEMA,
        savedAt = tonumber(bundle.savedAt) or 0,
        enabledAddons = enabledAddons,
    }
end

function A:ListProfiles()
    return self.Storage:ListProfiles()
end

function A:GetActiveProfile()
    return self.Storage:GetProfile()
end

function A:GetDefaultProfileForChar()
    local profileName = self.Storage:Get("character", { "defaultProfile" }, nil)
    return type(profileName) == "string" and profileName ~= "" and profileName or nil
end

function A:SetDefaultProfileForChar(profileKey)
    local profileName, err = ValidateProfileName(profileKey)
    if not profileName then
        self.Print(err)
        return false
    end
    if not ProfileExists(profileName) then
        self.Print("Profile not found: " .. profileName)
        return false
    end
    if not self.Storage:Set("character", { "defaultProfile" }, profileName) then
        self.Print("Could not save the default profile.")
        return false
    end

    self.Print("Default profile for this character = " .. profileName)
    return true
end

function A:GetProfileBundle(profileKey)
    local profileName, err = ValidateProfileName(profileKey)
    if not profileName then
        return nil, err
    end
    if not ProfileExists(profileName) then
        return nil, "Profile not found: " .. profileName
    end
    local previousProfile = self.Storage:GetProfile()
    if not self.Storage:SetProfile(profileName) then
        return nil, "Could not select profile: " .. profileName
    end

    local bundle = NormalizeBundle(self.Storage:GetProfileData({ "bundle" }, nil))
    if not bundle then
        -- Compatibility with an early DataVault experiment that wrote fields
        -- directly at the profile root instead of beneath `bundle`.
        bundle = NormalizeBundle({
            schema = self.Storage:GetProfileData({ "schema" }, PROFILE_SCHEMA),
            savedAt = self.Storage:GetProfileData({ "savedAt" }, 0),
            enabledAddons = self.Storage:GetProfileData({ "enabledAddons" }, nil),
        })
    end
    if not bundle then
        if previousProfile ~= profileName then
            self.Storage:SetProfile(previousProfile)
        end
        return nil, "Profile data is missing or corrupt: " .. profileName
    end
    return bundle, nil
end

function A:SaveProfile(profileKey)
    local profileName, err = ValidateProfileName(profileKey)
    if not profileName then
        self.Print(err or "Usage: /athena save <profileName>")
        return false
    end

    local enabledAddons = self.GetAddOnEnabledMap()
    local bundle = {
        schema = PROFILE_SCHEMA,
        savedAt = type(time) == "function" and time() or 0,
        enabledAddons = enabledAddons,
    }

    local previousProfile = self.Storage:GetProfile()
    if not self.Storage:SetProfile(profileName) then
        self.Print("Could not select profile: " .. profileName)
        return false
    end
    if not self.Storage:SetProfileData({ "bundle" }, bundle) then
        if previousProfile ~= profileName then
            self.Storage:SetProfile(previousProfile)
        end
        self.Print("Could not save profile: " .. profileName)
        return false
    end

    local enabledCount, capturedCount = 0, 0
    for _, enabled in pairs(enabledAddons) do
        capturedCount = capturedCount + 1
        if enabled then
            enabledCount = enabledCount + 1
        end
    end
    self.Print(
        "Saved profile: " .. profileName
        .. " (" .. tostring(enabledCount) .. " enabled, " .. tostring(capturedCount) .. " captured)"
    )
    return true, A.DeepCopy(bundle)
end

function A:ApplyProfile(profileKey)
    local profileName = A.Trim(profileKey)
    if profileName == "" then
        self.Print("Usage: /athena apply <profileName>")
        return false
    end

    local bundle, err = self:GetProfileBundle(profileName)
    if not bundle then
        self.Print(err)
        return false
    end

    local ok, summary = self:ApplyAddOnEnabledSet(bundle.enabledAddons)
    if not ok then
        if summary.blocked and #summary.missingDependencies > 0 then
            self.Print("Profile was not applied because required dependencies are missing.")
        elseif summary.blocked then
            self.Print("Profile cannot be applied during combat.")
        elseif summary.rolledBack then
            self.Print("Profile was not applied; addon changes were rolled back.")
        else
            self.Print("|cffff5555Profile was only partially applied and could not be fully rolled back.|r")
        end
    elseif summary.changed > 0 then
        self.Print(
            "Applied profile: " .. profileName
            .. " (changed " .. tostring(summary.changed) .. "). |cffffcc00Reload required.|r"
        )
    else
        self.Print("Applied profile: " .. profileName .. " (no changes).")
    end

    if #summary.missing > 0 then
        local required, ignored = {}, {}
        for _, addonName in ipairs(summary.missingDependencies) do
            required[addonName] = true
        end
        for _, addonName in ipairs(summary.missing) do
            if not required[addonName] then
                ignored[#ignored + 1] = addonName
            end
        end
        if #ignored > 0 then
            self.Print("Missing profile addons ignored: " .. table.concat(ignored, ", "))
        end
        if #summary.missingDependencies > 0 then
            self.Print("Missing required dependencies: " .. table.concat(summary.missingDependencies, ", "))
        end
    end
    if #summary.failed > 0 then
        self.Print("|cffff5555" .. tostring(#summary.failed) .. " addon change(s) failed.|r")
    end
    return ok, summary
end
