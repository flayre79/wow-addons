local Villa = _G.FabledUI_Villa
local UI = {}
Villa.UI = UI
Villa:RegisterModule("UI", UI)

local T = rawget(_G, "FabledUI_UIToolkit")
UI.Toolkit = T
-- Villa now wears the suite's signature FableNeon skin: deep indigo ground,
-- electric-cyan primary accent (#3AE9FF), arcane-purple secondary (#B45CFF).
-- The palette is resolved from the shared UIToolkit theme at load so Villa
-- stays in lock-step with the rest of the suite; the literals below are the
-- fallback if the toolkit is somehow unavailable (Villa hard-depends on it, so
-- this is belt-and-suspenders).
UI.Theme = "FableNeon"

local function copy(c, aOverride)
    if type(c) ~= "table" then return { 1, 1, 1, 1 } end
    return { c[1] or 1, c[2] or 1, c[3] or 1, aOverride or (c[4] == nil and 1 or c[4]) }
end

-- FableNeon fallbacks (mirror FabledUI_UIToolkit/Themes.lua PRESETS.FableNeon).
local FN = {
    background   = { 0.031, 0.027, 0.059, 0.965 },
    surface      = { 0.070, 0.063, 0.118, 0.975 },
    surfaceRaised= { 0.090, 0.075, 0.153, 0.985 },
    border       = { 0.360, 0.310, 0.620, 0.34 },
    borderStrong = { 0.227, 0.882, 1.000, 0.50 },
    accent       = { 0.227, 0.914, 1.000, 1.0 },
    accent2      = { 0.706, 0.361, 1.000, 1.0 },
    text         = { 0.925, 0.922, 0.980, 1.0 },
    textMuted    = { 0.612, 0.600, 0.761, 1.0 },
    success      = { 0.361, 0.941, 0.627, 1.0 },
    warning      = { 1.000, 0.761, 0.294, 1.0 },
    danger       = { 1.000, 0.302, 0.416, 1.0 },
    spectrum     = {
        cyan   = { 0.227, 0.914, 1.000, 1.0 },
        purple = { 0.706, 0.361, 1.000, 1.0 },
        pink   = { 1.000, 0.353, 0.651, 1.0 },
        green  = { 0.361, 0.941, 0.627, 1.0 },
        amber  = { 1.000, 0.761, 0.294, 1.0 },
        azure  = { 0.357, 0.616, 1.000, 1.0 },
    },
}

-- Resolve the live theme tokens (falls back to FN literals).
local tok = FN
if T and T.Themes and type(T.Themes.Resolve) == "function" then
    local ok, resolved = pcall(function() return T.Themes:Resolve("FableNeon") end)
    if ok and type(resolved) == "table" then
        tok = resolved
    end
end

-- ── Semantic palette (named slots the whole addon references) ────────────────
UI.Accent      = copy(tok.accent, 1.0)          -- electric cyan  #3AE9FF (primary)
UI.Accent2     = copy(tok.accent2, 1.0)         -- arcane purple  #B45CFF (secondary)
UI.AccentSoft  = copy(tok.accent, 0.16)
UI.Accent2Soft = copy(tok.accent2, 0.16)
UI.PanelBG     = copy(tok.surface, 0.96)
UI.PanelBorder = copy(tok.border, 0.85)         -- visible purple structure edge
UI.InsetBG     = copy(tok.background, 0.95)      -- darker recessed wells
UI.InsetBorder = copy(tok.border, 0.65)
UI.RowBG       = copy(tok.surfaceRaised, 0.90)
UI.RowBorder   = copy(tok.border, 0.55)
UI.RowSelBG    = copy(tok.accent, 0.10)          -- selected-row cyan wash
UI.RowSelBorder= copy(tok.accent, 0.55)
UI.Text        = copy(tok.text, 1.0)
UI.TextMuted   = copy(tok.textMuted, 1.0)
UI.Success     = copy(tok.success, 1.0)
UI.Warning     = copy(tok.warning, 1.0)
UI.Danger      = copy(tok.danger, 1.0)
UI.BorderStrong= copy(tok.borderStrong, 0.85)
UI.Spectrum    = tok.spectrum or FN.spectrum

local function unpackColor(color)
    return color[1], color[2], color[3], color[4]
end
UI.Unpack = unpackColor

-- Spectrum lookup by name (cyan/purple/pink/green/amber/azure) → falls back to accent.
function UI:SpectrumColor(name)
    local s = self.Spectrum or FN.spectrum
    return (s and s[name]) or self.Accent
end

local function EnsureBackdrop(frame)
    if not frame.SetBackdrop then
        return false
    end
    if not frame.GetBackdrop or not frame:GetBackdrop() then
        frame:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end
    return true
end

function UI:ApplyBackdrop(frame, bg, border)
    if not frame or not EnsureBackdrop(frame) then
        return
    end
    frame:SetBackdropColor(unpackColor(bg or self.PanelBG))
    frame:SetBackdropBorderColor(unpackColor(border or self.PanelBorder))
end

-- ── Neon flourishes (guarded; no-op if the Effects layer is missing) ─────────
-- A 2px cyan→purple gradient seam pinned to the bottom of `anchor` (or the top
-- of `frame` when no anchor is given). This is the signature FableNeon detail.
function UI:AddNeonSeam(frame, anchor)
    if not frame or not frame.CreateTexture then return end
    local seam = frame.__villaSeam
    if not seam then
        seam = frame:CreateTexture(nil, "OVERLAY")
        seam:SetTexture("Interface/Buttons/WHITE8x8")
        seam:SetHeight(2)
        frame.__villaSeam = seam
    end
    seam:ClearAllPoints()
    if anchor then
        seam:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 1, -1)
        seam:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, -1)
    else
        seam:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        seam:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    end
    if seam.SetGradient and CreateColor then
        seam:SetColorTexture(1, 1, 1, 1)
        seam:SetGradient("HORIZONTAL",
            CreateColor(unpackColor(self.Accent)),
            CreateColor(unpackColor(self.Accent2)))
    else
        seam:SetColorTexture(unpackColor(self.Accent))
    end
    return seam
