local P = _G.FabledUI_Poseidon
if not P then return end

P.Events = P.Events or {}
local E = P.Events

-- Legacy hard-coded fallback set: used only when P.FishingSpellIDs has not
-- yet been populated by Data/FishingSpellIDs.lua (e.g. /reload mid-cast).
-- Production lookup goes through P.FishingSpellIDs which carries 20+ entries
-- (BetterFishing union Angleur, see Data/FishingSpellIDs.lua).
local FISHING_SPELLS_FALLBACK = {
    [7620] = true,
    [131474] = true,
    [131476] = true,
    [330962] = true,
}

local function GetFishingSpellNameSet()
    if E.fishingSpellNameSet then
        return E.fishingSpellNameSet
    end
    local lookup = {}
    local idSource = (P.FishingSpellIDs and next(P.FishingSpellIDs)) and P.FishingSpellIDs or FISHING_SPELLS_FALLBACK
    for spellID in pairs(idSource) do
        local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or (GetSpellInfo and GetSpellInfo(spellID))
        if type(spellName) == "string" and spellName ~= "" then
            lookup[spellName:lower()] = true
        end
    end
    E.fishingSpellNameSet = lookup
    return lookup
end

-- P1-11 (May-04 audit): replace the 14-keyword channel-name regex with a
-- spell-ID set lookup sourced from P.FishingSpellIDs (BetterFishing union
-- Angleur, see Data/FishingSpellIDs.lua). Falls back to the small static
-- set + the "fishing" substring match for unknown / future spell IDs so
-- older clients still work.
local function IsFishingSpell(spellID, spellName)
    if spellID then
        if P.FishingSpellIDs and P.FishingSpellIDs[spellID] then
            return true
        end
        if FISHING_SPELLS_FALLBACK[spellID] then
            return true
        end
    end
    if type(spellName) == "string" and spellName ~= "" then
        local lower = spellName:lower()
        if GetFishingSpellNameSet()[lower] then
            return true
        end
        -- Legacy fallback for unknown spell IDs.
        return lower:find("fishing", 1, true) ~= nil
    end
    return false
end

-- P2-2 (May-04 audit): PLAYER_SOFT_INTERACT_CHANGED sub-type detection.
-- Mirrors Angleur/Angleur.lua:132-162 - inspect the soft-interact GUID
-- for known NPC IDs that identify fishing sub-types and tag
-- P.State.fishingSubType so BuffTracker / Stats can disambiguate sessions.
--
-- GUID NPC-ID markers (string.match against the GUID):
--    -377944-       Ice fishing pool NPC
--    -192631-       Stair fishing rod (Angleur uses ice for both)
--    -197596-       Stair fishing alt rod
--    -35591-        Midnight Patient bait
--    -152121-       Compressed Ocean
--    -240236-       Oceanic Vortex (Compressed Ocean variant)
local SOFT_INTERACT_NPC_PATTERNS = {
    { pattern = "%-377944%-", subType = "ice"        },
    { pattern = "%-192631%-", subType = "ice"        },
    { pattern = "%-197596%-", subType = "ice"        },
    { pattern = "%-35591%-",  subType = "patient"    },
    { pattern = "%-152121%-", subType = "compressed" },
    { pattern = "%-240236%-", subType = "compressed" },
}

-- 12.x (Midnight) secret values: unit identity read from a tainted execution
-- path can be a "secret string". type() still reports "string", but indexing it
-- (guid:match, name:lower) or using it as a table key throws, so it has to be
-- filtered explicitly. Shimmed so the file still loads on pre-12.x clients.
local issecretvalue = _G.issecretvalue or function() return false end

local function SafeUnitName(unit)
    local name = UnitName and UnitName(unit)
    if not name or issecretvalue(name) then return nil end
    return name
end

