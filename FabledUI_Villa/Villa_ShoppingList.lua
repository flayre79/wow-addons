local Villa = _G.FabledUI_Villa
local ShoppingList = {}
Villa.ShoppingList = ShoppingList
Villa:RegisterModule("ShoppingList", ShoppingList)

ShoppingList.panelTitle = "Shopping List"
ShoppingList.panelSubtitle = "Build vendor-run wishlists and track what you still need to collect."

-- ============================================================
-- Data API
-- ============================================================

local function GetDB()
    local db = Villa.db
    if not db then return nil end
    db.shoppingLists = db.shoppingLists or {}
    return db
end

function ShoppingList:CreateList(name)
    if not name or name == "" then return false end
    local db = GetDB()
    if not db then return false end
    if db.shoppingLists[name] then return false end
    db.shoppingLists[name] = {
        name    = name,
        entries = {},
    }
    return true
end

function ShoppingList:DeleteList(name)
    if not name then return end
    local db = GetDB()
    if not db then return end
    db.shoppingLists[name] = nil
    if db.activeList == name then
        db.activeList = nil
    end
end

function ShoppingList:AddItem(listName, itemID, quantity, source)
    itemID  = tonumber(itemID)
    if not listName or not itemID then return false end
    local db = GetDB()
    if not db or not db.shoppingLists[listName] then return false end
    local entries = db.shoppingLists[listName].entries
    if entries[itemID] then
        entries[itemID].quantity = math.max(1, (entries[itemID].quantity or 1) + (tonumber(quantity) or 1))
        if source then entries[itemID].source = source end
    else
        entries[itemID] = {
            itemID   = itemID,
            quantity = tonumber(quantity) or 1,
            source   = source or "vendor",
            note     = "",
        }
    end
    return true
end

function ShoppingList:RemoveItem(listName, itemID)
    itemID = tonumber(itemID)
    if not listName or not itemID then return end
    local db = GetDB()
    if not db or not db.shoppingLists[listName] then return end
    db.shoppingLists[listName].entries[itemID] = nil
end

function ShoppingList:GetList(listName)
    local db = GetDB()
    if not db then return nil end
    return db.shoppingLists[listName]
end

function ShoppingList:GetAll()
    local db = GetDB()
    if not db then return {} end
    return db.shoppingLists
end

function ShoppingList:SetActive(listName)
    local db = GetDB()
    if not db then return end
    db.activeList = listName
end

function ShoppingList:GetActive()
    local db = GetDB()
    if not db then return nil end
    return db.activeList
end