end

-- Soft outer purple halo around a top-level panel via the toolkit Effects layer.
function UI:AddGlow(frame, color, size, alpha)
    if not frame then return end
    local fx = self.Toolkit and self.Toolkit.Effects
    if fx and type(fx.AddOuterGlow) == "function" then
        pcall(fx.AddOuterGlow, fx, frame, color or self.Accent2, size or 20, alpha or 0.30)
    end
end

function UI:CreatePanelFrame(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetAllPoints(parent)
    self:ApplyBackdrop(frame, self.PanelBG, self.PanelBorder)
    return frame
end

function UI:CreateCard(parent, width, titleText)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width or 128, 58)
    self:ApplyBackdrop(box, self.InsetBG, self.PanelBorder)
    -- Signature top seam on every stat card.
    self:AddNeonSeam(box)

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetPoint("RIGHT", box, "RIGHT", -12, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(unpackColor(self.TextMuted))
    title:SetText(titleText or "")
    box.title = title

    local value = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    value:SetPoint("BOTTOMLEFT", 12, 8)
    value:SetPoint("RIGHT", box, "RIGHT", -12, 8)
    value:SetJustifyH("LEFT")
    value:SetTextColor(unpackColor(self.Accent))
    value:SetText("0")
    box.value = value
    return box
end

function UI:CreateInsetRow(parent, height)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(height or 32)
    self:ApplyBackdrop(row, self.InsetBG, self.InsetBorder)
    return row
end

function UI:CreateScrollRegion(parent, topOffset, bottomOffset)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, topOffset or -134)
    scroll:SetPoint("BOTTOMRIGHT", -30, bottomOffset or 34)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    return scroll, content
end

