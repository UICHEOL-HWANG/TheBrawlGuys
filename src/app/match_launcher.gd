class_name MatchLauncher
extends RefCounted
## The match scene the app pushes (platform B1): main.tscn with its MatchSetup, the shared
## per-device BotProgress, the rematch seed source, the player's nickname and the 메뉴로 hook.

const MATCH_SCENE := preload("res://src/main/main.tscn")


static func scene(setup: MatchSetup, progress: BotProgress, new_seed: Callable, nickname: String,
		on_menu: Callable) -> Node:
	var match_scene := MATCH_SCENE.instantiate()
	match_scene.set("setup", setup)
	match_scene.set("bot_progress", progress)
	match_scene.set("menu_available", true)
	match_scene.set("new_seed", new_seed)
	match_scene.set("nickname", nickname)
	match_scene.connect("menu_requested", on_menu)
	return match_scene
