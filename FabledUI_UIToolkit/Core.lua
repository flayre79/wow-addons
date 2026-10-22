local addonName, ns = ...

FabledUI_UIToolkit = FabledUI_UIToolkit or {}
local T = FabledUI_UIToolkit
_G.FabledUI_UIToolkit = T

T.VERSION = "1.5.0"
T.Modules = T.Modules or {}
T.DevTools = T.DevTools or {}
T.events = T.events or CreateFrame("Frame")

local function SafeString(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

function T:Print(msg)
    print("|cffaaaaaa[FabledUI Toolkit]|r " .. SafeString(msg))
end

function T:IsAvailable()
    return true
end

function T:RegisterModule(moduleID, definition)
    if type(moduleID) ~= "string" or moduleID == "" then
        return nil
    end

    if type(definition) ~= "table" then
        definition = { object = definition }
    end

    definition.id = moduleID
    self.Modules[moduleID] = definition
    return definition
end

function T:GetModule(moduleID)
    return self.Modules[moduleID]
end

function T:RegisterDevTool(toolID, definition)
    if type(toolID) ~= "string" or toolID == "" then
        return nil
    end

    if type(definition) ~= "table" then
        definition = { object = definition }
    end

    definition.id = toolID
    definition.kind = definition.kind or "devtool"
    self.DevTools[toolID] = definition
    self:RegisterModule(toolID, definition)
    return definition
end

function T:GetDevTool(toolID)
    return self.DevTools[toolID]
end

function T:GetDevTools()
    local list = {}
    for _, definition in pairs(self.DevTools) do
        table.insert(list, definition)
    end

    table.sort(list, function(a, b)
        local aName = string.lower(a.displayName or a.title or a.id or "")
        local bName = string.lower(b.displayName or b.title or b.id or "")
        return aName < bName
    end)

    return list
end

T.events:UnregisterAllEvents()
T.events:RegisterEvent("ADDON_LOADED")
T.events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        T:Print("Online. Safe UI injection services active.")
    end
end)
