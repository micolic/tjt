# TODO List — TJT (Legion TD 2 + OCG Deck-Building + Permadeath)

> **Game Design:** A hybrid strategy game fusing Legion TD 2 wave defense with
> OCG deck-building and permadeath. Players build a predefined unit deck before
> the match, choose a King (with future aura effects), place static defenders,
> and survive progressive waves. Dead units stay dead — every loss is permanent.
> Inspired by *Legion TD 2* and card games, NOT autobattlers like TFT.

---

## Plan — Budući milestone-ovi (nakon core stabilizacije)

- [ ] Ekonomija — osnovni income, interest, workers/mythium (vezano za PvP).
- [x] Deck-building sistem — pre-match unit set selekcija (OCG stil).
- [ ] King selekcija — biranje tipa Kinga pre partije.
- [ ] King aura — pasivni efekti Kinga na defendere.
- [x] Unit upgrade paths — tiers 1-7, every current defender has an upgrade, with branch choices in the selected-unit info panel.
- [ ] PvP slanje unita — iz ličnog deck-a, bez posebnog barracks-a.
- [ ] Multiplayer — 1v1, 2v2, 3v3, 4v4, coop (server authoritative).
- [ ] Map / lane dizajn — više arena layout-a.
- [ ] Graveyard meni — dropdown meni sa info o svim fallen unitima (slično graveyard-u u Yu-Gi-Oh igri).

---

## ✅ Completed Systems

### Core Game Loop ✅
- [x] Build phase → Battle phase → Reward → Repeat
- [x] BattleManager with 3 states (PREPARATION / BATTLE / ENDED)
- [x] Main Menu → Arena → Victory / Game Over screens
- [x] Start Battle button (also skips prep timer between waves)

### Wave System ✅
- [x] WaveManager with 15 configurable waves + 3 boss waves
- [x] WaveConfig resources with EnemyGroup composition
- [x] Progressive difficulty scaling (+5% per wave)
- [x] 30-second prep timer between waves (skippable)
- [x] Ally positions saved before battle, restored after
- [x] Full stat reset (HP, mana, cooldowns, AI state) between rounds
- [x] Gold + XP rewards per wave completion
- [x] Victory when all waves cleared / Game Over when all allies die
- [x] Streaming enemy spawn (one-by-one, each starts walking immediately)
- [x] Enemies spawn off-grid at random X near center, free-moving from start
- [x] WaveEnemyGroup props: enemy_type, count, spawn_interval_within_group
- [x] Win condition delegates to WaveManager (remaining_enemies counter)

### Unit Placement ✅
- [x] Bottom panel with unit cards (name, sprite, stats, gold cost)
- [x] Click card → click tile to place (ghost sprite preview)
- [x] Ghost tints green (free) / red (occupied)
- [x] Gold cost displayed on cards, affordability check + dimming
- [x] Gold deducted on placement, auto-cancel if can't afford more
- [x] Max deployed units limit (8)
- [x] ~~Sell portal~~ (removed — gold refund via right-click instead)

### Ability System ✅
- [x] Base Ability resource with targeting, cooldown, range
- [x] PassiveAbility for permanent stat bonuses
- [x] Fireball — single target, 100 dmg, 200 range, projectile
- [x] Mending Bolt — heal lowest ally 60 HP, or damage enemy 50 if all full
- [x] Heal — self heal 30 HP
- [x] Arcane Explosion — AoE 25 dmg to all enemies
- [x] Warrior's Endurance — passive +20% health regen
- [x] Mana system (gain per attack, cast when full)

### King System ✅
- [x] King unit auto-spawns at bottom-center of GameArea on arena load
- [x] King death = instant Game Over ("The King has fallen!")
- [x] Enemies walk toward King position (dummy target tracks King)
- [x] King unsellable (sell portal guard) & unremovable (right-click guard)
- [x] King does NOT count against max deployed units limit
- [x] Larger visual scale (1.5×) via visual_scale property on UnitStats
- [x] is_king flag on UnitStats for identification
- [x] King stats: 2500 HP, 40 ATK, 0.5 AS, 8 Armor, 25 MR, Legendary rarity, 0 cost

### Combat AI ✅
- [x] Aggro-range based target finding
- [x] A* pathfinding on unit grid
- [x] Threat tracking (incoming_damage / incoming_healing)
- [x] Anti-overkill: prefer targets with effective HP > 0
- [x] Anti-overheal: prefer allies with effective missing HP > 0
- [x] Separation force to prevent unit stacking (anchored units resist push)
- [x] Enemy dummy target (walk toward King when no target)
- [x] Pre-move intercept (switch to enemy in attack range before walking)
- [x] Diagnostic logging with emoji markers ([AI] prefix)
- [x] Avoidance steering (steer around same-team units, hard-obstacle for fighting allies)
- [x] Stuck detection (switch to alternate target after 1.5s no progress)
- [x] Path blocker detection (enemies attack blocking ally instead of walking through)
- [x] Ally idle detection logging (⚠ IDLE warns when allies ignore combat)

