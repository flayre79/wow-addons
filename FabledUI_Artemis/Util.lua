local A = FabledUI_Artemis or Artemis

A.Util = A.Util or {}
local U = A.Util

local function QuestTagTypeValue(key)
    return Enum and Enum.QuestTagType and Enum.QuestTagType[key] or nil
end

local function QuestFrequencyValue(key)
    return Enum and Enum.QuestFrequency and Enum.QuestFrequency[key] or nil
end

local CACHE_TTL = {
    MAP_NAME = 300,
    OBJECTIVES = 1,
    ITEM = 2,
    REWARD = 10,
    TIMELEFT = 15,
}

local function Now()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

function U:ColorText(text, hexColor)
    return "|c" .. (tostring(hexColor):match("^%x%x%x%x%x%x%x%x$") and hexColor or "ffffffff") .. tostring(text or "") .. "|r"
end

function U:SafeText(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return fallback or ""
end

function U:_GetCacheBucket(bucketKey)
    A.cache = A.cache or {}
    A.cache.runtime = A.cache.runtime or {}
    A.cache.runtime[bucketKey] = A.cache.runtime[bucketKey] or {}
    return A.cache.runtime[bucketKey]
end

function U:_GetCached(bucketKey, cacheKey, ttl)
    local bucket = self:_GetCacheBucket(bucketKey)
    local entry = bucket[cacheKey]
    if not entry then
        return nil
    end
    if ttl and ttl > 0 and (Now() - (entry.t or 0)) > ttl then
        bucket[cacheKey] = nil
        return nil
    end
    return entry.v
end

function U:_SetCached(bucketKey, cacheKey, value)
    local bucket = self:_GetCacheBucket(bucketKey)
    bucket[cacheKey] = {
        t = Now(),
        v = value,
    }
    return value
end

function U:IsWorldQuest(questID)
    if not questID then
        return false
    end
    if C_QuestLog and C_QuestLog.IsWorldQuest then
        return C_QuestLog.IsWorldQuest(questID) == true
    end
    return false
end

function U:IsQuestInLog(questID)
    if not questID or not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then
        return false
    end
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    return type(index) == "number" and index > 0
end

function U:GetQuestTitle(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end
    return "Quest " .. tostring(questID or "?")
end

-- Is the quest finished and ready to hand in?
--
-- C_QuestLog.GetInfo().isComplete is not a reliable answer -- it comes back nil
-- for plenty of quests that are visibly complete in the log, which is why
-- turn-in rows rendered in plain white instead of gold. Ask the dedicated APIs
-- instead, preferring ReadyForTurnIn (complete AND handable) over IsComplete
-- (objectives done), and keep the GetInfo field only as a last resort.
--
-- `info` is optional; pass the GetInfo table when the caller already has it.
function U:IsQuestComplete(questID, info)
    if not questID then
        return false
    end

    if C_QuestLog and type(C_QuestLog.ReadyForTurnIn) == "function" then
        local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questID)
        if ok and ready ~= nil then
            if ready then
                return true
            end
        end
    end

    if C_QuestLog and type(C_QuestLog.IsComplete) == "function" then
        local ok, complete = pcall(C_QuestLog.IsComplete, questID)
        if ok and complete ~= nil then
            return complete == true
        end
    end

    return type(info) == "table" and info.isComplete == true
end

function U:GetQuestObjectivesRaw(questID)
    local cached = self:_GetCached("objectives", questID, CACHE_TTL.OBJECTIVES)
    if cached then
        return cached
    end

    local out = {}
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives and questID) then
        return out
    end

    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if type(objectives) ~= "table" then
        return out
    end

    for index, objective in ipairs(objectives) do
        out[#out + 1] = {
            key = tostring(questID) .. ":" .. tostring(index),
            text = objective.text or "",
            finished = objective.finished == true,
            numFulfilled = objective.numFulfilled,
            numRequired = objective.numRequired,
            type = objective.type,
            objectiveType = objective.objectiveType,
        }
    end

    return self:_SetCached("objectives", questID, out)
