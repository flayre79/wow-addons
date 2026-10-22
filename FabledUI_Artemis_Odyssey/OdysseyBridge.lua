local A = FabledUI_Artemis or Artemis
if not A or not A.Modules then
    return
end

local U = A.Util

local Odyssey = {
    providerKey = "child-odyssey",
    moduleName = "FabledUI_Artemis_Odyssey",
}

local function BuildQuestPayload(questID, objectiveIndex)
    local mapID, x, y = U:GetQuestWaypointInfo(questID)
    return {
        source = "Artemis",
        questID = questID,
        objectiveIndex = objectiveIndex,
        title = U:GetQuestTitle(questID),
        mapID = mapID,
        x = x,
        y = y,
    }
end

function Odyssey:Init()
end

function Odyssey:GetProvider()
    return _G.FabledUI_Odyssey
end

function Odyssey:IsAvailable()
    local provider = self:GetProvider()
    return type(provider) == "table"
end

function Odyssey:GetCapabilities()
    local provider = self:GetProvider()
    if type(provider) == "table" and type(provider.GetCapabilities) == "function" then
        local ok, capabilities = pcall(provider.GetCapabilities)
        if ok and type(capabilities) == "table" then
            return capabilities
        end
    end
    return {}
end

function Odyssey:SetQuestFocus(questID, objectiveIndex)
    local provider = self:GetProvider()
    if type(provider) ~= "table" or type(provider.SetFocusTarget) ~= "function" then
        return false
    end

    provider.SetFocusTarget("quest", BuildQuestPayload(questID, objectiveIndex))
    if A.profile.odysseyOpenMapOnFocus and type(provider.OpenMapToTarget) == "function" then
        provider.OpenMapToTarget("quest", BuildQuestPayload(questID, objectiveIndex))
    end
    return true
end

function Odyssey:ClearFocus()
    local provider = self:GetProvider()
    if type(provider) ~= "table" or type(provider.ClearFocusTarget) ~= "function" then
        return false
    end
    provider.ClearFocusTarget("Artemis")
    return true
end

function Odyssey:ReplaceRouteForQuest(questID)
    local provider = self:GetProvider()
    local payload = BuildQuestPayload(questID)
    if type(provider) == "table" and type(provider.ReplaceRoute) == "function" then
        provider.ReplaceRoute("Artemis", {
            { kind = "quest", payload = payload },
        })
        return true
    end
    if type(provider) == "table" and type(provider.SetFocusTarget) == "function" then
        provider.SetFocusTarget("quest", payload)
        return true
    end
    return false
end

function Odyssey:PushQuest(questID, forceMode)
    local provider = self:GetProvider()
    if type(provider) ~= "table" then
        return false
    end

    local payload = BuildQuestPayload(questID)
    local mode = forceMode or A.profile.odysseyRouteMode or "APPEND"

    if mode == "FOCUS" and type(provider.SetFocusTarget) == "function" then
        provider.SetFocusTarget("quest", payload)
        return true
    end

    if mode == "REPLACE" and self:ReplaceRouteForQuest(questID) then
        return true
    end

    if type(provider.PushRouteEntry) == "function" then
        provider.PushRouteEntry("quest", payload)
        return true
    end

    if type(provider.SetFocusTarget) == "function" then
        provider.SetFocusTarget("quest", payload)
        return true
    end

    return false
end

function Odyssey:PushChecklist(entry, forceMode)
    local provider = self:GetProvider()
    if type(provider) ~= "table" then
        return false
    end

    local payload = {
        source = "Artemis",
        entryID = entry.id,
        label = entry.label,
        questID = entry.questID,
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
    }

    local mode = forceMode or A.profile.odysseyRouteMode or "APPEND"
    if mode == "FOCUS" and type(provider.SetFocusTarget) == "function" then
        provider.SetFocusTarget(entry.questID and "quest" or "checklist", payload)
        return true
    end

    if mode == "REPLACE" and type(provider.ReplaceRoute) == "function" then
        provider.ReplaceRoute("Artemis", {
            { kind = entry.questID and "quest" or "checklist", payload = payload },
        })
        return true
    end

    if type(provider.PushRouteEntry) == "function" then
        provider.PushRouteEntry(entry.questID and "quest" or "checklist", payload)
        return true
    end

    if entry.questID and type(provider.SetFocusTarget) == "function" then
        provider.SetFocusTarget("quest", payload)
        return true
    end

    return false
end

function Odyssey:OpenMapForQuest(questID)
    local provider = self:GetProvider()
    if type(provider) ~= "table" then
        return false
    end

    if type(provider.OpenMapToTarget) == "function" then
        provider.OpenMapToTarget("quest", BuildQuestPayload(questID))
        return true
    end

    if U:OpenQuestDetails(questID) then
        return true
    end

    return false
end

A.Modules:Register("odyssey", Odyssey)
