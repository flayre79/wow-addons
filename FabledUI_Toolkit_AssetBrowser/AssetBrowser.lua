local addonName, ns = ...

local AssetBrowser = {}
ns.AssetBrowser = AssetBrowser

local ROWS = 16
local ROW_HEIGHT = 32
local TAB_ATLAS = "atlas"
local TAB_ICON = "icon"
local ICON_SCAN_BATCH = 500
local ICON_SCAN_INTERVAL = 0.02

local function Round(value)
    return math.floor(value + 0.5)
end

local function Trim(text)
    return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Lower(text)
    return string.lower(text or "")
end

local function FormatNumber(value)
    return BreakUpLargeNumbers(tonumber(value) or 0)
end

local function SetButtonSelected(button, selected)
    if selected then
        button:LockHighlight()
        button:GetFontString():SetTextColor(1.0, 0.82, 0.2)
    else
        button:UnlockHighlight()
        button:GetFontString():SetTextColor(1, 1, 1)
    end
end

local function SortAscending(a, b)
    return a < b
end

local function StyleToolkitButton(button)
    if not button then
        return
    end

    if button.SetNormalTexture then
        button:SetNormalTexture(nil)
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture(nil)
    end
    if button.SetPushedTexture then
        button:SetPushedTexture(nil)
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture(nil)
    end

    if ns.Toolkit and ns.Toolkit.Themes and type(ns.Toolkit.Themes.StyleFlatButton) == "function" then
        ns.Toolkit.Themes:StyleFlatButton(button, "Dark", { 0.320, 0.635, 1.000, 1.0 })
    end
end

