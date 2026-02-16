---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
-----#                                                                       #
-----# Credits: graphics by https://github.com/jrwieland                     #
-----#                                                                       #
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

-- Author: Alexander Gnauck

local IMG_DIR = "/TEMPLATES/1.Wizard/img"

local wizard = {}

-- useful to show lines for layout debugging
local THICKNESS = 0
local LANDSCAPE = 0
local PORTRAIT = 1

local ORIENTATION = (LCD_W > LCD_H) and LANDSCAPE or PORTRAIT

local exit = false

function wizard.exitWizard()
	return exit
end

local function closeDialog()
	lvgl.confirm({
		title = "Exit",
		message = "Do you really want to exit the model wizard?",
		confirm = function()
			exit = true
		end,
	})
end

--- return an LVGL page with a layout fir the wizard
---@param settings table
function wizard.page(settings)
	--[[
    This creates a page containing a layout for the wizard pages
    it accounts also for the display orientation of the radio

    Landscape:
    2 Columns, left 60% right 40%

    Portrait:
    2 Rows, top 60%, bottom 40%

    --]]

	if ORIENTATION == LANDSCAPE then
		-- landscape layout
		return {
			{
				type = "page",
				title = settings.title,
				subtitle = settings.subtitle,
				flexPad = 0,
				flexFlow = lvgl.FLOW_ROW,
				align = CENTER | VTOP,
				backButton = true,
				nextButton = {
					press = settings.nextFunc,
					active = function()
						return settings.hasNext
					end,
				},
				prevButton = {
					press = settings.previousFunc,
					active = function()
						return settings.hasPrevious
					end,
				},
				back = closeDialog,
				children = {
					-- main rect for settings
					{
						type = "rectangle",
						w = lvgl.PERCENT_SIZE + 60,
						h = lvgl.PERCENT_SIZE + 100,
						thickness = THICKNESS,
						flexFlow = lvgl.FLOW_COLUMN,
						align = LEFT | VTOP,
						children = settings.children1,
					},
					-- image rect
					{
						type = "rectangle",
						scrollBar = false,
						w = lvgl.PERCENT_SIZE + 40,
						h = lvgl.PERCENT_SIZE + 100,
						thickness = THICKNESS,
						flexFlow = lvgl.FLOW_COLUMN,
						children = settings.children2,
					},
				},
			},
		}
	else
		-- portrait layout
		return {
			{
				type = "page",
				title = settings.title,
				subtitle = settings.subtitle,
				flexPad = 0,
				flexFlow = lvgl.FLOW_COLUMN,
				align = CENTER | VTOP,
				backButton = true,
				nextButton = {
					press = settings.nextFunc,
					active = function()
						return settings.hasNext
					end,
				},
				prevButton = {
					press = settings.previousFunc,
					active = function()
						return settings.hasPrevious
					end,
				},
				back = closeDialog,
				children = {
					-- main rect for settings
					{
						type = "rectangle",
						w = lvgl.PERCENT_SIZE + 100,
						h = lvgl.PERCENT_SIZE + 60,
						thickness = THICKNESS,
						flexFlow = lvgl.FLOW_COLUMN,
						align = LEFT | VTOP,
						children = settings.children1,
					},
					-- image rect
					{
						type = "rectangle",
						scrollBar = false,
						w = lvgl.PERCENT_SIZE + 100,
						h = lvgl.PERCENT_SIZE + 40,
						thickness = THICKNESS,
						flexFlow = lvgl.FLOW_COLUMN,
						children = settings.children2,
					},
				},
			},
		}
	end
end

function wizard.settings(settings)
	return {
		type = "rectangle",
		flexPad = 0,
		flexFlow = lvgl.FLOW_ROW,
		thickness = THICKNESS,
		w = lvgl.PERCENT_SIZE + 100,
		visible = settings.visible,
		children = {
			{
				type = "rectangle",
				thickness = THICKNESS,
				w = lvgl.PERCENT_SIZE + 60,
				children = {
					{
						type = "label",
						w = lvgl.PERCENT_SIZE + 100,
						color = COLOR_THEME_PRIMARY1,
						text = settings.title,
					},
				},
			},
			{
				type = "rectangle",
				thickness = THICKNESS,
				w = lvgl.PERCENT_SIZE + 40,
				flexFlow = lvgl.FLOW_ROW,
				align = LEFT | VCENTER,
				children = settings.children,
			},
		},
	}
end

function wizard.settingsVertical(settings)
	return {
		type = "rectangle",
		flexPad = 0,
		thickness = THICKNESS,
		w = lvgl.PERCENT_SIZE + 100,
		flexFlow = lvgl.FLOW_COLUMN,
		align = LEFT | VTOP,
		visible = settings.visible,
		children = {
			{
				type = "rectangle",
				thickness = THICKNESS,
				w = lvgl.PERCENT_SIZE + 100,
				children = {
					{
						type = "label",
						w = lvgl.PERCENT_SIZE + 100,
						color = COLOR_THEME_PRIMARY1,
						text = settings.title,
					},
				},
			},
			{
				type = "rectangle",
				thickness = THICKNESS,
				flexFlow = lvgl.FLOW_ROW,
				align = LEFT | VCENTER,
				children = settings.children,
			},
		},
	}
end

function wizard.summaryLine(title, chNum, text2)
	local txt
	if chNum ~= nil then
		txt = "CH" .. chNum + 1
	else
		txt = text2
	end

	return wizard.settings({
		title = title,
		children = {
			{
				type = "label",
				w = lvgl.PERCENT_SIZE + 100,
				text = txt,
			},
		},
	})
end

function wizard.image(settings)
	-- some border around the images
	local BORDER_PADDING = lvgl.PAD_LARGE * 4

	if ORIENTATION == LANDSCAPE then
		return {
			type = "image",
			x = 0,
			y = 0,
			w = LCD_W * 40 / 100 - BORDER_PADDING,
			h = lvgl.PAGE_BODY_HEIGHT - BORDER_PADDING,
			file = settings.file,
			visible = settings.visibleFunc,
		}
	else
		return {
			type = "image",
			x = 0,
			y = 0,
			w = LCD_W - BORDER_PADDING,
			h = lvgl.PAGE_BODY_HEIGHT * 40 / 100 - BORDER_PADDING,
			file = settings.file,
			visible = settings.visibleFunc,
		}
	end
end

function wizard.finishedPage(settings)
	return wizard.page({
		title = settings.title,
		subtitle = "Finished",
		hasPrevious = false,
		hasNext = false,
		children1 = {
			{
				type = "label",
				text = "Model successfully created !",
			},
			{
				type = "label",
				text = "Hold [RTN] to exit.",
			},
		},
		children2 = {
			wizard.image({
				file = IMG_DIR .. "/summary.png",
				visible = function()
					return true
				end,
			}),
		},
	})
end

return wizard
