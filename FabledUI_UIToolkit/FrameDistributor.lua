-- FrameDistributor.lua
-- Deferred-iteration primitive ported from CraftSim's GUTIL.FrameDistributor.
-- Source: .sample-addons/CraftSim/Libs/GUTIL/GUTIL.lua (lines 1212-1293).
--
-- Spreads work across frames so heavy iteration does not stall the UI.
-- Consumers can use either CraftSim's call-style (T.FrameDistributor{...})
-- or T.FrameDistributor:CreateNew{...}. Both return an instance with
-- :Continue(), :Break(), :SetIterationTable(), and :Reset().
--
-- Refer to CraftSim's documentation for usage patterns.
--
-- INTENTIONALLY UNCONSUMED (as of 2026-09-05). The toolkit pass quarantined the
-- suite's other zero-consumer modules; this one stays on purpose. It was lifted
-- as the fix for Crafty's single-frame scans (RecipeScan, Profit:GetSortedRows,
-- Cooldowns:Scan) stalling the UI -- see .audit-2026-05-04/_MASTER_SYNTHESIS.md
-- -- and that migration is still open. Do not retire it as dead code without
-- first closing or dropping that work.

local T = FabledUI_UIToolkit
T = T or {}
_G.FabledUI_UIToolkit = T

---------------------------------------------------------------------
-- Internal helpers (stand-ins for GUTIL:Count and Object:extend, so
-- this module is self-contained and does not pull in LibStub deps).
---------------------------------------------------------------------

local function CountTable(t)
    local count = 0
    if type(t) ~= "table" then
        return 0
    end
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

---------------------------------------------------------------------
-- FrameDistributor class
---------------------------------------------------------------------

local FrameDistributor = {}
FrameDistributor.__index = FrameDistributor

---@class FabledUI.FrameDistributor.ConstructorOptions
---@field iterationsPerFrame number? default: 1
---@field maxIterations number?
---@field iterationTable table? if nil iterates til maxIterations or cancelled
---@field continue fun(frameDistributor, key, value, currentIteration, progress) called each iteration; must call :Continue()
---@field cancel? fun(): boolean checked between iterations; truthy stops iteration
---@field finally? fun() invoked on completion or cancel

---@param options FabledUI.FrameDistributor.ConstructorOptions
function FrameDistributor:new(options)
    options = options or {}
    self.iterationsPerFrame = options.iterationsPerFrame or 1
    self.maxIterations = options.maxIterations

    self.iterationTable = options.iterationTable
    self:Reset()
    self.continue = options.continue or function() end
    self.cancel = options.cancel or function() return false end
    self.finally = options.finally or function() end
end

function FrameDistributor:Continue()
    self.currentIteration = self.currentIteration + 1

    if self.maxIterations then
        if self.currentIteration >= self.maxIterations then
            self.finally()
            return
        end
    end

    local runInFrame = self.iterationsPerFrame <= 0 or (mod(self.currentIteration, self.iterationsPerFrame) > 0)

    if self.cancel() then
        self.finally()
        return
    end
    local key, value
    if self.iterationTable then
        key, value = next(self.iterationTable, self.currentIterationKey)
        self.currentIterationKey = key
    end

    local currentProgress = self.currentIteration / self.iterationProgressStep

    if self.iterationTable and not key then
        self.finally()
        return
    end

    if runInFrame then
        self.continue(self, key, value, self.currentIteration, currentProgress)
    else
        RunNextFrame(function()
            self.continue(self, key, value, self.currentIteration, currentProgress)
        end)
    end
end

--- Stops iteration and calls finally callback
function FrameDistributor:Break()
    self.finally()
end

---@param newTable table
function FrameDistributor:SetIterationTable(newTable)
    self.iterationTable = newTable
    self:Reset()
end

function FrameDistributor:Reset()
    self.tableSize = CountTable(self.iterationTable or {})
    if self.iterationTable then
        self.iterationProgressStep = (self.tableSize / 100)
        if self.iterationProgressStep <= 0 then
            self.iterationProgressStep = 1
        end
    else
        self.iterationProgressStep = 1
    end
    self.currentIterationKey = nil
    self.breakActive = false
    self.currentIteration = 0
end

---------------------------------------------------------------------
-- Public factory exposed on T (FabledUI_UIToolkit)
---------------------------------------------------------------------

local function NewInstance(options)
    local instance = setmetatable({}, FrameDistributor)
    instance:new(options)
    return instance
end

-- Class table is callable to mimic CraftSim's GUTIL.FrameDistributor{...} syntax
local FrameDistributorClass = setmetatable({}, {
    __call = function(_, options)
        return NewInstance(options)
    end,
    __index = FrameDistributor,
})

--- Convenience constructor: T.FrameDistributor:CreateNew{...}
---@param options FabledUI.FrameDistributor.ConstructorOptions
---@return table instance
function FrameDistributorClass:CreateNew(options)
    return NewInstance(options)
end

T.FrameDistributor = FrameDistributorClass