local function CreateTabButton(parent, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetText(text)
    StyleToolkitButton(button)
    return button
end

local function SetTextureOrAtlas(texture, record)
    texture:SetTexCoord(0, 1, 0, 1)
    if not record then
        texture:SetTexture(nil)
        return
    end

    if record.kind == TAB_ATLAS then
        texture:SetAtlas(record.atlas)
    else
        texture:SetTexture(record.fileID)
    end
end

local function NormalizeAtlasParentKey(parentKey)
    local numeric = tonumber(parentKey)
    if numeric then
        return numeric, tostring(numeric)
    end
    return tostring(parentKey), tostring(parentKey)
end

local function BuildAtlasPath(parentKey)
    local numeric = tonumber(parentKey)
    if numeric then
        local fromAPI = C_Texture.GetFilenameFromFileDataID(numeric)
        return fromAPI or ("FileData ID " .. tostring(numeric))
    end
    return tostring(parentKey)
end

function AssetBrowser:GetDB()
    return ns:GetDB()
end

function AssetBrowser:EnsureIconSources()
    if self.iconSourcesBuilt then
        return
    end

    self.iconSourcesBuilt = true
    self.iconRecords = {}
    self.iconIndex = {}

    local function addIcon(fileID, source, label)
        fileID = tonumber(fileID)
        if not fileID or fileID <= 0 then
            return
        end

        local record = self.iconIndex[fileID]
        if not record then
            record = {
                kind = TAB_ICON,
                fileID = fileID,
                filename = BuildAtlasPath(fileID),
                search = Lower(tostring(fileID) .. " " .. BuildAtlasPath(fileID)),
                labels = {},
                sourceText = "",
            }
            self.iconIndex[fileID] = record
            table.insert(self.iconRecords, record)
        end

        if source and not record.labels[source] then
            record.labels[source] = true
            if label then
                record.sourceText = record.sourceText == "" and label or (record.sourceText .. ", " .. label)
                record.search = record.search .. " " .. Lower(label)
            end
        end
    end

    local queryList = {}
    local function addFromQuery(func, label, source)
        if type(func) ~= "function" then
            return
        end
        table.wipe(queryList)
        func(queryList)
        for _, fileID in ipairs(queryList) do
            addIcon(fileID, source, label)
        end
    end

    addFromQuery(GetMacroIcons, "Macro Icons", "macro")
    addFromQuery(GetMacroItemIcons, "Macro Item Icons", "macroitem")

    for parentKey in pairs(ns.AtlasData or {}) do
        local numeric = tonumber(parentKey)
        if numeric then
            addIcon(numeric, "atlasparent", "Atlas Parent")
        end
    end

    local db = self:GetDB()
    for fileID, cacheRecord in pairs(db.iconCache or {}) do
        addIcon(fileID, cacheRecord.source or "cache", cacheRecord.label or "Cached")
    end
end

function AssetBrowser:PersistIconCacheRecord(fileID, source, label)
    local db = self:GetDB()
    db.iconCache[fileID] = db.iconCache[fileID] or {
        source = source,
        label = label,
    }
end

function AssetBrowser:StartSpellIconScan()
    if self.scanTicker then
        return
    end

    if self.frame and self.frame.utilityButton then
        self.frame.utilityButton:SetText("Scanning…")
    end

    self:EnsureIconSources()

    local db = self:GetDB()
    db.scan = db.scan or {
        maxSpellID = 250000,
        nextSpellID = 1,
        complete = false,
    }

    db.scan.complete = false

    self.scanTicker = C_Timer.NewTicker(ICON_SCAN_INTERVAL, function()
        local foundAny = false
        local startID = db.scan.nextSpellID
        local endID = math.min(startID + ICON_SCAN_BATCH - 1, db.scan.maxSpellID)

        for spellID = startID, endID do
            local fileID = C_Spell.GetSpellTexture(spellID)
            if fileID then
                foundAny = true
                self:PersistIconCacheRecord(fileID, "spell", "Spell Icon")
                local existing = self.iconIndex[fileID]
                if existing then
                    if not existing.labels.spell then
                        existing.labels.spell = true
                        existing.sourceText = existing.sourceText == "" and "Spell Icon" or (existing.sourceText .. ", Spell Icon")
                        existing.search = existing.search .. " spell icon"
                    end
                else
                    self.iconSourcesBuilt = false
                end
            end
        end

        db.scan.nextSpellID = endID + 1
        if db.scan.nextSpellID > db.scan.maxSpellID then
            db.scan.complete = true
            self.scanTicker:Cancel()
            self.scanTicker = nil
            self.iconSourcesBuilt = false
            self:RefreshIconData()
            if self.frame and self.frame.utilityButton then
                self.frame.utilityButton:SetText("Start Spell Icon Scan")
            end
            ns:Notify("Spell icon scan complete. Your tiny goblin now knows more file IDs.")
            return
        end

        if foundAny then
            self.iconSourcesBuilt = false
            self:RefreshIconData()
        elseif self.frame and self.frame:IsShown() and self.state.activeTab == TAB_ICON then
            self:UpdateFooterStatus(string.format("Scanning spell icons: %s / %s", FormatNumber(endID), FormatNumber(db.scan.maxSpellID)))
        end
    end)
end

function AssetBrowser:StopSpellIconScan()
    if self.scanTicker then
        self.scanTicker:Cancel()
        self.scanTicker = nil
    end
    if self.frame and self.frame.utilityButton then
        self.frame.utilityButton:SetText("Start Spell Icon Scan")
    end
end

function AssetBrowser:BuildAtlasData()
    if self.atlasRecords then
        return
    end

    self.atlasRecords = {}
    self.atlasIndex = {}
    self.parentAtlasIndex = {}

    for parentKey, atlasMap in pairs(ns.AtlasData or {}) do
        local parentKeyNormalized, parentDisplay = NormalizeAtlasParentKey(parentKey)
        self.parentAtlasIndex[parentKeyNormalized] = self.parentAtlasIndex[parentKeyNormalized] or {}

        for atlasName, info in pairs(atlasMap) do
            local path = BuildAtlasPath(parentKey)
            local record = {
                kind = TAB_ATLAS,
                atlas = atlasName,
                parentFileID = parentKeyNormalized,
                parentDisplay = parentDisplay,
                parentPath = path,
                width = info[1],
                height = info[2],
                leftTexCoord = info[3],
                rightTexCoord = info[4],
                topTexCoord = info[5],
                bottomTexCoord = info[6],
                tilesHorizontally = info[7],
                tilesVertically = info[8],
            }

            local apiInfo = C_Texture.GetAtlasInfo(atlasName)
            record.existsInAPI = apiInfo ~= nil
            record.search = Lower(string.format("%s %s %s", atlasName, path, parentDisplay))

            self.atlasIndex[atlasName] = record
            table.insert(self.atlasRecords, record)
            table.insert(self.parentAtlasIndex[parentKeyNormalized], record)
        end
    end
end

function AssetBrowser:GetOrCreateFrame()
    if self.frame then
        return self.frame
    end

    self.state = self.state or {
        activeTab = self:GetDB().activeTab or TAB_ATLAS,
        atlasSearch = self:GetDB().atlasSearch or "",
        iconSearch = self:GetDB().iconSearch or "",
        atlasSort = self:GetDB().atlasSort or "name",
        iconSort = self:GetDB().iconSort or "id",
        atlasOffset = 0,
        iconOffset = 0,
        selectedAtlas = nil,
        selectedIcon = nil,
        filteredAtlases = {},
        filteredIcons = {},
    }

    local db = self:GetDB()
    local frame

    if ns.Toolkit and ns.Toolkit.Shell and type(ns.Toolkit.Shell.CreateWindow) == "function" then
        frame = ns.Toolkit.Shell:CreateWindow(ns.FRAME_NAME, {
            title = "FabledUI Toolkit — Asset Browser",
            subtitle = "Retail-only suite dev tool for atlases, textures, and icon file data.",
            theme = "Dark",
            accentColor = { 0.320, 0.635, 1.000, 1.0 },
            width = db.window.width,
            height = db.window.height,
            minWidth = 1020,
            minHeight = 650,
            maxWidth = 1800,
            maxHeight = 1200,
            state = db.window,
            ribbonLabel = "Asset Browser",
            ribbonIcon = 134400,
            onSizeChanged = function(_, width, height)
                self:ApplyResponsiveLayout(width, height)
                self:RefreshVisibleRows()
            end,
            onHide = function()
                self:SaveWindowBounds()
            end,
        })
        frame:EnableMouseWheel(true)
    else
        frame = CreateFrame("Frame", ns.FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetResizable(true)
        if frame.SetResizeBounds then
            frame:SetResizeBounds(1020, 650, 1800, 1200)
        else
            if frame.SetMinResize then
                frame:SetMinResize(1020, 650)
            end
            if frame.SetMaxResize then
                frame:SetMaxResize(1800, 1200)
            end
        end
        frame:SetScript("OnDragStart", function(f)
            if not InCombatLockdown() then
                f:StartMoving()
            end
        end)
        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            self:SaveWindowBounds()
        end)
        frame:SetScript("OnSizeChanged", function(_, width, height)
            self:ApplyResponsiveLayout(width, height)
            self:RefreshVisibleRows()
        end)
        frame:SetPoint(db.window.point, UIParent, db.window.relativePoint, db.window.x, db.window.y)
        frame:SetSize(db.window.width, db.window.height)
        frame:EnableMouseWheel(true)
        frame:Hide()
        frame.TitleText:SetText("FabledUI Toolkit — Asset Browser")
        ns:ApplyToolkitTheme(frame, "Dark")

        local resize = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
        resize:SetPoint("BOTTOMRIGHT", -6, 6)
        frame.resizeButton = resize
    end

    local subtitle = frame.SubtitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if not frame.SubtitleText then
        subtitle:SetPoint("TOPLEFT", 16, -34)
    end
    subtitle:SetText("Retail-only suite dev tool for atlases, textures, and icon file data.")
    frame.subtitle = subtitle

    local atlasTab = CreateTabButton(frame, "Atlases")
    atlasTab:SetPoint("TOPLEFT", 16, -56)
    atlasTab:SetScript("OnClick", function() self:SetActiveTab(TAB_ATLAS) end)

    local iconTab = CreateTabButton(frame, "Icons")
    iconTab:SetPoint("LEFT", atlasTab, "RIGHT", 8, 0)
    iconTab:SetScript("OnClick", function() self:SetActiveTab(TAB_ICON) end)

    frame.tabs = {
        [TAB_ATLAS] = atlasTab,
        [TAB_ICON] = iconTab,
    }

    local searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchBox:SetPoint("TOPLEFT", 16, -90)
    searchBox:SetSize(280, 24)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(editBox, userInput)
        SearchBoxTemplate_OnTextChanged(editBox)
        if userInput then
            self:OnSearchChanged(editBox:GetText())
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
    end)
    frame.searchBox = searchBox

    local sortLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    sortLabel:SetText("Sort")

    local sortDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", 8, 0)
    sortDropdown:SetWidth(160)
    frame.sortDropdown = sortDropdown

    local utilityButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    utilityButton:SetSize(180, 24)
    utilityButton:SetPoint("LEFT", sortDropdown, "RIGHT", 16, 0)
    utilityButton:SetText("Start Spell Icon Scan")
    utilityButton:SetScript("OnClick", function() self:StartSpellIconScan() end)
    StyleToolkitButton(utilityButton)
    frame.utilityButton = utilityButton

    local utilityButton2 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    utilityButton2:SetSize(120, 24)
    utilityButton2:SetPoint("LEFT", utilityButton, "RIGHT", 8, 0)
    utilityButton2:SetText("Copy Name")
    utilityButton2:SetScript("OnClick", function() self:CopyCurrentSelectionPrimary() end)
    StyleToolkitButton(utilityButton2)
    frame.copyPrimaryButton = utilityButton2

    local utilityButton3 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    utilityButton3:SetSize(120, 24)
    utilityButton3:SetPoint("LEFT", utilityButton2, "RIGHT", 8, 0)
    utilityButton3:SetText("Copy Snippet")
    utilityButton3:SetScript("OnClick", function() self:CopyCurrentSelectionSnippet() end)
    StyleToolkitButton(utilityButton3)
    frame.copySnippetButton = utilityButton3

    local listPane = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    listPane:SetPoint("TOPLEFT", 16, -124)
    listPane:SetPoint("BOTTOMLEFT", 16, 36)
    listPane:SetWidth(420)
    frame.listPane = listPane

    local listTitle = listPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 12, -12)
    listTitle:SetText("Results")
    frame.listTitle = listTitle

    local scrollUp = CreateFrame("Button", nil, listPane, "UIPanelScrollUpButtonTemplate")
    scrollUp:SetPoint("TOPRIGHT", -28, -8)
    scrollUp:SetScript("OnClick", function() self:ScrollBy(-1) end)

    local scrollDown = CreateFrame("Button", nil, listPane, "UIPanelScrollDownButtonTemplate")
    scrollDown:SetPoint("BOTTOMRIGHT", -28, 8)
    scrollDown:SetScript("OnClick", function() self:ScrollBy(1) end)

    local scrollBar = CreateFrame("Slider", nil, listPane, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", -5, -28)
    scrollBar:SetPoint("BOTTOMRIGHT", -5, 28)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(1)
    scrollBar.scrollStep = 1
    scrollBar:SetScript("OnValueChanged", function(_, value)
        self:SetScrollOffset(Round(value))
    end)
    frame.scrollBar = scrollBar

    local rows = {}
    local anchor = nil
    for index = 1, ROWS do
        local row = CreateFrame("Button", nil, listPane)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("LEFT", 8, 0)
        row:SetPoint("RIGHT", -36, 0)
        if anchor then
            row:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
        else
            row:SetPoint("TOP", 8, -34)
        end
        anchor = row

        row:SetNormalTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight")
        row:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
        row:SetHighlightTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight")
        row:GetHighlightTexture():SetVertexColor(0.12, 0.32, 0.56, 0.5)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetSize(24, 24)

        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
        row.title:SetPoint("RIGHT", -8, 0)
        row.title:SetJustifyH("LEFT")

        row.subtitle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.subtitle:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -1)
        row.subtitle:SetPoint("RIGHT", -8, 0)
        row.subtitle:SetJustifyH("LEFT")
        row.subtitle:SetTextColor(0.72, 0.72, 0.72)

        row:SetScript("OnClick", function(button)
            self:SelectRecord(button.record)
        end)

        rows[index] = row
    end
    frame.rows = rows

    local previewPane = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    previewPane:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 12, 0)
    previewPane:SetPoint("BOTTOMRIGHT", -16, 36)
    frame.previewPane = previewPane

    local previewTitle = previewPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewTitle:SetPoint("TOPLEFT", 12, -12)
    previewTitle:SetText("Preview")
    frame.previewTitle = previewTitle

    local canvas = CreateFrame("Frame", nil, previewPane, "BackdropTemplate")
    canvas:SetPoint("TOPLEFT", 12, -34)
    canvas:SetPoint("BOTTOMLEFT", 12, 96)
    canvas:SetPoint("RIGHT", -12, 0)
    canvas:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    canvas:SetBackdropColor(0.06, 0.06, 0.08, 1)
    canvas:SetBackdropBorderColor(0.28, 0.28, 0.32, 1)
    canvas:EnableMouseWheel(true)
    canvas:EnableMouse(true)
    canvas:RegisterForDrag("LeftButton")
    canvas:SetClipsChildren(true)
    frame.canvas = canvas

    local checker = canvas:CreateTexture(nil, "BACKGROUND")
    checker:SetAllPoints()
    checker:SetAtlas("UI-HUD-ExperienceBar-Fill-Rested")
    checker:SetHorizTile(true)
    checker:SetVertTile(true)
    checker:SetAlpha(0.06)
    canvas.checker = checker

    local displayTexture = canvas:CreateTexture(nil, "ARTWORK")
    displayTexture:SetPoint("CENTER")
    displayTexture:SetSize(256, 256)
    canvas.displayTexture = displayTexture

    canvas.overlayPool = {}
    canvas.zoom = 1
    canvas.offsetX = 0
    canvas.offsetY = 0

    canvas:SetScript("OnMouseWheel", function(_, delta)
        self:AdjustZoom(delta > 0 and 0.1 or -0.1)
    end)
    canvas:SetScript("OnDragStart", function(f)
        f.dragging = true
        f.dragStartX, f.dragStartY = GetCursorPosition()
        f.startOffsetX, f.startOffsetY = f.offsetX, f.offsetY
    end)
    canvas:SetScript("OnDragStop", function(f)
        f.dragging = false
    end)
    canvas:SetScript("OnUpdate", function(f)
        if not f.dragging then
            return
        end
        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        f.offsetX = f.startOffsetX + (cursorX - f.dragStartX) / scale
        f.offsetY = f.startOffsetY + (cursorY - f.dragStartY) / scale
        self:LayoutPreviewTexture()
    end)

    local details = CreateFrame("Frame", nil, previewPane)
    details:SetPoint("BOTTOMLEFT", 12, 12)
    details:SetPoint("BOTTOMRIGHT", -12, 12)
    details:SetHeight(72)
    frame.details = details

    local detailText = details:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetPoint("TOPLEFT")
    detailText:SetPoint("BOTTOMRIGHT")
    detailText:SetJustifyH("LEFT")
    detailText:SetJustifyV("TOP")
    frame.detailText = detailText

    local status = frame.StatusText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if not frame.StatusText then
        status:SetPoint("BOTTOMLEFT", 16, 14)
        status:SetPoint("RIGHT", -16, 0)
        status:SetJustifyH("LEFT")
    end
    frame.statusText = status

    self.frame = frame
    self:SetupSortDropdown()
    self:SetActiveTab(self.state.activeTab)
    self:RefreshAllData()

    return frame
