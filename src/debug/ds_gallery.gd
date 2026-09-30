extends Control
## Design system gallery (design.md DS-GOV-02). Every token, component, shader sample, VFX and SFX is shown here.
## Run: godot --path . res://src/debug/ds_gallery.tscn

const SWATCH_SIZE := Vector2(120, 64)
const SWATCH_COLUMNS := 7
const PREVIEW_SIZE := Vector2i(560, 360)
## Registered components: [display name, scene path]. Phase 1 adds DamageCounter, StockIcons, ...
const COMPONENTS: Array[Array] = [
	["DamageCounter · DS-CMP-01", "res://src/ui/components/damage_counter/damage_counter.tscn"],
	["StockIcons · DS-CMP-02", "res://src/ui/components/stock_icons/stock_icons.tscn"],
	["ResultBanner · DS-CMP-09", "res://src/ui/components/result_banner/result_banner.tscn"],
	["TouchStick · DS-CMP-03", "res://src/ui/components/touch_stick/touch_stick.tscn"],
	["TouchButton v2 · DS-CMP-04", "res://src/ui/components/touch_button/touch_button.tscn"],
	["ChargeGauge · DS-CMP-05", "res://src/ui/components/charge_gauge/charge_gauge.tscn"],
	["MenuButton · DS-CMP-06", "res://src/ui/components/menu_button/menu_button.tscn"],
	["Panel · DS-CMP-07", "res://src/ui/components/panel/panel.tscn"],
	["CrestLogo · DS-CMP-15", "res://src/ui/components/crest_logo/crest_logo.tscn"],
	["LoginPanel · DS-CMP-14", "res://src/ui/components/login_panel/login_panel.tscn"],
	["KeyHintBar · DS-CMP-16", "res://src/ui/components/key_hint_bar/key_hint_bar.tscn"],
	["SelectCard · DS-CMP-08", "res://src/ui/components/select_card/select_card.tscn"],
	["TextField · DS-CMP-17", "res://src/ui/components/text_field/text_field.tscn"],
	["CodeInput · DS-CMP-18", "res://src/ui/components/code_input/code_input.tscn"],
]
## Pass `--components-only` after `--` to render just the components section (evidence capture).
const COMPONENTS_ONLY_ARG := "--components-only"
## Pass `--items-only` after `--` to render just the items preview (evidence capture).
const ITEMS_ONLY_ARG := "--items-only"
## Capture-only section switches, same idea as --items-only.
const VFX_ONLY_ARG := "--vfx-only"
const AUDIO_ONLY_ARG := "--audio-only"
const CHARACTERS_ONLY_ARG := "--characters-only"
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


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = DS.UI_SURFACE_DIM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.S7)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S6)
	margin.add_child(col)

	var config := GameConfig.new()
	_sfx = SfxDirector.new()
	add_child(_sfx)
	_sfx.setup(config)
	_music = MusicDirector.new()
	add_child(_music)
	_music.setup(config)

	var args := OS.get_cmdline_user_args()
	if args.has(CHARACTERS_ONLY_ARG):
		col.add_child(_heading("Characters · DS-VIS-02"))
		col.add_child(_characters_preview())
		return
	if args.has(VFX_ONLY_ARG):
		col.add_child(_heading("VFX · DS-VFX-01~06"))
		col.add_child(_vfx_preview())
		return
	if args.has(AUDIO_ONLY_ARG):
		col.add_child(_heading("SFX · DS-SFX-01 / BGM · DS-SFX-02"))
		col.add_child(_audio_preview())
		return
	if args.has(ITEMS_ONLY_ARG):
		col.add_child(_heading("Items · DS-VIS-05 (crate + shadow / bat fresh·cracked / bomb unlit·lit / rock resting·tumbling)"))
		col.add_child(_items_preview())
		return
	if not args.has(COMPONENTS_ONLY_ARG):
		col.add_child(_heading("Palette · DS-TOK-01 (A 한낮 햇살)"))
		col.add_child(_swatches())
		col.add_child(_heading("Typography · DS-TOK-02"))
		col.add_child(_type_scale())
		col.add_child(_heading("Soft toon · DS-VIS-01 / DS-VIS-02"))
		col.add_child(_toon_preview())
		col.add_child(_heading("Items · DS-VIS-05 (crate + shadow / bat fresh·cracked / bomb unlit·lit / rock resting·tumbling)"))
		col.add_child(_items_preview())
		col.add_child(_heading("Characters · DS-VIS-02"))
		col.add_child(_characters_preview())
		col.add_child(_heading("VFX · DS-VFX-01~06"))
		col.add_child(_vfx_preview())
		col.add_child(_heading("SFX · DS-SFX-01 / BGM · DS-SFX-02"))
		col.add_child(_audio_preview())
	col.add_child(_heading("Components · DS-CMP"))
	col.add_child(_components())


