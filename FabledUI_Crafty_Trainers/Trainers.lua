local M = _G.FabledUI_Crafty
M.Trainers = M.Trainers or {}
local T = M.Trainers

function T:GetAll()
    return M.TrainerDB or {}
end

function T:GetFiltered()
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    local filterProfession = M.filters.profession or "ALL"
    local filterExpansion = M.filters.expansion or "ALL"
    local rows = {}
    for _, trainer in ipairs(self:GetAll()) do
        local passes = (filterProfession == "ALL" or trainer.profession == filterProfession)
            and (filterExpansion == "ALL" or trainer.expansion == filterExpansion)
        if passes then
            rows[#rows + 1] = trainer
        end
    end
    table.sort(rows, function(a, b)
        if a.expansion ~= b.expansion then
            return a.expansion < b.expansion
        end
        if a.profession ~= b.profession then
            return a.profession < b.profession
        end
        return a.name < b.name
    end)
    return rows
end

function T:SetWaypoint(trainer)
    if not trainer or not trainer.mapID then
        return false
    end

    local label = string.format("%s (%s)", trainer.name or "Trainer", trainer.profession or "Profession")

    -- Try suite waypoint addons first (Odyssey).
    -- Build the candidate list without a nil hole — a nil first entry
    -- (_G.FlayreDev_Odyssey is unset on current installs) makes ipairs stop
    -- before reaching Odyssey, silently skipping it. Also honor Odyssey's return
    -- (nil = rejected) and autoTrack so it actually navigates.
    local odyssey = (type(_G.FabledUI_Odyssey) == "table" and _G.FabledUI_Odyssey)
        or (type(_G.FlayreDev_Odyssey) == "table" and _G.FlayreDev_Odyssey) or nil
    if odyssey and type(odyssey.SetWaypoint) == "function" then
        local id = odyssey:SetWaypoint(trainer.x, trainer.y, trainer.mapID, { title = label, autoTrack = true })
        if id ~= nil then
            return true
        end
    end

    -- Fallback to native Blizzard waypoint
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint then
        local point = UiMapPoint.CreateFromCoordinates(trainer.mapID, trainer.x, trainer.y)
        if point then
            C_Map.SetUserWaypoint(point)
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            return true
        end
    end

    -- Last resort: TomTom
    if TomTom and type(TomTom.AddWaypoint) == "function" then
        local ok = pcall(TomTom.AddWaypoint, TomTom, trainer.mapID, trainer.x, trainer.y, {
            title = label,
            persistent = false,
            from = M.ADDON_NAME,
        })
        if ok then
            return true
        end
    end

    return false
end


function T:GetCharactersNeedingTraining(profession)
    if M.EnsureStorageTables then M:EnsureStorageTables() end
    local names = {}
    for characterKey, data in pairs(M.db.alts or {}) do
        local profData = data.professions and data.professions[profession]
        if not profData or (profData.skillLevel or 0) <= 0 then
            names[#names + 1] = M:GetShortCharacterName(characterKey)
        end
    end
    table.sort(names)
    return names
end




function T:GetFirstTrainerForProfession(profession)
    if not profession then
        return nil
    end
    for _, trainer in ipairs(self:GetAll()) do
        if trainer.profession == profession then
            return trainer
        end
    end
    local guide = M.Training and M.Training:GetGuide(profession, M.filters and M.filters.expansion) or nil
    if guide and guide.trainerZone and guide.trainerZone ~= "" then
        return {
            name = "Retail trainer guide",
            profession = profession,
            expansion = guide.tier or (M.filters and M.filters.expansion) or "Retail",
            zone = guide.trainerZone,
            x = 0,
            y = 0,
        }
    end
    return nil
end
