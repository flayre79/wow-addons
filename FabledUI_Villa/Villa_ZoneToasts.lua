local Villa = _G.FabledUI_Villa
local ZoneToasts = {}
Villa.ZoneToasts = ZoneToasts
Villa:RegisterModule("ZoneToasts", ZoneToasts)

-- ============================================================
-- Constants
-- ============================================================

local TOAST_COOLDOWN_SECS = 300   -- 5 minutes per mapID

-- ============================================================
-- Storage helpers
-- ============================================================

local function GetDB()
    local db = Villa.db
    if not db then return nil end
    db.toastCooldowns = db.toastCooldowns or {}
    return db
end

-- ============================================================
-- Toast display
-- ============================================================

local toastFrame = nil

local function EnsureToastFrame()
    if toastFrame then return toastFrame end

    local frame = CreateFrame("Frame", "VillaZoneToastFrame", UIParent, "BackdropTemplate")
    frame:SetSize(340, 52)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.10, 0.96)
    frame:SetBackdropBorderColor(0.227, 0.914, 1.000, 0.9)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\Icons\\Achievement_Reputation_08")
    frame.Icon = icon

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", icon, "RIGHT", 8, 4)
    label:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    label:SetJustifyH("LEFT")
    frame.Label = label

    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("LEFT", icon, "RIGHT", 8, -8)
    sub:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("Click Villa to browse vendors.")
    frame.Sub = sub

    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            Villa:OpenPanel("vendors")
        end
        frame:Hide()
    end)

    -- Fade-out animation
    local ag = frame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.6)
    fade:SetStartDelay(5.0)
    ag:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
    end)
    frame.FadeGroup = ag

    toastFrame = frame
    return frame
end

function ZoneToasts:ShowToast(text)
    local frame = EnsureToastFrame()
    frame.Label:SetText(text or "Uncollected vendors nearby.")
    if frame.FadeGroup then
        frame.FadeGroup:Stop()
    end
    frame:SetAlpha(1)
    frame:Show()
    if frame.FadeGroup then
        frame.FadeGroup:Play()
    end
end

-- ============================================================
-- Uncollected vendor check
-- ============================================================

local function CountUncollectedVendorsInZone(mapID)
    if not mapID then return 0, 0 end
    local count      = 0
    local itemCount  = 0

    -- Primary path: use HomeData's zone-aware vendor iteration
    if Villa.HomeData and Villa.HomeData.IterVendorSourcesForMap then
        local seen = {}
        for _, entry in ipairs(Villa.HomeData:IterVendorSourcesForMap(mapID, true)) do
            if not entry.isCollected then
                local vendorKey = tostring(entry.vendorKey or entry.vendorName or "")
                if not seen[vendorKey] then
                    seen[vendorKey] = true
                    count = count + 1
                end
                itemCount = itemCount + 1
            end
        end
        return count, itemCount
    end

    -- Fallback: walk the merged vendor list and filter by mapID
    if Villa.HomeData and Villa.HomeData.GetMergedVendorList then
        local vendors = Villa.HomeData:GetMergedVendorList() or {}
        for _, vendor in ipairs(vendors) do
            local matched = false
            local locations = vendor.locations or {}
            if #locations == 0 then
                locations = { { mapID = vendor.mapID } }
            end
            for _, loc in ipairs(locations) do
                if tonumber(loc.mapID or vendor.mapID) == tonumber(mapID) then
                    matched = true
                    break
                end
            end
            if matched then
                local owned, total = 0, 0
                if Villa.HomeData.GetVendorProgress then
                    owned, total = Villa.HomeData:GetVendorProgress(vendor)
                else
                    total = #(vendor.items or {})
                end
                if owned < total then
                    count     = count + 1
                    itemCount = itemCount + (total - owned)
                end
            end
        end
    end

    return count, itemCount
end

-- ============================================================
-- Zone change handler
-- ============================================================

function ZoneToasts:OnZoneChanged()
    -- Respect the toggle setting
    if not Villa.settings or Villa.settings.zoneToasts == false then
        return
    end

    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    -- Cooldown check
    local db = GetDB()
    if not db then return end

    local now      = GetTime()
    local lastFire = db.toastCooldowns[mapID]
    if lastFire and (now - lastFire) < TOAST_COOLDOWN_SECS then
        return
    end

    -- Defer the actual work by one frame so map data is fully loaded
    C_Timer.After(1.5, function()
        if not Villa.settings or Villa.settings.zoneToasts == false then return end

        local vendorCount, itemCount = CountUncollectedVendorsInZone(mapID)
        if vendorCount <= 0 then return end

        db.toastCooldowns[mapID] = GetTime()

        local msg
        if vendorCount == 1 then
            msg = "1 housing vendor nearby with " .. tostring(itemCount) .. " uncollected item" .. (itemCount == 1 and "" or "s")
        else
            msg = tostring(vendorCount) .. " housing vendors nearby with uncollected items"
        end
        self:ShowToast(msg)
    end)
end

-- ============================================================
-- Lifecycle
-- ============================================================

function ZoneToasts:OnInitialize()
    local db = GetDB()
    if not db then return end
    db.toastCooldowns = db.toastCooldowns or {}

    -- Ensure the setting key exists (default true)
    if Villa.settings and Villa.settings.zoneToasts == nil then
        Villa.settings.zoneToasts = true
    end
end

function ZoneToasts:OnEnable()
    -- Hook into the ZONE_CHANGED_NEW_AREA event already registered in Core.lua
    -- by patching the existing handler (safe, additive).
    local origSetScript = Villa.events:GetScript("OnEvent")
    Villa.events:HookScript("OnEvent", function(_, event)
        if event == "ZONE_CHANGED_NEW_AREA" then
            ZoneToasts:OnZoneChanged()
        end
    end)
end