end

function U:GetQuestObjectives(questID)
    if A.Objectives and type(A.Objectives.GetQuestObjectives) == "function" and A.Objectives ~= self then
        local ok, objectives = pcall(A.Objectives.GetQuestObjectives, A.Objectives, questID)
        if ok and type(objectives) == "table" then
            return objectives
        end
    end
    return self:GetQuestObjectivesRaw(questID)
end

function U:GetQuestItem(questID)
    local cached = self:_GetCached("items", questID, CACHE_TTL.ITEM)
    if cached ~= nil then
        if cached == false then
            return nil
        end
        return unpack(cached)
    end

    if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID and GetQuestLogSpecialItemInfo) then
        self:_SetCached("items", questID, false)
        return nil
    end

    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then
        self:_SetCached("items", questID, false)
        return nil
    end

    local itemName, itemTexture = GetQuestLogSpecialItemInfo(logIndex)
    if itemName and itemTexture then
        -- Resolve the itemID for the secure "item" attribute. A bare name works
        -- but is ambiguous across items sharing one, and the attribute is set
        -- once and fired by a hardware click -- not somewhere to be approximate.
        local itemID
        if C_Item and C_Item.GetItemInfoInstant then
            local ok, id = pcall(C_Item.GetItemInfoInstant, itemName)
            if ok then itemID = id end
        end
        self:_SetCached("items", questID, { itemName, itemTexture, logIndex, itemID })
        return itemName, itemTexture, logIndex, itemID
    end

    self:_SetCached("items", questID, false)
    return nil
end

-- Content-type tag (Dungeon / Raid / Group / PvP / Elite / Scenario ...) so the
-- tracker can call out quests that need group/instanced content, like the
-- Blizzard quest log does. Returns tagID, tagName, isElite.
function U:GetQuestTag(questID)
    if not questID or not (C_QuestLog and C_QuestLog.GetQuestTagInfo) then
        return nil
    end
    local cached = self:_GetCached("questTag", questID, CACHE_TTL.ITEM)
    if cached ~= nil then
        if cached == false then
            return nil
        end
        return cached.tagID, cached.tagName, cached.isElite
    end

    local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
    if ok and type(info) == "table" and (info.tagID or info.isElite) then
        self:_SetCached("questTag", questID, { tagID = info.tagID, tagName = info.tagName, isElite = info.isElite })
        return info.tagID, info.tagName, info.isElite
    end

    self:_SetCached("questTag", questID, false)
    return nil
end

-- Inline icon markup for a quest's content tag, using Blizzard's own
-- QUEST_TAG_ATLAS mapping so it matches the default quest log exactly. Returns
-- "" when the quest has no notable tag.
function U:GetQuestTagMarkup(quest)
    if not quest or type(CreateAtlasMarkup) ~= "function" or type(QUEST_TAG_ATLAS) ~= "table" then
        return ""
    end
    local atlas
    if quest.isElite and QUEST_TAG_ATLAS["ELITE"] then
        atlas = QUEST_TAG_ATLAS["ELITE"]
    elseif quest.tagID and QUEST_TAG_ATLAS[quest.tagID] then
        atlas = QUEST_TAG_ATLAS[quest.tagID]
    end
    if atlas then
        return CreateAtlasMarkup(atlas, 15, 15) .. " "
    end
    return ""
end

