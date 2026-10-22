local A = FabledUI_Artemis or Artemis
local U = A.Util

A.QuestScan = A.QuestScan or {}
local Q = A.QuestScan

local function QuestClassificationValue(key)
    return Enum and Enum.QuestClassification and Enum.QuestClassification[key] or nil
end

local function QuestFrequencyValue(key)
    return Enum and Enum.QuestFrequency and Enum.QuestFrequency[key] or nil
end

local function Now()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

-- Per-quest, because expansion is per-quest.
--
-- "Show Objectives" is the default for every row; expanding one row is an
-- explicit request for that row and must win over the default. Without the
-- questID check, clicking a quest's icon flipped it to "expanded" and then
-- rendered nothing, because the scan had never gathered its objectives -- the
-- toggle looked broken while working perfectly.
local function WantsObjectives(questID)
    -- An explicit per-quest expand wins over EVERY global switch, the module
    -- toggle included. moduleToggles.objectives ships false, so gating the
    -- expand on it meant clicking a row's icon on a fresh profile did nothing
    -- at all -- the exact symptom this whole path was added to fix. The toggle
    -- governs the default for all rows; one row is the user asking directly.
    if questID and A:IsQuestExpanded(questID) then
        return true
    end
    if not A:IsModuleEnabled("objectives") then
        return false
    end
    return A.profile.showObjectives and not A.profile.compactMode
end

local function WantsQuestItems()
    -- Gate on the module toggle only (the real Settings control). The legacy
    -- showQuestItems flag was a redundant second gate that could drift out of
    -- sync with the module and silently suppress the item buttons.
    return A:IsModuleEnabled("questItems")
end

local function WantsRewardDetails(isWorldQuest, questID)
    if A:IsModuleEnabled("rewards") then
        if isWorldQuest then
            return true
        end
        if A.profile.filterMode == "CHECKLIST" or A.profile.showChecklist == true then
            return true
        end
    end

    if questID and A.character and (A.character.focusQuestID == questID or A:IsQuestPinned(questID)) then
        return true
    end

    return false
end

local function BuildQuestEntry(info, watchedSet, source)
    local questID = info.questID
    if not questID then
        return nil
    end

    local questTagType = info.questTagType
    local isWorldQuest = (info.isTask == true) or (info.isWorldQuest == true) or (A.WorldQuests and A.WorldQuests.IsWorldQuest and A.WorldQuests:IsWorldQuest(questID, info)) or U:IsWorldQuest(questID)
    local mapID = info.mapID or U:GetQuestMapID(questID)
    local title = info.title or U:GetQuestTitle(questID)
    local campaignID = info.campaignID or U:GetQuestCampaignID(questID)
    local classification = info.classification
    local frequency = info.frequency

    if frequency == nil and C_QuestLog and C_QuestLog.GetQuestFrequency then
        frequency = C_QuestLog.GetQuestFrequency(questID)
    end

    local objectives = WantsObjectives(questID) and U:GetQuestObjectives(questID) or {}
    local itemName, itemTexture, itemID = nil, nil, nil
    if WantsQuestItems() then
        itemName, itemTexture, _, itemID = U:GetQuestItem(questID)
    end

    -- Content-type tag (Dungeon/Raid/Group/Elite/...) for the row callout.
    local tagID, tagName, isElite = U:GetQuestTag(questID)
    local progressPct = U:GetQuestProgressBar(questID)

    local timeLeftText, timeLeftMinutes = nil, nil
    if isWorldQuest and A:IsModuleEnabled("worldQuests") then
        timeLeftText, timeLeftMinutes = U:GetWQTimeLeft(questID)
    end

    local rewardType, rewardText = "NONE", nil
    if WantsRewardDetails(isWorldQuest, questID) then
        rewardType = U:GetQuestRewardCategory(questID, questTagType)
        rewardText = U:GetWQRewards(questID, questTagType)
    end

    local isCampaign = campaignID ~= nil or classification == QuestClassificationValue("Campaign")
    local isBonus = classification == QuestClassificationValue("BonusObjective")
    local isRecurring = classification == QuestClassificationValue("Recurring")
    local isImportant = classification == QuestClassificationValue("Important")

    return {
        questID = questID,
        title = title,
        source = source or "questlog",
        mapID = mapID,
        mapName = nil,
        isWatched = watchedSet[questID] == true,
        isWorldQuest = isWorldQuest,
        isCampaign = isCampaign,
        isBonus = isBonus,
        isRecurring = isRecurring,
        isImportant = isImportant,
        isPinned = A:IsQuestPinned(questID),
        classification = classification,
        campaignID = campaignID,
        frequency = frequency,
        objectives = objectives,
        itemName = itemName,
        itemTexture = itemTexture,
        itemID = itemID,
        rewardText = rewardText,
        rewardType = rewardType,
        questTagType = questTagType,
        tagID = tagID,
        tagName = tagName,
        isElite = isElite,
        progressPct = progressPct,
        headerTitle = nil, -- filled in by CollectQuestLogEntries (native log header)
        timeLeftText = timeLeftText,
        timeLeftMinutes = timeLeftMinutes,
        -- Not info.isComplete: that field is nil for many visibly-complete
        -- quests. See U:IsQuestComplete.
        isComplete = U:IsQuestComplete(questID, info),
        isOnMap = info.isOnMap == true,
    }
