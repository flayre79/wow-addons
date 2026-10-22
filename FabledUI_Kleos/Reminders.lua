local K = Kleos

-- ============================================================================
-- Reminders
-- "Reminds for active events with achievements."
--
-- Two sources, live first:
--   calendar  C_Calendar holiday entries for today, when the client exposes
--             day events (GetDayEvent is absent on some builds, so every call
--             is type-guarded)
--   windows   Data.EVENT_WINDOWS date math, which covers the recurring
--             holidays even when the calendar is not loaded yet at login
--
-- A reminder fires once per event per day. `reminderSeen` is keyed by
-- event key + ordinal date so it self-expires instead of growing forever.
-- ============================================================================

K.Reminders = K.Reminders or {}
local Rem = K.Reminders

local SECONDS_PER_DAY = 86400

local function Today()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local now = C_DateAndTime.GetCurrentCalendarTime()
        if type(now) == "table" then
            return tonumber(now.year), tonumber(now.month), tonumber(now.monthDay)
        end
    end
    if type(date) == "function" then
        local stamp = date("*t")
        if type(stamp) == "table" then return stamp.year, stamp.month, stamp.day end
    end
    return nil, nil, nil
end

Rem.Today = Today

local function DateKey(year, month, day)
    return ("%04d%02d%02d"):format(tonumber(year) or 0, tonumber(month) or 0, tonumber(day) or 0)
end

-- Days from (month, day) to today, treating the window as this calendar year.
local function DaysUntil(month, day, todayYear, todayMonth, todayDay)
    if type(time) ~= "function" then return nil end
    local target = time({ year = todayYear, month = month, day = day, hour = 12 })
    local now = time({ year = todayYear, month = todayMonth, day = todayDay, hour = 12 })
    if not target or not now then return nil end
    return math.floor((target - now) / SECONDS_PER_DAY)
end

Rem.DaysUntil = DaysUntil

-- ----------------------------------------------------------------------------
-- Which events are relevant right now
-- Returns rows: { key, name, state = "ACTIVE"|"SOON", daysUntil, daysLeft }
-- ----------------------------------------------------------------------------
function Rem:UpcomingFromWindows(lookaheadDays)
    lookaheadDays = tonumber(lookaheadDays) or 7
    local year, month, day = Today()
    if not year then return {} end

    local rows = {}
    for _, window in ipairs(K.Data.EVENT_WINDOWS) do
        local offset = DaysUntil(window.month, window.day, year, month, day)
        if offset ~= nil then
            local duration = tonumber(window.days) or 1
            if offset <= 0 and offset > -duration then
                rows[#rows + 1] = {
                    key = window.key, name = window.name, state = "ACTIVE",
                    daysUntil = 0, daysLeft = duration + offset,
                }
            elseif offset > 0 and offset <= lookaheadDays then
                rows[#rows + 1] = {
                    key = window.key, name = window.name, state = "SOON",
                    daysUntil = offset, daysLeft = duration,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.daysUntil ~= b.daysUntil then return a.daysUntil < b.daysUntil end
        return a.name < b.name
    end)
    return rows
end

function Rem:UpcomingFromCalendar()
    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then return {} end
    local year, month, day = Today()
    if not year then return {} end

    local rows = {}
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, day)
    if not ok or not count then return {} end
    for index = 1, count do
        local okEvent, event = pcall(C_Calendar.GetDayEvent, 0, day, index)
        if okEvent and type(event) == "table" then
            local isHoliday = event.calendarType == "HOLIDAY" or event.eventType == 0
            if isHoliday and event.title then
                rows[#rows + 1] = {
                    key = "CAL:" .. tostring(event.title),
                    name = event.title,
                    state = event.sequenceType == "START" and "SOON" or "ACTIVE",
                    daysUntil = 0,
                    daysLeft = nil,
                }
            end
        end
    end
    return rows
end

function Rem:Upcoming(lookaheadDays)
    local rows = self:UpcomingFromCalendar()
    if #rows > 0 then return rows end
    return self:UpcomingFromWindows(lookaheadDays)
end

