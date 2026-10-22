local Villa = _G.FabledUI_Villa
local AchDecor = {}
Villa.AchievementDecor = AchDecor
Villa:RegisterModule("AchievementDecor", AchDecor)

AchDecor.panelTitle = "Achievement Decor"
AchDecor.panelSubtitle = "Achievements that award housing decor. Reverse lookup: pick an achievement, see the items."

AchDecor.filter = { search = "", status = "ALL", expansion = "ALL" }
AchDecor.selectedIndex = 1

local STATUS_ORDER  = { "ALL", "COMPLETED", "PENDING" }
local STATUS_LABELS = { ALL = "All", COMPLETED = "Completed", PENDING = "Pending" }

local EXPANSION_ORDER = { "ALL", "Midnight", "The War Within", "Dragonflight", "Shadowlands", "BFA", "Legion", "WoD", "MoP", "Cata", "WotLK", "TBC", "Classic" }
local EXPANSION_LABELS = {
    ALL              = "All Expansions",
    Midnight         = "Midnight",
    ["The War Within"] = "The War Within",
    Dragonflight     = "Dragonflight",
    Shadowlands      = "Shadowlands",
    BFA              = "Battle for Azeroth",
    Legion           = "Legion",
    WoD              = "Warlords of Draenor",
    MoP              = "Mists of Pandaria",
    Cata             = "Cataclysm",
    WotLK            = "Wrath of the Lich King",
    TBC              = "The Burning Crusade",
    Classic          = "Classic",
}

-- ============================================================
-- Data helpers
-- ============================================================

local function GetItemNameAndIcon(itemID)
    -- Call C_Item.GetItemInfo directly. Wrapping a multi-return call in
    -- parentheses or an and/or chain truncates it to its FIRST value, so the
    -- previous form left `icon` nil on every call and item icons never drew.
    -- (The legacy global GetItemInfo is gone in modern retail anyway.)
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return name or ("Item #" .. tostring(itemID)), icon
end

local function IsAchievementCompleted(achievementID)
    if not achievementID or not GetAchievementInfo then return false end
    local _, _, _, completed = GetAchievementInfo(achievementID)
    return completed and true or false
end

local function GetAchievementName(achievementID, fallback)
    if achievementID and GetAchievementInfo then
        local _, name = GetAchievementInfo(achievementID)
        if name and name ~= "" then return name end
    end
    return fallback or ("Achievement #" .. tostring(achievementID or "?"))
end

-- Pull achievement entries from whichever donor mode is active.
local function GetSourceEntries()
    if Villa.NormalizedData and type(Villa.NormalizedData.GetAchievementEntries) == "function" then
        local out = Villa.NormalizedData:GetAchievementEntries()
        if out and #out > 0 then return out end
    end
    if Villa.HomeData and type(Villa.HomeData.GetAchievementEntries) == "function" then
        return Villa.HomeData:GetAchievementEntries()
    end
    return {}
end

-- Build (lazily) and cache a decorID -> itemID map from HomeData.decorMeta.
local _decorToItemCache
local function GetDecorToItemMap()
    if _decorToItemCache then return _decorToItemCache end
    local map = {}
    local meta = Villa.HomeData and Villa.HomeData.decorMeta or nil
    if type(meta) == "table" then
        for itemID, m in pairs(meta) do
            local decorID = tonumber(m and m.decorID)
            if decorID and not map[decorID] then
                map[decorID] = tonumber(itemID)
            end
        end
    end
    _decorToItemCache = map
    return map
end

