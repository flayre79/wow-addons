local T = rawget(_G, "FabledUI_UIToolkit")
if not T then return end

T.Preview = {}
local P = T.Preview

local ACCENT = { 0.227, 0.914, 1.000, 1.0 }   -- FableNeon electric cyan (#3AE9FF)
local THEME  = "FableNeon"
local FRAME_W, FRAME_H = 280, 380

local previewFrame

local function EnsureFrame()
    if previewFrame then return previewFrame end

    local f = CreateFrame("Frame", "FabledUI_PreviewPopup", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Theme styling
    if T.Themes and T.Themes.Apply then
        T.Themes:Apply(f, THEME, ACCENT)
    end
    -- FableNeon: soft outer halo + crisp neon edge to match the suite windows.
    if T.Effects and T.Effects.StyleWindow then
        pcall(T.Effects.StyleWindow, T.Effects, f, THEME, ACCENT)
    end

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    if T.Themes and T.Themes.ApplyPanel then
        T.Themes:ApplyPanel(titleBar, THEME, ACCENT, true)
    end

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 10, 0)
    titleText:SetPoint("RIGHT", -30, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetText("3D Preview")
    if T.Themes and T.Themes.ApplyTitleText then
        T.Themes:ApplyTitleText(titleText, THEME, ACCENT)
    end
    f.titleText = titleText

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", -3, 0)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function() P:Hide() end)
    if T.Themes and T.Themes.StyleFlatButton then
        T.Themes:StyleFlatButton(closeBtn, THEME, ACCENT)
    end

    -- Accent strip under title (cyan->purple seam)
    local accentStrip = f:CreateTexture(nil, "ARTWORK")
    accentStrip:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 1, 0)
    accentStrip:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -1, 0)
    accentStrip:SetHeight(2)
    local th = T.Themes and T.Themes.Resolve and T.Themes:Resolve(THEME, ACCENT) or nil
    if accentStrip.SetGradient and CreateColor and th and th.accent2 then
        accentStrip:SetColorTexture(1, 1, 1, 1)
        accentStrip:SetGradient("HORIZONTAL",
            CreateColor(th.accent[1], th.accent[2], th.accent[3], 1),
            CreateColor(th.accent2[1], th.accent2[2], th.accent2[3], 1))
    else
        accentStrip:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], ACCENT[4])
    end

    -- 3D model frames: a DressUpModel for wearable gear and a generic Model
    -- for props that expose a world model. Housing decor has no runtime
    -- itemID->model API (see ShowPlaceholder), so it falls back to an icon.
    local dressModel = CreateFrame("DressUpModel", nil, f)
    dressModel:SetPoint("TOPLEFT", 8, -36)
    dressModel:SetPoint("BOTTOMRIGHT", -8, 40)
    dressModel:Hide()

    local decorModel = CreateFrame("Model", nil, f)
    decorModel:SetPoint("TOPLEFT", 8, -36)
    decorModel:SetPoint("BOTTOMRIGHT", -8, 40)
    decorModel:Hide()

    local rotationSpeed = 0.01

    local function WireMouse(model)
        local isDragging = false
        local lastX = 0

        model:EnableMouse(true)
        model:EnableMouseWheel(true)

        model:SetScript("OnMouseWheel", function(self, delta)
            local dist = (self.GetCameraDistance and self:GetCameraDistance()) or 3.0
            local newDist = dist - delta * 0.3
            newDist = math.max(0.5, math.min(newDist, 60.0))
            -- Defensive: if the model frame doesn't currently have a custom
            -- camera bound, SetCameraDistance throws. Re-bind first.
            pcall(self.SetCamera, self, 0)
            pcall(self.SetCameraDistance, self, newDist)
        end)

        model:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                isDragging = true
                lastX = GetCursorPosition()
            elseif button == "RightButton" then
                self:SetFacing(0)
            end
        end)

        model:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                isDragging = false
            end
        end)

        model:SetScript("OnUpdate", function(self)
            if isDragging then
                local curX = GetCursorPosition()
                local diff = (curX - lastX) * rotationSpeed
                self:SetFacing((self:GetFacing() or 0) + diff)
                lastX = curX
            end
        end)
    end

    WireMouse(dressModel)
    WireMouse(decorModel)

    f.dressModel = dressModel
    f.decorModel = decorModel
    -- Backwards-compat alias used by older callers / tests.
    f.model = dressModel

    -- Icon placeholder — shown when a 3D model isn't available (housing decor,
    -- or any item whose model never loads). Large item icon + a short note, so
    -- the popup never falls back to rendering the player character.
    local placeholder = CreateFrame("Frame", nil, f)
    placeholder:SetPoint("TOPLEFT", 8, -36)
    placeholder:SetPoint("BOTTOMRIGHT", -8, 40)
    placeholder:Hide()

    local phIcon = placeholder:CreateTexture(nil, "ARTWORK")
    phIcon:SetSize(100, 100)
    phIcon:SetPoint("CENTER", 0, 28)
    phIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    placeholder.icon = phIcon

    -- thin neon ring around the icon
    local phRing = placeholder:CreateTexture(nil, "OVERLAY")
    phRing:SetPoint("TOPLEFT", phIcon, "TOPLEFT", -2, 2)
    phRing:SetPoint("BOTTOMRIGHT", phIcon, "BOTTOMRIGHT", 2, -2)
    phRing:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12)

    local phText = placeholder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    phText:SetPoint("TOP", phIcon, "BOTTOM", 0, -16)
    phText:SetPoint("LEFT", 12, 0)
    phText:SetPoint("RIGHT", -12, 0)
    phText:SetJustifyH("CENTER")
    phText:SetWordWrap(true)
    phText:SetText("")
    if T.Themes and T.Themes.ApplyBodyText then
        T.Themes:ApplyBodyText(phText, THEME, ACCENT, true)
    end
    placeholder.text = phText
    f.placeholder = placeholder

    -- Footer panel
    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(34)
    if T.Themes and T.Themes.ApplyPanel then
        T.Themes:ApplyPanel(footer, THEME, ACCENT)
    end

    local itemLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemLabel:SetPoint("CENTER", 0, 0)
    itemLabel:SetJustifyH("CENTER")
    itemLabel:SetText("")
    if T.Themes and T.Themes.ApplyBodyText then
        T.Themes:ApplyBodyText(itemLabel, THEME, ACCENT)
    end
    f.itemLabel = itemLabel

    previewFrame = f
    return f
