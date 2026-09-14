---- #########################################################################
---- #                                                                       #
---- # Gauge Core - shared responsive layout primitives                      #
---- #                                                                       #
---- # Classifies the zone (mode + orientation + style), computes dial       #
---- # geometry and typography, and places every text into a REGION with an  #
---- # alignment. The renderer never measures text at runtime: LVGL aligns   #
---- # inside the region (lvgl.label supports align + w), so a changing      #
---- # value cannot shift its neighbours.                                    #
---- #                                                                       #
---- # The value area is sized from the widest string the configured scale   #
---- # can produce, so digits keep their position as the value moves.       #
---- #                                                                       #
---- # All physical sizes go through theme.px() (LCD_SCALE), so a "micro"    #
---- # zone means the same physical size on every radio.                     #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local floor, min, max = math.floor, math.min, math.max

local T  -- theme

function M.setup(theme, _geometry, _format)
  T = theme
end

M.STYLE_AUTO, M.STYLE_NEEDLE, M.STYLE_ARC, M.STYLE_BAR = 1, 2, 3, 4
M.SWEEP_270, M.SWEEP_180, M.SWEEP_360 = 1, 2, 3
M.COLOR_RAIL, M.COLOR_SECTIONS = 3, 5

-- Sweep option -> { startAngle, sweep }. LVGL angles: 0 = 3 o'clock, clockwise.
local SWEEPS = {
  [M.SWEEP_270] = { 135, 270 },
  [M.SWEEP_180] = { 180, 180 },
  [M.SWEEP_360] = { 270, 360 },
}

local function clamp(v, lo, hi)
  return max(lo, min(hi, v))
end

local function box(x, y, w, h)
  return { x = floor(x), y = floor(y), w = floor(w), h = floor(h or 0) }
end

-- Width of the ring's clear interior over the vertical span [yTop, yBottom].
--
-- The chord narrows with distance from the dial centre, so the binding edge is
-- whichever of the two is FARTHER from it. The old code always used the
-- bottom, on the reasoning that "the ring is closest to the text at the bottom
-- of its box" - true only while the box lies entirely below the centre. A
-- micro dial centres its value ON the centre, so its box straddles it and the
-- TOP edge is the far one: at 60x60 the value's top-right corner sat 13.4 px
-- out on a 13 px clear radius while the bottom corners were comfortably
-- inside. Taking the max of the two is the honest rule and costs one
-- comparison.
local function chordAt(L, yTop, yBottom)
  local clearR = L.radius - floor(L.trackThickness / 2)
  local dy = max(math.abs(yTop - L.cy), math.abs(yBottom - L.cy))
  if clearR <= 0 or dy >= clearR then return 0 end
  return 2 * math.sqrt(clearR * clearR - dy * dy)
end

-- Clip a box to that chord, centred on the dial centre, so every corner of
-- the text stays inside the ring (the audit's LABEL/RING collisions: G-6 for
-- the value, G-7 for the min/max row). One px of safety, because a box
-- exactly as wide as the floored chord puts its corners on the ring and
-- rounding can push them a hair outside.
local function clipToChord(L, b)
  if not b then return b end
  local chord = chordAt(L, b.y, b.y + b.h)
  if chord > 0 and chord < b.w then
    b.w = floor(chord) - T.px(1)
    b.x = L.cx - floor(b.w / 2)
  end
  return b
end

-- Stack text rows in the band [top, bottom], sharing whatever slack exists
-- instead of pinning every gap at `xs` and leaving the remainder unused.
--
-- The dial's text block used to be built by chaining `+ T.px(T.space.xs)`
-- between rows, which pins the gap at 2 px whatever the zone. Measured before
-- this: a 260x220 dial had three 2 px gaps AND 15 px of dead space below the
-- name; a 480x272 horizontal zone had 17 px between the value and the min/max
-- row and 85 px between that and the name, because the name was anchored to
-- the bottom of the text column regardless of where the content ended.
--
-- The gap is the slack divided between the rows, clamped to [xs, md] so a
-- tight zone still collapses to the old spacing and a roomy one never drifts
-- into looking disconnected. The block is then CENTRED in its band, so what
-- is left over is split above and below rather than all falling to the bottom.
--
-- Returns nothing; the boxes are mutated in place.
local function stackTextRows(top, bottom, rows, zoneH)
  local n = #rows
  if n == 0 then return end
  local contentH = 0
  for i = 1, n do contentH = contentH + rows[i].h end
  local slack = (bottom - top) - contentH
  local gap = clamp(floor(slack / max(n, 1)),
                    T.px(T.space.xs), T.px(T.space.md))
  local used = contentH + gap * (n - 1)
  local y = top + max(floor(((bottom - top) - used) / 2), 0)
  for i = 1, n do
    local ry = floor(y)
    -- The zone is the hard limit, as everywhere else. This matters because
    -- the stack OVERWRITES positions that were already clamped once - the
    -- value box in a horizontal zone is placed and clamped by placeValue and
    -- then restacked here, so without this a 28x16 zone put the value label
    -- 1 px below its own bottom edge. Rows may end up touching in a zone
    -- this small; painting outside it is the worse outcome.
    if zoneH and ry + rows[i].h > zoneH then
      ry = max(zoneH - rows[i].h, 0)
    end
    rows[i].y = ry
    y = y + rows[i].h + gap
  end
