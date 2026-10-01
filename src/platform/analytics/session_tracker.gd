class_name SessionTracker
extends RefCounted
## One app session's product signals (platform A8, analytics-strategy §3.3/§3.4). The Analytics
## autoload shows it every tracked event: it counts matches, remembers the last screen, keeps the
## session's loss streak and derives load timings from screen changes (boot → first login screen,
## first login screen → first title). observe() returns follow-up events to send.

## Back from the background after this long, the app starts a new Amplitude session
## (tracking-plan §2 session_id).
const SESSION_TIMEOUT_MS := 30 * 60 * 1000

## Monotonic ms since engine start (boot time for boot_to_login).
var clock_ms: Callable = Time.get_ticks_msec
var matches: int = 0
var last_screen: String = ""
var loss_streak: int = 0

var _started_ms: int = 0
var _login_shown_ms: int = -1
var _boot_timed: bool = false
var _title_timed: bool = false


func start() -> void:
	_started_ms = int(clock_ms.call())


## Returns [[event_name, props], ...] to send after this event.
func observe(event_name: String, props: Dictionary) -> Array:
	match event_name:
		"screen_viewed":
			return _on_screen(String(props.get("screen", "")))
		"match_started":
			matches += 1
		"match_ended":
			loss_streak = loss_streak + 1 if props.get("result") == "loss" else 0
	return []


## True when an app that was in the background for away_ms needs a new Amplitude session.
static func is_new_session(away_ms: int) -> bool:
	return away_ms >= SESSION_TIMEOUT_MS


## session_ended properties.
func end_props() -> Dictionary:
	var seconds := (int(clock_ms.call()) - _started_ms) / 1000.0
	return {"duration_s": snappedf(seconds, 0.01), "matches": matches, "last_screen": last_screen}


func _on_screen(screen: String) -> Array:
	last_screen = screen
	var now := int(clock_ms.call())
	if screen == "login" and not _boot_timed:
		_boot_timed = true
		_login_shown_ms = now
		return [["load_timed", {"stage": "boot_to_login", "ms": now}]]
	if screen == "title" and not _title_timed and _login_shown_ms >= 0:
		_title_timed = true
		return [["load_timed", {"stage": "login_to_title", "ms": now - _login_shown_ms}]]
	return []
