local addonName, ns = ...

local existing = _G.FabledUI_Poseidon or {}
local P = existing
_G.FabledUI_Poseidon = P

P.ADDON_NAME = addonName
P.VERSION = "3.5.0"
P.NAMESPACE = ns or {}
P.FISHING_JOURNAL_SPELL_ID = 271990

-- P1: Rare fish ID placeholder. Populated later by the FishingTracker mine.
-- Keys are itemIDs, values are truthy markers (true or rarity descriptor).
-- Consumers should treat a missing key as "not rare".
P.RareFishIDs = P.RareFishIDs or {}

-- P3: Fishing buff spell ID placeholder. Populated later by the data mine.
-- Keys are spellIDs, values are friendly labels used by the BuffTracker
-- HUD strip. `true` means "use the live spell name from C_Spell".
P.FishingBuffSpells = P.FishingBuffSpells or {}

-- P1/P2 helpers exposed for views and filters.
function P:IsRareFish(fishName, fishItemID)
    local id = fishItemID
    if not id and fishName then
        id = self:GetFishItemID(fishName)
    end
    if id and self.RareFishIDs[id] then
        return true
    end
    return false
end

function P:IsJunkFish(fishName, fishItemID)
    local id = fishItemID
    if not id and fishName then
        id = self:GetFishItemID(fishName)
    end
    if not id or not C_Item or not C_Item.GetItemQualityByID then
        return false
    end
    local quality = C_Item.GetItemQualityByID(id)
    if Enum and Enum.ItemQuality and Enum.ItemQuality.Poor then
        return quality == Enum.ItemQuality.Poor
    end
    return quality == 0
end

P.State = P.State or {
    lastPoolHover = nil,
    lastHoverTime = 0,
    lastPoolMapID = nil,
    lastPoolX = nil,
    lastPoolY = nil,
    pendingCast = nil,
    recentNodes = {},
    recentCatches = {},
}

local function ChatPrefix()
    return "|cff4fd1c5[Poseidon]|r"
end

function P:Print(...)
    print(ChatPrefix(), ...)
end

-- Opens Blizzard's spellbook to the Fishing entry (or the closest analog
-- the client exposes). Called from the toolkit Journal toggle + the HUD
-- "Open Fishing Journal" action — both used to call this without a
-- definition and threw a runtime error. We prefer C_AddOns.LoadAddOn on
-- Blizzard_ProfessionsBook (the modern container), falling back to the
-- legacy SpellBookFrame_OpenToCategory call site.
function P:OpenFishingJournal()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_ProfessionsBook")
    end

    -- 12.0 path: ProfessionsBookFrame is the unified secondary-profession UI.
    local frame = _G.ProfessionsBookFrame
    if frame and type(frame.Show) == "function" then
        pcall(frame.Show, frame)
        return true
    end

    -- Legacy path: classic SpellBookFrame with the secondary profession tab.
    if _G.ToggleSpellBook then
        pcall(_G.ToggleSpellBook, _G.BOOKTYPE_PROFESSION or "professions")
        return true
    end

    self:Print("Couldn't locate the Fishing journal — try /spellbook manually.")
    return false
end

function P:SafeStr(value)
    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" then
        return text
    end
    return ""
end

function P:NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end
    -- In WoW 12.0 secure contexts (TooltipDataProcessor callbacks), unit names
    -- arrive as "secret string" values whose methods cannot be called. pcall
    -- prevents 900+ errors per session; tainted names simply return nil.
    local ok, result = pcall(function()
        local trimmed = name:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed == "" then return nil end
        return trimmed:lower()
    end)
    return ok and result or nil
end

function P:InvalidateCaches()
    self._knownPoolLookup = nil
    self._knownFishLookup = nil
end

function P:GetKnownPoolLookup()
    if self._knownPoolLookup then
        return self._knownPoolLookup
    end

    local lookup = {
        ["open water"] = true,
    }

    local function addName(name)
        local normalized = self:NormalizeName(name)
        if normalized then
            lookup[normalized] = true
        end
    end

    if type(_G.FishIntel_PoolFishIndex) == "table" then
        for poolName in pairs(_G.FishIntel_PoolFishIndex) do
            addName(poolName)
        end
    end

    if self.Data and self.Data.Midnight then
        local midnight = self.Data.Midnight
        if type(midnight.zones) == "table" then
            for _, zoneInfo in pairs(midnight.zones) do
                if type(zoneInfo) == "table" and type(zoneInfo.pools) == "table" then
                    for _, poolName in ipairs(zoneInfo.pools) do
                        addName(poolName)
                    end
                end
            end
        end
        if type(midnight.specialPools) == "table" then
            for _, entry in ipairs(midnight.specialPools) do
                if type(entry) == "table" then
                    addName(entry.name)
                end
            end
        end
    end

    self._knownPoolLookup = lookup
    return lookup