end

-- Item classes/subclasses that DressUpModel:TryOn renders (wearable gear).
local DRESSUP_CLASSES = {
    [Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4] = true,
    [Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2] = true,
}
local HOUSING_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Housing) or 15

local function ItemClassOf(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, c = C_Item.GetItemInfoInstant(itemID)
        return c
    elseif _G.GetItemInfoInstant then
        local _, _, _, _, _, c = _G.GetItemInfoInstant(itemID)
        return c
    end
    return nil
end

local function IconOf(itemID)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID))
        or (_G.GetItemIcon and _G.GetItemIcon(itemID))
        or 134400 -- default question-mark icon
end

-- Frame a loaded model from the harvested camera presets, falling back to the
-- supplied fixed distance when neither donor covers it.
--
-- Without this every decor rendered at one hardcoded camera distance, so a
-- candle and a treehouse were framed identically -- the 726 presets harvested
-- into Data/CameraPresetData.lua existed for months with nothing calling them.
--
-- CameraPresets:Apply owns the per-donor call sequence on purpose; the two
-- schemas are not interchangeable (see Data/CameraPresets.lua).
local function FrameModel(model, itemID, fallbackDistance)
    local presets = T.CameraPresets

    -- HomeBound keys on the model file id, which is only knowable once the
    -- model has loaded -- hence calling this from OnModelLoaded, not from Show.
    local fileID
    if model.GetModelFileID then
        local ok, value = pcall(model.GetModelFileID, model)
        if ok and type(value) == "number" and value > 0 then
            fileID = value
        end
    end

    if presets and presets.Apply then
        local applied = presets:Apply(model, itemID, fileID)
        if applied then
            return true
        end
    end

    pcall(model.SetCamera, model, 0)
    pcall(model.SetCameraDistance, model, fallbackDistance)
    return false
end

