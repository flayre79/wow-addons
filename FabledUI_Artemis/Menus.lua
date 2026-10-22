local A = FabledUI_Artemis or Artemis

A.Menus = A.Menus or {}
local M = A.Menus

local function SupportsMenus()
    return type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function"
end

-- Selection state goes through the menu API's own check/radio glyph, never a
-- "✓ " text prefix. The default UI font has no glyph for U+2713, so the prefix
-- rendered as a missing-glyph box -- the same trap CLAUDE.md records for "≡".
-- One checklist menu had already been converted; these are the rest.
--
-- AddChoice is for one-of-many (preset, reward type, expiration, route mode);
-- AddToggle is for independent booleans. CreateRadio and CreateCheckbox take
-- the same (text, isSelected, onSelect) shape, so the fallback is a swap --
-- worth having because a client without CreateRadio would otherwise drop the
-- entire menu rather than one glyph.
local function AddChoice(root, label, isSelected, onSelect)
    if type(root.CreateRadio) == "function" then
        return root:CreateRadio(label, isSelected, onSelect)
    end
    return root:CreateCheckbox(label, isSelected, onSelect)
end

local function AddToggle(root, label, isChecked, onToggle)
    return root:CreateCheckbox(label, isChecked, onToggle)
end

function M:OpenPresetMenu(owner)
    if not SupportsMenus() then
        return false
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Tracker Preset")
        for _, presetKey in ipairs(A.DataModel:GetPresetKeys()) do
            local preset = A.DataModel.PRESETS[presetKey]
            AddChoice(rootDescription, preset.label or presetKey, function()
                return A.profile.activePreset == presetKey
            end, function()
                A:SetActivePreset(presetKey)
            end)
        end
    end)
    return true
end

function M:OpenWorldQuestFilterMenu(owner)
    if not SupportsMenus() then
        return false
    end

    local filters = A.profile.worldQuestFilters or {}
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("World Quest Filters")
        AddToggle(rootDescription, "Tracked or Pinned Only", function()
            return filters.trackedOnly == true
        end, function()
            filters.trackedOnly = not filters.trackedOnly
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)

        rootDescription:CreateDivider()
        rootDescription:CreateTitle("Reward Type")
        for _, key in ipairs(A.DataModel:GetSortedRewardFilterKeys()) do
            AddChoice(rootDescription, A.DataModel:GetWorldQuestRewardFilterLabel(key), function()
                return (filters.reward or "ALL") == key
            end, function()
                filters.reward = key
                if A.Tracker then
                    A.Tracker:Refresh(true)
                end
            end)
        end

        rootDescription:CreateDivider()
        rootDescription:CreateTitle("Expiration")
        for _, key in ipairs(A.DataModel:GetSortedTimeFilterKeys()) do
            AddChoice(rootDescription, A.DataModel:GetWorldQuestTimeFilterLabel(key), function()
                return (filters.time or "ALL") == key
            end, function()
                filters.time = key
                if A.Tracker then
                    A.Tracker:Refresh(true)
                end
            end)
        end
    end)

    return true
end

function M:OpenChecklistTemplateMenu(owner)
    if not SupportsMenus() then
        return false
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Checklist Templates")
        for _, key in ipairs(A.DataModel:GetChecklistTemplateKeys()) do
            local template = A.DataModel.CHECKLIST_TEMPLATES[key]
            AddToggle(rootDescription, template.label or key, function()
                return A:IsChecklistTemplateEnabled(key)
            end, function()
                A:SetChecklistTemplateEnabled(key, not A:IsChecklistTemplateEnabled(key))
                if A.Tracker then
                    A.Tracker:Refresh(true)
                end
            end)
        end
    end)

    return true
end

function M:OpenOdysseyModeMenu(owner)
    if not SupportsMenus() then
        return false
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Odyssey Routing")
        for _, key in ipairs(A.DataModel:GetOdysseyRouteModeKeys()) do
            AddChoice(rootDescription, A.DataModel:GetOdysseyRouteModeLabel(key), function()
                return (A.profile.odysseyRouteMode or "APPEND") == key
            end, function()
                A.profile.odysseyRouteMode = key
                if A.Tracker then
                    A.Tracker:Refresh(true)
                end
            end)
        end
        rootDescription:CreateDivider()
        AddToggle(rootDescription, "Open map when focus changes", function()
            return A.profile.odysseyOpenMapOnFocus == true
        end, function()
            A.profile.odysseyOpenMapOnFocus = not A.profile.odysseyOpenMapOnFocus
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)
    end)

    return true
end

function M:OpenSectionMenu(owner, sectionKey, itemCount, label)
    if not SupportsMenus() then
        return false
    end

    local section = A.DataModel:GetSection(sectionKey)
    local title = label or (section and section.label) or sectionKey
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(title .. " (" .. tostring(itemCount or 0) .. ")")
        rootDescription:CreateButton(A:GetCollapsed(sectionKey) and "Expand Section" or "Collapse Section", function()
            A:SetCollapsed(sectionKey, not A:GetCollapsed(sectionKey))
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)

        if sectionKey == "CHECKLIST" then
            rootDescription:CreateDivider()
            for _, key in ipairs(A.DataModel:GetChecklistTemplateKeys()) do
                local templateLabel = A.DataModel:GetChecklistTemplateLabel(key)
                -- Native menu checkbox instead of a "✓ " text prefix (which rendered
                -- as a missing-glyph box in the default font).
                rootDescription:CreateCheckbox(templateLabel, function()
                    return A:IsChecklistTemplateEnabled(key)
                end, function()
                    A:SetChecklistTemplateEnabled(key, not A:IsChecklistTemplateEnabled(key))
                    if A.Tracker then
                        A.Tracker:Refresh(true)
                    end
                end)
            end
        end
    end)

    return true
