# Route Optimization Plan — WR Analysis

Comparison of the bot's current Red Any% Glitchless route against the community WR route (1:44:03 by pokeguy). Bot's PB: 1:49:25. Target: sub-1:47.

Sources:
- https://github.com/pokemon-speedrunning/speedrun-routes/tree/main/docs/gen-1/red-blue/main-glitchless
- https://speedruns.dozuki.com/Guide/Pokemon+Red-Blue+Any%25+Glitchless+-+Nidoran+Route/21

---

## Priority 1: Easy Wins (~2:00-2:30 savings)

### Battle Style SET
- WR switches to SET mode so the "Will you switch Pokemon?" prompt never appears
- Saves ~1-2 seconds per trainer knockout, ~1:00-1:30 over a full run
- **Where to change**: `util/settings.lua` — add a step during game setup to change Battle Style from SHIFT to SET
- Settings are at memory address 0x1354 (bitmask-based for Yellow, direct for Red)
- Verify the correct bit/address for Battle Style in Red

### Poke Doll Ghost Skip
- WR buys 1 Poke Doll at Celadon Dept Store (4F) and uses it on the Marowak ghost in Pokemon Tower
- Completely skips the ghost fight (~30-60 seconds)
- Allowed in Glitchless (banned only in Classic category)
- **Where to change**:
  - `ai/red/strategies.lua` — add Poke Doll to Celadon shop list
  - Add a strategy step to use Poke Doll when encountering the ghost
  - `storage/inventory.lua` — verify Poke Doll item ID exists

### Shop Optimization — More Repels
- WR buys significantly more Repels:
  - Vermilion: 6 Repels (bot buys 3)
  - Celadon: 10 Super Repels (bot buys fewer)
- More encounter avoidance = fewer random battles in late game
- **Where to change**: shop strategy functions in `ai/red/strategies.lua` (shopRepels, shopBuffs, etc.)

---

## Priority 2: Moderate Changes (~1:00-2:00 savings)

### Rock Slide for Channelers
- WR teaches Rock Slide (TM48, traded from Soda Pop on Celadon roof) in slot 2
- Used against Channelers in Pokemon Tower: 2HKOs Gastly/Haunter cleanly
- Avoids Thrash Confusion risk against ghosts
- **Where to change**:
  - Add Soda Pop purchase + trade to Celadon strategy
  - Teach TM48 Rock Slide during Fly menu (before Lavender)
  - Update combat logic to prefer Rock Slide vs Ghost types in tower
  - `ai/combat.lua` — may need move priority adjustment

### Agatha Strategy — EQ+Blizzard instead of Thrash
- WR uses: X Special + EQ on Gengar, Blizzard on Golbat, EQ x3 on rest
- No Confusion risk (Thrash causes Confusion after 3-4 turns)
- Requires Blizzard TM (taught before Blaine in WR route)
- **Where to change**:
  - Verify Blizzard is taught in current bot route
  - `ai/red/strategies.lua` — rewrite Agatha fight strategy
  - Must reserve 1+ Blizzard PP for Golbat specifically
  - If Agatha's Gengar uses Hypnosis: use Poke Flute, then EQ

### X Item Rebalance
- WR buys: 11 X Accuracy, 6 X Speed, 3 X Special
- Bot buys: 10 X Accuracy, 4 X Speed, 4-5 X Special
- More X Speeds = more guaranteed first-turns in E4
- Fewer X Specials needed if using Horn Drill more
- **Where to change**: `ai/red/strategies.lua` — shopBuffs function, Celadon Dept Store

### Champion Strategy Refinement
- WR: X Special + X Acc + HD on Pidgeot, then HD x5 through rest
- Clean Horn Drill sweep with setup on turn 1
- Verify bot's current Champion strategy matches this pattern
- **Where to change**: `ai/red/strategies.lua` — champion fight function

---

## Priority 3: Harder Changes (diminishing returns)

### Instant Text Trick
- Talk to Celadon bike salesman without voucher, close final dialog with B
- Sets text speed to instant (faster than "Fast" setting)
- NOT permanent — disabled by opening menus or Yes/No prompts
- Would need careful sequencing of when to trigger/re-trigger
- **Difficulty**: High — requires understanding exactly when instant text breaks and re-triggering at optimal points
- **Savings**: ~30-60 seconds if maintained well

