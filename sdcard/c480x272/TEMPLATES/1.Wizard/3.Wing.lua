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
-- CH1  = Elevron left
-- CH2  = Elevron Right
-- CH3  = Throttle / Motor
-- CH5  = Arm (elrs)

-- default switches
-- SA = Flaps
-- SB = Gears (retracts)
-- SC = Dual rates
-- SF↓ = Motor arm (safety)

---------------------------------------------------------------------------------------------------

local topbar_txt = "Build a wing model with a wizard"

local paticles_list = {
    "name",
    "image",
    "motor",
    "elevron",
    "dual_rates",
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
