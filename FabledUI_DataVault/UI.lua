local addonName, _ = ...
local DV = DataVault

-- FableNeon cosmetic theming (guarded — no error if the toolkit is absent).
local TK = rawget(_G, "FabledUI_UIToolkit")
local FN_ACCENT = { 0.227, 0.914, 1.0, 1.0 }  -- electric cyan; DataVault is the suite backbone
local function StyleButton(b)
    if b and TK and TK.Themes and TK.Themes.StyleFlatButton then
        TK.Themes:StyleFlatButton(b, "FableNeon", FN_ACCENT)
    end
end

local uiFrame = nil

local function BuildUI()
    -- Create the main movable frame
    uiFrame = CreateFrame("Frame", "FabledUIDataVaultUI", UIParent, "BackdropTemplate")
    uiFrame:SetSize(400, 350)
    uiFrame:SetPoint("CENTER", 0, 0)
    uiFrame:SetFrameStrata("HIGH")
    uiFrame:SetToplevel(true)
    uiFrame:SetMovable(true)
    uiFrame:EnableMouse(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", uiFrame.StartMoving)
    uiFrame:SetScript("OnDragStop", uiFrame.StopMovingOrSizing)

    -- Standard 12.0 Backdrop
    uiFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    -- FableNeon dark panel skin (overrides the Blizzard dialog art above).
    if TK and TK.Themes and TK.Themes.ApplyPanel then
        TK.Themes:ApplyPanel(uiFrame, "FableNeon", FN_ACCENT)
    end

    -- Title
    local title = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("FabledUI - DataVault")
    if TK and TK.Themes and TK.Themes.ApplyTitleText then
        TK.Themes:ApplyTitleText(title, "FableNeon", FN_ACCENT)
    end

    -- Stats Text Area
    local statsText = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 20, -50)
    statsText:SetPoint("BOTTOMRIGHT", -20, 80)
    statsText:SetJustifyH("LEFT")
    statsText:SetJustifyV("TOP")
    uiFrame.statsText = statsText

    -- Checkpoint Button (Hard Save)
    local btnCheckpoint = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    btnCheckpoint:SetSize(120, 25)
    btnCheckpoint:SetPoint("BOTTOMLEFT", 20, 20)
    btnCheckpoint:SetText("Force Checkpoint")
    btnCheckpoint:SetScript("OnClick", function()
        DV:Checkpoint()
    end)
    -- Tooltip for Checkpoint
    btnCheckpoint:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Forces WoW to save all DataVault and Shard data to disk by reloading the UI.")
        GameTooltip:Show()
    end)
    btnCheckpoint:SetScript("OnLeave", function() GameTooltip:Hide() end)
    StyleButton(btnCheckpoint)

    -- Compact/Dedupe Button
    local btnCompact = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    btnCompact:SetSize(120, 25)
    btnCompact:SetPoint("LEFT", btnCheckpoint, "RIGHT", 10, 0)
    btnCompact:SetText("Compact DB")
    btnCompact:SetScript("OnClick", function()
        DV:Compact()
        DV:RefreshStats()
    end)
    StyleButton(btnCompact)

    -- Close Button
    local btnClose = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    btnClose:SetSize(80, 25)
    btnClose:SetPoint("BOTTOMRIGHT", -20, 20)
    btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function()
        uiFrame:Hide()
    end)
    StyleButton(btnClose)

    -- Lazy build: populate stats every time the window is shown so the
    -- first invocation paints fresh data instead of coming up blank.
    uiFrame:SetScript("OnShow", function()
        DV:RefreshStats()
    end)

    -- Start hidden so the OnShow handler fires on the first :Show() call.
    uiFrame:Hide()
end

function DV:RefreshStats()
    -- Allow refresh during OnShow (before IsShown reports true) so the
    -- first paint isn't blank. Only bail out if the frame doesn't exist yet.
    if not uiFrame or not uiFrame.statsText then return end

    local lines = {}
    table.insert(lines, "|cff00ccffCore Version:|r " .. tostring(DV.VERSION))
    table.insert(lines, "")
    
    table.insert(lines, "|cff00ccffActive Shards:|r")
    local shardCount = 0
    for shardKey, _ in pairs(self.shards) do
        table.insert(lines, "  - " .. shardKey .. " |cff00ff00(Connected)|r")
        shardCount = shardCount + 1
    end
    if shardCount == 0 then table.insert(lines, "  - None") end
    
    table.insert(lines, "")
    table.insert(lines, "|cff00ccffRegistered Namespaces:|r")
    local nsCount = 0
    if DataVaultDB and DataVaultDB.addons then
        for addonKey, dataBlock in pairs(DataVaultDB.addons) do
            local isDirty = self:Dirty(addonKey)
            local status = isDirty and "|cffff0000(Pending Save)|r" or "|cff00ff00(Saved)|r"
            table.insert(lines, string.format("  - %s: v%s %s", addonKey, tostring(dataBlock.schemaVersion or 1), status))
            nsCount = nsCount + 1
        end
    end
    if nsCount == 0 then table.insert(lines, "  - None") end

    uiFrame.statsText:SetText(table.concat(lines, "\n"))
end

function DV:ToggleUI()
    -- `/dv ui` is intended to OPEN the window (not flip it closed). Build it
    -- on demand if it doesn't exist yet, then always show. The OnShow handler
    -- will call RefreshStats() so the contents render immediately.
    if not uiFrame then BuildUI() end

    if uiFrame:IsShown() then
        -- Already visible: re-paint with fresh data so a second `/dv ui`
        -- behaves like a refresh rather than a no-op.
        self:RefreshStats()
    else
        uiFrame:Show()
    end
end

function DV:PrintStats()
    self:Print("DataVault Status")
    
    local shardCount = 0
    for shardKey, _ in pairs(self.shards) do shardCount = shardCount + 1 end
    self:Print("Active Shards Connected:", shardCount)
    
    local nsCount = 0
    if DataVaultDB and DataVaultDB.addons then
        for k, v in pairs(DataVaultDB.addons) do nsCount = nsCount + 1 end
    end
    self:Print("Core Namespaces:", nsCount)
end

--- Basic Deduplication / Compaction Tool
--- Cleans out empty namespaces to keep the SavedVariables file lean
function DV:Compact()
    local removed = 0
    if DataVaultDB and DataVaultDB.addons then
        for addonKey, dataBlock in pairs(DataVaultDB.addons) do
            -- If a namespace was created but has no data, purge it
            if not dataBlock.data or next(dataBlock.data) == nil then
                DataVaultDB.addons[addonKey] = nil
                removed = removed + 1
            end
        end
    end
    self:Print("Compaction complete. Purged", removed, "empty namespaces.")
end

DV.Dedupe = DV.Dedupe or {}

function DV.Dedupe:Scan()
    local report = { emptyNamespaces = {}, count = 0 }
    if DataVaultDB and DataVaultDB.addons then
        for addonKey, dataBlock in pairs(DataVaultDB.addons) do
            if type(dataBlock) == "table" and (type(dataBlock.data) ~= "table" or next(dataBlock.data) == nil) then
                report.count = report.count + 1
                report.emptyNamespaces[#report.emptyNamespaces + 1] = addonKey
            end
        end
    end
    table.sort(report.emptyNamespaces)
    return report
end

function DV.Dedupe:Compact()
    return DV:Compact()
end
