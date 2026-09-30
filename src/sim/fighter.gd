class_name Fighter
extends RefCounted
## One fighter's sim state. Serialized in World snapshots (to_data/from_data) and exposed to
## views only as value copies (to_view) — never by reference (PRD §5.2, context D4).
## View reading: "launched" = HITSTUN and not on_ground; "respawn" = invuln_ticks > 0.
## New states are appended so Phase 1 values (KO = 5) never move. DODGE = a roll or air dodge
## (combat-depth A); a broken guard is HITSTUN with guard_break_left > 0.

enum State { IDLE, MOVE, AIR, ATTACK, HITSTUN, KO, CHARGE, GUARD, HOLDING, HELD, SPECIAL, DODGE }

## "No fighter" / "no item" marker for partner_id and item_kind.
const NONE := -1

const DATA_TYPES := {
	"id": TYPE_INT, "spawn_id": TYPE_INT, "pos": TYPE_VECTOR3, "vel": TYPE_VECTOR3,
	"facing": TYPE_VECTOR3, "state": TYPE_INT, "state_ticks": TYPE_INT, "damage": TYPE_FLOAT,
	"stocks": TYPE_INT, "jumps_left": TYPE_INT, "on_ground": TYPE_BOOL,
	"hitstun_ticks": TYPE_INT, "hitstop_ticks": TYPE_INT, "invuln_ticks": TYPE_INT,
	"attack_ticks": TYPE_INT, "hit_ids": TYPE_ARRAY,
	"attack_kind": TYPE_INT, "combo_queued": TYPE_BOOL, "charge_ticks": TYPE_INT,
	"charge_mul": TYPE_FLOAT, "grab_ticks": TYPE_INT, "partner_id": TYPE_INT,
	"item_kind": TYPE_INT, "item_uses": TYPE_INT, "burn_ticks": TYPE_INT, "burn_clock": TYPE_INT,
	"held_presses": TYPE_INT, "character": TYPE_STRING, "gauge": TYPE_FLOAT,
	"guard_prev": TYPE_BOOL, "guard_press_age": TYPE_INT, "guard_rest_ticks": TYPE_INT, "guard_hp": TYPE_FLOAT, "guard_idle_ticks": TYPE_INT,
	"guard_break_left": TYPE_INT, "perfect_by": TYPE_INT, "dodge_kind": TYPE_INT, "dodge_ticks": TYPE_INT,
	"dodge_total": TYPE_INT, "dodge_dir": TYPE_VECTOR3, "intangible": TYPE_BOOL, "air_dodge_used": TYPE_BOOL,
	"roll_streak": TYPE_INT, "roll_recent": TYPE_INT,
}

var id: int = 0
## Increments on every respawn so views snap instead of interpolating across the map.
var spawn_id: int = 0
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3(0, 0, 1)
var state: int = State.IDLE
var state_ticks: int = 0
var damage: float = 0.0
var stocks: int = 0
var jumps_left: int = 0
var on_ground: bool = true
var hitstun_ticks: int = 0
var hitstop_ticks: int = 0
var invuln_ticks: int = 0
var attack_ticks: int = 0
## Targets already hit by the current swing (one hit per target per attack).
var hit_ids: Array[int] = []
## AttackSet.Kind of the current (or last) attack.
var attack_kind: int = 0
## A light press landed inside the combo buffer; the next hit starts when this one ends (E2).
var combo_queued: bool = false
var charge_ticks: int = 0
## Multiplier for the heavy attack that is currently swinging (E3).
var charge_mul: float = 1.0
## Ticks left before a hold ends by itself (holder only, E5).
var grab_ticks: int = 0
## HOLDING: the fighter being held. HELD: the holder.
var partner_id: int = NONE
## Item.Kind carried in hand, or NONE (E6).
var item_kind: int = NONE
var item_uses: int = 0
## Ticks of burning left (campfire, Burning) and ticks since the last burn damage.
var burn_ticks: int = 0
var burn_clock: int = 0
## PressBuffer mask of presses made during hitstop, replayed when the freeze ends.
var held_presses: int = 0
## CharacterData id ("" = classic) and special gauge 0..SpecialGauge.MAX (Phase 5).
var character: String = CharacterData.DEFAULT
var gauge: float = 0.0
## Guard (combat-depth A, GuardMeter): last tick's guard level, ticks since the last guard press,
## ticks guard was let go before it (frozen while held; perfect-guard rearm), meter points, ticks since the last guard, ticks of guard-break stun left, and the attacker
## whose hit this fighter perfect-guarded this tick (NONE otherwise).
var guard_prev: bool = false
var guard_press_age: int = GuardMeter.AGE_CAP
var guard_rest_ticks: int = GuardMeter.AGE_CAP
var guard_hp: float = GuardMeter.MAX
var guard_idle_ticks: int = 0
var guard_break_left: int = 0
var perfect_by: int = NONE
## Dodge (Dodge): Dodge.Kind, ticks since it started, its length, direction, whether hits pass
## through right now, the air dodge spent this airtime, and the roll-spam streak and window.
var dodge_kind: int = 0
var dodge_ticks: int = 0
var dodge_total: int = 0
var dodge_dir: Vector3 = Vector3.ZERO
var intangible: bool = false
var air_dodge_used: bool = false
var roll_streak: int = 0
var roll_recent: int = 0


func is_alive() -> bool:
	return state != State.KO


## Hits, grabs and projectiles pass through: respawn / special invulnerability or a dodge window.
func untouchable() -> bool:
	return invuln_ticks > 0 or intangible


func can_act() -> bool:
	return state == State.IDLE or state == State.MOVE or state == State.AIR


func set_state(s: int) -> void:
	if state != s:
		state = s
		state_ticks = 0


func to_view() -> Dictionary:
	return FighterViewData.of(self)


func to_data() -> Dictionary:
	var d := {}
	for key: String in DATA_TYPES:
		d[key] = get(key)
	d["hit_ids"] = hit_ids.duplicate()
	return d


static func from_data(d: Dictionary) -> Fighter:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	for v: Variant in d["hit_ids"]:
		if typeof(v) != TYPE_INT:
			return null
	var f := Fighter.new()
	for key: String in DATA_TYPES:
		if key != "hit_ids":
			f.set(key, d[key])
	f.hit_ids.assign(d["hit_ids"])
	return f
