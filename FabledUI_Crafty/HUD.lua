local M = _G.FabledUI_Crafty
M.HUD = M.HUD or {}
local H = M.HUD
local TK = M.Toolkit

-- Shared RadarHUD from UIToolkit (SVC-004)
local SharedHUD = FabledUI_UIToolkit and FabledUI_UIToolkit.RadarHUD

-- ================================================================
-- Respawn-status helpers (Crafty-specific age → shared status)
-- ================================================================
local RESPAWN_FRESH = 5 * 60    -- < 5 min  → stale (not yet respawned)
local RESPAWN_MAYBE = 15 * 60   -- 5-15 min → aging (uncertain)

local function NodeStatus(node)
    local age = time() - (node.t or 0)
    if age < RESPAWN_FRESH then
        return "stale"
    elseif age < RESPAWN_MAYBE then
        return "aging"
    end
    return "fresh"
end

-- ================================================================
-- Position persistence
-- ================================================================
local function CapturePosition(frame)
    if not frame or not M.db or not M.db.hud then
        return
    end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    M.db.hud.window = M.db.hud.window or {}
    M.db.hud.window.point = point
    M.db.hud.window.relativePoint = relativePoint
    M.db.hud.window.x = x
    M.db.hud.window.y = y
    M:MarkDirty()
end

function H:Init()
    if self.frame then
        return
    end

    -- Outer window — taller to fit radar below the text stats
    local frame = CreateFrame("Frame", "FabledUI_CraftyHUD", UIParent, "BackdropTemplate")
    frame:SetSize(240, 340)
    local hudState = (M.db and M.db.hud and M.db.hud.window) or {}
    frame:SetPoint(hudState.point or "CENTER", UIParent, hudState.relativePoint or "CENTER", hudState.x or 420, hudState.y or 140)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        CapturePosition(self)
    end)
    frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.03, 0.05, 0.06, 0.9)

    -- ---- Text stats ----
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 12, -12)
    frame.title:SetText("Crafty HUD")

    frame.countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.countText:SetPoint("TOPLEFT", 12, -38)

    frame.rateText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.rateText:SetPoint("TOPLEFT", 12, -64)

    frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusText:SetPoint("TOPLEFT", 12, -84)

    -- ---- Circular Radar (shared SVC-004) ----
    if SharedHUD then
        frame.radar = SharedHUD:CreateRadar(frame, {
            size  = 180,
            range = 0.15,
            rings = { 150, 300 },
            ringRanges = { 0.05, 0.10 },
        })
        frame.radar:SetPoint("TOP", frame, "TOP", 0, -112)
        frame.radar:SetActive(true)
    end

    -- ---- Legend ----
    local legendAnchor = frame.radar or frame.statusText
    local legend = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOP", legendAnchor, "BOTTOM", 0, -6)
    -- Player marker is bright cyan with a white core (centre, larger than blips).
    -- Blips are colored by respawn age: <5m red (just gathered), 5-15m yellow (uncertain), >=15m green (likely respawned).
    legend:SetText("|cff44ddff●|r You  |cffe53333●|r <5m  |cffe5d010●|r ~10m  |cff33dd55●|r Respawned")
    legend:SetJustifyH("CENTER")
    legend:SetWidth(220)

    -- Farm session line
    frame.farmText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.farmText:SetPoint("TOP", legend, "BOTTOM", 0, -6)
    frame.farmText:SetText("")

    -- Stop session button
    local stopBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    stopBtn:SetSize(100, 22)
    stopBtn:SetPoint("BOTTOM", frame, "BOTTOM", -50, 10)
    stopBtn:SetText("Stop Session")
    stopBtn:SetScript("OnClick", function()
        if M.FarmSession then M.FarmSession:StopSession() end
    end)

    frame.pinButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.pinButton:SetSize(72, 22)
    frame.pinButton:SetPoint("BOTTOM", frame, "BOTTOM", 42, 10)
    frame.pinButton:SetText("Pin")
    frame.pinButton:SetScript("OnClick", function()
        self:TogglePinned()
    end)

    if TK then
        TK:ApplyPanel(frame, true)
        TK:ApplyTitleText(frame.title)
        TK:ApplyBodyText(frame.rateText)
        TK:ApplyBodyText(frame.statusText, true)
        TK:StyleFlatButton(frame.pinButton)
        TK:StyleFlatButton(stopBtn)
    end

    self.frame = frame
    self:Refresh()
    frame:SetShown(M.settings.pinHUD)
end

function H:TogglePinned()
    M.settings.pinHUD = not M.settings.pinHUD
    M:SaveSettings()
    if self.frame then
        self.frame:SetShown(M.settings.pinHUD)
        self:Refresh()
    end
end

function H:Refresh()
    if not self.frame then
        return
    end

    local f = self.frame

    -- ---- Craft stats ----
    local lumber = M.Materials:GetLumberCount()
    local queueCount = #M.Queue:GetAll()
    local concentration = M.Concentration and M.Concentration:GetBestCurrentCharacterSnapshot() or nil
    f.countText:SetText(string.format("Lumber: %d", lumber))
    local lumberLine = M.Lumber and M.Lumber.GetTopBreakdownLine and M.Lumber:GetTopBreakdownLine(2) or nil
    local statusLine
    if concentration then
        f.rateText:SetText(string.format("Queue %d · %s %d/%d", queueCount, concentration.professionName or "Conc", math.floor(concentration.current or 0), concentration.maxQuantity or 0))
        statusLine = (concentration.current or 0) < (concentration.maxQuantity or 0) and ("Full in " .. M.Concentration:FormatTimer(concentration.secondsUntilFull)) or "Concentration ready."
    else
        f.rateText:SetText(string.format("Queued crafts: %d", queueCount))
        statusLine = M.settings.pinHUD and "Pinned until you hide it." or "Hidden when not pinned."
    end
    if lumberLine and lumberLine ~= "" then
        statusLine = lumberLine .. " · " .. statusLine
    end
    f.statusText:SetText(statusLine)
    f.pinButton:SetText(M.settings.pinHUD and "Unpin" or "Pin")
    if TK then
        TK:StyleFlatButton(f.pinButton)
    end

    -- ---- Farm session line ----
    if f.farmText then
        local fs = M.FarmSession
        if fs and fs.activeSession then
            local rate = fs:GetSessionRate()
            local elapsed = time() - (fs.activeSession.startTime or 0)
            local mins = math.floor(elapsed / 60)
            f.farmText:SetText(string.format("|cff88ffaaFarming:|r %d gathers · %d/hr · %dm", fs.activeSession.gathers, rate, mins))
        else
            f.farmText:SetText("|cff888888No active farm session.|r")
        end
    end

    -- ---- Radar blips (delegate to shared RadarHUD) ----
    if f.radar and f.radar.SetPoints then
        local nodes = (M.FarmSession and M.FarmSession:GetRecentNodes()) or {}
        local points = {}
        for i = #nodes, 1, -1 do
            local node = nodes[i]
            points[#points + 1] = {
                x      = node.x,
                y      = node.y,
                mapID  = node.mapID,
                status = NodeStatus(node),
            }
        end
        f.radar:SetPoints(points)
        f.radar:Render()
    end
end
