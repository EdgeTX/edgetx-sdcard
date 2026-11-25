---- #########################################################################
---- # Gauge Core - retained LVGL dial renderer                              #
---- #########################################################################

local M = {}
local floor, max, min = math.floor, math.max, math.min
local T, G, F, U
local setProp, label, resolveColor, stateText

-- Object budget for the spatial gradient's arc slices. The dial's worst-case
-- tree (needle + hub + ticks + rails + history + full text stack) sits around
-- 30 objects, and the whole-tree ceiling both families are held to is 38, so
-- the ramp gets what is left with a floor that still reads as a ramp.
local DIAL_GRADIENT_SLICES = 8

function M.setup(uiCore, theme, geometry, format)
  U, T, G, F = uiCore, theme, geometry, format
  setProp, label, resolveColor = U.setProp, U.label, U.resolveColor
  stateText = U.stateText
  M.updateSourceLabels = U.updateSourceLabels
end

local function markRoundCenter(widget, obj)
  local ui = widget.ui
  local round = ui.roundCenters
  if not round then
    round = {}
    ui.roundCenters = round
  end
  round[obj] = true
end

-- ---------------------------------------------------------------- angles --

local function angleOf(widget, value)
  local cfg, L = widget.config, widget.layout
  local a = G.valueToAngle(value, cfg.min, cfg.max, L.startAngle, L.sweep)
  a = floor(a + 0.5)
  -- a full ring must never close onto its own start angle (zero length arc)
  local limit = L.startAngle + L.sweep - ((L.sweep >= 360) and 1 or 0)
  if a > limit then a = limit end
  if a < L.startAngle then a = L.startAngle end
  return a
end
M.angleOf = angleOf

-- Ordered (lo, hi) angle span for a band. Bands are always ascending in
-- VALUE space (ranges.build), but a descending scale (Min > Max) mirrors the
-- value->angle mapping (geometry.normalize), so angleOf(r.from) can come out
-- above angleOf(r.to). Sorting here, rather than assuming a2 > a1, is what
-- keeps sections/rails/marks visible on a descending scale (AUDIT.md P0-3).
local function bandSpan(widget, r)
  local a1, a2 = angleOf(widget, r.from), angleOf(widget, r.to)
  if a1 > a2 then a1, a2 = a2, a1 end
  return a1, a2
end
M.bandSpan = bandSpan

-- ----------------------------------------------------------------- build --

