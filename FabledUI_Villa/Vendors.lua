local Villa = _G.FabledUI_Villa
local Vendors = {}
Villa.Vendors = Vendors
Villa:RegisterModule("Vendors", Vendors)

Vendors.panelTitle = "Villa Vendors"
Vendors.panelSubtitle = "Browse housing vendors and their decor catalogs."
Vendors.frame = nil
Vendors.rows = {}
Vendors.filter = { currentZoneOnly = false, search = "", expansion = "ALL" }
Vendors.selectedIndex = 1

local VENDOR_EXPANSION_ORDER  = { "ALL", "Midnight", "The War Within", "Dragonflight", "Shadowlands", "BFA", "Legion", "WoD", "MoP", "Cata", "WotLK", "TBC", "Classic" }
local VENDOR_EXPANSION_LABELS = {
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

local function GetVendorRequirementText(vendor)
    if not vendor then
        return nil
    end
    local seen = {}
    for _, item in ipairs(vendor.items or {}) do
        local gate = item.requirementText or (item.itemID and Villa:GetDecorRequirementText(item.itemID))
        if gate then
            seen[gate] = true
        end
    end
    local parts = {}
    for gate in pairs(seen) do
        parts[#parts + 1] = gate
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, " • ") or (vendor.requirementLabel and (vendor.requirementLabel .. " gated") or nil)
end

local function GetFilteredWidth(scroll)
    return math.max(360, (scroll:GetWidth() or 430) - 24)
end

local function StringMatches(haystack, needle)
    haystack = (haystack or ""):lower()
    needle = (needle or ""):lower()
    return needle == "" or haystack:find(needle, 1, true) ~= nil
end

local function BuildVendorListBase()
    if Villa.HomeData and Villa.HomeData.GetMergedVendorList then
        return Villa.HomeData:GetMergedVendorList()
    end
    return {}
end

local function FilterVendors(vendors, filter)
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    local results = {}
    filter = filter or { currentZoneOnly = false, search = "" }
    for _, vendor in ipairs(vendors or {}) do
        local pass = true
        if filter.expansion and filter.expansion ~= "ALL" then
            pass = (vendor.expansion or "") == filter.expansion
        end
        if pass and filter.currentZoneOnly and currentMapID then
            local matched = false
            local locations = vendor.locations or {}
            if #locations == 0 then
                locations = { { mapID = vendor.mapID } }
            end
            for _, location in ipairs(locations) do
                if tonumber(location.mapID or vendor.mapID) == tonumber(currentMapID) then
                    matched = true
                    break
                end
            end
            pass = matched
        end
        if pass and filter.search ~= "" then
            local joined = table.concat({ vendor.name or "", vendor.zone or "", vendor.currency or "", vendor.requirementLabel or "", vendor.sourceSummary or "" }, " ")
            pass = StringMatches(joined, filter.search)
            if not pass then
                for _, item in ipairs(vendor.items or {}) do
                    local itemName = (Villa.HomeData and Villa.HomeData.GetDecorDisplayName and Villa.HomeData:GetDecorDisplayName(item)) or (item.name or "Decor")
                    local req = item.requirementText or (item.itemID and Villa:GetDecorRequirementText(item.itemID)) or ""
                    if StringMatches(itemName .. " " .. req, filter.search) then
                        pass = true
                        break
                    end
                end
            end
        end
        if pass then
            results[#results + 1] = vendor
        end
    end
    table.sort(results, function(a, b)
        if (a.expansion or "") ~= (b.expansion or "") then
            return (a.expansion or "") < (b.expansion or "")
        end
        if (a.zone or "") ~= (b.zone or "") then
            return (a.zone or "") < (b.zone or "")
        end
        return (a.name or "") < (b.name or "")
    end)
    return results
end

local function BuildProviderVendorList(providerTag, filter)
    local vendors = (Villa.NormalizedData and Villa.NormalizedData.GetVendorsByProvider and Villa.NormalizedData:GetVendorsByProvider(providerTag)) or {}
    return FilterVendors(vendors, filter)
end

local function MakeProviderSubtitle(providerLabel, vendor, emphasis)
    local owned, total = (Villa.HomeData and Villa.HomeData.GetVendorProgress and Villa.HomeData:GetVendorProgress(vendor)) or 0, #(vendor.items or {})
    local source = emphasis or vendor.requirementLabel or vendor.currency or providerLabel or vendor.sourceSummary or "source"
    local locationText = (vendor.locationCount and vendor.locationCount > 1) and (" • " .. tostring(vendor.locationCount) .. " locations") or ""
    return string.format("%s • %d/%d collected • %s%s", tostring(vendor.zone or "Unknown"), tonumber(owned or 0), tonumber(total or #(vendor.items or {})), tostring(source), locationText)
end

local VendorEngineVilla = {}
function VendorEngineVilla:GetVendorList(filter)
    return FilterVendors(BuildVendorListBase(), filter)
end
function VendorEngineVilla:GetVendorSubtitle(vendor)
    return string.format("%s • %s • %d items%s", tostring(vendor.zone or "Unknown"), tostring(vendor.currency or "unknown"), #(vendor.items or {}), (vendor.locationCount and vendor.locationCount > 1) and (" • " .. tostring(vendor.locationCount) .. " locations") or "")
end

local VendorEngineCodex = {}
function VendorEngineCodex:GetVendorList(filter)
    return FilterVendors(BuildVendorListBase(), filter)
end
function VendorEngineCodex:GetVendorSubtitle(vendor)
    return MakeProviderSubtitle("codex", vendor)
end

local VendorEngineHybrid = setmetatable({}, { __index = VendorEngineCodex })

Villa:RegisterEngine("vendors", "villa", VendorEngineVilla)
Villa:RegisterEngine("vendors", "codex", VendorEngineCodex)
Villa:RegisterEngine("vendors", "hybrid", VendorEngineHybrid)

local VendorEngineBetterHomes = {}
function VendorEngineBetterHomes:GetVendorList(filter)
    return BuildProviderVendorList("betterhomes", filter)
end
function VendorEngineBetterHomes:GetVendorSubtitle(vendor)
    return MakeProviderSubtitle("BetterHomes", vendor, vendor.expansion or "BetterHomes")
end


local VendorEngineHIT = {}
function VendorEngineHIT:GetVendorList(filter)
    return BuildProviderVendorList("hit", filter)
end
function VendorEngineHIT:GetVendorSubtitle(vendor)
    return MakeProviderSubtitle("HousingItemTracker", vendor, vendor.currency or "HousingItemTracker")
end

local VendorEngineDecorVendor = {}
function VendorEngineDecorVendor:GetVendorList(filter)
    return BuildProviderVendorList("decorvendor", filter)
end
function VendorEngineDecorVendor:GetVendorSubtitle(vendor)
    return MakeProviderSubtitle("DecorVendor", vendor, vendor.expansion or vendor.currency or "DecorVendor")
end


local VendorEngineHousingVendor = {}
function VendorEngineHousingVendor:GetVendorList(filter)
    return BuildProviderVendorList("housingvendor", filter)
end
function VendorEngineHousingVendor:GetVendorSubtitle(vendor)
    return MakeProviderSubtitle("HousingVendor", vendor, vendor.requirementLabel or vendor.currency or "HousingVendor")
end

local VendorEngineHDG = setmetatable({}, { __index = VendorEngineCodex })
Villa:RegisterEngine("vendors", "betterhomes", VendorEngineBetterHomes)
Villa:RegisterEngine("vendors", "hit", VendorEngineHIT)
Villa:RegisterEngine("vendors", "decorvendor", VendorEngineDecorVendor)
Villa:RegisterEngine("vendors", "hdg", VendorEngineHDG)
Villa:RegisterEngine("vendors", "housingvendor", VendorEngineHousingVendor)

function Vendors:GetEngine()
    return Villa:GetEngine("vendors") or VendorEngineCodex
end

function Vendors:GetFilteredVendors()
    local engine = self:GetEngine()
    if engine and engine.GetVendorList then
        return engine:GetVendorList(self.filter)
    end
    return {}
end

function Vendors:GetSelectedVendor(vendors)
    vendors = vendors or self:GetFilteredVendors()
    if #vendors == 0 then
        return nil
    end
    self.selectedIndex = math.min(math.max(self.selectedIndex or 1, 1), #vendors)
    return vendors[self.selectedIndex]
end

function Vendors:CreatePanel(parent)
    if self.frame then
        return self.frame
    end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

-- Compact neon icon button — replaces the wide text action buttons (Waypoint /
-- View Req / Preview). The label lives in the tooltip so meaning stays clear.
local ICON_WAYPOINT = "Interface\\Icons\\Ability_Hunter_Pathfinding"
local ICON_PREVIEW  = "Interface\\Icons\\INV_Misc_Spyglass_02"
local ICON_VIEWREQ  = "Interface\\Icons\\INV_Misc_Book_09"

local function CreateIconButton(parent, iconTexture, tipTitle, tipBody, size)
    size = size or 26
    local UI = Villa.UI
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)

    local base  = (UI and UI.InsetBG) and { UI.InsetBG[1], UI.InsetBG[2], UI.InsetBG[3], 0.92 } or { 0.05, 0.06, 0.12, 0.92 }
    local hover = (UI and UI.RowBG) and { UI.RowBG[1], UI.RowBG[2], UI.RowBG[3], 0.98 } or { 0.09, 0.11, 0.19, 0.98 }

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(base[1], base[2], base[3], base[4])
    b.Bg = bg

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(iconTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.Icon = icon

    local TK = rawget(_G, "FabledUI_UIToolkit")
    if TK and TK.Effects and type(TK.Effects.AddNeonBorder) == "function" then
        local col = (UI and UI.RowBorder) or { 0.36, 0.31, 0.62, 0.7 }
        pcall(TK.Effects.AddNeonBorder, TK.Effects, b, col, 1)
    end

    b:SetScript("OnEnter", function(self)
        self.Bg:SetColorTexture(hover[1], hover[2], hover[3], hover[4])
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tipTitle)
        if tipBody then GameTooltip:AddLine(tipBody, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.Bg:SetColorTexture(base[1], base[2], base[3], base[4])
        GameTooltip_Hide()
    end)
    b:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)
    b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    return b
end

function Vendors:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then
        return
    end
    frame._initialized = true

    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetPoint("TOPLEFT", 16, -62)
    topRow:SetPoint("TOPRIGHT", -16, -62)
    topRow:SetHeight(24)

    local zone = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
    zone:SetSize(92, 22)
    zone:SetPoint("LEFT", 0, 0)
    zone:SetText("This Zone")
    zone:SetScript("OnClick", function()
        self.filter.currentZoneOnly = not self.filter.currentZoneOnly
        self:Refresh()
    end)
    self.zoneButton = zone

    -- Mode cycler removed from the toolbar: Villa presents a uniform view
    -- regardless of which donor engine backs the data. The engine is still
    -- settable via /villa mode and Settings; it defaults to the aggregate
    -- "hybrid". (Refresh() guards on self.modeButton, so nil is safe.)
    self.modeButton = nil

    local search = CreateFrame("EditBox", nil, topRow, "InputBoxTemplate")
    search:SetSize(240, 22)
    search:SetPoint("LEFT", zone, "RIGHT", 10, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(box)
        self.filter.search = box:GetText() or ""
        self.selectedIndex = 1
        self:Refresh()
    end)
    self.searchBox = search

    local expBtn = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
    expBtn:SetSize(140, 22)
    expBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
    expBtn:SetText(VENDOR_EXPANSION_LABELS[self.filter.expansion] or "All Expansions")
    expBtn:SetScript("OnClick", function(btn)
        local menuList = {}
        for _, key in ipairs(VENDOR_EXPANSION_ORDER) do
            local k = key
            menuList[#menuList + 1] = {
                text = VENDOR_EXPANSION_LABELS[k] or k,
                notCheckable = true,
                func = function()
                    self.filter.expansion = k
                    self.selectedIndex = 1
                    btn:SetText(VENDOR_EXPANSION_LABELS[k] or k)
                    self:Refresh()
                end,
            }
        end
        if _G.MenuUtil and type(_G.MenuUtil.CreateContextMenu) == "function" then
            local ok = pcall(MenuUtil.CreateContextMenu, btn, function(_, rootDescription)
                for _, entry in ipairs(menuList) do
                    rootDescription:CreateButton(entry.text, entry.func)
                end
            end)
            if ok then return end
        end
        if _G.EasyMenu then
            EasyMenu(menuList, CreateFrame("Frame", "VillaExpDropContext", UIParent), btn, 0, -4, "MENU")
        end
    end)
    self.expButton = expBtn

    local rescan = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
    rescan:SetSize(78, 22)
    rescan:SetPoint("LEFT", expBtn, "RIGHT", 8, 0)
    rescan:SetText("Rescan")
    if Villa.UI then Villa.UI:StyleButton(rescan) end
    rescan:SetScript("OnClick", function()
        -- Force a fresh pass. Collection status is read live from C_HousingCatalog
        -- on every refresh, so this re-scans bags/bank for owned decor, re-syncs
        -- related surfaces, and re-renders — an obvious "update now" control.
        if Villa.LiveCounts and type(Villa.LiveCounts.ScanBags) == "function" then
            Villa.LiveCounts:ScanBags()
        end
        if Villa.MapPins and type(Villa.MapPins.RefreshAllData) == "function" then
            Villa.MapPins:RefreshAllData()
        end
        self:Refresh()
        Villa:Print("Rescan complete. " .. ((self.summaryText and self.summaryText:GetText()) or ""))
    end)
    rescan:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText("Rescan")
        GameTooltip:AddLine("Re-read your collection status and refresh the list.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Collection status also updates automatically when you collect or place decor.", 0.6, 0.85, 1.0, true)
        GameTooltip:Show()
    end)
    rescan:SetScript("OnLeave", GameTooltip_Hide)
    self.rescanButton = rescan

    local summary = topRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", rescan, "RIGHT", 12, 0)
    summary:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
    summary:SetJustifyH("RIGHT")
    self.summaryText = summary

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -92)
    scroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 18)
    scroll:SetWidth(430)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.content = content

    local detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 12, 0)
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

    local gate = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gate:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    gate:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    gate:SetJustifyH("LEFT")
    gate:SetWordWrap(true)
    self.detailGate = gate

    local itemsHeader = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemsHeader:SetPoint("TOPLEFT", gate, "BOTTOMLEFT", 0, -12)
    itemsHeader:SetText("Decor Catalog")

    local itemScroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", itemsHeader, "BOTTOMLEFT", 0, -8)
    itemScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -28, 46)

    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetSize(1, 1)
    itemScroll:SetScrollChild(itemContent)
    self.itemScroll = itemScroll
    self.itemContent = itemContent
    self.itemRows = {}

    local waypoint = CreateIconButton(detail, ICON_WAYPOINT, "Waypoint", "Set a map waypoint / route to this vendor.", 28)
    waypoint:SetPoint("BOTTOMLEFT", 12, 12)
    waypoint:SetScript("OnClick", function()
        local vendor = self.currentVendor
        if not vendor then return end
        local mapID, x, y = Villa.HomeData:GetVendorWaypoint(vendor)
        if not (mapID and x and y) then
            Villa:Print("No map location stored for " .. (vendor.name or "this vendor") .. ".")
            return
        end
        if Villa:SetWaypoint(mapID, x, y, vendor.name) then
            Villa:Print("Waypoint set: " .. (vendor.name or "vendor"))
        else
            Villa:Print("Could not set a waypoint — no provider (Odyssey/TomTom/Blizzard) available.")
        end
    end)
    self.detailWaypoint = waypoint

    local previewBtn = CreateIconButton(detail, ICON_PREVIEW, "Preview", "Show a preview of this vendor's decor.", 28)
    previewBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    previewBtn:SetScript("OnClick", function()
        local vendor = self.currentVendor
        if not vendor then return end
        -- Preview the vendor's first previewable decor (itemID or decorID).
        local itemID, decorID
        for _, item in ipairs(vendor.items or {}) do
            if item.itemID or item.decorID then
                itemID, decorID = item.itemID, item.decorID
                break
            end
        end
        local TK = rawget(_G, "FabledUI_UIToolkit")
        if TK and TK.Preview and (itemID or decorID) then
            TK.Preview:Show(itemID, previewBtn, decorID)
        end
    end)
    previewBtn:Hide()
    self.detailPreviewButton = previewBtn
