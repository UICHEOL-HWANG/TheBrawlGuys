extends SceneTree
## Visual regression capture for the camp lobby; no account or network access.
var _args: Dictionary
var _screen: Control
var _frame := 0


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	process_frame.connect(_step)


func _step() -> void:
	_frame += 1
	if _frame == 1:
		if _args.has("ui-scale"):
			root.content_scale_factor = float(_args["ui-scale"])
		var backdrop := load("res://src/app/menu_backdrop/menu_backdrop.tscn").instantiate() as MenuBackdrop
		root.add_child(backdrop)
		var layer := CanvasLayer.new()
		root.add_child(layer)
		if String(_args.get("screen", "room")) == "result":
			var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
			root.add_child(hud)
			hud.call("setup", 2, 3)
			var banner: ResultBanner = hud.call("banner")
			banner.set_menu_available(true)
			banner.set_highlights(ResultHighlights.lines([
				{"slot": 0, "ringouts_scored": 3, "items_used": 2, "special_hits": 5}], [0]))
			if _args.has("challenges-demo"):
				var progress := BotProgress.new()
				var reward := progress.record(QuickMatchPrefs.new().build(1),
					{"match_over": true, "winner": 0}, "demo", [
					{"slot": 0, "ringouts_scored": 10, "special_hits": 20}])
				banner.set_highlights("P1 · 링아웃 10회 / 필살기 적중 20회\n" + reward)
				banner.set_progress(progress.summary(CharacterData.BARBARIAN))
			hud.call("show_result", 0, 0)
			root.gui_disable_input = true
			return
		var room := String(_args.get("screen", "room")) == "room"
		var file := "waiting_room_screen" if room else "title_screen"
		_screen = load("res://src/app/screens/%s.gd" % file).new() as Control
		if room:
			_screen.set("is_host", true)
			_screen.set("code", "CAMP42")
		if not room and _args.has("progress-demo"):
			var progress := BotProgress.new()
			var setup := QuickMatchPrefs.new().build(1)
			for i: int in 6:
				progress.record(setup, {"match_over": true, "winner": 0 if i % 3 != 0 else 1}, "demo-%d" % i)
			_screen.set("bot_progress", progress)
		layer.add_child(_screen)
		if room:
			var model := LobbyModel.new()
			model.add_human(1)
			model.add_human(2)
			model.set_name(1, "브롤왕")
			model.set_name(2, "숲지기")
			model.set_pick(1, CharacterData.KNIGHT, true)
			model.set_pick(2, CharacterData.MAGE, true)
			model.set_conn(2, LobbyModel.CONN_CONNECTED, 42)
			model.set_bots(true)
			model.rule = MatchRules.TEAM
			_screen.call("refresh", model, 1)
		Input.warp_mouse(Vector2.ZERO)
		root.gui_disable_input = true
	elif _frame == 100:
		var path := "%s/%s%s.png" % [_args["out-dir"], _args.get("screen", "room"), _args.get("tag", "")]
		quit(0 if CaptureArgs.save(root, path) == OK else 1)
