-- Mounted lumber harvesting: progress on the twelve Lumberjack achievements.
--
-- Patch 12.0.1 added one account-wide achievement per expansion, each
-- "Harvest 250 <wood> Lumber". Earning one lets you chop that expansion's
-- trees without dismounting -- the reward line reads "Mounted Lumber
-- Harvesting in <expansion> Zones". There is no meta achievement. Ids, names
-- and lumber item ids were checked against Wowhead's tooltip API on
-- 2026-10-11; 62367 and 62368, in the middle of the run, are not lumber.
--
-- Progress is read from the achievement API on every refresh and never
-- stored: the game already keeps the count account-wide, and a copy here
-- could only go stale. The one thing remembered is which wood was handled
-- last, so the radar HUD keeps showing the relevant expansion after a reload.

local H = FabledUI_Harvest
if not H then return end

H.Lumberjack = {}
local L = H.Lumberjack

L.REQUIRED_DEFAULT = 250

-- Oldest expansion first; the window lists them in this order. `short` is
-- what fits on the 220px radar HUD.
L.ACHIEVEMENTS = {
    { id = 62357, expansion = "Classic",                short = "Classic",  name = "Classically Trained Lumberjack", lumber = "Ironwood Lumber",    itemID = 245586 },
    { id = 62358, expansion = "Burning Crusade",        short = "TBC",      name = "Outlandish Lumberjack",          lumber = "Olemba Lumber",      itemID = 242691 },
    { id = 62359, expansion = "Wrath of the Lich King", short = "Wrath",    name = "Wrathful Lumberjack",            lumber = "Coldwind Lumber",    itemID = 251762 },
    { id = 62360, expansion = "Cataclysm",              short = "Cata",     name = "Cataclysmic Lumberjack",         lumber = "Ashwood Lumber",     itemID = 251764 },
    { id = 62361, expansion = "Mists of Pandaria",      short = "MoP",      name = "Mist-Shrouded Lumberjack",       lumber = "Bamboo Lumber",      itemID = 251763 },
    { id = 62362, expansion = "Warlords of Draenor",    short = "WoD",      name = "Lumberjack Warlord",             lumber = "Shadowmoon Lumber",  itemID = 251766 },
    { id = 62363, expansion = "Legion",                 short = "Legion",   name = "Legion Lumberjack",              lumber = "Fel-Touched Lumber", itemID = 251767 },
    { id = 62364, expansion = "Battle for Azeroth",     short = "BfA",      name = "Azeroth's Lumberjack",           lumber = "Darkpine Lumber",    itemID = 251768 },
    { id = 62365, expansion = "Shadowlands",            short = "SL",       name = "Shadowy Lumberjack",             lumber = "Arden Lumber",       itemID = 251772 },
    { id = 62366, expansion = "Dragonflight",           short = "DF",       name = "Draconic Lumberjack",            lumber = "Dragonpine Lumber",  itemID = 251773 },
    { id = 62369, expansion = "The War Within",         short = "TWW",      name = "The Lumberjack Within",          lumber = "Dornic Fir Lumber",  itemID = 248012 },
    { id = 62370, expansion = "Midnight",               short = "Midnight", name = "Midnight Lumberjack",            lumber = "Thalassian Lumber",  itemID = 256963 },
}

-- =============================================================================
-- Game API seam
-- =============================================================================

-- The globals are looked up per call, never captured at load, and kept on the
-- module so tests can substitute them: the simulator shadows its own
-- achievement API, so a test cannot stub the globals themselves.
local function Global(name)
    return function(...)
        local fn = rawget(_G, name)
        if type(fn) == "function" then return fn(...) end
    end
end

L.api = {
    GetAchievementInfo         = Global("GetAchievementInfo"),
    GetAchievementNumCriteria  = Global("GetAchievementNumCriteria"),
    GetAchievementCriteriaInfo = Global("GetAchievementCriteriaInfo"),
    GetItemCount = function(itemID)
        if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) end
        local legacy = rawget(_G, "GetItemCount")
        if type(legacy) == "function" then return legacy(itemID) end
    end,
}

