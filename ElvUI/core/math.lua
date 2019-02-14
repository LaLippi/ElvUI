local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Cache global variables
local tinsert, tremove, next = tinsert, tremove, next
local select, tonumber, assert, type, unpack = select, tonumber, assert, type, unpack
local atan2, modf, ceil, floor, abs, sqrt, mod = math.atan2, math.modf, math.ceil, math.floor, math.abs, math.sqrt, mod
local format, strfind, strsub, strupper, gsub, gmatch, utf8sub = format, strfind, strsub, strupper, gsub, gmatch, string.utf8sub
local MATCH_ITEM_LEVEL = ITEM_LEVEL:gsub('%%d', '(%%d+)')
local MATCH_ENCHANT = ENCHANTED_TOOLTIP_LINE:gsub('%%s', '(.+)')

--WoW API / Variables
local CreateFrame = CreateFrame
local UnitPosition = UnitPosition
local GetPlayerFacing = GetPlayerFacing
local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight
local C_Timer_After = C_Timer.After
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo
local GetInspectSpecialization = GetInspectSpecialization

local ScanTooltip = CreateFrame("GameTooltip", "ElvUI_GearSlotTooltip", UIParent, "GameTooltipTemplate") -- pull this out once main scantooltip is committed
local ARMOR_SLOTS = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
local X2_INVTYPES = {
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_RANGED = true,
}
local X2_EXCEPTIONS = {
    [2] = 19, -- wands, use INVTYPE_RANGEDRIGHT, but are 1H
}


--Return short value of a number
function E:ShortValue(v)
	local shortValueDec = format("%%.%df", E.db.general.decimalLength or 1)
	local shortValue = abs(v)
	if E.db.general.numberPrefixStyle == "METRIC" then
		if shortValue >= 1e12 then
			return format(shortValueDec.."T", v / 1e12)
		elseif shortValue >= 1e9 then
			return format(shortValueDec.."G", v / 1e9)
		elseif shortValue >= 1e6 then
			return format(shortValueDec.."M", v / 1e6)
		elseif shortValue >= 1e3 then
			return format(shortValueDec.."k", v / 1e3)
		else
			return format("%.0f", v)
		end
	elseif E.db.general.numberPrefixStyle == "CHINESE" then
		if shortValue >= 1e8 then
			return format(shortValueDec.."Y", v / 1e8)
		elseif shortValue >= 1e4 then
			return format(shortValueDec.."W", v / 1e4)
		else
			return format("%.0f", v)
		end
	elseif E.db.general.numberPrefixStyle == "KOREAN" then
		if shortValue >= 1e8 then
			return format(shortValueDec.."억", v / 1e8)
		elseif shortValue >= 1e4 then
			return format(shortValueDec.."만", v / 1e4)
		elseif shortValue >= 1e3 then
			return format(shortValueDec.."천", v / 1e3)
		else
			return format("%.0f", v)
		end
	elseif E.db.general.numberPrefixStyle == "GERMAN" then
		if shortValue >= 1e12 then
			return format(shortValueDec.."Bio", v / 1e12)
		elseif shortValue >= 1e9 then
			return format(shortValueDec.."Mrd", v / 1e9)
		elseif shortValue >= 1e6 then
			return format(shortValueDec.."Mio", v / 1e6)
		elseif shortValue >= 1e3 then
			return format(shortValueDec.."Tsd", v / 1e3)
		else
			return format("%.0f", v)
		end
	else
		if shortValue >= 1e12 then
			return format(shortValueDec.."T", v / 1e12)
		elseif shortValue >= 1e9 then
			return format(shortValueDec.."B", v / 1e9)
		elseif shortValue >= 1e6 then
			return format(shortValueDec.."M", v / 1e6)
		elseif shortValue >= 1e3 then
			return format(shortValueDec.."K", v / 1e3)
		else
			return format("%.0f", v)
		end
	end
end

function E:IsEvenNumber(num)
	return num % 2 == 0
end

