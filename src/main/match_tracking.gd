class_name MatchTracking
extends RefCounted
## Telemetry wiring of one match scene (platform A6/B1): a MatchTelemetry per match built from the
## MatchSetup, fed once per tick, ended on match over (flush + Supabase upload), on restart
## (abandoned, or rematch_clicked after the result) and when the scene leaves the tree.

var _track: Callable
var _recorder: MatchRecorder
var _telemetry: MatchTelemetry = null


func _init(track: Callable, recorder: MatchRecorder) -> void:
	_track = track
	_recorder = recorder


func telemetry() -> MatchTelemetry:
	return _telemetry


func begin(setup: MatchSetup) -> void:
	_telemetry = MatchTelemetry.new(_track)
	_telemetry.begin(TelemetrySetup.from_match_setup(setup))


func on_tick(events: Array, view_events: Array, view: Dictionary) -> void:
	if _telemetry != null:
		_telemetry.on_frame(events, view_events, view)


func finish(view: Dictionary) -> void:
	if _telemetry == null:
		return
	_telemetry.end(view)
	Analytics.flush()
	_recorder.record(_telemetry)


## Restart: an unfinished match is abandoned; after the result it is a rematch.
func close_for_restart(view: Dictionary, result_shown: bool) -> void:
	if _telemetry == null:
		return
	if _telemetry.is_active():
		_telemetry.end(view, true)
	elif result_shown:
		_track.call("rematch_clicked", {"match_id": _telemetry.match_id()})


## Leaving the scene (menu, quit) mid-match abandons it.
func close_for_exit(view: Dictionary) -> void:
	if _telemetry != null and _telemetry.is_active():
		_telemetry.end(view, true)
