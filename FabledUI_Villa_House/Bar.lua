-- VillaHouse's House XP bar: always on screen, movable, never calls the housing API.
-- It renders VillaHouse:GetProgress() and nothing else; Core.lua decides when the
-- numbers change and fires the callback that repaints this.

local VillaHouse = _G.FabledUI_Villa_House
if not VillaHouse then return end

local Bar = {}
VillaHouse.Bar = Bar

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 300, 18
local DEFAULT_POINT = { "BOTTOM", 0, 190 }

local COLOR_LIVE  = { 1.00, 0.72, 0.11 }
local COLOR_STALE = { 0.55, 0.55, 0.55 }
local COLOR_MAX   = { 0.35, 0.85, 0.45 }

local function formatNumber(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if type(BreakUpLargeNumbers) == "function" then
        return BreakUpLargeNumbers(value)
    end
    return tostring(value)
end

local function settings()
    local bar = VillaHouse:DB().bar
    if bar.shown == nil then bar.shown = true end
    if bar.locked == nil then bar.locked = false end
    return bar
end

function Bar:ApplyPosition()
    local frame = self.frame
    if not frame then return end
    local saved = settings()
    frame:ClearAllPoints()
    if type(saved.point) == "string" and type(saved.x) == "number" and type(saved.y) == "number" then
        frame:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
    else
        frame:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[1], DEFAULT_POINT[2], DEFAULT_POINT[3])
    end
end

function Bar:SavePosition()
    local frame = self.frame
    if not frame then return end
    local point, _, _, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then return end
    local saved = settings()
    saved.point, saved.x, saved.y = point, x or 0, y or 0
end

function Bar:ResetPosition()
    local saved = settings()
    saved.point, saved.x, saved.y = nil, nil, nil
    self:ApplyPosition()
end

function Bar:SetLocked(locked)
    settings().locked = locked and true or false
end

function Bar:SetShown(shown)
    settings().shown = shown and true or false
    if self.frame then self.frame:SetShown(settings().shown) end
end

function Bar:ShowTooltip()
    local frame = self.frame
    if not frame or not GameTooltip then return end
    local p = VillaHouse:GetProgress()
    local s = VillaHouse.state

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    if not p then
        GameTooltip:SetText("House XP")
        GameTooltip:AddLine("Waiting for your house. If this does not fill in, open the Housing Dashboard once.", 0.8, 0.8, 0.8, true)
    else
        GameTooltip:SetText("House Level " .. p.level)
        if p.isMax then
            GameTooltip:AddLine("Maximum level.", 0.35, 0.85, 0.45)
        elseif p.span > 0 then
            GameTooltip:AddDoubleLine("This level",
                string.format("%s / %s (%d%%)", formatNumber(p.into), formatNumber(p.span), math.floor(p.fraction * 100)),
                0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("To level " .. (p.level + 1), formatNumber(p.remaining) .. " XP",
                0.8, 0.8, 0.8, 1, 0.82, 0)
        end
        GameTooltip:AddDoubleLine("Total House XP", formatNumber(p.favor), 0.8, 0.8, 0.8, 1, 1, 1)
        if s.sessionGain > 0 then
            GameTooltip:AddDoubleLine("This session",
                string.format("+%s (last +%s)", formatNumber(s.sessionGain), formatNumber(s.lastGain)),
                0.8, 0.8, 0.8, 0.4, 1, 0.4)
        end
        -- One read, on hover. Same call Blizzard's Endeavors tab makes for its
        -- House XP icon.
        local available = VillaHouse.Api.AvailableEndeavorXP()
        if available then
            GameTooltip:AddDoubleLine("Endeavor House XP available", formatNumber(available), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if not p.confirmed then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Showing last session's numbers until the game sends new ones.", 0.6, 0.6, 0.6, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click for endeavor tasks and what they really pay.", 0.6, 0.85, 1.0)
    if rawget(_G, "FabledUI_VillaDecor") then
        GameTooltip:AddLine("Right-click for new decor that still pays House XP.", 0.6, 0.85, 1.0)
    end
    if not settings().locked then
        GameTooltip:AddLine("Drag to move. /vhouse lock to pin it.", 0.6, 0.85, 1.0)
    end
    GameTooltip:Show()
end

function Bar:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "FabledUI_VillaHouseBar", UIParent)
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    self.frame = frame

    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0, 0, 0, 0.65)

    local fill = CreateFrame("StatusBar", nil, frame)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(0)
    self.fill = fill

    local text = fill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", 0, 0)
    self.text = text

    frame:SetScript("OnDragStart", function(f)
        if not settings().locked then
            Bar.dragging = true
            f:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        Bar:SavePosition()
    end)
    -- A click opens the task list; the release that ends a drag does not.
    frame:SetScript("OnMouseUp", function(_, button)
        local wasDragging = Bar.dragging
        Bar.dragging = false
        if wasDragging then return end
        if button == "LeftButton" then
            if VillaHouse.TaskList then VillaHouse.TaskList:Toggle() end
        elseif button == "RightButton" then
            -- The sibling addon; absent is fine, the click just does nothing.
            local decor = rawget(_G, "FabledUI_VillaDecor")
            if type(decor) == "table" and decor.Window then decor.Window:Toggle() end
        end
    end)
    frame:SetScript("OnEnter", function() Bar:ShowTooltip() end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    self:ApplyPosition()
    frame:SetShown(settings().shown)
    VillaHouse:RegisterCallback(self, function() Bar:Refresh() end)
    self:Refresh()
    return frame
end

function Bar:Refresh()
    if not self.frame then return end
    local p = VillaHouse:GetProgress()

    if not p then
        self.fill:SetValue(0)
        self.text:SetText("House XP: waiting")
        return
    end

    local color = COLOR_LIVE
    if p.isMax then
        color = COLOR_MAX
    elseif not p.confirmed then
        color = COLOR_STALE
    end
    self.fill:SetStatusBarColor(color[1], color[2], color[3])
    self.fill:SetValue(p.fraction)

    if p.isMax then
        self.text:SetText(string.format("House %d  |  Max", p.level))
    elseif p.span > 0 then
        self.text:SetText(string.format("House %d  |  %d%%  |  %s to %d",
            p.level, math.floor(p.fraction * 100), formatNumber(p.remaining), p.level + 1))
    else
        self.text:SetText(string.format("House %d", p.level))
    end
end
