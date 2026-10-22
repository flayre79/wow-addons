-- FabledUI_Crafty_Allocator/Allocator.lua
--
-- Crafty Module: Reagent Allocator. Sibling LoadOnDemand addon, registered
-- in FabledUI_Crafty/ModuleRegistry.lua under the "allocator" key.
--
-- Adds an "Unlock" checkbox under the Track Recipe checkbox in Blizzard's
-- schematic form. When checked, reagent allocations aren't gated by
-- inventory state — useful for planning a craft you don't yet have all
-- materials for, or routing the recipe through Crafty's queue without
-- the form bouncing your allocation.
--
-- Originally lifted from SimpleCraftSim (GPL); reorganized to fit Crafty's
-- module pattern. The donor's filename / namespace identity is gone — this
-- file owns the feature now and is referenced only as
-- "Crafty Allocator" or M.Modules.allocator throughout the suite.

local M = _G.FabledUI_Crafty
if not M then return end

M.Allocator = M.Allocator or {}
local A = M.Allocator

A.VERSION = "0.2.0"

local CHECKBOX_TOP_OFFSET = -6
local CHECKBOX_SIZE = 24
local LABEL_OFFSET_X = 0
local LABEL_TEXT = (GetLocale() == "zhCN" or GetLocale() == "zhTW") and "解锁" or "Unlock"
local BAG_UPDATE_EVENTS = {
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
}

local unlockCheckbox
local unlockLabel
local isUnlockEnabled = false
local originalGetCraftingReagentCount
local originalGetReagentQuantityInPossession
local originalAccumulateReagentsInPossession
local flyoutButtonOverridesInstalled = false
local originalFlyoutItemButtonUpdateState
local originalFlyoutCurrencyButtonUpdateState
local flyoutButtonStateCache = setmetatable({}, { __mode = "k" })

-- ----------------------------------------------------------------------------
-- Module-enable check (sourced from the central ModuleRegistry)
-- ----------------------------------------------------------------------------

local function moduleEnabled()
    if M.Modules and M.Modules.IsEnabled then
        return M.Modules:IsEnabled("allocator")
    end
    return true
end

function A:IsEnabled() return moduleEnabled() end
function A:IsUnlocked() return isUnlockEnabled end

-- ----------------------------------------------------------------------------
-- Schematic-form helpers
-- ----------------------------------------------------------------------------

local function GetCraftingPage()
    local professionsFrame = _G.ProfessionsFrame
    return professionsFrame and professionsFrame.CraftingPage or nil
end

local function GetSchematicForm()
    local craftingPage = GetCraftingPage()
    return craftingPage and craftingPage.SchematicForm or nil
end

local function SafeCallMethod(object, methodName, ...)
    local method = object and object[methodName]
    if method then pcall(method, object, ...) end
end

local function RefreshCraftingForm()
    local schematicForm = GetSchematicForm()
    if not schematicForm or not schematicForm:IsShown() then return end

    SafeCallMethod(schematicForm, "UpdateAllSlots")
    SafeCallMethod(schematicForm, "OnAllocationsChanged")
    SafeCallMethod(schematicForm, "UpdateReagentSlots")
    SafeCallMethod(schematicForm, "UpdateOutputIcon")
    SafeCallMethod(schematicForm, "UpdateOutputItem")
    SafeCallMethod(schematicForm, "UpdateResultData")
    SafeCallMethod(schematicForm, "UpdateDetailsStats")
    SafeCallMethod(schematicForm, "UpdateCreateButton")
    SafeCallMethod(schematicForm, "Layout")

    local craftingPage = GetCraftingPage()
    if craftingPage and craftingPage.OnEvent then
        pcall(craftingPage.OnEvent, craftingPage, "BAG_UPDATE")
    end
end

-- ----------------------------------------------------------------------------
-- Reagent-count overrides
-- ----------------------------------------------------------------------------

local function GetCraftingReagentCountOverride() return 9999 end
local function GetReagentQuantityInPossessionOverride() return 9999 end
local function AccumulateReagentsInPossessionOverride() return 9999 end

