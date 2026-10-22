local Villa = _G.FabledUI_Villa
local CatalogScan = {}
Villa.CatalogScan = CatalogScan
Villa:RegisterModule("CatalogScan", CatalogScan)

-- ============================================================================
-- Live decor catalog dump.
--
-- Villa's bundled datasets (BetterHomes / HIT / HDG / Codex / HousingVendor,
-- ~170k lines in FabledUI_DataVault_Villa) are imported donor data of uneven
-- quality. The client can tell us the truth directly: C_HousingCatalog exposes
-- a searcher that enumerates every catalog entry, and GetCatalogEntryInfo gives
-- per-entry identity and ownership. One scan replaces a lot of guessing, and
-- needs no vendor legwork -- unlike prices and vendor->item mapping, which are
-- NOT in the catalog and still require Villa_VendorCapture.
--
-- Written against the same API surface AllTheThings uses (src/Classes/Decor.lua):
--   searcher = C_HousingCatalog.CreateCatalogSearcher()
--   searcher:SetAutoUpdateOnParamChanges(false)
--   searcher:SetResultsUpdatedCallback(cb)   -- async; results arrive in cb
--   searcher:RunSearch()
--   entries = searcher:GetCatalogSearchResults()  -- each has .recordID
--   info    = C_HousingCatalog.GetCatalogEntryInfo(entry)
--
-- Deliberately NOT used: C_HousingCatalog.GetCatalogEntryDebugInfoForID, which
-- ATT documents as force-tainting.
-- ============================================================================

-- Blizzard returns 0xFFFFFFFF for "unknown quantity" on some entries; ATT hit
-- the same thing. Treat it as unknown rather than letting 4 billion into a sum.
local UNKNOWN_QTY = 4294967295

local issecretvalue = _G.issecretvalue or function() return false end

local function SafeNum(v)
    if v == nil or issecretvalue(v) then return nil end
    v = tonumber(v)
    if not v or v < 0 or v >= UNKNOWN_QTY then return nil end
    return v
end

local function SafeStr(v)
    if type(v) ~= "string" or v == "" or issecretvalue(v) then return nil end
    return v
end

-- Shares FabledUI_VillaCaptureDB with Villa_VendorCapture: same "verified
-- ground truth" bucket, already declared in the .toc, and keeping catalog +
-- vendor data together is what makes the coverage report below cheap.
local function DB()
    FabledUI_VillaCaptureDB = FabledUI_VillaCaptureDB or {}
    local db = FabledUI_VillaCaptureDB
    db.catalog     = db.catalog or {}      -- [decorID] = { name, itemID, owned, ... }
    db.catalogMeta = db.catalogMeta or {}  -- { lastScan, entryCount, ownedCount }
    return db
end

local function ResolveName(info, recordID)
    local name = SafeStr(info and info.name)
    if name then return name end
    if C_HousingDecor and type(C_HousingDecor.GetDecorName) == "function" then
        local ok, n = pcall(C_HousingDecor.GetDecorName, recordID)
        if ok then return SafeStr(n) end
    end
    return nil
end

function CatalogScan:IsAvailable()
    return C_HousingCatalog ~= nil
        and type(C_HousingCatalog.CreateCatalogSearcher) == "function"
        and type(C_HousingCatalog.GetCatalogEntryInfo) == "function"
end

-- ── Results handling ────────────────────────────────────────────────────────
function CatalogScan:OnResults()
    if not self._running then return end -- ignore spurious/late callbacks
    self._running = false

    local searcher = self._searcher
    if not searcher then return end

    local ok, entries = pcall(searcher.GetCatalogSearchResults, searcher)
    if not ok or type(entries) ~= "table" then
        Villa:Print("|cffff5555Catalog scan returned no usable results.|r")
        return
    end

    local db = DB()
    local decorType = Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Decor
    local seen, ownedCount, added = 0, 0, 0

    for i = 1, #entries do
        local entry = entries[i]
        local infoOk, info = pcall(C_HousingCatalog.GetCatalogEntryInfo, entry)
        if infoOk and type(info) == "table" then
            local entryType = info.entryID and info.entryID.entryType
            -- Only decor; the catalog also carries rooms/styles/other types.
            if decorType == nil or entryType == decorType then
                local recordID = SafeNum(info.entryID and info.entryID.recordID)
                             or SafeNum(entry.recordID)
                if recordID then
                    seen = seen + 1

                    -- Owned = placed + in-storage quantity + still-redeemable,
                    -- matching ATT's HowManyDecor.
                    local numPlaced  = SafeNum(info.numPlaced) or 0
                    local quantity   = SafeNum(info.quantity) or 0
                    local redeemable = SafeNum(info.remainingRedeemable) or 0
                    local total      = numPlaced + quantity + redeemable

                    local rec = db.catalog[recordID]
                    if not rec then
                        rec = {}
                        db.catalog[recordID] = rec
                        added = added + 1
                    end

                    rec.decorID             = recordID
                    rec.name                = ResolveName(info, recordID) or rec.name
                    rec.itemID              = SafeNum(info.itemID) or rec.itemID
                    rec.entryType           = SafeNum(entryType) or rec.entryType
                    rec.numPlaced           = numPlaced
                    rec.numStored           = SafeNum(info.numStored)
                    rec.quantity            = quantity
                    rec.remainingRedeemable = redeemable
                    rec.owned               = total

                    if total > 0 then ownedCount = ownedCount + 1 end
                end
            end
        end
    end

    db.catalogMeta.lastScan   = (time and time()) or nil
    db.catalogMeta.entryCount = seen
    db.catalogMeta.ownedCount = ownedCount

    if DataVault and DataVault.dirtyFlags then
        DataVault.dirtyFlags["FabledUI_VillaCaptureDB"] = true
    end

    Villa:Print(string.format(
        "Catalog scan: |cff5cf0a0%d|r decor entries (|cff5cf0a0%d|r new), |cff5cf0a0%d|r owned.",
        seen, added, ownedCount))

    if self._wantCoverage then
        self._wantCoverage = false
        self:PrintCoverage()
    end
