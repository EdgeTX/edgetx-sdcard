---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - threshold alerts                                           #
---- #                                                                       #
---- # A gauge that only changes colour is useless when you are looking at   #
---- # the model. Alerts fire on a state TRANSITION into warning/critical,   #
---- # never continuously, and are guarded by:                               #
---- #                                                                       #
---- #   * a startup delay - a model powering up reports nonsense for a      #
---- #     second or two; without this every power-on screams CRITICAL       #
---- #     (the ePowerbar lesson),                                           #
---- #   * an optional switch, so alerts only arm when the model is armed,   #
---- #   * a re-arm interval, so a value hovering on a threshold cannot      #
---- #     machine-gun (state hysteresis in ranges.lua does the rest),       #
---- #   * data validity - no alerts while the link is down.                 #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

M.OFF, M.CRITICAL, M.ALL = 1, 2, 3

local REPEAT_TICKS = 500   -- 5 s between repeats of the same state

-- A SWITCH option is a swsrc_t (may be negative), not a MIXSRC id: it must be
-- read with getSwitchValue(), never getValue() (AUDIT.md P0-1). On any
-- failure to read it, stay armed - a misread switch must not silence alerts.
local function switchActive(id)
  if not id or id == 0 then return true end
  if type(getSwitchValue) ~= "function" then return true end
  local ok, value = pcall(getSwitchValue, id)
  if not ok then return true end
  return value == true
end

local function play(widget, state)
  local cfg = widget.config
  if type(playHaptic) == "function" and cfg.vibrate and state == "critical" then
    playHaptic(60, 0)
  end
  if type(playTone) ~= "function" then return end
  if state == "critical" then
    playTone(880, 180, 0)
    playTone(660, 180, 20)
  else
    playTone(660, 120, 0)
  end
end

function M.reset(widget)
  widget.alert = widget.alert or {}
  widget.alert.state = nil
  widget.alert.at = 0
  widget.alert.armedAt = nil
end

-- Called once per refresh, after telemetry.
function M.update(widget)
  local cfg = widget.config
  local a = widget.alert
  if not a then
    M.reset(widget)
    a = widget.alert
  end
  local level = cfg.alerts or M.OFF
  if level == M.OFF then
    a.state = nil
    return
  end

  local data = widget.data
  if data.availability ~= "valid" or data.state == nil then
    a.state = nil
    -- Re-arm the STARTUP DELAY too, not just the transition: a brownout is
    -- precisely the "model powering up reports nonsense" case the delay
    -- exists for (Tanda 6 F-7). Leaving armedAt in the past made the first
    -- frame after reconnect alert immediately.
    a.armedAt = nil
    return
  end

  local now = getTime()
  if a.armedAt == nil then
    a.armedAt = now + (tonumber(cfg.delay) or 0) * 100  -- seconds -> 10 ms
  end
  if now < a.armedAt then return end
  if not switchActive(cfg.alertSw) then return end

  local state = data.state
  local wanted = (state == "critical")
    or (level == M.ALL and state == "warning")
  if not wanted then
    a.state = state
    return
  end
  if state ~= a.state or (now - a.at) >= REPEAT_TICKS then
    a.state = state
    a.at = now
    play(widget, state)
  end
end

return M