end

function P:GetKnownFishLookup()
    if self._knownFishLookup then
        return self._knownFishLookup
    end

    local lookup = {}
    local function addName(name)
        local normalized = self:NormalizeName(name)
        if normalized then
            lookup[normalized] = true
        end
    end

    if type(_G.FishIntel_FishItems) == "table" then
        for fishName in pairs(_G.FishIntel_FishItems) do
            addName(fishName)
        end
    end

    if type(_G.FishIntel_PoolFishIndex) == "table" then
        for _, fishList in pairs(_G.FishIntel_PoolFishIndex) do
            if type(fishList) == "table" then
                for _, fishName in ipairs(fishList) do
                    addName(fishName)
                end
            end
        end
    end

    if self.Data and self.Data.Midnight and type(self.Data.Midnight.fish) == "table" then
        for _, fishGroup in pairs(self.Data.Midnight.fish) do
            if type(fishGroup) == "table" then
                for _, fishInfo in ipairs(fishGroup) do
                    if type(fishInfo) == "table" then
                        addName(fishInfo.name)
                    end
                end
            end
        end
    end

    self._knownFishLookup = lookup
    return lookup
end

function P:IsKnownFishName(name)
    local normalized = self:NormalizeName(name)
    return normalized and self:GetKnownFishLookup()[normalized] == true or false
end

function P:GetFishItemID(fishName)
    if type(fishName) ~= "string" then
        return nil
    end
    local items = _G.FishIntel_FishItems or (self.Data and self.Data.FishItems)
    if type(items) == "table" then
        return items[fishName]
    end
    return nil
end

function P:LooksLikeFishingPool(name)
    local normalized = self:NormalizeName(name)
    if not normalized then
        return false
    end

    if self:GetKnownPoolLookup()[normalized] then
        return true
    end

    local keywords = {
        "pool", "school", "swarm", "ripple", "torrent", "bloom", "vortex",
        "cargo", "treasure", "surge", "void", "waves", "wave", "slick",
    }
    for _, keyword in ipairs(keywords) do
        if normalized:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

function P:GetCurrentMapPosition()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return mapID, nil, nil
    end

    local x, y = position:GetXY()
    return mapID, x, y
end

function P:GetMapName(mapID)
    if not mapID or not C_Map or not C_Map.GetMapInfo then
        return "Unknown Map"
    end
    local mapInfo = C_Map.GetMapInfo(mapID)
    return (mapInfo and mapInfo.name) or ("Map " .. tostring(mapID))
end

function P:GetZoneOpenWaterFish(zoneName)
    local lookup = _G.FishIntel_ZoneOpenWaterFish
    if type(lookup) ~= "table" or type(zoneName) ~= "string" then
        return nil
    end
    return lookup[zoneName]
end

function P:GetCurrentZoneName(mapID)
    local subZone = GetSubZoneText and GetSubZoneText() or nil
    if type(subZone) == "string" and subZone ~= "" then
        return subZone
    end
    return self:GetMapName(mapID)
end

local function InitCallbacks()
    if P.callbacks then
        return
    end

    if CreateFromMixins and CallbackRegistryMixin then
        local registry = CreateFromMixins(CallbackRegistryMixin)
        registry:OnLoad()
        registry:SetUndefinedEventsAllowed(true)
        P.callbacks = registry
        return
    end

    local registry = { listeners = {} }
    function registry:RegisterCallback(eventName, func, owner)
        self.listeners[eventName] = self.listeners[eventName] or {}
        table.insert(self.listeners[eventName], { func = func, owner = owner })
        return owner or func
    end
    function registry:UnregisterCallback(eventName, owner)
        local bucket = self.listeners[eventName]
        if not bucket then
            return
        end
        for index = #bucket, 1, -1 do
            if bucket[index].owner == owner then
                table.remove(bucket, index)
            end
        end
    end
    function registry:TriggerEvent(eventName, ...)
        local bucket = self.listeners[eventName]
        if not bucket then
            return
        end
        for _, entry in ipairs(bucket) do
            entry.func(entry.owner, ...)
        end
    end
    P.callbacks = registry
