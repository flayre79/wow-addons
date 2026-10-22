local Villa = _G.FabledUI_Villa
local Notes = {}
Villa.Notes = Notes
Villa:RegisterModule("Notes", Notes)

-- ============================================================
-- Data API
-- ============================================================

local function GetDB()
    local db = Villa.db
    if not db then return nil end
    db.itemNotes = db.itemNotes or {}
    return db
end

function Notes:Get(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local db = GetDB()
    if not db then return nil end
    local note = db.itemNotes[itemID]
    return (note and note ~= "") and note or nil
end

function Notes:Set(itemID, text)
    itemID = tonumber(itemID)
    if not itemID then return end
    local db = GetDB()
    if not db then return end
    if not text or text == "" then
        db.itemNotes[itemID] = nil
    else
        db.itemNotes[itemID] = text
    end
end

function Notes:Delete(itemID)
    Notes:Set(itemID, nil)
end

function Notes:GetAll()
    local db = GetDB()
    if not db then return {} end
    return db.itemNotes
end

function Notes:ImportCSV(csvText)
    if not csvText or csvText == "" then return 0 end
    local count = 0
    for line in (csvText .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            local idStr, note = line:match("^(%d+)%s*,%s*(.*)$")
            local id = tonumber(idStr)
            if id and note then
                Notes:Set(id, note)
                count = count + 1
            end
        end
    end
    return count
end

function Notes:ExportCSV()
    local db = GetDB()
    if not db then return "" end
    local lines = {}
    local ids   = {}
    for id in pairs(db.itemNotes) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local note = db.itemNotes[id]
        if note and note ~= "" then
            -- Escape commas in note with double-quote wrapping if needed
            if note:find(",") then
                note = '"' .. note:gsub('"', '""') .. '"'
            end
            lines[#lines + 1] = tostring(id) .. "," .. note
        end
    end
    return table.concat(lines, "\n")
end

-- ============================================================
-- Tooltip integration
-- ============================================================

function Notes:HookTooltips()
    if self._tooltipsHooked then return end
    self._tooltipsHooked = true

    local function getItemIDFromLink(itemLink)
        if not itemLink then return nil end
        local id = itemLink:match("item:(%d+)")
        return id and tonumber(id) or nil
    end

    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if not tooltip or not tooltip.GetItem then return end
            local _, itemLink = tooltip:GetItem()
            local itemID = getItemIDFromLink(itemLink)
            if not itemID then return end
            local note = Notes:Get(itemID)
            if note then
                tooltip:AddLine("Note: " .. note, 1.0, 1.0, 0.0, true)
            end
        end)
    end
end

-- ============================================================
-- Note editor popup
-- ============================================================

local noteEditorFrame = nil

local function EnsureNoteEditor()
    if noteEditorFrame then return noteEditorFrame end

    local frame = CreateFrame("Frame", "VillaNoteEditor", UIParent, "BackdropTemplate")
    frame:SetSize(280, 140)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetDragScroll(false)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.10, 0.96)
    frame:SetBackdropBorderColor(0.706, 0.361, 1.000, 0.95)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Item Note")
    frame.Title = title

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", 14, -32)
    editBox:SetPoint("BOTTOMRIGHT", -14, 36)
    editBox:SetAutoFocus(true)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(500)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    frame.EditBox = editBox

    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", -10, 8)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        local id   = frame._itemID
        local text = editBox:GetText():match("^%s*(.-)%s*$")
        if id then
            Notes:Set(id, text)
        end
        frame:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelBtn:SetSize(70, 22)
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    noteEditorFrame = frame
    return frame
end

function Notes:OpenEditor(itemID, anchorFrame)
    itemID = tonumber(itemID)
    if not itemID then return end
    local frame = EnsureNoteEditor()
    frame._itemID = itemID

    local name = (GetItemInfo and GetItemInfo(itemID)) or (C_Item and C_Item.GetItemInfo and (C_Item.GetItemInfo(itemID)))
    frame.Title:SetText("Note: " .. (type(name) == "string" and name or ("Item #" .. tostring(itemID))))
    frame.EditBox:SetText(Notes:Get(itemID) or "")
    frame.EditBox:SetCursorPosition(0)

    if anchorFrame then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
    end
    frame:Show()
    frame.EditBox:SetFocus()
end

-- ============================================================
-- CSV import/export frame
-- ============================================================

local csvFrame = nil

local function EnsureCSVFrame()
    if csvFrame then return csvFrame end

    local frame = CreateFrame("Frame", "VillaNotesCSV", UIParent, "BackdropTemplate")
    frame:SetSize(460, 320)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.10, 0.96)
    frame:SetBackdropBorderColor(0.706, 0.361, 1.000, 0.95)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Villa Notes — CSV Import/Export")
    frame.Title = title

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Format: itemID,note text   (one entry per line)")
    frame.Hint = hint

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -56)
    scroll:SetPoint("BOTTOMRIGHT", -28, 44)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetSize(scroll:GetWidth() or 400, 1)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    scroll:SetScrollChild(editBox)
    frame.EditBox = editBox

    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 24)
    importBtn:SetPoint("BOTTOMLEFT", 14, 10)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local text  = editBox:GetText()
        local count = Notes:ImportCSV(text)
        Villa:Print("Imported " .. tostring(count) .. " notes from CSV.")
        frame:Hide()
    end)

    local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportBtn:SetSize(100, 24)
    exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    exportBtn:SetText("Export to Box")
    exportBtn:SetScript("OnClick", function()
        editBox:SetText(Notes:ExportCSV())
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(70, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 10)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    csvFrame = frame
    return frame
end

function Notes:OpenCSVFrame(mode)
    local frame = EnsureCSVFrame()
    if mode == "export" then
        frame.EditBox:SetText(Notes:ExportCSV())
        frame.EditBox:SetFocus()
        frame.EditBox:HighlightText()
    else
        frame.EditBox:SetText("")
        frame.EditBox:SetFocus()
    end
    frame:Show()
end

-- ============================================================
-- Shift+click hook (catalog/vendor item rows call this)
-- ============================================================

function Notes:HandleItemShiftClick(itemID, anchorFrame)
    if not IsShiftKeyDown() then return false end
    Notes:OpenEditor(itemID, anchorFrame)
    return true
end

-- ============================================================
-- Slash command extensions (wired in Core.lua's handler)
-- ============================================================

function Notes:HandleSlash(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "export" then
        Notes:OpenCSVFrame("export")
    elseif arg == "import" then
        Notes:OpenCSVFrame("import")
    else
        Villa:Print("Usage: /villa notes export | /villa notes import")
    end
end

-- ============================================================
-- Lifecycle
-- ============================================================

function Notes:OnInitialize()
    local db = GetDB()
    if not db then return end
    db.itemNotes = db.itemNotes or {}
end

function Notes:OnEnable()
    self:HookTooltips()
end
