local Villa = _G.FabledUI_Villa
local Checklist = {}
Villa.Checklist = Checklist
Villa:RegisterModule("Checklist", Checklist)

Checklist.panelTitle = "Checklist"
Checklist.panelSubtitle = "Completionist view: every decor item and its collection status."

-- ============================================================
-- Internal state
-- ============================================================

local allItems      = {}   -- built once per session, rebuilt on demand
local filteredItems = {}   -- after search + filter
local filterState   = {
    search       = "",
    showCollected = true,
    showMissing   = true,
}

-- ============================================================
-- Data helpers
-- ============================================================

local function GetItemName(itemID)
    if not itemID then return "Item #?" end
    local name = C_Item and C_Item.GetItemInfo and select(1, C_Item.GetItemInfo(itemID))
    if not name and GetItemInfo then
        name = GetItemInfo(itemID)
    end
    return name or ("Item #" .. tostring(itemID))
end

local function BuildItemList()
    local seen = {}
    local out  = {}

    -- 1. Vendor items from HomeData
    if Villa.HomeData and Villa.HomeData.GetMergedVendorList then
        for _, vendor in ipairs(Villa.HomeData:GetMergedVendorList()) do
            for _, item in ipairs(vendor.items or {}) do
                local id = tonumber(item.itemID)
                if id and not seen[id] then
                    seen[id] = true
                    out[#out + 1] = { itemID = id }
                end
            end
        end
    end

    -- 2. C_HousingCatalog full scan
    if C_HousingCatalog then
        local numItems = C_HousingCatalog.GetNumDecorInCatalog and C_HousingCatalog.GetNumDecorInCatalog() or 0
        if C_HousingCatalog.GetCatalogEntryInfo then
            for i = 1, numItems do
                local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfo, i)
                if ok and info and info.itemID and not seen[tonumber(info.itemID)] then
                    local id = tonumber(info.itemID)
                    seen[id] = true
                    out[#out + 1] = { itemID = id }
                end
            end
        end
    end

    return out
end

local function EnrichAndFilter()
    filteredItems = {}
    local needle = (filterState.search or ""):lower()

    for _, entry in ipairs(allItems) do
        local state = Villa:GetCollectionState(entry.itemID)
        local name  = state.name or GetItemName(entry.itemID)
        local collected = state.known

        -- filter: collected / missing
        if collected and not filterState.showCollected then
            -- skip
        elseif not collected and not filterState.showMissing then
            -- skip
        else
            -- filter: search text
            if needle == "" or (name or ""):lower():find(needle, 1, true) then
                filteredItems[#filteredItems + 1] = {
                    itemID    = entry.itemID,
                    name      = name,
                    collected = collected,
                    stored    = state.stored or 0,
                    placed    = state.placed or 0,
                    total     = state.total  or 0,
                }
            end
        end
    end

    -- sort: missing first, then alphabetical
    table.sort(filteredItems, function(a, b)
        if a.collected ~= b.collected then
            return not a.collected  -- missing first
        end
        return (a.name or "") < (b.name or "")
    end)
end

-- ============================================================
-- Panel creation
-- ============================================================

function Checklist:CreatePanel(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

-- ============================================================
-- UI initialisation (called once)
-- ============================================================

function Checklist:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then return end
    frame._initialized = true

    local yTop = -62

    -- ---------- Summary line ----------
    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", 18, yTop)
    summary:SetJustifyH("LEFT")
    self.summaryLabel = summary

    -- ---------- Search box ----------
    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(200, 22)
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, yTop + 2)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
    searchLabel:SetText("Search:")

    searchBox:SetScript("OnTextChanged", function(self)
        filterState.search = self:GetText() or ""
        Checklist:ApplyFilterAndRefreshRows()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.searchBox = searchBox

    -- ---------- Filter checkboxes ----------
    local cbY = yTop - 28

    local cbCollected = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cbCollected:SetSize(24, 24)
    cbCollected:SetPoint("TOPLEFT", 18, cbY)
    cbCollected:SetChecked(filterState.showCollected)
    cbCollected:SetScript("OnClick", function(self)
        filterState.showCollected = self:GetChecked()
        Checklist:ApplyFilterAndRefreshRows()
    end)
    local cbCollectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbCollectedLabel:SetPoint("LEFT", cbCollected, "RIGHT", 2, 0)
    cbCollectedLabel:SetText("Show Collected")

    local cbMissing = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cbMissing:SetSize(24, 24)
    cbMissing:SetPoint("LEFT", cbCollectedLabel, "RIGHT", 14, 0)
    cbMissing:SetChecked(filterState.showMissing)
    cbMissing:SetScript("OnClick", function(self)
        filterState.showMissing = self:GetChecked()
        Checklist:ApplyFilterAndRefreshRows()
    end)
    local cbMissingLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbMissingLabel:SetPoint("LEFT", cbMissing, "RIGHT", 2, 0)
    cbMissingLabel:SetText("Show Missing")

    self.cbCollected = cbCollected
    self.cbMissing   = cbMissing

    -- ---------- Column headers ----------
    local headerY = cbY - 28
    local hdrFrame = CreateFrame("Frame", nil, frame)
    hdrFrame:SetPoint("TOPLEFT", 18, headerY)
    hdrFrame:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    hdrFrame:SetHeight(18)

    local hName = hdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hName:SetPoint("LEFT", 6, 0)
    hName:SetText("Item Name")

    local hStatus = hdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hStatus:SetPoint("RIGHT", hdrFrame, "RIGHT", -180, 0)
    hStatus:SetText("Status")

    local hStored = hdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hStored:SetPoint("RIGHT", hdrFrame, "RIGHT", -110, 0)
    hStored:SetText("Stored")

    local hPlaced = hdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hPlaced:SetPoint("RIGHT", hdrFrame, "RIGHT", -40, 0)
    hPlaced:SetText("Placed")

    -- ---------- Scroll area ----------
    local scrollY = headerY - 22
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 18, scrollY)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -38, 18)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.rows        = {}
end

