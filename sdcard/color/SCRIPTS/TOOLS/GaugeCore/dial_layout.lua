---- Gauge Core - dial-only responsive layout -----------------------------

local M = {}
local floor, min, max = math.floor, math.min, math.max
local C, T, G, F, SWEEPS
local clamp, box, clipToChord, stackTextRows, placeValue

function M.setup(common, theme, geometry, format)
  C, T, G, F = common, theme, geometry, format
  SWEEPS = C.SWEEPS
  clamp, box = C.clamp, C.box
  clipToChord, stackTextRows = C.clipToChord, C.stackTextRows
  placeValue = C.placeValue
end

-- ------------------------------------------------------------------ dial --

local function dialLayout(widget, cfg, L, w, h)
  local mode, orientation = L.mode, L.orientation
  -- Phase 1's instrument composition is deliberately narrow in scope. The
  -- compact horizontal family and every balanced/vertical family retain their
  -- established geometry; only a horizontal face with room for both title
  -- and value gets the explicit header/main/footer structure.
  local horizontalInstrument = orientation == "horizontal"
    and (mode == "normal" or mode == "large")
  L.horizontalInstrument = horizontalInstrument
  -- A 60x60 micro dial has no name, unit, state chip, history, or needle.
  -- Keeping the normal six-pixel frame around that already-minimal face made
  -- its safe inner chord narrower than "16.62" at the smallest EdgeTX font.
  -- Let containment own the real one-pixel edge limit instead; larger faces
  -- retain their normal breathing room.
  local pad = (mode == "micro") and 0 or T.px(T.space.md)
  local sweep = SWEEPS[cfg.sweep or C.SWEEP_270] or SWEEPS[C.SWEEP_270]
  L.startAngle, L.sweep = sweep[1], sweep[2]
  local side = min(w, h)

  L.showUnit = mode ~= "micro"
  L.showName = (mode == "normal" or mode == "large")
  -- ShowChip (owner request, Tanda 5): the no-data pill is opt-out, not
  -- mandatory. The ROW is reserved either way (Tanda 8 F9): `Off` now hides
  -- only the informational chips and never WARN or CRIT, so the space has to
  -- exist whatever the option says, or a warning badge would land on top of
  -- the name. What the option costs is one text row in the layouts that stack
  -- it - horizontal zones and the bar; on the square and vertical dials the
  -- badge rides ON the dial and was never part of the budget.
  L.showState = mode ~= "micro"
  L.showMarkers = (cfg.showMinMax or 1) > 1 and mode ~= "micro"
  -- No `mode == "large"` gate. That gate wanted a short side of 180 * LCD_SCALE
  -- (~300 px on an 800x480 radio), which the most common half-screen zone -
  -- 400x240 - never reaches, so the third choice of a published option did
  -- nothing on the layouts people actually use. Fit is decided lower down by
  -- minMaxTextFits() against the real captions, which is the honest test and
  -- already degrades to the marks when the cells are too narrow.
  L.showMinMaxText = (cfg.showMinMax or 1) > 2 and mode ~= "micro"
  -- a full ring starts and ends at the same point: two scale labels would sit
  -- on top of each other
  -- A 400x160 face classifies as normal, although its dedicated dial half has
  -- enough room for both endpoint labels. Treat large as an unconditional
  -- candidate and the new horizontal instrument as a fit-tested candidate;
  -- the final geometry below can still reject both labels as one unit.
  L.showScale = (mode == "large" or horizontalInstrument) and (L.sweep < 360)
  L.showGhost = (mode ~= "micro")

  -- The name is the least important text on the dial: the smallest font keeps
  -- the hierarchy value -> unit -> name clean (review P2-10). The state text
  -- stays one step larger because WARN/CRIT carry the severity.
  L.nameFont = T.FONTS.XXS
  L.stateFont = T.FONTS.XS
  L.minMaxFont = T.FONTS.XXS
  L.scaleFont = T.FONTS.XXS
  local nameH = T.fontHeight(L.nameFont)
  local stateH = T.fontHeight(L.stateFont)
  local minMaxH = T.fontHeight(L.minMaxFont)

  -- The badge's complete footprint belongs to layout, including its outline.
  -- Computing it before the horizontal bands means the header reserves the
  -- exact same geometry that dial_renderer and ui_core later paint.
  L.chipPad = T.px(7)
  L.chipHeight = stateH + T.px(6)
  L.chipOff = floor((L.chipHeight - stateH) / 2)
  L.chipOutline = T.px(1)

  -- "Markers + text" is a preference, not permission to wrap telemetry
  -- captions. Evaluate it before carving a footer so a failed fit gives every
  -- pixel back to the value instead of leaving a blank reserved band.
  local minCaption = "min " .. F.display(widget, cfg.min)
  local maxCaption = "max " .. F.display(widget, cfg.max)
  local minMaxCellNeed = max(T.textWidth(minCaption, L.minMaxFont),
                             T.textWidth(maxCaption, L.minMaxFont))
  local function minMaxTextFits(b)
    return floor(b.w / 2) >= minMaxCellNeed
  end

  -- dial box and text region per orientation
  local dial, textRegion, valueRegion
  if orientation == "horizontal" then
    -- The dial takes the full zone HEIGHT and the text column keeps only the
    -- width it needs. `min(w*0.5, h)` strangled the dial to half the zone
    -- even when there was height to spare, wasting up to ~73 % of the area
    -- (AUDIT.md G-13: 480x272 used 27 %). The column floor - the value at its
    -- smallest font plus the longest label row - keeps the text legible, and
    -- the max() with the old half-width rule means a narrow horizontal zone
    -- never loses dial size.
    local textMin = max(T.px(120), floor(w * 0.28))
    local dialSide = max(min(w - textMin, h), min(w * 0.5, h))
    dial = box(pad, pad, dialSide - pad * 2, h - pad * 2)
    local tx = dial.x + dial.w + T.px(T.space.md)
    textRegion = box(tx, pad, w - tx - pad, h - pad * 2)
    if horizontalInstrument then
      if L.showMinMaxText and not minMaxTextFits(textRegion) then
        L.showMinMaxText = false
      end
      local headerH = max(L.showName and nameH or 0,
                          L.showState
                            and (L.chipHeight + L.chipOutline * 2) or 0)
      local footerH = L.showMinMaxText and minMaxH or 0
      local gap = T.px(T.space.sm)
      L.headerBox = box(textRegion.x, textRegion.y, textRegion.w, headerH)
      L.footerBox = box(textRegion.x,
        textRegion.y + textRegion.h - footerH, textRegion.w, footerH)
      local mainY = textRegion.y + headerH
        + ((headerH > 0) and gap or 0)
      local mainBottom = L.footerBox.y
        - ((footerH > 0) and gap or 0)
      L.mainBox = box(textRegion.x, mainY, textRegion.w,
                      max(mainBottom - mainY, T.px(12)))
      valueRegion = L.mainBox
    else
      local rows = (L.showName and nameH or 0) + (L.showState and stateH or 0)
        + (L.showMinMaxText and minMaxH or 0)
      valueRegion = box(textRegion.x, textRegion.y,
                        textRegion.w, max(textRegion.h - rows, T.px(12)))
    end
  elseif orientation == "vertical" then
    local dialSide = min(w, h * 0.62)
    dial = box(floor((w - dialSide) / 2) + pad, pad,
               dialSide - pad * 2, dialSide - pad * 2)
    local ty = dial.y + dial.h + T.px(T.space.sm)
    textRegion = box(pad, ty, w - pad * 2, h - ty - pad)
    -- C6 (Tanda 7): `mode` is classified on min(w, h), so a very TALL zone is
    -- judged by its NARROW axis - a 100x260 widget came out "compact" and
    -- dropped its source name on 260 px of height. Mode still governs
    -- everything else (tick count, fonts, scale labels, markers); the name
    -- only needs somewhere to sit, and in a vertical zone that is measurable
    -- directly. Promoting the whole mode instead would drag six other
    -- decisions along with it for the sake of one label.
    if not L.showName then
      local smallest = T.fontHeight(T.RAMP[#T.RAMP])
      L.showName = (textRegion.h - nameH - T.px(T.space.sm)) >= smallest
    end
    local rows = (L.showName and nameH or 0) + (L.showMinMaxText and minMaxH or 0)
    valueRegion = box(textRegion.x, textRegion.y,
                      textRegion.w, max(textRegion.h - rows, T.px(12)))
  else
    local nameSpace = L.showName and (nameH + T.px(T.space.xs)) or 0
    local d = min(w, h - nameSpace)
    dial = box(floor((w - d) / 2) + pad, pad, d - pad * 2, d - pad * 2)
    textRegion = dial
    -- value lives inside the dial circle. A micro dial draws no state chip
    -- and no needle, so its value can sit in the MIDDLE of the circle, where
    -- the clear chord is widest; larger modes must clear the state chip.
    -- P0-2: the normal/large value region is dropped `valueDrop` px so the
    -- text cell clears the pivot and the needle blade at critical angles
    -- (measured: the cell used to start 6 px inside the pivot's vertical
    -- span at 200x160). The min/max row below is chord-clipped further down,
    -- and the region's own chord clip keeps the fit honest.
    -- Tanda 7 B (closing Tanda 5 P1-5, which stayed 🟡 pending this decision).
    -- valueDrop was px(7). It buys clearance from the pivot and the blade,
    -- and it costs CHORD - and the chord is what picks the value font, so the
    -- gauge's headline number was paying for it: 16 px on a 200x160 dial, the
    -- same size as its own `min 31` caption, which flattens the hierarchy the
    -- type ramp exists to express.
    --
    -- Tanda 7 A settled what the clearance is actually worth: the labels are
    -- created AFTER the needle (renderer.build) and paint over it, so the
    -- needle passing behind the digits was never a correctness problem - and
    -- the owner accepted that look explicitly (Tanda 5 review 3.13 / P2-5).
    -- What must stay clear is the PIVOT, a solid disc the digits would sit on
    -- top of; px(3) still clears it, and the value cell's own chord clip keeps
    -- the fit honest either way.
    local valueDrop = T.px(3)
    if mode == "micro" then
      -- centred exactly on the dial centre: the clear chord is widest there,
      -- and a micro dial's value is only a few px wide (no unit, no state)
      valueRegion = box(dial.x, dial.y + floor(dial.h / 2)
                        - floor(dial.h * 0.15),
                        dial.w, floor(dial.h * 0.30))
    elseif mode == "compact" then
      valueRegion = box(dial.x, dial.y + floor(dial.h * 0.50),
                        dial.w, floor(dial.h * 0.26))
    else
      valueRegion = box(dial.x, dial.y + floor(dial.h * 0.45) + valueDrop,
                        dial.w, floor(dial.h * 0.26))
    end
  end

  -- Exposed structural boxes are inexpensive layout data and make the visual
  -- contract directly testable without inferring it from retained objects.
  L.dialBox, L.textRegion = dial, textRegion

  L.cx = dial.x + floor(dial.w / 2)
  L.cy = dial.y + floor(dial.h / 2)

  -- Resolve the presentation before the radial metrics: Needle uses a thin
  -- active arc as a secondary position cue, while Arc keeps the full track
  -- weight because it has no blade. Auto is Needle outside the micro family.
  L.showNeedle = (cfg.style == C.STYLE_NEEDLE)
    or (cfg.style == C.STYLE_AUTO and mode ~= "micro")

  -- Ring metrics depend on the zone, not on the radius, so they are computed
  -- first; the radius is then whatever is left after reserving room for
  -- everything drawn OUTSIDE the track (rail, gap, ticks). Deriving the
  -- radius from the box alone pushes the ticks past the zone edge.
  L.trackThickness = clamp(floor(side * T.ratio.trackToRadius / 2),
                           T.px(3), T.px(12))
  L.arcThickness = L.showNeedle
    and clamp(floor(L.trackThickness * T.ratio.needleArcToTrack + 0.5),
              T.px(2), L.trackThickness)
    or L.trackThickness
  L.railThickness = max(T.px(2), floor(L.trackThickness * T.ratio.railToTrack))
  L.ghostThickness = max(T.px(2), floor(L.trackThickness * 0.45))
  L.tickCount = (mode == "micro") and 3 or ((mode == "large") and 7 or 5)
  -- Minimum 2 px: at 1 px the scale marks vanished into the background on
  -- dark themes (~2.5:1 contrast, review P-C). Micro ticks stay at exactly
  -- two pixels: px(2) becomes three on the 800-class scale, whose half-stroke
  -- crossed a 60 px stress zone even while its endpoints remained inside.
  local minTick = (mode == "micro") and 2 or T.px(2)
  L.tickThickness = clamp(floor(side / 90), minTick, T.px(3))
  L.minorTicks = (mode == "large") and (L.tickCount - 1) or 0

  local tickLength = clamp(floor(side / 40), T.px(2), T.px(6))
  -- The micro face needs every radial pixel.  One pixel still separates its
  -- three ticks from the rail and leaves their endpoints inside the zone;
  -- larger faces keep the full xs rhythm.
  local tickGap = (mode == "micro") and T.px(1) or T.px(T.space.xs)
  -- Only Rail and Sections actually paint a reference band outside the track.
  -- Reserving that band in Static, Threshold and Gradient left a visibly empty
  -- annulus between the dial and its scale ticks (INFORME-DEFECTOS.md W-01).
  -- Keep this fact here, before every radial budget is derived, so the dial
  -- grows into the released room instead of merely moving the ticks outward.
  L.hasReferenceBand = cfg.colorMode == C.COLOR_RAIL
    or cfg.colorMode == C.COLOR_SECTIONS
  L.railGap = T.px(1)
  local referenceBandReserve = L.hasReferenceBand
    and (L.railThickness + L.railGap) or 0
  local outerReserve = floor(L.trackThickness / 2) + referenceBandReserve
    + tickGap + tickLength + 1
  local half = floor(min(dial.w, dial.h) / 2)
  L.radius = max(half - outerReserve, T.px(8))
  -- The rail band radius clears the value arc's outer edge by `railGap`: when
  -- the value is critical both layers are red at adjacent radii, and touching
  -- them read as one bevelled blob (review P-E). The 1 px band gap keeps the
  -- red->amber transition a clean range boundary.
  -- CONTAINMENT. `radius` above has a px(8) FLOOR, so in a zone smaller than
  -- the ring's own outer furniture the subtraction goes negative, the floor
  -- wins, and everything derived from the radius is then pushed OUTSIDE the
  -- zone - the ticks first, since they are the outermost thing on the dial.
  --
  -- That is not a cosmetic overflow. Ticks and history marks are LINES, and
  -- LvglWidgetLine::getPt reads their coordinates with luaL_checkunsigned
  -- (lua_lvgl_widget.cpp:1001,1004): a negative one RAISES on the radio, so
  -- the widget dies on its first build and disables itself for the session -
  -- the coordinate-validation harness exists to catch. Measured
  -- before this clamp: every zone below ~32x32 at LCD_SCALE 1.0 (46x46 at
  -- 1.375) built negative tick coordinates.
  --
  -- So give up the outer FURNITURE rather than the widget, in ascending order
  -- of importance: the ticks first (a 30 px dial cannot resolve them anyway),
  -- then the ring shrinks onto whatever is left. `edgeReach` is the clearance
  -- from the dial centre to the nearest zone edge - the real budget, which
  -- the dial BOX alone does not capture once the box has been centred.
  local edgeReach = min(L.cx, L.cy, w - L.cx, h - L.cy) - 1
  local railOut = floor(L.trackThickness / 2) + referenceBandReserve
  if L.radius + railOut + tickGap + tickLength > edgeReach then
    local r = edgeReach - railOut - tickGap - tickLength
    if r >= T.px(8) then
      L.radius = r                       -- ticks still fit: just shrink
    else
      L.tickCount, L.minorTicks, tickLength = 0, 0, 0
      L.radius = max(edgeReach - railOut - T.px(1), T.px(3))
    end
  end

  L.railRadius = L.radius + floor(L.trackThickness / 2)
    + referenceBandReserve
  L.tickInner = L.railRadius + tickGap
  L.tickOuter = L.tickInner + tickLength
  -- Threshold is an exact boundary, not another scale tick. Its radial line
  -- spans the complete neutral track, then adds a bounded 1..2 px lip towards
  -- the ticks. Thickness is always at least one physical step above a normal
  -- tick and remains capped by the LCD-scaled stroke budget.
  L.thresholdLip = clamp(
    floor(L.trackThickness * T.ratio.thresholdLipToTrack + 0.5),
    T.px(1), T.px(2))
  L.thresholdInner = max(L.radius - floor(L.trackThickness / 2), 0)
  L.thresholdOuter = min(
    L.radius + floor((L.trackThickness + 1) / 2) + L.thresholdLip,
    L.tickInner, max(edgeReach, 0))
  L.thresholdOuter = max(L.thresholdOuter, L.thresholdInner)
  L.thresholdThickness = clamp(L.tickThickness + T.px(1),
                               T.px(2), T.px(4))
  -- Radial span of the min/max history marks. LAYOUT data, like the bar's
  -- markOverhang: renderer.build and renderer.updateHistory both need it and
  -- used to compute the same two expressions independently - the exact shape
  -- of drift that put the state pill outside its zone.
  -- Both ends are clamped for the same luaL_checkunsigned reason as above:
  -- `edgeReach` caps the outer end in the degenerate zones the branch above
  -- lands in, and 0 caps the inner one, which goes negative once the ring is
  -- thicker than the radius it was squeezed onto.
  L.markInner = max(L.radius - floor(L.trackThickness / 2) - T.px(1), 0)
  L.markOuter = min(L.railRadius + T.px(1), max(edgeReach, 0))

  -- In a balanced zone the value text hangs inside the dial circle, and the
  -- circle's clear interior at that height is a CHORD of the ring - narrower
  -- than the dial box. Centering the value+unit group against the full box
  -- width pushes the unit (and wide values) onto the ring, exactly the
  -- LABEL/RING collisions the audit measured (AUDIT.md G-6). Horizontal/
  -- vertical zones place the value outside the dial and do not need it.
  --
  -- The region itself is NO LONGER pre-clipped: placeValue now measures the
  -- chord per candidate font, at the bottom of the box that font would really
  -- occupy (see pickValueFont). Pre-clipping here would re-impose the
  -- region-depth chord as a ceiling and undo exactly that (Tanda 7 B).
  local chordCtx = (orientation == "balanced")
    and { L = L, region = valueRegion } or nil

  -- needle
  if L.showNeedle then
    L.pivotRadius = clamp(floor(L.radius * T.ratio.pivotRadius),
                          T.px(3), T.px(9))
    -- The blade has to START inside the hub. It used to begin at 0.16 * radius
    -- while the hub ended at 0.09 * radius (T.ratio.pivotRadius), so a gap of
    -- 0.07 * radius - 4 px on a 200x160 zone - always separated the needle
    -- from its own pivot and the needle read as floating. Overlapping by one
    -- pixel is what makes the two look like one object at every size; the hub
    -- is drawn after the blade, so the overlap is never visible as a seam.
    L.needleInner = min(clamp(floor(L.radius * 0.16), T.px(3), T.px(20)),
                        max(0, L.pivotRadius - 1))
    L.needleOuter = L.radius - floor(L.trackThickness / 2) - T.px(1)
    L.needleHalf = clamp(floor(L.radius * T.ratio.needleWidth), T.px(2), T.px(7))
    -- Tapered blade from three LINES (P2-1 keeps the needle a line family):
    -- base -> mid -> tip, each a bit thinner than the last, so the width
    -- steps down gradually instead of jumping straight from the thick base
    -- to the 2 px tip in one cut (Tanda 4's two-part P-A read as a paddle
    -- with a toothpick glued on at anything above micro sizes; owner
    -- request, Tanda 5). Each segment overlaps the previous by 75% of its
    -- OWN thickness so the rounded caps (renderer.buildNeedle) blend into
    -- one another instead of leaving a visible seam.
    local reach = L.needleOuter - L.needleInner
    L.needleBodyOuter = L.needleInner + floor(reach * T.ratio.needleBodyReach)
    L.needleMidOuter = L.needleInner + floor(reach * T.ratio.needleMidReach)
    L.needleMidHalf = clamp(floor(L.needleHalf * T.ratio.needleMidToHalf),
                            1, L.needleHalf)
    L.needleTipHalf = clamp(floor(L.needleHalf * T.ratio.needleTipToHalf),
                            1, L.needleMidHalf)
    L.needleTipThickness = max(T.px(2), L.needleTipHalf * 2)
    L.needleMidInner = max(L.needleInner,
                           L.needleBodyOuter - floor(L.needleMidHalf * 2 * 0.75))
    L.needleTipInner = max(L.needleMidInner,
                           L.needleMidOuter - floor(L.needleTipThickness * 0.75))
  end

  -- typography and text regions
  local cap = (mode == "micro") and T.FONTS.XS
    or ((mode == "compact") and T.FONTS.L or nil)
  -- a unit that will not be drawn (micro zones) must not reserve width in the
  -- value group: the chord a micro dial leaves for text is only a few px
  -- (AUDIT.md G-6)
  -- P0-2, re-expressed against the thing it actually protects. Runs HERE,
  -- after the needle block, because L.pivotRadius does not exist before it.
  --
  -- `valueDrop` was a fixed px(7) nudge chosen to push the value cell clear of
  -- the pivot hub and the blade. A fixed nudge cannot hold that guarantee once
  -- the type can grow: the box is centred in its region, so a taller font
  -- raises its own top edge and walks straight back onto the hub (measured at
  -- 200x160 with the value at MIDSIZE: cell top 74, hub spanning 69..77).
  --
  -- The hub is a real, measurable disc, so clear THAT explicitly and let the
  -- chord hand back whatever room is left. Top-aligning the value in the
  -- region rather than centring it then puts the cell as high as the
  -- guarantee allows, which is also where the chord is widest - the value
  -- gets the largest font that genuinely fits without ever touching the hub.
  -- Change A settled the other half of the old clearance: the labels are
  -- created after the needle and paint over it, so the BLADE passing behind
  -- the digits is by design (owner, Tanda 5 review 3.13 / P2-5).
  if chordCtx and L.pivotRadius and mode ~= "micro" then
    local hubBottom = L.cy + L.pivotRadius + T.px(2)
    if valueRegion.y < hubBottom then
      -- Move the region DOWN without shrinking it. Trimming the height to
      -- keep the bottom edge fixed looks tidy and is wrong: `region.h` is the
      -- height budget the font ramp is checked against, so a region trimmed
      -- by 20 px rejected every candidate taller than what was left - a
      -- 300x272 dial dropped two whole ramp steps (48 px to 32 px) with the
      -- room still sitting unused below it. The box is top-aligned here, so
      -- the height is a budget, not an extent: the CHORD is what actually
      -- limits the font, and stackTextRows takes whatever is left below.
      valueRegion.y = hubBottom
    end
    chordCtx.topAlign = true
  end

  local valuePolicy
  if horizontalInstrument then
    -- Phase 2 hierarchy for the explicit information column. The value stays
    -- within the 35..45% reference band whenever the discrete EdgeTX ramp can
    -- provide it; the unit then chooses the legible font closest to 40%, never
    -- above 50%, and uses the tighter `sm` relationship. No other family
    -- receives this table, so placeValue's established defaults remain exact.
    valuePolicy = {
      valueMaxHeight = floor(h * 0.45),
      unitTargetRatio = 0.40,
      unitMaxRatio = 0.50,
      unitMinFont = T.FONTS.XS,
      unitGap = T.px(T.space.sm),
    }
  end
  placeValue(L, valueRegion, F.widestSample(widget),
             L.showUnit and widget.unitText or "", cap, chordCtx, valuePolicy)

  -- Rows BELOW the value, in paint order top to bottom. They are placed with
  -- provisional geometry here and then stacked by stackTextRows, which owns
  -- the vertical rhythm (Tanda 7 B); only the x/w/h of each box matter above.
  local align = (orientation == "horizontal") and LEFT or CENTER
  local stackTop, stackBottom, stackRows
  if orientation == "horizontal" then
    if horizontalInstrument then
      -- One header, two owners. Reserve the longest informational badge rather
      -- than today's state, so NORMAL -> WARN/CRIT/NO SOURCE never changes the
      -- layout or walks the value vertically. The outline is kept inside the
      -- header's right edge and the title receives the remaining width.
      local stateReserve = min(textRegion.w,
        T.textWidth("NO SOURCE", L.stateFont) + L.chipPad * 2)
      local headerGap = T.px(T.space.sm)
      local stateRight = L.headerBox.x + L.headerBox.w - L.chipOutline
      local stateX = stateRight - stateReserve
      local nameW = max(stateX - headerGap - L.headerBox.x, 1)
      local nameY = L.headerBox.y
        + floor((L.headerBox.h - nameH) / 2)
      local stateY = L.headerBox.y
        + floor((L.headerBox.h - stateH) / 2)
      L.nameBox = box(L.headerBox.x, nameY, nameW, nameH)
      L.stateBox = box(stateX, stateY, stateReserve, stateH)
      L.minMaxBox = box(L.footerBox.x, L.footerBox.y,
                        L.footerBox.w, minMaxH)
      -- placeValue already centred the stable value+unit group in mainBox.
      -- There is nothing left to distribute: title/state and history have
      -- explicit bands and NORMAL simply hides its retained badge objects.
      stackRows = {}
      stackTop, stackBottom = 0, 0
    else
      L.stateBox = box(textRegion.x, 0, textRegion.w, stateH)
      L.minMaxBox = box(textRegion.x, 0, textRegion.w, minMaxH)
      L.nameBox = box(textRegion.x, 0, textRegion.w, nameH)
      if L.showMinMaxText and not minMaxTextFits(L.minMaxBox) then
        L.showMinMaxText = false
      end
      -- Compact horizontal faces retain the established distributed stack.
      stackRows = { L.valueBox }
      if L.showState then stackRows[#stackRows + 1] = L.stateBox end
      if L.showMinMaxText then stackRows[#stackRows + 1] = L.minMaxBox end
      if L.showName then stackRows[#stackRows + 1] = L.nameBox end
      stackTop = textRegion.y
      stackBottom = textRegion.y + textRegion.h
    end
  elseif orientation == "vertical" then
    L.minMaxBox = box(textRegion.x, 0, textRegion.w, minMaxH)
    L.nameBox = box(textRegion.x, 0, textRegion.w, nameH)
    if L.showMinMaxText and not minMaxTextFits(L.minMaxBox) then
      L.showMinMaxText = false
    end
    -- the state chip rides on the dial, not in the text column
    L.stateBox = box(dial.x, dial.y + floor(dial.h * 0.24), dial.w, stateH)
    stackRows = {}
    if L.showMinMaxText then stackRows[#stackRows + 1] = L.minMaxBox end
    if L.showName then stackRows[#stackRows + 1] = L.nameBox end
    stackTop = L.valueBox.y + L.valueBox.h
    stackBottom = textRegion.y + textRegion.h
  else
    L.stateBox = box(dial.x, dial.y + floor(dial.h * 0.26), dial.w, stateH)
    stackTop = L.valueBox.y + L.valueBox.h
    -- The min/max row stays TIGHT under the value, and is deliberately NOT
    -- part of the distributed stack. It lives INSIDE the ring, where the
    -- clear chord narrows with every pixel of descent (clipToChord below), so
    -- "breathing room" here is bought with width: distributing it pushed the
    -- row into a 26 px chord where "min 31" needs 36 and wrapped it to two
    -- lines, of which one is visible. Above it the chord is widest, so tight
    -- is also correct here - the slack belongs to the name instead.
    L.minMaxBox = box(dial.x, stackTop + T.px(T.space.xs), dial.w, minMaxH)
    if L.showMinMaxText then
      clipToChord(L, L.minMaxBox)
      if not minMaxTextFits(L.minMaxBox) then
        L.showMinMaxText = false
      end
    end
    if L.sweep >= 360 then
      -- A CLOSED ring has no open wedge to hang the name in, so it goes
      -- INSIDE. It used to be pinned tight under the value - 2 px below it,
      -- with 18 px of the ring's interior left empty underneath (F3). The
      -- reason given was G-10, "the name stays inside the ring": letting the
      -- band run to the ring's bottom EDGE does push the name onto the arc.
      --
      -- But the ring's outer edge was never the right bound. The name has to
      -- clear the arc's INNER edge, cy + clearR, which is what chordAt already
      -- measures against - so bounding the band there distributes the slack
      -- AND satisfies G-10 by construction rather than by staying away from
      -- the problem. clipToChord then keeps a long source name inside the
      -- circle at its new, lower depth, where the chord is narrower.
      L.nameBox = box(dial.x, stackTop + T.px(T.space.xs), dial.w, nameH)
      local ringInner = L.cy + L.radius - floor(L.trackThickness / 2)
      stackTextRows(stackTop, ringInner - T.px(T.space.xs), { L.nameBox }, h)
      clipToChord(L, L.nameBox)
      L.showMinMaxText = false
    else
      -- The name hangs in the ring's OPEN WEDGE, below the arc's ends, so
      -- unlike the min/max row above it, moving it down costs no width. The
      -- old code took `closeY` - tight under the content - and left the
      -- remainder as dead air (15 px at 260x220, Tanda 5 review 3.15 part
      -- two). Split the difference instead: the name breathes, and `farY`
      -- still caps it at the spot that was always known to clear the arc.
      local afterMinMax = L.showMinMaxText
        and (L.minMaxBox.y + L.minMaxBox.h) or stackTop
      local closeY = afterMinMax + T.px(T.space.xs)
      local farY = dial.y + dial.h - nameH
      local y = closeY + floor(max(farY - closeY, 0) / 2)
      L.nameBox = box(0, min(y, farY), w, nameH)
    end
    -- the balanced dial places its rows itself: inside the ring the chord,
    -- not the slack, decides where a row may sit
    stackRows = {}
    stackTop, stackBottom = 0, 0
  end

  -- The unit was placed against the value's baseline inside placeValue, so if
  -- the stack MOVED the value (it does in a horizontal zone, where the value
  -- is one of the distributed rows) the unit has to travel with it or it is
  -- left behind on the old baseline.
  local valueY0 = L.valueBox.y
  stackTextRows(stackTop, stackBottom, stackRows, h)
  local valueDY = L.valueBox.y - valueY0
  if valueDY ~= 0 then L.unitBox.y = L.unitBox.y + valueDY end
  -- A row that is not drawn keeps a sane position rather than the y = 0 the
  -- provisional boxes above carry: minMaxBox still feeds clipToChord and the
  -- min/max split below, and a box at the top of the zone would clip against
  -- the wrong chord.
  if not L.showMinMaxText then
    L.minMaxBox.y = L.valueBox.y + L.valueBox.h
  end
  L.textAlign = align
  L.nameAlign = horizontalInstrument and LEFT or align
  L.stateAlign = horizontalInstrument and RIGHT or align

  -- the min/max row hangs below the value INSIDE the dial circle: constrain
  -- it to the chord at its depth so it neither crosses the ring nor the
  -- history marks that point into the same lower band (AUDIT.md G-7). The
  -- minTextBox/maxTextBox split below then inherit the clipped width.
  if orientation == "balanced" then
    clipToChord(L, L.minMaxBox)
  end

  -- min / max text share the min-max row, LEFT and RIGHT aligned inside their
  -- halves. That is what makes them a PAIR - so the row must be no wider than
  -- the pair needs (F4).
  --
  -- It used to inherit the full width of whatever contained it. In a 480x272
  -- zone that is the whole 202 px text column: "min 31" flush left, "max 78"
  -- flush right, 202 px of nothing between them, with the source name starting
  -- under "min". Three labels scattered along a line read as three unrelated
  -- labels, not as one caption belonging to the value above.
  --
  -- Capped to what the two strings need plus one comfortable gap, and then
  -- aligned the way the rest of the column is - so the group hangs together
  -- and still never grows past the space it was given.
  local mmNeed = T.textWidth("min " .. F.widestSample(widget), L.minMaxFont) * 2
    + T.px(T.space.lg)
  local mmW = min(L.minMaxBox.w, max(mmNeed, T.px(24)))
  local mmAlign = horizontalInstrument and CENTER or align
  if mmW < L.minMaxBox.w then
    if mmAlign == CENTER then
      L.minMaxBox.x = L.minMaxBox.x + floor((L.minMaxBox.w - mmW) / 2)
    end
    L.minMaxBox.w = mmW
  end
  local halfW = floor(L.minMaxBox.w / 2)
  L.minTextBox = box(L.minMaxBox.x, L.minMaxBox.y, halfW, minMaxH)
  L.maxTextBox = box(L.minMaxBox.x + halfW, L.minMaxBox.y, halfW, minMaxH)

  -- scale end labels, one at each arc end, sitting just OUTSIDE the end
  -- ticks. The old code centred a fixed 30 px box on the point at
  -- tickOuter + px(sm): its inner half retreated over the end tick ("100"
  -- read as "f00", AUDIT.md G-8), and the fixed width clipped long strings
  -- like 20000.00 (AUDIT.md G-9). Each label is now sized with its own text
  -- width and pushed outward along the radial until its NEAREST corner sits
  -- at r0 - so every point of the box is at distance >= r0 from the centre,
  -- and no point of the tick (which ends inside r0) can touch it.
  if L.showScale then
    local sh = T.fontHeight(L.scaleFont)
    local r0 = L.tickOuter + T.px(T.space.sm)
    local function placeScaleLabel(angle, text)
      local sw = T.textWidth(text, L.scaleFont)
      local a, b = sw / 2, sh / 2
      local ux, uy = G.pointOnCircle(0, 0, 1, angle)
      local sx = (ux >= 0) and a or -a
      local sy = (uy >= 0) and b or -b
      local dot = ux * sx + uy * sy
      local r = dot + math.sqrt(math.max(dot * dot + r0 * r0 - a * a - b * b, 0))
      local cx, cy = G.pointOnCircle(L.cx, L.cy, r, angle)
      return box(cx - a, cy - b, sw, sh)
    end
    -- A label that the zone edge forced back over its own end tick slides
    -- along the TANGENT until it clears the tick: the radial placement above
    -- clears it by construction, only the zone clamp can pull it back in. A
    -- 180 deg arc ends at 9/3 o'clock, right at the extreme marks, so on a
    -- zone just wide enough for the dial the clamp does exactly that
    -- (AUDIT.md G-11).
    local function clearEndTick(angle, b)
      local ux, uy = G.pointOnCircle(0, 0, 1, angle)
      local px, py = -uy, ux            -- tangent unit vector
      local halfTh = max(1, L.tickThickness / 2)
      local tMin, tMax, pMin, pMax = math.huge, -math.huge, math.huge, -math.huge
      for i = 1, 4 do
        local cx0 = b.x + ((i % 2 == 1) and 0 or b.w)
        local cy0 = b.y + (i <= 2 and 0 or b.h)
        local dx, dy = cx0 - L.cx, cy0 - L.cy
        local t = dx * ux + dy * uy
        local pt = dx * px + dy * py
        if t < tMin then tMin = t end
        if t > tMax then tMax = t end
        if pt < pMin then pMin = pt end
        if pt > pMax then pMax = pt end
      end
      -- clear when the radial span or the perpendicular band misses the tick
      if tMax <= L.tickInner or tMin >= L.tickOuter
        or pMax <= -halfTh or pMin >= halfTh then
        return b
      end
      local gap = 1
      local function shifted(s)
        return box(b.x + px * s, b.y + py * s, b.w, b.h)
      end
      local function inZone(bb)
        return bb.x >= 0 and bb.y >= 0
          and bb.x + bb.w <= w and bb.y + bb.h <= h
      end
      local d = shifted(halfTh + gap - pMin)          -- slide along +tangent
      if inZone(d) then return d end
      local u = shifted(-halfTh - gap - pMax)         -- or along -tangent
      if inZone(u) then return u end
      return b  -- no room either way: keep the clamped position
    end
    L.scaleMinBox = placeScaleLabel(L.startAngle,
      F.display(widget, widget.config.min))
    L.scaleMaxBox = placeScaleLabel(L.startAngle + L.sweep,
      F.display(widget, widget.config.max))
    -- do not let the labels leave the zone
    if L.scaleMinBox.x < 0 then L.scaleMinBox.x = 0 end
    if L.scaleMaxBox.x + L.scaleMaxBox.w > w then
      L.scaleMaxBox.x = w - L.scaleMaxBox.w
    end
    L.scaleMinBox = clearEndTick(L.startAngle, L.scaleMinBox)
    L.scaleMaxBox = clearEndTick(L.startAngle + L.sweep, L.scaleMaxBox)
    -- Endpoint labels are atomic: showing only one implies a false range. A
    -- normal horizontal face may use them only when both boxes remain inside
    -- the zone, remain distinct, and stay out of the information column.
    local function inside(bb)
      return bb.x >= 0 and bb.y >= 0
        and bb.x + bb.w <= w and bb.y + bb.h <= h
    end
    local function intersects(a, b)
      return a.x < b.x + b.w and a.x + a.w > b.x
        and a.y < b.y + b.h and a.y + a.h > b.y
    end
    if not inside(L.scaleMinBox) or not inside(L.scaleMaxBox)
      or intersects(L.scaleMinBox, L.scaleMaxBox)
      or (horizontalInstrument
          and (intersects(L.scaleMinBox, textRegion)
               or intersects(L.scaleMaxBox, textRegion))) then
      L.showScale = false
    end
  end

  -- C1 (Tanda 7): centre the whole composition in a VERTICAL zone.
  --
  -- The dial is pinned to the top with `pad`, and its side is capped at
  -- min(w, h * 0.62) - so in a tall, narrow zone the dial is width-limited and
  -- cannot grow, the text is centred in whatever is left, and the result is
  -- air at both ends. Measured at 100x260: the dial ended at y=94, the value
  -- sat at 164..188, leaving 70 px above it and 72 px below - 142 of 260 px,
  -- 55 % of the zone, unused.
  --
  -- Shifting dial and text down together as one group closes that. The shift
  -- is capped by the CONTAINMENT budget rather than applied blindly: moving
  -- the ring down reduces its clearance to the bottom edge, and the ring's
  -- outermost line geometry must stay inside the zone or the widget dies on
  -- luaL_checkunsigned (see the edgeReach clamp above, and R-1/R-4).
  if orientation == "vertical" then
    local top = min(L.cy - L.tickOuter, L.valueBox.y)
    local bottom = max(L.cy + L.tickOuter, L.valueBox.y + L.valueBox.h)
    if L.showMinMaxText then bottom = max(bottom, L.minMaxBox.y + L.minMaxBox.h) end
    if L.showName then bottom = max(bottom, L.nameBox.y + L.nameBox.h) end
    local shift = floor(((h - (bottom - top)) / 2) - top)
    -- never move UP (that would undo the top padding), and never eat into the
    -- clearance the ring needs below itself
    local room = (h - L.cy) - max(L.tickOuter, L.markOuter) - 1
    shift = min(shift, max(room, 0))
    -- And never push the composition PAST the bottom edge. When the content
    -- is taller than the zone - a 16x22 micro dial, where neither the ring
    -- nor the smallest font can shrink any further - the group already
    -- overflows at the top, and centring it just moves the overflow to the
    -- bottom, where it takes the value label out of the zone with it.
    shift = min(shift, max(h - bottom, 0))
    if shift > 0 then
      L.cy = L.cy + shift
      local boxes = { L.valueBox, L.unitBox, L.minMaxBox, L.nameBox,
                      L.stateBox, L.minTextBox, L.maxTextBox,
                      L.scaleMinBox, L.scaleMaxBox }
      for i = 1, #boxes do
        if boxes[i] then boxes[i].y = boxes[i].y + shift end
      end
    end
  end
end


function M.calculate(widget, cfg, L)
  local w, h = widget.zone.w, widget.zone.h
  if not L then
    local mode, orientation = C.classify(w, h)
    L = { mode = mode, orientation = orientation, w = w, h = h }
  end
  L.style = "dial"
  dialLayout(widget, cfg, L, w, h)
  return L
end

return M
