class_name Gimmick
extends RefCounted
## Base for arena gimmicks (PRD-ARENA-01~04). A gimmick is deterministic: it reads only the
## GimmickContext (fighters, arena, config, tick, this tick's events) and its own state, which
## to_data / load_data carry through World snapshots. Subclasses override kind, step, copy and
## the state hooks; area is the gimmick's shape on the arena (null for arena-wide effects).

var id: int = 0
var area: ArenaShape = null


func kind() -> String:
	return ""


## Per-match setup from the config (schedules). Called once when the World is built.
func start(_config: GameConfig) -> void:
	pass


## One tick; returns the events it produced.
func step(_ctx: GimmickContext) -> Array[Dictionary]:
	return []


func copy() -> Gimmick:
	push_error("Gimmick.copy: %s must override copy" % kind())
	return null


## Copies the shared fields into a fresh subclass instance (for copy overrides).
func copy_base_into(g: Gimmick) -> Gimmick:
	g.id = id
	g.area = area.copy() if area != null else null
	return g


func to_data() -> Dictionary:
	return {}


func load_data(_d: Dictionary) -> bool:
	return true


## Plain values for the render layer: kind, id, area and the subclass state (view_state).
func to_view() -> Dictionary:
	var v := {"kind": kind(), "id": id}
	if area != null:
		v["pos"] = area.center
		v["area"] = area.to_view()
	v.merge(view_state())
	return v


func view_state() -> Dictionary:
	return {}
