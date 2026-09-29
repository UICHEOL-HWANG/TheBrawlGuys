# Phase 1 — 핵심 전투 + 기본 터치 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캡슐 두 개(플레이어 vs 봇)가 이동·점프·약공격으로 싸우고, 누적 대미지 넉백으로 경기장 밖으로 날아가 스톡을 잃으며, 키보드와 터치로 한 판을 끝까지 할 수 있게 한다.

**Architecture:** 전투 규칙은 전부 `src/sim/`의 순수 로직(`Collision`, `Fighter`, `AttackData`, `Motion`, `Combat`, `Rules`, `World`)이고, 틱마다 `InputFrame`만 받는다. `World.state_view()`는 값 데이터(파이터 목록 + 이번 틱 이벤트)를 내놓고, `src/render/`·`src/ui/`가 그것을 보간해 그린다. 입력은 `src/input/`에서 키보드·터치·봇을 모두 `InputFrame`으로 바꾸며, 버튼 누름은 래치로 틱에 전달한다.

**Tech Stack:** Godot 4.7.2 (GDScript 정적 타입), GUT 9.7.1, Movie Maker(`--write-movie`)로 영상 증거

**Spec:** [`docs/PRD.md`](../../../docs/PRD.md) §3·§4·§5 · [`docs/PHASES.md`](../../../docs/PHASES.md) Phase 1 · [`docs/design.md`](../../../docs/design.md) · 결정: [`phase-1-context.md`](./phase-1-context.md) D1~D7

## Global Constraints

- Godot 4.7.2, GDScript 정적 타입 필수 (`untyped_declaration` = 에러) — PRD §5.1
- `src/sim/`은 Node·SceneTree·RenderingServer·PhysicsServer3D·Input·전역 난수·Time·OS·Engine·`load()`를 쓰지 않는다 (`scripts/check-sim-purity.sh`) — PRD §5.2-1, -7
- sim은 60Hz 고정 틱, 렌더는 `prev → curr`를 `alpha`로 보간 — PRD §5.4
- `state_view()`는 값 데이터만 (살아 있는 sim 객체 참조 금지) — Phase 0 최종 리뷰 #5
- 모든 튜닝 수치는 `GameConfig`, 아트 디렉션 상수는 렌더 코드의 이름 붙은 const, 색·UI 크기는 `DS` 토큰만 (`scripts/check-colors.sh`, .gd/.tscn/.tres) — design.md §2.2
- 넉백 공식: `knockback = (base_knockback + damage_percent × knockback_scaling) × global_knockback_mul`, `velocity = normalize(facing + (0, launch_angle_y, 0)) × knockback`, `hitstun = knockback × hitstun_factor`(초) — PRD §4.2
- 스톡 3, 링아웃 `y < kill_y` 또는 경계 밖, 리스폰은 공중 + 2초 무적 — PRD §4.1
- 캐시된 `ToonMaterials` 머티리얼은 절대 수정하지 않는다 (필요하면 `duplicate()`) — toon_materials.gd
- GUT는 예상된 `push_error`를 `assert_push_error`로 인정해야 통과한다
- 새 스크립트의 `.uid` 사이드카는 같은 커밋에 넣는다
- 커밋: `<type>: <description>` + 마지막 줄 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- 증거 스크린샷·영상은 `dev/active/phase-1/evidence/`

---

## File Structure

```
src/
  sim/
    sim_time.gd            T4  SimTime: TICK_RATE, TICK_DT, to_ticks()
    collision.gd           T3  Collision: 지면·경계·캡슐–캡슐·캡슐–박스
    attack_data.gd         T4  AttackData: 공격 수치 값 객체 (light_from(config))
    fighter.gd             T4  Fighter: 상태·직렬화·뷰 변환
    motion.gd              T5  Motion: 입력 적용·중력·착지·밀어내기
    combat.gd              T6  Combat: 히트 판정·대미지·넉백·hitstun·hitstop
    rules.gd               T7  Rules: 스폰·링아웃·스톡·리스폰·승패
    world.gd               T5  (수정) 파이터 보유, 틱 순서, snapshot v2
    input_frame.gd         T2  (수정) 양자화, make()
  config/game_config.gd    T1  (수정) Phase 1 수치 + fingerprint()
  main/fixed_ticker.gd     T4  (수정) SimTime 상수 사용
  main/main.gd             T16 (수정) 경기 루프 전체 연결
  input/
    button_latch.gd        T2  ButtonLatch
    input_bindings.gd      T10 InputBindings: P1 키 → InputMap
    local_input.gd         T10 LocalInput: 키보드(+터치) → InputFrame
    bot_controller.gd      T9  BotController
    touch_stick_model.gd   T11 TouchStickModel (순수 계산)
    touch_input.gd         T11 TouchInput: 터치/마우스 → LocalInput
  render/
    fighter_view.gd        T14 FighterView
    arena_view.gd          T14 (수정) 가장자리 밝은 립
    camera_framing.gd      T15 (수정) x/z 분리 프레이밍
    camera_rig.gd          T15 (수정) 화면비·피치 전달, 흔들림 오프셋
    feel/shake_model.gd    T15 ShakeModel
    feel/hit_spark.gd      T15 HitSpark
    feel/feel_director.gd  T15 FeelDirector: 이벤트 → 연출
  ui/
    player_style.gd        T13 PlayerStyle: 플레이어 색·모양
    damage_color.gd        T13 DamageColor: 대미지 램프
    hud.gd                 T13 Hud: 상단 HUD + 결과 배너
    theme/tokens.gd        T11 (수정) 반투명 표면 토큰
    components/
      touch_stick/         T11 TouchStick (DS-CMP-03)
      touch_button/        T11 TouchButton v1 (DS-CMP-04)
      damage_counter/      T13 DamageCounter (DS-CMP-01)
      stock_icons/         T13 StockIcons (DS-CMP-02)
      result_banner/       T13 ResultBanner (DS-CMP-09)
  debug/
    config_schema.gd       T1  (수정) step 파싱 가드
    ds_gallery.gd          T11·T13 (수정) COMPONENTS 등록
    ringout_demo.gd/.tscn  T17 링아웃 영상용 데모 씬
scripts/
  test.sh                  T8  (수정) tests/replay 포함
  bench_sim.gd             T17 4인 600틱 sim 비용
  measure_input_latency.gd T17 입력 → 상태 반영 프레임 수
  tune_knockback.gd        T17 링아웃 최소 배율 탐색
tests/
  unit/test_button_latch.gd, test_collision.gd, test_fighter.gd, test_world_movement.gd,
       test_combat.gd, test_rules.gd, test_bot.gd, test_input_bindings.gd,
       test_touch_stick_model.gd, test_player_style.gd, test_damage_color.gd,
       test_shake_model.gd, test_fighter_view.gd  (+ 기존 파일 수정)
  replay/test_replay.gd    T8
```

**경계 원칙:** 규칙·계산은 `RefCounted`/정적 함수로(테스트 대상), 노드는 결과를 그리기만 한다. 봇·입력은 sim 밖(`src/input/`)이며 `state_view()` 값만 읽는다.

**틱 순서 (World.tick):** ① 파이터마다 `Motion.step` (hitstop이면 멈춤) → ② `Motion.separate` → ③ `Combat.resolve` (히트 이벤트) → ④ `Rules.apply` (링아웃·리스폰 이벤트) → ⑤ 승패 판정 → ⑥ `tick_count += 1`.

---

### Task 1: GameConfig Phase 1 수치 + config 지문 + ConfigSchema 가드

**Files:**
- Modify: `src/config/game_config.gd` (전체 교체), `src/debug/config_schema.gd`
- Test: `tests/unit/test_game_config.gd`, `tests/unit/test_config_schema.gd`

**Interfaces:**
- Consumes: 기존 `GameConfig` 필드 (Phase 0)
- Produces:
  - 새 필드 — Movement: `max_jumps: int`, `air_acceleration`, `air_drag` / Fighter: `fighter_radius`, `fighter_height`, `hitstun_ground_friction` / Rules: `stocks: int`, `respawn_height`, `respawn_invuln`, `blast_margin` / LightAttack: `light_damage`, `light_base_knockback`, `light_knockback_scaling`, `light_launch_angle_y`, `light_startup_ticks: int`, `light_active_ticks: int`, `light_recovery_ticks: int`, `light_hitbox_forward`, `light_hitbox_up`, `light_hitbox_half_width`, `light_hitbox_half_height` / Bot: `bot_attack_range`, `bot_attack_cooldown_ticks: int`, `bot_edge_ratio` / Feel: `shake_per_knockback`, `shake_max`, `shake_decay`, `blink_hz`, `blink_hz_end`, `spark_large_threshold` / Camera: `cam_zoom_max` 기본 70 (D2)
  - `func fingerprint() -> int` — 모든 스크립트 변수 값의 해시 (D1)
- 근거: `[PRD-CFG-01]` `[PRD-RULE-02]` `[PRD-RULE-03]` `[PRD-RULE-04]` `[GD-FEEL-01~03]` `[GD-CAM-01]`

- [ ] **Step 1: 실패하는 테스트 추가**

`tests/unit/test_game_config.gd` 끝에 추가:
```gdscript


func test_global_knockback_default() -> void:
	assert_eq(GameConfig.new().global_knockback_mul, 1.0)


func test_phase1_defaults_match_prd() -> void:
	var c := GameConfig.new()
	assert_eq(c.stocks, 3)
	assert_eq(c.respawn_invuln, 2.0)
	assert_eq(c.max_jumps, 2)
	assert_eq(c.light_damage, 4.0)
	assert_eq(c.light_base_knockback, 3.0)
	assert_eq(c.light_knockback_scaling, 0.05)
	assert_eq(c.cam_zoom_max, 70.0)


func test_fingerprint_changes_with_values() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	assert_eq(a.fingerprint(), b.fingerprint(), "same values -> same fingerprint")
	b.light_damage = 5.0
	assert_ne(a.fingerprint(), b.fingerprint(), "changed value -> different fingerprint")
```

`tests/unit/test_config_schema.gd` 끝에 추가:
```gdscript


class _BadStep extends Resource:
	## Reproduces a range hint whose third field is a suffix, not a step ("0,1,or_greater").
	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": "suffixed", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		}]


func test_non_numeric_hint_suffix_falls_back_to_default_step() -> void:
	var s := _find(ConfigSchema.sliders_for(_BadStep.new()), "suffixed")
	assert_false(s.is_empty())
	assert_eq(s["step"], ConfigSchema.DEFAULT_STEP, "was 0.0 before the guard")


func test_phase1_groups_are_exposed() -> void:
	var specs := ConfigSchema.sliders_for(GameConfig.new())
	for name: String in ["stocks", "light_damage", "light_startup_ticks", "bot_attack_range", "shake_max", "blink_hz"]:
		assert_false(_find(specs, name).is_empty(), "%s missing" % name)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_game_config` → FAIL (`stocks`, `fingerprint` 등 미정의)
Run: `scripts/test.sh -gselect=test_config_schema` → FAIL (새 그룹 없음)

- [ ] **Step 3: GameConfig 교체**

`src/config/game_config.gd` 전체:
```gdscript
class_name GameConfig
extends Resource
## Value ownership: GameConfig holds gameplay/feel tunables exposed on the debug panel.
## Art-direction constants (prop counts, light energies, mesh sizes) stay as named consts
## in render code; colors and UI sizes live only in DS tokens (src/ui/theme/tokens.gd).
## Every tunable number lives here. The debug panel builds a slider for each @export_range.
## Initial values: docs/PRD.md §4.5. Camera rules: docs/design.md GD-CAM-01.

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 25.0, 0.1) var jump_velocity: float = 9.0
@export_range(-80.0, -5.0, 0.5) var gravity: float = -25.0
@export_range(1, 4, 1) var max_jumps: int = 2
## Airborne steering toward the input direction (m/s^2); with no input only air_drag applies,
## so launched fighters keep their momentum after hitstun ends.
@export_range(0.0, 80.0, 0.5) var air_acceleration: float = 20.0
@export_range(0.0, 40.0, 0.5) var air_drag: float = 2.0

@export_group("Fighter")
@export_range(0.2, 1.0, 0.01) var fighter_radius: float = 0.45
@export_range(0.8, 3.0, 0.05) var fighter_height: float = 1.6
@export_range(0.0, 1.0, 0.01) var hitstun_ground_friction: float = 0.85

@export_group("Arena")
@export_range(4.0, 20.0, 0.1) var arena_radius: float = 10.0
@export_range(-30.0, -2.0, 0.5) var kill_y: float = -8.0

@export_group("Rules")
@export_range(1, 9, 1) var stocks: int = 3
@export_range(1.0, 20.0, 0.5) var respawn_height: float = 6.0
@export_range(0.0, 5.0, 0.1) var respawn_invuln: float = 2.0
@export_range(2.0, 40.0, 0.5) var blast_margin: float = 12.0

@export_group("Knockback")
@export_range(0.0, 10.0, 0.01) var global_knockback_mul: float = 1.0
@export_range(0.0, 0.2, 0.001) var hitstun_factor: float = 0.04
@export_range(0.0, 0.3, 0.005) var hitstop_light: float = 0.06
@export_range(0.0, 0.3, 0.005) var hitstop_heavy: float = 0.1
@export_range(0.0, 1.0, 0.01) var guard_damage_mul: float = 0.2
@export_range(0.0, 1.0, 0.01) var guard_knockback_mul: float = 0.0

@export_group("LightAttack")
@export_range(0.0, 30.0, 0.5) var light_damage: float = 4.0
@export_range(0.0, 30.0, 0.1) var light_base_knockback: float = 3.0
@export_range(0.0, 0.5, 0.005) var light_knockback_scaling: float = 0.05
@export_range(0.0, 2.0, 0.05) var light_launch_angle_y: float = 0.6
@export_range(0, 30, 1) var light_startup_ticks: int = 3
@export_range(1, 30, 1) var light_active_ticks: int = 3
@export_range(0, 60, 1) var light_recovery_ticks: int = 8
@export_range(0.0, 3.0, 0.05) var light_hitbox_forward: float = 0.8
@export_range(0.0, 3.0, 0.05) var light_hitbox_up: float = 0.9
@export_range(0.1, 2.0, 0.05) var light_hitbox_half_width: float = 0.45
@export_range(0.1, 2.0, 0.05) var light_hitbox_half_height: float = 0.45

@export_group("Bot")
@export_range(0.5, 5.0, 0.1) var bot_attack_range: float = 1.4
@export_range(0, 120, 1) var bot_attack_cooldown_ticks: int = 30
@export_range(0.3, 1.0, 0.01) var bot_edge_ratio: float = 0.8

@export_group("Feel")
@export_range(0.0, 0.2, 0.001) var shake_per_knockback: float = 0.02
@export_range(0.0, 3.0, 0.05) var shake_max: float = 0.6
@export_range(0.5, 30.0, 0.5) var shake_decay: float = 8.0
@export_range(1.0, 30.0, 0.5) var blink_hz: float = 10.0
@export_range(1.0, 40.0, 0.5) var blink_hz_end: float = 20.0
@export_range(0.0, 40.0, 0.5) var spark_large_threshold: float = 8.0

@export_group("Loop")
@export_range(1, 10, 1) var max_ticks_per_frame: int = 5

@export_group("Camera")
@export_range(30.0, 85.0, 0.5) var cam_pitch: float = 60.0
@export_range(0.0, 10.0, 0.1) var cam_margin: float = 3.0
@export_range(5.0, 40.0, 0.5) var cam_zoom_min: float = 14.0
@export_range(10.0, 150.0, 0.5) var cam_zoom_max: float = 70.0
@export_range(0.0, 20.0, 0.1) var cam_smooth: float = 6.0
@export_range(10.0, 70.0, 0.5) var cam_fov: float = 40.0

@export_group("Touch")
@export_range(0.05, 0.5, 0.01) var touch_hold_threshold: float = 0.15


## Hash of every script variable (D1). Snapshots and replays store it so a run can only be
## restored or verified against the exact same tuning.
func fingerprint() -> int:
	var values: Array = []
	for p: Dictionary in get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append([p["name"], get(p["name"])])
	return hash(values)
```

(`global_knockback_mul` 범위를 0~3 → 0~10으로 넓힌다. T17 튜닝에서 3을 넘길 수 있기 때문이다.)

- [ ] **Step 4: ConfigSchema step 가드**

`src/debug/config_schema.gd`의 `"step": ...` 줄을 다음으로 바꾼다:
```gdscript
			"step": float(parts[2]) if parts.size() > 2 and parts[2].strip_edges().is_valid_float() else DEFAULT_STEP,
```
같은 함수에서 `var parts := ...` 바로 아래에 추가:
```gdscript
		if parts.size() < 2:
			continue
```

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh -gselect=test_game_config` → PASS
Run: `scripts/test.sh -gselect=test_config_schema` → PASS
Run: `scripts/check-all.sh` → `ALL CHECKS PASSED` (카메라 기존 테스트는 zoom 인자를 직접 넘기므로 영향 없음)

- [ ] **Step 6: 커밋**

```bash
git add src/config/game_config.gd src/debug/config_schema.gd tests/unit/test_game_config.gd tests/unit/test_config_schema.gd
git commit -m "feat: add phase 1 tunables and config fingerprint

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: InputFrame 양자화 + ButtonLatch

**Files:**
- Modify: `src/sim/input_frame.gd`
- Create: `src/input/button_latch.gd`
- Test: `tests/unit/test_input_frame.gd` (추가), `tests/unit/test_button_latch.gd`

**Interfaces:**
- Consumes: `InputFrame` (Phase 0)
- Produces:
  - `InputFrame.MOVE_STEPS := 127`, `static func quantize_axis(v: float) -> float`, `static func make(mx: float, mz: float, p_jump: bool = false, p_light: bool = false, p_heavy: bool = false, p_guard: bool = false, p_grab: bool = false) -> InputFrame`
  - `class_name ButtonLatch extends RefCounted` — `func press() -> void`, `func consume() -> bool`
- 근거: `[PRD-CTL-01]`, context D5·D6

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_input_frame.gd` 끝에 추가:
```gdscript


func test_quantize_axis_snaps_to_steps_and_clamps() -> void:
	assert_eq(InputFrame.quantize_axis(0.0), 0.0)
	assert_eq(InputFrame.quantize_axis(1.5), 1.0)
	assert_eq(InputFrame.quantize_axis(-2.0), -1.0)
	var q := InputFrame.quantize_axis(0.3333)
	assert_almost_eq(q * InputFrame.MOVE_STEPS, roundf(q * InputFrame.MOVE_STEPS), 0.00001)


func test_make_quantizes_and_sets_buttons() -> void:
	var f := InputFrame.make(0.70710678, -0.70710678, true, true)
	assert_eq(f.move_x, InputFrame.quantize_axis(0.70710678))
	assert_eq(f.move_z, InputFrame.quantize_axis(-0.70710678))
	assert_true(f.jump)
	assert_true(f.light)
	assert_false(f.heavy or f.guard or f.grab)
```

`tests/unit/test_button_latch.gd`:
```gdscript
extends GutTest


func test_consume_returns_false_without_press() -> void:
	assert_false(ButtonLatch.new().consume())


func test_press_is_consumed_exactly_once() -> void:
	var l := ButtonLatch.new()
	l.press()
	assert_true(l.consume(), "first tick sees the press")
	assert_false(l.consume(), "second tick does not see it again")


func test_press_survives_frames_without_ticks() -> void:
	var l := ButtonLatch.new()
	l.press()
	# a frame with zero sim ticks consumes nothing; the next tick still sees it
	assert_true(l.consume())


func test_multiple_presses_before_a_tick_collapse_to_one() -> void:
	var l := ButtonLatch.new()
	l.press()
	l.press()
	assert_true(l.consume())
	assert_false(l.consume())
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_input_frame` → FAIL (`quantize_axis` 미정의)
Run: `scripts/test.sh -gselect=test_button_latch` → FAIL (`ButtonLatch` 미정의)

- [ ] **Step 3: 구현**

`src/sim/input_frame.gd`에서 `var grab` 선언 아래에 상수를, 파일 끝에 두 함수를 추가:
```gdscript
## Move axes are quantized to 1/MOVE_STEPS so keyboard, touch, bot and network inputs are
## bit-identical for the same intent (context D5).
const MOVE_STEPS := 127
```
```gdscript


static func quantize_axis(v: float) -> float:
	return roundf(clampf(v, -1.0, 1.0) * MOVE_STEPS) / MOVE_STEPS


static func make(mx: float, mz: float, p_jump: bool = false, p_light: bool = false,
		p_heavy: bool = false, p_guard: bool = false, p_grab: bool = false) -> InputFrame:
	var f := InputFrame.new()
	f.move_x = quantize_axis(mx)
	f.move_z = quantize_axis(mz)
	f.jump = p_jump
	f.light = p_light
	f.heavy = p_heavy
	f.guard = p_guard
	f.grab = p_grab
	return f
```

`src/input/button_latch.gd`:
```gdscript
class_name ButtonLatch
extends RefCounted
## Carries a button press from the frame it happened in to the next sim tick (context D6).
## Frames can run zero or several fixed ticks, so edges must be latched, not polled per tick.

var _pending: bool = false


func press() -> void:
	_pending = true


func consume() -> bool:
	var was := _pending
	_pending = false
	return was
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_input_frame` → PASS · `scripts/test.sh -gselect=test_button_latch` → PASS · `scripts/check-sim-purity.sh` → OK

- [ ] **Step 5: 커밋**

```bash
git add src/sim/input_frame.gd src/input/button_latch.gd src/input/button_latch.gd.uid tests/unit/test_input_frame.gd tests/unit/test_button_latch.gd tests/unit/test_button_latch.gd.uid
git commit -m "feat: quantize move input and add button latch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Collision — 지면·경계·캡슐–캡슐·캡슐–박스

**Files:**
- Create: `src/sim/collision.gd`
- Test: `tests/unit/test_collision.gd`

**Interfaces:**
- Consumes: 없음
- Produces: `class_name Collision extends RefCounted` (정적 함수만)
  - `static func on_arena_floor(pos: Vector3, arena_radius: float) -> bool` — 수평 거리 ≤ 반경
  - `static func is_out_of_bounds(pos: Vector3, arena_radius: float, blast_margin: float, kill_y: float) -> bool`
  - `static func separate_capsules(a: Vector3, b: Vector3, radius: float, height: float) -> Vector3` — `a`에 더할 수평 밀어내기 벡터 (b에는 음수). 겹치지 않으면 `Vector3.ZERO`
  - `static func yaw_of(facing: Vector3) -> float` — `atan2(facing.x, facing.z)`
  - `static func capsule_hits_box(cap_base: Vector3, radius: float, height: float, box_center: Vector3, box_yaw: float, half: Vector3) -> bool` — 수직 캡슐(발 위치 `cap_base`) vs Y축 회전 박스(로컬 +z = 정면)
- 근거: `[PRD-ARCH-01]` `[PRD-RULE-02]`

