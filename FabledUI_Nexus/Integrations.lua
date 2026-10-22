local N = Nexus
N.Integrations = N.Integrations or {}

function N.Integrations:SupportsMinimapLauncher()
    local LibStub = _G.LibStub
    if type(LibStub) ~= "function" then
        return false
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local Icon = LibStub("LibDBIcon-1.0", true)
    return LDB ~= nil and Icon ~= nil
end

function N.Integrations:ApplyMinimapVisibility()
    local LibStub = _G.LibStub
    if type(LibStub) ~= "function" then
        return
    end

    local Icon = LibStub("LibDBIcon-1.0", true)
    if not Icon or not N._ldb then
        return
    end

    if N.db.showMinimap then
        Icon:Show("Nexus")
    else
        Icon:Hide("Nexus")
    end
end

function N.Integrations:Init()
    local iconPath = N.NEXUS_ICON or "Interface\\Icons\\INV_Misc_Gear_01"

    local LibStub = _G.LibStub
    if type(LibStub) == "function" then
        local LDB = LibStub("LibDataBroker-1.1", true)
        local Icon = LibStub("LibDBIcon-1.0", true)
        if LDB and Icon and not N._ldb then
            N._ldb = LDB:NewDataObject("Nexus", {
                type = "launcher",
                text = "Nexus",
                icon = iconPath,
                OnClick = function(_, button)
                    if button == "RightButton" then
                        N.Registry:OpenNexusSettings()
                    else
                        N.UI:Toggle()
                    end
                end,
                OnTooltipShow = function(tt)
                    tt:AddLine("FabledUI - Nexus")
                    tt:AddLine("Left-click: Toggle Hub", 1, 1, 1)
                    tt:AddLine("Right-click: Open Settings", 1, 1, 1)
                end,
            })
            N.db.minimap = N.db.minimap or { hide = not N.db.showMinimap }
            Icon:Register("Nexus", N._ldb, N.db.minimap)
            self:ApplyMinimapVisibility()
        end
    end

    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon and not N._addonCompartmentRegistered then
        pcall(function()
            AddonCompartmentFrame:RegisterAddon({
                text = "Nexus",
                icon = iconPath,
                notCheckable = true,
                func = function(_, menuInputData)
                    if menuInputData and menuInputData.buttonName == "RightButton" then
                        N.Registry:OpenNexusSettings()
                    else
                        N.UI:Toggle()
                    end
                end,
                funcOnEnter = function(button)
                    if MenuUtil and MenuUtil.ShowTooltip then
                        MenuUtil.ShowTooltip(button, function(tooltip)
                            tooltip:SetText("FabledUI - Nexus")
                            tooltip:AddLine("Left-click: Toggle Hub", 1, 1, 1)
                            tooltip:AddLine("Right-click: Open Settings", 1, 1, 1)
                        end)
                    end
                end,
                funcOnLeave = function(button)
                    if MenuUtil and MenuUtil.HideTooltip then
                        MenuUtil.HideTooltip(button)
                    end
                end,
            })
        end)
        N._addonCompartmentRegistered = true
    end
end


