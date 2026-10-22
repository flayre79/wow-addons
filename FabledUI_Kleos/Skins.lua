local K = Kleos

-- ============================================================================
-- Skins
-- "ElvUI/GW2 UI Skin — enable via options."
--
-- Detection is by published global, and every call into a foreign skin API is
-- wrapped: these are third-party addons whose internals change without notice,
-- and a skin failing must never stop the window from opening.
--
-- AUTO (the default) picks whichever skin addon is loaded; NONE keeps the
-- FabledUI look even when ElvUI is installed.
-- ============================================================================

K.Skins = K.Skins or {}
local S = K.Skins

S.MODES = { "AUTO", "NONE", "ELVUI", "GW2" }

function S:Mode()
    local mode = (K.db and K.db.settings and K.db.settings.skin) or "AUTO"
    mode = tostring(mode):upper()
    for _, candidate in ipairs(self.MODES) do
        if candidate == mode then return mode end
    end
    return "AUTO"
end

function S:ElvUI()
    local elv = rawget(_G, "ElvUI")
    if type(elv) ~= "table" then return nil end
    local engine = elv[1]
    if type(engine) ~= "table" or type(engine.GetModule) ~= "function" then return nil end
    local ok, skins = pcall(engine.GetModule, engine, "Skins")
    if not ok or type(skins) ~= "table" then return nil end
    return engine, skins
end

function S:GW2()
    -- GW2 UI publishes its addon table under a couple of names depending on
    -- version; treat any of them as "installed".
    local candidates = { "GW2_ADDON", "GW2UI", "GwAddon" }
    for _, name in ipairs(candidates) do
        local value = rawget(_G, name)
        if value ~= nil then return value end
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "GW2_UI")
        if ok and loaded then return true end
    end
    return nil
end

function S:Detect()
    local mode = self:Mode()
    if mode == "NONE" then return "NONE" end
    if mode == "ELVUI" then return self:ElvUI() and "ELVUI" or "NONE" end
    if mode == "GW2" then return self:GW2() and "GW2" or "NONE" end
    if self:ElvUI() then return "ELVUI" end
    if self:GW2() then return "GW2" end
    return "NONE"
end

local function CollectButtons(frame, found, depth)
    if depth > 4 or #found > 200 then return found end
    for _, child in ipairs({ frame:GetChildren() }) do
        local objectType = child.GetObjectType and child:GetObjectType() or nil
        if objectType == "Button" then
            found[#found + 1] = child
        elseif objectType == "Frame" or objectType == "ScrollFrame" then
            CollectButtons(child, found, depth + 1)
        end
    end
    return found
end

function S:ApplyElvUI(frame)
    local engine, skins = self:ElvUI()
    if not skins then return false end

    local applied = false
    if type(skins.HandleFrame) == "function" then
        applied = pcall(skins.HandleFrame, skins, frame, true) or applied
    elseif type(skins.SetTemplate) == "function" then
        applied = pcall(skins.SetTemplate, frame, "Transparent") or applied
    end

    if type(skins.HandleButton) == "function" then
        for _, button in ipairs(CollectButtons(frame, {}, 0)) do
            pcall(skins.HandleButton, skins, button)
        end
        applied = true
    end

    self._applied = applied and "ELVUI" or self._applied
    return applied
end

function S:ApplyGW2(frame)
    -- GW2 UI has no documented public skinning entry point for foreign frames.
    -- Match its flat dark panel instead so the window does not clash.
    if not frame.SetBackdrop then return false end
    pcall(function()
        frame:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Buttons/WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.04, 0.04, 0.05, 0.94)
        frame:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
    end)
    self._applied = "GW2"
    return true
end

function S:Apply(frame)
    if not frame then return false end
    local mode = self:Detect()
    self._detected = mode
    if mode == "ELVUI" then return self:ApplyElvUI(frame) end
    if mode == "GW2" then return self:ApplyGW2(frame) end
    self._applied = "NONE"
    return false
end

function S:Reapply()
    self._applied = nil
    if K.UI and K.UI.frame then return self:Apply(K.UI.frame) end
    return false
end

function S:Status()
    return { mode = self:Mode(), detected = self._detected or self:Detect(), applied = self._applied or "NONE" }
end
