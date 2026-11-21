---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - geometry helpers (pure Lua, no firmware dependencies)      #
---- #                                                                       #
---- # Angle convention matches LVGL: 0 deg = 3 o'clock, angles increase     #
---- # clockwise (screen y points down).                                     #
---- #                                                                       #
---- # Point tables are {x, y} pairs - the exact format the EdgeTX binding   #
---- # reads (LvglWidgetLine::getPt uses rawgeti(pt,1)/rawgeti(pt,2)); named  #
---- # {x = ...} points fail on the radio.                                   #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local floor = math.floor
local cos = math.cos
local sin = math.sin
local rad = math.pi / 180

function M.clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

-- Position of `value` inside [minimum, maximum] as 0..1.
-- Inverted ranges (minimum > maximum) are mirrored rather than swapped, so a
-- descending scale (e.g. 0 at the right) maps correctly - the official C++
-- gauge's "value - min - max" transform is degenerate for asymmetric ranges.
function M.normalize(value, minimum, maximum)
  if maximum == minimum then return 0 end
  local t = (value - minimum) / (maximum - minimum)
  -- NaN survives clamp() untouched - neither `t < 0` nor `t > 1` is true of
  -- it - and every angle and bar width on the widget is derived from this
  -- one function, so a single NaN here reaches lvgl.set as a non-integer
  -- and raises on the radio. telemetry.refresh rejects non-finite READINGS
  -- at the gate; this catches a NaN arriving from anywhere else (a degenerate
  -- min/max pair, a caller passing a computed bound).
  if t ~= t then return 0 end
  return M.clamp(t, 0, 1)
end

function M.valueToAngle(value, minimum, maximum, startAngle, sweepAngle)
  return startAngle + M.normalize(value, minimum, maximum) * sweepAngle
end

function M.pointOnCircle(cx, cy, radius, angle)
  local a = angle * rad
  return cx + radius * cos(a), cy + radius * sin(a)
end

-- Radial line from r1 to r2 at `angle`.
function M.linePoints(cx, cy, r1, r2, angle)
  local x1, y1 = M.pointOnCircle(cx, cy, r1, angle)
  local x2, y2 = M.pointOnCircle(cx, cy, r2, angle)
  return { { x1, y1 }, { x2, y2 } }
end

-- Same line, written INTO a caller-owned buffer instead of allocating:
-- the binding copies the values out on every set (LvglWidgetLine::getPts,
-- lua_lvgl_widget.cpp:1008-1029) and retains no reference to the Lua table,
-- so mutating a reused buffer is legal and removes the per-frame allocation
-- the needle's three segments made (Tanda 6 F-11 / Phase 5.1). The buffer
-- must keep #buf == 2 (lua_rawlen drives getPts).
function M.linePointsInto(buf, cx, cy, r1, r2, angle)
  local x1, y1 = M.pointOnCircle(cx, cy, r1, angle)
  local x2, y2 = M.pointOnCircle(cx, cy, r2, angle)
  buf[1][1], buf[1][2] = x1, y1
  buf[2][1], buf[2][2] = x2, y2
  return buf
end

M.tickPoints = M.linePoints

-- Horizontal bar fill width for the linear (Bar) style.
function M.barFill(width, value, minimum, maximum)
  return floor(width * M.normalize(value, minimum, maximum) + 0.5)
end

-- NEVER compare a fractional number with `== 0` or `== 1` on this firmware.
--
-- EdgeTX builds Lua with `LUA_FLOORN2I 1` (radio/src/thirdparty/Lua/src/
-- luaconf.h:164) so its API can take unrounded floats where an integer is
-- required. That macro is also what `luaV_equalobj` uses for a float/integer
-- pair (lvm.c:404), so on the radio - and ONLY on the radio, never in the
-- pure-Lua harness -
--
--     0.45 == 0    --> true
--     1.75 == 1    --> true
--     0.45 == 0.0  --> false   (float/float is exact)
--     0.45 > 0     --> true    (ordering converts int->float, also exact)
--
-- Equality against a FLOAT literal and every inequality are safe; equality
-- against an INTEGER literal silently floors. Use `> 0` / `>= 1`, or a
-- boolean resolved once, as below. This cost the zero-origin bar option and
-- every partial segment before it was found; see
-- docs/visual-kit/INFORME-BAR-DIAL-2026-08-11.md.
function M.isZero(n)
  return n <= 0 and n >= 0
