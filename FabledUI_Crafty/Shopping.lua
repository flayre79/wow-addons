local M = _G.FabledUI_Crafty
M.Shopping = M.Shopping or {}
local S = M.Shopping

local function getInventoryCount(itemID)
    return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID, true)) or 0
end

function S:GetPlannerEngine(opts)
    opts = type(opts) == "table" and opts or {}
    if opts.engine then
        return opts.engine
    end
    if M.settings and M.settings.useCraftSimQueuePlanner then
        return "CraftSim-like"
    end
    return "Crafty"
end

function S:UsesRecursivePlanner(opts)
    return self:GetPlannerEngine(opts) == "CraftSim-like"
end

function S:GetProjectedProducedQuantity(itemID, queueEntries, pendingEntries)
    local total = 0
    itemID = tonumber(itemID)
    for _, entry in ipairs(queueEntries or {}) do
        local recipe = M.Recipes and M.Recipes:Get(entry.recipeID) or nil
        if recipe and tonumber(recipe.itemID) == itemID then
            total = total + (math.max(1, tonumber(recipe.outputQuantity) or 1) * (tonumber(entry.quantity) or 0))
        end
    end
    for _, entry in ipairs(pendingEntries or {}) do
        local recipe = M.Recipes and M.Recipes:Get(entry.recipeID) or nil
        if recipe and tonumber(recipe.itemID) == itemID then
            total = total + (math.max(1, tonumber(recipe.outputQuantity) or 1) * (tonumber(entry.quantity) or 0))
        end
    end
    return total
end

function S:BuildSubcraftEntries(recipe, quantity, character, queueEntries, visited, pendingEntries)
    pendingEntries = pendingEntries or {}
    visited = visited or {}
    if not recipe or type(recipe.materials) ~= "table" then
        return pendingEntries
    end

    local visitKey = string.format("%s:%s", tostring(recipe.recipeID), tostring(character or ""))
    if visited[visitKey] then
        return pendingEntries
    end
    visited[visitKey] = true

    queueEntries = queueEntries or (M.Queue and M.Queue.GetAll and M.Queue:GetAll()) or {}

    for _, mat in ipairs(recipe.materials or {}) do
        local producer = M.Recipes and M.Recipes.GetPrimaryProducerRecipe and M.Recipes:GetPrimaryProducerRecipe(mat.itemID, mat.profession) or nil
        if producer and tonumber(producer.recipeID) ~= tonumber(recipe.recipeID) then
            local required = (tonumber(mat.qty) or 0) * math.max(1, tonumber(quantity) or 1)
            local available = getInventoryCount(mat.itemID) + self:GetProjectedProducedQuantity(mat.itemID, queueEntries, pendingEntries)
            local shortage = math.max(0, required - available)
            if shortage > 0 then
                local output = math.max(1, tonumber(producer.outputQuantity) or 1)
                local craftsNeeded = math.max(1, math.ceil(shortage / output))
                pendingEntries[#pendingEntries + 1] = {
                    recipeID = producer.recipeID,
                    quantity = craftsNeeded,
                    character = character,
                    engine = "CraftSim-like",
                    _internal = true,
                    _skipSubcraft = true,
                }
                self:BuildSubcraftEntries(producer, craftsNeeded, character, queueEntries, visited, pendingEntries)
            end
        end
    end

    return pendingEntries
end

