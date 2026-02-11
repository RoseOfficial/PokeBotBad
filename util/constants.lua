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
Constants.BRIDGE_RETRY_DELAY = 1         -- seconds
Constants.BRIDGE_TIMEOUT = 0.050         -- seconds (socket timeout)

return Constants
