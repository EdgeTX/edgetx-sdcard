---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - design tokens and text metrics                             #
---- #                                                                       #
---- # Single source of truth for colour, opacity, spacing and typography.   #
---- # ui_core/dial_renderer/bar never name a raw constant; they ask here.  #
---- #                                                                       #
---- # Colours are theme roles (api_colorlcd.cpp COLOR_THEME_*) so the gauge #
---- # follows dark / light / high-contrast themes. The only literal is RED: #
---- # the firmware exposes no "critical" theme role.                        #
---- #                                                                       #
---- # Text metrics: lcd.sizeText() reports the font cell (including         #
---- # leading), not the ink box, and the numbers differ per screen scale.   #
---- # Rather than hard-coding per-font correction tables (which are         #
---- # resolution specific), we                                              #
---- #   * memoize the measurement (it never changes at runtime), and        #
---- #   * let LVGL align text horizontally inside a label of known width    #
---- #     (align = CENTER / RIGHT) instead of positioning by measured width.#
---- # The reported height is >= the ink height, so using it for fitting is  #
---- # conservative - text never overflows its region.                       #
---- #                                                                       #
---- # MEASURING CONTRACT (Tanda 6 F-4): M.textWidth is memoized and         #
---- # therefore BOUNDED - it may only be called from layout/build paths,    #
---- # over the fixed set of strings one configuration can produce. The      #
---- # renderers must never measure a LIVE string through it: at high        #
---- # precision the value string changes every frame, and each new string   #
---- # would become a permanent entry in a cache shared by every gauge on    #
---- # the card. M.measureWidth is the renderers' entry: exact, deliberately #
---- # NOT memoized, one lcd.sizeText call per call.                         #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local floor, min, max = math.floor, math.min, math.max

-- Font flags: the firmware's etcxcst constants are the font index << 8
-- (radio/src/gui/colorlcd/fonts.h FONT_INDEX). Ordered small -> large.
M.FONTS = {
  XXS = TINSIZE,
  XS  = SMLSIZE,
  S   = STDSIZE,
  M   = MIDSIZE,
  L   = DBLSIZE,
  XL  = XLSIZE,
  XXL = XXLSIZE,
}