-- Percent (0-100) for quests whose objective is a progress bar (e.g. "Collect
-- ingredients" 70%), else nil. Only quests with a "progressbar" objective have a
-- meaningful percent, so we detect that first to avoid false 0% bars everywhere.
function U:GetQuestProgressBar(questID)
    if not questID or not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return nil
    end
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    local hasBar = false
    if objectives then
        for _, o in ipairs(objectives) do
            if o and o.type == "progressbar" then
                hasBar = true
                break
            end
        end
    end
    if not hasBar then
        return nil
    end
    local pct
    if type(GetQuestProgressBarPercent) == "function" then
        pct = GetQuestProgressBarPercent(questID)
    end
    if type(pct) == "number" then
        return math.floor(pct + 0.5)
    end
    return nil
end

function U:GetQuestCampaignID(questID)
    if C_CampaignInfo and C_CampaignInfo.GetQuestCampaignID then
        return C_CampaignInfo.GetQuestCampaignID(questID)
    end
    return nil
end

function U:GetQuestMapID(questID)
    if C_QuestLog and C_QuestLog.GetQuestUiMapID then
        return C_QuestLog.GetQuestUiMapID(questID)
    end
    return nil
end

function U:GetMapName(mapID)
    if not mapID then
        return nil
    end

    local cached = self:_GetCached("mapNames", mapID, CACHE_TTL.MAP_NAME)
    if cached ~= nil then
        return cached
    end

    if not (C_Map and C_Map.GetMapInfo) then
        return nil
    end
    local mapInfo = C_Map.GetMapInfo(mapID)
    local value = mapInfo and mapInfo.name or false
    self:_SetCached("mapNames", mapID, value)
    return value or nil
end

function U:GetQuestWaypointInfo(questID, preferredMapID)
    local mapID = preferredMapID or self:GetQuestMapID(questID)
    if not mapID and C_Map and C_Map.GetBestMapForUnit then
        mapID = C_Map.GetBestMapForUnit("player")
    end

    if not mapID then
        return nil, nil, nil
    end

    if C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        local tasks = C_TaskQuest.GetQuestsOnMap(mapID)
        if tasks then
            for _, taskInfo in ipairs(tasks) do
                if taskInfo.questID == questID then
                    return mapID, taskInfo.x, taskInfo.y
                end
            end
        end
    end

    return mapID, nil, nil
end

function U:OpenQuestDetails(questID)
    if not questID then
        return false
    end

    if type(QuestMapFrame_OpenToQuestDetails) == "function" then
        -- MapCanvas data providers can fire nil-method warnings in 12.x internally;
        -- pcall prevents propagation without affecting the actual open behaviour.
        pcall(QuestMapFrame_OpenToQuestDetails, questID)
        return true
    end

    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(questID)
        return true
    end

    return false
end

-- Super-track a quest (sets the on-screen waypoint arrow) WITHOUT opening the
-- world map. This is the WoW-standard click behavior and, unlike OpenQuestDetails,
-- it doesn't trigger a world-map data-provider refresh (which some third-party
-- map addons throw assertions during in 12.x).
function U:SuperTrackQuest(questID)
    if not questID then
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        pcall(C_QuestLog.SetSelectedQuest, questID)
    end
    return true
end

-- Is this quest the one the on-screen waypoint arrow is currently pointing at?
function U:IsSuperTracked(questID)
    if questID and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, tracked = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        return ok and tracked == questID
    end
    return false
end

-- Clear the on-screen waypoint / super-track arrow (the "direction arrow").
function U:ClearWaypoint()
    if C_SuperTrack then
        if C_SuperTrack.ClearAllSuperTracked then
            pcall(C_SuperTrack.ClearAllSuperTracked)
        elseif C_SuperTrack.SetSuperTrackedQuestID then
            pcall(C_SuperTrack.SetSuperTrackedQuestID, 0)
        end
    end
    if C_Map and C_Map.ClearUserWaypoint then
        pcall(C_Map.ClearUserWaypoint)
    end
    return true
end

