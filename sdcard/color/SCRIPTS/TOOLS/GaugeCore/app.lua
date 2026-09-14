---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - lifecycle                                                  #
---- #                                                                       #
---- # Loaded by main.lua on first use (the official Value2 pattern), so a   #
---- # radio that never places this widget pays only for main.lua at boot.   #
---- #                                                                       #
---- # create()  - state tables + module loading                             #
---- # update()  - options -> config -> ranges -> layout; rebuilds the LVGL  #
---- #             tree only when the structural signature changed           #
---- # refresh() - read telemetry, run alerts, update properties             #
---- #                                                                       #
---- # background() is deliberately absent: the firmware only calls it while #
---- # the widget is OFF screen, so all data maintenance lives in refresh(). #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local input = ...
-- Frontends pass an explicit product specification. Accepting the historical
-- bare DEFS array keeps local tools and old compiled mains diagnosable during
-- the transition, while every shipping frontend uses the structured form.
local SPEC
if type(input) == "table" and type(input.defs) == "table" then
  SPEC = input
else
  SPEC = { name = "GaugePro", family = nil, coreApi = 1, defs = input }
end
local DEFS = assert(SPEC.defs, "GaugePro: missing frontend option definitions")
local CORE_API = 1
if type(SPEC.name) ~= "string" or SPEC.name == "" then
  error("GaugeCore: frontend name must be a non-empty string")
end
if SPEC.family ~= nil and SPEC.family ~= "dial" and SPEC.family ~= "bar" then
  error(SPEC.name .. ": invalid GaugeCore family " .. tostring(SPEC.family))
end
if SPEC.coreApi ~= CORE_API then
  error((SPEC.name or "GaugePro") .. ": incompatible GaugeCore API (expected "
    .. tostring(SPEC.coreApi) .. ", found " .. tostring(CORE_API) .. ")")
end

local M = {}
M.coreApi = CORE_API

-- Shared product semantics are always present. Bar-only presentation and
-- motion are loaded only for GaugeBarPro (or for the legacy auto-dispatcher).
-- This matters on EdgeTX: each loaded chunk has a real RAM cost even when no
-- function from it is ever called.
local COMMON_MODULES = {
  "theme", "geometry", "format", "options", "ranges", "presets",
  "smoothing", "telemetry", "layout_common", "ui_core", "alerts",
}
local DIAL_MODULES = { "dial_layout", "dial_renderer" }
local BAR_MODULES = {
  "motion", "bar_layout", "bar_style", "bar_faces", "bar",
}

local function moduleNames()
  local names = {}
  for i = 1, #COMMON_MODULES do names[#names + 1] = COMMON_MODULES[i] end
  if SPEC.family == "dial" or SPEC.family == nil then
    for i = 1, #DIAL_MODULES do names[#names + 1] = DIAL_MODULES[i] end
  end
  if SPEC.family == "bar" or SPEC.family == nil then
    for i = 1, #BAR_MODULES do names[#names + 1] = BAR_MODULES[i] end
  end
  return names
end

local SCALE_AUTO = 1
local BATTERY_OFF = 1

-- Presentation aliases are deliberately exact and tiny. They must never feed
-- back into telemetry lookup, preset matching or persistence: `source.name`
-- remains the firmware identifier and only `nameText` consumes this mapping.
-- Do not normalize arbitrary third-party names; their spelling belongs to the
-- sensor author. Label overrides are resolved by configure() before this
-- helper, so user-authored text always wins.
local SOURCE_NAME_ALIASES = {
  ["tx-voltage"] = "TX VOLTAGE",
  ["TX_VOLTAGE"] = "TX VOLTAGE",
}

local function presentSourceName(name)
  if type(name) ~= "string" then return "" end
  return SOURCE_NAME_ALIASES[name] or name
end
M.presentSourceName = presentSourceName

-- The module table is SHARED by every widget instance: the modules are pure
-- (all per-widget state lives in the `widget` table), the setup() calls are
-- idempotent, and theme's metric caches are exactly what should be shared
-- across instances. main.lua also memoizes app.lua itself, so one screen
-- with four gauges loads each required chunk once rather than once per
-- instance (AUDIT.md P2-3).
-- Keyed by path so two differently-located copies of the widget stay
-- independent.
local MODS_BY_PATH = {}

