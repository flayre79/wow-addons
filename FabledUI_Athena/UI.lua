local A = Athena

local ROW_H = 26
local RAIL_WIDTH = 200
local FN_THEME = "FableNeon"
local FN_ACCENT = { 0.29, 0.62, 1.0, 1.0 }

local FILTER_ALL, FILTER_ENABLED, FILTER_DISABLED = 1, 2, 3
local MAX_CHIPS = 3

-- Synthetic group for addons carrying no category. Declared up here because the
-- row builder closes over it, and a local declared further down would read as a
-- nil global from inside that closure.
local UNCATEGORISED_KEY = "__athena_uncategorised"

-- Reasons that mean "switched off", not "broken". Everything else GetAddOnInfo
-- can return (MISSING, CORRUPT, INTERFACE_VERSION, DEP_MISSING, BANNED, ...) is
-- a real problem and gets the warning treatment.
local USER_DISABLED_REASONS = {
    DISABLED = true,
    DEP_DISABLED = true,
}

-- GetAddOnInfo reports loadable=false for anything the user simply switched off,
-- so `loadable` alone cannot distinguish "you turned this off" from "this is
-- broken". Keying the warning colour off it painted almost the whole list amber.
function A.IsAddOnProblem(loadable, reason)
    if loadable ~= false then
        return false
    end
    if type(reason) ~= "string" or reason == "" then
        return false
    end
    return not USER_DISABLED_REASONS[reason]
end

-- ==========================================
-- TOOLKIT ACCESS
-- ==========================================
-- UIToolkit is an OptionalDep. The suite convention (Iris, Kleos, Crafty) is to
-- refuse the window and say so rather than hand-rolling replacement chrome, so
-- there is exactly one look to maintain. Athena's slash commands keep working
-- without it, which is the recovery path if a profile disabled UIToolkit.
local function Toolkit()
    return rawget(_G, "FabledUI_UIToolkit")
end

local function ToolkitReady()
    local TK = Toolkit()
    if type(TK) ~= "table" then return false end
    if not (TK.Shell and type(TK.Shell.CreateWindow) == "function") then return false end
    if not (TK.Components and type(TK.Components.CreateButton) == "function") then return false end
    if not (TK.Themes and type(TK.Themes.Resolve) == "function") then return false end
    return true
end

local function Theme()
    local TK = Toolkit()
    if TK and TK.Themes and TK.Themes.Resolve then
        return TK.Themes:Resolve(FN_THEME, FN_ACCENT)
    end
    return nil
end

local function Tint(texture, color)
    if texture and color then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

local function Colored(fontString, color)
    if fontString and color then
        fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

-- ==========================================
-- CATEGORY CHIP COLOURS
-- ==========================================
-- Chips are drawn as colour-escaped text in a single FontString rather than as
-- Tag frames. Rows are recycled, and a Tag frame sizes itself to its text at
-- creation with no setter, so reusing one across bindings is not possible.
local CHIP_COLORS = { "cyan", "purple", "pink", "green", "amber", "azure" }

