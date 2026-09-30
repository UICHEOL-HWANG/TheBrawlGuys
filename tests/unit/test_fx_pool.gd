extends GutTest
## Round-robin effect slots (mobile cap on simultaneous hit effects).


func test_hands_out_every_slot_then_reuses_the_oldest() -> void:
	var pool := FxPool.new(3)
	assert_eq([pool.acquire(), pool.acquire(), pool.acquire()], [0, 1, 2])
	assert_eq(pool.acquire(), 0, "the oldest effect is recycled once all are busy")
	assert_eq(pool.acquire(), 1)


func test_cap_is_at_least_one() -> void:
	var pool := FxPool.new(0)
	assert_eq(pool.size(), 1)
	assert_eq(pool.acquire(), 0)
	assert_eq(pool.acquire(), 0)
