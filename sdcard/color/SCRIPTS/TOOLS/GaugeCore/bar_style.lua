---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - bar personalization resolver                              #
---- #                                                                       #
---- # Stored options are inputs, never working state. This module resolves  #
---- # preset -> explicit override -> responsive compact variant into a      #
---- # per-widget visual contract and a runtime theme-aware palette.         #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local T, SENSOR_PRESETS
local min, max = math.min, math.max

function M.setup(theme, presets)
  T, SENSOR_PRESETS = theme, presets
end

-- Appearance presets are deliberately data, not branches scattered through
-- renderers. `compact` documents the predictable small-zone downgrade.
local PRESETS = {
  [1] = {
    key = "auto-source", label = "Auto Source", sourceAware = true,
    face = "continuous", palette = "classic", direction = "auto",
    origin = "scale-low", thickness = "medium", ends = "round",
    segments = 10, gap = "normal", surface = "transparent",
    contrast = "auto", motion = "refined",
    compact = "source face with reduced detail",
  },
  [2] = {
    key = "classic-rail", label = "Classic Rail",
    face = "continuous", palette = "classic", direction = "auto",
    origin = "scale-low", thickness = "medium", ends = "round",
    segments = 10, gap = "normal", surface = "transparent",
    contrast = "auto", motion = "refined",
    compact = "continuous medium rail",
  },
  [3] = {
    key = "theme-clean", label = "Theme Clean",
    face = "continuous", palette = "theme", direction = "auto",
    origin = "scale-low", thickness = "thin", ends = "round",
    segments = 10, gap = "tight", surface = "theme-panel",
    contrast = "auto", motion = "essential",
    compact = "thin continuous line without panel",
  },
  [4] = {
    key = "hex-telemetry", label = "Hex Telemetry",
    face = "hex", palette = "classic", direction = "auto",
    origin = "scale-low", thickness = "medium", ends = "chamfer",
    segments = 8, gap = "normal", surface = "theme-panel",
    contrast = "auto", motion = "refined",
    compact = "six chamfered cells",
  },
  [5] = {
    key = "status-blocks", label = "Status Blocks",
    face = "blocks", palette = "classic", direction = "auto",
    origin = "scale-low", thickness = "medium", ends = "square",
    segments = 10, gap = "normal", surface = "transparent",
    contrast = "auto", motion = "essential",
    compact = "six square blocks",
  },
  [6] = {
    key = "signal-ticks", label = "Signal Ticks",
    face = "ticks", palette = "theme", direction = "auto",
    origin = "scale-low", thickness = "medium", ends = "square",
    segments = 20, gap = "tight", surface = "transparent",
    contrast = "auto", motion = "refined",
    compact = "ten high-contrast ticks",
  },
  [7] = {
    key = "rc-center", label = "RC Center",
    face = "dual-rail", palette = "custom-two", direction = "auto",
    origin = "zero", thickness = "medium", ends = "round",
    segments = 10, gap = "normal", surface = "transparent",
    contrast = "auto", motion = "refined",
    compact = "zero-notch dual rail",
  },
  [8] = {
    key = "minimal-line", label = "Minimal Line",
    face = "continuous", palette = "theme", direction = "auto",
    origin = "scale-low", thickness = "thin", ends = "round",
    segments = 8, gap = "tight", surface = "transparent",
    contrast = "off", motion = "essential",
    compact = "one-pixel-equivalent theme line",
  },
  [9] = {
    key = "bold-data", label = "Bold Data",
    face = "continuous", palette = "classic", direction = "auto",
    origin = "scale-low", thickness = "thick", ends = "round",
    segments = 12, gap = "normal", surface = "theme-panel",
    contrast = "auto", motion = "refined",
    compact = "medium rail with external value",
  },
}
M.PRESETS = PRESETS

-- Auto Source may choose the signal-strength reading model without adding a
-- tenth user-facing preset. It is immutable resolver data like PRESETS: RSSI
-- and link-quality values get the familiar rising bars, while SNR and other
-- genuinely fast signed/noisy signal metrics retain Fine Ticks.
local AUTO_SIGNAL_STEPS = {
  key = "auto-signal-steps", label = "Stepped Signal",
  face = "steps", palette = "classic", direction = "auto",
  origin = "scale-low", thickness = "medium", ends = "square",
  segments = 8, gap = "normal", surface = "transparent",
  contrast = "auto", motion = "refined",
  compact = "five rising signal steps",
}

