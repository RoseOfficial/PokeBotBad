local Constants = {}

-- Sentinel value used throughout the codebase to mean "effectively infinite" or "done checking"
Constants.OVER_9000 = 9001

-- Stuck detection thresholds (in frames, game runs at ~60fps)
Constants.STUCK_WARNING_FRAMES = 18000   -- ~5 minutes
Constants.STUCK_RESET_FRAMES = 36000     -- ~10 minutes
Constants.WALK_STUCK_FRAMES = 600        -- ~10 seconds

-- Combat constants
Constants.RED_BAR_FRACTION = 0.2         -- HP threshold for red bar
Constants.MIN_DAMAGE_RATIO = 217 / 255   -- Gen 1 minimum damage roll

-- Pokemon IDs (internal game index numbers)
Constants.METAPOD_ID = 124

-- Bridge connection
Constants.BRIDGE_PORT = 16834
Constants.BRIDGE_RETRY_ATTEMPTS = 3
Constants.BRIDGE_RETRY_DELAY = 0.5       -- seconds (initial delay between retries)
Constants.BRIDGE_MAX_DELAY = 2           -- seconds (cap for exponential backoff)
Constants.BRIDGE_TIMEOUT = 0.050         -- seconds (socket timeout)

-- Memory: In-game time registers (read via Memory.raw)
Constants.TIME_FRAMES_ADDR = 0x1A45
Constants.TIME_SECONDS_ADDR = 0x1A44
Constants.TIME_MINUTES_ADDR = 0x1A43
Constants.TIME_HOURS_ADDR = 0x1A41

-- Memory: Battle system addresses
Constants.OPPONENT_MOVES_BASE = 0x0FED
Constants.OUR_MOVES_BASE = 0x101C
Constants.OUR_BATTLE_MOVES_BASE = 0x101B  -- 1-indexed: 0x101B + moveIndex
Constants.OUR_PP_BASE = 0x102D
Constants.OUR_PP_BATTLE_BASE = 0x102C     -- 1-indexed: 0x102C + moveIndex
Constants.MOVE_COUNT_ADDR = 0x101F
Constants.SLEEP_STATUS_ADDR = 0x116F
Constants.CONFUSION_ADDR = 0x106B
Constants.FREEZE_STATUS_ADDR = 0x0FE9    -- Yellow-specific freeze check
Constants.EXP_ADDR_HIGH = 0x1179
Constants.EXP_ADDR_MID = 0x117A
Constants.EXP_ADDR_LOW = 0x117B

-- Memory: NPC/player positions
Constants.NPC_X_ADDR = 0x0223
Constants.NPC_Y_ADDR = 0x0222
Constants.NPC_SPRITE_ADDR = 0x0242       -- Red-specific NPC sprite position

-- Memory: Menu/UI state
Constants.NAMING_SCREEN_ADDR = 0x10B7
Constants.TEXT_ACCEPT_ADDR = 0x0C3A      -- Yellow text input acceptance
Constants.INGAME_STATE_ADDR = 0x020E
Constants.YELLOW_START_MENU_ADDR = 0x0F95
Constants.YELLOW_OPTIONS_ADDR = 0x0D3D

-- Memory: Inventory
Constants.ITEM_BASE_ADDR = 0x131E

-- Battle menu state values
Constants.BATTLE_MENU_READY = 94         -- battle menu is interactable
Constants.BATTLE_MENU_ATTACK_SELECT = 106 -- attack selection is open
Constants.TEXT_INPUT_ACTIVE = 240         -- naming/text input screen active
Constants.POKEMON_MENU_YELLOW = 51       -- pokemon menu identifier (Yellow)
Constants.POKEMON_MENU_RED = 103         -- pokemon menu identifier (Red)
Constants.SPLIT_CHECK_INTERVAL = 600     -- frames between split time checks

-- Game detection (used in data.lua with direct memory.readbyte — not via Memory.raw)
Constants.TITLE_TEXT_ADDR = 0x0447
Constants.YELLOW_DOMAIN_SIZE_THRESHOLD = 30000

-- Party data structure
Constants.PARTY_BASE_ADDR = 0x116B
Constants.PARTY_SLOT_STRIDE = 0x2C

