-- FabledUI - Artemis Checklist : Multi-Character Panel
-- =====================================================================
-- Feature A2 (Larias pattern): adds a character-picker dropdown to the
-- checklist module so players can review and tick off tasks for any
-- character on the account from a single window.
--
-- Storage shape (DataVault-first with SavedVariable fallback):
--   db.checklist[charKey][taskID] = { done = bool, completedAt = time() }
--   db.checklistCharacters[charKey] = {
--       name = "Bob", realm = "Stormrage", classFile = "MAGE",
--       lastSeen = time(),
--   }
--
-- Each task is keyed by its checklist entry id (the same id Artemis
-- already mints in Checklist.lua: derived "kind:questID" or custom id).
-- Reset markers are read from the entry's templateKey; we reuse the
-- existing template-driven categorisation rather than inventing new ones:
--   recurring/daily  -> daily reset
--   recurring/weekly -> weekly reset
--   monthly          -> monthly reset
--
-- The reset sweep runs once per /reload and is idempotent.

local A = FabledUI_Artemis or Artemis
if not A then return end

A.MultiChar = A.MultiChar or {}
local MC = A.MultiChar

local SHARD_KEY = "FabledUI_DataVault"
local ADDON_KEY = "artemis_checklist"

-- ---------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------

local function CharacterKey()
    if A.GetCharacterKey then
        return A:GetCharacterKey()
    end
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return name .. "-" .. realm
end

local function CurrentClassFile()
    local _, classFile = UnitClass("player")
    return classFile
end

-- DataVault-first store. We piggyback on the existing DataVault namespace
-- so every checklist client sees the same data (account scope). Falls back
-- to a dedicated SavedVariable when DataVault isn't installed.
function MC:Store()
    if self._store then
        return self._store
    end

    local dv = _G.DataVault

    if dv and dv.IsAvailable and dv:IsAvailable() then
        dv:EnsureNamespace(ADDON_KEY)
        local store = dv:Get("account", ADDON_KEY, "multichar", nil)
        if type(store) ~= "table" then
            store = { checklist = {}, characters = {}, lastResetSweep = {} }
            dv:Set("account", ADDON_KEY, "multichar", store)
        end
        store.checklist = store.checklist or {}
        store.characters = store.characters or {}
        store.lastResetSweep = store.lastResetSweep or {}
        self._backend = "DataVault"
        self._store = store
        return store
    end

    _G.FabledUI_Artemis_ChecklistMultiCharDB = _G.FabledUI_Artemis_ChecklistMultiCharDB or {
        checklist = {}, characters = {}, lastResetSweep = {},
    }
    local store = _G.FabledUI_Artemis_ChecklistMultiCharDB
    store.checklist = store.checklist or {}
    store.characters = store.characters or {}
    store.lastResetSweep = store.lastResetSweep or {}
    self._backend = "Local SVs"
    self._store = store
    return store
end

function MC:GetBackendLabel()
    if not self._store then
        self:Store()
    end
    return self._backend or "Unknown"
end

-- ---------------------------------------------------------------------
-- Roster / character bookkeeping
-- ---------------------------------------------------------------------

function MC:RememberCharacter()
    local store = self:Store()
    local key = CharacterKey()
    store.characters[key] = store.characters[key] or {}
    local entry = store.characters[key]
    entry.name = UnitName("player") or entry.name or "Unknown"
    entry.realm = GetRealmName() or entry.realm or "UnknownRealm"
    entry.classFile = CurrentClassFile() or entry.classFile
    entry.lastSeen = time()
    return entry
end

function MC:GetSelectedKey()
    local store = self:Store()
    if not store.selectedKey or not store.characters[store.selectedKey] then
        store.selectedKey = CharacterKey()
    end
    return store.selectedKey
end

function MC:SetSelectedKey(charKey)
    if not charKey then return end
    local store = self:Store()
    if not store.characters[charKey] then
        return
    end
    store.selectedKey = charKey
    if A.Tracker then
        A.Tracker:Refresh(true)
    end
    if MC.panel and MC.panel:IsShown() then
        MC:RefreshPanel()
    end
end

-- Returns an array of { key, label, classFile } sorted by name-realm.
function MC:GetCharacterChoices()
    local store = self:Store()
    local list = {}
    for key, info in pairs(store.characters) do
        list[#list + 1] = {
            key = key,
            name = info.name or key,
            realm = info.realm or "",
            classFile = info.classFile,
            lastSeen = info.lastSeen or 0,
        }
    end
    table.sort(list, function(a, b)
        if a.realm ~= b.realm then return a.realm < b.realm end
        return a.name < b.name
    end)
    return list
end

-- ---------------------------------------------------------------------
-- Per-task state
-- ---------------------------------------------------------------------

function MC:GetTaskState(charKey, taskID)
    if not charKey or not taskID then return nil end
    local store = self:Store()
    local bucket = store.checklist[charKey]
    if not bucket then return nil end
    return bucket[taskID]
end

