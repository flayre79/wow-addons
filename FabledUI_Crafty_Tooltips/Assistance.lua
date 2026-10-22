local M = _G.FabledUI_Crafty
M.Assistance = M.Assistance or {}
local A = M.Assistance
-- Resolve AssistanceData lazily. The data lives in its own LoD shard
-- (FabledUI_Crafty_Data_Assistance, ~3.9k LOC) — first call here loads it.
local function D()
    if not M.AssistanceData and M.EnsureFeatureShardLoaded then
        M:EnsureFeatureShardLoaded("Assistance")
    end
    return M.AssistanceData or {}
end

local TYPE_INFO = {
    herb = {
        headline = "Milling outcome",
        color = { r = 0.0, g = 1.0, b = 0.5 },
        settingsKey = "tooltipAssistanceMillingEnabled",
        locationKey = "tooltipAssistanceLocationsEnabled",
    },
    milling = {
        headline = "Milled from",
        color = { r = 0.0, g = 1.0, b = 0.5 },
        settingsKey = "tooltipAssistanceMillingEnabled",
    },
    prospecting = {
        headline = "Prospecting outcome",
        color = { r = 1.0, g = 0.5, b = 0.0 },
        settingsKey = "tooltipAssistanceProspectingEnabled",
    },
    ore = {
        headline = "Prospected from",
        color = { r = 1.0, g = 0.5, b = 0.0 },
        settingsKey = "tooltipAssistanceProspectingEnabled",
        locationKey = "tooltipAssistanceLocationsEnabled",
    },
    gear = {
        headline = "Disenchant into",
        color = { r = 1.0, g = 0.0, b = 0.9 },
        settingsKey = "tooltipAssistanceDisenchantEnabled",
    },
    disenchant = {
        headline = "Disenchant from",
        color = { r = 1.0, g = 0.0, b = 0.9 },
        settingsKey = "tooltipAssistanceDisenchantEnabled",
    },
}

local function getTooltipItemID(tt)
    local data = tt and tt.GetPrimaryTooltipData and tt:GetPrimaryTooltipData() or nil
    if not data then
        return nil
    end
    return data.id or (data.hyperlink and tonumber(string.match(data.hyperlink, "item:?(%d+):"))) or nil
end

local function getItemInfo(itemID)
    if not itemID then
        return nil
    end
    return C_Item.GetItemInfo(itemID)
end

local function getItemLink(itemID)
    local _, link = getItemInfo(itemID)
    return link or tostring(itemID)
end

local function getItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    return nil
end

local function addItemTexture(itemID)
    if M.settings.tooltipAssistanceShowIcons == false then
        return ""
    end
    local texture = getItemIcon(itemID)
    return texture and ("|T" .. texture .. ":14|t ") or ""
end

function A:GetMapName(mapLocation)
    local d = D()
    local data = d.mapIDs and d.mapIDs[mapLocation]
    if not data then
        return nil
    end
    local mapID = data[2] or data[1]
    if not mapID then
        return nil
    end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

function A:GetEntry(itemID)
    local d = D()
    if d.herb and d.herb[itemID] then
        return "herb", d.herb[itemID]
    elseif d.milling and d.milling[itemID] then
        return "milling", d.milling[itemID]
    elseif d.ore and d.ore[itemID] then
        return "ore", d.ore[itemID]
    elseif d.prospecting and d.prospecting[itemID] then
        return "prospecting", d.prospecting[itemID]
    elseif d.disenchant and d.disenchant[itemID] then
        return "disenchant", d.disenchant[itemID]
    end
    return nil
end

function A:GetGearEntry(itemID)
    local d = D()
    if not d.gear then
        return nil
    end
    local _, _, itemQuality, itemLevel, _, _, _, _, itemEquipLoc, _, _, classID, _, _, expacID = getItemInfo(itemID)
    local itemSort = (classID == 4 and "armor" or classID == 2 and "weapon" or nil)
    if not itemQuality or not itemLevel or not itemSort or itemSort == nil then
        return nil
    end
    for _, filterType in next, { "", "INVTYPE_BODY", "INVTYPE_RELIC", "INVTYPE_TABARD", "INVTYPE_BAG", "INVTYPE_QUIVER" } do
        if itemEquipLoc == filterType then
            return nil
        end
    end
    local rows = d.gear[itemQuality]
    if type(rows) ~= "table" then
        return nil
    end
    for _, itemTable in ipairs(rows) do
        if expacID == itemTable.expansion and itemTable[itemSort] then
            return "gear", itemTable[itemSort]
        end
    end
    return nil
