--------------------------------------------------------------------------------------------------------------
-- Addon:	FishingTracker
-- Version:	1.68
-- Desc:	Tracks fishing statistics with advanced features.
--------------------------------------------------------------------------------------------------------------
-- For Debug Use
-- /etrace
-- /dump C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
-- /run local mapID = C_Map.GetBestMapForUnit("player"); print(format("You are in %s (%d)", C_Map.GetMapInfo(mapID).name, mapID))
-- /run local itemid=133724; local itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, _, _, _, _, _, _ = GetItemInfo(itemid); print(itemName, itemType, itemSubType);
-- /dump UIParent:GetWidth(), UIParent:GetHeight()
--------------------------------------------------------------------------------------------------------------
-- 1. CONSTANTS
--------------------------------------------------------------------------------------------------------------
-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("FishingTracker", "enUS", true)
local LibGraph = LibStub("LibGraph-2.0")

private = private or {}
private.zoneExpansionSkillMap = private.zoneExpansionSkillMap or {}

FishingTrackerDB = FishingTrackerDB or {}
local db

-- Initialize the global FishingTracker table early
FishingTracker = FishingTracker or {}

-- Get locale and set flags
local currentLocale = GetLocale()
FishingTracker.CURRENT_LOCALE = currentLocale
FishingTracker.isZhCN = (currentLocale == "zhCN")
FishingTracker.isZhTW = (currentLocale == "zhTW")
FishingTracker.isChinese = (FishingTracker.isZhCN or FishingTracker.isZhTW)

-- Font Constants Data
local FRAME_FONT_ID = {
    -- Default to English fonts initially
    "Interface\\AddOns\\FishingTracker\\Fonts\\ARIALN.TTF",	-- Arial Narrow
    "Interface\\AddOns\\FishingTracker\\Fonts\\ARIALNB.TTF",	-- Arial Narrow Bold
    "Interface\\AddOns\\FishingTracker\\Fonts\\HANZEB.TTF"	-- Hanzel
}
-- ##### DEBUG #####
-- print("FishingTracker: Detected locale = " .. FishingTracker.CURRENT_LOCALE)
-- print("FishingTracker: isZhCN = " .. tostring(FishingTracker.isZhCN))
-- print("FishingTracker: isZhTW = " .. tostring(FishingTracker.isZhTW))
-- #################
if FishingTracker.isZhCN then
    -- Simplified Chinese fonts
    FRAME_FONT_ID[1] = "Interface\\AddOns\\FishingTracker\\Fonts\\FZLanTingHei-RN-GBK.TTF"	-- FZLanTingHei-RN-GBK
    FRAME_FONT_ID[2] = "Interface\\AddOns\\FishingTracker\\Fonts\\FZLanTingHei-HN-GBK.TTF"	-- FZLanTingHei-HN-GBK
    FRAME_FONT_ID[3] = "Interface\\AddOns\\FishingTracker\\Fonts\\HANZEB.TTF"			-- Hanzel
    -- ##### DEBUG #####
    -- print("Fonts changed to Simplified Chinese")
    -- #################
elseif FishingTracker.isZhTW then
    -- Traditional Chinese fonts
    FRAME_FONT_ID[1] = "Interface\\AddOns\\FishingTracker\\Fonts\\FZLanTingHei-RN-GBK.TTF"	-- FZLanTingHei-RN-GBK
    FRAME_FONT_ID[2] = "Interface\\AddOns\\FishingTracker\\Fonts\\FZLanTingHei-HN-GBK.TTF"	-- FZLanTingHei-HN-GBK
    FRAME_FONT_ID[3] = "Interface\\AddOns\\FishingTracker\\Fonts\\HANZEB.TTF"			-- Hanzel
    -- ##### DEBUG #####
    -- print("Fonts changed to Traditional Chinese")
    -- #################
else
    -- Default fonts (English and other languages)
    FRAME_FONT_ID[1] = "Interface\\AddOns\\FishingTracker\\Fonts\\ARIALN.TTF"	-- Arial Narrow
    FRAME_FONT_ID[2] = "Interface\\AddOns\\FishingTracker\\Fonts\\ARIALNB.TTF"	-- Arial Narrow Bold
    FRAME_FONT_ID[3] = "Interface\\AddOns\\FishingTracker\\Fonts\\HANZEB.TTF"	-- Hanzel
    -- ##### DEBUG #####
    -- print("Fonts kept as English defaults")
    -- #################
end
-- ##### DEBUG #####
-- Debug: Print what fonts are actually set
-- print("Current Fonts:")
-- print("  FRAME_FONT_ID[1] = " .. FRAME_FONT_ID[1])
-- print("  FRAME_FONT_ID[2] = " .. FRAME_FONT_ID[2])
-- print("  FRAME_FONT_ID[3] = " .. FRAME_FONT_ID[3])
-- #################

--------------------------------------------------------------------------------------------------------------
-- Addon Version Check Constants
local addonName = "FishingTracker"
local ADDON_NAME, private = ...
local ADDON_TITLE = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title")
local ADDON_VERSION = (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0.0"):match("^([%d.]+)")
local ADDON_ICON_TEXTURE = tostring(C_AddOns.GetAddOnMetadata(ADDON_NAME, "IconTexture"))
local DATA_VERSION = tonumber((C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "1.0"):match("(%d+)$"))
local GAME_VERSION = select(4, GetBuildInfo())

--------------------------------------------------------------------------------------------------------------
-- Addon Others Constants
local FISHING_SPELL_ID = 131476 -- Fishing spell ID
local FISHING_BUFF_SPELL_ID = 394009 -- "Fishing For Attention" buff
local MIDNIGHT_BUFF_SPELL_ID = 1214848 -- "Winds of Mysterious Fortune" buff
local DEFAULT_AUTO_HIDE_DELAY = 10 -- seconds
local DEFAULT_WATCHDRAGGER_FADE_TIME = 0.25
local DEFAULT_SESSION_UPDATE_INTERVAL = 5 -- seconds
local DEFAULT_MAINFRAME_BG = false
local DEFAULT_FRAME_WIDTH = 250
local DEFAULT_FRAME_HEIGHT = 250
local DEFAULT_FRAME_TRANSPARENCY = 0.2
local DEFAULT_FRAME_LOCK = false
local DEFAULT_SCALE = 1.0
local DEFAULT_SOUND = true
local DEFAULT_DEBUG = false
local DEFAULT_TRASH_COUNT = false
local DEFAULT_MAX_DEBUG_MESSAGES = 10000
local SPACES = string.rep(" ", 23) -- Creates a string with 23 spaces
local IsFishingLoot = IsFishingLoot

local MP3_FISH_SOUND = {
    "Interface\\AddOns\\FishingTracker\\Sounds\\quest_fish.mp3",	-- QUEST - MP3_FISH_SOUND[1]
    "Interface\\AddOns\\FishingTracker\\Sounds\\rare_fish.mp3"		-- RARE - MP3_FISH_SOUND[2]
}

local PNG_DOT = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\Red_Dot.png",		-- RED - PNG_DOT[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\Green_Dot.png",	-- GREEN - PNG_DOT[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\White_Dot.png",	-- WHITE - PNG_DOT[3]
    "Interface\\AddOns\\FishingTracker\\Artwork\\Yellow_Dot.png"	-- YELLOW - PNG_DOT[4]
}

local PNG_CLOSE_BUTTON = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\Close_Button_Normal.png",	-- NORMAL - PNG_CLOSE_BUTTON[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\Close_Button_Highlight.png",	-- HIGHLIGHT - PNG_CLOSE_BUTTON[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\Close_Button_Pressed.png"	-- PRESSED - PNG_CLOSE_BUTTON[3]
}

local PNG_FRAME_LOCK = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\lock.png",			-- LOCK - PNG_FRAME_LOCK[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\lock_Highlight.png",		-- HIGHLIGHT - PNG_FRAME_LOCK[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\unlock.png"			-- UNLOCK - PNG_FRAME_LOCK[3]
}

local PNG_SOUND = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\sound_ON.png",			-- ON - PNG_SOUND[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\sound_OFF.png",		-- OFF - PNG_SOUND[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\sound_OF_Highlight.png"	-- HIGHLIGHT - PNG_SOUND[3]
}

local PNG_TRANS = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\trans_ON.png",		-- ON - PNG_TRANS[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\trans_OFF.png",	-- OFF - PNG_TRANS[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\trans_ON.png"		-- HIGHLIGHT - PNG_TRANS[3]
}

local PNG_TRASH = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\trash_ON.png",		-- ON - PNG_TRASH[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\trash_OFF.png"		-- OFF - PNG_TRASH[2]
}

local PNG_SORT_FISH = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\sort_fish_normal.png",		-- NORMALE - PNG_SORT_FISH[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\sort_fish_highlight.png",	-- HIGHLIGHT - PNG_SORT_FISH[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\sort_fish_disabled.png"	-- DISABLED - PNG_SORT_FISH[3]
}

local PNG_SORT_ZONE = {
    "Interface\\AddOns\\FishingTracker\\Artwork\\sort_zone_normal.png",		-- NORMALE - PNG_SORT_ZONE[1]
    "Interface\\AddOns\\FishingTracker\\Artwork\\sort_zone_highlight.png",	-- HIGHLIGHT - PNG_SORT_ZONE[2]
    "Interface\\AddOns\\FishingTracker\\Artwork\\sort_zone_disabled.png"	-- DISABLED - PNG_SORT_ZONE[3]
}

-- Rare & Special Fish IDs and Default Quality Colors Data
local FISH_QUALITY_COLORS = FT_QualityColorsIDs or {}
local RARE_FISH_IDS = FT_RareFishIDs or {}
local SPECIAL_FISH_IDS = FT_SpecialFishIDs or {}
local JUNK_ITEMS_IDS = FT_JunkItemsIDs or {}
local NOT_JUNK_ITEMS_IDS = FT_NotJunkItemsIDs or {}

-- Fishing Poles & Buff Data
local FISHING_POLES = FT_FishingPolesIDs
local FISHING_HAT_BUFF = FT_FishingHatBuffIDs
local FISHING_TOYS_BUFF = FT_FishingToysBuffIDs
local FISHING_SKILL_BUFF = FT_FishingSkillBuffIDs
local FISHING_PERCEPTION_BUFF = FT_FishingPerceptionBuffIDs

--------------------------------------------------------------------------------------------------------------
-- 2. DATA STORAGE SYSTEM
--------------------------------------------------------------------------------------------------------------
FishingTrackerDB = FishingTrackerDB or {
    version = DATA_VERSION,
    fishData = {},
    zoneData = {},
    totalCaught = 0,
    config = {
        autoHide = true,
        autoHideDelay = DEFAULT_AUTO_HIDE_DELAY,
        trackSessions = true,
        frameLocked = DEFAULT_FRAME_LOCK,
        enableSound = DEFAULT_SOUND,
        enableBackground = DEFAULT_MAINFRAME_BG,
        backgroundAlpha = DEFAULT_FRAME_TRANSPARENCY,
        trashcount = DEFAULT_TRASH_COUNT,
        autoHideConditions = {
            mounted = true,
            fishingBuff = true
        },
        minimap = {
            show = true,
            position = 225,
            radius = 90
        },
        transparency = DEFAULT_FRAME_TRANSPARENCY,
    },
    ui = {
        width = DEFAULT_FRAME_WIDTH,
        height = DEFAULT_FRAME_HEIGHT,
        point = "TOP",
        relativePoint = "TOP",
        x = 0,
        y = -290,
        scale = DEFAULT_SCALE
    },
    globalStatsUI = {
        point = "TOP",
        relativePoint = "TOP",
        x = 300,
        y = -290,
        scale = DEFAULT_SCALE
    }
}

local function MigrateZoneFormat()
    for zoneKey, zoneData in pairs(db.zoneData) do
        -- Check if this is old format (no brackets in key)
        if not zoneKey:match("%[%d+%]$") then
            -- Create new key in the format "Zone - Subzone [mapID]"
            local newKey = format("%s - %s [%d]", 
                zoneData.zoneName or zoneKey, 
                zoneData.subzoneName or zoneKey, 
                zoneData.mapID or 0)

            -- Only migrate if we don't already have data for this key
            if not db.zoneData[newKey] then
                db.zoneData[newKey] = zoneData
            end

            -- For zones that already exist in new format, merge the data
            if db.zoneData[newKey] and db.zoneData[newKey] ~= zoneData then
                -- Merge totals
                db.zoneData[newKey].total = (db.zoneData[newKey].total or 0) + (zoneData.total or 0)

                -- Merge fish data
                for fishName, fishData in pairs(zoneData.fishData or {}) do
                    if not db.zoneData[newKey].fishData[fishName] then
                        db.zoneData[newKey].fishData[fishName] = fishData
                    else
                        -- Add counts if fish already exists
                        local count = type(fishData) == "table" and fishData.count or fishData
                        if type(db.zoneData[newKey].fishData[fishName]) == "table" then
                            db.zoneData[newKey].fishData[fishName].count = db.zoneData[newKey].fishData[fishName].count + count
                        else
                            db.zoneData[newKey].fishData[fishName] = db.zoneData[newKey].fishData[fishName] + count
                        end
                    end
                end
            end

            -- Remove old format entry
            db.zoneData[zoneKey] = nil
        end
    end
end

local function CleanupZoneData()
    for zoneKey, zoneData in pairs(FishingTrackerDB.zoneData) do
        if zoneKey:match(L["UNKNOWN_ZONE"]) then
            FishingTrackerDB.zoneData[zoneKey] = nil
        end
    end
end

local function DeepCleanDatabase()
    -- First pass: Delete all zones with total = 0
    for zoneKey, zoneData in pairs(FishingTrackerDB.zoneData) do
        if zoneData.total == 0 or not zoneData.total then
            FishingTrackerDB.zoneData[zoneKey] = nil
        end
    end

    -- Second pass: Delete parent zones if they have no subzones left
    local parentZones = {}

    -- Find all parent zones (e.g., "Borean Tundra")
    for zoneKey, zoneData in pairs(FishingTrackerDB.zoneData) do
        local zoneName = zoneData.zoneName or zoneKey:match("^(.-) %-") or zoneKey
        parentZones[zoneName] = true
    end

    -- Check if parent zones have any remaining subzones
    for parentZone in pairs(parentZones) do
        local hasSubzones = false

        for zoneKey in pairs(FishingTrackerDB.zoneData) do
            if zoneKey:match("^" .. parentZone .. " %-") then
                hasSubzones = true
                break
            end
        end

        -- Delete the parent zone if no subzones exist
        if not hasSubzones and FishingTrackerDB.zoneData[parentZone] then
            FishingTrackerDB.zoneData[parentZone] = nil
        end
    end
end

local function MigrateZoneData()
    for zoneKey, zoneData in pairs(FishingTrackerDB.zoneData) do
        -- Skip if already migrated (has zoneName field)
        if not zoneData.zoneName then
            -- Extract zone and subzone from the key
            -- Format is "Zone - Subzone [mapID]" or just "Zone [mapID]"
            local zone, subzone = zoneKey:match("^(.-) %- (.-) %[%d+%]$")

            -- If no subzone found (format is "Zone [mapID]")
            if not zone then
                zone = zoneKey:match("^(.-) %[%d+%]$")
                subzone = zone -- Subzone same as zone
            end

            -- Add the new fields
            zoneData.zoneName = zone or L["UNKNOWN_ZONE"]
            zoneData.subzoneName = subzone or zoneData.zoneName

            -- Debug output
            -- ##### DEBUG #####
            if DEFAULT_DEBUG then
                AddDebugMessage(format(L["MIGRATED_ZONE_DATA"].." %s -> zoneName: %s, subzoneName: %s", 
                    zoneKey, zoneData.zoneName, zoneData.subzoneName))
            end
            -- #################

        end
    end
end

local function MigrateZoneNames()
    if not db or not db.zoneData then return end

    for zoneKey, zoneData in pairs(db.zoneData) do
        -- Skip if already has proper names
        if not zoneData.zoneName or zoneData.zoneName == L["UNKNOWN_ZONE"] then
            -- Extract zone and subzone from key (format is "Zone - Subzone [mapID]")
            local zoneFromKey, subzoneFromKey = zoneKey:match("^(.-) %- (.-) %[%d+%]$")

            -- If no subzone found (format is "Zone [mapID]")
            if not zoneFromKey then
                zoneFromKey = zoneKey:match("^(.-) %[%d+%]$")
                subzoneFromKey = zoneFromKey
            end

            -- If we still don't have names, try to get from mapID
            if not zoneFromKey and zoneData.mapID and zoneData.mapID > 0 then
                local mapInfo = C_Map.GetMapInfo(zoneData.mapID)
                if mapInfo then
                    zoneFromKey = mapInfo.name
                    subzoneFromKey = mapInfo.name
                end
            end

            -- Update the names if we found them
            if zoneFromKey then
                zoneData.zoneName = zoneFromKey
                zoneData.subzoneName = subzoneFromKey or zoneFromKey
            end
        end
    end
end

local function MigrateZoneDisplayNames()
    for zoneKey, zoneData in pairs(db.zoneData) do
        if not zoneData.displayZoneName then
            -- Extract the display name from the zone key (this should already be the formatted name)
            local displayName = zoneKey:match("^(.-) %-")
            if displayName then
                zoneData.displayZoneName = displayName
            else
                zoneData.displayZoneName = zoneData.zoneName or zoneKey
            end
        end
    end
end

local function InitializeDB()
    -- Start with default values
    local defaults = {
        version = DATA_VERSION,
        fishData = {},
        zoneData = {},
        totalCaught = 0,
        config = {
            autoHide = true,
            autoHideDelay = DEFAULT_AUTO_HIDE_DELAY,
            trackSessions = true,
            frameLocked = DEFAULT_FRAME_LOCK,
            enableSound = DEFAULT_SOUND,
            enableBackground = DEFAULT_MAINFRAME_BG,
            backgroundAlpha = DEFAULT_FRAME_TRANSPARENCY,
            trashcount = DEFAULT_TRASH_COUNT,
            autoHideConditions = {
                mounted = true,
                fishingBuff = true
            },
            minimap = {
                show = true,
                position = 225,
                radius = 90
            },
            transparency = DEFAULT_FRAME_TRANSPARENCY,
        },
        ui = {
            width = DEFAULT_FRAME_WIDTH,
            height = DEFAULT_FRAME_HEIGHT,
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = -290,
            scale = DEFAULT_SCALE
        },
        globalStatsUI = {
            point = "TOP",
            relativePoint = "TOP",
            x = 300,
            y = -290,
            scale = DEFAULT_SCALE
        }
    }

    -- Initialize the database
    FishingTrackerDB = FishingTrackerDB or {}

    -- Merge saved data with defaults
    for k, v in pairs(defaults) do
        if FishingTrackerDB[k] == nil then
            FishingTrackerDB[k] = v
        elseif type(v) == "table" then
            for subk, subv in pairs(v) do
                if FishingTrackerDB[k][subk] == nil then
                    FishingTrackerDB[k][subk] = subv
                end
            end
        end
    end

    -- Set our local db reference
    db = FishingTrackerDB

    -- Migration for existing zone data to add mapID
    for zoneKey, zoneData in pairs(db.zoneData) do
        if not zoneData.mapID then
            -- Try to extract zone name to lookup mapID
            local zoneName = zoneKey:match("^(.-) %-") or zoneKey
            local mapID = 0

            -- Try to find the mapID (this is a simplified approach)
            for id = 1, 3000 do  -- Reasonable upper limit for map IDs
                local mapInfo = C_Map.GetMapInfo(id)
                if mapInfo and mapInfo.name == zoneName then
                    mapID = id
                    break
                end
            end

            zoneData.mapID = mapID
        end
    end

    MigrateZoneFormat()
    MigrateZoneData()
    CleanupZoneData()
    MigrateZoneNames()
    MigrateZoneDisplayNames()

    return db
