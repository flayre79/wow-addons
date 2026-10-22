-- FabledUI - Poseidon : Fishing Buff Tracker
-- =====================================================================
-- Feature P3: monitor the player's active fishing buffs and surface a
-- compact status indicator on the HUD ("Buff: Lure +200" or
-- "No active fishing buff").
--
-- Implementation notes:
--   * P.FishingBuffSpells is the source of truth (defined in Core.lua as
--     an empty placeholder; data lands separately).
--   * UNIT_AURA on "player" drives invalidation; we cache the resolved
--     buff descriptor between events to avoid re-scanning every frame.
--   * Resolution honours both spellID matches and a friendly-label
--     override declared in P.FishingBuffSpells (e.g. [12345] = "Lure +200").
--   * A live name fallback uses C_Spell.GetSpellName so the indicator
--     still produces a readable string when the data table only carries
--     `[id] = true`.
--   * If the data table is empty we still expose a no-buff status so the
--     HUD slot can render "No active fishing buff" instead of disappearing.

local P = _G.FabledUI_Poseidon
if not P then return end

P.BuffTracker = P.BuffTracker or {}
local BT = P.BuffTracker

local function GetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

-- Build a friendly label for a spellID, preferring an explicit override
-- in the data table and falling back to the live spell name.
function BT:LabelFor(spellID)
    local override = P.FishingBuffSpells and P.FishingBuffSpells[spellID]
    if type(override) == "string" and override ~= "" then
        return override
    end
    return GetSpellName(spellID) or ("Spell " .. tostring(spellID))
end

-- ---------------------------------------------------------------------
-- Aura scanning
-- ---------------------------------------------------------------------

-- 12.1: aura data reached by index, slot, or aura-instance ID raises a Lua error
-- while auras are secret. That broke both halves of the old scanner --
-- AuraUtil.ForEachAura (slot-driven) and the UnitAura(unit, index, filter) walk
-- it fell back to. Worse, the fallback was the unprotected one: ForEachAura was
-- pcall'd, so a secret-aura error there fell straight through into the raw
-- UnitAura loop, which then threw for real.
--
-- Spell-ID lookups are explicitly still permitted, and P.FishingBuffSpells is
-- already keyed by spellID -- so query the known IDs directly rather than
-- walking the aura list. That is 12.1-safe and cheaper than scanning up to 60
-- slots on every UNIT_AURA.
--
-- AuraData structs are fully secret in 12.1, so each field read is guarded too:
-- secret timing degrades to nil, and GetStatusLine already renders the label
-- without a countdown when expirationTime is missing.
local issecretvalue = _G.issecretvalue or function() return false end

local function SafeField(tbl, key)
    local ok, v = pcall(function() return tbl[key] end)
    if not ok or v == nil or issecretvalue(v) then return nil end
    return v
end

local function GetPlayerAuraBySpellID(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or type(aura) ~= "table" then return nil end
    return aura
end

function BT:ScanPlayerBuffs()
    local detected
    if type(P.FishingBuffSpells) == "table" then
        for spellID, def in pairs(P.FishingBuffSpells) do
            if def and type(spellID) == "number" then
                local aura = GetPlayerAuraBySpellID(spellID)
                if aura then
                    detected = {
                        spellID = spellID,
                        label = self:LabelFor(spellID),
                        duration = SafeField(aura, "duration"),
                        expirationTime = SafeField(aura, "expirationTime"),
                        rawName = SafeField(aura, "name"),
                    }
                    break
                end
            end
        end
    end
    self.activeBuff = detected
    return detected
end

function BT:GetActiveBuff()
    return self.activeBuff
end

function BT:GetStatusLine()
    if not P.settings or P.settings.showBuffTracker == false then
        return nil
    end
    local active = self.activeBuff
    if active and active.label then
        local remaining = active.expirationTime and (active.expirationTime - GetTime()) or nil
        if remaining and remaining > 0 then
            local minutes = math.floor(remaining / 60)
            local seconds = math.floor(remaining % 60)
            return string.format("Buff: %s (%d:%02d)", active.label, minutes, seconds)
        end
        return string.format("Buff: %s", active.label)
    end
    if not P.FishingBuffSpells or next(P.FishingBuffSpells) == nil then
        return "No active fishing buff (data pending)"
    end
    return "No active fishing buff"
end

-- ---------------------------------------------------------------------
-- Boot / event wiring
-- ---------------------------------------------------------------------

function BT:Init()
    if self.frame then return end

    local frame = CreateFrame("Frame")
    self.frame = frame
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterUnitEvent("UNIT_AURA", "player")

    frame:SetScript("OnEvent", function(_, event)
        BT:ScanPlayerBuffs()
        if event == "UNIT_AURA" or event == "PLAYER_ENTERING_WORLD" then
            -- Repaint the HUD slot if it's open.
            if P.UI and P.UI.RenderHUDBuffStatus then
                P.UI:RenderHUDBuffStatus()
            end
            -- Keep the HUD itself consistent in case the player is mid-cast.
            if P.UI and P.UI.QueueRefresh then
                P.UI:QueueRefresh()
            end
        end
    end)

    -- Pre-warm so the first render has data without waiting for an event.
    BT:ScanPlayerBuffs()
end
