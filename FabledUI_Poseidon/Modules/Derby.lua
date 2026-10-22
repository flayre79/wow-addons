local P = _G.FabledUI_Poseidon
if not P then return end

P.Derby = P.Derby or {}
local D = P.Derby

function D:Init()
    self.catches = self.catches or {}
end

-- 12.1: AuraUtil.FindAuraByName is a FrameXML helper built on slot iteration, so
-- it raises a Lua error while auras are secret even though it takes a name.
-- There is no spell ID for the derby buff in P.Data (only the name), so the
-- lookup stays, wrapped: an error degrades to "derby not active" instead of
-- breaking the caller. If this matters more later, add the spell ID to
-- P.Data and switch to C_UnitAuras.GetPlayerAuraBySpellID as BuffTracker does.
function D:IsActive()
    if not AuraUtil or not AuraUtil.FindAuraByName then
        return false
    end
    local buffName = (P.Data and P.Data.DERBY_BUFF) or "Derby Dasher"
    local ok, found = pcall(AuraUtil.FindAuraByName, buffName, "player", "HELPFUL")
    return ok and found ~= nil
end

function D:RecordCatch(fishName)
    if type(fishName) ~= "string" or fishName == "" then
        return
    end
    self.catches = self.catches or {}
    self.catches[fishName] = (self.catches[fishName] or 0) + 1
end

function D:GetTopCatches(limit)
    local out = {}
    for fishName, count in pairs(self.catches or {}) do
        out[#out + 1] = { name = fishName, count = count }
    end
    table.sort(out, function(a, b)
        if a.count == b.count then
            return a.name < b.name
        end
        return a.count > b.count
    end)
    if limit and #out > limit then
        while #out > limit do
            table.remove(out)
        end
    end
    return out
end
