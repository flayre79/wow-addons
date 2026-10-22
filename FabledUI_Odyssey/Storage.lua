local addonName, ns = ...
local O = ns.Odyssey

local DEFAULTS = {
    dbVersion = 3,
    nextIDs = {
        waypoint = 1,
        tour = 1,
        gap = 1,
    },
    settings = {
        providerMode = "auto",
        autoTrackOnAdd = false,
        showDistance = true,
        showETA = true,
        showHUD = true,
        lockHUD = false,
        autoAdvanceTours = false,
        autoAuditOnLogin = false,
        debug = false,
        frameScale = 1,
        routeOptimizationMode = "manual",
        suppressDuplicates = true,
        duplicateTolerance = 0.001,
        autoCaptureUserWaypoint = true,
        autoImportSuperTrackedQuest = true,
        autoTrackImportedQuest = true,
        captureQuestOnAccept = false,
        showWorldMapButton = true,
        mapClickCaptureEnabled = true,
        mapClickCaptureModifier = "ALT",
        arrivalDistanceYards = 25,
        -- Arrival handling for a plain tracked waypoint (no tour involved).
        -- Without these, reaching a waypoint did nothing at all: the arrow sat
        -- at "0 yd" forever because only tour auto-advance ever reacted to
        -- distance, and that needs an active tour.
        announceArrival = true,
        untrackOnArrival = true,
        showSourceLabels = true,
        showMapPins = true,
        pulsePlayerOnMap = true,
    },
    waypoints = {},
    tours = {},
    activeTourID = nil,
    activeTourIndex = 1,
    trackedWaypointID = nil,
    audit = {
        lastRun = 0,
        lastSummary = "Never run",
        lastReport = {},
        decisions = {},
    },
    gaps = {},
    integrationLog = {},
    ui = {
        mainWindow = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 900,
            height = 620,
            scale = 1,
            alpha = 1,
            displayState = "hidden",
        },
        hud = {
            point = "BOTTOM",
            relativePoint = "BOTTOM",
            x = 0,
            y = 220,
            width = 156,
            height = 132,
            scale = 1,
            alpha = 1,
        },
    },
    migration = {
        importedLegacyOdyssey = false,
    },
}

local function DeepMergeMissing(destination, source)
    if type(destination) ~= "table" or type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            DeepMergeMissing(destination[key], value)
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

local function CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local destination = {}
    for key, value in pairs(source) do
        destination[key] = CopyTable(value)
    end
    return destination
end

local function LooksLikeLegacyOdyssey(candidate)
    if type(candidate) ~= "table" or candidate.dbVersion ~= nil then
        return false
    end

    if candidate.activeTour ~= nil or candidate.index ~= nil then
        return true
    end

    if type(candidate.tours) == "table" then
        for key, value in pairs(candidate.tours) do
            if type(key) == "string" or (type(value) == "table" and value.id == nil and value.waypointIDs == nil) then
                return true
            end
        end
    end

    return false
end