수학 메모: 박스 로컬 좌표로 옮기면 (`rel.rotated(UP, -yaw)`) 캡슐 축은 여전히 수직 선분이다. 거리² = dx² + dy² + dz² (dx = max(|x|−hx, 0), dz 동일, dy = 선분 [y0, y1]과 박스 [−hy, hy]의 간격). 거리² ≤ r² 이면 겹침. Y축 회전 박스 vs 수직 캡슐에 대해 정확하다.

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_collision.gd`:
```gdscript
extends GutTest

const R := 0.45
const H := 1.6


func test_floor_is_inside_radius() -> void:
	assert_true(Collision.on_arena_floor(Vector3(9.9, 0, 0), 10.0))
	assert_true(Collision.on_arena_floor(Vector3(0, 5, -10.0), 10.0))
	assert_false(Collision.on_arena_floor(Vector3(7.2, 0, 7.2), 10.0))


func test_out_of_bounds_by_height_or_distance() -> void:
	assert_false(Collision.is_out_of_bounds(Vector3(0, 0, 0), 10.0, 12.0, -8.0))
	assert_true(Collision.is_out_of_bounds(Vector3(0, -8.1, 0), 10.0, 12.0, -8.0))
	assert_true(Collision.is_out_of_bounds(Vector3(22.1, 3, 0), 10.0, 12.0, -8.0))
	assert_false(Collision.is_out_of_bounds(Vector3(21.9, 3, 0), 10.0, 12.0, -8.0))


func test_separate_pushes_apart_by_half_penetration() -> void:
	var push := Collision.separate_capsules(Vector3(0.5, 0, 0), Vector3(0, 0, 0), R, H)
	# overlap = 2R - 0.5 = 0.4 -> a moves +0.2 on x
	assert_almost_eq(push.x, 0.2, 0.0001)
	assert_eq(push.y, 0.0)


func test_separate_ignores_far_or_vertically_disjoint() -> void:
	assert_eq(Collision.separate_capsules(Vector3(2, 0, 0), Vector3.ZERO, R, H), Vector3.ZERO)
	assert_eq(Collision.separate_capsules(Vector3(0.1, 2.0, 0), Vector3.ZERO, R, H), Vector3.ZERO)


func test_separate_coincident_uses_deterministic_axis() -> void:
	var push := Collision.separate_capsules(Vector3.ZERO, Vector3.ZERO, R, H)
	assert_almost_eq(push.x, R, 0.0001)


func test_yaw_of_facing() -> void:
	assert_almost_eq(Collision.yaw_of(Vector3(0, 0, 1)), 0.0, 0.0001)
	assert_almost_eq(Collision.yaw_of(Vector3(1, 0, 0)), PI / 2.0, 0.0001)


func test_box_in_front_hits_capsule() -> void:
	# box 0.8 in front of a fighter facing +x, target standing 1.0 away on x
	var yaw := Collision.yaw_of(Vector3(1, 0, 0))
	var center := Vector3(0.8, 0.9, 0)
	var half := Vector3(0.45, 0.45, 0.45)
	assert_true(Collision.capsule_hits_box(Vector3(1.0, 0, 0), R, H, center, yaw, half))


func test_box_misses_capsule_behind_or_too_far() -> void:
	var yaw := Collision.yaw_of(Vector3(1, 0, 0))
	var center := Vector3(0.8, 0.9, 0)
	var half := Vector3(0.45, 0.45, 0.45)
	assert_false(Collision.capsule_hits_box(Vector3(-1.0, 0, 0), R, H, center, yaw, half), "behind")
	assert_false(Collision.capsule_hits_box(Vector3(1.8, 0, 0), R, H, center, yaw, half), "gap 0.1 beyond radius")


func test_box_touching_edge_counts_as_hit() -> void:
	# box right face at x = 1.25, capsule surface at x = 1.7 - 0.45 = 1.25
	var center := Vector3(0.8, 0.9, 0)
	var half := Vector3(0.45, 0.45, 0.45)
	assert_true(Collision.capsule_hits_box(Vector3(1.7, 0, 0), R, H, center, PI / 2.0, half))


func test_box_rotation_matters() -> void:
	# a long thin box along local +z: facing +x covers x, facing +z does not
	var half := Vector3(0.1, 0.45, 1.0)
	var target := Vector3(1.5, 0, 0)
	assert_true(Collision.capsule_hits_box(target, R, H, Vector3(0.8, 0.9, 0), PI / 2.0, half))
	assert_false(Collision.capsule_hits_box(target, R, H, Vector3(0.8, 0.9, 0), 0.0, half))


func test_box_above_capsule_misses() -> void:
	var half := Vector3(0.45, 0.45, 0.45)
	assert_false(Collision.capsule_hits_box(Vector3(0.8, 0, 0), R, H, Vector3(0.8, 3.0, 0), 0.0, half))
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_collision` → FAIL (`Collision` 미정의)

- [ ] **Step 3: 구현**

`src/sim/collision.gd`:
```gdscript
class_name Collision
extends RefCounted
## Simple-shape collision for the pure sim (PRD §5.2): round arena floor, ring-out bounds,
## vertical capsules (fighters) and Y-rotated boxes (hitboxes). No engine physics.

## Push direction used when two capsules sit exactly on top of each other.
const COINCIDENT_AXIS := Vector3(1, 0, 0)
const EPSILON := 0.000001


static func on_arena_floor(pos: Vector3, arena_radius: float) -> bool:
	return Vector2(pos.x, pos.z).length() <= arena_radius


static func is_out_of_bounds(pos: Vector3, arena_radius: float, blast_margin: float, kill_y: float) -> bool:
	return pos.y < kill_y or Vector2(pos.x, pos.z).length() > arena_radius + blast_margin


static func separate_capsules(a: Vector3, b: Vector3, radius: float, height: float) -> Vector3:
	if absf(a.y - b.y) >= height:
		return Vector3.ZERO
	var d := Vector3(a.x - b.x, 0.0, a.z - b.z)
	var dist := d.length()
	var min_dist := radius * 2.0
	if dist >= min_dist:
		return Vector3.ZERO
	var dir := COINCIDENT_AXIS if dist < EPSILON else d / dist
	return dir * (min_dist - dist) * 0.5


static func yaw_of(facing: Vector3) -> float:
	return atan2(facing.x, facing.z)


static func capsule_hits_box(cap_base: Vector3, radius: float, height: float,
		box_center: Vector3, box_yaw: float, half: Vector3) -> bool:
	var local := (cap_base - box_center).rotated(Vector3.UP, -box_yaw)
	var seg_bottom := local.y + radius
	var seg_top := local.y + maxf(height - radius, radius)
	var dx := maxf(absf(local.x) - half.x, 0.0)
	var dz := maxf(absf(local.z) - half.z, 0.0)
	var dy := 0.0
	if seg_bottom > half.y:
		dy = seg_bottom - half.y
	elif seg_top < -half.y:
		dy = -half.y - seg_top
	return dx * dx + dy * dy + dz * dz <= radius * radius + EPSILON
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_collision` → 11/11 PASS · `scripts/check-sim-purity.sh` → OK

- [ ] **Step 5: 커밋**

```bash
git add src/sim/collision.gd src/sim/collision.gd.uid tests/unit/test_collision.gd tests/unit/test_collision.gd.uid
git commit -m "feat: add simple-shape collision for fighters and hitboxes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: SimTime + AttackData + Fighter 데이터

**Files:**
- Create: `src/sim/sim_time.gd`, `src/sim/attack_data.gd`, `src/sim/fighter.gd`
- Modify: `src/main/fixed_ticker.gd` (상수를 SimTime에서 가져오기)
- Test: `tests/unit/test_fighter.gd`

**Interfaces:**
- Consumes: `GameConfig` LightAttack·hitstop 필드 (T1)
- Produces:
  - `class_name SimTime` — `const TICK_RATE := 60`, `const TICK_DT := 1.0 / 60`, `static func to_ticks(seconds: float) -> int` (반올림, 음수 → 0)
  - `class_name AttackData` — 필드 `damage, base_knockback, knockback_scaling, launch_angle_y: float`, `startup_ticks, active_ticks, recovery_ticks, hitstop_ticks: int`, `hitbox_forward, hitbox_up: float`, `hitbox_half: Vector3`; `static func light_from(config: GameConfig) -> AttackData`, `func total_ticks() -> int`, `func is_active(attack_ticks: int) -> bool` (공격 시작 틱을 1로 셈: `startup < t ≤ startup + active`)
  - `class_name Fighter` — `enum State { IDLE, MOVE, AIR, ATTACK, HITSTUN, KO }`; 필드 `id, spawn_id, state, state_ticks, stocks, jumps_left, hitstun_ticks, hitstop_ticks, invuln_ticks, attack_ticks: int`, `pos, vel, facing: Vector3`, `damage: float`, `on_ground: bool`, `hit_ids: Array[int]`; `func is_alive() -> bool`, `func can_act() -> bool`, `func set_state(s: int) -> void`, `func to_view() -> Dictionary`, `func to_data() -> Dictionary`, `static func from_data(d: Dictionary) -> Fighter` (검증 실패 시 `null`)
  - 뷰 상태 해석: "launched" = `HITSTUN && !on_ground`, "respawn" = `invuln_ticks > 0` (PHASES 상태 목록 대응)
- 근거: `[PRD-ARCH-03]` `[PRD-ARCH-04]`, context D4

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_fighter.gd`:
```gdscript
extends GutTest


func _sample() -> Fighter:
	var f := Fighter.new()
	f.id = 1
	f.spawn_id = 2
	f.pos = Vector3(1, 2, 3)
	f.vel = Vector3(-1, 0, 4)
	f.facing = Vector3(1, 0, 0)
	f.set_state(Fighter.State.HITSTUN)
	f.damage = 42.5
	f.stocks = 2
	f.jumps_left = 1
	f.on_ground = false
	f.hitstun_ticks = 7
	f.hit_ids.assign([0, 3])
	return f


func test_sim_time_to_ticks() -> void:
	assert_eq(SimTime.TICK_RATE, 60)
	assert_eq(SimTime.to_ticks(0.06), 4, "3.6 rounds to 4")
	assert_eq(SimTime.to_ticks(2.0), 120)
	assert_eq(SimTime.to_ticks(-1.0), 0)


func test_fixed_ticker_uses_sim_time() -> void:
	assert_eq(FixedTicker.TICK_RATE, SimTime.TICK_RATE)


func test_light_attack_from_config() -> void:
	var c := GameConfig.new()
	var a := AttackData.light_from(c)
	assert_eq(a.damage, 4.0)
	assert_eq(a.base_knockback, 3.0)
	assert_eq(a.knockback_scaling, 0.05)
	assert_eq(a.hitstop_ticks, SimTime.to_ticks(c.hitstop_light))
	assert_eq(a.hitbox_half, Vector3(c.light_hitbox_half_width, c.light_hitbox_half_height, c.light_hitbox_half_width))
	assert_eq(a.total_ticks(), c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks)


func test_attack_active_window() -> void:
	var a := AttackData.new()
	a.startup_ticks = 3
	a.active_ticks = 2
	assert_false(a.is_active(3))
	assert_true(a.is_active(4))
	assert_true(a.is_active(5))
	assert_false(a.is_active(6))


func test_set_state_resets_ticks_only_on_change() -> void:
	var f := Fighter.new()
	f.state_ticks = 9
	f.set_state(Fighter.State.IDLE)
	assert_eq(f.state_ticks, 9, "same state keeps the counter")
	f.set_state(Fighter.State.AIR)
	assert_eq(f.state_ticks, 0)


func test_can_act_and_alive() -> void:
	var f := Fighter.new()
	for s: int in [Fighter.State.IDLE, Fighter.State.MOVE, Fighter.State.AIR]:
		f.set_state(s)
		assert_true(f.can_act())
	for s: int in [Fighter.State.ATTACK, Fighter.State.HITSTUN, Fighter.State.KO]:
		f.set_state(s)
		assert_false(f.can_act())
	assert_false(f.is_alive())


func test_data_round_trip() -> void:
	var f := _sample()
	var g := Fighter.from_data(f.to_data())
	assert_not_null(g)
	assert_eq(g.to_data(), f.to_data())


func test_from_data_rejects_missing_or_mistyped() -> void:
	var d := _sample().to_data()
	var missing := d.duplicate(true)
	missing.erase("stocks")
	assert_null(Fighter.from_data(missing))
	var mistyped := d.duplicate(true)
	mistyped["damage"] = "lots"
	assert_null(Fighter.from_data(mistyped))
	var bad_ids := d.duplicate(true)
	bad_ids["hit_ids"] = [0, "x"]
	assert_null(Fighter.from_data(bad_ids))


func test_to_view_is_a_copy() -> void:
	var f := _sample()
	var view := f.to_view()
	f.pos = Vector3(9, 9, 9)
	f.damage = 99.0
	assert_eq(view["pos"], Vector3(1, 2, 3))
	assert_eq(view["damage"], 42.5)
	assert_false(view.has("hit_ids"), "internal bookkeeping stays out of views")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_fighter` → FAIL (`SimTime`, `AttackData`, `Fighter` 미정의)

- [ ] **Step 3: 구현**

`src/sim/sim_time.gd`:
```gdscript
class_name SimTime
extends RefCounted
## Fixed simulation clock (PRD §5.4). Durations in GameConfig are seconds; the sim counts ticks.

const TICK_RATE := 60
const TICK_DT := 1.0 / TICK_RATE


static func to_ticks(seconds: float) -> int:
	return maxi(roundi(seconds * TICK_RATE), 0)
```

`src/main/fixed_ticker.gd`의 두 상수를 교체:
```gdscript
const TICK_RATE := SimTime.TICK_RATE
const TICK_DT := SimTime.TICK_DT
```

`src/sim/attack_data.gd`:
```gdscript
class_name AttackData
extends RefCounted
## One attack's numbers as a sim value object (PRD §4.2-4.3). Phase 1 builds the light attack
## from GameConfig; Phase 5 styles will build attacks from style data instead.

var damage: float = 0.0
var base_knockback: float = 0.0
var knockback_scaling: float = 0.0
var launch_angle_y: float = 0.0
var startup_ticks: int = 0
var active_ticks: int = 1
var recovery_ticks: int = 0
var hitbox_forward: float = 0.0
var hitbox_up: float = 0.0
var hitbox_half: Vector3 = Vector3.ONE
var hitstop_ticks: int = 0


static func light_from(config: GameConfig) -> AttackData:
	var a := AttackData.new()
	a.damage = config.light_damage
	a.base_knockback = config.light_base_knockback
	a.knockback_scaling = config.light_knockback_scaling
	a.launch_angle_y = config.light_launch_angle_y
	a.startup_ticks = config.light_startup_ticks
	a.active_ticks = config.light_active_ticks
	a.recovery_ticks = config.light_recovery_ticks
	a.hitbox_forward = config.light_hitbox_forward
	a.hitbox_up = config.light_hitbox_up
	a.hitbox_half = Vector3(config.light_hitbox_half_width, config.light_hitbox_half_height, config.light_hitbox_half_width)
	a.hitstop_ticks = SimTime.to_ticks(config.hitstop_light)
	return a


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks


## attack_ticks counts ticks since the attack began; the first attack tick is 1.
func is_active(attack_ticks: int) -> bool:
	return attack_ticks > startup_ticks and attack_ticks <= startup_ticks + active_ticks
```

`src/sim/fighter.gd`:
```gdscript
class_name Fighter
extends RefCounted
## One fighter's sim state. Serialized in World snapshots (to_data/from_data) and exposed to
## views only as value copies (to_view) — never by reference (PRD §5.2, context D4).
## View reading: "launched" = HITSTUN and not on_ground; "respawn" = invuln_ticks > 0.

enum State { IDLE, MOVE, AIR, ATTACK, HITSTUN, KO }

const DATA_TYPES := {
	"id": TYPE_INT, "spawn_id": TYPE_INT, "pos": TYPE_VECTOR3, "vel": TYPE_VECTOR3,
	"facing": TYPE_VECTOR3, "state": TYPE_INT, "state_ticks": TYPE_INT, "damage": TYPE_FLOAT,
	"stocks": TYPE_INT, "jumps_left": TYPE_INT, "on_ground": TYPE_BOOL,
	"hitstun_ticks": TYPE_INT, "hitstop_ticks": TYPE_INT, "invuln_ticks": TYPE_INT,
	"attack_ticks": TYPE_INT, "hit_ids": TYPE_ARRAY,
}

var id: int = 0
## Increments on every respawn so views snap instead of interpolating across the map.
var spawn_id: int = 0
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3(0, 0, 1)
var state: int = State.IDLE
var state_ticks: int = 0
var damage: float = 0.0
var stocks: int = 0
var jumps_left: int = 0
var on_ground: bool = true
var hitstun_ticks: int = 0
var hitstop_ticks: int = 0
var invuln_ticks: int = 0
var attack_ticks: int = 0
## Targets already hit by the current swing (one hit per target per attack).
var hit_ids: Array[int] = []


func is_alive() -> bool:
	return state != State.KO


func can_act() -> bool:
	return state == State.IDLE or state == State.MOVE or state == State.AIR


func set_state(s: int) -> void:
	if state != s:
		state = s
		state_ticks = 0


func to_view() -> Dictionary:
	return {
		"id": id, "spawn_id": spawn_id, "pos": pos, "facing": facing, "state": state,
		"on_ground": on_ground, "damage": damage, "stocks": stocks, "jumps_left": jumps_left,
		"invuln_ticks": invuln_ticks, "hitstop_ticks": hitstop_ticks, "attack_ticks": attack_ticks,
	}


func to_data() -> Dictionary:
	var d := {}
	for key: String in DATA_TYPES:
		d[key] = get(key)
	d["hit_ids"] = hit_ids.duplicate()
	return d


static func from_data(d: Dictionary) -> Fighter:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	for v: Variant in d["hit_ids"]:
		if typeof(v) != TYPE_INT:
			return null
	var f := Fighter.new()
	for key: String in DATA_TYPES:
		if key != "hit_ids":
			f.set(key, d[key])
	f.hit_ids.assign(d["hit_ids"])
	return f
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_fighter` → 9/9 PASS · `scripts/test.sh -gselect=test_fixed_ticker` → PASS · `scripts/check-sim-purity.sh` → OK

- [ ] **Step 5: 커밋**

```bash
git add src/sim/sim_time.gd src/sim/sim_time.gd.uid src/sim/attack_data.gd src/sim/attack_data.gd.uid src/sim/fighter.gd src/sim/fighter.gd.uid src/main/fixed_ticker.gd tests/unit/test_fighter.gd tests/unit/test_fighter.gd.uid
git commit -m "feat: add fighter state, attack data and sim clock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: World 이동·점프·중력·밀어내기 + snapshot v2

**Files:**
- Create: `src/sim/motion.gd`, `src/sim/rules.gd` (스폰 부분만 — 링아웃은 T7)
- Modify: `src/sim/world.gd` (전체 교체)
- Test: `tests/unit/test_world_movement.gd` (기존 `tests/unit/test_world.gd`는 그대로 통과해야 함)

**Interfaces:**
- Consumes: `Fighter`, `AttackData`, `SimTime` (T4), `Collision` (T3), `InputFrame` (T2), `GameConfig.fingerprint()` (T1)
- Produces:
  - `class_name Motion` — `static func step(f: Fighter, input: InputFrame, config: GameConfig, attack: AttackData) -> void`, `static func separate(fighters: Array[Fighter], config: GameConfig) -> void`, `const LAND_TOLERANCE := 0.05`
  - `class_name Rules` — `const ONGOING := -2`, `const DRAW := -1`, `const SPAWN_RADIUS_RATIO := 0.5`, `static func spawn_point(index: int, count: int, config: GameConfig) -> Vector3`, `static func facing_to_center(pos: Vector3) -> Vector3`, `static func spawn_fighter(index: int, count: int, config: GameConfig) -> Fighter`
  - `World` — `_init(p_config: GameConfig, p_seed: int = 0, p_player_count: int = 2)`, `var fighters: Array[Fighter]`, `var match_over: bool`, `var winner_id: int`, `func tick(inputs: Array[InputFrame])` (inputs[i]는 fighter id i의 입력, 모자라면 neutral), `state_view()` → `{"tick", "arena_radius", "match_over", "winner", "fighters": Array[Dictionary], "events": Array[Dictionary]}`, `const SNAPSHOT_VERSION := 2`, `restore()`가 config 지문 불일치를 `"config mismatch"` 오류로 거부
- 근거: `[PRD-CTL-02]` `[PRD-ARCH-01]` `[PRD-ARCH-04]` `[PRD-ARCH-05]`, context D1·D4

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_world_movement.gd`:
```gdscript
extends GutTest


func _inputs(p1: InputFrame) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, InputFrame.neutral()]
	return a


func _run(w: World, p1: InputFrame, ticks: int) -> void:
	for i: int in ticks:
		w.tick(_inputs(p1))


func test_spawns_two_fighters_facing_each_other() -> void:
	var w := World.new(GameConfig.new(), 1)
	assert_eq(w.fighters.size(), 2)
	assert_almost_eq(w.fighters[0].pos.x, -5.0, 0.0001)
	assert_almost_eq(w.fighters[1].pos.x, 5.0, 0.0001)
	assert_almost_eq(w.fighters[0].facing.x, 1.0, 0.0001)
	assert_almost_eq(w.fighters[1].facing.x, -1.0, 0.0001)
	assert_eq(w.fighters[0].stocks, 3)


func test_walks_at_move_speed_and_turns() -> void:
	var w := World.new(GameConfig.new(), 1)
	_run(w, InputFrame.make(0.0, 1.0), 60)
	var f := w.fighters[0]
	assert_almost_eq(f.pos.z, 6.0, 0.01, "move_speed 6 for one second")
	assert_eq(f.pos.y, 0.0)
	assert_true(f.on_ground)
	assert_almost_eq(f.facing.z, 1.0, 0.0001)
	assert_eq(f.state, Fighter.State.MOVE)


func test_jump_rises_lands_and_restores_jumps() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	assert_gt(w.fighters[0].pos.y, 0.0)
	assert_eq(w.fighters[0].jumps_left, c.max_jumps - 1)
	var peak := 0.0
	for i: int in 90:
		w.tick(_inputs(InputFrame.neutral()))
		peak = maxf(peak, w.fighters[0].pos.y)
	# v^2 / 2g = 81 / 50 = 1.62 (discrete integration lands slightly under)
	assert_almost_eq(peak, 1.62, 0.1)
	assert_true(w.fighters[0].on_ground)
	assert_eq(w.fighters[0].jumps_left, c.max_jumps)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)


func test_double_jump_once_then_no_more() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	_run(w, InputFrame.neutral(), 10)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	assert_eq(w.fighters[0].jumps_left, 0)
	assert_gt(w.fighters[0].vel.y, 8.0, "second jump resets vertical speed")
	_run(w, InputFrame.neutral(), 5)
	var vy_before := w.fighters[0].vel.y
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	assert_lt(w.fighters[0].vel.y, vy_before, "third press does nothing; gravity keeps pulling")


func test_walking_off_the_edge_falls() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(-c.arena_radius + 0.2, 0, 0)
	_run(w, InputFrame.make(-1.0, 0.0), 30)
	var f := w.fighters[0]
	assert_lt(f.pos.y, 0.0)
	assert_false(f.on_ground)
	assert_eq(f.state, Fighter.State.AIR)
	assert_true(f.jumps_left <= c.max_jumps - 1, "walking off costs the ground jump")


