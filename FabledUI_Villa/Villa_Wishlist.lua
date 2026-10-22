local Villa = _G.FabledUI_Villa
local Wishlist = {}
Villa.Wishlist = Wishlist
Villa:RegisterModule("Wishlist", Wishlist)

Wishlist.panelTitle = "Villa Wishlist"
Wishlist.panelSubtitle = "Per-character saved decor wishlists. Right-click any decor item to add it."

-- ============================================================
-- Storage helpers (per-character wishlists)
-- ============================================================

local function GetCharKey()
    local name = (UnitName and UnitName("player")) or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "Realm"
    return name .. "-" .. realm
end

local function GetDB()
    local db = Villa.db
    if not db then return nil end
    db.wishlists = db.wishlists or {}
    local key = GetCharKey()
    db.wishlists[key] = db.wishlists[key] or {}
    -- A character may have multiple named wishlists; default list "Default"
    if not next(db.wishlists[key]) then
        db.wishlists[key]["Default"] = { name = "Default", entries = {} }
        db.wishlists[key]._activeList = "Default"
    end
    return db, key
end

local function GetCharLists()
    local db, key = GetDB()
    if not db or not key then return nil, nil end
    return db.wishlists[key], key
end

-- ============================================================
-- Public API
-- ============================================================

function Wishlist:GetActive()
    local lists = GetCharLists()
    if not lists then return nil end
    local active = lists._activeList
    if active and lists[active] then
        return active
    end
    -- Fall back to first available
    for k in pairs(lists) do
        if k ~= "_activeList" then
            lists._activeList = k
            return k
        end
    end
    return nil
end

function Wishlist:SetActive(name)
    local lists = GetCharLists()
    if not lists or not lists[name] then return end
    lists._activeList = name
end

function Wishlist:GetAll()
    return GetCharLists() or {}
end

function Wishlist:GetList(name)
    local lists = GetCharLists()
    if not lists or not name then return nil end
    return lists[name]
end

function Wishlist:CreateList(name)
    if not name or name == "" then return false end
    local lists = GetCharLists()
    if not lists then return false end
    if lists[name] then return false end
    lists[name] = { name = name, entries = {} }
    lists._activeList = name
    return true
end

function Wishlist:DeleteList(name)
    local lists = GetCharLists()
    if not lists or not name then return end
    lists[name] = nil
    if lists._activeList == name then
        lists._activeList = nil
        for k in pairs(lists) do
            if k ~= "_activeList" then
                lists._activeList = k
                break
            end
        end
    end
end

function Wishlist:AddItem(itemID, listName, note)
    itemID = tonumber(itemID)
    if not itemID then return false end
    local lists = GetCharLists()
    if not lists then return false end
    listName = listName or self:GetActive() or "Default"
    if not lists[listName] then
        lists[listName] = { name = listName, entries = {} }
    end
    if lists[listName].entries[itemID] then
        return false -- already on the list
    end
    lists[listName].entries[itemID] = {
        addedOn = time(),
        note = note or "",
    }
    return true
end

function Wishlist:RemoveItem(itemID, listName)
    itemID = tonumber(itemID)
    if not itemID then return end
    local lists = GetCharLists()
    if not lists then return end
    listName = listName or self:GetActive() or "Default"
    if lists[listName] and lists[listName].entries then
        lists[listName].entries[itemID] = nil
    end
end