local function loadModules(path)
  local mods = MODS_BY_PATH[path]
  if mods then return mods end
  mods = {}
  MODS_BY_PATH[path] = mods
  local names = moduleNames()
  for i = 1, #names do
    local name = names[i]
    local chunk, err = loadScript(path .. name .. ".lua", "bt")
    if not chunk then
      error((SPEC.name or "GaugePro") .. ": cannot load " .. name
        .. " from " .. path .. " (" .. tostring(err) .. ")")
    end
    local ok, mod = pcall(chunk)
    if not ok or type(mod) ~= "table" then
      error((SPEC.name or "GaugePro") .. ": bad module " .. name
        .. " from " .. path .. " (" .. tostring(mod) .. ")")
    end
    mods[name] = mod
  end
  mods.layout_common.setup(mods.theme, mods.geometry, mods.format)
  if mods.dial_layout then
    mods.dial_layout.setup(mods.layout_common, mods.theme, mods.geometry,
                           mods.format)
  end
  if mods.bar_layout then
    mods.bar_layout.setup(mods.layout_common, mods.theme, mods.geometry,
                          mods.format)
  end

  -- Compatibility facade used by the lifecycle. It composes exactly one
  -- family for the new frontends and both only for GaugePro legacy.
  mods.layout = {
    calculate = function(widget, cfg)
      local w, h = widget.zone.w, widget.zone.h
      local mode, orientation = mods.layout_common.classify(w, h)
      local layout = { mode = mode, orientation = orientation, w = w, h = h }
      local style = mods.layout_common.pickStyle(cfg, w, h, widget.family)
      if style == "bar" then
        return assert(mods.bar_layout,
          "GaugeCore: Bar layout was not loaded").calculate(widget, cfg, layout)
      end
      return assert(mods.dial_layout,
        "GaugeCore: Dial layout was not loaded").calculate(widget, cfg, layout)
    end,
    signature = mods.layout_common.signature,
    applyBarVisual = mods.bar_layout and mods.bar_layout.applyBarVisual,
  }
  mods.ui_core.setup(mods.theme, mods.geometry, mods.format)
  if mods.dial_renderer then
    mods.dial_renderer.setup(mods.ui_core, mods.theme, mods.geometry,
                             mods.format)
  end
  -- Public compatibility alias for existing diagnostics and tests. It points
  -- at the genuinely shared UI primitives, never at the dial renderer.
  mods.renderer = mods.ui_core
  if mods.dial_renderer then
    mods.renderer.angleOf = mods.dial_renderer.angleOf
    mods.renderer.bandSpan = mods.dial_renderer.bandSpan
  end
  if mods.motion then mods.motion.setup(mods.theme) end
  if mods.bar_style then mods.bar_style.setup(mods.theme, mods.presets) end
  if mods.bar_faces then
    mods.bar_faces.setup(mods.theme, mods.geometry, mods.renderer)
  end
  if mods.bar then
    mods.bar.setup(mods.theme, mods.geometry, mods.format, mods.renderer,
                   mods.bar_faces, mods.motion, mods.bar_style)
  end
  return mods
end

function M.create(zone, options, path)
  path = path or "/SCRIPTS/TOOLS/GaugeCore/"
  local widget = {
    zone = zone,
    options = options,
    path = path,
    family = SPEC.family,
    frontendName = SPEC.name or "GaugePro",
    defs = DEFS,
    mods = loadModules(path),
    -- `gen` counts REAL resolutions of the source (telemetry.resolveSource);
    -- configure() stamps widget.sourceGen with it so refresh() can spot a
    -- source that resolved after the last configure.
    source = { id = -1, resolved = false, name = "", unitName = "", gen = 0 },
    data = { availability = "unset" },
    history = {},
    smooth = {},
    alert = {},
    ui = {},
    frame = { props = {} },
    unitText = "",
    nameText = "",
  }
  return widget
end

-- Which renderer draws this layout.
local function painter(widget)
  return (widget.layout.style == "bar") and widget.mods.bar
      or widget.mods.dial_renderer
end
M.painter = painter

