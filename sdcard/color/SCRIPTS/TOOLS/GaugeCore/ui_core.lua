---- #########################################################################
---- # Gauge Core - shared retained LVGL and semantic UI primitives          #
---- #########################################################################

local M = {}
local floor, max = math.floor, math.max
local T, G, F

function M.setup(theme, geometry, format)
  T, G, F = theme, geometry, format
end

M.COLOR_STATIC, M.COLOR_THRESHOLD, M.COLOR_RAIL, M.COLOR_GRADIENT,
  M.COLOR_SECTIONS = 1, 2, 3, 4, 5

-- Property writes are QUEUED per object and flushed in one lvgl.set call at
-- the end of the frame: each lvgl.set is a full C++ getParams + refresh(), so
-- a state transition that touches six objects with two keys each used to
-- emit 14 refreshes when 6 would do (AUDIT.md P2-2). The cache still filters
-- unchanged keys, and it is updated immediately, so later reads in the same
-- frame see the new value.
local function setProp(widget, obj, key, value)
  if not obj then return end
  local frame = widget.frame
  local props = frame.props
  local cache = props[obj]
  if not cache then
    cache = {}
    props[obj] = cache
  end
  if cache[key] == value then return end
  cache[key] = value
  -- Keep one dirty-property table per retained LVGL object. Clearing the
  -- table after flush makes it reusable, avoiding one table allocation for
  -- every moving segment on every frame.
  local dirty = frame.dirty
  if not dirty then
    dirty = {}
    frame.dirty = dirty
  end
  local t = dirty[obj]
  if not t then
    t = {}
    dirty[obj] = t
  end
  local queued = frame.dirtyQueued
  if not queued then
    queued = {}
    frame.dirtyQueued = queued
  end
  if not queued[obj] then
    queued[obj] = true
    local list = frame.dirtyList
    if not list then
      list = {}
      frame.dirtyList = list
    end
    local n = (frame.dirtyCount or 0) + 1
    frame.dirtyCount = n
    list[n] = obj
  end
  t[key] = value
end
M.setProp = setProp

-- Send every queued property for each object in a single lvgl.set call.
-- Called once at the end of each update frame (renderer and bar).
--
-- F-01 (docs/visual-kit/INFORME-DEFECTOS.md): on the radio,
-- LvglWidgetRoundObject::refresh() - which EVERY lvgl.set on an arc or
-- circle triggers, whichever property changed - recomputes the object's
-- screen position from its OWN cached x/y, and that recompute lands wrong
-- for any arc that has already been shown once. Confirmed empirically with
-- an isolated repro against this exact build (not a Gauge Pro bug): a
-- freshly built arc paints correctly; the moment ANY property on it is
-- rewritten with lvgl.set - endAngle, colour, opacity, doesn't matter which
-- - it jumps off-centre. Reaffirming radius.coord does not help (the radio
-- clamps back to the SAME wrong spot). The one fix that reproducibly holds,
-- confirmed across four consecutive updates at the dial's real radius, is
-- resending the UNCONVERTED centre as x/y in that SAME lvgl.set call, every
-- time, forever - so every batched write to a round object carries it here,
-- rather than patching each call site (and rather than the corner-coordinate
-- correction floated in the original writeup, which measured no better than
-- doing nothing).
function M.flush(widget)
  local frame = widget.frame
  local count = frame.dirtyCount or 0
  if count == 0 then return end
  local dirty, list, queued = frame.dirty, frame.dirtyList,
    frame.dirtyQueued
  -- On widget.ui, NOT widget.frame: M.build() below unconditionally replaces
  -- widget.frame wholesale (a fresh per-build animation-state table) AFTER
  -- every arc in this file has already been built and marked, so a registry
  -- kept on frame would be thrown away before its first flush ever runs.
  -- widget.ui is the retained object tree and is only ever added to, never
  -- replaced, once M.build() starts - the correct home for "which of these
  -- retained objects need this treatment".
  local round, L = widget.ui.roundCenters, widget.layout
  for i = 1, count do
    local obj = list[i]
    local t = dirty[obj]
    if round and round[obj] then
      t.x, t.y = L.cx, L.cy
    end
    lvgl.set(obj, t)
    for key in pairs(t) do t[key] = nil end
    queued[obj] = nil
  end
  frame.dirtyCount = 0
