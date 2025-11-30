extends Resource
class_name PassiveAbility

## Base class for passive abilities that modify unit stats

enum PassiveType {
	HEALTH_REGEN_BONUS,    # Increases health regen by percentage
	MANA_REGEN_BONUS,      # Increases mana regen by percentage
	DAMAGE_BONUS,          # Increases attack damage
	ARMOR_BONUS,           # Increases armor
	SPEED_BONUS,           # Increases attack speed
	MAX_HEALTH_BONUS,      # Increases max health
	DAMAGE_REDUCTION       # Reduces incoming damage
}

@export var passive_name: String = "Unnamed Passive"
@export_multiline var description: String = ""
@export var passive_type: PassiveType = PassiveType.HEALTH_REGEN_BONUS
@export var value: float = 0.0  # Percentage (0.2 = 20%) or flat value depending on type


## Apply passive effect to unit
func apply(unit: Unit) -> void:
	match passive_type:
		PassiveType.HEALTH_REGEN_BONUS:
			# Increase health regen by percentage
			var bonus = unit.stats.health_regen * value
			unit.stats.health_regen += bonus
			print("[Passive] %s: %s health regen increased by %.1f%% (%.2f -> %.2f)" % 
				[unit.stats.name, passive_name, value * 100, 
				unit.stats.health_regen - bonus, unit.stats.health_regen])
		
		PassiveType.MANA_REGEN_BONUS:
			var bonus = unit.stats.mana_regen * value
			unit.stats.mana_regen += bonus
			print("[Passive] %s: %s mana regen increased by %.1f%%" % 
				[unit.stats.name, passive_name, value * 100])
		
		PassiveType.DAMAGE_BONUS:
			var bonus = int(unit.stats.attack_damage * value)
			unit.stats.attack_damage += bonus
			print("[Passive] %s: %s damage increased by %d" % 
				[unit.stats.name, passive_name, bonus])
		
		PassiveType.ARMOR_BONUS:
			var bonus = int(value)
			unit.stats.armor += bonus
			print("[Passive] %s: %s armor increased by %d" % 
				[unit.stats.name, passive_name, bonus])
		
		PassiveType.MAX_HEALTH_BONUS:
			var bonus = int(unit.stats.max_health * value)
			unit.stats.max_health += bonus
			unit.current_health += bonus  # Also increase current health
			print("[Passive] %s: %s max health increased by %d" % 
				[unit.stats.name, passive_name, bonus])


## Remove passive effect from unit (for temporary passives)
func remove(unit: Unit) -> void:
	match passive_type:
		PassiveType.HEALTH_REGEN_BONUS:
			var bonus = (unit.stats.health_regen / (1.0 + value)) * value
			unit.stats.health_regen -= bonus
		
		PassiveType.MANA_REGEN_BONUS:
			var bonus = (unit.stats.mana_regen / (1.0 + value)) * value
			unit.stats.mana_regen -= bonus
		
		PassiveType.DAMAGE_BONUS:
			var bonus = int((unit.stats.attack_damage / (1.0 + value)) * value)
			unit.stats.attack_damage -= bonus
		
		PassiveType.ARMOR_BONUS:
			unit.stats.armor -= int(value)
		
		PassiveType.MAX_HEALTH_BONUS:
			var bonus = int((unit.stats.max_health / (1.0 + value)) * value)
			unit.stats.max_health -= bonus
