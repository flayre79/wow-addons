local K = Kleos

-- ============================================================================
-- Catalog
-- One index over every achievement Blizzard exposes, built by walking
-- GetCategoryList() once per session.
--
-- Blizzard gives no API for "which expansion is this achievement from", "is it
-- a raid achievement", or "is this one of the hidden tracking achievements".
-- All three are derived here from the category chain so every other Kleos
-- module reads the same answer:
--
--   expansion  category chain names -> Data:ResolveExpansionName, root id hint
--   kind       category chain names -> Data:ResolveKindFromName, root id map
--   hidden     present with includeAll=true but not with includeAll=false
--
-- The index is a session cache. Achievement metadata does not change inside a
-- session except for completion state, which is read live on every query.
-- ============================================================================

K.Catalog = K.Catalog or {}
local Cat = K.Catalog

Cat.entries = Cat.entries or {}         -- id -> entry
Cat.order = Cat.order or {}             -- build order (stable, index-friendly)
Cat.categories = Cat.categories or {}   -- catID -> { id, name, parent, kind, expansion, children }
Cat.roots = Cat.roots or {}             -- ordered root category ids
Cat._built = false
Cat._stats = { total = 0, hidden = 0, statistics = 0, categories = 0 }

local MAX_CHAIN_DEPTH = 12

-- ----------------------------------------------------------------------------
-- Category chain
-- ----------------------------------------------------------------------------
local function CategoryInfo(catID)
    if type(GetCategoryInfo) ~= "function" then return nil, nil, nil end
    local name, parentID, flags = GetCategoryInfo(catID)
    return name, parentID, flags
end

