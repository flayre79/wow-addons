local K = Kleos
local U = K.UI
local W = K.Widgets

-- ============================================================================
-- UI_Tutorial
-- "Ingame explanation for first time users." Shown once, on the first time the
-- window is opened, and reachable afterwards through /kleos tutorial.
--
-- The seen flag lives in account storage, so it does not re-appear per
-- character.
-- ============================================================================

K.Tutorial = K.Tutorial or {}
local Tut = K.Tutorial

Tut.PAGES = {
    {
        title = "Browse everything",
        body = "The Browse tab indexes every achievement the client exposes — including the hidden "
            .. "tracking achievements Blizzard normally omits (tick Hidden). Filter by expansion, type, "
            .. "reward, faction and obtainability, or click a category on the left.",
    },
    {
        title = "Watch and exclude",
        body = "Watch an achievement to pin it to the Watch tab and the Kleos tracker. Exclude the ones "
            .. "you never want to see: they disappear from every list except the Excluded tab. "
            .. "Right-click any row for the full action menu, including Wowhead and related achievements.",
    },
    {
        title = "Rewards",
        body = "The Rewards tab groups achievements by what they actually give you: mounts, pets, titles, "
            .. "toys, transmog, tabards, teleports and housing decor. Decor rows name the decor items "
            .. "when the housing catalog can resolve them.",
    },
    {
        title = "Instances",
        body = "Inside a dungeon or raid, Kleos works out which achievements apply, snapshots their "
            .. "criteria when a boss pull starts, counts the mobs the criteria ask for, and tells you "
            .. "afterwards which ones you met or missed. Chat output stays off until you enable it in "
            .. "the settings.",
    },
    {
        title = "Your data",
        body = "The Data tab exports your watch list, exclusions, notes and objectives as text you can "
            .. "paste to an alt account, and holds the filter profiles. Summary shows points per "
            .. "expansion and per character; Calendar shows what you earned on any given day.",
    },
}

function Tut:Build()
    if self.frame then return self.frame end

    local frame = W:Panel(UIParent, "FabledUI_KleosTutorial")
    frame:SetSize(460, 260)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "FabledUI_KleosTutorial")

    frame.heading = W:Label(frame, "|cff4fd1c5Kleos|r", "GameFontNormalLarge")
    frame.heading:SetPoint("TOPLEFT", 16, -14)

    frame.title = W:Label(frame, "", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 16, -44)
    frame.title:SetPoint("TOPRIGHT", -16, -44)

    frame.body = W:Label(frame, "", "GameFontHighlightSmall")
    frame.body:SetPoint("TOPLEFT", 16, -70)
    frame.body:SetPoint("TOPRIGHT", -16, -70)
    frame.body:SetJustifyV("TOP")
    if frame.body.SetHeight then frame.body:SetHeight(120) end

    frame.progressLabel = W:Label(frame, "", "GameFontDisableSmall")
    frame.progressLabel:SetPoint("BOTTOMLEFT", 16, 14)

    frame.back = W:Button(frame, K.L.PREVIOUS or "Back", 90, 22, function()
        Tut:SetPage((self._page or 1) - 1)
    end)
    frame.back:SetPoint("BOTTOMRIGHT", -216, 10)

    frame.next = W:Button(frame, K.L.NEXT or "Next", 90, 22, function()
        if (Tut._page or 1) >= #Tut.PAGES then
            Tut:Finish()
        else
            Tut:SetPage((Tut._page or 1) + 1)
        end
    end)
    frame.next:SetPoint("BOTTOMRIGHT", -120, 10)

    frame.close = W:Button(frame, K.L.DONE or "Close", 100, 22, function() Tut:Finish() end)
    frame.close:SetPoint("BOTTOMRIGHT", -14, 10)

    self.frame = frame
    return frame
end

function Tut:SetPage(page)
    local frame = self:Build()
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    if page > #self.PAGES then page = #self.PAGES end
    self._page = page

    local entry = self.PAGES[page]
    frame.title:SetText("|cffffd100" .. entry.title .. "|r")
    frame.body:SetText(entry.body)
    frame.progressLabel:SetText(("%d / %d"):format(page, #self.PAGES))
    frame.back:SetEnabled(page > 1)
    frame.next:SetText(page >= #self.PAGES and (K.L.DONE or "Done") or (K.L.NEXT or "Next"))
    return page
end

function Tut:Show()
    local frame = self:Build()
    self:SetPage(self._page or 1)
    frame:Show()
    return frame
end

function Tut:Finish()
    if self.frame then self.frame:Hide() end
    if K.db and K.db.settings then
        K.db.settings.tutorialSeen = true
        K.Storage:CommitSoon()
    end
end

function Tut:MaybeShow()
    if not (K.db and K.db.settings) then return false end
    if K.db.settings.tutorialSeen then return false end
    -- Mark it seen as soon as it is shown: a player who closes it with Escape
    -- has still seen it, and a tutorial that keeps coming back is worse than
    -- one that appears once.
    K.db.settings.tutorialSeen = true
    K.Storage:CommitSoon()
    self:Show()
    return true
end

function Tut:Reset()
    if K.db and K.db.settings then
        K.db.settings.tutorialSeen = false
        K.Storage:CommitSoon()
    end
    self._page = 1
    return true
end
