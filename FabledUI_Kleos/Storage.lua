local K = Kleos

K.Storage = K.Storage or {}
local S = K.Storage

local ADDON_KEY = "kleos"

local DEFAULT_FILTERS = {
    tab = "BROWSE",
    browseMode = "ALL",
    sort = "NAME",
    search = "",
    expansion = "ALL",
    kind = "ALL",
    category = "ALL",
    completion = "ALL",
    reward = "ALL",
    faction = "ALL",
    obtainable = "ALL",
    saturation = "MIXED",
    compact = false,
    showTracking = false,
    showStatistics = false,
    showExcluded = false,
    page = 1,
}

local DEFAULTS = {
    schema = 3,
    watchlist = {},
    excluded = {},
    notes = {},
    tactics = {},
    customObjectives = {},
    charEarned = {},
    characterSnapshots = {},
    earnedHistory = {},
    reminderSeen = {},
    profiles = {
        Default = { filters = DEFAULT_FILTERS },
    },
    activeProfile = "Default",
    settings = {
        lockFrames = false,
        tooltips = true,
        unitItemTooltips = true,
        reminders = true,
        reminderDays = 7,
        announce = false,
        announceThrottleSec = 60,
        tutorialSeen = false,
        skin = "AUTO",
        tracker = {
            enabled = false,
            autoShow = true,
            mode = "INSTANCE",
            windowState = { width = 400, height = 360 },
        },
        main = {
            windowState = { width = 1040, height = 700 },
        },
        filters = DEFAULT_FILTERS,
    },
}

K.Storage.DEFAULT_FILTERS = DEFAULT_FILTERS

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
    end
    return copy
end