function MC:SetTaskDone(charKey, taskID, done)
    if not charKey or not taskID then return end
    local store = self:Store()
    store.checklist[charKey] = store.checklist[charKey] or {}
    if done then
        store.checklist[charKey][taskID] = {
            done = true,
            completedAt = time(),
        }
    else
        store.checklist[charKey][taskID] = nil
    end
    if A.Tracker then
        A.Tracker:Refresh(true)
    end
    if MC.panel and MC.panel:IsShown() then
        MC:RefreshPanel()
    end
end

function MC:ToggleTask(taskID)
    local key = self:GetSelectedKey()
    local current = self:GetTaskState(key, taskID)
    self:SetTaskDone(key, taskID, not (current and current.done))
end

function MC:IsTaskDone(taskID, charKey)
    local key = charKey or self:GetSelectedKey()
    local entry = self:GetTaskState(key, taskID)
    return entry and entry.done == true or false
end

-- ---------------------------------------------------------------------
-- Reset markers
-- ---------------------------------------------------------------------
-- Map a checklist entry to a reset cadence. Falls back to "none" so
-- one-off custom entries are never auto-cleared.
function MC:GetResetMarker(entry)
    if type(entry) ~= "table" then return "none" end
    local kind = entry.type or entry.templateKey
    if kind == "daily"   then return "daily"   end
    if kind == "weekly"  then return "weekly"  end
    if kind == "monthly" then return "monthly" end
    if kind == "expiring" then return "weekly" end
    if kind == "recurring" then return "weekly" end
    return "none"
end

local function SecondsUntilDailyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
        if ok and type(seconds) == "number" then return seconds end
    end
    if GetQuestResetTime then
        local ok, seconds = pcall(GetQuestResetTime)
        if ok and type(seconds) == "number" then return seconds end
    end
    return 0
end

local function SecondsUntilWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and type(seconds) == "number" then return seconds end
    end
    return 0
end

-- A "period bucket" is a coarse timestamp that only changes when a reset
-- has happened. We compare it against the last sweep we ran for each
-- character to know whether to clear the matching tasks.
local function CurrentDailyBucket()
    return math.floor((time() + SecondsUntilDailyReset()) / 86400)
end

local function CurrentWeeklyBucket()
    return math.floor((time() + SecondsUntilWeeklyReset()) / (86400 * 7))
end

local function CurrentMonthlyBucket()
    local d = date("*t")
    return d.year * 100 + d.month
end

local function ClearByMarker(store, charKey, marker)
    local bucket = store.checklist[charKey]
    if not bucket then return end
    for taskID, state in pairs(bucket) do
        if state and state._marker == marker then
            bucket[taskID] = nil
        end
    end
end

function MC:RunResetSweep()
    local store = self:Store()
    local sweep = store.lastResetSweep
    local nowDaily = CurrentDailyBucket()
    local nowWeekly = CurrentWeeklyBucket()
    local nowMonthly = CurrentMonthlyBucket()

    for charKey in pairs(store.characters) do
        sweep[charKey] = sweep[charKey] or {}
        local mySweep = sweep[charKey]
        if mySweep.daily ~= nowDaily then
            ClearByMarker(store, charKey, "daily")
            mySweep.daily = nowDaily
        end
        if mySweep.weekly ~= nowWeekly then
            ClearByMarker(store, charKey, "weekly")
            mySweep.weekly = nowWeekly
        end
        if mySweep.monthly ~= nowMonthly then
            ClearByMarker(store, charKey, "monthly")
            mySweep.monthly = nowMonthly
        end
    end
end

-- Persist the marker alongside the task state so RunResetSweep can find
-- the right bucket to clear without recomputing classifications.
local rawSetTaskDone = MC.SetTaskDone
function MC:SetTaskDoneWithMarker(charKey, taskID, done, marker)
    rawSetTaskDone(self, charKey, taskID, done)
    if done then
        local store = self:Store()
        store.checklist[charKey] = store.checklist[charKey] or {}
        if store.checklist[charKey][taskID] then
            store.checklist[charKey][taskID]._marker = marker or "none"
        end
    end
end

function MC:ToggleEntry(entry)
    if type(entry) ~= "table" or not entry.id then return end
    local key = self:GetSelectedKey()
    local current = self:GetTaskState(key, entry.id)
    local nowDone = not (current and current.done)
    self:SetTaskDoneWithMarker(key, entry.id, nowDone, self:GetResetMarker(entry))
end

-- ---------------------------------------------------------------------
-- UI panel (character picker + per-task list)
-- ---------------------------------------------------------------------

local CLASS_COLORS = (RAID_CLASS_COLORS and RAID_CLASS_COLORS) or {}

local function ClassColorHex(classFile)
    local c = classFile and CLASS_COLORS[classFile]
    if c and c.colorStr then return c.colorStr end
    if c then
        return string.format("ff%02x%02x%02x", math.floor((c.r or 1) * 255), math.floor((c.g or 1) * 255), math.floor((c.b or 1) * 255))
    end
    return "ffffffff"
end

function MC:BuildCharacterMenu(button)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(button, function(_, rootDescription)
            rootDescription:CreateTitle("Select Character")
            for _, choice in ipairs(self:GetCharacterChoices()) do
                local hex = ClassColorHex(choice.classFile)
                local label = string.format("|c%s%s|r |cffaaaaaa- %s|r", hex, choice.name, choice.realm)
                rootDescription:CreateButton(label, function()
                    self:SetSelectedKey(choice.key)
                end)
            end
        end)
        return true
    end
    return false
