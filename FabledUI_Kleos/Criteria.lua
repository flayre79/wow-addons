local K = Kleos
K.Criteria = {}
local C = K.Criteria

-- ============================================================================
-- Criteria — SVC-003
-- The shared requirement service. Two jobs:
--
--   Describe(req)  turn a requirement into "what is this / how far am I"
--   Open(req)      best-effort deep link: open the panel that lets the player
--                  actually work on it
--
-- Published as the KleosCriteria global so other suite addons (VillaHouse, Villa)
-- can consume it without a hard dependency on Kleos internals.
--
-- Deep linking is explicitly best-effort per the PRD glossary: every branch is
-- guarded and Open() returns false rather than erroring when the client does
-- not expose the panel.
-- ============================================================================

local KC = _G.KleosCriteria or {}
_G.KleosCriteria = KC

local VALID_TYPES = {
    achievement = true, quest = true, reputation = true, renown = true,
    faction = true, class = true, race = true, profession = true, item = true,
    spell = true, currency = true, creature = true, area = true, map = true,
    level = true, skill = true, battleground = true, decor = true, encounter = true,
}

function C:Init()
    KC.IsAvailable   = function() return true end
    KC.Normalize     = function(_, req) return C:Normalize(req) end
    KC.Describe      = function(_, req) return C:Describe(req) end
    KC.Open          = function(_, req) return C:Open(req) end
    KC.Breakdown     = function(_, id) return K.Meta:Breakdown(id) end
    KC.Progress      = function(_, id) return K.Catalog:GetProgress(id) end
    KC.RegisterCriteriaType = function(_, criteriaType, resolver) return C:RegisterCriteriaType(criteriaType, resolver) end
    KC.VERSION = 2
end

local function normType(value)
    value = tostring(value or ""):lower()
    return VALID_TYPES[value] and value or "unknown"
end

function C:Normalize(req)
    if type(req) == "number" then return { type = "achievement", id = req } end
    if type(req) == "string" then
        local kind, id = req:match("^(%a+)%:([%w_%-]+)$")
        if kind and id then return { type = normType(kind), id = tonumber(id) or id } end
        local numeric = tonumber(req)
        return numeric and { type = "achievement", id = numeric } or { type = "unknown", id = req }
    end
    if type(req) == "table" then
        if req.type and req.id ~= nil then
            return { type = normType(req.type), id = req.id, meta = req.meta, label = req.label }
        end
        if req.achievementID then return { type = "achievement", id = tonumber(req.achievementID) } end
        if req.questID then return { type = "quest", id = tonumber(req.questID) } end
        if req.itemID then return { type = "item", id = tonumber(req.itemID) } end
        if req.factionID then return { type = "reputation", id = tonumber(req.factionID) } end
        if req.currencyID then return { type = "currency", id = tonumber(req.currencyID) } end
    end
    return { type = "unknown", id = req }
end

-- ----------------------------------------------------------------------------
-- Criteria type -> requirement mapping
-- Blizzard's criteria type ids are not documented in the API and the full set
-- runs past 150 values, so this table is deliberately partial: only the types
-- whose assetID meaning is certain are mapped. Everything else falls back to
-- the criterion's own text, which is what the player sees in Blizzard's UI
-- anyway. Addons can extend it through RegisterCriteriaType / the open API.
-- ----------------------------------------------------------------------------
C.CRITERIA_TYPE_MAP = {
    [0]  = "creature",     -- kill creature (assetID = creature id)
    [1]  = "battleground", -- win battleground (assetID = map id)
    [5]  = "level",        -- reach character level
    [7]  = "skill",        -- reach skill level (assetID = skill line id)
    [8]  = "achievement",  -- complete achievement (assetID = achievement id)
    [27] = "quest",        -- complete quest (assetID = quest id)
    [28] = "spell",        -- be hit by / cast spell (assetID = spell id)
    [29] = "spell",        -- cast spell (assetID = spell id)
    [36] = "item",         -- own item (assetID = item id)
    [41] = "item",         -- consume item (assetID = item id)
    [43] = "area",         -- explore area (assetID = area id)
    [46] = "reputation",   -- reach reputation with faction (assetID = faction id)
    [69] = "item",         -- equip item (assetID = item id)
}

C.customResolvers = C.customResolvers or {}

function C:RegisterCriteriaType(criteriaType, resolver)
    criteriaType = tonumber(criteriaType)
    if not criteriaType then return false end
    if type(resolver) == "string" then
        self.CRITERIA_TYPE_MAP[criteriaType] = normType(resolver)
        return true
    end
    if type(resolver) == "function" then
        self.customResolvers[criteriaType] = resolver
        return true
    end
    return false
end

