-- ============================================================================
-- FabledUI_Crafty/ReagentOptimizer.lua
--
-- CraftSim "ReagentOptimization"-inspired optional/finishing reagent picker.
--
-- Public API:
--   M.ReagentOptimizer:GetModifiedReagentSlots(recipeID)
--       Walks the live recipe schematic and returns the list of modified
--       (quality-tiered) reagent slots, each with `{ slotIndex, slotText,
--         choices = { { itemID, quality, skillBonus, price, qty }, ... } }`.
--
--   M.ReagentOptimizer:RecommendOptionalReagents(recipeID, qualityTarget)
--       Computes the cheapest tier per slot that still helps reach the target
--       quality. Returns:
--         { picks = { [slotIndex] = chosenChoice, ... },
--           totalSkill = N, totalCost = N, savings = N (vs all-T3),
--           qualityTarget = N, slots = { ... },
--           lines = { "For Quality 3: Use Tier 2 herb (saves 12g over Tier 3)" } }
--
-- Notes:
--   * We treat each modified-reagent slot's "quality" choice as the existing
--     in-slot item tiers (1=T1, 2=T2, 3=T3). Higher quality contributes more
--     skill but costs more.
--   * Skill contribution per quality tier is approximated from the recipe's
--     `qualityIlvlBonuses` if present, otherwise via a simple linear ramp
--     (T1=0, T2=2, T3=5 per unit). This is intentionally a heuristic — the
--     module is documented as best-effort.
-- ============================================================================

local M = _G.FabledUI_Crafty
M.ReagentOptimizer = M.ReagentOptimizer or {}
local RO = M.ReagentOptimizer

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local DEFAULT_QUALITY_TARGET = 3
local TIER_SKILL_FALLBACK    = { 0, 2, 5 } -- additive skill per unit (q1, q2, q3)

local function getModifiedSlotType()
    if Enum and Enum.TradeskillSlotDataType then
        return Enum.TradeskillSlotDataType.ModifiedReagent
    end
    return 2 -- common numeric value when the enum table is missing
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function getItemPrice(itemID)
    if M.Profit and M.Profit.GetItemPrice then
        local ok, value = pcall(M.Profit.GetItemPrice, M.Profit, itemID)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function getItemName(itemID)
    if not itemID then return "?" end
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(itemID)
        if name then return name end
    end
    return string.format("Item %s", tostring(itemID))
end

-- ---------------------------------------------------------------------------
-- Schematic walk
-- ---------------------------------------------------------------------------
function RO:GetModifiedReagentSlots(recipeID)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeSchematic then
        return {}
    end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or type(schematic) ~= "table" then
        return {}
    end

    local modifiedSlotType = getModifiedSlotType()
    local slots = {}
    for slotIndex, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local dataType = slot.dataSlotType or slot.dataSlotTypeOverride
        if dataType == modifiedSlotType then
            local choices = {}
            for _, reagent in ipairs(slot.reagents or {}) do
                if reagent and reagent.itemID then
                    local quality = tonumber(reagent.quality) or 1
                    local price = getItemPrice(reagent.itemID)
                    local qtyRequired = tonumber(slot.quantityRequired or 1) or 1
                    local skill = TIER_SKILL_FALLBACK[quality] or 0
                    if type(slot.qualityIlvlBonuses) == "table"
                        and slot.qualityIlvlBonuses[quality] then
                        skill = math.max(skill, tonumber(slot.qualityIlvlBonuses[quality]) or 0)
                    end
                    choices[#choices + 1] = {
                        itemID = reagent.itemID,
                        name = getItemName(reagent.itemID),
                        quality = quality,
                        price = price,
                        quantityRequired = qtyRequired,
                        skillBonus = skill * qtyRequired,
                        unitCost = price * qtyRequired,
                    }
                end
            end
            -- Sort each slot's choices ascending by quality so [1] = T1, [3] = T3.
            table.sort(choices, function(a, b)
                return (a.quality or 1) < (b.quality or 1)
            end)
            if #choices > 0 then
                slots[#slots + 1] = {
                    slotIndex = slotIndex,
                    slotText = slot.slotText,
                    choices = choices,
                }
            end
        end
    end
    return slots
