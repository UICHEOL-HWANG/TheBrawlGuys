class_name ItemStatus
extends RefCounted
## Feather-glove lightness (PRD-ITEM-06): a clean glove hit makes the target light for
## glove_light_time; light fighters take glove_light_knockback_mul of every knockback (all hit
## sources share Combat.apply_hit). Counts down every tick; respawn clears it (Rules).


## The knockback multiplier for this target right now.
static func knockback_mul(target: Fighter, config: GameConfig) -> float:
	return config.glove_light_knockback_mul if target.light_ticks > 0 else 1.0


## After a melee hit event: a clean (unguarded) glove hit refreshes the target's lightness.
static func on_melee_hit(target: Fighter, attack_kind: int, event: Dictionary, config: GameConfig) -> void:
	if attack_kind == AttackSet.Kind.GLOVE and String(event["type"]) == "hit":
		target.light_ticks = SimTime.to_ticks(config.glove_light_time)
		event["made_light"] = true


static func step(fighters: Array[Fighter]) -> void:
	for f: Fighter in fighters:
		if f.light_ticks > 0:
			f.light_ticks -= 1