local function ChipColorKey(categoryKey)
    local sum = 0
    for index = 1, #categoryKey do
        sum = sum + categoryKey:byte(index)
    end
    return CHIP_COLORS[(sum % #CHIP_COLORS) + 1]
end

local function ChipHex(categoryKey)
    local TK = Toolkit()
    local color
    if TK and TK.Effects and TK.Effects.Spectrum then
        color = TK.Effects:Spectrum(ChipColorKey(categoryKey), FN_THEME, FN_ACCENT)
    end
    color = color or FN_ACCENT
    return string.format("%02x%02x%02x",
        math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5))
end

-- ==========================================
-- WINDOW STATE
-- ==========================================
local function LoadWindowState()
    local stored = A.Storage:Get("account", { "windowState" }, nil)
    return type(stored) == "table" and A.DeepCopy(stored) or {}
end

local function SaveWindowStateSoon(state)
    A.Util:SaveSoon("athena-window", function()
        A.Storage:Set("account", { "windowState" }, A.DeepCopy(state))
    end)
end

-- ==========================================
-- SMALL WIDGET HELPERS
-- ==========================================
local function NewButton(parent, text, width, height, onClick, primary)
    return Toolkit().Components:CreateButton(parent, {
        text = text,
        width = width,
        height = height,
        primary = primary,
        onClick = onClick,
    })
end

local function NewHeading(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetText(text:upper())
    fs:SetJustifyH("LEFT")
    local TK = Toolkit()
    if TK.Themes.ApplyBodyText then
        TK.Themes:ApplyBodyText(fs, FN_THEME, FN_ACCENT, true)
    end
    return fs
end

local function NewDivider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    Tint(line, Theme() and Theme().border)
    return line
end

-- UIPanelScrollFrameTemplate ships Blizzard's stepper arrows. Against this theme
-- the track and thumb are invisible but the arrows still draw as bare squares,
-- leaving them floating beside the list. Fade the steppers and tint the thumb.
local function TidyScrollBar(scrollFrame)
    local bar = scrollFrame.ScrollBar or scrollFrame.scrollBar
    if not bar then return end

    for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton", "Back", "Forward" }) do
        local stepper = bar[key]
        if stepper then
            stepper:SetAlpha(0)
            if stepper.EnableMouse then stepper:EnableMouse(false) end
        end
    end

    local theme = Theme()
    local thumb = bar.ThumbTexture or (bar.GetThumbTexture and bar:GetThumbTexture())
    if thumb and theme then
        thumb:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.40)
        if thumb.SetWidth then thumb:SetWidth(4) end
    end
end

-- A scrolling list of pooled buttons. Used for the profile and category rails,
-- where the item count is small enough that pooling per item is fine.
local function NewListPanel(parent, builder)
    local panel = {}
    panel.builder = builder
    panel.scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(1, 1)
    panel.scroll:SetScrollChild(panel.content)
    panel.buttons = {}
    panel.empty = panel.scroll:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.empty:SetPoint("TOPLEFT", 6, -4)
    panel.empty:SetJustifyH("LEFT")
    panel.empty:Hide()
    local TK = Toolkit()
    if TK and TK.Themes and TK.Themes.ApplyBodyText then
        TK.Themes:ApplyBodyText(panel.empty, FN_THEME, FN_ACCENT, true)
    end
    TidyScrollBar(panel.scroll)
    return panel
end

local function NewListButton(panel, index)
    local button = CreateFrame("Button", nil, panel.content)
    button:SetHeight(20)
    button:SetPoint("TOPLEFT", 0, -(index - 1) * 21)
    button:SetPoint("TOPRIGHT", 0, -(index - 1) * 21)

    button.highlight = button:CreateTexture(nil, "BACKGROUND")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(0, 0, 0, 0)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("LEFT", 6, 0)
    button.label:SetPoint("RIGHT", -6, 0)
    button.label:SetJustifyH("LEFT")

    -- Tooltips are stored as data and read here. Setting OnEnter at bind time
    -- would clobber this highlight, and hooking it on every refresh would stack
    -- a new hook per refresh.
    button:SetScript("OnEnter", function(self)
        if not self.__selected then
            local theme = Theme()
            Tint(self.highlight, theme and theme.buttonHover)
        end
        if self.__tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.__tooltipTitle)
            if self.__tooltipBody then
                GameTooltip:AddLine(self.__tooltipBody, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.__selected then
            self.highlight:SetColorTexture(0, 0, 0, 0)
        end
        GameTooltip:Hide()
    end)
    return button
end

local function SetListButtonSelected(button, selected)
    button.__selected = selected and true or false
    local theme = Theme()
    if selected then
        Tint(button.highlight, theme and theme.accentSoft)
        Colored(button.label, theme and theme.accent)
    else
        button.highlight:SetColorTexture(0, 0, 0, 0)
        Colored(button.label, theme and theme.text)
    end
end

-- Fill a list panel from `items`, creating buttons only as the list grows.
local function FillList(panel, items, bind, emptyText)
    for index, item in ipairs(items) do
        local button = panel.buttons[index]
        if not button then
            button = (panel.builder or NewListButton)(panel, index)
            panel.buttons[index] = button
        end
        bind(button, item)
        button:Show()
    end
    for index = #items + 1, #panel.buttons do
        panel.buttons[index]:Hide()
    end
    panel.content:SetHeight(math.max(1, #items * 21))
    panel.content:SetWidth(math.max(1, panel.scroll:GetWidth() or 1))

    if emptyText and #items == 0 then
        panel.empty:SetText(emptyText)
        panel.empty:Show()
    else
        panel.empty:Hide()
    end
end

-- ==========================================
-- DRAG AND DROP
-- ==========================================
-- Drop targets are resolved by hit-testing our own category buttons on
-- OnDragStop rather than relying on OnReceiveDrag. OnReceiveDrag is built around
-- Blizzard's cursor-payload model (items, spells), and nothing is on the cursor
-- here. Drag state is keyed on the addon name / category key, never on a frame,
-- because addon rows are recycled as the list scrolls underneath the drag.
local INDENT_PER_DEPTH = 12

local function EnsureDragProxy(f)
    if f.dragProxy then
        return f.dragProxy
    end

    local theme = Theme()
    local proxy = CreateFrame("Frame", nil, UIParent)
    proxy:SetSize(200, 22)
    proxy:SetFrameStrata("TOOLTIP")
    -- Must not swallow the cursor, or IsMouseOver on the drop targets underneath
    -- would never be true.
    proxy:EnableMouse(false)

    local TK = Toolkit()
    if TK.Effects then
        TK.Effects:RoundedFill(proxy, theme and theme.surfaceRaised)
        TK.Effects:RoundedStroke(proxy, theme and theme.accent)
    end

    proxy.label = proxy:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    proxy.label:SetPoint("LEFT", 8, 0)
    proxy.label:SetPoint("RIGHT", -8, 0)
    proxy.label:SetJustifyH("LEFT")
    Colored(proxy.label, theme and theme.accent)

    proxy:Hide()
    f.dragProxy = proxy
    return proxy
end

-- Which third of the row the cursor sits in. Top and bottom thirds reorder among
-- siblings; the middle third nests. This is the standard file-tree affordance.
local function DropModeFor(button)
    local top, bottom = button:GetTop(), button:GetBottom()
    if not (top and bottom) or top <= bottom then
        return "into"
    end

    local _, cursorY = GetCursorPosition()
    local scale = button:GetEffectiveScale()
    if not scale or scale == 0 then
        return "into"
    end

    local y = cursorY / scale
    local band = (top - bottom) / 3
    if y >= top - band then
        return "before"
    end
    if y <= bottom + band then
        return "after"
    end
    return "into"
end

-- Every drop target carries `__dropTarget`, so the rail rows and the group
-- headers in the main list are interchangeable as far as the drag is concerned:
--   "all"           the rail's All addons row
--   "category"      a real category, in either place
--   "uncategorised" the synthetic bucket at the end of the grouped list
local function DropTargetsFor(f)
    local targets = {}
    if f.categoryList then
        for _, button in ipairs(f.categoryList.buttons) do
            targets[#targets + 1] = button
        end
    end
    for _, row in ipairs(f.rows or {}) do
        targets[#targets + 1] = row
    end
    return targets
end

local function DropTargetUnderCursor(f)
    for _, frame in ipairs(DropTargetsFor(f)) do
        if frame.__dropTarget and frame:IsShown() and frame:IsMouseOver() then
            return frame
        end
    end
    return nil
end

local function ClearDropHints(f)
    for _, frame in ipairs(DropTargetsFor(f)) do
        if frame.dropLine then frame.dropLine:Hide() end
        if frame.dropInto then frame.dropInto:Hide() end
    end
end

-- Only a category drag can reorder, so only it gets the before/after bands. An
-- addon is always dropped *onto* a group.
local function DropModeForDrag(drag, frame)
    if not drag or drag.kind ~= "category" then
        return "into"
    end
    if frame.__dropTarget ~= "category" then
        return "into"
    end
    return DropModeFor(frame)
end

local function UpdateDropHint(f)
    ClearDropHints(f)

    local frame = DropTargetUnderCursor(f)
    if not frame then
        return
    end

    local drag = A._drag
    -- The synthetic bucket is not a real category, so a category cannot be filed
    -- under it and gets no hint at all.
    if drag and drag.kind == "category" and frame.__dropTarget == "uncategorised" then
        return
    end

    local mode = DropModeForDrag(drag, frame)
    if mode == "into" then
        if frame.dropInto then frame.dropInto:Show() end
        return
    end

    if frame.dropLine then
        frame.dropLine:ClearAllPoints()
        frame.dropLine:SetPoint("LEFT")
        frame.dropLine:SetPoint("RIGHT")
        frame.dropLine:SetPoint(mode == "before" and "TOP" or "BOTTOM")
        frame.dropLine:Show()
    end
end

-- `sourceCategory` is the group the row was sitting under when the drag started,
-- which only exists in grouped mode. It lets a shift-drag remove exactly the
-- membership you dragged out of instead of wiping every tag the addon carries.
local function BeginDrag(f, kind, id, label, sourceCategory)
    A._drag = { kind = kind, id = id, sourceCategory = sourceCategory }

    local proxy = EnsureDragProxy(f)
    proxy.label:SetText(label or id or "")
    proxy:Show()
    proxy:SetScript("OnUpdate", function(self)
        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
            (cursorX / scale) + 14, (cursorY / scale) - 10)
        UpdateDropHint(f)
    end)
end

local function EndDrag(f)
    local drag = A._drag
    A._drag = nil

    if f.dragProxy then
        f.dragProxy:SetScript("OnUpdate", nil)
        f.dragProxy:Hide()
    end

    local frame = DropTargetUnderCursor(f)
    ClearDropHints(f)

    if not drag or not frame then
        return
    end

    local targetKind = frame.__dropTarget
    local targetKey = frame.__categoryKey

    if drag.kind == "addon" then
        -- Both "All addons" and the Uncategorised bucket mean "belongs to no
        -- category", so dropping there clears the addon's tags.
        if targetKind ~= "category" then
            A:SetAddonCategories(drag.id, {})
            A:RefreshUI()
            return
        end

        if targetKey == drag.sourceCategory then
            return
        end

        local moving = IsShiftKeyDown and IsShiftKeyDown()
        if moving and drag.sourceCategory then
            -- Take it out of the group it came from, not out of every group.
            A:MoveAddonBetweenCategories(drag.id, drag.sourceCategory, targetKey)
        else
            A:AssignAddonToCategory(drag.id, targetKey, moving)
        end
        A:RefreshUI()
        return
    end

    if drag.kind == "category" then
        if targetKind == "uncategorised" then
            return
        end
        if targetKind == "all" then
            -- Dropped on "All addons": promote to a root category.
            A:MoveCategory(drag.id, nil, "into")
        else
            A:MoveCategory(drag.id, targetKey, DropModeForDrag(drag, frame))
        end
        A:RefreshUI()
    end
end

-- ==========================================
-- CATEGORY TREE ROWS
-- ==========================================
local function NewCategoryButton(panel, index)
    local button = NewListButton(panel, index)
    local theme = Theme()

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.count:SetPoint("RIGHT", -6, 0)
    Colored(button.count, theme and theme.textMuted)

    button.expander = CreateFrame("Button", nil, button)
    button.expander:SetSize(14, 14)
    button.expander:SetPoint("LEFT", 2, 0)
    -- ASCII only: the triangle glyphs render as tofu boxes in WoW's fonts.
    button.expander.label = button.expander:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.expander.label:SetPoint("CENTER")
    Colored(button.expander.label, theme and theme.accent)
    button.expander:Hide()

    button.dropInto = button:CreateTexture(nil, "OVERLAY")
    button.dropInto:SetAllPoints()
    Tint(button.dropInto, theme and theme.accentSoft)
    button.dropInto:Hide()

    button.dropLine = button:CreateTexture(nil, "OVERLAY")
    button.dropLine:SetHeight(2)
    Tint(button.dropLine, theme and theme.accent)
    button.dropLine:Hide()

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if not self.__categoryKey then return end
        BeginDrag(panel.owner, "category", self.__categoryKey, self.label:GetText())
    end)
    button:SetScript("OnDragStop", function()
        EndDrag(panel.owner)
    end)

    return button
end

-- ==========================================
-- BLIZZARD SETTINGS MENU
-- ==========================================
function A:RegisterSettingsPanel()
    if self._settingsRegistered then return end
    self._settingsRegistered = true

    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("FabledUI - Athena")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    desc:SetText("Addon profiles (enabled sets) + custom categories independent of TOC. Use /athena or the button in Blizzard’s AddOns window.")

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    btn:SetSize(160, 26)
    btn:SetText("Open Athena")
    btn:SetScript("OnClick", function() A:ToggleMain() end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "Athena")
        Settings.RegisterAddOnCategory(cat)
        self.CategoryID = cat.GetID and cat:GetID() or cat.ID
    elseif InterfaceOptions_AddCategory then
        panel.name = "Athena"
        InterfaceOptions_AddCategory(panel)
    end
end

-- ==========================================
-- BLIZZARD ADDON UI INTEGRATION
-- ==========================================
function A:InitBlizzardAddOnsIntegration()
    local frame = _G.AddonList or _G.AddonListFrame or _G.AddOnsFrame or _G.AddOnsList
    if not frame or frame._athenaButton then return end

    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(90, 22)
    b:SetText("Athena")

    if frame.CloseButton then
        b:SetPoint("RIGHT", frame.CloseButton, "LEFT", -6, 0)
        b:SetPoint("TOP", frame, "TOP", 0, -10)
    else
        b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, -12)
    end

    b:SetScript("OnClick", function() A:ToggleMain() end)
    frame._athenaButton = b
end

-- ==========================================
-- RELOAD CONFIRMATION
-- ==========================================
-- Registered once. This writes into the global StaticPopupDialogs table, which
-- is the one piece of Athena's chrome UIToolkit cannot yet supply; see
-- docs/UIToolkit/Lane_Requests.md.
if not StaticPopupDialogs["FABLEDUI_ATHENA_RELOAD_CONFIRM"] then
    StaticPopupDialogs["FABLEDUI_ATHENA_RELOAD_CONFIRM"] = {
        text = "Profile applied. A UI reload is required to activate addon changes. Reload now?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- ==========================================
-- TEXT PROMPT
-- ==========================================
local function BuildPrompt(parent)
    local theme = Theme()
    local dialog = CreateFrame("Frame", nil, parent)
    dialog:SetSize(320, 118)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:EnableMouse(true)

    local TK = Toolkit()
    if TK.Effects then
        TK.Effects:RoundedFill(dialog, theme and theme.surfaceRaised)
        TK.Effects:RoundedStroke(dialog, theme and theme.borderStrong)
    end

    dialog.text = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.text:SetPoint("TOPLEFT", 16, -16)
    dialog.text:SetPoint("TOPRIGHT", -16, -16)
    dialog.text:SetJustifyH("LEFT")
    Colored(dialog.text, theme and theme.text)

    dialog.edit = CreateFrame("EditBox", nil, dialog)
    dialog.edit:SetPoint("TOPLEFT", 16, -40)
    dialog.edit:SetPoint("TOPRIGHT", -16, -40)
    dialog.edit:SetHeight(26)
    dialog.edit:SetAutoFocus(false)
    dialog.edit:SetTextInsets(8, 8, 0, 0)
    if TK.Themes.ApplyFont then TK.Themes:ApplyFont(dialog.edit, nil, 13) end
    Colored(dialog.edit, theme and theme.text)
    if TK.Effects then
        TK.Effects:RoundedFill(dialog.edit, { 0.055, 0.043, 0.10, 1 })
        TK.Effects:RoundedStroke(dialog.edit, theme and theme.border)
    end

    dialog.accept = NewButton(dialog, "OK", 90, 24, nil, true)
    dialog.accept:SetPoint("BOTTOMRIGHT", -16, 14)
    dialog.cancel = NewButton(dialog, "Cancel", 90, 24, function() dialog:Hide() end)
    dialog.cancel:SetPoint("RIGHT", dialog.accept, "LEFT", -8, 0)

    dialog.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
    dialog:Hide()
    return dialog
end

function A:Prompt(labelText, initialValue, onAccept)
    if not self.frame then return end
    local dialog = self.frame.prompt
    if not dialog then return end

    dialog.text:SetText(labelText or "")
    dialog.edit:SetText(initialValue or "")

    local function Accept()
        local value = dialog.edit:GetText() or ""
        dialog:Hide()
        if type(onAccept) == "function" then onAccept(value) end
    end

    dialog.accept:SetScript("OnClick", Accept)
    dialog.edit:SetScript("OnEnterPressed", Accept)
    dialog:Show()
    dialog:Raise()
    dialog.edit:SetFocus()
end

-- ==========================================
-- ADDON ROWS
-- ==========================================
local function BuildRow(f, parent)
    local theme = Theme()
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        if self.__addonName then
            BeginDrag(f, "addon", self.__addonName, self.name:GetText(), self.__sourceCategory)
        elseif self.__dropTarget == "category" and self.__categoryKey then
            BeginDrag(f, "category", self.__categoryKey, self.name:GetText())
        end
    end)
    row:SetScript("OnDragStop", function()
        EndDrag(f)
    end)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(0, 0, 0, 0)

    row.dropInto = row:CreateTexture(nil, "OVERLAY")
    row.dropInto:SetAllPoints()
    Tint(row.dropInto, theme and theme.accentSoft)
    row.dropInto:Hide()

    row.dropLine = row:CreateTexture(nil, "OVERLAY")
    row.dropLine:SetHeight(2)
    Tint(row.dropLine, theme and theme.accent)
    row.dropLine:Hide()

    row.check = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    row.check:SetPoint("LEFT", 4, 0)
    row.check:SetSize(20, 20)
    local TK = Toolkit()
    if TK.Effects and TK.Effects.StyleCheckbox then
        TK.Effects:StyleCheckbox(row.check, FN_THEME, FN_ACCENT)
    end

    -- Group headers reuse the same pooled row, so the expander lives here rather
    -- than in a second row type.
    row.expander = CreateFrame("Button", nil, row)
    row.expander:SetSize(16, 16)
    row.expander.label = row.expander:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.expander.label:SetPoint("CENTER")
    Colored(row.expander.label, theme and theme.accent)
    row.expander:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetWidth(250)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.chips = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.chips:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.chips:SetPoint("RIGHT", row, "RIGHT", -70, 0)
    row.chips:SetJustifyH("LEFT")
    row.chips:SetWordWrap(false)

    -- Always visible, never hover-revealed. Showing it on the row's OnEnter and
    -- hiding it on OnLeave flickers and cannot be clicked: moving the cursor onto
    -- a child frame takes mouse focus away from the row and fires the row's
    -- OnLeave, which hid the button out from under the cursor, which restored
    -- focus to the row, which showed it again.
    row.tagButton = NewButton(row, "Tags", 54, 18)
    row.tagButton:SetPoint("RIGHT", -8, 0)

    local function ClearHover(self)
        -- IsMouseOver is true while the cursor is over any child, so this only
        -- fires when the cursor genuinely leaves the row.
        if row:IsMouseOver() then return end
        row.stripe:SetColorTexture(0, 0, 0, 0)
        GameTooltip:Hide()
    end

    row:SetScript("OnEnter", function(self)
        local activeTheme = Theme()
        Tint(self.stripe, activeTheme and activeTheme.buttonHover)
        if self.__reason then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.__addonName or "")
            GameTooltip:AddLine(self.__reason, 1, 0.8, 0.3, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", ClearHover)
    row.tagButton:HookScript("OnLeave", ClearHover)

    row.check:SetScript("OnClick", function(self)
        local addonName = row.__addonName
        if not addonName then return end
        local ok, err = A:SetAddOnEnabled(addonName, self:GetChecked())
        if not ok then
            A.Print("Could not change " .. addonName .. ": " .. tostring(err))
        end
        A:RefreshUI()
    end)

    row.tagButton:SetScript("OnClick", function(self)
        if row.__addonName then
            A:ShowAddonCategoryMenu(self, row.__addonName)
        end
    end)

    row:SetScript("OnClick", function(self, mouseButton)
        if self.__addonName then
            if mouseButton == "RightButton" then
                A:ShowAddonCategoryMenu(self, self.__addonName)
            end
            return
        end

        if not self.__categoryKey then return end
        if mouseButton == "RightButton" then
            -- The synthetic bucket is not a real category, so it has nothing to
            -- rename, nest or delete.
            if self.__categoryKey ~= UNCATEGORISED_KEY then
                A:ShowCategoryMenu(self, self.__categoryKey, self.name:GetText())
            end
            return
        end
        A:ToggleCategoryCollapsed(self.__categoryKey)
        A:RefreshUI()
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.expander:SetScript("OnClick", function()
        if row.__categoryKey then
            A:ToggleCategoryCollapsed(row.__categoryKey)
            A:RefreshUI()
        end
    end)

    Colored(row.name, theme and theme.text)
    return row
end

-- ==========================================
-- ASSIGNING CATEGORIES
-- ==========================================
local function TagPrompt(addonName)
    A:Prompt(
        "Categories for " .. addonName .. " (comma-separated):",
        A:CategorySetToDisplayString(A:GetAddonCategorySet(addonName)),
        function(value)
            A:SetAddonCategories(addonName, A:ParseCategoryNamesToSet(value))
            A:RefreshUI()
        end
    )
end

local function ToggleAddonCategory(addonName, categoryKey)
    if A:GetAddonCategorySet(addonName)[categoryKey] then
        A:UnassignAddonFromCategory(addonName, categoryKey)
    else
        A:AssignAddonToCategory(addonName, categoryKey)
    end
    A:RefreshUI()
end

-- The discoverable path for assignment: right-click a row, or click its Tags
-- button. Dragging onto the rail is the shortcut, not the only route.
function A:ShowAddonCategoryMenu(anchor, addonName)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        TagPrompt(addonName)
        return
    end

    MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
        if rootDescription.CreateTitle then
            rootDescription:CreateTitle(addonName)
        end

        local rows = A:GetCategoryTree(true)
        for _, row in ipairs(rows) do
            local categoryKey = row.key
            local label = string.rep("    ", row.depth or 0) .. row.name
            if rootDescription.CreateCheckbox then
                rootDescription:CreateCheckbox(label, function()
                    return A:GetAddonCategorySet(addonName)[categoryKey] == true
                end, function()
                    ToggleAddonCategory(addonName, categoryKey)
                end)
            else
                local mark = A:GetAddonCategorySet(addonName)[categoryKey] and "[x] " or "[  ] "
                rootDescription:CreateButton(mark .. label, function()
                    ToggleAddonCategory(addonName, categoryKey)
                end)
            end
        end

        if #rows > 0 and rootDescription.CreateDivider then
            rootDescription:CreateDivider()
        end

        rootDescription:CreateButton("New category…", function()
            A:Prompt("New category name:", "", function(value)
                if A.Trim(value) == "" then return end
                local createdKey = A:CreateCategory(value)
                if createdKey then
                    A:AssignAddonToCategory(addonName, createdKey)
                end
                A:RefreshUI()
            end)
        end)
        rootDescription:CreateButton("Edit as text…", function()
            TagPrompt(addonName)
        end)
    end)
end

-- Category data is read once per refresh and cached on the frame. Reading it per
-- addon meant one storage round-trip and one DeepCopy for every row, on every
-- scroll tick and every frame of a resize drag.
local function CachedCategories(f)
    return f.__categories or {}
end

local function CachedCategorySet(f, addonName)
    local set = (f.__categoryMap or {})[addonName]
    return type(set) == "table" and set or nil
end

local function ChipText(f, addonName)
    local categorySet = CachedCategorySet(f, addonName)
    if not categorySet then
        return ""
    end

    local categories = CachedCategories(f)
    local keys = A.SortedKeys(categorySet)
    if #keys == 0 then
        return ""
    end

    local parts = {}
    for index = 1, math.min(#keys, MAX_CHIPS) do
        local key = keys[index]
        local category = categories[key]
        local label = (type(category) == "table" and category.name) or key
        parts[#parts + 1] = "|cff" .. ChipHex(key) .. label .. "|r"
    end
    if #keys > MAX_CHIPS then
        parts[#parts + 1] = "+" .. tostring(#keys - MAX_CHIPS)
    end
    return table.concat(parts, "  ")
end

local function BindHeaderRow(row, entry)
    local theme = Theme()
    row.__addonName = nil
    row.__categoryKey = entry.key
    row.__sourceCategory = nil
    row.__reason = nil
    row.__dropTarget = entry.key == UNCATEGORISED_KEY and "uncategorised" or "category"
    row.dropInto:Hide()
    row.dropLine:Hide()

    local indent = 4 + (entry.depth or 0) * INDENT_PER_DEPTH
    row.check:Hide()
    row.chips:SetText("")
    row.tagButton:Hide()
    row.stripe:SetColorTexture(0, 0, 0, 0)

    row.expander:ClearAllPoints()
    row.expander:SetPoint("LEFT", indent, 0)
    row.expander.label:SetText(entry.collapsed and "+" or "-")
    row.expander:SetShown(entry.key ~= nil)

    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", indent + 20, 0)
    row.name:SetWidth(320)
    row.name:SetText(entry.name .. "   |cff8a86a6" .. tostring(entry.count or 0) .. "|r")
    Colored(row.name, theme and theme.accent)
end

local function BindRow(f, row, entry)
    if entry.kind == "header" then
        BindHeaderRow(row, entry)
        return
    end

    local addon = entry.addon
    local theme = Theme()
    row.__addonName = addon.name
    row.__categoryKey = nil
    -- Which group this row is currently sitting under, so a shift-drag out of it
    -- removes that membership and nothing else. Nil in the ungrouped list.
    row.__sourceCategory = entry.sourceCategory
    row.__reason = nil
    row.__dropTarget = nil
    row.dropInto:Hide()
    row.dropLine:Hide()

    local indent = 4 + (entry.depth or 0) * INDENT_PER_DEPTH
    row.expander:Hide()
    row.check:ClearAllPoints()
    row.check:SetPoint("LEFT", indent, 0)
    row.check:Show()
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.check, "RIGHT", 8, 0)
    row.name:SetWidth(250)

    local enabled = A._AddonAPI.IsEnabled(addon.name) == true
    row.check:SetChecked(enabled)

    local protected, protectReason = A:IsProtectedAddOn(addon.name, addon)
    row.check:SetEnabled(not (addon.security == "SECURE"))

    row.name:SetText(addon.title or addon.name)
    if addon.security == "SECURE" then
        Colored(row.name, theme and theme.textMuted)
        row.__reason = "Blizzard secure addon — managed by the client."
    elseif protected then
        Colored(row.name, theme and theme.accent)
        row.__reason = protectReason
    elseif enabled then
        Colored(row.name, theme and theme.text)
    else
        Colored(row.name, theme and theme.textMuted)
    end

    if A.IsAddOnProblem(addon.loadable, addon.reason) then
        row.__reason = tostring(addon.reason)
        Colored(row.name, theme and theme.warning)
    end

    -- Chips restate what the group header already says, so they only earn their
    -- space in the ungrouped list.
    row.chips:SetText(A.groupByCategory and "" or ChipText(f, addon.name))
    row.tagButton:Show()
    row.stripe:SetColorTexture(0, 0, 0, 0)
end

-- Position and bind only the rows the viewport can show. The pool grows to the
-- window height, never to the addon count, so a 400-addon client costs the same
-- number of frames as a 20-addon one.
local function LayoutRows(f)
    local list = f.display or {}
    local viewHeight = f.scroll:GetHeight() or 0
    local offset = f.scroll:GetVerticalScroll() or 0
    local visibleCount = math.max(1, math.ceil(viewHeight / ROW_H) + 1)
    local firstIndex = math.max(1, math.floor(offset / ROW_H) + 1)

    for index = #f.rows + 1, visibleCount do
        f.rows[index] = BuildRow(f, f.rowContainer)
    end

    for index = 1, #f.rows do
        local row = f.rows[index]
        local dataIndex = firstIndex + index - 1
        local entry = index <= visibleCount and list[dataIndex] or nil
        if entry then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(dataIndex - 1) * ROW_H)
            row:SetPoint("TOPRIGHT", 0, -(dataIndex - 1) * ROW_H)
            BindRow(f, row, entry)
            row:Show()
        else
            row:Hide()
        end
    end

    f.rowContainer:SetHeight(math.max(1, #list * ROW_H))
    f.rowContainer:SetWidth(math.max(1, f.scroll:GetWidth() or 1))
end

-- ==========================================
-- MAIN WINDOW
-- ==========================================
function A:CreateMainWindow()
    if self.frame then return self.frame end
    if not ToolkitReady() then
        if not self._toolkitWarned then
            self._toolkitWarned = true
            self.Print("FabledUI_UIToolkit is unavailable; the Athena window cannot open. Use /athena list, /athena apply <name> or /athena default <name>.")
        end
        return nil
    end

    local TK = Toolkit()
    local theme = Theme()
    local state = LoadWindowState()

    local f = TK.Shell:CreateWindow("FabledUI_AthenaFrame", {
        title = "FabledUI - Athena",
        subtitle = "Right-click an addon (or use Tags) to categorise it · drag onto a group here or in the rail · shift-drag to move it",
        theme = FN_THEME,
        accentColor = FN_ACCENT,
        frameStrata = "DIALOG",
        width = 860,
        height = 580,
        minWidth = 720,
        -- The rail stacks fixed-height sections above the category tree, so the
        -- floor has to leave the tree a usable height rather than a negative one.
        minHeight = 500,
        state = state,
        ribbon = false,
        resizable = true,
        onBoundsChanged = function() SaveWindowStateSoon(state) end,
        onDisplayStateChanged = function() SaveWindowStateSoon(state) end,
        -- Re-layout only. This fires on every frame of a resize drag, so a full
        -- data refresh here would re-read storage continuously.
        onSizeChanged = function()
            if A.frame and A.frame.rowContainer then LayoutRows(A.frame) end
        end,
    })
    if not f then return nil end

    f:SetToplevel(true)
    self.frame = f
    self.filterMode = FILTER_ALL
    self.searchText = ""
    self.groupByCategory = self.Storage:Get("account", { "groupByCategory" }, false) == true
    f.rows = {}

    local content = f.Content

    -- ---------- left rail ----------
    local rail = CreateFrame("Frame", nil, content)
    rail:SetPoint("TOPLEFT")
    rail:SetPoint("BOTTOMLEFT")
    rail:SetWidth(RAIL_WIDTH)
    f.rail = rail

    local railEdge = rail:CreateTexture(nil, "ARTWORK")
    railEdge:SetPoint("TOPRIGHT")
    railEdge:SetPoint("BOTTOMRIGHT")
    railEdge:SetWidth(1)
    Tint(railEdge, theme and theme.border)

    local profileHeading = NewHeading(rail, "Profiles")
    profileHeading:SetPoint("TOPLEFT", 2, -2)

    f.profileList = NewListPanel(rail)
    f.profileList.scroll:SetPoint("TOPLEFT", 0, -20)
    f.profileList.scroll:SetPoint("TOPRIGHT", -22, -20)
    f.profileList.scroll:SetHeight(120)

    local newButton = NewButton(rail, "New profile…", 176, 22, function()
        A:Prompt("New profile name:", "", function(value)
            if A.Trim(value) == "" then return end
            if A:SaveProfile(value) then
                A.selectedProfile = A.Trim(value)
            end
            A:RefreshUI()
        end)
    end)
    newButton:SetPoint("TOPLEFT", 0, -146)

    f.saveButton = NewButton(rail, "Overwrite", 86, 22, function()
        local profileName = A.selectedProfile
        if not profileName then return end
        A:Prompt("Overwrite \"" .. profileName .. "\" with the current addon set?", profileName, function(value)
            if A.Trim(value) ~= "" then
                A:SaveProfile(value)
                A.selectedProfile = A.Trim(value)
                A:RefreshUI()
            end
        end)
    end)
    f.saveButton:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 0, -6)

    f.applyButton = NewButton(rail, "Apply", 86, 22, function()
        local profileName = A.selectedProfile
        if not profileName then return end
        A:ApplyProfile(profileName)
        A:RefreshUI()
        if A._reloadRequired then
            StaticPopup_Show("FABLEDUI_ATHENA_RELOAD_CONFIRM")
        end
    end, true)
    f.applyButton:SetPoint("LEFT", f.saveButton, "RIGHT", 4, 0)

    f.defaultButton = NewButton(rail, "Set as default", 176, 22, function()
        if A.selectedProfile then
            A:SetDefaultProfileForChar(A.selectedProfile)
            A:RefreshUI()
        end
    end)
    f.defaultButton:SetPoint("TOPLEFT", f.saveButton, "BOTTOMLEFT", 0, -6)
    f.defaultButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Set as default")
        GameTooltip:AddLine("Marks this profile as the default for this character only.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.defaultButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local railDivider = NewDivider(rail)
    railDivider:SetPoint("TOPLEFT", 0, -232)
    railDivider:SetPoint("TOPRIGHT", -14, -232)

    local categoryHeading = NewHeading(rail, "Categories")
    categoryHeading:SetPoint("TOPLEFT", 2, -242)

    local newCategoryButton = NewButton(rail, "New category…", 176, 22, function()
        A:Prompt("New category name:", "", function(value)
            if A.Trim(value) ~= "" then
                A:CreateCategory(value)
                A:RefreshUI()
            end
        end)
    end)
    newCategoryButton:SetPoint("TOPLEFT", 0, -260)

    f.categoryList = NewListPanel(rail, NewCategoryButton)
    f.categoryList.owner = f
    f.categoryList.scroll:SetPoint("TOPLEFT", 0, -288)
    f.categoryList.scroll:SetPoint("TOPRIGHT", -22, -288)
    f.categoryList.scroll:SetPoint("BOTTOM", 0, 4)

    -- ---------- right pane ----------
    local pane = CreateFrame("Frame", nil, content)
    pane:SetPoint("TOPLEFT", rail, "TOPRIGHT", 14, 0)
    pane:SetPoint("BOTTOMRIGHT")
    f.pane = pane

    f.search = TK.Components:CreateSearchBox(pane, {
        placeholder = "Search addons…",
        width = 200,
        height = 26,
    })
    f.search:SetPoint("TOPLEFT")
    f.search.editBox:SetScript("OnTextChanged", function(self)
        A.searchText = A.Trim(self:GetText() or ""):lower()
        A:RefreshUI()
    end)

    f.segmented = TK.Components:CreateSegmented(pane, {
        options = { "All", "On", "Off" },
        segWidth = 44,
        height = 26,
        selected = FILTER_ALL,
        onSelect = function(index)
            A.filterMode = index
            A:RefreshUI()
        end,
    })
    f.segmented:SetPoint("LEFT", f.search, "RIGHT", 10, 0)

    f.groupToggle = TK.Components:CreateToggle(pane, {
        text = "Group",
        width = 96,
        height = 26,
        checked = A.groupByCategory == true,
        onToggle = function(state)
            A.groupByCategory = state and true or false
            A.Storage:Set("account", { "groupByCategory" }, A.groupByCategory)
            A:RefreshUI()
        end,
    })
    f.groupToggle:SetPoint("LEFT", f.segmented, "RIGHT", 10, 0)

    -- Lives in the status bar, not the toolbar: at the minimum window width a
    -- toolbar-anchored button overlaps the filters when it appears.
    f.reloadButton = NewButton(f.StatusBar, "Reload UI", 84, 18, function() ReloadUI() end, true)
    f.reloadButton:SetPoint("RIGHT", -8, 0)
    f.reloadButton:Hide()

    local paneDivider = NewDivider(pane)
    paneDivider:SetPoint("TOPLEFT", 0, -34)
    paneDivider:SetPoint("TOPRIGHT", 0, -34)

    f.scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 0, -42)
    f.scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    -- Named rowContainer, not `content`: Shell already owns `frame.Content`.
    f.rowContainer = CreateFrame("Frame", nil, f.scroll)
    f.rowContainer:SetSize(1, 1)
    f.scroll:SetScrollChild(f.rowContainer)
    -- Hook rather than SetScript: the template's own handler drives the bar.
    f.scroll:HookScript("OnVerticalScroll", function() LayoutRows(f) end)
    TidyScrollBar(f.scroll)

    f.prompt = BuildPrompt(f)

    return f
end

-- ==========================================
-- REFRESH
-- ==========================================
local function BuildFilteredList(f)
    local search = A.searchText or ""
    local categoryKey = A.categoryFilter
    local filterMode = A.filterMode or FILTER_ALL

    -- Filtering by a parent includes everything tagged into its descendants --
    -- that is what nesting is for.
    local acceptedCategories = categoryKey and A:GetCategoryDescendants(categoryKey) or nil

    local list, enabledCount, total = {}, 0, 0
    for _, name, title, _, loadable, reason, security in A.IterateAddOns() do
        total = total + 1
        local enabled = A._AddonAPI.IsEnabled(name) == true
        if enabled then enabledCount = enabledCount + 1 end

        local match = true
        if search ~= "" then
            local haystackTitle = (title or name):lower()
            match = haystackTitle:find(search, 1, true) ~= nil
                or name:lower():find(search, 1, true) ~= nil
        end
        if match and acceptedCategories then
            local set = CachedCategorySet(f, name)
            local inCategory = false
            if set then
                for assignedKey, assigned in pairs(set) do
                    if assigned and acceptedCategories[assignedKey] then
                        inCategory = true
                        break
                    end
                end
            end
            match = inCategory
        end
        if match and filterMode == FILTER_ENABLED and not enabled then
            match = false
        end
        if match and filterMode == FILTER_DISABLED and enabled then
            match = false
        end

        if match then
            list[#list + 1] = {
                name = name,
                title = title,
                loadable = loadable,
                reason = reason,
                security = security,
            }
        end
    end

    return list, enabledCount, total
end

-- Turn the matching addons into the rows actually rendered. Ungrouped, that is
-- one entry per addon. Grouped, it is a category header followed by its members,
-- and because categories are tags rather than folders an addon legitimately
-- appears under every category it carries.
local function BuildDisplayList(f, addons)
    if not A.groupByCategory then
        local entries = {}
        for _, addon in ipairs(addons) do
            entries[#entries + 1] = { kind = "addon", addon = addon, depth = 0 }
        end
        return entries
    end

    local collapsed = A:GetCollapsedCategories()
    local accepted = A.categoryFilter and A:GetCategoryDescendants(A.categoryFilter) or nil
    local entries = {}

    for _, row in ipairs(A:GetCategoryTree()) do
        if not accepted or accepted[row.key] then
            local members = {}
            for _, addon in ipairs(addons) do
                local set = CachedCategorySet(f, addon.name)
                if set and set[row.key] then
                    members[#members + 1] = addon
                end
            end

            local isCollapsed = collapsed[row.key] == true
            entries[#entries + 1] = {
                kind = "header",
                key = row.key,
                name = row.name,
                depth = row.depth,
                count = #members,
                collapsed = isCollapsed,
            }
            if not isCollapsed then
                for _, addon in ipairs(members) do
                    entries[#entries + 1] = {
                        kind = "addon",
                        addon = addon,
                        depth = (row.depth or 0) + 1,
                        sourceCategory = row.key,
                    }
                end
            end
        end
    end

    -- Only meaningful when looking at everything; filtering to a category and
    -- then showing what is in no category reads as a bug.
    if not accepted then
        local loose = {}
        for _, addon in ipairs(addons) do
            local set = CachedCategorySet(f, addon.name)
            if not set or not next(set) then
                loose[#loose + 1] = addon
            end
        end

        local isCollapsed = collapsed[UNCATEGORISED_KEY] == true
        entries[#entries + 1] = {
            kind = "header",
            key = UNCATEGORISED_KEY,
            name = "Uncategorised",
            depth = 0,
            count = #loose,
            collapsed = isCollapsed,
        }
        if not isCollapsed then
            for _, addon in ipairs(loose) do
                entries[#entries + 1] = { kind = "addon", addon = addon, depth = 1 }
            end
        end
    end

    return entries
end

-- An inline texture escape, not a glyph. The star and bullet characters are
-- missing from WoW's default fonts and render as tofu boxes -- the same trap the
-- toolkit hit with the dropdown arrow.
local DEFAULT_PROFILE_ICON = "|TInterface\\Common\\FavoritesIcon:14:14:0:0|t"

local function RefreshProfiles(f)
    local profiles = A:ListProfiles()
    local defaultProfile = A:GetDefaultProfileForChar()

    if A.selectedProfile then
        local stillExists = false
        for _, profileName in ipairs(profiles) do
            if profileName == A.selectedProfile then
                stillExists = true
                break
            end
        end
        if not stillExists then A.selectedProfile = nil end
    end

    FillList(f.profileList, profiles, function(button, profileName)
        local isDefault = profileName == defaultProfile
        button.label:SetText((isDefault and (DEFAULT_PROFILE_ICON .. " ") or "") .. profileName)
        button.__tooltipTitle = profileName
        button.__tooltipBody = isDefault and "This character's default profile." or nil
        SetListButtonSelected(button, profileName == A.selectedProfile)
        button:SetScript("OnClick", function()
            A.selectedProfile = profileName
            A:RefreshUI()
        end)
    end, "No profiles yet — use New profile…")

    local hasSelection = A.selectedProfile ~= nil
    f.saveButton:SetEnabled(hasSelection)
    f.applyButton:SetEnabled(hasSelection)
    f.defaultButton:SetEnabled(hasSelection)
end

function A:ShowCategoryMenu(button, categoryKey, categoryName)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(button, function(_, rootDescription)
        rootDescription:CreateButton("Rename…", function()
            A:Prompt("Rename category:", categoryName, function(value)
                if A.Trim(value) ~= "" then
                    A:RenameCategory(categoryKey, value)
                    A:RefreshUI()
                end
            end)
        end)
        rootDescription:CreateButton("New category inside…", function()
            A:Prompt("New category inside \"" .. categoryName .. "\":", "", function(value)
                if A.Trim(value) ~= "" then
                    A:CreateCategory(value, categoryKey)
                    A:SetCategoryCollapsed(categoryKey, false)
                    A:RefreshUI()
                end
            end)
        end)
        rootDescription:CreateButton("Move to top level", function()
            A:MoveCategory(categoryKey, nil, "into")
            A:RefreshUI()
        end)
        rootDescription:CreateButton("Delete", function()
            A:DeleteCategory(categoryKey)
            if A.categoryFilter == categoryKey then
                A.categoryFilter = nil
            end
            A:RefreshUI()
        end)
    end)
end

local function RefreshCategories(f)
    -- An addon tagged into a child counts toward every ancestor, so a collapsed
    -- parent still reports everything filed beneath it.
    local directCounts = {}
    for _, categorySet in pairs(f.__categoryMap or {}) do
        if type(categorySet) == "table" then
            for categoryKey, assigned in pairs(categorySet) do
                if assigned then
                    directCounts[categoryKey] = (directCounts[categoryKey] or 0) + 1
                end
            end
        end
    end

    local rows = A:GetCategoryTree()
    local rolledUpCounts = {}
    for _, row in ipairs(rows) do
        local total = 0
        for descendantKey in pairs(A:GetCategoryDescendants(row.key)) do
            total = total + (directCounts[descendantKey] or 0)
        end
        rolledUpCounts[row.key] = total
    end

    local items = { { key = nil, name = "All addons", depth = 0 } }
    for _, row in ipairs(rows) do
        items[#items + 1] = row
    end

    FillList(f.categoryList, items, function(button, item)
        local indent = 6 + (item.depth or 0) * INDENT_PER_DEPTH
        button.__categoryKey = item.key
        button.__dropTarget = item.key and "category" or "all"

        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", indent + 14, 0)
        button.label:SetPoint("RIGHT", -34, 0)
        button.label:SetText(item.name)

        if item.key then
            button.count:SetText(tostring(rolledUpCounts[item.key] or 0))
        else
            button.count:SetText("")
        end

        if item.hasChildren then
            button.expander:ClearAllPoints()
            button.expander:SetPoint("LEFT", indent - 2, 0)
            button.expander.label:SetText(item.collapsed and "+" or "-")
            button.expander:SetScript("OnClick", function()
                A:ToggleCategoryCollapsed(item.key)
                A:RefreshUI()
            end)
            button.expander:Show()
        else
            button.expander:Hide()
        end

        SetListButtonSelected(button, item.key == A.categoryFilter)

        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                if item.key then
                    A:ShowCategoryMenu(self, item.key, item.name)
                end
                return
            end
            A.categoryFilter = item.key
            A:RefreshUI()
        end)
    end)
end

function A:RefreshUI()
    local f = self.frame
    if not f then return end

    f.__categories = self:GetCategories()
    local map = self.Storage:Get("account", { "addonCategoryMap" }, nil)
    f.__categoryMap = type(map) == "table" and map or {}

    RefreshProfiles(f)
    RefreshCategories(f)

    local list, enabledCount, total = BuildFilteredList(f)
    f.filtered = list
    f.display = BuildDisplayList(f, list)
    LayoutRows(f)

    f.reloadButton:SetShown(self._reloadRequired == true)

    local status = tostring(#list) .. " of " .. tostring(total) .. " shown · "
        .. tostring(enabledCount) .. " enabled"
    if self.selectedProfile then
        status = status .. " · profile: " .. self.selectedProfile
    end
    if self._reloadRequired then
        status = status .. " · |cffffc24breload required|r"
    end
    f:SetShellStatus(status)
end

function A:ToggleMain()
    if not self.frame then
        if not self:CreateMainWindow() then return end
    end

    if self.frame:IsShellVisible() then
        self.frame:HideShell()
        return
    end

    if not self.selectedProfile then
        self.selectedProfile = self:GetDefaultProfileForChar() or self:GetActiveProfile()
    end
    self.frame:ShowExpanded()
    self:RefreshUI()
end
