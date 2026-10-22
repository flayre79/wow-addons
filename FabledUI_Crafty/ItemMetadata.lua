local M = _G.FabledUI_Crafty
M.ItemMetadata = M.ItemMetadata or {}
local IM = M.ItemMetadata

local EXPANSION_NAMES = {
    [0] = "Classic",
    [1] = "The Burning Crusade",
    [2] = "Wrath of the Lich King",
    [3] = "Cataclysm",
    [4] = "Mists of Pandaria",
    [5] = "Warlords of Draenor",
    [6] = "Legion",
    [7] = "Battle for Azeroth",
    [8] = "Shadowlands",
    [9] = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
}

local EXPANSION_COLORS = {
    [0] = "F4BF2A",
    [1] = "CBD86C",
    [2] = "9DC6E5",
    [3] = "8E3C14",
    [4] = "5FB177",
    [5] = "D77500",
    [6] = "D9E342",
    [7] = "C4C6C5",
    [8] = "F9F8F6",
    [9] = "B6B6BA",
    [10] = "EA551F",
    [11] = "5C1FEA",
}

local function getTooltipItemID(tt)
    local data = tt and tt.GetPrimaryTooltipData and tt:GetPrimaryTooltipData() or nil
    if not data then
        return nil
    end
    return data.id or (data.hyperlink and tonumber(string.match(data.hyperlink, "item:?(%d+):"))) or nil
end

function IM:GetExpansionName(expansionID)
    return EXPANSION_NAMES[tonumber(expansionID or -1)]
end

function IM:GetColoredExpansionText(expansionID)
    local name = self:GetExpansionName(expansionID)
    if not name then
        return nil
    end
    local color = EXPANSION_COLORS[tonumber(expansionID or -1)] or "FFFFFF"
    return string.format("|cff%s%s|r", color, name)
end

function IM:GetItemExpansionID(itemID)
    if not itemID then
        return nil
    end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, expacID = C_Item.GetItemInfo(itemID)
    return expacID
end

function IM:BuildTooltipLines(itemID)
    local lines = {}
    if M.settings.tooltipExpansionInfoEnabled ~= false then
        local expacID = self:GetItemExpansionID(itemID)
        local expansionText = self:GetColoredExpansionText(expacID)
        if expansionText then
            lines[#lines + 1] = "Crafty era: " .. expansionText
        end
    end
    return (#lines > 0) and lines or nil
end

local function addTooltipLines(tooltip)
    local itemID = getTooltipItemID(tooltip)
    if not itemID then
        return
    end
    local lines = IM:BuildTooltipLines(itemID)
    if not lines then
        return
    end
    tooltip:AddLine(" ")
    for _, line in ipairs(lines) do
        tooltip:AddLine(line)
    end
    tooltip:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and not M.USE_UNIFIED_TOOLTIP_COMPOSER then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addTooltipLines)
end

return IM
