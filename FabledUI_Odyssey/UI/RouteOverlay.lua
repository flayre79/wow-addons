local addonName, ns = ...
local O = ns.Odyssey

-- Visual route-line renderer for Odyssey tours.
-- Ported from RoutePlanner/WorldMap.lua (line pool + DrawWorldMapRoutes,
-- lines 7-66 and 639-751). Adapted to Odyssey's data model: it draws the
-- active tour's waypoint list against the current world map canvas.

local Overlay = {}
O.UI.RouteOverlay = Overlay

local linePool = {}
local activeLines = {}
local lineContainer = nil
local hooked = false
local lastDrawnMapID = nil

local DEFAULT_COLOR = { 0.30, 0.78, 1.0, 0.85 }
local DEFAULT_THICKNESS = 2

---------------------------------------------------------------------------
-- Line Pool (mirrors RoutePlanner/WorldMap.lua:31-66)
---------------------------------------------------------------------------
local function AcquireLine()
    if not lineContainer then
        return nil
    end
    local line = next(linePool)
    if line then
        linePool[line] = nil
        line:Show()
        return line
    end
    local newLine = lineContainer:CreateLine(nil, "OVERLAY")
    newLine:SetThickness(DEFAULT_THICKNESS)
    return newLine
end

local function ReleaseLine(line)
    if not line then
        return
    end
    line:Hide()
    line:ClearAllPoints()
    linePool[line] = true
end

local function ReleaseAllLines()
    for i = #activeLines, 1, -1 do
        ReleaseLine(activeLines[i])
        activeLines[i] = nil
    end
end

local function GetLine(index)
    if activeLines[index] then
        return activeLines[index]
    end
    local line = AcquireLine()
    activeLines[index] = line
    return line
end

---------------------------------------------------------------------------
-- Canvas helper
---------------------------------------------------------------------------
local function GetMapCanvas()
    if not WorldMapFrame then
        return nil
    end
    if WorldMapFrame.GetCanvas then
        return WorldMapFrame:GetCanvas()
    end
    return WorldMapFrame.ScrollContainer or WorldMapFrame
end

local function GetActiveMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        return WorldMapFrame:GetMapID()
    end
    return nil
end

---------------------------------------------------------------------------
-- Active-tour resolution
---------------------------------------------------------------------------
local function GetActiveTourWaypoints(forMapID)
    if not O.Modules or not O.Modules.Tours or not O.Services or not O.Services.WaypointService then
        return nil
    end

    local tour = O.Modules.Tours:GetActiveTour()
    if not tour or type(tour.waypointIDs) ~= "table" or #tour.waypointIDs < 2 then
        return nil
    end

    local svc = O.Services.WaypointService
    local list = {}
    for _, waypointID in ipairs(tour.waypointIDs) do
        local wp = svc:GetWaypointByID(waypointID)
        if wp and (not forMapID or tonumber(wp.mapID) == tonumber(forMapID)) then
            list[#list + 1] = wp
        end
    end

    if #list < 2 then
        return nil
    end
    return list, tour
end

---------------------------------------------------------------------------
-- Route metadata (color/thickness/loop)
---------------------------------------------------------------------------
function Overlay:GetRouteColor()
    local settings = O.db and O.db.settings or nil
    if type(settings) == "table" and type(settings.routeLineColor) == "table" then
        local c = settings.routeLineColor
        return { c[1] or DEFAULT_COLOR[1], c[2] or DEFAULT_COLOR[2], c[3] or DEFAULT_COLOR[3], c[4] or DEFAULT_COLOR[4] }
    end
    return { DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3], DEFAULT_COLOR[4] }
end

function Overlay:GetRouteThickness()
    local settings = O.db and O.db.settings or nil
    -- Bind the converted value instead of calling tonumber twice: the second
    -- call returns `number?` again as far as the analyzer is concerned.
    local thickness = settings and tonumber(settings.routeLineThickness)
    if thickness then
        return math.max(1, math.floor(thickness))
    end
    return DEFAULT_THICKNESS
end

function Overlay:IsLoop()
    local tour = O.Modules and O.Modules.Tours and O.Modules.Tours:GetActiveTour()
    if tour and tour.loop ~= nil then
        return tour.loop and true or false
    end
    return false
