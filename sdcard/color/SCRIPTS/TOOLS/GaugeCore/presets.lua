---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - known-sensor presets and battery maths                     #
---- #                                                                       #
---- # Matching order: exact source name (normalized), then unit fallback    #
---- # for telemetry sources. Presets only initialize values while the       #
---- # Scale option is Auto.                                                 #
---- #                                                                       #
---- # Battery helpers: cell-count detection from pack voltage and a         #
---- # discharge-curve percentage, the way BattAnalog / the community        #
---- # battery widgets do it. Voltage alone is a poor state-of-charge        #
---- # indicator - the curve makes the gauge mean something.                 #
---- #                                                                       #
---- # Pure Lua, no firmware dependencies.                                   #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

-- Units are the EdgeTX TelemetryUnit enum (dataconstants.h):
-- 1=V 2=A 3=mA 4=kts 5=m/s 7=km/h 9=m 11=degC 12=degF 13=% 14=mAh 15=W
-- 17=dB 18=rpm 28=km 29=dBm
local PRESETS = {
  {
    names = { "RSSI", "RSSI1", "RSSI2", "RSSI3" },
    units = { 17 },
    kind = "signal",
    minimum = 0, maximum = 100, warning = 55, critical = 35, highIsGood = true,
  },
  {
    names = { "1RSS", "2RSS", "TRSS" },
    units = { 29 },
    kind = "signal",
    minimum = -120, maximum = 0, warning = -80, critical = -95,
    highIsGood = true,
  },
  {
    names = { "RQly", "RQly%", "TQly", "VFR%", "VFR" },
    kind = "signal",
    minimum = 0, maximum = 100, warning = 55, critical = 35, highIsGood = true,
  },
  {
    names = { "SNR" },
    kind = "signal",
    minimum = -20, maximum = 20, warning = 2, critical = -5, highIsGood = true,
  },
  {
    names = { "RxBt", "RxBatt", "Batt", "Vbat", "VFAS" },
    units = { 1 },
    kind = "battery",
    minimum = 0, maximum = 8.4, warning = 3.7, critical = 3.5, highIsGood = true,
    battery = true,
  },
  {
    names = { "TxBat", "TxBatt", "Battery", "tx-voltage" },
    kind = "battery",
    minimum = 6, maximum = 8.4, warning = 6.8, critical = 6.4, highIsGood = true,
  },
  {
    -- cellsTable: getSourceValue() returns one entry PER CELL for this
    -- sensor (api_general.cpp luaPushCells), unlike RxBt/VFAS above which is
    -- a single pack-total reading. The pack-range rescale in app.lua only
    -- makes sense for a value that IS the pack total (AUDIT.md P1-6) -
    -- Lowest and Average stay single-cell magnitude regardless of pack size.
    names = { "Cell", "Cells", "Cels", "Cel#" },
    kind = "battery",
    minimum = 3.0, maximum = 4.2, warning = 3.7, critical = 3.5,
    highIsGood = true, battery = true, cellsTable = true,
  },
  {
    names = { "Tmp", "Temp", "Temperature", "Tmp1", "Tmp2", "TFET", "TBEC" },
    units = { 11, 12 },
    kind = "temperature",
    minimum = 0, maximum = 120, warning = 70, critical = 90, highIsGood = false,
  },
  {
    names = { "RPM", "RPMs", "Turbine", "Hspd" },
    units = { 18 },
    minimum = 0, maximum = 20000, warning = 16000, critical = 18000,
    highIsGood = false,
  },
  {
    names = { "Curr", "Current" },
    units = { 2 },
    minimum = 0, maximum = 100, warning = 70, critical = 85, highIsGood = false,
  },
  {
    names = { "Capa", "Capacity", "Consumption", "mAh" },
    units = { 14 },
    kind = "capacity",
    minimum = 0, maximum = 5000, warning = 3500, critical = 4500,
    highIsGood = false,
  },
  {
    names = { "Fuel", "Bat%", "Rem" },
    kind = "capacity",
    minimum = 0, maximum = 100, warning = 30, critical = 15, highIsGood = true,
  },
  {
    names = { "Thr", "Throttle" },
    -- Throttle is deliberately not a centred control. Treating it like a
    -- stick/channel would invent a neutral midpoint and select Dual Rail for
    -- a unipolar source.
    kind = "throttle",
    minimum = 0, maximum = 100, warning = 80, critical = 95, highIsGood = false,
  },
  {
    names = { "Alt", "Altitude", "GAlt" },
    units = { 9 },
    minimum = 0, maximum = 400, warning = 300, critical = 380,
    highIsGood = false,
  },
  {
    names = { "GSpd", "GPSspeed", "ASpd" },
    units = { 4, 5, 7 },
    minimum = 0, maximum = 150, warning = 120, critical = 140,
    highIsGood = false,
  },
  {
    names = { "Dist", "Distance" },
    units = { 28 },
    minimum = 0, maximum = 1000, warning = 700, critical = 900,
    highIsGood = false,
  },
  {
    names = { "Sats", "Satellites" },
    kind = "signal",
    minimum = 0, maximum = 24, warning = 8, critical = 5, highIsGood = true,
  },
  {
    names = { "Vibr", "Vibration" },
    minimum = 0, maximum = 100, warning = 40, critical = 60, highIsGood = false,
  },
}

