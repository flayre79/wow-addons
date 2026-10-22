local addonName, ns = ...
local O = ns.Odyssey

local Gaps = {}
O.Modules.Gaps = Gaps

local function NormalizePriority(priority)
    priority = string.upper(O:Trim((priority ~= nil and priority ~= "") and priority or "P2"))
    if priority ~= "P0" and priority ~= "P1" and priority ~= "P2" and priority ~= "P3" then
        priority = "P2"
    end
    return priority
end

local function NormalizeStatus(status)
    status = O:Trim((status ~= nil and status ~= "") and status or "Open")
    if status ~= "Open" and status ~= "Done" and status ~= "Deferred" then
        status = "Open"
    end
    return status
end

function Gaps:List()
    return O.db.gaps
end

function Gaps:GetByID(gapID)
    gapID = tonumber(gapID)
    if not gapID then
        return nil
    end

    for _, gap in ipairs(O.db.gaps) do
        if tonumber(gap.id) == gapID then
            return gap
        end
    end
    return nil
end

function Gaps:Add(title, priority, tags, notes)
    title = O:Trim(title)
    if title == "" then
        return nil
    end

    local gapID = tonumber(O.db.nextIDs.gap) or 1
    O.db.nextIDs.gap = gapID + 1

    local gap = {
        id = gapID,
        title = title,
        priority = NormalizePriority(priority),
        status = "Open",
        tags = O:Trim(tags),
        notes = O:Trim(notes),
        createdAt = time(),
        updatedAt = time(),
    }

    O.db.gaps[#O.db.gaps + 1] = gap
    O:MarkDirty()
    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshGapsPanel()
    end
    return gap
end

function Gaps:Update(gapID, fields)
    local gap = self:GetByID(gapID)
    if not gap then
        return nil
    end

    fields = type(fields) == "table" and fields or {}
    if fields.title ~= nil then
        local title = O:Trim(fields.title)
        if title ~= "" then
            gap.title = title
        end
    end
    if fields.priority ~= nil then
        gap.priority = NormalizePriority(fields.priority)
    end
    if fields.status ~= nil then
        gap.status = NormalizeStatus(fields.status)
    end
    if fields.tags ~= nil then
        gap.tags = O:Trim(fields.tags)
    end
    if fields.notes ~= nil then
        gap.notes = O:Trim(fields.notes)
    end

    gap.updatedAt = time()
    O:MarkDirty()
    if O.UI.MainFrame then
        O.UI.MainFrame:RefreshGapsPanel()
    end
    return gap
end

function Gaps:Remove(gapID)
    gapID = tonumber(gapID)
    if not gapID then
        return false
    end

    for index, gap in ipairs(O.db.gaps) do
        if tonumber(gap.id) == gapID then
            table.remove(O.db.gaps, index)
            O:MarkDirty()
            if O.UI.MainFrame then
                O.UI.MainFrame:RefreshGapsPanel()
            end
            return true
        end
    end
    return false
end
