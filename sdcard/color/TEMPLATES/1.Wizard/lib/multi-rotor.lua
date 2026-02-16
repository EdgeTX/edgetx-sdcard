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

local page = 1
local pages = {}

local STICK_NUMBER_AIL = 3
local STICK_NUMBER_ELE = 1
local STICK_NUMBER_THR = 2
local STICK_NUMBER_RUD = 0

local channels = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" }
local switches = { "SA", "SB", "SC", "SD", "SE", "SF" }

local RUN_DIR = "/TEMPLATES/1.Wizard/lib"
local IMG_DIR = "/TEMPLATES/1.Wizard/img"

local WIZARD_TITLE = "Multirotor Wizard"

local modelConfig = loadScript(RUN_DIR .. "/model-config.lua")()
local wizard = loadScript(RUN_DIR .. "/wizard-ui.lua")()

local function getImagePath(filename)
	return IMG_DIR .. "/multirotor/" .. filename
end

-- Select the next or previous page
local function selectPage(step)
	page = page + step
	pages[page]()
end

local ThrottleFields = {
	value = defaultChannel(STICK_NUMBER_THR),
	avail_values = channels,
}
local function runThrottleConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Throttle Settings",
		hasPrevious = false,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Throttle channel",
				children = {
					{
						type = "choice",
						values = ThrottleFields.avail_values,
						get = function()
							return ThrottleFields.value + 1
						end,
						set = function(val)
							ThrottleFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("throttle.png"),
			}),
		},
	})

	lvgl.build(page)
end

local RollFields = {
	value = defaultChannel(STICK_NUMBER_AIL),
	avail_values = channels,
}
local function runRollConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Roll Settings",
		hasPrevious = true,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Roll channel",
				children = {
					{
						type = "choice",
						values = RollFields.avail_values,
						get = function()
							return RollFields.value + 1
						end,
						set = function(val)
							RollFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("roll.png"),
			}),
		},
	})

	lvgl.build(page)
end

local PitchFields = {
	value = defaultChannel(STICK_NUMBER_ELE),
	avail_values = channels,
}
local function runPitchConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Pitch Settings",
		hasPrevious = true,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Pitch channel",
				children = {
					{
						type = "choice",
						values = PitchFields.avail_values,
						get = function()
							return PitchFields.value + 1
						end,
						set = function(val)
							PitchFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("pitch.png"),
			}),
		},
	})

	lvgl.build(page)
end

local YawFields = {
	value = defaultChannel(STICK_NUMBER_RUD),
	avail_values = channels,
}
local function runYawConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Yaw Settings",
		hasPrevious = true,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Yaw channel",
				children = {
					{
						type = "choice",
						values = YawFields.avail_values,
						get = function()
							return YawFields.value + 1
						end,
						set = function(val)
							YawFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("yaw.png"),
			}),
		},
	})

	lvgl.build(page)
end

local ArmFields = {
	value = 5,
	avail_values = switches,
}
local function runArmConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Arm switch",
		hasPrevious = true,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Arm switch",
				children = {
					{
						type = "choice",
						values = ArmFields.avail_values,
						get = function()
							return ArmFields.value + 1
						end,
						set = function(val)
							ArmFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("arm.png"),
			}),
		},
	})

	lvgl.build(page)
end

local BeeperFields = {
	value = 3,
	avail_values = switches,
}
local function runBeeperConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Beeper switch",
		hasPrevious = true,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Beeper switch",
				children = {
					{
						type = "choice",
						values = BeeperFields.avail_values,
						get = function()
							return BeeperFields.value + 1
						end,
						set = function(val)
							BeeperFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("beeper.png"),
			}),
		},
	})

	lvgl.build(page)
end

local ModeFields = {
	value = 0,
	avail_values = switches,
}
local function runModeConfig()
	lvgl.clear()

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Mode switch",
		hasPrevious = true,
		hasNext = true,
		previousFunc = function()
			selectPage(-1)
		end,
		nextFunc = function()
			selectPage(1)
		end,
		children1 = {
			wizard.settings({
				title = "Assign Mode switch",
				children = {
					{
						type = "choice",
						values = ModeFields.avail_values,
						get = function()
							return ModeFields.value + 1
						end,
						set = function(val)
							ModeFields.value = val - 1
						end,
					},
				},
			}),
		},
		children2 = {
			wizard.image({
				file = getImagePath("mode.png"),
			}),
		},
	})

	lvgl.build(page)
end

local function createModel()
	model.defaultInputs()
	model.deleteMixes()

	-- throttle
	modelConfig.addMix(ThrottleFields.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_THR), "Thr")
	-- roll
	modelConfig.addMix(RollFields.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_AIL), "Roll")
	-- pitch
	modelConfig.addMix(PitchFields.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_ELE), "Pitch")
	-- yaw
	modelConfig.addMix(YawFields.value, MIXSRC_FIRST_INPUT + defaultChannel(STICK_NUMBER_RUD), "Yaw")
	modelConfig.addMix(4, MIXSRC_SA + ArmFields.value, "Arm")
	modelConfig.addMix(5, MIXSRC_SA + BeeperFields.value, "Beeper")
	modelConfig.addMix(6, MIXSRC_SA + ModeFields.value, "Mode")
end

local function runConfigSummary()
	local rows = {}

	function addRows(...)
		for i, v in ipairs({ ... }) do
			rows[#rows + 1] = v
		end
	end

	-- throttle
	addRows(wizard.summaryLine("Throttle channel", ThrottleFields.value))
	-- roll
	addRows(wizard.summaryLine("Roll channel", RollFields.value))
	-- pitch
	addRows(wizard.summaryLine("Pitch channel", PitchFields.value))
	-- yaw
	addRows(wizard.summaryLine("Yaw channel", YawFields.value))
	-- arm
	addRows(wizard.summaryLine("Arm switch", nil, ArmFields.avail_values[ArmFields.value + 1]))
	-- beeper
	addRows(wizard.summaryLine("Beeper switch", nil, BeeperFields.avail_values[1 + BeeperFields.value]))
	-- mode
	addRows(wizard.summaryLine("Mode switch", nil, ModeFields.avail_values[ModeFields.value + 1]))

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

	endPage = wizard.finishedPage({ title = WIZARD_TITLE })

	lvgl.build(endPage)
end

local function init()
	pages = {
		runThrottleConfig,
		runRollConfig,
		runPitchConfig,
		runYawConfig,
		runArmConfig,
		runBeeperConfig,
		runModeConfig,
		runConfigSummary,
		runFinished,
	}

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
