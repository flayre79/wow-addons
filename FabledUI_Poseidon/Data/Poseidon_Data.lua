local P = _G.FabledUI_Poseidon
if not P then return end

FishIntel_PoolFishIndex = FishIntel_PoolFishIndex or {}
FishIntel_FishMeta = FishIntel_FishMeta or {}

local midnightPools = {
    ["Bubbling Bloom"] = { "Arcane Wyrmfish", "Lynxfish", "Sin'dorei Swarmer", "Restored Songfish", "Shimmer Spinefish", "Eversong Trout" },
    ["Bloom Swarm"] = { "Restored Songfish", "Shimmer Spinefish" },
    ["Sunwell Swarm"] = { "Arcane Wyrmfish", "Lynxfish", "Sin'dorei Swarmer", "Restored Songfish", "Shimmer Spinefish", "Sunwell Fish", "Eversong Trout" },
    ["Blossoming Torrent"] = { "Arcane Wyrmfish", "Restored Songfish", "Shimmer Spinefish", "Sunwell Fish", "Tender Lumifin" },
    ["Hunter Surge"] = { "Gore Guppy", "Blood Hunter" },
    ["Surface Ripple"] = { "Gore Guppy", "Lynxfish", "Root Crab", "Sin'dorei Swarmer", "Blood Hunter", "Fungalskin Pike", "Lucky Loa" },
    ["Obscured School"] = { "Root Crab", "Fungalskin Pike", "Lucky Loa" },
    ["Lashing Waves"] = { "Bloomtail Minnow", "Fungalskin Pike" },
    ["Viscous Void"] = { "Blood Hunter", "Hollow Grouper", "Null Voidfish", "Ominous Octopus", "Shimmersiren", "Warping Wise" },
    ["Oceanic Vortex"] = { "Blood Hunter", "Hollow Grouper", "Null Voidfish", "Ominous Octopus", "Shimmersiren", "Warping Wise" },
    ["Careless Cargo"] = { "Treasure", "Lure Recipes", "Line Components" },
    ["Lost Treasures"] = { "Treasure", "Rare Recipes", "Line Components" },
    -- 12.1 Coiled Isle. Only Torrential Gorgerswarm contains a LooksLikeFishingPool
    -- keyword, so the rest are recognised by exact name or not at all.
    ["Willow Sea"] = { "Polluted Puffer", "Spotted Killifish", "Dirty Darter", "Toxic Tlhapi" },
    ["Bubbling Beryl"] = { "Sulfurous Sludgefish", "Dirty Darter", "Toxic Tlhapi", "Ula'tek Snakehead" },
    ["Vile Venom"] = { "Many-Eyed Flounder", "Twin-Headed Snipefish" },
    ["Cursed Oddity"] = { "Oozing Goby", "Giggling Skull", "Grotesque Sturgeon", "Loathsome Anglerfish", "Twin-Headed Snipefish" },
    ["Torrential Gorgerswarm"] = { "Coiled Stargorger" },
    ["Abyssal Swirl"] = { "Oozing Goby", "Ephemeral Star Ooze" },
}

for poolName, fishList in pairs(midnightPools) do
    FishIntel_PoolFishIndex[poolName] = FishIntel_PoolFishIndex[poolName] or fishList
end

local fishMeta = {
    ["Blood Hunter"] = { quality = "Uncommon", note = "May spawn a hostile spirit unless protected by Amani Angler's Ward." },
    ["Warping Wise"] = { quality = "Rare", note = "Teleports you to a random Midnight location." },
    ["Null Voidfish"] = { quality = "Rare", note = "Key lure / transmute ingredient and high-value Voidstorm target." },
    ["Ominous Octopus"] = { quality = "Rare", note = "Strong lure demand for skinners." },
    ["Eversong Trout"] = { quality = "Rare", note = "Used in Quel'dorei Medley feast variant." },
}

for fishName, meta in pairs(fishMeta) do
    FishIntel_FishMeta[fishName] = FishIntel_FishMeta[fishName] or meta
end

_G.FishIntel_ZoneOpenWaterFish = _G.FishIntel_ZoneOpenWaterFish or {
    ["Eversong Woods"] = { "Arcane Wyrmfish", "Lynxfish", "Sin'dorei Swarmer", "Restored Songfish", "Shimmer Spinefish", "Sunwell Fish", "Eversong Trout" },
    ["Silvermoon City"] = { "Arcane Wyrmfish", "Lynxfish", "Sin'dorei Swarmer", "Restored Songfish", "Shimmer Spinefish", "Sunwell Fish", "Eversong Trout" },
    ["Zul'Aman"] = { "Gore Guppy", "Lynxfish", "Root Crab", "Sin'dorei Swarmer", "Blood Hunter", "Fungalskin Pike", "Lucky Loa" },
    ["Harandar"] = { "Arcane Wyrmfish", "Root Crab", "Bloomtail Minnow", "Fungalskin Pike", "Restored Songfish", "Shimmer Spinefish", "Tender Lumifin" },
    ["Voidstorm"] = { "Blood Hunter", "Hollow Grouper", "Null Voidfish", "Ominous Octopus", "Shimmersiren", "Warping Wise" },
    ["The Coiled Isle"] = { "Spotted Killifish", "Dirty Darter", "Toxic Tlhapi", "Beached Asteroid", "Bulbous Benthos", "Pristine Polygon" },
}

_G.FishIntel_PoolZoneIndex = _G.FishIntel_PoolZoneIndex or {
    ["Bubbling Bloom"] = { "Eversong Woods" },
    ["Bloom Swarm"] = { "Eversong Woods", "Harandar" },
    ["Sunwell Swarm"] = { "Eversong Woods" },
    ["Blossoming Torrent"] = { "Eversong Woods", "Harandar" },
    ["Hunter Surge"] = { "Zul'Aman" },
    ["Surface Ripple"] = { "Zul'Aman", "Harandar" },
    ["Obscured School"] = { "Zul'Aman", "Harandar" },
    ["Lashing Waves"] = { "Zul'Aman", "Harandar" },
    ["Viscous Void"] = { "Voidstorm" },
    ["Oceanic Vortex"] = { "Voidstorm" },
    ["Careless Cargo"] = { "Eversong Woods", "Zul'Aman", "Harandar", "Voidstorm" },
    ["Lost Treasures"] = { "Eversong Woods", "Zul'Aman", "Harandar", "Voidstorm" },
    ["Willow Sea"] = { "The Coiled Isle" },
    ["Bubbling Beryl"] = { "The Coiled Isle" },
    ["Vile Venom"] = { "The Coiled Isle" },
    ["Cursed Oddity"] = { "The Coiled Isle" },
    ["Torrential Gorgerswarm"] = { "The Coiled Isle" },
    ["Abyssal Swirl"] = { "The Coiled Isle" },
}
