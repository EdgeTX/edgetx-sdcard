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
-- Date: 2021-2024
local app_name = "BattAnalog"
local app_ver = "1.2"

local CELL_DETECTION_TIME = 8
local lib_sensors = loadScript("/WIDGETS/" .. app_name .. "/lib_sensors.lua", "tcd")(m_log,app_name)
local DEFAULT_SOURCE = lib_sensors.findSourceId( {"cell","VFAS","RxBt","A1", "A2"})
local useLvgl = true

local _options = {
    {"sensor"            , SOURCE, DEFAULT_SOURCE },
    {"batt_type"         , CHOICE, 1 , {"LiPo", "LiPo-HV (high voltage)", "Li-Ion"} },
    {"cbCellCount"       , CHOICE, 1 , {"Auto Detection", "1 cell", "2 cell", "3 cell", "4 cell", "5 cell", "6 cell", "8 cell", "10 cell", "12 cell", "14 cell"} },
    {"isTotalVoltage"    , BOOL  , 0      }, -- 0=Show as average Lipo cell level, 1=show the total voltage (voltage as is)
    {"color"             , COLOR , YELLOW },
}

local function translate(nam)
    local translations = {
        sensor = "Voltage Sensor",
        color = "Text Color",
        isTotalVoltage="Show Total Voltage",
        batt_type="Battery Type",
        cellCount = "Cell Count (0=auto)",
        cbCellCount = "Cell Count",
    }
    return translations[nam]
end

local function create(zone, options)
    -- imports
    local m_log = loadScript("/WIDGETS/" .. app_name .. "/lib_log.lua", "tcd")(app_name, "/WIDGETS/" .. app_name)
    local wgt = loadScript("/WIDGETS/" .. app_name .. "/logic.lua")(m_log)
    wgt.tools = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")(m_log, app_name, useLvgl)
    wgt.zone = zone
    wgt.options = options
    wgt.m_log = m_log
    wgt.log = function(fmt, ...)
        wgt.m_log.info(fmt, ...)
    end

    loadScript("/WIDGETS/" .. app_name .. "/ui_lvgl")(wgt)
    return wgt
end

-- This function allow updates when you change widgets settings
local function update(wgt, options)
    wgt.options = options

    wgt.batt_height = wgt.zone.h --???
    wgt.batt_width = wgt.zone.w
    -- wgt.log("batt_11  width: " .. wgt.batt_width .. ", height: " .. wgt.batt_height)


    local ver, radio, maj, minor, rev, osname = getVersion()
    wgt.is_valid_ver = (maj == 2 and minor >= 11)
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

local function getDxByStick(stk)
    local v = getValue(stk)
    if math.abs(v) < 150 then return 0 end
    local d = math.ceil(v / 90)
    return d
end

local function refresh(wgt, event, touchState)

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
    useLvgl = true
}
