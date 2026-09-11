class_name UnitStats
extends Resource

signal health_reached_zero
signal health_changed(new_health: int)
signal mana_bar_filled

@export var name: String

enum Team {PLAYER, ENEMY}
enum DamageType {PHYSICAL, MAGICAL, PURE}
enum Faction {
	NONE,
	WARRIOR,  ## Sentinel, Grunt, Slayer — 3× bonus: +20% ATK damage
	MYSTIC,   ## Acolyte, Sage, Shaman  — 3× bonus: +20% ability power
	WARDEN,   ## Scout, Cleric          — 2× bonus: +15% ATK speed
}

const TARGET := {
	Team.PLAYER: "enemy_units",
	Team.ENEMY: "player_units"
}

const TEAM_SPRITESHEET := {
	Team.PLAYER: preload("res://asset/sprites/rogues.png"),
	Team.ENEMY: preload("res://asset/sprites/monsters.png")
}

const MAX_ATTACK_RANGE := 5
const MOVE_ONE_TILE_SPEED := 1.0
## Legion TD has tiers 1-6; TJT adds tier 7 as the "champion" tier (see UNIT_BLUEPRINTS.md).
const MAX_TIER := 7

@export_category("Data")
## Shop price in gold. For upgrade units this is the TOTAL value (base + upgrade price).
@export var gold_cost := 1
## Unit tier (Legion TD-style "level" of the unit: 1 = cheapest / weakest, 7 = champion).
## Upgrades keep the tier of their base unit.
@export_range(1, MAX_TIER) var tier := 1 : set = _set_tier
## Copies of this unit available in the deck pool.
@export var pool_count := 5
@export var is_king: bool = false  ## When true, this is the King unit — death = Game Over
@export var faction: Faction = Faction.NONE  ## Faction for synergy system

@export_category("Upgrades")
## Legion TD-style upgrade options for a placed unit. The upgraded unit's gold_cost is its
## TOTAL value (base + upgrade), so the price to upgrade is the difference between the two
## gold_costs and selling an upgraded unit refunds everything invested in it.
## Only the base unit lists its upgrades — upgraded units do NOT reference their base
## (avoids cyclic .tres references).
@export var upgrades: Array[UnitStats] = []
## Name of the base unit this unit belongs to (e.g. "Sentinel" for Vanguard). Used so a base
## unit and its upgrade count as ONE unique unit for faction synergies. Empty = this unit's name.
@export var unit_line: String = ""

@export_category("Visuals")
## Cell (column, row) of this sprite in the team spritesheet; multiplied by tile_size.
@export var skin_coordinates: Vector2i
## Size of the unit's visual sprite in pixels (e.g. 32x32, 16x16, 64x64).
## Used to center the unit on its placement tile and to slice the spritesheet correctly.
## Changing this auto-updates `footprint` to match (tile_size / GRID_CELL_PX).
@export var tile_size: Vector2i = Vector2i(32, 32) : set = _set_tile_size
## Visual scale multiplier (e.g. 1.5 for King). Applied to the Visuals node.
@export var visual_scale: float = 1.0
## Placement footprint in logical grid cells (8 px each). Auto-calculated from
## tile_size: footprint = ceil(tile_size / 8). A 32x32 sprite -> 4x4 cells (32 px),
## a 64x64 sprite -> 8x8 cells (64 px). Can be overridden manually if needed.
@export var footprint: Vector2i = Vector2i(4, 4)
## Optional SpriteFrames for animated units (idle, move, attack).
## When set, the unit will use AnimatedSprite2D instead of the static spritesheet.
@export var sprite_frames: SpriteFrames

