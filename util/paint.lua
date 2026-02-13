local Paint = {}

local Player = require "util.player"
local Walk = require "action.walk"
local Utils = require "util.utils"
local Analytics = require "util.analytics"

local elapsedTime = Utils.elapsedTime
local drawText = Utils.drawText

function Paint.draw(currentMap)
	local px, py = Player.position()
	drawText(0, 0, elapsedTime())
	drawText(0, 7, currentMap..": "..px.." "..py)

	local displayStats = Analytics.getDisplayStats()
	if displayStats then
		drawText(0, 14, "PB: "..displayStats.pb)
		drawText(0, 21, "#"..displayStats.totalRuns.." | "..displayStats.winRate.." win")
	end

	local resetReasons = Analytics.getResetReasons()
	if resetReasons then
		drawText(0, 28, resetReasons)
	end

	local deadliest = Analytics.getDeadliestStrategies(3)
	if deadliest then
		drawText(0, 35, "Deadliest:")
		for i, line in ipairs(deadliest) do
			drawText(0, 35 + i * 7, line)
		end
	end

	local strat = Walk.strategy
	if strat and strat.s then
		drawText(0, 63, ">> "..strat.s)
	end
	return true
end

return Paint
