---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - retained bar face contract                                #
---- #                                                                       #
---- # Face code receives normalized render state. It never reads sensors,   #
---- # classifies alerts, owns labels/badges/history, or creates objects in  #
---- # update(). Continuous, Blocks, Hex, Ticks, and Steps are production     #
---- # faces, including signed Dual Rail on horizontal and vertical axes.     #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local T, G, R
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
-- Forward-declared: the continuous face builds its surface long before the
-- segmented helpers are defined, and it used to carry its own copy of this.
-- Two copies meant a surface fix landed in one face and not the other.
local buildPanel

-- Hot-path variants for already-normalized render state. The public geometry
-- helpers clamp arbitrary callers; face updates receive guaranteed 0..1 and
-- avoid repeating tonumber/clamp work several times per frame.
local function pointAt(axis, normalized)
  return axis.start + axis.growth * floor(axis.length * normalized + 0.5)
end

local function spanAt(axis, fromPosition, toPosition)
  local p1, p2 = pointAt(axis, fromPosition), pointAt(axis, toPosition)
  if p1 > p2 then p1, p2 = p2, p1 end
  if axis.orientation == "vertical" then
    return axis.x, p1, axis.w, p2 - p1
  end
  return p1, axis.y, p2 - p1, axis.h
end

local GRADIENT_CEILING = 38
local GRADIENT_SHARED_RESERVE = 11

function M.setup(theme, geometry, renderer)
  T, G, R = theme, geometry, renderer
end

local function unavailableSupports()
  return false
end

local function unavailableBuild()
  return false
end

local function unavailableUpdate() end
local function unavailablePalette() end
local function unavailableVisible() end

local function continuousSupports(_profile, config)
  return not config or config.direction == nil
    or config.direction == "horizontal" or config.direction == "vertical"
end

-- Gradient is a SHARED rule, not a bar rule: slice budget, scale-position ->
-- severity mapping and slice colour all live in the core so the dial's arc
-- and this axis cannot drift into two meanings (ui_core, "spatial gradient").
-- Re-exported here because the catalogue, the census and the tests address
-- them through the face module.
function M.gradientSliceCount(length, available)
  return R.gradientSliceCount(length, available)
end

function M.gradientPosition(cfg, axisPosition)
  return R.gradientPosition(cfg, axisPosition)
end

local function gradientFixedObjects(config, layout)
  local count = 1 -- exact position head
  if config and config.surface and config.surface ~= "transparent" then
    count = count + 1
  end
  if config and config.ends == "chamfer" then
    count = count + 4 -- three-piece track + authored-start tip
  else
    count = count + 1 -- one-piece track
    -- The current one-pixel casing is a centre rectangle plus two bevel tips.
    -- With no concrete layout (the estimator), reserve it conservatively.
    if not layout or (layout.barEdge or 0) > 0 then count = count + 3 end
  end
  return count
end

local function gradientSharedObjects(widget)
  local L, cfg = widget.layout, widget.config
  local count = 1 -- value label
  if L.showUnit and widget.unitText ~= "" then count = count + 1 end
  if L.showName then count = count + 1 end
  if L.showState then count = count + 3 end -- edge + fill + label
  if L.showGhost then count = count + 1 end
  if L.showMarkers then count = count + 2 end
  if L.showMinMaxText then count = count + 2 end -- min + max captions
  local marks = widget.barVisual and widget.barVisual.marks or "auto"
  local thresholds = marks == "thresholds" or marks == "full"
    or (marks == "auto" and cfg.colorMode ~= R.COLOR_STATIC)
  if thresholds then
    for i = 1, #widget.ranges do
      local t = G.normalize(widget.ranges[i].to, cfg.min, cfg.max)
      if t > 0 and t < 1 then count = count + 1 end
    end
  end
  if marks == "ends" or marks == "full" then count = count + 2 end
  if widget.barVisual and widget.barVisual.origin == "zero" then
    count = count + 1
  end
  return count
end

local function continuousEstimate(profile, config)
  if config and config.colorMode == R.COLOR_GRADIENT then
    local fixed = gradientFixedObjects(config)
    local available = GRADIENT_CEILING - GRADIENT_SHARED_RESERVE - fixed
    local length = (profile and profile.w) or 300
    return GRADIENT_SHARED_RESERVE + fixed
      + M.gradientSliceCount(length, available)
  end
  local count = 7 -- casing + track + fill + exact head + three bands
  if config and config.surface and config.surface ~= "transparent" then
    count = count + 1
  end
  if config and config.ends == "chamfer" then count = count + 2 end
  return count
end

local function shape(ui, key, rect, color, opacity, radius, bevel, orientation)
  bevel = min(bevel or 0, floor((rect.w - 1) / 2), floor(rect.h / 2))
  if bevel > 0 then
    if orientation == "vertical" then
      ui[key] = lvgl.rectangle{
        x = rect.x, y = rect.y + bevel, w = rect.w,
        h = max(1, rect.h - bevel * 2), color = color, opacity = opacity,
        filled = 1, rounded = 0,
      }
      local midX = rect.x + floor(rect.w / 2)
      ui[key .. "Caps"] = {
        lvgl.triangle{
          pts = { { rect.x, rect.y + bevel }, { midX, rect.y },
                  { rect.x + rect.w, rect.y + bevel } },
          color = color, opacity = opacity,
        },
        lvgl.triangle{
          pts = { { rect.x, rect.y + rect.h - bevel },
                  { rect.x + rect.w, rect.y + rect.h - bevel },
                  { midX, rect.y + rect.h } },
          color = color, opacity = opacity,
        },
      }
    else
      ui[key] = lvgl.rectangle{
        x = rect.x + bevel, y = rect.y,
        w = max(1, rect.w - bevel * 2), h = rect.h,
        color = color, opacity = opacity, filled = 1, rounded = 0,
      }
      ui[key .. "Caps"] = {
        lvgl.triangle{
          pts = {
            { rect.x + bevel, rect.y },
            { rect.x + bevel, rect.y + rect.h },
            { rect.x, rect.y + floor(rect.h / 2) },
          },
          color = color, opacity = opacity,
        },
        lvgl.triangle{
          pts = {
            { rect.x + rect.w - bevel, rect.y },
            { rect.x + rect.w, rect.y + floor(rect.h / 2) },
            { rect.x + rect.w - bevel, rect.y + rect.h },
          },
          color = color, opacity = opacity,
        },
      }
    end
  else
    ui[key] = lvgl.rectangle{
      x = rect.x, y = rect.y, w = rect.w, h = rect.h,
      color = color, opacity = opacity, filled = 1, rounded = radius or 0,
    }
  end
end

local function setShapeProp(widget, ui, key, prop, value)
  R.setProp(widget, ui[key], prop, value)
  local caps = ui[key .. "Caps"]
  if caps then
    for i = 1, #caps do R.setProp(widget, caps[i], prop, value) end
  end
end

local function showShape(ui, key, visible)
  local fn = visible and lvgl.show or lvgl.hide
  if ui[key] then fn(ui[key]) end
  local caps = ui[key .. "Caps"]
  if caps then for i = 1, #caps do fn(caps[i]) end end
end

local function bandSpan(axis, range, cfg)
  local t1 = G.normalize(range.from, cfg.min, cfg.max)
  local t2 = G.normalize(range.to, cfg.min, cfg.max)
  return G.axisSpan(axis, t1, t2)
end

