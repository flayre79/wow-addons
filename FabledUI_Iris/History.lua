local I = Iris
I.History = {}
local H = I.History

local HISTORY_SCHEMA_VERSION = 2
H.SCHEMA_VERSION = HISTORY_SCHEMA_VERSION

H.buf = {
    data = {},
    head = 1,
    len = 0,
    max = 1000,
}

local CHAT_EVENTS = {
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
    CHAT_MSG_EMOTE = "EMOTE",
    CHAT_MSG_GUILD = "GUILD",
    CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID_WARNING",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE",
    CHAT_MSG_WHISPER = "WHISPER",
    CHAT_MSG_WHISPER_INFORM = "WHISPER",
    CHAT_MSG_BN_WHISPER = "BNET",
    CHAT_MSG_BN_WHISPER_INFORM = "BNET",
    CHAT_MSG_CHANNEL = "CHANNEL",
    CHAT_MSG_SYSTEM = "SYSTEM",
    CHAT_MSG_MONSTER_SAY = "CREATURE",
    CHAT_MSG_MONSTER_YELL = "CREATURE",
    CHAT_MSG_MONSTER_EMOTE = "CREATURE",
    CHAT_MSG_MONSTER_WHISPER = "CREATURE",
    CHAT_MSG_RAID_BOSS_EMOTE = "CREATURE",
    CHAT_MSG_RAID_BOSS_WHISPER = "CREATURE",
}

local function SafeString(value)
    if I.Text and I.Text.SafeString then
        return I.Text:SafeString(value)
    end

    local ok, result = pcall(tostring, value)
    if ok and type(result) == "string" then
        return result
    end
    return ""
end

local function CleanLine(value)
    if I.Text and I.Text.CleanLine then
        return I.Text:CleanLine(value)
    end
    return SafeString(value)
end

local function ExtractURLs(value)
    if I.Text and I.Text.ExtractURLs then
        return I.Text:ExtractURLs(value)
    end
    return {}
end

local function ClampMax(value)
    local number = tonumber(value) or 1000
    if number < 50 then
        return 50
    end
    if number > 5000 then
        return 5000
    end
    return math.floor(number)
end

local function CurrentTime()
    if type(GetServerTime) == "function" then
        local ok, value = pcall(GetServerTime)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    if type(time) == "function" then
        local ok, value = pcall(time)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return 0
end

