local Villa = _G.FabledUI_Villa
local SettingsModule = {}
Villa.Settings = SettingsModule
Villa:RegisterModule("Settings", SettingsModule)

-- Villa's settings live in the Shell control window (Villa_Control.lua), not
-- here. This file exists only to keep the Game Menu -> AddOns entry working:
-- the Blizzard canvas frame covers the world, the map and the housing UI, which
-- are exactly what you need to see while changing a domain mode or toggling the
-- zone overlay, so the controls themselves cannot live in it.
--
-- Deliberately NOT set any more: `Villa.CategoryID`. FabledUI_Nexus's registry
-- resolves a module's settings entry point by checking CategoryID/categoryID
-- FIRST and only then falling back to `settingsPath` (Registry.lua:999-1006).
-- While Villa published a category ID, Nexus's Settings button opened this
-- panel rather than the control window. The category is still registered -- the
-- ID just is not advertised, so Nexus resolves "OpenSettings" and lands in the
-- right place. Villa.Settings.categoryID is kept for OpenCanvas below.

function SettingsModule:BuildPanel()
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", nil, UIParent)
    panel.name = "FabledUI - Villa"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Villa v" .. ((_G.FabledUI_Villa and _G.FabledUI_Villa.VERSION) or "0.30.01"))

    local body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    body:SetJustifyH("LEFT")
    body:SetText("Villa's controls live in their own window so the world, map and housing UI stay visible while you change them. Open it below, with /villa control, or from the Villa button on the world map.")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    open:SetText("Open Villa Controls")
    open:SetScript("OnClick", function()
        if Villa.Control and type(Villa.Control.Open) == "function" then
            Villa.Control:Open()
        end
    end)
    self.openButton = open

    self.panel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

function SettingsModule:OnEnable()
    self:BuildPanel()
end

-- The Blizzard canvas category, for the Game Menu path and as the fallback when
-- the toolkit shell is missing. Callers that just want "Villa's settings"
-- should use Villa:OpenSettings().
function SettingsModule:OpenCanvas()
    self:BuildPanel()
    if Settings and Settings.OpenToCategory and self.categoryID then
        Settings.OpenToCategory(self.categoryID)
        return true
    end
    if InterfaceOptionsFrame_OpenToCategory and self.panel then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        return true
    end
    return false
end

function SettingsModule:Open()
    if Villa.Control and type(Villa.Control.Open) == "function" and Villa.Control:Open() then
        return true
    end
    return self:OpenCanvas()
end
