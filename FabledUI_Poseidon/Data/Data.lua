local P = _G.FabledUI_Poseidon
if not P then return end

P.Data = P.Data or {}

P.Data.DERBY_BUFF = "Derby Dasher"
P.Data.MARK_KEYWORD = "Mereldar Derby Mark"

P.Data.Midnight = {
    intro = {
        "Buy and learn Angler's Guide from the fishing supply vendor near the trainer to unlock minimap pool tracking.",
        "You can level Fishing to 300 in any Midnight zone, but open-water progression feels smoother when you stay in the earlier zones a bit longer.",
        "Pool fishing ignores most zone-skill friction, but it is slower if your only goal is raw skill-ups.",
        "Voidstorm has no normal open water. Natural fishing there is built around rare Oceanic Vortex bubbles and Viscous Void pools.",
    },
    skillBrackets = {
        { zone = "Eversong Woods / Silvermoon City", minSkill = 1, maxSkill = 150, note = "Best early bracket. Safe place to climb before the jungle nonsense begins." },
        { zone = "Zul'Aman", minSkill = 150, maxSkill = 225, note = "Good transition zone once Eversong stops being generous." },
        { zone = "Harandar", minSkill = 225, maxSkill = 300, note = "Best late bracket for steady open-water progress." },
        { zone = "Pool Fishing", minSkill = 1, maxSkill = 300, note = "Works at any skill, slower for leveling, still great for targeted fish." },
    },
    zones = {
        ["Eversong Woods"] = {
            recommended = "1-150",
            notes = {
                "Strong starter zone for both open water and early pools.",
                "Great source for Sunwell-themed fish tables.",
            },
            pools = { "Bubbling Bloom", "Bloom Swarm", "Sunwell Swarm", "Blossoming Torrent" },
        },
        ["Zul'Aman"] = {
            recommended = "150-225",
            notes = {
                "Hunter Surge and Surface Ripple support both routine catches and Blood Hunter-style drama.",
                "Amani Angler's Ward is especially helpful here if Blood Hunter spirits annoy you.",
            },
            pools = { "Hunter Surge", "Surface Ripple", "Obscured School", "Lashing Waves" },
        },
        ["Harandar"] = {
            recommended = "225-300",
            notes = {
                "Best late progression zone.",
                "Important for Bloomtail Minnow, Tender Lumifin, and several lure-feeding fish." ,
            },
            pools = { "Lashing Waves", "Obscured School", "Bloom Swarm", "Blossoming Torrent" },
        },
        ["Voidstorm"] = {
            recommended = "Pools only",
            notes = {
                "No normal open water.",
                "Oceanic Vortex bubbles are rare, long-lived, and the best targeted source for Null Voidfish and Ominous Octopus.",
                "These do not behave like normal trackable Fishing Pool nodes in every case, so manual notes matter here.",
            },
            pools = { "Viscous Void", "Oceanic Vortex" },
        },
        ["The Coiled Isle"] = {
            recommended = "Patch 12.1",
            notes = {
                "Off the coast of Zul'Aman. None of its pool names contain a usual pool word, so they only register by exact name.",
                "Cursed fish only bite in cursed waters after a Curse Surge.",
                "Angler of the Coiled Isle wants 14 fish, Cursed Oddities included.",
            },
            pools = { "Willow Sea", "Bubbling Beryl", "Vile Venom", "Cursed Oddity" },
        },
    },
    fish = {
        common = {
            { name = "Arcane Wyrmfish", zones = { "Eversong Woods", "Harandar" }, pools = { "Bubbling Bloom", "Sunwell Swarm", "Blossoming Torrent" } },
            { name = "Gore Guppy", zones = { "Zul'Aman" }, pools = { "Hunter Surge", "Surface Ripple" } },
            { name = "Lynxfish", zones = { "Eversong Woods", "Zul'Aman" }, pools = { "Bubbling Bloom", "Sunwell Swarm", "Surface Ripple" } },
            { name = "Root Crab", zones = { "Zul'Aman", "Harandar" }, pools = { "Obscured School", "Surface Ripple" } },
            { name = "Sin'dorei Swarmer", zones = { "Eversong Woods", "Zul'Aman" }, pools = { "Bubbling Bloom", "Sunwell Swarm", "Surface Ripple" } },
            { name = "Beached Asteroid", zones = { "The Coiled Isle" }, pools = {} },
            { name = "Dirty Darter", zones = { "The Coiled Isle" }, pools = { "Willow Sea", "Bubbling Beryl" } },
            { name = "Polluted Puffer", zones = { "The Coiled Isle" }, pools = { "Willow Sea" } },
            { name = "Spotted Killifish", zones = { "The Coiled Isle" }, pools = { "Willow Sea" } },
            { name = "Toxic Tlhapi", zones = { "The Coiled Isle" }, pools = { "Willow Sea", "Bubbling Beryl" } },
        },
        uncommon = {
            { name = "Blood Hunter", zones = { "Zul'Aman", "Voidstorm" }, pools = { "Surface Ripple", "Hunter Surge", "Viscous Void", "Oceanic Vortex" }, special = "Can spawn a hostile spirit. Amani Angler's Ward suppresses that nonsense for 30 minutes." },
            { name = "Bloomtail Minnow", zones = { "Harandar" }, pools = { "Lashing Waves" } },
            { name = "Fungalskin Pike", zones = { "Zul'Aman", "Harandar" }, pools = { "Lashing Waves", "Obscured School", "Surface Ripple" } },
            { name = "Restored Songfish", zones = { "Eversong Woods", "Harandar" }, pools = { "Bloom Swarm", "Bubbling Bloom", "Sunwell Swarm", "Blossoming Torrent" } },
            { name = "Shimmer Spinefish", zones = { "Eversong Woods", "Harandar" }, pools = { "Bloom Swarm", "Bubbling Bloom", "Sunwell Swarm", "Blossoming Torrent" } },
            { name = "Shimmersiren", zones = { "Voidstorm" }, pools = { "Viscous Void", "Oceanic Vortex" } },
            { name = "Sunwell Fish", zones = { "Eversong Woods" }, pools = { "Sunwell Swarm", "Blossoming Torrent" } },
            { name = "Tender Lumifin", zones = { "Harandar" }, pools = { "Blossoming Torrent" } },
            { name = "Bulbous Benthos", zones = { "The Coiled Isle" }, pools = {} },
            { name = "Sulfurous Sludgefish", zones = { "The Coiled Isle" }, pools = { "Bubbling Beryl" } },
        },
        rare = {
            { name = "Eversong Trout", zones = { "Eversong Woods" }, pools = { "Sunwell Swarm", "Bubbling Bloom" } },
            { name = "Hollow Grouper", zones = { "Voidstorm" }, pools = { "Viscous Void", "Oceanic Vortex" } },
            { name = "Lucky Loa", zones = { "Zul'Aman" }, pools = { "Obscured School", "Surface Ripple" } },
            { name = "Null Voidfish", zones = { "Voidstorm" }, pools = { "Viscous Void", "Oceanic Vortex" } },
            { name = "Ominous Octopus", zones = { "Voidstorm" }, pools = { "Viscous Void", "Oceanic Vortex" } },
            { name = "Warping Wise", zones = { "Voidstorm" }, pools = { "Viscous Void", "Oceanic Vortex" }, special = "Teleports you to a random location in a random Midnight zone." },
            { name = "Blightswarmer", zones = { "The Coiled Isle" }, pools = {}, special = "Cursed waters only, after a Curse Surge." },
            { name = "Coiled Stargorger", zones = { "The Coiled Isle" }, pools = { "Torrential Gorgerswarm" }, special = "Only from a Torrential Gorgerswarm." },
            { name = "Pristine Polygon", zones = { "The Coiled Isle" }, pools = {} },
            { name = "Ula'tek Snakehead", zones = { "The Coiled Isle" }, pools = { "Bubbling Beryl" } },
        },
        cursed = {
            { name = "Giggling Skull", zones = { "The Coiled Isle" }, pools = { "Cursed Oddity" } },
            { name = "Grotesque Sturgeon", zones = { "The Coiled Isle" }, pools = { "Cursed Oddity" } },
            { name = "Loathsome Anglerfish", zones = { "The Coiled Isle" }, pools = { "Cursed Oddity" } },
            { name = "Many-Eyed Flounder", zones = { "The Coiled Isle" }, pools = { "Vile Venom" } },
            { name = "Oozing Goby", zones = { "The Coiled Isle" }, pools = { "Cursed Oddity", "Abyssal Swirl" } },
            { name = "Twin-Headed Snipefish", zones = { "The Coiled Isle" }, pools = { "Cursed Oddity", "Vile Venom" } },
            { name = "Blackened Sludgefish", zones = { "The Coiled Isle" }, pools = {}, special = "Cursed waters only, after a Curse Surge." },
            { name = "Explosive Tlhapi", zones = { "The Coiled Isle" }, pools = {}, special = "Cursed waters only, after a Curse Surge." },
            { name = "Pustulent Blightswarmer", zones = { "The Coiled Isle" }, pools = {}, special = "Cursed waters only, after a Curse Surge." },
        },
    },
    specialPools = {
        { name = "Careless Cargo", contains = "Treasure", notes = "Can contain lure recipes, line components, motes, and general treasure." },
        { name = "Lost Treasures", contains = "Treasure", notes = "Very rare. Similar to Careless Cargo. Reported empty outcomes may be bug-related." },
        { name = "Viscous Void", contains = "Voidstorm rare fish", notes = "Best general target for Null Voidfish and Ominous Octopus." },
        { name = "Oceanic Vortex", contains = "Voidstorm rare fish", notes = "Rare bubble pool, long duration, poor minimap visibility, excellent value." },
        { name = "Torrential Gorgerswarm", contains = "Coiled Stargorger", notes = "The only source of Coiled Stargorger, an Angler of the Coiled Isle fish." },
        { name = "Abyssal Swirl", contains = "Oozing Goby, Ephemeral Star Ooze", notes = "Made from another Coiled Isle pool with an Eerie Bauble from Second Mate Sluggs. The Star Ooze starts the Three-Eyed Fish questline." },
    },
    valueNotes = {
        "Most feast and personal food recipes have cheaper alternatives, so unique fish are often more valuable as market items than as personal cooking inputs.",
        "Skinning lures are likely the strongest AH sink because they have no herb replacement path.",
        "Majestic Voidstorm Lure uses Ominous Octopus. Grand Beast Lure uses Null Voidfish.",
        "School of Gems transmute consumes Fungalskin Pike and Null Voidfish, which can spike demand.",
    },
    items = {
        "Aquarius Bloom turns any fishing pool into a Bloom Swarm.",
        "An Angler's Deep Dive gives +10 Midnight Fishing skill and can appear in treasure pools and Patient Treasures.",
        "Angler's Anomaly creates an Oceanic Vortex pool anywhere you want and lasts longer than natural spawns.",
        "Midnight Angler's Grand Line doubles treasure drops after completing the Bloomline and Glimmerline combine chains.",
    },
}
