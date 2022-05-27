local wgt_options_xx = ...

local self = {}
self.wgt_options_xx = wgt_options_xx
self.rxbt_id = nil
self.periodic1 = {startTime = getTime(), sampleIntervalMili = sampleIntervalMili}

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
  --local rx_val = getValue("RxBt")
  if self.rxbt_id == nil then
    self.rxbt_id = getFieldInfo("RxBt").id
  end
  if self.rxbt_id == nil then
    return false
  end

  local rx_val = getValue(self.rxbt_id)
  if rx_val > 0 then
    return true
  end
  return false
end
--------------------------------------------------------------------------------------------------------

return self