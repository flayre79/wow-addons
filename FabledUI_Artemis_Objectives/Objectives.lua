local A = FabledUI_Artemis or Artemis
if not A or not A.Modules then
    return
end

local Objectives = {
    providerKey = "child-objectives",
    moduleName = "FabledUI_Artemis_Objectives",
}

function Objectives:IsAvailable()
    return type(A) == "table" and type(A.Util) == "table" and type(A.Util.GetQuestObjectivesRaw) == "function"
end

function Objectives:GetQuestObjectives(questID)
    return A.Util:GetQuestObjectivesRaw(questID)
end

A.Modules:Register("objectives", Objectives)
