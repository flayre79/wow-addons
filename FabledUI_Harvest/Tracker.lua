local H = FabledUI_Harvest
if not H then return end

H.Tracker = {}
local T = H.Tracker

-- Known gathering spell IDs → node type
-- Covers core Retail gathering skills; extend as new Midnight nodes are discovered
local GATHER_SPELLS = {
    -- Herbalism (generic gather actions)
    [2366]  = "herb", [2368]  = "herb", [3570]  = "herb",
    [11993] = "herb", [28695] = "herb", [50300] = "herb",
    [51005] = "herb", [124041]= "herb", [158748]= "herb",
    [188673]= "herb", [229239]= "herb", [247016]= "herb",
    [269823]= "herb", [299211]= "herb", [339895]= "herb",
    [366253]= "herb", [383585]= "herb",
    -- Mining (generic mine actions)
    [2575]  = "ore",  [2576]  = "ore",  [3564]  = "ore",
    [10248] = "ore",  [29355] = "ore",  [50310] = "ore",
    [55209] = "ore",  [75208] = "ore",  [102161]= "ore",
    [158773]= "ore",  [188689]= "ore",  [229250]= "ore",
    [247018]= "ore",  [273224]= "ore",  [299394]= "ore",
    [339900]= "ore",  [366262]= "ore",  [383586]= "ore",
    [423341]= "ore",  -- The War Within (Khaz Algar)
    [471013]= "ore",  -- Midnight
    -- Skinning (track separately — type "skin")
    [8613]  = "skin", [8617]  = "skin", [8618]  = "skin",
    -- Logging / timber. The lumber layer had no spell entries at all, so every
    -- lumber gather fell through to bag-delta name inference. 1239682 is the
    -- Midnight housing-decor wood logging cast, which is the one that matters
    -- for the Session Harvest lumber counter.
    [167895] = "lumber",  -- Draenor garrison logging
    [1239682] = "lumber", -- TWW / Midnight housing decor wood logging
}

-- Spell IDs churn every expansion: the table above was capped at Dragonflight
-- (383585/383586), so on current content the primary capture path missed
-- outright and every gather degraded to the bag-delta fallback. Matching on the
-- spell *name* resolved from one base ID per profession survives new IDs for
-- the same action, which is how GatherMate2 has stayed current. The ID table is
-- kept as the fast path and as a fallback for clients where the name lookup
-- fails.
local GATHER_SPELL_NAMES = {
    -- English floor. C_Spell.GetSpellName only resolves IDs the client has
    -- data for, so on a partially-populated client several professions would
    -- otherwise have no name entry at all -- and NodeTypeForErrorMessage,
    -- which matches failed-gather errors against these names, would go silent
    -- for them. The localised names resolved below are added on top; extra
    -- English keys are harmless because matching is a plain substring find
    -- against the client's own message.
    ["Herb Gathering"] = "herb",
    ["Herbalism"]      = "herb",
    ["Mining"]         = "ore",
    ["Skinning"]       = "skin",
    ["Logging"]        = "lumber",
}
do
    local GetSpellName = C_Spell and C_Spell.GetSpellName
    if GetSpellName then
        -- One representative ID per gathering action; we only want its name.
        local nameSources = {
            [2366]    = "herb",   -- Herb Gathering
            [2575]    = "ore",    -- Mining
            [423341]  = "ore",    -- Mining (Khaz Algar variant name)
            [471013]  = "ore",    -- Mining (Midnight variant name)
            [8613]    = "skin",   -- Skinning
            [167895]  = "lumber", -- Logging
            [1239682] = "lumber", -- Housing decor wood logging
        }
        for spellID, nodeType in pairs(nameSources) do
            local ok, name = pcall(GetSpellName, spellID)
            if ok and type(name) == "string" and name ~= "" then
                GATHER_SPELL_NAMES[name] = nodeType
            end
        end
    end
end

-- Classify a UI error message as a failed gathering attempt.
--
-- Walking up to a node you lack the skill for produces "Requires Herbalism"
-- rather than a cast, so the node was never recorded -- exactly the nodes worth
-- remembering, since you will come back for them. GatherMate2 captures these
-- the same way. Matching against the localised profession names already
-- resolved above keeps this working in every locale without a string table;
-- the plain-text find (4th arg true) matters because localised names can
-- contain Lua pattern characters.
local function NodeTypeForErrorMessage(msg)
    if type(msg) ~= "string" or msg == "" then return nil end
    for name, nodeType in pairs(GATHER_SPELL_NAMES) do
        if #name > 2 and msg:find(name, 1, true) then
            return nodeType
        end
    end
    return nil
