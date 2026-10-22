local addonName, ns = ...
local O = ns.Odyssey

local Tours = {}
O.Modules.Tours = Tours

local MAX_TOUR_WAYPOINTS = 500

local function RefreshRouteOverlay()
    if O.UI and O.UI.RouteOverlay and O.UI.RouteOverlay.Refresh then
        O.UI.RouteOverlay:Refresh()
    end
end

local function FindTourIndexByID(tourID)
    tourID = tonumber(tourID)
    if not tourID then
        return nil
    end
    for index, tour in ipairs(O.db.tours) do
        if tonumber(tour.id) == tourID then
            return index, tour
        end
    end
    return nil
end

function Tours:ListTours()
    return O.db.tours
end

function Tours:GetTourByID(tourID)
    local _, tour = FindTourIndexByID(tourID)
    return tour
end

function Tours:GetActiveTour()
    return self:GetTourByID(O.db.activeTourID)
end

function Tours:GetActiveWaypoint()
    local tour = self:GetActiveTour()
    if not tour then
        return nil
    end
    local index = math.max(1, math.min(#tour.waypointIDs, tonumber(O.db.activeTourIndex) or 1))
    local waypointID = tour.waypointIDs[index]
    return waypointID and O.Services.WaypointService:GetWaypointByID(waypointID) or nil
end

function Tours:CreateTour(name, waypointIDs)
    name = O:Trim(name)
    if name == "" then
        return nil
    end

    local copiedWaypointIDs = {}
    if type(waypointIDs) == "table" then
        if #waypointIDs > MAX_TOUR_WAYPOINTS then
            return nil, "Tour exceeds the waypoint limit."
        end
        for index, waypointID in ipairs(waypointIDs) do
            waypointID = tonumber(waypointID)
            if not waypointID or not O.Services.WaypointService:GetWaypointByID(waypointID) then
                return nil, "Tour waypoint " .. index .. " does not exist."
            end
            copiedWaypointIDs[#copiedWaypointIDs + 1] = waypointID
        end
    end

    local tourID = tonumber(O.db.nextIDs.tour) or 1
    O.db.nextIDs.tour = tourID + 1

    local tour = {
        id = tourID,
        name = name,
        waypointIDs = copiedWaypointIDs,
        createdAt = time(),
        updatedAt = time(),
    }

    O.db.tours[#O.db.tours + 1] = tour
    O.db.activeTourID = tourID
    O.db.activeTourIndex = 1
    O:MarkDirty()

    if O.UI.MainFrame then
        O.UI.MainFrame.selectedTourID = tourID
        O.UI.MainFrame:RefreshToursPanel()
    end
    RefreshRouteOverlay()
    return tourID
end

function Tours:StartTour(tourID)
    local tour = self:GetTourByID(tourID)
    if not tour then
        return false
    end

    O.db.activeTourID = tour.id
    O.db.activeTourIndex = 1
    O:MarkDirty()

    local firstWaypointID = tour.waypointIDs[1]
    if firstWaypointID then
        O.Services.WaypointService:TrackWaypoint(firstWaypointID)
    else
        O.Services.WaypointService:UntrackWaypoint()
    end

    if O.UI.MainFrame then
        O.UI.MainFrame.selectedTourID = tour.id
        O.UI.MainFrame:RefreshToursPanel()
    end
    RefreshRouteOverlay()
    return true
end

function Tours:StartTourByName(name)
    name = O:Trim(name)
    for _, tour in ipairs(O.db.tours) do
        if tour.name == name then
            self:StartTour(tour.id)
            return true
        end
    end
    O:Print("Tour not found: " .. name)
    return false
end

function Tours:DeleteTour(tourID)
    local index, tour = FindTourIndexByID(tourID)
    if not index or not tour then
        return false
    end

    local wasActive = tonumber(O.db.activeTourID) == tonumber(tour.id)
    table.remove(O.db.tours, index)
    if wasActive then
        O.db.activeTourID = O.db.tours[1] and O.db.tours[1].id or nil
        O.db.activeTourIndex = 1
        local nextTour = self:GetActiveTour()
        if nextTour and nextTour.waypointIDs[1] then
            O.Services.WaypointService:TrackWaypoint(nextTour.waypointIDs[1])
        else
            O.Services.WaypointService:UntrackWaypoint()
        end
    end

    O:MarkDirty()
    if O.UI.MainFrame then
        O.UI.MainFrame.selectedTourID = O.db.activeTourID
        O.UI.MainFrame:RefreshToursPanel()
    end
    RefreshRouteOverlay()
    return true
end

function Tours:AddCurrentPositionToActiveTour(title)
    local activeTour = self:GetActiveTour()
    if not activeTour then
        O:Print("Create or select a tour first.")
        return nil
    end
    if #activeTour.waypointIDs >= MAX_TOUR_WAYPOINTS then
        O:Print("The active tour has reached the waypoint limit.")
        return nil
    end

    local mapID, x, y = O:GetPlayerMapPosition()
    if not mapID then
        O:Print("Unable to read player position here.")
        return nil
    end

    local waypointID = O.Services.WaypointService:AddWaypoint({
        title = O:Trim((title ~= nil and title ~= "") and title or (activeTour.name .. " Point " .. (#activeTour.waypointIDs + 1))),
        mapID = mapID,
        x = x,
        y = y,
        source = "Tours",
        tags = { "tour" },
        autoTrack = false,
    })

    if waypointID then
        table.insert(activeTour.waypointIDs, waypointID)
        activeTour.updatedAt = time()
        O.db.activeTourIndex = #activeTour.waypointIDs
        O.Services.WaypointService:TrackWaypoint(waypointID)
        O:MarkDirty()
        if O.UI.MainFrame then
            O.UI.MainFrame:RefreshAll()
        end
        RefreshRouteOverlay()
    end
    return waypointID
end

function Tours:AdvanceTour(step)
    local tour = self:GetActiveTour()
    if not tour or #tour.waypointIDs == 0 then
        return false
    end

    local delta = tonumber(step) or 1
    local currentIndex = math.max(1, math.min(#tour.waypointIDs, tonumber(O.db.activeTourIndex) or 1))
    local newIndex = currentIndex + delta
    if tour.loop then
        newIndex = ((newIndex - 1) % #tour.waypointIDs) + 1
    else
        newIndex = math.max(1, math.min(#tour.waypointIDs, newIndex))
    end
    O.db.activeTourIndex = newIndex
    O:MarkDirty()

    local waypointID = tour.waypointIDs[newIndex]
    if waypointID then
        O.Services.WaypointService:TrackWaypoint(waypointID)
    end

    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshToursPanel()
    end
    RefreshRouteOverlay()
    return true
end

function Tours:AttachExistingWaypointToTour(tourID, waypointID)
    local tour = self:GetTourByID(tourID)
    if not tour then
        return false
    end
    if not O.Services.WaypointService:GetWaypointByID(waypointID) then
        return false
    end
    if #tour.waypointIDs >= MAX_TOUR_WAYPOINTS then
        return false
    end
    table.insert(tour.waypointIDs, tonumber(waypointID))
    tour.updatedAt = time()
    O:MarkDirty()
    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshToursPanel()
    end
    RefreshRouteOverlay()
    return true
end

function Tours:MoveWaypointWithinTour(tourID, index, delta)
    local tour = self:GetTourByID(tourID)
    if not tour then
        return false
    end

    index = tonumber(index)
    if not index or index < 1 or index > #tour.waypointIDs then
        return false
    end

    local newIndex = math.max(1, math.min(#tour.waypointIDs, index + (tonumber(delta) or 0)))
    if newIndex == index then
        return false
    end

    local waypointID = table.remove(tour.waypointIDs, index)
    table.insert(tour.waypointIDs, newIndex, waypointID)

    if tonumber(O.db.activeTourID) == tonumber(tourID) and tonumber(O.db.activeTourIndex) == index then
        O.db.activeTourIndex = newIndex
    end

    tour.updatedAt = time()
    O:MarkDirty()
    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshToursPanel()
    end
    RefreshRouteOverlay()
    return true
end


-- Body of HandleArrival. Split out so the re-entrancy guard below wraps every
-- return path rather than being repeated at each one.
local function EvaluateArrival(self, distance)
    local tour = self:GetActiveTour()
    if not tour or #tour.waypointIDs == 0 or not O.db.settings.autoAdvanceTours then
        return false
    end

    local threshold = math.max(5, tonumber(O.db.settings.arrivalDistanceYards) or 25)

    -- An unknown distance is not the same as "the player left the radius", so
    -- it must not re-arm the latch. GetDistanceToWaypoint returns nil whenever
    -- the target is on another continent or its map data is not loaded.
    if not distance then
        return false
    end
    if distance > threshold then
        self._arrivalReady = true
        return false
    end

    if self._arrivalReady == false then
        return false
    end
    self._arrivalReady = false

    local activeIndex = math.max(1, math.min(#tour.waypointIDs, tonumber(O.db.activeTourIndex) or 1))
    if activeIndex >= #tour.waypointIDs then
        if tour.loop then
            self:AdvanceTour(1)
            if O.UI.MainFrame then
                local nextWaypoint = self:GetActiveWaypoint()
                O.UI.MainFrame:Toast("Tour looped", nextWaypoint and ("Next stop: " .. (nextWaypoint.title or "Waypoint")) or "Returned to the first stop.")
            end
            return true
        end
        if O.UI.MainFrame then
            O.UI.MainFrame:Toast("Tour complete", "You reached the final stop of the active tour.")
        end
        return false
    end

    self:AdvanceTour(1)
    if O.UI.MainFrame then
        local nextWaypoint = self:GetActiveWaypoint()
        O.UI.MainFrame:Toast("Tour advanced", nextWaypoint and ("Next stop: " .. (nextWaypoint.title or "Waypoint")) or "Moved to the next stop.")
    end
    return true
end

function Tours:HandleArrival(distance)
    -- This is re-entrant. AdvanceTour tracks the new waypoint, tracking
    -- refreshes the HUD, and HUD:Refresh ends by calling back into
    -- HandleArrival with a freshly measured distance. That inner call is
    -- looking at the *next* stop, which is normally outside the arrival
    -- radius, so it would re-arm the latch the outer call had just cleared --
    -- and the following frame advances again. Left unguarded a tour walks
    -- through every remaining stop in a handful of frames.
    if self._handlingArrival then
        return false
    end

    self._handlingArrival = true
    -- pcall so a failure inside the toast or refresh cannot leave the guard
    -- stuck on, which would disable auto-advance for the rest of the session.
    local ok, result = pcall(EvaluateArrival, self, distance)
    self._handlingArrival = false

    if not ok then
        error(result, 0)
    end
    return result
end
