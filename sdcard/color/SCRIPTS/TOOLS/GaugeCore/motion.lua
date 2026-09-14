---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - bar motion language                                       #
---- #                                                                       #
---- # Motion explains a telemetry change; it never owns telemetry truth.   #
---- # Raw state, alert decisions, badges, thresholds and numeric text stay  #
---- # immediate. This module only derives a retained visual presentation:  #
---- # a bounded color transition, dropout fade, segment settle and optional #
---- # expressive head emphasis.                                             #
---- #                                                                       #
---- # Every transition uses scalar fields in one per-widget table. Colors  #
---- # are precomputed when a transition starts and opacity is quantized, so #
---- # a refresh creates no table/cache entry and cannot grow memory over    #
---- # time. getTime() is always handled as 10 ms ticks.                     #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local T
local segmentedFace

-- Durations are 10 ms ticks. Refined's 180 ms and Expressive's 220 ms sit
-- inside the plan's 150-220 ms state-color bound. Four visible steps are
-- deliberate: enough temporal continuity to explain the change, but a hard
-- ceiling on color/opacity writes and no per-frame palette cache churn.
M.PROFILES = {
  off = {
    pulse = "off", colorTicks = 0, fadeTicks = 0,
    settleTicks = 0, headTicks = 0,
  },
  essential = {
    pulse = "essential", colorTicks = 0, fadeTicks = 18,
    settleTicks = 0, headTicks = 0,
  },
  refined = {
    pulse = "refined", colorTicks = 18, fadeTicks = 18,
    settleTicks = 16, headTicks = 0,
  },
  expressive = {
    pulse = "refined", colorTicks = 22, fadeTicks = 18,
    settleTicks = 22, headTicks = 22,
  },
}

local PAUSE_TICKS = 50       -- >500 ms means refresh was not visible/running
local COLOR_STEPS = 4
local FADE_STEPS = 4

function M.setup(theme)
  T = theme
end

function M.effectiveProfile(widget)
  local visual = widget and widget.barVisual
  if visual and visual.effectiveMotion then
    return visual.effectiveMotion, visual.motionReduced or false
  end
  local requested = visual and visual.motion or "refined"
  if not M.PROFILES[requested] then requested = "refined" end
  local family = visual and visual.profile and visual.profile.family
    or "standard"
  -- Expressive is intentionally absent from the two smallest families. The
  -- same authored choice becomes Refined there: meaning and damping survive,
  -- but the optional head/cascade emphasis cannot compete with tiny data.
  if requested == "expressive" and (family == "micro" or family == "short") then
    return "refined", true
  end
  return requested, false
end

local function clearState(m)
  m.initialized = false
  -- Lua removes nil-valued keys. Scalar sentinels keep the complete retained
  -- footprint materialized before the first warning tween or dropout.
  m.profile = false
  m.expressive = false
  m.paletteSig = false
  m.visualContract = false
  m.lastAt = 0
  m.rawState = false
  m.rawValid = false
  m.rawNormalized = 0
  m.lastNormalized = 0
  m.lastValue = false
  m.visualColor = 0
  m.targetColor = 0
  m.colorActive = false
  m.colorAt = 0
  m.color1, m.color2, m.color3 = 0, 0, 0
  m.fadeActive = false
  m.fadeAt = 0
  m.fadeFrom = 0
  m.fadeNormalized = 0
  m.fadeValue = false
  m.segmented = false
  m.segmentCount = 1
  m.originT = 0
  m.settleAllowed = false
  m.segmentIndex = false
  m.segmentDistance = 0
  m.settleIndex = false
  m.settleAt = 0
  m.headAt = 0
  m.headActive = false
  m.headArmed = true
  m.fastEligible = false
  m.requiresFrameMotion = false
end

