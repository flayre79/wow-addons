-- ============================================================================
-- FabledUI_Crafty - GuildCrafters (P1-A6) -- FULLY IMPLEMENTED
-- Donor: VamoosesGuildCraft/Modules/GuildQuery.lua (257 lines, ported).
--
-- Wraps C_GuildInfo to query which guild members can craft a recipe and
-- maintains a roster cache (online/class/zone, plus profession enrichment
-- via C_Club.GetMemberInfo).
--
-- Public API:
--   M.GuildCrafters:RefreshRoster()                          -- rebuild cache
--   M.GuildCrafters:EnrichFromClub(members)                  -- profession data
--   M.GuildCrafters:QueryRecipe(skillLineID, recipeSpellID, recipeLevel)
--   M.GuildCrafters:OnRecipeKnownByMembers()                 -- event handler
--   M.GuildCrafters:GetCrafters(recipeID)                    -- last result
--   M.GuildCrafters:GetOnlineMembers()                       -- view
--   M.GuildCrafters:GetRosterEntry(name)                     -- single lookup
--   M.GuildCrafters:ClearCache()
--
-- Fires (via M:Fire):
--   "GuildCraftersUpdated" -> { recipeID, crafters, dataHole? }
--   "GuildRosterUpdated"
-- ============================================================================

local M = _G.FabledUI_Crafty
if not M then return end

M.GuildCrafters = M.GuildCrafters or {}
local GC = M.GuildCrafters

GC.roster           = GC.roster or {}            -- [name-server] -> entry
GC.craftersByRecipe = GC.craftersByRecipe or {}  -- [recipeSpellID] -> { crafter, ... }
GC.pendingRecipeID  = nil
GC.rosterDebounce   = nil

local ROSTER_DEBOUNCE = 0.5
local QUERY_TIMEOUT   = 3
local MAX_CACHED_RECIPES = 20

-- ---------------------------------------------------------------------------
-- Roster cache
-- ---------------------------------------------------------------------------

function GC:DebouncedRosterRefresh()
    if self.rosterDebounce and self.rosterDebounce.Cancel then
        self.rosterDebounce:Cancel()
    end
    self.rosterDebounce = C_Timer.NewTimer(ROSTER_DEBOUNCE, function()
        self:RefreshRoster()
    end)
end

function GC:RefreshRoster()
    local numTotal = GetNumGuildMembers and GetNumGuildMembers() or 0
    if not numTotal or numTotal == 0 then return end

    local newRoster = {}
    for i = 1, numTotal do
        local name, rankName, rankIndex, level, classDisplayName, zone,
              note, officerNote, online, status, classFile, achievePoints,
              achieveRank, isMobile, isSoR, repStanding, guid = GetGuildRosterInfo(i)
        if name then
            newRoster[name] = {
                guid       = guid,
                class      = classDisplayName,
                classFile  = classFile,
                online     = online,
                zone       = zone or "",
                rank       = rankName,
                rankIndex  = rankIndex,
                level      = level,
                isMobile   = isMobile,
            }
        end
    end

    self:EnrichFromClub(newRoster)

    self.roster = newRoster
    if M.Fire then M:Fire("GuildRosterUpdated") end
end

-- ---------------------------------------------------------------------------
-- C_Club enrichment (profession data lives on club member info, not roster)
-- ---------------------------------------------------------------------------

function GC:EnrichFromClub(members)
    if not C_Club or not C_Club.GetSubscribedClubs then return end
    local clubs = C_Club.GetSubscribedClubs()
    if not clubs then return end

    -- O(1) lookup indexes: full name and short name -> member entry.
    local byFull, byShort = {}, {}
    for rosterName, entry in pairs(members) do
        byFull[rosterName] = entry
        local short = rosterName:match("^([^-]+)")
        if short then byShort[short] = entry end
    end

    for _, clubInfo in ipairs(clubs) do
        if clubInfo.clubType == Enum.ClubType.Guild then
            pcall(function()
                local clubMembers = C_Club.GetClubMembers(clubInfo.clubId)
                if not clubMembers then return end
                for _, memberId in ipairs(clubMembers) do
                    local info = C_Club.GetMemberInfo(clubInfo.clubId, memberId)
                    if info and info.name then
                        local matched = byFull[info.name] or byShort[info.name]
                        if matched then
                            matched.prof1Name = info.profession1Name or ""
                            matched.prof1ID   = info.profession1ID   or 0
                            matched.prof1Rank = info.profession1Rank or 0
                            matched.prof2Name = info.profession2Name or ""
                            matched.prof2ID   = info.profession2ID   or 0
                            matched.prof2Rank = info.profession2Rank or 0
                            matched.presence  = info.presence
                        end
                    end
                end
            end)
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