end

-- Initialize DB immediately
db = InitializeDB()

--------------------------------------------------------------------------------------------------------------
-- 3. DEBUG FRAME
--------------------------------------------------------------------------------------------------------------
local debugFrame = CreateFrame("Frame", "FishingTrackerDebugFrame", UIParent, "BackdropTemplate")
debugFrame:SetSize(500, 300)
debugFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
debugFrame:SetMovable(true)
debugFrame:EnableMouse(true)
debugFrame:RegisterForDrag("LeftButton")
debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
debugFrame:Hide()

-- Debug Frame styling
debugFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 0.1, edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
debugFrame:SetBackdropColor(0.1, 0.1, 0.2, db.config.transparency)
debugFrame:SetBackdropBorderColor(0.4, 0.4, 0.5)

-- Debug Frame Title Bar
local debugTitleBar = CreateFrame("Frame", nil, debugFrame, "BackdropTemplate")
debugTitleBar:SetPoint("TOPLEFT", debugFrame, "TOPLEFT", 2, -2)
debugTitleBar:SetPoint("TOPRIGHT", debugFrame, "TOPRIGHT", -2, -2)
debugTitleBar:SetHeight(20)
debugTitleBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 0.1, edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
debugTitleBar:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)
debugTitleBar:SetBackdropBorderColor(0.4, 0.4, 0.5)

-- Debug Frame Title Text
local debugTitleText = debugTitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugTitleText:SetPoint("CENTER", debugTitleBar, "CENTER", 0, 0)
debugTitleText:SetText(L["FISHING_TRACKER_DEBUG_OUTPUT"])
debugTitleText:SetTextColor(1, 1, 1)

-- Debug Frame Close Button
local debugCloseButton = CreateFrame("Button", nil, debugTitleBar)
debugCloseButton:SetPoint("RIGHT", debugTitleBar, "RIGHT", -1, 0)
debugCloseButton:SetSize(15, 15)
debugCloseButton:SetScript("OnClick", function() debugFrame:Hide() end)

-- Debug Frame Normal Texture
local normalTexture = debugCloseButton:CreateTexture(nil, "BACKGROUND")
normalTexture:SetTexture(PNG_CLOSE_BUTTON[1])
normalTexture:SetAllPoints()
debugCloseButton:SetNormalTexture(normalTexture)

-- Debug Frame Highlight Texture
local highlightTexture = debugCloseButton:CreateTexture(nil, "HIGHLIGHT")
highlightTexture:SetTexture(PNG_CLOSE_BUTTON[2])
highlightTexture:SetAllPoints()
debugCloseButton:SetHighlightTexture(highlightTexture)

-- Debug Frame Pushed Texture
local pushedTexture = debugCloseButton:CreateTexture(nil, "BACKGROUND")
pushedTexture:SetTexture(PNG_CLOSE_BUTTON[3])
pushedTexture:SetAllPoints()
debugCloseButton:SetPushedTexture(pushedTexture)

-- Debug Scroll Frame
local debugScrollFrame = CreateFrame("ScrollFrame", nil, debugFrame, "UIPanelScrollFrameTemplate")
debugScrollFrame:SetPoint("TOPLEFT", debugTitleBar, "BOTTOMLEFT", 10, -1)
debugScrollFrame:SetPoint("BOTTOMRIGHT", debugFrame, "BOTTOMRIGHT", -25, 1)

-- Debug Scroll Child
local debugScrollChild = CreateFrame("Frame")
debugScrollFrame:SetScrollChild(debugScrollChild)
debugScrollChild:SetWidth(480)
debugScrollChild:SetHeight(1)

-- Debug Text
debugFrame.debugText = debugScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugFrame.debugText:SetFont(FRAME_FONT_ID[1], 12)
debugFrame.debugText:SetPoint("TOPLEFT", 0, 0)
debugFrame.debugText:SetJustifyH("LEFT")
debugFrame.debugText:SetTextColor(1, 1, 1)
debugFrame.debugText:SetText(L["DEBUG_OUTPUT_APPEAR"])

-- Debug message buffer
local debugMessages = {}

-- Function to add debug messages
local function AddDebugMessage(message)
    if not DEFAULT_DEBUG then return end

    -- Get precise time (seconds since game started) and convert to HH:MM:SS format
    local seconds = GetTime()
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    local timestamp = format("|cFFC8C8C8[%02d:%02d:%02d]|r ", hours, minutes, secs)
    local fullMessage = timestamp..message

    -- Clear the buffer if we've reached capacity
    if #debugMessages >= DEFAULT_MAX_DEBUG_MESSAGES then
        -- Instead of clearing completely, remove the oldest 10% of messages
        local removeCount = math.floor(DEFAULT_MAX_DEBUG_MESSAGES * 0.1)
        for i = 1, removeCount do
            table.remove(debugMessages, 1)
        end
    end

    -- Add the new message
    table.insert(debugMessages, fullMessage)

    -- Update the debug display
    local debugText = table.concat(debugMessages, "\n")
    debugFrame.debugText:SetText(debugText)

    -- Update scroll child height
    local totalHeight = debugFrame.debugText:GetStringHeight()
    debugScrollChild:SetHeight(totalHeight)
    debugScrollFrame:UpdateScrollChildRect()

    -- Auto-scroll to bottom
    debugScrollFrame:SetVerticalScroll(totalHeight)
end

-- Initialize debug frame visibility based on debug mode
-- ##### DEBUG #####
if DEFAULT_DEBUG then
    debugFrame:Show()
else
    debugFrame:Hide()
end
-- #################

--------------------------------------------------------------------------------------------------------------
-- 4. CORE FUNCTIONS
--------------------------------------------------------------------------------------------------------------
local function GetLocalizedString(key)
    return L[key] or key -- Fallback to the key if translation missing
end

local function formatNumberWithCommas(num)
    if not num then return "0" end
    local formatted = tostring(num)
    local k = #formatted
    while k > 3 do
        formatted = formatted:sub(1, k-3) .. "," .. formatted:sub(k-2)
        k = k - 3
    end
    return formatted
end

-- Function to update background settings
local function UpdateBackgroundSettings()
    if FTmainFrameBGtexture then
        if db.config.enableBackground then
            FTmainFrameBGtexture:Show()
            FTmainFrameBGtexture:SetAlpha(db.config.backgroundAlpha or 0.2)
        else
            FTmainFrameBGtexture:Hide()
        end
    end
end

local function IsRareFish(itemID)
    return itemID and FT_RareFishIDs[itemID] or false
end

local function IsSpecialFish(itemID)
    return itemID and FT_SpecialFishIDs[itemID] or false
end

local function IsJunkItems(itemID)
    return itemID and FT_JunkItemsIDs[itemID] or false
end

local function IsNotJunkItems(itemID)
    return itemID and FT_NotJunkItemsIDs[itemID] or false
end

local function CreateColumns(parent, numColumns, width, height, spacing)
    local columns = {}
    local totalWidth = parent:GetWidth() - 20 -- Account for padding

    for i = 1, numColumns do
        local column = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        column:SetSize(width, height)

        if i == 1 then
            column:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
        else
            column:SetPoint("TOPLEFT", columns[i-1], "TOPRIGHT", spacing, 0)
        end
--[[
        -- Optional styling
        column:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 0.1, edgeSize = 0.1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        column:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
]]
        columns[i] = column
    end

    return columns
end

local function GetSkillLevel(skillLineID)
    local skillRank, skillMax = 0, 0
    local professions = {GetProfessions()}
    for _, profIndex in ipairs(professions) do
        local _, _, rank, max, _, _, skillLine = GetProfessionInfo(profIndex)
        if skillLine == skillLineID then
            skillRank = rank
            skillMax = max
            break
        end
    end
    return skillRank, skillMax
end

local function GetMinimapPosition(angle)
    angle = angle or math.rad(db.config.minimap.position or 225)
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local radius = db.config.minimap.radius or 90

    local effectiveRadius = radius
    if minimapShape == "SQUARE" or minimapShape == "CORNER-TOPRIGHT" or minimapShape == "CORNER-TOPLEFT" 
        or minimapShape == "CORNER-BOTTOMRIGHT" or minimapShape == "CORNER-BOTTOMLEFT" then
        effectiveRadius = (radius * 1.4142)
    end

    local Radiusx = math.cos(angle) * effectiveRadius
    local Radiusy = math.sin(angle) * effectiveRadius

    return Radiusx, Radiusy, effectiveRadius
end

local function UpdateMinimapButtonPosition()
    local angle = math.rad(db.config.minimap.position or 225)
    local Radiusx, Radiusy, effectiveRadius = GetMinimapPosition(angle)

    local buttonSizeOffset = 16
    local finalX = Radiusx + (Radiusx / effectiveRadius) * buttonSizeOffset
    local finalY = Radiusy + (Radiusy / effectiveRadius) * buttonSizeOffset

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", finalX, finalY)
end

