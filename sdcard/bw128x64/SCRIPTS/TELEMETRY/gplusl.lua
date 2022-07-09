-- This code was originally written by Miami Mike to calculate the Open Location Code (Google+Code)
-- It was altered by ChrisOhara to permanently store the last received GPS coordinates by background function.
-- So that it can display the last position as Google+Code even after connection to receiver is lost.
-- Works on taranis

local mid = LCD_W / 2
local map = {[0] =
	"2", "3", "4", "5", "6", "7", "8", "9", "C", "F",
	"G", "H", "J", "M", "P", "Q", "R", "V", "W", "X"}

local my_gpsId
local latitude, longitude = 0.0, 0.0
local lat = 0
local lon = 0
local pluscode = ""


local function init_func()
    my_gpsId  = getFieldInfo("GPS") and getFieldInfo("GPS").id or nil;
end


local function getcode(lat, lon)
	local int = math.floor(lat)
	local codepair = map[int]
	lat = 20 * (lat - int)
	int = math.floor(lon)
	codepair = codepair .. map[int]
	lon = 20 * (lon - int)
	return lat, lon, codepair
end


local function bg_func()
	if getValue(my_gpsId) ~= 0 then
		local gps = getValue(my_gpsId)
		latitude, longitude = gps.lat, gps.lon
	end	
end


local function run_func()
	lat = (latitude + 90) / 20
	lon = (longitude + 180) / 20
	pluscode = ""
	for i = 1, 4 do
		lat, lon, codepair = getcode(lat, lon)
		pluscode = pluscode .. codepair
	end
	pluscode = pluscode .. "+"
	lat, lon, codepair = getcode(lat, lon)
	pluscode = pluscode .. codepair
	pluscode = pluscode .. map[4 * math.floor(lat / 5) + math.floor(lon / 4)]
	lcd.clear()
	lcd.drawText(mid - 53, 5, "GPS coordinates are")
	lcd.drawText(mid - 44, 15, latitude.. ", " .. longitude)
	lcd.drawText(mid- 49, 35, "Google Plus Code is")
	lcd.drawText(mid - 32, 45, pluscode) -- full 12 characters
	--- lcd.drawText(mid - 20, 45, string.sub(pluscode, 5, 12)) -- shortened version
	return 0
end

return {run=run_func, init=init_func, background=bg_func}