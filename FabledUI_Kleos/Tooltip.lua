local K = Kleos
K.Tooltip = K.Tooltip or {}
local T = K.Tooltip

-- ============================================================================
-- Tooltip
-- Three surfaces:
--   achievement  progress, reward typing, meta relationship, personal note
--   unit         "needed for <achievement>" when the mob is a kill criterion
--   item         the same for items an achievement asks you to own or use
--
-- The unit/item answers come from Catalog's asset index, which is built in
-- chunks off the first hover. The first hover after login therefore shows
-- nothing extra; that is deliberate, because building it eagerly costs a
-- five-thousand-achievement criteria walk at login.
-- ============================================================================

local MAX_UNIT_LINES = 4

local function TooltipsEnabled()
    return K.db and K.db.settings and K.db.settings.tooltips == true
end

local function UnitItemTooltipsEnabled()
    return K.db and K.db.settings and K.db.settings.unitItemTooltips == true
end

-- ----------------------------------------------------------------------------
-- Achievement
-- ----------------------------------------------------------------------------
function T:FillAchievement(tooltip, id)
    id = tonumber(id)
    if not tooltip or not id then return false end

    local entry = K.Catalog:GetEntry(id)
    if not entry then return false end
    local state = K.Catalog:GetState(id) or {}

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff4fd1c5Kleos|r", 0.31, 0.82, 0.77)

    if K:IsWatched(id) then
        tooltip:AddLine("|TInterface\\Common\\FavoritesIcon:12|t " .. (K.L.WATCH or "Watched"), 1, 0.82, 0)
    end
    if K:IsExcluded(id) then
        tooltip:AddLine("|TInterface\\RaidFrame\\ReadyCheck-NotReady:12|t " .. (K.L.EXCLUDED or "Excluded"), 1, 0.35, 0.35)
    end

    -- Progress
    if state.completed then
        local when = (state.year and state.year > 0)
            and (" (%02d/%02d/%04d)"):format(state.month or 0, state.day or 0, 2000 + state.year)
            or ""
        tooltip:AddLine((K.L.COMPLETE or "Complete") .. when, 0, 1, 0)
        if not state.wasEarnedByMe then
            tooltip:AddLine(K.L.EARNED_BY_ACCOUNT or "Earned by another character", 0.53, 0.8, 0.53)
        end
    else
        local progress, done, total = K.Catalog:GetProgress(id)
        if total and total > 0 then
            tooltip:AddLine(("%s: %d/%d (%d%%)"):format(K.L.PROGRESS or "Progress", done, total, math.floor(progress * 100 + 0.5)), 1, 0.82, 0)
        end
    end

    -- Reward typing
    local rewardDescription = K.Rewards:Describe(id)
    if rewardDescription then
        tooltip:AddLine(("%s: %s"):format(K.L.REWARD or "Reward", rewardDescription), 0.9, 0.9, 0.9, true)
    end
    if entry.rewardText and entry.rewardText ~= "" then
        tooltip:AddLine(entry.rewardText, 0.75, 0.75, 0.75, true)
    end
    local decorIDs = K.Rewards:GetDecorIDs(id)
    if #decorIDs > 0 then
        local names = K.UI and K.UI.DecorNames and K.UI.DecorNames(id, 3) or {}
        tooltip:AddLine(("%s: %s"):format(K.L.HOUSING or "Housing Decor",
            #names > 0 and table.concat(names, ", ") or tostring(#decorIDs)), 0.6, 0.85, 1, true)
    end

    -- Meta relationships
    local children = K.Meta:GetChildren(id)
    if #children > 0 then
        local done = 0
        for _, child in ipairs(children) do
            if child.completed then done = done + 1 end
        end
        tooltip:AddLine(("%s: %d/%d"):format(K.L.META or "Meta steps", done, #children), 0.4, 0.8, 1)
    end
    local parents = K.Meta:GetParents(id)
    if #parents > 0 then
        local names = {}
        for index, parentID in ipairs(parents) do
            if index > 2 then break end
            names[#names + 1] = K.Meta.AchievementName(parentID)
        end
        tooltip:AddLine(("%s: %s"):format(K.L.PART_OF or "Part of", table.concat(names, ", ")), 0.4, 0.8, 1, true)
    end

    local note = K:GetNote(id)
    if note then tooltip:AddLine(("%s: %s"):format(K.L.NOTES or "Note", note), 1, 1, 0.6, true) end

    local objectives = K.Objectives:Count(id)
    if objectives > 0 then
        tooltip:AddLine(("%s: %d"):format(K.L.OBJECTIVES or "Objectives", objectives), 0.8, 0.8, 0.6)
    end

    return true
end

local function AppendKleosLines(tooltip, id)
    if not id then return end
    if not TooltipsEnabled() then return end
    K:SafeCall(function() T:FillAchievement(tooltip, id) end)
end

-- Legacy hook target for clients still routing achievement links through
-- SetHyperlink. Only registered when the modern path is unavailable.
local function OnTooltipSetHyperlink(tooltip, link)
    if type(link) ~= "string" then return end
    local id = tonumber(link:match("achievement:(%d+)"))
    AppendKleosLines(tooltip, id)
end

-- ----------------------------------------------------------------------------
-- Unit / item
-- ----------------------------------------------------------------------------
function T:FillForAsset(tooltip, kind, assetID)
    if not tooltip or not UnitItemTooltipsEnabled() then return false end

    local ids, ready = K.Catalog:AchievementsForAsset(kind, assetID)
    if not ready then return false end
    if #ids == 0 then return false end

    local outstanding = {}
    for _, id in ipairs(ids) do
        local state = K.Catalog:GetState(id)
        if not (state and state.completed) or K:IsWatched(id) then
            outstanding[#outstanding + 1] = id
        end
    end
    if #outstanding == 0 then return false end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff4fd1c5Kleos|r " .. (K.L.NEEDED_FOR or "Needed for"), 0.31, 0.82, 0.77)
    for index, id in ipairs(outstanding) do
        if index > MAX_UNIT_LINES then
            tooltip:AddLine(("+%d %s"):format(#outstanding - MAX_UNIT_LINES, K.L.MORE or "more"), 0.6, 0.6, 0.6)
            break
        end
        local progress = K.Catalog:GetProgress(id)
        local suffix = (progress > 0 and progress < 1) and ((" (%d%%)"):format(math.floor(progress * 100 + 0.5))) or ""
        local watched = K:IsWatched(id) and "|TInterface\\Common\\FavoritesIcon:12|t " or ""
        tooltip:AddLine(watched .. K.Meta.AchievementName(id) .. suffix, 1, 0.82, 0)
    end
    return true
end

function T:OnUnitTooltip(tooltip, unit)
    -- On 12.x the unit token can be a secret string; passing one to UnitGUID
    -- throws rather than returning nil. Util.SafeUnitGUID absorbs both that
    -- and a secret GUID coming back, so anything unreadable arrives as nil.
    local guid = K.Util and K.Util.SafeUnitGUID(unit)
    if not guid then return end
    local npcID = K.Encounter and K.Encounter.NPCIDFromGUID and K.Encounter.NPCIDFromGUID(guid) or nil
    if not npcID then return end
    K:SafeCall(function() T:FillForAsset(tooltip, "creature", npcID) end)
end

function T:OnItemTooltip(tooltip, itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    K:SafeCall(function() T:FillForAsset(tooltip, "item", itemID) end)
end

-- ----------------------------------------------------------------------------
-- Registration
-- ----------------------------------------------------------------------------
function T:Init()
    if self._registered then return end
    self._registered = true

    local modern = false
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType
    then
        if Enum.TooltipDataType.Achievement then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
                local id = data and (data.id or data.dataInstanceID)
                AppendKleosLines(tooltip, id)
            end)
            modern = true
        end

        if Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
                if not UnitItemTooltipsEnabled() then return end
                -- The unit token is not in the data payload; read it off the
                -- tooltip owner, which is what Blizzard's own post-calls do.
                -- A secret token is no more usable than a missing one, so
                -- treat it as absent and let the data.guid path try instead.
                local _, unit = tooltip:GetUnit()
                if K.Util and not K.Util.IsUsableString(unit) then unit = nil end
                if not unit and data and data.guid then
                    local npcID = K.Encounter.NPCIDFromGUID(data.guid)
                    if npcID then K:SafeCall(function() T:FillForAsset(tooltip, "creature", npcID) end) end
                    return
                end
                T:OnUnitTooltip(tooltip, unit)
            end)
        end

        if Enum.TooltipDataType.Item then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
                if not UnitItemTooltipsEnabled() then return end
                local itemID = data and (data.id or data.itemID)
                T:OnItemTooltip(tooltip, itemID)
            end)
        end
    end

    -- Fallback for clients without TooltipDataProcessor: hook the achievement
    -- link path only, so we never double-append when the modern path took.
    if not modern and GameTooltip and GameTooltip.HookScript then
        hooksecurefunc(GameTooltip, "SetHyperlink", OnTooltipSetHyperlink)
        if ItemRefTooltip and ItemRefTooltip.HookScript then
            hooksecurefunc(ItemRefTooltip, "SetHyperlink", OnTooltipSetHyperlink)
        end
        if GameTooltip.HookScript then
            GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
                if not UnitItemTooltipsEnabled() then return end
                local _, unit = tooltip:GetUnit()
                T:OnUnitTooltip(tooltip, unit)
            end)
        end
    end
end
