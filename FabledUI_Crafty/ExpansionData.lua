-- ============================================================================
-- FabledUI_Crafty - ExpansionData
-- Canonical expansion enum, name tables, brand colors, and string-normalization
-- helpers shared across the addon. Sourced from:
--   * ItemEra/Utils.lua (ExpansionDictionary, ExpansionNames, ExpansionNamesShort,
--     ExpansionColorsHex)            -- P1-3 (audit 2026-05-04, Group 2)
--   * CCM/CCM.lua (EXPANSION_ALIAS, EXPANSION_ID_MAP)
--                                    -- P1-A13 (audit 2026-05-04, Group 6)
--
-- Notes:
--   * The 'WoTLK' shorthand from ItemEra is renamed to 'WotLK' to match Crafty's
--     existing M.EXPANSION_ORDER ("Classic","TBC","WotLK","Cataclysm",...).
--   * Lookups are intentionally exposed on M.Expansion so this module can be
--     consumed without leaking globals.
-- ============================================================================

local M = _G.FabledUI_Crafty
if not M then return end

M.Expansion = M.Expansion or {}
local E = M.Expansion

-- ---------------------------------------------------------------------------
-- Canonical 0..11 enum (verbatim from ItemEra)
-- ---------------------------------------------------------------------------
E.ExpansionDictionary = {
    CLASSIC = 0,
    TBC     = 1,
    WOTLK   = 2,
    CATA    = 3,
    MOP     = 4,
    WOD     = 5,
    LEGION  = 6,
    BFA     = 7,
    SHADOW  = 8,
    DF      = 9,
    TWW     = 10,
    MN      = 11,
}

local D = E.ExpansionDictionary

-- ---------------------------------------------------------------------------
-- Full names (verbatim from ItemEra)
-- ---------------------------------------------------------------------------
E.ExpansionNames = {
    [D.CLASSIC] = "Classic",
    [D.TBC]     = "The Burning Crusade",
    [D.WOTLK]   = "Wrath of the Lich King",
    [D.CATA]    = "Cataclysm",
    [D.MOP]     = "Mists of Pandaria",
    [D.WOD]     = "Warlords of Draenor",
    [D.LEGION]  = "Legion",
    [D.BFA]     = "Battle for Azeroth",
    [D.SHADOW]  = "Shadowlands",
    [D.DF]      = "Dragonflight",
    [D.TWW]     = "The War Within",
    [D.MN]      = "Midnight",
}

-- ---------------------------------------------------------------------------
-- Short names (note: 'WoTLK' renamed to 'WotLK' to match Crafty conventions)
-- ---------------------------------------------------------------------------
E.ExpansionNamesShort = {
    [D.CLASSIC] = "Classic",
    [D.TBC]     = "TBC",
    [D.WOTLK]   = "WotLK",  -- renamed from 'WoTLK' (ItemEra) to match EXPANSION_ORDER
    [D.CATA]    = "Cata",
    [D.MOP]     = "MoP",
    [D.WOD]     = "WoD",
    [D.LEGION]  = "Legion",
    [D.BFA]     = "BFA",
    [D.SHADOW]  = "SL",
    [D.DF]      = "DF",
    [D.TWW]     = "TWW",
    [D.MN]      = "Midnight",
}

-- ---------------------------------------------------------------------------
-- Per-expansion brand color (verbatim from ItemEra)
-- ---------------------------------------------------------------------------
E.ExpansionColorsHex = {
    [D.CLASSIC] = "#F4BF2A",
    [D.TBC]     = "#CBD86C",
    [D.WOTLK]   = "#9DC6E5",
    [D.CATA]    = "#8E3C14",
    [D.MOP]     = "#5FB177",
    [D.WOD]     = "#D77500",
    [D.LEGION]  = "#D9E342",
    [D.BFA]     = "#C4C6C5",
    [D.SHADOW]  = "#F9F8F6",
    [D.DF]      = "#B6B6BA",
    [D.TWW]     = "#EA551F",
    [D.MN]      = "#5C1FEA",
}

