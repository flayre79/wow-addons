-- FabledUI_Villa_Decor -- uncollected decor that still pays House XP.
--
-- The first time you collect a decor item the house gains XP. Blizzard's catalog
-- already knows which items still owe you that: every entry reports the exact
-- amount (firstAcquisitionBonus), its quality, and sourceText saying who sells
-- it and for how much. So this addon asks the game rather than trusting the
-- imported donor datasets, which are months stale on prices. It reads every
-- catalog entry and keeps the ones whose bonus is above zero; the searcher's
-- own "first acquisition bonus only" filter is deliberately not used (see Scan).
--
-- The only thing the game does not give is coordinates. Those come from the
-- DataVault_Villa shards when they are installed, joined on the vendor's NAME
-- (sourceText carries no npcID). Without the shards the list still works; it
-- just cannot drop a waypoint.
--
-- Searcher usage follows FabledUI_Villa/Villa_CatalogScan.lua, which follows
-- AllTheThings: results arrive asynchronously in a callback, the searcher may be
-- userdata, and GetCatalogEntryDebugInfoForID is never touched (force-taints).
-- Scans run when the window opens, on its Refresh button, and after a new item
-- is collected while it is open. No timers.

local addonName = ...

local Decor = {}
_G.FabledUI_VillaDecor = Decor

Decor.VERSION = "0.2.1"
Decor.ADDON_NAME = addonName or "FabledUI_Villa_Decor"

local Source = _G.FabledUI_VillaDecorSource
local PREFIX = "|cffffb81c[Villa Decor]|r "
local RESCAN_DEBOUNCE = 1.0
local SCAN_TIMEOUT = 10
local UNKNOWN_QTY = 4294967295
local CATALOG_SHARD = "FabledUI_DataVault_Villa_Catalog"

local issecretvalue = _G.issecretvalue or function() return false end

function Decor.Print(...)
    print(PREFIX, ...)
end

local function safeNumber(value)
    if value == nil or issecretvalue(value) then return nil end
    value = tonumber(value)
    if not value or value < 0 or value >= UNKNOWN_QTY then return nil end
    return value
end

local function safeString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

-- -----------------------------------------------------------------------------
-- API seam (tests replace these; the simulator shadows its own globals)
-- -----------------------------------------------------------------------------

Decor.Api = {
    CreateSearcher = function()
        if not (C_HousingCatalog and C_HousingCatalog.CreateCatalogSearcher) then return nil end
        local ok, searcher = pcall(C_HousingCatalog.CreateCatalogSearcher)
        if ok then return searcher end
        return nil
    end,

    EntryInfo = function(entry)
        if not (C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfo) then return nil end
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfo, entry)
        if ok and type(info) == "table" then return info end
        return nil
    end,

    DecorEntryType = function()
        local enum = rawget(_G, "Enum")
        return enum and enum.HousingCatalogEntryType and enum.HousingCatalogEntryType.Decor or nil
    end,

    Providers = function()
        return rawget(_G, "FabledUI_DataVault_VillaProviders")
    end,

    -- The big vendor shard is LoadOnDemand (several MB of Lua). It is pulled in
    -- the first time the window is opened, never at login: it carries the quest
    -- and achievement ids Prereqs.lua checks, and the rest of the coordinates.
    LoadCatalogShard = function()
        if not (C_AddOns and C_AddOns.LoadAddOn) then return false end
        local ok, loaded = pcall(C_AddOns.LoadAddOn, CATALOG_SHARD)
        return ok and loaded and true or false
    end,

    PlayerFaction = function()
        if type(UnitFactionGroup) ~= "function" then return nil end
        local ok, faction = pcall(UnitFactionGroup, "player")
        if ok then return safeString(faction) end
        return nil
    end,

    -- x/y are 0-100 percentages, the unit every Villa housing dataset uses.
    SetWaypoint = function(mapID, x, y, label)
        local odyssey = rawget(_G, "FabledUI_Odyssey")
        if type(odyssey) == "table" and type(odyssey.SetWaypoint) == "function" then
            local ok, id = pcall(odyssey.SetWaypoint, odyssey, x, y, mapID, { title = label or "", autoTrack = true })
            if ok and id ~= nil then return true end
        end
        local mapPoint = rawget(_G, "UiMapPoint")
        if C_Map and C_Map.SetUserWaypoint and type(mapPoint) == "table" and mapPoint.CreateFromCoordinates then
            local ok, point = pcall(mapPoint.CreateFromCoordinates, mapID, x / 100, y / 100)
            if ok and point and pcall(C_Map.SetUserWaypoint, point) then
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                    pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
                end
                return true
            end
        end
        local tomtom = rawget(_G, "TomTom")
        if type(tomtom) == "table" and type(tomtom.AddWaypoint) == "function" then
            local ok = pcall(tomtom.AddWaypoint, tomtom, mapID, x / 100, y / 100, { title = label or "" })
            return ok and true or false
        end
        return false
    end,
}

