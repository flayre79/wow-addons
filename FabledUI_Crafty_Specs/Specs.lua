local M = _G.FabledUI_Crafty
M.Specs = M.Specs or {}
local S = M.Specs

-- P0-8: cache C_Traits.GetTreeNodes(treeID) results.
-- C_Traits.GetTreeNodes is a hot call during CaptureOpenProfession and the
-- result is invariant per tree until the trait config list reloads. Pattern
-- lifted from TalentTreeTweaks/ImportExportUtilV2.lua:116-130.
local _treeNodeCache = {}

local function GetTreeNodesCached(treeID)
    if not treeID then
        return {}
    end
    local cached = _treeNodeCache[treeID]
    if cached then
        return cached
    end
    local nodes
    if C_Traits and C_Traits.GetTreeNodes then
        local ok, result = pcall(C_Traits.GetTreeNodes, treeID)
        if ok and type(result) == "table" then
            nodes = result
        end
    end
    nodes = nodes or {}
    _treeNodeCache[treeID] = nodes
    return nodes
end

function S:InvalidateTreeNodeCache()
    _treeNodeCache = {}
end

-- TRAIT_CONFIG_LIST_UPDATED fires when the entire trait config list reloads
-- (relog, talent reset). Drop the per-tree node cache so a stale tree layout
-- isn't reused across config changes.
do
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    listener:SetScript("OnEvent", function()
        S:InvalidateTreeNodeCache()
    end)
end

local function ensureAlt(characterKey, professionName)
    local char = M.Alts and M.Alts:GetCharacterData(characterKey)
    if not char then
        M.Alts:RegisterCurrentCharacter()
        char = M.Alts and M.Alts:GetCharacterData(characterKey)
    end
    char.professions = type(char.professions) == 'table' and char.professions or {}
    char.professions[professionName] = type(char.professions[professionName]) == 'table' and char.professions[professionName] or {}
    return char.professions[professionName]
end

local function getNodeName(configID, nodeID, nodeInfo)
    local entryID = nodeInfo and nodeInfo.entryIDs and nodeInfo.entryIDs[1]
    if not entryID or not C_Traits or not C_Traits.GetEntryInfo then
        return tostring(nodeID)
    end
    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
    local definitionInfo = entryInfo and C_Traits.GetDefinitionInfo and C_Traits.GetDefinitionInfo(entryInfo.definitionID) or nil
    if definitionInfo and definitionInfo.overrideName and definitionInfo.overrideName ~= '' then
        return definitionInfo.overrideName, definitionInfo.overrideIcon
    end
    return tostring(nodeID), definitionInfo and definitionInfo.overrideIcon or nil
end

function S:CaptureOpenProfession(markDirty)
    if not C_ProfSpecs or not C_ProfSpecs.GetConfigIDForSkillLine or not C_Traits or not C_Traits.GetConfigInfo then
        return nil
    end
    local context = M.Concentration and M.Concentration:GetOpenProfessionContext() or nil
    if not context or not context.tradeSkillLineID or not context.professionName then
        return nil
    end

    local configID = C_ProfSpecs.GetConfigIDForSkillLine(context.tradeSkillLineID)
    if not configID then
        return nil
    end

    -- P0-9: pcall around C_Traits.GetConfigInfo. The raw call throws when
    -- invoked during a TRAIT_CONFIG_LIST_UPDATED reload (config not yet
    -- republished). Pattern from TalentTreeTweaks/SharedUtil.lua:298.
    local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not okConfig or type(configInfo) ~= 'table' then
        return nil
    end

    local activeNodes = {}
    local totalRanks = 0
    local treeIDs = configInfo.treeIDs or {}
    for _, treeID in ipairs(treeIDs) do
        local nodeIDs = GetTreeNodesCached(treeID)
        for _, nodeID in ipairs(nodeIDs or {}) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            local rank = math.max(0, tonumber((nodeInfo and (nodeInfo.activeRank or nodeInfo.currentRank)) or 0) or 0)
            if rank > 0 then
                local name, icon = getNodeName(configID, nodeID, nodeInfo)
                local maxRank = tonumber(nodeInfo and nodeInfo.maxRanks or 0) or 0
                activeNodes[#activeNodes + 1] = {
                    nodeID = nodeID,
                    name = name,
                    icon = icon,
                    rank = rank,
                    maxRank = maxRank,
                    description = C_ProfSpecs.GetDescriptionForPath and C_ProfSpecs.GetDescriptionForPath(nodeID) or nil,
                }
                totalRanks = totalRanks + rank
            end
        end
    end

    table.sort(activeNodes, function(a, b)
        if (a.rank or 0) ~= (b.rank or 0) then
            return (a.rank or 0) > (b.rank or 0)
        end
        return (a.name or '') < (b.name or '')
    end)

    local characterKey = M:GetCurrentCharacterKey()
    local prof = ensureAlt(characterKey, context.professionName)
    prof.specialization = {
        configID = configID,
        professionName = context.professionName,
        tradeSkillLineID = context.tradeSkillLineID,
        pointsSpent = totalRanks,
        activeNodes = activeNodes,
        lastScanned = time(),
    }

    if markDirty then
        M:MarkDirty()
        M:Fire('AltDataChanged')
        M:Fire('DataChanged')
    end

    return prof.specialization
end

function S:GetSnapshot(characterKey, professionName)
    local char = M.Alts and M.Alts:GetCharacterData(characterKey)
    local prof = char and char.professions and char.professions[professionName]
    return prof and prof.specialization or nil
end

function S:GetSummaryText(snapshot)
    if not snapshot then
        return 'No specialization snapshot'
    end
    local names = {}
    for index, node in ipairs(snapshot.activeNodes or {}) do
        if index > 3 then break end
        names[#names + 1] = string.format('%s (%d)', node.name or ('Node ' .. tostring(node.nodeID)), node.rank or 0)
    end
    local lead = string.format('%d ranks tracked', snapshot.pointsSpent or 0)
    if #names > 0 then
        return lead .. ' · ' .. table.concat(names, ', ')
    end
    return lead
end