end

function A:GetTooltipData(itemID)
    local dataType, data = self:GetEntry(itemID)
    if dataType and data then
        return dataType, data
    end
    return self:GetGearEntry(itemID)
end

function A:IsEnabledForType(dataType)
    local info = TYPE_INFO[dataType]
    if not info then
        return false
    end
    return M.settings[info.settingsKey] ~= false
end

function A:BuildTextRows(dataResults)
    local lines = {}
    if type(dataResults) ~= "table" then
        return lines
    end

    if type(dataResults.text) == "table" then
        for _, textTable in ipairs(dataResults.text) do
            if textTable.chance then
                lines[#lines + 1] = tostring(textTable.chance)
            end
            local qualityLabel = textTable.quality and _G["ITEM_QUALITY" .. tostring(textTable.quality) .. "_DESC"] or nil
            local typeList = type(textTable.type) == "table" and table.concat(textTable.type, " & ") or nil
            local parts = {}
            if qualityLabel then
                parts[#parts + 1] = qualityLabel
            end
            if typeList then
                parts[#parts + 1] = typeList
            end
            if #parts > 0 then
                lines[#lines + 1] = table.concat(parts, " ")
            end
        end
    end

    if type(dataResults.items) == "table" then
        for _, itemTable in ipairs(dataResults.items) do
            if itemTable.chance then
                lines[#lines + 1] = tostring(itemTable.chance)
            end
            local itemParts = {}
            for _, item in ipairs(itemTable) do
                if type(item) == "number" then
                    itemParts[#itemParts + 1] = addItemTexture(item) .. getItemLink(item)
                elseif type(item) == "string" then
                    itemParts[#itemParts + 1] = item
                end
            end
            if #itemParts > 0 then
                lines[#lines + 1] = table.concat(itemParts, ", ")
            end
        end
    end

    return lines
end

function A:BuildLocationLines(dataResults)
    local lines = {}
    if M.settings.tooltipAssistanceLocationsEnabled == false then
        return lines
    end
    local found = type(dataResults) == "table" and dataResults.found or nil
    if type(found) ~= "table" then
        return lines
    end

    if type(found.node) == "table" and #found.node > 0 then
        local nodeParts = {}
        for _, item in ipairs(found.node) do
            if type(item) == "number" then
                nodeParts[#nodeParts + 1] = addItemTexture(item) .. getItemLink(item)
            elseif type(item) == "string" then
                nodeParts[#nodeParts + 1] = item
            end
        end
        if #nodeParts > 0 then
            local chance = found.chance and (" (" .. tostring(found.chance) .. ")") or ""
            lines[#lines + 1] = "Nodes" .. chance .. ": " .. table.concat(nodeParts, ", ")
        end
    end

    if type(found.location) == "table" and #found.location > 0 then
        local zones = {}
        local seen = {}
        for _, mapLocation in ipairs(found.location) do
            local name = self:GetMapName(mapLocation)
            if name and not seen[name] then
                seen[name] = true
                zones[#zones + 1] = name
            end
        end
        if #zones > 0 then
            lines[#lines + 1] = "Zones: " .. table.concat(zones, ", ")
        end
    end

    return lines
end

function A:BuildTooltipLines(itemID)
    local dataType, dataResults = self:GetTooltipData(itemID)
    if not dataType or not dataResults or not self:IsEnabledForType(dataType) then
        return nil
    end

    local info = TYPE_INFO[dataType]
    local lines = { "Crafty Assistant: " .. (info.headline or dataType) }
    local body = self:BuildTextRows(dataResults)
    for _, line in ipairs(body) do
        lines[#lines + 1] = line
    end
    local locationLines = self:BuildLocationLines(dataResults)
    for _, line in ipairs(locationLines) do
        lines[#lines + 1] = line
    end
    return lines
end

local function addTooltipLines(tooltip)
    if M.settings.tooltipAssistanceEnabled == false then
        return
    end
    local itemID = getTooltipItemID(tooltip)
    if not itemID then
        return
    end
    local lines = A:BuildTooltipLines(itemID)
    if not lines or #lines == 0 then
        return
    end
    tooltip:AddLine(" ")
    for index, line in ipairs(lines) do
        if index == 1 then
            tooltip:AddLine(line, 0.36, 0.88, 0.71)
        else
            tooltip:AddLine(line, 1, 1, 1, true)
        end
    end
    tooltip:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and not M.USE_UNIFIED_TOOLTIP_COMPOSER then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addTooltipLines)
end

return A
