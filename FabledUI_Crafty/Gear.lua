local M = _G.FabledUI_Crafty
M.Gear = M.Gear or {}
local G = M.Gear

local PROF_ENUM_BY_NAME = {
    Alchemy = Enum and Enum.Profession and Enum.Profession.Alchemy,
    Blacksmithing = Enum and Enum.Profession and Enum.Profession.Blacksmithing,
    Enchanting = Enum and Enum.Profession and Enum.Profession.Enchanting,
    Engineering = Enum and Enum.Profession and Enum.Profession.Engineering,
    Herbalism = Enum and Enum.Profession and Enum.Profession.Herbalism,
    Inscription = Enum and Enum.Profession and Enum.Profession.Inscription,
    Jewelcrafting = Enum and Enum.Profession and Enum.Profession.Jewelcrafting,
    Leatherworking = Enum and Enum.Profession and Enum.Profession.Leatherworking,
    Mining = Enum and Enum.Profession and Enum.Profession.Mining,
    Skinning = Enum and Enum.Profession and Enum.Profession.Skinning,
    Tailoring = Enum and Enum.Profession and Enum.Profession.Tailoring,
    Cooking = Enum and Enum.Profession and Enum.Profession.Cooking,
    Fishing = Enum and Enum.Profession and Enum.Profession.Fishing,
}

local function ensureAlt(characterKey, professionName)
    local char = M.Alts and M.Alts:GetCharacterData(characterKey)
    if not char then
        M.Alts:RegisterCurrentCharacter()
        char = M.Alts and M.Alts:GetCharacterData(characterKey)
    end
    char.professions = type(char.professions) == 'table' and char.professions or {}
    char.professions[professionName] = type(char.professions[professionName]) == 'table' and char.professions[professionName] or {}
    return char.professions[professionName]
end

local function getTooltipSkillBonus(itemLink, professionName)
    if not itemLink or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return 0
    end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, itemLink)
    if not ok or type(data) ~= 'table' then
        return 0
    end
    local best = 0
    for _, line in ipairs(data.lines or {}) do
        local text = line.leftText
        if type(text) == 'string' and text:find('Skill') then
            local value = tonumber(text:match('%+(%d+)')) or 0
            if value > 0 then
                if not professionName or text:find(professionName) or text:find('Profession') or text:find('Crafting') then
                    best = math.max(best, value)
                end
            end
        end
    end
    return best
end

local function buildItemSnapshot(itemLink, professionName)
    if not itemLink then
        return nil
    end

    local itemID = nil
    local quality = nil
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, itemQuality, _, _, _, _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
        itemID = select(1, C_Item.GetItemInfoInstant(itemLink))
        quality = itemQuality
    elseif GetItemInfoInstant then
        itemID = select(1, GetItemInfoInstant(itemLink))
    end

    local name = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemLink)) or itemLink
    local itemLevel = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(itemLink) or nil
    local stats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)) or {}

    return {
        itemLink = itemLink,
        itemID = itemID,
        name = name,
        quality = quality,
        itemLevel = itemLevel,
        skill = getTooltipSkillBonus(itemLink, professionName),
        multicraft = tonumber(stats.ITEM_MOD_MULTICRAFT_SHORT) or 0,
        resourcefulness = tonumber(stats.ITEM_MOD_RESOURCEFULNESS_SHORT) or 0,
        ingenuity = tonumber(stats.ITEM_MOD_INGENUITY_SHORT) or 0,
        craftingspeed = tonumber(stats.ITEM_MOD_CRAFTING_SPEED_SHORT) or 0,
    }
end

local function sumItemStats(items)
    local total = {
        skill = 0,
        multicraft = 0,
        resourcefulness = 0,
        ingenuity = 0,
        craftingspeed = 0,
        score = 0,
    }
    for _, item in ipairs(items or {}) do
        if item then
            total.skill = total.skill + (item.skill or 0)
            total.multicraft = total.multicraft + (item.multicraft or 0)
            total.resourcefulness = total.resourcefulness + (item.resourcefulness or 0)
            total.ingenuity = total.ingenuity + (item.ingenuity or 0)
            total.craftingspeed = total.craftingspeed + (item.craftingspeed or 0)
        end
    end
    total.score = total.skill + total.multicraft + total.resourcefulness + total.ingenuity + total.craftingspeed
    return total
end

function G:GetProfessionEnum(professionName)
    return PROF_ENUM_BY_NAME[professionName]
end

function G:ScanOpenProfessionGear(markDirty)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetTradeSkillLine then
        return nil
    end
    local context = M.Concentration and M.Concentration:GetOpenProfessionContext() or nil
    if not context or not context.professionName then
        return nil
    end
    local professionEnum = context.professionEnum or self:GetProfessionEnum(context.professionName)
    if not professionEnum or not C_TradeSkillUI.GetProfessionSlots then
        return nil
    end

    local characterKey = M:GetCurrentCharacterKey()
    local prof = ensureAlt(characterKey, context.professionName)
    local slots = { C_TradeSkillUI.GetProfessionSlots(professionEnum) }
    local items = {}
    for index, inventorySlot in ipairs(slots) do
        if inventorySlot then
            items[index] = buildItemSnapshot(GetInventoryItemLink('player', inventorySlot), context.professionName)
        end
    end

    prof.gear = {
        professionEnum = professionEnum,
        professionName = context.professionName,
        slots = slots,
        items = items,
        totals = sumItemStats(items),
        lastScanned = time(),
    }

    if markDirty then
        M:MarkDirty()
        M:Fire('AltDataChanged')
        M:Fire('DataChanged')
    end

    return prof.gear
end

function G:GetProfessionGear(characterKey, professionName)
    local char = M.Alts and M.Alts:GetCharacterData(characterKey)
    local prof = char and char.professions and char.professions[professionName]
    return prof and prof.gear or nil
end

function G:GetTotals(characterKey, professionName)
    local gear = self:GetProfessionGear(characterKey, professionName)
    return gear and gear.totals or nil
end

function G:DescribeTotals(totals)
    if not totals then
        return 'No profession gear snapshot'
    end
    local parts = {}
    if (totals.skill or 0) > 0 then
        parts[#parts + 1] = string.format('Skill +%d', totals.skill)
    end
    if (totals.multicraft or 0) > 0 then
        parts[#parts + 1] = string.format('MC %d', totals.multicraft)
    end
    if (totals.resourcefulness or 0) > 0 then
        parts[#parts + 1] = string.format('RF %d', totals.resourcefulness)
    end
    if (totals.ingenuity or 0) > 0 then
        parts[#parts + 1] = string.format('IG %d', totals.ingenuity)
    end
    if (totals.craftingspeed or 0) > 0 then
        parts[#parts + 1] = string.format('SP %d', totals.craftingspeed)
    end
    return (#parts > 0) and table.concat(parts, ' · ') or 'No statted profession gear detected'
end

function G:GetTooltipLines(characterKey, professionName)
    local gear = self:GetProfessionGear(characterKey, professionName)
    if not gear then
        return { 'No profession gear snapshot.' }
    end
    local lines = { self:DescribeTotals(gear.totals) }
    for index, item in ipairs(gear.items or {}) do
        if item then
            lines[#lines + 1] = string.format('Slot %d: %s%s', index, item.name or ('Item ' .. tostring(item.itemID or '?')), item.itemLevel and (' · ilvl ' .. tostring(item.itemLevel)) or '')
        else
            lines[#lines + 1] = string.format('Slot %d: empty', index)
        end
    end
    return lines
end
