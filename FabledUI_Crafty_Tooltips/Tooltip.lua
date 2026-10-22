local addonName, ns = ...
local M = _G.FabledUI_Crafty
M.Tooltip = M.Tooltip or {}
local T = M.Tooltip

-- Prefer the shared copy the parent publishes on _G.FabledUI_Crafty; this
-- addon's own `ns` never receives the constants. (Fix B8)
local ItemProfConstants = (_G.FabledUI_Crafty and _G.FabledUI_Crafty.ItemProfConstants) or ns or {}
local band = bit.band
local NUM_PROFS = 10
-- P2-12: tooltip output cache. ModifyItemTooltip is called per tooltip
-- repaint; mousing over the same item three times in a row should reuse
-- the previous build, not rebuild sections + re-walk Assistance/GearTokens
-- /ItemMetadata each time. Pattern lifted from
-- .sample-addons/ItemTooltipProfessionIcons/ItemTooltipProfessionIcons.lua:57-61.
local previousItemID = -1
local previousIcons = nil
local previousSections = nil

local PROF_ORDER = {
    { label = "Cooking", flag = 0x001 },
    { label = "Alchemy", flag = 0x002 },
    { label = "Blacksmithing", flag = 0x004 },
    { label = "Enchanting", flag = 0x008 },
    { label = "Engineering", flag = 0x010 },
    { label = "Leatherworking", flag = 0x020 },
    { label = "Tailoring", flag = 0x040 },
    { label = "Inscription", flag = 0x080 },
    { label = "Jewelcrafting", flag = 0x100 },
    { label = "Mining", flag = 0x200 },
}

function T:GetProfessionOptions()
    return PROF_ORDER
end

-- P2-7: per-character profession-filter bitmask. Different alts care about
-- different professions (a JC main doesn't want Tailoring icons cluttering
-- every tooltip). Storage moves from M.settings (account-wide) to
-- M.db.charSettings[charKey].tooltipProfFilterMask. Pattern from ITPI's
-- ItemTooltipProfessionConfigFrame.lua:81-96. A one-shot migration on
-- first read copies the legacy account-wide mask into every known char
-- so existing users don't lose their preference.
local function ensureCharSettings()
    if not M.db then return nil end
    M.db.charSettings = type(M.db.charSettings) == "table" and M.db.charSettings or {}
    local key = M.GetCurrentCharacterKey and M:GetCurrentCharacterKey() or nil
    if not key then return nil end
    M.db.charSettings[key] = type(M.db.charSettings[key]) == "table" and M.db.charSettings[key] or {}
    return M.db.charSettings[key]
end

local function migrateAccountFilterToChars()
    if not M.db or M.db._tooltipFilterMigrated then
        return
    end
    M.db._tooltipFilterMigrated = true
    local legacy = M.settings and M.settings.tooltipProfFilterMask
    if not legacy then return end
    M.db.charSettings = type(M.db.charSettings) == "table" and M.db.charSettings or {}
    -- Apply to current character + every alt we already know about.
    if M.db.alts and type(M.db.alts) == "table" then
        for charKey in pairs(M.db.alts) do
            local entry = type(M.db.charSettings[charKey]) == "table" and M.db.charSettings[charKey] or {}
            if entry.tooltipProfFilterMask == nil then
                entry.tooltipProfFilterMask = legacy
            end
            M.db.charSettings[charKey] = entry
        end
    end
    local currentKey = M.GetCurrentCharacterKey and M:GetCurrentCharacterKey() or nil
    if currentKey then
        local entry = type(M.db.charSettings[currentKey]) == "table" and M.db.charSettings[currentKey] or {}
        if entry.tooltipProfFilterMask == nil then
            entry.tooltipProfFilterMask = legacy
        end
        M.db.charSettings[currentKey] = entry
    end
end

function T:GetFilterMask()
    migrateAccountFilterToChars()
    local cs = ensureCharSettings()
    if cs and cs.tooltipProfFilterMask then
        return tonumber(cs.tooltipProfFilterMask) or 0x3FF
    end
    local settings = M.settings or {}
    if settings.tooltipProfFilterMask then
        return tonumber(settings.tooltipProfFilterMask) or 0x3FF
    end
    return 0x3FF
end

