class_name SynergyManager
extends Node

## Tracks faction counts of placed ally units and applies/removes stat bonuses.
##
## Factions:
##   WARRIOR (3×): Sentinel, Grunt, Slayer  → +20% ATK damage
##   MYSTIC  (3×): Acolyte, Sage, Shaman     → +20% ability power
##   WARDEN  (2×): Scout, Cleric             → +15% ATK speed

signal synergies_updated

## Synergy definitions: Faction → {threshold, bonuses}
const SYNERGY_DEFS := {
	UnitStats.Faction.WARRIOR: {
		"name": "Warriors",
		"threshold": 3,
		"attack_damage_mult": 1.2,
	},
	UnitStats.Faction.MYSTIC: {
		"name": "Mystics",
		"threshold": 3,
		"ability_power_mult": 1.2,
	},
	UnitStats.Faction.WARDEN: {
		"name": "Wardens",
		"threshold": 2,
		"attack_speed_mult": 1.15,
	},
}

var _tracked_units: Array[Node] = []
var _applied: Dictionary = {}  # Faction → bool


func register_unit(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	if not ("stats" in unit) or not unit.stats:
		return
	if unit.stats.get("faction") == null:
		return
	if unit.stats.faction == UnitStats.Faction.NONE:
		return
	if unit in _tracked_units:
		return
	_tracked_units.append(unit)
	if is_synergy_active(unit.stats.faction):
		_store_and_apply(unit, SYNERGY_DEFS[unit.stats.faction])
	# Unregister automatically when the unit leaves the tree
	unit.tree_exited.connect(_on_unit_removed.bind(unit))
	_recompute()


func _on_unit_removed(unit: Node) -> void:
	_tracked_units.erase(unit)
	_recompute()


func get_faction_count(faction: UnitStats.Faction) -> int:
	var seen_names := {}
	var count := 0
	for u in _tracked_units:
		if is_instance_valid(u) and u.stats and u.stats.faction == faction:
			var n: String = u.stats.get_unit_line()
			if n not in seen_names:
				seen_names[n] = true
				count += 1
	return count


## Returns Dictionary[Faction, int] of all tracked faction counts.
## Only unique unit types are counted per faction. Identity is stats.get_unit_line(), so a
## base unit and its upgrade (e.g. Sentinel / Vanguard) count as one.
func get_all_counts() -> Dictionary:
	var counts := {}
	var seen: Dictionary = {}  # faction → { name: true }
	for u in _tracked_units:
		if not is_instance_valid(u) or not u.stats:
			continue
		var f: int = u.stats.faction
		if f == UnitStats.Faction.NONE:
			continue
		var n: String = u.stats.get_unit_line()
		if f not in seen:
			seen[f] = {}
		if n not in seen[f]:
			seen[f][n] = true
			counts[f] = counts.get(f, 0) + 1
	return counts


## Returns true when the given faction's synergy bonus is currently active.
func is_synergy_active(faction: UnitStats.Faction) -> bool:
	return _applied.get(faction, false)


func _recompute() -> void:
	# Drop invalid refs
	_tracked_units = _tracked_units.filter(func(u): return is_instance_valid(u))

	for faction in SYNERGY_DEFS.keys():
		var def: Dictionary = SYNERGY_DEFS[faction]
		var count := get_faction_count(faction)
		var should_be_active: bool = count >= def.threshold
		var was_active: bool = _applied.get(faction, false)

		if should_be_active and not was_active:
			_apply_synergy(faction)
		elif not should_be_active and was_active:
			_remove_synergy(faction)

	synergies_updated.emit()


func _apply_synergy(faction: UnitStats.Faction) -> void:
	var def: Dictionary = SYNERGY_DEFS[faction]
	for unit in _tracked_units:
		if not is_instance_valid(unit) or not unit.stats:
			continue
		if unit.stats.faction != faction:
			continue
		_store_and_apply(unit, def)
	_applied[faction] = true


func _remove_synergy(faction: UnitStats.Faction) -> void:
	var def: Dictionary = SYNERGY_DEFS[faction]
	for unit in _tracked_units:
		if not is_instance_valid(unit) or not unit.stats:
			continue
		if unit.stats.faction != faction:
			continue
		_restore(unit, def)
	_applied[faction] = false


func _store_and_apply(unit: Node, def: Dictionary) -> void:
	if "attack_damage_mult" in def:
		if not unit.has_meta("syn_base_atk"):
			unit.set_meta("syn_base_atk", unit.stats.attack_damage)
		unit.stats.attack_damage = int(unit.get_meta("syn_base_atk") * def.attack_damage_mult)

	if "ability_power_mult" in def:
		if not unit.has_meta("syn_base_ap"):
			unit.set_meta("syn_base_ap", unit.stats.ability_power)
		unit.stats.ability_power = int(unit.get_meta("syn_base_ap") * def.ability_power_mult)

	if "attack_speed_mult" in def:
		if not unit.has_meta("syn_base_spd"):
			unit.set_meta("syn_base_spd", unit.stats.attack_speed)
		unit.stats.attack_speed = unit.get_meta("syn_base_spd") * def.attack_speed_mult


func _restore(unit: Node, def: Dictionary) -> void:
	if "attack_damage_mult" in def and unit.has_meta("syn_base_atk"):
		unit.stats.attack_damage = unit.get_meta("syn_base_atk")
		unit.remove_meta("syn_base_atk")

	if "ability_power_mult" in def and unit.has_meta("syn_base_ap"):
		unit.stats.ability_power = unit.get_meta("syn_base_ap")
		unit.remove_meta("syn_base_ap")

	if "attack_speed_mult" in def and unit.has_meta("syn_base_spd"):
		unit.stats.attack_speed = unit.get_meta("syn_base_spd")
		unit.remove_meta("syn_base_spd")
