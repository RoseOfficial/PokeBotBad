local Paint = {}

local Walk = require "action.walk"
local Combat = require "ai.combat"
local Control = require "ai.control"
local Strategies = require "ai.strategies"
local Memory = require "util.memory"
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

	-- Line 6: Viability score
	if PACE_AWARE_RESETS and RESET_FOR_TIME then
		local viability = Strategies.getViabilityScore()
		if viability then
			drawText(0, y, "PB: "..math.floor(viability * 100).."%")
		end
		y = y + LINE
	end

	-- Line 7: Crit danger indicator (during battles)
	if CRIT_SURVIVAL_THRESHOLD and Memory.value("game", "battle") > 0 then
		local enemyAttack = Combat.enemyAttack()
		if enemyAttack then
			local ours, enemy = Combat.activePokemon()
			if enemy.baseSpeed and enemy.baseSpeed > 0 then
				local cRate = Combat.critRate(enemyAttack, enemy.baseSpeed)
				if cRate >= CRIT_SURVIVAL_THRESHOLD then
					local pct = math.floor(cRate * 100)
					drawText(0, y, "Crit: "..pct.."%")
				end
			end
		end
		y = y + LINE
	end

	-- Line 8: Run count, win rate, PB (compact)
	local displayStats = Analytics.getDisplayStats()
	if displayStats then
		drawText(0, y, "#"..displayStats.totalRuns.." | "..displayStats.winRate.." win | PB "..displayStats.pb)
	end

	return true
end

return Paint