-- http://www.wowwiki.com/ColorGradient
function E:ColorGradient(perc, ...)
	if perc >= 1 then
		return select(select('#', ...) - 2, ...)
	elseif perc <= 0 then
		return ...
	end

	local num = select('#', ...) / 3
	local segment, relperc = modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

	return r1+(r2-r1)*relperc, g1+(g2-g1)*relperc, b1+(b2-b1)*relperc
end

--Return rounded number
function E:Round(num, idp)
	if(idp and idp > 0) then
		local mult = 10 ^ idp
		return floor(num * mult + 0.5) / mult
	end
	return floor(num + 0.5)
end

--Truncate a number off to n places
function E:Truncate(v, decimals)
	return v - (v % (0.1 ^ (decimals or 0)))
end

--RGB to Hex
function E:RGBToHex(r, g, b)
	r = r <= 1 and r >= 0 and r or 1
	g = g <= 1 and g >= 0 and g or 1
	b = b <= 1 and b >= 0 and b or 1
	return format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

--Hex to RGB
function E:HexToRGB(hex)
	local rhex, ghex, bhex = strsub(hex, 1, 2), strsub(hex, 3, 4), strsub(hex, 5, 6)
	return tonumber(rhex, 16), tonumber(ghex, 16), tonumber(bhex, 16)
end

--From http://wow.gamepedia.com/UI_coordinates
function E:FramesOverlap(frameA, frameB)
	if not frameA or not frameB then return	end

	local sA, sB = frameA:GetEffectiveScale(), frameB:GetEffectiveScale()
	if not sA or not sB then return	end

	local frameALeft, frameARight, frameABottom, frameATop = frameA:GetLeft(), frameA:GetRight(), frameA:GetBottom(), frameA:GetTop()
	local frameBLeft, frameBRight, frameBBottom, frameBTop = frameB:GetLeft(), frameB:GetRight(), frameB:GetBottom(), frameB:GetTop()
	if not (frameALeft and frameARight and frameABottom and frameATop) then return end
	if not (frameBLeft and frameBRight and frameBBottom and frameBTop) then return end

	return ((frameALeft*sA) < (frameBRight*sB)) and ((frameBLeft*sB) < (frameARight*sA)) and ((frameABottom*sA) < (frameBTop*sB)) and ((frameBBottom*sB) < (frameATop*sA))
end

function E:GetScreenQuadrant(frame)
	local x, y = frame:GetCenter()
	local screenWidth = GetScreenWidth()
	local screenHeight = GetScreenHeight()

	if not (x and y) then
		return "UNKNOWN", frame:GetName()
	end

	local point
	if (x > (screenWidth / 3) and x < (screenWidth / 3)*2) and y > (screenHeight / 3)*2 then
		point = "TOP"
	elseif x < (screenWidth / 3) and y > (screenHeight / 3)*2 then
		point = "TOPLEFT"
	elseif x > (screenWidth / 3)*2 and y > (screenHeight / 3)*2 then
		point = "TOPRIGHT"
	elseif (x > (screenWidth / 3) and x < (screenWidth / 3)*2) and y < (screenHeight / 3) then
		point = "BOTTOM"
	elseif x < (screenWidth / 3) and y < (screenHeight / 3) then
		point = "BOTTOMLEFT"
	elseif x > (screenWidth / 3)*2 and y < (screenHeight / 3) then
		point = "BOTTOMRIGHT"
	elseif x < (screenWidth / 3) and (y > (screenHeight / 3) and y < (screenHeight / 3)*2) then
		point = "LEFT"
	elseif x > (screenWidth / 3)*2 and y < (screenHeight / 3)*2 and y > (screenHeight / 3) then
		point = "RIGHT"
	else
		point = "CENTER"
	end

	return point
end

