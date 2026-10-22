local addonName, ns = ...
local O = ns.Odyssey

-- Persistent world-map pins for stored Odyssey waypoints, plus the player
-- pulse absorbed from World_Map_Character_Pulse.
--
-- `Services/WaypointService.lua:RefreshVisuals` has always called
-- `O.UI.MapPins:Refresh()`, and Storage.lua has always shipped `showMapPins`
-- and `pulsePlayerOnMap` defaults -- but no module answered to either. This
-- file is what those three references were pointing at.
--
-- Structure deliberately mirrors UI/RouteOverlay.lua (pool + container
-- parented to the map canvas + Render/Refresh/Clear/Initialize) rather than
-- registering a map data provider. Odyssey already draws its route lines that
-- way, so pins and lines share one canvas, one refresh path and one hook set.

local Pins = {}
O.UI.MapPins = Pins

local PIN_SIZE = 14
local TRACKED_PIN_SIZE = 18

local COLOR_DEFAULT = { 0.31, 0.72, 0.91, 1.00 } -- azure (journey/wayfinding)
local COLOR_TRACKED = { 1.00, 0.82, 0.20, 1.00 } -- amber, for the tracked stop
local COLOR_BORDER  = { 0.02, 0.05, 0.08, 0.90 }

-- Pulse tuning, carried over from World_Map_Character_Pulse/Config.lua.
local PULSE_SCALE = 1.50
local PULSE_HALF_DURATION = 0.60

local pinPool = {}
local activePins = {}
local pinContainer = nil
local hooked = false
local lastDrawnMapID = nil

local pulseTarget = nil
local pulseAnim = nil

---------------------------------------------------------------------------
-- Canvas helpers (same resolution order as UI/RouteOverlay.lua)
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

-- Absent setting means "on": the default has always been true, and a database
-- saved before the key existed should still show pins rather than silently
-- losing them. Exposed as methods so the rule can be asserted without a world
-- map canvas to render against.
function Pins:ArePinsEnabled()
    local settings = O.db and O.db.settings
    return not settings or settings.showMapPins ~= false
end

function Pins:IsPulseEnabled()
    local settings = O.db and O.db.settings
    return not settings or settings.pulsePlayerOnMap ~= false
end

local function PinsEnabled()
    return Pins:ArePinsEnabled()
end

local function PulseEnabled()
    return Pins:IsPulseEnabled()
end

---------------------------------------------------------------------------
-- Pin pool
---------------------------------------------------------------------------
local function ApplyPinLook(pin, isTracked)
    local color = isTracked and COLOR_TRACKED or COLOR_DEFAULT
    local size = isTracked and TRACKED_PIN_SIZE or PIN_SIZE

    pin:SetSize(size, size)
    pin.border:SetColorTexture(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4])
    pin.icon:SetColorTexture(color[1], color[2], color[3], color[4])
end

local function OnPinEnter(pin)
    if not GameTooltip or not pin.waypointID then
        return
    end
    local waypoint = O.Services and O.Services.WaypointService
        and O.Services.WaypointService:GetWaypointByID(pin.waypointID)
    if not waypoint then
        return
    end

    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(waypoint.title or "Waypoint", 1, 1, 1)
    if O.db and O.db.settings and O.db.settings.showSourceLabels and waypoint.source then
        GameTooltip:AddLine(waypoint.source, 0.62, 0.65, 0.71)
    end
    GameTooltip:AddLine(string.format("%.1f, %.1f", (waypoint.x or 0) * 100, (waypoint.y or 0) * 100), 0.62, 0.65, 0.71)
    GameTooltip:AddLine("Click to track. Right-click to remove.", 0.31, 0.72, 0.91)
    GameTooltip:Show()
end

local function OnPinLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function OnPinClick(pin, button)
    -- Capture the ID first: both branches refresh, which releases this pin
    -- back into the pool and clears `pin.waypointID` underneath us.
    local waypointID = pin.waypointID
    local service = O.Services and O.Services.WaypointService
    if not waypointID or not service then
        return
    end

    if button == "RightButton" then
        service:RemoveWaypoint(waypointID)
    else
        service:TrackWaypoint(waypointID)
    end
