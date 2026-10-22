local P = _G.FabledUI_Poseidon
if not P then return end

P.Minimap = P.Minimap or {}
local M = P.Minimap

function M:Init()
    if self.initialized then
        return
    end

    local LibStub = _G.LibStub
    if type(LibStub) ~= "function" then
        return
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local Icon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not Icon then
        return
    end

    self.ldb = LDB:NewDataObject("Poseidon", {
        type = "launcher",
        text = "Poseidon",
        icon = "Interface/Icons/Trade_Fishing",
        OnClick = function(_, button)
            if button == "RightButton" then
                P:OpenSettings()
            else
                P:ToggleHUD()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("FabledUI - Poseidon")
            tooltip:AddLine("Left-click: Toggle HUD", 1, 1, 1)
            tooltip:AddLine("Right-click: Settings", 1, 1, 1)
        end,
    })

    Icon:Register("Poseidon", self.ldb, P.settings.minimap)
    self.icon = Icon
    self.initialized = true

    if P.settings.minimap.hide then
        Icon:Hide("Poseidon")
    else
        Icon:Show("Poseidon")
    end
end

function M:ToggleVisibility()
    if not self.icon then
        self:Init()
    end
    if not self.icon then
        P:Print("Minimap libraries are not available.")
        return
    end

    P.settings.minimap.hide = not P.settings.minimap.hide
    if P.settings.minimap.hide then
        self.icon:Hide("Poseidon")
    else
        self.icon:Show("Poseidon")
    end
    P:MarkDirty()
end