end

---------------------------------------------------------------------------
-- Render (mirrors RoutePlanner/WorldMap.lua:639-751)
---------------------------------------------------------------------------
function Overlay:Render()
    if not lineContainer then
        return
    end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        ReleaseAllLines()
        lineContainer:Hide()
        lastDrawnMapID = nil
        return
    end

    local canvas = GetMapCanvas()
    if not canvas then
        return
    end

    local mapID = GetActiveMapID()
    if not mapID then
        ReleaseAllLines()
        lineContainer:Hide()
        return
    end

    local mapChanged = lastDrawnMapID ~= mapID
    if mapChanged then
        lastDrawnMapID = mapID
        ReleaseAllLines()
        lineContainer:SetParent(canvas)
        lineContainer:ClearAllPoints()
        lineContainer:SetAllPoints(canvas)
        lineContainer:SetFrameStrata("FULLSCREEN")
        lineContainer:SetFrameLevel(2000)
        lineContainer:Show()
    else
        ReleaseAllLines()
    end

    local canvasW, canvasH = canvas:GetSize()
    if not canvasW or canvasW == 0 then
        return
    end
    lineContainer:SetSize(canvasW, canvasH)

    local waypoints, tour = GetActiveTourWaypoints(mapID)
    if not waypoints then
        lineContainer:Show()
        return
    end

    local routeColor = self:GetRouteColor()
    local thickness = self:GetRouteThickness()
    local loop = (tour and tour.loop) and true or false
    local numWP = #waypoints
    local segments = numWP - 1
    if loop then segments = numWP end

    local lineIndex = 0
    for seg = 1, segments do
        local p1 = waypoints[seg]
        local nextIdx = seg + 1
        if loop and seg == numWP then
            nextIdx = 1
        end
        local p2 = waypoints[nextIdx]

        if p1 and p2 then
            lineIndex = lineIndex + 1
            local line = GetLine(lineIndex)
            if line then
                local lineColor = (type(p1.color) == "table" and p1.color)
                               or (type(p2.color) == "table" and p2.color)
                               or routeColor

                line:ClearAllPoints()
                line:SetStartPoint("TOPLEFT", canvas, p1.x * canvasW, -p1.y * canvasH)
                line:SetEndPoint("TOPLEFT", canvas, p2.x * canvasW, -p2.y * canvasH)
                line:SetColorTexture(
                    lineColor[1] or 1,
                    lineColor[2] or 1,
                    lineColor[3] or 1,
                    lineColor[4] or 1
                )
                line:SetThickness(thickness)
                line:SetDrawLayer("OVERLAY", 7)
                line:Show()
            end
        end
    end

    lineContainer:Show()
end

function Overlay:Refresh()
    if hooked and WorldMapFrame and WorldMapFrame:IsShown() then
        self:Render()
    end
end

function Overlay:Clear()
    ReleaseAllLines()
    if lineContainer then
        lineContainer:Hide()
    end
    lastDrawnMapID = nil
end

---------------------------------------------------------------------------
-- Initialization / hooks
---------------------------------------------------------------------------
function Overlay:Initialize()
    if hooked then
        return
    end
    if not WorldMapFrame then
        return
    end

    if not lineContainer then
        lineContainer = CreateFrame("Frame", "FabledUIOdysseyRouteOverlay", UIParent)
        lineContainer:Hide()
    end

    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function()
            Overlay:Render()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            Overlay:Clear()
        end)
    end

    -- Hook SetMapID (the canonical post-transition signal) instead of
    -- OnMapChanged. OnMapChanged is the event callback dispatched by the
    -- map system but doesn't fire reliably across every transition path
    -- (zone scroll, in-instance map switch, etc); SetMapID is the actual
    -- mutator. Belt-and-suspenders: hook both when available so we never
    -- miss a refresh.
    if hooksecurefunc then
        if WorldMapFrame.SetMapID then
            hooksecurefunc(WorldMapFrame, "SetMapID", function()
                Overlay:Render()
            end)
        end
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                Overlay:Render()
            end)
        end
    end

    hooked = true
end

function Overlay:IsHooked()
    return hooked
end
