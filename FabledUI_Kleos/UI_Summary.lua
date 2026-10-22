local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Summary
-- The summary view: account points, per-expansion completion, per-character
-- progress (the "Per-Character Progress" scope row) and the live instance
-- status from the encounter engine.
--
-- Per-character rows come from the snapshots Storage writes on login and on
-- each ACHIEVEMENT_EARNED, so alts appear without any inspection.
-- ============================================================================

local ROW_HEIGHT = 18

local function ExpansionRows()
    K.Catalog:Build()
    local buckets = {}
    for _, id in ipairs(K.Catalog.order) do
        local entry = K.Catalog.entries[id]
        if entry and not entry.isStatistic and not entry.isGuild then
            local key = entry.expansion or "OTHER"
            local bucket = buckets[key]
            if not bucket then
                bucket = { key = key, total = 0, earned = 0, points = 0, earnedPoints = 0 }
                buckets[key] = bucket
            end
            bucket.total = bucket.total + 1
            bucket.points = bucket.points + (entry.points or 0)
            local state = K.Catalog:GetState(id)
            if state and state.completed then
                bucket.earned = bucket.earned + 1
                bucket.earnedPoints = bucket.earnedPoints + (entry.points or 0)
            end
        end
    end

    local rows = {}
    for _, key in ipairs(K.Data.EXPANSION_ORDER) do
        if buckets[key] then rows[#rows + 1] = buckets[key] end
    end
    if buckets.OTHER then rows[#rows + 1] = buckets.OTHER end
    return rows
end

U.SummaryExpansionRows = ExpansionRows

local function CharacterRows()
    local rows = {}
    for characterKey, snapshot in pairs((K.db and K.db.characterSnapshots) or {}) do
        if type(snapshot) == "table" then
            rows[#rows + 1] = {
                character = characterKey,
                points = tonumber(snapshot.points) or 0,
                earned = tonumber(snapshot.earned) or 0,
                updated = tonumber(snapshot.updated) or 0,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        return a.character < b.character
    end)
    return rows
end

U.SummaryCharacterRows = CharacterRows

local function Builder(uiSelf, panel)
    panel.headline = W:Label(panel, "", "GameFontNormalLarge")
    panel.headline:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)

    panel.subline = W:Label(panel, "", "GameFontHighlightSmall")
    panel.subline:SetPoint("TOPLEFT", panel.headline, "BOTTOMLEFT", 0, -4)

    panel.overall = W:ProgressBar(panel, 420, 14)
    panel.overall:SetPoint("TOPLEFT", panel.subline, "BOTTOMLEFT", 0, -8)

    -- Left: expansion breakdown
    local leftPanel = W:Panel(panel)
    leftPanel:SetPoint("TOPLEFT", panel.overall, "BOTTOMLEFT", 0, -10)
    leftPanel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    leftPanel:SetWidth(430)
    panel.leftPanel = leftPanel

    panel.expansionHeader = W:Label(leftPanel, K.L.EXPANSIONS or "Expansions", "GameFontNormalSmall")
    panel.expansionHeader:SetPoint("TOPLEFT", 8, -6)

    local expansionList = W:RowList(leftPanel, { rowHeight = ROW_HEIGHT, pageSize = 40 })
    expansionList:SetPoint("TOPLEFT", panel.expansionHeader, "BOTTOMLEFT", 0, -4)
    expansionList:SetPoint("BOTTOMRIGHT", -6, 6)
    panel.expansionList = expansionList

    expansionList:SetRenderer(function(row, item)
        if not item then return end
        row.icon:SetTexture(nil)
        local name = K.Data.EXPANSION_KEY_TO_FULLNAME[item.key] or (K.L.OTHER or "Other")
        local fraction = item.total > 0 and (item.earned / item.total) or 0
        row.name:SetText(W:ProgressColor(fraction) .. name .. "|r")
        row.right:SetText(("%d/%d  |cff888888%d/%d|r"):format(item.earned, item.total, item.earnedPoints, item.points))
        row.star:SetText("")
        row:SetScript("OnClick", function()
            local filters = U.Filters()
            filters.expansion = (item.key ~= "OTHER") and item.key or "ALL"
            filters.page = 1
            U:SelectInternalTab("BROWSE")
        end)
    end)

    -- Right: characters + live status
    local rightPanel = W:Panel(panel)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 8, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    panel.rightPanel = rightPanel

    panel.characterHeader = W:Label(rightPanel, K.L.CHARACTERS or "Characters", "GameFontNormalSmall")
    panel.characterHeader:SetPoint("TOPLEFT", 8, -6)

    local characterList = W:RowList(rightPanel, { rowHeight = ROW_HEIGHT, pageSize = 40 })
    characterList:SetPoint("TOPLEFT", panel.characterHeader, "BOTTOMLEFT", 0, -4)
    characterList:SetPoint("TOPRIGHT", -6, -24)
    characterList:SetHeight(150)
    panel.characterList = characterList

    characterList:SetRenderer(function(row, item)
        if not item then return end
        row.icon:SetTexture(nil)
        local isCurrent = item.character == K:GetCharacterKey()
        row.name:SetText((isCurrent and "|cffffd100" or "|cffcccccc") .. item.character .. "|r")
        row.right:SetText(("%d %s  |cff888888%d|r"):format(item.points, K.L.POINTS or "pts", item.earned))
        row.star:SetText("")
    end)

    panel.statusHeader = W:Label(rightPanel, K.L.INSTANCE or "Instance", "GameFontNormalSmall")
    panel.statusHeader:SetPoint("TOPLEFT", characterList, "BOTTOMLEFT", 0, -10)

    panel.statusBody = W:Label(rightPanel, "", "GameFontHighlightSmall")
    panel.statusBody:SetPoint("TOPLEFT", panel.statusHeader, "BOTTOMLEFT", 0, -4)
    panel.statusBody:SetPoint("RIGHT", rightPanel, "RIGHT", -8, 0)
    if panel.statusBody.SetMaxLines then panel.statusBody:SetMaxLines(8) end

    panel.scanButton = W:Button(rightPanel, K.L.GROUP_SCAN_ACTION or "Scan Group", 130, 20, function()
        K.GroupScan:Scan(nil, function(summary)
            K.GroupScan:AnnounceSummary(summary)
            U:RenderTab("SUMMARY")
        end)
    end)
    panel.scanButton:SetPoint("BOTTOMLEFT", 8, 8)

    panel.announceButton = W:Button(rightPanel, K.L.ANNOUNCE_ACTION or "Announce", 130, 20, function()
        K.Encounter:AnnounceTracked()
    end)
    panel.announceButton:SetPoint("LEFT", panel.scanButton, "RIGHT", 6, 0)
end

local function Renderer(uiSelf, panel)
    if not panel or not panel.expansionList then return end

    local summary = K.Catalog:PointsSummary()
    panel.headline:SetText(("%s: |cffffd100%d|r / %d"):format(
        K.L.POINTS or "Points", summary.blizzardPoints > 0 and summary.blizzardPoints or summary.earnedPoints, summary.totalPoints))

    local watched, excluded, objectives = 0, 0, 0
    for _ in pairs((K.db and K.db.watchlist) or {}) do watched = watched + 1 end
    for _ in pairs((K.db and K.db.excluded) or {}) do excluded = excluded + 1 end
    for _ in pairs((K.db and K.db.customObjectives) or {}) do objectives = objectives + 1 end

    local stats = K.Catalog:Stats()
    panel.subline:SetText(("%s %d/%d  •  %s %d  •  %s %d  •  %s %d  •  %s %d"):format(
        K.L.ACHIEVEMENTS or "Achievements", summary.earned, summary.total,
        K.L.WATCH or "Watched", watched,
        K.L.EXCLUDED or "Excluded", excluded,
        K.L.HIDDEN or "Hidden", stats.hidden,
        K.L.STATISTICS or "Statistics", stats.statistics))

    panel.overall:SetProgress(summary.total > 0 and (summary.earned / summary.total) or 0,
        ("%d%%"):format(summary.total > 0 and math.floor((summary.earned / summary.total) * 100 + 0.5) or 0))

    panel.expansionList:SetItems(ExpansionRows())
    panel.characterList:SetItems(CharacterRows())

    local status = K.Encounter:Status()
    local lines = {}
    if status.inInstance then
        lines[#lines + 1] = ("%s (%s)"):format(tostring(status.instanceName or "?"), tostring(status.difficultyName or "?"))
        lines[#lines + 1] = ("%s: %d  •  %s: %d (%s)"):format(
            K.L.ACHIEVEMENTS or "Achievements", status.achievements or 0,
            K.L.MOB_RULES or "Mob rules", status.mobRules or 0,
            tostring(status.mobSource or "?"))
        if status.encounter then
            lines[#lines + 1] = ("%s: %s"):format(K.L.ENCOUNTER or "Encounter", status.encounter)
        end
    else
        lines[#lines + 1] = K.L.NOT_IN_INSTANCE or "Not in a dungeon or raid."
    end

    local lastResult = K.Encounter.state.lastResult
    if lastResult then
        if #lastResult.met > 0 then lines[#lines + 1] = "|cff00ff00+ " .. table.concat(lastResult.met, ", ") .. "|r" end
        if #lastResult.failed > 0 then lines[#lines + 1] = "|cffff5555- " .. table.concat(lastResult.failed, ", ") .. "|r" end
    end

    local scan = K.GroupScan.state and K.GroupScan:Summarise() or nil
    if scan then
        local scanLines = 0
        for achievementID, names in pairs(scan.byAchievement or {}) do
            if scanLines >= 3 then break end
            lines[#lines + 1] = ("|cffffd100%s|r: %s"):format(K.Meta.AchievementName(achievementID), table.concat(names, ", "))
            scanLines = scanLines + 1
        end
    end

    panel.statusBody:SetText(table.concat(lines, "\n"))
end

U.builders.SUMMARY = Builder
U.renderers.SUMMARY = Renderer
