-- Adds the decor budget cost to the House Editor's hover tooltip on placed decor.
--
-- The hook is Blizzard's own: BaseHouseEditorModeMixin:OnDecorHovered
-- (Blizzard_HouseEditorTemplates.lua, live source) builds GameTooltip from
-- C_HousingDecor.GetHoveredDecorInfo(), calls Show(), and then fires
-- EventRegistry "HousingDecorInstance.MouseOver" (mode, tooltip). Every editor
-- mode that hovers decor (basic, expert, cleanup, customize) goes through it.
-- Lines added here need a second Show() to resize the tooltip.
--
-- The cost is the catalog entry's placementCost, the same number the catalog
-- tooltip prints beside an item's name (HousingCatalogEntryMixin, live source).
--
-- Scale is NOT shown, because nothing exposes it. HousingDecorInstanceInfo
-- carries decorGUID, decorID, name, flags, dye slots, tags and catalog size --
-- no transform. C_HousingExpertMode can enter the Scale submode and reset it,
-- and HOUSING_DECOR_PRECISION_MANIPULATION_EVENT says a drag happened, but no
-- function returns the current scale (live API docs, 2026-10-02). Recheck when
-- a patch adds a getter.
--
-- One catalog lookup per hover, nothing cached across hovers, no timer.

local addonName = ...

local EditorTip = {}
_G.FabledUI_VillaEditorTip = EditorTip

EditorTip.VERSION = "0.1.0"
EditorTip.ADDON_NAME = addonName or "FabledUI_Villa_EditorTip"

local issecretvalue = _G.issecretvalue or function() return false end

local LABEL_COLOR = { 1, 0.82, 0 }
local VALUE_COLOR = { 1, 1, 1 }

function EditorTip:DB()
    local db = rawget(_G, "FabledUI_VillaEditorTipDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_VillaEditorTipDB = db
    end
    if db.enabled == nil then db.enabled = true end
    return db
end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- A plain number from a value that may be a secret (12.x tainted path).
local function plainNumber(value)
    if issecretvalue(value) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

-- decorID -> placement cost, or nil when the catalog does not answer.
function EditorTip:CostForDecor(decorID)
    decorID = plainNumber(decorID)
    if not decorID then return nil end
    local enum = rawget(_G, "Enum")
    local decorType = enum and enum.HousingCatalogEntryType and enum.HousingCatalogEntryType.Decor
    local catalog = rawget(_G, "C_HousingCatalog")
    if decorType == nil or type(catalog) ~= "table" or type(catalog.GetCatalogEntryInfoByRecordID) ~= "function" then
        return nil
    end
    local ok, info = pcall(catalog.GetCatalogEntryInfoByRecordID, decorType, decorID)
    if not ok or type(info) ~= "table" then return nil end
    return plainNumber(info.placementCost)
end

-- The decor under the cursor right now, or nil.
function EditorTip:HoveredDecor()
    local decor = rawget(_G, "C_HousingDecor")
    if type(decor) ~= "table" or type(decor.GetHoveredDecorInfo) ~= "function" then return nil end
    local ok, info = pcall(decor.GetHoveredDecorInfo)
    if ok and type(info) == "table" then return info end
    return nil
end

-- Paints the cost line. Returns true when a line was added.
function EditorTip:Paint(tooltip, decorInfo)
    if not tooltip or type(decorInfo) ~= "table" then return false end
    local cost = self:CostForDecor(decorInfo.decorID)
    if not cost then return false end
    tooltip:AddDoubleLine("Decor cost", tostring(cost),
        LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3],
        VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3])
    tooltip:Show()
    return true
end

function EditorTip:OnDecorMouseOver(tooltip)
    if not self:DB().enabled then return end
    if not tooltip then return end
    local ok, err = pcall(self.Paint, self, tooltip, self:HoveredDecor())
    if not ok then report(err) end
end

if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "HousingDecorInstance.MouseOver",
        function(_, _mode, tooltip) EditorTip:OnDecorMouseOver(tooltip) end, EditorTip)
end

-- -----------------------------------------------------------------------------
-- Slash
-- -----------------------------------------------------------------------------

SLASH_FABLEDUI_VILLAEDITORTIP1 = "/veditor"
SlashCmdList["FABLEDUI_VILLAEDITORTIP"] = function(msg)
    local db = EditorTip:DB()
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local function say(...) print("|cffffb81c[Villa Editor Tip]|r", ...) end
    if cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        say("Decor cost on editor hover " .. (db.enabled and "on." or "off."))
    else
        say("/veditor on | off  (currently " .. (db.enabled and "on" or "off") .. ")")
    end
end