function E:GetXYOffset(position, override)
	local default = E.Spacing
	local x, y = override or default, override or default

	if position == 'TOP' then
		return 0, y
	elseif position == 'TOPLEFT' then
		return x, y
	elseif position == 'TOPRIGHT' then
		return -x, y
	elseif position == 'BOTTOM' then --or or then
		return 0, -y
	elseif position == 'BOTTOMLEFT' then
		return x, -y
	elseif position == 'BOTTOMRIGHT' then
		return -x, -y
	elseif position == 'LEFT' then
		return -x, 0
	elseif position == 'RIGHT' then
		return x, 0
	elseif position == "CENTER" then
		return 0, 0
	end
end

local gftStyles = {
	-- keep percents in this table with `PERCENT` in the key, and `%.1f%%` in the value somewhere.
	-- we use these two things to follow our setting for decimal length. they need to be EXACT.
	['CURRENT'] = '%s',
	['CURRENT_MAX'] = '%s - %s',
	['CURRENT_PERCENT'] = '%s - %.1f%%',
	['CURRENT_MAX_PERCENT'] = '%s - %s | %.1f%%',
	['PERCENT'] = '%.1f%%',
	['DEFICIT'] = '-%s'
}

function E:GetFormattedText(style, min, max)
	assert(gftStyles[style], 'Invalid format style: '..style)
	assert(min, 'You need to provide a current value. Usage: E:GetFormattedText(style, min, max)')
	assert(max, 'You need to provide a maximum value. Usage: E:GetFormattedText(style, min, max)')

	if max == 0 then max = 1 end

	local gftUseStyle
	local gftDec = E.db.general.decimalLength or 1
	if (gftDec ~= 1) and strfind(style, 'PERCENT') then
		gftUseStyle = gsub(gftStyles[style], '%%%.1f%%%%', '%%.'..gftDec..'f%%%%')
	else
		gftUseStyle = gftStyles[style]
	end

	if style == 'DEFICIT' then
		local gftDeficit = max - min
		return ((gftDeficit > 0) and format(gftUseStyle, E:ShortValue(gftDeficit))) or ''
	elseif style == 'PERCENT' then
		return format(gftUseStyle, min / max * 100)
	elseif style == 'CURRENT' or ((style == 'CURRENT_MAX' or style == 'CURRENT_MAX_PERCENT' or style == 'CURRENT_PERCENT') and min == max) then
		return format(gftStyles.CURRENT, E:ShortValue(min))
	elseif style == 'CURRENT_MAX' then
		return format(gftUseStyle, E:ShortValue(min), E:ShortValue(max))
	elseif style == 'CURRENT_PERCENT' then
		return format(gftUseStyle, E:ShortValue(min), min / max * 100)
	elseif style == 'CURRENT_MAX_PERCENT' then
		return format(gftUseStyle, E:ShortValue(min), E:ShortValue(max), min / max * 100)
	end
end

function E:ShortenString(str, numChars, dots)
	local bytes = #str
	if bytes <= numChars then
		return str
	else
		local len, pos = 0, 1
		while pos <= bytes do
			len = len + 1
			local c = str:byte(pos)
			if c > 0 and c <= 127 then
				pos = pos + 1
			elseif c >= 192 and c <= 223 then
				pos = pos + 2
			elseif c >= 224 and c <= 239 then
				pos = pos + 3
			elseif c >= 240 and c <= 247 then
				pos = pos + 4
			end
			if len == numChars then
				break
			end
		end

		if len == numChars and pos <= bytes then
			return strsub(str, 1, pos - 1)..(dots and '...' or '')
		else
			return str
		end
	end
end

function E:AbbreviateString(str, allUpper)
	local newString = ""
	for word in gmatch(str, "[^%s]+") do
		word = utf8sub(word, 1, 1) --get only first letter of each word
		if allUpper then word = strupper(word) end
		newString = newString..word
	end

	return newString
end

