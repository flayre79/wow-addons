local N = FabledUI_Nexus
N.UI = {}

local PAD = 4
local ROW_GAP = 4
local HEADER_H = 18
local DEFAULT_ROW_WIDTH = 176
local MIN_ROW_WIDTH = 120
local MAX_ROW_WIDTH = 280

local GROUP_COLORS = {
    Favorites = { 1.0, 0.82, 0.2 },
    Suite = { 0.25, 0.75, 1.0 },
    Widgets = { 0.5, 1.0, 0.7 },
    ["3rd-Party"] = { 0.85, 0.55, 1.0 },
}

local function SetTextureSafe(textureObject, value)
    if not textureObject then return end
    local ok = pcall(textureObject.SetTexture, textureObject, value)
    if not ok then textureObject:SetTexture(N.THIRD_PARTY_DEFAULT_ICON) end
end

local function IsCompactRow(entry)
    return entry.moduleType == "widget"
end

local function TruncateText(value, maxChars)
    value = tostring(value or "")
    maxChars = tonumber(maxChars) or 999
    if value == "" or #value <= maxChars then return value end
    return value:sub(1, math.max(1, maxChars - 3)) .. "..."
end

local function GetAddonMetadataValue(addonName, fieldName)
    if type(addonName) ~= "string" or addonName == "" then return nil end
    local value
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        value = C_AddOns.GetAddOnMetadata(addonName, fieldName)
    end
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

local function CreateHeader(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(HEADER_H)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("LEFT", 4, 0)
    btn.arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.arrow:SetPoint("RIGHT", -4, 0)
    btn.line = btn:CreateTexture(nil, "BORDER")
    btn.line:SetPoint("BOTTOMLEFT", 0, 0)
    btn.line:SetPoint("BOTTOMRIGHT", 0, 0)
    btn.line:SetHeight(1)
    btn.line:SetColorTexture(1, 1, 1, 0.08)
    return btn
end

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHeight(36)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(0, 0, 0, 0.35)

    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT", 0, 0)
    row.strip:SetPoint("BOTTOMLEFT", 0, 0)
    row.strip:SetWidth(3)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 7, 0)
    row.icon:SetSize(28, 28)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 7)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)  -- truncate long names/values with an ellipsis

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -1)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetWordWrap(false)

    row.settings = CreateFrame("Button", nil, row)
    row.settings:RegisterForClicks("LeftButtonUp")
    row.settings:SetSize(16, 16)
    row.settings:SetPoint("RIGHT", -6, 0)
    row.settings:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.settings.icon = row.settings:CreateTexture(nil, "ARTWORK")
    row.settings.icon:SetAllPoints()
    SetTextureSafe(row.settings.icon, N.SETTINGS_ICON)
    row.settings:SetAlpha(0.35)

    row.favorite = row:CreateTexture(nil, "OVERLAY")
    row.favorite:SetSize(12, 12)
    row.favorite:SetPoint("TOPRIGHT", row.settings, "TOPLEFT", -4, 2)
    row.favorite:SetTexture("Interface\\COMMON\\ReputationStar")
    row.favorite:Hide()

    row.hover = row:CreateTexture(nil, "HIGHLIGHT")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.06)
    return row
end

