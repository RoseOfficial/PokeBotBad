local Paint = {}

local Walk = require "action.walk"
local Control = require "ai.control"
local Strategies = require "ai.strategies"
local Utils = require "util.utils"
local Analytics = require "util.analytics"
local Constants = require "util.constants"

local drawText = Utils.drawText
local LINE = Constants.OVERLAY_LINE_HEIGHT

function Paint.draw(currentMap)
	local y = 2

	-- Line 1: Elapsed time
	drawText(0, y, Utils.elapsedTime())
	y = y + LINE

	-- Line 2: Split delta + pace estimate (if PB data exists)
	local delta = Analytics.getSplitDelta()
	if delta then
		local pace = Analytics.getPace()
		local line2 = delta
		if pace then
			line2 = line2.." ("..pace..")"
		end
		drawText(0, y, line2)
	end
	y = y + LINE

	-- Line 3: Current area
	local area = Control.areaName
	if area then
		drawText(0, y, area)
	end
	y = y + LINE

	-- Line 4: Current strategy
	local strat = Walk.strategy
	if strat and strat.s then
		drawText(0, y, ">> "..strat.s)
	end
	y = y + LINE

	-- Line 5: Pace surplus/deficit
	if PACE_AWARE_RESETS and RESET_FOR_TIME then
		local surplus = Strategies.getPaceSurplus()
		if surplus ~= 0 then
			local sign = surplus >= 0 and "+" or ""
			drawText(0, y, "Pace: "..sign..math.floor(surplus * 60).."s")
		end
		y = y + LINE
	end

	-- Line 6: Run count, win rate, PB (compact)
	local displayStats = Analytics.getDisplayStats()
	if displayStats then
		drawText(0, y, "#"..displayStats.totalRuns.." | "..displayStats.winRate.." win | PB "..displayStats.pb)
	end

	return true
end

return Paint
