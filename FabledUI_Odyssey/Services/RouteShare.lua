local addonName, ns = ...
local O = ns.Odyssey

-- Route export-string format and chat-link share/receive popup.
-- Version 3 keeps each waypoint's map ID, title, and source so cross-zone
-- tours round-trip without being flattened onto the first map. Version 2 and
-- the older ODYSSEY/ARIADNE waypoint formats remain import-only.
--
-- Format:
--   FabUIODY!3!<name>!<r,g,b,a>!<loop>!<mapID,x,y,title,source>;...
--
-- The chat-link receive flow follows RoutePlanner/Core.lua:1010-1206:
-- chunked addon messages are reassembled per sender, then the recipient
-- sees a popup with sender name + route preview + Import / Cancel buttons.

local Share = {}
O.Services.RouteShare = Share

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

local PREFIX = "FabUIODY"
local FORMAT_VERSION = 3
local CHUNK_SIZE = 220
local MAX_ROUTE_BYTES = 30000
local MAX_ROUTE_WAYPOINTS = 500
local MAX_CHUNKS = 140
local MAX_INCOMING_BUFFERS = 20
local MAX_RECEIVED_ROUTES = 20
local CHAT_EVENTS = {
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local incomingRoutes = {}
local receivedRoutes = {}
local hooked = false
local popupFrame = nil

local function CountEntries(collection)
    local count = 0
    for _ in pairs(collection) do
        count = count + 1
    end
    return count
end

local function EvictOldest(collection)
    local oldestKey, oldestTime
    for key, value in pairs(collection) do
        local timestamp = type(value) == "table" and tonumber(value.timestamp) or 0
        if oldestTime == nil or timestamp < oldestTime then
            oldestKey, oldestTime = key, timestamp
        end
    end
    if oldestKey ~= nil then
        collection[oldestKey] = nil
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function SafeNumber(value, fallback)
    return tonumber(value) or fallback
end

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function EncodeField(value)
    return (tostring(value or "")
        :gsub("\r?\n", " ")
        :gsub("([^%w%-_%.~])", function(char)
            return string.format("%%%02X", string.byte(char))
        end))
end

local function DecodeField(value)
    return (tostring(value or "")
        :gsub("%+", " ")
        :gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16) or 32)
        end))
end

local function NormalizeName(name)
    local trimmed = O:Trim(name or "")
    if trimmed == "" then
        trimmed = "Route"
    end
    return trimmed:sub(1, 80)
end

