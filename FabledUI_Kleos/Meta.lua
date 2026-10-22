local K = Kleos

-- ============================================================================
-- Meta
-- Meta-achievement interaction and the step-by-step breakdown the PRD asks
-- for. A meta achievement is one whose criteria are themselves achievements
-- (criteria type 8, CRITERIA_TYPE_ACHIEVEMENT), where the criteria assetID is
-- the child achievement id.
--
-- Three relationships are exposed:
--   children  the achievements a meta is made of
--   parents   the metas that include a given achievement (reverse index)
--   chain     Blizzard's progressive series, via GetPreviousAchievement /
--             GetNextAchievement (e.g. "Level 10 -> 20 -> 30")
-- ============================================================================

K.Meta = K.Meta or {}
local M = K.Meta

-- CRITERIA_TYPE_ACHIEVEMENT is a FrameXML global; fall back to its known value
-- so a client that stops exporting it does not silently disable meta support.
local CRITERIA_ACHIEVEMENT = rawget(_G, "CRITERIA_TYPE_ACHIEVEMENT") or 8

M._parentIndex = nil
M._childCache = M._childCache or {}

local MAX_CHAIN = 20

local function AchievementName(id)
    local entry = K.Catalog and K.Catalog:GetEntry(id)
    if entry and entry.name and entry.name ~= "" then return entry.name end
    local _, name = GetAchievementInfo(id)
    if type(name) == "string" and name ~= "" then return name end
    return ("Achievement #%d"):format(id)
end

M.AchievementName = AchievementName

-- ----------------------------------------------------------------------------
-- Children
-- ----------------------------------------------------------------------------
function M:GetChildren(id)
    id = tonumber(id)
    if not id then return {} end
    local cached = self._childCache[id]
    if cached then return cached end

    local children = {}
    local count = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(id)) or 0
    for index = 1, count do
        local criteriaString, criteriaType, completed, _, _, _, _, assetID = GetAchievementCriteriaInfo(id, index)
        if criteriaType == CRITERIA_ACHIEVEMENT then
            local childID = tonumber(assetID)
            if childID and childID > 0 then
                children[#children + 1] = {
                    achievementID = childID,
                    criteriaIndex = index,
                    completed = completed and true or false,
                    name = (type(criteriaString) == "string" and criteriaString ~= "") and criteriaString or AchievementName(childID),
                }
            end
        end
    end

    self._childCache[id] = children
    return children
end

function M:IsMeta(id)
    return #self:GetChildren(id) > 0
end

