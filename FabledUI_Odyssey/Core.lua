local addonName, ns = ...

ns = ns or {}
ns.Odyssey = ns.Odyssey or {}

local O = ns.Odyssey
_G.FabledUI_Odyssey = O

O.NAME = addonName
O.DISPLAY_NAME = "FabledUI - Odyssey"
O.VERSION = "2.3.1"
O.DB_NAMESPACE = "odyssey"
O.API_VERSION = 2

O.Modules = O.Modules or {}
O.UI = O.UI or {}
O.Settings = O.Settings or {}
O.Services = O.Services or {}

-- ==========================================
-- FABLENEON THEME (cosmetic only)
-- ==========================================
local TK = rawget(_G, "FabledUI_UIToolkit")
local FN_ACCENT = { 0.31, 0.72, 0.91, 1.0 } -- azure (journey/wayfinding)

local function StyleButton(b)
    if b and TK and TK.Themes and TK.Themes.StyleFlatButton then
        TK.Themes:StyleFlatButton(b, "FableNeon", FN_ACCENT)
    end
end

local eventFrame = CreateFrame("Frame")
O.EventFrame = eventFrame

local function SafeCall(methodName, ...)
    local method = O[methodName]
    if type(method) == "function" then
        return method(O, ...)
    end
end

function O:Print(message)
    print("|cff4fb8e8[Odyssey]|r " .. tostring(message))
end

function O:Debug(message)
    if self.db and self.db.settings and self.db.settings.debug then
        self:Print("|cff9aa5b1" .. tostring(message) .. "|r")
    end
end

function O:MarkDirty()
    local vault = rawget(_G, "DataVault")
    if self._storageBackend == "DataVault"
        and vault and type(vault.IsAvailable) == "function" and vault:IsAvailable()
        and type(vault.Mutate) == "function"
    then
        local updated = vault:Mutate("account", self.DB_NAMESPACE, function(current)
            return type(self.db) == "table" and self.db or current or {}
        end)
        if type(updated) == "table" then
            self.db = updated
            return true
        end
        return false
    end

    if type(self.db) == "table" then
        _G.FabledUI_OdysseyDB = self.db
        return true
    end
    return false
end

function O:MutateDB(mutator)
    if type(mutator) ~= "function" then
        return nil, "Storage mutation callback is invalid."
    end

    local vault = rawget(_G, "DataVault")
    if self._storageBackend == "DataVault"
        and vault and type(vault.IsAvailable) == "function" and vault:IsAvailable()
        and type(vault.Mutate) == "function"
    then
        local updated = vault:Mutate("account", self.DB_NAMESPACE, function(current)
            current = type(current) == "table" and current or {}
            local replacement = mutator(current)
            return type(replacement) == "table" and replacement or current
        end)
        if type(updated) == "table" then
            self.db = updated
            return updated
        end
        return nil, "DataVault mutation failed."
    end

    self.db = type(self.db) == "table" and self.db or {}
    local replacement = mutator(self.db)
    if type(replacement) == "table" then
        self.db = replacement
    end
    _G.FabledUI_OdysseyDB = self.db
    return self.db
end

function O:RecordIntegrationRequest(operation, source, succeeded, detail)
    if type(self.db) ~= "table" then
        return
    end

    self.db.integrationLog = type(self.db.integrationLog) == "table" and self.db.integrationLog or {}
    self.db.integrationLog[#self.db.integrationLog + 1] = {
        operation = self:SafeString(operation),
        source = self:SafeString(source),
        succeeded = succeeded and true or false,
        detail = self:SafeString(detail),
        timestamp = time(),
    }
    while #self.db.integrationLog > 50 do
        table.remove(self.db.integrationLog, 1)
    end
    self:MarkDirty()
end

function O:Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

function O:SafeString(value)
    -- nil maps to the empty string, not to tostring(nil) == "nil". Every
    -- absence check in the addon is written as `Trim(x) == ""`, so returning
    -- the four-character word "nil" made all of them miss: a nil tour name
    -- became a tour literally called "nil", and a nil whisper target passed
    -- the "a target is required" guard.
    if value == nil then
        return ""
    end
    local ok, text = pcall(tostring, value)
    return ok and type(text) == "string" and text or ""
end