local function GetActiveTourPayload(routeID)
    if not O.Modules or not O.Modules.Tours or not O.Services or not O.Services.WaypointService then
        return nil
    end

    local svc = O.Services.WaypointService
    local tour = nil
    if routeID then
        tour = O.Modules.Tours:GetTourByID(routeID)
    end
    if not tour then
        tour = O.Modules.Tours:GetActiveTour()
    end
    if not tour or type(tour.waypointIDs) ~= "table" or #tour.waypointIDs < 2 then
        return nil
    end

    local waypoints = {}
    local mapID = nil
    for _, waypointID in ipairs(tour.waypointIDs) do
        local wp = svc:GetWaypointByID(waypointID)
        if wp then
            local x = tonumber(wp.x)
            local y = tonumber(wp.y)
            local wpMap = tonumber(wp.mapID) or 0
            if wpMap > 0 and x and y then
                if not mapID then
                    mapID = wpMap
                end
                waypoints[#waypoints + 1] = {
                    x = x,
                    y = y,
                    mapID = wpMap,
                    title = wp.title,
                    source = wp.source,
                }
            end
        end
    end

    if #waypoints < 2 or not mapID then
        return nil
    end

    return {
        name = NormalizeName(tour.name),
        mapID = mapID,
        loop = tour.loop and true or false,
        waypoints = waypoints,
        color = (type(tour.color) == "table" and tour.color) or { 0.30, 0.78, 1.0, 0.85 },
    }
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------
function Share:ExportPayload(payload)
    if type(payload) ~= "table" or type(payload.waypoints) ~= "table" or #payload.waypoints < 2 then
        return nil, "Route must have at least 2 waypoints."
    end
    if #payload.waypoints > MAX_ROUTE_WAYPOINTS then
        return nil, "Route exceeds the waypoint limit."
    end

    local color = payload.color or { 0.30, 0.78, 1.0, 0.85 }
    for index = 1, 4 do
        local component = tonumber(color[index])
        if not IsFiniteNumber(component) or component < 0 or component > 1 then
            return nil, "Route color is invalid."
        end
    end
    local parts = {
        PREFIX,
        tostring(FORMAT_VERSION),
        EncodeField(NormalizeName(payload.name)),
        string.format("%.2f,%.2f,%.2f,%.2f", color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0.85),
        payload.loop and "1" or "0",
    }

    local wpStrings = {}
    for index, wp in ipairs(payload.waypoints) do
        local mapID = tonumber(wp.mapID)
        local x, y, err = O.Services.WaypointService:NormalizeCoordinates(wp.x, wp.y)
        if not mapID or mapID <= 0 or not x then
            return nil, "Route waypoint " .. index .. ": " .. tostring(err or "invalid map ID")
        end
        wpStrings[#wpStrings + 1] = string.format(
            "%d,%.5f,%.5f,%s,%s",
            math.floor(mapID), x, y, EncodeField(wp.title or ("Waypoint " .. index)), EncodeField(wp.source or "Import")
        )
    end
    parts[#parts + 1] = table.concat(wpStrings, ";")

    local exported = table.concat(parts, "!")
    if #exported > MAX_ROUTE_BYTES then
        return nil, "Route export exceeds the size limit."
    end
    return exported
end

function Share:ExportTour(tourID)
    local payload = GetActiveTourPayload(tourID)
    if not payload then
        return nil, "No tour available to export."
    end
    return self:ExportPayload(payload)
end

---------------------------------------------------------------------------
-- Parse
---------------------------------------------------------------------------
function Share:ParseExportString(str)
    if type(str) ~= "string" or str == "" then
        return nil, "Empty import string."
    end
    if #str > MAX_ROUTE_BYTES then
        return nil, "Route import exceeds the size limit."
    end

    local parts = {}
    for part in str:gmatch("[^!]+") do
        parts[#parts + 1] = part
    end

    if #parts < 6 then
        return nil, "Invalid format: not enough fields."
    end
    if parts[1] ~= PREFIX then
        return nil, "Invalid format: missing " .. PREFIX .. " prefix."
    end

    local formatVersion = tonumber(parts[2])
    if formatVersion ~= 2 and formatVersion ~= FORMAT_VERSION then
        return nil, "Unsupported route format version: " .. tostring(formatVersion)
    end

    local name, mapID, colorStr, loopStr, waypointsStr
    if formatVersion == 2 then
        if #parts < 7 then
            return nil, "Invalid version 2 route."
        end
        name = NormalizeName(parts[3])
        mapID = tonumber(parts[4])
        colorStr, loopStr, waypointsStr = parts[5], parts[6], parts[7]
        if not mapID or mapID <= 0 then
            return nil, "Invalid mapID."
        end
    else
        name = NormalizeName(DecodeField(parts[3]))
        colorStr, loopStr, waypointsStr = parts[4], parts[5], parts[6]
    end

    local cr, cg, cb, ca = colorStr:match("^([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]+)$")
    cr, cg, cb, ca = tonumber(cr), tonumber(cg), tonumber(cb), tonumber(ca)
    if not (IsFiniteNumber(cr) and IsFiniteNumber(cg) and IsFiniteNumber(cb) and IsFiniteNumber(ca))
        or cr < 0 or cr > 1 or cg < 0 or cg > 1 or cb < 0 or cb > 1 or ca < 0 or ca > 1
    then
        return nil, "Invalid color data."
    end

    local loop = loopStr == "1"

    local waypoints = {}
    for wp in waypointsStr:gmatch("[^;]+") do
        local wpMap, x, y, title, source
        if formatVersion == 2 then
            x, y = wp:match("^([%d%.]+),([%d%.]+)$")
            wpMap = mapID
        else
            wpMap, x, y, title, source = wp:match("^(%d+),([%d%.]+),([%d%.]+),([^,]*),?(.*)$")
            wpMap = tonumber(wpMap)
        end
        local nx, ny, coordinateError = O.Services.WaypointService:NormalizeCoordinates(x, y)
        if not wpMap or wpMap <= 0 or not nx then
            return nil, coordinateError or "Route contains an invalid waypoint."
        end
        waypoints[#waypoints + 1] = {
            x = nx,
            y = ny,
            mapID = math.floor(wpMap),
            title = formatVersion == 3 and DecodeField(title) or nil,
            source = formatVersion == 3 and DecodeField(source) or nil,
        }
        if #waypoints > MAX_ROUTE_WAYPOINTS then
            return nil, "Route exceeds the waypoint limit."
        end
    end

    if #waypoints < 2 then
        return nil, "Route must have at least 2 waypoints."
    end

    return {
        name = name,
        mapID = mapID or waypoints[1].mapID,
        formatVersion = formatVersion,
        color = { cr, cg, cb, ca },
        loop = loop,
        waypoints = waypoints,
    }
end

---------------------------------------------------------------------------
-- Import (creates a tour with imported waypoints)
---------------------------------------------------------------------------
function Share:ImportFromString(str, options)
    if type(str) == "string" and (str:match("^ODYSSEY:%d+|") or str:match("^ARIADNE:%d+|")) then
        if not O.Services or not O.Services.WaypointService then
            return nil, "Odyssey services unavailable."
        end
        local count, legacyError = O.Services.WaypointService:ImportWaypoints(str, options)
        if not count or count == 0 then
            return nil, legacyError or "Legacy route contained no waypoints."
        end
        return count, { formatVersion = 1, legacy = true, waypointCount = count }
    end

    local parsed, err = self:ParseExportString(str)
    if not parsed then
        return nil, err
    end

    if not O.Services or not O.Services.WaypointService or not O.Modules or not O.Modules.Tours then
        return nil, "Odyssey services unavailable."
    end

    local svc = O.Services.WaypointService
    local pending = {}
    for index, wp in ipairs(parsed.waypoints) do
        pending[#pending + 1] = {
            title = O:Trim(wp.title) ~= "" and wp.title or string.format("%s %d", parsed.name, index),
            mapID = wp.mapID,
            x = wp.x,
            y = wp.y,
            source = O:Trim(wp.source) ~= "" and wp.source or ((options and options.source) or "Import"),
            tags = { "imported", "share" },
            autoTrack = false,
            allowDuplicate = true,
        }
    end

    local addedIDs
    addedIDs, err = svc:AddWaypointsAtomic(pending)
    if not addedIDs or #addedIDs < 2 then
        return nil, err or "Could not import route waypoints."
    end

    local tourName = parsed.name
    if options and options.sender and options.sender ~= "" then
        tourName = string.format("%s (from %s)", parsed.name, options.sender)
    end

    local tourID
    tourID, err = O.Modules.Tours:CreateTour(tourName, addedIDs)
    if not tourID then
        for _, waypointID in ipairs(addedIDs) do
            svc:RemoveWaypoint(waypointID)
        end
        return nil, err or "Could not create the imported tour."
    end
    if tourID then
        local tour = O.Modules.Tours:GetTourByID(tourID)
        if tour then
            tour.loop = parsed.loop and true or false
            tour.color = parsed.color
            tour.updatedAt = time()
        end
        if O.MarkDirty then
            O:MarkDirty()
        end
    end

    if O.UI and O.UI.MainFrame and O.UI.MainFrame.RefreshAll then
        O.UI.MainFrame:RefreshAll()
    end

    return tourID, parsed
end

---------------------------------------------------------------------------
-- Receive popup
---------------------------------------------------------------------------
local function BuildPreviewText(parsed, sender)
    if not parsed then
        return ""
    end

    local zoneName
    if C_Map and C_Map.GetMapInfo and parsed.mapID then
        local info = C_Map.GetMapInfo(parsed.mapID)
        if info and info.name then
            zoneName = info.name
        end
    end
    zoneName = zoneName or ("MapID " .. tostring(parsed.mapID or "?"))

    return string.format(
        "|cffFFFFFF%s|r\n|cffAAAAAA%s - %d waypoints|r",
        parsed.name or "Unknown",
        zoneName,
        parsed.waypoints and #parsed.waypoints or 0
    )
end

function Share:ShowReceivedPopup(sender, exportString)
    local parsed = select(1, self:ParseExportString(exportString))
    local previewText = BuildPreviewText(parsed, sender)

    if popupFrame then
        popupFrame.exportString = exportString
        popupFrame.sender = sender
        popupFrame.senderText:SetText("|cffAAAAAASent by:|r |cff00ccff" .. (sender or "?") .. "|r")
        popupFrame.infoText:SetText(previewText)
        popupFrame:Show()
        popupFrame:Raise()
        return
    end

    local f = CreateFrame("Frame", "FabledUIOdysseyReceivedRouteFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(360, 190)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
    f.title:SetText("Odyssey Route Received")

    f.senderText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.senderText:SetPoint("TOPLEFT", f.InsetBg or f, "TOPLEFT", 15, -15)
    f.senderText:SetText("|cffAAAAAASent by:|r |cff00ccff" .. (sender or "?") .. "|r")

    f.infoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.infoText:SetPoint("TOPLEFT", f.senderText, "BOTTOMLEFT", 0, -10)
    f.infoText:SetJustifyH("LEFT")
    f.infoText:SetText(previewText)

    f.exportString = exportString
    f.sender = sender

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 26)
    importBtn:SetPoint("BOTTOMLEFT", f.InsetBg or f, "BOTTOMLEFT", 15, 12)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local tourID, parsedOrErr = Share:ImportFromString(f.exportString, { sender = f.sender, source = f.sender or "Share" })
        if tourID then
            O:Print(string.format("|cff00ff00Route '%s' imported from %s.|r",
                (type(parsedOrErr) == "table" and parsedOrErr.name) or "Route", tostring(f.sender)))
            f:Hide()
        else
            O:Print("|cffFF8800Import failed:|r " .. tostring(parsedOrErr or "unknown error"))
        end
    end)
    StyleButton(importBtn)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 26)
    cancelBtn:SetPoint("BOTTOMRIGHT", f.InsetBg or f, "BOTTOMRIGHT", -15, 12)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        f:Hide()
    end)
    StyleButton(cancelBtn)

    popupFrame = f
    f:Show()
