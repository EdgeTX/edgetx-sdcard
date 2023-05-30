local app_name, p2 = ...

local M = {}
M.app_name = app_name
M.tele_src_name = nil
M.tele_src_id = nil


--------------------------------------------------------------
local function log(s)
    print(M.app_name .. ": " .. s)
end
---------------------------------------------------------------------------------------------------

function M.periodicInit()
    local t = {}
    t.startTime = -1;
    t.durationMili = -1;
    return t
end

function M.periodicStart(t, durationMili)
    t.startTime = getTime();
    t.durationMili = durationMili;
end

function M.periodicHasPassed(t)
    -- not started yet
    if (t.durationMili <= 0) then
        return false;
    end

    local elapsed = getTime() - t.startTime;
    log(string.format('elapsed: %d (t.durationMili: %d)', elapsed, t.durationMili))
    local elapsedMili = elapsed * 10;
    if (elapsedMili < t.durationMili) then
        return false;
    end
    return true;
end

function M.periodicGetElapsedTime(t)
    local elapsed = getTime() - t.startTime;
    log(string.format("elapsed: %d",elapsed));
    local elapsedMili = elapsed * 10;
    log(string.format("elapsedMili: %d",elapsedMili));
    return elapsedMili;
end

function M.periodicReset(t)
    t.startTime = getTime();
    log(string.format("periodicReset()"));
    periodicGetElapsedTime(t)
end

function M.getDurationMili(t)
    return t.durationMili
end

---------------------------------------------------------------------------------------------------

function M.isTelemetryAvailable()
    -- select telemetry source
    if not M.tele_src_id then
        log("select telemetry source")
        tele_src = getFieldInfo("RSSI")
        if not tele_src then tele_src = getFieldInfo("RxBt") end
        if not tele_src then tele_src = getFieldInfo("A1") end
        if not tele_src then tele_src = getFieldInfo("A2") end
        if not tele_src then tele_src = getFieldInfo("1RSS") end
        if not tele_src then tele_src = getFieldInfo("2RSS") end
        if not tele_src then tele_src = getFieldInfo("RQly") end
        if not tele_src then tele_src = getFieldInfo("TRSS") end
        if not tele_src then tele_src = getFieldInfo("VFR%") end

        if tele_src == nil then
            log("no telemetry sensor found")
            M.tele_src_id = nil
            M.tele_src_name = "---"
            tele_is_available = false
            return
        end
    end
    M.tele_src_id = tele_src.id
    M.tele_src_name = tele_src.name

    if M.tele_src_id == nil then
        return false
    end

    local rx_val = getValue(M.tele_src_id)
    if rx_val ~= 0 then
        return true
    end
    return false
end

--------------------------------------------------------------------------------------------------------

-- workaround to detect telemetry-reset event, until a proper implementation on the lua interface will be created
-- this workaround assume that:
--   RSSI- is always going down
--   RSSI- is reset on the C++ side when a telemetry-reset is pressed by user
--   widget is calling this func on each refresh/background
-- on event detection, the function onTelemetryResetEvent() will be trigger
--
function M.detectResetEvent(wgt, callback_onTelemetryResetEvent)

    local currMinRSSI = getValue('RSSI-')
    if (currMinRSSI == nil) then
        log("telemetry reset event: can not be calculated")
        return
    end
    if (currMinRSSI == wgt.telemResetLowestMinRSSI) then
        --log("telemetry reset event: not found")
        return
    end

    if (currMinRSSI < wgt.telemResetLowestMinRSSI) then
        -- rssi just got lower, record it
        wgt.telemResetLowestMinRSSI = currMinRSSI
        --log("telemetry reset event: not found")
        return
    end

    -- reset telemetry detected
    wgt.telemResetLowestMinRSSI = 101
    log("telemetry reset event detected")

    -- notify event
    callback_onTelemetryResetEvent(wgt)
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

return M
