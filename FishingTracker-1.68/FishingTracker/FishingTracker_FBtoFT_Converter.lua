local addonName, private = ...

-- Table to cache item names
local itemNameCache = {}

local function GetCompleteItemInfo(itemID)
    -- Get all available item information
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID)

    -- If we don't have the name yet, try to force load it
    if not itemName then
        itemLink = "|Hitem:"..itemID.."|h|r"
        itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
              itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemLink)
    end

    return {
        name = itemName or "Item_"..itemID,
        link = itemLink,
        rarity = itemRarity,
        level = itemLevel,
        minLevel = itemMinLevel,
        type = itemType,
        subType = itemSubType,
        stackCount = itemStackCount,
        equipLoc = itemEquipLoc,
        texture = itemTexture,
        sellPrice = itemSellPrice
    }
end

local function GetItemName(itemID)
    -- Return cached name if available
    if itemNameCache[itemID] and itemNameCache[itemID].name then
        return itemNameCache[itemID].name
    end

    -- Get complete item info
    local itemInfo = GetCompleteItemInfo(itemID)

    -- Cache the result
    itemNameCache[itemID] = itemInfo

    return itemInfo.name
end

local function GetZoneName(zoneID)
    local zoneName = C_Map.GetMapInfo(zoneID) and C_Map.GetMapInfo(zoneID).name
    return zoneName or ("Zone_"..tostring(zoneID))
end

local function CollectAllItemIDs(fishSchools)
    local itemIDs = {}
    for zoneID, schools in pairs(fishSchools) do
        for _, school in ipairs(schools) do
            if school.fish then
                for itemID, _ in pairs(school.fish) do
                    itemIDs[itemID] = true
                end
            end
        end
    end
    return itemIDs
end

local function PreloadAllItemInfo(itemIDs, callback)
    local totalItems = 0
    local loadedItems = 0
    local waitingFor = {}

    -- Count how many items we need to load
    for itemID in pairs(itemIDs) do
        if not itemNameCache[itemID] then
            totalItems = totalItems + 1
            waitingFor[itemID] = true
        end
    end

    if totalItems == 0 then
        callback()
        return
    end

    print(string.format("Preloading item information (%d items)...", totalItems))

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(self, elapsed)
        local itemsProcessed = 0

        -- Process up to 10 items per frame to avoid freezing the game
        for itemID in pairs(waitingFor) do
            if itemsProcessed >= 10 then break end

            local itemInfo = GetCompleteItemInfo(itemID)
            if itemInfo.name and not itemInfo.name:match("^Item_") then
                itemNameCache[itemID] = itemInfo
                waitingFor[itemID] = nil
                loadedItems = loadedItems + 1
                itemsProcessed = itemsProcessed + 1
            end
        end

        -- Update progress every 100 items or when done
        if loadedItems % 100 == 0 or next(waitingFor) == nil then
            print(string.format("Loaded %d/%d items...", loadedItems, totalItems))
        end

        -- All items loaded or we've given up
        if next(waitingFor) == nil or loadedItems >= totalItems then
            self:Hide()
            callback()
        end
    end)
end

local function MergeWithFishingTrackerData(newDB)
    if not FishingTrackerDB then
        return newDB
    end

    -- Merge fish data
    for fishName, fishData in pairs(FishingTrackerDB.fishData or {}) do
        if not newDB.fishData[fishName] then
            newDB.fishData[fishName] = fishData
        else
            newDB.fishData[fishName].count = newDB.fishData[fishName].count + (fishData.count or 0)
        end
        newDB.totalCaught = newDB.totalCaught + (fishData.count or 0)
    end

    -- Merge zone data
    for zoneName, zoneData in pairs(FishingTrackerDB.zoneData or {}) do
        if not newDB.zoneData[zoneName] then
            newDB.zoneData[zoneName] = zoneData
        else
            -- Merge fish counts within the zone
            for fishName, fishData in pairs(zoneData.fishData or {}) do
                if not newDB.zoneData[zoneName].fishData[fishName] then
                    newDB.zoneData[zoneName].fishData[fishName] = fishData
                else
                    newDB.zoneData[zoneName].fishData[fishName].count = 
                        newDB.zoneData[zoneName].fishData[fishName].count + (fishData.count or 0)
                end
            end
            newDB.zoneData[zoneName].total = newDB.zoneData[zoneName].total + (zoneData.total or 0)
        end
    end

    -- Merge config settings (preserve existing FishingTracker config)
    if FishingTrackerDB.config then
        newDB.config = FishingTrackerDB.config
    end

    -- Merge UI settings (preserve existing FishingTracker UI settings)
    if FishingTrackerDB.ui then
        newDB.ui = FishingTrackerDB.ui
    end

    return newDB