end

---------------------------------------------------------------------------
-- Chunked addon-message reassembly (mirrors RoutePlanner Core.lua:1010-1064)
---------------------------------------------------------------------------
function Share:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX then
        return
    end

    if type(message) ~= "string" or #message > 255 then
        return false
    end

    local msgID, chunkNum, totalChunks, data = message:match("^([%w%-]+):(%d+):(%d+):(.+)$")
    if not msgID then
        return false
    end
    chunkNum = tonumber(chunkNum)
    totalChunks = tonumber(totalChunks)
    if #msgID > 64 or not chunkNum or not totalChunks or chunkNum < 1 or totalChunks < 1
        or totalChunks > MAX_CHUNKS or chunkNum > totalChunks or #data > CHUNK_SIZE
    then
        return false
    end

    local cleanSender = (Ambiguate and Ambiguate(sender, "short")) or sender or "?"

    local bufferKey = (sender or "?") .. ":" .. msgID
    if not incomingRoutes[bufferKey] then
        while CountEntries(incomingRoutes) >= MAX_INCOMING_BUFFERS do
            EvictOldest(incomingRoutes)
        end
        incomingRoutes[bufferKey] = {
            chunks = {},
            totalChunks = totalChunks,
            received = 0,
            sender = cleanSender,
            timestamp = time(),
        }
        if C_Timer and C_Timer.After then
            C_Timer.After(60, function()
                incomingRoutes[bufferKey] = nil
            end)
        end
    end

    local buffer = incomingRoutes[bufferKey]
    if buffer.totalChunks ~= totalChunks then
        incomingRoutes[bufferKey] = nil
        return false
    end
    if not buffer.chunks[chunkNum] then
        buffer.chunks[chunkNum] = data
        buffer.received = buffer.received + 1
    end

    if buffer.received >= buffer.totalChunks then
        local pieces = {}
        for i = 1, buffer.totalChunks do
            pieces[i] = buffer.chunks[i] or ""
        end
        local exportString = table.concat(pieces)
        if #exportString > MAX_ROUTE_BYTES or not self:ParseExportString(exportString) then
            incomingRoutes[bufferKey] = nil
            return false
        end
        while CountEntries(receivedRoutes) >= MAX_RECEIVED_ROUTES and not receivedRoutes[cleanSender] do
            EvictOldest(receivedRoutes)
        end
        receivedRoutes[cleanSender] = {
            exportString = exportString,
            timestamp = time(),
        }
        incomingRoutes[bufferKey] = nil
        O:Print("|cff00ccff" .. cleanSender .. "|r has shared an Odyssey route. Click the link in chat to import it.")
    end
    return true