local function Number(value)
    if type(value) == "number" then return value end
    return nil
end

local function Now()
    return (GetTime and GetTime()) or 0
end

-- =============================================================================
-- Reading progress
-- =============================================================================

function L:Entry(id)
    for _, entry in ipairs(self.ACHIEVEMENTS) do
        if entry.id == id then return entry end
    end
    return nil
end

--- One achievement's live state. Never errors: an id the client does not know
--- comes back `known = false` with the shipped name and no progress, so a
--- Blizzard renumbering shows up as a flagged row rather than a Lua error.
function L:Read(entry)
    local api = self.api
    local record = {
        id = entry.id,
        expansion = entry.expansion,
        short = entry.short,
        name = entry.name,
        lumber = entry.lumber,
        itemID = entry.itemID,
        known = false,
        completed = false,
        quantity = 0,
        required = self.REQUIRED_DEFAULT,
    }

    local ok, _, name, _, completed, _, _, _, _, _, icon = pcall(api.GetAchievementInfo, entry.id)
    if not (ok and type(name) == "string" and name ~= "") then
        return record
    end
    record.known = true
    record.name = name
    record.completed = completed and true or false
    record.icon = icon

    local countOK, count = pcall(api.GetAchievementNumCriteria, entry.id)
    if countOK and Number(count) and count >= 1 then
        local critOK, _, _, _, quantity, required = pcall(api.GetAchievementCriteriaInfo, entry.id, 1)
        if critOK then
            record.quantity = Number(quantity) or 0
            if Number(required) and required > 0 then record.required = required end
        end
    end

    -- An unlocked expansion reads full whatever its criterion reports, so the
    -- bar can never show something already earned as short.
    if record.completed then record.quantity = record.required end
    if record.quantity > record.required then record.quantity = record.required end
    if record.quantity < 0 then record.quantity = 0 end
    return record
end

--- Every achievement in expansion order, plus how many are unlocked.
function L:ReadAll()
    local records, done = {}, 0
    for index, entry in ipairs(self.ACHIEVEMENTS) do
        local record = self:Read(entry)
        records[index] = record
        if record.completed then done = done + 1 end
    end
    return records, done, #self.ACHIEVEMENTS
end

-- =============================================================================
-- Which wood is being chopped
-- =============================================================================

-- How long after Init bag counts are only recorded, not compared. Bags can
-- still be filling in at login, and a stack arriving then is not a chop.
local SETTLE_SECONDS = 10

function L:CountLumber()
    local counts = {}
    for _, entry in ipairs(self.ACHIEVEMENTS) do
        local ok, n = pcall(self.api.GetItemCount, entry.itemID)
        counts[entry.id] = (ok and Number(n)) or 0
    end
    return counts
end

--- Compare lumber counts in the bags with the last look. The wood whose count
--- went up is the one being chopped, so it becomes the active one -- this
--- works for an expansion already unlocked, where the achievement criterion
--- has nothing left to count. Returns the achievement id that rose, if any.
function L:NoteBags()
    local counts = self:CountLumber()
    local previous = self._counts
    self._counts = counts
    if not previous or Now() - (self._initAt or 0) < SETTLE_SECONDS then
        return nil
    end

    local bestID, bestRise
    for id, n in pairs(counts) do
        local rise = n - (previous[id] or 0)
        if rise > 0 and (not bestRise or rise > bestRise) then
            bestID, bestRise = id, rise
        end
    end
    if bestID then self:SetActive(bestID) end
    return bestID
end

function L:SetActive(id)
    if not self:Entry(id) then return end
    self.activeID = id
    -- An achievement id is durable, unlike the housing handles; safe to keep.
    if H.settings then H.settings.lumberjackLast = id end
