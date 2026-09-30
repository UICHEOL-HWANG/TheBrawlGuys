class_name SpecialCatalog
extends RefCounted
## Special id -> its stateless Special (one file each under src/sim/specials/).

const GROUND_SLAM := GroundSlam.ID
const DASH_RUSH := DashRush.ID
const SPIN_SLASH := SpinSlash.ID
const BIG_FIREBALL := BigFireball.ID
const IDS: Array[String] = [GROUND_SLAM, DASH_RUSH, SPIN_SLASH, BIG_FIREBALL]

static var _cache: Dictionary = {}


## The special for id; unknown ids get the inert base Special (never hits).
static func get_special(id: String) -> Special:
	if not _cache.has(id):
		_cache[id] = _make(id)
	return _cache[id]


static func attack(id: String, config: GameConfig) -> AttackData:
	return get_special(id).attack(config)


static func _make(id: String) -> Special:
	match id:
		GROUND_SLAM:
			return GroundSlam.new()
		DASH_RUSH:
			return DashRush.new()
		SPIN_SLASH:
			return SpinSlash.new()
		BIG_FIREBALL:
			return BigFireball.new()
	push_error("SpecialCatalog: unknown special '%s'" % id)
	return Special.new()
