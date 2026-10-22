local addonName, _ = ...
local DV = DataVault

-- ============================================================
-- DataVault Minimap Icon
-- Uses LibDataBroker-1.1 + LibDBIcon-1.0 when available.
-- The `true` flag on LibStub silently returns nil if the lib
-- is absent, so this file is safe to load unconditionally.
-- ============================================================

local function InitMinimapIcon()
    local LibStub = _G.LibStub
    if type(LibStub) ~= "function" then return end

    local LDB  = LibStub("LibDataBroker-1.1", true)
    local Icon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not Icon then return end

    if DV._minimapLDB then return end  -- already registered

    DV._minimapLDB = LDB:NewDataObject("FabledUI_DataVault", {
        type  = "launcher",
        label = "DataVault",
        icon  = "Interface\\Icons\\INV_Misc_Book_09",
        OnClick = function(_, button)
            DV:ToggleUI()
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("FabledUI DataVault")
            tt:AddLine("|cFFAAAAAAAAClick to open DataVault UI", 1, 1, 1)
        end,
    })

    -- Persist minimap icon state in the SavedVariable. The previous
    -- implementation used DV.db (a runtime-only table) which was wiped on
    -- every /reload, so user-set positions and the hide flag never stuck
    -- across sessions. DataVaultDB is the declared SavedVariable; we anchor
    -- a sub-table inside it for LibDBIcon to mutate directly.
    DataVaultDB.minimapIcon = DataVaultDB.minimapIcon or { hide = false }
    DV.db = DV.db or {}
    DV.db.minimapIcon = DataVaultDB.minimapIcon

    Icon:Register("FabledUI_DataVault", DV._minimapLDB, DataVaultDB.minimapIcon)
end

-- ============================================================
-- Toggle helper (called from slash command /dv minimap)
-- ============================================================

function DV:ToggleMinimapIcon()
    local LibStub = _G.LibStub
    if type(LibStub) ~= "function" then
        DV:Print("LibDBIcon not available — minimap icon unavailable.")
        return
    end
    local Icon = LibStub("LibDBIcon-1.0", true)
    if not Icon or not DV._minimapLDB then
        DV:Print("Minimap icon not initialised.")
        return
    end

    -- Mutate the SV-backed table directly (same reference DV.db.minimapIcon
    -- points to) so the hide flag persists across /reload.
    DataVaultDB.minimapIcon = DataVaultDB.minimapIcon or { hide = false }
    DataVaultDB.minimapIcon.hide = not DataVaultDB.minimapIcon.hide

    if DataVaultDB.minimapIcon.hide then
        Icon:Hide("FabledUI_DataVault")
        DV:Print("Minimap icon hidden.")
    else
        Icon:Show("FabledUI_DataVault")
        DV:Print("Minimap icon shown.")
    end
end

-- ============================================================
-- Hook into PLAYER_LOGIN to initialise after DB is ready
-- ============================================================

local minimapFrame = CreateFrame("Frame")
minimapFrame:RegisterEvent("PLAYER_LOGIN")
minimapFrame:SetScript("OnEvent", function()
    InitMinimapIcon()
end)