### RNG Manipulation
- WR hard resets + plays frame-perfectly to get specific Nidoran DVs
- Also manipulates Paras encounter and trash can puzzle (1 attempt)
- The bot resets hundreds of times instead — different optimization target
- **Difficulty**: Very high — would require frame-counting and input-perfect sequences
- **Savings**: ~1-2 minutes (fewer resets needed, trash cans solved instantly)
- **Note**: The bot's brute-force approach (reset until good DVs) is actually reasonable for an automated runner. RNG manip would reduce resets but the per-run time saving is mainly in trash cans.

### Mega Punch Early
- WR teaches Mega Punch (TM01) at Moon Stone menu for higher base power in mid-game
- Replaces Horn Attack in slot 1 temporarily
- **Where to change**: Moon Stone menu strategy, move teaching sequence

---

## Not Worth Changing

### Pokeball Count (Viridian)
- WR buys 3 (RNG manip guarantees catch). Bot needs more for random encounters.
- Bot's 8 Pokeballs is correct for non-manip play.

### Potion Count (Pewter)
- WR buys 8. Bot's count is fine — healing needs vary more without manip.

### Parlyz Heals
- WR buys 2-3 for Surge area. Low priority — Thrash usually sweeps before paralysis matters.

---

## WR Route — Full Shop List (for reference)

| Location | Items |
|----------|-------|
| Viridian Mart | 3 Poke Balls |
| Pewter Mart | 8 Potions |
| Vermilion Mart | Sell TM34 + Nugget; Buy 6 Repels, 2 Parlyz Heals |
| Celadon 2F | TM07 (Horn Drill), 10 Super Repels, 3 Super Potions |
| Celadon 4F | 1 Poke Doll |
| Celadon Roof | 1 Soda Pop (trade for Rock Slide TM), 1 Fresh Water |
| Celadon 5F | 11 X Accuracy, 6 X Speed, 3 X Special |

## WR Route — Move Slots (Nidoking final)

| Slot | Move | Taught When |
|------|------|-------------|
| 1 | Earthquake | Level-up (replaces Mega Punch) |
| 2 | Rock Slide → Horn Drill | TM48 pre-Lavender, then TM07 replaces it |
| 3 | Thunderbolt | TM24 post-Bike |
| 4 | Blizzard | TM14 at Cinnabar Mansion |

## WR Route — E4 Strategy (for reference)

| Battle | Setup | Moves |
|--------|-------|-------|
| **Rival (Victory Road)** | X Acc + X Speed | Blizz, TB/Blizz, HD, EQ x2, HD |
| **Lorelei** | Swap bird turn 1, swap back | X Acc, HD x5 |
| **Bruno** | Max Ether on HD first | X Acc, HD x5 |
| **Agatha** | Super Potion + Rare Candy | X Special + EQ, Blizz, EQ x3 |
| **Lance** | Heal to 127+ HP | X Special + TB, Blizz, X Speed + Blizz, TB, Blizz |
| **Champion** | — | X Special + X Acc + HD, HD x5 |

---

## Implementation Order

1. Battle Style SET (easiest, biggest single gain)
2. More Repels (shop list tweak)
3. Poke Doll ghost skip (new strategy step + shop item)
4. X item rebalance (shop list + verify E4 has enough)
5. Rock Slide for Channelers (move teaching + combat logic)
6. Agatha EQ+Blizzard rewrite (E4 strategy change)
7. Champion strategy verification
8. Tighten time requirements to match new route speed

## Files That Will Need Changes

- `ai/red/strategies.lua` — shop lists, E4 fights, new strategy steps
- `ai/strategies.lua` — shared strategy functions (settings, ghost fight)
- `ai/combat.lua` — move priority for Rock Slide vs ghosts, Agatha logic
- `util/settings.lua` — Battle Style SET during game setup
- `data/red/paths.lua` — any new movement paths (Celadon 4F for Poke Doll, roof for Soda Pop)
- `util/constants.lua` — new item IDs if needed (Poke Doll, Soda Pop, Fresh Water)
- `storage/inventory.lua` — verify item IDs for new shop items
