extends GutTest
## Match-scene telemetry wiring (platform A6/A7/A8): match load time, per-match perf sample, how
## long the result stays up and what the player does next, and the session context on the header.

var _sent: Array = []
var _now: int = 0
var _tracking: MatchTracking
var _world: World


func before_each() -> void:
	_sent.clear()
	_now = 100
	var track := func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s: %s" % [n, EventCatalog.validate(n, p)])
		_sent.append([n, p])
	var clock := func() -> int: return _now
	_tracking = MatchTracking.new(track, MatchRecorder.new(null), MatchCounter.new(""), clock)
	_world = World.new(GameConfig.new(), 1, 2)
	_tracking.begin(MatchSetup.vs_bots(), _world)


func _names() -> Array[String]:
	var out: Array[String] = []
	for s: Array in _sent:
		out.append(String(s[0]))
	return out


func _props(event_name: String) -> Dictionary:
	for s: Array in _sent:
		if s[0] == event_name:
			return s[1]
	return {}


func _tick() -> Dictionary:
	var inputs: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	_world.tick(inputs)
	var view := _world.state_view()
	_tracking.on_tick(view["events"], [], view, inputs)
	_tracking.on_frame_time(1.0 / 60.0)
	return view


func _finish() -> void:
	var view := _tick()
	view["match_over"] = true
	view["winner"] = 0
	_tracking.finish(view)


func test_first_tick_reports_the_match_load_time() -> void:
	_now = 850
	_tick()
	_tick()
	assert_eq(_names().count("load_timed"), 1)
	assert_eq(_props("load_timed"), {"stage": "match_load", "ms": 750})


func test_match_header_has_the_session_context() -> void:
	var started := _props("match_started")
	assert_eq(started["user_match_seq"], 1)
	assert_eq(started["loss_streak"], Analytics.loss_streak())
	_finish()
	var row := _tracking.telemetry().match_row()
	assert_eq(row["final_state_hash"], _world.state_hash())
	assert_eq(row["session_id"], Analytics.session_id())


func test_finish_sends_a_perf_sample_for_the_match() -> void:
	_finish()
	var perf := _props("perf_sampled")
	assert_eq(perf["match_id"], _tracking.telemetry().match_id())
	assert_eq(perf["frame_count"], 1)
	assert_gt(_names().find("perf_sampled"), _names().find("match_ended"))


func test_result_then_menu() -> void:
	_finish()
	_now += 4200
	_tracking.on_menu()
	_tracking.close_for_exit(_world.state_view())
	assert_eq(_names().count("result_viewed"), 1)
	assert_eq(_props("result_viewed")["next"], "menu")
	assert_eq(_props("result_viewed")["dwell_ms"], 4200)


func test_result_then_rematch() -> void:
	_finish()
	_now += 900
	_tracking.close_for_restart(_world.state_view(), true)
	assert_eq(_props("result_viewed")["next"], "rematch")
	assert_eq(_names().slice(-2), ["result_viewed", "rematch_clicked"])


func test_result_then_quit() -> void:
	_finish()
	_tracking.close_for_exit(_world.state_view())
	assert_eq(_props("result_viewed")["next"], "quit")


func test_leaving_mid_match_abandons_with_a_perf_sample_and_no_result() -> void:
	_tick()
	_tracking.close_for_exit(_world.state_view())
	assert_true(_names().has("match_abandoned"))
	assert_true(_names().has("perf_sampled"))
	assert_false(_names().has("result_viewed"))
