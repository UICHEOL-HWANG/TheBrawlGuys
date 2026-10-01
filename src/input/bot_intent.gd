class_name BotIntent
extends RefCounted
## A bot's last decision for bot_intent tracking (PRD-BOT-04): the intent name BotController
## picked this tick, the nearest foe it looked at and that foe's distance. Read-only for the
## tracker (BotSquad samples it on change, rate-capped).

var name: String = "idle"
var target: int = -1
var dist: float = -1.0
## The target was attacking or charging within bot_guard_range (a threat the bot saw).
var threat: bool = false


## Records the target of this tick (an empty foe clears it).
func look(me: Dictionary, foe: Dictionary, guard_range: float) -> void:
	target = -1 if foe.is_empty() else int(foe["id"])
	dist = -1.0 if foe.is_empty() else BotViewQuery.flat(me["pos"], foe["pos"]).length()
	var s := -1 if foe.is_empty() else int(foe["state"])
	threat = dist >= 0.0 and dist <= guard_range and (s == Fighter.State.ATTACK or s == Fighter.State.CHARGE)


## Names the decision and passes its frame through.
func say(intent_name: String, frame: InputFrame) -> InputFrame:
	name = intent_name
	return frame


func to_dict() -> Dictionary:
	return {"intent": name, "target": target, "dist": snappedf(dist, 0.01), "threat": threat}