--Add time before calling a function
local waitTable = {}
local waitFrame
function E:Delay(delay, func, ...)
	if (type(delay) ~= "number") or (type(func) ~= "function") then
		return false
	end

	if delay < 0.01 then
		delay = 0.01 -- Restrict to the lowest time that the C_Timer API allows us
	end

	local extend = {...}
	if not next(extend) then
		C_Timer_After(delay, func)
		return true
	else
		if waitFrame == nil then
			waitFrame = CreateFrame("Frame","WaitFrame", E.UIParent)
			waitFrame:SetScript("onUpdate",function (_,elapse)
				local i, count = 1, #waitTable
				while i <= count do
					local waitRecord = tremove(waitTable,i)
					local waitDelay = tremove(waitRecord,1)
					local waitFunc = tremove(waitRecord,1)
					local waitParams = tremove(waitRecord,1)
					if waitDelay > elapse then
						tinsert(waitTable,i,{waitDelay-elapse,waitFunc,waitParams})
						i = i + 1
					else
						count = count - 1
						waitFunc(unpack(waitParams))
					end
				end
			end)
		end
		tinsert(waitTable,{delay,func,extend})
		return true
	end
end

function E:StringTitle(str)
	return gsub(str, "(.)", strupper, 1)
end

E.TimeThreshold = 3
E.TimeColors = { -- aura time colors for days, hours, minutes, seconds, fadetimer
	[0] = '|cffeeeeee',
	[1] = '|cffeeeeee',
	[2] = '|cffeeeeee',
	[3] = '|cffeeeeee',
	[4] = '|cfffe0000',
	[5] = '|cff909090', --mmss
	[6] = '|cff707070', --hhmm
}
E.TimeFormats = { -- short and long aura time formats
	[0] = {'%dd', '%dd'},
	[1] = {'%dh', '%dh'},
	[2] = {'%dm', '%dm'},
	[3] = {'%ds', '%d'},
	[4] = {'%.1fs', '%.1f'},
	[5] = {'%d:%02d', '%d:%02d'}, --mmss
	[6] = {'%d:%02d', '%d:%02d'}, --hhmm
}

local DAY, HOUR, MINUTE = 86400, 3600, 60 --used for calculating aura time text
local DAYISH, HOURISH, MINUTEISH = HOUR * 23.5, MINUTE * 59.5, 59.5 --used for caclculating aura time at transition points
local HALFDAYISH, HALFHOURISH, HALFMINUTEISH = DAY/2 + 0.5, HOUR/2 + 0.5, MINUTE/2 + 0.5 --used for calculating next update times

-- will return the the value to display, the formatter id to use and calculates the next update for the Aura
function E:GetTimeInfo(s, threshhold, hhmm, mmss)
	if s < MINUTE then
		if s >= threshhold then
			return floor(s), 3, 0.51
		else
			return s, 4, 0.051
		end
	elseif s < HOUR then
		if mmss and s < mmss then
			return s/MINUTE, 5, 0.51, s%MINUTE
		else
			local minutes = floor((s/MINUTE)+.5)
			if hhmm and s < (hhmm * MINUTE) then
				return s/HOUR, 6, minutes > 1 and (s - (minutes*MINUTE - HALFMINUTEISH)) or (s - MINUTEISH), minutes%MINUTE
			else
				return ceil(s / MINUTE), 2, minutes > 1 and (s - (minutes*MINUTE - HALFMINUTEISH)) or (s - MINUTEISH)
			end
		end
	elseif s < DAY then
		if mmss and s < mmss then
			return s/MINUTE, 5, 0.51, s%MINUTE
		elseif hhmm and s < (hhmm * MINUTE) then
			local minutes = floor((s/MINUTE)+.5)
			return s/HOUR, 6, minutes > 1 and (s - (minutes*MINUTE - HALFMINUTEISH)) or (s - MINUTEISH), minutes%MINUTE
		else
			local hours = floor((s/HOUR)+.5)
			return ceil(s / HOUR), 1, hours > 1 and (s - (hours*HOUR - HALFHOURISH)) or (s - HOURISH)
		end
	else
		local days = floor((s/DAY)+.5)
		return ceil(s / DAY), 0, days > 1 and (s - (days*DAY - HALFDAYISH)) or (s - DAYISH)
	end
