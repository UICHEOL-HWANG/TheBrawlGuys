extends GutTest
## Effectively endless stocks (the tutorial's practice arena refills to 99): the HUD shows one
## player marker and "∞" instead of the configured number of pips (design.md DS-CMP-02).

const STOCKS_SCENE := preload("res://src/ui/components/stock_icons/stock_icons.tscn")
const TUTORIAL_SCENE := preload("res://src/tutorial/tutorial_match.tscn")
const PROGRESS_PATH := "user://test_unlimited_stocks.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PROGRESS_PATH):
		DirAccess.remove_absolute(PROGRESS_PATH)


func _stocks() -> StockIcons:
	var s := STOCKS_SCENE.instantiate() as StockIcons
	add_child_autofree(s)
	s.setup(1, 3)
	return s


func _visible_markers(s: StockIcons) -> int:
	var n := 0
	for c: Node in s.get_children():
		if c is PlayerMarker and (c as PlayerMarker).visible:
			n += 1
	return n


func test_unlimited_shows_one_marker_and_infinity() -> void:
	var s := _stocks()
	assert_false(s.is_unlimited())
	assert_eq(s.infinity_text(), "", "counted stocks show no infinity sign")
	s.set_unlimited(true)
	assert_true(s.is_unlimited())
	assert_eq(_visible_markers(s), 1, "one marker keeps the player's color and shape")
	assert_eq(s.infinity_text(), StockIcons.INFINITY)
	s.set_stocks(97)
	assert_eq(_visible_markers(s), 1, "a refill or a ring-out changes nothing")
	assert_false((s.get_child(0) as PlayerMarker).is_dimmed())


func test_unlimited_can_be_turned_back_off() -> void:
	var s := _stocks()
	s.set_unlimited(true)
	s.set_unlimited(false)
	s.set_stocks(2)
	assert_eq(_visible_markers(s), 3)
	assert_eq(s.shown(), 2)
	assert_eq(s.infinity_text(), "")


func test_team_tint_reaches_the_unlimited_marker() -> void:
	var s := _stocks()
	s.set_unlimited(true)
	s.set_tint(PlayerStyle.team_color(0))
	assert_eq((s.get_child(0) as PlayerMarker).get("_tint"), PlayerStyle.team_color(0))


func test_hud_cards_switch_to_unlimited() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(2, 3)
	hud.set_unlimited_stocks()
	for i: int in 2:
		assert_true(hud.strip().cards[i].stock_icons().is_unlimited(), "P%d reads endless" % (i + 1))


func test_the_tutorial_practice_cards_read_unlimited() -> void:
	var scene := TUTORIAL_SCENE.instantiate()
	scene.set("progress", TutorialProgress.new(SettingsStore.new(PROGRESS_PATH)))
	scene.set("track", func(_n: String, _p: Dictionary) -> void: pass)
	add_child_autofree(scene)
	await wait_process_frames(3)
	var hud: Hud = scene.call("get_hud")
	for i: int in hud.strip().cards.size():
		assert_true(hud.strip().cards[i].stock_icons().is_unlimited(), "the 99-stock practice reads as endless")


func test_mirrored_cards_put_infinity_on_the_outside() -> void:
	var s := STOCKS_SCENE.instantiate() as StockIcons
	s.mirrored = true
	add_child_autofree(s)
	s.setup(1, 3)
	s.set_unlimited(true)
	assert_true(s.get_child(0) is Label, "right-hand cards: ∞ then the marker")
	assert_true(s.get_child(1) is PlayerMarker)
