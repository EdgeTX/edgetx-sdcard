local topbar_txt, paticles_list = ...

---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
---- #                                                                       #
---- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################


-- Author: Offer Shmuely
-- Date: 2025
local ver = "0.1"

--[[
This is the engine for the "Wizard by Presets" tool.
- Uses a single, touch‑enabled page with vertical scrolling instead of many separate pages, making the workflow faster and more intuitive.
- Builds the wizard from small reusable “particles” (motor, flaps, tail, beeper, etc.).
- The same particles can be shared between different model wizards (plane, glider, wing, heli, multirotor).
- Particles are also used by the preset script engine, so one implementation powers both interactive wizards and one‑click presets.
- This keeps behavior, channel layout and safety logic consistent, and makes maintenance and updates much easier.
- Sets proper, descriptive names on mixer lines
- Sets proper, descriptive names on channels (output) lines
]]



local app_name = "WizardByPresets"

local app_folder    = "/TEMPLATES/1.Wizard"
local ENGINE_FOLDER = app_folder .. "/engine"
local SCRIPT_FOLDER = app_folder .. "/particles"

local m_log =   loadScript(ENGINE_FOLDER .. "/lib_log"  , "btd")(app_name, app_folder)
local m_utils = loadScript(ENGINE_FOLDER .. "/lib_utils", "btd")(m_log, app_name, app_folder)

-- better font names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local lvSCALE = lvgl.LCD_SCALE or 1

local preset_list = {
}

local preset_info = {
    category="",
    name="",
    author="",
    ver="",
    help=""
}
local error_desc = nil
local exitTool = false

-- state machine
local STATE = {
    MAIN_INIT = 2,
    MAIN = 3,
    UPDATE_MODEL_INIT = 8,
    UPDATE_MODEL = 9,
    ON_END_INIT = 10,
    ON_END = 11,
    ERROR_PAGE_INIT = 12,
    ERROR_PAGE = 13,
}
local state = STATE.MAIN_INIT

local ImgBackground = ENGINE_FOLDER .. "/img/background.png"
local ImgSummary    = ENGINE_FOLDER .. "/img/summary.png"
---------------------------------------------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

