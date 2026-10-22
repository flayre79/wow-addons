-- The Villa Decor window: every decor item that still pays first-acquisition
-- House XP, cheapest usable vendor first, with what stands in the way of buying
-- it. Pure rendering over FabledUI_VillaDecor.

local Decor = _G.FabledUI_VillaDecor
if not Decor then return end

local Window = {}
Decor.Window = Window

local WIDTH, HEIGHT = 960, 500
local ROW_HEIGHT = 22
local HEADER_Y = -58

-- Fixed columns are measured from the row's right edge; Item takes the rest.
local COLUMNS = {
    { key = "name",   label = "Item",   flex = true },
    { key = "xp",     label = "XP",     width = 36,  right = 650, justify = "RIGHT" },
    { key = "source", label = "Source", width = 176, right = 466, justify = "LEFT" },
    { key = "zone",   label = "Zone",   width = 140, right = 318, justify = "LEFT" },
    { key = "needs",  label = "Needs",  width = 200, right = 110, justify = "LEFT" },
    { key = "cost",   label = "Cost",   width = 100, right = 2,   justify = "RIGHT" },
}
local FLEX_RIGHT_INSET = 650 + 36 + 8

local FACTION_ICON = {
    Alliance = "|TInterface\\FriendsFrame\\PlusManz-Alliance:14:14|t ",
    Horde    = "|TInterface\\FriendsFrame\\PlusManz-Horde:14:14|t ",
}

local STATUS_COLOR = { met = "|cff55dd55", unmet = "|cffff5050", unknown = "|cffffd24a" }
local STATUS_WORD  = { met = "done", unmet = "not yet", unknown = "can't check" }

local function settings()
    return Decor:Settings()
end

local function qualityColored(row)
    local colors = rawget(_G, "ITEM_QUALITY_COLORS")
    local color = colors and row.quality and colors[row.quality]
    if color and color.hex then
        return color.hex .. row.name .. "|r"
    end
    return row.name
end

-- The one line that matters most: the first thing you have not done, else the
-- first thing that could not be checked, else a quiet "cleared".
local function needsText(row)
    local needs = row.needs or {}
    if #needs == 0 then return "" end

    local firstUnmet, firstUnknown, unmet, unknown = nil, nil, 0, 0
    for _, req in ipairs(needs) do
        if req.status == "unmet" then
            unmet = unmet + 1
            firstUnmet = firstUnmet or req
        elseif req.status == "unknown" then
            unknown = unknown + 1
            firstUnknown = firstUnknown or req
        end
    end

    if firstUnmet then
        return STATUS_COLOR.unmet .. firstUnmet.label .. (unmet > 1 and (" +" .. (unmet - 1)) or "") .. "|r"
    end
    if firstUnknown then
        return STATUS_COLOR.unknown .. "? " .. firstUnknown.label .. (unknown > 1 and (" +" .. (unknown - 1)) or "") .. "|r"
    end
    return STATUS_COLOR.met .. "cleared (" .. #needs .. ")|r"
end

local function cellText(row, key)
    if key == "name" then
        return qualityColored(row)
    elseif key == "xp" then
        return "|cffffb81c" .. row.xp .. "|r"
    elseif key == "source" then
        if row.kind == "Vendor" then
            return (FACTION_ICON[row.faction] or "") .. row.sourceName
        end
        return "|cff9d9d9d" .. row.kind .. (row.sourceName ~= "" and (": " .. row.sourceName) or "") .. "|r"
    elseif key == "zone" then
        return row.zone
    elseif key == "needs" then
        return needsText(row)
    elseif key == "cost" then
        return row.costText
    end
    return ""
end

