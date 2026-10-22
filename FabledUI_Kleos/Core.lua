local addonName, _ = ...
Kleos = Kleos or {}
local K = Kleos
_G.FabledUI_Kleos = K

K.VERSION = "1.2.1"
K._ready = false

local PREFIX = "|cff4fd1c5[Kleos]|r "

function K:Print(...) print(PREFIX, ...) end

-- SafeCall runs fn and, when it throws, reports *where* rather than only what.
-- A bare pcall message is useless once the same sentence can come from six call
-- sites -- "attempt to perform string conversion on a secret string value" cost
-- a whole debugging session for exactly that reason. xpcall captures the stack
-- at the point of the throw instead.
--
-- Repeats are collapsed: these fire per nameplate and per tooltip, so an
-- unguarded error would otherwise flood chat faster than it can be read. The
-- same message prints once, then again at most every REPEAT_AFTER seconds,
-- carrying the tally of what was suppressed in between.
local REPEAT_AFTER = 60
local reported = {}   -- first line of the error -> { at = time, since = count }

local function CaptureStack(err)
    local msg = tostring(err)
    if type(debugstack) ~= "function" then return msg end
    return msg .. "|n" .. debugstack(2, 6, 3)
end

function K:ReportError(detail)
    detail = tostring(detail)
    local key = detail:match("^[^\r\n|]*") or detail
    local now = (type(GetTime) == "function") and GetTime() or 0
    local seen = reported[key]

    if seen then
        seen.since = seen.since + 1
        if (now - seen.at) < REPEAT_AFTER then return end
        local suppressed = seen.since
        seen.at, seen.since = now, 0
        self:Print(("|cffff5555Error:|r %s |cff888888(%dx more since)|r"):format(detail, suppressed))
        return
    end

    reported[key] = { at = now, since = 0 }
    self:Print("|cffff5555Error:|r " .. detail)
end

function K:SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end

    local ok, a, b, c, d
    if select("#", ...) == 0 then
        -- Fast path: every call site in the addon passes a closure and no args.
        ok, a, b, c, d = xpcall(fn, CaptureStack)
    else
        -- Lua 5.1's xpcall forwards no arguments, so bind them into a closure
        -- rather than lean on a Blizzard extension that may not be there.
        local n = select("#", ...)
        local args = { ... }
        ok, a, b, c, d = xpcall(function() return fn(unpack(args, 1, n)) end, CaptureStack)
    end

    if not ok then
        self:ReportError(a)
        return nil
    end
    return a, b, c, d
end

-- ----------------------------------------------------------------------------
-- Client version
-- Read from the TOC version (120100 -> major 12) rather than the display
-- string, which is localised and inconsistently punctuated.
-- ----------------------------------------------------------------------------
function K:ClientMajorVersion()
    if type(GetBuildInfo) ~= "function" then return 0 end
    local _, _, _, rawTocVersion = GetBuildInfo()
    local tocVersion = tonumber(rawTocVersion)
    if tocVersion then return math.floor(tocVersion / 10000) end
    return 0
end

-- ----------------------------------------------------------------------------
-- Guarded event registration
-- Two runtime failures are invisible to the offline harness, and both of them
-- abort the rest of the caller's Init when they happen inline:
--
--   * the event name does not exist on this client, which raises
--     "Attempt to register unknown event"
--   * the event is protected for addons, which raises ADDON_ACTION_FORBIDDEN.
--     Midnight (12.0) made COMBAT_LOG_EVENT_UNFILTERED one of these; it took
--     out Encounter:Init before it could attach its OnEvent handler, leaving
--     five registered events with nothing listening.
--
-- Registering one at a time means a single refusal costs that one event and
-- nothing else. Refusals are recorded on the frame for /kleos status.
-- ----------------------------------------------------------------------------
function K:RegisterEvents(frame, events)
    if not frame or type(frame.RegisterEvent) ~= "function" then return {}, {} end
    local registered, refused = {}, {}
    for _, event in ipairs(events or {}) do
        local ok, err = pcall(frame.RegisterEvent, frame, event)
        if ok then
            registered[#registered + 1] = event
        else
            refused[#refused + 1] = event
            self._refusedEvents = self._refusedEvents or {}
            self._refusedEvents[event] = tostring(err)
        end
    end
    frame._kleosEvents = registered
    frame._kleosRefusedEvents = refused
    return registered, refused
end

function K:RefusedEvents()
    return self._refusedEvents or {}
end

-- Utility Functions
K.Util = K.Util or {}
function K.Util:ApplyBackdrop(f)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile="Interface/Tooltips/UI-Tooltip-Background",
        edgeFile="Interface/Tooltips/UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=14,
        insets={left=3,right=3,top=3,bottom=3}
    })
    f:SetBackdropColor(0,0,0,0.9)
