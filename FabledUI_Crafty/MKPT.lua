-- FabledUI_Crafty/MKPT.lua
--
-- MKPT Module — wraps Crafty's existing Knowledge Points tracking surface
-- (Knowledge tab, KnowledgeVignettes auto-supertrack, per-profession
-- knowledge data shards) under a single togglable umbrella so users who
-- want a CraftSim-only experience can disable Knowledge without losing
-- the rest of Crafty.
--
-- Donor: .sample-addons/MyusKnowledgePointsTracker (4,160 LOC across
--   MKPT_Profession / MKPT_Item / MKPT_Currency / MKPT_Requirement /
--   MKPT_RightClickMenu / MKPT_Ui / Init.lua / etc).
--
-- What's wired today (Crafty already has this functionality, gated by
-- this module's toggle):
--   - Knowledge tab in the main Crafty window (UI:RenderKnowledge)
--   - Per-profession knowledge data shards (FabledUI_Crafty_Data_<Prof>)
--   - KnowledgeVignettes auto-supertrack on VIGNETTES_UPDATED
--   - Knowledge waypoint button (K:SetWaypoint)
--
-- What's pending port from MKPT (queued for follow-up):
--   - Minimap icon (LibDBIcon-style) for one-click open to Knowledge tab
--   - Per-character earned-source ledger (which sources you've already
--     completed this week / this character — we only track watch/exclude
--     today, not "earned" state)
--   - Right-click menu on knowledge sources (Set Waypoint / Mark Earned /
--     Hide Source / Track Quest)
--   - Currency requirement tracker (some sources need currency to redeem)
--
-- Public API:
--   M.MKPT:IsEnabled()
--   M.MKPT:SetEnabled(bool)

local M = _G.FabledUI_Crafty
if not M then return end

M.MKPT = M.MKPT or {}
local MKPT = M.MKPT

MKPT.VERSION = "0.1.0"

function MKPT:IsEnabled()
    if not M.settings then return true end
    return M.settings.mkptModuleEnabled ~= false
end

function MKPT:SetEnabled(enabled)
    if not M.settings then return end
    M.settings.mkptModuleEnabled = enabled and true or false
    if M.SaveSettings then M:SaveSettings() end
    if M.Fire then M:Fire("DataChanged") end
    -- KnowledgeVignettes consults the toggle on its own gate; main UI
    -- refreshes on DataChanged so the Knowledge tab shows/hides accordingly.
end
