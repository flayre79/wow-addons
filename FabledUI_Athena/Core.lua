local addonName, _ = ...
Athena = Athena or {}
local A = Athena
_G.FabledUI_Athena = A

A.VERSION = "1.6.0"
A.ADDON_NAME = addonName or "FabledUI_Athena"
A.STORE_KEY = "athena"
A._ready = false

local PREFIX = "|cff7f8cff[Athena]|r "

function A.Print(...)
    print(PREFIX, ...)
end

function A.Debug(msg)
    local enabled = A.Storage and A.Storage.Get
        and A.Storage:Get("account", { "meta", "debug" }, false)
    if enabled then
        A.Print("|cffaaaaaa" .. tostring(msg) .. "|r")
    end
end

function A.SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        A.Print("|cffff5555Error:|r " .. tostring(a))
        return nil
    end
    return a, b, c, d
end

function A.GetCharacterKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Realm")
end

function A.GetCharacterID()
    if type(UnitGUID) == "function" then
        local guid = UnitGUID("player")
        if type(guid) == "string" and guid ~= "" then
            return guid
        end
    end
    return UnitName("player") or "Unknown"
end

function A.Trim(s)
    return type(s) == "string" and (s:gsub("^%s+", ""):gsub("%s+$", "")) or ""
end

function A.NormalizeKey(s)
    s = A.Trim(s):lower():gsub("%s+", "_"):gsub("[^%w_]+", "")
    return s == "" and "unnamed" or s
end

function A.SortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGOUT")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGOUT" then
        -- Flush any pending debounced SV writes before client teardown.
        if A.Util and A.Util.Flush then pcall(function() A.Util:Flush() end) end
        return
    end
    if event == "PLAYER_LOGIN" then
        A:InitStorage()
        if A.RegisterSettingsPanel then A:RegisterSettingsPanel() end
        if A.InitBlizzardAddOnsIntegration then A:InitBlizzardAddOnsIntegration() end

        SLASH_FABLEDUI_ATHENA1 = "/athena"
        SlashCmdList["FABLEDUI_ATHENA"] = function(msg)
            local cmd, rest = (msg or ""):match("^(%S+)%s*(.*)$")
            cmd = (cmd or ""):lower()

            if cmd == "save" then A:SaveProfile(rest)
            elseif cmd == "apply" then A:ApplyProfile(rest)
            elseif cmd == "default" then A:SetDefaultProfileForChar(rest)
            elseif cmd == "list" then
                local keys = A:ListProfiles()
                A.Print(#keys > 0 and ("Profiles: " .. table.concat(keys, ", ")) or "No profiles saved yet.")
            else
                A:ToggleMain()
            end
        end

        A._ready = true
        A.Print("Online (" .. A._storageBackend .. "). /athena | save/apply/default/list")
        return
    end

    if event == "ADDON_LOADED" and (
        arg1 == "Blizzard_AddOnList"
        or arg1 == "Blizzard_AddOnManager"
        or arg1 == "Blizzard_AddOns"
    ) then
        if A.InitBlizzardAddOnsIntegration then
            -- Defer when in combat: the Blizzard AddOn panel chrome is
            -- protected; calling CreateFrame/SetPoint on it during combat
            -- can taint the panel and lock us out of clicking it. Wait for
            -- PLAYER_REGEN_ENABLED before installing.
            if InCombatLockdown and InCombatLockdown() then
                local deferred = CreateFrame("Frame")
                deferred:RegisterEvent("PLAYER_REGEN_ENABLED")
                deferred:SetScript("OnEvent", function(self)
                    self:UnregisterAllEvents()
                    if A.InitBlizzardAddOnsIntegration then A:InitBlizzardAddOnsIntegration() end
                end)
            else
                A:InitBlizzardAddOnsIntegration()
            end
        end
    end
end)
