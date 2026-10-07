class_name GrabFx
extends Node3D
## Grab readability (combat-motion B3): a GripPop on the victim when a grab connects, a pulsing
## band in the holder's color around the held fighter's chest while the hold lasts, and a whoosh
## ring when the holder throws. Fed sim events and fighter views; never writes to the sim.

const POPS := 4
## Band around the held fighter: radius (m), tube share, pulse (Hz, amount).
const BAND_RADIUS := 0.62
const BAND_THICKNESS := 0.22
const BAND_PULSE_HZ := 3.0
const BAND_PULSE := 0.12
const BAND_ALPHA := 0.8

var _pops: Array[GripPop] = []
var _pool := FxPool.new(POPS)
var _bursts: BurstPool
var _bands: Dictionary = {}
var _time: float = 0.0


func setup(bursts: BurstPool) -> void:
	_bursts = bursts
	for i: int in POPS:
		var p := GripPop.new()
		add_child(p)
		_pops.append(p)


func on_event(e: Dictionary) -> void:
	match String(e["type"]):
		"grab":
			var at: Vector3 = e["pos"]
			_pops[_pool.acquire()].play(at + Vector3.UP * BurstLooks.CHEST, PlayerStyle.color(int(e["attacker"])))
		"hit":
			if int(e.get("attack_kind", -1)) == AttackSet.Kind.THROW:
				var at: Vector3 = e["pos"]
				_bursts.play(at + Vector3.UP * BurstLooks.CHEST, BurstLooks.throw_whoosh(PlayerStyle.color(int(e["attacker"]))))


## Every frame: a band on each held fighter, in its holder's color.
func apply(fighters: Array) -> void:
	var held := {}
	for f: Dictionary in fighters:
		if int(f.get("state", Fighter.State.IDLE)) != Fighter.State.HELD:
			continue
		var id := int(f["id"])
		held[id] = true
		var band := _band(id)
		band.position = (f["pos"] as Vector3) + Vector3.UP * BurstLooks.CHEST
		band.scale = Vector3.ONE * BAND_RADIUS * (1.0 + BAND_PULSE * sin(_time * TAU * BAND_PULSE_HZ))
		FxMaterials.tint(band, PlayerStyle.color(int(f.get("partner_id", id))), BAND_ALPHA)
	for id: int in _bands.keys():
		(_bands[id] as MeshInstance3D).visible = held.has(id)


func advance(delta: float) -> void:
	_time += delta
	for p: GripPop in _pops:
		p.advance(delta)


func stop_all() -> void:
	for p: GripPop in _pops:
		p.advance(GripPop.LIFE)
	for id: int in _bands.keys():
		(_bands[id] as MeshInstance3D).visible = false


func active_pops() -> int:
	return _pops.filter(func(p: GripPop) -> bool: return p.active()).size()


func band_visible(id: int) -> bool:
	return _bands.has(id) and (_bands[id] as MeshInstance3D).visible


func _band(id: int) -> MeshInstance3D:
	if not _bands.has(id):
		_bands[id] = FxMaterials.ring(self, BAND_THICKNESS, DS.WHITE)
	return _bands[id]