end

-- Resolve a cast to a node type by ID first, then by spell name.
local function NodeTypeForSpell(spellID)
    if not spellID then return nil end
    local byID = GATHER_SPELLS[spellID]
    if byID then return byID end

    local GetSpellName = C_Spell and C_Spell.GetSpellName
    if not GetSpellName then return nil end
    local ok, name = pcall(GetSpellName, spellID)
    if ok and type(name) == "string" then
        return GATHER_SPELL_NAMES[name]
    end
    return nil
end

-- How far ahead of the player a fishing bobber lands. GatherMate2 uses the same
-- 15-yard projection for fishing and gas clouds.
local FISHING_CAST_YARDS = 15

-- Fishing spell IDs (cast → bobber lands near a pool)
local FISHING_SPELLS = {
    [7620]   = true, -- Fishing (base)
    [131474] = true, -- Fishing (high-level)
    [153467] = true, -- Angler's Fishing Line variant
    [295430] = true, -- Battle for Azeroth fishing
    [342093] = true, -- Shadowlands fishing
    [392155] = true, -- Dragonflight fishing
}

-- Infer node type from game object name when no spell ID is known
local function InferNodeType(name)
    if not name then return "treasure" end
    local n = name:lower()
    if n:find("ore") or n:find("vein") or n:find("seam") or n:find("deposit") then return "ore" end
    if n:find("timber") or n:find("lumber") or n:find("log") or n:find("branch") or n:find("tree") then return "lumber" end
    if n:find("pool") or n:find("school") or n:find("shoal") then return "fish" end
    if n:find("herb") or n:find("root") or n:find("bloom") or n:find("blossom") or
       n:find("petal") or n:find("leaf") or n:find("grass") or n:find("vine") or n:find("flower") then return "herb" end
    return "treasure"
end

-- Classify a *material* name (loot item or bag-delta item) into a node type.
--
-- This is the single source of truth for material-name classification. It used
-- to be copy-pasted into InferNodeTypeFromLoot and NodeTypeForItem, and the two
-- copies had silently drifted: the loot-window path was missing the whole "skin"
-- branch and the "seed"/"flower" herb patterns, so skinning never registered a
-- node when the loot window was the only signal. Both callers now share this.
--
-- Matches anchor to word boundaries (%f[%w] frontier) so "Stonebound Tea" (an
-- inscription consumable) and "+Strength Metal Trinket" are not read as ore.
-- Returns nil when the name carries no gathering signature.
local function ClassifyGatherName(name)
    if not name then return nil end
    local lower = name:lower()

    if lower:find("%f[%w]lumber") or lower:find("%f[%w]timber")
        or lower:find("%f[%w]log") or lower:find("%f[%w]plank")
        or lower:find("%f[%w]kindling") or lower:find("%f[%w]bough") then
        return "lumber"
    end
    if lower:find("%f[%w]ore$") or lower:find("%s+ore$")
        or lower:find("%f[%w]vein") or lower:find("%f[%w]deposit") then
        return "ore"
    end
    if lower:find("%f[%w]herb") or lower:find("%f[%w]petal")
        or lower:find("%f[%w]bloom") or lower:find("%f[%w]blossom")
        or lower:find("%f[%w]leaf") or lower:find("%f[%w]root")
        or lower:find("%f[%w]seed") or lower:find("%f[%w]flower") then
        return "herb"
    end
    if lower:find("%f[%w]hide") or lower:find("%f[%w]leather")
        or lower:find("%f[%w]scale") or lower:find("%f[%w]pelt") then
        return "skin"
    end
    return nil
end

-- Project a point `yards` ahead of the player, in normalised map coordinates.
--
-- A fishing bobber is not at the player's feet: it lands roughly 15 yards out
-- in the direction they are facing, so recording the player's own position puts
-- every fishing node systematically short of the pool. Converting yards to
-- normalised coordinates needs the zone's real dimensions, which is what
-- C_Map.GetMapWorldSize provides. Returns the input unchanged when facing or
-- zone size is unavailable (minimap rotation makes GetPlayerFacing return nil).
local function ProjectAhead(mapID, x, y, yards)
    if not (mapID and x and y) then return x, y end
    if not (C_Map and C_Map.GetMapWorldSize) then return x, y end

    local ok, width, height = pcall(C_Map.GetMapWorldSize, mapID)
    if not ok or not width or not height or width == 0 or height == 0 then
        return x, y
    end

    local facing = GetPlayerFacing and GetPlayerFacing()
    if not facing then return x, y end

    -- Map y grows downward while world facing is measured counterclockwise from
    -- north, which is why the vertical term uses cos and the horizontal sin.
    local rad = facing + math.pi
    return x + math.sin(rad) * yards / width,
           y + math.cos(rad) * yards / height
