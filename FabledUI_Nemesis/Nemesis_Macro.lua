-- ============================================================
-- Nemesis_Macro.lua
--
-- Generates a target + waypoint macro for any tracked entity, and
-- shows it in a copy-friendly StaticPopup with a multi-line edit
-- box. The user copies the text and pastes it into a real macro
-- slot in-game.
--
-- Waypoint integration follows the existing fallback chain:
--   1. FabledUI_Odyssey WaypointService (if loaded)
--   2. /way slash command (TomTom-style)
--   3. C_Map.SetUserWaypoint  (Blizzard built-in)
--
-- The macro emits literal slash lines so it works inside any chat
-- frame regardless of which waypoint addon is installed.
-- ============================================================

local N = Nemesis
N.Macro = {}
local M = N.Macro

local POPUP_KEY = "FABLEDUI_NEMESIS_MACRO"

-- ------------------------------------------------------------
-- Map-name resolution (used for /way <map>)
-- ------------------------------------------------------------

local function GetMapName(mapID)
    mapID = tonumber(mapID)
    if not mapID then return nil end
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name and info.name ~= "" then
            return info.name
        end
    end
    return nil
end

-- ------------------------------------------------------------
-- Macro composition
-- ------------------------------------------------------------

local function SanitizeName(name)
    if type(name) ~= "string" then return "" end
    -- Trim and collapse interior whitespace; macros tolerate either
    -- but cleaner output paste-tests better in macro slots.
    name = name:match("^%s*(.-)%s*$") or name
    return name
end

-- Returns multi-line macro text:
--   /target <NPC name>
--   /way <map> <x> <y> <NPC name>          (TomTom / common)
--   /script C_Map.SetUserWaypoint(...)     (Blizzard built-in)
--
-- The /script line is a fallback that always works in vanilla
-- Blizzard UI; /way is preferred when TomTom or Odyssey is loaded.
function M:GetMacroText(entityID)
    entityID = tonumber(entityID)
    if not entityID then return nil, "Invalid entity ID" end

    if not (N.Database and N.Database.GetEntityData) then
        return nil, "Database unavailable"
    end

    local entry = N.Database:GetEntityData(entityID)
    if type(entry) ~= "table" then
        return nil, "Entity not found"
    end

    local name   = SanitizeName(entry.displayName or entry.name or ("Entity " .. tostring(entityID)))
    local mapID  = tonumber(entry.mapID)
    local x      = tonumber(entry.x)
    local y      = tonumber(entry.y)

    local lines = {}

    -- /target line — always present.
    lines[#lines + 1] = "/target " .. name

    -- Coordinate-bearing lines only if we have a valid pin location.
    if mapID and x and y then
        local mapName = GetMapName(mapID) or ("map " .. tostring(mapID))
        local xPct = x * 100
        local yPct = y * 100

        -- TomTom / common /way slash: "/way <zone> <x> <y> <title>"
        lines[#lines + 1] = string.format("/way %s %.2f %.2f %s", mapName, xPct, yPct, name)

        -- Blizzard built-in waypoint as a fallback. Stays on a single
        -- line; macros tolerate up to ~255 chars per line in 12.x.
        lines[#lines + 1] = string.format(
            "/script C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(%d, %.4f, %.4f)); C_SuperTrack.SetSuperTrackedUserWaypoint(true)",
            mapID, x, y
        )
    end

    return table.concat(lines, "\n")
end

-- Convenience: build the macro AND drop a live waypoint via the
-- Odyssey waypoint service so the user can navigate immediately
-- while the macro is on their clipboard.
function M:DropLiveWaypoint(entityID)
    entityID = tonumber(entityID)
    if not entityID then return false end
    local entry = N.Database and N.Database:GetEntityData(entityID)
    if type(entry) ~= "table" then return false end

    local mapID, x, y = tonumber(entry.mapID), tonumber(entry.x), tonumber(entry.y)
    if not (mapID and x and y) then return false end
    local title = entry.displayName or entry.name or ("Entity " .. tostring(entityID))

    -- 1. Odyssey WaypointService (preferred)
    local Odyssey = rawget(_G, "FabledUI_Odyssey")
    if Odyssey and Odyssey.Services and Odyssey.Services.WaypointService then
        local svc = Odyssey.Services.WaypointService
        if type(svc.SetWaypoint) == "function" then
            local ok = pcall(svc.SetWaypoint, svc, x, y, mapID, {
                title = title,
                source = "Nemesis",
                tags = { "nemesis", "macro" },
            })
            if ok then return true end
        end
    end

    -- 2. TomTom
    local TomTom = rawget(_G, "TomTom")
    if TomTom and type(TomTom.AddWaypoint) == "function" then
        local ok = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, { title = title })
        if ok then return true end
    end

    -- 3. Blizzard built-in
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(point)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        return true
    end

    return false
end

-- ------------------------------------------------------------
-- Copy popup
-- ------------------------------------------------------------

local function EnsurePopup()
    if StaticPopupDialogs[POPUP_KEY] then return end

    StaticPopupDialogs[POPUP_KEY] = {
        text         = "Nemesis macro for %s\n\nCtrl+A to select all, Ctrl+C to copy. Paste into a macro slot in-game.",
        button1      = OKAY,
        hasEditBox   = true,
        editBoxWidth = 360,
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog, data)
            if not dialog or not dialog.editBox then return end
            local edit = dialog.editBox
            edit:SetText(data and data.macroText or "")
            edit:HighlightText()
            edit:SetFocus()
            -- Multi-line behavior: WoW edit boxes default to single-line.
            -- We can't reliably switch to multi-line on a StaticPopup edit box,
            -- so we render lines joined by newlines; the EditBox renders the
            -- first line but Ctrl+A / Ctrl+C still copies the full string.
            edit:SetMaxLetters(0)
            edit:SetAutoFocus(true)
        end,
        EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        EditBoxOnTextChanged = function(self, data)
            -- Restore the original macro if the user types over it; the
            -- popup is read-only-by-convention.
            local parent = self:GetParent()
            if parent and parent.data and parent.data.macroText and self:GetText() ~= parent.data.macroText then
                self:SetText(parent.data.macroText)
                self:HighlightText()
            end
        end,
    }