end

function P:RegisterCallback(eventName, func, owner)
    InitCallbacks()
    return self.callbacks:RegisterCallback(eventName, func, owner)
end

function P:UnregisterCallback(eventName, owner)
    if not self.callbacks then
        return
    end
    self.callbacks:UnregisterCallback(eventName, owner)
end

function P:TriggerEvent(eventName, ...)
    if not self.callbacks then
        return
    end
    self.callbacks:TriggerEvent(eventName, ...)
end

function P:MarkDirty()
    if DataVault and DataVault.dirtyFlags then
        DataVault.dirtyFlags["FabledUI_DataVault_Poseidon"] = true
    end
end

function P:QueueDataBroadcast(reason)
    if self._dataBroadcastQueued then
        self._lastBroadcastReason = reason or self._lastBroadcastReason or "data"
        return
    end

    self._dataBroadcastQueued = true
    self._lastBroadcastReason = reason or "data"
    C_Timer.After(0.05, function()
        P._dataBroadcastQueued = false
        local finalReason = P._lastBroadcastReason or "data"
        P._lastBroadcastReason = nil
        P:TriggerEvent("Poseidon.DataChanged", finalReason)
    end)
end

function P:RecordRecentNode(node)
    if type(node) ~= "table" then
        return
    end

    local key = tostring(node.mapID or 0) .. ":" .. (node.coordKey or "")
    local recent = self.State.recentNodes
    for index = #recent, 1, -1 do
        if recent[index].key == key then
            table.remove(recent, index)
        end
    end

    table.insert(recent, 1, {
        key = key,
        mapID = node.mapID,
        coordKey = node.coordKey,
        name = node.name,
        mapName = node.mapName,
        subZone = node.subZone,
        x = node.x,
        y = node.y,
        lastSeen = node.lastSeen,
        fishCount = node.fish and P.Nodes and P.Nodes:GetFishCount(node) or 0,
    })

    while #recent > 20 do
        table.remove(recent)
    end
end

function P:RecordRecentCatch(itemName, poolName, isFish)
    if type(itemName) ~= "string" or itemName == "" then
        return
    end

    local recent = self.State.recentCatches
    table.insert(recent, 1, {
        itemName = itemName,
        poolName = poolName,
        isFish = isFish == true,
        at = time(),
    })

    while #recent > 12 do
        table.remove(recent)
    end
end

function P:OpenSettings()
    if Settings and Settings.OpenToCategory and self.CategoryID then
        Settings.OpenToCategory(self.CategoryID)
    else
        self:Print("Settings are not ready yet.")
    end
end

function P:IsHUDShown()
    return self.UI and self.UI.IsHUDShown and self.UI:IsHUDShown() or false
end

function P:ShowHUD(reason)
    if self.UI and self.UI.ShowHUD then
        self.UI:ShowHUD(reason)
    end
end

function P:HideHUD()
    if self.UI and self.UI.HideHUD then
        self.UI:HideHUD()
    end
end

function P:ToggleHUD()
    if self.UI and self.UI.ToggleHUD then
        self.UI:ToggleHUD()
    end
end

function P:ToggleUI()
    self:ToggleHUD()
end

function P:ShowUI()
    self:ShowHUD("nexus")
end

function P:OpenUI()
    self:ShowHUD("nexus")
end

function P:LaunchUI()
    self:ShowHUD("nexus")
end

function P:OpenMainWindow()
    self:ShowFull()
end

function P:ShowFull(page)
    if self.UI and self.UI.ShowFull then
        self.UI:ShowFull(page)
    end
end

