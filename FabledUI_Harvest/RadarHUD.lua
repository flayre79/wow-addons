local H = Harvest
H.RadarHUD = {}
local R = H.RadarHUD

-- Shared RadarHUD from UIToolkit (SVC-004)
local SharedHUD = FabledUI_UIToolkit and FabledUI_UIToolkit.RadarHUD

-- Distance from the panel's top edge to the top of the radar, clearing the
-- title (8px inset + ~12px line) and the four-line stats block (~56px) plus
-- the 8px and 10px gaps. The panel is a fixed 220x300 with a fixed header, so
-- this is deterministic; it is a constant rather than an anchor to f.stats
-- because anchoring to that FontString centres the radar on the text instead
-- of on the panel.
local RADAR_TOP_INSET = 94

function R:Init()
    local f = CreateFrame("Frame", "FabledUI_HarvestHUD", UIParent, "BackdropTemplate")
    self.frame = f

    f:SetSize(220, 300)
    f:SetPoint(H.settings.radar.anchor, UIParent, H.settings.radar.anchor, H.settings.radar.x, H.settings.radar.y)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.7)

    f:SetScript("OnDragStart", function() if not H.settings.radar.locked then f:StartMoving() end end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local a, _, _, x, y = f:GetPoint(1)
        H.settings.radar.anchor, H.settings.radar.x, H.settings.radar.y = a, x, y
    end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOPLEFT", 8, -8)
    f.title:SetText("Session Harvest")

    f.stats = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.stats:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.stats:SetJustifyH("LEFT")

    -- Session state. Every layer gets a counter, not just the three the panel
    -- names: SaveNode reports fish, treasure and skin captures too, and a
    -- counter table that lacked those keys dropped them on the floor, so the
    -- total under-reported whatever the player was actually farming.
    self.session = { lumber = 0, herb = 0, ore = 0, fish = 0, treasure = 0, skin = 0 }
    self.sessionTotal = 0
    self.sessionStart = (GetTime and GetTime()) or 0

    -- Render through the same path as every later update, so the seeded text
    -- and the updated text are always the same shape and the panel cannot
    -- change height partway through a session.
    self:RefreshStats()

    -- ---- Shared circular radar (SVC-004) ----
    if SharedHUD then
        f.radar = SharedHUD:CreateRadar(f, {
            size  = 180,
            range = 0.15,
            rings = { 150, 300 },
            ringRanges = { 0.05, 0.10 },
        })
        -- Anchor horizontally to the frame, vertically to the stats block.
        -- Anchoring TOP->f.stats.BOTTOM centred the radar on the *text*, and
        -- f.stats is a left-aligned FontString pinned to TOPLEFT, so its centre
        -- sits ~38px from the left edge. A 180px radar centred there hung ~50px
        -- off the left side of the 220px panel.
        f.radar:SetPoint("TOP", f, "TOP", 0, -(RADAR_TOP_INSET))
        f.radar:SetActive(H.settings.radar.enabled)
        SharedHUD:StartSession("harvest")
    end

    if H.settings.radar.enabled then
        f:Show()
    else
        f:Hide()
    end

    self:StartTicker()
    self:WatchZoneChanges()
    self:RebuildPoints()
end

-- Radar:Render positions every blip relative to the player's *current*
-- position, so it has to run continuously -- its own contract says "call this
-- each tick". Harvest only ever called it from SaveNode, which meant the blips
-- froze wherever the player happened to be standing at the last capture and
-- only jumped when something was gathered.
--
-- Render is cheap (it repositions already-created textures); rebuilding the
-- point list is the part that walks the database, so those run at different
-- rates. 0.2s is responsive enough to read as smooth while keeping the walk
-- over a busy zone's points to five passes a second.
local RENDER_INTERVAL = 0.2

function R:StartTicker()
    if self._ticker then return end
    local ticker = CreateFrame("Frame")
    self._ticker = ticker
    local elapsedSince = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < RENDER_INTERVAL then return end
        elapsedSince = 0

        local frame = self.frame
        if not (frame and frame.radar and frame:IsShown()) then return end
        frame.radar:Render()
    end)
end

function R:StopTicker()
    if self._ticker then
        self._ticker:SetScript("OnUpdate", nil)
        self._ticker = nil
    end
end

-- Points are per-map, so crossing a zone boundary leaves the radar showing the
-- previous zone's nodes until the next capture.
function R:WatchZoneChanges()
    if self._zoneWatcher then return end
    local watcher = CreateFrame("Frame")
    self._zoneWatcher = watcher
    -- Handler before registration: a frame must never hold a live registration
    -- with no handler attached.
    watcher:SetScript("OnEvent", function()
        self:RebuildPoints()
    end)
    watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
end