func test_airborne_momentum_is_kept_without_input() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var f := w.fighters[0]
	f.pos = Vector3(0, 3, 0)
	f.vel = Vector3(7, 0, 0)
	f.on_ground = false
	f.set_state(Fighter.State.AIR)
	w.tick(_inputs(InputFrame.neutral()))
	assert_almost_eq(f.vel.x, 7.0 - c.air_drag * SimTime.TICK_DT, 0.0001, "only light drag, no snap to zero")


func test_below_floor_does_not_snap_back_up() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(0, -1.0, 0)
	w.fighters[0].on_ground = false
	w.fighters[0].set_state(Fighter.State.AIR)
	w.tick(_inputs(InputFrame.neutral()))
	assert_lt(w.fighters[0].pos.y, -1.0, "under the floor keeps falling")


func test_overlapping_fighters_are_pushed_apart() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(0, 0, 0)
	w.fighters[1].pos = Vector3(0.3, 0, 0)
	w.tick(_inputs(InputFrame.neutral()))
	var d := Vector2(w.fighters[1].pos.x - w.fighters[0].pos.x, w.fighters[1].pos.z - w.fighters[0].pos.z).length()
	assert_almost_eq(d, c.fighter_radius * 2.0, 0.001)


func test_state_view_lists_fighters_as_values() -> void:
	var w := World.new(GameConfig.new(), 1)
	var view := w.state_view()
	var fighters: Array = view["fighters"]
	assert_eq(fighters.size(), 2)
	assert_eq(view["arena_radius"], 10.0)
	assert_false(view["match_over"])
	w.fighters[0].pos = Vector3(3, 3, 3)
	assert_almost_eq((fighters[0] as Dictionary)["pos"].x, -5.0, 0.0001)


func test_snapshot_restore_mid_movement_continues_identically() -> void:
	var a := World.new(GameConfig.new(), 5)
	_run(a, InputFrame.make(0.5, 0.5, true), 20)
	var snap := a.snapshot()
	var b := World.new(a.config, 5)
	assert_true(b.restore(snap))
	for i: int in 30:
		var input := InputFrame.make(-0.2, 1.0, i == 7)
		a.tick(_inputs(input))
		b.tick(_inputs(input))
	assert_eq(b.state_hash(), a.state_hash())


func test_restore_rejects_config_mismatch() -> void:
	var a := World.new(GameConfig.new(), 1)
	var snap := a.snapshot()
	var other := GameConfig.new()
	other.move_speed = 7.0
	var b := World.new(other, 1)
	assert_false(b.restore(snap))
	assert_push_error("config mismatch")


func test_hash_changes_when_config_changes() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var before := w.state_hash()
	c.light_damage = 6.0
	assert_ne(w.state_hash(), before, "config is a tracked sim input (D1)")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_world_movement` → FAIL (`World.fighters`, `Motion`, `Rules` 미정의)

- [ ] **Step 3: Rules (스폰)**

`src/sim/rules.gd`:
```gdscript
class_name Rules
extends RefCounted
## Match rules (PRD §4.1): spawning here; ring-out, stocks, respawn and winner added in Task 7.

const ONGOING := -2
const DRAW := -1
## Fighters spawn on a circle at this fraction of the arena radius.
const SPAWN_RADIUS_RATIO := 0.5


static func spawn_point(index: int, count: int, config: GameConfig) -> Vector3:
	var angle := PI + TAU * float(index) / float(maxi(count, 1))
	var r := config.arena_radius * SPAWN_RADIUS_RATIO
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


static func facing_to_center(pos: Vector3) -> Vector3:
	var flat := Vector3(-pos.x, 0.0, -pos.z)
	return flat.normalized() if flat.length() > 0.0001 else Vector3(0, 0, 1)


static func spawn_fighter(index: int, count: int, config: GameConfig) -> Fighter:
	var f := Fighter.new()
	f.id = index
	f.pos = spawn_point(index, count, config)
	f.facing = facing_to_center(f.pos)
	f.stocks = config.stocks
	f.jumps_left = config.max_jumps
	f.on_ground = true
	return f
```

- [ ] **Step 4: Motion**

`src/sim/motion.gd`:
```gdscript
class_name Motion
extends RefCounted
## Per-tick fighter movement (PRD §4): input -> state, gravity, landing, walking off the edge,
## and capsule separation. Hitstop freezes a fighter completely (PRD §4.2).

## A fighter may land only if it was at most this far below the floor on the previous tick,
## so a fighter falling under the arena never snaps back up.
const LAND_TOLERANCE := 0.05


static func step(f: Fighter, input: InputFrame, config: GameConfig, attack: AttackData) -> void:
	if not f.is_alive():
		return
	if f.hitstop_ticks > 0:
		f.hitstop_ticks -= 1
		return
	if f.invuln_ticks > 0:
		f.invuln_ticks -= 1
	match f.state:
		Fighter.State.HITSTUN:
			_step_hitstun(f, config)
		Fighter.State.ATTACK:
			_step_attack(f, attack)
		_:
			_step_control(f, input, config)
	_integrate(f, config)
	f.state_ticks += 1


static func separate(fighters: Array[Fighter], config: GameConfig) -> void:
	for i: int in fighters.size():
		for j: int in range(i + 1, fighters.size()):
			var a := fighters[i]
			var b := fighters[j]
			if not a.is_alive() or not b.is_alive():
				continue
			var push := Collision.separate_capsules(a.pos, b.pos, config.fighter_radius, config.fighter_height)
			a.pos += push
			b.pos -= push


static func _step_control(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	if input.light:
		f.set_state(Fighter.State.ATTACK)
		f.attack_ticks = 0
		f.hit_ids.clear()
		if f.on_ground:
			f.vel.x = 0.0
			f.vel.z = 0.0
		return
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if input.jump and f.jumps_left > 0:
		f.vel.y = config.jump_velocity
		f.jumps_left -= 1
		f.on_ground = false
	var target := Vector2(dir.x, dir.z) * config.move_speed
	if f.on_ground:
		f.vel.x = target.x
		f.vel.z = target.y
	else:
		# airborne: steer toward the input, or drift with light drag, never snap to zero
		var accel := config.air_acceleration if dir.length_squared() > 0.0 else config.air_drag
		var flat := Vector2(f.vel.x, f.vel.z).move_toward(target, accel * SimTime.TICK_DT)
		f.vel.x = flat.x
		f.vel.z = flat.y
	if dir.length_squared() > 0.0:
		f.facing = dir.normalized()
	if not f.on_ground:
		f.set_state(Fighter.State.AIR)
	elif dir.length_squared() > 0.0:
		f.set_state(Fighter.State.MOVE)
	else:
		f.set_state(Fighter.State.IDLE)


static func _step_attack(f: Fighter, attack: AttackData) -> void:
	f.attack_ticks += 1
	if f.on_ground:
		f.vel.x = 0.0
		f.vel.z = 0.0
	if f.attack_ticks >= attack.total_ticks():
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


static func _step_hitstun(f: Fighter, config: GameConfig) -> void:
	f.hitstun_ticks -= 1
	if f.on_ground:
		f.vel.x *= config.hitstun_ground_friction
		f.vel.z *= config.hitstun_ground_friction
	if f.hitstun_ticks <= 0:
		f.hitstun_ticks = 0
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


static func _integrate(f: Fighter, config: GameConfig) -> void:
	var prev_y := f.pos.y
	f.vel.y += config.gravity * SimTime.TICK_DT
	f.pos += f.vel * SimTime.TICK_DT
	var over_floor := Collision.on_arena_floor(f.pos, config.arena_radius)
	if over_floor and f.pos.y <= 0.0 and prev_y >= -LAND_TOLERANCE and f.vel.y <= 0.0:
		f.pos.y = 0.0
		f.vel.y = 0.0
		if not f.on_ground:
			f.on_ground = true
			f.jumps_left = config.max_jumps
			if f.state == Fighter.State.AIR:
				f.set_state(Fighter.State.IDLE)
		return
	if f.on_ground:
		# walked off the edge: the ground jump is gone, air jumps remain
		f.jumps_left = mini(f.jumps_left, config.max_jumps - 1)
	f.on_ground = false
	if f.state == Fighter.State.IDLE or f.state == Fighter.State.MOVE:
		f.set_state(Fighter.State.AIR)
```

- [ ] **Step 5: World 교체**

`src/sim/world.gd` 전체:
```gdscript
class_name World
extends RefCounted
## Pure game state (PRD §5.2). Never reference Node, SceneTree, Input, RenderingServer or PhysicsServer3D here.
## Tick order: Motion.step per fighter -> Motion.separate -> Combat.resolve -> Rules.apply -> winner.
## The config is a tracked sim input: its fingerprint is part of every snapshot (context D1).

const SNAPSHOT_VERSION := 2
const DEFAULT_PLAYER_COUNT := 2
const SNAPSHOT_TYPES := {
	"tick": TYPE_INT, "rng_seed": TYPE_INT, "rng_state": TYPE_INT, "config_fp": TYPE_INT,
	"match_over": TYPE_BOOL, "winner": TYPE_INT, "fighters": TYPE_ARRAY,
}

var config: GameConfig
var tick_count: int = 0
var fighters: Array[Fighter] = []
var match_over: bool = false
var winner_id: int = Rules.ONGOING
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Events produced by the most recent tick (plain data, e.g. hits and ring-outs).
var _events: Array[Dictionary] = []


func _init(p_config: GameConfig, p_seed: int = 0, p_player_count: int = DEFAULT_PLAYER_COUNT) -> void:
	config = p_config
	_rng.seed = p_seed
	for i: int in p_player_count:
		fighters.append(Rules.spawn_fighter(i, p_player_count, config))


func tick(inputs: Array[InputFrame]) -> void:
	_events = []
	if not match_over:
		var attack := AttackData.light_from(config)
		for f: Fighter in fighters:
			var input: InputFrame = inputs[f.id] if f.id < inputs.size() else InputFrame.neutral()
			Motion.step(f, input, config, attack)
		Motion.separate(fighters, config)
	tick_count += 1


func rand_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Plain value data only (ints/floats/Vector types/Arrays and Dictionaries of the same):
## never references to live sim objects, so the render layer can keep prev/curr copies
## that stay valid after later ticks.
func state_view() -> Dictionary:
	var views: Array[Dictionary] = []
	for f: Fighter in fighters:
		views.append(f.to_view())
	return {
		"tick": tick_count,
		"arena_radius": config.arena_radius,
		"match_over": match_over,
		"winner": winner_id,
		"fighters": views,
		"events": _events.duplicate(true),
	}


func snapshot() -> PackedByteArray:
	var data: Array[Dictionary] = []
	for f: Fighter in fighters:
		data.append(f.to_data())
	return var_to_bytes({
		"v": SNAPSHOT_VERSION,
		"tick": tick_count,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"config_fp": config.fingerprint(),
		"match_over": match_over,
		"winner": winner_id,
		"fighters": data,
	})


func restore(data: PackedByteArray) -> bool:
	var decoded: Variant = bytes_to_var(data) if data.size() > 4 else null
	if not (decoded is Dictionary) or (decoded as Dictionary).get("v") != SNAPSHOT_VERSION:
		push_error("World.restore: incompatible snapshot")
		return false
	var s: Dictionary = decoded
	for key: String in SNAPSHOT_TYPES:
		if not s.has(key) or typeof(s[key]) != SNAPSHOT_TYPES[key]:
			push_error("World.restore: incomplete snapshot")
			return false
	if s["config_fp"] != config.fingerprint():
		push_error("World.restore: config mismatch")
		return false
	var restored: Array[Fighter] = []
	for d: Variant in s["fighters"]:
		var f: Fighter = Fighter.from_data(d) if d is Dictionary else null
		if f == null:
			push_error("World.restore: invalid fighter data")
			return false
		restored.append(f)
	tick_count = s["tick"]
	_rng.seed = s["rng_seed"]
	_rng.state = s["rng_state"]
	match_over = s["match_over"]
	winner_id = s["winner"]
	fighters = restored
	_events = []
	return true


func state_hash() -> int:
	return hash(snapshot())
```

- [ ] **Step 6: 통과 확인**

Run: `scripts/test.sh -gselect=test_world_movement` → 12/12 PASS
Run: `scripts/test.sh -gselect=test_world` → 기존 9개 PASS (버전은 `World.SNAPSHOT_VERSION`으로 참조하므로 그대로 유효)
Run: `scripts/check-all.sh` → `ALL CHECKS PASSED` (main.gd는 기존 `World.new(_config, SEED)` 호출 그대로 동작)

- [ ] **Step 7: 커밋**

```bash
git add src/sim/motion.gd src/sim/motion.gd.uid src/sim/rules.gd src/sim/rules.gd.uid src/sim/world.gd tests/unit/test_world_movement.gd tests/unit/test_world_movement.gd.uid
git commit -m "feat: add fighter movement, spawning and snapshot v2 with config fingerprint

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Combat — 약공격 히트·대미지·넉백·hitstun·hitstop

**Files:**
- Create: `src/sim/combat.gd`
- Modify: `src/sim/world.gd` (`tick()`에 Combat 호출 추가)
- Test: `tests/unit/test_combat.gd`

**Interfaces:**
- Consumes: `Fighter`, `AttackData`, `SimTime` (T4), `Collision.capsule_hits_box`, `Collision.yaw_of` (T3), `World.tick` 순서 (T5)
- Produces: `class_name Combat`
  - `static func knockback(attack: AttackData, target_damage: float, config: GameConfig) -> float`
  - `static func launch_velocity(facing: Vector3, attack: AttackData, knockback_value: float) -> Vector3`
  - `static func hitstun_ticks(knockback_value: float, config: GameConfig) -> int`
  - `static func hitbox_center(attacker: Fighter, attack: AttackData) -> Vector3`
  - `static func resolve(fighters: Array[Fighter], attack: AttackData, config: GameConfig) -> Array[Dictionary]`
  - 히트 이벤트: `{"type": "hit", "attacker": int, "target": int, "pos": Vector3, "knockback": float, "hitstop_ticks": int}` — `state_view()["events"]`로 노출 (T15 연출이 소비)
- 규칙: 대미지를 먼저 더한 뒤 그 %로 넉백 계산 (D7). 공격 한 번에 대상당 1회만 히트 (`hit_ids`). 무적 대상은 무시. 타격 순간 공격자·피격자 모두 `hitstop_ticks` 동안 완전 정지 → 이후 넉백 속도로 날아감
- 근거: `[PRD-RULE-01]` `[PRD-RULE-04]` `[PRD-RULE-05]` `[GD-FEEL-01]`

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_combat.gd`:
```gdscript
extends GutTest


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


## P2 stands 1.0 m in front of P1 (inside the light hitbox).
func _adjacent_world(config: GameConfig = null) -> World:
	var w := World.new(config if config != null else GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	return w


## Presses light on the first tick, then idles until the hit lands (startup + 2 ticks).
func _swing_until_hit(w: World) -> void:
	w.tick(_inputs(InputFrame.make(0, 0, false, true)))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))


func test_knockback_formula_at_0_50_150_percent() -> void:
	var c := GameConfig.new()
	var a := AttackData.light_from(c)
	assert_almost_eq(Combat.knockback(a, 0.0, c), 3.0, 0.0001)
	assert_almost_eq(Combat.knockback(a, 50.0, c), 5.5, 0.0001)
	assert_almost_eq(Combat.knockback(a, 150.0, c), 10.5, 0.0001)
	c.global_knockback_mul = 2.0
	assert_almost_eq(Combat.knockback(a, 150.0, c), 21.0, 0.0001)


func test_hitstun_scales_with_knockback() -> void:
	var c := GameConfig.new()
	assert_eq(Combat.hitstun_ticks(10.5, c), 25, "10.5 * 0.04 s = 0.42 s = 25.2 ticks")
	assert_eq(Combat.hitstun_ticks(0.0, c), 0)


func test_launch_velocity_direction_and_speed() -> void:
	var a := AttackData.light_from(GameConfig.new())
	var v := Combat.launch_velocity(Vector3(1, 0, 0), a, 10.0)
	assert_almost_eq(v.length(), 10.0, 0.0001)
	assert_almost_eq(v.y / v.x, a.launch_angle_y, 0.0001)
	assert_eq(v.z, 0.0)


func test_light_hits_after_startup_and_applies_damage() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var target := w.fighters[1]
	assert_eq(target.damage, 4.0)
	assert_eq(target.state, Fighter.State.HITSTUN)
	var events: Array = w.state_view()["events"]
	assert_eq(events.size(), 1)
	var e: Dictionary = events[0]
	assert_eq(e["type"], "hit")
	assert_eq(e["attacker"], 0)
	assert_eq(e["target"], 1)
	assert_almost_eq(e["knockback"], Combat.knockback(AttackData.light_from(w.config), 4.0, w.config), 0.0001)


func test_hitstop_freezes_both_then_target_flies() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var stop := AttackData.light_from(w.config).hitstop_ticks
	assert_eq(w.fighters[0].hitstop_ticks, stop)
	assert_eq(w.fighters[1].hitstop_ticks, stop)
	var p1_at_hit := w.fighters[0].pos
	var p2_at_hit := w.fighters[1].pos
	for i: int in stop:
		w.tick(_inputs(InputFrame.make(1, 0), InputFrame.make(-1, 0)))
	assert_eq(w.fighters[0].pos, p1_at_hit, "attacker frozen during hitstop")
	assert_eq(w.fighters[1].pos, p2_at_hit, "target frozen during hitstop")
	w.tick(_inputs(InputFrame.neutral()))
	assert_gt(w.fighters[1].pos.x, p2_at_hit.x, "knocked away along attacker facing")
	assert_gt(w.fighters[1].pos.y, p2_at_hit.y, "launched upward")


func test_hitstun_ignores_movement_input() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var stop := AttackData.light_from(w.config).hitstop_ticks
	for i: int in stop + 3:
		w.tick(_inputs(InputFrame.neutral(), InputFrame.make(-1, 0)))
	assert_eq(w.fighters[1].state, Fighter.State.HITSTUN)
	assert_gt(w.fighters[1].vel.x, 0.0, "input -x does not override knockback")


func test_one_hit_per_swing() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	for i: int in 20:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[1].damage, 4.0)


func test_invulnerable_target_is_not_hit() -> void:
	var w := _adjacent_world()
	w.fighters[1].invuln_ticks = 100
	_swing_until_hit(w)
	assert_eq(w.fighters[1].damage, 0.0)
	assert_eq((w.state_view()["events"] as Array).size(), 0)


func test_facing_away_misses() -> void:
	var w := _adjacent_world()
	w.fighters[0].facing = Vector3(-1, 0, 0)
	_swing_until_hit(w)
	assert_eq(w.fighters[1].damage, 0.0)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_combat` → FAIL (`Combat` 미정의)

- [ ] **Step 3: Combat 구현**

`src/sim/combat.gd`:
```gdscript
class_name Combat
extends RefCounted
## Hit resolution (PRD §4.2): active hitboxes vs fighter capsules, damage %, knockback formula,
## hitstun and hitstop. Damage is added before knockback is computed (context D7).


static func knockback(attack: AttackData, target_damage: float, config: GameConfig) -> float:
	return (attack.base_knockback + target_damage * attack.knockback_scaling) * config.global_knockback_mul


static func launch_velocity(facing: Vector3, attack: AttackData, knockback_value: float) -> Vector3:
	var dir := Vector3(facing.x, attack.launch_angle_y, facing.z)
	if dir.length() <= 0.0:
		return Vector3.ZERO
	return dir.normalized() * knockback_value


static func hitstun_ticks(knockback_value: float, config: GameConfig) -> int:
	return SimTime.to_ticks(knockback_value * config.hitstun_factor)


static func hitbox_center(attacker: Fighter, attack: AttackData) -> Vector3:
	return attacker.pos + attacker.facing * attack.hitbox_forward + Vector3.UP * attack.hitbox_up