end

function E:GetDistance(unit1, unit2)
	local x1, y1, _, map1 = UnitPosition(unit1)
	if not x1 then return end

	local x2, y2, _, map2 = UnitPosition(unit2)
	if not x2 then return end

	if map1 ~= map2 then return end

	local dX = x2 - x1
	local dY = y2 - y1
	local distance = sqrt(dX * dX + dY * dY)
	return distance, atan2(dY, dX) - GetPlayerFacing()
end

--Money text formatting, code taken from Scrooge by thelibrarian ( http://www.wowace.com/addons/scrooge/ )
local COLOR_COPPER, COLOR_SILVER, COLOR_GOLD = "|cffeda55f", "|cffc7c7cf", "|cffffd700"
local ICON_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12|t"
local ICON_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12|t"
local ICON_GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12|t"
function E:FormatMoney(amount, style, textonly)
	local coppername = textonly and L["copperabbrev"] or ICON_COPPER
	local silvername = textonly and L["silverabbrev"] or ICON_SILVER
	local goldname = textonly and L["goldabbrev"] or ICON_GOLD

	local value = abs(amount)
	local gold = floor(value / 10000)
	local silver = floor(mod(value / 100, 100))
	local copper = floor(mod(value, 100))

	if not style or style == "SMART" then
		local str = ""
		if gold > 0 then str = format("%d%s%s", gold, goldname, (silver > 0 or copper > 0) and " " or "") end
		if silver > 0 then str = format("%s%d%s%s", str, silver, silvername, copper > 0 and " " or "") end
		if copper > 0 or value == 0 then str = format("%s%d%s", str, copper, coppername) end
		return str
	end

	if style == "FULL" then
		if gold > 0 then
			return format("%d%s %d%s %d%s", gold, goldname, silver, silvername, copper, coppername)
		elseif silver > 0 then
			return format("%d%s %d%s", silver, silvername, copper, coppername)
		else
			return format("%d%s", copper, coppername)
		end
	elseif style == "SHORT" then
		if gold > 0 then
			return format("%.1f%s", amount / 10000, goldname)
		elseif silver > 0 then
			return format("%.1f%s", amount / 100, silvername)
		else
			return format("%d%s", amount, coppername)
		end
	elseif style == "SHORTINT" then
		if gold > 0 then
			return format("%d%s", gold, goldname)
		elseif silver > 0 then
			return format("%d%s", silver, silvername)
		else
			return format("%d%s", copper, coppername)
		end
	elseif style == "CONDENSED" then
		if gold > 0 then
			return format("%s%d|r.%s%02d|r.%s%02d|r", COLOR_GOLD, gold, COLOR_SILVER, silver, COLOR_COPPER, copper)
		elseif silver > 0 then
			return format("%s%d|r.%s%02d|r", COLOR_SILVER, silver, COLOR_COPPER, copper)
		else
			return format("%s%d|r", COLOR_COPPER, copper)
		end
	elseif style == "BLIZZARD" then
		if gold > 0 then
			return format("%s%s %d%s %d%s", BreakUpLargeNumbers(gold), goldname, silver, silvername, copper, coppername)
		elseif silver > 0 then
			return format("%d%s %d%s", silver, silvername, copper, coppername)
		else
			return format("%d%s", copper, coppername)
		end
	elseif style == "BLIZZARD2" then
		if gold > 0 then
			return format("%s%s %02d%s %02d%s", BreakUpLargeNumbers(gold), goldname, silver, silvername, copper, coppername)
		elseif silver > 0 then
			return format("%d%s %02d%s", silver, silvername, copper, coppername)
		else
			return format("%d%s", copper, coppername)
		end
	end

	-- Shouldn't be here; punt
	return self:FormatMoney(amount, "SMART")
end

function E:GetGearSlotInfo(unit, slot, deepScan)
	ScanTooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")
	ScanTooltip:SetInventoryItem(unit, slot)
	ScanTooltip:Show()

	local iLvl, enchantText, enchantColors, itemLevelColors
	local textures = {}

	if deepScan then
		for i = 1, 10 do
			local tex = _G["ElvUI_GearSlotTooltipTexture"..i]
			local hasTexture = tex and tex:GetTexture()
			if hasTexture then
				textures[i] = hasTexture
				tex:SetTexture()
			end
		end			
		for x = 1, ScanTooltip:NumLines() do
			local line = _G["ElvUI_GearSlotTooltipTextLeft"..x]
			if line then
				local lineText = line:GetText()
				local lr, lg, lb = line:GetTextColor()
				local tr, tg, tb = _G.ElvUI_GearSlotTooltipTextLeft1:GetTextColor()
				local itemLevel = lineText and lineText:match(MATCH_ITEM_LEVEL)
				local enchant = lineText:match(MATCH_ENCHANT)
				if enchant then
					enchantText = enchant:sub(1, 18)
					enchantColors = {lr, lg, lb}
				end
				if itemLevel and itemLevel ~= "1" then
					iLvl = tonumber(itemLevel)
					itemLevelColors = {tr, tg, tb}
				end
			end
		end		
	else
		local colorblind = GetCVarBool('colorblindmode') and 4 or 3
		for x = 2, colorblind do
			local line = _G["ElvUI_GearSlotTooltipTextLeft"..x]
			if line then
				local lineText = line:GetText()
				local itemLevel = lineText and lineText:match(MATCH_ITEM_LEVEL)
				if enchant then
					enchantText = enchant:sub(1, 18)
					enchantColors = {lr, lg, lb}
				end
				if itemLevel and itemLevel ~= "1" then
					iLvl = tonumber(itemLevel)
				end
			end
		end
	end

	ScanTooltip:Hide()

	return iLvl, enchantText, deepScan and textures, enchantColors, itemLevelColors
end

--Credit ls & Acidweb
function E:CalculateAverageItemLevel(iLevelDB, unit)
	local spec = GetInspectSpecialization(unit)
	local isOK, total, link = true, 0

	if not spec or spec == 0 then
		isOK = false
	end

	-- Armour
	for _, id in next, ARMOR_SLOTS do
		link = GetInventoryItemLink(unit, id)
		if link then
			local cur = iLevelDB[id]
			if cur and cur > 0 then
				total = total + cur
			end
		elseif GetInventoryItemTexture(unit, id) then
			isOK = false
		end
	end

	-- Main hand
	local mainItemLevel, mainQuality, mainEquipLoc, mainItemClass, mainItemSubClass, _ = 0
	link = GetInventoryItemLink(unit, 16)
	if link then
		mainItemLevel = iLevelDB[16]
		_, _, mainQuality, _, _, _, _, _, mainEquipLoc, _, _, mainItemClass, mainItemSubClass = GetItemInfo(link)
	elseif GetInventoryItemTexture(unit, 16) then
		isOK = false
	end

	-- Off hand
	local offItemLevel, offEquipLoc = 0
	link = GetInventoryItemLink(unit, 17)
	if link then
		offItemLevel = iLevelDB[17]
		_, _, _, _, _, _, _, _, offEquipLoc = GetItemInfo(link)
	elseif GetInventoryItemTexture(unit, 17) then
		isOK = false
	end

	if mainQuality == 6 or (not offEquipLoc and X2_INVTYPES[mainEquipLoc] and X2_EXCEPTIONS[mainItemClass] ~= mainItemSubClass and spec ~= 72) then
		mainItemLevel = max(mainItemLevel, offItemLevel)
		total = total + mainItemLevel * 2
	else
		total = total + mainItemLevel + offItemLevel
	end

	return isOK, total / 16
end

function E:GetUnitItemLevel(unit)
	local iLevelDB = {}

	for i = 1, 17 do
		if i ~= 4 then
			iLevelDB[i] = E:GetTTGearSlotInfo(unit, i)
		end
	end

	return E:CalculateAverageItemLevel(iLevelDB, unit)
end
