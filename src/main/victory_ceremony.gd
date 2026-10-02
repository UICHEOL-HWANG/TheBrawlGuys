class_name VictoryCeremony
extends RefCounted
## The winners' moment before the result banner (design.md GD-CAM-02): who cheers (the winner,
## or the winning team's fighters still in the arena), where the close shot looks and how far it
## zooms in. Pure reads of the final sim view; a draw has no one to cheer.

## One Cheer clip (1.67 s), then the banner comes up at the bottom.
const SECONDS := 1.7
const ZOOM_IN_S := 0.5
## Close shot on a lone winner; teammates standing apart get a wider one.
const CAMERA_WEIGHT := 0.85
const SPREAD_CLOSE := 2.0
const SPREAD_WIDE := 10.0
const WIDE_WEIGHT := 0.35
## Looks this far toward the camera from the winners, so they stand above the bottom banner.
const FRAME_LEAD := Vector3(0.0, 0.0, 1.6)


static func winners(view: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var winner := int(view.get("winner", Rules.DRAW))
	var fighters: Array = view.get("fighters", [])
	if winner < 0 or winner >= fighters.size():
		return out
	var mode: Dictionary = view.get("mode", {})
	var teams: Array = mode.get("teams", [])
	var team_rule := String(mode.get("rule", MatchRules.STOCK)) == MatchRules.TEAM
	if not team_rule or winner >= teams.size():
		if _standing(fighters[winner]):
			out.append(winner)
		return out
	var team := int(mode.get("winner_team", -1))
	if team < 0:
		team = int(teams[winner])
	for i: int in mini(teams.size(), fighters.size()):
		if int(teams[i]) == team and _standing(fighters[i]):
			out.append(i)
	return out


## The winners' middle on the arena floor, led toward the camera (FRAME_LEAD).
static func focus(view: Dictionary, slots: Array[int]) -> Vector3:
	if slots.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for i: int in slots:
		sum += view["fighters"][i]["pos"] as Vector3
	var at := sum / float(slots.size())
	at.y = maxf(at.y, DecorView.GROUND_Y)
	return at + FRAME_LEAD


## How close the shot gets (0 = match framing): eased in over ZOOM_IN_S, wider for spread teams.
static func camera_weight(view: Dictionary, slots: Array[int], elapsed: float) -> float:
	if slots.is_empty():
		return 0.0
	var center := focus(view, slots) - FRAME_LEAD
	var spread := 0.0
	for i: int in slots:
		spread = maxf(spread, ((view["fighters"][i]["pos"] as Vector3) - center).length() * 2.0)
	var t := clampf(inverse_lerp(SPREAD_CLOSE, SPREAD_WIDE, spread), 0.0, 1.0)
	var x := clampf(elapsed / ZOOM_IN_S, 0.0, 1.0)
	return lerpf(CAMERA_WEIGHT, WIDE_WEIGHT, t) * (1.0 - (1.0 - x) * (1.0 - x))


static func _standing(fighter: Dictionary) -> bool:
	return int(fighter.get("state", Fighter.State.IDLE)) != Fighter.State.KO
