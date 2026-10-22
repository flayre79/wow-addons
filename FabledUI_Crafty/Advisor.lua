local M = _G.FabledUI_Crafty
M.Advisor = M.Advisor or {}
local A = M.Advisor

local function addRow(rows, title, detail, status, action)
    rows[#rows + 1] = {
        title = title,
        detail = detail,
        status = status,
        action = action,
    }
end

local function getOpenContext()
    if M.Concentration and M.Concentration.GetOpenProfessionContext then
        return M.Concentration:GetOpenProfessionContext()
    end
    return nil
end

local function getKnowledgeSummary(professionName, expansion)
    if M.Knowledge and M.Knowledge.GetSummary then
        return M.Knowledge:GetSummary(professionName, expansion or 'ALL')
    end
    return nil
end

local function getGuideSummary(professionName, expansion)
    if M.Training and M.Training.GetGuideSummary then
        return M.Training:GetGuideSummary(professionName, expansion)
    end
    return nil
end

local function getTrainer(professionName)
    if M.Trainers and M.Trainers.GetFirstTrainerForProfession then
        return M.Trainers:GetFirstTrainerForProfession(professionName)
    end
    return nil
end

function A:GetRows()
    local rows = {}
    local context = getOpenContext()
    local professionName = nil
    if context and context.professionName then
        professionName = context.professionName
    elseif M.filters and M.filters.profession and M.filters.profession ~= 'ALL' then
        professionName = M.filters.profession
    end

    if professionName then
        local stats = M.Recipes:GetSummaryStats(professionName)
        addRow(rows,
            professionName .. ' browser snapshot',
            string.format('Known current: %d · Alt only: %d · Unknown: %d · Ready: %d', stats.knownCurrent or 0, stats.knownAltOnly or 0, stats.unknown or 0, stats.craftable or 0),
            (stats.craftable or 0) > 0 and 'Craft-ready' or 'Needs materials',
            'Recipes')

        local expansion = 'ALL'
        if M.filters and M.filters.expansion then
            expansion = M.filters.expansion
        end
        local knowledgeSummary = getKnowledgeSummary(professionName, expansion)
        if knowledgeSummary and (knowledgeSummary.totalRows or 0) > 0 then
            addRow(rows,
                'Knowledge checklist',
                M.Knowledge:GetSummaryHeadline(knowledgeSummary),
                string.format('%d rows · %d points', knowledgeSummary.totalRows or 0, knowledgeSummary.totalPoints or 0),
                'Knowledge')
        end

        local guideExpansion = nil
        if context and context.expansion then
            guideExpansion = context.expansion
        elseif M.filters and M.filters.expansion then
            guideExpansion = M.filters.expansion
        end
        local guideSummary = getGuideSummary(professionName, guideExpansion)
        if guideSummary then
            addRow(rows,
                'Guide route',
                guideSummary.activeStep and guideSummary.activeStep.text or 'Guide available',
                string.format('%s %d/%d', guideSummary.guide.tier or 'Guide', guideSummary.skill or 0, guideSummary.guide.maxSkill or guideSummary.maxSkill or 0),
                'Guide')
        end

        local trainer = getTrainer(professionName)
        if trainer then
            addRow(rows,
                'Trainer routing',
                string.format('%s in %s at %.1f, %.1f', trainer.name, trainer.zone, trainer.x * 100, trainer.y * 100),
                trainer.expansion or 'Trainer',
                'Trainers')
        end

        local gear = nil
        if M.Gear and M.Gear.ScanOpenProfessionGear then
            gear = M.Gear:ScanOpenProfessionGear(false)
        end
        local spec = nil
        if M.Specs and M.Specs.CaptureOpenProfession then
            spec = M.Specs:CaptureOpenProfession(false)
        end
        if gear or spec then
            addRow(rows,
                'Gearing + specialization',
                string.format('%s | %s', gear and M.Gear:DescribeTotals(gear.totals) or 'No gear snapshot', spec and M.Specs:GetSummaryText(spec) or 'No specialization snapshot'),
                'Profiled',
                'Gearing')
        end
    else
        addRow(rows,
            'Open a profession',
            'Advisor is summary-only now. Open a Retail profession window for contextual guidance, then use Knowledge, Guide, Timers, or Gearing for the detailed surfaces.',
            'Waiting',
            'Open Blizzard Professions')
    end

    local queueSummary = M.Queue:GetSummary()
    addRow(rows,
        'Queue pressure',
        string.format('%d entries across %d crafter buckets with %d total crafts planned. %d recursive-planner entries active.', queueSummary.entries or 0, queueSummary.characters or 0, queueSummary.totalQuantity or 0, queueSummary.craftSimLike or 0),
        (queueSummary.entries or 0) > 0 and 'Active' or 'Idle',
        'Queue')

    local materialSummary = M.Materials:GetSummary()
    addRow(rows,
        'Shopping pressure',
        string.format('%d tracked materials · %d shortages · %d queued produced · %d missing total units.', materialSummary.totalItems or 0, materialSummary.shortageItems or 0, materialSummary.totalQueuedProduced or 0, materialSummary.totalShortage or 0),
        (materialSummary.shortageItems or 0) > 0 and 'Shopping list needed' or 'Covered',
        'Materials')

    local best = nil
    if M.Concentration and M.Concentration.GetBestCurrentCharacterSnapshot then
        best = M.Concentration:GetBestCurrentCharacterSnapshot()
    end
    if best then
        addRow(rows,
            'Best timer lane',
            string.format('%s is at %d/%d%s', best.professionName or 'Profession', math.floor(best.current or 0), best.maxQuantity or 0, (best.current or 0) < (best.maxQuantity or 0) and (' · full in ' .. M.Concentration:FormatTimer(best.secondsUntilFull)) or ' · full'),
            (best.current or 0) >= (best.maxQuantity or 0) and 'Ready now' or 'Charging',
            'Timers')
    end

    local cooldownRows = {}
    if M.Cooldowns and M.Cooldowns.GetRows then
        cooldownRows = M.Cooldowns:GetRows(M.filters and M.filters.profession) or {}
    end
    if cooldownRows[1] then
        addRow(rows,
            'Cooldown watch',
            string.format('Fastest recipe ready window: %s on %s in %s', cooldownRows[1].name or 'recipe', M:GetShortCharacterName(cooldownRows[1].characterKey), M.Concentration:FormatTimer(cooldownRows[1].seconds or 0)),
            string.format('%d cooldown row(s)', #cooldownRows),
            'Timers')
    end

    local session = nil
    if M.History and M.History.GetSessionSummary then
        session = M.History:GetSessionSummary()
    end
    if session and (session.crafts or 0) > 0 then
        addRow(rows,
            'Craft session log',
            string.format('%d crafts tracked today · %s profit · %d concentration spent.', session.crafts or 0, M.Util:MoneyToString(session.profit or 0), session.concentration or 0),
            M.settings.activityCraftLogEnabled == false and 'Disabled' or 'Tracking',
            'Data')
    end

    local displayMode = 'OFF'
    if M.Tooltip and M.Tooltip.GetDisplayMode then
        displayMode = M.Tooltip:GetDisplayMode()
    end
    addRow(rows,
        'Tooltip compositor',
        'Unified tooltip pipeline for profession use, processing hints, token metadata, and era tags.',
        displayMode,
        'Tooltips')

    return rows
end
