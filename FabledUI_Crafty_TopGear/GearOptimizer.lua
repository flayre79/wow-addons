-- ============================================================================
-- FabledUI_Crafty/GearOptimizer.lua
--
-- CraftSim "TopGear"-inspired gear optimizer for profession crafting.
--
-- Public API:
--   M.GearOptimizer:GetCandidatesForProfession(professionName)
--       Returns a flat list of candidate items (bags + bank + equipped) that
--       carry profession stat affixes for the given profession.
--
--   M.GearOptimizer:RecommendForRecipe(recipeID, opts)
--       Returns a sorted list of equipment combinations ranked by an expected
--       crafting score. Each entry is:
--         { score, breakdown = { skill, multicraft, resourcefulness, ... },
--           items = { [slotIndex] = candidate, ... }, isCurrent = bool }
--       opts.maxResults defaults to 3.
--
--   M.GearOptimizer:ShowRecommendationPopup(recipeID)
--       Builds (or refreshes) and shows a small popup window listing the top
--       combinations with "Equip" buttons. The "Equip" buttons use
--       EquipItemByName(itemLink) which the protected hardware-event API will
--       carry out only when invoked from a real click.
--
-- Stat priorities (linear weights, intentionally simple — we are not trying
-- to perfectly model CraftSim's curves):
--   * Crafting Skill — primary when the recipe still has a quality
--     breakpoint ahead of the player; otherwise demoted to a small bonus
--   * Inspiration / Ingenuity — secondary always
--   * Multicraft — secondary always
--   * Resourcefulness — tertiary
--   * Crafting Speed — small bonus
-- ============================================================================

local M = _G.FabledUI_Crafty
M.GearOptimizer = M.GearOptimizer or {}
local GO = M.GearOptimizer

-- ---------------------------------------------------------------------------
-- Stat weights
-- ---------------------------------------------------------------------------
local WEIGHT_SKILL_PRIMARY    = 6.0
local WEIGHT_SKILL_SECONDARY  = 1.5
local WEIGHT_INGENUITY        = 2.5
local WEIGHT_MULTICRAFT       = 2.5
local WEIGHT_RESOURCEFULNESS  = 1.5
local WEIGHT_CRAFTING_SPEED   = 0.5

local DEFAULT_MAX_RESULTS = 3

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function getProfessionEnum(professionName)
    if M.Gear and M.Gear.GetProfessionEnum then
        return M.Gear:GetProfessionEnum(professionName)
    end
    return nil
end

local function getTooltipSkillBonus(itemLink, professionName)
    if not itemLink or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return 0
    end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, itemLink)
    if not ok or type(data) ~= "table" then
        return 0
    end
    local best = 0
    for _, line in ipairs(data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and text:find("Skill") then
            local value = tonumber(text:match("%+(%d+)")) or 0
            if value > 0 then
                if not professionName or text:find(professionName)
                    or text:find("Profession") or text:find("Crafting") then
                    best = math.max(best, value)
                end
            end
        end
    end
    return best
end

local function buildItemSnapshot(itemLink, professionName, location)
    if not itemLink then
        return nil
    end
    local itemID
    if C_Item and C_Item.GetItemInfoInstant then
        itemID = select(1, C_Item.GetItemInfoInstant(itemLink))
    elseif GetItemInfoInstant then
        itemID = select(1, GetItemInfoInstant(itemLink))
    end

    local name = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemLink)) or itemLink
    local itemLevel = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(itemLink) or nil
    local stats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)) or {}

    local snap = {
        itemLink = itemLink,
        itemID = itemID,
        name = name,
        itemLevel = itemLevel,
        skill = getTooltipSkillBonus(itemLink, professionName),
        multicraft = tonumber(stats.ITEM_MOD_MULTICRAFT_SHORT) or 0,
        resourcefulness = tonumber(stats.ITEM_MOD_RESOURCEFULNESS_SHORT) or 0,
        ingenuity = tonumber(stats.ITEM_MOD_INGENUITY_SHORT) or 0,
        craftingspeed = tonumber(stats.ITEM_MOD_CRAFTING_SPEED_SHORT) or 0,
        location = location, -- "equipped" / "bag" / "bank"
    }

    -- A candidate is "interesting" if it carries any profession-relevant stats.
    snap.relevant = (snap.skill + snap.multicraft + snap.resourcefulness
                     + snap.ingenuity + snap.craftingspeed) > 0
    return snap
end