@export_category("Battle")
## Side this unit fights for (PLAYER or ENEMY).
@export var team: Team
## Hit points.
@export var max_health: int
## HP regenerated per second.
@export var health_regen: float
## Mana cap — the ability casts when mana is full.
@export var max_mana: int
## Mana at spawn.
@export var starting_mana: int
## Mana regenerated per second.
@export var mana_regen: float
## Basic attack damage.
@export var attack_damage: int
## Ability power — scales ability damage/healing.
@export var ability_power: int
## Attacks per second.
@export var attack_speed: float
## Physical damage reduction in %.
@export var armor: int
## Magical damage reduction in %.
@export var magic_resist: int
## Attack range in tiles.
@export_range(1, MAX_ATTACK_RANGE) var attack_range: int
## Aggro range in tiles — engages enemies within this distance.
@export_range(1, 10) var aggro_range: int = 3
## Effect scene for melee attacks.
@export var melee_attack: PackedScene
## Projectile scene for ranged attacks.
@export var ranged_attack: PackedScene
## Legacy ability slot — kept for compatibility; prefer ability_resource.
@export var ability: PackedScene
## Active ability resource (current ability system).
@export var ability_resource: Ability
## Passive ability resource (stat bonuses / on-hit effects).
@export var passive_ability: PassiveAbility
## SFX played on basic attacks.
@export var auto_attack_sound: AudioStream

var health: int : set = _set_health
var mana: int : set = _set_mana


func reset_health() -> void:
	health = get_max_health()


func reset_mana() -> void:
	mana = starting_mana


## Returns the number of units combined based on tier (3^(tier-1)).
func get_combined_unit_count() -> int:
	return 3 ** (tier - 1)

## Returns the total gold value of this unit (cost × combined count).
func get_gold_value() -> int:
	return gold_cost * get_combined_unit_count()


## Returns true if this unit has at least one upgrade option.
func has_upgrades() -> bool:
	return not upgrades.is_empty()


## Returns the gold needed to upgrade this unit into `target` (difference of total values).
## Never negative — a cheaper "upgrade" is free rather than refunding gold.
func get_upgrade_cost(target: UnitStats) -> int:
	if not target:
		return 0
	return maxi(target.gold_cost - gold_cost, 0)


## Returns the synergy identity of this unit: its unit_line if set, otherwise its name.
func get_unit_line() -> String:
	return unit_line if not unit_line.is_empty() else name


func get_max_health() -> int:
	return max_health


func get_attack_damage() -> int:
	return attack_damage


## Returns damage after applying armor or magic resist reduction.
## Armor and magic_resist are treated as direct percentages: 15 armor = 15% reduction.
## Capped at 90% to prevent full immunity (max 90 armor/MR effective).
## Pure: no reduction.
static func calculate_reduced_damage(
		damage: float,
		type: DamageType,
		armor_param: int,
		magic_resist_param: int) -> float:
	match type:
		DamageType.PHYSICAL:
			var reduction: float = clampf(float(armor_param), 0.0, 90.0) / 100.0
			return damage * (1.0 - reduction)
		DamageType.MAGICAL:
			var reduction: float = clampf(float(magic_resist_param), 0.0, 90.0) / 100.0
			return damage * (1.0 - reduction)
		DamageType.PURE:
			return damage
	return damage


func get_time_between_attacks() -> float:
	return 1 / attack_speed


func get_team_collision_layer() -> int:
	return team + 1


func get_team_collision_mask() -> int:
	return 2 - team


func is_melee() -> bool:
	return attack_range == 1


## Sets the tier value and emits a changed signal for resource updates.
func _set_tier(value: int) -> void:
	tier = value
	emit_changed()


## Sets tile_size and auto-calculates footprint from it (ceil(tile_size / 8)).
func _set_tile_size(value: Vector2i) -> void:
	tile_size = value
	footprint = Vector2i(ceili(value.x / 8.0), ceili(value.y / 8.0))
	emit_changed()


## Sets health and emits signal if zero.
func _set_health(value: int) -> void:
	health = value
	health_changed.emit(health)
	if health <= 0:
		health_reached_zero.emit()


## Sets mana and emits signal if full.
func _set_mana(value: int) -> void:
	mana = value
	if mana >= max_mana:
		mana_bar_filled.emit()


## Returns a string representation of the unit stats (the unit's name).
func _to_string() -> String:
	return name
