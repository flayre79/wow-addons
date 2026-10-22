-- FabledUI_Villa_Tooltip -- the "where does this come from" card for a decor
-- item, as plain data. Tooltip.lua paints it; nothing here touches a frame.
--
-- Most of the answer is in the catalog entry's own sourceText, which Blizzard
-- does not print in the catalog tooltip (owner's screenshot, 2026-09-21: name,
-- category, first-time bonus, and nothing about where to get it). It carries
-- vendor, zone, cost, faction standing, renown rank, profession and skill
-- level, drop and instance, achievement and category. Villa_Decor's Source
-- parser takes it apart.
--
-- What the text lacks is filled from two places:
--   live client   currency names, gold formatting, achievement criteria and
--                 completion, quest completion, reputation standing, how many
--                 of each material you hold
--   DataVault_Villa (via Villa_Decor.Prereqs)
--                 vendor faction, quest/achievement ids, materials, race
--                 locks, expansion (HDG by decorID, DecorVendor by vendor)
--
-- A card is built on every hover. The parse is a few string ops; the imported
-- data is indexed once per session by Prereqs. No caching of live checks:
-- reputation and criteria change as you play and the tooltip must say so.

local Decor = _G.FabledUI_VillaDecor
local Source = _G.FabledUI_VillaDecorSource
if not (Decor and Source) then return end

local Tip = {}
_G.FabledUI_VillaTooltip = Tip

Tip.VERSION = "0.1.0"

local issecretvalue = _G.issecretvalue or function() return false end

local function usableString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

local function usableNumber(value)
    if issecretvalue(value) then return nil end
    return tonumber(value)
end

local MAX_CRITERIA = 8