### Visual Feedback ✅
- [x] Damage numbers (float up + fade, scaled by damage)
- [x] Fireball projectile (smooth flight, hit detection, color)
- [x] Health bars + mana bars on all units
- [x] Unit skin flash on hit
- [x] Wave display UI (wave counter, enemy count, progress bar, timer)
- [x] Unit stats panel (live HP/mana for each ally)
- [x] VFX system — VFXSpawner component with spritesheet-based animated effects
- [x] Fireball explosion VFX (explosion_fire on projectile hit)
- [x] AOE ability VFX (explosion_magic on caster + targets)
- [x] Heal VFX (explosion_heal on healed ally)
- [x] Harm VFX (explosion_dark on damaged enemy)
- [x] Death VFX (death_effect on unit death)
- [x] Physical hit VFX (hit_physical on melee attack)
- [x] Animated enemy sprites (Crab, Jumper, Octopus with SpriteFrames)

### Unit Upgrade System (Legion TD style) ✅ (foundation)
- [x] `UnitStats.upgrades: Array[UnitStats]` — base unit lists its upgrade options
- [x] Upgraded unit's `gold_cost` = total value; upgrade price = difference (full refund on sell)
- [x] `UnitStats.unit_line` — base + upgrade count as ONE unique unit for synergies
- [x] Select a placed ally and choose an upgrade button during prep (position and selection preserved, toast + VFX)
- [x] `PassiveAbility.DAMAGE_REDUCTION` implemented — flat per-hit reduction (deterministic, min 1 dmg)
- [x] **Sentinel → Vanguard** (1770 HP / 186 ATK / 1.0 AS / 15 AR / 20 MR, cost 5 → 10) with *Iron Skin* (-6 dmg per hit)
- [x] Upgrade info shown in card tooltip and unit stats panel tooltip
- [x] Upgrade paths for all units (Grunt, Scout, Acolyte, Cleric, Sentinel, Slayer, Shaman) — see `UNIT_BLUEPRINTS.md` §4
- [x] Branching upgrades: Grunt chooses Bloodfang (+1 gold) or Ravager (+3 gold)
- [x] Selected-unit bottom panel shows live stats, abilities, and upgrade buttons instead of the U hotkey
- [x] Selected outline persists after hover exit and during combat; right-click / Escape deselects
- [x] Info and deck panels are mutually exclusive; opening the deck clears selection
- [x] Upgrades require preparation and sufficient gold; a failed replacement restores the original unit and payment
- [x] Bloodrage data uses BERSERK with fractional bonuses; threshold, healing, wave reset, live UI, and AI attack interval regressions are covered
- [x] Native Godot regression scene: `tests/arena_selection_test.tscn` (includes actual viewport picking and GUI upgrade clicks)

### Tier & Ability Framework ✅ (foundation) — see `UNIT_BLUEPRINTS.md`
- [x] Tiers 1-7 on UnitStats; roster assigned T1-T5
- [x] Deterministic passive framework via `CombatResolver` (no RNG — Pillar 6)
- [ ] StatusEffect component (stun / AS slow / move slow / DoT) → unlocks Storm Bolt, Tremor, Envenom, Cripple
- [ ] AuraManager (Leadership, Healing Aura, Reassurance, Telescope, Sickness, Blood Thirst)
- [ ] Second passive slot (`passive_abilities: Array`)
- [ ] Temporary summons (Raise Dead, Invoke Inferno, Mitosis)
- [ ] On-death triggers (Tree of Life / Knowledge)
- [ ] T6 units (Moon Guard, Minotaur, Sea Giant, Dragon Hawk, Yggdrasil, Lord of Death)
- [ ] T7 Champions (Thrall, Fenix, Doomsday Machine, Messiah, Goliath) — one per deck rule

### Deck Manager System ✅
- [x] DeckManager autoload singleton for persistent deck storage
- [x] Deck Selection scene — choose 7 units from all available ally units
- [x] Save & Load deck to/from user://deck.cfg (ConfigFile)
- [x] Default deck if no saved data exists
- [x] Right-click to deselect unit from deck
- [x] Explicit Save button (manual saving)
- [x] Main Menu: "Play" loads Arena with saved deck, "Deck Manager" opens DeckSelection
- [x] Arena reads deck from DeckManager instead of hardcoded list
- [x] Spacebar toggles unit selection panel in Arena

### Procedural Animation System ✅
- [x] UnitAnimator component with 4 states: IDLE, WALK, ATTACK, DEATH
- [x] Idle bob animation (1.5px, 1.5Hz sine wave)
- [x] Walk bob + tilt animation (2.5px, 4Hz, 5° lean)
- [x] Attack squash + lunge animation (0.15s, scale squash + forward lunge)
- [x] Death jump + spin + fade animation (0.4s)
- [x] AnimatedSprite2D support (auto-plays named animations when sprite_frames set)
- [x] Wired into unit_ai.gd (walk on move, attack on strike, idle on cooldown/no target)
- [x] Death animation plays before unit removal
- [x] Idle animation runs during PREPARATION phase

