local P = _G.FabledUI_Poseidon
if not P then return end

P.MapTooltip = P.MapTooltip or {}
local MT = P.MapTooltip

local function SortedKeys(set)
    local out = {}
    if type(set) ~= "table" then
        return out
    end
    for key, enabled in pairs(set) do
        if enabled then
            out[#out + 1] = key
        end
    end
    table.sort(out)
    return out
end

local function AddSection(tooltip, title, list, r, g, b)
    if type(list) ~= "table" or #list == 0 then
        return
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(title, r or 0.30, g or 0.78, b or 0.74)
    for _, value in ipairs(list) do
        tooltip:AddLine("- " .. value, 1, 1, 1, true)
    end
end

-- 12.x (Midnight) secret values: both UnitName and a tooltip line's GetText can
-- return a "secret string" when read from tainted addon code. Callers feed this
-- into LooksLikeFishingPool (which lowercases it) and into table lookups, both
-- of which throw on a secret -- so return nil instead. See Learn.lua.
local issecretvalue = _G.issecretvalue or function() return false end

function MT:GetTooltipPoolName(tooltip)
    local name = nil
    if tooltip and tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        if unit then
            name = UnitName(unit)
        end
    end
    if not name and tooltip and tooltip.GetName then
        local tooltipName = tooltip:GetName()
        if tooltipName then
            local textRegion = _G[tooltipName .. "TextLeft1"]
            name = textRegion and textRegion:GetText() or nil
        end
    end
    if name and issecretvalue(name) then return nil end
    return name
end

function MT:BuildPoolData(poolName, mapID, nodeData)
    if not P:LooksLikeFishingPool(poolName) then
        return nil
    end

    local learnedSet = {}
    local learnedDB = P.db.learned and P.db.learned[poolName]
    if type(learnedDB) == "table" then
        for fishName in pairs(learnedDB) do
            learnedSet[fishName] = true
        end
    end
    if nodeData and type(nodeData.fish) == "table" then
        for fishName in pairs(nodeData.fish) do
            learnedSet[fishName] = true
        end
    end

    local poolStats = P.Nodes and P.Nodes.GetPoolStats and P.Nodes:GetPoolStats(poolName, mapID) or nil
    if poolStats and type(poolStats.learned) == "table" then
        for _, fishName in ipairs(poolStats.learned) do
            learnedSet[fishName] = true
        end
    end

    local possibleSet = {}
    local static = type(_G.FishIntel_PoolFishIndex) == "table" and _G.FishIntel_PoolFishIndex[poolName] or nil
    if type(static) == "table" then
        for _, fishName in ipairs(static) do
            if not learnedSet[fishName] then
                possibleSet[fishName] = true
            end
        end
    end

    local zones = type(_G.FishIntel_PoolZoneIndex) == "table" and _G.FishIntel_PoolZoneIndex[poolName] or nil

    return {
        learned = SortedKeys(learnedSet),
        possible = SortedKeys(possibleSet),
        zones = zones,
        seenCount = poolStats and poolStats.seenCount or (nodeData and nodeData.seenCount) or 0,
        lastSeen = poolStats and poolStats.lastSeen or (nodeData and nodeData.lastSeen) or nil,
    }
end

function MT:AppendPoolTooltip(tooltip, poolName, mapID, nodeData)
    if not tooltip or not poolName then
        return
    end
    local data = self:BuildPoolData(poolName, mapID, nodeData)
    if not data then
        return
    end
    if data.zones and #data.zones > 0 then
        tooltip:AddLine("Zones: " .. table.concat(data.zones, ", "), 0.80, 0.84, 0.90, true)
    end
    if (data.seenCount or 0) > 0 then
        tooltip:AddLine(("Seen: %d"):format(data.seenCount), 0.80, 0.84, 0.90)
    end
    if data.lastSeen then
        tooltip:AddLine("Last Seen: " .. date("%Y-%m-%d %H:%M", data.lastSeen), 0.65, 0.70, 0.78)
    end
    AddSection(tooltip, "Learned Here", data.learned, 0.30, 0.78, 0.74)
    AddSection(tooltip, "Possible Here", data.possible, 0.96, 0.82, 0.28)
end

function MT:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    local function PostCall(tooltip)
        if not P.settings.tooltipIntel then
            return
        end
        local poolName = MT:GetTooltipPoolName(tooltip)
        if not P:LooksLikeFishingPool(poolName) then
            return
        end
        MT:AppendPoolTooltip(tooltip, poolName, C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil, nil)
    end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        if Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, PostCall)
        end
        if Enum.TooltipDataType.Object then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, PostCall)
        end
    end
end