local function normName(s)
  if type(s) ~= "string" then return "" end
  -- string methods (s:lower()) are unavailable on EdgeTX Lua builds without
  -- LUA_ENABLE_STRLIB_MT, so use the string library functions explicitly
  return (string.gsub(string.lower(s), "[^%w]", ""))
end
M.normName = normName

-- Find a preset for a resolved source { name = ..., unit = ... }.
function M.find(source)
  if not source or not source.name then return nil end
  local name = normName(source.name)
  if name == "" then return nil end
  for i = 1, #PRESETS do
    local p = PRESETS[i]
    for j = 1, #p.names do
      if normName(p.names[j]) == name then return p end
    end
  end
  if source.unit then
    for i = 1, #PRESETS do
      local p = PRESETS[i]
      if p.units then
        for j = 1, #p.units do
          if p.units[j] == source.unit then
            if not p.battery then return p end
            -- Battery/cell detection is only trustworthy from an exact NAME
            -- match: matching by unit alone (any unlabelled Volt sensor)
            -- must not inherit it, or an unrelated voltage sensor (a BEC, a
            -- servo rail) permanently latches a cell count and gets
            -- rescaled to a battery pack range it has nothing to do with
            -- (AUDIT.md P1-7).
            local copy = {}
            for k, v in pairs(p) do copy[k] = v end
            copy.battery = nil
            copy.cellsTable = nil
            return copy
          end
        end
      end
    end
  end
  return nil
end

-- Stable semantic hint for the opt-in Auto Source APPEARANCE preset. This is
-- intentionally coarse: it may select a useful face, but never changes the
-- scale, thresholds, alerts, or telemetry transforms owned above.
function M.kind(source)
  local preset = M.find(source)
  if preset and preset.kind then return preset.kind end
  local name = normName(source and source.name)
  -- Stable EdgeTX source families whose native meaning is signed around a
  -- neutral centre. This hint selects appearance only; scale ownership stays
  -- in app.lua and the user's Scale setting.
  if name == "ail" or name == "ele" or name == "rud"
     or string.find(name, "^ch%d+$")
     or string.find(name, "^trm[%a%d]+$")
     or string.find(name, "^trim[%a%d]+$")
     or string.find(name, "^gv%d+$")
     or string.find(name, "^gvar%d+$") then
    return "control"
  end
  return "generic"
end

-- ---------------------------------------------------------------- battery --

-- Chemistry limits: { full, empty, curve }. The curve is a voltage -> percent
-- polyline for one cell; linear interpolation between points. Approximations
-- of a resting discharge curve, matching what the battery widgets in the
-- ecosystem use.
M.CHEMISTRY = {
  lipo = {
    full = 4.2, empty = 3.3, nominal = 4.35,
    curve = {
      { 3.30, 0 }, { 3.50, 5 }, { 3.60, 10 }, { 3.65, 15 }, { 3.70, 25 },
      { 3.75, 35 }, { 3.80, 45 }, { 3.85, 55 }, { 3.90, 65 }, { 3.95, 75 },
      { 4.00, 85 }, { 4.10, 95 }, { 4.20, 100 },
    },
  },
  liion = {
    full = 4.2, empty = 2.8, nominal = 4.35,
    curve = {
      { 2.80, 0 }, { 3.10, 5 }, { 3.30, 10 }, { 3.50, 25 }, { 3.60, 40 },
      { 3.70, 55 }, { 3.80, 70 }, { 3.90, 80 }, { 4.00, 90 }, { 4.10, 97 },
      { 4.20, 100 },
    },
  },
}

-- Cell count from a pack voltage (BattAnalog / dbarrios83 heuristic).
function M.cellCount(total, chemistry)
  local chem = M.CHEMISTRY[chemistry] or M.CHEMISTRY.lipo
  if type(total) ~= "number" or total <= 0 then return 1 end
  local n = math.floor(total / chem.nominal) + 1
  if n < 1 then n = 1 end
  if n > 16 then n = 16 end
  return n
end

-- State of charge (0..100) for a per-cell voltage.
function M.percentFromCell(perCell, chemistry)
  local chem = M.CHEMISTRY[chemistry] or M.CHEMISTRY.lipo
  local curve = chem.curve
  if type(perCell) ~= "number" then return nil end
  if perCell <= curve[1][1] then return 0 end
  if perCell >= curve[#curve][1] then return 100 end
  for i = 2, #curve do
    local v1, p1 = curve[i - 1][1], curve[i - 1][2]
    local v2, p2 = curve[i][1], curve[i][2]
    if perCell <= v2 then
      return p1 + (p2 - p1) * (perCell - v1) / (v2 - v1)
    end
  end
  return 100
end

-- Range for a pack of `cells` cells, so a total-voltage source gets a scale
-- that matches the actual battery instead of a guessed 0..8.4 V.
function M.packRange(cells, chemistry)
  local chem = M.CHEMISTRY[chemistry] or M.CHEMISTRY.lipo
  return {
    minimum = chem.empty * cells,
    maximum = chem.full * cells,
    warning = 3.7 * cells,
    critical = 3.5 * cells,
    highIsGood = true,
  }
end

return M
