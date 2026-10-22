-- The Preyhunter's Journey bar: always on screen, movable. It renders
-- Journey:GetProgress() and Journey:GetHunt() and nothing else; Core.lua
-- decides when the numbers change and fires the callback that repaints this.
-- Same shape as FabledUI_Villa_House's House XP bar, so the two can sit
-- together. The hunt in progress is one line just above the bar.

local Journey = _G.FabledUI_Prey_Journey
if not Journey then return end

local Bar = {}
Journey.Bar = Bar

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 300, 18
local DEFAULT_POINT = { "BOTTOM", 0, 212 }

local COLOR_LIVE   = { 0.82, 0.20, 0.25 }
local COLOR_CAPPED = { 0.55, 0.55, 0.55 }
local COLOR_MAX    = { 0.35, 0.85, 0.45 }

-- Difficulty word colours on the hunt line. Anything else stays white.
local DIFFICULTY_COLORS = {
    normal    = "ff40c040",
    hard      = "ffff9020",
    nightmare = "ffe02030",
}

local function formatNumber(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if type(BreakUpLargeNumbers) == "function" then
        return BreakUpLargeNumbers(value)
    end
    return tostring(value)
end

local function settings()
    local bar = Journey:DB().bar
    if bar.shown == nil then bar.shown = true end
    if bar.locked == nil then bar.locked = false end
    return bar
end

-- "Praetor Singularis (Hard) - Eversong Woods", with the difficulty coloured.
function Bar.HuntLine(hunt)
    if type(hunt) ~= "table" then return nil end
    local text = "Hunting " .. hunt.target
    if hunt.difficulty then
        local color = DIFFICULTY_COLORS[hunt.difficulty:lower()]
        local word = color and ("|c" .. color .. hunt.difficulty .. "|r") or hunt.difficulty
        text = text .. " (" .. word .. ")"
    end
    if hunt.zone then text = text .. " - " .. hunt.zone end
    return text
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
    local p = Journey:GetProgress()
    local s = Journey.state

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    if not p then
        GameTooltip:SetText("Preyhunter's Journey")
        GameTooltip:AddLine("This character has no Prey journey yet, or the game has not sent it.", 0.8, 0.8, 0.8, true)
    elseif not p.unlocked then
        GameTooltip:SetText(p.name)
        GameTooltip:AddLine("Locked.", 0.8, 0.8, 0.8)
    else
        GameTooltip:SetText(string.format("%s  -  Level %d", p.name, p.level))
        if p.isMax and not p.paragon then
            GameTooltip:AddLine("Maximum level.", 0.35, 0.85, 0.45)
        elseif p.span > 0 then
            GameTooltip:AddDoubleLine("This level",
                string.format("%s / %s (%d%%)", formatNumber(p.into), formatNumber(p.span), math.floor(p.fraction * 100)),
                0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("To level " .. (p.level + 1), formatNumber(p.remaining),
                0.8, 0.8, 0.8, 1, 0.82, 0)
        end
        if p.maxLevel > 0 and not p.paragon then
            GameTooltip:AddDoubleLine("Journey", string.format("%d of %d", p.renownLevel, p.maxLevel),
                0.8, 0.8, 0.8, 1, 1, 1)
        end
        if s.sessionGain > 0 then
            GameTooltip:AddDoubleLine("This session",
                string.format("+%s (last +%s)", formatNumber(s.sessionGain), formatNumber(s.lastGain)),
                0.8, 0.8, 0.8, 0.4, 1, 0.4)
        end
        if p.weeklyCapped then
            GameTooltip:AddLine("Weekly cap reached.", 1, 0.5, 0.25)
        end
    end

    local hunt = Journey:GetHunt()
    if hunt then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Hunting", hunt.target, 0.8, 0.8, 0.8, 1, 1, 1)
        if hunt.difficulty then
            GameTooltip:AddDoubleLine("Difficulty", hunt.difficulty, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("Where", hunt.zone or "unknown", 0.8, 0.8, 0.8, 1, 1, 1)
        for _, objective in ipairs(hunt.objectives or {}) do
            if objective.done then
                GameTooltip:AddLine("  " .. objective.text, 0.45, 0.80, 0.45, true)
            else
                GameTooltip:AddLine("  " .. objective.text, 1, 1, 1, true)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to open the journey.", 0.6, 0.85, 1.0)
    if hunt then
        GameTooltip:AddLine("Right-click to show the hunt on the map.", 0.6, 0.85, 1.0)
    end
    if not settings().locked then
        GameTooltip:AddLine("Drag to move. /prey lock to pin it.", 0.6, 0.85, 1.0)
    end
    GameTooltip:Show()
end

function Bar:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "FabledUI_PreyJourneyBar", UIParent)
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

    -- The hunt line sits just above the bar and moves with it.
    local huntText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    huntText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    huntText:Hide()
    self.huntText = huntText

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
    -- A click opens the journey, a right-click the hunt's map; the release
    -- that ends a drag does neither.
    frame:SetScript("OnMouseUp", function(_, button)
        local wasDragging = Bar.dragging
        Bar.dragging = false
        if wasDragging then return end
        if button == "LeftButton" then
            Journey:Open()
        elseif button == "RightButton" then
            Journey:OpenHunt()
        end
    end)
    frame:SetScript("OnEnter", function() Bar:ShowTooltip() end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    self:ApplyPosition()
    frame:SetShown(settings().shown)
    Journey:RegisterCallback(self, function() Bar:Refresh() end)
    self:Refresh()
    return frame
end

function Bar:RefreshHunt()
    local line = Bar.HuntLine(Journey:GetHunt())
    if line then
        self.huntText:SetText(line)
        self.huntText:Show()
    else
        self.huntText:SetText("")
        self.huntText:Hide()
    end
end

function Bar:Refresh()
    if not self.frame then return end
    self:RefreshHunt()
    local p = Journey:GetProgress()

    if not p then
        self.fill:SetValue(0)
        self.text:SetText("Prey: waiting")
        return
    end
    if not p.unlocked then
        self.fill:SetValue(0)
        self.text:SetText("Prey: locked")
        return
    end

    local color = COLOR_LIVE
    if p.isMax and not p.paragon then
        color = COLOR_MAX
    elseif p.weeklyCapped then
        color = COLOR_CAPPED
    end
    self.fill:SetStatusBarColor(color[1], color[2], color[3])
    self.fill:SetValue(p.fraction)

    if p.isMax and not p.paragon then
        self.text:SetText(string.format("Prey %d  |  Max", p.level))
    elseif p.span > 0 then
        self.text:SetText(string.format("Prey %d  |  %d%%  |  %s to %d",
            p.level, math.floor(p.fraction * 100), formatNumber(p.remaining), p.level + 1))
    else
        self.text:SetText(string.format("Prey %d", p.level))
    end
end
