class_name DsGalleryBasics
extends RefCounted
## The DS gallery's static sections (split out of ds_gallery.gd, unchanged): headings, the
## palette, the type scale, the soft-toon sample, the registered components with the TouchButton
## states, and the shared preview viewport and button helpers.

const SWATCH_SIZE := Vector2(120, 64)
const SWATCH_COLUMNS := 7
const PREVIEW_SIZE := Vector2i(560, 360)


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_TITLE)
	return l


static func swatches() -> Control:
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


static func type_scale() -> Control:
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


static func toon_preview() -> Control:
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


static func components(components: Array[Array]) -> Control:
	var box := VBoxContainer.new()
	if components.is_empty():
		var l := Label.new()
		l.text = "등록된 컴포넌트 없음 — Phase 1부터 DamageCounter, StockIcons, TouchStick…"
		l.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
		box.add_child(l)
		return box
	for entry: Array in components:
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
	box.add_child(touch_button_states())
	return box


static func touch_button_states() -> Control:
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


static func preview_viewport(size: Vector2i) -> Array:
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


static func button(label: String, node_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.name = node_name
	b.pressed.connect(on_press)
	return b
