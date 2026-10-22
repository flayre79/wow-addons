local M = _G.FabledUI_Crafty
M.Knowledge = M.Knowledge or {}
local K = M.Knowledge

local CATEGORY_ORDER = {
    "WeeklyQuest",
    "Treatise",
    "DarkmoonQuest",
    "CatchUp",
    "Treasure",
    "Unique",
    "Gathering",
    "OneTime",
    "FirstCraft",
}

local CATEGORY_LABELS = {
    WeeklyQuest = "Weekly Quest",
    Treatise = "Treatise",
    DarkmoonQuest = "Darkmoon",
    CatchUp = "Catch-Up",
    Treasure = "Treasure",
    Unique = "Unique",
    Gathering = "Gathering",
    OneTime = "One-Time Treasure",
    FirstCraft = "First Craft",
}

local function includeCategory(category)
    if category == "FirstCraft" then
        return M.settings.knowledgeShowFirstCraft == true
    elseif category == "Unique" then
        return M.settings.knowledgeShowUnique ~= false
    elseif category == "Treasure" then
        return M.settings.knowledgeShowTreasure ~= false
    elseif category == "Gathering" then
        return M.settings.knowledgeShowGathering ~= false
    elseif category == "OneTime" then
        return M.settings.knowledgeShowTreasure ~= false
    end
    return M.settings.knowledgeShowWeekly ~= false
end

local function sortRows(a, b)
    local aProf = a.profession or ""
    local bProf = b.profession or ""
    if aProf ~= bProf then
        return aProf < bProf
    end
    local aExp = a.expansion or ""
    local bExp = b.expansion or ""
    if aExp ~= bExp then
        return aExp < bExp
    end
    local ao, bo = 999, 999
    for index, category in ipairs(CATEGORY_ORDER) do
        if a.category == category then
            ao = index
        end
        if b.category == category then
            bo = index
        end
    end
    if ao ~= bo then
        return ao < bo
    end
    if (a.points or 0) ~= (b.points or 0) then
        return (a.points or 0) > (b.points or 0)
    end
    return (a.itemID or 0) < (b.itemID or 0)
end