end

-- Pixels the state pill hangs BELOW the state text box, outline included.
--
-- The pill is `extra` px taller than its text and vertically centred on it
-- (chipOff = floor(extra / 2) above), so what hangs below is the half that
-- floor() did NOT take - plus the chipEdge outline the renderers draw around
-- the pill (renderer.build / bar.build).
--
-- `outline` is passed in, not restated, because that is the whole lesson of
-- this function. The budget used to guess the overhang as floor(extra / 2),
-- forgetting the outline entirely, and the pill left the bottom of every bar
-- zone. The first repair hard-coded T.px(1) here - and px() is not linear:
-- at LCD_SCALE 1.375 the renderers' `+ T.px(2)` on the outline box is 3, not
-- 2 * T.px(1) = 2, so the pill went right back outside on 800 px radios.
-- One value, defined once in the layout (L.chipOutline), used by the budget
-- AND by both renderers.
local function chipOverhang(shown, extra, outline)
  if not shown then return 0 end
  return extra - floor(extra / 2) + outline
end

-- mode: micro (<64), compact (<105), normal (<180), large (>=180)
-- orientation: horizontal (>1.4), vertical (<0.8), balanced
function M.classify(w, h)
  local scale = (lvgl and lvgl.LCD_SCALE) or 1
  local side = min(w, h)
  local mode
  if side < 64 * scale then mode = "micro"
  elseif side < 105 * scale then mode = "compact"
  elseif side < 180 * scale then mode = "normal"
  else mode = "large" end
  local ratio = w / h
  local orientation
  if ratio > 1.4 then orientation = "horizontal"
  elseif ratio < 0.8 then orientation = "vertical"
  else orientation = "balanced" end
  return mode, orientation
end

-- A rotary dial needs area; in a long thin zone a linear bar is the honest
-- instrument (GaugeRotary prints "too small" here, which helps nobody).
function M.pickStyle(cfg, w, h, family)
  if family == "dial" then return "dial" end
  if family == "bar" then return "bar" end
  if cfg.style == M.STYLE_BAR then return "bar" end
  if cfg.style == M.STYLE_AUTO and (w / h) > 2.6 then return "bar" end
  return "dial"
end

-- Largest font whose text fits both the width and the height available.
-- `chordCtx` (balanced dials only) = { L = layout, region = valueRegion }.
--
-- Without it the caller pre-clips the region to the chord at the REGION's
-- bottom edge and every font is judged against that one width. That is
-- pessimistic by exactly the difference between the region height and the
-- font height - the region is `dial.h * 0.26` tall, so a 24 px font was being
-- measured against the chord ~11 px lower than the box it would actually
-- occupy, where the ring has closed in. Measured at 200x160: the true chord
-- for MIDSIZE is 74 px and the pair needs 72, but the region-depth chord said
-- 61, so the value fell two ramp steps to STDSIZE - the same 16 px as its own
-- `min 31` caption. That is the mechanism behind Tanda 5 P1-5.
--
-- With it, each candidate is judged against the chord at ITS OWN box bottom.
-- The G-6 guarantee is unchanged - still the chord at the bottom of the box
-- that actually gets drawn, still minus px(1) - it is simply no longer
-- computed for a box nobody uses.
-- Resolve the unit font for one value candidate. With no policy this is the
-- established one-ramp-step behavior used by BarPro and every non-horizontal
-- dial. A policy may instead select the available font closest to a target
-- height ratio, while refusing candidates above a practical maximum and below
-- its legibility floor.
local function pickUnitFont(valueFont, policy)
  if not policy then return T.smallerFont(valueFont, 1) end
  local ramp = T.RAMP
  local valueIndex
  for i = 1, #ramp do
    if ramp[i] == valueFont then valueIndex = i break end
  end
  if not valueIndex then return valueFont end

  local minIndex = #ramp
  if policy.unitMinFont then
    for i = 1, #ramp do
      if ramp[i] == policy.unitMinFont then minIndex = i break end
    end
  end
  -- A policy is never allowed to promote the unit above the value. When the
  -- value already sits at/below the floor, equal size is the only legible
  -- fallback (this cannot occur in the normal/large horizontal caller).
  if minIndex <= valueIndex then return valueFont end

  local valueH = T.fontHeight(valueFont)
  local target = policy.unitTargetRatio or 0.40
  local maxRatio = policy.unitMaxRatio or 0.50
  local best, bestDelta
  for i = valueIndex + 1, minIndex do
    local candidate = ramp[i]
    local ratio = T.fontHeight(candidate) / valueH
    if ratio <= maxRatio then
      local delta = math.abs(ratio - target)
      -- Strictly-less keeps the first candidate on a tie: the minimum number
      -- of ramp steps that satisfies the same visual target.
      if not bestDelta or delta < bestDelta then
        best, bestDelta = candidate, delta
      end
    end
  end
  return best or ramp[minIndex] or valueFont
