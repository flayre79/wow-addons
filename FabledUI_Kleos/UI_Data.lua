local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Data
-- The data manager: filter profiles, export/import of the watch list,
-- exclusions, notes and tactics, plus compaction and a guarded reset.
--
-- Storage.lua owns the actual serialisation (KLEOS2 format); this panel is only
-- the surface. Reset asks twice because it throws away the player's curated
-- watch list, which cannot be recovered from the client.
-- ============================================================================

local ROW_HEIGHT = 18

local function MultiLineBox(parent, height)
    local container = W:Panel(parent)
    container:SetHeight(height or 120)

    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(1)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(editBox)

    container.editBox = editBox
    container.scroll = scroll

    -- The scroll child needs a real width or the text renders as one long line.
    container:SetScript("OnSizeChanged", function(self, width)
        if width and width > 40 then editBox:SetWidth(width - 40) end
    end)

    return container
end

local function Builder(uiSelf, panel)
    -- Left: profiles
    local profilePanel = W:Panel(panel)
    profilePanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    profilePanel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    profilePanel:SetWidth(260)
    panel.profilePanel = profilePanel

    panel.profileHeader = W:Label(profilePanel, K.L.PROFILES or "Filter profiles", "GameFontNormalSmall")
    panel.profileHeader:SetPoint("TOPLEFT", 8, -8)

    local profileList = W:RowList(profilePanel, { rowHeight = ROW_HEIGHT, pageSize = 40 })
    profileList:SetPoint("TOPLEFT", panel.profileHeader, "BOTTOMLEFT", 0, -6)
    profileList:SetPoint("TOPRIGHT", profilePanel, "TOPRIGHT", -6, -32)
    profileList:SetHeight(160)
    panel.profileList = profileList

    profileList:SetRenderer(function(row, name)
        if not name then return end
        row.icon:SetTexture(nil)
        local active = (K.db and K.db.activeProfile) == name
        row.name:SetText((active and "|cffffd100> " or "|cffcccccc  ") .. tostring(name) .. "|r")
        row.right:SetText("")
        row.star:SetText("")
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if K:DeleteProfile(name) then
                    U:RenderTab("DATA")
                else
                    K:Print(K.L.PROFILE_DELETE_FAILED or "The Default profile and the active profile cannot be deleted.")
                end
                return
            end
            K:SetProfile(name)
            U:RenderTab("DATA")
        end)
    end)

    panel.profileBox = CreateFrame("EditBox", nil, profilePanel, "InputBoxTemplate")
    panel.profileBox:SetSize(150, 20)
    panel.profileBox:SetPoint("TOPLEFT", profileList, "BOTTOMLEFT", 6, -8)
    panel.profileBox:SetAutoFocus(false)
    panel.profileBox:SetMaxLetters(32)

    panel.profileAdd = W:Button(profilePanel, K.L.CREATE or "Create", 80, 20, function()
        local name = (panel.profileBox:GetText() or ""):match("^%s*(.-)%s*$")
        if name == "" then return end
        if K:SetProfile(name) then
            panel.profileBox:SetText("")
            U:RenderTab("DATA")
        end
    end)
    panel.profileAdd:SetPoint("LEFT", panel.profileBox, "RIGHT", 6, 0)

    panel.storageInfo = W:Label(profilePanel, "", "GameFontHighlightSmall")
    panel.storageInfo:SetPoint("TOPLEFT", panel.profileBox, "BOTTOMLEFT", -6, -12)
    panel.storageInfo:SetPoint("RIGHT", profilePanel, "RIGHT", -8, 0)
    if panel.storageInfo.SetMaxLines then panel.storageInfo:SetMaxLines(10) end

    -- Right: export / import
    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", profilePanel, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.rightColumn = right

    panel.exportHeader = W:Label(right, K.L.EXPORT_ACTION or "Export", "GameFontNormalSmall")
    panel.exportHeader:SetPoint("TOPLEFT", 4, -6)

    local exportBox = MultiLineBox(right, 130)
    exportBox:SetPoint("TOPLEFT", panel.exportHeader, "BOTTOMLEFT", 0, -4)
    exportBox:SetPoint("RIGHT", right, "RIGHT", -4, 0)
    panel.exportBox = exportBox

    panel.exportButton = W:Button(right, K.L.EXPORT_ACTION or "Export", 110, 20, function()
        local text = K.Storage:Export()
        exportBox.editBox:SetText(text or "")
        exportBox.editBox:HighlightText()
        exportBox.editBox:SetFocus()
        K:Print((K.L.EXPORT_READY or "Export ready — press Ctrl-C to copy (%d characters)."):format(#(text or "")))
    end)
    panel.exportButton:SetPoint("TOPLEFT", exportBox, "BOTTOMLEFT", 0, -6)

    panel.importHeader = W:Label(right, K.L.IMPORT_ACTION or "Import", "GameFontNormalSmall")
    panel.importHeader:SetPoint("TOPLEFT", panel.exportButton, "BOTTOMLEFT", 0, -10)

    local importBox = MultiLineBox(right, 110)
    importBox:SetPoint("TOPLEFT", panel.importHeader, "BOTTOMLEFT", 0, -4)
    importBox:SetPoint("RIGHT", right, "RIGHT", -4, 0)
    panel.importBox = importBox

    local function DoImport(replace)
        local text = importBox.editBox:GetText() or ""
        local ok, result = K.Storage:Import(text, replace)
        if ok then
            K:Print((K.L.IMPORT_DONE or "Imported %d entries."):format(tonumber(result) or 0))
            importBox.editBox:SetText("")
            U:Refresh()
        else
            K:Print("|cffff5555" .. tostring(result) .. "|r")
        end
        U:RenderTab("DATA")
    end

    panel.importMerge = W:Button(right, K.L.IMPORT_MERGE or "Merge", 110, 20, function() DoImport(false) end)
    panel.importMerge:SetPoint("TOPLEFT", importBox, "BOTTOMLEFT", 0, -6)

    panel.importReplace = W:Button(right, K.L.IMPORT_REPLACE or "Replace", 110, 20, function() DoImport(true) end)
    panel.importReplace:SetPoint("LEFT", panel.importMerge, "RIGHT", 6, 0)

    panel.compactButton = W:Button(right, K.L.COMPACT_ACTION or "Compact", 110, 20, function()
        local removed = K.Storage:Compact()
        K:Print((K.L.COMPACT_DONE or "Removed %d dead entries."):format(removed or 0))
        U:RenderTab("DATA")
    end)
    panel.compactButton:SetPoint("LEFT", panel.importReplace, "RIGHT", 6, 0)

    -- Reset needs two clicks inside ten seconds; the watch list is not
    -- recoverable from the client once it is gone.
    panel.resetButton = W:Button(right, K.L.RESET_ACTION or "Reset", 110, 20, function()
        local now = (type(GetTime) == "function") and GetTime() or 0
        if panel._resetArmedAt and (now - panel._resetArmedAt) < 10 then
            panel._resetArmedAt = nil
            K.Storage:ResetUserData()
            K:Print(K.L.RESET_DONE or "Kleos user data reset.")
            U:Refresh()
            U:RenderTab("DATA")
        else
            panel._resetArmedAt = now
            panel.resetButton:SetText(K.L.RESET_CONFIRM or "Confirm?")
            K:Print(K.L.RESET_WARNING or "Click Reset again within 10 seconds to erase the watch list, exclusions, notes and objectives.")
            if C_Timer and C_Timer.After then
                C_Timer.After(10, function()
                    if panel.resetButton then panel.resetButton:SetText(K.L.RESET_ACTION or "Reset") end
                    panel._resetArmedAt = nil
                end)
            end
        end
    end)
    panel.resetButton:SetPoint("LEFT", panel.compactButton, "RIGHT", 6, 0)
end

local function Renderer(uiSelf, panel)
    if not panel or not panel.profileList then return end

    panel.profileList:SetItems(K:ListProfiles())

    local watched, excluded, notes, tactics, objectives, characters = 0, 0, 0, 0, 0, 0
    for _ in pairs((K.db and K.db.watchlist) or {}) do watched = watched + 1 end
    for _ in pairs((K.db and K.db.excluded) or {}) do excluded = excluded + 1 end
    for _ in pairs((K.db and K.db.notes) or {}) do notes = notes + 1 end
    for _ in pairs((K.db and K.db.tactics) or {}) do tactics = tactics + 1 end
    for _ in pairs((K.db and K.db.customObjectives) or {}) do objectives = objectives + 1 end
    for _ in pairs((K.db and K.db.characterSnapshots) or {}) do characters = characters + 1 end

    local stats = K.Catalog:Stats()
    local rewardCounts = K.Rewards:Counts()

    panel.storageInfo:SetText(table.concat({
        ("%s: |cffffd100%s|r"):format(K.L.STORAGE or "Storage", tostring(K._storageBackend or "?")),
        ("%s: %s"):format(K.L.PROFILE or "Profile", tostring((K.db and K.db.activeProfile) or "Default")),
        ("%s: %d  %s: %d"):format(K.L.WATCH or "Watched", watched, K.L.EXCLUDED or "Excluded", excluded),
        ("%s: %d  %s: %d"):format(K.L.NOTES or "Notes", notes, K.L.TACTICS_ACTION or "Tactics", tactics),
        ("%s: %d  %s: %d"):format(K.L.OBJECTIVES or "Objectives", objectives, K.L.CHARACTERS or "Characters", characters),
        ("%s: %d (%d %s, %d %s)"):format(K.L.CATALOG or "Catalog", stats.total, stats.hidden,
            K.L.HIDDEN or "hidden", stats.statistics, K.L.STATISTICS or "statistics"),
        rewardCounts and ("%s: %d"):format(K.L.REWARDS or "Rewards", rewardCounts.ANY or 0)
            or ("%s: %s"):format(K.L.REWARDS or "Rewards", K.L.INDEXING or "not indexed yet"),
    }, "\n"))
end

U.builders.DATA = Builder
U.renderers.DATA = Renderer
