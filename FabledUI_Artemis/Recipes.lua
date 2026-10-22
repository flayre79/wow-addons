local A = FabledUI_Artemis or Artemis

-- Tracked profession recipes.
--
-- Default-tracker parity. Blizzard's objective tracker carries a
-- ProfessionsRecipeTracker module: recipes you track from the profession UI
-- show up with a live have/need count per required reagent. Artemis hides the
-- Blizzard tracker by default (profile.hideDefaultTracker), so without this
-- module a tracked recipe renders *nowhere* -- the player tracks it, nothing
-- appears, and there is no error to explain why.
--
-- Precedent: !KalielsTracker/Core/ProfessionsRecipeTracker.lua, which is the
-- same Blizzard module reimplemented. It reads
-- C_TradeSkillUI.GetRecipesTracked(isRecraft) for both the normal and recraft
-- lists, walks recipeSchematic.reagentSlotSchematics, and counts only the
-- *required* slots. Optional/finishing reagents are deliberately not shown --
-- they are a crafting choice, not an outstanding errand.
--
-- Entry contract mirrors Scenario/Currency so the tracker renderer stays a
-- simple switch on section key:
--   { id, isName = true, text = <recipe name>, recipeID, isRecraft }
--   { id, text = <reagent name>, quantity, totalQuantity, completed,
--     recipeID, isRecraft }                          -- fixed-quantity slot
--   { id, text = <reagent name>, rangeText = "2-4", recipeID, isRecraft }
--                                                    -- variable-quantity slot
--
-- Every read of the live API goes through a `_`-prefixed seam below. The
-- simulator shadows its own globals, so C_TradeSkillUI cannot be stubbed from
-- a test (CLAUDE.md, "The simulator"); overriding a module method can be, and
-- that is how tests/recipes.lua drives fixtures through the real build logic.
A.Recipes = A.Recipes or {}
local R = A.Recipes

-- Blizzard encodes a recraft block as the negated recipe ID (NegateIf). We keep
-- the same convention so an entry ID is stable and collision-free across the
-- two lists.
local function BlockID(recipeID, isRecraft)
    return isRecraft and -recipeID or recipeID
end

R.MAX_RECIPES = 12

function R:IsAvailable()
    return type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetRecipesTracked) == "function"
end

function R:IsSectionEnabled()
    if not A:IsModuleEnabled("recipes") then
        return false
    end
    local prefs = A.profile and A.profile.recipeTracker
    if not prefs or prefs.enabled == nil then
        return true
    end
    return prefs.enabled == true
end

function R:SetSectionEnabled(enabled)
    A.profile.recipeTracker = A.profile.recipeTracker or {}
    A.profile.recipeTracker.enabled = enabled and true or false
end

-- --------------------------------------------------------------------------
-- Live-API seams. Each one returns a safe empty/nil value rather than raising,
-- so a client that renamed an API degrades to "no recipes" instead of killing
-- the render pass.
-- --------------------------------------------------------------------------

function R:_GetTrackedRecipeIDs(isRecraft)
    if not self:IsAvailable() then
        return {}
    end
    local ok, list = pcall(C_TradeSkillUI.GetRecipesTracked, isRecraft)
    if ok and type(list) == "table" then
        return list
    end
    return {}
end

function R:_GetSchematic(recipeID, isRecraft)
    if ProfessionsUtil and type(ProfessionsUtil.GetRecipeSchematic) == "function" then
        local ok, schematic = pcall(ProfessionsUtil.GetRecipeSchematic, recipeID, isRecraft)
        if ok and type(schematic) == "table" then
            return schematic
        end
    end
    if C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeSchematic) == "function" then
        local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, isRecraft)
        if ok and type(schematic) == "table" then
            return schematic
        end
    end
    return nil
end

-- How many of a slot's reagents the player is holding. The live helper counts
-- every quality tier of the slot together, which is what the crafting UI does.
function R:_CountInPossession(reagents)
    if type(reagents) ~= "table" then
        return 0
    end
    if ProfessionsUtil and type(ProfessionsUtil.AccumulateReagentsInPossession) == "function" then
        local ok, count = pcall(ProfessionsUtil.AccumulateReagentsInPossession, reagents)
        if ok and type(count) == "number" then
            return count
        end
    end

    local total = 0
    for _, reagent in ipairs(reagents) do
        if reagent.itemID and C_Item and type(C_Item.GetItemCount) == "function" then
            -- includeBank = true, includeUses = false, includeReagentBank = true:
            -- the crafting UI can pull from the reagent bank, so counting only
            -- the backpack reports a shortfall the player does not have.
            local ok, count = pcall(C_Item.GetItemCount, reagent.itemID, true, false, true, true)
            if ok and type(count) == "number" then
                total = total + count
            end
        end
    end
    return total
end

