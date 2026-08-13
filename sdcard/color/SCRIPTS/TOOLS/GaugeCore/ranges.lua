---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - semantic ranges and state detection                        #
---- #                                                                       #
---- # Builds the ordered normal/warning/critical bands from user options    #
---- # and maps a value to its operational state, with hysteresis.           #
---- #                                                                       #
---- # Hysteresis rule: a worse state is adopted immediately (safety first), #
---- # a better state only once the value has left the previous band by the  #
---- # deadband. Without it a value resting on a threshold chatters between  #
---- # two states on sensor noise - visible as colour flicker and audible as #
---- # repeated alerts.                                                      #
---- #                                                                       #
---- # Pure Lua, no firmware dependencies.                                   #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local SEVERITY = { normal = 1, warning = 2, critical = 3 }
M.SEVERITY = SEVERITY

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Build ascending bands from minimum to maximum.
-- Returns { { role=..., from=..., to=... }, ... } (3 entries).
-- Bands are always ascending in value space even when the scale is drawn
-- inverted (geometry.normalize handles the drawing direction), and the
-- warning/critical values are clamped into the range.
function M.build(minimum, maximum, warning, critical, highIsGood)
  if maximum < minimum then
    minimum, maximum = maximum, minimum
  end
  local lo = clamp(math.min(warning, critical), minimum, maximum)
  local hi = clamp(math.max(warning, critical), minimum, maximum)
  local ranges
  if highIsGood then
    ranges = {
      { role = "critical", from = minimum, to = lo },
      { role = "warning",  from = lo,      to = hi },
      { role = "normal",   from = hi,      to = maximum },
    }
  else
    ranges = {
      { role = "normal",   from = minimum, to = lo },
      { role = "warning",  from = lo,      to = hi },
      { role = "critical", from = hi,      to = maximum },
    }
  end
  return ranges
end

-- Deadband width for a range, as a fraction of the span (default 2%).
function M.deadband(minimum, maximum, fraction)
  local span = math.abs(maximum - minimum)
  -- `not (span > 0)`, never `span == 0`: this firmware floors a float before
  -- comparing it with an integer literal, so a 0.5 V span read as zero and
  -- the whole scale lost its hysteresis (see geometry.isZero).
  if span <= 0 then return 0 end
  return span * (fraction or 0.02)
end

-- If BOTH configured thresholds fall outside the effective range on the same
-- side, the clamp in build() collapses them onto the same endpoint and the
-- whole dial becomes one giant critical band - a manual -120..0 dBm scale
-- with the 0..100 defaults (55/35) is born permanently red, with zero-width
-- warning and normal bands (AUDIT.md G-4). Detect that case and derive the
-- thresholds at the proportions the built-in presets use (35 % / 55 % of the
-- span, mirrored for low-is-good) instead. An equal pair INSIDE the range is
-- a deliberate sharp cliff and is left alone.
-- Returns (warning, critical).
function M.saneThresholds(minimum, maximum, warning, critical, highIsGood)
  -- Same normalisation as build(): a descending scale (Min > Max) is a
  -- supported configuration, not a mistake. Without it the guard below
  -- fires on perfectly valid thresholds and derives them over a NEGATIVE
  -- span - warn/crit inverted, a warning value rendered red and firing
  -- the critical alert tone (Tanda 6 F-3).
  if maximum < minimum then minimum, maximum = maximum, minimum end
  local wl = math.min(warning, critical)
  local wh = math.max(warning, critical)
  if wh < minimum or wl > maximum then
    local span = maximum - minimum
    if highIsGood then
      return minimum + 0.55 * span, minimum + 0.35 * span
    end
    return minimum + 0.45 * span, minimum + 0.65 * span
  end
  return warning, critical
end

local function rawState(value, ranges)
  for i = 1, #ranges do
    local r = ranges[i]
    if value >= r.from and value <= r.to then
      return r.role
    end
  end
  -- outside the configured range: take the nearest boundary band
  if value < ranges[1].from then return ranges[1].role end
  return ranges[#ranges].role
end

local function bandOf(ranges, role)
  for i = 1, #ranges do
    if ranges[i].role == role then return ranges[i] end
  end
  return nil
end

-- Determine the state of a value.
-- `previous` and `deadband` are optional; when both are given the result is
-- hysteretic (see the header).
function M.determineState(value, ranges, previous, deadband)
  local raw = rawState(value, ranges)
  if not previous or raw == previous then return raw end
  if not deadband or deadband <= 0 then return raw end
  if (SEVERITY[raw] or 0) > (SEVERITY[previous] or 0) then
    return raw  -- degrading: react at once
  end
  local band = bandOf(ranges, previous)
  if band and value >= band.from - deadband and value <= band.to + deadband then
    return previous  -- still inside the widened previous band: hold
  end
  return raw
end

return M