-- Given an achievement id and one breakdown step, return the requirement that
-- step deep-links to, or nil when the criterion carries no usable asset.
function C:LinkForCriteria(achievementID, step)
    if type(step) ~= "table" then return nil end
    local criteriaType = tonumber(step.criteriaType)
    if not criteriaType then return nil end

    local custom = self.customResolvers[criteriaType]
    if custom then
        local ok, result = pcall(custom, achievementID, step)
        if ok and type(result) == "table" then return self:Normalize(result) end
    end

    local mapped = self.CRITERIA_TYPE_MAP[criteriaType]
    if not mapped then return nil end
    local assetID = tonumber(step.assetID)
    if mapped == "level" then
        return { type = "level", id = tonumber(step.required) or assetID or 0 }
    end
    if not assetID or assetID <= 0 then return nil end
    return { type = mapped, id = assetID, label = step.text }
end

-- ----------------------------------------------------------------------------
-- Describe
-- Returns title, status, satisfied. Callers render title/status directly, so
-- both are always strings.
-- ----------------------------------------------------------------------------
local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(id)
        if name then return name end
    end
    return ("Item #%d"):format(id)
end

local function ItemCount(id)
    if C_Item and C_Item.GetItemCount then
        return tonumber(C_Item.GetItemCount(id, true, false, true)) or 0
    end
    return 0
end

local function FactionName(id)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(id)
        if type(data) == "table" and data.name then return data.name, data.currentStanding, data.currentReactionThreshold end
    end
    -- Pre-11.x global, gone on current retail: reach for it dynamically so this
    -- stays a runtime fallback rather than an undefined global reference.
    local legacy = rawget(_G, "GetFactionInfoByID")
    if type(legacy) == "function" then
        local name, _, _, _, _, earned = legacy(id)
        if name then return name, earned end
    end
    return ("Faction #%d"):format(id)
end

function C:Describe(req)
    local r = self:Normalize(req)
    local id = tonumber(r.id)

    if r.type == "achievement" and id then
        local _, name, _, completed = GetAchievementInfo(id)
        if name and name ~= "" then
            local progress = K.Catalog and K.Catalog:GetProgress(id) or 0
            local status
            if completed then
                status = K.L.COMPLETE or "Complete"
            elseif progress > 0 then
                status = ("%d%%"):format(math.floor(progress * 100 + 0.5))
            else
                status = K.L.INCOMPLETE or "In progress"
            end
            if not completed and progress > 0 then
                status = (K.L.INCOMPLETE or "In progress") .. " (" .. status .. ")"
            end
            return ("%s: %s"):format(K.L.ACHIEVEMENT or "Achievement", name), status, completed and true or false
        end

    elseif r.type == "quest" and id then
        local completed = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
        local name
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then name = C_QuestLog.GetTitleForQuestID(id) end
        return ("%s: %s"):format(K.L.QUEST or "Quest", name or ("#" .. id)),
               completed and (K.L.COMPLETE or "Complete") or (K.L.INCOMPLETE or "Not complete"),
               completed and true or false

    elseif r.type == "item" and id then
        local count = ItemCount(id)
        return ("%s: %s"):format(K.L.ITEM or "Item", ItemName(id)), ("%s: %d"):format(K.L.OWNED or "Owned", count), count > 0

    elseif (r.type == "reputation" or r.type == "faction" or r.type == "renown") and id then
        local name, standing = FactionName(id)
        return ("%s: %s"):format(K.L.REPUTATION or "Reputation", name),
               standing and tostring(standing) or (K.L.UNKNOWN or "Unknown"),
               false

    elseif r.type == "currency" and id then
        local quantity, name = 0, nil
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            if type(info) == "table" then
                quantity = tonumber(info.quantity) or 0
                name = info.name
            end
        end
        return ("%s: %s"):format(K.L.CURRENCY or "Currency", name or ("#" .. id)), tostring(quantity), quantity > 0

    elseif r.type == "spell" and id then
        local name
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(id)
            name = type(info) == "table" and info.name or nil
        end
        return ("%s: %s"):format(K.L.SPELL or "Spell", name or ("#" .. id)), K.L.UNKNOWN or "Unknown", false

    elseif r.type == "level" and id then
        local level = (type(UnitLevel) == "function") and (UnitLevel("player") or 0) or 0
        return ("%s %d"):format(K.L.LEVEL or "Level", id), ("%d/%d"):format(level, id), level >= id

    elseif r.type == "creature" and id then
        return ("%s #%d"):format(K.L.CREATURE or "Creature", id), K.L.UNKNOWN or "Unknown", false

    elseif (r.type == "area" or r.type == "map" or r.type == "battleground") and id then
        local name
        if C_Map and C_Map.GetMapInfo then
            local info = C_Map.GetMapInfo(id)
            name = type(info) == "table" and info.name or nil
        end
        return ("%s: %s"):format(K.L.ZONE or "Zone", name or ("#" .. id)), K.L.UNKNOWN or "Unknown", false

    elseif r.type == "skill" and id then
        return ("%s #%d"):format(K.L.PROFESSION or "Profession", id), K.L.UNKNOWN or "Unknown", false

    elseif r.type == "decor" and id then
        local name
        if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID and Enum and Enum.HousingCatalogEntryType then
            local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, Enum.HousingCatalogEntryType.Decor, id)
            if ok and type(info) == "table" then name = info.name end
        end
        return ("%s: %s"):format(K.L.HOUSING or "Housing Decor", name or ("#" .. id)), K.L.UNKNOWN or "Unknown", false
    end

    local label = r.label or tostring(r.id)
    return ("%s: %s"):format(K.L.REQUIREMENT or "Requirement", label), K.L.UNKNOWN or "Unknown", false
