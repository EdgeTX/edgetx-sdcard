---- #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
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

-- Author: 3djc (2017)
-- Update by: Offer Shmuely (2023)
-- Update by: Alexander Gnauck (2025)

local wizardType = ...

local RUN_DIR = "/TEMPLATES/1.Wizard/lib"
local IMG_DIR = "/TEMPLATES/1.Wizard/img"

local RUDDER_NAME_AIL = (wizardType ~= "wing") and "Aileron" or "Elevron"
local WIZARD_TITLE = string.gsub(string.lower(wizardType), "^%l", string.upper) .. " Wizard"

local modelConfig = loadScript(RUN_DIR .. "/model-config.lua")()
local wizard = loadScript(RUN_DIR .. "/wizard-ui.lua")()

local exitWizard = false

local page = 1
local pages = {}

-- TODO change this for production
-- local folder = "/TEMPLATES/1.Wizard/"

local STICK_NUMBER_AIL = 3
local STICK_NUMBER_ELE = 1
local STICK_NUMBER_THR = 2
local STICK_NUMBER_RUD = 0

-- # TODO, looks like this is not used anywhere
-- local defaultChannel_AIL = defaultChannel(STICK_NUMBER_AIL) + 1
-- local defaultChannel_ELE = defaultChannel(STICK_NUMBER_ELE) + 1
-- local defaultChannel_THR = defaultChannel(STICK_NUMBER_THR) + 1
-- local defaultChannel_RUD = defaultChannel(STICK_NUMBER_RUD) + 1

local defaultChannel_0_AIL = defaultChannel(STICK_NUMBER_AIL)
local defaultChannel_0_ELE = defaultChannel(STICK_NUMBER_ELE)
local defaultChannel_0_THR = defaultChannel(STICK_NUMBER_THR)
local defaultChannel_0_RUD = defaultChannel(STICK_NUMBER_RUD)

local function getImagePath(filename)
	return IMG_DIR .. "/" .. wizardType .. "/" .. filename
end

-- Select the next or previous page
local function selectPage(step)
	page = page + step
	pages[page]()
end

