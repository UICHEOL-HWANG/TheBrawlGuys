class_name DsGalleryPreviews
extends Node
## The DS gallery's live previews (split out of ds_gallery.gd, unchanged): items, the four
## characters idling, every VFX on a button, every SFX recipe and the BGM layers. Owns the
## preview stage and the idle animators (process() advances them).

const CHARACTER_PREVIEW_SIZE := Vector2i(1100, 400)
const CHARACTER_X: Array[float] = [-2.4, -0.8, 0.8, 2.4]
const TRAIL_SAMPLES := 6
const IDLE_VIEW := {"state": Fighter.State.IDLE, "on_ground": true, "attack_kind": -1, "item_kind": -1,
		"charge_ticks": 0, "hitstop_ticks": 0}
## Fake single-stock view that flips the BGM to its intense layer.
const INTENSE_VIEW := {"match_over": false, "fighters": [{"state": Fighter.State.IDLE, "stocks": 1}]}
const CALM_VIEW := {"match_over": false, "fighters": [{"state": Fighter.State.IDLE, "stocks": 3}]}

var _sfx: SfxDirector
var _music: MusicDirector
var _animators: Array[CharacterAnimator] = []
var _intense_on: bool = false
var _vfx_stage: Node3D
var _charge_glow: ChargeGlow
var _trail: KnockbackTrail


func setup(sfx: SfxDirector, music: MusicDirector) -> void:
	_sfx = sfx
	_music = music


func _process(delta: float) -> void:
	for a: CharacterAnimator in _animators:
		a.apply(IDLE_VIEW, delta)


func items_preview() -> Control:
	var made := DsGalleryBasics.preview_viewport(DsGalleryBasics.PREVIEW_SIZE)
	var vp := made[1] as SubViewport
	var lineup := ItemLineup.new()
	vp.add_child(lineup)
	lineup.setup(GameConfig.new())
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.5, 6.5), Vector3(0, 0.4, 0), Vector3.UP)
	return made[0] as Control


func characters_preview() -> Control:
	var box := VBoxContainer.new()
	var made := DsGalleryBasics.preview_viewport(CHARACTER_PREVIEW_SIZE)
	var vp := made[1] as SubViewport
	box.add_child(made[0] as Control)
	# CharacterModel.setup needs the live tree, which this subtree joins only after we return.
	vp.ready.connect(_fill_characters.bind(vp))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 30.0
	cam.look_at_from_position(Vector3(0, 1.0, 4.4), Vector3(0, 0.9, 0), Vector3.UP)
	var row := HBoxContainer.new()
	for n: int in 3:
		var look := n
		row.add_child(DsGalleryBasics.button("Look %s" % "ABC"[n], "look_" + "abc"[n], func() -> void: LookPreset.apply(look)))
	box.add_child(row)
	return box


func _fill_characters(vp: SubViewport) -> void:
	var config := GameConfig.new()
	for i: int in CharacterCatalog.CHARACTERS.size():
		var model := CharacterModel.new()
		vp.add_child(model)
		if not model.setup(CharacterCatalog.CHARACTERS[i], config):
			continue
		model.position = Vector3(CHARACTER_X[i], 0, 0)
		var animator := CharacterAnimator.new()
		model.add_child(animator)
		animator.setup(model.animation_player(), config)
		_animators.append(animator)


func vfx_preview() -> Control:
	var box := VBoxContainer.new()
	var made := DsGalleryBasics.preview_viewport(DsGalleryBasics.PREVIEW_SIZE)
	var vp := made[1] as SubViewport
	box.add_child(made[0] as Control)
	_vfx_stage = Node3D.new()
	_vfx_stage.name = "vfx_stage"
	vp.add_child(_vfx_stage)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.5, 7), Vector3(0, 1.2, 0), Vector3.UP)
	var scale := Quality.particle_scale(GameConfig.new())
	var row := HBoxContainer.new()
	var kinds: Array[Array] = [
		["hit small", "hit_small", func() -> void: _spawn(HitSpark.new()).play(Vector3(0, 1, 0), false)],
		["hit large", "hit_large", func() -> void: _spawn(HitSpark.new()).play(Vector3(0, 1, 0), true)],
		["dust", "dust", func() -> void: _spawn(DustPuff.new()).play(Vector3.ZERO, 1.0, scale)],
		["trail", "trail", func() -> void: _play_trail(scale)],
		["splash", "splash", func() -> void: _spawn(RingoutBurst.new()).play(Vector3.ZERO, true, DS.P1, scale)],
		["star", "star", func() -> void: _spawn(RingoutBurst.new()).play(Vector3(0, 1, 0), false, DS.P2, scale)],
		["respawn", "respawn", func() -> void: _spawn(RespawnBeam.new()).play(Vector3(0, 4, 0))],
		["charge", "charge", func() -> void: _play_charge()],
	]
	for k: Array in kinds:
		row.add_child(DsGalleryBasics.button(k[0], "vfx_" + String(k[1]), k[2]))
	box.add_child(row)
	return box


func _spawn(effect: Node3D) -> Variant:
	_vfx_stage.add_child(effect)
	return effect


func _play_trail(scale: float) -> void:
	if _trail == null or not is_instance_valid(_trail):
		_trail = KnockbackTrail.new()
		_vfx_stage.add_child(_trail)
	for i: int in TRAIL_SAMPLES:
		_trail.add_sample(Vector3(-2.5 + i, 1.0, 0), 1.0, DS.P1, scale)


func _play_charge() -> void:
	if _charge_glow == null or not is_instance_valid(_charge_glow):
		_charge_glow = ChargeGlow.new()
		_vfx_stage.add_child(_charge_glow)
		_charge_glow.position = Vector3(0, 1, 0)
	_charge_glow.set_charge(1.0)


func audio_preview() -> Control:
	var box := VBoxContainer.new()
	var grid := HFlowContainer.new()
	for name: String in SfxDirector.sound_names():
		var recipe := name
		grid.add_child(DsGalleryBasics.button(recipe, "sfx_" + recipe, func() -> void: _sfx.play(recipe)))
	box.add_child(grid)
	var bgm := HBoxContainer.new()
	bgm.add_child(DsGalleryBasics.button("battle", "bgm_battle", _music.play_battle))
	bgm.add_child(DsGalleryBasics.button("intense toggle", "bgm_intense", _toggle_intense))
	bgm.add_child(DsGalleryBasics.button("menu", "bgm_menu", _music.play_menu))
	bgm.add_child(DsGalleryBasics.button("stop", "bgm_stop", _music.stop))
	box.add_child(bgm)
	return box


func _toggle_intense() -> void:
	_intense_on = not _intense_on
	_music.update_from(INTENSE_VIEW if _intense_on else CALM_VIEW)
