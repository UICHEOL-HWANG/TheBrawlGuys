extends GutTest
## FitCenter (design.md DS-LAY-04): centers a block, scrolls it when the screen is too short.


func _fit(block_size: Vector2, screen: Vector2) -> Array[Control]:
	var host := Control.new()
	host.size = screen
	add_child_autofree(host)
	var fit := FitCenter.new()
	host.add_child(fit)
	var block := Control.new()
	block.custom_minimum_size = block_size
	fit.content().add_child(block)
	return [fit, block]


func test_short_block_is_centered() -> void:
	var nodes := _fit(Vector2(400, 300), Vector2(1400, 700))
	await wait_process_frames(2)
	var block := nodes[1]
	assert_almost_eq(block.get_global_rect().get_center(), Vector2(700, 350), Vector2.ONE)


func test_tall_block_scrolls_instead_of_overflowing() -> void:
	var nodes := _fit(Vector2(400, 900), Vector2(1400, 600))
	await wait_process_frames(2)
	var fit := nodes[0] as FitCenter
	var block := nodes[1]
	assert_almost_eq(block.get_global_rect().position.y, 0.0, 1.0, "top edge stays on screen")
	assert_eq(fit.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	fit.scroll_vertical = 300
	await wait_process_frames(2)
	assert_gt(fit.scroll_vertical, 0, "can scroll to the rest")
