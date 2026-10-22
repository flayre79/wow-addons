local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Browse
-- The list panel behind five tabs: Browse (whole catalog), Watch, Tracked,
-- Excluded and Specials/Zone. They differ only in where the id list comes
-- from, so they share one builder and one renderer and select behaviour off
-- `mode`.
--
-- Filters live in the active storage profile, so switching profile switches
-- every dropdown at once.
-- ============================================================================

local SIDEBAR_WIDTH = 196
local DETAIL_WIDTH = 330
local FILTER_ROW_HEIGHT = 26

local COMPLETION_ORDER = { "ALL", "COMPLETE", "INCOMPLETE" }
local SATURATION_ORDER = { "MIXED", "ACCOUNT", "CHARACTER" }
local FACTION_ORDER = { "ALL", "ALLIANCE", "HORDE", "NEUTRAL" }
local OBTAINABLE_ORDER = { "ALL", "OBTAINABLE", "UNOBTAINABLE" }

local function Labels(keys, prefix)
    local labels = {}
    for _, key in ipairs(keys) do
        labels[key] = (prefix and prefix ~= "") and ((K.L[prefix] or prefix) .. ": " .. (K.L[key] or key)) or (K.L[key] or key)
    end
    return labels
end

local function RewardOrder()
    local order = { "ALL", "ANY", "NONE" }
    for _, typeKey in ipairs(K.Rewards.TYPES) do order[#order + 1] = typeKey end
    return order
end

local function ExpansionOrder()
    local order = { "ALL" }
    local available = K.Catalog:AvailableExpansions()
    if #available == 0 then
        -- Nothing classified yet (fresh client, or the sim's stub category
        -- tree): offer the full list rather than an empty dropdown.
        available = K.Data.EXPANSION_ORDER
    end
    for _, key in ipairs(available) do order[#order + 1] = key end
    return order
end

local function ExpansionLabels(order)
    local labels = { ALL = K.L.ALL_EXPANSIONS or "All Expansions" }
    for _, key in ipairs(order) do
        labels[key] = K.Data.EXPANSION_KEY_TO_FULLNAME[key] or key
    end
    return labels
end

local function KindOrder()
    local order = { "ALL" }
    for _, key in ipairs(K.Data.KIND_ORDER) do order[#order + 1] = key end
    return order
end

-- ----------------------------------------------------------------------------
-- Sources
-- ----------------------------------------------------------------------------
local function SortedKeys(map)
    local ids = {}
    for id, value in pairs(map or {}) do
        local numeric = tonumber(id)
        if value and numeric then ids[#ids + 1] = numeric end
    end
    table.sort(ids)
    return ids
end

local function TrackedIDs()
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs and Enum and Enum.ContentTrackingType then
        local ok, ids = pcall(C_ContentTracking.GetTrackedIDs, Enum.ContentTrackingType.Achievement)
        if ok and type(ids) == "table" then
            local numeric = {}
            for _, id in ipairs(ids) do
                local value = tonumber(id)
                if value then numeric[#numeric + 1] = value end
            end
            return numeric
        end
    end
    -- Older clients exposed a flat getter instead.
    if type(rawget(_G, "GetTrackedAchievements")) == "function" then
        local ok, a, b, c, d, e = pcall(_G.GetTrackedAchievements)
        if ok then
            local ids = {}
            for _, id in ipairs({ a, b, c, d, e }) do
                local value = tonumber(id)
                if value then ids[#ids + 1] = value end
            end
            return ids
        end
    end
    return {}
end

U.TrackedIDs = TrackedIDs

local function CuratedIDs()
    -- Recompute the derived lists (nearly done / recently earned) so the tab is
    -- never showing yesterday's progress.
    K.Data:RefreshDynamicLists()
    local ids = {}
    for _, id in ipairs(K.Data.CURATED) do ids[#ids + 1] = id end
    return ids
end

local function SourceForMode(mode)
    if mode == "WATCH" then return SortedKeys(K.db and K.db.watchlist), true end
    if mode == "EXCLUDED" then return SortedKeys(K.db and K.db.excluded), true end
    if mode == "TRACKED" then return TrackedIDs(), true end
    if mode == "CURATED" then return CuratedIDs(), true end
    if mode == "ZONE" then return K.Data._zoneResults or {}, true end
    return nil, false
end

U.SourceForMode = SourceForMode

-- ----------------------------------------------------------------------------
-- Builder
-- ----------------------------------------------------------------------------
local function BuildFilters(panel, mode)
    local filters = U.Filters()
    local showSidebar = mode == "ALL"

    local search = W:SearchBox(panel, 190, function(text)
        filters.search = text
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -2)
    if filters.search and filters.search ~= "" then search:SetText(filters.search) end
    panel.search = search

    local expansionOrder = ExpansionOrder()
    local expansion = W:Dropdown(panel, expansionOrder, ExpansionLabels(expansionOrder), function(key)
        filters.expansion = key
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end, 150)
    expansion:SetPoint("LEFT", search, "RIGHT", 8, 0)
    expansion:SetSelected(filters.expansion or "ALL")
    panel.expansionDrop = expansion

    local kindOrder = KindOrder()
    local kind = W:Dropdown(panel, kindOrder, Labels(kindOrder, "TYPE"), function(key)
        filters.kind = key
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end, 140)
    kind:SetPoint("LEFT", expansion, "RIGHT", 6, 0)
    kind:SetSelected(filters.kind or "ALL")
    panel.kindDrop = kind

    local sort = W:Dropdown(panel, K.Catalog.SORT_KEYS, Labels(K.Catalog.SORT_KEYS, "SORT"), function(key)
        filters.sort = key
        U:RenderTab(panel._tabKey)
    end, 140)
    sort:SetPoint("LEFT", kind, "RIGHT", 6, 0)
    sort:SetSelected(filters.sort or "NAME")
    panel.sortDrop = sort

    local completion = W:Dropdown(panel, COMPLETION_ORDER, Labels(COMPLETION_ORDER), function(key)
        filters.completion = key
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end, 120)
    completion:SetPoint("LEFT", sort, "RIGHT", 6, 0)
    completion:SetSelected(filters.completion or "ALL")
    panel.completionDrop = completion

    -- Second row
    local rewardOrder = RewardOrder()
    local reward = W:Dropdown(panel, rewardOrder, Labels(rewardOrder, "REWARD"), function(key)
        filters.reward = key
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end, 170)
    reward:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -6)
    reward:SetSelected(filters.reward or "ALL")
    panel.rewardDrop = reward

    local faction = W:Dropdown(panel, FACTION_ORDER, Labels(FACTION_ORDER, "FACTION"), function(key)
        filters.faction = key
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end, 130)
    faction:SetPoint("LEFT", reward, "RIGHT", 6, 0)
    faction:SetSelected(filters.faction or "ALL")
    panel.factionDrop = faction

    local obtainable = W:Dropdown(panel, OBTAINABLE_ORDER, Labels(OBTAINABLE_ORDER), function(key)
        filters.obtainable = key
        filters.page = 1
        U:RenderTab(panel._tabKey)
    end, 140)
    obtainable:SetPoint("LEFT", faction, "RIGHT", 6, 0)
    obtainable:SetSelected(filters.obtainable or "ALL")
    panel.obtainableDrop = obtainable

    local saturation = W:Dropdown(panel, SATURATION_ORDER, Labels(SATURATION_ORDER, "SATURATE"), function(key)
        filters.saturation = key
        U:RenderTab(panel._tabKey)
    end, 150)
    saturation:SetPoint("LEFT", obtainable, "RIGHT", 6, 0)
    saturation:SetSelected(filters.saturation or "MIXED")
    panel.saturationDrop = saturation

    local compact = W:Checkbox(panel, K.L.COMPACT or "Compact", filters.compact, function(checked)
        filters.compact = checked
        U:RenderTab(panel._tabKey)
    end)
    compact:SetPoint("LEFT", saturation, "RIGHT", 10, 0)
    panel.compactCheck = compact

    local tracking = W:Checkbox(panel, K.L.SHOW_TRACKING or "Hidden", filters.showTracking, function(checked)
        filters.showTracking = checked
        U:RenderTab(panel._tabKey)
    end)
    tracking:SetPoint("LEFT", compact, "RIGHT", 84, 0)
    panel.trackingCheck = tracking

    local statistics = W:Checkbox(panel, K.L.STATISTICS or "Stats", filters.showStatistics, function(checked)
        filters.showStatistics = checked
        U:RenderTab(panel._tabKey)
    end)
    statistics:SetPoint("LEFT", tracking, "RIGHT", 74, 0)
    panel.statisticsCheck = statistics

    panel._filterHeight = (FILTER_ROW_HEIGHT * 2) + 8
    panel._showSidebar = showSidebar
end

-- Category sidebar (Browse only). Roots collapse/expand; a child click filters
-- the list to that category and its descendants.
local function BuildSidebar(panel)
    local sidebar = W:Panel(panel)
    sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -panel._filterHeight)
    sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    panel.sidebar = sidebar

    local list = W:RowList(sidebar, { rowHeight = 18, pageSize = 400, emptyText = K.L.INDEXING or "Indexing..." })
    list:SetPoint("TOPLEFT", 6, -6)
    list:SetPoint("BOTTOMRIGHT", -6, 6)
    panel.sidebarList = list

    panel._expanded = panel._expanded or {}

    list:SetRenderer(function(row, node)
        if not node then return end
        row.icon:SetTexture(nil)
        local indent = node.depth == 0 and "" or "   "
        local marker = ""
        if node.hasChildren then marker = panel._expanded[node.id] and "- " or "+ " end
        local selected = tostring(U.Filters().category) == tostring(node.id)
        row.name:SetText((selected and "|cffffd100" or "|cffcccccc") .. indent .. marker .. tostring(node.name) .. "|r")
        row.right:SetText("")
        row.star:SetText("")
        row:SetScript("OnClick", function()
            if node.hasChildren then
                panel._expanded[node.id] = not panel._expanded[node.id]
            end
            local filters = U.Filters()
            filters.category = (tostring(filters.category) == tostring(node.id)) and "ALL" or node.id
            filters.page = 1
            U:RenderTab(panel._tabKey)
        end)
    end)
end

local function BuildList(panel)
    local left = panel._showSidebar and panel.sidebar or nil

    local listPanel = W:Panel(panel)
    listPanel:SetPoint("TOPLEFT", left or panel, left and "TOPRIGHT" or "TOPLEFT", left and 8 or 0, left and 0 or -panel._filterHeight)
    listPanel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(DETAIL_WIDTH + 8), 0)
    panel.listPanel = listPanel

    -- Count strip: "shown / total", so a filter that hides everything reads as
    -- a filter result rather than as an empty database.
    local header = W:Label(listPanel, "", "GameFontNormalSmall", "RIGHT")
    header:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -8, -6)
    panel.header = header

    local list = W:RowList(listPanel, { rowHeight = 22, pageSize = 100, footer = true })
    list:SetPoint("TOPLEFT", 6, -20)
    list:SetPoint("BOTTOMRIGHT", -6, 6)
    panel.list = list

    -- Kept for compatibility with the pre-1.2 renderer contract (and the
    -- tracker, which reads rows to highlight the selection).
    panel.rows = list.rows
    panel.content = list.content

    list:SetRenderer(function(row, id)
        if not id then return end
        local entry = K.Catalog:GetEntry(id)
        local state = K.Catalog:GetState(id) or {}
        local filters = U.Filters()
        local saturated = (filters.saturation == "CHARACTER") and state.wasEarnedByMe or state.completed

        row.icon:SetTexture(entry and entry.icon or nil)
        if entry and entry.icon then row.icon:SetTexCoord(0, 1, 0, 1) end

        local color = saturated and "|cff00ff00" or "|cffffd100"
        if filters.saturation == "MIXED" and state.completed and not state.wasEarnedByMe then
            color = "|cff88cc88"   -- account-earned, not by this character
        end

        local name = (entry and entry.name and entry.name ~= "") and entry.name or ("Ach " .. tostring(id))
        local marks = ""
        if K:IsExcluded(id) then marks = marks .. " |cffff5555(" .. (K.L.EXCLUDED_SHORT or "Excl") .. ")|r" end
        if entry and entry.hidden then marks = marks .. " |cff9999ff*|r" end
        if entry and entry.isStatistic then marks = marks .. " |cff8888aa#|r" end
        row.name:SetText(color .. name .. "|r" .. marks)

        local right = {}
        if entry and (entry.points or 0) > 0 then right[#right + 1] = tostring(entry.points) end
        if not saturated then
            local progress = K.Catalog:GetProgress(id)
            if progress > 0 then
                right[#right + 1] = W:ProgressColor(progress) .. ("%d%%"):format(math.floor(progress * 100 + 0.5)) .. "|r"
            end
        end
        local rewardTypes = K.Rewards:GetTypes(id)
        if #rewardTypes > 0 then
            local icon = K.Rewards.TYPE_ICONS[rewardTypes[1]]
            if icon then right[#right + 1] = W:IconMarkup(icon, 12) end
        end
        row.right:SetText(table.concat(right, " "))

        row.star:SetText(K:IsWatched(id) and "|TInterface\\Common\\FavoritesIcon:14|t" or "")

        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if K.Menu then K.Menu:Show(id, panel) end
                return
            end
            panel._selected = id
            U:SelectAchievement(id, panel)
            U:RenderTab(panel._tabKey)
        end)
        row:SetScript("OnEnter", function(self)
            if not (K.db and K.db.settings and K.db.settings.tooltips) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if K.Tooltip and K.Tooltip.FillAchievement then
                K.Tooltip:FillAchievement(GameTooltip, id)
            else
                GameTooltip:SetText(name)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Selection highlight
        if panel._selected == id then
            row.name:SetText("|cffffffff> |r" .. (row.name:GetText() or ""))
        end
    end)
end

local function Builder(uiSelf, panel, mode)
    panel._mode = mode
    BuildFilters(panel, mode)
    if panel._showSidebar then BuildSidebar(panel) end
    BuildList(panel)
    if U.BuildDetailPane then U:BuildDetailPane(panel, DETAIL_WIDTH) end
end

-- ----------------------------------------------------------------------------
-- Renderer
-- ----------------------------------------------------------------------------
local function FlattenTree(panel)
    local nodes = {}
    for _, root in ipairs(K.Catalog:GetCategoryTree()) do
        nodes[#nodes + 1] = { id = root.id, name = root.name, depth = 0, hasChildren = #root.children > 0 }
        if panel._expanded[root.id] then
            for _, child in ipairs(root.children) do
                nodes[#nodes + 1] = { id = child.id, name = child.name, depth = 1, hasChildren = false }
            end
        end
    end
    return nodes
end

local function Renderer(uiSelf, panel, mode)
    if not panel or not panel.list then return end
    mode = mode or panel._mode or "ALL"

    local filters = U.Filters()
    local source, isRestricted = SourceForMode(mode)

    local query = {
        search = filters.search,
        expansion = filters.expansion,
        kind = filters.kind,
        category = filters.category,
        completion = filters.completion,
        reward = filters.reward,
        faction = filters.faction,
        obtainable = filters.obtainable,
        saturation = filters.saturation,
        sort = filters.sort,
        showStatistics = filters.showStatistics,
        showTracking = filters.showTracking,
        -- The excluded tab must show excluded rows; every other tab hides them.
        showExcluded = (mode == "EXCLUDED") or filters.showExcluded,
        source = source,
    }

    local results = K.Catalog:Query(query)

    panel.list:SetRowHeight(filters.compact and 16 or 22)
    panel.list:SetItems(results, true)
    panel.rows = panel.list.rows

    if panel.sidebarList then
        panel.sidebarList:SetItems(FlattenTree(panel), true)
    end

    if panel.header then
        local summary
        if mode == "ZONE" then
            summary = ("%s: %s — %d"):format(K.L.SELECTED_ZONE or "Zone", tostring(K.Data._zoneName or "?"), #results)
        elseif isRestricted then
            summary = ("%s: %d / %d"):format(K.L[mode] or mode, #results, #(source or {}))
        else
            summary = ("%d / %d"):format(#results, K.Catalog:Count())
        end
        panel.header:SetText(summary)
    end

    -- Keep a live selection; fall back to the first row so the detail pane is
    -- never blank on an empty selection.
    if panel._selected then
        local stillPresent = false
        for _, id in ipairs(results) do
            if id == panel._selected then stillPresent = true; break end
        end
        if not stillPresent then panel._selected = results[1] end
    else
        panel._selected = results[1]
    end
    U:SelectAchievement(panel._selected, panel)
end

-- Scroll the selection into view when arriving from an external jump.
function U:FocusAchievement(id, panel)
    panel = panel or self.internalTabFrames.BROWSE
    if not (panel and panel.list) then return false end
    for index, candidate in ipairs(panel.list.items) do
        if candidate == id then
            local page = math.ceil(index / panel.list.pageSize)
            panel._selected = id
            panel.list:SetPage(page)
            self:SelectAchievement(id, panel)
            return true
        end
    end
    -- Not in the current result set: clear the filters that could be hiding it.
    local filters = self.Filters()
    filters.search, filters.expansion, filters.kind, filters.category = "", "ALL", "ALL", "ALL"
    filters.completion, filters.reward, filters.faction, filters.obtainable = "ALL", "ALL", "ALL", "ALL"
    panel._selected = id
    self:RenderTab(panel._tabKey)
    return true
end

for _, key in ipairs({ "BROWSE", "WATCH", "TRACKED", "EXCLUDED", "CURATED" }) do
    U.builders[key] = Builder
    U.renderers[key] = Renderer
end

-- ZONE draws into the specials panel with the zone result set.
U.renderers.ZONE = function(uiSelf, panel)
    panel = panel or U.internalTabFrames.CURATED
    if not panel then return end
    U:EnsurePanelBuilt("CURATED")
    Renderer(uiSelf, panel, "ZONE")
end