end

function AssetBrowser:SetupSortDropdown()
    local dropdown = self.frame.sortDropdown
    dropdown:SetupMenu(function(_, rootDescription)
        local activeTab = self.state.activeTab
        if activeTab == TAB_ATLAS then
            rootDescription:CreateRadio("Atlas Name", function() return self.state.atlasSort == "name" end, function()
                self.state.atlasSort = "name"
                self:GetDB().atlasSort = "name"
                self:RefreshAtlasData()
            end)
            rootDescription:CreateRadio("Parent File ID", function() return self.state.atlasSort == "file" end, function()
                self.state.atlasSort = "file"
                self:GetDB().atlasSort = "file"
                self:RefreshAtlasData()
            end)
            rootDescription:CreateRadio("Width", function() return self.state.atlasSort == "width" end, function()
                self.state.atlasSort = "width"
                self:GetDB().atlasSort = "width"
                self:RefreshAtlasData()
            end)
        else
            rootDescription:CreateRadio("File ID", function() return self.state.iconSort == "id" end, function()
                self.state.iconSort = "id"
                self:GetDB().iconSort = "id"
                self:RefreshIconData()
            end)
            rootDescription:CreateRadio("Source", function() return self.state.iconSort == "source" end, function()
                self.state.iconSort = "source"
                self:GetDB().iconSort = "source"
                self:RefreshIconData()
            end)
        end
    end)
