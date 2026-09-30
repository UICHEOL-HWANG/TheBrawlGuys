extends GutTest
## Offline event queue (platform A2): cap, persistence, exponential backoff.

const PATH := "user://test_batch_queue.json"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _ev(i: int) -> Dictionary:
	return {"event_type": "app_opened", "n": i}


func test_push_peek_drop() -> void:
	var q := BatchQueue.new("", 10)
	for i: int in 3:
		q.push(_ev(i))
	assert_eq(q.size(), 3)
	assert_eq(q.peek(2).size(), 2)
	assert_eq(int(q.peek(2)[0]["n"]), 0)
	q.drop_front(2)
	assert_eq(q.size(), 1)
	assert_eq(int(q.peek(5)[0]["n"]), 2)


func test_cap_drops_the_oldest() -> void:
	var q := BatchQueue.new("", 5)
	for i: int in 8:
		q.push(_ev(i))
	assert_eq(q.size(), 5)
	assert_eq(int(q.peek(1)[0]["n"]), 3, "oldest three dropped")
	assert_eq(q.dropped_count(), 3)


func test_persistence_round_trip() -> void:
	var q := BatchQueue.new(PATH, 10)
	q.push(_ev(1))
	q.push(_ev(2))
	assert_eq(q.save(), OK)
	var r := BatchQueue.new(PATH, 10)
	assert_eq(r.restore(), 2)
	assert_eq(int(r.peek(2)[1]["n"]), 2)


func test_corrupt_file_is_reported_not_fatal() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var q := BatchQueue.new(PATH, 10)
	assert_eq(q.restore(), 0)
	assert_eq(q.size(), 0)


func test_backoff_doubles_and_caps() -> void:
	var q := BatchQueue.new("", 10)
	assert_true(q.can_send(0))
	q.mark_failure(1000)
	assert_eq(q.next_attempt_ms(), 1000 + BatchQueue.BACKOFF_BASE_MS)
	assert_false(q.can_send(1000 + BatchQueue.BACKOFF_BASE_MS - 1))
	assert_true(q.can_send(1000 + BatchQueue.BACKOFF_BASE_MS))
	q.mark_failure(0)
	assert_eq(q.next_attempt_ms(), BatchQueue.BACKOFF_BASE_MS * 2)
	for i: int in 30:
		q.mark_failure(0)
	assert_eq(q.next_attempt_ms(), BatchQueue.BACKOFF_MAX_MS)
	q.mark_success()
	assert_true(q.can_send(0))
