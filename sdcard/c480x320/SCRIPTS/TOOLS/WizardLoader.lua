local toolName = "TNS|Wizard Loader|TNE"

local BackgroundImg = Bitmap.open("/SCRIPTS/WIZARD/img/background.png")
local planeIcon = Bitmap.open("/SCRIPTS/WIZARD/img/icons/plane.png")
local gliderIcon = Bitmap.open("/SCRIPTS/WIZARD/img/icons/glider.png")
local multirotorIcon = Bitmap.open("/SCRIPTS/WIZARD/img/icons/multirotor.png")

local w, h
local selWizard = 1
local numOfWizards = 3

local iconWidth = 85
local iconHeight = 130
local margin = 40

local iconX = {38, 198, 358}
local iconY = {100, 100, 100}

local touchX
local touchY

local function drawPage()
    lcd.clear()
    lcd.drawBitmap(BackgroundImg, 0, 0)

    lcd.drawFilledRectangle(70, 20, 350, 40, WHITE, 50)
    lcd.drawText(240, 20, "Choose Wizard to run...", CENTER + DBLSIZE + BLACK)

    lcd.drawBitmap(planeIcon, iconX[1], iconY[1])
    lcd.drawBitmap(gliderIcon, iconX[2], iconY[2])
    lcd.drawBitmap(multirotorIcon, iconX[3], iconY[3])

    lcd.drawRectangle(iconX[selWizard] - 2, iconY[selWizard] - 1, iconWidth + 4,
                      iconHeight + 4, RED, 2)
end

local function launchWizard()
    -- print(selWizard)
    chdir("/SCRIPTS/WIZARD")
    if (selWizard == 1) then
        return "/SCRIPTS/WIZARD/plane.lua"
    elseif (selWizard == 2) then
        return "/SCRIPTS/WIZARD/glider.lua"
    elseif (selWizard == 3) then
        return "/SCRIPTS/WIZARD/multirotor.lua"
    end
end

local function init() selWizard = 1 end

local function run(event, touchState)
    drawPage()

    if (event == nil) then
        error("Cannot be run as a model script!")
        return 2
    elseif (event == EVT_VIRTUAL_NEXT) or (event == EVT_VIRTUAL_NEXT_PAGE) then
        selWizard = selWizard + 1
        if (selWizard > numOfWizards) then
            selWizard = 1
        elseif (selWizard < 1) then
            selWizard = numOfWizards
        end
    elseif (event == EVT_VIRTUAL_PREV) or (event == EVT_VIRTUAL_PREV_PAGE) then
        selWizard = selWizard - 1
        if (selWizard > numOfWizards) then
            selWizard = 1
        elseif (selWizard < 1) then
            selWizard = numOfWizards
        end
    elseif (event == EVT_VIRTUAL_ENTER) or (event == EVT_VIRTUAL_ENTER_LONG) then
        return launchWizard()
    elseif (event == EVT_TOUCH_BREAK) or (event == EVT_TOUCH_TAP) then
        touchX = touchState.x
        touchY = touchState.y
        if (touchX > iconX[1]) and (touchX < (iconX[1] + iconWidth)) then
            if (touchY > iconY[1]) and (touchY < (iconY[1] + iconHeight)) then
                selWizard = 1
                return launchWizard()
            end
        elseif (touchX > iconX[2]) and (touchX < (iconX[2] + iconWidth)) then
            if (touchY > iconY[2]) and (touchY < (iconY[2] + iconHeight)) then
                selWizard = 2
                return launchWizard()
            end
        elseif (touchX > iconX[3]) and (touchX < (iconX[3] + iconWidth)) then
            if (touchY > iconY[3]) and (touchY < (iconY[3] + iconHeight)) then
                selWizard = 3
                return launchWizard()
            end
        end
    elseif (event == EVT_MENU_LONG) then
        -- exit script
        return 2
    end

    return 0
end

return {init = init, run = run}