local function configureGeometry(widget, m)
  local visual = widget.barVisual
  local family = visual and visual.profile and visual.profile.family
    or "standard"
  m.segmented = segmentedFace and segmentedFace(widget) or false
  m.segmentCount = max(1, floor(tonumber(visual and visual.renderedSegments
    or visual and visual.segments) or 1))
  m.originT = widget.layout and widget.layout.axis
    and widget.layout.axis.originT or 0
  -- A whole-cell highlight is cheap for Blocks/Steps. True Hex would repaint
  -- three LVGL objects per highlighted cell and Fine Ticks is deliberately a
  -- dense reference grid; both keep the precise damped head instead. This is
  -- the plan's frame-budget cap, chosen at build rather than after overruns.
  local name = widget.barFaceName
  m.settleAllowed = (name == "blocks" or name == "steps")
    and m.segmentCount <= 12 and family ~= "micro" and family ~= "short"
end

function M.reset(widget)
  local m = widget.motionState
  local segmented, segmentCount, originT, settleAllowed
  if m then
    segmented, segmentCount = m.segmented, m.segmentCount
    originT, settleAllowed = m.originT, m.settleAllowed
  end
  if not m then
    m = {}
    widget.motionState = m
  end
  clearState(m)
  -- Source/range resets can be non-structural. Preserve already-built face
  -- geometry in that path; M.build immediately recalculates it after a real
  -- tree/layout rebuild.
  if segmentCount then
    m.segmented, m.segmentCount = segmented, segmentCount
    m.originT, m.settleAllowed = originT, settleAllowed
  end
  -- segmentedFace is declared below this function in source order, so build
  -- refreshes geometry once all locals are initialized (reset may also be
  -- called from app.lua before a bar tree exists).
  return m
end

function M.build(widget)
  local m = M.reset(widget)
  configureGeometry(widget, m)
  return m
end

local function prime(widget, m, state, targetColor, paletteSig, profile, now)
  m.initialized = true
  m.profile = profile
  m.expressive = profile == "expressive"
  m.visualContract = widget.barVisual
  m.fastEligible = profile ~= "expressive" and not m.settleAllowed
  m.requiresFrameMotion = m.settleAllowed
  m.paletteSig = paletteSig
  m.lastAt = now
  m.rawState = state.state
  m.rawValid = state.valid
  m.rawNormalized = state.rawNormalized or 0
  m.visualColor = targetColor
  m.targetColor = targetColor
  m.colorActive = false
  m.fadeActive = false
  m.settleIndex = false
  m.headActive = false
  m.headArmed = true
  if state.valid then
    m.lastNormalized = state.smoothNormalized or state.rawNormalized or 0
    m.lastValue = state.smoothValue
  end
end

local function directState(state, targetColor, profile, reduced, paused)
  state.visualColor = targetColor
  state.visualValid = state.valid
  state.opacity = state.rawOpacity
    or (state.valid and T.opacity.full or T.opacity.muted)
  state.motionProfile = profile
  state.motionReduced = reduced
  state.motionPaused = paused or false
  state.pulseMode = M.PROFILES[profile].pulse
  state.colorTransition = false
  state.settleIndex, state.settleLevel = nil, 0
  state.headBoost = 0
  state.motionActive = false
end

local function startColor(m, targetColor, now, duration)
  local from = m.visualColor or m.targetColor or targetColor
  m.targetColor = targetColor
  m.colorAt = now
  m.colorActive = duration > 0 and from ~= targetColor
  if not m.colorActive then
    m.visualColor = targetColor
    return
  end
  -- Fixed scalar slots, not a transition table and not the global palette
  -- cache. The exact authored target is restored byte-for-byte at step four.
  m.color1 = T.mixColor(from, targetColor, 0.25)
  m.color2 = T.mixColor(from, targetColor, 0.50)
  m.color3 = T.mixColor(from, targetColor, 0.75)
end

local function colorStep(m, now, duration)
  if not m.colorActive then return m.visualColor end
  local step = floor((now - m.colorAt) * COLOR_STEPS / duration)
  if step <= 0 then
    return m.visualColor
  elseif step == 1 then
    m.visualColor = m.color1
  elseif step == 2 then
    m.visualColor = m.color2
  elseif step == 3 then
    m.visualColor = m.color3
  else
    m.visualColor = m.targetColor
    m.colorActive = false
  end
  return m.visualColor
