extends SceneTree
## Frame time of the four-bot match per quality level (PRD-NFR-01). Windowed run, vsync off.
## Run: godot --path . -s res://scripts/measure_fps.gd
## Writes dev/done/phase-3/evidence/performance.md.

const WARMUP := 120
const SAMPLES := 600
const OUT := "res://dev/done/phase-3/evidence/performance.md"

var _config: GameConfig
var _level: int = 0
var _frame: int = 0
var _last_us: int = 0
var _times: Array[int] = []
var _rows: PackedStringArray = []


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_config = load("res://src/config/default_config.tres") as GameConfig
	root.add_child((load("res://src/debug/perf_match.tscn") as PackedScene).instantiate())
	_set_level(0)
	process_frame.connect(_tick)


func _set_level(level: int) -> void:
	_level = level
	_config.quality_level = level
	_config.emit_changed()
	# emit_changed applies the level's shipping cap (30/60); lift it so frame time is uncapped.
	Engine.max_fps = 0
	_frame = 0
	_times.clear()
	_last_us = Time.get_ticks_usec()


func _tick() -> void:
	Engine.max_fps = 0  # the match's _ready applies the LOW cap on the first frame; keep it lifted
	var now := Time.get_ticks_usec()
	_frame += 1
	if _frame > WARMUP:
		_times.append(now - _last_us)
	_last_us = now
	if _times.size() < SAMPLES:
		return
	_times.sort()
	var total := 0
	for t: int in _times:
		total += t
	var avg := float(total) / _times.size()
	var p95 := _times[int(_times.size() * 0.95)]
	_rows.append("| %s | %.0f | %d | %d | %.1f | %d |" % [["LOW", "MEDIUM", "HIGH"][_level], avg, p95, _times[-1], 1000000.0 / avg, int(Quality.settings(_level)["max_fps"])])
	if _level < 2:
		_set_level(_level + 1)
		return
	var text := "# Phase 3 성능 (데스크톱, 4인 봇전, vsync 끔, 상한 해제)\n\n| 품질 | 평균 µs | p95 µs | 최대 µs | 평균 FPS | 출시 상한 FPS |\n|---|---|---|---|---|---|\n" + "\n".join(_rows) + "\n\n- 기기: %s\n- 측정 중에는 Engine.max_fps = 0 (상한 해제): 표는 렌더 비용 자체이며 출시 상한 열은 참고용\n- 프레임 시간이 세 단계 모두 같은 값으로 수렴하면 렌더 비용이 창/디스플레이 한계보다 작다는 뜻이다 (상한 해제 후에도 그 아래는 보이지 않음). 최대값의 1초 스파이크는 창 시작 시 1회성 정지\n- 모바일 실기기 측정: 대기\n" % OS.get_model_name()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	quit(0)
