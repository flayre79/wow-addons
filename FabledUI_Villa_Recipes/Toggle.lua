-- The "Decor only" toggle on Blizzard's profession window.
--
-- Blizzard's recipe list has no decor filter (12.1 filter menu: learned,
-- unlearned, skill-up, first craft, makeable, sources, slots, expansion --
-- Blizzard_Professions.lua, Professions.InitFilterMenu). The list is a
-- TreeDataProvider that ProfessionsCraftingPageMixin:Init rebuilds from
-- C_TradeSkillUI.GetFilteredRecipeIDs on every list update, so the way in that
-- touches nothing of Blizzard's is:
--
--   * hooksecurefunc the page's Init -- a post-hook, the original runs untouched
--   * after it, walk the tree Blizzard just built and REMOVE the recipe nodes
--     that do not make decor, then the categories left with nothing in them
--   * keep every removed node with its parent and index, so switching the
--     toggle off puts them straight back -- no call into Blizzard's rebuild
--
-- No Blizzard function is replaced and none is called from here except the
-- tree node API on the provider Blizzard handed to its own ScrollBox. The
-- Crafty overlay on the same window uses parenting + HookScript only and has
-- been fine; this is the same posture plus one hooksecurefunc.
--
-- Node shapes, from Professions.GenerateCraftingDataProvider (live source):
--   { recipeInfo = ..., order = 0 }             a recipe
--   { categoryInfo = ..., group = ... }         a category (has child nodes)
--   { topPadding = true } / { bottomPadding = true } / { isDivider = true }

local Recipes = _G.FabledUI_VillaRecipes
if not Recipes then return end

local Toggle = {}
Recipes.Toggle = Toggle

local PROFESSIONS_ADDON = "Blizzard_Professions"

function Recipes:DB()
    local db = rawget(_G, "FabledUI_VillaRecipesDB")
    if type(db) ~= "table" then
        db = {}
        _G.FabledUI_VillaRecipesDB = db
    end
    if db.decorOnly == nil then db.decorOnly = false end
    return db
end

-- -----------------------------------------------------------------------------
-- Pruning and restoring (pure tree work; tests drive it with a fake provider)
-- -----------------------------------------------------------------------------

Toggle._removed = {}   -- { { parent = node, node = node, index = n }, ... } in removal order
Toggle._pruned = nil   -- the provider currently pruned, so a rebuild is told apart

local function nodeData(node)
    local ok, data = pcall(node.GetData, node)
    if ok and type(data) == "table" then return data end
    return {}
end

local function childNodes(node)
    local ok, nodes = pcall(node.GetNodes, node)
    if ok and type(nodes) == "table" then return nodes end
    return {}
end

local function indexOf(parent, node)
    for index, child in ipairs(childNodes(parent)) do
        if child == node then return index end
    end
    return nil
end

