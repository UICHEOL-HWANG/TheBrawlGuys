class_name SettingsFlow
extends RefCounted
## The title's 설정: the SettingsScreen pushed over the title; 뒤로 / Esc pops back to it.

const SETTINGS := "settings"


## track: the app's analytics sink (null keeps the screen's default).
static func open(router: ScreenRouter, config: GameConfig, track: Variant = null) -> void:
	if router.is_busy() or router.current_id() == SETTINGS:
		return
	var screen := SettingsScreen.new()
	screen.config = config
	if track is Callable:
		screen.track = track
	screen.cancelled.connect(func() -> void: router.pop())
	router.push(SETTINGS, screen)