-- Reagent display name. Returns nil when the item is not cached yet; the caller
-- requests a load and the GET_ITEM_INFO_RECEIVED refresh fills it in.
function R:_GetReagentName(reagent)
    if type(reagent) ~= "table" then
        return nil
    end
    if reagent.itemID then
        if C_Item and type(C_Item.GetItemNameByID) == "function" then
            local ok, name = pcall(C_Item.GetItemNameByID, reagent.itemID)
            if ok and type(name) == "string" and name ~= "" then
                return name
            end
        end
        -- Not cached yet. Ask for it and remember that we are waiting, so
        -- Events can tell an interesting GET_ITEM_INFO_RECEIVED from the
        -- hundreds that fire while the cache fills at login.
        self._awaitingItemData = true
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            pcall(C_Item.RequestLoadItemDataByID, reagent.itemID)
        end
        return nil
    end
    if reagent.currencyID and C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, reagent.currencyID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return nil
end

-- --------------------------------------------------------------------------
-- Slot predicates.
--
-- Blizzard's ProfessionsUtil helpers are thin field reads
-- (`required`, `reagentType == Enum.CraftingReagentType.Basic`), so we prefer
-- the helper when the client exposes it and fall back to the fields it reads.
-- The fallback is what makes fixture tables work in tests.
-- --------------------------------------------------------------------------

local REAGENT_TYPE_BASIC = 1
local REAGENT_TYPE_MODIFYING = 2

local function ReagentTypeValue(name, default)
    local E = _G.Enum and _G.Enum.CraftingReagentType
    if E and E[name] ~= nil then
        return E[name]
    end
    return default
end

local function SlotIsRequired(slot)
    if ProfessionsUtil and type(ProfessionsUtil.IsReagentSlotRequired) == "function" then
        local ok, required = pcall(ProfessionsUtil.IsReagentSlotRequired, slot)
        if ok then
            return required == true
        end
    end
    return slot.required == true
end

local function SlotIsBasic(slot)
    return SlotIsRequired(slot) and slot.reagentType == ReagentTypeValue("Basic", REAGENT_TYPE_BASIC)
end

local function SlotIsModifying(slot)
    return SlotIsRequired(slot) and slot.reagentType == ReagentTypeValue("Modifying", REAGENT_TYPE_MODIFYING)
end

-- A variable-quantity reagent can be supplied in a range of amounts instead of
-- a fixed count. Blizzard does not persist the player's chosen amount outside
-- the crafting form, so -- like the default tracker -- we show the range rather
-- than an invented "have/need".
--
-- Two paths. The live client puts CraftingReagentSlotSchematicMixin on the
-- slot, and its GetVariableQuantityRange is authoritative. Without the mixin we
-- derive the range from the documented struct: CraftingReagentSlotSchematic has
-- a `variableQuantities` array of CraftingVariableQuantities {reagent, quantity}
-- -- a list of per-reagent amounts, NOT a min/max pair -- so the range is the
-- span of the quantities in it.
local function SlotVariableRange(slot, reagent)
    if type(slot.IsVariableQuantityReagent) == "function" then
        local ok, isVariable = pcall(slot.IsVariableQuantityReagent, slot, reagent)
        if not (ok and isVariable) then
            return nil
        end
        if type(slot.GetVariableQuantityRange) == "function" then
            local okRange, minQty, maxQty = pcall(slot.GetVariableQuantityRange, slot, reagent)
            if okRange and minQty and maxQty then
                return minQty, maxQty
            end
        end
        -- Mixin present but the range getter is not; fall through to the struct.
    end

    local quantities = slot.variableQuantities
    if type(quantities) ~= "table" or #quantities == 0 then
        return nil
    end

    local minQty, maxQty
    for _, entry in ipairs(quantities) do
        local quantity = type(entry) == "table" and entry.quantity or nil
        if type(quantity) == "number" then
            minQty = (minQty == nil or quantity < minQty) and quantity or minQty
            maxQty = (maxQty == nil or quantity > maxQty) and quantity or maxQty
        end
    end

    -- A single-valued list is a fixed quantity wearing the variable struct;
    -- rendering "3-3" would be worse than the normal have/need row.
    if minQty and maxQty and minQty ~= maxQty then
        return minQty, maxQty
    end
    return nil
end

local function SlotQuantityRequired(slot, reagent)
    if type(slot.GetQuantityRequired) == "function" then
        local ok, quantity = pcall(slot.GetQuantityRequired, slot, reagent)
        if ok and type(quantity) == "number" then
            return quantity
        end
    end
    return slot.quantityRequired or 1
end

-- --------------------------------------------------------------------------

function R:GetTrackedCount()
    return #self:_GetTrackedRecipeIDs(false) + #self:_GetTrackedRecipeIDs(true)
end

