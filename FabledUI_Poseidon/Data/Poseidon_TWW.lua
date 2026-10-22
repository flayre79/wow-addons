local P = _G.FabledUI_Poseidon
if not P then return end

FishIntel_AllTWWFish = FishIntel_AllTWWFish or {
    "Nibbling Minnow",
    "Dornish Pike",
    "Quiet River Bass",
    "Dilly-Dally Dace",
    "Regal Dottyback",
    "Bismuth Bitterling",
    "Whispering Stargazer",
    "Crystalline Sturgeon",
    "Specular Rainbowfish",
    "Sanguine Dogfish",
    "Bloody Perch",
    "Roaring Anglerseeker",
    "Spiked Sea Raven",
    "Kaheti Slum Shark",
    "Arathor Hammerfish",
    "Queen's Lurefish",
    "Pale Huskfish",
}

FishIntel_TWW_DerbyRotation = FishIntel_TWW_DerbyRotation or {
    [83529] = { "Bismuth Bitterling", "Whispering Stargazer", "Regal Dottyback" },
    [83530] = { "Bloody Perch", "Roaring Anglerseeker", "Spiked Sea Raven" },
    [83531] = { "Dilly-Dally Dace", "Dornish Pike", "Kaheti Slum Shark" },
    [83532] = { "Crystalline Sturgeon", "Specular Rainbowfish", "Sanguine Dogfish" },
    [82778] = { "Nibbling Minnow", "Arathor Hammerfish", "Queen's Lurefish" },
}