function ShoppingList:IsInAnyList(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local db = GetDB()
    if not db then return nil end
    for listName, list in pairs(db.shoppingLists) do
        if list.entries and list.entries[itemID] then
            return listName
        end
    end
    return nil
end

-- ============================================================
-- Helpers
-- ============================================================

local function GetSortedListNames()
    local names = {}
    local db = GetDB()
    if not db then return names end
    for name in pairs(db.shoppingLists) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function GetSortedEntries(list)
    if not list or not list.entries then return {} end
    local out = {}
    for _, entry in pairs(list.entries) do
        out[#out + 1] = entry
    end
    table.sort(out, function(a, b)
        if (a.source or "") ~= (b.source or "") then
            return (a.source or "") < (b.source or "")
        end
        return (a.itemID or 0) < (b.itemID or 0)
    end)
    return out
end

-- The old first branch called `GetItemCount` from inside this local function,
-- which is this function itself, not the global: endless recursion on every
-- row. The global is gone in 12.1.5 anyway; C_Item's is the only one.
local function GetItemCount(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID) or 0
    end
    return 0
end

local function GetItemName(itemID)
    if not itemID then return "Item #?" end
    local name = C_Item and C_Item.GetItemInfo and select(1, C_Item.GetItemInfo(itemID))
    if not name and GetItemInfo then
        name = GetItemInfo(itemID)
    end
    return name or ("Item #" .. tostring(itemID))
end

-- ============================================================
-- Panel
-- ============================================================

function ShoppingList:CreatePanel(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    self.frame = frame
    return frame
end

function ShoppingList:InitUI(frame)
    frame = frame or self.frame
    if not frame or frame._initialized then return end
    frame._initialized = true

    -- ---------- left sidebar ----------
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
    sideHeader:SetText("Saved Lists")

    local sideScroll = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
    sideScroll:SetPoint("TOPLEFT", 6, -32)
    sideScroll:SetPoint("BOTTOMRIGHT", -22, 38)
    local sideContent = CreateFrame("Frame", nil, sideScroll)
    sideContent:SetSize(1, 1)
    sideScroll:SetScrollChild(sideContent)
    self.sideScroll   = sideScroll
    self.sideContent  = sideContent
    self.sideRows     = {}

    local newBtn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    newBtn:SetSize(80, 22)
    newBtn:SetPoint("BOTTOMLEFT", 8, 8)
    newBtn:SetText("+ New List")
    newBtn:SetScript("OnClick", function()
        self:PromptNewList()
    end)

    local delBtn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    delBtn:SetSize(70, 22)
    delBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    delBtn:SetText("Delete")
    delBtn:SetScript("OnClick", function()
        local active = ShoppingList:GetActive()
        if active then
            ShoppingList:DeleteList(active)
            self:Refresh()
        end
    end)
    self.deleteBtn = delBtn

    -- ---------- right pane ----------
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
    itemScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -28, 46)
    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetSize(1, 1)
    itemScroll:SetScrollChild(itemContent)
    self.itemScroll   = itemScroll
    self.itemContent  = itemContent
    self.itemRows     = {}

    local waypointBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    waypointBtn:SetSize(180, 24)
    waypointBtn:SetPoint("BOTTOMLEFT", 12, 12)
    waypointBtn:SetText("Waypoint to Next Vendor")
    waypointBtn:SetScript("OnClick", function()
        self:WaypointNextVendor()
    end)
    self.waypointBtn = waypointBtn
end

function ShoppingList:PromptNewList()
    if not StaticPopupDialogs["FABLEDUI_VILLA_NEW_LIST"] then
        StaticPopupDialogs["FABLEDUI_VILLA_NEW_LIST"] = {
            text         = "Enter a name for the new shopping list:",
            button1      = "Create",
            button2      = "Cancel",
            hasEditBox   = true,
            maxLetters   = 48,
            OnAccept     = function(dialog)
                local name = dialog.editBox:GetText():match("^%s*(.-)%s*$")
                if name and name ~= "" then
                    ShoppingList:CreateList(name)
                    ShoppingList:SetActive(name)
                    ShoppingList:Refresh()
                end
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        }
    end
    StaticPopup_Show("FABLEDUI_VILLA_NEW_LIST")
end

function ShoppingList:RefreshSidebar()
    for _, row in ipairs(self.sideRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.sideRows = {}

    local names  = GetSortedListNames()
    local active = ShoppingList:GetActive()
    local y      = 0
    local width  = math.max(140, (self.sideScroll:GetWidth() or 140) - 10)

    for _, name in ipairs(names) do
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
        label:SetText(name)

        row:SetScript("OnClick", function()
            ShoppingList:SetActive(name)
            self:Refresh()
        end)

        self.sideRows[#self.sideRows + 1] = row
        y = y + 32
    end

    self.sideContent:SetWidth(width)
    self.sideContent:SetHeight(math.max(1, y))
end

function ShoppingList:RefreshDetail()
    for _, row in ipairs(self.itemRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.itemRows = {}

    local active = ShoppingList:GetActive()
    local list   = active and ShoppingList:GetList(active)

    if not list then
        if self.detailTitle then self.detailTitle:SetText("No list selected") end
        if self.detailSub   then self.detailSub:SetText("Select or create a list on the left.") end
        return
    end

    local entries = GetSortedEntries(list)
    if self.detailTitle then self.detailTitle:SetText(list.name) end
    if self.detailSub   then self.detailSub:SetText(string.format("%d items", #entries)) end

    local width = math.max(250, (self.itemScroll:GetWidth() or 300) - 24)
    local y = 0
    for _, entry in ipairs(entries) do
        local inBag   = GetItemCount(entry.itemID)
        local have    = math.min(inBag, entry.quantity or 1)
        local done    = have >= (entry.quantity or 1)

        local row = CreateFrame("Button", nil, self.itemContent, "BackdropTemplate")
        row:SetSize(width, 46)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetBackdrop({
            bgFile   = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 10,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(done and 0.04 or 0.06, done and 0.09 or 0.08, done and 0.06 or 0.16, 0.90)
        row:SetBackdropBorderColor(done and 0.26 or 0.32, done and 0.48 or 0.36, done and 0.26 or 0.48, 0.80)

        -- icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 6, 0)
        -- Direct call: an and/or chain truncates the multi-return to its first
        -- value, which left iconFileID nil and the icon blank on every row.
        local _, _, _, _, _, _, _, _, _, iconFileID = C_Item.GetItemInfo(entry.itemID)
        if iconFileID then
            icon:SetTexture(iconFileID)
        end

        local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", 46, -6)
        nameLabel:SetPoint("RIGHT", row, "RIGHT", -76, 0)
        nameLabel:SetJustifyH("LEFT")
        local itemName = GetItemName(entry.itemID)
        nameLabel:SetText((done and "|cff66cc66[✓] |r" or "") .. itemName)

        local sourceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sourceLabel:SetPoint("BOTTOMLEFT", 46, 6)
        sourceLabel:SetJustifyH("LEFT")
        sourceLabel:SetText(string.format("%s  %d/%d", entry.source or "vendor", have, entry.quantity or 1))

        -- remove button
        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 20)
        removeBtn:SetPoint("RIGHT", -6, 0)
        removeBtn:SetText("Remove")
        local capturedItemID = entry.itemID
        removeBtn:SetScript("OnClick", function()
            ShoppingList:RemoveItem(active, capturedItemID)
            self:RefreshDetail()
        end)

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(entry.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        self.itemRows[#self.itemRows + 1] = row
        y = y + 50
    end

    self.itemContent:SetWidth(width)
    self.itemContent:SetHeight(math.max(1, y))
end

function ShoppingList:WaypointNextVendor()
    local active = ShoppingList:GetActive()
    local list   = active and ShoppingList:GetList(active)
    if not list then return end

    local entries = GetSortedEntries(list)
    for _, entry in ipairs(entries) do
        if (entry.source or "vendor") == "vendor" then
            -- Try to find vendor location from HomeData
            if Villa.HomeData and Villa.HomeData.GetSourceInfo then
                local info = Villa.HomeData:GetSourceInfo(entry.itemID)
                if info and info.mapID and info.x and info.y then
                    Villa:SetWaypoint(info.mapID, info.x, info.y, info.vendorName or "Shopping List Vendor")
                    return
                end
            end
            -- Fallback: search via GetDecorSourceInfo
            local src = Villa:GetDecorSourceInfo(entry.itemID)
            if src and src.mapID and src.x and src.y then
                Villa:SetWaypoint(src.mapID, src.x, src.y, src.vendorName or "Shopping List Vendor")
                return
            end
        end
    end
    Villa:Print("No vendor-source entries with known waypoints in this list.")
end

function ShoppingList:Refresh()
    if not self.frame then return end
    self:InitUI(self.frame)
    self:RefreshSidebar()
    self:RefreshDetail()
end

-- ============================================================
-- Context menu helpers (called from Vendors tab)
-- ============================================================

function ShoppingList:ShowAddMenu(itemID, source, anchorFrame)
    itemID = tonumber(itemID)
    if not itemID then return end

    if not _G.MenuUtil and not _G.EasyMenu then
        Villa:Print("No context menu library available.")
        return
    end

    local menuList = {}
    local names    = GetSortedListNames()

    for _, name in ipairs(names) do
        local listName = name
        menuList[#menuList + 1] = {
            text    = listName,
            notCheckable = true,
            func    = function()
                ShoppingList:AddItem(listName, itemID, 1, source or "vendor")
                Villa:Print("Added item to list: " .. listName)
            end,
        }
    end

    menuList[#menuList + 1] = {
        text    = "New List...",
        notCheckable = true,
        func    = function()
            ShoppingList:PromptNewList()
        end,
    }

    -- 12.0.5: prefer MenuUtil; EasyMenu was removed in modern clients.
    if _G.MenuUtil and type(_G.MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, anchorFrame or UIParent, function(_, rootDescription)
            for _, item in ipairs(menuList) do
                rootDescription:CreateButton(item.text, item.func)
            end
        end)
        if ok then return end
    end
    if _G.EasyMenu then
        EasyMenu(menuList, _G.DropDownList1 or UIParent, anchorFrame or "cursor", 0, 0, "MENU")
    end
end

-- ============================================================
-- OnInitialize: ensure DB fields exist
-- ============================================================

function ShoppingList:OnInitialize()
    local db = GetDB()
    if not db then return end
    db.shoppingLists = db.shoppingLists or {}
    -- activeList is nil by default (no active list selected)
end