end

local function AcquirePin()
    if not pinContainer then
        return nil
    end

    local pin = next(pinPool)
    if pin then
        pinPool[pin] = nil
        pin:Show()
        return pin
    end

    local newPin = CreateFrame("Button", nil, pinContainer)
    newPin:SetSize(PIN_SIZE, PIN_SIZE)
    newPin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    newPin.border = newPin:CreateTexture(nil, "BACKGROUND")
    newPin.border:SetAllPoints(newPin)

    newPin.icon = newPin:CreateTexture(nil, "ARTWORK")
    newPin.icon:SetPoint("TOPLEFT", newPin, "TOPLEFT", 2, -2)
    newPin.icon:SetPoint("BOTTOMRIGHT", newPin, "BOTTOMRIGHT", -2, 2)

    newPin:SetScript("OnEnter", OnPinEnter)
    newPin:SetScript("OnLeave", OnPinLeave)
    newPin:SetScript("OnClick", OnPinClick)

    return newPin
end

local function ReleasePin(pin)
    if not pin then
        return
    end
    pin.waypointID = nil
    pin:Hide()
    pin:ClearAllPoints()
    pinPool[pin] = true
end

local function ReleaseAllPins()
    for index = #activePins, 1, -1 do
        ReleasePin(activePins[index])
        activePins[index] = nil
    end
end

---------------------------------------------------------------------------
-- Player pulse (absorbed from World_Map_Character_Pulse/Config.lua)
---------------------------------------------------------------------------
local function GetPlayerPin()
    if not WorldMapFrame or type(WorldMapFrame.dataProviders) ~= "table" then
        return nil
    end

    for provider in pairs(WorldMapFrame.dataProviders) do
        if type(provider) == "table" and type(provider.ShouldShowUnit) == "function" then
            local ok, shouldShow = pcall(provider.ShouldShowUnit, provider, "player")
            if ok and shouldShow and provider.pin then
                return provider.pin
            end
        end
    end
    return nil
end

local function GetPulseTarget(pin)
    if not pin then
        return nil
    end
    -- Prefer the icon texture so the pin's own hit rect is left alone.
    local candidates = { pin.Icon, pin.icon, pin.Texture, pin.texture, pin }
    for _, candidate in ipairs(candidates) do
        if type(candidate) == "table" and type(candidate.SetScale) == "function" then
            return candidate
        end
    end
    return nil
end

function Pins:StopPulse()
    if pulseAnim and pulseAnim.Stop then
        pcall(pulseAnim.Stop, pulseAnim)
    end
    if pulseTarget and pulseTarget.SetScale then
        pcall(pulseTarget.SetScale, pulseTarget, 1.0)
    end
    pulseAnim = nil
    pulseTarget = nil
end

function Pins:StartPulse()
    if not PulseEnabled() then
        self:StopPulse()
        return false
    end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return false
    end

    local target = GetPulseTarget(GetPlayerPin())
    if not target then
        return false
    end

    if pulseTarget ~= target then
        self:StopPulse()
        pulseTarget = target
    end

    if not pulseAnim then
        if type(target.CreateAnimationGroup) ~= "function" then
            return false
        end
        local ok, group = pcall(target.CreateAnimationGroup, target)
        if not ok or not group then
            return false
        end
        group:SetLooping("BOUNCE")

        local scale = group:CreateAnimation("Scale")
        scale:SetOrder(1)
        scale:SetDuration(PULSE_HALF_DURATION)
        scale:SetScaleFrom(1.0, 1.0)
        scale:SetScaleTo(PULSE_SCALE, PULSE_SCALE)
        scale:SetSmoothing("IN_OUT")

        pulseAnim = group
    end

    if pulseAnim.IsPlaying and not pulseAnim:IsPlaying() then
        pulseAnim:Play()
    end
    return true
end

function Pins:IsPulsing()
    return pulseAnim ~= nil and pulseAnim.IsPlaying ~= nil and pulseAnim:IsPlaying() and true or false
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------

