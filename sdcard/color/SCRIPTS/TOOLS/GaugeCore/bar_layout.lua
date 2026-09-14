---- Gauge Core - bar-only responsive layout ------------------------------

local M = {}
local floor, min, max = math.floor, math.min, math.max
local C, T, G, F
local clamp, box, chipOverhang, placeValue

function M.setup(common, theme, geometry, format)
  C, T, G, F = common, theme, geometry, format
  clamp, box = C.clamp, C.box
  chipOverhang, placeValue = C.chipOverhang, C.placeValue
end

-- ------------------------------------------------------------------- bar --

local function barLayout(widget, cfg, L, w, h)
  -- The layout stacks value / bar / state row with `pad` between and around
  -- them: three gaps, 12 px at the normal step. In a 44 px zone that is more
  -- than a quarter of the height, competing directly with the value font
  -- floor (P1-4) and the state row (P1-2) - and it was exactly the 2 px the
  -- old budget had to under-reserve to keep both, which is what pushed the
  -- pill out of the zone. Short bars (the same breakpoint that drops the
  -- name) buy the room back from the padding instead, honestly.
  local compactPad = T.px(T.space.xs)
  local pad = (h < T.px(46)) and compactPad or T.px(T.space.sm)
  L.showUnit = true
  L.showValue = true
  L.showName = h >= T.px(46)
  -- the row is reserved whatever ShowChip says: see the dial branch (F9)
  L.showState = w >= T.px(120)
  L.showMarkers = (cfg.showMinMax or 1) > 1
  -- Slot 6 is one of the SHARED options, so its third choice has to mean the
  -- same thing here as it does on the dial. It used to be hard-wired false:
  -- "Markers + text" was pixel-identical to "Markers" on every bar, at every
  -- size. Placement is decided after placeValue, against the room the value
  -- row actually leaves.
  L.showMinMaxText = (cfg.showMinMax or 1) > 2
  L.showScale = false
  L.showGhost = true
  L.showNeedle = false

  L.nameFont = T.FONTS.XS
  L.stateFont = T.FONTS.XS
  L.minMaxFont = T.FONTS.XXS
  -- A real fullscreen landscape instrument needs a composed visual block,
  -- not a value centred in all remaining height with a rail pinned to the
  -- bottom. This flag changes pixels only; the stored option contract and all
  -- compact degradation rules remain untouched.
  local fullscreen = w >= T.px(400) and h >= T.px(240)
  L.fullscreenBar = fullscreen
  if fullscreen then L.minMaxFont = T.FONTS.XS end
  local nameH = T.fontHeight(L.nameFont)
  local stateH = T.fontHeight(L.stateFont)
  -- the smallest font the value can use: the value region must never drop
  -- under this, or the auto-fit would overflow the box (AUDIT.md P1-4)
  local minText = T.fontHeight(T.FONTS.XXS)

  -- The min/max marker and the peak-hold ghost stick out this far above AND
  -- below the bar, so they read as ticks against it rather than as part of
  -- the fill. It is LAYOUT data because it is part of the bar's real
  -- footprint and the budget below has to reserve it: bar.lua reads it back
  -- instead of restating px(2)/px(4), which is what kept the two in sync
  -- once the pill taught the same lesson.
  L.markOverhang = T.px(2)

  -- Width of the chipEdge outline drawn around the state pill, on EACH side.
  -- Both renderers must inset by this and grow by twice it - never by
  -- T.px(2), which is not 2 * T.px(1) at every LCD_SCALE (see chipOverhang).
  L.chipOutline = T.px(1)

  -- The row below the bar carries the state text (right) and, when there is
  -- height for it, the name (left). Its height is the STATE font's, never
  -- the name's: sizing it from nameH meant the short-bar paths zeroed nameH
  -- and collapsed STALE/NO LINK/WARN/CRIT out of exactly the zones where
  -- they matter most (AUDIT.md P1-2). Both fonts are XS here, so the two
  -- readings coincide today - naming the state font keeps it that way if
  -- either font is ever re-tuned.
  --
  -- VERTICAL BUDGET. The zone has to hold, top to bottom: the value area,
  -- the bar, and the state/name row - and the state PILL is taller than its
  -- text and centred on it (review P-B), so the row must also reserve what
  -- the pill hangs below that text (chipOverhang, outline included).
  --
  -- When it does not all fit, relax in this order, giving up the least
  -- important thing left each time:
  --
  --   1. full pill, preferred bar height     (the intended look)
  --   2. full pill, bar trimmed to its floor
  --   3. minimal pill (stateH + 2)
  --   4. bare pill (stateH + 0): no vertical padding, outline only
  --   5. no state row at all
  --
  -- Rungs 1-4 all keep WARN / CRIT / NO LINK on screen, which is what P1-2
  -- guarantees; rung 4 exists precisely so that a 44 px bar reaches it
  -- instead of falling to rung 5. Every rung sizes the row from the pill it
  -- actually paints, which is what keeps the pill inside the zone: the old
  -- nested version reserved floor(chipExtra / 2) - forgetting the 1 px
  -- outline - and reserved nothing at all on the minimal-pill rung, so the
  -- pill left the bottom of EVERY bar zone by 1 px, and a short one by 2.
  local chipExtra, rowH, barH, textH

  -- One rung: the tallest bar this pill size allows, else the bar trimmed to
  -- its floor. Returns true when the value area still fits.
  local function fits(extra)
    chipExtra = extra
    rowH = (L.showState or L.showName)
      and (stateH + chipOverhang(L.showState, extra, L.chipOutline)) or 0
    -- What has to fit UNDER the bar. With no row down there, the bottom pad
    -- is all that separates the bar from the zone edge, and the markers
    -- already stick markOverhang px past it - so the marker, not the row,
    -- sets the floor. A real row is always taller than the overhang, so this
    -- only ever bites on the row-less short bar it was written for.
    local below = max(rowH, L.markOverhang)
    barH = clamp(floor(h * 0.34), T.px(8), T.px(26))
    textH = h - barH - below - pad * 3
    if textH >= minText then return true end
    barH = max(h - minText - below - pad * 3, T.px(8))
    textH = h - barH - below - pad * 3
    return textH >= minText
  end

  if not L.showState then
    fits(0)
  else
    local stateFits = fits(T.px(6)) or fits(T.px(2)) or fits(0)
    -- The old height breakpoint changed TWO variables at h=px(46): it added
    -- the name and switched xs -> sm padding. With the real EdgeTX font
    -- heights, a 46 px bar therefore lost its safety row after a 44 px bar
    -- had shown it, then regained it later. Padding is another degradation
    -- rung: if the preferred spacing fails, retry the exact same pill ladder
    -- with compact spacing before removing WARN/CRIT.
    if not stateFits and pad > compactPad then
      pad = compactPad
      stateFits = fits(T.px(6)) or fits(T.px(2)) or fits(0)
    end
    if not stateFits then
      L.showState = false               -- final rung: last resort
      fits(0)
    end
  end
  -- A zone too short for even the smallest value font keeps the font's
  -- height anyway; the value box is what the auto-fit needs (AUDIT.md P1-4).
  --
  -- But raising textH back up does not create pixels. The bar was sized from
  -- the budget that did NOT fit, so unless it gives the room back the track
  -- is drawn past the bottom edge of the zone - measured at 200x20: the bar
  -- ended 3 px outside, taking the min/max marks (markOverhang) with it.
  -- LVGL clips it to the parent, so this is a silently truncated instrument
  -- rather than a crash, which is precisely why it survived this long.
  -- The bar is the element that degrades most gracefully here: a 2 px bar
  -- still reads as a bar, a bar outside the widget reads as nothing.
  if textH < minText then
    textH = minText
    barH = max(h - textH - max(rowH, L.markOverhang) - pad * 3, T.px(2))
  end

  local groupTop = pad
  if fullscreen then
    barH = clamp(floor(h * 0.09), T.px(24), T.px(42))
    textH = clamp(floor(h * 0.26), T.fontHeight(T.FONTS.XL), T.px(124))
    local below = max(rowH, L.markOverhang)
    local groupH = textH + barH + below + pad * 3
    groupTop = max(pad, floor((h - groupH) / 2))
  end

  local valueRegion = box(pad, groupTop, w - pad * 2, textH)
  placeValue(L, valueRegion, F.widestSample(widget),
             L.showUnit and widget.unitText or "",
             (h < T.px(60)) and T.FONTS.M or nil)

  -- "min N" / "max N" ride the ENDS of the value row rather than claiming a
  -- row of their own: the five-rung vertical ladder above has already spent
  -- every pixel this zone has, and a horizontal bar leaves that row's two
  -- margins empty around a centred value. Reserved against the configured
  -- endpoints - the longest legitimate captions for this scale - exactly as
  -- the dial does, and dropped back to the marks when either margin is too
  -- narrow, so a live extreme can never wrap or collide with the value.
  if L.showMinMaxText then
    local minMaxH = T.fontHeight(L.minMaxFont)
    local need = max(
      T.textWidth("min " .. F.display(widget, cfg.min), L.minMaxFont),
      T.textWidth("max " .. F.display(widget, cfg.max), L.minMaxFont))
    local groupLeft = L.valueBox.x
    local groupRight = (L.unitBox and L.showUnit)
      and (L.unitBox.x + L.unitBox.w) or (L.valueBox.x + L.valueBox.w)
    local leftRoom = groupLeft - pad * 2
    local rightRoom = (w - pad) - groupRight - pad
    local baseline = L.valueBox.y + L.valueBox.h - minMaxH
    if need > 0 and leftRoom >= need and rightRoom >= need
       and baseline >= pad then
      L.minTextBox = box(pad, baseline, leftRoom, minMaxH)
      L.maxTextBox = box(groupRight + pad, baseline, rightRoom, minMaxH)
    else
      L.showMinMaxText = false
    end
  end

  L.bar = box(pad, groupTop + textH + pad, w - pad * 2, barH)
  -- Below roughly 24 px of zone height nothing fits honestly any more: textH
  -- has already been floored at the smallest font in the ramp (P1-4) and barH
  -- at px(2), and the two plus the padding still exceed the zone. Slide the
  -- bar up rather than let it - and the min/max marks that overhang it by
  -- markOverhang - be drawn past the bottom edge. The value then overlaps the
  -- bar, which is the honest picture at that size; painting outside the
  -- widget is not, and LVGL would clip it away unseen.
  local barLimit = h - L.markOverhang
  if L.bar.y + L.bar.h > barLimit then
    L.bar.y = max(barLimit - L.bar.h, L.markOverhang)
    if L.bar.y + L.bar.h > h then L.bar.h = max(h - L.bar.y, 1) end
    barH = L.bar.h
  end
  -- Keep the complete, containment-corrected footprint. Phase 2 can make the
  -- visible rail thin or thick inside this slot without rerunning (or
  -- weakening) the five-rung short-zone budget above.
  L.barSlot = box(L.bar.x, L.bar.y, L.bar.w, L.bar.h)
  L.barRadius = floor(barH / 2)
  L.nameBox = box(pad, L.bar.y + barH + pad, floor((w - pad * 2) / 2), nameH)
  L.stateBox = box(pad + floor((w - pad * 2) / 2), L.bar.y + barH + pad,
                   floor((w - pad * 2) / 2), stateH)
  L.nameAlign = LEFT
  L.stateAlign = RIGHT
  L.textAlign = LEFT
  -- same pill as the dial (review P-B), sized to what the zone could reserve
  L.chipPad = T.px(7)
  L.chipHeight = stateH + chipExtra
  -- see the dial branch: chipOff must come from the layout, or a no-op
  -- update() loses it and the next chip render crashes (Tanda 6 F-1)
  L.chipOff = floor((L.chipHeight - stateH) / 2)
  L.markThickness = max(1, T.px(2))