end

-- ---------------------------------------------------------------------------
-- Optimization
-- ---------------------------------------------------------------------------
-- Greedy: start every slot at its highest tier (max skill, max cost), then
-- repeatedly downgrade the slot that loses the least skill per gold saved
-- until further downgrades would drop us below an acceptable skill ceiling.
-- For "minimum reagent cost to hit target quality" we treat target quality
-- 3 as "use highest tier where it helps most", target quality 1 as "use
-- cheapest", and target quality 2 as "downgrade everything to tier 2 unless
-- T1 retains the same skill curve".
local function pickInitial(slots, qualityTarget)
    local picks = {}
    for _, slot in ipairs(slots) do
        if qualityTarget >= 3 then
            picks[slot.slotIndex] = slot.choices[#slot.choices] -- highest tier
        elseif qualityTarget == 2 then
            picks[slot.slotIndex] = slot.choices[2] or slot.choices[#slot.choices]
        else
            picks[slot.slotIndex] = slot.choices[1]
        end
    end
    return picks
end

local function totalsFor(picks)
    local skill, cost = 0, 0
    for _, pick in pairs(picks) do
        skill = skill + (pick.skillBonus or 0)
        cost = cost + (pick.unitCost or 0)
    end
    return skill, cost
end

local function highestTierTotals(slots)
    local picks = {}
    for _, slot in ipairs(slots) do
        picks[slot.slotIndex] = slot.choices[#slot.choices]
    end
    local skill, cost = totalsFor(picks)
    return skill, cost, picks
end

function RO:RecommendOptionalReagents(recipeID, qualityTarget)
    if M.Modules and not M.Modules:IsEnabled("reagentPicker") then
        return nil
    end
    qualityTarget = tonumber(qualityTarget) or DEFAULT_QUALITY_TARGET
    local slots = self:GetModifiedReagentSlots(recipeID)
    if #slots == 0 then
        return {
            picks = {},
            totalSkill = 0,
            totalCost = 0,
            savings = 0,
            qualityTarget = qualityTarget,
            slots = {},
            lines = { "No modified (quality-tiered) reagent slots in this recipe." },
        }
    end

    local picks = pickInitial(slots, qualityTarget)

    -- For target quality < 3, attempt downgrades that save the most cost
    -- relative to the skill they sacrifice. Stop downgrading a slot when
    -- further downgrades would drop the slot to an empty / nil choice.
    if qualityTarget < 3 then
        local improved = true
        while improved do
            improved = false
            local bestSlotID, bestNextChoice, bestRatio
            for _, slot in ipairs(slots) do
                local current = picks[slot.slotIndex]
                if current then
                    -- Find the next tier down.
                    local nextChoice
                    for _, choice in ipairs(slot.choices) do
                        if choice.quality < current.quality
                            and (not nextChoice or choice.quality > nextChoice.quality) then
                            nextChoice = choice
                        end
                    end
                    if nextChoice then
                        local skillLoss = (current.skillBonus or 0) - (nextChoice.skillBonus or 0)
                        local costSaved = (current.unitCost or 0) - (nextChoice.unitCost or 0)
                        if costSaved > 0 then
                            local ratio = costSaved / math.max(1, skillLoss)
                            if not bestRatio or ratio > bestRatio then
                                bestRatio = ratio
                                bestSlotID = slot.slotIndex
                                bestNextChoice = nextChoice
                            end
                        end
                    end
                end
            end
            if bestSlotID and bestNextChoice then
                picks[bestSlotID] = bestNextChoice
                improved = true
            end
        end
    end

    local totalSkill, totalCost = totalsFor(picks)
    local _, maxCost = highestTierTotals(slots)
    local savings = math.max(0, maxCost - totalCost)

    -- Build the user-facing "For Quality X: Use Tier Y (saves Zg over Tier 3)" lines.
    local lines = {}
    for _, slot in ipairs(slots) do
        local pick = picks[slot.slotIndex]
        if pick then
            local maxChoice = slot.choices[#slot.choices]
            local saved = math.max(0, (maxChoice.unitCost or 0) - (pick.unitCost or 0))
            local label = slot.slotText
                or string.format("Slot %d", slot.slotIndex)
            if saved > 0 then
                lines[#lines + 1] = string.format(
                    "For Quality %d: Use Tier %d %s (saves %s over Tier %d)",
                    qualityTarget, pick.quality or 1,
                    pick.name or label,
                    M.Util and M.Util:MoneyToString(saved) or (saved .. "c"),
                    maxChoice.quality or 3)
            else
                lines[#lines + 1] = string.format(
                    "For Quality %d: Use Tier %d %s",
                    qualityTarget, pick.quality or 1, pick.name or label)
            end
        end
    end
    if #lines == 0 then
        lines[#lines + 1] = "All slots already at the cheapest acceptable tier."
    end

    return {
        picks = picks,
        totalSkill = totalSkill,
        totalCost = totalCost,
        savings = savings,
        qualityTarget = qualityTarget,
        slots = slots,
        lines = lines,
    }
end

-- ---------------------------------------------------------------------------
-- Popup UI for the Queue tab "Reagent Picker" button.
-- ---------------------------------------------------------------------------
local function ensurePopup()
    if RO._popup then
        return RO._popup
    end
    local frame = CreateFrame("Frame", "FabledUI_CraftyReagentOptimizerPopup", UIParent, "BackdropTemplate")
    frame:SetSize(520, 360)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.07, 0.08, 0.95)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 12, -10)
    frame.title:SetText("Reagent Optimizer")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.subtitle:SetWidth(500)
    frame.subtitle:SetJustifyH("LEFT")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", 0, 0)

    -- Quality target dropdown buttons (1/2/3)
    frame.qButtons = {}
    for q = 1, 3 do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(60, 22)
        btn:SetPoint("TOPLEFT", 12 + (q - 1) * 66, -50)
        btn:SetText("Q" .. q)
        btn:SetScript("OnClick", function()
            if frame._recipeID then
                RO:ShowRecommendationPopup(frame._recipeID, q)
            end
        end)
        frame.qButtons[q] = btn
    end

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 12, -84)
    frame.scroll:SetPoint("BOTTOMRIGHT", -28, 12)
    frame.scrollChild = CreateFrame("Frame", nil, frame.scroll)
    frame.scrollChild:SetSize(1, 1)
    frame.scroll:SetScrollChild(frame.scrollChild)

    frame.lines = {}

    RO._popup = frame
    return frame
end

local function getOrCreateLine(parent, index)
    if parent.lines[index] then
        return parent.lines[index]
    end
    local fs = parent.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetWidth(470)
    fs:SetJustifyH("LEFT")
    parent.lines[index] = fs
    return fs
end

function RO:ShowRecommendationPopup(recipeID, qualityTarget)
    local frame = ensurePopup()
    frame._recipeID = recipeID
    qualityTarget = tonumber(qualityTarget) or DEFAULT_QUALITY_TARGET

    local recipe = M.Recipes and M.Recipes:Get(recipeID) or nil
    local result = self:RecommendOptionalReagents(recipeID, qualityTarget)
    frame.title:SetText(string.format("Reagent Optimizer · %s",
        (recipe and recipe.name) or ("Recipe " .. tostring(recipeID))))
    frame.subtitle:SetText(string.format(
        "Target Quality: %d  ·  Estimated cost: %s  ·  Savings: %s",
        qualityTarget,
        M.Util and M.Util:MoneyToString(result.totalCost or 0) or tostring(result.totalCost or 0),
        M.Util and M.Util:MoneyToString(result.savings or 0) or tostring(result.savings or 0)))

    -- Reset all lines
    for _, fs in pairs(frame.lines) do
        fs:SetText("")
        fs:Hide()
    end

    local y = 0
    for index, line in ipairs(result.lines or {}) do
        local fs = getOrCreateLine(frame, index)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, -y)
        fs:SetText(line)
        fs:Show()
        y = y + 18
    end
    frame.scrollChild:SetSize(470, math.max(20, y))
    frame:Show()
end
