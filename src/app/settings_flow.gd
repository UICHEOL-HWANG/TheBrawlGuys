class_name SettingsFlow
extends RefCounted
## The title's 설정: the SettingsScreen pushed over the title; 뒤로 / Esc pops back to it.

const SETTINGS := "settings"


static func open(router: ScreenRouter, config: GameConfig) -> void:
	if router.is_busy() or router.current_id() == SETTINGS:
		return
	var screen := SettingsScreen.new()
	screen.config = config
	screen.cancelled.connect(func() -> void: router.pop())
	router.push(SETTINGS, screen)
