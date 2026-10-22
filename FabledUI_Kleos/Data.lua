local K = Kleos
K.Data = {
    -- Curated lists are user-visible "specials". Kleos ships two seeded lists
    -- and the open API (API.lua) lets other addons register more.
    CURATED = {},
    EVENTS = {},
    PVP = {},
}

-- ============================================================================
-- EXPANSION_ALIAS / EXPANSION_ID_MAP
-- Lifted from CCM (CCM.lua:80-115) for consistent expansion-name parsing
-- across the Kleos achievement-category and filter pipelines.
-- ============================================================================

-- Lowercase substring -> canonical full name. Use lowercased category names
-- (or any user-entered token) as keys.
K.Data.EXPANSION_ALIAS = {
    ["classic"]                    = "Classic",
    ["the burning crusade"]        = "The Burning Crusade",
    ["burning crusade"]            = "The Burning Crusade",
    ["wrath of the lich king"]     = "Wrath of the Lich King",
    ["cataclysm"]                  = "Cataclysm",
    ["mists of pandaria"]          = "Mists of Pandaria",
    ["warlords of draenor"]        = "Warlords of Draenor",
    ["legion"]                     = "Legion",
    ["battle for azeroth"]         = "Battle for Azeroth",
    ["shadowlands"]                = "Shadowlands",
    ["dragonflight"]               = "Dragonflight",
    ["the war within"]             = "The War Within",
    ["war within"]                 = "The War Within",
    ["tww"]                        = "The War Within",
    ["khaz algar"]                 = "The War Within",
    ["khaz'algar"]                 = "The War Within",
    ["midnight"]                   = "Midnight",
    ["wotlk"]                      = "Wrath of the Lich King",
    ["bfa"]                        = "Battle for Azeroth",
    ["mop"]                        = "Mists of Pandaria",
    ["wod"]                        = "Warlords of Draenor",
    ["cata"]                       = "Cataclysm",
    ["tbc"]                        = "The Burning Crusade",
}

-- Numeric expansion-id fallback (matches GetExpansionLevel-style ordinals).
K.Data.EXPANSION_ID_MAP = {
    [0]  = "Classic",
    [1]  = "The Burning Crusade",
    [2]  = "Wrath of the Lich King",
    [3]  = "Cataclysm",
    [4]  = "Mists of Pandaria",
    [5]  = "Warlords of Draenor",
    [6]  = "Legion",
    [7]  = "Battle for Azeroth",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
}

-- Canonical full-name -> internal short key. This is the single source of
-- truth for the short keys; UI.lua and Catalog.lua both read it rather than
-- keeping their own copy (the previous split copy is why Midnight existed in
-- the alias table but could never be selected in the UI).
K.Data.EXPANSION_FULLNAME_TO_KEY = {
    ["Classic"]                = "CLASSIC",
    ["The Burning Crusade"]    = "TBC",
    ["Wrath of the Lich King"] = "WOTLK",
    ["Cataclysm"]              = "CATA",
    ["Mists of Pandaria"]      = "MOP",
    ["Warlords of Draenor"]    = "WOD",
    ["Legion"]                 = "LEGION",
    ["Battle for Azeroth"]     = "BFA",
    ["Shadowlands"]            = "SHADOWLANDS",
    ["Dragonflight"]           = "DRAGONFLIGHT",
    ["The War Within"]         = "TWW",
    ["Midnight"]               = "MIDNIGHT",
}

K.Data.EXPANSION_KEY_TO_FULLNAME = {}
for full, key in pairs(K.Data.EXPANSION_FULLNAME_TO_KEY) do
    K.Data.EXPANSION_KEY_TO_FULLNAME[key] = full
end

-- Newest first; "ALL" is prepended by the UI.
K.Data.EXPANSION_ORDER = {
    "MIDNIGHT", "TWW", "DRAGONFLIGHT", "SHADOWLANDS", "BFA", "LEGION",
    "WOD", "MOP", "CATA", "WOTLK", "TBC", "CLASSIC",
}

-- Static root-category hints. Blizzard renumbers these between expansions, so
-- Catalog.lua treats them as a hint and prefers name resolution on the
-- category chain. MIDNIGHT deliberately has no hint: it is resolved by name.
K.Data.EXPANSION_ROOT_HINTS = {
    [15312] = "Classic",
    [15313] = "The Burning Crusade",
    [15272] = "Wrath of the Lich King",
    [15318] = "Cataclysm",
    [15320] = "Mists of Pandaria",
    [15462] = "Warlords of Draenor",
    [15478] = "Legion",
    [13593] = "Battle for Azeroth",
    [15837] = "Shadowlands",
    [15921] = "Dragonflight",
    [16573] = "The War Within",
}