end

-- Registers `obj` (an arc or circle whose centre is the dial's own L.cx/L.cy)
-- so every future setProp-batched write to it re-sends that centre - see the
-- F-01 note on M.flush above. Objects that are never updated after build
-- (the track) do not need this: the bug only shows up on a SUBSEQUENT
-- lvgl.set, and a freshly built arc is already correct.

local function label(box, font, color, align, text)
  return lvgl.label{
    x = box.x, y = box.y, w = box.w, h = box.h,
    text = text or "", font = font, color = color, align = align or LEFT,
  }
end
M.label = label

-- ---------------------------------------------------------------- colours --

-- Semantic key for the current frame. Gradient mode quantises the ramp so a
-- slowly drifting value does not repaint on every frame.
function M.colorKey(widget)
  local data, cfg = widget.data, widget.config
  if data.availability ~= "valid" or data.displayValue == nil then
    return "muted"
  end
  if widget.source.isTimer and data.value and data.value < 0 then
    return "warning"  -- elapsed countdown, as the official Value widget does
  end
  if cfg.colorMode == M.COLOR_STATIC then return "static" end
  if cfg.colorMode == M.COLOR_GRADIENT then
    -- ramp across the THRESHOLDS, not the whole scale: red at the critical
    -- boundary, green once the value is in the normal band (GaugeRotary's
    -- getRangeColor semantics). A gradient over min..max would show green
    -- while the value sits just above the warning line.
    local lo, hi = cfg.crit, cfg.warn
    if lo > hi then lo, hi = hi, lo end
    -- Equal thresholds give the ramp a zero span, so normalize() pins every
    -- value to the red end (AUDIT.md P1-5). Fall back to the band colour: a
    -- warn == crit configuration is a sharp cliff, and the state already says
    -- which side of it the value is on.
    if lo == hi then return data.state or "normal" end
    local t = G.normalize(data.displayValue, lo, hi)
    if not cfg.highGood then t = 1 - t end
    return "grad" .. floor(t * 20)
  end
  return data.state or "normal"
end

-- The colour for a semantic key: accent in Static mode, the gradient ramp
-- for gradN, the theme role otherwise. Shared with the bar (Tanda 6 F-15:
-- bar.lua used to carry its own copy of this).
local function resolveColor(widget, key, palette)
  if key == "static" then return widget.accent or T.color.accent end
  if string.sub(key, 1, 4) == "grad" then
    local step = tonumber(string.sub(key, 5)) or 0
    if palette then return T.paletteColor(palette, step / 20, 20) end
    return T.gradientColor(step / 20)
  end
  return T.stateColor(key, widget.accent, palette)
end
M.resolveColor = resolveColor

-- ---- spatial gradient (shared by both families) --------------------------
--
-- Gradient means ONE thing: the colour of a point is the severity OF THAT
-- POINT ON THE SCALE, so the whole instrument shows where the bad end is
-- before the reading ever gets there. The bar slices its axis; the dial
-- slices its arc. They differ in geometry and in nothing else - the rule,
-- the slice budget and the colour lookup all live here so a change to one
-- family cannot quietly become a second meaning in the other.
--
-- The dial used to take a completely different route: one colour for the
-- whole arc, interpolated from the CURRENT value's distance to the
-- thresholds. That is a legitimate idea, but it is not this one, and two
-- gauges on one screen answered different questions under one option name.

-- How many slices a run of `length` px deserves, capped by the object budget.
function M.gradientSliceCount(length, available)
  local target = math.ceil(math.max(1, tonumber(length) or 1) / T.px(12))
  target = math.max(8, math.min(24, target))
  return math.max(1, math.min(target, floor(tonumber(available) or 24)))
end

-- Map a physical position on the authored scale into the semantic gradient:
-- critical=0, warning=.5, normal=1. Descending scales and low-is-good both
-- fall out of the same value mapping instead of swapping face-local bands.
function M.gradientPosition(cfg, axisPosition)
  axisPosition = math.max(0, math.min(1, tonumber(axisPosition) or 0))
  local value = cfg.min + (cfg.max - cfg.min) * axisPosition
  local lo, hi = cfg.crit, cfg.warn
  if lo > hi then lo, hi = hi, lo end
  if lo == hi then
    if cfg.highGood then return (value >= hi) and 1 or 0 end
    return (value <= lo) and 1 or 0
  end
  local t = G.normalize(value, lo, hi)
  if not cfg.highGood then t = 1 - t end
  return t
end

-- The colour a slice at `position` takes. `palette` is the bar's resolved
-- table; the dial has no palette resolver and passes nil, which falls back to
-- the calibrated status colours - the same three the bar's "classic" palette
-- carries, so both families land on identical RGB for identical severities.
function M.spatialColor(cfg, palette, position)
  palette = palette or T.color
  local t = M.gradientPosition(cfg, position)
  if t <= 0 then return palette.critical or T.color.crit end
  if t >= 1 then return palette.normal or T.color.accent end
  if t == 0.5 then return palette.warning or T.color.warn end
  return T.paletteColor(palette.critical and palette or nil, t, 24)
end

-- The colour for the VALUE text. Shared with the bar (bar.lua calls it), so
-- both orientations obey the same rule.
--
-- The status colour used to drive this directly, which is how a UI-background
-- role ended up as the primary readout's ink. The value is DATA, so it takes
-- the theme's own text role and stays legible whatever the state (Tanda 8
-- §3.2). Two exceptions, both deliberate:
--   * CRITICAL - alarm outranks neutral legibility, it is the universal
--     convention, and the fixed red clears 3:1 on both reference backgrounds.
--   * MUTED - a gauge with no data must RECEDE; leaving the value at full
--     theme ink would make a stale reading look like a live one.
-- Takes the STATE key, never the frame's colour key: in Static mode colorKey
-- is permanently "static" and in Gradient mode "grad0".."grad20", so a value
-- coloured from there would never have turned red in two of the five modes.
function M.valueColor(key, palette)
  if key == "critical" then
    return (palette and palette.critical) or T.color.crit
  end
  if key == "muted" then return (palette and palette.muted) or T.color.muted end
  return (palette and palette.value) or T.color.value
