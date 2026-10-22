
local M = _G.FabledUI_Crafty

M.API = M.API or {}
local API = M.API

local function getItemLink(itemLinkOrID)
    if type(itemLinkOrID) == "string" and itemLinkOrID:find("item:") then
        return itemLinkOrID
    end
    if tonumber(itemLinkOrID) and C_Item and C_Item.GetItemInfo then
        local _, link = C_Item.GetItemInfo(tonumber(itemLinkOrID))
        return link
    end
    return nil
end

function API:Toggle(forceShow)
    if M.UI then
        M.UI:Toggle(forceShow)
    end
end

function API:ToggleWindow(forceShow)
    return self:Toggle(forceShow)
end

function API:OpenToTab(tabKey)
    if M.UI then
        M.UI:OpenToTab(tabKey)
    end
end

function API:QueueRecipe(recipeID, quantity, character)
    if M.Queue then
        return M.Queue:Add(recipeID, quantity, character)
    end
    return false
end

function API:TrackRecipe(recipeID, recipeQuantity, recraft, orderID)
    if M.Queue then
        return M.Queue:TrackRecipe(recipeID, recipeQuantity, recraft, orderID)
    end
    return false
end

function API:UntrackRecipe(recipeID, recipeQuantity)
    if M.Queue then
        return M.Queue:UntrackRecipe(recipeID, recipeQuantity)
    end
    return false
end

function API:SwapCookingPet()
    return false
end

function API:IsAppearanceCollected(itemLinkOrID)
    local itemLink = getItemLink(itemLinkOrID)
    if not itemLink or not (C_TransmogCollection and C_TransmogCollection.GetItemInfo) then
        return false
    end
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    if sourceID and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
        return C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) and true or false
    end
    if appearanceID and C_TransmogCollection.PlayerHasTransmogByItemInfo then
        local ok, result = pcall(C_TransmogCollection.PlayerHasTransmogByItemInfo, itemLink)
        if ok then
            return result and true or false
        end
    end
    return false
end

function API:IsSourceCollected(itemLinkOrID)
    local itemLink = getItemLink(itemLinkOrID)
    if not itemLink or not (C_TransmogCollection and C_TransmogCollection.GetItemInfo) then
        return false
    end
    local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    if sourceID and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
        return C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) and true or false
    end
    return false
end

function API:GetShoppingListText()
    if M.Materials then
        return M.Materials:BuildShoppingListText()
    end
    return ""
end

function API:GetMaterialTotals()
    if M.Materials then
        return M.Materials:CalculateTotals()
    end
    return {}
end

function API:GetKnownBy(recipeID)
    if M.Recipes then
        local _, knownBy = M.Recipes:GetKnownByDisplay(recipeID)
        return knownBy or {}
    end
    return {}
end

function API:GetPrimaryProducerRecipe(itemID, professionFilter)
    if M.Recipes then
        return M.Recipes:GetPrimaryProducerRecipe(itemID, professionFilter)
    end
    return nil
end

function API:GetBestCrafterForRecipe(recipe)
    if M.Alts then
        return M.Alts:GetBestCrafterForRecipe(recipe)
    end
    return nil
end

function API:GetKnowledgeRows()
    return M.Knowledge and M.Knowledge:GetRows() or {}
end

function API:GetGuideRows()
    local rows = {}
    local status = ""
    if M.Training then
        rows, status = M.Training:GetRows()
    end
    return rows, status
end

_G.FabledUI_CraftyAPI = API


function API:GetLumberBreakdown()
    return M.Lumber and M.Lumber:GetLumberBreakdown() or {}
end

function API:GetItemExpansionName(itemID)
    if M.ItemMetadata then
        local expansionID = M.ItemMetadata:GetItemExpansionID(itemID)
        return M.ItemMetadata:GetExpansionName(expansionID), expansionID
    end
    return nil, nil
end

function API:GetProfessionAssistance(itemID)
    return M.Assistance and M.Assistance:GetTooltipData(itemID) or nil
end


function API:GetCooldownRows()
    return M.Cooldowns and M.Cooldowns:GetRows() or {}
end

function API:GetCraftLogRows()
    return M.History and M.History:GetRecentRows() or {}
end

function API:GetGearSummary(characterKey, professionName)
    return M.Gear and M.Gear:GetProfessionGear(characterKey, professionName) or nil
end

function API:GetSpecializationSummary(characterKey, professionName)
    return M.Specs and M.Specs:GetSnapshot(characterKey, professionName) or nil
end

function API:GetTimerRows()
    return M.Timers and M.Timers:GetRows() or {}
end

function API:GetGearingRows()
    return M.GearingOverview and M.GearingOverview:GetRows() or {}
end