-- A dense segmented face can require nearly forty retained LVGL objects.
-- Building that tree in the same callback that parses all 2.12 options and
-- resolves layout/theme metadata needlessly concentrates the work. Existing
-- widgets therefore stage a structural settings rebuild: update() resolves
-- and latches the new structure, the next refresh builds it, and the normal
-- paint resumes one frame later. Initial creation and telemetry-driven
-- reconfiguration still build immediately because no prior tree exists (or
-- because refresh already owns the bounded callback).
local function rebuild(widget)
  widget.rebuildPending = false
  lvgl.clear()
  widget.ui = {}
  widget.frame = { props = {}, dirty = {} }
  painter(widget).build(widget)
end

-- Ranges, derived text and layout. Called from update(), and from refresh()
-- through the two one-shot latches there: the frame a battery pack's cell
-- count becomes known, and the frame a late-arriving sensor finally resolves.
local function configure(widget, deferRebuild)
  local m, cfg, src = widget.mods, widget.config, widget.source

  -- Everything below is DERIVED from `src`. Record which resolution of the
  -- source it was derived from, so refresh() can tell when a late-resolving
  -- sensor has left it stale (telemetry.resolveSource bumps src.gen).
  widget.sourceGen = src.gen

  -- scale: Auto uses a known-sensor preset, Manual always uses the user
  -- values. On firmware without the Scale option (2.11, ten slots) Auto keeps
  -- the original behaviour: presets apply only while the ranges are untouched.
  local auto
  if widget.hasScaleOption then
    auto = (cfg.scale == SCALE_AUTO)
  else
    auto = (cfg.rawMin == 0 and cfg.rawMax == 100 and cfg.rawWarn == 55
            and cfg.rawCrit == 35)
  end

  local minimum, maximum = cfg.rawMin, cfg.rawMax
  local warning, critical = cfg.rawWarn, cfg.rawCrit
  local highGood = cfg.highGood
  local precision = cfg.precision

  -- F-12: autoCells is auto-branch state and must default FALSE - the old
  -- code only wrote it inside the auto branch, so switching Auto -> Manual
  -- (or -> Battery) left a stale latch lying around (Tanda 6 F-12).
  widget.autoCells = false

  if cfg.battery ~= BATTERY_OFF then
    -- state of charge: the scale is always a percentage
    minimum, maximum, warning, critical, highGood = 0, 100, 30, 15, true
    precision = 0
  elseif auto then
    local preset = m.presets.find(src)
    widget.autoCells = (preset ~= nil) and preset.battery or false
    if preset then
      minimum, maximum = preset.minimum, preset.maximum
      warning, critical = preset.warning, preset.critical
      highGood = preset.highIsGood
      -- a pack voltage scale only means something once the cell count is
      -- known; until then keep the single-cell preset. And only for a
      -- reading that IS the pack total: a `cellsTable` source (Cels) showing
      -- Lowest or Average is still single-cell magnitude no matter how many
      -- cells were detected - rescaling it to the pack range would clamp it
      -- permanently near the bottom of the dial (AUDIT.md P1-6).
      local wantsPackRange = not preset.cellsTable
        or cfg.cells == m.telemetry.CELLS_TOTAL
      if preset.battery and src.cells and src.cells > 1 and wantsPackRange then
        local pack = m.presets.packRange(src.cells, "lipo")
        minimum, maximum = pack.minimum, pack.maximum
        warning, critical = pack.warning, pack.critical
        highGood = pack.highIsGood
      end
    end
  end

  -- When BOTH thresholds are out of the effective range on the same side,
  -- building the bands from them would turn the whole dial critical with
  -- zero-width warning/normal bands (e.g. a manual -120..0 dBm scale with
  -- the 0..100 defaults). Derive them at the presets' proportions instead
  -- (AUDIT.md G-4).
  warning, critical = m.ranges.saneThresholds(minimum, maximum, warning,
                                              critical, highGood)
  cfg.min, cfg.max, cfg.warn, cfg.crit = minimum, maximum, warning, critical
  cfg.highGood = highGood

  -- precision: Auto (1) follows the sensor, else the chosen decimal count
  if cfg.precisionChoice > 1 then
    precision = cfg.precisionChoice - 2
  elseif cfg.battery == BATTERY_OFF then
    precision = src.prec or 0
    if src.name == "tx-voltage" then precision = 1 end
  end
  cfg.precision = precision

  -- displayed strings
  if cfg.suffix and cfg.suffix ~= "" then
    widget.unitText = cfg.suffix
  elseif cfg.battery ~= BATTERY_OFF then
    widget.unitText = "%"
  else
    widget.unitText = src.unitName or ""
  end
  widget.nameText = (cfg.label and cfg.label ~= "") and cfg.label
                    or presentSourceName(src.name)

  widget.ranges = m.ranges.build(cfg.min, cfg.max, cfg.warn, cfg.crit,
                                 cfg.highGood)
  widget.deadband = m.ranges.deadband(cfg.min, cfg.max)

  local rangeSig = table.concat({ cfg.min, cfg.max, cfg.warn, cfg.crit,
                                  cfg.highGood and 1 or 0, cfg.precision }, ":")
  -- Battery mode and the Cells aggregation mode change which UNIT the
  -- displayed value is in without necessarily changing cfg.min/max (e.g.
  -- Lowest -> Total on a Cels source keeps the same pack-range scale), so
  -- rangeSig alone would miss it and leave stale per-cell-volt history mixed
  -- with pack-total readings (AUDIT.md P0-7).
  local historySig = tostring(cfg.battery) .. ":" .. tostring(cfg.cells)
  if rangeSig ~= widget.rangeSig or historySig ~= widget.historySig then
    widget.rangeSig = rangeSig
    widget.historySig = historySig
    m.telemetry.resetHistory(widget)
    m.smoothing.reset(widget)
    if widget.motionState then m.motion.reset(widget) end
  end

  local L = m.layout.calculate(widget, cfg)
  -- Resolve bar appearance from immutable stored config only when the active
  -- layout can consume it. A dial ignores every bar-only option, so it should
  -- not pay RGB analysis/cache-signature cost during configure either.
  if L.style == "bar" then
    widget.barVisual, widget.barPalette = m.bar_style.resolve(widget, cfg)
    widget.limitNotice = widget.barVisual.notice
    m.layout.applyBarVisual(L, widget.barVisual, cfg)
  else
    widget.barVisual, widget.barPalette = nil, nil
    widget.limitNotice = nil
  end
  widget.layout = L
  -- rangeSig is included so a range edit (min/max/warn/crit/precision, or the
  -- battery cell latch) rebuilds everything derived from it at BUILD time:
  -- section/rail arcs, bar threshold marks, scale end labels (AUDIT.md P0-2).
  local sig = m.layout.signature(L, cfg) .. ":" .. widget.unitText
    .. ":" .. widget.rangeSig
  if L.style == "bar" then
    sig = sig .. ":" .. widget.barVisual.structuralSig
  end
  if sig ~= widget.layoutSig then
    widget.layoutSig = sig
    widget.layoutRebuilt = true
    -- New split frontends stage their initial tree too: parsing/resolution
    -- and a rich Bar build in one callback measured above the 10k structural
    -- guardrail. GaugePro legacy keeps its historical immediate first build.
    local staged = deferRebuild and ((widget.ui and widget.ui.built)
      or SPEC.family ~= nil)
    if staged then
      widget.rebuildPending = true
    else
      rebuild(widget)
    end
  end