end

local function fadeOpacity(from, target, elapsed, duration)
  local step = floor(elapsed * FADE_STEPS / duration)
  if step <= 0 then return from, false end
  if step >= FADE_STEPS then return target, true end
  return floor(from + (target - from) * step / FADE_STEPS + 0.5), false
end

segmentedFace = function(widget)
  local name = widget.barFaceName
  return name == "blocks" or name == "hex"
    or name == "ticks" or name == "steps"
end

local function segmentMotion(_widget, state, m, effect, now, allowTrigger)
  state.settleIndex, state.settleLevel = nil, 0
  if effect.settleTicks <= 0 or not state.valid or not m.settleAllowed then
    m.settleIndex = false
    return
  end
  local count = m.segmentCount
  local normalized = max(0, min(1, state.smoothNormalized or 0))
  local origin = m.originT
  local distance = abs(normalized - origin)
  local index = min(count, max(1, floor(normalized * count) + 1))

  if allowTrigger and m.segmentIndex and index ~= m.segmentIndex
     and distance > m.segmentDistance + 0.0001 then
    m.settleIndex = index
    m.settleAt = now
  end
  m.segmentIndex, m.segmentDistance = index, distance

  if m.settleIndex then
    local elapsed = now - m.settleAt
    if elapsed < effect.settleTicks then
      state.settleIndex = m.settleIndex
      state.settleLevel = (elapsed * 2 < effect.settleTicks) and 2 or 1
    else
      m.settleIndex = false
    end
  end
end

local function headMotion(state, m, effect, now, allowTrigger)
  state.headBoost = 0
  if effect.headTicks <= 0 or not state.valid then
    m.headActive = false
    m.headArmed = true
    return
  end
  local raw = state.rawNormalized or 0
  local delta = abs(raw - (m.rawNormalized or raw))
  if not m.headActive and not m.headArmed and delta < 0.02 then
    m.headArmed = true
  end
  -- One material move gets one short emphasis. It cannot restart on every
  -- noisy sample and become a permanent shimmer; a calm sample rearms it.
  if allowTrigger and m.headArmed and not m.headActive and delta >= 0.08 then
    m.headAt = now
    m.headActive = true
    m.headArmed = false
  end
  if m.headActive then
    local elapsed = now - m.headAt
    if elapsed < effect.headTicks then
      state.headBoost = (elapsed * 2 < effect.headTicks) and 2 or 1
    else
      m.headActive = false
    end
  end
end

