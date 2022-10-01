local wgt_options_xx = ...

local self = {}
self.wgt_options_xx = wgt_options_xx
self.tele_src_name = nil
self.tele_src_id = nil

self.periodic1 = { startTime = getTime(), sampleIntervalMili = sampleIntervalMili }

--------------------------------------------------------------
local function log(s)
    --return;
    print("appValue2: " .. s)
end
--------------------------------------------------------------

-----------------------------------------------------------------
local function periodicReset(t)
    t.startTime = getTime();
end

local function periodicHasPassed(t)
    local elapsed = getTime() - t.startTime;
    local elapsedMili = elapsed * 10;
    if (elapsedMili < t.sampleIntervalMili) then
        return false;
    end
    return true;
end

local function periodicGetElapsedTime(t)
    local elapsed = getTime() - t.startTime;
    --log(string.format("elapsed: %d",elapsed));
    local elapsedMili = elapsed * 10;
    --log(string.format("elapsedMili: %d",elapsedMili));
    return elapsedMili;
end

--------------------------------------------------------------------------------------------------------

function self.isTelemetryAvailable()
    -- select telemetry source
    if not self.tele_src_id then
        log("select telemetry source")
        tele_src = getFieldInfo("RSSI")
        if not tele_src then tele_src = getFieldInfo("RxBt") end
        if not tele_src then tele_src = getFieldInfo("A1") end
        if not tele_src then tele_src = getFieldInfo("A2") end
        if not tele_src then tele_src = getFieldInfo("1RSS") end
        if not tele_src then tele_src = getFieldInfo("2RSS") end
        if not tele_src then tele_src = getFieldInfo("RQly") end
        if not tele_src then tele_src = getFieldInfo("TRSS") end

        if tele_src == nil then
            log("no telemetry sensor found")
            self.tele_src_id = nil
            self.tele_src_name = "---"
            tele_is_available = false
            return
        end
    end
    self.tele_src_id = tele_src.id
    self.tele_src_name = tele_src.name

    if self.tele_src_id == nil then
        return false
    end

    local rx_val = getValue(self.tele_src_id)
    if rx_val ~= 0 then
        return true
    end
    return false
end
--------------------------------------------------------------------------------------------------------

return self