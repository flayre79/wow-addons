local addonName, _ = ...
Harvest = Harvest or {}
local H = Harvest
_G.FabledUI_Harvest = H

H.VERSION = "1.1.0"
-- Node-store format version. Bump only when the on-disk shape of db.nodes
-- changes, and add the matching migration in Storage.lua.
H.SCHEMA_VERSION = 1
H.nodes = {} -- In-memory cache of current zone's nodes for fast rendering

function H:Print(...)
    print("|cff33ff99[Harvest]|r", ...)
end

local ev = CreateFrame("Frame")
-- SetScript before RegisterEvent: a frame must never hold a live registration
-- with no handler attached.
ev:SetScript("OnEvent", function()
    H:ResolveStorage()
    if H.MapProvider then H.MapProvider:Init() end
    if H.RadarHUD then H.RadarHUD:Init() end
    if H.Tracker then H.Tracker:Init() end
    if H.UI then H.UI:Init() end

    H:Print("Online. Tracking layers active.")
end)
ev:RegisterEvent("PLAYER_LOGIN")

-- Slash Commands
--
-- Every branch here is reachable before PLAYER_LOGIN has run ResolveStorage --
-- a slash command typed during a slow load, or after storage failed to
-- resolve -- so nothing may assume H.db or H.settings exists. `stats` used to
-- index H.db.nodes through a `or {}` that only guarded the *inner* field, so a
-- nil H.db threw rather than reporting that storage was not ready.
SLASH_HARVEST1 = "/harvest"

function H:HandleSlash(msg)
    local cmd = string.lower(strtrim(msg or ""))

    if cmd == "export" then
        if self.IE then self.IE:OpenExport() else self:Print("IE module not loaded.") end

    elseif cmd == "import" then
        if self.IE then self.IE:OpenImport() else self:Print("IE module not loaded.") end

    elseif cmd == "" or cmd == "show" or cmd == "toggle" then
        if self.Window then self.Window:Toggle() else self:Print("UI not loaded.") end

    elseif cmd == "find" or cmd == "search" then
        if self.Window then self.Window:Open("find") else self:Print("UI not loaded.") end

    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        -- Straight to our own window; the Blizzard entry is only a proxy now.
        if self.Window then self.Window:Open("settings") else self:Print("UI not loaded.") end

    elseif cmd == "radar" then
        if not (self.settings and self.settings.radar) then
            self:Print("Settings are not ready yet.")
            return
        end
        self.settings.radar.enabled = not self.settings.radar.enabled
        if self.RadarHUD and self.RadarHUD.frame then
            self.RadarHUD.frame:SetShown(self.settings.radar.enabled)
        end
        self:Print("Radar HUD " .. (self.settings.radar.enabled and "enabled." or "disabled."))

    elseif cmd == "prune" then
        if self.IsPruneRunning and self:IsPruneRunning() then
            self:Print("Prune already in progress.")
            return
        end
        local days = (self.settings and self.settings.pruneAgeDays) or 30
        local started = self.PruneNodes and self:PruneNodes(function(count)
            self:Print(string.format("Pruned %d node(s) older than %d days.", count, days))
        end)
        if not started then
            self:Print("Nothing to prune — storage is not ready.")
        end

    elseif cmd == "stats" then
        if not (self.db and self.db.nodes) then
            self:Print("Storage is not ready yet.")
            return
        end
        local total, mapCount = 0, 0
        for _, mapNodes in pairs(self.db.nodes) do
            mapCount = mapCount + 1
            for _ in pairs(mapNodes) do total = total + 1 end
        end
        self:Print(string.format("Tracked %d nodes across %d maps. Storage: %s",
            total, mapCount, self._storageBackend or "Unknown"))

        local radar = self.RadarHUD
        if radar and radar.sessionTotal then
            self:Print(string.format("This session: %d gathered (herb %d, ore %d, lumber %d).",
                radar.sessionTotal,
                (radar.session and radar.session.herb) or 0,
                (radar.session and radar.session.ore) or 0,
                (radar.session and radar.session.lumber) or 0))
        end

    else
        self:Print("Commands: /harvest (opens) | find | settings | radar | stats | prune | export | import")
    end
end

SlashCmdList["HARVEST"] = function(msg)
    H:HandleSlash(msg)
end