-- Ordered candidate ramp used by the auto-fit search (largest first).
-- STDSIZE is deliberately IN the ramp: the old M(24) -> XS(13) jump skipped
-- the 16 px step, so a chord that barely missed 24 px threw the value down to
-- 13 px (AUDIT.md P3-4; P0-2's value clearance narrows the chord at 200x160).
--
-- Built by FILTERING, not by literal indexing: a firmware that does not
-- define one of these constants (e.g. XXLSIZE on a target that has no
-- double-size fonts) must degrade to a shorter ramp, never leave a HOLE.
-- #RAMP keeps reporting the full length otherwise, so fitFont walks into
-- fontHeight(nil) -> heightCache[nil] = h raises `table index is nil`
-- (Tanda 6 F-10): a crash on the first layout pass, and the widget
-- permanently disables itself.
local RAMP_ORDER = { "XXL", "XL", "L", "M", "S", "XS", "XXS" }
M.RAMP = {}
for i = 1, #RAMP_ORDER do
  local f = M.FONTS[RAMP_ORDER[i]]
  if f ~= nil then M.RAMP[#M.RAMP + 1] = f end
end
assert(#M.RAMP > 0, "GaugePro: firmware exposes no usable font constants")

-- TWO CHANNELS, NEVER ONE (Tanda 8 §3). A gauge has to say two different
-- things at once, and they have incompatible requirements:
--
--   STATUS - the arc, the rail/section bands, the threshold marks, the badge.
--            Large, peripheral, read as a blob of colour in ~200 ms with the
--            pilot's eyes on the aircraft. Hue is the right channel here.
--   DATA   - the value, unit, source name, min/max. Read as SHAPES. Legibility
--            beats identity, and a hue that must survive an unknown background
--            buys nothing you can actually read.
--
-- Every real instrument splits them this way: an airspeed indicator has green,
-- yellow and red arcs ON THE DIAL FACE and plain white numerals. Colouring the
-- number is what a dashboard does; colouring the scale is what an instrument
-- does. Before Tanda 8 the status colour drove BOTH, which is why a role
-- chosen for a button background ended up as the value's text colour.
--
-- The one deliberate exception is CRITICAL, where alarm outranks neutrality.
M.color = {
  -- The three status colours are FIXED, not theme roles. The reasoning that
  -- already justified a literal for `crit` - EdgeTX has no "critical" role -
  -- applies just as well to "good" and "warning": the role vocabulary is a UI
  -- vocabulary (PRIMARY* is text, SECONDARY* is chrome, ACTIVE is the
  -- background of a CHECKED control, WARNING is warning LABEL TEXT), and it
  -- has no notion of instrument state.
  --
  -- This used to be COLOR_THEME_ACTIVE, which is #ffde00 on the stock theme
  -- and scores 1.13:1 against the stock screen background - the normal state,
  -- arc and value alike, was effectively invisible on a stock radio. It
  -- measured 9.87:1 on a dark theme, which is why every render in this repo
  -- looked right for four review rounds.
  --
  -- A fixed colour has no theme author looking after it, so each one is
  -- chosen to clear the WCAG 1.4.11 non-text floor (3:1) against BOTH
  -- reference backgrounds - stock light #e4eef2 and a dark theme #303030.
  -- That constrains relative luminance to [0.189, 0.247], a window only 0.058
  -- wide, and 3.35:1 is the best ANY colour can do on both at once. All three
  -- land within 0.05 of that optimum:
  --
  --        light      dark
  --   #209058  3.35:1  3.35:1   normal    (was 1.13:1)
  --   #c86000  3.34:1  3.35:1   warning   (stock WARNING role: 2.76:1 on dark)
  --   #ff0000  3.39:1  3.30:1   critical  (unchanged - already near optimal)
  --
  -- Equal luminance by construction, so no state shouts louder than another by
  -- accident and the three differ in HUE alone - which is exactly how dial
  -- arcs are drawn. It also means hue is the ONLY separator, so the badge text
  -- (renderer.stateText) is not decoration: see the note on `warn` below.
  accent  = lcd.RGB(0x20, 0x90, 0x58),
  -- Fixed too, and for a reason beyond contrast. On the stock theme
  -- COLOR_THEME_WARNING is #e00000 - a red 53 perceptual units from critical's
  -- #ff0000, i.e. THE SAME COLOUR to the eye, which wasted the hue channel
  -- entirely. This amber sits 213 units away. The cost is real and worth
  -- naming: a theme author who picked a warning colour no longer sees it here.
  warn    = lcd.RGB(0xc8, 0x60, 0x00),
  -- An lcd.RGB literal rather than the RED constant, though they are the same
  -- #ff0000: lcd.getColor() returns NIL for the fixed colour indices
  -- (api_colorlcd.cpp:968 - only RGB flags and the 14 theme indices resolve),
  -- so RED could not be decoded by labelOn() below.
  crit    = lcd.RGB(0xff, 0x00, 0x00),

  -- ---- DATA channel: theme roles, never the status colour ----------------
  -- PRIMARY1 is the theme's own ink - "label text" in the theme vocabulary,
  -- 17.81:1 on the stock background, and whatever a dark theme's author chose
  -- in its place. The value is the one thing on the widget that must stay
  -- readable in every state, so it gets the role whose whole job is that.
  value   = COLOR_THEME_PRIMARY1,
  -- The badge label picks between these two by the fill's luminance
  -- (M.labelOn): PRIMARY1/PRIMARY2 are a PAIR in the theme vocabulary - ink
  -- on the screen background, and ink on chrome - so a theme that inverts one
  -- inverts the other, and the badge follows without being told.
  inkDark = COLOR_THEME_PRIMARY1,
  inkLite = COLOR_THEME_PRIMARY2,

  needle  = COLOR_THEME_PRIMARY1,    -- the needle NEVER follows the state
                                     -- colour (owner request): a fixed,
                                     -- always-legible tone against every
                                     -- band colour, including the green
                                     -- normal state above, and both themes
  rail    = COLOR_THEME_SECONDARY1,  -- track + rail base (used with opacity)
  tick    = COLOR_THEME_SECONDARY1,  -- scale ticks: the LIGHTER role, so 1 px
                                     -- marks read on dark themes (review P-C)
  label   = COLOR_THEME_SECONDARY1,
  muted   = COLOR_THEME_DISABLED,
  history = COLOR_THEME_SECONDARY1,
}

M.opacity = {
  full     = 255,
  rail     = 90,    -- inactive track: ~35% - a crisper silhouette that still
                    -- never competes with the value arc (review P2-9)
  railBand = 200,   -- reference rail bands (Rail mode): drawn at reduced
                    -- opacity so the value arc - and with it the critical
                    -- red - stays the foreground (review P-E)
  railBandCrit = 160, -- one step dimmer, applied ONLY while the state is
                    -- critical (renderer.applyColors): at 200 the passive
                    -- amber band was the highest-luminance element on the
                    -- ring, competing with the full-red arc/text it is
                    -- supposed to sit behind (Tanda 5 review 3.6)
  ghost    = 110,   -- peak-hold segment
  tickMinor = 110,  -- Fine Ticks reference grid: visible but subordinate
  tickMajor = 145,  -- endpoints, fifths and exact thresholds read first
  muted    = 120,   -- whole gauge when data is not live
  pulse    = 150,   -- critical pulse trough
}

-- Logical spacing steps; always passed through px().
M.space = { xs = 2, sm = 4, md = 6, lg = 10 }

M.ratio = {
  unitToValue     = 0.55,  -- unit font relative to the value font
  trackToRadius   = 0.14,
  railToTrack     = 0.34,
  -- Needle keeps the track as the quiet reference and the active arc as a
  -- subordinate position cue. Arc style does not consume this ratio: its arc
  -- remains the full track thickness because it is the only value geometry.
  needleArcToTrack = 0.62,
  -- Exact Threshold marks cross the track and extend slightly towards the
  -- ticks. The layout clamps the resulting physical lip to 1..2 pixels.
  thresholdLipToTrack = 0.15,
  needleWidth     = 0.055, -- half-width of the needle base, relative to radius
  -- Three-part taper (owner request, Tanda 5): two steps (thick body ->
  -- thin tip, review P-A) read as a paddle with a toothpick glued to the
  -- end - the width more than halves in one jump with almost no blend.
  -- A middle segment splits that single big step into two smaller ones.
  needleBodyReach = 0.30,  -- short base establishes direction without reading
                           -- as a second hub
  needleMidReach  = 0.66,  -- longer mid/tip transitions make taper visible
  -- 0.62 looked right on paper but `floor(needleHalf * ratio)` collapses
  -- mid onto the tip's width at the canonical 200x160 base (needleHalf=3:
  -- floor(3*0.62)=1, same as the tip) - the 3rd step silently disappeared
  -- at the most common size. 0.7 clears that floor (floor(3*0.7)=2).
  needleMidToHalf = 0.68,  -- mid half-width relative to the BASE half-width
  needleTipToHalf = 0.32,  -- tip half-width relative to the base half-width;
                           -- layout still enforces the legible 2 px minimum
  pivotRadius     = 0.08,  -- one physical step smaller at the reference size
}

-- Physical size helper: LCD_SCALE is 0.8 / 1.0 / 1.375 for 320 / 480 / 800 px
-- wide screens (etx_lv_theme.h), so px() keeps proportions identical.
function M.px(value)
  return max(1, floor(value * (lvgl.LCD_SCALE or 1) + 0.5))
end

-- ---------------------------------------------------------------- metrics --

local widthCache = {}
local heightCache = {}

-- Height of a font, measured once. Used for fitting and row heights.
function M.fontHeight(font)
  local h = heightCache[font]
  if h then return h end
  local _, measured = lcd.sizeText("8", font)
  h = (type(measured) == "number" and measured > 0) and measured or 16
  heightCache[font] = h
  return h
end

-- Width of a string, memoized per (font, text). BOUNDED by contract: only
-- called from layout / build paths over the fixed string set one
-- configuration produces (see the header). NEVER call this with a live
-- value string - that is what M.measureWidth is for.
function M.textWidth(text, font)
  local byFont = widthCache[font]
  if not byFont then
    byFont = {}
    widthCache[font] = byFont
  end
  local w = byFont[text]
  if not w then
    w = lcd.sizeText(text, font) or 0
    byFont[text] = w
  end
  return w
end

-- Exact width of a string, deliberately NOT memoized: one lcd.sizeText call
-- per call, no cache write. The renderers' entry for the LIVE value string
-- (anchorUnit): exact like textWidth but incapable of growing the shared
-- cache one entry per frame (Tanda 6 F-4).
function M.measureWidth(text, font)
  return lcd.sizeText(text, font) or 0
end

-- Largest font from `candidates` whose height fits `available`.
-- Falls back to the smallest candidate.
function M.fitFont(candidates, available)
  for i = 1, #candidates do
    if M.fontHeight(candidates[i]) <= available then return candidates[i] end
  end
  return candidates[#candidates]
end

-- Font one step smaller in the ramp (used for the unit next to the value).
-- The unit never lands on STDSIZE: a 24 px value keeps its 13 px unit (the
-- ~0.55 ratio of the Tanda-4 design), even though STDSIZE is a valid VALUE
-- font in the ramp (P0-2 / AUDIT P3-4).
function M.smallerFont(font, steps)
  steps = steps or 1
  for i = 1, #M.RAMP do
    if M.RAMP[i] == font then
      local j = i + steps
      while j <= #M.RAMP and M.RAMP[j] == M.FONTS.S do j = j + 1 end
      if j > #M.RAMP then j = #M.RAMP end
      return M.RAMP[j]
    end
  end
  return font
end

-- ----------------------------------------------------------------- states --

-- Colour for a semantic state key. `accent` overrides the normal colour when
-- the user picked one (Accent option); nil keeps the theme role.
function M.stateColor(key, accent, palette)
  if palette then
    if key == "warning" then return palette.warning end
    if key == "critical" then return palette.critical end
    if key == "muted" then return palette.muted or M.color.muted end
    return palette.normal or accent or M.color.accent
  end
  if key == "warning" then return M.color.warn end
  if key == "critical" then return M.color.crit end
  if key == "muted" then return M.color.muted end
  return accent or M.color.accent
end

-- ---------------------------------------------------------------- luminance --

-- The RGB behind a colour flag, or nil if the firmware will not say.
--
-- lcd.getColor exists (api_colorlcd.cpp:956, since 2.3.11) and returns the
-- RGB565 value in the HIGH 16 bits with RGB_FLAG set. Its guard resolves RGB
-- flags and the fourteen THEME indices only, so a FIXED literal (RED, GREEN,
-- WHITE...) comes back nil - which is why this widget's own status colours are
-- lcd.RGB literals: those carry RGB_FLAG and always resolve.
--
-- An RGB flag can be decoded without calling anything, so the API is only
-- consulted for theme roles. Nothing here is load-bearing: every caller has a
-- defined answer for nil.
local function resolveColor(flag)
  if type(flag) ~= "number" then return nil end
  local v = flag
  if (v & 0x8000) == 0 then
    if type(lcd) ~= "table" or type(lcd.getColor) ~= "function" then
      return nil
    end
    local ok, got = pcall(lcd.getColor, flag)
    if not ok or type(got) ~= "number" then return nil end
    v = got
  end
  return v
end
M.resolveColor = resolveColor

local function rgbOf(flag)
  local v = resolveColor(flag)
  if not v then return nil end
  local c = (v >> 16) & 0xFFFF
  return (c & 0xF800) >> 8, (c & 0x07E0) >> 3, (c & 0x001F) << 3
end
M.rgbOf = rgbOf

local function channel(c)
  c = c / 255
  if c <= 0.04045 then return c / 12.92 end
  return ((c + 0.055) / 1.055) ^ 2.4
end

-- WCAG 2.x relative luminance, 0..1.
local function luminance(r, g, b)
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end
M.luminance = luminance

-- Contrast and distance are analysis signals, not color-replacement rules.
-- A theme or custom palette whose colors are close keeps the exact authored
-- colors; bar_style uses these measurements to request redundant structure.
function M.contrastRatio(a, b)
  local ar, ag, ab = rgbOf(a)
  local br, bg, bb = rgbOf(b)
  if not ar or not br then return nil end
  local la, lb = luminance(ar, ag, ab), luminance(br, bg, bb)
  local hi, lo = max(la, lb), (la < lb) and la or lb
  return (hi + 0.05) / (lo + 0.05)
end

function M.colorDistance(a, b)
  local ar, ag, ab = rgbOf(a)
  local br, bg, bb = rgbOf(b)
  if not ar or not br then return nil end
  local dr, dg, db = ar - br, ag - bg, ab - bb
  return math.sqrt(dr * dr + dg * dg + db * db)
end

-- A stable signature uses resolved RGB values for theme roles. Theme flags
-- themselves do not change when the pilot changes theme; lcd.getColor does.
function M.colorSignature(colors)
  local parts = {}
  for i = 1, #colors do
    local flag = colors[i]
    parts[i] = tostring(resolveColor(flag) or flag or "nil")
  end
  return table.concat(parts, ":")
end

local function inverseChannel(c)
  if c <= 0.0031308 then return c * 12.92 * 255 end
  return (1.055 * (c ^ (1 / 2.4)) - 0.055) * 255
end

-- Full dichromacy matrices from Machado et al. They are used only while a
-- palette is resolved (configure/theme change), never in the frame loop.
-- Measuring the simulated separation lets Auto add a redundant outline/head
-- when two authored severity colours collapse for a pilot with a common
-- colour-vision deficiency. The authored colours themselves remain untouched.
local CVD = {
  protanopia = {
    0.152286, 1.052583, -0.204868,
    0.114503, 0.786281, 0.099216,
    -0.003882, -0.048116, 1.051998,
  },
  deuteranopia = {
    0.367322, 0.860646, -0.227968,
    0.280085, 0.672501, 0.047413,
    -0.011820, 0.042940, 0.968881,
  },
  tritanopia = {
    1.255528, -0.076749, -0.178779,
    -0.078411, 0.930809, 0.147602,
    0.004733, 0.691367, 0.303900,
  },
}

local function cvdRgb(color, matrix)
  local r, g, b = rgbOf(color)
  if not r then return nil end
  r, g, b = channel(r), channel(g), channel(b)
  local rr = matrix[1] * r + matrix[2] * g + matrix[3] * b
  local gg = matrix[4] * r + matrix[5] * g + matrix[6] * b
  local bb = matrix[7] * r + matrix[8] * g + matrix[9] * b
  rr, gg, bb = max(0, min(1, rr)), max(0, min(1, gg)), max(0, min(1, bb))
  return inverseChannel(rr), inverseChannel(gg), inverseChannel(bb)
end

function M.colorVisionDistance(a, b, mode)
  local matrix = CVD[mode]
  if not matrix then return M.colorDistance(a, b) end
  local ar, ag, ab = cvdRgb(a, matrix)
  local br, bg, bb = cvdRgb(b, matrix)
  if not ar or not br then return nil end
  local dr, dg, db = ar - br, ag - bg, ab - bb
  return math.sqrt(dr * dr + dg * dg + db * db)
end

-- Gamma-aware interpolation in linear-light space. Endpoints are returned
-- byte-for-byte so choosing a custom color never silently edits it.
function M.mixColor(a, b, t)
  if t <= 0 then return a end
  if t >= 1 then return b end
  local ar, ag, ab = rgbOf(a)
  local br, bg, bb = rgbOf(b)
  if not ar or not br then return (t < 0.5) and a or b end
  local r = inverseChannel(channel(ar) + (channel(br) - channel(ar)) * t)
  local g = inverseChannel(channel(ag) + (channel(bg) - channel(ag)) * t)
  local bl = inverseChannel(channel(ab) + (channel(bb) - channel(ab)) * t)
  return lcd.RGB(floor(r + 0.5), floor(g + 0.5), floor(bl + 0.5))
end

-- The ink colour to print ON a filled swatch: whichever of the theme's two
-- text roles contrasts more with the fill.
--
-- This is what makes a filled badge SELF-GROUNDING - its contrast is between
-- the fill and its own label, both of which the widget controls - so it reads
-- on a light theme, a dark theme, and a theme that ships a background.png
-- photograph alike. No flat colour can promise that.
--
-- Memoized by BOTH the fill and the resolved theme inks. Theme role flags are
-- stable numeric IDs while lcd.getColor(role) changes when the pilot switches
-- theme. Caching by `fill` alone therefore returned a decision made for the
-- previous theme until the Lua state was reloaded.
local INK_CACHE_MAX = 32
local inkCache, inkOrder = {}, {}
function M.labelOn(fill, palette)
  local fillResolved = resolveColor(fill)
  local darkInk = (palette and palette.inkDark) or M.color.inkDark
  local liteInk = (palette and palette.inkLite) or M.color.inkLite
  local darkResolved = resolveColor(darkInk)
  local liteResolved = resolveColor(liteInk)
  local cacheKey = tostring(fill) .. ":" .. tostring(
    (palette and palette.signature) or "default")
  local cached = inkCache[cacheKey]
  if cached and cached.fill == fillResolved and cached.dark == darkResolved
     and cached.lite == liteResolved then
    return cached.ink
  end

  local r, g, b = rgbOf(fillResolved)
  local ink
  if not r then
    -- Unknowable fill: PRIMARY1 is the theme's own ink and the safer guess,
    -- since a widget on a stock radio is drawn on a light background.
    ink = darkInk
  else
    local lf = luminance(r, g, b)
    local dr, dg, db = rgbOf(darkInk)
    local lr, lg, lb = rgbOf(liteInk)
    -- No theme information at all: 0.1791 is where black and white tie.
    if not dr or not lr then
      ink = (lf > 0.1791) and darkInk or liteInk
    else
      local function ratio(a, c)
        local hi, lo = max(a, c), (a < c) and a or c
        return (hi + 0.05) / (lo + 0.05)
      end
      ink = (ratio(lf, luminance(dr, dg, db)) >= ratio(lf, luminance(lr, lg, lb)))
        and darkInk or liteInk
    end
  end
  if not inkCache[cacheKey] then
    if #inkOrder >= INK_CACHE_MAX then
      local old = table.remove(inkOrder, 1)
      inkCache[old] = nil
    end
    inkOrder[#inkOrder + 1] = cacheKey
  end
  inkCache[cacheKey] = {
    fill = fillResolved, dark = darkResolved, lite = liteResolved, ink = ink,
  }
  return ink
end

function M.inkCacheStats()
  return { entries = #inkOrder, maximum = INK_CACHE_MAX }
end

-- ----------------------------------------------------------------- gradient --

-- Continuous critical -> warning -> normal ramp (Gradient colour mode),
-- expressed on the normalized 0..1 position between the critical end (0) and
-- the good end (1).
--
-- It interpolates between the THREE STATUS COLOURS rather than inventing its
-- own endpoints. The old ramp was lcd.RGB(0xdf - g, g, 0): a straight line to
-- #00df00, which is 1.16:1 against the stock background - the same defect as
-- the old accent, confined to one mode. Anchoring the ends to colours that
-- were already chosen for both backgrounds fixes the ends for free.
--
-- The MIDDLE is the part that needs work. Mixing amber into green passes
-- through olive, and luminance is not linear in sRGB values, so intermediate
-- mixes wander out of the [0.189, 0.247] window even though both endpoints sit
-- inside it. A scale factor pulls any mix that drifts back to the edge of the
-- window, which holds the whole ramp at >= 3.02:1 on both reference
-- backgrounds - against 1.54:1 worst case before. Hue varies; brightness does
-- not. That is how a dial's colour scale should behave anyway: no part of the
-- ramp is allowed to shout louder than another.
--
-- The bounds are drawn in slightly from the true window so the RGB565
-- quantisation the panel applies cannot push a step back out.
local GRAD_LO, GRAD_HI = 0.198, 0.240
local gradCache = {}

local function gradAnchor(t)
  local r1, g1, b1 = rgbOf(M.color.crit)
  local r2, g2, b2 = rgbOf(M.color.warn)
  local r3, g3, b3 = rgbOf(M.color.accent)
  -- rgbOf cannot fail for these (lcd.RGB literals), but a nil here would
  -- otherwise become an arithmetic error inside a render callback.
  if not r1 or not r2 or not r3 then return nil end
  local a, b, u
  if t < 0.5 then
    a, b, u = { r1, g1, b1 }, { r2, g2, b2 }, t * 2
  else
    a, b, u = { r2, g2, b2 }, { r3, g3, b3 }, (t - 0.5) * 2
  end
  return a[1] + (b[1] - a[1]) * u,
         a[2] + (b[2] - a[2]) * u,
         a[3] + (b[3] - a[3]) * u
end

function M.gradientColor(t)
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local cached = gradCache[t]
  if cached then return cached end
  local r, g, b = gradAnchor(t)
  if not r then return M.color.accent end
  local l = luminance(r, g, b)
  -- 1/2.2 undoes the display gamma well enough to land inside the window in
  -- one step; the exact figure does not matter because the window is a band,
  -- not a point.
  local k
  if l > GRAD_HI then k = (GRAD_HI / l) ^ (1 / 2.2)
  elseif l < GRAD_LO then k = (GRAD_LO / l) ^ (1 / 2.2) end
  if k then
    r, g, b = r * k, g * k, b * k
    if r > 255 then r = 255 end
    if g > 255 then g = 255 end
    if b > 255 then b = 255 end
  end
  local c = lcd.RGB(floor(r + 0.5), floor(g + 0.5), floor(b + 0.5))
  gradCache[t] = c
  return c
end

-- Palette-aware interpolation for bar faces. It is quantized and bounded:
-- live values can only address `steps + 1` entries, and repeated palette or
-- theme edits retain at most PALETTE_CACHE_MAX signatures. Classic delegates
-- to the already approved calibrated ramp, keeping its pixels identical.
local PALETTE_CACHE_MAX = 12
local paletteCache, paletteOrder = {}, {}

local function paletteBucket(signature)
  local bucket = paletteCache[signature]
  if bucket then return bucket end
  if #paletteOrder >= PALETTE_CACHE_MAX then
    local old = table.remove(paletteOrder, 1)
    paletteCache[old] = nil
  end
  bucket = {}
  paletteCache[signature] = bucket
  paletteOrder[#paletteOrder + 1] = signature
  return bucket
end

function M.paletteColor(palette, t, steps)
  palette = palette or {
    normal = M.color.accent, warning = M.color.warn,
    critical = M.color.crit, signature = "classic", calibrated = true,
  }
  steps = floor(tonumber(steps) or 24)
  if steps < 2 then steps = 2 elseif steps > 24 then steps = 24 end
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local q = floor(t * steps + 0.5)
  local signature = tostring(palette.signature or M.colorSignature{
    palette.normal, palette.warning, palette.critical,
  })
  local bucket = paletteBucket(signature)
  local key = steps * 100 + q
  local cached = bucket[key]
  if cached then return cached end

  local qt = q / steps
  local color
  if q == 0 then color = palette.critical
  elseif q == steps then color = palette.normal
  elseif palette.calibrated then color = M.gradientColor(qt)
  elseif qt <= 0.5 then color = M.mixColor(palette.critical,
                                            palette.warning, qt * 2)
  else color = M.mixColor(palette.warning, palette.normal, (qt - 0.5) * 2)
  end
  bucket[key] = color
  return color
end

function M.paletteCacheStats()
  local entries = 0
  for _, bucket in pairs(paletteCache) do
    for _ in pairs(bucket) do entries = entries + 1 end
  end
  return { signatures = #paletteOrder, entries = entries,
           maximum = PALETTE_CACHE_MAX }
end

function M.clearPaletteCache()
  paletteCache, paletteOrder = {}, {}
end

return M