static func resolve(fighters: Array[Fighter], attack: AttackData, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for attacker: Fighter in fighters:
		if attacker.state != Fighter.State.ATTACK or not attack.is_active(attacker.attack_ticks):
			continue
		var center := hitbox_center(attacker, attack)
		var yaw := Collision.yaw_of(attacker.facing)
		for target: Fighter in fighters:
			if target == attacker or not target.is_alive() or target.invuln_ticks > 0:
				continue
			if attacker.hit_ids.has(target.id):
				continue
			if Collision.capsule_hits_box(target.pos, config.fighter_radius, config.fighter_height,
					center, yaw, attack.hitbox_half):
				events.append(_apply_hit(attacker, target, attack, config, center))
	return events


static func _apply_hit(attacker: Fighter, target: Fighter, attack: AttackData,
		config: GameConfig, at: Vector3) -> Dictionary:
	attacker.hit_ids.append(target.id)
	target.damage += attack.damage
	var kb := knockback(attack, target.damage, config)
	target.vel = launch_velocity(attacker.facing, attack, kb)
	if target.vel.y > 0.0:
		target.on_ground = false
	target.hitstun_ticks = hitstun_ticks(kb, config)
	target.attack_ticks = 0
	target.hit_ids.clear()
	target.set_state(Fighter.State.HITSTUN)
	target.hitstop_ticks = attack.hitstop_ticks
	attacker.hitstop_ticks = attack.hitstop_ticks
	return {
		"type": "hit", "attacker": attacker.id, "target": target.id, "pos": at,
		"knockback": kb, "hitstop_ticks": attack.hitstop_ticks,
	}
```

- [ ] **Step 4: World.tick에 연결**

`src/sim/world.gd`의 `tick()`에서 `Motion.separate(fighters, config)` 바로 아래에 추가:
```gdscript
		_events.append_array(Combat.resolve(fighters, attack, config))
```

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh -gselect=test_combat` → 9/9 PASS · `scripts/test.sh` 전체 PASS · `scripts/check-sim-purity.sh` → OK

- [ ] **Step 6: 커밋**

```bash
git add src/sim/combat.gd src/sim/combat.gd.uid src/sim/world.gd tests/unit/test_combat.gd tests/unit/test_combat.gd.uid
git commit -m "feat: add light attack hits with knockback, hitstun and hitstop

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Rules — 링아웃·스톡·리스폰·승패

**Files:**
- Modify: `src/sim/rules.gd` (함수 추가), `src/sim/world.gd` (`tick()`에 Rules·승패 추가)
- Test: `tests/unit/test_rules.gd`

**Interfaces:**
- Consumes: `Rules.spawn_point`, `Rules.facing_to_center`, `Rules.ONGOING/DRAW` (T5), `Collision.is_out_of_bounds` (T3), `SimTime.to_ticks` (T4)
- Produces:
  - `static func respawn(f: Fighter, count: int, config: GameConfig) -> void` — 스폰 지점 위 `respawn_height` 공중, 속도 0, 대미지 0, `invuln_ticks = to_ticks(respawn_invuln)`, `spawn_id += 1`, 점프 회복, 상태 AIR
  - `static func apply(fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]` — 링아웃된 파이터마다 스톡 -1, 남으면 리스폰, 0이면 KO. 이벤트 `{"type": "ringout", "id": int, "pos": Vector3, "stocks_left": int}`
  - `static func winner(fighters: Array[Fighter]) -> int` — 살아 있는 파이터가 1명이면 그 id, 0명이면 `DRAW`, 2명 이상이면 `ONGOING`
  - `World.tick`: Combat 뒤에 `Rules.apply`, 이어서 승패가 정해지면 `match_over = true`, `winner_id` 설정. 경기가 끝나면 이후 틱은 `tick_count`만 증가
- 근거: `[PRD-RULE-02]` `[PRD-RULE-03]` `[PRD-UI-01]`

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_rules.gd`:
```gdscript
extends GutTest


func _neutral() -> Array[InputFrame]:
	var a: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	return a


func test_falling_below_kill_y_costs_a_stock_and_respawns_invulnerable() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var f := w.fighters[1]
	f.damage = 80.0
	f.pos = Vector3(3, c.kill_y - 0.5, 0)
	f.on_ground = false
	w.tick(_neutral())
	assert_eq(f.stocks, c.stocks - 1)
	assert_eq(f.damage, 0.0)
	assert_eq(f.spawn_id, 1)
	assert_eq(f.invuln_ticks, SimTime.to_ticks(c.respawn_invuln))
	assert_almost_eq(f.pos.y, c.respawn_height, 0.0001)
	assert_eq(f.state, Fighter.State.AIR)
	var events: Array = w.state_view()["events"]
	assert_eq((events[0] as Dictionary)["type"], "ringout")
	assert_eq((events[0] as Dictionary)["stocks_left"], c.stocks - 1)


func test_leaving_blast_zone_horizontally_rings_out() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(c.arena_radius + c.blast_margin + 0.5, 2, 0)
	w.fighters[0].on_ground = false
	w.tick(_neutral())
	assert_eq(w.fighters[0].stocks, c.stocks - 1)


func test_respawn_invulnerability_counts_down_and_blocks_hits() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].pos = Vector3(0, c.kill_y - 1, 0)
	w.tick(_neutral())
	var invuln := w.fighters[1].invuln_ticks
	w.tick(_neutral())
	assert_eq(w.fighters[1].invuln_ticks, invuln - 1)
	# a hit attempt during invulnerability does nothing
	var attacker := w.fighters[0]
	attacker.pos = w.fighters[1].pos - Vector3(1.0, 0, 0)
	attacker.facing = Vector3(1, 0, 0)
	var a: Array[InputFrame] = [InputFrame.make(0, 0, false, true), InputFrame.neutral()]
	w.tick(a)
	for i: int in c.light_startup_ticks + 1:
		w.tick(_neutral())
	assert_eq(w.fighters[1].damage, 0.0)


func test_last_stock_lost_means_ko_and_winner() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, c.kill_y - 1, 0)
	w.tick(_neutral())
	assert_eq(w.fighters[1].state, Fighter.State.KO)
	assert_false(w.fighters[1].is_alive())
	assert_true(w.match_over)
	assert_eq(w.winner_id, 0)
	var view := w.state_view()
	assert_true(view["match_over"])
	assert_eq(view["winner"], 0)


func test_simultaneous_last_stocks_is_a_draw() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	for f: Fighter in w.fighters:
		f.stocks = 1
		f.pos = Vector3(f.pos.x, c.kill_y - 1, 0)
	w.tick(_neutral())
	assert_true(w.match_over)
	assert_eq(w.winner_id, Rules.DRAW)


func test_winner_rule() -> void:
	var a := Fighter.new()
	var b := Fighter.new()
	b.id = 1
	var fighters: Array[Fighter] = [a, b]
	assert_eq(Rules.winner(fighters), Rules.ONGOING)
	b.set_state(Fighter.State.KO)
	assert_eq(Rules.winner(fighters), 0)


func test_after_match_over_the_world_stops_simulating() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, c.kill_y - 1, 0)
	w.tick(_neutral())
	var frozen := w.fighters[0].pos
	var a: Array[InputFrame] = [InputFrame.make(1, 0), InputFrame.neutral()]
	w.tick(a)
	assert_eq(w.fighters[0].pos, frozen)
	assert_eq(w.tick_count, 2)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_rules` → FAIL (`Rules.apply` 등 미정의, 스톡 감소 없음)

- [ ] **Step 3: Rules 추가**

`src/sim/rules.gd` 파일 끝에 추가:
```gdscript


static func respawn(f: Fighter, count: int, config: GameConfig) -> void:
	f.pos = spawn_point(f.id, count, config) + Vector3.UP * config.respawn_height
	f.vel = Vector3.ZERO
	f.facing = facing_to_center(f.pos)
	f.damage = 0.0
	f.on_ground = false
	f.jumps_left = config.max_jumps
	f.hitstun_ticks = 0
	f.hitstop_ticks = 0
	f.attack_ticks = 0
	f.hit_ids.clear()
	f.invuln_ticks = SimTime.to_ticks(config.respawn_invuln)
	f.spawn_id += 1
	f.set_state(Fighter.State.AIR)


static func apply(fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if not f.is_alive():
			continue
		if not Collision.is_out_of_bounds(f.pos, config.arena_radius, config.blast_margin, config.kill_y):
			continue
		var at := f.pos
		f.stocks -= 1
		if f.stocks > 0:
			respawn(f, fighters.size(), config)
		else:
			f.vel = Vector3.ZERO
			f.set_state(Fighter.State.KO)
		events.append({"type": "ringout", "id": f.id, "pos": at, "stocks_left": f.stocks})
	return events


static func winner(fighters: Array[Fighter]) -> int:
	var alive: Array[int] = []
	for f: Fighter in fighters:
		if f.is_alive():
			alive.append(f.id)
	if alive.size() == 1:
		return alive[0]
	if alive.is_empty():
		return DRAW
	return ONGOING
```

- [ ] **Step 4: World.tick에 연결**

`src/sim/world.gd`의 `tick()`에서 Combat 줄 아래에 추가:
```gdscript
		_events.append_array(Rules.apply(fighters, config))
		var result := Rules.winner(fighters)
		if result != Rules.ONGOING:
			match_over = true
			winner_id = result
```

`tick()`은 최종적으로 다음과 같다:
```gdscript
func tick(inputs: Array[InputFrame]) -> void:
	_events = []
	if not match_over:
		var attack := AttackData.light_from(config)
		for f: Fighter in fighters:
			var input: InputFrame = inputs[f.id] if f.id < inputs.size() else InputFrame.neutral()
			Motion.step(f, input, config, attack)
		Motion.separate(fighters, config)
		_events.append_array(Combat.resolve(fighters, attack, config))
		_events.append_array(Rules.apply(fighters, config))
		var result := Rules.winner(fighters)
		if result != Rules.ONGOING:
			match_over = true
			winner_id = result
	tick_count += 1
```

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh -gselect=test_rules` → 7/7 PASS · `scripts/test.sh` 전체 PASS · `scripts/check-sim-purity.sh` → OK

- [ ] **Step 6: 커밋**

```bash
git add src/sim/rules.gd src/sim/world.gd tests/unit/test_rules.gd tests/unit/test_rules.gd.uid
git commit -m "feat: add ring-out, stocks, respawn invulnerability and winner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 리플레이 하네스

**Files:**
- Create: `tests/replay/test_replay.gd`
- Modify: `scripts/test.sh` (`tests/replay` 포함)

**Interfaces:**
- Consumes: `World` 전체 (T5~T7), `InputFrame.make` (T2)
- Produces: 리플레이 회귀 게이트 — 이후 sim을 바꾸는 모든 태스크는 이 테스트를 통과하거나, 의도된 변경이면 골든 값을 갱신하고 커밋 메시지에 이유를 적는다
- 근거: `[PRD-ARCH-04]` `[PRD-ARCH-05]` `[PRD-NFR-06]`, context D3

- [ ] **Step 1: 테스트 러너가 replay 폴더도 돌도록 수정**

`scripts/test.sh`의 GUT 실행 줄을:
```bash
  -gdir=res://tests/unit,res://tests/replay -ginclude_subdirs -gexit "$@"
```

- [ ] **Step 2: 리플레이 테스트 작성**

`tests/replay/test_replay.gd`:
```gdscript
extends GutTest
## Replay regression (context D3): seed + config + scripted inputs -> state_hash sequence.
## GOLDEN_HASH guards against unintended sim changes. When a sim change is deliberate,
## re-run this file, copy the printed value into GOLDEN_HASH and say why in the commit message.
## The golden value is tied to the Godot version (4.7.2) because it hashes engine floats.

const SEED := 7
const TICKS := 600
const HALF := 300
const GOLDEN_HASH := 0


static func _script_input(player: int, t: int) -> InputFrame:
	if player == 0:
		var mx := 1.0 if floori(t / 90.0) % 2 == 0 else -1.0
		return InputFrame.make(mx, 0.3, t % 45 == 0, t % 20 == 10)
	var mz := -1.0 if floori(t / 70.0) % 2 == 0 else 1.0
	return InputFrame.make(-0.5, mz, t % 60 == 30, t % 25 == 5)


static func _inputs_at(t: int) -> Array[InputFrame]:
	var a: Array[InputFrame] = [_script_input(0, t), _script_input(1, t)]
	return a


## Runs `ticks` ticks from the world's current tick and returns a hash of the per-tick state hashes.
static func _run(w: World, ticks: int) -> int:
	var seq: Array[int] = []
	for i: int in ticks:
		w.tick(_inputs_at(w.tick_count))
		seq.append(w.state_hash())
	return hash(seq)


func test_same_inputs_give_identical_runs() -> void:
	var a := _run(World.new(GameConfig.new(), SEED), TICKS)
	var b := _run(World.new(GameConfig.new(), SEED), TICKS)
	assert_eq(a, b)


func test_restore_then_continue_matches_uninterrupted_run() -> void:
	var config := GameConfig.new()
	var straight := World.new(config, SEED)
	_run(straight, HALF)
	var snap := straight.snapshot()
	var second_half_straight := _run(straight, TICKS - HALF)
	var resumed := World.new(config, SEED)
	assert_true(resumed.restore(snap))
	assert_eq(_run(resumed, TICKS - HALF), second_half_straight)


func test_the_script_actually_fights() -> void:
	var w := World.new(GameConfig.new(), SEED)
	var hits := 0
	for i: int in TICKS:
		w.tick(_inputs_at(w.tick_count))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hits += 1
	assert_gt(hits, 0, "the scripted inputs must exercise combat, or the golden hash guards nothing")


func test_config_changes_the_run() -> void:
	var other := GameConfig.new()
	other.move_speed = 6.5
	assert_ne(_run(World.new(other, SEED), TICKS), _run(World.new(GameConfig.new(), SEED), TICKS))


func test_golden_hash() -> void:
	var h := _run(World.new(GameConfig.new(), SEED), TICKS)
	assert_ne(GOLDEN_HASH, 0, "GOLDEN_HASH not set yet; set it to %d" % h)
	assert_eq(h, GOLDEN_HASH, "sim behavior changed; if deliberate, update GOLDEN_HASH to %d" % h)
```

- [ ] **Step 3: 실행 — 골든 테스트만 실패해야 한다**

Run: `scripts/test.sh -gselect=test_replay`
Expected: 4 PASS, `test_golden_hash` FAIL with message `GOLDEN_HASH not set yet; set it to <N>`.
`test_the_script_actually_fights`가 실패하면 스크립트 입력이 두 파이터를 만나게 하지 못하는 것이다 — 이때는 `_script_input`의 P2 `move_x`를 `-1.0`으로 바꿔 서로 다가가게 하고 다시 돌린다.

- [ ] **Step 4: 골든 값 기록**

출력된 `<N>`을 `const GOLDEN_HASH := <N>`에 넣는다.

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh -gselect=test_replay` → 5/5 PASS · `scripts/check-all.sh` → `ALL CHECKS PASSED`

- [ ] **Step 6: 커밋**

```bash
git add scripts/test.sh tests/replay/test_replay.gd tests/replay/test_replay.gd.uid
git commit -m "test: add replay regression harness with golden hash

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: 봇 1단계

**Files:**
- Create: `src/input/bot_controller.gd`
- Test: `tests/unit/test_bot.gd`

**Interfaces:**
- Consumes: `World.state_view()` 구조 (T5) — `fighters[i]`의 `id, pos, facing, state, on_ground, jumps_left`, 루트의 `arena_radius`; `GameConfig.bot_*` (T1); `InputFrame.make` (T2)
- Produces: `class_name BotController extends RefCounted` — `func _init(p_self_id: int, p_config: GameConfig)`, `func sample(view: Dictionary) -> InputFrame`
- 규칙 (우선순위 순):
  1. 자기가 없거나 KO → neutral
  2. 경기장 밖 공중에서 떨어지는 중(`!on_ground`, 수평 거리 > 반경, `pos.y < 0`) → 중앙 방향 + `jumps_left > 0`이면 점프
  3. 수평 거리 > `arena_radius × bot_edge_ratio` → 중앙으로 이동
  4. 가장 가까운 살아 있는 상대가 `bot_attack_range` 안이고 쿨다운 0 → 상대 방향으로 이동 입력 + 약공격 (쿨다운 = `bot_attack_cooldown_ticks`)
  5. 그 외 → 가장 가까운 상대에게 접근
- 봇은 sim 밖(`src/input/`)에 있고 `state_view()` 값만 읽는다. 난수를 쓰지 않아 결정적이다
- 근거: `[PRD-BOT-01]` `[PRD-CTL-01]`

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_bot.gd`:
```gdscript
extends GutTest


func _view(me_pos: Vector3, foe_pos: Vector3, me_on_ground: bool = true, jumps: int = 2) -> Dictionary:
	return {
		"arena_radius": 10.0,
		"fighters": [
			{"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": Fighter.State.IDLE, "on_ground": true, "jumps_left": 2},
			{"id": 1, "pos": me_pos, "facing": Vector3(-1, 0, 0), "state": Fighter.State.IDLE, "on_ground": me_on_ground, "jumps_left": jumps},
		],
	}


func test_approaches_the_opponent() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(5, 0, 0), Vector3(-2, 0, 0)))
	assert_lt(f.move_x, 0.0)
	assert_false(f.light)


func test_attacks_in_range_then_waits_for_cooldown() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	assert_true(bot.sample(v).light, "in range and ready")
	var waited := 0
	for i: int in 1000:
		if bot.sample(v).light:
			break
		waited += 1
	# cooldown N set on the attack sample, decremented at the start of each later sample
	assert_eq(waited, c.bot_attack_cooldown_ticks - 1)


func test_returns_to_center_near_the_edge() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(9.0, 0, 0), Vector3(9.5, 0, 1.0)))
	assert_lt(f.move_x, 0.0, "moves toward center even though the foe is right there")
	assert_false(f.light)


func test_recovers_with_jump_when_falling_off_stage() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(11.0, -0.5, 0), Vector3(0, 0, 0), false, 1))
	assert_lt(f.move_x, 0.0)
	assert_true(f.jump)
	var no_jumps := bot.sample(_view(Vector3(11.0, -0.5, 0), Vector3(0, 0, 0), false, 0))
	assert_false(no_jumps.jump)


func test_ko_bot_does_nothing() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(1, 0, 0), Vector3(0, 0, 0))
	(v["fighters"][1] as Dictionary)["state"] = Fighter.State.KO
	var f := bot.sample(v)
	assert_eq(f.move_x, 0.0)
	assert_false(f.light or f.jump)


func test_bot_drives_a_real_world_into_combat() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var bot := BotController.new(1, c)
	var hit := false
	for i: int in 300:
		var inputs: Array[InputFrame] = [InputFrame.neutral(), bot.sample(w.state_view())]
		w.tick(inputs)
		if w.fighters[0].damage > 0.0:
			hit = true
			break
	assert_true(hit, "bot walks over and lands a light attack on an idle player")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_bot` → FAIL (`BotController` 미정의)

- [ ] **Step 3: 구현**

`src/input/bot_controller.gd`:
```gdscript
class_name BotController
extends RefCounted
## Phase 1 bot (PRD §6.4, step 1): approach, attack in range, retreat from the edge, jump back
## when falling off. Reads only World.state_view() values and produces InputFrames — never
## touches the sim directly. Deterministic (no randomness).

var _self_id: int
var _config: GameConfig
var _cooldown: int = 0


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config


func sample(view: Dictionary) -> InputFrame:
	if _cooldown > 0:
		_cooldown -= 1
	var me := _find(view, _self_id)
	if me.is_empty() or int(me["state"]) == Fighter.State.KO:
		return InputFrame.neutral()
	var my_pos: Vector3 = me["pos"]
	var flat := Vector2(my_pos.x, my_pos.z)
	var radius: float = view["arena_radius"]
	var to_center := -flat.normalized() if flat.length() > 0.001 else Vector2.ZERO

	if not bool(me["on_ground"]) and flat.length() > radius and my_pos.y < 0.0:
		return InputFrame.make(to_center.x, to_center.y, int(me["jumps_left"]) > 0)
	if flat.length() > radius * _config.bot_edge_ratio:
		return InputFrame.make(to_center.x, to_center.y)

	var foe := _nearest_foe(view, my_pos)
	if foe.is_empty():
		return InputFrame.neutral()
	var foe_pos: Vector3 = foe["pos"]
	var delta := Vector2(foe_pos.x - my_pos.x, foe_pos.z - my_pos.z)
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if delta.length() <= _config.bot_attack_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		return InputFrame.make(dir.x, dir.y, false, true)
	return InputFrame.make(dir.x, dir.y)