function Cat:BuildCategoryMap()
    self.categories = {}
    self.roots = {}

    local list = (type(GetCategoryList) == "function") and GetCategoryList() or nil
    if type(list) ~= "table" then return self.categories end

    for _, catID in ipairs(list) do
        local name, parentID = CategoryInfo(catID)
        self.categories[catID] = {
            id = catID,
            name = name or ("Category " .. tostring(catID)),
            parent = (parentID and parentID ~= -1) and parentID or nil,
            children = {},
        }
    end

    for _, catID in ipairs(list) do
        local node = self.categories[catID]
        local parent = node.parent and self.categories[node.parent]
        if parent then
            parent.children[#parent.children + 1] = catID
        else
            self.roots[#self.roots + 1] = catID
        end
    end

    -- Resolve expansion + kind per category once, walking up the chain.
    for _, catID in ipairs(list) do
        local node = self.categories[catID]
        node.expansion, node.kind, node.chain = self:ClassifyCategory(catID)
    end

    self._stats.categories = #list
    return self.categories
end

-- Returns the chain of category ids from the given category up to its root.
function Cat:GetCategoryChain(catID)
    local chain = {}
    local current = catID
    for _ = 1, MAX_CHAIN_DEPTH do
        if current == nil then break end
        local node = self.categories[current]
        chain[#chain + 1] = current
        if not node or not node.parent then break end
        current = node.parent
    end
    return chain
end

-- expansion key, kind key, chain. Name matching wins over the root id hint:
-- Blizzard renumbers root categories between expansions but the names are
-- stable (and localised names still resolve through the alias table for the
-- English tokens most of them contain).
function Cat:ClassifyCategory(catID)
    local chain = self:GetCategoryChain(catID)
    local expansion, kind

    -- A top-level category is classified by its stable id, not by its name.
    -- Blizzard's root is called "Dungeons & Raids", which matches both the raid
    -- and the dungeon keyword; the id says which one the root means, and the
    -- name walk below still resolves the "Raids" child correctly.
    if K.Data.ROOT_CATEGORY_KIND[catID] then
        kind = K.Data.ROOT_CATEGORY_KIND[catID]
    end

    for _, id in ipairs(chain) do
        local node = self.categories[id]
        local name = node and node.name or nil
        if not expansion then
            local full = K.Data:ResolveExpansionName(name)
            if full then expansion = K.Data.EXPANSION_FULLNAME_TO_KEY[full] end
        end
        if not kind then
            kind = K.Data:ResolveKindFromName(name)
        end
    end

    local root = chain[#chain]
    if not expansion and root then
        local hinted = K.Data.EXPANSION_ROOT_HINTS[root]
        if hinted then expansion = K.Data.EXPANSION_FULLNAME_TO_KEY[hinted] end
    end
    if not kind and root then
        kind = K.Data.ROOT_CATEGORY_KIND[root]
    end

    return expansion, kind or "OTHER", chain
end

-- ----------------------------------------------------------------------------
-- Index build
-- ----------------------------------------------------------------------------
local function ReadAchievement(catID, index)
    local id, name, points, completed, month, day, year, description,
          flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic
        = GetAchievementInfo(catID, index)
    if not id then return nil end
    return {
        id = id,
        name = name,
        points = tonumber(points) or 0,
        description = description,
        rewardText = rewardText,
        icon = icon,
        flags = tonumber(flags) or 0,
        isGuild = isGuild and true or false,
        isStatistic = isStatistic and true or false,
        category = catID,
        earnedMonth = tonumber(month),
        earnedDay = tonumber(day),
        earnedYear = tonumber(year),
        _completedAtBuild = completed and true or false,
        _mineAtBuild = wasEarnedByMe and true or false,
        earnedBy = earnedBy,
    }
end

function Cat:Build(force)
    if self._built and not force then return self end
    if type(GetCategoryList) ~= "function" or type(GetAchievementInfo) ~= "function" then
        self._built = true
        return self
    end

    self:BuildCategoryMap()

    self.entries = {}
    self.order = {}
    local stats = { total = 0, hidden = 0, statistics = 0, categories = self._stats.categories }

    for catID in pairs(self.categories) do
        local visible = tonumber(GetCategoryNumAchievements and GetCategoryNumAchievements(catID, false)) or 0
        local total = tonumber(GetCategoryNumAchievements and GetCategoryNumAchievements(catID, true)) or 0
        if total < visible then total = visible end

        -- Two passes: the visible id set first, so "hidden" does not depend on
        -- the hidden entries happening to sort last inside the category.
        local visibleIDs = {}
        for index = 1, visible do
            local entry = ReadAchievement(catID, index)
            if entry then visibleIDs[entry.id] = true end
        end

        for index = 1, total do
            local entry = ReadAchievement(catID, index)
            if entry and not self.entries[entry.id] then
                local node = self.categories[catID]
                entry.expansion = node and node.expansion or nil
                entry.kind = node and node.kind or "OTHER"
                entry.categoryName = node and node.name or nil
                entry.hidden = not visibleIDs[entry.id]
                self.entries[entry.id] = entry
                self.order[#self.order + 1] = entry.id
                stats.total = stats.total + 1
                if entry.hidden then stats.hidden = stats.hidden + 1 end
                if entry.isStatistic then stats.statistics = stats.statistics + 1 end
            end
        end
    end

    self._stats = stats
    self._built = true
    self._progressCache = {}
    return self
end

function Cat:IsReady() return self._built end
function Cat:Stats() return self._stats end
function Cat:Count() return self._stats.total end

-- Entries for ids Blizzard never handed us (curated lists referencing an id
-- from another locale/build, API-registered ids) are synthesised on demand so
-- the UI can still show something instead of dropping the row.
function Cat:GetEntry(id)
    id = tonumber(id)
    if not id then return nil end
    if not self._built then self:Build() end
    local entry = self.entries[id]
    if entry then return entry end

    local aid, name, points, _, month, day, year, description, flags, icon,
          rewardText, isGuild, _, earnedBy, isStatistic = GetAchievementInfo(id)
    if not aid then return nil end
    entry = {
        id = aid,
        name = name,
        points = tonumber(points) or 0,
        description = description,
        rewardText = rewardText,
        icon = icon,
        flags = tonumber(flags) or 0,
        isGuild = isGuild and true or false,
        isStatistic = isStatistic and true or false,
        earnedMonth = tonumber(month),
        earnedDay = tonumber(day),
        earnedYear = tonumber(year),
        earnedBy = earnedBy,
        hidden = false,
        synthetic = true,
    }
    local catID = (type(GetAchievementCategory) == "function") and GetAchievementCategory(aid) or nil
    if catID and catID ~= -1 then
        local node = self.categories[catID]
        entry.category = catID
        entry.categoryName = node and node.name or nil
        entry.expansion = node and node.expansion or nil
        entry.kind = node and node.kind or "OTHER"
    else
        entry.kind = "OTHER"
    end
    self.entries[aid] = entry
    return entry
end

-- ----------------------------------------------------------------------------
-- Live state (never cached: completion changes mid-session)
-- ----------------------------------------------------------------------------
function Cat:GetState(id)
    id = tonumber(id)
    if not id then return nil end
    local _, _, _, completed, month, day, year, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(id)
    return {
        completed = completed and true or false,
        wasEarnedByMe = wasEarnedByMe and true or false,
        month = tonumber(month), day = tonumber(day), year = tonumber(year),
    }
end

-- Fraction of criteria met, 0..1. Achievements with no criteria report their
-- completion flag so PROGRESS sorting still orders them sensibly.
function Cat:GetProgress(id)
    id = tonumber(id)
    if not id then return 0, 0, 0 end
    self._progressCache = self._progressCache or {}

    local state = self:GetState(id)
    if state and state.completed then return 1, 1, 1 end

    local numCriteria = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(id)) or 0
    if numCriteria == 0 then return 0, 0, 0 end

    local met, quantity, required = 0, 0, 0
    for index = 1, numCriteria do
        local _, _, done, qty, reqQty = GetAchievementCriteriaInfo(id, index)
        if done then met = met + 1 end
        quantity = quantity + (tonumber(qty) or 0)
        required = required + (tonumber(reqQty) or 0)
    end

    -- A single quantity criterion (e.g. "kill 1000 boars") is more meaningful
    -- as qty/reqQty than as 0-or-1 criteria met.
    if numCriteria == 1 and required > 0 then
        return math.min(1, quantity / required), quantity, required
    end
    return met / numCriteria, met, numCriteria
end

-- ----------------------------------------------------------------------------
-- Saturation: which "earned" answer the player asked to see
--   ACCOUNT    account-wide completion (Blizzard's `completed`)
--   CHARACTER  earned by this character (`wasEarnedByMe`)
--   MIXED      account completion, but the UI dims rows this character missed
-- ----------------------------------------------------------------------------
function Cat:IsEarned(id, saturation)
    local state = self:GetState(id)
    if not state then return false end
    if saturation == "CHARACTER" then
        return state.wasEarnedByMe or K:IsEarnedByChar(id)
    end
    return state.completed
end

-- ----------------------------------------------------------------------------
-- Obtainability
-- Blizzard exposes no "still obtainable" flag. Two sources are combined: the
-- Kleos override table (shard data / API registrations) and a category-name
-- heuristic for the categories Blizzard itself parks retired content in.
-- Anything else is reported obtainable, which is the safe default for a filter.
-- ----------------------------------------------------------------------------
Cat.unobtainableOverrides = Cat.unobtainableOverrides or {}

local UNOBTAINABLE_NAME_TOKENS = { "legacy", "removed", "no longer" }

function Cat:IsUnobtainable(id)
    id = tonumber(id)
    if not id then return false end
    if self.unobtainableOverrides[id] ~= nil then return self.unobtainableOverrides[id] and true or false end

    local entry = self:GetEntry(id)
    if not entry then return false end
    local name = entry.categoryName
    if type(name) == "string" then
        local lower = name:lower()
        for _, token in ipairs(UNOBTAINABLE_NAME_TOKENS) do
            if lower:find(token, 1, true) then return true end
        end
    end
    return false
end

function Cat:SetUnobtainable(id, value)
    id = tonumber(id)
    if not id then return false end
    self.unobtainableOverrides[id] = value and true or false
    return true
end

-- ----------------------------------------------------------------------------
-- Faction relevance
-- Also unexposed. Derived from the category chain plus the achievement name,
-- which is how Blizzard names the split pairs ("Alliance Slayer" / "Horde
-- Slayer"). Neutral is the default so no row is hidden by accident.
-- ----------------------------------------------------------------------------
local FACTION_TOKENS = {
    { "alliance", "ALLIANCE" },
    { "horde",    "HORDE" },
}

function Cat:GetFaction(id)
    local entry = self:GetEntry(id)
    if not entry then return "NEUTRAL" end
    if entry._faction then return entry._faction end
    local haystack = ((entry.name or "") .. " " .. (entry.categoryName or "")):lower()
    local faction = "NEUTRAL"
    for _, pair in ipairs(FACTION_TOKENS) do
        if haystack:find(pair[1], 1, true) then faction = pair[2]; break end
    end
    entry._faction = faction
    return faction
end

-- ----------------------------------------------------------------------------
-- Query
-- filters:
--   search       substring over name + description + criteria (lowercased)
--   expansion    "ALL" or an expansion short key
--   kind         "ALL" or a Data.KIND_ORDER key
--   category     "ALL" or a category id (includes descendants)
--   completion   "ALL" | "COMPLETE" | "INCOMPLETE"
--   reward       "ALL" | "ANY" | "NONE" | a Rewards type key
--   faction      "ALL" | "ALLIANCE" | "HORDE" | "NEUTRAL"
--   obtainable   "ALL" | "OBTAINABLE" | "UNOBTAINABLE"
--   saturation   "ACCOUNT" | "CHARACTER" | "MIXED"
--   showStatistics / showTracking / showExcluded  booleans
--   sort         "NAME" | "POINTS" | "PROGRESS" | "DATE" | "ID" | "CATEGORY"
--   source       optional array of ids to filter instead of the whole index
-- ----------------------------------------------------------------------------
local function MatchesSearch(entry, needle)
    if not needle or needle == "" then return true end
    local name = entry.name and entry.name:lower() or ""
    if name:find(needle, 1, true) then return true end
    local description = entry.description and entry.description:lower() or ""
    if description:find(needle, 1, true) then return true end
    local rewardText = entry.rewardText and entry.rewardText:lower() or ""
    if rewardText:find(needle, 1, true) then return true end

    -- Criteria text last: it is the expensive lookup.
    local numCriteria = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(entry.id)) or 0
    for index = 1, numCriteria do
        local criteriaString = GetAchievementCriteriaInfo(entry.id, index)
        if type(criteriaString) == "string" and criteriaString:lower():find(needle, 1, true) then
            return true
        end
    end
    return false
end

function Cat:CategoryMatches(entry, categoryFilter)
    if categoryFilter == nil or categoryFilter == "ALL" then return true end
    local wanted = tonumber(categoryFilter)
    if not wanted then return true end
    if entry.category == wanted then return true end
    local chain = self:GetCategoryChain(entry.category)
    for _, id in ipairs(chain) do
        if id == wanted then return true end
    end
    return false
end

local SORTERS = {}

function Cat:Query(filters)
    filters = filters or {}
    if not self._built then self:Build() end

    local needle = filters.search
    needle = (type(needle) == "string" and needle ~= "") and needle:lower() or nil

    local ids = filters.source
    if type(ids) ~= "table" then ids = self.order end

    local saturation = filters.saturation or "MIXED"
    local results = {}

    for _, id in ipairs(ids) do
        -- An id the client does not know (a curated list from another build, an
        -- API registration) yields no entry and is dropped rather than drawn as
        -- a blank row.
        local entry = self:GetEntry(id)
        if entry then
            local include = true
            if entry.isStatistic and not filters.showStatistics then include = false end
            if include and entry.hidden and not filters.showTracking then include = false end
            if include and not filters.showExcluded and K.IsExcluded and K:IsExcluded(id) then include = false end
            if include and filters.expansion and filters.expansion ~= "ALL" then
                include = entry.expansion == filters.expansion
            end
            if include and filters.kind and filters.kind ~= "ALL" then
                include = entry.kind == filters.kind
            end
            if include and filters.category and filters.category ~= "ALL" then
                include = self:CategoryMatches(entry, filters.category)
            end
            if include and filters.completion and filters.completion ~= "ALL" then
                local earned = self:IsEarned(id, saturation)
                include = (filters.completion == "COMPLETE") == earned
            end
            if include and filters.faction and filters.faction ~= "ALL" then
                include = self:GetFaction(id) == filters.faction
            end
            if include and filters.obtainable and filters.obtainable ~= "ALL" then
                local unobtainable = self:IsUnobtainable(id)
                include = (filters.obtainable == "UNOBTAINABLE") == unobtainable
            end
            if include and filters.reward and filters.reward ~= "ALL" and K.Rewards then
                include = K.Rewards:Matches(id, filters.reward)
            end
            if include and needle then
                include = MatchesSearch(entry, needle)
            end
            if include then results[#results + 1] = id end
        end
    end

    local sorter = SORTERS[filters.sort or "NAME"] or SORTERS.NAME
    table.sort(results, sorter(self))
    return results
end

local function NameOf(cat, id)
    local entry = cat:GetEntry(id)
    local name = entry and entry.name
    if type(name) == "string" and name ~= "" then return name:lower() end
    return "zzz" .. tostring(id)
end

SORTERS.NAME = function(cat)
    return function(a, b) return NameOf(cat, a) < NameOf(cat, b) end
end

SORTERS.ID = function()
    return function(a, b) return a < b end
end

SORTERS.POINTS = function(cat)
    return function(a, b)
        local pa = (cat:GetEntry(a) or {}).points or 0
        local pb = (cat:GetEntry(b) or {}).points or 0
        if pa ~= pb then return pa > pb end
        return NameOf(cat, a) < NameOf(cat, b)
    end
end

SORTERS.PROGRESS = function(cat)
    return function(a, b)
        local pa = cat:GetProgress(a)
        local pb = cat:GetProgress(b)
        if pa ~= pb then return pa > pb end
        return NameOf(cat, a) < NameOf(cat, b)
    end
end

SORTERS.DATE = function(cat)
    return function(a, b)
        local sa = cat:GetState(a) or {}
        local sb = cat:GetState(b) or {}
        local ka = ((sa.year or 0) * 10000) + ((sa.month or 0) * 100) + (sa.day or 0)
        local kb = ((sb.year or 0) * 10000) + ((sb.month or 0) * 100) + (sb.day or 0)
        if ka ~= kb then return ka > kb end
        return NameOf(cat, a) < NameOf(cat, b)
    end
end

SORTERS.CATEGORY = function(cat)
    return function(a, b)
        local ca = (cat:GetEntry(a) or {}).categoryName or ""
        local cb = (cat:GetEntry(b) or {}).categoryName or ""
        if ca ~= cb then return ca < cb end
        return NameOf(cat, a) < NameOf(cat, b)
    end
end

Cat.SORT_KEYS = { "NAME", "POINTS", "PROGRESS", "DATE", "CATEGORY", "ID" }

-- ----------------------------------------------------------------------------
-- Category tree for the browse sidebar. Roots keep Blizzard's order; children
-- are sorted by name so the tree does not reshuffle between sessions.
-- ----------------------------------------------------------------------------
function Cat:GetCategoryTree()
    if not self._built then self:Build() end
    local tree = {}
    for _, rootID in ipairs(self.roots) do
        local node = self.categories[rootID]
        if node then
            local children = {}
            for _, childID in ipairs(node.children) do
                local child = self.categories[childID]
                if child then children[#children + 1] = { id = childID, name = child.name, kind = child.kind, expansion = child.expansion } end
            end
            table.sort(children, function(a, b) return (a.name or "") < (b.name or "") end)
            tree[#tree + 1] = { id = rootID, name = node.name, kind = node.kind, expansion = node.expansion, children = children }
        end
    end
    return tree
end

-- Which expansions the live client actually exposes, newest first. Used to
-- build the expansion dropdown so a filter can never offer an expansion whose
-- categories are absent (the pre-1.2 UI offered eleven hardcoded ones and
-- silently omitted Midnight).
function Cat:AvailableExpansions()
    if not self._built then self:Build() end
    local present = {}
    for _, node in pairs(self.categories) do
        if node.expansion then present[node.expansion] = true end
    end
    local ordered = {}
    for _, key in ipairs(K.Data.EXPANSION_ORDER) do
        if present[key] then ordered[#ordered + 1] = key end
    end
    return ordered
end

-- ----------------------------------------------------------------------------
-- Asset index: creature id / item id -> achievements that need them.
-- This is what lets a unit or item tooltip say "needed for X". Building it
-- touches every criterion of every achievement, so it is built in chunks off
-- the first request and never on login.
-- ----------------------------------------------------------------------------
local ASSET_CHUNK = 250
local CRITERIA_KILL_CREATURE = 0
local CRITERIA_ITEM_TYPES = { [36] = true, [41] = true, [69] = true }

Cat.assetIndex = nil

function Cat:AssetIndexReady()
    return self.assetIndex ~= nil and self.assetIndex._complete == true
end

local function IndexAchievementAssets(index, achievementID)
    local count = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(achievementID)) or 0
    for criteriaIndex = 1, count do
        local _, rawCriteriaType, _, _, _, _, _, assetID = GetAchievementCriteriaInfo(achievementID, criteriaIndex)
        local criteriaType = tonumber(rawCriteriaType)
        local asset = tonumber(assetID)
        if asset and asset > 0 then
            local bucket
            if criteriaType == CRITERIA_KILL_CREATURE then
                bucket = index.creature
            elseif criteriaType and CRITERIA_ITEM_TYPES[criteriaType] then
                bucket = index.item
            end
            if bucket then
                bucket[asset] = bucket[asset] or {}
                local list = bucket[asset]
                local duplicate = false
                for _, existing in ipairs(list) do
                    if existing == achievementID then duplicate = true; break end
                end
                if not duplicate then list[#list + 1] = achievementID end
            end
        end
    end
end

-- The asset index is the one derived structure expensive enough to be worth
-- persisting, so it lives in the DataVault shard keyed by client build. A patch
-- that adds achievements changes the stamp and the cache is rebuilt.
local ASSET_CACHE_NAME = "assetIndex"

function Cat:LoadAssetIndexFromShard()
    local shard = rawget(_G, "KleosShard")
    if not (shard and shard.IsAvailable and shard:IsAvailable()) then return nil end
    local ok, data = pcall(shard.Get, shard, ASSET_CACHE_NAME, shard:BuildStamp())
    if not ok or type(data) ~= "table" then return nil end
    if type(data.creature) ~= "table" or type(data.item) ~= "table" then return nil end
    data._complete = true
    data._fromShard = true
    self.assetIndex = data
    return data
end

function Cat:SaveAssetIndexToShard()
    local shard = rawget(_G, "KleosShard")
    if not (shard and shard.IsAvailable and shard:IsAvailable()) then return false end
    if not self:AssetIndexReady() then return false end
    local ok = pcall(shard.Set, shard, ASSET_CACHE_NAME,
        { creature = self.assetIndex.creature, item = self.assetIndex.item }, shard:BuildStamp())
    return ok and true or false
end

function Cat:BuildAssetIndexNow()
    self:Build()
    if self:LoadAssetIndexFromShard() then return self.assetIndex end
    local index = { creature = {}, item = {} }
    for _, id in ipairs(self.order) do IndexAchievementAssets(index, id) end
    index._complete = true
    self.assetIndex = index
    self:SaveAssetIndexToShard()
    return index
end

function Cat:BuildAssetIndexAsync(onDone)
    if self:AssetIndexReady() then
        if onDone then onDone(self.assetIndex) end
        return
    end
    if self._assetBuilding then return end

    self:Build()
    if self:LoadAssetIndexFromShard() then
        if onDone then onDone(self.assetIndex) end
        return
    end
    self._assetBuilding = true
    local index = { creature = {}, item = {} }
    local position = 1

    local function Step()
        local stop = math.min(position + ASSET_CHUNK - 1, #self.order)
        for cursor = position, stop do
            IndexAchievementAssets(index, self.order[cursor])
        end
        position = stop + 1
        local finished = position > #self.order
        -- No C_Timer means no way to yield; finish the walk in this frame rather
        -- than leaving a half-built index that reports itself complete.
        if not finished and not (C_Timer and C_Timer.After) then
            for cursor = position, #self.order do IndexAchievementAssets(index, self.order[cursor]) end
            position = #self.order + 1
            finished = true
        end

        if finished then
            index._complete = true
            self.assetIndex = index
            self._assetBuilding = false
            self:SaveAssetIndexToShard()
            if onDone then onDone(index) end
        else
            C_Timer.After(0, Step)
        end
    end

    Step()
end

-- Returns the achievements that need this creature / item, and whether the
-- index was ready. A not-ready answer kicks the build off so the next hover
-- has data.
function Cat:AchievementsForAsset(kind, assetID)
    assetID = tonumber(assetID)
    if not assetID then return {}, false end
    if not self:AssetIndexReady() then
        self:BuildAssetIndexAsync()
        return {}, false
    end
    local bucket = self.assetIndex[kind]
    local list = bucket and bucket[assetID] or nil
    if not list then return {}, true end
    local copy = {}
    for position, id in ipairs(list) do copy[position] = id end
    return copy, true
end

function Cat:PointsSummary()
    if not self._built then self:Build() end
    local earnedPoints, totalPoints, earned, total = 0, 0, 0, 0
    for _, id in ipairs(self.order) do
        local entry = self.entries[id]
        if entry and not entry.isStatistic and not entry.isGuild then
            total = total + 1
            totalPoints = totalPoints + (entry.points or 0)
            local state = self:GetState(id)
            if state and state.completed then
                earned = earned + 1
                earnedPoints = earnedPoints + (entry.points or 0)
            end
        end
    end
    return {
        earnedPoints = earnedPoints,
        totalPoints = totalPoints,
        earned = earned,
        total = total,
        blizzardPoints = (type(GetTotalAchievementPoints) == "function") and (GetTotalAchievementPoints() or 0) or 0,
    }
end
