-- Harvest's own window: node search and settings.
--
-- Settings used to live in a canvas panel inside Blizzard's options, which put
-- the addon's only interface three clicks deep inside someone else's UI and
-- gave it nowhere to grow. Everything now lives here, and the Blizzard entry
-- is a proxy whose only job is to open this window -- the same shape Athena
-- uses.
--
-- Chrome comes from FabledUI_UIToolkit (another lane owns that addon; we call
-- its Shell and Themes, never edit them). If the toolkit is missing the window
-- degrades to a message rather than a Lua error.

local H = FabledUI_Harvest
if not H then return end

H.Window = {}
local W = H.Window

local WINDOW_NAME = "FabledUI_HarvestFrame"
local THEME = "FableNeon"
local ACCENT = { 0.44, 0.88, 0.63, 1.0 }  -- neon green (gathering)

local TAB_ORDER = { "find", "settings" }
local TAB_LABELS = { find = "Find Nodes", settings = "Settings" }

local ROW_HEIGHT = 34
local MAX_ROWS = 12

local function Toolkit()
    local T = rawget(_G, "FabledUI_UIToolkit")
    if T and T.Shell and type(T.Shell.CreateWindow) == "function" then
        return T
    end
    return nil
end

local function StyleButton(button)
    local T = Toolkit()
    if button and T and T.Themes and T.Themes.StyleFlatButton then
        T.Themes:StyleFlatButton(button, THEME, ACCENT)
    end
end

local function MakeCheckbox(parent, label, initial, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.Text:SetText(label)
    cb:SetChecked(initial and true or false)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return cb
end

-- =============================================================================
-- Find tab
-- =============================================================================

local function BuildFindPage(page)
    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetSize(280, 22)
    search:SetPoint("TOPLEFT", 8, -8)
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    page.SearchBox = search

    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", search, "RIGHT", 10, 0)
    hint:SetText("Try: mining | lumber | a zone name | a node you've found")

    local summary = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 2, -8)
    summary:SetJustifyH("LEFT")
    page.Summary = summary

    -- Fixed row pool. The result list is capped, so a pool sized to the cap
    -- never needs to grow and rows can be reused across every query.
    page.Rows = {}
    local anchor = summary
    for index = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, page)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", index == 1 and -2 or 0, index == 1 and -10 or -2)
        row:SetPoint("RIGHT", page, "RIGHT", -8, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, 0.04)
        row.Background = bg

        row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        local hl = row:GetHighlightTexture()
        if hl then hl:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.18) end

        row.Zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.Zone:SetPoint("TOPLEFT", 8, -5)
        row.Zone:SetJustifyH("LEFT")

        row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.Detail:SetPoint("BOTTOMLEFT", 8, 5)
        row.Detail:SetJustifyH("LEFT")

        row.Count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.Count:SetPoint("RIGHT", -10, 0)
        row.Count:SetJustifyH("RIGHT")

        row:SetScript("OnClick", function(self)
            if self.mapID then W:OpenMapTo(self.mapID) end
        end)

        row:Hide()
        page.Rows[index] = row
        anchor = row
    end

    search:SetScript("OnTextChanged", function() W:RefreshFind() end)
end

--- Open the world map to a zone. Clicking a result should take the player
--- somewhere, and the map is the one destination that needs no other addon.
--- Returns true when the map was opened or retargeted.
---
--- Every call here is guarded individually rather than trusted. This runs from
--- a click on a search result, so anything that throws lands in the player's
--- face as a Lua error -- and the map frame is Blizzard's, loaded on demand,
--- with a surface that differs between clients.
function W:OpenMapTo(mapID)
    if not mapID then return false end

    local mapFrame = rawget(_G, "WorldMapFrame")
    if not mapFrame then return false end

    -- Showing the map is a protected action in combat.
    if InCombatLockdown and InCombatLockdown() then
        if H.Print then H:Print("Can't open the map in combat.") end
        return false
    end

    local shownOK, shown = pcall(mapFrame.IsShown, mapFrame)
    if shownOK and not shown then
        local toggle = rawget(_G, "ToggleWorldMap")
        if toggle then pcall(toggle) end
    end

    if mapFrame.SetMapID then
        pcall(mapFrame.SetMapID, mapFrame, mapID)
    end
    return true
end

