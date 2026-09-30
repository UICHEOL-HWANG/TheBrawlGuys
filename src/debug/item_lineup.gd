class_name ItemLineup
extends Node3D
## Item model lineup for the DS gallery and evidence captures (DS-VIS-05, Phase 4 T8): a falling
## crate over its landing shadow, fresh and cracked bats, an unlit and a lit bomb, a resting and
## a tumbling rock, in a row along x. Fake item views only; nothing runs the sim.

const SPACING := 1.25
const LIT_FUSE_TICKS := 40
const TUMBLE_TICK := 3


func setup(config: GameConfig) -> void:
	var samples := samples_for(config)
	for i: int in samples.size():
		var s: Dictionary = samples[i]
		s["pos"] = Vector3((i - (samples.size() - 1) * 0.5) * SPACING, float(s.get("y", 0.0)), 0)
		var v := ItemView.new()
		add_child(v)
		v.setup(int(s["kind"]), config, int(s["state"]) == Item.State.FALLING)
		v.apply(s, s, 1.0, int(s.get("tick", 0)))


static func samples_for(config: GameConfig) -> Array[Dictionary]:
	return [
		_sample(Item.Kind.BAT, Item.State.FALLING, config.bat_uses, Item.UNLIT, 1.2),
		_sample(Item.Kind.BAT, Item.State.GROUND, config.bat_uses, Item.UNLIT),
		_sample(Item.Kind.BAT, Item.State.GROUND, 1, Item.UNLIT),
		_sample(Item.Kind.BOMB, Item.State.GROUND, 1, Item.UNLIT),
		_sample(Item.Kind.BOMB, Item.State.THROWN, 1, LIT_FUSE_TICKS),
		_sample(Item.Kind.ROCK, Item.State.GROUND, 1, Item.UNLIT),
		_sample(Item.Kind.ROCK, Item.State.THROWN, 1, Item.UNLIT, 0.4, TUMBLE_TICK),
	]


static func _sample(kind: int, state: int, uses: int, fuse: int, y: float = 0.0, tick: int = 0) -> Dictionary:
	return {"id": 0, "kind": kind, "state": state, "uses": uses, "fuse_ticks": fuse, "y": y, "tick": tick}
