---- #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
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
local options = {
  { "Color", COLOR, COLOR_THEME_SECONDARY1 },
  { "Shadow", BOOL, 0 }
}

local function create(zone, options)
  local pie = { zone=zone, options=options, counter=0 }
  return pie
end

local function update(pie, options)
  pie.options = options
end

local function background(pie)
  pie.counter = pie.counter + 1
end

function refresh(pie)
  pie.counter = pie.counter + 1

  lcd.setColor(CUSTOM_COLOR, pie.options.Color)

  if pie.options.Shadow == 0 then
    lcd.drawNumber(pie.zone.x, pie.zone.y, pie.counter, LEFT + DBLSIZE + CUSTOM_COLOR);
  else
    lcd.drawNumber(pie.zone.x, pie.zone.y, pie.counter, LEFT + DBLSIZE + CUSTOM_COLOR + SHADOWED);
  end
end

return { name="Counter", options=options, create=create, update=update, refresh=refresh, background=background }
