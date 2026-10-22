-- FabledUI - Artemis : Currency Tracker
-- =====================================================================
-- Feature A1: live currency widget rendered as a Tracker section.
-- Surfaces gold + the weekly-reset currencies relevant to Midnight 12.0.5.
-- IDs come from the authoritative sample addon (Larias's Weekly Checklist
-- constants) and from the suggested values in the feature spec; both lists
-- are merged and de-duped at registration time.
--
-- The user-suggested IDs (3008/3107/3010/3056/3055) belong to The War
-- Within (11.x). Midnight (12.0.5) shifted to: 3310 Restored Coffer Keys,
-- 3212 Sparks of Omens, 3378 Catalyst, 3383/3341/3343/3345/3347 crests.
-- Resonance Crystals is the housing currency (verified in
-- FabledUI_DataVault_Villa/HomeData.lua) but its ID is not yet known to
-- the suite; we leave a 0-id placeholder row so it lights up the moment
-- the ID is confirmed.
local A = FabledUI_Artemis or Artemis
if not A then return end

A.Currency = A.Currency or {}
local C = A.Currency

local DEFAULT_CURRENCIES = {
    -- key            id      label                          weekly
    { key = "gold",   id = 0,    label = "Gold",                     weekly = false, kind = "money" },
    -- Midnight (12.0.5) currencies sourced from Larias constants.
    { key = "coffer", id = 3310, label = "Restored Coffer Keys",     weekly = true  },
    { key = "spark",  id = 3212, label = "Sparks of Omens",          weekly = true  },
    { key = "cata",   id = 3378, label = "Catalyst Charges",         weekly = true  },
    { key = "advCrest", id = 3383, label = "Adventurer's Crests",    weekly = true  },
    { key = "vetCrest", id = 3341, label = "Veteran's Crests",       weekly = true  },
    { key = "chmpCrest", id = 3343, label = "Champion's Crests",     weekly = true  },
    { key = "heroCrest", id = 3345, label = "Hero's Crests",         weekly = true  },
    { key = "mythCrest", id = 3347, label = "Mythic Crests",         weekly = true  },
    -- Spec-suggested (verify post-launch). Left enabled-but-disabled by
    -- default in DEFAULT_ENABLED until the IDs are confirmed for 12.0.5.
    { key = "valorstones", id = 3008, label = "Valorstones",                weekly = true,  speculative = true },
    { key = "footlocker",  id = 3107, label = "Adventurer's Footlocker",    weekly = true,  speculative = true },
    { key = "resonance",   id = 3010, label = "Resonance Crystals",         weekly = false, speculative = true },
    { key = "shards",      id = 3056, label = "Coffer Key Shards",          weekly = true,  speculative = true },
    { key = "key",         id = 3055, label = "Coffer Key",                 weekly = true,  speculative = true },
}

local DEFAULT_ENABLED = {
    gold      = true,
    coffer    = true,
    spark     = true,
    cata      = true,
    advCrest  = true,
    vetCrest  = true,
    chmpCrest = true,
    heroCrest = true,
    mythCrest = true,
    -- speculative defaults off; user can flip on once the live game
    -- confirms the ID is valid.
    valorstones = false,
    footlocker  = false,
    resonance   = false,
    shards      = false,
    key         = false,
}

C.DEFINITIONS = DEFAULT_CURRENCIES

function C:GetDefinitions()
    return DEFAULT_CURRENCIES
end

function C:GetDefaultEnabledMap()
    local copy = {}
    for k, v in pairs(DEFAULT_ENABLED) do
        copy[k] = v
    end
    return copy
end

function C:IsEnabled(key)
    local prefs = A.profile and A.profile.currencyTracker or nil
    if not prefs then
        return DEFAULT_ENABLED[key] == true
    end
    if prefs.shown and prefs.shown[key] ~= nil then
        return prefs.shown[key] == true
    end
    return DEFAULT_ENABLED[key] == true
end

function C:SetEnabled(key, enabled)
    A.profile.currencyTracker = A.profile.currencyTracker or { enabled = true, shown = {} }
    A.profile.currencyTracker.shown = A.profile.currencyTracker.shown or {}
    A.profile.currencyTracker.shown[key] = enabled and true or false