-- ============================================================
-- Row rendering
-- ============================================================

local ROW_HEIGHT = 24
local ROW_GAP    = 2

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameFs:SetPoint("LEFT", 6, 0)
    nameFs:SetPoint("RIGHT", row, "RIGHT", -220, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetWordWrap(false)
    row.nameFs = nameFs

    local statusFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusFs:SetPoint("RIGHT", row, "RIGHT", -160, 0)
    statusFs:SetWidth(60)
    statusFs:SetJustifyH("CENTER")
    row.statusFs = statusFs

    local storedFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    storedFs:SetPoint("RIGHT", row, "RIGHT", -100, 0)
    storedFs:SetWidth(50)
    storedFs:SetJustifyH("CENTER")
    row.storedFs = storedFs

    local placedFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placedFs:SetPoint("RIGHT", row, "RIGHT", -30, 0)
    placedFs:SetWidth(50)
    placedFs:SetJustifyH("CENTER")
    row.placedFs = placedFs

    -- tooltip on hover
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self._itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self._itemID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

function Checklist:ApplyFilterAndRefreshRows()
    EnrichAndFilter()
    self:RefreshRows()
end

function Checklist:RefreshRows()
    if not self.scrollChild then return end

    -- hide existing rows
    for _, row in ipairs(self.rows) do
        row:Hide()
    end

    local width = math.max(300, (self.scrollFrame:GetWidth() or 400) - 10)
    local collectedCount = 0
    local totalCount     = #allItems

    -- count collected from full (unfiltered) list for summary
    for _, entry in ipairs(allItems) do
        local state = Villa:GetCollectionState(entry.itemID)
        if state.known then
            collectedCount = collectedCount + 1
        end
    end

    -- summary
    local pct = totalCount > 0 and math.floor((collectedCount / totalCount) * 100) or 0
    if self.summaryLabel then
        self.summaryLabel:SetText(string.format("Collected: %d / %d  (%d%%)", collectedCount, totalCount, pct))
    end

    -- render filtered rows
    local y = 0
    for i, data in ipairs(filteredItems) do
        local row = self.rows[i]
        if not row then
            row = CreateRow(self.scrollChild, i)
            self.rows[i] = row
        end

        row:SetWidth(width)
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -y)
        row._itemID = data.itemID

        -- alternating background
        local even = (i % 2 == 0)
        if data.collected then
            row:SetBackdropColor(0.04, even and 0.10 or 0.08, 0.04, 0.85)
            row:SetBackdropBorderColor(0.20, 0.40, 0.20, 0.60)
        else
            row:SetBackdropColor(even and 0.10 or 0.08, 0.04, 0.04, 0.85)
            row:SetBackdropBorderColor(0.40, 0.20, 0.20, 0.60)
        end

        row.nameFs:SetText(data.name or ("Item #" .. tostring(data.itemID)))

        if data.collected then
            row.statusFs:SetText("|cff44ff44\226\156\148|r")
        else
            row.statusFs:SetText("|cffff4444\226\156\150|r")
        end

        row.storedFs:SetText(tostring(data.stored))
        row.placedFs:SetText(tostring(data.placed))

        row:Show()
        y = y + ROW_HEIGHT + ROW_GAP
    end

    self.scrollChild:SetWidth(width)
    self.scrollChild:SetHeight(math.max(1, y))
end

-- ============================================================
-- Refresh (called each time panel is shown)
-- ============================================================

function Checklist:Refresh()
    if not self.frame then return end
    self:InitUI(self.frame)

    -- rebuild master item list (cheap re-scan each open)
    allItems = BuildItemList()

    self:ApplyFilterAndRefreshRows()
end