end
M.configure = configure

-- configure() PLUS the cheap delta path for text a rebuild did not repaint.
-- Every caller needs both halves: a signature change rebuilds the tree and
-- paints the current strings itself, but a config change that leaves the
-- signature alone - a Name/Suffix edit, or a source whose unit is empty -
-- only reaches the screen through updateSourceLabels (AUDIT.md P0-6).
-- Splitting the two across call sites is what let the late-resolution path
-- draw an unnamed, unitless gauge.
local function apply(widget, deferRebuild)
  widget.layoutRebuilt = false
  configure(widget, deferRebuild)
  -- setProp() no-ops when the string is unchanged, so this is free on the
  -- common "nothing moved" call.
  if not widget.layoutRebuilt then
    painter(widget).updateSourceLabels(widget)
  end
end
M.apply = apply

function M.update(widget, options)
  if not widget.mods then return end
  widget.options = options
  local m = widget.mods

  widget.hasScaleOption = (options.Scale ~= nil)
  local cfg = m.options.parse(DEFS, options)
  -- keep the authored values: configure() writes the *effective* scale into
  -- cfg.min/max, and the Auto heuristic must keep seeing what the user set
  cfg.rawMin, cfg.rawMax = cfg.min, cfg.max
  cfg.rawWarn, cfg.rawCrit = cfg.warn, cfg.crit
  cfg.precisionChoice = cfg.precision
  cfg.tau = m.smoothing.tau(cfg.damping)
  widget.config = cfg
  widget.accent = (cfg.accent and cfg.accent ~= 0) and cfg.accent or nil

  local prevId = widget.source.id
  local src = m.telemetry.resolveSource(widget)
  if src.id ~= prevId then
    widget.data.lastValue = nil   -- never show a new source's old data
    widget.data.state = nil
    src.cells = nil
    widget.cellsApplied = nil   -- let the NEW source's cell count re-latch
    m.telemetry.resetHistory(widget)
    m.smoothing.reset(widget)
    if widget.motionState then m.motion.reset(widget) end
    m.alerts.reset(widget)
  end

  apply(widget, true)
