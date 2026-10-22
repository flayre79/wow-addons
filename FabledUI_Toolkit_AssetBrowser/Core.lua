local addonName, ns = ...

ns.ADDON_NAME = addonName
ns.FRAME_NAME = addonName .. "Frame"
ns.DATAVAULT_SHARD = "FabledUI_DataVault_AssetBrowser"
ns.LOCAL_DB_NAME = "FabledUI_Toolkit_AssetBrowserDB"
ns.DB = nil
ns.StorageMode = "local"
ns.frames = ns.frames or {}

local Toolkit = rawget(_G, "FabledUI_UIToolkit")
ns.Toolkit = Toolkit

local defaults = {
    assetBrowser = {
        enabled = true,
        openOnLogin = false,
        includeMissingAtlases = false,
        activeTab = "atlas",
        atlasSearch = "",
        iconSearch = "",
        atlasSort = "name",
        iconSort = "id",
        window = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 1180,
            height = 760,
            scale = 1,
            alpha = 1,
            displayState = "expanded",
            ribbonPoint = "TOP",
            ribbonRelativePoint = "TOP",
            ribbonX = 0,
            ribbonY = -160,
            ribbonWidth = 280,
            ribbonHeight = 24,
        },
        iconCache = {},
        scan = {
            maxSpellID = 250000,
            nextSpellID = 1,
            complete = false,
        },
    },
}

local function CopyDefaults(dst, src)
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

local function ResolveRootTable()
    local dataVaultRoot = rawget(_G, ns.DATAVAULT_SHARD)
    local legacyRoot = rawget(_G, ns.LOCAL_DB_NAME)

    if type(dataVaultRoot) == "table" then
        ns.StorageMode = "datavault-compatible"
        _G[ns.LOCAL_DB_NAME] = dataVaultRoot
        return dataVaultRoot
    end

    if type(legacyRoot) == "table" then
        ns.StorageMode = "local-migrated"
        _G[ns.DATAVAULT_SHARD] = legacyRoot
        return legacyRoot
    end

    ns.StorageMode = "local-new"
    local root = {}
    _G[ns.LOCAL_DB_NAME] = root
    _G[ns.DATAVAULT_SHARD] = root
    return root
end

function ns:GetDB()
    return self.DB and self.DB.assetBrowser or nil
end

function ns:Print(message)
    local prefix = "|cff66c0ff" .. addonName .. "|r: "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(message))
end

function ns:Notify(message, icon, duration)
    if self.Toolkit and self.Toolkit.Toast and type(self.Toolkit.Toast.Show) == "function" then
        self.Toolkit.Toast:Show(message, icon, duration)
    else
        self:Print(message)
    end
end

function ns:ApplyToolkitTheme(frame, themeName)
    if self.Toolkit and self.Toolkit.Themes and type(self.Toolkit.Themes.Apply) == "function" then
        self.Toolkit.Themes:Apply(frame, themeName or "Dark")
        return true
    end
    return false
end

function ns:ShowCopyDialog(label, text)
    local dialogKey = addonName .. "_COPY_DIALOG"
    StaticPopupDialogs[dialogKey] = StaticPopupDialogs[dialogKey] or {
        text = "%s",
        button1 = OKAY,
        hasEditBox = true,
        editBoxWidth = 420,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog, data)
            dialog.Text:SetText(data.label or "Copy")
            dialog.editBox:SetText(data.text or "")
            dialog.editBox:HighlightText()
            dialog.editBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        OnAccept = function(dialog)
            dialog:Hide()
        end,
    }

    StaticPopup_Show(dialogKey, nil, nil, {
        label = label,
        text = text,
    })
end

function ns:RegisterWithToolkit()
    if not self.Toolkit or type(self.Toolkit.RegisterDevTool) ~= "function" or not self.AssetBrowser then
        return
    end

    self.Toolkit:RegisterDevTool("asset_browser", {
        displayName = "Asset Browser",
        addonName = addonName,
        icon = 134400,
        open = function()
            self.AssetBrowser:Toggle(true)
        end,
        toggle = function()
            self.AssetBrowser:Toggle()
        end,
        isAvailable = function()
            return self:GetDB() and self:GetDB().enabled
        end,
        object = self.AssetBrowser,
    })
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local root = ResolveRootTable()
        CopyDefaults(root, defaults)
        ns.DB = root
    elseif event == "PLAYER_LOGIN" then
        ns.Toolkit = rawget(_G, "FabledUI_UIToolkit")
        if ns.RegisterSettings then
            ns:RegisterSettings()
        end
        ns:RegisterWithToolkit()
        if ns.AssetBrowser and ns:GetDB() and ns:GetDB().enabled and ns:GetDB().openOnLogin then
            ns.AssetBrowser:Toggle(true)
        end
    end
end)

SLASH_FABLEDUIASSETBROWSER1 = "/fuiassets"
SLASH_FABLEDUIASSETBROWSER2 = "/fuiassetbrowser"
SLASH_FABLEDUIASSETBROWSER3 = "/fuiassetsettings"
SlashCmdList.FABLEDUIASSETBROWSER = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "settings" or msg == "config" or msg == "options" or msg == "" and IsShiftKeyDown() then
        if ns.SettingsCategory then
            Settings.OpenToCategory(ns.SettingsCategory:GetID())
        end
        return
    end

    if not ns.AssetBrowser then
        ns:Print("Asset Browser is not available.")
        return
    end

    local db = ns:GetDB()
    if db and db.enabled == false then
        ns:Print("Asset Browser is disabled in settings.")
        return
    end

    ns.AssetBrowser:Toggle()
end
