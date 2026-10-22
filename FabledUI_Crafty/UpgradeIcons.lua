local M = _G.FabledUI_Crafty
M.UpgradeIcons = M.UpgradeIcons or {}
local U = M.UpgradeIcons

local SQUISH_CURVE_ID = 92181
local categoryEnum = {
    Explorer = 970,
    Adventurer = 971,
    Veteran = 972,
    Champion = 973,
    Hero = 974,
    Myth = 978,
    Awakened = 998,
}

local SeasonData = {
    [30] = {
        [categoryEnum.Explorer] = 98,
        [categoryEnum.Adventurer] = 102,
        [categoryEnum.Veteran] = 108,
        [categoryEnum.Champion] = 121,
        [categoryEnum.Hero] = 134,
        [categoryEnum.Myth] = 147,
    },
    [34] = {
        [categoryEnum.Explorer] = 207,
        [categoryEnum.Adventurer] = 220,
        [categoryEnum.Veteran] = 233,
        [categoryEnum.Champion] = 246,
        [categoryEnum.Hero] = 259,
        [categoryEnum.Myth] = 272,
    },
}

local categoryDataTab = {
    [categoryEnum.Explorer] = { englishName = "Explorer", minLevel = 207 },
    [categoryEnum.Adventurer] = { englishName = "Adventurer", minLevel = 220 },
    [categoryEnum.Veteran] = { englishName = "Veteran", minLevel = 233 },
    [categoryEnum.Champion] = { englishName = "Champion", minLevel = 246 },
    [categoryEnum.Hero] = { englishName = "Hero", minLevel = 259 },
    [categoryEnum.Myth] = { englishName = "Myth", minLevel = 272 },
    [categoryEnum.Awakened] = { englishName = "Awakened", minLevel = 493 },
}

local defaultIcons = {
    [categoryEnum.Explorer] = "|A:Professions-ChatIcon-Quality-Tier1:%d:%d|a",
    [categoryEnum.Adventurer] = "|A:Professions-ChatIcon-Quality-Tier2:%d:%d|a",
    [categoryEnum.Veteran] = "|A:Professions-ChatIcon-Quality-Tier3:%d:%d|a",
    [categoryEnum.Champion] = "|A:Professions-ChatIcon-Quality-Tier4:%d:%d|a",
    [categoryEnum.Hero] = "|A:Professions-ChatIcon-Quality-Tier5:%d:%d|a",
    [categoryEnum.Myth] = "|A:Professions-ChatIcon-Quality-Tier5:%d:%d|a",
    [categoryEnum.Awakened] = "|A:ui-ej-icon-empoweredraid-large:%d:%d|a",
}

local patternUpgradeLevel = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
patternUpgradeLevel = patternUpgradeLevel:gsub("%%s", ")(.*)(")
patternUpgradeLevel = patternUpgradeLevel:gsub("%%d", "[0-9]+")
patternUpgradeLevel = "(" .. patternUpgradeLevel .. ")"

local patternIlvl = ITEM_LEVEL
patternIlvl = patternIlvl:gsub("'", ".")
patternIlvl = patternIlvl:gsub("’", ".")
patternIlvl = "^" .. patternIlvl:gsub("%%d", "([0-9]+)") .. "$"

local function GetPostSquishItemLevel(preSquishItemLevel)
    if C_CurveUtil and C_CurveUtil.EvaluateGameCurve then
        return C_CurveUtil.EvaluateGameCurve(SQUISH_CURVE_ID, preSquishItemLevel)
    end
    return preSquishItemLevel
end

function U:UpdateSeasonData()
    if not (C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID) then
        return
    end
    local currentSeasonID = C_SeasonInfo.GetCurrentDisplaySeasonID()
    local currentSeasonData = currentSeasonID and SeasonData[currentSeasonID] or nil
    if not currentSeasonData then
        return
    end
    for trackID, minLevel in pairs(currentSeasonData) do
        if categoryDataTab[trackID] then
            categoryDataTab[trackID].minLevel = minLevel
        end
    end
end

function U:GetIconForTrack(trackID, size)
    local iconString = defaultIcons[trackID]
    if not iconString then
        return nil
    end
    size = math.max(8, math.min(32, tonumber(size) or 18))
    return iconString:format(size, size)
end

function U:GetIconForLink(itemLink, size)
    if not itemLink or not (C_Item and C_Item.GetItemUpgradeInfo) then
        return nil
    end
    local itemUpgradeData = C_Item.GetItemUpgradeInfo(itemLink)
    if not itemUpgradeData or not itemUpgradeData.trackStringID then
        return nil
    end
    return self:GetIconForTrack(itemUpgradeData.trackStringID, size)
end

function U:TooltipEnabled()
    local settings = M.settings or {}
    return settings.upgradeIconsOnTooltip ~= false
end

