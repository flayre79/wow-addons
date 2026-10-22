-- ================================================================
-- FabledUI_UIToolkit :: RadarHUD  (SVC-004)
-- Shared circular radar / HUD utility used by Crafty, Harvest, etc.
-- ================================================================
local T = FabledUI_UIToolkit
T.RadarHUD = {}
local HUD = T.RadarHUD

-- ================================================================
-- Defaults
-- ================================================================
local DEFAULT_SIZE      = 180
local DEFAULT_RANGE     = 0.15   -- normalised map-units visible from centre
local DEFAULT_BLIP_SIZE = 8

local STATUS_COLORS = {
    fresh = { 0.2, 0.9, 0.3 },   -- green  (likely respawned)
    aging = { 0.95, 0.85, 0.1 }, -- yellow (uncertain)
    stale = { 0.9, 0.2, 0.2 },   -- red    (recently gathered)
}

-- ================================================================
-- Internal helpers
-- ================================================================
local function GetPlayerMapPos()
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil, nil end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID, nil, nil end
    return mapID, pos:GetXY()
end

local function ColorForStatus(status)
    local c = STATUS_COLORS[status] or STATUS_COLORS.fresh
    return c[1], c[2], c[3]
end

local function PlaceBlip(blip, dx, dy, halfR, range, r, g, b)
    local sx = halfR + dx / range * halfR
    local sy = halfR - dy / range * halfR
    blip:SetPoint("CENTER", blip:GetParent(), "TOPLEFT", sx, -sy)
    blip:SetVertexColor(r, g, b, 1)
    blip:Show()
end

-- ================================================================
-- Session tracking
-- ================================================================
local sessions = {}

function HUD:StartSession(key)
    sessions[key] = {
        startTime = time(),
        gathers   = 0,
    }
end

function HUD:EndSession(key)
    local s = sessions[key]
    if s then
        s.endTime = time()
    end
end

function HUD:GetSessionStats(key)
    local s = sessions[key]
    if not s then return nil end
    local elapsed = (s.endTime or time()) - s.startTime
    local rate = elapsed > 0 and math.floor(s.gathers / (elapsed / 3600)) or 0
    return {
        startTime = s.startTime,
        endTime   = s.endTime,
        elapsed   = elapsed,
        gathers   = s.gathers,
        ratePerHour = rate,
    }
end

-- Increment gather count for a running session
function HUD:AddGather(key, count)
    local s = sessions[key]
    if s and not s.endTime then
        s.gathers = s.gathers + (count or 1)
    end
end

