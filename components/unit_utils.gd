extends Node
class_name UnitUtils

# Utility helpers for unit-like nodes (units, enemy units, etc.)
# Use `UnitUtils.is_unit_node(node)` to check if a node implements the unit interface.

static func is_unit_node(node) -> bool:
	if node == null:
		return false
	# Consider a node a unit if it exposes `apply_damage` (and/or `stats`) method/property
	if node.has_method("apply_damage"):
		return true
	# Fallback: some nodes may expose `stats` resource directly and be unit-like
	if node.has_property("stats"):
		return true
	return false
