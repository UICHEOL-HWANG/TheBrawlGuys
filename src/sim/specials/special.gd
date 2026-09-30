class_name Special
extends RefCounted
## Base for one character special (PRD §6.2.1); each special lives in its own file and overrides
## what it needs. Stateless: every value comes from the fighter, its attack and GameConfig.
## Frames: the attack's startup / active / recovery; attack_ticks counts ticks since the start
## (the first special tick is 1), the same as an ATTACK.


## Numbers and frames of the special (it becomes the fighter's AttackSet.Kind.SPECIAL entry).
func attack(_config: GameConfig) -> AttackData:
	return AttackData.new()


## Movement on each tick the fighter advances in SPECIAL (default: planted on the ground).
func move(f: Fighter, _attack: AttackData, _config: GameConfig) -> void:
	if f.on_ground:
		Actions.stop_horizontal(f)


## Once per advanced tick, after movement (projectile spawns, multi-hit windows).
func advance(_f: Fighter, _attack: AttackData, _field: ProjectileField, _config: GameConfig) -> Array[Dictionary]:
	return []


## This tick's contacts (SpecialHits.contact), found before melee combat and applied after it.
func contacts(_f: Fighter, _fighters: Array[Fighter], _attack: AttackData, _config: GameConfig) -> Array[Dictionary]:
	return []


## Distance (m) within which the special can hit a foe (bots fire when a foe is this close).
func reach(_config: GameConfig) -> float:
	return 0.0
