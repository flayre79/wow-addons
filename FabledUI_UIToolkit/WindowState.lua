local T = FabledUI_UIToolkit
T.WindowState = T.WindowState or {}

local WindowState = T.WindowState

local DEFAULTS = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 960,
    height = 620,
    scale = 1,
    alpha = 1,
    displayState = "expanded",
    ribbonPoint = "TOP",
    ribbonRelativePoint = "TOP",
    ribbonX = 0,
    ribbonY = -160,
    ribbonWidth = 260,
    ribbonHeight = 24,
}

function WindowState:Ensure(state, overrides)
    if type(state) ~= "table" then
        return nil
    end

    for key, value in pairs(DEFAULTS) do
        if state[key] == nil then
            state[key] = value
        end
    end

    if type(overrides) == "table" then
        for key, value in pairs(overrides) do
            if state[key] == nil then
                state[key] = value
            end
        end
    end

    return state
end

function WindowState:Apply(frame, state)
    if not frame or type(state) ~= "table" then
        return
    end

    self:Ensure(state)

    if frame.ClearAllPoints then
        frame:ClearAllPoints()
    end
    frame:SetPoint(state.point or "CENTER", UIParent, state.relativePoint or "CENTER", state.x or 0, state.y or 0)
    if state.width and state.height then
        frame:SetSize(state.width, state.height)
    end
    if state.scale then
        frame:SetScale(state.scale)
    end
    if state.alpha then
        frame:SetAlpha(state.alpha)
    end
end

function WindowState:Capture(frame, state)
    if not frame or type(state) ~= "table" then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    state.point = point or state.point or "CENTER"
    state.relativePoint = relativePoint or state.relativePoint or "CENTER"
    state.x = x or 0
    state.y = y or 0
    state.width = math.floor(frame:GetWidth() + 0.5)
    state.height = math.floor(frame:GetHeight() + 0.5)
    state.scale = frame:GetScale()
    state.alpha = frame:GetAlpha()
end

function WindowState:ApplyRibbon(frame, state)
    if not frame or type(state) ~= "table" then
        return
    end

    self:Ensure(state)

    frame:ClearAllPoints()
    frame:SetPoint(state.ribbonPoint or "TOP", UIParent, state.ribbonRelativePoint or "TOP", state.ribbonX or 0, state.ribbonY or -160)
    frame:SetSize(state.ribbonWidth or 260, state.ribbonHeight or 24)
end

function WindowState:CaptureRibbon(frame, state)
    if not frame or type(state) ~= "table" then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    state.ribbonPoint = point or state.ribbonPoint or "TOP"
    state.ribbonRelativePoint = relativePoint or state.ribbonRelativePoint or "TOP"
    state.ribbonX = x or 0
    state.ribbonY = y or -160
    state.ribbonWidth = math.floor(frame:GetWidth() + 0.5)
    state.ribbonHeight = math.floor(frame:GetHeight() + 0.5)
end

function WindowState:GetDisplayState(state)
    if type(state) ~= "table" then
        return "expanded"
    end
    return state.displayState or "expanded"
end

function WindowState:SetDisplayState(state, displayState)
    if type(state) ~= "table" then
        return
    end
    state.displayState = displayState or "expanded"
end

function WindowState:Reset(state, overrides)
    if type(state) ~= "table" then
        return
    end

    for key in pairs(state) do
        state[key] = nil
    end

    self:Ensure(state, overrides)
end