end

-- ----------------------------------------------------------------------------
-- Open — best-effort deep links
-- ----------------------------------------------------------------------------
local function Try(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, ...)
    return ok
end

local function OpenAchievement(id)
    local opened = false
    if type(ToggleAchievementFrame) == "function" then
        -- Toggle would close an already-open frame, so only call it when the
        -- pane is not up.
        local frame = rawget(_G, "AchievementFrame")
        if not (frame and frame.IsShown and frame:IsShown()) then
            opened = Try(ToggleAchievementFrame)
        else
            opened = true
        end
    end
    if type(rawget(_G, "AchievementFrame_SelectAchievement")) == "function" then
        Try(_G.AchievementFrame_SelectAchievement, id)
    end
    return opened
end

C.OpenAchievement = OpenAchievement

function C:Open(req)
    local r = self:Normalize(req)
    local id = tonumber(r.id)

    if r.type == "achievement" and id then
        return OpenAchievement(id)

    elseif r.type == "quest" and id then
        if C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id)
            and type(rawget(_G, "QuestMapFrame_OpenToQuestDetails")) == "function" then
            if Try(_G.QuestMapFrame_OpenToQuestDetails, id) then return true end
        end
        if type(rawget(_G, "ToggleQuestLog")) == "function" then return Try(_G.ToggleQuestLog) end
        if type(rawget(_G, "ToggleWorldMap")) == "function" then return Try(_G.ToggleWorldMap) end
        return false

    elseif r.type == "item" and id then
        -- Collectible rewards open their journal; everything else links the item.
        if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(id) then
            if Try(rawget(_G, "ToggleToyCollection")) then return true end
        end
        if type(rawget(_G, "ToggleCollectionsJournal")) == "function" then
            return Try(_G.ToggleCollectionsJournal)
        end
        return false

    elseif r.type == "reputation" or r.type == "faction" or r.type == "renown" then
        if type(rawget(_G, "ToggleCharacter")) == "function" then
            return Try(_G.ToggleCharacter, "ReputationFrame")
        end
        return false

    elseif r.type == "currency" then
        if type(rawget(_G, "ToggleCharacter")) == "function" then
            return Try(_G.ToggleCharacter, "TokenFrame")
        end
        return false

    elseif r.type == "skill" or r.type == "profession" then
        if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and id then
            if Try(C_TradeSkillUI.OpenTradeSkill, id) then return true end
        end
        if type(rawget(_G, "ToggleProfessionsBook")) == "function" then
            return Try(_G.ToggleProfessionsBook)
        end
        if type(rawget(_G, "ToggleSpellBook")) == "function" then
            return Try(_G.ToggleSpellBook, rawget(_G, "BOOKTYPE_PROFESSION") or "professions")
        end
        return false

    elseif (r.type == "area" or r.type == "map" or r.type == "battleground") and id then
        local mapFrame = rawget(_G, "WorldMapFrame")
        if type(rawget(_G, "OpenWorldMap")) == "function" then
            if Try(_G.OpenWorldMap, id) then return true end
        end
        if mapFrame and mapFrame.SetMapID then
            if type(rawget(_G, "ToggleWorldMap")) == "function" then Try(_G.ToggleWorldMap) end
            return Try(mapFrame.SetMapID, mapFrame, id)
        end
        return false

    elseif r.type == "encounter" and id then
        if type(rawget(_G, "EncounterJournal_OpenJournal")) == "function" then
            return Try(_G.EncounterJournal_OpenJournal, nil, nil, id)
        end
        return false

    elseif r.type == "decor" and id then
        -- Housing decor lives in Villa in this suite; fall back to the
        -- Blizzard housing UI when Villa is not loaded.
        local villa = rawget(_G, "FabledUI_Villa")
        if villa and type(villa.ShowDecor) == "function" then
            if Try(villa.ShowDecor, villa, id) then return true end
        end
        if type(rawget(_G, "ToggleHousingMarketFrame")) == "function" then
            return Try(_G.ToggleHousingMarketFrame)
        end
        return false

    elseif r.type == "spell" and id then
        if type(rawget(_G, "ToggleSpellBook")) == "function" then
            return Try(_G.ToggleSpellBook, rawget(_G, "BOOKTYPE_SPELL") or "spell")
        end
        return false
    end

    return false
end

-- Convenience for the UI: does this requirement have anywhere to go?
function C:CanOpen(req)
    local r = self:Normalize(req)
    if r.type == "unknown" then return false end
    if r.type == "creature" or r.type == "level" then return false end
    return true
end
