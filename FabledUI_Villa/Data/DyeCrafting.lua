-- DyeCrafting.lua
-- Provider: Villa.Data.DyeCrafting
--
-- Source: VamoosesDyeStudio - Data/VDS_DyeCraftingDB.lua (310 LOC)
-- See: .sample-addons/VamoosesDyeStudio/Data/VDS_DyeCraftingDB.lua
--
-- Full bulk import from VamoosesDyeStudio. All 10 pigment chains across 12
-- expansions (Classic→Midnight) plus the dye→pigment recipe lookup.
--
-- ============================================================================
-- SCHEMA DOCUMENTATION
-- ============================================================================
-- Each pigment requires 10 of any one listed herb -> produces 1 pigment ->
-- 1 dye. Professions involved: Midnight Alchemy or Midnight Inscription.
--
-- DyeCrafting = {
--     pigments = {
--         [pigmentItemID] = {
--             name      = string,             -- display name
--             category  = string,             -- color bucket ("Black", "Blue", ...)
--             herbQty   = number,             -- always 10 in current source
--             herbs = {
--                 [expansionKey] = { herbItemID, ... }, -- one or more herbs per expansion
--             },
--         },
--         ...
--     },
-- }
--
-- expansionKey is a stable string the importer attaches per herb (e.g.
-- "Classic", "BC", "Wrath", "Cata", "MoP", "WoD", "Legion", "BfA",
-- "Shadowlands", "Dragonflight", "TWW", "Midnight"). The original VDS file
-- stored herbs as a flat array with inline expansion comments; the Villa
-- import upgrades that to the keyed shape so callers can prompt
-- "what herb works here in expansion X" without scanning a list.
-- ============================================================================

local Villa = _G.FabledUI_Villa
if not Villa then return end
Villa.Data = Villa.Data or {}

