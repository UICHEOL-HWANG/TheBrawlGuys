class_name StockLoss
extends RefCounted
## Who or what caused a lost stock (platform A6, stock_lost). The last attacker or arena gimmick
## to touch the victim within WINDOW_TICKS gets the credit, the more recent one wins; otherwise
## the fall is self-inflicted. Also turns the ringout position into an angle and compass zone.

## About three seconds at 60 Hz.
const WINDOW_TICKS := 180
const NONE := -1
## Compass sectors from angle 0 (+x, east) counter-clockwise seen from above (-z is north).
const ZONES: Array[String] = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
const ZONE_BELOW := "below"

var _attack: Dictionary = {}  # victim -> [attacker, tick]
var _gimmick: Dictionary = {}  # victim -> [kind, tick]


func note_attack(victim: int, attacker: int, tick: int) -> void:
	if attacker != victim and attacker >= 0:
		_attack[victim] = [attacker, tick]


func note_gimmick(victim: int, kind: String, tick: int) -> void:
	_gimmick[victim] = [kind, tick]


## {"attacker_slot", "cause": knockback|gimmick|self, "gimmick_kind"}; forgets the victim's history.
func classify(victim: int, tick: int) -> Dictionary:
	var attack: Array = _attack.get(victim, [NONE, -WINDOW_TICKS - 1])
	var gimmick: Array = _gimmick.get(victim, ["", -WINDOW_TICKS - 1])
	_attack.erase(victim)
	_gimmick.erase(victim)
	var attack_recent := tick - int(attack[1]) <= WINDOW_TICKS
	var gimmick_recent := tick - int(gimmick[1]) <= WINDOW_TICKS
	if gimmick_recent and (not attack_recent or int(gimmick[1]) >= int(attack[1])):
		return {"attacker_slot": NONE, "cause": "gimmick", "gimmick_kind": gimmick[0]}
	if attack_recent:
		return {"attacker_slot": int(attack[0]), "cause": "knockback", "gimmick_kind": ""}
	return {"attacker_slot": NONE, "cause": "self", "gimmick_kind": ""}


## Degrees 0..359 on the ground plane: 0 = +x (east), 90 = -z (north).
static func angle_deg(pos: Vector3) -> int:
	return posmod(roundi(rad_to_deg(atan2(-pos.z, pos.x))), 360)


## Compass sector of the exit, or "below" when the fighter fell inside the arena radius.
static func zone(pos: Vector3, arena_radius: float) -> String:
	if Vector2(pos.x, pos.z).length() <= arena_radius:
		return ZONE_BELOW
	var sector := roundi(angle_deg(pos) / 45.0) % ZONES.size()
	return ZONES[sector]