function Window:ShowRowTooltip(rowFrame)
    local row = rowFrame.data
    if not row or not GameTooltip then return end
    GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText(qualityColored(row))
    GameTooltip:AddDoubleLine("First time you collect it", "+" .. row.xp .. " House XP", 0.8, 0.8, 0.8, 1, 0.72, 0.11)

    if #(row.needs or {}) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Needs", 1, 0.82, 0)
        for _, req in ipairs(row.needs) do
            local color = STATUS_COLOR[req.status] or STATUS_COLOR.unknown
            GameTooltip:AddDoubleLine(req.label, color .. (STATUS_WORD[req.status] or "?") .. "|r", 1, 1, 1, 1, 1, 1)
        end
        if row.uncertain then
            GameTooltip:AddLine("Yellow means a requirement is on file but could not be checked from here.", 0.6, 0.6, 0.6, true)
        end
    end

    local Prereqs = Decor.Prereqs
    for _, vendor in ipairs(row.parsed.vendors) do
        GameTooltip:AddLine(" ")
        local side = Prereqs and Prereqs:VendorFaction(vendor.name)
        GameTooltip:AddDoubleLine("Vendor", (FACTION_ICON[side] or "") .. vendor.name, 1, 0.82, 0, 1, 1, 1)
        if #vendor.zones > 0 then
            GameTooltip:AddDoubleLine("Zone", table.concat(vendor.zones, " / "), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if vendor.costText then
            GameTooltip:AddDoubleLine("Cost", vendor.costText, 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    for _, other in ipairs(row.parsed.others) do
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(other.kind, other.name, 1, 0.82, 0, 1, 1, 1)
        if #other.zones > 0 then
            GameTooltip:AddDoubleLine("Zone", table.concat(other.zones, " / "), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    if row.vendor then
        GameTooltip:AddLine("Click for a waypoint to " .. row.vendor.name .. ".", 0.6, 0.85, 1.0)
    else
        GameTooltip:AddLine("Not sold by a vendor.", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function Window:AcquireRow(index)
    local rowFrame = self.rowFrames[index]
    if rowFrame then return rowFrame end

    rowFrame = CreateFrame("Button", nil, self.content)
    rowFrame:SetHeight(ROW_HEIGHT)
    rowFrame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    rowFrame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    local stripe = rowFrame:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.04 or 0)

    local highlight = rowFrame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.12)

    rowFrame.cells = {}
    for _, column in ipairs(COLUMNS) do
        local cell = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell:SetWordWrap(false)
        if column.flex then
            cell:SetPoint("LEFT", rowFrame, "LEFT", 6, 0)
            cell:SetPoint("RIGHT", rowFrame, "RIGHT", -FLEX_RIGHT_INSET, 0)
            cell:SetJustifyH("LEFT")
        else
            cell:SetPoint("RIGHT", rowFrame, "RIGHT", -column.right, 0)
            cell:SetWidth(column.width)
            cell:SetJustifyH(column.justify)
        end
        rowFrame.cells[column.key] = cell
    end

    rowFrame:SetScript("OnEnter", function(f) Window:ShowRowTooltip(f) end)
    rowFrame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    rowFrame:SetScript("OnClick", function(f)
        if not f.data then return end
        local ok, reason = Decor:WaypointTo(f.data)
        if ok then
            Window.status:SetText("|cff55dd55Waypoint set:|r " .. f.data.vendor.name)
        else
            Window.status:SetText("|cffff6060" .. tostring(reason) .. "|r")
        end
    end)

    self.rowFrames[index] = rowFrame
    return rowFrame
end

function Window:UpdateHeaders()
    local s = settings()
    for _, column in ipairs(COLUMNS) do
        local arrow = ""
        if s.sortKey == column.key then
            arrow = s.sortDesc and " v" or " ^"
        end
        self.headers[column.key].label:SetText(column.label .. arrow)
    end
end

function Window:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    local s, meta = settings(), Decor.meta
    self:UpdateHeaders()
    self.vendorOnly:SetChecked(s.vendorOnly)
    self.goldOnly:SetChecked(s.goldOnly)
    self.hideBlocked:SetChecked(s.hideBlocked)
    self.hideUncertain:SetChecked(s.hideUncertain)

    local visible = Decor:GetVisibleRows()
    local visibleXP = 0
    for index, row in ipairs(visible) do
        local rowFrame = self:AcquireRow(index)
        rowFrame.data = row
        for _, column in ipairs(COLUMNS) do
            rowFrame.cells[column.key]:SetText(cellText(row, column.key))
        end
        rowFrame:SetAlpha(row.blocked and 0.55 or 1)
        rowFrame:Show()
        visibleXP = visibleXP + row.xp
    end
    for index = #visible + 1, #self.rowFrames do
        self.rowFrames[index].data = nil
        self.rowFrames[index]:Hide()
    end
    self.content:SetHeight(math.max(1, #visible * ROW_HEIGHT))

    local note
    if meta.scanning then
        note = "Asking the housing catalog..."
    elseif meta.lastError then
        note = "|cffff6060Something failed while reading the catalog.|r The error went to your error catcher; /vdecor status repeats it."
    elseif meta.timedOut then
        note = "|cffff6060The housing catalog did not answer within 10 seconds.|r Press Refresh. If it keeps happening, run /vdecor status and send me what it prints."
    elseif not meta.scanned then
        note = "The housing catalog did not answer. Open the Housing Dashboard's catalog once, then press Refresh."
    elseif meta.total == 0 then
        note = "Nothing left that pays first-acquisition House XP."
    else
        note = string.format("%d shown, worth %d House XP. %d items still pay XP in total (%d XP): %d you cannot buy yet, %d with a requirement that could not be checked%s.",
            #visible, visibleXP, meta.total - meta.shop, meta.totalXP, meta.blocked or 0, meta.uncertain or 0,
            meta.shop > 0 and (", plus " .. meta.shop .. " shop-only (hidden)") or "")
    end
    self.note:SetText(note)
end

-- A scroll child created 1x1 and only ever given a height stays one pixel wide,
-- and every row anchored to its edges goes with it (CLAUDE.md, Frames).
function Window:SyncContentWidth()
    local width = self.scroll:GetWidth()
    if width and width > 0 then
        self.content:SetWidth(width)
    end
end

local function makeCheck(parent, label, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    text:SetText(label)
    check:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return check
end

function Window:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "FabledUI_VillaDecorWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    self.frame = frame

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.05, 0.08, 0.94)

    local titleBar = frame:CreateTexture(nil, "BORDER")
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(26)
    titleBar:SetColorTexture(1, 0.72, 0.11, 0.18)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -7)
    title:SetText("New Decor That Pays House XP")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local function toggle(key)
        return function(checked)
            settings()[key] = checked
            Window:Refresh()
        end
    end

    self.vendorOnly = makeCheck(frame, "Vendor items only", toggle("vendorOnly"))
    self.vendorOnly:SetPoint("TOPLEFT", 8, -30)

    self.goldOnly = makeCheck(frame, "Gold only", toggle("goldOnly"))
    self.goldOnly:SetPoint("TOPLEFT", 160, -30)

    self.hideBlocked = makeCheck(frame, "Hide what I can't buy yet", toggle("hideBlocked"))
    self.hideBlocked:SetPoint("TOPLEFT", 260, -30)

    self.hideUncertain = makeCheck(frame, "Hide unverified requirements", toggle("hideUncertain"))
    self.hideUncertain:SetPoint("TOPLEFT", 460, -30)

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(80, 20)
    refresh:SetPoint("TOPRIGHT", -34, -31)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() Decor:Scan() end)

    -- Column headers double as sort buttons.
    self.headers = {}
    for _, column in ipairs(COLUMNS) do
        local button = CreateFrame("Button", nil, frame)
        button:SetHeight(18)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label = label
        if column.flex then
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, HEADER_Y)
            button:SetWidth(120)
            label:SetPoint("LEFT")
        else
            button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(column.right + 30), HEADER_Y)
            button:SetWidth(column.width)
            label:SetPoint(column.justify)
        end
        button:SetScript("OnClick", function() Decor:SetSort(column.key) end)
        self.headers[column.key] = button
    end

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 8, HEADER_Y - 20)
    divider:SetPoint("TOPRIGHT", -8, HEADER_Y - 20)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.15)

    self.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", 8, HEADER_Y - 24)
    self.scroll:SetPoint("BOTTOMRIGHT", -30, 58)
    self.content = CreateFrame("Frame", nil, self.scroll)
    self.content:SetSize(WIDTH - 38, 1)
    self.scroll:SetScrollChild(self.content)
    self.scroll:SetScript("OnSizeChanged", function() Window:SyncContentWidth() end)
    self.rowFrames = {}

    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.status:SetPoint("BOTTOMLEFT", 10, 38)
    self.status:SetPoint("BOTTOMRIGHT", -10, 38)
    self.status:SetJustifyH("LEFT")

    self.note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.note:SetPoint("BOTTOMLEFT", 10, 8)
    self.note:SetPoint("BOTTOMRIGHT", -10, 8)
    self.note:SetJustifyH("LEFT")
    self.note:SetWordWrap(true)

    frame:SetScript("OnShow", function()
        Window:SyncContentWidth()
        Window.status:SetText("")
        Decor:SetWatching(true)
        Window:Refresh()
    end)
    frame:SetScript("OnHide", function() Decor:SetWatching(false) end)

    -- Escape closes it.
    local specialFrames = rawget(_G, "UISpecialFrames")
    if type(specialFrames) == "table" then
        table.insert(specialFrames, "FabledUI_VillaDecorWindow")
    end

    Decor:RegisterCallback(self, function() Window:Refresh() end)
    return frame
end

function Window:Toggle()
    local frame = self:Build()
    frame:SetShown(not frame:IsShown())
end