function N.UI:Create()
    if self.anchor then return end

    local anchor = CreateFrame("Button", "FabledUI_NexusAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(N.db.iconSize, N.db.iconSize)
    anchor:SetPoint(N.db.anchor, UIParent, N.db.anchor, N.db.x, N.db.y)
    anchor:SetFrameStrata("HIGH")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    anchor:SetBackdropColor(0, 0, 0, 0.35)

    anchor:SetScript("OnDragStart", function()
        if not N.db.locked then anchor:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local point, _, _, x, y = anchor:GetPoint()
        N.db.anchor, N.db.x, N.db.y = point, x, y
        N:MarkDirty()
    end)
    anchor:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            N.Registry:OpenNexusSettings()
        else
            self:ToggleCollapse()
        end
    end)

    anchor.icon = anchor:CreateTexture(nil, "ARTWORK")
    anchor.icon:SetAllPoints()
    SetTextureSafe(anchor.icon, N.NEXUS_ICON)
    anchor.arrow = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.arrow:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Visible settings cog beside the hub icon (in addition to right-click).
    local gear = CreateFrame("Button", nil, anchor)
    gear:SetSize(18, 18)
    gear:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    gear:SetFrameStrata("HIGH")
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetAllPoints()
    SetTextureSafe(gear.icon, "Interface\\Buttons\\UI-OptionsButton")
    gear.icon:SetVertexColor(0.32, 0.85, 1.0)
    gear:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(0.65, 1.0, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Nexus Settings")
        GameTooltip:AddLine("Open the standalone control panel.", 0.7, 0.9, 1, true)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.32, 0.85, 1.0)
        GameTooltip:Hide()
    end)
    gear:SetScript("OnClick", function() N.Registry:OpenNexusSettings() end)
    anchor.gear = gear
    self.gear = gear

    self.anchor = anchor
    self.container = CreateFrame("Frame", nil, anchor)
    self.container:SetClipsChildren(true)

    -- FableNeon wordmark header (mirrors UIToolkit Shell BRAND_WORD gradient).
    self.brand = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.brand:SetJustifyH("LEFT")
    self.brand:SetText("|cff3ae9ffF|r|cff71c9ffA|r|cff9fa9ffB|r|cffc58bffL|r|cffe273d9E|r|cffff5aa6D|r|cff615e86 / NEXUS|r")
    self.brandLine = self.container:CreateTexture(nil, "ARTWORK")
    self.brandLine:SetHeight(1)
    self.brandLine:SetColorTexture(0.32, 0.85, 1.0, 0.28)

    -- Drag-to-resize handle on the hub's right edge (manual width control).
    local grip = CreateFrame("Button", nil, self.container)
    grip:SetWidth(6)
    grip:SetPoint("TOPRIGHT", self.container, "TOPRIGHT", 0, 0)
    grip:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", 0, 0)
    grip:EnableMouse(true)
    grip:SetFrameLevel(self.container:GetFrameLevel() + 5)
    grip.bar = grip:CreateTexture(nil, "OVERLAY")
    grip.bar:SetPoint("TOPRIGHT", 0, 0)
    grip.bar:SetPoint("BOTTOMRIGHT", 0, 0)
    grip.bar:SetWidth(2)
    grip.bar:SetColorTexture(0.32, 0.85, 1.0, 0.0)
    grip:SetScript("OnEnter", function(self) self.bar:SetColorTexture(0.32, 0.85, 1.0, 0.55) end)
    grip:SetScript("OnLeave", function(self)
        if not self.dragging then self.bar:SetColorTexture(0.32, 0.85, 1.0, 0.0) end
    end)
    grip:SetScript("OnMouseDown", function(self) self.dragging = true; self.throttle = 0 end)
    grip:SetScript("OnMouseUp", function(self)
        self.dragging = false
        self.bar:SetColorTexture(0.32, 0.85, 1.0, 0.0)
        N:MarkDirty()
    end)
    grip:SetScript("OnHide", function(self) self.dragging = false end)
    grip:SetScript("OnUpdate", function(self, elapsed)
        if not self.dragging then return end
        self.throttle = (self.throttle or 0) + elapsed
        if self.throttle < 0.03 then return end
        self.throttle = 0
        local left = N.UI.container:GetLeft()
        if not left then return end
        local cx = GetCursorPosition() / (UIParent:GetEffectiveScale() or 1)
        local target = math.max(MIN_ROW_WIDTH, math.min(MAX_ROW_WIDTH, cx - left))
        if math.abs((tonumber(N.db.rowWidth) or DEFAULT_ROW_WIDTH) - target) >= 1 then
            N.db.rowWidth = target
            N.UI:Refresh()
        end
    end)
    self.grip = grip

    self.rows, self.headers = {}, {}
    self:Refresh()
end

function N.UI:ApplyLiveOptions()
    if not self.anchor then self:Create() end
    if N.Integrations and N.Integrations.ApplyMinimapVisibility then
        N.Integrations:ApplyMinimapVisibility()
    end
    self:Refresh()
end

function N.UI:ToggleCollapse()
    N.db.collapsed = not N.db.collapsed
    N:MarkDirty()
    self:Refresh()
end

function N.UI:Toggle()
    if not self.anchor then self:Create() end
    self:ToggleCollapse()
end

function N.UI:AdjustWidth(delta)
    local current = tonumber(N.db.rowWidth) or DEFAULT_ROW_WIDTH
    N.db.rowWidth = math.max(MIN_ROW_WIDTH, math.min(MAX_ROW_WIDTH, current + delta))
    N:MarkDirty()
    self:Refresh()
end