end

function AssetBrowser:ApplySortDropdownText()
    local dropdown = self.frame.sortDropdown
    if self.state.activeTab == TAB_ATLAS then
        local labels = { name = "Atlas Name", file = "Parent File ID", width = "Width" }
        dropdown:SetDefaultText("Sort")
        dropdown:OverrideText(labels[self.state.atlasSort] or "Atlas Name")
    else
        local labels = { id = "File ID", source = "Source" }
        dropdown:SetDefaultText("Sort")
        dropdown:OverrideText(labels[self.state.iconSort] or "File ID")
    end
end

function AssetBrowser:ApplyResponsiveLayout(width, height)
    if not self.frame or not self.frame.listPane then
        return
    end

    local listWidth = math.max(360, math.floor((width or self.frame:GetWidth()) * 0.36))
    self.frame.listPane:SetWidth(listWidth)
    self:LayoutPreviewTexture()
end

function AssetBrowser:SaveWindowBounds()
    local db = self:GetDB()
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    db.window.point = point
    db.window.relativePoint = relativePoint
    db.window.x = x
    db.window.y = y
    db.window.width = self.frame:GetWidth()
    db.window.height = self.frame:GetHeight()
end

function AssetBrowser:Toggle(forceShow)
    local frame = self:GetOrCreateFrame()
    local isVisible = frame.IsShellVisible and frame:IsShellVisible() or frame:IsShown()

    if forceShow or not isVisible then
        if frame.ShowExpanded then
            frame:ShowExpanded()
        else
            frame:Show()
        end
        self:RefreshAllData()
    else
        if frame.HideShell then
            frame:HideShell()
        else
            frame:Hide()
            self:SaveWindowBounds()
        end
    end