function U:ContainerIconsEnabled()
    local settings = M.settings or {}
    return settings.upgradeIconsOnContainers == true
end

local function SearchAndReplaceTooltipLine(tooltip)
    if not U:TooltipEnabled() then
        return
    end
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    if not itemLink then
        return
    end

    local itemUpgradeData = C_Item.GetItemUpgradeInfo(itemLink)
    if not itemUpgradeData then
        return
    end

    local categoryData = categoryDataTab[itemUpgradeData.trackStringID]
    if not categoryData then
        return
    end

    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = line and line:GetText() or nil
        if text then
            local ilvl = tonumber(text:match(patternIlvl))
            if ilvl then
                local itemMinLevel = categoryData.minLevel
                if ilvl >= itemMinLevel then
                    local itemMaxLevel = GetPostSquishItemLevel(itemUpgradeData.maxItemLevel)
                    if ilvl < itemMaxLevel and itemMaxLevel > itemMinLevel then
                        line:SetText(text .. "/" .. itemMaxLevel)
                        line:Show()
                    end
                end
            elseif text:match(patternUpgradeLevel) then
                text = text:gsub(patternUpgradeLevel, "%1" .. (U:GetIconForTrack(itemUpgradeData.trackStringID, 20) or "") .. " %2%3")
                line:SetText(text)
                line:Show()
                break
            end
        end
    end
end

local function GetInventorySlots()
    return {
        [INVSLOT_HEAD] = { slotButton = CharacterHeadSlot },
        [INVSLOT_NECK] = { slotButton = CharacterNeckSlot },
        [INVSLOT_SHOULDER] = { slotButton = CharacterShoulderSlot },
        [INVSLOT_CHEST] = { slotButton = CharacterChestSlot },
        [INVSLOT_WRIST] = { slotButton = CharacterWristSlot },
        [INVSLOT_BACK] = { slotButton = CharacterBackSlot },
        [INVSLOT_WAIST] = { slotButton = CharacterWaistSlot },
        [INVSLOT_LEGS] = { slotButton = CharacterLegsSlot },
        [INVSLOT_FEET] = { slotButton = CharacterFeetSlot },
        [INVSLOT_HAND] = { slotButton = CharacterHandsSlot },
        [INVSLOT_FINGER1] = { slotButton = CharacterFinger0Slot },
        [INVSLOT_FINGER2] = { slotButton = CharacterFinger1Slot },
        [INVSLOT_TRINKET1] = { slotButton = CharacterTrinket0Slot },
        [INVSLOT_TRINKET2] = { slotButton = CharacterTrinket1Slot },
        [INVSLOT_MAINHAND] = { slotButton = CharacterMainHandSlot },
        [INVSLOT_OFFHAND] = { slotButton = CharacterSecondaryHandSlot },
    }
end