--- Redraw the counter block. Fixed four lines so the layout never shifts.
function R:RefreshStats()
    if not (self.frame and self.frame.stats) then return end
    local session = self.session or {}

    -- Clamp elapsed to at least a second so the first gather of a session does
    -- not divide by ~0 and report an absurd rate.
    local now = (GetTime and GetTime()) or 0
    local elapsed = math.max(now - (self.sessionStart or now), 1)
    local perHour = math.floor(((self.sessionTotal or 0) / elapsed) * 3600)

    self.frame.stats:SetText(string.format(
        "Lumber: %d\nHerbs: %d\nOre: %d\nTotal: %d (%d/hr)",
        session.lumber or 0, session.herb or 0, session.ore or 0,
        self.sessionTotal or 0, perHour))
end

function R:UpdateSession(type, amount)
    if not type then return end
    amount = amount or 1

    -- Accept any layer. The old guard only incremented keys that already
    -- existed, so a capture of a type the table did not name was discarded
    -- silently -- no counter, no total, no error.
    self.session = self.session or {}
    self.session[type] = (self.session[type] or 0) + amount
    self.sessionTotal = (self.sessionTotal or 0) + amount

    self:RefreshStats()

    -- Notify shared session tracker
    if SharedHUD then
        SharedHUD:AddGather("harvest", amount)
    end
end

-- Node freshness thresholds, in seconds, for blip colouring.
local FRESH_SECONDS = 300
local AGING_SECONDS = 900

--- Build the radar point list for a map from stored nodes.
--- Returns a list of { x, y, mapID, status, label }.
---
--- This walk used to live inline inside SaveNode, which meant the only thing
--- that could ever refresh the radar was a capture.
function R:BuildPoints(mapID)
    local points = {}
    local nodes = H.db and H.db.nodes and H.db.nodes[mapID]
    if not nodes then return points end

    local now = time()
    local layers = H.settings and H.settings.layers
    for key, node in pairs(nodes) do
        if type(node) == "table" then
            -- Respect the layer toggles, so hiding ore on the map hides it on
            -- the radar too rather than leaving the two views disagreeing.
            if not layers or layers[node.type] then
                local sx, sy = strsplit(",", key)
                local nx, ny = tonumber(sx), tonumber(sy)
                if nx and ny then
                    local age = now - (node.lastSeen or now)
                    local status = (age < FRESH_SECONDS) and "fresh"
                        or (age < AGING_SECONDS) and "aging"
                        or "stale"
                    points[#points + 1] = {
                        x = nx, y = ny, mapID = mapID,
                        status = status, label = node.name,
                    }
                end
            end
        end
    end

    self:AppendImportedPoints(points, mapID, layers)
    return points
end

-- How far from the player an imported node has to be before it is left out of
-- the point list, in normalised map units. Render walks every point five times
-- a second, and a busy zone carries thousands of imported nodes, so they are
-- filtered once at build time rather than every frame. The bound is wider than
-- the radar's own range so the player can walk a fair way before the next
-- rebuild without blips popping in at the edge.
local IMPORT_PREFILTER = 0.30

--- Fold imported reference nodes into a point list, nearest-first and capped.
function R:AppendImportedPoints(points, mapID, layers)
    if not H.ForEachImportedNode then return points end
    if H.settings and H.settings.showImportedNodes == false then return points end

    local imported = H:GetImportedNodes(mapID)
    if not imported then return points end

    -- Filter against the player rather than the map centre; off-map this
    -- yields nothing rather than an arbitrary corner of the zone.
    local px, py
    if C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if ok and pos and pos.GetXY then px, py = pos:GetXY() end
    end
    if not (px and py) then return points end

    local bound = IMPORT_PREFILTER * IMPORT_PREFILTER
    for layer in pairs(imported) do
        if not layers or layers[layer] then
            H:ForEachImportedNode(mapID, layer, function(x, y)
                local dx, dy = x - px, y - py
                if dx * dx + dy * dy <= bound then
                    -- Imported nodes have no sighting time, so they never read
                    -- as "fresh" -- that colour means the player saw it this
                    -- session and it would be a lie here.
                    points[#points + 1] = {
                        x = x, y = y, mapID = mapID,
                        status = "stale", label = layer, imported = true,
                    }
                end
            end)
        end
    end
    return points
end

--- Rebuild the point list for a map (defaults to the player's current map).
function R:RebuildPoints(mapID)
    if not (self.frame and self.frame.radar) then return end
    if not mapID then
        mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    end
    if not mapID then return end
    self.frame.radar:SetPoints(self:BuildPoints(mapID))
    self.frame.radar:Render()
end

--- Supply current node points to the radar and render.
--- nodes: list of { x, y, mapID, status }
function R:RefreshRadar(nodes)
    if not self.frame or not self.frame.radar then return end
    self.frame.radar:SetPoints(nodes or {})
    self.frame.radar:Render()
end
