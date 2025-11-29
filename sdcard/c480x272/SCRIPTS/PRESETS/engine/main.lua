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
-- Date: 2023-2025
local ver = "0.3"

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script ...
-- send the log file that will be created on: /SCRIPTS/PRESETS/app.log

local app_name = "PresetsLoader"

local app_folder    = "/SCRIPTS/PRESETS"
local SCRIPT_FOLDER = "/SCRIPTS/PRESETS/scripts"
--chdir(app_folder)

local m_log =   loadScript(app_folder .. "/engine/lib_log"  , "btd")(app_name, app_folder)
local m_utils = loadScript(app_folder .. "/engine/lib_utils", "btd")(m_log, app_name, app_folder)

-- better font names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}


local preset_list = {
    about="---"
}
local num_of_presets = 0

local preset_script_chunk
local preset_info = {
    category="",
    name="",
    author="",
    ver="",
    help=""
}
local error_desc = nil
local exitTool = false

local preset_folder_name = "---"
local preset_selection_idx = 1

-- state machine
local STATE = {
    SPLASH = 0,
    INIT = 1,
    SELECTION_INIT = 2,
    SELECTION = 3,
    SCRIPT_RUNNER_INIT = 4,
    SCRIPT_RUNNER = 5,
    CONFIRM_REQUEST_INIT = 6,
    CONFIRM_REQUEST = 7,
    UPDATE_MODEL_INIT = 8,
    UPDATE_MODEL = 9,
    ON_END_INIT = 10,
    ON_END = 11,
    ERROR_PAGE_INIT = 12,
    ERROR_PAGE = 13,
}
local state = STATE.SPLASH

local ImgSplash     = app_folder .. "/engine/img/splash.png"
local ImgBackground = app_folder .. "/engine/img/background.png"
local ImgSummary    = app_folder .. "/engine/img/summary.png"
---------------------------------------------------------------------------------------------------
local function getVer()
    return ver
end

local function log(fmt, ...)
    m_log.info(fmt, ...)
end
---------------------------------------------------------------------------------------------------

local splash_start_time = 0
local function state_SPLASH(event, touchState)

    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    log('elapsed: %d (t.durationMili: %d)', elapsed, splash_start_time)
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    if (elapsedMili >= 50) then
        ImgSplash = nil
        state = STATE.INIT
    end

    return 0
end

local function build_topbar(prev_state, next_state, isFirstPage)
    -- log("build_topbar(%s)", preset_folder_name)
    if isFirstPage == nil then
        isFirstPage = false
    end
    if isFirstPage==false or isFirstPage==nil then
        lvgl.clear()
    end

    local bTopArea = lvgl.box({scrollDir=lvgl.SCROLL_OFF, x=0, y=0, w=LCD_W, h=30})
    bTopArea.build({
        -- {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, color=BLACK , filled=true, hide=true},
        -- {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, color=COLOR_THEME_SECONDARY2 , filled=true, hide=true},
        {type="rectangle", x=0, y=0, w=LCD_W, h=40, color=COLOR_THEME_SECONDARY1 , filled=true, visible=function() return isFirstPage==false end},
        -- {type="rectangle", x=0, y=0, w=LCD_W, h=LCD_H, file=ImgBackground},

        {type="button", x=5, y=3, w=50, h=35, text="<", visible=function() return prev_state ~= nil end,
            press=(function() state = prev_state end)
        },
        {type="button", x=LCD_W-55, y=3, w=50, h=35, text=">", visible=function() return next_state ~= nil end,
            press=(function() state = next_state end)
        },

        {type="label", x=75, y=10, color=COLOR_THEME_PRIMARY2, font=FS.FONT_8,
            text=function()
                return string.format("Preset: %s", preset_info["name"])
            end,
            visible=function() return isFirstPage==false end
        },
    })
