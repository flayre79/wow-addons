local P = _G.FabledUI_Poseidon
if not P then return end

local UI = P.UI

local function BeginPage(content, width)
    UI:WipeChildren(content)
    content._nextY = -4
    content:SetHeight(1)
    return math.max(540, width or 760)
end

local function AddPanel(content, width, title, icon, height, alt)
    local panel = UI:TrackChild(content, UI:CreatePanel(content, title, icon, alt))
    panel:SetPoint("TOPLEFT", 10, content._nextY)
    panel:SetSize(width - 20, height)
    content._nextY = content._nextY - height - 12
    return panel
end

local function FinishPage(content)
    content:SetHeight(math.abs(content._nextY) + 24)
end

local function AddListLines(panel, items, startY, lineCount, formatter)
    local y = startY
    if type(items) ~= "table" or #items == 0 then
        UI:AddWrappedText(panel, "Nothing recorded yet.", 12, y, panel:GetWidth() - 24, "GameFontNormalSmall", UI.Colors.subtext)
        return
    end
    local limit = math.min(#items, lineCount or #items)
    for index = 1, limit do
        local lineText = formatter(items[index], index)
        UI:AddWrappedText(panel, lineText, 12, y, panel:GetWidth() - 24, "GameFontHighlightSmall", UI.Colors.text)
        y = y - 18
    end
end

function UI:RenderOverviewPage(content, width)
    width = BeginPage(content, width)
    local overview = P.Stats:GetOverviewData()
    local session = overview.session or {}
    local zone = overview.zone or {}
    local zoneInfo = overview.zoneInfo or {}
    local nodeCount, fishLinks = P.Nodes:GetNodeTotals()

    local panel = AddPanel(content, width, "Current Session", "Interface/Icons/Trade_Fishing", 122)
    UI:AddLabelValue(panel, "Zone", zoneInfo.mapName or "Unknown", 12, -34, width - 44)
    UI:AddLabelValue(panel, "Sub-zone", (zoneInfo.subZone and zoneInfo.subZone ~= "" and zoneInfo.subZone) or "None", 12, -50, width - 44)
    UI:AddLabelValue(panel, "Current Pool", session.lastPool or "Open Water", 12, -66, width - 44)
    UI:AddLabelValue(panel, "Casts", tostring(session.casts or 0), 12, -82, width - 44)
    UI:AddLabelValue(panel, "Catches", tostring(session.catches or 0), 12, -98, width - 44)
    UI:AddLabelValue(panel, "Success / Hour", string.format("%.0f%%  •  %.1f fish/hr", P.Stats:GetSuccessRate(session), P.Stats:GetFishPerHour(session)), 12, -114, width - 44)

    panel = AddPanel(content, width, "Zone Snapshot", "Interface/Icons/INV_Misc_Map_01", 104, true)
    UI:AddLabelValue(panel, "Zone Casts", tostring(zone.casts or 0), 12, -34, width - 44)
    UI:AddLabelValue(panel, "Zone Catches", tostring(zone.catches or 0), 12, -50, width - 44)
    UI:AddLabelValue(panel, "Known Pools", tostring(#P.Stats:GetTopEntries(zone.pools or {}, 999)), 12, -66, width - 44)
    UI:AddLabelValue(panel, "Unique Fish", tostring(#P.Stats:GetTopEntries(zone.fish or {}, 999)), 12, -82, width - 44)

    panel = AddPanel(content, width, "Lifetime Totals", "Interface/Icons/Achievement_BG_returnXflags_def_wsg", 104)
    UI:AddLabelValue(panel, "Lifetime Casts", tostring(overview.lifetime.casts or 0), 12, -34, width - 44)
    UI:AddLabelValue(panel, "Lifetime Catches", tostring(overview.lifetime.catches or 0), 12, -50, width - 44)
    UI:AddLabelValue(panel, "Tracked Nodes", tostring(nodeCount), 12, -66, width - 44)
    UI:AddLabelValue(panel, "Learned Links", tostring(fishLinks), 12, -82, width - 44)

    panel = AddPanel(content, width, "Tournament Watch", "Interface/Icons/Achievement_BG_killflagcarriers_grabflagcapit", 90, true)
    local derbyText = "No tournament buff detected right now."
    if P.settings.showDerbyTracker and P.Derby and P.Derby.IsActive and P.Derby:IsActive() then
        derbyText = "Tournament active right now. Poseidon will include derby catches in the active session view."
    end
    UI:AddWrappedText(panel, derbyText, 12, -36, width - 44, "GameFontHighlight", UI.Colors.text)

    panel = AddPanel(content, width, "Recent Catches", "Interface/Icons/Achievement_General_StayClassy", 124)
    AddListLines(panel, P.State.recentCatches or {}, -34, 5, function(entry)
        return UI:Truncate(string.format("%s  •  %s", entry.itemName or "Unknown", entry.poolName or "Open Water"), 96)
    end)

    if self.full and self.full.SetShellStatus then
        self.full:SetShellStatus(string.format("%d casts / %d catches this session", session.casts or 0, session.catches or 0))
    end

    FinishPage(content)
end

function UI:RenderZonesPage(content, width)
    width = BeginPage(content, width)
    local zones = P.Stats:GetZoneCards()

    if #zones == 0 and P.Data and P.Data.Midnight and type(P.Data.Midnight.zones) == "table" then
        for zoneName, zoneInfo in pairs(P.Data.Midnight.zones) do
            local panel = AddPanel(content, width, zoneName, "Interface/Icons/INV_Misc_Map_01", 112)
            UI:AddWrappedText(panel, "Recommended skill: " .. tostring(zoneInfo.recommended or "Any"), 12, -36, width - 44, "GameFontHighlight", UI.Colors.text)
            UI:AddWrappedText(panel, "Pools: " .. UI:JoinList(zoneInfo.pools or {}, 4, 120), 12, -56, width - 44, "GameFontNormalSmall", UI.Colors.subtext)
            UI:AddWrappedText(panel, "Notes: " .. UI:JoinList(zoneInfo.notes or {}, 2, 120), 12, -76, width - 44, "GameFontNormalSmall", UI.Colors.subtext)
        end
    else
        for _, zone in ipairs(zones) do
            local hasSubZone = type(zone.subZone) == "string" and zone.subZone ~= ""
            local headerLabel = hasSubZone and zone.subZone or zone.name or zone.mapName or "Unknown Zone"
            local panel = AddPanel(content, width, headerLabel, "Interface/Icons/INV_Misc_Map_01", 112)
            UI:AddLabelValue(panel, "Tracked Casts", tostring(zone.casts or 0), 12, -34, width - 44)
            UI:AddLabelValue(panel, "Tracked Catches", tostring(zone.catches or 0), 12, -50, width - 44)
            UI:AddLabelValue(panel, "Known Pools", tostring(#P.Stats:GetTopEntries(zone.pools or {}, 999)), 12, -66, width - 44)
            UI:AddLabelValue(panel, "Unique Fish", tostring(#P.Stats:GetTopEntries(zone.fish or {}, 999)), 12, -82, width - 44)
            local parentLabel = zone.mapName
            if hasSubZone and parentLabel and parentLabel ~= "" and parentLabel ~= zone.subZone then
                UI:AddWrappedText(panel, parentLabel, 12, -98, width - 44, "GameFontNormalSmall", UI.Colors.subtext)
            end
        end
    end

    if self.full and self.full.SetShellStatus then
        self.full:SetShellStatus(string.format("%d tracked zones", #zones))
    end

    FinishPage(content)
end

-- P1/P2: Filter helpers used by the catalog page. Each call resolves the
-- fish's itemID via Core.GetFishItemID and applies the live filter
-- toggles. Filters fail open (entry passes) when data is missing so an
-- empty RareFishIDs table never accidentally hides every fish.
local function ApplyFishFilters(entries)
    if type(entries) ~= "table" then return {} end
    local rareOnly = P.settings and P.settings.fishRareOnly == true
    local hideJunk = P.settings and P.settings.fishHideJunk == true
    if not rareOnly and not hideJunk then
        return entries
    end

    local hasRareData = next(P.RareFishIDs) ~= nil
    local out = {}
    for _, entry in ipairs(entries) do
        local include = true
        local itemID = P:GetFishItemID(entry.name)

        if rareOnly then
            -- If we have no data yet, keep the original list visible so the
            -- catalog isn't blanked out. Once data lands, the filter starts
            -- working immediately.
            if hasRareData and not P:IsRareFish(entry.name, itemID) then
                include = false
            end
        end

        if include and hideJunk and itemID and P:IsJunkFish(entry.name, itemID) then
            include = false
        end

        if include then
            out[#out + 1] = entry
        end
    end
    return out
end

local function CreateFilterPanel(content, width)
    -- Adds a compact filter strip with the rare-only and hide-junk toggles
    -- above the fish catalog. Keeps both filters visible regardless of
    -- whether rare data has loaded yet (the rare check fails open).
    local panel = AddPanel(content, width, "Filters", "Interface/Buttons/UI-CheckBox-Up", 60, true)

    local rare = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    rare:SetPoint("TOPLEFT", 12, -28)
    rare.text:SetText("Rare only")
    rare:SetChecked(P.settings.fishRareOnly == true)
    rare:SetScript("OnClick", function(self)
        P.settings.fishRareOnly = self:GetChecked() and true or false
        P:MarkDirty()
        UI:RefreshFull()
    end)

    local junk = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    junk:SetPoint("LEFT", rare, "RIGHT", 110, 0)
    junk.text:SetText("Hide junk (grey)")
    junk:SetChecked(P.settings.fishHideJunk == true)
    junk:SetScript("OnClick", function(self)
        P.settings.fishHideJunk = self:GetChecked() and true or false
        P:MarkDirty()
        UI:RefreshFull()
    end)

    return panel
end

function UI:RenderFishPage(content, width)
    width = BeginPage(content, width)

    -- P1/P2: filter strip first, then the (filtered) catalog.
    CreateFilterPanel(content, width)

    local fishCards = P.Stats:GetFishCards()
    local filtered = ApplyFishFilters(fishCards)

    if #filtered == 0 then
        local panel = AddPanel(content, width, "Fish Catalog", "Interface/Icons/Trade_Fishing", 84)
        local message
        if #fishCards == 0 then
            message = "No fish recorded yet. Catch a few fish and Poseidon will build out your personal catalog here."
        else
            message = "No fish match the current filters. Toggle 'Rare only' or 'Hide junk' to see more."
        end
        UI:AddWrappedText(panel, message, 12, -36, width - 44, "GameFontHighlight", UI.Colors.text)
    else
        for _, entry in ipairs(filtered) do
            local panel = AddPanel(content, width, entry.name, UI:GetFishIcon(entry.name), 72, true)
            UI:AddLabelValue(panel, "Lifetime Catches", tostring(entry.count or 0), 12, -34, width - 44)
            local meta = _G.FishIntel_FishMeta and _G.FishIntel_FishMeta[entry.name] or nil
            local classification = meta and meta.quality or "Known Catch"
            local itemID = P:GetFishItemID(entry.name)
            if itemID and P:IsRareFish(entry.name, itemID) then
                classification = classification .. "  |cffa335ee[Rare]|r"
            end
            UI:AddLabelValue(panel, "Classification", classification, 12, -50, width - 44)
        end
    end

    if self.full and self.full.SetShellStatus then
        self.full:SetShellStatus(string.format("%d unique fish (%d after filters)", #fishCards, #filtered))
    end

    FinishPage(content)
end

function UI:RenderNodesPage(content, width)
    width = BeginPage(content, width)
    local selectedMapID = self.state.selectedNodeMapID
    local selectedCoordKey = self.state.selectedNodeCoordKey
    local selectedNode = selectedMapID and selectedCoordKey and P.Nodes:GetNode(selectedMapID, selectedCoordKey) or nil
    local allNodes = P.Nodes:IterateNodes(nil)

    if not selectedNode and #allNodes > 0 then
        selectedNode = allNodes[1]
        self.state.selectedNodeMapID = selectedNode.mapID
        self.state.selectedNodeCoordKey = selectedNode.coordKey
    end

    local panel = AddPanel(content, width, "Selected Node", "Interface/Icons/Ability_Hunter_AspectoftheFox", 172)
    if selectedNode then
        UI:AddLabelValue(panel, "Pool", selectedNode.name or "Fishing Pool", 12, -34, width - 44)
        UI:AddLabelValue(panel, "Map", selectedNode.mapName or ("Map " .. tostring(selectedNode.mapID or 0)), 12, -50, width - 44)
        UI:AddLabelValue(panel, "Location", string.format("%.1f, %.1f", (selectedNode.x or 0) * 100, (selectedNode.y or 0) * 100), 12, -66, width - 44)
        UI:AddLabelValue(panel, "Seen / Catches", string.format("%d / %d", selectedNode.seenCount or 0, selectedNode.catchCount or 0), 12, -82, width - 44)
        UI:AddLabelValue(panel, "Last Seen", UI:FormatRelativeTime(selectedNode.lastSeen), 12, -98, width - 44)
        UI:AddWrappedText(panel, "Learned: " .. UI:JoinList(P.Nodes:GetPoolStats(selectedNode.name, selectedNode.mapID).learned or {}, 4, 110), 12, -116, width - 44, "GameFontNormalSmall", UI.Colors.subtext)

        local noteBox = UI:TrackChild(panel, CreateFrame("EditBox", nil, panel, "InputBoxTemplate"))
        noteBox:SetPoint("TOPLEFT", 12, -136)
        noteBox:SetSize(width - 156, 24)
        noteBox:SetAutoFocus(false)
        noteBox:SetText(selectedNode.note or "")
        noteBox:SetScript("OnEscapePressed", noteBox.ClearFocus)

        local save = UI:TrackChild(panel, UI:CreateActionButton(panel, "Save Note", 96, 24))
        save:SetPoint("LEFT", noteBox, "RIGHT", 8, 0)
        save:SetScript("OnClick", function()
            P.Nodes:SetNodeNote(selectedNode.mapID, selectedNode.coordKey, noteBox:GetText())
        end)
    else
        UI:AddWrappedText(panel, "No nodes tracked yet. Cast into a few pools and the node browser will have something to chew on.", 12, -36, width - 44, "GameFontHighlight", UI.Colors.text)
    end

    panel = AddPanel(content, width, "Recent Nodes", "Interface/Icons/INV_Misc_Map_01", math.max(96, 40 + (math.min(#allNodes, 8) * 34)), true)
    if #allNodes == 0 then
        UI:AddWrappedText(panel, "No nodes recorded yet.", 12, -34, width - 44, "GameFontNormalSmall", UI.Colors.subtext)
    else
        local y = -34
        for index = 1, math.min(#allNodes, 8) do
            local node = allNodes[index]
            local row = UI:TrackChild(panel, CreateFrame("Button", nil, panel, "BackdropTemplate"))
            UI:ApplyPanelBackdrop(row, index % 2 == 0)
            row:SetPoint("TOPLEFT", 12, y)
            row:SetSize(width - 44, 28)
            row:SetScript("OnClick", function()
                UI.state.selectedNodeMapID = node.mapID
                UI.state.selectedNodeCoordKey = node.coordKey
                UI:RefreshFull()
            end)
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 8, 0)
            text:SetPoint("RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetText(UI:Truncate(string.format("%s  •  %s  •  %.1f, %.1f", node.name or "Pool", node.mapName or "Map", (node.x or 0) * 100, (node.y or 0) * 100), 110))
            y = y - 34
        end
    end

    if self.full and self.full.SetShellStatus then
        self.full:SetShellStatus(string.format("%d tracked nodes", #allNodes))
    end

    FinishPage(content)
end

function UI:RenderSharingPage(content, width)
    width = BeginPage(content, width)
    local panel = AddPanel(content, width, "Import / Export", "Interface/Icons/INV_Scroll_06", 104)
    UI:AddWrappedText(panel, "Back up or share your tracked nodes without touching slash-command nonsense.", 12, -36, width - 44, "GameFontHighlight", UI.Colors.text)

    local export = UI:TrackChild(panel, UI:CreateActionButton(panel, "Export Nodes", 110, 24))
    export:SetPoint("TOPLEFT", 12, -72)
    export:SetScript("OnClick", function()
        P.ImportExport:OpenExportWindow()
    end)

    local import = UI:TrackChild(panel, UI:CreateActionButton(panel, "Import Nodes", 110, 24))
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    import:SetScript("OnClick", function()
        P.ImportExport:OpenImportWindow()
    end)

    local meta = P.db.meta or {}
    panel = AddPanel(content, width, "Storage", "Interface/Icons/INV_Misc_Book_09", 96, true)
    UI:AddLabelValue(panel, "Backend", tostring(P._storageBackend or "Unknown"), 12, -34, width - 44)
    UI:AddLabelValue(panel, "Last Import", meta.lastImportAt and date("%Y-%m-%d %H:%M", meta.lastImportAt) or "Never", 12, -50, width - 44)
    UI:AddLabelValue(panel, "Last Export", meta.lastExportAt and date("%Y-%m-%d %H:%M", meta.lastExportAt) or "Never", 12, -66, width - 44)

    if self.full and self.full.SetShellStatus then
        self.full:SetShellStatus("Import / export ready")
    end

    FinishPage(content)
end
