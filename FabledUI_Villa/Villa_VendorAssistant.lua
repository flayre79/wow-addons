local Villa = _G.FabledUI_Villa
local VA = {}
Villa.VendorAssistant = VA
Villa:RegisterModule("VendorAssistant", VA)

-- 12.1.5 deletes the global GetCoinTextureString. This is what Blizzard's
-- removed shim pointed it at (Deprecated_CurrencyScript.lua).
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString

-- Vendor Assistant: collection state on the merchant window itself.
--
-- Two halves, both driven from the same scan:
--   1. A check mark drawn on every merchant slot whose decor is already
--      collected, so a vendor grid answers "what do I still need" at a glance
--      instead of item by item.
--   2. A drawer beside the merchant frame listing exactly the decor this
--      vendor sells that you are missing, plus anything here that is on a
--      wishlist, with a running gold total for the missing set.
--
-- Everything it needs already exists in Villa: Villa:ItemIDToDecorID and
-- Villa:IsDecorRecordCollected for state, Villa.Wishlist for the stars, and
-- Villa.VendorCapture for the cost of each slot. This module is presentation
-- over data the suite already banks -- it deliberately stores nothing of its
-- own beyond the drawer's open/closed preference.
--
-- Pattern reference: HomeDecor Systems/Vendor/CheckMarks.lua +
-- UI/Vendor/VendorAssistant.lua, which is the addon this replaces.

local TK = _G.FabledUI_UIToolkit

local DRAWER_WIDTH   = 300
local TAB_WIDTH      = 26
local TAB_HEIGHT     = 190
local ROW_HEIGHT     = 30
local ACCENT         = { 0.227, 0.914, 1.0 }
local CHECK_ATLAS    = "common-icon-checkmark"
local CHECK_FALLBACK = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- ============================================================
-- Merchant slot readers
-- ============================================================
-- 12.0 removed the global GetMerchantItemInfo in favour of
-- C_MerchantFrame.GetItemInfo, which returns a table. Same shim
-- Villa_VendorCapture uses -- see the note there about why calling the dead
-- global silently captured nothing.

local function MerchantSlotItemID(index)
    if type(GetMerchantItemID) == "function" then
        local ok, id = pcall(GetMerchantItemID, index)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if type(GetMerchantItemLink) == "function" then
        local ok, link = pcall(GetMerchantItemLink, index)
        if ok and type(link) == "string" then
            return tonumber(link:match("item:(%d+)"))
        end
    end
    return nil
end

local function MerchantSlotInfo(index)
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" then
            return info.name, info.texture, info.price, info.hasExtendedCost
        end
        return nil
    end
    if type(GetMerchantItemInfo) == "function" then
        local nm, tex, price, _, _, _, _, ext = GetMerchantItemInfo(index)
        return nm, tex, price, ext
    end
    return nil
end

-- Exposed as a swappable seam purely so tests can feed it. The simulator ships
-- its own C_MerchantFrame and shadows any stub, so a test that stubs the global
-- silently reads the simulator's prices instead of its own fixture -- which is
-- how the shopping-total bug would have shipped looking tested.
VA.ReadSlotInfo = MerchantSlotInfo
VA.ReadSlotItemID = MerchantSlotItemID

-- ============================================================
-- Scan
-- ============================================================

-- Rows for every decor slot the open merchant sells, classified. Pure read: it
-- does not write to the capture DB -- Villa_VendorCapture owns that, and having
-- two writers to one table is how the counts drift.
function VA:ScanVendor()
    local rows, missing, wishlisted = {}, 0, 0

    if type(GetMerchantNumItems) ~= "function" then
        self.rows, self.missingCount, self.wishlistCount = rows, 0, 0
        return rows
    end

    local total = GetMerchantNumItems() or 0
    for index = 1, total do
        local itemID = self.ReadSlotItemID(index)
        local decorID = itemID and Villa:ItemIDToDecorID(itemID) or nil
        if itemID and decorID then
            local name, texture, price, extended = self.ReadSlotInfo(index)
            local collected = Villa:IsDecorRecordCollected(decorID) and true or false
            local starred = false
            if Villa.Wishlist and Villa.Wishlist.IsOnAnyWishlist then
                starred = Villa.Wishlist:IsOnAnyWishlist(itemID) and true or false
            end

            rows[#rows + 1] = {
                index     = index,
                itemID    = itemID,
                decorID   = decorID,
                name      = name or ("Item " .. itemID),
                texture   = texture,
                -- Extended-cost slots (currency/token) have no gold price, so
                -- they are excluded from the shopping total rather than
                -- silently counted as free.
                price     = (not extended) and price or nil,
                extended  = extended == true,
                collected = collected,
                starred   = starred,
            }
            if not collected then missing = missing + 1 end
            if starred then wishlisted = wishlisted + 1 end
        end
    end

    self.rows          = rows
    self.missingCount  = missing
    self.wishlistCount = wishlisted
    return rows
