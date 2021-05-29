---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
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
}

local function create(zone, options)
  local pie = { zone=zone, options=options, counter=0 }
  print(options.Option2)
  return pie
end

local function update(pie, options)
  pie.options = options
end

local function background(pie)

end

function refresh(pie)
  local GPSTable = getTxGPS()
  if GPSTable ~= nil then
    local numsat = GPSTable.numsat
	if numsat ~= nil then
      lcd.drawText(pie.zone.x, pie.zone.y, "NumSat: " .. string.format("%d", numsat), LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.numSat
	else
      lcd.drawText(pie.zone.x, pie.zone.y, "NumSat: no data yet", LEFT + TEXT_COLOR + SHADOWED)
	end
    if GPSTable.fix then
      lcd.drawText(pie.zone.x, pie.zone.y+20, "GPS Lock", LEFT + TEXT_COLOR + SHADOWED)
    else
      lcd.drawText(pie.zone.x, pie.zone.y+20, "No GPS lock yet", LEFT + TEXT_COLOR + SHADOWED)
    end
    lcd.drawText(pie.zone.x, pie.zone.y+40, "HDOP: " .. string.format("%.1f",GPSTable.hdop * 0.01), LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.hdop
--    if (GPSTable.fix==true) then
	  lcd.drawText(pie.zone.x, pie.zone.y+60, "Lat: " .. string.format("%f",GPSTable.lat), LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.latitude * 0.000001, positive is North
      lcd.drawText(pie.zone.x, pie.zone.y+80, "Lon: " .. string.format("%f",GPSTable.lon), LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.longitude * 0.000001, positive is East
	  lcd.drawText(pie.zone.x, pie.zone.y+100, "Alt: " .. string.format("%d",GPSTable.alt) .. " m", LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.altitude (precision 1m)
	  lcd.drawText(pie.zone.x, pie.zone.y+120, "Spd: " .. string.format("%.2f",GPSTable.speed * 0.01) .. " m/s", LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.speed in [cm/s]
	  lcd.drawText(pie.zone.x, pie.zone.y+140, "Head: " .. string.format("%d",GPSTable.heading * 0.1) .. " deg", LEFT + TEXT_COLOR + SHADOWED) -- internal gpsData.groundCourse in 10 deg units
--    end
  end
end

return { name="TxGPStest", options=options, create=create, update=update, refresh=refresh, background=background }