### Camera & QoL ✅
- [x] Camera2D with mouse scroll zoom (0.5×–2.0×, 0.1 step)
- [x] Middle-click camera pan (drag to move camera, zoom-scaled)
- [x] Shift+click multi-place (hold Shift to keep placing same unit type)
- [x] Drag card to grid placement (drag from card, release on tile to place)
- [x] Click outside panel closes it (left-click on arena hides unit selection panel)

### Bug Fixes Applied ✅
- [x] Lambda capture freed errors (WeakRef pattern)
- [x] AI spam during PREPARATION (battle state guard)
- [x] remaining_enemies going to -1 (double-decrement guard)
- [x] Freed object cast in UnitGrid.remove_unit (is_instance_valid guard)
- [x] handle_unit_death validity check
- [x] BattleManager type casting issues
- [x] Mana regeneration system (battle state check)
- [x] Enemy separation pushing fighters off targets (anchoring fix)
- [x] check_win_condition false positive with grid-free enemies (WaveManager delegation)
- [x] Wave completing instantly when enemies spawn off-grid (remaining_enemies counter)
- [x] Attack tween squash bug — interrupted attack left units squashed (scale + position reset in _kill_attack_tween)
- [x] King shrinking after first battle — _base_scale captured before visual_scale applied (re-capture after set_stats)
- [x] Idle animation float precision — _idle_time wrapped with fmod to prevent drift over long sessions
- [x] Attack→idle transition — _idle_time now resets when returning to idle from attack tween
- [x] Game Over bug — King with 0 HP was incorrectly detected as alive (explicit current_health > 0 check)
- [x] Duplicate permadeath toast — _is_dead guard prevents multiple health_reached_zero emissions
- [x] EnemyUnit.apply_damage null-pointer — else branch accessing stats when null (early return guard)
- [x] handle_unit_death wrong tile — now finds tile by iterating grid.units instead of global_position
- [x] Dual HP system — EnemyUnit now has current_health/current_mana properties synced with stats
- [x] Dead units attacking — AI disabled on death (ai.enabled = false in _on_health_reached_zero)
- [x] VFX "default" animation error — SpriteFrames.new() already has "default", now removed before adding
- [x] AnimatedSprite2D playing empty "default" animation — now plays "idle" if available
- [x] Placement ghost null texture — push_warning + early return if no spritesheet for team
- [x] z_index override on hover — UnitAI no longer sets z_index when unit is hovered

---

## ⚡ Legion TD 2 Core Systems — Missing

> These are the mechanics that define the Legion TD genre. Without them the game is
> a basic tower defense; with them it becomes a strategic economy game.

### 1. King Lives / Leak Mechanic ✅
- [x] King HP never resets between waves — permanent damage from leaks
- [x] King health_regen = 0 (no self-healing)
- [x] Game Over only when King HP reaches 0 (King fights alone if all allies die)
- [x] King HP bar visible in HUD at all times
- [x] Leak mechanic — enemies reaching King deal leak damage (= attack_damage) and despawn

### 4. Faction / Synergy System ✅
- [x] Units belong to factions: Warrior (Sentinel, Grunt, Slayer), Mystic (Acolyte, Shaman), Warden (Scout, Cleric)
- [x] Placing 3+ Warriors → +20% ATK damage; 3+ Mystics → +20% AP; 2+ Wardens → +15% ATK speed
- [x] SynergyManager component tracks placed units, applies/removes stat bonuses live
- [x] SynergyPanel HUD shows active/pending synergies (dots ●●○ style)
- [x] Faction field added to UnitStats; all ally .tres files updated
- [ ] Faction icon shown on unit cards in UnitSelectionPanel

### 5. Wave Preview / Info System ✅
- [x] After each wave completes, prep-phase shows next wave's enemy composition
- [x] Format: "Next: 3× Orc, 2× Troll" via NextWaveLabel in WaveDisplay
- [x] WaveManager.get_next_wave_config() added
- [ ] Enemy icons with HP/ATK/count displayed (currently text-only)

### 6. Income & Gold HUD 🟢 (MEDIUM)
- [ ] Gold always visible in HUD (not just on unit selection panel)
- [ ] Income breakdown tooltip: base + workers + interest = total next wave
- [ ] Mythium always visible next to gold
- [ ] King HP / Lives always visible in HUD

---

## 🔥 High Priority — Next Up

- [x] ~~IMPORTANT: Fix aggro, AI movement, pathfinding, and targeting~~ (anchoring, avoidance steering, stuck detection, blocker detection)
- [ ] Enemy target switching still needs tuning (debug logs added)
- [ ] Ally back-row engagement (Y aggro multiplier increased 1.0→2.0, needs testing)