end

-- ----------------------------------------------------------------------------
-- Slash command
-- ----------------------------------------------------------------------------
local SLASH_HELP = {
    "|cffffd100/kleos|r — open the window",
    "|cffffd100/kleos <text>|r — open Browse with that search",
    "|cffffd100/kleos browse|watch|tracked|excluded|specials|rewards|summary|calendar|data|r — open a tab",
    "|cffffd100/kleos settings|r, |cffffd100/kleos tutorial|r, |cffffd100/kleos reindex|r",
    "|cffffd100/kleos scan|r — scan the group for missing achievements",
    "|cffffd100/kleos announce|r — post what is being tracked to group chat",
    "|cffffd100/kleos events|r — check event reminders now",
    "|cffffd100/iat [id|watch|instance]|r — the tracker overlay",
}

local TAB_ALIASES = {
    browse = "BROWSE", watch = "WATCH", watched = "WATCH", tracked = "TRACKED",
    excluded = "EXCLUDED", specials = "CURATED", curated = "CURATED",
    rewards = "REWARDS", summary = "SUMMARY", calendar = "CALENDAR", data = "DATA",
}

local function HandleSlash(message)
    message = tostring(message or ""):match("^%s*(.-)%s*$") or ""
    local lowered = message:lower()

    if lowered == "settings" or lowered == "options" or lowered == "config" then
        if K.Settings and K.Settings.Open then K.Settings:Open() end
        return
    end
    if lowered == "help" or lowered == "?" then
        for _, line in ipairs(SLASH_HELP) do K:Print(line) end
        return
    end
    if lowered == "tutorial" then
        if K.Tutorial then K.Tutorial:Show() end
        return
    end
    if lowered == "reindex" then
        K.Catalog:Build(true)
        K:Print(("%d achievements indexed."):format(K.Catalog:Count()))
        return
    end
    if lowered == "scan" then
        K.GroupScan:Scan(nil, function(summary) K.GroupScan:AnnounceSummary(summary) end)
        return
    end
    if lowered == "announce" then
        K.Encounter:AnnounceTracked()
        return
    end
    if lowered == "events" or lowered == "reminders" then
        local fired = K.Reminders:Check(true)
        if #fired == 0 then K:Print("No events with outstanding achievements right now.") end
        return
    end
    if lowered == "status" then
        local status = K.Encounter:Status()
        K:Print(("storage=%s catalog=%d instance=%s achievements=%d mobRules=%d mobSource=%s"):format(
            tostring(K._storageBackend), K.Catalog:Count(),
            tostring(status.instanceName or "none"), status.achievements or 0,
            status.mobRules or 0, tostring(status.mobSource)))
        local refused = {}
        for event in pairs(K:RefusedEvents()) do refused[#refused + 1] = event end
        if #refused > 0 then
            table.sort(refused)
            K:Print("events this client refused: " .. table.concat(refused, ", "))
        end
        return
    end

    local tab = TAB_ALIASES[lowered]
    if tab then
        if K.UI then
            K.UI:Show()
            K.UI:SelectInternalTab(tab)
        end
        return
    end

    -- Anything else is treated as a search: /kleos loremaster
    if message ~= "" and K.UI then
        local filters = K:GetFilters()
        filters.search = message
        filters.page = 1
        K.UI:Show()
        K.UI:SelectInternalTab("BROWSE")
        local panel = K.UI.internalTabFrames and K.UI.internalTabFrames.BROWSE
        if panel and panel.search then panel.search:SetText(message) end
        return
    end

    if K.UI then K.UI:Toggle() end
end

K.HandleSlash = HandleSlash

-- Keybinding target (Bindings.xml). One entry point so the XML stays trivial.
function _G.FabledUI_Kleos_Binding(action)
    if not K._ready then return end
    action = tostring(action or ""):upper()
    if action == "TOGGLE" then
        if K.UI then K.UI:Toggle() end
    elseif action == "TRACKER" then
        if K.Tracker then K.Tracker:Toggle() end
    elseif action == "NEXTTAB" then
        if K.UI then K.UI:CycleTab(1) end
    elseif action == "PREVTAB" then
        if K.UI then K.UI:CycleTab(-1) end
    elseif action == "ANNOUNCE" then
        K.Encounter:AnnounceTracked()
    else
        local index = tonumber(action:match("TAB(%d+)"))
        if index and K.UI then K.UI:SelectTabByIndex(index) end
    end
end

-- ----------------------------------------------------------------------------
-- Startup
-- ----------------------------------------------------------------------------
local function Startup()
    -- Each stage is wrapped so a failure in one module cannot stop the rest
    -- (the slash command and the banner must register regardless).
    if K.ResolveStorage then K:SafeCall(function() K:ResolveStorage() end) end
    if K.Criteria      then K:SafeCall(function() K.Criteria:Init() end) end
    if K.Tooltip       then K:SafeCall(function() K.Tooltip:Init() end) end
    if K.Encounter     then K:SafeCall(function() K.Encounter:Init() end) end
    if K.Reminders     then K:SafeCall(function() K.Reminders:Init() end) end
    if K.Tracker       then K:SafeCall(function() K.Tracker:Init() end) end
    if K.Settings      then K:SafeCall(function() K.Settings:Register() end) end
    if K.UI            then K:SafeCall(function() K.UI:Init() end) end
    if K.UI            then K:SafeCall(function() K.UI:InitWorldMapButton() end) end
    if K.API           then K:SafeCall(function() K.API:Init() end) end

    -- The catalog is built on first use rather than at login: it is a walk over
    -- every category Blizzard exposes and nothing needs it until a panel opens.
end

local ev = CreateFrame("Frame")

-- Script first, registration second, and registration one event at a time:
-- a client that refuses one of these must not leave the frame listening with
-- nothing attached. See K:RegisterEvents above.
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if K._ready then return end
        K._ready = true

        Startup()

        SLASH_FABLEDUI_KLEOS1 = "/kleos"
        SLASH_FABLEDUI_KLEOS2 = "/kls"
        SlashCmdList["FABLEDUI_KLEOS"] = HandleSlash

        SLASH_FABLEDUI_IAT1 = "/iat"
        SlashCmdList["FABLEDUI_IAT"] = function(msg) if K.Tracker then K.Tracker:Slash(msg) end end

        K:Print(("Online v%s (%s). /kleos • /iat • /kleos help"):format(
            K.VERSION, K._storageBackend or "Unknown"))

    elseif event == "PLAYER_LOGOUT" then
        -- Flush any pending debounced SV writes before the client tears down.
        if K.Util and K.Util.Flush then K:SafeCall(function() K.Util:Flush() end) end

    elseif event == "ACHIEVEMENT_EARNED" then
        local id = ...
        if not K._ready then return end
        if K.RecordEarned then K:SafeCall(function() K:RecordEarned(id) end) end
        if K.API then K.API:Fire(K.API.EVENTS.ACHIEVEMENT_EARNED, id) end
        -- The earned achievement's row colour and the calendar index both go
        -- stale immediately, so refresh both surfaces.
        if K.Tracker and K.Tracker.Refresh then K:SafeCall(function() K.Tracker:Refresh() end) end
        if K.UI and K.UI.Refresh then K:SafeCall(function() K.UI:Refresh() end) end

    elseif event == "TRACKED_ACHIEVEMENT_LIST_CHANGED" then
        if not K._ready then return end
        if K.UI and K.UI.activeInternalTab == "TRACKED" then K:SafeCall(function() K.UI:Refresh() end) end

    else
        -- CRITERIA_EARNED / CRITERIA_UPDATE both route through Refresh, which
        -- reads self.db. Gate on K._ready so the very-early-/reload edge (event
        -- before PLAYER_LOGIN) cannot crash.
        if K._ready then
            if K.Tracker and K.Tracker.Refresh then K:SafeCall(function() K.Tracker:Refresh() end) end
            if K.UI and K.UI.IsShown and K.UI:IsShown() and K.UI.Refresh then
                K:SafeCall(function() K.UI:Refresh() end)
            end
        end
    end
end)

K.CORE_EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "ACHIEVEMENT_EARNED",
    "CRITERIA_EARNED",
    "CRITERIA_UPDATE",
    "TRACKED_ACHIEVEMENT_LIST_CHANGED",
}

K:RegisterEvents(ev, K.CORE_EVENTS)
K._coreFrame = ev
