class_name TutorialLauncher
extends RefCounted
## Builds the tutorial scene for the app shell (Phase 5 T11): where it came from (first_login /
## replay), the progress it marks, the analytics sink and what to do when the player leaves.

const SCENE := preload("res://src/tutorial/tutorial_match.tscn")


static func scene(source: String, progress: TutorialProgress, track: Callable, on_leave: Callable) -> Node:
	var node := SCENE.instantiate()
	node.set("source", source)
	node.set("progress", progress)
	node.set("track", track)
	node.connect("menu_requested", on_leave)
	return node