function W:RefreshFind()
    local page = self.pages and self.pages.find
    if not (page and page.Rows) then return end

    local query = page.SearchBox and page.SearchBox:GetText() or ""
    local results = H.Search:Query(query, { limit = MAX_ROWS })

    for index, row in ipairs(page.Rows) do
        local result = results[index]
        if not result then
            row:Hide()
        else
            row.mapID = result.mapID
            row.Zone:SetText(result.name or ("Map " .. result.mapID))

            local detail = H.Search:DescribeLayers(result)
            if result.matchedNames and #result.matchedNames > 0 then
                -- Say what actually matched, so a name hit does not look like
                -- an unexplained result.
                detail = table.concat(result.matchedNames, ", ") .. "  |  " .. detail
            end
            row.Detail:SetText(detail)

            -- Distinguish what the player found from what shipped with us.
            if result.captured > 0 then
                row.Count:SetText(string.format("%d  (%d yours)", result.total, result.captured))
            else
                row.Count:SetText(tostring(result.total))
            end
            row:Show()
        end
    end

    if page.Summary then
        if #results == 0 then
            page.Summary:SetText(query ~= "" and "No zones match that." or "No node data yet.")
        else
            local shown = math.min(#results, MAX_ROWS)
            page.Summary:SetText(string.format("Showing %d zone%s, richest first. Click one to open its map.",
                shown, shown == 1 and "" or "s"))
        end
    end
end

-- =============================================================================
-- Settings tab
-- =============================================================================

local function BuildSettingsPage(page)
    local settings = H.settings or {}

    local layersLbl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    layersLbl:SetPoint("TOPLEFT", 8, -8)
    layersLbl:SetText("Map layers")

    local anchor = layersLbl
    local layers = settings.layers or {}
    -- Iterate the module's layer order, not pairs(): a hash walk reshuffles the
    -- checkbox order between sessions.
    for _, layer in ipairs(H.Search and H.Search.LAYERS or {}) do
        if layers[layer] ~= nil then
            local cb = MakeCheckbox(page, layer:gsub("^%l", string.upper), layers[layer], function(val)
                layers[layer] = val
                if H.MapProvider then H.MapProvider:RefreshPins() end
                if H.RadarHUD and H.RadarHUD.RebuildPoints then H.RadarHUD:RebuildPoints() end
            end)
            cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == layersLbl and 4 or 0, -4)
            anchor = cb
        end
    end

    local behaviourLbl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    behaviourLbl:SetPoint("TOPLEFT", layersLbl, "TOPLEFT", 260, 0)
    behaviourLbl:SetText("Behaviour")

    local radarCb = MakeCheckbox(page, "Show session radar HUD", settings.radar and settings.radar.enabled, function(val)
        if settings.radar then settings.radar.enabled = val end
        if H.RadarHUD and H.RadarHUD.frame then H.RadarHUD.frame:SetShown(val) end
    end)
    radarCb:SetPoint("TOPLEFT", behaviourLbl, "BOTTOMLEFT", 4, -4)

    local failedCb = MakeCheckbox(page, "Record nodes I lack the skill for",
        settings.captureFailedGathers ~= false, function(val)
            settings.captureFailedGathers = val
        end)
    failedCb:SetPoint("TOPLEFT", radarCb, "BOTTOMLEFT", 0, -4)

    local importedCb = MakeCheckbox(page, "Show imported node locations",
        settings.showImportedNodes ~= false, function(val)
            settings.showImportedNodes = val
            if H.MapProvider then H.MapProvider:RefreshPins() end
            if H.RadarHUD and H.RadarHUD.RebuildPoints then H.RadarHUD:RebuildPoints() end
        end)
    importedCb:SetPoint("TOPLEFT", failedCb, "BOTTOMLEFT", 0, -4)

    local dataLbl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dataLbl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, -18)
    dataLbl:SetText("Node data")

    local pruneBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    pruneBtn:SetSize(170, 24)
    pruneBtn:SetPoint("TOPLEFT", dataLbl, "BOTTOMLEFT", 4, -6)
    pruneBtn:SetText("Prune old nodes")
    StyleButton(pruneBtn)
    pruneBtn:SetScript("OnClick", function()
        if H:IsPruneRunning() then
            H:Print("Prune already in progress.")
            return
        end
        if not H:PruneNodes(function(count) H:Print("Pruned " .. count .. " old nodes.") end) then
            H:Print("Nothing to prune — storage is not ready.")
        end
    end)

    local exportBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    exportBtn:SetSize(120, 24)
    exportBtn:SetPoint("LEFT", pruneBtn, "RIGHT", 8, 0)
    exportBtn:SetText("Export")
    StyleButton(exportBtn)
    exportBtn:SetScript("OnClick", function()
        if H.IE then H.IE:OpenExport() end
    end)

    local importBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 24)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetText("Import")
    StyleButton(importBtn)
    importBtn:SetScript("OnClick", function()
        if H.IE then H.IE:OpenImport() end
    end)

    page.Status = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.Status:SetPoint("TOPLEFT", pruneBtn, "BOTTOMLEFT", -4, -12)
    page.Status:SetJustifyH("LEFT")
