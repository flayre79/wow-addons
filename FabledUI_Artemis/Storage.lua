local A = FabledUI_Artemis or Artemis
local ADDON_KEY = "artemis"

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = DeepCopy(v)
    end
    return out
end

local function DeepMerge(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return dst
    end

    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            DeepMerge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

local function CharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return name .. "-" .. realm
end

function A:GetDefaults()
    return {
        version = 2,
        account = {
            preferences = {
                enabled = true,
                locked = false,
                theme = "FableNeon",
                anchor = "TOPRIGHT",
                x = -350,
                y = -260,
                width = 380,
                height = 520,
                compactMode = false,
                hideDefaultTracker = true,
                autoHideInInstances = true,
                showQuestItems = true,
                -- Objectives start COLLAPSED and are expanded per quest by
                -- clicking a row's icon. True here means every quest shows every
                -- objective at once, which is exactly the wall of text the
                -- per-quest expansion was added to replace. The `objectives`
                -- module toggle below is what allows them to be read at all;
                -- this only sets the starting state.
                showObjectives = false,
                showCompletedObjectives = false,
                showWorldQuestTimers = true,
                -- Blizzard's tracker shows tracked achievements and we hide it.
                trackAchievements = true,
                showChecklist = true,
                showCurrentZoneOnly = false,
                groupByZone = false,
                autoRouteFocusToOdyssey = true,
                routeOnMiddleClick = true,
                odysseyRouteMode = "APPEND",
                odysseyOpenMapOnFocus = false,
                renderMode = "SAFE",
                activePreset = "STANDARD",
                filterMode = "ALL",
                -- Point-size nudge applied on top of the Blizzard row font objects,
                -- which are fixed at 10pt and read small in the tracker.
                -- 0 restores the pre-2.7.1 sizing exactly. /artemis fontsize <n>
                fontDelta = 1,
                -- Row tooltip detail. Kaliel's parity: its tracker offers the
                -- same three switches ("Show tooltips" / "Show Rewards" /
                -- "Show ID"). The reads are `~= false`, so an existing profile
                -- with none of these keys gets objectives and rewards without a
                -- migration step. Quest ID ships off -- it is a debugging
                -- detail, and it is the one Kaliel's also defaults off.
                tooltipShowObjectives = true,
                tooltipShowRewards = true,
                tooltipShowID = false,
                sectionOrder = {
                    "SCENARIO",
                    "FOCUS",
                    "EXPIRING",
                    "CAMPAIGN",
                    "CURRENT_ZONE",
                    "WORLD",
                    "DAILY",
                    "WEEKLY",
                    "MONTHLY",
                    "QUESTS",
                    "BONUS",
                    "CHECKLIST",
                    "RECIPES",
                    "ENDEAVORS",
                    "ACTIVITIES",
                    "ACHIEVEMENTS",
                    -- AR-A1: render the currency tracker after the regular
                    -- quest sections so it does not push the focus area down.
                    "CURRENCIES",
                },
                -- AR-A1: currency tracker preferences. enabled controls the
                -- whole section; shown[<key>] controls each row. Defaults
                -- live in Currency.lua so the table fills in lazily.
                currencyTracker = {
                    enabled = true,
                    shown = {
                        gold = true,
                        coffer = true,
                        spark = true,
                        cata = true,
                        advCrest = true,
                        vetCrest = true,
                        chmpCrest = true,
                        heroCrest = true,
                        mythCrest = true,
                    },
                },
                -- Tracked profession recipes (default-tracker parity). Section
                -- toggle only; the row set is whatever the player has tracked
                -- in the profession UI, so there is nothing per-row to store.
                recipeTracker = {
                    enabled = true,
                },
                -- AR-A3: solo focus is stored per-character on
                -- characters[<key>].soloFocus (see GetCharacterState below);
                -- no account-level entry is needed.
                collapsedSections = {},
                hiddenQuestIDs = {},
                hiddenChecklistIDs = {},
                worldQuestFilters = {
                    reward = "ALL",
                    time = "ALL",
                    trackedOnly = false,
                },
                -- FRESH-PROFILE DEFAULTS. These are what someone installing
                -- Artemis for the first time gets, and they were audited on
                -- 2026-09-05 before sharing the suite with David's guild --
                -- everything up to then had only ever been verified against his
                -- own tuned profile.
                --
                -- The rule, already stated on `recipes` below: anything the
                -- Blizzard tracker shows must default ON, because we hide the
                -- Blizzard tracker. Defaulting it off silently removes
                -- functionality the player already had.
                moduleToggles = {
                    worldQuests = true,
                    -- Was false while profile.showChecklist was true, so the
                    -- section could never populate no matter what the pref said.
                    checklist = true,
                    -- Blizzard's tracker shows tracked achievements. Paired
                    -- with trackAchievements above.
                    achievements = true,
                    odyssey = true,
                    -- The world-quest reward filter (the spyglass menu) matches
                    -- on quest.rewardType, and rewardType is only computed when
                    -- this module is on. Off, that whole menu silently did
                    -- nothing except "All Rewards".
                    rewards = true,
                    -- Objectives are the core of a quest tracker. This gates
                    -- whether they can be read at all; profile.showObjectives
                    -- (false) governs whether they start expanded. Off, clicking
                    -- a row's expand icon did nothing on a fresh profile.
                    objectives = true,
                    questItems = true,
                    -- Ships ON, unlike most Artemis modules: this is parity
                    -- with a Blizzard tracker section we hide, so defaulting it
                    -- off would silently lose functionality the player had.
                    recipes = true,
                },
            },
            checklistTemplates = {
                builtInEnabled = {
                    focus = true,
                    pinned = true,
                    recurring = true,
                    expiring = true,
                    important = false,
                },
                customEntries = {},
            },
        },
        characters = {},
        window = {
            point = "TOPRIGHT",
            relativePoint = "TOPRIGHT",
            x = -350,
            y = -260,
            width = 760,
            height = 620,
            scale = 1,
            alpha = 1,
            displayState = "expanded",
            -- AR-004: persist tracker visibility across /reload so the user
            -- does not have to re-open Artemis after every UI reload.
            shown = true,
            ribbonPoint = "TOP",
            ribbonRelativePoint = "TOP",
            ribbonX = 0,
            ribbonY = -160,
            ribbonWidth = 280,
            ribbonHeight = 24,
        },
        cache = {
            questRewards = {},
            lastSeen = {},
        },
    }
end

local function MigrateLegacyState(state)
    if type(state) ~= "table" then
        return nil
    end

    if state.version == 2 and state.account and state.characters then
        return state
    end

    if type(state.profile) ~= "table" then
        return nil
    end

    local defaults = A:GetDefaults()
    local charKey = CharacterKey()
    local migrated = defaults
    local profile = state.profile

    local accountPrefs = migrated.account.preferences
    accountPrefs.enabled = profile.enabled ~= false
    accountPrefs.locked = profile.locked == true
    accountPrefs.theme = profile.theme or accountPrefs.theme
    accountPrefs.anchor = profile.anchor or accountPrefs.anchor
    accountPrefs.x = profile.x or accountPrefs.x
    accountPrefs.y = profile.y or accountPrefs.y
    accountPrefs.width = profile.width or accountPrefs.width
    accountPrefs.height = profile.height or accountPrefs.height
    accountPrefs.showObjectives = profile.showObjectives ~= false
    accountPrefs.showWorldQuestTimers = profile.showWQTimers ~= false
    accountPrefs.trackAchievements = profile.trackAchievements == true
    accountPrefs.autoHideInInstances = profile.autoHideInInstances ~= false
    accountPrefs.hideDefaultTracker = profile.hideDefaultTracker ~= false
    accountPrefs.filterMode = profile.filterMode or accountPrefs.filterMode
    accountPrefs.collapsedSections = profile.collapsed or {}

    migrated.window = migrated.window or {}
    migrated.window.point = profile.anchor or migrated.window.point
    migrated.window.relativePoint = profile.anchor or migrated.window.relativePoint
    migrated.window.x = profile.x or migrated.window.x
    migrated.window.y = profile.y or migrated.window.y
    migrated.window.width = profile.width or migrated.window.width
    migrated.window.height = profile.height or migrated.window.height

    migrated.characters[charKey] = {
        focusQuestID = profile.focusQuestID,
        focusObjectiveKey = nil,
        focusMode = profile.focusQuestID and "QUEST" or "NONE",
        collapsedSections = profile.collapsed or {},
        ignoredQuestIDs = {},
        manualChecklistState = {},
        pinnedQuestIDs = {},
        uiState = {
            scrollOffset = 0,
        },
    }

    return migrated
end

function A:GetCharacterKey()
    return CharacterKey()
end

function A:GetCharacterState()
    local charKey = CharacterKey()
    self.db.characters[charKey] = self.db.characters[charKey] or {
        focusQuestID = nil,
        focusObjectiveKey = nil,
        focusMode = "NONE",
        collapsedSections = {},
        ignoredQuestIDs = {},
        manualChecklistState = {},
        pinnedQuestIDs = {},
        -- AR-A3: per-character toggle for the Solo Focus mode button.
        soloFocus = false,
        -- Per-quest objective expansion, keyed by questID. Only expanded
        -- quests draw their objective rows, matching the default tracker.
        expandedQuestIDs = {},
        uiState = {
            scrollOffset = 0,
        },
    }
    -- Backfill for characters created before AR-A3 shipped.
    if self.db.characters[charKey].soloFocus == nil then
        self.db.characters[charKey].soloFocus = false
    end
    -- Backfill for characters created before per-quest expansion shipped. A
    -- nil table here would error on first index rather than read as "nothing
    -- expanded".
    if self.db.characters[charKey].expandedQuestIDs == nil then
        self.db.characters[charKey].expandedQuestIDs = {}
    end
    return self.db.characters[charKey]
end

-- Per-quest objective expansion. Clicking a row's quest icon toggles this;
-- clicking the row text still opens the quest log.
function A:IsQuestExpanded(questID)
    if not questID then
        return false
    end
    return self.character.expandedQuestIDs[questID] == true
end

function A:SetQuestExpanded(questID, expanded)
    if not questID then
        return
    end
    self.character.expandedQuestIDs[questID] = expanded and true or nil

    -- The scan caches each quest's objective list, and it only gathers
    -- objectives for quests that wanted them at scan time. Expanding a quest
    -- changes that answer, so the cached scan is now wrong: without this the
    -- row flips to "expanded" and still renders nothing, because the cached
    -- entry carries an empty objectives table.
    if self.QuestScan and type(self.QuestScan.Invalidate) == "function" then
        self.QuestScan:Invalidate()
    end
end

function A:ToggleQuestExpanded(questID)
    self:SetQuestExpanded(questID, not self:IsQuestExpanded(questID))
    return self:IsQuestExpanded(questID)
end

-- AR-A3: per-character helpers for the Solo Focus toggle. We keep these on
-- the addon root (instead of the Tracker module) so they are reachable
-- before the UI initializes.
function A:IsSoloFocusActive()
    local char = self:GetCharacterState()
    return char and char.soloFocus == true
end

function A:SetSoloFocusActive(enabled)
    local char = self:GetCharacterState()
    char.soloFocus = enabled and true or false
    if self.Tracker then
        self.Tracker:Refresh(true)
    end
end

function A:GetProfile()
    return self.db.account.preferences
end

function A:GetChecklistStore()
    return self.db.account.checklistTemplates
end

function A:IsModuleEnabled(moduleKey)
    local toggles = self.profile and self.profile.moduleToggles or nil
    if not toggles then
        return true
    end
    if toggles[moduleKey] == nil then
        return true
    end
    return toggles[moduleKey] == true
end

function A:SetModuleEnabled(moduleKey, enabled)
    self.profile.moduleToggles = self.profile.moduleToggles or {}
    self.profile.moduleToggles[moduleKey] = enabled and true or false

    if not enabled then
        if moduleKey == "checklist" then
            self.profile.showChecklist = false
            if self.profile.filterMode == "CHECKLIST" then
                self.profile.filterMode = "ALL"
            end
        elseif moduleKey == "worldQuests" and self.profile.filterMode == "WORLD" then
            self.profile.filterMode = "ALL"
        elseif moduleKey == "objectives" then
            self.profile.showObjectives = false
        elseif moduleKey == "questItems" then
            self.profile.showQuestItems = false
        end
    else
        -- Re-enabling must restore the paired display flag, or an off->on toggle
        -- leaves the content hidden (the flag was cleared on disable above).
        if moduleKey == "checklist" then
            self.profile.showChecklist = true
        elseif moduleKey == "objectives" then
            self.profile.showObjectives = true
        elseif moduleKey == "questItems" then
            self.profile.showQuestItems = true
        end
    end

    if self.QuestScan then
        self.QuestScan:Invalidate()
    end
    if self.Tracker then
        self.Tracker:Refresh(true)
    end
end

function A:ResolveStorage()
    local defaults = self:GetDefaults()
    local liveState

    if DataVault and DataVault.IsAvailable and DataVault:IsAvailable() then
        DataVault:EnsureNamespace(ADDON_KEY)
        liveState = DataVault:Get("account", ADDON_KEY, "state", nil)
        liveState = MigrateLegacyState(liveState) or liveState
        if type(liveState) ~= "table" then
            liveState = DeepCopy(defaults)
            DataVault:Set("account", ADDON_KEY, "state", liveState)
        else
            DeepMerge(liveState, defaults)
            DataVault:Set("account", ADDON_KEY, "state", liveState)
        end
        self._storageBackend = "DataVault"
    else
        _G.FabledUI_ArtemisDB = MigrateLegacyState(_G.FabledUI_ArtemisDB) or _G.FabledUI_ArtemisDB or DeepCopy(defaults)
        liveState = _G.FabledUI_ArtemisDB
        DeepMerge(liveState, defaults)
        self._storageBackend = "Local SVs"
    end

    self.db = liveState
    self.profile = self:GetProfile()
    self.character = self:GetCharacterState()
    self.cache = self.db.cache

    -- One-time correction: usable quest items shipped gated behind a module
    -- toggle that defaulted OFF, so the item buttons never appeared for existing
    -- profiles. Enable it once (respecting a later manual disable via the flag).
    if self.profile and not self.db.migratedQuestItems then
        self.db.migratedQuestItems = true
        self.profile.moduleToggles = self.profile.moduleToggles or {}
        if self.profile.moduleToggles.questItems ~= true then
            self.profile.moduleToggles.questItems = true
            self.profile.showQuestItems = true
        end
    end

    -- Sections added after a profile was created are invisible to DeepMerge:
    -- sectionOrder is an array, and DeepMerge only fills in absent *keys*, so
    -- index 1..n already exist and the new entry is never appended. Each new
    -- section therefore needs an explicit insert, or it silently never renders
    -- for anyone but a fresh install.
    if self.profile and type(self.profile.sectionOrder) == "table" then
        local order = self.profile.sectionOrder

        local function IndexOf(key)
            for i, existing in ipairs(order) do
                if existing == key then
                    return i
                end
            end
            return nil
        end

        -- Scenario pins to the top.
        if not IndexOf("SCENARIO") then
            table.insert(order, 1, "SCENARIO")
        end

        -- Recipes sit with the other derived sections, after the checklist and
        -- before achievements.
        if not IndexOf("RECIPES") then
            local anchor = IndexOf("ACHIEVEMENTS") or IndexOf("CURRENCIES")
            if anchor then
                table.insert(order, anchor, "RECIPES")
            else
                order[#order + 1] = "RECIPES"
            end
        end

        -- Traveler's Log sits with the other derived sections.
        if not IndexOf("ACTIVITIES") then
            local anchor = IndexOf("ACHIEVEMENTS") or IndexOf("CURRENCIES")
            if anchor then
                table.insert(order, anchor, "ACTIVITIES")
            else
                order[#order + 1] = "ACTIVITIES"
            end
        end

        -- Endeavors sit immediately after recipes, ahead of achievements.
        if not IndexOf("ENDEAVORS") then
            local anchor = IndexOf("ACHIEVEMENTS") or IndexOf("CURRENCIES")
            if anchor then
                table.insert(order, anchor, "ENDEAVORS")
            else
                order[#order + 1] = "ENDEAVORS"
            end
        end
    end
    self.db.window = self.db.window or {
        point = self.profile.anchor or "TOPRIGHT",
        relativePoint = self.profile.anchor or "TOPRIGHT",
        x = self.profile.x or -350,
        y = self.profile.y or -260,
        width = self.profile.width or 760,
        height = self.profile.height or 620,
        scale = 1,
        alpha = 1,
        displayState = "expanded",
        -- AR-004: persisted tracker visibility (default to shown).
        shown = true,
        ribbonPoint = "TOP",
        ribbonRelativePoint = "TOP",
        ribbonX = 0,
        ribbonY = -160,
        ribbonWidth = 280,
        ribbonHeight = 24,
    }
    self.window = self.db.window
    self.profile.anchor = self.db.window.point or self.profile.anchor
    self.profile.x = self.db.window.x or self.profile.x
    self.profile.y = self.db.window.y or self.profile.y
    self.profile.width = self.db.window.width or self.profile.width
    self.profile.height = self.db.window.height or self.profile.height
end

function A:SetFocusQuest(questID, objectiveKey)
    self.character.focusQuestID = questID
    self.character.focusObjectiveKey = objectiveKey
    self.character.focusMode = questID and (objectiveKey and "OBJECTIVE" or "QUEST") or "NONE"

    if self.profile.autoRouteFocusToOdyssey and questID then
        self.Odyssey:SetQuestFocus(questID, objectiveKey)
    elseif not questID then
        self.Odyssey:ClearFocus()
    end

    if self.Tracker then
        self.Tracker:Refresh(true)
    end
end

function A:ClearFocusQuest()
    self:SetFocusQuest(nil, nil)
end

function A:GetCollapsed(sectionKey)
    local char = self:GetCharacterState()
    if char.collapsedSections[sectionKey] ~= nil then
        return char.collapsedSections[sectionKey]
    end
    return self.profile.collapsedSections[sectionKey] == true
end

function A:SetCollapsed(sectionKey, isCollapsed)
    local char = self:GetCharacterState()
    char.collapsedSections[sectionKey] = isCollapsed and true or false
end

function A:IsQuestHidden(questID)
    return self.profile.hiddenQuestIDs[questID] == true or self.character.ignoredQuestIDs[questID] == true
end

function A:SetQuestHidden(questID, hidden)
    if not questID then
        return
    end
    self.character.ignoredQuestIDs[questID] = hidden and true or nil
end

function A:IsQuestPinned(questID)
    return questID and self.character.pinnedQuestIDs[questID] == true or false
end

function A:SetQuestPinned(questID, pinned)
    if not questID then
        return
    end
    self.character.pinnedQuestIDs[questID] = pinned and true or nil
end

function A:IsChecklistTemplateEnabled(key)
    local store = self:GetChecklistStore()
    return store.builtInEnabled[key] == true
end

function A:SetChecklistTemplateEnabled(key, enabled)
    local store = self:GetChecklistStore()
    store.builtInEnabled[key] = enabled and true or false
end

function A:SetChecklistHidden(entryID, hidden)
    if not entryID then
        return
    end
    self.profile.hiddenChecklistIDs[entryID] = hidden and true or nil
end

function A:SetActivePreset(presetKey)
    presetKey = tostring(presetKey or "STANDARD"):upper()
    if not self.DataModel.PRESETS[presetKey] then
        self:Print("Unknown preset:", presetKey)
        return
    end

    self.profile.activePreset = presetKey
    self.profile.filterMode = self.DataModel.PRESETS[presetKey].filterMode or "ALL"
    self.profile.showCurrentZoneOnly = self.DataModel.PRESETS[presetKey].currentZoneOnly == true
    self.profile.compactMode = self.DataModel.PRESETS[presetKey].compactMode == true
    self.profile.showChecklist = self.DataModel.PRESETS[presetKey].showChecklist ~= false

    if self.Tracker then
        self.Tracker:Refresh(true)
    end
end
