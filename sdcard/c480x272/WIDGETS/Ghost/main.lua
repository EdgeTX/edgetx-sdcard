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

local backgroundBitmap
local orangeLed
local greenLed
local offsetX
local offsetY
local sensors = {}

local id_RFMD
local id_FRat
local id_RQly
local id_TPWR

local id_VBan
local id_VFrq
local id_VChn
local id_VPwr

local updateIDs = true

local options = {
  { "VTX", BOOL, 0 },
}

local function getValues(wgt)
  if wgt.options.VTX == 0 then
    sensors[1] = string.format("%s", getValue(id_RFMD))
    sensors[2] = string.format("%d Hz", getValue(id_FRat))
    sensors[3] = string.format("%d %%", getValue(id_RQly))
    if (id_TPWR == nil) then
      sensors[4] = "Range"
    else
      sensors[4] = string.format("%d mW", getValue(id_TPWR))
    end
  else
    sensors[1] = string.format("%s", getValue(id_VBan))
    sensors[2] = string.format("%dMHz", getValue(id_VFrq))
    sensors[3] = string.format("CH: %d", getValue(id_VChn))
    sensors[4] = string.format("%d mW", getValue(id_VPwr))
  end
end

local function getIDs(wgt)
  id_RFMD = getFieldInfo("RFMD").id
  if wgt.options.VTX == 0 then
    id_FRat = getFieldInfo("FRat").id
    id_RQly = getFieldInfo("RQly").id
    id_TPWR = getFieldInfo("TPWR").id
  else
    id_VBan = getFieldInfo("VBan").id
    id_VFrq = getFieldInfo("VFrq").id
    id_VChn = getFieldInfo("VChn").id
    id_VPwr = getFieldInfo("VPwr").id
  end
end

local function create(zone, options)
  local wgt = { zone=zone, options=options}
  backgroundBitmap = Bitmap.open("/WIDGETS/Ghost/img/background.png")
  orangeLed = Bitmap.open("/WIDGETS/Ghost/img/orange.png")
  greenLed = Bitmap.open("/WIDGETS/Ghost/img/green.png")
  offsetX = (wgt.zone.w - 178) / 2
  offsetY = (wgt.zone.h - 148) / 2
  return wgt
end

local function update(wgt, options)
  wgt.options = options
  updateIDs = true
end

local function background(wgt)
end

function refresh(wgt)
  -- runs only on large enough zone
  if wgt.zone.w < 180 or wgt.zone.h < 145 then
    lcd.drawText(1, 1, "Widget space too small!", LEFT)
    return
  end

  if backgroundBitmap ~= nil then
    lcd.drawBitmap(backgroundBitmap, wgt.zone.x + offsetX, wgt.zone.y + offsetY)
  end

  if getRSSI() ~= 0 then
    if getValue("RFMD") == 0 then
      lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 35, "SCAN", CENTER + DBLSIZE)
      lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 70, "TELEM", CENTER + DBLSIZE)
      lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 105, "SENSORS", CENTER + DBLSIZE)
      updateIDs = true
      return
    end

    if updateIDs == true then
      getIDs(wgt)
      updateIDs = false
    end

    if getValue(id_RFMD) == "Pure" then
      if orangeLed ~= nil then
        lcd.drawBitmap(orangeLed, wgt.zone.x + offsetX + 143, wgt.zone.y + offsetY)
      end
    elseif greenLed ~= nil then
      lcd.drawBitmap(greenLed, wgt.zone.x + offsetX + 143, wgt.zone.y + offsetY)
    end

    getValues(wgt)

    -- RF Mode/Band
    lcd.drawText(wgt.zone.x + offsetX + 75, wgt.zone.y + offsetY + 2, sensors[1], CENTER + DBLSIZE)

    -- Frame rate / Frequency
    lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 35, sensors[2], CENTER + DBLSIZE)

    -- RSSI / Channel
    lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 70, sensors[3], CENTER + DBLSIZE)

    -- Transmit power
    lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 105, sensors[4], CENTER + DBLSIZE)
  else
    lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 35, "NO", CENTER + DBLSIZE)
    lcd.drawText(wgt.zone.x + offsetX + 85, wgt.zone.y + offsetY + 70, "TELEM", CENTER + DBLSIZE)
  end

end

return { name="Ghost", options=options, create=create, update=update, refresh=refresh, background=background }