-- Waypoints stored against `mapID`, in stored order. Split out so tests can
-- assert the filter without a world map being present.
function Pins:GetWaypointsForMap(mapID)
    local list = {}
    mapID = tonumber(mapID)
    if not mapID or not O.db or type(O.db.waypoints) ~= "table" then
        return list
    end

    for _, waypoint in ipairs(O.db.waypoints) do
        if tonumber(waypoint.mapID) == mapID then
            list[#list + 1] = waypoint
        end
    end
    return list
end

function Pins:Render()
    if not pinContainer then
        return
    end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        ReleaseAllPins()
        pinContainer:Hide()
        lastDrawnMapID = nil
        self:StopPulse()
        return
    end

    -- Pins and pulse are separate settings. Turning pins off must not take the
    -- player pulse down with it, so this returns before the pin work but still
    -- drives the pulse.
    if not PinsEnabled() then
        ReleaseAllPins()
        pinContainer:Hide()
        lastDrawnMapID = nil
        self:StartPulse()
        return
    end

    local canvas = GetMapCanvas()
    local mapID = GetActiveMapID()
    if not canvas or not mapID then
        ReleaseAllPins()
        pinContainer:Hide()
        return
    end

    if lastDrawnMapID ~= mapID then
        lastDrawnMapID = mapID
        pinContainer:SetParent(canvas)
        pinContainer:ClearAllPoints()
        pinContainer:SetAllPoints(canvas)
        pinContainer:SetFrameStrata("FULLSCREEN")
        -- Above RouteOverlay's lines (level 2000) so a pin is never buried
        -- under the route segment that connects it.
        pinContainer:SetFrameLevel(2010)
    end
    ReleaseAllPins()
    pinContainer:Show()

    local canvasW, canvasH = canvas:GetSize()
    if not canvasW or canvasW == 0 or not canvasH or canvasH == 0 then
        return
    end
    pinContainer:SetSize(canvasW, canvasH)

    local trackedID = tonumber(O.db and O.db.trackedWaypointID)
    for _, waypoint in ipairs(self:GetWaypointsForMap(mapID)) do
        local pin = AcquirePin()
        if not pin then
            break
        end

        local isTracked = trackedID ~= nil and tonumber(waypoint.id) == trackedID
        pin.waypointID = waypoint.id
        ApplyPinLook(pin, isTracked)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT",
            (tonumber(waypoint.x) or 0) * canvasW,
            -(tonumber(waypoint.y) or 0) * canvasH)
        pin:SetFrameLevel(pinContainer:GetFrameLevel() + (isTracked and 2 or 1))
        pin:Show()

        activePins[#activePins + 1] = pin
    end

    self:StartPulse()
end

function Pins:Refresh()
    if hooked and WorldMapFrame and WorldMapFrame:IsShown() then
        self:Render()
    end
end

function Pins:Clear()
    ReleaseAllPins()
    if pinContainer then
        pinContainer:Hide()
    end
    lastDrawnMapID = nil
    self:StopPulse()
end

function Pins:GetActivePinCount()
    return #activePins
end

---------------------------------------------------------------------------
-- Initialization / hooks
---------------------------------------------------------------------------
function Pins:Initialize()
    if hooked or not WorldMapFrame then
        return
    end

    if not pinContainer then
        pinContainer = CreateFrame("Frame", "FabledUIOdysseyMapPins", UIParent)
        pinContainer:Hide()
    end

    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function()
            Pins:Render()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            Pins:Clear()
        end)
    end

    -- Same rationale as RouteOverlay: SetMapID is the actual mutator and
    -- fires on every transition path; OnMapChanged is hooked too when present.
    if hooksecurefunc then
        if WorldMapFrame.SetMapID then
            hooksecurefunc(WorldMapFrame, "SetMapID", function()
                Pins:Render()
            end)
        end
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                Pins:Render()
            end)
        end
    end

    hooked = true
end

function Pins:IsHooked()
    return hooked
end
