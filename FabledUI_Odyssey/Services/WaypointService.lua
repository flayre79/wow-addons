local addonName, ns = ...
local O = ns.Odyssey

local Service = {}
O.Services.WaypointService = Service
O.API = Service

local MAX_WAYPOINTS = 2000
local MAX_IMPORT_BYTES = 200000
local MAX_IMPORT_RECORDS = 500

Service.Limits = {
    maxWaypoints = MAX_WAYPOINTS,
    maxImportBytes = MAX_IMPORT_BYTES,
    maxImportRecords = MAX_IMPORT_RECORDS,
}

local function UrlEncode(text)
    return (tostring(text or "")
        :gsub("\n", " ")
        :gsub("([^%w %-_%.~])", function(char)
            return string.format("%%%02X", string.byte(char))
        end))
end

local function UrlDecode(text)
    return (tostring(text or "")
        :gsub("%+", " ")
        :gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16) or 32)
        end))
end

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function FindWaypointIndexByID(waypointID)
    waypointID = tonumber(waypointID)
    if not waypointID then
        return nil
    end

    for index, waypoint in ipairs(O.db.waypoints) do
        if tonumber(waypoint.id) == waypointID then
            return index, waypoint
        end
    end
    return nil
end

local function NormalizeExternalSource(source)
    source = O:Trim(source ~= nil and source or "external")
    if source == "" then
        source = "external"
    end
    source = string.lower(source):gsub("[^%w]+", "-"):gsub("%-+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if source == "" then
        source = "external"
    end
    return source
end

local function NormalizeCoordinates(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not IsFiniteNumber(x) or not IsFiniteNumber(y) then
        return nil, nil, "Waypoint coordinates must be finite numbers."
    end
    if x < 0 or y < 0 or x > 100 or y > 100 then
        return nil, nil, "Waypoint coordinates must be between 0 and 1, or 0 and 100 percent."
    end
    if x > 1 or y > 1 then
        x = x / 100
        y = y / 100
    end
    if x < 0 or y < 0 or x > 1 or y > 1 then
        return nil, nil, "Waypoint coordinates are outside the map."
    end
    return x, y
end

local function CopyArray(source)
    local copy = {}
    if type(source) == "table" then
        for _, value in ipairs(source) do
            copy[#copy + 1] = value
        end
    end
    return copy
end

local function AppendUniqueTags(destination, source)
    if type(destination) ~= "table" or type(source) ~= "table" then
        return
    end

    local seen = {}
    for _, tag in ipairs(destination) do
        seen[tag] = true
    end

    for _, tag in ipairs(source) do
        if type(tag) == "string" and tag ~= "" and not seen[tag] then
            destination[#destination + 1] = tag
            seen[tag] = true
        end
    end
end

local function WaypointHasTag(waypoint, tag)
    if type(waypoint) ~= "table" or type(tag) ~= "string" then
        return false
    end
    for _, waypointTag in ipairs(waypoint.tags or {}) do
        if waypointTag == tag then
            return true
        end
    end
    return false
end

local function ResolveExternalPayload(kind, payload, options)
    if type(payload) ~= "table" then
        return nil, "External waypoint payload is invalid."
    end

    options = type(options) == "table" and options or {}

    local mapID = tonumber(payload.mapID or payload.uiMapID) or 0
    local x, y, coordinateError = NormalizeCoordinates(payload.x or payload.coordX, payload.y or payload.coordY)

    local questID = tonumber(payload.questID)
    if (mapID <= 0 or not x or not y) and questID and C_QuestLog and C_QuestLog.GetNextWaypoint then
        local questMapID, questX, questY = C_QuestLog.GetNextWaypoint(questID)
        mapID = tonumber(questMapID) or mapID
        x, y, coordinateError = NormalizeCoordinates(questX or x, questY or y)
    end

    if mapID <= 0 or not x or not y then
        return nil, coordinateError or "Waypoint payload is missing coordinates."
    end

    local title = O:Trim(payload.title or payload.label or payload.name or "")
    if title == "" then
        if questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = O:Trim(C_QuestLog.GetTitleForQuestID(questID) or "")
        end
        if title == "" then
            title = questID and ("Quest " .. questID) or ((kind and (kind:gsub("^%l", string.upper))) or "Waypoint")
        end
    end

    local source = O:Trim(payload.source or options.source or "External")
    local sourceToken = NormalizeExternalSource(source)
    local tags = {}
    AppendUniqueTags(tags, payload.tags)
    AppendUniqueTags(tags, options.tags)

    return {
        title = title,
        mapID = mapID,
        x = x,
        y = y,
        source = source,
        sourceToken = sourceToken,
        questID = questID,
        objectiveIndex = tonumber(payload.objectiveIndex),
        entryID = payload.entryID,
        tags = tags,
    }
end

local function ValidateWaypointData(data)
    if type(data) ~= "table" then
        return nil, "Waypoint data is invalid."
    end

    -- The explicit `not mapID` is what lets the analyzer narrow `number?` to
    -- `number` before math.floor; IsFiniteNumber is opaque to it.
    local mapID = tonumber(data.mapID)
    if not mapID or not IsFiniteNumber(mapID) or mapID <= 0 then
        return nil, "Map ID is invalid."
    end
    mapID = math.floor(mapID)

    local x, y, err = NormalizeCoordinates(data.x, data.y)
    if not x then
        return nil, err
    end

    return {
        title = data.title,
        mapID = mapID,
        x = x,
        y = y,
        -- Elevation, when the source knew it. Optional: most waypoints come
        -- from a 2D map click and have none.
        z = tonumber(data.z),
        autoTrack = data.autoTrack,
        source = data.source,
        tags = CopyArray(data.tags),
        questID = tonumber(data.questID),
        objectiveIndex = tonumber(data.objectiveIndex),
        entryID = data.entryID,
        sourceToken = data.sourceToken,
        createdAt = tonumber(data.createdAt),
        allowDuplicate = data.allowDuplicate,
        duplicateTolerance = data.duplicateTolerance,
    }
end

local function CreateWaypointRecord(data, waypointID)
    return {
        id = waypointID,
        title = O:Trim((data.title ~= nil and data.title ~= "") and data.title or ("Waypoint " .. waypointID)),
        mapID = data.mapID,
        x = data.x,
        y = data.y,
        z = data.z,
        source = O:Trim((data.source ~= nil and data.source ~= "") and data.source or "Odyssey"),
        sourceToken = data.sourceToken,
        createdAt = data.createdAt or time(),
        tags = CopyArray(data.tags),
        questID = data.questID,
        objectiveIndex = data.objectiveIndex,
        entryID = data.entryID,
    }
end

local function RefreshVisuals(refreshAll)
    if O.UI and O.UI.MapPins and O.UI.MapPins.Refresh then
        O.UI.MapPins:Refresh()
    end
    if O.UI and O.UI.RouteOverlay and O.UI.RouteOverlay.Refresh then
        O.UI.RouteOverlay:Refresh()
    end
    if O.UI and O.UI.MainFrame then
        if refreshAll and O.UI.MainFrame.RefreshAll then
            O.UI.MainFrame:RefreshAll()
        elseif O.UI.MainFrame.RefreshWaypointsPanel then
            O.UI.MainFrame:RefreshWaypointsPanel()
        end
    end
end

function Service:IsAvailable()
    return true
end

function Service:CanSetWaypoint()
    local providerName = O:GetPreferredProviderName()
    return providerName ~= nil, providerName or "None"
end

function Service:GetWaypoints()
    return O.db.waypoints
end

function Service:GetWaypointByID(waypointID)
    local _, waypoint = FindWaypointIndexByID(waypointID)
    return waypoint
end

function Service:NormalizeCoordinates(x, y)
    return NormalizeCoordinates(x, y)
end

function Service:FindDuplicateWaypoint(mapID, x, y, tolerance)
    mapID = tonumber(mapID) or 0
    x = tonumber(x)
    y = tonumber(y)
    if mapID <= 0 or not IsFiniteNumber(x) or not IsFiniteNumber(y) then
        return nil
    end
    tolerance = tonumber(tolerance) or tonumber(O.db.settings.duplicateTolerance) or 0.001

    for index, waypoint in ipairs(O.db.waypoints) do
        if tonumber(waypoint.mapID) == mapID then
            local dx = math.abs((tonumber(waypoint.x) or 0) - x)
            local dy = math.abs((tonumber(waypoint.y) or 0) - y)
            if dx <= tolerance and dy <= tolerance then
                return index, waypoint
            end
        end
    end

    return nil
end

function Service:AddWaypoint(data, mapID, x, y, options)
    if type(data) ~= "table" then
        options = type(options) == "table" and options or {}
        data = {
            title = data,
            mapID = mapID,
            x = x,
            y = y,
            autoTrack = options.autoTrack,
            source = options.source,
            tags = options.tags,
            questID = options.questID,
            allowDuplicate = options.allowDuplicate,
            duplicateTolerance = options.duplicateTolerance,
        }
    end

    local normalized, validationError = ValidateWaypointData(data)
    if not normalized then
        return nil, validationError
    end
    if #O.db.waypoints >= MAX_WAYPOINTS then
        return nil, "Waypoint limit reached."
    end

    if O.db.settings.suppressDuplicates and not normalized.allowDuplicate then
        local _, duplicate = self:FindDuplicateWaypoint(normalized.mapID, normalized.x, normalized.y, normalized.duplicateTolerance)
        if duplicate then
            if normalized.autoTrack or O.db.settings.autoTrackOnAdd then
                self:TrackWaypoint(duplicate.id)
            elseif O.UI.MainFrame then
                O.UI.MainFrame.selectedWaypointID = duplicate.id
                O.UI.MainFrame:RefreshWaypointsPanel()
            end
            return duplicate.id, true
        end
    end

    local waypointID = tonumber(O.db.nextIDs.waypoint) or 1
    O.db.nextIDs.waypoint = waypointID + 1
    local waypoint = CreateWaypointRecord(normalized, waypointID)

    O.db.waypoints[#O.db.waypoints + 1] = waypoint
    O:MarkDirty()

    if O.db.settings.autoTrackOnAdd or normalized.autoTrack then
        self:TrackWaypoint(waypoint.id)
    else
        if O.UI.MainFrame then
            O.UI.MainFrame.selectedWaypointID = waypoint.id
        end
        RefreshVisuals(false)
    end

    return waypoint.id, false
end

function Service:AddWaypoints(list, options)
    local addedIDs = {}
    if type(list) ~= "table" then
        return addedIDs
    end

    for _, waypoint in ipairs(list) do
        local payload = {}
        for key, value in pairs(waypoint) do
            payload[key] = value
        end
        if type(options) == "table" then
            for key, value in pairs(options) do
                if payload[key] == nil then
                    payload[key] = value
                end
            end
        end
        local waypointID = self:AddWaypoint(payload)
        if waypointID then
            addedIDs[#addedIDs + 1] = waypointID
        end
    end
    return addedIDs
end

function Service:AddWaypointsAtomic(list, options)
    if type(list) ~= "table" or #list == 0 then
        return nil, "Waypoint list is empty."
    end
    if #list > MAX_IMPORT_RECORDS then
        return nil, "Waypoint list exceeds the import limit."
    end
    if #O.db.waypoints + #list > MAX_WAYPOINTS then
        return nil, "Waypoint limit would be exceeded."
    end

    local prepared = {}
    for index, waypoint in ipairs(list) do
        local payload = {}
        if type(waypoint) ~= "table" then
            return nil, "Waypoint " .. index .. " is invalid."
        end
        for key, value in pairs(waypoint) do
            payload[key] = value
        end
        if type(options) == "table" then
            for key, value in pairs(options) do
                if payload[key] == nil then
                    payload[key] = value
                end
            end
        end
        payload.allowDuplicate = true
        local normalized, err = ValidateWaypointData(payload)
        if not normalized then
            return nil, "Waypoint " .. index .. ": " .. tostring(err)
        end
        prepared[#prepared + 1] = normalized
    end

    local addedIDs = {}
    for _, normalized in ipairs(prepared) do
        local waypointID = tonumber(O.db.nextIDs.waypoint) or 1
        O.db.nextIDs.waypoint = waypointID + 1
        O.db.waypoints[#O.db.waypoints + 1] = CreateWaypointRecord(normalized, waypointID)
        addedIDs[#addedIDs + 1] = waypointID
    end
    O:MarkDirty()
    RefreshVisuals(false)
    return addedIDs
end

function Service:SetWaypoint(xPercent, yPercent, mapID, options)
    options = type(options) == "table" and options or {}
    return self:AddWaypoint({
        title = options.title,
        mapID = mapID,
        x = xPercent,
        y = yPercent,
        autoTrack = options.autoTrack,
        source = options.source or "External",
        tags = options.tags,
        questID = options.questID,
        objectiveIndex = options.objectiveIndex,
        entryID = options.entryID,
        sourceToken = options.sourceToken,
        allowDuplicate = options.allowDuplicate,
        duplicateTolerance = options.duplicateTolerance,
    })
end

function Service:CapturePlayerPosition(title, options)
    local mapID, x, y = O:GetPlayerMapPosition()
    if not mapID then
        return nil, "Player position could not be resolved."
    end

    return self:AddWaypoint({
        title = title,
        mapID = mapID,
        x = x,
        y = y,
        -- Record the height the player is standing at. Without it the marker
        -- is built with z = 0 and hangs at that height rather than sitting
        -- where the waypoint was actually taken.
        z = O:GetPlayerElevation(),
        source = options and options.source or "Manual",
        tags = options and options.tags or { "manual" },
        autoTrack = options and options.autoTrack,
    })
end

function Service:CaptureActiveUserWaypoint(options)
    if not C_Map or not C_Map.GetUserWaypoint then
        return nil, "Blizzard user waypoints are not available."
    end

    local point = C_Map.GetUserWaypoint()
    if type(point) ~= "table" or not point.uiMapID or type(point.position) ~= "table" then
        return nil, "No active Blizzard waypoint found."
    end

    -- Read x/y off the table directly rather than through the Vector2D mixin.
    -- HousingCodex/Core/Waypoints.lua:157 documents that calling GetXY() on a
    -- GetUserWaypoint position can route through Blizzard's error handler on
    -- 12.1; the fields are always present, the method may not be.
    local x, y = point.position.x, point.position.y
    if (x == nil or y == nil) and type(point.position.GetXY) == "function" then
        local ok, px, py = pcall(point.position.GetXY, point.position)
        if ok then
            x, y = px, py
        end
    end
    if x == nil or y == nil then
        return nil, "No active Blizzard waypoint found."
    end

    local title = options and options.title
    if O:Trim(title) == "" then
        title = nil
    end

    return self:AddWaypoint({
        title = title or (options and options.fallbackTitle) or "Blizzard Waypoint",
        mapID = tonumber(point.uiMapID) or 0,
        x = x,
        y = y,
        -- Keep Blizzard's elevation. Dropping it here and rebuilding the point
        -- without a z is what left a re-tracked waypoint hanging in the air.
        z = tonumber(point.z),
        source = options and options.source or "Blizzard",
        tags = options and options.tags or { "blizzard", "user-waypoint" },
        autoTrack = options and options.autoTrack,
    })
end

function Service:CaptureSuperTrackedQuest(options)
    if not C_SuperTrack or not C_SuperTrack.GetSuperTrackedQuestID or not C_QuestLog or not C_QuestLog.GetNextWaypoint then
        return nil, "Supertracked quest APIs are not available."
    end

    local questID = tonumber(C_SuperTrack.GetSuperTrackedQuestID())
    if not questID or questID <= 0 then
        return nil, "No supertracked quest is active."
    end

    local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
    if not mapID or not x or not y then
        return nil, "The current supertracked quest has no waypoint."
    end

    local questTitle = nil
    if C_QuestLog.GetTitleForQuestID then
        questTitle = C_QuestLog.GetTitleForQuestID(questID)
    elseif C_QuestLog.GetQuestInfo then
        questTitle = C_QuestLog.GetQuestInfo(questID)
    end
    questTitle = O:Trim(questTitle)

    local title = options and options.title
    if O:Trim(title) == "" then
        title = nil
    end

    return self:AddWaypoint({
        title = title or ((questTitle ~= "" and questTitle) or ("Quest " .. questID)),
        mapID = tonumber(mapID) or 0,
        x = x,
        y = y,
        source = options and options.source or "Quest",
        tags = options and options.tags or { "quest", "supertracked" },
        autoTrack = options and options.autoTrack,
        questID = questID,
    })
end

function Service:CaptureWaypointFromMap(mapID, x, y, options)
    mapID = tonumber(mapID) or 0
    if mapID <= 0 then
        return nil, "Map ID is invalid."
    end

    return self:AddWaypoint({
        title = options and options.title or nil,
        mapID = mapID,
        x = x,
        y = y,
        source = options and options.source or "Map",
        tags = options and options.tags or { "map" },
        autoTrack = options and options.autoTrack,
        allowDuplicate = options and options.allowDuplicate,
    })
end

local function ClearTrackedProvider()
    if O._trackedProviderID and O._trackedProviderName then
        O:ClearProviderWaypoint(O._trackedProviderID, O._trackedProviderName)
    end
    O._trackedProviderID = nil
    O._trackedProviderName = nil
end

local function RemoveWaypointReferences(removedIDs)
    for _, tour in ipairs(O.db.tours) do
        local changed = false
        for index = #tour.waypointIDs, 1, -1 do
            if removedIDs[tonumber(tour.waypointIDs[index])] then
                table.remove(tour.waypointIDs, index)
                changed = true
            end
        end
        if changed then
            tour.updatedAt = time()
        end
    end

    local activeTour = O.Modules and O.Modules.Tours and O.Modules.Tours:GetActiveTour() or nil
    if activeTour then
        O.db.activeTourIndex = math.max(1, math.min(#activeTour.waypointIDs, tonumber(O.db.activeTourIndex) or 1))
    else
        O.db.activeTourIndex = 1
    end
end

function Service:RemoveWaypoint(waypointID)
    local index = FindWaypointIndexByID(waypointID)
    if not index then
        return false
    end

    local removedIDs = { [tonumber(waypointID)] = true }
    if removedIDs[tonumber(O.db.trackedWaypointID)] then
        ClearTrackedProvider()
        O.db.trackedWaypointID = nil
    end
    RemoveWaypointReferences(removedIDs)

    table.remove(O.db.waypoints, index)
    O:MarkDirty()
    RefreshVisuals(true)
    return true
end

function Service:ClearAllWaypoints()
    ClearTrackedProvider()
    O.db.trackedWaypointID = nil
    wipe(O.db.waypoints)
    for _, tour in ipairs(O.db.tours) do
        wipe(tour.waypointIDs)
        tour.updatedAt = time()
    end
    O:MarkDirty()
    RefreshVisuals(true)
    return true
end

function Service:ClearWaypoint(waypointID)
    return self:RemoveWaypoint(waypointID)
end

function Service:ClearAll()
    return self:ClearAllWaypoints()
end

function Service:TrackWaypoint(waypointID)
    local waypoint = self:GetWaypointByID(waypointID)
    if not waypoint then
        return nil
    end

    ClearTrackedProvider()

    local providerID, providerName, providerError = O:SetProviderWaypoint(waypoint)
    O.db.trackedWaypointID = waypoint.id
    O._trackedProviderID = providerID
    O._trackedProviderName = providerName
    O:MarkDirty()

    if O.UI.MainFrame then
        O.UI.MainFrame.selectedWaypointID = waypoint.id
    end
    RefreshVisuals(false)
    if O.UI.MainFrame and O.UI.MainFrame.RefreshToursPanel then
        O.UI.MainFrame:RefreshToursPanel()
    end
    if O.UI.HUD and O.UI.HUD.Refresh then
        O.UI.HUD:Refresh()
    end
    return providerID, providerName or providerError
end

function Service:UntrackWaypoint()
    local changed = O.db.trackedWaypointID ~= nil or O._trackedProviderID ~= nil
    ClearTrackedProvider()
    O.db.trackedWaypointID = nil
    if changed then
        O:MarkDirty()
    end

    RefreshVisuals(false)
    if O.UI.MainFrame and O.UI.MainFrame.RefreshToursPanel then
        O.UI.MainFrame:RefreshToursPanel()
    end
    if O.UI.HUD and O.UI.HUD.Refresh then
        O.UI.HUD:Refresh()
    end
    return changed
end

function Service:RestoreTrackedWaypoint()
    local waypointID = tonumber(O.db and O.db.trackedWaypointID)
    if not waypointID then
        return false, "No persisted waypoint is tracked."
    end
    local waypoint = self:GetWaypointByID(waypointID)
    if not waypoint then
        O.db.trackedWaypointID = nil
        O:MarkDirty()
        return false, "Persisted tracked waypoint no longer exists."
    end

    ClearTrackedProvider()
    local providerID, providerName, providerError = O:SetProviderWaypoint(waypoint)
    O._trackedProviderID = providerID
    O._trackedProviderName = providerName
    RefreshVisuals(false)
    return true, providerName or providerError
end

function Service:MoveWaypoint(waypointID, delta)
    local index = FindWaypointIndexByID(waypointID)
    if not index then
        return false
    end

    local newIndex = index + (tonumber(delta) or 0)
    newIndex = math.max(1, math.min(#O.db.waypoints, newIndex))
    if newIndex == index then
        return false
    end

    local waypoint = table.remove(O.db.waypoints, index)
    table.insert(O.db.waypoints, newIndex, waypoint)
    O:MarkDirty()

    if O.UI.MainFrame then
        O.UI.MainFrame.selectedWaypointID = waypoint.id
        O.UI.MainFrame:RefreshWaypointsPanel()
    end
    return true
end

function Service:RemoveWaypointsByTag(tag)
    if type(tag) ~= "string" or tag == "" then
        return 0
    end

    local removedIDs = {}
    local retained = {}
    local removed = 0
    for _, waypoint in ipairs(O.db.waypoints) do
        if WaypointHasTag(waypoint, tag) then
            removedIDs[tonumber(waypoint.id)] = true
            removed = removed + 1
        else
            retained[#retained + 1] = waypoint
        end
    end

    if removed > 0 then
        if removedIDs[tonumber(O.db.trackedWaypointID)] then
            ClearTrackedProvider()
            O.db.trackedWaypointID = nil
        end
        O.db.waypoints = retained
        RemoveWaypointReferences(removedIDs)
        O:MarkDirty()
        RefreshVisuals(true)
    end

    return removed
end

function Service:ReplaceWaypointsByTag(tag, list)
    if type(tag) ~= "string" or tag == "" then
        return nil, "Ownership tag is invalid."
    end
    if type(list) ~= "table" or #list == 0 then
        return nil, "Replacement waypoint list is empty."
    end
    if #list > MAX_IMPORT_RECORDS then
        return nil, "Replacement waypoint list exceeds the limit."
    end

    local prepared = {}
    for index, data in ipairs(list) do
        local normalized, err = ValidateWaypointData(data)
        if not normalized then
            return nil, "Waypoint " .. index .. ": " .. tostring(err)
        end
        if not WaypointHasTag(normalized, tag) then
            normalized.tags[#normalized.tags + 1] = tag
        end
        prepared[#prepared + 1] = normalized
    end

    local removedIDs = {}
    local retained = {}
    for _, waypoint in ipairs(O.db.waypoints) do
        if WaypointHasTag(waypoint, tag) then
            removedIDs[tonumber(waypoint.id)] = true
        else
            retained[#retained + 1] = waypoint
        end
    end
    if #retained + #prepared > MAX_WAYPOINTS then
        return nil, "Waypoint limit would be exceeded."
    end

    local nextID = tonumber(O.db.nextIDs.waypoint) or 1
    local records, addedIDs = {}, {}
    for _, data in ipairs(prepared) do
        records[#records + 1] = CreateWaypointRecord(data, nextID)
        addedIDs[#addedIDs + 1] = nextID
        nextID = nextID + 1
    end

    if removedIDs[tonumber(O.db.trackedWaypointID)] then
        ClearTrackedProvider()
        O.db.trackedWaypointID = nil
    end
    RemoveWaypointReferences(removedIDs)
    for _, record in ipairs(records) do
        retained[#retained + 1] = record
    end
    O.db.waypoints = retained
    O.db.nextIDs.waypoint = nextID
    O:MarkDirty()
    RefreshVisuals(true)
    return addedIDs
end

function Service:ReorderWaypoint(waypointID, newIndex)
    local index = FindWaypointIndexByID(waypointID)
    if not index then
        return false
    end

    newIndex = tonumber(newIndex)
    if not newIndex then
        return false
    end

    newIndex = math.max(1, math.min(#O.db.waypoints, math.floor(newIndex)))
    if newIndex == index then
        return false
    end

    local waypoint = table.remove(O.db.waypoints, index)
    table.insert(O.db.waypoints, newIndex, waypoint)
    O:MarkDirty()

    if O.UI.MainFrame then
        O.UI.MainFrame.selectedWaypointID = waypoint.id
        O.UI.MainFrame:RefreshWaypointsPanel()
    end
    return true
end

function Service:AttachWaypointToTour(tourID, waypointID)
    waypointID = tonumber(waypointID)
    if not waypointID or not self:GetWaypointByID(waypointID) then
        return false
    end

    local tour = O.Modules.Tours:GetTourByID(tourID)
    if not tour then
        return false
    end

    table.insert(tour.waypointIDs, waypointID)
    tour.updatedAt = time()
    O:MarkDirty()
    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshToursPanel()
    end
    return true
end

function Service:ExportWaypoints(scope)
    local parts = { "ODYSSEY:1" }

    if scope == "tour" then
        local tour = O.Modules.Tours:GetActiveTour()
        if not tour then
            return table.concat(parts, "|")
        end
        local title = UrlEncode(tour.name)
        parts[#parts + 1] = "TOUR," .. title
        for _, waypointID in ipairs(tour.waypointIDs) do
            local waypoint = self:GetWaypointByID(waypointID)
            if waypoint then
                parts[#parts + 1] = string.format("W,%d,%.5f,%.5f,%s,%s", waypoint.mapID, waypoint.x, waypoint.y, UrlEncode(waypoint.title), UrlEncode(waypoint.source))
            end
        end
    else
        for _, waypoint in ipairs(O.db.waypoints) do
            parts[#parts + 1] = string.format("W,%d,%.5f,%.5f,%s,%s", waypoint.mapID, waypoint.x, waypoint.y, UrlEncode(waypoint.title), UrlEncode(waypoint.source))
        end
    end

    return table.concat(parts, "|")
end

function Service:Export()
    return self:ExportWaypoints("all")
end

function Service:ImportWaypoints(payload, options)
    payload = O:Trim(payload)
    if #payload > MAX_IMPORT_BYTES then
        return 0, "Import payload exceeds the size limit."
    end
    local header, remainder = payload:match("^(ODYSSEY:%d+)%|(.*)$")
    if not header then
        header, remainder = payload:match("^(ARIADNE:%d+)%|(.*)$")
    end
    if not header then
        return 0, "Unsupported waypoint import format."
    end
    local version = tonumber(header:match(":(%d+)$"))
    if version ~= 1 then
        return 0, "Unsupported waypoint format version: " .. tostring(version)
    end

    local importedTourName = nil
    local pending = {}

    for chunk in string.gmatch(remainder or "", "([^|]+)") do
        if chunk:match("^TOUR,") then
            importedTourName = UrlDecode(chunk:sub(6))
        else
            local mapID, x, y, titleEnc, sourceEnc = chunk:match("^W?,?(%-?%d+),([%d%.]+),([%d%.]+),([^,]+),?(.*)$")
            if not (mapID and x and y) then
                return 0, "Import contains a malformed waypoint record."
            end
            pending[#pending + 1] = {
                title = UrlDecode(titleEnc),
                mapID = tonumber(mapID),
                x = tonumber(x),
                y = tonumber(y),
                source = UrlDecode(sourceEnc ~= "" and sourceEnc or "Import"),
                autoTrack = false,
                tags = { "imported" },
                allowDuplicate = true,
            }
            if #pending > MAX_IMPORT_RECORDS then
                return 0, "Import contains too many waypoints."
            end
        end
    end

    if #pending == 0 then
        return 0, "Import contains no waypoints."
    end

    local addedIDs, err = self:AddWaypointsAtomic(pending)
    if not addedIDs then
        return 0, err
    end

    if importedTourName and #addedIDs > 0 then
        O.Modules.Tours:CreateTour(importedTourName, addedIDs)
    end

    if type(options) == "table" and options.trackNewest and #addedIDs > 0 then
        local newestWaypointID = addedIDs[#addedIDs]
        if newestWaypointID then
            self:TrackWaypoint(newestWaypointID)
        end
    end

    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshAll()
    end
    return #addedIDs
end

function Service:Import(payload, options)
    return self:ImportWaypoints(payload, options)
end

function Service:RegisterOptimizer(name, callback)
    if type(name) ~= "string" or type(callback) ~= "function" then
        return false
    end
    O._routeOptimizers = O._routeOptimizers or {}
    O._routeOptimizers[name] = callback
    return true
end

function Service:OptimizeRoute(name, waypointIDs)
    local optimizers = O._routeOptimizers or {}
    local optimizer = optimizers[name]
    if type(optimizer) ~= "function" then
        return nil
    end
    return optimizer(waypointIDs)
end

function Service:BuildExternalWaypoint(kind, payload, options)
    return ResolveExternalPayload(kind, payload, options)
end

function Service:ExportRouteToString(tourID)
    if not O.Services.RouteShare then
        return nil, "RouteShare service unavailable."
    end
    return O.Services.RouteShare:ExportTour(tourID)
end

function Service:ImportRouteFromString(str, options)
    if not O.Services.RouteShare then
        return nil, "RouteShare service unavailable."
    end
    return O.Services.RouteShare:ImportFromString(str, options)
end

function Service:OptimizeActiveTour()
    if not O.Services.RouteOptimizer or not O.Modules or not O.Modules.Tours then
        return false
    end
    local tour = O.Modules.Tours:GetActiveTour()
    if not tour then
        return false
    end
    local changed = O.Services.RouteOptimizer:OptimizeTour(tour)
    if changed then
        if O.UI and O.UI.MainFrame and O.UI.MainFrame.RefreshAll then
            O.UI.MainFrame:RefreshAll()
        end
        if O.UI and O.UI.RouteOverlay and O.UI.RouteOverlay.Refresh then
            O.UI.RouteOverlay:Refresh()
        end
    end
    return changed
end