end

function AssetBrowser:SetActiveTab(tabKey)
    self.state.activeTab = tabKey
    self:GetDB().activeTab = tabKey

    for key, button in pairs(self.frame.tabs) do
        SetButtonSelected(button, key == tabKey)
    end

    local search = tabKey == TAB_ATLAS and self.state.atlasSearch or self.state.iconSearch
    self.frame.searchBox:SetText(search or "")
    self.frame.utilityButton:SetShown(tabKey == TAB_ICON)
    self.frame.copyPrimaryButton:SetShown(true)
    self.frame.copySnippetButton:SetShown(true)

    self.frame.utilityButton:SetText(self.scanTicker and "Scanning…" or "Start Spell Icon Scan")
    self.frame.previewTitle:SetText(tabKey == TAB_ATLAS and "Atlas Preview" or "Icon Preview")
    self.frame.listTitle:SetText(tabKey == TAB_ATLAS and "Atlas Results" or "Icon Results")

    self:ApplySortDropdownText()
    self:RefreshVisibleRows()
    self:RefreshCurrentPreview()
end

function AssetBrowser:OnSearchChanged(text)
    text = Trim(text)
    if self.state.activeTab == TAB_ATLAS then
        self.state.atlasSearch = text
        self:GetDB().atlasSearch = text
        self:RefreshAtlasData()
    else
        self.state.iconSearch = text
        self:GetDB().iconSearch = text
        self:RefreshIconData()
    end
end

