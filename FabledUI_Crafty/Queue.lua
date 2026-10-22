local M = _G.FabledUI_Crafty
M.Queue = M.Queue or {}
local Q = M.Queue

local function MakeKey(recipeID, character, orderID)
    if orderID and tonumber(orderID) then
        return string.format('%d:%s:order:%d', tonumber(recipeID) or 0, character or M:GetCurrentCharacterKey(), tonumber(orderID))
    end
    return string.format('%d:%s', tonumber(recipeID) or 0, character or M:GetCurrentCharacterKey())
end

local function normalizeOpts(character, opts)
    if type(character) == 'table' and opts == nil then
        opts = character
        character = nil
    end
    opts = type(opts) == 'table' and opts or {}
    return character, opts
end

function Q:GetProjectedProducedQuantity(itemID)
    return (M.Shopping and M.Shopping.GetProjectedProducedQuantity and M.Shopping:GetProjectedProducedQuantity(itemID, self:GetAll())) or 0
end

function Q:Add(recipeID, quantity, character, opts)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    character, opts = normalizeOpts(character, opts)
    recipeID = tonumber(recipeID)
    quantity = math.max(1, tonumber(quantity) or 1)
    local recipe = M.Recipes and M.Recipes:Get(recipeID) or nil
    character = character or (M.Alts and M.Alts:GetBestCrafterForRecipe(recipe)) or M:GetCurrentCharacterKey()

    if not recipeID then
        return false
    end

    -- P2-30: respect click-lock for user-driven calls. Internal sub-craft
    -- enqueues (opts._skipSubcraft branches and recursive calls) explicitly
    -- bypass the lock by passing opts._bypassClickLock = true, so a single
    -- top-level Add doesn't get strangled by its own sub-recipe expansion.
    if not (opts and opts._bypassClickLock) and self.IsLocked and self:IsLocked() then
        return false
    end

    local engine = (M.Shopping and M.Shopping.GetPlannerEngine and M.Shopping:GetPlannerEngine(opts)) or opts.engine or 'Crafty'
    local key = MakeKey(recipeID, character, opts.orderID)
    local entry = M.db.queue[key]
    if entry then
        entry.quantity = (entry.quantity or 0) + quantity
        entry.updatedAt = time()
    else
        entry = {
            recipeID = recipeID,
            quantity = quantity,
            character = character,
            addedAt = time(),
            updatedAt = time(),
            recraft = opts.recraft == true,
            orderID = tonumber(opts.orderID),
            engine = engine,
            sourceMode = opts.sourceMode or ((M.settings and M.settings.shoppingListModePSL) and 'PSL' or 'Crafty'),
        }
        M.db.queue[key] = entry
    end

    if opts.recraft ~= nil then
        entry.recraft = opts.recraft == true
    end
    if opts.orderID ~= nil then
        entry.orderID = tonumber(opts.orderID)
    end
    entry.engine = engine

    if not opts._skipSubcraft and M.Shopping and M.Shopping.UsesRecursivePlanner and M.Shopping:UsesRecursivePlanner({ engine = engine }) then
        local pendingEntries = M.Shopping:BuildSubcraftEntries(recipe, quantity, character, self:GetAll(), opts._visited)
        for _, pending in ipairs(pendingEntries or {}) do
            -- Sub-craft enqueues are internal — bypass the user-facing
            -- click-lock so a single top-level Add doesn't lose its
            -- recursive expansion if BeginCraftClickLock was just fired.
            pending._bypassClickLock = true
            self:Add(pending.recipeID, pending.quantity, pending.character, pending)
        end
    end

    if M.History and M.History.RecordAcquisition then
        M.History:RecordAcquisition('queue_add', recipeID, quantity, character)
    end
    M:MarkDirty()
    M:Fire('QueueChanged')
    M:Fire('DataChanged')
    return true
end