-- Resolve an arbitrary string (lowered) to a canonical expansion full-name.
-- Returns nil when no alias matches.
function K.Data:ResolveExpansionName(text)
    if type(text) ~= "string" or text == "" then return nil end
    local lower = text:lower()
    -- Exact key first (cheaper path)
    if self.EXPANSION_ALIAS[lower] then return self.EXPANSION_ALIAS[lower] end
    -- Substring fallback for category-name parsing
    for key, full in pairs(self.EXPANSION_ALIAS) do
        if lower:find(key, 1, true) then return full end
    end
    return nil
end

-- Resolve a numeric ordinal to a canonical full-name.
function K.Data:ResolveExpansionId(id)
    id = tonumber(id)
    return id and self.EXPANSION_ID_MAP[id] or nil
end

function K.Data:ExpansionKey(text)
    local full = self:ResolveExpansionName(text)
    return full and self.EXPANSION_FULLNAME_TO_KEY[full] or nil
end

-- ============================================================================
-- Achievement "kind" classification
-- The PRD asks for sorting by expansion, zone, dungeon, raid, pet battle,
-- event and PvP. Blizzard exposes none of that directly, so kind is derived
-- from the category chain: the localised category name is matched against
-- keyword sets, and the root category id gives a coarse fallback.
-- ============================================================================

K.Data.KIND_ORDER = {
    "ZONE", "DUNGEON", "RAID", "PVP", "EVENT", "PETBATTLE", "PROFESSION",
    "REPUTATION", "QUEST", "EXPLORATION", "COLLECTION", "CHARACTER", "FEAT", "OTHER",
}

