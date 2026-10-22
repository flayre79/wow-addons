local A = FabledUI_Artemis or Artemis

-- Scenario / instance objective tracking: delves, dungeons, raids, Mythic+,
-- scenarios, and public events all run on the C_ScenarioInfo criteria API.
-- Mirrors the lightweight entry contract the Currency section uses so the
-- tracker renderer stays simple.
A.Scenario = A.Scenario or {}
local S = A.Scenario

-- Current scenario info, or nil when the player isn't in one.
function S:GetScenarioInfo()
    if not (C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo) then
        return nil
    end
    local ok, info = pcall(C_ScenarioInfo.GetScenarioInfo)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info
    end
    return nil
end

function S:IsActive()
    return self:GetScenarioInfo() ~= nil
end

-- A short header word for the section based on the scenario type.
function S:GetSectionLabel()
    local info = self:GetScenarioInfo()
    if not info then
        return "Scenario"
    end
    local t = info.type or info.scenarioType
    local E = _G.Enum and _G.Enum.ScenarioType
    if E and t ~= nil then
        if t == E.Delve then return "Delve" end
        if t == E.Dungeon then return "Dungeon" end
        if t == E.Scenario then return "Scenario" end
        if t == E.LegionInvasion then return "Invasion" end
        if t == E.WarfrontContribution then return "Warfront" end
    end
    return "Scenario"
end

local function ReadCriteria(index)
    if not (C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo) then
        return nil
    end
    local ok, c = pcall(C_ScenarioInfo.GetCriteriaInfo, index)
    if ok and type(c) == "table" then
        return c
    end
    return nil
end

-- Build the objective entries for the current scenario step. Entry shapes:
--   { isName = true,  text = <scenario name> }
--   { isStep = true,  text = <current step title> }
--   { text = <criterion>, completed = bool, failed = bool,
--     progressPct = 0-100 + progressText,  OR  quantity/totalQuantity }
function S:BuildEntries()
    local entries = {}
    local info = self:GetScenarioInfo()
    if not info then
        return entries
    end

    local nameText = info.name
    if info.numStages and info.numStages > 1 and info.currentStage then
        nameText = string.format("%s  (Stage %d/%d)", info.name, info.currentStage, info.numStages)
    end
    entries[#entries + 1] = { id = "scenario:name", text = nameText, isName = true }

    local step
    if C_ScenarioInfo.GetScenarioStepInfo then
        local ok, s = pcall(C_ScenarioInfo.GetScenarioStepInfo)
        if ok then
            step = s
        end
    end

    if step then
        if type(step.title) == "string" and step.title ~= "" and step.title ~= info.name then
            entries[#entries + 1] = { id = "scenario:step", text = step.title, isStep = true }
        end

        local numCriteria = step.numCriteria or 0
        for i = 1, numCriteria do
            local c = ReadCriteria(i)
            if c and type(c.description) == "string" and c.description ~= "" then
                local entry = {
                    id = "scenario:crit:" .. i,
                    text = c.description,
                    completed = c.completed == true,
                    failed = c.failed == true,
                }
                if c.isWeightedProgress and c.totalQuantity and c.totalQuantity > 0 then
                    entry.progressPct = math.floor((c.quantity or 0) / c.totalQuantity * 100 + 0.5)
                    entry.progressText = c.quantityString
                elseif c.totalQuantity and c.totalQuantity > 1 then
                    entry.quantity = c.quantity or 0
                    entry.totalQuantity = c.totalQuantity
                end
                entries[#entries + 1] = entry
            end
        end
    end

    return entries
end