end

-- A SWITCH option is a swsrc_t, read with getSwitchValue() (AUDIT.md P0-1),
-- never getValue(). Unlike the alert switch, a misread here must NOT trigger
-- a reset, so any failure to read leaves resetArmed unchanged (no edge).
local function checkResetSwitch(widget)
  local sw = widget.config.resetSw
  if not sw or sw == 0 then return end
  if type(getSwitchValue) ~= "function" then return end
  local ok, value = pcall(getSwitchValue, sw)
  if not ok then return end
  local active = (value == true)
  if active and not widget.resetArmed then
    local idx = widget.source.sensorIndex
    if idx and type(model) == "table" and type(model.resetSensor) == "function" then
      -- For a real telemetry sensor, resetHistory() alone is undone within
      -- THIS SAME refresh(): telemetry.refresh() calls readHistorySiblings()
      -- right after, which reads the radio's own <name>-/<name>+ sources
      -- straight back, unreset (AUDIT.md P1-8). model.resetSensor() is the
      -- same primitive the official "Reset telemetry" action uses.
      model.resetSensor(idx)
    end
    widget.mods.telemetry.resetHistory(widget)
  end
  widget.resetArmed = active
end

function M.refresh(widget, _event, _touch)
  if not widget.mods then return end
  if widget.rebuildPending then
    rebuild(widget)
    return
  end
  if not widget.ui.built then return end
  local m = widget.mods
  checkResetSwitch(widget)
  m.telemetry.refresh(widget)

  -- Two things can invalidate the derived config from inside a frame. At most
  -- ONE of them is applied per refresh: apply() costs a full configure (~8k
  -- VM instructions on a large dial) against a 20000-instruction per-callback
  -- budget (lua_widget.cpp MAX_INSTRUCTIONS), and doing both in one frame
  -- would put two rebuilds in a single callback. Whichever does not fire this
  -- frame fires on the next one - both are one-shot latches.
  if widget.source.gen ~= widget.sourceGen then
    -- The source resolved LATE: it was absent when the widget was created (a
    -- fresh model, after "delete all sensors", a new RX) and the throttled
    -- retry in telemetry.refresh has just found it. resolveSource fills
    -- widget.source, but everything DERIVED from it - unit text, name, the
    -- Auto preset scale, precision, the layout - comes from configure(),
    -- which otherwise only runs from update(). The firmware calls update()
    -- "when the widget options have changed" (widget.h:109), not on a timer,
    -- so without this an RPM sensor discovered a second after boot kept
    -- drawing on the default 0..100 scale, nameless and unitless, until the
    -- user happened to edit an option.
    apply(widget, false)
  elseif widget.config.battery == BATTERY_OFF and widget.source.cells
         and not widget.cellsApplied then
    -- a battery pack's cell count is only known after the first reading; when
    -- it lands, the scale is rebuilt once
    widget.cellsApplied = true
    apply(widget, false)
  end

  -- EdgeTX/HTX does not guarantee widget.update() for a live theme switch.
  -- The resolver therefore probes the small resolved-role signature at most
  -- once per second and swaps only the palette table. bar.update() detects its
  -- signature and recolors the existing tree in this same refresh.
  if widget.layout.style == "bar" then
    m.bar_style.refreshPalette(widget, widget.config)
  end

  m.alerts.update(widget)
  painter(widget).update(widget)
end

return M
