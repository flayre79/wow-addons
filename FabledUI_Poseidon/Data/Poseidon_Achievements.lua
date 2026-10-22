local P = _G.FabledUI_Poseidon
if not P then return end

FishIntel_Achievements = FishIntel_Achievements or {
    TWW = { 40539, 19415, 40476, 40480, 40484, 40485, 40487, 40489, 40490, 40491, 40494, 40495, 40498, 40499, 40500, 40501, 40502, 40503 },
    DF = { 16632 },
    SL = { 14333 },
    BFA = { 12753, 12754, 13502, 13489 },
    LEGION = { 10594, 10596, 10597, 10598 },
}

FishIntel_AllFishingAchievements = FishIntel_AllFishingAchievements or {
    { id = 40539, name = "The Derby Dash", reward = "Kah, Legend of the Deep" },
    { id = 19415, name = "Algari Fisherman", reward = nil },
    { id = 16632, name = "Dragon Isles Fisherman", reward = nil },
    { id = 14333, name = "Shadowlands Fisherman", reward = nil },
    { id = 13502, name = "Secret Fish and Where to Find Them", reward = "Hyper-Compressed Ocean" },
}

FishIntel_FishAchievements = FishIntel_FishAchievements or {}
