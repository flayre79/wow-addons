local P = _G.FabledUI_Poseidon
if not P then return end

P.Nodes = P.Nodes or {}
local N = P.Nodes

local function RoundCoord(value)
    if type(value) ~= "number" then
        return nil
    end
    return math.floor((value * 10000) + 0.5) / 10000
end

local function GetCoordKey(x, y)
    return string.format("%.4f,%.4f", x, y)
end

local function GetSubZoneSafe()
    local subZone = GetSubZoneText and GetSubZoneText() or nil
    if type(subZone) == "string" and subZone ~= "" then
        return subZone
    end
    return ""
end

function N:GetFishCount(node)
    local count = 0
    if type(node) ~= "table" or type(node.fish) ~= "table" then
        return 0
    end
    for _ in pairs(node.fish) do
        count = count + 1
    end
    return count
end

function N:GetNode(mapID, coordKey)
    if not mapID or not coordKey then
        return nil
    end
    local bucket = P.db.nodes[mapID]
    return bucket and bucket[coordKey] or nil
end

function N:GetOrCreateNode(mapID, x, y, poolName)
    if not mapID or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    x = RoundCoord(x)
    y = RoundCoord(y)
    if not x or not y then
        return nil
    end

    local coordKey = GetCoordKey(x, y)
    P.db.nodes[mapID] = P.db.nodes[mapID] or {}
    local bucket = P.db.nodes[mapID]
    local now = time()
    local node = bucket[coordKey]
    if not node then
        node = {
            mapID = mapID,
            mapName = P:GetMapName(mapID),
            subZone = GetSubZoneSafe(),
            coordKey = coordKey,
            x = x,
            y = y,
            name = poolName or "Fishing Pool",
            fish = {},
            note = "",
            discovered = now,
            lastSeen = now,
            seenCount = 0,
            catchCount = 0,
            lastObservedAt = 0,
            lastCatchAt = 0,
        }
        bucket[coordKey] = node
    end

    node.mapID = mapID
    node.mapName = P:GetMapName(mapID)
    node.subZone = GetSubZoneSafe()
    node.coordKey = coordKey
    node.x = x
    node.y = y
    node.name = poolName or node.name or "Fishing Pool"
    node.updatedAt = now
    return node
end

function N:ObserveNode(mapID, x, y, poolName)
    local node = self:GetOrCreateNode(mapID, x, y, poolName)
    if not node then
        return nil
    end

    local now = time()
    if (now - (node.lastObservedAt or 0)) > 10 then
        node.seenCount = (node.seenCount or 0) + 1
        node.lastObservedAt = now
    end
    node.lastSeen = now
    node.name = poolName or node.name

    P:MarkDirty()
    P:RecordRecentNode(node)
    self:QueueRefresh()
    return node
end

function N:RecordCatchAtNode(mapID, x, y, poolName, fishName)
    local node = self:GetOrCreateNode(mapID, x, y, poolName)
    if not node then
        return nil
    end

    local now = time()
    node.lastSeen = now
    node.lastCatchAt = now
    node.catchCount = (node.catchCount or 0) + 1
    node.name = poolName or node.name
    if type(fishName) == "string" and fishName ~= "" then
        node.fish[fishName] = (node.fish[fishName] or 0) + 1
    end

    P:MarkDirty()
    P:RecordRecentNode(node)
    self:QueueRefresh()
    return node
end

function N:ImportNode(data)
    if type(data) ~= "table" then
        return nil
    end
    local node = self:GetOrCreateNode(data.mapID, data.x, data.y, data.name)
    if not node then
        return nil
    end
    node.lastSeen = data.lastSeen or node.lastSeen
    node.discovered = data.discovered or node.discovered
    node.seenCount = math.max(node.seenCount or 0, data.seenCount or 0)
    node.catchCount = math.max(node.catchCount or 0, data.catchCount or 0)
    node.mapName = data.mapName or node.mapName
    node.subZone = data.subZone or node.subZone
    node.note = data.note or node.note or ""
    if type(data.fish) == "table" then
        for fishName, count in pairs(data.fish) do
            node.fish[fishName] = math.max(node.fish[fishName] or 0, tonumber(count) or 0)
        end
    end
    P:MarkDirty()
    self:QueueRefresh()
    return node
end

function N:SetNodeNote(mapID, coordKey, note)
    local node = self:GetNode(mapID, coordKey)
    if not node then
        return false
    end
    node.note = type(note) == "string" and note or ""
    node.updatedAt = time()
    P:MarkDirty()
    self:QueueRefresh()
    return true