local function CountTableEntries(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

local function GetZoneKey()
    local zone = GetRealZoneText() or L["UNKNOWN_ZONE"]
    local subzone = GetMinimapZoneText() or zone
    local mapID = C_Map.GetBestMapForUnit("player") or 0

    local displayZone = zone -- Create a separate variable for display purposes

    -- Special handling for duplicate zones
    if zone == L["DALARAN"] then
        if mapID == 41 then
            displayZone = L["DALARAN_(DEADWIND_PASS)"]
        elseif mapID == 125 or mapID == 126 then
            displayZone = L["DALARAN_(NORTHREND)"]
        elseif mapID == 501 or mapID == 502 then
            displayZone = L["DALARAN_(EASTERN_KINGDOMS)"]
        elseif mapID == 627 or mapID == 628 then
            displayZone = L["DALARAN_(BROKEN_ISLES)"]
        elseif mapID == 2305 or mapID == 2306 or mapID == 2307 then
            displayZone = L["DALARAN_(SCENARIO)"]
        end
    elseif zone == L["SHADOWMOON_VALLEY"] then
        if mapID == 104 then
            displayZone = L["SHADOWMOON_VALLEY_(OUTLAND)"]
        elseif mapID == 539 then
            displayZone = L["SHADOWMOON_VALLEY_(DRAENOR)"]
        end
    elseif zone == L["NAGRAND"] then
        if mapID == 107 then
            displayZone = L["NAGRAND_(OUTLAND)"]
        elseif mapID == 550 then
            displayZone = L["NAGRAND_(DRAENOR)"]
        end
    end

    -- Clean up subzone if it's the same as zone
    if subzone == zone then
        subzone = zone
    end

    -- If we have a mapID but still have "Unknown Zone", try to get name from map
    if (zone == L["UNKNOWN_ZONE"] or subzone == L["UNKNOWN_ZONE"]) and mapID > 0 then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo then
            zone = mapInfo.name
            subzone = mapInfo.name
            displayZone = zone
        end
    end

    return format("%s - %s [%d]", displayZone, subzone, mapID), mapID, zone, subzone, displayZone
end

local function PlayRareFishSound()
    if db.config.enableSound then
        PlaySoundFile(MP3_FISH_SOUND[2], "Master")
    end
end

local function PlayQuestFishSound()
    if db.config.enableSound then
        PlaySoundFile(MP3_FISH_SOUND[1], "Master")
    end
end

local function GetFishColor(itemID)
    if not itemID then return FT_QualityColorsIDs[1].hex end  -- Default if no ID

    local itemName, itemLink, quality, _, _, itemType, itemSubType = GetItemInfo(itemID)
    -- First check if it's a known rare fish (priority over regular quality)
    if IsRareFish(itemID) then
        return FT_QualityColorsIDs[8].hex -- RARE_FISH (yellow)
    elseif IsSpecialFish(itemID) then
        return FT_QualityColorsIDs[9].hex -- SPECIAL_FISH (light yellow)
    elseif itemType == L["QUEST"] or itemSubType == L["QUEST"] then
        return FT_QualityColorsIDs[10].hex -- Quest Item (light pink)
    elseif quality and FT_QualityColorsIDs[quality] then
        return FT_QualityColorsIDs[quality].hex
    end

    -- Default to white
    return FT_QualityColorsIDs[1].hex
end

local function CopyTable(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = CopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function HasFishingBuff()
    -- Check for the main fishing buff
    if C_UnitAuras.GetPlayerAuraBySpellID(FISHING_BUFF_SPELL_ID) then
        return true
    end
    return false
end

local function GetCurrentZoneData()
    local instanceName, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    local CurrentZoneData = private.zoneExpansionSkillMap[instanceMapID] or { expansion = L["FISHING"], skillLineID = 356 }
    return CurrentZoneData, instanceMapID
end

local function GetFishingPoleBonus()
    local baseBonus = 0
    local CurrentZoneData = GetCurrentZoneData()
    local expansionName = CurrentZoneData.expansion
    local expansionskillLineID = CurrentZoneData.skillLineID

    -- First check profession equipment slot (new system)
    local PROFESSION_TOOL_SLOT = 28
    local itemID = GetInventoryItemID("player", PROFESSION_TOOL_SLOT)
    if itemID and FT_FishingPolesIDs[itemID] then
        if itemID == 198225 and expansionskillLineID == 2826 then
            baseBonus = 6
        else
            baseBonus = FT_FishingPolesIDs[itemID]
        end
    end

    return baseBonus
end

local function GetFishingHatBonus()
    local HatBase = 0
    local CurrentZoneData = GetCurrentZoneData()
    local expansionName = CurrentZoneData.expansion
    local expansionskillLineID = CurrentZoneData.skillLineID

    -- First check profession equipment slot (new system)
    local PROFESSION_TOOL_SLOT = 1
    local itemID = GetInventoryItemID("player", PROFESSION_TOOL_SLOT)
    if itemID and FT_FishingHatBuffIDs[itemID] then
        if itemID == 193529 and expansionskillLineID == 2826 then
            HatBase = 4
        else
            HatBase = FT_FishingHatBuffIDs[itemID]
        end
    end

    return HatBase
end

local function GetFishingSkillBuffBonus()
    local totalequipBonus = 0
    local CurrentZoneData = GetCurrentZoneData()
    local expansionName = CurrentZoneData.expansion
    local expansionskillLineID = CurrentZoneData.skillLineID

    for spellID, equipBonus in pairs(FT_FishingSkillBuffIDs) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            totalequipBonus = totalequipBonus + equipBonus
        end
    end

    return totalequipBonus
end

local function GetFishingToysBuffBonus()
    local totalBonus = 0

    for spellID, Bonus in pairs(FT_FishingToysBuffIDs) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            totalBonus = totalBonus + Bonus
        end
    end

    return totalBonus
end

local function GetFishingPoleEnchantBonus()
    -- Known fishing enchant IDs and their bonuses
    local FISHING_ENCHANTS = {
        [5930] = 6,  -- Undercurrent +6
        [5931] = 5,  -- Angler +5
        [846] = 3,   -- Minor Fishing +3
        [849] = 2,   -- Lesser Fishing +2
        [851] = 1    -- Fishing +1
    }

    local totalBonus = 0

    -- Check both profession slot#(28) & slot#(10)
    for _, slot in ipairs({28, 10}) do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            -- Method 1: Check enchant ID directly
            local _, _, _, _, _, _, _, _, _, _, enchantID = strsplit(":", itemLink)
            enchantID = tonumber(enchantID)

            if enchantID and FISHING_ENCHANTS[enchantID] then
                totalBonus = totalBonus + FISHING_ENCHANTS[enchantID]
            else
                -- Method 2: Deep scan tooltip text
                local tooltip = CreateFrame("GameTooltip", "FishingTrackerScanTooltip", nil, "GameTooltipTemplate")
                tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                tooltip:SetInventoryItem("player", slot)

                -- Look for the enchant line specifically
                for i = 3, tooltip:NumLines() do
                    local line = _G["FishingTrackerScanTooltipTextLeft"..i]
                    local text = line and line:GetText()
                    if text then
                        -- Match various possible enchant text formats
                        local EnchantBonus = text:match(L["ENCHANTED"].." %+(%d+) "..L["FISHING"])
                        local LureBonus = text:match(L["FISHING_LURE"].." %(%+(%d+) "..L["FISHING_SKILL"].."%)")
                        -- local DragonBonus = text:match(L["EQUIP"].." %+(%d+) "..L["DRAGON_ISLES_FISHING_SKILL"])
                        -- local OnEquipBonus = text:match(L["EQUIP"].." "..L["ON_EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                        -- local EquipBonus = text:match(L["EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
--[[
                        if isZhCN then
                            -- Match various possible Simplified Chinese enchant text formats
                            local EnchantBonus = text:match(L["ENCHANTED"].." %+(%d+) "..L["FISHING"])
                            local LureBonus = text:match(L["FISHING_LURE"].." %(%+(%d+) "..L["FISHING_SKILL"].."%)")
                            -- local DragonBonus = text:match(L["EQUIP"].." %+(%d+) "..L["DRAGON_ISLES_FISHING_SKILL"])
                            -- local OnEquipBonus = text:match(L["EQUIP"].." "..L["ON_EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                            -- local EquipBonus = text:match(L["EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                        elseif isZhTW then
                            -- Match various possible Traditional Chinese enchant text formats
                            local EnchantBonus = text:match(L["ENCHANTED"].." %+(%d+) "..L["FISHING"])
                            local LureBonus = text:match(L["FISHING_LURE"].." %(%+(%d+) "..L["FISHING_SKILL"].."%)")
                            -- local DragonBonus = text:match("裝備：%+(%d+)點巨龍群島釣魚技能")
                            -- local OnEquipBonus = text:match(L["EQUIP"].." "..L["ON_EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                            -- local EquipBonus = text:match(L["EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                        else
                            -- Match various possible enchant text formats
                            local EnchantBonus = text:match(L["ENCHANTED"].." %+(%d+) "..L["FISHING"])
                            local LureBonus = text:match(L["FISHING_LURE"].." %(%+(%d+) "..L["FISHING_SKILL"].."%)")
                            local DragonBonus = text:match(L["EQUIP"].." %+(%d+) "..L["DRAGON_ISLES_FISHING_SKILL"])
                            -- local OnEquipBonus = text:match(L["EQUIP"].." "..L["ON_EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                            -- local EquipBonus = text:match(L["EQUIP"].." %+(%d+) "..L["FISHING_SKILL"])
                        end
]]
                        -- Skip OnEquipBonus if this is the Strong Fishing Pole in slot 28
                        local OnEquipBonus
                        if slot == 28 and GetInventoryItemID("player", slot) == 6365 then
                            OnEquipBonus = 0
                        end

                        if EnchantBonus or OnEquipBonus or LureBonus then
                            EnchantBonus = tonumber(EnchantBonus) or 0
                            OnEquipBonus = tonumber(OnEquipBonus) or 0
                            LureBonus = tonumber(LureBonus) or 0

                            local CurrentZoneData = GetCurrentZoneData()
                            local expansionskillName = CurrentZoneData.expansion
                            local expansionskillLineID = CurrentZoneData.skillLineID
                            local mapID = C_Map.GetBestMapForUnit("player") or 0

                            if expansionskillLineID == 2592 and mapID == 407 then
                                local professions = {GetProfessions()}
                                -- Check if the 4th profession exists
                                if professions[4] ~= nil then
                                    local name, icon, curLv, maxLv, numAbil, offset, SL, _, _, _, currName = GetProfessionInfo(professions[4])
                                    if currName == nil then currName = name end
                                    expansionskillName = currName or L["UNKNOWN_FISHING"]

                                    if expansionskillName == "Classic Fishing" then expansionskillLineID = 2592
                                    elseif expansionskillName == "Outland Fishing" then expansionskillLineID = 2591
                                    elseif expansionskillName == "Northrend Fishing" then expansionskillLineID = 2590
                                    elseif expansionskillName == "Cataclysm Fishing" then expansionskillLineID = 2589
                                    elseif expansionskillName == "Pandaria Fishing" then expansionskillLineID = 2588
                                    elseif expansionskillName == "Draenor Fishing" then expansionskillLineID = 2587
                                    elseif expansionskillName == "Legion Fishing" then expansionskillLineID = 2586
                                    elseif expansionskillName == "Kul Tiran Fishing" then expansionskillLineID = 2585
                                    elseif expansionskillName == "Shadowlands Fishing" then expansionskillLineID = 2754
                                    elseif expansionskillName == "Dragon Isles Fishing" then expansionskillLineID = 2826
                                    elseif expansionskillName == "Khaz Algar Fishing" then expansionskillLineID = 2876
                                    end
                                end
                            end

                            if CurrentZoneData then
                                if expansionskillLineID == 2826 then
                                    totalBonus = totalBonus + EnchantBonus + OnEquipBonus + LureBonus
                                else
                                    totalBonus = totalBonus + EnchantBonus + OnEquipBonus + LureBonus
                                end
                            end
                        end
                    end
                end
                tooltip:Hide()
            end
        end
    end

    return totalBonus
end

-- Debug function to check header text status
local function DebugHeaderStatus()
    if not DEFAULT_DEBUG then return end

    AddDebugMessage("=== GLOBAL STATS HEADER DEBUG ===")
    AddDebugMessage("Global stats frame exists: " .. tostring(globalStatsFrame ~= nil))

    if globalStatsFrame then
        AddDebugMessage("Header text exists: " .. tostring(globalStatsFrame.headerText ~= nil))
        if globalStatsFrame.headerText then
            AddDebugMessage("Header text: " .. tostring(globalStatsFrame.headerText:GetText() or "NIL"))
            AddDebugMessage("Header visible: " .. tostring(globalStatsFrame.headerText:IsVisible()))
            AddDebugMessage("Header shown: " .. tostring(globalStatsFrame.headerText:IsShown()))
            AddDebugMessage("Header parent: " .. tostring(globalStatsFrame.headerText:GetParent() and "exists" or "NIL"))
            AddDebugMessage("Header width: " .. tostring(globalStatsFrame.headerText:GetWidth()))
            AddDebugMessage("Header height: " .. tostring(globalStatsFrame.headerText:GetHeight()))
        else
            AddDebugMessage("Header text is NIL")
        end
    else
        AddDebugMessage("Global stats frame is NIL - frame not created yet")
    end
    AddDebugMessage("=== END HEADER DEBUG ===")
end

-- Call debug after frame creation
C_Timer.After(1, DebugHeaderStatus)
C_Timer.After(3, DebugHeaderStatus)
C_Timer.After(5, DebugHeaderStatus)

-- Create Event Frame First
local eventFrame = CreateFrame("Frame")

--------------------------------------------------------------------------------------------------------------
-- 5. GLOBAL STATS FRAME
--------------------------------------------------------------------------------------------------------------
local globalStatsFrame = CreateFrame("Frame", "FishingTrackerGlobalStatsFrame", UIParent, "BackdropTemplate")
globalStatsFrame:SetSize(DEFAULT_FRAME_WIDTH, DEFAULT_FRAME_HEIGHT + 200)
globalStatsFrame:SetPoint(db.globalStatsUI.point, UIParent, db.globalStatsUI.relativePoint, db.globalStatsUI.x, db.globalStatsUI.y)
globalStatsFrame:SetMovable(true)
globalStatsFrame:EnableMouse(true)
globalStatsFrame:RegisterForDrag("LeftButton")
globalStatsFrame:SetScript("OnDragStart", function(self)
    if not db.config.frameLocked then
        self:StartMoving()
    end
end)

globalStatsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, _, relativePoint, x, y = globalStatsFrame:GetPoint()

    -- Get current frame position relative to screen
    local left = self:GetLeft()
    local top = self:GetTop()
    local screenHeight = UIParent:GetHeight()

    -- Calculate offset from TOP center
    local screenCenterX = UIParent:GetWidth() / 2
    local frameCenterX = left + (self:GetWidth() / 2)

    -- print(format("point:%s, relativePoint:%s | X:%d, Y:%d", point, relativePoint, x, y))

    -- Save as TOP anchor
    db.globalStatsUI.point = "TOP"
    db.globalStatsUI.relativePoint = "TOP"
    db.globalStatsUI.x = frameCenterX - screenCenterX
    db.globalStatsUI.y = top - screenHeight  -- TOP anchor uses negative y values

    -- print(format("db.globalStatsUI.point:%s, db.globalStatsUI.relativePoint:%s |db.globalStatsUI.x:%d, db.globalStatsUI.y:%d", db.globalStatsUI.point, db.globalStatsUI.relativePoint, db.globalStatsUI.x, db.globalStatsUI.y))

    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage(format(">>> GlobalStatsFrame position saved: TOP anchor, x=%d, y=%d (top=%d, screenHeight=%d) <<<", 
            db.globalStatsUI.x, db.globalStatsUI.y, top, screenHeight))
    end
    -- #################
end)

globalStatsFrame:SetScale(db.globalStatsUI.scale)
globalStatsFrame:Hide()

-- Global Frame Styling
globalStatsFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 0.1, edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
globalStatsFrame:SetBackdropColor(0.1, 0.1, 0.2, db.config.transparency)
globalStatsFrame:SetBackdropBorderColor(0.4, 0.4, 0.5)

-- Global Frame Title Bar
local globalTitleBar = CreateFrame("Frame", nil, globalStatsFrame, "BackdropTemplate")
globalTitleBar:SetPoint("TOPLEFT", globalStatsFrame, "TOPLEFT", 2, -2)
globalTitleBar:SetPoint("TOPRIGHT", globalStatsFrame, "TOPRIGHT", -2, -2)
globalTitleBar:SetHeight(20)
globalTitleBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 0.1, edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
globalTitleBar:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)
globalTitleBar:SetBackdropBorderColor(0.4, 0.4, 0.5)

-- Global Frame Title Text
local globalTitleText = globalTitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
globalTitleText:SetFont(FRAME_FONT_ID[2], 13)
globalTitleText:SetPoint("LEFT", globalTitleBar, "LEFT", 2, 0)
globalTitleText:SetText(L["FISHING_TRACKER_GLOBAL_FISH_STATISTICS"])
globalTitleText:SetTextColor(1, 1, 1)

-- Global Frame Close Button
local globalCloseButton = CreateFrame("Button", nil, globalTitleBar)
globalCloseButton:SetPoint("RIGHT", globalTitleBar, "RIGHT", -1, 0)
globalCloseButton:SetSize(15, 15)
globalCloseButton:SetScript("OnClick", function() globalStatsFrame:Hide() end)

-- Global Frame Normal Texture
local normalTexture = globalCloseButton:CreateTexture(nil, "BACKGROUND")
normalTexture:SetTexture(PNG_CLOSE_BUTTON[1])
normalTexture:SetAllPoints()
globalCloseButton:SetNormalTexture(normalTexture)

-- Global Frame Highlight Texture
local highlightTexture = globalCloseButton:CreateTexture(nil, "HIGHLIGHT")
highlightTexture:SetTexture(PNG_CLOSE_BUTTON[2])
highlightTexture:SetAllPoints()
globalCloseButton:SetHighlightTexture(highlightTexture)

-- Global Frame Pushed Texture
local pushedTexture = globalCloseButton:CreateTexture(nil, "BACKGROUND")
pushedTexture:SetTexture(PNG_CLOSE_BUTTON[3])
pushedTexture:SetAllPoints()
globalCloseButton:SetPushedTexture(pushedTexture)

-- Global Stats Header Frame (Fixed - no scrolling) - REDUCED HEIGHT
local globalHeaderFrame = CreateFrame("Frame", "FishingTrackerGlobalHeader", globalStatsFrame)
globalHeaderFrame:SetPoint("TOPLEFT", globalTitleBar, "BOTTOMLEFT", 10, -5)
globalHeaderFrame:SetPoint("TOPRIGHT", globalStatsFrame, "TOPRIGHT", -10, -5)
globalHeaderFrame:SetHeight(40) -- REDUCED from 80 to 40

-- Global Stats Header Text - COMPACT LAYOUT
globalStatsFrame.headerText = globalHeaderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
globalStatsFrame.headerText:SetFont(FRAME_FONT_ID[1], 10)
globalStatsFrame.headerText:SetPoint("TOPLEFT", globalHeaderFrame, "TOPLEFT", 0, 12)
globalStatsFrame.headerText:SetJustifyH("LEFT")
globalStatsFrame.headerText:SetJustifyV("TOP")
globalStatsFrame.headerText:SetTextColor(1, 1, 1) -- Bright white for visibility
globalStatsFrame.headerText:SetNonSpaceWrap(true)

-- Function to safely initialize header
local function SafeInitializeHeader()
    if not globalStatsFrame or not globalStatsFrame.headerText then
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage("Header not ready for initialization")
        end
        -- #################
        return false
    end

    local totalFish = db and db.totalCaught or 0
    local fishTypes = CountTableEntries(db and db.fishData or {})
    local zones = CountTableEntries(db and db.zoneData or {})

    local headerText = format("\n"..L["FISHING_STATISTICS_SUMMARY"].."\n"..L["TOTAL_FISH_CAUGHT"].." |cFF00FF00%s|r\n"..L["TOTAL_FISH_TYPES"].." |cFF00FF00%d|r\n"..L["TOTAL_ZONES"].." |cFF00FF00%d|r", 
        formatNumberWithCommas(totalFish), 
        formatNumberWithCommas(fishTypes), 
        formatNumberWithCommas(zones))

    globalStatsFrame.headerText:SetText(headerText)
    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage("Header initialized successfully")
        AddDebugMessage("Header text set to: " .. headerText:gsub("\n", "\\n"))
    end
    -- #################

    return true
end

-- Try to initialize header multiple times
local initAttempts = 0
local maxAttempts = 10

local function TryInitializeHeader()
    initAttempts = initAttempts + 1
    if SafeInitializeHeader() then
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage("Header initialization successful on attempt " .. initAttempts)
        end
        -- #################
        return
    elseif initAttempts < maxAttempts then
        C_Timer.After(0.5, TryInitializeHeader)
    else
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage("Header initialization failed after " .. maxAttempts .. " attempts")
        end
        -- #################
    end
end

-- Start initialization attempts
TryInitializeHeader()

-- Global Scroll Frame for data only (starts below header) - ADJUSTED POSITION
local globalScrollFrame = CreateFrame("ScrollFrame", nil, globalStatsFrame, "UIPanelScrollFrameTemplate")
globalScrollFrame:SetPoint("TOPLEFT", globalHeaderFrame, "BOTTOMLEFT", 0, 0)
globalScrollFrame:SetPoint("BOTTOMRIGHT", globalStatsFrame, "BOTTOMRIGHT", 0, 20) -- Leave space for sort buttons

-- Custom scroll speed adjustment
globalScrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local scrollBar = self.ScrollBar or _G[self:GetName().."ScrollBar"]
    if scrollBar then
        local currentValue = scrollBar:GetValue()
        local minValue, maxValue = scrollBar:GetMinMaxValues()

        -- Adjust this value to change scroll speed (higher = faster scrolling)
        local scrollStep = 25

        if delta > 0 then
            scrollBar:SetValue(math.max(minValue, currentValue - scrollStep))
        else
            scrollBar:SetValue(math.min(maxValue, currentValue + scrollStep))
        end
    end
end)

-- Global Scroll Child
local globalScrollChild = CreateFrame("Frame")
globalScrollFrame:SetScrollChild(globalScrollChild)
globalScrollChild:SetWidth(DEFAULT_FRAME_WIDTH - 30) -- Account for scrollbar
globalScrollChild:SetHeight(1) -- Will be updated dynamically

-- Global Scroll Bar adjustments
globalScrollFrame.ScrollBar:ClearAllPoints()
globalScrollFrame.ScrollBar:SetPoint("TOPLEFT", globalScrollFrame, "TOPRIGHT", -17, -16)
globalScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", globalScrollFrame, "BOTTOMRIGHT", -17, 16)

-- Global Stats Content (this will be inside the scroll frame)
globalStatsFrame.fishDataText = globalScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
globalStatsFrame.fishDataText:SetFont(FRAME_FONT_ID[1], 10)
globalStatsFrame.fishDataText:SetPoint("TOPLEFT", 0, 0)
globalStatsFrame.fishDataText:SetJustifyH("LEFT")
globalStatsFrame.fishDataText:SetTextColor(0.8, 0.8, 1)

-- ===== ADD THE TEST CODE RIGHT HERE =====
-- Test: Force show the header when frame is shown
globalStatsFrame:HookScript("OnShow", function()
    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage("Global stats frame shown - forcing header update")
    end
    -- #################
    SafeInitializeHeader()

    -- Force the header to be visible
    if globalStatsFrame.headerText then
        globalStatsFrame.headerText:Show()
        globalStatsFrame.headerText:SetAlpha(1) -- Ensure full opacity
    end
end)
-- ===== END OF TEST CODE =====

FishingTrackerGlobalStatsFrame:Hide()

--------------------------------------------------------------------------------------------------------------
-- 6. UPDATE GLOBAL STATS DISPLAY
--------------------------------------------------------------------------------------------------------------
-- Define all functions and buttons in a local scope
do
    -- Local references to ensure they're available in this scope
    local UpdateGlobalFishStatsDisplay
    local UpdateGlobalZoneStatsDisplay
    local UpdateGlobalStatsDisplay
    local UpdateSortButtonStates

    -- Sort mode tracking
    globalStatsFrame.sortMode = globalStatsFrame.sortMode or "fish" -- Default to fish sorting

    -- Function to initialize header with current data
    local function InitializeHeaderText()
        if not db then return end

        local totalFish = db.totalCaught or 0
        local fishTypes = CountTableEntries(db.fishData or {})
        local zones = CountTableEntries(db.zoneData or {})

        globalStatsFrame.headerText:SetText(format("\n"..L["FISHING_STATISTICS_SUMMARY"].."\n"..L["TOTAL_FISH_CAUGHT"].." |cFF00FFC8%s|r\n"..L["TOTAL_FISH_TYPES"].." |cFF00FFC8%d|r\n"..L["TOTAL_ZONES"].." |cFF00FFC8%d|r\n", 
            formatNumberWithCommas(totalFish), 
            formatNumberWithCommas(fishTypes), 
            formatNumberWithCommas(zones)))
        globalStatsFrame.headerText:Show()
    end

    -- Initialize header immediately and schedule another update after DB load
    C_Timer.After(0, InitializeHeaderText)
    C_Timer.After(2, InitializeHeaderText)

    -- Define the display functions
    UpdateGlobalFishStatsDisplay = function()
        -- Ensure header frame is visible
        globalHeaderFrame:Show()
        globalStatsFrame.headerText:Show()

        local sortedFish = {}

        -- Calculate consolidated zone counts
        local zoneTotals = {}
        local subzoneCount = 0

        for zoneKey, zoneData in pairs(db.zoneData) do
            subzoneCount = subzoneCount + 1
            local zoneName = zoneData.displayZoneName or zoneData.zoneName or zoneKey:match("^(.-) %-") or zoneKey
            if not zoneTotals[zoneName] then
                zoneTotals[zoneName] = true
            end
        end

        local zoneCount = CountTableEntries(zoneTotals)

        -- Set header content (fixed - no scrolling) - COMPACT FORMAT
        globalStatsFrame.headerText:SetText(format("\n"..L["FISHING_STATISTICS_SUMMARY"].."\n"..L["TOTAL_FISH_CAUGHT"].." |cFF00FFC8%s|r\n"..L["TOTAL_FISH_TYPES"].." |cFF00FFC8%d|r\n"..L["TOTAL_ZONES"].." |cFF00FFC8%d / %d|r\n", 
            formatNumberWithCommas(db.totalCaught), 
            formatNumberWithCommas(CountTableEntries(db.fishData)), 
            zoneCount, subzoneCount))

        -- Clear previous columns if they exist
        if globalStatsFrame.fishDataColumns then
            for _, column in ipairs(globalStatsFrame.fishDataColumns) do
                column:Hide()
            end
        end

        -- Create columns container if it doesn't exist
        if not globalStatsFrame.fishDataContainer then
            globalStatsFrame.fishDataContainer = CreateFrame("Frame", nil, globalScrollChild)
            globalStatsFrame.fishDataContainer:SetPoint("TOPLEFT", globalScrollChild, "TOPLEFT", 0, 0)
            globalStatsFrame.fishDataContainer:SetSize(globalScrollChild:GetWidth() - 20, 200)
        end

        -- Create 3 columns for the stats
        globalStatsFrame.fishDataColumns = CreateColumns(globalStatsFrame.fishDataContainer, 3, 
            (globalScrollChild:GetWidth() - 50) / 3, 200, 10)

        local startY = 0

        -- Set up column headers (inside scroll area)
        local nameHeader = globalStatsFrame.fishDataColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameHeader:SetFont(FRAME_FONT_ID[1], 10)
        nameHeader:SetPoint("TOPLEFT", globalStatsFrame.fishDataColumns[1], "TOPLEFT", -0, startY)
        nameHeader:SetJustifyH("LEFT")
        nameHeader:SetText(L["FISH_NAME"])
        nameHeader:SetTextColor(0.8, 0.8, 1)

        local countHeader = globalStatsFrame.fishDataColumns[2]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countHeader:SetFont(FRAME_FONT_ID[1], 10)
        countHeader:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[2], "TOPRIGHT", 35, startY)
        countHeader:SetJustifyH("RIGHT")
        countHeader:SetText(L["COUNT"])
        countHeader:SetTextColor(0.8, 0.8, 1)

        local percentHeader = globalStatsFrame.fishDataColumns[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        percentHeader:SetFont(FRAME_FONT_ID[1], 10)
        percentHeader:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[3], "TOPRIGHT", 10, startY)
        percentHeader:SetJustifyH("RIGHT")
        percentHeader:SetText(L["PERCENT"])
        percentHeader:SetTextColor(0.8, 0.8, 1)

        -- Prepare fish data for sorting
        for fishName, fishData in pairs(db.fishData) do
            local count = type(fishData) == "table" and fishData.count or fishData
            local itemID = type(fishData) == "table" and fishData.itemID or nil
            table.insert(sortedFish, {
                name = fishName,
                count = count,
                itemID = itemID
            })
        end

        -- Sort by count (descending)
        table.sort(sortedFish, function(a, b) return a.count > b.count end)

        -- Create text entries for each fish
        local maxRows = 0
        local rowHeight = 12
        local contentStartY = startY - 15 -- Start below headers

        for i, fish in ipairs(sortedFish) do
            local percentage = db.totalCaught > 0 and (fish.count / db.totalCaught) * 100 or 0
            local color = GetFishColor(fish.itemID)
            local displayText = color and (color..fish.name.."|r") or fish.name

            -- Fish name column with icon
            local nameTextFrame = CreateFrame("Frame", nil, globalStatsFrame.fishDataColumns[1])
            nameTextFrame:SetSize(150, rowHeight)
            nameTextFrame:SetPoint("TOPLEFT", globalStatsFrame.fishDataColumns[1], "TOPLEFT", 0, contentStartY - (i-1)*rowHeight)

            -- Fish icon
            local fishIcon = nameTextFrame:CreateTexture(nil, "OVERLAY")
            fishIcon:SetSize(12, 12)
            fishIcon:SetPoint("LEFT", nameTextFrame, "LEFT", 0, 0)

            -- Get item icon if available
            local iconTexture = nil
            if fish.itemID then
                iconTexture = GetItemIcon(fish.itemID)
            end

            if iconTexture then
                fishIcon:SetTexture(iconTexture)
            else
                fishIcon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
            end

            -- Add tooltip to show fishing pole info
            fishIcon:SetScript("OnEnter", function(self)
                if fish.itemID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(fish.itemID)
                    GameTooltip:Show()
                end
            end)

            fishIcon:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            -- Fish name column
            local nameText = globalStatsFrame.fishDataColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetFont(FRAME_FONT_ID[1], 10)
            nameText:SetPoint("TOPLEFT", globalStatsFrame.fishDataColumns[1], "TOPLEFT", 15, contentStartY - (i-1)*rowHeight)
            nameText:SetJustifyH("LEFT")
            nameText:SetTextColor(0.8, 0.8, 1)
            nameText:SetText(displayText)

            -- Count column
            local countText = globalStatsFrame.fishDataColumns[2]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countText:SetFont(FRAME_FONT_ID[1], 10)
            countText:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[2], "TOPRIGHT", 35, contentStartY - (i-1)*rowHeight)
            countText:SetJustifyH("RIGHT")
            countText:SetTextColor(0.8, 0.8, 1)
            countText:SetText(formatNumberWithCommas(fish.count))

            -- Percentage column
            local percentText = globalStatsFrame.fishDataColumns[3]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            percentText:SetFont(FRAME_FONT_ID[1], 10)
            percentText:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[3], "TOPRIGHT", 10, contentStartY - (i-1)*rowHeight)
            percentText:SetJustifyH("RIGHT")
            percentText:SetTextColor(0.8, 0.8, 1)
            percentText:SetText(format("%.1f%%", percentage))

            maxRows = i
        end

        -- Adjust container height based on content
        local containerHeight = 30 + (maxRows * rowHeight)
        globalStatsFrame.fishDataContainer:SetHeight(containerHeight)

        -- Calculate total height needed for content
        local totalHeight = containerHeight

        -- Update scroll child height
        globalScrollChild:SetHeight(totalHeight)

        -- Update scroll range
        globalScrollFrame:UpdateScrollChildRect()

        -- Reset scroll position to top
        globalScrollFrame:SetVerticalScroll(0)
    end

    UpdateGlobalZoneStatsDisplay = function()
        -- Ensure header frame is visible
        globalHeaderFrame:Show()
        globalStatsFrame.headerText:Show()

        local zoneTotals = {} -- This will consolidate totals by zone name
        local subzoneCount = 0

        -- First, consolidate all zone data by zone name and count subzones
        for zoneKey, zoneData in pairs(db.zoneData) do
            subzoneCount = subzoneCount + 1
            -- Use displayZoneName if available, otherwise fall back to zoneName
            local zoneName = zoneData.displayZoneName or zoneData.zoneName or zoneKey:match("^(.-) %-") or zoneKey
            local total = zoneData.total or 0

            if total > 0 then
                if not zoneTotals[zoneName] then
                    zoneTotals[zoneName] = {
                        name = zoneName,
                        count = 0,
                        subzones = {} -- Track subzones for debugging if needed
                    }
                end
                zoneTotals[zoneName].count = zoneTotals[zoneName].count + total
                table.insert(zoneTotals[zoneName].subzones, zoneData.subzoneName or zoneName)
            end
        end

        -- Convert to sorted array
        local sortedZones = {}
        for zoneName, zoneData in pairs(zoneTotals) do
            table.insert(sortedZones, zoneData)
        end

        local zoneCount = CountTableEntries(zoneTotals)

        -- Set header content (fixed - no scrolling)
        globalStatsFrame.headerText:SetText(format("\n"..L["ZONE_STATISTICS_SUMMARY"].."\n"..L["TOTAL_FISH_CAUGHT"].." |cFF00FFC8%s|r\n"..L["TOTAL_FISH_TYPES"].." |cFF00FFC8%d|r\n"..L["TOTAL_ZONES"].." |cFF00FFC8%d / %d|r\n", 
            formatNumberWithCommas(db.totalCaught), 
            formatNumberWithCommas(CountTableEntries(db.fishData)), 
            zoneCount, subzoneCount))

        -- Clear previous columns if they exist
        if globalStatsFrame.fishDataColumns then
            for _, column in ipairs(globalStatsFrame.fishDataColumns) do
                column:Hide()
            end
        end

        -- Create columns container if it doesn't exist
        if not globalStatsFrame.fishDataContainer then
            globalStatsFrame.fishDataContainer = CreateFrame("Frame", nil, globalScrollChild)
            globalStatsFrame.fishDataContainer:SetPoint("TOPLEFT", globalScrollChild, "TOPLEFT", 0, 0)
            globalStatsFrame.fishDataContainer:SetSize(globalScrollChild:GetWidth() - 20, 200)
        end

        -- Create 3 columns for the stats
        globalStatsFrame.fishDataColumns = CreateColumns(globalStatsFrame.fishDataContainer, 3, 
            (globalScrollChild:GetWidth() - 50) / 3, 200, 10)

        local startY = 0

        -- Set up column headers (inside scroll area)
        local nameHeader = globalStatsFrame.fishDataColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameHeader:SetFont(FRAME_FONT_ID[1], 10)
        nameHeader:SetPoint("TOPLEFT", globalStatsFrame.fishDataColumns[1], "TOPLEFT", 0, startY)
        nameHeader:SetJustifyH("LEFT")
        nameHeader:SetText(L["ZONE_NAME"])
        nameHeader:SetTextColor(0.8, 0.8, 1)

        local countHeader = globalStatsFrame.fishDataColumns[2]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countHeader:SetFont(FRAME_FONT_ID[1], 10)
        countHeader:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[2], "TOPRIGHT", 35, startY)
        countHeader:SetJustifyH("RIGHT")
        countHeader:SetText(L["COUNT"])
        countHeader:SetTextColor(0.8, 0.8, 1)

        local percentHeader = globalStatsFrame.fishDataColumns[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        percentHeader:SetFont(FRAME_FONT_ID[1], 10)
        percentHeader:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[3], "TOPRIGHT", 10, startY)
        percentHeader:SetJustifyH("RIGHT")
        percentHeader:SetText(L["PERCENT"])
        percentHeader:SetTextColor(0.8, 0.8, 1)

        -- Sort by count (descending)
        table.sort(sortedZones, function(a, b) return a.count > b.count end)

        -- Create text entries for each zone
        local maxRows = 0
        local rowHeight = 12
        local contentStartY = startY - 15 -- Start below headers

        for i, zone in ipairs(sortedZones) do
            local percentage = db.totalCaught > 0 and (zone.count / db.totalCaught) * 100 or 0
            local displayText = "|cFF00BFFF"..zone.name.."|r"

            -- Zone name column
            local nameText = globalStatsFrame.fishDataColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetFont(FRAME_FONT_ID[1], 10)
            nameText:SetPoint("TOPLEFT", globalStatsFrame.fishDataColumns[1], "TOPLEFT", 0, contentStartY - (i-1)*rowHeight)
            nameText:SetJustifyH("LEFT")
            nameText:SetTextColor(0.8, 0.8, 1)
            nameText:SetText(displayText)

            -- Count column
            local countText = globalStatsFrame.fishDataColumns[2]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countText:SetFont(FRAME_FONT_ID[1], 10)
            countText:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[2], "TOPRIGHT", 35, contentStartY - (i-1)*rowHeight)
            countText:SetJustifyH("RIGHT")
            countText:SetTextColor(0.8, 0.8, 1)
            countText:SetText(formatNumberWithCommas(zone.count))

            -- Percentage column
            local percentText = globalStatsFrame.fishDataColumns[3]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            percentText:SetFont(FRAME_FONT_ID[1], 10)
            percentText:SetPoint("TOPRIGHT", globalStatsFrame.fishDataColumns[3], "TOPRIGHT", 10, contentStartY - (i-1)*rowHeight)
            percentText:SetJustifyH("RIGHT")
            percentText:SetTextColor(0.8, 0.8, 1)
            percentText:SetText(format("%.1f%%", percentage))

            maxRows = i
        end

        -- Adjust container height based on content
        local containerHeight = 30 + (maxRows * rowHeight)
        globalStatsFrame.fishDataContainer:SetHeight(containerHeight)

        -- Calculate total height needed for content
        local totalHeight = containerHeight

        -- Update scroll child height
        globalScrollChild:SetHeight(totalHeight)

        -- Update scroll range
        globalScrollFrame:UpdateScrollChildRect()

        -- Reset scroll position to top
        globalScrollFrame:SetVerticalScroll(0)
    end

    -- Global Stats Sort Button Frame (Fixed - no scrolling)
    local SortButtonframe = CreateFrame("Frame", "SortButton", globalStatsFrame, "BackdropTemplate")
    SortButtonframe:SetSize(DEFAULT_FRAME_WIDTH, 20)
    SortButtonframe:SetPoint("BOTTOM", globalStatsFrame, "BOTTOM", 0, 0)
    SortButtonframe:SetFrameLevel(globalStatsFrame:GetFrameLevel() + 1)
    SortButtonframe:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 0.1, edgeSize = 0.1,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })

    SortButtonframe:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)
    SortButtonframe:SetBackdropBorderColor(0.4, 0.4, 0.5)

    -- Custom Sort Fish Button
    local sortFishBtn = CreateFrame("Button", nil, SortButtonframe)
    sortFishBtn:SetSize(80, 18)
    sortFishBtn:SetPoint("LEFT", SortButtonframe, "LEFT", 20, 0)

    -- Sort Fish Button Normal Texture
    local sortFishNormal = sortFishBtn:CreateTexture(nil, "BACKGROUND")
    sortFishNormal:SetTexture(PNG_SORT_FISH[1]) -- Your custom artwork
    sortFishNormal:SetAllPoints()
    sortFishBtn:SetNormalTexture(sortFishNormal)

    -- Sort Fish Button Highlight Texture
    local sortFishHighlight = sortFishBtn:CreateTexture(nil, "OVERLAY")
    sortFishHighlight:SetTexture(PNG_SORT_FISH[2]) -- Your custom artwork
    sortFishHighlight:SetAllPoints()
    sortFishBtn:SetHighlightTexture(sortFishHighlight)

    -- Sort Fish Button Disabled Texture
    local sortFishDisabled = sortFishBtn:CreateTexture(nil, "BACKGROUND")
    sortFishDisabled:SetTexture(PNG_SORT_FISH[3]) -- Your custom artwork
    sortFishDisabled:SetAllPoints()
    sortFishBtn:SetDisabledTexture(sortFishDisabled)

    -- Sort Fish Button Text
    local sortFishText = sortFishBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sortFishText:SetFont(FRAME_FONT_ID[2], 12)
    sortFishText:SetPoint("CENTER", sortFishBtn, "CENTER", 0, 0)
    sortFishText:SetText(L["SORT_FISH"])
    sortFishText:SetTextColor(1, 1, 1)

    -- Custom Sort Zone Button
    local sortZoneBtn = CreateFrame("Button", nil, SortButtonframe)
    sortZoneBtn:SetSize(80, 18)
    sortZoneBtn:SetPoint("RIGHT", SortButtonframe, "RIGHT", -20, 0)

    -- Sort Zone Button Normal Texture
    local sortZoneNormal = sortZoneBtn:CreateTexture(nil, "BACKGROUND")
    sortZoneNormal:SetTexture(PNG_SORT_ZONE[1]) -- Your custom artwork
    sortZoneNormal:SetAllPoints()
    sortZoneBtn:SetNormalTexture(sortZoneNormal)

    -- Sort Zone Button Highlight Texture
    local sortZoneHighlight = sortZoneBtn:CreateTexture(nil, "OVERLAY")
    sortZoneHighlight:SetTexture(PNG_SORT_ZONE[2]) -- Your custom artwork
    sortZoneHighlight:SetAllPoints()
    sortZoneBtn:SetHighlightTexture(sortZoneHighlight)

    -- Sort Zone Button Disabled Texture
    local sortZoneDisabled = sortZoneBtn:CreateTexture(nil, "BACKGROUND")
    sortZoneDisabled:SetTexture(PNG_SORT_ZONE[3]) -- Your custom artwork
    sortZoneDisabled:SetAllPoints()
    sortZoneBtn:SetDisabledTexture(sortZoneDisabled)

    -- Sort Zone Button Text
    local sortZoneText = sortZoneBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sortZoneText:SetFont(FRAME_FONT_ID[2], 12)
    sortZoneText:SetPoint("CENTER", sortZoneBtn, "CENTER", 0, 0)
    sortZoneText:SetText(L["SORT_ZONE"])
    sortZoneText:SetTextColor(1, 1, 1)

    -- Update the button scripts
    sortFishBtn:SetScript("OnClick", function()
        globalStatsFrame.sortMode = "fish"
        UpdateGlobalStatsDisplay()
    end)

    sortZoneBtn:SetScript("OnClick", function()
        globalStatsFrame.sortMode = "zone"
        UpdateGlobalStatsDisplay()
    end)

    -- Update the UpdateSortButtonStates function to handle custom buttons
    UpdateSortButtonStates = function()
        if globalStatsFrame.sortMode == "fish" then
            -- Fish view is active, so fish button should be enabled, zone button disabled
            sortFishBtn:SetEnabled(false)
            sortZoneBtn:SetEnabled(true)
            sortFishText:SetTextColor(0.5, 0.5, 0.5) -- Gray when inactive
            sortZoneText:SetTextColor(1, 1, 1) -- White when active
            -- Force disabled texture
            sortFishDisabled:Show()
            sortFishNormal:Hide()
            sortZoneDisabled:Hide()
        else
            -- Zone view is active, so zone button should be enabled, fish button disabled
            sortFishBtn:SetEnabled(true)
            sortZoneBtn:SetEnabled(false)
            sortFishText:SetTextColor(1, 1, 1) -- White when enabled
            sortZoneText:SetTextColor(0.5, 0.5, 0.5) -- Gray when disabled
            -- Hide disabled texture for zone button
            sortFishDisabled:Hide()
            sortZoneNormal:Hide()
            sortZoneDisabled:Show()
        end
    end

    UpdateGlobalStatsDisplay = function()
        UpdateSortButtonStates()

        -- Always ensure header is updated
        if globalStatsFrame.sortMode == "zone" then
            UpdateGlobalZoneStatsDisplay()
        else
            UpdateGlobalFishStatsDisplay()
        end

        -- Force header visibility
        if globalStatsFrame.headerText then
            globalStatsFrame.headerText:Show()
        end
    end

    SortButtonframe:Show()

    -- Make the main function available globally for other parts of the addon
    _G.UpdateGlobalStatsDisplay = UpdateGlobalStatsDisplay

    -- Force initial display update after DB is loaded
    C_Timer.After(3, function()
        if db then
            UpdateGlobalStatsDisplay()
        end
    end)