func _process(delta: float) -> void:
	for a: CharacterAnimator in _animators:
		a.apply(IDLE_VIEW, delta)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_TITLE)
	return l


func _swatches() -> Control:
	var grid := GridContainer.new()
	grid.columns = SWATCH_COLUMNS
	grid.add_theme_constant_override("h_separation", DS.S3)
	grid.add_theme_constant_override("v_separation", DS.S3)
	for key: String in DS.PALETTE:
		var color: Color = DS.PALETTE[key]
		var cell := VBoxContainer.new()
		var chip := ColorRect.new()
		chip.color = color
		chip.custom_minimum_size = SWATCH_SIZE
		cell.add_child(chip)
		var label := Label.new()
		label.text = "%s\n#%s" % [key, color.to_html(false)]
		label.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
		cell.add_child(label)
		grid.add_child(cell)
	return grid


func _type_scale() -> Control:
	var box := VBoxContainer.new()
	var display := load(DS.FONT_DISPLAY_PATH) as Font
	var caption := load(DS.FONT_CAPTION_PATH) as Font
	var rows: Array[Array] = [
		["display_xl 118%", display, DS.SIZE_DISPLAY_XL],
		["display_l 승리!", display, DS.SIZE_DISPLAY_L],
		["title 호숫가 캠프장", display, DS.SIZE_TITLE],
		["body 상자가 떨어지면 먼저 주워라", null, DS.SIZE_BODY],
		["caption 핑 42ms", caption, DS.SIZE_CAPTION],
	]
	for row: Array in rows:
		var l := Label.new()
		l.text = row[0]
		if row[1] != null:
			l.add_theme_font_override("font", row[1])
		l.add_theme_font_size_override("font_size", row[2])
		box.add_child(l)
	return box


func _toon_preview() -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	var vp := SubViewport.new()
	vp.size = PREVIEW_SIZE
	vp.own_world_3d = true
	container.add_child(vp)

	var env := EnvironmentRig.new()
	vp.add_child(env)
	env.setup()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = ToonMaterials.toon(DS.GRASS)
	vp.add_child(ground)
	var bush := SphereCluster.new()
	vp.add_child(bush)
	bush.setup(DS.GRASS_MID, 1.2, 1)
	bush.position = Vector3(-2.2, 0, 0)
	var tree := SphereCluster.new()
	vp.add_child(tree)
	tree.setup(DS.CANOPY, 1.3, 2, 1.2)
	tree.position = Vector3(2.2, 0, -0.5)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = ToonMaterials.toon(DS.P1, 0.35)
	ball.position = Vector3(0, 0.5, 1.5)
	vp.add_child(ball)

	var cam := Camera3D.new()
	vp.add_child(cam)
	# look_at() requires being inside the live SceneTree; this SubViewport subtree
	# isn't attached yet at this point (the caller adds `container` afterward), so
	# use the position-taking variant Godot 4.7 itself suggests in that error.
	cam.look_at_from_position(Vector3(0, 7, 7), Vector3.ZERO, Vector3.UP)
	return container