end

-- Static secret-fish locations imported from HandyNotes_SecretFish (see
-- Data/SecretFish.lua). Deliberately NOT folded into IterateNodes: those are
-- pools the player has personally discovered and are sorted by lastSeen, while
-- these are reference data with no discovery state. They share the map pin
-- pool and nothing else.
---@param mapID number
---@return table[] entries node-shaped tables, empty when the map has none
function N:GetSecretFish(mapID)
    local out = {}
    local data = P.Data and P.Data.SecretFish
    if not mapID or type(data) ~= "table" then
        return out
    end
    local bucket = data[mapID]
    if type(bucket) ~= "table" then
        return out
    end
    for _, entry in ipairs(bucket) do
        out[#out + 1] = {
            mapID       = mapID,
            mapName     = P:GetMapName(mapID),
            x           = entry.x,
            y           = entry.y,
            name        = entry.name or "Secret Fish",
            achievement = entry.achievement,
            criteria    = entry.criteria,
            loot        = entry.loot,
            quests      = entry.quests,
            note        = entry.note,
            isSecret    = true,
        }
    end
    return out
end

function N:IterateNodes(mapID)
    local out = {}
    if mapID then
        local bucket = P.db.nodes[mapID] or {}
        for _, node in pairs(bucket) do
            out[#out + 1] = node
        end
    else
        for _, bucket in pairs(P.db.nodes) do
            for _, node in pairs(bucket) do
                out[#out + 1] = node
            end
        end
    end
    table.sort(out, function(a, b)
        if (a.lastSeen or 0) == (b.lastSeen or 0) then
            return (a.name or "") < (b.name or "")
        end
        return (a.lastSeen or 0) > (b.lastSeen or 0)
    end)
    return out
end

function N:GetNodeTotals()
    local nodeCount = 0
    local learnedLinks = 0
    for _, bucket in pairs(P.db.nodes) do
        for _, node in pairs(bucket) do
            nodeCount = nodeCount + 1
            learnedLinks = learnedLinks + self:GetFishCount(node)
        end
    end
    return nodeCount, learnedLinks
end

function N:GetPoolStats(poolName, mapID)
    if type(poolName) ~= "string" or poolName == "" then
        return nil
    end

    local stats = {
        seenCount = 0,
        catchCount = 0,
        lastSeen = nil,
        learned = {},
    }
    local learnedSet = {}

    for _, node in ipairs(self:IterateNodes(mapID)) do
        if node.name == poolName then
            stats.seenCount = stats.seenCount + (node.seenCount or 0)
            stats.catchCount = stats.catchCount + (node.catchCount or 0)
            if (node.lastSeen or 0) > (stats.lastSeen or 0) then
                stats.lastSeen = node.lastSeen
            end
            for fishName in pairs(node.fish or {}) do
                learnedSet[fishName] = true
            end
        end
    end

    for fishName in pairs(learnedSet) do
        stats.learned[#stats.learned + 1] = fishName
    end
    table.sort(stats.learned)
    return stats
end

-- Pass right-click through to the map so right-click-to-zoom-out still works.
--
-- SetPassThroughButtons is protected: insecure callers are blocked while in
-- combat lockdown, and pins are created lazily from RefreshPins, which fires on
-- WorldMapFrame's OnShow -- openable mid-fight. So apply it out of combat only
-- and retry on the next refresh. Unlike the MapCanvas-pooled pins in Harvest /
-- Villa / Nemesis these are plain frames that never go through AcquirePin, so
-- Blizzard's CheckMouseButtonPassthrough never touches them and no no-op shadow
-- is needed -- our own call is the only caller.
local function ApplyPinPassThrough(pin)
    if pin._passThroughApplied or InCombatLockdown() then
        return
    end
    if pin.SetPassThroughButtons then
        pin._passThroughApplied = true
        pin:SetPassThroughButtons("RightButton")
    end
end

function N:CreatePin(parent)
    local pin = CreateFrame("Button", nil, parent)
    pin:SetSize(P.settings.pinSize or 16, P.settings.pinSize or 16)
    pin:EnableMouse(true)
    ApplyPinPassThrough(pin)

    pin.Icon = pin:CreateTexture(nil, "ARTWORK")
    pin.Icon:SetAllPoints()
    pin.Icon:SetTexture([[Interface\Minimap\Tracking\Fish]])

    pin:SetScript("OnEnter", function(self)
        if not self.nodeData then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.nodeData.name or "Fishing Pool")
        GameTooltip:AddLine(string.format("%s  %.1f, %.1f", self.nodeData.mapName or ("Map " .. tostring(self.nodeData.mapID or 0)), (self.nodeData.x or 0) * 100, (self.nodeData.y or 0) * 100), 0.8, 0.84, 0.9)
        if self.nodeData.subZone and self.nodeData.subZone ~= "" then
            GameTooltip:AddLine(self.nodeData.subZone, 0.62, 0.67, 0.76)
        end
        if self.nodeData.isSecret then
            -- Reference point, not a pool the player has found: show what it
            -- counts toward rather than catch history.
            GameTooltip:AddLine("Secret Fish", 0.55, 0.82, 0.95)
            if self.nodeData.achievement then
                local info = C_AchievementInfo and select(2, GetAchievementInfo(self.nodeData.achievement))
                GameTooltip:AddLine(info or ("Achievement " .. self.nodeData.achievement), 0.72, 0.76, 0.85)
            end
            if self.nodeData.note then
                GameTooltip:AddLine(self.nodeData.note, 0.62, 0.67, 0.76, true)
            end
        elseif P.MapTooltip and P.MapTooltip.AppendPoolTooltip then
            P.MapTooltip:AppendPoolTooltip(GameTooltip, self.nodeData.name, self.nodeData.mapID, self.nodeData)
        end
        GameTooltip:Show()
    end)

    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    pin:SetScript("OnClick", function(self)
        -- Secret-fish pins are reference points with no stored node, so there
        -- is no coordKey to open a detail view for.
        if self.nodeData and self.nodeData.isSecret then
            return
        end
        if P.UI and P.UI.ShowNode and self.nodeData then
            P.UI:ShowNode(self.nodeData.mapID, self.nodeData.coordKey)
        end
    end)

    return pin
end

function N:EnsureMapSupport()
    if self.worldMapFrame and self.canvas then
        return true
    end
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer or not WorldMapFrame.ScrollContainer.Child then
        return false
    end
    self.worldMapFrame = WorldMapFrame
    self.canvas = WorldMapFrame.ScrollContainer.Child
    self.activePins = self.activePins or {}

    if not self.hookedMap then
        self.hookedMap = true
        WorldMapFrame:HookScript("OnShow", function()
            N:QueueRefresh()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            if N.activePins then
                for _, pin in ipairs(N.activePins) do
                    pin:Hide()
                end
            end
        end)
    end
    return true
end

function N:RefreshPins()
    if not self:EnsureMapSupport() or not self.canvas then
        return
    end

    for _, pin in ipairs(self.activePins or {}) do
        pin:Hide()
        pin.nodeData = nil
    end

    if not P.settings.enableMapPins then
        return
    end

    local mapID = self.worldMapFrame and self.worldMapFrame.GetMapID and self.worldMapFrame:GetMapID() or nil
    if not mapID then
        return
    end

    local width = self.canvas:GetWidth()
    local height = self.canvas:GetHeight()
    if width <= 0 or height <= 0 then
        return
    end

    -- Discovered pools first, then the static secret-fish reference points.
    -- Both share the pin pool, so the index runs across the two lists.
    local toDraw = self:IterateNodes(mapID)
    if P.settings.showSecretFish ~= false then
        for _, node in ipairs(self:GetSecretFish(mapID)) do
            toDraw[#toDraw + 1] = node
        end
    end

    local index = 0
    for _, node in ipairs(toDraw) do
        index = index + 1
        local pin = self.activePins[index]
        if not pin then
            pin = self:CreatePin(self.canvas)
            self.activePins[index] = pin
        end
        -- Retry for pins created during combat lockdown.
        ApplyPinPassThrough(pin)
        pin:SetParent(self.canvas)
        pin:SetSize(P.settings.pinSize or 16, P.settings.pinSize or 16)
        pin.nodeData = node
        pin.Icon:SetTexture(node.isSecret
            and [[Interface\Minimap\Tracking\None]]
            or  [[Interface\Minimap\Tracking\Fish]])
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", self.canvas, "TOPLEFT", (node.x or 0) * width, -((node.y or 0) * height))
        pin:Show()
    end
end

function N:QueueRefresh()
    if self.refreshQueued then
        return
    end
    self.refreshQueued = true
    C_Timer.After(0.1, function()
        N.refreshQueued = false
        N:RefreshPins()
        P:QueueDataBroadcast("nodes")
    end)
end

function N:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", function()
        N:QueueRefresh()
    end)
    self.frame = frame

    self:EnsureMapSupport()
end
