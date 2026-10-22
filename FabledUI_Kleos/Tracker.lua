local K = Kleos
K.Tracker = K.Tracker or {}
local T = K.Tracker
local W = K.Widgets

-- ============================================================================
-- Tracker
-- The on-screen overlay. Three modes:
--   INSTANCE  the achievements the encounter engine says apply here, with met /
--             failed state per achievement and live criteria progress
--   WATCH     the watch list
--   SINGLE    one achievement, which is what /iat <id> selects
--
-- "Progress signals" from the scope doc are the colour states plus the signal
-- line: when a criterion ticks over or an achievement fails mid-pull, the
-- change is called out at the top rather than only changing a row colour
-- somewhere in the list.
-- ============================================================================

T.MODES = { "INSTANCE", "WATCH", "SINGLE" }

local ROW_HEIGHT = 16
local SIGNAL_HOLD = 8   -- seconds a signal line stays up

local function TrackerSettings()
    K.db.settings.tracker = K.db.settings.tracker or {}
    local settings = K.db.settings.tracker
    settings.windowState = settings.windowState or {}
    local state = settings.windowState
    -- Migrate the pre-1.2 flat keys.
    state.width = state.width or settings.w or 400
    state.height = state.height or settings.h or 360
    state.x = state.x or settings.x or 0
    state.y = state.y or settings.y or 0
    return settings, state
end

