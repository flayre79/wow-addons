local addonName, ns = ...

local Villa = _G.FabledUI_Villa or _G.FlayreDev_Villa or {}
_G.FabledUI_Villa = Villa
_G.FlayreDev_Villa = Villa
ns.Villa = Villa

Villa.NAME = addonName
Villa.DISPLAY_NAME = "Villa"
Villa.VERSION = "0.30.01"

-- Keybinding declaration (replaces deprecated Bindings.xml <Binding> element in 12.x)
BINDING_HEADER_FABLEDUI_VILLA = "FabledUI Villa"
BINDING_NAME_FABLEDUI_VILLA_TOGGLE = "Toggle FabledUI Villa"
function FABLEDUI_VILLA_TOGGLE()
    if FabledUI_Villa and FabledUI_Villa.ToggleUI then
        FabledUI_Villa:ToggleUI()
    end
end
Villa.modules = Villa.modules or {}
Villa.engineRegistry = Villa.engineRegistry or {}
Villa.events = Villa.events or CreateFrame("Frame")
Villa.state = Villa.state or {
    dashboardHooked = false,
    villaMode = false,
}

local function safestr(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

function Villa:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = safestr(select(i, ...))
    end
    DEFAULT_CHAT_FRAME:AddMessage(("|cffc77dff[%s]|r %s"):format(self.DISPLAY_NAME, table.concat(parts, " ")))
end

function Villa:RegisterModule(name, module)
    self.modules[name] = module
end

function Villa:IterModules()
    return pairs(self.modules)
end

function Villa:SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local packed = { ... }
    local ok, a, b, c, d = xpcall(function()
        return fn(unpack(packed))
    end, CallErrorHandler)
    if not ok then
        return false
    end
    return true, a, b, c, d
end

function Villa:RegisterEngine(domain, key, engine)
    if not domain or not key or type(engine) ~= "table" then
        return
    end
    self.engineRegistry[domain] = self.engineRegistry[domain] or {}
    self.engineRegistry[domain][key] = engine
    engine.key = key
    engine.domain = domain
end


function Villa:RegisterModeStub(domain, key)
    if not domain or not key then
        return
    end
    self.engineRegistry[domain] = self.engineRegistry[domain] or {}
    if not self.engineRegistry[domain][key] then
        self.engineRegistry[domain][key] = { key = key, domain = domain, isStub = true }
    end
end

function Villa:GetRegisteredEngines(domain)

    return self.engineRegistry[domain] or {}
end

function Villa:GetActiveMode(domain)
    local modes = self.settings and self.settings.domainModes or nil
    local selected = modes and modes[domain] or nil
    local engines = self.engineRegistry[domain] or {}
    if selected and engines[selected] then
        return selected
    end
    if engines.codex then
        return "codex"
    end
    if engines.villa then
        return "villa"
    end
    for key in pairs(engines) do
        return key
    end
    return nil
end

function Villa:GetEngine(domain)
    local key = self:GetActiveMode(domain)
    local engines = self.engineRegistry[domain] or {}
    return key and engines[key] or nil
end

function Villa:SetMode(domain, key)
    if not domain or not key then
        return false
    end
    local engines = self.engineRegistry[domain] or {}
    if not engines[key] then
        return false
    end
    self.settings.domainModes = self.settings.domainModes or {}
    self.settings.domainModes[domain] = key

    if domain == "vendors" and self.Vendors and self.Vendors.Refresh then
        self.Vendors:Refresh()
    elseif domain == "mapPins" and self.MapPins and self.MapPins.RefreshAllData then
        self.MapPins:RefreshAllData()
    elseif domain == "zoneOverlay" and self.ZoneOverlay and self.ZoneOverlay.Refresh then
        self.ZoneOverlay:Refresh()
    end

    -- Keep the control window's mode rows in step whichever way the mode was
    -- changed -- its own buttons, /villa, or CycleMode.
    if self.Control and type(self.Control.Refresh) == "function" then
        self.Control:Refresh()
    end
    return true
end

function Villa:CycleMode(domain)
    local engines = self.engineRegistry[domain] or {}
    local ordered = {}
    for key in pairs(engines) do
        ordered[#ordered + 1] = key
    end
    table.sort(ordered)
    if #ordered == 0 then
        return nil
    end
    local current = self:GetActiveMode(domain)
    local index = 1
    for i, key in ipairs(ordered) do
        if key == current then
            index = i + 1
            break
        end
    end
    if index > #ordered then
        index = 1
    end
    self:SetMode(domain, ordered[index])
    return ordered[index]
end

function Villa:GetPlayerMapPosition()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        return mapID, nil, nil
    end

    local x, y = pos:GetXY()
    return mapID, x * 100, y * 100
end

local function CallSuiteWaypointAddon(addonTable, x, y, mapID, label)
    if type(addonTable) ~= "table" then
        return false
    end

    if type(addonTable.SetWaypoint) == "function" then
        -- autoTrack so the vendor waypoint is immediately navigated to
        -- (arrow/supertrack). Odyssey returns the new waypoint id, or nil if it
        -- rejected the point (invalid mapID/coords) — only report success when it
        -- actually accepted, so we can fall through to the Blizzard/TomTom paths.
        local id = addonTable:SetWaypoint(x, y, mapID, { title = label or "", autoTrack = true })
        return id ~= nil
    end

    if type(addonTable.NavigateToWaypoint) == "function" then
        local id = addonTable:NavigateToWaypoint(mapID, x, y, { title = label or "", autoTrack = true })
        return id ~= nil
    end

    if type(addonTable.StartNavigation) == "function" then
        addonTable:StartNavigation(mapID, x, y, label or "")
        return true
    end

    return false
end

function Villa:SetWaypoint(mapID, x, y, label)
    if not mapID or not x or not y then
        return false
    end

    -- Check each candidate directly. A table literal with a nil first entry
    -- (_G.FlayreDev_Odyssey is unset on current installs) leaves a hole, and
    -- ipairs stops at the first nil — which previously skipped Odyssey entirely
    -- and silently fell through to the Blizzard waypoint (so nothing ever landed
    -- in Odyssey's list). Build the list without holes.
    local candidates = {}
    if type(_G.FabledUI_Odyssey) == "table" then candidates[#candidates + 1] = _G.FabledUI_Odyssey end
    if type(_G.FlayreDev_Odyssey) == "table" then candidates[#candidates + 1] = _G.FlayreDev_Odyssey end

    for _, addonTable in ipairs(candidates) do
        if CallSuiteWaypointAddon(addonTable, x, y, mapID, label) then
            return true
        end
    end

    if C_Map and UiMapPoint and C_Map.SetUserWaypoint then
        local point = UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100)
        if point then
            C_Map.SetUserWaypoint(point)
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            return true
        end
    end

    if _G.TomTom and type(_G.TomTom.AddWaypoint) == "function" then
        local uid = _G.TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = label or "" })
        if uid and _G.TomTom.SetCrazyArrow and type(_G.TomTom.SetCrazyArrow) == "function" then
            _G.TomTom:SetCrazyArrow(mapID, x / 100, y / 100, label or "")
        end
        return true
    end

    return false
end

-- ── Housing catalog collection state (Midnight C_HousingCatalog) ─────────────
-- A decor's catalog record is keyed by decorID (== recordID). The itemID is a
-- SEPARATE identifier that must be mapped to a decorID first. Ownership counts
-- live in totalNumPlaced / totalNumStored / remainingRedeemable (the older
-- numPlaced/numStored/quantity names are kept as fallbacks), and the API can
-- return the unsigned sentinel 4294967295 for "unknown" — guard it. There is no
-- isCollected/isOwned boolean on the entry; C_Housing.IsDecorCollected(decorID)
-- is the authoritative getter. Reference: HousingVendor CollectionAPI,
-- HousingCodex Core/Data, ATT Decor, DecorVendor (firstAcquisitionBonus == 0).
local DECOR_ENTRY_TYPE = (Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Decor) or 1

local function OwnedCountFromInfo(info)
    if type(info) ~= "table" then return 0 end
    local placed = tonumber(info.totalNumPlaced) or tonumber(info.numPlaced) or 0
    local stored = tonumber(info.totalNumStored) or tonumber(info.numStored) or tonumber(info.quantity) or 0
    local redeem = tonumber(info.remainingRedeemable) or 0
    local sum = placed + stored + redeem
    if sum >= 1000000 then return 0 end   -- unsigned -1 sentinel guard
    return sum
end

-- Full catalog record for a decorID (== recordID), account-wide. Also carries
-- info.asset (model file id) + info.uiModelSceneID for 3D previews.
function Villa:GetDecorRecordInfo(decorID)
    decorID = tonumber(decorID)
    if not decorID or not C_HousingCatalog then
        return nil
    end
    if type(C_HousingCatalog.GetCatalogEntryInfoByRecordID) == "function" then
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, DECOR_ENTRY_TYPE, decorID, true)
        if ok and type(info) == "table" then
            return info
        end
    end
    return nil
end

-- The static decorID <-> itemID index, from
-- FabledUI_DataVault_Villa/DecorIndex.lua. That shard is always loaded (not the
-- LoadOnDemand catalog), so this costs nothing to reach and needs no
-- EnsureCatalogData. Returns nil when the shard is not installed.
local function DecorIndexProvider()
    local providers = _G.FabledUI_DataVault_VillaProviders
    local codex = providers and providers["codex"]
    if codex and type(codex.GetDecorIDForItem) == "function" then
        return codex
    end
    return nil
end

-- Map a real WoW itemID -> its decorID (catalog recordID).
--
-- The live API is authoritative but not always available: it returns nil for
-- items the client has not cached, and everything downstream of this (collection
-- state, the vendor assistant's collected/missing split, wishlist matching)
-- inherits that nil as a wrong answer rather than an error. The static index
-- backstops it with 2,913 known pairs.
function Villa:ItemIDToDecorID(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    if C_Housing and type(C_Housing.GetDecorItemInfoFromItemID) == "function" then
        local ok, di = pcall(C_Housing.GetDecorItemInfoFromItemID, itemID)
        if ok and type(di) == "table" and di.decorID then
            return di.decorID
        end
    end
    local index = DecorIndexProvider()
    if index then
        return index:GetDecorIDForItem(itemID)
    end
    return nil
end

-- The reverse: decorID -> itemID. There is no live API for this direction at
-- all, so donor data that carries only a decorID previously had no way to reach
-- an item link or a tooltip.
function Villa:DecorIDToItemID(decorID)
    local index = DecorIndexProvider()
    return index and index:GetItemIDForDecor(decorID) or nil
end

-- Housing placement budget cost for a decor. Houses have a finite placement
-- budget, so this is what makes "can I still afford to place this" answerable.
-- Accepts either identifier; returns nil when unknown, so a caller summing a
-- shopping list can distinguish "free" from "no idea".
function Villa:GetDecorBudgetCost(decorOrItemID)
    local index = DecorIndexProvider()
    if not index then return nil end
    local cost = index:GetDecorBudgetCost(decorOrItemID)
    if cost then return cost end
    local decorID = self:ItemIDToDecorID(decorOrItemID)
    return decorID and index:GetDecorBudgetCost(decorID) or nil
end

-- Resolve either identifier to a decorID, so the attribute getters below can
-- take whichever one the caller happens to be holding.
function Villa:ResolveDecorID(decorOrItemID)
    local index = DecorIndexProvider()
    if not index then return nil end
    if index:GetDecorAttributes(decorOrItemID) then
        return tonumber(decorOrItemID)
    end
    return self:ItemIDToDecorID(decorOrItemID)
end

-- Size band: "Tiny" | "Small" | "Medium" | "Large" | "Huge".
function Villa:GetDecorSize(decorOrItemID)
    local index = DecorIndexProvider()
    local decorID = index and self:ResolveDecorID(decorOrItemID)
    return decorID and index:GetDecorSize(decorID) or nil
end

-- Colour tags, e.g. { "Dark Brown", "Olive" }. Always a table, so callers can
-- iterate without guarding -- decorating by palette is most of what a housing
-- addon is for, and this is the axis Villa had nothing of.
function Villa:GetDecorColors(decorOrItemID)
    local index = DecorIndexProvider()
    local decorID = index and self:ResolveDecorID(decorOrItemID)
    return decorID and index:GetDecorColors(decorID) or {}
end

-- Vendor cost as (amount, currencyID) for decor bought with something other
-- than gold. The vendor assistant reports extended-cost slots as UNPRICED
-- because the merchant API gives it no gold value; this is what prices them.
function Villa:GetDecorCurrency(decorOrItemID)
    local index = DecorIndexProvider()
    local decorID = index and self:ResolveDecorID(decorOrItemID)
    if not decorID then return nil end
    return index:GetDecorCurrency(decorID)
end

-- Every colour tag present in the index, sorted -- for building a filter list
-- without hardcoding one that drifts from the data.
function Villa:GetAllDecorColors()
    local index = DecorIndexProvider()
    return index and index:GetAllDecorColors() or {}
end

-- Model and icon file IDs, for previews that would otherwise need a live
-- catalog round-trip. Pairs with UIToolkit's camera presets.
function Villa:GetDecorAssets(decorOrItemID)
    local index = DecorIndexProvider()
    if not index then return nil end
    local attrs = index:GetDecorAttributes(decorOrItemID)
    if not attrs then
        local decorID = self:ItemIDToDecorID(decorOrItemID)
        attrs = decorID and index:GetDecorAttributes(decorID) or nil
    end
    if not attrs then return nil end
    -- 0 is the donor's "none", which is not a usable file id.
    local model = (attrs.model and attrs.model > 0) and attrs.model or nil
    local icon = (attrs.icon and attrs.icon > 0) and attrs.icon or nil
    return model, icon
end

-- Is the decor with this catalog recordID (decorID) collected? Authoritative
-- boolean first, then owned-count / first-acquisition-bonus fallbacks.
function Villa:IsDecorRecordCollected(decorID)
    decorID = tonumber(decorID)
    if not decorID then return false end
    if C_Housing and type(C_Housing.IsDecorCollected) == "function" then
        local ok, res = pcall(C_Housing.IsDecorCollected, decorID)
        if ok and res == true then
            return true
        end
    end
    local info = self:GetDecorRecordInfo(decorID)
    if info then
        if OwnedCountFromInfo(info) > 0 then return true end
        if info.firstAcquisitionBonus == 0 then return true end
    end
    return false
end

-- How many copies of this decor (recordID) the account owns (placed + stored +
-- redeemable), guarded against the unsigned sentinel. 0 if unknown/uncollected.
function Villa:GetDecorOwnedCount(decorID)
    return OwnedCountFromInfo(self:GetDecorRecordInfo(decorID))
end

function Villa:GetCatalogEntryInfoByItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or not C_HousingCatalog then
        return nil
    end
    -- Prefer the record lookup (full info) once we can resolve a decorID.
    local decorID = self:ItemIDToDecorID(itemID)
    if decorID then
        local info = self:GetDecorRecordInfo(decorID)
        if info then return info end
    end
    if type(C_HousingCatalog.GetCatalogEntryInfoByItem) == "function" then
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID, true)
        if ok and type(info) == "table" then
            -- Some builds return a brief entry ({entryID=...}) with no counts;
            -- follow up by recordID for the full record when possible.
            if OwnedCountFromInfo(info) == 0 and info.entryID and info.entryID.recordID then
                local full = self:GetDecorRecordInfo(info.entryID.recordID)
                if full then return full end
            end
            return info
        end
    end
    return nil
end

function Villa:GetCollectionState(itemID)
    local info = self:GetCatalogEntryInfoByItem(itemID)
    local state = {
        known = false,
        itemID = itemID,
        stored = 0,
        placed = 0,
        total = 0,
    }
    if info then
        local rawStored = tonumber(info.totalNumStored) or tonumber(info.numStored) or tonumber(info.quantity) or 0
        local rawPlaced = tonumber(info.totalNumPlaced) or tonumber(info.numPlaced) or 0
        state.stored = (rawStored < 1000000) and rawStored or 0
        state.placed = (rawPlaced < 1000000) and rawPlaced or 0
        state.total = OwnedCountFromInfo(info)
        state.known = state.total > 0 or info.firstAcquisitionBonus == 0 or false
        state.recordID = info.recordID or (info.entryID and info.entryID.recordID)
        state.name = info.name
    end
    return state, info
end

function Villa:IsKnownDecorItem(itemID)
    -- Resolve to a decorID (recordID) and check by record — the reliable path.
    local decorID = self:ItemIDToDecorID(itemID)
    if decorID then
        return self:IsDecorRecordCollected(decorID)
    end
    -- Many donor entries pass a bare decorID here (or an itemID the API can't
    -- map, e.g. donor data that stuffed a decorID into the itemID field). Try
    -- treating the value as a decorID/recordID directly, then fall back.
    if self:IsDecorRecordCollected(itemID) then
        return true
    end
    return self:GetCollectionState(itemID).known
end

-- Hardcoded fallbacks for clients where Enum.ItemClass.Housing /
-- Enum.ItemHousingSubclass.Decor are not yet exposed. Source: TADA
-- T-AuctionDecorAssistant.lua (see .sample-addons/TADA/...:62-80) which
-- ships these as ADA.HOUSING_CLASS_ID / ADA.DECOR_SUBCLASS_ID. Values
-- updated to match Blizzard's published housing item taxonomy
-- (Enum.ItemClass.Housing == 15, Enum.ItemHousingSubclass.Decor == 5).
local HOUSING_CLASS_ID_FALLBACK  = 15
local HOUSING_DECOR_SUBCLASS_ID_FALLBACK = 5

-- Predicate: does Blizzard tag this itemID as a housing decor item?
-- Distinct from IsHousingRelevantItem (catalog membership) and
-- IsKnownDecorItem (player has collected it). Useful for AH/tooltip hooks
-- that need to filter by Blizzard's item taxonomy without consulting the
-- Villa catalog.
function Villa:IsHousingDecorItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local housingClassID  = (Enum and Enum.ItemClass and Enum.ItemClass.Housing) or HOUSING_CLASS_ID_FALLBACK
    local decorSubClassID = (Enum and Enum.ItemHousingSubclass and Enum.ItemHousingSubclass.Decor) or HOUSING_DECOR_SUBCLASS_ID_FALLBACK
    if housingClassID == nil or decorSubClassID == nil then
        return false
    end

    local classID, subClassID
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local _, _, _, _, _, cId, sId = C_Item.GetItemInfoInstant(itemID)
        classID, subClassID = cId, sId
    end
    if (classID == nil or subClassID == nil) and type(GetItemInfoInstant) == "function" then
        local _, _, _, _, _, cId, sId = GetItemInfoInstant(itemID)
        classID, subClassID = classID or cId, subClassID or sId
    end

    if classID == nil or subClassID == nil then
        return false
    end

    return classID == housingClassID and subClassID == decorSubClassID
end

function Villa:IsHousingRelevantItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    if self.HomeData and type(self.HomeData.GetSourceInfo) == "function" and self.HomeData:GetSourceInfo(itemID) then
        return true
    end
    local info = self:GetCatalogEntryInfoByItem(itemID)
    return info ~= nil
end

function Villa:GetDecorSourceInfo(itemID)
    if self.HomeData and type(self.HomeData.GetSourceInfo) == "function" then
        return self.HomeData:GetSourceInfo(itemID)
    end
    return nil
end

function Villa:GetDecorRequirementText(itemID)
    if self.HomeData and type(self.HomeData.GetRequirementText) == "function" then
        return self.HomeData:GetRequirementText(itemID)
    end
    return nil
end

-- Villa's settings are the control window. The Blizzard canvas category is a
-- stub that points back at it and is only opened directly when the toolkit
-- shell is unavailable -- opening it covers the world, map and housing UI,
-- which are the things you need to see while changing these settings.
function Villa:OpenSettings()
    if self.Control and type(self.Control.Open) == "function" and self.Control:Open() then
        return true
    end
    if self.Settings and type(self.Settings.OpenCanvas) == "function" then
        return self.Settings:OpenCanvas()
    end
    return false
end

function Villa:GetDashboardFrame()
    if self.Dashboard and type(self.Dashboard.GetFrame) == "function" then
        return self.Dashboard:GetFrame()
    end
    return _G.HousingDashboardFrame or _G.PlayerHousingFrame or _G.HousingFrame
end

function Villa:ShowDashboard()
    local frame = self:GetDashboardFrame()
    if frame and frame.Show then
        frame:Show()
        return frame
    end
    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        local loaded = false
        if type(C_AddOns.IsAddOnLoaded) == "function" then
            local okLoaded, isLoaded = pcall(C_AddOns.IsAddOnLoaded, "Blizzard_HousingDashboard")
            loaded = okLoaded and isLoaded or false
        end
        if not loaded then
            pcall(C_AddOns.LoadAddOn, "Blizzard_HousingDashboard")
        end
        frame = self:GetDashboardFrame()
        if frame and frame.Show then
            frame:Show()
            return frame
        end
    end
    return frame
end

function Villa:OpenPanel(panelKey)
    -- Villa now opens in its own FableNeon window (Tabs:ShowPanel builds/shows
    -- it lazily). No longer forces Blizzard's housing dashboard open.
    if self.Tabs and type(self.Tabs.ShowPanel) == "function" then
        self.Tabs:ShowPanel(panelKey or "vendors")
    end
end

function Villa:ToggleUI(forceShow, panelKey)
    local shown = self.Tabs and self.Tabs.IsShown and self.Tabs:IsShown()
    -- Explicit hide, or a plain toggle while already open → close.
    if forceShow == false or (shown and forceShow ~= true) then
        if self.Tabs and self.Tabs.HideAllPanels then
            self.Tabs:HideAllPanels()
        end
        return
    end
    self:OpenPanel(panelKey or (self.db and self.db.ui and self.db.ui.tabs and self.db.ui.tabs.lastPanel) or "vendors")
end

Villa.Toggle = Villa.ToggleUI

function Villa:InitializeModules()
    for _, module in self:IterModules() do
        if type(module.OnInitialize) == "function" then
            self:SafeCall(module.OnInitialize, module)
        end
    end
end

function Villa:EnableModules()
    for _, module in self:IterModules() do
        if type(module.OnEnable) == "function" then
            self:SafeCall(module.OnEnable, module)
        end
    end
end

local function HandleSlashCommand(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""

    if msg == "" then
        Villa:ToggleUI()
        return
    end

    if msg == "help" then
        Villa:Print("Commands: /villa, /villa vendors, /villa quests, /villa achievements, /villa drops, /villa pvp, /villa professions, /villa progress, /villa wishlist, /villa treasures, /villa catalog, /villa styles, /villa trainers, /villa tracker, /villa reputation, /villa materials, /villa planning, /villa statistics, /villa preview, /villa trainers+, /villa shoppinglist, /villa checklist, /villa achdecor, /villa control, /villa settings, /villa pins, /villa overlay, /villa mode, /villa notes export|import, /villa capture, /villa catalogscan, /villa coverage, /villa debug")
        return
    end

    -- Notes sub-commands: /villa notes export | /villa notes import
    if msg:find("^notes") then
        local arg = msg:match("^notes%s+(.*)$") or ""
        if Villa.Notes and type(Villa.Notes.HandleSlash) == "function" then
            Villa.Notes:HandleSlash(arg)
        end
        return
    end

    if msg == "settings" then
        Villa:OpenSettings()
        return
    end

    -- The control window is a toggle rather than an open, because the point of
    -- it is to sit next to the world while you flip things.
    if msg == "control" or msg == "controls" then
        if Villa.Control and type(Villa.Control.Toggle) == "function" then
            Villa.Control:Toggle()
        end
        return
    end

    local panelCommands = { vendors = "vendors", show = "vendors", quests = "quests", achievements = "achievements", drops = "drops", pvp = "pvp", professions = "professions", progress = "progress", wishlist = "wishlist", treasures = "treasures", catalog = "catalog", styles = "styles", trainers = "trainers", tracker = "tracker", reputation = "reputation", materials = "materials", mats = "materials", planning = "planning", stats = "statistics", statistics = "statistics", preview = "preview", ["trainers+"] = "trainers_hv", hvtrainers = "trainers_hv", shoppinglist = "shoppinglist", shopping = "shoppinglist", lists = "shoppinglist", checklist = "checklist", achdecor = "achdecor", ["achievement-decor"] = "achdecor" }
    if panelCommands[msg] then
        Villa:OpenPanel(panelCommands[msg])
        return
    end

    if msg == "pins" then
        Villa.settings.showMapPins = not Villa.settings.showMapPins
        if Villa.MapPins and Villa.MapPins.RefreshAllData then
            Villa.MapPins:RefreshAllData()
        end
        Villa:Print("Map pins", Villa.settings.showMapPins and "enabled." or "disabled.")
        return
    end

    if msg == "overlay" then
        Villa.settings.showZoneOverlay = not Villa.settings.showZoneOverlay
        if Villa.ZoneOverlay and Villa.ZoneOverlay.Refresh then
            Villa.ZoneOverlay:Refresh()
        end
        Villa:Print("Zone overlay", Villa.settings.showZoneOverlay and "enabled." or "disabled.")
        return
    end

    if msg:find("^mode") then
        Villa:Print("Modes — Vendors:", Villa:GetActiveMode("vendors") or "none", "Overlay:", Villa:GetActiveMode("zoneOverlay") or "none", "Pins:", Villa:GetActiveMode("mapPins") or "none")
        return
    end

    if msg == "capture" then
        if Villa.VendorCapture and Villa.VendorCapture.PrintStats then
            Villa.VendorCapture:PrintStats()
        end
        return
    end

    -- "catalog" is already a panel command, so the live dump is "catalogscan".
    if msg == "catalogscan" or msg == "scan" then
        if Villa.CatalogScan then
            Villa.CatalogScan:Scan(true)
        end
        return
    end

    if msg == "coverage" then
        if Villa.CatalogScan then
            Villa.CatalogScan:PrintStats()
        end
        return
    end

    if msg == "debug" and Villa.Dashboard then
        Villa.Dashboard:PrintDebug()
        return
    end

    Villa:Print("Unknown command.")
end

function _G.FabledUI_Villa_OnAddonCompartmentClick(button)
    if button == "RightButton" then
        Villa:OpenSettings()
        return
    end
    if type(Villa.ToggleUI) == "function" then
        Villa:ToggleUI()
    end
end

function _G.FabledUI_Villa_OnAddonCompartmentEnter(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Villa")
    GameTooltip:AddLine("Left-click: open Villa", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function _G.FabledUI_Villa_OnAddonCompartmentLeave()
    GameTooltip_Hide()
end

Villa.events:RegisterEvent("PLAYER_LOGIN")
Villa.events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- WoW 12.0.7 housing events. Registered with pcall so a 12.0.x client that
-- hasn't shipped the event names yet (PTR ordering, regional delays) bails
-- gracefully rather than throwing at addon load.
local function safeRegister(eventName)
    pcall(Villa.events.RegisterEvent, Villa.events, eventName)
end
safeRegister("NEIGHBORHOOD_INITIATIVE_UPDATED")
safeRegister("HOUSE_LEVEL_FAVOR_UPDATED")
safeRegister("HOUSE_LEVEL_CHANGED")
safeRegister("PLAYER_HOUSE_LIST_UPDATED")
safeRegister("HOUSING_DECOR_PLACED")
safeRegister("HOUSING_DECOR_REMOVED")

Villa.events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Guard every init step. ResolveStorage was unguarded, so any error
        -- there aborted the whole PLAYER_LOGIN handler before "Backbone online"
        -- — Villa then silently never came up. SafeCall (xpcall) logs the
        -- failure but lets init continue, and always registers the slash + banner.
        Villa:SafeCall(Villa.ResolveStorage, Villa)
        Villa:SafeCall(Villa.InitializeModules, Villa)
        Villa:SafeCall(Villa.EnableModules, Villa)

        SLASH_FABLEDUI_VILLA1 = "/villa"
        SLASH_FABLEDUI_VILLA2 = "/house"
        SlashCmdList.FABLEDUI_VILLA = HandleSlashCommand

        Villa:Print("Backbone online.")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if Villa.MapPins and type(Villa.MapPins.RefreshAllData) == "function" then
            Villa.MapPins:RefreshAllData()
        end
        if Villa.ZoneOverlay and type(Villa.ZoneOverlay.Refresh) == "function" then
            Villa.ZoneOverlay:Refresh()
        end
    elseif event == "PLAYER_HOUSE_LIST_UPDATED" then
        if Villa.Endeavors and type(Villa.Endeavors.OnHouseListUpdated) == "function" then
            -- SafeCall in addition to the re-entrancy guard inside the handler:
            -- the Housing dashboard event storm must never escape into an error
            -- that abandons the OnEvent frame.
            Villa:SafeCall(Villa.Endeavors.OnHouseListUpdated, Villa.Endeavors)
        end
    elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" or event == "HOUSE_LEVEL_CHANGED" then
        if Villa.Endeavors and type(Villa.Endeavors.OnHouseLevelUpdated) == "function" then
            Villa.Endeavors:OnHouseLevelUpdated()
        end
    elseif event == "NEIGHBORHOOD_INITIATIVE_UPDATED" then
        if Villa.Endeavors and type(Villa.Endeavors.OnInitiativeUpdated) == "function" then
            Villa.Endeavors:OnInitiativeUpdated()
        end
    elseif event == "HOUSING_DECOR_PLACED" or event == "HOUSING_DECOR_REMOVED" then
        if Villa.LiveCounts and type(Villa.LiveCounts.OnDecorChanged) == "function" then
            Villa.LiveCounts:OnDecorChanged(event, ...)
        end
    end
end)
