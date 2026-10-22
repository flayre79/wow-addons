-- FabledUI_Prey_Tooltip -- which Prey achievements a hunt would advance.
-- Index.lua answers "which achievements does finishing this hunt move, and
-- how far along are they"; Tooltip.lua puts the answer on the hunt map.
--
-- THE ACHIEVEMENTS (warcraft.wiki.gg, "Achievements: Expansion Features
-- Prey", 62 of them, checked 2026-10-11). Two kinds advance on finishing a
-- hunt:
--
--   * TARGET achievements, whose criteria are the 30 target names: Prey:
--     Normal / Hard / Nightmare Mode I-III ("one of", "15 of", "all of the
--     following ... on Hard difficulty"), Gotta Hunt Them All ("all ... on any
--     difficulty"), and 15 pairs in a Hard and a Nightmare version, the bust
--     and effigy ones ("Defeat Praetor Singularis or Consul Nebulor on Hard
--     mode", e.g. 62161 / 62179). These are found at runtime, not listed: the
--     achievement category titled "Prey", its subcategories, and every step
--     of each series. A new season's achievements arrive without a code change.
--   * HUNT achievements, which count any hunt that meets a condition and have
--     no target criteria: listed below by id, because nothing in them names a
--     target.
--
-- Everything else in the category (ambushes, traps, fishing, cooking, the
-- Coiled Isle bosses, the meta) is earned DURING a hunt, not by finishing one,
-- and is left off.
--
-- MATCHING, per achievement, so one achievement's misspelling cannot hide the
-- others (the wiki shows "The Talon of Janali" in the Mode series and "The
-- Talon of Jan'alai" in Gotta Hunt Them All). For each achievement the first
-- of these that finds a criterion wins: the pin's title compared case-, space-
-- and punctuation-blind; a type-27 ("complete a quest") criterion whose asset
-- is the pin's quest id; a criterion containing the title or the reverse; a
-- criterion within two edits of the title. The answer is memoised per title.
--
-- DIFFICULTY of an achievement: a difficulty word in its name ("Hard Mode",
-- "(Nightmare)"), else the word after " on " in its description ("on Hard
-- mode", "on any difficulty"). Only achievements for the hunt's own difficulty
-- or any difficulty are shown; finishing a Hard hunt is not assumed to tick a
-- Normal criterion (the wiki says each tier's III needs all 30 independently).
--
-- WHAT IS LIVE. Which criterion names which target is built once per session,
-- on first use. Earned, criterion done and progress are read on every hover.

local addonName = ...

local PreyTip = {}
_G.FabledUI_Prey_Tooltip = PreyTip

PreyTip.VERSION = "0.2.0"
PreyTip.ADDON_NAME = addonName or "FabledUI_Prey_Tooltip"
PreyTip.CATEGORY_TITLE = "prey"
PreyTip.CRITERIA_TYPE_QUEST = 27
PreyTip.FUZZY_MIN_LENGTH = 5
PreyTip.EDIT_MIN_LENGTH = 10
PreyTip.EDIT_MAX = 2

-- Difficulty words as the achievements spell them. The hunt map's own word
-- ("Difficulty: Hard") is always tried first, so a locale this list does not
-- cover still matches its own difficulty.
PreyTip.DIFFICULTIES = { "Nightmare", "Hard", "Normal" }

-- Hunt achievements: any hunt that meets the condition counts. Ids from the
-- wiki's Wowhead links, 2026-10-11. Names and progress are read live.
PreyTip.HUNT_ACHIEVEMENTS = {
    { id = 62134, warMode = true },                               -- The Deadliest of Prey: 5 hunts in War Mode
    { id = 62135, warMode = true, difficulty = "Nightmare" },     -- Now It's A Party: a Nightmare hunt in War Mode
    { id = 62403, difficulty = "Nightmare",
      condition = "needs Lord Viscera's Cat Scratch" },           -- 'Tis But A Scratch
    { id = 62139, zones = true },                                 -- Midnight Hunter: a hunt in every Midnight zone
}

local HUNT_IDS = {}
for _, rule in ipairs(PreyTip.HUNT_ACHIEVEMENTS) do HUNT_IDS[rule.id] = rule end
PreyTip._HuntIDs = HUNT_IDS

local issecretvalue = _G.issecretvalue or function() return false end

-- Secret check first, then type, then anything else (CLAUDE.md, secret values).
local function usableString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end
PreyTip._UsableString = usableString

local function usableNumber(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

function PreyTip:DB()
    local db = rawget(_G, "FabledUI_PreyTooltipDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_PreyTooltipDB = db
    end
    if db.enabled == nil then db.enabled = true end
    return db
end

-- -----------------------------------------------------------------------------
-- API seam. The simulator shadows its own globals, so a test cannot stub the
-- achievement functions, but it can replace these.
-- -----------------------------------------------------------------------------

local function callGlobal(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function callIn(namespace, name, ...)
    local ns = rawget(_G, namespace)
    if type(ns) ~= "table" or type(ns[name]) ~= "function" then return false end
    return pcall(ns[name], ...)
end

PreyTip.Api = {
    CategoryList = function()
        local ok, list = callGlobal("GetCategoryList")
        if ok and type(list) == "table" then return list end
        return {}
    end,

    -- title, parentID
    CategoryInfo = function(categoryID)
        local ok, title, parentID = callGlobal("GetCategoryInfo", categoryID)
        if not ok then return nil, nil end
        return usableString(title), usableNumber(parentID)
    end,

    CategoryCount = function(categoryID)
        local ok, total = callGlobal("GetCategoryNumAchievements", categoryID, true)
        return ok and usableNumber(total) or 0
    end,

    AchievementAt = function(categoryID, index)
        local ok, id = callGlobal("GetAchievementInfo", categoryID, index)
        return ok and usableNumber(id) or nil
    end,

    -- name, earned, description
    AchievementInfo = function(achievementID)
        local ok, _, name, _, completed, _, _, _, description = callGlobal("GetAchievementInfo", achievementID)
        if not ok then return nil end
        return usableString(name), completed == true, usableString(description)
    end,

    NumCriteria = function(achievementID)
        local ok, count = callGlobal("GetAchievementNumCriteria", achievementID)
        return ok and usableNumber(count) or 0
    end,

    -- criteriaString, criteriaType, completed, assetID, quantity, reqQuantity
    CriteriaInfo = function(achievementID, index)
        local ok, text, criteriaType, completed, quantity, reqQuantity, _, _, assetID =
            callGlobal("GetAchievementCriteriaInfo", achievementID, index)
        if not ok then return nil end
        return usableString(text), usableNumber(criteriaType), completed == true, usableNumber(assetID),
            usableNumber(quantity), usableNumber(reqQuantity)
    end,

    Previous = function(achievementID)
        local ok, id = callGlobal("GetPreviousAchievement", achievementID)
        return ok and usableNumber(id) or nil
    end,

    Next = function(achievementID)
        local ok, id = callGlobal("GetNextAchievement", achievementID)
        return ok and usableNumber(id) or nil
    end,

    -- The War Mode toggle, as set; true in a sanctuary too.
    WarMode = function()
        local ok, value = callIn("C_PvP", "IsWarModeDesired")
        return ok and value == true
    end,

    -- The zone a quest sits in, or nil. Blizzard's prey widget asks
    -- GetQuestUiMapID(questID, true) the same way. Whether it answers for a
    -- hunt not yet accepted is unproven.
    QuestZone = function(questID)
        questID = usableNumber(questID)
        if not questID then return nil end
        local ok, mapID = callGlobal("GetQuestUiMapID", questID, true)
        mapID = ok and usableNumber(mapID) or nil
        local guard = 0
        while mapID and mapID > 0 and guard < 6 do
            local okInfo, info = callIn("C_Map", "GetMapInfo", mapID)
            if not okInfo or type(info) ~= "table" then return nil end
            local mapType = usableNumber(info.mapType)
            if mapType and mapType <= 3 then -- Enum.UIMapType.Zone
                return mapType == 3 and usableString(info.name) or nil
            end
            mapID = usableNumber(info.parentMapID)
            guard = guard + 1
        end
        return nil
    end,

    IsPreyMap = function()
        local ok, kit = callIn("C_AdventureMap", "GetAdventureMapTextureKit")
        return ok and kit == "midnight"
    end,
}

-- -----------------------------------------------------------------------------
-- Text helpers
-- -----------------------------------------------------------------------------

-- Case-, space- and punctuation-blind key. ASCII punctuation only: in Lua 5.1
-- %p never matches a UTF-8 continuation byte, so accented names survive.
function PreyTip.Normalize(text)
    text = usableString(text)
    if not text then return nil end
    local key = (text:lower():gsub("[%s%p]", ""))
    if key == "" then return nil end
    return key
end

-- "Difficulty: Hard" -> "Hard". The word after the last colon, trimmed.
function PreyTip.OfferDifficulty(description)
    description = usableString(description)
    if not description then return nil end
    local word = description:match(":%s*([^:]-)%s*$") or description
    word = word:match("^%s*(.-)%s*$")
    if not word or word == "" then return nil end
    return word
end

local function knownDifficulty(word, offer)
    local lower = word:lower()
    if offer and lower == offer:lower() then return offer end
    for _, difficulty in ipairs(PreyTip.DIFFICULTIES) do
        if lower == difficulty:lower() then return difficulty end
    end
    return nil
end

-- The difficulty an achievement asks for, or nil for "any difficulty".
function PreyTip.AchievementDifficulty(name, description, offer)
    name = usableString(name)
    if name then
        for word in name:gmatch("%a+") do
            local difficulty = knownDifficulty(word, offer)
            if difficulty then return difficulty end
        end
    end
    description = usableString(description)
    if description then
        for word in (" " .. description):gmatch("%s[Oo]n%s+(%a+)") do
            if word:lower() == "any" then return nil end
            local difficulty = knownDifficulty(word, offer)
            if difficulty then return difficulty end
        end
    end
    return nil
end

-- How many of `total` criteria the description asks for: a number when it
-- gives one ("15 of the following"), one for "one of" or "X or Y", all of
-- them otherwise ("all of the following").
function PreyTip.RequiredCount(description, total)
    description = usableString(description)
    if not description or total <= 0 then return total end
    local n = tonumber(description:match("(%d+)"))
    if n and n > 0 and n <= total then return n end
    local padded = " " .. description:lower() .. " "
    if padded:find("[^%a]one[^%a]") or padded:find("%sor%s") then return 1 end
    return total
end

-- Edit distance, giving up (returns limit + 1) once it must exceed `limit`.
function PreyTip.EditDistance(a, b, limit)
    local la, lb = #a, #b
    if math.abs(la - lb) > limit then return limit + 1 end
    local previous = {}
    for j = 0, lb do previous[j] = j end
    for i = 1, la do
        local current = { [0] = i }
        local rowMin = i
        local ca = a:byte(i)
        for j = 1, lb do
            local cost = (ca == b:byte(j)) and 0 or 1
            local value = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            current[j] = value
            if value < rowMin then rowMin = value end
        end
        if rowMin > limit then return limit + 1 end
        previous = current
    end
    return previous[lb]
end

-- -----------------------------------------------------------------------------
-- Index
-- -----------------------------------------------------------------------------

function PreyTip:BuildIndex()
    local api = self.Api
    local index = {
        categories   = {},
        achievements = {},  -- every achievement found, in scan order
        criteria     = {},  -- [achievementID] = { { index, key, questID }, ... }
        previous     = {},  -- [achievementID] = previous step of its series
        names        = {},
        targetCount  = 0,
        memo         = {},
    }

    -- The Prey category, then anything parented to it.
    local list = api.CategoryList()
    local wanted = {}
    for _, id in ipairs(list) do
        local title = api.CategoryInfo(id)
        if title and title:lower() == self.CATEGORY_TITLE then wanted[id] = true end
    end
    for _, id in ipairs(list) do
        local _, parentID = api.CategoryInfo(id)
        if parentID and wanted[parentID] then wanted[id] = true end
    end

    -- Every achievement in them, and every step of each one's series.
    local seen = {}
    local function addAchievement(id)
        if not id or seen[id] then return end
        seen[id] = true
        index.achievements[#index.achievements + 1] = id
        index.previous[id] = api.Previous(id)
    end
    local function addSeries(id)
        local guard, cursor = 0, id
        while cursor and guard < 50 do
            addAchievement(cursor)
            cursor = api.Previous(cursor)
            guard = guard + 1
        end
        guard = 0
        cursor = id and api.Next(id)
        while cursor and not seen[cursor] and guard < 50 do
            addAchievement(cursor)
            cursor = api.Next(cursor)
            guard = guard + 1
        end
    end
    for _, id in ipairs(list) do
        if wanted[id] then
            index.categories[#index.categories + 1] = id
            for i = 1, api.CategoryCount(id) do
                addSeries(api.AchievementAt(id, i))
            end
        end
    end
    table.sort(index.categories)

    -- Every criterion of a target achievement is a target. Hunt achievements
    -- are handled by rule, not by name.
    local nameSeen = {}
    for _, achievementID in ipairs(index.achievements) do
        if not HUNT_IDS[achievementID] then
            local entries = {}
            for i = 1, api.NumCriteria(achievementID) do
                local text, criteriaType, _, assetID = api.CriteriaInfo(achievementID, i)
                local key = self.Normalize(text)
                local questID = nil
                if criteriaType == self.CRITERIA_TYPE_QUEST and assetID and assetID > 0 then questID = assetID end
                if key or questID then
                    entries[#entries + 1] = { index = i, key = key, questID = questID }
                end
                if key and not nameSeen[key] then
                    nameSeen[key] = true
                    index.names[#index.names + 1] = text
                    index.targetCount = index.targetCount + 1
                end
            end
            index.criteria[achievementID] = entries
        end
    end
    table.sort(index.names)
    return index
end

-- Built once per session. An empty result is not kept, so a client that had
-- not loaded achievement data yet gets another try on the next hover.
function PreyTip:Index()
    if self._index then return self._index end
    local index = self:BuildIndex()
    if #index.achievements > 0 then self._index = index end
    return index
end

function PreyTip:ResetIndex()
    self._index = nil
end

-- The criterion of one achievement that names this target, or nil.
local function matchIn(entries, key, questID)
    if key then
        for _, entry in ipairs(entries) do
            if entry.key == key then return entry.index end
        end
    end
    if questID then
        for _, entry in ipairs(entries) do
            if entry.questID == questID then return entry.index end
        end
    end
    if key and #key >= PreyTip.FUZZY_MIN_LENGTH then
        for _, entry in ipairs(entries) do
            local other = entry.key
            if other and #other >= PreyTip.FUZZY_MIN_LENGTH
                and (other:find(key, 1, true) or key:find(other, 1, true)) then
                return entry.index
            end
        end
    end
    if key and #key >= PreyTip.EDIT_MIN_LENGTH then
        local best, bestIndex = PreyTip.EDIT_MAX + 1, nil
        for _, entry in ipairs(entries) do
            local other = entry.key
            if other and #other >= PreyTip.EDIT_MIN_LENGTH then
                local distance = PreyTip.EditDistance(key, other, PreyTip.EDIT_MAX)
                if distance < best then best, bestIndex = distance, entry.index end
            end
        end
        return bestIndex
    end
    return nil
end

-- Every (achievement, criterion) naming this target, at most one per
-- achievement. Memoised per title and quest for the session.
function PreyTip:Lookup(title, questID)
    local index = self:Index()
    local key = self.Normalize(title)
    questID = usableNumber(questID)
    if not key and not questID then return {} end

    local memoKey = (key or "") .. "#" .. tostring(questID or "")
    local cached = index.memo[memoKey]
    if cached then return cached end

    local refs = {}
    for _, achievementID in ipairs(index.achievements) do
        local entries = index.criteria[achievementID]
        if entries then
            local criteriaIndex = matchIn(entries, key, questID)
            if criteriaIndex then
                refs[#refs + 1] = { achievementID = achievementID, criteriaIndex = criteriaIndex }
            end
        end
    end
    if self._index == index then index.memo[memoKey] = refs end
    return refs
end

-- Progress toward an achievement: (done, needed). A single criterion with a
-- count ("Complete 5 Prey Hunts") reports its own quantity; a list reports
-- how many are done against how many the description asks for. needed is 0
-- when the achievement exposes nothing to count.
function PreyTip:Progress(achievementID, description)
    local count = self.Api.NumCriteria(achievementID)
    if count == 1 then
        local _, _, completed, _, quantity, required = self.Api.CriteriaInfo(achievementID, 1)
        if required and required > 1 then
            return math.min(quantity or 0, required), required
        end
        return completed and 1 or 0, 1
    end
    local done = 0
    for i = 1, count do
        local _, _, completed = self.Api.CriteriaInfo(achievementID, i)
        if completed then done = done + 1 end
    end
    return done, self.RequiredCount(description, count)
end

local function difficultyAllows(tag, offer)
    return tag == nil or offer == nil or tag:lower() == offer:lower()
end

-- The criteria of a zone achievement still open, by name.
function PreyTip:OpenZones(achievementID)
    local open = {}
    for i = 1, self.Api.NumCriteria(achievementID) do
        local text, _, completed = self.Api.CriteriaInfo(achievementID, i)
        if text and not completed then open[#open + 1] = text end
    end
    return open
end

-- The hunt achievements this hunt would advance, given its difficulty and zone.
function PreyTip:HuntRows(offer, zone)
    local rows = {}
    for _, rule in ipairs(self.HUNT_ACHIEVEMENTS) do
        local name, earned, description = self.Api.AchievementInfo(rule.id)
        if name and not earned and difficultyAllows(rule.difficulty, offer) then
            local done, total = self:Progress(rule.id, description)
            local row = { achievementID = rule.id, name = name, done = done, total = total, counts = true }
            local skip = false
            if rule.zones then
                local open = self:OpenZones(rule.id)
                local zoneKey = self.Normalize(zone)
                if zoneKey then
                    local counts = false
                    for _, text in ipairs(open) do
                        if self.Normalize(text) == zoneKey then counts = true end
                    end
                    skip = not counts
                elseif #open > 0 then
                    row.counts = false
                    row.note = "counts in " .. table.concat(open, ", ")
                end
            end
            if rule.warMode and not self.Api.WarMode() then
                row.counts = false
                row.note = "War Mode is off"
            end
            if rule.condition then
                row.note = row.note and (row.note .. "; " .. rule.condition) or rule.condition
            end
            if not skip then rows[#rows + 1] = row end
        end
    end
    return rows
end

-- What the tooltip shows for one hunt. Returns rows, refCount:
--   rows     -- achievements finishing this hunt would advance: target
--               achievements first (only the lowest unearned step of each
--               series), then hunt achievements;
--   refCount -- how many achievements name the target at all.
-- Hunt achievements are only added for a Prey hunt: one whose target some
-- achievement names, or any pin while the Prey map is open.
function PreyTip:RowsFor(title, questID, offer, zone)
    local refs = self:Lookup(title, questID)
    local rows, inRows = {}, {}

    for _, ref in ipairs(refs) do
        local id = ref.achievementID
        local name, earned, description = self.Api.AchievementInfo(id)
        local _, _, criterionDone = self.Api.CriteriaInfo(id, ref.criteriaIndex)
        if name and not earned and not criterionDone then
            if difficultyAllows(self.AchievementDifficulty(name, description, offer), offer) then
                local done, total = self:Progress(id, description)
                rows[#rows + 1] = { achievementID = id, name = name, done = done, total = total, counts = true }
                inRows[id] = true
            end
        end
    end

    -- A later step whose earlier step is already listed adds nothing: the
    -- same finish advances both, and the earlier one completes first.
    local index = self:Index()
    local collapsed = {}
    for _, row in ipairs(rows) do
        local previous = index.previous[row.achievementID]
        if not (previous and inRows[previous]) then collapsed[#collapsed + 1] = row end
    end
    table.sort(collapsed, function(a, b) return a.name < b.name end)

    if #refs > 0 or self.Api.IsPreyMap() then
        for _, row in ipairs(self:HuntRows(offer, zone)) do
            collapsed[#collapsed + 1] = row
        end
    end
    return collapsed, #refs
end