end

local function GetPlayerMapPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil, nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local x, y = pos:GetXY()
        return mapID, x, y
    end
    return nil, nil, nil
end

-- 12.x (Midnight) secret values. Unit identity read from a tainted execution
-- path -- which every handler in this file is -- can come back as a "secret
-- string": it may be passed around, but indexing it (guid:match(...)), using it
-- as a table key, or concatenating it throws. Funnel all unit reads through
-- these two so the call sites below only ever see a real string or nil.
-- Shimmed so the file still loads on pre-12.x clients.
local issecretvalue = _G.issecretvalue or function() return false end

local function SafeUnitGUID(unit)
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return nil end
    return guid
end

local function SafeUnitName(unit)
    local name = UnitName(unit)
    if not name or issecretvalue(name) then return nil end
    return name
end

local function GetGUIDType(guid)
    return guid and guid:match("^(%a+)%-")
end

-- Cache the last game object the player targeted — most reliable timing for coord capture
local cachedGUID, cachedName = nil, nil
local cachedMapID, cachedX, cachedY = nil, nil, nil

-- Fishing-specific: track whether a cast is in-flight so we can record on loot
local fishingCastPending = false
local fishingCastMapID, fishingCastX, fishingCastY = nil, nil, nil
local fishingCastName = nil

-- Return true if the name looks like a fish pool game object
local function IsFishPool(name)
    if not name then return false end
    local n = name:lower()
    return n:find("pool") ~= nil
        or n:find("school") ~= nil
        or n:find("shoal") ~= nil
        or n:find("wreckage") ~= nil
        or n:find("debris") ~= nil
end

local function CacheTargetIfObject()
    local guid = SafeUnitGUID("target")
    if guid and GetGUIDType(guid) == "GameObject" then
        local mapID, x, y = GetPlayerMapPos()
        if mapID then
            cachedGUID  = guid
            cachedName  = SafeUnitName("target") or "Unknown"
            cachedMapID, cachedX, cachedY = mapID, x, y
        end
    end
end

local function ExtractObjectID(guid)
    -- GUID format: "GameObject-0-realmID-mapID-instanceID-objectID-spawnUID"
    if not guid then return 0 end
    local parts = { guid:match("(%a+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(.+)") }
    return tonumber(parts[6]) or 0
end

-- Infer node type from a loot item name. Used as a fallback when the player
-- gathered a node without targeting it (lumber and Midnight nodes often skip
-- PLAYER_TARGET_CHANGED). Returns nil if the loot doesn't look like a gather.
local function InferNodeTypeFromLoot()
    if not GetNumLootItems then return nil end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local name
        if link then
            name = link:match("%[(.-)%]") or link
        end
        if not name and GetLootSlotInfo then
            local _, n = GetLootSlotInfo(slot)
            name = n
        end
        local nodeType = ClassifyGatherName(name)
        if nodeType then
            return nodeType, name
        end
    end
    return nil, nil
end

-- =============================================================================
-- Bag-delta capture (alternative to LOOT_OPENED for silent gathers)
-- =============================================================================
-- Pattern adapted from .sample-addons/Gathering/Elements/GasClouds.lua
-- (lines 21-101 + 103-136). Lumber and several Midnight 12.0.5 nodes do not
-- fire LOOT_OPENED at all — the items just appear in the player's bags as the
-- channel completes. We snapshot bag contents on UNIT_SPELLCAST_CHANNEL_START
-- (and on UNIT_SPELLCAST_SUCCEEDED for non-channelled gathers, as a belt-and-
-- braces) and diff them once BAG_UPDATE_DELAYED settles.
-- =============================================================================

-- API shims (the bag API moved to C_Container in Retail).
-- The pre-10.0 globals are probed with rawget: they are absent from the 12.x
-- API surface, so a plain _G.Foo read is an undefined-field to static analysis
-- even though the guard is deliberate. rawget states "may not exist" outright.
local _GetContainerNumSlots  = C_Container and C_Container.GetContainerNumSlots  or rawget(_G, "GetContainerNumSlots")
local _GetContainerItemID    = C_Container and C_Container.GetContainerItemID    or rawget(_G, "GetContainerItemID")
local _GetContainerItemInfo  = rawget(_G, "GetContainerItemInfo")
if C_Container and C_Container.GetContainerItemInfo then
    _GetContainerItemInfo = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.iconFileID, info.stackCount end
    end