local function HandleSoftInteractChanged()
    local guid = UnitGUID and UnitGUID("softinteract") or nil
    if type(guid) ~= "string" or issecretvalue(guid) or guid == "" then
        if P.State.fishingSubType ~= "standard" then
            P.State.fishingSubType = "standard"
        end
        return
    end
    for _, entry in ipairs(SOFT_INTERACT_NPC_PATTERNS) do
        if guid:match(entry.pattern) then
            P.State.fishingSubType = entry.subType
            return
        end
    end
    -- Anything else with a soft-interact GUID that isn't standard fishing
    -- (and isn't one of the known NPCs) - flag as void hole / unknown.
    P.State.fishingSubType = "void"
end

-- P2-1 (May-04 audit): rare-catch toast.
-- When CHAT_MSG_LOOT carries an itemID present in P.RareFishIDs, fire a
-- transient T.Toast with the item icon. Falls back to a custom OVERLAY
-- frame if the toolkit is unavailable. Pattern reference:
-- Angleur/midnight.lua:184-203 (full-screen alert) trimmed down to the
-- toolkit's Toast helper.
local function ResolveItemIcon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    if GetItemIcon then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then return icon end
    end
    return nil
end

local function FireRareCatchToast(itemName, itemID)
    if not itemName or itemName == "" then return end

    local icon = ResolveItemIcon(itemID)
    local message = string.format("Rare catch: %s!", itemName)

    -- Prefer the Toolkit's Toast helper; fall back to a brief OVERLAY frame
    -- so we never break if the toolkit isn't loaded yet.
    local T = P.UI and P.UI.GetToolkit and P.UI:GetToolkit() or rawget(_G, "FabledUI_UIToolkit")
    if T and T.Toast and T.Toast.Show then
        T.Toast:Show(message, icon or itemID, 4.0)
        return
    end

    -- Fallback: lightweight OVERLAY frame (Angleur-style flash, scaled down)
    if not E._fallbackToast then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(280, 44)
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
        frame:SetFrameStrata("TOOLTIP")
        frame:Hide()
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
        end
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetSize(28, 28)
        frame.icon:SetPoint("LEFT", 8, 0)
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
        frame.text:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        frame.text:SetJustifyH("LEFT")
        E._fallbackToast = frame
    end

    local frame = E._fallbackToast
    if icon then
        frame.icon:SetTexture(icon)
        frame.icon:Show()
    else
        frame.icon:Hide()
    end
    frame.text:SetText(message)
    frame:Show()
    if frame._timer then frame._timer:Cancel() end
    frame._timer = C_Timer.NewTimer(4, function() frame:Hide() end)
end

local function MaybeFireRareCatch(itemName, itemID)
    if not itemID then return end
    if not P.RareFishIDs or not P.RareFishIDs[itemID] then return end
    -- Honour the same "showRareCatchToast" setting; default ON if missing.
    if P.settings and P.settings.showRareCatchToast == false then return end
    FireRareCatchToast(itemName, itemID)
end

local function ExtractLootInfo(message)
    if type(message) ~= "string" then
        return nil, nil, nil
    end
    local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    local itemName = itemLink and itemLink:match("|h%[(.-)%]|h|r") or message:match("%[(.-)%]")
    local itemID = itemLink and tonumber(itemLink:match("Hitem:(%d+)")) or nil
    local quantity = tonumber(message:match("x(%d+)")) or 1
    return itemName, itemID, quantity
end

local function IsLikelyFishingLoot(itemName, itemID, poolName)
    if P:IsKnownFishName(itemName) then
        return true
    end
    if type(_G.FishIntel_FishItems) == "table" and itemID then
        for _, knownItemID in pairs(_G.FishIntel_FishItems) do
            if knownItemID == itemID then
                return true
            end
        end
    end
    if type(poolName) == "string" and type(itemName) == "string" and type(_G.FishIntel_PoolFishIndex) == "table" then
        local static = _G.FishIntel_PoolFishIndex[poolName]
        if type(static) == "table" then
            for _, fishName in ipairs(static) do
                if fishName == itemName then
                    return true
                end
            end
        end
    end
    return false
end

local function ResolvePoolContext()
    local pending = P.State.pendingCast
    if pending and (GetTime() - (pending.at or 0)) <= 75 then
        return pending.poolName, pending.mapID, pending.x, pending.y
    end
    if P.State.lastPoolHover and (GetTime() - (P.State.lastHoverTime or 0)) <= 30 then
        return P.State.lastPoolHover, P.State.lastPoolMapID, P.State.lastPoolX, P.State.lastPoolY
    end
    local mapID, x, y = P:GetCurrentMapPosition()
    return nil, mapID, x, y
end

function E:HandleFishingAttempt(spellID, castGUID)
    local targetName = SafeUnitName("target")
    local mouseoverName = SafeUnitName("mouseover")
    local mapID, x, y = P:GetCurrentMapPosition()
    local poolName = nil

    if P:LooksLikeFishingPool(targetName) then
        poolName = targetName
    elseif P:LooksLikeFishingPool(mouseoverName) then
        poolName = mouseoverName
    elseif P.State.lastPoolHover and (GetTime() - (P.State.lastHoverTime or 0)) <= 30 then
        poolName = P.State.lastPoolHover
        mapID = P.State.lastPoolMapID or mapID
        x = P.State.lastPoolX or x
        y = P.State.lastPoolY or y
    end

    P.State.pendingCast = {
        at = GetTime(),
        spellID = spellID,
        castGUID = castGUID,
        poolName = poolName,
        mapID = mapID,
        x = x,
        y = y,
    }

    if poolName and P.settings.enableAutoLog and mapID and x and y and P.Nodes then
        P.Nodes:ObserveNode(mapID, x, y, poolName)
    end

    if P.Stats then
        P.Stats:RecordCast({ poolName = poolName or "Open Water", mapID = mapID, x = x, y = y })
    end

    if P.settings.autoShowHUDWhileFishing ~= false and P.ShowHUD and not P:IsHUDShown() then
        P:ShowHUD("fishing")
    end

    P:QueueDataBroadcast("cast")
end

function E:HandleLoot(message)
    local itemName, itemID = ExtractLootInfo(message)
    if not itemName then
        return
    end

    local pending = P.State.pendingCast
    local poolName, mapID, x, y = ResolvePoolContext()
    if pending and pending.poolName then
        poolName = pending.poolName
        mapID = pending.mapID or mapID
        x = pending.x or x
        y = pending.y or y
    end

    local likelyFishing = pending and (GetTime() - (pending.at or 0)) <= 75
    if not likelyFishing and not poolName then
        return
    end

    if not poolName and likelyFishing then
        poolName = "Open Water"
    end

    local isFish = IsLikelyFishingLoot(itemName, itemID, poolName)
    if not isFish and not P.settings.countTrash then
        return
    end

    if P.Stats then
        P.Stats:RecordCatch(itemName, {
            poolName = poolName or "Open Water",
            mapID = mapID,
            x = x,
            y = y,
            isFish = isFish,
            itemID = itemID,
        })
    end

    -- P2-1: rare-catch toast. Cross-reference itemID against the merged
    -- rare-fish lookup (P.RareFishIDs, populated from Data/RareFish.lua).
    if isFish then
        MaybeFireRareCatch(itemName, itemID)
    end

    if isFish and P.Counters then
        P.Counters:Increment(itemName)
    end

    if isFish and poolName and poolName ~= "Open Water" and P.settings.learnPools then
        P.db.learned[poolName] = P.db.learned[poolName] or {}
        P.db.learned[poolName][itemName] = true
    end

    if isFish and poolName and poolName ~= "Open Water" and P.settings.enableAutoLog and mapID and x and y and P.Nodes then
        P.Nodes:RecordCatchAtNode(mapID, x, y, poolName, itemName)
    end

    if isFish and P.settings.showDerbyTracker and P.Derby and P.Derby.IsActive and P.Derby:IsActive() then
        P.Derby:RecordCatch(itemName)
    end

    P:RecordRecentCatch(itemName, poolName or "Open Water", isFish)
    P:MarkDirty()
    P.State.pendingCast = nil
    P:QueueDataBroadcast("catch")
end

function E:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    -- Initial sub-type tag so consumers always read a known value.
    P.State.fishingSubType = P.State.fishingSubType or "standard"

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    -- P2-2: detect fishing sub-type via the soft-interact GUID.
    if pcall(frame.RegisterEvent, frame, "PLAYER_SOFT_INTERACT_CHANGED") then
        -- Event is registered. Older clients pcall-fail and we silently skip.
    end
    local _poseEvtErrCount = 0
    frame:SetScript("OnEvent", function(_, event, ...)
      local ok, err = pcall(function(...)
        if event == "UNIT_SPELLCAST_SENT" then
            local unit, _, castGUID, spellID = ...
            local spellName = spellID and (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or (GetSpellInfo and GetSpellInfo(spellID))) or nil
            if unit == "player" and IsFishingSpell(spellID, spellName) then
                E:HandleFishingAttempt(spellID, castGUID)
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, castGUID, spellID = ...
            if unit == "player" and P.State.pendingCast and P.State.pendingCast.castGUID == castGUID then
                P.State.pendingCast.succeeded = true
                P.State.pendingCast.spellID = spellID or P.State.pendingCast.spellID
            end
        elseif event == "CHAT_MSG_LOOT" then
            local message = ...
            E:HandleLoot(message)
        elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
            HandleSoftInteractChanged()
        end
      end, ...)
      if not ok then
        _poseEvtErrCount = _poseEvtErrCount + 1
        if _poseEvtErrCount <= 3 then
            print("|cffff5555[Poseidon.Events]|r " .. tostring(err))
        end
      end
    end)
    self.frame = frame
end