end

function L:GetActiveID()
    local id = self.activeID or (H.settings and H.settings.lumberjackLast)
    if id and self:Entry(id) then return id end
    return nil
end

-- =============================================================================
-- Text for the HUD and chat
-- =============================================================================

local GREEN = "|cff33ff99"
local GREY = "|cff9d9d9d"
local RED = "|cffff6060"

--- One line for the radar HUD: the active wood's progress, or the overall
--- count when no wood has been chopped since the addon started tracking.
function L:HudText()
    local id = self:GetActiveID()
    if id then
        local record = self:Read(self:Entry(id))
        if record.completed then
            return string.format("%sMounted chop: %s unlocked|r", GREEN, record.short)
        end
        return string.format("Mounted chop, %s: %d/%d", record.short, record.quantity, record.required)
    end
    local _, done, total = self:ReadAll()
    return string.format("Mounted chop: %d/%d expansions", done, total)
end

--- Right-hand status for one record, shared by the window and chat.
function L:StatusText(record)
    if not record.known then
        return RED .. "not found on this client|r"
    elseif record.completed then
        return GREEN .. "Unlocked|r"
    end
    return string.format("%d / %d", record.quantity, record.required)
end

function L:PrintSummary()
    local records, done, total = self:ReadAll()
    H:Print(string.format("Mounted lumber harvesting: %d of %d expansions unlocked.", done, total))
    local activeID = self:GetActiveID()
    for _, record in ipairs(records) do
        local line = string.format("  %s: %s", record.expansion, self:StatusText(record))
        if not record.completed and record.known then
            line = line .. " " .. GREY .. record.lumber .. "|r"
        end
        if record.id == activeID then
            line = line .. GREY .. " (last chopped)|r"
        end
        H:Print(line)
    end
end

--- Open Blizzard's achievement window on one of these. Returns true if the
--- call went through.
function L:OpenAchievement(id)
    if not id then return false end
    -- Blizzard_AchievementUI is load-on-demand; loading it in combat is not
    -- something to gamble a click on.
    if InCombatLockdown and InCombatLockdown() then
        H:Print("Can't open the achievement window in combat.")
        return false
    end
    local open = rawget(_G, "OpenAchievementFrameToAchievement")
    if type(open) ~= "function" then return false end
    local ok = pcall(open, id)
    return ok and true or false
end

-- =============================================================================
-- Events
-- =============================================================================

-- CRITERIA_UPDATE has no payload and can fire many times a second in combat;
-- one read per half second is plenty for a count that moves one chop at a time.
local REFRESH_DELAY = 0.5

function L:ScheduleRefresh()
    if self._pending then return end
    if not (C_Timer and C_Timer.After) then
        self:Refresh()
        return
    end
    self._pending = true
    C_Timer.After(REFRESH_DELAY, function()
        self._pending = false
        self:Refresh()
    end)
end

--- Push fresh numbers to whatever is showing them.
function L:Refresh()
    if H.RadarHUD and H.RadarHUD.RefreshLumberjack then
        H.RadarHUD:RefreshLumberjack()
    end
    local W = H.Window
    if W and W.activeTab == "lumberjack" and W.window and W.window:IsShown() and W.RefreshLumberjack then
        W:RefreshLumberjack()
    end
end

function L:Init()
    if self._frame then return end
    self._initAt = Now()
    self._counts = self:CountLumber()

    local frame = CreateFrame("Frame")
    self._frame = frame
    -- SetScript before RegisterEvent: a frame must never hold a live
    -- registration with no handler attached.
    frame:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE_DELAYED" then
            if self:NoteBags() then self:ScheduleRefresh() end
        else
            self:ScheduleRefresh()
        end
    end)
    frame:RegisterEvent("CRITERIA_UPDATE")
    frame:RegisterEvent("ACHIEVEMENT_EARNED")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")

    self:Refresh()
end
