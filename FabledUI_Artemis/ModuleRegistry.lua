local A = FabledUI_Artemis or Artemis

A.Modules = A.Modules or {}
local M = A.Modules

M.providers = M.providers or {}

local ChecklistStub = { providerKey = "core-stub", moduleName = "Core Checklist Stub" }
function ChecklistStub:IsAvailable() return false end
function ChecklistStub:ToggleManualEntry(entryID)
    if not entryID or not A.character or not A.character.manualChecklistState then return end
    A.character.manualChecklistState[entryID] = not A.character.manualChecklistState[entryID]
    if A.Tracker then A.Tracker:Refresh(true) end
end
function ChecklistStub:GetEntries() return {} end

local OdysseyStub = { providerKey = "core-stub", moduleName = "Core Odyssey Stub" }
function OdysseyStub:IsAvailable() return false end
function OdysseyStub:Init() end
function OdysseyStub:GetCapabilities() return {} end
function OdysseyStub:SetQuestFocus() return false end
function OdysseyStub:ClearFocus() return false end
function OdysseyStub:PushQuest() return false end
function OdysseyStub:PushChecklist() return false end
function OdysseyStub:OpenMapForQuest() return false end

local WorldQuestStub = { providerKey = "core-stub", moduleName = "Core World Quest Stub" }
function WorldQuestStub:IsAvailable() return false end
function WorldQuestStub:CollectTasks(scan)
    if C_Map and C_Map.GetBestMapForUnit then
        scan.currentMapID = C_Map.GetBestMapForUnit("player")
    end
end
function WorldQuestStub:PassesFilters() return true end
function WorldQuestStub:GetFilterSummary()
    local filters = A.profile and A.profile.worldQuestFilters or {}
    return string.format("%s / %s%s", filters.reward or "ALL", filters.time or "ALL", filters.trackedOnly and " / tracked" or "")
end

local ObjectivesStub = { providerKey = "core-stub", moduleName = "Core Objectives Stub" }
function ObjectivesStub:IsAvailable() return false end
function ObjectivesStub:GetQuestObjectives(questID)
    return A.Util:GetQuestObjectivesRaw(questID)
end

local RewardsStub = { providerKey = "core-stub", moduleName = "Core Rewards Stub" }
function RewardsStub:IsAvailable() return false end
function RewardsStub:GetQuestRewardData(questID, questTagType)
    return A.Util:GetQuestRewardDataRaw(questID, questTagType)
end
function RewardsStub:GetQuestRewardCategory(questID, questTagType)
    local data = self:GetQuestRewardData(questID, questTagType)
    return data.category or "NONE"
end
function RewardsStub:GetRewardSummary(questID, questTagType)
    local data = self:GetQuestRewardData(questID, questTagType)
    return data.summary
end

function M:Register(kind, provider)
    if type(kind) ~= "string" or kind == "" or type(provider) ~= "table" then
        return false
    end

    self.providers[kind] = provider

    if kind == "checklist" then
        A.Checklist = provider
    elseif kind == "odyssey" then
        A.Odyssey = provider
    elseif kind == "worldQuests" then
        A.WorldQuests = provider
    elseif kind == "objectives" then
        A.Objectives = provider
    elseif kind == "rewards" then
        A.Rewards = provider
    end

    return true
end

function M:Get(kind)
    return self.providers[kind]
end

function M:IsRegistered(kind)
    return type(self.providers[kind]) == "table"
end

function M:GetProviderLabel(kind)
    local provider = self.providers[kind]
    if type(provider) ~= "table" then
        return "missing"
    end
    return provider.moduleName or provider.providerKey or kind
end

function M:GetStatus(kind)
    local provider = self.providers[kind]
    if type(provider) ~= "table" then
        return "missing"
    end

    if type(provider.IsAvailable) == "function" then
        local ok, available = pcall(provider.IsAvailable, provider)
        if ok and available then
            return "ready"
        end
    else
        return "loaded"
    end

    return "loaded"
end

function M:GetSummary()
    local summary = {}
    for _, kind in ipairs({ "checklist", "odyssey", "worldQuests", "objectives", "rewards" }) do
        summary[#summary + 1] = string.format("%s=%s", kind, self:GetStatus(kind))
    end
    return table.concat(summary, ", ")
end

A.Checklist = A.Checklist or ChecklistStub
A.Odyssey = A.Odyssey or OdysseyStub
A.WorldQuests = A.WorldQuests or WorldQuestStub
A.Objectives = A.Objectives or ObjectivesStub
A.Rewards = A.Rewards or RewardsStub

M.providers.checklist = M.providers.checklist or A.Checklist
M.providers.odyssey = M.providers.odyssey or A.Odyssey
M.providers.worldQuests = M.providers.worldQuests or A.WorldQuests
M.providers.objectives = M.providers.objectives or A.Objectives
M.providers.rewards = M.providers.rewards or A.Rewards
