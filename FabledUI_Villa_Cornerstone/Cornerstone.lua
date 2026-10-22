-- Mouse over a neighborhood cornerstone: its plot and its owner, in the tooltip.
--
-- The world-cursor tooltip for a cornerstone carries the object's name and no
-- id the addon can use (AllTheThings resolves world objects by name for the
-- same reason). So the plot is found by geometry: the stone nearest the player,
-- from Stones.lua. When two stones are about equally near, both are listed --
-- a wrong owner stated with confidence is worse than two candidates.
--
-- "Nearest the player" is not "under the cursor": standing on your own lot and
-- hovering a neighbour's stone named YOUR plot -- 0.1.0's "every cornerstone
-- says You" (owner's /vcorner probe, 2026-10-02: 8 yd from his own stone 46).
-- The tooltip data offers nothing better: /vcorner debug on the live client
-- showed only dataInstanceID (a counter that rises on every refresh), type 4
-- and the one "Cornerstone" line -- no id, no guid. So since 0.3.0 the stone
-- is AIMED: the player's facing, turned by the cursor's offset from screen
-- centre, gives a ray along the ground, and the stone nearest that ray wins
-- (CursorRay). It assumes the camera looks where the character faces. When
-- no stone lies within 35 degrees of the ray the tooltip says it can't tell
-- (0.3.1; 0.3.0 fell back to nearest-to-you and named the wrong plot).
-- Nearest-to-you is used only when there is no ray at all.
-- Bearings use WoW's frame: +x north, +y west, atan2(west, north),
-- counter-clockwise like GetPlayerFacing (Odyssey's live-proven arrow).
--
-- Owners come from C_HousingNeighborhood.GetNeighborhoodMapData(), the getter
-- Blizzard's map pins use. It answers correctly with the map closed (same
-- probe: 55 rows, 1 you, 36 named, 18 for sale, identical to the map-open
-- read), so the tooltip reads it live. A snapshot is also saved per
-- neighborhood NAME (housing GUIDs are session tokens, CLAUDE.md) whenever
-- the world map shows the neighborhood, and is used only if the live read
-- comes back empty.
--
-- No request is made, nothing runs on a timer, and GetPlayerOwnedHouses() is
-- never called (CLAUDE.md, Events).

local addonName = ...

local Corner = {}
_G.FabledUI_VillaCornerstone = Corner

Corner.VERSION = "0.3.1"
Corner.ADDON_NAME = addonName or "FabledUI_Villa_Cornerstone"

-- The world object's name. enUS only until someone plays another locale.
Corner.NAMES = { ["Cornerstone"] = true }

