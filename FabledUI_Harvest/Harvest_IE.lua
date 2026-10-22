local H = Harvest
if not H then return end

H.IE = {}
local IE = H.IE

local HEADER = "HARVEST1"

-- FableNeon cosmetic theming (guarded; no-op if the toolkit is absent).
local TK = rawget(_G, "FabledUI_UIToolkit")
local FN_ACCENT = { 0.44, 0.88, 0.63, 1.0 }  -- neon green (gathering)
local function StyleButton(b)
    if b and TK and TK.Themes and TK.Themes.StyleFlatButton then
        TK.Themes:StyleFlatButton(b, "FableNeon", FN_ACCENT)
    end
end
local function ApplyPanel(f)
    if f and TK and TK.Themes and TK.Themes.ApplyPanel then
        TK.Themes:ApplyPanel(f, "FableNeon", FN_ACCENT)
    end
end

-- ============================================================
-- Escape / Unescape helpers (mirrors Poseidon pattern)
-- ============================================================
local function Escape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\n", "\\n")
    value = value:gsub("|", "\\p")
    value = value:gsub(",", "\\c")
    return value
end

local function Unescape(value)
    value = tostring(value or "")
    local out = {}
    local i = 1
    while i <= #value do
        local ch = value:sub(i, i)
        if ch == "\\" then
            local nextChar = value:sub(i + 1, i + 1)
            if nextChar == "n" then
                out[#out + 1] = "\n"
            elseif nextChar == "p" then
                out[#out + 1] = "|"
            elseif nextChar == "c" then
                out[#out + 1] = ","
            elseif nextChar == "\\" then
                out[#out + 1] = "\\"
            else
                out[#out + 1] = nextChar
            end
            i = i + 2
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end
    return table.concat(out)
end

-- ============================================================
-- Serialization
-- Fields: mapID | coordKey | type | id | name | lastSeen
-- ============================================================
function IE:ExportNodes()
    if not H.db or type(H.db.nodes) ~= "table" then
        return HEADER
    end

    local lines = { HEADER }
    for mapID, nodeMap in pairs(H.db.nodes) do
        for coordKey, data in pairs(nodeMap) do
            if type(data) == "table" then
                lines[#lines + 1] = table.concat({
                    tostring(mapID),
                    Escape(coordKey),
                    Escape(data.type or "treasure"),
                    tostring(data.id or 0),
                    Escape(data.name or ""),
                    tostring(data.lastSeen or 0),
                }, "|")
            end
        end
    end
    return table.concat(lines, "\n")
end

-- ============================================================
-- Deserialization — merges imported nodes, keeping newest
-- ============================================================
function IE:ImportNodes(blob)
    if type(blob) ~= "string" or blob == "" then
        return 0, "No import text found."
    end

    local normalized = blob:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = { strsplit("\n", normalized) }
    if lines[1] ~= HEADER then
        return 0, "Import header invalid (expected " .. HEADER .. ")."
    end

    if not H.db then
        return 0, "Harvest storage not ready."
    end
    H.db.nodes = H.db.nodes or {}

    local imported = 0
    for index = 2, #lines do
        local line = lines[index]
        if line and line ~= "" then
            local parts = { strsplit("|", line) }
            local mapID    = tonumber(parts[1])
            local coordKey = Unescape(parts[2] or "")
            local nodeType = Unescape(parts[3] or "treasure")
            local nodeID   = tonumber(parts[4]) or 0
            local name     = Unescape(parts[5] or "")
            local lastSeen = tonumber(parts[6]) or 0

            if mapID and coordKey ~= "" then
                H.db.nodes[mapID] = H.db.nodes[mapID] or {}
                local existing = H.db.nodes[mapID][coordKey]
                -- Only overwrite if imported record is newer or slot is empty
                if not existing or lastSeen > (existing.lastSeen or 0) then
                    H.db.nodes[mapID][coordKey] = {
                        type     = nodeType,
                        id       = nodeID,
                        name     = name,
                        lastSeen = lastSeen,
                    }
                    imported = imported + 1
                end
            end
        end
    end

    if DataVault and DataVault.dirtyFlags then
        DataVault.dirtyFlags["FabledUI_DataVault_Harvest"] = true
    end
    if H.MapProvider then H.MapProvider:RefreshPins() end
    return imported, nil
end

-- ============================================================
-- UI helpers
-- ============================================================
local function CreateWindow(title)
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.06, 0.08, 0.12, 0.96)
    ApplyPanel(frame)  -- FableNeon surface + border (overrides the plain dark backdrop above)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOPLEFT", 16, -16)
    frame.title:SetText(title)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    if TK and TK.Themes and TK.Themes.StyleCloseButton then TK.Themes:StyleCloseButton(close) end

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -48)
    scroll:SetPoint("BOTTOMRIGHT", -36, 52)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(480)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(editBox)

    frame.scroll  = scroll
    frame.editBox = editBox
    return frame
end

function IE:EnsureWindows()
    if self.exportFrame and self.importFrame then return end

    -- Export window
    self.exportFrame = CreateWindow("Harvest Export")

    local exportBtn = CreateFrame("Button", nil, self.exportFrame, "UIPanelButtonTemplate")
    exportBtn:SetSize(120, 24)
    exportBtn:SetPoint("BOTTOMLEFT", 16, 16)
    exportBtn:SetText("Export All")
    StyleButton(exportBtn)
    exportBtn:SetScript("OnClick", function()
        local blob = IE:ExportNodes()
        self.exportFrame.editBox:SetText(blob)
        self.exportFrame.editBox:SetFocus()
        self.exportFrame.editBox:HighlightText()
    end)

    -- Import window
    self.importFrame = CreateWindow("Harvest Import")

    local importBtn = CreateFrame("Button", nil, self.importFrame, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 24)
    importBtn:SetPoint("BOTTOMLEFT", 16, 16)
    importBtn:SetText("Import")
    StyleButton(importBtn)
    importBtn:SetScript("OnClick", function()
        local count, err = IE:ImportNodes(self.importFrame.editBox:GetText())
        if err then
            H:Print(err)
        else
            H:Print("Imported " .. tostring(count) .. " node(s).")
            self.importFrame:Hide()
        end
    end)
end

function IE:OpenExport()
    self:EnsureWindows()
    local blob = IE:ExportNodes()
    self.exportFrame.editBox:SetText(blob)
    self.exportFrame:Show()
    self.exportFrame.editBox:SetFocus()
    self.exportFrame.editBox:HighlightText()
end

function IE:OpenImport()
    self:EnsureWindows()
    self.importFrame.editBox:SetText("")
    self.importFrame:Show()
    self.importFrame.editBox:SetFocus()
end
