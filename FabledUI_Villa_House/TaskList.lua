-- VillaHouse's endeavor task window: every task you can do right now, with the
-- banner number beside what it will really pay, sortable and filterable.
-- Pure rendering over VillaHouse.Tasks; this file makes no game API calls.

local VillaHouse = _G.FabledUI_Villa_House
if not VillaHouse then return end

local Tasks = VillaHouse.Tasks
local TaskList = {}
VillaHouse.TaskList = TaskList

local WIDTH, HEIGHT = 540, 440
local ROW_HEIGHT = 22
local HEADER_Y = -58

-- Right-aligned numeric columns, measured from the row's right edge.
local COLUMNS = {
    { key = "name",    label = "Task",    align = "LEFT" },
    { key = "done",    label = "Done",    width = 50, right = 210 },
    { key = "banner",  label = "Banner",  width = 60, right = 145 },
    { key = "xp",      label = "Real XP", width = 70, right = 70 },
    { key = "coupons", label = "Coupons", width = 64, right = 2 },
}

local function settings()
    return Tasks:Settings()
end

local function cellText(row, key)
    if key == "name" then
        return (row.tracked and "|cffffd100*|r " or "") .. row.name
    elseif key == "done" then
        if row.finished then return "|cff55dd55done|r" end
        return row.timesCompleted > 0 and ("x" .. row.timesCompleted) or ""
    elseif key == "banner" then
        return tostring(row.banner)
    elseif key == "xp" then
        if row.pending or row.xp == nil then return "|cff888888...|r" end
        if row.capped then return "|cffff6060" .. row.xp .. " cap|r" end
        if row.xp < row.banner then return "|cffffb81c" .. row.xp .. "|r" end
        return tostring(row.xp)
    elseif key == "coupons" then
        if row.pending or row.coupons == nil then return "|cff888888...|r" end
        return row.coupons > 0 and tostring(row.coupons) or ""
    end
    return ""
end

