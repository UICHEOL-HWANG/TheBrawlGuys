class_name AttackSet
extends RefCounted
## Every attack's numbers for one tick, keyed by Kind (PRD §4.3-4.4). Built from GameConfig
## every tick so debug-panel tuning applies at once; Phase 5 styles derive their tables from this
## one with with_attacks (StyleCatalog). LIGHT_1/2 are link hits and LIGHT_3 is the Phase 1 light
## attack (context E1). SPECIAL (Phase 5, appended so older values never move) holds the
## character's special; the classic table keeps a heavy-shaped placeholder there.

enum Kind { LIGHT_1, LIGHT_2, LIGHT_3, HEAVY, GRAB, THROW, BAT, ROCK, BOMB, SPECIAL }

var _table: Array[AttackData] = []


static func from_config(config: GameConfig) -> AttackSet:
	var s := AttackSet.new()
	s._table.assign([
		_link(config), _link(config), AttackData.light_from(config), _heavy(config), _grab(config),
		_throw(config), _bat(config), _rock(config), _bomb(config), _heavy(config),
	])
	return s


## A new set with the given {Kind: AttackData} entries replaced; this set is left unchanged.
func with_attacks(overrides: Dictionary) -> AttackSet:
	var s := AttackSet.new()
	s._table.assign(_table)
	for kind: int in overrides:
		s._table[kind] = overrides[kind]
	return s


func get_attack(kind: int) -> AttackData:
	return _table[kind]


static func is_light_chainable(kind: int) -> bool:
	return kind == Kind.LIGHT_1 or kind == Kind.LIGHT_2


static func _numbers(damage: float, base: float, scaling: float, angle: float, hitstop_seconds: float) -> AttackData:
	var a := AttackData.new()
	a.damage = damage
	a.base_knockback = base
	a.knockback_scaling = scaling
	a.launch_angle_y = angle
	a.hitstop_ticks = SimTime.to_ticks(hitstop_seconds)
	return a


static func _frames(a: AttackData, startup: int, active: int, recovery: int) -> void:
	a.startup_ticks = startup
	a.active_ticks = active
	a.recovery_ticks = recovery


static func _link(c: GameConfig) -> AttackData:
	var a := _numbers(c.light_link_damage, c.light_link_base_knockback, 0.0, c.light_link_launch_angle_y, c.hitstop_light)
	_frames(a, c.light_startup_ticks, c.light_active_ticks, c.light_recovery_ticks)
	a.hitbox_forward = c.light_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.light_hitbox_half_width, c.light_hitbox_half_height, c.light_hitbox_half_width)
	a.min_hitstun_ticks = c.light_link_hitstun_ticks
	return a


static func _heavy(c: GameConfig) -> AttackData:
	var a := _numbers(c.heavy_damage, c.heavy_base_knockback, c.heavy_knockback_scaling, c.heavy_launch_angle_y, c.hitstop_heavy)
	_frames(a, c.heavy_startup_ticks, c.heavy_active_ticks, c.heavy_recovery_ticks)
	a.hitbox_forward = c.heavy_hitbox_forward
	a.hitbox_up = c.heavy_hitbox_up
	a.hitbox_half = Vector3(c.heavy_hitbox_half_width, c.heavy_hitbox_half_height, c.heavy_hitbox_half_width)
	return a


static func _grab(c: GameConfig) -> AttackData:
	var a := _numbers(0.0, 0.0, 0.0, 0.0, 0.0)
	_frames(a, c.grab_startup_ticks, c.grab_active_ticks, c.grab_recovery_ticks)
	a.hitbox_forward = c.grab_forward
	a.hitbox_up = c.fighter_height * 0.5
	a.hitbox_half = Vector3(c.grab_half_width, c.fighter_height * 0.5, c.grab_half_width)
	return a


static func _throw(c: GameConfig) -> AttackData:
	return _numbers(c.throw_damage, c.throw_base_knockback, c.throw_knockback_scaling, c.throw_launch_angle_y, c.hitstop_heavy)


static func _bat(c: GameConfig) -> AttackData:
	var a := _numbers(c.bat_damage, c.bat_base_knockback, c.bat_knockback_scaling, c.bat_launch_angle_y, c.hitstop_heavy)
	_frames(a, c.bat_startup_ticks, c.bat_active_ticks, c.bat_recovery_ticks)
	a.hitbox_forward = c.bat_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.bat_hitbox_half_width, c.light_hitbox_half_height, c.bat_hitbox_half_width)
	return a


static func _rock(c: GameConfig) -> AttackData:
	return _numbers(c.rock_damage, c.rock_base_knockback, c.rock_knockback_scaling, c.rock_launch_angle_y, c.hitstop_light)


static func _bomb(c: GameConfig) -> AttackData:
	return _numbers(c.bomb_damage, c.bomb_base_knockback, c.bomb_knockback_scaling, c.bomb_launch_angle_y, c.hitstop_heavy)
