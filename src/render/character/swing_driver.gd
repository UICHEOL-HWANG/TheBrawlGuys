class_name SwingDriver
extends RefCounted
## Picks the clip of a seek-driven state and where it should be this frame (combat-motion A2).
## Swings follow the sim's attack_ticks (plus the render fraction of the next tick) through
## SwingTiming, so the strike lands on the first active tick for every style's frame data.
## Posed states (holding, being held) hold one frame with a sway on a free-running clock. A
## timed state reached outside ATTACK / SPECIAL (a getup attack) runs on that clock too.

## A swing seen at or below this attack tick after a later one is a fresh swing.
const RESTART_TICKS := 2

var _config: GameConfig
var _plan: Dictionary = {}
var _frames: AttackData = AttackData.new()
var _posed: int = -1
var _from_sim: bool = false
var _ticks: int = 0
var _sub: float = 0.0
var _clock: float = 0.0


func _init(config: GameConfig) -> void:
	_config = config


## A new swing / pose starts; returns the clip to play. fallback: the state's AnimClips clip
## (used when no plan fits or the model lacks the planned clip) and its length.
func begin(anim: int, view: Dictionary, fallback: String, fallback_length: float, has_clip: Callable) -> String:
	_clock = 0.0
	_sub = 0.0
	_ticks = int(view.get("attack_ticks", 0))
	_posed = anim if SwingClips.POSES.has(anim) else -1
	if _posed >= 0:
		var clip := String((SwingClips.POSES[anim] as Dictionary)["clip"])
		return clip if has_clip.call(clip) else fallback
	if anim == AnimMap.Anim.THROW:
		return _begin_throw(fallback, has_clip)
	var state := int(view.get("state", Fighter.State.IDLE))
	_from_sim = state == Fighter.State.ATTACK or state == Fighter.State.SPECIAL
	var kind := int(view.get("attack_kind", AttackSet.Kind.LIGHT_1)) if _from_sim else AttackSet.Kind.HEAVY
	var special := String(view.get("special", ""))
	_plan = SwingClips.pick(String(view.get("style", "")), kind, special)
	if _plan.is_empty() or not has_clip.call(String(_plan["clip"])):
		_plan = {"clip": fallback, "start": 0.0, "contact": fallback_length * 0.35, "end": fallback_length}
	_frames = _frames_for(String(view.get("style", "")), kind, special)
	return String(_plan["clip"])


## True when the view starts another swing of the same state (a repeat of the same kind). A new
## swing starts at its first ticks; a rollback that rewinds a few ticks mid-swing is not one.
func restarts(view: Dictionary) -> bool:
	var ticks := int(view.get("attack_ticks", 0))
	return _posed < 0 and _from_sim and ticks < _ticks and ticks <= RESTART_TICKS


## Clip time for this frame; frozen (hitstop) holds it.
func time(view: Dictionary, delta: float, frozen: bool) -> float:
	if not frozen:
		_clock += delta
	if _posed >= 0:
		return SwingClips.pose_time(_posed, _clock)
	var progress := 1.0 + _clock * SimTime.TICK_RATE
	if _from_sim:
		var ticks := int(view.get("attack_ticks", 0))
		if ticks != _ticks:
			_ticks = ticks
			_sub = 0.0
		elif not frozen:
			_sub = minf(_sub + delta * SimTime.TICK_RATE, 1.0)
		progress = float(_ticks) + _sub
	return SwingTiming.clip_time(progress, _frames, _plan)


func plan() -> Dictionary:
	return _plan


## True once a render-clocked swing (the toss) has played to its end.
func done() -> bool:
	return not _from_sim and _clock * SimTime.TICK_RATE >= float(_frames.total_ticks())


## The toss runs on the render clock: release pose at once (held while frozen), then follow-through.
func _begin_throw(fallback: String, has_clip: Callable) -> String:
	_from_sim = false
	_plan = SwingClips.THROW if has_clip.call(String(SwingClips.THROW["clip"])) else \
			{"clip": fallback, "start": 0.0, "contact": 0.0, "end": 0.01}
	_frames = AttackData.new()
	_frames.startup_ticks = 0
	_frames.active_ticks = SwingClips.THROW_ACTIVE_TICKS
	_frames.recovery_ticks = SwingClips.THROW_RECOVERY_TICKS
	return String(_plan["clip"])


func _frames_for(style: String, kind: int, special: String) -> AttackData:
	if kind == AttackSet.Kind.SPECIAL:
		return SpecialCatalog.attack(special, _config) if not special.is_empty() else AttackData.new()
	return StyleCatalog.build(style if not style.is_empty() else StyleCatalog.CLASSIC, _config).attacks.get_attack(kind)