-- targetColor is resolved by bar.lua from the current palette. paletteSig is
-- passed separately so a live HTX theme switch lands immediately instead of
-- interpolating through colors that belong to two different themes.
function M.update(widget, state, targetColor, paletteSig)
  assert(T, "GaugePro: motion.setup was not called")
  local m = widget.motionState or M.build(widget)
  local profile, reduced = M.effectiveProfile(widget)
  local effect = M.PROFILES[profile]
  local now = getTime()

  if not m.initialized then
    prime(widget, m, state, targetColor, paletteSig, profile, now)
    directState(state, targetColor, profile, reduced, false)
    state.settleEnabled = m.settleAllowed
    -- Seed the retained segment cursor without playing an activation effect
    -- for the widget's first already-present sample.
    segmentMotion(widget, state, m, effect, now, false)
    return state
  end

  local paused = now - m.lastAt > PAUSE_TICKS
  local contextChanged = profile ~= m.profile or paletteSig ~= m.paletteSig
  if paused or contextChanged then
    -- A hidden widget must not replay color/cascade time when it becomes
    -- visible again. A profile or theme edit likewise starts from the exact
    -- newly-authored endpoint rather than carrying old temporal state across.
    prime(widget, m, state, targetColor, paletteSig, profile, now)
    directState(state, targetColor, profile, reduced, paused)
    state.settleEnabled = m.settleAllowed
    segmentMotion(widget, state, m, effect, now, false)
    return state
  end

  -- Ordinary valid telemetry is the hottest callback on the radio. When no
  -- bounded transition is running and the semantic state is unchanged, take
  -- the retained scalar path: gradient buckets may still change color
  -- immediately, position damping still runs in smoothing.lua, and segmented
  -- faces may still settle their leading cell, but none of the dropout/state
  -- machinery below needs to execute.
  if state.valid and m.rawValid and state.state == m.rawState
     and not m.colorActive and not m.fadeActive and effect.headTicks == 0 then
    m.targetColor, m.visualColor = targetColor, targetColor
    state.motionPaused = false
    state.visualValid = true
    state.opacity = T.opacity.full
    state.visualColor = targetColor
    state.colorTransition = false
    state.headBoost = 0
    segmentMotion(widget, state, m, effect, now, true)
    state.motionActive = state.settleLevel > 0
    m.lastAt = now
    m.lastNormalized = state.smoothNormalized or state.rawNormalized or 0
    m.lastValue = state.smoothValue
    m.rawNormalized = state.rawNormalized or 0
    return state
  end

  state.motionProfile = profile
  state.motionReduced = reduced
  state.motionPaused = false
  state.pulseMode = effect.pulse
  state.settleEnabled = m.settleAllowed
  state.colorTransition = false
  state.visualValid = state.valid
  state.opacity = state.rawOpacity
    or (state.valid and T.opacity.full or T.opacity.muted)

  local wasValid = m.rawValid
  if state.valid then
    m.fadeActive = false
    state.opacity = T.opacity.full
    state.visualValid = true

    local semanticChanged = state.state ~= m.rawState
    local canTween = effect.colorTicks > 0 and wasValid and semanticChanged
      and state.state ~= "critical"
    if targetColor ~= m.targetColor then
      if canTween then
        startColor(m, targetColor, now, effect.colorTicks)
      else
        m.targetColor, m.visualColor = targetColor, targetColor
        m.colorActive = false
      end
    end
    state.visualColor = colorStep(m, now, effect.colorTicks)
    state.colorTransition = m.colorActive
    m.lastNormalized = state.smoothNormalized or state.rawNormalized or 0
    m.lastValue = state.smoothValue
  else
    m.colorActive = false
    if effect.fadeTicks > 0 and wasValid then
      m.fadeActive = true
      m.fadeAt = now
      m.fadeFrom = T.opacity.full
      m.fadeNormalized = m.lastNormalized
      m.fadeValue = m.lastValue
      -- Keep the last semantic color while its truthful geometry leaves. The
      -- availability badge/text already changed above this module.
      m.targetColor = targetColor
    end
    if m.fadeActive then
      local done
      state.opacity, done = fadeOpacity(m.fadeFrom, T.opacity.muted,
        now - m.fadeAt, effect.fadeTicks)
      state.visualValid = not done
      state.smoothNormalized = m.fadeNormalized
      state.smoothValue = m.fadeValue
      if done then
        m.fadeActive = false
        m.visualColor = targetColor
      end
    else
      state.opacity = T.opacity.muted
      state.visualValid = false
      m.visualColor, m.targetColor = targetColor, targetColor
    end
    state.visualColor = m.visualColor
  end

  local allowTrigger = not paused and wasValid
  segmentMotion(widget, state, m, effect, now, allowTrigger)
  headMotion(state, m, effect, now, allowTrigger)
  m.requiresFrameMotion = m.settleAllowed or m.headActive
    or m.colorActive or m.fadeActive
  state.motionActive = m.colorActive or m.fadeActive
    or state.settleLevel > 0 or state.headBoost > 0

  m.profile = profile
  m.paletteSig = paletteSig
  m.lastAt = now
  m.rawState = state.state
  m.rawValid = state.valid
  m.rawNormalized = state.rawNormalized or 0
  return state
end

return M
