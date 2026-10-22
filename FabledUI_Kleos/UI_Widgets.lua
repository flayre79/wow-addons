local K = Kleos

-- ============================================================================
-- UI_Widgets
-- The widget kit every Kleos panel is built from. Kept separate from UI.lua so
-- the tab modules do not each grow their own row pool.
--
-- Chrome styling comes from FabledUI_UIToolkit when it is loaded (Themes) and
-- degrades to a plain backdrop when it is not. UIToolkit belongs to another
-- lane, so nothing here writes to it.
-- ============================================================================

K.Widgets = K.Widgets or {}
local W = K.Widgets

local TK = rawget(_G, "FabledUI_UIToolkit")
W.ACCENT = { 1.0, 0.71, 0.33, 1.0 }   -- warm amber; Kleos = glory/renown
W.THEME = "FableNeon"

function W:Toolkit() return TK end

function W:StyleButton(button)
    if button and TK and TK.Themes and TK.Themes.StyleFlatButton then
        TK.Themes:StyleFlatButton(button, self.THEME, self.ACCENT)
    end
    return button
end

function W:StylePanel(frame)
    if not frame then return frame end
    K.Util:ApplyBackdrop(frame)
    if TK and TK.Themes and TK.Themes.ApplyPanel then
        TK.Themes:ApplyPanel(frame, self.THEME, self.ACCENT)
    end
    return frame
end

function W:Panel(parent, name)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    return self:StylePanel(frame)
end

function W:Button(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    self:StyleButton(button)
    button:SetSize(width or 100, height or 22)
    button:SetText(text or "")
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

function W:Label(parent, text, template, justify)
    local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fontString:SetJustifyH(justify or "LEFT")
    fontString:SetText(text or "")
    return fontString
end

function W:Checkbox(parent, label, checked, onChange)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(18, 18)
    -- UICheckButtonTemplate exposes the label as .Text on retail 11.x+ and as
    -- .text on older clients; fall back to an anchored string so the label is
    -- never invisible.
    if checkbox.Text then
        checkbox.Text:SetText(label)
    elseif checkbox.text then
        checkbox.text:SetText(label)
    else
        local fontString = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fontString:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        fontString:SetText(label)
        checkbox.Text = fontString
    end
    checkbox:SetChecked(checked and true or false)
    checkbox:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked() and true or false) end
    end)
    return checkbox
end

-- ----------------------------------------------------------------------------
-- Dropdown
-- MenuUtil when available (the simulator provides it), otherwise the button
-- cycles through its options so the control is still usable.
-- ----------------------------------------------------------------------------
function W:Dropdown(parent, options, labels, onChange, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    self:StyleButton(button)
    button:SetSize(width or 150, 20)
    button._options = options or {}
    button._labels = labels or {}
    button._index = 1
    button._onChange = onChange

    local function LabelFor(key)
        return button._labels[key] or tostring(key)
    end

    button:SetText(LabelFor(button._options[1]))

    button:SetScript("OnClick", function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                for _, key in ipairs(self._options) do
                    local option = key
                    rootDescription:CreateButton(LabelFor(option), function()
                        self:SetSelected(option)
                        if self._onChange then self._onChange(option) end
                    end)
                end
            end)
        else
            local current = (self._index or 1) + 1
            if current > #self._options then current = 1 end
            local option = self._options[current]
            self:SetSelected(option)
            if self._onChange then self._onChange(option) end
        end
    end)

    function button:SetOptions(newOptions, newLabels)
        self._options = newOptions or {}
        if newLabels then self._labels = newLabels end
    end

    function button:SetSelected(key)
        for index, option in ipairs(self._options) do
            if option == key then self._index = index end
        end
        self:SetText(LabelFor(key))
        self._selected = key
    end

    function button:GetSelected() return self._selected or self._options[self._index or 1] end

    return button
end

-- ----------------------------------------------------------------------------
-- Search box
-- Debounced through Util so typing does not re-query the catalog per keystroke.
-- ----------------------------------------------------------------------------
function W:SearchBox(parent, width, onChange, placeholder)
    -- SearchBoxTemplate gives the magnifier and clear button; InputBoxTemplate is
    -- the fallback for clients (and the simulator, on some builds) that do not
    -- register it. A missing template throws from CreateFrame, which would take
    -- the whole panel build down with it.
    local box
    for _, template in ipairs({ "SearchBoxTemplate", "InputBoxTemplate" }) do
        local ok, created = pcall(CreateFrame, "EditBox", nil, parent, template)
        if ok and created then
            box = created
            break
        end
    end
    if not box then
        box = CreateFrame("EditBox", nil, parent)
        box:SetFontObject("ChatFontNormal")
    end
    box:SetSize(width or 200, 20)
    box:SetAutoFocus(false)
    if box.Instructions then box.Instructions:SetText(placeholder or (K.L.SEARCH or "Search")) end

    box:SetScript("OnTextChanged", function(self, userInput)
        if self.Instructions then self.Instructions:SetShown((self:GetText() or "") == "") end
        if not userInput then return end
        local text = self:GetText() or ""
        K.Util:DebouncedSave("kleos.search", 0.25, function()
            if onChange then onChange(text) end
        end)
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onChange then onChange(self:GetText() or "") end
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        if onChange then onChange("") end
    end)
    return box
end

-- ----------------------------------------------------------------------------
-- Progress bar
-- ----------------------------------------------------------------------------
function W:ProgressBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width or 160, height or 12)
    bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    bar:SetStatusBarColor(unpack(self.ACCENT))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetColorTexture(0, 0, 0, 0.5)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")

    function bar:SetProgress(fraction, label)
        fraction = tonumber(fraction) or 0
        self:SetValue(math.max(0, math.min(1, fraction)))
        self.text:SetText(label or ("%d%%"):format(math.floor(fraction * 100 + 0.5)))
    end

    return bar
