local A = FabledUI_Artemis or Artemis

A.Sections = A.Sections or {}
local S = A.Sections

local function PassesGlobalFilter(quest, scan)
    local mode = A.profile.filterMode or "ALL"
    local isFocused = A.character.focusQuestID and quest.questID == A.character.focusQuestID

    -- AR-A3: Solo Focus suppresses every non-focus quest entirely. Returning
    -- false here keeps unrelated quests from being added to any section, so
    -- the renderer naturally collapses to the focused quest only.
    if A:IsSoloFocusActive() then
        return isFocused
    end

    if mode == "FOCUS" then
        return isFocused
    end

    if mode == "WORLD" then
        return quest.isWorldQuest == true
    end

    if mode == "ZONE" then
        return A.Classifier:IsCurrentZoneQuest(quest, scan.currentMapID) == true
    end

    if mode == "CHECKLIST" then
        return false
    end

    -- Endeavors-only view. Endeavors are not quests, so no quest passes; the
    -- ENDEAVORS section is populated directly in Build.
    if mode == "ENDEAVORS" then
        return false
    end

    if A.profile.autoHideInInstances then
        local _, instanceType = IsInInstance()
        local inInstance = instanceType == "party" or instanceType == "raid"
        if inInstance and not isFocused then
            if quest.isWorldQuest then
                return false
            end
            if quest.mapID and scan.currentMapID and quest.mapID ~= scan.currentMapID then
                return false
            end
        end
    end

    return true
end

local function PassesWorldQuestFilters(quest)
    if not quest.isWorldQuest then
        return true
    end

    if A.WorldQuests and type(A.WorldQuests.PassesFilters) == "function" then
        local ok, passes = pcall(A.WorldQuests.PassesFilters, A.WorldQuests, quest)
        if ok then
            return passes == true
        end
    end

    return true
end

