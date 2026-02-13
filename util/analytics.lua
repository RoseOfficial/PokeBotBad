local Constants = require "util.constants"

local Analytics = {}

-- Internal state: all-time stats (parsed from logs + live)
local allTime = {
	resets = 0,
	victories = 0,
	victoryTimes = {},    -- sorted array of seconds
	pb = nil,             -- formatted time string
	pbSeconds = math.huge,
	resetReasons = {},    -- category -> count
	resetAreas = {},      -- area name -> count
	parseWarnings = 0,
}

-- Internal state: current session only
local session = {
	resets = 0,
	victories = 0,
	victoryTimes = {},
	resetReasons = {},
	resetAreas = {},
	strategyResets = {},
	strategyCompletes = {},
	startClock = nil,
}

-- Internal state: split tracking
local splits = {
	pbSplits = {},      -- splitNumber -> {area=string, igt=seconds}
	pbFinish = nil,     -- total PB time in seconds
	currentSplits = {}, -- splitNumber -> {area=string, igt=seconds}
	latestSplit = 0,    -- highest split number in current run
	pbSplitsPath = nil, -- file path for saving/loading
}

-- Internal state: per-checkpoint reset tracking (for threshold tuning)
local checkpointStats = {
	timeResets = {},       -- checkpoint -> count of time-based resets
	totalResets = {},      -- checkpoint -> count of all resets at that area
	adjustments = {},      -- checkpoint -> computed multiplier (0.9-1.1)
}

-- Helpers

local function findPlain(str, substr)
	return str:find(substr, 1, true)
end

local function timeToSeconds(timeStr)
	local h, m, s = timeStr:match("(%d+):(%d+):(%d+)")
	if not h then return nil end
	return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