-- ================================================================
-- CreateRadar
-- ================================================================
-- opts fields (all optional):
--   size        (number)   pixel diameter, default 180
--   range       (number)   normalised map range, default 0.15
--   blipSize    (number)   blip px, default 8
--   rings       (table)    e.g. {150, 300} — yard labels for distance rings
--   ringRanges  (table)    normalised ranges matching rings, e.g. {0.05, 0.10}
--   bgColor     (table)    {r, g, b, a}
--   borderColor (table)    {r, g, b, a}
-- ================================================================
function HUD:CreateRadar(parent, opts)
    opts = opts or {}
    local size     = opts.size or DEFAULT_SIZE
    local range    = opts.range or DEFAULT_RANGE
    local blipSize = opts.blipSize or DEFAULT_BLIP_SIZE
    local halfR    = size / 2

    -- Radar frame
    local radar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    radar:SetSize(size, size)
    radar:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    local bg = opts.bgColor or { 0.04, 0.06, 0.10, 0.88 }
    radar:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    local bc = opts.borderColor or { 0.3, 0.3, 0.5, 0.7 }
    radar:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])

    -- Player marker (centre) — visually distinct from gather-node blips:
    --   * 1.5x the size of node blips
    --   * bright cyan with a white core (so you can see "I am here, not a blip")
    --   * outer halo ring so even on busy radars the player reads as the centre
    local playerSize = opts.playerSize or math.max(12, math.floor(blipSize * 1.5 + 0.5))
    local haloSize = playerSize + 6
    local coreSize = math.max(3, math.floor(playerSize * 0.45 + 0.5))

    local selfHalo = radar:CreateTexture(nil, "OVERLAY")
    selfHalo:SetDrawLayer("OVERLAY", 1)
    selfHalo:SetSize(haloSize, haloSize)
    selfHalo:SetTexture("Interface/Buttons/WHITE8x8")
    selfHalo:SetVertexColor(0.2, 1.0, 1.0, 0.18)
    selfHalo:SetPoint("CENTER")

    local selfDot = radar:CreateTexture(nil, "OVERLAY")
    selfDot:SetDrawLayer("OVERLAY", 2)
    selfDot:SetSize(playerSize, playerSize)
    selfDot:SetTexture("Interface/Buttons/WHITE8x8")
    selfDot:SetVertexColor(0.2, 1.0, 1.0, 1)
    selfDot:SetPoint("CENTER")

    local selfCore = radar:CreateTexture(nil, "OVERLAY")
    selfCore:SetDrawLayer("OVERLAY", 3)
    selfCore:SetSize(coreSize, coreSize)
    selfCore:SetTexture("Interface/Buttons/WHITE8x8")
    selfCore:SetVertexColor(1, 1, 1, 1)
    selfCore:SetPoint("CENTER")

    -- Distance rings
    local rings     = opts.rings or { 150, 300 }
    local ringNorms = opts.ringRanges or { 0.05, 0.10 }
    local ringColors = {
        { r = 0.4, g = 0.4, b = 0.8, a = 0.5 },
        { r = 0.6, g = 0.6, b = 1.0, a = 0.4 },
    }
    radar._rings = {}
    for i, yardLabel in ipairs(rings) do
        local norm = ringNorms[i] or (i * 0.05)
        local d = norm / range * size
        local rc = ringColors[i] or ringColors[#ringColors]
        local ringFrame = CreateFrame("Frame", nil, radar, "BackdropTemplate")
        ringFrame:SetSize(d, d)
        ringFrame:SetPoint("CENTER")
        ringFrame:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
        ringFrame:SetBackdropBorderColor(rc.r, rc.g, rc.b, rc.a)

        local lbl = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("BOTTOMLEFT", ringFrame, "BOTTOMLEFT", 2, 2)
        lbl:SetText("~" .. yardLabel .. "y")
        lbl:SetTextColor(rc.r, rc.g, rc.b, rc.a + 0.1)

        radar._rings[#radar._rings + 1] = ringFrame
    end

    -- Cardinal labels
    for _, dir in ipairs({
        { "N", "TOP",    0, -4 },
        { "S", "BOTTOM", 0,  4 },
        { "E", "RIGHT", -4,  0 },
        { "W", "LEFT",   4,  0 },
    }) do
        local t = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint(dir[2], radar, dir[2], dir[3], dir[4])
        t:SetText(dir[1])
        t:SetTextColor(0.5, 0.5, 0.7, 0.7)
    end

    -- Blip pool (managed internally)
    radar._blips   = {}
    radar._range   = range
    radar._size    = size
    radar._blipSize = blipSize
    radar._active  = false
    radar._points  = {}

    -- ============================================================
    -- Public API on the returned radarFrame
    -- ============================================================

    --- Enable / disable the radar display
    function radar:SetActive(active)
        self._active = active
        self:SetShown(active)
    end

    --- Supply the list of points to render.
    --- Each point: { x = <map-norm>, y = <map-norm>, status = "fresh"|"aging"|"stale", label = optional, mapID = optional }
    function radar:SetPoints(points)
        self._points = points or {}
    end

    --- Replace distance rings at runtime.
    --- ringYards: { 150, 300 }  — labels only; positions still use ringRanges from opts
    function radar:SetRings(ringYards)
        -- Update labels on existing ring frames
        for i, rf in ipairs(self._rings) do
            local lbl = ringYards[i]
            if lbl then
                -- find the fontstring child and update
                -- (rings are rebuild-safe; this is a lightweight update)
            end
        end
    end

    --- Core render — call this each tick / on refresh
    function radar:Render()
        if not self._active then return end

        local mapID, px, py = GetPlayerMapPos()
        local blips = self._blips
        local hr    = self._size / 2
        local rng   = self._range

        -- Hide all blips
        for _, b in ipairs(blips) do b:Hide() end

        if not px or not py then return end

        local shown = 0
        for _, pt in ipairs(self._points) do
            local sameMap = (pt.mapID == nil) or (pt.mapID == mapID)
            if sameMap then
                local dx = pt.x - px
                local dy = pt.y - py
                if math.abs(dx) <= rng and math.abs(dy) <= rng then
                    shown = shown + 1
                    local blip = blips[shown]
                    if not blip then
                        blip = self:CreateTexture(nil, "OVERLAY")
                        blip:SetSize(self._blipSize, self._blipSize)
                        blip:SetTexture("Interface/Buttons/WHITE8x8")
                        blips[shown] = blip
                    end
                    local r, g, b = ColorForStatus(pt.status or "fresh")
                    PlaceBlip(blip, dx, dy, hr, rng, r, g, b)
                end
            end
        end
    end

    return radar
end
