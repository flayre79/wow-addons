local M = _G.FabledUI_Crafty
M.History = M.History or {}
local H = M.History

local function pushLimited(list, entry, maxEntries)
    list[#list + 1] = entry
    while #list > maxEntries do
        table.remove(list, 1)
    end
end

function H:RecordAcquisition(kind, recipeID, quantity, character)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    pushLimited(M.db.history.acquisitions, {
        ts = time(),
        kind = kind,
        recipeID = recipeID,
        quantity = quantity,
        character = character,
    }, 200)
    M:MarkDirty()
    M:Fire('HistoryChanged')
end

function H:RecordCraft(eventRow)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    pushLimited(M.db.history.crafting, eventRow, 300)
    local todayKey = date('%Y-%m-%d')
    M.db.history.sessions[todayKey] = M.db.history.sessions[todayKey] or { crafts = 0, profit = 0, concentration = 0 }
    local s = M.db.history.sessions[todayKey]
    s.crafts = (s.crafts or 0) + (eventRow.crafts or 1)
    s.profit = (s.profit or 0) + (eventRow.profit or 0)
    s.concentration = (s.concentration or 0) + (eventRow.concentrationSpent or 0)
    M:MarkDirty()
    M:Fire('HistoryChanged')
    M:Fire('DataChanged')
end

function H:RecordPrice(itemID, price)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    M.db.history.prices[itemID] = price
    M:MarkDirty()
    M:Fire('HistoryChanged')
end

function H:GetRecentRows()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    local rows = {}
    for _, eventRow in ipairs(M.db.history.acquisitions or {}) do
        rows[#rows + 1] = eventRow
    end
    for _, eventRow in ipairs(M.db.history.crafting or {}) do
        rows[#rows + 1] = eventRow
    end
    table.sort(rows, function(a, b)
        return (a.ts or 0) > (b.ts or 0)
    end)
    local trimmed = {}
    for i = 1, math.min(30, #rows) do
        trimmed[#trimmed + 1] = rows[i]
    end
    return trimmed
end

function H:GetSessionSummary()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    local todayKey = date('%Y-%m-%d')
    local s = M.db.history.sessions[todayKey] or { crafts = 0, profit = 0, concentration = 0 }
    return s
end

function H:BuildCSV()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    local lines = { 'timestamp,event,recipeID,recipeName,quantity,character,profit,materials,saleValue,concentration' }
    for _, eventRow in ipairs(self:GetRecentRows()) do
        local recipe = M.Recipes:Get(eventRow.recipeID)
        local recipeName = eventRow.recipeName or (recipe and recipe.name) or ''
        lines[#lines + 1] = string.format('%d,%s,%s,"%s",%d,%s,%d,%d,%d,%d',
            eventRow.ts or 0,
            tostring(eventRow.kind or ''),
            tostring(eventRow.recipeID or ''),
            tostring(recipeName):gsub('"', '""'),
            tonumber(eventRow.quantity or eventRow.outputQuantity or eventRow.crafts or 0) or 0,
            tostring(eventRow.character or ''),
            tonumber(eventRow.profit or 0) or 0,
            tonumber(eventRow.actualMaterialCost or 0) or 0,
            tonumber(eventRow.saleValue or 0) or 0,
            tonumber(eventRow.concentrationSpent or 0) or 0
        )
    end
    return table.concat(lines, "\n")
end
