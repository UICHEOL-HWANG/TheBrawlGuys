extends Node
## Analytics autoload (platform A2, PRD-DATA-03): the game's single entry point for Amplitude.
## Live only when the game runs with a display outside tests and an Amplitude key is set;
## otherwise it still validates every event (invalid ones fail tests) and drops it.
## A8: every tracked event also feeds the SessionTracker (session_started / session_ended,
## load_timed, the session loss streak) and install user properties (InstallInfo).

var _client: AnalyticsClient = null
## Offline runs still stamp matches with a per-run session id (epoch ms at startup).
var _offline_session_id: int = int(Time.get_unix_time_from_system() * 1000.0)
var _session := SessionTracker.new()
var _install: InstallInfo = null
var _session_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session.start()
	if not PlatformEnv.is_live():
		return
	var secrets := Secrets.load_from()
	if not secrets.has_analytics():
		push_warning("Analytics: disabled — amplitude.api_key missing")
		return
	_client = AnalyticsClient.new(secrets.amplitude_api_key, DeviceId.load_or_create(),
			GodotHttpTransport.new(self), BatchQueue.new())
	_client.context = PlatformEnv.amplitude_context()
	_client.set_super_property("event_schema_version", EventCatalog.SCHEMA_VERSION)
	_install = InstallInfo.new()
	var now_iso := Time.get_datetime_string_from_system(true) + "Z"
	_client.set_user_properties(_install.properties(now_iso, PlatformEnv.app_version()))
	track("app_opened")
	_start_session()
	_client.flush()


func is_enabled() -> bool:
	return _client != null


## Amplitude session id (epoch ms); matches rows carry it so both stores join.
func session_id() -> int:
	return _client.session_id if _client != null else _offline_session_id


## Consecutive losses of the local player in this app session (match_started.loss_streak).
func loss_streak() -> int:
	return _session.loss_streak


func track(event_name: String, props: Dictionary = {}) -> void:
	_send(event_name, props)
	for follow: Array in _session.observe(event_name, props):
		_send(String(follow[0]), follow[1])
	if event_name == "match_started" and _install != null:
		var primary := _install.note_device(String(props.get("input_device", "")))
		_client.set_user_properties({"input_device_primary": primary})


## Attach the Supabase user id (empty = logged out) to later events.
func identify(user_id: String, user_props: Dictionary = {}) -> void:
	if _client != null:
		_client.identify(user_id, user_props)


func set_super_property(key: String, value: Variant) -> void:
	if _client != null:
		_client.set_super_property(key, value)


## Send now and keep the rest on disk (match end, pause, quit).
func flush() -> void:
	if _client != null:
		_client.flush()
		_client.persist()


func _send(event_name: String, props: Dictionary) -> void:
	if _client != null:
		_client.track(event_name, props)
		return
	var errors := EventCatalog.validate(event_name, props)
	if not errors.is_empty():
		AnalyticsClient.report_invalid(errors)


## A fresh session (counts, loss streak, load timings) at launch and after a mobile resume.
func _start_session() -> void:
	if _session_open:
		return
	_session = SessionTracker.new()
	_session.start()
	_session_open = true
	track("session_started")


## session_ended once, when the app closes or is paused (mobile background).
func _end_session() -> void:
	if _session_open:
		_session_open = false
		track("session_ended", _session.end_props())


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()


func _notification(what: int) -> void:
	if _client == null:
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			track("app_closed")
			_end_session()
			flush()
		NOTIFICATION_APPLICATION_PAUSED:
			track("app_backgrounded")
			_end_session()
			flush()
		NOTIFICATION_APPLICATION_RESUMED:
			_start_session()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if PlatformEnv.kind() != "desktop":
				track("app_backgrounded")
				flush()