local FACE = { [2] = "continuous", [3] = "blocks", [4] = "hex",
               [5] = "ticks", [6] = "steps", [7] = "dual-rail" }
local DIRECTION = { [2] = "horizontal", [3] = "vertical" }
local ORIGIN = { [2] = "scale-low", [3] = "zero" }
local THICKNESS = { [2] = "thin", [3] = "medium", [4] = "thick",
                    [5] = "maximum" }
local ENDS = { [2] = "round", [3] = "square", [4] = "chamfer" }
local SEGMENTS = { [2] = 6, [3] = 8, [4] = 10, [5] = 12,
                   [6] = 16, [7] = 24 }
local GAP = { [2] = "tight", [3] = "normal", [4] = "wide" }
local PALETTE = { [2] = "classic", [3] = "theme", [4] = "custom-three",
                  [5] = "custom-two" }
local SURFACE = { [2] = "transparent", [3] = "theme-panel",
                  [4] = "custom" }
local CONTRAST = { [2] = "off", [3] = "strong" }
local MOTION = { [2] = "off", [3] = "essential", [4] = "refined",
                 [5] = "expressive" }
local HEAD = { [2] = "none", [3] = "cap", [4] = "dot", [5] = "line",
               [6] = "needle" }
local MARKS = { [2] = "off", [3] = "thresholds", [4] = "ends",
                [5] = "full" }
local VALUE_POS = { [2] = "above", [3] = "inside", [4] = "end",
                    [5] = "off" }
local LABEL_POS = { [2] = "above", [3] = "below", [4] = "inside",
                    [5] = "off" }

local THEME_ROLES = {
  COLOR_THEME_PRIMARY1, COLOR_THEME_PRIMARY2,
  COLOR_THEME_SECONDARY1, COLOR_THEME_SECONDARY2, COLOR_THEME_SECONDARY3,
  COLOR_THEME_ACTIVE, COLOR_THEME_WARNING, COLOR_THEME_DISABLED,
}

local function pick(index, values, inherited)
  return values[index] or inherited
end

local function hasReason(list, reason)
  for i = 1, #list do
    if list[i] == reason then return true end
  end
  return false
end