-- ---------------------------------------------------------------------------
-- Row pooling for list panels
-- ---------------------------------------------------------------------------
-- The list panels used to CreateFrame() one Button plus two FontStrings per
-- entry on every Refresh -- and Refresh runs on every search keystroke. On the
-- Catalog panel that was ~1500 frame creations per character typed. Worse, the
-- previous rows were released with SetParent(nil), which orphans them without
-- reclaiming anything: WoW frames cannot be destroyed, so the only correct
-- pattern is to keep them and rebind. After the first build these create nothing.
--
-- The title/subtitle anchoring lives here because all three panel files had it
-- duplicated verbatim -- which is precisely how a missing content:SetWidth()
-- survived in triplicate and blanked every one of those lists.
--
-- `owner` is the panel module; it must already have `owner.content` (the scroll
-- child) built by its InitUI.
function UI:AcquireListRow(owner, index, width, height)
    owner.rows = owner.rows or {}
    local row = owner.rows[index]

    if not row then
        row = CreateFrame("Button", nil, owner.content, "BackdropTemplate")

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -7)
        title:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        title:SetJustifyH("LEFT")
        row.Title = title

        local subtitle = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        subtitle:SetPoint("BOTTOMLEFT", 10, 7)
        subtitle:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        subtitle:SetJustifyH("LEFT")
        row.Subtitle = subtitle

        -- Style once, at creation, BEFORE the caller applies its own per-row
        -- backdrop and selection colours. StyleButton stamps __fabledStyled and
        -- early-outs afterwards, so the caller's colours survive every refresh.
        --
        -- Previously rows were rebuilt each pass and StyleDescendants styled them
        -- *after* the panel set its colours, overwriting the selection highlight
        -- every time -- which is why selection never visibly worked on these
        -- panels while Vendors (which doesn't restyle in Refresh) was fine.
        self:StyleButton(row)

        owner.rows[index] = row
    end

    row:SetSize(width, height)
    row:ClearAllPoints()   -- caller re-anchors; stale anchors would stack rows
    row:Show()
    return row
end

-- Hide pooled rows past the last one used this pass. They stay allocated for the
-- next refresh rather than being orphaned.
function UI:ReleaseListRows(owner, usedCount)
    if not owner or not owner.rows then return end
    for i = (usedCount or 0) + 1, #owner.rows do
        local row = owner.rows[i]
        if row then row:Hide() end
    end
end

-- ---------------------------------------------------------------------------
-- Virtualised list
-- ---------------------------------------------------------------------------
-- Why this exists rather than a ScrollFrame with every row realised:
--
-- A ScrollFrame's scroll child must be rowHeight * #entries tall. Past roughly
-- 32,000px the client stops drawing the child's contents entirely -- the frames
-- are there, correctly sized, correctly anchored, alpha 1, and simply are not
-- rendered. Measured on this addon:
--
--   Vendors      439 rows -> 30,730px -> renders
--   Professions 1260 rows -> 57,960px -> blank
--   Catalog     1507 rows -> 69,322px -> blank
--
-- Identical row code in all three; only the child height differs.
--
-- So the list is windowed instead: a viewport the size of the visible area, a
-- slider for position, and only enough rows to fill the viewport. The tallest
-- frame is now the viewport itself, so entry count no longer affects rendering
-- at all, and refresh cost stops scaling with #entries -- which also retires the
-- old behaviour of rebuilding ~1500 frames on every search keystroke.
--
-- opts.rowHeight  pixel height per row (default 46)
-- opts.bind       function(row, entry, index, isSelected) -- fills the row
-- opts.onSelect   function(index) -- called on click
local VirtualList = {}
VirtualList.__index = VirtualList

function VirtualList:SetEntries(entries)
    self.entries = entries or {}
    if self.selectedIndex > #self.entries then self.selectedIndex = 1 end
    self:UpdateRange()
    self:Render()
end

function VirtualList:GetSelected()
    return self.entries[self.selectedIndex]
end

function VirtualList:UpdateRange()
    local height = self.viewport:GetHeight() or 0
    -- +1 so a partially visible row at the bottom still draws.
    self.visibleCount = math.max(1, math.floor(height / self.rowHeight) + 1)

    local overflow = #self.entries - self.visibleCount
    if overflow > 0 then
        self.slider:SetMinMaxValues(1, overflow + 1)
        self.slider:Show()
    else
        self.slider:SetMinMaxValues(1, 1)
        self.slider:Hide()
    end

    local maxFirst = math.max(1, #self.entries - self.visibleCount + 1)
    self.first = math.min(math.max(self.first or 1, 1), maxFirst)
    self.slider:SetValue(self.first)
end

function VirtualList:Render()
    local used = 0
    local width = math.max(120, (self.viewport:GetWidth() or 400) - 20)

    for slot = 1, self.visibleCount do
        local index = self.first + slot - 1
        local entry = self.entries[index]
        if not entry then break end

        local row = UI:AcquireListRow(self, slot, width, self.rowHeight - 4)
        row:SetPoint("TOPLEFT", self.viewport, "TOPLEFT", 0, -((slot - 1) * self.rowHeight))
        row:SetScript("OnClick", function()
            self.selectedIndex = index
            if self.onSelect then self.onSelect(index) end
        end)

        if self.bind then self.bind(row, entry, index, index == self.selectedIndex) end
        used = slot
    end

    UI:ReleaseListRows(self, used)
end

function VirtualList:ScrollBy(delta)
    self.first = (self.first or 1) + delta
    self:UpdateRange()
    self:Render()
end

-- `parent` must already be sized/anchored; the list fills it.
function UI:CreateVirtualList(parent, opts)
    opts = opts or {}

    local list = setmetatable({}, VirtualList)
    list.rowHeight     = opts.rowHeight or 46
    list.bind          = opts.bind
    list.onSelect      = opts.onSelect
    list.entries       = {}
    list.rows          = {}
    list.first         = 1
    list.selectedIndex = 1
    list.visibleCount  = 1

    local viewport = CreateFrame("Frame", nil, parent)
    viewport:SetAllPoints(parent)
    list.viewport = viewport
    -- AcquireListRow parents rows to owner.content, so point it at the viewport.
    list.content = viewport

    -- A bare Slider rather than UIPanelScrollBarTemplate: that template's
    -- up/down buttons resolve through $parent, which breaks on unnamed frames.
    local slider = CreateFrame("Slider", nil, viewport)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(12)
    slider:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", 0, -2)
    slider:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", 0, 2)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.05, 0.06, 0.11, 0.75)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.42, 0.37, 0.72, 0.95)
    thumb:SetSize(12, 44)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnValueChanged", function(_, value)
        local v = math.floor(value + 0.5)
        if v ~= list.first then
            list.first = v
            list:Render()
        end
    end)
    list.slider = slider

    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(_, delta)
        list:ScrollBy(delta > 0 and -3 or 3)
    end)

    return list