end

-- ── Running a scan ──────────────────────────────────────────────────────────
function CatalogScan:Scan(alsoCoverage)
    if not self:IsAvailable() then
        Villa:Print("|cffff5555Housing catalog API unavailable on this client.|r")
        return false
    end
    if self._running then
        Villa:Print("Catalog scan already in progress.")
        return false
    end

    if not self._searcher then
        -- Do NOT type-check the result against "table": the searcher is a
        -- C-created object and can come back as userdata, which the previous
        -- check rejected outright. AllTheThings never type-checks it either.
        -- Accept anything non-nil and let the method probes below decide.
        local ok, searcher = pcall(C_HousingCatalog.CreateCatalogSearcher)
        if not ok then
            Villa:Print("|cffff5555Catalog searcher errored:|r " .. tostring(searcher))
            return false
        end
        if searcher == nil then
            Villa:Print("|cffff5555Catalog searcher came back nil.|r "
                .. "The housing catalog may need to be opened once first.")
            return false
        end
        -- If it exists but exposes no RunSearch, say so precisely rather than
        -- failing later with a vague message.
        if type(searcher.RunSearch) ~= "function" then
            Villa:Print(("|cffff5555Catalog searcher has no RunSearch|r (type=%s).")
                :format(type(searcher)))
            return false
        end
        self._searcher = searcher
        -- Scan on demand only; we don't want a callback storm as the player
        -- browses the in-game catalog UI.
        if type(searcher.SetAutoUpdateOnParamChanges) == "function" then
            pcall(searcher.SetAutoUpdateOnParamChanges, searcher, false)
        end
        if type(searcher.SetResultsUpdatedCallback) == "function" then
            pcall(searcher.SetResultsUpdatedCallback, searcher, function()
                CatalogScan:OnResults()
            end)
        end
    end

    self._running = true
    self._wantCoverage = alsoCoverage and true or false

    local ok = pcall(self._searcher.RunSearch, self._searcher)
    if not ok then
        self._running = false
        Villa:Print("|cffff5555Catalog search failed to start.|r")
        return false
    end

    -- Results are async. If the callback never lands, say so rather than
    -- leaving the player staring at nothing.
    C_Timer.After(8, function()
        if CatalogScan._running then
            CatalogScan._running = false
            Villa:Print("|cffff5555Catalog scan timed out|r (no results callback).")
        end
    end)
    return true
end

-- ── Reporting ───────────────────────────────────────────────────────────────
function CatalogScan:GetStats()
    local db = DB()
    local total, owned = 0, 0
    for _, rec in pairs(db.catalog) do
        total = total + 1
        if (rec.owned or 0) > 0 then owned = owned + 1 end
    end
    return total, owned, db.catalogMeta.lastScan
end

-- The actionable number: of every decor entry the client knows about, how many
-- do we have a *verified vendor source* for? That gap is exactly what vendor
-- tours still have to close, and it is the only thing the catalog can't tell us.
-- Returns sourced, total, ownedNoSource. Shared by PrintCoverage and the
-- Progress panel so both report identical numbers from one implementation.
function CatalogScan:GetCoverage()
    local db = DB()
    local total, sourced, ownedNoSource = 0, 0, 0
    local capture = Villa.VendorCapture

    for decorID, rec in pairs(db.catalog) do
        total = total + 1
        local verified = capture and capture.IsVerified and capture:IsVerified(decorID)
        if verified then
            sourced = sourced + 1
        elseif (rec.owned or 0) > 0 then
            ownedNoSource = ownedNoSource + 1
        end
    end

    return sourced, total, ownedNoSource
end

function CatalogScan:PrintCoverage()
    local sourced, total, ownedNoSource = self:GetCoverage()

    if total == 0 then
        Villa:Print("No catalog data yet — run |cff5cf0a0/villa catalogscan|r first.")
        return
    end

    Villa:Print(string.format(
        "Vendor coverage: |cff5cf0a0%d|r/|cff5cf0a0%d|r decor entries have a verified vendor (|cff5cf0a0%.1f%%|r).",
        sourced, total, (sourced / total) * 100))

    -- With zero captured vendors the "no known source" count is just the owned
    -- count wearing a disguise, and calling it quest/drop decor would be an
    -- unsupported claim. Only attribute a cause once there is vendor data to
    -- attribute against.
    if sourced == 0 then
        Villa:Print("  |cffffd166No vendor data captured yet|r — visit housing vendors to populate this.")
    else
        Villa:Print(string.format(
            "  |cffffd166%d|r owned with no known vendor source — likely quest/drop/achievement decor.",
            ownedNoSource))
    end
end

function CatalogScan:PrintStats()
    local total, owned, lastScan = self:GetStats()
    if total == 0 then
        Villa:Print("Catalog not scanned yet. Run |cff5cf0a0/villa catalogscan|r.")
        return
    end
    Villa:Print(string.format("Catalog: |cff5cf0a0%d|r decor entries, |cff5cf0a0%d|r owned.", total, owned))
    if lastScan and date then
        Villa:Print("  Last scan: " .. date("%Y-%m-%d %H:%M", lastScan))
    end
    self:PrintCoverage()
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────
function CatalogScan:OnEnable()
    -- No automatic scan on login: the catalog searcher is not guaranteed to be
    -- populated that early, and this should stay an explicit, cheap-to-repeat
    -- action rather than login-time work.
    DB()
end
