local A = FabledUI_Artemis or Artemis

A.Classifier = A.Classifier or {}
local C = A.Classifier

local function QuestFrequencyValue(key)
    return Enum and Enum.QuestFrequency and Enum.QuestFrequency[key] or nil
end

function C:IsCurrentZoneQuest(quest, currentMapID)
    -- Exact map match.
    if quest.mapID and currentMapID and quest.mapID == currentMapID then
        return true
    end

    -- Map-lineage match: the quest's map is an ancestor or descendant of the
    -- current map (handles sub-zone granularity — e.g. standing in a sub-area
    -- whose uiMapID differs from the quest's zone map).
    if quest.mapID and currentMapID and C_Map and C_Map.GetMapInfo then
        local cursor, guard = currentMapID, 0
        while cursor and guard < 12 do
            if cursor == quest.mapID then return true end
            local info = C_Map.GetMapInfo(cursor)
            cursor = info and info.parentMapID
            guard = guard + 1
        end
        cursor, guard = quest.mapID, 0
        while cursor and guard < 12 do
            if cursor == currentMapID then return true end
            local info = C_Map.GetMapInfo(cursor)
            cursor = info and info.parentMapID
            guard = guard + 1
        end
    end

    -- Header/zone-name fallback: some areas (e.g. "Darkmoon Faire") are grouped
    -- by the quest log's sort category rather than a uiMapID. Match the quest's
    -- native header against the player's current zone/subzone text, normalising
    -- for case, a leading "The ", and whitespace (the minimap says "The Darkmoon
    -- Faire" but the header is just "Darkmoon Faire"), plus substring either way.
    local header = quest.headerTitle
    if header and header ~= "" then
        local function norm(s)
            if not s or s == "" then return nil end
            s = tostring(s):lower():gsub("^the%s+", "")
            s = s:gsub("^%s+", ""):gsub("%s+$", "")
            return s ~= "" and s or nil
        end
        local h = norm(header)
        if h then
            local zones = {}
            if GetSubZoneText then zones[#zones + 1] = GetSubZoneText() end
            if GetZoneText then zones[#zones + 1] = GetZoneText() end
            if GetMinimapZoneText then zones[#zones + 1] = GetMinimapZoneText() end
            for _, z in ipairs(zones) do
                local zn = norm(z)
                if zn and (zn == h or zn:find(h, 1, true) or h:find(zn, 1, true)) then
                    return true
                end
            end
        end
    end

    return false
end

function C:GetQuestSection(quest, scan)
    local focusQuestID = A.character.focusQuestID
    if focusQuestID and quest.questID == focusQuestID then
        return "FOCUS"
    end

    if quest.isWorldQuest and quest.timeLeftMinutes and quest.timeLeftMinutes <= 120 then
        return "EXPIRING"
    end

    if quest.isCampaign then
        return "CAMPAIGN"
    end

    if self:IsCurrentZoneQuest(quest, scan.currentMapID) then
        return "CURRENT_ZONE"
    end

    if quest.isWorldQuest then
        return "WORLD"
    end

    if quest.frequency == QuestFrequencyValue("Daily") then
        return "DAILY"
    end

    if quest.frequency == QuestFrequencyValue("Weekly") then
        return "WEEKLY"
    end

    if quest.isBonus then
        return "BONUS"
    end

    return "QUESTS"
end
