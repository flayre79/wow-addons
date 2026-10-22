local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Rewards
-- The reward tab: one selector per reward type (mount, pet, title, toy,
-- transmog, tabard, teleport, housing decor) over the reverse index built in
-- Rewards.lua. Housing decor rows resolve their decor names through the
-- catalog so the tab answers "which achievement gives me that chair".
--
-- The index build is chunked, so the tab shows progress on first open instead
-- of freezing while 5,000 achievements are classified.
-- ============================================================================

local DETAIL_WIDTH = 330

local function TypeOrder()
    local order = { "ANY" }
    for _, typeKey in ipairs(K.Rewards.TYPES) do order[#order + 1] = typeKey end
    return order
end

local function DecorNames(id, limit)
    local names = {}
    for _, recordID in ipairs(K.Rewards:GetDecorIDs(id)) do
        if #names >= (limit or 3) then break end
        local name
        if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID and Enum and Enum.HousingCatalogEntryType then
            local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, Enum.HousingCatalogEntryType.Decor, recordID)
            if ok and type(info) == "table" then name = info.name end
        end
        names[#names + 1] = name or ("#" .. tostring(recordID))
    end
    return names
end

U.DecorNames = DecorNames

local function Builder(uiSelf, panel)
    panel._rewardType = panel._rewardType or "ANY"

    local selector = CreateFrame("Frame", nil, panel)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    selector:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    selector:SetHeight(26)
    panel.selector = selector

    panel.typeButtons = {}
    local x = 0
    for _, typeKey in ipairs(TypeOrder()) do
        local label = (typeKey == "ANY") and (K.L.ALL or "All") or (K.L[typeKey] or typeKey)
        local button = W:Button(selector, label, 92, 20, function()
            panel._rewardType = typeKey
            panel._selected = nil
            U:RenderTab("REWARDS")
        end)
        button:SetPoint("LEFT", selector, "LEFT", x, 0)
        panel.typeButtons[typeKey] = button
        x = x + 95
    end

    panel.status = W:Label(panel, "", "GameFontNormalSmall")
    panel.status:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 4, -4)

    local listPanel = W:Panel(panel)
    listPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -46)
    listPanel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(DETAIL_WIDTH + 8), 0)
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
        local state = K.Catalog:GetState(id) or {}

        row.icon:SetTexture(entry.icon or nil)
        local color = state.completed and "|cff00ff00" or "|cffffd100"
        row.name:SetText(color .. ((entry.name ~= "" and entry.name) or ("Ach " .. id)) .. "|r")

        local right
        if panel._rewardType == "HOUSING" then
            local names = DecorNames(id, 2)
            right = #names > 0 and table.concat(names, ", ") or (K.L.UNKNOWN or "?")
        else
            right = K.Rewards:Describe(id) or ""
        end
        row.right:SetText("|cff888888" .. right .. "|r")
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

    panel._filterHeight = 46
    U:BuildDetailPane(panel, DETAIL_WIDTH)
end

local function Renderer(uiSelf, panel)
    if not panel or not panel.list then return end

    for typeKey, button in pairs(panel.typeButtons or {}) do
        if button.SetEnabled then button:SetEnabled(typeKey ~= panel._rewardType) end
    end

    local index = K.Rewards:GetIndex()
    if not index then
        panel.status:SetText(K.L.INDEXING or "Indexing reward data...")
        panel.list:SetItems({})
        K.Rewards:BuildIndexAsync(function()
            if U.activeInternalTab == "REWARDS" then U:RenderTab("REWARDS") end
        end, function(fraction)
            if panel.status then
                panel.status:SetText(("%s %d%%"):format(K.L.INDEXING or "Indexing...", math.floor(fraction * 100 + 0.5)))
            end
        end)
        return
    end

    local ids = K.Rewards:ListByType(panel._rewardType or "ANY")
    local filters = U.Filters()
    local results = K.Catalog:Query({
        source = ids,
        completion = filters.completion,
        expansion = filters.expansion,
        saturation = filters.saturation,
        sort = filters.sort,
        showStatistics = filters.showStatistics,
        showTracking = filters.showTracking,
    })

    panel.list:SetItems(results, true)
    panel.rows = panel.list.rows

    local counts = K.Rewards:Counts() or {}
    local parts = {}
    for _, typeKey in ipairs(TypeOrder()) do
        local count = counts[typeKey]
        if count and count > 0 then
            parts[#parts + 1] = ("%s %d"):format(K.L[typeKey] or typeKey, count)
        end
    end
    panel.status:SetText(("%d %s  |cff666666|  %s"):format(#results, K.L.ACHIEVEMENTS or "achievements", table.concat(parts, "  ")))

    if not panel._selected then panel._selected = results[1] end
    U:RenderDetail(panel, panel._selected)
end

U.builders.REWARDS = Builder
U.renderers.REWARDS = Renderer
