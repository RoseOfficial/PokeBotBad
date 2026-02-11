local Bridge = {}

local Utils = require "util.utils"

local json = require "external.json"

local socket = require "socket"
local memory = require "util.memory"
local Constants = require "util.constants"

local client = nil
local timeStopped = true
local timePaused = false
local timeMin = 0
local timeFrames = 0

local gameName = nil

local function send(prefix, body)
	if client then
		local message = prefix
		if body then
			message = message.." "..body
		end
		local bytes, err = client:send(message.."\n")
		if not bytes then
			print("Bridge send error: "..tostring(err))
			client = nil
			Bridge.reconnect()
		end
		return bytes ~= nil
	end
end

local function readln()
	if client then
		local s, status, partial = client:receive("*l")
		if status == "closed" then
			print("Bridge: connection closed by server")
			client = nil
			Bridge.reconnect()
			return nil
		end
		if s and s ~= "" then
			return s
		end
	end
end

-- Wrapper functions

local function attemptConnect()
	local c = socket.connect("localhost", Constants.BRIDGE_PORT)
	if c then
		c:settimeout(Constants.BRIDGE_TIMEOUT)
		c:setoption("keepalive", true)
		return c
	end
	return nil
end

function Bridge.init(name)
	gameName = name
	if socket then
		for attempt = 1, Constants.BRIDGE_RETRY_ATTEMPTS do
			client = attemptConnect()
			if client then
				print("Connected to LiveSplit! (attempt "..attempt..")")
				send("init,"..gameName)
				return true
			end
			print("Connection attempt "..attempt.."/"..Constants.BRIDGE_RETRY_ATTEMPTS.." failed...")
			if attempt < Constants.BRIDGE_RETRY_ATTEMPTS then
				-- Busy-wait for BRIDGE_RETRY_DELAY seconds (no os.sleep in BizHawk Lua)
				local waitUntil = os.clock() + Constants.BRIDGE_RETRY_DELAY
				while os.clock() < waitUntil do end
			end
		end
		print("ERROR: Could not connect to LiveSplit after "..Constants.BRIDGE_RETRY_ATTEMPTS.." attempts!")
		print("Make sure LiveSplit Server is running on port "..Constants.BRIDGE_PORT..".")
	end
end

local function restoreTimerState()
	if not timeStopped then
		send("initgametime")
		send("starttimer")
		if timePaused then
			send("pausegametime")
		end
		print("Bridge: restored timer state (stopped="..tostring(timeStopped)..", paused="..tostring(timePaused)..")")
	end
end

function Bridge.reconnect()
	if not gameName then return false end
	local delay = Constants.BRIDGE_RETRY_DELAY
	for attempt = 1, Constants.BRIDGE_RETRY_ATTEMPTS do
		print("Reconnect attempt "..attempt.."/"..Constants.BRIDGE_RETRY_ATTEMPTS.."...")
		client = attemptConnect()
		if client then
			print("Reconnected to LiveSplit!")
			send("init,"..gameName)
			restoreTimerState()
			return true
		end
		if attempt < Constants.BRIDGE_RETRY_ATTEMPTS then
			local waitUntil = os.clock() + delay
			while os.clock() < waitUntil do end
			delay = delay * 2
		end
	end
	print("Reconnection failed after "..Constants.BRIDGE_RETRY_ATTEMPTS.." attempts.")
	return false
end

function Bridge.chatRandom(...)
	return Bridge.chat(Utils.random(arg))
end

function Bridge.chat(message, suppressed, extra, newLine)
	if not suppressed then
		if extra then
			p(message.." | "..extra, newLine)
		else
			p(message, newLine)
		end
	end
	return true
end

function Bridge.time()
	if (not timeStopped) then
		local frames = memory.raw(Constants.TIME_FRAMES_ADDR)
		local seconds = memory.raw(Constants.TIME_SECONDS_ADDR)
		local minutes = memory.raw(Constants.TIME_MINUTES_ADDR)
		local hours = memory.raw(Constants.TIME_HOURS_ADDR)

		if (frames == timeFrames) then
			local seconds2 = seconds + (frames / 60)
			local message = hours..":"..minutes..":"..seconds2
			send("setgametime", message)
			if timeFrames == 59 then
				timeFrames = 0
			else
				timeFrames = (frames + 1)
			end
		end

		if timePaused then
			send("unpausegametime")
			timePaused = false
		end
	end
end

function Bridge.command(command)
	print("Bridge Command")
	return send(command)
end

function Bridge.comparisonTime()
	print("Bridge Comparison Time")
	return send("getcomparisonsplittime")
end

function Bridge.process()
	local response = readln()
	if response then
		if response:find("name:") then
			return response:gsub("name:", "")
		end
	end
end

function Bridge.pollForName()
	Bridge.polling = true
end

-- These functions are called throughout the codebase but the send commands
-- were disabled by the original author. Kept as no-ops to avoid nil errors.
function Bridge.caught() end
function Bridge.hp() end
function Bridge.stats() end
function Bridge.input() end
function Bridge.encounter() end

function Bridge.liveSplit()
	send("initgametime")
	send("pausegametime")
	timePaused = true
	send("starttimer")
	timeStopped = false
end

function Bridge.split(finished)
	if finished then
		timeStopped = true
	end
	send("split")
	Utils.splitUpdate()
end

function Bridge.pausegametime()
	send("pausegametime")
	timePaused = true
end

function Bridge.report(report)
	if INTERNAL and not STREAMING_MODE then
		print(json.encode(report))
	end
	send("report", json.encode(report))
end

-- GUESSING

function Bridge.guessing(guess, enabled)
	send(guess, tostring(enabled))
end

function Bridge.guessResults(guess, result)
	send(guess.."results", result)
end

function Bridge.moonResults(encounters, cutter)
	Bridge.guessResults("moon", encounters..","..(cutter and "cutter" or "none"))
end

-- RESET

function Bridge.reset()
	send("reset")
	timeStopped = false
	timePaused = false
end

function Bridge.close()
	if client then
		client:close()
		client = nil
	end
	print("Bridge closed")
end

return Bridge
