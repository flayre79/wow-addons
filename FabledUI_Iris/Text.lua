local I = Iris
I.Text = {}
local T = I.Text

local function SafeString(value)
    if value == nil then
        return ""
    end

    if type(issecretvalue) == "function" then
        local checked, secret = pcall(issecretvalue, value)
        if checked and secret then
            return ""
        end
    end

    local ok, result = pcall(tostring, value)
    if not ok or type(result) ~= "string" then
        return ""
    end
    if type(issecretvalue) == "function" then
        local checked, secret = pcall(issecretvalue, result)
        if checked and secret then
            return ""
        end
    end
    return result
end

local function Trim(s)
    return SafeString(s):gsub("^%s+", ""):gsub("%s+$", "")
end

function T:SafeString(value)
    return SafeString(value)
end

local function MakeScratchFontString()
    if T._scratch then
        return T._scratch
    end

    local holder = CreateFrame("Frame")
    holder:Hide()

    local fs = holder:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    fs:SetWidth(2048)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    T._scratch = fs
    return fs
end

function T:ResolveDisplayText(text)
    -- In WoW 12.x, chat strings can be secret values whose comparison and
    -- methods are blocked. SafeString omits those values; pcall contains font
    -- resolution failures for ordinary strings without leaking an exception.
    local ok, result = pcall(function()
        local s = SafeString(text)
        if #s == 0 then return "" end
        local fs = MakeScratchFontString()
        fs:SetFormattedText("%s", s)
        return fs:GetText() or s
    end)
    if ok then
        return result
    end
    return SafeString(text)
end

function T:StripFormatting(text)
    text = SafeString(text)

    text = text:gsub("|K.-|k", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|n", " ")
    text = text:gsub("%s+", " ")

    return Trim(text)
end

function T:CleanLine(text)
    local resolved = self:ResolveDisplayText(text)
    return self:StripFormatting(resolved)
end

local function AddUnique(out, seen, value)
    value = Trim(value)
    value = value:gsub("[%),%.%!%?%]%}>]+$", "")
    if value == "" then
        return
    end

    local key = string.lower(value)
    if not seen[key] then
        seen[key] = true
        out[#out + 1] = value
    end
end

function T:ExtractURLs(text)
    local clean = self:CleanLine(text)
    local out = {}
    local seen = {}

    for url in clean:gmatch("https?://[%w%._~:/%?#%[%]@!$&'()*+,;=%%%-]+") do
        AddUnique(out, seen, url)
    end

    for url in clean:gmatch("www%.[%w%._~:/%?#%[%]@!$&'()*+,;=%%%-]+") do
        AddUnique(out, seen, url)
    end

    for email in clean:gmatch("[%w%._%%+%-]+@[%w%.%-]+%.[A-Za-z][A-Za-z]+") do
        AddUnique(out, seen, email)
    end

    return out
end

function T:BuildRawText(lines)
    return table.concat(lines or {}, "\n")
end

function T:BuildCleanText(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
        local cleaned = self:CleanLine(line)
        if cleaned ~= "" then
            out[#out + 1] = cleaned
        end
    end
    return table.concat(out, "\n")
end

function T:BuildURLText(lines)
    local all = {}
    local seen = {}

    for _, line in ipairs(lines or {}) do
        for _, url in ipairs(self:ExtractURLs(line)) do
            local key = string.lower(url)
            if not seen[key] then
                seen[key] = true
                all[#all + 1] = url
            end
        end
    end

    return table.concat(all, "\n")
end