### More Defender Units ✅
- [x] 7 ally unit types (one per tier 1-7) + King
- [x] **Tank line:** Grunt (Bloodrage), Sentinel (Fortitude, upgrades to Vanguard)
- [x] **DPS line:** Acolyte (Ember Bolt + Arcane Bolt), Scout (Piercing Shot + Eagle Eye), Slayer (Executioner's Strike)
- [x] **Support line:** Cleric (Divine Light), Shaman (Nature's Fury, T7 Champion)
- [x] Each unit has: .tres stats, unique ability/passive, balanced gold cost, upgrade path

### More Enemy Types ✅
- [x] Need 5–8 enemy types for wave variety (now 9: Orc, Necro, Goblin, Wolf, Troll, Skeleton Archer, Crab, Jumper, Octopus)
- [x] **Fast:** Goblin — low HP (50), high attack speed (1.2), swarms
- [x] **Fast Flanker:** Wolf — low HP (60), high aggro range (9), flanks backline
- [x] **Tank:** Troll — high HP (250), slow (0.4 AS), heavy armor (15)
- [x] **Ranged DPS:** Skeleton Archer — ranged (3), medium HP (70), high aggro (8)
- [x] **Armored Melee:** Crab — HP 120, armor 8, animated sprite (warped-files)
- [x] **Fast Assassin:** Jumper — HP 60, ATK 18, speed 1.5, animated sprite
- [x] **Magic Ranged:** Octopus — HP 80, range 3, MR 30, large unit, animated sprite
- [ ] **Healer:** Shaman — heals other enemies
- [ ] **Boss:** Dragon / Demon Lord — very high HP, special ability, appears on boss waves

### More Waves & Difficulty Curve ✅
- [x] Expand from 4 to 15 waves for a full game
- [x] Increasing enemy variety as waves progress (new types introduced gradually)
- [x] Boss every 5th wave (Wave 5: Troll Assault, Wave 10: The Warhost, Wave 15: The Last Stand)
- [ ] Wave generator improvements (random composition per run?)
- [ ] Wave preview (show what's coming before build phase)
- [ ] Income system between waves (base gold + interest on saved gold?)

### Lane / Positioning System (Legion TD Core)
- [x] Enemies walk toward King (replaces traditional lives system)
- [x] King death = Game Over (no lives counter needed)
- [x] Enemies stream in from top of lane, walk toward King
- [ ] Player units are static defenders (no movement during battle)
- [ ] Multiple lanes? (future — multiplayer prep)

### Multi-Tile Units & Unit Stacking
- [ ] Some units occupy 2, 4, or 8 tiles (large enemies like Octopus, bosses)
- [ ] Area2D collision shape scales with unit size (unit_size: Vector2i in UnitStats)
- [ ] Grid placement logic: prevent overlapping large units, show occupied tiles
- [ ] Unit stacking on single tile: visual offset (front/back layering) for 2D perspective
- [ ] Z-index sorting: lower Y = further back = drawn behind (pseudo-depth)
- [ ] Visual "row" stagger: units on same tile are offset vertically to show depth

---

## 🎯 Medium Priority

### Combat Improvements
- [x] Target stickiness (units commit to current target while alive + in range)
- [x] Target switch delay (0.8s lock prevents erratic switching)
- [x] Ability target filtering — dead/freed units filtered from get_valid_targets
- [ ] Tank aggro system (enemies prefer attacking nearest/taunting unit)
- [ ] Attack priority options (closest, lowest HP, highest threat)
- [ ] Critical hit system
- [ ] Status effects (slow, stun, poison, burn)
- [ ] Armor/Magic Resist damage reduction formulas + tooltips
- [ ] AoE/splash damage for certain units
- [ ] Lifesteal mechanic

### Gold & Economy
- [ ] ~~Income per wave (base + interest on banked gold, like Legion TD)~~ → see Legion TD 2 Core Systems above
- [ ] Gold display always visible in HUD → see HUD section above
- [ ] Unit sell value decay (sell for less than buy price?)
- [ ] Balance gold costs vs wave rewards curve

### Build Phase UX
- [x] Right-click / Escape clears selection or cancels placement / drag, without selling
- [x] Quick sell hotkey (E key removes hovered unit during prep phase and refunds the full invested gold)
- [x] Drag placed units to reposition during build phase; an 8-pixel threshold keeps ordinary clicks from moving them
- [ ] Unit tooltip on hover (full stats, ability description)
- [ ] Undo last placement button
- [ ] Quick-buy hotkeys (1-9 for unit types)
- [ ] Show ability info on selection card

### Wave / Battle UX
- [ ] Wave preview panel (show enemy types + count before battle starts)
- [ ] Speed up / fast forward button during battle
- [ ] Auto-start next wave option
- [ ] Battle replay / combat log

---

## 📦 Low Priority / Nice to Have

### Visual Polish
- [x] Unit death animations (fade out, particles) — procedural death (jump+spin+fade)
- [x] VFX system — VFXSpawner component with spritesheet-based animated effects
- [x] Fireball explosion VFX (explosion_fire on projectile hit)
- [x] AOE ability VFX (explosion_magic on caster + targets)
- [x] Heal VFX (explosion_heal on healed ally)
- [x] Death VFX (death_effect on unit death)
- [x] Physical hit VFX (hit_physical on melee attack)
- [x] Animated enemy sprites (Crab, Jumper, Octopus with SpriteFrames)
- [ ] Melee hit effects (slash sprite)
- [x] Ability cast animations — attack squash+lunge procedural
- [ ] Screen shake on boss spawn / big hits
- [x] Attack animations (sprite flipping/bobbing) — procedural walk bob+tilt, attack squash+lunge
- [ ] Particle effects for status effects
- [ ] Better backgrounds / arena tilemap art

### Audio
- [ ] Battle music
- [ ] Attack sound effects per unit type
- [ ] Ability cast sounds
- [ ] Gold spend / earn sound
- [ ] Victory / defeat jingles
- [ ] UI click sounds
- [ ] Volume controls

### Meta / Progression
- [ ] High score tracking (waves survived, gold earned)
- [ ] Save/Load system
- [ ] Player statistics
- [ ] Unlockable units / skins
- [ ] Different arena maps / layouts
- [ ] Daily challenges

### Performance
- [x] Object pooling for projectiles
- [x] Optimize AI search frequency (cached BattleManager refs)
- [x] Loading screen with tips (threaded scene loading)
- [x] Y-sort z-index for unit depth ordering
- [x] Rectangular aggro range (allies only — wider X, narrower Y)

---

## 🐛 Known Issues / Tech Debt
- [ ] `[WAVE] WARNING: Could not find PlayerStats node!` on startup (harmless, timing issue)
- [x] ~~`[dummy] → [dummy]` target change spam~~ (dummy target reused instead of recreated)
- [x] ~~`[Ability] No valid targets` fireball spam~~ (moved to verbose logging)
- [ ] `target changed [unit] → [unit]` log noise (same-name different instances)
- [ ] Audit Executioner's Strike data: it currently serializes DAMAGE_BONUS (`passive_type = 2`, `value = 4.0`) instead of the documented every-fourth-hit multiplier. Bloodrage's separate resource mismatch is fixed.
- [ ] Investigate headless shutdown diagnostics: two ObjectDB instances and the UnitStats script resource remain in use. Reproduced in Main Menu and Arena launches as well as the regression scene; regression assertions pass.
- [ ] `[Ability] [unit] ability ready!` × 5 spam when multiple units ready simultaneously
- [ ] ~~Fix sage_ally.tres UID warning~~ (Sage removed from roster)
- [ ] Consistent naming conventions (snake_case vs PascalCase)
- [x] Warrior's Endurance passive stacking on each unit placement — FIXED (guard flag + stats order)
- [ ] **Unit/EnemyUnit code duplication** — set_stats, _swap_to_animated_sprite, _on_health_reached_zero, _connect_stats_signals, apply_damage are duplicated. Future refactor: introduce UnitBase class or shared component.

---

## 📊 Current Content

### Ally Units (7 + King) — one per tier 1-7, original names inspired by Legion TD (see `UNIT_BLUEPRINTS.md`)
| Unit | Tier | HP | ATK | AS | Range | Cost | Active | Passive |
|------|------|----|-----|------|-------|------|--------|---------|
| Grunt (Warrior) | 1 | 100 | 10 | 1.0 | 1 (melee) | 1💰 | — | Bloodrage (+20/40/60% AS below 60/40/20% HP) |
| ↳ Bloodfang (upgrade) | 1 | 500 | 50 | 1.0 | 1 (melee) | 2💰 (1+1) | — | Bloodrage |
| ↳ Ravager (upgrade) | 1 | 1050 | 60 | 0.6 | 1 (melee) | 4💰 (1+3) | — | Greater Bloodrage (+30/60/90% AS below 60/40/20% HP) |
| Scout (Warden) | 2 | 110 | 17 | 0.9 | 4 (ranged) | 2💰 | Piercing Shot (120 dmg) | Eagle Eye (every 3rd shot ×1.6) |
| ↳ Hawkeye (upgrade) | 2 | 335 | 42 | 0.9 | 4 (ranged) | 4💰 (2+2) | Piercing Shot | Eagle Eye |
| Acolyte (Mystic) | 3 | 350 | 20 | 1.0 | 3 (ranged) | 3💰 | Ember Bolt (100 dmg) | Arcane Bolt (+15 magical per attack) |
| ↳ Arcanist (upgrade) | 3 | 850 | 52 | 0.8 | 3 (ranged) | 6💰 (3+3) | Ember Bolt | Arcane Bolt |
| Cleric (Warden) | 4 | 420 | 58 | 1.0 | 3 (ranged) | 4💰 | Divine Light (50 HP to 4 most wounded) | — |
| ↳ Hierophant (upgrade) | 4 | 840 | 127 | 1.0 | 3 (ranged) | 8💰 (4+4) | Divine Light | — |
| Sentinel (Warrior) | 5 | 880 | 75 | 0.9 | 1 (melee) | 5💰 | — | Fortitude (+5 armor) |
| ↳ Vanguard (upgrade) | 5 | 1770 | 186 | 1.0 | 1 (melee) | 10💰 (5+5) | — | Iron Skin (-6 dmg per hit, min 1) |
| Slayer (Warrior) | 6 | 1035 | 128 | 1.3 | 1 (melee) | 7💰 | — | Executioner's Strike (every 4th hit ×2) |
| ↳ Juggernaut (upgrade) | 6 | 2200 | 160 | 0.9 | 1 (melee) | 14💰 (7+7) | — | Executioner's Strike |
| Shaman (Mystic) | 7 | 1800 | 120 | 1.0 | 3 (ranged) | 10💰 | Nature's Fury (100 magical, bounces 5×, -25%) | — |
| ↳ Avatar (upgrade) | 7 | 2500 | 180 | 0.8 | 3 (ranged) | 20💰 (10+10) | Nature's Fury | — |
| **King** 👑 | — | **2500** | 80 | 0.7 | 1 (melee) | — | *(none yet — auras/abilities TBD)* | — |

### Enemy Units (9)
| Unit | HP | ATK | AS | Armor | MR | Range | Role |
|------|----|-----|------|-------|-----|-------|------|
| Orc | 100 | 10 | 0.7 | 5 | 20 | 1 (melee) | Standard warrior |
| Necro | 60 | 10 | 0.8 | 2 | 30 | 3 (ranged) | Ranged caster |
| Goblin | 50 | 8 | 1.2 | 2 | 10 | 1 (melee) | Fast swarm |
| Wolf | 60 | 12 | 1.0 | 0 | 5 | 1 (melee) | Fast flanker |
| Troll | 250 | 15 | 0.4 | 15 | 10 | 1 (melee) | Heavy tank |
| Skeleton Archer | 70 | 15 | 0.9 | 3 | 5 | 3 (ranged) | Ranged DPS |
| Crab | 120 | 12 | 1.0 | 8 | 10 | 1 (melee) | Armored melee (animated) |
| Jumper | 60 | 18 | 1.5 | 2 | 15 | 1 (melee) | Fast assassin (animated) |
| Octopus | 80 | 14 | 0.8 | 4 | 30 | 3 (ranged) | Magic ranged, large (animated) |

### Waves (15)
| Wave | Name | Enemies | Reward |
|------|------|---------|--------|
| 1 | First Blood | 6× Goblin | 30💰, 5 XP |
| 2 | Orc Warband | 6× Orc | 50💰, 10 XP |
| 3 | Wolf Pack | 4× Wolf + 6× Goblin + 4× Crab | 60💰, 15 XP |
| 4 | Bone Rain | 3× Skeleton Archer + 4× Orc + 5× Jumper + 3× Octopus | 70💰, 20 XP |
| **5** | **BOSS: Troll Assault 👑** | **2× Troll + 8× Orc** | **120💰, 35 XP** |
| 6 | Dark Magic | 4× Necro + 6× Goblin | 80💰, 25 XP |
| 7 | Feral Onslaught | 8× Wolf + 3× Skeleton Archer | 90💰, 30 XP |
| 8 | Siege Line | 6× Orc + 2× Troll + 4× Necro | 100💰, 35 XP |
| 9 | Arrow Storm | 5× Skeleton Archer + 8× Wolf | 110💰, 40 XP |
| **10** | **BOSS: The Warhost 👑** | **4× Troll + 6× Necro + 8× Orc** | **200💰, 60 XP** |
| 11 | Goblin Horde | 10× Goblin + 5× Skeleton Archer | 130💰, 45 XP |
| 12 | Undead Legion | 6× Necro + 4× Orc + 2× Troll | 140💰, 50 XP |
| 13 | The Wild Hunt | 8× Wolf + 4× Troll + 3× Skeleton Archer | 160💰, 55 XP |
| 14 | Total War | 8× Orc + 6× Necro + 4× Wolf + 4× Troll | 180💰, 65 XP |
| **15** | **FINAL: The Last Stand 👑** | **4× Troll + 5× Skeleton Archer + 10× Goblin + 6× Necro** | **500💰, 100 XP** |

---

## Session Log

### September 2026 (Session 11) — Fine-Grained Placement Grid + Tile-Size Units
- ✅ Logical placement grid reduced 32 px → 8 px cells (`PlayArea.GRID_CELL_PX`); visual tilemap unchanged
- ✅ `UnitStats.footprint` (Vector2i, default 4x4 = 32 px) — future support for smaller (2x2) and larger (8x8+) units
- ✅ `UnitStats.tile_size` (Vector2i in pixels, default 32x32) — spritesheet slicing and placement use this size
- ✅ Unit origin is the **footprint center**; Sprite2D/collision are centered so the unit is visually centered in the tile
- ✅ `UnitGrid` rework: multi-cell occupancy, `unit_anchors` map, `is_area_free`, `get_units_in_area`, `remove_unit_node`, `clear`
- ✅ Footprint-aware placement ghost, click-to-place, drag & drop (incl. swap when footprints fit), quick sell, upgrades
- ✅ Drop anchor computed from the unit's dragged position (lands where the player sees it)
- ✅ Grid sizes ×4: GameArea 120×48, EnemyArea 120×16 logical cells
- ✅ TileHighlighter converts logical (8 px) tiles to visual (32 px) tiles
- ✅ All 665 arena test checks pass

### September 2026 (Session 10) — Tier Rework & Legion TD Ability Catalog
- ✅ `UnitStats.tier` range 1-7 (`MAX_TIER`), all allies assigned tier / cost / rarity by Legion TD logic
- ✅ `PassiveAbility` combat framework: `modify_outgoing_damage`, `on_attack_hit`, `on_health_changed` hooks
- ✅ New passive types: NTH_ATTACK_MULTIPLIER, MAGIC_MISSILE, LIFESTEAL, ARMOR_SHRED, SPLASH, MULTISHOT, BERSERK (+ SPEED_BONUS implemented)
- ✅ `CombatResolver` — single entry for basic-attack hits (melee + basic arrows); abilities bypass it
- ✅ New actives: `ChainDamageAbility` (Nature's Fury), `ChainHealAbility` (Mending Wave); `max_targets` on AoE dmg/heal
- ✅ Roster rework: Grunt→Bloodrage, Scout+Eagle Eye, Acolyte+Arcane Bolt, Slayer→Executioner's Strike, Cleric Divine Light (4 targets), Shaman→Nature's Fury (T7)
- ✅ Data-only passives ready for blueprints: Life Steal, Corruption, Circle Splash, Burst Shot
- ✅ `UNIT_BLUEPRINTS.md` — tier system, ability catalog (implemented / data-only / needs engine), upgrade trees, T1-T7 unit blueprints, roadmap
- ✅ Tooltips show Tier, Ability, Passive

### September 2026 (Session 9) — Unit Upgrade System
- ✅ Upgrade data model on UnitStats (`upgrades`, `unit_line`, `has_upgrades()`, `get_upgrade_cost()`)
- ✅ Arena upgrade flow: U hotkey on hovered ally during prep, pays difference, respawns at same tile
- ✅ SynergyManager counts unique units by `unit_line` (Sentinel + Vanguard = 1 Warrior)
- ✅ `PassiveAbility.DAMAGE_REDUCTION` implemented and hooked into `Unit.apply_damage`
- ✅ First upgrade: Sentinel → Vanguard (Iron Skin), sprite (4,1) on rogues.png
- ✅ Stats panel rebuilds when a unit node is replaced in place
- ✅ New input action `upgrade_unit` (U) in project.godot

### August 2026 (Session 8) — VFX System, Animated Enemies, Review Fixes
- ✅ VFX system — VFXSpawner component with 8 VFX types (explosions, hit effects, death)
- ✅ VFX integrated into abilities (fireball, AOE, heal, harm) and combat (melee hit, death)
- ✅ VFX assets copied from Animation Pack, Bullet Impact 32x32, explosion pack 1
- ✅ 3 new animated enemy units: Crab, Jumper, Octopus (from warped-files assets)
- ✅ SpriteFrames generated for all 3 new enemies (idle + walk animations)
- ✅ UnitStats .tres files created for Crab, Jumper, Octopus with balanced stats
- ✅ Wave 3 and 4 updated to include new enemy types
- ✅ Deck Manager system — persistent deck storage, Deck Selection scene, Main Menu integration
- ✅ Arena reads deck from DeckManager instead of hardcoded list
- ✅ Spacebar toggles unit selection panel in Arena
- ✅ Game Over bug fix — King with 0 HP incorrectly detected as alive
- ✅ Duplicate permadeath toast fix — _is_dead guard on health_reached_zero
- ✅ Review fixes (10 items):
  - ✅ EnemyUnit.apply_damage null-pointer (critical)
  - ✅ handle_unit_death wrong tile (grid iteration instead of global_position)
  - ✅ Dual HP system unified (current_health property on EnemyUnit)
  - ✅ Leak mechanic implemented (enemies deal damage to King and despawn)
  - ✅ Stale comment removed from _spawn_king
  - ✅ Ability target filtering (dead units excluded)
  - ✅ Quick sell hotkey (E key) connected
  - ✅ Placement ghost null texture guard
  - ✅ z_index optimization (only update on position change, skip when hovered)
  - ✅ Unit/EnemyUnit code duplication noted for future refactor

### May 2026 (Session 7) — Legion TD 2 Core Systems
- ✅ TODO updated with full Legion TD 2 structural analysis
- ✅ King HP never resets between waves (permanent damage from leaks)
- ✅ King health_regen = 0 (no self-healing)
- ✅ Wave Preview: after each wave, prep-phase shows next wave composition ("Next: 3× Orc, 2× Troll")
- ✅ Faction Synergy system: Warrior/Mystic/Warden factions with stat bonuses
- ✅ SynergyManager component: tracks placed units, applies/removes bonuses live
- ✅ SynergyPanel HUD: shows active/pending synergies with ●●○ style indicators
- ✅ All ally .tres files updated with faction assignments

### April 2026 (Session 6) — Animation, Camera, QoL, Bug Fixes
- ✅ Procedural UnitAnimator system added (IDLE, WALK, ATTACK, DEATH)
- ✅ Idle bob, walk bob+tilt, attack squash+lunge, death jump+spin+fade
- ✅ AnimatedSprite2D support prepared for future sprite sheet animations
- ✅ Camera2D added with mouse-wheel zoom and middle-click pan
- ✅ Shift+click multi-place and drag-card-to-grid placement implemented
- ✅ Click outside unit panel closes it
- ✅ Fixed King size shrink bug after first battle (base scale recaptured)
- ✅ Added idle animation stability fix for long sessions
- ✅ Added attack→idle transition reset so idle phase restarts cleanly

### February 2026 (Session 5) — King Unit, Arena Expansion
- ✅ **King unit** — core game mechanic: death = Game Over
- ✅ King auto-spawns at bottom-center of GameArea on arena load
- ✅ Enemies walk toward King position (dummy target tracks King)
- ✅ King unsellable & unremovable (sell portal + right-click guards)
- ✅ King visual_scale 1.5× (applied to $Visuals node, survives wave resets)
- ✅ is_king flag + visual_scale property added to UnitStats
- ✅ Arena expansion: Background 30×17, GameArea 18×12, EnemyArea 18×4
- ✅ max_deployed_units 5→8
- ✅ AOEDamageAbility fix on EnemyUnit (use apply_damage instead of current_health)
- ✅ AoEHealAbility narrowing conversion fix (explicit int() casts)

### February 2026 (Session 4) — New Units, Resolution, Animation Prep
- ✅ Resolution increase: 640×360 → 960×540 viewport, 1920×1080 window
- ✅ 5 new ally units: Sentinel, Scout, Slayer, Cleric, Shaman (originally Knight, Ranger, Rogue, Priest, Druid)
- ✅ 5 new abilities: Fortitude, Piercing Shot, Executioner's Strike, Divine Light, Nature's Fury
- ✅ AoEHealAbility class (area heal with green flash)
- ✅ AnimatedSprite2D preparation (sprite_frames property in UnitStats)
- ✅ Warrior's Endurance passive stacking fix (guard flag + stats order)
- ✅ Retaliation targeting (units fight back when attacked)
- ✅ Aggro range fixes (Grunt 3→5, Y multiplier 0.75→1.0)

### February 2026 (Session 3) — Gold, Overkill Fix, Polish
- ✅ Gold cost system: card display, affordability check, auto-deduct on placement
- ✅ Anti-overkill threat tracking (incoming_damage / incoming_healing)
- ✅ Fireball ability updated with threat-aware targeting
- ✅ AI log spam reduced (verbose mode toggle)
- ✅ Freed object cast fix in UnitGrid.remove_unit
- ✅ handle_unit_death validity guard

### February 2026 (Session 2) — Menus, Unit Selection, Waves
- ✅ Main Menu, Victory Screen, Game Over Screen
- ✅ Unit selection panel with click-to-place + ghost sprite
- ✅ Wave system: 4 waves, prep timer, position save/restore, stat reset
- ✅ Early healer unit with Mending Bolt (heal/harm dual mode) — later removed (Sage), support now covered by Cleric + Shaman
- ✅ HealOrHarmAbility class
- ✅ Lambda capture fixes (WeakRef pattern)
- ✅ UI: Arial system font, compact panels, wave display
- ✅ Fixed AI spam, remaining_enemies going negative

### November 2025 (Session 1) — Foundation
- ✅ Damage number system
- ✅ Complete ability system (Fireball, Heal, AoE, Passive)
- ✅ Projectile system (smooth flight, hit detection)
- ✅ Float-based health/mana regeneration
- ✅ Bug fixes (mana regen, BattleManager casting, console spam)

---
*Last Updated: September 2026 (Session 10)*
