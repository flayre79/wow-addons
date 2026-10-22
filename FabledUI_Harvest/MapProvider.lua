local H = FabledUI_Harvest
H.MapProvider = {}

local PIN_COLORS = {
    herb     = { r = 0.2, g = 1.0, b = 0.2 },
    ore      = { r = 0.7, g = 0.7, b = 0.8 },
    fish     = { r = 0.2, g = 0.5, b = 1.0 },
    treasure = { r = 1.0, g = 0.8, b = 0.0 },
    lumber   = { r = 0.8, g = 0.4, b = 0.0 },
    skin     = { r = 0.9, g = 0.6, b = 0.4 },
}

-- =============================================================================
-- Pin mixin
-- =============================================================================
-- 12.x: there is no WorldMapFrame:RegisterPinTemplate. Pins are registered by
-- creating a pin pool directly in WorldMapFrame.pinPools (see H.MapProvider:Init).
-- The pin exposes hover via OnMouseEnter/OnMouseLeave *methods* — AcquirePin
-- wires those itself and asserts no OnEnter/OnLeave *script* is set on the pin,
-- so setting scripts here would throw Blizzard_MapCanvas.lua:280 "assertion failed!".
-- =============================================================================

local PinMixin = CreateFromMixins(MapCanvasPinMixin)

function PinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_VIGNETTE")
    self:SetSize(14, 14)
    if not self.Texture then
        self.Texture = self:CreateTexture(nil, "ARTWORK")
        self.Texture:SetAllPoints()
        self.Texture:SetTexture("Interface\\Minimap\\Tracking\\None")
    end
    -- Cluster count badge (shown only when this pin represents N>1 nodes)
    if not self.Badge then
        self.Badge = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.Badge:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 4, -3)
        self.Badge:SetTextColor(1, 1, 1)
        self.Badge:Hide()
    end
end

function PinMixin:OnMouseEnter()
    if not self.nodeData then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.nodeData.name or "Gathering Node")
    GameTooltip:AddLine("Type: " .. (self.nodeData.type or "Unknown"), 1, 1, 1)
    if self.clusterCount and self.clusterCount > 1 then
        GameTooltip:AddLine("Cluster: " .. self.clusterCount .. " nearby nodes", 0.7, 0.7, 1)
        if self.clusterMembers then
            local seen = {}
            for _, member in ipairs(self.clusterMembers) do
                local key = member.type or "?"
                seen[key] = (seen[key] or 0) + 1
            end
            for typ, n in pairs(seen) do
                GameTooltip:AddLine(string.format("  %s x%d", typ, n), 0.9, 0.9, 0.9)
            end
        end
    end
    GameTooltip:Show()
end

function PinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- 12.x taint guard. Blizzard's AcquirePin calls pin:CheckMouseButtonPassthrough
-- (MapCanvas_DataProviderBase.lua:290), which calls the *protected*
-- Frame:SetPassThroughButtons(). Protected functions are blocked for insecure
-- callers while in combat lockdown, and RefreshAllData reaches AcquirePin from
-- our own code (SaveNode -> RefreshPins), so gathering while in combat produced
-- ADDON_ACTION_BLOCKED. Same workaround HandyNotes / Plumber / HereBeDragons
-- use: shadow the method with a no-op so Blizzard's unconditional call is inert,
-- and invoke the real one ourselves exactly once, only when out of combat.
function PinMixin:SetPassThroughButtons() end

function PinMixin:ApplyPassThrough()
    if self._passThroughApplied or InCombatLockdown() then
        return
    end
    local orig = self._origSetPassThroughButtons
    if orig then
        self._passThroughApplied = true
        orig(self, "RightButton")
    end
end

-- Gathering pins are hover-only; clicks are no-ops (but must exist because
-- AcquirePin routes OnMouseUp -> pin:OnMouseUp/pin:OnClick for mouse-enabled pins).
function PinMixin:OnClick() end
function PinMixin:OnMouseUp() end
function PinMixin:OnMouseDown() end

function PinMixin:OnAcquired(node, x, y, clusterCount, clusterMembers)
    self.nodeData = node
    self.clusterCount = clusterCount or 1
    self.clusterMembers = clusterMembers
    self:SetPosition(x, y)
    -- Retry for pins whose first acquire happened during combat lockdown.
    self:ApplyPassThrough()
    local c = PIN_COLORS[node and node.type] or { r = 1, g = 1, b = 1 }
    if self.Texture then
        self.Texture:SetVertexColor(c.r, c.g, c.b)
    end
    -- "(N)" badge for clustered pins; also slightly upsizes the icon to mimic
    -- a stacked-icon appearance.
    if self.Badge then
        if self.clusterCount > 1 then
            self.Badge:SetText("(" .. self.clusterCount .. ")")
            self.Badge:Show()
            self:SetSize(18, 18)
        else
            self.Badge:Hide()
            self:SetSize(14, 14)
        end
    end
end

function PinMixin:OnReleased()
    self.nodeData = nil
    self.clusterCount = nil
    self.clusterMembers = nil
    if self.Texture then
        self.Texture:SetVertexColor(1, 1, 1)
    end
    if self.Badge then
        self.Badge:Hide()
    end
    self:SetSize(14, 14)
end

-- =============================================================================
-- Data provider
-- =============================================================================