static func _find(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


func _nearest_foe(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == _self_id or int(f["state"]) == Fighter.State.KO:
			continue
		var p: Vector3 = f["pos"]
		var d := Vector2(p.x - my_pos.x, p.z - my_pos.z).length()
		if d < best_dist:
			best_dist = d
			best = f
	return best
```

Note: 약공격 입력이 들어간 틱에는 sim이 방향을 갱신하지 않으므로(`Motion._step_control`은 공격 시작을 먼저 처리), 봇은 접근하는 동안의 이동으로 이미 상대를 바라보고 있다.

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_bot` → 6/6 PASS · `scripts/check-all.sh` → PASS

- [ ] **Step 5: 커밋**

```bash
git add src/input/bot_controller.gd src/input/bot_controller.gd.uid tests/unit/test_bot.gd tests/unit/test_bot.gd.uid
git commit -m "feat: add phase 1 bot controller

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: 키보드 입력 — InputBindings + LocalInput

**Files:**
- Create: `src/input/input_bindings.gd`, `src/input/local_input.gd`
- Test: `tests/unit/test_input_bindings.gd`

**Interfaces:**
- Consumes: `ButtonLatch` (T2), `InputFrame.make` (T2)
- Produces:
  - `class_name InputBindings` — `const P1: Dictionary` (액션 → 키 목록), `static func apply() -> void` (없는 액션·키만 추가, 여러 번 불러도 안전)
  - `class_name LocalInput extends RefCounted` — `func poll() -> void` (매 프레임 1회: 액션 누름을 래치), `func press_jump() -> void`, `func press_light() -> void` (터치가 호출), `func sample() -> InputFrame` (틱마다 1회)
  - 액션 이름: `p1_left, p1_right, p1_up, p1_down, p1_jump, p1_light, p1_heavy, p1_guard, p1_grab` (Phase 1은 이동·점프·약공격만 사용)
- 좌표: `Input.get_vector(left, right, up, down)`의 y는 화면 위가 음수 → 카메라가 +z 쪽에서 보므로 `move_z = y`가 그대로 "화면 위 = 멀어지는 방향"이다
- 근거: `[PRD-CTL-02]` `[PRD-CTL-01]` `[PRD-NFR-03]`

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_input_bindings.gd`:
```gdscript
extends GutTest


func before_each() -> void:
	InputBindings.apply()


func after_each() -> void:
	for action: String in InputBindings.P1:
		Input.action_release(action)


func test_all_p1_actions_exist_with_their_keys() -> void:
	for action: String in InputBindings.P1:
		assert_true(InputMap.has_action(action), action)
		var keys: Array[int] = []
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey:
				keys.append((ev as InputEventKey).physical_keycode)
		for key: int in InputBindings.P1[action]:
			assert_has(keys, key, "%s bound to %d" % [action, key])


func test_apply_is_idempotent() -> void:
	InputBindings.apply()
	InputBindings.apply()
	assert_eq(InputMap.action_get_events("p1_jump").size(), (InputBindings.P1["p1_jump"] as Array).size())


func test_local_input_reads_move_actions() -> void:
	var local := LocalInput.new()
	Input.action_press("p1_right")
	Input.action_press("p1_up")
	var f := local.sample()
	assert_gt(f.move_x, 0.0)
	assert_lt(f.move_z, 0.0, "screen up is away from the camera (-z)")
	assert_almost_eq(Vector2(f.move_x, f.move_z).length(), 1.0, 0.02, "diagonal is normalized")


func test_latched_press_reaches_exactly_one_tick() -> void:
	var local := LocalInput.new()
	local.press_jump()
	local.press_light()
	var first := local.sample()
	var second := local.sample()
	assert_true(first.jump and first.light)
	assert_false(second.jump or second.light)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_input_bindings` → FAIL (`InputBindings`, `LocalInput` 미정의)

- [ ] **Step 3: 구현**

`src/input/input_bindings.gd`:
```gdscript
class_name InputBindings
extends RefCounted
## Default P1 keyboard bindings (PRD §3.2) registered as InputMap actions at startup.
## Game code reads actions, never raw keys, so rebinding only edits InputMap.

const P1 := {
	"p1_left": [KEY_A], "p1_right": [KEY_D], "p1_up": [KEY_W], "p1_down": [KEY_S],
	"p1_jump": [KEY_SPACE], "p1_light": [KEY_J], "p1_heavy": [KEY_K],
	"p1_guard": [KEY_L], "p1_grab": [KEY_U],
}


static func apply() -> void:
	for action: String in P1:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in P1[action]:
			if not _has_key(action, key):
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


static func _has_key(action: String, key: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return true
	return false
```

`src/input/local_input.gd`:
```gdscript
class_name LocalInput
extends RefCounted
## Local player input (PRD §3.1): keyboard actions -> one InputFrame per sim tick.
## Button presses are latched once per rendered frame (poll) and consumed per tick (context D6).
## Touch controls feed the same latches through press_jump / press_light (Task 11).

var _jump := ButtonLatch.new()
var _light := ButtonLatch.new()


func poll() -> void:
	if Input.is_action_just_pressed("p1_jump"):
		_jump.press()
	if Input.is_action_just_pressed("p1_light"):
		_light.press()


func press_jump() -> void:
	_jump.press()


func press_light() -> void:
	_light.press()


func sample() -> InputFrame:
	var move := _move_vector()
	return InputFrame.make(move.x, move.y, _jump.consume(), _light.consume())


func _move_vector() -> Vector2:
	return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_input_bindings` → 4/4 PASS · `scripts/check-all.sh` → PASS

- [ ] **Step 5: 커밋**

```bash
git add src/input/input_bindings.gd src/input/input_bindings.gd.uid src/input/local_input.gd src/input/local_input.gd.uid tests/unit/test_input_bindings.gd tests/unit/test_input_bindings.gd.uid
git commit -m "feat: add P1 keyboard bindings and latched local input

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: 터치 기본 — 플로팅 스틱 + 점프 + 공격, TouchStick·TouchButton v1

**Files:**
- Create: `src/input/touch_stick_model.gd`, `src/input/touch_input.gd`, `src/ui/components/touch_stick/touch_stick.gd` + `.tscn`, `src/ui/components/touch_button/touch_button.gd` + `.tscn`
- Modify: `src/ui/theme/tokens.gd` (반투명 표면·눌림 스쿼시 토큰), `docs/design.md` (토큰 표 동기화), `src/config/game_config.gd` (Touch 그룹), `src/input/local_input.gd` (터치 스틱 연결), `src/debug/ds_gallery.gd` (컴포넌트 등록 + `set_preview`)
- Test: `tests/unit/test_touch_stick_model.gd`, `tests/unit/test_touch_input.gd`

**Interfaces:**
- Consumes: `LocalInput.press_jump/press_light` (T10), `DS` 토큰, `GameConfig`
- Produces:
  - `DS.UI_SURFACE_50 := Color("#FFFDF680")`, `DS.UI_SURFACE_70 := Color("#FFFDF6B3")`, `DS.PRESS_SQUISH := Vector2(1.04, 0.92)`
  - `GameConfig` Touch 그룹: `touch_stick_radius: float = 140.0`, `touch_stick_deadzone: float = 0.15`, `touch_attack_diameter: float = 170.0`, `touch_jump_diameter: float = 130.0` (플레이어가 조절할 조작 크기이므로 GameConfig — DS-A11Y-03)
  - `class_name TouchStickModel` — `_init(p_radius: float, p_deadzone: float)`, `begin(p: Vector2)`, `move(p: Vector2)`, `end()`, `active() -> bool`, `center() -> Vector2`, `knob() -> Vector2`, `vector() -> Vector2` (반경으로 정규화, 데드존 안이면 0, 길이 ≤ 1, 화면 y 아래 = +z)
  - `LocalInput.touch_stick: TouchStickModel` — 활성이면 키보드 대신 스틱 벡터 사용
  - `class_name TouchStick extends Control` — `show_stick(center: Vector2, knob: Vector2, radius: float)`, `hide_stick()`, `set_preview()`
  - `class_name TouchButton extends Control` — `enum State { IDLE, PRESSED }`, `@export label_text: String`, `@export diameter: float`, `set_state(s: int)`, `contains(point: Vector2) -> bool`, `set_preview()`
  - `class_name TouchInput extends CanvasLayer` — `setup(local: LocalInput, config: GameConfig)`, `attack_center() -> Vector2`, `jump_center() -> Vector2`, `stick_zone_point() -> Vector2`
  - 갤러리 규약: 컴포넌트가 `set_preview()`를 가지면 갤러리가 인스턴스 직후 호출해 데모 값을 보여준다
- 동작: 스틱 영역 = 화면 왼쪽 40% × 아래 70%. 점프는 누를 때, 공격은 뗄 때(탭) 약공격. 손가락 index ≥ 3(4손가락 탭)은 디버그 패널 몫이라 무시. 디버그 빌드에서는 마우스 왼쪽 버튼을 손가락 0으로 취급 (데스크톱 테스트용). 터치가 한 번이라도 들어오거나 터치스크린이 있으면 표시
- 근거: `[PRD-CTL-03]` `[PRD-CTL-04]` `[DS-CMP-03]` `[DS-CMP-04]` `[DS-LAY-01]` `[DS-TOK-01]` `[DS-TOK-05]`

- [ ] **Step 1: 토큰 추가 + design.md 동기화**

`src/ui/theme/tokens.gd`의 `const TRANSPARENT` 아래에 추가:
```gdscript
## Translucent cream surfaces for touch controls over the 3D scene (design.md DS-LAY-01).
const UI_SURFACE_50 := Color("#FFFDF680")
const UI_SURFACE_70 := Color("#FFFDF6B3")
```
`const MOTION_SLOW` 아래에 추가:
```gdscript
## Button press squish (design.md DS-TOK-05).
const PRESS_SQUISH := Vector2(1.04, 0.92)
```
`docs/design.md` §3 UI 팔레트 표에서 `ui_surface_dim` 행 아래에 두 행을 추가:
```markdown
| `ui_surface_50` | `#FFFDF6` 50% | 가상 스틱 바탕 |
| `ui_surface_70` | `#FFFDF6` 70% | 터치 버튼 바탕 |
```
그리고 DS-TOK-05의 "버튼 눌림" 줄 끝에 ` — 토큰 `PRESS_SQUISH`` 를 덧붙인다.

- [ ] **Step 2: GameConfig Touch 그룹 확장**

`src/config/game_config.gd`의 `touch_hold_threshold` 아래에 추가:
```gdscript
@export_range(60.0, 300.0, 5.0) var touch_stick_radius: float = 140.0
@export_range(0.0, 0.5, 0.01) var touch_stick_deadzone: float = 0.15
@export_range(96.0, 300.0, 2.0) var touch_attack_diameter: float = 170.0
@export_range(96.0, 300.0, 2.0) var touch_jump_diameter: float = 130.0
```

- [ ] **Step 3: 실패하는 테스트**

`tests/unit/test_touch_stick_model.gd`:
```gdscript
extends GutTest


func test_inactive_stick_reads_zero() -> void:
	assert_eq(TouchStickModel.new(100.0, 0.15).vector(), Vector2.ZERO)


func test_vector_is_normalized_by_radius_and_clamped() -> void:
	var m := TouchStickModel.new(100.0, 0.15)
	m.begin(Vector2(200, 500))
	m.move(Vector2(250, 500))
	assert_almost_eq(m.vector().x, 0.5, 0.0001)
	m.move(Vector2(500, 500))
	assert_almost_eq(m.vector().length(), 1.0, 0.0001, "clamped to unit length")
	assert_eq(m.knob(), Vector2(300, 500), "knob stops at the rim")


func test_dead_zone_reads_zero() -> void:
	var m := TouchStickModel.new(100.0, 0.15)
	m.begin(Vector2(0, 0))
	m.move(Vector2(10, 0))
	assert_eq(m.vector(), Vector2.ZERO)


func test_screen_down_is_positive() -> void:
	var m := TouchStickModel.new(100.0, 0.0)
	m.begin(Vector2(0, 0))
	m.move(Vector2(0, 80))
	assert_gt(m.vector().y, 0.0, "screen down = toward the camera = +z")


func test_end_releases() -> void:
	var m := TouchStickModel.new(100.0, 0.0)
	m.begin(Vector2(0, 0))
	m.move(Vector2(50, 0))
	m.end()
	assert_false(m.active())
	assert_eq(m.vector(), Vector2.ZERO)
```

`tests/unit/test_touch_input.gd`:
```gdscript
extends GutTest

var _local: LocalInput
var _touch: TouchInput


func before_each() -> void:
	InputBindings.apply()
	_local = LocalInput.new()
	_touch = TouchInput.new()
	add_child_autofree(_touch)
	_touch.setup(_local, GameConfig.new())


func _touch_event(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag_event(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func test_tap_attack_fires_light_on_release() -> void:
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	assert_false(_local.sample().light, "nothing on press")
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), false))
	assert_true(_local.sample().light, "light on release")


func test_jump_fires_on_press() -> void:
	_touch._unhandled_input(_touch_event(1, _touch.jump_center(), true))
	assert_true(_local.sample().jump)


func test_stick_drag_moves_and_release_stops() -> void:
	var start := _touch.stick_zone_point()
	_touch._unhandled_input(_touch_event(0, start, true))
	_touch._unhandled_input(_drag_event(0, start + Vector2(140, 0)))
	assert_gt(_local.sample().move_x, 0.9)
	_touch._unhandled_input(_touch_event(0, start + Vector2(140, 0), false))
	assert_eq(_local.sample().move_x, 0.0)


func test_stick_and_attack_work_at_the_same_time() -> void:
	var start := _touch.stick_zone_point()
	_touch._unhandled_input(_touch_event(0, start, true))
	_touch._unhandled_input(_drag_event(0, start + Vector2(0, -140)))
	_touch._unhandled_input(_touch_event(1, _touch.attack_center(), true))
	_touch._unhandled_input(_touch_event(1, _touch.attack_center(), false))
	var f := _local.sample()
	assert_lt(f.move_z, -0.9)
	assert_true(f.light)


func test_fourth_finger_is_ignored() -> void:
	_touch._unhandled_input(_touch_event(3, _touch.jump_center(), true))
	assert_false(_local.sample().jump, "index 3 belongs to the debug panel gesture")
```

- [ ] **Step 4: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_touch_stick_model` → FAIL · `scripts/test.sh -gselect=test_touch_input` → FAIL (클래스 미정의)

- [ ] **Step 5: TouchStickModel + LocalInput 연결**

`src/input/touch_stick_model.gd`:
```gdscript
class_name TouchStickModel
extends RefCounted
## Floating virtual stick math (PRD §3.3, design.md DS-LAY-01): wherever the thumb lands becomes
## the center. vector() is normalized by the radius, zero inside the dead zone, length <= 1.
## Screen y grows downward, which maps to +z (toward the camera).

var radius: float
## Fraction of the radius that reads as zero.
var deadzone: float
var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO


func _init(p_radius: float, p_deadzone: float) -> void:
	radius = maxf(p_radius, 1.0)
	deadzone = p_deadzone


func begin(p: Vector2) -> void:
	_active = true
	_center = p
	_current = p


func move(p: Vector2) -> void:
	if _active:
		_current = p


func end() -> void:
	_active = false


func active() -> bool:
	return _active


func center() -> Vector2:
	return _center


func knob() -> Vector2:
	return _center + (_current - _center).limit_length(radius)


func vector() -> Vector2:
	if not _active:
		return Vector2.ZERO
	var d := (_current - _center) / radius
	if d.length() < deadzone:
		return Vector2.ZERO
	return d.limit_length(1.0)
```

`src/input/local_input.gd`: `var _light` 선언 아래에 필드를 추가하고 `_move_vector()`를 교체:
```gdscript
## Set by TouchInput; when the stick is held it overrides the keyboard move vector.
var touch_stick: TouchStickModel = null
```
```gdscript
func _move_vector() -> Vector2:
	if touch_stick != null and touch_stick.active():
		return touch_stick.vector()
	return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
```

- [ ] **Step 6: TouchButton v1 컴포넌트**

`src/ui/components/touch_button/touch_button.gd`:
```gdscript
class_name TouchButton
extends Control
## Touch action button v1 (design.md DS-CMP-04): idle / pressed. Highlight, disabled and
## charging states arrive with v2 in Phase 2. Circle hit-test, cream 70% fill, press squish.

enum State { IDLE, PRESSED }

const PREVIEW_DIAMETER := 150.0
## Vertical nudge that centers a body-size label inside the circle.
const LABEL_BASELINE_RATIO := 0.35

@export var label_text: String = "공격"
@export var diameter: float = PREVIEW_DIAMETER

var _state: int = State.IDLE
var _font: Font


func _ready() -> void:
	_font = load(DS.FONT_BODY_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_size()


func set_state(s: int) -> void:
	_state = s
	scale = DS.PRESS_SQUISH if s == State.PRESSED else Vector2.ONE
	queue_redraw()


func contains(point: Vector2) -> bool:
	return point.distance_to(get_global_rect().get_center()) <= diameter * 0.5


func set_preview() -> void:
	diameter = PREVIEW_DIAMETER
	_apply_size()


func _apply_size() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var r := diameter * 0.5
	var fill := DS.UI_SURFACE_DIM if _state == State.PRESSED else DS.UI_SURFACE_70
	draw_circle(Vector2(r, r), r, fill)
	if _font != null:
		draw_string(_font, Vector2(0.0, r + DS.SIZE_BODY * LABEL_BASELINE_RATIO), label_text,
				HORIZONTAL_ALIGNMENT_CENTER, diameter, DS.SIZE_BODY, DS.UI_TEXT)
```

`src/ui/components/touch_button/touch_button.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/components/touch_button/touch_button.gd" id="1"]

[node name="TouchButton" type="Control"]
script = ExtResource("1")
```

- [ ] **Step 7: TouchStick 컴포넌트**

`src/ui/components/touch_stick/touch_stick.gd`:
```gdscript
class_name TouchStick
extends Control
## Floating virtual stick visual (design.md DS-CMP-03): hidden until a thumb lands, then a
## translucent cream base with a solid cream knob. Drawing only; TouchStickModel holds the math.

const KNOB_RATIO := 0.45
const PREVIEW_RADIUS := 140.0
const PREVIEW_SIZE_RATIO := 2.6

var _shown: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _radius: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_stick(center: Vector2, knob: Vector2, radius: float) -> void:
	_shown = true
	_center = center - global_position
	_knob = knob - global_position
	_radius = radius
	queue_redraw()


func hide_stick() -> void:
	_shown = false
	queue_redraw()


func set_preview() -> void:
	custom_minimum_size = Vector2.ONE * PREVIEW_RADIUS * PREVIEW_SIZE_RATIO
	var mid := custom_minimum_size * 0.5
	_shown = true
	_center = mid
	_knob = mid + Vector2(PREVIEW_RADIUS * 0.5, -PREVIEW_RADIUS * 0.3)
	_radius = PREVIEW_RADIUS
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	draw_circle(_center, _radius, DS.UI_SURFACE_50)
	draw_circle(_knob, _radius * KNOB_RATIO, DS.UI_SURFACE)
```

`src/ui/components/touch_stick/touch_stick.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/components/touch_stick/touch_stick.gd" id="1"]

[node name="TouchStick" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 8: TouchInput**

`src/input/touch_input.gd`:
```gdscript
class_name TouchInput
extends CanvasLayer
## Phase 1 touch controls (PRD §3.3, design.md DS-LAY-01): floating stick on the left 40% x
## bottom 70% of the screen, jump + attack buttons bottom-right. Jump fires on press; attack
## fires a light attack on release (tap) — holds become heavy in Phase 2. Finger index >= 3
## (four-finger tap) belongs to the debug panel. Debug builds without a touchscreen also accept
## the left mouse button as finger 0 for desktop testing.

const TOUCH_STICK_SCENE := preload("res://src/ui/components/touch_stick/touch_stick.tscn")
const TOUCH_BUTTON_SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")
const LAYER := 10
const STICK_ZONE_WIDTH := 0.4
const STICK_ZONE_TOP := 0.3
const MAX_FINGERS := 3
const MOUSE_FINGER := 0
const NO_FINGER := -1

var _local: LocalInput
var _model: TouchStickModel
var _stick: TouchStick
var _jump: TouchButton
var _attack: TouchButton
var _stick_finger: int = NO_FINGER
var _jump_finger: int = NO_FINGER
var _attack_finger: int = NO_FINGER


func setup(local: LocalInput, config: GameConfig) -> void:
	_local = local
	layer = LAYER
	_model = TouchStickModel.new(config.touch_stick_radius, config.touch_stick_deadzone)
	local.touch_stick = _model
	_stick = TOUCH_STICK_SCENE.instantiate() as TouchStick
	add_child(_stick)
	_attack = _make_button("공격", config.touch_attack_diameter)
	_jump = _make_button("점프", config.touch_jump_diameter)
	visible = DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func attack_center() -> Vector2:
	return _attack.get_global_rect().get_center()


func jump_center() -> Vector2:
	return _jump.get_global_rect().get_center()


func stick_zone_point() -> Vector2:
	var vp := _viewport_size()
	return Vector2(vp.x * STICK_ZONE_WIDTH * 0.5, vp.y * (STICK_ZONE_TOP + 1.0) * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index < MAX_FINGERS:
			_finger(t.index, t.position, t.pressed)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position)
	elif _mouse_as_finger() and event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_finger(MOUSE_FINGER, m.position, m.pressed)
	elif _mouse_as_finger() and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(MOUSE_FINGER, mm.position)


func _make_button(text: String, d: float) -> TouchButton:
	var b := TOUCH_BUTTON_SCENE.instantiate() as TouchButton
	b.label_text = text
	b.diameter = d
	add_child(b)
	return b


func _layout() -> void:
	var vp := _viewport_size()
	var a := _attack.diameter
	_attack.position = Vector2(vp.x - DS.S8 - a, vp.y - DS.S8 - a)
	_jump.position = _attack.position + Vector2(-_jump.diameter - DS.S6, a - _jump.diameter)


func _finger(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		_down(index, pos)
	else:
		_up(index)


func _down(index: int, pos: Vector2) -> void:
	visible = true
	if _attack_finger == NO_FINGER and _attack.contains(pos):
		_attack_finger = index
		_attack.set_state(TouchButton.State.PRESSED)
	elif _jump_finger == NO_FINGER and _jump.contains(pos):
		_jump_finger = index
		_jump.set_state(TouchButton.State.PRESSED)
		_local.press_jump()
	elif _stick_finger == NO_FINGER and _in_stick_zone(pos):
		_stick_finger = index
		_model.begin(pos)
		_refresh_stick()


func _up(index: int) -> void:
	if index == _attack_finger:
		_attack_finger = NO_FINGER
		_attack.set_state(TouchButton.State.IDLE)
		_local.press_light()
	if index == _jump_finger:
		_jump_finger = NO_FINGER
		_jump.set_state(TouchButton.State.IDLE)
	if index == _stick_finger:
		_stick_finger = NO_FINGER
		_model.end()
		_stick.hide_stick()


func _drag(index: int, pos: Vector2) -> void:
	if index == _stick_finger:
		_model.move(pos)
		_refresh_stick()


func _refresh_stick() -> void:
	_stick.show_stick(_model.center(), _model.knob(), _model.radius)


func _in_stick_zone(pos: Vector2) -> bool:
	var vp := _viewport_size()
	return pos.x <= vp.x * STICK_ZONE_WIDTH and pos.y >= vp.y * STICK_ZONE_TOP


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _mouse_as_finger() -> bool:
	return OS.is_debug_build() and not DisplayServer.is_touchscreen_available()
```

- [ ] **Step 9: 갤러리 등록 + `set_preview` 규약 + 컴포넌트만 보기 옵션**

`src/debug/ds_gallery.gd`:
1. `COMPONENTS`를 교체:
```gdscript
const COMPONENTS: Array[Array] = [
	["TouchStick · DS-CMP-03", "res://src/ui/components/touch_stick/touch_stick.tscn"],
	["TouchButton v1 · DS-CMP-04", "res://src/ui/components/touch_button/touch_button.tscn"],
]
## Pass `--components-only` after `--` to render just the components section (evidence capture).
const COMPONENTS_ONLY_ARG := "--components-only"
```
2. `_components()`의 마지막 루프를 교체:
```gdscript
	for entry: Array in COMPONENTS:
		var title := Label.new()
		title.text = entry[0]
		box.add_child(title)
		var node := (load(entry[1]) as PackedScene).instantiate()
		box.add_child(node)
		if node.has_method("set_preview"):
			node.call("set_preview")
	return box
```
3. `_ready()`에서 섹션을 붙이는 부분을 다음처럼 감싼다 (팔레트·타이포·툰 미리보기는 옵션이 없을 때만):
```gdscript
	if not OS.get_cmdline_user_args().has(COMPONENTS_ONLY_ARG):
		col.add_child(_heading("Palette · DS-TOK-01 (A 한낮 햇살)"))
		col.add_child(_swatches())
		col.add_child(_heading("Typography · DS-TOK-02"))
		col.add_child(_type_scale())
		col.add_child(_heading("Soft toon · DS-VIS-01 / DS-VIS-02"))
		col.add_child(_toon_preview())
	col.add_child(_heading("Components · DS-CMP"))
	col.add_child(_components())
```

- [ ] **Step 10: 통과 확인**

Run: `scripts/test.sh -gselect=test_touch_stick_model` → 5/5 PASS · `scripts/test.sh -gselect=test_touch_input` → 5/5 PASS
Run: `scripts/check-all.sh` → `ALL CHECKS PASSED` (반투명 색은 토큰으로만 쓴다)

- [ ] **Step 11: 갤러리 증거**

```bash
mkdir -p dev/active/phase-1/evidence
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ds_gallery.tscn --out=$PWD/dev/active/phase-1/evidence/gallery-touch.png --frames=60 --components-only
```
이미지를 직접 열어 확인: 반투명 스틱 바탕 + 크림 노브, "공격" 원형 버튼(크림 70%, 청록 글자).

- [ ] **Step 12: 커밋**

```bash
git add src/input/touch_stick_model.gd src/input/touch_input.gd src/input/local_input.gd src/ui/components/touch_stick src/ui/components/touch_button src/ui/theme/tokens.gd src/config/game_config.gd src/debug/ds_gallery.gd docs/design.md tests/unit/test_touch_stick_model.gd tests/unit/test_touch_input.gd dev/active/phase-1/evidence/gallery-touch.png
git add src/input/*.uid tests/unit/*.uid
git commit -m "feat: add floating touch stick, jump and attack buttons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: 🖼 HUD 시안 게이트 (Stitch)

**수행자:** 사용자(시안 생성) + 컨트롤러(비교·기록). 구현 에이전트에게 맡기지 않는다.

**Files:**
- Create: `docs/references/stitch/hud-A.png`, `hud-B.png`, `hud-C.png` (사용자 제공)
- Modify: `docs/design.md` (DS-LAY-01·DS-LAY-02 결정 기록, §12 추적표 상태), `dev/active/phase-1/phase-1-context.md` (결정 기록)

**Interfaces:**
- Produces: T13(HUD)과 T11 터치 배치가 따를 확정 레이아웃 — 확정 전이라도 T13은 design.md DS-LAY-02 기본 배치로 진행할 수 있다 (게이트는 차단하지 않는다)
- 근거: `[DS-LAY-01]` `[DS-LAY-02]` `[DS-CMP-01]` `[DS-CMP-02]`, design.md §11 절차 5

- [ ] **Step 1: 시안 생성 (사용자)**

aside CLI로 Google Stitch에 `docs/stitch-prompts.md`의 **공통 컨텍스트 + 1번(인게임 HUD + 터치 조작)** 프롬프트를 보내 3안을 만든다. 결과를 `docs/references/stitch/hud-A.png`, `hud-B.png`, `hud-C.png`로 저장한다.

- [ ] **Step 2: 비교 화면 (컨트롤러)**

세 시안과 현재 구현 스크린샷(T13 이전이면 design.md DS-LAY-01/02 ASCII 배치)을 나란히 보여주는 비교를 만들어 사용자에게 보여준다. 비교 항목:
1. 대미지 %가 휴대폰 가로 화면에서 한눈에 읽히는가 (상단 좌우 끝)
2. 버튼 배치: 호(A) / 다이아몬드(B) / 2×2(C) 중 엄지 도달성
3. 팔레트 이탈 여부 (이탈 색은 토큰으로 되돌린다 — stitch-prompts.md 처리 규칙 3)

- [ ] **Step 3: 결정 기록**

사용자가 고른 안을 design.md에 기록한다:
- DS-LAY-01 "(초안 — Phase 2 🖼 게이트에서 3안 비교)"를 유지하되 Phase 1 버튼 2개(점프·공격) 배치 선택을 한 줄로 적는다 (4버튼 최종 비교는 Phase 2)
- DS-LAY-02에 확정 HUD 배치와 참고 시안 파일명을 적는다
- §12 추적표 DS-LAY-02 상태를 🟨로
- `phase-1-context.md` 결정 표에 "HUD 🖼: <안> 확정 (날짜)" 추가

- [ ] **Step 4: 커밋**

```bash
git add docs/references/stitch docs/design.md dev/active/phase-1/phase-1-context.md
git commit -m "docs: record phase 1 HUD mockup decision

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

게이트가 지연되면: Step 1~4를 건너뛰고 T13을 DS-LAY-02 기본 배치로 진행한 뒤, `phase-1-tasks.md`의 T12를 "🖼 대기"로 남긴다. 시안이 들어오면 T13 배치 상수만 조정한다.

---

### Task 13: HUD 컴포넌트 + HUD 배치

**Files:**
- Create: `src/ui/player_style.gd`, `src/ui/damage_color.gd`, `src/ui/hud.gd`, `src/ui/components/player_marker/player_marker.gd`, `src/ui/components/damage_counter/damage_counter.gd` + `.tscn`, `src/ui/components/stock_icons/stock_icons.gd` + `.tscn`, `src/ui/components/result_banner/result_banner.gd` + `.tscn`
- Modify: `src/debug/ds_gallery.gd` (`COMPONENTS`에 3개 추가)
- Test: `tests/unit/test_player_style.gd`, `tests/unit/test_damage_color.gd`, `tests/unit/test_hud.gd`

**Interfaces:**
- Consumes: `DS` 토큰, `Rules.DRAW` (T5), `Fighter.State` (T4), `state_view()` 구조 (T5·T7)
- Produces:
  - `class_name PlayerStyle` — `enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }`, `static color(index: int) -> Color`, `static shape(index: int) -> int`, `static label(index: int) -> String` ("P1"…), `static polygon(shape_id: int, radius: float, center: Vector2 = Vector2.ZERO) -> PackedVector2Array`
  - `class_name DamageColor` — `static for_percent(p: float) -> Color` (0/50/100/150+ 램프 선형 보간)
  - `class_name PlayerMarker extends Control` — `setup(index: int, diameter: float)`, `set_dimmed(d: bool)` (씬 없이 `.new()`)
  - `class_name DamageCounter extends PanelContainer` — `setup(index: int)`, `set_damage(p: float)` (올라가면 스쿼시 팝), `set_ko(ko: bool)`, `text() -> String`, `set_preview()`
  - `class_name StockIcons extends HBoxContainer` — `setup(index: int, max_stocks: int)`, `set_stocks(n: int)`, `shown() -> int`, `set_preview()`
  - `class_name ResultBanner extends PanelContainer` — `signal restart_requested`, `show_result(winner_id: int, local_id: int)`, `hide_result()`, `title() -> String`, `set_preview()`
  - `class_name Hud extends CanvasLayer` — `signal restart_requested`, `setup(player_count: int, max_stocks: int)`, `update_from(view: Dictionary)`, `show_result(winner_id: int, local_id: int)`, `hide_result()`, `counter_text(i: int) -> String`, `stocks_shown(i: int) -> int`, `result_visible() -> bool`
- 배치(DS-LAY-02): 상단 가장자리, safe area 안쪽 `DS.S5` 여백. 1:1은 좌우 끝, N명은 사이 간격을 균등 분배. 결과 배너는 중앙. T12 결정이 있으면 그 배치를 따른다
- 근거: `[DS-CMP-01]` `[DS-CMP-02]` `[DS-CMP-09]` `[DS-LAY-02]` `[DS-VIS-03]` `[PRD-UI-01]` `[DS-GOV-02]`

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_player_style.gd`:
```gdscript
extends GutTest


func test_colors_and_shapes_are_paired_per_player() -> void:
	assert_eq(PlayerStyle.color(0), DS.P1)
	assert_eq(PlayerStyle.color(1), DS.P2)
	assert_eq(PlayerStyle.shape(0), PlayerStyle.Shape.CIRCLE)
	assert_eq(PlayerStyle.shape(1), PlayerStyle.Shape.TRIANGLE)
	assert_eq(PlayerStyle.label(1), "P2")


func test_polygons_have_the_right_vertex_counts() -> void:
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.TRIANGLE, 10.0).size(), 3)
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.SQUARE, 10.0).size(), 4)
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.DIAMOND, 10.0).size(), 4)
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.CIRCLE, 10.0).size(), PlayerStyle.CIRCLE_SEGMENTS)


func test_polygon_points_sit_on_the_radius_around_center() -> void:
	for p: Vector2 in PlayerStyle.polygon(PlayerStyle.Shape.DIAMOND, 10.0, Vector2(5, 5)):
		assert_almost_eq(p.distance_to(Vector2(5, 5)), 10.0, 0.0001)
```

`tests/unit/test_damage_color.gd`:
```gdscript
extends GutTest


func test_ramp_stops() -> void:
	assert_eq(DamageColor.for_percent(0.0), DS.UI_SURFACE)
	assert_eq(DamageColor.for_percent(50.0), DS.PETAL_YELLOW)
	assert_eq(DamageColor.for_percent(100.0), DS.FIRE)
	assert_eq(DamageColor.for_percent(150.0), DS.DANGER)
	assert_eq(DamageColor.for_percent(300.0), DS.DANGER)
	assert_eq(DamageColor.for_percent(-5.0), DS.UI_SURFACE)


func test_ramp_interpolates_between_stops() -> void:
	var mid := DamageColor.for_percent(25.0)
	var expected := DS.UI_SURFACE.lerp(DS.PETAL_YELLOW, 0.5)
	assert_almost_eq(mid.r, expected.r, 0.0001)
	assert_almost_eq(mid.g, expected.g, 0.0001)
	assert_almost_eq(mid.b, expected.b, 0.0001)
```

`tests/unit/test_hud.gd`:
```gdscript
extends GutTest

var _hud: Hud


func before_each() -> void:
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.setup(2, 3)


func _view(p1_damage: float, p2_stocks: int, p2_state: int = Fighter.State.IDLE) -> Dictionary:
	return {"fighters": [
		{"id": 0, "damage": p1_damage, "stocks": 3, "state": Fighter.State.IDLE},
		{"id": 1, "damage": 0.0, "stocks": p2_stocks, "state": p2_state},
	]}


func test_counters_show_rounded_damage() -> void:
	_hud.update_from(_view(41.6, 3))
	assert_eq(_hud.counter_text(0), "42%")
	assert_eq(_hud.counter_text(1), "0%")


func test_stocks_follow_the_view() -> void:
	_hud.update_from(_view(0.0, 1))
	assert_eq(_hud.stocks_shown(0), 3)
	assert_eq(_hud.stocks_shown(1), 1)


func test_result_banner_texts() -> void:
	assert_false(_hud.result_visible())
	_hud.show_result(0, 0)
	assert_true(_hud.result_visible())
	var banner := ResultBanner.new()
	add_child_autofree(banner)
	banner.show_result(1, 0)
	assert_eq(banner.title(), "패배…")
	banner.show_result(Rules.DRAW, 0)
	assert_eq(banner.title(), "무승부")
	banner.show_result(0, 0)
	assert_eq(banner.title(), "승리!")
	_hud.hide_result()
	assert_false(_hud.result_visible())
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_player_style` · `-gselect=test_damage_color` · `-gselect=test_hud` → 모두 FAIL (클래스 미정의)

- [ ] **Step 3: PlayerStyle + DamageColor**

`src/ui/player_style.gd`:
```gdscript
class_name PlayerStyle
extends RefCounted
## Player identity (design.md DS-VIS-03): color + shape + label — never color alone.

enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }

const COLORS := [DS.P1, DS.P2, DS.P3, DS.P4]
const SHAPES := [Shape.CIRCLE, Shape.TRIANGLE, Shape.SQUARE, Shape.DIAMOND]
const CIRCLE_SEGMENTS := 24


static func color(index: int) -> Color:
	return COLORS[posmod(index, COLORS.size())]


static func shape(index: int) -> int:
	return SHAPES[posmod(index, SHAPES.size())]


static func label(index: int) -> String:
	return "P%d" % (index + 1)


static func polygon(shape_id: int, radius: float, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var count := CIRCLE_SEGMENTS
	var start := 0.0
	match shape_id:
		Shape.TRIANGLE:
			count = 3
			start = -PI / 2.0
		Shape.SQUARE:
			count = 4
			start = PI / 4.0
		Shape.DIAMOND:
			count = 4
			start = -PI / 2.0
	var pts := PackedVector2Array()
	for i: int in count:
		var a := start + TAU * float(i) / float(count)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
```

`src/ui/damage_color.gd`:
```gdscript
class_name DamageColor
extends RefCounted
## Damage % -> DamageCounter color along the DS damage ramp (design.md DS-TOK-01: 0/50/100/150+).

const STOPS := [0.0, 50.0, 100.0, 150.0]


static func for_percent(p: float) -> Color:
	var ramp: Array = DS.DAMAGE_RAMP
	if p <= STOPS[0]:
		return ramp[0]
	for i: int in range(1, STOPS.size()):
		if p <= STOPS[i]:
			var t: float = (p - STOPS[i - 1]) / (STOPS[i] - STOPS[i - 1])
			return (ramp[i - 1] as Color).lerp(ramp[i], t)
	return ramp[ramp.size() - 1]
```

- [ ] **Step 4: PlayerMarker + StockIcons**

`src/ui/components/player_marker/player_marker.gd`:
```gdscript
class_name PlayerMarker
extends Control
## A player's color + shape badge (design.md DS-VIS-03), shared by HUD components.
## Dimmed markers (lost stocks) switch to the dim surface color with a small pop.

const POP_SCALE := 1.4

var _index: int = 0
var _diameter: float = DS.S6
var _dimmed: bool = false


func setup(index: int, diameter: float) -> void:
	_index = index
	_diameter = diameter
	custom_minimum_size = Vector2(diameter, diameter)
	pivot_offset = custom_minimum_size * 0.5
	queue_redraw()


func set_dimmed(d: bool) -> void:
	if d and not _dimmed and is_inside_tree():
		scale = Vector2.ONE * POP_SCALE
		create_tween().tween_property(self, "scale", Vector2.ONE, DS.MOTION_BASE)
	_dimmed = d
	queue_redraw()


func is_dimmed() -> bool:
	return _dimmed


func _draw() -> void:
	var c := DS.UI_SURFACE_DIM if _dimmed else PlayerStyle.color(_index)
	draw_colored_polygon(PlayerStyle.polygon(PlayerStyle.shape(_index), _diameter * 0.5, size * 0.5), c)
```

`src/ui/components/stock_icons/stock_icons.gd`:
```gdscript
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
```

`src/ui/components/stock_icons/stock_icons.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/components/stock_icons/stock_icons.gd" id="1"]

[node name="StockIcons" type="HBoxContainer"]
script = ExtResource("1")
```

- [ ] **Step 5: DamageCounter**

`src/ui/components/damage_counter/damage_counter.gd`:
```gdscript
class_name DamageCounter
extends PanelContainer
## Player damage % (design.md DS-CMP-01): cream pill card with the player's shape badge and a big
## Jua number on the damage ramp, deep-teal outline; squish pop when it rises, dimmed when KO.

const PREVIEW_PLAYER := 0
const PREVIEW_DAMAGE := 42.0
const POP_SCALE := 1.25
const KO_ALPHA := 0.35

var _index: int = 0
var _shown: int = -1
var _marker: PlayerMarker
var _label: Label


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S3)
	add_child(row)
	_marker = PlayerMarker.new()
	row.add_child(_marker)
	_marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = Label.new()
	_label.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_label.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_XL)
	_label.add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
	_label.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 2)
	row.add_child(_label)
	setup(_index)
	set_damage(0.0)


func setup(index: int) -> void:
	_index = index
	if _marker != null:
		_marker.setup(index, DS.S7)


func set_damage(p: float) -> void:
	var rounded := roundi(p)
	if _shown >= 0 and rounded > _shown:
		_pop()
	_shown = rounded
	if _label != null:
		_label.text = "%d%%" % rounded
		_label.add_theme_color_override("font_color", DamageColor.for_percent(p))


func set_ko(ko: bool) -> void:
	modulate.a = KO_ALPHA if ko else 1.0


func text() -> String:
	return _label.text if _label != null else ""


func set_preview() -> void:
	setup(PREVIEW_PLAYER)
	set_damage(PREVIEW_DAMAGE)


func _pop() -> void:
	if not is_inside_tree():
		return
	pivot_offset = size * 0.5
	scale = Vector2.ONE * POP_SCALE
	create_tween().tween_property(self, "scale", Vector2.ONE, DS.MOTION_SQUISH) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
```

(`outline_size`는 Label 외곽선의 전체 두께라서 디자인의 3px 테두리에 맞추려면 `TEXT_OUTLINE × 2`를 쓴다.)

`src/ui/components/damage_counter/damage_counter.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/components/damage_counter/damage_counter.gd" id="1"]

[node name="DamageCounter" type="PanelContainer"]
script = ExtResource("1")
```

- [ ] **Step 6: ResultBanner**

`src/ui/components/result_banner/result_banner.gd`:
```gdscript
class_name ResultBanner
extends PanelContainer
## Match result (design.md DS-CMP-09): "승리!" / "패배…" / "무승부" in Jua display_l with an
## elastic pop, plus a restart button. Hidden until show_result().

signal restart_requested

const POP_FROM := 0.8

var _title: Label
var _button: Button


func _ready() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S5)
	add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_title.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_L)
	col.add_child(_title)
	_button = Button.new()
	_button.text = "다시 하기"
	_button.pressed.connect(func() -> void: restart_requested.emit())
	col.add_child(_button)
	visible = false


func show_result(winner_id: int, local_id: int) -> void:
	if winner_id == Rules.DRAW:
		_title.text = "무승부"
	elif winner_id == local_id:
		_title.text = "승리!"
	else:
		_title.text = "패배…"
	visible = true
	if is_inside_tree():
		pivot_offset = size * 0.5
		scale = Vector2.ONE * POP_FROM
		create_tween().tween_property(self, "scale", Vector2.ONE, DS.MOTION_SQUISH) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_button.grab_focus()


func hide_result() -> void:
	visible = false


func title() -> String:
	return _title.text


func set_preview() -> void:
	show_result(0, 0)
```

`src/ui/components/result_banner/result_banner.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/components/result_banner/result_banner.gd" id="1"]

[node name="ResultBanner" type="PanelContainer"]
script = ExtResource("1")
```

- [ ] **Step 7: Hud**

`src/ui/hud.gd`:
```gdscript
class_name Hud
extends CanvasLayer
## In-match HUD (design.md DS-LAY-02): damage counter + stocks per player along the top edge
## (1v1 at the far left and right, N players spread evenly), result banner in the center.

signal restart_requested

const DAMAGE_COUNTER_SCENE := preload("res://src/ui/components/damage_counter/damage_counter.tscn")
const STOCK_ICONS_SCENE := preload("res://src/ui/components/stock_icons/stock_icons.tscn")
const RESULT_BANNER_SCENE := preload("res://src/ui/components/result_banner/result_banner.tscn")
const LAYER := 5

var _row: HBoxContainer
var _banner: ResultBanner
var _counters: Array[DamageCounter] = []
var _stocks: Array[StockIcons] = []


func setup(player_count: int, max_stocks: int) -> void:
	layer = LAYER
	if _row == null:
		_build_frame()
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_counters.clear()
	_stocks.clear()
	for i: int in player_count:
		if i > 0:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_row.add_child(spacer)
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", DS.S2)
		_row.add_child(slot)
		var counter := DAMAGE_COUNTER_SCENE.instantiate() as DamageCounter
		slot.add_child(counter)
		counter.setup(i)
		var stocks := STOCK_ICONS_SCENE.instantiate() as StockIcons
		slot.add_child(stocks)
		stocks.setup(i, max_stocks)
		_counters.append(counter)
		_stocks.append(stocks)
	hide_result()


func update_from(view: Dictionary) -> void:
	for f: Dictionary in view["fighters"]:
		var i := int(f["id"])
		if i >= _counters.size():
			continue
		_counters[i].set_damage(float(f["damage"]))
		_counters[i].set_ko(int(f["state"]) == Fighter.State.KO)
		_stocks[i].set_stocks(int(f["stocks"]))


func show_result(winner_id: int, local_id: int) -> void:
	_banner.show_result(winner_id, local_id)


func hide_result() -> void:
	_banner.hide_result()


func counter_text(i: int) -> String:
	return _counters[i].text()


func stocks_shown(i: int) -> int:
	return _stocks[i].shown()


func result_visible() -> bool:
	return _banner.visible


func _build_frame() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, DS.S5)
	add_child(margin)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_row)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_banner = RESULT_BANNER_SCENE.instantiate() as ResultBanner
	center.add_child(_banner)
	_banner.restart_requested.connect(func() -> void: restart_requested.emit())
```

- [ ] **Step 8: 갤러리 등록**

`src/debug/ds_gallery.gd`의 `COMPONENTS` 배열 앞쪽에 추가 (기존 터치 항목 유지):
```gdscript
	["DamageCounter · DS-CMP-01", "res://src/ui/components/damage_counter/damage_counter.tscn"],
	["StockIcons · DS-CMP-02", "res://src/ui/components/stock_icons/stock_icons.tscn"],
	["ResultBanner · DS-CMP-09", "res://src/ui/components/result_banner/result_banner.tscn"],
```

- [ ] **Step 9: 통과 확인**

Run: `scripts/test.sh -gselect=test_player_style` → 3/3 · `-gselect=test_damage_color` → 2/2 · `-gselect=test_hud` → 3/3 PASS
Run: `scripts/check-all.sh` → `ALL CHECKS PASSED`

- [ ] **Step 10: 갤러리 증거**

```bash
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ds_gallery.tscn --out=$PWD/dev/active/phase-1/evidence/gallery-hud.png --frames=90 --components-only
```
이미지 확인: DamageCounter "42%"(노랑~흰색 사이, 청록 외곽선, P1 원 배지), StockIcons(삼각형 2개 채움 + 1개 흐림), ResultBanner "승리!" + "다시 하기".

- [ ] **Step 11: 커밋**

```bash
git add src/ui/player_style.gd src/ui/damage_color.gd src/ui/hud.gd src/ui/components/player_marker src/ui/components/damage_counter src/ui/components/stock_icons src/ui/components/result_banner src/debug/ds_gallery.gd tests/unit/test_player_style.gd tests/unit/test_damage_color.gd tests/unit/test_hud.gd dev/active/phase-1/evidence/gallery-hud.png
git add src/ui/*.uid tests/unit/*.uid
git commit -m "feat: add HUD damage counters, stocks and result banner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: FighterView (보간·스냅·링·깜빡임) + 경기장 가장자리 립

**Files:**
- Create: `src/render/fighter_view.gd`
- Modify: `src/render/arena_view.gd` (가장자리 밝은 립)
- Test: `tests/unit/test_fighter_view.gd`

**Interfaces:**
- Consumes: `state_view()["fighters"][i]` 값 (T4 `to_view()`), `PlayerStyle` (T13), `ToonMaterials.toon` (Phase 0), `Collision.yaw_of` (T3), `SimTime` (T4), `GameConfig.fighter_*`, `blink_hz`, `blink_hz_end` (T1)
- Produces: `class_name FighterView extends Node3D`
  - `setup(index: int, config: GameConfig) -> void`
  - `apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void` — KO면 숨김, 아니면 보간 위치·방향·깜빡임 적용
  - `static interpolate(prev: Dictionary, curr: Dictionary, alpha: float) -> Vector3` — `spawn_id`가 다르거나 `prev`가 비면 `curr` 위치로 스냅 (D4)
  - `static blink_visible(invuln_ticks: int, tick: int, config: GameConfig) -> bool` — 무적 중 `blink_hz`, 마지막 0.5초는 `blink_hz_end`로 켜짐/꺼짐 반복
- 비주얼: 캡슐(플레이어 색, 림 0.35) + 발밑 납작한 링(플레이어 색) + 머리 위 `P1`/`P2` 라벨(Jua, 크림 글자 + 청록 외곽선, 빌보드). 캐시 머티리얼은 수정하지 않는다
- 경기장 립: 잔디 윗면 가장자리에 `DS.GRASS_SUN` 밝은 테두리 → 먼 쪽 가장자리(흙 단면이 가려지는 쪽)도 읽힌다 (Phase 0 Ruling 9 보완)
- 근거: `[DS-VIS-03]` `[DS-VIS-04]` `[GD-FEEL-03]` `[PRD-ARCH-02]`

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_fighter_view.gd`:
```gdscript
extends GutTest


func _view(pos: Vector3, spawn_id: int) -> Dictionary:
	return {"pos": pos, "spawn_id": spawn_id}


func test_interpolates_between_ticks() -> void:
	var p := FighterView.interpolate(_view(Vector3(0, 0, 0), 0), _view(Vector3(2, 4, 0), 0), 0.25)
	assert_eq(p, Vector3(0.5, 1.0, 0))


func test_snaps_after_respawn() -> void:
	var p := FighterView.interpolate(_view(Vector3(20, -8, 0), 0), _view(Vector3(-5, 6, 0), 1), 0.5)
	assert_eq(p, Vector3(-5, 6, 0), "no sliding across the map on respawn")


func test_snaps_without_previous_state() -> void:
	assert_eq(FighterView.interpolate({}, _view(Vector3(1, 2, 3), 0), 0.5), Vector3(1, 2, 3))


func test_visible_when_not_invulnerable() -> void:
	var c := GameConfig.new()
	for t: int in 10:
		assert_true(FighterView.blink_visible(0, t, c))


func test_blinks_at_blink_hz_then_faster_at_the_end() -> void:
	var c := GameConfig.new()
	# 10 Hz -> toggles every 60 / (2 * 10) = 3 ticks
	var long_invuln := SimTime.to_ticks(c.respawn_invuln)
	var pattern: Array[bool] = []
	for t: int in 6:
		pattern.append(FighterView.blink_visible(long_invuln, t, c))
	assert_eq(pattern, [true, true, true, false, false, false] as Array[bool])
	# last 0.5 s uses blink_hz_end (20 Hz) -> toggles every 1.5 ticks
	var toggles := 0
	var last := FighterView.blink_visible(10, 0, c)
	for t: int in range(1, 12):
		var now := FighterView.blink_visible(10, t, c)
		if now != last:
			toggles += 1
		last = now
	assert_gt(toggles, 5, "faster blinking in the final half second")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_fighter_view` → FAIL (`FighterView` 미정의)

- [ ] **Step 3: FighterView 구현**

`src/render/fighter_view.gd`:
```gdscript
class_name FighterView
extends Node3D
## Draws one fighter (design.md DS-VIS-03, GD-FEEL-03): toon capsule in the player color with a
## rim light, a flat foot ring and a P-label. Interpolates prev -> curr by alpha, snaps when
## spawn_id changes (respawn), blinks while invulnerable, hides when KO. Reads view values only.

const RIM := 0.35
const RING_INNER_RATIO := 1.15
const RING_OUTER_RATIO := 1.45
const RING_FLATTEN := 0.08
const RING_LIFT := 0.02
const LABEL_GAP := 0.6
const LABEL_PIXEL_SIZE := 0.01
const BLINK_END_SECONDS := 0.5

var _config: GameConfig
var _body: MeshInstance3D
var _ring: MeshInstance3D
var _label: Label3D


func setup(index: int, config: GameConfig) -> void:
	_config = config
	var color := PlayerStyle.color(index)

	var capsule := CapsuleMesh.new()
	capsule.radius = config.fighter_radius
	capsule.height = config.fighter_height
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = ToonMaterials.toon(color, RIM)
	_body.position.y = config.fighter_height * 0.5
	add_child(_body)

	var torus := TorusMesh.new()
	torus.inner_radius = config.fighter_radius * RING_INNER_RATIO
	torus.outer_radius = config.fighter_radius * RING_OUTER_RATIO
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, RING_FLATTEN, 1.0)
	_ring.position.y = RING_LIFT
	_ring.material_override = ToonMaterials.toon(color)
	add_child(_ring)

	_label = Label3D.new()
	_label.text = PlayerStyle.label(index)
	_label.font = load(DS.FONT_DISPLAY_PATH) as Font
	_label.font_size = DS.SIZE_TITLE
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = DS.UI_SURFACE
	_label.outline_modulate = DS.CANOPY_DEEP
	_label.outline_size = DS.TEXT_OUTLINE * 2
	_label.position.y = config.fighter_height + LABEL_GAP
	add_child(_label)


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	if int(curr["state"]) == Fighter.State.KO:
		visible = false
		return
	visible = true
	position = interpolate(prev, curr, alpha)
	var facing: Vector3 = curr["facing"]
	rotation.y = Collision.yaw_of(facing)
	_body.visible = blink_visible(int(curr["invuln_ticks"]), tick, _config)


static func interpolate(prev: Dictionary, curr: Dictionary, alpha: float) -> Vector3:
	var to: Vector3 = curr["pos"]
	if prev.is_empty() or prev.get("spawn_id") != curr.get("spawn_id"):
		return to
	var from: Vector3 = prev["pos"]
	return from.lerp(to, alpha)


static func blink_visible(invuln_ticks: int, tick: int, config: GameConfig) -> bool:
	if invuln_ticks <= 0:
		return true
	var hz := config.blink_hz_end if invuln_ticks <= SimTime.to_ticks(BLINK_END_SECONDS) else config.blink_hz
	var phase := floori(float(tick) * hz * 2.0 / SimTime.TICK_RATE)
	return phase % 2 == 0
```

- [ ] **Step 4: 경기장 가장자리 립**

`src/render/arena_view.gd`:
1. 상수 추가 (`SEGMENTS` 아래):
```gdscript
## Bright lip on the grass edge so the far side, where the dirt band is hidden, still reads (DS-VIS-04).
const LIP_WIDTH := 0.3
const LIP_FLATTEN := 0.06
const LIP_LIFT := 0.005
```
2. `var _rim` 아래에 `var _lip: MeshInstance3D` 추가
3. `setup()`에서 `_rim` 생성 다음 줄에:
```gdscript
	_lip = MeshInstance3D.new()
	add_child(_lip)
```
4. `_rebuild()` 끝에 추가:
```gdscript
	var lip := TorusMesh.new()
	lip.inner_radius = r - LIP_WIDTH
	lip.outer_radius = r
	lip.rings = SEGMENTS
	_lip.mesh = lip
	_lip.scale = Vector3(1.0, LIP_FLATTEN, 1.0)
	_lip.position.y = LIP_LIFT
	_lip.material_override = ToonMaterials.toon(DS.GRASS_SUN)
```

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh -gselect=test_fighter_view` → 5/5 PASS · `scripts/check-all.sh` → PASS (색은 전부 DS/PlayerStyle 경유)

(화면 증거는 main에 연결하는 T16에서 캡처한다.)

- [ ] **Step 6: 커밋**

```bash
git add src/render/fighter_view.gd src/render/fighter_view.gd.uid src/render/arena_view.gd tests/unit/test_fighter_view.gd tests/unit/test_fighter_view.gd.uid
git commit -m "feat: add fighter view with interpolation, respawn snap and blink

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: 타격감 v1 (흔들림·히트 퍼프) + 카메라 프레이밍 개선

**Files:**
- Create: `src/render/feel/shake_model.gd`, `src/render/feel/hit_spark.gd`, `src/render/feel/feel_director.gd`
- Modify: `src/render/camera_framing.gd`, `src/render/camera_rig.gd`
- Test: `tests/unit/test_shake_model.gd`, `tests/unit/test_camera_framing.gd` (추가)

**Interfaces:**
- Consumes: 히트 이벤트 `{"type": "hit", "pos", "knockback", "hitstop_ticks"}` (T6), 링아웃 이벤트 `{"type": "ringout", "pos"}` (T7), `GameConfig.shake_*`, `spark_large_threshold`, `cam_*` (T1), `SimTime` (T4)
- Produces:
  - `class_name ShakeModel extends RefCounted` — `_init(p_config: GameConfig)`, `add(knockback: float, delay_seconds: float) -> void`, `update(delta: float) -> Vector3` (카메라 오프셋), `amplitude() -> float`
  - `class_name HitSpark extends Node3D` — `play(at: Vector3, large: bool) -> void` (끝나면 스스로 해제)
  - `class_name FeelDirector extends Node3D` — `setup(config: GameConfig, camera: CameraRig) -> void`, `on_events(events: Array) -> void`
  - `CameraFraming.compute(targets, margin, zoom_min, zoom_max, fov_deg, aspect: float = 1.0, pitch_deg: float = 90.0) -> Dictionary` — x는 가로 FOV(`tan(v/2)·aspect`), z는 `sin(pitch)` 원근 축소를 반영해 각각 맞춘 뒤 큰 쪽 (기본값은 기존 동작과 동일)
  - `CameraRig.follow()`가 화면비·피치를 넘기고, `set_shake_offset(offset: Vector3) -> void`로 흔들림을 더한다
- 규칙 (GD-FEEL-02): 진폭 = `min(knockback × shake_per_knockback, shake_max)`, hitstop이 끝나는 시점(`hitstop_ticks / 60`초 뒤)에 시작, `exp(−shake_decay × t)`로 감쇠. 오프셋 패턴은 난수 없이 사인 합성. 링아웃은 `shake_max`로 즉시
- 규칙 (DS-VFX-01 v1): 넉백 ≥ `spark_large_threshold`면 대형(큰 퍼프 + 꽃잎 파티클), 아니면 소형 퍼프. 색은 `DS.GLOW`, 꽃잎 `DS.PETAL_PINK`
- 근거: `[GD-FEEL-01]` `[GD-FEEL-02]` `[DS-VFX-01]` `[GD-CAM-01]`, context D2

- [ ] **Step 1: 실패하는 테스트**

`tests/unit/test_shake_model.gd`:
```gdscript
extends GutTest


func test_amplitude_scales_with_knockback_and_caps() -> void:
	var c := GameConfig.new()
	var s := ShakeModel.new(c)
	s.add(10.0, 0.0)
	s.update(0.0)
	assert_almost_eq(s.amplitude(), 10.0 * c.shake_per_knockback, 0.0001)
	var big := ShakeModel.new(c)
	big.add(1000.0, 0.0)
	big.update(0.0)
	assert_almost_eq(big.amplitude(), c.shake_max, 0.0001)


func test_shake_waits_for_hitstop_then_decays() -> void:
	var c := GameConfig.new()
	var s := ShakeModel.new(c)
	s.add(20.0, 0.1)
	s.update(0.05)
	assert_eq(s.amplitude(), 0.0, "still in hitstop")
	s.update(0.06)
	var start := s.amplitude()
	assert_gt(start, 0.0)
	s.update(0.5)
	assert_lt(s.amplitude(), start * 0.1, "exponential decay")


func test_offset_is_zero_without_shake_and_bounded_with_it() -> void:
	var c := GameConfig.new()
	var s := ShakeModel.new(c)
	assert_eq(s.update(0.016), Vector3.ZERO)
	s.add(1000.0, 0.0)
	for i: int in 30:
		assert_true(s.update(0.016).length() <= c.shake_max * 1.5)
```

`tests/unit/test_camera_framing.gd` 끝에 추가:
```gdscript


func test_wide_aspect_fits_x_with_less_distance() -> void:
	var pts := PackedVector3Array([Vector3(-4, 0, 0), Vector3(4, 0, 0)])
	var square := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0, 1.0, 90.0)
	var wide := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0, 2.0, 90.0)
	assert_almost_eq(square["distance"], 4.0, 0.0001)
	assert_almost_eq(wide["distance"], 2.0, 0.0001, "horizontal half-FOV tangent doubles")


func test_pitch_shrinks_depth_extent() -> void:
	var pts := PackedVector3Array([Vector3(0, 0, -4), Vector3(0, 0, 4)])
	var f := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0, 1.0, 30.0)
	assert_almost_eq(f["distance"], 4.0 * sin(deg_to_rad(30.0)), 0.0001)


func test_launched_fighter_stays_framed_with_default_limits() -> void:
	var c := GameConfig.new()
	# a fighter 15 m past a 10 m arena edge, the other at the far edge
	var pts := PackedVector3Array([Vector3(25, 0, 0), Vector3(-10, 0, 0)])
	var f := CameraFraming.compute(pts, c.cam_margin, c.cam_zoom_min, c.cam_zoom_max, c.cam_fov, 16.0 / 9.0, c.cam_pitch)
	assert_lt(f["distance"], c.cam_zoom_max, "not clamped: the whole spread fits")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_shake_model` → FAIL (`ShakeModel` 미정의)
Run: `scripts/test.sh -gselect=test_camera_framing` → FAIL (인자 7개 시그니처 없음)

- [ ] **Step 3: CameraFraming x/z 분리**

`src/render/camera_framing.gd`의 `compute`를 교체:
```gdscript
## x fits the horizontal FOV (vertical FOV widened by the aspect ratio); z is foreshortened by
## the camera pitch. Defaults (aspect 1, pitch 90) reproduce the old single-extent behavior.
static func compute(targets: PackedVector3Array, margin: float, zoom_min: float, zoom_max: float,
		fov_deg: float, aspect: float = 1.0, pitch_deg: float = 90.0) -> Dictionary:
	if targets.is_empty():
		return {"center": Vector3.ZERO, "distance": zoom_min}
	var lo := targets[0]
	var hi := targets[0]
	for p: Vector3 in targets:
		lo = lo.min(p)
		hi = hi.max(p)
	var half_x := (hi.x - lo.x) * 0.5 + margin
	var half_z := (hi.z - lo.z) * 0.5 + margin
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var dist_x := half_x / (t * maxf(aspect, 0.01))
	var dist_z := half_z * sin(deg_to_rad(pitch_deg)) / t
	return {"center": (lo + hi) * 0.5, "distance": clampf(maxf(dist_x, dist_z), zoom_min, zoom_max)}
```

- [ ] **Step 4: CameraRig 화면비·피치·흔들림**

`src/render/camera_rig.gd`:
1. `var _distance` 아래에 `var _shake_offset: Vector3 = Vector3.ZERO` 추가
2. `follow()`의 `compute` 호출을 교체:
```gdscript
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var frame := CameraFraming.compute(targets, _config.cam_margin, _config.cam_zoom_min,
			_config.cam_zoom_max, _config.cam_fov, aspect, _config.cam_pitch)
```
3. `_camera.position = ...` 줄을 교체하고 흔들림은 look_at 이후 오프셋으로 더한다:
```gdscript
	_camera.position = _center + Vector3(0.0, sin(pitch), cos(pitch)) * _distance
	_camera.look_at(_center, Vector3.UP)
	_camera.position += _shake_offset
```
4. 파일 끝에 추가:
```gdscript


func set_shake_offset(offset: Vector3) -> void:
	_shake_offset = offset
```

- [ ] **Step 5: ShakeModel**

`src/render/feel/shake_model.gd`:
```gdscript
class_name ShakeModel
extends RefCounted
## Screen shake (design.md GD-FEEL-02): amplitude = min(knockback x shake_per_knockback, shake_max),
## starting when hitstop ends, decaying exponentially. Deterministic sine pattern, no randomness.

## Incommensurate frequencies (Hz) so the offset never settles into a visible loop.
const FREQ_X := 41.0
const FREQ_Y := 53.0
const FREQ_PHASE := 1.3

var _config: GameConfig
var _amplitude: float = 0.0
var _time: float = 0.0
## Pending shakes as Vector2(seconds_until_start, amplitude).
var _pending: Array[Vector2] = []


func _init(p_config: GameConfig) -> void:
	_config = p_config


func add(knockback: float, delay_seconds: float) -> void:
	var amp := minf(knockback * _config.shake_per_knockback, _config.shake_max)
	_pending.append(Vector2(delay_seconds, amp))


func amplitude() -> float:
	return _amplitude


func update(delta: float) -> Vector3:
	var still: Array[Vector2] = []
	for p: Vector2 in _pending:
		var left := p.x - delta
		if left <= 0.0:
			_amplitude = maxf(_amplitude, p.y)
		else:
			still.append(Vector2(left, p.y))
	_pending = still
	_amplitude *= exp(-_config.shake_decay * delta) if delta > 0.0 else 1.0
	_time += delta
	if _amplitude <= 0.0:
		return Vector3.ZERO
	return Vector3(sin(_time * FREQ_X), sin(_time * FREQ_Y + FREQ_PHASE), 0.0) * _amplitude
```

(시작 틱에 막 합류한 진폭도 같은 update에서 감쇠가 한 번 적용된다. 첫 테스트는 `update(0.0)`이라 감쇠 없이 그대로 확인한다.)

- [ ] **Step 6: HitSpark**

`src/render/feel/hit_spark.gd`:
```gdscript
class_name HitSpark
extends Node3D
## Hit puff v1 (design.md DS-VFX-01): a soft glow puff that swells and shrinks away; large hits
## add a burst of petals. Round shapes only (no sharp spark lines). Frees itself when done.

const SMALL_SCALE := 0.6
const LARGE_SCALE := 1.2
const START_SCALE := 0.2
const PETAL_COUNT := 12
const PETAL_SIZE := 0.08
const PETAL_SPEED := 4.0
const PETAL_GRAVITY := Vector3(0, -9.0, 0)
const PETAL_LIFETIME := 0.6
const LIFETIME := 0.8


func play(at: Vector3, large: bool) -> void:
	position = at
	var puff := MeshInstance3D.new()
	puff.mesh = SphereMesh.new()
	puff.material_override = ToonMaterials.toon(DS.GLOW)
	puff.scale = Vector3.ONE * START_SCALE
	add_child(puff)
	var peak := LARGE_SCALE if large else SMALL_SCALE
	var tw := create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * peak, DS.MOTION_FAST).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "scale", Vector3.ZERO, DS.MOTION_BASE).set_ease(Tween.EASE_IN)
	if large:
		add_child(_petals())
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _petals() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var petal := SphereMesh.new()
	petal.radius = PETAL_SIZE
	petal.height = PETAL_SIZE * 2.0
	petal.material = ToonMaterials.toon(DS.PETAL_PINK)
	p.mesh = petal
	p.amount = PETAL_COUNT
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = PETAL_LIFETIME
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = PETAL_SPEED * 0.5
	p.initial_velocity_max = PETAL_SPEED
	p.gravity = PETAL_GRAVITY
	p.emitting = true
	return p
```

(`petal.material`에 캐시 머티리얼을 그대로 참조로 넣는 것은 수정이 아니므로 허용된다.)

- [ ] **Step 7: FeelDirector**

`src/render/feel/feel_director.gd`:
```gdscript
class_name FeelDirector
extends Node3D
## Turns sim events into game feel (design.md §9): hit puffs sized by knockback, screen shake that
## starts when hitstop ends, a full-strength shake on ring-out. Render-side only.

var _config: GameConfig
var _camera: CameraRig
var _shake: ShakeModel


func setup(config: GameConfig, camera: CameraRig) -> void:
	_config = config
	_camera = camera
	_shake = ShakeModel.new(config)


func on_events(events: Array) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"hit":
				var kb: float = e["knockback"]
				var spark := HitSpark.new()
				add_child(spark)
				spark.play(e["pos"], kb >= _config.spark_large_threshold)
				_shake.add(kb, float(e["hitstop_ticks"]) / SimTime.TICK_RATE)
			"ringout":
				_shake.add(_config.shake_max / maxf(_config.shake_per_knockback, 0.0001), 0.0)


func _process(delta: float) -> void:
	if _shake != null and _camera != null:
		_camera.set_shake_offset(_shake.update(delta))
```

- [ ] **Step 8: 통과 확인**

Run: `scripts/test.sh -gselect=test_shake_model` → 3/3 PASS · `scripts/test.sh -gselect=test_camera_framing` → 7/7 PASS (기존 4 + 신규 3)
Run: `scripts/check-all.sh` → `ALL CHECKS PASSED`

(화면 증거는 T16에서 main에 연결한 뒤 캡처한다.)

- [ ] **Step 9: 커밋**

```bash
git add src/render/feel src/render/camera_framing.gd src/render/camera_rig.gd tests/unit/test_shake_model.gd tests/unit/test_shake_model.gd.uid tests/unit/test_camera_framing.gd
git commit -m "feat: add knockback-scaled shake, hit puffs and aspect-aware framing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: main 연결 — 경기 루프·입력·봇·HUD·연출·결과·재시작·틱 비용

**Files:**
- Modify: `src/main/main.gd` (전체 교체), `scripts/capture_evidence.gd` (`--show-touch` 추가)
- Test: `tests/unit/test_main_smoke.gd`

**Interfaces:**
- Consumes: T1~T15 전부 — `World(config, seed, count)`, `BotController`, `LocalInput`, `TouchInput`, `InputBindings`, `FighterView`, `Hud`, `FeelDirector`, `CameraRig`, `ConfigPanel`
- Produces:
  - `main.gd`: `func get_world() -> World` (측정 스크립트용), `func _gather_inputs() -> Array[InputFrame]` (T17 데모 씬이 오버라이드), `func _start_match() -> void` (재시작, 데모가 오버라이드)
  - 디버그 패널 정보 줄: `tick · tps · sim ms/tick · alpha · fps` (틱 비용 훅, PRD-NFR-02)
  - `capture_evidence.gd --show-touch`: 씬에서 TouchInput을 찾아 보이게 한다
- 순서 (매 프레임): `LocalInput.poll()` → 틱마다 [입력 수집 → `World.tick` → 비용 측정 → view 갱신 → 이벤트 누적] → 파이터 보간 → HUD → 연출 → 카메라(살아 있는 파이터 추적, 없으면 경기장) → 경기 종료 시 결과 배너 1회
- 근거: `[PRD-UI-01]` `[PRD-NFR-02]` `[PRD-ARCH-02]` `[PRD-CFG-01]` `[GD-CAM-01]`

- [ ] **Step 1: 실패하는 스모크 테스트**

`tests/unit/test_main_smoke.gd`:
```gdscript
extends GutTest


func test_main_runs_a_match_loop() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.5)
	var w: World = main.call("get_world")
	assert_not_null(w)
	assert_gt(w.tick_count, 0, "fixed ticks advanced")
	assert_eq(w.fighters.size(), 2)
	assert_ne(w.fighters[1].pos, Rules.spawn_point(1, 2, w.config), "the bot moved")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_main_smoke` → FAIL (`get_world` 없음)

- [ ] **Step 3: main.gd 교체**

`src/main/main.gd` 전체:
```gdscript
extends Node
## Entry point: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4).
## Phase 1: local player (keyboard + touch) vs bot, HUD, game feel, result and restart.

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := 1
const PLAYER_COUNT := 2
const LOCAL_PLAYER := 0
const BOT_PLAYER := 1
## Smoothing factor for the per-tick sim cost shown in the debug panel.
const SIM_COST_SMOOTHING := 0.1

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _camera: CameraRig
var _panel: ConfigPanel
var _local_input: LocalInput
var _bot: BotController
var _views: Array[FighterView] = []
var _hud: Hud
var _feel: FeelDirector
var _result_shown: bool = false
## Render interpolation contract: views lerp prev -> curr by _alpha.
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _tps_ticks: int = 0
var _tps_time: float = 0.0
var _tps: float = 0.0
var _sim_us: float = 0.0


func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("main: GameConfig missing at %s" % CONFIG_PATH)
		get_tree().quit(1)
		set_process(false)
		return
	InputBindings.apply()
	_ticker = FixedTicker.new(_config.max_ticks_per_frame)
	_config.changed.connect(func() -> void: _ticker.max_ticks_per_frame = _config.max_ticks_per_frame)

	var env := EnvironmentRig.new()
	add_child(env)
	env.setup()
	var arena := ArenaView.new()
	add_child(arena)
	arena.setup(_config)
	var decor := DecorView.new()
	add_child(decor)
	decor.setup(_config, SEED)
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.setup(_config)
	_feel = FeelDirector.new()
	add_child(_feel)
	_feel.setup(_config, _camera)
	for i: int in PLAYER_COUNT:
		var view := FighterView.new()
		add_child(view)
		view.setup(i, _config)
		_views.append(view)

	_local_input = LocalInput.new()
	var touch := TouchInput.new()
	add_child(touch)
	touch.setup(_local_input, _config)
	_hud = Hud.new()
	add_child(_hud)
	_hud.restart_requested.connect(_start_match)
	if OS.is_debug_build():
		_panel = ConfigPanel.new()
		add_child(_panel)
		_panel.setup(_config)
	_start_match()


func get_world() -> World:
	return _world


func _start_match() -> void:
	_world = World.new(_config, SEED, PLAYER_COUNT)
	_bot = BotController.new(BOT_PLAYER, _config)
	_hud.setup(PLAYER_COUNT, _config.stocks)
	_result_shown = false
	_curr_state = _world.state_view()
	_prev_state = _curr_state


func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = [_local_input.sample(), _bot.sample(_curr_state)]
	return inputs


func _process(delta: float) -> void:
	_local_input.poll()
	var ticks := _ticker.advance(delta)
	var events: Array = []
	for i: int in ticks:
		_prev_state = _curr_state
		var started := Time.get_ticks_usec()
		_world.tick(_gather_inputs())
		_sim_us = lerpf(_sim_us, float(Time.get_ticks_usec() - started), SIM_COST_SMOOTHING)
		_curr_state = _world.state_view()
		events.append_array(_curr_state["events"])
	_alpha = _ticker.alpha()
	_draw_fighters()
	_hud.update_from(_curr_state)
	_feel.on_events(events)
	_camera.follow(_camera_targets(), delta)
	if bool(_curr_state["match_over"]) and not _result_shown:
		_result_shown = true
		_hud.show_result(int(_curr_state["winner"]), LOCAL_PLAYER)
	_update_info(delta, ticks)


func _unhandled_input(event: InputEvent) -> void:
	if _result_shown and event.is_action_pressed("ui_accept"):
		_start_match()


func _draw_fighters() -> void:
	var prev: Array = _prev_state["fighters"]
	var curr: Array = _curr_state["fighters"]
	var tick := int(_curr_state["tick"])
	for i: int in _views.size():
		var before: Dictionary = prev[i] if i < prev.size() else {}
		_views[i].apply(before, curr[i], _alpha, tick)


func _camera_targets() -> PackedVector3Array:
	var pts := PackedVector3Array()
	for f: Dictionary in _curr_state["fighters"]:
		if int(f["state"]) != Fighter.State.KO:
			pts.append(f["pos"])
	if pts.is_empty():
		var r := _config.arena_radius
		pts = PackedVector3Array([Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, -r), Vector3(0, 0, r)])
	return pts


func _update_info(delta: float, ticks: int) -> void:
	_tps_ticks += ticks
	_tps_time += delta
	if _tps_time >= 1.0:
		_tps = _tps_ticks / _tps_time
		_tps_ticks = 0
		_tps_time = 0.0
	if _panel == null:
		return
	_panel.set_info("tick %d · %.0f tps · sim %.3f ms · alpha %.2f · %d fps" % [
		_world.tick_count, _tps, _sim_us / 1000.0, _alpha, Engine.get_frames_per_second()])
```

- [ ] **Step 4: capture_evidence `--show-touch`**

`scripts/capture_evidence.gd`:
1. usage 주석에 `[--show-touch]` 추가
2. `if args.has("show-panel"):` 블록 아래에 추가:
```gdscript
	if args.has("show-touch"):
		var touch := _find_touch_input(instance)
		if touch == null:
			push_error("capture_evidence: no TouchInput found in scene tree")
			quit(1)
			return
		touch.visible = true
```
3. `_find_config_panel` 아래에 추가:
```gdscript


func _find_touch_input(node: Node) -> TouchInput:
	if node is TouchInput:
		return node
	for child: Node in node.get_children():
		var found := _find_touch_input(child)
		if found != null:
			return found
	return null
```

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh -gselect=test_main_smoke` → PASS · `scripts/check-all.sh` → `ALL CHECKS PASSED`

- [ ] **Step 6: 화면 증거 + 수동 확인**

```bash
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out=$PWD/dev/active/phase-1/evidence/match-hud.png --frames=150 --show-touch
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out=$PWD/dev/active/phase-1/evidence/match-panel.png --frames=150 --show-panel
```
이미지를 직접 열어 확인:
1. 파랑·빨강 캡슐 + 발밑 링 + `P1`/`P2` 라벨, 봇이 플레이어 쪽으로 다가와 있다
2. 상단 좌우에 DamageCounter(%)와 스톡 3개, 봇이 때렸다면 P1 % > 0
3. 하단 왼쪽 스틱 영역(보이지 않음이 정상), 오른쪽 아래 "공격"·"점프" 버튼
4. 경기장 가장자리 밝은 립, 청록 그림자
5. 패널 정보 줄에 `sim … ms`, 새 그룹(Fighter·Rules·LightAttack·Bot·Feel)의 슬라이더

그다음 `godot --path .`으로 직접 플레이: WASD 이동, Space 점프(2단), J 약공격. 봇을 때리면 퍼프와 흔들림이 보이고 % 가 오른다. (링아웃까지의 체감은 T17 튜닝 후 확인)

- [ ] **Step 7: 커밋**

```bash
git add src/main/main.gd scripts/capture_evidence.gd tests/unit/test_main_smoke.gd tests/unit/test_main_smoke.gd.uid dev/active/phase-1/evidence/match-hud.png dev/active/phase-1/evidence/match-panel.png
git commit -m "feat: wire phase 1 match loop with bot, HUD, feel and restart

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: 측정·튜닝 — sim 벤치, 입력 지연, 링아웃 체감 + 영상

**Files:**
- Create: `src/debug/feel_scenario.gd`, `src/debug/ringout_demo.gd` + `.tscn`, `scripts/bench_sim.gd`, `scripts/measure_input_latency.gd`, `scripts/tune_knockback.gd`
- Modify: `src/config/game_config.gd` (`global_knockback_mul` 튜닝값), `tests/unit/test_game_config.gd` (기대값), `tests/replay/test_replay.gd` (골든 재생성), `docs/PRD.md` §4.5 (초기값 표), `.gitignore` (`*.avi`)
- Test: `tests/unit/test_ringout_feel.gd`

**Interfaces:**
- Consumes: `World`, `BotController`, `main.gd`의 `get_world()`·`_start_match()`·`_gather_inputs()` (T16)
- Produces:
  - `class_name FeelScenario` — `const TARGET_DISTANCE_RATIO := 0.5`, `const MAX_TICKS := 600`, `static func rings_out(config: GameConfig, damage: float) -> bool` (중앙과 가장자리 사이에 선 대상이 `damage`%에서 약공격 한 방을 맞고 링아웃되는지)
  - 측정 기록: `dev/active/phase-1/evidence/measurements.md` (벤치·지연·튜닝 결과)
- 완료 기준 연결: "100% 이상에서 약공격 한 방에 날아간다" = `FeelScenario.rings_out(config, 100) == true` 이고 `rings_out(config, 0) == false` (대미지에 비례해야 한다)
- 근거: `[PRD-CORE-01]` `[PRD-RULE-04]` `[PRD-NFR-02]` `[PRD-NFR-03]`

- [ ] **Step 1: 링아웃 체감 시나리오 + 실패하는 테스트**

`src/debug/feel_scenario.gd`:
```gdscript
class_name FeelScenario
extends RefCounted
## The Phase 1 feel check (PRD §1.1 "과장된 넉백"): a target standing halfway between the
## arena center and edge takes one light attack at the given damage %. Shared by the
## regression test and scripts/tune_knockback.gd so both measure the same thing.

const TARGET_DISTANCE_RATIO := 0.5
const MAX_TICKS := 600
const ATTACKER_GAP := 1.0


static func rings_out(config: GameConfig, damage: float) -> bool:
	var w := World.new(config, 1)
	var target := w.fighters[1]
	target.pos = Vector3(config.arena_radius * TARGET_DISTANCE_RATIO, 0, 0)
	target.damage = damage
	var attacker := w.fighters[0]
	attacker.pos = target.pos - Vector3(ATTACKER_GAP, 0, 0)
	attacker.facing = Vector3(1, 0, 0)
	var swing: Array[InputFrame] = [InputFrame.make(0, 0, false, true), InputFrame.neutral()]
	w.tick(swing)
	var idle: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	for i: int in MAX_TICKS:
		w.tick(idle)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "ringout" and int(e["id"]) == 1:
				return true
	return false
```

`tests/unit/test_ringout_feel.gd`:
```gdscript
extends GutTest


func test_strong_hit_at_100_percent_rings_out() -> void:
	assert_true(FeelScenario.rings_out(GameConfig.new(), 100.0),
			"PHASES Phase 1: at 100%+ one light attack must send the target out")


func test_same_hit_at_0_percent_stays_on_stage() -> void:
	assert_false(FeelScenario.rings_out(GameConfig.new(), 0.0), "knockback must scale with damage")
```

Run: `scripts/test.sh -gselect=test_ringout_feel`
Expected: `test_strong_hit_at_100_percent_rings_out` FAIL (PRD 초기값 `global_knockback_mul = 1.0`으로는 약 2~3 m밖에 날아가지 않는다 — context 열린 이슈 3), 0% 테스트는 PASS.

- [ ] **Step 2: 튜닝 스크립트로 최소 배율 탐색**

`scripts/tune_knockback.gd`:
```gdscript
extends SceneTree
## Finds the smallest global_knockback_mul for which FeelScenario rings out at 100%, and checks
## the same value keeps a 0% hit on stage. Prints a recommended default with a safety margin.
## Run: godot --headless --path . -s res://scripts/tune_knockback.gd

const LOW := 0.5
const HIGH := 10.0
const ITERATIONS := 20
const SAFETY := 1.15
const ROUND_TO := 0.05


func _init() -> void:
	var lo := LOW
	var hi := HIGH
	if not _rings(hi, 100.0):
		push_error("tune_knockback: even %.2f does not ring out at 100%%" % hi)
		quit(1)
		return
	for i: int in ITERATIONS:
		var mid := (lo + hi) * 0.5
		if _rings(mid, 100.0):
			hi = mid
		else:
			lo = mid
	var recommended := snappedf(hi * SAFETY, ROUND_TO)
	print("tune_knockback: minimum %.3f, recommended %.2f" % [hi, recommended])
	print("tune_knockback: 0%% stays on stage at recommended: %s" % str(not _rings(recommended, 0.0)))
	quit(0)


func _rings(mul: float, damage: float) -> bool:
	var c := GameConfig.new()
	c.global_knockback_mul = mul
	return FeelScenario.rings_out(c, damage)
```

Run: `godot --headless --path . -s res://scripts/tune_knockback.gd`
기록할 출력: `minimum <m>, recommended <R>` 와 `0% stays on stage at recommended: true`.
`false`가 나오면(0%에서도 날아가면) 배율만으로는 안 되는 것이다 — `light_base_knockback`을 0.5씩 낮추고 다시 돌려 두 조건을 동시에 만족하는 조합을 찾는다.

- [ ] **Step 3: 튜닝값 반영 + 연쇄 갱신**

1. `src/config/game_config.gd`: `global_knockback_mul` 기본값을 `<R>`로 (조정했다면 `light_base_knockback`도)
2. `tests/unit/test_game_config.gd`: `test_global_knockback_default`의 기대값을 `<R>`로
3. `docs/PRD.md` §4.5 초기값 표에 행 추가: `| global_knockback_mul | <R> (Phase 1 튜닝: 중간 거리 100% 약공격 한 방 링아웃) |` (README R6)
4. Run: `scripts/test.sh -gselect=test_replay` → `test_golden_hash`가 새 값을 출력하며 FAIL (config가 바뀌었으므로 정상) → 출력값으로 `GOLDEN_HASH` 갱신

Run: `scripts/test.sh` → 전체 PASS (`test_ringout_feel` 2/2 포함) · `scripts/check-all.sh` → PASS

- [ ] **Step 4: sim 벤치마크 (4인 봇전)**

`scripts/bench_sim.gd`:
```gdscript
extends SceneTree
## Sim cost per tick for a 4-fighter bot match (PRD-NFR-02: <= 2 ms/tick on target mobile).
## Run: godot --headless --path . -s res://scripts/bench_sim.gd

const PLAYERS := 4
const TICKS := 600
const SEED := 3


func _init() -> void:
	var config := GameConfig.new()
	var world := World.new(config, SEED, PLAYERS)
	var bots: Array[BotController] = []
	for i: int in PLAYERS:
		bots.append(BotController.new(i, config))
	var total := 0
	var worst := 0
	for t: int in TICKS:
		var view := world.state_view()
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(view))
		var started := Time.get_ticks_usec()
		world.tick(inputs)
		var cost := Time.get_ticks_usec() - started
		total += cost
		worst = maxi(worst, cost)
	print("bench_sim: %d fighters, %d ticks, avg %.1f us/tick, worst %d us/tick" % [
		PLAYERS, TICKS, float(total) / TICKS, worst])
	quit(0)
```

Run: `godot --headless --path . -s res://scripts/bench_sim.gd` → 출력 한 줄을 기록. 데스크톱 평균이 2000 us를 넘으면 PRD §5.6 GDExtension 기준을 검토 대상으로 context에 적는다 (모바일 실측은 기기 확보 후).

- [ ] **Step 5: 입력 지연 측정**

`scripts/measure_input_latency.gd`:
```gdscript
extends SceneTree
## Frames from a jump key press to the local fighter leaving the ground, counting the frame that
## draws it (PRD-NFR-03: <= 3). Run windowed so frame timing matches real play:
##   godot --path . -s res://scripts/measure_input_latency.gd

const MAIN_SCENE := "res://src/main/main.tscn"
const WARMUP_FRAMES := 30
const GIVE_UP_FRAMES := 30
const LIFT := 0.01
const BUDGET := 3

var _main: Node
var _frame: int = 0
var _pressed_at: int = -1


func _init() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == WARMUP_FRAMES:
		Input.action_press("p1_jump")
		_pressed_at = _frame
		return
	if _pressed_at < 0:
		return
	if _frame == _pressed_at + 1:
		Input.action_release("p1_jump")
	var w: World = _main.call("get_world")
	if w.fighters[0].pos.y > LIFT:
		var frames := _frame - _pressed_at + 1
		print("measure_input_latency: %d frames (budget %d)" % [frames, BUDGET])
		quit(0 if frames <= BUDGET else 1)
	elif _frame - _pressed_at > GIVE_UP_FRAMES:
		push_error("measure_input_latency: fighter never left the ground")
		quit(1)
```

Run: `godot --path . -s res://scripts/measure_input_latency.gd` → `N frames (budget 3)`, exit 0. 3을 넘으면 원인을 context에 기록하고(예: 틱 누산기 위상) 수정 태스크를 제안한다.

- [ ] **Step 6: 링아웃 데모 씬 + 영상·프레임 증거**

`src/debug/ringout_demo.gd`:
```gdscript
extends "res://src/main/main.gd"
## Phase 1 evidence scene: the bot stands at 100% halfway to the edge and the player lands one
## light attack at tick 60. Used for the ring-out video and key frames (PHASES Phase 1).

const DEMO_DAMAGE := 100.0
const SWING_TICK := 60


func _start_match() -> void:
	super._start_match()
	var w := get_world()
	var target := w.fighters[BOT_PLAYER]
	target.pos = Vector3(w.config.arena_radius * FeelScenario.TARGET_DISTANCE_RATIO, 0, 0)
	target.damage = DEMO_DAMAGE
	target.facing = Vector3(-1, 0, 0)
	var attacker := w.fighters[LOCAL_PLAYER]
	attacker.pos = target.pos - Vector3(FeelScenario.ATTACKER_GAP, 0, 0)
	attacker.facing = Vector3(1, 0, 0)


func _gather_inputs() -> Array[InputFrame]:
	var swing := get_world().tick_count == SWING_TICK
	var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, swing), InputFrame.neutral()]
	return inputs
```

`src/debug/ringout_demo.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/debug/ringout_demo.gd" id="1"]

[node name="RingoutDemo" type="Node"]
script = ExtResource("1")
```

`.gitignore`에 `*.avi` 추가 (영상은 커밋하지 않고 로컬 증거로 둔다).

```bash
godot --path . --write-movie dev/active/phase-1/evidence/ringout.avi --fixed-fps 60 --resolution 960x540 --quit-after 300 res://src/debug/ringout_demo.tscn
for f in 58 70 100; do
  godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ringout_demo.tscn --out=$PWD/dev/active/phase-1/evidence/ringout-$f.png --frames=$f
done
```
프레임을 직접 열어 확인: 58 = 맞기 직전, 70 = 히트 퍼프(대형) + 흔들림 + 날아가는 빨강 캡슐, 100 = 경기장 밖으로 떨어지는 중 또는 링아웃 직후 P2 스톡 2개. 영상(`ringout.avi`)은 사용자에게 보여줄 로컬 증거로 둔다.

- [ ] **Step 7: 측정 기록**

`dev/active/phase-1/evidence/measurements.md`:
```markdown
# Phase 1 측정 기록

| 항목 | 명령 | 결과 | 기준 |
|---|---|---|---|
| sim 비용 (봇 4, 600틱, 데스크톱) | `godot --headless --path . -s res://scripts/bench_sim.gd` | avg <A> us/tick, worst <W> us/tick | 모바일 ≤ 2 ms (PRD-NFR-02) |
| 입력 지연 (점프) | `godot --path . -s res://scripts/measure_input_latency.gd` | <N> frames | ≤ 3 (PRD-NFR-03) |
| 넉백 튜닝 | `godot --headless --path . -s res://scripts/tune_knockback.gd` | minimum <m>, 채택 <R> | 100% 링아웃 & 0% 잔류 |
```
`<…>`를 Step 2·4·5의 실제 출력으로 채운다.

- [ ] **Step 8: 커밋**

```bash
git add src/debug/feel_scenario.gd src/debug/ringout_demo.gd src/debug/ringout_demo.tscn scripts/bench_sim.gd scripts/measure_input_latency.gd scripts/tune_knockback.gd src/config/game_config.gd tests/unit/test_game_config.gd tests/unit/test_ringout_feel.gd tests/replay/test_replay.gd docs/PRD.md .gitignore dev/active/phase-1/evidence/ringout-*.png dev/active/phase-1/evidence/measurements.md
git add src/debug/*.uid scripts/*.uid tests/unit/*.uid
git commit -m "feat: tune knockback for ring-outs and add sim/latency measurements

global_knockback_mul raised to <R> so a 100% light hit from mid-arena rings out;
replay golden hash regenerated because the default config changed.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Phase 1 마감 — 검사·증거·문서

**Files:**
- Modify: `docs/PHASES.md` (Phase 1 체크박스), `docs/design.md` (§12 추적표 상태, 버전 0.4), `dev/active/phase-1/phase-1-context.md`, `dev/active/phase-1/phase-1-tasks.md`, `ASSETS.md` (Phase 1에서 추가된 외부 에셋이 없으면 변경 없음)

**Interfaces:**
- Consumes: T1~T17 전부
- Produces: Phase 1 완료 판정과 Phase 2가 읽을 context
- 근거: `docs/README.md` R3·R4·§4 "Phase 완료"

- [ ] **Step 1: 전체 검사**

Run: `scripts/check-all.sh` → `ALL CHECKS PASSED` (테스트·sim 순수성·색·문서 추적). 출력을 context에 붙인다.

- [ ] **Step 2: 완료 기준 증거표 (PHASES.md Phase 1)**

| 완료 기준 | 증거 |
|---|---|
| 봇과 한 판을 끝까지 — 키보드 | 직접 플레이 후 결과 배너 스크린샷 `evidence/result-keyboard.png` (플레이 중 `screencapture -w`) |
| 봇과 한 판을 끝까지 — Android 터치 | APK 설치 후 실기기 플레이 스크린샷 `evidence/android-touch.png` — 기기가 없으면 미체크 + " — 실기기 확인 대기" |
| 100%+ 약공격 한 방에 날아가는 게 보인다 | `test_ringout_feel` PASS + `evidence/ringout-58/70/100.png` + 로컬 `ringout.avi` |
| HUD가 휴대폰에서 한눈에 읽힌다 | 실기기 스크린샷 (없으면 `evidence/match-hud.png` + " — 실기기 확인 대기") |
| 4인 1틱 비용 측정·기록 | `evidence/measurements.md` |
| 입력 → 화면 ≤ 3프레임 | `evidence/measurements.md` |
| 모든 전투·타격감 수치가 디버그 패널에 있다 | `evidence/match-panel.png` + `test_config_schema` |

증거 없는 항목은 체크하지 않는다 (Phase 0 T13 교훈).

- [ ] **Step 3: 문서 갱신**

1. `docs/PHASES.md` Phase 1: 증거가 있는 ⚙️/🎨 태스크와 완료 기준만 `[x]`
2. `docs/design.md` §12: `DS-CMP-01`, `DS-CMP-02`, `DS-CMP-03`, `DS-CMP-09`, `DS-LAY-02`(T12 결정 시), `GD-FEEL-01~03` → ✅ / `DS-CMP-04`(v1만), `DS-VIS-03`(P1·P2만), `DS-VIS-04`, `DS-VFX-01`(v1), `DS-LAY-01`, `GD-CAM-01` → 🟨 / 상단 버전 `0.4 · (0.4: Phase 1 HUD·터치·타격감 v1)`
3. `phase-1-context.md`: 상태 "구현 완료", 결정 D1~D7의 최종 상태, 측정값, 알려진 차이, "Phase 2로 넘기는 항목"
4. `phase-1-tasks.md`: 상태 칸 ✅ / 🖼 대기 / 실기기 대기

- [ ] **Step 4: 최종 리뷰 후 이동 (컨트롤러)**

SDD 최종 전체 리뷰(opus)가 끝난 뒤 `git mv dev/active/phase-1 dev/done/phase-1`.

- [ ] **Step 5: 커밋**

```bash
git add docs/PHASES.md docs/design.md dev/active/phase-1
git commit -m "docs: close phase 1 with evidence and traceability

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review 결과

**Spec 커버리지 (PHASES.md Phase 1):**

| PHASES 항목 | 태스크 |
|---|---|
| collision (캡슐–박스, 캡슐–캡슐, 지면·경계) | T3 |
| fighter 상태 머신 (idle/move/jump/attack/hitstun/launched/respawn) | T4 (enum + launched·respawn 해석), T5 |
| 이동·점프·2단 점프·중력 | T5 |
| 약공격 (전방 박스, 활성 프레임, 대미지 %) | T4, T6 |
| 넉백 공식·hitstun·hitstop | T6 |
| 링아웃·스톡 3·리스폰 무적·승패 | T7 |
| 틱 비용 계측 훅 | T16 (패널 정보 줄), T17 (벤치) |
| 키보드 입력 | T10 |
| 터치 기본 (스틱 + 점프 + 공격 탭) | T11 |
| 봇 1단계 | T9 |
| 캡슐 뷰 + 보간, 승패 화면 + 재시작 | T14, T13, T16 |
| DamageCounter / StockIcons / TouchStick / TouchButton v1 / ResultBanner | T13, T11 |
| 플레이어 식별 (링 + 라벨) | T14 |
| 타격감 v1 (퍼프·흔들림·깜빡임) | T15, T14 |
| 경기장 가장자리 가독성 | T14 |
| HUD 레이아웃 + 🖼 | T12, T13 |
| 갤러리 등록 | T11, T13 |
| 테스트: 넉백 0/50/150, hitstun 입력 무시, hitstop 위치 불변, 링아웃·리스폰·무적, 스톡 0 승패, 600틱 리플레이 해시 | T6, T7, T8 |
| 완료 기준 6개 | T17 측정, T18 증거표 |
| Phase 0 이월 (config 입력·카메라·리플레이·보간 스냅·입력 양자화·ConfigSchema 가드·global_knockback 테스트) | T1, T2, T5, T8, T14, T15 |

**플레이스홀더 점검:** 코드 단계는 모두 전체 코드. 값이 실행 결과에 따라 정해지는 곳은 두 군데뿐이며 절차가 명시돼 있다 — 리플레이 `GOLDEN_HASH`(T8 Step 3~4, T17 Step 3)와 넉백 튜닝값 `<R>`(T17 Step 2~3).

**타입·이름 일관성:** `World(config, seed, count)` / `state_view()` 키(`tick, arena_radius, match_over, winner, fighters, events`) / `Fighter.to_view()` 키 / 이벤트 키(`hit`: attacker·target·pos·knockback·hitstop_ticks, `ringout`: id·pos·stocks_left) / `Rules.ONGOING·DRAW` / `GameConfig` 필드명이 정의 태스크와 사용 태스크(T9·T13·T14·T15·T16·T17)에서 일치하는지 확인함.

**설계 중 발견해 반영한 수정:**
- 공중에서 입력이 없을 때 수평 속도를 0으로 덮어쓰면 hitstun이 끝나는 순간 날아가던 캐릭터가 멈춘다 → `air_acceleration`·`air_drag`로 관성 유지 (T1, T5)
- ConfigSchema 가드 테스트는 step 자리에 접미어가 오는 경우를 재현하도록 커스텀 속성 목록 사용 (T1)
- 봇 쿨다운 테스트는 "다음 공격까지 대기 샘플 수 = 쿨다운 − 1"로 측정 (T9)
