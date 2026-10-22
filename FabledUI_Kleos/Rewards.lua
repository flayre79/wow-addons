local K = Kleos

-- ============================================================================
-- Rewards
-- Typed reward classification for the reward filters the PRD asks for:
-- mounts, pets, titles, toys, transmog, tabards, teleports and housing decor.
--
-- Blizzard exposes achievement rewards two ways and neither is complete:
--   GetAchievementNumRewards / GetAchievementReward  item ids, when there is
--        an item at all (absent on some clients, hence the type guard)
--   GetAchievementInfo(...) rewardText               a localised sentence
--
-- Rather than shipping a copied third-party reward database, classification
-- runs through an ordered provider chain, each of which may contribute types
-- and ids. Providers are additive and any of them can be missing at runtime:
--
--   1. overrides      Kleos-owned data + Rewards:SetOverride / the open API
--   2. blizzardItems  reward item ids -> item class/subclass/equip slot
--   3. suiteDecor     Villa's imported achievement->decor index, when loaded
--   4. housingCatalog decor lookup by reward item id (C_HousingCatalog)
--   5. text           keyword match on rewardText (last resort, localised)
--
-- Everything is session-cached; nothing here is persisted, so a client patch
-- that changes a reward is picked up on the next login with no migration.
-- ============================================================================

K.Rewards = K.Rewards or {}
local R = K.Rewards

R.TYPES = { "MOUNT", "PET", "TITLE", "TOY", "TRANSMOG", "TABARD", "TELEPORT", "HOUSING", "OTHER" }

R.TYPE_ICONS = {
    MOUNT    = "Interface/Icons/Ability_Mount_RidingHorse",
    PET      = "Interface/Icons/INV_Box_PetCarrier_01",
    TITLE    = "Interface/Icons/Achievement_Reputation_01",
    TOY      = "Interface/Icons/INV_Misc_Toy_10",
    TRANSMOG = "Interface/Icons/INV_Misc_Desecrated_ClothShoulder",
    TABARD   = "Interface/Icons/INV_Shirt_Guild_01",
    TELEPORT = "Interface/Icons/Spell_Arcane_TeleportStormwind",
    HOUSING  = "Interface/Icons/INV_Misc_Coin_01",
    OTHER    = "Interface/Icons/INV_Misc_QuestionMark",
}

R.cache = R.cache or {}          -- id -> { types = { KEY = true }, items = {}, decor = {}, sources = {} }
R.overrides = R.overrides or {}   -- id -> { types = {...}, items = {...}, decor = {...} }
R.providers = R.providers or {}
R._index = nil                    -- type -> array of ids (built lazily)

-- ----------------------------------------------------------------------------
-- Keyword heuristics
-- rewardText is a localised sentence, so this is a best-effort last resort.
-- Tokens are lowercase substrings; the first match per type wins.
-- ----------------------------------------------------------------------------
R.TEXT_TOKENS = {
    MOUNT    = { "mount", "reittier", "monture", "montaria", "средство передвижения", "坐骑" },
    PET      = { "pet", "companion", "haustier", "mascotte", "mascote", "спутник", "宠物" },
    TITLE    = { "title", "titel", "titre", "título", "звание", "头衔" },
    TOY      = { "toy", "spielzeug", "jouet", "brinquedo", "игрушка", "玩具" },
    TRANSMOG = { "transmog", "appearance", "aussehen", "apparence", "aparência", "облик", "外观" },
    TABARD   = { "tabard", "wappenrock", "tabardo", "гербовая накидка", "战袍" },
    TELEPORT = { "teleport", "hearthstone", "portal", "teleportation", "телепорт", "传送" },
    HOUSING  = { "decor", "decoration", "housing", "dekoration", "décor", "decoração", "декор", "装饰" },
}

local function EnsureBucket(id)
    local bucket = R.cache[id]
    if not bucket then
        bucket = { types = {}, items = {}, decor = {}, sources = {} }
        R.cache[id] = bucket
    end
    return bucket