end

--------------------------------------------------------------------------------------------------------------
-- 7. MAIN FRAME - Modified to anchor to TOP and expand downward
--------------------------------------------------------------------------------------------------------------
local FTmainFrame = CreateFrame("Frame", "FishingTrackerFrame", UIParent, "BackdropTemplate")
FTmainFrame:SetSize(db.ui.width, db.ui.height)
FTmainFrame:SetPoint(db.ui.point, UIParent, db.ui.relativePoint, db.ui.x, db.ui.y)
FTmainFrame:SetFrameLevel(UIParent:GetFrameLevel() + 1)
FTmainFrame:SetMovable(true)
FTmainFrame:EnableMouse(true)
FTmainFrame:RegisterForDrag("LeftButton")
FTmainFrame.isLocked = db.config.frameLocked
FTmainFrame:SetScript("OnDragStart", function(self)
    if not db.config.frameLocked then
        self:StartMoving()
    end
end)

FTmainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, _, relativePoint, x, y = FTmainFrame:GetPoint()

    -- Get current frame position relative to screen
    local left = self:GetLeft()
    local top = self:GetTop()
    local screenHeight = UIParent:GetHeight()

    -- Calculate offset from TOP center
    local screenCenterX = UIParent:GetWidth() / 2
    local frameCenterX = left + (self:GetWidth() / 2)

    -- print(format("point:%s, relativePoint:%s | X:%d, Y:%d", point, relativePoint, x, y))

    -- Save as TOP anchor
    db.ui.point = "TOP"
    db.ui.relativePoint = "TOP"
    db.ui.x = frameCenterX - screenCenterX
    db.ui.y = top - screenHeight  -- TOP anchor uses negative y values

    -- print(format("db.ui.point:%s, db.ui.relativePoint:%s |db.ui.x:%d, db.ui.y:%d", db.ui.point, db.ui.relativePoint, db.ui.x, db.ui.y))

    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage(format(">>> Frame position saved: TOP anchor, x=%d, y=%d (top=%d, screenHeight=%d) <<<", 
            db.ui.x, db.ui.y, top, screenHeight))
    end
    -- #################
end)

FTmainFrame:SetScale(db.ui.scale)

-- Add Main Frame Background Texture
local FTmainFrameBGtexture = FTmainFrame:CreateTexture(nil, "BACKGROUND")
FTmainFrameBGtexture:SetAllPoints(true) -- Make it cover the entire frame
-- FTmainFrameBGtexture:SetTexture("Interface\\AddOns\\FishingTracker\\Artwork\\bg_screen.jpg")
FTmainFrameBGtexture:SetAlpha(db.config.backgroundAlpha or 0.2) -- Adjust transparency as needed (0.0 to 1.0)
UpdateBackgroundSettings()

if FTmainFrame:IsVisible() then
    FTmainFrame:Hide()
else
    FTmainFrame:Show()
end

--[[
-- Frame styling - Remove or modify the backdrop since we have a background image
FTmainFrame:SetBackdrop(nil) -- Remove the backdrop completely

-- OR keep a subtle border by modifying the backdrop:
FTmainFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
FTmainFrame:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.5) -- More transparent border
]]

-- Main Frame styling
FTmainFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 0.1, edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
FTmainFrame:SetBackdropColor(0.1, 0.1, 0.2, db.config.transparency)
FTmainFrame:SetBackdropBorderColor(0.4, 0.4, 0.5)

-- Main Frame Title Bar
local titleBar = CreateFrame("Frame", nil, FTmainFrame, "BackdropTemplate")
titleBar:SetPoint("TOPLEFT", FTmainFrame, "TOPLEFT", 2, -2)
titleBar:SetPoint("TOPRIGHT", FTmainFrame, "TOPRIGHT", -2, -2)
titleBar:SetHeight(20)
titleBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 0.1, edgeSize = 0.1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
titleBar:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)
titleBar:SetBackdropBorderColor(0.4, 0.4, 0.5)

-- Main Frame Title Text
local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetFont(FRAME_FONT_ID[2], 13)
titleText:SetPoint("LEFT", titleBar, "LEFT", 2, 0)
titleText:SetJustifyH("CENTER")
titleText:SetText("|T"..ADDON_ICON_TEXTURE..":16:16:0:0|t |T"..PNG_DOT[3]..":15:15:0:0|t "..L["FISHING_TRACKER"].." "..ADDON_VERSION.."|cFFFFFFFF"..SPACES.."|r")
titleText:SetTextColor(1, 1, 1)

local function UpdateFrameTransparency()
    if not db.config.transparency then
        db.config.transparency = DEFAULT_FRAME_TRANSPARENCY
    elseif db.config.transparency < 0.1 then
        db.config.transparency = 0.1
    elseif db.config.transparency > 1 then
        db.config.transparency = 1
    end

    FTmainFrame:SetBackdropColor(0.1, 0.1, 0.2, db.config.transparency)
    titleBar:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)

    globalStatsFrame:SetBackdropColor(0.1, 0.1, 0.2, db.config.transparency)
    globalTitleBar:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)

    debugFrame:SetBackdropColor(0.1, 0.1, 0.2, db.config.transparency)
    debugTitleBar:SetBackdropColor(0.3, 0.3, 0.4, db.config.transparency + 0.2 > 1 and 1 or db.config.transparency + 0.2)