end

local function valueUnitGap(policy)
  return (policy and policy.unitGap) or T.px(T.space.md)
end

local function pickValueFont(sample, unitText, maxW, maxH, cap, chordCtx,
                             policy)
  local ramp = T.RAMP
  local gap = valueUnitGap(policy)
  local heightLimit = maxH
  if policy and policy.valueMaxHeight then
    heightLimit = min(heightLimit, policy.valueMaxHeight)
  end
  local started = (cap == nil)
  for i = 1, #ramp do
    local font = ramp[i]
    if not started and font == cap then started = true end
    if started then
      local fh = T.fontHeight(font)
      if fh <= heightLimit then
        local avail = maxW
        if chordCtx then
          local r = chordCtx.region
          local y0 = chordCtx.topAlign and r.y
            or (r.y + max(floor((r.h - fh) / 2), 0))
          local c = floor(chordAt(chordCtx.L, y0, y0 + fh)) - T.px(1)
          if c < avail then avail = c end
        end
        -- The default unit is one ramp step below the value (review P-D): two
        -- steps shrank the `B` of `dB` to where it blurred into an `E` at
        -- small sizes. A caller-supplied policy may choose a ratio-based font;
        -- the same width fit below remains the final arbiter in both cases.
        local unitFont = pickUnitFont(font, policy)
        local w = T.textWidth(sample, font)
        local uw = 0
        if unitText and unitText ~= "" then
          uw = T.textWidth(unitText, unitFont) + gap
        end
        if avail > 0 and w + uw <= avail then
          return font, unitFont, w, uw, avail
        end
      end
    end
  end
  -- Nothing fits the region: use the smallest font, but never let the
  -- reserved box exceed the region. The region was chord-clipped to stay
  -- inside the ring (AUDIT.md G-6), so an oversized box - possible once the
  -- sample carries a slack character (P1-3/P1-4) - would push its corners
  -- onto the ring. The value itself is always narrower than the sample.
  local font = ramp[#ramp]
  local unitFont = pickUnitFont(font, policy)
  local uw = 0
  if unitText and unitText ~= "" then
    uw = T.textWidth(unitText, unitFont) + gap
  end
  -- The last-resort width must respect the chord too, or the fallback box -
  -- the one case where the reserve CAN exceed what fits - lands on the ring.
  local limit = maxW
  if chordCtx then
    local r = chordCtx.region
    local fh = T.fontHeight(font)
    local y0 = chordCtx.topAlign and r.y
      or (r.y + max(floor((r.h - fh) / 2), 0))
    limit = min(limit, max(floor(chordAt(chordCtx.L, y0, y0 + fh)) - T.px(1), 0))
  end
  local w = min(T.textWidth(sample, font), max(limit - uw, 0))
  return font, unitFont, w, uw, limit
end

-- Place the value + unit pair centred as a group inside `region`.
-- `chordCtx` is forwarded to pickValueFont; when present the group is centred
-- on the DIAL centre rather than on the region, because the width it was
-- fitted against is the ring's chord (symmetric about L.cx), not the region.
local function placeValue(L, region, sample, unitText, cap, chordCtx, policy)
  local valueFont, unitFont, vw, uw, avail =
    pickValueFont(sample, unitText, region.w, region.h, cap, chordCtx, policy)
  L.valueFont = valueFont
  L.unitFont = unitFont
  local vh = T.fontHeight(valueFont)
  local uh = T.fontHeight(unitFont)
  local gap = valueUnitGap(policy)
  -- Shared with ui_core.anchorUnit: the reserved box and every live re-anchor
  -- must read one resolved gap or the unit jumps after the first refresh.
  L.unitGap = gap
  local groupW = vw + uw
  -- A trailing unit adds visual weight on the right of the group, so centre
  -- it ~1 px left of the geometric centre when a unit is shown (review
  -- P1-8). Only when there is room: never let the box leave the region, so
  -- the G-6 chord guarantee holds.
  -- The width the group was actually fitted against: the chord at the chosen
  -- font's own box bottom when chordCtx is in play, the region otherwise.
  local fitW = avail or region.w
  local optical = 0
  if unitText ~= "" and groupW + T.px(1) <= fitW then
    optical = T.px(1)
  end
  local x0
  if chordCtx then
    -- the chord is symmetric about the dial centre, so centre the group there
    x0 = L.cx - floor((groupW + optical) / 2)
  else
    x0 = region.x + floor((region.w - groupW - optical) / 2)
  end
  -- topAlign: the region's TOP is the P0-2 hub guarantee, and it is also
  -- where the chord is widest, so the value sits there rather than floating
  -- in the middle of a region sized for the largest candidate.
  local y0 = (chordCtx and chordCtx.topAlign) and region.y
    or (region.y + floor((region.h - vh) / 2))
  if y0 < region.y then y0 = region.y end
  -- The type ramp has a FLOOR (theme.RAMP's smallest font), so a region
  -- shorter than that font still gets a box taller than itself - and in a
  -- micro dial the region is already the zone's last few pixels, so the box
  -- hung off the bottom edge of the widget (measured at 24x20, LCD_SCALE
  -- 1.375: the value label ended 1 px outside). The region is the
  -- preference; the zone is the hard limit. Only ever bites where the font
  -- could not shrink far enough, so every zone with room is untouched.
  if y0 + vh > L.h then y0 = max(L.h - vh, 0) end
  if x0 < 0 then x0 = 0 end
  L.valueBox = box(x0, y0, vw, vh)
  -- P1-1 (Tanda 5 review 3.4): the box is reserved at the widest sample's
  -- width so digits never shift the group, but RIGHT-aligning the actual
  -- ink inside it flushed short values against the unit, leaving the empty
  -- reserve entirely on the left - the visible "22 dB" sat well right of
  -- the dial's centre even though the RESERVED group was centred there.
  -- Centring the ink instead, with the unit re-anchored to its real edge
  -- every time the value text changes (renderer.anchorUnit/bar.lua), keeps
  -- the VISIBLE group centred on the same point for any digit count: with
  -- the ink centred in a box of width vw, its own centre is always at
  -- vw/2 regardless of actualW, so attaching the unit right after the ink
  -- reproduces exactly the reserved group's centre, not an approximation.
  L.valueAlign = CENTER
  -- unit sits on the value baseline, one step down in the type ramp. `uw`
  -- from pickValueFont already includes the gap, so the box must not add it
  -- again: the reserved group is then exactly `groupW` and the fit check in
  -- pickValueFont (w + uw <= maxW) is honest (AUDIT.md G-6).
  L.unitBox = box(x0 + vw + gap, y0 + (vh - uh) - T.px(1), max(uw - gap, 1), uh)
  L.unitAlign = LEFT
end


-- Family layouts consume these primitives; presentation geometry stays out
-- of this common module while typography and containment remain one source.
M.SWEEPS = SWEEPS
M.clamp = clamp
M.box = box
M.chordAt = chordAt
M.clipToChord = clipToChord
M.stackTextRows = stackTextRows
M.chipOverhang = chipOverhang
M.pickValueFont = pickValueFont
M.placeValue = placeValue

-- Structural signature: a change here means the object tree must be rebuilt.
-- Anything that only moves or recolours an existing object stays out of it.
function M.signature(L, cfg)
  return table.concat({
    L.style, L.mode, L.orientation,
    L.showNeedle and 1 or 0, L.showUnit and 1 or 0, L.showName and 1 or 0,
    (L.showValue == false) and 0 or 1,
    L.showState and 1 or 0, L.showMarkers and 1 or 0,
    L.showMinMaxText and 1 or 0, L.showScale and 1 or 0,
    cfg.colorMode, (L.style == "bar") and 0 or (cfg.sweep or 1),
    L.valueFont, L.radius or 0,
    L.w, L.h,
    -- ShowChip no longer moves anything (F9 reserves the row either way), so
    -- it does not belong here structurally - but the badge's VISIBILITY is
    -- decided in updateChip, which only runs when the state STRING changes.
    -- Without this, toggling the option while a NO LINK badge was on screen
    -- left it there until the link state next moved.
    (cfg.showChip == false) and 0 or 1,
  }, ":")
end

return M
