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
	["TouchButton v1 · DS-CMP-04", "res://src/ui/components/touch_button/touch_button.tscn"],
]
## Pass `--components-only` after `--` to render just the components section (evidence capture).
const COMPONENTS_ONLY_ARG := "--components-only"


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

	if not OS.get_cmdline_user_args().has(COMPONENTS_ONLY_ARG):
		col.add_child(_heading("Palette · DS-TOK-01 (A 한낮 햇살)"))
		col.add_child(_swatches())
		col.add_child(_heading("Typography · DS-TOK-02"))
		col.add_child(_type_scale())
		col.add_child(_heading("Soft toon · DS-VIS-01 / DS-VIS-02"))
		col.add_child(_toon_preview())
	col.add_child(_heading("Components · DS-CMP"))
	col.add_child(_components())


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
	return box