local function fitsInventoryType(itemLink)
    -- GetItemInfoInstant returns the inventory equip-slot, which we use to
    -- decide whether a candidate is even profession gear. Profession slots
    -- are typically INVTYPE_PROFESSION_TOOL and INVTYPE_PROFESSION_GEAR.
    if not itemLink then
        return false
    end
    local equipLoc
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, eq = C_Item.GetItemInfoInstant(itemLink)
        equipLoc = eq
        if not equipLoc then
            -- GetItemInfoInstant returns multiple values; the 4th is equipLoc
            -- on most builds, but on some it shifts. Use a select fallback.
            equipLoc = select(4, C_Item.GetItemInfoInstant(itemLink))
        end
    elseif GetItemInfoInstant then
        equipLoc = select(4, GetItemInfoInstant(itemLink))
    end
    if type(equipLoc) ~= "string" or equipLoc == "" then
        return false
    end
    return equipLoc:find("PROFESSION") ~= nil
end

-- Iterate bags 0..NUM_BAG_SLOTS for items that look profession-relevant.
local function scanBagsForCandidates(professionName)
    local out = {}
    if not C_Container or not C_Container.GetContainerNumSlots then
        return out
    end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
            if ok and link then
                local snap = buildItemSnapshot(link, professionName, "bag")
                if snap and snap.relevant and fitsInventoryType(link) then
                    out[#out + 1] = snap
                end
            end
        end
    end
    return out
end

-- Bank scan: bank slots are 6..12 in the BAG range (BANK_CONTAINER bag id is
-- -1 in classic, but on retail we just enumerate the standard bank bag ids).
local function scanBankForCandidates(professionName)
    local out = {}
    if not C_Container or not C_Container.GetContainerNumSlots then
        return out
    end
    local bankBags = { -1 }                  -- main bank
    for i = (NUM_BAG_SLOTS or 4) + 1, ((NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7)) do
        bankBags[#bankBags + 1] = i
    end
    for _, bag in ipairs(bankBags) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
            if ok and link then
                local snap = buildItemSnapshot(link, professionName, "bank")
                if snap and snap.relevant and fitsInventoryType(link) then
                    out[#out + 1] = snap
                end
            end
        end
    end
    return out
end

local function scanEquippedForCandidates(professionName)
    local out = {}
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then
        return out
    end
    local enum = getProfessionEnum(professionName)
    if not enum then
        return out
    end
    local slots = { C_TradeSkillUI.GetProfessionSlots(enum) }
    for _, inventorySlot in ipairs(slots) do
        if inventorySlot then
            local link = GetInventoryItemLink("player", inventorySlot)
            if link then
                local snap = buildItemSnapshot(link, professionName, "equipped")
                if snap then
                    snap.equipSlot = inventorySlot
                    out[#out + 1] = snap
                end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Public: candidate aggregation
-- ---------------------------------------------------------------------------
function GO:GetCandidatesForProfession(professionName)
    if not professionName then
        return {}
    end
    -- Reuse Gear's helper if it ever appears (forward-compatibility).
    if M.Gear and type(M.Gear.GetAllAvailableTools) == "function" then
        local ok, list = pcall(M.Gear.GetAllAvailableTools, M.Gear, professionName)
        if ok and type(list) == "table" and #list > 0 then
            return list
        end
    end

    local out = {}
    for _, snap in ipairs(scanEquippedForCandidates(professionName)) do
        out[#out + 1] = snap
    end
    for _, snap in ipairs(scanBagsForCandidates(professionName)) do
        out[#out + 1] = snap
    end
    for _, snap in ipairs(scanBankForCandidates(professionName)) do
        out[#out + 1] = snap
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Skill breakpoint detection (best-effort)
-- ---------------------------------------------------------------------------
-- Returns (currentSkill, breakpointSkill) for a recipe. Falls back gracefully
-- when the trade-skill window isn't open or the recipe lacks quality data.
local function getRecipeBreakpoint(recipeID, recipe)
    local context = M.Concentration and M.Concentration:GetOpenProfessionContext() or nil
    local current = (context and context.skillLevel) or (recipe and recipe.skillLevel) or 0
    local breakpoint = 0
    if recipe and recipe.maxQuality and recipe.maxQuality > 0 then
        -- Without an actual breakpoint API, approximate the high end as the
        -- profession's max skill if known. This makes "needs more skill" the
        -- default until the player is right up against cap.
        breakpoint = (context and context.maxSkillLevel) or (recipe and recipe.maxSkillLevel) or 0
    end
    return tonumber(current) or 0, tonumber(breakpoint) or 0
end

-- ---------------------------------------------------------------------------
-- Combination scoring
-- ---------------------------------------------------------------------------
local function scoreItems(items, weights)
    local skill, mc, rf, ig, sp = 0, 0, 0, 0, 0
    for _, item in ipairs(items) do
        if item then
            skill = skill + (item.skill or 0)
            mc = mc + (item.multicraft or 0)
            rf = rf + (item.resourcefulness or 0)
            ig = ig + (item.ingenuity or 0)
            sp = sp + (item.craftingspeed or 0)
        end
    end
    local score = skill * weights.skill
        + mc * weights.multicraft
        + rf * weights.resourcefulness
        + ig * weights.ingenuity
        + sp * weights.craftingspeed
    return score, { skill = skill, multicraft = mc, resourcefulness = rf, ingenuity = ig, craftingspeed = sp }
end

-- ---------------------------------------------------------------------------
-- Public: recommendation
-- ---------------------------------------------------------------------------
function GO:RecommendForRecipe(recipeID, opts)
    opts = type(opts) == "table" and opts or {}
    local recipe = M.Recipes and M.Recipes:Get(recipeID) or nil
    if not recipe then
        return {}
    end
    local professionName = recipe.profession
    local candidates = self:GetCandidatesForProfession(professionName)
    if #candidates == 0 then
        return {}
    end

    local current, breakpoint = getRecipeBreakpoint(recipeID, recipe)
    local atBreakpoint = breakpoint > 0 and current < breakpoint
    local weights = {
        skill = atBreakpoint and WEIGHT_SKILL_PRIMARY or WEIGHT_SKILL_SECONDARY,
        multicraft = WEIGHT_MULTICRAFT,
        resourcefulness = WEIGHT_RESOURCEFULNESS,
        ingenuity = WEIGHT_INGENUITY,
        craftingspeed = WEIGHT_CRAFTING_SPEED,
    }

    -- Group candidates by the slot they belong to. We do not have a perfect
    -- mapping of inventory equip-loc → profession slot index, so as a simple
    -- heuristic we group by item.equipSlot when known, otherwise by the
    -- inventory type tag itself.
    local equippedBySlot = {}
    for _, item in ipairs(candidates) do
        if item.location == "equipped" and item.equipSlot then
            equippedBySlot[item.equipSlot] = item
        end
    end

    -- Greedy combination strategy:
    --  1. Always include currently-equipped tools as the baseline.
    --  2. For each candidate not currently equipped, propose a "swap" combo
    --     that replaces the lowest-scoring equipped item with this one.
    -- That gives O(N) candidate combos which is plenty given the inventory size.

    local baseline = {}
    for _, item in pairs(equippedBySlot) do
        baseline[#baseline + 1] = item
    end
    local baselineScore, baselineBreakdown = scoreItems(baseline, weights)

    local results = {
        {
            score = baselineScore,
            breakdown = baselineBreakdown,
            items = baseline,
            label = "Currently Equipped",
            isCurrent = true,
        },
    }

    -- Score each non-equipped candidate as a single-item delta against the
    -- weakest equipped slot it could replace.
    local lowestEquippedScore, lowestEquippedItem
    for _, item in pairs(equippedBySlot) do
        local s = scoreItems({ item }, weights)
        if not lowestEquippedScore or s < lowestEquippedScore then
            lowestEquippedScore, lowestEquippedItem = s, item
        end
    end

    for _, item in ipairs(candidates) do
        if item.location ~= "equipped" then
            local newSet = {}
            for _, equipped in pairs(equippedBySlot) do
                if equipped ~= lowestEquippedItem then
                    newSet[#newSet + 1] = equipped
                end
            end
            newSet[#newSet + 1] = item
            local score, breakdown = scoreItems(newSet, weights)
            results[#results + 1] = {
                score = score,
                breakdown = breakdown,
                items = newSet,
                label = string.format("Swap in: %s%s", item.name or "?",
                    item.location == "bank" and " (bank)" or ""),
                replaces = lowestEquippedItem,
                candidate = item,
                isCurrent = false,
            }
        end
    end

    table.sort(results, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return (a.label or "") < (b.label or "")
    end)

    -- Trim to maxResults but ALWAYS keep the baseline so the user can see
    -- where they stand.
    local maxResults = math.max(1, tonumber(opts.maxResults) or DEFAULT_MAX_RESULTS)
    local trimmed, sawCurrent = {}, false
    for _, entry in ipairs(results) do
        if #trimmed < maxResults then
            trimmed[#trimmed + 1] = entry
            if entry.isCurrent then sawCurrent = true end
        else
            break
        end
    end
    if not sawCurrent then
        for _, entry in ipairs(results) do
            if entry.isCurrent then
                trimmed[#trimmed] = entry -- replace the worst-ranked kept entry
                break
            end
        end
    end

    return trimmed, { current = current, breakpoint = breakpoint, atBreakpoint = atBreakpoint }
end

-- ---------------------------------------------------------------------------
-- Popup UI
-- ---------------------------------------------------------------------------
local function ensurePopup()
    if GO._popup then
        return GO._popup
    end
    local frame = CreateFrame("Frame", "FabledUI_CraftyGearOptimizerPopup", UIParent, "BackdropTemplate")
    frame:SetSize(440, 260)
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
    frame.title:SetText("Gear Optimizer")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.subtitle:SetWidth(420)
    frame.subtitle:SetJustifyH("LEFT")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", 0, 0)

    frame.rows = {}
    GO._popup = frame
    return frame
end

local function getOrCreateRow(parent, index)
    if parent.rows[index] then
        return parent.rows[index]
    end
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(414, 50)
    row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    row:SetBackdropColor(1, 1, 1, 0.04)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("TOPLEFT", 8, -6)
    row.label:SetWidth(310)
    row.label:SetJustifyH("LEFT")

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.detail:SetWidth(310)
    row.detail:SetJustifyH("LEFT")

    row.actionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.actionButton:SetSize(80, 22)
    row.actionButton:SetPoint("RIGHT", -8, 0)
    row.actionButton:SetText("Equip")

    parent.rows[index] = row
    return row
end

function GO:ShowRecommendationPopup(recipeID)
    if M.Modules and not M.Modules:IsEnabled("topGear") then
        return
    end
    local frame = ensurePopup()
    local recipe = M.Recipes and M.Recipes:Get(recipeID) or nil
    if not recipe then
        frame:Hide()
        return
    end
    local results, meta = self:RecommendForRecipe(recipeID, { maxResults = 3 })
    frame.title:SetText(string.format("Gear Optimizer · %s", recipe.name or "Recipe"))
    if meta and meta.breakpoint > 0 then
        frame.subtitle:SetText(string.format(
            "%s · skill %d/%d %s",
            recipe.profession or "?",
            meta.current or 0, meta.breakpoint or 0,
            meta.atBreakpoint and "|cffffd05a(skill prioritised)|r"
                or "|cff7be37bat cap (multicraft prioritised)|r"))
    else
        frame.subtitle:SetText(string.format(
            "%s · stat-based ranking (no skill breakpoint detected)",
            recipe.profession or "?"))
    end

    -- hide all rows first
    for _, row in pairs(frame.rows) do
        row:Hide()
        row.actionButton:SetScript("OnClick", nil)
    end

    if not results or #results == 0 then
        local row = getOrCreateRow(frame, 1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, -56)
        row:Show()
        row.label:SetText("|cffd95f5fNo profession-statted gear found|r")
        row.detail:SetText("Equip a profession tool/accessory and re-open this popup.")
        row.actionButton:Hide()
        frame:SetHeight(110)
        frame:Show()
        return
    end

    local y = 56
    for index, entry in ipairs(results) do
        local row = getOrCreateRow(frame, index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, -y)
        row:Show()
        local breakdown = entry.breakdown or {}
        row.label:SetText(string.format("%d. %s · |cffffd100Score %d|r",
            index, entry.label or "Combo", math.floor(entry.score or 0)))
        row.detail:SetText(string.format(
            "Skill +%d  MC %d  RF %d  Ing %d  Spd %d",
            breakdown.skill or 0, breakdown.multicraft or 0,
            breakdown.resourcefulness or 0, breakdown.ingenuity or 0,
            breakdown.craftingspeed or 0))
        if entry.isCurrent then
            row.actionButton:SetText("Current")
            row.actionButton:Disable()
        else
            row.actionButton:Enable()
            row.actionButton:SetText("Equip")
            local link = entry.candidate and entry.candidate.itemLink or nil
            row.actionButton:SetScript("OnClick", function()
                if not link then return end
                if InCombatLockdown() then
                    M:Print("Cannot equip in combat.")
                    return
                end
                -- C_Item.EquipItemByName: the global is gone in 12.1.5.
                if C_Item and C_Item.EquipItemByName then
                    C_Item.EquipItemByName(link)
                    M:Print("Equip requested: " .. link)
                end
            end)
        end
        y = y + 56
    end

    frame:SetHeight(math.max(160, y + 16))
    frame:Show()
end