-- -----------------------------------------------------------------------------
-- State and settings
-- -----------------------------------------------------------------------------

Decor.rows = {}
Decor.meta = { scanned = false, scanning = false, total = 0, shop = 0, totalXP = 0 }
Decor._callbacks = {}
Decor.watching = false

function Decor:DB()
    local db = rawget(_G, "FabledUI_VillaDecorDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_VillaDecorDB = db
    end
    return db
end

function Decor:Settings()
    local s = self:DB()
    if s.vendorOnly == nil then s.vendorOnly = true end
    if s.goldOnly == nil then s.goldOnly = false end
    -- On by default: the list is for "what can I buy right now".
    if s.hideBlocked == nil then s.hideBlocked = true end
    if s.hideUncertain == nil then s.hideUncertain = false end
    s.hideGated = nil -- 0.1.x; it only ever saw the gates the game's text admits to
    if type(s.sortKey) ~= "string" then s.sortKey = "cost" end
    if s.sortDesc == nil then s.sortDesc = false end
    return s
end

function Decor:RegisterCallback(owner, fn)
    if owner == nil or type(fn) ~= "function" then return end
    self._callbacks[owner] = fn
end

-- A failure is isolated but never silent. A bare pcall here once hid whatever
-- went wrong while painting the results, and the window sat on "Asking the
-- housing catalog..." forever with nothing in the error catcher (2026-09-21).
function Decor._Report(err)
    Decor.meta.lastError = tostring(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- Called through the table so a test can watch it without tripping the harness.
local function report(err)
    Decor._Report(err)
end

function Decor:Fire()
    for _, fn in pairs(self._callbacks) do
        local ok, err = pcall(fn, self)
        if not ok then report(err) end
    end
end

-- -----------------------------------------------------------------------------
-- Rows
-- -----------------------------------------------------------------------------

-- nil when the entry is not something that still pays XP.
--
-- firstAcquisitionBonus > 0 is the whole test: it is the game saying XP is still
-- owed. Owned counts are deliberately not consulted -- an item sitting
-- unredeemed in your collection can still owe its bonus, and that is the
-- cheapest XP there is.
function Decor:BuildRow(info, decorType)
    if type(info) ~= "table" then return nil end

    local entryID = type(info.entryID) == "table" and info.entryID or nil
    local entryType = (entryID and entryID.entryType) or info.entryType
    if decorType ~= nil and entryType ~= nil and entryType ~= decorType then return nil end

    local decorID = safeNumber(entryID and entryID.recordID) or safeNumber(info.recordID)
    local xp = safeNumber(info.firstAcquisitionBonus) or 0
    -- Checked here as well as in the searcher filter, so an older client
    -- without SetFirstAcquisitionBonusOnly still produces the right list.
    if not decorID or xp <= 0 then return nil end

    local parsed = Source.Parse(safeString(info.sourceText))
    local prereqs = Decor.Prereqs
    local playerFaction = self.Api.PlayerFaction()
    -- The cheapest vendor you can actually use: a Horde-only vendor is not the
    -- best one for an Alliance character however little it charges.
    local vendor = prereqs and prereqs:BestVendor(parsed, playerFaction) or Source.BestVendor(parsed)

    local kind
    if vendor then
        kind = "Vendor"
    elseif parsed.others[1] then
        kind = parsed.others[1].kind
    elseif parsed.isShop then
        kind = "Shop"
    else
        kind = "Other"
    end

    local sourceName, zones
    if vendor then
        sourceName, zones = vendor.name, vendor.zones
    elseif parsed.others[1] then
        sourceName, zones = parsed.others[1].name, parsed.others[1].zones
    end

    local itemID = safeNumber(info.itemID)
    local needs = prereqs and prereqs:ForRow(decorID, itemID, parsed, vendor, playerFaction) or {}
    local blocked, uncertain = false, false
    if prereqs then blocked, uncertain = prereqs:Summarise(needs) end

    return {
        decorID    = decorID,
        itemID     = itemID,
        needs      = needs,
        blocked    = blocked,   -- something you have not done / cannot do
        uncertain  = uncertain, -- a gate on file that could not be checked
        faction    = vendor and prereqs and prereqs:VendorFaction(vendor.name) or nil,
        name       = safeString(info.name) or ("Decor " .. decorID),
        xp         = xp,
        quality    = safeNumber(info.quality),
        kind       = kind,
        parsed     = parsed,
        vendor     = vendor,
        sourceName = sourceName or "",
        zone       = zones and table.concat(zones, " / ") or "",
        costText   = vendor and vendor.costText or "",
        costRank   = Source.CostRank(vendor and vendor.cost),
        goldOnly   = vendor and Source.IsGoldOnly(vendor.cost) or false,
    }
end

local SORT_VALUE = {
    name   = function(row) return row.name:lower() end,
    xp     = function(row) return row.xp end,
    source = function(row) return (row.kind .. " " .. row.sourceName):lower() end,
    zone   = function(row) return row.zone:lower() end,
    cost   = function(row) return row.costRank end,
    needs  = function(row) return (row.blocked and 2) or (row.uncertain and 1) or 0 end,
}
Decor.SORT_KEYS = { "name", "xp", "source", "zone", "needs", "cost" }

function Decor:Compare(a, b, key, descending)
    local value = SORT_VALUE[key] or SORT_VALUE.cost
    local av, bv = value(a), value(b)
    if av ~= bv then
        if descending then return av > bv end
        return av < bv
    end
    -- Same price: the one paying more XP first, then a stable order.
    if a.xp ~= b.xp then return a.xp > b.xp end
    if a.name ~= b.name then return a.name < b.name end
    return a.decorID < b.decorID
end

function Decor:GetVisibleRows()
    local s = self:Settings()
    local visible = {}
    for _, row in ipairs(self.rows) do
        local keep = row.kind ~= "Shop"
        if s.vendorOnly and row.kind ~= "Vendor" then keep = false end
        if s.hideBlocked and row.blocked then keep = false end
        if s.hideUncertain and row.uncertain then keep = false end
        if s.goldOnly and not row.goldOnly then keep = false end
        if keep then visible[#visible + 1] = row end
    end
    local key, descending = s.sortKey, s.sortDesc
    table.sort(visible, function(a, b) return Decor:Compare(a, b, key, descending) end)
    return visible
end

function Decor:SetSort(key)
    if not SORT_VALUE[key] then return end
    local s = self:Settings()
    if s.sortKey == key then
        s.sortDesc = not s.sortDesc
    else
        s.sortKey = key
        s.sortDesc = key == "xp"
    end
    self:Fire()
end

-- -----------------------------------------------------------------------------
-- Scanning
-- -----------------------------------------------------------------------------

local function callIfPresent(object, method, ...)
    if object and type(object[method]) == "function" then
        pcall(object[method], object, ...)
        return true
    end
    return false
end

function Decor:OnResults()
    if not self.meta.scanning then return end -- late or spurious callback
    self.meta.scanning = false
    self.meta.timedOut = false

    local searcher = self._searcher
    local entries
    if searcher and type(searcher.GetCatalogSearchResults) == "function" then
        local ok, results = pcall(searcher.GetCatalogSearchResults, searcher)
        if ok and type(results) == "table" then entries = results end
    end

    -- Results are entry VARIANT ids: one decor record can come back several
    -- times (dye variants). One row per record.
    local rows, shop, totalXP, seen = {}, 0, 0, {}
    local blockedCount, uncertainCount = 0, 0
    local decorType = self.Api.DecorEntryType()
    self.meta.entries = entries and #entries or 0
    for _, entry in ipairs(entries or {}) do
        local row = self:BuildRow(self.Api.EntryInfo(entry), decorType)
        if row and not seen[row.decorID] then
            seen[row.decorID] = true
            rows[#rows + 1] = row
            if row.kind == "Shop" then
                shop = shop + 1
            else
                totalXP = totalXP + row.xp
                if row.blocked then blockedCount = blockedCount + 1 end
                if row.uncertain then uncertainCount = uncertainCount + 1 end
            end
        end
    end

    self.rows = rows
    self.meta.scanned = entries ~= nil
    self.meta.total = #rows
    self.meta.shop = shop
    self.meta.totalXP = totalXP
    self.meta.blocked = blockedCount
    self.meta.uncertain = uncertainCount
    self:Fire()
end

function Decor:Scan()
    if self.meta.scanning then return false end

    if not self._searcher then
        -- Accept anything non-nil: the searcher is C-created and may be userdata.
        local searcher = self.Api.CreateSearcher()
        if searcher == nil or type(searcher.RunSearch) ~= "function" then
            self.meta.scanned = false
            self:Fire()
            return false
        end
        self._searcher = searcher
        -- Exactly the three calls AllTheThings and Villa_CatalogScan make, and
        -- nothing else. That sequence is proven on the live client (Villa's
        -- last scan banked 2033 entries). 0.1.0 also set the collected /
        -- uncollected / first-acquisition-bonus / indoors / outdoors filters
        -- here and its callback never arrived. Which setter was at fault was
        -- not isolated; none are needed, because BuildRow tests
        -- firstAcquisitionBonus > 0 on every entry anyway.
        callIfPresent(searcher, "SetAutoUpdateOnParamChanges", false)
        callIfPresent(searcher, "SetResultsUpdatedCallback", function()
            local ok, err = pcall(Decor.OnResults, Decor)
            if not ok then
                Decor.meta.scanning = false
                report(err)
                Decor:Fire()
            end
        end)
    end

    local searcher = self._searcher
    self.meta.scanning = true
    self.meta.timedOut = false
    self.meta.lastError = nil
    self._scanToken = (self._scanToken or 0) + 1
    self:Fire()

    local ok, err = pcall(searcher.RunSearch, searcher)
    if not ok then
        self.meta.scanning = false
        report(err)
        self:Fire()
        return false
    end

    -- One-shot, not a poll: if the callback never lands, say so and unlock
    -- Refresh rather than leaving the window waiting forever.
    if self.meta.scanning and C_Timer and C_Timer.After then
        local token = self._scanToken
        C_Timer.After(SCAN_TIMEOUT, function() Decor:_OnScanTimeout(token) end)
    end
    return true
end

function Decor:_OnScanTimeout(token)
    if token ~= self._scanToken or not self.meta.scanning then return false end
    self.meta.scanning = false
    self.meta.timedOut = true
    self:Fire()
    return true
end

-- What /vdecor status prints: enough to tell "no searcher" from "no callback"
-- from "results but nothing pays XP" without a debugger.
function Decor:PrintStatus()
    local meta, searcher = self.meta, self._searcher
    self.Print(string.format("version %s | searcher: %s | scanning: %s | timed out: %s",
        self.VERSION, searcher and type(searcher) or "none", tostring(meta.scanning), tostring(meta.timedOut)))
    if searcher then
        local parts = {}
        for _, method in ipairs({ "IsSearchInProgress", "GetNumSearchItems", "GetSearchCount" }) do
            if type(searcher[method]) == "function" then
                local ok, value = pcall(searcher[method], searcher)
                parts[#parts + 1] = method .. "=" .. (ok and tostring(value) or "error")
            end
        end
        if type(searcher.GetCatalogSearchResults) == "function" then
            local ok, results = pcall(searcher.GetCatalogSearchResults, searcher)
            parts[#parts + 1] = "results=" .. ((ok and type(results) == "table") and #results or "none")
        end
        self.Print(table.concat(parts, " | "))
    end
    self.Print(string.format("catalog entries read: %s | rows that pay XP: %d (%d shop) | total XP: %d",
        tostring(meta.entries), meta.total, meta.shop, meta.totalXP))
    local prereqs = self.Prereqs
    if prereqs then
        local factions, reps = 0, 0
        for _ in pairs(prereqs._vendorFaction) do factions = factions + 1 end
        for _ in pairs(prereqs._repByItem) do reps = reps + 1 end
        self.Print(string.format("blocked: %s | unverified: %s | vendors with a known side: %d | items with a reputation gate on file: %d | quest/achievement ids loaded: %s",
            tostring(meta.blocked), tostring(meta.uncertain), factions, reps, tostring(prereqs._hitByDecor ~= nil)))
    end
    if meta.lastError then self.Print("last error: " .. meta.lastError) end
end

function Decor:ScanSoon()
    if self._scanPending then return end
    if not (C_Timer and C_Timer.After) then
        self:Scan()
        return
    end
    self._scanPending = true
    C_Timer.After(RESCAN_DEBOUNCE, function()
        Decor._scanPending = false
        if Decor.watching then Decor:Scan() end
    end)
end

function Decor:SetWatching(watching)
    self.watching = watching and true or false
    if self.watching then self:Scan() end
end

-- -----------------------------------------------------------------------------
-- Vendor locations (static data, joined on vendor name)
-- -----------------------------------------------------------------------------

local function addLocation(index, name, mapID, x, y, zone, faction)
    name = safeString(name)
    mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
    if not name or not mapID or not x or not y then return end
    local key = name:lower()
    index[key] = index[key] or {}
    table.insert(index[key], { mapID = mapID, x = x, y = y, zone = safeString(zone), faction = safeString(faction) })
end

function Decor:IndexHomeShard(index, providers)
    local home = type(providers) == "table" and providers["home"] or nil
    if type(home) ~= "table" then return end
    local sources, locations = home.CodexVendorSourceData, home.CodexNPCLocationData
    if type(sources) ~= "table" or type(locations) ~= "table" then return end

    for _, zones in pairs(sources) do
        for zoneName, vendors in pairs(zones) do
            for _, vendor in ipairs(vendors) do
                local loc = locations[vendor.npcId]
                if type(loc) == "table" then
                    -- One location, or an array of them (faction variants).
                    local list = loc.uiMapId and { loc } or loc
                    for _, one in ipairs(list) do
                        addLocation(index, vendor.npcName, one.uiMapId, one.x, one.y, zoneName, one.faction)
                    end
                end
            end
        end
    end
end

function Decor:IndexCatalogShard(index, providers)
    if type(providers) ~= "table" then return end
    local decorVendor = providers["decorvendor"]
    if type(decorVendor) == "table" and type(decorVendor.Vendors) == "table" then
        for _, vendor in ipairs(decorVendor.Vendors) do
            addLocation(index, vendor.name, vendor.mapID, vendor.x, vendor.y, vendor.zone, vendor.requirementLabel)
        end
    end
    local betterHomes = providers["betterhomes"]
    if type(betterHomes) == "table" and type(betterHomes.VendorData) == "table" then
        for _, vendor in ipairs(betterHomes.VendorData) do
            addLocation(index, vendor.name, vendor.mapID, vendor.x, vendor.y, vendor.zone, vendor.faction)
        end
    end
end

local function pickLocation(candidates, zones, playerFaction)
    if type(candidates) ~= "table" then return nil end
    local wanted = {}
    for _, zone in ipairs(zones or {}) do wanted[zone:lower()] = true end

    local best, bestScore
    for _, loc in ipairs(candidates) do
        local score = 0
        if loc.zone and wanted[loc.zone:lower()] then score = score + 2 end
        local faction = loc.faction and loc.faction:lower() or nil
        if faction == "alliance" or faction == "horde" then
            if playerFaction and faction == playerFaction:lower() then
                score = score + 1
            else
                score = score - 4
            end
        end
        if not best or score > bestScore then best, bestScore = loc, score end
    end
    return best
end

-- Returns a location table or nil. Tries the always-loaded shard first, and
-- loads the big one only on a miss.
function Decor:FindVendorLocation(vendor)
    if type(vendor) ~= "table" or not safeString(vendor.name) then return nil end
    local key = vendor.name:lower()
    local faction = self.Api.PlayerFaction()

    if not self._homeIndex then
        self._homeIndex = {}
        self:IndexHomeShard(self._homeIndex, self.Api.Providers())
    end
    local found = pickLocation(self._homeIndex[key], vendor.zones, faction)
    if found then return found end

    if not self._catalogIndex then
        self._catalogIndex = {}
        self.Api.LoadCatalogShard()
        self:IndexCatalogShard(self._catalogIndex, self.Api.Providers())
    end
    return pickLocation(self._catalogIndex[key], vendor.zones, faction)
end

-- Returns true, or false plus a reason the window can show.
function Decor:WaypointTo(row)
    if type(row) ~= "table" or not row.vendor then
        return false, "Not sold by a vendor."
    end
    local loc = self:FindVendorLocation(row.vendor)
    if not loc then
        if type(self.Api.Providers()) ~= "table" then
            return false, "No vendor coordinates: enable FabledUI_DataVault_Villa."
        end
        return false, "No coordinates on file for " .. row.vendor.name .. "."
    end
    local label = row.vendor.name .. " - " .. row.name
    if self.Api.SetWaypoint(loc.mapID, loc.x, loc.y, label) then
        return true
    end
    return false, "Could not set a waypoint."
end

-- -----------------------------------------------------------------------------
-- Events and slash
-- -----------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function()
    if Decor.watching then Decor:ScanSoon() end
end)
pcall(eventFrame.RegisterEvent, eventFrame, "NEW_HOUSING_ITEM_ACQUIRED")
Decor._eventFrame = eventFrame

SLASH_FABLEDUI_VILLADECOR1 = "/villadecor"
SLASH_FABLEDUI_VILLADECOR2 = "/vdecor"
SlashCmdList["FABLEDUI_VILLADECOR"] = function(msg)
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    if cmd == "status" or cmd == "debug" then
        Decor:PrintStatus()
    elseif Decor.Window then
        Decor.Window:Toggle()
    end
end