end

-- A larger popup with a true multi-line ScrollingEditBox built on
-- the fly. Used because StaticPopup's built-in editBox is single-line.
local copyFrame
local function ShowCopyFrame(title, macroText)
    if not copyFrame then
        copyFrame = CreateFrame("Frame", "FabledUI_NemesisMacroCopy", UIParent, "BackdropTemplate")
        copyFrame:SetSize(440, 220)
        copyFrame:SetPoint("CENTER")
        copyFrame:SetFrameStrata("DIALOG")
        copyFrame:SetToplevel(true)
        copyFrame:SetMovable(true)
        copyFrame:EnableMouse(true)
        copyFrame:RegisterForDrag("LeftButton")
        copyFrame:SetClampedToScreen(true)
        copyFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        copyFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        copyFrame:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })

        copyFrame.title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        copyFrame.title:SetPoint("TOP", 0, -14)

        copyFrame.hint = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        copyFrame.hint:SetPoint("TOP", copyFrame.title, "BOTTOM", 0, -4)
        copyFrame.hint:SetText("Ctrl+A to select all, Ctrl+C to copy. Paste into a macro slot.")

        copyFrame.scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
        copyFrame.scroll:SetPoint("TOPLEFT", 16, -56)
        copyFrame.scroll:SetPoint("BOTTOMRIGHT", -36, 50)

        copyFrame.editBox = CreateFrame("EditBox", nil, copyFrame.scroll)
        copyFrame.editBox:SetMultiLine(true)
        copyFrame.editBox:SetFontObject("ChatFontNormal")
        copyFrame.editBox:SetWidth(380)
        copyFrame.editBox:SetAutoFocus(true)
        copyFrame.editBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
        copyFrame.scroll:SetScrollChild(copyFrame.editBox)

        copyFrame.close = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
        copyFrame.close:SetPoint("TOPRIGHT", -4, -4)

        copyFrame.ok = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
        copyFrame.ok:SetSize(96, 22)
        copyFrame.ok:SetPoint("BOTTOM", 0, 14)
        copyFrame.ok:SetText("Close")
        copyFrame.ok:SetScript("OnClick", function() copyFrame:Hide() end)
        local _tk = rawget(_G, "FabledUI_UIToolkit")
        if _tk and _tk.Themes and _tk.Themes.StyleFlatButton then
            _tk.Themes:StyleFlatButton(copyFrame.ok, "FableNeon", { 0.860, 0.290, 0.360, 1.0 })
        end
    end

    copyFrame.title:SetText(title or "Nemesis Macro")
    copyFrame.editBox:SetText(macroText or "")
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
    copyFrame:Show()
end

-- Public: show the popup with a macro for the given entity.
function M:ShowCopyPopup(entityID)
    local macroText, err = self:GetMacroText(entityID)
    if not macroText then
        if N and N.Print then N:Print("Macro: " .. tostring(err)) end
        return
    end

    local entry = N.Database and N.Database:GetEntityData(entityID)
    local entityName = entry and (entry.displayName or entry.name) or ("Entity " .. tostring(entityID))

    -- Drop a live waypoint as a courtesy so the user can also navigate now.
    pcall(function() M:DropLiveWaypoint(entityID) end)

    EnsurePopup()
    ShowCopyFrame("Nemesis Macro - " .. entityName, macroText)
end