end

function VA:GetRows(filter)
    local out = {}
    for _, row in ipairs(self.rows or {}) do
        if filter == "saved" then
            if row.starred then out[#out + 1] = row end
        else
            if not row.collected then out[#out + 1] = row end
        end
    end
    return out
end

-- Gold cost of everything still missing here. Extended-cost items contribute
-- nothing and are reported separately so the number is never a half-truth.
function VA:GetShoppingTotal()
    local copper, unpriced = 0, 0
    for _, row in ipairs(self.rows or {}) do
        if not row.collected then
            if row.price and row.price > 0 then
                copper = copper + row.price
            else
                unpriced = unpriced + 1
            end
        end
    end
    return copper, unpriced
end

-- ============================================================
-- Check marks on the merchant grid
-- ============================================================

local function EnsureCheck(button)
    if button.fabledDecorCheck then return button.fabledDecorCheck end
    local tex = button:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetSize(14, 14)
    tex:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    if tex.SetAtlas then
        tex:SetAtlas(CHECK_ATLAS, true)
    else
        tex:SetTexture(CHECK_FALLBACK)
    end
    tex:SetVertexColor(0.36, 0.94, 0.63, 0.95)
    tex:Hide()
    button.fabledDecorCheck = tex
    return tex
end

local function EnsureStar(button)
    if button.fabledDecorStar then return button.fabledDecorStar end
    local tex = button:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetSize(13, 13)
    tex:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    tex:SetTexture("Interface\\Common\\FavoritesIcon")
    tex:Hide()
    button.fabledDecorStar = tex
    return tex
end

function VA:HideAllMarks()
    local perPage = _G.MERCHANT_ITEMS_PER_PAGE or 10
    for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            if button.fabledDecorCheck then button.fabledDecorCheck:Hide() end
            if button.fabledDecorStar then button.fabledDecorStar:Hide() end
        end
    end
end

-- Paint the currently visible merchant page. Slot index has to be derived from
-- the page, not the button number: button 1 is merchant slot 13 on page 2.
function VA:UpdateCheckMarks()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if Villa.db and Villa.db.vendorAssistantMarks == false then
        self:HideAllMarks()
        return
    end

    local perPage = _G.MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1

    local byIndex = {}
    for _, row in ipairs(self.rows or {}) do
        byIndex[row.index] = row
    end

    for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local slot = (page - 1) * perPage + i
            local row = byIndex[slot]
            if row then
                EnsureCheck(button):SetShown(row.collected)
                EnsureStar(button):SetShown(row.starred and not row.collected)
            else
                if button.fabledDecorCheck then button.fabledDecorCheck:Hide() end
                if button.fabledDecorStar then button.fabledDecorStar:Hide() end
            end
        end
    end
end

-- ============================================================
-- Drawer
-- ============================================================

local function Paint(texture, r, g, b, a)
    texture:SetColorTexture(r, g, b, a or 1)
end

local function CreateStatTile(parent, label)
    local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tile:SetHeight(38)
    local bg = tile:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Paint(bg, 1, 1, 1, 0.05)

    tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tile.value:SetPoint("TOPLEFT", 6, -4)
    tile.value:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tile.label:SetPoint("BOTTOMLEFT", 6, 4)
    tile.label:SetText(label)
    return tile
end

function VA:EnsureDrawer()
    if self.drawer then return self.drawer end
    if not MerchantFrame then return nil end

    -- Parented to UIParent and merely anchored to the merchant frame: keeping
    -- our frames out of Blizzard's hierarchy avoids inheriting its show/hide
    -- and taint behaviour.
    local drawer = CreateFrame("Frame", "FabledUIVillaVendorDrawer", UIParent, "BackdropTemplate")
    drawer:SetSize(DRAWER_WIDTH, 400)
    drawer:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", -2, -12)
    drawer:SetFrameStrata(MerchantFrame:GetFrameStrata())
    drawer:SetFrameLevel(MerchantFrame:GetFrameLevel() + 5)
    drawer:Hide()

    local bg = drawer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Paint(bg, 0.04, 0.04, 0.07, 0.94)

    local edge = drawer:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    Paint(edge, ACCENT[1], ACCENT[2], ACCENT[3], 0.28)

    local title = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("FabledUI |cff3ae9ffVilla|r")

    local subtitle = drawer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Decor shopping list")

    -- Stat tiles
    local tiles = {}
    local names = { "Missing", "Saved", "Vendor" }
    for i = 1, 3 do
        local tile = CreateStatTile(drawer, names[i])
        tile:SetWidth((DRAWER_WIDTH - 20 - 8) / 3)
        if i == 1 then
            tile:SetPoint("TOPLEFT", 10, -46)
        else
            tile:SetPoint("TOPLEFT", tiles[i - 1], "TOPRIGHT", 4, 0)
        end
        tiles[i] = tile
    end
    drawer.tiles = tiles

    -- Filter tabs
    local function CreateTab(label, key, anchor)
        local btn = CreateFrame("Button", nil, drawer)
        btn:SetSize((DRAWER_WIDTH - 24) / 2, 22)
        if anchor then
            btn:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
        else
            btn:SetPoint("TOPLEFT", 10, -90)
        end
        local tbg = btn:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints()
        btn.bg = tbg
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(label)
        btn:SetScript("OnClick", function()
            VA.filter = key
            VA:RefreshDrawer()
        end)
        return btn
    end
    drawer.tabMissing = CreateTab("Missing", "missing", nil)
    drawer.tabSaved   = CreateTab("Saved", "saved", drawer.tabMissing)

    -- Scrolling row list
    local scroll = CreateFrame("ScrollFrame", nil, drawer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -118)
    scroll:SetPoint("BOTTOMRIGHT", -28, 34)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(DRAWER_WIDTH - 40, 1)
    scroll:SetScrollChild(content)
    drawer.scroll = scroll
    drawer.content = content
    drawer.rows = {}

    drawer.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    drawer.empty:SetPoint("TOP", 0, -20)
    drawer.empty:SetWidth(DRAWER_WIDTH - 60)
    drawer.empty:Hide()

    drawer.footer = drawer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    drawer.footer:SetPoint("BOTTOMLEFT", 10, 10)
    drawer.footer:SetPoint("BOTTOMRIGHT", -10, 10)
    drawer.footer:SetJustifyH("LEFT")

    -- Side tab: the drawer's toggle, riding the merchant frame's right edge.
    local tab = CreateFrame("Button", nil, UIParent)
    tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    tab:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", -2, -60)
    tab:SetFrameStrata(MerchantFrame:GetFrameStrata())
    tab:SetFrameLevel(MerchantFrame:GetFrameLevel() + 4)
    local tabBg = tab:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    Paint(tabBg, 0.04, 0.04, 0.07, 0.94)
    local tabEdge = tab:CreateTexture(nil, "BORDER")
    tabEdge:SetPoint("TOPLEFT", -1, 1)
    tabEdge:SetPoint("BOTTOMRIGHT", 1, -1)
    Paint(tabEdge, ACCENT[1], ACCENT[2], ACCENT[3], 0.28)
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER")
    tab.text:SetText("V\nI\nL\nL\nA")
    tab.text:SetSpacing(1)
    tab:SetScript("OnClick", function() VA:ToggleDrawer() end)
    tab:SetScript("OnEnter", function(selfTab)
        GameTooltip:SetOwner(selfTab, "ANCHOR_RIGHT")
        GameTooltip:SetText("Villa decor shopping list")
        GameTooltip:AddLine("Decor this vendor sells that you have not collected.", 0.8, 0.85, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:Hide()
    drawer.tab = tab

    if TK and TK.Themes and TK.Themes.Apply then
        pcall(TK.Themes.Apply, TK.Themes, drawer, "Dark")
    end

    self.drawer = drawer
    return drawer
end

local function StyleTab(button, active)
    if active then
        Paint(button.bg, ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
        button.text:SetTextColor(0.93, 0.92, 0.98)
    else
        Paint(button.bg, 1, 1, 1, 0.05)
        button.text:SetTextColor(0.61, 0.60, 0.76)
    end
end

function VA:AcquireRow(index)
    local drawer = self.drawer
    if drawer.rows[index] then return drawer.rows[index] end

    local row = CreateFrame("Button", nil, drawer.content)
    row:SetSize(DRAWER_WIDTH - 40, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + 2)))

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Paint(bg, 1, 1, 1, 0.04)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 4, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT", -26, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    -- Star toggles the item on the active wishlist -- the same list the Villa
    -- window and its right-click menus use, not a private one.
    row.star = CreateFrame("Button", nil, row)
    row.star:SetSize(18, 18)
    row.star:SetPoint("RIGHT", -4, 0)
    row.star.tex = row.star:CreateTexture(nil, "ARTWORK")
    row.star.tex:SetAllPoints()
    row.star.tex:SetTexture("Interface\\Common\\FavoritesIcon")
    row.star:SetScript("OnClick", function()
        local itemID = row._itemID
        if not itemID or not Villa.Wishlist then return end
        if Villa.Wishlist:IsOnAnyWishlist(itemID) then
            Villa.Wishlist:RemoveItem(itemID)
        else
            Villa.Wishlist:AddItem(itemID)
        end
        VA:ScanVendor()
        VA:RefreshDrawer()
        VA:UpdateCheckMarks()
    end)

    row:SetScript("OnEnter", function(selfRow)
        if not selfRow._itemID then return end
        GameTooltip:SetOwner(selfRow, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(selfRow._itemID)
        GameTooltip:Show()
        Paint(bg, ACCENT[1], ACCENT[2], ACCENT[3], 0.12)
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Paint(bg, 1, 1, 1, 0.04)
    end)

    drawer.rows[index] = row
    return row
end

function VA:RefreshDrawer()
    local drawer = self.drawer
    if not drawer or not drawer:IsShown() then return end

    local filter = self.filter or "missing"
    StyleTab(drawer.tabMissing, filter == "missing")
    StyleTab(drawer.tabSaved, filter == "saved")

    drawer.tiles[1].value:SetText(tostring(self.missingCount or 0))
    drawer.tiles[2].value:SetText(tostring(self.wishlistCount or 0))
    drawer.tiles[3].value:SetText(tostring(#(self.rows or {})))

    local list = self:GetRows(filter)
    for index, data in ipairs(list) do
        local row = self:AcquireRow(index)
        row._itemID = data.itemID
        row.icon:SetTexture(data.texture)
        row.label:SetText(data.name)
        row.star.tex:SetVertexColor(data.starred and 1 or 0.35,
                                    data.starred and 0.82 or 0.35,
                                    data.starred and 0.25 or 0.35)
        row:Show()
    end
    for index = #list + 1, #drawer.rows do
        drawer.rows[index]:Hide()
    end
    drawer.content:SetHeight(math.max(1, #list * (ROW_HEIGHT + 2)))

    if #list == 0 then
        drawer.empty:SetText(filter == "saved"
            and "Nothing here is on a wishlist."
            or "You already own every decor this vendor sells.")
        drawer.empty:Show()
    else
        drawer.empty:Hide()
    end

    local copper, unpriced = self:GetShoppingTotal()
    local money = (GetCoinTextureString and copper > 0) and GetCoinTextureString(copper) or "-"
    if unpriced > 0 then
        drawer.footer:SetText(string.format("Missing total: %s  |cff8f8ab8(+%d token)|r", money, unpriced))
    else
        drawer.footer:SetText("Missing total: " .. money)
    end
end

function VA:ToggleDrawer()
    local drawer = self:EnsureDrawer()
    if not drawer then return end
    if drawer:IsShown() then
        drawer:Hide()
        if Villa.db then Villa.db.vendorDrawerOpen = false end
    else
        drawer:Show()
        if Villa.db then Villa.db.vendorDrawerOpen = true end
        self:RefreshDrawer()
    end
end

-- ============================================================
-- Events
-- ============================================================

function VA:Update()
    self:ScanVendor()
    self:UpdateCheckMarks()
    self:RefreshDrawer()
end

function VA:OnMerchantShow()
    if Villa.db and Villa.db.vendorAssistant == false then return end
    local drawer = self:EnsureDrawer()
    if not drawer then return end

    self:ScanVendor()

    -- The tab only appears when this vendor actually sells decor; on a
    -- reagent vendor it would be noise.
    local hasDecor = #(self.rows or {}) > 0
    drawer.tab:SetShown(hasDecor)
    if hasDecor and Villa.db and Villa.db.vendorDrawerOpen then
        drawer:Show()
    end

    self:UpdateCheckMarks()
    self:RefreshDrawer()
end

function VA:OnMerchantClosed()
    self:HideAllMarks()
    if self.drawer then
        self.drawer:Hide()
        self.drawer.tab:Hide()
    end
end

function VA:OnEnable()
    if self._frame then return end
    self.filter = "missing"
    self.rows = {}

    local frame = CreateFrame("Frame")
    self._frame = frame
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_UPDATE")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then
            VA:OnMerchantClosed()
            return
        end
        -- Defer a tick: on MERCHANT_SHOW the slot data is not fully populated
        -- yet, which is the same reason Villa_VendorCapture waits.
        C_Timer.After(0.1, function()
            local ok, err = pcall(VA.OnMerchantShow, VA)
            if not ok and not VA._errorReported then
                VA._errorReported = true
                Villa:Print("|cffff5555Vendor assistant failed:|r " .. tostring(err))
            end
        end)
    end)

    -- Repaint on page turn. MerchantFrame_Update runs for every page change and
    -- every buy, and the check marks are keyed to slot index, so they have to
    -- follow it.
    if type(_G.MerchantFrame_Update) == "function" and not self._hooked then
        self._hooked = true
        hooksecurefunc("MerchantFrame_Update", function()
            if MerchantFrame and MerchantFrame:IsShown() then
                pcall(VA.UpdateCheckMarks, VA)
            end
        end)
    end
end
