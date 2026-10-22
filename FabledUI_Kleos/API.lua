local K = Kleos

-- ============================================================================
-- API — the open API from the scope doc ("add additional categories with
-- achievements") plus the extension points every other module exposes.
--
-- Published as the KleosAPI global. Everything here is defensive: an addon
-- calling it with junk gets `false`, never an error thrown back across the
-- addon boundary.
--
-- Registered categories are session-scoped by design. A consumer registers on
-- its own PLAYER_LOGIN, so persisting them would only create stale entries for
-- addons the player has since removed.
-- ============================================================================

K.API = K.API or {}
local A = K.API

A.VERSION = 1
A.categories = A.categories or {}       -- key -> { key, name, ids, icon, description, owner }
A.categoryOrder = A.categoryOrder or {}
A.callbacks = A.callbacks or {}          -- event -> { fn, ... }

A.EVENTS = {
    READY = "KLEOS_READY",
    WATCH_CHANGED = "KLEOS_WATCH_CHANGED",
    EXCLUDE_CHANGED = "KLEOS_EXCLUDE_CHANGED",
    ACHIEVEMENT_EARNED = "KLEOS_ACHIEVEMENT_EARNED",
    ENCOUNTER_RESULT = "KLEOS_ENCOUNTER_RESULT",
    CATEGORIES_CHANGED = "KLEOS_CATEGORIES_CHANGED",
}

local MAX_CATEGORY_IDS = 5000

-- ----------------------------------------------------------------------------
-- Callback bus
-- ----------------------------------------------------------------------------
function A:RegisterCallback(event, fn)
    event = tostring(event or "")
    if event == "" or type(fn) ~= "function" then return false end
    self.callbacks[event] = self.callbacks[event] or {}
    local bucket = self.callbacks[event]
    for _, existing in ipairs(bucket) do
        if existing == fn then return true end
    end
    bucket[#bucket + 1] = fn
    return true
end

function A:UnregisterCallback(event, fn)
    local bucket = self.callbacks[tostring(event or "")]
    if not bucket then return false end
    for index, existing in ipairs(bucket) do
        if existing == fn then
            table.remove(bucket, index)
            return true
        end
    end
    return false
end

function A:Fire(event, ...)
    local bucket = self.callbacks[tostring(event or "")]
    if not bucket then return 0 end
    local delivered = 0
    for _, fn in ipairs(bucket) do
        local ok, err = pcall(fn, event, ...)
        if ok then
            delivered = delivered + 1
        elseif K.Print then
            K:Print("|cffff5555API callback error (" .. tostring(event) .. "):|r " .. tostring(err))
        end
    end
    return delivered
end

-- ----------------------------------------------------------------------------
-- Categories
-- ----------------------------------------------------------------------------
function A:RegisterCategory(key, name, ids, options)
    key = tostring(key or "")
    if key == "" or type(ids) ~= "table" then return false end
    options = type(options) == "table" and options or {}

    local clean, seen = {}, {}
    for _, id in ipairs(ids) do
        local numeric = tonumber(id)
        if numeric and numeric > 0 and not seen[numeric] then
            seen[numeric] = true
            clean[#clean + 1] = numeric
            if #clean >= MAX_CATEGORY_IDS then break end
        end
    end
    if #clean == 0 then return false end

    local isNew = self.categories[key] == nil
    self.categories[key] = {
        key = key,
        name = tostring(name or key),
        ids = clean,
        icon = options.icon,
        description = tostring(options.description or ""),
        owner = tostring(options.owner or "unknown"),
    }
    if isNew then self.categoryOrder[#self.categoryOrder + 1] = key end

    -- Registered categories double as curated lists so the existing curated
    -- surfaces pick them up without a second registration call.
    K.Data:RegisterCuratedList(key, self.categories[key].name, clean, self.categories[key].description)
    K.Data:RebuildCuratedFlatList()

    self:Fire(self.EVENTS.CATEGORIES_CHANGED, key)
    if K.UI and K.UI.OnCategoriesChanged then K:SafeCall(function() K.UI:OnCategoriesChanged() end) end
    return true
end

function A:UnregisterCategory(key)
    key = tostring(key or "")
    if not self.categories[key] then return false end
    self.categories[key] = nil
    for index, existing in ipairs(self.categoryOrder) do
        if existing == key then
            table.remove(self.categoryOrder, index)
            break
        end
    end
    K.Data.CURATED_LISTS[key] = nil
    K.Data:RebuildCuratedFlatList()
    self:Fire(self.EVENTS.CATEGORIES_CHANGED, key)
    if K.UI and K.UI.OnCategoriesChanged then K:SafeCall(function() K.UI:OnCategoriesChanged() end) end
    return true
end

function A:ListCategories()
    local list = {}
    for _, key in ipairs(self.categoryOrder) do
        local category = self.categories[key]
        if category then list[#list + 1] = category end
    end
    return list
end

function A:GetCategory(key)
    return self.categories[tostring(key or "")]
end

-- ----------------------------------------------------------------------------
-- Public surface
-- ----------------------------------------------------------------------------
function A:Publish()
    local api = _G.KleosAPI or {}
    _G.KleosAPI = api

    api.VERSION = self.VERSION
    api.EVENTS = self.EVENTS

    api.IsReady = function() return K._ready == true end

    -- Categories / data
    api.RegisterCategory   = function(_, ...) return A:RegisterCategory(...) end
    api.UnregisterCategory = function(_, ...) return A:UnregisterCategory(...) end
    api.ListCategories     = function() return A:ListCategories() end

    -- Extension points on the other modules
    api.RegisterRewardProvider = function(_, name, fn) return K.Rewards:RegisterProvider(name, fn) end
    api.SetRewardOverride      = function(_, id, types, items, decor) return K.Rewards:SetOverride(id, types, items, decor) end
    api.RegisterObjectives     = function(_, id, objectives, source) return K.Objectives:Register(id, objectives, source) end
    api.RegisterTactics        = function(_, key, text) return K.Encounter:RegisterTactics(key, text) end
    api.RegisterCriteriaType   = function(_, criteriaType, resolver) return K.Criteria:RegisterCriteriaType(criteriaType, resolver) end
    api.SetUnobtainable        = function(_, id, value) return K.Catalog:SetUnobtainable(id, value) end

    -- Reads
    api.GetProgress     = function(_, id) return K.Catalog:GetProgress(id) end
    api.GetRewardTypes  = function(_, id) return K.Rewards:GetTypes(id) end
    api.GetDecorIDs     = function(_, id) return K.Rewards:GetDecorIDs(id) end
    api.GetBreakdown    = function(_, id) return K.Meta:Breakdown(id) end
    api.GetRelated      = function(_, id, limit) return K.Meta:GetRelated(id, limit) end
    api.Query           = function(_, filters) return K.Catalog:Query(filters) end
    api.IsWatched       = function(_, id) return K:IsWatched(id) end
    api.IsExcluded      = function(_, id) return K:IsExcluded(id) end
    api.EncounterStatus = function() return K.Encounter:Status() end

    -- Writes the player would expect an addon to be able to make
    api.SetWatched  = function(_, id, value) return K:SetWatched(id, value) end
    api.SetExcluded = function(_, id, value) return K:SetExcluded(id, value) end
    api.ShowAchievement = function(_, id)
        if not K.UI then return false end
        K.UI:ShowAchievement(id)
        return true
    end

    -- Events
    api.RegisterCallback   = function(_, event, fn) return A:RegisterCallback(event, fn) end
    api.UnregisterCallback = function(_, event, fn) return A:UnregisterCallback(event, fn) end

    return api
end

function A:Init()
    self:Publish()
    self:Fire(self.EVENTS.READY, K.VERSION)
end