function N.UI:ShowHeaderMenu(header, groupName)
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(header, function(_, root)
        root:CreateTitle(groupName)
        root:CreateButton(N.Registry:IsGroupCollapsed(groupName) and "Expand Group" or "Collapse Group", function()
            N.Registry:ToggleGroupCollapsed(groupName)
            N.UI:Refresh()
        end)
        root:CreateButton("Open Nexus Settings", function() N.Registry:OpenNexusSettings() end)
    end)
end

function N.UI:ShowRowMenu(row, entry)
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(entry.label or entry.id)
        root:CreateButton("Open", function() N.Registry:ExecuteToggle(entry) end)
        if entry.showSettingsButton then
            root:CreateButton("Open Settings", function() N.Registry:ExecuteSettings(entry) end)
        end
        if entry.moduleType ~= "widget" then
            root:CreateButton(entry.isFavorite and "Unpin from Favorites" or "Pin to Favorites", function()
                N.Registry:ToggleFavorite(entry.key)
                N.UI:Refresh()
            end)
        end
        if entry.moduleType == "custom" then
            root:CreateButton("Remove from Nexus", function()
                N.Registry:RemoveCustomAddon(entry.id)
                N.UI:Refresh()
                if N.Settings then N.Settings:RefreshManualList() end
            end)
        end
    end)
end

function N.UI:GetStripColor(entry)
    if entry.installationState == "missing" then return 0.85, 0.25, 0.25 end
    local c = GROUP_COLORS[entry.group or entry.baseGroup or "Suite"] or { 0.75, 0.75, 0.75 }
    return c[1], c[2], c[3]
end