end

-- Main Frame Trash Count Button
local TrashCountButton = CreateFrame("Button", "ARTWORK", titleBar)
TrashCountButton:SetPoint("RIGHT", titleBar, "RIGHT", -70, 0)
TrashCountButton:SetSize(15, 15)

-- Function to update trash count texture
local function UpdateTrashCountTexture()
    local TrashCountTexture = TrashCountButton:GetNormalTexture()
    if not TrashCountTexture then
        TrashCountTexture = TrashCountButton:CreateTexture(nil, "BACKGROUND")
        TrashCountTexture:SetAllPoints()
        TrashCountButton:SetNormalTexture(TrashCountTexture)
    end
    TrashCountTexture:SetTexture(db.config.trashcount and PNG_TRASH[1] or PNG_TRASH[2])
end

-- Initialize the texture after DB is loaded
C_Timer.After(0.5, function()
    UpdateTrashCountTexture()
end)

-- Main Frame Trash Count Button Highlight Texture
local TrashCountHighlightTexture = TrashCountButton:CreateTexture(nil, "OVERLAY")
TrashCountHighlightTexture:SetTexture(PNG_TRASH[1])
TrashCountHighlightTexture:SetAllPoints()
TrashCountButton:SetHighlightTexture(TrashCountHighlightTexture)

-- Main Frame Trash Count Button Function
TrashCountButton:SetScript("OnClick", function() 
    db.config.trashcount = not db.config.trashcount
    print(addonName..L["TRASH_COUNT"]..(db.config.trashcount and "|cFF00FF00"..L["ENABLED"].."|r" or "|cFFFF0000"..L["DISABLED"].."|r"))
    UpdateTrashCountTexture()
end)

-- Main Frame Transparency Button
local TransparencyButton = CreateFrame("Button", "ARTWORK", titleBar)
TransparencyButton:SetPoint("RIGHT", titleBar, "RIGHT", -52, 0)
TransparencyButton:SetSize(15, 15)

-- Main Frame Transparency Button Normal Texture
local TransparencyTexture = TransparencyButton:CreateTexture(nil, "BACKGROUND")
TransparencyTexture:SetTexture(PNG_TRANS[2])
TransparencyTexture:SetAllPoints()
TransparencyButton:SetNormalTexture(TransparencyTexture)

-- Main Frame Transparency Button Highlight Texture
local TransparencyHighlightTexture = TransparencyButton:CreateTexture(nil, "OVERLAY")
TransparencyHighlightTexture:SetTexture(PNG_TRANS[1])
TransparencyHighlightTexture:SetAllPoints()
TransparencyButton:SetHighlightTexture(TransparencyHighlightTexture)

-- Main Frame Transparency Button Function
TransparencyButton:SetScript("OnClick", function() 
    db.config.transparency = db.config.transparency + 0.1
    if db.config.transparency > 1 then
        db.config.transparency = DEFAULT_FRAME_TRANSPARENCY
    end
    print(format(addonName..L["TRANSPARENCY_SET"]..db.config.transparency))
    UpdateFrameTransparency()
end)

-- Main Frame Sound Button
local SoundButton = CreateFrame("Button", "ARTWORK", titleBar)
SoundButton:SetPoint("RIGHT", titleBar, "RIGHT", -35, 0)
SoundButton:SetSize(15, 15)

-- Main Frame Sound Button Normal Texture
local SoundTexture = SoundButton:CreateTexture(nil, "BACKGROUND")
SoundTexture:SetTexture(db.config.enableSound and PNG_SOUND[1] or PNG_SOUND[2])
SoundTexture:SetAllPoints()
SoundButton:SetNormalTexture(SoundTexture)

-- Main Frame Sound Button Highlight Texture
local SoundHighlightTexture = SoundButton:CreateTexture(nil, "OVERLAY")
SoundHighlightTexture:SetTexture(PNG_SOUND[3])
SoundHighlightTexture:SetAllPoints()
SoundButton:SetHighlightTexture(SoundHighlightTexture)

-- Main Frame Sound Button Function
SoundButton:SetScript("OnClick", function() 
    db.config.enableSound = not db.config.enableSound
    print(addonName..L["SOUND"]..(db.config.enableSound and "|cFF00FF00"..L["ENABLED"].."|r" or "|cFFFF0000"..L["DISABLED"].."|r"))
    -- Update Sound Button Texture
    SoundTexture:SetTexture(db.config.enableSound and PNG_SOUND[1] or PNG_SOUND[2])
    SoundTexture:SetAllPoints()
    SoundButton:SetNormalTexture(SoundTexture)
end)

-- Main Frame Lock Button
local LockButton = CreateFrame("Button", "ARTWORK", titleBar)
LockButton:SetPoint("RIGHT", titleBar, "RIGHT", -18, 0)
LockButton:SetSize(15, 15)

-- Function to update trash count texture
local function UpdateLockTexture()
    local LockTexture = LockButton:GetNormalTexture()
    if not LockTexture then
        LockTexture = LockButton:CreateTexture(nil, "BACKGROUND")
        LockTexture:SetAllPoints()
        LockButton:SetNormalTexture(LockTexture)
    end
    LockTexture:SetTexture(db.config.frameLocked and PNG_FRAME_LOCK[1] or PNG_FRAME_LOCK[3])
end

-- Initialize the texture after DB is loaded
C_Timer.After(0.5, function()
    UpdateLockTexture()
end)

-- Main Frame Lock Button Highlight Texture
local LockHighlightTexture = LockButton:CreateTexture(nil, "OVERLAY")
LockHighlightTexture:SetTexture(PNG_FRAME_LOCK[2])
LockHighlightTexture:SetAllPoints()
LockButton:SetHighlightTexture(LockHighlightTexture)

-- Main Frame Lock Button Function
LockButton:SetScript("OnClick", function() 
    db.config.frameLocked = not db.config.frameLocked
    print(addonName..L["FRAME_IS_NOW"]..(db.config.frameLocked and "|cFFFF0000"..L["LOCKED"].."|r" or "|cFF00FF00"..L["UNLOCKED"].."|r"))
    UpdateLockTexture()
end)

-- Main Frame Close Button
local CloseButton = CreateFrame("Button", nil, titleBar)
CloseButton:SetPoint("RIGHT", titleBar, "RIGHT", -1, 0)
CloseButton:SetSize(15, 15)
CloseButton:SetScript("OnClick", function() FTmainFrame:Hide() end)

-- Main Frame Close Button Normal Texture
local normalTexture = CloseButton:CreateTexture(nil, "BACKGROUND")
normalTexture:SetTexture(PNG_CLOSE_BUTTON[1])
normalTexture:SetAllPoints()
CloseButton:SetNormalTexture(normalTexture)

-- Main Frame Close Button Highlight Texture
local highlightTexture = CloseButton:CreateTexture(nil, "OVERLAY")
highlightTexture:SetTexture(PNG_CLOSE_BUTTON[2])
highlightTexture:SetAllPoints()
CloseButton:SetHighlightTexture(highlightTexture)

-- Main Frame Close Button Pushed Texture
local pushedTexture = CloseButton:CreateTexture(nil, "BACKGROUND")
pushedTexture:SetTexture(PNG_CLOSE_BUTTON[3])
pushedTexture:SetAllPoints()
CloseButton:SetPushedTexture(pushedTexture)

-- Main Frame Fishing Pole Icon Frame
local fishingPoleIcon = CreateFrame("Button", nil, titleBar)
fishingPoleIcon:SetPoint("RIGHT", titleBar, "RIGHT", -2, -26)
fishingPoleIcon:SetSize(25, 25)
fishingPoleIcon:SetFrameStrata("MEDIUM")
fishingPoleIcon:SetFrameLevel(FishingTrackerFrame:GetFrameLevel() + 1)

-- Main Frame Fishing Pole Texture
local poleTexture = fishingPoleIcon:CreateTexture(nil, "BACKGROUND")
poleTexture:SetAllPoints()
poleTexture:SetTexture("Interface\\Icons\\inv_fishingpole_02") -- Default fishing pole icon
fishingPoleIcon:SetNormalTexture(poleTexture)

-- Main Frame Function To Update Fishing Pole Icon
local function UpdateFishingPoleIcon()
    local itemID = GetInventoryItemID("player", 28) -- Profession tool slot
    if itemID and itemID > 0 then
        local iconTexture = GetItemIcon(itemID)
        if iconTexture then
            poleTexture:SetTexture(iconTexture)
            fishingPoleIcon:Show()

            -- Update tooltip functionality
            fishingPoleIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(itemID)
                GameTooltip:Show()
            end)

            -- Add click handler to open Fishing Journal
            fishingPoleIcon:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    -- Use Fishing Journal directly
                    if C_SpellBook and C_SpellBook.FindSpellBookSlotBySpellID then
                        local slot = C_SpellBook.FindSpellBookSlotBySpellID(271990) -- Fishing Journal spell ID
                        if slot then
                            CastSpell(slot, "spell")
                        end
                    else
                        -- Fallback for older clients
                        CastSpellByID(271990)
                    end
                end
            end)
        else
            fishingPoleIcon:Hide()
        end
    else
        poleTexture:SetTexture("interface/icons/inv_misc_profession_book_fishing")

        -- Add click handler for default icon too
        fishingPoleIcon:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- Use Fishing Journal directly
                if C_SpellBook and C_SpellBook.FindSpellBookSlotBySpellID then
                    local slot = C_SpellBook.FindSpellBookSlotBySpellID(271990) -- Fishing Journal spell ID
                    if slot then
                        CastSpell(slot, "spell")
                    end
                else
                    -- Fallback for older clients
                    CastSpellByID(271990)
                end
            end
        end)
    end
end

-- Main Frame Set Up Tooltip Leave Behavior
fishingPoleIcon:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

C_Timer.After(2, UpdateFishingPoleIcon) -- Wait a bit for inventory to load

-- Main Frame Highlight Texture
local highlight = FTmainFrame:CreateTexture(nil, "OVERLAY")
highlight:SetAllPoints(true)
highlight:SetColorTexture(0.3, 0.3, 0.8, 0.2)
highlight:Hide()

-- Main Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", nil, FTmainFrame)
scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, 10)
scrollFrame:SetPoint("BOTTOMRIGHT", FTmainFrame, "BOTTOMRIGHT", -10, 10)

-- Main Scroll Child
local scrollChild = CreateFrame("Frame")
scrollFrame:SetScrollChild(scrollChild)
scrollChild:SetWidth(DEFAULT_FRAME_WIDTH)
scrollChild:SetHeight(1)

-- Main UI Elements Zone Text
FTmainFrame.zoneText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
FTmainFrame.zoneText:SetFont(FRAME_FONT_ID[2], 16)
FTmainFrame.zoneText:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -2)
FTmainFrame.zoneText:SetJustifyH("LEFT")
FTmainFrame.zoneText:SetTextColor(0.8, 0.8, 1)

-- Main UI Elements SubZone Text
FTmainFrame.subzoneText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
FTmainFrame.subzoneText:SetFont(FRAME_FONT_ID[2], 14)
FTmainFrame.subzoneText:SetPoint("TOPLEFT", FTmainFrame.zoneText, "BOTTOMLEFT", 0, 0)
FTmainFrame.subzoneText:SetJustifyH("LEFT")
FTmainFrame.subzoneText:SetTextColor(0.8, 0.8, 1)

-- Main UI Elements Total Text
FTmainFrame.totalText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
FTmainFrame.totalText:SetFont(FRAME_FONT_ID[1], 11)
FTmainFrame.totalText:SetPoint("TOPLEFT", FTmainFrame.subzoneText, "BOTTOMLEFT", 0, -5)
FTmainFrame.totalText:SetJustifyH("LEFT")
FTmainFrame.totalText:SetTextColor(0.8, 0.8, 1)

-- Main Frame Fishing Skill Text
FTmainFrame.fishingSkillText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
FTmainFrame.fishingSkillText:SetFont(FRAME_FONT_ID[1], 11)
FTmainFrame.fishingSkillText:SetPoint("TOPLEFT", FTmainFrame.totalText, "BOTTOMLEFT", 0, -10)
FTmainFrame.fishingSkillText:SetJustifyH("LEFT")
FTmainFrame.fishingSkillText:SetTextColor(0.8, 0.8, 0.3)

-- Main Frame Current Location Stats Header
FTmainFrame.zoneStatsHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
FTmainFrame.zoneStatsHeader:SetFont(FRAME_FONT_ID[2], 12)
FTmainFrame.zoneStatsHeader:SetPoint("TOPLEFT", FTmainFrame.fishingSkillText, "BOTTOMLEFT", 0, -10)
FTmainFrame.zoneStatsHeader:SetText(L["CURRENT_LOCATION_STATS"])
FTmainFrame.zoneStatsHeader:SetJustifyH("LEFT")
FTmainFrame.zoneStatsHeader:SetTextColor(0.6, 0.8, 1) -- Light blue

-- Main Frame Current Location Stats Content
FTmainFrame.zoneStatsText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
FTmainFrame.zoneStatsText:SetFont(FRAME_FONT_ID[1], 11)
FTmainFrame.zoneStatsText:SetPoint("TOPLEFT", FTmainFrame.zoneStatsHeader, "BOTTOMLEFT", 0, -5)
FTmainFrame.zoneStatsText:SetJustifyH("LEFT")
FTmainFrame.zoneStatsText:SetTextColor(0.8, 0.8, 1)

-- Main Frame Caught Text
FTmainFrame.caughtText = FTmainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
FTmainFrame.caughtText:SetFont(FRAME_FONT_ID[1], 10)
FTmainFrame.caughtText:SetPoint("BOTTOMLEFT", FTmainFrame, "BOTTOM", 0, 20)
FTmainFrame.caughtText:SetTextColor(0.8, 0.8, 0.8)
FTmainFrame.caughtText:Hide()

-- Main Frame Mini Stats Text
FTmainFrame.miniStats = FTmainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
FTmainFrame.miniStats:SetFont(FRAME_FONT_ID[1], 10)
FTmainFrame.miniStats:SetPoint("BOTTOMLEFT", FTmainFrame, "BOTTOMLEFT", 10, 5)
FTmainFrame.miniStats:SetTextColor(0.8, 0.8, 0.8)

-- Main Frame Timer Text
FTmainFrame.timerText = FTmainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
FTmainFrame.timerText:SetFont(FRAME_FONT_ID[1], 10)
FTmainFrame.timerText:SetPoint("BOTTOMRIGHT", FTmainFrame, "BOTTOMRIGHT", -10, 5)
FTmainFrame.timerText:SetTextColor(0.8, 0.8, 0.8)
FTmainFrame.timerText:Hide()

--------------------------------------------------------------------------------------------------------------
-- 8. PIE CHART TEXT FRAME
--------------------------------------------------------------------------------------------------------------
local pieTextFrame = CreateFrame("Frame", "FTPieChartTextFrame", FTmainFrame) -- Changed parent to frame
pieTextFrame:SetSize(100, 30)
pieTextFrame:SetFrameStrata("MEDIUM")
pieTextFrame:SetFrameLevel(FTmainFrame:GetFrameLevel()+1)
pieTextFrame:Hide()

local pieText = pieTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pieText:SetFont(FRAME_FONT_ID[3], 22)
pieText:SetPoint("CENTER")
pieText:SetJustifyH("CENTER")
pieText:SetTextColor(0.8, 0.8, 1)

FTmainFrame:HookScript("OnShow", function()
    pieTextFrame:Show()
    pieText:SetText(formatNumberWithCommas(db.totalCaught))
end)

FTmainFrame:HookScript("OnHide", function()
    pieTextFrame:Hide()
end)