end

function UI:StyleButton(button)
    if not button or button.__fabledStyled then
        return
    end
    if self.Toolkit and self.Toolkit.Themes and self.Toolkit.Themes.StyleFlatButton then
        pcall(self.Toolkit.Themes.StyleFlatButton, self.Toolkit.Themes, button, self.Theme, self.Accent)
        -- Recolor default gold/white template text to theme ink + hover glow.
        local fs = button.GetFontString and button:GetFontString()
        if fs and self.Toolkit.Themes.ApplyBodyText then
            pcall(self.Toolkit.Themes.ApplyBodyText, self.Toolkit.Themes, fs, self.Theme, self.Accent, false)
        end
        local fx = self.Toolkit.Effects
        if fx and type(fx.StyleNeonButton) == "function" then
            pcall(fx.StyleNeonButton, fx, button, self.Theme, self.Accent)
        end
    elseif button.SetBackdrop then
        self:ApplyBackdrop(button, self.InsetBG, self.PanelBorder)
        if button.SetNormalFontObject then
            button:SetNormalFontObject("GameFontHighlightSmall")
            button:SetHighlightFontObject("GameFontHighlightSmall")
            button:SetDisabledFontObject("GameFontDisableSmall")
        end
    end
    button.__fabledStyled = true
end

function UI:StyleEditBox(editBox)
    if not editBox or editBox.__fabledStyled then
        return
    end
    if editBox.SetBackdrop then
        self:ApplyBackdrop(editBox, { 0.04, 0.05, 0.09, 0.96 }, self.InsetBorder)
    end
    editBox.__fabledStyled = true
end

function UI:StyleBackdropFrame(frame, kind)
    if not frame or frame.__fabledBackdropStyled or not frame.SetBackdrop then
        return
    end
    if kind == "row" then
        self:ApplyBackdrop(frame, self.RowBG, self.RowBorder)
    elseif kind == "inset" then
        self:ApplyBackdrop(frame, self.InsetBG, self.InsetBorder)
    else
        self:ApplyBackdrop(frame, self.PanelBG, self.PanelBorder)
    end
    frame.__fabledBackdropStyled = true
end

local function StyleChildrenRecursive(self, frame, depth)
    if not frame or depth > 4 then
        return
    end

    if frame:IsObjectType("Button") then
        self:StyleButton(frame)
    elseif frame:IsObjectType("EditBox") then
        self:StyleEditBox(frame)
    elseif frame:IsObjectType("Frame") and frame.SetBackdrop then
        self:StyleBackdropFrame(frame, depth > 1 and "row" or nil)
    end

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        StyleChildrenRecursive(self, child, depth + 1)
    end
end

function UI:StyleDescendants(frame)
    StyleChildrenRecursive(self, frame, 0)
end

function UI:ApplyButtonState(button, selected)
    if not button then
        return
    end
    self:StyleButton(button)
    if selected then
        button:SetNormalFontObject("GameFontHighlightSmall")
    else
        button:SetNormalFontObject("GameFontNormalSmall")
    end
end

function UI:GetAccentColor()
    return self.Accent
end

function UI:GetAccent2Color()
    return self.Accent2
end
