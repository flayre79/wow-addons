local P = _G.FabledUI_Poseidon
if not P then return end

P.UI = P.UI or {}
local UI = P.UI

function UI:Init()
    if self.initialized then
        return
    end
    self.initialized = true
    self.state = self.state or {
        page = (P.settings.full and P.settings.full.selectedPage) or "overview",
        selectedNodeMapID = nil,
        selectedNodeCoordKey = nil,
    }

    self:RegisterRefreshCallbacks()
end

function UI:RegisterRefreshCallbacks()
    if self.callbacksRegistered then
        return
    end
    self.callbacksRegistered = true

    P:RegisterCallback("Poseidon.DataChanged", function()
        UI:QueueRefresh()
    end, self)
end

function UI:QueueRefresh()
    if self.refreshQueued then
        return
    end
    self.refreshQueued = true
    C_Timer.After(0.05, function()
        UI.refreshQueued = false
        if UI.hud then
            UI:RefreshHUD()
        end
        if UI.full then
            UI:RefreshFull()
        end
    end)
end

function UI:EnsureHUD()
    if not self.hud then
        self:CreateHUDWindow()
    end
    return self.hud
end

function UI:EnsureFull()
    if not self.full then
        self:CreateFullWindow()
    end
    return self.full
end

function UI:RefreshHUD()
    local frame = self:EnsureHUD()
    if not frame then
        return
    end
    self:ApplyRuntimeState(frame, P.settings.hud)
    self:RenderHUD()
end

function UI:RefreshFull()
    local frame = self:EnsureFull()
    if not frame then
        return
    end
    self:ApplyRuntimeState(frame, P.settings.full)
    self:RenderFullPage()
end

function UI:IsHUDShown()
    return self:IsWindowVisible(self.hud)
end

function UI:ShowHUD(reason)
    local frame = self:EnsureHUD()
    if not frame then
        P:Print("UIToolkit is not available, so Poseidon cannot open its HUD.")
        return
    end
    frame.__poseidonReason = reason or "manual"
    self:RefreshHUD()
    self:ShowWindow(frame)
end

function UI:HideHUD()
    self:HideWindow(self.hud)
end

function UI:ToggleHUD()
    local frame = self:EnsureHUD()
    if not frame then
        P:Print("UIToolkit is not available, so Poseidon cannot open its HUD.")
        return
    end
    self:RefreshHUD()
    self:ToggleWindow(frame)
end

function UI:ShowFull(page)
    local frame = self:EnsureFull()
    if not frame then
        P:Print("UIToolkit is not available, so Poseidon cannot open its journal.")
        return
    end

    if type(page) == "string" and page ~= "" then
        self.state.page = page
        P.settings.full.selectedPage = page
    end

    self:RefreshFull()
    self:ShowWindow(frame)
end

function UI:HideFull()
    self:HideWindow(self.full)
end

function UI:ShowNode(mapID, coordKey)
    self.state.selectedNodeMapID = mapID
    self.state.selectedNodeCoordKey = coordKey
    self:ShowFull("nodes")
end