function S:BuildMaterialGraph(queueEntries, opts)
    local totals = {}
    queueEntries = queueEntries or (M.Queue and M.Queue.GetAll and M.Queue:GetAll()) or {}
    opts = type(opts) == "table" and opts or {}
    local recursive = opts.recursive
    if recursive == nil then
        recursive = self:UsesRecursivePlanner(opts)
    end

    local function addNeed(itemID, name, amount, source, profession, producerRecipeID)
        if not itemID then
            return
        end
        local row = totals[itemID]
        if not row then
            row = {
                itemID = itemID,
                name = name or ("Item " .. tostring(itemID)),
                need = 0,
                have = 0,
                queuedProduced = 0,
                shortage = 0,
                source = source,
                profession = profession,
                producerRecipeID = producerRecipeID,
            }
            totals[itemID] = row
        end
        row.need = row.need + (amount or 0)
        row.source = row.source or source
        row.profession = row.profession or profession
        row.producerRecipeID = row.producerRecipeID or producerRecipeID
    end

    -- Recursively walk a recipe's reagents. When recursive=true, any reagent that has
    -- a primary producer recipe expands into that producer's own reagents instead of
    -- being added as a "Crafted" leaf, until we bottom out at raw/vendor materials.
    local function expand(recipe, multiplier, visited)
        if not recipe or type(recipe.materials) ~= "table" then
            return
        end
        local key = tostring(recipe.recipeID or recipe.itemID or recipe)
        if visited[key] then
            return
        end
        visited[key] = true
        for _, mat in ipairs(recipe.materials) do
            local producer = M.Recipes and M.Recipes.GetPrimaryProducerRecipe and M.Recipes:GetPrimaryProducerRecipe(mat.itemID, mat.profession) or nil
            if recursive and producer and tonumber(producer.recipeID) ~= tonumber(recipe.recipeID) then
                local perCraftOutput = math.max(1, tonumber(producer.outputQuantity) or 1)
                local matNeed = (tonumber(mat.qty) or 0) * (multiplier or 0)
                local craftsNeeded = matNeed / perCraftOutput
                expand(producer, craftsNeeded, visited)
            else
                local source = mat.source
                local profession = mat.profession
                local producerRecipeID = nil
                if producer then
                    source = "Crafted"
                    profession = producer.profession
                    producerRecipeID = producer.recipeID
                end
                addNeed(mat.itemID, mat.name, (tonumber(mat.qty) or 0) * (multiplier or 0), source, profession, producerRecipeID)
            end
        end
        visited[key] = nil
    end

    for _, entry in ipairs(queueEntries) do
        local recipe = M.Recipes and M.Recipes:Get(entry.recipeID) or nil
        if recipe then
            expand(recipe, tonumber(entry.quantity) or 0, {})
        end
    end

    for _, row in pairs(totals) do
        row.have = getInventoryCount(row.itemID)
        row.queuedProduced = self:GetProjectedProducedQuantity(row.itemID, queueEntries)
        if not row.producerRecipeID and not recursive then
            local producer = M.Recipes and M.Recipes:GetPrimaryProducerRecipe(row.itemID, row.profession) or nil
            if producer then
                row.producerRecipeID = producer.recipeID
                row.profession = producer.profession
                row.source = "Crafted"
            end
        end
        row.shortage = math.max(0, (row.need or 0) - (row.have or 0) - (row.queuedProduced or 0))
    end

    return totals
end

function S:GetSummary(queueEntries, opts)
    local summary = {
        totalItems = 0,
        shortageItems = 0,
        totalNeed = 0,
        totalHave = 0,
        totalQueuedProduced = 0,
        totalShortage = 0,
    }
    for _, row in pairs(self:BuildMaterialGraph(queueEntries, opts)) do
        summary.totalItems = summary.totalItems + 1
        summary.totalNeed = summary.totalNeed + (row.need or 0)
        summary.totalHave = summary.totalHave + math.min((row.have or 0) + (row.queuedProduced or 0), row.need or 0)
        summary.totalQueuedProduced = summary.totalQueuedProduced + (row.queuedProduced or 0)
        summary.totalShortage = summary.totalShortage + (row.shortage or 0)
        if (row.shortage or 0) > 0 then
            summary.shortageItems = summary.shortageItems + 1
        end
    end
    return summary
end

function S:GetSortedRows(shortageOnly, queueEntries, opts)
    local rows = {}
    for _, row in pairs(self:BuildMaterialGraph(queueEntries, opts)) do
        if not shortageOnly or (row.shortage or 0) > 0 then
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        if (a.shortage or 0) ~= (b.shortage or 0) then
            return (a.shortage or 0) > (b.shortage or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    return rows
end

function S:BuildShoppingListText()
    local lines = { (M.settings and M.settings.shoppingListModePSL) and "Crafty Shopping List (PSL-compatible)" or "Crafty Shopping List" }
    for _, row in ipairs(self:GetSortedRows(true)) do
        local producer = row.producerRecipeID and M.Recipes:Get(row.producerRecipeID) or nil
        local sourceText = row.source or "Raw"
        if producer then
            sourceText = string.format("Craft via %s (%s)", producer.name or "recipe", producer.profession or "profession")
        end
        if M.settings and M.settings.shoppingListModePSL then
            lines[#lines + 1] = string.format("%s x%d  | have %d | queued %d | shortage %d | %s", row.name, row.need or 0, row.have or 0, row.queuedProduced or 0, row.shortage or 0, sourceText)
        else
            lines[#lines + 1] = string.format("%s,%d,%d,%d,%d,%s", row.name, row.have or 0, row.queuedProduced or 0, row.need or 0, row.shortage or 0, sourceText)
        end
    end
    if #lines == 1 then
        lines[#lines + 1] = "All queued materials are already covered."
    end
    return table.concat(lines, "\n")
end

return S
