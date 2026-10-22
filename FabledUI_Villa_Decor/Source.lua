-- Parser for the housing catalog's sourceText.
--
-- C_HousingCatalog.GetCatalogEntryInfo(...).sourceText is Blizzard's own answer
-- to "where does this come from and what does it cost", and unlike the imported
-- donor datasets it is never stale. It is display text, though, so it has to be
-- taken apart. The shape below is from real strings in the owner's
-- HousingCompanion saved variables (2026-09-19), not from documentation:
--
--   |cFFFFD200Vendor: |rThroska|n|cFFFFD200Zone: |rRazorwind Shores|n
--   |cFFFFD200Zone: |rFounder's Point|n|cFFFFD200Cost: |r5|Hcurrency:3363|h|T...|t|h|n|n
--
--   * lines are separated by the literal two characters |n
--   * an empty line ends a block; each block is one way of getting the item
--   * a line is "|cXXXXXXXXLabel: |rValue"; a bare "|cXXXXXXXXShop|r" is the
--     real-money shop
--   * a requirement (Achievement/Quest/...) in the SAME block as a Vendor gates
--     that vendor; in its OWN block it is an alternative source
--   * Cost is space-separated parts: "200|T...UI-GOLDICON.BLP:0|t" for gold,
--     "100|Hcurrency:824|h|T...|t|h" for a currency
--
-- Labels are the enUS ones. On another locale nothing matches and every item
-- reads as "Other" -- the list still works, it just cannot rank by vendor cost.

local Source = {}
_G.FabledUI_VillaDecorSource = Source

local COPPER_PER_GOLD, COPPER_PER_SILVER = 10000, 100

local VENDOR_LABELS = { Vendor = true, Vendors = true }

-- Labels seen in live text (2026-09-21 saved variables, counts):
--   Zone 3291, Vendor 2642, Cost 2598, Profession 329, Quest 326, Faction 185,
--   Category 184, Achievement 184, Drop 64, Treasure 22, Renown 6, Event 1.
-- "Faction: Storm's Wake - Honored" and "Renown: Ritual Sites Rank 3" sit in
-- the vendor's block and are reputation gates. "Category" follows an
-- Achievement and names its achievement category; it attaches to it.

local function splitLines(text)
    local lines, start = {}, 1
    while true do
        local from, to = text:find("|n", start, true)
        if not from then
            lines[#lines + 1] = text:sub(start)
            break
        end
        lines[#lines + 1] = text:sub(start, from - 1)
        start = to + 1
    end
    return lines
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Returns { copper = n, currencies = { { id = n, amount = n }, ... } }.
function Source.ParseCost(value)
    local cost = { copper = 0, currencies = {} }
    if type(value) ~= "string" then return cost end

    for part in value:gmatch("%S+") do
        local digits = part:match("^(%d[%d,]*)")
        local amount = digits and tonumber((digits:gsub(",", "")))
        if amount then
            local currencyID = tonumber(part:match("|Hcurrency:(%d+)|h"))
            local upper = part:upper()
            if currencyID then
                cost.currencies[#cost.currencies + 1] = { id = currencyID, amount = amount }
            elseif upper:find("UI-GOLDICON", 1, true) then
                cost.copper = cost.copper + amount * COPPER_PER_GOLD
            elseif upper:find("UI-SILVERICON", 1, true) then
                cost.copper = cost.copper + amount * COPPER_PER_SILVER
            elseif upper:find("UI-COPPERICON", 1, true) then
                cost.copper = cost.copper + amount
            end
        end
    end
    return cost
end

-- Returns:
--   {
--     isShop = bool,
--     vendors = { { name, zones = {}, costText, cost, requires = { {kind,name} } } },
--     others  = { { kind, name, zones = {} } },   -- non-vendor ways to get it
--   }
function Source.Parse(text)
    local result = { isShop = false, vendors = {}, others = {} }
    if type(text) ~= "string" or text == "" then return result end

    local vendor          -- vendor of the current block, once seen
    local blockReqs = {}  -- requirements seen in the current block
    local lastOther       -- for attaching Zone / Category lines to a non-vendor source
    local lastReq         -- the most recent requirement of any kind, for Category

    local function endBlock()
        -- A block with requirements and no vendor is a source in its own right.
        if not vendor then
            for _, req in ipairs(blockReqs) do
                result.others[#result.others + 1] = req
            end
        end
        vendor, blockReqs, lastOther, lastReq = nil, {}, nil, nil
    end

    for _, line in ipairs(splitLines(text)) do
        if trim(line) == "" then
            endBlock()
        else
            local label, value = line:match("^|c%x%x%x%x%x%x%x%x(.-):%s*|r(.*)$")
            if not label then
                local bare = line:match("^|c%x%x%x%x%x%x%x%x(.-)|r")
                if bare and trim(bare) == "Shop" then result.isShop = true end
            else
                label, value = trim(label), trim(value)
                if VENDOR_LABELS[label] then
                    vendor = { name = value, zones = {}, costText = nil, cost = Source.ParseCost(nil), requires = blockReqs }
                    result.vendors[#result.vendors + 1] = vendor
                elseif label == "Zone" then
                    if vendor then
                        vendor.zones[#vendor.zones + 1] = value
                    elseif lastOther then
                        lastOther.zones[#lastOther.zones + 1] = value
                    end
                elseif label == "Cost" then
                    if vendor then
                        vendor.costText = value
                        vendor.cost = Source.ParseCost(value)
                    end
                elseif label == "Category" then
                    if lastReq then lastReq.category = value end
                else
                    local req = { kind = label, name = value, zones = {} }
                    lastReq = req
                    if vendor then
                        vendor.requires[#vendor.requires + 1] = req
                    else
                        blockReqs[#blockReqs + 1] = req
                        lastOther = req
                    end
                end
            end
        end
    end
    endBlock()
    return result
end

-- One number to rank a cost by. Pure gold sorts by copper. Anything involving a
-- currency sorts after all gold prices (currencies are not comparable to gold
-- or to each other), then by amount. No cost at all sorts last.
local CURRENCY_BASE, UNKNOWN_COST = 1e12, 2e12

function Source.CostRank(cost)
    if type(cost) ~= "table" then return UNKNOWN_COST end
    local currencies = cost.currencies or {}
    if #currencies > 0 then
        local total = 0
        for _, currency in ipairs(currencies) do total = total + currency.amount end
        return CURRENCY_BASE + total + (cost.copper or 0) / COPPER_PER_GOLD
    end
    if (cost.copper or 0) > 0 then return cost.copper end
    return UNKNOWN_COST
end

function Source.IsGoldOnly(cost)
    return type(cost) == "table" and #(cost.currencies or {}) == 0 and (cost.copper or 0) > 0
end

-- The vendor to show for an item: the cheapest by CostRank; a tie goes to the
-- vendor with no achievement/quest gate.
function Source.BestVendor(parsed)
    local best, bestRank
    for _, vendor in ipairs(parsed.vendors) do
        local rank = Source.CostRank(vendor.cost) + (#vendor.requires > 0 and 0.5 or 0)
        if not best or rank < bestRank then
            best, bestRank = vendor, rank
        end
    end
    return best
end
