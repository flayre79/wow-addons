local M = _G.FabledUI_Crafty
if not M then return end
M.TrainingData = M.TrainingData or {}

local data = {
    Alchemy = {
        Dragonflight = {
            profession = "Alchemy",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Alchemical Theory",
                    recommended = false,
                    note = "Bonus skill when crafting. General path.",
                },
                {
                    name = "Potion Mastery",
                    recommended = false,
                    note = "Potion quality and multicraft.",
                },
                {
                    name = "Flask Mastery",
                    recommended = false,
                    note = "Phial quality and multicraft.",
                },
                {
                    name = "Thaumaturgy",
                    recommended = false,
                    note = "Transmutation-focused.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Build into the guide path below.",
                },
                {
                    text = "Dragon Isles Treatises",
                    note = "10 KP each. From Dragon Isles Inscription or AH.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Open world drops from Dragon Isles content.",
                },
                {
                    text = "Weekly patron quest",
                    note = "Gives several Knowledge Points. Check in Valdrakken weekly.",
                },
            },
            steps = {
                {
                    text = "2x Refreshing Healing Potion (1-7), then 2x Aerated Mana Potion (7-11)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 11,
                    note = "",
                    materials = {
                        ["Rousing Frost"] = 6,
                        Hochenblume = 32,
                        ["Rousing Air"] = 2,
                        ["Draconic Vial"] = 4,
                    },
                },
                {
                    text = "Use Reclaim Concoctions on all 10 potions you just made (11-15)",
                    type = "step",
                    minSkill = 11,
                    maxSkill = 15,
                    note = "Reclaim Concoctions destroys potions for Dragon's Alchemical Solution — needed later for experimentation.",
                    materials = {},
                },
                {
                    text = "15x Omnium Draconis (16-25) — recipe turns yellow at 20, may need more",
                    type = "step",
                    minSkill = 16,
                    maxSkill = 25,
                    note = "",
                    materials = {
                        Writhebark = 15,
                        Saxifrage = 15,
                        Hochenblume = 75,
                        ["Bubble Poppy"] = 15,
                    },
                },
                {
                    text = "Unlock Specializations at skill 25. Plan your KP carefully before spending.",
                    type = "trainer",
                    minSkill = 25,
                    maxSkill = 25,
                    note = "",
                    materials = {},
                },
                {
                    text = "1x Primal Convergent (First Craft, 25-26)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 26,
                    note = "",
                    materials = {
                        ["Awakened Earth"] = 1,
                        ["Awakened Fire"] = 1,
                        ["Awakened Air"] = 1,
                        ["Awakened Frost"] = 1,
                        ["Awakened Order"] = 1,
                    },
                },
                {
                    text = "15x Phial of Tepid Versatility (26-35, yellow last 5)",
                    type = "step",
                    minSkill = 26,
                    maxSkill = 35,
                    note = "",
                    materials = {
                        ["Awakened Frost"] = 30,
                        Hochenblume = 240,
                    },
                },
                {
                    text = "1x Basic Phial Experimentation + 1x Basic Potion Experimentation (First Crafts, 45-47)",
                    type = "step",
                    minSkill = 45,
                    maxSkill = 47,
                    note = "2x per experimentation: 5x Artisan's Mettle, 2x Dragon's Alchemical Solution, 1x Omnium Draconis. Dragon's Alch Solution comes from Reclaim Concoctions.",
                    materials = {
                        ["Artisan's Mettle"] = 10,
                        ["Dragon's Alchemical Solution"] = 4,
                        ["Omnium Draconis"] = 2,
                    },
                },
                {
                    text = "More experimentations + 2x Elemental Potion of Power (50-56)",
                    type = "step",
                    minSkill = 47,
                    maxSkill = 56,
                    note = "",
                    materials = {
                        ["Omnium Draconis"] = 8,
                        ["Primal Convergent"] = 2,
                    },
                },
                {
                    text = "65-100: Spam Basic Phial Experimentation and Basic Potion Experimentation",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "Both give skill to 100 but go green between 90-100. Spark of Ingenuity required for any end-game high-quality crafts. Farm via weekly quests.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Alchemy",
            tier = "Midnight",
            trainerZone = "Silvermoon City (Quel'Thalas)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Potions",
                    recommended = false,
                    note = "Potion mastery path.",
                },
                {
                    name = "Flasks",
                    recommended = true,
                    note = "Flask recipes give 2 skill/craft until 90. Best 50-100 method.",
                },
                {
                    name = "Transmutes",
                    recommended = false,
                    note = "Transmutation focus for mote conversion.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Craft each potion, flask, and transmute once.",
                },
                {
                    text = "Camberon's Cauldron",
                    note = "Click the cauldron near your trainer to Research new recipes. Do this early!",
                },
                {
                    text = "Recycle Potions",
                    note = "Recycle your crafted potions to gain skill points back (7-20 mechanic).",
                },
                {
                    text = "Treatise on Alchemy (Midnight)",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "6x Silvermoon Health Potion (1-7)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 7,
                    note = "",
                    materials = {
                        ["Tranquility Bloom"] = 36,
                        ["Sunglass Vial"] = 30,
                    },
                },
                {
                    text = "50-100: Craft Flasks (2 skill until 90, then yellow to 95) or Potions (1 skill, yellow at 80)",
                    type = "step",
                    minSkill = 50,
                    maxSkill = 100,
                    note = "Flask path is faster. Discover Flask recipes through specialization. Potions/Transmutes also viable but slower. Last 5-10 points may need extra crafts.",
                    materials = {},
                },
            },
        },
        Shadowlands = {
            profession = "Alchemy",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Alchemy from Elixologist Vilmos in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "80x Crafter's Mark I (1-35)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 35,
                    note = "Quickest way up with Nightshade. Keep all marks — used for crafted gear.",
                    materials = {
                        Widowbloom = 160,
                        ["Empty Vial"] = 80,
                    },
                },
                {
                    text = "33x Spectral Flask of Power (35-70)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 70,
                    note = "",
                    materials = {
                        Widowbloom = 99,
                        ["Rising Glory"] = 99,
                        Marrowroot = 99,
                        Nightshade = 66,
                        ["Phial of Serenity"] = 33,
                    },
                },
                {
                    text = "40x Potion of Spectral Strength (70-100)",
                    type = "step",
                    minSkill = 70,
                    maxSkill = 100,
                    note = "",
                    materials = {
                        Widowbloom = 80,
                        ["Vigil's Torch"] = 80,
                        ["Empty Vial"] = 40,
                    },
                },
                {
                    text = "15x Cosmic Healing Potion (100-115)",
                    type = "step",
                    minSkill = 100,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Rising Glory"] = 30,
                        Marrowroot = 30,
                        ["Empty Vial"] = 15,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Alchemy",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Alchemical Mastery",
                    recommended = false,
                    note = "Unlocks Formulated Courage to clear experiment debuff. Niche.",
                },
                {
                    name = "Potion Mastery",
                    recommended = true,
                    note = "Best for most players. Potent Potions / Elixir Expert sub-specs.",
                },
                {
                    name = "Flask Mastery",
                    recommended = false,
                    note = "Fantastic Flasks sub-spec. Good for progression raiders.",
                },
                {
                    name = "Thaumaturgy",
                    recommended = false,
                    note = "Transmutes 20 herbs -> mixed mats. Only gives skill up to 50.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Craft each recipe for the first time while it gives skill points.",
                },
                {
                    text = "Meticulous Experimentation",
                    note = "Daily CD. 5 skill points each. Best daily discovery source. Craft every day!",
                },
                {
                    text = "Treatise on Alchemy",
                    note = "10 KP each. Crafted by Inscriptionists. Buy from AH or an alt.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "Collect one-time treasures for 24 KP total. See Map Pins for locations.",
                },
                {
                    text = "Weekly Quests & Patrons",
                    note = "Complete 'A Worthy Ally' and Patron Work Orders for 10-15 KP per week.",
                },
                {
                    text = "Wild Experimentation (normal)",
                    note = "Cheap experiment for procedure discovery — use until hazardous outcome to learn Meticulous.",
                },
            },
            steps = {
                {
                    text = "Wild Experimentation x3 — Use on 20x Mycobloom, 20x Blessing Blossom, 20x Orbinid (or Luredrop)",
                    type = "step",
                    minSkill = 10,
                    maxSkill = 20,
                    note = "Discovers: Algari Mana Potion, Slumbering Soul Serum, Cavedweller's Delight. First craft each discovered recipe for KP!",
                    materials = {
                        Mycobloom = 20,
                        ["Blessing Blossom"] = 20,
                        Orbinid = 20,
                    },
                },
                {
                    text = "1x Slumbering Soul Serum (First Craft bonus)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 22,
                    note = "",
                    materials = {
                        Mycobloom = 4,
                        ["Blessing Blossom"] = 5,
                        ["Arathor's Spear"] = 5,
                        ["Gilded Vial"] = 5,
                    },
                },
                {
                    text = "Complete Meticulous Experimentation daily to fill final points. Algari Alchemist Stone requires Spark of Omens.",
                    type = "step",
                    minSkill = 90,
                    maxSkill = 100,
                    note = "Spark of Omens is time-gated (cannot be farmed). Meticulous Experimentation stays yellow all the way to 100.",
                    materials = {
                        ["Artisan's Acuity"] = 1,
                    },
                },
            },
        },
    },
    Blacksmithing = {
        Dragonflight = {
            profession = "Blacksmithing",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Armorsmithing",
                    recommended = true,
                    note = "Pick first! Put 10 → Fine-Armor → 10 → Vambraces. Unlocks Primal Molten Vambraces for 65-100.",
                },
                {
                    name = "Weaponsmithing",
                    recommended = false,
                    note = "Weapon focus.",
                },
                {
                    name = "Toolsmithing",
                    recommended = false,
                    note = "Profession tools.",
                },
                {
                    name = "Specialty Armor",
                    recommended = false,
                    note = "Specialty crafts.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. This guide captures all first crafts on the leveling path.",
                },
                {
                    text = "Spark of Ingenuity",
                    note = "Required for 65-100 crafts (BoP). Complete Dragonflight campaign + Engine of Innovation questline.",
                },
                {
                    text = "Weekly patron quests",
                    note = "Dragon Isles Knowledge from weekly crafting orders. Check Valdrakken.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Open world Dragon Isles content.",
                },
            },
            steps = {
                {
                    text = "1x Explorer's Plate Bracers + 1x Draconium Blacksmith's Hammer (EQUIP HAMMER!) — 1-7",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 7,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 18,
                        ["Draconium Ore"] = 5,
                    },
                },
                {
                    text = "1x Draconium Pickaxe (7-10)",
                    type = "step",
                    minSkill = 7,
                    maxSkill = 10,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 10,
                        ["Draconium Ore"] = 2,
                    },
                },
                {
                    text = "1x Draconium Sickle + 1x Explorer's Plate Chestguard (10-17)",
                    type = "step",
                    minSkill = 10,
                    maxSkill = 17,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 20,
                        ["Draconium Ore"] = 5,
                    },
                },
                {
                    text = "1x Draconium Skinning Knife + 1x Draconium Blacksmith's Toolbox (EQUIP TOOLBOX!) — 17-21",
                    type = "step",
                    minSkill = 17,
                    maxSkill = 21,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 22,
                        ["Draconium Ore"] = 6,
                    },
                },
                {
                    text = "1x Draconium Leatherworker's Knife + 1x Draconium Defender (21-26)",
                    type = "step",
                    minSkill = 21,
                    maxSkill = 26,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 24,
                        ["Draconium Ore"] = 9,
                    },
                },
                {
                    text = "Unlock Specializations at skill 25. Pick Armorsmithing first.",
                    type = "trainer",
                    minSkill = 25,
                    maxSkill = 25,
                    note = "DON'T spend KP yet! Level to 65 first, then put 10pts Armorsmithing → Fine-Armor → 10pts → Vambraces.",
                    materials = {},
                },
                {
                    text = "1x Draconium Axe + 1x Draconium Leatherworker's Toolset (26-31)",
                    type = "step",
                    minSkill = 26,
                    maxSkill = 31,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 24,
                        ["Draconium Ore"] = 12,
                    },
                },
                {
                    text = "1x Draconium Needle Set + 1x Explorer's Expert Clasp (31-37)",
                    type = "step",
                    minSkill = 31,
                    maxSkill = 37,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 20,
                        ["Draconium Ore"] = 8,
                    },
                },
                {
                    text = "2x Explorer's Expert Greaves (37-41)",
                    type = "step",
                    minSkill = 37,
                    maxSkill = 41,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 42,
                        ["Draconium Ore"] = 21,
                    },
                },
                {
                    text = "1x Draconium Great Axe + 1x Explorer's Expert Gauntlets (41-45)",
                    type = "step",
                    minSkill = 41,
                    maxSkill = 45,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 32,
                        ["Draconium Ore"] = 16,
                    },
                },
                {
                    text = "65-100: Spend KP (Armorsmithing 10 → Fine-Armor 10 → Vambraces), then craft 5x Primal Molten Vambraces per Spark",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "Spark of Ingenuity (BoP) from: 1) Dragonflight campaign → unlock World Quests, 2) Engine of Innovation questline (Therazal in Valdrakken). Each Spark enables high-quality armor crafts.",
                    materials = {
                        ["Primal Molten Alloy"] = 70,
                    },
                },
            },
        },
        Midnight = {
            profession = "Blacksmithing",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Craftsmithing",
                    recommended = true,
                    note = "Unlock Rare Profession Equipment recipes (no BoP mats needed). Best path for 70-100.",
                },
                {
                    name = "Weaponsmithing",
                    recommended = false,
                    note = "Weapon focus.",
                },
                {
                    name = "Armorsmithing",
                    recommended = false,
                    note = "Armor focus.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Craft every recipe in your book at least once.",
                },
                {
                    text = "NPC/Patron Work Orders",
                    note = "Good source of Artisan's Acuity. Check daily.",
                },
                {
                    text = "Rare Profession Equipment",
                    note = "Sun-Blessed tools (Craftsmithing spec). BoP, but great for skill 70-100.",
                },
                {
                    text = "Treatise on Blacksmithing",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "Filter 'First Craft Bonus' in your Profession window and craft EVERY recipe while learning new ones from trainer",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 50,
                    note = "Step-by-step: 1) Use First Craft filter. 2) Keep trainer window open side-by-side. 3) Craft each recipe once. 4) Learn new trainer recipes. 5) Repeat. End up ~47-50 skill.",
                    materials = {
                        ["Luminant Flux"] = 100,
                        ["Refulgent Copper Ingot"] = 50,
                        ["Brilliant Silver Ore"] = 50,
                    },
                },
                {
                    text = "70-100: Unlock Rare Profession Equipment via Craftsmithing spec, then spam craft Sun-Blessed tools",
                    type = "step",
                    minSkill = 70,
                    maxSkill = 100,
                    note = "Sun-Blessed tools include: Blacksmith's Hammer, Toolbox, Leatherworker's Knife, Needle Set, Pickaxe, Sickle, Skinning Knife. Pick first unlockable and craft to 100. All are BoP.",
                    materials = {
                        ["Sterling Alloy"] = 5,
                        ["Majestic Claw"] = 1,
                        ["Dazzling Thorium"] = 2,
                    },
                },
            },
        },
        Shadowlands = {
            profession = "Blacksmithing",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Blacksmithing from Quartermaster Aldric in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "45x Shadowghast Ingot (1-30)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 30,
                    note = "Smelt Elethium Ore. Buy Shadowghast from AH if already available and cheaper.",
                    materials = {
                        ["Elethium Ore"] = 225,
                    },
                },
                {
                    text = "30x Elethium Ore Nugget (30-55)",
                    type = "step",
                    minSkill = 30,
                    maxSkill = 55,
                    note = "",
                    materials = {
                        ["Elethium Ore"] = 90,
                    },
                },
                {
                    text = "20x Shadowghast Helm (55-75)",
                    type = "step",
                    minSkill = 55,
                    maxSkill = 75,
                    note = "",
                    materials = {
                        ["Shadowghast Ingot"] = 80,
                        ["Elethium Ore"] = 80,
                    },
                },
                {
                    text = "20x Shadowghast Breastplate (75-95)",
                    type = "step",
                    minSkill = 75,
                    maxSkill = 95,
                    note = "",
                    materials = {
                        ["Shadowghast Ingot"] = 80,
                        ["Elethium Ore"] = 80,
                    },
                },
                {
                    text = "20x Shadowghast Sabatons (95-115, green last 5)",
                    type = "step",
                    minSkill = 95,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Shadowghast Ingot"] = 80,
                        ["Elethium Ore"] = 80,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Blacksmithing",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Hammer of the Titans",
                    recommended = false,
                    note = "Weapon-focused. Ironclaw weapons and Everburning Ignition daily CD.",
                },
                {
                    name = "Armorsmithing",
                    recommended = false,
                    note = "Armor pieces. Requires high skill for epic recipes.",
                },
                {
                    name = "Everburning Forge",
                    recommended = true,
                    note = "PICK at skill 50! Unlocks Everburning Ignition (2h recharge, 5 charges) — cheapest 75-94 path.",
                },
                {
                    name = "Craftsmithing / Means of Production",
                    recommended = false,
                    note = "Profession tool crafting orders. Good for Artisan's Acuity income.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Craft each newly learned recipe at least once.",
                },
                {
                    text = "Everburning Ignition",
                    note = "2-hour recharge, 5 charges. Craft 30 for 75-94. ~3-4 days of logging in.",
                },
                {
                    text = "NPC/Patron Work Orders",
                    note = "Main source of Artisan's Acuity and weekly KP. Check daily.",
                },
                {
                    text = "Treatise on Blacksmithing",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "One-time treasures provide 24 KP. Look for Blacksmithing-specific items like 'Old Hammer'.",
                },
                {
                    text = "Weekly Quests",
                    note = "Complete the weekly profession quest in Dornogal for 10 KP.",
                },
            },
            steps = {
                {
                    text = "Craft 1x each weapon (First Crafts): Dredger's Defender, Ironclaw Dirk, Stiletto, Axe, Sword, Great Mace, Knuckles",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 42,
                    note = "Make Defender and Dirk first — they turn yellow sooner. Also craft Proficient Blacksmith's Toolbox (EQUIP) + Dredger's Helm/Gauntlets.",
                    materials = {
                        ["Ironclaw Ore"] = 51,
                        Bismuth = 17,
                        ["Core Alloy"] = 14,
                        ["Crystalline Powder"] = 2,
                    },
                },
                {
                    text = "94-100: Complete NPC/Patron Work Orders for profession equipment (+2 skill per order)",
                    type = "step",
                    minSkill = 94,
                    maxSkill = 100,
                    note = "Epic armor (Spark Recipes) for final push if you have Sparks and specialization recipes.",
                    materials = {},
                },
            },
        },
    },
    Enchanting = {
        Dragonflight = {
            profession = "Enchanting",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Enchantment",
                    recommended = true,
                    note = "Pick first! Don't spend KP yet, level to 65+ first.",
                },
                {
                    name = "Manipulation",
                    recommended = false,
                    note = "Material conversion and shattering.",
                },
                {
                    name = "Artifice",
                    recommended = false,
                    note = "Specialty wands and rods.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. All Writs and Devotions give KP on first craft.",
                },
                {
                    text = "Disenchanting",
                    note = "Skill up to 25 from disenchanting old gear. Do BEFORE leveling!",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Dragon Isles open world content.",
                },
                {
                    text = "Weekly patron quests",
                    note = "Dragon Isles Knowledge from crafting orders weekly.",
                },
            },
            steps = {
                {
                    text = "1x Runed Serevite Rod (buy Serevite Rod from Andoris) — EQUIP IT! (1-2)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 2,
                    note = "",
                    materials = {
                        ["Serevite Rod"] = 1,
                        ["Chromatic Dust"] = 3,
                    },
                },
                {
                    text = "Disenchant spare gear for skill 2-25 (skip to 5 if no gear)",
                    type = "step",
                    minSkill = 2,
                    maxSkill = 25,
                    note = "",
                    materials = {},
                },
                {
                    text = "First Crafts (all on Enchanting Vellum): 1x Writ of Versatility, 1x Scepter of Spectacle:Earth, 1x Scepter:Fire (1-5 if skip disenchant)",
                    type = "step",
                    minSkill = 2,
                    maxSkill = 5,
                    note = "",
                    materials = {
                        ["Chromatic Dust"] = 5,
                        ["Rousing Earth"] = 3,
                        ["Rousing Fire"] = 3,
                        Writhebark = 2,
                    },
                },
                {
                    text = "7x Writ of Critical Strike (5-15), then First Crafts: Writ of Haste, Writ of Mastery",
                    type = "step",
                    minSkill = 5,
                    maxSkill = 15,
                    note = "",
                    materials = {
                        ["Chromatic Dust"] = 27,
                    },
                },
                {
                    text = "1x Runed Draconium Rod (EQUIP, sell Serevite Rod) + 3x Bracer Writs (15-21)",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 21,
                    note = "",
                    materials = {
                        ["Chromatic Dust"] = 4,
                        ["Draconium Ore"] = 3,
                        Writhebark = 2,
                        ["Vibrant Shard"] = 3,
                    },
                },
                {
                    text = "2x Bracer Writ of Leech + 1x Scepter:Frost + 1x Scepter:Air (21-25, may need more bracer writs)",
                    type = "step",
                    minSkill = 21,
                    maxSkill = 25,
                    note = "",
                    materials = {
                        ["Vibrant Shard"] = 2,
                        ["Chromatic Dust"] = 2,
                        ["Rousing Frost"] = 3,
                        ["Rousing Air"] = 3,
                        Writhebark = 2,
                    },
                },
                {
                    text = "3x each of Writ of Avoidance/Leech/Speed (Cloak, 25-31), then 3x Writ of Leech Cloak",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 31,
                    note = "",
                    materials = {
                        ["Chromatic Dust"] = 60,
                    },
                },
                {
                    text = "4x Devotion of Versatility (31-35)",
                    type = "step",
                    minSkill = 31,
                    maxSkill = 35,
                    note = "",
                    materials = {
                        ["Chromatic Dust"] = 20,
                        ["Vibrant Shard"] = 12,
                    },
                },
                {
                    text = "35-50: Chest/Ring/Bracer enchants for First Crafts, then spam ring Writs (Chromatic Dust)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 50,
                    note = "",
                    materials = {
                        ["Chromatic Dust"] = 80,
                        ["Vibrant Shard"] = 10,
                        ["Resonant Crystal"] = 5,
                    },
                },
                {
                    text = "65-100: Spark of Ingenuity required for epic enchant recipes. Fill gap with weapon enchant Devotions.",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "Spark of Ingenuity from: Dragonflight campaign completion + Engine of Innovation questline in Valdrakken. Epic wands also require Sparks.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Enchanting",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Ephemerals",
                    recommended = false,
                    note = "Consumable enchants (oils, stones).",
                },
                {
                    name = "Enrichments",
                    recommended = false,
                    note = "Stat enchants for gear.",
                },
                {
                    name = "Equipment",
                    recommended = true,
                    note = "Weapon and armor enchants. Unlocks first at skill 25.",
                },
                {
                    name = "Gleeful Glamours",
                    recommended = true,
                    note = "4th spec (skill 75). Transformation enchants — popular NPC crafting order items.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. This guide is designed around capturing 1ST CRAFT bonuses while recipes still give skill.",
                },
                {
                    text = "Gleeful Glamours (+24 KP)",
                    note = "Hit skill 55 to unlock. 24 unique glamour recipes = 24 KP at once. Major KP source.",
                },
                {
                    text = "NPC Crafting Orders",
                    note = "Glamour enchants and gear enchants frequently ordered. Main Artisan's Acuity source.",
                },
                {
                    text = "Treatise on Enchanting",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "30x Runed Refulgent Copper Rod, then Disenchant all 30 of them for skill points up to 25",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 25,
                    note = "You get about half your Eversinging Dust back from disenchanting. Buy extra Refulgent Copper Rods from supply vendor Lyna.",
                    materials = {
                        ["Refulgent Copper Rod"] = 30,
                        ["Eversinging Dust"] = 150,
                    },
                },
                {
                    text = "80-100: Epic enchants via Spark recipes. Fill remaining points with NPC Crafting Orders.",
                    type = "step",
                    minSkill = 80,
                    maxSkill = 100,
                    note = "Epic enchants require Sparks of Midnight (time-gated). Otherwise fill with Patron/NPC Crafting Orders which give skill too.",
                    materials = {},
                },
            },
        },
        Shadowlands = {
            profession = "Enchanting",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Enchanting from Imbuer Au'vanya in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "Disenchant all spare Shadowlands green/blue gear first for free skill points to 25.",
                    materials = {},
                },
                {
                    text = "Disenchant spare Shadowlands gear (1-25)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 25,
                    note = "",
                    materials = {},
                },
                {
                    text = "1x Runed Elethium Rod (buy rod from vendor) — EQUIP (1-5 if no disenchant gear)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 5,
                    note = "",
                    materials = {
                        ["Elethium Rod"] = 1,
                        ["Rit Dust"] = 3,
                    },
                },
                {
                    text = "7x Enchant Ring — Tenet of Critical Strike (25-40)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 40,
                    note = "",
                    materials = {
                        ["Rit Dust"] = 35,
                    },
                },
                {
                    text = "7x Enchant Ring — Tenet of Mastery (40-55)",
                    type = "step",
                    minSkill = 40,
                    maxSkill = 55,
                    note = "",
                    materials = {
                        ["Rit Dust"] = 35,
                    },
                },
                {
                    text = "25x Enchant Cloak — Fortified Leech (55-80)",
                    type = "step",
                    minSkill = 55,
                    maxSkill = 80,
                    note = "",
                    materials = {
                        ["Rit Dust"] = 75,
                    },
                },
                {
                    text = "15x Enchant Chest — Sacred Stats (80-95)",
                    type = "step",
                    minSkill = 80,
                    maxSkill = 95,
                    note = "",
                    materials = {
                        ["Soul Dust"] = 45,
                        ["Rit Dust"] = 30,
                    },
                },
                {
                    text = "20x Enchant Ring — Tenet of Haste or Critical Strike (95-115, green last 5)",
                    type = "step",
                    minSkill = 95,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Rit Dust"] = 100,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Enchanting",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Ephemerals, Enrichments, and Equipment",
                    recommended = true,
                    note = "PICK FIRST. Spend 5 pts here, then 15 in Deceptive Decorations to unlock 22 Gleeful Glamour recipes = 22 KP for 20 pts invested!",
                },
                {
                    name = "Deceptive Decorations (sub-spec)",
                    recommended = true,
                    note = "Unlock under EEE. 22 transformation glam recipes. All are NPC crafting order items = Artisan's Acuity income.",
                },
                {
                    name = "Supplementary Shattering",
                    recommended = false,
                    note = "Disenchanting material yield improvement.",
                },
                {
                    name = "Enchanting Specialization (Ephemerals)",
                    recommended = false,
                    note = "High-end enchant quality. Useful for raiding.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Critical early on — craft every new recipe at least once.",
                },
                {
                    text = "Gleeful Glamour trick",
                    note = "+22 KP total from 22 Glamour recipes (unlock via Deceptive Decorations sub-spec, 15 pts).",
                },
                {
                    text = "NPC Crafting Orders",
                    note = "Glamours, crests, and enchants frequently appear. Provides weekly KP and Acuity.",
                },
                {
                    text = "Treatise on Enchanting",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "24 KP from one-time treasures (e.g. Enchanter's Crystal).",
                },
                {
                    text = "Weekly Quests",
                    note = "Complete 'A Worthy Ally' and Dornogal profession weekly.",
                },
            },
            steps = {
                {
                    text = "9x Glimmering Haste (put on Enchanting Vellum, sell on AH)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 10,
                    note = "",
                    materials = {
                        ["Storm Dust"] = 45,
                    },
                },
                {
                    text = "Epic Enchants via Spark recipes (91-100)",
                    type = "step",
                    minSkill = 91,
                    maxSkill = 100,
                    note = "Requires Spark of Omens and Ephemerals specialization. Fill remaining with Glimmering enchants (slow, green).",
                    materials = {},
                },
            },
        },
    },
    Engineering = {
        Dragonflight = {
            profession = "Engineering",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Function Over Form",
                    recommended = true,
                    note = "Pick first. Put 5 pts → unlock Gear sub-spec → 5 more pts. Needed for 65-100 recipe discovery.",
                },
                {
                    name = "Bombs and Bullets",
                    recommended = false,
                    note = "Combat items.",
                },
                {
                    name = "Utility",
                    recommended = false,
                    note = "Utility gadgets.",
                },
                {
                    name = "Contraptions",
                    recommended = false,
                    note = "Specialty items.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Captured on the leveling path below.",
                },
                {
                    text = "Spark of Ingenuity",
                    note = "Required for 65-100 Tinker bracers/goggles (BoP). Complete DF campaign + Engine of Innovation.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Dragon Isles open world.",
                },
                {
                    text = "Weekly patron quests",
                    note = "Dragon Isles Knowledge from Valdrakken crafting orders.",
                },
            },
            steps = {
                {
                    text = "25x Handful of Serevite Bolts (1-15)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 15,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 100,
                    },
                },
                {
                    text = "6x Shock-Spring Coil (15-21)",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 21,
                    note = "",
                    materials = {
                        ["Rousing Earth"] = 10,
                        ["Serevite Ore"] = 25,
                        ["Handful of Serevite Bolts"] = 10,
                    },
                },
                {
                    text = "First Craft all profession tools (21-29): 1x Ore Satchel, 1x Draconium Delver's Helmet, 1x Draconium Encased Samophlange (EQUIP!), 1x Lapidary's Clamps",
                    type = "step",
                    minSkill = 21,
                    maxSkill = 29,
                    note = "Buy Smudged Lens from Kognir. Equip Samophlange, sell Arclight Spanner and Micro-Adjustor.",
                    materials = {
                        ["Draconium Ore"] = 10,
                        ["Handful of Serevite Bolts"] = 8,
                        ["Shock-Spring Coil"] = 3,
                        ["Greased-Up Gears"] = 2,
                        ["Smudged Lens"] = 2,
                    },
                },
                {
                    text = "Unlock Specializations at skill 25. Pick Function Over Form. Put 5pts → Gear sub-spec.",
                    type = "trainer",
                    minSkill = 25,
                    maxSkill = 25,
                    note = "",
                    materials = {},
                },
                {
                    text = "1x Draconium Brainwave Amplifier (EQUIP!) + 1x Draconium Fabric Cutters (29-33)",
                    type = "step",
                    minSkill = 29,
                    maxSkill = 33,
                    note = "",
                    materials = {
                        ["Smudged Lens"] = 1,
                        ["Draconium Ore"] = 6,
                        ["Handful of Serevite Bolts"] = 5,
                        ["Shock-Spring Coil"] = 5,
                    },
                },
                {
                    text = "4x Bottomless Stonecrust Ore Satchel (33-41)",
                    type = "step",
                    minSkill = 33,
                    maxSkill = 41,
                    note = "",
                    materials = {
                        ["Draconium Ore"] = 20,
                        ["Handful of Serevite Bolts"] = 8,
                    },
                },
                {
                    text = "5x Tinker Removal Kit (41-45)",
                    type = "step",
                    minSkill = 41,
                    maxSkill = 45,
                    note = "",
                    materials = {
                        ["Draconium Ore"] = 10,
                        ["Handful of Serevite Bolts"] = 15,
                        ["Shock-Spring Coil"] = 10,
                    },
                },
                {
                    text = "65-100: Spark of Ingenuity required for Tinker bracers and goggles. Complete DF campaign → Engine of Innovation (Therazal, Valdrakken) for Sparks.",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "Put remaining KP into Function Over Form → Gear sub-spec (total 10pts needed for Tinker bracer recipes). Epic goggles require both Sparks and high KP investment.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Engineering",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Recycling",
                    recommended = true,
                    note = "PICK FIRST — REQUIRED! Put 10 pts here to activate recipe discovery. Unlocks Quel'dorei gear recipes (cheapest 45-80 path).",
                },
                {
                    name = "Market Mobility",
                    recommended = false,
                    note = "Profession tool crafting orders. Good Artisan's Acuity income.",
                },
                {
                    name = "Innovations",
                    recommended = false,
                    note = "Gadgets and toys. Fun utility items.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Discover recipes via Recycling, then craft each once.",
                },
                {
                    text = "Recycling discovery",
                    note = "After 10 Recycling spec pts, recycling materials discovers new recipes. Each discovery = First Craft KP.",
                },
                {
                    text = "Housing Decor (80-100)",
                    note = "7 Housing Decor recipes discovered via Recycling. All stay yellow to 92 — great final stretch.",
                },
                {
                    text = "Treatise on Engineering",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "First Crafts: 1x Evercore Shade + 1x Evercore Vision Guard (16-20)",
                    type = "step",
                    minSkill = 16,
                    maxSkill = 20,
                    note = "",
                    materials = {
                        Evercore = 2,
                    },
                },
                {
                    text = "10x Soul Sprocket + all 4 Cogwheel First Crafts (25-39)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 39,
                    note = "Put 10 points into Recycling spec now! Then craft Cogwheel First Crafts.",
                    materials = {
                        ["Malleable Wireframe"] = 10,
                        ["Refulgent Copper Ore"] = 50,
                        ["Umbral Tin Ore"] = 100,
                    },
                },
                {
                    text = "80-100: Craft 7 Housing Decor items (discovered via Recycling). All stay yellow to 92, craft each First for KP, then repeat cheapest.",
                    type = "step",
                    minSkill = 80,
                    maxSkill = 100,
                    note = "7 decor recipes: Small Telogrus Lamp, Ren'dorei Void Projector, Crafting Framework, Lightpost, Warp Orb, Ambient Crystal, Stargazer. Need ~600-700 Thalassian Lumber total.",
                    materials = {
                        Aetherlume = 5,
                        Evercore = 5,
                        ["Song Gear"] = 10,
                        ["Soul Sprocket"] = 10,
                        ["Thalassian Lumber"] = 10,
                    },
                },
            },
        },
        Shadowlands = {
            profession = "Engineering",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Engineering from Machinist Au'gur in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "50x Porous Bone Shaft (1-35)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 35,
                    note = "",
                    materials = {
                        ["Porous Stone"] = 100,
                        Bones = 50,
                    },
                },
                {
                    text = "20x Bladed Bone Knife (35-55)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 55,
                    note = "",
                    materials = {
                        ["Porous Bone Shaft"] = 60,
                        ["Shadowghast Ingot"] = 20,
                    },
                },
                {
                    text = "30x Wormhole Generator: Shadowlands (55-85)",
                    type = "step",
                    minSkill = 55,
                    maxSkill = 85,
                    note = "Buy parts from Engineering supply vendor near trainer.",
                    materials = {
                        ["Elethium Ore"] = 90,
                        ["Porous Stone"] = 60,
                        Bones = 30,
                    },
                },
                {
                    text = "30x Borrowed Time Device (85-115, green at 110)",
                    type = "step",
                    minSkill = 85,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Elethium Ore"] = 60,
                        ["Porous Stone"] = 60,
                        Bones = 30,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Engineering",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Inventing",
                    recommended = true,
                    note = "Daily Invent gives guaranteed skill point to 100. Unlocks Prototypes and recipe discovery. ~15 days to 100 this way.",
                },
                {
                    name = "Reconfiguration",
                    recommended = false,
                    note = "Scrapping old parts for mats. Useful for material recovery.",
                },
                {
                    name = "Fundamentals",
                    recommended = false,
                    note = "Core Engineering improvement. Goggles, gadgets.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Collect all goggles first crafts early!",
                },
                {
                    text = "Daily Inventing",
                    note = "Inventing gives guaranteed skill point and KP chance all the way to 100.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "24 KP total. Look for 'Mechanical Parts' and 'Rusted Scrap' treasures.",
                },
                {
                    text = "Treatise on Engineering",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
                {
                    text = "Pile of Rusted Scrap",
                    note = "Key reagent for ALL Engineering recipes. Farm by looting mobs or use Pilfer Through Parts on old expansion items.",
                },
            },
            steps = {
                {
                    text = "First Crafts: 4UT0-41M3R + all 4 Goggle types (Tracker's, Acolyte's, Spelunker's, Dredger's)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 33,
                    note = "",
                    materials = {
                        ["Pile of Rusted Scrap"] = 30,
                        ["Handful of Bismuth Bolts"] = 26,
                        ["Whimsical Wiring"] = 5,
                        ["Gyrating Gear"] = 5,
                        ["Safety Switch"] = 1,
                    },
                },
                {
                    text = "Option A (Slow/Cheap, ~15 days): Daily Inventing gives guaranteed skill point to 100",
                    type = "step",
                    minSkill = 40,
                    maxSkill = 100,
                    note = "Craft expensive toys at skill 80+ (guaranteed skill until 90). Other recipes yellow at 80.",
                    materials = {},
                },
                {
                    text = "Option B (Fast/Expensive): Discover Convincingly Realistic Jumper Cables via Scrap, spam craft to 92",
                    type = "step",
                    minSkill = 40,
                    maxSkill = 92,
                    note = "May need many Scrap runs to discover recipe. Then spam craft. Finish last 8 points with daily Inventing.",
                    materials = {
                        ["Pile of Rusted Scrap"] = 5,
                        ["Handful of Bismuth Bolts"] = 5,
                        ["Whimsical Wiring"] = 1,
                        ["Gyrating Gear"] = 1,
                        ["Safety Switch"] = 1,
                    },
                },
            },
        },
    },
    Inscription = {
        Dragonflight = {
            profession = "Inscription",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Runebinding",
                    recommended = true,
                    note = "Pick first. Unlocks Darkmoon Deck Boxes. Don't spend KP until skill 85.",
                },
                {
                    name = "Manuscripts",
                    recommended = false,
                    note = "Off-hands, tomes.",
                },
                {
                    name = "Notarization",
                    recommended = false,
                    note = "Contracts, Treatises.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Captured throughout the guide path.",
                },
                {
                    text = "Dragon Isles Treatises",
                    note = "10 KP each. Buy from Dragon Isles Inscription on AH.",
                },
                {
                    text = "Spark of Ingenuity",
                    note = "Required for Darkmoon Deck Boxes (Runebinding endgame 85-100). BoP.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Dragon Isles open world content.",
                },
            },
            steps = {
                {
                    text = "Mill herbs for skill 1-15: 100x Hochenblume, 20x Writhebark, 15x Saxifrage, 20x Bubble Poppy",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 15,
                    note = "Keep at least 35x Writhebark unmill'd! They're used in Runed Writhebark later.",
                    materials = {
                        Hochenblume = 100,
                        Writhebark = 20,
                        Saxifrage = 15,
                        ["Bubble Poppy"] = 20,
                    },
                },
                {
                    text = "6x Blazing Ink + 9x Flourishing Ink + 8x Serene Ink + 1x Chilled Rune (15-20)",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 20,
                    note = "",
                    materials = {
                        ["Iridescent Water"] = 23,
                        ["Draconic Vial"] = 23,
                    },
                },
                {
                    text = "7x Runed Writhebark + 4x Burnished Ink (20-32)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 32,
                    note = "",
                    materials = {
                        ["Rousing Air"] = 35,
                        Writhebark = 35,
                        ["Flourishing Ink"] = 7,
                        ["Chilled Rune"] = 7,
                        ["Blazing Ink"] = 8,
                        ["Serene Ink"] = 8,
                    },
                },
                {
                    text = "32-45: Craft missives (Dragon Isles Missive of the... all stat types) for First Craft KP",
                    type = "step",
                    minSkill = 32,
                    maxSkill = 45,
                    note = "Also: 1x Vantus Rune, 1x Contract, 1x Darkmoon Card of the Dragon Isles for First Crafts.",
                    materials = {
                        ["Burnished Ink"] = 10,
                        ["Blazing Ink"] = 10,
                        ["Serene Ink"] = 10,
                        ["Glittering Parchment"] = 20,
                    },
                },
                {
                    text = "45-60: Dragon Isles Treatise First Crafts (all 9 professions). Each gives 1 KP and 10 KP on use.",
                    type = "step",
                    minSkill = 45,
                    maxSkill = 60,
                    note = "",
                    materials = {
                        ["Burnished Ink"] = 18,
                        ["Blazing Ink"] = 18,
                        ["Serene Ink"] = 18,
                        ["Runed Writhebark"] = 9,
                        ["Glittering Parchment"] = 9,
                    },
                },
                {
                    text = "Skill 85: Now spend KP! Put 10pts Runebinding → Arcane Mastery → 10pts to unlock Darkmoon Deck Box recipes.",
                    type = "trainer",
                    minSkill = 85,
                    maxSkill = 85,
                    note = "",
                    materials = {},
                },
                {
                    text = "85-100: Craft Darkmoon Deck Boxes with Spark of Ingenuity",
                    type = "step",
                    minSkill = 85,
                    maxSkill = 100,
                    note = "Spark of Ingenuity (BoP) from Dragon Isles campaign. Darkmoon Deck Boxes are very profitable — sell on AH.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Inscription",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Calm Hands",
                    recommended = true,
                    note = "PICK FIRST! Unlocks the Thalassian Treatise on Inscription. Also: treat yourself to 10 pts before using Treatises — they give 2 KP instead of 1.",
                },
                {
                    name = "Archival (Midnight)",
                    recommended = false,
                    note = "Vantus Runes. Useful with raid groups.",
                },
                {
                    name = "Covenant of the Glyph",
                    recommended = false,
                    note = "Cosmetic glyph market.",
                },
                {
                    name = "Contracts",
                    recommended = false,
                    note = "Crafting order missives.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Get every Missive, Baton, Soul Cipher, and Treatise type.",
                },
                {
                    text = "Calm Hands + Treatises",
                    note = "Put 10 pts into Calm Hands BEFORE using Treatises to get 2 KP per treatise instead of 1.",
                },
                {
                    text = "Thalassian Treatises",
                    note = "Warbound — mail to alts. Discover Treatises for other professions and distribute.",
                },
                {
                    text = "Treatise on Inscription",
                    note = "10 KP self-treatise. Also discovered via Calm Hands spec.",
                },
            },
            steps = {
                {
                    text = "First Crafts: Faunatender's Baton, Floratender's Crutch, Rootwarden's Lamp, 2x Soul Cipher (30-35)",
                    type = "step",
                    minSkill = 30,
                    maxSkill = 35,
                    note = "",
                    materials = {
                        Azeroot = 26,
                        ["Mote of Pure Void"] = 2,
                        ["Mote of Light"] = 2,
                        ["Duskshrouded Stone"] = 2,
                        ["Munsell Ink"] = 2,
                        ["Sienna Ink"] = 2,
                    },
                },
                {
                    text = "3x Thalassian Treatise on Inscription (42-45) — DO NOT USE YET",
                    type = "step",
                    minSkill = 42,
                    maxSkill = 45,
                    note = "Save all Treatises until you have 10 pts in Calm Hands specialization. They give 2 KP per treatise after that!",
                    materials = {
                        ["Lexicologist's Vellum"] = 9,
                        ["Mote of Wild Magic"] = 3,
                        ["Munsell Ink"] = 3,
                        ["Sienna Ink"] = 3,
                    },
                },
                {
                    text = "Craft Thalassian Treatises until skill 100 (~60 total). Discover Treatises for other professions.",
                    type = "step",
                    minSkill = 51,
                    maxSkill = 100,
                    note = "Treatises are Warbound — mail to alts or sell. Discover 10+ other profession Treatises from crafting Inscription ones. Stays yellow to 90, green last 10 — need extra at end.",
                    materials = {
                        ["Lexicologist's Vellum"] = 3,
                        ["Mote of Wild Magic"] = 1,
                        ["Munsell Ink"] = 1,
                        ["Sienna Ink"] = 1,
                    },
                },
            },
        },
        Shadowlands = {
            profession = "Inscription",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Inscription from Scribe Au'tehshi in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "Mill herbs: 100x Widowbloom, 100x Rising Glory, 60x Marrowroot, 60x Vigil's Torch (1-20)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 20,
                    note = "",
                    materials = {},
                },
                {
                    text = "20x Luminous Ink + 15x Umbral Ink (20-35)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 35,
                    note = "",
                    materials = {},
                },
                {
                    text = "25x Writ of Domination (35-60)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 60,
                    note = "",
                    materials = {
                        ["Umbral Ink"] = 50,
                        ["Rune Etched Papers"] = 25,
                    },
                },
                {
                    text = "20x Shadowlands Missive (60-80)",
                    type = "step",
                    minSkill = 60,
                    maxSkill = 80,
                    note = "",
                    materials = {
                        ["Luminous Ink"] = 40,
                        ["Umbral Ink"] = 40,
                        ["Rune Etched Papers"] = 20,
                    },
                },
                {
                    text = "20x Contract: Wild Hunt (80-100)",
                    type = "step",
                    minSkill = 80,
                    maxSkill = 100,
                    note = "",
                    materials = {
                        ["Luminous Ink"] = 20,
                        ["Rune Etched Papers"] = 20,
                    },
                },
                {
                    text = "15x Darkmoon Card of Death (or other cards) (100-115)",
                    type = "step",
                    minSkill = 100,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Luminous Ink"] = 30,
                        ["Umbral Ink"] = 30,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Inscription",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Pursuit of Knowledge",
                    recommended = true,
                    note = "PICK FIRST! Unlocks the Algari Treatise on Inscription recipe — this carries you from 51 to 100.",
                },
                {
                    name = "Archival",
                    recommended = false,
                    note = "Vantus Runes. Strong with raid teams.",
                },
                {
                    name = "Covenant of the Glyph",
                    recommended = false,
                    note = "Glyphs and mounts. Good for cosmetic market.",
                },
                {
                    name = "Contracts and Missives",
                    recommended = false,
                    note = "Crafting Missives and Crafting Orders.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Get every Missive and Treatise type once.",
                },
                {
                    text = "Algari Treatise production",
                    note = "Treatises are Warbound — mail to alts who can use them. 10 KP each.",
                },
                {
                    text = "Inscription treasures",
                    note = "24 KP total from one-time treasures (e.g. Scribe's Ancient Tool).",
                },
                {
                    text = "Weekly Quests",
                    note = "Complete the weekly profession quest in Dornogal for 10 KP.",
                },
                {
                    text = "Patron Work Orders",
                    note = "Crests and Missives frequently appear. Check daily for KP and Acuity.",
                },
            },
            steps = {
                {
                    text = "Buy Profession Equipment from AH first (Lightweight Scribe's Quill with Resourcefulness recommended)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 20,
                    note = "Multicraft and Resourcefulness procs save gold on inks. Don't overpay — prices drop fast.",
                    materials = {},
                },
                {
                    text = "1x each: Algari Missive of the Fireflash, Harmonious, Peerless, Quickblade (First Crafts)",
                    type = "step",
                    minSkill = 40,
                    maxSkill = 47,
                    note = "",
                    materials = {
                        ["Viridescent Spores"] = 20,
                        ["Boundless Cipher"] = 4,
                        ["Apricate Ink"] = 4,
                    },
                },
                {
                    text = "6x Algari Treatise on Inscription (3 batches of 3x)",
                    type = "step",
                    minSkill = 42,
                    maxSkill = 51,
                    note = "Treatises are Warbound! Mail them to alts rather than using all on Inscription. Sell or give to guildmates.",
                    materials = {
                        ["Leyline Residue"] = 12,
                        ["Boundless Cipher"] = 6,
                        ["Apricate Ink"] = 12,
                    },
                },
                {
                    text = "Craft Algari Treatises until skill 100 (~60 total needed). Switch to other Treatise types as you discover them.",
                    type = "step",
                    minSkill = 51,
                    maxSkill = 100,
                    note = "Treatise stays yellow to 90, green last 10. Discover Treatises for other professions and distribute to alts — massive gold/KP value. Takes weeks of Treatise crafting.",
                    materials = {
                        ["Leyline Residue"] = 2,
                        ["Boundless Cipher"] = 1,
                        ["Apricate Ink"] = 2,
                    },
                },
            },
        },
    },
    Jewelcrafting = {
        Dragonflight = {
            profession = "Jewelcrafting",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Faceting",
                    recommended = false,
                    note = "Gem cutting quality.",
                },
                {
                    name = "Jewelry",
                    recommended = false,
                    note = "Rings and necklaces.",
                },
                {
                    name = "Artifice",
                    recommended = false,
                    note = "Specialty gems and prisms.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Captured throughout the guide.",
                },
                {
                    text = "Dragon Isles Prospecting",
                    note = "Skill points from prospecting ore (1-6).",
                },
                {
                    text = "Spark of Ingenuity",
                    note = "Required for Primal Focus jewelry (65-100). BoP.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Dragon Isles open world.",
                },
            },
            steps = {
                {
                    text = "Dragon Isles Prospecting on 25x Serevite Ore (1-6)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 6,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 25,
                    },
                },
                {
                    text = "First Crafts (6-12): 1x Glossy Stone, 1x Shimmering Clasp, 1x Dragon Isles Crushing (on Eternity Amber), 3x Solid Eternity Amber",
                    type = "step",
                    minSkill = 6,
                    maxSkill = 12,
                    note = "",
                    materials = {
                        ["Crumbled Stone"] = 4,
                        ["Rousing Earth"] = 2,
                        ["Eternity Amber"] = 9,
                        ["Misshapen Filigree"] = 1,
                        ["Mystic Sapphire"] = 1,
                    },
                },
                {
                    text = "First Crafts (12-15): 1x Frameless Lens, 1x Energized Vibrant Emerald, 1x Zen Mystic Sapphire",
                    type = "step",
                    minSkill = 12,
                    maxSkill = 15,
                    note = "",
                    materials = {
                        ["Rousing Earth"] = 3,
                        ["Fractured Glass"] = 3,
                        ["Silken Gemdust"] = 2,
                        ["Rousing Frost"] = 2,
                        ["Vibrant Emerald"] = 2,
                        ["Mystic Sapphire"] = 2,
                    },
                },
                {
                    text = "First Crafts (15-20): 1x Sensei's Sundered Onyx, 1x Crafty Queen's Ruby, 1x Band of New Beginnings, 1x Pendant of Impending Perils",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 20,
                    note = "",
                    materials = {
                        ["Rousing Fire"] = 2,
                        ["Sundered Onyx"] = 2,
                        ["Rousing Air"] = 2,
                        ["Queen's Ruby"] = 2,
                        ["Shimmering Clasp"] = 1,
                        ["Eternity Amber"] = 2,
                    },
                },
                {
                    text = "First Crafts (20-26): 1x Bold-Print Bifocals, 1x Sundered Onyx Loupe (EQUIP!), 1x Draconic Vial. Sell Jeweler's Toolset.",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 26,
                    note = "",
                    materials = {
                        ["Serevite Ore"] = 4,
                        ["Frameless Lens"] = 3,
                        ["Sundered Onyx"] = 1,
                        ["Rousing Fire"] = 1,
                        ["Fractured Glass"] = 5,
                        ["Draconic Stopper"] = 5,
                        ["Silken Gemdust"] = 2,
                    },
                },
                {
                    text = "55-75: Craft rings/necklaces with optional stat reagents (sell on AH)",
                    type = "step",
                    minSkill = 55,
                    maxSkill = 75,
                    note = "",
                    materials = {},
                },
                {
                    text = "75-100: Spark of Ingenuity required for Primal Focus jewelry. Complete DF campaign + Engine of Innovation.",
                    type = "step",
                    minSkill = 75,
                    maxSkill = 100,
                    note = "Epic gear: learn Torc of Passed Time and Signet of Titanic Insight via KP investment in Jewelry spec.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Jewelcrafting",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Gemcutting (Midnight)",
                    recommended = true,
                    note = "Unlock gem cuts for Eversong Diamonds and other gems. Strong market at tier launch.",
                },
                {
                    name = "Settings (Midnight)",
                    recommended = false,
                    note = "Ring and necklace quality improvements.",
                },
                {
                    name = "Mastering the Stone",
                    recommended = false,
                    note = "Prospecting efficiency.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. The guide is designed around catching First Crafts while leveling.",
                },
                {
                    text = "Monologuer's Chalice spam",
                    note = "Cheap filler recipe (60-65). 2x Crystalline Glass each.",
                },
                {
                    text = "Patron/NPC Crafting Orders",
                    note = "Main source past 65. Don't rush 65-100 unless you need high-quality guaranteed crafts.",
                },
                {
                    text = "Treatise on Jewelcrafting",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "65-100: Patron/NPC Crafting Orders — optional unless you need skill for guaranteed gold-quality crafts",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "No rush here unless you're filling gem orders. Cut Eversong Diamonds (weekly limit) and optional NPC orders provide steady progress. Rank 4 armor requires ~80+ skill for consistent gold quality.",
                    materials = {},
                },
            },
        },
        Shadowlands = {
            profession = "Jewelcrafting",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Jewelcrafting from Jeweled Gem-Blaster Au'phes in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "Shadowlands Prospecting on 250x Elethium Ore (1-20)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 20,
                    note = "",
                    materials = {
                        ["Elethium Ore"] = 250,
                    },
                },
                {
                    text = "10x Shadowlands Gem Chips (from prospecting) → cut into 10x Nightbloom Medallion (20-35)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 35,
                    note = "",
                    materials = {},
                },
                {
                    text = "30x Quick Sand Spinel (35-65)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 65,
                    note = "",
                    materials = {
                        ["Sand Spinel"] = 30,
                        ["Elethium Ore"] = 30,
                    },
                },
                {
                    text = "30x Guardian's Shadowghast Ring (65-95)",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 95,
                    note = "",
                    materials = {
                        ["Shadowghast Ingot"] = 120,
                        ["Elethium Ore"] = 60,
                    },
                },
                {
                    text = "10x Nightbloom Medallion + 10x Brilliant Spectral Agate (95-115)",
                    type = "step",
                    minSkill = 95,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        Nightbloom = 20,
                        ["Spectral Agate"] = 20,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Jewelcrafting",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Gemcutting",
                    recommended = true,
                    note = "Unlock gem cuts for Algari gems. Strong market for BiS gems early tier.",
                },
                {
                    name = "Settings",
                    recommended = false,
                    note = "Ring/necklace crafting with stat bonuses.",
                },
                {
                    name = "Mastering the Stone",
                    recommended = false,
                    note = "Prospect efficiency and raw gem processing.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Get every gem cut, ring, and necklace type.",
                },
                {
                    text = "Algari Prospecting",
                    note = "Skill points for prospecting ore. Do early while still orange (1-15).",
                },
                {
                    text = "NPC/Patron Work Orders",
                    note = "Primary source of weekly KP and Artisan's Acuity. Check daily.",
                },
                {
                    text = "Treatise on Jewelcrafting",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "24 KP from one-time treasures (e.g. Jeweler's Amber).",
                },
                {
                    text = "Weekly Quests",
                    note = "Complete the Dornogal profession weekly for 10 KP.",
                },
                {
                    text = "Blasphemite weekly limit",
                    note = "Only 10 Blasphemite can be cut per week. Save for when you can guarantee gold quality.",
                },
            },
            steps = {
                {
                    text = "2x Engraved Gemcutter + 1x each: Deadly Amber, Masterful Amber, Versatile Amber, Quick Amber (First Crafts)",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 20,
                    note = "",
                    materials = {
                        ["Handful of Pebbles"] = 10,
                        ["Glittering Glass"] = 2,
                        Bismuth = 10,
                        ["Ambivalent Amber"] = 4,
                        ["Engraved Gemcutter"] = 4,
                    },
                },
                {
                    text = "3x Marbled Stone + 1x Radiant Loupes (EQUIP the Radiant Loupes!)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 22,
                    note = "",
                    materials = {
                        ["Handful of Pebbles"] = 12,
                        Bismuth = 9,
                        ["Radiant Ruby"] = 1,
                        ["Crushed Gemstones"] = 4,
                        ["Marbled Stone"] = 10,
                    },
                },
                {
                    text = "3x Decorative Lens (26-31)",
                    type = "step",
                    minSkill = 26,
                    maxSkill = 31,
                    note = "",
                    materials = {
                        ["Glittering Glass"] = 30,
                        ["Ambivalent Amber"] = 6,
                        ["Crushed Gemstones"] = 12,
                    },
                },
                {
                    text = "1x Malleable Band + 1x Malleable Pendant (First Crafts, 31-35)",
                    type = "step",
                    minSkill = 31,
                    maxSkill = 35,
                    note = "",
                    materials = {
                        ["Ambivalent Amber"] = 4,
                        ["Radiant Ruby"] = 1,
                        ["Stunning Sapphire"] = 1,
                        ["Crushed Gemstones"] = 6,
                    },
                },
                {
                    text = "1x Storyteller's Glasses + 1x Incanter's Shard + 1x Right-Handed Magnifying Glass (First Crafts, 35-41)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 41,
                    note = "",
                    materials = {
                        ["Crushed Gemstones"] = 9,
                        ["Decorative Lens"] = 3,
                        ["Ambivalent Amber"] = 1,
                        ["Gleaming Shard"] = 1,
                    },
                },
                {
                    text = "80-100: NPC Crafting Orders, Blasphemite weekly cuts (10/week), and PvP Gem Recipes",
                    type = "step",
                    minSkill = 80,
                    maxSkill = 100,
                    note = "Blasphemite gems require high skill for guaranteed gold quality. PvP gems are craftable without Sparks.",
                    materials = {},
                },
            },
        },
    },
    Leatherworking = {
        Dragonflight = {
            profession = "Leatherworking",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Leather Armor Crafting",
                    recommended = true,
                    note = "Pick first (or Mail if you wear mail). Don't spend KP until 65.",
                },
                {
                    name = "Mail Armor Crafting",
                    recommended = false,
                    note = "Mail alternative.",
                },
                {
                    name = "Protective Linings",
                    recommended = false,
                    note = "Leg armor kits, spellthreads.",
                },
                {
                    name = "Specialty",
                    recommended = false,
                    note = "Specialty items.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Guide captures both Leather AND Mail First Crafts.",
                },
                {
                    text = "Spark of Ingenuity",
                    note = "Required for Primal Molten Defender/Rogue bracers (65-100). BoP.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Dragon Isles open world.",
                },
                {
                    text = "Weekly patron quests",
                    note = "Dragon Isles Knowledge from crafting orders weekly in Valdrakken.",
                },
            },
            steps = {
                {
                    text = "1x Pioneer's Leather Wristguards + 1x Trailblazer's Scale Bracers (1-7)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 7,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 20,
                        ["Adamant Scales"] = 20,
                    },
                },
                {
                    text = "1x Pioneer's Leather Boots + 1x Trailblazer's Scale Boots (7-11)",
                    type = "step",
                    minSkill = 7,
                    maxSkill = 11,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 30,
                        ["Adamant Scales"] = 30,
                    },
                },
                {
                    text = "1x Pioneer's Leather Tunic + 1x Trailblazer's Scale Vest + 1x Durable Pack (11-20)",
                    type = "step",
                    minSkill = 11,
                    maxSkill = 20,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 60,
                        ["Adamant Scales"] = 60,
                        ["Dense Hide"] = 1,
                    },
                },
                {
                    text = "1x Pioneer's Practiced Belt + 1x Trailblazer's Toughened Chainbelt (20-25)",
                    type = "step",
                    minSkill = 20,
                    maxSkill = 25,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 16,
                        ["Adamant Scales"] = 16,
                        ["Dense Hide"] = 2,
                        ["Lustrous Scaled Hide"] = 2,
                    },
                },
                {
                    text = "Unlock Specializations at skill 25. Pick Leather or Mail (matching your class). DON'T spend KP yet!",
                    type = "trainer",
                    minSkill = 25,
                    maxSkill = 25,
                    note = "",
                    materials = {},
                },
                {
                    text = "1x Pioneer's Practiced Gloves + 1x Trailblazer's Toughened Grips (25-31)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 31,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 16,
                        ["Adamant Scales"] = 16,
                        ["Dense Hide"] = 2,
                        ["Lustrous Scaled Hide"] = 2,
                    },
                },
                {
                    text = "1x Jeweler's Cover + 1x Protective Gloves (31-37)",
                    type = "step",
                    minSkill = 31,
                    maxSkill = 37,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 10,
                        ["Adamant Scales"] = 10,
                        ["Dense Hide"] = 2,
                        ["Lustrous Scaled Hide"] = 2,
                    },
                },
                {
                    text = "1x Alchemist's Hat + 1x Smithing Apron (37-41)",
                    type = "step",
                    minSkill = 37,
                    maxSkill = 41,
                    note = "",
                    materials = {
                        ["Adamant Scales"] = 10,
                        ["Resilient Leather"] = 0,
                        ["Dense Hide"] = 2,
                        ["Lustrous Scaled Hide"] = 2,
                    },
                },
                {
                    text = "1x Pioneer's Practiced Shoulderpads + 1x Trailblazer's Toughened Spikes (41-47)",
                    type = "step",
                    minSkill = 41,
                    maxSkill = 47,
                    note = "",
                    materials = {
                        ["Resilient Leather"] = 16,
                        ["Adamant Scales"] = 16,
                        ["Dense Hide"] = 2,
                        ["Lustrous Scaled Hide"] = 2,
                    },
                },
                {
                    text = "47-52: More leg armor + shoulder pieces",
                    type = "step",
                    minSkill = 47,
                    maxSkill = 52,
                    note = "",
                    materials = {},
                },
                {
                    text = "65-100: Spend KP (20pts Leather/Mail Armor → Bracers sub-spec). Craft Primal Molten bracers with Spark of Ingenuity.",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "Spark of Ingenuity from: DF campaign completion + Engine of Innovation questline.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Leatherworking",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Leather Specialization (Midnight)",
                    recommended = false,
                    note = "Leather armor quality and quantity.",
                },
                {
                    name = "Mail Specialization (Midnight)",
                    recommended = false,
                    note = "Mail armor focus.",
                },
                {
                    name = "Primordials",
                    recommended = true,
                    note = "Optional reagents, leg kits, specialty items. Not BoP — sell on AH.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. The First Craft sweep carries you from 7 to ~60 skill.",
                },
                {
                    text = "Patron/NPC Crafting Orders",
                    note = "Main source past 60. Especially for armor at Rank 4-5.",
                },
                {
                    text = "Treatise on Leatherworking",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "Unlock Specializations at skill 25. Check Midnight Leatherworking Spec Guide for KP builds.",
                    type = "trainer",
                    minSkill = 25,
                    maxSkill = 25,
                    note = "Second spec at 50, third at 75. EQUIP Hideworker's Cover once you craft it.",
                    materials = {},
                },
                {
                    text = "60-100: Patron/NPC Crafting Orders OR craft armor pieces to reach Rank 4 guaranteed crafts",
                    type = "step",
                    minSkill = 60,
                    maxSkill = 100,
                    note = "No rush unless you want guaranteed gold-quality armor without Concentration. Patron Orders are RNG but often include cheap options. Stop here and use Patron Orders if not crafting armor seriously.",
                    materials = {},
                },
            },
        },
        Shadowlands = {
            profession = "Leatherworking",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Leatherworking from Tanner Au'qil in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "50x Heavy Desolate Leather (1-30)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 30,
                    note = "",
                    materials = {
                        ["Desolate Leather"] = 300,
                    },
                },
                {
                    text = "25x Stonebound Armor Kit (30-55)",
                    type = "step",
                    minSkill = 30,
                    maxSkill = 55,
                    note = "",
                    materials = {
                        ["Heavy Desolate Leather"] = 50,
                        ["Desolate Leather"] = 50,
                    },
                },
                {
                    text = "25x Shadowlands Armor Kit (55-80)",
                    type = "step",
                    minSkill = 55,
                    maxSkill = 80,
                    note = "",
                    materials = {
                        ["Heavy Desolate Leather"] = 50,
                        ["Pallid Bone"] = 25,
                    },
                },
                {
                    text = "25x Crafter's Mark I (80-100)",
                    type = "step",
                    minSkill = 80,
                    maxSkill = 100,
                    note = "",
                    materials = {
                        ["Heavy Desolate Leather"] = 25,
                        ["Elethium Ore"] = 25,
                    },
                },
                {
                    text = "15x Shadowghast Boots (100-115)",
                    type = "step",
                    minSkill = 100,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Heavy Desolate Leather"] = 60,
                        ["Callous Hide"] = 15,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Leatherworking",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Leather Specialization",
                    recommended = false,
                    note = "Leather armor and kits. Good for mail/leather wearing classes.",
                },
                {
                    name = "Mail Specialization",
                    recommended = false,
                    note = "Mail armor focus.",
                },
                {
                    name = "Primordial Crafting",
                    recommended = true,
                    note = "Leg Armor Kits and Optional Reagents. Not BoP — sellable on AH. Best for gold income.",
                },
                {
                    name = "Tactical Gear",
                    recommended = false,
                    note = "Specialty pieces including Hideseeker's Pack and bags.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Craft one leather AND one mail piece when possible.",
                },
                {
                    text = "Leg Armor Kits",
                    note = "Stormbound and Defender Kits sell consistently. Non-BoP, craft for profit.",
                },
                {
                    text = "Optional Reagents",
                    note = "Writhing Armor Banding, Storm-Touched Weapon Wrap, etc. Non-BoP.",
                },
                {
                    text = "Treatise on Leatherworking",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "24 KP total from one-time treasures (e.g. Leatherworker's Tanning Oil).",
                },
                {
                    text = "Weekly Quests & Patrons",
                    note = "Complete Dornogal weeklies and Patron Orders for ~15 KP/week.",
                },
            },
            steps = {
                {
                    text = "1x Spelunker's Practiced Sash + 1x Tracker's Toughened Girdle + 1x Spelunker's Practiced Mitts (25-35, make Sash/Girdle first — yellow at 30)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 35,
                    note = "",
                    materials = {
                        ["Stormcharged Leather"] = 85,
                        ["Gloom Chitin"] = 50,
                    },
                },
                {
                    text = "1x Gemcutter's Apron + 1x Apothecary's Cap + 1x Steelsmith's Apron (Profession accessories, 35-44)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 44,
                    note = "",
                    materials = {
                        ["Stormcharged Leather"] = 20,
                        ["Gloom Chitin"] = 20,
                        ["Thunderous Hide"] = 2,
                        ["Sunless Carapace"] = 1,
                    },
                },
                {
                    text = "1x Tracker's Toughened Shoulderguards + 1x Spelunker's Practiced Shoulders (44-50)",
                    type = "step",
                    minSkill = 44,
                    maxSkill = 50,
                    note = "",
                    materials = {
                        ["Gloom Chitin"] = 30,
                        ["Stormcharged Leather"] = 30,
                        ["Sunless Carapace"] = 1,
                        ["Thunderous Hide"] = 1,
                    },
                },
                {
                    text = "1x Tracker's Toughened Links + 1x Spelunker's Practiced Britches (50-56)",
                    type = "step",
                    minSkill = 50,
                    maxSkill = 56,
                    note = "",
                    materials = {
                        ["Gloom Chitin"] = 30,
                        ["Stormcharged Leather"] = 30,
                        ["Sunless Carapace"] = 1,
                        ["Thunderous Hide"] = 1,
                    },
                },
                {
                    text = "91-100: NPC Crafting Orders for profession equipment or epic armor (Spark Recipes)",
                    type = "step",
                    minSkill = 91,
                    maxSkill = 100,
                    note = "",
                    materials = {},
                },
            },
        },
    },
    Tailoring = {
        Dragonflight = {
            profession = "Tailoring",
            tier = "Dragonflight",
            trainerZone = "Valdrakken (Dragon Isles)",
            maxSkill = 100,
            specializations = {
                {
                    name = "Garmentcrafting",
                    recommended = true,
                    note = "Pick first. Don't spend KP until 65. Need 15pts for Surveyor's Seasoned Expedition Tent (filler 65+).",
                },
                {
                    name = "Clothworking",
                    recommended = false,
                    note = "Bolt quality and cloth procs.",
                },
                {
                    name = "Specialty Textiles",
                    recommended = false,
                    note = "Specialty bags and bolts.",
                },
                {
                    name = "Embroidery",
                    recommended = false,
                    note = "Spellthread and embellishments.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Guide captures First Crafts throughout.",
                },
                {
                    text = "Spark of Ingenuity",
                    note = "Required for Primal Infusion cloth gear (65-100). BoP.",
                },
                {
                    text = "Dragon Shard of Knowledge",
                    note = "5 KP. Dragon Isles open world content.",
                },
                {
                    text = "Weekly patron quests",
                    note = "Dragon Isles Knowledge from Valdrakken crafting orders.",
                },
            },
            steps = {
                {
                    text = "30x Dragon Isles Unravelling on 150x Tattered Wildercloth (1-15)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 15,
                    note = "",
                    materials = {
                        ["Tattered Wildercloth"] = 150,
                    },
                },
                {
                    text = "1x Surveyor's Cloth Robe + 1x Wildercloth Gardening Hat (15-21)",
                    type = "step",
                    minSkill = 15,
                    maxSkill = 21,
                    note = "",
                    materials = {
                        Wildercloth = 13,
                        ["Spool of Wilderthread"] = 9,
                        Hochenblume = 5,
                    },
                },
                {
                    text = "1x Wildercloth Chef's Hat + 1x Surveyor's Tailored Cloak (21-27)",
                    type = "step",
                    minSkill = 21,
                    maxSkill = 27,
                    note = "",
                    materials = {
                        Wildercloth = 13,
                        ["Spool of Wilderthread"] = 10,
                    },
                },
                {
                    text = "Unlock Specializations at skill 25. Pick Garmentcrafting. DON'T spend KP until 65!",
                    type = "trainer",
                    minSkill = 25,
                    maxSkill = 25,
                    note = "",
                    materials = {},
                },
                {
                    text = "1x Wildercloth Fishing Cap (27-30)",
                    type = "step",
                    minSkill = 27,
                    maxSkill = 30,
                    note = "",
                    materials = {
                        Wildercloth = 5,
                        ["Spool of Wilderthread"] = 4,
                    },
                },
                {
                    text = "1x Surveyor's Seasoned Cord + 2x Wildercloth Alchemist's Robe (30-36)",
                    type = "step",
                    minSkill = 30,
                    maxSkill = 36,
                    note = "",
                    materials = {
                        Wildercloth = 20,
                        ["Spool of Wilderthread"] = 14,
                    },
                },
                {
                    text = "1x Surveyor's Seasoned Gloves + 1x Wildercloth Enchanter's Hat (36-40)",
                    type = "step",
                    minSkill = 36,
                    maxSkill = 40,
                    note = "",
                    materials = {
                        Wildercloth = 11,
                        ["Spool of Wilderthread"] = 10,
                        ["Chromatic Dust"] = 3,
                    },
                },
                {
                    text = "3x Surveyor's Seasoned Shoulders (40-46, alternative: Wildercloth Bags if you need them)",
                    type = "step",
                    minSkill = 40,
                    maxSkill = 46,
                    note = "",
                    materials = {
                        Wildercloth = 24,
                        ["Spool of Wilderthread"] = 18,
                    },
                },
                {
                    text = "7x Wildercloth Bolt, 1x Abrasive Polishing Cloth, 2x Surveyor's Seasoned Pants (46-51)",
                    type = "step",
                    minSkill = 46,
                    maxSkill = 51,
                    note = "",
                    materials = {
                        Wildercloth = 75,
                        ["Spool of Wilderthread"] = 20,
                        ["Fractured Glass"] = 3,
                    },
                },
                {
                    text = "1x Surveyor's Seasoned Hood + 2x Vibrant Wildercloth Bolt + 1x Vibrant Spellthread (51-54)",
                    type = "step",
                    minSkill = 51,
                    maxSkill = 54,
                    note = "",
                    materials = {
                        Wildercloth = 10,
                        ["Spool of Wilderthread"] = 7,
                        ["Vibrant Shard"] = 3,
                        ["Wildercloth Bolt"] = 6,
                    },
                },
                {
                    text = "65-100: If Renown 15 Dragonscale Expedition: craft Surveyor's Expedition Tent (15pts Garmentcrafting first). Otherwise: Spark of Ingenuity for Primal Infusion gear.",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 100,
                    note = "Method 1 (Renown 15): Put 15pts Garmentcrafting → Tent recipe → craft many tents. Method 2: DF campaign + Engine of Innovation for Sparks. Both reach 100.",
                    materials = {},
                },
            },
        },
        Midnight = {
            profession = "Tailoring",
            tier = "Midnight",
            trainerZone = "Quel'Thalas",
            maxSkill = 100,
            specializations = {
                {
                    name = "Loom of the Ages (Midnight)",
                    recommended = false,
                    note = "Bolt and cloth quality.",
                },
                {
                    name = "From Dawn Until Dusk (Midnight)",
                    recommended = true,
                    note = "Unlocks daily Bolt CDs (Dusk/Dawn thread). Critical for 50+ crafting.",
                },
                {
                    name = "Woven Arcana (Midnight)",
                    recommended = false,
                    note = "Bags, spellthreads, optional reagents.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Catch all First Crafts at 40-45 even on grey recipes.",
                },
                {
                    text = "Daily Bolt Cooldowns",
                    note = "Unlock via From Dawn Until Dusk spec. Bolt CDs provide Dusk/Dawn thread for end-game crafting.",
                },
                {
                    text = "Patron/NPC Work Orders",
                    note = "Consistent end-game source past 50. Slow but steady.",
                },
                {
                    text = "Treatise on Tailoring",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
            },
            steps = {
                {
                    text = "40-45: Filter 'First Craft Bonus' and craft all available recipes (many will be grey but give 1 KP each)",
                    type = "step",
                    minSkill = 40,
                    maxSkill = 45,
                    note = "EQUIP Bright Linen Tailoring Robe when you craft it. Note: Reagent Satchel/Backpack reagent (Fantastic Fur) pricing unknown — craft if cheap.",
                    materials = {},
                },
                {
                    text = "50-100 — SLOW METHOD (cheaper): Daily Bolt CDs + Patron/NPC Work Orders to trickle to 100",
                    type = "step",
                    minSkill = 50,
                    maxSkill = 100,
                    note = "Slow method: unlock Bolt CDs via From Dawn Until Dusk spec, craft daily. Fill with Patron Orders. Low cost but takes weeks.",
                    materials = {},
                },
                {
                    text = "50-100 — FAST METHOD: Spam craft armor pieces (Imbued Linen gear) using batch orders to rush to 100",
                    type = "step",
                    minSkill = 50,
                    maxSkill = 100,
                    note = "Fast method requires much more Bright Linen and Imbued Bolts. Profitable if gear sells on AH.",
                    materials = {},
                },
            },
        },
        Shadowlands = {
            profession = "Tailoring",
            tier = "Shadowlands",
            trainerZone = "Oribos (Hall of Shapes)",
            maxSkill = 115,
            specializations = {},
            knowledgeSources = {},
            steps = {
                {
                    text = "Learn Shadowlands Tailoring from Weaver Au'rikku in Oribos.",
                    type = "trainer",
                    minSkill = 0,
                    maxSkill = 1,
                    note = "",
                    materials = {},
                },
                {
                    text = "45x Shrouded Cloth Bolt (1-30)",
                    type = "step",
                    minSkill = 1,
                    maxSkill = 30,
                    note = "",
                    materials = {
                        ["Shrouded Cloth"] = 225,
                    },
                },
                {
                    text = "15x Wrapped Package (30-45)",
                    type = "step",
                    minSkill = 30,
                    maxSkill = 45,
                    note = "",
                    materials = {
                        ["Shrouded Cloth Bolt"] = 15,
                    },
                },
                {
                    text = "20x Shadowlace Coat (45-65)",
                    type = "step",
                    minSkill = 45,
                    maxSkill = 65,
                    note = "",
                    materials = {
                        ["Shrouded Cloth Bolt"] = 60,
                        ["Enchanted Shadowcoave"] = 20,
                    },
                },
                {
                    text = "20x Shadowlace Pants (65-85)",
                    type = "step",
                    minSkill = 65,
                    maxSkill = 85,
                    note = "",
                    materials = {
                        ["Shrouded Cloth Bolt"] = 60,
                        ["Enchanted Shadowcoave"] = 20,
                    },
                },
                {
                    text = "30x Heavy Desolate Cloak (85-115, green at 110)",
                    type = "step",
                    minSkill = 85,
                    maxSkill = 115,
                    note = "",
                    materials = {
                        ["Shrouded Cloth Bolt"] = 90,
                    },
                },
            },
        },
        ["The War Within"] = {
            profession = "Tailoring",
            tier = "The War Within",
            trainerZone = "Dornogal",
            maxSkill = 100,
            specializations = {
                {
                    name = "Loom of the Ages",
                    recommended = false,
                    note = "Cloth and bolt quality improvements.",
                },
                {
                    name = "From Dawn Until Dusk",
                    recommended = true,
                    note = "PICK as 3rd spec! Daily bolt Cooldowns (Dusk/Dawn) unlock here — cheap 50-91 path.",
                },
                {
                    name = "Woven Arcana",
                    recommended = false,
                    note = "Bags, embroidery, and spellthreads.",
                },
                {
                    name = "Dreamcloth Expertise",
                    recommended = false,
                    note = "Epic crafted gear focus.",
                },
            },
            knowledgeSources = {
                {
                    text = "First Craft Bonus",
                    note = "1 KP per unique recipe. Craft each cloth piece, bag, and spellthread type once.",
                },
                {
                    text = "Daily Duskweave/Dawnweave Bolt CDs",
                    note = "Unlocked at skill 50 via From Dawn Until Dusk spec. Main source of thread for end-game crafts.",
                },
                {
                    text = "Embroidery Thread (48-65)",
                    note = "Weavercloth Embroidery Thread stays yellow and uses Writhing Samples.",
                },
                {
                    text = "Treatise on Tailoring",
                    note = "10 KP. Buy from Inscription AH or alt.",
                },
                {
                    text = "Khaz Algar Treasures",
                    note = "24 KP total from one-time treasures (e.g. Tailor's Enchanted Needle).",
                },
                {
                    text = "Weekly Quests & Patrons",
                    note = "Complete Dornogal weeklies and Patron Orders for ~15 KP/week.",
                },
            },
            steps = {
                {
                    text = "4x Exquisite Weavercloth Bolt (25-29)",
                    type = "step",
                    minSkill = 25,
                    maxSkill = 29,
                    note = "",
                    materials = {
                        ["Mosswool Thread"] = 8,
                        ["Weavercloth Bolt"] = 8,
                        ["Storm Dust"] = 4,
                    },
                },
                {
                    text = "1x Pioneer's Perfected Hood (make FIRST, turns yellow at 40), 1x Perfected Gloves (37-39), 3x Perfected Mantle (39-45)",
                    type = "step",
                    minSkill = 35,
                    maxSkill = 45,
                    note = "",
                    materials = {
                        ["Mosswool Thread"] = 16,
                        ["Weavercloth Bolt"] = 11,
                    },
                },
                {
                    text = "91-100: NPC Crafting Orders or spam daily Duskweave/Dawnweave Bolt CDs (unlocked via From Dawn Until Dusk spec at 50)",
                    type = "step",
                    minSkill = 91,
                    maxSkill = 100,
                    note = "Epic gear (Woven gear with Spark) also viable. Cloth daily bolt CDs provide thread for end-game crafting.",
                    materials = {},
                },
            },
        },
    },
}

for k, v in pairs(data) do
    M.TrainingData[k] = v
end
