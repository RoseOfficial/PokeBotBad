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

-- Analytics
Constants.ANALYTICS_SUMMARY_INTERVAL = 50

return Constants