local function CreateHarvestPin()
    local pin = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
    -- Stash the real C method before the mixin shadows it with the no-op.
    pin._origSetPassThroughButtons = pin.SetPassThroughButtons
    Mixin(pin, PinMixin)
    pin:EnableMouse(true)
    -- Pass right-click through to the map so right-click-to-zoom-out still works.
    pin:ApplyPassThrough()
    return pin
end

local function ResetHarvestPin(_, pin)
    pin:Hide()
    pin:ClearAllPoints()
    if pin.OnReleased then pin:OnReleased() end
    pin.pinTemplate = nil
    pin.owningMap = nil
end

function H.MapProvider:Init()
    if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
        return
    end
    if self.provider then
        return
    end

    -- 12.x: there is no WorldMapFrame:RegisterPinTemplate. Register a pin pool
    -- directly (mirrors HereBeDragons-Pins-2.0). The factory enables mouse and
    -- exposes hover as methods so AcquirePin's "no OnEnter/OnLeave script"
    -- assertion (Blizzard_MapCanvas.lua:280) passes.
    if not WorldMapFrame.pinPools["FabledUI_HarvestPin"] then
        local pool
        if CreateUnsecuredRegionPoolInstance then
            pool = CreateUnsecuredRegionPoolInstance("FabledUI_HarvestPin")
        else
            pool = CreateObjectPool(CreateHarvestPin, ResetHarvestPin)
        end
        pool.parent = WorldMapFrame:GetCanvas()
        pool.createFunc = CreateHarvestPin
        pool.resetFunc = ResetHarvestPin
        pool.creationFunc = CreateHarvestPin
        pool.resetterFunc = ResetHarvestPin
        WorldMapFrame.pinPools["FabledUI_HarvestPin"] = pool
    end

    local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function Provider:RefreshAllData()
        local map = self:GetMap()
        if not map then return end
        map:RemoveAllPinsByTemplate("FabledUI_HarvestPin")

        local mapID = map:GetMapID()
        if not mapID or not H.db or not H.db.nodes or not H.db.nodes[mapID] then
            return
        end

        -- Step 1: build the raw pin list from saved nodes.
        local rawPins = {}
        for coordKey, node in pairs(H.db.nodes[mapID]) do
            if node and H.settings and H.settings.layers and H.settings.layers[node.type] then
                local sx, sy = strsplit(",", coordKey)
                local x, y = tonumber(sx), tonumber(sy)
                if x and y then
                    rawPins[#rawPins + 1] = {
                        x = x, y = y,
                        type = node.type,
                        node = node,
                        coordKey = coordKey,
                    }
                end
            end
        end

        -- Step 1b: fold in imported reference nodes for this map.
        --
        -- These are read-only: they never enter H.db, so they cannot be
        -- exported as if the player had found them and they carry no lastSeen
        -- to age. They are marked so the tooltip can say where they came from.
        if H.ForEachImportedNode and (not H.settings or H.settings.showImportedNodes ~= false) then
            local layers = H.settings and H.settings.layers
            local imported = H:GetImportedNodes(mapID)
            if imported then
                for layer in pairs(imported) do
                    if not layers or layers[layer] then
                        H:ForEachImportedNode(mapID, layer, function(x, y)
                            rawPins[#rawPins + 1] = {
                                x = x, y = y,
                                type = layer,
                                node = { type = layer, name = layer, imported = true },
                                imported = true,
                            }
                        end)
                    end
                end
            end
        end

        -- Step 2: cluster nearby pins of the same type before painting.
        -- Radius is configurable via settings.clusterRadius (defaults to the
        -- module default of 60). Type-grouped so herbs/ore don't merge.
        local clusters
        if H.Clustering and H.Clustering.ClusterPins then
            local radius = (H.settings and H.settings.clusterRadius) or H.Clustering.DEFAULT_RADIUS
            clusters = H.Clustering:ClusterPins(rawPins, radius, "type")
        else
            -- Fallback: treat each pin as its own cluster.
            clusters = {}
            for _, p in ipairs(rawPins) do
                clusters[#clusters + 1] = { p, x = p.x, y = p.y, type = p.type, count = 1 }
            end
        end

        -- Step 3: paint one pin per cluster. Anchor pin's node data + count.
        for _, cluster in ipairs(clusters) do
            local anchor = cluster[1]
            if anchor then
                local pin = map:AcquirePin("FabledUI_HarvestPin",
                                           anchor.node, anchor.x, anchor.y,
                                           cluster.count or #cluster, cluster)
                if pin then pin:Show() end
            end
        end
    end

    -- Flush any capture that happened while the map was closed (see RefreshPins).
    function Provider:OnShow()
        if self.pendingRefresh then
            self.pendingRefresh = nil
            self:RefreshAllData()
        end
    end

    if WorldMapFrame.AddDataProvider then
        WorldMapFrame:AddDataProvider(Provider)
        self.provider = Provider
    end
end

function H.MapProvider:RefreshPins()
    local provider = self.provider
    if not provider then return end
    -- Repainting a closed map is pure waste (SaveNode calls this on every
    -- capture) and it is what dragged AcquirePin onto our tainted call path in
    -- the first place. Defer to the provider's OnShow instead.
    if not WorldMapFrame:IsShown() then
        provider.pendingRefresh = true
        return
    end
    provider:RefreshAllData()
end
