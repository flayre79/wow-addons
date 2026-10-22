local T = FabledUI_UIToolkit

T.Modules = T.Modules or {}
T.DevTools = T.DevTools or {}

function T:ForEachModule(callback)
    if type(callback) ~= "function" then
        return
    end

    local ids = {}
    for moduleID in pairs(self.Modules) do
        table.insert(ids, moduleID)
    end
    table.sort(ids)

    for _, moduleID in ipairs(ids) do
        callback(moduleID, self.Modules[moduleID])
    end
end

function T:ForEachDevTool(callback)
    if type(callback) ~= "function" then
        return
    end

    local tools = self:GetDevTools()
    for _, definition in ipairs(tools) do
        callback(definition.id, definition)
    end
end
