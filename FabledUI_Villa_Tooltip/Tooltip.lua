-- Paints the card into tooltips.
--
-- Two ways a decor tooltip appears:
--
--   1. The housing catalog. HousingCatalogEntryMixin:OnEnter builds GameTooltip
--      by hand and then fires EventRegistry "HousingCatalogEntry.TooltipCreated"
--      (entry, tooltip) BEFORE tooltip:Show() -- Blizzard's own extension point
--      (Blizzard_HousingCatalogEntry.lua, live source). The entry carries
--      entryInfo with sourceText. No frame is hooked.
--
--   2. An item tooltip (bags, vendor, chat link). TooltipDataProcessor post-call
--      for Item; the item id maps to a decor record through
--      C_Housing.GetDecorItemInfoFromItemID, then the static DecorIndex. On
--      12.x anything read in a post-call can be a secret value, so the id goes
--      through issecretvalue before type() (CLAUDE.md, secret values).
--
-- Nothing here is cached across hovers and nothing runs on a timer.

local Tip = _G.FabledUI_VillaTooltip
local Decor = _G.FabledUI_VillaDecor
if not (Tip and Decor) then return end

local issecretvalue = _G.issecretvalue or function() return false end

local HEADER = { 1, 0.82, 0 }
local NORMAL = { 1, 1, 1 }
local DIM = { 0.7, 0.7, 0.7 }
local STATUS_COLOR = { met = "|cff55dd55", unmet = "|cffff5050", unknown = "|cffffd24a" }
local STATUS_WORD = { met = "done", unmet = "not yet", unknown = "unverified" }
local FACTION_ICON = {
    Alliance = "|TInterface\\FriendsFrame\\PlusManz-Alliance:14:14|t ",
    Horde    = "|TInterface\\FriendsFrame\\PlusManz-Horde:14:14|t ",
}