-- ---------------------------------------------------------------------------
-- CCM: lowercase substring -> canonical full name (P1-A13)
-- Source: CCM/CCM.lua:80-100
-- ---------------------------------------------------------------------------
E.EXPANSION_ALIAS = {
    ["classic"]                 = "Classic",
    ["the burning crusade"]     = "The Burning Crusade",
    ["burning crusade"]         = "The Burning Crusade",
    ["wrath of the lich king"]  = "Wrath of the Lich King",
    ["cataclysm"]               = "Cataclysm",
    ["mists of pandaria"]       = "Mists of Pandaria",
    ["warlords of draenor"]     = "Warlords of Draenor",
    ["legion"]                  = "Legion",
    ["battle for azeroth"]      = "Battle for Azeroth",
    ["shadowlands"]             = "Shadowlands",
    ["dragonflight"]            = "Dragonflight",
    ["the war within"]          = "The War Within",
    ["war within"]              = "The War Within",
    ["tww"]                     = "The War Within",
    ["khaz algar"]              = "The War Within",
    ["khaz'algar"]              = "The War Within",
    ["midnight"]                = "Midnight",
    ["wotlk"]                   = "Wrath of the Lich King",
    ["bfa"]                     = "Battle for Azeroth",
}

-- ---------------------------------------------------------------------------
-- Numeric fallback (donor packets sometimes ship the enum) (P1-A13)
-- Source: CCM/CCM.lua:102-115
-- ---------------------------------------------------------------------------
E.EXPANSION_ID_MAP = {
    [0]  = "Classic",
    [1]  = "The Burning Crusade",
    [2]  = "Wrath of the Lich King",
    [3]  = "Cataclysm",
    [4]  = "Mists of Pandaria",
    [5]  = "Warlords of Draenor",
    [6]  = "Legion",
    [7]  = "Battle for Azeroth",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
}

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

function M:GetExpansionShortNameByID(expansionID)
    if expansionID == nil then return nil end
    return E.ExpansionNamesShort[expansionID]
end

function M:GetExpansionFullNameByID(expansionID)
    if expansionID == nil then return nil end
    return E.ExpansionNames[expansionID]
end

-- The 15th return of C_Item.GetItemInfo is the expansion enum (matches the
-- canonical 0..11 numbering above). Fall back to nil if the item isn't cached.
function M:GetExpansionByItemID(itemID)
    if not itemID or not C_Item or not C_Item.GetItemInfo then
        return nil
    end
    local expansionID = select(15, C_Item.GetItemInfo(itemID))
    if not expansionID then return nil end
    return expansionID, E.ExpansionNames[expansionID], E.ExpansionNamesShort[expansionID]
end

-- Map a free-form donor string (recipe text, item subtitle, scanner label) to
-- a canonical full expansion name. Lowercases and tries a substring match
-- against EXPANSION_ALIAS. Returns nil if no entry hits.
function M:NormalizeExpansionFromString(label)
    if type(label) == "number" then
        return E.EXPANSION_ID_MAP[label]
    end
    if type(label) ~= "string" or label == "" then
        return nil
    end
    local needle = label:lower()
    -- Direct hit first (cheapest path).
    local exact = E.EXPANSION_ALIAS[needle]
    if exact then return exact end
    -- Substring scan: matches "Khaz'Algar Alchemy", "TWW Reagent Bag", etc.
    for alias, canonical in pairs(E.EXPANSION_ALIAS) do
        if needle:find(alias, 1, true) then
            return canonical
        end
    end
    return nil
end

-- Convenience: hex color -> ColorMixin-friendly r,g,b (0..1).
function M:GetExpansionColor(expansionID)
    local hex = E.ExpansionColorsHex[expansionID]
    if not hex then return nil end
    local r = tonumber(hex:sub(2, 3), 16) or 255
    local g = tonumber(hex:sub(4, 5), 16) or 255
    local b = tonumber(hex:sub(6, 7), 16) or 255
    return r / 255, g / 255, b / 255, hex
end
