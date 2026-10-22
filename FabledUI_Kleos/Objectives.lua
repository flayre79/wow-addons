local K = Kleos

-- ============================================================================
-- Objectives
-- "Custom objectives for certain achievements" from the Kleos scope doc, in
-- two flavours:
--
--   registered  objective packs shipped as data (the encounter sibling and the
--               open API register these) that clarify criteria Blizzard states
--               badly — e.g. an achievement whose single criterion is "Defeat
--               X" but actually needs four separate things done first
--   custom      free-text checklists the player writes themselves, persisted
--               per account through DataVault
--
-- Both render through the same shape as Meta:Breakdown steps so the detail
-- pane and tracker do not need to care which kind they are drawing.
-- ============================================================================

K.Objectives = K.Objectives or {}
local O = K.Objectives

O.registered = O.registered or {}   -- achievementID -> { { text, hint, link }, ... }

local MAX_TEXT = 200
local MAX_PER_ACHIEVEMENT = 25

-- ----------------------------------------------------------------------------
-- Registered packs
-- ----------------------------------------------------------------------------
function O:Register(achievementID, objectives, source)
    achievementID = tonumber(achievementID)
    if not achievementID or type(objectives) ~= "table" then return false end

    local clean = {}
    for _, objective in ipairs(objectives) do
        local text, hint, link
        if type(objective) == "string" then
            text = objective
        elseif type(objective) == "table" then
            text = objective.text or objective[1]
            hint = objective.hint
            link = objective.link
        end
        if type(text) == "string" and text ~= "" then
            clean[#clean + 1] = {
                text = text:sub(1, MAX_TEXT),
                hint = type(hint) == "string" and hint:sub(1, MAX_TEXT) or nil,
                link = type(link) == "table" and link or nil,
                source = source or "registered",
            }
        end
        if #clean >= MAX_PER_ACHIEVEMENT then break end
    end

    if #clean == 0 then return false end
    self.registered[achievementID] = clean
    return true
end

function O:GetRegistered(achievementID)
    achievementID = tonumber(achievementID)
    return achievementID and self.registered[achievementID] or nil
end

function O:HasRegistered(achievementID)
    return self:GetRegistered(achievementID) ~= nil
end

-- ----------------------------------------------------------------------------
-- Player-authored checklists
-- ----------------------------------------------------------------------------
local function Bucket(create)
    if not K.db then return nil end
    if type(K.db.customObjectives) ~= "table" then
        if not create then return nil end
        K.db.customObjectives = {}
    end
    return K.db.customObjectives
end

function O:List(achievementID)
    achievementID = tonumber(achievementID)
    local bucket = Bucket(false)
    local list = achievementID and bucket and bucket[achievementID]
    if type(list) ~= "table" then return {} end
    return list
end

function O:Add(achievementID, text)
    achievementID = tonumber(achievementID)
    if not achievementID then return false end
    text = tostring(text or ""):match("^%s*(.-)%s*$") or ""
    if text == "" then return false end

    local bucket = Bucket(true)
    if not bucket then return false end
    bucket[achievementID] = bucket[achievementID] or {}
    local list = bucket[achievementID]
    if #list >= MAX_PER_ACHIEVEMENT then return false end

    list[#list + 1] = { text = text:sub(1, MAX_TEXT), done = false }
    K.Storage:CommitSoon()
    return true
end

function O:Remove(achievementID, index)
    achievementID = tonumber(achievementID)
    index = tonumber(index)
    if not achievementID or not index then return false end
    local bucket = Bucket(false)
    local list = bucket and bucket[achievementID]
    if type(list) ~= "table" or not list[index] then return false end
    table.remove(list, index)
    if #list == 0 then bucket[achievementID] = nil end
    K.Storage:CommitSoon()
    return true
end

function O:Toggle(achievementID, index)
    achievementID = tonumber(achievementID)
    index = tonumber(index)
    if not achievementID or not index then return false end
    local bucket = Bucket(false)
    local list = bucket and bucket[achievementID]
    local objective = type(list) == "table" and list[index] or nil
    if type(objective) ~= "table" then return false end
    objective.done = not objective.done
    K.Storage:CommitSoon()
    return objective.done
end

function O:Clear(achievementID)
    achievementID = tonumber(achievementID)
    local bucket = Bucket(false)
    if not achievementID or not bucket then return false end
    bucket[achievementID] = nil
    K.Storage:CommitSoon()
    return true
end

-- ----------------------------------------------------------------------------
-- Combined view: registered pack first, then the player's own checklist. The
-- shape matches Meta:Breakdown so callers can concatenate the two lists.
-- ----------------------------------------------------------------------------
function O:Steps(achievementID)
    achievementID = tonumber(achievementID)
    if not achievementID then return {} end

    local steps = {}
    for index, objective in ipairs(self:GetRegistered(achievementID) or {}) do
        steps[#steps + 1] = {
            kind = "objective",
            index = index,
            text = objective.text,
            hint = objective.hint,
            link = objective.link,
            completed = false,
            editable = false,
            source = objective.source,
        }
    end
    for index, objective in ipairs(self:List(achievementID)) do
        steps[#steps + 1] = {
            kind = "custom",
            index = index,
            text = objective.text,
            completed = objective.done and true or false,
            editable = true,
        }
    end
    return steps
end

function O:Count(achievementID)
    local registered = self:GetRegistered(achievementID)
    return (registered and #registered or 0) + #self:List(achievementID)
end