local function DeepMergeMissing(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then dst[key] = {} end
            DeepMergeMissing(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

K.DeepCopy = K.DeepCopy or DeepCopy

local function DataVaultBackend()
    if not DataVault or type(DataVault.IsAvailable) ~= "function" then return nil end
    local ok, available = pcall(DataVault.IsAvailable, DataVault)
    if not ok or not available then return nil end
    if type(DataVault.Get) ~= "function" or type(DataVault.Set) ~= "function" or type(DataVault.Mutate) ~= "function" then
        return nil
    end
    return DataVault
end

local function FallbackRoot(scope)
    if scope == "character" or scope == "char" then
        FabledUI_KleosCharDB = FabledUI_KleosCharDB or {}
        return FabledUI_KleosCharDB
    end
    FabledUI_KleosDB = FabledUI_KleosDB or {}
    return FabledUI_KleosDB
end

local function Traverse(root, path, create)
    local node = root
    for index = 1, #path do
        local segment = path[index]
        if type(node) ~= "table" then return nil end
        if node[segment] == nil and create then node[segment] = {} end
        node = node[segment]
        if node == nil then return nil end
    end
    return node
end

function S:IsDataVault()
    return DataVaultBackend() ~= nil
end

function S:Get(scope, path, defaultValue)
    path = type(path) == "table" and path or {}
    local backend = DataVaultBackend()
    local value
    if backend then
        value = backend:Get(scope, ADDON_KEY, unpack(path))
    else
        value = Traverse(FallbackRoot(scope), path, false)
    end
    if value == nil then return defaultValue end
    return value
end

function S:Set(scope, path, value)
    path = type(path) == "table" and path or {}
    local backend = DataVaultBackend()
    if backend then
        if #path == 0 then
            return backend:Set(scope, ADDON_KEY, nil, value)
        end
        return backend:Set(scope, ADDON_KEY, unpack(path), value)
    end

    if #path == 0 then
        if type(value) ~= "table" then return false end
        if scope == "character" or scope == "char" then
            FabledUI_KleosCharDB = value
        else
            FabledUI_KleosDB = value
        end
        return true
    end

    local root = FallbackRoot(scope)
    local parentPath = {}
    for index = 1, #path - 1 do parentPath[index] = path[index] end
    local parent = Traverse(root, parentPath, true)
    if type(parent) ~= "table" then return false end
    parent[path[#path]] = value
    return true
end

function S:Mutate(scope, path, fn)
    if type(fn) ~= "function" then return nil end
    path = type(path) == "table" and path or {}
    local backend = DataVaultBackend()
    if backend then
        if #path == 0 then
            return backend:Mutate(scope, ADDON_KEY, fn)
        end
        return backend:Mutate(scope, ADDON_KEY, unpack(path), fn)
    end
    local updated = fn(self:Get(scope, path))
    self:Set(scope, path, updated)
    return updated
end

function S:CommitSoon()
    local function Commit()
        if K.db then S:Set("account", {}, K.db) end
    end
    if K.Util and K.Util.SaveSoon then
        K.Util:SaveSoon("kleos.db", Commit)
    else
        Commit()
    end
end

local function EnsureProfile(db, name)
    name = tostring(name or "Default")
    db.profiles = db.profiles or {}
    if type(db.profiles[name]) ~= "table" then db.profiles[name] = {} end
    if type(db.profiles[name].filters) ~= "table" then db.profiles[name].filters = {} end
    DeepMergeMissing(db.profiles[name].filters, DEFAULT_FILTERS)
    return db.profiles[name]
end

function K:ResolveStorage()
    local db = S:Get("account", {}, nil)
    if type(db) ~= "table" then db = {} end
    DeepMergeMissing(db, DeepCopy(DEFAULTS))

    -- Migrate the v1 single-filter table into the default named profile.
    local active = tostring(db.activeProfile or "Default")
    local profile = EnsureProfile(db, active)
    if type(db.settings.filters) == "table" then
        for key, value in pairs(db.settings.filters) do
            if profile.filters[key] == nil or active == "Default" then
                profile.filters[key] = value
            end
        end
    end
    db.settings.filters = profile.filters
    db.activeProfile = active

    -- Schema 3 added the kind / obtainable / tracking filters and the custom
    -- objectives bucket. Every profile gets the new keys, not just the active
    -- one, so switching profile can never land on a nil filter value.
    if (tonumber(db.schema) or 0) < 3 then
        for _, storedProfile in pairs(db.profiles) do
            if type(storedProfile) == "table" and type(storedProfile.filters) == "table" then
                DeepMergeMissing(storedProfile.filters, DEFAULT_FILTERS)
            end
        end
        if type(db.customObjectives) ~= "table" then db.customObjectives = {} end
    end
    db.schema = 3

    self.db = db
    self._storageBackend = S:IsDataVault() and "DataVault" or "Local SVs"
    S:Set("account", {}, db)
    self:UpdateCharacterSnapshot()
end

function K:GetCharacterKey()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Realm"
    return string.format("%s-%s", tostring(name), tostring(realm))
end

function K:GetFilters()
    if not self.db then return DeepCopy(DEFAULT_FILTERS) end
    local profile = EnsureProfile(self.db, self.db.activeProfile)
    self.db.settings.filters = profile.filters
    return profile.filters
end

function K:ListProfiles()
    local names = {}
    for name in pairs((self.db and self.db.profiles) or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function K:SetProfile(name)
    if not self.db then return false end
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return false end
    local profile = EnsureProfile(self.db, name)
    self.db.activeProfile = name
    self.db.settings.filters = profile.filters
    S:CommitSoon()
    if self.UI and self.UI.Refresh then self.UI:Refresh() end
    return true
end

function K:DeleteProfile(name)
    if not self.db or name == "Default" or name == self.db.activeProfile then return false end
    if not self.db.profiles[name] then return false end
    self.db.profiles[name] = nil
    S:CommitSoon()
    return true
end

function K:IsWatched(id)
    return self.db and self.db.watchlist[tonumber(id)] == true or false
end

function K:SetWatched(id, value)
    id = tonumber(id)
    if not id or not self.db then return false end
    S:Mutate("account", { "watchlist" }, function(list)
        list = type(list) == "table" and list or {}
        list[id] = value and true or nil
        return list
    end)
    self.db.watchlist[id] = value and true or nil
    S:CommitSoon()
    return true
end

function K:IsExcluded(id)
    return self.db and self.db.excluded[tonumber(id)] == true or false
end

function K:SetExcluded(id, value)
    id = tonumber(id)
    if not id or not self.db then return false end
    S:Mutate("account", { "excluded" }, function(list)
        list = type(list) == "table" and list or {}
        list[id] = value and true or nil
        return list
    end)
    self.db.excluded[id] = value and true or nil
    S:CommitSoon()
    return true
end

function K:SetNote(id, note)
    id = tonumber(id)
    if not id or not self.db then return false end
    note = tostring(note or ""):sub(1, 2000)
    self.db.notes[id] = note ~= "" and note or nil
    S:CommitSoon()
    return true
end

function K:GetNote(id)
    return self.db and self.db.notes[tonumber(id)] or nil
end

function K:SetTactic(id, text)
    id = tonumber(id)
    if not id or not self.db then return false end
    text = tostring(text or ""):sub(1, 4000)
    self.db.tactics[id] = text ~= "" and text or nil
    S:CommitSoon()
    return true
end

function K:RecordEarned(id)
    id = tonumber(id)
    if not id or not self.db then return end
    local key = self:GetCharacterKey()
    self.db.charEarned[key] = self.db.charEarned[key] or {}
    self.db.charEarned[key][id] = true

    local _, _, _, _, month, day, year = GetAchievementInfo(id)
    self.db.earnedHistory[id] = {
        timestamp = GetServerTime and GetServerTime() or time(),
        year = tonumber(year), month = tonumber(month), day = tonumber(day),
        character = key,
    }
    self:UpdateCharacterSnapshot()
    S:CommitSoon()
end

function K:IsEarnedByChar(id, characterKey)
    if not self.db then return false end
    characterKey = characterKey or self:GetCharacterKey()
    local earned = self.db.charEarned and self.db.charEarned[characterKey]
    return type(earned) == "table" and earned[tonumber(id)] == true or false
end

function K:UpdateCharacterSnapshot()
    if not self.db then return end
    local key = self:GetCharacterKey()
    local earned = self.db.charEarned[key] or {}
    local count = 0
    for _, value in pairs(earned) do if value then count = count + 1 end end
    self.db.characterSnapshots[key] = {
        points = GetTotalAchievementPoints and (GetTotalAchievementPoints() or 0) or 0,
        earned = count,
        updated = GetServerTime and GetServerTime() or time(),
    }
end

local function SortedIDs(set)
    local ids = {}
    for id, value in pairs(set or {}) do
        id = tonumber(id)
        if value and id and id > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for index, id in ipairs(ids) do ids[index] = tostring(id) end
    return table.concat(ids, ",")
end

local function HexEncode(text)
    return (tostring(text or ""):gsub(".", function(char) return string.format("%02X", string.byte(char)) end))
end

local function HexDecode(text)
    if type(text) ~= "string" or #text % 2 ~= 0 or text:find("[^0-9A-Fa-f]") then return nil end
    return (text:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
end

function S:Export()
    local db = K.db or {}
    -- Header lines keep their order; the payload lines are sorted separately so
    -- two exports of the same data are byte-identical (pairs() order is not
    -- stable). `table.sort(lines, 4)` used to stand in for that and threw
    -- "attempt to call a number value" as soon as there was anything to sort.
    local header = {
        "KLEOS2",
        "W\t" .. SortedIDs(db.watchlist),
        "X\t" .. SortedIDs(db.excluded),
    }
    local lines = {}
    for id, note in pairs(db.notes or {}) do
        if tonumber(id) and type(note) == "string" and note ~= "" then
            lines[#lines + 1] = "N\t" .. tostring(id) .. "\t" .. HexEncode(note)
        end
    end
    for id, tactic in pairs(db.tactics or {}) do
        if tonumber(id) and type(tactic) == "string" and tactic ~= "" then
            lines[#lines + 1] = "T\t" .. tostring(id) .. "\t" .. HexEncode(tactic)
        end
    end
    -- Custom objectives: one line per objective, done-flag prefixed, so a
    -- partially ticked checklist survives the round trip.
    for id, objectives in pairs(db.customObjectives or {}) do
        if tonumber(id) and type(objectives) == "table" then
            for _, objective in ipairs(objectives) do
                if type(objective) == "table" and type(objective.text) == "string" and objective.text ~= "" then
                    lines[#lines + 1] = "O\t" .. tostring(id) .. "\t"
                        .. (objective.done and "1" or "0") .. HexEncode(objective.text)
                end
            end
        end
    end
    table.sort(lines)
    for _, line in ipairs(lines) do header[#header + 1] = line end
    return table.concat(header, "\n")
end

local function ImportIDs(text, target)
    local count = 0
    for token in tostring(text or ""):gmatch("%d+") do
        local id = tonumber(token)
        if id and id > 0 and id < 1000000000 then
            target[id] = true
            count = count + 1
            if count >= 10000 then break end
        end
    end
    return count
end

function S:Import(text, replace)
    if type(text) ~= "string" or #text > 1048576 or text:sub(1, 6) ~= "KLEOS2" then
        return false, "Unsupported or oversized import"
    end
    local db = K.db
    if not db then return false, "Storage unavailable" end
    local watch = replace and {} or DeepCopy(db.watchlist or {})
    local excluded = replace and {} or DeepCopy(db.excluded or {})
    local notes = replace and {} or DeepCopy(db.notes or {})
    local tactics = replace and {} or DeepCopy(db.tactics or {})
    local objectives = replace and {} or DeepCopy(db.customObjectives or {})
    local imported = 0

    for line in text:gmatch("[^\r\n]+") do
        local kind, first, second = line:match("^(%u)\t([^\t]*)\t?(.*)$")
        if kind == "W" then imported = imported + ImportIDs(first, watch)
        elseif kind == "X" then imported = imported + ImportIDs(first, excluded)
        elseif (kind == "N" or kind == "T") and tonumber(first) then
            local decoded = HexDecode(second)
            if decoded then
                if kind == "N" then notes[tonumber(first)] = decoded:sub(1, 2000)
                else tactics[tonumber(first)] = decoded:sub(1, 4000) end
                imported = imported + 1
            end
        elseif kind == "O" and tonumber(first) then
            -- "O<tab>id<tab><doneFlag><hex text>"
            local flag, payload = second:match("^([01])(.*)$")
            local decoded = payload and HexDecode(payload) or nil
            local id = tonumber(first)
            if id and decoded and decoded ~= "" then
                objectives[id] = objectives[id] or {}
                local bucket = objectives[id]
                if #bucket < 25 then
                    bucket[#bucket + 1] = { text = decoded:sub(1, 200), done = flag == "1" }
                    imported = imported + 1
                end
            end
        end
    end

    db.watchlist, db.excluded, db.notes, db.tactics = watch, excluded, notes, tactics
    db.customObjectives = objectives
    S:CommitSoon()
    return true, imported
end

function S:Compact()
    if not K.db then return 0 end
    local removed = 0
    for _, key in ipairs({ "watchlist", "excluded", "notes", "tactics", "earnedHistory" }) do
        local bucket = K.db[key]
        if type(bucket) == "table" then
            for id, value in pairs(bucket) do
                if not tonumber(id) or value == nil or value == false or value == "" then
                    bucket[id] = nil
                    removed = removed + 1
                end
            end
        end
    end
    -- Objective buckets are arrays; an empty one is dead weight keyed by an
    -- achievement id that no longer has a checklist.
    for id, objectives in pairs(K.db.customObjectives or {}) do
        if type(objectives) ~= "table" or #objectives == 0 or not tonumber(id) then
            K.db.customObjectives[id] = nil
            removed = removed + 1
        end
    end
    for character, earned in pairs(K.db.charEarned or {}) do
        if type(earned) ~= "table" then
            K.db.charEarned[character] = nil
            removed = removed + 1
        else
            for id, value in pairs(earned) do
                if not tonumber(id) or not value then earned[id] = nil; removed = removed + 1 end
            end
        end
    end
    S:CommitSoon()
    return removed
end

function S:ResetUserData()
    local preservedWindow = K.db and K.db.settings and DeepCopy(K.db.settings.main.windowState) or nil
    local db = DeepCopy(DEFAULTS)
    if preservedWindow then db.settings.main.windowState = preservedWindow end
    K.db = db
    S:Set("account", {}, db)
    K:SetProfile("Default")
    return true
end