end

-- The value's ink follows the STATE, and the state moves independently of the
-- colour key, so it needs a gate of its own. Shared with the bar.
function M.applyStateInk(widget, palette)
  local frame = widget.frame
  -- through the module table: stateKey is declared further down the file
  local skey = M.stateKey(widget)
  local paletteSig = palette and palette.signature
  if skey ~= frame.stateKey or paletteSig ~= frame.stateInkPaletteSig then
    frame.stateKey = skey
    frame.stateInkPaletteSig = paletteSig
    local ink = M.valueColor(skey, palette)
    setProp(widget, widget.ui.valueLabel, "color", ink)
    -- The unit goes with it in the two EXCEPTION states, and only there.
    -- "22" in red beside "dB" in the label role read as two different things
    -- when they are one token; the same split made a stale "78" grey next to
    -- a live-looking blue "dB". In the ordinary states the unit keeps its
    -- quieter role on purpose - that hierarchy (big dark number, small quiet
    -- unit) is what makes the number the thing you see first.
    if widget.ui.unitLabel then
      setProp(widget, widget.ui.unitLabel, "color",
              (ink == ((palette and palette.value) or T.color.value))
                and ((palette and palette.label) or T.color.label) or ink)
    end
  end
end


-- ---------------------------------------------------------------- updates --

local function stateText(widget)
  local data = widget.data
  local a = data.availability
  if a == "unset" then return "NO SOURCE" end
  if a == "disconnected" then return "NO LINK" end
  if a == "stale" then return "STALE" end
  if a ~= "valid" then return "NO DATA" end
  -- An elapsed countdown timer is classified WARNING by colorKey (the arc is
  -- amber); its raw state is critical because a negative value sits below the
  -- scale minimum. The chip must say what the instrument paints - a CRIT
  -- word in warning colour is the worst of both worlds (AUDIT.md G-3).
  if widget.source.isTimer and data.value and data.value < 0 then
    return "WARN"
  end
  if data.state == "warning" then return "WARN" end
  if data.state == "critical" then return "CRIT" end
  if widget.limitNotice then return widget.limitNotice.text or "LIMIT" end
  return ""
end
M.stateText = stateText