local function SetUnlockCountOverridesEnabled(enabled)
    local itemUtil = _G.ItemUtil
    if type(itemUtil) == "table" and type(itemUtil.GetCraftingReagentCount) == "function" and not originalGetCraftingReagentCount then
        originalGetCraftingReagentCount = itemUtil.GetCraftingReagentCount
    end

    local professionsUtil = _G.ProfessionsUtil
    if type(professionsUtil) == "table" and type(professionsUtil.GetReagentQuantityInPossession) == "function" and not originalGetReagentQuantityInPossession then
        originalGetReagentQuantityInPossession = professionsUtil.GetReagentQuantityInPossession
    end
    if type(professionsUtil) == "table" and type(professionsUtil.AccumulateReagentsInPossession) == "function" and not originalAccumulateReagentsInPossession then
        originalAccumulateReagentsInPossession = professionsUtil.AccumulateReagentsInPossession
    end

    if type(itemUtil) == "table" and originalGetCraftingReagentCount then
        itemUtil.GetCraftingReagentCount = enabled and GetCraftingReagentCountOverride or originalGetCraftingReagentCount
    end
    if type(professionsUtil) == "table" and originalGetReagentQuantityInPossession then
        professionsUtil.GetReagentQuantityInPossession = enabled and GetReagentQuantityInPossessionOverride or originalGetReagentQuantityInPossession
    end
    if type(professionsUtil) == "table" and originalAccumulateReagentsInPossession then
        professionsUtil.AccumulateReagentsInPossession = enabled and AccumulateReagentsInPossessionOverride or originalAccumulateReagentsInPossession
    end
end

-- ----------------------------------------------------------------------------
-- Flyout button state (the reagent picker squares to the left of the slot)
-- ----------------------------------------------------------------------------

local function IsFlyoutElementUnlocked(elementData, behavior)
    if not isUnlockEnabled or not elementData or not behavior then return false end

    local reagent = elementData.reagent
    local transaction = behavior.GetTransaction and behavior:GetTransaction() or nil
    if not reagent or not transaction then return false end

    if transaction.HasAllocatedReagent and transaction:HasAllocatedReagent(reagent) then return false end
    if transaction.AreDependentReagentsAllocated and not transaction:AreDependentReagentsAllocated(reagent) then return false end

    local recraftAllocation = transaction.GetRecraftAllocation and transaction:GetRecraftAllocation() or nil
    if recraftAllocation and C_TradeSkillUI and C_TradeSkillUI.IsRecraftReagentValid and not C_TradeSkillUI.IsRecraftReagentValid(recraftAllocation, reagent) then
        return false
    end

    return true
end

local function UpdateFlyoutButtonState(button, count, elementData, behavior)
    if button and elementData and behavior then
        flyoutButtonStateCache[button] = { behavior = behavior, elementData = elementData }
    end

    local cachedState = button and flyoutButtonStateCache[button] or nil
    elementData = elementData or (cachedState and cachedState.elementData) or nil
    behavior = behavior or (cachedState and cachedState.behavior) or nil

    local valid = behavior and behavior.IsElementValid and behavior:IsElementValid(elementData)
    if not valid then return end

    if IsFlyoutElementUnlocked(elementData, behavior) then
        button.enabled = true
        if button.DesaturateHierarchy then button:DesaturateHierarchy(0) end
        if button.GetNormalTexture and button:GetNormalTexture() then
            SetItemButtonTextureVertexColor(button, 1, 1, 1)
            SetItemButtonNormalTextureVertexColor(button, 1, 1, 1)
        end
    end
end

local function EnsureFlyoutButtonOverrides()
    if flyoutButtonOverridesInstalled then return end
    if not moduleEnabled() then return end

    local function InstallOverride(mixin, originalRefName)
        if not mixin or type(mixin.UpdateState) ~= "function" then return end

        if originalRefName == "item" then
            originalFlyoutItemButtonUpdateState = mixin.UpdateState
        else
            originalFlyoutCurrencyButtonUpdateState = mixin.UpdateState
        end

        mixin.UpdateState = function(button, count, elementData, behavior)
            local original = originalRefName == "item" and originalFlyoutItemButtonUpdateState or originalFlyoutCurrencyButtonUpdateState
            original(button, count, elementData, behavior)
            UpdateFlyoutButtonState(button, count, elementData, behavior)
        end
    end

    InstallOverride(_G.ProfessionsFlyoutItemButtonMixin, "item")
    InstallOverride(_G.ProfessionsFlyoutCurrencyButtonMixin, "currency")
    flyoutButtonOverridesInstalled = true
end