end

function Vendors:RefreshDetail(vendor)
    if not self.detailFrame then
        return
    end
    self.currentVendor = vendor
    if not vendor then
        self.detailTitle:SetText("No vendor selected")
        self.detailSubtitle:SetText("Pick a vendor from the list.")
        self.detailGate:SetText("")
        self.detailWaypoint:Disable()
        if self.detailReqButton then
            self.detailReqButton:Hide()
        end
        if self.detailPreviewButton then
            self.detailPreviewButton:Hide()
        end
        self.itemContent:SetHeight(1)
        return
    end

    self.detailTitle:SetText(vendor.name or "Unknown Vendor")
    local owned, total = Villa.HomeData:GetVendorProgress(vendor)
    self.detailSubtitle:SetText(((self:GetEngine().GetVendorSubtitle and self:GetEngine():GetVendorSubtitle(vendor)) or (vendor.zone or "Unknown")) .. ((vendor.locationCount and vendor.locationCount > 1) and (" • " .. tostring(vendor.locationCount) .. " locations") or ""))
    local gateText = GetVendorRequirementText(vendor) or "No known acquisition gate metadata yet."

    -- KleosCriteria: enhance vendor-level gate text with progress info
    local KC = _G.KleosCriteria
    if KC and KC.IsAvailable and KC:IsAvailable() and gateText ~= "No known acquisition gate metadata yet." then
        local descText, progress, done = KC:Describe(gateText)
        if descText then
            local progressSuffix = ""
            if done then
                progressSuffix = " |cff00ff00(Complete)|r"
            elseif progress then
                progressSuffix = " |cffffff00(" .. tostring(progress) .. ")|r"
            end
            gateText = descText .. progressSuffix
        end
    end

    self.detailGate:SetText(string.format("%s\nCollection progress: %d/%d", gateText, owned, total))
    self.detailWaypoint:Enable()

    -- KleosCriteria: "View Requirement" button on the detail panel
    if self.detailReqButton then
        self.detailReqButton:Hide()
    end
    local vendorReqText = GetVendorRequirementText(vendor)
    if vendorReqText and KC and KC.IsAvailable and KC:IsAvailable() then
        if not self.detailReqButton then
            local btn = CreateIconButton(self.detailFrame, ICON_VIEWREQ, "View Requirement",
                "Open the achievement or quest UI for this vendor's requirement.", 28)
            btn:SetPoint("BOTTOMLEFT", self.detailWaypoint, "BOTTOMRIGHT", 8, 0)
            self.detailReqButton = btn
        end
        local capturedReq = vendorReqText
        self.detailReqButton:SetScript("OnClick", function()
            if KC and KC.Open then
                KC:Open(capturedReq)
            end
        end)
        self.detailReqButton:Show()
    end

    -- Show/hide the preview button based on whether any item has an itemID
    if self.detailPreviewButton then
        local hasPreviewable = false
        for _, item in ipairs(vendor.items or {}) do
            if item.itemID or item.decorID then
                hasPreviewable = true
                break
            end
        end
        self.detailPreviewButton:SetShown(hasPreviewable)
    end

    for _, row in ipairs(self.itemRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.itemRows = {}

    local width = math.max(250, (self.itemScroll:GetWidth() or 300) - 24)
    local y = 0
    for _, item in ipairs(vendor.items or {}) do
        local row = CreateFrame("Button", nil, self.itemContent, "BackdropTemplate")
        row:SetSize(width, 46)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        row:SetBackdropColor(0.06, 0.08, 0.16, 0.90)
        row:SetBackdropBorderColor(0.32, 0.36, 0.48, 0.80)

        local name = (Villa.HomeData and Villa.HomeData.GetDecorDisplayName and Villa.HomeData:GetDecorDisplayName(item)) or (item.name or "Decor")
        local known = Villa.HomeData and Villa.HomeData.IsEntryCollected and Villa.HomeData:IsEntryCollected(item)

        -- Ownership badge (owned count) keyed by decorID — the reliable key.
        local badge = ""
        local ownedCount = (item.decorID and Villa.GetDecorOwnedCount and Villa:GetDecorOwnedCount(item.decorID)) or 0
        if ownedCount > 0 then
            badge = " |cff5cf0a0\195\151" .. ownedCount .. "|r"
        elseif known then
            badge = " |cff888888\226\156\147|r"
        end

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetPoint("RIGHT", row, "RIGHT", ((item.itemID or item.decorID) and -34 or -12), 0)
        title:SetJustifyH("LEFT")
        title:SetText(name .. badge .. (known and " |cff5cf0a0• Known|r" or ""))

        local sourceInfo = item.itemID and Villa:GetDecorSourceInfo(item.itemID) or item
        local reqText = item.requirementText or (sourceInfo and sourceInfo.requirementText) or nil
        local bodyText = sourceInfo and (sourceInfo.requirementText or sourceInfo.sourceLabel or "Source data available") or (item.decorID and ("Decor #" .. item.decorID) or "Source data unavailable")

        -- KleosCriteria deep-linking: enhance requirement display with progress info
        local KC = _G.KleosCriteria
        local hasKleosReq = false
        if reqText and KC and KC.IsAvailable and KC:IsAvailable() then
            local descText, progress, done = KC:Describe(reqText)
            if descText then
                local progressSuffix = ""
                if done then
                    progressSuffix = " |cff00ff00(Complete)|r"
                elseif progress then
                    progressSuffix = " |cffffff00(" .. tostring(progress) .. ")|r"
                end
                bodyText = descText .. progressSuffix
                hasKleosReq = true
            end
        end

        -- Prefer our own VERIFIED captured cost (real gold/currency scanned from
        -- the live vendor) over the unreliable donor requirement text.
        if item.decorID and Villa.VendorCapture and Villa.VendorCapture.GetCostText then
            local costText = Villa.VendorCapture:GetCostText(item.decorID)
            if costText and costText ~= "" then
                bodyText = "|cffffd100" .. costText .. "|r  ·  " .. bodyText
            end
        end

        local body = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        body:SetPoint("BOTTOMLEFT", 10, 8)
        body:SetPoint("RIGHT", row, "RIGHT", (hasKleosReq and -34 or -12), 0)
        body:SetJustifyH("LEFT")
        body:SetText(bodyText)

        -- KleosCriteria: "View Requirement" button for deep-linking
        if hasKleosReq and reqText then
            local viewReqBtn = CreateIconButton(row, ICON_VIEWREQ, "View Requirement",
                "Open the achievement or quest UI for this requirement.", 20)
            viewReqBtn:SetPoint("BOTTOMRIGHT", -8, 6)
            local capturedReq = reqText
            viewReqBtn:SetScript("OnClick", function()
                if KC and KC.Open then
                    KC:Open(capturedReq)
                end
            end)
        end

        -- Per-item 3D preview button
        if item.itemID or item.decorID then
            local itemPreviewBtn = CreateIconButton(row, ICON_PREVIEW, "Preview",
                "Show a 3D preview of this decor.", 20)
            itemPreviewBtn:SetPoint("TOPRIGHT", -8, -6)
            local capturedItemID = item.itemID
            local capturedDecorID = item.decorID
            itemPreviewBtn:SetScript("OnClick", function(btn)
                local TK = rawget(_G, "FabledUI_UIToolkit")
                if TK and TK.Preview then
                    TK.Preview:Show(capturedItemID, btn, capturedDecorID)
                end
            end)
        end

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- Build from the catalog record (by decorID). The donor itemID is
            -- unreliable and can resolve to unrelated gear, so do NOT SetItemByID it.
            local info = item.decorID and Villa.GetDecorRecordInfo and Villa:GetDecorRecordInfo(item.decorID) or nil
            GameTooltip:SetText((info and info.name) or name, 1, 1, 1)
            GameTooltip:AddLine("Housing Decor", 0.55, 0.82, 1.0)
            local owned = item.decorID and Villa.IsDecorRecordCollected and Villa:IsDecorRecordCollected(item.decorID)
            if owned then
                GameTooltip:AddLine("Collected", 0.36, 0.94, 0.63)
            else
                GameTooltip:AddLine("Not collected", 1.0, 0.30, 0.42)
            end
            if item.requirementText and item.requirementText ~= "" then
                GameTooltip:AddLine(item.requirementText, 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseUp", function(rowFrame, button)
            if button == "RightButton" then
                if item.itemID and Villa.ShoppingList then
                    -- Show a context menu with shopping list options plus waypoint
                    local menuList = {
                        { text = "Add to Shopping List", isTitle = true, notCheckable = true },
                    }
                    local names = {}
                    for name in pairs(Villa.ShoppingList:GetAll()) do
                        names[#names + 1] = name
                    end
                    table.sort(names)
                    for _, listName in ipairs(names) do
                        local capturedName = listName
                        menuList[#menuList + 1] = {
                            text         = capturedName,
                            notCheckable = true,
                            func         = function()
                                Villa.ShoppingList:AddItem(capturedName, item.itemID, 1, "vendor")
                                Villa:Print("Added to list: " .. capturedName)
                            end,
                        }
                    end
                    menuList[#menuList + 1] = {
                        text         = "New List...",
                        notCheckable = true,
                        func         = function()
                            Villa.ShoppingList:PromptNewList()
                        end,
                    }
                    menuList[#menuList + 1] = { text = "", disabled = true, notCheckable = true }
                    if Villa.Wishlist and item.itemID then
                        local capturedID = item.itemID
                        menuList[#menuList + 1] = {
                            text         = "Add to Wishlist",
                            notCheckable = true,
                            func         = function()
                                Villa.Wishlist:ShowAddMenu(capturedID, rowFrame)
                            end,
                        }
                    end
                    menuList[#menuList + 1] = {
                        text         = "Set Waypoint",
                        notCheckable = true,
                        func         = function()
                            local mapID, x, y = Villa.HomeData:GetVendorWaypoint(vendor)
                            Villa:SetWaypoint(mapID, x, y, vendor.name)
                        end,
                    }
                    -- 12.0.5: prefer MenuUtil; EasyMenu removed in modern clients.
                    local shown = false
                    if _G.MenuUtil and type(_G.MenuUtil.CreateContextMenu) == "function" then
                        shown = pcall(MenuUtil.CreateContextMenu, rowFrame, function(_, rootDescription)
                            for _, menuItem in ipairs(menuList) do
                                if menuItem.isTitle then
                                    rootDescription:CreateTitle(menuItem.text)
                                elseif not menuItem.disabled and menuItem.func then
                                    rootDescription:CreateButton(menuItem.text, menuItem.func)
                                end
                            end
                        end)
                    end
                    if not shown and _G.EasyMenu then
                        EasyMenu(menuList, _G.DropDownList1 or UIParent, rowFrame, 0, 0, "MENU")
                        shown = true
                    end
                    if not shown then
                        -- Fallback: set waypoint directly on right-click
                        local mapID, x, y = Villa.HomeData:GetVendorWaypoint(vendor)
                        Villa:SetWaypoint(mapID, x, y, vendor.name)
                    end
                else
                    local mapID, x, y = Villa.HomeData:GetVendorWaypoint(vendor)
                    Villa:SetWaypoint(mapID, x, y, vendor.name)
                end
            end
        end)

        self.itemRows[#self.itemRows + 1] = row
        y = y + 50
    end
    self.itemContent:SetWidth(width)
    self.itemContent:SetHeight(math.max(1, y))
end

function Vendors:Refresh()
    if not self.content or not self.scroll then
        return
    end

    if self.zoneButton then
        self.zoneButton:SetText(self.filter.currentZoneOnly and "|cff00ff00This Zone|r" or "This Zone")
    end
    if self.modeButton then
        self.modeButton:SetText("Mode: " .. (Villa:GetActiveMode("vendors") or "none"))
    end
    if self.expButton then
        self.expButton:SetText(VENDOR_EXPANSION_LABELS[self.filter.expansion] or "All Expansions")
    end

    for _, row in ipairs(self.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(self.rows)

    local vendors = self:GetFilteredVendors()
    local selected = self:GetSelectedVendor(vendors)
    local totalItems, ownedItems = 0, 0
    for _, vendor in ipairs(vendors) do
        local owned, total = Villa.HomeData:GetVendorProgress(vendor)
        totalItems = totalItems + total
        ownedItems = ownedItems + owned
    end
    if self.summaryText then
        self.summaryText:SetText(string.format("%d vendors • %d/%d collected", #vendors, ownedItems, totalItems))
    end
    local y = 0
    local width = GetFilteredWidth(self.scroll)

    for index, vendor in ipairs(vendors) do
        local isSelected = vendor == selected
        local visited = (Villa.VendorVisits and Villa.VendorVisits.IsVisited and Villa.VendorVisits:IsVisited(vendor)) or false
        local row = CreateFrame("Button", nil, self.content, "BackdropTemplate")
        row:SetSize(width, 64)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        row:SetBackdropColor(isSelected and 0.09 or 0.05, isSelected and 0.11 or 0.07, isSelected and 0.20 or 0.15, 0.92)
        row:SetBackdropBorderColor(isSelected and 0.75 or 0.45, isSelected and 0.65 or 0.45, isSelected and 0.25 or 0.52, 0.85)
        if visited and not isSelected then
            row:SetAlpha(0.72)
        else
            row:SetAlpha(1.0)
        end
        row:SetScript("OnClick", function()
            self.selectedIndex = index
            self:Refresh()
        end)

        if visited then
            local check = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            check:SetPoint("TOPRIGHT", row, "TOPRIGHT", -110, -10)
            check:SetText("|cff66ff66✓|r")
            check:SetJustifyH("RIGHT")
        end

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetPoint("RIGHT", row, "RIGHT", -120, 0)
        title:SetJustifyH("LEFT")
        title:SetText(vendor.name)

        local subtitle = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        subtitle:SetPoint("BOTTOMLEFT", 10, 10)
        subtitle:SetPoint("RIGHT", row, "RIGHT", -120, 0)
        subtitle:SetJustifyH("LEFT")
        local owned, total = Villa.HomeData:GetVendorProgress(vendor)
        subtitle:SetText(((self:GetEngine().GetVendorSubtitle and self:GetEngine():GetVendorSubtitle(vendor)) or (vendor.zone or "Unknown")) .. ((vendor.locationCount and vendor.locationCount > 1) and (" • " .. tostring(vendor.locationCount) .. " locations") or "") .. string.format(" • %d/%d", owned, total))

        local pin = CreateIconButton(row, ICON_WAYPOINT, "Waypoint",
            "Set a map waypoint / route to this vendor.", 26)
        pin:SetPoint("RIGHT", -10, 0)
        pin:SetScript("OnClick", function()
            local mapID, x, y = Villa.HomeData:GetVendorWaypoint(vendor)
            if not (mapID and x and y) then
                Villa:Print("No map location stored for " .. (vendor.name or "this vendor") .. ".")
                return
            end
            if Villa:SetWaypoint(mapID, x, y, vendor.name) then
                Villa:Print("Waypoint set: " .. (vendor.name or "vendor"))
            else
                Villa:Print("Could not set a waypoint — no provider available.")
            end
        end)

        self.rows[#self.rows + 1] = row
        y = y + 70
    end

    self.content:SetWidth(width)
    self.content:SetHeight(math.max(1, y))
    self:RefreshDetail(selected)
end

function Vendors:OnEnable()
    -- 12.x (Midnight): unit GUIDs/names read from tainted addon code can come
    -- back as secret values that throw when indexed or concatenated. Same guard
    -- as Villa_VendorVisits.lua / Villa_VendorCapture.lua.
    local issecretvalue = _G.issecretvalue or function() return false end

    local f = CreateFrame("Frame")
    f:RegisterEvent("MERCHANT_SHOW")
    f:SetScript("OnEvent", function()
        local guid = UnitGUID("target")
        if not guid or issecretvalue(guid) then
            return
        end
        local npcID = tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        if not npcID then
            return
        end

        local mapID, x, y = Villa:GetPlayerMapPosition()
        if not mapID or not x or not y then
            return
        end

        Villa.db.customVendors = Villa.db.customVendors or {}
        for _, vendor in ipairs(Villa.db.customVendors) do
            if vendor.npcID == npcID then
                return
            end
        end

        local targetName = UnitName("target")
        if targetName and issecretvalue(targetName) then targetName = nil end

        table.insert(Villa.db.customVendors, {
            npcID = npcID,
            name = targetName or "Unknown Vendor",
            zone = GetZoneText() or "Unknown Zone",
            mapID = mapID,
            x = x,
            y = y,
            expansion = "misc",
            currency = "unknown",
            items = {},
        })
    end)
end
