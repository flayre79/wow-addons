local A = FabledUI_Artemis or Artemis
if not A or not A.Modules then
    return
end

local U = A.Util

local WorldQuests = {
    providerKey = "child-worldquests",
    moduleName = "FabledUI_Artemis_WorldQuests",
}

local function QuestClassificationValue(key)
    return Enum and Enum.QuestClassification and Enum.QuestClassification[key] or nil
end

local function QuestFrequencyValue(key)
    return Enum and Enum.QuestFrequency and Enum.QuestFrequency[key] or nil
end

function WorldQuests:IsAvailable()
    return C_Map and C_Map.GetBestMapForUnit and C_TaskQuest and C_TaskQuest.GetQuestsOnMap
end

function WorldQuests:IsWorldQuest(questID, info)
    if info and (info.isTask == true or info.isWorldQuest == true) then
        return true
    end
    return U:IsWorldQuest(questID)
end

function WorldQuests:GetFilterSummary()
    local filters = A.profile and A.profile.worldQuestFilters or {}
    return string.format("%s / %s%s", filters.reward or "ALL", filters.time or "ALL", filters.trackedOnly and " / tracked" or "")
end

function WorldQuests:PassesFilters(quest)
    if not quest or not quest.isWorldQuest then
        return true
    end

    local filters = A.profile.worldQuestFilters or {}
    if filters.trackedOnly and not quest.isWatched and not A:IsQuestPinned(quest.questID) then
        return false
    end

    local rewardFilter = filters.reward or "ALL"
    if rewardFilter ~= "ALL" and (quest.rewardType or "NONE") ~= rewardFilter then
        return false
    end

    local timeFilter = filters.time or "ALL"
    local minutes = quest.timeLeftMinutes or math.huge
    if timeFilter == "LT_30" and minutes > 30 then
        return false
    elseif timeFilter == "LT_120" and minutes > 120 then
        return false
    elseif timeFilter == "LT_720" and minutes > 720 then
        return false
    elseif timeFilter == "LT_1440" and minutes > 1440 then
        return false
    end

    return true
end

function WorldQuests:CollectTasks(scan, buildQuestEntry)
    if not self:IsAvailable() then
        if C_Map and C_Map.GetBestMapForUnit then
            scan.currentMapID = C_Map.GetBestMapForUnit("player")
        end
        return
    end

    local currentMap = C_Map.GetBestMapForUnit("player")
    scan.currentMapID = currentMap
    if not currentMap then
        return
    end

    local tasks = C_TaskQuest.GetQuestsOnMap(currentMap)
    if not tasks then
        return
    end

    local watchedSet = U:BuildWatchedQuestSet()
    for _, taskInfo in ipairs(tasks) do
        local questID = taskInfo.questID
        if questID and not scan.byQuestID[questID] then
            local info = {
                questID = questID,
                title = U:GetQuestTitle(questID),
                mapID = taskInfo.mapID or currentMap,
                classification = QuestClassificationValue("WorldQuest"),
                isTask = true,
                isWorldQuest = taskInfo.questTagType ~= nil,
                isOnMap = true,
                isComplete = false,
                frequency = taskInfo.isDaily and QuestFrequencyValue("Daily") or nil,
                questTagType = taskInfo.questTagType,
            }
            local quest = buildQuestEntry(info, watchedSet, "maptask")
            if quest then
                scan.quests[#scan.quests + 1] = quest
                scan.byQuestID[quest.questID] = quest
            end
        elseif questID and scan.byQuestID[questID] then
            local quest = scan.byQuestID[questID]
            quest.isOnMap = true
            quest.questTagType = quest.questTagType or taskInfo.questTagType
            if taskInfo.isDaily and not quest.frequency then
                quest.frequency = QuestFrequencyValue("Daily") or quest.frequency
            end
            if not quest.timeLeftMinutes then
                quest.timeLeftText, quest.timeLeftMinutes = U:GetWQTimeLeft(questID)
            end
            if (quest.rewardType == nil or quest.rewardType == "NONE") and A:IsModuleEnabled("rewards") then
                quest.rewardType = U:GetQuestRewardCategory(questID, quest.questTagType)
                quest.rewardText = U:GetWQRewards(questID, quest.questTagType)
            end
        end
    end
end

A.Modules:Register("worldQuests", WorldQuests)
