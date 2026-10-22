local addonName, ns = ...
local O = ns.Odyssey

local Audit = {}
O.Modules.Audit = Audit

local function Colorize(level, text)
    if level == "ok" then
        return "|cff2ecc71" .. text .. "|r"
    elseif level == "warn" then
        return "|cffffd200" .. text .. "|r"
    elseif level == "bad" then
        return "|cffff5a5a" .. text .. "|r"
    end
    return text
end

local function FindTomCatAddOns()
    local hits = {}
    local addonAPI = C_AddOns
    local getNumAddOns = addonAPI and addonAPI.GetNumAddOns or GetNumAddOns
    local getAddOnInfo = addonAPI and addonAPI.GetAddOnInfo or GetAddOnInfo
    if type(getNumAddOns) ~= "function" or type(getAddOnInfo) ~= "function" then
        return hits
    end

    local okCount, total = pcall(getNumAddOns)
    if not okCount then
        total = 0
    end
    for i = 1, (total or 0) do
        -- Read the pcall results into fresh locals and narrow them to strings
        -- rather than nil-ing `name`/`title` back out. Reassigning nil over a
        -- value the analyzer has already typed as a string is what raised
        -- cast-local-type here.
        local okInfo, rawName, rawTitle = pcall(getAddOnInfo, i)
        local name = (okInfo and type(rawName) == "string") and rawName or ""
        local title = (okInfo and type(rawTitle) == "string") and rawTitle or ""
        local lowerName = string.lower(name)
        local lowerTitle = string.lower(title)
        if lowerName:find("tomcat", 1, true) or lowerTitle:find("tomcat", 1, true) then
            local isLoaded = false
            if addonAPI and type(addonAPI.IsAddOnLoaded) == "function" then
                local okLoaded, loaded = pcall(addonAPI.IsAddOnLoaded, name ~= "" and name or i)
                isLoaded = okLoaded and loaded or false
            elseif type(IsAddOnLoaded) == "function" then
                local okLoaded, loaded = pcall(IsAddOnLoaded, i)
                isLoaded = okLoaded and loaded or false
            end
            hits[#hits + 1] = {
                name = name,
                title = title,
                isLoaded = isLoaded,
            }
        end
    end
    return hits
end

function Audit:Run(popToast)
    local report = {}
    local tomCatAddOns = FindTomCatAddOns()
    local hasTomTom = TomTom and true or false
    local waypointCount = #O.db.waypoints
    local tourCount = #O.db.tours

    if #tomCatAddOns == 0 then
        report[#report + 1] = {
            level = "ok",
            head = "TomCat add-ons not detected",
            body = "No TomCat overlap found. Odyssey can fully own route and tour workflows.",
        }
    else
        report[#report + 1] = {
            level = "warn",
            head = string.format("TomCat modules detected: %d", #tomCatAddOns),
            body = "Review overlap before duplicating curated zone tour content.",
        }
        for _, entry in ipairs(tomCatAddOns) do
            report[#report + 1] = {
                level = "warn",
                head = (entry.name ~= nil and entry.name ~= "") and entry.name or (entry.title or "Unnamed add-on"),
                body = entry.isLoaded and "Loaded" or "Installed but disabled",
            }
        end
    end

    report[#report + 1] = {
        level = hasTomTom and "warn" or "ok",
        head = hasTomTom and "TomTom detected" or "TomTom not detected",
        body = hasTomTom and "Provider adapter available; Blizzard remains the internal model." or "Native Blizzard waypoint flow will be primary.",
    }

    report[#report + 1] = {
        level = waypointCount > 0 and "ok" or "warn",
        head = string.format("Waypoint inventory: %d", waypointCount),
        body = waypointCount > 0 and "Persistent waypoint service is populated." or "No waypoints stored yet.",
    }

    report[#report + 1] = {
        level = tourCount > 0 and "ok" or "warn",
        head = string.format("Tour inventory: %d", tourCount),
        body = tourCount > 0 and "Tours module is active and has data." or "No named tours stored yet.",
    }

    report[#report + 1] = {
        level = "warn",
        head = "Curated zone tours",
        body = "Still missing packaged authored route content. Current module is infrastructure-first.",
    }

    report[#report + 1] = {
        level = O.db.settings.autoAdvanceTours and "ok" or "warn",
        head = "Tour completion automation",
        body = O.db.settings.autoAdvanceTours
            and ("Arrival-based auto-advance is enabled (" .. tostring(O.db.settings.arrivalDistanceYards or 25) .. " yd threshold).")
            or "Arrival-based auto-advance is available but currently disabled in Settings.",
    }

    report[#report + 1] = {
        level = "ok",
        head = "External route API",
        body = "Waypoint, route replacement, and focus-target entry points are exposed for suite callers.",
    }

    O.db.audit.lastRun = time()
    O.db.audit.lastSummary = string.format("TomCat=%d TomTom=%s Waypoints=%d Tours=%d", #tomCatAddOns, hasTomTom and "yes" or "no", waypointCount, tourCount)
    O.db.audit.lastReport = report
    O:MarkDirty()

    if popToast and O.UI.MainFrame then
        O.UI.MainFrame:Toast("Audit complete", O.db.audit.lastSummary)
    end
end

function Audit:GetReport()
    return O.db.audit.lastReport or {}
end

function Audit:GetRenderedReport()
    local lines = {}
    for _, entry in ipairs(self:GetReport()) do
        lines[#lines + 1] = string.format("%s %s: %s", Colorize(entry.level, "*"), entry.head or "", entry.body or "")
    end
    return table.concat(lines, "\n")
end

function Audit:SetDecision(key, value)
    O.db.audit.decisions[key] = value
    O:MarkDirty()
end

function Audit:GetDecision(key)
    return O.db.audit.decisions[key]
end