end

private.ConvertFishingBuddyData = function()
    if not FishingBuddy_Info then
        print("|cFFFF0000FishingBuddy data not found!|r")
        print("Possible reasons:")
        print("- FishingBuddy addon is not installed")
        print("- FishingBuddy is installed but not enabled")
        print("- FishingBuddy hasn't been loaded yet (try reloading UI)")
        print("- You haven't used FishingBuddy to collect any data yet")
        print("Type /reload and try again after ensuring FishingBuddy is enabled")
        return
    end

    if not FishingBuddy_Info.FishSchools or not next(FishingBuddy_Info.FishSchools) then
        print("|cFFFF0000No fishing data found in FishingBuddy!|r")
        print("You need to fish with FishingBuddy enabled to collect data first")
        return
    end

    print("|cFF00FF00Starting FishingBuddy data conversion...|r")

    -- First collect all unique item IDs
    local allItemIDs = CollectAllItemIDs(FishingBuddy_Info.FishSchools)

    -- Pre-load all item names with proper waiting
    PreloadAllItemInfo(allItemIDs, function()
        local newDB = {
            totalCaught = 0,
            config = {},
            fishData = {},
            zoneData = {},
        }

        local totalConverted = 0

        -- Process FishSchools data
        for zoneID, schools in pairs(FishingBuddy_Info.FishSchools) do
            if type(schools) == "table" then
                local zoneName = GetZoneName(zoneID)

                for _, school in ipairs(schools) do
                    if type(school) == "table" and school.fish and type(school.fish) == "table" and school.count and school.count > 0 then
                        -- Initialize zone data if not exists
                        if not newDB.zoneData[zoneName] then
                            newDB.zoneData[zoneName] = {
                                fishData = {},
                                total = 0,
                                mapID = zoneID,
                            }
                        end

                        -- Process each fish in the school
                        for itemID, count in pairs(school.fish) do
                            if itemID and count then
                                local itemInfo = itemNameCache[itemID] or GetCompleteItemInfo(itemID)
                                local itemName = itemInfo.name

                                -- Update fish data
                                if not newDB.fishData[itemName] then
                                    newDB.fishData[itemName] = {
                                        count = 0,
                                        itemID = itemID,
                                        itemType = itemInfo.type,
                                        itemSubType = itemInfo.subType,
                                        texture = itemInfo.texture
                                    }
                                end
                                newDB.fishData[itemName].count = newDB.fishData[itemName].count + count
                                newDB.totalCaught = newDB.totalCaught + count

                                -- Update zone fish data
                                if not newDB.zoneData[zoneName].fishData[itemName] then
                                    newDB.zoneData[zoneName].fishData[itemName] = {
                                        count = 0,
                                        itemID = itemID,
                                        itemType = itemInfo.type,
                                        itemSubType = itemInfo.subType,
                                        texture = itemInfo.texture
                                    }
                                end
                                newDB.zoneData[zoneName].fishData[itemName].count = 
                                    newDB.zoneData[zoneName].fishData[itemName].count + count
                                newDB.zoneData[zoneName].total = newDB.zoneData[zoneName].total + count

                                totalConverted = totalConverted + count
                            end
                        end
                    end
                end
            end
        end

        -- Merge with existing FishingTracker data
        newDB = MergeWithFishingTrackerData(newDB)

        -- Save the converted data
        FishingTrackerDB = newDB

        if totalConverted > 0 then
            print(string.format("|cFF00FF00Success! Converted %d fish catches.|r", totalConverted))
            print("|cFF00FF00Data has been merged with existing FishingTracker data.|r")
        else
            print("|cFFFF0000No fish data was converted.|r")
        end

        -- Force update of the display if FishingTracker is loaded
        if FishingTracker and FishingTracker.UpdateDisplay then
            FishingTracker.UpdateDisplay()
        end
    end)
end