function Wishlist:Contains(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    local lists = GetCharLists()
    if not lists then return false end
    for name, list in pairs(lists) do
        if name ~= "_activeList" and type(list) == "table" and list.entries and list.entries[itemID] then
            return true, name
        end
    end
    return false
end

-- Used by Villa_AcquiredAlert (also re-exported by tests)
function Wishlist:IsOnAnyWishlist(itemID)
    local found = self:Contains(itemID)
    return found
end

-- ============================================================
-- Helpers
-- ============================================================

local function GetItemNameAndIcon(itemID)
    -- Call C_Item.GetItemInfo directly. Wrapping a multi-return call in
    -- parentheses or an and/or chain truncates it to its FIRST value, so the
    -- previous form left `icon` nil on every call and item icons never drew.
    -- (The legacy global GetItemInfo is gone in modern retail anyway.)
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return name or ("Item #" .. tostring(itemID)), icon
end

local function IsItemCollected(itemID)
    if Villa.GetCollectionState then
        local state = Villa:GetCollectionState(itemID)
        return state and state.known or false
    end
    return false
end

local function GetSortedListNames(lists)
    local out = {}
    for k in pairs(lists or {}) do
        if k ~= "_activeList" then
            out[#out + 1] = k
        end
    end
    table.sort(out)
    return out
end

local function GetSortedEntries(list)
    if not list or not list.entries then return {} end
    local out = {}
    for itemID, info in pairs(list.entries) do
        out[#out + 1] = { itemID = itemID, addedOn = info.addedOn or 0, note = info.note or "" }
    end
    table.sort(out, function(a, b)
        return (a.addedOn or 0) > (b.addedOn or 0)
    end)
    return out
end

-- ============================================================
-- Panel
-- ============================================================

function Wishlist:CreatePanel(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

function Wishlist:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then return end
    frame._initialized = true

    -- Sidebar (saved lists)
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 16, -62)
    sidebar:SetPoint("BOTTOMLEFT", 16, 18)
    sidebar:SetWidth(180)
    sidebar:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    sidebar:SetBackdropColor(0.04, 0.05, 0.10, 0.92)
    sidebar:SetBackdropBorderColor(0.28, 0.26, 0.48, 0.88)
    self.sidebar = sidebar

    local sideHeader = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sideHeader:SetPoint("TOPLEFT", 10, -10)
    sideHeader:SetText("Wishlists")

    local sideScroll = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
    sideScroll:SetPoint("TOPLEFT", 6, -32)
    sideScroll:SetPoint("BOTTOMRIGHT", -22, 38)
    local sideContent = CreateFrame("Frame", nil, sideScroll)
    sideContent:SetSize(1, 1)
    sideScroll:SetScrollChild(sideContent)
    self.sideScroll = sideScroll
    self.sideContent = sideContent
    self.sideRows = {}

    local newBtn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    newBtn:SetSize(80, 22)
    newBtn:SetPoint("BOTTOMLEFT", 8, 8)
    newBtn:SetText("+ New")
    newBtn:SetScript("OnClick", function() self:PromptNewList() end)

    local delBtn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    delBtn:SetSize(70, 22)
    delBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    delBtn:SetText("Delete")
    delBtn:SetScript("OnClick", function()
        local active = self:GetActive()
        if active then
            self:DeleteList(active)
            self:Refresh()
        end
    end)

    -- Detail
    local detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, 0)
    detail:SetPoint("BOTTOMRIGHT", -16, 18)
    detail:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    detail:SetBackdropColor(0.04, 0.05, 0.10, 0.92)
    detail:SetBackdropBorderColor(0.36, 0.31, 0.62, 0.85)
    self.detailFrame = detail

    local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailTitle:SetPoint("TOPLEFT", 12, -10)
    detailTitle:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    detailTitle:SetJustifyH("LEFT")
    self.detailTitle = detailTitle

    local detailSub = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailSub:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -4)
    detailSub:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    detailSub:SetJustifyH("LEFT")
    self.detailSub = detailSub

    local itemScroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", 12, -52)
    itemScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -28, 14)
    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetSize(1, 1)
    itemScroll:SetScrollChild(itemContent)
    self.itemScroll = itemScroll
    self.itemContent = itemContent
    self.itemRows = {}
end