function Q:FindEntriesByRecipe(recipeID)
    local entries = {}
    recipeID = tonumber(recipeID)
    for key, entry in pairs((M.db and M.db.queue) or {}) do
        if tonumber(entry.recipeID) == recipeID then
            entries[#entries + 1] = { key = key, entry = entry }
        end
    end
    table.sort(entries, function(a, b)
        return (a.entry.updatedAt or a.entry.addedAt or 0) > (b.entry.updatedAt or b.entry.addedAt or 0)
    end)
    return entries
end

function Q:Remove(recipeID, character, orderID)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    if not character then
        local removed = 0
        for _, row in ipairs(self:FindEntriesByRecipe(recipeID)) do
            if orderID == nil or tonumber(row.entry.orderID) == tonumber(orderID) then
                M.db.queue[row.key] = nil
                removed = removed + 1
            end
        end
        if removed > 0 then
            M:MarkDirty()
            M:Fire('QueueChanged')
            M:Fire('DataChanged')
        end
        return removed > 0
    end
    local key = MakeKey(recipeID, character, orderID)
    M.db.queue[key] = nil
    M:MarkDirty()
    M:Fire('QueueChanged')
    M:Fire('DataChanged')
    return true
end

function Q:SetQuantity(recipeID, character, quantity, orderID)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    quantity = tonumber(quantity) or 0
    if quantity <= 0 then
        self:Remove(recipeID, character, orderID)
        return
    end

    local key = MakeKey(recipeID, character, orderID)
    if M.db.queue[key] then
        M.db.queue[key].quantity = quantity
        M.db.queue[key].updatedAt = time()
        M:MarkDirty()
        M:Fire('QueueChanged')
        M:Fire('DataChanged')
        return
    end

    self:Add(recipeID, quantity, character, { orderID = orderID })
end

function Q:ChangeQuantity(recipeID, character, delta, orderID)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    if character then
        local key = MakeKey(recipeID, character, orderID)
        local entry = M.db.queue[key]
        if not entry then
            return
        end
        self:SetQuantity(recipeID, character, (entry.quantity or 0) + (tonumber(delta) or 0), orderID)
        return
    end

    local entries = self:FindEntriesByRecipe(recipeID)
    if entries[1] then
        local entry = entries[1].entry
        self:SetQuantity(recipeID, entry.character, (entry.quantity or 0) + (tonumber(delta) or 0), entry.orderID)
    end
end

function Q:Clear()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    table.wipe(M.db.queue)
    M:MarkDirty()
    M:Fire('QueueChanged')
    M:Fire('DataChanged')
end

function Q:GetAll()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    local list = {}
    for _, entry in pairs(M.db.queue) do
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        if a.character ~= b.character then
            return a.character < b.character
        end
        local ar = M.Recipes and M.Recipes:Get(a.recipeID)
        local br = M.Recipes and M.Recipes:Get(b.recipeID)
        local an = ar and ar.name or tostring(a.recipeID)
        local bn = br and br.name or tostring(b.recipeID)
        return an < bn
    end)
    return list
end

function Q:GetRecipeQueuedQuantity(recipeID)
    local total = 0
    for _, entry in ipairs(self:GetAll()) do
        if tonumber(entry.recipeID) == tonumber(recipeID) then
            total = total + (tonumber(entry.quantity) or 0)
        end
    end
    return total
end