function T:SetFilterFlag(flag, enabled)
    local current = self:GetFilterMask()
    if enabled then
        current = current + (band(current, flag) == 0 and flag or 0)
    else
        if band(current, flag) ~= 0 then
            current = current - flag
        end
    end
    -- Write to per-character storage; mirror to the account-wide slot for
    -- back-compat in case other code still reads M.settings directly.
    local cs = ensureCharSettings()
    if cs then
        cs.tooltipProfFilterMask = current
    end
    if M.settings then
        M.settings.tooltipProfFilterMask = current
    end
    previousItemID = -1
    previousIcons = nil
    previousSections = nil
    M:SaveSettings()
end

function T:IsFlagEnabled(flag)
    return band(self:GetFilterMask(), flag) ~= 0
end

function T:GetDisplayMode()
    local mode = M.settings and M.settings.tooltipProfessionDisplayMode or nil
    if mode == "OFF" or mode == "ICONS" or mode == "TEXT" or mode == "BOTH" then
        return mode
    end
    local icons = M.settings.tooltipProfessionIconsEnabled ~= false
    local text = M.settings.tooltipProfessionTextEnabled == true
    if icons and text then
        return "BOTH"
    elseif text then
        return "TEXT"
    elseif icons then
        return "ICONS"
    end
    return "OFF"
end

function T:SetDisplayMode(mode)
    mode = tostring(mode or "OFF"):upper()
    if mode ~= "OFF" and mode ~= "ICONS" and mode ~= "TEXT" and mode ~= "BOTH" then
        mode = "OFF"
    end
    M.settings.tooltipProfessionDisplayMode = mode
    M.settings.tooltipProfessionIconsEnabled = (mode == "ICONS" or mode == "BOTH")
    M.settings.tooltipProfessionTextEnabled = (mode == "TEXT" or mode == "BOTH")
    previousItemID = -1
    previousIcons = nil
    previousSections = nil
    T._builtTextures = nil
    M:SaveSettings()
end

-- P2-13: cache BuildTextures output. The donor implementation rebuilds 10
-- texture strings on every tooltip render; the rebuild only ever changes
-- when icon size, classic/modern toggle, or vendor-include change. Cache
-- the array and invalidate via T:RebuildTextures() when settings flip.
local function buildTexturesImpl()
    local settings = M.settings or {}
    local iconSize = math.max(8, math.min(32, tonumber(settings.tooltipProfIconSize) or 18))
    local classic = settings.tooltipProfClassicIcons == true
    local textureSet = ItemProfConstants.TEXTURES and ItemProfConstants.TEXTURES[classic]
    if type(textureSet) ~= "table" then
        return nil
    end

    local out = {}
    local trimLen = classic and 9 or 10
    for i = 1, NUM_PROFS do
        out[i] = string.sub(textureSet[i], 1, trimLen) .. iconSize .. "|t "
    end
    return out
end

function T:RebuildTextures()
    self._builtTextures = buildTexturesImpl()
    previousItemID = -1
    previousIcons = nil
    previousSections = nil
end

local function BuildTextures()
    if T._builtTextures == nil then
        T._builtTextures = buildTexturesImpl() or false
    end
    if T._builtTextures == false then
        return nil
    end
    return T._builtTextures
end

function T:GetTooltipItemID(tt)
    local data = tt and tt.GetPrimaryTooltipData and tt:GetPrimaryTooltipData() or nil
    if not data then
        return nil
    end

    local itemID = data.id
    if itemID then
        return itemID
    end

    local itemLink = data.hyperlink
    if itemLink then
        return tonumber(string.match(itemLink, "item:?(%d+):"))
    end

    if data.guid and C_Item and C_Item.GetItemIDByGUID then
        return C_Item.GetItemIDByGUID(data.guid)
    end

    return nil
end

