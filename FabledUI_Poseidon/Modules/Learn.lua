local P = _G.FabledUI_Poseidon
if not P then return end

P.Learn = P.Learn or {}
local L = P.Learn

local function RememberPool(name)
    if not P:LooksLikeFishingPool(name) then
        return
    end
    local mapID, x, y = P:GetCurrentMapPosition()
    P.State.lastPoolHover = name
    P.State.lastHoverTime = GetTime()
    P.State.lastPoolMapID = mapID
    P.State.lastPoolX = x
    P.State.lastPoolY = y
end

-- 12.x (Midnight) secret values: both UnitName and a tooltip line's GetText can
-- return a "secret string" when read from tainted addon code. The name flows into
-- RememberPool -> P.State.lastPoolHover and is later matched and used as a key,
-- so drop it rather than store a value that throws downstream.
local issecretvalue = _G.issecretvalue or function() return false end

local function CaptureTooltipName(tooltip)
    local name = nil
    if tooltip and tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        if unit then
            name = UnitName(unit)
        end
    end
    if not name and tooltip and tooltip.GetName then
        local tooltipName = tooltip:GetName()
        if tooltipName then
            local textRegion = _G[tooltipName .. "TextLeft1"]
            name = textRegion and textRegion:GetText() or nil
        end
    end
    if name and issecretvalue(name) then name = nil end
    RememberPool(name)
end

function L:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        if Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, CaptureTooltipName)
        end
        if Enum.TooltipDataType.Object then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, CaptureTooltipName)
        end
    end

    if GameTooltip and GameTooltip.HookScript and GameTooltip.HasScript and GameTooltip:HasScript("OnShow") then
        GameTooltip:HookScript("OnShow", function(tooltip)
            CaptureTooltipName(tooltip)
        end)
    end
end