function Q:GetGroupedByCharacter()
    local grouped = {}
    for _, entry in ipairs(self:GetAll()) do
        grouped[entry.character] = grouped[entry.character] or {}
        grouped[entry.character][#grouped[entry.character] + 1] = entry
    end
    return grouped
end

function Q:GetSummary()
    local entries = self:GetAll()
    local characterSet = {}
    local totalQuantity = 0
    local recrafts = 0
    local orders = 0
    local craftSimLike = 0
    local pslEntries = 0
    for _, entry in ipairs(entries) do
        characterSet[entry.character or 'Unknown'] = true
        totalQuantity = totalQuantity + (entry.quantity or 0)
        if entry.recraft then
            recrafts = recrafts + 1
        end
        if entry.orderID then
            orders = orders + 1
        end
        if entry.engine == 'CraftSim-like' then
            craftSimLike = craftSimLike + 1
        end
        if entry.sourceMode == 'PSL' then
            pslEntries = pslEntries + 1
        end
    end
    return {
        entries = #entries,
        characters = M.Util and M.Util:TableCount(characterSet) or 0,
        totalQuantity = totalQuantity,
        recrafts = recrafts,
        orders = orders,
        craftSimLike = craftSimLike,
        pslEntries = pslEntries,
    }
end

-- P0-3: Build per-recipe craftability status using a single bag-counts
-- snapshot rather than per-recipe-per-reagent C_Item.GetItemCount calls.
-- For a queue of N entries with M reagents each, the old path issued
-- N*M GetItemCount calls (each scanning every bag); this issues exactly
-- one bag walk total. Pattern lifted from ThendarsLumberTracker:7121-7145.
function Q:GetStatus()
    local bagCounts = (M.Materials and M.Materials.GetBagCounts and M.Materials:GetBagCounts()) or {}
    local entries = self:GetAll()
    local rows = {}
    for _, entry in ipairs(entries) do
        local recipe = M.Recipes and M.Recipes:Get(entry.recipeID) or nil
        local craftableNow = 0
        local missingReagents = 0
        if recipe and type(recipe.materials) == "table" then
            local minRatio
            for _, mat in ipairs(recipe.materials) do
                local need = (tonumber(mat.qty) or 0) * (tonumber(entry.quantity) or 1)
                local have = bagCounts[tonumber(mat.itemID) or -1] or 0
                if have < need then
                    missingReagents = missingReagents + 1
                end
                if (tonumber(mat.qty) or 0) > 0 then
                    local ratio = math.floor(have / (tonumber(mat.qty) or 1))
                    if minRatio == nil or ratio < minRatio then
                        minRatio = ratio
                    end
                end
            end
            craftableNow = minRatio or 0
        end
        rows[#rows + 1] = {
            entry = entry,
            recipe = recipe,
            craftableNow = math.min(craftableNow, tonumber(entry.quantity) or 0),
            missingReagents = missingReagents,
            -- A recipe with no resolved materials data must not report as
            -- "ready" (that produced a ready=true / craftableNow=0 row). (Fix B6)
            ready = (recipe ~= nil and type(recipe.materials) == "table") and missingReagents == 0 or false,
        }
    end
    return rows
end

-- P2-30: CraftSim-style click lock. A burst of craft-button presses (or a
-- mis-firing keybind) used to enqueue duplicate sub-craft entries; this
-- 0.8s window rejects subsequent Add() calls until either the timer
-- expires or TRADE_SKILL_ITEM_CRAFTED_RESULT releases it via :EndCraftClickLock.
-- Pattern from .sample-addons/CraftSim/Modules/CraftQueue/CraftQueue.lua:71-111.
local DEFAULT_CLICK_LOCK_SECONDS = 0.8

function Q:BeginCraftClickLock(seconds)
    local lockSeconds = tonumber(seconds) or DEFAULT_CLICK_LOCK_SECONDS
    self._craftClickLockUntil = (GetTime and GetTime() or 0) + lockSeconds

    if C_Timer and C_Timer.After then
        C_Timer.After(lockSeconds + 0.05, function()
            if not self._craftClickLockUntil or self._craftClickLockUntil <= 0 then
                return
            end
            local now = GetTime and GetTime() or 0
            if now >= self._craftClickLockUntil then
                self._craftClickLockUntil = 0
            end
        end)
    end
end

function Q:EndCraftClickLock()
    self._craftClickLockUntil = 0
end

function Q:IsLocked()
    local until_ = self._craftClickLockUntil or 0
    if until_ <= 0 then
        return false
    end
    if C_TradeSkillUI and C_TradeSkillUI.IsCrafting and C_TradeSkillUI.IsCrafting() then
        return true
    end
    local now = GetTime and GetTime() or 0
    if now < until_ then
        return true
    end
    self._craftClickLockUntil = 0
    return false
end

function Q:AddAllFiltered()
    local added = 0
    for _, row in ipairs(M.Recipes:GetFilteredList()) do
        if row.craftable then
            if self:Add(row.recipeID, 1) then
                added = added + 1
            end
        end
    end
    return added
end

function Q:TrackRecipe(recipeID, quantity, recraft, orderID)
    return self:Add(recipeID, quantity, nil, {
        recraft = recraft == true,
        orderID = orderID,
        engine = (M.settings and M.settings.useCraftSimQueuePlanner) and 'CraftSim-like' or 'Crafty',
        sourceMode = 'PSL',
    })
end

function Q:UntrackRecipe(recipeID, quantity)
    quantity = tonumber(quantity) or 0
    if quantity <= 0 then
        return self:Remove(recipeID)
    end
    local remaining = quantity
    for _, row in ipairs(self:FindEntriesByRecipe(recipeID)) do
        local entry = row.entry
        local consume = math.min(remaining, tonumber(entry.quantity) or 0)
        self:SetQuantity(recipeID, entry.character, (tonumber(entry.quantity) or 0) - consume, entry.orderID)
        remaining = remaining - consume
        if remaining <= 0 then
            break
        end
    end
    return true
end