end
---------------------------------------------------------------------------------------------------
local function state_INIT()
    log("PRESETS: init - start")
    preset_list[#preset_list+1] = "---"
    for fn in dir(SCRIPT_FOLDER) do
        preset_list[#preset_list+1] = fn
        log("PRESETS: init - found preset: [%s]", fn)
    end
    log("PRESETS: init - end")
    log("PRESETS: init - count=%d", #preset_list)
    num_of_presets = #preset_list

    state = STATE.SELECTION_INIT
    return 0
end

---------------------------------------------------------------------------------------------------
local function on_change_preset_selection(i)
    preset_folder_name = preset_list[i]
    log("Selected preset_name: %s. %s",i, preset_folder_name)

    preset_info = m_utils.readMeta(SCRIPT_FOLDER .. "/" .. preset_folder_name .. "/meta.ini")
    preset_info.icon = Bitmap.open(SCRIPT_FOLDER .. "/" .. preset_folder_name .. "/icon.png")

    log("Category: %s", preset_info["category"])
    log("preset_selection: %s", preset_info["name"])
    log("about: %s", preset_info["about"])
end

---------------------------------------------------------------------------------------------------
local function state_SELECTION_INIT()

    lvgl.clear()
    lvgl.build({
        {type="image", x=0, y=0, w=LCD_W, h=LCD_H, file=ImgBackground},
        {type="label", text="Preset:", x=75, y=65, color=BLACK},
        {type="choice", x=130, y=60, w=298, title="Select Preset",
            values=preset_list,
            get=function() return preset_selection_idx end,
            set=function(val)
                preset_selection_idx=val
                on_change_preset_selection(val)
            end
        },

        -- draw preset info
        {type="label", x=60, y=120, color=WHITE, font=FS.FONT_6,
            text=function()
                if preset_info["about"] == nil then
                    return "---"
                end
                local about = string.gsub(preset_info["about"], "/n", "\n")
                -- log("fix about: [%s] [%s]", preset_info["about"], about)
                return about
            end
        },

        -- dreaw status bar
        {type="label", x=10, y=252, color=BLACK, font=FS.FONT_6,
            text=function()
                return string.format("Category: %s", preset_info["category"])
            end
        },
        {type="label", x=300, y=250, color=BLACK, font=FS.FONT_6,
            text=function()
                return string.format("ver: %s  author: %s", preset_info["ver"], preset_info["author"])
            end
        },
        {type="image", x=LCD_W-95, y=105, w=50, h=50, file=function() return string.format(SCRIPT_FOLDER .. "/%s/icon.png", preset_folder_name) end},

    })

    build_topbar(nil, STATE.SCRIPT_RUNNER_INIT, true)

    lvgl.build({
        -- {type="image", x=0, y=0, w=LCD_W, h=LCD_H, file=ImgBackground},
        {type="label", text="Preset Loader ", x=145, y=8, color=COLOR_THEME_PRIMARY1, font=FS.FONT_8},

    })

    -- when returning to selection, re-apply current selection
    on_change_preset_selection(preset_selection_idx)
    -- preset_folder_name = "NA"

    state = STATE.SELECTION
    return 0
end

---------------------------------------------------------------------------------------------------
local function state_SELECTION(event, touchState)
    if event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
        log("(%s) %s - %s", page, touchState.x, touchState.y)
    elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
        log("(%s) %s - %s", page, touchState.x, touchState.y)
        log("current_preset_selection=%s", preset_selection_idx)

        if preset_selection_idx > 1 then
            state = STATE.SCRIPT_RUNNER_INIT
            return 0
        end
    end

    if (event == EVT_VIRTUAL_NEXT_PAGE) then
        if preset_selection_idx > 1 then
            state = STATE.SCRIPT_RUNNER_INIT
            return 0
        end
    end

    return 0
end

---------------------------------------------------------------------------------------------------

local function state_SCRIPT_RUNNER_INIT()
    log("state_SCRIPT_RUNNER_INIT(%s)", preset_folder_name)

    build_topbar(STATE.SELECTION_INIT, STATE.CONFIRM_REQUEST_INIT)

    local bPresetArea = lvgl.box({scrollDir=lvgl.SCROLL_VER, x=0, y=30, w=LCD_W, h=LCD_H-30})
    bPresetArea:image({x=LCD_W-95, y=10, w=100, h=100, file=function() return string.format(SCRIPT_FOLDER .. "/%s/icon.png", preset_folder_name) end})


    -- validate module exist
    local script_name = SCRIPT_FOLDER .. "/" .. preset_folder_name .. "/main.lua"
    local code_chunk = loadScript(script_name, "btd")
    if code_chunk == nil then
        error_desc = "File not found: " .. script_name
        return
    end

    preset_script_chunk = code_chunk(m_log,m_utils,bPresetArea)
    if preset_script_chunk == nil then
        error_desc = "failed to load preset file:\n " .. script_name .. " \n"
        return nil
    end
    log("%s - loaded OK", preset_folder_name)

    local the_ver = preset_script_chunk.getVer()
    log("the_ver: " .. the_ver)

    local err = preset_script_chunk.init()
    if err ~= nil then
        log("preset.init() returned error: %s", err)
        error_desc = err
        state = STATE.ERROR_PAGE_INIT
        return 0
    end

    log("state_SCRIPT_RUNNER_INIT() - end")
    state = STATE.SCRIPT_RUNNER
    return 0
end

local function state_SCRIPT_RUNNER(event, touchState)
    --log("state_SCRIPT_RUNNER()")

    if event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
        log("(%s) %s - %s", page, touchState.x, touchState.y)
    elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
        log("(%s) %s - %s", page, touchState.x, touchState.y)
        if preset_selection_idx > 1 then
            state = STATE.CONFIRM_REQUEST_INIT
            return 0
        end
    end

    if (event == EVT_VIRTUAL_NEXT_PAGE)
        or
        (event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160)) then
        state = STATE.CONFIRM_REQUEST_INIT
        return 0
    end
    --if (event == EVT_VIRTUAL_PREV) or (event == EVT_VIRTUAL_PREV_PAGE) then
    if (event == EVT_VIRTUAL_PREV_PAGE)
        or
        (event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160)) then

        state = STATE.SELECTION_INIT
        return 0
    end

    return 0
end

---------------------------------------------------------------------------------------------------

local function state_CONFIRM_REQUEST_INIT(event)
    log("state_CONFIRM_REQUEST_INIT()")

    build_topbar(STATE.SCRIPT_RUNNER_INIT, nil)

    lvgl.build({
        {type="label",text="Update the current model?", x=60, y=80, color=COLOR_THEME_PRIMARY1, font=FS.FONT_12},
        {type="label",text="Note: this will change the current plane settings!!", x=60, y=120, color=RED},

        {type="button", x=LCD_W-240, y=LCD_H-45, w=110, h=40, text="Cancel",
            press=(function()  exitTool = true end)
        },
        {type="button", x=LCD_W-120, y=LCD_H-45, w=110, h=40, text="Apply",
            press=(function() state = STATE.UPDATE_MODEL_INIT end)
        },
    })

    state = STATE.CONFIRM_REQUEST
    return 0
end

local function state_CONFIRM_REQUEST(event, touchState)
    --log("state_CONFIRM_REQUEST()")
    if (event == EVT_VIRTUAL_PREV_PAGE) then
        state = STATE.SCRIPT_RUNNER_INIT
        return 0
    end

    return 0
end

---------------------------------------------------------------------------------------------------

local function state_UPDATE_MODEL_INIT()
    preset_script_chunk.do_update_model()
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

    build_topbar(nil, nil)

    lvgl.build({
        {type="label",text="Model updated.", x=50, y=80, color=COLOR_THEME_PRIMARY1, font=FS.FONT_12},
        {type="image", x=LCD_W-120, y=50, w=100, h=200, file=ImgSummary},
        {type="button", x=LCD_W-120, y=LCD_H-45, w=110, h=40, text="Done",
            press=(function() exitTool = true end)
        },
    })

    state = STATE.ON_END
    return 0
end
---------------------------------------------------------------------------------------------------
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
    if event == EVT_VIRTUAL_ENTER_LONG or event == EVT_VIRTUAL_PREV_PAGE or event == EVT_VIRTUAL_EXIT then
        log("state_ERROR_PAGE() - exit")
        state = STATE.SELECTION
        return 0
    end
    return 0
end

---------------------------------------------------------------------------------------------------

local function init()
    lcd.drawBitmap(ImgSplash, 0, 0)

end

local function run(event, touchState)
    if (exitTool) then return 2 end

    if state == STATE.SPLASH then
        log("STATE.SPLASH")
        return state_SPLASH()

    elseif state == STATE.INIT then
        log("STATE.INIT")
        return state_INIT()

    elseif state == STATE.SELECTION_INIT then
        log("STATE.SELECTION_INIT")
        return state_SELECTION_INIT(event, touchState)
    elseif state == STATE.SELECTION then
        -- log("STATE.SELECTION")
        return state_SELECTION(event, touchState)

    elseif state == STATE.SCRIPT_RUNNER_INIT then
        log("STATE.SCRIPT_RUNNER_INIT")
        return state_SCRIPT_RUNNER_INIT(event, touchState)
    elseif state == STATE.SCRIPT_RUNNER then
        log("STATE.SCRIPT_RUNNER")
        return state_SCRIPT_RUNNER(event, touchState)

    elseif state == STATE.CONFIRM_REQUEST_INIT then
        log("STATE.CONFIRM_REQUEST_INIT")
        return state_CONFIRM_REQUEST_INIT(event, touchState)
    elseif state == STATE.CONFIRM_REQUEST then
        log("STATE.CONFIRM_REQUEST")
        return state_CONFIRM_REQUEST(event, touchState)

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
