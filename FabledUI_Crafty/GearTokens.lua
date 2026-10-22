
local M = _G.FabledUI_Crafty
M.GearTokens = M.GearTokens or {}
local G = M.GearTokens

local classDisplay = {
    DEATHKNIGHT = "DK",
    DEMONHUNTER = "DH",
    DRUID = "Druid",
    EVOKER = "Evoker",
    HUNTER = "Hunter",
    MAGE = "Mage",
    MONK = "Monk",
    PALADIN = "Paladin",
    PRIEST = "Priest",
    ROGUE = "Rogue",
    SHAMAN = "Shaman",
    WARLOCK = "Warlock",
    WARRIOR = "Warrior",
}

local function getTooltipItemID(tt)
    local data = tt and tt.GetPrimaryTooltipData and tt:GetPrimaryTooltipData() or nil
    if not data then
        return nil
    end
    return data.id or (data.hyperlink and tonumber(string.match(data.hyperlink, "item:?(%d+):"))) or nil
end

function G:GetTokenInfo(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end
    -- TokenTooltipData lives in its own LoD shard (FabledUI_Crafty_Data_Tokens,
    -- ~5k LOC) — load on first use so a non-raider doesn't pay the parse cost.
    if not M.TokenTooltipData and M.EnsureFeatureShardLoaded then
        M:EnsureFeatureShardLoaded("Tokens")
    end
    return M.TokenTooltipData and M.TokenTooltipData[itemID] or nil
end

function G:IsEnabled()
    return M.settings.tokenTooltipDetailsEnabled ~= false
end

function G:IsEligibleForPlayer(info)
    if not info or not info.classes or #info.classes == 0 then
        return true
    end
    local _, classTag = UnitClass("player")
    for _, tokenClass in ipairs(info.classes) do
        if tokenClass == classTag then
            return true
        end
    end
    return false
end

function G:BuildTooltipLines(itemID)
    local info = self:GetTokenInfo(itemID)
    if not info then
        return nil
    end
    if M.settings.tokenTooltipOnlyForEligible == true and not self:IsEligibleForPlayer(info) then
        return nil
    end

    local lines = {
        string.format("Crafty token map: %s", info.raid or "Raid"),
    }

    if info.groups and #info.groups > 0 then
        lines[#lines + 1] = "Set family: " .. table.concat(info.groups, ", ")
    end
    if info.slots and #info.slots > 0 then
        lines[#lines + 1] = "Slots: " .. table.concat(info.slots, ", ")
    end
    if info.classes and #info.classes > 0 then
        local classParts = {}
        for _, tokenClass in ipairs(info.classes) do
            classParts[#classParts + 1] = classDisplay[tokenClass] or tokenClass
        end
        lines[#lines + 1] = "Classes: " .. table.concat(classParts, ", ")
    end
    if info.difficulties and #info.difficulties > 0 then
        lines[#lines + 1] = "Difficulties: " .. table.concat(info.difficulties, ", ")
    end

    lines[#lines + 1] = self:IsEligibleForPlayer(info) and "|cff5de0b5Eligible for your class|r" or "|cffd9b55fAlt token / other class family|r"
    return lines
end

local function addTooltipLines(tooltip)
    if not G:IsEnabled() then
        return
    end
    local itemID = getTooltipItemID(tooltip)
    if not itemID then
        return
    end
    local lines = G:BuildTooltipLines(itemID)
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
