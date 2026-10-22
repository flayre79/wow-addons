local A = FabledUI_Artemis or Artemis
if not A or not A.Modules then
    return
end

local Checklist = {
    providerKey = "child-checklist",
    moduleName = "FabledUI_Artemis_Checklist",
}

local function QuestFrequencyValue(key)
    return Enum and Enum.QuestFrequency and Enum.QuestFrequency[key] or nil
end

local function BuildDerivedEntry(kind, quest)
    return {
        id = string.format("%s:%d", kind, quest.questID),
        questID = quest.questID,
        label = quest.title,
        type = kind,
        mapID = quest.mapID,
        mapName = quest.mapName,
        timeLeftText = quest.timeLeftText,
        rewardText = quest.rewardText,
        completed = false,
        source = "derived",
    }
end

local function AddEntry(entries, seen, entry)
    if not entry or not entry.id or seen[entry.id] or A.profile.hiddenChecklistIDs[entry.id] then
        return
    end
    seen[entry.id] = true
    entries[#entries + 1] = entry
end

local function AddQuestEntry(entries, seen, kind, quest, tag)
    if not quest or A:IsQuestHidden(quest.questID) then
        return
    end
    local entry = BuildDerivedEntry(kind, quest)
    entry.templateKey = tag
    AddEntry(entries, seen, entry)
end

function Checklist:IsAvailable()
    return true
end

function Checklist:ToggleManualEntry(entryID)
    if not entryID then
        return
    end
    local state = A.character.manualChecklistState
    state[entryID] = not state[entryID]
    if A.Tracker then
        A.Tracker:Refresh(true)
    end
end

-- =====================================================================
-- P2-10: MR-style RegisterModule API
-- ---------------------------------------------------------------------
-- Modules are bundles of related rows that the renderer walks in order.
-- Shape mirrors MidnightRoutine/Core.lua RegisterModule:
--   {
--     key         = "<unique-string>",
--     label       = "<display title>",
--     labelColor  = "#rrggbb"?,
--     resetType   = "daily" | "weekly" | "monthly" | "auto" | "none",
--     defaultOpen = bool?,
--     rows = {
--       { key, label, max?, note?, questIds?, timerEpoch?,
--         timerInterval?, timerDuration? },
--       ...
--     },
--   }
-- For rows whose resetType is "auto" the renderer asks
-- Checklist:DetectFrequency(row.questIds[1]) at render time.
-- =====================================================================

Checklist._modules        = Checklist._modules or {}
Checklist._modulesByKey   = Checklist._modulesByKey or {}

function Checklist:RegisterModule(def)
    assert(type(def) == "table",   "Checklist:RegisterModule expects a table")
    assert(def.key,    "Checklist module missing .key")
    assert(def.label,  "Checklist module missing .label")
    assert(def.rows,   "Checklist module missing .rows")
    if self._modulesByKey[def.key] then
        -- Replacing is allowed (data files reload on /reload).
        for index, existing in ipairs(self._modules) do
            if existing.key == def.key then
                self._modules[index] = def
                self._modulesByKey[def.key] = def
                return def
            end
        end
    end
    self._modules[#self._modules + 1] = def
    self._modulesByKey[def.key] = def
    return def
end

function Checklist:GetModules()
    return self._modules
end

function Checklist:GetModule(key)
    return self._modulesByKey[key]
end

-- =====================================================================
-- P2-11: Quest-frequency auto-detection
-- ---------------------------------------------------------------------
-- Pattern lifted from MidnightRoutine Modules/CustomTasks.lua lines 90-118.
-- Returns "daily" | "weekly" | "once" | nil.
-- =====================================================================

function Checklist:DetectFrequency(questID)
    if not questID or not C_QuestLog then
        return nil
    end

    local logIndex = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if logIndex and logIndex > 0 and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(logIndex)
        local frequency = info and info.frequency
        local dailyValue  = QuestFrequencyValue("Daily")  or 1
        local weeklyValue = QuestFrequencyValue("Weekly") or 2

        if frequency == dailyValue then
            return "daily"
        elseif frequency == weeklyValue then
            return "weekly"
        elseif frequency ~= nil then
            return "once"
        end
    end

    if GetQuestID and GetQuestID() == questID then
        if QuestIsDaily and QuestIsDaily() then
            return "daily"
        end
        if QuestIsWeekly and QuestIsWeekly() then
            return "weekly"
        end
    end

    return nil
end

-- Resolve a row's effective reset type: explicit value wins; "auto" falls
-- through to DetectFrequency on the first questID; nil/none leave it
-- alone so the renderer can decide.
function Checklist:ResolveRowResetType(row, moduleResetType)
    if type(row) ~= "table" then
        return moduleResetType
    end
    local resetType = row.resetType or moduleResetType
    if resetType == "auto" then
        local ids = row.questIds
        if type(ids) == "table" and ids[1] then
            local detected = self:DetectFrequency(ids[1])
            if detected then
                return detected
            end
        end
        return nil
    end
    return resetType
end

-- =====================================================================
-- Larias snapshot -> module registration
-- ---------------------------------------------------------------------
-- The existing data file (Data/MidnightWeekly.lua) stores the snapshot
-- as an array of weeks. We wrap each week as a module so the new
-- RegisterModule API covers the same content. The renderer below still
-- emits the same per-item entries it always did, so the existing
-- multi-character panel keeps working.
-- =====================================================================

local function GetLariasWeeks()
    return (A.Data and A.Data.MidnightWeekly)
        or (_G.FabledUI_Artemis_Checklist and _G.FabledUI_Artemis_Checklist.Data and _G.FabledUI_Artemis_Checklist.Data.MidnightWeekly)
end

function Checklist:EnsureLariasModulesRegistered()
    if self._lariasRegistered then
        return
    end
    local weeks = GetLariasWeeks()
    if type(weeks) ~= "table" then
        return
    end
    for _, week in ipairs(weeks) do
        if type(week) == "table" and type(week.items) == "table" then
            local rows = {}
            for _, item in ipairs(week.items) do
                rows[#rows + 1] = {
                    key   = item.id,
                    label = item.text or item.id,
                    max   = 1,
                    note  = item.notes,
                }
            end
            self:RegisterModule({
                key         = "larias:" .. tostring(week.id or "?"),
                label       = week.title or week.id or "Larias Week",
                labelColor  = "#e5bc55",
                resetType   = "weekly",
                defaultOpen = true,
                rows        = rows,
                source      = "larias",
                weekID      = week.id,
            })
        end
    end
    self._lariasRegistered = true
end

local function AppendLariasEntries(self, entries, seen, templateFlags)
    if templateFlags.lariasWeekly == false then
        return
    end
    -- Walk the registered modules whose source is "larias" so the same
    -- output shape that already drives the multi-char panel is preserved.
    for _, mod in ipairs(self:GetModules()) do
        if mod.source == "larias" then
            for _, row in ipairs(mod.rows or {}) do
                local entryID = string.format("larias:%s:%s", tostring(mod.weekID or "?"), tostring(row.key or "?"))
                local completed = A.character.manualChecklistState[entryID] == true
                local resetType = self:ResolveRowResetType(row, mod.resetType) or "weekly"
                AddEntry(entries, seen, {
                    id         = entryID,
                    label      = row.label or row.key,
                    type       = resetType,
                    mapName    = mod.label,
                    rewardText = row.note,
                    completed  = completed,
                    source     = "larias",
                })
            end
        end
    end
end

function Checklist:GetEntries(scan)
    local entries = {}
    local seen = {}
    if not A.profile.showChecklist then
        return entries
    end

    -- Lazy: register the Larias snapshot through the new API the first
    -- time we render. Keeping it lazy means the data file load order
    -- (parent vs child global) doesn't matter.
    self:EnsureLariasModulesRegistered()

    local templateFlags = A:GetChecklistStore().builtInEnabled or {}

    for _, quest in ipairs(scan.quests) do
        if templateFlags.focus and A.character.focusQuestID and quest.questID == A.character.focusQuestID then
            AddQuestEntry(entries, seen, "focus", quest, "focus")
        end

        if templateFlags.pinned and A:IsQuestPinned(quest.questID) then
            AddQuestEntry(entries, seen, "pinned", quest, "pinned")
        end

        if templateFlags.important and quest.isImportant then
            AddQuestEntry(entries, seen, "important", quest, "important")
        end

        if templateFlags.recurring then
            if quest.frequency == QuestFrequencyValue("Daily") then
                AddQuestEntry(entries, seen, "daily", quest, "recurring")
            elseif quest.frequency == QuestFrequencyValue("Weekly") then
                AddQuestEntry(entries, seen, "weekly", quest, "recurring")
            elseif quest.isRecurring and not quest.isWorldQuest then
                AddQuestEntry(entries, seen, "recurring", quest, "recurring")
            end
        end

        if templateFlags.expiring and quest.isWorldQuest and quest.timeLeftMinutes and quest.timeLeftMinutes <= 240 then
            AddQuestEntry(entries, seen, "expiring", quest, "expiring")
        end
    end

    local customEntries = A:GetChecklistStore().customEntries or {}
    for _, entry in ipairs(customEntries) do
        if entry.enabled ~= false then
            local completed = A.character.manualChecklistState[entry.id] == true
            AddEntry(entries, seen, {
                id = entry.id,
                label = entry.label,
                type = entry.type or "custom",
                mapID = entry.mapID,
                x = entry.x,
                y = entry.y,
                questID = entry.questID,
                rewardText = entry.notes,
                completed = completed,
                source = "custom",
            })
        end
    end

    -- Larias Midnight weekly snapshot. Now sourced from the registered
    -- module list rather than walking the raw data table directly.
    AppendLariasEntries(self, entries, seen, templateFlags)

    table.sort(entries, function(a, b)
        if (a.completed == true) ~= (b.completed == true) then
            return a.completed ~= true
        end
        if (a.timeLeftText or "") ~= (b.timeLeftText or "") then
            return (a.timeLeftText or "") < (b.timeLeftText or "")
        end
        return (a.label or a.id or "") < (b.label or b.id or "")
    end)

    return entries
end

A.Modules:Register("checklist", Checklist)
A.Checklist = Checklist
