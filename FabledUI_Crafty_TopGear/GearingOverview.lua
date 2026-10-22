local M = _G.FabledUI_Crafty
M.GearingOverview = M.GearingOverview or {}
local G = M.GearingOverview

function G:GetRows()
    local rows = {}
    for _, characterKey in ipairs((M.Alts and M.Alts.GetAllCharacters and M.Alts:GetAllCharacters()) or {}) do
        local char = M.Alts:GetCharacterData(characterKey) or {}
        for professionName, profData in pairs(char.professions or {}) do
            local hasGear = type(profData.gear) == 'table'
            local hasSpec = type(profData.specialization) == 'table'
            if hasGear or hasSpec then
                rows[#rows + 1] = {
                    characterKey = characterKey,
                    professionName = professionName,
                    gearText = hasGear and M.Gear:DescribeTotals(profData.gear.totals) or 'No profession gear snapshot',
                    specText = hasSpec and M.Specs:GetSummaryText(profData.specialization) or 'No specialization snapshot',
                    tooltip = hasGear and M.Gear:GetTooltipLines(characterKey, professionName) or {'No profession gear snapshot.'},
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.characterKey ~= b.characterKey then
            return a.characterKey < b.characterKey
        end
        return (a.professionName or '') < (b.professionName or '')
    end)
    return rows
end

function G:GetSystemRows()
    return {
        {
            title = 'Upgrade track overlays',
            detail = (M.settings and M.settings.upgradeIconsOnContainers) and 'Tooltip + inventory overlays active.' or 'Tooltip overlays active. Inventory overlays optional.',
            status = (M.settings and M.settings.upgradeIconsOnTooltip ~= false) and 'Enabled' or 'Disabled',
        },
        {
            title = 'Token mapping',
            detail = (M.settings and M.settings.tokenTooltipOnlyForEligible) and 'Only showing token families that match the player class.' or 'Showing full token family detail on supported items.',
            status = (M.settings and M.settings.tokenTooltipDetailsEnabled ~= false) and 'Enabled' or 'Disabled',
        },
        {
            title = 'Profit stat inputs',
            detail = ((M.settings and M.settings.useCraftSimProfitModel) and 'CraftSim-like' or 'Crafty') .. ' profit engine using profession gear stats when available.',
            status = 'Linked',
        },
    }
end
