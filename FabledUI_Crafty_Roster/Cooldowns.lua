local M = _G.FabledUI_Crafty
M.Cooldowns = M.Cooldowns or {}
local C = M.Cooldowns

local function ensureAlt(characterKey, professionName)
    local char = M.Alts and M.Alts:GetCharacterData(characterKey)
    if not char then
        if M.Alts and M.Alts.RegisterCurrentCharacter then
            M.Alts:RegisterCurrentCharacter()
        end
        char = M.Alts and M.Alts:GetCharacterData(characterKey)
    end
    if not char then
        return nil
    end
    char.professions = type(char.professions) == 'table' and char.professions or {}
    char.professions[professionName] = type(char.professions[professionName]) == 'table' and char.professions[professionName] or {}
    return char.professions[professionName]
end

local function GetRecipeName(recipeID)
    local recipe = M.Recipes and M.Recipes.Get and M.Recipes:Get(recipeID) or nil
    if recipe and recipe.name and recipe.name ~= '' then
        return recipe.name
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and type(info) == 'table' and info.name and info.name ~= '' then
            return info.name
        end
    end
    return 'Recipe ' .. tostring(recipeID)
end

-- Returns true when this recipe is learned by the current character.
local function IsRecipeLearned(recipeID)
    if C_TradeSkillUI then
        if type(C_TradeSkillUI.GetRecipeInfo) == 'function' then
            local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if ok and type(info) == 'table' then
                if info.learned ~= nil then
                    return info.learned and true or false
                end
            end
        end
        if type(C_TradeSkillUI.IsRecipeProfessionLearned) == 'function' then
            local ok, learned = pcall(C_TradeSkillUI.IsRecipeProfessionLearned, recipeID)
            if ok then
                return learned and true or false
            end
        end
    end
    return true
end

function C:ScanOpenProfession(markDirty)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs or not C_TradeSkillUI.GetRecipeCooldown then
        return 0
    end
    local context = M.Concentration and M.Concentration:GetOpenProfessionContext() or nil
    if not context or not context.professionName then
        return 0
    end

    local characterKey = M:GetCurrentCharacterKey()
    local prof = ensureAlt(characterKey, context.professionName)
    if not prof then
        return 0
    end
    -- Reset cooldowns recorded for this profession on this character; we re-scan from scratch.
    prof.cooldowns = {}
    local count = 0
    local now = time()

    local ok, recipeIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if ok and type(recipeIDs) == 'table' then
        for _, recipeID in ipairs(recipeIDs) do
            if IsRecipeLearned(recipeID) then
                local okCd, currentCooldown, isDayCooldown, currentCharges, maxCharges = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
                if okCd then
                    local cd = tonumber(currentCooldown) or 0
                    local charges = tonumber(currentCharges) or 0
                    local maxC = tonumber(maxCharges) or 0
                    -- A recipe has a cooldown if it currently has time remaining,
                    -- if it is a day cooldown, or if it tracks charges.
                    if cd > 0 or isDayCooldown or maxC > 0 then
                        prof.cooldowns[recipeID] = {
                            recipeID       = recipeID,
                            recipeName     = GetRecipeName(recipeID),
                            charKey        = characterKey,
                            professionName = context.professionName,
                            cooldownEnd    = now + cd,
                            currentCooldown = cd,
                            isDayCooldown  = isDayCooldown and true or false,
                            charges        = charges,
                            maxCharges     = maxC,
                            -- Aliases retained for older readers:
                            currentCharges = charges,
                            name           = nil, -- legacy field cleared in favor of recipeName
                            readyAt        = now + cd,
                            lastScanned    = now,
                        }
                        prof.cooldowns[recipeID].name = prof.cooldowns[recipeID].recipeName
                        count = count + 1
                    end
                end
            end
        end
    end

    -- Mirror into the persistent SavedVariables location described in CR-014:
    -- M.db.cooldowns[charKey][recipeID]
    if type(M.db) == 'table' then
        M.db.cooldowns = type(M.db.cooldowns) == 'table' and M.db.cooldowns or {}
        M.db.cooldowns[characterKey] = type(M.db.cooldowns[characterKey]) == 'table' and M.db.cooldowns[characterKey] or {}
        for recipeID, entry in pairs(prof.cooldowns) do
            M.db.cooldowns[characterKey][recipeID] = entry
        end
        -- Drop stale entries on this profession that no longer have an active cooldown.
        for recipeID, entry in pairs(M.db.cooldowns[characterKey]) do
            if entry and entry.professionName == context.professionName and not prof.cooldowns[recipeID] then
                M.db.cooldowns[characterKey][recipeID] = nil
            end
        end
    end

    if markDirty then
        if M.MarkDirty then M:MarkDirty() end
        if M.Fire then
            M:Fire('AltDataChanged')
            M:Fire('DataChanged')
        end
    end

    return count
end

function C:GetRows(professionFilter)
    local rows = {}
    local now = time()
    for _, characterKey in ipairs(M.Alts and M.Alts:GetAllCharacters() or {}) do
        local char = M.Alts:GetCharacterData(characterKey) or {}
        for professionName, profData in pairs(char.professions or {}) do
            if (not professionFilter or professionFilter == 'ALL' or professionName == professionFilter) and type(profData.cooldowns) == 'table' then
                for _, cd in pairs(profData.cooldowns) do
                    local readyAtTs = tonumber(cd.cooldownEnd or cd.readyAt or 0) or 0
                    local seconds = math.max(0, readyAtTs - now)
                    local charges = tonumber(cd.charges or cd.currentCharges or 0) or 0
                    local maxC = tonumber(cd.maxCharges or 0) or 0
                    local readyAtText = (readyAtTs > 0) and date('%Y-%m-%d %H:%M', readyAtTs) or ''
                    rows[#rows + 1] = {
                        characterKey   = characterKey,
                        professionName = professionName,
                        recipeID       = cd.recipeID,
                        name           = cd.recipeName or cd.name,
                        recipeName     = cd.recipeName or cd.name,
                        currentCharges = charges,
                        charges        = charges,
                        maxCharges     = maxC,
                        seconds        = seconds,
                        cooldownEnd    = readyAtTs,
                        readyAt        = readyAtText,
                        isDayCooldown  = cd.isDayCooldown and true or false,
                    }
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if (a.seconds or 0) ~= (b.seconds or 0) then
            return (a.seconds or 0) < (b.seconds or 0)
        end
        if (a.professionName or '') ~= (b.professionName or '') then
            return (a.professionName or '') < (b.professionName or '')
        end
        return (a.name or '') < (b.name or '')
    end)
    return rows
end

-- Summary used by the Timers tab footer / status text.
-- Returns: readyCount, totalCount, nextReadyRow (or nil).
function C:GetSummary(professionFilter)
    local rows = self:GetRows(professionFilter)
    local readyCount, total = 0, #rows
    local nextRow
    for _, row in ipairs(rows) do
        local hasCharges = (row.maxCharges or 0) > 0 and (row.charges or 0) > 0
        if (row.seconds or 0) <= 0 or hasCharges then
            readyCount = readyCount + 1
        end
        if (row.seconds or 0) > 0 then
            if not nextRow or (row.seconds < nextRow.seconds) then
                nextRow = row
            end
        end
    end
    return readyCount, total, nextRow
end
