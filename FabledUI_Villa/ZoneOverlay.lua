local Villa = _G.FabledUI_Villa
local ZoneOverlay = {}
Villa.ZoneOverlay = ZoneOverlay
Villa:RegisterModule("ZoneOverlay", ZoneOverlay)

ZoneOverlay.rows = {}
ZoneOverlay.expandedCategories = ZoneOverlay.expandedCategories or { vendors = true }
ZoneOverlay.expandedVendors = ZoneOverlay.expandedVendors or {}

local function GetContainer()
    if WorldMapFrame and WorldMapFrame.ScrollContainer then
        return WorldMapFrame.ScrollContainer
    end
    return WorldMapFrame
end

local function GetMapGroupYOffset(mapID)
    if not mapID or not C_Map or not C_Map.GetMapGroupID then
        return -6
    end
    return C_Map.GetMapGroupID(mapID) and -31 or -6
end

local function BuildVendorSectionsForMap(mapID, includeCollected)
    local grouped = {}
    if Villa.HomeData and Villa.HomeData.IterVendorSourcesForMap then
        for _, entry in ipairs(Villa.HomeData:IterVendorSourcesForMap(mapID, true)) do
            if includeCollected or not entry.isCollected then
                local key = tostring(entry.vendorKey or table.concat({ tostring(entry.vendorName or "Unknown Vendor"), tostring(entry.mapID or 0), tostring(entry.x or 0), tostring(entry.y or 0) }, "|"))
                grouped[key] = grouped[key] or {
                    categoryKey = "vendors",
                    label = "Vendors",
                    sourceName = entry.vendorName or "Unknown Vendor",
                    mapID = entry.mapID,
                    x = entry.x,
                    y = entry.y,
                    cityName = entry.cityName,
                    requirementText = entry.requirementText,
                    items = {},
                }
                grouped[key].items[#grouped[key].items + 1] = entry
            end
        end
    end

    local vendors = {}
    for key, vendor in pairs(grouped) do
        table.sort(vendor.items, function(a, b)
            return (a.name or "") < (b.name or "")
        end)
        vendor.key = key
        vendors[#vendors + 1] = vendor
    end
    table.sort(vendors, function(a, b)
        if (a.sourceName or "") ~= (b.sourceName or "") then
            return (a.sourceName or "") < (b.sourceName or "")
        end
        return tostring(a.cityName or "") < tostring(b.cityName or "")
    end)
    return vendors
end

local function BuildOverlayFlatData(mapID, style)
    local includeCollected = Villa.settings.includeCollectedVendorDecor
    local vendors = BuildVendorSectionsForMap(mapID, includeCollected)
    local flat = {}
    local totalSources, collectedSources = 0, 0
    for _, vendor in ipairs(vendors) do
        for _, item in ipairs(vendor.items) do
            totalSources = totalSources + 1
            if item.isCollected then
                collectedSources = collectedSources + 1
            end
        end
    end

    if style == "villa" then
        for _, vendor in ipairs(vendors) do
            local owned, total = Villa.HomeData:GetVendorProgress(vendor)
            flat[#flat + 1] = {
                isVendor = true,
                vendor = vendor,
                label = vendor.sourceName,
                detail = string.format("%d/%d collected%s%s", owned, total, vendor.cityName and (" • " .. vendor.cityName) or "", (vendor.locationCount and vendor.locationCount > 1) and (" • " .. tostring(vendor.locationCount) .. " locations") or ""),
            }
        end
    else
        flat[#flat + 1] = {
            isHeader = true,
            categoryKey = "vendors",
            label = string.format("Vendors • %d", #vendors),
            isExpanded = ZoneOverlay.expandedCategories.vendors ~= false,
        }
        if ZoneOverlay.expandedCategories.vendors ~= false then
            for _, vendor in ipairs(vendors) do
                local owned, total = Villa.HomeData:GetVendorProgress(vendor)
                local expanded = ZoneOverlay.expandedVendors[vendor.key] ~= false
                flat[#flat + 1] = {
                    isVendor = true,
                    isExpandable = true,
                    isExpanded = expanded,
                    vendor = vendor,
                    label = vendor.sourceName,
                    detail = string.format("%d/%d collected%s%s", owned, total, vendor.cityName and (" • " .. vendor.cityName) or "", (vendor.locationCount and vendor.locationCount > 1) and (" • " .. tostring(vendor.locationCount) .. " locations") or ""),
                }
                if expanded then
                    for _, item in ipairs(vendor.items) do
                        flat[#flat + 1] = {
                            vendor = vendor,
                            entry = item,
                            icon = item.isCollected and 1392952 or 134400,
                            label = (Villa.HomeData and Villa.HomeData.GetDecorDisplayName and Villa.HomeData:GetDecorDisplayName(item)) or item.name,
                            detail = (item.requirementText or vendor.requirementText or vendor.sourceName or "Source") .. (item.isCollected and " • known" or ""),
                        }
                    end
                end
            end
        end
    end

    return flat, #vendors, totalSources, collectedSources
end



local function BuildSimpleVendorFlatData(vendors, style, sourceLabel)
    local flat = {}
    local totalSources = 0
    for _, vendor in ipairs(vendors) do totalSources = totalSources + #(vendor.items or {}) end
    if style == "villa" then
        for _, vendor in ipairs(vendors) do
            flat[#flat + 1] = { isVendor = true, vendor = vendor, label = vendor.name or vendor.sourceName, detail = string.format("%s • %d items", tostring(vendor.zone or vendor.cityName or "Unknown"), #(vendor.items or {})) }
        end
    else
        flat[#flat + 1] = { isHeader = true, categoryKey = "vendors", label = string.format("%s • %d", sourceLabel or "Vendors", #vendors), isExpanded = ZoneOverlay.expandedCategories.vendors ~= false }
        if ZoneOverlay.expandedCategories.vendors ~= false then
            for _, vendor in ipairs(vendors) do
                local vkey = tostring(vendor.vendorKey or table.concat({ tostring(vendor.name or vendor.sourceName or "Unknown"), tostring(vendor.mapID or 0), tostring(vendor.x or 0), tostring(vendor.y or 0) }, "|"))
                local expanded = ZoneOverlay.expandedVendors[vkey] ~= false
                flat[#flat + 1] = { isVendor = true, isExpandable = true, isExpanded = expanded, vendor = vendor, label = vendor.name or vendor.sourceName, detail = string.format("%s • %d items", tostring(vendor.zone or vendor.cityName or "Unknown"), #(vendor.items or {})) }
                if expanded then
                    for _, item in ipairs(vendor.items or {}) do
                        flat[#flat + 1] = { vendor = vendor, entry = item, icon = item.isCollected and 1392952 or 134400, label = (Villa.HomeData and Villa.HomeData.GetDecorDisplayName and Villa.HomeData:GetDecorDisplayName(item)) or item.name or (item.decorID and ("Decor #" .. tostring(item.decorID))) or "Decor", detail = item.requirementText or sourceLabel or vendor.name or "Source" }
                    end
                end
            end
        end
    end
    return flat, #vendors, totalSources, 0
end

local function BuildProviderOverlayFlatData(providerTag, mapID, style, sourceLabel)
    local vendors = (Villa.NormalizedData and Villa.NormalizedData.GetVendorsByProvider and Villa.NormalizedData:GetVendorsByProvider(providerTag, mapID, true)) or {}
    return BuildSimpleVendorFlatData(vendors, style, sourceLabel or providerTag)
end

local function BuildBetterHomesOverlayFlatData(mapID, style)
    return BuildProviderOverlayFlatData("betterhomes", mapID, style, "BetterHomes")
end

local OverlayEngineVilla = {}
function OverlayEngineVilla:BuildData(mapID)
    return BuildOverlayFlatData(mapID, "villa")
end

local OverlayEngineCodex = {}
function OverlayEngineCodex:BuildData(mapID)
    return BuildOverlayFlatData(mapID, "codex")
end

local OverlayEngineHybrid = {}
function OverlayEngineHybrid:BuildData(mapID)
    return BuildOverlayFlatData(mapID, "hybrid")
end

Villa:RegisterEngine("zoneOverlay", "villa", OverlayEngineVilla)
Villa:RegisterEngine("zoneOverlay", "codex", OverlayEngineCodex)
Villa:RegisterEngine("zoneOverlay", "hybrid", OverlayEngineHybrid)

local OverlayEngineBetterHomes = {}
function OverlayEngineBetterHomes:BuildData(mapID)
    return BuildBetterHomesOverlayFlatData(mapID, "codex")
end
local OverlayEngineHIT = {}
function OverlayEngineHIT:BuildData(mapID)
    return BuildProviderOverlayFlatData("hit", mapID, "codex", "HousingItemTracker")
end

local OverlayEngineDecorVendor = {}
function OverlayEngineDecorVendor:BuildData(mapID)
    return BuildProviderOverlayFlatData("decorvendor", mapID, "codex", "DecorVendor")
end


local OverlayEngineHousingVendor = {}
function OverlayEngineHousingVendor:BuildData(mapID)
    return BuildProviderOverlayFlatData("housingvendor", mapID, "codex", "HousingVendor")
end

local OverlayEngineHDG = setmetatable({}, { __index = OverlayEngineCodex })
Villa:RegisterEngine("zoneOverlay", "betterhomes", OverlayEngineBetterHomes)
Villa:RegisterEngine("zoneOverlay", "hit", OverlayEngineHIT)
Villa:RegisterEngine("zoneOverlay", "decorvendor", OverlayEngineDecorVendor)
Villa:RegisterEngine("zoneOverlay", "hdg", OverlayEngineHDG)
Villa:RegisterEngine("zoneOverlay", "housingvendor", OverlayEngineHousingVendor)

function ZoneOverlay:GetEngine()
    return Villa:GetEngine("zoneOverlay") or OverlayEngineCodex
end

function ZoneOverlay:EnsureFrame()
    if self.frame and self.frame:GetParent() == GetContainer() then
        return self.frame
    end
    if not WorldMapFrame then
        return nil
    end

    local parent = GetContainer()
    if not parent then
        return nil
    end

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(false)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.03, 0.04, 0.08, Villa.settings.zoneOverlayAlpha or 0.9)
    frame:SetBackdropBorderColor(0.36, 0.31, 0.62, 0.85)

    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            Villa:OpenSettings()
            return
        end
        Villa.settings.zoneOverlayMinimized = not Villa.settings.zoneOverlayMinimized
        self:Refresh()
    end)
    frame.TitleBar = titleBar

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("Villa Zone Sources")
    frame.Title = title

    local mode = titleBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mode:SetPoint("RIGHT", -10, 0)
    frame.ModeLabel = mode

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", -24, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    frame.Scroll = scroll
    frame.Content = content
    self.frame = frame
    return frame
end

function ZoneOverlay:ReleaseRows()
    for _, row in ipairs(self.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(self.rows)
end

function ZoneOverlay:UpdatePosition(mapID)
    local frame = self.frame
    if not frame then
        return
    end
    frame:ClearAllPoints()
    local parent = GetContainer()
    local pos = Villa.settings.zoneOverlayPosition
    if pos == "bottomRight" then
        frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -35, 5)
    else
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 7, GetMapGroupYOffset(mapID))
    end
end

function ZoneOverlay:Refresh()
    local frame = self:EnsureFrame()
    if not frame then
        return
    end

    local show = Villa.settings.showZoneOverlay and WorldMapFrame and WorldMapFrame:IsShown()
    frame:SetShown(show)
    if not show then
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    local zoneInfo = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    self:UpdatePosition(mapID)
    frame:SetBackdropColor(0.03, 0.04, 0.08, Villa.settings.zoneOverlayAlpha or 0.9)
    frame.ModeLabel:SetText((Villa:GetActiveMode("zoneOverlay") or "none") .. (Villa.settings.zoneOverlayMinimized and " • minimized" or ""))

    local flatData, vendorCount, totalSources, collectedSources = self:GetEngine():BuildData(mapID)
    local missingSources = math.max(0, (totalSources or 0) - (collectedSources or 0))
    local title = string.format("%s • %d sources • %d missing", ((zoneInfo and zoneInfo.name) or "Unknown Zone"), totalSources or vendorCount or 0, missingSources)
    frame.Title:SetText(title)

    if Villa.settings.zoneOverlayMinimized then
        frame:SetSize(250, 24)
        frame.Scroll:Hide()
        return
    end

    frame.Scroll:Show()
    self:ReleaseRows()

    local y = 0
    local width = 252
    for _, entry in ipairs(flatData) do
        if entry.isHeader then
            local row = CreateFrame("Button", nil, frame.Content, "BackdropTemplate")
            row:SetSize(width, 22)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
            row:SetBackdropColor(0.12, 0.12, 0.18, 0.95)
            row:SetBackdropBorderColor(0.35, 0.35, 0.45, 0.8)
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 8, 0)
            text:SetText((entry.isExpanded and "▼ " or "▶ ") .. entry.label)
            row:SetScript("OnClick", function()
                self.expandedCategories[entry.categoryKey] = not entry.isExpanded
                self:Refresh()
            end)
            self.rows[#self.rows + 1] = row
            y = y + 24
        else
            local row = CreateFrame("Button", nil, frame.Content, "BackdropTemplate")
            row:SetSize(width, entry.isVendor and 34 or 36)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
            row:SetBackdropColor(0.05, 0.07, 0.15, 0.92)
            row:SetBackdropBorderColor(0.20, 0.22, 0.32, 0.85)

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("TOPLEFT", 8, -6)
            text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetText((entry.isExpandable and ((entry.isExpanded and "▼ " or "▶ ") .. entry.label) or entry.label))

            local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            sub:SetPoint("BOTTOMLEFT", 8, 6)
            sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            sub:SetJustifyH("LEFT")
            sub:SetText(entry.detail or "")

            row:SetScript("OnClick", function(_, button)
                if entry.isExpandable and entry.vendor then
                    ZoneOverlay.expandedVendors[entry.vendor.key] = not entry.isExpanded
                    self:Refresh()
                    return
                end
                local target = entry.entry or entry.vendor
                if target then
                    Villa:SetWaypoint(target.mapID, target.x, target.y, target.vendorName or target.sourceName or target.name)
                end
            end)
            row:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" then
                    Villa:OpenPanel("vendors")
                end
            end)
            self.rows[#self.rows + 1] = row
            y = y + 40
        end
    end

    frame.Content:SetSize(width, math.max(1, y))
    frame:SetSize(300, math.min(y + 40, 440))
end

function ZoneOverlay:OnEnable()
    local frame = CreateFrame("Frame")
    self.eventFrame = frame
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:SetScript("OnEvent", function()
        self:Refresh()
    end)
    C_Timer.After(1.5, function()
        if WorldMapFrame then
            WorldMapFrame:HookScript("OnShow", function()
                self:Refresh()
            end)
            if WorldMapFrame.SetMapID then
                hooksecurefunc(WorldMapFrame, "SetMapID", function()
                    self:Refresh()
                end)
            end
        end
    end)
end
