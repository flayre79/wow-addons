local Villa = _G.FabledUI_Villa
local Dashboard = {}
Villa.Dashboard = Dashboard
Villa:RegisterModule("Dashboard", Dashboard)

-- Villa no longer injects its whole UI into Blizzard's Housing Dashboard (that
-- crammed 22 tabs of list+detail into a corner of a fixed frame). Instead it
-- runs in its own resizable FableNeon window (Tabs.lua), and this module just
-- adds a small neon launcher to the dashboard for discoverability.
Dashboard.Cache = {
    MainFrame = nil,
    CatalogPanel = nil,
    HouseInfoPanel = nil,
}

Dashboard.eventFrame = Dashboard.eventFrame or CreateFrame("Frame")

local function ResolveDashboardFrame()
    return _G.HousingDashboardFrame or _G.PlayerHousingFrame or _G.HousingFrame
end

function Dashboard:GetFrame()
    return ResolveDashboardFrame()
end

function Dashboard:RefreshCache(frame)
    frame = frame or self.Cache.MainFrame or ResolveDashboardFrame()
    if not frame then
        return nil
    end
    self.Cache.MainFrame = frame
    self.Cache.CatalogPanel = frame.CatalogContent or frame.CatalogPanel or nil
    self.Cache.HouseInfoPanel = frame.HouseInfoContent or frame.HouseInfoPanel or nil
    return frame
end

-- A 40x40 neon launcher hanging off the dashboard's top-left edge (the empty
-- gutter where the old tab rail used to sit — no overlap with Blizzard content).
function Dashboard:AddLauncher(frame)
    if not frame or frame.VillaLauncher then
        return
    end
    local UI = Villa.UI

    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(40, 40)
    btn:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, -8)
    btn:SetFrameStrata("HIGH")

    local base = (UI and UI.InsetBG) and { UI.InsetBG[1], UI.InsetBG[2], UI.InsetBG[3], 0.96 } or { 0.05, 0.06, 0.12, 0.96 }
    local hover = (UI and UI.RowBG) and { UI.RowBG[1], UI.RowBG[2], UI.RowBG[3], 0.98 } or { 0.09, 0.11, 0.19, 0.98 }

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(base[1], base[2], base[3], base[4])

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexture(134414) -- housing icon (matches the .toc IconTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local T = rawget(_G, "FabledUI_UIToolkit")
    if T and T.Effects and type(T.Effects.AddNeonBorder) == "function" then
        local col = (UI and (UI.BorderStrong or UI.Accent)) or { 0.227, 0.882, 1.0, 0.85 }
        pcall(T.Effects.AddNeonBorder, T.Effects, btn, col, 1)
    end

    btn:SetScript("OnEnter", function(self)
        bg:SetColorTexture(hover[1], hover[2], hover[3], hover[4])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("FabledUI Villa")
        GameTooltip:AddLine("Housing vendors, sources, wishlists & more.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Click to open Villa.", 0.6, 0.85, 1.0)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        bg:SetColorTexture(base[1], base[2], base[3], base[4])
        GameTooltip_Hide()
    end)
    btn:SetScript("OnClick", function()
        if Villa.ToggleUI then
            Villa:ToggleUI()
        end
    end)

    frame.VillaLauncher = btn
end

function Dashboard:TryAttach()
    local frame = self:RefreshCache()
    if not frame then
        return false
    end
    self:AddLauncher(frame)
    self:HookFrame(frame)
    return true
end

function Dashboard:ScheduleRetry(delay)
    C_Timer.After(delay or 0.25, function()
        self:TryAttach()
    end)
end

function Dashboard:ScheduleRetryBurst()
    for _, delay in ipairs({ 0, 0.1, 0.5, 1.0, 2.0 }) do
        self:ScheduleRetry(delay)
    end
end

function Dashboard:HookFrame(frame)
    if not frame or frame.VillaHooked then
        return
    end
    frame.VillaHooked = true

    -- Only re-assert the launcher when the dashboard shows; the Villa window is
    -- independent of the dashboard's visibility now.
    frame:HookScript("OnShow", function()
        self:RefreshCache(frame)
        self:AddLauncher(frame)
    end)
end

function Dashboard:OnEnable()
    local ef = self.eventFrame
    ef:UnregisterAllEvents()
    ef:RegisterEvent("ADDON_LOADED")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("PLAYER_LOGIN")
    ef:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_HousingDashboard" then
            self:ScheduleRetryBurst()
        elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
            self:ScheduleRetryBurst()
        end
    end)
    self:ScheduleRetryBurst()
end

function Dashboard:PrintDebug()
    self:RefreshCache()
    Villa:Print(
        "MainFrame:", tostring(self.Cache.MainFrame ~= nil),
        "HouseInfo:", tostring(self.Cache.HouseInfoPanel ~= nil),
        "Catalog:", tostring(self.Cache.CatalogPanel ~= nil),
        "VillaWindow:", tostring(Villa.Tabs and Villa.Tabs.IsShown and Villa.Tabs:IsShown() or false)
    )
end