end

-- _bagSnapshot[itemID] = qty (flat, since we only care about per-item totals)
local _bagSnapshot = nil
-- Context for the pending delta (where the player gathered, what spell, etc.)
local _bagDeltaPending = nil

local function SnapshotBags()
    local snapshot = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots = _GetContainerNumSlots and _GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local id = _GetContainerItemID and _GetContainerItemID(bag, slot)
            if id then
                local _, count = _GetContainerItemInfo(bag, slot)
                count = count or 1
                snapshot[id] = (snapshot[id] or 0) + count
            end
        end
    end
    return snapshot
end

-- Walk current bag contents, return positive deltas vs the snapshot.
local function ComputeBagDelta(snapshot)
    local delta = {}
    local current = SnapshotBags()
    for id, qty in pairs(current) do
        local before = snapshot[id] or 0
        if qty > before then
            delta[id] = qty - before
        end
    end
    return delta, current
end

-- Trade-goods subclass IDs. Not exposed as an Enum by the client, so they are
-- named here rather than left as bare numbers at the comparison site.
local TRADEGOODS_LEATHER      = 6
local TRADEGOODS_METAL_STONE  = 7
local TRADEGOODS_HERB         = 9

-- Item subclass -> node type. This is the authoritative classification: the
-- item API knows a Peacebloom is a herb, where the name patterns cannot, since
-- the %f[%w] frontier that keeps "Stonebound Tea" from reading as ore also
-- stops any token fused into a compound word from matching at all.
local TRADEGOODS_NODE_TYPES = {
    [TRADEGOODS_HERB]        = "herb",
    [TRADEGOODS_METAL_STONE] = "ore",
    [TRADEGOODS_LEATHER]     = "skin",
}

-- Resolve a node type from a delta-detected item ID.
--
-- Classification order matters. The item's own class/subclass is definitive and
-- is tried first; ClassifyGatherName is kept as the fallback because it still
-- covers what the subclass cannot -- lumber has no dedicated trade-goods
-- subclass, and an uncached item returns no class data at all on first sight.
local function NodeTypeForItem(itemID)
    local name, classID, subclassID
    if C_Item and C_Item.GetItemInfo then
        name, _, _, _, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemID)
    else
        -- Deprecated pre-10.0 global; rawget keeps the fallback reachable
        -- without static analysis resolving it to the deprecated symbol.
        local legacy = rawget(_G, "GetItemInfo")
        if legacy then
            name, _, _, _, _, _, _, _, _, _, _, classID, subclassID = legacy(itemID)
        end
    end
    if not name then return nil, nil end

    if Enum and Enum.ItemClass and classID == Enum.ItemClass.Tradegoods then
        local byClass = TRADEGOODS_NODE_TYPES[subclassID]
        if byClass then return byClass, name end
    end

    -- Shares ClassifyGatherName with the loot-window path so the two capture
    -- routes cannot drift apart again.
    return ClassifyGatherName(name), name
end

-- Process a finished bag-delta capture: record gathered nodes via SaveNode.
local function ProcessBagDelta()
    if not _bagDeltaPending or not _bagSnapshot then
        _bagSnapshot = nil
        _bagDeltaPending = nil
        return
    end

    local delta = ComputeBagDelta(_bagSnapshot)
    local ctx = _bagDeltaPending
    _bagSnapshot = nil
    _bagDeltaPending = nil

    -- Nothing changed — likely a non-gather channel completed, or the player
    -- is just chugging a potion. Bail silently.
    local anyDelta = false
    for _ in pairs(delta) do anyDelta = true; break end
    if not anyDelta then return end

    -- Only one node was gathered at this position regardless of how many items
    -- dropped — collapse to a single SaveNode call using the dominant type.
    local bestType, bestName, bestQty
    for itemID, qty in pairs(delta) do
        local nodeType, itemName = NodeTypeForItem(itemID)
        if nodeType and (not bestQty or qty > bestQty) then
            bestType = nodeType
            bestName = itemName
            bestQty = qty
        end
    end

    -- If we couldn't classify the loot, but the originating spell already told
    -- us a type (e.g. herbalism), trust the spell.
    bestType = bestType or ctx.fallbackType
    if not bestType then return end

    if ctx.mapID and ctx.x and ctx.y then
        H:SaveNode(ctx.mapID, ctx.x, ctx.y, bestType, ctx.spellID or 0,
                   bestName or ctx.fallbackName or "Gathered Node")
        cachedGUID = nil
    end
