extends Node
## Analytics autoload (platform A2, PRD-DATA-03): the game's single entry point for Amplitude.
## Live only when the game runs with a display outside tests and an Amplitude key is set;
## otherwise it still validates every event (invalid ones fail tests) and drops it.

var _client: AnalyticsClient = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not PlatformEnv.is_live():
		return
	var secrets := Secrets.load_from()
	if not secrets.has_analytics():
		push_warning("Analytics: disabled — amplitude.api_key missing")
		return
	_client = AnalyticsClient.new(secrets.amplitude_api_key, DeviceId.load_or_create(),
			GodotHttpTransport.new(self), BatchQueue.new())
	_client.context = PlatformEnv.amplitude_context()
	var screen := UiScale.tracking(DisplayProbe.profile())  # UiScaler keeps these current later
	for key: String in screen:
		_client.set_super_property(key, screen[key])
	track("app_opened")
	_client.flush()


func is_enabled() -> bool:
	return _client != null


func track(event_name: String, props: Dictionary = {}) -> void:
	if _client != null:
		_client.track(event_name, props)
		return
	var errors := EventCatalog.validate(event_name, props)
	if not errors.is_empty():
		AnalyticsClient.report_invalid(errors)


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


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()


func _notification(what: int) -> void:
	if _client == null:
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			track("app_closed")
			flush()
		NOTIFICATION_APPLICATION_PAUSED:
			track("app_backgrounded")
			flush()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if PlatformEnv.kind() != "desktop":
				track("app_backgrounded")
				flush()