Villa.Data.DyeCrafting = {
    __source  = "vamoosesdyestudio",
    __version = "2026-05-04-vamoosesdyestudio-full",
    __notes   = "Full pigment + dye-recipe import from VamoosesDyeStudio. " ..
                "See .sample-addons/VamoosesDyeStudio/Data/VDS_DyeCraftingDB.lua.",

    pigments = {
        [262639] = {
            name = "Black Dye Pigment", category = "Black", herbQty = 10,
            herbs = {
                Classic     = { 3818   }, -- Fadeleaf
                BC          = { 22785  }, -- Felweed
                Wrath       = { 36905  }, -- Lichbloom
                Cata        = { 52985  }, -- Azshara's Veil
                MoP         = { 89639  }, -- Desecrated Herb
                WoD         = { 109128 }, -- Nagrand Arrowbloom
                Legion      = { 128304 }, -- Yseralline Seed
                BfA         = { 152505 }, -- Riverbud
                Shadowlands = { 169701 }, -- Death Blossom
                Dragonflight= { 191470 }, -- Writhebark
                TWW         = { 210805 }, -- Blessing Blossom
                Midnight    = { 236774 }, -- Azeroot
            },
        },
        [262643] = {
            name = "Blue Dye Pigment", category = "Blue", herbQty = 10,
            herbs = {
                Classic     = { 765    }, -- Silverleaf
                BC          = { 22789  }, -- Terocone
                Wrath       = { 36906  }, -- Icethorn
                Cata        = { 52984  }, -- Stormvine
                MoP         = { 72235  }, -- Silkweed
                WoD         = { 109124 }, -- Frostweed
                Legion      = { 124102 }, -- Dreamleaf
                BfA         = { 152507 }, -- Akunda's Bite
                Shadowlands = { 169701 }, -- Death Blossom
                Dragonflight= { 191467 }, -- Bubble Poppy
                TWW         = { 210799 }, -- Luredrop
                Midnight    = { 236776 }, -- Argentleaf
            },
        },
        [262642] = {
            name = "Brown Dye Pigment", category = "Brown", herbQty = 10,
            herbs = {
                Classic     = { 2450   }, -- Briarthorn
                BC          = { 22786  }, -- Dreaming Glory
                Wrath       = { 36903  }, -- Adder's Tongue
                Cata        = { 52983  }, -- Cinderbloom
                MoP         = { 89639  }, -- Desecrated Herb
                WoD         = { 109126 }, -- Gorgrond Flytrap
                Legion      = { 124103 }, -- Foxflower
                BfA         = { 152511 }, -- Sea Stalk
                Shadowlands = { 168589 }, -- Marrowroot
                Dragonflight= { 191470 }, -- Writhebark
                TWW         = { 210796 }, -- Mycobloom
                Midnight    = { 236774 }, -- Azeroot
            },
        },
        [262647] = {
            name = "Green Dye Pigment", category = "Green", herbQty = 10,
            herbs = {
                Classic     = { 2452   }, -- Swiftthistle
                BC          = { 22785  }, -- Felweed
                Wrath       = { 36903  }, -- Adder's Tongue
                Cata        = { 52985  }, -- Azshara's Veil
                MoP         = { 72234  }, -- Green Tea Leaf
                WoD         = { 109128 }, -- Nagrand Arrowbloom
                Legion      = { 124102 }, -- Dreamleaf
                BfA         = { 152505 }, -- Riverbud
                Shadowlands = { 170554 }, -- Vigil's Torch
                Dragonflight= { 191467 }, -- Bubble Poppy
                TWW         = { 210805 }, -- Blessing Blossom
                Midnight    = { 236770 }, -- Sanguithorn
            },
        },
        [262656] = {
            name = "Orange Dye Pigment", category = "Orange", herbQty = 10,
            herbs = {
                Classic     = { 13464  }, -- Golden Sansam
                BC          = { 22792  }, -- Nightmare Vine
                Wrath       = { 36901  }, -- Goldclover
                Cata        = { 52986  }, -- Heartblossom
                MoP         = { 72237  }, -- Rain Poppy
                WoD         = { 109125 }, -- Fireweed
                Legion      = { 124103 }, -- Foxflower
                BfA         = { 152509 }, -- Siren's Pollen
                Shadowlands = { 168583 }, -- Widowbloom
                Dragonflight= { 191470 }, -- Writhebark
                TWW         = { 210799 }, -- Luredrop
                Midnight    = { 236770 }, -- Sanguithorn
            },
        },
        [262625] = {
            name = "Purple Dye Pigment", category = "Purple", herbQty = 10,
            herbs = {
                Classic     = { 3356   }, -- Kingsblood
                BC          = { 22793  }, -- Mana Thistle
                Wrath       = { 36907  }, -- Talandra's Rose
                Cata        = { 52987  }, -- Twilight Jasmine
                MoP         = { 79011  }, -- Fool's Cap
                WoD         = { 109129 }, -- Talador Orchid
                Legion      = { 124101 }, -- Aethril
                BfA         = { 168487 }, -- Zin'anthid
                Shadowlands = { 170554 }, -- Vigil's Torch
                Dragonflight= { 191460 }, -- Hochenblume
                TWW         = { 210802 }, -- Orbinid
                Midnight    = { 236776 }, -- Argentleaf
            },
        },
        [262655] = {
            name = "Red Dye Pigment", category = "Red", herbQty = 10,
            herbs = {
                Classic     = { 785    }, -- Mageroyal
                BC          = { 22791  }, -- Netherbloom
                Wrath       = { 36904  }, -- Tiger Lily
                Cata        = { 52983  }, -- Cinderbloom
                MoP         = { 72237  }, -- Rain Poppy
                WoD         = { 109125 }, -- Fireweed
                Legion      = { 151565 }, -- Astral Glory
                BfA         = { 152506 }, -- Star Moss
                Shadowlands = { 168583 }, -- Widowbloom
                Dragonflight= { 191464 }, -- Saxifrage
                TWW         = { 210808 }, -- Arathor's Spear
                Midnight    = { 236778 }, -- Mana Lily
            },
        },
        [262628] = {
            name = "Teal Dye Pigment", category = "Teal", herbQty = 10,
            herbs = {
                Classic     = { 2453   }, -- Bruiseweed
                BC          = { 22789  }, -- Terocone
                Wrath       = { 36905  }, -- Lichbloom
                Cata        = { 52984  }, -- Stormvine
                MoP         = { 72235  }, -- Silkweed
                WoD         = { 109127 }, -- Starflower
                Legion      = { 128304 }, -- Yseralline Seed
                BfA         = { 152509 }, -- Siren's Pollen
                Shadowlands = { 168589 }, -- Marrowroot
                Dragonflight= { 191460 }, -- Hochenblume
                TWW         = { 210802 }, -- Orbinid
                Midnight    = { 236761 }, -- Tranquility Bloom
            },
        },
        [260947] = {
            name = "White Dye Pigment", category = "White", herbQty = 10,
            herbs = {
                Classic     = { 2447   }, -- Peacebloom
                BC          = { 22787  }, -- Ragveil
                Wrath       = { 36906  }, -- Icethorn
                Cata        = { 52988  }, -- Whiptail
                MoP         = { 79010  }, -- Snow Lily
                WoD         = { 109129 }, -- Talador Orchid
                Legion      = { 124104 }, -- Fjarnskaggl
                BfA         = { 152508 }, -- Winter's Kiss
                Shadowlands = { 168586 }, -- Rising Glory
                Dragonflight= { 191464 }, -- Saxifrage
                TWW         = { 210796 }, -- Mycobloom
                Midnight    = { 236761 }, -- Tranquility Bloom
            },
        },
        [262648] = {
            name = "Yellow Dye Pigment", category = "Yellow", herbQty = 10,
            herbs = {
                Classic     = { 8838   }, -- Sungrass
                BC          = { 22786  }, -- Dreaming Glory
                Wrath       = { 36901  }, -- Goldclover
                Cata        = { 52988  }, -- Whiptail
                MoP         = { 72234  }, -- Green Tea Leaf
                WoD         = { 109126 }, -- Gorgrond Flytrap
                Legion      = { 124104 }, -- Fjarnskaggl
                BfA         = { 152511 }, -- Sea Stalk
                Shadowlands = { 168586 }, -- Rising Glory
                Dragonflight= { 191464 }, -- Saxifrage
                TWW         = { 210808 }, -- Arathor's Spear
                Midnight    = { 236778 }, -- Mana Lily
            },
        },
    },

    -- ========================================================================
    -- DYE RECIPES: [dyeItemID] = pigmentItemID
    -- Each dye requires 1 pigment of the matching color.
    -- Lifted verbatim from VDS_DyeCraftingDB.dyeRecipes.
    -- ========================================================================
    dyeRecipes = {
        -- Black dyes (from Black Dye Pigment 262639)
        [259109] = 262639, -- Dark Iron Dye
        [259121] = 262639, -- Obsidium Black Dye
        [259123] = 262639, -- Stormheim Grey Dye
        [259098] = 262639, -- Darkwood Dye
        [259111] = 262639, -- Ironclaw Dye
        [259104] = 262639, -- Stormsteel Dye

        -- Blue dyes (from Blue Dye Pigment 262643)
        [259115] = 262643, -- Alliance Blue Dye
        [259153] = 262643, -- Dusk Lily Grey Dye
        [259129] = 262643, -- Zephras Blue Dye
        [259135] = 262643, -- Midnight Blue Dye
        [259146] = 262643, -- Nazjatar Navy Dye

        -- Brown dyes (from Brown Dye Pigment 262642)
        [259053] = 262642, -- Warm Teak Dye
        [259096] = 262642, -- Mesquite Brown Dye
        [259101] = 262642, -- Pale Umber Dye
        [259103] = 262642, -- Heartwood Dye
        [259112] = 262642, -- Dark Gold Dye
        [259122] = 262642, -- Earthen Brown Dye
        [259141] = 262642, -- Vol'dun Taupe Dye
        [259145] = 262642, -- Timbermaw Brown Dye
        [259128] = 262642, -- Kalimdor Sand Dye

        -- Green dyes (from Green Dye Pigment 262647)
        [259114] = 262647, -- Lush Green Dye
        [259150] = 262647, -- Earthroot Dye
        [259124] = 262647, -- Silversage Green Dye
        [259133] = 262647, -- Dustwallow Green Dye
        [259143] = 262647, -- Gravemoss Green Dye
        [259147] = 262647, -- Grizzly Hills Green Dye
        [259134] = 262647, -- Emerald Dreaming Dye

        -- Orange dyes (from Orange Dye Pigment 262656)
        [259118] = 262656, -- Elwynn Pumpkin Dye
        [259132] = 262656, -- Kodohide Brown Dye
        [259105] = 262656, -- Copper Dye
        [259108] = 262656, -- Bronze Dye

        -- Purple dyes (from Purple Dye Pigment 262625)
        [259116] = 262625, -- Kirin Tor Violet Dye
        [259119] = 262625, -- Netherstorm Fuchsia Dye
        [259126] = 262625, -- Void Violet Dye
        [259130] = 262625, -- Nightsong Lilac Dye
        [259131] = 262625, -- Arcwine Dye
        [259140] = 262625, -- Moonberry Amethyst Dye
        [259144] = 262625, -- Forsaken Plum Dye

        -- Red dyes (from Red Dye Pigment 262655)
        [259127] = 262655, -- Firebloom Red Dye
        [259102] = 262655, -- Mahogany Dye
        [259142] = 262655, -- Ratchet Rust Dye
        [259113] = 262655, -- Horde Red Dye
        [259139] = 262655, -- Gilnean Rose Dye
        [259152] = 262655, -- Hinterlands Hickory Dye
        [259154] = 262655, -- Rain Poppy Red Dye
        [259151] = 262655, -- Deep Mageroyal Red Dye

        -- Teal dyes (from Teal Dye Pigment 262628)
        [259136] = 262628, -- Vortex Teal Dye
        [259125] = 262628, -- Un'Goro Green Dye
        [259110] = 262628, -- Kul Tiran Steel Dye
        [259148] = 262628, -- Tidesage Teal Dye

        -- White dyes (from White Dye Pigment 260947)
        [259120] = 260947, -- Bone-White Dye
        [259078] = 260947, -- Basic Birch Dye
        [259099] = 260947, -- Highland Birch Dye
        [259149] = 260947, -- Highborne Marble Dye

        -- Yellow dyes (from Yellow Dye Pigment 262648)
        [258838] = 262648, -- Gold Dye
        [259097] = 262648, -- Pinewood Dye
        [259100] = 262648, -- Holy Oak Tan Dye
        [259106] = 262648, -- Zandalari Gold Dye
        [259107] = 262648, -- Brass Dye
        [259117] = 262648, -- Sandfury Yellow Dye
        [259137] = 262648, -- Sungrass Yellow Dye
        [259138] = 262648, -- Savannah Gold Dye
    },
}

-- ============================================================================
-- Helper API (mirrors VDS_DyeCraftingDB.GetPigmentForDye / GetHerbsForDye)
-- ============================================================================

function Villa.Data.DyeCrafting.GetPigmentForDye(dyeItemID)
    local d = Villa.Data.DyeCrafting
    local pigmentID = d.dyeRecipes and d.dyeRecipes[dyeItemID] or nil
    if not pigmentID then return nil end
    return pigmentID, d.pigments and d.pigments[pigmentID] or nil
end

function Villa.Data.DyeCrafting.GetHerbsForDye(dyeItemID)
    local d = Villa.Data.DyeCrafting
    local pigmentID = d.dyeRecipes and d.dyeRecipes[dyeItemID] or nil
    if not pigmentID then return nil end
    local pigment = d.pigments and d.pigments[pigmentID] or nil
    return pigment and pigment.herbs or nil
end
