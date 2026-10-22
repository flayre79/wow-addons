-- EndeavorsData.lua
-- Provider: Villa.CodexData.Endeavors
--
-- THERE IS NO STATIC ENDEAVORS DATASET, AND THERE IS NOT GOING TO BE ONE.
--
-- This file used to declare three empty tables -- houseLevels, initiatives,
-- tasks -- under `__source = "framework"` and a header promising a "pending
-- offline pipeline import ... handled by a separate sprint
-- (tools/data-pipeline/sources/villa-housing-importer.py)". Both halves of that
-- were false: nothing read the tables, and that importer has never contained
-- the word "Endeavors". It was a file waiting forever for a job nobody had
-- scheduled -- the "framework file that ships with an empty table" CLAUDE.md
-- says to call out loudly rather than leave sitting there looking plausible.
--
-- The 2026-08-14 donor review went looking for something to fill it with and
-- found that no donor has one either:
--
--   * VamoosesEndeavors 1.6.9 is 10,229 lines and carries zero static endeavor
--     data. It drives entirely off C_NeighborhoodInitiative (14 distinct
--     functions) and C_Housing, and derives per-task house XP by *learning it
--     from the activity log* rather than tabulating it.
--   * HousingCodex's EndeavorsData is likewise a runtime state machine over the
--     same APIs.
--
-- That is not an oversight upstream. Initiative cycles rotate server-side and
-- their task lists come down in the payload, so a static table would be stale
-- the week it was written.
--
-- What this file is instead
-- -------------------------
-- The single definition of the runtime state shape that Villa_Endeavors.lua
-- fills in from the live APIs. That shape used to be written out twice, once
-- here as documentation and once there as the real thing, which is how a
-- contract quietly drifts. Villa_Endeavors.lua now builds its state from
-- NewEndeavorState() below, so there is one copy.

local Providers = _G.FabledUI_DataVault_VillaProviders or {}
_G.FabledUI_DataVault_VillaProviders = Providers

local function _CurrentVilla()
    return _G.FabledUI_Villa or {}
end

local Villa = setmetatable({}, {
    __index = function(_, key)
        local current = _CurrentVilla()
        local value = current[key]
        if value ~= nil then
            return value
        end
        if key == "RegisterModule" or key == "RegisterEngine" then
            return function() end
        end
        return nil
    end,
    __newindex = function(_, key, value)
        local current = _G.FabledUI_Villa
        if current then
            current[key] = value
        end
    end,
})

local CodexData = Providers["codex"] or {}
Providers["codex"] = CodexData
Villa.CodexData = Villa.CodexData or CodexData

local Endeavors = CodexData.Endeavors or {
    __source  = "runtime",
    __version = "2026-08-14-runtime-only",
    __notes   = "No static dataset exists upstream; state is rebuilt from " ..
                "C_Housing and C_NeighborhoodInitiative each session. This " ..
                "provider defines the state shape, not the data.",
}

-- Every field Villa_Endeavors.lua maintains, with the value it holds before the
-- live APIs have answered. Consumers reading state before the first
-- PLAYER_HOUSE_LIST_UPDATED get these, so they are all non-nil where a nil
-- would force a guard at every call site.
--
-- Returned fresh each call rather than as a shared table: the caller mutates
-- what it gets back, and handing out one shared default would make every
-- consumer alias the same state.
function CodexData:NewEndeavorState()
    return {
        -- Where the player is
        isInNeighborhood      = false,
        hasHouse              = false,
        houseGUID             = nil,

        -- House level and favor (C_Housing)
        houseLevel            = 0,
        houseFavor            = 0,   -- favor toward the next level
        houseFavorNeeded      = 0,
        houseFavorTotal       = 0,   -- cumulative, for display
        houseFavorTotalNeeded = 0,
        maxHouseLevel         = 0,
        isMaxLevel            = false,

        -- Current initiative (C_NeighborhoodInitiative)
        initiativeInfo        = nil,   -- live payload, as returned
        taskSnapshots         = {},    -- [taskID] = { current, max }
        sessionProgress       = {},    -- [taskID] = { taskName, current, max,
                                       --              delta, lastChangedTime, completed }
        lastNeighborhoodGUID  = nil,
        lastCycleID           = nil,
        initiativeDataFresh   = false,
    }
end

-- Field names only, so a test can assert the two files have not drifted apart
-- without hardcoding the list a second time.
function CodexData:GetEndeavorStateFields()
    local fields = {}
    for key in pairs(self:NewEndeavorState()) do
        fields[#fields + 1] = key
    end
    table.sort(fields)
    return fields
end

CodexData.Endeavors = Endeavors

if Villa.RegisterModule and type(Villa.RegisterModule) == "function" then
    Villa:RegisterModule("CodexData.Endeavors", Endeavors)
end