--------------------------------------------------------------------------------------------------------------
-- 9. MINIMAP BUTTON
--------------------------------------------------------------------------------------------------------------
minimapButton = CreateFrame("Button", "FishingTrackerMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:RegisterForClicks("LeftButtonDown","RightButtonDown");

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture(ADDON_ICON_TEXTURE)
icon:SetSize(18, 18)
icon:SetPoint("CENTER")

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetSize(46, 46)
overlay:SetPoint("TOPLEFT", 2, -2)

minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if not FishingTrackerFrame:IsVisible() then
            highlight:Show()
            UIFrameFadeIn(FTmainFrame, DEFAULT_WATCHDRAGGER_FADE_TIME, 0, 1)
            UIFrameFadeIn(highlight, DEFAULT_WATCHDRAGGER_FADE_TIME, 0, 0.15)
            FTmainFrame:Show()
        else
            FishingTrackerFrame:Hide()
        end
    elseif button == "RightButton" then
        if not FishingTrackerGlobalStatsFrame:IsVisible() then
            FishingTrackerGlobalStatsFrame:Show()
            UpdateGlobalStatsDisplay()
        else
            FishingTrackerGlobalStatsFrame:Hide()
        end
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["FISHING_TRACKER"], 1, 1, 1)
    GameTooltip:AddLine(L["LEFT_CLICK"], 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L["RIGHT_CLICK"], 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L["DRAG_TO_MOVE"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self.isMoving = true
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self.isMoving = false
end)

minimapButton:SetScript("OnUpdate", function(self)
    if self.isMoving then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale

        local angle = math.atan2(py - my, px - mx)
        db.config.minimap.position = math.deg(angle)
        UpdateMinimapButtonPosition()
    end
end)

--------------------------------------------------------------------------------------------------------------
-- 10. MAIN FRAME - UPDATE DISPLAY FUNCTIONS (FIXED UPVALUES)
--------------------------------------------------------------------------------------------------------------
-- Create a container for all display-related functions and variables
local DisplayManager = {
    -- Local variables that were causing upvalue issues
    currentZoneData = nil,
    currentMapID = nil,
    zoneName = "",
    subzoneName = "",
    expansionName = L["UNKNOWN"],
    skillLineID = nil,
    RealexpansionName = L["UNKNOWN"],
    RealprofessionName = L["UNKNOWN"],
    RealskillRank = 0,
    RealskillMax = 0
}

-- Extract the complex logic into separate functions
function DisplayManager:GetExpansionZoneData(instanceMapID)
    local instanceName, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    self.currentZoneData = private.zoneExpansionSkillMap[instanceMapID] or { expansion = L["FISHING"], skillLineID = 356 }

    if self.currentZoneData then
        self.expansionName = self.currentZoneData.expansion
        self.skillLineID = self.currentZoneData.skillLineID

        if self.expansionName == L["KUL_TIRAN"] then
            local playerFaction, localizedFaction = UnitFactionGroup("player")
            if playerFaction == L["HORDE"] then
                self.expansionName = L["ZANDALARI"]
            elseif playerFaction == L["ALLIANCE"] then
                self.expansionName = L["KUL_TIRAN"]
            end
        end

        local classicMapIDs = {
            [41] = true, [84] = true, [85] = true, [87] = true, [88] = true, [89] = true, [90] = true, 
            [407] = true, [198] = true, [201] = true, [203] = true, [204] = true, [205] = true, [241] = true,
        }

        local LegionMapIDs = {
            [41] = true,
        }

        local KulTiranMapIDs = {
            -- [62] = true,
        }

        local CataclysmMapIDs = {
            [198] = true, [201] = true, [203] = true, [204] = true, [205] = true, [241] = true,
        }

        -- ##### DEBUG #####
        -- print("<TEST> Expansion Name: "..self.expansionName)
        -- print("<TEST> Current MapID: "..self.currentMapID)
        -- #################

        if self.expansionName == "Classic" and classicMapIDs[self.currentMapID] then
            if LegionMapIDs[self.currentMapID] then
                self.expansionName, self.skillLineID = "Legion Fishing", 2586
            elseif KulTiranMapIDs[self.currentMapID] then
                self.expansionName, self.skillLineID = "Kul Tiran Fishing", 2585
            elseif CataclysmMapIDs[self.currentMapID] then
                self.expansionName, self.skillLineID = "Cataclysm Fishing", 2589
                if C_UnitAuras.GetPlayerAuraBySpellID(MIDNIGHT_BUFF_SPELL_ID) then
                    self.expansionName, self.skillLineID = "Khaz Algar Fishing", 2876
                end
            else
                local professions = {GetProfessions()}
                if professions[4] ~= nil then
                    local name, icon, curLv, maxLv, numAbil, offset, SL, _, _, _, currName = GetProfessionInfo(professions[4])
                    self.expansionName = currName

                    if self.expansionName == "Classic Fishing" then self.skillLineID = 2592
                    elseif self.expansionName == "Outland Fishing" then self.skillLineID = 2591
                    elseif self.expansionName == "Northrend Fishing" then self.skillLineID = 2590
                    elseif self.expansionName == "Cataclysm Fishing" then self.skillLineID = 2589
                    elseif self.expansionName == "Pandaria Fishing" then self.skillLineID = 2588
                    elseif self.expansionName == "Draenor Fishing" then self.skillLineID = 2587
                    elseif self.expansionName == "Legion Fishing" then self.skillLineID = 2586
                    elseif self.expansionName == "Kul Tiran Fishing" then self.skillLineID = 2585
                    elseif self.expansionName == "Shadowlands Fishing" then self.skillLineID = 2754
                    elseif self.expansionName == "Dragon Isles Fishing" then self.skillLineID = 2826
                    elseif self.expansionName == "Khaz Algar Fishing" then self.skillLineID = 2876
                    end

                    -- ##### DEBUG #####
                    if DEFAULT_DEBUG then
                        AddDebugMessage("expansionName: " .. self.expansionName)
                    end
                    -- #################

                    if self.expansionName == "Khaz Algar Fishing" then
                        self.skillLineID = 2876
                    end
                end
            end
        end

        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage(format("|cFFFFFFFF==================== DEBUG START ====================|r"))
            AddDebugMessage(format("GAME VERSION: %s    ADDON VERSION: %s", GAME_VERSION, ADDON_VERSION ))
            AddDebugMessage(format(L["FISHING_IN"].." %s (%d)", instanceName, instanceMapID))
            AddDebugMessage(format("|cFFFFFF00(From Data_Zone)Expansion Name: |r|cFFFFFFFF%s  |r|cFFFFFF00SkillLineID: |r|cFFFFFFFF%s|r", self.expansionName, self.skillLineID))
        end
        -- #################
    end
    return self.currentZoneData
end

function DisplayManager:GetProfessionInfo()
    -- Query profession by skillLineID if known
    if self.skillLineID then
        -- Try to get profession info, but handle nil case
        local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.skillLineID)
        if profInfo then
            self.RealexpansionName = profInfo.expansionName or self.expansionName
            self.RealprofessionName = profInfo.professionName or L["FISHING"]
            self.RealskillRank = profInfo.skillLevel or 0
            self.RealskillMax = profInfo.maxSkillLevel or 0

            if self.RealskillRank == 0 or self.RealskillMax == 0 then
                self.RealskillRank, self.RealskillMax = GetSkillLevel(self.skillLineID)
            end
        else
            -- If we couldn't get profession info, try direct skill check
            self.RealexpansionName = self.expansionName
            self.RealprofessionName = L["FISHING"]
            self.RealskillRank, self.RealskillMax = GetSkillLevel(self.skillLineID)
        end
    else
        -- Default values if no skillLineID
        self.RealexpansionName = self.expansionName
        self.RealprofessionName = L["FISHING"]
        self.RealskillRank, self.RealskillMax = GetSkillLevel(356) -- Default to basic fishing
    end

    -- if cannot get skillRank or skillMax will use back the latest Profession Information you had learnt.
    if self.RealskillRank and self.RealskillMax == 0 then
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage(format("|cFFFFFF00-- ProfInfo: |r|cFFFFFFFF %s |r|cFFFFFF00Rank: |r|cFFFFFFFF%s |r|cFFFFFF00Max: |r|cFFFFFFFF%s|r", self.RealprofessionName, self.RealskillRank, self.RealskillMax))
        end
        -- #################
        local professions = {GetProfessions()}
        -- Check if the 4th profession exists
        if professions[4] ~= nil then
            local name, icon, curLv, maxLv, numAbil, offset, SL, _, _, _, currName = GetProfessionInfo(professions[4])
            if currName == nil then currName = name end
            self.RealprofessionName = currName or L["UNKNOWN_FISHING"]
            self.RealskillRank = curLv
            self.RealskillMax = maxLv
            -- ##### DEBUG #####
            if DEFAULT_DEBUG then
                AddDebugMessage(format("|cFFFF0000Cannot get skillRank or skillMax, use back latest Profession you had learnt.|r"))
                AddDebugMessage(format("|cFFFFFFFFCurrName[4]: %s|r", currName))
            end
            -- #################
        else
            -- ##### DEBUG #####
            if DEFAULT_DEBUG then
                AddDebugMessage(format("|cFFFFFFFFNo 4th profession found|r"))
            end
            -- #################
        end
    end

    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage(format("|cFFFFFF00RealExpansionZoneData - Expansion: |r|cFFFFFFFF%s  |r|cFFFFFF00SkillLineID: |r|cFFFFFFFF%s|r", self.currentZoneData.expansion, self.currentZoneData.skillLineID))
    end
    -- #################
end

function DisplayManager:UpdateFishingSkillDisplay()
    local poleBaseBonus = GetFishingPoleBonus()
    local hatBaseBonus = GetFishingHatBonus()
    local poleEnchantBonus = GetFishingPoleEnchantBonus()
    local equipBuffBonus = GetFishingSkillBuffBonus()
    local toysBonus = GetFishingToysBuffBonus()
    local TotalEnchantBonus = hatBaseBonus + poleEnchantBonus + equipBuffBonus + toysBonus

    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage("===== FISHING BONUS DEBUG =====")
        AddDebugMessage(format("TotalBonus: %d = HatBonus: %d + PoleBonus: %d + EquipBuffBonus: %d + ToysBonus: %d", TotalEnchantBonus, hatBaseBonus, poleEnchantBonus, equipBuffBonus, toysBonus))
    end
    -- #################

    -- Get Perception Buff and Bonus
    local totalperceptionBuffBonus = 0

    -- Check both profession slot#(28) & slot#(1)
    for _, slot in ipairs({28, 1}) do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            -- Method 2: Deep scan tooltip text
            local tooltip = CreateFrame("GameTooltip", "FishingTrackerScanTooltip", nil, "GameTooltipTemplate")
            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            tooltip:SetInventoryItem("player", slot)

            -- Look for the enchant line specifically
            for i = 3, tooltip:NumLines() do
                local line = _G["FishingTrackerScanTooltipTextLeft"..i]
                local text = line and line:GetText()
                if text then
                    -- Match various possible enchant text formats
                    local PerceptionBonus = text:match("%+(%d+) "..L["PERCEPTION"])
                    if PerceptionBonus then
                        PerceptionBonus = tonumber(PerceptionBonus) or 0
                        totalperceptionBuffBonus = totalperceptionBuffBonus + PerceptionBonus
                    end
                end
            end
        end
    end

    for spellID, perceptionBuff in pairs(FT_FishingPerceptionBuffIDs) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            totalperceptionBuffBonus = totalperceptionBuffBonus + perceptionBuff
        end
    end

    local skilldisplayText = ""
    if self.RealskillRank and self.RealskillMax > 0 then
        if TotalEnchantBonus > 0 then
            if poleBaseBonus == 0 then
                if totalperceptionBuffBonus > 0 then
                    skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d (+ |cFF00FFFF%d|r) / %d)\n"..L["PERCEPTION"]..": +|cFF00EEFF%d|r", 
                        self.RealprofessionName, 
                        self.RealskillRank or 0, 
                        TotalEnchantBonus, 
                        self.RealskillMax or 0, 
                        totalperceptionBuffBonus or 0)
                else
                    skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d (+ |cFF00FFFF%d|r) / %d)", 
                        self.RealprofessionName, 
                        self.RealskillRank or 0, 
                        TotalEnchantBonus, 
                        self.RealskillMax or 0)
                end
            else
                if totalperceptionBuffBonus > 0 then
                    skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d (|cFF00FF00+%d|r + |cFF00FFFF%d|r) / %d)\n"..L["PERCEPTION"]..": +|cFF00EEFF%d|r", 
                        self.RealprofessionName, 
                        self.RealskillRank or 0, 
                        poleBaseBonus, 
                        TotalEnchantBonus, 
                        self.RealskillMax or 0, 
                        totalperceptionBuffBonus or 0)
                else
                    skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d (|cFF00FF00+%d|r + |cFF00FFFF%d|r) / %d)", 
                        self.RealprofessionName, 
                        self.RealskillRank or 0, 
                        poleBaseBonus, 
                        TotalEnchantBonus, 
                        self.RealskillMax or 0)
                end
            end
        elseif poleBaseBonus > 0 then
            if totalperceptionBuffBonus > 0 then
                skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d (|cFF00FF00+%d|r) / %d)\n"..L["PERCEPTION"]..": +|cFF00EEFF%d|r", 
                    self.RealprofessionName, 
                    self.RealskillRank or 0, 
                    poleBaseBonus, 
                    self.RealskillMax or 0, 
                    totalperceptionBuffBonus or 0)
            else
                skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d (|cFF00FF00+%d|r) / %d)", 
                    self.RealprofessionName, 
                    self.RealskillRank or 0, 
                    poleBaseBonus, 
                    self.RealskillMax or 0)
            end
        elseif poleBaseBonus == 0 then
            if totalperceptionBuffBonus > 0 then
                skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d / %d)\n"..L["PERCEPTION"]..": +|cFF00EEFF%d|r", 
                    self.RealprofessionName, 
                    self.RealskillRank or 0, 
                    self.RealskillMax or 0, 
                    totalperceptionBuffBonus or 0)
            else
                skilldisplayText = format("|cFFFFFFFF%s|r\n("..L["SKILL"].." %d / %d)", 
                    self.RealprofessionName, 
                    self.RealskillRank or 0, 
                    self.RealskillMax or 0)
            end
        end
    else
        if totalperceptionBuffBonus > 0 then
            skilldisplayText = format("|cFFFFFFFF%s|r "..L["NOT_LEARNED_OR"].."\n|cFFFFFFFF%s|r "..L["NOT_LEARNED"].."\n"..L["PERCEPTION"]..": +|cFF00EEFF%d|r",
                self.RealprofessionName, 
                self.zoneName, 
                totalperceptionBuffBonus or 0)
        else
            skilldisplayText = format("|cFFFFFFFF%s|r "..L["NOT_LEARNED_OR"].."\n|cFFFFFFFF%s|r "..L["NOT_LEARNED"],
                self.RealprofessionName, 
                self.zoneName)
        end
    end

    local fishingCharm
    for spellID, Bonus in pairs(FT_FishingToysBuffIDs) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            if spellID == 125167 and self.skillLineID == 2588 then
                fishingCharm = L["ANCIENT_PANDAREN_CHARM"]
                skilldisplayText = skilldisplayText.."\n"..fishingCharm
            end
        end
    end

    -- ##### DEBUG #####
    if DEFAULT_DEBUG then
        AddDebugMessage(format("|cFFFFFFFF===== FISHING SKILL UPDATE =====|r"))
        AddDebugMessage(format("|cFFFFFF00-- Zone: |r|cFFFFFFFF%s - %s |r|cFFFFFF00SkillLineID: |r|cFFFFFFFF%s|r", self.zoneName, self.subzoneName, self.skillLineID))
        AddDebugMessage(format("|cFFFFFF00-- ProfInfo: |r|cFFFFFFFF%s |r|cFFFFFF00Rank: |r|cFFFFFFFF%d (+%d +%d) |r|cFFFFFF00Max: |r|cFFFFFFFF%d|r", self.RealprofessionName, self.RealskillRank, poleBaseBonus, poleEnchantBonus, self.RealskillMax))
        AddDebugMessage(format("-- Base pole bonus: %d -- Enchant bonus: %d -- Total bonus: %d", poleBaseBonus, poleEnchantBonus, poleBaseBonus + poleEnchantBonus))
        if totalperceptionBuffBonus > 0 then
            AddDebugMessage(format("-- "..L["PERCEPTION"]..": +%d", totalperceptionBuffBonus))
        end
    end
    -- #################

    -- Set the fishing skill text
    FTmainFrame.fishingSkillText:SetText(skilldisplayText)
end

function DisplayManager:UpdateZoneStats()
    local zoneKey, mapID, zoneName, subzoneName, displayZoneName = GetZoneKey()
    if not zoneKey then return end

    db.zoneData[zoneKey] = db.zoneData[zoneKey] or {
        total = 0,
        fishData = {},
        mapID = mapID,
        zoneName = zoneName,  -- Store the original zone name
        subzoneName = subzoneName,
        displayZoneName = displayZoneName  -- Store the display zone name
    }

    -- For Display the Zone Name "Dalaran (Deadwind Pass)" Only
    local mapID = C_Map.GetBestMapForUnit("player")
    if zoneName == L["DEADWIND_PASS"] and mapID == 41 then
        displayZoneName = L["DALARAN_(DEADWIND_PASS)"]
    end

    -- Update zone text displays using the display zone name
    FTmainFrame.zoneText:SetText("|cFF00BFFF"..displayZoneName.."|r")
    FTmainFrame.subzoneText:SetText("|cFF00BFAA"..subzoneName.."|r")
    FTmainFrame.totalText:SetText(L["TOTAL_CAUGHT"].." |cFF00FFC8"..formatNumberWithCommas(db.totalCaught).."|r")

    local zoneTotal = db.zoneData[zoneKey].total or 0
    FTmainFrame.zoneStatsText:SetText(L["FISH_CAUGHT_HERE"].." |cFF00FFC8"..formatNumberWithCommas(zoneTotal).."|r")

    -- Ensure names are always up to date
    db.zoneData[zoneKey].zoneName = zoneName
    db.zoneData[zoneKey].subzoneName = subzoneName
    db.zoneData[zoneKey].displayZoneName = displayZoneName

    -- Ensure mapID is updated if it was 0 previously
    if db.zoneData[zoneKey].mapID == 0 then
        db.zoneData[zoneKey].mapID = mapID
    end
end