local function load_preset(preset_name, pos_y, page)
    log("load_preset(%s)", preset_name)

    local bPresetArea1 = page:box({scrollDir=lvgl.SCROLL_OFF, x=0, y=pos_y, w=LCD_W})
    -- bPresetArea1:image({x=LCD_W-95, y=10, w=100, h=100, file=function() return string.format(SCRIPT_FOLDER .. "/%s/icon.png", preset_name) end})

     --------------------------------------------------------------
    -- load particle
    local script_name = SCRIPT_FOLDER .. "/" .. preset_name .. "/main.lua"
    local preset_script_lib = loadScript(script_name, "btd")(m_log, m_utils, SCRIPT_FOLDER .. "/" .. preset_name)
    if preset_script_lib == nil then
        error_desc = "failed to load preset file:\n " .. script_name .. " \n"
        return nil, nil
    end
    --------------------------------------------------------------

    preset_info = m_utils.readMeta(SCRIPT_FOLDER .. "/" .. preset_name .. "/meta.ini")
    -- preset_info.icon = bitmap.open(SCRIPT_FOLDER .. "/" .. preset_name .. "/icon.png")
    log("Category: %s", preset_info["category"])
    log("name: %s", preset_info["name"])
    log("about: %s", preset_info["about"])

    local topbar_h = 30
    local preset_height = preset_script_lib.height + topbar_h
    bPresetArea1:rectangle({x=5, y=0, w=LCD_W-15, h=preset_height, 
        color=lcd.RGB(0xFFEEAD), 
        -- color=COLOR_THEME_FOCUS, 
        filled=true, rounded=5, thickness=2 })
    bPresetArea1:rectangle({x=5, y=0, w=LCD_W-15, h=topbar_h, color=GREY , filled=true, rounded=5, thickness=2 })
    bPresetArea1:label({x=20, y=5, color=WHITE, font=BOLD, text=preset_info["name"]})

    local bPresetArea2 = bPresetArea1:box({x=0, y=topbar_h+5, h=5+preset_height, w=LCD_W, scrollDir=lvgl.SCROLL_OFF})

    --------------------------------------------------------------
    -- init the particle to create it's UI inside bPresetArea2
    local err = preset_script_lib.init(bPresetArea2)
    --------------------------------------------------------------

    if err ~= nil then
        log("preset.init() returned error: %s", err)
        error_desc = err
        state = STATE.ERROR_PAGE_INIT
        return nil, nil
    end

    preset_list[#preset_list+1] = preset_script_lib
    return preset_script_lib, bPresetArea1, preset_height
end

---------------------------------------------------------------------------------------------------
local function state_MAIN_INIT()

    lvgl.clear()
    local page = lvgl.page({x=0, y=0, w=LCD_W, h=0, title=topbar_txt, align=lvgl.CENTER, scrollDir=lvgl.SCROLL_ALL,
        scrollBar=true,
        backButton=true,
        back=(function() exitTool = true end)
    })

    -- loop through paticles_list and load each preset UI block
    local preset, box, preset_height
    local last_height = 5
    for i = 1, #paticles_list do
        local particle_name = paticles_list[i]
        preset, box, preset_height = load_preset(particle_name, last_height, page)
        last_height = last_height + preset_height + 10
    end

    -- Apply / Cancel buttons
    local space_left = 6*lvSCALE
    local space_right = 12*lvSCALE
    local space_middle = 12*lvSCALE
    local btn_w = (LCD_W-space_left-space_right-space_middle)/2
    page:build({
        {type="box", x=0, y=last_height, w=LCD_W, scrollDir=lvgl.SCROLL_OFF,
            children={
                {type="button", text="Cancel", x=space_left, y=2, w=btn_w, h=40*lvSCALE, press=(function()  exitTool = true end)},
                {type="button", text="Apply" , x=LCD_W-space_right-btn_w, y=2, w=btn_w, h=40*lvSCALE, press=(function() state = STATE.UPDATE_MODEL_INIT end)},
                {type="box", x=0, y=40*lvSCALE, w=LCD_W, h=15, color=RED} -- rectangle/box ???
            }
        }
    })

    state = STATE.MAIN
    return 0
end

local function state_MAIN(event, touchState)
    return 0
end

---------------------------------------------------------------------------------------------------

local function state_UPDATE_MODEL_INIT()
    log("state_UPDATE_MODEL: init - start")
    log("PRESETS: count=%d", #preset_list)

    lcd.clear()
    model.defaultInputs()
    model.deleteMixes()

    for i = 1, #preset_list do
        log("Applying preset %d/%d", i, #preset_list)
        preset_list[i].do_update_model()
    end
    log("state_UPDATE_MODEL: end")

    state = STATE.UPDATE_MODEL
    return 0
end

local function state_UPDATE_MODEL(event, touchState)
    state = STATE.ON_END_INIT
    return 0
end

---------------------------------------------------------------------------------------------------

local function state_ON_END_INIT(event, touchState)
    log("state_ON_END_INIT()")

    lvgl.clear()
    lvgl.build({
        {type="page", 
            x=0, y=0, w=LCD_W, h=LCD_H, title=topbar_txt, align=lvgl.CENTER, scrollDir=lvgl.SCROLL_OFF,
            scrollBar=false,
            backButton=true,
            back=(function() exitTool = true end),

            children = {
                {type="label",text="Model updated.", x=50, y=40*lvSCALE, color=COLOR_THEME_PRIMARY1, font=FS.FONT_12},
                {type="image", x=LCD_W-120, y=0, w=100, h=200, file=ImgSummary},
                {type="button", x=20, y=LCD_H-100*lvSCALE, w=LCD_W-40, h=40*lvSCALE, text="Done",
                    press=(function() exitTool = true end)
                },
            }
        }
    })

    state = STATE.ON_END
    return 0
end

local function state_ON_END(event, touchState)
    return 0
end
---------------------------------------------------------------------------------------------------

local function state_ERROR_PAGE_INIT(event, touchState)
    lvgl.clear()
    lvgl.build({
        {type="label",text=error_desc or "Unknown error",x=40,y=80,w=LCD_W - 80,color=COLOR_THEME_PRIMARY1},
        {type="label",text="Hold [RTN] to exit.",x=100,y=200,color=COLOR_THEME_PRIMARY1}
    })
    state = STATE.ERROR_PAGE
    return 0
end

local function state_ERROR_PAGE(event, touchState)
    return 0
end

---------------------------------------------------------------------------------------------------

local function init()

end

---------------------------------------------------------------------------------------------------

local function run(event, touchState)
    if (exitTool) then return 2 end

    if state == STATE.MAIN_INIT then
        log("STATE.MAIN_INIT")
        return state_MAIN_INIT(event, touchState)
    elseif state == STATE.MAIN then
        -- log("STATE.MAIN")
        return state_MAIN(event, touchState)

    elseif state == STATE.UPDATE_MODEL_INIT then
        log("STATE.UPDATE_MODEL_INIT")
        return state_UPDATE_MODEL_INIT(event, touchState)
    elseif state == STATE.UPDATE_MODEL then
        log("STATE.UPDATE_MODEL")
        return state_UPDATE_MODEL(event, touchState)

    elseif state == STATE.ON_END_INIT then
        log("STATE.ON_END_INIT")
        return state_ON_END_INIT(event, touchState)
    elseif state == STATE.ON_END then
        log("STATE.ON_END")
        return state_ON_END(event, touchState)

    elseif state == STATE.ERROR_PAGE_INIT then
        --log("STATE.ERROR_PAGE_INIT")
        return state_ERROR_PAGE_INIT(event, touchState)
    elseif state == STATE.ERROR_PAGE then
        --log("STATE.ERROR_PAGE")
        return state_ERROR_PAGE(event, touchState)
    end

    return 0
end


return { init=init, run=run, useLvgl=true }
