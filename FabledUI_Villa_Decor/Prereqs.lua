-- What stands between you and buying a decor item, and whether you have
-- already cleared it.
--
-- The catalog's sourceText says who sells a thing and for how much. It does NOT
-- say the vendor is Horde-only, and it under-reports gates: the owner's first
-- list (2026-09-21, an Alliance character, "hide gated" ticked) still showed
-- Tauren Bluff Rug from Brave Tuho in Mulgore, Blightfire Candle from a
-- Sunreaver vendor in Dalaran, and Glorious Pendant of Rukhmar, which needs the
-- achievement Secrets of Skettis. None of that is in the game's text.
--
-- So requirements come from two places and are then checked LIVE:
--
--   sourceText      quest / achievement names (no ids)
--   DataVault_Villa faction of a vendor, by name       (home shard, always loaded)
--                   reputation / renown by item        (RenownData, always loaded)
--                   quest + achievement IDS by decorID (HIT, LoadOnDemand shard)
--                   reputation by decorID              (HousingVendor, LoD shard)
--                   race-locked vendors                (DecorVendor, LoD shard)
--
-- A quest or achievement named anywhere in an item's sources is treated as a
-- prerequisite for buying it. 0.1.x read one in its own block as "another way
-- to get it" and did not count it as a gate. For first-acquisition XP that was
-- the wrong reading: either way the quest has to be done, and if it is ALREADY
-- done -- very common for old quests -- the vendor simply sells it. That is
-- what the live check is for.
--
-- Every requirement ends up "met", "unmet" or "unknown". Unknown is honest:
-- imported data with no id to check, or a standing label this file cannot rank.
-- The imported data is months old; the live checks are not.

local Decor = _G.FabledUI_VillaDecor
if not Decor then return end

local Prereqs = {}
Decor.Prereqs = Prereqs

local issecretvalue = _G.issecretvalue or function() return false end

