---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - telemetry engine                                           #
---- #                                                                       #
---- # Source resolution with metadata caching, value reading with cell      #
---- # aggregation, battery state-of-charge, and the availability model:     #
---- #   unset        - no source configured                                 #
---- #   invalid      - source id does not resolve                           #
---- #   valid        - fresh/current data                                   #
---- #   stale        - value present but sensor not current (link alive)    #
---- #   disconnected - telemetry link down (getRSSI() == 0)                 #
---- #   unavailable  - no value at all                                      #
---- #                                                                       #
---- # getSourceValue() returns THREE values: value, current, fresh          #
---- # (api_general.cpp:837). Telemetry values are already scaled by the     #
---- # sensor precision, so `prec` is only needed for formatting.            #
---- #                                                                       #
---- # History comes from the radio's own <name>- / <name>+ sensors when     #
---- # they exist (the same source the rest of the UI shows, and the one     #
---- # the standard telemetry reset clears); the in-Lua tracker is the       #
---- # fallback for sticks, channels and gvars.                             #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

-- TelemetryUnit enum -> display text (subset; see dataconstants.h)
local UNIT_NAMES = {
  [1] = "V", [2] = "A", [3] = "mA", [4] = "kts", [5] = "m/s", [6] = "ft/s",
  [7] = "km/h", [8] = "mph", [9] = "m", [10] = "ft", [11] = "C", [12] = "F",
  [13] = "%", [14] = "mAh", [15] = "W", [16] = "mW", [17] = "dB", [18] = "rpm",
  [19] = "g", [20] = "deg", [21] = "rad", [22] = "ml", [23] = "floz",
  [24] = "ml/min", [25] = "Hz", [26] = "ms", [27] = "us", [28] = "km",
  [29] = "dBm",
}

M.CELLS_LOWEST, M.CELLS_TOTAL, M.CELLS_AVERAGE = 1, 2, 3
M.BATTERY_OFF, M.BATTERY_LIPO, M.BATTERY_LIION = 1, 2, 3

-- F-9 retry policy: a telemetry source that is ABSENT at boot (the sensor
-- not yet discovered - the normal case, telemetry arrives seconds after the
-- widget) is re-resolved from refresh() at most once per second, for at most
-- 30 attempts. Beyond that the source is treated as resolved-absent: a
-- genuinely missing source must not rescan the 60-sensor table forever.
local RESOLVE_RETRY_TICKS = 100     -- 1 s (getTime() counts 10 ms ticks)
local MAX_RESOLVE_RETRIES = 30

function M.unitName(unit)
  return UNIT_NAMES[unit] or ""
end

-- getFieldInfo can return names starting with a stray invalid byte on some
-- firmware versions (GaugeRotary lib_widget_tools cleanInvalidChar).  Do not
-- confuse that firmware defect with UTF-8: every valid non-ASCII character
-- also starts above 127.  Strip only bytes that cannot begin a valid UTF-8
-- sequence; preserve an intact 2/3/4-byte character such as "É" or "温".
local function validUtf8At(s, i)
  local b1 = string.byte(s, i)
  if not b1 then return false end
  if b1 < 0x80 then return true end

  local b2, b3, b4 = string.byte(s, i + 1), string.byte(s, i + 2),
                      string.byte(s, i + 3)
  local function cont(b) return b and b >= 0x80 and b <= 0xBF end
  if b1 >= 0xC2 and b1 <= 0xDF then
    return cont(b2)
  elseif b1 == 0xE0 then
    return b2 and b2 >= 0xA0 and b2 <= 0xBF and cont(b3)
  elseif (b1 >= 0xE1 and b1 <= 0xEC) or (b1 >= 0xEE and b1 <= 0xEF) then
    return cont(b2) and cont(b3)
  elseif b1 == 0xED then
    return b2 and b2 >= 0x80 and b2 <= 0x9F and cont(b3)
  elseif b1 == 0xF0 then
    return b2 and b2 >= 0x90 and b2 <= 0xBF and cont(b3) and cont(b4)
  elseif b1 >= 0xF1 and b1 <= 0xF3 then
    return cont(b2) and cont(b3) and cont(b4)
  elseif b1 == 0xF4 then
    return b2 and b2 >= 0x80 and b2 <= 0x8F and cont(b3) and cont(b4)
  end
  return false
end

local function cleanName(name)
  if type(name) ~= "string" then return "" end
  local n = string.byte(name, 1)
  while n and n >= 0x80 and not validUtf8At(name, 1) do
    name = string.sub(name, 2)
    n = string.byte(name, 1)
  end
  return name
