local Villa = _G.FabledUI_Villa
local UI = Villa.UI
local CodexData = Villa.CodexData

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
        entryType = config.entryType,
        provider = config.provider,
    }
    Villa[config.objectName] = module
    Villa:RegisterModule(config.objectName, module)

    function module:GetEntries()
        local provider = self.provider
        if type(provider) == "function" then
            return provider(CodexData) or {}
        end
        return {}
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
        self.detailTags = {}

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
        if UI then UI:StyleEditBox(search) end

        local summary = topRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summary:SetPoint("LEFT", search, "RIGHT", 12, 0)
        summary:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
        summary:SetJustifyH("RIGHT")
        self.summaryText = summary

        -- Virtualised list rather than a ScrollFrame; see UI:CreateVirtualList
        -- for why (scroll children past ~32k px stop drawing their contents).
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
                row.Subtitle:SetText(string.format("%s • %d/%d", tostring(entry.subtitle or "Unknown"), tonumber(entry.owned or 0), tonumber(entry.total or #(entry.decorIds or {}))))

                row:SetScript("OnEnter", function(selfButton)
                    GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
                    GameTooltip:SetText(entry.title or "Unknown")
                    GameTooltip:AddLine(entry.subtitle or "", 0.82, 0.82, 0.94)
                    GameTooltip:AddLine(string.format("Decor IDs: %d", #(entry.decorIds or {})), 0.65, 0.85, 1)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", GameTooltip_Hide)
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
        title:SetPoint("RIGHT", detail, "RIGHT", -120, 0)
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

        local star = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
        star:SetSize(92, 22)
        star:SetPoint("TOPRIGHT", -12, -10)
        star:SetText("Wishlist")
        star:SetScript("OnClick", function()
            local entry = self.currentEntry
            if not entry then return end
            CodexData:ToggleWishlist(entry.entryType, entry.key)
            self:RefreshDetail(entry)
        end)
        self.wishlistButton = star
        if UI then UI:StyleButton(star) end
    end

    function module:RefreshDetail(entry)
        self.currentEntry = entry
        if not entry then
            self.detailTitle:SetText("No entry selected")
            self.detailSubtitle:SetText("Pick an entry from the list.")
            self.detailBody:SetText("")
            self.wishlistButton:Disable()
            return
        end
        self.detailTitle:SetText(entry.title or "Unknown")
        self.detailSubtitle:SetText(string.format("%s  |  %d/%d known", tostring(entry.subtitle or "Unknown"), tonumber(entry.owned or 0), tonumber(entry.total or #(entry.decorIds or {}))))
        self.detailBody:SetText(entry.detail or "No details available.")
        self.wishlistButton:Enable()
        local starred = CodexData:IsWishlisted(entry.entryType, entry.key)
        self.wishlistButton:SetText(starred and "Unwishlist" or "Wishlist")
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

    function module:OnEnable()
        -- Lazy only
    end

    return module
end

-- Provider that prefers NormalizedData (donor merge) and falls back through
-- HomeData and CodexData. Keeps the Codex Wishlist enrichment while pulling
-- whichever donor surface is actually populated.
local function chainedProvider(method)
    return function(_)
        local nd = Villa.NormalizedData
        if nd and type(nd[method]) == "function" then
            local entries = nd[method](nd)
            if type(entries) == "table" and #entries > 0 then return entries end
        end
        local hd = Villa.HomeData
        if hd and type(hd[method]) == "function" then
            local entries = hd[method](hd)
            if type(entries) == "table" and #entries > 0 then return entries end
        end
        if CodexData and type(CodexData[method]) == "function" then
            return CodexData[method](CodexData) or {}
        end
        return {}
    end
end

createModule({ key = "quests", objectName = "Quests", title = "Villa Quests", subtitle = "Housing decor items obtainable from quests.", entryType = "quest", provider = chainedProvider("GetQuestEntries") })
createModule({ key = "achievements", objectName = "Achievements", title = "Villa Achievements", subtitle = "Housing decor items rewarded by achievements.", entryType = "achievement", provider = chainedProvider("GetAchievementEntries") })
createModule({ key = "drops", objectName = "Drops", title = "Villa Drops", subtitle = "Housing decor items from dungeon, raid, and world drops.", entryType = "drop", provider = chainedProvider("GetDropEntries") })
createModule({ key = "pvp", objectName = "PvP", title = "Villa PvP", subtitle = "Housing decor items from PvP vendors and seasonal rewards.", entryType = "pvp", provider = chainedProvider("GetPvPEntries") })
createModule({ key = "professions", objectName = "Professions", title = "Villa Professions", subtitle = "Crafting and recipe donor sources.", entryType = "profession", provider = function(data) return data:GetProfessionEntries() end })
-- Wishlist panel is now provided by Villa_Wishlist.lua (per-character persistent wishlists).