end

local function AddType(bucket, typeKey, source)
    if not typeKey then return end
    bucket.types[typeKey] = true
    if source then bucket.sources[typeKey] = bucket.sources[typeKey] or source end
end

local function AddUnique(list, value)
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    list[#list + 1] = value
end

-- ----------------------------------------------------------------------------
-- Provider registry. Order is the registration order; built-ins register at
-- the bottom of this file so API-registered providers land last.
-- ----------------------------------------------------------------------------
function R:RegisterProvider(name, fn)
    if type(name) ~= "string" or name == "" or type(fn) ~= "function" then return false end
    for _, provider in ipairs(self.providers) do
        if provider.name == name then
            provider.fn = fn
            return true
        end
    end
    self.providers[#self.providers + 1] = { name = name, fn = fn }
    self._index = nil
    return true
end

function R:SetOverride(id, types, items, decor)
    id = tonumber(id)
    if not id then return false end
    local record = { types = {}, items = {}, decor = {} }
    for _, typeKey in ipairs(type(types) == "table" and types or {}) do
        record.types[#record.types + 1] = tostring(typeKey):upper()
    end
    for _, itemID in ipairs(type(items) == "table" and items or {}) do
        local numeric = tonumber(itemID)
        if numeric then record.items[#record.items + 1] = numeric end
    end
    for _, decorID in ipairs(type(decor) == "table" and decor or {}) do
        local numeric = tonumber(decorID)
        if numeric then record.decor[#record.decor + 1] = numeric end
    end
    self.overrides[id] = record
    self.cache[id] = nil
    self._index = nil
    return true
end

-- ----------------------------------------------------------------------------
-- Classification
-- ----------------------------------------------------------------------------
function R:Classify(id)
    id = tonumber(id)
    if not id then return nil end
    local cached = self.cache[id]
    if cached and cached._done then return cached end

    local bucket = EnsureBucket(id)
    for _, provider in ipairs(self.providers) do
        local ok, err = pcall(provider.fn, self, id, bucket)
        if not ok and K.Print then
            K:Print("|cffff5555Reward provider " .. provider.name .. " failed:|r " .. tostring(err))
        end
    end

    bucket.typeList = {}
    for _, typeKey in ipairs(self.TYPES) do
        if bucket.types[typeKey] then bucket.typeList[#bucket.typeList + 1] = typeKey end
    end
    bucket.hasAny = #bucket.typeList > 0
    bucket._done = true
    return bucket
end

function R:GetTypes(id)
    local bucket = self:Classify(id)
    return bucket and bucket.typeList or {}
end

function R:HasType(id, typeKey)
    if not typeKey then return false end
    local bucket = self:Classify(id)
    return bucket ~= nil and bucket.types[tostring(typeKey):upper()] == true
end

function R:HasAny(id)
    local bucket = self:Classify(id)
    return bucket ~= nil and bucket.hasAny == true
end

function R:GetDecorIDs(id)
    local bucket = self:Classify(id)
    return bucket and bucket.decor or {}
end

function R:GetItemIDs(id)
    local bucket = self:Classify(id)
    return bucket and bucket.items or {}
end

-- Filter predicate used by Catalog:Query. "ANY"/"NONE" cover the old
-- "rewards only" checkbox; a type key covers the typed filters.
function R:Matches(id, filterKey)
    if filterKey == nil or filterKey == "ALL" then return true end
    if filterKey == "ANY" then return self:HasAny(id) end
    if filterKey == "NONE" then return not self:HasAny(id) end
    return self:HasType(id, filterKey)
end

-- Short human string for the row/tooltip, e.g. "Mount, Title".
function R:Describe(id)
    local types = self:GetTypes(id)
    if #types == 0 then return nil end
    local labels = {}
    for _, typeKey in ipairs(types) do
        labels[#labels + 1] = K.L[typeKey] or typeKey
    end
    return table.concat(labels, ", ")
end

-- ----------------------------------------------------------------------------
-- Reverse index (Rewards tab). Built in chunks so a 5,000-achievement pass
-- never blocks a frame; BuildIndexNow() is the synchronous form used by tests
-- and by a filter change that needs an answer immediately.
-- ----------------------------------------------------------------------------
local CHUNK = 400

local function NewIndex()
    local index = { _counts = {} }
    for _, typeKey in ipairs(R.TYPES) do index[typeKey] = {} end
    index.ANY = {}
    return index
end

function R:BuildIndexNow()
    K.Catalog:Build()
    local index = NewIndex()
    for _, id in ipairs(K.Catalog.order) do
        local bucket = self:Classify(id)
        if bucket and bucket.hasAny then
            index.ANY[#index.ANY + 1] = id
            for _, typeKey in ipairs(bucket.typeList) do
                local list = index[typeKey]
                if list then list[#list + 1] = id end
            end
        end
    end
    for _, typeKey in ipairs(self.TYPES) do
        index._counts[typeKey] = #index[typeKey]
    end
    index._counts.ANY = #index.ANY
    index._complete = true
    self._index = index
    return index
end

function R:BuildIndexAsync(onDone, onProgress)
    if self._index and self._index._complete then
        if onDone then onDone(self._index) end
        return
    end
    if self._building then return end

    K.Catalog:Build()
    self._building = true
    local index = NewIndex()
    local order = K.Catalog.order
    local position = 1

    local function Step()
        local stop = math.min(position + CHUNK - 1, #order)
        for cursor = position, stop do
            local id = order[cursor]
            local bucket = self:Classify(id)
            if bucket and bucket.hasAny then
                index.ANY[#index.ANY + 1] = id
                for _, typeKey in ipairs(bucket.typeList) do
                    local list = index[typeKey]
                    if list then list[#list + 1] = id end
                end
            end
        end
        position = stop + 1
        if onProgress then onProgress(math.min(1, (position - 1) / math.max(1, #order))) end
        if position > #order then
            for _, typeKey in ipairs(self.TYPES) do index._counts[typeKey] = #index[typeKey] end
            index._counts.ANY = #index.ANY
            index._complete = true
            self._index = index
            self._building = false
            if onDone then onDone(index) end
        elseif C_Timer and C_Timer.After then
            C_Timer.After(0, Step)
        else
            Step()
        end
    end

    Step()
end

function R:GetIndex()
    if not (self._index and self._index._complete) then return nil end
    return self._index
end

function R:ListByType(typeKey)
    typeKey = tostring(typeKey or "ANY"):upper()
    local index = self:GetIndex() or self:BuildIndexNow()
    return index[typeKey] or {}
end

function R:Counts()
    local index = self:GetIndex()
    return index and index._counts or nil
end

-- ============================================================================
-- Built-in providers
-- ============================================================================

-- 1. Overrides ----------------------------------------------------------------
R:RegisterProvider("overrides", function(self, id, bucket)
    local record = self.overrides[id]
    if not record then return end
    for _, typeKey in ipairs(record.types) do AddType(bucket, typeKey, "override") end
    for _, itemID in ipairs(record.items) do AddUnique(bucket.items, itemID) end
    for _, decorID in ipairs(record.decor) do AddUnique(bucket.decor, decorID) end
    if #record.decor > 0 then AddType(bucket, "HOUSING", "override") end
end)

-- 2. Blizzard reward items ----------------------------------------------------
-- Item class ids: 15 = Miscellaneous (2 = companion pet, 5 = mount).
local ITEM_CLASS_MISC = 15
local ITEM_SUBCLASS_PET = 2
local ITEM_SUBCLASS_MOUNT = 5

local function ClassifyItem(bucket, itemID)
    AddUnique(bucket.items, itemID)

    local classID, subclassID, equipLoc
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, loc, _, class, subclass = C_Item.GetItemInfoInstant(itemID)
        equipLoc, classID, subclassID = loc, class, subclass
    end

    if classID == ITEM_CLASS_MISC and subclassID == ITEM_SUBCLASS_MOUNT then
        AddType(bucket, "MOUNT", "item")
    elseif classID == ITEM_CLASS_MISC and subclassID == ITEM_SUBCLASS_PET then
        AddType(bucket, "PET", "item")
    end

    if equipLoc == "INVTYPE_TABARD" then
        AddType(bucket, "TABARD", "item")
        AddType(bucket, "TRANSMOG", "item")
    elseif type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        AddType(bucket, "TRANSMOG", "item")
    end

    if C_ToyBox and C_ToyBox.GetToyInfo then
        local toyItemID = C_ToyBox.GetToyInfo(itemID)
        if toyItemID then AddType(bucket, "TOY", "item") end
    end
end

R:RegisterProvider("blizzardItems", function(_, id, bucket)
    if type(GetAchievementNumRewards) ~= "function" or type(GetAchievementReward) ~= "function" then return end
    local count = tonumber(GetAchievementNumRewards(id)) or 0
    for index = 1, count do
        local itemID = GetAchievementReward(id, index)
        itemID = tonumber(itemID)
        if itemID then ClassifyItem(bucket, itemID) end
    end
end)

-- 3. Suite housing data -------------------------------------------------------
-- Villa imports the achievement -> decor index through the data pipeline. Kleos
-- reads it when Villa is loaded rather than keeping a second copy that would
-- drift; when Villa is absent the text provider still flags decor rewards, it
-- just cannot name the decor items.
local function SuiteDecorSource()
    local villa = rawget(_G, "FabledUI_Villa")
    local data = villa and villa.Data and villa.Data.AchievementSources
    if type(data) ~= "table" then return nil end
    return data
end

R.SuiteDecorSource = SuiteDecorSource

R:RegisterProvider("suiteDecor", function(_, id, bucket)
    local source = SuiteDecorSource()
    local record = source and source[id]
    if type(record) ~= "table" then return end
    AddType(bucket, "HOUSING", "villa")
    for _, decorID in ipairs(type(record.decorIDs) == "table" and record.decorIDs or {}) do
        local numeric = tonumber(decorID)
        if numeric then AddUnique(bucket.decor, numeric) end
    end
end)

-- 4. Housing catalog ----------------------------------------------------------
-- A reward item that resolves to a catalog decor entry is decor regardless of
-- what the reward text says.
R:RegisterProvider("housingCatalog", function(_, _, bucket)
    if not (C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem) then return end
    for _, itemID in ipairs(bucket.items) do
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID)
        if ok and type(info) == "table" then
            AddType(bucket, "HOUSING", "catalog")
            -- Field name has moved between builds; read both without asserting
            -- either exists on the returned record.
            local recordID = tonumber(info.recordID or rawget(info, "catalogEntryRecordID"))
            if recordID then AddUnique(bucket.decor, recordID) end
        end
    end
end)

-- 5. Reward text --------------------------------------------------------------
R:RegisterProvider("text", function(self, id, bucket)
    local entry = K.Catalog and K.Catalog:GetEntry(id)
    local text = entry and entry.rewardText
    if type(text) ~= "string" or text == "" then
        local _, _, _, _, _, _, _, _, _, _, rewardText = GetAchievementInfo(id)
        text = rewardText
    end
    if type(text) ~= "string" or text == "" then return end

    local lower = text:lower()
    local matched = false
    for typeKey, tokens in pairs(self.TEXT_TOKENS) do
        for _, token in ipairs(tokens) do
            if lower:find(token, 1, true) then
                AddType(bucket, typeKey, "text")
                matched = true
                break
            end
        end
    end
    -- Reward text present but unrecognised still counts as "has a reward", which
    -- is what the ANY filter and the old "rewards only" checkbox mean.
    if not matched then AddType(bucket, "OTHER", "text") end
    bucket.text = text
end)