local function IconLocation(frame, relativeTo)
    if not relativeTo then
        return
    end
    local settings = M.settings or {}
    local location = tonumber(settings.upgradeIconLocation) or 1
    if location == 10 then
        frame:ClearAllPoints()
        return
    end

    local settings = M.settings or {}
    local xScale = tonumber(settings.upgradeIconOffsetX) or 1
    local yScale = tonumber(settings.upgradeIconOffsetY) or 1
    local positions = {
        [1] = { "TOPLEFT", relativeTo, "TOPLEFT", -3 * xScale, 2 * yScale },
        [2] = { "TOP", relativeTo, "TOP", 0, 2 * yScale },
        [3] = { "TOPRIGHT", relativeTo, "TOPRIGHT", 3 * xScale, 2 * yScale },
        [4] = { "LEFT", relativeTo, "LEFT", -3 * xScale, 0 },
        [5] = { "CENTER", relativeTo, "CENTER", 0, 0 },
        [6] = { "RIGHT", relativeTo, "RIGHT", 3 * xScale, 0 },
        [7] = { "BOTTOMLEFT", relativeTo, "BOTTOMLEFT", -3 * xScale, -2 * yScale },
        [8] = { "BOTTOM", relativeTo, "BOTTOM", 0, -2 * yScale },
        [9] = { "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 3 * xScale, -2 * yScale },
    }
    frame:ClearAllPoints()
    frame:SetPoint(unpack(positions[location] or positions[1]))
end

local function IconScale(frame)
    local settings = M.settings or {}
    frame:SetScale(tonumber(settings.upgradeIconScale) or 1)
end

function U:UpdateIcon(iconButton, itemLink)
    if not iconButton then
        return
    end
    if not iconButton.CraftyUpgradeIcon then
        iconButton.CraftyUpgradeIcon = iconButton:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    end
    if not self:ContainerIconsEnabled() then
        iconButton.CraftyUpgradeIcon:SetText("")
        return
    end
    IconLocation(iconButton.CraftyUpgradeIcon, iconButton)
    IconScale(iconButton.CraftyUpgradeIcon)
    iconButton.CraftyUpgradeIcon:SetText(self:GetIconForLink(itemLink, 18) or "")
end

function U:UpdateInventory(slotIndex)
    local inventory = GetInventorySlots()[slotIndex]
    if not inventory or not inventory.slotButton then
        return
    end
    local itemLink = GetInventoryItemLink("player", slotIndex)
    self:UpdateIcon(inventory.slotButton, itemLink)
end

function U:UpdateContainerFrame(containerFrame)
    if not containerFrame or not containerFrame.EnumerateValidItems then
        return
    end
    for _, itemButton in containerFrame:EnumerateValidItems() do
        local itemLink = C_Container.GetContainerItemLink(itemButton:GetBagID(), itemButton:GetID())
        self:UpdateIcon(itemButton, itemLink)
    end
end

function U:UpdateBankSlot(itemButton)
    if not itemButton then
        return
    end
    local itemLink = C_Container.GetContainerItemLink(itemButton:GetBankTabID(), itemButton:GetContainerSlotID())
    self:UpdateIcon(itemButton, itemLink)
end

function U:UpdateEquipmentFlyoutFrames(selfFrame)
    if not selfFrame or not selfFrame.buttons then
        return
    end
    for _, iconButton in ipairs(selfFrame.buttons) do
        if iconButton and iconButton.location and type(iconButton.location) ~= "table" then
            local locationData = EquipmentManager_GetLocationData(iconButton.location)
            if locationData then
                local itemLink
                if locationData.isBags then
                    itemLink = C_Container.GetContainerItemLink(locationData.bag, locationData.slot)
                elseif locationData.isPlayer then
                    itemLink = GetInventoryItemLink("player", locationData.slot)
                elseif locationData.isBank then
                    local bankItemButton = _G["BankFrameItem" .. (locationData.slot - 63)]
                    if bankItemButton then
                        itemLink = C_Container.GetContainerItemLink(bankItemButton:GetBagID(), bankItemButton:GetID())
                    end
                end
                self:UpdateIcon(iconButton, itemLink)
            end
        end
    end
end

function U:RefreshAll()
    for slotIndex = 1, 17 do
        self:UpdateInventory(slotIndex)
    end
    for bagID = 0, 12 do
        local containerFrame = ContainerFrameUtil_GetShownFrameForID and ContainerFrameUtil_GetShownFrameForID(bagID) or nil
        if containerFrame then
            self:UpdateContainerFrame(containerFrame)
        end
    end
    if EquipmentFlyoutFrame and EquipmentFlyoutFrame:IsShown() then
        self:UpdateEquipmentFlyoutFrames(EquipmentFlyoutFrame)
    end
end

function U:Init()
    if self._initialized then
        return
    end
    self._initialized = true
    self:UpdateSeasonData()

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, SearchAndReplaceTooltipLine)
    end

    EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", function()
        U:RefreshAll()
        EventRegistry:RegisterFrameEventAndCallback("BAG_UPDATE", function(_, bagIndex)
            if bagIndex < 13 then
                local frame = ContainerFrameUtil_GetShownFrameForID and ContainerFrameUtil_GetShownFrameForID(bagIndex) or nil
                if frame then
                    U:UpdateContainerFrame(frame)
                end
            end
        end)
    end)

    EventRegistry:RegisterCallback("CharacterFrame.Show", function()
        for slotIndex = 1, 17 do
            U:UpdateInventory(slotIndex)
        end
    end)

    EventRegistry:RegisterFrameEventAndCallback("PLAYER_EQUIPMENT_CHANGED", function(_, slotIndex)
        U:UpdateInventory(slotIndex)
    end)

    EventRegistry:RegisterCallback("ContainerFrame.OpenBag", function()
        U:RefreshAll()
    end)

    if BankPanelItemButtonMixin then
        hooksecurefunc(BankPanelItemButtonMixin, "Refresh", function(self) U:UpdateBankSlot(self) end)
    end

    EventRegistry:RegisterFrameEventAndCallback("LOOT_OPENED", function()
        if not (LootFrame and LootFrame.ScrollBox) then
            return
        end
        for slotIndex = 1, GetNumLootItems() do
            local lootElement = LootFrame.ScrollBox:FindFrameByPredicate(function(frame)
                return frame.GetSlotIndex and frame:GetSlotIndex() == slotIndex
            end)
            if lootElement and lootElement.Item then
                U:UpdateIcon(lootElement.Item, GetLootSlotLink(slotIndex))
            end
        end
    end)

    if EquipmentFlyoutFrame then
        EquipmentFlyoutFrame:HookScript("OnShow", function(frame) U:UpdateEquipmentFlyoutFrames(frame) end)
        EquipmentFlyoutFrame:HookScript("OnEvent", function(frame) U:UpdateEquipmentFlyoutFrames(frame) end)
    end
end
