-- ============================================================================
-- FabledUI_Kleos_Encounters — criteria guidance
--
-- Loaded on demand the first time the player enters a dungeon or raid, because
-- that is the only place it is used.
--
-- What it does: turns an achievement's raw criteria into the sentence a player
-- actually needs. Blizzard's criteria strings state the target but not the
-- constraint — "Fanged Pit Viper" says nothing about the ten-second window, and
-- a timed criterion does not say when its clock starts. This module reads the
-- criteria shape (type, quantity, duration, flags) and emits the constraint.
--
-- It is derived, not authored per boss: no encounter database is shipped or
-- required, so it cannot go stale against a patch. Guidance for a specific
-- encounter can still be layered on top through
-- KleosAPI:RegisterObjectives / :RegisterTactics.
-- ============================================================================

local K = rawget(_G, "Kleos")
if not K or not K.Encounter then return end

local Guidance = {}
_G.KleosEncounterGuidance = Guidance

-- Criteria type -> the constraint that type implies. Only types whose meaning
-- is certain appear here; Criteria.lua carries the same caveat.
local TYPE_HINTS = {
    [0]  = "Kill: %s. Counted per kill, so pulls can be split unless a timer says otherwise.",
    [1]  = "Win the battleground: %s.",
    [5]  = "Reach character level %s.",
    [7]  = "Reach the required skill level.",
    [8]  = "Complete the linked achievement first: %s.",
    [27] = "Complete the quest: %s.",
    [28] = "Be hit by, or cast, the tracked spell.",
    [29] = "Cast the tracked spell.",
    [36] = "Have the item in your bags: %s.",
    [41] = "Use or consume the item: %s.",
    [43] = "Visit the area: %s.",
    [46] = "Reach the required reputation standing.",
    [69] = "Have the item equipped: %s.",
}

local MAX_STEPS = 20

local function Trim(text, limit)
    text = tostring(text or "")
    if #text <= (limit or 180) then return text end
    return text:sub(1, (limit or 180) - 3) .. "..."
end

-- One achievement -> objective rows in the shape Objectives:Register expects.
function Guidance:Build(achievementID)
    achievementID = tonumber(achievementID)
    if not achievementID then return {} end

    local steps = K.Meta:Breakdown(achievementID)
    if #steps == 0 then return {} end

    local objectives = {}
    local timed, quantityHeavy, sameTimeKills = nil, false, false

    for index, step in ipairs(steps) do
        if index > MAX_STEPS then break end

        if step.duration and step.duration > 0 then
            timed = step.duration
        end
        if step.required and step.required > 1 then
            quantityHeavy = true
            if step.criteriaType == 0 then sameTimeKills = true end
        end

        local template = TYPE_HINTS[step.criteriaType or -1]
        if template then
            local text = template:find("%%s") and template:format(Trim(step.text, 90)) or template
            objectives[#objectives + 1] = {
                text = Trim(text),
                hint = step.link and ("Click the matching step above to open it.") or nil,
                link = step.link,
            }
        end
    end

    -- Constraints that come from the criteria set as a whole rather than from
    -- one criterion. These are the ones players actually lose achievements to.
    if timed then
        table.insert(objectives, 1, {
            text = ("Timed: %d seconds. The clock starts on the first qualifying event, not on the pull — check the tracker before engaging.")
                :format(timed),
        })
    end
    if sameTimeKills then
        table.insert(objectives, 1, {
            text = "Multiple kills required: let the adds accumulate first. Kleos counts how many are up in the tracker and calls it out when the target number is alive.",
        })
    elseif quantityHeavy then
        table.insert(objectives, 1, {
            text = "This has a counted criterion. Progress carries between attempts unless the tracker shows it resetting.",
        })
    end

    local difficulty = K.Encounter.state and K.Encounter.state.difficultyName
    if difficulty and difficulty ~= "" then
        objectives[#objectives + 1] = {
            text = ("Current difficulty: %s. Criteria can differ per difficulty; the numbers above are read live from this one.")
                :format(difficulty),
        }
    end

    return objectives
end

-- Phrasing used by the announce lines, kept here so the chat wording and the
-- objective wording stay in one place.
Guidance.ANNOUNCE = {
    tracking = "tracking %s",
    met = "earned %s",
    missed = "missed %s",
    mobs = "%d/%d up",
}

K.Encounter:RegisterGuidance("criteriaShape", function(achievementID)
    return Guidance:Build(achievementID)
end)

-- A pattern-level tactic: any encounter with a timed criterion gets the same
-- warning, which is more useful than no tactics at all and never goes stale.
K.Encounter:RegisterTactics("timed", "One or more tracked criteria are on a timer — hold DPS until the tracker shows the counter.")

Guidance.LOADED = true