-- ----------------------------------------------------------------------------
-- Transaction sanitization (clear allocations the user can't fund after disabling)
-- ----------------------------------------------------------------------------

local function SanitizeTransaction(transaction)
    if not transaction then return false end

    local changed = false
    local beforeCount

    if transaction.CreateCraftingReagentInfoTbl then
        local ok, tbl = pcall(transaction.CreateCraftingReagentInfoTbl, transaction)
        if ok and tbl then beforeCount = #tbl end
    end

    SafeCallMethod(transaction, "SanitizeOptionalAllocations")
    SafeCallMethod(transaction, "SanitizeAllocations")
    SafeCallMethod(transaction, "SanitizeTargetAllocations")

    local recipeSchematic = transaction.GetRecipeSchematic and transaction:GetRecipeSchematic() or nil
    if recipeSchematic and transaction.HasAnyAllocations and transaction.ClearAllocations and transaction.EnumerateAllocations then
        local useCharacterInventoryOnly = transaction.ShouldUseCharacterInventoryOnly and transaction:ShouldUseCharacterInventoryOnly() or false

        for slotIndex, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics or {}) do
            if transaction:HasAnyAllocations(slotIndex) then
                local requiredQuantity = reagentSlotSchematic.quantityRequired or 0
                local allocatedOwnedQuantity = 0
                local invalidSlot = false

                for _, allocation in transaction:EnumerateAllocations(slotIndex) do
                    local reagent = allocation and allocation.reagent
                    if not reagent then
                        invalidSlot = true
                        break
                    end

                    local professionsUtil = _G.ProfessionsUtil
                    local ownedQuantity = professionsUtil and professionsUtil.GetReagentQuantityInPossession and professionsUtil.GetReagentQuantityInPossession(reagent, useCharacterInventoryOnly) or 0
                    local reagentRequiredQuantity = reagentSlotSchematic.GetQuantityRequired and reagentSlotSchematic:GetQuantityRequired(reagent) or requiredQuantity
                    if ownedQuantity < reagentRequiredQuantity then
                        invalidSlot = true
                        break
                    end

                    allocatedOwnedQuantity = allocatedOwnedQuantity + ownedQuantity
                end

                if not invalidSlot and requiredQuantity > 0 and allocatedOwnedQuantity < requiredQuantity then
                    invalidSlot = true
                end

                if invalidSlot then
                    pcall(transaction.ClearAllocations, transaction, slotIndex)
                    changed = true
                end
            end
        end
    end

    if beforeCount and transaction.CreateCraftingReagentInfoTbl then
        local ok, tbl = pcall(transaction.CreateCraftingReagentInfoTbl, transaction)
        if ok and tbl then changed = changed or beforeCount ~= #tbl end
    end

    return changed
end

local function SanitizeVisibleReagentAllocations()
    local schematicForm = GetSchematicForm()
    if not schematicForm or not schematicForm:IsVisible() then return end

    local transaction = schematicForm.GetTransaction and schematicForm:GetTransaction() or nil
    SanitizeTransaction(transaction)

    if schematicForm.QualityDialog and schematicForm.QualityDialog.IsShown and schematicForm.QualityDialog:IsShown() then
        local qd = schematicForm.QualityDialog
        local slotIndex = qd.GetSlotIndex and qd:GetSlotIndex() or nil
        if slotIndex and transaction and transaction.GetAllocationsCopy and qd.ReinitAllocations then
            local allocationsCopy = transaction:GetAllocationsCopy(slotIndex)
            qd:ReinitAllocations(allocationsCopy)
        end
    end

    RefreshCraftingForm()
end

local function RefreshVisibleFlyouts()
    for button, buttonState in pairs(flyoutButtonStateCache) do
        UpdateFlyoutButtonState(button, nil, buttonState.elementData, buttonState.behavior)
    end
end

local function SetCraftingPageBagUpdatesSuspended(suspended)
    local craftingPage = GetCraftingPage()
    if not craftingPage or type(craftingPage.IsEventRegistered) ~= "function" then return end

    craftingPage.craftyAllocatorSuspendedBagEvents = craftingPage.craftyAllocatorSuspendedBagEvents or {}

    for _, eventName in ipairs(BAG_UPDATE_EVENTS) do
        if suspended then
            if craftingPage:IsEventRegistered(eventName) then
                craftingPage.craftyAllocatorSuspendedBagEvents[eventName] = true
                pcall(craftingPage.UnregisterEvent, craftingPage, eventName)
            end
        elseif craftingPage.craftyAllocatorSuspendedBagEvents[eventName] then
            craftingPage.craftyAllocatorSuspendedBagEvents[eventName] = nil
            if type(craftingPage.RegisterEvent) == "function" and not craftingPage:IsEventRegistered(eventName) then
                pcall(craftingPage.RegisterEvent, craftingPage, eventName)
            end
        end
    end
end

