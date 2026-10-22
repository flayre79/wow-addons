local T = FabledUI_UIToolkit
T.Toast = {}
local toastPool = {}

local TOAST_W_NO_ICON  = 250
local TOAST_W_ICON     = 290
local TOAST_H          = 40
local ICON_SIZE        = 28
local ICON_PAD         = 6    -- padding from left edge to icon
local TEXT_PAD_ICON    = ICON_PAD + ICON_SIZE + 6
local TEXT_PAD_NO_ICON = 0    -- centred when no icon

--- SVC-005: Toast Helper
--- Displays a transient non-intrusive notification. Stacks vertically if multiple are called.
--- @param message string  Text to display.
--- @param icon    string|number|nil  Texture path, FileDataID, or spell/item ID for the icon.
--- @param duration number|nil  Seconds to display (default 3.0).
function T.Toast:Show(message, icon, duration)
    duration = duration or 3.0

    -- Recycle a hidden toast from the pool
    local toast
    for _, t in ipairs(toastPool) do
        if not t:IsShown() then
            toast = t
            break
        end
    end

    if not toast then
        toast = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        toast:SetFrameStrata("TOOLTIP")
        toast:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })

        -- Icon texture (hidden until an icon is supplied)
        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(ICON_SIZE, ICON_SIZE)
        toast.icon:SetPoint("LEFT", ICON_PAD, 0)
        toast.icon:Hide()

        -- Text
        toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

        table.insert(toastPool, toast)
    end

    -- Resolve icon texture. The legacy globals GetSpellTexture / GetItemInfo
    -- were removed in WoW 11.0 — we now use C_Spell.GetSpellTexture and
    -- C_Item.GetItemIconByID, falling back to treating the input number as
    -- a FileDataID so the caller doesn't have to differentiate.
    local resolvedIcon = nil
    if type(icon) == "string" and icon ~= "" then
        resolvedIcon = icon
    elseif type(icon) == "number" and icon > 0 then
        local fileID
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, tex = pcall(C_Spell.GetSpellTexture, icon)
            if ok and tex then fileID = tex end
        end
        if not fileID and C_Item and C_Item.GetItemIconByID then
            local ok, tex = pcall(C_Item.GetItemIconByID, icon)
            if ok and tex then fileID = tex end
        end
        resolvedIcon = fileID or icon  -- fall back to using the number as a FileDataID
    end

    -- Resize and reposition text depending on whether we have an icon
    if resolvedIcon then
        toast:SetSize(TOAST_W_ICON, TOAST_H)
        toast.icon:SetTexture(resolvedIcon)
        toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim edges like Blizzard
        toast.icon:Show()
        toast.text:ClearAllPoints()
        toast.text:SetPoint("LEFT",  toast, "LEFT", TEXT_PAD_ICON, 0)
        toast.text:SetPoint("RIGHT", toast, "RIGHT", -6, 0)
        toast.text:SetJustifyH("LEFT")
    else
        toast:SetSize(TOAST_W_NO_ICON, TOAST_H)
        toast.icon:Hide()
        toast.text:ClearAllPoints()
        toast.text:SetPoint("CENTER", 0, 0)
        toast.text:SetJustifyH("CENTER")
    end

    -- Stack position
    local activeCount = 0
    for _, t in ipairs(toastPool) do
        if t:IsShown() then activeCount = activeCount + 1 end
    end
    toast:ClearAllPoints()
    toast:SetPoint("TOP", UIParent, "TOP", 0, -(100 + (activeCount * 45)))

    toast.text:SetText(message)
    toast:Show()

    C_Timer.After(duration, function()
        toast:Hide()
    end)
end
