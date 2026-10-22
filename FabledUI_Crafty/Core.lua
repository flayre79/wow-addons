local addonName, ns = ...

local M = _G.FabledUI_Crafty or {}
_G.FabledUI_Crafty = M
ns.M = M

M.ADDON_NAME = addonName
M.DISPLAY_NAME = "Crafty"
M.VERSION = "3.1.0"
M.USE_UNIFIED_TOOLTIP_COMPOSER = true
M.EVENTS = CreateFrame("Frame")
if type(CreateFromMixins) == "function" and type(CallbackRegistryMixin) == "table" then
    M.callbacks = M.callbacks or CreateFromMixins(CallbackRegistryMixin)
    if M.callbacks.OnLoad then
        M.callbacks:OnLoad()
    end
    if M.callbacks.GenerateCallbackEvents then
        M.callbacks:GenerateCallbackEvents({
            "StorageReady",
            "DataChanged",
            "QueueChanged",
            "AltDataChanged",
            "RecipeFiltersChanged",
            "HistoryChanged",
            "GuildRosterUpdated",
            "GuildCraftersUpdated",
        })
    end
else
    M.callbacks = M.callbacks or {}
end

local function safePrint(...)
    print("|cff5cf0a0[Crafty]|r", ...)
end

-- Lightweight bootstrap profiler. Each safeCall records a ms timing for its
-- label so we can identify what's actually expensive at boot / first-open.
-- The accumulated table is flushed via M:PrintBootProfile() (also bound to
-- /crafty profile). Use debugprofilestart/stop which give us monotonic ms.
M._bootProfile = M._bootProfile or {}

