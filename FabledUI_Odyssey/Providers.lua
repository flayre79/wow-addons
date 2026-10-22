local addonName, ns = ...
local O = ns.Odyssey

O._speed = {
    lastTime = 0,
    lastContinent = nil,
    lastWorldX = nil,
    lastWorldY = nil,
    average = 0,
    alpha = 0.20,
}

function O:GetBestMapForPlayer()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
end

function O:GetPlayerPositionForMap(mapID)
    if not mapID or not C_Map or not C_Map.GetPlayerMapPosition then
        return nil
    end
    return C_Map.GetPlayerMapPosition(mapID, "player")
end

-- The player's world height, for waypoints captured where the player stands.
--
-- UnitPosition returns (posY, posX, posZ, instanceID) -- note Y comes first.
-- It is restricted inside instances, battlegrounds and arenas, where it
-- returns zeros or nothing; there is no height to record in those cases, so
-- this returns nil rather than a fabricated 0, which would drop the marker to
-- the bottom of the world.
--
-- Precedent that this z shares a coordinate space with a UiMapPoint's z:
-- HandyNotes_MapNotes/Core/Retail/RetailNpc.lua:683-686 compares the two
-- directly.
function O:GetPlayerElevation()
    if type(UnitPosition) ~= "function" then
        return nil
    end

    local ok, _, _, posZ = pcall(UnitPosition, "player")
    if not ok then
        return nil
    end

    posZ = tonumber(posZ)
    if not posZ or posZ ~= posZ or posZ == 0 then
        return nil
    end
    return posZ
end

function O:GetWorldPositionFromMapPosition(mapID, x, y)
    if not C_Map or not C_Map.GetWorldPosFromMapPos then
        return nil
    end

    local ok, continentID, worldPosition = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(self:Clamp01(x), self:Clamp01(y)))
    if ok and continentID and worldPosition and worldPosition.GetXY then
        local worldX, worldY = worldPosition:GetXY()
        return continentID, worldX, worldY
    end
    return nil
end

function O:UpdateSpeedEstimate()
    local playerMapID = self:GetBestMapForPlayer()
    local playerPosition = playerMapID and self:GetPlayerPositionForMap(playerMapID)
    if not playerPosition or not playerPosition.GetXY then
        return
    end

    local playerX, playerY = playerPosition:GetXY()
    local continentID, worldX, worldY = self:GetWorldPositionFromMapPosition(playerMapID, playerX, playerY)
    if not continentID then
        return
    end

    local now = GetTime()
    local speed = self._speed
    if speed.lastTime == 0 then
        speed.lastTime = now
        speed.lastContinent = continentID
        speed.lastWorldX = worldX
        speed.lastWorldY = worldY
        return
    end

    local deltaTime = now - speed.lastTime
    if deltaTime > 0.05 and speed.lastContinent == continentID and speed.lastWorldX and speed.lastWorldY then
        local distance = math.sqrt((worldX - speed.lastWorldX) ^ 2 + (worldY - speed.lastWorldY) ^ 2)
        local velocity = distance / deltaTime
        if velocity < 500 then
            if speed.average == 0 then
                speed.average = velocity
            else
                speed.average = (1 - speed.alpha) * speed.average + speed.alpha * velocity
            end
        end
    end

    speed.lastTime = now
    speed.lastContinent = continentID
    speed.lastWorldX = worldX
    speed.lastWorldY = worldY
end

function O:GetDistanceToWaypoint(waypoint)
    if type(waypoint) ~= "table" or not waypoint.mapID then
        return nil
    end

    local playerMapID = self:GetBestMapForPlayer()
    local playerPosition = playerMapID and self:GetPlayerPositionForMap(playerMapID)
    if not playerPosition or not playerPosition.GetXY then
        return nil
    end

    local playerX, playerY = playerPosition:GetXY()
    local playerContinent, playerWorldX, playerWorldY = self:GetWorldPositionFromMapPosition(playerMapID, playerX, playerY)
    local targetContinent, targetWorldX, targetWorldY = self:GetWorldPositionFromMapPosition(waypoint.mapID, waypoint.x, waypoint.y)

    if playerContinent and targetContinent and playerContinent == targetContinent and playerWorldX and targetWorldX then
        local dx = targetWorldX - playerWorldX
        local dy = targetWorldY - playerWorldY
        return math.sqrt(dx * dx + dy * dy)
    end

    if playerMapID == waypoint.mapID then
        local dx = (waypoint.x or 0) - playerX
        local dy = (waypoint.y or 0) - playerY
        return math.sqrt(dx * dx + dy * dy) * 10000
    end

    return nil