-- Append one recipe's header row plus a row per required reagent slot.
-- Returns false when the recipe could not be read at all, so the caller can
-- skip it rather than emit a header with nothing under it.
function R:_AppendRecipe(entries, recipeID, isRecraft)
    local schematic = self:_GetSchematic(recipeID, isRecraft)
    if type(schematic) ~= "table" then
        return false
    end

    local blockID = BlockID(recipeID, isRecraft)
    local name = schematic.name
    if type(name) ~= "string" or name == "" then
        name = "Recipe " .. tostring(recipeID)
    end
    if isRecraft then
        -- PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER is "Recrafting %s"; fall
        -- back to a literal so the row still reads correctly on a client that
        -- does not define it.
        -- rawget rather than _G.NAME: this is a localized string constant that
        -- is not in the generated Blizzard globals list, and a bare _G lookup
        -- makes LuaLS type-check the _G table and report undefined-field.
        local fmt = rawget(_G, "PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER")
        if type(fmt) == "string" and fmt:find("%%s") then
            name = fmt:format(name)
        else
            name = "Recrafting " .. name
        end
    end

    entries[#entries + 1] = {
        id = "recipe:" .. blockID,
        text = name,
        isName = true,
        recipeID = recipeID,
        isRecraft = isRecraft == true,
    }

    -- Modifying-required slots sort ahead of basic ones, matching the order the
    -- default tracker lists them in.
    local slots = {}
    for slotIndex, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if SlotIsRequired(slot) then
            if SlotIsModifying(slot) then
                table.insert(slots, 1, { slotIndex = slotIndex, slot = slot })
            else
                slots[#slots + 1] = { slotIndex = slotIndex, slot = slot }
            end
        end
    end

    for _, tbl in ipairs(slots) do
        local slot = tbl.slot
        local reagent = (slot.reagents or {})[1]
        local label

        if SlotIsBasic(slot) then
            -- nil means the item cache has not caught up. Drop the row rather
            -- than render a blank one; the GET_ITEM_INFO_RECEIVED refresh
            -- (gated on IsAwaitingItemData) brings it back with a name.
            label = self:_GetReagentName(reagent)
        elseif SlotIsModifying(slot) then
            label = slot.slotInfo and slot.slotInfo.slotText or nil
        end

        if label then
            local entry = {
                id = "recipe:" .. blockID .. ":" .. tbl.slotIndex,
                text = label,
                recipeID = recipeID,
                isRecraft = isRecraft == true,
            }

            local minQty, maxQty = SlotVariableRange(slot, reagent)
            if minQty then
                entry.rangeText = string.format("%d-%d", minQty, maxQty)
            else
                local required = SlotQuantityRequired(slot, reagent)
                local have = self:_CountInPossession(slot.reagents)
                entry.quantity = have
                entry.totalQuantity = required
                entry.completed = have >= required
            end

            entries[#entries + 1] = entry
        end
    end

    return true
end

-- True when the last build hit a reagent whose item data had not loaded yet.
-- Events uses this to decide whether a GET_ITEM_INFO_RECEIVED is worth a
-- refresh.
function R:IsAwaitingItemData()
    return self._awaitingItemData == true
end

function R:BuildEntries()
    local entries = {}
    -- Recomputed by _GetReagentName during this build.
    self._awaitingItemData = false
    if not self:IsSectionEnabled() then
        return entries
    end

    local rendered = 0
    -- Normal recipes first, then recrafts -- the same order the default tracker
    -- uses, so a player switching to Artemis sees the list they already know.
    for _, isRecraft in ipairs({ false, true }) do
        for _, recipeID in ipairs(self:_GetTrackedRecipeIDs(isRecraft)) do
            if rendered >= self.MAX_RECIPES then
                return entries
            end
            if type(recipeID) == "number" and self:_AppendRecipe(entries, recipeID, isRecraft) then
                rendered = rendered + 1
            end
        end
    end

    return entries
end

-- Untrack, mirroring the default tracker's right-click action. Not a protected
-- call, but pcall'd anyway: a client without the setter would otherwise raise
-- out of a click handler.
function R:Untrack(recipeID, isRecraft)
    if not (C_TradeSkillUI and type(C_TradeSkillUI.SetRecipeTracked) == "function") then
        return false
    end
    local ok = pcall(C_TradeSkillUI.SetRecipeTracked, recipeID, false, isRecraft == true)
    return ok
end

-- Open the recipe in the profession UI. The Professions frame is load-on-demand,
-- so it has to be pulled in first.
function R:OpenRecipe(recipeID)
    if not (C_TradeSkillUI and type(C_TradeSkillUI.OpenRecipe) == "function") then
        return false
    end
    -- Both are load-on-demand, so neither is in the generated globals list;
    -- rawget keeps the existence check honest without a static false positive.
    local loadUI = rawget(_G, "ProfessionsFrame_LoadUI")
    if not rawget(_G, "ProfessionsFrame") and type(loadUI) == "function" then
        pcall(loadUI)
    end
    local ok = pcall(C_TradeSkillUI.OpenRecipe, recipeID)
    return ok
end