end
M.cleanName = cleanName

-- Timer sources are the contiguous "timer" family (api_general.cpp:415).
-- Detect them by id, never by name: T1/T2/T3 are common TEMPERATURE sensor
-- labels, and telemetry sensors always carry a unit while timers do not.
local timerBase = nil
local function resolveTimerBase()
  if timerBase ~= nil then return timerBase end
  if type(getSourceIndex) == "function" then
    timerBase = getSourceIndex("timer1") or false
  else
    timerBase = false
  end
  return timerBase
end

local function isTimerSource(id, name, isTelemetry)
  if isTelemetry then return false end
  local base = resolveTimerBase()
  if base and id >= base and id <= base + 2 then return true end
  if type(name) ~= "string" then return false end
  return string.sub(name, 1, 5) == "timer" or name == "tx-time"
end

-- Sensor precision AND index are not exposed by getFieldInfo; look them up
-- once, together, through the model sensor table. MAX_SENSORS is exposed to
-- Lua (40/60/99 depending on the target) - scanning a hard-coded 32 misses
-- sensors on big radios. The index (0-based, the same space as
-- model.getSensor(i)) is what model.resetSensor(sensor) expects - it is NOT
-- a MIXSRC id.
--
-- Each model.getSensor(i) call builds a fresh Lua table on the radio, so a
-- 60-sensor scan is pure allocation, and the name -> {prec, index} mapping
-- is MODEL data. The cache is therefore scoped to the WIDGET: the module
-- table is shared for the whole radio session, and a module-level cache
-- survived a model change and handed the next model a stale index - which
-- model.resetSensor() then reset, destroying data on the model being flown
-- (Tanda 6 F-6). resolveSource() only re-runs when the source changes, so
-- the per-widget cache still avoids the repeated scan, with none of the
-- cross-model hazard (review §B.4). Only HITS are cached: a sensor not yet
-- connected must be re-scanned once it appears, so a miss is never cached.
local function findSensor(widget, name)
  if type(model) ~= "table" or type(model.getSensor) ~= "function" then
    return nil, nil
  end
  local cache = widget.sensorCache
  if cache then
    local hit = cache[name]
    if hit then return hit.prec, hit.index end
  end
  local count = tonumber(MAX_SENSORS) or 60
  for i = 0, count - 1 do
    local sn = model.getSensor(i)
    if sn and sn.name == name then
      cache = cache or {}
      widget.sensorCache = cache
      cache[name] = { prec = sn.prec, index = i }
      return sn.prec, i
    end
  end
  return nil, nil
end

-- Resolve and cache source metadata. Only does work when the source changed
-- OR the previous resolution is still pending (F-9). A telemetry sensor
-- that is absent at boot is the normal state - refresh() re-enters this
-- throttled until getFieldInfo() answers, so name/unit/precision/preset,
-- the -/+ siblings and the NO LINK vs NO DATA distinction all appear with
-- the sensor, not before it.
function M.resolveSource(widget)
  local id = (widget.config and widget.config.source) or 0
  local s = widget.source
  if s.id == id and s.resolved then return s end
  s.id = id
  s.name = ""
  s.unit = nil
  s.unitName = ""
  s.isTelemetry = false
  s.isTimer = false
  s.prec = nil
  s.sensorIndex = nil
  s.minId = nil
  s.maxId = nil
  s.cells = nil
  s.resolved = false
  if id and id > 0 then
    local info = getFieldInfo(id)
    if info then
      s.name = cleanName(info.name or "")
      s.unit = info.unit
      s.unitName = M.unitName(info.unit)
      -- tx-voltage is not a telemetry source, but the official Value widget
      -- appends "V" to it (value.cpp MIXSRC_TX_VOLTAGE case)
      if s.name == "tx-voltage" then s.unitName = "V" end
      s.isTelemetry = (info.unit ~= nil)
      s.isTimer = isTimerSource(id, s.name, s.isTelemetry)
      if s.isTelemetry then
        s.prec, s.sensorIndex = findSensor(widget, s.name)
        -- the radio already tracks per-sensor min/max as sibling sources
        local lo = getFieldInfo(s.name .. "-")
        local hi = getFieldInfo(s.name .. "+")
        s.minId = lo and lo.id or nil
        s.maxId = hi and hi.id or nil
      end
      s.resolved = true
      s.retries = nil
      s.retryAt = nil
      -- Generation counter. app.configure() derives the unit text, the name,
      -- the Auto preset scale, the precision and the whole layout from the
      -- fields above, and it only runs from update() - which the firmware
      -- calls when the OPTIONS change, not periodically (widget.h:109). A
      -- source that resolves LATE, from the retry in M.refresh below, would
      -- therefore leave every derived value stale. app.refresh watches this
      -- counter and reconfigures once when it moves.
      --
      -- Bumped ONLY on a real resolution: a failed retry repopulates
      -- nothing, and the retries-exhausted latch in the else branch resolves
      -- the source to "absent", which changes nothing either.
      s.gen = (s.gen or 0) + 1
    else
      -- Not resolved yet: retry on later refreshes, but bounded so a
      -- genuinely absent source does not rescan forever (Tanda 6 F-9).
      s.retries = (s.retries or 0) + 1
      s.resolved = (s.retries >= MAX_RESOLVE_RETRIES)
    end
  else
    -- "no source" is a resolved state
    s.resolved = true
  end
  return s