end

function O:GetETAForDistance(distance)
    if not distance or self._speed.average <= 0.5 then
        return nil
    end
    return distance / self._speed.average
end

-- World-space bearing to a waypoint, in radians measured counter-clockwise
-- from north -- the same frame of reference GetPlayerFacing() uses. Subtract
-- the player's facing to get a screen-relative angle for an arrow:
--
--     texture:SetRotation(bearing - GetPlayerFacing())
--
-- (Precedent for that subtraction: HandyNotes_Dragonflight/core/map.lua
-- MinimapPinMixin:UpdateRotation.)
--
-- WoW's world coordinates put +x toward north and +y toward west, so the
-- counter-clockwise-from-north angle is atan2(westward, northward).
function O:GetBearingToWaypoint(waypoint)
    if type(waypoint) ~= "table" then
        return nil
    end

    local playerMapID = self:GetBestMapForPlayer()
    local playerPosition = playerMapID and self:GetPlayerPositionForMap(playerMapID)
    if not playerPosition or not playerPosition.GetXY then
        return nil
    end

    local playerX, playerY = playerPosition:GetXY()
    local playerContinent, playerWorldX, playerWorldY = self:GetWorldPositionFromMapPosition(playerMapID, playerX, playerY)
    local targetContinent, targetWorldX, targetWorldY = self:GetWorldPositionFromMapPosition(waypoint.mapID, waypoint.x, waypoint.y)
    if playerContinent and targetContinent and playerContinent == targetContinent and playerWorldX and targetWorldX then
        local northward = targetWorldX - playerWorldX
        local westward = targetWorldY - playerWorldY
        return math.atan2(westward, northward)
    end

    -- Fallback for maps GetWorldPosFromMapPos refuses (some instances and
    -- micro-dungeons). Map coordinates run +x east and +y south, and are not
    -- aspect-corrected, so this is approximate -- but an approximate heading
    -- beats an arrow frozen in place, which is what returning nil here did.
    if playerMapID == waypoint.mapID then
        local eastward = (tonumber(waypoint.x) or 0) - playerX
        local southward = (tonumber(waypoint.y) or 0) - playerY
        return math.atan2(-eastward, -southward)
    end

    return nil
end

local function HasTomTomProvider()
    return TomTom and (type(TomTom.AddWaypoint) == "function" or type(TomTom.AddZWaypoint) == "function")
end

local function HasBlizzardProvider()
    if not C_Map or type(C_Map.SetUserWaypoint) ~= "function" or not UiMapPoint then
        return false
    end
    -- CreateFromCoordinates is preferred because it takes elevation; the
    -- Vector2D form is the fallback for clients that only expose that.
    if type(UiMapPoint.CreateFromCoordinates) == "function" then
        return true
    end
    return type(UiMapPoint.CreateFromVector2D) == "function" and type(CreateVector2D) == "function"
end

function O:CanUseBlizzardWaypointOnMap(mapID)
    if not HasBlizzardProvider() then
        return false
    end
    mapID = tonumber(mapID)
    if mapID and mapID > 0 and C_Map.CanSetUserWaypointOnMap then
        local ok, allowed = pcall(C_Map.CanSetUserWaypointOnMap, mapID)
        return ok and allowed and true or false
    end
    return true
end

function O:GetPreferredProviderName(mapID)
    local mode = self.db.settings.providerMode
    local hasTomTom = HasTomTomProvider()
    local hasBlizzard = self:CanUseBlizzardWaypointOnMap(mapID)

    if mode == "tomtom" and hasTomTom then
        return "TomTom"
    elseif mode == "blizzard" and hasBlizzard then
        return "Blizzard"
    elseif hasBlizzard then
        return "Blizzard"
    elseif hasTomTom then
        return "TomTom"
    end

    return nil
