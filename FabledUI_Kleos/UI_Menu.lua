local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Menu
-- The right-click menu from the scope doc: links to Wowhead, the instance
-- tracker, transmog sets, related achievements and pet guides, plus the
-- watch/exclude/track actions.
--
-- MenuUtil is the modern context-menu API and is used when present. The
-- fallback is a small button panel rather than nothing, because on a client
-- without MenuUtil the right-click menu is the only way to reach some of these
-- actions.
-- ============================================================================

K.Menu = K.Menu or {}
local Menu = K.Menu

local WOWHEAD_URL = "https://www.wowhead.com/achievement=%d"

-- ----------------------------------------------------------------------------
-- URL copy popup: WoW cannot put text on the OS clipboard, so the honest
-- version is a focused, pre-selected edit box the player copies from.
-- ----------------------------------------------------------------------------
function Menu:ShowURL(url, label)
    local popup = self._urlPopup
    if not popup then
        popup = W:Panel(UIParent, "FabledUI_KleosURLPopup")
        popup:SetSize(420, 96)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:EnableMouse(true)
        popup:SetMovable(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

        popup.title = W:Label(popup, "", "GameFontNormal")
        popup.title:SetPoint("TOPLEFT", 12, -10)

        popup.box = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.box:SetSize(380, 22)
        popup.box:SetPoint("TOPLEFT", 16, -34)
        popup.box:SetAutoFocus(true)
        popup.box:SetScript("OnEscapePressed", function() popup:Hide() end)
        popup.box:SetScript("OnEnterPressed", function() popup:Hide() end)

        popup.hint = W:Label(popup, K.L.COPY_HINT or "Press Ctrl-C to copy, Escape to close.", "GameFontHighlightSmall")
        popup.hint:SetPoint("BOTTOMLEFT", 14, 10)

        tinsert(UISpecialFrames, "FabledUI_KleosURLPopup")
        self._urlPopup = popup
    end

    popup.title:SetText(label or (K.L.LINK_ACTION or "Link"))
    popup.box:SetText(url or "")
    popup.box:HighlightText()
    popup:Show()
    popup.box:SetFocus()
    return popup
end

-- ----------------------------------------------------------------------------
-- Action list
-- Each entry: { text, fn, submenu = { ... } }. Built once per open so the
-- labels reflect the current watch/exclude/track state.
-- ----------------------------------------------------------------------------
function Menu:BuildActions(id, panel)
    id = tonumber(id)
    if not id then return {} end

    local actions = {}
    local rewardTypes = {}
    for _, typeKey in ipairs(K.Rewards:GetTypes(id)) do rewardTypes[typeKey] = true end

    actions[#actions + 1] = {
        text = K:IsWatched(id) and (K.L.UNWATCH_ACTION or "Unwatch") or (K.L.WATCH_ACTION or "Watch"),
        fn = function()
            K:SetWatched(id, not K:IsWatched(id))
            if K.API then K.API:Fire(K.API.EVENTS.WATCH_CHANGED, id, K:IsWatched(id)) end
            U:Refresh()
        end,
    }

    actions[#actions + 1] = {
        text = K:IsExcluded(id) and (K.L.UNEXCLUDE_ACTION or "Restore") or (K.L.EXCLUDE_ACTION or "Exclude"),
        fn = function()
            K:SetExcluded(id, not K:IsExcluded(id))
            if K.API then K.API:Fire(K.API.EVENTS.EXCLUDE_CHANGED, id, K:IsExcluded(id)) end
            U:Refresh()
        end,
    }

    actions[#actions + 1] = {
        text = K.L.TRACK_ACTION or "Track",
        fn = function()
            if not U.TrackWithBlizzard(id, true) then K:SetWatched(id, true) end
            U:Refresh()
        end,
    }

    actions[#actions + 1] = {
        text = K.L.TRACKER or "Send to tracker",
        fn = function() if K.Tracker then K.Tracker:SetAchievement(id, true) end end,
    }

    actions[#actions + 1] = {
        text = K.L.OPEN_ACTION or "Open achievement pane",
        fn = function() K.Criteria:Open({ type = "achievement", id = id }) end,
    }

    actions[#actions + 1] = {
        text = "Wowhead",
        fn = function() Menu:ShowURL(WOWHEAD_URL:format(id), K.Meta.AchievementName(id)) end,
    }

    -- Related achievements
    local related = K.Meta:GetRelated(id, 10)
    if #related > 0 then
        local submenu = {}
        for _, entry in ipairs(related) do
            submenu[#submenu + 1] = {
                text = ("%s |cff888888(%s)|r"):format(entry.name, entry.relation),
                fn = function() U:ShowAchievement(entry.achievementID) end,
            }
        end
        actions[#actions + 1] = { text = K.L.RELATED or "Related achievements", submenu = submenu }
    end

    -- Meta breakdown jump
    local children = K.Meta:GetChildren(id)
    if #children > 0 then
        local submenu = {}
        for index, child in ipairs(children) do
            if index > 15 then break end
            submenu[#submenu + 1] = {
                text = (child.completed and "|cff00ff00" or "|cffffffff") .. child.name .. "|r",
                fn = function() U:ShowAchievement(child.achievementID) end,
            }
        end
        actions[#actions + 1] = { text = K.L.META or "Meta steps", submenu = submenu }
    end

    if rewardTypes.TRANSMOG or rewardTypes.TABARD then
        actions[#actions + 1] = {
            text = K.L.TRANSMOG or "Transmog set",
            fn = function()
                if type(rawget(_G, "ToggleCollectionsJournal")) == "function" then
                    pcall(_G.ToggleCollectionsJournal, 5)   -- 5 = Appearances
                end
            end,
        }
    end

    if rewardTypes.PET then
        actions[#actions + 1] = {
            text = K.L.PET or "Pet journal",
            fn = function()
                if type(rawget(_G, "ToggleCollectionsJournal")) == "function" then
                    pcall(_G.ToggleCollectionsJournal, 2)   -- 2 = Pet Journal
                end
            end,
        }
    end

    if rewardTypes.MOUNT then
        actions[#actions + 1] = {
            text = K.L.MOUNT or "Mount journal",
            fn = function()
                if type(rawget(_G, "ToggleCollectionsJournal")) == "function" then
                    pcall(_G.ToggleCollectionsJournal, 1)
                end
            end,
        }
    end

    if rewardTypes.HOUSING then
        local names = U.DecorNames and U.DecorNames(id, 3) or {}
        actions[#actions + 1] = {
            text = (#names > 0) and ((K.L.HOUSING or "Housing decor") .. ": " .. table.concat(names, ", "))
                or (K.L.HOUSING or "Housing decor"),
            fn = function()
                local decorIDs = K.Rewards:GetDecorIDs(id)
                K.Criteria:Open({ type = "decor", id = decorIDs[1] })
            end,
        }
    end

    actions[#actions + 1] = {
        text = K.L.GROUP_SCAN_ACTION or "Scan group",
        fn = function()
            K.GroupScan:Scan({ id }, function(summary) K.GroupScan:AnnounceSummary(summary) end)
        end,
    }

    if panel and panel.detail and panel.detail.objectiveBox then
        actions[#actions + 1] = {
            text = K.L.OBJECTIVES or "Add objective",
            fn = function()
                U:RenderDetail(panel, id)
                panel.detail.objectiveBox:SetFocus()
            end,
        }
    end

    return actions
end

-- ----------------------------------------------------------------------------
-- Presentation
-- ----------------------------------------------------------------------------
function Menu:Show(id, panel, anchor)
    id = tonumber(id)
    if not id then return false end
    local actions = self:BuildActions(id, panel)
    if #actions == 0 then return false end

    if MenuUtil and MenuUtil.CreateContextMenu then
        local owner = anchor or panel or UIParent
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:CreateTitle(K.Meta.AchievementName(id))
            for _, action in ipairs(actions) do
                if action.submenu then
                    local submenu = rootDescription:CreateButton(action.text)
                    for _, child in ipairs(action.submenu) do
                        submenu:CreateButton(child.text, child.fn)
                    end
                else
                    rootDescription:CreateButton(action.text, action.fn)
                end
            end
        end)
        return true
    end

    return self:ShowFallback(id, actions)
end

function Menu:ShowFallback(id, actions)
    local frame = self._fallback
    if not frame then
        frame = W:Panel(UIParent, "FabledUI_KleosMenu")
        frame:SetSize(240, 100)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableMouse(true)
        frame.title = W:Label(frame, "", "GameFontNormal")
        frame.title:SetPoint("TOPLEFT", 10, -8)
        frame.buttons = {}
        frame:SetScript("OnLeave", function(self)
            if not self:IsMouseOver() then self:Hide() end
        end)
        self._fallback = frame
    end

    frame.title:SetText(K.Meta.AchievementName(id))

    local y = 28
    for index, action in ipairs(actions) do
        local button = frame.buttons[index]
        if not button then
            button = W:Button(frame, "", 220, 18)
            button:SetPoint("TOPLEFT", 10, -y)
            frame.buttons[index] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 10, -y)
        button:SetText(action.text)
        button:SetScript("OnClick", function()
            frame:Hide()
            if action.fn then action.fn() end
        end)
        button:Show()
        y = y + 20
    end
    for index = #actions + 1, #frame.buttons do frame.buttons[index]:Hide() end

    frame:SetHeight(y + 10)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:Show()
    return true
end