end

-- --------------------------------------------------------------- reading --

local function setNoData(data, availability)
  data.availability = availability
  data.value = nil
  data.displayValue = data.lastValue
  data.state = nil
  data.fresh = false
end

-- Aggregate a CELLS table according to the configured mode.
-- getSourceValue returns one entry per cell, already in volts
-- (api_general.cpp luaPushCells: values[i] * 0.01).
local function aggregateCells(t, mode)
  local total, count, lowest = 0, 0, nil
  for i = 1, #t do
    local v = t[i]
    if type(v) == "number" then
      total = total + v
      count = count + 1
      if lowest == nil or v < lowest then lowest = v end
    end
  end
  if count == 0 then return nil, 0 end
  if mode == M.CELLS_TOTAL then return total, count end
  if mode == M.CELLS_AVERAGE then return total / count, count end
  return lowest, count
end
M.aggregateCells = aggregateCells

-- Latch the cell count on the first valid reading: a pack sags under load, so
-- re-deriving it later would step the scale down mid-flight.
local function latchCells(widget, value)
  local s = widget.source
  if s.cells then return s.cells end
  local chem = (widget.config.battery == M.BATTERY_LIION) and "liion" or "lipo"
  s.cells = widget.mods.presets.cellCount(value, chem)
  return s.cells
end
M.latchCells = latchCells

-- Returns true only when at least one sibling actually produced a number:
-- both ids can resolve yet read nil for a while (sensor just appeared, no
-- samples yet), and treating that as success permanently disables the
-- trackHistory() fallback below (AUDIT.md P1-9).
local function readHistorySiblings(widget)
  local s, h = widget.source, widget.history
  if not s.minId and not s.maxId then return false end
  local lo = s.minId and getSourceValue(s.minId) or nil
  local hi = s.maxId and getSourceValue(s.maxId) or nil
  local gotAny = false
  local changed = false
  if type(lo) == "number" then
    gotAny = true
    if h.min == nil or lo < h.min or h.min < lo then
      h.min, changed = lo, true
    end
  end
  if type(hi) == "number" then
    gotAny = true
    if h.max == nil or hi < h.max or h.max < hi then
      h.max, changed = hi, true
    end
  end
  if changed then h.gen = (h.gen or 0) + 1 end
  return gotAny
end

-- True when the reading is already a single cell's voltage: a Cels source
-- aggregated as Lowest or Average is per-cell after aggregateCells(), so the
-- battery block must NOT divide by the cell count again (Tanda 6 F-2 - the
-- default Lowest configuration read 0 % at 3.85 V/cell because the per-cell
-- aggregate was divided by four a second time).
local function isPerCellReading(cfg, wasCells)
  return wasCells and cfg.cells ~= M.CELLS_TOTAL
end

-- The radio's <name>-/<name>+ siblings track the RAW per-item sensor value.
-- That is only the same quantity as the displayed value when neither
-- transform below is active; otherwise the units silently mismatch (a
-- percentage dial with volt history, or a pack total with a per-cell
-- extreme) - api_general.cpp documents Cels+/Cels- as always a single
-- cell's value, never the pack total or average (AUDIT.md P0-7). This is
-- deliberately STRICTER than isPerCellReading(): Average is also a per-cell
-- reading for the battery math, but its MEAN is not the siblings' extreme,
-- so only Lowest may trust them.
local function historyTrustworthy(cfg, wasCells)
  if cfg.battery and cfg.battery ~= M.BATTERY_OFF then return false end
  if wasCells then return cfg.cells == M.CELLS_LOWEST end
  return true
end
M.historyTrustworthy = historyTrustworthy

