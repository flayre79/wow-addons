local Providers = _G.FabledUI_DataVault_VillaProviders or {}
_G.FabledUI_DataVault_VillaProviders = Providers

local function _CurrentVilla()
    return _G.FabledUI_Villa or {}
end

local Villa = setmetatable({}, {
    __index = function(_, key)
        local current = _CurrentVilla()
        local value = current[key]
        if value ~= nil then
            return value
        end
        if key == "RegisterModule" or key == "RegisterEngine" then
            return function() end
        end
        if key == "engineRegistry" then
            return {}
        end
        return nil
    end,
    __newindex = function(_, key, value)
        local current = _G.FabledUI_Villa
        if current then
            current[key] = value
        end
    end,
})

local NormalizedData = Providers["normalized"] or {}
Providers["normalized"] = NormalizedData
Villa.NormalizedData = NormalizedData
Villa:RegisterModule("NormalizedData", NormalizedData)

local function shallowCopy(source)
    local copy = {}
    for k, v in pairs(source or {}) do
        copy[k] = v
    end
    return copy
end

local function normalizeText(value)
    value = tostring(value or "")
    value = value:lower()
    value = value:gsub("[%s_%-]+", " ")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function normalizeNumber(value)
    local number = tonumber(value)
    return number and tostring(number) or ""
end

local function normalizeCoord(value)
    local number = tonumber(value)
    if not number then
        return ""
    end
    return tostring(math.floor(number * 100 + 0.5))
end

