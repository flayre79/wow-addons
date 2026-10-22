local M = _G.FabledUI_Crafty
M.Concentration = M.Concentration or {}
local C = M.Concentration

local notificationState = {}

local function safeFloor(value)
    return math.floor((tonumber(value) or 0) + 0.00001)
end

function C:GetOpenProfessionContext()
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetTradeSkillLine) ~= "function" then
        return nil
    end

    local skillLineID, skillLineDisplayName, skillLineRank, skillLineMaxRank, _, parentSkillLineID, parentSkillLineDisplayName = C_TradeSkillUI.GetTradeSkillLine()
    if not skillLineID then
        return nil
    end

    local info = type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID) or nil
    local professionName = (info and info.professionName) or parentSkillLineDisplayName or skillLineDisplayName
    local professionID = (info and info.professionID) or parentSkillLineID or skillLineID

    return {
        skillLineID = skillLineID,
        professionID = professionID,
        professionName = professionName,
        skillLevel = (info and info.skillLevel) or skillLineRank or 0,
        maxSkillLevel = (info and info.maxSkillLevel) or skillLineMaxRank or 0,
    }
end

function C:CaptureOpenProfession(markDirty)
    if not M.Alts or not M.Alts.RegisterCurrentCharacter then
        return nil
    end

    local context = self:GetOpenProfessionContext()
    if not context or not context.professionName or type(C_TradeSkillUI.GetConcentrationCurrencyID) ~= "function" then
        return nil
    end

    local currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(context.skillLineID)
    if not currencyID then
        return nil
    end

    local currencyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID) or nil
    if type(currencyInfo) ~= "table" then
        return nil
    end

    local characterKey, entry = M.Alts:RegisterCurrentCharacter()
    entry.concentration = type(entry.concentration) == "table" and entry.concentration or {}

    entry.concentration[context.professionName] = {
        currencyID = currencyID,
        skillLineID = context.skillLineID,
        professionID = context.professionID,
        professionName = context.professionName,
        quantity = tonumber(currencyInfo.quantity) or 0,
        maxQuantity = tonumber(currencyInfo.maxQuantity) or 0,
        rechargingCycleDurationMS = tonumber(currencyInfo.rechargingCycleDurationMS) or 0,
        lastUpdated = GetServerTime(),
    }

    if entry.professions and entry.professions[context.professionName] then
        entry.professions[context.professionName].concentrationCurrencyID = currencyID
        entry.professions[context.professionName].concentration = tonumber(currencyInfo.quantity) or 0
        entry.professions[context.professionName].concentrationMax = tonumber(currencyInfo.maxQuantity) or 0
        entry.professions[context.professionName].concentrationUpdatedAt = GetServerTime()
    end

    if markDirty then
        M:MarkDirty()
        M:Fire("AltDataChanged")
    end

    return characterKey, entry.concentration[context.professionName]
end

function C:GetCharacterProfessionData(characterKey, professionName)
    if not M.Alts or not M.Alts.GetCharacterData then
        return nil
    end
    local data = M.Alts:GetCharacterData(characterKey)
    if not data or type(data.concentration) ~= "table" then
        return nil
    end
    return data.concentration[professionName]
end

function C:GetEstimatedCurrent(data)
    if type(data) ~= "table" then
        return 0
    end

    local amount = tonumber(data.quantity) or 0
    local maxQuantity = tonumber(data.maxQuantity) or 0
    local cycleMS = tonumber(data.rechargingCycleDurationMS) or 0
    local lastUpdated = tonumber(data.lastUpdated) or 0

    if cycleMS <= 0 or maxQuantity <= 0 or lastUpdated <= 0 then
        return math.min(maxQuantity > 0 and maxQuantity or amount, amount)
    end

    local elapsedSeconds = math.max(0, GetServerTime() - lastUpdated)
    local recovered = elapsedSeconds / (cycleMS / 1000)
    return math.min(maxQuantity, amount + recovered)
end

function C:GetSecondsUntilFull(data)
    if type(data) ~= "table" then
        return 0
    end

    local maxQuantity = tonumber(data.maxQuantity) or 0
    local cycleMS = tonumber(data.rechargingCycleDurationMS) or 0
    if maxQuantity <= 0 or cycleMS <= 0 then
        return 0
    end

    local current = self:GetEstimatedCurrent(data)
    if current >= maxQuantity then
        return 0
    end

    local missing = maxQuantity - current
    return math.ceil(missing * (cycleMS / 1000))
end

function C:GetExactFullTime(data)
    local seconds = self:GetSecondsUntilFull(data)
    if seconds <= 0 then
        return date("%Y-%m-%d %H:%M", GetServerTime())
    end
    return date("%Y-%m-%d %H:%M", GetServerTime() + seconds)
end

function C:GetSecondsToTarget(data, target)
    if type(data) ~= "table" then
        return nil
    end
    target = tonumber(target)
    if not target or target <= 0 then
        return nil
    end

    local maxQuantity = tonumber(data.maxQuantity) or 0
    local cycleMS = tonumber(data.rechargingCycleDurationMS) or 0
    if maxQuantity <= 0 or cycleMS <= 0 or target > maxQuantity then
        return nil
    end

    local current = self:GetEstimatedCurrent(data)
    if current >= target then
        return 0
    end

    local missing = target - current
    return math.ceil(missing * (cycleMS / 1000))
