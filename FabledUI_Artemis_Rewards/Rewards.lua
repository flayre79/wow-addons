local A = FabledUI_Artemis or Artemis
if not A or not A.Modules then
    return
end

local Rewards = {
    providerKey = "child-rewards",
    moduleName = "FabledUI_Artemis_Rewards",
}

function Rewards:IsAvailable()
    return type(A) == "table" and type(A.Util) == "table" and type(A.Util.GetQuestRewardDataRaw) == "function"
end

function Rewards:GetQuestRewardData(questID, questTagType)
    return A.Util:GetQuestRewardDataRaw(questID, questTagType)
end

function Rewards:GetQuestRewardCategory(questID, questTagType)
    local data = self:GetQuestRewardData(questID, questTagType)
    return data.category or "NONE"
end

function Rewards:GetRewardSummary(questID, questTagType)
    local data = self:GetQuestRewardData(questID, questTagType)
    return data.summary
end

A.Modules:Register("rewards", Rewards)