-- Show the item icon + a short note instead of a 3D model.
local function ShowPlaceholder(f, itemID, housing)
    f.dressModel:Hide()
    f.decorModel:Hide()
    pcall(f.decorModel.ClearModel, f.decorModel)
    f.placeholder.icon:SetTexture(IconOf(itemID))
    f.placeholder.text:SetText(housing
        and "No 3D preview available for housing decor.\nShowing the item icon."
        or "No 3D model available for this item.\nShowing the item icon.")
    f.placeholder:Show()
end

-- Attempt a generic world-model render (mounts, props). If nothing loads
-- shortly, fall back to the icon placeholder rather than an empty/def model.
local function ShowDecor(f, itemID)
    f.dressModel:Hide()
    f.placeholder:Hide()
    local m = f.decorModel
    pcall(m.ClearModel, m)
    m:Show()
    m.__token = (m.__token or 0) + 1
    local token = m.__token
    m.__loaded = false
    m:SetScript("OnModelLoaded", function(self)
        if self.__token ~= token then return end
        self.__loaded = true
        f.placeholder:Hide()
        self:Show()
        self:SetFacing(0)
        pcall(self.SetPosition, self, 0, 0, 0)
        -- Preset framing (falls back to the old fixed 6.0 when uncovered).
        FrameModel(self, itemID, 6.0)
    end)
    if m.SetItem then
        pcall(m.SetItem, m, itemID)
    end
    pcall(m.SetCamera, m, 0)
    pcall(m.SetCameraDistance, m, 6.0)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.4, function()
            if m.__token == token and not m.__loaded then
                m:Hide()
                ShowPlaceholder(f, itemID, false)
            end
        end)
    end
end

-- Housing decor renders from the catalog record's model asset (a file id keyed
-- by decorID == recordID), NOT via Model:SetItem. Fetch it at runtime.
local DECOR_ENTRY_TYPE = (Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Decor) or 1

local function DecorRecord(decorID)
    decorID = tonumber(decorID)
    if not decorID or not C_HousingCatalog or type(C_HousingCatalog.GetCatalogEntryInfoByRecordID) ~= "function" then
        return nil
    end
    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, DECOR_ENTRY_TYPE, decorID, true)
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

-- Show the decor's REAL catalog icon (info.iconTexture), not the donor itemID's
-- icon — donor itemIDs are unreliable and can resolve to unrelated gear.
local function ShowDecorIcon(f, iconTex, itemID, note)
    f.dressModel:Hide()
    f.decorModel:Hide()
    pcall(f.decorModel.ClearModel, f.decorModel)
    f.placeholder.icon:SetTexture(iconTex or IconOf(itemID))
    f.placeholder.text:SetText(note or "No 3D model available for this decor.\nShowing its catalog icon.")
    f.placeholder:Show()
end

-- Render a decor's real 3D model from its catalog asset (keyed by decorID). If
-- there's no model (or it never loads), fall back to the catalog icon.
local function ShowDecorModel(f, decorID, itemID)
    f.dressModel:Hide()
    f.placeholder:Hide()
    local info = decorID and DecorRecord(decorID) or nil
    local asset = info and info.asset
    local iconTex = info and info.iconTexture
    if not asset or asset == 0 then
        ShowDecorIcon(f, iconTex, itemID)
        return
    end
    local m = f.decorModel
    pcall(m.ClearModel, m)
    m:Show()
    m.__token = (m.__token or 0) + 1
    local token = m.__token
    m.__loaded = false
    m:SetScript("OnModelLoaded", function(self)
        if self.__token ~= token then return end
        self.__loaded = true
        f.placeholder:Hide()
        self:Show()
        self:SetFacing(0)
        -- itemID first (HCT hand-tuned each craftable decor), then the catalog
        -- asset id via HomeBound. Falls back to the old fixed 4.0 when neither
        -- donor covers this decor.
        FrameModel(self, itemID, 4.0)
    end)
    if m.SetModel then
        pcall(m.SetModel, m, asset)
    end
    pcall(m.SetCamera, m, 0)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            if m.__token == token and not m.__loaded then
                m:Hide()
                ShowDecorIcon(f, iconTex, itemID)
            end
        end)
    end
end

