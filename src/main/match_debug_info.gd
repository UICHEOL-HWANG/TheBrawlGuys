class_name MatchDebugInfo
extends Node
## Loop numbers for the debug ConfigPanel (TickStats: ticks per second, sim cost per tick). The
## panel exists in debug builds only; release builds just count.

var _stats := TickStats.new()
var _panel: ConfigPanel


func setup(config: GameConfig) -> void:
	if OS.is_debug_build():
		_panel = ConfigPanel.new()
		add_child(_panel)
		_panel.setup(config)


func add_sim_cost(usec: int) -> void:
	_stats.add_sim_cost(usec)


func on_frame(delta: float, ticks: int, tick_count: int, alpha: float) -> void:
	_stats.add_frame(delta, ticks)
	if _panel != null:
		_panel.set_info(_stats.info(tick_count, alpha))
