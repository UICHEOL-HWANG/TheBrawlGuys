extends GutTest
## HUD portraits (design.md DS-CMP-22): s8 on an unscaled (desktop-class) canvas, where the slim
## strip has room for the GetAmped-style head that stands out past the card; s7 once the 2D canvas
## is enlarged for phones (DS-LAY-04), where every px of strip height costs fight view.


func test_diameter_per_ui_scale() -> void:
	assert_eq(HudStrip.portrait_diameter(1.0), DS.S8, "desktop and tablets keep the large head")
	assert_eq(HudStrip.portrait_diameter(1.65), DS.S7, "an enlarged phone canvas keeps the slim strip")


func test_badge_resizes_with_its_marker_in_the_corner() -> void:
	var b := PortraitBadge.new()
	add_child_autofree(b)
	b.setup(0, CharacterData.DEFAULT, null, PlayerStyle.color(0), false)
	b.set_diameter(DS.S8)
	assert_eq(b.custom_minimum_size, Vector2(DS.S8, DS.S8))
	assert_eq(b.diameter(), float(DS.S8))
	var marker := b.get_child(b.get_child_count() - 1) as PlayerMarker
	assert_eq(marker.position, Vector2(DS.S8 - PortraitBadge.BADGE, DS.S8 - PortraitBadge.BADGE))


func test_strip_cards_follow_the_ui_scale() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(2, 3)
	await wait_process_frames(1)
	var now := float(HudStrip.portrait_diameter(hud.get_tree().root.content_scale_factor))
	for c: PlayerCard in hud.strip().cards:
		assert_eq(c.portrait().diameter(), now, "built for the current canvas scale")
	hud.strip().set_ui_scale(1.0)
	for c: PlayerCard in hud.strip().cards:
		assert_eq(c.portrait().diameter(), float(DS.S8), "desktop")
	hud.strip().set_ui_scale(1.6)
	for c: PlayerCard in hud.strip().cards:
		assert_eq(c.portrait().diameter(), float(DS.S7), "phone")
