local Villa = _G.FabledUI_Villa
local UI = Villa.UI

local function stringMatches(haystack, needle)
    haystack = tostring(haystack or ""):lower()
    needle = tostring(needle or ""):lower()
    if needle == "" then return true end
    return haystack:find(needle, 1, true) ~= nil
end

local function createModule(config)
    local module = {
        panelKey = config.key,
        panelTitle = config.title,
        panelSubtitle = config.subtitle,
        provider = config.provider,
    }
    Villa[config.objectName] = module
    Villa:RegisterModule(config.objectName, module)

    function module:GetEntries()
        return (type(self.provider) == "function" and self.provider()) or {}
    end

    function module:GetFilteredEntries()
        local all = self:GetEntries()
        local q = self.filter and self.filter.search or ""
        if q == "" then return all end
        local out = {}
        for _, entry in ipairs(all) do
            if stringMatches(entry.title, q) or stringMatches(entry.subtitle, q) or stringMatches(entry.detail, q) then
                out[#out + 1] = entry
            end
        end
        return out
    end

    function module:GetSelected(entries)
        entries = entries or self:GetFilteredEntries()
        if #entries == 0 then return nil end
        self.selectedIndex = math.min(math.max(self.selectedIndex or 1, 1), #entries)
        return entries[self.selectedIndex]
    end

    function module:CreatePanel(parent)
        if self.frame then return self.frame end
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetAllPoints(parent)
        frame:Hide()
        self.frame = frame
        return frame
    end

    function module:InitUI(frame)
        frame = frame or self.frame
        if not frame or frame._initialized then return end
        frame._initialized = true
        self.filter = self.filter or { search = "" }
        self.rows = {}

        local topRow = CreateFrame("Frame", nil, frame)
        topRow:SetPoint("TOPLEFT", 16, -62)
        topRow:SetPoint("TOPRIGHT", -16, -62)
        topRow:SetHeight(24)

        local search = CreateFrame("EditBox", nil, topRow, "InputBoxTemplate")
        search:SetSize(220, 22)
        search:SetPoint("LEFT", 0, 0)
        search:SetAutoFocus(false)
        search:SetScript("OnTextChanged", function(box)
            self.filter.search = box:GetText() or ""
            self.selectedIndex = 1
            self:Refresh()
        end)
        self.searchBox = search
        if UI and UI.StyleEditBox then UI:StyleEditBox(search) end

        local summary = topRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summary:SetPoint("LEFT", search, "RIGHT", 12, 0)
        summary:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
        summary:SetJustifyH("RIGHT")
        self.summaryText = summary

        -- Virtualised list rather than a ScrollFrame: the old scroll child was
        -- 46px * #entries tall (69,322px on Catalog) and the client silently
        -- stops drawing a child that large. See UI:CreateVirtualList.
        local listHost = CreateFrame("Frame", nil, frame)
        listHost:SetPoint("TOPLEFT", 16, -92)
        listHost:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 18)
        listHost:SetWidth(430)
        self.scroll = listHost -- the detail pane anchors off this

        self.list = UI:CreateVirtualList(listHost, {
            rowHeight = 46,
            bind = function(row, entry, _, isSelected)
                row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
                row:SetBackdropColor(isSelected and 0.12 or 0.08, 0.10, 0.16, 0.94)
                row:SetBackdropBorderColor(isSelected and 0.53 or 0.22, 0.47, 0.96, 0.90)
                row.Title:SetText(entry.title or "Unknown")
                row.Subtitle:SetText(entry.subtitle or "")
            end,
            onSelect = function(index)
                self.selectedIndex = index
                self.list:Render()
                self:RefreshDetail(self.list:GetSelected())
            end,
        })

        local detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        detail:SetPoint("TOPLEFT", listHost, "TOPRIGHT", 12, 0)
        detail:SetPoint("BOTTOMRIGHT", -16, 18)
        detail:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
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

        local body = detail:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        body:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
        body:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetWordWrap(true)
        self.detailBody = body
    end

    function module:RefreshDetail(entry)
        self.currentEntry = entry
        if not entry then
            self.detailTitle:SetText("No entry selected")
            self.detailSubtitle:SetText("Pick an entry from the list.")
            self.detailBody:SetText("")
            return
        end
        self.detailTitle:SetText(entry.title or "Unknown")
        self.detailSubtitle:SetText(entry.subtitle or "")
        self.detailBody:SetText(entry.detail or "No details available.")
    end

    function module:Refresh()
        if not self.frame then return end
        self:InitUI(self.frame)
        local entries = self:GetFilteredEntries()
        self.summaryText:SetText(string.format("%d entries", #entries))
        self.list.selectedIndex = math.min(math.max(self.selectedIndex or 1, 1), math.max(#entries, 1))
        self.list:SetEntries(entries)
        self.selectedIndex = self.list.selectedIndex
        self:RefreshDetail(self.list:GetSelected())
    end
end

createModule({ key = "treasures", objectName = "Treasures", title = "Villa Treasures", subtitle = "BetterHomes treasure donor routes.", provider = function() return (Villa.NormalizedData and Villa.NormalizedData.GetTreasureEntries and Villa.NormalizedData:GetTreasureEntries()) or (Villa.BetterHomesData and Villa.BetterHomesData:GetTreasureEntries()) or {} end })
createModule({ key = "catalog", objectName = "Catalog", title = "Villa Catalog", subtitle = "HousingDecorGuide donor catalog slice.", provider = function() return (Villa.NormalizedData and Villa.NormalizedData.GetCatalogEntries and Villa.NormalizedData:GetCatalogEntries()) or (Villa.HDGData and Villa.HDGData:GetCatalogEntries()) or {} end })
createModule({ key = "styles", objectName = "Styles", title = "Villa Styles", subtitle = "HousingDecorGuide style donor browser.", provider = function() return (Villa.NormalizedData and Villa.NormalizedData.GetStyleEntries and Villa.NormalizedData:GetStyleEntries()) or (Villa.HDGData and Villa.HDGData:GetStyleEntries()) or {} end })
createModule({ key = "trainers", objectName = "Trainers", title = "Villa Trainers", subtitle = "HousingDecorGuide profession trainer donor browser.", provider = function() return (Villa.NormalizedData and Villa.NormalizedData.GetTrainerEntries and Villa.NormalizedData:GetTrainerEntries()) or (Villa.HDGData and Villa.HDGData:GetTrainerEntries()) or {} end })

-- Quests / Achievements / Drops / PvP panels are owned by CodexPanels.lua
-- (with Wishlist enrichment); their providers there chain through
-- NormalizedData -> HomeData -> CodexData. Don't re-register here.
-- Wishlist panel is provided by Villa_Wishlist.lua (per-character persistent wishlists).

-- Progress panel: live collection coverage dashboard
local progressModule = {
    panelKey   = "progress",
    panelTitle = "Villa Progress",
    panelSubtitle = "Housing collection coverage at a glance.",
}
Villa.Progress = progressModule
Villa:RegisterModule("Progress", progressModule)

function progressModule:CreatePanel(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

function progressModule:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then return end
    frame._initialized = true

    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    heading:SetPoint("TOPLEFT", 16, -62)
    heading:SetText("Collection Coverage")
    heading:SetTextColor(0.80, 0.75, 1.0)

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -16)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    self.bodyText = body

    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 24)
    refreshBtn:SetPoint("BOTTOMLEFT", 16, 18)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() self:Refresh() end)
end

function progressModule:Refresh()
    if not self.frame then return end
    self:InitUI(self.frame)
    if not self.bodyText then return end

    local lines = {}

    -- Live collection numbers come from Villa_CatalogScan, not straight from
    -- C_HousingCatalog. This used to call C_HousingCatalog.GetNumDecorInCatalog
    -- and GetNumDecorCollected -- neither of which exists -- so both guards
    -- failed, `total` was permanently 0, and the panel always claimed the API
    -- returned no data (while advising a trip to your garrison, which has
    -- nothing to do with housing). CatalogScan walks the real catalog searcher
    -- and caches the result, so read that.
    local scan = Villa.CatalogScan
    local total, owned, lastScan = 0, 0, nil
    if scan and scan.GetStats then
        local ok, t, o, ls = pcall(scan.GetStats, scan)
        if ok then total, owned, lastScan = t or 0, o or 0, ls end
    end

    if total > 0 then
        local pct = math.floor((owned / total) * 100)
        table.insert(lines, "|cff00ccffTotal Decor Entries:|r  " .. total)
        table.insert(lines, "|cff00ff00Collected:|r  " .. owned .. "  (|cffffff00" .. pct .. "%|r)")
        table.insert(lines, "|cffff6666Uncollected:|r  " .. (total - owned))
        if lastScan and date then
            table.insert(lines, "|cffaaaaaaLast catalog scan: " .. date("%Y-%m-%d %H:%M", lastScan) .. "|r")
        end

        -- How much of the catalog we can actually attribute to a vendor. This is
        -- the number vendor tours move, so it belongs on the progress panel.
        if scan.GetCoverage then
            local okc, sourced, ctotal, ownedNoSource = pcall(scan.GetCoverage, scan)
            if okc and (ctotal or 0) > 0 then
                table.insert(lines, "")
                table.insert(lines, string.format(
                    "|cff00ccffVerified vendor source:|r  %d/%d  (|cffffff00%.1f%%|r)",
                    sourced, ctotal, (sourced / ctotal) * 100))
                if sourced == 0 then
                    table.insert(lines, "  |cffaaaaaaNo vendor data captured yet — visit housing vendors.|r")
                else
                    table.insert(lines, string.format(
                        "  |cffaaaaaa%d owned with no known vendor source.|r", ownedNoSource))
                end
            end
        end
    else
        table.insert(lines, "|cffaaaaaaNo catalog data yet.|r")
        table.insert(lines, "Run |cff5cf0a0/villa catalogscan|r to read the live decor catalog.")
    end

    -- Provider-level stats if a donor addon exposes them
    if Villa.NormalizedData and Villa.NormalizedData.GetStats then
        local ok, stats = pcall(function() return Villa.NormalizedData:GetStats() end)
        if ok and type(stats) == "table" then
            table.insert(lines, "")
            table.insert(lines, "|cff00ccffDonor Data Loaded:|r")
            for k, v in pairs(stats) do
                table.insert(lines, "  " .. tostring(k) .. ": " .. tostring(v))
            end
        end
    end

    -- Shopping list totals
    if Villa.ShoppingList then
        local lists = Villa.ShoppingList:GetAll()
        local listCount, itemCount = 0, 0
        for _, listData in pairs(lists or {}) do
            listCount = listCount + 1
            local items = (type(listData) == "table") and (listData.items or {}) or {}
            itemCount = itemCount + #items
        end
        if listCount > 0 then
            table.insert(lines, "")
            table.insert(lines, string.format("|cff00ccffShopping Lists:|r  %d lists, %d items tracked", listCount, itemCount))
        end
    end

    self.bodyText:SetText(table.concat(lines, "\n"))
end
