class_name ProjectileField
extends RefCounted
## Every projectile in flight, in spawn order, plus the next id (snapshot state).

var list: Array[Projectile] = []
var next_id: int = 0


## Spawns `attack`'s projectile from fighter f's hand, flying along its facing.
func fire(f: Fighter, attack: AttackData, attack_kind: int, power: float, config: GameConfig) -> Projectile:
	var p := Projectile.new()
	p.id = next_id
	next_id += 1
	p.owner_id = f.id
	p.kind = attack.projectile_kind
	p.attack_kind = attack_kind
	p.radius = attack.projectile_radius
	p.pos = f.pos + Vector3.UP * attack.hitbox_up + f.facing * (config.fighter_radius + p.radius)
	p.vel = f.facing * attack.projectile_speed
	p.ticks_left = attack.projectile_ticks
	p.power = power
	list.append(p)
	return p


func views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Projectile in list:
		out.append(p.to_view())
	return out


func to_data() -> Dictionary:
	var data: Array[Dictionary] = []
	for p: Projectile in list:
		data.append(p.to_data())
	return {"list": data, "next_id": next_id}


static func from_data(d: Dictionary) -> ProjectileField:
	if typeof(d.get("list")) != TYPE_ARRAY or typeof(d.get("next_id")) != TYPE_INT:
		return null
	var field := ProjectileField.new()
	for raw: Variant in d["list"]:
		var p: Projectile = Projectile.from_data(raw) if raw is Dictionary else null
		if p == null:
			return null
		field.list.append(p)
	field.next_id = d["next_id"]
	return field
