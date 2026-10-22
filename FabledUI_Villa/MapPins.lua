local Villa = _G.FabledUI_Villa
local MapPins = {}
Villa.MapPins = MapPins
Villa:RegisterModule("MapPins", MapPins)

-- 12.0.5: data providers MUST be mixed in from MapCanvasDataProviderMixin so the
-- map canvas can call its full method surface (OnMapChanged, OnShow, OnEvent, etc).
-- Using a plain table here causes "attempt to call a nil value" warnings every
-- time the world map opens, zooms, or pans (ALL-001 in UAT).
if not MapPins.provider then
    if MapCanvasDataProviderMixin and CreateFromMixins then
        MapPins.provider = CreateFromMixins(MapCanvasDataProviderMixin)
    else
        MapPins.provider = {}
    end
end

local function BuildVendorKey(vendor)
    return table.concat({
        tostring(vendor.vendorKey or vendor.npcID or 0),
        tostring(vendor.locationKey or 0),
        tostring(vendor.mapID or 0),
        tostring(vendor.x or 0),
        tostring(vendor.y or 0),
        tostring(vendor.name or ""),
    }, "|")
end

local function GetMapParentID(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.parentMapID or nil
end

local function MapContainsVendor(currentMapID, vendorMapID)
    currentMapID = tonumber(currentMapID)
    vendorMapID = tonumber(vendorMapID)
    if not currentMapID or not vendorMapID then
        return false
    end
    if currentMapID == vendorMapID then
        return true
    end
    local seen = {}
    local cursor = vendorMapID
    while cursor and not seen[cursor] do
        seen[cursor] = true
        cursor = GetMapParentID(cursor)
        if cursor == currentMapID then
            return true
        end
    end
    return false
end

local function GetVendorCollectionSummary(vendor)
    if Villa.HomeData and Villa.HomeData.GetVendorProgress then
        return Villa.HomeData:GetVendorProgress(vendor)
    end
    local owned, total = 0, 0
    local missingNames = {}
    for _, item in ipairs(vendor.items or {}) do
        total = total + 1
        local known = Villa.HomeData and Villa.HomeData.IsEntryCollected and Villa.HomeData:IsEntryCollected(item)
        if known then
            owned = owned + 1
        elseif #missingNames < 6 then
            local name = (Villa.HomeData and Villa.HomeData.GetDecorDisplayName and Villa.HomeData:GetDecorDisplayName(item)) or (item.name or "Decor")
            missingNames[#missingNames + 1] = name
        end
    end
    return owned, total, missingNames
end


local function ExpandVendorLocations(vendor)
    local expanded = {}
    local locations = vendor.locations or {}
    if #locations == 0 then
        locations = { { mapID = vendor.mapID, x = vendor.x, y = vendor.y, zone = vendor.zone, cityName = vendor.cityName } }
    end
    for index, location in ipairs(locations) do
        local row = {}
        for k, v in pairs(vendor) do
            row[k] = v
        end
        row.mapID = location.mapID or vendor.mapID
        row.x = location.x or vendor.x
        row.y = location.y or vendor.y
        row.zone = location.zone or vendor.zone
        row.cityName = location.cityName or vendor.cityName
        row.locationIndex = index
        row.locationCount = #locations
        row.locationKey = table.concat({ tostring(row.mapID or 0), tostring(row.x or 0), tostring(row.y or 0), tostring(row.zone or "") }, "|")
        expanded[#expanded + 1] = row
    end
    return expanded
end

local function CollectPins(filterFunc)
    local pins, seen = {}, {}
    if not Villa.HomeData or not Villa.HomeData.GetMergedVendorList then
        return pins
    end
    for _, vendor in ipairs(Villa.HomeData:GetMergedVendorList()) do
        for _, pinVendor in ipairs(ExpandVendorLocations(vendor)) do
            if filterFunc(pinVendor) then
                local key = BuildVendorKey(pinVendor)
                if not seen[key] then
                    seen[key] = true
                    pins[#pins + 1] = pinVendor
                end
            end
        end
    end
    table.sort(pins, function(a, b)
        if (a.zone or "") ~= (b.zone or "") then
            return (a.zone or "") < (b.zone or "")
        end
        return (a.name or "") < (b.name or "")
    end)
    return pins
end

local function CollectProviderPins(providerTag, mapID, includeParentMaps, missingOnly)
    local pins, seen = {}, {}
    local vendors = (Villa.NormalizedData and Villa.NormalizedData.GetVendorsByProvider and Villa.NormalizedData:GetVendorsByProvider(providerTag, mapID, includeParentMaps)) or {}
    for _, vendor in ipairs(vendors) do
        for _, pinVendor in ipairs(ExpandVendorLocations(vendor)) do
            local matched = includeParentMaps and MapContainsVendor(mapID, pinVendor.mapID) or (tonumber(pinVendor.mapID) == tonumber(mapID))
            if matched and missingOnly then
                local owned, total = GetVendorCollectionSummary(pinVendor)
                if total > 0 and owned >= total then
                    matched = false
                end
            end
            if matched then
                local key = BuildVendorKey(pinVendor)
                if not seen[key] then
                    seen[key] = true
                    pins[#pins + 1] = pinVendor
                end
            end
        end
    end
    table.sort(pins, function(a, b)
        if (a.zone or "") ~= (b.zone or "") then
            return (a.zone or "") < (b.zone or "")
        end
        return (a.name or "") < (b.name or "")
    end)
    return pins
end

-- 12.x MapCanvas contract: mix in MapCanvasPinMixin (for SetPosition/OnLoad/
-- SetOwningMap) and expose hover/click as *methods*. Setting OnEnter/OnLeave
-- scripts on the pin directly throws Blizzard_MapCanvas.lua:280 "assertion failed!".
local PinMixin = CreateFromMixins(MapCanvasPinMixin)
function PinMixin:OnLoad()
    self:SetSize(16, 16)
    if not self.Texture then
        self.Texture = self:CreateTexture(nil, "ARTWORK")
        self.Texture:SetAllPoints()
    end
    self.Texture:SetAtlas("auctionhouse-icon-favorite")
end

function PinMixin:OnReleased()
    self.vendor = nil
end

-- 12.x taint guard. Blizzard's AcquirePin calls pin:CheckMouseButtonPassthrough
-- (MapCanvas_DataProviderBase.lua:290), which calls the *protected*
-- Frame:SetPassThroughButtons(). Protected functions are blocked for insecure
-- callers while in combat lockdown, so any refresh that reaches AcquirePin from
-- our own code during combat throws ADDON_ACTION_BLOCKED. Same workaround
-- HandyNotes / Plumber / HereBeDragons use: shadow the method with a no-op so
-- Blizzard's unconditional call is inert, and invoke the real one ourselves
-- exactly once, only when out of combat.
function PinMixin:SetPassThroughButtons() end

function PinMixin:ApplyPassThrough()
    if self._passThroughApplied or InCombatLockdown() then
        return
    end
    local orig = self._origSetPassThroughButtons
    if orig then
        self._passThroughApplied = true
        orig(self, "RightButton")
    end
end

function PinMixin:OnAcquired(vendor)
    self.vendor = vendor
    -- Retry for pins whose first acquire happened during combat lockdown.
    self:ApplyPassThrough()
    -- vendor coords are normalized (0-1) map positions.
    if vendor and vendor.x and vendor.y then
        self:SetPosition(vendor.x, vendor.y)
    end
end

function PinMixin:OnClick(button)
    local vendor = self.vendor
    if not vendor then
        return
    end
    if button == "RightButton" then
        Villa:OpenPanel("vendors")
        return
    end
    Villa:SetWaypoint(vendor.mapID, vendor.x, vendor.y, vendor.name)
end

function PinMixin:OnMouseUp() end
function PinMixin:OnMouseDown() end

function PinMixin:OnMouseEnter()
    local vendor = self.vendor
    if not vendor then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(vendor.name or "Unknown Vendor")
    GameTooltip:AddLine(vendor.zone or "Unknown Zone", 1, 1, 1)
    if vendor.currency and vendor.currency ~= "unknown" then
        GameTooltip:AddLine(vendor.currency, 0.9, 0.82, 0.45)
    end
    if vendor.requirementLabel and vendor.requirementLabel ~= vendor.currency then
        GameTooltip:AddLine(vendor.requirementLabel, 0.82, 0.82, 0.82, true)
    end
    if vendor.locationCount and vendor.locationCount > 1 then
        GameTooltip:AddLine(string.format("%d known vendor locations", vendor.locationCount), 0.7, 0.85, 1)
    end
    if vendor.sourceSummary and vendor.sourceSummary ~= "" then
        GameTooltip:AddLine("Providers: " .. vendor.sourceSummary, 0.75, 0.75, 0.75, true)
    end
    local owned, total, missingNames = GetVendorCollectionSummary(vendor)
    GameTooltip:AddLine(string.format("Collected %d / %d decor", owned, total), 0.65, 0.85, 0.65)
    if #missingNames > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Missing:", 1, 0.82, 0)
        for _, name in ipairs(missingNames) do
            GameTooltip:AddLine(name, 0.9, 0.9, 0.9, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: set waypoint", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function PinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

local EngineVilla = {}
function EngineVilla:GetPinsForMap(mapID)
    return CollectPins(function(vendor)
        return vendor.mapID == mapID
    end)
end

local EngineCodex = {}
function EngineCodex:GetPinsForMap(mapID)
    return CollectPins(function(vendor)
        return MapContainsVendor(mapID, vendor.mapID)
    end)
end

local EngineHybrid = {}
function EngineHybrid:GetPinsForMap(mapID)
    return CollectPins(function(vendor)
        if not MapContainsVendor(mapID, vendor.mapID) then
            return false
        end
        local owned, total = GetVendorCollectionSummary(vendor)
        return total == 0 or owned < total
    end)
end

Villa:RegisterEngine("mapPins", "villa", EngineVilla)
Villa:RegisterEngine("mapPins", "codex", EngineCodex)
Villa:RegisterEngine("mapPins", "hybrid", EngineHybrid)

local EngineBetterHomes = {}
function EngineBetterHomes:GetPinsForMap(mapID)
    return CollectProviderPins("betterhomes", mapID, true, false)
end

local EngineHIT = {}
function EngineHIT:GetPinsForMap(mapID)
    return CollectProviderPins("hit", mapID, true, false)
end


local EngineHousingVendor = {}
function EngineHousingVendor:GetPinsForMap(mapID)
    return CollectProviderPins("housingvendor", mapID, true, false)
end

local EngineDecorVendor = {}
function EngineDecorVendor:GetPinsForMap(mapID)
    return CollectProviderPins("decorvendor", mapID, true, false)
end

Villa:RegisterEngine("mapPins", "betterhomes", EngineBetterHomes)
Villa:RegisterEngine("mapPins", "hit", EngineHIT)
Villa:RegisterEngine("mapPins", "decorvendor", EngineDecorVendor)
Villa:RegisterEngine("mapPins", "housingvendor", EngineHousingVendor)

function MapPins:GetEngine()
    return Villa:GetEngine("mapPins") or EngineCodex
end

function MapPins.provider:GetMap()
    return self.mapCanvas
end

function MapPins.provider:OnAdded(mapCanvas)
    self.mapCanvas = mapCanvas
    MapPins:RefreshAllData()
end

function MapPins.provider:OnRemoved()
    if self.mapCanvas and self.mapCanvas.RemoveAllPinsByTemplate then
        self.mapCanvas:RemoveAllPinsByTemplate("FlayreDevVillaVendorPinTemplate")
    end
    self.mapCanvas = nil
end

function MapPins:RefreshAllData()
    local mapCanvas = self.provider.mapCanvas
    if not mapCanvas then
        return
    end

    mapCanvas:RemoveAllPinsByTemplate("FlayreDevVillaVendorPinTemplate")
    if not Villa.settings.showMapPins then
        return
    end

    local mapID = mapCanvas:GetMapID()
    if not mapID then
        return
    end

    local engine = self:GetEngine()
    local pins = engine and engine.GetPinsForMap and engine:GetPinsForMap(mapID) or {}
    for _, vendor in ipairs(pins) do
        mapCanvas:AcquirePin("FlayreDevVillaVendorPinTemplate", vendor)
    end
end

local function CreateVillaPin()
    local pin = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
    -- Stash the real C method before the mixin shadows it with the no-op.
    pin._origSetPassThroughButtons = pin.SetPassThroughButtons
    Mixin(pin, PinMixin)
    pin:EnableMouse(true)
    -- Pass right-click through to the map so right-click-to-zoom-out still works.
    pin:ApplyPassThrough()
    return pin
end

local function ResetVillaPin(_, pin)
    pin:Hide()
    pin:ClearAllPoints()
    if pin.OnReleased then pin:OnReleased() end
    pin.pinTemplate = nil
    pin.owningMap = nil
end

function MapPins:OnEnable()
    C_Timer.After(1.5, function()
        if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
            return
        end
        -- 12.x: no RegisterPinTemplate. Register a pin pool directly, exposing
        -- hover/click as methods so AcquirePin's assertion (no OnEnter/OnLeave
        -- script) passes. See wow-map-pin notes / Nemesis + Harvest for the pattern.
        if not WorldMapFrame.pinPools["FlayreDevVillaVendorPinTemplate"] then
            local pool
            if CreateUnsecuredRegionPoolInstance then
                pool = CreateUnsecuredRegionPoolInstance("FlayreDevVillaVendorPinTemplate")
            else
                pool = CreateObjectPool(CreateVillaPin, ResetVillaPin)
            end
            pool.parent = WorldMapFrame:GetCanvas()
            pool.createFunc = CreateVillaPin
            pool.resetFunc = ResetVillaPin
            pool.creationFunc = CreateVillaPin
            pool.resetterFunc = ResetVillaPin
            WorldMapFrame.pinPools["FlayreDevVillaVendorPinTemplate"] = pool
        end
        if not self._providerAdded then
            WorldMapFrame:AddDataProvider(self.provider)
            self._providerAdded = true
        end
    end)
end
