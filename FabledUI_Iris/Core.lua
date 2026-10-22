local addonName, _ = ...
Iris = Iris or {}
local I = Iris
_G.FabledUI_Iris = I

I.VERSION = "1.5.0"

local PREFIX = "|cff00d4ff[Iris]|r "

function I:Print(...)
    print(PREFIX, ...)
end

local function Trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Lower(s)
    return string.lower(tostring(s or ""))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if I._inited then
        return
    end
    I._inited = true

    I:ResolveStorage()

    if I.History then
        I.History:Init()
    end

    if I.UI then
        I.UI:Init()
    end

    SLASH_FABLEDUI_IRIS1 = "/iris"
    SlashCmdList["FABLEDUI_IRIS"] = function(msg)
        local cmd = Lower(Trim((msg or ""):match("^(%S+)") or ""))

        if cmd == "" or cmd == "history" then
            if I.UI then
                I.UI:OpenHistory()
            end
        elseif cmd == "copy" or cmd == "raw" then
            if I.UI then
                I.UI:OpenRawFromActiveChat()
            end
        elseif cmd == "clean" then
            if I.UI then
                I.UI:OpenCleanFromActiveChat()
            end
        elseif cmd == "urls" or cmd == "url" then
            if I.UI then
                I.UI:OpenUrlsFromActiveChat()
            end
        elseif cmd == "settings" then
            if I.Settings then
                I.Settings:Open()
            end
        elseif cmd == "clear" then
            if I.History then
                I.History:Clear()
                I:Print("History cleared.")
            end
        else
            I:Print("Commands: /iris | /iris copy | /iris clean | /iris urls | /iris history | /iris clear | /iris settings")
        end
    end

    I:Print("Online (" .. tostring(I._storageBackend or "Unknown") .. "). Left-click the Iris tab button to copy, right-click it for history.")
end)
