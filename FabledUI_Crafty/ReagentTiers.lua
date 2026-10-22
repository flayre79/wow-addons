-- ============================================================================
-- FabledUI_Crafty - ReagentTiers (P1-A8) -- FULLY IMPLEMENTED (read-only cache)
-- Donor: ProfessionShoppingList/modules-old/TrackingWindow.lua:1904-1908.
--
-- Maintains a lazily-populated lookup of reagent quality tiers so callers can
-- ask "what's the q3 itemID for this reagent?" without re-walking the recipe.
-- Read-only as far as Materials.lua is concerned (Agent A owns Materials.lua);
-- this module only PUBLISHES a lookup that other modules can consume.
--
-- Schema:
--   M.ReagentTiers[reagentID] = { 1 = q1ItemID, 2 = q2ItemID, 3 = q3ItemID }
-- All three quality slots map back to the same triplet, so a caller holding
-- any quality variant can resolve any other quality without a separate
-- recipe-walk. q2/q3 may be 0 if a reagent has no higher tier.
-- ============================================================================

local M = _G.FabledUI_Crafty
if not M then return end

M.ReagentTiers = M.ReagentTiers or {}

local function isValidID(id)
    return type(id) == "number" and id > 0
end

-- Register the three quality variants of a reagent. Idempotent: safe to call
-- repeatedly with the same triplet. Higher-quality slots may be 0 (legacy
-- reagent, no q2/q3 variants).
function M:RegisterReagentTier(q1, q2, q3)
    if not isValidID(q1) then return end
    local triplet = { [1] = q1, [2] = q2 or 0, [3] = q3 or 0 }
    M.ReagentTiers[q1] = triplet
    if isValidID(q2) then M.ReagentTiers[q2] = triplet end
    if isValidID(q3) then M.ReagentTiers[q3] = triplet end
    -- Defensive: never let id 0 leak in as a key.
    M.ReagentTiers[0] = nil
end

-- Resolve the actual itemID for a target quality given any reagent variant.
-- Returns nil if the reagent isn't registered, or if the requested quality
-- slot is empty (e.g. asking for q3 when the reagent only has q1).
function M:GetReagentTier(reagentID, quality)
    if not reagentID or not quality then return nil end
    local triplet = M.ReagentTiers[reagentID]
    if not triplet then return nil end
    local id = triplet[quality]
    if not isValidID(id) then return nil end
    return id
end

-- Hot path: register every reagent triplet found in a recipe's reagent slot
-- list. Caller should hand us the result of C_TradeSkillUI.GetRecipeSchematic
-- (or equivalent) -- we walk reagentSlotSchematics looking for entries with
-- 3 itemIDs (the standard quality-tier reagent shape). Side-effect only;
-- returns the number of triplets registered for diagnostics.
function M:PopulateReagentTiersFromSchematic(schematic)
    if type(schematic) ~= "table" then return 0 end
    local slots = schematic.reagentSlotSchematics
    if type(slots) ~= "table" then return 0 end

    local registered = 0
    for _, slot in ipairs(slots) do
        local reagents = slot and slot.reagents
        if type(reagents) == "table" and #reagents >= 1 then
            local q1 = reagents[1] and reagents[1].itemID
            local q2 = reagents[2] and reagents[2].itemID or 0
            local q3 = reagents[3] and reagents[3].itemID or 0
            if isValidID(q1) then
                self:RegisterReagentTier(q1, q2, q3)
                registered = registered + 1
            end
        end
    end
    return registered
end

-- Diagnostic: dump cache size. Useful from /run prints during dev.
function M:GetReagentTierCacheSize()
    local n = 0
    for _ in pairs(M.ReagentTiers) do n = n + 1 end
    return n
end
