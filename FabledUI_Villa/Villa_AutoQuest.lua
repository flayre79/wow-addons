local Villa = _G.FabledUI_Villa
local AutoQuest = {}
Villa.AutoQuest = AutoQuest
Villa:RegisterModule("AutoQuest", AutoQuest)

-- ============================================================
-- Known housing quest IDs (onboarding / treasure quests).
-- Pre-seeded from the DataVault TreasureHunt import (99 quest entries
-- across Founder's Point + Razorwind Shores). Hydrated at module init
-- so we don't pay the table-rebuild cost at quest-accept time.
-- ============================================================
local HOUSING_QUEST_IDS = {}

local function HydrateHousingQuestIDs()
    -- Pull TreasureHunt questIDs from the DataVault shard if present.
    local providers = _G.FabledUI_DataVault_VillaProviders
    local codex = providers and providers["codex"]
    local treasure = codex and codex.TreasureHunt
    if treasure and type(treasure.locations) == "table" then
        for questID in pairs(treasure.locations) do
            if type(questID) == "number" then
                HOUSING_QUEST_IDS[questID] = true
            end
        end
    end
end

-- Hydrate at module load; the DataVault shard is loaded as a dependency so
-- providers["codex"].TreasureHunt is already populated by the time we run.
HydrateHousingQuestIDs()

-- ============================================================
-- Title patterns that identify a quest as housing-related
-- ============================================================
local HOUSING_TITLE_PATTERNS = {
    "Housing",
    "Decor",
    "Estate",
    "Decoration",
    "Dwelling",
}

-- ============================================================
-- Helpers
-- ============================================================

local function IsHousingQuest(questID)
    if HOUSING_QUEST_IDS[questID] then
        return true
    end
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title then
            for _, pattern in ipairs(HOUSING_TITLE_PATTERNS) do
                if title:find(pattern, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function ShouldAutoAccept()
    local settings = Villa.settings
    return settings and settings.autoAcceptHousingQuests
end

-- ============================================================
-- Event frame
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_ACCEPT_CONFIRM")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "QUEST_DETAIL" then
        if not ShouldAutoAccept() then return end
        local questID = GetQuestID and GetQuestID() or 0
        if questID and questID > 0 and IsHousingQuest(questID) then
            AcceptQuest()
        end
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        if not ShouldAutoAccept() then return end
        -- Auto-confirm if the confirmation dialog is for a housing quest
        local questID = GetQuestID and GetQuestID() or 0
        if questID and questID > 0 and IsHousingQuest(questID) then
            AcceptQuest()
        end
    end
end)

-- ============================================================
-- Module lifecycle
-- ============================================================

function AutoQuest:OnEnable()
    -- Ensure the setting key exists with a default of false
    if Villa.settings and Villa.settings.autoAcceptHousingQuests == nil then
        Villa.settings.autoAcceptHousingQuests = false
    end
end