-- Expansion names the way HDG's import spells them, keyed by the prefix the
-- game puts on a profession ("Midnight Leatherworking", "Dragon Isles
-- Inscription", "Khaz Algar Inscription").
local PROFESSION_PREFIX_EXPANSION = {
    ["Classic"] = "Classic", ["Outland"] = "The Burning Crusade", ["Northrend"] = "Wrath of the Lich King",
    ["Cataclysm"] = "Cataclysm", ["Pandaria"] = "Mists of Pandaria", ["Draenor"] = "Warlords of Draenor",
    ["Legion"] = "Legion", ["Battle for Azeroth"] = "Battle for Azeroth", ["Kul Tiran"] = "Battle for Azeroth",
    ["Zandalari"] = "Battle for Azeroth", ["Shadowlands"] = "Shadowlands", ["Dragon Isles"] = "Dragonflight",
    ["Khaz Algar"] = "The War Within", ["Midnight"] = "Midnight",
}

-- -----------------------------------------------------------------------------
-- API seam (tests replace these)
-- -----------------------------------------------------------------------------

Tip.Api = {
    CurrencyName = function(currencyID)
        if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
        if ok and type(info) == "table" then
            return usableString(info.name), usableNumber(info.iconFileID)
        end
        return nil
    end,

    MoneyText = function(copper)
        local fn = rawget(_G, "GetMoneyString")
        if type(fn) == "function" then
            local ok, text = pcall(fn, copper, true)
            if ok and type(text) == "string" then return text end
        end
        return string.format("%dg", math.floor(copper / 10000))
    end,

    -- name, completed
    AchievementInfo = function(achievementID)
        local fn = rawget(_G, "GetAchievementInfo")
        if type(fn) ~= "function" or type(achievementID) ~= "number" then return nil end
        local ok, id, name, _, completed = pcall(fn, achievementID)
        if not ok or id == nil then return nil end
        return usableString(name), completed and true or false
    end,

    -- { { text, completed }, ... }
    AchievementCriteria = function(achievementID)
        local count = rawget(_G, "GetAchievementNumCriteria")
        local info = rawget(_G, "GetAchievementCriteriaInfo")
        if type(count) ~= "function" or type(info) ~= "function" or type(achievementID) ~= "number" then return nil end
        local okCount, n = pcall(count, achievementID)
        if not okCount or type(n) ~= "number" then return nil end
        local list = {}
        for index = 1, math.min(n, MAX_CRITERIA) do
            local ok, text, _, completed = pcall(info, achievementID, index)
            if ok and usableString(text) then
                list[#list + 1] = { text = text, completed = completed and true or false }
            end
        end
        return list, n
    end,

    ItemCount = function(itemID)
        if not (C_Item and C_Item.GetItemCount) then return nil end
        local ok, count = pcall(C_Item.GetItemCount, itemID, true)
        if ok then return usableNumber(count) end
        return nil
    end,

    ItemName = function(itemID)
        if not (C_Item and C_Item.GetItemNameByID) then return nil end
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok then return usableString(name) end
        return nil
    end,

    Providers = function()
        return rawget(_G, "FabledUI_DataVault_VillaProviders")
    end,

    PlayerFaction = function()
        return Decor.Api.PlayerFaction()
    end,

    -- { recipeID, name, learned, source } from FabledUI_Villa_Recipes, or nil.
    CraftInfo = function(decorID)
        local recipes = rawget(_G, "FabledUI_VillaRecipes")
        if type(recipes) ~= "table" or type(recipes.CraftInfoForDecor) ~= "function" then return nil end
        local ok, info = pcall(recipes.CraftInfoForDecor, recipes, decorID)
        if ok and type(info) == "table" then return info end
        return nil
    end,
}

-- -----------------------------------------------------------------------------
-- Imported lookups (indexed once)
-- -----------------------------------------------------------------------------

Tip._expansionByDecor = nil
Tip._expansionByVendor = nil
Tip._dropByDecor = nil

function Tip:Reset()
    self._expansionByDecor, self._expansionByVendor, self._dropByDecor = nil, nil, nil
end

function Tip:BuildIndexes()
    if self._expansionByDecor then return end
    self._expansionByDecor, self._expansionByVendor, self._dropByDecor = {}, {}, {}
    Decor.Prereqs:Build() -- loads the catalog shard on first use
    local providers = self.Api.Providers()
    if type(providers) ~= "table" then return end

    local hdg = providers["hdg"]
    if type(hdg) == "table" and type(hdg.CatalogEntries) == "table" then
        for _, row in ipairs(hdg.CatalogEntries) do
            local decorID = tonumber(row.decorID)
            if decorID then
                if usableString(row.expansion) then self._expansionByDecor[decorID] = row.expansion end
                -- sourceType 4 is a boss drop in HDG's scheme: label = boss, zone = instance.
                if row.sourceType == 4 and usableString(row.sourceLabel) then
                    self._dropByDecor[decorID] = { boss = row.sourceLabel, place = usableString(row.zone) }
                end
            end
        end
    end

    local decorVendor = providers["decorvendor"]
    if type(decorVendor) == "table" and type(decorVendor.Vendors) == "table" then
        for _, vendor in ipairs(decorVendor.Vendors) do
            local name, expansion = usableString(vendor.name), usableString(vendor.expansion)
            if name and expansion and expansion ~= "Race Locked" then
                self._expansionByVendor[name:lower()] = expansion
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- The card
-- -----------------------------------------------------------------------------

local function costParts(cost)
    local parts = {}
    if type(cost) ~= "table" then return parts end
    if (cost.copper or 0) > 0 then
        parts[#parts + 1] = { text = Tip.Api.MoneyText(cost.copper) }
    end
    for _, currency in ipairs(cost.currencies or {}) do
        local name, icon = Tip.Api.CurrencyName(currency.id)
        parts[#parts + 1] = {
            text = tostring(currency.amount) .. " " .. (name or ("currency " .. currency.id)),
            icon = icon,
        }
    end
    return parts
end

local function joinCost(cost)
    local texts = {}
    for _, part in ipairs(costParts(cost)) do
        texts[#texts + 1] = (part.icon and ("|T" .. part.icon .. ":12:12|t ") or "") .. part.text
    end
    return table.concat(texts, " + ")
end

local function statusOf(list, kind, label)
    for _, req in ipairs(list) do
        if req.kind == kind and (label == nil or req.label == label) then return req.status end
    end
    return nil
end

-- Returns a card:
--   {
--     kinds      = { "Vendor", "Drop", ... }        -- every way the game names
--     vendors    = { { name, faction, zone, cost, costText, gates = { {label, status} } } }
--     drops      = { { boss, place } }
--     crafts     = { { profession, level, expansion, materials = { {name, need, have} } } }
--     achievements = { { name, category, status, criteria = { {text, completed} }, criteriaTotal } }
--     quests     = { { name, status } }
--     treasures  = { { name, place } }
--     events     = { { name } }
--     gates      = { { label, status } }            -- race / faction / reputation on the shown vendor
--     expansion  = "Legion" | nil
--     zones      = { "Dalaran", ... }
--     xp         = number | nil
--   }
function Tip:BuildCard(entryInfo)
    if type(entryInfo) ~= "table" then return nil end
    self:BuildIndexes()

    local entryID = type(entryInfo.entryID) == "table" and entryInfo.entryID or nil
    local decorID = usableNumber(entryID and entryID.recordID) or usableNumber(entryInfo.recordID)
    local itemID = usableNumber(entryInfo.itemID)
    local parsed = Source.Parse(usableString(entryInfo.sourceText))
    local Prereqs = Decor.Prereqs
    local playerFaction = self.Api.PlayerFaction()
    local record = Prereqs:ItemRecord(decorID)

    local card = {
        kinds = {}, vendors = {}, drops = {}, crafts = {}, achievements = {},
        quests = {}, treasures = {}, events = {}, gates = {}, zones = {},
        xp = usableNumber(entryInfo.firstAcquisitionBonus),
        isShop = parsed.isShop,
    }
    local kindSeen, zoneSeen = {}, {}
    local function addKind(kind)
        if not kindSeen[kind] then
            kindSeen[kind] = true
            card.kinds[#card.kinds + 1] = kind
        end
    end
    local function addZone(zone)
        zone = usableString(zone)
        if zone and not zoneSeen[zone:lower()] then
            zoneSeen[zone:lower()] = true
            card.zones[#card.zones + 1] = zone
        end
    end

    -- Vendors, cheapest usable first; each with its own gates.
    local best = Prereqs:BestVendor(parsed, playerFaction)
    local ordered = {}
    if best then ordered[1] = best end
    for _, vendor in ipairs(parsed.vendors) do
        if vendor ~= best then ordered[#ordered + 1] = vendor end
    end
    for index, vendor in ipairs(ordered) do
        addKind("Vendor")
        local needs = Prereqs:ForRow(decorID, itemID, { vendors = { vendor }, others = {}, isShop = false }, vendor, playerFaction)
        local gates = {}
        for _, req in ipairs(needs) do
            if req.kind == "faction" or req.kind == "race" or req.kind == "reputation" then
                gates[#gates + 1] = { label = req.label, status = req.status }
            end
        end
        card.vendors[#card.vendors + 1] = {
            name = vendor.name,
            faction = Prereqs:VendorFaction(vendor.name),
            zone = table.concat(vendor.zones, ", "),
            cost = vendor.cost,
            costText = joinCost(vendor.cost),
            gates = gates,
            best = index == 1,
        }
        for _, zone in ipairs(vendor.zones) do addZone(zone) end
        if index == 1 then card.gates = gates end
    end

    -- Everything the whole text names, with live status where an id exists.
    local needs = Prereqs:ForRow(decorID, itemID, parsed, best, playerFaction)
    local named = {}
    for _, vendor in ipairs(parsed.vendors) do
        for _, req in ipairs(vendor.requires) do named[#named + 1] = req end
    end
    for _, other in ipairs(parsed.others) do named[#named + 1] = other end

    local achievementSeen, questSeen = {}, {}
    for _, req in ipairs(named) do
        local kind = (usableString(req.kind) or ""):lower()
        local name = usableString(req.name)
        for _, zone in ipairs(req.zones or {}) do addZone(zone) end
        if kind == "achievement" and name and not achievementSeen[name] then
            achievementSeen[name] = true
            addKind("Achievement")
            local id = (record and record.achievement == name) and tonumber(record.achievementId) or nil
            local criteria, total
            if id then criteria, total = self.Api.AchievementCriteria(id) end
            card.achievements[#card.achievements + 1] = {
                name = name, category = usableString(req.category), id = id,
                status = statusOf(needs, "achievement", name) or "unknown",
                criteria = criteria or {}, criteriaTotal = total or 0,
            }
        elseif kind == "quest" and name and not questSeen[name] then
            questSeen[name] = true
            addKind("Quest")
            card.quests[#card.quests + 1] = { name = name, status = statusOf(needs, "quest", name) or "unknown" }
        elseif kind == "drop" and name then
            addKind("Drop")
            card.drops[#card.drops + 1] = { boss = name, place = req.zones[1] }
        elseif kind == "profession" and name then
            addKind("Crafted")
            local profession, level = name:match("^(.-)%s*%((%d+)%)$")
            profession = profession or name
            local expansion
            for prefix, label in pairs(PROFESSION_PREFIX_EXPANSION) do
                if profession:sub(1, #prefix) == prefix then expansion = label end
            end
            local materials = {}
            for _, mat in ipairs(record and type(record.materials) == "table" and record.materials or {}) do
                local matID = tonumber(mat.id)
                if matID then
                    materials[#materials + 1] = {
                        id = matID,
                        name = self.Api.ItemName(matID) or usableString(mat.name) or ("item " .. matID),
                        need = tonumber(mat.quantity) or 1,
                        have = self.Api.ItemCount(matID),
                    }
                end
            end
            -- Do you know the recipe, and if not, where is it learned? Live,
            -- through Villa_Recipes when it is installed.
            local recipe = self.Api.CraftInfo(decorID)
            card.crafts[#card.crafts + 1] = {
                profession = profession, level = tonumber(level), expansion = expansion, materials = materials,
                recipeID = recipe and recipe.recipeID or nil,
                known = recipe and recipe.learned,       -- true / false / nil (no recipe on file)
                learnFrom = recipe and recipe.source or nil,
            }
        elseif kind == "treasure" and name then
            addKind("Treasure")
            card.treasures[#card.treasures + 1] = { name = name, place = req.zones[1] }
        elseif kind == "event" and name then
            addKind("Event")
            card.events[#card.events + 1] = { name = name }
        end
    end

    -- An achievement or quest the game's text does not mention but the import does.
    if record then
        if usableString(record.achievement) and not achievementSeen[record.achievement] then
            addKind("Achievement")
            local id = tonumber(record.achievementId)
            local criteria, total
            if id then criteria, total = self.Api.AchievementCriteria(id) end
            card.achievements[#card.achievements + 1] = {
                name = record.achievement, id = id,
                status = statusOf(needs, "achievement", record.achievement) or "unknown",
                criteria = criteria or {}, criteriaTotal = total or 0,
            }
        end
        if usableString(record.quest) and not questSeen[record.quest] then
            addKind("Quest")
            card.quests[#card.quests + 1] = { name = record.quest, status = statusOf(needs, "quest", record.quest) or "unknown" }
        end
    end
    if #card.drops == 0 and decorID and self._dropByDecor[decorID] then
        addKind("Drop")
        card.drops[1] = self._dropByDecor[decorID]
        addZone(card.drops[1].place)
    end
    if parsed.isShop then addKind("Shop") end

    -- Expansion: the import by decor id, then by the shown vendor, then the
    -- profession's prefix.
    card.expansion = decorID and self._expansionByDecor[decorID] or nil
    if not card.expansion and best and usableString(best.name) then
        card.expansion = self._expansionByVendor[best.name:lower()]
    end
    if not card.expansion and card.crafts[1] then card.expansion = card.crafts[1].expansion end

    return card
end