function DisplayManager:UpdateFishColumns()
    local zoneKey = GetZoneKey()
    if not zoneKey or not db.zoneData[zoneKey] then return end

    local zoneData = db.zoneData[zoneKey]
    local fishEntries = {}
    local maxRows = 0
    local rowHeight = 12

    -- Clear previous columns if they exist
    if FTmainFrame.zoneStatsColumns then
        for _, column in ipairs(FTmainFrame.zoneStatsColumns) do
            column:Hide()
        end
    end

    -- Create columns container if it doesn't exist
    if not FTmainFrame.zoneStatsContainer then
        FTmainFrame.zoneStatsContainer = CreateFrame("Frame", nil, scrollChild)
        FTmainFrame.zoneStatsContainer:SetPoint("TOPLEFT", FTmainFrame.zoneStatsHeader, "BOTTOMLEFT", 0, -5)
        FTmainFrame.zoneStatsContainer:SetSize(scrollChild:GetWidth() - 20, 200) -- Adjust height as needed
    end

    -- Create 3 columns for the stats
    FTmainFrame.zoneStatsColumns = CreateColumns(FTmainFrame.zoneStatsContainer, 3, 
        (scrollChild:GetWidth() - 50) / 3, -- Column width (total width minus spacing)
        200, -- Column height
        10) -- Spacing between columns

    local startY = -25 -- Start below headers and total line

    -- Set up column headers (positioned below the total line)
    local nameHeader = FTmainFrame.zoneStatsColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetFont(FRAME_FONT_ID[1], 10)
    nameHeader:SetPoint("TOPLEFT", FTmainFrame.zoneStatsColumns[1], "TOPLEFT", 0, startY + 15)
    nameHeader:SetJustifyH("LEFT")
    nameHeader:SetText(L["FISH_NAME"])
    nameHeader:SetTextColor(0.8, 0.8, 1)

    local countHeader = FTmainFrame.zoneStatsColumns[2]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countHeader:SetFont(FRAME_FONT_ID[1], 10)
    countHeader:SetPoint("TOPRIGHT", FTmainFrame.zoneStatsColumns[2], "TOPRIGHT", 20, startY + 15)
    countHeader:SetJustifyH("RIGHT")
    countHeader:SetText(L["COUNT"])
    countHeader:SetTextColor(0.8, 0.8, 1)

    local percentHeader = FTmainFrame.zoneStatsColumns[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    percentHeader:SetFont(FRAME_FONT_ID[1], 10)
    percentHeader:SetPoint("TOPRIGHT", FTmainFrame.zoneStatsColumns[3], "TOPRIGHT", -10, startY + 15)
    percentHeader:SetJustifyH("RIGHT")
    percentHeader:SetText(L["PERCENT"])
    percentHeader:SetTextColor(0.8, 0.8, 1)

    if zoneData.fishData then
        -- Prepare fish data for sorting
        for fishName, fishData in pairs(zoneData.fishData) do
            local count = type(fishData) == "table" and fishData.count or fishData
            local itemID = type(fishData) == "table" and fishData.itemID or nil
            table.insert(fishEntries, {
                name = fishName,
                count = count,
                itemID = itemID
            })
        end

        -- Sort by count (descending)
        table.sort(fishEntries, function(a, b) return a.count > b.count end)

        -- Create arrays to store percentage data for each fish
        local percentages = {}
        local zoneTotal = zoneData.total or 0

        -- First pass: calculate all percentages
        for i, fish in ipairs(fishEntries) do
            percentages[i] = zoneTotal > 0 and (fish.count / zoneTotal) * 100 or 0
        end

        -- Before the fish processing loop, add this check:
        if zoneTotal == 0 or #fishEntries == 0 then
            -- Display "No fish caught here yet" message
            local noFishText = FTmainFrame.zoneStatsColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noFishText:SetFont(FRAME_FONT_ID[1], 10)
            noFishText:SetPoint("TOPLEFT", FTmainFrame.zoneStatsColumns[1], "TOPLEFT", 0, startY)
            noFishText:SetJustifyH("LEFT")
            noFishText:SetTextColor(1, 1, 1)
            noFishText:SetText(L["NO_FISH_CAUGHT_HERE"])
            maxRows = 1
        else
            for i, fish in ipairs(fishEntries) do
                local percentage = percentages[i]
                local color = GetFishColor(fish.itemID)
                local displayText = color and (color..fish.name.."|r") or fish.name

                -- Fish name column with icon
                local nameTextFrame = CreateFrame("Frame", nil, FTmainFrame.zoneStatsColumns[1])
                nameTextFrame:SetSize(150, rowHeight)
                nameTextFrame:SetPoint("TOPLEFT", FTmainFrame.zoneStatsColumns[1], "TOPLEFT", 0, startY - (i-1)*rowHeight)

                -- Fish icon
                local fishIcon = nameTextFrame:CreateTexture(nil, "OVERLAY")
                fishIcon:SetSize(12, 12)
                fishIcon:SetPoint("LEFT", nameTextFrame, "LEFT", 0, 0)

                -- Get item icon if available
                local iconTexture = nil
                if fish.itemID then
                    iconTexture = GetItemIcon(fish.itemID)
                end

                if iconTexture then
                    fishIcon:SetTexture(iconTexture)
                else
                    -- Fallback to a generic fish icon if item icon not available
                    fishIcon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
                end

                -- Optional: Add tooltip to show fishing pole info
                fishIcon:SetScript("OnEnter", function(self)
                    if fish.itemID then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetItemByID(fish.itemID)
                        GameTooltip:Show()
                    end
                end)

                fishIcon:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)

                -- Fish name column
                local nameText = FTmainFrame.zoneStatsColumns[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameText:SetFont(FRAME_FONT_ID[1], 10)
                nameText:SetPoint("TOPLEFT", FTmainFrame.zoneStatsColumns[1], "TOPLEFT", 15, startY - (i-1)*rowHeight)
                nameText:SetJustifyH("LEFT")
                nameText:SetTextColor(0.8, 0.8, 1)
                nameText:SetText(displayText)

                -- Count column
                local countText = FTmainFrame.zoneStatsColumns[2]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                countText:SetFont(FRAME_FONT_ID[1], 10)
                countText:SetPoint("TOPRIGHT", FTmainFrame.zoneStatsColumns[2], "TOPRIGHT", 20, startY - (i-1)*rowHeight)
                countText:SetJustifyH("RIGHT")
                countText:SetTextColor(0.8, 0.8, 1)
                countText:SetText(formatNumberWithCommas(fish.count))

                -- Percentage column
                local percentText = FTmainFrame.zoneStatsColumns[3]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                percentText:SetFont(FRAME_FONT_ID[1], 10)
                percentText:SetPoint("TOPRIGHT", FTmainFrame.zoneStatsColumns[3], "TOPRIGHT", -10, startY - (i-1)*rowHeight)
                percentText:SetJustifyH("RIGHT")
                percentText:SetTextColor(0.8, 0.8, 1)
                percentText:SetText(format("%.1f%%", percentage))

                maxRows = i
            end
        end
    end

    -- Adjust container height based on content
    local containerHeight = 50 + (maxRows * rowHeight) -- Header + total line + rows
    FTmainFrame.zoneStatsContainer:SetHeight(containerHeight)

    return containerHeight
end

--------------------------------------------------------------------------------------------------------------
-- 11. PIE CHART CREATE
--------------------------------------------------------------------------------------------------------------
function DisplayManager:UpdatePieChart()
    local pieGraph = LibGraph:CreateGraphPieChart("PieChart", FishingTrackerFrame, "TOP", "TOP", 70, -45, 100, 100)
    pieGraph:ResetPie()
    pieGraph:OnUpdate()

    -- Get fish data for the current zone
    local zoneKey = GetZoneKey()
    if not zoneKey or not db.zoneData[zoneKey] then
        pieText:SetText(formatNumberWithCommas(db.totalCaught))
        return
    end

    local zoneData = db.zoneData[zoneKey]
    local fishEntries = {}
    local percentages = {}
    local gR, gG, gB = 0.1, 0.5, 0.5

    -- Prepare fish data for the pie chart
    if zoneData.fishData and zoneData.total and zoneData.total >= 0 then
        for fishName, fishData in pairs(zoneData.fishData) do
            local count = type(fishData) == "table" and fishData.count or fishData
            local itemID = type(fishData) == "table" and fishData.itemID or nil
            table.insert(fishEntries, {
                name = fishName,
                count = count,
                itemID = itemID
            })
        end

        -- Sort by count (descending)
        table.sort(fishEntries, function(a, b) return a.count > b.count end)

        -- Calculate percentages
        for i, fish in ipairs(fishEntries) do
            percentages[i] = (fish.count / zoneData.total) * 100
        end

        -- Add pie sections after a short delay
        C_Timer.After(0.5, function()
            pieGraph:ResetPie()
            for i, fish in ipairs(fishEntries) do
                if gR > 1 then gR = 0.1 end
                if gG > 1 then gG = 0.5 end
                if gB > 1 then gB = 0.5 end
                pieGraph:AddPie(percentages[i], {gR, gG, gB})
                gR = gR + 0.005
                gG = gG + 0.025
                gB = gB + 0.025
            end
            pieGraph:CompletePie({gR, gG+0.1, gB+0.1})
        end)
    end

    -- Update Pie Chart Text Frame
    pieTextFrame:ClearAllPoints()
    pieTextFrame:SetPoint("CENTER", pieGraph, "CENTER", 0, 0)
    pieText:SetText(formatNumberWithCommas(db.totalCaught))

    -- Show/hide with the main frame
    if FTmainFrame:IsVisible() then
        pieTextFrame:Show()
    else
        pieGraph:AddPie(100, {gR, gG, gB})
        pieGraph:CompletePie({gR, gG, gB})
        pieGraph:ResetPie()
        pieGraph:OnUpdate()
        pieTextFrame:Hide()
    end
end
--------------------------------------------------------------------------------------------------------------
-- END OF PIE CHART
--------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------
-- 12. MAIN UPDATEDISPLAY FUNCTION
--------------------------------------------------------------------------------------------------------------
local function UpdateDisplay()
    UpdateFishingPoleIcon()

    -- Get current zone info
    local zoneKey, currentMapID, zoneName, subzoneName, displayZoneName = GetZoneKey()
    DisplayManager.zoneName = zoneName
    DisplayManager.subzoneName = subzoneName
    DisplayManager.displayZoneName = displayZoneName
    DisplayManager.currentMapID = currentMapID

    -- Update zone data
    DisplayManager:UpdateZoneStats()

    -- Get expansion and skill data
    local RealExpansionZoneData = DisplayManager:GetExpansionZoneData(currentMapID)

    -- Get profession information
    DisplayManager:GetProfessionInfo()

    -- Update fishing skill display
    DisplayManager:UpdateFishingSkillDisplay()

    -- Update Pie Chart
    DisplayManager:UpdatePieChart()

    -- Update fish columns and get container height
    local containerHeight = DisplayManager:UpdateFishColumns()

    -- Update frame height and scroll
    local totalHeight = FTmainFrame.zoneText:GetStringHeight() + 
                        FTmainFrame.totalText:GetStringHeight() + 
                        FTmainFrame.zoneStatsHeader:GetStringHeight() + 
                        (containerHeight or 0) + 
                        60

    scrollChild:SetHeight(totalHeight)
    local maxHeight = UIParent:GetHeight() * 0.8
    local newHeight = math.min(maxHeight, totalHeight + 60)

    if math.abs(FTmainFrame:GetHeight() - newHeight) > 5 then
        FTmainFrame:SetHeight(newHeight)
        db.ui.height = newHeight
    end
end

local function VerifyZoneNames()
    if not DEFAULT_DEBUG then return end

    AddDebugMessage("===== VERIFYING ZONE NAMES =====")
    for zoneKey, zoneData in pairs(db.zoneData) do
        AddDebugMessage(format("Zone: %s | Name: %s | Subzone: %s | MapID: %d",
            zoneKey,
            zoneData.zoneName or L["NIL"],
            zoneData.subzoneName or L["NIL"],
            zoneData.mapID or 0))
    end
    AddDebugMessage("===== VERIFICATION COMPLETE =====")
end

-- Call this after initialization
C_Timer.After(5, VerifyZoneNames)

local function MigrateDalaranData()
    for zoneKey, zoneData in pairs(db.zoneData) do
        if zoneKey:match(L["DALARAN"]) and not zoneKey:match("%[%d+%]") then
            -- This is old Dalaran data without mapID in key
            local newKey = zoneKey.." ["..(zoneData.mapID or 0).."]"

            -- Only migrate if we don't already have data for this key
            if not db.zoneData[newKey] then
                db.zoneData[newKey] = zoneData
            end
            db.zoneData[zoneKey] = nil
        end
    end
end

local function UpdateMiniStats()
    if not db.sessionData then return end

    local duration = time() - db.sessionData.startTime
    local fph = 0

    -- Prevent division by zero
    if duration > 0 then
        fph = (db.sessionData.fishCaught / (duration/3600))
        if fph < 0 then fph = 0 end
    end

    FTmainFrame.miniStats:SetText(format(L["SESSION"].." %d "..L["FISH"].." | %.1f "..L["FISH_PER_HOUR"], db.sessionData.fishCaught, fph))
end

local function StartFishingSession()
    if not db.config.trackSessions then return end

    db.sessionData = {
        startTime = time(),
        fishCaught = 0,
        rareFish = {},
        bestCatch = nil,
        lastUpdate = time()
    }

    FTmainFrame.miniStats:Show()
    UpdateMiniStats()

    FTmainFrame.sessionTimer = C_Timer.NewTicker(DEFAULT_SESSION_UPDATE_INTERVAL, function()
        if db.sessionData then
            UpdateMiniStats()
            db.sessionData.lastUpdate = time()
        else
            FTmainFrame.sessionTimer:Cancel()
        end
    end)
end

local function EndFishingSession()
    if not db.sessionData then return end

    if FTmainFrame.sessionTimer then
        FTmainFrame.sessionTimer:Cancel()
    end

    local duration = time() - db.sessionData.startTime
    local fph = (db.sessionData.fishCaught / (duration/3600))
    if fph < 0 then fph = 0 end
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage(format(format(L["FISHING_SESSION_ENDED"].." %d "..L["FISH_IN"].." %s (%.1f "..L["FISH_PER_HOUR"]..")", db.sessionData.fishCaught, SecondsToTime(duration), fph)))
        end
        -- #################

        FTmainFrame.caughtText:Hide()

    if #db.sessionData.rareFish > 0 then
        print(L["RARE_FISH_CAUGHT_THIS_SESSION"])
        for _, fish in ipairs(db.sessionData.rareFish) do
            print(" - "..fish)
        end
    end

    db.sessionData = nil
    FTmainFrame.miniStats:Hide()  -- Hide mini stats when session truly ends
end

local function ShouldAutoHide()
    if not db.config.autoHide then return false end

    local mounted = db.config.autoHideConditions.mounted and IsMounted()
    local noBuff = db.config.autoHideConditions.fishingBuff and not HasFishingBuff()

    return mounted or noBuff
end

local function HandleLoot()
    if not IsFishingLoot() then return end

    -- Change to green dot immediately when loot is detected
    titleText:SetText("|T"..ADDON_ICON_TEXTURE..":16:16:0:0|t |T"..PNG_DOT[2]..":15:15:0:0|t "..L["FISHING_TRACKER"].." "..ADDON_VERSION.."|cFFFFFFFF"..SPACES.."|r")

    local zoneKey, mapID = GetZoneKey()
    if not zoneKey then
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            AddDebugMessage("Skipping loot handling - invalid zone")
        end
        -- #################
        return
    end

    local numLootItems = GetNumLootItems()
    if numLootItems == 0 then return end

    for i = 1, numLootItems do
        if LootSlotHasItem(i) then

            local itemLink = GetLootSlotLink(i)
            local itemCount = GetLootSlotInfo(i)

            local _, _, quantity = GetLootSlotInfo(i)
            quantity = quantity or 1

            -- ##### DEBUG #####
            if DEFAULT_DEBUG then
                AddDebugMessage(format("|cFFFFAA00* Item Loot Name: |r%s (x%d)", itemLink or L["NIL"], quantity))
            end
            -- #################

            if not itemLink then break end -- Changed from return to break

            local lootType = GetLootSlotType(i)

            if lootType == 2 or lootType == 3 then    -- (lootType 2 = Money) (lootType 3 = Currency)
                FTmainFrame.caughtText:SetPoint("LEFT", 10, 0)
                FTmainFrame.caughtText:Show()
                FTmainFrame.caughtText:SetText(format("|cFFFFFFFF* "..L["MONEY_OR_CURRENCY_DROP"].." |r|cFF00C8C8"..L["NOT_COUNT_IN_DATABASE"].."|r"))
                -- ##### DEBUG #####
                if DEFAULT_DEBUG then
                    AddDebugMessage(format("|cFFFFFFFF* "..L["MONEY_OR_CURRENCY_DROP"].." |r|cFFFF00FF"..L["NOT_COUNT_IN_DATABASE"].."|r"))
                end
                -- #################
                break  -- Changed from return to break
            end

            -- Only process regular items (lootType 1) or quest items (lootType 4)
            if lootType == 1 or lootType == 4 then
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, 
                      itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(itemLink)

                if not itemName then
                    -- Item info not available yet, try to get it later
                    C_Timer.After(0.5, function()
                        local name, link = GetItemInfo(itemLink)
                        if name then
                            -- Re-process this specific item
                            local _, _, quantity = GetLootSlotInfo(i)
                            -- Create a proper item link for processing
                            local fullItemLink = link or itemLink
                            ProcessSingleLootItem(fullItemLink, quantity, i)
                        end
                    end)
                    break
                end

                local itemID = tonumber(itemLink:match("item:(%d+)")) or select(1, GetItemInfoInstant(itemName))
                local color = GetFishColor(itemID)
                local rarity = (color and quality) or 1
                -- ##### DEBUG #####
                if DEFAULT_DEBUG then
                    AddDebugMessage(format("|cFF00FFFF* 1st Check -- |r|cFFFFFFFF%s / %s%s|r / %s / %s|r", itemID, color, itemName, itemType, itemSubType))
                end
                -- #################

                if itemName or itemType then
                    local itemID = tonumber(itemLink:match("item:(%d+)")) or select(1, GetItemInfoInstant(itemName))

                    if itemID then
                        local caughtcount = quantity
                        local junkloot = 0
                            if db.config.trashcount == false then
                            -- print("DEFAULT TRASH COUNT is |cffff0000Disabled|r")
                                -- if itemSubType == L["JUNK"] or itemType == (L["ARMOR"] or L["WEAPON"]) or itemQuality == 0 or IsJunkItems(itemID) then
                                if itemSubType == L["JUNK"] or itemQuality == 0 or IsJunkItems(itemID) then
                                    itemSubType = L["JUNK"]
                                    if itemQuality > 0 or IsRareFish(itemID) or IsSpecialFish(itemID) or IsNotJunkItems(itemID) then
                                        caughtcount = quantity
                                        FTmainFrame.caughtText:SetPoint("LEFT", 10, 20)
                                        FTmainFrame.caughtText:Show()
                                        FTmainFrame.caughtText:SetText(format("|cFFFFFFFF* %s (x%d) "..L["CHECKED_RAREFISH_SPECIALFISH"].."|r", itemLink, quantity))
                                        -- ##### DEBUG #####
                                        if DEFAULT_DEBUG then
                                            AddDebugMessage(format("|cFFFFFFFF* Item: %s (x%d) "..L["CHECKED_RAREFISH_SPECIALFISH"].."|r", itemLink, quantity))
                                        end
                                        -- #################
                                    else
                                        caughtcount = 0
                                        junkloot = 1
                                        FTmainFrame.caughtText:SetPoint("LEFT", 10, 0)
                                        FTmainFrame.caughtText:Show()
                                        FTmainFrame.caughtText:SetText(format("|cFFFFFFFF* %s "..L["IS"].." |r|cFFFFFF00%s|r|cFFFFFFFF. |r|cFF00C8C8"..L["NOT_COUNT_IN_DATABASE"].."|r", itemLink, itemSubType))
                                        titleText:SetText("|T"..ADDON_ICON_TEXTURE..":16:16:0:0|t |T"..PNG_DOT[1]..":15:15:0:0|t "..L["FISHING_TRACKER"].." "..ADDON_VERSION.."|cFFFFFFFF"..SPACES.."|r")
                                        -- ##### DEBUG #####
                                        if DEFAULT_DEBUG then
                                            AddDebugMessage(format("|cFFFFFFFF* Item: %s "..L["IS"].." |r|cFFFFFF00%s|r|cFFFFFFFF "..L["OR"].." |r|cFFFFFF00"..L["BAD_QUALITY"].."|r|cFFFFFFFF. |r|cFFFF00FF"..L["NOT_COUNT_IN_DATABASE"].."|r", itemLink, itemSubType))
                                        end
                                        -- #################
                                    end
                                elseif caughtcount == quantity or string.find(string.lower(itemName), L["FISH"]) or itemType == (L["TRADESKILL"] or L["CONSUMABLE"] or L["QUEST"] or L["MISCELLANEOUS"]) or itemSubType == (L["COOKING"] or L["OTHER"] or L["QUEST"]) or IsRareFish(itemID) or IsSpecialFish(itemID) then
                                    -- ##### DEBUG #####
                                    if DEFAULT_DEBUG then
                                        AddDebugMessage(format("|cFFFFFF00* 2nd Check -- |r|cFFFFFFFF%s / %s%s|r / %s / %s|r", itemID, color, itemName, itemType, itemSubType))
                                    end
                                    -- #################
                                    db.totalCaught = db.totalCaught + quantity -- Add the full stack count to total

                                    -- Get item ID from link if possible
                                    itemID = tonumber(itemLink:match("item:(%d+)")) or select(1, GetItemInfoInstant(itemName))
                                end

                            else
                                -- print("DEFAULT TRASH COUNT is |cff00ff00Enabled|r")
                                if caughtcount == quantity or string.find(string.lower(itemName), L["FISH"]) or itemType == (L["TRADESKILL"] or L["CONSUMABLE"] or L["QUEST"] or L["MISCELLANEOUS"]) or itemSubType == (L["COOKING"] or L["OTHER"] or L["QUEST"]) or IsRareFish(itemID) or IsSpecialFish(itemID) then
                                    -- ##### DEBUG #####
                                    if DEFAULT_DEBUG then
                                        AddDebugMessage(format("|cFFFFFF00* 2nd Check -- |r|cFFFFFFFF%s / %s%s|r / %s / %s|r", itemID, color, itemName, itemType, itemSubType))
                                    end
                                    -- #################
                                    db.totalCaught = db.totalCaught + quantity -- Add the full stack count to total

                                    -- Get item ID from link if possible
                                    itemID = tonumber(itemLink:match("item:(%d+)")) or select(1, GetItemInfoInstant(itemName))
                                end
                            end

                        if junkloot == 0 then
                            -- Update global fish data
                            if not db.fishData[itemName] then
                                db.fishData[itemName] = {
                                    count = 0,
                                    itemID = itemID,
                                    itemType = itemType,
                                    itemSubType = itemSubType
                                }
                            end
                            db.fishData[itemName].count = db.fishData[itemName].count + quantity -- Add the full stack count
                            -- Update type info if it wasn't set before
                            db.fishData[itemName].itemType = db.fishData[itemName].itemType or itemType
                            db.fishData[itemName].itemSubType = db.fishData[itemName].itemSubType or itemSubType

                            -- Update zone data
                            local zoneKey, mapID, zoneName, subzoneName = GetZoneKey()
                            db.zoneData[zoneKey] = db.zoneData[zoneKey] or { 
                                total = 0, 
                                fishData = {},
                                mapID = mapID,
                                zoneName = zoneName,  -- Store proper zone name
                                subzoneName = subzoneName  -- Store proper subzone name
                            }

                            -- Ensure names are always up to date
                            db.zoneData[zoneKey].zoneName = zoneName
                            db.zoneData[zoneKey].subzoneName = subzoneName

                            -- Ensure mapID is updated if it was 0 previously
                            if db.zoneData[zoneKey].mapID == 0 then
                                db.zoneData[zoneKey].mapID = mapID
                            end

                            db.zoneData[zoneKey].total = db.zoneData[zoneKey].total + quantity -- Add the full stack count

                            if not db.zoneData[zoneKey].fishData[itemName] then
                                db.zoneData[zoneKey].fishData[itemName] = {
                                    count = 0,
                                    itemID = itemID,
                                    itemType = itemType,
                                    itemSubType = itemSubType
                                }
                            end
                            db.zoneData[zoneKey].fishData[itemName].count = db.zoneData[zoneKey].fishData[itemName].count + quantity -- Add the full stack count
                            -- Update type info if it wasn't set before
                            db.zoneData[zoneKey].fishData[itemName].itemType = db.zoneData[zoneKey].fishData[itemName].itemType or itemType
                            db.zoneData[zoneKey].fishData[itemName].itemSubType = db.zoneData[zoneKey].fishData[itemName].itemSubType or itemSubType

                            -- Update session data if tracking
                            if db.sessionData then
                                db.sessionData.fishCaught = db.sessionData.fishCaught + quantity -- Add the full stack count
                                if IsRareFish(itemID) then
                                    for i = 1, quantity do -- Add each item in the stack to rare fish list
                                        table.insert(db.sessionData.rareFish, itemName)
                                    end
                                    PlayRareFishSound()
                                end
                            end

                            -- Check for Quest item caught
                            if itemType == L["QUEST"] or itemSubType == L["QUEST"] then
                                PlayQuestFishSound()
                            end

                            if FTmainFrame:IsVisible() then
                                FTmainFrame.caughtText:SetPoint("LEFT", 10, 0)
                                FTmainFrame.caughtText:Show()
                                FTmainFrame.caughtText:SetText(format("|cFFFFFFFF* %s (x%d) |r|cFF00C8C8ID: %s "..L["SAVED"].."|r", itemLink, quantity, itemID))
                                -- ##### DEBUG #####
                                if DEFAULT_DEBUG then
                                    AddDebugMessage(format("|cFFFFFFFF* "..L["ITEM"].." %s (x%d) |r|cFFFF00FFCaught ID: %s "..L["SAVED"].."|r", itemLink, quantity, itemID))
                                end
                                -- #################
                                UpdateDisplay()
                                UpdateGlobalStatsDisplay()
                                pieText:SetText(formatNumberWithCommas(db.totalCaught))
                            end
                            junkloot = 0
                        end
                    end
                end
            end
        end
    end
end

local function CancelAutoHide()
    if FTmainFrame.hideTimer then
        FTmainFrame.hideTimer:Cancel()
        FTmainFrame.hideTimer = nil
    end
    FTmainFrame.timerText:Hide()
end

local function StartHideTimer()
    if not db.config.autoHide then return end
    if FTmainFrame.hideTimer then return end  -- Prevent duplicate timers
    if not FTmainFrame:IsVisible() then return end

    CancelAutoHide()

    FTmainFrame.timeLeft = math.max(1, db.config.autoHideDelay or DEFAULT_AUTO_HIDE_DELAY)
    FTmainFrame.timerText:Show()
    FTmainFrame.timerText:SetText(L["CLOSING_IN"].." |cFFFF0000"..format("%02d", FTmainFrame.timeLeft).."|r "..L["SECONDS"])

    -- Always show mini stats during countdown if we have session data
    if db.sessionData then
        FTmainFrame.miniStats:Show()
        UpdateMiniStats()
    end

    FTmainFrame.hideTimer = C_Timer.NewTicker(1, function()
        if not FTmainFrame:IsVisible() then
            CancelAutoHide()
            return
        end

        FTmainFrame.timeLeft = FTmainFrame.timeLeft - 1
        FTmainFrame.timerText:SetText(L["CLOSING_IN"].." |cFFFF0000"..format("%02d", FTmainFrame.timeLeft).."|r "..L["SECONDS"])

        if FTmainFrame.timeLeft <= 5 then
            titleText:SetText("|T"..ADDON_ICON_TEXTURE..":16:16:0:0|t |T"..PNG_DOT[4]..":15:15:0:0|t "..L["FISHING_TRACKER"].." "..ADDON_VERSION.."|cFFFFFFFF"..SPACES.."|r")
        end

        -- Update stats each tick if we have session data
        if db.sessionData then
            UpdateMiniStats()
        end

        if FTmainFrame.timeLeft <= 0 then
            CancelAutoHide()
            UIFrameFadeOut(FTmainFrame, DEFAULT_WATCHDRAGGER_FADE_TIME, 1, 0)
            UIFrameFadeOut(pieTextFrame, DEFAULT_WATCHDRAGGER_FADE_TIME, 1, 0)
            C_Timer.After(DEFAULT_WATCHDRAGGER_FADE_TIME, function()
                if FTmainFrame:IsVisible() then
                    FTmainFrame:Hide()
                    pieTextFrame:Hide()
                end
            end)
        end
    end)
end

local function ShowFishingFrame()
    CancelAutoHide()
    highlight:Show()
    UIFrameFadeIn(FTmainFrame, DEFAULT_WATCHDRAGGER_FADE_TIME, 0, 1)
    UIFrameFadeIn(highlight, DEFAULT_WATCHDRAGGER_FADE_TIME, 0, 0.15)
    UIFrameFadeIn(pieTextFrame, DEFAULT_WATCHDRAGGER_FADE_TIME, 0, 1)
    UpdateDisplay()
    FTmainFrame:Show()
    pieTextFrame:Show()
end

local function ShowHelp()
    print(format(L["HELP_TITLE"], ADDON_VERSION))
    print("|cFF00FF00/ft|r or |cFF00FF00/fishingtracker|r"..L["HELP_TOGGLE"])
    print("|cFF00FF00/ft stats|r"..L["HELP_STATS"])
    print("|cFF00FF00/ft lock|r"..L["HELP_LOCK"])
    print("|cFF00FF00/ft sound|r"..L["HELP_SOUND"])
    print("|cFF00FF00/ft bg <on/off/0.1-1.0>|r"..L["HELP_BG"])
    print("|cFF00FF00/ft scale <0.5-2.0>|r"..L["HELP_SCALE"])
    print("|cFF00FF00/ft transparency <0.1-1.0>|r"..L["HELP_TRANSPARENCY"])
    print("|cFF00FF00/ft debug|r"..L["HELP_DEBUG"])
    print("|cFF00FF00/ft resetui|r"..L["HELP_RESETUI"])
    print("|cFF00FF00/ft convert|r"..L["HELP_CONVERT"])
    print("|cFF00FF00/ft trash|r"..L["HELP_TRASH"])
    print("|cFF00FF00/ft help|r"..L["HELP_HELP"])
end

FTmainFrame:SetScript("OnHide", function()
    CancelAutoHide()
    highlight:Hide()
    EndFishingSession()
end)

--------------------------------------------------------------------------------------------------------------
-- 13. EVENT HANDLING
--------------------------------------------------------------------------------------------------------------
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            db = InitializeDB()
            DeepCleanDatabase()

            if db.globalStatsUI then
                globalStatsFrame:ClearAllPoints()
                globalStatsFrame:SetPoint(db.globalStatsUI.point, UIParent, db.globalStatsUI.relativePoint, db.globalStatsUI.x, db.globalStatsUI.y)
                globalStatsFrame:SetScale(db.globalStatsUI.scale)
            end

            UpdateFrameTransparency()

            -- FORCE UPDATE GLOBAL STATS HEADER AFTER DB LOAD
            C_Timer.After(0.5, function()
                if globalStatsFrame and globalStatsFrame.headerText then
                    globalStatsFrame.headerText:SetText(format("\n"..L["FISHING_STATISTICS_SUMMARY"].."\n"..L["TOTAL_FISH_CAUGHT"].." |cFF00FFC8%s|r\n"..L["TOTAL_FISH_TYPES"].." |cFF00FFC8%d|r\n"..L["TOTAL_ZONES"].." |cFF00FFC8%d|r\n", 
                        formatNumberWithCommas(db.totalCaught or 0), 
                        formatNumberWithCommas(CountTableEntries(db.fishData or {})), 
                        formatNumberWithCommas(CountTableEntries(db.zoneData or {}))))
                end
            end)

            -- Register other events after ADDON_LOADED
            self:RegisterEvent("LOOT_OPENED")
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
            self:RegisterEvent("PLAYER_LOGIN")
            self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
            self:RegisterEvent("SKILL_LINES_CHANGED")
            self:RegisterEvent("SPELLS_CHANGED")
            self:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
            self:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
            self:RegisterEvent("UNIT_AURA")
            self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
            self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
            self:RegisterEvent("UNIT_SPELLCAST_STOP")
            self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
            self:RegisterEvent("ZONE_CHANGED")
            self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        end

        if db.ui then
            FTmainFrame:SetSize(db.ui.width, db.ui.height)
            FTmainFrame:ClearAllPoints()
            FTmainFrame:SetPoint(db.ui.point, UIParent, db.ui.relativePoint, db.ui.x, db.ui.y)
            FTmainFrame:SetScale(db.ui.scale)
        end

        minimapButton:SetShown(db.config.minimap.show)
        UpdateMinimapButtonPosition()
        UpdateFrameTransparency()
        UpdateDisplay()
        UpdateGlobalStatsDisplay()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID == FISHING_SPELL_ID then
            ShowFishingFrame()
            StartFishingSession()
            -- Add raid warning with instance name
            local currentInstanceName, currentInstanceType, _, _, _, _, _, currentinstanceMapID = GetInstanceInfo()
            local mapID = C_Map.GetBestMapForUnit("player")
            -- ##### DEBUG #####
            if DEFAULT_DEBUG then
                RaidNotice_AddMessage(RaidWarningFrame, format(L["FISHING_IN"].." %s (%d)", currentInstanceName, currentinstanceMapID), ChatTypeInfo["RAID_WARNING"])
                RaidNotice_AddMessage(RaidWarningFrame, format(L["YOU_ARE_IN"].." %s (%d)", C_Map.GetMapInfo(mapID).name, mapID), ChatTypeInfo["RAID_WARNING"])
            end
            -- #################
            titleText:SetText("|T"..ADDON_ICON_TEXTURE..":16:16:0:0|t |T"..PNG_DOT[3]..":15:15:0:0|t "..L["FISHING_TRACKER"].." "..ADDON_VERSION.."|cFFFFFFFF"..SPACES.."|r")
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" then
            if FTmainFrame:IsVisible() then
                UIFrameFadeOut(highlight, DEFAULT_WATCHDRAGGER_FADE_TIME, 0.15, 0)
                StartHideTimer()
            end
        end

    elseif event == "LOOT_OPENED" then
        HandleLoot()
        -- Only start hide timer if we're not tracking a session
        if FTmainFrame:IsVisible() and not db.sessionData then
            StartHideTimer()
        end

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            if FTmainFrame:IsVisible() then
                if ShouldAutoHide() then
                    StartHideTimer()
                else
                    CancelAutoHide()
                end
            end
        end

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "ZONE_CHANGED" then
        if FTmainFrame:IsVisible() then
            if ShouldAutoHide() then
                StartHideTimer()
            else
                CancelAutoHide()
            end
        end

    elseif event == "LOOT_OPENED" then
        HandleLoot()

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        if FTmainFrame:IsVisible() then
            if ShouldAutoHide() then
                StartHideTimer()
        else
                CancelAutoHide()
            end
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE" then
        local slot = ...
        if not slot or slot == 28 then -- Profession tool slot
            UpdateFishingPoleIcon()
        end

    end
end)

