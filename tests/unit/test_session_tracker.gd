extends GutTest
## Session-level product signals (platform A8, analytics-strategy §3.3/§3.4): session length and
## matches, load timings derived from screen changes, session loss streak, install user properties.

var _now: int = 0
var _session: SessionTracker


func before_each() -> void:
	_now = 1000
	_session = SessionTracker.new()
	_session.clock_ms = func() -> int: return _now
	_session.start()


func test_boot_and_login_load_times_come_from_screen_changes() -> void:
	_now = 2500
	var first := _session.observe("screen_viewed", {"screen": "login"})
	assert_eq(first, [["load_timed", {"stage": "boot_to_login", "ms": 2500}]])
	_now = 9000
	var second := _session.observe("screen_viewed", {"screen": "title"})
	assert_eq(second, [["load_timed", {"stage": "login_to_title", "ms": 6500}]])
	_now = 12000
	assert_eq(_session.observe("screen_viewed", {"screen": "login"}), [], "only the first time per session")
	assert_eq(_session.observe("screen_viewed", {"screen": "title"}), [])


func test_session_end_summarises_the_session() -> void:
	_session.observe("screen_viewed", {"screen": "title"})
	_session.observe("match_started", {"match_id": "a"})
	_session.observe("match_started", {"match_id": "b"})
	_session.observe("screen_viewed", {"screen": "match"})
	_now = 61_000
	var p := _session.end_props()
	assert_almost_eq(float(p["duration_s"]), 60.0, 0.001)
	assert_eq(p["matches"], 2)
	assert_eq(p["last_screen"], "match")
	assert_eq(EventCatalog.validate("session_ended", p).size(), 0)


func test_loss_streak_counts_consecutive_losses() -> void:
	for r: String in ["loss", "loss"]:
		_session.observe("match_ended", {"result": r})
	assert_eq(_session.loss_streak, 2)
	_session.observe("match_abandoned", {})
	assert_eq(_session.loss_streak, 2, "an abandon keeps the streak")
	_session.observe("match_ended", {"result": "win"})
	assert_eq(_session.loss_streak, 0)


func test_install_info_is_written_once_and_tracks_the_primary_device() -> void:
	var path := "user://test_install.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var info := InstallInfo.new(path)
	var props := info.properties("2026-09-30T12:00:00Z", "0.4.0")
	assert_eq(props["first_seen_at"], "2026-09-30T12:00:00Z")
	assert_eq(props["install_build"], "0.4.0")
	var later := InstallInfo.new(path).properties("2027-01-01T00:00:00Z", "0.9.0")
	assert_eq(later["first_seen_at"], "2026-09-30T12:00:00Z", "first seen never moves")
	assert_eq(later["install_build"], "0.4.0")
	assert_eq(info.note_device("touch"), "touch")
	info.note_device("keyboard")
	assert_eq(info.note_device("keyboard"), "keyboard", "most matches win")
	assert_eq(InstallInfo.new(path).properties("x", "y")["input_device_primary"], "keyboard")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_perf_sampler_percentiles_and_spikes() -> void:
	var perf := PerfSampler.new()
	for i: int in 95:
		perf.add_frame(1.0 / 60.0)
	for i: int in 5:
		perf.add_frame(0.1)
	var p := perf.props()
	assert_eq(p["frame_count"], 100)
	assert_almost_eq(float(p["fps_p50"]), 60.0, 0.1)
	assert_almost_eq(float(p["fps_p5"]), 10.0, 0.1, "the slowest 5 % of frames")
	assert_eq(p["spike_count"], 5)
	assert_eq(PerfSampler.new().props()["frame_count"], 0)