func _components() -> Control:
	var box := VBoxContainer.new()
	if COMPONENTS.is_empty():
		var l := Label.new()
		l.text = "등록된 컴포넌트 없음 — Phase 1부터 DamageCounter, StockIcons, TouchStick…"
		l.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
		box.add_child(l)
		return box
	for entry: Array in COMPONENTS:
		var title := Label.new()
		title.text = entry[0]
		box.add_child(title)
		var node := (load(entry[1]) as PackedScene).instantiate()
		box.add_child(node)
		if node.has_method("set_preview"):
			node.call("set_preview")
	var states_title := Label.new()
	states_title.text = "TouchButton v2 states · idle / pressed / highlight / disabled / charging"
	box.add_child(states_title)
	box.add_child(_touch_button_states())
	return box


func _touch_button_states() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S5)
	var scene := load("res://src/ui/components/touch_button/touch_button.tscn") as PackedScene
	var icons := [TouchIcons.Icon.ATTACK, TouchIcons.Icon.JUMP, TouchIcons.Icon.GRAB, TouchIcons.Icon.GUARD, TouchIcons.Icon.ATTACK]
	var states := [TouchButton.State.IDLE, TouchButton.State.PRESSED, TouchButton.State.HIGHLIGHT,
			TouchButton.State.DISABLED, TouchButton.State.CHARGING]
	for i: int in states.size():
		var b := scene.instantiate() as TouchButton
		b.icon = icons[i]
		row.add_child(b)
		b.set_state(states[i])
		b.set_charge(0.6)
	return row


func _items_preview() -> Control:
	var made := _preview_viewport(PREVIEW_SIZE)
	var vp := made[1] as SubViewport
	var lineup := ItemLineup.new()
	vp.add_child(lineup)
	lineup.setup(GameConfig.new())
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.5, 6.5), Vector3(0, 0.4, 0), Vector3.UP)
	return made[0] as Control


func _preview_viewport(size: Vector2i) -> Array:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(size)
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	container.add_child(vp)
	var env := EnvironmentRig.new()
	vp.add_child(env)
	env.setup()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = ToonMaterials.toon(DS.GRASS)
	vp.add_child(ground)
	return [container, vp]


func _button(label: String, node_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.name = node_name
	b.pressed.connect(on_press)
	return b


func _characters_preview() -> Control:
	var box := VBoxContainer.new()
	var made := _preview_viewport(CHARACTER_PREVIEW_SIZE)
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
		row.add_child(_button("Look %s" % "ABC"[n], "look_" + "abc"[n], func() -> void: LookPreset.apply(look)))
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


func _vfx_preview() -> Control:
	var box := VBoxContainer.new()
	var made := _preview_viewport(PREVIEW_SIZE)
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
		row.add_child(_button(k[0], "vfx_" + String(k[1]), k[2]))
	box.add_child(row)
	return box


## Adds an effect node to the preview stage and returns it typed as its own class via duck typing.
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


func _audio_preview() -> Control:
	var box := VBoxContainer.new()
	var grid := HFlowContainer.new()
	for name: String in SfxRecipes.RECIPES:
		var recipe := name
		grid.add_child(_button(recipe, "sfx_" + recipe, func() -> void: _sfx.play(recipe)))
	box.add_child(grid)
	var bgm := HBoxContainer.new()
	bgm.add_child(_button("battle", "bgm_battle", _music.play_battle))
	bgm.add_child(_button("intense toggle", "bgm_intense", _toggle_intense))
	bgm.add_child(_button("menu", "bgm_menu", _music.play_menu))
	bgm.add_child(_button("stop", "bgm_stop", _music.stop))
	box.add_child(bgm)
	return box


func _toggle_intense() -> void:
	_intense_on = not _intense_on
	_music.update_from(INTENSE_VIEW if _intense_on else CALM_VIEW)
