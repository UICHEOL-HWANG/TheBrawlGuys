class_name SwingEvents
extends RefCounted
## Melee swing view event (the whoosh cue, design.md DS-SFX-01): a fighter's ATTACK view crossing
## the tick a little before its first active tick (the blade or fist moving through the air).
## Fists, swords and swung items only: a grab, a thrown item or a mage's bolt cast is no swing.
## Read from view differences only; the sim emits nothing new.

## The whoosh leads the strike by this many ticks (the motion is already under way).
const LEAD_TICKS := 2
## A same-kind view rewinding to at most this tick is a fresh swing (a repeat); a rewind further
## along is a rollback mid-swing and stays quiet (matches SwingDriver.RESTART_TICKS).
const RESTART_TICKS := 2
const MELEE: Array[int] = [AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2, AttackSet.Kind.LIGHT_3,
		AttackSet.Kind.HEAVY]
const ITEMS: Array[int] = [AttackSet.Kind.BAT, AttackSet.Kind.HAMMER]


## {"type": "swing", "id", "pos", "style", "kind"} when this tick's view crosses the whoosh tick
## of a swing, else {}.
static func detect(a: Dictionary, b: Dictionary, config: GameConfig) -> Dictionary:
	if int(b.get("state", -1)) != Fighter.State.ATTACK:
		return {}
	var kind := int(b.get("attack_kind", -1))
	var style := String(b.get("style", ""))
	if not (ITEMS.has(kind) or (MELEE.has(kind) and style != StyleCatalog.RANGED)):
		return {}
	var ticks := int(b.get("attack_ticks", 0))
	var before := 0
	if int(a.get("state", -1)) == Fighter.State.ATTACK and int(a.get("attack_kind", -1)) == kind:
		before = int(a.get("attack_ticks", 0))
		if before > ticks:
			if ticks > RESTART_TICKS:
				return {}  # a rollback rewound mid-swing: the whoosh already played
			before = 0
	var at := fire_tick(style, kind, config)
	if before >= at or ticks < at:
		return {}
	return {"type": "swing", "id": int(b["id"]), "pos": b["pos"], "style": style, "kind": kind}


## The attack tick the whoosh plays on for style's kind.
static func fire_tick(style: String, kind: int, config: GameConfig) -> int:
	return maxi(_table(style, config).get_attack(kind).startup_ticks + 1 - LEAD_TICKS, 1)


## Built per call (only on a melee ATTACK tick) so debug-panel tuning applies at once, as the sim's
## own AttackSet.from_config does.
static func _table(style: String, config: GameConfig) -> AttackSet:
	var id := style if not style.is_empty() else StyleCatalog.CLASSIC
	return StyleCatalog.attacks(id, config, AttackSet.from_config(config))