-- Map decorIDs -> itemIDs via HomeData.decorMeta when possible.
local function ResolveItemIDs(entry)
    local items = {}
    if entry.decorIds and type(entry.decorIds) == "table" then
        local map = GetDecorToItemMap()
        for _, decorID in ipairs(entry.decorIds) do
            local itemID = map[tonumber(decorID)]
            items[#items + 1] = { itemID = itemID, decorID = decorID }
        end
    end
    return items
end

local function GetEntryExpansion(entry)
    return entry.expansion or "ALL"
end

-- ============================================================
-- Villa.Data.AchievementSources — cross-addon compatibility view
-- ============================================================
-- FabledUI_Kleos reads `FabledUI_Villa.Data.AchievementSources[achievementID]`
-- and pulls `.decorIDs` off it (Rewards.lua, the "suiteDecor" provider) so it
-- can name the decor an achievement awards. It degrades silently when the table
-- is absent -- it just stops naming them, with nothing logged.
--
-- That table used to be a generated snapshot file
-- (FabledUI_Villa/Data/AchievementSources.lua) built from HomeDecor v12.0.20.
-- The file was retired on 2026-08-14: it was 121 versions stale and every
-- decorID in it was already reachable through the live providers. Deleting it
-- outright would have left Kleos quietly less capable, so the contract is kept
-- and re-pointed at current data instead.
--
-- Built lazily through a metatable because the source lives in the LoadOnDemand
-- catalog shard: Kleos indexing this is a UI action (opening achievement
-- rewards), not a hot loop, so paying the shard load on first touch is fine --
-- but paying it at Villa's login would not be.
local _achievementSources

local function BuildAchievementSources()
    local sources = {}
    if Villa.EnsureCatalogData then
        Villa:EnsureCatalogData()
    end
    for _, entry in ipairs(GetSourceEntries()) do
        local achievementID = tonumber(entry.key)
        if achievementID then
            local decorIDs = {}
            for _, decorID in ipairs(entry.decorIds or {}) do
                local numeric = tonumber(decorID)
                if numeric then
                    decorIDs[#decorIDs + 1] = numeric
                end
            end
            -- `decorIDs`, not the provider's `decorIds`: this is Kleos's field
            -- name and the whole point is that its existing read keeps working.
            sources[achievementID] = {
                name = entry.title or entry.label,
                decorIDs = decorIDs,
                expansion = entry.expansion,
            }
        end
    end
    return sources
end

function AchDecor:GetAchievementSources()
    if not _achievementSources then
        _achievementSources = BuildAchievementSources()
    end
    return _achievementSources
end

Villa.Data = Villa.Data or {}
Villa.Data.AchievementSources = setmetatable({}, {
    __index = function(_, key)
        return AchDecor:GetAchievementSources()[key]
    end,
    -- So `for id, record in pairs(Villa.Data.AchievementSources)` works too;
    -- a bare __index would make the table look empty to any iteration.
    __pairs = function()
        return pairs(AchDecor:GetAchievementSources())
    end,
})

local function FilterEntries(all, filter)
    local out = {}
    for _, entry in ipairs(all or {}) do
        local pass = true
        local achID = entry.achievementId or entry.achievementID
        local achName = GetAchievementName(achID, entry.title)

        if filter.search and filter.search ~= "" then
            local q = filter.search:lower()
            local hay = (achName or ""):lower() .. " " .. ((entry.subtitle or "")):lower()
            pass = hay:find(q, 1, true) ~= nil
        end

        if pass and filter.status and filter.status ~= "ALL" then
            local completed = IsAchievementCompleted(achID)
            if filter.status == "COMPLETED" and not completed then pass = false end
            if filter.status == "PENDING" and completed then pass = false end
        end

        if pass and filter.expansion and filter.expansion ~= "ALL" then
            pass = (GetEntryExpansion(entry) == filter.expansion)
        end

        if pass then
            out[#out + 1] = entry
        end
    end
    table.sort(out, function(a, b)
        local an = GetAchievementName(a.achievementId or a.achievementID, a.title or "")
        local bn = GetAchievementName(b.achievementId or b.achievementID, b.title or "")
        return (an or "") < (bn or "")
    end)
    return out
end

-- ============================================================
-- Public API
-- ============================================================

function AchDecor:GetFilteredEntries()
    return FilterEntries(GetSourceEntries(), self.filter)
end

function AchDecor:GetSelected(entries)
    entries = entries or self:GetFilteredEntries()
    if #entries == 0 then return nil end
    self.selectedIndex = math.min(math.max(self.selectedIndex or 1, 1), #entries)
    return entries[self.selectedIndex]
end

-- ============================================================
-- Panel
-- ============================================================

function AchDecor:CreatePanel(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

function AchDecor:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then return end
    frame._initialized = true

    -- Top row: search + filters
    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetPoint("TOPLEFT", 16, -62)
    topRow:SetPoint("TOPRIGHT", -16, -62)
    topRow:SetHeight(24)

    local search = CreateFrame("EditBox", nil, topRow, "InputBoxTemplate")
    search:SetSize(200, 22)
    search:SetPoint("LEFT", 0, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(box)
        self.filter.search = box:GetText() or ""
        self.selectedIndex = 1
        self:Refresh()
    end)

    local statusBtn = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
    statusBtn:SetSize(110, 22)
    statusBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
    statusBtn:SetText("Status: " .. STATUS_LABELS[self.filter.status])
    statusBtn:SetScript("OnClick", function(btn)
        local menuList = {}
        for _, key in ipairs(STATUS_ORDER) do
            local k = key
            menuList[#menuList + 1] = {
                text = STATUS_LABELS[k] or k,
                notCheckable = true,
                func = function()
                    self.filter.status = k
                    self.selectedIndex = 1
                    btn:SetText("Status: " .. (STATUS_LABELS[k] or k))
                    self:Refresh()
                end,
            }
        end
        if _G.MenuUtil and type(_G.MenuUtil.CreateContextMenu) == "function" then
            local ok = pcall(MenuUtil.CreateContextMenu, btn, function(_, rd)
                for _, e in ipairs(menuList) do rd:CreateButton(e.text, e.func) end
            end)
            if ok then return end
        end
        if _G.EasyMenu then
            EasyMenu(menuList, CreateFrame("Frame", "VillaAchDecorStatusMenu", UIParent), btn, 0, -4, "MENU")
        end
    end)

    local expBtn = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
    expBtn:SetSize(140, 22)
    expBtn:SetPoint("LEFT", statusBtn, "RIGHT", 8, 0)
    expBtn:SetText(EXPANSION_LABELS[self.filter.expansion] or "All Expansions")
    expBtn:SetScript("OnClick", function(btn)
        local menuList = {}
        for _, key in ipairs(EXPANSION_ORDER) do
            local k = key
            menuList[#menuList + 1] = {
                text = EXPANSION_LABELS[k] or k,
                notCheckable = true,
                func = function()
                    self.filter.expansion = k
                    self.selectedIndex = 1
                    btn:SetText(EXPANSION_LABELS[k] or k)
                    self:Refresh()
                end,
            }
        end
        if _G.MenuUtil and type(_G.MenuUtil.CreateContextMenu) == "function" then
            local ok = pcall(MenuUtil.CreateContextMenu, btn, function(_, rd)
                for _, e in ipairs(menuList) do rd:CreateButton(e.text, e.func) end
            end)
            if ok then return end
        end
        if _G.EasyMenu then
            EasyMenu(menuList, CreateFrame("Frame", "VillaAchDecorExpMenu", UIParent), btn, 0, -4, "MENU")
        end
    end)

    local summary = topRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", expBtn, "RIGHT", 12, 0)
    summary:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
    summary:SetJustifyH("RIGHT")
    self.summaryText = summary
    self.searchBox = search
    self.statusBtn = statusBtn
    self.expBtn = expBtn

    -- Left list
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -92)
    scroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 18)
    scroll:SetWidth(380)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.content = content
    self.rows = {}

    -- Right detail
    local detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 12, 0)
    detail:SetPoint("BOTTOMRIGHT", -16, 18)
    detail:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    detail:SetBackdropColor(0.04, 0.05, 0.10, 0.92)
    detail:SetBackdropBorderColor(0.36, 0.31, 0.62, 0.85)
    self.detailFrame = detail

    local title = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    title:SetJustifyH("LEFT")
    self.detailTitle = title

    local subtitle = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    subtitle:SetJustifyH("LEFT")
    self.detailSubtitle = subtitle

    local itemHeader = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    itemHeader:SetText("Awarded items")

    local itemScroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", itemHeader, "BOTTOMLEFT", 0, -6)
    itemScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -28, 14)
    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetSize(1, 1)
    itemScroll:SetScrollChild(itemContent)
    self.itemScroll = itemScroll
    self.itemContent = itemContent
    self.itemRows = {}
end

function AchDecor:RefreshDetail(entry)
    for _, row in ipairs(self.itemRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.itemRows = {}

    if not entry then
        if self.detailTitle then self.detailTitle:SetText("No achievement selected") end
        if self.detailSubtitle then self.detailSubtitle:SetText("Pick an achievement on the left.") end
        return
    end

    local achID = entry.achievementId or entry.achievementID
    local achName = GetAchievementName(achID, entry.title)
    local completed = IsAchievementCompleted(achID)

    if self.detailTitle then
        self.detailTitle:SetText(achName .. (completed and "  |cff66cc66[Completed]|r" or ""))
    end
    if self.detailSubtitle then
        local owned, total = entry.owned or 0, entry.total or 0
        self.detailSubtitle:SetText(string.format("%s  -  Decor collected: %d/%d", entry.subtitle or "", owned, total))
    end

    local items = ResolveItemIDs(entry)
    local width = math.max(250, (self.itemScroll:GetWidth() or 300) - 24)
    local y = 0
    for _, info in ipairs(items) do
        local itemID = info.itemID
        local row = CreateFrame("Button", nil, self.itemContent, "BackdropTemplate")
        row:SetSize(width, 36)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(0.06, 0.08, 0.16, 0.90)
        row:SetBackdropBorderColor(0.32, 0.36, 0.48, 0.80)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 6, 0)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 36, -4)
        label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        label:SetJustifyH("LEFT")

        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("BOTTOMLEFT", 36, 4)
        sub:SetJustifyH("LEFT")

        if itemID then
            local name, iconID = GetItemNameAndIcon(itemID)
            if iconID then icon:SetTexture(iconID) end
            local known = Villa.IsKnownDecorItem and Villa:IsKnownDecorItem(itemID)
            label:SetText(name .. (known and "  |cff66cc66[Collected]|r" or ""))
            sub:SetText("itemID: " .. tostring(itemID) .. (info.decorID and ("  decorID: " .. tostring(info.decorID)) or ""))
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(itemID)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnMouseUp", function(rowFrame, button)
                if button == "RightButton" and Villa.Wishlist then
                    Villa.Wishlist:ShowAddMenu(itemID, rowFrame)
                end
            end)
        else
            label:SetText("Unknown decor (decorID " .. tostring(info.decorID) .. ")")
            sub:SetText("No itemID resolved from current donor data.")
        end

        self.itemRows[#self.itemRows + 1] = row
        y = y + 40
    end
    self.itemContent:SetWidth(width)
    self.itemContent:SetHeight(math.max(1, y))
end

function AchDecor:Refresh()
    if not self.frame then return end
    self:InitUI(self.frame)

    if self.statusBtn then self.statusBtn:SetText("Status: " .. (STATUS_LABELS[self.filter.status] or "All")) end
    if self.expBtn then self.expBtn:SetText(EXPANSION_LABELS[self.filter.expansion] or "All Expansions") end

    for _, row in ipairs(self.rows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.rows = {}

    local entries = self:GetFilteredEntries()
    local selected = self:GetSelected(entries)
    if self.summaryText then
        self.summaryText:SetText(string.format("%d achievements", #entries))
    end

    local width = math.max(360, (self.scroll:GetWidth() or 400) - 24)
    local y = 0
    for index, entry in ipairs(entries) do
        local achID = entry.achievementId or entry.achievementID
        local achName = GetAchievementName(achID, entry.title)
        local completed = IsAchievementCompleted(achID)

        local isSelected = (entry == selected)
        local row = CreateFrame("Button", nil, self.content, "BackdropTemplate")
        row:SetSize(width, 42)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        row:SetBackdropColor(isSelected and 0.12 or 0.08, 0.10, 0.16, 0.94)
        row:SetBackdropBorderColor(isSelected and 0.53 or 0.22, 0.47, 0.96, 0.90)

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -6)
        title:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        title:SetJustifyH("LEFT")
        title:SetText(achName .. (completed and "  |cff66cc66[Done]|r" or ""))

        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("BOTTOMLEFT", 10, 6)
        sub:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        sub:SetJustifyH("LEFT")
        local owned = entry.owned or 0
        local total = entry.total or 0
        sub:SetText(string.format("%s  -  %d items  -  %d/%d collected", entry.subtitle or "", total, owned, total))

        local capturedIndex = index
        row:SetScript("OnClick", function()
            self.selectedIndex = capturedIndex
            self:Refresh()
        end)

        self.rows[#self.rows + 1] = row
        y = y + 46
    end
    self.content:SetWidth(width)
    self.content:SetHeight(math.max(1, y))
    self:RefreshDetail(selected)
end
