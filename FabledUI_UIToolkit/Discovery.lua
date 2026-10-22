local T = FabledUI_UIToolkit
T.Discovery = {}

--- SVC-005: Safe Frame Discovery
--- Retries locating a dynamically loaded Blizzard frame to prevent nil-reference crashes.
--- @param globalName string The global name of the frame to find (e.g., "HousingDashboardFrame")
--- @param maxAttempts number Max number of retries
--- @param interval number Seconds between retries
--- @param callback function Called when the frame is found: callback(frame)
function T.Discovery:WaitForFrame(globalName, maxAttempts, interval, callback)
    maxAttempts = maxAttempts or 10
    interval = interval or 0.2
    local attempts = 0

    local function CheckFrame()
        attempts = attempts + 1
        local frame = _G[globalName]
        if frame then
            callback(frame)
            return true -- stop ticker
        end
        if attempts >= maxAttempts then
            T:Print("Timeout waiting for frame: " .. tostring(globalName))
            return true -- stop ticker
        end
        return false -- continue
    end

    if not CheckFrame() then
        C_Timer.NewTicker(interval, CheckFrame, maxAttempts)
    end
end