end

function Q:Invalidate()
    self._lastScan = nil
    self._lastStamp = nil
end

function Q:CollectQuestLogEntries(scan)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
        return
    end

    local watchedSet = U:BuildWatchedQuestSet()
    local count = C_QuestLog.GetNumQuestLogEntries() or 0

    -- Track the native quest-log header each quest sits under (zone or special
    -- category like "Dungeon"/"Raid"/"Weekly Event"/"Neighborhood") so the
    -- tracker can group exactly like Blizzard's quest log. headerOrder preserves
    -- the log's own ordering of those headers.
    scan.headerOrder = scan.headerOrder or {}
    local seenHeader = {}
    local currentHeader = nil

    for index = 1, count do
        local info = C_QuestLog.GetInfo(index)
        if info then
            if info.isHeader then
                currentHeader = info.title
                if currentHeader and not seenHeader[currentHeader] then
                    seenHeader[currentHeader] = true
                    scan.headerOrder[#scan.headerOrder + 1] = currentHeader
                end
            elseif not info.isHidden and info.questID then
                local quest = BuildQuestEntry(info, watchedSet, "questlog")
                if quest then
                    quest.headerTitle = currentHeader
                    scan.quests[#scan.quests + 1] = quest
                    scan.byQuestID[quest.questID] = quest
                end
            end
        end
    end
end

function Q:CollectCurrentMapTasks(scan)
    if not A:IsModuleEnabled("worldQuests") then
        if C_Map and C_Map.GetBestMapForUnit then
            scan.currentMapID = C_Map.GetBestMapForUnit("player")
        end
        return
    end

    if A.WorldQuests and type(A.WorldQuests.CollectTasks) == "function" then
        local ok, err = pcall(A.WorldQuests.CollectTasks, A.WorldQuests, scan, BuildQuestEntry)
        if not ok and A.Print then
            A:Print("World quest module task scan failed:", err)
        end
        return
    end

    if C_Map and C_Map.GetBestMapForUnit then
        scan.currentMapID = C_Map.GetBestMapForUnit("player")
    end
end

function Q:CollectAchievements(scan)
    scan.achievements = U:GetTrackedAchievements()
end

function Q:Run(force)
    local stamp = table.concat({
        tostring(A.profile.filterMode),
        tostring(A.profile.showObjectives),
        tostring(A.profile.compactMode),
        tostring(A.profile.showQuestItems),
        tostring(A.profile.showChecklist),
        tostring(A.profile.showWorldQuestTimers),
        tostring(A.profile.trackAchievements),
        tostring(A:IsModuleEnabled("worldQuests")),
        tostring(A:IsModuleEnabled("objectives")),
        tostring(A:IsModuleEnabled("questItems")),
        tostring(A:IsModuleEnabled("rewards")),
        tostring(A.profile.worldQuestFilters and A.profile.worldQuestFilters.reward),
        tostring(A.profile.worldQuestFilters and A.profile.worldQuestFilters.time),
        tostring(A.profile.worldQuestFilters and A.profile.worldQuestFilters.trackedOnly),
    }, ":")

    if not force and self._lastScan and self._lastStamp == stamp then
        local age = Now() - (self._lastScanAge or 0)
        if age >= 0 and age < 0.35 then
            return self._lastScan
        end
    end

    local scan = {
        quests = {},
        byQuestID = {},
        achievements = {},
        currentMapID = nil,
        currentMapName = nil,
    }

    self:CollectQuestLogEntries(scan)
    self:CollectCurrentMapTasks(scan)
    self:CollectAchievements(scan)

    if scan.currentMapID then
        scan.currentMapName = U:GetMapName(scan.currentMapID)
    end

    table.sort(scan.quests, function(a, b)
        if a.isPinned ~= b.isPinned then
            return a.isPinned == true
        end

        if a.isWorldQuest ~= b.isWorldQuest then
            return a.isWorldQuest == true
        end

        if (a.timeLeftMinutes or math.huge) ~= (b.timeLeftMinutes or math.huge) then
            return (a.timeLeftMinutes or math.huge) < (b.timeLeftMinutes or math.huge)
        end

        if a.isCampaign ~= b.isCampaign then
            return a.isCampaign == true
        end

        return (a.title or "") < (b.title or "")
    end)

    self._lastScan = scan
    self._lastStamp = stamp
    self._lastScanAge = Now()
    return scan
end
