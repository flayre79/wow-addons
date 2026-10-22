local Villa = _G.FabledUI_Villa
local Tracker = {}
Villa.Tracker = Tracker
Villa:RegisterModule("Tracker", Tracker)

-- 12.1.5 deletes the globals GetItemInfo and GetCoinTextureString. These are
-- what Blizzard's removed shims pointed them at (Deprecated_ItemScript.lua,
-- Deprecated_CurrencyScript.lua).
local GetItemInfo = C_Item and C_Item.GetItemInfo
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString

Tracker.panelTitle = "Villa Tracker"
Tracker.panelSubtitle = "HousingItemTracker donor behavior for housing-relevant items, tooltip sourcing, and merchant highlights."

local function addLine(tooltip, text, r, g, b)
    if tooltip and text and text ~= "" then
        tooltip:AddLine(text, r or 0.82, g or 0.82, b or 0.94, true)
    end
end

local function GetMarketValue(itemID)
    -- Try TSM first
    if TSM_API then
        local itemString = "i:" .. itemID
        local price = TSM_API.GetCustomPriceValue("DBMarket", itemString)
        if price and price > 0 then return price, "TSM" end
    end
    -- Try Auctionator
    if Auctionator and Auctionator.API and Auctionator.API.v1 then
        local price = Auctionator.API.v1.GetAuctionPriceByItemLink(
            "Auctionator", select(2, GetItemInfo(itemID)))
        if price and price > 0 then return price, "Auctionator" end
    end
    -- Try RECrystallize / Aux / OribosExchange fallbacks
    if AuctionatorPrice then
        local price = AuctionatorPrice:GetValue("i:" .. itemID)
        if price and price > 0 then return price, "Auctionator" end
    end
    return nil, nil
end

function Tracker:IsRelevantItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    if Villa.NormalizedData and Villa.NormalizedData.GetMaterialInfo and Villa.NormalizedData:GetMaterialInfo(itemID) then return true end
    if Villa.HITData and type(Villa.HITData.IsHousingMaterial) == "function" and Villa.HITData:IsHousingMaterial(itemID) then return true end
    if Villa.HousingVendorData and type(Villa.HousingVendorData.IsHousingMaterial) == "function" and Villa.HousingVendorData:IsHousingMaterial(itemID) then return true end
    if Villa:IsHousingRelevantItem(itemID) then return true end
    return false
end

function Tracker:DecorateTooltip(tooltip, itemID)
    if not tooltip or not itemID or not self:IsRelevantItem(itemID) then return end
    addLine(tooltip, " ")
    addLine(tooltip, "Villa Tracker", 0.227, 0.914, 1.000)

    local materialInfo = Villa.NormalizedData and Villa.NormalizedData.GetMaterialInfo and Villa.NormalizedData:GetMaterialInfo(itemID)
    if materialInfo then
        if materialInfo.usages and #materialInfo.usages > 0 then
            addLine(tooltip, "Used in housing recipes", 0.95, 0.85, 0.55)
            for i = 1, math.min(#materialInfo.usages, 5) do
                addLine(tooltip, "• " .. tostring(materialInfo.usages[i]), 0.85, 0.85, 0.85)
            end
        end
        if materialInfo.source then
            addLine(tooltip, "Material source: " .. tostring(materialInfo.source), 0.75, 0.88, 1)
        end
        if materialInfo.price then
            addLine(tooltip, "Base vendor price: " .. tostring(materialInfo.price) .. "c", 0.95, 0.85, 0.55)
        end
        if materialInfo.sourceSummary and materialInfo.sourceSummary ~= "" then
            addLine(tooltip, "Providers: " .. tostring(materialInfo.sourceSummary), 0.72, 0.72, 0.72)
        end
    end

    local info = Villa:GetDecorSourceInfo(itemID)
    if info and info.vendorName then
        addLine(tooltip, "Vendor: " .. tostring(info.vendorName), 0.70, 0.88, 1.00)
    end
    if info and info.requirementText then
        addLine(tooltip, tostring(info.requirementText), 0.82, 0.82, 0.82)
    end

    if Villa.settings.showMarketValue then
        -- Skip BoP items (index 11 of GetItemInfo is the bindType; 1 = BoP)
        local bindType = select(11, GetItemInfo(itemID))
        if bindType ~= 1 then
            local price, source = GetMarketValue(itemID)
            if price and source then
                tooltip:AddLine("|cFF00FF00Market Value: " .. GetCoinTextureString(price) .. " (" .. source .. ")|r")
            end
        end
    end
end

local function getItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local id = itemLink:match("item:(%d+)")
    return id and tonumber(id) or nil
end

function Tracker:HookTooltips()
    if self._tooltipsHooked then return end
    self._tooltipsHooked = true
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if not tooltip or not tooltip.GetItem then return end
            local _, itemLink = tooltip:GetItem()
            local itemID = getItemIDFromLink(itemLink)
            if itemID then
                self:DecorateTooltip(tooltip, itemID)
            end
        end)
    end
end

function Tracker:HookMerchant()
    if self._merchantHooked then return end
    self._merchantHooked = true
    if not MerchantFrame_UpdateMerchantInfo then return end
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
        local perPage = MERCHANT_ITEMS_PER_PAGE or 10
        if not MerchantFrame or not MerchantFrame:IsShown() then return end
        for i = 1, perPage do
            local index = (((MerchantFrame.page or 1) - 1) * perPage) + i
            local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
            if itemButton then
                local itemLink = GetMerchantItemLink and GetMerchantItemLink(index)
                local itemID = getItemIDFromLink(itemLink)
                if itemID and self:IsRelevantItem(itemID) then
                    itemButton.IconBorder:SetVertexColor(0.227, 0.914, 1.000)
                    itemButton.IconBorder:Show()
                end
            end
        end
    end)
end

function Tracker:OnEnable()
    self:HookTooltips()
    self:HookMerchant()
end

function Tracker:GetEntries()
    return (Villa.HITData and Villa.HITData:GetTrackerEntries()) or {}
end

function Tracker:CreatePanel(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

function Tracker:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then return end
    frame._initialized = true
    self.rows = {}

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 18, -70)
    title:SetText("Housing tracker donor systems")

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    body:SetJustifyH("LEFT")
    body:SetText("HousingItemTracker donor behavior is now mounted under Villa for tooltip sourcing, merchant highlighting, and housing-relevant material awareness. This panel is the boring diagnostics cockpit for that donor brain.")

    local y = -140
    for _, entry in ipairs(self:GetEntries()) do
        local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 18, y)
        row:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
        row:SetHeight(54)
        row:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        row:SetBackdropColor(0.08, 0.10, 0.16, 0.94)
        row:SetBackdropBorderColor(0.22, 0.47, 0.96, 0.90)
        local rt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rt:SetPoint("TOPLEFT", 10, -8)
        rt:SetText(entry.title or "Unknown")
        local rs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rs:SetPoint("TOPLEFT", rt, "BOTTOMLEFT", 0, -4)
        rs:SetText(entry.subtitle or "")
        local rd = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rd:SetPoint("TOPLEFT", rs, "BOTTOMLEFT", 0, -4)
        rd:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        rd:SetJustifyH("LEFT")
        rd:SetText(entry.detail or "")
        self.rows[#self.rows + 1] = row
        y = y - 60
    end
end

function Tracker:Refresh()
    if not self.frame then return end
    self:InitUI(self.frame)
end
