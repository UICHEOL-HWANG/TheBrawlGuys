class_name FighterHazards
extends Node3D
## Arena hazard visuals on one fighter, drawn by MatchStage next to its FighterView: flames while
## the sim says the fighter is burning (BurnFlames) and its silhouette over the fog while the fog
## is in (FogSilhouette). Hidden while the fighter is KO. Reads view values only.

var _burn: BurnFlames
var _silhouette: FogSilhouette
## The menu backdrop hides player identity (no colored silhouettes there).
var _identity: bool = true


func setup(index: int, config: GameConfig) -> void:
	_burn = BurnFlames.new()
	add_child(_burn)
	_burn.setup(config)
	_silhouette = FogSilhouette.new()
	add_child(_silhouette)
	_silhouette.setup(index, config)


## fighter: the fighter's latest view; at: its drawn position; fog: the arena fog amount 0..1.
func apply(fighter: Dictionary, at: Vector3, fog: float) -> void:
	var alive := int(fighter.get("state", Fighter.State.IDLE)) != Fighter.State.KO
	position = at
	_burn.set_burning(alive and bool(fighter.get("burning", false)))
	_silhouette.set_amount(fog if alive and _identity else 0.0)


func set_identity_visible(on: bool) -> void:
	_identity = on


func burning() -> bool:
	return _burn.visible


func silhouette() -> FogSilhouette:
	return _silhouette
