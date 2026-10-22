-- FabledUI_Crafty/PKT.lua
--
-- PKT Module — wraps Crafty's profession-knowledge treasure features
-- (auto-supertrack on vignette match, treasure-quest set, location
-- waypoints) under a togglable umbrella separate from the broader
-- knowledge tracking (which lives in M.MKPT).
--
-- Donor: .sample-addons/ProfessionKnowledgeTreasures (1,448 LOC across
--   PKT_Main / PKT_Data / PKT_UI). The donor's PKT_Data carries Midnight
--   treasure entries already partially imported into our slim
--   FabledUI_Crafty_Data/KnowledgeData.lua MidnightTreasures table.
--
-- What's wired today (gated by this toggle):
--   - VIGNETTES_UPDATED auto-supertrack (M.KnowledgeVignettes)
--   - Midnight treasure quest set + zone constants (KnowledgeData)
--
-- What's pending port from PKT (queued for follow-up):
--   - Sequential "next nearest treasure in zone" router with /pkt next
--   - TomTom-aware waypoint chain across multiple treasures
--   - Minimap pin overlay for treasure positions (treasure_minimap_icon_32.tga)
--   - Per-character "claimed" state (so we skip treasures you already grabbed)
--   - PKT_Data.lua bulk import of remaining treasure coordinates
--
-- Public API:
--   M.PKT:IsEnabled()
--   M.PKT:SetEnabled(bool)

local M = _G.FabledUI_Crafty
if not M then return end

M.PKT = M.PKT or {}
local PKT = M.PKT

PKT.VERSION = "0.1.0"

function PKT:IsEnabled()
    if not M.settings then return true end
    return M.settings.pktModuleEnabled ~= false
end

function PKT:SetEnabled(enabled)
    if not M.settings then return end
    M.settings.pktModuleEnabled = enabled and true or false
    if M.SaveSettings then M:SaveSettings() end
    -- KnowledgeVignettes consults the toggle on its own gate.
    if M.KnowledgeVignettes and M.KnowledgeVignettes.InvalidateCache then
        M.KnowledgeVignettes:InvalidateCache()
    end
end
