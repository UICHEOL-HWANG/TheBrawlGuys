extends GutTest
## Character select rules (Phase 5 T9, PRD-LOCAL-01): each human moves an own cursor over the
## cards, confirms to lock it (ready) and cancels to unlock; cancelling while still choosing
## leaves the screen. The flow goes on only once every human is ready.

const M := preload("res://src/app/screens/character_select_model.gd")


func test_cursors_start_on_different_cards_and_wrap() -> void:
	var m := M.new([0, 1] as Array[int], 4)
	assert_eq([m.focus(0), m.focus(1)], [0, 1], "P1 and P2 do not start on the same card")
	assert_true(m.move(0, -1))
	assert_eq(m.focus(0), 3, "wraps to the last card")
	m.move(0, 1)
	assert_eq(m.focus(0), 0)
	assert_eq(m.browse(0), 2)
	assert_eq(m.browse(1), 0, "each seat counts its own browsing")


func test_single_player_confirms_straight_through() -> void:
	var m := M.new([0] as Array[int], 4)
	m.move(0, 1)
	assert_eq(m.confirm(0), M.ALL_READY)
	assert_eq(m.picks(), {0: 1})


func test_both_humans_must_be_ready() -> void:
	var m := M.new([0, 1] as Array[int], 4)
	assert_eq(m.confirm(0), M.READY, "P1 locks in and waits")
	assert_false(m.all_ready())
	assert_false(m.move(0, 1), "a ready cursor stays put")
	assert_eq(m.focus(0), 0)
	assert_eq(m.confirm(0), M.NONE, "confirming twice does nothing")
	assert_eq(m.confirm(1), M.ALL_READY)
	assert_eq(m.picks(), {0: 0, 1: 1})


func test_cancel_unreadies_first_then_leaves() -> void:
	var m := M.new([0, 1] as Array[int], 4)
	m.confirm(1)
	assert_eq(m.cancel(1), M.UNREADY, "P2 takes the pick back")
	assert_eq(m.state(1), M.CHOOSING)
	assert_true(m.move(1, 1), "and can browse again")
	assert_eq(m.cancel(1), M.NONE, "P2's cancel while choosing never leaves for both")
	assert_eq(m.cancel(0), M.BACK, "P1's cancel while choosing leaves the screen")


func test_both_humans_may_pick_the_same_card() -> void:
	var m := M.new([0, 1] as Array[int], 4)
	m.move(1, -1)
	assert_eq(m.seats_on(0), [0, 1] as Array[int])
	m.confirm(0)
	assert_eq(m.confirm(1), M.ALL_READY)
	assert_eq(m.picks(), {0: 0, 1: 0})


func test_pointing_moves_the_cursor_and_counts_as_browsing() -> void:
	var m := M.new([0] as Array[int], 4)
	assert_true(m.point(0, 2))
	assert_false(m.point(0, 2), "same card: no change")
	assert_false(m.point(0, 9), "out of range")
	assert_eq(m.focus(0), 2)
	assert_eq(m.browse(0), 1)


func test_reopen_starts_a_fresh_visit_on_the_same_cards() -> void:
	var m := M.new([0, 1] as Array[int], 4)
	m.move(0, 2)
	m.confirm(0)
	m.confirm(1)
	m.reopen()
	assert_eq([m.state(0), m.state(1)], [M.CHOOSING, M.CHOOSING])
	assert_eq(m.focus(0), 2, "the cursor stays where it was")
	assert_eq(m.browse(0), 0)


func test_unknown_seats_are_ignored() -> void:
	var m := M.new([0] as Array[int], 4)
	assert_false(m.move(3, 1))
	assert_eq(m.confirm(-1), M.NONE)
	assert_eq(m.cancel(5), M.NONE)
	assert_eq(m.seat_of_slot(0), 0)
	assert_eq(m.seat_of_slot(1), -1)