end

function O:SetProviderWaypoint(waypoint)
    if type(waypoint) ~= "table" then
        return nil, nil, "Waypoint is invalid."
    end

    local mapID = tonumber(waypoint.mapID) or 0
    local x, y, coordinateError
    if self.Services and self.Services.WaypointService and self.Services.WaypointService.NormalizeCoordinates then
        x, y, coordinateError = self.Services.WaypointService:NormalizeCoordinates(waypoint.x, waypoint.y)
    else
        x, y = tonumber(waypoint.x), tonumber(waypoint.y)
    end
    if mapID <= 0 or not x or not y then
        return nil, nil, coordinateError or "Waypoint coordinates are invalid."
    end

    local function TryTomTom()
        if TomTom and TomTom.AddWaypoint then
            local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, {
                title = waypoint.title,
                persistent = false,
                minimap = true,
                world = true,
            })
            if ok and uid then
                return uid, "TomTom"
            end
        elseif TomTom and TomTom.AddZWaypoint then
            local ok, uid = pcall(TomTom.AddZWaypoint, TomTom, mapID, x, y, waypoint.title)
            if ok and uid then
                return uid, "TomTom"
            end
        end
        return nil, nil, "TomTom rejected the waypoint."
    end

    local function TryBlizzard()
        if not self:CanUseBlizzardWaypointOnMap(mapID) then
            return nil, nil, "Blizzard cannot set a user waypoint on this map."
        end
        -- Pass the stored elevation through. A UiMapPoint built from x/y alone
        -- gets z = 0, and the in-world marker is drawn at that height -- which
        -- is why a waypoint could hang in mid-air instead of sitting on the
        -- ground. CreateFromCoordinates takes z as its fourth argument
        -- (precedent: AllTheThings/src/Modules/Vignette.lua:38).
        local z = tonumber(waypoint.z)
        local pointOK, mapPoint
        if type(UiMapPoint.CreateFromCoordinates) == "function" then
            pointOK, mapPoint = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y, z)
        else
            pointOK, mapPoint = pcall(UiMapPoint.CreateFromVector2D, mapID, CreateVector2D(x, y), z)
        end
        if not pointOK or not mapPoint then
            return nil, nil, "Blizzard could not create a map point."
        end
        if waypoint.title and mapPoint.SetTitle then
            pcall(mapPoint.SetTitle, mapPoint, waypoint.title)
        end
        self._suspendUserWaypointCapture = true
        local setOK = pcall(C_Map.SetUserWaypoint, mapPoint)
        if not setOK then
            self._suspendUserWaypointCapture = false
            return nil, nil, "Blizzard rejected the user waypoint."
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                self._suspendUserWaypointCapture = false
            end)
        else
            self._suspendUserWaypointCapture = false
        end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        return "blizzard:user", "Blizzard"
    end

    local mode = self.db.settings.providerMode
    if mode == "tomtom" then
        return TryTomTom()
    elseif mode == "blizzard" then
        return TryBlizzard()
    end

    local provider = self:GetPreferredProviderName(mapID)
    local providerID, providerName, providerError
    if provider == "Blizzard" then
        providerID, providerName, providerError = TryBlizzard()
        if providerID then
            return providerID, providerName
        end
        if HasTomTomProvider() then
            return TryTomTom()
        end
    elseif provider == "TomTom" then
        providerID, providerName, providerError = TryTomTom()
        if providerID then
            return providerID, providerName
        end
        if self:CanUseBlizzardWaypointOnMap(mapID) then
            return TryBlizzard()
        end
    end

    return nil, nil, providerError or "No waypoint provider is available."
end

function O:ClearProviderWaypoint(providerID, providerName)
    if providerName == "TomTom" then
        if TomTom and providerID and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, providerID)
        end
    elseif providerName == "Blizzard" then
        if C_Map and C_Map.ClearUserWaypoint then
            pcall(C_Map.ClearUserWaypoint)
        end
        if C_SuperTrack and C_SuperTrack.ClearSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.ClearSuperTrackedUserWaypoint)
        end
    end
end
