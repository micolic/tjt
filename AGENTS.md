# AGENTS.md — TJT Project Rules for AI Agents

> **Project:** TJT — Legion TD 2 + OCG Deck-Building + Permadeath
> **Engine:** Godot 4.7 (GL Compatibility renderer)
> **Language:** GDScript (typed)

## Project Identity

TJT is a hybrid strategy game fusing:
- **Legion TD 2** wave defense (static defenders, progressive waves, King defense)
- **OCG deck-building** (predefined unit set chosen before the match)
- **Permadeath** (units that die in a match stay dead — no revive between waves)

TJT is **NOT** a TFT-style auto-battler. No board swapping, no items, no shop reroll.

See `Game Design Document.md` for full design spec.

## Communication

- Chat in Serbian (Cyrillic or Latin)
- Documentation, code, and comments in English

## Code Style

- Typed GDScript (`var x: int = 0`, not `var x = 0`)
- Composition over inheritance
- Scene-based architecture
- Signal-driven systems
- Reusable components
- Production-ready code — no placeholders
- Maintainability over cleverness
- Explain tradeoffs in comments when non-obvious
- **Console logging**: every new component or feature should log key actions to console with a `[Tag]` prefix (e.g. `[DeckManager]`, `[WAVE]`, `[Battle]`). This makes debugging easier for both developer and AI agent. Log initialization, state changes, errors, and important events.

## Architecture

### Managers (singleton-like nodes in Arena scene)
- `BattleManager` — state machine: PREPARATION → BATTLE → ENDED
- `WaveManager` — wave progression, enemy spawning, between-wave flow
- `SynergyManager` — faction synergy tracking and bonuses

### Unit system
- `Unit` (player) and `EnemyUnit` (enemy) both extend `Area2D`
- Shared components: `UnitAI`, `UnitAnimator`, `UnitVisuals`
- Stats configured via `UnitStats` resource (.tres files)
- **Placement grid**: logical cells are 8 px (`PlayArea.GRID_CELL_PX`); the visual tilemap stays 32 px.
  Units occupy a footprint of cells (`UnitStats.footprint`, default 4x4 = 32 px), enabling smaller
  (2x2 = 16 px) and larger (8x8 = 64 px) units. `UnitGrid` tracks every occupied cell plus a
  unit→anchor map; use `is_area_free()` / `get_unit_anchor()` / `remove_unit_node()` for placement logic.
  **Unit origin is the footprint center** — the sprite is centered on the node so the unit is
  visually centered in its footprint (`PlayArea.get_unit_position()`).
- **Visual tile size**: `UnitStats.tile_size` (Vector2i in pixels, e.g. 32x32, 16x16). The
  spritesheet region and preview icons slice at this resolution; placement is centered on the footprint.
- **Ranges** (attack/aggro) are still measured in 32 px design cells (`CELL_SIZE`), independent of the placement grid.
- **Damage types**: `UnitStats.DamageType.PHYSICAL`, `MAGICAL`, `PURE`
- **Armor/MR**: percentage-based reduction (15 armor = 15% less physical damage), capped at 90%
- **Mana**: per-unit `mana_regen` (no mana per attack)
- **Tiers**: `UnitStats.tier` 1-7 (Legion TD style; upgrades keep base tier). Design reference: `UNIT_BLUEPRINTS.md`
- **Basic attacks** go through `CombatResolver.resolve_basic_attack()` — this is where `PassiveAbility` on-hit hooks fire. Ability damage calls `apply_damage` directly and must NOT trigger on-hit passives.
- **No RNG in combat**: chance-based effects from Legion TD are converted to deterministic counters (every Nth attack) or thresholds

### Key design rules
- **King HP = 0** is the only defeat condition. King fights alone if all other allies die.
- **Permadeath**: dead units are `queue_free()`-d and never revive between waves.
- **Leak**: enemies that reach the King fight him; King HP is permanent across waves.

## File Organization

```
scenes/      # Godot scenes (.tscn) and their scripts
components/  # Reusable GDScript components (managers, AI, helpers)
data/        # Resource files (.tres) and their scripts
  units/     # UnitStats resources
  abilities/ # Ability resources
  waves/     # WaveConfig and WaveEnemyGroup resources
asset/       # Sprites, tilesets, fonts, audio, shaders
```

## Verification

- Open project in Godot 4.7+ and run — main scene is Main Menu
- Check for parse errors in Output panel
- Test wave 1 (should be challenging: 10 goblins + 6 orcs + 5 skeleton archers)
- Verify: King death = game over, permadeath toasts appear, Victory/GameOver stats display
- Run selected-unit regression checks with Godot 4.7+: `godot --headless --path . res://tests/arena_selection_test.tscn` (use the installed Godot executable if it is not on PATH).
- Arena regression tests use a scene-based `Node` runner, not `--script`: the `DeckManager` autoload must be registered before Arena is compiled.

## Required Reading

Before working on any **unit** design, balance, or ability task, every agent **must** read:

- `reference/legion_td_mega_book.md` — full extracted text of the *Legion TD Mega Book (Overall Strategical Guide) 3.41* forum thread. This is the **primary and exclusive external reference for unit design** — tower stats, abilities, tiers, armor/damage types, upgrades, and balance. Use it to inform unit stats, abilities, and upgrade paths.

> **Note:** The Mega Book also covers King mechanics, income, placement, and other systems. Those parts are **reference only** — TJT's King, economy, and meta-systems follow `Game Design Document.md`, not the Mega Book. Use the reference exclusively for **units** (towers/defenders).

Keep `reference/` ignored by Git; reference files must not become commit candidates. Configure agent access separately instead of removing Git ignore rules. If the running session still blocks access, ask the user to reload the session or explicitly approve another local reference.

## Current Priorities

See `TODO.md` for current task list. Economy is deferred until PvP work begins.
