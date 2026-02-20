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
local channels = { "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8" }

local RUN_DIR = "/TEMPLATES/1.Wizard/lib"
local IMG_DIR = "/TEMPLATES/1.Wizard/img"

local wizard = loadScript(RUN_DIR .. "/wizard-ui.lua")()

local WIZARD_TITLE = "Helicopter Wizard"

local function getImagePath(filename)
	return IMG_DIR .. "/helicopter/" .. filename
end

-- Select the next or previous page
local function selectPage(step)
	page = page + step
	pages[page]()
end

local TypeFields = {
	heli_type = { value = 0, available_values = { "FBL", "FB" } },
	swash_type = { value = 0, available_values = { "120", "120X", "140", "90" } },
}
local function runTypeConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "What type of helicopter?",
			children = {
				{
					type = "choice",
					values = TypeFields.heli_type.available_values,
					get = function()
						return TypeFields.heli_type.value + 1
					end,
					set = function(val)
						TypeFields.heli_type.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Specify your swash type",
			children = {
				{
					type = "choice",
					values = TypeFields.swash_type.available_values,
					get = function()
						return TypeFields.swash_type.value + 1
					end,
					set = function(val)
						TypeFields.swash_type.value = val - 1
					end,
				},
			},
			visible = function()
				return TypeFields.heli_type.value == 1
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("type.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Helicopter Type",
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

local StyleFields = { value = 0, available_values = { "Sport", "Light 3D", "Full 3D" } }
local function runStyleConfig()
	lvgl.clear()

	local children1 = {

		wizard.settings({
			title = "What is your flying style?",
			children = {
				{
					type = "choice",
					values = StyleFields.available_values,
					get = function()
						return StyleFields.value + 1
					end,
					set = function(val)
						StyleFields.value = val - 1
					end,
				},
			},
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("style.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Flying Style",
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

local SwitchFields = {
	FlightMode = { value = 1, available_values = { "SA", "SB", "SC", "SD", "SE", "SF" } },
	ThrottleHold = { value = 5, available_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG" } },
	-- Tail Gain only in non FBL mode
	TailGain = { value = 0, available_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG" } },
}
local function runSwitchConfig()
	lvgl.clear()

	local children1 = {

		wizard.settings({
			title = "FM (Idle Up)",
			children = {
				{
					type = "choice",
					values = SwitchFields.FlightMode.available_values,
					get = function()
						return SwitchFields.FlightMode.value + 1
					end,
					set = function(val)
						SwitchFields.FlightMode.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Throttle Hold",
			children = {
				{
					type = "choice",
					values = SwitchFields.ThrottleHold.available_values,
					get = function()
						return SwitchFields.ThrottleHold.value + 1
					end,
					set = function(val)
						SwitchFields.ThrottleHold.value = val - 1
					end,
				},
			},
		}),

		-- only visible for non FBL Helis
		wizard.settings({
			title = "Tail Gain",
			children = {
				{
					type = "choice",
					values = SwitchFields.TailGain.available_values,
					get = function()
						return SwitchFields.TailGain.value + 1
					end,
					set = function(val)
						SwitchFields.TailGain.value = val - 1
					end,
				},
			},
			visible = function()
				return TypeFields.heli_type.value == 1
			end,
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("switch.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Switch configuration",
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

local ThrFields = { value = 2, available_values = channels }
local function runThrConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Throttle Channel",
			children = {
				{
					type = "choice",
					values = ThrFields.available_values,
					get = function()
						return ThrFields.value + 1
					end,
					set = function(val)
						ThrFields.value = val - 1
					end,
				},
			},
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("throttle.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Throttle Config",
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

local CurveFields = {
	FlightMode0 = { value = 0, available_values = { "Thr Up", "V Curve", "Flat" } },
	FlightMode1 = { value = 0, available_values = { "V Curve", "Flat" } },
	FlightMode2 = { value = 1, available_values = { "V Curve", "Flat" } },
}
local function runCurveConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Throttle Curve FMO",
			children = {
				{
					type = "choice",
					values = CurveFields.FlightMode0.available_values,
					get = function()
						return CurveFields.FlightMode0.value + 1
					end,
					set = function(val)
						CurveFields.FlightMode0.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Throttle Curve FM1",
			children = {
				{
					type = "choice",
					values = CurveFields.FlightMode1.available_values,
					get = function()
						return CurveFields.FlightMode1.value + 1
					end,
					set = function(val)
						CurveFields.FlightMode1.value = val - 1
					end,
				},
			},
		}),

		wizard.settings({
			title = "Throttle Curve FM2",
			children = {
				{
					type = "choice",
					values = CurveFields.FlightMode2.available_values,
					get = function()
						return CurveFields.FlightMode2.value + 1
					end,
					set = function(val)
						CurveFields.FlightMode2.value = val - 1
					end,
				},
			},
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("curve.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Throttle Curves",
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

local AilerFields = { value = 0, available_values = channels }
local function runAilerConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Roll Channel",
			children = {
				{
					type = "choice",
					values = AilerFields.available_values,
					get = function()
						return AilerFields.value + 1
					end,
					set = function(val)
						AilerFields.value = val - 1
					end,
				},
			},
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("roll.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Roll Config",
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

local EleFields = { value = 1, available_values = channels }
local function runEleConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Nick Channel",
			children = {
				{
					type = "choice",
					values = EleFields.available_values,
					get = function()
						return EleFields.value + 1
					end,
					set = function(val)
						EleFields.value = val - 1
					end,
				},
			},
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("nick.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Elevator Config",
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

local RudFields = { value = 3, available_values = channels }
local function runRudConfig()
	lvgl.clear()

	local children1 = {
		wizard.settings({
			title = "Tail (Rudder) Channel",
			children = {
				{
					type = "choice",
					values = RudFields.available_values,
					get = function()
						return RudFields.value + 1
					end,
					set = function(val)
						RudFields.value = val - 1
					end,
				},
			},
		}),
	}

	local children2 = {
		wizard.image({
			file = getImagePath("tail.png"),
		}),
	}

	local page = wizard.page({
		title = WIZARD_TITLE,
		subtitle = "Tail Config",
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

local function createModel()
	local switchValues = { [0] = 2, 5, 8, 11, 14, 17, 19 }

	local tUp = switchValues[SwitchFields.FlightMode.value]
	local hold = switchValues[SwitchFields.ThrottleHold.value]
	local gyRate = switchValues[SwitchFields.TailGain.value]

	model.defaultInputs()
	model.deleteMixes()

	-- Curve Fm0
	if StyleFields.value == 0 and CurveFields.FlightMode0.value == 0 then
		model.setCurve(0, { name = "TC0", y = { -100, 0, 20, 40, 40 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode0.value == 0 then
		model.setCurve(0, { name = "TC0", y = { -100, 0, 35, 50, 50 } })
	elseif StyleFields.value == 2 and CurveFields.FlightMode0.value == 0 then
		model.setCurve(0, { name = "TC0", y = { -100, 0, 40, 80, 80 } })
	elseif StyleFields.value == 0 and CurveFields.FlightMode0.value == 1 then
		model.setCurve(0, { name = "TC0", y = { 50, 40, 50 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode0.value == 1 then
		model.setCurve(0, { name = "TC0", y = { 65, 55, 65 } })
	elseif StyleFields.value == 2 and CurveFields.FlightMode0.value == 1 then
		model.setCurve(0, { name = "TC0", y = { 70, 60, 70 } })
	elseif StyleFields.value == 0 and CurveFields.FlightMode0.value == 2 then
		model.setCurve(0, { name = "TC0", y = { 60, 60, 60 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode0.value == 2 then
		model.setCurve(0, { name = "TC0", y = { 65, 65, 65 } })
	else
		model.setCurve(0, { name = "TC0", y = { 70, 70, 70 } })
	end

	--Curve FM1
	if StyleFields.value == 0 and CurveFields.FlightMode1.value == 0 then
		model.setCurve(1, { name = "TC1", y = { 60, 50, 60 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode1.value == 0 then
		model.setCurve(1, { name = "TC1", y = { 70, 60, 70 } })
	elseif StyleFields.value == 2 and CurveFields.FlightMode1.value == 0 then
		model.setCurve(1, { name = "TC1", y = { 85, 75, 85 } })
	elseif StyleFields.value == 0 and CurveFields.FlightMode1.value == 1 then
		model.setCurve(1, { name = "TC1", y = { 65, 65, 65 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode1.value == 1 then
		model.setCurve(1, { name = "TC1", y = { 70, 70, 70 } })
	else
		model.setCurve(1, { name = "TC1", y = { 85, 85, 85 } })
	end

	--Curve FM2
	if StyleFields.value >= 0 and CurveFields.FlightMode2.value == 0 then
		model.setCurve(2, { name = "Tc2", y = { 70, 60, 70 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode2.value == 0 then
		model.setCurve(2, { name = "TC2", y = { 85, 70, 85 } })
	elseif StyleFields.value == 2 and CurveFields.FlightMode2.value == 0 then
		model.setCurve(2, { name = "TC2", y = { 100, 90, 100 } })
	elseif StyleFields.value == 0 and CurveFields.FlightMode2.value == 1 then
		model.setCurve(2, { name = "TC2", y = { 75, 75, 75 } })
	elseif StyleFields.value == 1 and CurveFields.FlightMode2.value == 1 then
		model.setCurve(2, { name = "TC2", y = { 85, 85, 85 } })
	else
		model.setCurve(2, { name = "TC2", y = { 95, 95, 95 } })
	end

	--Curve TH Hold
	model.setCurve(3, { name = "THD", y = { -100, -100, -100 } })

	-- Throttle
	model.insertMix(ThrFields.value, 0, { name = "Th0", weight = 100, curveType = 3, curveValue = 1 })
	model.insertMix(
		ThrFields.value,
		1,
		{ name = "Th1", weight = 100, switch = tUp, multiplex = 2, curveType = 3, curveValue = 2 }
	)
	model.insertMix(
		ThrFields.value,
		2,
		{ name = "Th2", weight = 100, switch = tUp - 1, multiplex = 2, curveType = 3, curveValue = 3 }
	)
	model.insertMix(
		ThrFields.value,
		3,
		{ name = "Hld", weight = 100, offset = -15, switch = hold + 1, multiplex = 2, curveType = 3, curveValue = 4 }
	)
	model.setOutput(ThrFields.value, { name = "Throt" })

	-- Ail
	if TypeFields.heli_type.value == 0 then
		model.insertMix(AilerFields.value, 0, { name = "Ail", weight = 100 })
		model.setOutput(AilerFields.value, { name = "Ailer" })
	else
		col2 = getFieldInfo("cyc2").id
		model.insertMix(AilerFields.value, 0, { source = col2, name = "Ail", weight = 100 })
		model.setOutput(AilerFields.value, { name = "Ailer" })
	end

	-- Elev
	if TypeFields.heli_type.value == 0 then
		model.insertMix(EleFields.value, 0, { name = "Ele", weight = 100 })
		model.setOutput(EleFields.value, { name = "Elev" })
	else
		col1 = getFieldInfo("cyc1").id
		model.insertMix(EleFields.value, 0, { source = col1, name = "Ele", weight = 100 })
		model.setOutput(EleFields.value, { name = "Elev" })
	end

	-- Rudder
	model.insertMix(RudFields.value, 0, { name = "Rud", weight = 100 })
	model.setOutput(RudFields.value, { name = "Rud" })

	-- Gyro
	if TypeFields.heli_type.value == 0 then
		model.insertMix(4, 0, { source = 110, name = "T.Gain", weight = 25 })
		model.setOutput(4, { name = "T.Gain" })
	else
		model.insertMix(4, 0, { source = 110, name = "HHold", weight = 25 })
		model.insertMix(4, 1, { source = 110, name = "Rate", weight = -25, switch = gyRate + 1, multiplex = 2 })
		model.setOutput(4, { name = "T.Gain" })
	end

	-- Pitch
	if TypeFields.heli_type.value == 0 then
		model.insertMix(5, 0, { source = 89, name = "Pch", weight = 100 })
		model.setOutput(5, { name = "Pitch" })
	else
		col3 = getFieldInfo("cyc3").id
		model.insertMix(5, 0, { source = col3, name = "Pch", weight = 100 })
		model.setOutput(5, { name = "Pitch" })
	end

	--Set Swash Parameters
	if TypeFields.heli_type.value == 1 and TypeFields.swash_type.value == 0 then
		model.setSwashRing({
			type = 1,
			collectiveSource = 89,
			aileronSource = 90,
			elevatorSource = 88,
			collectiveWeight = 60,
			aileronWeight = 60,
			elevatorWeight = 60,
		})
	elseif TypeFields.swash_type.value == 1 then
		model.setSwashRing({
			type = 2,
			collectiveSource = 89,
			aileronSource = 90,
			elevatorSource = 88,
			collectiveWeight = 60,
			aileronWeight = 60,
			elevatorWeight = 60,
		})
	elseif TypeFields.swash_type.value == 2 then
		model.setSwashRing({
			type = 3,
			collectiveSource = 89,
			aileronSource = 90,
			elevatorSource = 88,
			collectiveWeight = 40,
			aileronWeight = 40,
			elevatorWeight = 60,
		})
	elseif TypeFields.swash_type.value == 3 then
		model.setSwashRing({
			type = 4,
			collectiveSource = 89,
			aileronSource = 90,
			elevatorSource = 88,
			collectiveWeight = 35,
			aileronWeight = 35,
			elevatorWeight = 60,
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

	-- Type
	addRows(wizard.summaryLine("Type", nil, TypeFields.heli_type.available_values[TypeFields.heli_type.value + 1]))

	-- flybar heli
	if TypeFields.heli_type.value == 1 then
		addRows(
			wizard.summaryLine(
				"Swash Type",
				nil,
				TypeFields.swash_type.available_values[TypeFields.swash_type.value + 1]
			)
		)
	end

	-- Style
	addRows(wizard.summaryLine("Flying style", nil, StyleFields.available_values[StyleFields.value + 1]))

	-- Switches
	addRows(
		wizard.summaryLine(
			"FM Switch",
			nil,
			SwitchFields.FlightMode.available_values[SwitchFields.FlightMode.value + 1]
		)
	)
	addRows(
		wizard.summaryLine(
			"Throttle Hold Switch",
			nil,
			SwitchFields.ThrottleHold.available_values[SwitchFields.ThrottleHold.value + 1]
		)
	)
	if TypeFields.heli_type.value == 1 then
		addRows(
			wizard.summaryLine(
				"Tail Gain Switch",
				nil,
				SwitchFields.TailGain.available_values[SwitchFields.TailGain.value + 1]
			)
		)
	end

	-- thr
	addRows(wizard.summaryLine("Throttle Channel", ThrFields.value))

	-- FM0 Curve
	addRows(
		wizard.summaryLine(
			"FM0 Curve",
			nil,
			CurveFields.FlightMode0.available_values[CurveFields.FlightMode0.value + 1]
		)
	)

	-- FM1 Curve
	addRows(
		wizard.summaryLine(
			"FM1 Curve",
			nil,
			CurveFields.FlightMode1.available_values[CurveFields.FlightMode1.value + 1]
		)
	)

	-- FM2 Curve
	addRows(
		wizard.summaryLine(
			"FM2 Curve",
			nil,
			CurveFields.FlightMode2.available_values[CurveFields.FlightMode2.value + 1]
		)
	)

	-- Ail
	addRows(wizard.summaryLine("Aileron Channel", AilerFields.value))

	-- Elev
	addRows(wizard.summaryLine("Elevator Channel", EleFields.value))

	-- Rudder
	addRows(wizard.summaryLine("Rudder Channel", RudFields.value))

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

-- Init
local function init()
	pages = {
		runTypeConfig,
		runStyleConfig,
		runSwitchConfig,
		runThrConfig,
		runCurveConfig,
		runAilerConfig,
		runEleConfig,
		runRudConfig,
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