function P:HandleSlashCommand(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()

    if command == "" or command == "hud" then
        self:ToggleHUD()
    elseif command == "full" then
        self:ShowFull(rest ~= "" and rest or nil)
    elseif command == "settings" then
        self:OpenSettings()
    elseif command == "import" then
        if self.ImportExport then
            self.ImportExport:OpenImportWindow()
        end
    elseif command == "export" then
        if self.ImportExport then
            self.ImportExport:OpenExportWindow()
        end
    elseif command == "zones" or command == "fish" or command == "nodes" or command == "sharing" or command == "overview" then
        self:ShowFull(command)
    elseif command == "minimap" then
        if self.Minimap then
            self.Minimap:ToggleVisibility()
        end
    else
        self:Print("/poseidon - toggle HUD")
        self:Print("/poseidon full - open full browser")
        self:Print("/poseidon zones | fish | nodes | sharing")
        self:Print("/poseidon settings | import | export | minimap")
    end
end

-- Merge imported Tier-3 fish-ID datasets into the live runtime lookup so the
-- Rare-only / Special filters in the Fish catalog resolve against actual IDs
-- rather than the empty placeholder declared at the top of this file. Skips
-- metadata keys (string-keyed __source/__version/__notes) and accepts either
-- `true` markers or descriptor strings.
local function PopulateFishLookups()
    P.RareFishIDs = P.RareFishIDs or {}
    if P.Data and type(P.Data.RareFish) == "table" then
        for id, value in pairs(P.Data.RareFish) do
            if type(id) == "number" and value ~= nil and value ~= false then
                P.RareFishIDs[id] = value
            end
        end
    end
    if P.Data and type(P.Data.SpecialFish) == "table" then
        for id, value in pairs(P.Data.SpecialFish) do
            if type(id) == "number" and value ~= nil and value ~= false and P.RareFishIDs[id] == nil then
                P.RareFishIDs[id] = value
            end
        end
    end

    -- P0 (May-04 audit): mirror P.Data.FishingBuffs into the truthy
    -- lookup that BuffTracker.lua:91 reads. Data/FishingBuffs.lua already
    -- performs this merge at file-parse time; we re-run it at PLAYER_LOGIN
    -- so a hot-reload or out-of-order load still leaves the table populated.
    P.FishingBuffSpells = P.FishingBuffSpells or {}
    if P.Data and type(P.Data.FishingBuffs) == "table" then
        for id, def in pairs(P.Data.FishingBuffs) do
            if type(id) == "number" then
                if type(def) == "table" then
                    P.FishingBuffSpells[id] = def.label or true
                elseif def then
                    P.FishingBuffSpells[id] = def
                end
            end
        end
    end

    -- P1-11: fishing-channel spell-ID set (replaces 14-keyword regex).
    P.FishingSpellIDs = P.FishingSpellIDs or {}
    if P.Data and type(P.Data.FishingSpellIDs) == "table" then
        for id, def in pairs(P.Data.FishingSpellIDs) do
            if type(id) == "number" then
                if type(def) == "table" then
                    P.FishingSpellIDs[id] = def.label or true
                elseif def then
                    P.FishingSpellIDs[id] = def
                end
            end
        end
    end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    InitCallbacks()
    PopulateFishLookups()
    if P.ResolveStorage then
        P:ResolveStorage()
    end

    if P.Stats and P.Stats.Init then
        P.Stats:Init()
    end
    if P.Nodes and P.Nodes.Init then
        P.Nodes:Init()
    end
    if P.Derby and P.Derby.Init then
        P.Derby:Init()
    end
    if P.Events and P.Events.Init then
        P.Events:Init()
    end
    if P.Learn and P.Learn.Init then
        P.Learn:Init()
    end
    if P.MapTooltip and P.MapTooltip.Init then
        P.MapTooltip:Init()
    end
    if P.Minimap and P.Minimap.Init then
        P.Minimap:Init()
    end
    -- P3: BuffTracker attaches before UI:Init so the HUD render path can
    -- pull a populated status line on first paint.
    if P.BuffTracker and P.BuffTracker.Init then
        P.BuffTracker:Init()
    end
    -- Journal companion: opens the Fishing journal + nudges the UI companion.
    -- Init wires an event frame that refreshes the status line on SPELLS_CHANGED.
    if P.Journal and P.Journal.Init then
        P.Journal:Init()
    end
    if P.UI and P.UI.Init then
        P.UI:Init()
    end
    if P.Settings and P.Settings.Register then
        P.Settings:Register()
    end

    SLASH_FABLEDUI_POSEIDON1 = "/poseidon"
    SLASH_FABLEDUI_POSEIDON2 = "/fish"
    SlashCmdList["FABLEDUI_POSEIDON"] = function(msg)
        P:HandleSlashCommand(msg)
    end

    _G.FabledUI_Poseidon_ToggleUI = function() P:ToggleHUD() end
    _G.FabledUI_Poseidon_ShowUI = function() P:ShowHUD("nexus") end
    _G.FabledUI_Poseidon_OpenUI = function() P:ShowHUD("nexus") end
    _G.FabledUI_Poseidon_LaunchUI = function() P:ShowHUD("nexus") end
    _G.FabledUI_Poseidon_OpenMainWindow = function() P:ShowFull() end

    P:Print("Online. /poseidon for the HUD.")
end)
