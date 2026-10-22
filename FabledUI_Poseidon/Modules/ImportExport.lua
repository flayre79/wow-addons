local P = _G.FabledUI_Poseidon
if not P then return end

P.ImportExport = P.ImportExport or {}
local IE = P.ImportExport

local HEADER = "POSEIDON2"

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

local function SplitEscaped(line, delimiter)
    local parts = {}
    local current = {}
    local escaped = false
    for i = 1, #line do
        local ch = line:sub(i, i)
        if escaped then
            current[#current + 1] = "\\"
            current[#current + 1] = ch
            escaped = false
        elseif ch == "\\" then
            escaped = true
        elseif ch == delimiter then
            parts[#parts + 1] = table.concat(current)
            current = {}
        else
            current[#current + 1] = ch
        end
    end
    parts[#parts + 1] = table.concat(current)
    return parts
end

function IE:SerializeNodes(mapID)
    local lines = { HEADER }
    for _, node in ipairs(P.Nodes:IterateNodes(mapID)) do
        local fishParts = {}
        for fishName, count in pairs(node.fish or {}) do
            fishParts[#fishParts + 1] = Escape(fishName) .. "," .. tostring(count or 0)
        end
        table.sort(fishParts)
        lines[#lines + 1] = table.concat({
            tostring(node.mapID or 0),
            tostring(node.x or 0),
            tostring(node.y or 0),
            Escape(node.name or ""),
            tostring(node.lastSeen or 0),
            tostring(node.discovered or 0),
            tostring(node.seenCount or 0),
            tostring(node.catchCount or 0),
            Escape(node.mapName or ""),
            Escape(node.subZone or ""),
            Escape(node.note or ""),
            table.concat(fishParts, ";"),
        }, "|")
    end
    return table.concat(lines, "\n")
end

function IE:DeserializeNodes(blob)
    if type(blob) ~= "string" or blob == "" then
        return 0, "No import text found."
    end
    local normalized = blob:gsub("\r\n", "\n")
    local lines = { strsplit("\n", normalized) }
    if lines[1] ~= HEADER then
        return 0, "Import header is invalid."
    end

    local imported = 0
    for index = 2, #lines do
        local line = lines[index]
        if line and line ~= "" then
            local fields = SplitEscaped(line, "|")
            local fishTable = {}
            if fields[12] and fields[12] ~= "" then
                for _, pairText in ipairs(SplitEscaped(fields[12], ";")) do
                    local fishName, countText = pairText:match("^(.*),(%d+)$")
                    if fishName and countText then
                        fishTable[Unescape(fishName)] = tonumber(countText) or 0
                    end
                end
            end
            local node = P.Nodes:ImportNode({
                mapID = tonumber(fields[1]),
                x = tonumber(fields[2]),
                y = tonumber(fields[3]),
                name = Unescape(fields[4]),
                lastSeen = tonumber(fields[5]) or time(),
                discovered = tonumber(fields[6]) or time(),
                seenCount = tonumber(fields[7]) or 0,
                catchCount = tonumber(fields[8]) or 0,
                mapName = Unescape(fields[9]),
                subZone = Unescape(fields[10]),
                note = Unescape(fields[11]),
                fish = fishTable,
            })
            if node then
                imported = imported + 1
            end
        end
    end

    P.db.meta.lastImportAt = time()
    P:MarkDirty()
    P:QueueDataBroadcast("import")
    return imported
end

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
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.06, 0.08, 0.12, 0.96)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOPLEFT", 16, -16)
    frame.title:SetText(title)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -48)
    scroll:SetPoint("BOTTOMRIGHT", -36, 52)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(480)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    scroll:SetScrollChild(editBox)

    frame.scroll = scroll
    frame.editBox = editBox
    return frame
end

function IE:EnsureWindows()
    if self.exportFrame and self.importFrame then
        return
    end

    self.exportFrame = CreateWindow("Poseidon Export")
    local exportAll = CreateFrame("Button", nil, self.exportFrame, "UIPanelButtonTemplate")
    exportAll:SetSize(120, 24)
    exportAll:SetPoint("BOTTOMLEFT", 16, 16)
    exportAll:SetText("Export All")
    exportAll:SetScript("OnClick", function()
        self.exportFrame.editBox:SetText(IE:SerializeNodes(nil))
        self.exportFrame.editBox:HighlightText()
        P.db.meta.lastExportAt = time()
        P:MarkDirty()
    end)

    self.importFrame = CreateWindow("Poseidon Import")
    local importButton = CreateFrame("Button", nil, self.importFrame, "UIPanelButtonTemplate")
    importButton:SetSize(120, 24)
    importButton:SetPoint("BOTTOMLEFT", 16, 16)
    importButton:SetText("Import")
    importButton:SetScript("OnClick", function()
        local count, err = IE:DeserializeNodes(self.importFrame.editBox:GetText())
        if err then
            P:Print(err)
        else
            P:Print("Imported nodes:", count)
            self.importFrame:Hide()
        end
    end)
end

function IE:OpenExportWindow()
    self:EnsureWindows()
    self.exportFrame.editBox:SetText(IE:SerializeNodes(nil))
    self.exportFrame:Show()
    self.exportFrame.editBox:HighlightText()
end

function IE:OpenImportWindow()
    self:EnsureWindows()
    self.importFrame.editBox:SetText("")
    self.importFrame:Show()
end