local function secondsToTime(totalSecs)
	if not totalSecs then return "N/A" end
	local secs = math.floor(totalSecs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	local s = secs % 60
	return string.format("%d:%02d:%02d", h, m, s)
end

local function increment(tbl, key)
	tbl[key] = (tbl[key] or 0) + 1
end

local function median(sorted)
	local n = #sorted
	if n == 0 then return nil end
	if n % 2 == 1 then
		return sorted[math.ceil(n / 2)]
	else
		local mid = math.floor(n / 2)
		return math.floor((sorted[mid] + sorted[mid + 1]) / 2)
	end
end

local function average(arr)
	if #arr == 0 then return nil end
	local sum = 0
	for _, v in ipairs(arr) do sum = sum + v end
	return math.floor(sum / #arr)
end

local function sortedByCount(tbl)
	local sorted = {}
	for k, v in pairs(tbl) do
		table.insert(sorted, {name = k, count = v})
	end
	table.sort(sorted, function(a, b) return a.count > b.count end)
	return sorted
end

-- Reset reason classification
--
-- Categories: DVs, Time, Combat, RNG, Encounters, Other
--
-- Text-based (for parsing historical logs):
--   DVs:        "bad nidoran", "bad squirtle", "unrunnable"
--   Time:       "took too long"
--   RNG:        "critical", "sand-attack", "missed", "confusion", "slumbering"
--   Combat:     "died", "growled to death", "ran out of potions", "death by", "yolo strats"
--   Encounters: "too many encounters"
--   Other:      everything else
--
-- Code-based (for live hooks):
--   DVs: "stats"  |  Time: "time"  |  Combat: "death","potion","yolo"
--   RNG: "miss","critical","accuracy","confusion","sleep"
--   Encounters: "encounters"  |  Other: everything else

local function classifyReasonFromText(text)
	local lower = text:lower()
	if findPlain(lower, "bad nidoran") or findPlain(lower, "bad squirtle") or findPlain(lower, "unrunnable") then
		return "DVs"
	end
	if findPlain(lower, "took too long") then
		return "Time"
	end
	if findPlain(lower, "critical") or findPlain(lower, "sand-attack") or findPlain(lower, "missed") or findPlain(lower, "confusion") or findPlain(lower, "slumbering") then
		return "RNG"
	end
	if findPlain(lower, "died") or findPlain(lower, "growled to death") or findPlain(lower, "ran out of potions") or findPlain(lower, "death by") or findPlain(lower, "yolo strats") then
		return "Combat"
	end
	if findPlain(lower, "too many encounters") then
		return "Encounters"
	end
	return "Other"
end

local function classifyReasonFromCode(code)
	if code == "stats" then return "DVs" end
	if code == "time" then return "Time" end
	if code == "death" or code == "potion" or code == "yolo" then return "Combat" end
	if code == "miss" or code == "critical" or code == "accuracy" or code == "confusion" or code == "sleep" then return "RNG" end
	if code == "encounters" then return "Encounters" end
	return "Other"
end

-- Log parsing

local function parseResetLine(line)
	-- Normal: "Reset at {AREA} | {TIME} | {REASON}. | {SEED}"
	local area, time, reason = line:match("^Reset at (.+) | (%d+:%d+:%d+) |(.+)%.")
	if not area then
		-- BibleThump separator (deep runs): "Reset at {AREA} | {TIME} BibleThump {REASON}. | {SEED}"
		area, time, reason = line:match("^Reset at (.+) | (%d+:%d+:%d+) BibleThump(.+)%.")
	end
	return area, time, reason
end

local function parseVictoryLine(line)
	-- Matches both old ("Finished the game in {TIME} | {SEED}")
	-- and new ("{DATE} | Finished the game in {TIME} | Time: ...") formats
	return line:match("Finished the game in (%d+:%d+:%d+)")
end

local function parseLogs(resetPath, victoryPath)
	local f = io.open(resetPath, "r")
	if f then
		for line in f:lines() do
			local area, time, reason = parseResetLine(line)
			if area then
				allTime.resets = allTime.resets + 1
				increment(allTime.resetAreas, area)
				if reason then
					increment(allTime.resetReasons, classifyReasonFromText(reason))
				end
				-- Track per-checkpoint reset stats for threshold tuning
				local checkpoint = Constants.AREA_TO_CHECKPOINT[area]
				if checkpoint then
					increment(checkpointStats.totalResets, checkpoint)
					if reason and findPlain(reason:lower(), "took too long") then
						increment(checkpointStats.timeResets, checkpoint)
					end
				end
			elseif line:match("%S") then
				allTime.parseWarnings = allTime.parseWarnings + 1
			end
		end
		f:close()
	end

	f = io.open(victoryPath, "r")
	if f then
		for line in f:lines() do
			local time = parseVictoryLine(line)
			if time then
				allTime.victories = allTime.victories + 1
				local secs = timeToSeconds(time)
				if secs then
					table.insert(allTime.victoryTimes, secs)
					if secs < allTime.pbSeconds then
						allTime.pbSeconds = secs
						allTime.pb = time
					end
				end
			elseif line:match("%S") then
				allTime.parseWarnings = allTime.parseWarnings + 1
			end
		end
		f:close()
	end

	table.sort(allTime.victoryTimes)
end

-- Split tracking

local function loadPBSplits(path)
	if not path then return end
	local f = io.open(path, "r")
	if not f then return end
	for line in f:lines() do
		local num, area, igt = line:match("^(%d+)|(.+)|(%d+)$")
		if num then
			splits.pbSplits[tonumber(num)] = {
				area = area,
				igt = tonumber(igt),
			}
		end
	end
	f:close()
end

local function savePBSplits(path, splitData)
	if not path then return end
	local f = io.open(path, "w")
	if not f then
		print("Could not save PB splits: "..path)
		return
	end
	local keys = {}
	for k in pairs(splitData) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local entry = splitData[k]
		f:write(k.."|"..entry.area.."|"..entry.igt.."\n")
	end
	f:close()
end

-- Threshold tuning: compute per-checkpoint adjustments from historical reset rates

local function computeThresholdAdjustments()
	for checkpoint, timeCount in pairs(checkpointStats.timeResets) do
		if timeCount >= Constants.THRESHOLD_MIN_SAMPLES then
			local total = checkpointStats.totalResets[checkpoint] or timeCount
			local timeResetRate = timeCount / total

			-- Asymmetric dampened adjustment:
			-- Loosen 1.5x faster than tighten (killing a potential PB costs more
			-- than wasting time on a slow run). Square root dampens noise from
			-- small sample sizes — prevents overreacting to a few unlucky resets.
			local target = Constants.THRESHOLD_TARGET_RESET_RATE
			local maxAdj = Constants.THRESHOLD_MAX_ADJUSTMENT
			local deviation = timeResetRate - target
			local normalized = math.abs(deviation) / target
			local magnitude = math.sqrt(normalized) * maxAdj
			if deviation > 0 then
				-- Too tight: loosen aggressively
				magnitude = magnitude * 1.5
			end
			local sign = deviation >= 0 and 1 or -1
			local adjustment = 1.0 + sign * math.min(magnitude, maxAdj)
			checkpointStats.adjustments[checkpoint] = adjustment
		end
	end
end

-- Public API

function Analytics.init(resetLogPath, victoryLogPath, pbSplitsPath)
	session.startClock = os.time()
	parseLogs(resetLogPath, victoryLogPath)

	splits.pbSplitsPath = pbSplitsPath
	loadPBSplits(pbSplitsPath)
	if allTime.pbSeconds < math.huge then
		splits.pbFinish = allTime.pbSeconds
	end

	local totalRuns = allTime.resets + allTime.victories
	local pbStr = allTime.pb or "N/A"
	local splitCount = 0
	for _ in pairs(splits.pbSplits) do splitCount = splitCount + 1 end
	p("Analytics loaded: "..totalRuns.." runs, "..allTime.victories.." victories, PB: "..pbStr.." ("..splitCount.." PB splits)", true)
	if allTime.parseWarnings > 0 then
		p("Analytics: "..allTime.parseWarnings.." lines skipped during log parsing", true)
	end

	-- Compute threshold adjustments from historical data
	computeThresholdAdjustments()
	local adjCount = 0
	for checkpoint, adj in pairs(checkpointStats.adjustments) do
		adjCount = adjCount + 1
		p("Threshold adjustment: "..checkpoint.." = "..string.format("%.3f", adj), true)
	end
	if adjCount > 0 then
		p("Analytics: "..adjCount.." checkpoint threshold adjustments computed", true)
	end
end

function Analytics.onStrategyComplete(strategyName)
	if not strategyName then return end
	increment(session.strategyCompletes, strategyName)
end

function Analytics.onReset(data)
	allTime.resets = allTime.resets + 1
	session.resets = session.resets + 1

	if data.strategy then
		increment(session.strategyResets, data.strategy)
	end

	if data.area then
		increment(allTime.resetAreas, data.area)
		increment(session.resetAreas, data.area)
	end

	local category
	if data.reasonCode then
		category = classifyReasonFromCode(data.reasonCode)
	elseif data.reasonText then
		category = classifyReasonFromText(data.reasonText)
	else
		category = "Other"
	end
	increment(allTime.resetReasons, category)
	increment(session.resetReasons, category)

	local totalSessionRuns = session.resets + session.victories
	if totalSessionRuns % Constants.ANALYTICS_SUMMARY_INTERVAL == 0 then
		Analytics.summary()
	end
end

function Analytics.onVictory(data)
	allTime.victories = allTime.victories + 1
	session.victories = session.victories + 1

	if data.time then
		local secs = timeToSeconds(data.time)
		if secs then
			table.insert(allTime.victoryTimes, secs)
			table.sort(allTime.victoryTimes)
			table.insert(session.victoryTimes, secs)
			table.sort(session.victoryTimes)

			if secs < allTime.pbSeconds then
				local oldPBSecs = allTime.pbSeconds
				allTime.pbSeconds = secs
				allTime.pb = data.time
				splits.pbFinish = secs
				if oldPBSecs < math.huge then
					p("*** NEW PB: "..data.time.." (improved by "..secondsToTime(oldPBSecs - secs)..") ***", true)
				else
					p("*** NEW PB: "..data.time.." ***", true)
				end
				-- Save current run's splits as new PB splits
				if splits.latestSplit > 0 then
					splits.pbSplits = {}
					for k, v in pairs(splits.currentSplits) do
						splits.pbSplits[k] = {area = v.area, igt = v.igt}
					end
					savePBSplits(splits.pbSplitsPath, splits.pbSplits)
					p("PB splits saved ("..splits.latestSplit.." splits)", true)
				end
			end
		end
	end
end

function Analytics.onSplit(splitNumber, areaName, igtSeconds)
	if not splitNumber or not igtSeconds then return end
	splits.currentSplits[splitNumber] = {
		area = areaName or "unknown",
		igt = igtSeconds,
	}
	splits.latestSplit = splitNumber
end

function Analytics.getSplitDelta()
	if splits.latestSplit == 0 then return nil end
	local current = splits.currentSplits[splits.latestSplit]
	local pb = splits.pbSplits[splits.latestSplit]
	if not current or not pb then return nil end
	local delta = current.igt - pb.igt
	local sign = delta >= 0 and "+" or "-"
	local absDelta = math.abs(delta)
	if absDelta >= 60 then
		local mins = math.floor(absDelta / 60)
		local secs = absDelta % 60
		return sign..mins..":"..string.format("%02d", secs)
	end
	return sign..absDelta.."s"
end

function Analytics.getPace()
	if not splits.pbFinish or splits.latestSplit == 0 then return nil end
	local current = splits.currentSplits[splits.latestSplit]
	local pb = splits.pbSplits[splits.latestSplit]
	if not current or not pb then return nil end

	local currentDelta = current.igt - pb.igt

	-- Collect deltas at every completed split to detect a trend
	local deltas = {}
	for i = 1, splits.latestSplit do
		local c = splits.currentSplits[i]
		local p = splits.pbSplits[i]
		if c and p then
			table.insert(deltas, {split = i, delta = c.igt - p.igt})
		end
	end

	-- Need 2+ data points to extrapolate a trend; otherwise use simple additive
	if #deltas < 2 then
		return "~"..secondsToTime(splits.pbFinish + currentDelta)
	end

	-- Trend: how much is the delta changing per split?
	local trendPerSplit = (deltas[#deltas].delta - deltas[1].delta)
	                    / (deltas[#deltas].split - deltas[1].split)

	-- Count remaining splits from PB data
	local maxPBSplit = 0
	for k in pairs(splits.pbSplits) do
		if k > maxPBSplit then maxPBSplit = k end
	end
	local remainingSplits = math.max(0, maxPBSplit - splits.latestSplit)

	-- Dampened extrapolation (0.5x) prevents wild swings from small samples
	local projectedDelta = currentDelta + trendPerSplit * remainingSplits * 0.5
	local estimatedFinish = math.max(0, splits.pbFinish + projectedDelta)
	return "~"..secondsToTime(estimatedFinish)
end

function Analytics.resetSplits()
	splits.currentSplits = {}
	splits.latestSplit = 0
end

function Analytics.pb()
	return allTime.pb or "N/A"
end

function Analytics.isNewPB(timeStr)
	local secs = timeToSeconds(timeStr)
	if not secs then return false end
	return secs < allTime.pbSeconds
end

function Analytics.getDisplayStats()
	local totalRuns = allTime.resets + allTime.victories
	if totalRuns == 0 then return nil end
	local winRate = string.format("%.1f%%", (allTime.victories / totalRuns) * 100)
	return {
		pb = allTime.pb or "N/A",
		totalRuns = totalRuns,
		winRate = winRate,
	}
end

function Analytics.getResetReasons()
	if allTime.resets == 0 then return nil end
	local reasons = sortedByCount(allTime.resetReasons)
	local parts = {}
	for _, entry in ipairs(reasons) do
		local short = entry.name
		if short == "Encounters" then short = "Enc" end
		table.insert(parts, short..":"..entry.count)
	end
	return table.concat(parts, " ")
end

local function calculateStrategyStats()
	local merged = {}
	for name, count in pairs(session.strategyCompletes) do
		if not merged[name] then merged[name] = {resets = 0, completes = 0} end
		merged[name].completes = count
	end
	for name, count in pairs(session.strategyResets) do
		if not merged[name] then merged[name] = {resets = 0, completes = 0} end
		merged[name].resets = count
	end

	local result = {}
	local minAttempts = Constants.ANALYTICS_MIN_STRATEGY_ATTEMPTS
	for name, data in pairs(merged) do
		local total = data.resets + data.completes
		if total >= minAttempts then
			local failRate = data.resets / total
			table.insert(result, {
				name = name,
				resets = data.resets,
				completes = data.completes,
				total = total,
				failRate = failRate,
			})
		end
	end
	table.sort(result, function(a, b) return a.failRate > b.failRate end)
	return result
end

function Analytics.getDeadliestStrategies(limit)
	local sessionRuns = session.resets + session.victories
	if sessionRuns < Constants.ANALYTICS_MIN_RUNS_FOR_STRATEGY_DISPLAY then
		return nil
	end
	local stats = calculateStrategyStats()
	if #stats == 0 then return nil end
	local result = {}
	for i = 1, math.min(limit or 3, #stats) do
		local entry = stats[i]
		if entry.resets == 0 then break end
		table.insert(result, string.format("%s %d/%d %.0f%%", entry.name, entry.resets, entry.total, entry.failRate * 100))
	end
	if #result == 0 then return nil end
	return result
end

function Analytics.summary()
	local totalRuns = allTime.resets + allTime.victories

	p("=== Run Analytics ===", true)
	p("Total runs: "..totalRuns, true)
	p("Victories: "..allTime.victories.."  |  Resets: "..allTime.resets, true)
	if totalRuns > 0 then
		p("Win rate: "..string.format("%.1f%%", (allTime.victories / totalRuns) * 100), true)
	end
	p("PB: "..(allTime.pb or "N/A"), true)

	if #allTime.victoryTimes > 0 then
		p("", true)
		p("-- Victory Times --", true)
		p("Best:    "..secondsToTime(allTime.victoryTimes[1]), true)
		p("Worst:   "..secondsToTime(allTime.victoryTimes[#allTime.victoryTimes]), true)
		if #allTime.victoryTimes > 1 then
			p("Median:  "..secondsToTime(median(allTime.victoryTimes)), true)
			p("Average: "..secondsToTime(average(allTime.victoryTimes)), true)
		end
	end

	if allTime.resets > 0 then
		p("", true)
		p("-- Reset Reasons --", true)
		local reasons = sortedByCount(allTime.resetReasons)
		for _, entry in ipairs(reasons) do
			local pct = string.format("%.1f%%", (entry.count / allTime.resets) * 100)
			p("  "..entry.name..": "..entry.count.." ("..pct..")", true)
		end
	end

	if allTime.resets > 0 then
		p("", true)
		p("-- Reset Areas (top 10) --", true)
		local areas = sortedByCount(allTime.resetAreas)
		for i, entry in ipairs(areas) do
			if i > 10 then break end
			p("  "..entry.name..": "..entry.count, true)
		end
	end

	p("", true)
	p("-- Current Session --", true)
	local sessionRuns = session.resets + session.victories
	p("Runs: "..sessionRuns.."  |  Victories: "..session.victories, true)
	if session.startClock then
		local duration = os.time() - session.startClock
		local hours = math.floor(duration / 3600)
		local mins = math.floor((duration % 3600) / 60)
		p("Duration: "..hours.."h "..mins.."m", true)
	end
	local deadliest = calculateStrategyStats()
	if #deadliest > 0 then
		p("", true)
		p("-- Deadliest Strategies (Session) --", true)
		for i, entry in ipairs(deadliest) do
			if i > 10 then break end
			if entry.resets == 0 then break end
			local pct = string.format("%.1f%%", entry.failRate * 100)
			p("  "..entry.name..": "..entry.resets.."/"..entry.total.." ("..pct.." fail)", true)
		end
	end

	p("====================", true)
end

function Analytics.getThresholdAdjustment(checkpointName)
	return checkpointStats.adjustments[checkpointName]
end

-- Run viability scoring: estimate PB probability from current pace

function Analytics.computeViability(checkpointName, currentIGT)
	if not splits.pbFinish or splits.latestSplit == 0 then return nil end

	-- Find the PB split time closest to current run position
	local pbSplitTime = nil
	for num, data in pairs(splits.pbSplits) do
		if splits.currentSplits[num] and data.igt then
			pbSplitTime = data.igt
		end
	end
	if not pbSplitTime then return nil end

	local timeAhead = pbSplitTime - currentIGT  -- positive = ahead of PB
	local pbRemaining = splits.pbFinish - pbSplitTime

	-- Sigmoid viability curve: ratio = timeAhead / pbRemaining
	-- Steepness 8 gives useful spread across the run:
	--   Mt. Moon 2min behind:  ratio=-0.023, score=0.45 (recoverable)
	--   V. Road 2min behind:   ratio=-0.12,  score=0.28 (unlikely)
	--   V. Road 30s behind:    ratio=-0.03,  score=0.44 (still possible)
	-- Being exactly on PB pace = 50% (generous — matching your best ever
	-- is harder than it sounds, but the sigmoid naturally drops from there).
	if pbRemaining <= 0 then return nil end
	local ratio = timeAhead / pbRemaining
	local score = 1.0 / (1.0 + math.exp(-8 * ratio))
	return math.max(0.0, math.min(1.0, score))
end

return Analytics