end

function C:GetBestTimeToTarget(target, professionFilter)
    if not M.Alts or not M.Alts.GetAllCharacters then
        return nil
    end

    local best
    for _, characterKey in ipairs(M.Alts:GetAllCharacters()) do
        local charData = M.Alts:GetCharacterData(characterKey)
        local concentration = charData and charData.concentration or nil
        if type(concentration) == "table" then
            for professionName, data in pairs(concentration) do
                if not professionFilter or professionFilter == "ALL" or professionFilter == professionName then
                    local seconds = self:GetSecondsToTarget(data, target)
                    if seconds ~= nil then
                        local current = self:GetEstimatedCurrent(data)
                        if not best or seconds < best.seconds then
                            best = {
                                characterKey = characterKey,
                                professionName = professionName,
                                current = current,
                                target = target,
                                seconds = seconds,
                                exact = date("%Y-%m-%d %H:%M", GetServerTime() + seconds),
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

function C:FormatTimer(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

function C:GetBestCurrentCharacterSnapshot()
    if not M.Alts or not M.Alts.GetCharacterData then
        return nil
    end

    local characterKey = M:GetCurrentCharacterKey()
    local data = M.Alts:GetCharacterData(characterKey)
    if not data or type(data.concentration) ~= "table" then
        return nil
    end

    local best
    for professionName, professionData in pairs(data.concentration) do
        local current = self:GetEstimatedCurrent(professionData)
        if not best or current > best.current then
            best = {
                characterKey = characterKey,
                professionName = professionName,
                current = current,
                maxQuantity = tonumber(professionData.maxQuantity) or 0,
                secondsUntilFull = self:GetSecondsUntilFull(professionData),
                exactFullTime = self:GetExactFullTime(professionData),
            }
        end
    end
    return best
end

function C:GetAllRows()
    local rows = {}
    if not M.Alts or not M.Alts.GetAllCharacters then
        return rows
    end

    for _, characterKey in ipairs(M.Alts:GetAllCharacters()) do
        local charData = M.Alts:GetCharacterData(characterKey)
        local concentration = charData and charData.concentration or nil
        if type(concentration) == "table" then
            for professionName, data in pairs(concentration) do
                local current = self:GetEstimatedCurrent(data)
                rows[#rows + 1] = {
                    characterKey = characterKey,
                    professionName = professionName,
                    current = current,
                    maxQuantity = tonumber(data.maxQuantity) or 0,
                    secondsUntilFull = self:GetSecondsUntilFull(data),
                    exactFullTime = self:GetExactFullTime(data),
                    data = data,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.characterKey ~= b.characterKey then
            return a.characterKey < b.characterKey
        end
        return a.professionName < b.professionName
    end)
    return rows
end

function C:BuildTooltipLines(characterKey)
    local lines = {}
    local character = M.Alts and M.Alts:GetCharacterData(characterKey) or nil
    local concentration = character and character.concentration or nil
    if type(concentration) ~= "table" then
        return lines
    end

    local professions = {}
    for professionName in pairs(concentration) do
        professions[#professions + 1] = professionName
    end
    table.sort(professions)

    for _, professionName in ipairs(professions) do
        local data = concentration[professionName]
        local current = safeFloor(self:GetEstimatedCurrent(data))
        local maxQuantity = tonumber(data.maxQuantity) or 0
        local timerText = self:FormatTimer(self:GetSecondsUntilFull(data))
        lines[#lines + 1] = string.format("%s concentration: %d/%d%s", professionName, current, maxQuantity, current < maxQuantity and (" · full in " .. timerText) or " · full")
    end

    return lines
end

function C:CheckFullNotifications()
    local settings = M.settings or {}
    if settings.concentrationNotificationsEnabled == false then
        return
    end
    if not M.Alts or not M.Alts.GetAllCharacters then
        return
    end

    for _, row in ipairs(self:GetAllRows()) do
        local key = row.characterKey .. "::" .. row.professionName
        if (row.current or 0) >= (row.maxQuantity or 0) and (row.maxQuantity or 0) > 0 then
            if not notificationState[key] then
                notificationState[key] = true
                local msg = string.format("%s %s concentration is full.", M:GetShortCharacterName(row.characterKey), row.professionName)
                RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
                if PlaySound then
                    PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
                end
            end
        else
            notificationState[key] = false
        end
    end
end

function C:Init()
    if self._initialized then
        return
    end
    self._initialized = true

    self.timerFrame = CreateFrame("Frame")
    self.timerFrame.elapsed = 0
    self.timerFrame:SetScript("OnUpdate", function(_, elapsed)
        C.timerFrame.elapsed = C.timerFrame.elapsed + elapsed
        if C.timerFrame.elapsed >= 30 then
            C.timerFrame.elapsed = 0
            C:CheckFullNotifications()
        end
    end)
end