local function buildTrack(widget)
  local ui, L, cfg = widget.ui, widget.layout, widget.config
  -- Same clamp as angleOf(): lv_arc_set_bg_end_angle only subtracts 360 once
  -- (270 + 360 = 630 -> 270, equal to bgStartAngle), and LVGL skips drawing a
  -- zero-length arc entirely, so a full ring's background track never
  -- rendered without this (AUDIT.md P0-4).
  local endA = L.startAngle + L.sweep - ((L.sweep >= 360) and 1 or 0)
  ui.track = lvgl.arc{
    x = L.cx, y = L.cy, radius = L.radius,
    startAngle = L.startAngle, endAngle = endA,
    bgStartAngle = L.startAngle, bgEndAngle = endA,
    color = T.color.rail, bgColor = T.color.rail,
    bgOpacity = T.opacity.rail, opacity = 0,
    thickness = L.trackThickness, rounded = 1,
  }

  -- Sections: the whole scale as three coloured bands on the OUTER ring -
  -- the same position/opacity model as the Rail mode below - so the bands
  -- stay clearly visible regardless of where the value arc currently sits.
  -- Drawing them at the value arc's own radius/thickness put them directly
  -- underneath it at 25% opacity, which made Sections pixel-identical to
  -- Static at any value inside the normal band (AUDIT.md G-2).
  if cfg.colorMode == U.COLOR_SECTIONS then
    ui.sections = {}
    ui.sectionRoles = {}
    for i = 1, #widget.ranges do
      local r = widget.ranges[i]
      local a1, a2 = bandSpan(widget, r)
      if a2 > a1 then
        local c = T.stateColor(r.role, widget.accent)
        local sec = lvgl.arc{
          x = L.cx, y = L.cy, radius = L.railRadius,
          startAngle = a1, endAngle = a2,
          bgStartAngle = a1, bgEndAngle = a2,
          color = c, bgColor = c, bgOpacity = 255, opacity = 0,
          thickness = L.railThickness, rounded = 0,
        }
        -- LVGL objects are opaque userdata on the radio (no __newindex), so
        -- the role the repaint path needs rides in a parallel array instead
        -- of on the object (degenerate bands are skipped at build, so
        -- sections[i] is not ranges[i]).
        ui.sections[#ui.sections + 1] = sec
        ui.sectionRoles[#ui.sections] = r.role
        markRoundCenter(widget, sec)
      end
    end
  end

  -- threshold rail: a thin permanent reminder of where the bands are, drawn
  -- outside the track so the value arc keeps the foreground to itself. The
  -- bands draw at reduced opacity (railBand) so they read as the reference
  -- behind the value arc: in a critical state, the red of the arc dominates
  -- the red of the band instead of merging into one bevelled blob
  -- (review P-E).
  if cfg.colorMode == U.COLOR_RAIL then
    ui.rails = {}
    for i = 1, #widget.ranges do
      local r = widget.ranges[i]
      if r.role ~= "normal" then
        local a1, a2 = bandSpan(widget, r)
        if a2 > a1 then
          local c = T.stateColor(r.role, widget.accent)
          local rail = lvgl.arc{
            x = L.cx, y = L.cy, radius = L.railRadius,
            startAngle = a1, endAngle = a2,
            bgStartAngle = a1, bgEndAngle = a2,
            color = c, bgColor = c, bgOpacity = T.opacity.railBand, opacity = 0,
            thickness = L.railThickness, rounded = 0,
          }
          ui.rails[#ui.rails + 1] = rail
          markRoundCenter(widget, rail)
        end
      end
    end
  end
end

local function buildTicks(widget)
  local ui, L = widget.ui, widget.layout
  ui.ticks = {}
  local count = L.tickCount
  for i = 1, count do
    local a = L.startAngle + ((i - 1) / (count - 1)) * L.sweep
    ui.ticks[i] = lvgl.line{
      pts = G.linePoints(L.cx, L.cy, L.tickInner, L.tickOuter, a),
      thickness = L.tickThickness, color = T.color.tick,
    }
  end
  -- Minor ticks are shorter, thinner and dimmer rather than dashed:
  -- dashGap/dashWidth exist on hline/vline only (LvglWidgetLineBase), not on
  -- the free-angle line class (LvglWidgetLine).
  if L.minorTicks and L.minorTicks > 0 then
    ui.minors = {}
    local inner = L.tickInner
    local outer = L.tickInner + floor((L.tickOuter - L.tickInner) * 0.55)
    for i = 1, L.minorTicks do
      local a = L.startAngle + ((i - 0.5) / (count - 1)) * L.sweep
      ui.minors[i] = lvgl.line{
        pts = G.linePoints(L.cx, L.cy, inner, outer, a),
        thickness = 1, color = T.color.tick, opacity = T.opacity.ghost,
      }
    end
  end
end

-- Threshold mode's contract is "exact marks", and the bar has always drawn
-- them. The dial drew nothing, so Static, Threshold and Gradient were
-- byte-identical for as long as the reading stayed in the normal band - which
-- is nearly all of it. One radial line per INTERIOR boundary, in that
-- boundary's own colour, spanning the track so it reads against the arc
-- whether the arc has reached it or not.
local function buildThresholdMarks(widget)
  local ui, L, cfg = widget.ui, widget.layout, widget.config
  ui.thresholdMarks = {}
  for i = 1, #widget.ranges do
    local r = widget.ranges[i]
    local t = G.normalize(r.to, cfg.min, cfg.max)
    -- Interior only: the two ends of the scale are the track's own edges.
    if t > 0 and t < 1 then
      local a = angleOf(widget, r.to)
      ui.thresholdMarks[#ui.thresholdMarks + 1] = lvgl.line{
        pts = G.linePoints(L.cx, L.cy, L.thresholdInner, L.thresholdOuter, a),
        thickness = L.thresholdThickness,
        color = T.stateColor(r.role, widget.accent),
      }
    end
  end
end

local function buildNeedle(widget)
  local ui, L = widget.ui, widget.layout
  local a = L.startAngle
  -- A needle of LINES, not triangles: on the radio LvglWidgetTriangle::refresh
  -- frees the canvas and rebuilds it on every angle change - under needle
  -- damping the smoothed value moves almost every frame, so the audit
  -- measured ~46 canvas rebuilds in 20 frames and ~24 KB of heap churn per
  -- frame on a 200x200 zone (AUDIT.md P2-1). LvglWidgetLine::refresh only
  -- rewrites the points: no allocation churn at all.
  --
  -- The taper lost by P2-1 is restored with three lines, not two (review
  -- P-A, revised Tanda 5 on owner feedback): base -> mid -> tip. Two steps
  -- (thick body straight to a 2 px tip) read as a paddle with a toothpick
  -- glued to the end - the width more than halved in one jump. A middle
  -- segment splits that into two smaller steps, and `rounded = 1` on all
  -- three softens both the hub end and the two seams so they blend instead
  -- of showing a hard edge.
  -- Fixed colour, set once here and never touched by applyColors: the
  -- needle must stay legible against every band colour (green/amber/red)
  -- and the dark/light theme alike, so it does not follow the state colour
  -- the way the arc and value do (owner request, Tanda 5 review).
  -- The pts BUFFERS are persistent per segment (Phase 5.1): the binding
  -- copies the coordinates out on every set and keeps no reference, so
  -- updateArc can mutate them in place - the needle no longer allocates
  -- nine tables per angle change (Tanda 6 F-11). The { pts = ... } WRAPPER
  -- passed to lvgl.set is hoisted to a per-segment persistent table too
  -- (Phase 5.2): luaLvglSet parses the params table at CALL TIME
  -- (getParams -> parseParam, api_colorlcd_lvgl.cpp:116, lua_lvgl_widget.cpp
  -- :763) and retains no reference, so the same wrapper can be passed
  -- forever - its pts field points at the persistent buffer, whose fresh
  -- contents are read on every set. Both buffers and wrappers must NEVER
  -- go through setProp: its cache compares tables by identity and would
  -- drop every write after the first (5.1/5.2 TRAP 2) - the needle stays
  -- on direct lvgl.set.
  ui.needlePts = { { 0, 0 }, { 0, 0 } }
  ui.needleMidPts = { { 0, 0 }, { 0, 0 } }
  ui.needleTipPts = { { 0, 0 }, { 0, 0 } }
  ui.needleSet = { pts = ui.needlePts }
  ui.needleMidSet = { pts = ui.needleMidPts }
  ui.needleTipSet = { pts = ui.needleTipPts }
  ui.needle = lvgl.line{
    pts = G.linePointsInto(ui.needlePts, L.cx, L.cy, L.needleInner,
                           L.needleBodyOuter, a),
    thickness = max(1, L.needleHalf * 2), rounded = 1, color = T.color.needle,
  }
  ui.needleMid = lvgl.line{
    pts = G.linePointsInto(ui.needleMidPts, L.cx, L.cy, L.needleMidInner,
                           L.needleMidOuter, a),
    thickness = max(1, L.needleMidHalf * 2), rounded = 1, color = T.color.needle,
  }
  ui.needleTip = lvgl.line{
    pts = G.linePointsInto(ui.needleTipPts, L.cx, L.cy, L.needleTipInner,
                           L.needleOuter, a),
    thickness = L.needleTipThickness, rounded = 1, color = T.color.needle,
  }
  -- Solid hub: ONE filled circle in the neutral rail role, created after the
  -- needle so it covers the blade's inner end. The old ring+accent-dot pair
  -- read as pixel noise where needle, value and pivot meet; a clean solid
  -- circle reads as a deliberate centre (review P-A). The hub keeps the
  -- neutral tone in every state - it is the pivot, not a state indicator.
  ui.pivotRing = lvgl.circle{
    x = L.cx, y = L.cy, radius = L.pivotRadius,
    filled = 1, color = T.color.rail,
  }
end

function M.build(widget)
  local L, ui = widget.layout, widget.ui

  buildTrack(widget)
  buildTicks(widget)

  if L.showGhost then
    ui.ghost = lvgl.arc{
      x = L.cx, y = L.cy, radius = L.radius,
      startAngle = L.startAngle, endAngle = L.startAngle,
      bgStartAngle = L.startAngle, bgEndAngle = L.startAngle,
      bgOpacity = 0, opacity = T.opacity.ghost,
      color = T.color.rail,
      thickness = L.ghostThickness, rounded = 1,
    }
    lvgl.hide(ui.ghost)
    markRoundCenter(widget, ui.ghost)
  end

  -- Gradient is SPATIAL on both families (ui_core, "spatial gradient"): the
  -- arc is cut into slices whose colour is the severity of that point on the
  -- scale, exactly as the bar cuts its axis. The dial used to paint the whole
  -- arc one colour derived from the CURRENT value instead, which made Static,
  -- Threshold and Gradient byte-identical in the normal state and gave one
  -- option name two meanings across two widgets on the same screen.
  if widget.config.colorMode == U.COLOR_GRADIENT then
    local count = U.gradientSliceCount(
      L.radius * L.sweep * 0.0175, DIAL_GRADIENT_SLICES)
    ui.gradientArcs = {}
    ui.gradientSpans = {}
    local cfg = widget.config
    for i = 1, count do
      local a1 = L.startAngle + L.sweep * (i - 1) / count
      local a2 = L.startAngle + L.sweep * i / count
      local arc = lvgl.arc{
        x = L.cx, y = L.cy, radius = L.radius,
        startAngle = a1, endAngle = a2,
        bgStartAngle = a1, bgEndAngle = a2,
        bgOpacity = 0,
        color = U.spatialColor(cfg, nil, (i - 0.5) / count),
        -- Butt ends inside the run: a rounded cap on every slice would bead
        -- the arc. Only the two extremes keep the family's rounded end.
        thickness = L.arcThickness, rounded = (count == 1) and 1 or 0,
      }
      lvgl.hide(arc)
      markRoundCenter(widget, arc)
      ui.gradientArcs[i] = arc
      ui.gradientSpans[i] = { a1, a2, shown = false }
    end
    -- One canonical handle for shared code, as the bar keeps ui.fill.
    ui.valueArc = ui.gradientArcs[1]
  else
    ui.valueArc = lvgl.arc{
      x = L.cx, y = L.cy, radius = L.radius,
      startAngle = L.startAngle, endAngle = L.startAngle,
      bgStartAngle = L.startAngle, bgEndAngle = L.startAngle + L.sweep,
      bgOpacity = 0, color = T.color.accent,
      thickness = L.arcThickness, rounded = 1,
    }
    markRoundCenter(widget, ui.valueArc)
  end

  if widget.config.colorMode == U.COLOR_THRESHOLD then
    buildThresholdMarks(widget)
  end

  if L.showNeedle then buildNeedle(widget) end

  if L.showMarkers then
    -- Persistent pts buffers and persistent { pts = ... } wrappers, exactly
    -- like the needle (Phase 5.1 + 5.2): the binding copies the coordinates
    -- out on every set and retains no reference to either table, so both can
    -- be mutated in place forever. The marks were left out of Phase 5 and
    -- stayed the last per-frame allocator on the dial - 870 B/frame for the
    -- whole time the history is advancing, which is every second of a climb,
    -- not the "few seconds after power-up" the original note assumed.
    -- NEVER route these through setProp: its cache compares tables by
    -- identity and would drop every write after the first (5.1/5.2 TRAP 2).
    ui.minMarkPts = { { 0, 0 }, { 0, 0 } }
    ui.maxMarkPts = { { 0, 0 }, { 0, 0 } }
    ui.minMarkSet = { pts = ui.minMarkPts }
    ui.maxMarkSet = { pts = ui.maxMarkPts }
    ui.minMark = lvgl.line{
      pts = G.linePointsInto(ui.minMarkPts, L.cx, L.cy, L.markInner,
                             L.markOuter, L.startAngle),
      thickness = max(1, L.tickThickness), color = T.color.history,
    }
    ui.maxMark = lvgl.line{
      pts = G.linePointsInto(ui.maxMarkPts, L.cx, L.cy, L.markInner,
                             L.markOuter, L.startAngle),
      thickness = max(1, L.tickThickness), color = T.color.history,
    }
    lvgl.hide(ui.minMark)
    lvgl.hide(ui.maxMark)
  end

  ui.valueLabel = label(L.valueBox, L.valueFont, T.color.accent, L.valueAlign,
                        F.NO_VALUE)
  if L.showUnit and widget.unitText ~= "" then
    ui.unitLabel = label(L.unitBox, L.unitFont, T.color.label, L.unitAlign,
                         widget.unitText)
  end
  if L.showName then
    ui.nameLabel = label(L.nameBox, L.nameFont, T.color.label, L.nameAlign,
                         widget.nameText)
  end
  if L.showState then
    -- The pill is taller than the state text and centred on it, so the
    -- letters sit in the middle of the pill, not 1 px from its top edge
    -- (review P-B). The centring offset is LAYOUT data (L.chipOff): it must
    -- survive a no-op update(), which replaces the layout table but only
    -- rebuilds on a signature change - a renderer-written field was lost
    -- and the next chip render crashed on nil (Tanda 6 F-1).
    -- 1 px outline in the label role, behind the pill, so the badge keeps a
    -- defined edge instead of reading as "a piece of the rail behind the
    -- text" (review P-B). It matters more now that the fill is a status
    -- colour: the outline is what separates the badge from a theme whose
    -- background happens to sit near the same luminance, or from a
    -- background.png photograph.
    local edge = L.chipOutline
    ui.chipEdge = lvgl.rectangle{
      x = L.stateBox.x - edge, y = L.stateBox.y - L.chipOff - edge,
      w = L.stateBox.w + edge * 2, h = L.chipHeight + edge * 2,
      color = T.color.label, filled = 1,
      rounded = floor((L.chipHeight + edge * 2) / 2),
    }
    -- Built muted, shown coloured: the badge is hidden here and updateChip
    -- sets its fill and its ink from the state before it is ever shown.
    ui.chip = lvgl.rectangle{
      x = L.stateBox.x, y = L.stateBox.y - L.chipOff,
      w = L.stateBox.w, h = L.chipHeight,
      color = T.color.muted, filled = 1, rounded = floor(L.chipHeight / 2),
    }
    lvgl.hide(ui.chipEdge)
    lvgl.hide(ui.chip)
    -- hidden at build like the pill it belongs to: the three are one object
    -- as far as visibility is concerned (see updateChip)
    ui.stateLabel = label(L.stateBox, L.stateFont, T.labelOn(T.color.muted),
                          L.stateAlign)
    lvgl.hide(ui.stateLabel)
  end
  if L.showMinMaxText then
    ui.minText = label(L.minTextBox, L.minMaxFont, T.color.history, LEFT)
    ui.maxText = label(L.maxTextBox, L.minMaxFont, T.color.history, RIGHT)
  end
  if L.showScale then
    ui.scaleMin = label(L.scaleMinBox, L.scaleFont, T.color.label, CENTER,
                        F.display(widget, widget.config.min))
    ui.scaleMax = label(L.scaleMaxBox, L.scaleFont, T.color.label, CENTER,
                        F.display(widget, widget.config.max))
  end

  widget.frame = {
    props = {},
    dirty = {},
    angle = -1, ghostAngle = -1, minAngle = -1, maxAngle = -1,
    needleShown = true, markersShown = false, chipShown = false,
    colorKey = "", accentKey = nil, valueStr = "", stateStr = "",
    minStr = "", maxStr = "",
    prevAvail = "unset", pulse = false, pulseAt = 0,
  }
  ui.built = true
end

local function applyColors(widget, key)
  local ui = widget.ui
  local c = resolveColor(widget, key)
  local opa = (key == "muted") and T.opacity.muted or T.opacity.full
  if ui.gradientArcs then
    -- Each slice owns its colour (the severity of its own position), so only
    -- the muted/live opacity is a per-state decision here.
    for i = 1, #ui.gradientArcs do
      setProp(widget, ui.gradientArcs[i], "opacity", opa)
    end
  else
    setProp(widget, ui.valueArc, "color", c)
    setProp(widget, ui.valueArc, "opacity", opa)
  end
  -- the VALUE's ink is not set here: it follows the state, which moves on its
  -- own gate (U.applyStateInk)
  -- the needle is intentionally NOT touched here: it keeps T.color.needle,
  -- set once at build time (buildNeedle)
  --
  -- Neither is the badge: its fill and label are set by updateChip, which runs
  -- on a change of the state STRING. That is the correct gate - in Static mode
  -- colorKey never leaves "static", so a normal -> warning transition does not
  -- reach this function at all, and a badge coloured from here would have kept
  -- saying WARN in the all-clear colour.
  if ui.sections then
    -- The NORMAL band carries the accent and was painted at build time; an
    -- Accent edit repaints here without a rebuild, so it must be recolored
    -- in place (Tanda 6 F-5). The warn/crit bands are fixed colours and
    -- resolve to the same colour as before - setProp filters the no-ops.
    for i = 1, #ui.sections do
      local sec = ui.sections[i]
      setProp(widget, sec, "color",
              T.stateColor(ui.sectionRoles[i], widget.accent))
      -- F2: the reference bands used to keep full opacity while the gauge
      -- itself was muted, so a widget announcing NO LINK still had three
      -- fully saturated bands on it - one of them red - and they were the
      -- brightest thing on the dial. Whatever the value arc does, the passive
      -- reference behind it does too.
      setProp(widget, sec, "bgOpacity", opa)
    end
  end
  if ui.rails then
    -- P1-3 (Tanda 5 review 3.6): only while critical, drop every passive
    -- band one step further so the full-red arc/text stay the brightest
    -- thing on the ring. WARN keeps the normal reference opacity - there
    -- the amber band IS the active state, not a competing one.
    -- Muted overrides both: see the note on sections above.
    local railOpa = T.opacity.railBand
    if key == "muted" then railOpa = T.opacity.muted
    elseif key == "critical" then railOpa = T.opacity.railBandCrit end
    for _, rail in ipairs(ui.rails) do
      setProp(widget, rail, "bgOpacity", railOpa)
    end
  end
end
local function updateText(widget)
  local ui, frame = widget.ui, widget.frame
  local data = widget.data

  local str
  if data.availability == "unset" then
    str = F.NO_VALUE
  else
    str = F.display(widget, data.displayValue)
  end
  if str ~= frame.valueStr then
    frame.valueStr = str
    setProp(widget, ui.valueLabel, "text", str)
    U.anchorUnit(widget, str)
  end

  if ui.stateLabel then
    local s = stateText(widget)
    if s ~= frame.stateStr then
      frame.stateStr = s
      setProp(widget, ui.stateLabel, "text", s)
      U.updateChip(widget, s)
    end
  end

  if ui.minText then
    local h = widget.history
    local mn = h.min and F.display(widget, h.min) or ""
    local mx = h.max and F.display(widget, h.max) or ""
    if mn ~= frame.minStr then
      frame.minStr = mn
      setProp(widget, ui.minText, "text", (mn ~= "") and ("min " .. mn) or "")
    end
    if mx ~= frame.maxStr then
      frame.maxStr = mx
      setProp(widget, ui.maxText, "text", (mx ~= "") and ("max " .. mx) or "")
    end
  end
end

-- NEEDLE LENGTH IS CONSTANT (Tanda 7 A, replacing Tanda 5 review 3.12/P0-4).
--
-- P0-4 used to shorten the blade whenever the current angle's ray entered the
-- state chip, so it would not be "drawn through a solid pill". The paint
-- order already guarantees that: renderer.build creates the needle (objects
-- 11-13 on a 200x160 dial) BEFORE the chip (20-21), the chip is `filled = 1`
-- with no opacity - fully opaque - and LVGL paints children in creation
-- order. The blade behind the pill was never visible in the first place.
--
-- What the truncation did cost was the needle itself. Measured at 200x160,
-- Sweep 270, chip shown: 41 % of the blade left at value 30, 28 % at 34,
-- 18 % at 40, and 13 % - 5 of 38 px - at value 50. It bit on 25 % of the
-- scale at 270 deg, 35 % at 180 and 16 % at 360, and ONLY while a chip was
-- up: that is WARN / CRIT / STALE / NO LINK / NO DATA, the states the pilot
-- actually looks at. A needle that changes length as it sweeps reads as a
-- rendering fault, because no real instrument does it.
--
-- So the needle now runs its full reach at every angle and passes BEHIND the
-- badge, the way a pointer passes behind a label on a real gauge. This is the
-- same creation-order contract the value and name labels already rely on to
-- paint over the arcs (Tanda 5 review 3.1) - not a new assumption. It is
-- pinned by "A: the chip occludes the needle by paint order" in the suite, so
-- if the order or the chip's opacity ever changes, that test fails first and
-- says why.

-- Sweep the sliced ramp up to `angle`. Only the slice the value is inside
-- changes span; the ones behind it are already at full span and the ones
-- ahead are already hidden, so an ordinary frame touches one object - the
-- same shape as the bar's gradient prefix walk.
local function updateGradientArcs(widget, angle)
  local ui = widget.ui
  local arcs, spans = ui.gradientArcs, ui.gradientSpans
  for i = 1, #arcs do
    local span = spans[i]
    local a1, a2 = span[1], span[2]
    if angle >= a2 then
      if span.paint ~= a2 then
        span.paint = a2
        setProp(widget, arcs[i], "endAngle", a2)
      end
      if not span.shown then
        span.shown = true
        lvgl.show(arcs[i])
      end
    elseif angle > a1 then
      local clipped = min(a2, max(a1, angle))
      if span.paint ~= clipped then
        span.paint = clipped
        setProp(widget, arcs[i], "endAngle", clipped)
      end
      if not span.shown then
        span.shown = true
        lvgl.show(arcs[i])
      end
    elseif span.shown then
      span.shown = false
      lvgl.hide(arcs[i])
    end
  end
end

local function updateArc(widget)
  local ui, L, frame = widget.ui, widget.layout, widget.frame
  local data = widget.data

  if data.availability ~= "valid" or data.displayValue == nil then
    widget.smooth.value = nil
    if frame.needleShown then
      frame.needleShown = false
      if ui.needle then lvgl.hide(ui.needle) end
      if ui.needleMid then lvgl.hide(ui.needleMid) end
      if ui.needleTip then lvgl.hide(ui.needleTip) end
    end
    return
  end

  if frame.prevAvail ~= "valid" then
    widget.smooth.value = nil  -- snap on reconnect instead of sweeping up
  end
  local sv = widget.mods.smoothing.step(widget, data.displayValue)
  local a = angleOf(widget, sv)
  -- The old `or frame.chipShown ~= frame.needleClampChip` term went with
  -- needleReach: it existed only to re-cut the blade when the chip appeared
  -- or vanished, and a blade of constant length has nothing to re-cut. One
  -- fewer comparison per frame, and one fewer needle rewrite per state change.
  if a ~= frame.angle then
    frame.angle = a
    if ui.gradientArcs then
      updateGradientArcs(widget, a)
    else
      setProp(widget, ui.valueArc, "endAngle", a)
    end
    if ui.needle then
      -- three line segments, all rewritten with the same guarded pts path
      -- as before: base + mid + tip sweep together (P2-1). The pts tables
      -- are the PERSISTENT buffers from buildNeedle, mutated in place by
      -- linePointsInto, and the wrappers are the PERSISTENT { pts = ... }
      -- tables too - zero allocation per frame (Phase 5.1 + 5.2). Direct
      -- lvgl.set, NEVER setProp (identity cache would freeze both, TRAP 2).
      G.linePointsInto(ui.needlePts, L.cx, L.cy, L.needleInner,
                       L.needleBodyOuter, a)
      lvgl.set(ui.needle, ui.needleSet)
      G.linePointsInto(ui.needleMidPts, L.cx, L.cy, L.needleMidInner,
                       L.needleMidOuter, a)
      lvgl.set(ui.needleMid, ui.needleMidSet)
      G.linePointsInto(ui.needleTipPts, L.cx, L.cy, L.needleTipInner,
                       L.needleOuter, a)
      lvgl.set(ui.needleTip, ui.needleTipSet)
    end
  end
  if not frame.needleShown then
    frame.needleShown = true
    if ui.needle then lvgl.show(ui.needle) end
    if ui.needleMid then lvgl.show(ui.needleMid) end
    if ui.needleTip then lvgl.show(ui.needleTip) end
  end
end

local function updateHistory(widget)
  local ui, L, frame = widget.ui, widget.layout, widget.frame
  local h = widget.history

  -- peak-hold ghost: INDEPENDENT of the markers option (firmware idiom
  -- C.3 - always created, visibility driven by DATA). The dial used to
  -- early-return on ui.minMark, so with Min/max = Off the ghost existed
  -- but could never show, while the bar's ghost worked (Tanda 6 F-8).
  -- Both h.min and h.max are required: readHistorySiblings can populate
  -- them independently, and the descending-scale peak picks either one.
  if ui.ghost then
    if h.min and h.max then
      local peak = (widget.config.max >= widget.config.min) and h.max or h.min
      local ga = angleOf(widget, peak)
      if ga ~= frame.ghostAngle then
        frame.ghostAngle = ga
        setProp(widget, ui.ghost, "endAngle", ga)
        setProp(widget, ui.ghost, "bgEndAngle", ga)
        lvgl.show(ui.ghost)
      end
    elseif frame.ghostAngle ~= -1 then
      -- The history was CLEARED - the reset switch, a source change, a range
      -- edit. The markers below already leave on the same event; the ghost
      -- used to stay behind, still marking a peak that no longer exists, and
      -- only corrected itself on the next valid reading. In a dropout, or
      -- straight after a reset on a disconnected model, that is indefinite.
      -- -1 is the build-time sentinel and no real angle (angleOf never
      -- returns below startAngle), so restoring it also re-arms the show.
      frame.ghostAngle = -1
      lvgl.hide(ui.ghost)
    end
  end

  if not ui.minMark then return end

  local shown = (h.min ~= nil and h.max ~= nil)
  if shown ~= frame.markersShown then
    frame.markersShown = shown
    if shown then
      lvgl.show(ui.minMark)
      lvgl.show(ui.maxMark)
    else
      lvgl.hide(ui.minMark)
      lvgl.hide(ui.maxMark)
    end
  end
  if not shown then return end

  -- in-place into the build-time buffers, direct lvgl.set, never setProp
  local a = angleOf(widget, h.min)
  if a ~= frame.minAngle then
    frame.minAngle = a
    G.linePointsInto(ui.minMarkPts, L.cx, L.cy, L.markInner, L.markOuter, a)
    lvgl.set(ui.minMark, ui.minMarkSet)
  end
  a = angleOf(widget, h.max)
  if a ~= frame.maxAngle then
    frame.maxAngle = a
    G.linePointsInto(ui.maxMarkPts, L.cx, L.cy, L.markInner, L.markOuter, a)
    lvgl.set(ui.maxMark, ui.maxMarkSet)
  end
end
function M.update(widget)
  local ui = widget.ui
  if not ui.built then return end
  local frame = widget.frame

  local key = U.colorKey(widget)
  -- The accent is an INPUT to the colour (normal band, Static mode), so an
  -- Accent edit must repaint even when the semantic key did not change
  -- (Tanda 6 F-5; cf. radio_info.cpp re-reading its colour options in
  -- update()). frame.colorKey stays the SEMANTIC key - tests and the
  -- gallery read it as the state label - the accent rides on its own gate.
  if key ~= frame.colorKey or widget.accent ~= frame.accentKey then
    frame.colorKey = key
    frame.accentKey = widget.accent
    applyColors(widget, key)
  end

  U.applyStateInk(widget)
  updateText(widget)
  updateArc(widget)
  updateHistory(widget)
  -- The pill, not the arc. Modulating the value arc's opacity took the
  -- critical red down to 1.74:1 against a dark theme at the trough - the data
  -- channel disappearing to announce that it matters. The pill is the status
  -- channel and CRIT keeps it on screen even with the chip option off, which
  -- is what makes it the safe carrier here and on the bar (bar.lua).
  if ui.chip then
    ui.pulseTargets = ui.pulseTargets
      or { ui.chip, ui.chipEdge, ui.stateLabel }
    U.updatePulse(widget, key, ui.pulseTargets)
  end

  U.flush(widget)
  frame.prevAvail = widget.data.availability
end

return M
