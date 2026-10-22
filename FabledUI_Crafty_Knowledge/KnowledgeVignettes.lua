-- ============================================================================
-- FabledUI_Crafty - KnowledgeVignettes (P1-A9)
-- Auto-supertrack any vignette whose questID matches a tracked knowledge
-- treasure. Donor: MyusKnowledgePointsTracker/MKPT.lua:108-127.
--
-- Gated behind M.settings.knowledgeAutoSupertrack (default true). The setting
-- is registered with a sane default in EnsureStorageTables (Storage.lua); we
-- read defensively so toggling the flag at runtime takes immediate effect.
-- ============================================================================

local M = _G.FabledUI_Crafty
if not M then return end

M.KnowledgeVignettes = M.KnowledgeVignettes or {}
local KV = M.KnowledgeVignettes

-- Build a quick { [questID] = true } set of every Midnight treasure quest we
-- know about. Falls back to the legacy KnowledgeData.quests entries on the
-- main per-profession block. Cheap to rebuild on demand; called lazily and
-- cached against the underlying KnowledgeData table identity so we re-walk
-- after the LoD child loads.
local trackedCache, trackedSourceID = nil, nil

local function buildTrackedQuests()
    local set = {}
    local kd = M.KnowledgeData
    if not kd then return set end

    -- Midnight schema: M.KnowledgeData.MidnightTreasures[skillLineID] = { {questID,...}, ... }
    local mid = kd.MidnightTreasures
    if type(mid) == "table" then
        for _, treasures in pairs(mid) do
            if type(treasures) == "table" then
                for _, entry in ipairs(treasures) do
                    if entry and entry.questID then
                        set[entry.questID] = true
                    end
                end
            end
        end
    end

    -- Legacy per-profession schema: kd[profession][expansion] = { { quests = {...} } }
    for key, expansionTable in pairs(kd) do
        -- Skip the Midnight* helper tables we already walked.
        if type(expansionTable) == "table" and key ~= "MidnightTreasures" and key ~= "MidnightTreasureZones" then
            for _, entries in pairs(expansionTable) do
                if type(entries) == "table" then
                    for _, entry in ipairs(entries) do
                        if entry and type(entry.quests) == "table" then
                            for _, q in ipairs(entry.quests) do
                                if q then set[q] = true end
                            end
                        end
                    end
                end
            end
        end
    end

    return set
end

local function getTrackedQuests()
    local kd = M.KnowledgeData
    if trackedCache and trackedSourceID == kd then
        return trackedCache
    end
    trackedCache = buildTrackedQuests()
    trackedSourceID = kd
    return trackedCache
end

function KV:InvalidateCache()
    trackedCache = nil
    trackedSourceID = nil
end

local function isEnabled()
    -- Default ON. Treat nil and any non-false as enabled.
    if not M.settings then return true end
    if M.settings.knowledgeAutoSupertrack == false then return false end
    -- Knowledge module owns the codex (KP sources + treasure autotrack);
    -- when disabled the vignette autotrack stops.
    if M.Modules and not M.Modules:IsEnabled("knowledge") then return false end
    return true
end

function KV:OnVignettesUpdated()
    if not isEnabled() then return end
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes then return end
    if not C_SuperTrack or not C_SuperTrack.SetSuperTrackedVignette then return end

    local tracked = getTrackedQuests()
    if not next(tracked) then return end

    local guids = C_VignetteInfo.GetVignettes() or {}
    for _, guid in ipairs(guids) do
        local info = C_VignetteInfo.GetVignetteInfo(guid)
        if info then
            local q = info.questID or info.objectGUID
            -- Some vignettes carry questID directly; others surface it via name->lookup.
            if q and tracked[q] then
                C_SuperTrack.SetSuperTrackedVignette(guid)
                if SuperTrackedFrame and SuperTrackedFrame.SetTargetAlphaForState then
                    SuperTrackedFrame:SetTargetAlphaForState(0, 0.6)
                end
                return
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("VIGNETTES_UPDATED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
local _vigErrCount = 0
frame:SetScript("OnEvent", function(_, event)
    local ok, err = pcall(function()
        if event == "PLAYER_ENTERING_WORLD" then
            KV:InvalidateCache()
        end
        KV:OnVignettesUpdated()
    end)
    if not ok then
        _vigErrCount = _vigErrCount + 1
        if _vigErrCount <= 3 then
            print("|cffff5555[Crafty.KnowledgeVignettes]|r " .. tostring(err))
        end
    end
end)