end

local function CreatePanel()
    if MC.panel then return MC.panel end

    local panel = CreateFrame("Frame", "FabledUI_Artemis_ChecklistMultiCharPanel", UIParent, "BackdropTemplate")
    panel:SetSize(380, 480)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("HIGH")
    panel:Hide()

    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        panel:SetBackdropColor(0.05, 0.05, 0.07, 0.94)
    end

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 14, -12)
    panel.title:SetText("|cffe5bc55Checklist|r")

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -2)
    panel.subtitle:SetText("Account-wide multi-character checklist")

    panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.close:SetPoint("TOPRIGHT", -4, -4)

    -- Character picker button (acts as the dropdown target).
    panel.picker = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.picker:SetSize(240, 24)
    panel.picker:SetPoint("TOPLEFT", 14, -50)
    panel.picker:SetText("Current Character")
    panel.picker:SetScript("OnClick", function(self)
        if not MC:BuildCharacterMenu(self) then
            -- Cycle through known characters as a fallback.
            local choices = MC:GetCharacterChoices()
            if #choices == 0 then return end
            local current = MC:GetSelectedKey()
            local nextIdx = 1
            for i, choice in ipairs(choices) do
                if choice.key == current then
                    nextIdx = (i % #choices) + 1
                    break
                end
            end
            MC:SetSelectedKey(choices[nextIdx].key)
        end
    end)

    panel.backendLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.backendLabel:SetPoint("LEFT", panel.picker, "RIGHT", 8, 0)
    panel.backendLabel:SetJustifyH("LEFT")

    panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", panel.picker, "BOTTOMLEFT", 0, -10)
    panel.scroll:SetPoint("BOTTOMRIGHT", -32, 12)

    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(1, 1)
    panel.scroll:SetScrollChild(panel.content)
    panel.rows = {}

    MC.panel = panel
    return panel
end

local function AcquireRow(content, index)
    local rows = MC.panel.rows
    if rows[index] then return rows[index] end
    local row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    row:SetSize(18, 18)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "RIGHT", 4, 0)
    row.text:SetWidth(310)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    rows[index] = row
    return row
end

function MC:CollectEntries()
    if not (A.Checklist and A.Checklist.GetEntries and A.QuestScan) then
        return {}
    end
    local scan = A.QuestScan:Run(false)
    local ok, entries = pcall(A.Checklist.GetEntries, A.Checklist, scan)
    if not ok or type(entries) ~= "table" then
        return {}
    end
    return entries
end

function MC:RefreshPanel()
    local panel = MC.panel
    if not panel then return end

    local key = self:GetSelectedKey()
    local store = self:Store()
    local info = store.characters[key] or {}
    local hex = ClassColorHex(info.classFile)
    panel.picker:SetText(string.format("|c%s%s|r", hex, info.name or "Current"))
    panel.backendLabel:SetText("Backend: " .. self:GetBackendLabel())

    local entries = self:CollectEntries()
    local previous
    for index, entry in ipairs(entries) do
        local row = AcquireRow(panel.content, index)
        row:ClearAllPoints()
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
        else
            row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 4, -4)
        end
        local taskID = entry.id
        local marker = self:GetResetMarker(entry)
        local done = self:IsTaskDone(taskID, key)
        row:SetChecked(done)
        local suffix = ""
        if marker ~= "none" then
            suffix = string.format(" |cffaaaaaa(%s)|r", marker)
        end
        row.text:SetText((entry.label or taskID or "Task") .. suffix)
        row:SetScript("OnClick", function(self)
            local nowDone = self:GetChecked() and true or false
            MC:SetTaskDoneWithMarker(key, taskID, nowDone, marker)
        end)
        row:Show()
        previous = row
    end

    -- Hide unused rows.
    for index = #entries + 1, #panel.rows do
        panel.rows[index]:Hide()
    end

    panel.content:SetHeight(math.max(1, #entries * 22 + 8))
end

function MC:Toggle()
    local panel = CreatePanel()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        self:RefreshPanel()
    end
end

-- ---------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        MC:Store()
        MC:RememberCharacter()
        MC:RunResetSweep()
        SLASH_FABLEDUI_ARTEMIS_CHECKLIST1 = "/checklist"
        SLASH_FABLEDUI_ARTEMIS_CHECKLIST2 = "/artchecklist"
        SlashCmdList["FABLEDUI_ARTEMIS_CHECKLIST"] = function(msg)
            msg = (msg or ""):lower()
            if msg == "panel" or msg == "" or msg == "show" or msg == "toggle" then
                MC:Toggle()
            elseif msg == "sweep" or msg == "reset" then
                MC:RunResetSweep()
                if A and A.Print then A:Print("Checklist reset sweep complete.") end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-run the sweep on world enters to catch the daily/weekly tick
        -- cleanly when a player keeps the game running for >24h.
        MC:RunResetSweep()
    end
end)