local function FormatTime(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 or type(date) ~= "function" then
        return ""
    end

    local ok, value = pcall(date, "%H:%M:%S", timestamp)
    if ok and type(value) == "string" then
        return value
    end
    return ""
end

local function CopyURLs(urls, fallbackText)
    local out = {}
    local seen = {}

    if type(urls) == "table" then
        for _, value in ipairs(urls) do
            local url = SafeString(value)
            local key = url:lower()
            if url ~= "" and not seen[key] then
                seen[key] = true
                out[#out + 1] = url
            end
        end
    else
        for _, value in ipairs(ExtractURLs(fallbackText)) do
            local key = value:lower()
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = value
            end
        end
    end

    return out
end

local function LowerNoFormatting(value)
    return SafeString(value)
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
        :lower()
end

function H:RingSetMax()
    local newMax = ClampMax(I.settings and I.settings.historySize or 1000)
    local oldMax = tonumber(self.buf.max) or newMax
    if newMax == oldMax and self.buf.len <= newMax then
        self.buf.max = newMax
        return
    end

    -- A wrapped ring's indices are defined by its old modulus. Changing max
    -- before popping corrupts the traversal whenever head is past the new cap.
    -- Snapshot in chronological order under oldMax, then rebuild at newMax.
    local entries = {}
    for offset = 0, self.buf.len - 1 do
        local index = (self.buf.head + offset - 1) % oldMax + 1
        local entry = self.buf.data[index]
        if entry then
            entries[#entries + 1] = entry
        end
    end

    self.buf.data = {}
    self.buf.head = 1
    self.buf.len = 0
    self.buf.max = newMax

    local startIndex = math.max(1, #entries - newMax + 1)
    for index = startIndex, #entries do
        self.buf.len = self.buf.len + 1
        self.buf.data[self.buf.len] = entries[index]
    end
end

function H:PopOldest()
    if self.buf.len <= 0 then
        return
    end

    self.buf.data[self.buf.head] = nil
    self.buf.head = (self.buf.head % self.buf.max) + 1
    self.buf.len = self.buf.len - 1
end

function H:NormalizeEntry(value)
    if type(value) == "string" then
        if value == "" then
            return nil
        end
        return {
            legacy = true,
            displayLine = value,
            rawLine = value,
            cleanLine = CleanLine(value),
            urls = CopyURLs(nil, value),
        }
    end

    if type(value) ~= "table" then
        return nil
    end

    local rawLine = SafeString(value.rawLine or value.raw or value.message)
    local cleanLine = SafeString(value.cleanLine or value.clean)
    if cleanLine == "" and rawLine ~= "" then
        cleanLine = CleanLine(rawLine)
    end

    local displayLine = SafeString(value.displayLine)
    if rawLine == "" and cleanLine == "" and displayLine == "" then
        return nil
    end

    local event = SafeString(value.event)
    local bucket = SafeString(value.bucket)
    if bucket == "" then
        bucket = CHAT_EVENTS[event] or ""
    end

    local timestamp = tonumber(value.timestamp)
    if timestamp then
        timestamp = math.floor(timestamp)
    end

    return {
        event = event ~= "" and event or nil,
        bucket = bucket ~= "" and bucket or nil,
        author = CleanLine(value.author),
        timestamp = timestamp,
        showTimestamp = value.showTimestamp ~= false,
        channelName = CleanLine(value.channelName),
        channelBaseName = CleanLine(value.channelBaseName),
        rawLine = rawLine,
        cleanLine = cleanLine,
        urls = CopyURLs(value.urls, cleanLine ~= "" and cleanLine or rawLine),
        displayLine = displayLine ~= "" and displayLine or nil,
        legacy = value.legacy == true or nil,
    }
end

function H:BuildEntry(event, msg, author, channelName, channelBaseName)
    local bucket = CHAT_EVENTS[event]
    if not bucket then
        return nil
    end
    if not (I.settings and I.settings.channels) then
        return nil
    end
    if not I.settings.channels[bucket] then
        return nil
    end

    local rawLine = SafeString(msg)
    local cleanLine = CleanLine(msg)
    local cleanAuthor = CleanLine(author)
    if rawLine == "" and cleanLine == "" then
        return nil
    end

    return {
        event = event,
        bucket = bucket,
        author = cleanAuthor,
        timestamp = I.settings.includeTimestamps ~= false and CurrentTime() or nil,
        showTimestamp = I.settings.includeTimestamps ~= false,
        channelName = CleanLine(channelName),
        channelBaseName = CleanLine(channelBaseName),
        rawLine = rawLine,
        cleanLine = cleanLine,
        urls = CopyURLs(nil, rawLine),
    }
end

local function RenderNormalizedEntry(entry)
    if entry.displayLine then
        return entry.displayLine
    end

    local tag = entry.bucket or "CHAT"
    if tag == "CHANNEL" then
        if entry.channelName and entry.channelName ~= "" then
            tag = entry.channelName
        elseif entry.channelBaseName and entry.channelBaseName ~= "" then
            tag = entry.channelBaseName
        end
    end

    local prefix = ""
    if entry.showTimestamp then
        local formatted = FormatTime(entry.timestamp)
        if formatted ~= "" then
            prefix = "[" .. formatted .. "] "
        end
    end

    local message = entry.cleanLine ~= "" and entry.cleanLine or entry.rawLine
    if entry.author ~= "" and tag ~= "SYSTEM" then
        return string.format("%s[%s] %s: %s", prefix, tag, entry.author, message)
    end
    return string.format("%s[%s] %s", prefix, tag, message)
end

function H:RenderEntry(value)
    local entry = self:NormalizeEntry(value)
    if not entry then
        return ""
    end
    return RenderNormalizedEntry(entry)
end

function H:Push(value)
    local entry = self:NormalizeEntry(value)
    if not entry then
        return
    end

    local maxEntries = self.buf.max
    local index = (self.buf.head + self.buf.len - 1) % maxEntries + 1

    if self.buf.len >= maxEntries then
        self.buf.head = (self.buf.head % maxEntries) + 1
        index = (self.buf.head + self.buf.len - 2) % maxEntries + 1
    else
        self.buf.len = self.buf.len + 1
    end

    self.buf.data[index] = entry
    self.dirty = true

    if not self._loading then
        self:SaveSoon()
    end
end

function H:Clear()
    self.buf.data = {}
    self.buf.head = 1
    self.buf.len = 0
    self.dirty = true
    self:Save()
end

function H:ToEntries()
    local out = {}
    if self.buf.len <= 0 then
        return out
    end

    for offset = 0, self.buf.len - 1 do
        local index = (self.buf.head + offset - 1) % self.buf.max + 1
        local entry = self.buf.data[index]
        if entry then
            out[#out + 1] = entry
        end
    end
    return out
end

-- Backwards-compatible rendered line view used by the existing history UI.
function H:ToTable()
    local out = {}
    for _, entry in ipairs(self:ToEntries()) do
        local line = RenderNormalizedEntry(entry)
        if line ~= "" then
            out[#out + 1] = line
        end
    end
    return out
end

function H:Search(query)
    query = SafeString(query):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if query == "" then
        return self:ToTable()
    end

    local out = {}
    for _, entry in ipairs(self:ToEntries()) do
        local rendered = RenderNormalizedEntry(entry)
        local fields = {
            rendered,
            entry.event or "",
            entry.bucket or "",
            entry.author or "",
            entry.channelName or "",
            entry.channelBaseName or "",
            entry.rawLine or "",
            entry.cleanLine or "",
            table.concat(entry.urls or {}, " "),
        }
        if LowerNoFormatting(table.concat(fields, " ")):find(query, 1, true) then
            out[#out + 1] = rendered
        end
    end
    return out
end

function H:Load()
    self.buf.data = {}
    self.buf.head = 1
    self.buf.len = 0

    local saved, needsMigration
    if I.Storage and I.Storage.LoadHistory then
        saved, needsMigration = I.Storage:LoadHistory()
    end
    if type(saved) ~= "table" then
        self.dirty = false
        return
    end

    self:RingSetMax()

    local entries = saved
    if type(saved.entries) == "table" then
        entries = saved.entries
        if tonumber(saved.schemaVersion) ~= HISTORY_SCHEMA_VERSION then
            needsMigration = true
        end
    else
        needsMigration = true
    end

    self._loading = true
    local startIndex = math.max(1, #entries - self.buf.max + 1)
    for index = startIndex, #entries do
        local value = entries[index]
        if type(value) == "string" then
            needsMigration = true
        end
        self:Push(value)
    end
    self._loading = nil

    if needsMigration then
        self.dirty = true
        self:Save()
    else
        self.dirty = false
    end
end

function H:Save()
    if not (I.Storage and I.Storage.SaveHistory) then
        return
    end

    local payload = {
        schemaVersion = HISTORY_SCHEMA_VERSION,
        entries = self:ToEntries(),
    }
    if I.Storage:SaveHistory(payload) then
        self.dirty = false
    end
end

function H:SaveSoon()
    if I.Util and I.Util.SaveSoon then
        I.Util:SaveSoon("iris.history", function() self:Save() end)
    else
        self:Save()
    end
end

-- Retained for callers/tests that need the final readable line without keeping
-- a second formatting implementation beside the structured entry builder.
function H:FormatLine(event, msg, author, channelName, channelBaseName)
    local entry = self:BuildEntry(event, msg, author, channelName, channelBaseName)
    if not entry then
        return nil
    end
    return self:RenderEntry(entry)
end

function H:Init()
    if self._inited then
        return
    end
    self._inited = true

    self:RingSetMax()
    self:Load()

    local frame = CreateFrame("Frame")
    self.eventFrame = frame

    for eventName in pairs(CHAT_EVENTS) do
        frame:RegisterEvent(eventName)
    end
    frame:RegisterEvent("PLAYER_LOGOUT")

    frame:SetScript("OnEvent", function(_, event, msg, author, languageName, channelName, target, flags, zoneChannelID, channelIndex, channelBaseName)
        local ok, err = pcall(function()
            if event == "PLAYER_LOGOUT" then
                if I.Util and I.Util.Flush then
                    I.Util:Flush()
                end
                self:Save()
                return
            end

            if not I.settings or not I.settings.enableHistory then
                return
            end

            local entry = self:BuildEntry(event, msg, author, channelName, channelBaseName)
            if entry then
                self:Push(entry)
            end
        end)
        if not ok then
            self._errorCount = (self._errorCount or 0) + 1
            if self._errorCount <= 3 then
                print("|cffff5555[Iris.History]|r " .. tostring(err))
            end
        end
    end)
end