end

-- Test seam. Everything below is a pure function over its arguments and carries
-- most of the capture path's decision logic, but they are file-locals reachable
-- only from the OnEvent closure created in T:Init. Exported so tests/ can
-- exercise the classification rules directly instead of trying to drive five
-- game events through a frame the simulator cannot fire realistically.
-- Not public API: nothing outside tests/ should call these.
T._internal = {
    ClassifyGatherName = ClassifyGatherName,
    InferNodeType      = InferNodeType,
    IsFishPool         = IsFishPool,
    ExtractObjectID    = ExtractObjectID,
    NodeTypeForSpell   = NodeTypeForSpell,
    NodeTypeForErrorMessage = NodeTypeForErrorMessage,
    NodeTypeForItem    = NodeTypeForItem,
    ProjectAhead       = ProjectAhead,
    GATHER_SPELLS      = GATHER_SPELLS,
    GATHER_SPELL_NAMES = GATHER_SPELL_NAMES,
    FISHING_SPELLS     = FISHING_SPELLS,
    FISHING_CAST_YARDS = FISHING_CAST_YARDS,
}

function T:Init()
    local frame = CreateFrame("Frame")

    local _trackerErrCount = 0
    frame:SetScript("OnEvent", function(_, event, ...)
      local ok, err = pcall(function(...)
        if event == "PLAYER_TARGET_CHANGED" then
            CacheTargetIfObject()

        elseif event == "LOOT_OPENED" then
            -- Fishing loot: if we have a pending bobber cast, use those coords.
            if fishingCastPending then
                H:SaveNode(fishingCastMapID, fishingCastX, fishingCastY, "fish", 0, fishingCastName or "Fishing Pool")
                fishingCastPending = false
                fishingCastMapID, fishingCastX, fishingCastY = nil, nil, nil
                fishingCastName = nil
                -- Don't fall through — this was a fishing loot, not a gather loot.
                return
            end

            -- Standard gather loot: try the live target first, then use cache.
            local guid   = SafeUnitGUID("target")
            local name, mapID, x, y, objID

            if guid and GetGUIDType(guid) == "GameObject" then
                mapID, x, y = GetPlayerMapPos()
                name        = SafeUnitName("target") or "Unknown"
                objID       = ExtractObjectID(guid)
            elseif cachedGUID then
                mapID, x, y = cachedMapID, cachedX, cachedY
                name        = cachedName
                objID       = ExtractObjectID(cachedGUID)
            end

            -- Fallback: if no game-object target/cache (lumber and several
            -- Midnight 12.0.5 nodes don't trigger PLAYER_TARGET_CHANGED), but
            -- the loot itself looks like a gathering material, infer the
            -- node type from the loot and use the player's current position.
            if not (mapID and x and y) then
                local lootType, lootName = InferNodeTypeFromLoot()
                if lootType then
                    mapID, x, y = GetPlayerMapPos()
                    name = lootName or lootType
                    objID = 0
                    if mapID and x and y then
                        H:SaveNode(mapID, x, y, lootType, objID, name)
                        cachedGUID = nil
                        return
                    end
                end
            end

            if mapID and x and y then
                local nodeType = InferNodeType(name)
                -- If we still couldn't classify the node by name, double-check
                -- the loot for a gather signature before recording.
                if nodeType == "treasure" then
                    local lootType = InferNodeTypeFromLoot()
                    if lootType then nodeType = lootType end
                end
                H:SaveNode(mapID, x, y, nodeType, objID, name)
                cachedGUID = nil
            end

        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unitTarget, _, spellID = ...
            if unitTarget ~= "player" then return end

            -- Fishing cast succeeded: snapshot position now for later LOOT_OPENED
            if FISHING_SPELLS[spellID] then
                if not fishingCastPending then
                    local mapID, x, y = GetPlayerMapPos()
                    if mapID and x and y then
                        -- Record where the bobber lands, not where the player
                        -- stands, so the pool pin sits on the actual water.
                        x, y = ProjectAhead(mapID, x, y, FISHING_CAST_YARDS)
                        fishingCastPending = true
                        fishingCastMapID, fishingCastX, fishingCastY = mapID, x, y
                        local guid = SafeUnitGUID("target")
                        if guid and GetGUIDType(guid) == "GameObject" then
                            local tName = SafeUnitName("target") or ""
                            fishingCastName = IsFishPool(tName) and tName or (cachedName or "Fishing Pool")
                        else
                            fishingCastName = (cachedName and IsFishPool(cachedName)) and cachedName or "Fishing Pool"
                        end
                    end
                end
                return
            end

            local nodeType = NodeTypeForSpell(spellID)
            if not nodeType then return end

            -- Standard path: we had a GameObject target — record immediately.
            local guid = SafeUnitGUID("target")
            local hasObjectTarget = guid and GetGUIDType(guid) == "GameObject"

            if hasObjectTarget or cachedGUID then
                local mapID = cachedMapID
                local x     = cachedX
                local y     = cachedY
                if not mapID then
                    mapID, x, y = GetPlayerMapPos()
                end
                if mapID and x and y then
                    H:SaveNode(mapID, x, y, nodeType, spellID, cachedName or "Unknown Node")
                    cachedGUID = nil
                end
                return
            end

            -- Alt path: gather succeeded without a GameObject GUID (lumber and
            -- several Midnight nodes skip PLAYER_TARGET_CHANGED entirely). Arm
            -- a bag-delta capture using the player's current position; the
            -- subsequent BAG_UPDATE_DELAYED will compute the delta and call
            -- SaveNode. We snapshot here in case CHANNEL_START never fired
            -- (the gather may be instant).
            if not _bagSnapshot then
                _bagSnapshot = SnapshotBags()
            end
            local mapID, x, y = GetPlayerMapPos()
            if mapID and x and y then
                _bagDeltaPending = {
                    mapID = mapID, x = x, y = y,
                    spellID = spellID,
                    fallbackType = nodeType,
                    fallbackName = cachedName or "Gathered Node",
                }
            end

        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            -- Some gathering animations are channelled (the cast bar fills as
            -- the player kneels). Snapshot bags now and arm a delta capture
            -- regardless of GUID availability — BAG_UPDATE_DELAYED will diff.
            local unitTarget, _, spellID = ...
            if unitTarget ~= "player" then return end

            local nodeType = NodeTypeForSpell(spellID)
            if not nodeType then return end

            -- Skip if the standard target-cache path will handle this gather.
            local guid = SafeUnitGUID("target")
            local hasObjectTarget = (guid and GetGUIDType(guid) == "GameObject")
                                    or (cachedGUID ~= nil)
            if hasObjectTarget then return end

            _bagSnapshot = SnapshotBags()
            local mapID, x, y = GetPlayerMapPos()
            if mapID and x and y then
                _bagDeltaPending = {
                    mapID = mapID, x = x, y = y,
                    spellID = spellID,
                    fallbackType = nodeType,
                    fallbackName = cachedName or "Gathered Node",
                }
            end

        elseif event == "UI_ERROR_MESSAGE" then
            -- Opt-out: this is the one capture path that records a node the
            -- player did not actually gather.
            if H.settings and H.settings.captureFailedGathers == false then return end

            local _, msg = ...
            local nodeType = NodeTypeForErrorMessage(msg)
            if not nodeType then return end

            -- The world tooltip still names whatever is under the cursor.
            -- Route it through the same secret-value guard as unit reads: a
            -- 12.x secret string cannot be indexed or concatenated.
            local nodeName
            local left1 = _G["GameTooltipTextLeft1"]
            if left1 and left1.GetText then
                local text = left1:GetText()
                if text and not issecretvalue(text) then nodeName = text end
            end

            local mapID, x, y = GetPlayerMapPos()
            if mapID and x and y then
                H:SaveNode(mapID, x, y, nodeType, 0, nodeName or "Unreachable Node")
            end

        elseif event == "BAG_UPDATE_DELAYED" then
            -- If a snapshot is armed, diff & save. No-op otherwise so we don't
            -- create spurious nodes from looting drops, vendoring, etc.
            if _bagSnapshot and _bagDeltaPending then
                ProcessBagDelta()
            end
        end
      end, ...)
      if not ok then
        _trackerErrCount = _trackerErrCount + 1
        if _trackerErrCount <= 3 then
            print("|cffff5555[Harvest.Tracker]|r " .. tostring(err))
        end
      end
    end)

    -- Handler first, then one RegisterEvent at a time. A refused or unknown
    -- event raises out of Init, and registering as a batch beforehand would
    -- leave this frame holding live registrations with no OnEvent attached --
    -- every remaining capture path silently dead with nothing logged.
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
end
