local M = _G.FabledUI_Crafty
M.Lumber = M.Lumber or {}
local L = M.Lumber
local D = M.LumberData or {}

function L:GetCategories()
    return D.categories or {}
end

function L:GetLumberBreakdown()
    local rows = {}
    for _, category in ipairs(self:GetCategories()) do
        local count = 0
        for _, itemID in ipairs(category.items or {}) do
            count = count + (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID, true) or 0)
        end
        rows[#rows + 1] = {
            name = category.name,
            items = category.items or {},
            count = count,
        }
    end
    return rows
end

function L:GetTotalLumberCount()
    local total = 0
    for _, row in ipairs(self:GetLumberBreakdown()) do
        total = total + (row.count or 0)
    end
    return total
end

function L:GetTopBreakdownLine(limit)
    limit = tonumber(limit) or 3
    local rows = self:GetLumberBreakdown()
    table.sort(rows, function(a, b)
        if a.count ~= b.count then
            return (a.count or 0) > (b.count or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    local parts = {}
    for _, row in ipairs(rows) do
        if (row.count or 0) > 0 then
            parts[#parts + 1] = string.format("%s %d", row.name or "Lumber", row.count or 0)
            if #parts >= limit then
                break
            end
        end
    end
    if #parts == 0 then
        return "No lumber tracked yet."
    end
    return table.concat(parts, "  |  ")
end

local function normalizeKnowledgeKey(name)
    local key = string.lower(name or "")
    key = key:gsub("%*", "")
    key = key:gsub("[^%w%s\']+", "")
    key = key:gsub("%s+", " ")
    key = key:gsub("^%s+", "")
    key = key:gsub("%s+$", "")
    return key
end

-- HousingLumberHelper: per-zone yield/hour reporting backed by
-- M.db.lumberByZone (populated by FarmSession). Returns the top N zones
-- ordered by yield-per-hour, falling back to total count when sessionTime
-- is missing.
function L:GetBestZones(limit)
    limit = tonumber(limit) or 5
    local rows = {}
    if not M.db or type(M.db.lumberByZone) ~= "table" then
        return rows
    end
    for mapID, data in pairs(M.db.lumberByZone) do
        if type(data) == "table" and (data.count or 0) > 0 then
            local sessionTime = math.max(1, tonumber(data.sessionTime) or 0)
            local hours = sessionTime / 3600
            local rate = hours > 0 and (data.count / hours) or data.count
            local zoneName = "Unknown zone"
            if C_Map and C_Map.GetMapInfo then
                local info = C_Map.GetMapInfo(mapID)
                if info and info.name then zoneName = info.name end
            end
            rows[#rows + 1] = {
                mapID = mapID,
                zoneName = zoneName,
                count = data.count or 0,
                sessionTime = sessionTime,
                ratePerHour = math.floor(rate + 0.5),
                lastSeen = data.lastSeen or 0,
            }
        end
    end
    table.sort(rows, function(a, b)
        if (a.ratePerHour or 0) ~= (b.ratePerHour or 0) then
            return (a.ratePerHour or 0) > (b.ratePerHour or 0)
        end
        return (a.count or 0) > (b.count or 0)
    end)
    while #rows > limit do
        table.remove(rows, #rows)
    end
    return rows
end

-- HousingLumberHelper: include bank stockpiles when "Scan warband bank"
-- setting is enabled. Returns 0 when the setting is off.
function L:GetBankLumberCount()
    if M.settings and M.settings.farmScanWarbandBank == false then
        return 0
    end
    if not M.db or type(M.db.lumberBank) ~= "table" then
        return 0
    end
    local total = 0
    for _, count in pairs(M.db.lumberBank) do
        total = total + (tonumber(count) or 0)
    end
    return total
end

function L:GetKnowledgeRows()
    local rows = {}
    for profession, entries in pairs(D.oneTimeKnowledge or {}) do
        for _, entry in ipairs(entries) do
            local key = normalizeKnowledgeKey(entry.name or "")
            local detail = (D.knowledgeDetails and D.knowledgeDetails[key]) or nil
            rows[#rows + 1] = {
                profession = profession,
                expansion = "Midnight",
                category = "OneTime",
                points = 1,
                itemID = 0,
                hint = entry.name or "One-Time Knowledge",
                mapID = detail and detail.mapID or nil,
                x = detail and detail.x or nil,
                y = detail and detail.y or nil,
                location = detail and detail.location or nil,
                label = detail and detail.label or entry.name or "Knowledge",
                quests = entry.questID and { entry.questID } or nil,
                limit = 1,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.profession ~= b.profession then
            return a.profession < b.profession
        end
        return (a.hint or "") < (b.hint or "")
    end)
    return rows
end

return L
