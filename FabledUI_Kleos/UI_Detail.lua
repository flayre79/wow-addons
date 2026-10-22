local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Detail
-- The right-hand pane shared by every list tab: identity, reward typing,
-- progress, actions, and the step-by-step breakdown (meta children, criteria,
-- registered objectives and the player's own checklist) with deep links.
-- ============================================================================

local STEP_ROW_HEIGHT = 18

local function TrackWithBlizzard(id, enable)
    if C_ContentTracking and Enum and Enum.ContentTrackingType then
        local trackingType = Enum.ContentTrackingType.Achievement
        if enable and C_ContentTracking.StartTracking then
            local ok = pcall(C_ContentTracking.StartTracking, trackingType, id)
            if ok then return true end
        elseif not enable and C_ContentTracking.StopTracking then
            local ok = pcall(C_ContentTracking.StopTracking, trackingType, id)
            if ok then return true end
        end
    end
    -- Pre-11.x API, still present on some builds.
    local legacy = enable and rawget(_G, "AddTrackedAchievement") or rawget(_G, "RemoveTrackedAchievement")
    if type(legacy) == "function" then
        return pcall(legacy, id)
    end
    return false
end

U.TrackWithBlizzard = TrackWithBlizzard

local function IsBlizzardTracked(id)
    for _, tracked in ipairs(U.TrackedIDs and U.TrackedIDs() or {}) do
        if tracked == id then return true end
    end
    return false
end

function U:BuildDetailPane(panel, width)
    local detail = W:Panel(panel)
    detail:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -(panel._filterHeight or 60))
    detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    detail:SetWidth(width or 330)
    panel.detail = detail

    detail.icon = detail:CreateTexture(nil, "ARTWORK")
    detail.icon:SetSize(36, 36)
    detail.icon:SetPoint("TOPLEFT", 10, -10)

    detail.name = W:Label(detail, K.L.SELECT_PROMPT or "Select an achievement...", "GameFontHighlightLarge")
    detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, 0)
    detail.name:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -10, -10)
    detail.name:SetJustifyH("LEFT")
    if detail.name.SetMaxLines then detail.name:SetMaxLines(2) end

    detail.meta = W:Label(detail, "", "GameFontNormalSmall")
    detail.meta:SetPoint("TOPLEFT", detail.icon, "BOTTOMLEFT", 0, -6)
    detail.meta:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -10, 0)

    detail.description = W:Label(detail, "", "GameFontHighlightSmall")
    detail.description:SetPoint("TOPLEFT", detail.meta, "BOTTOMLEFT", 0, -6)
    detail.description:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -10, 0)
    if detail.description.SetMaxLines then detail.description:SetMaxLines(3) end

    detail.reward = W:Label(detail, "", "GameFontHighlightSmall")
    detail.reward:SetPoint("TOPLEFT", detail.description, "BOTTOMLEFT", 0, -6)
    detail.reward:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -10, 0)
    detail.reward:SetTextColor(1, 0.85, 0)
    if detail.reward.SetMaxLines then detail.reward:SetMaxLines(2) end

    detail.progress = W:ProgressBar(detail, (width or 330) - 20, 12)
    detail.progress:SetPoint("TOPLEFT", detail.reward, "BOTTOMLEFT", 0, -8)

    -- Action rows
    detail.watchButton = W:Button(detail, K.L.WATCH_ACTION or "Watch", 96, 20)
    detail.watchButton:SetPoint("TOPLEFT", detail.progress, "BOTTOMLEFT", 0, -8)

    detail.excludeButton = W:Button(detail, K.L.EXCLUDE_ACTION or "Exclude", 96, 20)
    detail.excludeButton:SetPoint("LEFT", detail.watchButton, "RIGHT", 4, 0)

    detail.trackButton = W:Button(detail, K.L.TRACK_ACTION or "Track", 96, 20)
    detail.trackButton:SetPoint("LEFT", detail.excludeButton, "RIGHT", 4, 0)

    detail.openButton = W:Button(detail, K.L.OPEN_ACTION or "Open", 96, 20)
    detail.openButton:SetPoint("TOPLEFT", detail.watchButton, "BOTTOMLEFT", 0, -4)

    detail.trackerButton = W:Button(detail, K.L.TRACKER or "Tracker", 96, 20)
    detail.trackerButton:SetPoint("LEFT", detail.openButton, "RIGHT", 4, 0)

    detail.linkButton = W:Button(detail, K.L.LINK_ACTION or "Link", 96, 20)
    detail.linkButton:SetPoint("LEFT", detail.trackerButton, "RIGHT", 4, 0)

    detail.stepsHeader = W:Label(detail, K.L.STEPS or "Steps", "GameFontNormalSmall")
    detail.stepsHeader:SetPoint("TOPLEFT", detail.openButton, "BOTTOMLEFT", 0, -8)

    detail.steps = W:RowList(detail, { rowHeight = STEP_ROW_HEIGHT, pageSize = 60, emptyText = K.L.NO_STEPS or "No criteria." })
    detail.steps:SetPoint("TOPLEFT", detail.stepsHeader, "BOTTOMLEFT", 0, -4)
    detail.steps:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -8, 30)

    detail.objectiveBox = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
    detail.objectiveBox:SetSize((width or 330) - 90, 20)
    detail.objectiveBox:SetPoint("BOTTOMLEFT", 14, 6)
    detail.objectiveBox:SetAutoFocus(false)
    detail.objectiveBox:SetMaxLetters(200)

    detail.objectiveAdd = W:Button(detail, "+", 24, 20, function()
        local id = detail._id
        local text = detail.objectiveBox:GetText() or ""
        if id and K.Objectives:Add(id, text) then
            detail.objectiveBox:SetText("")
            U:RenderDetail(panel, id)
        end
    end)
    detail.objectiveAdd:SetPoint("LEFT", detail.objectiveBox, "RIGHT", 6, 0)

    detail.steps:SetRenderer(function(row, step)
        if not step then return end
        row.icon:SetTexture(nil)

        local prefix
        if step.kind == "custom" then
            prefix = step.completed and "|cff00ff00[x]|r " or "|cffaaaaaa[ ]|r "
        elseif step.kind == "objective" then
            prefix = "|cff66ccff- |r"
        else
            prefix = step.completed and "|cff00ff00* |r" or "|cffaaaaaa* |r"
        end

        local suffix = ""
        if step.required and step.required > 1 then
            suffix = (" |cff888888(%d/%d)|r"):format(step.quantity or 0, step.required)
        elseif step.duration and step.duration > 0 then
            suffix = (" |cff888888(%ds)|r"):format(math.max(0, step.duration - (step.elapsed or 0)))
        elseif step.childProgress and step.childProgress > 0 and step.childProgress < 1 then
            suffix = (" |cff888888(%d%%)|r"):format(math.floor(step.childProgress * 100 + 0.5))
        end

        local color = step.completed and "|cff00ff00" or "|cffffffff"
        row.name:SetText(prefix .. color .. tostring(step.text or "?") .. "|r" .. suffix)
        row.right:SetText(step.link and "|cff66ccff>|r" or "")
        row.star:SetText("")

        row:SetScript("OnClick", function(_, button)
            if step.kind == "custom" then
                if button == "RightButton" then
                    K.Objectives:Remove(detail._id, step.index)
                else
                    K.Objectives:Toggle(detail._id, step.index)
                end
                U:RenderDetail(panel, detail._id)
                return
            end
            if step.link then
                if step.link.type == "achievement" and step.link.id then
                    U:ShowAchievement(step.link.id)
                else
                    K.Criteria:Open(step.link)
                end
            end
        end)
        row:SetScript("OnEnter", function(self)
            if not step.link and not step.hint then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if step.hint then GameTooltip:AddLine(step.hint, 1, 1, 1, true) end
            if step.link then
                local title, status = K.Criteria:Describe(step.link)
                GameTooltip:AddLine(title, 1, 0.82, 0)
                GameTooltip:AddLine(status, 0.9, 0.9, 0.9)
                if K.Criteria:CanOpen(step.link) then
                    GameTooltip:AddLine(K.L.CLICK_TO_OPEN or "Click to open", 0.4, 0.8, 1)
                end
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)

    return detail
end

function U:RenderDetail(panel, id)
    local detail = panel and panel.detail
    if not detail then return end

    id = tonumber(id)
    detail._id = id

    if not id then
        detail.icon:SetTexture(nil)
        detail.name:SetText(K.L.SELECT_PROMPT or "Select an achievement...")
        detail.meta:SetText("")
        detail.description:SetText("")
        detail.reward:SetText("")
        detail.progress:SetProgress(0, "")
        detail.steps:SetItems({})
        return
    end

    local entry = K.Catalog:GetEntry(id) or {}
    local state = K.Catalog:GetState(id) or {}

    detail.icon:SetTexture(entry.icon or nil)
    local points = (entry.points or 0) > 0 and (" |cff888888(%d %s)|r"):format(entry.points, K.L.POINTS or "pts") or ""
    detail.name:SetText(((entry.name and entry.name ~= "") and entry.name or ("Ach #" .. id)) .. points)

    local metaBits = {}
    if entry.categoryName then metaBits[#metaBits + 1] = entry.categoryName end
    if entry.expansion then metaBits[#metaBits + 1] = K.Data.EXPANSION_KEY_TO_FULLNAME[entry.expansion] or entry.expansion end
    if entry.kind and entry.kind ~= "OTHER" then metaBits[#metaBits + 1] = K.L[entry.kind] or entry.kind end
    if state.completed then
        local when = (state.year and state.year > 0)
            and (" — %02d/%02d/%04d"):format(state.month or 0, state.day or 0, 2000 + (state.year or 0))
            or ""
        metaBits[#metaBits + 1] = "|cff00ff00" .. (K.L.COMPLETE or "Complete") .. when .. "|r"
        if not state.wasEarnedByMe then
            metaBits[#metaBits + 1] = "|cff88cc88" .. (K.L.ACCOUNT or "Account") .. "|r"
        end
    end
    if entry.hidden then metaBits[#metaBits + 1] = "|cff9999ff" .. (K.L.HIDDEN or "Hidden") .. "|r" end
    if K.Catalog:IsUnobtainable(id) then metaBits[#metaBits + 1] = "|cffff5555" .. (K.L.UNOBTAINABLE or "Unobtainable") .. "|r" end
    detail.meta:SetText(table.concat(metaBits, " • "))

    detail.description:SetText(entry.description or "")

    local rewardBits = {}
    local rewardDescription = K.Rewards:Describe(id)
    if rewardDescription then rewardBits[#rewardBits + 1] = rewardDescription end
    if entry.rewardText and entry.rewardText ~= "" then rewardBits[#rewardBits + 1] = entry.rewardText end
    local decorIDs = K.Rewards:GetDecorIDs(id)
    if #decorIDs > 0 then
        rewardBits[#rewardBits + 1] = ("%s: %d"):format(K.L.HOUSING or "Housing Decor", #decorIDs)
    end
    detail.reward:SetText(#rewardBits > 0 and (((K.L.REWARD or "Reward") .. ": ") .. table.concat(rewardBits, " — ")) or "")

    local progress, done, total = K.Catalog:GetProgress(id)
    local progressLabel
    if state.completed then
        progressLabel = K.L.COMPLETE or "Complete"
    elseif total and total > 0 then
        progressLabel = ("%d/%d"):format(done or 0, total)
    else
        progressLabel = ("%d%%"):format(math.floor(progress * 100 + 0.5))
    end
    detail.progress:SetProgress(progress, progressLabel)

    -- Actions
    detail.watchButton:SetText(K:IsWatched(id) and (K.L.UNWATCH_ACTION or "Unwatch") or (K.L.WATCH_ACTION or "Watch"))
    detail.watchButton:SetScript("OnClick", function()
        K:SetWatched(id, not K:IsWatched(id))
        if K.API then K.API:Fire(K.API.EVENTS.WATCH_CHANGED, id, K:IsWatched(id)) end
        U:RenderTab(panel._tabKey)
        U:RenderDetail(panel, id)
    end)

    detail.excludeButton:SetText(K:IsExcluded(id) and (K.L.UNEXCLUDE_ACTION or "Restore") or (K.L.EXCLUDE_ACTION or "Exclude"))
    detail.excludeButton:SetScript("OnClick", function()
        K:SetExcluded(id, not K:IsExcluded(id))
        if K.API then K.API:Fire(K.API.EVENTS.EXCLUDE_CHANGED, id, K:IsExcluded(id)) end
        U:RenderTab(panel._tabKey)
        U:RenderDetail(panel, id)
    end)

    local blizzardTracked = IsBlizzardTracked(id)
    detail.trackButton:SetText(blizzardTracked and (K.L.UNTRACK_ACTION or "Untrack") or (K.L.TRACK_ACTION or "Track"))
    detail.trackButton:SetScript("OnClick", function()
        if not TrackWithBlizzard(id, not blizzardTracked) then
            K:Print(K.L.TRACK_UNAVAILABLE or "This client does not expose achievement tracking; using the Kleos watch list instead.")
            K:SetWatched(id, true)
        end
        U:RenderDetail(panel, id)
    end)

    detail.openButton:SetScript("OnClick", function()
        K.Criteria:Open({ type = "achievement", id = id })
    end)

    detail.trackerButton:SetScript("OnClick", function()
        if K.Tracker then K.Tracker:SetAchievement(id, true) end
    end)

    -- Linking an achievement into chat is an explicit user action, so it uses
    -- the chat edit box rather than sending anything itself.
    detail.linkButton:SetScript("OnClick", function()
        local link = (type(GetAchievementLink) == "function") and GetAchievementLink(id) or nil
        if not link then
            K:Print(K.L.NO_LINK or "This client did not return a link for that achievement.")
            return
        end
        local getActiveWindow = rawget(_G, "ChatEdit_GetActiveWindow")
        local editBox = type(getActiveWindow) == "function" and getActiveWindow() or nil
        if not editBox and type(rawget(_G, "ChatFrame_OpenChat")) == "function" then
            _G.ChatFrame_OpenChat(link)
            return
        end
        if editBox and editBox.Insert then editBox:Insert(link) end
    end)

    -- Steps: breakdown first, then objectives.
    local steps = K.Meta:Breakdown(id)
    for _, objective in ipairs(K.Objectives:Steps(id)) do steps[#steps + 1] = objective end
    detail.steps:SetItems(steps)

    local summary = K.Meta:CompletionSummary(id)
    detail.stepsHeader:SetText(("%s (%d/%d)%s"):format(
        K.L.STEPS or "Steps", summary.completed, summary.steps,
        summary.isMeta and ("  |cff66ccff" .. (K.L.META or "Meta") .. "|r") or ""))
end