function A:SetUnlockEnabled(enabled, shouldRefresh)
    local normalizedEnabled = not not enabled
    local wasEnabled = isUnlockEnabled

    if isUnlockEnabled == normalizedEnabled then
        if unlockCheckbox then unlockCheckbox:SetChecked(normalizedEnabled) end
        return
    end

    isUnlockEnabled = normalizedEnabled
    SetUnlockCountOverridesEnabled(normalizedEnabled)
    SetCraftingPageBagUpdatesSuspended(normalizedEnabled)

    if unlockCheckbox then unlockCheckbox:SetChecked(normalizedEnabled) end

    RefreshVisibleFlyouts()

    if wasEnabled and not normalizedEnabled then
        SanitizeVisibleReagentAllocations()
    elseif shouldRefresh then
        RefreshCraftingForm()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, RefreshCraftingForm)
            C_Timer.After(0.05, RefreshCraftingForm)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Checkbox UI on the schematic form
-- ----------------------------------------------------------------------------

local function GetTrackRecipeCheckbox()
    local schematicForm = GetSchematicForm()
    return schematicForm and schematicForm.TrackRecipeCheckbox or nil
end

local function CreateControls(parent)
    if unlockCheckbox then return end

    unlockCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    unlockCheckbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    unlockCheckbox:SetHitRectInsets(0, 0, 0, 0)

    unlockLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockLabel:SetPoint("LEFT", unlockCheckbox, "RIGHT", LABEL_OFFSET_X, 0)
    unlockLabel:SetJustifyH("LEFT")
    unlockLabel:SetText(LABEL_TEXT)

    local checkboxName = unlockCheckbox.GetName and unlockCheckbox:GetName()
    local checkboxText = unlockCheckbox.Text or (checkboxName and _G[checkboxName .. "Text"]) or nil
    if checkboxText then
        checkboxText:SetText("")
        checkboxText:Hide()
    end

    unlockCheckbox:SetScript("OnClick", function(self)
        A:SetUnlockEnabled(self:GetChecked(), true)
    end)
end

local function EnsureControls()
    if not moduleEnabled() then return end

    local schematicForm = GetSchematicForm()
    local trackCheckbox = GetTrackRecipeCheckbox()
    if not schematicForm or not trackCheckbox then return end

    CreateControls(schematicForm)

    unlockCheckbox:ClearAllPoints()
    unlockCheckbox:SetPoint("TOPLEFT", trackCheckbox, "BOTTOMLEFT", 0, CHECKBOX_TOP_OFFSET)
    unlockCheckbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    unlockCheckbox:Show()

    unlockLabel:ClearAllPoints()
    unlockLabel:SetPoint("LEFT", unlockCheckbox, "RIGHT", LABEL_OFFSET_X, 0)
    unlockLabel:Show()

    if unlockCheckbox then unlockCheckbox:SetChecked(isUnlockEnabled) end
end

local function HookProfessionsFrame()
    if not moduleEnabled() then return end

    local schematicForm = GetSchematicForm()
    if not schematicForm or schematicForm.CraftyAllocatorHooked then return end

    schematicForm.CraftyAllocatorHooked = true

    if schematicForm.HookScript then
        schematicForm:HookScript("OnShow", EnsureControls)
        schematicForm:HookScript("OnHide", function()
            A:SetUnlockEnabled(false, false)
        end)
    end

    if schematicForm.Init then
        hooksecurefunc(schematicForm, "Init", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, EnsureControls)
            end
        end)
    end

    EnsureControls()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, EnsureControls)
    end
end

-- ----------------------------------------------------------------------------
-- Bootstrap
-- ----------------------------------------------------------------------------
-- This file only loads if the user enabled the Allocator module (Crafty's
-- ModuleRegistry calls LoadAddOn("FabledUI_Crafty_Allocator") on demand) OR
-- if Blizzard auto-loaded us at PLAYER_LOGIN because we were already loaded
-- in a prior session. Either way, we register late hooks so the schematic
-- form gets the Unlock checkbox.

if _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage then
    -- Blizzard_Professions already loaded — install immediately.
    EnsureFlyoutButtonOverrides()
    HookProfessionsFrame()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_Professions" or arg1 == "Blizzard_ProfessionsTemplates" then
                EnsureFlyoutButtonOverrides()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, HookProfessionsFrame)
                else
                    HookProfessionsFrame()
                end
            end
        elseif event == "PLAYER_LOGIN" then
            EnsureFlyoutButtonOverrides()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, HookProfessionsFrame)
            else
                HookProfessionsFrame()
            end
        end
    end)
end
