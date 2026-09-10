extends Control

## Shows active / pending faction synergies in HUD.

@onready var vbox: VBoxContainer = $VBoxContainer

var synergy_manager: SynergyManager


func _ready() -> void:
	# Title
	var title := Label.new()
	title.text = "Synergies"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	vbox.add_child(title)
	# Rows are created dynamically on update
	_build_rows()


func setup(mgr: SynergyManager) -> void:
	synergy_manager = mgr
	if mgr:
		mgr.synergies_updated.connect(_on_synergies_updated)
	_refresh()


func _on_synergies_updated() -> void:
	_refresh()


func _refresh() -> void:
	if not synergy_manager:
		return
	var counts: Dictionary = synergy_manager.get_all_counts()
	var i := 1  # skip title at index 0
	for faction in SynergyManager.SYNERGY_DEFS.keys():
		var def: Dictionary = SynergyManager.SYNERGY_DEFS[faction]
		var count: int = counts.get(faction, 0)
		var threshold: int = def.threshold
		var active: bool = synergy_manager.is_synergy_active(faction)
		var row: Label = vbox.get_child(i) if i < vbox.get_child_count() else null
		if not row:
			break
		var dots := ""
		for d in range(threshold):
			dots += "●" if d < count else "○"
		var status := " ACTIVE" if active else ""
		var label_text := "%s %s %d/%d%s" % [
			_faction_icon(faction), def.name, count, threshold, status]
		row.text = "%s  %s" % [dots, label_text]
		row.add_theme_color_override(
				"font_color",
				Color(1.0, 0.87, 0.35) if active else Color(0.76, 0.76, 0.76))
		i += 1


func _build_rows() -> void:
	for faction in SynergyManager.SYNERGY_DEFS.keys():
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		vbox.add_child(row)


func _faction_icon(faction: UnitStats.Faction) -> String:
	match faction:
		UnitStats.Faction.WARRIOR: return "⚔"
		UnitStats.Faction.MYSTIC:  return "✨"
		UnitStats.Faction.WARDEN:  return "🏹"
	return ""