function S:Build(scan)
    -- AR: zone-grouped organization — one section per zone, current zone first.
    -- Single-purpose filter modes (Checklist, Endeavors) show exactly one
    -- section, so zone grouping has nothing to group; keep the normal builder.
    local mode = A.profile.filterMode or "ALL"
    if A.profile.groupByZone and mode ~= "CHECKLIST" and mode ~= "ENDEAVORS" then
        return self:BuildByZone(scan)
    end

    -- A single-purpose mode suppresses every section but its own. Without this
    -- an "Endeavors only" view still rendered recipes, currencies and
    -- achievements, because those sections are populated independently of the
    -- quest filter.
    local soloSection = (mode == "ENDEAVORS") and "ENDEAVORS" or nil
    local function SectionAllowed(key)
        return soloSection == nil or soloSection == key
    end

    local sections = {}
    local order = A.profile.sectionOrder or {}

    for _, sectionKey in ipairs(order) do
        sections[sectionKey] = {
            key = sectionKey,
            meta = A.DataModel:GetSection(sectionKey),
            items = {},
        }
    end

    for _, quest in ipairs(scan.quests) do
        if (A:IsModuleEnabled("worldQuests") or not quest.isWorldQuest) and not A:IsQuestHidden(quest.questID) and PassesGlobalFilter(quest, scan) and PassesWorldQuestFilters(quest) then
            if not A.profile.showCurrentZoneOnly or A.Classifier:IsCurrentZoneQuest(quest, scan.currentMapID) or A.character.focusQuestID == quest.questID then
                local sectionKey = A.Classifier:GetQuestSection(quest, scan)
                if sections[sectionKey] then
                    sections[sectionKey].items[#sections[sectionKey].items + 1] = quest
                end
            end
        end
    end

    -- AR-A3: Solo Focus suppresses checklist + achievements too so only the
    -- focused quest is visible. Quests are already filtered above.
    local soloFocus = A:IsSoloFocusActive()

    -- `A.Checklist and` is load-bearing: it comes from the separate
    -- FabledUI_Artemis_Checklist addon, not the base TOC. pcall does not
    -- protect its own argument expression, so pcall(A.Checklist.GetEntries)
    -- raises while BUILDING the call when the module addon is absent. This went
    -- unnoticed only because the checklist module used to default off;
    -- BuildByZone below already had the check.
    if SectionAllowed("CHECKLIST") and A.profile.showChecklist and A:IsModuleEnabled("checklist") and A.Checklist and sections.CHECKLIST and not soloFocus then
        local ok, entries = pcall(A.Checklist.GetEntries, A.Checklist, scan)
        sections.CHECKLIST.items = ok and entries or {}
    elseif sections.CHECKLIST then
        sections.CHECKLIST.items = {}
    end

    if SectionAllowed("ACHIEVEMENTS") and A.profile.trackAchievements and A:IsModuleEnabled("achievements") and sections.ACHIEVEMENTS and not soloFocus then
        sections.ACHIEVEMENTS.items = scan.achievements or {}
    elseif sections.ACHIEVEMENTS then
        sections.ACHIEVEMENTS.items = {}
    end

    -- Tracked profession recipes. Suppressed under Solo Focus like every other
    -- non-quest section.
    if SectionAllowed("RECIPES") and A.Recipes and sections.RECIPES and not soloFocus then
        local ok, entries = pcall(A.Recipes.BuildEntries, A.Recipes)
        sections.RECIPES.items = ok and entries or {}
    elseif sections.RECIPES then
        sections.RECIPES.items = {}
    end

    -- Tracked endeavors. Same suppression rule as recipes.
    if SectionAllowed("ENDEAVORS") and A.Endeavors and sections.ENDEAVORS and not soloFocus then
        local ok, entries = pcall(A.Endeavors.BuildEntries, A.Endeavors)
        sections.ENDEAVORS.items = ok and entries or {}
    elseif sections.ENDEAVORS then
        sections.ENDEAVORS.items = {}
    end

    -- Tracked Traveler's Log activities. Same suppression rule again.
    if SectionAllowed("ACTIVITIES") and A.Activities and sections.ACTIVITIES and not soloFocus then
        local ok, entries = pcall(A.Activities.BuildEntries, A.Activities)
        sections.ACTIVITIES.items = ok and entries or {}
    elseif sections.ACTIVITIES then
        sections.ACTIVITIES.items = {}
    end

    -- AR-A1: populate the currency tracker. Skip entirely while Solo Focus
    -- is active so the panel only shows the focused quest.
    if SectionAllowed("CURRENCIES") and A.Currency and sections.CURRENCIES and not soloFocus then
        local ok, entries = pcall(A.Currency.BuildEntries, A.Currency)
        sections.CURRENCIES.items = ok and entries or {}
    elseif sections.CURRENCIES then
        sections.CURRENCIES.items = {}
    end

    -- Scenario/instance objectives (delve/dungeon/raid/M+/event). Shown whenever
    -- active, regardless of Solo Focus (it's the content you're standing in).
    if SectionAllowed("SCENARIO") and A.Scenario and A.Scenario:IsActive() and sections.SCENARIO then
        sections.SCENARIO.meta = { key = "SCENARIO", label = A.Scenario:GetSectionLabel(), order = 5 }
        local ok, entries = pcall(A.Scenario.BuildEntries, A.Scenario)
        sections.SCENARIO.items = ok and entries or {}
    elseif sections.SCENARIO then
        sections.SCENARIO.items = {}
    end

    return sections, order
end

-- AR: category-grouped variant of Build. Focus stays pinned at the top; every
-- other quest is bucketed under its NATIVE quest-log header (the same zone /
-- special-category headers Blizzard shows: "Dungeon", "Raid", "Weekly Event",
-- "Neighborhood", "Eversong Woods", ...). Groups follow the log's own order;
-- checklist + currencies trail at the bottom as usual.
function S:BuildByZone(scan)
    local sections = {}
    local order = {}
    local soloFocus = A:IsSoloFocusActive()
    local focusQuestID = A.character.focusQuestID

    -- Scenario/instance objectives pinned above everything.
    if A.Scenario and A.Scenario:IsActive() then
        sections.SCENARIO = { key = "SCENARIO", meta = { key = "SCENARIO", label = A.Scenario:GetSectionLabel(), order = 5 }, items = {} }
        local ok, entries = pcall(A.Scenario.BuildEntries, A.Scenario)
        sections.SCENARIO.items = ok and entries or {}
        order[#order + 1] = "SCENARIO"
    end

    -- Focus section pinned first (reuse the DataModel meta for consistent styling).
    sections.FOCUS = { key = "FOCUS", meta = A.DataModel:GetSection("FOCUS"), items = {} }
    order[#order + 1] = "FOCUS"

    local groupOrder, groupSeen = {}, {}

    -- Prefer the native log header; fall back to a zone name (world quests /
    -- tasks aren't in the log), then a generic bucket.
    local function GroupNameFor(quest)
        if quest.headerTitle and quest.headerTitle ~= "" then
            return quest.headerTitle
        end
        if quest.isWorldQuest then
            return "World Quests"
        end
        if quest.mapID then
            local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(quest.mapID)
            if info and info.name then
                return info.name
            end
        end
        return "Other Quests"
    end

    local function GroupSection(name)
        local key = "GROUP_" .. name
        if not sections[key] then
            sections[key] = { key = key, meta = { key = key, label = name, order = 50 }, items = {} }
            if not groupSeen[name] then
                groupSeen[name] = true
                groupOrder[#groupOrder + 1] = name
            end
        end
        return sections[key]
    end

    for _, quest in ipairs(scan.quests) do
        if (A:IsModuleEnabled("worldQuests") or not quest.isWorldQuest)
            and not A:IsQuestHidden(quest.questID)
            and PassesGlobalFilter(quest, scan)
            and PassesWorldQuestFilters(quest) then
            if focusQuestID and quest.questID == focusQuestID then
                sections.FOCUS.items[#sections.FOCUS.items + 1] = quest
            else
                local s = GroupSection(GroupNameFor(quest))
                s.items[#s.items + 1] = quest
            end
        end
    end

    -- Order groups by the quest log's native header order; groups not present in
    -- the log (world quests / fallbacks) trail alphabetically after.
    local logRank = {}
    for i, name in ipairs(scan.headerOrder or {}) do
        logRank[name] = i
    end
    table.sort(groupOrder, function(a, b)
        local ra, rb = logRank[a], logRank[b]
        if ra and rb then return ra < rb end
        if ra then return true end
        if rb then return false end
        return tostring(a):lower() < tostring(b):lower()
    end)
    for _, name in ipairs(groupOrder) do
        order[#order + 1] = "GROUP_" .. name
    end

    -- Checklist + currencies trail the zone sections (mirrors Build).
    if A.profile.showChecklist and A:IsModuleEnabled("checklist") and A.Checklist and not soloFocus then
        sections.CHECKLIST = { key = "CHECKLIST", meta = A.DataModel:GetSection("CHECKLIST"), items = {} }
        local ok, entries = pcall(A.Checklist.GetEntries, A.Checklist, scan)
        sections.CHECKLIST.items = ok and entries or {}
        order[#order + 1] = "CHECKLIST"
    end

    if A.Recipes and not soloFocus then
        sections.RECIPES = { key = "RECIPES", meta = A.DataModel:GetSection("RECIPES"), items = {} }
        local ok, entries = pcall(A.Recipes.BuildEntries, A.Recipes)
        sections.RECIPES.items = ok and entries or {}
        order[#order + 1] = "RECIPES"
    end

    if A.Endeavors and not soloFocus then
        sections.ENDEAVORS = { key = "ENDEAVORS", meta = A.DataModel:GetSection("ENDEAVORS"), items = {} }
        local ok, entries = pcall(A.Endeavors.BuildEntries, A.Endeavors)
        sections.ENDEAVORS.items = ok and entries or {}
        order[#order + 1] = "ENDEAVORS"
    end

    if A.Activities and not soloFocus then
        sections.ACTIVITIES = { key = "ACTIVITIES", meta = A.DataModel:GetSection("ACTIVITIES"), items = {} }
        local ok, entries = pcall(A.Activities.BuildEntries, A.Activities)
        sections.ACTIVITIES.items = ok and entries or {}
        order[#order + 1] = "ACTIVITIES"
    end

    if A.Currency and not soloFocus then
        sections.CURRENCIES = { key = "CURRENCIES", meta = A.DataModel:GetSection("CURRENCIES"), items = {} }
        local ok, entries = pcall(A.Currency.BuildEntries, A.Currency)
        sections.CURRENCIES.items = ok and entries or {}
        order[#order + 1] = "CURRENCIES"
    end

    return sections, order
end