-- Root category ids that are stable across expansions (Blizzard's top level).
K.Data.ROOT_CATEGORY_KIND = {
    [92]    = "CHARACTER",     -- General
    [96]    = "QUEST",         -- Quests
    [97]    = "EXPLORATION",   -- Exploration
    [95]    = "PVP",           -- Player vs. Player
    [168]   = "DUNGEON",       -- Dungeons & Raids
    [169]   = "PROFESSION",    -- Professions
    [201]   = "REPUTATION",    -- Reputation
    [155]   = "EVENT",         -- World Events
    [81]    = "FEAT",          -- Feats of Strength
    [15246] = "COLLECTION",    -- Collections
    [15117] = "OTHER",         -- Expansion Features
    [15522] = "CHARACTER",     -- Character
    [15234] = "PETBATTLE",     -- Pet Battles
}

-- Lowercase keyword -> kind. Checked against every category name on the chain,
-- most specific first (RAID before DUNGEON so "Raids" doesn't land on dungeon).
K.Data.KIND_KEYWORDS = {
    { "raid",            "RAID" },
    { "dungeon",         "DUNGEON" },
    { "pet battle",      "PETBATTLE" },
    { "battle pet",      "PETBATTLE" },
    { "player vs",       "PVP" },
    { "arena",           "PVP" },
    { "battleground",    "PVP" },
    { "rated",           "PVP" },
    { "world event",     "EVENT" },
    { "holiday",         "EVENT" },
    { "profession",      "PROFESSION" },
    { "reputation",      "REPUTATION" },
    { "quest",           "QUEST" },
    { "exploration",     "EXPLORATION" },
    { "collection",      "COLLECTION" },
    { "feat of strength","FEAT" },
    { "feats of strength","FEAT" },
    { "housing",         "ZONE" },
    { "delve",           "DUNGEON" },
    { "scenario",        "DUNGEON" },
}

function K.Data:ResolveKindFromName(text)
    if type(text) ~= "string" or text == "" then return nil end
    local lower = text:lower()
    for _, pair in ipairs(self.KIND_KEYWORDS) do
        if lower:find(pair[1], 1, true) then return pair[2] end
    end
    return nil
end

-- ============================================================================
-- Seeded event windows
-- Reminders.lua prefers the live calendar; these windows are the fallback for
-- recurring holidays whose achievements players routinely miss. `month`/`day`
-- are approximate start dates and `days` the usual duration.
-- ============================================================================
K.Data.EVENT_WINDOWS = {
    { key = "LUNAR_FESTIVAL",  name = "Lunar Festival",         month = 1,  day = 29, days = 15 },
    { key = "LOVE_IN_AIR",     name = "Love is in the Air",     month = 2,  day = 5,  days = 15 },
    { key = "NOBLEGARDEN",     name = "Noblegarden",            month = 4,  day = 1,  days = 8 },
    { key = "CHILDRENS_WEEK",  name = "Children's Week",        month = 5,  day = 1,  days = 8 },
    { key = "MIDSUMMER",       name = "Midsummer Fire Festival",month = 6,  day = 21, days = 15 },
    { key = "PIRATES_DAY",     name = "Pirates' Day",           month = 9,  day = 19, days = 1 },
    { key = "BREWFEST",        name = "Brewfest",               month = 9,  day = 20, days = 17 },
    { key = "HALLOWS_END",     name = "Hallow's End",           month = 10, day = 18, days = 14 },
    { key = "DAY_OF_DEAD",     name = "Day of the Dead",        month = 11, day = 1,  days = 3 },
    { key = "PILGRIMS",        name = "Pilgrim's Bounty",       month = 11, day = 22, days = 8 },
    { key = "WINTER_VEIL",     name = "Feast of Winter Veil",   month = 12, day = 16, days = 18 },
}

-- ============================================================================
-- Curated lists
-- A curated list is a named set of achievement ids with a description. Kleos
-- seeds the two that need no external data (watch-list overflow and the
-- account-wide meta hunt) and the open API adds the rest.
-- ============================================================================
K.Data.CURATED_LISTS = {}

function K.Data:RegisterCuratedList(key, name, ids, description)
    key = tostring(key or "")
    if key == "" or type(ids) ~= "table" then return false end
    local clean = {}
    for _, id in ipairs(ids) do
        local numeric = tonumber(id)
        if numeric and numeric > 0 then clean[#clean + 1] = numeric end
    end
    self.CURATED_LISTS[key] = {
        key = key,
        name = tostring(name or key),
        description = tostring(description or ""),
        ids = clean,
    }
    return true
end

function K.Data:ListCuratedKeys()
    local keys = {}
    for key in pairs(self.CURATED_LISTS) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

function K.Data:GetCuratedList(key)
    return self.CURATED_LISTS[tostring(key or "")]
end

-- ----------------------------------------------------------------------------
-- Dynamic curated lists
-- Two lists worth having that need no authored data, recomputed when the
-- Specials tab draws: what you are closest to finishing, and what you finished
-- most recently. API-registered categories live alongside them.
-- ----------------------------------------------------------------------------
local NEARLY_DONE_THRESHOLD = 0.6
local NEARLY_DONE_LIMIT = 200
local RECENT_LIMIT = 100

function K.Data:RefreshDynamicLists()
    local Catalog = K.Catalog
    if not Catalog then return end
    Catalog:Build()

    local nearly, recent = {}, {}
    for _, id in ipairs(Catalog.order) do
        local entry = Catalog.entries[id]
        if entry and not entry.isStatistic then
            local state = Catalog:GetState(id)
            if state and state.completed then
                if state.year and state.year > 0 then
                    recent[#recent + 1] = {
                        id = id,
                        stamp = ((state.year or 0) * 10000) + ((state.month or 0) * 100) + (state.day or 0),
                    }
                end
            elseif #nearly < NEARLY_DONE_LIMIT then
                local progress = Catalog:GetProgress(id)
                if progress >= NEARLY_DONE_THRESHOLD and progress < 1 then
                    nearly[#nearly + 1] = { id = id, progress = progress }
                end
            end
        end
    end

    table.sort(nearly, function(a, b) return a.progress > b.progress end)
    table.sort(recent, function(a, b) return a.stamp > b.stamp end)

    local nearlyIDs = {}
    for _, row in ipairs(nearly) do nearlyIDs[#nearlyIDs + 1] = row.id end
    local recentIDs = {}
    for index, row in ipairs(recent) do
        if index > RECENT_LIMIT then break end
        recentIDs[#recentIDs + 1] = row.id
    end

    if #nearlyIDs > 0 then
        self:RegisterCuratedList("NEARLY_DONE", K.L.NEARLY_DONE or "Nearly done", nearlyIDs,
            "Incomplete achievements at 60% or better.")
    else
        self.CURATED_LISTS.NEARLY_DONE = nil
    end
    if #recentIDs > 0 then
        self:RegisterCuratedList("RECENT", K.L.RECENT or "Recently earned", recentIDs,
            "Most recently earned achievements, newest first.")
    else
        self.CURATED_LISTS.RECENT = nil
    end

    return self:RebuildCuratedFlatList()
end

-- CURATED stays as the flat "everything curated" id list so older callers
-- (BuildList in UI.lua, the /kleos curated tab) keep working.
function K.Data:RebuildCuratedFlatList()
    local seen, flat = {}, {}
    for _, key in ipairs(self:ListCuratedKeys()) do
        for _, id in ipairs(self.CURATED_LISTS[key].ids) do
            if not seen[id] then
                seen[id] = true
                flat[#flat + 1] = id
            end
        end
    end
    self.CURATED = flat
    return flat
end