end

function C:IsSectionEnabled()
    local prefs = A.profile and A.profile.currencyTracker
    if not prefs then
        return true
    end
    if prefs.enabled == nil then
        return true
    end
    return prefs.enabled == true
end

function C:SetSectionEnabled(enabled)
    A.profile.currencyTracker = A.profile.currencyTracker or { enabled = true, shown = {} }
    A.profile.currencyTracker.enabled = enabled and true or false
end

local function FormatGold(copperAmount)
    copperAmount = copperAmount or 0
    if type(GetMoneyString) == "function" then
        return GetMoneyString(copperAmount, true)
    end
    local g = math.floor(copperAmount / 10000)
    return string.format("%dg", g)
end

local function FormatResetCountdown(seconds)
    if not seconds or seconds <= 0 then
        return "soon"
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days >= 1 then
        return string.format("%dd %dh", days, hours)
    elseif hours >= 1 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

function C:GetWeeklyResetSeconds()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and type(seconds) == "number" then
            return seconds
        end
    end
    return nil
end

-- Build the per-line item table the Tracker consumes when it renders the
-- CURRENCIES section. Each entry mirrors the lightweight contract used by
-- the existing checklist section so the renderer can stay simple.
function C:BuildEntries()
    local entries = {}
    if not self:IsSectionEnabled() then
        return entries
    end

    local weeklySeconds = self:GetWeeklyResetSeconds()
    local weeklyCountdown = FormatResetCountdown(weeklySeconds)

    for _, def in ipairs(DEFAULT_CURRENCIES) do
        if self:IsEnabled(def.key) then
            local label = def.label
            local valueText
            local rewardText

            if def.kind == "money" then
                local copper = (type(GetMoney) == "function" and GetMoney()) or 0
                valueText = FormatGold(copper)
                rewardText = "Carried gold across all bags."
            elseif def.id and def.id > 0 and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, def.id)
                if ok and type(info) == "table" then
                    if type(info.name) == "string" and info.name ~= "" then
                        label = info.name
                    end
                    local quantity = info.quantity or 0
                    local maxQuantity = info.maxQuantity or 0
                    if maxQuantity and maxQuantity > 0 then
                        valueText = string.format("%d / %d", quantity, maxQuantity)
                    else
                        valueText = tostring(quantity)
                    end
                    if info.iconFileID then
                        label = string.format("|T%d:14|t %s", info.iconFileID, label)
                    end
                    if info.description then
                        rewardText = info.description
                    end
                else
                    valueText = "n/a"
                    rewardText = def.speculative and "ID not yet confirmed for Midnight 12.0.5." or "Currency not loaded."
                end
            else
                valueText = "n/a"
                rewardText = "No live data source for this currency."
            end

            local timeLeftText
            if def.weekly then
                timeLeftText = "resets in " .. weeklyCountdown
            end

            entries[#entries + 1] = {
                id = "currency:" .. def.key,
                key = def.key,
                currencyID = def.id,
                label = label,
                valueText = valueText,
                rewardText = rewardText,
                timeLeftText = timeLeftText,
                resetShort = def.weekly and weeklyCountdown or nil,
                source = "currency",
            }
        end
    end

    return entries
end

-- AR-A1: tick the tracker once a minute so the weekly-reset countdown
-- text stays current without burning CPU. Guard so we only schedule once.
function C:StartTicker()
    if self._tickerStarted or not C_Timer or not C_Timer.NewTicker then
        return
    end
    self._tickerStarted = true
    self._ticker = C_Timer.NewTicker(60, function()
        if A and A.Tracker and A.Tracker.frame and A.Tracker:IsExpandedVisible() then
            if A.Currency:IsSectionEnabled() then
                A.Tracker:Refresh(true)
            end
        end
    end)
end

local registrar = CreateFrame("Frame")
registrar:RegisterEvent("PLAYER_LOGIN")
registrar:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if A.Currency then
        A.Currency:StartTicker()
    end
end)