local function usableString(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

-- -----------------------------------------------------------------------------
-- Live checks (API seam; tests replace these). true / false / nil = unknown.
-- Defined on the table here, but always CALLED as Decor.Api.X at the point of
-- use: tests swap Decor.Api for a copy, and a local captured at load would go
-- on calling the real client behind their back.
-- -----------------------------------------------------------------------------

local Api = Decor.Api

Api.QuestDone = function(questID)
    if type(questID) ~= "number" or questID <= 0 or not C_QuestLog then return nil end
    -- Warband-wide first: a quest done on any character has unlocked the vendor.
    for _, name in ipairs({ "IsQuestFlaggedCompletedOnAccount", "IsQuestFlaggedCompleted" }) do
        local fn = C_QuestLog[name]
        if type(fn) == "function" then
            local ok, done = pcall(fn, questID)
            if ok and done then return true end
            if ok and name == "IsQuestFlaggedCompleted" then return false end
        end
    end
    return nil
end

Api.AchievementDone = function(achievementID)
    if type(achievementID) ~= "number" or achievementID <= 0 then return nil end
    local fn = rawget(_G, "GetAchievementInfo")
    if type(fn) ~= "function" then return nil end
    local ok, id, _, _, completed = pcall(fn, achievementID)
    if not ok or id == nil then return nil end
    return completed and true or false
end

-- Standard reputation reaction, 1 (Hated) .. 8 (Exalted).
Api.FactionReaction = function(factionID)
    if not (C_Reputation and C_Reputation.GetFactionDataByID) then return nil end
    local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
    if ok and type(data) == "table" and type(data.reaction) == "number" then
        return data.reaction
    end
    return nil
end

Api.RenownLevel = function(factionID)
    if not (C_MajorFactions and C_MajorFactions.GetMajorFactionData) then return nil end
    local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
    if ok and type(data) == "table" and type(data.renownLevel) == "number" then
        return data.renownLevel
    end
    return nil
end

-- Returns rankText, rankNumber for a friendship faction.
Api.Friendship = function(factionID)
    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then return nil end
    local ok, data = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
    if not ok or type(data) ~= "table" or (tonumber(data.friendshipFactionID) or 0) == 0 then return nil end
    local level
    if C_GossipInfo.GetFriendshipReputationRanks then
        local okRanks, ranks = pcall(C_GossipInfo.GetFriendshipReputationRanks, factionID)
        if okRanks and type(ranks) == "table" then level = tonumber(ranks.currentLevel) end
    end
    return usableString(data.reaction), level
end

-- -----------------------------------------------------------------------------
-- Indexes over the imported data
-- -----------------------------------------------------------------------------

local STANDING_RANK = {
    hated = 1, hostile = 2, unfriendly = 3, neutral = 4,
    friendly = 5, honored = 6, revered = 7, exalted = 8,
}

function Prereqs:Reset()
    self._built = false
    self._vendorFaction = {}   -- lower(name) -> { alliance = bool, horde = bool }
    self._vendorNote = {}      -- lower(name) -> race-lock note
    self._repByItem = {}       -- itemID  -> { factionID, factionName, standing, kind }
    self._repByDecor = {}      -- decorID -> same
    self._factionByName = {}   -- lower(faction name) -> { factionID, kind }
    self._hitByDecor = nil     -- HIT DecorItems table, when the shard is loaded
end
Prereqs:Reset()

local function noteFaction(map, name, faction)
    name, faction = usableString(name), usableString(faction)
    if not name or not faction then return end
    faction = faction:lower()
    -- Only an explicit side is evidence. "neutral" in the donor files is as
    -- often a default as a fact, so it proves nothing either way.
    if faction ~= "alliance" and faction ~= "horde" then return end
    local key = name:lower()
    map[key] = map[key] or {}
    map[key][faction] = true
end

function Prereqs:Build()
    if self._built then return end
    self._built = true

    -- The LoadOnDemand shard carries the quest/achievement ids. Several MB of
    -- Lua, pulled in the first time the window is opened and not before.
    Decor.Api.LoadCatalogShard()
    local providers = Decor.Api.Providers()
    if type(providers) ~= "table" then return end

    local home = providers["home"]
    if type(home) == "table" and type(home.CodexVendorSourceData) == "table"
        and type(home.CodexNPCLocationData) == "table" then
        for _, zones in pairs(home.CodexVendorSourceData) do
            for _, vendors in pairs(zones) do
                for _, vendor in ipairs(vendors) do
                    local loc = home.CodexNPCLocationData[vendor.npcId]
                    if type(loc) == "table" then
                        local list = loc.uiMapId and { loc } or loc
                        for _, one in ipairs(list) do
                            noteFaction(self._vendorFaction, vendor.npcName, one.faction)
                        end
                    end
                end
            end
        end
    end

    local decorVendor = providers["decorvendor"]
    if type(decorVendor) == "table" and type(decorVendor.Vendors) == "table" then
        for _, vendor in ipairs(decorVendor.Vendors) do
            noteFaction(self._vendorFaction, vendor.name, vendor.requirementLabel)
            -- DecorVendor files race-locked vendors under currency "Race Locked"
            -- and puts the rule where the zone should be ("Must be Gnome or Dwarf").
            if vendor.currency == "Race Locked" and usableString(vendor.name) and usableString(vendor.zone) then
                self._vendorNote[vendor.name:lower()] = vendor.zone
            end
        end
    end

    local betterHomes = providers["betterhomes"]
    if type(betterHomes) == "table" and type(betterHomes.VendorData) == "table" then
        for _, vendor in ipairs(betterHomes.VendorData) do
            noteFaction(self._vendorFaction, vendor.name, vendor.faction)
        end
    end

    local codex = providers["codex"]
    local renown = type(codex) == "table" and codex.Renown or nil
    if type(renown) == "table" then
        for factionID, faction in pairs(renown) do
            if type(factionID) == "number" and type(faction) == "table" and type(faction.rewards) == "table" then
                if usableString(faction.label) then
                    self._factionByName[faction.label:lower()] = { factionID = factionID, kind = usableString(faction.kind) or "standard" }
                end
                for _, reward in ipairs(faction.rewards) do
                    local entry = {
                        factionID = factionID,
                        factionName = usableString(faction.label) or ("Faction " .. factionID),
                        standing = usableString(reward.requiredStanding),
                        kind = usableString(faction.kind) or "standard",
                    }
                    if entry.standing then
                        if tonumber(reward.itemId) and reward.itemId > 0 then self._repByItem[reward.itemId] = entry end
                        if tonumber(reward.decorId) and reward.decorId > 0 then self._repByDecor[reward.decorId] = entry end
                    end
                end
            end
        end
    end

    local housingVendor = providers["housingvendor"]
    if type(housingVendor) == "table" and type(housingVendor.ReputationVendors) == "table" then
        for _, vendor in ipairs(housingVendor.ReputationVendors) do
            for _, item in ipairs(type(vendor.items) == "table" and vendor.items or {}) do
                local standing = usableString(item.reputation)
                if tonumber(item.factionID) and usableString(item.factionName) then
                    local key = item.factionName:lower()
                    self._factionByName[key] = self._factionByName[key] or { factionID = item.factionID, kind = "standard" }
                end
                if standing and tonumber(item.factionID) then
                    local entry = {
                        factionID = item.factionID,
                        factionName = usableString(item.factionName) or ("Faction " .. item.factionID),
                        standing = standing,
                        kind = standing:match("^Renown%s+%d+") and "renown" or "standard",
                    }
                    -- RenownData is the newer import; do not overwrite it.
                    if tonumber(item.itemID) and not self._repByItem[item.itemID] then self._repByItem[item.itemID] = entry end
                    if tonumber(item.decorID) and not self._repByDecor[item.decorID] then self._repByDecor[item.decorID] = entry end
                end
            end
        end
    end

    local hit = providers["hit"]
    if type(hit) == "table" and type(hit.DecorItems) == "table" then
        self._hitByDecor = hit.DecorItems
    end
end

-- The imported per-decor record (quest/achievement ids, profession, materials),
-- or nil. Shared with Villa_Tooltip so the shard is indexed once.
function Prereqs:ItemRecord(decorID)
    self:Build()
    local hit = self._hitByDecor and decorID and self._hitByDecor[decorID]
    return type(hit) == "table" and hit or nil
end

-- "Alliance", "Horde", or nil when the vendor sells to both / nothing is known.
function Prereqs:VendorFaction(name)
    name = usableString(name)
    if not name then return nil end
    local seen = self._vendorFaction[name:lower()]
    if not seen then return nil end
    if seen.alliance and not seen.horde then return "Alliance" end
    if seen.horde and not seen.alliance then return "Horde" end
    return nil
end

function Prereqs:IsWrongFaction(vendor, playerFaction)
    local faction = self:VendorFaction(vendor and vendor.name)
    return faction ~= nil and playerFaction ~= nil and faction ~= playerFaction
end

-- -----------------------------------------------------------------------------
-- Checking
-- -----------------------------------------------------------------------------

local function status(done)
    if done == true then return "met" end
    if done == false then return "unmet" end
    return "unknown"
end

-- "Proudmoore Admiralty - Friendly" or "Ritual Sites Rank 3" -> a reputation
-- entry, with the faction id looked up by name in the imported data. No id on
-- file means the standing can still be shown but not checked.
function Prereqs:ParseTextReputation(text)
    self:Build()
    local name, standing = text:match("^(.-)%s+%-%s+(.+)$")
    if not name then
        name, standing = text:match("^(.-)%s+(Rank%s+%d+)$")
    end
    if not name then
        name, standing = text:match("^(.-)%s+(Renown%s+%d+)$")
    end
    if not name or not standing then return nil end
    local known = self._factionByName[name:lower()]
    return {
        factionID = known and known.factionID or nil,
        factionName = name,
        standing = standing,
        kind = known and known.kind or (standing:match("^Renown") and "renown" or "standard"),
    }
end

function Prereqs:CheckReputation(entry)
    if not entry.factionID then return "unknown" end
    local standing = entry.standing
    local renown = tonumber(standing:match("^Renown%s+(%d+)"))
    if renown then
        local level = Decor.Api.RenownLevel(entry.factionID)
        return level and status(level >= renown) or "unknown"
    end

    local rank = STANDING_RANK[standing:lower()]
    if rank then
        local reaction = Decor.Api.FactionReaction(entry.factionID)
        return reaction and status(reaction >= rank) or "unknown"
    end

    -- Friendship factions: "Good Friend", "Rank 5", "Venom Trawler", ...
    local text, level = Decor.Api.Friendship(entry.factionID)
    local wantedLevel = tonumber(standing:match("^Rank%s+(%d+)"))
    if wantedLevel and level then return status(level >= wantedLevel) end
    if text and text:lower() == standing:lower() then return "met" end
    -- A different rank name cannot be ordered without the faction's rank list.
    return "unknown"
end

local function addUnique(list, seen, req)
    local key = req.kind .. "|" .. req.label:lower()
    if seen[key] then
        -- Keep the copy that can actually be checked.
        if req.id and not seen[key].id then
            seen[key].id = req.id
        end
        return
    end
    seen[key] = req
    list[#list + 1] = req
end

-- Returns the requirement list for one catalog row, each entry
--   { kind, label, status, detail }
function Prereqs:ForRow(decorID, itemID, parsed, vendor, playerFaction)
    self:Build()
    local list, seen = {}, {}

    if vendor then
        local faction = self:VendorFaction(vendor.name)
        if faction then
            addUnique(list, seen, {
                kind = "faction", label = faction .. " vendor",
                status = (playerFaction == nil) and "unknown" or status(faction == playerFaction),
            })
        end
        local note = usableString(vendor.name) and self._vendorNote[vendor.name:lower()]
        if note then
            addUnique(list, seen, { kind = "race", label = note, status = "unknown" })
        end
    end

    -- Names from the game's own text.
    local named = {}
    for _, req in ipairs(vendor and vendor.requires or {}) do named[#named + 1] = req end
    for _, other in ipairs(type(parsed) == "table" and parsed.others or {}) do named[#named + 1] = other end
    local textRep
    for _, req in ipairs(named) do
        local kind = usableString(req.kind) and req.kind:lower() or ""
        if (kind == "quest" or kind == "achievement") and usableString(req.name) then
            addUnique(list, seen, { kind = kind, label = req.name })
        elseif (kind == "faction" or kind == "renown") and usableString(req.name) then
            -- "Storm's Wake - Honored" / "Ritual Sites Rank 3": the game's own
            -- statement of the gate. Only the vendor we show is checked.
            textRep = textRep or self:ParseTextReputation(req.name)
        end
    end

    -- Ids (and any gate the game's text left out) from the imported item data.
    local hit = self._hitByDecor and self._hitByDecor[decorID]
    if type(hit) == "table" then
        if usableString(hit.quest) then
            addUnique(list, seen, { kind = "quest", label = hit.quest, id = tonumber(hit.questId) })
        end
        if usableString(hit.achievement) then
            addUnique(list, seen, { kind = "achievement", label = hit.achievement, id = tonumber(hit.achievementId) })
        end
    end

    -- A name with no id cannot be checked: that is "unknown", never "unmet".
    for _, req in ipairs(list) do
        if req.kind == "quest" then
            req.status = req.id and status(Decor.Api.QuestDone(req.id)) or "unknown"
        elseif req.kind == "achievement" then
            req.status = req.id and status(Decor.Api.AchievementDone(req.id)) or "unknown"
        end
    end

    local rep = textRep or (decorID and self._repByDecor[decorID]) or (itemID and self._repByItem[itemID])
    if rep then
        addUnique(list, seen, {
            kind = "reputation",
            label = rep.factionName .. ": " .. rep.standing,
            status = self:CheckReputation(rep),
        })
    end

    return list
end

-- The vendor to show: the cheapest one you can actually use.
function Prereqs:BestVendor(parsed, playerFaction)
    self:Build()
    local Source = _G.FabledUI_VillaDecorSource
    local best, bestRank
    for _, vendor in ipairs(type(parsed) == "table" and parsed.vendors or {}) do
        local rank = Source.CostRank(vendor.cost)
        if self:IsWrongFaction(vendor, playerFaction) then rank = rank + 1e13 end
        if #vendor.requires > 0 then rank = rank + 0.5 end
        if not best or rank < bestRank then best, bestRank = vendor, rank end
    end
    return best
end

-- Summarises a requirement list: blocked (any unmet), uncertain (any unknown).
function Prereqs:Summarise(list)
    local blocked, uncertain = false, false
    for _, req in ipairs(list) do
        if req.status == "unmet" then blocked = true end
        if req.status == "unknown" then uncertain = true end
    end
    return blocked, uncertain and not blocked
end