local MotorFields = {
	is_motor = { id = "is_motor", is_visible = 1, isActive = true, value = 1, avail_values = { "No", "Yes" } },
	motor_ch = {
		id = "motor_ch",
		is_visible = 1,
		isActive = true,
		value = defaultChannel_0_THR,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	},
	is_arm = { id = "is_arm", is_visible = 1, isActive = true, value = 1, avail_values = { "No", "Yes" } },
	arm_switch = {
		id = "arm_switch",
		is_visible = 1,
		isActive = true,
		value = 5,
		avail_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" },
	},
}
local function runMotorConfig()
	lvgl.clear()

	local children1 = {

		wizard.settings({
			title = "Have a motor?",
			children = {
				{
					type = "toggle",
					get = function()
						return MotorFields.is_motor.value
					end,
					set = function(val)
						MotorFields.is_motor.value = val
					end,
				},
			},
		}),

		wizard.settings({
			title = "Motor channel",
			children = {
				{
					type = "choice",
					values = MotorFields.motor_ch.avail_values,
					get = function()
						return MotorFields.motor_ch.value + 1
					end,
					set = function(val)
						MotorFields.motor_ch.value = val - 1
					end,
				},
			},
			visible = function()
				return MotorFields.is_motor.value
			end,
		}),

		wizard.settings({
			title = "Safety Switch",
			children = {
				{
					type = "toggle",
					get = function()
						return MotorFields.is_arm.value
					end,
					set = function(val)
						MotorFields.is_arm.value = val
					end,
				},
				{
					type = "choice",
					values = MotorFields.arm_switch.avail_values,
					visible = function()
						return MotorFields.is_arm.value == 1
					end,
					get = function()
						return MotorFields.arm_switch.value + 1
					end,
					set = function(val)
						MotorFields.arm_switch.value = val - 1
					end,
				},
			},
			visible = function()
				return MotorFields.is_motor.value
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("prop.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Motor Settings",
		hasPrevious = false,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = children1,
		children2 = children2,
	})

	lvgl.build(page)
end

-- fields format : {[1]x, [2]y, [3]COMBO, [4]visible, [5]default, [6]{values}}
-- fields format : {[1]x, [2]y, [3]VALUE, [4]visible, [5]default, [6]min, [7]max}
local AilFields = {
	-- TODO add "1 with v-cable text" somewhere
	ail_type = {
		id = "ail_type",
		x = 50,
		y = 70,
		w = 200,
		is_visible = 1,
		value = 2,
		avail_values = { "None", "One", "Two" },
	},
	ail_ch_a = {
		id = "ail_ch_a",
		x = 100,
		y = 120,
		w = 0,
		is_visible = 1,
		value = defaultChannel_0_AIL,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	}, -- Ail1 chan
	ail_ch_b = {
		id = "ail_ch_b",
		x = 100,
		y = 160,
		w = 0,
		is_visible = 1,
		value = defaultChannel_0_AIL + 1,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	}, -- Ail2 chan
}

local function runAilConfig()
	lvgl.clear()

	local children1 = {

		wizard.settings({
			title = "Number of " .. RUDDER_NAME_AIL,
			children = {
				{
					type = "choice",
					values = AilFields.ail_type.avail_values,
					get = function()
						return AilFields.ail_type.value + 1
					end,
					set = function(val)
						AilFields.ail_type.value = val - 1
					end,
				},
			},
			visible = function()
				return (wizardType ~= "wing")
			end,
		}),

		wizard.settings({
			title = "A (right)",
			children = {
				{
					type = "choice",
					values = AilFields.ail_ch_a.avail_values,
					get = function()
						return AilFields.ail_ch_a.value + 1
					end,
					set = function(val)
						AilFields.ail_ch_a.value = val - 1
					end,
				},
			},
			visible = function()
				return AilFields.ail_type.value > 0
			end,
		}),

		wizard.settings({
			title = "B (left)",
			children = {
				{
					type = "choice",
					values = AilFields.ail_ch_b.avail_values,
					get = function()
						return AilFields.ail_ch_b.value + 1
					end,
					set = function(val)
						AilFields.ail_ch_b.value = val - 1
					end,
				},
			},
			visible = function()
				return AilFields.ail_type.value == 2
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("plane-2a.png"),
			visibleFunc = function()
				return AilFields.ail_type.value == 2
			end,
		}),

		wizard.image({
			file = getImagePath("plane-1a.png"),
			visibleFunc = function()
				return AilFields.ail_type.value == 1
			end,
		}),

		wizard.image({
			file = getImagePath("plane.png"),
			visibleFunc = function()
				return AilFields.ail_type.value == 0
			end,
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = RUDDER_NAME_AIL .. " Settings",
		hasPrevious = true,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		previousFunc = function()
			selectPage(-1)
		end,
		children1 = children1,
		children2 = children2,
	})

	lvgl.build(page)
end

-- todo, help text for flaps
local FlapsFields = {
	flap_type = { id = "flap_type", value = 0, avail_values = { "No", "Yes (one)", "Yes (two)" } },
	flap_ch_a = {
		id = "flap_ch_a",
		value = 8 - 1,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	},
	flap_ch_b = {
		id = "flap_ch_b",
		value = 9 - 1,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	},
}

local function runFlapsConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Do you have flaps",
			children = {
				{
					type = "choice",
					values = FlapsFields.flap_type.avail_values,
					get = function()
						return FlapsFields.flap_type.value + 1
					end,
					set = function(val)
						FlapsFields.flap_type.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "A (right)",
			children = {
				{
					type = "choice",
					values = FlapsFields.flap_ch_a.avail_values,
					get = function()
						return FlapsFields.flap_ch_a.value + 1
					end,
					set = function(val)
						FlapsFields.flap_ch_a.value = val - 1
					end,
				},
			},
			visible = function()
				return FlapsFields.flap_type.value > 0
			end,
		}),

		wizard.settings({
			title = "B (left)",
			children = {
				{
					type = "choice",
					values = FlapsFields.flap_ch_b.avail_values,
					get = function()
						return FlapsFields.flap_ch_b.value + 1
					end,
					set = function(val)
						FlapsFields.flap_ch_b.value = val - 1
					end,
				},
			},
			visible = function()
				return FlapsFields.flap_type.value == 2
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("plane-2f.png"),
			visibleFunc = function()
				return FlapsFields.flap_type.value == 2
			end,
		}),

		wizard.image({
			file = getImagePath("plane-1f.png"),
			visibleFunc = function()
				return FlapsFields.flap_type.value == 1
			end,
		}),

		wizard.image({
			file = getImagePath("plane.png"),
			visibleFunc = function()
				return FlapsFields.flap_type.value == 0
			end,
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Flaps Settings",
		hasPrevious = true,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		previousFunc = function()
			selectPage(-1)
		end,
		children1 = children1,
		children2 = children2,
	})

	lvgl.build(page)
end

local TailFields = {
	tail_type = {
		id = "tail_type",
		value = 1,
		avail_values = {
			"1 CH for Elevator, no Rudder",
			"1 CH for Elevator, 1 for Rudder",
			"2 CH for Elevator, 1 for Rudder",
			"V Tail",
		},
	},
	ch_a = {
		id = "ch_a",
		value = defaultChannel_0_ELE,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	}, --ele
	ch_b = {
		id = "ch_b",
		value = defaultChannel_0_RUD,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	}, --rud
	ch_c = {
		id = "ch_c",
		value = 6 - 1,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	}, --ele2
}

local function runTailConfig()
	lvgl.clear()

	local children1 = {

		wizard.settingsVertical({
			title = "Select your tail configuration",
			children = {
				{
					type = "choice",
					values = TailFields.tail_type.avail_values,
					get = function()
						return TailFields.tail_type.value + 1
					end,
					set = function(val)
						TailFields.tail_type.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Channel for A",
			children = {
				{
					type = "choice",
					values = TailFields.ch_a.avail_values,
					get = function()
						return TailFields.ch_a.value + 1
					end,
					set = function(val)
						TailFields.ch_a.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Channel for B",
			children = {
				{
					type = "choice",
					values = TailFields.ch_b.avail_values,
					get = function()
						return TailFields.ch_b.value + 1
					end,
					set = function(val)
						TailFields.ch_b.value = val - 1
					end,
				},
			},
			visible = function()
				return TailFields.tail_type.value > 0
			end,
		}),

		wizard.settings({
			title = "Channel for C",
			children = {
				{
					type = "choice",
					values = TailFields.ch_c.avail_values,
					get = function()
						return TailFields.ch_c.value + 1
					end,
					set = function(val)
						TailFields.ch_c.value = val - 1
					end,
				},
			},
			visible = function()
				return TailFields.tail_type.value == 2
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("tail-1.png"),
			visibleFunc = function()
				return TailFields.tail_type.value == 0
			end,
		}),

		wizard.image({
			file = getImagePath("tail-2.png"),
			visibleFunc = function()
				return TailFields.tail_type.value == 1
			end,
		}),

		wizard.image({
			file = getImagePath("tail-3.png"),
			visibleFunc = function()
				return TailFields.tail_type.value == 2
			end,
		}),

		wizard.image({
			file = getImagePath("tail-4.png"),
			visibleFunc = function()
				return TailFields.tail_type.value == 3
			end,
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Tail Settings",
		hasPrevious = true,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		previousFunc = function()
			selectPage(-1)
		end,
		children1 = children1,
		children2 = children2,
	})

	lvgl.build(page)
end

local GearFields = {
	is_gear = { id = "is_gear", value = 0, avail_values = { "No", "Yes" } },
	switch = { id = "switch", value = 3, avail_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
	channel = {
		id = "channel",
		value = 7 - 1,
		avail_values = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8", "CH9", "CH10" },
	}, --ele
}

local function runGearConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Does your model have retract landing gears?",
			children = {
				{
					type = "choice",
					values = GearFields.is_gear.avail_values,
					get = function()
						return GearFields.is_gear.value + 1
					end,
					set = function(val)
						GearFields.is_gear.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Retracts switch",
			children = {
				{
					type = "choice",
					values = GearFields.switch.avail_values,
					get = function()
						return GearFields.switch.value + 1
					end,
					set = function(val)
						GearFields.switch.value = val - 1
					end,
				},
			},
			visible = function()
				return GearFields.is_gear.value > 0
			end,
		}),

		wizard.settings({
			title = "Retracts channel",
			children = {
				{
					type = "choice",
					values = GearFields.channel.avail_values,
					get = function()
						return GearFields.channel.value + 1
					end,
					set = function(val)
						GearFields.channel.value = val - 1
					end,
				},
			},
			visible = function()
				return GearFields.is_gear.value > 0
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("plane.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Landing Gear",
		hasPrevious = true,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		previousFunc = function()
			selectPage(-1)
		end,
		children1 = children1,
		children2 = children2,
	})

	lvgl.build(page)
end

local AdditionalSettingsFields = {
	--{ 170, 52, VALUE, 1, 30, 0, 100 }, -- model name
	expo = { id = "expo", value = 30, min = 0, max = 100 }, -- expo
	is_dual_rate = { id = "is_dual_rate", value = 1, avail_values = { "No", "Yes" } },
	dr_switch = { id = "dr_switch", value = 2, avail_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
}
-- AdditionalSettingsFields.page = {
--     AdditionalSettingsFields.expo,
--     AdditionalSettingsFields.is_dual_rate,
--     AdditionalSettingsFields.dr_switch,
-- }

local function runAdditionalSettings()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Expo",
			children = {
				{
					type = "numberEdit",
					w = lvgl.PERCENT_SIZE + 100,
					min = AdditionalSettingsFields.expo.min,
					max = AdditionalSettingsFields.expo.max,
					get = function()
						return AdditionalSettingsFields.expo.value
					end,
					set = function(val)
						AdditionalSettingsFields.expo.value = val
					end,
				},
			},
		}),

		wizard.settings({
			title = "Dual Rate",
			children = {
				{
					type = "toggle",
					get = function()
						return AdditionalSettingsFields.is_dual_rate.value
					end,
					set = function(val)
						AdditionalSettingsFields.is_dual_rate.value = val
					end,
				},
				{
					type = "choice",
					values = AdditionalSettingsFields.dr_switch.avail_values,
					visible = function()
						return AdditionalSettingsFields.is_dual_rate.value == 1
					end,
					get = function()
						return AdditionalSettingsFields.dr_switch.value + 1
					end,
					set = function(val)
						AdditionalSettingsFields.dr_switch.value = val - 1
					end,
				},
			},
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Additional Settings",
		hasPrevious = true,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		previousFunc = function()
			selectPage(-1)
		end,
		children1 = children1,
		children2 = nil,
	})

	lvgl.build(page)
end

local function createModel()
	model.defaultInputs()

	if wizardType == "wing" then
		-- delete rudder
		model.deleteInput(defaultChannel(STICK_NUMBER_RUD), 0)
	end

	model.deleteMixes()

	-- input lines
	local expoVal = AdditionalSettingsFields.expo.value
	local is_dual_rate = (AdditionalSettingsFields.is_dual_rate.value == 1)
	local dr_switch = AdditionalSettingsFields.dr_switch.avail_values[1 + AdditionalSettingsFields.dr_switch.value]
	if is_dual_rate then
		modelConfig.updateInputLine(defaultChannel_0_AIL, 0, expoVal, 100, dr_switch .. CHAR_UP)
		modelConfig.updateInputLine(defaultChannel_0_AIL, 1, expoVal, 75, dr_switch .. "-")
		modelConfig.updateInputLine(defaultChannel_0_AIL, 2, expoVal, 50, dr_switch .. CHAR_DOWN)

		modelConfig.updateInputLine(defaultChannel_0_ELE, 0, expoVal, 100, dr_switch .. CHAR_UP)
		modelConfig.updateInputLine(defaultChannel_0_ELE, 1, expoVal, 75, dr_switch .. "-")
		modelConfig.updateInputLine(defaultChannel_0_ELE, 2, expoVal, 50, dr_switch .. CHAR_DOWN)
	else
		modelConfig.updateInputLine(defaultChannel_0_AIL, 0, expoVal, 100, nil)
		modelConfig.updateInputLine(defaultChannel_0_ELE, 0, expoVal, 100, nil)
	end

	if wizardType ~= "wing" then
		modelConfig.updateInputLine(defaultChannel_0_RUD, 0, expoVal, 100, nil)
	end

	-- motor
	if MotorFields.is_motor.value == 1 then
		modelConfig.addMix(MotorFields.motor_ch.value, MIXSRC_FIRST_INPUT + defaultChannel_0_THR, "Motor")
	end

	-- ailerons
	if wizardType ~= "wing" then
		if AilFields.ail_type.value == 1 then
			modelConfig.addMix(AilFields.ail_ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel_0_AIL, "Ail")
		elseif AilFields.ail_type.value == 2 then
			modelConfig.addMix(AilFields.ail_ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel_0_AIL, "Ail-R")
			modelConfig.addMix(AilFields.ail_ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel_0_AIL, "Ail-L", -100)
		end
	else
		-- wing delta mix
		modelConfig.addMix(AilFields.ail_ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "ele-R", 50)
		modelConfig.addMix(
			AilFields.ail_ch_a.value,
			MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL),
			"ail-R",
			-50
		)
		modelConfig.addMix(AilFields.ail_ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "ele-L", 50)
		modelConfig.addMix(AilFields.ail_ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL), "ail-L", 50)
	end

	-- flaps
	if wizardType ~= "wing" then
		if FlapsFields.flap_type.value == 1 then
			modelConfig.addMix(FlapsFields.flap_ch_a.value, MIXSRC_SA, "Flaps")
		elseif FlapsFields.flap_type.value == 2 then
			modelConfig.addMix(FlapsFields.flap_ch_a.value, MIXSRC_SA, "FlapsR")
			modelConfig.addMix(FlapsFields.flap_ch_b.value, MIXSRC_SA, "FlapsL")
		end
	end

	-- Tail
	if wizardType ~= "wing" then
		if TailFields.tail_type.value == 0 then
			modelConfig.addMix(TailFields.ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel(1), "Elev")
		elseif TailFields.tail_type.value == 1 then
			modelConfig.addMix(TailFields.ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel(1), "Elev")
			modelConfig.addMix(TailFields.ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel(0), "Rudder")
		elseif TailFields.tail_type.value == 2 then
			modelConfig.addMix(TailFields.ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel(1), "Elev-R")
			modelConfig.addMix(TailFields.ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel(0), "Rudder")
			modelConfig.addMix(TailFields.ch_c.value, MIXSRC_FIRST_INPUT + defaultChannel(1), "Elev-L")
		elseif TailFields.tail_type.value == 3 then
			modelConfig.addMix(TailFields.ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel(1), "V-EleR", 50)
			modelConfig.addMix(TailFields.ch_a.value, MIXSRC_FIRST_INPUT + defaultChannel(0), "V-RudR", 50, 1)
			modelConfig.addMix(TailFields.ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel(1), "V-EleL", 50)
			modelConfig.addMix(TailFields.ch_b.value, MIXSRC_FIRST_INPUT + defaultChannel(0), "V-RudL", -50, 1)
		end
	end

	-- retracts
	if wizardType ~= "wing" then
		if GearFields.is_gear.value == 1 then
			local switchIndex = MIXSRC_SA + GearFields.switch.value
			modelConfig.addMix(GearFields.channel.value, switchIndex, "Gear", 100, 0)
		end
	end

	-- SF arm switch
	if MotorFields.is_arm.value == 1 then
		local switchName = MotorFields.arm_switch.avail_values[1 + MotorFields.arm_switch.value]
		local switchIndex = getSwitchIndex(switchName .. CHAR_DOWN)
		local channelIndex = MotorFields.motor_ch.value

		model.setCustomFunction(FUNC_OVERRIDE_CHANNEL, {
			switch = switchIndex,
			func = 0,
			value = -100,
			mode = 0,
			param = channelIndex, --"CH3"
			active = 1,
		})
	end
end

local function runConfigSummary()
	local rows = {}

	local function addRows(...)
		for i, v in ipairs({ ... }) do
			rows[#rows + 1] = v
		end
	end

	-- motors
	if MotorFields.is_motor.value == 1 then
		addRows(wizard.summaryLine("Motor Channel", MotorFields.motor_ch.value))
	end

	-- ail
	if AilFields.ail_type.value == 1 then
		addRows(wizard.summaryLine(RUDDER_NAME_AIL .. " channel", AilFields.ail_ch_a.value))
	elseif AilFields.ail_type.value == 2 then
		addRows(
			wizard.summaryLine(RUDDER_NAME_AIL .. " Right channel", AilFields.ail_ch_a.value),
			wizard.summaryLine(RUDDER_NAME_AIL .. " Left channel", AilFields.ail_ch_b.value)
		)
	end

	-- flaps
	if FlapsFields.flap_type.value == 1 then
		addRows(wizard.summaryLine("Flaps channel", FlapsFields.flap_ch_a.value))
	elseif FlapsFields.flap_type.value == 2 then
		addRows(
			wizard.summaryLine("Flaps Right channel", FlapsFields.flap_ch_a.value),
			wizard.summaryLine("Flaps Left channel", FlapsFields.flap_ch_b.value)
		)
	end

	-- tail
	if wizardType ~= "wing" then
		if TailFields.tail_type.value == 0 then
			addRows(wizard.summaryLine("Elevator channel", TailFields.ch_a.value))
		elseif TailFields.tail_type.value == 1 then
			addRows(
				wizard.summaryLine("Elevator channel", TailFields.ch_a.value),
				wizard.summaryLine("Rudder channel", TailFields.ch_b.value)
			)
		elseif TailFields.tail_type.value == 2 then
			addRows(
				wizard.summaryLine("Elevator Right channel", TailFields.ch_a.value),
				wizard.summaryLine("Rudder channel", TailFields.ch_b.value),
				wizard.summaryLine("Elevator Left channel", TailFields.ch_c.value)
			)
		elseif TailFields.tail_type.value == 3 then
			addRows(
				wizard.summaryLine("V-Tail Right", TailFields.ch_a.value),
				wizard.summaryLine("V-Tail Left", TailFields.ch_b.value)
			)
		end
	end

	-- retracts gear
	if wizardType ~= "wing" then
		if GearFields.is_gear.value == 1 then
			local switchName = GearFields.switch.avail_values[1 + GearFields.switch.value]
			addRows(
				wizard.summaryLine("Gear Switch", nil, switchName),
				wizard.summaryLine("Gear Channel", GearFields.channel.value)
			)
		else
			addRows(wizard.summaryLine("Gear Switch", nil, "None"), wizard.summaryLine("Gear Channel", nil, "None"))
		end
	end

	-- expo
	addRows(wizard.summaryLine("Expo", nil, AdditionalSettingsFields.expo.value))

	-- dual rate
	addRows(
		wizard.summaryLine(
			"Dual Rate",
			nil,
			AdditionalSettingsFields.is_dual_rate.avail_values[1 + AdditionalSettingsFields.is_dual_rate.value]
				.. (
					AdditionalSettingsFields.is_dual_rate.value == 1
						and " (" .. AdditionalSettingsFields.dr_switch.avail_values[1 + AdditionalSettingsFields.dr_switch.value] .. ")"
					or ""
				)
		)
	)

	-- arm switch
	if MotorFields.is_arm.value == 1 then
		local switchName = MotorFields.arm_switch.avail_values[1 + MotorFields.arm_switch.value]
		addRows(wizard.summaryLine("Arm switch", nil, switchName))
	end

	lvgl.clear()

	local children2 = {
		{
			type = "label",
			w = lvgl.PERCENT_SIZE + 100,
			text = "Please review the configuration.",
		},
		{
			type = "label",
			w = lvgl.PERCENT_SIZE + 100,
			text = "After review press next to apply the configuration.",
		},
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Model Summary",
		hasPrevious = true,
		hasNext = true,
		nextFunc = function()
			selectPage(1)
		end,
		previousFunc = function()
			selectPage(-1)
		end,
		children1 = rows,
		children2 = children2,
	})

	lvgl.build(page)
end

local function runFinished()
	createModel()

	lvgl.clear()

	local endPage = wizard.finishedPage({ title = WIZARD_TITLE })

	lvgl.build(endPage)
end

-- Init
local function init()
	if wizardType ~= "wing" then
		pages = {
			runMotorConfig,
			runAilConfig,
			runFlapsConfig,
			runTailConfig,
			runGearConfig,
			runAdditionalSettings,
			runConfigSummary,
			runFinished,
		}
	else
		-- wing has less wizard pages
		pages = {
			runMotorConfig,
			runAilConfig,
			runAdditionalSettings,
			runConfigSummary,
			runFinished,
		}
	end

	-- go to the first page
	pages[page]()
end

local function run(event, touchState)
	if event == EVT_VIRTUAL_PREV_PAGE and page > 1 and page < #pages then
		killEvents(event)
		selectPage(-1)
	elseif event == EVT_VIRTUAL_NEXT_PAGE and page < #pages then
		killEvents(event)
		selectPage(1)
	end

	if wizard.exitWizard() == true then
		return 2
	end

	return 0
end

return {
	run = run,
	init = init,
}
