local Villa = _G.FabledUI_Villa
local UI = Villa.UI
local HV = Villa.HousingVendorData

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
        local provider = self.provider
        return type(provider) == "function" and (provider(HV) or {}) or {}
    end

    function module:GetFilteredEntries()
        local q = self.filter and self.filter.search or ""
        local all = self:GetEntries()
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
                row.Subtitle:SetText(entry.subtitle or "")

                row:SetScript("OnMouseUp", function(_, button)
                    if button == "RightButton" and entry.mapID and entry.x and entry.y then
                        Villa:SetWaypoint(entry.mapID, entry.x, entry.y, entry.name or entry.title)
                    end
                end)
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

createModule({ key = "reputation", objectName = "Reputation", title = "Villa Reputation", subtitle = "Reputation rewards from housing vendors.", provider = function(data) return (Villa.NormalizedData and Villa.NormalizedData.GetReputationEntries and Villa.NormalizedData:GetReputationEntries()) or (data and data:GetReputationEntries()) or {} end })
createModule({ key = "materials", objectName = "Materials", title = "Villa Materials", subtitle = "Crafting materials sourced from housing vendors.", provider = function(data) return (Villa.NormalizedData and Villa.NormalizedData.GetMaterialsEntries and Villa.NormalizedData:GetMaterialsEntries()) or (data and data:GetMaterialsEntries()) or {} end })
createModule({ key = "planning", objectName = "Planning", title = "Villa Planning", subtitle = "Housing planning items and blueprints.", provider = function(data) return (Villa.NormalizedData and Villa.NormalizedData.GetPlanningEntries and Villa.NormalizedData:GetPlanningEntries()) or (data and data:GetPlanningEntries()) or {} end })
createModule({ key = "statistics", objectName = "Statistics", title = "Villa Statistics", subtitle = "Coverage statistics across housing vendor catalogs.", provider = function(data) return (Villa.NormalizedData and Villa.NormalizedData.GetStatisticsEntries and Villa.NormalizedData:GetStatisticsEntries()) or (data and data:GetStatisticsEntries()) or {} end })
createModule({ key = "preview", objectName = "Preview", title = "Preview Tuning (Dev)", subtitle = "Camera and model-position tuning data. For 3D item previews, click a vendor item's Preview button.", provider = function(data) return (Villa.NormalizedData and Villa.NormalizedData.GetPreviewEntries and Villa.NormalizedData:GetPreviewEntries()) or (data and data:GetPreviewEntries()) or {} end })
createModule({ key = "trainers_hv", objectName = "HVTrainers", title = "Villa Trainers+", subtitle = "Profession trainers (extended sources).", provider = function(data) return (Villa.NormalizedData and Villa.NormalizedData.GetTrainerEntries and Villa.NormalizedData:GetTrainerEntries()) or (data and data:GetTrainerEntries()) or {} end })
