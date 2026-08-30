---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - needle damping                                             #
---- #                                                                       #
---- # Frame-rate independent exponential filter:                            #
---- #   factor = 1 - exp(-dt / tau)                                         #
---- # so the needle glides at the same speed whatever the refresh rate,     #
---- # while the digital value updates instantly.                            #
---- #                                                                       #
---- # getTime() returns 10 ms ticks (get_tmr10ms); ALL time maths converts  #
---- # explicitly to milliseconds - mixing the two units makes the first     #
---- # step of every re-acquisition jump.                                    #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local exp = math.exp

-- Damping option (0..9) -> filter time constant in milliseconds.
-- 0 disables the filter (raw value), 4 (default) is ~160 ms.
function M.tau(damping)
  local d = tonumber(damping) or 4
  if d <= 0 then return 0 end
  if d > 9 then d = 9 end
  return d * 40
end

function M.reset(widget)
  widget.smooth.value = nil
  widget.smooth.time = 0
end

function M.step(widget, target)
  local sm = widget.smooth
  if target == nil then
    sm.value = nil
    return nil
  end
  local tau = widget.config.tau or 160
  if tau <= 0 then
    sm.value = target
    return target
  end
  local now = getTime() * 10           -- 10 ms ticks -> ms
  if sm.value == nil then
    sm.value = target
    sm.time = now
    return target
  end
  local dt = now - sm.time
  if dt <= 0 then dt = 1 elseif dt > 1000 then dt = 1000 end
  sm.time = now
  sm.value = sm.value + (target - sm.value) * (1 - exp(-dt / tau))
  return sm.value
end

return M