end

-- ----------------------------------------------------------------------------
-- Paged row list
-- Frame count is bounded by the page size, not by the result count: the
-- catalog can return 5,000 rows and this still builds at most `pageSize`
-- buttons. Rows are recycled between pages and between tabs.
--
--   list:SetRenderer(fn)   fn(row, id, index) draws one row
--   list:SetItems(ids)     replaces the result set and re-renders page 1
--   list:SetPage(n)
--   list:Refresh()
-- ----------------------------------------------------------------------------
local DEFAULT_PAGE_SIZE = 100

function W:RowList(parent, options)
    options = options or {}
    local list = CreateFrame("Frame", nil, parent)
    list.rowHeight = options.rowHeight or 22
    list.pageSize = options.pageSize or DEFAULT_PAGE_SIZE
    list.items = {}
    list.rows = {}
    list.page = 1

    local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -26, options.footer and 24 or 0)
    list.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    list.content = content

    local emptyLabel = self:Label(list, options.emptyText or (K.L.NO_RESULTS or "No results."), "GameFontDisableLarge", "CENTER")
    emptyLabel:SetPoint("TOP", list, "TOP", 0, -40)
    emptyLabel:Hide()
    list.emptyLabel = emptyLabel

    local footer, pageLabel, previous, nextButton
    if options.footer then
        footer = CreateFrame("Frame", nil, list)
        footer:SetPoint("BOTTOMLEFT", 0, 0)
        footer:SetPoint("BOTTOMRIGHT", 0, 0)
        footer:SetHeight(22)

        previous = self:Button(footer, "<", 28, 20, function() list:SetPage((list.page or 1) - 1) end)
        previous:SetPoint("LEFT", 0, 0)

        nextButton = self:Button(footer, ">", 28, 20, function() list:SetPage((list.page or 1) + 1) end)
        nextButton:SetPoint("LEFT", previous, "RIGHT", 4, 0)

        pageLabel = self:Label(footer, "", "GameFontHighlightSmall", "LEFT")
        pageLabel:SetPoint("LEFT", nextButton, "RIGHT", 8, 0)

        list.footer = footer
        list.pageLabel = pageLabel
        list.previousButton = previous
        list.nextButton = nextButton
    end

    function list:PageCount()
        return math.max(1, math.ceil(#self.items / self.pageSize))
    end

    function list:SetRenderer(fn) self.renderer = fn end

    function list:SetRowHeight(height)
        self.rowHeight = tonumber(height) or self.rowHeight
    end

    function list:AcquireRow(index)
        local row = self.rows[index]
        if row then return row end
        row = CreateFrame("Button", nil, self.content)
        row:SetPoint("LEFT", 0, 0)
        row:SetPoint("RIGHT", 0, 0)
        row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 2, 0)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetJustifyH("LEFT")

        row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.right:SetPoint("RIGHT", -4, 0)
        row.right:SetJustifyH("RIGHT")
        -- Keep the two strings from overlapping on a narrow window.
        row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)

        row.star = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.star:SetPoint("RIGHT", row.right, "LEFT", -2, 0)

        self.rows[index] = row
        return row
    end

    function list:SetItems(items, keepPage)
        self.items = type(items) == "table" and items or {}
        if not keepPage then self.page = 1 end
        if self.page > self:PageCount() then self.page = self:PageCount() end
        self:Refresh()
    end

    function list:SetPage(page)
        page = tonumber(page) or 1
        local count = self:PageCount()
        if page < 1 then page = 1 end
        if page > count then page = count end
        self.page = page
        self:Refresh()
    end

    function list:VisibleRange()
        local first = ((self.page - 1) * self.pageSize) + 1
        local last = math.min(#self.items, first + self.pageSize - 1)
        return first, last
    end

    function list:Refresh()
        local first, last = self:VisibleRange()
        local y, drawn = 0, 0

        for cursor = first, last do
            drawn = drawn + 1
            local row = self:AcquireRow(drawn)
            row:SetHeight(self.rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -y)
            row._item = self.items[cursor]
            row._index = cursor
            if self.renderer then self.renderer(row, self.items[cursor], cursor) end
            row:Show()
            y = y + self.rowHeight
        end

        for index = drawn + 1, #self.rows do
            self.rows[index]:Hide()
            self.rows[index]._item = nil
        end

        self.content:SetHeight(math.max(1, y))
        self.content:SetWidth(math.max(1, self.scroll:GetWidth() or 1))
        self.emptyLabel:SetShown(#self.items == 0)

        if self.pageLabel then
            local count = self:PageCount()
            self.pageLabel:SetText(("%d-%d / %d  (%s %d/%d)"):format(
                (#self.items > 0) and first or 0, last, #self.items, K.L.PAGE or "page", self.page, count))
            if self.previousButton then self.previousButton:SetEnabled(self.page > 1) end
            if self.nextButton then self.nextButton:SetEnabled(self.page < count) end
        end
    end

    return list
end

-- ----------------------------------------------------------------------------
-- Colour helpers
-- ----------------------------------------------------------------------------
function W:ProgressColor(fraction)
    fraction = tonumber(fraction) or 0
    if fraction >= 1 then return "|cff00ff00" end
    if fraction >= 0.5 then return "|cffffd100" end
    if fraction > 0 then return "|cffff9955" end
    return "|cffaaaaaa"
end

function W:IconMarkup(texture, size)
    if not texture then return "" end
    size = size or 14
    if type(texture) == "number" then return ("|T%d:%d|t"):format(texture, size) end
    return ("|T%s:%d|t"):format(tostring(texture), size)
end