function AssetBrowser:SetScrollOffset(offset)
    if self.state.activeTab == TAB_ATLAS then
        local maxOffset = math.max(#self.state.filteredAtlases - ROWS, 0)
        self.state.atlasOffset = math.max(0, math.min(offset, maxOffset))
    else
        local maxOffset = math.max(#self.state.filteredIcons - ROWS, 0)
        self.state.iconOffset = math.max(0, math.min(offset, maxOffset))
    end
    self:RefreshVisibleRows()
end

function AssetBrowser:ScrollBy(delta)
    local offset = self.state.activeTab == TAB_ATLAS and self.state.atlasOffset or self.state.iconOffset
    self:SetScrollOffset(offset + delta)
end

function AssetBrowser:GetActiveListAndOffset()
    if self.state.activeTab == TAB_ATLAS then
        return self.state.filteredAtlases, self.state.atlasOffset
    end
    return self.state.filteredIcons, self.state.iconOffset
end

function AssetBrowser:RefreshVisibleRows()
    if not self.frame then
        return
    end

    local list, offset = self:GetActiveListAndOffset()
    local maxOffset = math.max(#list - ROWS, 0)
    self.frame.scrollBar:SetMinMaxValues(0, maxOffset)
    self.frame.scrollBar:SetValue(offset)
    self.frame.scrollBar:SetShown(maxOffset > 0)

    for rowIndex = 1, ROWS do
        local record = list[offset + rowIndex]
        local row = self.frame.rows[rowIndex]
        row.record = record
        if record then
            if record.kind == TAB_ATLAS then
                row.icon:SetAtlas(record.atlas)
                row.title:SetText(record.atlas)
                row.subtitle:SetFormattedText("Parent %s  •  %sx%s%s", record.parentDisplay or record.parentFileID, record.width, record.height, record.existsInAPI and "" or "  •  Not in live API")
            else
                row.icon:SetTexture(record.fileID)
                row.title:SetText(tostring(record.fileID))
                row.subtitle:SetText(record.sourceText ~= "" and record.sourceText or record.filename)
            end
            row:Show()
        else
            row:Hide()
        end
    end

    local countText = string.format("%s results", FormatNumber(#list))
    self:UpdateFooterStatus(countText)
end

function AssetBrowser:UpdateFooterStatus(text)
    if self.frame and self.frame.statusText then
        self.frame.statusText:SetText(text or "")
    end
    if self.frame and self.frame.SetShellStatus then
        self.frame:SetShellStatus(text or "")
    end
end

function AssetBrowser:SelectRecord(record)
    if not record then
        return
    end

    if record.kind == TAB_ATLAS then
        self.state.selectedAtlas = record
    else
        self.state.selectedIcon = record
    end

    self:RefreshCurrentPreview()
end

function AssetBrowser:RefreshCurrentPreview()
    if not self.frame then
        return
    end

    local record = self.state.activeTab == TAB_ATLAS and self.state.selectedAtlas or self.state.selectedIcon
    if not record then
        self.frame.canvas.displayTexture:SetTexture(nil)
        self.frame.detailText:SetText("Select a result to inspect it.")
        self:ClearAtlasOverlays()
        return
    end

    if record.kind == TAB_ATLAS then
        self:ShowAtlasPreview(record)
    else
        self:ShowIconPreview(record)
    end
end

function AssetBrowser:EnsureOverlay(index)
    local overlay = self.frame.canvas.overlayPool[index]
    if overlay then
        return overlay
    end

    local parent = self.frame.canvas
    overlay = {
        top = parent:CreateTexture(nil, "OVERLAY"),
        bottom = parent:CreateTexture(nil, "OVERLAY"),
        left = parent:CreateTexture(nil, "OVERLAY"),
        right = parent:CreateTexture(nil, "OVERLAY"),
    }

    for _, texture in pairs(overlay) do
        texture:SetColorTexture(0.2, 0.8, 1.0, 0.9)
    end

    self.frame.canvas.overlayPool[index] = overlay
    return overlay
end

function AssetBrowser:ClearAtlasOverlays()
    for _, overlay in ipairs(self.frame.canvas.overlayPool) do
        overlay.top:Hide()
        overlay.bottom:Hide()
        overlay.left:Hide()
        overlay.right:Hide()
    end
end

function AssetBrowser:LayoutPreviewTexture()
    local canvas = self.frame.canvas
    local texture = canvas.displayTexture
    if not texture:GetTexture() then
        return
    end

    local width = (canvas.baseWidth or 256) * canvas.zoom
    local height = (canvas.baseHeight or 256) * canvas.zoom
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", canvas, "CENTER", canvas.offsetX, canvas.offsetY)
    texture:SetSize(width, height)

    if canvas.activeRecord and canvas.activeRecord.kind == TAB_ATLAS then
        self:LayoutAtlasOverlays(canvas.activeRecord, width, height)
    end
end

function AssetBrowser:LayoutAtlasOverlays(selectedRecord, textureWidth, textureHeight)
    self:ClearAtlasOverlays()

    local sameFile = self.parentAtlasIndex[selectedRecord.parentFileID] or self.parentAtlasIndex[selectedRecord.parentDisplay] or {}
    local texture = self.frame.canvas.displayTexture
    local left = texture:GetLeft()
    local right = texture:GetRight()
    local top = texture:GetTop()
    local bottom = texture:GetBottom()
    if not left or not right or not top or not bottom then
        return
    end

    local screenWidth = right - left
    local screenHeight = top - bottom

    for index, record in ipairs(sameFile) do
        local overlay = self:EnsureOverlay(index)
        local oLeft = left + screenWidth * record.leftTexCoord
        local oRight = left + screenWidth * record.rightTexCoord
        local oTop = top - screenHeight * record.topTexCoord
        local oBottom = top - screenHeight * record.bottomTexCoord

        local r, g, b = 0.2, 0.8, 1.0
        if record.atlas == selectedRecord.atlas then
            r, g, b = 1.0, 0.82, 0.2
        end

        overlay.top:SetColorTexture(r, g, b, 0.95)
        overlay.bottom:SetColorTexture(r, g, b, 0.95)
        overlay.left:SetColorTexture(r, g, b, 0.95)
        overlay.right:SetColorTexture(r, g, b, 0.95)

        local canvas = self.frame.canvas
        local cLeft = canvas:GetLeft()
        local cBottom = canvas:GetBottom()

        overlay.top:ClearAllPoints()
        overlay.top:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", oLeft - cLeft, oTop - cBottom)
        overlay.top:SetSize(math.max(oRight - oLeft, 1), 2)
        overlay.top:Show()

        overlay.bottom:ClearAllPoints()
        overlay.bottom:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", oLeft - cLeft, oBottom - cBottom)
        overlay.bottom:SetSize(math.max(oRight - oLeft, 1), 2)
        overlay.bottom:Show()

        overlay.left:ClearAllPoints()
        overlay.left:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", oLeft - cLeft, oBottom - cBottom)
        overlay.left:SetSize(2, math.max(oTop - oBottom, 1))
        overlay.left:Show()

        overlay.right:ClearAllPoints()
        overlay.right:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", oRight - cLeft, oBottom - cBottom)
        overlay.right:SetSize(2, math.max(oTop - oBottom, 1))
        overlay.right:Show()
    end
end

function AssetBrowser:AdjustZoom(delta)
    local canvas = self.frame.canvas
    canvas.zoom = math.max(0.1, math.min(8, canvas.zoom + delta))
    self:LayoutPreviewTexture()
end

function AssetBrowser:ResetPreviewView()
    local canvas = self.frame.canvas
    canvas.zoom = 1
    canvas.offsetX = 0
    canvas.offsetY = 0
    self:LayoutPreviewTexture()
end

-- Resolve a usable preview texture for an atlas record. Returns the source
-- mode chosen ("fileid" | "path" | "atlas") so the caller can describe the
-- preview source to the user. Returns nil when no source could be resolved.
function AssetBrowser:SetPreviewTextureForAtlas(record)
    local canvas = self.frame.canvas
    local texture = canvas.displayTexture
    texture:SetTexCoord(0, 1, 0, 1)

    local parentID = tonumber(record.parentFileID)
    if parentID and parentID > 0 then
        texture:SetTexture(parentID)
        if texture:GetTexture() then
            return "fileid"
        end
    end

    if type(record.parentPath) == "string" and record.parentPath ~= "" then
        texture:SetTexture(record.parentPath)
        if texture:GetTexture() then
            return "path"
        end
    end

    if type(record.atlas) == "string" and record.atlas ~= "" then
        local ok = pcall(texture.SetAtlas, texture, record.atlas, false)
        if ok and texture:GetTexture() then
            return "atlas"
        end
    end

    texture:SetTexture(nil)
    return nil
end

function AssetBrowser:ShowAtlasPreview(record)
    local canvas = self.frame.canvas
    canvas.activeRecord = record
    local tex = canvas.displayTexture

    local previewMode = self:SetPreviewTextureForAtlas(record)
    canvas.baseWidth = tonumber(record.width) or 256
    canvas.baseHeight = tonumber(record.height) or 256
    canvas.zoom = 1
    canvas.offsetX = 0
    canvas.offsetY = 0
    self:LayoutPreviewTexture()

    local previewSourceText
    if previewMode == "fileid" then
        previewSourceText = string.format("Parent File ID %s", tostring(record.parentFileID))
    elseif previewMode == "path" then
        previewSourceText = string.format("Texture Path %s", tostring(record.parentPath))
    elseif previewMode == "atlas" then
        previewSourceText = string.format("Atlas fallback %s", tostring(record.atlas))
    else
        previewSourceText = "No preview source available"
    end

    self.frame.detailText:SetFormattedText("|cffffffffAtlas:|r %s\n|cffffffffParent:|r %s\n|cffffffffAtlas Size:|r %sx%s\n|cffffffffTexCoords:|r %.6f, %.6f, %.6f, %.6f\n|cffffffffAPI Visibility:|r %s\n|cffffffffPreview Source:|r %s\n|cffffffffPath:|r %s",
        record.atlas,
        record.parentDisplay or record.parentFileID,
        record.width,
        record.height,
        record.leftTexCoord,
        record.rightTexCoord,
        record.topTexCoord,
        record.bottomTexCoord,
        record.existsInAPI and "Available" or "Database-only",
        previewSourceText,
        record.parentPath
    )
end

function AssetBrowser:ShowIconPreview(record)
    local canvas = self.frame.canvas
    canvas.activeRecord = record
    canvas.baseWidth = 256
    canvas.baseHeight = 256
    canvas.displayTexture:SetTexture(record.fileID)
    canvas.zoom = 1
    canvas.offsetX = 0
    canvas.offsetY = 0
    self:LayoutPreviewTexture()
    self:ClearAtlasOverlays()

    self.frame.detailText:SetFormattedText("|cffffffffFile ID:|r %s\n|cffffffffSource:|r %s\n|cffffffffFilename:|r %s",
        record.fileID,
        record.sourceText ~= "" and record.sourceText or "Unknown",
        record.filename
    )
end

function AssetBrowser:RefreshAllData()
    self:BuildAtlasData()
    self:RefreshAtlasData()
    self:RefreshIconData()
    self:RefreshCurrentPreview()
end

function AssetBrowser:RefreshAtlasData()
    self:BuildAtlasData()
    local search = Lower(self.state.atlasSearch)
    local includeMissing = self:GetDB().includeMissingAtlases

    table.wipe(self.state.filteredAtlases)
    for _, record in ipairs(self.atlasRecords) do
        if (includeMissing or record.existsInAPI) and (search == "" or string.find(record.search, search, 1, true)) then
            table.insert(self.state.filteredAtlases, record)
        end
    end

    local sortMode = self.state.atlasSort
    table.sort(self.state.filteredAtlases, function(a, b)
        if sortMode == "file" then
            if a.parentFileID ~= b.parentFileID then
                return tostring(a.parentDisplay or a.parentFileID) < tostring(b.parentDisplay or b.parentFileID)
            end
            return a.atlas < b.atlas
        elseif sortMode == "width" then
            if a.width ~= b.width then
                return a.width < b.width
            end
            return a.atlas < b.atlas
        end
        return a.atlas < b.atlas
    end)

    if self.state.selectedAtlas and not self.atlasIndex[self.state.selectedAtlas.atlas] then
        self.state.selectedAtlas = nil
    end

    self.state.atlasOffset = math.max(0, math.min(self.state.atlasOffset, math.max(#self.state.filteredAtlases - ROWS, 0)))
    if self.state.activeTab == TAB_ATLAS then
        self:RefreshVisibleRows()
    end
end

function AssetBrowser:RefreshIconData()
    self:EnsureIconSources()
    local search = Lower(self.state.iconSearch)

    table.wipe(self.state.filteredIcons)
    for _, record in ipairs(self.iconRecords) do
        if search == "" or string.find(record.search, search, 1, true) then
            table.insert(self.state.filteredIcons, record)
        end
    end

    local sortMode = self.state.iconSort
    table.sort(self.state.filteredIcons, function(a, b)
        if sortMode == "source" then
            local aSource = a.sourceText ~= "" and a.sourceText or a.filename
            local bSource = b.sourceText ~= "" and b.sourceText or b.filename
            if aSource ~= bSource then
                return aSource < bSource
            end
        end
        return tonumber(a.fileID) < tonumber(b.fileID)
    end)

    self.state.iconOffset = math.max(0, math.min(self.state.iconOffset, math.max(#self.state.filteredIcons - ROWS, 0)))
    if self.state.activeTab == TAB_ICON then
        self:RefreshVisibleRows()
    end
end

function AssetBrowser:CopyCurrentSelectionPrimary()
    local record = self.state.activeTab == TAB_ATLAS and self.state.selectedAtlas or self.state.selectedIcon
    if not record then
        ns:Notify("Select something first.")
        return
    end

    if record.kind == TAB_ATLAS then
        ns:ShowCopyDialog("Copy atlas name", record.atlas)
    else
        ns:ShowCopyDialog("Copy file ID", tostring(record.fileID))
    end
end

function AssetBrowser:CopyCurrentSelectionSnippet()
    local record = self.state.activeTab == TAB_ATLAS and self.state.selectedAtlas or self.state.selectedIcon
    if not record then
        ns:Notify("Select something first.")
        return
    end

    local snippet
    if record.kind == TAB_ATLAS then
        snippet = string.format('texture:SetAtlas("%s")', record.atlas)
    else
        snippet = string.format('texture:SetTexture(%d)', record.fileID)
    end

    ns:ShowCopyDialog("Copy snippet", snippet)
end