-- ----------------------------------------------------------------------------
-- Event achievements
-- The World Events category tree holds them; match the event name against
-- category names so the reminder can say how much is left to do.
-- ----------------------------------------------------------------------------
function Rem:AchievementsForEvent(eventName)
    if type(eventName) ~= "string" or eventName == "" then return {} end
    K.Catalog:Build()

    local wanted = eventName:lower()
    local categoryID
    for catID, node in pairs(K.Catalog.categories) do
        local name = type(node.name) == "string" and node.name:lower() or nil
        if name and (name == wanted or name:find(wanted, 1, true) or wanted:find(name, 1, true)) then
            categoryID = catID
            break
        end
    end
    if not categoryID then return {} end

    local ids = {}
    for _, id in ipairs(K.Catalog.order) do
        local entry = K.Catalog.entries[id]
        if entry and not entry.isStatistic and K.Catalog:CategoryMatches(entry, categoryID) then
            ids[#ids + 1] = id
        end
    end
    return ids
end

function Rem:OutstandingForEvent(eventName)
    local outstanding = {}
    for _, id in ipairs(self:AchievementsForEvent(eventName)) do
        local state = K.Catalog:GetState(id)
        if not (state and state.completed) then outstanding[#outstanding + 1] = id end
    end
    return outstanding
end

-- ----------------------------------------------------------------------------
-- Firing
-- ----------------------------------------------------------------------------
local function Seen(key)
    if not (K.db and type(K.db.reminderSeen) == "table") then return false end
    return K.db.reminderSeen[key] == true
end

local function MarkSeen(key)
    if not K.db then return end
    K.db.reminderSeen = K.db.reminderSeen or {}
    -- Keys embed the date, so old ones are dead weight: drop anything that is
    -- not today's before writing.
    local year, month, day = Today()
    local todayKey = DateKey(year, month, day)
    for existing in pairs(K.db.reminderSeen) do
        if type(existing) == "string" and not existing:find(todayKey, 1, true) then
            K.db.reminderSeen[existing] = nil
        end
    end
    K.db.reminderSeen[key] = true
    K.Storage:CommitSoon()
end

function Rem:Check(force)
    local settings = (K.db and K.db.settings) or {}
    if not force and not settings.reminders then return {} end

    local year, month, day = Today()
    local todayKey = DateKey(year, month, day)
    local fired = {}

    for _, row in ipairs(self:Upcoming(tonumber(settings.reminderDays) or 7)) do
        local seenKey = row.key .. ":" .. todayKey
        if force or not Seen(seenKey) then
            local outstanding = self:OutstandingForEvent(row.name)
            if #outstanding > 0 or row.state == "ACTIVE" then
                row.outstanding = #outstanding
                fired[#fired + 1] = row
                if not force then MarkSeen(seenKey) end
            end
        end
    end

    for _, row in ipairs(fired) do
        local when
        if row.state == "ACTIVE" then
            when = row.daysLeft and ("%s, %d day(s) left"):format(K.L.ACTIVE or "active", row.daysLeft) or (K.L.ACTIVE or "active")
        else
            when = ("starts in %d day(s)"):format(row.daysUntil or 0)
        end
        local suffix = row.outstanding and row.outstanding > 0 and (" — %d achievement(s) outstanding"):format(row.outstanding) or ""
        K:Print(("|cffffd100%s|r (%s)%s"):format(row.name, when, suffix))
    end

    if #fired > 0 and K.UI and K.UI.ShowReminderToast then
        K:SafeCall(function() K.UI:ShowReminderToast(fired) end)
    end

    return fired
end

function Rem:Init()
    if self._frame then return end
    local frame = CreateFrame("Frame")
    self._frame = frame
    frame:SetScript("OnEvent", function()
        if self._checkedAfterCalendar then return end
        self._checkedAfterCalendar = true
        K:SafeCall(function() Rem:Check() end)
    end)
    K:RegisterEvents(frame, { "CALENDAR_UPDATE_EVENT_LIST" })

    -- The calendar is usually not populated at login, so run once on a short
    -- delay and let the event above supersede it if it arrives first.
    if C_Timer and C_Timer.After then
        C_Timer.After(12, function() K:SafeCall(function() Rem:Check() end) end)
    end
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
end
