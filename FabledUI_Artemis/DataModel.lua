local A = FabledUI_Artemis or Artemis

A.DataModel = A.DataModel or {}
local D = A.DataModel

D.SECTIONS = {
    -- Scenario/instance objectives (delve, dungeon, raid, M+, event) pinned above all.
    SCENARIO = { key = "SCENARIO", label = "Scenario", order = 5 },
    FOCUS = { key = "FOCUS", label = "Focused", order = 10 },
    EXPIRING = { key = "EXPIRING", label = "Expiring Soon", order = 20 },
    CAMPAIGN = { key = "CAMPAIGN", label = "Campaign", order = 30 },
    CURRENT_ZONE = { key = "CURRENT_ZONE", label = "Current Zone", order = 40 },
    WORLD = { key = "WORLD", label = "World Quests", order = 50 },
    DAILY = { key = "DAILY", label = "Dailies", order = 60 },
    WEEKLY = { key = "WEEKLY", label = "Weeklies", order = 70 },
    MONTHLY = { key = "MONTHLY", label = "Monthly / Seasonal", order = 80 },
    QUESTS = { key = "QUESTS", label = "Story / Side Quests", order = 90 },
    BONUS = { key = "BONUS", label = "Bonus / Event", order = 100 },
    CHECKLIST = { key = "CHECKLIST", label = "Checklist", order = 110 },
    -- Tracked profession recipes. Default-tracker parity: Blizzard shows these
    -- and we hide Blizzard's tracker, so without this section they vanish.
    RECIPES = { key = "RECIPES", label = "Recipes", order = 115 },
    -- Tracked Neighborhood Initiative tasks. Same parity argument as RECIPES:
    -- Blizzard lists them and we hide Blizzard's tracker.
    ENDEAVORS = { key = "ENDEAVORS", label = "Endeavors", order = 117 },
    -- Tracked Traveler's Log activities. Same parity argument as ENDEAVORS.
    ACTIVITIES = { key = "ACTIVITIES", label = "Traveler's Log", order = 118 },
    ACHIEVEMENTS = { key = "ACHIEVEMENTS", label = "Achievements", order = 120 },
    -- AR-A1: Currency tracker section. Renders a compact list of tracked
    -- currencies (gold + Midnight weekly currencies) with reset timers.
    CURRENCIES = { key = "CURRENCIES", label = "Currencies", order = 130 },
}

D.PRESETS = {
    STANDARD = {
        label = "Standard",
        filterMode = "ALL",
        currentZoneOnly = false,
        compactMode = false,
        showChecklist = true,
    },
    MINIMAL = {
        label = "Minimal",
        filterMode = "ALL",
        currentZoneOnly = false,
        compactMode = true,
        showChecklist = false,
    },
    FOCUS = {
        label = "Focus",
        filterMode = "FOCUS",
        currentZoneOnly = false,
        compactMode = false,
        showChecklist = true,
    },
    WORLD = {
        label = "World Quest Focus",
        filterMode = "WORLD",
        currentZoneOnly = false,
        compactMode = false,
        showChecklist = true,
    },
    ZONE = {
        label = "Current Zone",
        filterMode = "ZONE",
        currentZoneOnly = true,
        compactMode = false,
        showChecklist = true,
    },
    CHECKLIST = {
        label = "Checklist",
        filterMode = "CHECKLIST",
        currentZoneOnly = false,
        compactMode = false,
        showChecklist = true,
    },
}

D.WQ_REWARD_FILTERS = {
    ALL = "All Rewards",
    MONEY = "Gold Only",
    CURRENCY = "Currency Only",
    ITEM = "Items Only",
    GEAR = "Gear Rewards",
    REPUTATION = "Reputation",
    NONE = "No Reward Data",
}

D.WQ_TIME_FILTERS = {
    ALL = "Any Time",
    LT_30 = "Under 30m",
    LT_120 = "Under 2h",
    LT_720 = "Under 12h",
    LT_1440 = "Under 24h",
}

D.CHECKLIST_TEMPLATES = {
    focus = {
        key = "focus",
        label = "Focused Quest",
        description = "Show the current focus quest in the checklist.",
    },
    pinned = {
        key = "pinned",
        label = "Pinned Quests",
        description = "Promote pinned quests into the checklist bucket.",
    },
    recurring = {
        key = "recurring",
        label = "Recurring Quests",
        description = "Show daily, weekly, and recurring quests as checklist entries.",
    },
    expiring = {
        key = "expiring",
        label = "Expiring World Quests",
        description = "Show soon-expiring world quests in the checklist bucket.",
    },
    important = {
        key = "important",
        label = "Important Quests",
        description = "Surface important quests as checklist reminders.",
    },
}

D.ODYSSEY_ROUTE_MODES = {
    APPEND = "Append Route",
    REPLACE = "Replace Route",
    FOCUS = "Set Focus Target",
}

function D:GetSection(sectionKey)
    return self.SECTIONS[sectionKey]
end

function D:GetPresetKeys()
    local keys = {}
    for key in pairs(self.PRESETS) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function D:GetWorldQuestRewardFilterLabel(key)
    return self.WQ_REWARD_FILTERS[key] or self.WQ_REWARD_FILTERS.ALL
end

function D:GetWorldQuestTimeFilterLabel(key)
    return self.WQ_TIME_FILTERS[key] or self.WQ_TIME_FILTERS.ALL
end

function D:GetSortedRewardFilterKeys()
    local keys = {}
    for key in pairs(self.WQ_REWARD_FILTERS) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function D:GetSortedTimeFilterKeys()
    local keys = {}
    for key in pairs(self.WQ_TIME_FILTERS) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function D:GetChecklistTemplateKeys()
    local keys = {}
    for key in pairs(self.CHECKLIST_TEMPLATES) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function D:GetChecklistTemplateLabel(key)
    local template = self.CHECKLIST_TEMPLATES[key]
    return template and template.label or key
end

function D:GetOdysseyRouteModeKeys()
    local keys = {}
    for key in pairs(self.ODYSSEY_ROUTE_MODES) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function D:GetOdysseyRouteModeLabel(key)
    return self.ODYSSEY_ROUTE_MODES[key] or self.ODYSSEY_ROUTE_MODES.APPEND
end