function TaskList:ShowRowTooltip(rowFrame)
    local row = rowFrame.data
    if not row or not GameTooltip then return end
    GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.name, 1, 0.82, 0)
    if row.repeatable then
        GameTooltip:AddLine(row.timesCompleted > 0
            and ("Repeatable, completed x" .. row.timesCompleted) or "Repeatable", 0.6, 0.85, 1.0)
    end
    if row.description ~= "" then
        GameTooltip:AddLine(row.description, 1, 1, 1, true)
    end
    for _, req in ipairs(row.requirements) do
        if req.completed then
            GameTooltip:AddLine("- " .. req.text, 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("- " .. req.text, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Banner shows", tostring(row.banner), 0.8, 0.8, 0.8, 1, 1, 1)
    if row.pending or row.xp == nil then
        GameTooltip:AddDoubleLine("Next completion pays", "loading...", 0.8, 0.8, 0.8, 0.6, 0.6, 0.6)
    else
        GameTooltip:AddDoubleLine("Next completion pays", row.xp .. " House XP", 0.8, 0.8, 0.8, 1, 0.72, 0.11)
        if row.capped then
            GameTooltip:AddLine("Cut by the House XP cap. Uncapped it would pay " .. tostring(row.xpUncapped) .. ".", 1, 0.4, 0.4, true)
        end
        if row.coupons and row.coupons > 0 then
            GameTooltip:AddDoubleLine("Community Coupons", tostring(row.coupons), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    if not row.finished then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(row.tracked and "Click to stop tracking." or "Click to track.", 0.6, 0.85, 1.0)
    end
    GameTooltip:Show()
end

function TaskList:AcquireRow(index)
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
        if column.align == "LEFT" then
            cell:SetPoint("LEFT", rowFrame, "LEFT", 6, 0)
            cell:SetPoint("RIGHT", rowFrame, "RIGHT", -(COLUMNS[2].right + COLUMNS[2].width + 6), 0)
            cell:SetJustifyH("LEFT")
            cell:SetWordWrap(false)
        else
            cell:SetPoint("RIGHT", rowFrame, "RIGHT", -column.right, 0)
            cell:SetWidth(column.width)
            cell:SetJustifyH("RIGHT")
        end
        rowFrame.cells[column.key] = cell
    end

    rowFrame:SetScript("OnEnter", function(f) TaskList:ShowRowTooltip(f) end)
    rowFrame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    rowFrame:SetScript("OnClick", function(f)
        if f.data then Tasks:ToggleTracked(f.data) end
    end)

    self.rowFrames[index] = rowFrame
    return rowFrame
end

function TaskList:UpdateHeaders()
    local s = settings()
    for _, column in ipairs(COLUMNS) do
        local button = self.headers[column.key]
        local arrow = ""
        if s.sortKey == column.key then
            arrow = s.sortDesc and " v" or " ^"
        end
        button.label:SetText(column.label .. arrow)
    end
end

function TaskList:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    local meta = Tasks.meta
    self.title:SetText(meta.title and ("Endeavor Tasks - " .. meta.title) or "Endeavor Tasks")
    self:UpdateHeaders()
    self.hideFinished:SetChecked(settings().hideFinished)
    self.repeatableOnly:SetChecked(settings().repeatableOnly)

    local visible = meta.loaded and Tasks:GetVisibleRows() or {}
    for index, row in ipairs(visible) do
        local rowFrame = self:AcquireRow(index)
        rowFrame.data = row
        for _, column in ipairs(COLUMNS) do
            rowFrame.cells[column.key]:SetText(cellText(row, column.key))
        end
        rowFrame:SetAlpha(row.finished and 0.5 or 1)
        rowFrame:Show()
    end
    for index = #visible + 1, #self.rowFrames do
        self.rowFrames[index].data = nil
        self.rowFrames[index]:Hide()
    end
    self.content:SetHeight(math.max(1, #visible * ROW_HEIGHT))

    local note
    if not meta.loaded then
        note = "No endeavor data yet. It fills in a moment after the game answers; if it stays empty, open the Housing Dashboard's Endeavors tab once."
    elseif #visible == 0 then
        note = "Nothing matches the filters."
    elseif not meta.scaled then
        note = "This client has no reward-scaling call, so Real XP is the base value."
    else
        note = "Real XP is what the next completion pays. Gold means it has dropped below the banner."
    end
    self.note:SetText(note)
end

-- A scroll child created 1x1 and only ever given a height stays one pixel wide,
-- and every row anchored to its edges goes with it (CLAUDE.md, Frames).
function TaskList:SyncContentWidth()
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
    check.labelText = text
    check:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return check
end

function TaskList:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "FabledUI_VillaHouseTaskList", UIParent)
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

    self.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.title:SetPoint("TOPLEFT", 10, -7)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    self.hideFinished = makeCheck(frame, "Hide finished", function(checked)
        settings().hideFinished = checked
        TaskList:Refresh()
    end)
    self.hideFinished:SetPoint("TOPLEFT", 8, -30)

    self.repeatableOnly = makeCheck(frame, "Repeatable only", function(checked)
        settings().repeatableOnly = checked
        TaskList:Refresh()
    end)
    self.repeatableOnly:SetPoint("TOPLEFT", 130, -30)

    -- Column headers double as sort buttons.
    self.headers = {}
    for _, column in ipairs(COLUMNS) do
        local button = CreateFrame("Button", nil, frame)
        button:SetHeight(18)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label = label
        if column.align == "LEFT" then
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, HEADER_Y)
            button:SetWidth(120)
            label:SetPoint("LEFT")
        else
            button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(column.right + 32), HEADER_Y)
            button:SetWidth(column.width)
            label:SetPoint("RIGHT")
        end
        button:SetScript("OnClick", function() Tasks:SetSort(column.key) end)
        self.headers[column.key] = button
    end

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 8, HEADER_Y - 20)
    divider:SetPoint("TOPRIGHT", -8, HEADER_Y - 20)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.15)

    self.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", 8, HEADER_Y - 24)
    self.scroll:SetPoint("BOTTOMRIGHT", -30, 44)
    self.content = CreateFrame("Frame", nil, self.scroll)
    self.content:SetSize(WIDTH - 38, 1)
    self.scroll:SetScrollChild(self.content)
    self.scroll:SetScript("OnSizeChanged", function() TaskList:SyncContentWidth() end)
    self.rowFrames = {}

    self.note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.note:SetPoint("BOTTOMLEFT", 10, 8)
    self.note:SetPoint("BOTTOMRIGHT", -10, 8)
    self.note:SetJustifyH("LEFT")
    self.note:SetWordWrap(true)

    frame:SetScript("OnShow", function()
        TaskList:SyncContentWidth()
        Tasks:SetWatching(true)
        TaskList:Refresh()
    end)
    frame:SetScript("OnHide", function() Tasks:SetWatching(false) end)

    -- Escape closes it.
    local specialFrames = rawget(_G, "UISpecialFrames")
    if type(specialFrames) == "table" then
        table.insert(specialFrames, "FabledUI_VillaHouseTaskList")
    end

    Tasks:RegisterCallback(self, function() TaskList:Refresh() end)
    return frame
end

function TaskList:Toggle()
    local frame = self:Build()
    frame:SetShown(not frame:IsShown())
end