local function normalizeDecorIds(decorIds)
    local ordered, seen = {}, {}
    for _, decorID in ipairs(decorIds or {}) do
        decorID = tonumber(decorID)
        if decorID and not seen[decorID] then
            seen[decorID] = true
            ordered[#ordered + 1] = decorID
        end
    end
    table.sort(ordered)
    return ordered
end

local function mergeUniqueList(target, incoming)
    local seen = {}
    for _, value in ipairs(target) do
        seen[tostring(value)] = true
    end
    for _, value in ipairs(incoming or {}) do
        local key = tostring(value)
        if not seen[key] then
            seen[key] = true
            target[#target + 1] = value
        end
    end
end

local function sortedTags(tagSet)
    local tags = {}
    for tag in pairs(tagSet or {}) do
        tags[#tags + 1] = tag
    end
    table.sort(tags)
    return tags
end

local function sortEntries(entries)
    table.sort(entries, function(a, b)
        if (a.subtitle or "") ~= (b.subtitle or "") then
            return (a.subtitle or "") < (b.subtitle or "")
        end
        return tostring(a.title or "") < tostring(b.title or "")
    end)
end

local decorToItemCache
local function decorToItemMap(home)
    if decorToItemCache then
        return decorToItemCache
    end
    local map = {}
    for itemID, meta in pairs((home and home.decorMeta) or {}) do
        local decorID = tonumber(meta and meta.decorID)
        if decorID and not map[decorID] then
            map[decorID] = tonumber(itemID)
        end
    end
    decorToItemCache = map
    return map
end

local function isDecorCollected(home, decorID)
    local itemID = decorToItemMap(home)[tonumber(decorID)]
    return itemID and Villa:IsKnownDecorItem(itemID) or false
end

local function collectionSummary(home, decorIds)
    local owned, total = 0, 0
    for _, decorID in ipairs(decorIds or {}) do
        total = total + 1
        if isDecorCollected(home, decorID) then
            owned = owned + 1
        end
    end
    return owned, total
end

local function buildDecorText(decorIds, limit)
    local parts = {}
    local max = limit or 18
    for i, decorID in ipairs(decorIds or {}) do
        if i > max then
            parts[#parts + 1] = string.format("… +%d more", #decorIds - max)
            break
        end
        parts[#parts + 1] = tostring(decorID)
    end
    return table.concat(parts, ", ")
end

function NormalizedData:Invalidate()
    self._vendorList = nil
    self._achievementEntries = nil
    self._questEntries = nil
    self._dropEntries = nil
    self._professionEntries = nil
    self._pvpEntries = nil
    self._trainerEntries = nil
    self._materialEntries = nil
    self._reputationEntries = nil
    self._planningEntries = nil
    self._statisticsEntries = nil
    self._previewEntries = nil
    self._catalogEntries = nil
    self._styleEntries = nil
    self._treasureEntries = nil
    self._providerStats = nil
    self._duplicateMatrix = nil
    self._audit = nil
    self._materialInfoByItem = nil
    decorToItemCache = nil
end

function NormalizedData:_recordAudit(domain, rawCount, normalizedCount, providerSet)
    self._audit = self._audit or {}
    self._audit[domain] = {
        rawCount = tonumber(rawCount) or 0,
        normalizedCount = tonumber(normalizedCount) or 0,
        duplicateCount = math.max((tonumber(rawCount) or 0) - (tonumber(normalizedCount) or 0), 0),
        providers = sortedTags(providerSet),
    }
end

function NormalizedData:GetDuplicateMatrix()
    if self._duplicateMatrix then
        return self._duplicateMatrix
    end

    local matrix = {
        { domain = "vendors",      label = "Vendors",      getter = function() return self:GetVendorList() end },
        { domain = "achievements", label = "Achievements", getter = function() return self:GetAchievementEntries() end },
        { domain = "quests",       label = "Quests",       getter = function() return self:GetQuestEntries() end },
        { domain = "drops",        label = "Drops",        getter = function() return self:GetDropEntries() end },
        { domain = "professions",  label = "Professions",  getter = function() return self:GetProfessionEntries() end },
        { domain = "pvp",          label = "PvP",          getter = function() return self:GetPvPEntries() end },
        { domain = "treasures",    label = "Treasures",    getter = function() return self:GetTreasureEntries() end },
        { domain = "catalog",      label = "Catalog",      getter = function() return self:GetCatalogEntries() end },
        { domain = "styles",       label = "Styles",       getter = function() return self:GetStyleEntries() end },
        { domain = "trainers",     label = "Trainers",     getter = function() return self:GetTrainerEntries() end },
        { domain = "preview",      label = "Preview",      getter = function() return self:GetPreviewEntries() end },
        { domain = "materials",    label = "Materials",    getter = function() return self:GetMaterialsEntries() end },
        { domain = "reputation",   label = "Reputation",   getter = function() return self:GetReputationEntries() end },
        { domain = "planning",     label = "Planning",     getter = function() return self:GetPlanningEntries() end },
    }

    for _, row in ipairs(matrix) do
        row.getter()
        local audit = (self._audit and self._audit[row.domain]) or { rawCount = 0, normalizedCount = 0, duplicateCount = 0, providers = {} }
        row.rawCount = audit.rawCount
        row.normalizedCount = audit.normalizedCount
        row.duplicateCount = audit.duplicateCount
        row.providers = audit.providers
        row.providerSummary = table.concat(audit.providers or {}, ", ")
        row.detail = string.format("Raw: %d\nNormalized: %d\nDuplicates removed: %d\nProviders: %s", row.rawCount, row.normalizedCount, row.duplicateCount, row.providerSummary ~= "" and row.providerSummary or "n/a")
    end

    self._duplicateMatrix = matrix
    return matrix
end

local function vendorIdentityKey(name, zone, currency, npcID)
    local idPart = normalizeNumber(npcID)
    if idPart ~= "" then
        return table.concat({ "npc", idPart }, "|")
    end
    return table.concat({
        "name",
        normalizeText(name or "Unknown Vendor"),
        normalizeText(zone or "Unknown Zone"),
        normalizeText(currency or ""),
    }, "|")
end

local function vendorLocationKey(mapID, x, y, zone)
    return table.concat({
        normalizeNumber(mapID),
        normalizeCoord(x),
        normalizeCoord(y),
        normalizeText(zone or ""),
    }, "|")
end

local function GetMapParentID(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.parentMapID or nil
end

local function MapContainsVendor(currentMapID, vendorMapID)
    currentMapID = tonumber(currentMapID)
    vendorMapID = tonumber(vendorMapID)
    if not currentMapID or not vendorMapID then
        return false
    end
    if currentMapID == vendorMapID then
        return true
    end
    local seen = {}
    local cursor = vendorMapID
    while cursor and not seen[cursor] do
        seen[cursor] = true
        cursor = GetMapParentID(cursor)
        if cursor == currentMapID then
            return true
        end
    end
    return false
end

local function itemKey(entry)
    -- Dedupe on the canonical decorID (== catalog recordID). Fall back to itemID,
    -- then name, so entries lacking a decorID still collapse sensibly. Source-
    -- specific fields (itemID/requirementText/sourceType) are intentionally NOT
    -- part of the key — the SAME decor supplied by multiple donors (Codex + HIT +
    -- DecorVendor all list Corlen's 13 pieces) must collapse to one entry, or the
    -- vendor inflates (13 x 3 = 39). Coalescing in ingestVendor then merges their
    -- fields so the surviving entry inherits a real itemID.
    local decorIds = normalizeDecorIds({ entry and entry.decorID })
    local decorPart = table.concat(decorIds, ",")
    if decorPart ~= "" then
        return "d:" .. decorPart
    end
    local itemPart = normalizeNumber(entry and entry.itemID)
    if itemPart ~= "" and itemPart ~= "0" then
        return "i:" .. itemPart
    end
    return "n:" .. normalizeText(entry and entry.name or "Unknown")
end

local function normalizeItem(home, raw, sourceTag)
    local entry = shallowCopy(raw or {})
    entry.sourceAddon = entry.sourceAddon or sourceTag
    if not entry.decorID and entry.itemID and home and home.GetMeta then
        local meta = home:GetMeta(entry.itemID)
        if meta and meta.decorID then
            entry.decorID = meta.decorID
        end
    end
    if home and home.GetDecorDisplayName then
        entry.name = home:GetDecorDisplayName(entry)
    else
        entry.name = entry.name or (entry.decorID and ("Decor #" .. tostring(entry.decorID))) or (entry.itemID and ("Item #" .. tostring(entry.itemID))) or "Decor"
    end
    entry.isCollected = (home and home.IsEntryCollected and home:IsEntryCollected(entry)) or false
    return entry
end

local function ingestVendor(results, grouped, home, sourceTag, vendor)
    if type(vendor) ~= "table" then
        return false
    end
    local key = vendorIdentityKey(vendor.name or vendor.vendorName, vendor.zone, vendor.currency or vendor.requirementLabel, vendor.npcID)
    local row = grouped[key]
    local created = false
    if not row then
        row = {
            vendorKey = key,
            npcID = vendor.npcID,
            name = vendor.name or vendor.vendorName or "Unknown Vendor",
            zone = vendor.zone or "Unknown Zone",
            mapID = vendor.mapID,
            x = vendor.x,
            y = vendor.y,
            cityName = vendor.cityName,
            currency = vendor.currency,
            requirementLabel = vendor.requirementLabel,
            expansion = vendor.expansion,
            sourceTag = sourceTag,
            sourceTags = {},
            items = {},
            locations = {},
            _itemKeys = {},
            _locationKeys = {},
        }
        grouped[key] = row
        results[#results + 1] = row
        created = true
    end
    row.sourceTags[sourceTag] = true
    row.currency = row.currency or vendor.currency
    row.requirementLabel = row.requirementLabel or vendor.requirementLabel
    row.expansion = row.expansion or vendor.expansion
    row.zone = row.zone ~= "Unknown Zone" and row.zone or vendor.zone
    row.cityName = row.cityName or vendor.cityName

    local locKey = vendorLocationKey(vendor.mapID, vendor.x, vendor.y, vendor.zone or vendor.cityName)
    if (vendor.mapID or vendor.x or vendor.y) and not row._locationKeys[locKey] then
        row._locationKeys[locKey] = true
        row.locations[#row.locations + 1] = {
            mapID = vendor.mapID,
            x = vendor.x,
            y = vendor.y,
            zone = vendor.zone,
            cityName = vendor.cityName,
            sourceTag = sourceTag,
        }
    end

    if not row.mapID and vendor.mapID then row.mapID = vendor.mapID end
    if not row.x and vendor.x then row.x = vendor.x end
    if not row.y and vendor.y then row.y = vendor.y end

    for _, rawItem in ipairs(vendor.items or {}) do
        local entry = normalizeItem(home, rawItem, sourceTag)
        local ikey = itemKey(entry)
        local existing = row._itemKeys[ikey]
        if type(existing) ~= "table" then
            row._itemKeys[ikey] = entry
            row.items[#row.items + 1] = entry
        else
            -- Same decor from another donor: fill in fields the surviving entry
            -- is missing (especially a real itemID — only some donors carry one,
            -- and collection/preview need it as a companion to the decorID).
            if not existing.itemID and entry.itemID then existing.itemID = entry.itemID end
            if not existing.decorID and entry.decorID then existing.decorID = entry.decorID end
            if not existing.requirementText and entry.requirementText then existing.requirementText = entry.requirementText end
            if not existing.mapID and entry.mapID then existing.mapID = entry.mapID end
            if not existing.x and entry.x then existing.x = entry.x end
            if not existing.y and entry.y then existing.y = entry.y end
            if entry.isCollected then existing.isCollected = true end
        end
    end
    return created
end

function NormalizedData:GetVendorsByProvider(providerTag, mapID, includeParentMaps)
    providerTag = tostring(providerTag or "")
    if providerTag == "" then
        return self:GetVendorList()
    end

    local currentMapID = tonumber(mapID)
    local results = {}
    for _, vendor in ipairs(self:GetVendorList()) do
        local hasProvider = false
        for _, tag in ipairs(vendor.sourceTags or {}) do
            if tag == providerTag then
                hasProvider = true
                break
            end
        end
        if hasProvider then
            if currentMapID then
                local matched = false
                local locations = vendor.locations or {}
                if #locations == 0 then
                    locations = { { mapID = vendor.mapID, x = vendor.x, y = vendor.y, zone = vendor.zone, cityName = vendor.cityName } }
                end
                for _, location in ipairs(locations) do
                    local vendorMapID = tonumber(location.mapID or vendor.mapID)
                    if vendorMapID and (vendorMapID == currentMapID or (includeParentMaps and MapContainsVendor(currentMapID, vendorMapID))) then
                        matched = true
                        break
                    end
                end
                if matched then
                    results[#results + 1] = vendor
                end
            else
                results[#results + 1] = vendor
            end
        end
    end
    return results
end

function NormalizedData:GetDomainEntries(domainKey)
    local getters = {
        achievements = self.GetAchievementEntries,
        quests = self.GetQuestEntries,
        drops = self.GetDropEntries,
        professions = self.GetProfessionEntries,
        pvp = self.GetPvPEntries,
        treasures = self.GetTreasureEntries,
        catalog = self.GetCatalogEntries,
        styles = self.GetStyleEntries,
        trainers = self.GetTrainerEntries,
        preview = self.GetPreviewEntries,
        materials = self.GetMaterialsEntries,
        reputation = self.GetReputationEntries,
        planning = self.GetPlanningEntries,
        statistics = self.GetStatisticsEntries,
    }
    local getter = getters[tostring(domainKey or "")]
    return getter and getter(self) or {}
end

function NormalizedData:GetDomainEntriesByProvider(domainKey, providerTag)
    providerTag = tostring(providerTag or "")
    if providerTag == "" then
        return self:GetDomainEntries(domainKey)
    end
    local results = {}
    for _, entry in ipairs(self:GetDomainEntries(domainKey)) do
        for _, tag in ipairs(entry.donorTags or {}) do
            if tag == providerTag then
                results[#results + 1] = entry
                break
            end
        end
    end
    return results
end

function NormalizedData:GetVendorList()
    if self._vendorList then
        return self._vendorList
    end

    local home = Providers["home"]
    local results, grouped = {}, {}
    local rawCount = 0
    local providerSet = {}

    if home and home.vendorCatalog then
        providerSet.villa = true
        local vendorBuckets = {}
        for itemID, source in pairs(home.vendorCatalog or {}) do
            local sourceKey = vendorIdentityKey(source.vendorName, source.zone, source.requirementLabel, source.npcID)
            vendorBuckets[sourceKey] = vendorBuckets[sourceKey] or {
                npcID = source.npcID,
                name = source.vendorName,
                zone = source.zone,
                mapID = source.mapID,
                x = source.x,
                y = source.y,
                cityName = source.cityName,
                currency = source.requirementLabel,
                requirementLabel = source.requirementLabel,
                items = {},
            }
            vendorBuckets[sourceKey].items[#vendorBuckets[sourceKey].items + 1] = {
                itemID = itemID,
                decorID = home.decorMeta and home.decorMeta[itemID] and home.decorMeta[itemID].decorID,
                sourceType = source.sourceType or "vendor",
                sourceLabel = "Vendor",
                requirementText = source.requirementLabel,
                zone = source.zone,
                cityName = source.cityName,
                mapID = source.mapID,
                x = source.x,
                y = source.y,
            }
        end
        for _, vendor in pairs(vendorBuckets) do
            rawCount = rawCount + 1
            ingestVendor(results, grouped, home, "villa", vendor)
        end
    end

    local codexZones = home and home.CodexVendorSourceData or nil
    local codexLocs = home and home.CodexNPCLocationData or nil
    if codexZones and codexLocs then
        providerSet.codex = true
        for expansionKey, zones in pairs(codexZones) do
            for zoneName, vendors in pairs(zones or {}) do
                for _, vendor in ipairs(vendors or {}) do
                    local locs = codexLocs[vendor.npcId]
                    local locList = nil
                    if type(locs) == "table" then
                        if type(locs[1]) == "table" then locList = locs else locList = { locs } end
                    end
                    if not locList then
                        locList = { { uiMapId = nil, x = nil, y = nil } }
                    end
                    for _, loc in ipairs(locList) do
                        rawCount = rawCount + 1
                        local items = {}
                        for _, decorID in ipairs(vendor.decorIds or {}) do
                            items[#items + 1] = {
                                decorID = decorID,
                                expansionKey = expansionKey,
                                requirementText = vendor.currencyName and (vendor.cost and (tostring(vendor.cost) .. " " .. vendor.currencyName) or vendor.currencyName) or (vendor.cost and tostring(vendor.cost) or nil),
                                zone = zoneName,
                                mapID = loc.uiMapId,
                                x = loc.x,
                                y = loc.y,
                            }
                        end
                        ingestVendor(results, grouped, home, "codex", {
                            npcID = vendor.npcId,
                            name = vendor.npcName,
                            zone = zoneName,
                            mapID = loc.uiMapId,
                            x = loc.x,
                            y = loc.y,
                            currency = vendor.currencyName,
                            requirementLabel = vendor.currencyName,
                            expansion = expansionKey,
                            items = items,
                        })
                    end
                end
            end
        end
    end

    local donorLists = {
        { key = "betterhomes", getter = function(p) return p.GetVendorList and p:GetVendorList() or {} end },
        { key = "hit", getter = function(p) return p.GetVendorList and p:GetVendorList() or {} end },
        { key = "decorvendor", getter = function(p) return p.GetVendorList and p:GetVendorList() or {} end },
        { key = "housingvendor", getter = function(p) return p.GetVendorList and p:GetVendorList() or {} end },
    }
    for _, def in ipairs(donorLists) do
        local provider = Providers[def.key]
        if provider then
            providerSet[def.key] = true
            for _, vendor in ipairs((provider and def.getter(provider)) or {}) do
                rawCount = rawCount + 1
                ingestVendor(results, grouped, home, def.key, vendor)
            end
        end
    end

    for _, vendor in ipairs(results) do
        vendor.sourceTags = sortedTags(vendor.sourceTags)
        vendor.sourceTag = (#vendor.sourceTags == 1 and vendor.sourceTags[1]) or "hybrid"
        vendor.providerCount = #vendor.sourceTags
        vendor.sourceSummary = table.concat(vendor.sourceTags, ", ")
        table.sort(vendor.items, function(a, b)
            return tostring(a.name or "") < tostring(b.name or "")
        end)
        table.sort(vendor.locations, function(a, b)
            if tonumber(a.mapID or 0) ~= tonumber(b.mapID or 0) then
                return tonumber(a.mapID or 0) < tonumber(b.mapID or 0)
            end
            if tonumber(a.x or 0) ~= tonumber(b.x or 0) then
                return tonumber(a.x or 0) < tonumber(b.x or 0)
            end
            return tonumber(a.y or 0) < tonumber(b.y or 0)
        end)
        vendor.locationCount = #(vendor.locations or {})
        local primary = vendor.locations[1]
        if primary then
            vendor.mapID = primary.mapID or vendor.mapID
            vendor.x = primary.x or vendor.x
            vendor.y = primary.y or vendor.y
            vendor.zone = primary.zone or vendor.zone
            vendor.cityName = primary.cityName or vendor.cityName
        end
        vendor._itemKeys = nil
        vendor._locationKeys = nil
    end

    table.sort(results, function(a, b)
        if (a.zone or "") ~= (b.zone or "") then
            return (a.zone or "") < (b.zone or "")
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    self:_recordAudit("vendors", rawCount, #results, providerSet)
    self._vendorList = results
    return results
end

local function domainSignature(entryType, title, subtitle, decorIds, extra)
    extra = extra or {}
    local sortedDecorIds = normalizeDecorIds(decorIds)
    local titleText = normalizeText(title)
    local subtitleText = normalizeText(subtitle)

    if entryType == "achievement" then
        return table.concat({ entryType, normalizeNumber(extra.achievementId), titleText, table.concat(sortedDecorIds, ",") }, "|")
    elseif entryType == "quest" then
        return table.concat({ entryType, normalizeNumber(extra.questId), titleText, subtitleText, table.concat(sortedDecorIds, ",") }, "|")
    elseif entryType == "drop" then
        return table.concat({ entryType, normalizeText(extra.sourceCategory), titleText, table.concat(sortedDecorIds, ",") }, "|")
    elseif entryType == "profession" then
        local recipeAnchor = normalizeNumber(extra.recipeId or extra.spellID or extra.itemID)
        if recipeAnchor == "" then
            recipeAnchor = table.concat({ titleText, normalizeText(extra.profession or extra.skillLine or ""), table.concat(sortedDecorIds, ",") }, "|")
        end
        return table.concat({ entryType, recipeAnchor, normalizeText(extra.profession or extra.skillLine or ""), titleText, normalizeNumber(extra.skillNeeded), table.concat(sortedDecorIds, ",") }, "|")
    elseif entryType == "pvp" then
        return table.concat({ entryType, normalizeNumber(extra.achievementId), titleText, subtitleText, table.concat(sortedDecorIds, ",") }, "|")
    end

    local keyish = extra.key or extra.id or extra.signature or extra.itemID or extra.decorID or extra.modelID or extra.displayID or extra.npcID or extra.factionID
    if keyish then
        return table.concat({ entryType, normalizeText(keyish), titleText, subtitleText }, "|")
    end

    if extra.mapID or extra.x or extra.y then
        return table.concat({ entryType, titleText, subtitleText, normalizeNumber(extra.mapID), normalizeCoord(extra.x), normalizeCoord(extra.y), table.concat(sortedDecorIds, ",") }, "|")
    end

    if #sortedDecorIds > 0 then
        return table.concat({ entryType, titleText, subtitleText, table.concat(sortedDecorIds, ",") }, "|")
    end

    return table.concat({ entryType, titleText, subtitleText }, "|")
end

local function mergeEntry(results, grouped, home, sourceTag, entryType, key, title, subtitle, detail, decorIds, extra)
    local gkey = domainSignature(entryType or "entry", title or "", subtitle or "", decorIds or {}, extra or {})
    local row = grouped[gkey]
    local created = false
    if not row then
        row = {
            entryType = entryType,
            key = key or gkey,
            title = title or "Unknown",
            subtitle = subtitle or "Unknown",
            detail = detail or "",
            decorIds = {},
            donorTags = {},
        }
        if type(extra) == "table" then
            for k, v in pairs(extra) do
                row[k] = v
            end
        end
        grouped[gkey] = row
        results[#results + 1] = row
        created = true
    end
    row.donorTags[sourceTag] = true
    mergeUniqueList(row.decorIds, decorIds or {})
    row.decorIds = normalizeDecorIds(row.decorIds)
    if not row.detail or row.detail == "" then
        row.detail = detail or ""
    elseif detail and detail ~= "" and not row.detail:find(detail, 1, true) then
        row.detail = string.format("%s\n%s", row.detail, detail)
    end
    return created
end

local function finalizeEntries(home, entries, formatter)
    for _, entry in ipairs(entries) do
        local owned, total = collectionSummary(home, entry.decorIds)
        entry.owned, entry.total = owned, total
        entry.donorTags = sortedTags(entry.donorTags)
        entry.sourceTag = (#entry.donorTags == 1 and entry.donorTags[1]) or "hybrid"
        entry.providerCount = #entry.donorTags
        entry.sourceSummary = table.concat(entry.donorTags or {}, ", ")
        entry.detail = formatter(entry, owned, total)
    end
    sortEntries(entries)
    return entries
end

local function harvestMaterialInfo(result, itemID, sourceTag, sourceInfo)
    if not itemID then
        return
    end
    local row = result[itemID]
    if not row then
        row = {
            itemID = itemID,
            sourceTags = {},
            usages = {},
            usageSet = {},
        }
        result[itemID] = row
    end
    row.sourceTags[sourceTag] = true
    if sourceInfo then
        row.name = row.name or sourceInfo.name
        row.source = row.source or sourceInfo.source
        row.price = row.price or sourceInfo.price
    end
end

local function addUsageName(row, usageName)
    usageName = tostring(usageName or "")
    if usageName ~= "" and not row.usageSet[usageName] then
        row.usageSet[usageName] = true
        row.usages[#row.usages + 1] = usageName
    end
end

function NormalizedData:GetMaterialInfo(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end
    if not self._materialInfoByItem then
        local index = {}
        local hv = Providers["housingvendor"]
        if hv and hv.GetMaterialInfo then
            for _, entry in ipairs(hv:GetMaterialsEntries() or {}) do
                harvestMaterialInfo(index, tonumber(entry.itemID or entry.materialID or entry.key), "housingvendor", hv:GetMaterialInfo(entry.itemID or entry.materialID or entry.key))
            end
        end
        local hit = Providers["hit"]
        if hit then
            for materialID in pairs(hit.Materials or {}) do
                harvestMaterialInfo(index, tonumber(materialID), "hit", nil)
            end
            for materialID in pairs(hit.ManualMaterials or {}) do
                harvestMaterialInfo(index, tonumber(materialID), "hit", nil)
            end
            for materialID, row in pairs(index) do
                if row.sourceTags.hit then
                    for _, usageName in ipairs(hit:GetUsageNames(materialID, 12) or {}) do
                        addUsageName(row, usageName)
                    end
                end
            end
        end
        for _, row in pairs(index) do
            table.sort(row.usages)
            row.sourceTags = sortedTags(row.sourceTags)
            row.sourceSummary = table.concat(row.sourceTags, ", ")
        end
        self._materialInfoByItem = index
    end
    return self._materialInfoByItem[itemID]
end


function NormalizedData:GetAchievementEntries()
    if self._achievementEntries then return self._achievementEntries end
    local home = Providers["home"]
    local entries, grouped = {}, {}
    local rawCount = 0
    local providerSet = {}
    local codex = Providers["codex"]
    for achievementId, info in pairs((codex and codex.AchievementSourceData) or {}) do
        providerSet.codex = true
        rawCount = rawCount + 1
        mergeEntry(entries, grouped, home, "codex", "achievement", tostring(achievementId), info.achievementName or ("Achievement #" .. tostring(achievementId)), info.category or "Unknown", "", info.decorIds or {}, { achievementId = achievementId })
    end
    for _, def in ipairs({
        { tag = "decorvendor", getter = function(p) return p.GetAchievementEntries and p:GetAchievementEntries() or {} end },
        { tag = "hit", getter = function(p) return p.GetAchievementEntries and p:GetAchievementEntries() or {} end },
    }) do
        local provider = Providers[def.tag]
        if provider then
            providerSet[def.tag] = true
            for _, entry in ipairs((provider and def.getter(provider)) or {}) do
                rawCount = rawCount + 1
                mergeEntry(entries, grouped, home, def.tag, "achievement", entry.key, entry.title, entry.subtitle, entry.detail, entry.decorIds or {}, { achievementId = entry.achievementId or entry.achievementID or tonumber(entry.key), key = entry.key, modelID = entry.model3D, itemID = entry.itemID })
            end
        end
    end
    self._achievementEntries = finalizeEntries(home, entries, function(entry, owned, total)
        return string.format("Category: %s\nDecor IDs: %s\nCollection: %d/%d\nSources: %s", tostring(entry.subtitle or "Unknown"), buildDecorText(entry.decorIds), owned, total, table.concat(entry.donorTags or {}, ", "))
    end)
    self:_recordAudit("achievements", rawCount, #self._achievementEntries, providerSet)
    return self._achievementEntries
end

function NormalizedData:GetQuestEntries()
    if self._questEntries then return self._questEntries end
    local home = Providers["home"]
    local entries, grouped = {}, {}
    local rawCount = 0
    local providerSet = {}
    local codex = Providers["codex"]
    for zoneName, quests in pairs((codex and codex.QuestSourceData) or {}) do
        providerSet.codex = true
        for _, quest in ipairs(quests or {}) do
            rawCount = rawCount + 1
            mergeEntry(entries, grouped, home, "codex", "quest", tostring(quest.questId or quest.questName), quest.questName or "Unknown Quest", zoneName, "", quest.decorIds or {}, { questId = quest.questId })
        end
    end
    for _, def in ipairs({
        { tag = "decorvendor", getter = function(p) return p.GetQuestEntries and p:GetQuestEntries() or {} end },
        { tag = "hit", getter = function(p) return p.GetQuestEntries and p:GetQuestEntries() or {} end },
    }) do
        local provider = Providers[def.tag]
        if provider then
            providerSet[def.tag] = true
            for _, entry in ipairs((provider and def.getter(provider)) or {}) do
                rawCount = rawCount + 1
                mergeEntry(entries, grouped, home, def.tag, "quest", entry.key, entry.title, entry.subtitle, entry.detail, entry.decorIds or {}, { questId = entry.questId or entry.questID or tonumber(entry.key), key = entry.key, itemID = entry.rewardItemID or entry.itemID, modelID = entry.model3D })
            end
        end
    end
    self._questEntries = finalizeEntries(home, entries, function(entry, owned, total)
        return string.format("Zone: %s\nDecor IDs: %s\nCollection: %d/%d\nSources: %s", tostring(entry.subtitle or "Unknown"), buildDecorText(entry.decorIds), owned, total, table.concat(entry.donorTags or {}, ", "))
    end)
    self:_recordAudit("quests", rawCount, #self._questEntries, providerSet)
    return self._questEntries
end

function NormalizedData:GetDropEntries()
    if self._dropEntries then return self._dropEntries end
    local home = Providers["home"]
    local entries, grouped = {}, {}
    local rawCount = 0
    local providerSet = {}
    local codex = Providers["codex"]
    for category, sources in pairs((codex and codex.DropSourceData) or {}) do
        providerSet.codex = true
        for _, source in ipairs(sources or {}) do
            rawCount = rawCount + 1
            mergeEntry(entries, grouped, home, "codex", "drop", tostring(category) .. ":" .. tostring(source.sourceName), source.sourceName or "Unknown Drop Source", tostring(category):gsub("^%l", string.upper), "", source.decorIds or {}, { sourceCategory = category, key = source.sourceName })
        end
    end
    self._dropEntries = finalizeEntries(home, entries, function(entry, owned, total)
        return string.format("Category: %s\nDecor IDs: %s\nCollection: %d/%d\nSources: %s", tostring(entry.subtitle or "Unknown"), buildDecorText(entry.decorIds), owned, total, table.concat(entry.donorTags or {}, ", "))
    end)
    self:_recordAudit("drops", rawCount, #self._dropEntries, providerSet)
    return self._dropEntries
end

function NormalizedData:GetProfessionEntries()
    if self._professionEntries then return self._professionEntries end
    local home = Providers["home"]
    local entries, grouped = {}, {}
    local rawCount = 0
    local providerSet = {}
    local codex = Providers["codex"]
    for professionName, crafts in pairs((codex and codex.CraftingSourceData) or {}) do
        providerSet.codex = true
        local buckets = {}
        for _, craft in ipairs(crafts or {}) do
            local key = string.format("%s|%s|%s", professionName, tostring(craft.skillLine or professionName), tostring(craft.recipeName or professionName))
            buckets[key] = buckets[key] or {
                key = key,
                title = craft.recipeName or professionName,
                subtitle = string.format("%s • %s", professionName, tostring(craft.skillLine or professionName)),
                decorIds = {},
                recipeId = craft.recipeId,
                skillNeeded = craft.skillNeeded,
            }
            if craft.decorId then
                buckets[key].decorIds[#buckets[key].decorIds + 1] = craft.decorId
            end
        end
        for _, bucket in pairs(buckets) do
            rawCount = rawCount + 1
            mergeEntry(entries, grouped, home, "codex", "profession", bucket.key, bucket.title, bucket.subtitle, "", bucket.decorIds, { recipeId = bucket.recipeId, skillNeeded = bucket.skillNeeded, key = bucket.key })
        end
    end
    for _, def in ipairs({
        { tag = "betterhomes", getter = function(p) return p.GetProfessionEntries and p:GetProfessionEntries() or {} end },
        { tag = "decorvendor", getter = function(p) return p.GetProfessionEntries and p:GetProfessionEntries() or {} end },
        { tag = "hit", getter = function(p) return p.GetProfessionEntries and p:GetProfessionEntries() or {} end },
        { tag = "housingvendor", getter = function(p) return p.GetProfessionEntries and p:GetProfessionEntries() or {} end },
    }) do
        local provider = Providers[def.tag]
        if provider then
            providerSet[def.tag] = true
            for _, entry in ipairs((provider and def.getter(provider)) or {}) do
                rawCount = rawCount + 1
                mergeEntry(entries, grouped, home, def.tag, "profession", entry.key, entry.title, entry.subtitle, entry.detail, entry.decorIds or {}, { recipeId = entry.recipeId or entry.spellID or entry.itemID, spellID = entry.spellID, itemID = entry.itemID, profession = entry.profession, skillLine = entry.skillLine, skillNeeded = entry.skillNeeded, key = entry.key })
            end
        end
    end
    self._professionEntries = finalizeEntries(home, entries, function(entry, owned, total)
        return string.format("Skill needed: %s\nDecor IDs: %s\nCollection: %d/%d\nSources: %s", tostring(entry.skillNeeded or "n/a"), buildDecorText(entry.decorIds), owned, total, table.concat(entry.donorTags or {}, ", "))
    end)
    self:_recordAudit("professions", rawCount, #self._professionEntries, providerSet)
    return self._professionEntries
end

function NormalizedData:GetPvPEntries()
    if self._pvpEntries then return self._pvpEntries end
    local entries, grouped = {}, {}
    local providerSet, rawCount = {}, 0
    for _, info in ipairs(self:GetAchievementEntries()) do
        if info.subtitle == "PvP" then
            providerSet.achievements = true
            rawCount = rawCount + 1
            mergeEntry(entries, grouped, Providers["home"], info.sourceTag or "hybrid", "pvp", info.key, info.title, "Achievements", info.detail, info.decorIds or {}, { achievementId = info.achievementId, key = info.key })
        end
    end
    for _, drop in ipairs(self:GetDropEntries()) do
        local title = drop.title or ""
        for _, kw in ipairs({ "Arena", "Battleground", "War", "Combatant", "Marshal", "Gladiator" }) do
            if title:find(kw, 1, true) then
                providerSet.drops = true
                rawCount = rawCount + 1
                mergeEntry(entries, grouped, Providers["home"], drop.sourceTag or "hybrid", "pvp", drop.key, drop.title, "Drops", drop.detail, drop.decorIds or {}, { key = drop.key })
                break
            end
        end
    end
    self._pvpEntries = finalizeEntries(Providers["home"], entries, function(entry, owned, total)
        return string.format("Group: %s\nDecor IDs: %s\nCollection: %d/%d\nSources: %s", tostring(entry.subtitle or "Unknown"), buildDecorText(entry.decorIds), owned, total, table.concat(entry.donorTags or {}, ", "))
    end)
    self:_recordAudit("pvp", rawCount, #self._pvpEntries, providerSet)
    return self._pvpEntries
end

local function genericSignature(entryType, entry)
    local title = entry.title or entry.label or ""
    local subtitle = entry.subtitle or entry.detail or ""
    local extra = {
        key = entry.key,
        id = entry.id,
        itemID = entry.itemID,
        decorID = entry.decorID,
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
        npcID = entry.npcID,
        factionID = entry.factionID,
        modelID = entry.modelID,
        displayID = entry.displayID,
        signature = entry.signature,
    }
    if entryType == "trainer" then
        return table.concat({
            entryType,
            normalizeNumber(entry.npcID),
            normalizeText(title),
            normalizeNumber(entry.mapID),
            normalizeCoord(entry.x),
            normalizeCoord(entry.y),
        }, "|")
    elseif entryType == "material" then
        return table.concat({
            entryType,
            normalizeNumber(entry.itemID or entry.materialID or entry.decorID),
            normalizeText(title),
            normalizeText(entry.sourceType or entry.sourceLabel or subtitle),
        }, "|")
    elseif entryType == "preview" then
        return table.concat({
            entryType,
            normalizeNumber(entry.itemID or entry.modelID or entry.displayID or entry.decorID),
            normalizeText(title),
        }, "|")
    end
    return domainSignature(entryType, title, subtitle, entry.decorIds or {}, extra)
end

local function mergeSimpleDomain(cacheField, domain, sourceDefs)
    return function(self)
        if self[cacheField] then return self[cacheField] end
        local results, grouped = {}, {}
        local rawCount, providerSet = 0, {}
        for _, def in ipairs(sourceDefs) do
            local provider = Providers[def.tag]
            if provider then
                providerSet[def.tag] = true
                for _, entry in ipairs((provider and def.getter(provider)) or {}) do
                    rawCount = rawCount + 1
                    local extra = shallowCopy(entry)
                    extra.signature = genericSignature(def.entryType, entry)
                    mergeEntry(results, grouped, Providers["home"], def.tag, def.entryType, entry.key, entry.title or entry.label, entry.subtitle or entry.detail or "", entry.detail, entry.decorIds or {}, extra)
                end
            end
        end
        for _, entry in ipairs(results) do
            entry.donorTags = sortedTags(entry.donorTags)
            entry.sourceTag = (#entry.donorTags == 1 and entry.donorTags[1]) or "hybrid"
            entry.providerCount = #entry.donorTags
            entry.sourceSummary = table.concat(entry.donorTags or {}, ", ")
            if not entry.detail or entry.detail == "" then
                entry.detail = string.format("Sources: %s", entry.sourceSummary)
            elseif not entry.detail:find("Sources:", 1, true) then
                entry.detail = string.format("%s\nSources: %s", entry.detail, entry.sourceSummary)
            end
        end
        sortEntries(results)
        self:_recordAudit(domain, rawCount, #results, providerSet)
        self[cacheField] = results
        return results
    end
end

NormalizedData.GetTreasureEntries = mergeSimpleDomain("_treasureEntries", "treasures", {
    { tag = "betterhomes", entryType = "treasure", getter = function(p) return p.GetTreasureEntries and p:GetTreasureEntries() or {} end },
})
NormalizedData.GetCatalogEntries = mergeSimpleDomain("_catalogEntries", "catalog", {
    { tag = "hdg", entryType = "catalog", getter = function(p) return p.GetCatalogEntries and p:GetCatalogEntries() or {} end },
})
NormalizedData.GetStyleEntries = mergeSimpleDomain("_styleEntries", "styles", {
    { tag = "hdg", entryType = "style", getter = function(p) return p.GetStyleEntries and p:GetStyleEntries() or {} end },
})
NormalizedData.GetTrainerEntries = mergeSimpleDomain("_trainerEntries", "trainers", {
    { tag = "hdg", entryType = "trainer", getter = function(p) return p.GetTrainerEntries and p:GetTrainerEntries() or {} end },
    { tag = "housingvendor", entryType = "trainer", getter = function(p) return p.GetTrainerEntries and p:GetTrainerEntries() or {} end },
})
function NormalizedData:GetPreviewEntries()
    if self._previewEntries then return self._previewEntries end
    local results, grouped = {}, {}
    local rawCount, providerSet = 0, {}

    local function mergePreview(sourceTag, entry)
        rawCount = rawCount + 1
        providerSet[sourceTag] = true
        entry = shallowCopy(entry or {})
        local itemID = tonumber(entry.itemID or entry.decorID or entry.key)
        local modelID = tonumber(entry.modelID or entry.displayID)
        local signature = table.concat({
            "preview",
            normalizeNumber(itemID or modelID),
            normalizeText(entry.title or entry.name or ("Item " .. tostring(itemID or modelID or "?"))),
        }, "|")
        local row = grouped[signature]
        if not row then
            row = {
                entryType = "preview",
                key = tostring(itemID or modelID or signature),
                itemID = itemID,
                modelID = modelID,
                title = entry.title or entry.name or ("Item " .. tostring(itemID or modelID or "?")),
                subtitle = entry.subtitle or "Preview data",
                detail = entry.detail or "",
                decorIds = normalizeDecorIds(entry.decorIds or { entry.decorID or itemID }),
                donorTags = {},
            }
            grouped[signature] = row
            results[#results + 1] = row
        end
        row.donorTags[sourceTag] = true
        if entry.detail and entry.detail ~= "" and not row.detail:find(entry.detail, 1, true) then
            row.detail = row.detail ~= "" and (row.detail .. "\n" .. entry.detail) or entry.detail
        end
        mergeUniqueList(row.decorIds, entry.decorIds or { entry.decorID or itemID })
        if not row.modelID and modelID then row.modelID = modelID end
        if not row.itemID and itemID then row.itemID = itemID end
    end

    local hv = Providers["housingvendor"]
    if hv then
        for _, entry in ipairs((hv.GetPreviewEntries and hv:GetPreviewEntries()) or {}) do
            mergePreview("housingvendor", entry)
        end
        for itemID, pos in pairs(hv.ModelPositions or {}) do
            mergePreview("housingvendor", {
                itemID = tonumber(itemID),
                title = "Item " .. tostring(itemID),
                subtitle = "HousingVendor model position",
                detail = string.format("HousingVendor model position. zoom=%s camera_y=%s model_x=%s model_z=%s", tostring(pos.zoom or "n/a"), tostring(pos.cameraY or pos.camera_y or "n/a"), tostring(pos.modelX or pos.model_x or "n/a"), tostring(pos.modelZ or pos.model_z or "n/a")),
                decorIds = { tonumber(itemID) },
            })
        end
    end

    local dv = Providers["decorvendor"]
    if dv and dv.ModelPositions then
        for modelID, pos in pairs(dv.ModelPositions or {}) do
            mergePreview("decorvendor", {
                modelID = tonumber(modelID),
                title = "Model " .. tostring(modelID),
                subtitle = "DecorVendor model position",
                detail = string.format("DecorVendor model position. zoom=%s camera_y=%s model_x=%s model_z=%s", tostring(pos.zoom or "n/a"), tostring(pos.camera_y or pos.cameraY or "n/a"), tostring(pos.model_x or pos.modelX or "n/a"), tostring(pos.model_z or pos.modelZ or "n/a")),
                decorIds = {},
            })
        end
    end

    self._previewEntries = finalizeEntries(Providers["home"], results, function(entry, owned, total)
        local base = (entry.detail and entry.detail ~= "") and entry.detail or "Preview/model tuning record."
        return string.format("%s\nCollection: %d/%d\nSources: %s", base, owned, total, table.concat(entry.donorTags or {}, ", "))
    end)
    self:_recordAudit("preview", rawCount, #self._previewEntries, providerSet)
    return self._previewEntries
end

function NormalizedData:GetMaterialsEntries()
    if self._materialEntries then return self._materialEntries end
    local results, grouped = {}, {}
    local rawCount, providerSet = 0, {}

    local hv = Providers["housingvendor"]
    if hv then
        providerSet.housingvendor = true
        for _, entry in ipairs((hv.GetMaterialsEntries and hv:GetMaterialsEntries()) or {}) do
            rawCount = rawCount + 1
            local extra = shallowCopy(entry)
            extra.signature = genericSignature("material", entry)
            mergeEntry(results, grouped, Providers["home"], "housingvendor", "material", entry.key, entry.title or entry.label, entry.subtitle or entry.detail or "", entry.detail, entry.decorIds or { entry.itemID }, extra)
        end
    end

    local hit = Providers["hit"]
    if hit then
        providerSet.hit = true
        local seen = {}
        for materialID in pairs(hit.Materials or {}) do
            seen[tonumber(materialID)] = true
        end
        for materialID in pairs(hit.ManualMaterials or {}) do
            seen[tonumber(materialID)] = true
        end
        for materialID in pairs(seen) do
            rawCount = rawCount + 1
            local usageNames = hit:GetUsageNames(materialID, 6) or {}
            local usageSummary = (#usageNames > 0) and table.concat(usageNames, ", ") or "Housing recipe material"
            local entry = {
                key = tostring(materialID),
                itemID = materialID,
                title = "Item " .. tostring(materialID),
                subtitle = "HousingItemTracker",
                detail = "Used in housing recipes: " .. usageSummary,
                sourceType = "housing recipes",
                decorIds = { materialID },
            }
            local extra = shallowCopy(entry)
            extra.signature = genericSignature("material", entry)
            mergeEntry(results, grouped, Providers["home"], "hit", "material", entry.key, entry.title, entry.subtitle, entry.detail, entry.decorIds, extra)
        end
    end

    self._materialEntries = finalizeEntries(Providers["home"], results, function(entry, owned, total)
        local itemID = tonumber(entry.itemID or entry.materialID or entry.key)
        local materialInfo = self:GetMaterialInfo(itemID)
        local lines = {}
        if entry.detail and entry.detail ~= "" then
            lines[#lines + 1] = entry.detail
        end
        if materialInfo then
            if materialInfo.source and materialInfo.source ~= "" then
                lines[#lines + 1] = "Source: " .. tostring(materialInfo.source)
            end
            if materialInfo.price then
                lines[#lines + 1] = "Base vendor price: " .. tostring(materialInfo.price) .. "c"
            end
            if materialInfo.usages and #materialInfo.usages > 0 then
                lines[#lines + 1] = "Used by: " .. table.concat(materialInfo.usages, ", ")
            end
        end
        lines[#lines + 1] = string.format("Collection: %d/%d", owned, total)
        lines[#lines + 1] = "Sources: " .. table.concat(entry.donorTags or {}, ", ")
        return table.concat(lines, "\n")
    end)
    self:_recordAudit("materials", rawCount, #self._materialEntries, providerSet)
    return self._materialEntries
end
-- The codex donor (FabledUI_DataVault_Villa/RenownData.lua) is the only one of
-- the two carrying real reward item IDs, per-reward standings and vendor map
-- coordinates; housingvendor carries decorIds and richer display strings. They
-- merge by faction key, so a faction present in both ends up with both.
--
-- Note the load-order asymmetry: this file lives in the LoadOnDemand catalog
-- shard, RenownData.lua in the always-loaded one, so Providers["codex"] is
-- already populated by the time this runs.
NormalizedData.GetReputationEntries = mergeSimpleDomain("_reputationEntries", "reputation", {
    { tag = "housingvendor", entryType = "reputation", getter = function(p) return p.GetReputationEntries and p:GetReputationEntries() or {} end },
    { tag = "codex", entryType = "reputation", getter = function(p) return p.GetReputationEntries and p:GetReputationEntries() or {} end },
})
NormalizedData.GetPlanningEntries = mergeSimpleDomain("_planningEntries", "planning", {
    { tag = "housingvendor", entryType = "planning", getter = function(p) return p.GetPlanningEntries and p:GetPlanningEntries() or {} end },
})
function NormalizedData:GetStatisticsEntries()
    if self._statisticsEntries then
        return self._statisticsEntries
    end

    local results = {}
    local providerSet = { normalized = true }
    local rawCount = 0

    for _, row in ipairs(self:GetDuplicateMatrix()) do
        rawCount = rawCount + 1
        results[#results + 1] = {
            entryType = "statistics",
            key = "dedup:" .. tostring(row.domain),
            title = row.label,
            subtitle = "Dedup Audit",
            detail = row.detail,
            donorTags = { "normalized" },
            sourceTag = "normalized",
            providerCount = #(row.providers or {}),
            sourceSummary = row.providerSummary,
        }
    end

    local hv = Providers["housingvendor"]
    for _, entry in ipairs((hv and hv.GetStatisticsEntries and hv:GetStatisticsEntries()) or {}) do
        rawCount = rawCount + 1
        providerSet.housingvendor = true
        local copy = shallowCopy(entry)
        copy.entryType = copy.entryType or "statistics"
        copy.sourceTag = copy.sourceTag or "housingvendor"
        copy.sourceSummary = copy.sourceSummary or "housingvendor"
        results[#results + 1] = copy
    end

    sortEntries(results)
    self:_recordAudit("statistics", rawCount, #results, providerSet)
    self._statisticsEntries = results
    return results
end

function NormalizedData:GetProviderStats()
    if self._providerStats then
        return self._providerStats
    end
    local stats = {}
    for _, row in ipairs(self:GetDuplicateMatrix()) do
        stats[row.domain] = row.normalizedCount
        stats[row.domain .. "Raw"] = row.rawCount
        stats[row.domain .. "Duplicates"] = row.duplicateCount
    end
    self._providerStats = stats
    return stats
end
