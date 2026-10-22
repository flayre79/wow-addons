-- The Prey hunt map hook. Hovering a target prints the Prey achievements that
-- finishing that hunt would advance, under Blizzard's own two lines (name,
-- "Difficulty: X").
--
-- The hunt map is Blizzard's AdventureMap with texture kit "midnight"
-- (Blizzard_AdventureMap, load-on-demand; live source 2026-10-06). Each target
-- is an AdventureMap_QuestOfferPinTemplate pin carrying questID, title and
-- description. MapCanvasMixin:AcquirePin wires every pin with
-- pin:SetScript("OnEnter", pin.OnMouseEnter) on each acquire, and the mixin's
-- methods are copied onto a pin when the pool creates it. So a hooksecurefunc
-- on AdventureMap_QuestOfferPinMixin, placed as soon as Blizzard_AdventureMap
-- loads and before any pin exists, reaches every pin. Blizzard's OnMouseEnter
-- ends with GameTooltip:Show(); lines added after it need a second Show().
--
-- A pin on any other adventure map matches no Prey criterion, and the hunt
-- achievements are only added on the Prey map, so it gets nothing.

local PreyTip = _G.FabledUI_Prey_Tooltip
if not PreyTip then return end

local MAP_ADDON = "Blizzard_AdventureMap"
local PIN_MIXIN = "AdventureMap_QuestOfferPinMixin"

local HEADER_COLOR = { 1, 0.82, 0 }
local LIVE_COLOR   = { 1, 1, 1 }
local OTHER_COLOR  = { 0.55, 0.55, 0.55 }
local NOTE_COLOR   = { 0.60, 0.60, 0.60 }
local DONE_COLOR   = { 0.45, 0.80, 0.45 }

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

function PreyTip.ProgressText(row)
    if not row.total or row.total <= 0 then return "" end
    return string.format("%d/%d", row.done, row.total)
end

-- Adds the achievement lines. Returns true when anything was added.
function PreyTip:Paint(tooltip, title, questID, description, zone)
    if not tooltip then return false end
    local offer = self.OfferDifficulty(description)
    local rows, refCount = self:RowsFor(title, questID, offer, zone)
    if refCount == 0 and #rows == 0 then return false end

    tooltip:AddLine(" ")
    if #rows == 0 then
        tooltip:AddLine("Prey achievements: nothing left for this hunt", DONE_COLOR[1], DONE_COLOR[2], DONE_COLOR[3])
        tooltip:Show()
        return true
    end

    tooltip:AddLine("Prey achievements", HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])
    for _, row in ipairs(rows) do
        local color = row.counts and LIVE_COLOR or OTHER_COLOR
        tooltip:AddDoubleLine(row.name, self.ProgressText(row),
            color[1], color[2], color[3], color[1], color[2], color[3])
        if row.note then
            tooltip:AddLine("   " .. row.note, NOTE_COLOR[1], NOTE_COLOR[2], NOTE_COLOR[3], true)
        end
    end
    tooltip:Show()
    return true
end

function PreyTip:OnPinEnter(pin)
    if not self:DB().enabled then return end
    if type(pin) ~= "table" then return end
    local tooltip = rawget(_G, "GameTooltip")
    if not tooltip then return end
    local ok, err = pcall(function()
        local questID = pin.questID
        self:Paint(tooltip, self._UsableString(pin.title), questID,
            self._UsableString(pin.description), self.Api.QuestZone(questID))
    end)
    if not ok then report(err) end
end

-- Returns true once the hook is in place.
function PreyTip:InstallHook()
    if self._hooked then return true end
    local mixin = rawget(_G, PIN_MIXIN)
    if type(mixin) ~= "table" or type(mixin.OnMouseEnter) ~= "function" then return false end
    hooksecurefunc(mixin, "OnMouseEnter", function(pin) PreyTip:OnPinEnter(pin) end)
    self._hooked = true
    return true
end

local hookFrame = CreateFrame("Frame")
hookFrame:SetScript("OnEvent", function(frame, _, loaded)
    if loaded == MAP_ADDON and PreyTip:InstallHook() then
        frame:UnregisterEvent("ADDON_LOADED")
    end
end)
hookFrame:RegisterEvent("ADDON_LOADED")
PreyTip._hookFrame = hookFrame

-- Already loaded by something earlier in the load order: hook now.
if PreyTip:InstallHook() then
    hookFrame:UnregisterEvent("ADDON_LOADED")
end

-- -----------------------------------------------------------------------------
-- Slash
-- -----------------------------------------------------------------------------

local function say(...) print("|cffd1333f[Prey Tooltip]|r", ...) end

function PreyTip:PrintStatus()
    local index = self:Index()
    say(string.format("on: %s | hooked: %s | categories: %s | achievements: %d | criteria names: %d",
        tostring(self:DB().enabled), tostring(self._hooked and true or false),
        #index.categories > 0 and table.concat(index.categories, ", ") or "none found",
        #index.achievements, index.targetCount))
    local found = {}
    for _, id in ipairs(index.achievements) do found[id] = true end
    say("Hunt achievements (by id):")
    for _, rule in ipairs(self.HUNT_ACHIEVEMENTS) do
        local name, earned = self.Api.AchievementInfo(rule.id)
        say(string.format("  %d %s%s%s", rule.id, name or "UNKNOWN ID",
            earned and " (earned)" or "", found[rule.id] and "" or " (not in the Prey category)"))
    end
    say("Target achievements:")
    for _, id in ipairs(index.achievements) do
        local entries = index.criteria[id]
        if entries and #entries > 0 then
            local name, earned = self.Api.AchievementInfo(id)
            say(string.format("  %d %s (%d criteria)%s", id, tostring(name), #entries, earned and " (earned)" or ""))
        end
    end
end

function PreyTip:PrintFind(text)
    local rows, refCount = self:RowsFor(text, nil, nil, nil)
    say(string.format("'%s' is named by %d achievement(s); every difficulty shown.", text, refCount))
    if refCount == 0 then return end
    if #rows == 0 then
        say("  Nothing left for this target.")
    end
    for _, row in ipairs(rows) do
        local progress = self.ProgressText(row)
        say(string.format("  %d %s%s%s", row.achievementID, row.name,
            progress ~= "" and ("  " .. progress) or "", row.note and ("  -- " .. row.note) or ""))
    end
end

SLASH_FABLEDUI_PREYTOOLTIP1 = "/preytip"
SlashCmdList["FABLEDUI_PREYTOOLTIP"] = function(msg)
    local db = PreyTip:DB()
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        say("Achievements on the hunt map " .. (db.enabled and "on." or "off."))
    elseif cmd == "status" then
        PreyTip:PrintStatus()
    elseif cmd == "targets" then
        local index = PreyTip:Index()
        say(string.format("%d criteria names: %s", index.targetCount, table.concat(index.names, ", ")))
    elseif cmd == "find" and rest ~= "" then
        PreyTip:PrintFind(rest)
    elseif cmd == "rescan" then
        PreyTip:ResetIndex()
        PreyTip:PrintStatus()
    else
        say("/preytip on | off | status | targets | find <name> | rescan  (currently "
            .. (db.enabled and "on" or "off") .. ")")
    end
end
