local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Calendar
-- "Achievements earned per day."
--
-- GetAchievementInfo returns the earned date as month/day/year where year is
-- an offset from 2000, so the index normalises to a real year once and every
-- other surface reads the normalised value.
--
-- The index is rebuilt on ACHIEVEMENT_EARNED (through Refresh) rather than
-- cached forever, and stays cheap because it only touches earned achievements.
-- ============================================================================

local ROW_HEIGHT = 18
local YEAR_BASE = 2000

local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

local function MonthName(month)
    local localised = rawget(_G, "CALENDAR_FULLDATE_MONTH_NAMES")
    if type(localised) == "table" and localised[month] then return localised[month] end
    return MONTH_NAMES[month] or tostring(month)
end

-- year -> month -> day -> { ids }
function U:BuildEarnedIndex()
    K.Catalog:Build()
    local index, years = {}, {}

    for _, id in ipairs(K.Catalog.order) do
        local state = K.Catalog:GetState(id)
        if state and state.completed and state.year and state.year > 0 and state.month and state.day then
            local year = state.year < 100 and (YEAR_BASE + state.year) or state.year
            index[year] = index[year] or {}
            index[year][state.month] = index[year][state.month] or {}
            local bucket = index[year][state.month]
            bucket[state.day] = bucket[state.day] or {}
            local dayBucket = bucket[state.day]
            dayBucket[#dayBucket + 1] = id
        end
    end

    for year in pairs(index) do years[#years + 1] = year end
    table.sort(years, function(a, b) return a > b end)

    self._earnedIndex = index
    self._earnedYears = years
    return index, years
end

local function Builder(uiSelf, panel)
    panel.header = W:Label(panel, "", "GameFontNormalLarge")
    panel.header:SetPoint("TOP", panel, "TOP", 0, -6)

    panel.previous = W:Button(panel, "<", 28, 20, function()
        panel._month = (panel._month or 1) - 1
        if panel._month < 1 then
            panel._month = 12
            panel._year = (panel._year or 2026) - 1
        end
        panel._day = nil
        U:RenderTab("CALENDAR")
    end)
    panel.previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -4)

    panel.next = W:Button(panel, ">", 28, 20, function()
        panel._month = (panel._month or 1) + 1
        if panel._month > 12 then
            panel._month = 1
            panel._year = (panel._year or 2026) + 1
        end
        panel._day = nil
        U:RenderTab("CALENDAR")
    end)
    panel.next:SetPoint("LEFT", panel.previous, "RIGHT", 4, 0)

    panel.yearDrop = W:Dropdown(panel, { "" }, {}, function(key)
        panel._year = tonumber(key) or panel._year
        panel._day = nil
        U:RenderTab("CALENDAR")
    end, 90)
    panel.yearDrop:SetPoint("LEFT", panel.next, "RIGHT", 8, 0)

    local dayPanel = W:Panel(panel)
    dayPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -32)
    dayPanel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    dayPanel:SetWidth(230)
    panel.dayPanel = dayPanel

    local dayList = W:RowList(dayPanel, { rowHeight = ROW_HEIGHT, pageSize = 40, emptyText = K.L.NO_RESULTS or "Nothing earned." })
    dayList:SetPoint("TOPLEFT", 6, -6)
    dayList:SetPoint("BOTTOMRIGHT", -6, 6)
    panel.dayList = dayList

    dayList:SetRenderer(function(row, item)
        if not item then return end
        row.icon:SetTexture(nil)
        local selected = panel._day == item.day
        row.name:SetText((selected and "|cffffd100" or "|cffcccccc") .. ("%s %d"):format(MonthName(item.month), item.day) .. "|r")
        row.right:SetText(("%d"):format(item.count))
        row.star:SetText("")
        row:SetScript("OnClick", function()
            panel._day = item.day
            U:RenderTab("CALENDAR")
        end)
    end)

    local listPanel = W:Panel(panel)
    listPanel:SetPoint("TOPLEFT", dayPanel, "TOPRIGHT", 8, 0)
    listPanel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(330 + 8), 0)
    panel.listPanel = listPanel

    local list = W:RowList(listPanel, { rowHeight = 22, pageSize = 100, footer = true })
    list:SetPoint("TOPLEFT", 6, -6)
    list:SetPoint("BOTTOMRIGHT", -6, 6)
    panel.list = list
    panel.rows = list.rows
    panel.content = list.content

    list:SetRenderer(function(row, id)
        if not id then return end
        local entry = K.Catalog:GetEntry(id) or {}
        row.icon:SetTexture(entry.icon or nil)
        row.name:SetText("|cff00ff00" .. ((entry.name ~= "" and entry.name) or ("Ach " .. id)) .. "|r")
        row.right:SetText((entry.points or 0) > 0 and tostring(entry.points) or "")
        row.star:SetText(K:IsWatched(id) and "|TInterface\\Common\\FavoritesIcon:14|t" or "")
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if K.Menu then K.Menu:Show(id, panel) end
                return
            end
            panel._selected = id
            U:RenderDetail(panel, id)
        end)
    end)

    panel._filterHeight = 32
    U:BuildDetailPane(panel, 330)
end

local function Renderer(uiSelf, panel)
    if not panel or not panel.dayList then return end

    local index, years = U:BuildEarnedIndex()

    if not panel._year then
        panel._year = years[1]
        if not panel._year then
            local todayYear = select(1, K.Reminders.Today())
            panel._year = todayYear or YEAR_BASE
        end
    end
    if not panel._month then
        local months = index[panel._year] or {}
        local newest
        for month in pairs(months) do
            if not newest or month > newest then newest = month end
        end
        panel._month = newest or 1
    end

    local yearOptions, yearLabels = {}, {}
    for _, year in ipairs(years) do
        yearOptions[#yearOptions + 1] = tostring(year)
        yearLabels[tostring(year)] = tostring(year)
    end
    if #yearOptions == 0 then
        yearOptions = { tostring(panel._year) }
        yearLabels[tostring(panel._year)] = tostring(panel._year)
    end
    panel.yearDrop:SetOptions(yearOptions, yearLabels)
    panel.yearDrop:SetSelected(tostring(panel._year))

    local monthBucket = (index[panel._year] or {})[panel._month] or {}
    local dayRows, monthTotal = {}, 0
    for day, ids in pairs(monthBucket) do
        dayRows[#dayRows + 1] = { day = day, month = panel._month, count = #ids }
        monthTotal = monthTotal + #ids
    end
    table.sort(dayRows, function(a, b) return a.day < b.day end)
    panel.dayList:SetItems(dayRows)

    panel.header:SetText(("%s %d — %d %s"):format(MonthName(panel._month), panel._year, monthTotal, K.L.ACHIEVEMENTS or "achievements"))

    local ids = {}
    if panel._day and monthBucket[panel._day] then
        for _, id in ipairs(monthBucket[panel._day]) do ids[#ids + 1] = id end
    else
        for _, row in ipairs(dayRows) do
            for _, id in ipairs(monthBucket[row.day] or {}) do ids[#ids + 1] = id end
        end
    end

    panel.list:SetItems(ids, true)
    panel.rows = panel.list.rows

    if not panel._selected or #ids == 0 then panel._selected = ids[1] end
    U:RenderDetail(panel, panel._selected)
end

U.builders.CALENDAR = Builder
U.renderers.CALENDAR = Renderer