-- Fallback tracker: reached whenever the sibling history cannot be trusted
-- for this reading's units, not only when the source has no sibling sensors.
local function trackHistory(widget, value)
  local h = widget.history
  local changed = false
  if h.min == nil then
    h.min, h.max = value, value
    changed = true
  else
    if value < h.min then h.min, changed = value, true end
    if value > h.max then h.max, changed = value, true end
  end
  if changed then h.gen = (h.gen or 0) + 1 end
end

-- Read the source and update widget.data.
function M.refresh(widget)
  local data = widget.data
  local src = widget.source
  local cfg = widget.config

  if not src.id or src.id == 0 then
    data.availability = "unset"
    data.value = nil
    data.displayValue = nil
    data.state = nil
    data.fresh = false
    return
  end

  -- F-9: a source that was absent at boot is still unresolved - keep
  -- re-resolving it, throttled, until getFieldInfo() answers. The old
  -- unconditional resolved=true latch lost the sensor forever (name, unit,
  -- precision, preset, siblings, NO LINK vs NO DATA).
  if not src.resolved then
    local now = getTime()
    if now - (src.retryAt or 0) >= RESOLVE_RETRY_TICKS then
      src.retryAt = now
      src = M.resolveSource(widget)
    end
  end

  local value, current, fresh = getSourceValue(src.id)

  if value == nil then
    if src.isTelemetry and getRSSI() == 0 then
      setNoData(data, "disconnected")
    else
      setNoData(data, "unavailable")
    end
    return
  end

  local wasCells = false
  if type(value) == "table" then
    wasCells = true
    local aggregate, count = aggregateCells(value, cfg.cells or M.CELLS_LOWEST)
    if aggregate == nil then
      -- non-numeric tables (GPS, date/time) are not gauge readings
      setNoData(data, "unavailable")
      return
    end
    value = aggregate
    if count > 0 then src.cells = src.cells or count end
  end

  if type(value) ~= "number" then
    setNoData(data, "unavailable")
    return
  end

  -- A non-finite reading is not a value, and an instrument must not pretend
  -- to know: NaN / +-inf are "no data", the same as no reading at all.
  --
  -- This is a containment guard, not a formality. The three are contagious:
  -- geometry.normalize maps NaN to NaN (neither comparison in clamp() is
  -- true), smoothing.step turns +-inf into NaN on its SECOND frame
  -- (inf - inf), and the NaN then arrives at lvgl.set as an arc endAngle,
  -- where the binding's luaL_checkinteger raises "number has no integer
  -- representation" - the widget disables itself for the session. format.lua
  -- already refuses to print a NaN (M.NO_VALUE); this is the same refusal
  -- applied to the geometry, at the one gate every reading passes through.
  if value ~= value or value == math.huge or value == -math.huge then
    setNoData(data, "unavailable")
    return
  end

  if src.isTelemetry and not current then
    setNoData(data, "stale")
    return
  end

  -- A pack voltage only tells you something once you know how many cells it
  -- has; latch the count from the first reading (see latchCells).
  if widget.autoCells and not src.cells then
    latchCells(widget, value)
  end

  -- Battery mode: show state of charge instead of raw volts.
  if cfg.battery and cfg.battery ~= M.BATTERY_OFF then
    local chem = (cfg.battery == M.BATTERY_LIION) and "liion" or "lipo"
    local cells = latchCells(widget, value)
    -- A Cels source aggregated as Lowest/Average is ALREADY per-cell volts:
    -- dividing again turns ~55 % into ~0 % (Tanda 6 F-2). Only pack-total
    -- readings - and non-table sources like RxBt, which report the pack
    -- directly - need the /count conversion.
    local perCell = value
    if not isPerCellReading(cfg, wasCells) and cells > 0 then
      perCell = value / cells
    end
    local percent = widget.mods.presets.percentFromCell(perCell, chem)
    if percent then
      value = percent
    end
  end

  data.availability = "valid"
  data.value = value
  data.displayValue = value
  data.lastValue = value
  data.fresh = (fresh == true)

  local prev = data.state
  data.state = widget.mods.ranges.determineState(value, widget.ranges, prev,
                                                 widget.deadband)

  local trusted = historyTrustworthy(cfg, wasCells) and readHistorySiblings(widget)
  if not trusted then
    trackHistory(widget, value)
  end
end

-- Clear the tracked history (source/range change, or the reset switch).
function M.resetHistory(widget)
  widget.history.min = nil
  widget.history.max = nil
  widget.history.gen = (widget.history.gen or 0) + 1
end

return M