function Tip:DB()
    local db = rawget(_G, "FabledUI_VillaTooltipDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_VillaTooltipDB = db
    end
    if db.enabled == nil then db.enabled = true end
    if db.materials == nil then db.materials = true end
    if db.criteria == nil then db.criteria = true end
    if db.items == nil then db.items = true end
    return db
end

local function status(s)
    return (STATUS_COLOR[s] or STATUS_COLOR.unknown) .. (STATUS_WORD[s] or "?") .. "|r"
end

local function addLine(tooltip, text, color, wrap)
    tooltip:AddLine(text, color[1], color[2], color[3], wrap and true or false)
end

local function addDouble(tooltip, left, right, leftColor, rightColor)
    tooltip:AddDoubleLine(left, right, leftColor[1], leftColor[2], leftColor[3], rightColor[1], rightColor[2], rightColor[3])
end

-- Paints one card. Returns the number of lines added.
function Tip:Paint(tooltip, card)
    if not tooltip or type(card) ~= "table" then return 0 end
    local db = self:DB()
    local lines = 0
    local function line(...) lines = lines + 1 addLine(tooltip, ...) end
    local function double(...) lines = lines + 1 addDouble(tooltip, ...) end

    if #card.kinds == 0 then
        line(" ", NORMAL)
        line("Source: not listed by the game", DIM)
        return lines
    end

    -- Labels are flush left, no space-indents: in a proportional font a run of
    -- spaces is a different width on every line, and the column wandered
    -- (owner's screenshot, 2026-09-21). Hierarchy is carried by colour instead:
    -- gold section heads, grey detail labels.
    line(" ", NORMAL)
    line("Source: " .. table.concat(card.kinds, ", "), HEADER)

    for _, vendor in ipairs(card.vendors) do
        local name = (FACTION_ICON[vendor.faction] or "") .. vendor.name
        double("Vendor", name, DIM, NORMAL)
        if vendor.zone ~= "" then double("Where", vendor.zone, DIM, NORMAL) end
        if vendor.costText ~= "" then double("Cost", vendor.costText, DIM, NORMAL) end
        for _, gate in ipairs(vendor.gates) do
            double("Needs", gate.label .. "  " .. status(gate.status), DIM, NORMAL)
        end
    end

    for _, drop in ipairs(card.drops) do
        double("Drops from", drop.boss, DIM, NORMAL)
        if drop.place then double("In", drop.place, DIM, NORMAL) end
    end

    for _, craft in ipairs(card.crafts) do
        local text = craft.profession .. (craft.level and (" (" .. craft.level .. ")") or "")
        double("Crafted by", text, DIM, NORMAL)
        if craft.known == true then
            double("Recipe", STATUS_COLOR.met .. "known|r", DIM, NORMAL)
        elseif craft.known == false then
            double("Recipe", STATUS_COLOR.unmet .. "not known|r", DIM, NORMAL)
            if craft.learnFrom then
                double("Learn from", craft.learnFrom, DIM, NORMAL)
            end
        end
        if db.materials then
            for _, mat in ipairs(craft.materials) do
                local have = mat.have
                local right = tostring(mat.need)
                if have then
                    local color = have >= mat.need and STATUS_COLOR.met or STATUS_COLOR.unmet
                    right = color .. have .. "|r/" .. mat.need
                end
                double("Material", mat.name .. "  " .. right, DIM, NORMAL)
            end
        end
    end

    for _, ach in ipairs(card.achievements) do
        double("Achievement", ach.name .. (ach.category and (" (" .. ach.category .. ")") or ""), DIM, NORMAL)
        double("Status", status(ach.status), DIM, NORMAL)
        if db.criteria then
            for _, crit in ipairs(ach.criteria) do
                local mark = crit.completed and STATUS_COLOR.met .. "+|r " or STATUS_COLOR.unmet .. "-|r "
                double("", mark .. crit.text, DIM, NORMAL)
            end
            if ach.criteriaTotal > #ach.criteria then
                double("", "... and " .. (ach.criteriaTotal - #ach.criteria) .. " more", DIM, DIM)
            end
        end
    end

    for _, quest in ipairs(card.quests) do
        double("Quest", quest.name .. "  " .. status(quest.status), DIM, NORMAL)
    end
    for _, treasure in ipairs(card.treasures) do
        double("Treasure", treasure.name .. (treasure.place and (", " .. treasure.place) or ""), DIM, NORMAL)
    end
    for _, event in ipairs(card.events) do
        double("Event", event.name, DIM, NORMAL)
    end

    if card.expansion or #card.zones > 0 then
        local where = table.concat(card.zones, ", ")
        if card.expansion then
            where = card.expansion .. (where ~= "" and (" - " .. where) or "")
        end
        double("From", where, DIM, NORMAL)
    end
    return lines
end

-- -----------------------------------------------------------------------------
-- Hook 1: the catalog
-- -----------------------------------------------------------------------------

function Tip:OnCatalogTooltip(entry, tooltip)
    if not self:DB().enabled then return end
    local info = type(entry) == "table" and entry.entryInfo or nil
    if type(info) ~= "table" then return end
    local ok, card = pcall(self.BuildCard, self, info)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(card) end
        return
    end
    self:Paint(tooltip, card)
end

if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "HousingCatalogEntry.TooltipCreated",
        function(_, entry, tooltip) Tip:OnCatalogTooltip(entry, tooltip) end, Tip)
end

-- -----------------------------------------------------------------------------
-- Hook 2: item tooltips
-- -----------------------------------------------------------------------------

function Tip:DecorEntryForItem(itemID)
    if issecretvalue(itemID) then return nil end
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local decorID
    if C_Housing and C_Housing.GetDecorItemInfoFromItemID then
        local ok, info = pcall(C_Housing.GetDecorItemInfoFromItemID, itemID)
        if ok and type(info) == "table" and not issecretvalue(info.decorID) then
            decorID = tonumber(info.decorID)
        end
    end
    if not decorID then
        local providers = rawget(_G, "FabledUI_DataVault_VillaProviders")
        local index = type(providers) == "table" and providers["codex"] and providers["codex"].DecorIndex
        if type(index) == "table" and type(index.ItemToDecor) == "table" then
            decorID = tonumber(index.ItemToDecor[itemID])
        end
    end
    if not decorID then return nil end

    local enum = rawget(_G, "Enum")
    local decorType = enum and enum.HousingCatalogEntryType and enum.HousingCatalogEntryType.Decor
    if decorType == nil or not (C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID) then return nil end
    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, decorType, decorID)
    if ok and type(info) == "table" then return info end
    return nil
end

function Tip:OnItemTooltip(tooltip, data)
    local db = self:DB()
    if not db.enabled or not db.items then return end
    if tooltip ~= GameTooltip and tooltip ~= rawget(_G, "ItemRefTooltip") then return end
    if type(data) ~= "table" then return end
    local info = self:DecorEntryForItem(data.id)
    if not info then return end
    local ok, card = pcall(self.BuildCard, self, info)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(card) end
        return
    end
    self:Paint(tooltip, card)
end

local processor = rawget(_G, "TooltipDataProcessor")
local enum = rawget(_G, "Enum")
if type(processor) == "table" and type(processor.AddTooltipPostCall) == "function"
    and enum and enum.TooltipDataType and enum.TooltipDataType.Item then
    pcall(processor.AddTooltipPostCall, enum.TooltipDataType.Item,
        function(tooltip, data) Tip:OnItemTooltip(tooltip, data) end)
end

-- -----------------------------------------------------------------------------
-- Slash
-- -----------------------------------------------------------------------------

SLASH_FABLEDUI_VILLATOOLTIP1 = "/vtip"
SlashCmdList["FABLEDUI_VILLATOOLTIP"] = function(msg)
    local db = Tip:DB()
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local function say(...) print("|cffffb81c[Villa Tooltip]|r", ...) end
    if cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        say("Decor source lines " .. (db.enabled and "on." or "off."))
    elseif cmd == "materials" or cmd == "criteria" or cmd == "items" then
        db[cmd] = not db[cmd]
        say(cmd .. ": " .. (db[cmd] and "shown" or "hidden"))
    else
        say(string.format("/vtip on | off | materials (%s) | criteria (%s) | items (%s: also on bag and vendor item tooltips)",
            db.materials and "shown" or "hidden", db.criteria and "shown" or "hidden", db.items and "on" or "off"))
    end
end
