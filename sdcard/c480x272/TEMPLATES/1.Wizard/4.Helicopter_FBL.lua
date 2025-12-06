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

-- default channels
-- CH1  = Aileron
-- CH2  = Elevator
-- CH3  = collective (pitch)
-- CH4  = Rudder (yaw)
-- CH5  = Arm (elrs)
-- CH6  = Motor (3 rpm)
-- CH7  = Tail Gain
-- CH8  = Bank (Profile/idle up)
-- CH9  = Rescue (panic)
-- CH10 = 

-- default switches
-- SA = Bank (Profile/idle up)
-- SB = 
-- SD = 
-- SH = Rescue (Panic)
-- SF↓ = Motor arm (safety)

---------------------------------------------------------------------------------------------------

local topbar_txt = "Build a Helicopter model with a wizard (Flight Controller)"

local paticles_list = {
    "name",
    "heli_channels_order",
    "heli_rates",
}

---------------------------------------------------------------------------------------------------

local wbp

local function init()
    wbp = loadScript("/TEMPLATES/1.Wizard/engine/wizard_by_presets", "btd")(topbar_txt, paticles_list)
    return wbp.init()
end

local function run(event, touchState)
    return wbp.run(event, touchState)
end

return { init=init, run=run, useLvgl=true }