function N.UI:ApplyRow(row, entry, width)
    local compact = IsCompactRow(entry)
    local rowH = compact and 22 or (N.db.showDescriptions and 36 or 26)
    local iconSize = compact and 16 or math.min(28, N.db.iconSize)
    row.entry = entry
    row:SetSize(width, rowH)
    row.icon:SetSize(iconSize, iconSize)
    row.icon:SetPoint("LEFT", 7, 0)
    SetTextureSafe(row.icon, entry.icon)
    local sr, sg, sb = self:GetStripColor(entry)
    row.strip:SetColorTexture(sr, sg, sb, 0.95)
    row.settings:SetShown(N.db.showSettings and entry.showSettingsButton)
    row.settings:SetSize(math.max(14, N.db.settingsIconSize), math.max(14, N.db.settingsIconSize))
    row.settings:SetAlpha(0.45)
    row.settings:SetScript("OnClick", function() N.Registry:ExecuteSettings(entry) end)
    row.favorite:SetShown(entry.isFavorite)

    if compact then
        row.label:SetFontObject("GameFontNormalSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)  -- widget rows have no cog/star: use full width
        row.label:SetText(N.Widgets and N.Widgets:GetText(entry) or entry.label)
        row.meta:Hide()
    else
        local yoff = N.db.showDescriptions and 7 or 0
        row.label:SetFontObject("GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, yoff)
        row.label:SetPoint("RIGHT", row.favorite, "LEFT", -4, yoff)  -- stop before the star/cog cluster
        row.label:SetText(entry.label or entry.id)
        if N.db.showDescriptions then
            local meta = entry.desc or entry.launchMethod or ""
            if tostring(N.db.descriptionMode or "SHORT"):upper() == "SHORT" then
                meta = TruncateText(meta, 36)
            end
            row.meta:SetPoint("RIGHT", row.favorite, "LEFT", -4, 0)
            row.meta:SetText(meta)
            row.meta:Show()
        else
            row.meta:Hide()
        end
    end

    -- Widget rows support mouse-wheel adjustment (e.g. volume ±5%).
    if entry.moduleType == "widget" then
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            if N.Widgets and N.Widgets:HandleScroll(entry, delta) then
                N.UI:Refresh()
            end
        end)
    else
        row:EnableMouseWheel(false)
        row:SetScript("OnMouseWheel", nil)
    end

    row:SetScript("OnEnter", function(self)
        self.settings:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.label or entry.id)
        if entry.desc then GameTooltip:AddLine(entry.desc, 0.85, 0.85, 0.85, true) end
        if entry.moduleType == "widget" and N.Widgets then
            GameTooltip:AddLine(N.Widgets:GetText(entry), 0.5, 1, 0.8, true)
            GameTooltip:AddLine("Left-click: widget action or refresh", 0.6, 0.9, 1)
            if entry.id == "widget_volume" then
                GameTooltip:AddLine("Right-click: mute / unmute", 0.6, 0.9, 1)
            end
        else
            local versionText = GetAddonMetadataValue(entry.addon, "Version") or "Unknown"
            local interfaceText = GetAddonMetadataValue(entry.addon, "Interface")
            GameTooltip:AddLine("Version: " .. versionText, 0.85, 0.85, 0.85)
            if interfaceText then GameTooltip:AddLine("Interface: " .. interfaceText, 0.7, 0.7, 0.7) end
            GameTooltip:AddLine("Launch: " .. tostring(entry.launchMethod or "None"), 0.6, 0.9, 1)
            GameTooltip:AddLine("Settings: " .. tostring(entry.settingsMethod or "None"), 0.6, 1, 0.7)
            GameTooltip:AddLine(entry.installed and "Installed" or "Missing", entry.installed and 0.3 or 1, entry.installed and 1 or 0.3, 0.3)
            GameTooltip:AddLine("Right-click: more actions", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.settings:SetAlpha(0.45)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if entry.moduleType == "widget" and N.Widgets and N.Widgets:HandleClick(entry, button) then
                N.UI:Refresh(); return
            end
            N.UI:ShowRowMenu(self, entry)
            return
        end
        if entry.moduleType == "widget" then
            if N.Widgets and N.Widgets:HandleClick(entry, button) then N.UI:Refresh() end
        else
            N.Registry:ExecuteToggle(entry)
        end
    end)
    row:Show()
end

function N.UI:Refresh()
    if not self.anchor then return end
    self.anchor:SetSize(N.db.iconSize, N.db.iconSize)
    SetTextureSafe(self.anchor.icon, N.NEXUS_ICON)
    if N.db.collapsed then
        self.anchor.arrow:SetText("+")
        self.container:Hide()
        return
    end
    self.anchor.arrow:SetText("-")
    self.container:Show()

    local width = N.db.showNames and (tonumber(N.db.rowWidth) or DEFAULT_ROW_WIDTH) or (N.db.iconSize + 14)
    self.container:ClearAllPoints()
    self.container:SetPoint("TOPLEFT", self.anchor, "BOTTOMLEFT", 0, -PAD)

    local y = 0
    if self.brand and N.db.showNames ~= false then
        self.brand:ClearAllPoints()
        self.brand:SetPoint("TOPLEFT", self.container, "TOPLEFT", 6, -3)
        self.brand:Show()
        self.brandLine:ClearAllPoints()
        self.brandLine:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -20)
        self.brandLine:SetPoint("TOPRIGHT", self.container, "TOPRIGHT", 0, -20)
        self.brandLine:Show()
        y = 26
    else
        if self.brand then self.brand:Hide() end
        if self.brandLine then self.brandLine:Hide() end
    end

    local currentGroup = nil
    local rowIndex, headerIndex = 0, 0
    for _, entry in ipairs(N.Registry.ActiveList or {}) do
        if entry.group ~= currentGroup then
            currentGroup = entry.group
            local groupName = currentGroup
            headerIndex = headerIndex + 1
            local header = self.headers[headerIndex] or CreateHeader(self.container)
            self.headers[headerIndex] = header
            header:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -y)
            header:SetWidth(width)
            local collapsed = N.Registry:IsGroupCollapsed(groupName)
            local count = 0
            for _, groupEntry in ipairs(N.Registry.ActiveList or {}) do
                if groupEntry.group == groupName then count = count + 1 end
            end
            header.text:SetText(string.format("%s (%d)", groupName, count))
            local c = GROUP_COLORS[groupName] or { 1, 1, 1 }
            header.text:SetTextColor(c[1], c[2], c[3])
            header.arrow:SetText(collapsed and "+" or "-")
            header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            header:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    N.UI:ShowHeaderMenu(header, groupName)
                    return
                end
                N.Registry:ToggleGroupCollapsed(groupName)
                N.UI:Refresh()
            end)
            header:Show()
            y = y + HEADER_H + 2
        end

        if not N.Registry:IsGroupCollapsed(entry.group) then
            rowIndex = rowIndex + 1
            local row = self.rows[rowIndex] or CreateRow(self.container)
            self.rows[rowIndex] = row
            row:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -y)
            self:ApplyRow(row, entry, width)
            y = y + row:GetHeight() + ROW_GAP
        end
    end

    for i = rowIndex + 1, #self.rows do self.rows[i]:Hide() end
    for i = headerIndex + 1, #self.headers do self.headers[i]:Hide() end
    self.container:SetSize(width, math.max(1, y))
    if self.grip then self.grip:SetShown(N.db.showNames ~= false) end
end

