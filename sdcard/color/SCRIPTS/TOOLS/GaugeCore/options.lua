---- #########################################################################
---- #                                                                       #
---- # Gauge Pro - widget option wire format                                  #
---- #                                                                       #
---- # THE OPTION CONTRACT (verified against radio/src, EdgeTX 3.0):         #
---- #                                                                       #
---- #  * The firmware hands options to Lua as NUMBERS, never strings,       #
---- #    except String/File options:                                        #
---- #      lua_widget.cpp updateWithoutRefresh()                            #
---- #        String/File     -> lua_pushstring                              #
---- #        Integer/Switch  -> lua_pushinteger (signed)                    #
---- #        everything else -> lua_pushinteger (unsigned)                  #
---- #    Comparing a CHOICE option against its label string can therefore   #
---- #    never match.                                                       #
---- #                                                                       #
---- #  * CHOICE values are stored 1-BASED: the settings dialog reads        #
---- #    getUnsignedValue(i) - 1 and writes newValue + 1                    #
---- #    (widget_settings.cpp). Declared defaults must be 1-based too; a    #
---- #    stored 0 means "never edited" and falls back to the default.       #
---- #                                                                       #
---- #  * Option slots are POSITIONAL and typed. setDefault() resets a slot  #
---- #    only when the stored type differs, so options may only ever be     #
---- #    APPENDED - inserting or reordering silently reinterprets saved     #
---- #    model data (widget.cpp:383).                                       #
---- #                                                                       #
---- #  * Capacity is version dependent:                                     #
---- #      2.11.x  MAX_WIDGET_OPTIONS = 10 (radio and Companion)            #
---- #      2.12+   MAX_WIDGET_OPTIONS = 50                                  #
---- #    Excess options are truncated (lua_widget_factory.cpp:291), so the  #
---- #    first ten declarations are the ones that must matter.              #
---- #                                                                       #
---- # Pure Lua except for the option-type constants; unit-testable.         #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #########################################################################

local M = {}

M.CORE_CAPACITY = 10
M.EXTENDED_CAPACITY = 50

-- How many option slots this firmware supports.
function M.capacity()
  if type(getVersion) ~= "function" then return M.CORE_CAPACITY end
  local _, _, maj, minor = getVersion()
  maj, minor = tonumber(maj), tonumber(minor)
  if not maj then return M.CORE_CAPACITY end
  if maj > 2 or (maj == 2 and (minor or 0) >= 12) then
    return M.EXTENDED_CAPACITY
  end
  return M.CORE_CAPACITY
end

-- NOTE (Tanda 6 F-14 / 6.1): the option-declaration builder and the label
-- translator are NOT here. They live inline in main.lua - which runs at boot
-- for every widget on the card, used or not - so boot costs exactly one file
-- read per widget. This module's versions were deleted in Tanda 6 after
-- verifying both builders byte-identical (boot-cost check: inline=24,
-- build=24, differences 0): ONE builder remains, so the two can never drift.

-- ------------------------------------------------------------- conversion --

-- CHOICE -> 1..#choices. Accepts the stored 1-based value, falls back to the
-- declared default for 0 ("never edited") or anything out of range.
local function choiceOf(raw, count, default)
  local v = tonumber(raw)
  if not v or v < 1 or v > count then return default end
  return v
end
M.choiceOf = choiceOf

local function boolOf(raw, default)
  local v = tonumber(raw)
  if v == nil then return default end
  return v ~= 0
end

local function numberOf(raw, default)
  return tonumber(raw) or default
end

local function stringOf(raw)
  if type(raw) ~= "string" then return "" end
  return raw
end

-- Parse the raw option table into a typed config keyed by `field`.
-- Options missing from `raw` (older firmware, truncated tail) fall back to
-- their declared defaults, so every consumer sees a complete config.
function M.parse(defs, raw)
  raw = raw or {}
  local cfg = {}
  for i = 1, #defs do
    local d = defs[i]
    if d.field then
      local value = raw[d.key]
      if d.type == CHOICE then
        cfg[d.field] = choiceOf(value, #d.choices, d.default)
      elseif d.type == BOOL then
        cfg[d.field] = boolOf(value, d.default ~= 0)
      elseif d.type == STRING then
        cfg[d.field] = stringOf(value)
      elseif d.type == SOURCE then
        cfg[d.field] = numberOf(value, 0)
      else  -- VALUE, SLIDER, SWITCH, COLOR
        cfg[d.field] = numberOf(value, d.default)
      end
    end
  end
  return cfg
end

return M
