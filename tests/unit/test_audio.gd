extends GutTest
## Buses and event -> sound mapping (design.md DS-SFX-01).


func test_buses_are_created_once() -> void:
	var c := GameConfig.new()
	AudioBuses.ensure(c)
	var count := AudioServer.bus_count
	AudioBuses.ensure(c)
	assert_eq(AudioServer.bus_count, count, "idempotent")
	for bus: String in [AudioBuses.SFX, AudioBuses.MUSIC, AudioBuses.UI]:
		var idx := AudioServer.get_bus_index(bus)
		assert_ne(idx, -1, bus)
		assert_eq(AudioServer.get_bus_send(idx), &"Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioBuses.MUSIC)), c.music_volume_db, 0.001)


func test_hits_pick_light_or_heavy_and_bend_pitch() -> void:
	var c := GameConfig.new()
	var soft := SfxDirector.sound_for({"type": "hit", "knockback": 2.0, "pos": Vector3.ZERO}, c)
	var hard := SfxDirector.sound_for({"type": "hit", "knockback": c.spark_large_threshold + 4.0, "pos": Vector3.ZERO}, c)
	assert_eq(soft["name"], "hit_light")
	assert_eq(hard["name"], "hit_heavy")
	assert_lt(float(hard["pitch"]), float(soft["pitch"]), "bigger knockback sounds lower")
	assert_between(float(hard["pitch"]), 0.7, 1.2)


func test_ringout_splashes_over_the_lake() -> void:
	var c := GameConfig.new()
	var lake := Vector3(c.arena_radius + DecorView.LAKE_OFFSET, -9, 0)
	assert_eq(SfxDirector.sound_for({"type": "ringout", "pos": lake, "id": 1}, c, true)["name"], "ringout_splash")
	assert_eq(SfxDirector.sound_for({"type": "ringout", "pos": -lake, "id": 1}, c, true)["name"], "ringout_whistle")


func test_view_events_and_items_have_sounds() -> void:
	var c := GameConfig.new()
	for pair: Array in [["landed", "land"], ["jumped", "jump"], ["respawned", "respawn"], ["guard_hit", "guard"],
			["item_pickup", "item_pickup"], ["item_throw", "item_throw"], ["explosion", "explosion"]]:
		var e := {"type": pair[0], "pos": Vector3.ZERO, "id": 0, "intensity": 1.0, "knockback": 0.0}
		assert_eq(SfxDirector.sound_for(e, c).get("name", ""), pair[1], String(pair[0]))
	assert_true(SfxDirector.sound_for({"type": "grab", "pos": Vector3.ZERO}, c).is_empty(), "silent events map to {}")


func test_director_plays_through_a_voice_pool() -> void:
	var d := SfxDirector.new()
	add_child_autofree(d)
	d.setup(GameConfig.new())
	assert_eq(d.voices(), SfxDirector.VOICES)
	assert_eq(d.next_voice(), 0)
	assert_null(d.voice_stream(0), "no voice has a stream before the first play")
	for i: int in SfxDirector.VOICES + 3:
		d.play("hit_light")
	for i: int in SfxDirector.VOICES:
		assert_not_null(d.voice_stream(i), "voice %d was used" % i)
	assert_eq(d.next_voice(), 3, "the round-robin wrapped past the last voice")
