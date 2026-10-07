class_name RushStreak
extends Node3D
## Dash rush afterimages (combat-motion B2): while the Rogue rushes, a see-through body ghost in
## his color is left behind every few ticks with two white speed lines streaming back from it;
## each ghost thins and fades within LIFE. Pooled (the oldest ghost is reused).

const SLOTS := 10
const LIFE := 0.26
const GHOST_RADIUS := 0.34
const GHOST_HEIGHT := 1.5
const GHOST_ALPHA := 0.55
const LINE_LENGTH := 1.4
const LINE_WIDTH := 0.05
## Speed lines as (height, sideways offset) in m off the ghost's centre line.
const LINES := [Vector2(1.15, 0.22), Vector2(0.45, -0.25)]

var _slots: Array[Node3D] = []
var _ages: Array[float] = []
var _pool := FxPool.new(SLOTS)


func _init() -> void:
	for i: int in SLOTS:
		var slot := Node3D.new()
		add_child(slot)
		var cap := CapsuleMesh.new()
		cap.radius = GHOST_RADIUS
		cap.height = GHOST_HEIGHT
		var ghost := FxMaterials.attach(slot, cap, DS.WHITE, false, 0)
		ghost.position.y = GHOST_HEIGHT * 0.5
		for l: Vector2 in LINES:
			var box := BoxMesh.new()
			box.size = Vector3(LINE_WIDTH, LINE_WIDTH, LINE_LENGTH)
			var line := FxMaterials.attach(slot, box, DS.WHITE, false, 1)
			line.position = Vector3(l.y, l.x, LINE_LENGTH * 0.5)
		slot.visible = false
		_slots.append(slot)
		_ages.append(LIFE)


## A ghost at the feet `at`, facing `facing` (lines stream out behind), tinted `color`.
func emit(at: Vector3, facing: Vector3, color: Color) -> void:
	var i := _pool.acquire()
	var slot := _slots[i]
	slot.position = at
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() > 0.0001:
		slot.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	FxMaterials.tint(slot.get_child(0) as MeshInstance3D, color, GHOST_ALPHA)
	_ages[i] = 0.0
	slot.visible = true


func advance(delta: float) -> void:
	for i: int in SLOTS:
		var slot := _slots[i]
		if not slot.visible:
			continue
		_ages[i] += delta
		var t := _ages[i] / LIFE
		if t >= 1.0:
			slot.visible = false
			continue
		var ghost := slot.get_child(0) as MeshInstance3D
		ghost.scale = Vector3(lerpf(1.0, 0.5, t), 1.0, lerpf(1.0, 0.5, t))
		FxMaterials.set_alpha(ghost, GHOST_ALPHA * (1.0 - t))
		for c: int in range(1, slot.get_child_count()):
			FxMaterials.set_alpha(slot.get_child(c) as MeshInstance3D, 0.9 * (1.0 - t))


func stop_all() -> void:
	for slot: Node3D in _slots:
		slot.visible = false


func live_count() -> int:
	return _slots.filter(func(s: Node3D) -> bool: return s.visible).size()
