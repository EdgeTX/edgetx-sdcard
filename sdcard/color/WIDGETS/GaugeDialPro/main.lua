---- #########################################################################
---- # Gauge Dial - dial frontend backed by the shared GaugeCore             #
---- #########################################################################

local TEST = ...
local NAME = "DialPro"
local CORE_API = 1
local CORE_PATH = "/SCRIPTS/TOOLS/GaugeCore/"
if type(TEST) == "table" and type(TEST.corePath) == "string" then
  CORE_PATH = TEST.corePath
end
if string.sub(CORE_PATH, -1) ~= "/" then CORE_PATH = CORE_PATH .. "/" end

-- Keep the widget registered on unsupported firmware so the model retains
-- its configuration and the pilot gets an actionable message.
if lvgl == nil then
  return {
    name = NAME,
    options = {},
    create = function(zone) return { zone = zone } end,
    update = function() end,
    refresh = function()
      lcd.drawText(3, 3, "Gauge Dial needs EdgeTX 2.11+", SMLSIZE)
    end,
  }
end

-- Wire contract: existing entries are immutable and new entries append only.
-- The shared prefix is pinned against GaugeBarPro by widgets_test.lua.
local DEFS = {
  { key = "Source", label = "Source", type = SOURCE, field = "source",
    since = 211, default = { "RSSI", "RQly", "RxBt", "Cels", "TxBt" } },
  { key = "Min", label = "Scale low", type = VALUE, field = "min",
    since = 211, default = 0, min = -10000, max = 10000 },
  { key = "Max", label = "Scale high", type = VALUE, field = "max",
    since = 211, default = 100, min = -10000, max = 10000 },
  { key = "Warn", label = "Warn level", type = VALUE, field = "warn",
    since = 211, default = 55, min = -10000, max = 10000 },
  { key = "Crit", label = "Critical level", type = VALUE, field = "crit",
    since = 211, default = 35, min = -10000, max = 10000 },
  { key = "HighGood", label = "High = good", type = BOOL,
    field = "highGood", since = 211, default = 1 },
  { key = "ColorMode", label = "Colour mode", type = CHOICE,
    field = "colorMode", since = 211, default = 3,
    choices = { "Static", "Threshold", "Rail", "Gradient", "Sections" } },
  { key = "Precision", label = "Decimals", type = CHOICE,
    field = "precision", since = 211, default = 1,
    choices = { "Auto", "0", "1", "2" } },
  { key = "ShowMinMax", label = "Min/max marks", type = CHOICE,
    field = "showMinMax", since = 211, default = 2,
    choices = { "Off", "Markers", "Markers + text" } },

  -- Family selector, intentionally in the 2.11-visible tenth slot.
  { key = "DialStyle", label = "Dial style", type = CHOICE,
    field = "style", since = 211, default = 1,
    choices = { "Auto", "Needle", "Arc" } },

  { key = "Sweep", label = "Dial sweep", type = CHOICE, field = "sweep",
    since = 212, default = 1, choices = { "270 deg", "180 deg", "360 deg" } },
  { key = "Accent", label = "Normal colour", type = COLOR, field = "accent",
    since = 212, default = lcd.RGB(0x20, 0x90, 0x58) },
  { key = "Label", label = "Name override", type = STRING, field = "label",
    since = 212, default = "" },
  { key = "Suffix", label = "Unit override", type = STRING, field = "suffix",
    since = 212, default = "" },
  { key = "Scale", label = "Scale ends", type = CHOICE, field = "scale",
    since = 212, default = 1, choices = { "Auto", "Manual" } },
  { key = "Damping", label = "Gauge damping", type = SLIDER,
    field = "damping", since = 212, default = 4, min = 0, max = 9 },
  { key = "Cells", label = "Cell reading", type = CHOICE, field = "cells",
    since = 212, default = 1, choices = { "Lowest", "Total", "Average" } },
  { key = "Battery", label = "Volts as %", type = CHOICE,
    field = "battery", since = 212, default = 1,
    choices = { "Off", "Li-Po", "Li-Ion" } },
  { key = "Alerts", label = "Alerts", type = CHOICE, field = "alerts",
    since = 212, default = 1,
    choices = { "Off", "Critical", "Warning + critical" } },
  { key = "AlertSw", label = "  Alert switch", type = SWITCH,
    field = "alertSw", since = 212, default = 0 },
  { key = "Delay", label = "  Startup delay (s)", type = VALUE,
    field = "delay", since = 212, default = 4, min = 0, max = 30 },
  { key = "Vibrate", label = "  Vibrate", type = BOOL,
    field = "vibrate", since = 212, default = 0 },
  { key = "ResetSw", label = "Reset min/max", type = SWITCH,
    field = "resetSw", since = 212, default = 0 },
  { key = "ShowChip", label = "Info badges", type = BOOL,
    field = "showChip", since = 212, default = 1 },
}

local SPEC = { name = NAME, family = "dial", coreApi = CORE_API, defs = DEFS }

local CORE, EXTENDED = 10, 50
local capacity = CORE
if type(getVersion) == "function" then
  local _, _, major, minor = getVersion()
  major, minor = tonumber(major), tonumber(minor)
  if major and (major > 2 or (major == 2 and (minor or 0) >= 12)) then
    capacity = EXTENDED
  end
end

local options = {}
local labels = { [NAME] = "Gauge Dial Pro" }
for i = 1, #DEFS do
  local d = DEFS[i]
  labels[d.key] = d.label
  local needs = (d.since == 212) and EXTENDED or CORE
  if needs <= capacity and #options < capacity then
    if d.type == CHOICE then
      options[#options + 1] = { d.key, d.type, d.default, d.choices }
    elseif d.type == VALUE or d.type == SLIDER then
      options[#options + 1] = { d.key, d.type, d.default, d.min, d.max }
    else
      options[#options + 1] = { d.key, d.type, d.default }
    end
  end
end

local function translate(name) return labels[name] end
local sharedApp

local function create(zone, opts, _widgetPath)
  if not sharedApp then
    local chunk, err = loadScript(CORE_PATH .. "app.lua", "bt")
    if not chunk then
      error(NAME .. ": cannot load GaugeCore/app.lua from " .. CORE_PATH
        .. " (" .. tostring(err) .. ")")
    end
    sharedApp = chunk(SPEC)
    if type(sharedApp) ~= "table" or sharedApp.coreApi ~= CORE_API then
      error(NAME .. ": incompatible GaugeCore API (expected "
        .. tostring(CORE_API) .. ")")
    end
  end
  local widget = sharedApp.create(zone, opts, CORE_PATH)
  widget.app = sharedApp
  return widget
end

local function update(widget, opts)
  if widget.app then widget.app.update(widget, opts) end
end

local function refresh(widget, event, touch)
  if widget.app then widget.app.refresh(widget, event, touch) end
end

return {
  name = NAME,
  options = options,
  translate = translate,
  create = create,
  update = update,
  refresh = refresh,
  useLvgl = true,
  defs = DEFS,
  family = SPEC.family,
  coreApi = CORE_API,
  corePath = CORE_PATH,
}