-- Further than this from every stone and the guess is not worth showing.
Corner.MAX_YARDS = 90
-- A runner-up within this many yards of the nearest is listed too.
Corner.AMBIGUOUS_YARDS = 12
-- Aiming by cursor: stones up to this far are considered...
Corner.MAX_RAY_YARDS = 160
-- ...the best must lie within this angle of the cursor ray (radians, 35 deg;
-- 20 missed stone 54 at 22 deg in the owner's 2026-10-02 debug run),
Corner.MAX_RAY_OFF = math.rad(35)
-- ...and a runner-up within this much more angle (4 deg) is listed too.
Corner.AMBIGUOUS_OFF = math.rad(4)
-- A snapshot older than this gets its age printed beside the owner.
Corner.STALE_SECONDS = 7 * 24 * 60 * 60

local issecretvalue = _G.issecretvalue or function() return false end

local LABEL = { 1, 0.82, 0 }
local VALUE = { 1, 1, 1 }
local DIM = { 0.65, 0.65, 0.65 }

local OWNER_NONE, OWNER_SELF = 0, 3
do
    local enum = rawget(_G, "Enum")
    local t = enum and enum.HousingPlotOwnerType
    if type(t) == "table" then
        OWNER_NONE = t.None or OWNER_NONE
        OWNER_SELF = t.Self or OWNER_SELF
    end
end

function Corner:DB()
    local db = rawget(_G, "FabledUI_VillaCornerstoneDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_VillaCornerstoneDB = db
    end
    if db.enabled == nil then db.enabled = true end
    if type(db.neighborhoods) ~= "table" then db.neighborhoods = {} end
    return db
end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- A real string or nil. The secret check must come before anything else
-- touches the value (CLAUDE.md, secret values).
local function plainString(v)
    if issecretvalue(v) then return nil end
    if type(v) ~= "string" or v == "" then return nil end
    return v
end

local function plainNumber(v)
    if issecretvalue(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

local function now()
    local fn = rawget(_G, "time")
    return type(fn) == "function" and fn() or 0
end

-- -----------------------------------------------------------------------------
-- Which plot
-- -----------------------------------------------------------------------------

function Corner:CurrentMapID()
    local map = rawget(_G, "C_Map")
    if type(map) ~= "table" or type(map.GetBestMapForUnit) ~= "function" then return nil end
    local ok, mapID = pcall(map.GetBestMapForUnit, "player")
    if ok then return plainNumber(mapID) end
    return nil
end

function Corner:PlayerPosition()
    local fn = rawget(_G, "UnitPosition")
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, "player")
    if not ok then return nil end
    a, b = plainNumber(a), plainNumber(b)
    if not (a and b) then return nil end
    return a, b
end

-- Every stone on the map ranked by distance from (px, py), nearest first.
-- Both axis orders are tried and the one that puts a stone nearer wins; see
-- Stones.lua for why the order is not taken on trust.
function Corner:Rank(stones, px, py)
    if type(stones) ~= "table" or not (px and py) then return nil end
    local function ranked(ax, ay)
        local list = {}
        for _, s in ipairs(stones) do
            local dx, dy = s.x - ax, s.y - ay
            list[#list + 1] = { plot = s.plot, yards = math.sqrt(dx * dx + dy * dy) }
        end
        table.sort(list, function(l, r) return l.yards < r.yards end)
        return list
    end
    local straight, swapped = ranked(px, py), ranked(py, px)
    if #straight == 0 then return nil end
    if swapped[1].yards < straight[1].yards then return swapped, "swapped" end
    return straight, "straight"
end

-- The candidate plots for a cornerstone being hovered now: one, or two when
-- the call is close. nil when not in a known neighborhood or too far away.
-- The direction the mouse points along the ground, as a bearing in the same
-- frame as GetPlayerFacing() (radians counter-clockwise from north). Assumes
-- the camera looks where the character faces -- true while moving or steering
-- with the right mouse button, false after swinging the camera with the left.
-- The cursor's offset from screen centre turns that by up to half the
-- horizontal field of view (CVar cameraFov, taken as horizontal degrees;
-- unverified, default 90). nil when facing or cursor are unavailable.
function Corner:CursorRay()
    local facingFn, cursorFn = rawget(_G, "GetPlayerFacing"), rawget(_G, "GetCursorPosition")
    local parent = rawget(_G, "UIParent")
    if type(facingFn) ~= "function" or type(cursorFn) ~= "function" or not parent then return nil end
    local ok, facing = pcall(facingFn)
    facing = ok and plainNumber(facing) or nil
    if not facing then return nil end
    local cx = cursorFn()
    local scale = parent:GetEffectiveScale()
    local width = parent:GetWidth()
    if not (cx and scale and scale > 0 and width and width > 0) then return nil end
    local fraction = (cx / scale) / width
    local fov = 90
    local cvar = rawget(_G, "GetCVar")
    if type(cvar) == "function" then fov = tonumber(cvar("cameraFov")) or fov end
    local half = math.rad(fov) / 2
    -- Right of centre is clockwise, which is a smaller counter-clockwise angle.
    local offset = math.atan((2 * fraction - 1) * math.tan(half))
    return facing - offset
end

local function angleBetween(a, b)
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then d = 2 * math.pi - d end
    return d
end

-- Stones ranked by how far off the cursor ray they lie, nearest the ray first.
-- (north, west) is the player's position in the stones' own axis order, as
-- Rank chose it.
function Corner:RankByRay(stones, north, west, ray)
    local list = {}
    for _, s in ipairs(stones) do
        local dn, dw = s.x - north, s.y - west
        local yards = math.sqrt(dn * dn + dw * dw)
        if yards <= self.MAX_RAY_YARDS then
            list[#list + 1] = { plot = s.plot, yards = yards, off = angleBetween(math.atan2(dw, dn), ray) }
        end
    end
    table.sort(list, function(l, r) return l.off < r.off end)
    return list
end

function Corner:Candidates(mapID, px, py, ray)
    local stones = self.Stones and self.Stones[mapID]
    local ranked, order = self:Rank(stones, px, py)
    if not ranked then return nil end
    if ray then
        local north, west = px, py
        if order == "swapped" then north, west = py, px end
        local aimed = self:RankByRay(stones, north, west, ray)
        local best = aimed[1]
        if best and best.off <= self.MAX_RAY_OFF then
            local picks = { best }
            local second = aimed[2]
            if second and second.off - best.off <= self.AMBIGUOUS_OFF then
                picks[2] = second
            end
            return picks
        end
        -- The ray points at no stone, so the hovered one is not the nearest
        -- either: falling back to nearest-to-you is what named the owner's own
        -- plot for stones 77 and 109 degrees off his ray (debug, 2026-10-02).
        -- Say so rather than guess.
        return false
    end
    local first = ranked[1]
    if first.yards > self.MAX_YARDS then return nil end
    local picks = { first }
    local second = ranked[2]
    if second and second.yards - first.yards <= self.AMBIGUOUS_YARDS then
        picks[2] = second
    end
    return picks
end

-- -----------------------------------------------------------------------------
-- Who owns it: a snapshot taken from the map
-- -----------------------------------------------------------------------------

function Corner:NeighborhoodName()
    local api = rawget(_G, "C_HousingNeighborhood")
    if type(api) ~= "table" or type(api.GetNeighborhoodName) ~= "function" then return nil end
    local ok, name = pcall(api.GetNeighborhoodName)
    if ok then return plainString(name) end
    return nil
end

-- True only in the state Blizzard's own map provider reads the data in: the
-- world map is up, showing the player's current map, and that map is the
-- neighborhood. Tests replace this; the sim's C_Housing cannot be stubbed.
function Corner:CanCapture()
    local frame = rawget(_G, "WorldMapFrame")
    if not (frame and frame.IsShown and frame:IsShown() and frame.GetMapID) then return false end
    local housing = rawget(_G, "C_Housing")
    if type(housing) ~= "table" or type(housing.IsOnNeighborhoodMap) ~= "function" then return false end
    local ok, onMap = pcall(housing.IsOnNeighborhoodMap)
    if not ok or onMap ~= true then return false end
    local shown = plainNumber(frame:GetMapID())
    return shown ~= nil and shown == self:CurrentMapID()
end

-- Reads the map's plot owners into the saved snapshot. Returns the number of
-- plots stored, or nil when this is not a moment to read.
function Corner:Capture()
    if not self:CanCapture() then return nil end
    local hood = self:NeighborhoodName()
    if not hood then return nil end
    local api = rawget(_G, "C_HousingNeighborhood")
    if type(api) ~= "table" or type(api.GetNeighborhoodMapData) ~= "function" then return nil end
    local ok, rows = pcall(api.GetNeighborhoodMapData)
    if not ok or type(rows) ~= "table" then return nil end
    local plots, count = {}, 0
    for _, row in ipairs(rows) do
        local id = type(row) == "table" and plainNumber(row.plotID)
        if id then
            plots[id] = {
                ownerType = plainNumber(row.ownerType),
                ownerName = plainString(row.ownerName),
            }
            count = count + 1
        end
    end
    -- An empty answer says nothing about owners; keep the last good snapshot.
    if count == 0 then return 0 end
    self:DB().neighborhoods[hood] = { time = now(), plots = plots }
    return count
end

-- The saved snapshot for the neighborhood the player is in, or nil.
function Corner:Snapshot()
    local hood = self:NeighborhoodName()
    if not hood then return nil end
    local snap = self:DB().neighborhoods[hood]
    if type(snap) == "table" and type(snap.plots) == "table" then return snap end
    return nil
end

-- Owners for the tooltip: the live getter, or the saved snapshot when the
-- live read is empty. Shaped like a snapshot ({ time, plots }).
function Corner:Owners()
    local api = rawget(_G, "C_HousingNeighborhood")
    if type(api) == "table" and type(api.GetNeighborhoodMapData) == "function" then
        local ok, rows = pcall(api.GetNeighborhoodMapData)
        if ok and type(rows) == "table" then
            local plots, count = {}, 0
            for _, row in ipairs(rows) do
                local id = type(row) == "table" and plainNumber(row.plotID)
                if id then
                    plots[id] = { ownerType = plainNumber(row.ownerType), ownerName = plainString(row.ownerName) }
                    count = count + 1
                end
            end
            if count > 0 then return { plots = plots } end
        end
    end
    return self:Snapshot()
end

function Corner:PlotName(plotID)
    local api = rawget(_G, "C_HousingNeighborhood")
    if type(api) == "table" and type(api.GetNeighborhoodPlotName) == "function" then
        local ok, name = pcall(api.GetNeighborhoodPlotName, plotID)
        if ok then
            name = plainString(name)
            if name then return name end
        end
    end
    return "Plot " .. tostring(plotID)
end

-- What to print for a plot's owner: text and whether it is a real name.
function Corner:OwnerText(row)
    if type(row) ~= "table" then return "open the map to learn", false end
    local ownerType = plainNumber(row.ownerType)
    if ownerType == OWNER_SELF then return "You", true end
    local name = plainString(row.ownerName)
    if name then return name, true end
    if ownerType == OWNER_NONE then return "nobody (for sale)", false end
    return "not shown", false
end

local function ageText(seconds)
    local days = math.floor(seconds / 86400)
    if days >= 1 then return days .. "d ago" end
    return math.floor(seconds / 3600) .. "h ago"
end

-- -----------------------------------------------------------------------------
-- Tooltip
-- -----------------------------------------------------------------------------

local function firstLineText(tooltip, data)
    local lines = type(data) == "table" and data.lines
    local line = type(lines) == "table" and lines[1]
    if type(line) == "table" then
        local text = plainString(line.leftText)
        if text then return text end
    end
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    local region = name and _G[name .. "TextLeft1"]
    if region and region.GetText then
        return plainString(region:GetText())
    end
    return nil
end

function Corner:IsCornerstoneTooltip(tooltip, data)
    local text = firstLineText(tooltip, data)
    return text ~= nil and self.NAMES[text] == true
end

-- Adds the plot and owner lines. Returns the number of lines added.
function Corner:Paint(tooltip, picks, snap)
    if not tooltip or type(picks) ~= "table" or #picks == 0 then return 0 end
    local plots = type(snap) == "table" and snap.plots or {}
    local age
    if type(snap) == "table" and type(snap.time) == "number" and snap.time > 0 then
        local elapsed = now() - snap.time
        if elapsed > self.STALE_SECONDS then age = ageText(elapsed) end
    end
    local added = 0
    for i, pick in ipairs(picks) do
        local owner, isName = self:OwnerText(plots[pick.plot])
        if isName and age then owner = owner .. " (map " .. age .. ")" end
        local plotLabel = (i == 1 and #picks > 1) and "Probably" or (i > 1 and "or" or "Plot")
        tooltip:AddDoubleLine(plotLabel, self:PlotName(pick.plot),
            LABEL[1], LABEL[2], LABEL[3], VALUE[1], VALUE[2], VALUE[3])
        local ownerColor = isName and VALUE or DIM
        tooltip:AddDoubleLine("Owner", owner,
            LABEL[1], LABEL[2], LABEL[3], ownerColor[1], ownerColor[2], ownerColor[3])
        added = added + 2
    end
    tooltip:Show()
    return added
end

-- One readable line per field of the hovered tooltip's data. Secret values
-- are named, never touched (CLAUDE.md, secret values).
local function describe(v)
    if issecretvalue(v) then return "<secret>" end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return tostring(v) end
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table(" .. n .. ")"
    end
    return t
end

function Corner:DebugLines(data)
    local out = {}
    if type(data) ~= "table" then
        out[1] = "data: " .. describe(data)
        return out
    end
    local keys = {}
    for k in pairs(data) do
        if type(k) == "string" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        out[#out + 1] = k .. " = " .. describe(data[k])
    end
    local lines = data.lines
    if type(lines) == "table" then
        for i, line in ipairs(lines) do
            if type(line) == "table" then
                out[#out + 1] = "line " .. i .. ": " .. describe(line.leftText) .. " | type " .. describe(line.type)
            end
        end
    end
    return out
end

local lastDebug, lastDebugAt = nil, 0
function Corner:MaybeDebug(data)
    if not self:DB().debug then return end
    local lines = self:DebugLines(data)
    local signature = table.concat(lines, "\n")
    local clock = rawget(_G, "GetTime")
    local t = type(clock) == "function" and clock() or 0
    if signature == lastDebug and t - lastDebugAt < 3 then return end
    lastDebug, lastDebugAt = signature, t
    print("|cffffb81c[Villa Cornerstone]|r hovered tooltip data:")
    for _, line in ipairs(lines) do print("   " .. line) end
end

-- With debug on: the ray, the three stones nearest it, and what was picked.
local lastAim, lastAimAt = nil, 0
function Corner:MaybeDebugAim(mapID, px, py, ray, picks)
    if not self:DB().debug then return end
    local stones = self.Stones and self.Stones[mapID]
    local out = {}
    if not (ray and stones and px and py) then
        out[1] = "aim: no ray (facing or cursor unavailable) -- nearest-to-you used"
    else
        local facingFn = rawget(_G, "GetPlayerFacing")
        local facing = type(facingFn) == "function" and facingFn() or 0
        out[1] = string.format("aim: facing %.0f deg, cursor ray %.0f deg", math.deg(facing), math.deg(ray))
        local _, order = self:Rank(stones, px, py)
        local north, west = px, py
        if order == "swapped" then north, west = py, px end
        local aimed = self:RankByRay(stones, north, west, ray)
        for i = 1, math.min(3, #aimed) do
            local a = aimed[i]
            out[#out + 1] = string.format("  stone %d: %.0f deg off the ray, %.0f yd", a.plot, math.deg(a.off), a.yards)
        end
    end
    local chosen = {}
    for _, p in ipairs(picks or {}) do chosen[#chosen + 1] = tostring(p.plot) end
    out[#out + 1] = "  picked: " .. (#chosen > 0 and table.concat(chosen, " or ") or "nothing")
    local signature = table.concat(out, "\n")
    local clock = rawget(_G, "GetTime")
    local t = type(clock) == "function" and clock() or 0
    if signature == lastAim and t - lastAimAt < 3 then return end
    lastAim, lastAimAt = signature, t
    for _, line in ipairs(out) do print("|cffffb81c[Villa Cornerstone]|r " .. line) end
end

function Corner:OnTooltip(tooltip, data)
    if not self:DB().enabled then return end
    if tooltip ~= rawget(_G, "GameTooltip") then return end
    if not self:IsCornerstoneTooltip(tooltip, data) then return end
    local mapID = self:CurrentMapID()
    local px, py = self:PlayerPosition()
    local ray = self:CursorRay()
    local picks = self:Candidates(mapID, px, py, ray)
    self:MaybeDebugAim(mapID, px, py, ray, picks or nil)
    if picks == false then
        tooltip:AddDoubleLine("Owner", "can't tell -- face the stone",
            LABEL[1], LABEL[2], LABEL[3], DIM[1], DIM[2], DIM[3])
        tooltip:Show()
        return
    end
    if not picks then return end
    self:Paint(tooltip, picks, self:Owners())
end

local processor = rawget(_G, "TooltipDataProcessor")
if type(processor) == "table" and type(processor.AddTooltipPostCall) == "function" then
    local enum = rawget(_G, "Enum")
    local kind = enum and enum.TooltipDataType and enum.TooltipDataType.Object
    -- The cornerstone should be an Object tooltip; AllTypes is the fallback
    -- if a client lacks that enum. The name check keeps either cheap.
    if kind == nil then kind = processor.AllTypes end
    if kind ~= nil then
        pcall(processor.AddTooltipPostCall, kind, function(tooltip, data)
            local ok, err = pcall(Corner.OnTooltip, Corner, tooltip, data)
            if not ok then report(err) end
        end)
    end
end

-- -----------------------------------------------------------------------------
-- When to read the map: it opens, it changes map, or its data updates.
-- -----------------------------------------------------------------------------

local function captureSafely()
    local ok, err = pcall(Corner.Capture, Corner)
    if not ok then report(err) end
end

local hookedMap = false
function Corner:HookWorldMap()
    if hookedMap then return true end
    local frame = rawget(_G, "WorldMapFrame")
    if not (frame and frame.HookScript) then return false end
    frame:HookScript("OnShow", captureSafely)
    if type(frame.OnMapChanged) == "function" then
        hooksecurefunc(frame, "OnMapChanged", captureSafely)
    end
    hookedMap = true
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" then
        if loaded == Corner.ADDON_NAME or loaded == "Blizzard_WorldMap" then
            Corner:HookWorldMap()
        end
    elseif event == "NEIGHBORHOOD_MAP_DATA_UPDATED" then
        captureSafely()
    end
end)
pcall(eventFrame.RegisterEvent, eventFrame, "ADDON_LOADED")
pcall(eventFrame.RegisterEvent, eventFrame, "NEIGHBORHOOD_MAP_DATA_UPDATED")
Corner._eventFrame = eventFrame
Corner:HookWorldMap()

-- -----------------------------------------------------------------------------
-- Slash: /vcorner probe prints what the tooltip would decide from where you
-- stand, beside what the getter answers right now (map open or not), so the
-- off-map answer can be compared with the snapshot.
-- -----------------------------------------------------------------------------

local function ownerSummary(plots)
    local counts = { you = 0, named = 0, empty = 0, other = 0 }
    for _, row in pairs(plots) do
        local ownerType = row.ownerType
        if ownerType == OWNER_SELF then counts.you = counts.you + 1
        elseif row.ownerName then counts.named = counts.named + 1
        elseif ownerType == OWNER_NONE then counts.empty = counts.empty + 1
        else counts.other = counts.other + 1 end
    end
    return string.format("%d you, %d named, %d for sale, %d other", counts.you, counts.named, counts.empty, counts.other)
end

function Corner:PrintProbe(say)
    local mapID = self:CurrentMapID()
    local px, py = self:PlayerPosition()
    local hood = self:NeighborhoodName()
    say(string.format("neighborhood %s, map %s, position %s, %s", tostring(hood), tostring(mapID), tostring(px), tostring(py)))

    local snap = self:Snapshot()
    if snap then
        say(string.format("saved from map %s: %s", ageText(now() - (snap.time or 0)), ownerSummary(snap.plots)))
    else
        say("No saved owners for this neighborhood yet -- open the map here once.")
    end

    local api = rawget(_G, "C_HousingNeighborhood")
    if type(api) == "table" and type(api.GetNeighborhoodMapData) == "function" then
        local ok, rows = pcall(api.GetNeighborhoodMapData)
        if ok and type(rows) == "table" then
            local live = {}
            for _, row in ipairs(rows) do
                local id = type(row) == "table" and plainNumber(row.plotID)
                if id then live[id] = { ownerType = plainNumber(row.ownerType), ownerName = plainString(row.ownerName) } end
            end
            say(string.format("getter right now (map %s): %d rows, %s",
                self:CanCapture() and "open" or "not open", #rows, ownerSummary(live)))
        end
    end

    local stones = self.Stones and self.Stones[mapID]
    if not stones then
        say("Not in Founder's Point (2352) or Razorwind Shores (2351).")
        return
    end
    local ranked, order = self:Rank(stones, px, py)
    if not ranked then
        say("No player position (UnitPosition returned nothing).")
        return
    end
    say("axis order " .. order)
    local owners = self:Owners()
    local plots = owners and owners.plots or {}
    for i = 1, math.min(3, #ranked) do
        local r = ranked[i]
        local owner = self:OwnerText(plots[r.plot])
        say(string.format("  stone %d: %.0f yd -> %s, owner %s", r.plot, r.yards, self:PlotName(r.plot), owner))
    end
end

SLASH_FABLEDUI_VILLACORNERSTONE1 = "/vcorner"
SlashCmdList["FABLEDUI_VILLACORNERSTONE"] = function(msg)
    local db = Corner:DB()
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local function say(...) print("|cffffb81c[Villa Cornerstone]|r", ...) end
    if cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        say("Cornerstone owner lines " .. (db.enabled and "on." or "off."))
    elseif cmd == "debug" then
        db.debug = not db.debug
        say("Debug " .. (db.debug and "on: hover a cornerstone to print its tooltip data." or "off."))
    elseif cmd == "probe" or cmd == "" then
        local ok, err = pcall(Corner.PrintProbe, Corner, say)
        if not ok then report(err) end
        if cmd == "" then say("/vcorner on | off | probe | debug") end
    else
        say("/vcorner on | off | probe | debug")
    end
end
