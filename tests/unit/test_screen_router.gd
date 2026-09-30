extends GutTest
## ScreenRouter (platform B1): the app's screen stack, screen_viewed tracking and curtain swaps.

var _router: ScreenRouter
var _world: Node
var _tracked: Array = []
var _now: int = 0


func before_each() -> void:
	_tracked.clear()
	_now = 1000
	_world = Node.new()
	add_child_autofree(_world)
	_router = ScreenRouter.new()
	_router.animate = false
	_router.world_parent = _world
	_router.track = func(n: String, p: Dictionary) -> void: _tracked.append([n, p])
	_router.clock_ms = func() -> int: return _now
	add_child_autofree(_router)


func _screen() -> Control:
	return Control.new()


func test_push_and_pop_track_screen_viewed() -> void:
	var login := _screen()
	_router.push("login", login)
	assert_eq(_router.current_id(), "login")
	assert_eq(_tracked[0], ["screen_viewed", {"screen": "login", "from_screen": "", "dwell_ms_prev": 0}])
	_now += 250
	var title := _screen()
	_router.push("title", title)
	assert_false(login.visible, "the covered screen hides")
	assert_eq(_tracked[1][1], {"screen": "title", "from_screen": "login", "dwell_ms_prev": 250})
	_router.pop()
	assert_eq(_router.current_id(), "login")
	assert_true(login.visible)
	await wait_process_frames(1)
	assert_false(is_instance_valid(title), "popped screens are freed")


func test_replace_and_reset() -> void:
	var login := _screen()
	_router.push("login", login)
	_router.replace("title", _screen())
	assert_eq(_router.depth(), 1)
	assert_eq(_router.current_id(), "title")
	_router.push("match", Node3D.new())
	_router.reset("login", _screen())
	assert_eq(_router.depth(), 1)
	assert_eq(_router.current_id(), "login")
	await wait_process_frames(1)
	assert_false(is_instance_valid(login))


func test_non_control_screens_live_in_the_world() -> void:
	_router.push("title", _screen())
	var match_node := Node3D.new()
	_router.push("match", match_node)
	assert_eq(match_node.get_parent(), _world)


func test_on_swap_runs_between_screens() -> void:
	_router.push("title", _screen())
	var order: Array[String] = []
	_router.push("match", Node3D.new(), true, func() -> void: order.append(_router.current_id()))
	assert_eq(order, ["title"], "on_swap runs before the new screen is added")
	_router.pop(true, func() -> void: order.append(_router.current_id()))
	assert_eq(order, ["title", "match"])


func test_curtain_swaps_after_covering_the_screen() -> void:
	_router.animate = true
	_router.push("title", _screen())
	_router.push("match", Node3D.new(), true)
	assert_eq(_router.current_id(), "title", "the swap waits for the curtain")
	assert_true(_router.is_busy())
	await wait_seconds(UiMotion.duration(UiMotion.Token.SLOW) + UiMotion.duration(UiMotion.Token.BASE) + 0.3)
	assert_eq(_router.current_id(), "match")
	assert_false(_router.is_busy())
	assert_false(_router.curtain().visible)
