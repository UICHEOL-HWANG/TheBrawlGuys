class_name ChargeGaugeLayer
extends CanvasLayer
## One ChargeGauge per fighter, shown over its head while it charges a heavy attack (context E10).
## The caller passes the 3D -> screen projection (CameraRig.unproject) and, optionally, whether a
## point is on screen (CameraRig.sees) so gauges of fighters out of a close shot hide, not flicker.

const SCENE := preload("res://src/ui/components/charge_gauge/charge_gauge.tscn")
const LAYER := 4
## Metres above the top of the capsule.
const HEAD_GAP := 0.9

var _gauges: Dictionary = {}


func _ready() -> void:
	layer = LAYER


func update_from(view: Dictionary, config: GameConfig, project: Callable, sees: Callable = Callable()) -> void:
	var full := float(maxi(SimTime.to_ticks(config.heavy_charge_max_time), 1))
	for f: Dictionary in view["fighters"]:
		var g := gauge(int(f["id"]))
		var charging := int(f["state"]) == Fighter.State.CHARGE
		g.visible = charging
		if not charging:
			continue
		g.set_value(float(f["charge_ticks"]) / full)
		var head: Vector3 = (f["pos"] as Vector3) + Vector3.UP * (config.fighter_height + HEAD_GAP)
		if sees.is_valid() and not bool(sees.call(head)):
			g.visible = false
			continue
		var at: Vector2 = project.call(head)
		g.position = at - g.size * 0.5


func gauge(id: int) -> ChargeGauge:
	if not _gauges.has(id):
		var g := SCENE.instantiate() as ChargeGauge
		add_child(g)
		g.visible = false
		_gauges[id] = g
	return _gauges[id]