local function addDowngrade(visual, reason)
  if not hasReason(visual.downgrades, reason) then
    visual.downgrades[#visual.downgrades + 1] = reason
  end
end

-- Convert renderer-facing downgrade strings into a user-facing diagnostic
-- only when the pilot made an explicit choice that could not be honoured.
-- Auto/preset responsiveness remains silent: it is the purpose of Auto.
-- The full reason stays available for support while the retained UI only has
-- to render the bounded, translated-independent word "LIMIT".
function M.syncNotices(visual, cfg)
  if not visual then return nil end
  cfg = cfg or {}
  local notices = {}
  for i = 1, #(visual.downgrades or {}) do
    local reason = visual.downgrades[i]
    local explicit, requested, effective = false, reason, "responsive"
    if reason == "motion-responsive" then
      explicit = cfg.motion == 5
      requested, effective = "expressive", visual.effectiveMotion
    elseif reason == "dual-rail-requires-zero-origin"
        or reason == "dual-rail-zero-outside-range" then
      explicit = cfg.barFace == 7 or cfg.barPreset == 7
        or (cfg.barOrigin or 1) > 1
      requested, effective = "dual-rail", visual.face
    elseif reason == "zero-origin-clamped" then
      explicit = cfg.barOrigin == 3 or cfg.barPreset == 7
      requested, effective = "zero", "scale-bound"
    elseif string.sub(reason, 1, 8) == "segments" then
      explicit = (cfg.segments or 1) > 1
      requested = SEGMENTS[cfg.segments] or visual.segments
      effective = visual.renderedSegments or visual.segments
    elseif reason == "blocks-chamfer-to-square" then
      explicit = cfg.barEnds == 4
      requested, effective = "chamfer", visual.ends
    elseif reason == "surface-compact" then
      explicit = (cfg.surface or 1) > 1
      requested, effective = SURFACE[cfg.surface] or "panel", visual.surface
    elseif reason == "hex-compact-blocks" then
      explicit = cfg.barFace == 4 or cfg.barPreset == 4
      requested, effective = "hex", "compact-blocks"
    elseif string.sub(reason, 1, 19) == "face-phase-pending:" then
      explicit = (cfg.barFace or 1) > 1
      requested, effective = visual.requestedFace, "continuous"
    elseif string.sub(reason, 1, 6) == "theme-" then
      explicit = (cfg.palette or 1) > 1 or (cfg.surface or 1) > 1
      requested, effective = "theme-role", "safe-color"
    end
    if explicit then
      notices[#notices + 1] = {
        requested = requested,
        effective = effective,
        reason = reason,
        explicit = true,
        text = "LIMIT",
      }
    end
  end
  visual.notices = notices
  visual.notice = notices[1]
  return visual.notice
end

local function zoneProfile(zone)
  local w = max(1, tonumber(zone and zone.w) or 1)
  local h = max(1, tonumber(zone and zone.h) or 1)
  local short = min(w, h)
  local ratio, area = w / h, w * h
  local family
  if h <= 45 or w <= 74 then
    family = "micro"
  elseif ratio >= 2.2 and h <= 64 then
    family = "short"
  elseif h / w >= 1.55 then
    family = "tall"
  elseif w >= 400 or area >= 60000 then
    family = "large"
  elseif short <= 70 or area < 10000 then
    family = "compact"
  else
    family = "standard"
  end
  return {
    w = w, h = h, ratio = ratio, family = family,
    compact = family == "micro" or family == "short"
      or family == "compact",
  }
end
M.zoneProfile = zoneProfile

local function autoDirection(profile)
  return (profile.ratio < 0.8) and "vertical" or "horizontal"
end

local function sourcePreset(kind, source, cfg)
  if kind == "signal" then
    local name = (SENSOR_PRESETS and SENSOR_PRESETS.normName)
      and SENSOR_PRESETS.normName(source and source.name) or ""
    if string.find(name, "rssi", 1, true)
       or string.find(name, "rss", 1, true)
       or string.find(name, "qly", 1, true)
       or string.find(name, "vfr", 1, true) then
      return AUTO_SIGNAL_STEPS
    end
    return PRESETS[6]
  end
  if kind == "battery" then return PRESETS[4] end
  if kind == "capacity" then return PRESETS[5] end
  if kind == "control" and cfg and cfg.min < 0 and cfg.max > 0 then
    return PRESETS[7]
  end
  return PRESETS[2]
end

local function compactCount(face, count, profile)
  if face == "blocks" then
    if profile.compact then count = min(count,
      (profile.family == "micro") and 6 or 10) end
    return max(6, min(24, count))
  elseif face == "hex" then
    if profile.compact then count = min(count, 6) end
    return max(6, min(10, count))
  elseif face == "ticks" then
    if profile.compact then count = min(count,
      (profile.family == "micro") and 8 or 12) end
    return max(8, min(28, count))
  elseif face == "steps" then
    if profile.compact then count = min(count, 5) end
    return max(5, min(10, count))
  end
  return count
end

local function signature(parts)
  for i = 1, #parts do parts[i] = tostring(parts[i]) end
  return table.concat(parts, ":")
end

function M.configSignature(cfg)
  return signature{
    cfg.barPreset, cfg.barFace, cfg.barDir, cfg.barOrigin, cfg.barSize,
    cfg.barEnds, cfg.segments, cfg.segGap, cfg.palette, cfg.warnClr,
    cfg.critClr, cfg.trackClr, cfg.surface, cfg.panelClr, cfg.contrast,
    cfg.motion, cfg.barHead, cfg.scaleMarks, cfg.valuePos, cfg.labelPos,
  }
end

-- Theme role flags are stable IDs; their resolved RGB values change when HTX
-- loads another theme. This is deliberately small enough to poll once per
-- second on firmware that does not call widget.update() for a theme switch.
function M.themeSignature()
  return T.colorSignature(THEME_ROLES)
end

local function runtimeColor(color)
  return T.resolveColor(color) or color
end

local function paletteInputSignature(cfg, visual, themeSig)
  return signature{
    visual.palette, visual.surface, visual.contrast,
    cfg.accent, cfg.warnClr, cfg.critClr, cfg.trackClr, cfg.panelClr,
    themeSig,
  }
end

local function paletteFor(cfg, visual, themeSig, inputSig)
  local normalSource = cfg.accent or T.color.accent
  local warningSource, criticalSource = T.color.warn, T.color.crit
  local mode = visual.palette

  -- The backdrop the DATA is actually read against. With a panel it is the
  -- panel; with a transparent surface it is whatever the home screen paints,
  -- which is the theme's own SECONDARY3. Every contrast decision below has to
  -- use this, not the track: a thin or segmented face barely touches the
  -- track, so measuring against the track alone let a 1.14:1 fill through.
  local backdrop = runtimeColor(
    (visual.surface == "custom" and cfg.panelClr) or COLOR_THEME_SECONDARY3)

  local themeDowngrade
  if mode == "theme" then
    -- COLOR_THEME_ACTIVE is the CHECKED-control background, not an instrument
    -- colour: it is #ffde00 at 1.13:1 on the stock theme, which is exactly why
    -- theme.color stopped using it (see theme.lua's status-colour comment).
    -- Adopt it only where it survives the same 3:1 floor a fixed colour must
    -- clear; otherwise keep the calibrated accent and say so.
    local candidate = runtimeColor(COLOR_THEME_ACTIVE)
    local ratio = T.contrastRatio(candidate, backdrop)
    if ratio and ratio < 3 then
      themeDowngrade = string.format("theme-normal-contrast-%.2f", ratio)
    else
      normalSource = COLOR_THEME_ACTIVE
    end
    local warnCandidate = runtimeColor(COLOR_THEME_WARNING)
    local warnRatio = T.contrastRatio(warnCandidate, backdrop)
    if warnRatio and warnRatio < 3 then
      themeDowngrade = (themeDowngrade and (themeDowngrade .. "+warning"))
        or string.format("theme-warning-contrast-%.2f", warnRatio)
    else
      warningSource = COLOR_THEME_WARNING
    end
  elseif mode == "custom-three" then
    warningSource = cfg.warnClr or T.color.warn
    criticalSource = cfg.critClr or T.color.crit
  elseif mode == "custom-two" then
    criticalSource = cfg.critClr or T.color.crit
    warningSource = T.mixColor(criticalSource, normalSource, 0.5)
  end

  local customSurface = visual.surface == "custom"
  local trackSource = customSurface and (cfg.trackClr or T.color.rail)
                      or T.color.rail
  local panelSource = customSurface and (cfg.panelClr or COLOR_THEME_SECONDARY3)
                      or COLOR_THEME_SECONDARY3
  local normal, warning, critical = runtimeColor(normalSource),
    runtimeColor(warningSource), runtimeColor(criticalSource)
  local track, panel = runtimeColor(trackSource), runtimeColor(panelSource)
  local palette = {
    mode = mode,
    normal = normal, warning = warning, critical = critical,
    track = track, panel = panel,
    border = runtimeColor(COLOR_THEME_SECONDARY1),
    history = runtimeColor(T.color.history), muted = runtimeColor(T.color.muted),
    value = runtimeColor(T.color.value), label = runtimeColor(T.color.label),
    inkDark = runtimeColor(T.color.inkDark),
    inkLite = runtimeColor(T.color.inkLite),
    sources = {
      normal = normalSource, warning = warningSource, critical = criticalSource,
      track = trackSource, panel = panelSource,
    },
  }
  -- A custom panel is an authored background, so theme text roles are not
  -- automatically safe on it. Preserve the panel byte-for-byte and select
  -- whichever existing theme ink reads best on top; no user color is altered.
  if customSurface then
    local panelInk = T.labelOn(panel, palette)
    palette.value, palette.label = panelInk, panelInk
    palette.border, palette.history = panelInk, panelInk
  end
  palette.calibrated = mode == "classic" and normalSource == T.color.accent
    and warningSource == T.color.warn and criticalSource == T.color.crit
  palette.themeSignature = themeSig or M.themeSignature()
  palette.inputSignature = inputSig
    or paletteInputSignature(cfg, visual, palette.themeSignature)
  palette.signature = mode .. ":" .. T.colorSignature{
    normal, warning, critical, track, panel, palette.border,
    palette.history, palette.muted, palette.value, palette.label,
    palette.inkDark, palette.inkLite,
  }

  local nw = T.colorDistance(normal, warning)
  local wc = T.colorDistance(warning, critical)
  local nt = T.contrastRatio(normal, track)
  local wt = T.contrastRatio(warning, track)
  local ct = T.contrastRatio(critical, track)
  -- Against the surface the data is read on, not only against the track. A
  -- Thin or Ticks face puts almost no track under its own colour, so this is
  -- the measurement that decides whether the reading is visible at all.
  local nb = T.contrastRatio(normal, backdrop)
  local wb = T.contrastRatio(warning, backdrop)
  local cb = T.contrastRatio(critical, backdrop)
  local basicNeed = (nw and nw < 60) or (wc and wc < 60)
    or (nt and nt < 3) or (wt and wt < 3) or (ct and ct < 3)
    or (nb and nb < 3) or (wb and wb < 3) or (cb and cb < 3) or false
  local nwCvd, wcCvd
  -- Matrix simulation is the expensive fallback, not a tax on every widget
  -- configure. If ordinary separation/contrast already requires assistance,
  -- the decision is complete and the redundant WARN/CRIT channel is enabled.
  if not basicNeed then
    local nwProtan = T.colorVisionDistance(normal, warning, "protanopia")
    local nwDeutan = T.colorVisionDistance(normal, warning, "deuteranopia")
    local nwTritan = T.colorVisionDistance(normal, warning, "tritanopia")
    local wcProtan = T.colorVisionDistance(warning, critical, "protanopia")
    local wcDeutan = T.colorVisionDistance(warning, critical, "deuteranopia")
    local wcTritan = T.colorVisionDistance(warning, critical, "tritanopia")
    nwCvd = nwProtan and min(nwProtan, nwDeutan, nwTritan) or nil
    wcCvd = wcProtan and min(wcProtan, wcDeutan, wcTritan) or nil
  end
  palette.backdrop = backdrop
  palette.themeDowngrade = themeDowngrade
  palette.analysis = {
    normalWarningDistance = nw,
    warningCriticalDistance = wc,
    normalTrackContrast = nt,
    warningTrackContrast = wt,
    criticalTrackContrast = ct,
    normalBackdropContrast = nb,
    warningBackdropContrast = wb,
    criticalBackdropContrast = cb,
    normalWarningCvdDistance = nwCvd,
    warningCriticalCvdDistance = wcCvd,
  }
  palette.needsAssist = basicNeed or (nwCvd and nwCvd < 45)
    or (wcCvd and wcCvd < 45) or false
  palette.assist = (visual.contrast == "strong") and "strong"
    or (visual.contrast == "off") and "off"
    or (palette.needsAssist and "needed" or "none")
  return palette
end

-- Resolve without writing to cfg or widget.options. The caller owns the two
-- returned per-instance tables; PRESETS and shared module state stay read-only.
function M.resolve(widget, cfg)
  assert(T, "GaugePro: bar_style.setup was not called")
  cfg = cfg or {}
  local profile = zoneProfile(widget and widget.zone)
  local selected = PRESETS[cfg.barPreset] or PRESETS[2]
  local hint = (SENSOR_PRESETS and SENSOR_PRESETS.kind)
    and SENSOR_PRESETS.kind(widget and widget.source) or "generic"
  local inherited = selected.sourceAware
    and sourcePreset(hint, widget and widget.source, cfg) or selected

  local visual = {
    preset = selected.key,
    inheritedPreset = inherited.key,
    sourceHint = hint,
    requestedFace = pick(cfg.barFace, FACE, inherited.face),
    direction = pick(cfg.barDir, DIRECTION, inherited.direction),
    origin = pick(cfg.barOrigin, ORIGIN, inherited.origin),
    thickness = pick(cfg.barSize, THICKNESS, inherited.thickness),
    ends = pick(cfg.barEnds, ENDS, inherited.ends),
    segments = pick(cfg.segments, SEGMENTS, inherited.segments),
    segmentsAuto = SEGMENTS[cfg.segments] == nil,
    gap = pick(cfg.segGap, GAP, inherited.gap),
    palette = pick(cfg.palette, PALETTE, inherited.palette),
    surface = pick(cfg.surface, SURFACE, inherited.surface),
    contrast = pick(cfg.contrast, CONTRAST, inherited.contrast),
    motion = pick(cfg.motion, MOTION, inherited.motion or "refined"),
    head = pick(cfg.barHead, HEAD, inherited.head or "line"),
    marks = pick(cfg.scaleMarks, MARKS, inherited.marks or "auto"),
    valuePos = pick(cfg.valuePos, VALUE_POS, inherited.valuePos or "auto"),
    labelPos = pick(cfg.labelPos, LABEL_POS, inherited.labelPos or "auto"),
    compactDescription = inherited.compact,
    profile = profile,
    downgrades = {},
  }
  visual.effectiveMotion = visual.motion
  visual.motionReduced = false
  if visual.motion == "expressive"
     and (profile.family == "micro" or profile.family == "short") then
    visual.effectiveMotion = "refined"
    visual.motionReduced = true
    addDowngrade(visual, "motion-responsive")
  end
  visual.face = visual.requestedFace
  if visual.direction == "auto" then visual.direction = autoDirection(profile) end

  if visual.face == "dual-rail" and ORIGIN[cfg.barOrigin] == nil then
    visual.origin = "zero"
  elseif visual.face == "dual-rail" and visual.origin ~= "zero" then
    visual.face = "continuous"
    addDowngrade(visual, "dual-rail-requires-zero-origin")
  end

  local lo, hi = min(cfg.min or 0, cfg.max or 0), max(cfg.min or 0, cfg.max or 0)
  local zeroInside = lo <= 0 and hi >= 0
  local signedZero = lo < 0 and hi > 0
  visual.zeroInside = zeroInside
  if visual.origin == "zero" and not zeroInside then
    addDowngrade(visual, "zero-origin-clamped")
  end
  if visual.face == "dual-rail" and not signedZero then
    visual.face = "continuous"
    visual.origin = "scale-low"
    addDowngrade(visual, "dual-rail-zero-outside-range")
  end

  if visual.face == "ticks" and visual.segmentsAuto
     and profile.family == "large" then
    visual.segments = 28
  end
  local requestedCount = visual.segments
  visual.segments = compactCount(visual.face, visual.segments, profile)
  if visual.segments ~= requestedCount then
    local reason = (not profile.compact and visual.segments < requestedCount)
      and "segments-object-budget" or "segments-responsive"
    addDowngrade(visual, reason)
  end
  if visual.face == "blocks" and visual.ends == "chamfer" then
    visual.ends = "square"
    addDowngrade(visual, "blocks-chamfer-to-square")
  end
  if profile.family == "micro" and visual.surface ~= "transparent" then
    visual.surface = "transparent"
    addDowngrade(visual, "surface-compact")
  end

  visual.configSig = M.configSignature(cfg)
  visual.structuralSig = signature{
    visual.face, visual.direction, visual.origin, visual.thickness,
    visual.ends, visual.segments, visual.gap, visual.surface, profile.family,
    visual.head, visual.marks, visual.valuePos, visual.labelPos,
  }
  local previous = widget and widget.barPalette
  -- Geometry-only settings edits are common and the live one-second probe is
  -- already the authority for theme drift. Reuse the current palette without
  -- eight lcd.getColor calls when its actual inputs are unchanged; if a
  -- palette/surface/color input moved, resolve the live roles immediately.
  local themeSig = previous and previous.themeSignature or M.themeSignature()
  local inputSig = paletteInputSignature(cfg, visual, themeSig)
  local palette
  if previous and previous.inputSignature == inputSig then
    palette = previous
  else
    themeSig = M.themeSignature()
    inputSig = paletteInputSignature(cfg, visual, themeSig)
    palette = paletteFor(cfg, visual, themeSig, inputSig)
  end
  visual.paletteSig = palette.signature
  visual.themeSig = palette.themeSignature
  -- Recorded on `visual`, resolved on `palette`: the palette is memoised by
  -- input signature, so the reason has to be copied here on every resolve
  -- rather than appended inside paletteFor, which would duplicate it.
  if palette.themeDowngrade then
    addDowngrade(visual, palette.themeDowngrade)
  end
  M.syncNotices(visual, cfg)
  if widget then
    local now = (type(getTime) == "function") and getTime() or 0
    if palette ~= previous or widget.barThemeCheckAt == nil then
      widget.barThemeCheckAt = now + 100
    end
  end
  return visual, palette
end

-- Re-resolve the palette at most once per second and only when a role's
-- resolved RGB actually changed. No geometry signature is touched: the bar
-- update path sees the new palette signature and recolors retained objects.
function M.refreshPalette(widget, cfg, now)
  if not widget or not widget.barVisual or not widget.barPalette then return false end
  now = tonumber(now) or ((type(getTime) == "function") and getTime() or 0)
  local due = widget.barThemeCheckAt or 0
  if now < due then return false end
  widget.barThemeCheckAt = now + 100
  local themeSig = M.themeSignature()
  if themeSig == widget.barVisual.themeSig then return false end
  cfg = cfg or widget.config or {}
  local inputSig = paletteInputSignature(cfg, widget.barVisual, themeSig)
  local palette = paletteFor(cfg, widget.barVisual, themeSig, inputSig)
  widget.barPalette = palette
  widget.barVisual.themeSig = palette.themeSignature
  widget.barVisual.paletteSig = palette.signature
  return true
end

return M