end

function M:OpenQuestMenu(owner, quest)
    if not SupportsMenus() or type(quest) ~= "table" then
        return false
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(quest.title or ("Quest " .. tostring(quest.questID)))

        -- Objective expansion is primarily the row icon; it is here too because
        -- a control with no label is only discoverable once you have found it.
        rootDescription:CreateButton(
            A:IsQuestExpanded(quest.questID) and "Hide Objectives" or "Show Objectives",
            function()
                A:ToggleQuestExpanded(quest.questID)
                if A.Tracker then
                    A.Tracker:Refresh(true)
                end
            end)

        -- Wording matches the row tooltip. This is super-tracking -- the same
        -- target the world-map POI sets and the navigation arrow follows.
        if A.Util:IsSuperTracked(quest.questID) then
            rootDescription:CreateButton("Stop Navigating", function()
                A.Util:ClearWaypoint()
            end)
        else
            rootDescription:CreateButton("Navigate Here", function()
                A.Util:SuperTrackQuest(quest.questID)
            end)
        end
        rootDescription:CreateButton("Open on Map", function()
            A.Util:OpenQuestDetails(quest.questID)
        end)
        rootDescription:CreateButton(A.character.focusQuestID == quest.questID and "Clear Focus" or "Focus Quest", function()
            if A.character.focusQuestID == quest.questID then
                A:ClearFocusQuest()
            else
                A:SetFocusQuest(quest.questID)
            end
        end)
        rootDescription:CreateButton(A:IsQuestPinned(quest.questID) and "Unpin from Checklist" or "Pin to Checklist", function()
            A:SetQuestPinned(quest.questID, not A:IsQuestPinned(quest.questID))
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)
        rootDescription:CreateDivider()
        rootDescription:CreateButton("Odyssey: Append Route", function()
            if not A.Odyssey:PushQuest(quest.questID, "APPEND") then
                A:Print("Odyssey bridge not available for quest routing.")
            end
        end)
        rootDescription:CreateButton("Odyssey: Replace Route", function()
            if not A.Odyssey:PushQuest(quest.questID, "REPLACE") then
                A:Print("Odyssey bridge not available for quest routing.")
            end
        end)
        rootDescription:CreateButton("Odyssey: Set Focus Target", function()
            if not A.Odyssey:PushQuest(quest.questID, "FOCUS") then
                A:Print("Odyssey bridge not available for quest routing.")
            end
        end)
        rootDescription:CreateButton("Open on Map", function()
            A.Odyssey:OpenMapForQuest(quest.questID)
        end)
        rootDescription:CreateDivider()
        rootDescription:CreateButton(A:IsQuestHidden(quest.questID) and "Unhide Quest" or "Hide Quest", function()
            A:SetQuestHidden(quest.questID, not A:IsQuestHidden(quest.questID))
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)
    end)

    return true
end

function M:OpenAchievementMenu(owner, achievementID)
    if not SupportsMenus() then
        return false
    end

    local _, name = GetAchievementInfo(achievementID)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(name or ("Achievement " .. tostring(achievementID)))
        rootDescription:CreateButton("Open Achievement", function()
            ToggleAchievementFrame()
            if AchievementFrame_SelectAchievement then
                AchievementFrame_SelectAchievement(achievementID)
            end
        end)
        rootDescription:CreateDivider()
        rootDescription:CreateButton("Untrack Achievement", function()
            A.Util:UntrackAchievement(achievementID)
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)
    end)

    return true
end

function M:OpenChecklistMenu(owner, entry)
    if not SupportsMenus() or type(entry) ~= "table" then
        return false
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(entry.label or entry.id or "Checklist")
        if entry.questID then
            rootDescription:CreateButton("Open Quest Details", function()
                A.Util:OpenQuestDetails(entry.questID)
            end)
        end
        rootDescription:CreateButton("Odyssey: Append Route", function()
            if not A.Odyssey:PushChecklist(entry, "APPEND") then
                A:Print("Odyssey bridge not available for checklist routing.")
            end
        end)
        rootDescription:CreateButton("Odyssey: Replace Route", function()
            if not A.Odyssey:PushChecklist(entry, "REPLACE") then
                A:Print("Odyssey bridge not available for checklist routing.")
            end
        end)
        rootDescription:CreateButton("Odyssey: Set Focus Target", function()
            if not A.Odyssey:PushChecklist(entry, "FOCUS") then
                A:Print("Odyssey bridge not available for checklist routing.")
            end
        end)
        if entry.source == "custom" then
            rootDescription:CreateButton((A.character.manualChecklistState[entry.id] and "Mark Incomplete" or "Mark Complete"), function()
                A.Checklist:ToggleManualEntry(entry.id)
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(A.profile.hiddenChecklistIDs[entry.id] and "Unhide Entry" or "Hide Entry", function()
            A:SetChecklistHidden(entry.id, not A.profile.hiddenChecklistIDs[entry.id])
            if A.Tracker then
                A.Tracker:Refresh(true)
            end
        end)
    end)

    return true
end