function Wishlist:PromptNewList()
    if not StaticPopupDialogs["FABLEDUI_VILLA_NEW_WISHLIST"] then
        StaticPopupDialogs["FABLEDUI_VILLA_NEW_WISHLIST"] = {
            text = "Enter a name for the new wishlist:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            maxLetters = 48,
            OnAccept = function(dialog)
                local name = dialog.editBox:GetText():match("^%s*(.-)%s*$")
                if name and name ~= "" then
                    Wishlist:CreateList(name)
                    Wishlist:SetActive(name)
                    Wishlist:Refresh()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
    end
    StaticPopup_Show("FABLEDUI_VILLA_NEW_WISHLIST")
end

function Wishlist:RefreshSidebar()
    for _, row in ipairs(self.sideRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.sideRows = {}

    local lists = self:GetAll()
    local names = GetSortedListNames(lists)
    local active = self:GetActive()
    local y = 0
    local width = math.max(140, (self.sideScroll:GetWidth() or 140) - 10)

    for _, name in ipairs(names) do
        local list = lists[name]
        local entryCount = 0
        if list and list.entries then
            for _ in pairs(list.entries) do entryCount = entryCount + 1 end
        end
        local isSelected = (name == active)
        local row = CreateFrame("Button", nil, self.sideContent, "BackdropTemplate")
        row:SetSize(width, 28)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({
            bgFile   = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        row:SetBackdropColor(isSelected and 0.09 or 0.05, isSelected and 0.11 or 0.07, isSelected and 0.20 or 0.14, 0.92)
        row:SetBackdropBorderColor(isSelected and 0.75 or 0.28, isSelected and 0.65 or 0.26, isSelected and 0.25 or 0.48, 0.88)

        local label = row:CreateFontString(nil, "OVERLAY", isSelected and "GameFontNormal" or "GameFontDisable")
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetText(string.format("%s (%d)", name, entryCount))

        local capturedName = name
        row:SetScript("OnClick", function()
            self:SetActive(capturedName)
            self:Refresh()
        end)

        self.sideRows[#self.sideRows + 1] = row
        y = y + 32
    end

    self.sideContent:SetWidth(width)
    self.sideContent:SetHeight(math.max(1, y))
end

function Wishlist:RefreshDetail()
    for _, row in ipairs(self.itemRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.itemRows = {}

    local active = self:GetActive()
    local list = active and self:GetList(active)
    if not list then
        if self.detailTitle then self.detailTitle:SetText("No wishlist selected") end
        if self.detailSub then self.detailSub:SetText("Create a wishlist on the left to begin.") end
        return
    end

    local entries = GetSortedEntries(list)
    local collected = 0
    for _, e in ipairs(entries) do
        if IsItemCollected(e.itemID) then collected = collected + 1 end
    end

    if self.detailTitle then self.detailTitle:SetText(list.name or "Wishlist") end
    if self.detailSub then
        self.detailSub:SetText(string.format("%d items - %d collected", #entries, collected))
    end

    local width = math.max(250, (self.itemScroll:GetWidth() or 300) - 24)
    local y = 0
    for _, entry in ipairs(entries) do
        local itemName, iconID = GetItemNameAndIcon(entry.itemID)
        local isCollected = IsItemCollected(entry.itemID)

        local row = CreateFrame("Button", nil, self.itemContent, "BackdropTemplate")
        row:SetSize(width, 42)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({
            bgFile   = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 10,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(isCollected and 0.04 or 0.06, isCollected and 0.10 or 0.08, isCollected and 0.06 or 0.16, 0.90)
        row:SetBackdropBorderColor(isCollected and 0.26 or 0.32, isCollected and 0.55 or 0.36, isCollected and 0.26 or 0.48, 0.80)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 6, 0)
        if iconID then icon:SetTexture(iconID) end

        local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", 42, -6)
        nameLabel:SetPoint("RIGHT", row, "RIGHT", -76, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText((isCollected and "|cff66cc66[Collected] |r" or "") .. itemName)

        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("BOTTOMLEFT", 42, 6)
        sub:SetJustifyH("LEFT")
        local addedTxt = "Added " .. (entry.addedOn and date("%Y-%m-%d", entry.addedOn) or "?")
        sub:SetText(addedTxt .. (entry.note ~= "" and ("  -  " .. entry.note) or ""))

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 20)
        removeBtn:SetPoint("RIGHT", -6, 0)
        removeBtn:SetText("Remove")
        local capturedID = entry.itemID
        local capturedList = list.name
        removeBtn:SetScript("OnClick", function()
            Wishlist:RemoveItem(capturedID, capturedList)
            Wishlist:RefreshDetail()
            Wishlist:RefreshSidebar()
        end)

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(entry.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        self.itemRows[#self.itemRows + 1] = row
        y = y + 46
    end

    self.itemContent:SetWidth(width)
    self.itemContent:SetHeight(math.max(1, y))
end

function Wishlist:Refresh()
    if not self.frame then return end
    self:InitUI(self.frame)
    self:RefreshSidebar()
    self:RefreshDetail()
end

-- ============================================================
-- Context-menu helper (called from any decor row right-click)
-- ============================================================

function Wishlist:ShowAddMenu(itemID, anchorFrame)
    itemID = tonumber(itemID)
    if not itemID then return end

    local lists = self:GetAll()
    local names = GetSortedListNames(lists)

    local menuList = {}
    menuList[#menuList + 1] = { text = "Add to Wishlist", isTitle = true, notCheckable = true }
    for _, name in ipairs(names) do
        local capturedName = name
        local already = lists[name].entries and lists[name].entries[itemID]
        menuList[#menuList + 1] = {
            text = name .. (already and "  (already added)" or ""),
            notCheckable = true,
            disabled = already and true or false,
            func = function()
                if Wishlist:AddItem(itemID, capturedName) then
                    Villa:Print("Added to wishlist: " .. capturedName)
                end
            end,
        }
    end
    menuList[#menuList + 1] = { text = "", disabled = true, notCheckable = true }
    menuList[#menuList + 1] = {
        text = "New wishlist...",
        notCheckable = true,
        func = function() Wishlist:PromptNewList() end,
    }

    if _G.MenuUtil and type(_G.MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, anchorFrame or UIParent, function(_, rootDescription)
            for _, entry in ipairs(menuList) do
                if entry.isTitle then
                    rootDescription:CreateTitle(entry.text)
                elseif not entry.disabled and entry.func then
                    rootDescription:CreateButton(entry.text, entry.func)
                end
            end
        end)
        if ok then return end
    end
    if _G.EasyMenu then
        EasyMenu(menuList, _G.DropDownList1 or UIParent, anchorFrame or "cursor", 0, 0, "MENU")
    end
end

-- ============================================================
-- Acquired toast (UIToolkit T.Toast)
-- ============================================================

function Wishlist:NotifyAcquired(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    local TK = rawget(_G, "FabledUI_UIToolkit")
    if not (TK and TK.Toast and TK.Toast.Show) then return end
    local name, icon = GetItemNameAndIcon(itemID)
    TK.Toast:Show("Wishlist item acquired: " .. name, icon or itemID, 4.0)
end

-- ============================================================
-- Lifecycle
-- ============================================================

function Wishlist:OnInitialize()
    -- Touch the per-character store so it exists even before first add.
    GetDB()
end