-- ----------------------------------------------------------------------------
-- Frame
-- ----------------------------------------------------------------------------
function T:Init()
    if self.frame then return end
    local settings, state = TrackerSettings()

    local frame = W:Panel(UIParent, "FabledUI_KleosIAT")
    frame:SetSize(state.width or 400, state.height or 360)
    frame:SetPoint("CENTER", UIParent, "CENTER", state.x or 0, state.y or 0)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if K.db.settings.lockFrames then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local centerX, centerY = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if centerX and parentX then
            state.x = math.floor(centerX - parentX + 0.5)
            state.y = math.floor(centerY - parentY + 0.5)
            K.Storage:CommitSoon()
        end
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "FabledUI_KleosIAT")

    frame.title = W:Label(frame, "|cff4fd1c5Kleos|r " .. (K.L.TRACKER or "Tracker"), "GameFontHighlight")
    frame.title:SetPoint("TOPLEFT", 10, -10)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    local TK = W:Toolkit()
    if TK and TK.Themes and TK.Themes.StyleCloseButton then TK.Themes:StyleCloseButton(closeButton) end

    frame.modeButton = W:Button(frame, "", 90, 18, function()
        local current = self.mode or "INSTANCE"
        local position = 1
        for index, mode in ipairs(T.MODES) do
            if mode == current then position = index end
        end
        position = position + 1
        if position > #T.MODES then position = 1 end
        self:SetMode(T.MODES[position])
    end)
    frame.modeButton:SetPoint("TOPRIGHT", closeButton, "BOTTOMLEFT", -2, -2)

    frame.announceButton = W:Button(frame, K.L.ANNOUNCE_ACTION or "Announce", 90, 18, function()
        K.Encounter:AnnounceTracked()
    end)
    frame.announceButton:SetPoint("RIGHT", frame.modeButton, "LEFT", -4, 0)

    -- Kept as `cur` for the pre-1.2 contract: this is the headline line.
    frame.cur = W:Label(frame, K.L.NO_SELECTION or "No achievement selected.", "GameFontNormal")
    frame.cur:SetPoint("TOPLEFT", 10, -34)
    frame.cur:SetPoint("TOPRIGHT", -10, -34)

    frame.signal = W:Label(frame, "", "GameFontHighlightSmall")
    frame.signal:SetPoint("TOPLEFT", frame.cur, "BOTTOMLEFT", 0, -2)
    frame.signal:SetPoint("TOPRIGHT", frame.cur, "BOTTOMRIGHT", 0, -2)

    local list = W:RowList(frame, { rowHeight = ROW_HEIGHT, pageSize = 120, emptyText = K.L.TRACKER_EMPTY or "Nothing to track here." })
    list:SetPoint("TOPLEFT", frame.signal, "BOTTOMLEFT", 0, -6)
    list:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.list = list
    -- `lines` and `cont` are the pre-1.2 field names; keep them pointed at the
    -- row pool so anything still reading them sees live rows.
    frame.lines = list.rows
    frame.cont = list.content

    list:SetRenderer(function(row, item)
        if not item then return end
        row.icon:SetTexture(item.icon or nil)
        row.name:SetText(item.text or "")
        row.right:SetText(item.right or "")
        row.star:SetText("")
        row:SetScript("OnClick", function(_, button)
            if not item.achievementID then return end
            if button == "RightButton" then
                if K.Menu then K.Menu:Show(item.achievementID, nil, row) end
                return
            end
            if K.UI then K.UI:ShowAchievement(item.achievementID) end
        end)
        row:SetScript("OnEnter", function(self)
            if not item.achievementID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(K.Meta.AchievementName(item.achievementID), 1, 1, 1)
            K.Tooltip:FillAchievement(GameTooltip, item.achievementID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)

    self.frame = frame
    self.mode = settings.mode or "INSTANCE"
    self:SetMode(self.mode)

    -- One ticker, only while visible: criteria quantities change without an
    -- event in some fights (timers, and quantity-only criteria).
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1, function()
            if frame:IsShown() then K:SafeCall(function() T:Refresh() end) end
        end)
    end

    if settings.enabled then frame:Show() end
end

function T:SetMode(mode)
    mode = tostring(mode or "INSTANCE"):upper()
    local valid = false
    for _, candidate in ipairs(self.MODES) do
        if candidate == mode then valid = true end
    end
    if not valid then mode = "INSTANCE" end

    self.mode = mode
    local settings = TrackerSettings()
    settings.mode = mode
    if self.frame and self.frame.modeButton then
        self.frame.modeButton:SetText(K.L[mode] or mode)
    end
    K.Storage:CommitSoon()
    self:Refresh()
    return mode
end

function T:SetAchievement(id, show)
    self.achievementID = tonumber(id)
    if self.achievementID then
        self.mode = "SINGLE"
        if self.frame and self.frame.modeButton then
            self.frame.modeButton:SetText(K.L.SINGLE or "Single")
        end
    end
    if show then
        if not self.frame then self:Init() end
        if self.frame then self.frame:Show() end
    end
    self:Refresh()
end

function T:Signal(text, color)
    if not self.frame then return end
    self._signalUntil = ((type(GetTime) == "function") and GetTime() or 0) + SIGNAL_HOLD
    self.frame.signal:SetText((color or "|cffffd100") .. tostring(text) .. "|r")
end

-- ----------------------------------------------------------------------------
-- Row building
-- ----------------------------------------------------------------------------
local function CriteriaRows(achievementID, rows, indent)
    for _, step in ipairs(K.Meta:Breakdown(achievementID)) do
        local suffix = ""
        if step.duration and step.duration > 0 then
            suffix = (" |cff888888(%ds)|r"):format(math.max(0, step.duration - (step.elapsed or 0)))
        elseif step.required and step.required > 1 then
            suffix = (" |cff888888(%d/%d)|r"):format(step.quantity or 0, step.required)
        end
        local color = step.completed and "|cff00ff00" or (step.eligible == false and "|cffff5555" or "|cffffd100")
        rows[#rows + 1] = {
            achievementID = achievementID,
            text = indent .. color .. tostring(step.text or "?") .. "|r" .. suffix,
        }
    end
end

function T:BuildRows()
    local rows = {}
    local mode = self.mode or "INSTANCE"

    if mode == "SINGLE" then
        local id = self.achievementID
        if type(id) ~= "number" then return rows end
        CriteriaRows(id, rows, "")
        return rows
    end

    local ids
    if mode == "WATCH" then
        ids = {}
        for id, value in pairs((K.db and K.db.watchlist) or {}) do
            local numeric = tonumber(id)
            if value and numeric then ids[#ids + 1] = numeric end
        end
        table.sort(ids)
    else
        local encounter = K.Encounter.state.encounter
        ids = encounter and encounter.achievements or K.Encounter:AchievementsInPlay()
    end

    for _, id in ipairs(ids) do
        local entry = K.Catalog:GetEntry(id) or {}
        local result = K.Encounter.state.results and K.Encounter.state.results[id] or nil
        local progress = K.Catalog:GetProgress(id)
        local marker = ""
        local color = "|cffffffff"
        if result == "met" then
            marker, color = "|cff00ff00[+]|r ", "|cff00ff00"
        elseif result == "failed" then
            marker, color = "|cffff5555[x]|r ", "|cffff5555"
        elseif progress >= 1 then
            color = "|cff00ff00"
        end

        rows[#rows + 1] = {
            achievementID = id,
            icon = entry.icon,
            text = marker .. color .. ((entry.name ~= "" and entry.name) or ("Ach " .. id)) .. "|r",
            right = progress > 0 and (W:ProgressColor(progress) .. ("%d%%"):format(math.floor(progress * 100 + 0.5)) .. "|r") or "",
        }
        CriteriaRows(id, rows, "   ")
    end

    return rows
end

function T:Refresh()
    local frame = self.frame
    if not frame then return end

    local mode = self.mode or "INSTANCE"
    local headline
    if mode == "SINGLE" then
        local id = self.achievementID
        if type(id) ~= "number" then
            headline = K.L.NO_SELECTION or "No achievement selected."
        else
            local entry = K.Catalog:GetEntry(id) or {}
            local state = K.Catalog:GetState(id) or {}
            headline = ("%s |cff888888(#%d)|r%s"):format(
                (entry.name ~= "" and entry.name) or ("Ach " .. id), id,
                state.completed and (" |cff00ff00" .. (K.L.COMPLETE or "DONE") .. "|r") or "")
        end
    elseif mode == "WATCH" then
        local count = 0
        for _, value in pairs((K.db and K.db.watchlist) or {}) do
            if value then count = count + 1 end
        end
        headline = ("%s: %d"):format(K.L.WATCH or "Watched", count)
    else
        local status = K.Encounter:Status()
        if status.inInstance then
            -- SafeText, not tostring: tostring on a secret value throws exactly
            -- the way concatenation does.
            local instance = K.Util and K.Util.SafeText(status.instanceName, "?") or "?"
            local encounter = K.Util and K.Util.SafeText(status.encounter) or ""
            headline = ("%s%s"):format(instance,
                encounter ~= "" and (" — " .. encounter) or "")
        else
            headline = K.L.NOT_IN_INSTANCE or "Not in a dungeon or raid."
        end
    end
    frame.cur:SetText(headline)

    -- Expire the signal line.
    local now = (type(GetTime) == "function") and GetTime() or 0
    if self._signalUntil and now > self._signalUntil then
        frame.signal:SetText("")
        self._signalUntil = nil
    end

    -- Detect criteria that ticked over since the last refresh and call it out.
    local rows = self:BuildRows()
    self:DetectChanges(rows)

    frame.list:SetItems(rows, true)
    frame.lines = frame.list.rows
end

-- Compares the previous row text set to the current one. Text comparison is
-- deliberate: it catches quantity changes, timer starts and completion in one
-- pass without keeping a parallel snapshot structure.
function T:DetectChanges(rows)
    local previous = self._previousRows
    self._previousRows = {}
    for _, row in ipairs(rows) do
        if row.achievementID then
            local key = tostring(row.achievementID) .. "|" .. tostring(row.text)
            self._previousRows[key] = true
        end
    end
    if not previous then return end

    local completedNow = 0
    for key in pairs(self._previousRows) do
        if not previous[key] and key:find("|cff00ff00", 1, true) then
            completedNow = completedNow + 1
        end
    end
    if completedNow > 0 then
        self:Signal(("%d %s"):format(completedNow, K.L.CRITERIA_MET or "criteria met"), "|cff00ff00")
    end
end

-- ----------------------------------------------------------------------------
-- Encounter hooks
-- ----------------------------------------------------------------------------
function T:OnInstanceChanged()
    if not self.frame then return end
    local settings = TrackerSettings()
    local status = K.Encounter:Status()
    if settings.enabled and settings.autoShow ~= false and status.inInstance and status.achievements > 0 then
        self.mode = "INSTANCE"
        self.frame:Show()
    end
    self:Refresh()
end

function T:OnEncounterStart(encounter)
    if not self.frame then return end
    local settings = TrackerSettings()
    if settings.enabled then self.frame:Show() end
    self.mode = (self.mode == "SINGLE") and "SINGLE" or "INSTANCE"
    self:Signal(("%s: %d %s"):format(tostring(encounter and encounter.name or "?"),
        #(encounter and encounter.achievements or {}), K.L.ACHIEVEMENTS or "achievements"))
    self:Refresh()
end

function T:OnEncounterEnd(summary)
    if not self.frame then return end
    if summary then
        if #summary.met > 0 then
            self:Signal(("%s: %s"):format(K.L.COMPLETE or "Met", table.concat(summary.met, ", ")), "|cff00ff00")
        elseif #summary.failed > 0 then
            self:Signal(("%s: %s"):format(K.L.FAILED or "Missed", table.concat(summary.failed, ", ")), "|cffff5555")
        end
    end
    self:Refresh()
end

function T:Toggle()
    if not self.frame then self:Init() end
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Refresh()
    end
end

-- /iat [id|watch|instance]
function T:Slash(message)
    if not self.frame then self:Init() end
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$") or ""

    local id = tonumber(message:match("(%d+)"))
    if id then
        self:SetAchievement(id, true)
        return
    end
    if message == "watch" or message == "watched" then
        self:SetMode("WATCH")
        if self.frame then self.frame:Show() end
        return
    end
    if message == "instance" or message == "iat" then
        self:SetMode("INSTANCE")
        if self.frame then self.frame:Show() end
        return
    end
    if message == "announce" then
        K.Encounter:AnnounceTracked()
        return
    end
    self:Toggle()
end
