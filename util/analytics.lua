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
	startClock = nil,
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

-- Public API

function Analytics.init(resetLogPath, victoryLogPath)
	session.startClock = os.time()
	parseLogs(resetLogPath, victoryLogPath)
	local totalRuns = allTime.resets + allTime.victories
	local pbStr = allTime.pb or "N/A"
	p("Analytics loaded: "..totalRuns.." runs, "..allTime.victories.." victories, PB: "..pbStr, true)
	if allTime.parseWarnings > 0 then
		p("Analytics: "..allTime.parseWarnings.." lines skipped during log parsing", true)
	end
end

function Analytics.onReset(data)
	allTime.resets = allTime.resets + 1
	session.resets = session.resets + 1

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
				if oldPBSecs < math.huge then
					p("*** NEW PB: "..data.time.." (improved by "..secondsToTime(oldPBSecs - secs)..") ***", true)
				else
					p("*** NEW PB: "..data.time.." ***", true)
				end
			end
		end
	end
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
	p("====================", true)
end

return Analytics