function K:GetAllKnowledgeSources()
    local sources = {}
    -- M.KnowledgeData carries per-profession trees ({ [prof] = { [exp] = { entries } } })
    -- alongside flat namespace tables (MidnightTreasures, MidnightTreasureZones)
    -- whose values are not iterable. Skip those keys + tolerate stray non-table
    -- values so a load-order quirk can't throw the Knowledge tab.
    for prof, expansions in pairs(M.KnowledgeData or {}) do
        if prof ~= "MidnightTreasures" and prof ~= "MidnightTreasureZones"
            and type(expansions) == "table"
        then
            for _, entries in pairs(expansions) do
                if type(entries) == "table" then
                    for _, entry in ipairs(entries) do
                        sources[#sources + 1] = entry
                    end
                end
            end
        end
    end
    if M.Lumber and M.Lumber.GetKnowledgeRows then
        local extra = M.Lumber:GetKnowledgeRows()
        for _, row in ipairs(extra) do
            sources[#sources + 1] = row
        end
    end
    return sources
end

function K:GetProfessionExpansionRows()
    local out = {}
    local summaryMap = {}

    for _, row in ipairs(self:GetAllKnowledgeSources()) do
        if includeCategory(row.category) then
            local profession = row.profession or "Profession"
            local expansion = row.expansion or "Expansion"
            local key = profession .. "||" .. expansion
            local summary = summaryMap[key]
            if not summary then
                summary = {
                    profession = profession,
                    expansion = expansion,
                    total = 0,
                    points = 0,
                    categories = {},
                }
                summaryMap[key] = summary
                out[#out + 1] = summary
            end
            summary.categories[row.category] = (summary.categories[row.category] or 0) + 1
            summary.total = summary.total + 1
            summary.points = summary.points + (row.points or 0)
        end
    end

    table.sort(out, function(a, b)
        if a.profession ~= b.profession then
            return a.profession < b.profession
        end
        return a.expansion < b.expansion
    end)
    return out
end

function K:GetRows()
    local rows = {}
    local filterProfession = M.filters and M.filters.profession or "ALL"
    local filterExpansion = M.filters and M.filters.expansion or "ALL"

    for _, entry in ipairs(self:GetAllKnowledgeSources()) do
        if (filterProfession == "ALL" or filterProfession == entry.profession) and (filterExpansion == "ALL" or filterExpansion == entry.expansion) then
            if includeCategory(entry.category) then
                rows[#rows + 1] = entry
            end
        end
    end

    table.sort(rows, sortRows)
    return rows
end


function K:GetSummary(professionFilter, expansionFilter)
    professionFilter = professionFilter or (M.filters and M.filters.profession) or "ALL"
    expansionFilter = expansionFilter or (M.filters and M.filters.expansion) or "ALL"
    local summary = {
        profession = professionFilter,
        expansion = expansionFilter,
        totalRows = 0,
        totalPoints = 0,
        byCategory = {},
    }
    for _, row in ipairs(self:GetRows()) do
        if (professionFilter == "ALL" or row.profession == professionFilter) and (expansionFilter == "ALL" or row.expansion == expansionFilter) then
            summary.totalRows = summary.totalRows + 1
            summary.totalPoints = summary.totalPoints + (row.points or 0)
            summary.byCategory[row.category or "Unknown"] = (summary.byCategory[row.category or "Unknown"] or 0) + 1
        end
    end
    return summary
end

function K:GetSummaryHeadline(summary)
    summary = summary or self:GetSummary()
    local bits = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        local count = summary.byCategory and summary.byCategory[category] or 0
        if count and count > 0 then
            bits[#bits + 1] = string.format("%s %d", CATEGORY_LABELS[category] or category, count)
        end
    end
    if #bits == 0 then
        return "No checklist rows match the current filters."
    end
    return table.concat(bits, "  |  ")
end

function K:GetSummaryText(summary)
    local parts = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        if summary.categories[category] then
            parts[#parts + 1] = string.format("%s %d", CATEGORY_LABELS[category] or category, summary.categories[category])
        end
    end
    return table.concat(parts, "  |  ")
end

function K:GetLabel(category)
    return CATEGORY_LABELS[category] or category or "Knowledge"
end

function K:SetWaypoint(row)
    if not row then
        return false
    end
    if not row.mapID or not row.x or not row.y then
        return false
    end

    local label = string.format("%s %s", row.profession or "Profession", self:GetLabel(row.category))
    local nx, ny = (row.x or 0) / 100, (row.y or 0) / 100

    -- Try suite waypoint addons first (Odyssey).
    local suiteWaypointAddons = {
        _G.FlayreDev_Odyssey,
        _G.FabledUI_Odyssey,
    }
    for _, addonTable in ipairs(suiteWaypointAddons) do
        if type(addonTable) == "table" and type(addonTable.SetWaypoint) == "function" then
            addonTable:SetWaypoint(nx, ny, row.mapID, { title = label })
            return true
        end
    end

    -- Fallback to native Blizzard waypoint
    if C_Map and C_Map.SetUserWaypoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(row.mapID, nx, ny))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        return true
    end

    -- Last resort: TomTom
    if TomTom and type(TomTom.AddWaypoint) == "function" then
        TomTom:AddWaypoint(row.mapID, nx, ny, { title = label })
        return true
    end

    return false
end

function K:BuildTooltipLines(row)
    local lines = {
        string.format("%s · %s", row.profession or "Profession", row.expansion or "Expansion"),
        string.format("%s · %d point(s)", self:GetLabel(row.category), row.points or 0),
    }
    if row.limit and row.limit > 0 then
        lines[#lines + 1] = string.format("Weekly limit: %d", row.limit)
    end
    if row.itemID and row.itemID > 0 then
        lines[#lines + 1] = string.format("Item ID: %d", row.itemID)
    end
    if row.hint and row.hint ~= "" then
        lines[#lines + 1] = row.hint
    end
    if row.location and row.location ~= "" then
        lines[#lines + 1] = "Location: " .. row.location
    end
    if row.mapID and row.x and row.y then
        lines[#lines + 1] = string.format("Coords: %.1f, %.1f (map %d)", row.x or 0, row.y or 0, row.mapID or 0)
    end
    if row.quests and #row.quests > 0 then
        lines[#lines + 1] = "Quest IDs: " .. table.concat(row.quests, ", ")
    end
    return lines
end
