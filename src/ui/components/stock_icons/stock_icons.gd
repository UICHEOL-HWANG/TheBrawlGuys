class_name StockIcons
extends HBoxContainer
## Remaining stocks (design.md DS-CMP-02): one player marker per stock, lost ones dimmed.

func setup(index: int, max_stocks: int) -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	add_theme_constant_override("separation", DS.S2)
	for i: int in max_stocks:
		var m := PlayerMarker.new()
		m.setup(index, DS.S5)
		add_child(m)


func set_stocks(n: int) -> void:
	for i: int in get_child_count():
		(get_child(i) as PlayerMarker).set_dimmed(i >= n)


func shown() -> int:
	var count := 0
	for child: Node in get_children():
		if not (child as PlayerMarker).is_dimmed():
			count += 1
	return count


func set_preview() -> void:
	setup(1, 3)
	set_stocks(2)
