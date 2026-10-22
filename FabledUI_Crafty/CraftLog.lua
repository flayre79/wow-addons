local M = _G.FabledUI_Crafty
M.CraftLog = M.CraftLog or {}
local C = M.CraftLog

local UPDATE_DELAY = 0.12
local PROFIT_AH_CUT = 0.95

local pendingSpellID = nil
local pendingRecipeID = nil
local pendingCount = 0
local pendingResults = {}
local flushArmed = false

local function pushLimited(list, entry, maxEntries)
    list[#list + 1] = entry
    while #list > maxEntries do
        table.remove(list, 1)
    end
end

local function getRecipeIDForCraft()
    if pendingRecipeID then
        return pendingRecipeID
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetSelectedRecipeID then
        return C_TradeSkillUI.GetSelectedRecipeID()
    end
    return nil
end

local function getResultItemSnapshot(result)
    local hyperlink = result and result.hyperlink
    local itemID = nil
    if hyperlink and C_Item and C_Item.GetItemInfoInstant then
        itemID = select(1, C_Item.GetItemInfoInstant(hyperlink))
    elseif hyperlink and GetItemInfoInstant then
        itemID = select(1, GetItemInfoInstant(hyperlink))
    end
    return {
        itemID = itemID,
        hyperlink = hyperlink,
        quantity = tonumber(result and result.quantity) or 0,
        multicraft = tonumber(result and result.multicraft) or 0,
        quality = tonumber(result and result.craftingQuality) or 0,
    }
end

local function summarizeResourcesReturned(resultSet)
    local savedCost = 0
    local saved = {}
    for _, result in ipairs(resultSet) do
        for _, info in ipairs(result.resourcesReturned or {}) do
            local reagent = info.reagent or {}
            local itemID = reagent.itemID
            local quantity = tonumber(info.quantity) or 0
            if itemID and quantity > 0 then
                local value = (M.Profit and M.Profit:GetItemPrice(itemID) or 0) * quantity
                savedCost = savedCost + value
                saved[#saved + 1] = { itemID = itemID, quantity = quantity, value = value }
            end
        end
    end
    return savedCost, saved
end

local function buildCraftEvent(resultSet, craftsCount)
    local recipeID = tonumber(getRecipeIDForCraft())
    if not recipeID then
        return nil
    end
    local recipe = M.Recipes and M.Recipes:Get(recipeID) or nil
    local profitData = M.Profit and M.Profit:CalculateRecipe(recipeID) or nil
    local outputItems = {}
    local totalOutputQty = 0
    local saleValue = 0
    local multicraftTriggered = false
    local ingenuityTriggered = false
    local concentrationSpent = 0

    for _, result in ipairs(resultSet) do
        local snap = getResultItemSnapshot(result)
        if snap.itemID then
            outputItems[#outputItems + 1] = snap
            local q = (snap.quantity or 0)
            local extra = (snap.multicraft or 0)
            totalOutputQty = totalOutputQty + q
            if extra > 0 then
                multicraftTriggered = true
            end
            saleValue = saleValue + ((M.Profit and M.Profit:GetItemPrice(snap.itemID) or 0) * q * PROFIT_AH_CUT)
        end
        if result.hasIngenuityProc then
            ingenuityTriggered = true
        end
        concentrationSpent = concentrationSpent + (tonumber(result.concentrationSpent) or 0)
    end

    local savedCost, savedReagents = summarizeResourcesReturned(resultSet)
    local baseMatCost = profitData and (profitData.materialCost or 0) or 0
    local actualMatCost = math.max(0, baseMatCost - savedCost)
    local profit = saleValue - actualMatCost

    return {
        ts = time(),
        kind = 'craft',
        recipeID = recipeID,
        recipeName = recipe and recipe.name or ('Recipe ' .. tostring(recipeID)),
        profession = recipe and recipe.profession or nil,
        character = M:GetCurrentCharacterKey(),
        crafts = craftsCount or 1,
        outputQuantity = totalOutputQty,
        baseMaterialCost = baseMatCost,
        savedCost = savedCost,
        actualMaterialCost = actualMatCost,
        saleValue = saleValue,
        profit = profit,
        concentrationSpent = concentrationSpent,
        multicraftTriggered = multicraftTriggered,
        ingenuityTriggered = ingenuityTriggered,
        results = outputItems,
        savedReagents = savedReagents,
    }
end

function C:Flush()
    flushArmed = false
    local results = pendingResults
    pendingResults = {}
    local crafts = math.max(1, pendingCount)
    pendingCount = 0
    if #results == 0 then
        return
    end
    local eventRow = buildCraftEvent(results, crafts)
    if not eventRow then
        return
    end

    M.History:RecordCraft(eventRow)
    if M.settings and M.settings.autoDecrementQueueOnCraft ~= false and M.Queue then
        M.Queue:ChangeQuantity(eventRow.recipeID, nil, -crafts)
    end
end

function C:OnCraftBegin(spellID)
    spellID = tonumber(spellID)
    if pendingSpellID ~= spellID then
        pendingCount = 0
    end
    pendingSpellID = spellID
    if C_TradeSkillUI and C_TradeSkillUI.GetSelectedRecipeID then
        pendingRecipeID = tonumber(C_TradeSkillUI.GetSelectedRecipeID())
    end
end

function C:OnSpellcastSucceeded(unit, _, spellID)
    if unit ~= 'player' then
        return
    end
    if tonumber(spellID) == tonumber(pendingSpellID) then
        pendingCount = pendingCount + 1
    end
end

function C:OnCraftedResult(result)
    if M.settings and M.settings.activityCraftLogEnabled == false then
        return
    end
    pendingResults[#pendingResults + 1] = result
    if not flushArmed then
        flushArmed = true
        C_Timer.After(UPDATE_DELAY, function()
            C:Flush()
        end)
    end
end

function C:Init()
    if self._initialized then
        return
    end
    self._initialized = true
    self.frame = CreateFrame('Frame')
    self.frame:RegisterEvent('TRADE_SKILL_CRAFT_BEGIN')
    self.frame:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
    self.frame:RegisterEvent('TRADE_SKILL_ITEM_CRAFTED_RESULT')
    self.frame:SetScript('OnEvent', function(_, event, ...)
        if event == 'TRADE_SKILL_CRAFT_BEGIN' then
            C:OnCraftBegin(...)
        elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
            C:OnSpellcastSucceeded(...)
        elseif event == 'TRADE_SKILL_ITEM_CRAFTED_RESULT' then
            C:OnCraftedResult(...)
        end
    end)
end