end

-- Orientation-neutral authored-scale axis. The descriptor is allocated once
-- during layout and then reused by every body, threshold, head and history
-- overlay. `start` is always the physical position of normalized 0: left for
-- horizontal bars and bottom for vertical bars. Vertical therefore grows with
-- -1 in screen coordinates while preserving the same normalized scale model.
function M.makeAxis(rect, orientation, minimum, maximum, origin)
  local vertical = orientation == "vertical"
  local length = vertical and rect.h or rect.w
  local start = vertical and (rect.y + rect.h) or rect.x
  local growth = vertical and -1 or 1
  local zeroInside = (minimum <= 0 and maximum >= 0)
    or (maximum <= 0 and minimum >= 0)
  local zeroT = M.normalize(0, minimum, maximum)
  local wantsZero = origin == "zero"
  local originT = wantsZero and zeroT or 0
  local axis = {
    orientation = vertical and "vertical" or "horizontal",
    x = rect.x, y = rect.y, w = rect.w, h = rect.h,
    start = start, length = length, growth = growth,
    crossStart = vertical and rect.x or rect.y,
    crossLength = vertical and rect.w or rect.h,
    scaleLowT = 0, zeroT = zeroT, zeroInside = zeroInside,
    origin = wantsZero and "zero" or "scale-low",
    originT = originT,
    -- Resolved ONCE, as a boolean, because every face asks this question on
    -- every frame and `originT == 0` is exactly the comparison the firmware
    -- gets wrong (see M.isZero). True means the fill is a prefix from the
    -- scale low end, which is also where a clamped zero origin lands.
    prefixOrigin = M.isZero(originT),
    originClamped = wantsZero and not zeroInside or false,
  }
  axis.endCoord = start + growth * length
  axis.originCoord = start + growth * floor(length * originT + 0.5)
  axis.zeroCoord = start + growth * floor(length * zeroT + 0.5)
  return axis
end

function M.axisPoint(axis, normalized)
  normalized = M.clamp(tonumber(normalized) or 0, 0, 1)
  return axis.start + axis.growth * floor(axis.length * normalized + 0.5)
end

-- Return a retained-rectangle-compatible x, y, w, h span between two
-- normalized authored-scale positions. Either order is accepted, which is
-- what lets a zero-origin value cross sign without face-local swapping.
function M.axisSpan(axis, fromPosition, toPosition)
  local p1 = M.axisPoint(axis, fromPosition)
  local p2 = M.axisPoint(axis, toPosition)
  if p1 > p2 then p1, p2 = p2, p1 end
  if axis.orientation == "vertical" then
    return axis.x, p1, axis.w, p2 - p1
  end
  return p1, axis.y, p2 - p1, axis.h
end

function M.axisOriginSpan(axis, normalized)
  normalized = M.clamp(tonumber(normalized) or 0, 0, 1)
  if normalized < axis.originT then return normalized, axis.originT end
  return axis.originT, normalized
end

function M.round(n)
  return floor(n + 0.5)
end

-- M.rayBoxEntry (slab-method ray/box intersection) lived here until Tanda 7.
-- Its only caller was renderer.needleReach, which shortened the needle so it
-- would not be drawn through the state chip - work the paint order already
-- does, since the chip is opaque and created after the needle. Both went
-- together; see the comment above updateArc in dial_renderer.lua.

return M
