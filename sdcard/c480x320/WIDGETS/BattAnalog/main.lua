--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for RadioMaster TX16S                         #
# Copyright "Offer Shmuely"                                             #
#                                                                       #
# License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
#                                                                       #
# This program is free software; you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License version 2 as     #
# published by the Free Software Foundation.                            #
#                                                                       #
# This program is distributed in the hope that it will be useful        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
#########################################################################


-- This widget display a graphical representation of a Lipo/Li-ion/LIHV (not other types) battery level,
-- it will automatically detect the cell amount of the battery.
-- it will take a lipo/li-ion voltage that received as a single value (as opposed to multi cell values send while using FLVSS liPo Voltage Sensor)
-- common sources are:
--   * Transmitter Battery
--   * expressLRS pwm receivers (ER6/ER8/SuperP14ch)
--   * FrSky VFAS
--   * A1/A2 analog voltage
--   * mini quad flight controller
--   * radio-master 168
--   * OMP m2 heli

]]

-- Widget to display the levels of Lipo battery from single analog source
-- Author : Offer Shmuely
-- Date: 2021-2025
local app_name = "BattAnalog"
local app_ver = "1.6"

local _options = {
    {"sensor"            , SOURCE, "RxBt" },
    -- should work soon {"sensor", SOURCE, {"cell","VFAS","RxBt","A1", "A2"} },
    {"batt_type"         , CHOICE, 1 , {"LiPo", "LiPo-HV (high voltage)", "Li-Ion", "LifePO4"} },
    {"cbCellCount"       , CHOICE, 1 , {"Auto Detection", "1 cell","2 cell","3 cell","4 cell","5 cell","6 cell","7 cell","8 cell","9 cell","10 cell", "11 cell","12 cell","13 cell","14 cell"} },
    {"isTotalVoltage"    , BOOL  , 0      }, -- 0=Show as average Lipo cell level, 1=show the total voltage (voltage as is)
    {"color"             , COLOR , YELLOW },
    {"isTelemCellV"      , BOOL  , 0},
    -- {"isTelemCellPerc"   , BOOL  , 0},
}

local function translate(name)
    local translations = {
        sensor = "Voltage Sensor",
        color = "Text Color",
        isTotalVoltage="Show Total Voltage",
        batt_type="Battery Type",
        cellCount = "Cell Count (0=auto)",
        cbCellCount = "Cell Count",
        isTelemCellV = "Generate Telemetry Cell",
        isTelemCellPerc = "Generate Telemetry Cell%",

    }
    return translations[name]
end

local function create(zone, options)
    -- imports
    local m_log = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "btd")(app_name, "/WIDGETS/" .. app_name)
    local wgt   = loadScript("/WIDGETS/" .. app_name .. "/logic.lua", "btd")(m_log)
    wgt.tools   = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "btd")(m_log, app_name, true)
    wgt.zone = zone
    wgt.options = options
    wgt.m_log = m_log
    wgt.log = function(fmt, ...)
        wgt.m_log.info(fmt, ...)
    end

    loadScript("/WIDGETS/" .. app_name .. "/ui_lvgl", "btd")(wgt)
    return wgt
end

-- This function allow updates when you change widgets settings
local function update(wgt, options)
    wgt.options = options

    wgt.batt_height = wgt.zone.h
    wgt.batt_width = wgt.zone.w

    local ver, radio, maj, minor, rev, osname = getVersion()
    local nVer = maj*1000000 + minor*1000 + rev
    --wgt.log("version: %s, %s %s %s %s", string.format("%d.%03d.%03d", maj, minor, rev), nVer<2011000, nVer>2011000, nVer>=2011000, nVer>=2011000)
    wgt.is_valid_ver = (nVer>=2011000)
    if wgt.is_valid_ver==false then
        local lytIvalidVer = {
            {
                type=LVGL_DEF.type.LABEL, x=0, y=0, font=0,
                text="!! this widget \nis supported only \non ver 2.11 and above",
                color=RED
            }
        }
        lvgl.build(lytIvalidVer)
        return
    end

    wgt.update_logic(wgt, options)
    wgt.update_ui()
end

local function background(wgt)
    wgt.background()
end

-- local function getDxByStick(stk)
--     local v = getValue(stk)
--     if math.abs(v) < 150 then return 0 end
--     local d = math.ceil(v / 90)
--     return d
-- end

-- local function debugChangeSize(wgt)
--     local is_need_update = false

--     local dw = getDxByStick("ail")
--     wgt.batt_width = wgt.batt_width + dw
--     wgt.batt_width = math.max(10, math.min(480, wgt.batt_width))
--     is_need_update = is_need_update or (dw ~= 0)

--     local dh = getDxByStick("ele")
--     wgt.batt_height = wgt.batt_height - dh
--     wgt.batt_height = math.max(10, math.min(272, wgt.batt_height))
--     is_need_update = is_need_update or (dh ~= 0)

--     if (is_need_update == true) then
--         wgt.zone.w = wgt.batt_width
--         wgt.zone.h = wgt.batt_height
--         wgt.update_ui()
--     end
-- end

local function refresh(wgt, event, touchState)
    wgt.background()

    -- debugChangeSize(wgt)

    wgt.refresh(event, touchState)
end

return {
    name = app_name,
    options = _options,
    create = create,
    update = update,
    background = background,
    refresh = refresh,
    translate=translate,
    useLvgl=true
}