-- Settings
Constants.START_WAIT = 99
Constants.SETTINGS_MENU_YELLOW = 93
Constants.SETTINGS_MENU_RED = 94
Constants.YELLOW_TEXT_SPEED_MASK = 0xF
Constants.YELLOW_ANIMATION_MASK = 0x80
Constants.YELLOW_BATTLE_STYLE_MASK = 0x40

-- NPC dodge addresses
Constants.DODGE_OLD_MAN_ADDR = 0x0273

-- Gameplay thresholds
Constants.POTION_TOPOFF_MARGIN = 49
Constants.SUPER_POTION_HEAL = 50
Constants.POTION_HEAL = 20
Constants.EVOLUTION_TIMEOUT_FRAMES = 3600
Constants.VICTORY_TIMEOUT_FRAMES = 1800
Constants.CHAMPION_MENU_VALUE = 252

-- Pace-aware resets
Constants.PACE_CARRY_FACTOR = 0.5       -- How much surplus carries forward (0=none, 1=full)
Constants.PACE_MAX_BONUS_SECONDS = 60   -- Max seconds a checkpoint can gain from surplus
Constants.PACE_MIN_LIMIT_FACTOR = 0.85  -- Floor: never tighten past 85% of base limit

-- Per-checkpoint pace tuning (overrides flat constants above)
Constants.CHECKPOINT_PACE = {
	bulbasaur     = { carry = 0.3, floor = 0.90 },  -- short, deterministic
	nidoran       = { carry = 0.2, floor = 0.80 },  -- high RNG variance
	old_man       = { carry = 0.5, floor = 0.85 },
	forest        = { carry = 0.5, floor = 0.85 },
	brock         = { carry = 0.6, floor = 0.85 },  -- deterministic
	shorts        = { carry = 0.5, floor = 0.85 },
	route3        = { carry = 0.5, floor = 0.85 },
	mt_moon       = { carry = 0.3, floor = 0.80 },  -- HIGH variance
	mankey        = { carry = 0.5, floor = 0.85 },
	bills         = { carry = 0.5, floor = 0.85 },
	misty         = { carry = 0.5, floor = 0.85 },
	vermilion     = { carry = 0.5, floor = 0.85 },
	trash         = { carry = 0.3, floor = 0.80 },  -- high variance trashcans
	safari_carbos = { carry = 0.5, floor = 0.85 },
	victory_road  = { carry = 0.6, floor = 0.90 },  -- late game
	e4center      = { carry = 0.6, floor = 0.90 },
	blue          = { carry = 0.7, floor = 0.90 },
	champion      = { carry = 0.7, floor = 0.90 },
}

-- Area name -> timeRequirements key mapping (for checkpoint reset tracking)
Constants.AREA_TO_CHECKPOINT = {
	["Pallet Rival"]    = "bulbasaur",
	["Nidoran grass"]   = "nidoran",
	["Tree Potion"]     = "old_man",
	["Viridian Forest"] = "forest",
	["Brock's Gym"]     = "brock",
	["Pewter City"]     = "shorts",
	["Mt. Moon"]        = "mt_moon",
	["Cerulean"]        = "mankey",
	["Cerulean Rival"]  = "bills",
	["Misty's Gym"]     = "misty",
	["Vermilion City"]  = "vermilion",
	["Surge's Gym"]     = "trash",
	["Safari Zone"]     = "safari_carbos",
	["Victory Road"]    = "victory_road",
	["Elite Four"]      = "e4center",
	["Blue"]            = "blue",
	["Champion"]        = "champion",
}

-- Analytics-driven threshold tuning
Constants.THRESHOLD_TARGET_RESET_RATE = 0.25  -- ideal time-reset rate per checkpoint
Constants.THRESHOLD_MAX_ADJUSTMENT = 0.10     -- max +/- 10% from base
Constants.THRESHOLD_MIN_SAMPLES = 5           -- min time-resets before adjusting

-- Analytics
Constants.ANALYTICS_SUMMARY_INTERVAL = 50
Constants.ANALYTICS_MIN_RUNS_FOR_STRATEGY_DISPLAY = 10
Constants.ANALYTICS_MIN_STRATEGY_ATTEMPTS = 3
Constants.PB_SPLITS_FILENAME = "pb_splits.txt"

-- Overlay
Constants.OVERLAY_LINE_HEIGHT = 10

return Constants