-- The semantic key BEHIND the chip's text, which is not always the frame's
-- colour key: in Static mode colorKey is permanently "static", and in Gradient
-- mode it is "grad0".."grad20". Colouring the badge from those would have
-- printed CRIT on an all-clear fill in two of the five colour modes.
local function stateKey(widget)
  local data = widget.data
  if data.availability ~= "valid" then return "muted" end
  if widget.source.isTimer and data.value and data.value < 0 then
    return "warning"
  end
  return data.state or "normal"
end
M.stateKey = stateKey

-- Show or hide the state chip, hugging its text. Shared by the dial and the
-- bar so both signal state identically: the bar used to have no chip at all,
-- leaving WARN/CRIT as bare text in bar zones while dial zones got the full
-- pill (AUDIT.md P1-10).
function M.updateChip(widget, s, palette)
  local ui, frame = widget.ui, widget.frame
  if not ui.chip then return end
  local show = (s ~= "")
  -- F9: `State chip = Off` is an appearance preference, and it used to
  -- suppress the pill in EVERY state - including WARN and CRIT. That left the
  -- normal/warning distinction resting on hue alone, which is precisely the
  -- discrimination ~8 % of a heavily male audience cannot make; the measured
  -- deuteranopia distance between this widget's warning and critical colours
  -- is 25.6, well inside the ~60 confusion threshold. The option now hides the
  -- INFORMATIONAL chips (NO LINK, STALE, NO DATA, NO SOURCE) and leaves the
  -- two that carry a safety signal alone. In the normal state it never had
  -- anything to hide: stateText returns "" there.
  if show and widget.config.showChip == false then
    local k = stateKey(widget)
    -- LIMIT is the explicit-option refusal contract, not a routine status
    -- decoration. Keep it observable even when quiet state chips are off;
    -- otherwise the exact configuration that needs an explanation becomes
    -- silent again. WARN/CRIT retain their existing safety priority.
    local noticeText = widget.limitNotice
      and (widget.limitNotice.text or "LIMIT")
    show = (k == "warning" or k == "critical" or s == noticeText)
  end
  if show then
    -- the chip hugs its text: measured here because the state string changes
    -- rarely (never per frame), unlike the value
    local L = widget.layout
    local w = T.textWidth(s, L.stateFont) + L.chipPad * 2
    local x = L.stateBox.x
    if L.stateAlign == CENTER then
      x = L.stateBox.x + floor((L.stateBox.w - w) / 2)
    elseif L.stateAlign == RIGHT then
      x = L.stateBox.x + L.stateBox.w - w
    end
    -- The pill HUGS its text, so it can come out wider than the box it was
    -- aligned in - a narrow text column in a horizontal zone is exactly that
    -- case - and the outline then adds chipOutline beyond it on each side.
    -- Measured at 80x56 (LCD_SCALE 0.8): the CRIT outline ended 1 px past the
    -- right edge of the zone. Clamp the pill, outline included, into the zone
    -- so the widget never paints outside itself.
    local edge = L.chipOutline
    local maxW = max(L.w - edge * 2, 1)
    if w > maxW then w = maxW end
    if x + w + edge > L.w then x = L.w - w - edge end
    if x < edge then x = edge end
    setProp(widget, ui.chip, "x", x)
    setProp(widget, ui.chip, "w", w)
    if ui.chipEdge then
      setProp(widget, ui.chipEdge, "x", x - L.chipOutline)
      setProp(widget, ui.chipEdge, "w", w + L.chipOutline * 2)
    end
    -- Centre the text INSIDE the pill it now hugs. The label was placed
    -- against stateBox, and for a RIGHT-aligned state row - the bar's - the
    -- pill's right edge coincides with stateBox's, so the word came out
    -- flush against the pill's right side with the whole 2 * chipPad sitting
    -- on the left. Re-anchoring the label to the PILL makes the padding
    -- symmetric for every alignment; for the dial's CENTER row both are
    -- already concentric, so this changes nothing there.
    if ui.stateLabel then
      setProp(widget, ui.stateLabel, "x", x)
      setProp(widget, ui.stateLabel, "w", w)
      setProp(widget, ui.stateLabel, "align", CENTER)
    end
    -- F8: the pill is a BADGE - the status colour is its GROUND, not its ink.
    --
    -- It used to be a COLOR_THEME_SECONDARY2 fill (a "label/button background"
    -- role) carrying the status colour as text. On the stock theme that is a
    -- #b6e0f2 fill at 1.19:1 against the screen - an invisible pill, read only
    -- through its 1 px outline - with CRIT printed on it at 2.91:1, under the
    -- 3:1 floor. So the most glanceable element in the widget, the one that
    -- says CRIT, was its weakest: a hairline outline around thin coloured text,
    -- seen for ~200 ms in sunlight with the pilot's eyes on the model.
    --
    -- Inverted, the badge is self-grounding and measures 5.2:1 (critical),
    -- 5.6:1 (warning), 5.4:1 (normal) and 6.4:1 (muted), on any theme, because
    -- both the fill and the ink are ours (theme.labelOn).
    local fill = T.stateColor(stateKey(widget), widget.accent, palette)
    local ink = T.labelOn(fill, palette)
    setProp(widget, ui.chip, "color", fill)
    if ui.stateLabel then
      setProp(widget, ui.stateLabel, "color", ink)
    end
    -- The outline takes the badge's OWN ink, not the label role. Under a
    -- SECONDARY2 fill an outline in the label role was the only thing making
    -- the pill visible, so a contrasting chrome colour made sense; over a
    -- coloured fill it reads as a third colour stapled on - a blue hairline
    -- around an amber badge. Ink-coloured, the badge is two colours that
    -- belong together, and the outline still does its remaining job: holding
    -- the shape apart from a theme background at a similar luminance, or from
    -- a background.png photograph.
    if ui.chipEdge then setProp(widget, ui.chipEdge, "color", ink) end
    lvgl.show(ui.chipEdge)
    lvgl.show(ui.chip)
    -- The LABEL travels with the pill. Before F9 this was implicit: the chip
    -- objects only existed when the option was on, so hiding "the chip" hid
    -- everything. Now the objects always exist and only their visibility
    -- moves - and a hidden pill with a visible label left "NO LINK" floating
    -- bare on the dial, which is the very defect the pill was added to fix
    -- (AUDIT.md P1-10, the bar's chipless WARN/CRIT text).
    if ui.stateLabel then lvgl.show(ui.stateLabel) end
    -- frame.chipBox used to be maintained here: the pill's footprint, read by
    -- needleReach() to stop the needle short of it. Both are gone with Tanda 7
    -- A - the pill is opaque and painted after the needle, so it occludes the
    -- blade without anyone having to measure it (see updateArc).
  else
    lvgl.hide(ui.chipEdge)
    lvgl.hide(ui.chip)
    if ui.stateLabel then lvgl.hide(ui.stateLabel) end
  end
  frame.chipShown = show
end

-- The value is CENTRED in a box reserved at the widest sample's width
-- (layout.placeValue, P1-1), so its own ink is always centred on the box
-- regardless of how many digits it actually has - but the unit was placed
-- once, at layout time, against the box's right edge. Re-anchor it to the
-- ink's REAL right edge whenever the text changes: shared by the dial and
-- the bar (bar.lua calls this too) so both keep the visible "value + unit"
-- group centred at any digit count, not just at the widest sample.
-- The live value string is measured through theme.measureWidth - EXACT but
-- deliberately NOT memoized. Measuring it through textWidth would add one
-- permanent entry to the shared width cache per frame at high precision
-- (Tanda 6 F-4).
function M.anchorUnit(widget, str)
  local ui, L = widget.ui, widget.layout
  if not ui.unitLabel then return end
  local actualW = T.measureWidth(str, L.valueFont)
  local inkRight
  if L.valueAlign == LEFT then
    inkRight = L.valueBox.x + actualW
  elseif L.valueAlign == RIGHT then
    inkRight = L.valueBox.x + L.valueBox.w
  else
    inkRight = L.valueBox.x + floor((L.valueBox.w + actualW) / 2)
  end
  -- placeValue resolves the gap once for the active family. Horizontal Dial
  -- uses `sm`; BarPro and every legacy/default path store `md`. The fallback
  -- keeps old serialized/test layouts safe if one reaches this renderer.
  local x = inkRight + (L.unitGap or T.px(T.space.md))
  -- Never anchor the unit outside the zone. In a region too small for the
  -- value+unit group, pickValueFont's last-resort branch clamps the RESERVED
  -- value width below the ink's real width, so ink centred in that box
  -- overhangs to the right and drags the unit with it (measured at 24x24:
  -- the unit label ended 2 px outside the widget). The clamp only ever bites
  -- in that degenerate case - at any size where the group actually fits,
  -- actualW <= valueBox.w and this x is already inside.
  local limit = L.w - L.unitBox.w
  if x > limit then x = limit end
  if x < 0 then x = 0 end
  setProp(widget, ui.unitLabel, "x", x)
end


-- Critical state pulses at ~1 Hz: attention without colour, so it survives
-- greyscale and colour-blind viewing. Two property writes per second.
-- Shared with the bar (Tanda 6 F-15): `obj` is the pulse target - the value
-- arc for the dial, the fill for the bar.
local function pulseOpacity(widget, obj, value)
  if obj and obj[1] then
    for i = 1, #obj do setProp(widget, obj[i], "opacity", value) end
  else
    setProp(widget, obj, "opacity", value)
  end
end

function M.updatePulse(widget, key, obj, mode, baseOpacity, resetPhase)
  local frame = widget.frame
  if key ~= "critical" then
    if frame.pulseActive or frame.pulse then
      -- Restore the opacity the NEW key calls for, not always full: losing
      -- the link while the pulse is in its trough must leave the gauge dim.
      baseOpacity = baseOpacity
        or ((key == "muted") and T.opacity.muted or T.opacity.full)
      pulseOpacity(widget, obj, baseOpacity)
      frame.pulse = false
      frame.pulseActive = false
      frame.pulsePhase = nil
    end
    return
  end
  mode = mode or "essential" -- nil preserves the approved dial behavior
  baseOpacity = baseOpacity or T.opacity.full
  if mode == "off" then
    if frame.pulseActive or frame.pulse then
      pulseOpacity(widget, obj, baseOpacity)
      frame.pulse = false
      frame.pulseActive = false
      frame.pulsePhase = nil
    end
    frame.pulseMode = mode
    return
  end
  local now = getTime()
  if resetPhase or not frame.pulseActive or frame.pulseMode ~= mode then
    frame.pulseAt = now
    frame.pulse = false
    frame.pulseActive = true
    frame.pulsePhase = 0
    frame.pulseMode = mode
    pulseOpacity(widget, obj, baseOpacity)
    return
  end

  if mode == "essential" then
    if now - frame.pulseAt >= 50 then  -- two writes -> one calm 1 Hz cycle
      frame.pulseAt = now
      frame.pulse = not frame.pulse
      pulseOpacity(widget, obj,
                   frame.pulse and T.opacity.pulse or baseOpacity)
    end
    return
  end

  -- Refined/Expressive: the same one-second period, quantized into a calm
  -- full -> mid -> trough -> mid breath. Four writes per second is bounded,
  -- avoids high-frequency shimmer, and is still allocation-free.
  local elapsed = now - frame.pulseAt
  if elapsed >= 100 then
    frame.pulseAt = now - (elapsed % 100)
    elapsed = elapsed % 100
  end
  local phase = floor(elapsed / 25)
  if phase ~= frame.pulsePhase then
    frame.pulsePhase = phase
    frame.pulse = phase ~= 0
    local opacity = baseOpacity
    if phase == 2 then
      opacity = T.opacity.pulse
    elseif phase == 1 or phase == 3 then
      opacity = floor((baseOpacity + T.opacity.pulse) / 2 + 0.5)
    end
    pulseOpacity(widget, obj, opacity)
  end
end

function M.updateSourceLabels(widget)
  local ui = widget.ui
  if ui.unitLabel then
    setProp(widget, ui.unitLabel, "text", widget.unitText or "")
  end
  if ui.nameLabel then
    setProp(widget, ui.nameLabel, "text", widget.nameText or "")
  end
  if ui.scaleMin then
    setProp(widget, ui.scaleMin, "text", F.display(widget, widget.config.min))
    setProp(widget, ui.scaleMax, "text", F.display(widget, widget.config.max))
  end
  -- This runs from app.update(), OUTSIDE the frame's refresh: flush the
  -- queued writes here so a Name/Suffix edit reaches LVGL before the next
  -- refresh (the cheap delta path of AUDIT.md P0-6).
  M.flush(widget)
end


return M
