local M = _G.FabledUI_Crafty
M.Timers = M.Timers or {}
local T = M.Timers

local function FormatSeconds(seconds)
    if M.Concentration and M.Concentration.FormatTimer then
        return M.Concentration:FormatTimer(seconds)
    end
    seconds = math.max(0, tonumber(seconds) or 0)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

local READY_COLOR   = "|cff5de0b5"
local COOLING_COLOR = "|cffe0c45d"
local RESET = "|r"

function T:GetRows(professionFilter)
    local rows = {}
    for _, data in ipairs((M.Concentration and M.Concentration.GetAllRows and M.Concentration:GetAllRows()) or {}) do
        if not professionFilter or professionFilter == "ALL" or data.professionName == professionFilter then
            rows[#rows + 1] = {
                kind = "Concentration",
                characterKey = data.characterKey,
                professionName = data.professionName,
                recipeName = "",
                state = string.format("%d/%d", math.floor(data.current or 0), data.maxQuantity or 0),
                charges = "",
                nextAt = data.exactFullTime or "",
                forecastSeconds = M.Concentration:GetSecondsToTarget(data.data, tonumber(M.settings and M.settings.concentrationForecastTarget) or 1000),
                seconds = data.secondsUntilFull or 0,
                tooltip = {
                    string.format("Current: %d/%d", math.floor(data.current or 0), data.maxQuantity or 0),
                    string.format("Full in: %s", FormatSeconds(data.secondsUntilFull or 0)),
                    string.format("Full at: %s", data.exactFullTime or ""),
                },
            }
        end
    end

    for _, data in ipairs((M.Cooldowns and M.Cooldowns.GetRows and M.Cooldowns:GetRows(professionFilter)) or {}) do
        local seconds = data.seconds or 0
        local hasCharges = (data.maxCharges or 0) > 0
        local chargesAvailable = (data.charges or 0) > 0
        local stateText
        if seconds <= 0 then
            stateText = READY_COLOR .. "Ready" .. RESET
        else
            stateText = COOLING_COLOR .. "Time: " .. FormatSeconds(seconds) .. RESET
        end
        local chargesText = ""
        if hasCharges then
            local color = chargesAvailable and READY_COLOR or COOLING_COLOR
            chargesText = string.format("%s%d / %d%s", color, data.charges or 0, data.maxCharges or 0, RESET)
        end
        rows[#rows + 1] = {
            kind = "Cooldown",
            characterKey = data.characterKey,
            professionName = data.professionName,
            recipeName = data.recipeName or data.name or ("Recipe " .. tostring(data.recipeID or "?")),
            recipeID = data.recipeID,
            state = stateText,
            charges = chargesText,
            isReady = (seconds <= 0) or chargesAvailable,
            isDayCooldown = data.isDayCooldown and true or false,
            nextAt = (seconds > 0) and (data.readyAt or "") or "",
            forecastSeconds = seconds,
            seconds = seconds,
            tooltip = {
                string.format("Profession: %s", data.professionName or "Unknown"),
                string.format("Character: %s", M:GetShortCharacterName(data.characterKey)),
                hasCharges and string.format("Charges: %d / %d", data.charges or 0, data.maxCharges or 0) or "",
                (seconds > 0) and string.format("Ready in: %s", FormatSeconds(seconds)) or "Status: Ready",
                (seconds > 0) and string.format("Ready at: %s", data.readyAt or "") or "",
                data.isDayCooldown and "Daily cooldown" or "",
            },
        }
    end

    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then
            return a.kind < b.kind
        end
        if (a.seconds or 0) ~= (b.seconds or 0) then
            return (a.seconds or 0) < (b.seconds or 0)
        end
        if (a.professionName or "") ~= (b.professionName or "") then
            return (a.professionName or "") < (b.professionName or "")
        end
        return (a.recipeName or "") < (b.recipeName or "")
    end)
    return rows
end

function T:GetStatusText(target, professionFilter)
    target = tonumber(target) or tonumber(M.settings and M.settings.concentrationForecastTarget) or 1000
    local readyCount, total, nextReady = 0, 0, nil
    if M.Cooldowns and M.Cooldowns.GetSummary then
        readyCount, total, nextReady = M.Cooldowns:GetSummary(professionFilter)
    end

    local cooldownPart
    if total == 0 then
        cooldownPart = "No profession cooldowns tracked yet (open each profession to scan)."
    elseif nextReady then
        cooldownPart = string.format("%d cooldowns ready / %d tracked - next: %s in %s",
            readyCount, total,
            nextReady.recipeName or nextReady.name or ("Recipe " .. tostring(nextReady.recipeID or "?")),
            FormatSeconds(nextReady.seconds or 0))
    else
        cooldownPart = string.format("%d cooldowns ready / %d tracked - all ready", readyCount, total)
    end

    local concPart
    local best = M.Concentration and M.Concentration.GetBestTimeToTarget and M.Concentration:GetBestTimeToTarget(target, professionFilter) or nil
    if best then
        concPart = string.format("Concentration target %d: %s %s in %s",
            target, M:GetShortCharacterName(best.characterKey), best.professionName,
            (M.Concentration and M.Concentration.FormatTimer) and M.Concentration:FormatTimer(best.seconds) or FormatSeconds(best.seconds))
    else
        concPart = string.format("Concentration target %d: no profession on track yet", target)
    end

    return cooldownPart .. " | " .. concPart
end