end

-- Resolve the visible Continuous-rail body inside the footprint barLayout
-- already proved fits. Appearance is resolved after M.calculate(), because
-- the immutable bar-style resolver owns preset/override precedence while the
-- layout owns pixels. Keeping that seam explicit prevents a BarSize edit from
-- bypassing the short-bar degradation ladder.
function M.applyBarVisual(L, visual, cfg)
  if not L or L.style ~= "bar" or not visual then return L end
  local slot = L.barSlot or L.bar
  local vertical = visual.direction == "vertical"
  L.barDirection = vertical and "vertical" or "horizontal"
  L.valuePosition = visual.valuePos or "auto"
  L.labelPosition = visual.labelPos or "auto"
  L.showValue = L.valuePosition ~= "off"
  if not L.showValue then L.showUnit = false end
  if L.labelPosition == "off" then L.showName = false end

  if vertical then
    -- Reclaim the tall zone: barLayout has already selected safe fonts and
    -- badge dimensions, but its provisional horizontal rail would consume
    -- only ~26 px. Keep the information hierarchy above/below and turn the
    -- middle into a genuine vertical instrument.
    local pad = max(1, slot.x)
    local top = pad
    local valueH = L.showValue and L.valueBox.h or 0
    local nameH = L.showName and L.nameBox.h or 0
    local topRows = 0
    if L.showValue and (L.valuePosition == "auto"
       or L.valuePosition == "above") then
      topRows = topRows + valueH + pad
    end
    if L.showName and L.labelPosition == "above" then
      topRows = topRows + nameH + pad
    end
    top = top + topRows

    local belowName = L.showName and (L.labelPosition == "auto"
      or L.labelPosition == "below")
    local bottomRows = belowName and nameH or 0
    if L.showState then
      local stateFoot = L.chipHeight - L.chipOff + L.chipOutline
      if bottomRows > 0 then bottomRows = bottomRows + pad end
      bottomRows = bottomRows + stateFoot
    end
    local bottom = L.h - pad - ((bottomRows > 0) and (bottomRows + pad) or 0)
    if bottom <= top then
      -- A pathological tiny/tall zone keeps containment and makes the value
      -- an overlay before sacrificing the data axis.
      top = pad
      L.valuePosition = L.showValue and "inside" or L.valuePosition
      bottom = max(top + 1, L.h - pad
        - ((bottomRows > 0) and (bottomRows + pad) or 0))
    end
    slot = box(pad, top, max(1, L.w - pad * 2), max(1, bottom - top))
    L.barSlot = slot

    -- "Inside" on a tall instrument means inside the instrument footprint,
    -- not printed through its data rail. Reserve a compact information lane
    -- beside the rail whenever the value/name is authored Inside or End. This
    -- keeps ticks, threshold marks and the moving head readable while giving
    -- the text a stable high-contrast canvas in both light and dark themes.
    local sideValue = L.showValue
      and (L.valuePosition == "inside" or L.valuePosition == "end")
    local sideLabel = L.showName and L.labelPosition == "inside"
    if (sideValue or sideLabel) and slot.w >= T.px(36) then
      local gap = max(pad, T.px(3))
      local railW = max(T.px(12), floor((slot.w - gap) * 0.38))
      railW = min(railW, max(1, slot.w - gap - T.px(18)))
      L.barRailSlot = box(slot.x, slot.y, railW, slot.h)
      local textX = slot.x + railW + gap
      local textW = max(1, slot.x + slot.w - textX)
      if sideValue then
        L.valueBox.x, L.valueBox.w = textX, textW
        L.valueAlign = LEFT
      end
      if sideLabel then
        L.nameBox.x, L.nameBox.w = textX, textW
        L.nameAlign = LEFT
      end
    end

    if L.showValue then
      if L.valuePosition == "inside" then
        L.valueBox.y = top + floor((slot.h - L.valueBox.h) / 2)
      elseif L.valuePosition == "end" then
        L.valueBox.y = top
      else
        L.valueBox.y = pad
      end
    end
    if L.showName then
      if L.labelPosition == "above" then
        L.nameBox.x, L.nameBox.y, L.nameBox.w = pad,
          pad + ((L.showValue and (L.valuePosition == "above"
            or L.valuePosition == "auto"))
            and (valueH + pad) or 0), L.w - pad * 2
        L.nameAlign = LEFT
      elseif L.labelPosition == "inside" then
        if not L.barRailSlot then
          L.nameBox.x, L.nameBox.w, L.nameAlign = pad, L.w - pad * 2, CENTER
        end
        L.nameBox.y = max(top, bottom - nameH - pad)
      else
        L.nameBox.x, L.nameBox.y, L.nameBox.w = pad, bottom + pad,
          L.w - pad * 2
        L.nameAlign = CENTER
      end
    end
    if L.showState then
      L.stateBox.x, L.stateBox.y = pad + floor((L.w - pad * 2) / 2),
        bottom + pad + (belowName and (nameH + pad) or 0)
      L.stateBox.w = floor((L.w - pad * 2) / 2)
    end
  else
    -- Horizontal placement variants preserve the proven short-bar footprint;
    -- they only move information within its reserved regions. This keeps the
    -- state row and marker overhang guarantees intact at 44 px heights.
    local pad = max(1, slot.x)
    if L.showValue and L.valuePosition == "inside" then
      L.valueBox.x, L.valueBox.y, L.valueBox.w = pad,
        slot.y + floor((slot.h - L.valueBox.h) / 2), L.w - pad * 2
      L.valueAlign = CENTER
    elseif L.showValue and L.valuePosition == "end" then
      L.valueBox.x, L.valueBox.w = floor(L.w * 0.5),
        max(1, L.w - floor(L.w * 0.5) - pad)
      L.valueAlign = RIGHT
    end
    if L.showName and L.labelPosition == "above" then
      L.nameBox.x, L.nameBox.y, L.nameBox.w = pad, pad,
        max(1, floor((L.w - pad * 2) / 2))
      L.nameAlign = LEFT
    elseif L.showName and L.labelPosition == "inside" then
      L.nameBox.x, L.nameBox.y, L.nameBox.w = pad,
        slot.y + max(0, slot.h - L.nameBox.h), L.w - pad * 2
      L.nameAlign = CENTER
    end
  end

  -- placeValue() authored the unit against the original value baseline. Any
  -- presentation variant that moves the value row must move that baseline as
  -- one semantic group; anchorUnit() will handle the live horizontal edge.
  if L.showValue and L.showUnit and L.unitBox then
    L.unitBox.y = L.valueBox.y + L.valueBox.h - L.unitBox.h - T.px(1)
  end

  local railSlot = L.barRailSlot or slot
  local maximum = max(1, vertical and railSlot.w or railSlot.h)
  local family = visual.profile and visual.profile.family or "standard"
  local large = family == "large"
  local wanted
  if visual.thickness == "thin" then
    wanted = T.px(large and 5 or 4)
  elseif visual.thickness == "thick" then
    wanted = T.px(large and 22 or 16)
  elseif visual.thickness == "maximum" then
    wanted = maximum
  else
    wanted = T.px((large and L.fullscreenBar) and 20 or large and 14 or 10)
  end
  wanted = clamp(wanted, min(maximum, T.px(2)), maximum)

  local outerX = vertical and (railSlot.x + floor((railSlot.w - wanted) / 2))
    or railSlot.x
  local outerY = vertical and railSlot.y
    or (railSlot.y + floor((railSlot.h - wanted) / 2))
  L.barOuter = vertical and box(outerX, outerY, wanted, railSlot.h)
    or box(outerX, outerY, railSlot.w, wanted)

  -- A retained outline around the track supplies a real casing. The outline
  -- must not be filled: it can become fully opaque under contrast assist and
  -- would otherwise defeat the inactive track's reduced opacity (W-03). The
  -- inset is surrendered on extremely small rails so the data channel never
  -- collapses to zero pixels.
  local primaryLength = vertical and slot.h or slot.w
  local edge = (wanted >= T.px(5) and primaryLength >= T.px(12))
    and T.px(1) or 0
  local innerW = max(1, L.barOuter.w - edge * 2)
  local innerH = max(1, L.barOuter.h - edge * 2)
  L.bar = box(L.barOuter.x + edge, L.barOuter.y + edge, innerW, innerH)
  L.barEdge = edge
  L.barThickness = visual.thickness
  L.barEnds = visual.ends
  L.barRadius = (visual.ends == "round")
    and floor((vertical and innerW or innerH) / 2) or 0
  L.barOuterRadius = (visual.ends == "round") and floor(wanted / 2) or 0
  L.barChamfer = (visual.ends == "chamfer")
    and min(floor((vertical and innerW or innerH) / 2), T.px(6)) or 0
  local axisInset = L.barChamfer
  if vertical then
    L.barAxis = box(L.bar.x, L.bar.y + axisInset, L.bar.w,
                    max(1, L.bar.h - axisInset * 2))
  else
    L.barAxis = box(L.bar.x + axisInset, L.bar.y,
                    max(1, L.bar.w - axisInset * 2), L.bar.h)
  end
  L.activeBar = box(L.barAxis.x, L.barAxis.y, L.barAxis.w, L.barAxis.h)
  if cfg and (cfg.colorMode == 3 or cfg.colorMode == 5)
     and (vertical and L.barAxis.w or L.barAxis.h) >= T.px(5) then
    local cross = vertical and L.barAxis.w or L.barAxis.h
    local rail = max(1, min(T.px(3), floor(cross * 0.3)))
    if vertical then
      L.activeBar.w = max(1, L.barAxis.w - rail - T.px(1))
    else
      L.activeBar.h = max(1, L.barAxis.h - rail - T.px(1))
    end
  end
  L.axis = G.makeAxis(L.barAxis, L.barDirection, cfg.min, cfg.max,
                      visual.origin)
  L.activeAxis = G.makeAxis(L.activeBar, L.barDirection, cfg.min, cfg.max,
                            visual.origin)
  return L
end


function M.calculate(widget, cfg, L)
  local w, h = widget.zone.w, widget.zone.h
  if not L then
    local mode, orientation = C.classify(w, h)
    L = { mode = mode, orientation = orientation, w = w, h = h }
  end
  L.style = "bar"
  barLayout(widget, cfg, L, w, h)
  return L
end

return M
