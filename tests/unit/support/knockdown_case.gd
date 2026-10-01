extends RefCounted
## Test helper for knockdown, getup and tech (combat-depth C): P2 (id 1) is launched high by a
## strong hit at (-3, 0, 0) and drifts along +x; P1 (id 0) waits far away. Scripts are
## Callables t -> InputFrame for P2 (t counts ticks since the launch).

const VICTIM := 1


## A world with P2 freshly launched (still in hitstop).
static func launched(config: GameConfig = null) -> World:
	var w := World.new(config if config != null else GameConfig.new(), 1)
	w.fighters[0].pos = Vector3(0, 0, -7)
	var t := w.fighters[VICTIM]
	t.pos = Vector3(-3, 0, 0)
	Combat.apply_hit(t, strong_hit(w.config), Vector3(1, 0, 0), 1.0, w.config, t.pos, 0)
	return w


## Knockback well above knockdown_min_knockback, mostly upward.
static func strong_hit(config: GameConfig) -> AttackData:
	return AttackData.make(0.0, 9.0, 0.0, 3.0, 0, 1, 0, config.hitstop_heavy)


static func step(w: World, p2: InputFrame, p1: InputFrame = null) -> void:
	w.tick([p1 if p1 != null else InputFrame.neutral(), p2] as Array[InputFrame])


## Ticks P2 with `script` until it stands on the ground (or max_ticks); returns the tick count.
static func until_landed(w: World, script: Callable, max_ticks: int = 240) -> int:
	var t := 0
	while t < max_ticks:
		step(w, script.call(t))
		t += 1
		if w.fighters[VICTIM].on_ground:
			break
	return t


## Ticks after the launch until P2 lands when nothing is pressed.
static func landing_tick(config: GameConfig = null) -> int:
	return until_landed(launched(config), func(_t: int) -> InputFrame: return InputFrame.neutral())


## A world with P2 lying in KNOCKDOWN (just landed).
static func knocked_down(config: GameConfig = null) -> World:
	var w := launched(config)
	until_landed(w, func(_t: int) -> InputFrame: return InputFrame.neutral())
	return w


static func events_of(w: World, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == type:
			out.append(e)
	return out