function T:BuildProfessionList(itemID)
    local itemFlags = ItemProfConstants.ITEM_PROF_FLAGS and ItemProfConstants.ITEM_PROF_FLAGS[itemID]
    if not itemFlags then
        return nil
    end

    local labels = {}
    local enabledFlags = band(itemFlags, self:GetFilterMask())
    for _, info in ipairs(PROF_ORDER) do
        if band(enabledFlags, info.flag) ~= 0 then
            labels[#labels + 1] = info.label
        end
    end
    return (#labels > 0) and labels or nil
end

function T:BuildProfessionIconLine(itemID)
    if self:GetDisplayMode() == "OFF" or self:GetDisplayMode() == "TEXT" then
        return nil
    end
    local itemFlags = ItemProfConstants.ITEM_PROF_FLAGS and ItemProfConstants.ITEM_PROF_FLAGS[itemID]
    if not itemFlags then
        return nil
    end

    if M.settings.tooltipProfIncludeVendor == false then
        local vendorFlag = ItemProfConstants.VENDOR_ITEM_FLAG or 0x400
        if band(itemFlags, vendorFlag) ~= 0 then
            return nil
        end
    end

    local textures = BuildTextures()
    if not textures then
        return nil
    end

    local enabledFlags = band(itemFlags, self:GetFilterMask())
    if enabledFlags == 0 then
        return nil
    end

    local parts = {}
    local mask = 1
    for i = 1, NUM_PROFS do
        if band(enabledFlags, mask) ~= 0 then
            parts[#parts + 1] = textures[i]
        end
        mask = mask * 2
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts)
end

function T:BuildProfessionTextLine(itemID)
    if self:GetDisplayMode() == "OFF" or self:GetDisplayMode() == "ICONS" then
        return nil
    end
    local labels = self:BuildProfessionList(itemID)
    if labels and #labels > 0 then
        return "Crafty professions: " .. table.concat(labels, ", ")
    end
    return nil
end

function T:BuildSections(itemID)
    local sections = {}

    local iconLine = self:BuildProfessionIconLine(itemID)
    local textLine = self:BuildProfessionTextLine(itemID)
    if iconLine or textLine then
        sections[#sections + 1] = {
            color = { 0.36, 0.88, 0.71 },
            lines = {
                iconLine,
                textLine,
            },
        }
    end

    if M.Assistance and M.Assistance.BuildTooltipLines then
        local lines = M.Assistance:BuildTooltipLines(itemID)
        if lines and #lines > 0 then
            sections[#sections + 1] = { color = { 0.36, 0.88, 0.71 }, lines = lines }
        end
    end

    if M.GearTokens and M.GearTokens.BuildTooltipLines then
        local lines = M.GearTokens:BuildTooltipLines(itemID)
        if lines and #lines > 0 then
            sections[#sections + 1] = { color = { 0.91, 0.73, 0.34 }, lines = lines }
        end
    end

    if M.ItemMetadata and M.ItemMetadata.BuildTooltipLines then
        local lines = M.ItemMetadata:BuildTooltipLines(itemID)
        if lines and #lines > 0 then
            sections[#sections + 1] = { color = { 0.75, 0.75, 0.95 }, lines = lines }
        end
    end

    return sections
end

-- P2-6: optional modifier-key gate. Default OFF preserves previous behavior;
-- when set to SHIFT/CTRL/ALT the tooltip enrichment only renders while that
-- modifier is held. Pattern from
-- .sample-addons/ItemEra/Modules/Tooltip/Tooltip.lua:82-99.
local function modifierAllows()
    local mode = M.settings and M.settings.tooltipModifier or "OFF"
    if not mode or mode == "OFF" or mode == "" then
        return true
    end
    if mode == "SHIFT" then return IsShiftKeyDown and IsShiftKeyDown() end
    if mode == "CTRL" or mode == "CONTROL" then return IsControlKeyDown and IsControlKeyDown() end
    if mode == "ALT" then return IsAltKeyDown and IsAltKeyDown() end
    return true
end

local function renderSections(tt, sections)
    if not sections or #sections == 0 then
        return
    end
    tt:AddLine(" ")
    for _, section in ipairs(sections) do
        local first = true
        for _, line in ipairs(section.lines or {}) do
            if line and line ~= "" then
                if first and section.color then
                    tt:AddLine(line, section.color[1], section.color[2], section.color[3], true)
                else
                    tt:AddLine(line, 1, 1, 1, true)
                end
                first = false
            end
        end
    end
    tt:Show()
end

function T:ModifyItemTooltip(tt)
    if not tt then
        return
    end

    -- P2-6: respect optional modifier gate.
    if not modifierAllows() then
        return
    end

    local itemID = self:GetTooltipItemID(tt)
    if not itemID then
        return
    end

    -- P2-12: hot-path cache. If the same itemID just rendered, replay the
    -- prior section list rather than walking every contributor module.
    if itemID == previousItemID and previousSections and #previousSections > 0 then
        renderSections(tt, previousSections)
        return
    end

    local sections = self:BuildSections(itemID)
    if not sections or #sections == 0 then
        previousItemID = itemID
        previousSections = nil
        return
    end

    previousItemID = itemID
    previousSections = sections

    renderSections(tt, sections)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
        -- Lazy-load the data pack the first time we see a profession-relevant
        -- tooltip so token / assistance enrichment works without forcing the
        -- player to open the Crafty window first.
        if M.EnsureDataLoaded then
            M:EnsureDataLoaded()
        end
        T:ModifyItemTooltip(tt)
    end)
end