C_Timer.After(5, function()
    if not FTmainFrame.fishingSkillText:GetText() or FTmainFrame.fishingSkillText:GetText() == "" then
        UpdateDisplay()
        UpdateGlobalStatsDisplay()
    end
end)

-- Initialize debug frame if debug mode is on
-- ##### DEBUG #####
if DEFAULT_DEBUG then
    debugFrame:Show()
else
    debugFrame:Hide()
end
-- #################

-- Initial event registration
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE")

--------------------------------------------------------------------------------------------------------------
-- 14. SLASH COMMANDS
--------------------------------------------------------------------------------------------------------------
SLASH_FISHINGTRACKER1 = "/ft"
SLASH_FISHINGTRACKER2 = "/fishingtracker"
SlashCmdList["FISHINGTRACKER"] = function(msg)
    -- First handle empty command (just /ft or /fishingtracker)
    if msg == "" then
        -- Toggle main frame
        if FTmainFrame:IsVisible() then
            CancelAutoHide()
            UIFrameFadeOut(FTmainFrame, DEFAULT_WATCHDRAGGER_FADE_TIME, 1, 0)
            C_Timer.After(DEFAULT_WATCHDRAGGER_FADE_TIME, function() FTmainFrame:Hide() end)
        else
            ShowFishingFrame()
            -- Refresh global stats if visible
            if globalStatsFrame:IsVisible() then
                UpdateGlobalStatsDisplay()
            end
            print(addonName..L["SHOWING_FISHING_DATA"], formatNumberWithCommas(db.totalCaught))
        end
        return
    end

    -- Initialize DB and update displays
    db = InitializeDB()
    UpdateFrameTransparency()
    UpdateDisplay()
    UpdateGlobalStatsDisplay()

    local _, _, command, value = msg:lower():find("^(%S+)%s*(%S*)$")
    command = command or msg:lower()

    if command == "help" then
        ShowHelp()
        return
    elseif command == "stats" or command == "global" then
        -- Toggle global stats frame
        if globalStatsFrame:IsVisible() then
            globalStatsFrame:Hide()
        else
            -- Ensure header is initialized before showing
            SafeInitializeHeader()
            UpdateGlobalStatsDisplay()
            globalStatsFrame:Show()
        end
        return
    elseif command == "lock" then
        db.config.frameLocked = not db.config.frameLocked
        print(addonName..L["FRAME_IS_NOW"]..(db.config.frameLocked and "|cFFFF0000"..L["LOCKED"].."|r" or "|cFF00FF00"..L["UNLOCKED"].."|r"))
        -- Update Frame Lock icon
        UpdateLockTexture()
        return
    elseif command == "sound" then
        db.config.enableSound = not db.config.enableSound
        print(addonName..L["SOUND"]..(db.config.enableSound and "|cFF00FF00"..L["ENABLED"].."|r" or "|cFFFF0000"..L["DISABLED"].."|r"))
        return
    elseif command == "bg" or command == "background" then
        if value == "on" then
            db.config.enableBackground = true
            print(addonName..L["BACKGROUND"].."|cFF00FF00"..L["ENABLED"].."|r")
        elseif value == "off" then
            db.config.enableBackground = false
            print(addonName..L["BACKGROUND"].."|cFFFF0000"..L["DISABLED"].."|r")
        elseif tonumber(value) then
            local alpha = tonumber(value)
            if alpha and alpha >= 0.1 and alpha <= 1 then
                db.config.backgroundAlpha = alpha
                print(addonName..L["BG_TRANSPARENCY_SET"], alpha)
            else
                print(addonName..L["BG_TRANSPARENCY_MUST"])
            end
        else
            db.config.enableBackground = not db.config.enableBackground
            print(addonName..L["BACKGROUND"]..(db.config.enableBackground and "|cFF00FF00"..L["ENABLED"].."|r" or "|cFFFF0000"..L["DISABLED"].."|r"))
        end
        UpdateBackgroundSettings()
        return
    elseif command == "scale" and tonumber(value) then
        local scale = tonumber(value)
        if scale and scale >= 0.5 and scale <= 2.0 then
            db.ui.scale = scale
            -- Reset position
            db.ui.x = 0
            db.ui.y = -290

            FTmainFrame:ClearAllPoints()
            FTmainFrame:SetPoint("TOP", UIParent, "TOP", db.ui.x, db.ui.y)
            FTmainFrame:SetScale(scale)
            print(addonName..L["SCALE_SET"]..scale..L["POSITION_RESET"])
            print(format(addonName.." UI X:%d UI Y:%d", db.ui.x, db.ui.y))
        else
            print(addonName..L["SCALE_MUST"])
        end
        return
    elseif command == "transparency" and tonumber(value) then
        local alpha = tonumber(value)
        if alpha and alpha >= 0.1 and alpha <= 1 then
            db.config.transparency = alpha
            UpdateFrameTransparency()
            print(addonName..L["TRANSPARENCY_SET"], alpha)
        else
            print(addonName..L["BG_TRANSPARENCY_MUST"])
        end
        return
    elseif command == "debug" then
        DEFAULT_DEBUG = not DEFAULT_DEBUG
        print(addonName..L["DEBUG_MODE"]..(DEFAULT_DEBUG and "|cFF00FF00"..L["ENABLED"].."|r" or "|cFFFF0000"..L["DISABLED"].."|r"))
        -- ##### DEBUG #####
        if DEFAULT_DEBUG then
            debugFrame:Show()
        else
            debugFrame:Hide()
        end
        -- #################
        return
    elseif command == "debugheader" then
        if globalStatsFrame then
            DebugHeaderStatus()
        else
            print("Global stats frame not created yet")
        end
        return
    elseif command == "resetui" then
        -- Reset main frame UI
        db.ui = {
            width = DEFAULT_FRAME_WIDTH,
            height = DEFAULT_FRAME_HEIGHT,
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = -290,
            scale = DEFAULT_SCALE
        }
        FTmainFrame:SetSize(db.ui.width, db.ui.height)
        FTmainFrame:ClearAllPoints()
        FTmainFrame:SetPoint(db.ui.point, UIParent, db.ui.relativePoint, db.ui.x, db.ui.y)
        FTmainFrame:SetScale(db.ui.scale)

        -- Reset global stats frame UI
        db.globalStatsUI = {
            point = "TOP",
            relativePoint = "TOP",
            x = 300,
            y = -290,
            scale = DEFAULT_SCALE
        }
        globalStatsFrame:ClearAllPoints()
        globalStatsFrame:SetPoint(db.globalStatsUI.point, UIParent, db.globalStatsUI.relativePoint, db.globalStatsUI.x, db.globalStatsUI.y)
        globalStatsFrame:SetScale(db.globalStatsUI.scale)

        print(addonName..L["FRAME_POSITION_RESET"])
        print(addonName..L["GLOBAL_STATS_POSITION_RESET"])
        return
    elseif command == "convert" then
        private.ConvertFishingBuddyData()
        return
    elseif command == "trash" or command == "trashcount" then
        db.config.trashcount = not db.config.trashcount
        DEFAULT_TRASH_COUNT = db.config.trashcount
        print(addonName..L["TRASH_COUNT"]..(db.config.trashcount and "|cFF00FF00"..L["ENABLED"].."|r" or "|cFFFF0000"..L["DISABLED"].."|r"))
        return
    end

    -- If we get here, the command wasn't recognized - show help
    ShowHelp()
end

-- Initialize the addon
minimapButton:SetShown(db.config.minimap.show)
UpdateMinimapButtonPosition()
UpdateFrameTransparency()

--------------------------------------------------------------------------------------------------------------
-- 15. ADDON LOADED MESSAGE
--------------------------------------------------------------------------------------------------------------
local AddonFrame = CreateFrame("Frame")
AddonFrame:RegisterEvent("ADDON_LOADED")
AddonFrame:SetScript("OnEvent", function(thisFrame, event, ...)
    if (event == "ADDON_LOADED") then
        local addonName = ...
        if (addonName == ADDON_NAME) then
            print(format(L["LOADED_MESSAGE"], ADDON_TITLE, ADDON_VERSION))
            print(format("|c7F7F7FFF< %s "..L["TOTAL_FISH_CAUGHT"].." |cFFFFFFFF%s|r >", ADDON_TITLE, formatNumberWithCommas(db.totalCaught)))
            print(format("|c7F7F7FFF< %s "..L["TOTAL_FISH_TYPES"].." |cFFFFFFFF%d|r >", ADDON_TITLE, formatNumberWithCommas(CountTableEntries(db.fishData))))
            print(format("|c7F7F7FFF< %s "..L["TOTAL_ZONES"].." |cFFFFFFFF%d|r >", ADDON_TITLE, formatNumberWithCommas(CountTableEntries(db.zoneData))))
            AddonFrame:UnregisterEvent("ADDON_LOADED")
        end
    end
end)

---- End of File ----