end

function W:RefreshSettings()
    local page = self.pages and self.pages.settings
    if not (page and page.Status) then return end

    local captured, maps = 0, 0
    if H.db and H.db.nodes then
        for _, zone in pairs(H.db.nodes) do
            maps = maps + 1
            for _ in pairs(zone) do captured = captured + 1 end
        end
    end

    local importedZones = 0
    if H.NodeIndex and H.NodeIndex.zones then
        for _ in pairs(H.NodeIndex.zones) do importedZones = importedZones + 1 end
    end

    page.Status:SetText(string.format(
        "You have gathered %d node%s across %d map%s.  Reference data covers %d zone%s.  Storage: %s.",
        captured, captured == 1 and "" or "s",
        maps, maps == 1 and "" or "s",
        importedZones, importedZones == 1 and "" or "s",
        H._storageBackend or "unknown"))
end

-- =============================================================================
-- Window
-- =============================================================================

function W:ShowTab(key)
    if not self.pages then return end
    for name, page in pairs(self.pages) do
        page:SetShown(name == key)
    end
    for name, button in pairs(self.tabButtons or {}) do
        button:SetEnabled(name ~= key)
    end
    self.activeTab = key

    if key == "find" then
        self:RefreshFind()
    elseif key == "settings" then
        self:RefreshSettings()
    end
end

function W:Create()
    if self.window then return self.window end

    local T = Toolkit()
    if not T then
        if H.Print then H:Print("FabledUI_UIToolkit is required for the Harvest window.") end
        return nil
    end

    H.settings = H.settings or {}
    H.settings.window = H.settings.window or {}

    local frame = T.Shell:CreateWindow(WINDOW_NAME, {
        title = "FabledUI - Harvest",
        subtitle = "Gathering nodes, map pins and session radar.",
        theme = THEME,
        accentColor = ACCENT,
        width = 760,
        height = 560,
        minWidth = 640,
        minHeight = 460,
        state = H.settings.window,
        ribbon = false,
        resizable = true,
    })
    if not frame then return nil end

    self.window = frame
    self.pages = {}
    self.tabButtons = {}

    local content = frame.Content

    local tabs = CreateFrame("Frame", nil, content)
    tabs:SetPoint("TOPLEFT", 0, 0)
    tabs:SetPoint("TOPRIGHT", 0, 0)
    tabs:SetHeight(28)

    local last
    for _, key in ipairs(TAB_ORDER) do
        local button = CreateFrame("Button", nil, tabs, "UIPanelButtonTemplate")
        button:SetSize(120, 24)
        button:SetText(TAB_LABELS[key])
        StyleButton(button)
        if last then
            button:SetPoint("LEFT", last, "RIGHT", 8, 0)
        else
            button:SetPoint("TOPLEFT", 0, 0)
        end
        button:SetScript("OnClick", function() W:ShowTab(key) end)
        self.tabButtons[key] = button
        last = button
    end

    local host = CreateFrame("Frame", nil, content)
    host:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, -10)
    host:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    for _, key in ipairs(TAB_ORDER) do
        local page = CreateFrame("Frame", nil, host)
        page:SetAllPoints()
        page:Hide()
        self.pages[key] = page
    end

    BuildFindPage(self.pages.find)
    BuildSettingsPage(self.pages.settings)

    self:ShowTab("find")
    frame:Hide()
    return frame
end

function W:Toggle()
    local frame = self:Create()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:ShowTab(self.activeTab or "find")
    end
end

function W:Open(tab)
    local frame = self:Create()
    if not frame then return end
    frame:Show()
    self:ShowTab(tab or self.activeTab or "find")
end
