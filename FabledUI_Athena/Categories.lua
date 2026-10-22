local A = Athena

-- Categories are tags, not folders: an addon may belong to several at once, and
-- the Blizzard chips feature depends on that. The tree adds `parent` and `order`
-- for *display* structure only -- nesting a category never changes which addons
-- are tagged with it.
local MAX_TREE_DEPTH = 12

local function ReadCategories()
    local categories = A.Storage:Get("account", { "categories" }, {})
    return type(categories) == "table" and categories or {}
end

-- Resolve every category's effective parent, mapping anything unusable to a
-- root. SavedVariables are user-editable and survive addon downgrades, so a
-- parent may point at a deleted category, at itself, or around a cycle. Every
-- tree walk below relies on this having already produced a forest.
local function ResolveParents(categories)
    local parents = {}
    for key, category in pairs(categories) do
        if type(category) == "table" then
            local parentKey = type(category.parent) == "string" and category.parent or nil
            if parentKey == key then
                parentKey = nil
            end
            if parentKey and type(categories[parentKey]) ~= "table" then
                parentKey = nil
            end
            parents[key] = parentKey
        end
    end

    for key in pairs(parents) do
        local seen, cursor, depth = { [key] = true }, parents[key], 0
        while cursor do
            depth = depth + 1
            if seen[cursor] or depth > MAX_TREE_DEPTH then
                parents[key] = nil
                break
            end
            seen[cursor] = true
            cursor = parents[cursor]
        end
    end

    return parents
end