local function timedCall(label, func)
    if type(func) ~= "function" then return end
    local startMS = (debugprofilestop and debugprofilestop()) or 0
    local ok, err = xpcall(func, CallErrorHandler)
    local endMS = (debugprofilestop and debugprofilestop()) or 0
    local elapsed = endMS - startMS
    M._bootProfile[#M._bootProfile + 1] = { label = label, ms = elapsed, ok = ok }
    if not ok and err then
        safePrint(label .. " failed:", err)
    end
    return elapsed
end

-- Back-compat alias so existing call sites keep working.
local safeCall = timedCall

function M:PrintBootProfile()
    if not M._bootProfile or #M._bootProfile == 0 then
        safePrint("No bootstrap profile recorded yet.")
        return
    end
    -- Sort by descending ms so the worst offenders surface first.
    local rows = {}
    local total = 0
    for _, e in ipairs(M._bootProfile) do
        rows[#rows + 1] = e
        total = total + (e.ms or 0)
    end
    table.sort(rows, function(a, b) return (a.ms or 0) > (b.ms or 0) end)
    safePrint(string.format("|cffffd100Bootstrap profile|r (%d steps, %.1fms total)", #rows, total))
    for i = 1, math.min(#rows, 20) do
        local e = rows[i]
        local mark = e.ok and "" or " |cffff5555[FAIL]|r"
        safePrint(string.format("  %7.1fms  %s%s", e.ms or 0, e.label or "?", mark))
    end
end

function M:Print(...)
    safePrint(...)
end

function M:GetCurrentCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Realm"
    return string.format("%s-%s", name, realm)
end

function M:GetShortCharacterName(characterKey)
    if not characterKey then
        return "Unknown"
    end
    return characterKey:match("^([^%-]+)") or characterKey
end

function M:MarkDirty()
    if DataVault and DataVault.dirtyFlags then
        DataVault.dirtyFlags["crafty"] = true
    end
end

function M:Fire(eventName, ...)
    if self.callbacks and self.callbacks.TriggerEvent then
        self.callbacks:TriggerEvent(eventName, ...)
    end
end

function M:RegisterCallback(owner, eventName, callback)
    if not owner or not eventName or not callback or not self.callbacks or not self.callbacks.RegisterCallback then
        return
    end
    self.callbacks:RegisterCallback(eventName, callback, owner)
end

function M:OpenSettings()
    if Settings and Settings.OpenToCategory and self.categoryID then
        Settings.OpenToCategory(self.categoryID)
    end
end

-- Loads the on-demand data pack (FabledUI_Crafty_Data) the first time any
-- consumer needs it. The original 31,714-line KnowledgeData.lua was split
-- into 11 sibling per-profession LoD addons (see EnsureProfessionKnowledgeLoaded),
-- so this LoD shard now only carries shared data: Training, TokenTooltip,
-- Assistance, MaterialSources, VendorSources, RecipeSources,
-- ConcentrationCurves, OptionalReagents, plus the slim MidnightTreasures
-- stub. Total parse cost is ~12k LOC instead of ~50k.
function M:EnsureDataLoaded()
    if self._dataLoaded then return true end
    if not (C_AddOns and C_AddOns.LoadAddOn) then
        self._dataLoaded = true
        return false
    end
    local startMS = (debugprofilestop and debugprofilestop()) or 0
    local ok, loaded = pcall(C_AddOns.LoadAddOn, "FabledUI_Crafty_Data")
    local elapsed = ((debugprofilestop and debugprofilestop()) or 0) - startMS
    self._bootProfile[#self._bootProfile + 1] = { label = "LoadAddOn(FabledUI_Crafty_Data)", ms = elapsed, ok = ok }
    self._dataLoaded = ok and (loaded or C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FabledUI_Crafty_Data") or false) or false
    -- Static packs just registered new RecipeSources rows; the merged-recipe
    -- memo must rebuild to include them.
    if self._dataLoaded and self.Recipes and self.Recipes.InvalidateMerged then
        self.Recipes:InvalidateMerged()
    end
    return self._dataLoaded
end

-- Per-profession LoD knowledge slice loader. Each call loads only the slice
-- for one profession (Alchemy / Blacksmithing / ... / Tailoring). Idempotent —
-- subsequent calls for an already-loaded profession are a no-op.
M._profKnowledgeLoaded = M._profKnowledgeLoaded or {}

local _knowledgeProfAddons = {
    Alchemy        = "FabledUI_Crafty_Data_Alchemy",
    Blacksmithing  = "FabledUI_Crafty_Data_Blacksmithing",
    Enchanting     = "FabledUI_Crafty_Data_Enchanting",
    Engineering    = "FabledUI_Crafty_Data_Engineering",
    Herbalism      = "FabledUI_Crafty_Data_Herbalism",
    Inscription    = "FabledUI_Crafty_Data_Inscription",
    Jewelcrafting  = "FabledUI_Crafty_Data_Jewelcrafting",
    Leatherworking = "FabledUI_Crafty_Data_Leatherworking",
    Mining         = "FabledUI_Crafty_Data_Mining",
    Skinning       = "FabledUI_Crafty_Data_Skinning",
    Tailoring      = "FabledUI_Crafty_Data_Tailoring",
}

-- Generic lazy-loader for the per-feature LoD data shards (Assistance,
-- Tokens, Training, Concentration, Vendors, Optional). Each shard is its own
-- addon (FabledUI_Crafty_Data_<Shard>) so the player only pays the parse
-- cost when the consumer actually needs the data.
M._featureShardLoaded = M._featureShardLoaded or {}

function M:EnsureFeatureShardLoaded(shardKey)
    if type(shardKey) ~= "string" then return false end
    if self._featureShardLoaded[shardKey] then return true end
    local addonName = "FabledUI_Crafty_Data_" .. shardKey
    if not (C_AddOns and C_AddOns.LoadAddOn) then
        self._featureShardLoaded[shardKey] = true
        return false
    end
    local startMS = (debugprofilestop and debugprofilestop()) or 0
    local ok, loaded = pcall(C_AddOns.LoadAddOn, addonName)
    local elapsed = ((debugprofilestop and debugprofilestop()) or 0) - startMS
    self._bootProfile[#self._bootProfile + 1] = { label = "LoadAddOn(" .. addonName .. ")", ms = elapsed, ok = ok }
    local nowLoaded = ok and (loaded or (C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName)) or false) or false
    self._featureShardLoaded[shardKey] = nowLoaded
    return nowLoaded
end

function M:EnsureProfessionKnowledgeLoaded(profession)
    if type(profession) ~= "string" then return false end
    if self._profKnowledgeLoaded[profession] then return true end
    local addonName = _knowledgeProfAddons[profession]
    if not addonName or not (C_AddOns and C_AddOns.LoadAddOn) then
        self._profKnowledgeLoaded[profession] = true -- avoid retry storm
        return false
    end
    local startMS = (debugprofilestop and debugprofilestop()) or 0
    local ok, loaded = pcall(C_AddOns.LoadAddOn, addonName)
    local elapsed = ((debugprofilestop and debugprofilestop()) or 0) - startMS
    self._bootProfile[#self._bootProfile + 1] = { label = "LoadAddOn(" .. addonName .. ")", ms = elapsed, ok = ok }
    local nowLoaded = ok and (loaded or (C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName)) or false) or false
    self._profKnowledgeLoaded[profession] = nowLoaded
    if nowLoaded and self.KnowledgeVignettes and self.KnowledgeVignettes.InvalidateCache then
        -- Newly-loaded profession may have tracked quests we should pick up.
        self.KnowledgeVignettes:InvalidateCache()
    end
    return nowLoaded
end

-- Convenience: load every profession the player currently has trained on the
-- active character. Called as a deferred warm-up shortly after login.
function M:WarmProfessionKnowledgeForCurrentCharacter()
    if not (GetProfessions and C_TradeSkillUI) then return end
    local indices = { GetProfessions() }
    for _, idx in ipairs(indices) do
        if type(idx) == "number" then
            local _, _, _, _, _, _, skillLineID = GetProfessionInfo(idx)
            if skillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
                local profKey = info and info.parentProfessionName or info and info.professionName
                if profKey and _knowledgeProfAddons[profKey] then
                    self:EnsureProfessionKnowledgeLoaded(profKey)
                end
            end
        end
    end
end

function M:RefreshAll()
    if self.EnsureStorageTables then
        self:EnsureStorageTables()
    end
    if self.Alts then
        self.Alts:ScanCurrentCharacterProfessions(false)
    end
    if self.Recipes and self.Recipes.ScanOpenProfession then
        self.Recipes:ScanOpenProfession(false)
    end
    if self.Concentration and self.Concentration.CaptureOpenProfession then
        self.Concentration:CaptureOpenProfession(false)
    end
    if self.Gear and self.Gear.ScanOpenProfessionGear then
        self.Gear:ScanOpenProfessionGear(false)
    end
    if self.Specs and self.Specs.CaptureOpenProfession then
        self.Specs:CaptureOpenProfession(false)
    end
    if self.Cooldowns and self.Cooldowns.ScanOpenProfession then
        self.Cooldowns:ScanOpenProfession(false)
    end
    if self.HUD then
        self.HUD:Refresh()
    end
    self:Fire("DataChanged")
end

local function RegisterSlashCommands()
    SLASH_FABLEDUI_CRAFTY1 = "/crafty"

    SlashCmdList["FABLEDUI_CRAFTY"] = function(msg)
        local cmd = (msg or ""):lower():match("^%s*(%S*)") or ""
        local rest = (msg or ""):match("^%s*%S*%s+(.*)$") or ""
        if cmd == "settings" then
            M:OpenSettings()
        elseif cmd == "queue" then
            if M.UI then
                M.UI:OpenToTab("queue")
            end
        elseif cmd == "alts" then
            if M.UI then
                M.UI:OpenToTab("alts")
            end
        elseif cmd == "trainers" then
            if M.UI then
                M.UI:OpenToTab("trainers")
            end
        elseif cmd == "concentration" or cmd == "timers" then
            if M.UI then
                M.UI:OpenToTab("timers")
            end
        elseif cmd == "data" or cmd == "log" then
            if M.UI then
                M.UI:OpenToTab("data")
            end
        elseif cmd == "advisor" then
            if M.UI then
                M.UI:OpenToTab("advisor")
            end
        elseif cmd == "knowledge" then
            if M.UI then
                M.UI:OpenToTab("knowledge")
            end
        elseif cmd == "guide" then
            if M.UI then
                M.UI:OpenToTab("guide")
            end
        elseif cmd == "gearing" or cmd == "gear" then
            if M.UI then
                M.UI:OpenToTab("gearing")
            end
        elseif cmd == "radar" then
            if M.HUD then
                M.HUD:TogglePinned()
            end
        elseif cmd == "shopping" then
            if M.UI then
                M.UI:ShowExportDialog("shopping")
            end
        elseif cmd == "export" then
            if M.UI then
                M.UI:ShowExportDialog("history")
            end
        elseif cmd == "refresh" then
            M:RefreshAll()
            M:Print("Profession and queue data refreshed.")
        elseif cmd == "scandebug" then
            M._craftyScanDebug = not M._craftyScanDebug
            M:Print("Recipe scan debug = " .. (M._craftyScanDebug and "ON" or "OFF"))
            if M.Recipes and M.Recipes.ScanOpenProfession then
                local n = M.Recipes:ScanOpenProfession(false)
                M:Print(string.format("Cached %d live recipes for the open profession.", tonumber(n) or 0))
            end
        elseif cmd == "profile" then
            M:PrintBootProfile()
        else
            -- Let sibling modules handle their own /crafty <cmd> before we
            -- fall back to toggling the main window. (Fix B2)
            if M.Modules and M.Modules.DispatchSlash and M.Modules:DispatchSlash(cmd, rest) then
                -- handled by a registered module slash handler
            elseif M.UI then
                M.UI:Toggle()
            end
        end
    end
end

M.RegisterSlashCommands = RegisterSlashCommands

local function BootstrapAddon()
    safeCall("ResolveStorage", function() M:ResolveStorage() end)
    safeCall("InitializeStaticData", function() M:InitializeStaticData() end)
    safeCall("RegisterSlashCommands", RegisterSlashCommands)
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "Blizzard_Professions" then
            safeCall("InitHooks", function()
                if M.Hooks then
                    M.Hooks:Init()
                end
            end)
            return
        end
        if loadedAddon ~= addonName then
            return
        end
        BootstrapAddon()
        M:Print("v" .. (M.VERSION or "?") .. " loaded (" .. (M._storageBackend or "storage") .. ").")
    elseif event == "PLAYER_LOGIN" then
        -- Auto-load any sibling-addon modules the user has enabled. Each
        -- manifest entry with `addonName` set points at a LoadOnDemand
        -- sibling (e.g. FabledUI_Crafty_Allocator). Disabled modules stay
        -- unloaded — that's the whole point of the LoD split.
        --
        -- MUST run before anything that touches M.Alts: the Alt Roster lives in
        -- the LoadOnDemand FabledUI_Crafty_Roster, so M.Alts does not exist
        -- until this loop has run. RegisterCurrentCharacter used to sit above
        -- this block, where its `if M.Alts` guard was always false — the login
        -- profession scan silently never happened, and the failure was
        -- invisible because the guard made it a no-op rather than an error.
        safeCall("LoadEnabledModules", function()
            if M.Modules and M.Modules.Each then
                for manifest in M.Modules:Each() do
                    if manifest.addonName and M.Modules:IsEnabled(manifest.key) then
                        M.Modules:EnsureLoaded(manifest.key)
                    end
                end
            end
        end)
        safeCall("RegisterCurrentCharacter", function()
            if M.Alts then
                M.Alts:RegisterCurrentCharacter()
                M.Alts:ScanCurrentCharacterProfessions(true)
            end
        end)
        safeCall("RegisterSettings", function()
            if M.Settings then
                M.Settings:Register()
            end
        end)
        safeCall("InitHooks", function()
            if M.Hooks then
                M.Hooks:Init()
            end
        end)
        safeCall("InitUI", function()
            if M.UI then
                M.UI:Init()
            end
        end)
        safeCall("InitHUD", function()
            if M.HUD then
                M.HUD:Init()
            end
        end)

        safeCall("InitUpgradeIcons", function() if M.UpgradeIcons then M.UpgradeIcons:Init() end end)
        safeCall("InitConcentration", function() if M.Concentration then M.Concentration:Init() end end)
        safeCall("InitCraftLog",   function() if M.CraftLog   then M.CraftLog:Init()   end end)
        safeCall("InitFarmSession", function() if M.FarmSession then M.FarmSession:Init() end end)

        -- Pre-load the FabledUI_Crafty_Data LoD pack (~50k LOC) ~8s after
        -- login, while the user is still in loading screen / arriving in
        -- zone. Pays the parse cost silently so the first /crafty open
        -- doesn't freeze the client for ~60s. Falls back to lazy-load in
        -- UI:Init if user opens the window before this fires.
        if C_Timer and C_Timer.After then
            C_Timer.After(8, function()
                if not M._dataLoaded and M.EnsureDataLoaded then
                    safeCall("EnsureDataLoaded(deferred)", function() M:EnsureDataLoaded() end)
                end
            end)
        end

        M:Print("v" .. (M.VERSION or "?") .. " online (" .. (M._storageBackend or "storage") .. "). /crafty to open.")
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "SKILL_LINES_CHANGED" then
        if M.EnsureStorageTables then
            M:EnsureStorageTables()
        end
        if not M.settings or M.settings.autoRefresh ~= false then
            safeCall("RecipeCacheScan", function()
                if M.Recipes and M.Recipes.ScanOpenProfession then
                    M.Recipes:ScanOpenProfession(true)
                end
            end)
            safeCall("ProfessionScan", function()
                if M.Alts then
                    M.Alts:ScanCurrentCharacterProfessions(true)
                end
            end)
            safeCall("ConcentrationCapture", function()
                if M.Concentration then
                    M.Concentration:CaptureOpenProfession(true)
                end
            end)
            safeCall("GearScan", function() if M.Gear then M.Gear:ScanOpenProfessionGear(true) end end)
            safeCall("SpecsCapture", function() if M.Specs then M.Specs:CaptureOpenProfession(true) end end)
            safeCall("CooldownScan", function() if M.Cooldowns then M.Cooldowns:ScanOpenProfession(true) end end)
        end
        safeCall("ConcentrationNotifications", function() if M.Concentration then M.Concentration:CheckFullNotifications() end end)
        safeCall("RefreshHooks", function()
            if M.Hooks then
                M.Hooks:RefreshBridge()
            end
        end)
        M:Fire("DataChanged")
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- P0-4: route equipment changes through the named-debounce so a
        -- weapon-swap macro (which can fire multiple PEC events in a tick)
        -- only triggers one gear rescan + one DataChanged + one profit
        -- cache flush. Pattern from Util:DebounceSnapshot.
        if M.Util and M.Util.DebounceSnapshot then
            M.Util:DebounceSnapshot("crafty.gearScan", 0.2, function()
                if M.Gear then M.Gear:ScanOpenProfessionGear(true) end
                if M.Profit and M.Profit.InvalidateCache then M.Profit:InvalidateCache() end
                M:Fire("DataChanged")
            end)
        else
            safeCall("GearScan", function() if M.Gear then M.Gear:ScanOpenProfessionGear(true) end end)
            M:Fire("DataChanged")
        end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        safeCall("SpecsCapture", function() if M.Specs then M.Specs:CaptureOpenProfession(true) end end)
        M:Fire("DataChanged")
    elseif event == "TRAIT_TREE_CHANGED" then
        safeCall("SpecsCapture", function() if M.Specs then M.Specs:CaptureOpenProfession(true) end end)
        M:Fire("DataChanged")
    elseif event == "BAG_UPDATE_DELAYED" or event == "CURRENCY_DISPLAY_UPDATE" then
        -- P0-3 + P0-4: invalidate the bag-counts snapshot eagerly so the
        -- next render reads fresh inventory; debounce the cascade of
        -- concentration / hook / DataChanged work into a single call so
        -- a heavy auto-loot doesn't spike the frame.
        if M.Materials and M.Materials.InvalidateBagCounts then
            M.Materials:InvalidateBagCounts()
        end
        if M.Profit and M.Profit.InvalidateCache then
            M.Profit:InvalidateCache()
        end

        local function snapshot()
            if M.Concentration then
                M.Concentration:CaptureOpenProfession(false)
                M.Concentration:CheckFullNotifications()
            end
            if M.Hooks then M.Hooks:RefreshBridge() end
            M:Fire("DataChanged")
        end

        if M.Util and M.Util.DebounceSnapshot then
            M.Util:DebounceSnapshot("crafty.bagSnapshot", 0.25, snapshot)
        else
            snapshot()
        end
    elseif event == "PLAYER_LOGOUT" then
        safeCall("RegisterCurrentCharacter", function()
            if M.Alts then
                M.Alts:RegisterCurrentCharacter()
            end
        end)
    end
end

M.EVENTS:RegisterEvent("ADDON_LOADED")
M.EVENTS:RegisterEvent("PLAYER_LOGIN")
M.EVENTS:RegisterEvent("PLAYER_LOGOUT")
M.EVENTS:RegisterEvent("TRADE_SKILL_SHOW")
M.EVENTS:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
M.EVENTS:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
M.EVENTS:RegisterEvent("SKILL_LINES_CHANGED")
M.EVENTS:RegisterEvent("BAG_UPDATE_DELAYED")
M.EVENTS:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
M.EVENTS:SetScript("OnEvent", OnEvent)


M.EVENTS:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
M.EVENTS:RegisterEvent("TRAIT_CONFIG_UPDATED")
M.EVENTS:RegisterEvent("TRAIT_TREE_CHANGED")