-- ----------------------------------------------------------------------------
-- Parents (reverse index)
-- Built by scanning the catalog for meta achievements once. Cheap relative to
-- the catalog build itself: only achievements with criteria are touched.
-- ----------------------------------------------------------------------------
function M:BuildParentIndex(force)
    if self._parentIndex and not force then return self._parentIndex end
    K.Catalog:Build()

    local index = {}
    for _, id in ipairs(K.Catalog.order) do
        for _, child in ipairs(self:GetChildren(id)) do
            local bucket = index[child.achievementID]
            if not bucket then
                bucket = {}
                index[child.achievementID] = bucket
            end
            bucket[#bucket + 1] = id
        end
    end

    self._parentIndex = index
    return index
end

function M:GetParents(id)
    id = tonumber(id)
    if not id then return {} end
    local index = self:BuildParentIndex()
    local parents = index[id]
    if not parents then return {} end
    local copy = {}
    for position, parentID in ipairs(parents) do copy[position] = parentID end
    return copy
end

-- ----------------------------------------------------------------------------
-- Progressive chain
-- ----------------------------------------------------------------------------
function M:GetChain(id)
    id = tonumber(id)
    if not id then return {} end

    local first = id
    if type(GetPreviousAchievement) == "function" then
        for _ = 1, MAX_CHAIN do
            local previous = GetPreviousAchievement(first)
            if not previous or previous == first then break end
            first = previous
        end
    end

    local chain = { first }
    if type(GetNextAchievement) == "function" then
        local current = first
        for _ = 1, MAX_CHAIN do
            local nextID = GetNextAchievement(current)
            if not nextID or nextID == current then break end
            chain[#chain + 1] = nextID
            current = nextID
        end
    end
    return chain
end

-- ----------------------------------------------------------------------------
-- Related achievements
-- Union of chain siblings, meta parents, meta children and same-category
-- neighbours, de-duplicated and with the subject itself removed. Feeds the
-- right-click "Related achievements" submenu and the enhanced tooltip.
-- ----------------------------------------------------------------------------
function M:GetRelated(id, limit)
    id = tonumber(id)
    if not id then return {} end
    limit = tonumber(limit) or 12

    local seen = { [id] = true }
    local related = {}

    local function Push(candidate, relation)
        candidate = tonumber(candidate)
        if not candidate or seen[candidate] then return end
        if #related >= limit then return end
        seen[candidate] = true
        related[#related + 1] = { achievementID = candidate, relation = relation, name = AchievementName(candidate) }
    end

    for _, chainID in ipairs(self:GetChain(id)) do Push(chainID, "chain") end
    for _, parentID in ipairs(self:GetParents(id)) do Push(parentID, "meta") end
    for _, child in ipairs(self:GetChildren(id)) do Push(child.achievementID, "child") end

    local entry = K.Catalog:GetEntry(id)
    if entry and entry.category then
        for _, candidate in ipairs(K.Catalog.order) do
            if #related >= limit then break end
            local other = K.Catalog.entries[candidate]
            if other and other.category == entry.category then Push(candidate, "category") end
        end
    end

    return related
end

-- ----------------------------------------------------------------------------
-- Breakdown
-- One ordered step list that works for both metas and ordinary achievements,
-- so the detail pane and the tracker render from the same shape.
--   kind         "achievement" for meta children, "criteria" otherwise
--   text         label to draw
--   completed    boolean
--   quantity / required   progress numbers when the criterion has them
--   link         normalised requirement handed to Criteria:Open for deep links
-- ----------------------------------------------------------------------------
function M:Breakdown(id)
    id = tonumber(id)
    if not id then return {} end

    local steps = {}
    local count = tonumber(GetAchievementNumCriteria and GetAchievementNumCriteria(id)) or 0

    for index = 1, count do
        local criteriaString, criteriaType, completed, quantity, requiredQuantity,
              _, flags, assetID, quantityString, criteriaID, eligible, duration, elapsed
            = GetAchievementCriteriaInfo(id, index)

        local step = {
            index = index,
            criteriaID = tonumber(criteriaID),
            criteriaType = tonumber(criteriaType),
            completed = completed and true or false,
            quantity = tonumber(quantity) or 0,
            required = tonumber(requiredQuantity) or 0,
            quantityString = quantityString,
            assetID = tonumber(assetID),
            flags = tonumber(flags) or 0,
            eligible = eligible ~= false,
            duration = tonumber(duration),
            elapsed = tonumber(elapsed),
        }

        if step.criteriaType == CRITERIA_ACHIEVEMENT and step.assetID then
            step.kind = "achievement"
            step.text = (type(criteriaString) == "string" and criteriaString ~= "") and criteriaString or AchievementName(step.assetID)
            step.link = { type = "achievement", id = step.assetID }
            local childProgress = K.Catalog:GetProgress(step.assetID)
            step.childProgress = childProgress
        else
            step.kind = "criteria"
            step.text = (type(criteriaString) == "string" and criteriaString ~= "") and criteriaString
                or ("%s %d"):format(K.L.CRITERIA or "Criteria", index)
            step.link = K.Criteria and K.Criteria:LinkForCriteria(id, step) or nil
        end

        steps[#steps + 1] = step
    end

    return steps
end

function M:CompletionSummary(id)
    local steps = self:Breakdown(id)
    local done = 0
    for _, step in ipairs(steps) do
        if step.completed then done = done + 1 end
    end
    local progress = K.Catalog:GetProgress(id)
    return {
        steps = #steps,
        completed = done,
        progress = progress,
        isMeta = self:IsMeta(id),
    }
end
