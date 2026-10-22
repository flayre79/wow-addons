-- Blizzard options entry point.
--
-- Harvest's settings live in its own window (UI_Window.lua), not in a canvas
-- panel inside Blizzard's options -- a panel there is three clicks deep inside
-- someone else's UI and has nowhere to grow. What stays registered is a proxy
-- with one button, so a player who does go looking under AddOns is pointed at
-- the real window instead of finding nothing. Same shape Athena uses.

local H = Harvest
if not H then return end

H.UI = {}

function H.UI:Init()
    local panel = CreateFrame("Frame")
    panel.name = "Harvest"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("FabledUI - Harvest")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    desc:SetText("Gathering nodes, map pins and session radar. "
        .. "Settings and node search live in Harvest's own window -- use /harvest or the button below.")

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    btn:SetSize(160, 26)
    btn:SetText("Open Harvest")
    btn:SetScript("OnClick", function()
        if H.Window then H.Window:Open() end
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "FabledUI - Harvest")
        Settings.RegisterAddOnCategory(cat)
        H.CategoryID = cat.GetID and cat:GetID() or cat.ID
    else
        -- Removed in 10.0; rawget so the dead-client fallback does not read as
        -- an undefined global against the 12.x API surface.
        local legacyAdd = rawget(_G, "InterfaceOptions_AddCategory")
        if legacyAdd then legacyAdd(panel) end
    end

    H.OptionsPanel = panel
end