local function ShowDressUp(f, itemID)
    f.decorModel:Hide()
    f.placeholder:Hide()
    local m = f.dressModel
    m:Show()
    m:SetUnit("player")
    m:Undress()
    m:SetFacing(0)
    pcall(m.SetCamera, m, 0)
    pcall(m.SetCameraDistance, m, 3.0)
    m:TryOn("item:" .. itemID)
end

-- Try to anchor the popup beside the source button; flip to the other side or
-- center if it would otherwise spill off the screen. SetClampedToScreen alone
-- isn't enough — it only kicks in during user drags, not initial placement.
local function PlacePopup(f, anchorFrame)
    f:ClearAllPoints()
    if not anchorFrame then
        f:SetPoint("CENTER")
        return
    end

    local screenW = UIParent:GetWidth() or 1920
    local screenH = UIParent:GetHeight() or 1080
    local fW, fH = f:GetWidth() or FRAME_W, f:GetHeight() or FRAME_H
    local aLeft = anchorFrame:GetLeft() or 0
    local aRight = anchorFrame:GetRight() or 0
    local aBottom = anchorFrame:GetBottom() or 0

    -- Prefer right-of-anchor; fall back to left-of-anchor; then to center.
    if aRight + 12 + fW <= screenW then
        f:SetPoint("LEFT", anchorFrame, "RIGHT", 12, 0)
    elseif aLeft - 12 - fW >= 0 then
        f:SetPoint("RIGHT", anchorFrame, "LEFT", -12, 0)
    else
        f:SetPoint("CENTER")
    end

    -- Final defensive nudge: if the chosen anchor still pushes the popup
    -- off the bottom or top edge, re-pin to CENTER.
    local resolvedBottom = aBottom - (fH * 0.5)
    if resolvedBottom < 0 or resolvedBottom + fH > screenH then
        f:ClearAllPoints()
        f:SetPoint("CENTER")
    end
end

function P:Show(itemID, anchorFrame, decorID)
    if not itemID and not decorID then return end

    local f = EnsureFrame()

    PlacePopup(f, anchorFrame)

    -- Resolve a decorID (from the caller, or mapped from the itemID) so housing
    -- decor can render its REAL model from the catalog asset. Routing: housing
    -- decor -> catalog model (icon fallback); gear -> DressUp try-on; other
    -- items -> generic world model with icon fallback. Class may be unknown on
    -- first pass (metadata not cached) — re-render once ContinueOnItemLoad fires.
    local function ResolveDecorID()
        if decorID then return decorID end
        if itemID and C_Housing and type(C_Housing.GetDecorItemInfoFromItemID) == "function" then
            local ok, di = pcall(C_Housing.GetDecorItemInfoFromItemID, itemID)
            if ok and type(di) == "table" and di.decorID then return di.decorID end
        end
        return nil
    end

    local function Render()
        local dID = ResolveDecorID()
        local classID = itemID and ItemClassOf(itemID) or nil
        if dID or classID == HOUSING_CLASS then
            ShowDecorModel(f, dID, itemID)
        elseif classID and DRESSUP_CLASSES[classID] then
            ShowDressUp(f, itemID)
        elseif classID == nil and itemID then
            ShowPlaceholder(f, itemID, false)
        elseif itemID then
            ShowDecor(f, itemID)
        else
            ShowPlaceholder(f, itemID or dID, true)
        end
    end
    Render()

    f.titleText:SetText("3D Preview")
    f.itemLabel:SetText("Loading...")

    local item = itemID and Item and Item.CreateFromItemID and Item:CreateFromItemID(itemID)
    if item and item.ContinueOnItemLoad then
        item:ContinueOnItemLoad(function()
            if not f:IsShown() then return end
            -- Re-render now that GetItemInfoInstant is populated.
            Render()
            local name = item:GetItemName()
            if name and name ~= "" then
                f.itemLabel:SetText(name)
            end
        end)
    else
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
        f.itemLabel:SetText(name or ("Item #" .. itemID))
    end

    f:Show()
end

function P:Hide()
    if previewFrame then
        previewFrame:Hide()
    end
end

function P:IsShown()
    return previewFrame and previewFrame:IsShown() or false
end
