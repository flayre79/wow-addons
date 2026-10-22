local P = _G.FabledUI_Poseidon
if not P then return end

P.Settings = P.Settings or {}
local S = P.Settings

local function OnSettingChanged()
    P:MarkDirty()
    if P.UI then
        P.UI:QueueRefresh()
    end
    if P.Nodes then
        P.Nodes:QueueRefresh()
    end
end

local function RegisterProxyBool(category, variable, name, tooltip, getter, setter)
    local initial = getter()
    local setting = Settings.RegisterProxySetting(category, variable, type(initial), name, initial, getter, function(value)
        setter(value)
        OnSettingChanged()
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function RegisterProxyNumber(category, variable, name, tooltip, defaultValue, getter, setter, minValue, maxValue, step)
    local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, getter, function(value)
        setter(value)
        OnSettingChanged()
    end)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    Settings.CreateSlider(category, setting, options, tooltip)
end

function S:Register()
    if self.registered then
        return
    end
    self.registered = true

    if not Settings or not Settings.RegisterVerticalLayoutCategory then
        return
    end

    local category = Settings.RegisterVerticalLayoutCategory("FabledUI - Poseidon")

    RegisterProxyBool(category, "Poseidon_TooltipIntel", "Tooltip Intel", "Show learned and possible catches on fishing pool tooltips.",
        function() return P.settings.tooltipIntel end,
        function(value) P.settings.tooltipIntel = value end)

    RegisterProxyBool(category, "Poseidon_MapPins", "World Map Pins", "Show Poseidon fish-node pins on the world map.",
        function() return P.settings.enableMapPins end,
        function(value) P.settings.enableMapPins = value end)

    RegisterProxyBool(category, "Poseidon_AutoLog", "Automatic Pool Logging", "Record pool nodes when you cast into known fishing pools.",
        function() return P.settings.enableAutoLog end,
        function(value) P.settings.enableAutoLog = value end)

    RegisterProxyBool(category, "Poseidon_LearnPools", "Learn Pool Fish", "Add confirmed catches to the learned list for a pool.",
        function() return P.settings.learnPools end,
        function(value) P.settings.learnPools = value end)

    RegisterProxyBool(category, "Poseidon_CountTrash", "Track Trash and Non-Fish", "Count non-fish catches in stats when they come from fishing.",
        function() return P.settings.countTrash end,
        function(value) P.settings.countTrash = value end)

    RegisterProxyBool(category, "Poseidon_DerbyTracker", "Show Derby Tracker", "Keep lightweight tournament intel visible when a derby buff is active.",
        function() return P.settings.showDerbyTracker end,
        function(value) P.settings.showDerbyTracker = value end)

    RegisterProxyBool(category, "Poseidon_AutoShowHUD", "Auto-Show HUD While Fishing", "Open the Poseidon HUD automatically when you start fishing.",
        function() return P.settings.autoShowHUDWhileFishing ~= false end,
        function(value) P.settings.autoShowHUDWhileFishing = value end)

    -- P1: Fish catalog rare-only filter persistence.
    RegisterProxyBool(category, "Poseidon_FishRareOnly", "Fish Catalog: Rare Only", "Hide non-rare fish in the catalog. Lights up once rare data is mined.",
        function() return P.settings.fishRareOnly == true end,
        function(value) P.settings.fishRareOnly = value end)

    -- P2: Fish catalog junk filter persistence.
    RegisterProxyBool(category, "Poseidon_FishHideJunk", "Fish Catalog: Hide Junk", "Hide grey-quality (Poor) catches from the fish catalog.",
        function() return P.settings.fishHideJunk == true end,
        function(value) P.settings.fishHideJunk = value end)

    -- P3: Buff tracker visibility on the HUD.
    RegisterProxyBool(category, "Poseidon_BuffTracker", "Show Buff Tracker", "Show the active fishing buff status indicator on the Poseidon HUD.",
        function() return P.settings.showBuffTracker ~= false end,
        function(value) P.settings.showBuffTracker = value end)

    -- Rare-catch toast: surfaces a brief notification when CHAT_MSG_LOOT
    -- contains an itemID in P.RareFishIDs. The setting default already
    -- exists in Storage; without a UI control the user couldn't opt out.
    RegisterProxyBool(category, "Poseidon_RareCatchToast", "Rare Catch Toast", "Show a brief toast notification when you catch a rare fish.",
        function() return P.settings.showRareCatchToast ~= false end,
        function(value) P.settings.showRareCatchToast = value end)

    RegisterProxyBool(category, "Poseidon_Minimap", "Show Minimap Icon", "Toggle the Poseidon launcher icon.",
        function() return not P.settings.minimap.hide end,
        function(value)
            P.settings.minimap.hide = not value
            if P.Minimap and P.Minimap.icon then
                if P.settings.minimap.hide then
                    P.Minimap.icon:Hide("Poseidon")
                else
                    P.Minimap.icon:Show("Poseidon")
                end
            end
        end)

    RegisterProxyNumber(category, "Poseidon_PinSize", "Pin Size", "World map fish pin size.", 16,
        function() return P.settings.pinSize or 16 end,
        function(value) P.settings.pinSize = math.floor(value + 0.5) end,
        10, 24, 1)

    RegisterProxyNumber(category, "Poseidon_HUDScale", "HUD Scale", "Scale for the compact fishing HUD.", 1,
        function() return P.settings.hud.scale or 1 end,
        function(value) P.settings.hud.scale = value end,
        0.8, 1.4, 0.05)

    RegisterProxyNumber(category, "Poseidon_HUDAlpha", "HUD Opacity", "Opacity for the compact fishing HUD.", 1,
        function() return P.settings.hud.alpha or 1 end,
        function(value) P.settings.hud.alpha = value end,
        0.65, 1.0, 0.05)

    RegisterProxyNumber(category, "Poseidon_FullScale", "Full Window Scale", "Scale for the main Poseidon browser window.", 1,
        function() return P.settings.full.scale or 1 end,
        function(value) P.settings.full.scale = value end,
        0.85, 1.3, 0.05)

    RegisterProxyNumber(category, "Poseidon_FullAlpha", "Full Window Opacity", "Opacity for the main Poseidon browser window.", 1,
        function() return P.settings.full.alpha or 1 end,
        function(value) P.settings.full.alpha = value end,
        0.75, 1.0, 0.05)

    RegisterProxyNumber(category, "Poseidon_SessionTimeout", "Session Timeout (minutes)", "Minutes of inactivity before Poseidon starts a fresh fishing session.", 20,
        function() return P.settings.sessionTimeoutMinutes or 20 end,
        function(value) P.settings.sessionTimeoutMinutes = math.floor(value + 0.5) end,
        5, 60, 5)

    Settings.RegisterAddOnCategory(category)
    P.CategoryID = category:GetID()
end
