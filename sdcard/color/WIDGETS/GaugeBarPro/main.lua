---- #########################################################################
---- # Gauge Bar - bar frontend backed by the shared GaugeCore               #
---- #########################################################################

local TEST = ...
local NAME = "BarPro"
local CORE_API = 1
local CORE_PATH = "/SCRIPTS/TOOLS/GaugeCore/"
if type(TEST) == "table" and type(TEST.corePath) == "string" then
  CORE_PATH = TEST.corePath
end
if string.sub(CORE_PATH, -1) ~= "/" then CORE_PATH = CORE_PATH .. "/" end

if lvgl == nil then
  return {
    name = NAME,
    options = {},
    create = function(zone) return { zone = zone } end,
    update = function() end,
    refresh = function()
      lcd.drawText(3, 3, "Gauge Bar needs EdgeTX 2.11+", SMLSIZE)
    end,
  }
end

-- Wire contract: existing entries are immutable and new entries append only.
-- The shared prefix is pinned against GaugeDialPro by widgets_test.lua.
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
  { key = "BarPreset", label = "Bar preset", type = CHOICE,
    field = "barPreset", since = 211, default = 2,
    choices = { "Auto", "Classic", "Theme", "Hex", "Blocks", "Ticks",
                "RC center", "Minimal", "Bold data" } },

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

  { key = "BarFace", label = "Bar face", type = CHOICE,
    field = "barFace", since = 212, default = 1,
    choices = { "Auto", "Continuous", "Blocks", "Hex", "Ticks", "Steps",
                "Dual rail" } },
  { key = "BarDir", label = "Bar direction", type = CHOICE,
    field = "barDir", since = 212, default = 1,
    choices = { "Auto", "Horizontal", "Vertical" } },
  { key = "BarOrigin", label = "Bar origin", type = CHOICE,
    field = "barOrigin", since = 212, default = 1,
    choices = { "Auto", "Scale low", "Zero" } },
  { key = "BarSize", label = "Bar thickness", type = CHOICE,
    field = "barSize", since = 212, default = 1,
    choices = { "Auto", "Thin", "Medium", "Thick", "Maximum" } },
  { key = "BarEnds", label = "Bar ends", type = CHOICE,
    field = "barEnds", since = 212, default = 1,
    choices = { "Auto", "Round", "Square", "Chamfer" } },
  { key = "Segments", label = "Bar segments", type = CHOICE,
    field = "segments", since = 212, default = 1,
    choices = { "Auto", "6", "8", "10", "12", "16", "24" } },
  { key = "SegGap", label = "Segment gap", type = CHOICE,
    field = "segGap", since = 212, default = 1,
    choices = { "Auto", "Tight", "Normal", "Wide" } },
  { key = "Palette", label = "Palette", type = CHOICE,
    field = "palette", since = 212, default = 1,
    choices = { "Auto", "Classic", "Theme adaptive", "Custom 3",
                "Custom 2" } },
  { key = "WarnClr", label = "Warning colour", type = COLOR,
    field = "warnClr", since = 212, default = lcd.RGB(0xc8, 0x60, 0x00) },
  { key = "CritClr", label = "Critical colour", type = COLOR,
    field = "critClr", since = 212, default = lcd.RGB(0xff, 0x00, 0x00) },
  { key = "TrackClr", label = "Track colour", type = COLOR,
    field = "trackClr", since = 212, default = COLOR_THEME_SECONDARY1 },
  { key = "Surface", label = "Surface", type = CHOICE,
    field = "surface", since = 212, default = 1,
    choices = { "Auto", "Transparent", "Theme panel", "Custom colors" } },
  { key = "PanelClr", label = "Panel colour", type = COLOR,
    field = "panelClr", since = 212, default = COLOR_THEME_SECONDARY3 },
  { key = "Contrast", label = "Contrast assist", type = CHOICE,
    field = "contrast", since = 212, default = 1,
    choices = { "Auto", "Off", "Strong" } },
  { key = "Motion", label = "Motion", type = CHOICE,
    field = "motion", since = 212, default = 1,
    choices = { "Auto", "Off", "Essential", "Refined", "Expressive" } },
  { key = "BarHead", label = "Position head", type = CHOICE,
    field = "barHead", since = 212, default = 1,
    choices = { "Auto", "None", "Cap", "Dot", "Line", "Needle" } },
  { key = "ScaleMarks", label = "Scale marks", type = CHOICE,
    field = "scaleMarks", since = 212, default = 1,
    choices = { "Auto", "Off", "Thresholds", "Ends", "Full" } },
  { key = "ValuePos", label = "Value position", type = CHOICE,
    field = "valuePos", since = 212, default = 1,
    choices = { "Auto", "Above", "Inside", "End", "Off" } },
  { key = "LabelPos", label = "Name position", type = CHOICE,
    field = "labelPos", since = 212, default = 1,
    choices = { "Auto", "Above", "Below", "Inside", "Off" } },
}

local SPEC = { name = NAME, family = "bar", coreApi = CORE_API, defs = DEFS }

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
local labels = { [NAME] = "Gauge Bar Pro" }
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