local function buildReferenceBands(widget, axis)
  local ui, cfg, palette = widget.ui, widget.config, widget.barPalette
  if cfg.colorMode ~= R.COLOR_RAIL and cfg.colorMode ~= R.COLOR_SECTIONS then
    return
  end
  ui.rails = {}
  ui.railMeta = {}
  local railCross = max(1, min(T.px(3),
    floor(axis.crossLength * 0.3)))
  for i = 1, #widget.ranges do
    local range = widget.ranges[i]
    if cfg.colorMode == R.COLOR_SECTIONS or range.role ~= "normal" then
      local x, y, w, h = bandSpan(axis, range, cfg)
      if axis.orientation == "vertical" then
        x, w = axis.x + axis.w - railCross, railCross
      else
        y, h = axis.y + axis.h - railCross, railCross
      end
      if w > 0 and h > 0 then
        local opacity = (cfg.colorMode == R.COLOR_SECTIONS)
          and T.opacity.ghost or T.opacity.railBand
        local band = lvgl.rectangle{
          x = x, y = y, w = w, h = h,
          color = T.stateColor(range.role, widget.accent, palette),
          opacity = opacity, filled = 1, rounded = 0,
        }
        -- LVGL objects are opaque userdata on the radio (no __newindex), so
        -- the role/opacity the repaint path needs ride in a parallel array.
        ui.rails[#ui.rails + 1] = band
        ui.railMeta[#ui.railMeta + 1] = { role = range.role,
                                          baseOpacity = opacity }
      end
    end
  end
end

local function continuousBuild(widget, _geometry, style)
  local L, ui = widget.layout, widget.ui
  local b, outer = L.bar, L.barOuter or L.bar
  local palette = widget.barPalette
  local track = (palette and palette.track) or T.color.rail
  local border = (palette and palette.border) or T.color.label
  local bevel = (style.ends == "chamfer") and L.barChamfer or 0

  -- Surface is intentionally first: every instrument object and every shared
  -- label is created after it, so a theme/custom panel can ground the complete
  -- widget without changing text geometry. One shared builder for every face.
  buildPanel(widget, style)

  -- Round/square bodies use a separate one-pixel casing. It must be a REAL
  -- border, not a filled silhouette behind the translucent track: Contrast
  -- Auto can raise the casing to full opacity and, on the stock theme, border
  -- and track resolve to the same colour. A filled casing therefore makes the
  -- entire inactive channel visually opaque even though the track itself is
  -- correctly set to T.opacity.rail (W-03).
  --
  -- A true chamfer already needs three retained track primitives; omitting
  -- its redundant second three-piece outline keeps the worst
  -- surface+sections variant inside the approved 24-object Continuous budget.
  if (L.barEdge or 0) > 0 and bevel == 0 then
    ui.casing = lvgl.rectangle{
      x = outer.x, y = outer.y, w = outer.w, h = outer.h,
      color = border, opacity = T.opacity.railBand, filled = 0,
      thickness = L.barEdge, rounded = L.barOuterRadius,
    }
  end
  shape(ui, "track", b, track, T.opacity.rail, L.barRadius, bevel,
        L.axis.orientation)

  -- Chamfer tips are casing, not authored scale. Keeping the data axis in the
  -- central body prevents a one-pixel fill from leaking into transparent
  -- corners and makes threshold/head/history positions share one exact map.
  local axis = L.axis
  local active = L.activeAxis or axis
  buildReferenceBands(widget, axis)

  -- Shared threshold/history overlays are built after this body. The head is
  -- built even later by continuousBuildOverlay, so the paint stack is always
  -- body -> thresholds/history -> exact position head -> text/badge.
  if widget.config.colorMode == R.COLOR_GRADIENT then
    local fixed = gradientFixedObjects(style, L)
    local available = GRADIENT_CEILING - gradientSharedObjects(widget) - fixed
    local count = M.gradientSliceCount(axis.length, available)
    ui.gradientSlices = {}
    ui.sliceState = {}
    style.gradientSlices = count
    for i = 1, count do
      local t1, t2 = (i - 1) / count, i / count
      local x, y, w, h = G.axisSpan(active, t1, t2)
      local slice = lvgl.rectangle{
        x = x, y = y, w = max(1, w), h = max(1, h),
        -- The first refresh paints the complete signature-keyed ramp. Keeping
        -- build colour constant splits interpolation work out of the already
        -- expensive structural callback without ever showing a wrong slice:
        -- every slice remains hidden until that refresh sets its span.
        color = (palette and palette.critical) or T.color.crit,
        filled = 1, rounded = 0,
      }
      -- LVGL objects are opaque userdata on the radio (no __newindex), so all
      -- per-slice geometry/visibility state lives in a parallel array. The
      -- userdata back-reference stays here so show/set reach the object.
      local sdata = {
        object = slice,
        fromPosition = t1, toPosition = t2,
        baseX = x, baseY = y,
        baseW = max(1, w), baseH = max(1, h),
        paintX = x, paintY = y,
        paintW = max(1, w), paintH = max(1, h),
        barShown = false,
      }
      ui.sliceState[i] = sdata
      lvgl.hide(slice)
      ui.gradientSlices[i] = slice
    end
    -- Shared code and diagnostics continue to have one canonical fill handle;
    -- the pulse target below owns the complete slice pool.
    ui.fill = ui.gradientSlices[1]
  else
    local x, y, w, h = G.axisSpan(active, active.originT, active.originT)
    ui.fill = lvgl.rectangle{
      x = x, y = y, w = max(1, w), h = max(1, h),
      color = (palette and palette.normal) or T.color.accent,
      filled = 1,
      rounded = (style.ends == "round")
        and floor(active.crossLength / 2) or 0,
    }
    lvgl.hide(ui.fill)
  end
  if bevel > 0 and style.origin == "scale-low" then
    local capColor = ui.gradientSlices
      and ((palette and palette.critical) or T.color.crit)
      or (palette and palette.normal) or T.color.accent
    local capPts
    if axis.orientation == "vertical" then
      local midX = active.x + floor(active.w / 2)
      capPts = { { active.x, active.y + active.h },
        { b.x + b.w, active.y + active.h }, { midX, b.y + b.h } }
    else
      capPts = { { active.x, active.y },
        { active.x, active.y + active.h },
        { b.x, active.y + floor(active.h / 2) } }
    end
    ui.fillCap = lvgl.triangle{ pts = capPts, color = capColor }
    lvgl.hide(ui.fillCap)
  end
  -- The critical pulse never dims the DATA. Modulating the fill's opacity put
  -- the composite red at 1.74:1 against a dark theme at the trough - the most
  -- urgent state rendered as the least visible thing on screen, and outside
  -- the 3:1 floor every colour this widget paints has to clear. The segmented
  -- faces already pulsed only their head; continuous and dual now do the same,
  -- and bar.lua falls back to the state pill when a face has no head. The
  -- target is attached by continuousBuildOverlay, once the head exists.
  return true
end

local function movingHead(ui, key, axis, position, cross1, cross2, thickness,
                          color, opacity)
  local pts
  if axis.orientation == "vertical" then
    pts = { { cross1, position }, { cross2, position } }
  else
    pts = { { position, cross1 }, { position, cross2 } }
  end
  ui[key .. "Pts"] = pts
  ui[key .. "Set"] = { pts = pts }
  ui[key] = lvgl.line{
    pts = pts, thickness = thickness, color = color, opacity = opacity,
    rounded = 1,
  }
  lvgl.hide(ui[key])
end

local function buildPositionHead(widget)
  local L, ui, axis = widget.layout, widget.ui, widget.layout.axis
  local kind = (widget.barVisual and widget.barVisual.head) or "line"
  ui.headKind = kind
  if kind == "none" then return true end
  local outer = L.barOuter or L.bar
  local color = T.labelOn((widget.barPalette and widget.barPalette.normal)
                            or T.color.accent, widget.barPalette)
  local position = axis.start
  if kind == "line" then
    local cross1 = (axis.orientation == "vertical")
      and (outer.x - T.px(1)) or (outer.y - T.px(1))
    local cross2 = (axis.orientation == "vertical")
      and (outer.x + outer.w + T.px(1)) or (outer.y + outer.h + T.px(1))
    movingHead(ui, "head", axis, position, cross1, cross2, L.markThickness,
               color, T.opacity.full)
  elseif kind == "dot" then
    local radius = max(T.px(2), floor(axis.crossLength * 0.28))
    local cx = (axis.orientation == "vertical")
      and (outer.x + floor(outer.w / 2)) or position
    local cy = (axis.orientation == "vertical")
      and position or (outer.y + floor(outer.h / 2))
    ui.head = lvgl.circle{
      x = cx, y = cy, radius = radius, color = color, filled = 1,
      opacity = T.opacity.full,
    }
    ui.headSet = { [(axis.orientation == "vertical") and "y" or "x"] = position }
    lvgl.hide(ui.head)
  elseif kind == "cap" then
    local thick = max(T.px(3), L.markThickness)
    if axis.orientation == "vertical" then
      ui.head = lvgl.rectangle{
        x = outer.x, y = position - floor(thick / 2),
        w = outer.w, h = thick, color = color, filled = 1,
        rounded = floor(thick / 2), opacity = T.opacity.full,
      }
      ui.headSet = { y = position - floor(thick / 2) }
    else
      ui.head = lvgl.rectangle{
        x = position - floor(thick / 2), y = outer.y,
        w = thick, h = outer.h, color = color, filled = 1,
        rounded = floor(thick / 2), opacity = T.opacity.full,
      }
      ui.headSet = { x = position - floor(thick / 2) }
    end
    ui.headHalf = floor(thick / 2)
    lvgl.hide(ui.head)
  else -- needle: a compact direction pointer contained inside the rail body
    local half = max(T.px(2), floor(axis.crossLength * 0.3))
    local low, high = min(axis.start, axis.endCoord), max(axis.start, axis.endCoord)
    local p1, p2 = max(low, position - half), min(high, position + half)
    local pts
    if axis.orientation == "vertical" then
      pts = { { outer.x, p1 }, { outer.x, p2 },
              { outer.x + outer.w, position } }
    else
      pts = { { p1, outer.y }, { p2, outer.y },
              { position, outer.y + outer.h } }
    end
    ui.headPts, ui.headSet, ui.headHalf = pts, { pts = pts }, half
    ui.head = lvgl.triangle{
      pts = pts, color = color, opacity = T.opacity.full,
    }
    ui.headKind = "needle"
    lvgl.hide(ui.head)
  end
  return true
end

local function continuousBuildOverlay(widget)
  local ok = buildPositionHead(widget)
  -- Same rule as the segmented faces: pulse the exact-position head, never the
  -- fill. With Head = None there is nothing here to pulse and bar.lua falls
  -- back to the state pill.
  widget.ui.pulseTargets = widget.ui.head and { widget.ui.head } or nil
  return ok
end

local function moveHead(ui, key, axis, position)
  if not ui[key] then return end
  local kind = ui.headKind or "line"
  if kind == "dot" then
    local prop = (axis.orientation == "vertical") and "y" or "x"
    ui.headSet[prop] = position
    lvgl.set(ui[key], ui.headSet)
    lvgl.show(ui[key])
    return
  elseif kind == "cap" then
    local prop = (axis.orientation == "vertical") and "y" or "x"
    ui.headSet[prop] = position - ui.headHalf
    lvgl.set(ui[key], ui.headSet)
    lvgl.show(ui[key])
    return
  elseif kind == "needle" then
    local pts, half = ui.headPts, ui.headHalf
    local coordinate = (axis.orientation == "vertical") and 2 or 1
    local low, high = min(axis.start, axis.endCoord), max(axis.start, axis.endCoord)
    pts[1][coordinate], pts[2][coordinate], pts[3][coordinate] =
      max(low, position - half), min(high, position + half), position
    lvgl.set(ui[key], ui.headSet)
    lvgl.show(ui[key])
    return
  end
  local pts = ui[key .. "Pts"]
  local coordinate = (axis.orientation == "vertical") and 2 or 1
  pts[1][coordinate], pts[2][coordinate] = position, position
  lvgl.set(ui[key], ui[key .. "Set"])
  lvgl.show(ui[key])
end

local function showSlice(sdata, shown)
  if sdata.barShown == shown then return end
  sdata.barShown = shown
  if shown then lvgl.show(sdata.object) else lvgl.hide(sdata.object) end
end

local function hideGradient(objects)
  for i = 1, #objects.gradientSlices do
    showSlice(objects.sliceState[i], false)
  end
end

local function setSliceGeometry(widget, sdata, x, y, w, h)
  if widget.layout.axis.orientation == "vertical" then
    if y ~= sdata.paintY then
      sdata.paintY = y; R.setProp(widget, sdata.object, "y", y)
    end
    if h ~= sdata.paintH then
      sdata.paintH = h; R.setProp(widget, sdata.object, "h", h)
    end
  else
    if x ~= sdata.paintX then
      sdata.paintX = x; R.setProp(widget, sdata.object, "x", x)
    end
    if w ~= sdata.paintW then
      sdata.paintW = w; R.setProp(widget, sdata.object, "w", w)
    end
  end
end

-- Fast prefix path for the overwhelmingly common Scale-low origin. Only a
-- crossed slice boundary walks the pool; motion within a slice touches that
-- one slice. This preserves the Phase 4 ordinary-frame budget.
local function updateGradientPrefix(widget, objects, normalized)
  local slices, states = objects.gradientSlices, objects.sliceState
  local frame = widget.frame
  local axis = widget.layout.activeAxis or widget.layout.axis
  local vertical = axis.orientation == "vertical"
  local count = #slices
  local whole = (normalized >= 1) and count or floor(normalized * count)
  local current = (whole < count) and (whole + 1) or nil
  local oldWhole = frame.gradientWhole
  if whole ~= oldWhole then
    frame.gradientWhole = whole
    for i = 1, count do
      local sdata = states[i]
      if i <= whole then
        if vertical then
          if sdata.paintY ~= sdata.baseY then
            sdata.paintY = sdata.baseY
            R.setProp(widget, sdata.object, "y", sdata.baseY)
          end
          if sdata.paintH ~= sdata.baseH then
            sdata.paintH = sdata.baseH
            R.setProp(widget, sdata.object, "h", sdata.baseH)
          end
        else
          if sdata.paintW ~= sdata.baseW then
            sdata.paintW = sdata.baseW
            R.setProp(widget, sdata.object, "w", sdata.baseW)
          end
        end
        showSlice(sdata, true)
      elseif i == current and normalized > sdata.fromPosition then
        local position = pointAt(axis, normalized)
        local length
        if vertical then
          length = sdata.baseY + sdata.baseH - position
          if length > 0 then
            if position ~= sdata.paintY then
              sdata.paintY = position
              R.setProp(widget, sdata.object, "y", position)
            end
            if length ~= sdata.paintH then
              sdata.paintH = length
              R.setProp(widget, sdata.object, "h", length)
            end
          end
        else
          length = position - sdata.baseX
          if length > 0 and length ~= sdata.paintW then
            sdata.paintW = length
            R.setProp(widget, sdata.object, "w", length)
          end
        end
        if length > 0 then
          showSlice(sdata, true)
        else
          showSlice(sdata, false)
        end
      else
        showSlice(sdata, false)
      end
    end
  elseif current then
    local sdata = states[current]
    if normalized > sdata.fromPosition then
      local position = pointAt(axis, normalized)
      local length
      if vertical then
        length = sdata.baseY + sdata.baseH - position
        if length > 0 then
          if position ~= sdata.paintY then
            sdata.paintY = position
            R.setProp(widget, sdata.object, "y", position)
          end
          if length ~= sdata.paintH then
            sdata.paintH = length
            R.setProp(widget, sdata.object, "h", length)
          end
        end
      else
        length = position - sdata.baseX
        if length > 0 and length ~= sdata.paintW then
          sdata.paintW = length
          R.setProp(widget, sdata.object, "w", length)
        end
      end
      if length > 0 then
        showSlice(sdata, true)
      else
        showSlice(sdata, false)
      end
    else
      showSlice(sdata, false)
    end
  end
end

local function spanIndices(lo, hi, count)
  if hi <= lo then return nil, nil end
  local first = min(count, floor(lo * count) + 1)
  local last = max(1, min(count, ceil(hi * count)))
  return first, last
end

local function updateGradientIndex(widget, states, axis, index, lo, hi)
  if not index then return end
  local sdata = states[index]
  local a, b = max(lo, sdata.fromPosition), min(hi, sdata.toPosition)
  if b <= a then
    showSlice(sdata, false)
    return
  end
  local x, y, w, h = spanAt(axis, a, b)
  if w <= 0 or h <= 0 then
    showSlice(sdata, false)
    return
  end
  setSliceGeometry(widget, sdata, x, y, w, h)
  showSlice(sdata, true)
end

-- Retained arbitrary-span path for numeric-zero origin. The original version
-- rescanned every gradient slice on every frame. A centred stick only moves
-- two interval boundaries, so cache the old interval and touch the crossed
-- slices plus the old/new boundary slices. A full walk now happens only on
-- first paint or a genuine sign-crossing transition.
local function updateGradientSpan(widget, objects, fromT, toT)
  local slices, states = objects.gradientSlices, objects.sliceState
  local frame = widget.frame
  local axis = widget.layout.activeAxis or widget.layout.axis
  local lo, hi = fromT, toT
  if lo > hi then lo, hi = hi, lo end
  local first, last = spanIndices(lo, hi, #slices)
  local oldFirst, oldLast = frame.gradientFirst, frame.gradientLast

  if oldFirst and not first then
    for i = oldFirst, oldLast do showSlice(states[i], false) end
  elseif first and not oldFirst then
    for i = first, last do
      updateGradientIndex(widget, states, axis, i, lo, hi)
    end
  elseif first then
    if first > oldFirst then
      for i = oldFirst, min(first - 1, oldLast) do
        showSlice(states[i], false)
      end
    elseif first < oldFirst then
      for i = first, min(oldFirst - 1, last) do
        updateGradientIndex(widget, states, axis, i, lo, hi)
      end
    end
    if last < oldLast then
      for i = max(last + 1, oldFirst), oldLast do
        showSlice(states[i], false)
      end
    elseif last > oldLast then
      for i = max(oldLast + 1, first), last do
        updateGradientIndex(widget, states, axis, i, lo, hi)
      end
    end

    -- A former partial boundary becomes a full interior slice when its index
    -- changes. Restore it before painting the new partial boundary.
    if oldFirst ~= first and oldFirst >= first and oldFirst <= last then
      updateGradientIndex(widget, states, axis, oldFirst, lo, hi)
    end
    if oldLast ~= last and oldLast >= first and oldLast <= last then
      updateGradientIndex(widget, states, axis, oldLast, lo, hi)
    end
    updateGradientIndex(widget, states, axis, first, lo, hi)
    if last ~= first then
      updateGradientIndex(widget, states, axis, last, lo, hi)
    end
  end
  frame.gradientFirst, frame.gradientLast = first, last
  frame.gradientWhole = first and (last - first + 1) or 0
end

local function continuousUpdate(widget, objects, state)
  local frame = widget.frame
  if not state.visualValid then
    if frame.fillShown then
      frame.fillShown = false
      if objects.gradientSlices then
        hideGradient(objects)
        frame.gradientWhole = -1
      else
        lvgl.hide(objects.fill)
      end
      if objects.fillCap then lvgl.hide(objects.fillCap) end
    end
    if frame.headShown and objects.head then
      frame.headShown = false
      lvgl.hide(objects.head)
    end
    return
  end
  local axis = widget.layout.axis
  local active = widget.layout.activeAxis or axis
  local normalized = state.smoothNormalized
  local fromT, toT
  if normalized < axis.originT then
    fromT, toT = normalized, axis.originT
  else
    fromT, toT = axis.originT, normalized
  end
  local x, y, w, h = spanAt(active, fromT, toT)
  local length = (axis.orientation == "vertical") and h or w
  local shown = length > 0
  if shown ~= frame.fillShown then
    frame.fillShown = shown
    if shown then
      if not objects.gradientSlices then lvgl.show(objects.fill) end
      if objects.fillCap then lvgl.show(objects.fillCap) end
    else
      if objects.gradientSlices then
        hideGradient(objects)
        frame.gradientWhole = -1
      else
        lvgl.hide(objects.fill)
      end
      if objects.fillCap then lvgl.hide(objects.fillCap) end
    end
  end
  if objects.gradientSlices then
    if axis.prefixOrigin then
      updateGradientPrefix(widget, objects, normalized)
    else
      updateGradientSpan(widget, objects, fromT, toT)
    end
    frame.fillW = length
  else
    local start = (axis.orientation == "vertical") and y or x
    if start ~= frame.fillStart or length ~= frame.fillLength then
      frame.fillStart, frame.fillLength = start, length
      frame.fillW = length
      R.setProp(widget, objects.fill, "x", x)
      R.setProp(widget, objects.fill, "y", y)
      R.setProp(widget, objects.fill, "w", max(1, w))
      R.setProp(widget, objects.fill, "h", max(1, h))
    end
  end
  local position = pointAt(axis, normalized)
  if objects.head and position ~= frame.headPos then
    frame.headPos, frame.headX = position, position
    moveHead(objects, "head", axis, position)
    frame.headShown = true
  elseif objects.head and not frame.headShown then
    frame.headShown = true
    lvgl.show(objects.head)
  end
end

local function continuousPalette(widget, objects, palette, state)
  if state.paletteChanged then
    if objects.panel then R.setProp(widget, objects.panel, "color", palette.panel) end
    setShapeProp(widget, objects, "casing", "color", palette.border)
    setShapeProp(widget, objects, "track", "color", palette.track)
  end
  local assist = palette.assist
  local assisted = assist == "needed" or assist == "strong"
  local casingOpacity = assisted and T.opacity.full or T.opacity.railBand
  local trackOpacity = (assist == "strong") and T.opacity.railBand
    or assisted and min(T.opacity.full, T.opacity.rail + 60) or T.opacity.rail
  setShapeProp(widget, objects, "casing", "opacity", casingOpacity)
  setShapeProp(widget, objects, "track", "opacity", trackOpacity)
  if objects.rails then
    for i = 1, #objects.rails do
      local rail = objects.rails[i]
      local meta = objects.railMeta[i]
      R.setProp(widget, rail, "color",
                T.stateColor(meta.role, widget.accent, palette))
      R.setProp(widget, rail, "opacity",
                (state.colorKey == "muted") and T.opacity.muted
                  or meta.baseOpacity)
    end
  end
  local fill = state.visualColor or R.resolveColor(widget, state.colorKey, palette)
  if objects.gradientSlices then
    if state.paletteChanged then
      local sliceCount = #objects.gradientSlices
      local states = objects.sliceState
      for i = 1, #objects.gradientSlices do
        local slice = objects.gradientSlices[i]
        local sdata = states[i]
        if sdata.gradientT == nil then
          local sample = (i == 1) and 0
            or (i == sliceCount) and 1
            or ((sdata.fromPosition + sdata.toPosition) * 0.5)
          sdata.gradientT = M.gradientPosition(widget.config, sample)
        end
        local sliceColor
        if sdata.gradientT <= 0 then sliceColor = palette.critical
        elseif sdata.gradientT >= 1 then sliceColor = palette.normal
        elseif sdata.gradientT == 0.5 then sliceColor = palette.warning
        else sliceColor = T.paletteColor(palette, sdata.gradientT, 24) end
        R.setProp(widget, slice, "color",
                  sliceColor)
      end
    end
  else
    R.setProp(widget, objects.fill, "color", fill)
  end
  if state.opacity ~= widget.frame.faceOpacity then
    widget.frame.faceOpacity = state.opacity
    if objects.gradientSlices then
      for i = 1, #objects.gradientSlices do
        R.setProp(widget, objects.gradientSlices[i], "opacity", state.opacity)
      end
    else
      R.setProp(widget, objects.fill, "opacity", state.opacity)
    end
  end
  if objects.fillCap then
    local capColor = objects.gradientSlices
      and palette.critical
      or fill
    R.setProp(widget, objects.fillCap, "color", capColor)
    if state.opacity ~= widget.frame.fillCapOpacity then
      widget.frame.fillCapOpacity = state.opacity
      R.setProp(widget, objects.fillCap, "opacity", state.opacity)
    end
  end
  R.setProp(widget, objects.head, "color", T.labelOn(fill, palette))
  R.setProp(widget, objects.head, "opacity", state.opacity)
  local headThickness = widget.layout.markThickness
    + ((assist == "strong") and T.px(2) or assisted and T.px(1) or 0)
    + (((state.headBoost or 0) > 0) and T.px(state.headBoost) or 0)
  if objects.headKind == "line" then
    R.setProp(widget, objects.head, "thickness", headThickness)
  end
end

local function continuousVisible(objects, visible)
  local fn = visible and lvgl.show or lvgl.hide
  if objects.panel then fn(objects.panel) end
  showShape(objects, "casing", visible)
  showShape(objects, "track", visible)
  if objects.rails then for i = 1, #objects.rails do fn(objects.rails[i]) end end
  if objects.gradientSlices then
    if not visible then hideGradient(objects) end
  else
    fn(objects.fill)
  end
  if objects.fillCap then fn(objects.fillCap) end
  if objects.head then fn(objects.head) end
end

-- ------------------------------------------------------- segmented faces --

local function segmentedSupports(_profile, config)
  return not config or config.direction == nil
    or config.direction == "horizontal" or config.direction == "vertical"
end

-- Whole segments plus the truthful fraction of the current segment. Ticks
-- and Steps pass partial=false and use the exact retained head for precision.
function M.segmentProgress(count, normalized, partial)
  count = max(1, floor(tonumber(count) or 1))
  normalized = max(0, min(1, tonumber(normalized) or 0))
  if normalized >= 1 then return count, 0 end
  local scaled = normalized * count
  local whole = floor(scaled)
  return whole, partial and (scaled - whole) or 0
end

local function addDowngrade(style, reason)
  if not style or not style.downgrades then return end
  for i = 1, #style.downgrades do
    if style.downgrades[i] == reason then return end
  end
  style.downgrades[#style.downgrades + 1] = reason
end

function buildPanel(widget, style)
  if style.surface == "transparent" then return end
  local L, palette = widget.layout, widget.barPalette
  -- A panel the same colour as the screen behind it is an invisible object
  -- that still costs a build slot and a full-zone fill every frame. On the
  -- stock theme that is exactly what "Theme panel" was: palette.panel is
  -- COLOR_THEME_SECONDARY3, which IS the home screen's background. Give it a
  -- real edge instead of painting nothing - the border role is already in the
  -- palette and is the same one the casing uses.
  local color = (palette and palette.panel) or COLOR_THEME_SECONDARY3
  local backdrop = palette and palette.backdrop
  local rounded = min(T.px(8), floor(min(L.w, L.h) / 8))
  if backdrop and color == backdrop and style.surface ~= "custom" then
    widget.ui.panel = lvgl.rectangle{
      x = 0, y = 0, w = L.w, h = L.h,
      color = (palette and palette.border) or COLOR_THEME_SECONDARY1,
      opacity = T.opacity.rail, filled = 0, thickness = T.px(1),
      rounded = rounded,
    }
    return
  end
  widget.ui.panel = lvgl.rectangle{
    x = 0, y = 0, w = L.w, h = L.h,
    color = color,
    opacity = T.opacity.full, filled = 1,
    rounded = rounded,
  }
end

local function gapPixels(style)
  if style.gap == "wide" then return T.px(5) end
  if style.gap == "tight" then return T.px(2) end
  return T.px(3)
end

local function budgetedCount(widget, style, ceiling, perCell,
                              minimum, maximum, geometryCap)
  local fixed = 1 -- exact retained head
  if style.surface ~= "transparent" then fixed = fixed + 1 end
  local available = ceiling - gradientSharedObjects(widget) - fixed
  local budgetCap = max(1, floor(available / perCell))
  local requested = max(minimum, min(maximum, style.segments or minimum))
  local count = min(requested, budgetCap, geometryCap or maximum)
  count = max(1, count)
  if count < requested then addDowngrade(style, "segments-whole-tree-budget") end
  style.renderedSegments = count
  return count
end

local function slotGeometry(axis, index, count, gap)
  local t1, t2 = (index - 1) / count, index / count
  local x, y, w, h = G.axisSpan(axis, t1, t2)
  local length = (axis.orientation == "vertical") and h or w
  local trailing = (index < count) and min(gap, max(0, length - 1)) or 0
  if axis.orientation == "vertical" then
    -- The physical trailing edge for a bottom-to-top axis is its top edge.
    y, h = y + trailing, max(1, h - trailing)
  else
    w = max(1, w - trailing)
  end
  return x, y, w, h, t1, t2
end

local function roleBands(widget)
  local bands = {}
  for i = 1, #widget.ranges do
    local range = widget.ranges[i]
    local a = G.normalize(range.from, widget.config.min, widget.config.max)
    local b = G.normalize(range.to, widget.config.min, widget.config.max)
    if a > b then a, b = b, a end
    local n = #bands
    bands[n + 1], bands[n + 2], bands[n + 3] = a, b, range.role
  end
  return bands
end

local function roleAt(bands, position)
  for i = 1, #bands, 3 do
    if position >= bands[i]
       and (position < bands[i + 1] or i == #bands - 2) then
      return bands[i + 2]
    end
  end
  return "normal"
end

local function spatialColor(widget, palette, position)
  return R.spatialColor(widget.config, palette, position)
end

local function paintCell(cell, stateOpacity)
  local fraction = cell.fraction
  local active = fraction > 0
  local color = active and cell.activeColor or cell.referenceColor
  local base = cell.baseOpacity
  local opacity
  -- `fraction >= 1` / `not active`, never `== 1` / `== 0`: the firmware floors
  -- a float before comparing it with an integer literal, so `0.45 == 0` was
  -- true here and every PARTIAL cell painted itself as an inactive ghost
  -- (G.isZero documents the mechanism).
  if stateOpacity == T.opacity.full and fraction >= 1 then
    opacity = T.opacity.full
  elseif stateOpacity == T.opacity.full and not active then
    opacity = base
  else
    local logical = base + floor((T.opacity.full - base) * fraction + 0.5)
    opacity = floor(logical * stateOpacity / T.opacity.full + 0.5)
  end
  if cell.paintColor == color and cell.paintOpacity == opacity then return end
  cell.paintColor, cell.paintOpacity = color, opacity
  local props = cell.paintProps
  props.color, props.opacity = color, opacity
  -- Cell parts always change color and opacity together. Their retained
  -- two-key table avoids two renderer-cache walks per part and allocates
  -- nothing while a fast telemetry source moves.
  lvgl.set(cell.primary, props)
  if cell.parts then
    -- The only multipart cell is the true hex: center plus two tips.
    lvgl.set(cell.parts[2], props)
    lvgl.set(cell.parts[3], props)
  end
end

local function setCellFraction(cell, fraction, stateOpacity, force)
  -- Ordering, not equality: callers pass the integer 0/1 for the common ends
  -- and a float in between, and a mixed `==` floors on this firmware - so a
  -- cell holding 0.45 compared equal to an incoming 0 and the repaint was
  -- skipped. Two `<` are exact for every pair (see G.isZero).
  local held = cell.fraction
  if not force and held >= fraction and fraction >= held then return end
  cell.fraction = fraction
  paintCell(cell, stateOpacity)
end

local function baseOpacity(widget, cell, palette)
  local mode = widget.config.colorMode
  local opacity
  if mode == R.COLOR_RAIL and cell.role ~= "normal" then
    opacity = (cell.role == "critical")
      and T.opacity.railBandCrit or T.opacity.railBand
  elseif mode == R.COLOR_SECTIONS or mode == R.COLOR_GRADIENT then
    opacity = T.opacity.ghost
  else
    opacity = T.opacity.rail
  end
  if palette.assist == "strong" then
    opacity = max(28, floor(opacity * 0.55))
  elseif palette.assist == "needed" then
    opacity = max(36, floor(opacity * 0.75))
  end
  if cell.variant == "major" then
    opacity = max(opacity, T.opacity.tickMajor)
  elseif cell.variant == "minor" then
    opacity = max(opacity, T.opacity.tickMinor)
  end
  return opacity
end

local function colorsForCell(widget, cell, palette, fill)
  local mode = widget.config.colorMode
  local semantic = T.stateColor(cell.role, widget.accent, palette)
  if mode == R.COLOR_GRADIENT then
    local spatial = spatialColor(widget, palette, cell.position)
    return spatial, spatial
  elseif mode == R.COLOR_SECTIONS then
    return semantic, semantic
  elseif mode == R.COLOR_RAIL and cell.role ~= "normal" then
    return semantic, fill
  end
  return palette.track, fill
end

local function segmentedPalette(widget, objects, palette, state)
  local paletteChanged = objects.segmentPaletteSig ~= palette.signature
  local fill = state.visualColor or R.resolveColor(widget, state.colorKey, palette)
  local colorChanged = objects.segmentColor ~= fill
  objects.segmentPaletteSig = palette.signature
  objects.segmentColorKey = state.colorKey
  objects.segmentColor = fill
  if objects.panel and paletteChanged then
    R.setProp(widget, objects.panel, "color", palette.panel)
  end
  local stateColored = widget.config.colorMode ~= R.COLOR_GRADIENT
    and widget.config.colorMode ~= R.COLOR_SECTIONS
  -- The cell loop is the dominant ordinary-frame tax on true Hex (three LVGL
  -- primitives per cell). Palette and semantic fill are normally stable, so
  -- do not scan a retained array merely to take neither branch ten times.
  if paletteChanged or (colorChanged and stateColored) then
    for i = 1, #objects.faceCells do
      local cell = objects.faceCells[i]
      if paletteChanged then
        if not cell.role then
          cell.role = roleAt(objects.faceRoleBands, cell.position)
        end
        cell.referenceColor, cell.activeColor = colorsForCell(
          widget, cell, palette, fill)
        cell.baseOpacity = baseOpacity(widget, cell, palette)
      else
        cell.activeColor = fill
      end
    end
  end
  objects.repaintAll = paletteChanged
  objects.repaintActive = colorChanged and stateColored and not paletteChanged
  R.setProp(widget, objects.head, "color", T.labelOn(fill, palette))
  R.setProp(widget, objects.head, "opacity", state.opacity)
  local assisted = palette.assist == "needed" or palette.assist == "strong"
  local headThickness = widget.layout.markThickness
    + ((palette.assist == "strong") and T.px(2)
       or assisted and T.px(1) or 0)
    + (((state.headBoost or 0) > 0) and T.px(state.headBoost) or 0)
    + (((state.settleLevel or 0) > 0) and T.px(state.settleLevel) or 0)
  if objects.headKind == "line" then
    R.setProp(widget, objects.head, "thickness", headThickness)
  end
end

local function segmentedBuildOverlay(widget)
  local ui = widget.ui
  buildPositionHead(widget)
  -- Segments remain visible to provide their reference scale, so pulsing their
  -- opacity would destroy partial-cell and inactive-state truth. The exact
  -- head is the retained, color-independent critical pulse target.
  ui.pulseTargets = ui.head and { ui.head } or nil
  return true
end

local function updatePartialIndex(cells, index, lo, hi, stateOpacity)
  local cell = cells[index]
  local a, b = max(lo, cell.fromPosition), min(hi, cell.toPosition)
  local fraction = (b > a) and ((b - a)
    / (cell.toPosition - cell.fromPosition)) or 0
  setCellFraction(cell, fraction, stateOpacity)
end

local function updatePartialCells(widget, objects, normalized, stateOpacity)
  local cells, frame = objects.faceCells, widget.frame
  local axis = widget.layout.axis
  if axis.prefixOrigin then
    local scaled = normalized * #cells
    local whole = (normalized >= 1) and #cells or floor(scaled)
    local partial = (whole < #cells) and (scaled - whole) or 0
    local oldWhole = frame.segmentWhole
    if oldWhole == nil then
      for i = 1, #cells do
        local fraction = (i <= whole) and 1
          or (i == whole + 1) and partial or 0
        setCellFraction(cells[i], fraction, stateOpacity)
      end
    elseif whole > oldWhole then
      for i = oldWhole + 1, whole do
        setCellFraction(cells[i], 1, stateOpacity)
      end
    elseif whole < oldWhole then
      local last = min(#cells, oldWhole + 1)
      for i = whole + 2, last do
        setCellFraction(cells[i], 0, stateOpacity)
      end
    end
    if whole < #cells then
      setCellFraction(cells[whole + 1], partial, stateOpacity)
    end
    frame.segmentWhole = whole
    return
  end
  local lo, hi = normalized, axis.originT
  if lo > hi then lo, hi = hi, lo end
  local first, last = spanIndices(lo, hi, #cells)
  local oldFirst, oldLast = frame.segmentFirst, frame.segmentLast
  if oldFirst and not first then
    for i = oldFirst, oldLast do setCellFraction(cells[i], 0, stateOpacity) end
  elseif first and not oldFirst then
    for i = first, last do
      updatePartialIndex(cells, i, lo, hi, stateOpacity)
    end
  elseif first then
    if first > oldFirst then
      for i = oldFirst, min(first - 1, oldLast) do
        setCellFraction(cells[i], 0, stateOpacity)
      end
    elseif first < oldFirst then
      for i = first, min(oldFirst - 1, last) do
        updatePartialIndex(cells, i, lo, hi, stateOpacity)
      end
    end
    if last < oldLast then
      for i = max(last + 1, oldFirst), oldLast do
        setCellFraction(cells[i], 0, stateOpacity)
      end
    elseif last > oldLast then
      for i = max(oldLast + 1, first), last do
        updatePartialIndex(cells, i, lo, hi, stateOpacity)
      end
    end
    if oldFirst ~= first and oldFirst >= first and oldFirst <= last then
      updatePartialIndex(cells, oldFirst, lo, hi, stateOpacity)
    end
    if oldLast ~= last and oldLast >= first and oldLast <= last then
      updatePartialIndex(cells, oldLast, lo, hi, stateOpacity)
    end
    updatePartialIndex(cells, first, lo, hi, stateOpacity)
    if last ~= first then
      updatePartialIndex(cells, last, lo, hi, stateOpacity)
    end
  end
  frame.segmentFirst, frame.segmentLast = first, last
  frame.segmentWhole = first and (last - first + 1) or 0
end

local function updatePointCells(widget, objects, normalized, stateOpacity)
  local cells, frame = objects.faceCells, widget.frame
  local axis = widget.layout.axis
  if axis.prefixOrigin then
    local active = frame.segmentActive or 0
    while active < #cells and normalized >= cells[active + 1].position do
      active = active + 1
      setCellFraction(cells[active], 1, stateOpacity)
    end
    while active > 0 and normalized < cells[active].position do
      setCellFraction(cells[active], 0, stateOpacity)
      active = active - 1
    end
    frame.segmentActive = active
    return
  end
  local active = 0
  local lo, hi = G.axisOriginSpan(axis, normalized)
  local hasSpan = hi > lo
  for i = 1, #cells do
    local position = cells[i].position
    local on = hasSpan and position >= lo and position <= hi
    if on then active = active + 1 end
    setCellFraction(cells[i], on and 1 or 0, stateOpacity)
  end
  frame.segmentActive = active
end

local function updateWholeCells(widget, objects, normalized, stateOpacity)
  local cells, frame = objects.faceCells, widget.frame
  if widget.layout.axis.prefixOrigin then
    local whole = (normalized >= 1) and #cells or floor(normalized * #cells)
    local oldWhole = frame.segmentWhole or 0
    if whole > oldWhole then
      for i = oldWhole + 1, whole do
        setCellFraction(cells[i], 1, stateOpacity)
      end
    elseif whole < oldWhole then
      for i = oldWhole, whole + 1, -1 do
        setCellFraction(cells[i], 0, stateOpacity)
      end
    end
    frame.segmentWhole = whole
    return
  end
  updatePointCells(widget, objects, normalized, stateOpacity)
  frame.segmentWhole = frame.segmentActive
end

local function segmentedUpdate(widget, objects, state)
  local cells, frame = objects.faceCells, widget.frame
  local opacityChanged = frame.segmentOpacity ~= state.opacity
  frame.segmentOpacity = state.opacity
  if not state.visualValid then
    for i = 1, #cells do
      setCellFraction(cells[i], 0, state.opacity)
    end
    if objects.repaintAll or opacityChanged then
      for i = 1, #cells do paintCell(cells[i], state.opacity) end
    end
    objects.repaintAll, objects.repaintActive = false, false
    frame.segmentWhole, frame.segmentActive = 0, 0
    if frame.headShown and objects.head then
      frame.headShown = false
      lvgl.hide(objects.head)
    end
    return
  end

  local normalized = state.smoothNormalized
  if objects.activation == "partial" then
    updatePartialCells(widget, objects, normalized, state.opacity)
  elseif objects.activation == "points" then
    updatePointCells(widget, objects, normalized, state.opacity)
  else -- whole increasing steps
    updateWholeCells(widget, objects, normalized, state.opacity)
  end

  if objects.repaintAll or opacityChanged then
    for i = 1, #cells do paintCell(cells[i], state.opacity) end
  elseif objects.repaintActive then
    for i = 1, #cells do
      if (cells[i].fraction or 0) > 0 then
        paintCell(cells[i], state.opacity)
      end
    end
  end
  objects.repaintAll, objects.repaintActive = false, false

  local axis = widget.layout.axis
  local position = pointAt(axis, normalized)
  if objects.head and position ~= frame.headPos then
    frame.headPos, frame.headX = position, position
    moveHead(objects, "head", axis, position)
    frame.headShown = true
  elseif objects.head and not frame.headShown then
    frame.headShown = true
    lvgl.show(objects.head)
  end
end

local function segmentedVisible(objects, visible)
  local fn = visible and lvgl.show or lvgl.hide
  if objects.panel then fn(objects.panel) end
  for i = 1, #objects.faceCells do
    local cell = objects.faceCells[i]
    if cell.parts then
      for j = 1, #cell.parts do fn(cell.parts[j]) end
    else
      fn(cell.primary)
    end
  end
  if objects.head then fn(objects.head) end
end

local function beginSegmented(widget, style, kind)
  buildPanel(widget, style)
  local ui = widget.ui
  ui.faceKind = kind
  ui.faceCells = {}
  ui.faceCells.paintProps = {}
  ui.faceRoleBands = roleBands(widget)
  return widget.layout.axis, ui.faceCells,
    ui.faceRoleBands
end

local function appendCell(cells, primary, parts, position, role, variant,
                          fromPosition, toPosition)
  local cell = {
    primary = primary, parts = parts, position = position, role = role,
    fraction = 0, baseOpacity = T.opacity.rail,
    referenceColor = T.color.rail, activeColor = T.color.accent,
    variant = variant, paintProps = cells.paintProps,
    fromPosition = fromPosition, toPosition = toPosition,
  }
  cells[#cells + 1] = cell
  return cell
end

local function blocksBuild(widget, _geometry, style)
  local axis, cells = beginSegmented(widget, style, "blocks")
  local gap = gapPixels(style)
  local minCell = T.px(3)
  local geometryCap = max(6, floor((axis.length + gap) / (minCell + gap)))
  local count = budgetedCount(widget, style, 38, 1, 6, 24, geometryCap)
  local radius = (style.ends == "round")
    and min(T.px(3), floor(axis.crossLength / 3)) or 0
  local variant = (radius > 0) and "soft" or "square"
  for i = 1, count do
    local x, y, w, h, t1, t2 = slotGeometry(axis, i, count, gap)
    local rect = lvgl.rectangle{
      x = x, y = y, w = w, h = h,
      color = widget.barPalette.track, opacity = T.opacity.rail,
      filled = 1, rounded = radius,
    }
    local position = (i - 0.5) / count
    appendCell(cells, rect, nil, position, nil, variant, t1, t2)
  end
  widget.ui.fill = cells[1] and cells[1].primary or nil
  widget.ui.activation = "partial"
  return true
end

local function hexBuild(widget, _geometry, style)
  local axis, cells = beginSegmented(widget, style, "hex")
  local gap = gapPixels(style)
  local tip = min(floor(axis.crossLength / 2), T.px(6))
  local compactBlock = tip < T.px(2) or axis.crossLength < T.px(5)
  local perCell = compactBlock and 1 or 3
  local minimumWidth = compactBlock and T.px(3) or (tip * 2 + T.px(2))
  local geometryCap = max(6, floor((axis.length + gap) / (minimumWidth + gap)))
  local count = budgetedCount(widget, style, 40, perCell, 6, 10, geometryCap)
  if compactBlock then
    style.faceVariant = "blocks-compact"
    addDowngrade(style, "hex-compact-blocks")
  else
    style.faceVariant = "true-hex"
  end
  for i = 1, count do
    local x, y, w, h, t1, t2 = slotGeometry(axis, i, count, gap)
    local position = (i - 0.5) / count
    local primary = (axis.orientation == "vertical") and h or w
    if compactBlock or primary < tip * 2 + 1 then
      local rect = lvgl.rectangle{
        x = x, y = y, w = w, h = h,
        color = widget.barPalette.track, opacity = T.opacity.rail,
        filled = 1, rounded = 0,
      }
      appendCell(cells, rect, nil, position, nil, "block", t1, t2)
      style.faceVariant = "blocks-compact"
    else
      local localTip = min(tip, floor((primary - 1) / 2))
      local center, first, second
      if axis.orientation == "vertical" then
        local centerY = y + localTip
        local centerH = max(1, h - localTip * 2)
        center = lvgl.rectangle{
          x = x, y = centerY, w = w, h = centerH,
          color = widget.barPalette.track, opacity = T.opacity.rail,
          filled = 1, rounded = 0,
        }
        local midX = x + floor(w / 2)
        first = lvgl.triangle{
          pts = { { x, centerY }, { midX, y }, { x + w, centerY } },
          color = widget.barPalette.track, opacity = T.opacity.rail,
        }
        local bottomY = centerY + centerH
        second = lvgl.triangle{
          pts = { { x, bottomY }, { x + w, bottomY }, { midX, y + h } },
          color = widget.barPalette.track, opacity = T.opacity.rail,
        }
      else
        local centerX = x + localTip
        local centerW = max(1, w - localTip * 2)
        center = lvgl.rectangle{
          x = centerX, y = y, w = centerW, h = h,
          color = widget.barPalette.track, opacity = T.opacity.rail,
          filled = 1, rounded = 0,
        }
        local midY = y + floor(h / 2)
        first = lvgl.triangle{
          pts = { { centerX, y }, { centerX, y + h }, { x, midY } },
          color = widget.barPalette.track, opacity = T.opacity.rail,
        }
        local rightX = centerX + centerW
        second = lvgl.triangle{
          pts = { { rightX, y }, { x + w, midY }, { rightX, y + h } },
          color = widget.barPalette.track, opacity = T.opacity.rail,
        }
      end
      appendCell(cells, center, { center, first, second }, position, nil,
                 "hex", t1, t2)
    end
  end
  widget.ui.fill = cells[1] and cells[1].primary or nil
  widget.ui.activation = "partial"
  return true
end

local function thresholdTicks(widget, count)
  local forced = {}
  for i = 1, #widget.ranges do
    local range = widget.ranges[i]
    local position = G.normalize(range.to, widget.config.min, widget.config.max)
    if position > 0 and position < 1 then
      local index = floor(position * (count - 1) + 1.5)
      index = max(2, min(count - 1, index))
      forced[index] = { position = position, role = range.role }
    end
  end
  return forced
end

local function ticksBuild(widget, _geometry, style)
  local axis, cells = beginSegmented(widget, style, "ticks")
  local geometryCap = max(8, floor(axis.length / T.px(4)) + 1)
  local count = budgetedCount(widget, style, 40, 1, 8, 28, geometryCap)
  local forced = thresholdTicks(widget, count)
  local thickness = max(2, T.px(2))
  for i = 1, count do
    local info = forced[i]
    local position = info and info.position or ((i - 1) / (count - 1))
    local major = info ~= nil or i == 1 or i == count or ((i - 1) % 5 == 0)
    local cross = major and axis.crossLength
      or max(1, floor(axis.crossLength * 0.65))
    local point = G.axisPoint(axis, position)
    local x, y, w, h
    if axis.orientation == "vertical" then
      x, w = axis.x + axis.w - cross, cross
      y = max(axis.y, min(axis.y + axis.h - thickness,
                          point - floor(thickness / 2)))
      h = thickness
    else
      x = max(axis.x, min(axis.x + axis.w - thickness,
                          point - floor(thickness / 2)))
      y, w, h = axis.y + axis.h - cross, thickness, cross
    end
    local rect = lvgl.rectangle{
      x = x, y = y, w = w, h = h,
      color = widget.barPalette.track, opacity = T.opacity.rail,
      filled = 1, rounded = major and 1 or 0,
    }
    local half = 0.5 / count
    local cell = appendCell(cells, rect, nil, position, nil,
      major and "major" or "minor", max(0, position - half),
      min(1, position + half))
    cell.major, cell.centerX = major, point
    cell.thresholdRole = info and info.role or nil
  end
  widget.ui.fill = cells[1] and cells[1].primary or nil
  widget.ui.activation = "points"
  return true
end

local function stepsBuild(widget, _geometry, style)
  local axis, cells = beginSegmented(widget, style, "steps")
  local gap = gapPixels(style)
  local geometryCap = max(5, floor((axis.length + gap) / (T.px(4) + gap)))
  local count = budgetedCount(widget, style, 32, 1, 5, 10, geometryCap)
  -- The staircase rises to the full cross-height, but its FIRST steps have to
  -- stay readable: interpolating from 1 px left a 2 px active green beside a
  -- 15 px inactive track - the data channel rendered thinner than the thing it
  -- is drawn over. Start the ramp at a floor instead. The floor yields to the
  -- staircase itself when the rail is too shallow to give every step its own
  -- pixel, so the shape never stalls into two equal steps.
  local rise = max(1, count - 1)
  local ceiling = max(1, axis.crossLength)
  -- The floor wins over strict monotonicity. A rail with fewer pixels than
  -- steps cannot give each one its own height, and the old ramp resolved that
  -- by starting at 1 px: on a real 800x480 radio the first active steps came
  -- out 2 px of green beside 15 px of inactive track, so the data channel was
  -- the faintest thing in the widget. Repeating a height at the bottom is a
  -- far smaller lie than drawing the reading as a hairline - the staircase
  -- still rises, it just starts from something you can see.
  local floorCross = min(max(T.px(3), 1), ceiling)
  for i = 1, count do
    local x, y, w, h, t1, t2 = slotGeometry(axis, i, count, gap)
    local cross = floorCross + floor((ceiling - floorCross) * (i - 1) / rise)
    if axis.orientation == "vertical" then
      x, w = axis.x + floor((axis.w - cross) / 2), cross
    else
      y, h = axis.y + axis.h - cross, cross
    end
    local position = (i - 0.5) / count
    local rect = lvgl.rectangle{
      x = x, y = y, w = w, h = h,
      color = widget.barPalette.track, opacity = T.opacity.rail,
      filled = 1, rounded = min(T.px(2), floor(w / 3)),
    }
    appendCell(cells, rect, nil, position, nil, "step", t1, t2)
  end
  widget.ui.fill = cells[1] and cells[1].primary or nil
  widget.ui.activation = "steps"
  return true
end

-- ---------------------------------------------------------- centred rail --

local function dualSupports(_profile, config)
  return (not config or config.direction == nil
      or config.direction == "horizontal" or config.direction == "vertical")
    and (not config or config.origin == nil or config.origin == "zero")
end

local function dualBuild(widget, _geometry, style)
  buildPanel(widget, style)
  local L, ui, palette = widget.layout, widget.ui, widget.barPalette
  local axis, active = L.axis, L.activeAxis or L.axis
  local radius = (style.ends == "round") and floor(axis.crossLength / 2) or 0
  ui.faceKind = "dual-rail"
  ui.dualTracks = {}
  for i = 1, 2 do
    local fromT, toT = (i == 1) and 0 or axis.originT,
      (i == 1) and axis.originT or 1
    local x, y, w, h = G.axisSpan(axis, fromT, toT)
    -- Both halves are TRACK, exactly like every other face's inactive body.
    -- They used to take palette.critical / palette.normal, so a stick pushed
    -- to +65 % still showed a full-length saturated red bar on the negative
    -- half - and under contrast assist that rail reached 59 % opacity, at
    -- which point it is indistinguishable from a filled negative reading.
    -- The sign is already carried by which side of the zero notch the fill
    -- grows from; it does not need a second, contradictory channel.
    local track = lvgl.rectangle{
      x = x, y = y, w = max(1, w), h = max(1, h),
      color = palette.track,
      opacity = T.opacity.rail, filled = 1, rounded = radius,
    }
    ui.dualTracks[i] = track
  end
  local x, y, w, h = G.axisSpan(active, active.originT, active.originT)
  ui.fill = lvgl.rectangle{
    x = x, y = y, w = max(1, w), h = max(1, h),
    color = palette.normal, filled = 1,
    rounded = (style.ends == "round") and floor(active.crossLength / 2) or 0,
  }
  lvgl.hide(ui.fill)
  return true
end

local function dualPalette(widget, objects, palette, state)
  if objects.panel and state.paletteChanged then
    R.setProp(widget, objects.panel, "color", palette.panel)
  end
  local assisted = palette.assist == "needed" or palette.assist == "strong"
  local trackOpacity = (palette.assist == "strong") and T.opacity.railBand
    or assisted and min(T.opacity.full, T.opacity.rail + 60) or T.opacity.rail
  for i = 1, #objects.dualTracks do
    local track = objects.dualTracks[i]
    R.setProp(widget, track, "color", palette.track)
    R.setProp(widget, track, "opacity", trackOpacity)
  end
  local negative = state.smoothValue ~= nil and state.smoothValue < 0
  local fill = negative and palette.critical or palette.normal
  R.setProp(widget, objects.fill, "color", fill)
  R.setProp(widget, objects.fill, "opacity", state.opacity)
  R.setProp(widget, objects.head, "color", T.labelOn(fill, palette))
  R.setProp(widget, objects.head, "opacity", state.opacity)
  local thickness = widget.layout.markThickness
    + ((palette.assist == "strong") and T.px(2)
       or assisted and T.px(1) or 0)
    + (((state.headBoost or 0) > 0) and T.px(state.headBoost) or 0)
  if objects.headKind == "line" then
    R.setProp(widget, objects.head, "thickness", thickness)
  end
end

local function dualUpdate(widget, objects, state)
  local negative = state.smoothValue ~= nil and state.smoothValue < 0
  if negative ~= widget.frame.dualNegative then
    widget.frame.dualNegative = negative
    local palette = widget.barPalette
    local fill = negative and palette.critical or palette.normal
    R.setProp(widget, objects.fill, "color", fill)
    R.setProp(widget, objects.head, "color", T.labelOn(fill, palette))
  end
  continuousUpdate(widget, objects, state)
end

local function dualVisible(objects, visible)
  local fn = visible and lvgl.show or lvgl.hide
  if objects.panel then fn(objects.panel) end
  for i = 1, #objects.dualTracks do fn(objects.dualTracks[i]) end
  fn(objects.fill)
  if objects.head then fn(objects.head) end
end

local function descriptor(name, targetLow, targetHigh, hardCeiling, estimate)
  return {
    name = name,
    implemented = false,
    targetObjects = { targetLow, targetHigh },
    hardCeiling = hardCeiling,
    supports = unavailableSupports,
    estimateObjects = estimate,
    build = unavailableBuild,
    buildOverlay = unavailableBuild,
    update = unavailableUpdate,
    applyPalette = unavailablePalette,
    setVisible = unavailableVisible,
    ownsAlerts = false,
  }
end

local REGISTRY = {
  continuous = descriptor("continuous", 12, 38, 38, continuousEstimate),
  blocks = descriptor("blocks", 16, 32, 38,
    function(_profile, config) return min(config.segments or 10, 24) + 12 end),
  hex = descriptor("hex", 22, 35, 40,
    function(_profile, config) return min(config.segments or 8, 10) * 3 + 10 end),
  ticks = descriptor("ticks", 18, 34, 40,
    function(_profile, config) return min(config.segments or 20, 28) + 12 end),
  steps = descriptor("steps", 12, 24, 32,
    function(_profile, config) return min(config.segments or 8, 10) + 12 end),
  ["dual-rail"] = descriptor("dual-rail", 16, 28, 36,
    function() return 18 end),
}

local continuous = REGISTRY.continuous
continuous.variantCeilings = { solid = 24, gradient = 38 }
continuous.implemented = true
continuous.supports = continuousSupports
continuous.build = continuousBuild
continuous.buildOverlay = continuousBuildOverlay
continuous.update = continuousUpdate
continuous.applyPalette = continuousPalette
continuous.setVisible = continuousVisible

local function installSegmented(face, build)
  face.implemented = true
  face.supports = segmentedSupports
  face.build = build
  face.buildOverlay = segmentedBuildOverlay
  face.update = segmentedUpdate
  face.applyPalette = segmentedPalette
  face.setVisible = segmentedVisible
end

installSegmented(REGISTRY.blocks, blocksBuild)
installSegmented(REGISTRY.hex, hexBuild)
installSegmented(REGISTRY.ticks, ticksBuild)
installSegmented(REGISTRY.steps, stepsBuild)

local dual = REGISTRY["dual-rail"]
dual.implemented = true
dual.supports = dualSupports
dual.build = dualBuild
dual.buildOverlay = continuousBuildOverlay
dual.update = dualUpdate
dual.applyPalette = dualPalette
dual.setVisible = dualVisible

M.REGISTRY = REGISTRY
M.ORDER = { "continuous", "blocks", "hex", "ticks", "steps", "dual-rail" }

-- Selecting a later-phase face during this milestone is safe and
-- explicit: the requested face remains in barVisual/signatures, while the
-- retained Continuous adapter draws the production fallback.
function M.select(name, profile, config)
  local requested = REGISTRY[name]
  if requested and requested.supports(profile, config) then
    return requested, nil
  end
  return continuous, "face-phase-pending:" .. tostring(name or "unknown")
end

-- Allocate the shared face input once at build. Ordinary refresh only edits
-- scalar fields and the existing threshold array.
function M.buildRenderState(widget)
  local state = {
    valid = false, availability = "unset", state = "muted",
    visualValid = false,
    rawValue = nil, smoothValue = nil, rawNormalized = 0,
    smoothNormalized = 0, minNormalized = nil, maxNormalized = nil,
    colorKey = "muted", visualColor = nil,
    rawOpacity = T.opacity.muted, opacity = T.opacity.muted,
    pulseMode = "off", motionActive = false, motionPaused = false,
    settleEnabled = false, settleIndex = nil, settleLevel = 0, headBoost = 0,
    thresholds = {},
  }
  for i = 1, #widget.ranges do
    local range = widget.ranges[i]
    state.thresholds[i] = {
      role = range.role,
      fromPosition = G.normalize(range.from, widget.config.min,
                                 widget.config.max),
      toPosition = G.normalize(range.to, widget.config.min, widget.config.max),
      position = G.normalize(range.to, widget.config.min, widget.config.max),
    }
  end
  widget.barRenderState = state
  return state
end

function M.updateRenderState(widget)
  local state = widget.barRenderState
  local data, cfg, frame = widget.data, widget.config, widget.frame
  state.availability = data.availability
  state.state = R.stateKey(widget)
  state.colorKey = R.colorKey(widget)
  state.rawOpacity = (state.colorKey == "muted") and T.opacity.muted
                     or T.opacity.full
  state.opacity = state.rawOpacity
  state.rawValue = data.displayValue
  state.valid = data.availability == "valid" and data.displayValue ~= nil
  state.visualValid = state.valid
  if not state.valid then
    widget.smooth.value = nil
    state.smoothValue = nil
    state.rawNormalized, state.smoothNormalized = 0, 0
  else
    if frame.prevAvail ~= "valid" then widget.smooth.value = nil end
    state.smoothValue = widget.mods.smoothing.step(widget, data.displayValue)
    state.rawNormalized = G.normalize(data.displayValue, cfg.min, cfg.max)
    state.smoothNormalized = G.normalize(state.smoothValue, cfg.min, cfg.max)
  end
  local history = widget.history
  state.minNormalized = history.min
    and G.normalize(history.min, cfg.min, cfg.max) or nil
  state.maxNormalized = history.max
    and G.normalize(history.max, cfg.min, cfg.max) or nil
  return state
end

return M
