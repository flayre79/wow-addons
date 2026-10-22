local addonName, ns = ...
local O = ns.Odyssey

local HUD = {}
O.UI.HUD = HUD

local function DistanceColor(distance)
    if not distance then
        return 1, 1, 1
    end

    local nearDistance = 30
    local farDistance = 400
    local t = math.max(0, math.min(1, (distance - nearDistance) / (farDistance - nearDistance)))
    if t < 0.5 then
        local blend = t * 2
        return blend, 1 - (0.05 * blend), 0.5 - (0.5 * blend)
    end
    local blend = (t - 0.5) * 2
    return 1 - (0.8 * blend), 0.95 - (0.20 * blend), blend
end

function O:InitializeHUD()
    HUD:Create()
end

function HUD:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "FabledUI_OdysseyHUD", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(156, 132)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.03, 0.06, 0.12, 0.90)
    frame:SetBackdropBorderColor(0, 0.5, 0.8, 0.55)

    frame:SetScript("OnDragStart", function(f)
        if not O.db.settings.lockHUD then
            f:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
    end)

    -- The arrow used to be inert: no clicks, no tooltip, no way to move to the
    -- next stop or dismiss a waypoint you had already reached.
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            O.Services.WaypointService:UntrackWaypoint()
            return
        end

        local tours = O.Modules and O.Modules.Tours
        local activeTour = tours and tours:GetActiveTour()
        if activeTour and #activeTour.waypointIDs > 1 then
            tours:AdvanceTour(IsShiftKeyDown and IsShiftKeyDown() and -1 or 1)
        else
            O:Print("No active tour to advance. Right-click the arrow to stop tracking.")
        end
    end)

    frame:SetScript("OnEnter", function(f)
        if not GameTooltip then
            return
        end
        local waypoint = O.db.trackedWaypointID
            and O.Services.WaypointService:GetWaypointByID(O.db.trackedWaypointID) or nil

        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:AddLine(waypoint and (waypoint.title or "Tracked Waypoint") or "Odyssey", 1, 1, 1)

        local tours = O.Modules and O.Modules.Tours
        local activeTour = tours and tours:GetActiveTour()
        if activeTour then
            GameTooltip:AddLine(string.format("%s  [%d/%d]", activeTour.name,
                tonumber(O.db.activeTourIndex) or 1, #activeTour.waypointIDs), 0.62, 0.65, 0.71)
            GameTooltip:AddLine("Click: next stop", 0.31, 0.72, 0.91)
            GameTooltip:AddLine("Shift-click: previous stop", 0.31, 0.72, 0.91)
        end
        GameTooltip:AddLine("Right-click: stop tracking", 0.31, 0.72, 0.91)
        if not O.db.settings.lockHUD then
            GameTooltip:AddLine("Drag: move this arrow", 0.62, 0.65, 0.71)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    local arrivedText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrivedText:SetPoint("CENTER", frame, "TOP", 0, -44)
    arrivedText:SetText("|cff2ecc71ARRIVED|r")
    arrivedText:Hide()
    self.arrivedText = arrivedText

    local arrowHolder = CreateFrame("Frame", nil, frame)
    arrowHolder:SetSize(72, 72)
    arrowHolder:SetPoint("TOP", frame, "TOP", 0, -8)

    local arrow = arrowHolder:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(48, 48)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW")
    self.arrow = arrow

    local distanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    distanceText:SetPoint("TOP", arrowHolder, "BOTTOM", 0, -2)
    self.distanceText = distanceText

    local etaText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    etaText:SetPoint("TOP", distanceText, "BOTTOM", 0, -2)
    self.etaText = etaText

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("TOP", etaText, "BOTTOM", 0, -2)
    titleText:SetWidth(144)
    titleText:SetJustifyH("CENTER")
    self.titleText = titleText

    local sourceText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sourceText:SetPoint("TOP", titleText, "BOTTOM", 0, -2)
    sourceText:SetWidth(144)
    sourceText:SetJustifyH("CENTER")
    self.sourceText = sourceText

    local ticker = CreateFrame("Frame")
    ticker.accumulator = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        -- Rotation is applied every frame, not on the 0.25s data tick: the
        -- heading changes whenever the player turns, and at 4 Hz the arrow
        -- visibly steps around instead of tracking the camera.
        HUD:ApplyArrowRotation()

        ticker.accumulator = ticker.accumulator + elapsed
        if ticker.accumulator < 0.25 then
            return
        end
        ticker.accumulator = 0
        O:UpdateSpeedEstimate()
        HUD:Refresh()
        if O.UI.MainFrame and O.UI.MainFrame.frame and O.UI.MainFrame.frame:IsShown() then
            O.UI.MainFrame:RefreshWaypointsPanel()
            O.UI.MainFrame:RefreshToursPanel()
        end
    end)

    self:RefreshLockState()
    self:Refresh()
end

-- Point the arrow at the cached world bearing, corrected for where the player
-- is currently looking. Cheap enough to run every frame: GetPlayerFacing is a
-- simple accessor, while the map lookups that produce the bearing stay on the
-- slower refresh tick.
--
-- The arrow texture points "forward" at rotation 0, and SetRotation turns it
-- counter-clockwise, which matches bearing and facing both being measured
-- counter-clockwise from north.
function HUD:ApplyArrowRotation()
    if not self.arrow or not self.frame or not self.frame:IsShown() then
        return
    end

    local bearing = self._worldBearing
    if not bearing then
        return
    end

    local facing = GetPlayerFacing and GetPlayerFacing()
    if not facing then
        -- Indoors and in a few instances the client reports no facing. Show
        -- the raw bearing rather than freezing at whatever was last set.
        self.arrow:SetRotation(bearing)
        return
    end

    self.arrow:SetRotation(bearing - facing)
end

function HUD:RefreshLockState()
    if not self.frame then
        return
    end
    -- Mouse stays enabled even when locked: clicking and the tooltip are how
    -- the arrow is operated, and OnDragStart already refuses to move a locked
    -- HUD. Disabling the mouse here made "lock" mean "inert".
    self.frame:EnableMouse(true)
end

function HUD:Refresh()
    if not self.frame then
        return
    end

    if not O.db.settings.showHUD then
        self.frame:Hide()
        return
    end

    local waypoint = O.db.trackedWaypointID and O.Services.WaypointService:GetWaypointByID(O.db.trackedWaypointID) or nil
    if not waypoint then
        self._worldBearing = nil
        self.frame:Hide()
        return
    end

    self.frame:Show()

    local distance = O:GetDistanceToWaypoint(waypoint)
    local eta = O:GetETAForDistance(distance)

    -- Cache the world bearing; ApplyArrowRotation folds in the player's facing
    -- every frame. Previously this set the rotation straight from the bearing
    -- with no facing term at all, so the arrow pointed at a fixed compass
    -- direction and never turned with the camera.
    self._worldBearing = O:GetBearingToWaypoint(waypoint)
    self:ApplyArrowRotation()

    local r, g, b = DistanceColor(distance)
    self.arrow:SetVertexColor(r, g, b, 1)
    self.distanceText:SetText(O:FormatDistance(distance))
    self.etaText:SetText("ETA " .. O:FormatTime(eta))
    self.titleText:SetText(waypoint.title or "Tracked Waypoint")
    if self.sourceText then
        local sourceLabel = ""
        if O.db.settings.showSourceLabels then
            sourceLabel = waypoint.source or ""
            if waypoint.questID then
                sourceLabel = sourceLabel ~= "" and (sourceLabel .. " • Quest " .. waypoint.questID) or ("Quest " .. waypoint.questID)
            end
        end
        self.sourceText:SetText(sourceLabel)
    end

    -- Show an explicit arrived state rather than just letting the readout sit
    -- at "0 yd" with no acknowledgement.
    local threshold = math.max(5, tonumber(O.db.settings.arrivalDistanceYards) or 25)
    if self.arrivedText then
        self.arrivedText:SetShown(distance ~= nil and distance <= threshold)
    end

    -- Tours get first refusal: if auto-advance moves to the next stop, that is
    -- the arrival handled. Only a waypoint no tour owns falls through to the
    -- standalone announce/untrack path.
    local advanced = false
    if O.Modules and O.Modules.Tours and O.Modules.Tours.HandleArrival then
        advanced = O.Modules.Tours:HandleArrival(distance)
    end
    if not advanced then
        O:EvaluateTrackedArrival(waypoint, distance)
    end
end