function GC:GetOnlineMembers()
    local online = {}
    for name, data in pairs(self.roster) do
        if data.online then
            online[#online + 1] = {
                name      = name,
                classFile = data.classFile or "WARRIOR",
                online    = true,
                zone      = data.zone or "",
                rank      = data.rank or "",
                level     = data.level or 0,
                prof1Name = data.prof1Name or "",
                prof2Name = data.prof2Name or "",
            }
        end
    end
    table.sort(online, function(a, b) return a.name < b.name end)
    return online
end

function GC:GetRosterEntry(name)
    return self.roster[name]
end

-- ---------------------------------------------------------------------------
-- Recipe query
-- ---------------------------------------------------------------------------

function GC:QueryRecipe(skillLineID, recipeSpellID, recipeLevel)
    if not IsInGuild or not IsInGuild() then return end
    if not skillLineID or not recipeSpellID then return end
    if not C_GuildInfo or not C_GuildInfo.QueryGuildMembersForRecipe then return end

    self.pendingRecipeID = recipeSpellID

    local ok = pcall(C_GuildInfo.QueryGuildMembersForRecipe, skillLineID, recipeSpellID, recipeLevel or 1)
    if not ok then
        self.pendingRecipeID = nil
        if M.Fire then
            M:Fire("GuildCraftersUpdated", {
                recipeID = recipeSpellID,
                crafters = {},
                dataHole = true,
            })
        end
        return
    end

    -- 3s timeout: GUILD_RECIPE_KNOWN_BY_MEMBERS may never fire if the recipe
    -- isn't in Blizzard's tracked-recipe set. We surface that as dataHole=true
    -- so the UI can show a clear "no data" state instead of a spinner.
    C_Timer.After(QUERY_TIMEOUT, function()
        if self.pendingRecipeID == recipeSpellID then
            self.pendingRecipeID = nil
            if M.Fire then
                M:Fire("GuildCraftersUpdated", {
                    recipeID = recipeSpellID,
                    crafters = {},
                    dataHole = true,
                })
            end
        end
    end)
end

function GC:OnRecipeKnownByMembers()
    if not GetGuildRecipeInfoPostQuery then
        if M.Fire then
            M:Fire("GuildCraftersUpdated", { recipeID = self.pendingRecipeID, crafters = {} })
        end
        return
    end

    local _skillLine, recipeID, numMembers = GetGuildRecipeInfoPostQuery()
    if not recipeID then return end

    -- Ignore results not initiated by us (e.g. another addon's scan).
    if self.pendingRecipeID and recipeID ~= self.pendingRecipeID then return end
    self.pendingRecipeID = nil

    local crafters = {}
    if numMembers and numMembers > 0 and GetGuildRecipeMember then
        for i = 1, numMembers do
            local displayName, fullName, classFileName, online = GetGuildRecipeMember(i)
            local rosterEntry = fullName and self.roster[fullName]
            crafters[#crafters + 1] = {
                name        = fullName or displayName or "?",
                displayName = displayName or "?",
                classFile   = classFileName or "WARRIOR",
                online      = online or false,
                zone        = rosterEntry and rosterEntry.zone or "",
                rank        = rosterEntry and rosterEntry.rank or "",
                skillRank   = rosterEntry and (rosterEntry.prof1Rank or rosterEntry.prof2Rank) or 0,
                presence    = rosterEntry and rosterEntry.presence or nil,
            }
        end
    end

    table.sort(crafters, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)

    -- Cap cache to prevent unbounded growth over a long session.
    local cacheCount = 0
    for _ in pairs(self.craftersByRecipe) do cacheCount = cacheCount + 1 end
    if cacheCount >= MAX_CACHED_RECIPES then
        for k in pairs(self.craftersByRecipe) do
            self.craftersByRecipe[k] = nil
            break
        end
    end

    self.craftersByRecipe[recipeID] = crafters
    if M.Fire then
        M:Fire("GuildCraftersUpdated", { recipeID = recipeID, crafters = crafters })
    end
end

function GC:GetCrafters(recipeID)
    return self.craftersByRecipe[recipeID]
end

function GC:ClearCache()
    self.craftersByRecipe = {}
    self.pendingRecipeID = nil
end

-- ---------------------------------------------------------------------------
-- Event wiring
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("GUILD_RECIPE_KNOWN_BY_MEMBERS")
frame:RegisterEvent("GUILD_TRADESKILL_UPDATE")
local _gcErrCount = 0
frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(function(...)
        if event == "PLAYER_LOGIN" then
            if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
                C_GuildInfo.GuildRoster()
            end
        elseif event == "GUILD_ROSTER_UPDATE" then
            GC:DebouncedRosterRefresh()
        elseif event == "GUILD_RECIPE_KNOWN_BY_MEMBERS" then
            GC:OnRecipeKnownByMembers()
        elseif event == "GUILD_TRADESKILL_UPDATE" then
            -- Guild tradeskill snapshots refreshed; no-op for now, hook here later.
        end
    end, ...)
    if not ok then
        _gcErrCount = _gcErrCount + 1
        if _gcErrCount <= 3 then
            print("|cffff5555[Crafty.GuildCrafters]|r " .. tostring(err))
        end
    end
end)
