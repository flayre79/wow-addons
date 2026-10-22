local addonName, ns = ...

_G.FabledUI_Artemis = ns
Artemis = ns

ns.name = addonName
ns.VERSION = "2.7.0"
ns.hiddenFrame = ns.hiddenFrame or CreateFrame("Frame")
ns.hiddenFrame:Hide()

function ns:Print(...)
    print("|cff4fd1c5[Artemis]|r", ...)
end

local function HandleSlashCommand(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "toggle" then
        ns.Tracker:Toggle()
        return
    end

    if cmd == "settings" or cmd == "options" then
        if ns.Settings and ns.Settings.Open then
            ns.Settings:Open()
        end
        return
    end

    if cmd == "refresh" then
        ns.Tracker:Refresh(true)
        -- AR-003: provide chat feedback so the user knows the refresh ran.
        ns:Print("Tracker refreshed.")
        return
    end

    if cmd == "reset" then
        if ns.Tracker and ns.Tracker.ResetWindow then
            ns.Tracker:ResetWindow()
        end
        return
    end

    if cmd == "focus" then
        local questID = tonumber(rest)
        if questID then
            ns:SetFocusQuest(questID)
        else
            ns:Print("Usage: /artemis focus <questID>")
        end
        return
    end

    -- Surfaces the things that fail silently: which storage backend resolved,
    -- which child modules loaded, and any event the client refused to register.
    -- A refusal costs one event and logs nothing on its own, so without this
    -- the symptom is "a section stopped updating" and no way to see why.
    if cmd == "status" then
        ns:Print("Version " .. (ns.VERSION or "?") .. ", storage: " .. (ns._storageBackend or "Unknown"))
        ns:Print(ns.Modules and ns.Modules.GetSummary and ns.Modules:GetSummary() or "modules=unknown")

        local refused = ns.Events and ns.Events.RefusedEvents and ns.Events:RefusedEvents() or {}
        local names = {}
        for event in pairs(refused) do
            names[#names + 1] = event
        end
        table.sort(names)
        if #names > 0 then
            ns:Print("Refused events: " .. table.concat(names, ", "))
        else
            ns:Print("Refused events: none")
        end

        if ns.Recipes then
            ns:Print(string.format("Tracked recipes: %d (%s)",
                ns.Recipes:GetTrackedCount(),
                ns.Recipes:IsSectionEnabled() and "section on" or "section off"))
        end

        -- Endeavors report the RAW api count as well as the built count: an
        -- empty section is invisible (Tracker only renders itemCount > 0), so
        -- "nothing tracked" and "the API told us nothing" look identical in the
        -- tracker and have completely different fixes.
        if ns.Activities then
            local total, complete, reason = ns.Activities:GetDiagnostics()
            if reason then
                ns:Print(string.format("Traveler's Log: unavailable (%s), %d built (%s)",
                    reason,
                    ns.Activities:GetTrackedCount(),
                    ns.Activities:IsSectionEnabled() and "section on" or "section off"))
            else
                ns:Print(string.format("Traveler's Log: %d tracked (%d complete), %d built (%s, completed %s)",
                    total or 0,
                    complete or 0,
                    ns.Activities:GetTrackedCount(),
                    ns.Activities:IsSectionEnabled() and "section on" or "section off",
                    ns.profile.showCompletedObjectives and "shown" or "hidden"))
            end
        end

        if ns.Endeavors then
            local total, complete, reason = ns.Endeavors:GetDiagnostics()
            if reason then
                ns:Print(string.format("Endeavors: unavailable (%s), %d built (%s)",
                    reason,
                    ns.Endeavors:GetTrackedCount(),
                    ns.Endeavors:IsSectionEnabled() and "section on" or "section off"))
            else
                -- Built can legitimately be lower than total: completed tasks
                -- are filtered out unless "Show Completed Objectives" is on.
                ns:Print(string.format("Endeavors: %d in the initiative (%d complete), %d built (%s, completed %s)",
                    total or 0,
                    complete or 0,
                    ns.Endeavors:GetTrackedCount(),
                    ns.Endeavors:IsSectionEnabled() and "section on" or "section off",
                    ns.profile.showCompletedObjectives and "shown" or "hidden"))
            end
        end
        return
    end

    if cmd == "fontsize" then
        local value = tonumber(rest)
        if not value then
            ns:Print(string.format("Font size nudge is %+d. Usage: /artemis fontsize <-4..8>, 0 for Blizzard default.",
                tonumber(ns.profile.fontDelta) or 0))
            return
        end
        value = math.max(-4, math.min(8, math.floor(value)))
        ns.profile.fontDelta = value
        if ns.Tracker then ns.Tracker:Refresh(true) end
        ns:Print(string.format("Font size nudge set to %+d.", value))
        return
    end

    if cmd == "clearfocus" then
        ns:ClearFocusQuest()
        return
    end

    if cmd == "preset" then
        if rest and rest ~= "" then
            ns:SetActivePreset(rest:upper())
        else
            ns:Print("Presets:", table.concat(ns.DataModel:GetPresetKeys(), ", "))
        end
        return
    end

    ns:Print("Commands: /artemis, /artemis settings, /artemis status, /artemis reset, /artemis refresh, /artemis focus <questID>, /artemis clearfocus, /artemis preset <name>, /artemis fontsize <n>")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    ns:ResolveStorage()
    ns.UI = ns.Tracker

    if ns.Odyssey and ns.Odyssey.Init then
        ns.Odyssey:Init()
    end

    if ns.Tracker and ns.Tracker.Init then
        ns.Tracker:Init()
    end

    if ns.Events and ns.Events.Init then
        ns.Events:Init()
    end

    if ns.Settings and ns.Settings.Register then
        ns.Settings:Register()
    end

    SLASH_FABLEDUI_ARTEMIS1 = "/artemis"
    SlashCmdList["FABLEDUI_ARTEMIS"] = HandleSlashCommand

    local moduleSummary = ns.Modules and ns.Modules.GetSummary and ns.Modules:GetSummary() or "modules=unknown"
    ns:Print("Online (" .. (ns._storageBackend or "Unknown") .. ", " .. moduleSummary .. "). /artemis to open.")
end)