end

function Share:OnRouteLinkClicked(sender)
    local data = receivedRoutes[sender]
    if not data then
        O:Print("|cffFF8800No route data received from " .. tostring(sender) .. ".|r")
        return
    end
    self:ShowReceivedPopup(sender, data.exportString)
end

---------------------------------------------------------------------------
-- Send
---------------------------------------------------------------------------
function Share:SendRouteToChat(exportString, channel, channelLabel, routeName, target)
    if type(exportString) ~= "string" or exportString == "" then
        O:Print("|cffFF8800Cannot send: route export is empty.|r")
        return false, "Route export is empty."
    end
    if #exportString > MAX_ROUTE_BYTES then
        return false, "Route export exceeds the size limit."
    end
    local parsed, parseError = self:ParseExportString(exportString)
    if not parsed then
        return false, parseError
    end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        O:Print("|cffFF8800Cannot send: addon messaging unavailable.|r")
        return false, "Addon messaging unavailable."
    end

    channel = string.upper(O:Trim(channel or "PARTY"))
    local supportedChannels = {
        PARTY = true,
        RAID = true,
        GUILD = true,
        OFFICER = true,
        WHISPER = true,
        INSTANCE_CHAT = true,
    }
    if not supportedChannels[channel] then
        return false, "Unsupported addon-message channel: " .. tostring(channel)
    end
    if channel == "WHISPER" and O:Trim(target) == "" then
        return false, "A whisper target is required."
    end

    local msgID = time() .. "-" .. math.random(10000, 99999)
    local chunks = {}
    for i = 1, #exportString, CHUNK_SIZE do
        chunks[#chunks + 1] = exportString:sub(i, i + CHUNK_SIZE - 1)
    end
    local totalChunks = #chunks
    if totalChunks == 0 or totalChunks > MAX_CHUNKS then
        return false, "Route requires too many message chunks."
    end
    local interval = totalChunks > 15 and 0.1 or 0.05

    for i, chunk in ipairs(chunks) do
        local msg = msgID .. ":" .. i .. ":" .. totalChunks .. ":" .. chunk
        local outgoing = msg
        if C_Timer and C_Timer.After then
            C_Timer.After(interval * (i - 1), function()
                C_ChatInfo.SendAddonMessage(PREFIX, outgoing, channel, target)
            end)
        else
            C_ChatInfo.SendAddonMessage(PREFIX, outgoing, channel, target)
        end
    end

    -- Companion plain-text marker so other Odyssey users see a clickable link.
    if SendChatMessage and channel and routeName then
        SendChatMessage("{Odyssey:" .. NormalizeName(routeName) .. "}", channel, nil, target)
    end

    O:Print(string.format("|cff00ff00Route '%s' sent to %s.|r", tostring(routeName or "Route"), tostring(channelLabel or channel or "?")))
    return true, totalChunks
end

---------------------------------------------------------------------------
-- Init: register addon prefix, hook chat-link clicks, transform plain markers
---------------------------------------------------------------------------
local function ChatFilter(self, event, msg, sender, ...)
    local routeName = msg and msg:match("^{Odyssey:(.+)}$")
    if routeName then
        local cleanSender = (Ambiguate and Ambiguate(sender or "?", "short")) or sender or "?"
        local link = "|Hgarrmission:OdysseyRoute:" .. cleanSender ..
            "|h|cff00ccff[Odyssey: " .. routeName .. "]|r|h"
        return false, link, sender, ...
    end
    return false
end

function Share:Initialize()
    if hooked then
        return
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end

    local frame = CreateFrame("Frame", "FabledUIOdysseyShareEvents")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
        if event == "CHAT_MSG_ADDON" then
            Share:OnAddonMessage(prefix, message, channel, sender)
        end
    end)

    for _, chatEvent in ipairs(CHAT_EVENTS) do
        if ChatFrame_AddMessageEventFilter then
            ChatFrame_AddMessageEventFilter(chatEvent, ChatFilter)
        end
    end

    -- hooksecurefunc instead of wholesale-replacing SetItemRef. Replacing
    -- the global is taint-prone — any other addon (or Blizzard code) calling
    -- through their secure path inherits our insecure closure, which 12.0
    -- treats as fatal for secure-action item refs (spell/macro links etc).
    -- The hook just observes every click; our garrmission:OdysseyRoute:
    -- prefix is custom enough that Blizzard's own SetItemRef won't have any
    -- handler for it and the double-tap on legitimate refs is a no-op.
    hooksecurefunc("SetItemRef", function(link)
        if not link then return end
        local sender = link:match("^garrmission:OdysseyRoute:(.+)$")
        if sender then
            Share:OnRouteLinkClicked(sender)
        end
    end)

    hooked = true
end

function Share:GetPrefix()
    return PREFIX
end
