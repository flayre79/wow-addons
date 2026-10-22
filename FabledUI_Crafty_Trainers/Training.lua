
local M = _G.FabledUI_Crafty
M.Training = M.Training or {}
local T = M.Training

local EXPANSION_PREFERENCE = {
    "Midnight",
    "The War Within",
    "Dragonflight",
    "Shadowlands",
}

local function getCurrentContext()
    if M.Concentration and M.Concentration.GetOpenProfessionContext then
        return M.Concentration:GetOpenProfessionContext()
    end
    return nil
end

local function mapExpansionName(expansion)
    if expansion == "TWW" then
        return "The War Within"
    end
    return expansion
end

function T:GetGuide(profession, expansion)
    -- TrainingData lives in its own LoD shard (FabledUI_Crafty_Data_Training,
    -- ~3k LOC) — load on first lookup of any profession's trainer data.
    if not M.TrainingData and M.EnsureFeatureShardLoaded then
        M:EnsureFeatureShardLoaded("Training")
    end
    local byProfession = (M.TrainingData or {})[profession]
    if not byProfession then
        return nil
    end

    if expansion then
        local mapped = mapExpansionName(expansion)
        if byProfession[mapped] then
            return byProfession[mapped]
        end
    end

    for _, tier in ipairs(EXPANSION_PREFERENCE) do
        if byProfession[tier] then
            return byProfession[tier]
        end
    end

    return byProfession[next(byProfession)]
end

function T:GetCurrentGuide()
    local context = getCurrentContext()
    local profession = (context and context.professionName) or (M.filters and M.filters.profession ~= "ALL" and M.filters.profession) or nil
    if not profession then
        return nil
    end
    local expansion = (context and context.expansion) or (M.filters and M.filters.expansion ~= "ALL" and M.filters.expansion) or nil
    return self:GetGuide(profession, expansion)
end

function T:GetCurrentSkillForProfession(profession)
    local charData = M.Alts and M.Alts:GetCharacterData(M:GetCurrentCharacterKey()) or nil
    local profData = charData and charData.professions and charData.professions[profession] or nil
    return profData and tonumber(profData.skillLevel) or 0, profData and tonumber(profData.maxSkillLevel) or 0
end

function T:GetActiveStep(guide, skill)
    if not guide or not guide.steps then
        return nil, nil
    end
    for index, step in ipairs(guide.steps) do
        if skill >= (step.minSkill or 0) and skill <= (step.maxSkill or 999) then
            return step, index
        end
    end
    return guide.steps[#guide.steps], #guide.steps
end

function T:GetGuideSummary(profession, expansion)
    local guide = profession and self:GetGuide(profession, expansion) or self:GetCurrentGuide()
    if not guide then
        return nil
    end
    local skill, maxSkill = self:GetCurrentSkillForProfession(guide.profession)
    local activeStep, activeIndex = self:GetActiveStep(guide, skill)
    return {
        guide = guide,
        skill = skill,
        maxSkill = maxSkill,
        activeStep = activeStep,
        activeIndex = activeIndex,
        knowledgeSourceCount = #(guide.knowledgeSources or {}),
    }
end

function T:GetRows()
    local summary = self:GetGuideSummary()
    if not summary then
        return {}, "Open a tracked profession or set a profession filter to see the retail leveling guide."
    end

    local guide = summary.guide
    local rows = {}

    if M.settings.guideShowKnowledgeSources ~= false and #(guide.knowledgeSources or {}) > 0 then
        local first = guide.knowledgeSources[1]
        rows[#rows + 1] = {
            kind = "knowledge",
            skill = "Info",
            title = string.format("Knowledge support: %d source(s)", #(guide.knowledgeSources or {})),
            note = first and (first.text or first.note) or "Knowledge tips available in the Knowledge tab.",
            materials = "Use Knowledge for checklist detail.",
        }
    end

    for index, step in ipairs(guide.steps or {}) do
        if M.settings.guideShowAllSteps == true or summary.activeIndex == nil or math.abs(index - summary.activeIndex) <= 2 or step.type == "trainer" then
            local matParts = {}
            for itemName, qty in pairs(step.materials or {}) do
                matParts[#matParts + 1] = string.format("%s x%d", itemName, qty)
            end
            table.sort(matParts)
            rows[#rows + 1] = {
                kind = (index == summary.activeIndex and "active") or step.type or "step",
                skill = string.format("%d-%d", step.minSkill or 0, step.maxSkill or 0),
                title = step.text,
                note = step.note or "",
                materials = table.concat(matParts, ", "),
                isActive = index == summary.activeIndex,
            }
        end
    end

    local status = string.format("%s · %s route · current skill %d/%d", guide.profession or "Profession", guide.tier or "Retail", summary.skill or 0, guide.maxSkill or summary.maxSkill or 0)
    return rows, status
end
