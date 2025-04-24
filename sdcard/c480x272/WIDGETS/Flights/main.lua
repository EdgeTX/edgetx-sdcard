local app_name = "Flights"

local tool = nil

local default_flight_starting_duration = 30  -- 30 sec to detect flight success

-- for backward compatibility
local function getSwitchIds(key)
    local OS_SWITCH_ID = {
        ["2.7"]  = {SA=112, SB=113, SC=114, SD=115, SE=116, SF=117, STICK3 = 89, INPUT3 = 3, CH3 = 204},
        ["2.8"]  = {SA=120, SB=121, SC=122, SD=123, SE=124, SF=125, STICK3 = 89, INPUT3 = 3, CH3 = 212},
        ["2.9"]  = {SA=120, SB=121, SC=122, SD=123, SE=124, SF=125, STICK3 = 89, INPUT3 = 3, CH3 = 212},
        ["2.10"] = {SA=126, SB=127, SC=128, SD=129, SE=130, SF=131, STICK3 = 89, INPUT3 = 3, CH3 = 228},
        ["2.11"] = {SA=126, SB=127, SC=128, SD=129, SE=130, SF=131, STICK3 = 89, INPUT3 = 3, CH3 = 228},
    }
    local ver, radio, maj, minor, rev, osname = getVersion()
    local os1 = string.format("%d.%d", maj, minor)
    return OS_SWITCH_ID[os1][key]
end

local DEFAULT_MOTOR_CHANNEL_ID = getSourceIndex("CH3") or getSourceIndex("thr111") or getSwitchIds("CH3")  -- motor_channel=CH3

local options = {
    { "arm_switch_id"       , SWITCH, "SF"..CHAR_UP}, -- CHAR_UP|-|CHAR_DOWN
    { "motor_channel"       , SOURCE, DEFAULT_MOTOR_CHANNEL_ID },
    { "heli_mode"           , BOOL, 0},            -- ignore motor direction detection, and throttle position
    { "text_color"          , COLOR, YELLOW},--, COLOR_THEME_PRIMARY2 },
    { "min_flight_duration" , VALUE, default_flight_starting_duration, -30, 120 },
    { "enable_sounds"       , BOOL, 1},            -- 0=no sound, 1=play blip sound on increment & on flight end
    { "use_telemetry"       , BOOL, 1},            -- 0=do not use telemetry, 1=use telemetry in state machine
    { "auto_debug"          , BOOL, 1},            -- show debug status on screen if widget is large enough
    -- { "ground_on_switch"    , BOOL, 0},            -- 0=auto detect ground by time, 1=ground on switch is used (not auto)
}

local function translate(name)
    local translations = {
        arm_switch_id="Arm Switch Position",
        motor_channel="Motor Channel",
        heli_mode="Heli mode (ignore motor ch)",
        min_flight_duration = "Min flight duration (sec)",
        text_color = "Text color",
        enable_sounds = "Enable sounds",
        use_telemetry = "Use telemetry",
        -- ground_on_switch = "Ground on switch",
        auto_debug = "Auto debug",
    }
    return translations[name]
end


local function create(zone, options)
    -- print(string.format("1111 Flights create: %s", name))
    tool = assert(loadScript("/WIDGETS/"..app_name.."/app.lua", "tcd"))()
    return tool.create(zone, options)
end
local function update(wgt, options) return tool.update(wgt, options) end
local function background(wgt)      return tool.background(wgt)      end
local function refresh(wgt)         return tool.refresh(wgt)         end

return {name=app_name, options=options, translate=translate, create=create,update = update, refresh=refresh, background=background, useLvgl=true}