function U:GetWQTimeLeft(questID)
    if not questID then
        return nil
    end

    local cached = self:_GetCached("timeLeft", questID, CACHE_TTL.TIMELEFT)
    if cached ~= nil then
        if cached == false then
            return nil
        end
        return cached.text, cached.minutes
    end

    local text, minutes
    if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftSeconds then
        local seconds = C_TaskQuest.GetQuestTimeLeftSeconds(questID)
        if type(seconds) == "number" and seconds > 0 then
            minutes = math.ceil(seconds / 60)
        end
    end

    if not minutes and C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
        local legacyMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questID)
        if type(legacyMinutes) == "number" and legacyMinutes > 0 then
            minutes = legacyMinutes
        end
    end

    if type(minutes) == "number" and minutes > 0 then
        if minutes < 60 then
            text = string.format("< %dm", minutes)
        elseif minutes < (24 * 60) then
            text = string.format("%dh", math.floor(minutes / 60))
        else
            text = string.format("%dd", math.floor(minutes / (24 * 60)))
        end
        self:_SetCached("timeLeft", questID, { text = text, minutes = minutes })
        return text, minutes
    end

    self:_SetCached("timeLeft", questID, false)
    return nil
end

function U:GetQuestRewardDataRaw(questID, questTagType)
    if not questID then
        return {
            category = "NONE",
            summary = nil,
        }
    end

    local cached = self:_GetCached("rewards", questID, CACHE_TTL.REWARD)
    if cached then
        return cached
    end

    local data = {
        category = "NONE",
        summary = nil,
        money = 0,
        currencies = {},
        items = {},
    }

    if questTagType == QuestTagTypeValue("PvP") then
        data.category = "PVP"
    elseif questTagType == QuestTagTypeValue("PetBattle") then
        data.category = "PET"
    elseif questTagType == QuestTagTypeValue("Profession") then
        data.category = "PROFESSION"
    end

    if C_QuestLog and C_QuestLog.GetQuestRewardMoney then
        local money = C_QuestLog.GetQuestRewardMoney(questID)
        if type(money) == "number" and money > 0 then
            data.money = money
            if data.category == "NONE" then
                data.category = "MONEY"
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestRewardCurrencies then
        local currencies = C_QuestLog.GetQuestRewardCurrencies(questID)
        if type(currencies) == "table" then
            for _, info in ipairs(currencies) do
                local amount = info.totalRewardAmount or info.baseRewardAmount or info.bonusRewardAmount or 0
                data.currencies[#data.currencies + 1] = {
                    texture = info.texture,
                    name = info.name,
                    amount = amount,
                }
                if data.category == "NONE" then
                    data.category = "CURRENCY"
                end
                if type(info.name) == "string" and info.name:lower():find("reputation", 1, true) then
                    data.category = "REPUTATION"
                end
            end
        end
    elseif GetNumQuestLogRewardCurrencies and GetQuestLogRewardCurrencyInfo then
        local count = GetNumQuestLogRewardCurrencies(questID) or 0
        for index = 1, count do
            local name, texture, numItems = GetQuestLogRewardCurrencyInfo(index, questID)
            data.currencies[#data.currencies + 1] = {
                texture = texture,
                name = name,
                amount = numItems or 0,
            }
            if data.category == "NONE" then
                data.category = "CURRENCY"
            end
            if type(name) == "string" and name:lower():find("reputation", 1, true) then
                data.category = "REPUTATION"
            end
        end
    end

    if GetNumQuestLogRewards and GetQuestLogRewardInfo then
        local count = GetNumQuestLogRewards(questID) or 0
        for index = 1, count do
            local name, texture, quantity = GetQuestLogRewardInfo(index, questID)
            if name and texture then
                data.items[#data.items + 1] = {
                    texture = texture,
                    name = name,
                    quantity = quantity or 1,
                }
                if data.category == "NONE" then
                    local lowerName = name:lower()
                    if lowerName:find("cache", 1, true) or lowerName:find("armor", 1, true) or lowerName:find("weapon", 1, true) then
                        data.category = "GEAR"
                    else
                        data.category = "ITEM"
                    end
                end
            end
        end
    end

    local parts = {}
    if data.money and data.money > 0 and type(GetMoneyString) == "function" then
        parts[#parts + 1] = GetMoneyString(data.money, true)
    end

    for _, info in ipairs(data.currencies) do
        if info.name and info.texture then
            parts[#parts + 1] = string.format("|T%s:0|t %s x%d", info.texture, info.name, info.amount or 0)
        end
    end

    for _, info in ipairs(data.items) do
        if info.name and info.texture then
            parts[#parts + 1] = string.format("|T%s:0|t %s x%d", info.texture, info.name, info.quantity or 1)
        end
    end

    data.summary = (#parts > 0) and table.concat(parts, "  ") or nil
    self:_SetCached("rewards", questID, data)
    return data
end

function U:GetQuestRewardData(questID, questTagType)
    if A.Rewards and type(A.Rewards.GetQuestRewardData) == "function" and A.Rewards ~= self then
        local ok, data = pcall(A.Rewards.GetQuestRewardData, A.Rewards, questID, questTagType)
        if ok and type(data) == "table" then
            return data
        end
    end
    return self:GetQuestRewardDataRaw(questID, questTagType)
end

function U:GetQuestRewardCategory(questID, questTagType)
    local rewardData = self:GetQuestRewardData(questID, questTagType)
    return rewardData.category or "NONE"
end

function U:GetWQRewards(questID, questTagType)
    local rewardData = self:GetQuestRewardData(questID, questTagType)
    return rewardData.summary
end

function U:GetQuestPrefixIcon(quest)
    if type(quest) ~= "table" then
        return ""
    end

    if quest.isPinned then
        return "|TInterface\\Common\\favoritesicon:14|t "
    end
    if quest.questTagType == QuestTagTypeValue("WorldBoss") then
        return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14|t "
    end
    if quest.questTagType == QuestTagTypeValue("PvP") then
        return "|TInterface\\Icons\\achievement_pvp_a_01:14|t "
    end
    if quest.questTagType == QuestTagTypeValue("PetBattle") then
        return "|TInterface\\Icons\\tracking_wildpet:14|t "
    end
    if quest.questTagType == QuestTagTypeValue("Profession") then
        return "|TInterface\\Icons\\trade_archaeology:14|t "
    end
    if quest.isWorldQuest then
        return "|TInterface\\Icons\\UI_WorldQuest:14|t "
    end
    if quest.frequency == QuestFrequencyValue("Daily") then
        return "|TInterface\\Icons\\inv_misc_tournaments_symbol_human:14|t "
    end
    if quest.frequency == QuestFrequencyValue("Weekly") then
        return "|TInterface\\Icons\\inv_misc_tournaments_symbol_orc:14|t "
    end
    if quest.isCampaign then
        return "|TInterface\\Icons\\questlegendary:14|t "
    end
    if quest.isImportant then
        return "|TInterface\\Common\\Indicator-Red:14|t "
    end
    if quest.isBonus then
        return "|TInterface\\Icons\\BonusEvents:14|t "
    end

    return ""
end

function U:GetRewardBadge(quest)
    if type(quest) ~= "table" then
        return nil
    end
    local labels = {
        MONEY = "Gold",
        CURRENCY = "Currency",
        ITEM = "Item",
        GEAR = "Gear",
        REPUTATION = "Rep",
        PET = "Pet",
        PVP = "PvP",
        PROFESSION = "Prof",
    }
    return labels[quest.rewardType]
end

function U:GetTrackedAchievements()
    local ids = {}
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs and Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement then
        local tracked = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
        if tracked then
            for _, id in ipairs(tracked) do
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    return ids
end

function U:UntrackAchievement(achievementID)
    if C_ContentTracking and C_ContentTracking.StopTracking and Enum and Enum.ContentTrackingType and Enum.ContentTrackingStopType then
        C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, achievementID, Enum.ContentTrackingStopType.Manual)
    end
end

function U:BuildWatchedQuestSet()
    local watched = {}
    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local watchCount = C_QuestLog.GetNumQuestWatches() or 0
        for index = 1, watchCount do
            local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
            if questID then
                watched[questID] = true
            end
        end
    end
    return watched
end

function U:CountIncompleteObjectives(objectives)
    local total = 0
    local remaining = 0
    for _, objective in ipairs(objectives or {}) do
        total = total + 1
        if not objective.finished then
            remaining = remaining + 1
        end
    end
    return total, remaining
end