-- Iterate `categories`, not `parents`. A root's parent is nil, and storing nil in
-- a Lua table removes the key entirely -- so every root is absent from `parents`
-- and iterating it would silently yield an empty tree.
local function SiblingsOf(categories, parents, parentKey)
    local siblings = {}
    for key, category in pairs(categories) do
        if type(category) == "table" and parents[key] == parentKey then
            siblings[#siblings + 1] = key
        end
    end

    table.sort(siblings, function(left, right)
        local leftOrder = tonumber(categories[left] and categories[left].order)
        local rightOrder = tonumber(categories[right] and categories[right].order)
        if leftOrder and rightOrder and leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        if leftOrder and not rightOrder then return true end
        if rightOrder and not leftOrder then return false end

        local leftName = tostring((categories[left] and categories[left].name) or left):lower()
        local rightName = tostring((categories[right] and categories[right].name) or right):lower()
        if leftName ~= rightName then
            return leftName < rightName
        end
        return left < right
    end)

    return siblings
end

function A:GetCategories()
    return A.DeepCopy(ReadCategories())
end

function A:ListCategories()
    return A.SortedKeys(ReadCategories())
end

function A:GetCategory(categoryKey)
    local category = ReadCategories()[categoryKey]
    return type(category) == "table" and A.DeepCopy(category) or nil
end

function A:GetCollapsedCategories()
    local collapsed = self.Storage:Get("account", { "categoryCollapsed" }, nil)
    return type(collapsed) == "table" and collapsed or {}
end

function A:SetCategoryCollapsed(categoryKey, collapsed)
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return false
    end
    return self.Storage:Set(
        "account",
        { "categoryCollapsed", categoryKey },
        collapsed and true or nil
    )
end

function A:ToggleCategoryCollapsed(categoryKey)
    local collapsed = self:GetCollapsedCategories()
    return self:SetCategoryCollapsed(categoryKey, not collapsed[categoryKey])
end

-- Flattened depth-annotated rows in display order. Collapsed subtrees are
-- skipped unless `includeCollapsed` is set (drag targeting needs the full set).
function A:GetCategoryTree(includeCollapsed)
    local categories = ReadCategories()
    local parents = ResolveParents(categories)
    local collapsed = self:GetCollapsedCategories()
    local rows = {}

    local function Walk(parentKey, depth)
        if depth > MAX_TREE_DEPTH then
            return
        end
        for _, key in ipairs(SiblingsOf(categories, parents, parentKey)) do
            local children = SiblingsOf(categories, parents, key)
            local isCollapsed = collapsed[key] == true
            rows[#rows + 1] = {
                key = key,
                name = (categories[key] and categories[key].name) or key,
                depth = depth,
                parent = parentKey,
                hasChildren = #children > 0,
                collapsed = isCollapsed,
            }
            if #children > 0 and (includeCollapsed or not isCollapsed) then
                Walk(key, depth + 1)
            end
        end
    end

    Walk(nil, 0)
    return rows
end

-- The category itself plus everything beneath it. Filtering by a parent shows
-- addons tagged into any descendant, which is the point of nesting.
function A:GetCategoryDescendants(categoryKey)
    local result = {}
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return result
    end

    local categories = ReadCategories()
    local parents = ResolveParents(categories)
    result[categoryKey] = true

    local changed = true
    while changed do
        changed = false
        for key, parentKey in pairs(parents) do
            if parentKey and result[parentKey] and not result[key] then
                result[key] = true
                changed = true
            end
        end
    end

    return result
end

function A:IsCategoryDescendant(categoryKey, ancestorKey)
    if type(categoryKey) ~= "string" or type(ancestorKey) ~= "string" then
        return false
    end
    if categoryKey == ancestorKey then
        return false
    end
    return self:GetCategoryDescendants(ancestorKey)[categoryKey] == true
end

function A:CreateCategory(name, parentKey)
    name = A.Trim(name)
    if name == "" then
        return nil
    end

    local createdKey
    local _, ok = A.Storage:Mutate("account", { "categories" }, function(categories)
        categories = type(categories) == "table" and categories or {}

        local key = A.NormalizeKey(name)
        local base, suffix = key, 2
        while categories[key] do
            key = base .. "_" .. suffix
            suffix = suffix + 1
        end

        local effectiveParent = nil
        if type(parentKey) == "string" and parentKey ~= "" and type(categories[parentKey]) == "table" then
            effectiveParent = parentKey
        end

        local highest = 0
        local parents = ResolveParents(categories)
        for _, siblingKey in ipairs(SiblingsOf(categories, parents, effectiveParent)) do
            local order = tonumber(categories[siblingKey].order) or 0
            if order > highest then
                highest = order
            end
        end

        categories[key] = { name = name, parent = effectiveParent, order = highest + 1 }
        createdKey = key
        return categories
    end)

    return ok and createdKey or nil
end

function A:RenameCategory(categoryKey, newName)
    newName = A.Trim(newName)
    if type(categoryKey) ~= "string" or newName == "" then
        return false
    end

    local renamed = false
    local _, ok = A.Storage:Mutate("account", { "categories" }, function(categories)
        categories = type(categories) == "table" and categories or {}
        if type(categories[categoryKey]) == "table" then
            categories[categoryKey].name = newName
            renamed = true
        end
        return categories
    end)
    return ok and renamed
end

function A:DeleteCategory(categoryKey)
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return false
    end

    local deleted = false
    local _, ok = A.Storage:Mutate("account", {}, function(root)
        root = type(root) == "table" and root or {}
        root.categories = type(root.categories) == "table" and root.categories or {}
        root.addonCategoryMap = type(root.addonCategoryMap) == "table" and root.addonCategoryMap or {}

        local target = root.categories[categoryKey]
        if type(target) ~= "table" then
            return root
        end

        -- Promote children rather than deleting the subtree: removing a grouping
        -- label should never silently discard the categories filed under it.
        local promotedParent = type(target.parent) == "string" and target.parent or nil
        if promotedParent == categoryKey or type(root.categories[promotedParent]) ~= "table" then
            promotedParent = nil
        end
        for _, category in pairs(root.categories) do
            if type(category) == "table" and category.parent == categoryKey then
                category.parent = promotedParent
            end
        end

        root.categories[categoryKey] = nil
        deleted = true

        if type(root.categoryCollapsed) == "table" then
            root.categoryCollapsed[categoryKey] = nil
        end

        for addonName, categorySet in pairs(root.addonCategoryMap) do
            if type(categorySet) == "table" and categorySet[categoryKey] then
                categorySet[categoryKey] = nil
                if not next(categorySet) then
                    root.addonCategoryMap[addonName] = nil
                end
            end
        end
        return root
    end)
    return ok and deleted
end

-- Reposition a category in the tree. `mode` is "into" (become target's child),
-- "before" or "after" (become target's sibling). Siblings are renumbered 1..n on
-- every move so `order` stays dense and comparisons stay trivial.
function A:MoveCategory(categoryKey, targetKey, mode)
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return false
    end
    if categoryKey == targetKey then
        return false
    end
    mode = mode or "into"

    -- Dropping a category into its own subtree would orphan the whole branch.
    if type(targetKey) == "string" and targetKey ~= ""
        and self:IsCategoryDescendant(targetKey, categoryKey) then
        return false
    end

    local moved = false
    local _, ok = A.Storage:Mutate("account", { "categories" }, function(categories)
        categories = type(categories) == "table" and categories or {}
        if type(categories[categoryKey]) ~= "table" then
            return categories
        end

        local parents = ResolveParents(categories)
        local newParent, anchorKey = nil, nil

        if type(targetKey) == "string" and targetKey ~= "" and type(categories[targetKey]) == "table" then
            if mode == "into" then
                newParent = targetKey
            else
                newParent = parents[targetKey]
                anchorKey = targetKey
            end
        end

        local siblings = {}
        for _, siblingKey in ipairs(SiblingsOf(categories, parents, newParent)) do
            if siblingKey ~= categoryKey then
                siblings[#siblings + 1] = siblingKey
            end
        end

        local insertAt = #siblings + 1
        if anchorKey then
            for index, siblingKey in ipairs(siblings) do
                if siblingKey == anchorKey then
                    insertAt = mode == "after" and index + 1 or index
                    break
                end
            end
        end
        table.insert(siblings, insertAt, categoryKey)

        categories[categoryKey].parent = newParent
        for index, siblingKey in ipairs(siblings) do
            categories[siblingKey].order = index
        end

        moved = true
        return categories
    end)

    return ok and moved
end

function A:GetAddonCategorySet(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return {}
    end
    local categorySet = A.Storage:Get("account", { "addonCategoryMap", addonName }, nil)
    return type(categorySet) == "table" and A.DeepCopy(categorySet) or {}
end

function A:SetAddonCategories(addonName, categorySet)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end

    local categories = ReadCategories()
    local sanitized = {}
    if type(categorySet) == "table" then
        for categoryKey, assigned in pairs(categorySet) do
            if assigned and categories[categoryKey] ~= nil then
                sanitized[categoryKey] = true
            end
        end
    end

    return A.Storage:Set(
        "account",
        { "addonCategoryMap", addonName },
        next(sanitized) and sanitized or nil
    )
end

-- Drag-and-drop assignment. Tags are additive by default; `exclusive` (shift)
-- clears the addon's other categories so a drag reads as a move instead.
function A:AssignAddonToCategory(addonName, categoryKey, exclusive)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return false
    end
    if ReadCategories()[categoryKey] == nil then
        return false
    end

    local categorySet = exclusive and {} or self:GetAddonCategorySet(addonName)
    categorySet[categoryKey] = true
    return self:SetAddonCategories(addonName, categorySet)
end

-- Shift-dragging a row out of one group and into another. Only the membership
-- you dragged out of is removed; every other tag the addon carries survives,
-- which is what separates this from the `exclusive` flag above.
function A:MoveAddonBetweenCategories(addonName, fromKey, toKey)
    if not self:AssignAddonToCategory(addonName, toKey) then
        return false
    end
    if type(fromKey) == "string" and fromKey ~= "" and fromKey ~= toKey then
        self:UnassignAddonFromCategory(addonName, fromKey)
    end
    return true
end

function A:UnassignAddonFromCategory(addonName, categoryKey)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end
    local categorySet = self:GetAddonCategorySet(addonName)
    if not categorySet[categoryKey] then
        return false
    end
    categorySet[categoryKey] = nil
    return self:SetAddonCategories(addonName, categorySet)
end

function A:ParseCategoryNamesToSet(csv)
    local categorySet = {}
    for token in A.Trim(csv):gmatch("([^,]+)") do
        local name = A.Trim(token)
        if name ~= "" then
            local foundKey
            for categoryKey, category in pairs(ReadCategories()) do
                if category and type(category.name) == "string" and category.name:lower() == name:lower() then
                    foundKey = categoryKey
                    break
                end
            end
            if not foundKey then
                foundKey = self:CreateCategory(name)
            end
            if foundKey then
                categorySet[foundKey] = true
            end
        end
    end
    return categorySet
end

function A:CategorySetToDisplayString(categorySet)
    if type(categorySet) ~= "table" then
        return ""
    end

    local categories, names = ReadCategories(), {}
    for categoryKey in pairs(categorySet) do
        local category = categories[categoryKey]
        names[#names + 1] = (category and category.name) or categoryKey
    end
    table.sort(names)
    return table.concat(names, ", ")
end