function Toggle:_Remove(parent, node)
    local index = indexOf(parent, node)
    if not index then return false end
    local ok = pcall(parent.Remove, parent, node, true)
    if ok then
        self._removed[#self._removed + 1] = { parent = parent, node = node, index = index }
    end
    return ok
end

-- Removes non-decor recipes under `node`; returns true when a recipe remains.
function Toggle:_PruneNode(node, isDecor)
    local keptRecipe = false
    -- Copy first: removing while iterating skips siblings.
    local children = {}
    for _, child in ipairs(childNodes(node)) do children[#children + 1] = child end

    for _, child in ipairs(children) do
        local data = nodeData(child)
        if data.recipeInfo then
            local recipeID = type(data.recipeInfo) == "table" and data.recipeInfo.recipeID or nil
            if recipeID and isDecor(recipeID) then
                keptRecipe = true
            else
                self:_Remove(node, child)
            end
        elseif data.categoryInfo then
            if self:_PruneNode(child, isDecor) then
                keptRecipe = true
            else
                self:_Remove(node, child)
            end
        elseif data.isDivider then
            -- The learned/unlearned divider: keep it, it is only art.
        end
    end
    return keptRecipe
end

function Toggle:Prune(dataProvider, isDecor)
    if type(dataProvider) ~= "table" or type(dataProvider.GetRootNode) ~= "function" then return false end
    if self._pruned == dataProvider then return true end -- already done for this build
    self._removed = {}
    self._pruned = dataProvider
    local root = dataProvider:GetRootNode()
    self:_PruneNode(root, isDecor)
    if type(dataProvider.Invalidate) == "function" then pcall(dataProvider.Invalidate, dataProvider) end
    return true
end

-- Puts every removed node back where it was. Only valid for the provider
-- that was pruned; a provider Blizzard has since rebuilt is left alone.
function Toggle:Restore(dataProvider)
    if not self._pruned or (dataProvider and dataProvider ~= self._pruned) then
        self._removed, self._pruned = {}, nil
        return false
    end
    for index = #self._removed, 1, -1 do
        local entry = self._removed[index]
        pcall(entry.parent.InsertNode, entry.parent, entry.node, entry.index)
    end
    local provider = self._pruned
    self._removed, self._pruned = {}, nil
    if type(provider.Invalidate) == "function" then pcall(provider.Invalidate, provider) end
    return true
end

function Toggle:RemovedCount()
    return #self._removed
end

-- -----------------------------------------------------------------------------
-- Wiring to the live window
-- -----------------------------------------------------------------------------

local function craftingPage()
    local frame = rawget(_G, "ProfessionsFrame")
    return type(frame) == "table" and frame.CraftingPage or nil
end

local function currentProvider()
    local page = craftingPage()
    local list = page and page.RecipeList
    local box = list and list.ScrollBox
    if box and type(box.GetDataProvider) == "function" then
        local ok, provider = pcall(box.GetDataProvider, box)
        if ok then return provider end
    end
    return nil
end

function Toggle:Apply()
    local provider = currentProvider()
    if not provider then return end
    if Recipes:DB().decorOnly then
        self:Prune(provider, function(recipeID) return Recipes:IsDecorRecipe(recipeID) end)
    else
        self:Restore(provider)
    end
    if self.button then self.button:SetChecked(Recipes:DB().decorOnly) end
end

function Toggle:OnPageInit()
    -- Blizzard rebuilt the tree: whatever we removed from the old one is gone
    -- with it. Start clean and prune the new one if the toggle is on.
    self._removed, self._pruned = {}, nil
    if Recipes:DB().decorOnly then self:Apply() end
end

function Toggle:Set(on)
    Recipes:DB().decorOnly = on and true or false
    self:Apply()
end

function Toggle:Install()
    if self._installed then return true end
    local page = craftingPage()
    if not page or type(page.Init) ~= "function" then return false end
    local list = page.RecipeList
    local anchor = list and list.FilterDropdown
    if not anchor then return false end

    hooksecurefunc(page, "Init", function() Toggle:OnPageInit() end)

    local button = CreateFrame("CheckButton", "FabledUI_VillaRecipesDecorToggle", list, "UICheckButtonTemplate")
    button:SetSize(22, 22)
    button:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("RIGHT", button, "LEFT", -2, 0)
    label:SetText("Decor only")
    button:SetChecked(Recipes:DB().decorOnly)
    button:SetScript("OnClick", function(self) Toggle:Set(self:GetChecked()) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Decor only")
        GameTooltip:AddLine("Show only recipes that make housing decor. Blizzard's own filters still apply on top.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.button = button

    self._installed = true
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, _, loaded)
    if loaded == PROFESSIONS_ADDON then
        Toggle:Install()
        -- The page may already have run Init before we hooked it.
        if Recipes:DB().decorOnly then Toggle:Apply() end
    end
end)
pcall(eventFrame.RegisterEvent, eventFrame, "ADDON_LOADED")
if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, already = pcall(C_AddOns.IsAddOnLoaded, PROFESSIONS_ADDON)
    if ok and already then Toggle:Install() end
end

SLASH_FABLEDUI_VILLARECIPES1 = "/vrecipes"
SlashCmdList["FABLEDUI_VILLARECIPES"] = function(msg)
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local function say(...) print("|cffffb81c[Villa Recipes]|r", ...) end
    if cmd == "on" or cmd == "off" then
        Toggle:Set(cmd == "on")
        say("Decor only " .. cmd .. ".")
    elseif cmd == "status" then
        local decor, total = 0, 0
        for _, v in pairs(Recipes._decorByRecipe) do
            total = total + 1
            if v then decor = decor + 1 end
        end
        say(string.format("decor only: %s | toggle installed: %s | recipes checked: %d (%d decor) | removed from list: %d | import rows: %s",
            tostring(Recipes:DB().decorOnly), tostring(Toggle._installed and true or false), total, decor,
            Toggle:RemovedCount(), tostring(Recipes._recipeByDecor and (function() local n = 0 for _ in pairs(Recipes._recipeByDecor) do n = n + 1 end return n end)() or "not loaded")))
    else
        say("/vrecipes on | off | status")
    end
end
