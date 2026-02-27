local app_name = "Flights"

local tool = nil

local default_flight_starting_duration = 30  -- 30 sec to detect flight success

local triggerTypeDefs = {
    labels = {
        "1. Plane with Telemetry",
        "2. Plane no Telemetry",
        "3. Heli [RPM]",
        "4. Heli [Arm]",
        "5. By switch",
        "6. DLG [Height]",
        "7. Glider [Height]",
    },
    info = {
        {desc = "1=Plane with Telemetry (mot+Arm+Telm)", file = "1_plane_tlm.lua"    },
        {desc = "2=Plane no Telemetry (mot+Arm)",        file = "2_plane_no_tlm.lua" },
        {desc = "3=Heli [RPM] (RPM+Telm)",               file = "3_heli_rpm.lua"     },
        {desc = "4=Heli [Arm] (Arm+Telm)",               file = "4_heli_arm.lua"     },
        {desc = "5=By switch",                           file = "5_by_switch.lua"    },
        {desc = "6=DLG [Vario] (Height)",               file = "6_dlg.lua"          },
        {desc = "7=Glider [Vario] (mot+Arm+Height)",    file = "7_glider.lua"       },
    }
}

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
    { "triggerType"         , CHOICE, 1 , triggerTypeDefs.labels},
    { "arm_switch_id"       , SWITCH, "SF"..CHAR_UP}, -- CHAR_UP|-|CHAR_DOWN
    { "motor_channel"       , SOURCE, DEFAULT_MOTOR_CHANNEL_ID },
    { "text_color"          , COLOR, YELLOW},--, COLOR_THEME_PRIMARY2 },
    { "min_flight_duration" , VALUE, default_flight_starting_duration, -30, 120 },
    { "enable_sounds"       , BOOL, 1},            -- 0=no sound, 1=play blip sound on increment & on flight end
    { "auto_debug"          , BOOL, 1},            -- show debug status on screen if widget is large enough
}

local function translate(name)
    local translations = {
        arm_switch_id="Arm Switch Position",
        motor_channel="Motor Channel",
        min_flight_duration = "Min flight duration (sec)",
        text_color = "Text color",
        enable_sounds = "Enable sounds",
        triggerType = "Type",
        auto_debug = "Auto debug",
    }
    return translations[name]
end


local function create(zone, options)
    -- print(string.format("1111 Flights create: %s", name))
    tool = assert(loadScript("/WIDGETS/"..app_name.."/app.lua", "btd"))(triggerTypeDefs)
    return tool.create(zone, options)
end
local function update(wgt, options) return tool.update(wgt, options) end
local function background(wgt)      return tool.background(wgt)      end
local function refresh(wgt)         return tool.refresh(wgt)         end

return {name=app_name, options=options, translate=translate, create=create,update = update, refresh=refresh, background=background, useLvgl=true}
