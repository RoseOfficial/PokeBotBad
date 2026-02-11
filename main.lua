-- Load configuration (fall back to defaults if config.lua is missing)
local configOk, config = pcall(dofile, "config.lua")
if not configOk then
	print("config.lua not found, using defaults")
	config = {}
end

-- OPTIONS (from config or defaults)

RESET_FOR_TIME = config.RESET_FOR_TIME or false
BEAST_MODE = config.BEAST_MODE or false

INITIAL_SPEED = config.INITIAL_SPEED or 1500
AFTER_BROCK_SPEED = config.AFTER_BROCK_SPEED or 1500
AFTER_MOON_SPEED = config.AFTER_MOON_SPEED or 500
E4_SPEED = config.E4_SPEED or 200

RESET_LOG = config.RESET_LOG or "./wiki/red/resets.txt"
VICTORY_LOG = config.VICTORY_LOG or "./wiki/red/victories.txt"

local CUSTOM_SEED  = config.CUSTOM_SEED
local NIDORAN_NAME = config.NIDORAN_NAME or "A"
local PAINT_ON     = config.PAINT_ON ~= false  -- default true
STREAMING_MODE     = config.STREAMING_MODE ~= false  -- default true

-- START CODE (hard hats on)

VERSION = "2.5.0"
CURRENT_SPEED = nil

local Data = require "data.data"

Data.init()

local Battle = require "action.battle"
local Textbox = require "action.textbox"
local Walk = require "action.walk"

local Combat = require "ai.combat"
local Control = require "ai.control"
local Strategies = require("ai."..Data.gameName..".strategies")

local Pokemon = require "storage.pokemon"

local Bridge = require "util.bridge"
local Input = require "util.input"
local Memory = require "util.memory"
local Paint = require "util.paint"
local Utils = require "util.utils"
local Settings = require "util.settings"

local hasAlreadyStartedPlaying = false
local oldSeconds
local running = true
local previousMap

-- HELPERS

function resetAll()
	Strategies.softReset()
	Combat.reset()
	Control.reset()
	Walk.reset()
	Paint.reset()
	Bridge.reset()
	Utils.reset()
	oldSeconds = 0
	running = false

	CURRENT_SPEED = INITIAL_SPEED
  	client.speedmode(INITIAL_SPEED)

	if CUSTOM_SEED then
		Data.run.seed = CUSTOM_SEED
		Strategies.replay = true
		p("RUNNING WITH A FIXED SEED ("..NIDORAN_NAME.." "..Data.run.seed.."), every run will play out identically!", true)
	else
		Data.run.seed = os.time()
		print("PokeBot v"..VERSION..": "..(BEAST_MODE and "BEAST MODE seed" or "Seed:").." "..Data.run.seed)
	end
	math.randomseed(Data.run.seed)
end


-- EXECUTE

p("Welcome to PokeBot "..Utils.capitalize(Data.gameName).." v"..VERSION, true)

Control.init()
Utils.init()

if CUSTOM_SEED then
	Strategies.reboot()
else
	hasAlreadyStartedPlaying = Utils.ingame()
end

Strategies.init(hasAlreadyStartedPlaying)

if hasAlreadyStartedPlaying and RESET_FOR_TIME then
	RESET_FOR_TIME = false
	p("Disabling time-limit resets as the game is already running. Please reset the emulator and restart the script if you'd like to go for a fast time.", true)
end

if STREAMING_MODE then
	if not CUSTOM_SEED or BEAST_MODE then
		RESET_FOR_TIME = true
	end
	Bridge.init(Data.gameName)
else
	if PAINT_ON then
		Input.setDebug(true)
	end
end



-- LOOP

local function generateNextInput(currentMap)
	if not Utils.ingame() then
		Bridge.pausegametime()
		if currentMap == 0 then
			if running then
				if not hasAlreadyStartedPlaying then
					if emu.framecount() ~= 1 then Strategies.reboot() end
					hasAlreadyStartedPlaying = true
				else
					resetAll()
				end
			else
				Settings.startNewAdventure()
			end
		else
			if not running then
				Bridge.liveSplit()
				running = true
			end
			Settings.choosePlayerNames()
		end
	else
		Bridge.time()
		Utils.splitCheck()
		local battleState = Memory.value("game", "battle")
		Control.encounter(battleState)

		local curr_hp = Combat.hp()
		Combat.updateHP(curr_hp)

		if curr_hp == 0 and not Control.canDie() and Pokemon.index(0) > 0 then
			Strategies.death(currentMap)
		elseif Walk.strategy then
			if Strategies.execute(Walk.strategy) then
				if Walk.traverse(currentMap) == false then
					return generateNextInput(currentMap)
				end
			end
		elseif battleState > 0 then
			if not Control.shouldCatch() then
				Battle.automate()
			end
		elseif Textbox.handle() then
			if Walk.traverse(currentMap) == false then
				return generateNextInput(currentMap)
			end
		end
	end
end

while true do
	local currentMap = Memory.value("game", "map")
	local battleState = Memory.value("game", "battle")
	if currentMap ~= previousMap then
		Input.clear()
		previousMap = currentMap
	end
	if Strategies.frames then
		if battleState == 0 then
			Strategies.frames = Strategies.frames + 1
		end
		Utils.drawText(0, 80, Strategies.frames)
	end
	if Bridge.polling then
		Settings.pollForResponse(NIDORAN_NAME)
	end

	if not Input.update() then
		generateNextInput(currentMap)
	end
	-- Stuck detection: warn if player position hasn't changed during walk
	-- Skip during battles since position naturally doesn't change while fighting
	if battleState > 0 then
		Walk.resetStuck()
	elseif Walk.strategy and Walk.isStuck() then
		print("WARNING: Player position unchanged for 600+ frames during walk")
	end

	if STREAMING_MODE then
		local newSeconds = Memory.value("time", "seconds")
		if newSeconds ~= oldSeconds and (newSeconds > 0 or Memory.value("time", "frames") > 0) then
			Bridge.time(Utils.elapsedTime())
			oldSeconds = newSeconds
		end
		if PAINT_ON then
			Paint.draw(currentMap)
		end
	elseif PAINT_ON then
		Paint.draw(currentMap)
	end

	Input.advance()
	emu.frameadvance()
end

Bridge.close()