local function ImportLegacyOdyssey(db, legacy)
    if db.migration.importedLegacyOdyssey then
        return
    end

    if type(legacy) ~= "table" then
        db.migration.importedLegacyOdyssey = true
        return
    end

    -- The legacy schema keyed tours by name, and DeepMergeMissing leaves those
    -- string keys in place (it only fills gaps, and `tours` is already a
    -- table). Migrated tours are appended as an array, so the name-keyed
    -- originals would otherwise sit in the saved variable forever -- invisible
    -- to every ipairs in the addon, but a full duplicate copy of the data.
    if type(db.tours) == "table" then
        for key in pairs(db.tours) do
            if type(key) ~= "number" then
                db.tours[key] = nil
            end
        end
    end

    local legacyTours = legacy.tours
    if type(legacyTours) == "table" then
        for tourName, points in pairs(legacyTours) do
            if type(points) == "table" then
                local tourID = db.nextIDs.tour
                db.nextIDs.tour = tourID + 1
                local tour = {
                    id = tourID,
                    name = O:Trim((tourName ~= nil and tourName ~= "") and tourName or ("Tour " .. tourID)),
                    waypointIDs = {},
                    createdAt = time(),
                    updatedAt = time(),
                }

                for _, point in ipairs(points) do
                    local waypointID = db.nextIDs.waypoint
                    db.nextIDs.waypoint = waypointID + 1
                    db.waypoints[#db.waypoints + 1] = {
                        id = waypointID,
                        title = O:Trim((point.title ~= nil and point.title ~= "") and point.title or (tour.name .. " Point " .. (#tour.waypointIDs + 1))),
                        mapID = tonumber(point.mapID) or 0,
                        x = O:Clamp01(point.x),
                        y = O:Clamp01(point.y),
                        source = "LegacyOdyssey",
                        createdAt = tonumber(point.createdAt) or time(),
                        tags = { "tour" },
                    }
                    table.insert(tour.waypointIDs, waypointID)
                end

                db.tours[#db.tours + 1] = tour
            end
        end
    end

    if type(legacy.gaps) == "table" and #legacy.gaps > 0 then
        db.gaps = CopyTable(legacy.gaps)
        local maxGapID = 0
        for _, gap in ipairs(db.gaps) do
            maxGapID = math.max(maxGapID, tonumber(gap.id) or 0)
        end
        db.nextIDs.gap = math.max(db.nextIDs.gap, maxGapID + 1)
    end

    if type(legacy.audit) == "table" then
        db.audit = CopyTable(legacy.audit)
    end

    if type(legacy.settings) == "table" then
        if legacy.settings.debug ~= nil then
            db.settings.debug = legacy.settings.debug and true or false
        end
        if legacy.settings.autoAudit ~= nil then
            db.settings.autoAuditOnLogin = legacy.settings.autoAudit and true or false
        end
    end

    local activeTourName = O:Trim(legacy.activeTour)
    if activeTourName ~= "" then
        for _, tour in ipairs(db.tours) do
            if tour.name == activeTourName then
                db.activeTourID = tour.id
                break
            end
        end
    end
    db.activeTourIndex = math.max(1, tonumber(legacy.index) or 1)

    db.migration.importedLegacyOdyssey = true
end

function O:ResolveStorage()
    -- Snapshot only the genuinely old, name-keyed schema. In local-storage
    -- mode `_G.FabledUI_OdysseyDB` becomes `self.db`; reading it as both source
    -- and destination made the old importer append to the table it was
    -- iterating and could duplicate/corrupt tours.
    local legacySnapshot = LooksLikeLegacyOdyssey(_G.FabledUI_OdysseyDB)
        and CopyTable(_G.FabledUI_OdysseyDB) or nil

    if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
        DataVault:EnsureNamespace(self.DB_NAMESPACE)
        self.db = DataVault:Get("account", self.DB_NAMESPACE, nil, {})
        self._storageBackend = "DataVault"
    else
        _G.FabledUI_OdysseyDB = _G.FabledUI_OdysseyDB or {}
        self.db = _G.FabledUI_OdysseyDB
        self._storageBackend = "Local"
    end

    DeepMergeMissing(self.db, DEFAULTS)
    ImportLegacyOdyssey(self.db, legacySnapshot)
    DeepMergeMissing(self.db, DEFAULTS)

    if type(self.db.waypoints) ~= "table" then
        self.db.waypoints = {}
    end
    if type(self.db.tours) ~= "table" then
        self.db.tours = {}
    end
    if type(self.db.gaps) ~= "table" then
        self.db.gaps = {}
    end
    if type(self.db.integrationLog) ~= "table" then
        self.db.integrationLog = {}
    end
    if type(self.db.ui) ~= "table" then
        self.db.ui = CopyTable(DEFAULTS.ui)
    end

    self.db.dbVersion = DEFAULTS.dbVersion
end