function O:Trim(value)
    -- Parenthesised so gsub's replacement count stays out of the return list.
    -- Bare `return s:gsub(...)` hands back two values, which silently becomes
    -- an extra argument wherever Trim is the last thing passed to a function.
    return (self:SafeString(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

function O:Round(value, places)
    local p = 10 ^ (tonumber(places) or 0)
    return math.floor((tonumber(value) or 0) * p + 0.5) / p
end

local function NormalizeIntegrationSource(source)
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

local function BuildIntegrationTag(prefix, source)
    return string.format("%s:%s", prefix, NormalizeIntegrationSource(source))
end

local function EnsureSourceOnPayload(payload, fallbackSource)
    if type(payload) ~= "table" then
        return {}
    end
    local copy = {}
    for key, value in pairs(payload) do
        copy[key] = value
    end
    if O:Trim(copy.source) == "" then
        copy.source = fallbackSource
    end
    return copy
end

-- The suite accumulated both `provider:Method(...)` and
-- `provider.Method(...)` callers. Public methods deliberately normalize both
-- shapes. Their first return value remains compatible with API v1; richer
-- failure detail is returned second.
local function HasPublicReceiver(value)
    return value == O
end

function O.IsAvailable(_receiver)
    local service = O.Services and O.Services.WaypointService
    return service and service:IsAvailable() or false
end

function O.CanSetWaypoint(_receiver)
    local service = O.Services and O.Services.WaypointService
    if not service then
        return false, "None"
    end
    return service:CanSetWaypoint()
end

function O.AddWaypoint(receiverOrTitle, titleOrMapID, mapIDOrX, xOrY, yOrOptions, maybeOptions)
    local title, mapID, x, y, options
    if HasPublicReceiver(receiverOrTitle) then
        title, mapID, x, y, options = titleOrMapID, mapIDOrX, xOrY, yOrOptions, maybeOptions
    else
        title, mapID, x, y, options = receiverOrTitle, titleOrMapID, mapIDOrX, xOrY, yOrOptions
    end

    local service = O.Services and O.Services.WaypointService
    if not service then
        return nil, "Waypoint service unavailable."
    end
    return service:AddWaypoint(title, mapID, x, y, options)
end

function O.SetWaypoint(receiverOrX, xOrY, yOrMapID, mapIDOrOptions, maybeOptions)
    local x, y, mapID, options
    if HasPublicReceiver(receiverOrX) then
        x, y, mapID, options = xOrY, yOrMapID, mapIDOrOptions, maybeOptions
    else
        x, y, mapID, options = receiverOrX, xOrY, yOrMapID, mapIDOrOptions
    end

    local service = O.Services and O.Services.WaypointService
    if not service then
        return nil, "Waypoint service unavailable."
    end
    return service:SetWaypoint(x, y, mapID, options)
end

function O.NavigateToWaypoint(receiverOrMapID, mapIDOrX, xOrY, yOrOptions, maybeOptions)
    local mapID, x, y, options
    if HasPublicReceiver(receiverOrMapID) then
        mapID, x, y, options = mapIDOrX, xOrY, yOrOptions, maybeOptions
    else
        mapID, x, y, options = receiverOrMapID, mapIDOrX, xOrY, yOrOptions
    end
    -- Copy before defaulting autoTrack. Villa passes an options table it owns
    -- (FabledUI_Villa/Core.lua:200); writing into it would hand a caller back a
    -- table this function had quietly edited.
    local resolved = {}
    if type(options) == "table" then
        for key, value in pairs(options) do
            resolved[key] = value
        end
    end
    resolved.autoTrack = resolved.autoTrack ~= false
    return O.SetWaypoint(O, x, y, mapID, resolved)
end

function O.StartNavigation(receiverOrMapID, mapIDOrX, xOrY, yOrLabel, maybeLabel)
    local mapID, x, y, label
    if HasPublicReceiver(receiverOrMapID) then
        mapID, x, y, label = mapIDOrX, xOrY, yOrLabel, maybeLabel
    else
        mapID, x, y, label = receiverOrMapID, mapIDOrX, xOrY, yOrLabel
    end
    return O.SetWaypoint(O, x, y, mapID, {
        title = label,
        source = "Navigation",
        autoTrack = true,
        tags = { "navigation", "external" },
    })
end

function O.ClearWaypoint(receiverOrID, maybeID)
    local waypointID = HasPublicReceiver(receiverOrID) and maybeID or receiverOrID
    local service = O.Services and O.Services.WaypointService
    if not service then
        return false, "Waypoint service unavailable."
    end
    return service:ClearWaypoint(waypointID)
end

function O.ClearAll(_receiver)
    local service = O.Services and O.Services.WaypointService
    if not service then
        return false, "Waypoint service unavailable."
    end
    return service:ClearAll()
end

function O.Export(_receiver)
    local service = O.Services and O.Services.WaypointService
    if not service then
        return "", "Waypoint service unavailable."
    end
    return service:Export()
end

function O.Import(receiverOrSerialized, maybeSerialized)
    local serialized = HasPublicReceiver(receiverOrSerialized) and maybeSerialized or receiverOrSerialized
    local service = O.Services and O.Services.WaypointService
    if not service then
        return 0, "Waypoint service unavailable."
    end
    return service:Import(serialized)
end

function O.ExportRoute(receiverOrTourID, maybeTourID)
    local tourID = HasPublicReceiver(receiverOrTourID) and maybeTourID or receiverOrTourID
    local share = O.Services and O.Services.RouteShare
    if not share or type(share.ExportTour) ~= "function" then
        return nil, "Route sharing service unavailable."
    end
    return share:ExportTour(tourID)
end

function O.ImportRoute(receiverOrSerialized, maybeSerialized)
    local serialized = HasPublicReceiver(receiverOrSerialized) and maybeSerialized or receiverOrSerialized
    local share = O.Services and O.Services.RouteShare
    if not share or type(share.ImportFromString) ~= "function" then
        return nil, "Route sharing service unavailable."
    end
    return share:ImportFromString(serialized)
end

function O.OptimizeActive(_receiver)
    local service = O.Services and O.Services.WaypointService
    if not service or type(service.OptimizeActiveTour) ~= "function" then
        return false, "Waypoint service unavailable."
    end
    return service:OptimizeActiveTour()
end

function O.SendRouteToChat(receiverOrTourID, tourIDOrChatType, chatTypeOrTarget, maybeTarget)
    local tourID, chatType, target
    if HasPublicReceiver(receiverOrTourID) then
        tourID, chatType, target = tourIDOrChatType, chatTypeOrTarget, maybeTarget
    else
        tourID, chatType, target = receiverOrTourID, tourIDOrChatType, chatTypeOrTarget
    end

    local share = O.Services and O.Services.RouteShare
    if not share or type(share.SendRouteToChat) ~= "function" then
        return false, "Route sharing service unavailable."
    end

    local exportString, exportError = share:ExportTour(tourID)
    if not exportString then
        return false, exportError
    end
    local tour = O.Modules and O.Modules.Tours
        and (tourID and O.Modules.Tours:GetTourByID(tourID) or O.Modules.Tours:GetActiveTour()) or nil
    return share:SendRouteToChat(exportString, chatType or "PARTY", target or chatType, tour and tour.name or "Route", target)
end

function O.GetCapabilities(_receiver)
    local canSet, providerName = O.CanSetWaypoint(O)
    return {
        apiVersion = O.API_VERSION,
        waypointService = true,
        canSetWaypoint = canSet,
        provider = providerName,
        importExport = true,
        routeFormatVersion = 3,
        tours = true,
        routeInjection = true,
        focusTarget = true,
        dotCalls = true,
    }
end

local function AddIntegratedWaypoint(kind, payload, sourceOverride, extraTags, autoTrack)
    if not O.Services or not O.Services.WaypointService then
        return nil
    end

    payload = EnsureSourceOnPayload(payload, sourceOverride)
    local source = payload.source or sourceOverride or kind or "external"
    local tags = { "external", "kind:" .. tostring(kind or "waypoint") }
    if type(extraTags) == "table" then
        for _, tag in ipairs(extraTags) do
            tags[#tags + 1] = tag
        end
    end

    local data, err = O.Services.WaypointService:BuildExternalWaypoint(kind, payload, {
        source = source,
        tags = tags,
    })
    if not data then
        O:Debug("Integration waypoint rejected: " .. tostring(err))
        return nil
    end

    data.autoTrack = autoTrack == true
    -- Integration-owned entries must remain independently removable even if a
    -- user saved the same coordinates manually.
    data.allowDuplicate = true
    return O.Services.WaypointService:AddWaypoint(data)
end

function O.PushRouteEntry(receiverOrKind, kindOrPayload, maybePayload)
    local kind, payload
    if HasPublicReceiver(receiverOrKind) then
        kind, payload = kindOrPayload, maybePayload
    else
        kind, payload = receiverOrKind, kindOrPayload
    end
    payload = EnsureSourceOnPayload(payload, "External")
    local source = payload.source or "External"
    local waypointID, err = AddIntegratedWaypoint(kind, payload, source, {
        BuildIntegrationTag("route-source", source),
    }, true)
    O:RecordIntegrationRequest("PushRouteEntry", source, waypointID ~= nil, err or waypointID)
    return waypointID ~= nil, waypointID or err
end

function O.ReplaceRoute(receiverOrSource, sourceOrEntries, maybeEntries)
    local sourceKey, entries
    if HasPublicReceiver(receiverOrSource) then
        sourceKey, entries = sourceOrEntries, maybeEntries
    else
        sourceKey, entries = receiverOrSource, sourceOrEntries
    end

    local service = O.Services and O.Services.WaypointService
    if not service or type(service.ReplaceWaypointsByTag) ~= "function" then
        return false, "Waypoint service unavailable."
    end

    local source = sourceKey
    if (source == nil or source == "") and type(entries) == "table" and type(entries[1]) == "table" and type(entries[1].payload) == "table" then
        source = entries[1].payload.source
    end
    source = source or "External"

    if type(entries) ~= "table" or #entries == 0 then
        O:RecordIntegrationRequest("ReplaceRoute", source, false, "Route entries are empty.")
        return false, "Route entries are empty."
    end

    local ownerTag = BuildIntegrationTag("route-source", source)
    local prepared = {}
    for index, entry in ipairs(entries) do
        if type(entry) ~= "table" then
            local err = "Route entry " .. index .. " is invalid."
            O:RecordIntegrationRequest("ReplaceRoute", source, false, err)
            return false, err
        end

        local kind = entry.kind or "waypoint"
        local payload = EnsureSourceOnPayload(type(entry.payload) == "table" and entry.payload or entry, source)
        local data, err = service:BuildExternalWaypoint(kind, payload, {
            source = source,
            tags = { "external", "kind:" .. tostring(kind), ownerTag },
        })
        if not data then
            err = "Route entry " .. index .. ": " .. tostring(err)
            O:RecordIntegrationRequest("ReplaceRoute", source, false, err)
            return false, err
        end
        data.allowDuplicate = true
        prepared[#prepared + 1] = data
    end

    -- If the user opted into auto-optimization, reorder the entries before
    -- they're persisted as waypoints. Optimization is skipped for short
    -- routes (< 3 stops) and silently bypassed if RouteOptimizer is missing.
    if O.Services.RouteOptimizer
        and O.Services.RouteOptimizer.IsAutoMode
        and O.Services.RouteOptimizer:IsAutoMode()
        and #prepared >= 3
    then
        local pMap, px, py = O:GetPlayerMapPosition()
        prepared = O.Services.RouteOptimizer:OptimizeEntries(prepared, px, py, pMap)
    end

    local addedIDs, err = service:ReplaceWaypointsByTag(ownerTag, prepared)
    if not addedIDs then
        O:RecordIntegrationRequest("ReplaceRoute", source, false, err)
        return false, err
    end

    service:TrackWaypoint(addedIDs[1])
    O:RecordIntegrationRequest("ReplaceRoute", source, true, #addedIDs)
    return true, addedIDs
end

function O.SetFocusTarget(receiverOrKind, kindOrPayload, maybePayload)
    local kind, payload
    if HasPublicReceiver(receiverOrKind) then
        kind, payload = kindOrPayload, maybePayload
    else
        kind, payload = receiverOrKind, kindOrPayload
    end

    local service = O.Services and O.Services.WaypointService
    if not service or type(service.ReplaceWaypointsByTag) ~= "function" then
        return false, "Waypoint service unavailable."
    end
    payload = EnsureSourceOnPayload(payload, "External")
    local source = payload.source or "External"
    local data, err = service:BuildExternalWaypoint(kind, payload, {
        source = source,
        tags = { "external", "kind:" .. tostring(kind or "waypoint"), "focus-target", BuildIntegrationTag("focus-source", source) },
    })
    if not data then
        O:RecordIntegrationRequest("SetFocusTarget", source, false, err)
        return false, err
    end
    data.allowDuplicate = true

    local addedIDs
    addedIDs, err = service:ReplaceWaypointsByTag("focus-target", { data })
    if not addedIDs then
        O:RecordIntegrationRequest("SetFocusTarget", source, false, err)
        return false, err
    end

    service:TrackWaypoint(addedIDs[1])
    O:RecordIntegrationRequest("SetFocusTarget", source, true, addedIDs[1])
    return true, addedIDs[1]
end

function O.ClearFocusTarget(receiverOrSource, maybeSource)
    local sourceKey = HasPublicReceiver(receiverOrSource) and maybeSource or receiverOrSource
    local service = O.Services and O.Services.WaypointService
    if not service then
        return false, "Waypoint service unavailable."
    end

    local removed = 0
    if sourceKey and sourceKey ~= "" then
        removed = service:RemoveWaypointsByTag(BuildIntegrationTag("focus-source", sourceKey))
    else
        removed = service:RemoveWaypointsByTag("focus-target")
    end
    O:RecordIntegrationRequest("ClearFocusTarget", sourceKey or "*", removed > 0, removed)
    return removed > 0
end

function O.OpenMapToTarget(receiverOrKind, kindOrPayload, maybePayload)
    local kind, payload
    if HasPublicReceiver(receiverOrKind) then
        kind, payload = kindOrPayload, maybePayload
    else
        kind, payload = receiverOrKind, kindOrPayload
    end
    payload = EnsureSourceOnPayload(payload, "External")
    local source = payload.source or "External"
    local waypointID, err = AddIntegratedWaypoint(kind, payload, source, {
        BuildIntegrationTag("route-source", source),
    }, false)
    if not waypointID then
        O:RecordIntegrationRequest("OpenMapToTarget", source, false, err)
        return false, err
    end

    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap")
    end
    if WorldMapFrame and WorldMapFrame.Show then
        WorldMapFrame:Show()
        local waypoint = O.Services.WaypointService:GetWaypointByID(waypointID)
        if waypoint and WorldMapFrame.SetMapID then
            pcall(WorldMapFrame.SetMapID, WorldMapFrame, waypoint.mapID)
        end
    end

    O.Services.WaypointService:TrackWaypoint(waypointID)
    O:RecordIntegrationRequest("OpenMapToTarget", source, true, waypointID)
    return true, waypointID
end

function O:FormatDistance(yards)
    yards = tonumber(yards)
    if not yards then
        return "--"
    end
    yards = math.max(0, yards)
    if yards >= 1760 then
        return string.format("%.2f mi", yards / 1760)
    end
    return string.format("%d yd", math.floor(yards + 0.5))
end

function O:FormatTime(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return "--"
    end
    if seconds > 86400 then
        return ">24h"
    end

    local minutes = math.floor(seconds / 60)
    local remSeconds = math.floor(seconds % 60)
    if minutes >= 60 then
        return string.format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm %02ds", minutes, remSeconds)
end

function O:GetPlayerMapPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position or not position.GetXY then
        return nil
    end

    local x, y = position:GetXY()
    if not x or not y then
        return nil
    end

    return mapID, x, y
end

function O:CaptureCurrentUserWaypoint(autoTrack)
    local waypointID, duplicateOrError = self.Services.WaypointService:CaptureActiveUserWaypoint({
        autoTrack = autoTrack,
        source = "Blizzard",
        tags = { "blizzard", "user-waypoint" },
    })

    if waypointID then
        if self.UI.MainFrame then
            local title = duplicateOrError and "Waypoint already saved" or "Waypoint saved"
            local body = duplicateOrError and "That Blizzard waypoint was already in Odyssey." or "Blizzard user waypoint imported into Odyssey."
            self.UI.MainFrame:Toast(title, body)
        end
        return waypointID
    end

    if self.UI.MainFrame and type(duplicateOrError) == "string" and duplicateOrError ~= "" then
        self.UI.MainFrame:Toast("Capture failed", duplicateOrError)
    end
    return nil
end

function O:CaptureCurrentSuperTrackedQuest(autoTrack)
    local waypointID, duplicateOrError = self.Services.WaypointService:CaptureSuperTrackedQuest({
        autoTrack = autoTrack,
        source = "Quest",
        tags = { "quest", "supertracked" },
    })

    if waypointID then
        if self.UI.MainFrame then
            local title = duplicateOrError and "Quest waypoint already saved" or "Quest waypoint imported"
            local body = duplicateOrError and "That quest destination was already present in Odyssey." or "Supertracked quest destination imported into Odyssey."
            self.UI.MainFrame:Toast(title, body)
        end
        return waypointID
    end

    if self.UI.MainFrame and type(duplicateOrError) == "string" and duplicateOrError ~= "" then
        self.UI.MainFrame:Toast("Quest capture failed", duplicateOrError)
    end
    return nil
end

function O:IsConfiguredMapClickModifierDown()
    local modifier = string.upper(self.db and self.db.settings and self.db.settings.mapClickCaptureModifier or "ALT")
    if modifier == "SHIFT" then
        return IsShiftKeyDown and IsShiftKeyDown()
    elseif modifier == "CTRL" then
        return IsControlKeyDown and IsControlKeyDown()
    end
    return IsAltKeyDown and IsAltKeyDown()
end

function O:GetMapClickModifierLabel()
    local modifier = string.upper(self.db and self.db.settings and self.db.settings.mapClickCaptureModifier or "ALT")
    if modifier == "SHIFT" then
        return "Shift"
    elseif modifier == "CTRL" then
        return "Ctrl"
    end
    return "Alt"
end

function O:GetNormalizedCursorPositionForFrame(frame)
    if not frame or not frame.GetLeft or not frame.GetBottom or not frame.GetWidth or not frame.GetHeight then
        return nil
    end

    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        return nil
    end

    local scale = frame:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local x = (cursorX - left) / width
    local y = ((bottom + height) - cursorY) / height
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end
    return self:Clamp01(x), self:Clamp01(y)
end

function O:CaptureWaypointFromWorldMapCursor(autoTrack)
    if not WorldMapFrame or not WorldMapFrame:IsShown() or not WorldMapFrame.GetMapID then
        return nil, "World map is not open."
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID or mapID <= 0 then
        return nil, "Current world map has no valid map ID."
    end

    local captureFrame = WorldMapFrame.ScrollContainer and (WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer) or WorldMapFrame
    local x, y = self:GetNormalizedCursorPositionForFrame(captureFrame)
    if not x or not y then
        return nil, "Cursor is not over the world map."
    end

    local title = string.format("Map Pin %.1f, %.1f", x * 100, y * 100)
    local waypointID, duplicateOrError = self.Services.WaypointService:CaptureWaypointFromMap(mapID, x, y, {
        autoTrack = autoTrack,
        source = "MapClick",
        tags = { "map", "click", "manual" },
        title = title,
    })

    if waypointID and self.UI.MainFrame then
        local titleText = duplicateOrError and "Map waypoint already saved" or "Map waypoint saved"
        local bodyText = duplicateOrError and "That map location was already in Odyssey." or "World map location imported into Odyssey."
        self.UI.MainFrame:Toast(titleText, bodyText)
    end
    return waypointID, duplicateOrError
end

function O:RefreshWorldMapButtons()
    if not self._worldMapControls then
        return
    end

    local show = self.db and self.db.settings and self.db.settings.showWorldMapButton
    local controls = self._worldMapControls
    if show then
        controls.container:Show()
        controls.container:SetHeight(52)
        if controls.mapButton then
            controls.mapButton:SetText("Save Map Cursor")
            controls.mapButton:SetShown(self.db.settings.mapClickCaptureEnabled)
        end
        if controls.hint then
            controls.hint:SetText(string.format("Hold %s to track it too", self:GetMapClickModifierLabel()))
            controls.hint:SetShown(self.db.settings.mapClickCaptureEnabled)
        end
    else
        controls.container:Hide()
    end
end

function O:EnsureWorldMapButtons()
    if self._worldMapControls or not WorldMapFrame then
        return
    end

    local container = CreateFrame("Frame", nil, WorldMapFrame)
    container:SetSize(250, 52)
    container:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -34, -32)

    local saveButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    saveButton:SetSize(118, 22)
    saveButton:SetPoint("LEFT", 0, 0)
    saveButton:SetText("Save Blizzard WP")
    saveButton:SetScript("OnClick", function()
        self:CaptureCurrentUserWaypoint(false)
    end)
    StyleButton(saveButton)

    local questButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    questButton:SetSize(118, 22)
    questButton:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)
    questButton:SetText("Save Quest WP")
    questButton:SetScript("OnClick", function()
        self:CaptureCurrentSuperTrackedQuest(self.db.settings.autoTrackImportedQuest)
    end)
    StyleButton(questButton)

    local mapButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    mapButton:SetSize(118, 22)
    mapButton:SetPoint("TOPLEFT", saveButton, "BOTTOMLEFT", 0, -4)
    mapButton:SetText("Save Map Cursor")
    mapButton:SetScript("OnClick", function()
        -- The configured modifier is what makes the new waypoint the tracked
        -- one; a plain click just stores it. This is the only remaining use of
        -- mapClickCaptureModifier now that the canvas right-click hook is gone.
        self:CaptureWaypointFromWorldMapCursor(self:IsConfiguredMapClickModifierDown())
    end)
    StyleButton(mapButton)

    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", mapButton, "RIGHT", 8, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(string.format("Hold %s to track it too", self:GetMapClickModifierLabel()))

    self._worldMapControls = {
        container = container,
        saveButton = saveButton,
        questButton = questButton,
        mapButton = mapButton,
        hint = hint,
    }

    self:RefreshWorldMapButtons()
end

function O:EnsureWorldMapCaptureHook()
    if self._worldMapCaptureHooked or not WorldMapFrame then
        return
    end

    -- DISABLED (2026-07-12): hooking the world-map canvas's OnMouseUp to capture
    -- a waypoint on right-click ALSO swallowed Blizzard's right-click-to-zoom-out
    -- — any OnMouseUp handler on the canvas consumes the right-click, so the map
    -- could no longer be backed out of a zone. The "Save Map Cursor" button on
    -- the map captures the same cursor position on click without touching the
    -- canvas's mouse handling, so we rely on that instead.
    self._worldMapCaptureHooked = true
end

function O:EvaluateAutomaticCaptures(reason, questID)
    if not self.db or not self.Services or not self.Services.WaypointService then
        return
    end

    if self._suspendUserWaypointCapture then
        return
    end

    if reason == "USER_WAYPOINT_UPDATED" and self.db.settings.autoCaptureUserWaypoint then
        self.Services.WaypointService:CaptureActiveUserWaypoint({
            autoTrack = false,
            source = "Blizzard",
            tags = { "blizzard", "user-waypoint" },
        })
        if self.UI.MainFrame then
            self.UI.MainFrame:RefreshWaypointsPanel()
        end
        return
    end

    if (reason == "SUPER_TRACKING_CHANGED" or reason == "QUEST_ACCEPTED") and self.db.settings.autoImportSuperTrackedQuest then
        if reason ~= "QUEST_ACCEPTED" or self.db.settings.captureQuestOnAccept then
            self.Services.WaypointService:CaptureSuperTrackedQuest({
                autoTrack = self.db.settings.autoTrackImportedQuest,
                source = reason == "QUEST_ACCEPTED" and "QuestAccept" or "Quest",
                tags = { "quest", "supertracked" },
                questID = questID,
            })
            if self.UI.MainFrame then
                self.UI.MainFrame:RefreshWaypointsPanel()
            end
        end
    end
end

-- Arrival handling for a plain tracked waypoint.
--
-- Tours:HandleArrival only fires for the *active tour's current stop* with
-- auto-advance enabled. A waypoint tracked on its own -- which is what every
-- capture button, every bridge push and every /way produces -- had nothing
-- watching its distance at all, so arriving simply left the arrow reading
-- "0 yd" with no way to dismiss it.
--
-- Returns true when an arrival was handled, so the caller can tell this apart
-- from "still travelling".
function O:EvaluateTrackedArrival(waypoint, distance)
    if type(waypoint) ~= "table" or not self.db then
        return false
    end

    local threshold = math.max(5, tonumber(self.db.settings.arrivalDistanceYards) or 25)
    if not distance then
        -- Unmeasurable is not "far away": leave the latch alone.
        return false
    end
    if distance > threshold then
        -- Genuinely out of range, so leaving and returning announces again.
        self._arrivedWaypointID = nil
        return false
    end

    -- Already handled this arrival; don't re-fire every HUD tick.
    if tonumber(self._arrivedWaypointID) == tonumber(waypoint.id) then
        return false
    end

    -- If the tour module owns this stop, let it drive: otherwise arriving on a
    -- tour would both advance and untrack.
    local tours = self.Modules and self.Modules.Tours
    if tours and self.db.settings.autoAdvanceTours then
        local activeWaypoint = tours.GetActiveWaypoint and tours:GetActiveWaypoint()
        if activeWaypoint and tonumber(activeWaypoint.id) == tonumber(waypoint.id) then
            return false
        end
    end

    self._arrivedWaypointID = waypoint.id

    local title = waypoint.title or "waypoint"
    if self.db.settings.announceArrival then
        self:Print(string.format("Arrived at |cff4fb8e8%s|r.", title))
        if self.UI.MainFrame and self.UI.MainFrame.Toast then
            self.UI.MainFrame:Toast("Arrived", title)
        end
    end

    if self.db.settings.untrackOnArrival and self.Services and self.Services.WaypointService then
        -- Clears the arrow and the provider's waypoint, which is what "I got
        -- there, stop pointing at it" means.
        self.Services.WaypointService:UntrackWaypoint()
    end

    return true
end

-- Bring up both world-map layers. Called at login and again when
-- Blizzard_WorldMap loads on demand: WorldMapFrame does not exist until that
-- addon is in, and either path can be the one that wins. Both modules guard
-- on their own `hooked` flag and return early without a WorldMapFrame, so
-- calling this twice is a no-op rather than a double set of hooks.
function O:InitializeWorldMapVisuals()
    for _, moduleName in ipairs({ "RouteOverlay", "MapPins" }) do
        local module = self.UI and self.UI[moduleName]
        if module and type(module.Initialize) == "function" then
            module:Initialize()
        end
    end
end

-- Replay `db.trackedWaypointID` into whichever provider is active this
-- session. Returns false plus a reason when there is nothing to restore, so a
-- caller (and the tests) can tell "nothing tracked" apart from "restore
-- failed". Silent by design: a stale ID after the waypoint was deleted is
-- ordinary, not an error worth printing at every login.
function O:RestorePersistedTracking()
    local service = self.Services and self.Services.WaypointService
    if not service or type(service.RestoreTrackedWaypoint) ~= "function" then
        return false, "Waypoint service unavailable."
    end
    if not self.db or self.db.trackedWaypointID == nil then
        return false, "No persisted waypoint is tracked."
    end

    -- On success `detail` is the provider that took it, or the reason no
    -- provider did -- the waypoint stays tracked internally either way, so
    -- don't phrase a provider refusal as if it were the provider's name.
    local restored, detail = service:RestoreTrackedWaypoint()
    self:Debug(restored
        and ("Restored tracked waypoint (provider: " .. tostring(detail) .. ")")
        or ("Tracked waypoint not restored: " .. tostring(detail)))
    return restored, detail
end

-- Parse TomTom's /way grammar, which is what wowhead, guides and other players
-- paste:
--   42.2 48.8 [title]
--   42.2, 48.8 [title]
--   #2339 42.2 48.8 [title]
--
-- Coordinates here are always percent. The service's normalizer reads values
-- of 1 or less as fractions, so "/way 0.5 0.8" handed to it raw would land
-- mid-map instead of in the corner; the division happens here instead.
--
-- Returns nil, nil when the message is not coordinate-shaped at all, so
-- subcommands such as "next" still dispatch. Returns nil, err when it looks
-- like coordinates but cannot be used.
function O:ParseWayCommand(message)
    local text = self:Trim(message)
    if not text:match("^[#%d]") then
        return nil, nil
    end

    local mapID
    local mapToken, afterMap = text:match("^#(%d+)%s*(.*)$")
    if mapToken then
        mapID = tonumber(mapToken)
        text = afterMap
    end

    local xText, yText, title = text:match("^(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)%s*(.-)$")
    local x, y = tonumber(xText), tonumber(yText)
    if not x or not y then
        return nil, "Usage: /way [#mapID] x y [title] -- e.g. /way 42.2 48.8"
    end
    if x > 100 or y > 100 then
        return nil, "/way coordinates are percent, between 0 and 100."
    end

    if not mapID then
        mapID = self:GetBestMapForPlayer()
        if not mapID then
            return nil, "Can't tell which map you are on. Use /way #mapID x y."
        end
    end

    return {
        mapID = mapID,
        x = x / 100,
        y = y / 100,
        coords = xText .. ", " .. yText,
        title = title ~= "" and title or nil,
    }
end

-- Save a parsed /way target and point the arrow at it. Tracking is done here
-- rather than through AddWaypoint's autoTrack because autoTrack drops the
-- provider's answer, and a map Blizzard refuses a pin on would then fail just
-- as silently as /way did before it parsed anything.
function O:AddWaypointFromWay(way)
    local service = self.Services.WaypointService

    local title = way.title
    if not title then
        local mapName
        if C_Map and C_Map.GetMapInfo then
            local info = C_Map.GetMapInfo(way.mapID)
            mapName = info and info.name
        end
        title = mapName and (mapName .. " " .. way.coords) or way.coords
    end

    local waypointID, duplicateOrError = service:AddWaypoint({
        title = title,
        mapID = way.mapID,
        x = way.x,
        y = way.y,
        source = "Way",
        tags = { "manual", "way" },
    })
    if not waypointID then
        self:Print(tostring(duplicateOrError or "Could not add that waypoint."))
        return nil
    end

    -- A duplicate keeps the title it was first saved under.
    local waypoint = service:GetWaypointByID(waypointID)
    local savedTitle = waypoint and waypoint.title or title

    local providerID, providerDetail = service:TrackWaypoint(waypointID)
    if providerID then
        self:Print(string.format("%s |cff4fb8e8%s|r.",
            duplicateOrError and "Tracking saved waypoint" or "Waypoint set:", savedTitle))
    else
        self:Print(string.format("Saved |cff4fb8e8%s|r, but no arrow: %s",
            savedTitle, tostring(providerDetail or "no waypoint provider is available.")))
    end
    return waypointID
end

function O:RegisterSlashCommands()
    SLASH_FABLEDUI_ODYSSEY1 = "/odyssey"
    SLASH_FABLEDUI_ODYSSEY2 = "/ariadne"
    SLASH_FABLEDUI_ODYSSEY3 = "/way"

    SlashCmdList["FABLEDUI_ODYSSEY"] = function(message)
        message = self:Trim(message)

        -- Coordinates before subcommands. Without this, "/way 42.2 48.8" read
        -- "42.2" as an unknown subcommand and fell through to toggling the
        -- window, so no waypoint was ever made.
        local way, wayError = self:ParseWayCommand(message)
        if way then
            self:AddWaypointFromWay(way)
            return
        elseif wayError then
            self:Print(wayError)
            return
        end

        local command, rest = message:match("^(%S+)%s*(.-)$")
        command = string.lower(command or "")

        if command == "start" then
            self.Modules.Tours:StartTourByName(rest)
        elseif command == "next" then
            self.Modules.Tours:AdvanceTour(1)
        elseif command == "prev" then
            self.Modules.Tours:AdvanceTour(-1)
        elseif command == "add" then
            self.Modules.Tours:AddCurrentPositionToActiveTour(rest)
        elseif command == "here" then
            local waypointID, err = self.Services.WaypointService:CapturePlayerPosition(rest, {
                source = "Manual",
                tags = { "manual", "here" },
                autoTrack = false,
            })
            if not waypointID and err then
                self:Print(err)
            end
        elseif command == "save" or command == "savewp" then
            self:CaptureCurrentUserWaypoint(false)
        elseif command == "savequest" or command == "quest" then
            self:CaptureCurrentSuperTrackedQuest(self.db.settings.autoTrackImportedQuest)
        elseif command == "clear" then
            self.Services.WaypointService:ClearAllWaypoints()
        elseif command == "settings" or command == "config" or command == "options" then
            if self.Settings and self.Settings.Open then
                self.Settings:Open()
            end
        elseif command == "audit" then
            self.Modules.Audit:Run(true)
            if self.UI.MainFrame then
                self.UI.MainFrame:RefreshAuditPanel()
            end
        else
            self.UI.MainFrame:Toggle()
        end
    end
end

function O:Initialize()
    if self._initialized then
        return
    end
    self._initialized = true

    SafeCall("ResolveStorage")
    SafeCall("RegisterSlashCommands")
    SafeCall("RegisterSettings")
    SafeCall("InitializeHUD")
    SafeCall("InitializeMainFrame")
    SafeCall("EnsureWorldMapButtons")
    SafeCall("EnsureWorldMapCaptureHook")

    self:InitializeWorldMapVisuals()
    if self.Services and self.Services.RouteShare and self.Services.RouteShare.Initialize then
        self.Services.RouteShare:Initialize()
    end

    eventFrame:RegisterEvent("USER_WAYPOINT_UPDATED")
    eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("ADDON_LOADED")

    -- `trackedWaypointID` survives in saved variables but the provider's own
    -- arrow does not: C_Map/TomTom start each session with nothing set. Replay
    -- the persisted selection so the HUD and the provider agree after a
    -- /reload instead of the HUD pointing at a waypoint no provider knows.
    self:RestorePersistedTracking()

    if self.db.settings.autoAuditOnLogin then
        self.Modules.Audit:Run(false)
    end

    self:Print("Online. /odyssey opens the panel.")
end

function O:HandleEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        -- PLAYER_LOGIN carries no payload; forwarding `...` here only tripped
        -- the redundant-parameter diagnostic against Initialize()'s signature.
        self:Initialize()
    elseif event == "USER_WAYPOINT_UPDATED" then
        self:EvaluateAutomaticCaptures(event)
    elseif event == "SUPER_TRACKING_CHANGED" then
        self:EvaluateAutomaticCaptures(event)
    elseif event == "QUEST_ACCEPTED" then
        local questID = ...
        self:EvaluateAutomaticCaptures(event, questID)
    elseif event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == "Blizzard_WorldMap" then
            self:EnsureWorldMapButtons()
            self:EnsureWorldMapCaptureHook()
            self:InitializeWorldMapVisuals()
        end
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if O and O.HandleEvent then
        O:HandleEvent(event, ...)
    end
end)
