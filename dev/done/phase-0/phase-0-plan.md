# Phase 0 — 뼈대 + 멀티플랫폼 검증 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 빈 숲 경기장이 데스크톱·Android·웹에서 뜨고, 60Hz 고정 틱 루프가 돌며, 디버그 패널로 `GameConfig` 수치를 실시간 조절할 수 있고, UI는 디자인 토큰으로만 그려지는 Godot 4 프로젝트 골격을 만든다.

**Architecture:** `src/sim/`은 `RefCounted` 순수 로직(World, InputFrame)이고 렌더·노드를 모른다. `src/main/main.gd`가 `FixedTicker`로 60Hz 틱을 돌리고, `src/render/`의 노드들이 `GameConfig`와 sim 상태를 읽어 그린다. 색·크기는 `src/ui/theme/tokens.gd`(DS) 한 곳에서만 나오고, 3D 비주얼 토큰은 글로벌 셰이더 파라미터로 관리한다.

**Tech Stack:** Godot 4.5+ (GDScript, 정적 타입), GUT 9.x (헤드리스 테스트), Jua·Pretendard 폰트(OFL), JDK 17 + Android SDK, Python `http.server`(웹 로컬 확인)

**Spec:** [`docs/PRD.md`](../../../docs/PRD.md) · [`docs/PHASES.md`](../../../docs/PHASES.md) §Phase 0 · [`docs/design.md`](../../../docs/design.md) · 문서 규칙 [`docs/README.md`](../../../docs/README.md)

## Global Constraints

- 엔진: Godot 4 (최신 stable, 4.5 이상) — PRD §1
- 언어: GDScript 정적 타이핑 필수 → `debug/gdscript/warnings/untyped_declaration=2`(에러) — PRD §5.1
- `sim/`은 `Node`, `SceneTree`, `RenderingServer`, `PhysicsServer3D`, `Input`을 참조하지 않는다. `Vector3` 등 내장 수학 타입은 허용 — PRD §5.2-1
- sim은 60Hz 고정 타임스텝, 렌더는 보간. `max_ticks_per_frame`으로 죽음의 나선 방지 — PRD §5.4
- 모든 수치는 `GameConfig`에. 하드코딩 금지 — PRD §5.2-4
- sim 내 난수는 `World`가 가진 시드 RNG만 — PRD §5.2-7
- 렌더러: 모바일·데스크톱 `mobile`, 웹 `gl_compatibility`. 웹은 스레드 없는 export — PRD §2
- 가로 화면 고정, 기준 해상도 1920×1080, Stretch `canvas_items` / Aspect `expand` — PRD §2, design.md DS-TOK-02
- 색·크기는 `tokens.gd`에서만 (`tokens.gd`, `DebugPanel` 제외), `#000` 금지 — design.md DS-GOV-01
- 3D 월드는 외곽선 없는 소프트 툰 셰이딩, 그림자는 색이 있어야 한다 — design.md DS-VIS-01
- 팔레트 A안(한낮 햇살) 확정값 사용 — design.md DS-TOK-01
- 모든 에셋은 `ASSETS.md`에 출처·라이선스 기록 — PRD-NFR-07
- 커밋 메시지: `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci), 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- 파일을 내려받는 단계(Godot, GUT, 폰트, 템플릿, SDK)는 **실행 전에 사용자 승인**을 받는다

---

## File Structure

```
/Users/uicheol_hwang/Games/            ← Godot 프로젝트 루트 (project.godot 위치)
  project.godot                         T1 생성, T6·T7·T9에서 설정 추가
  .gitignore                            T1
  ASSETS.md                             T5
  export_presets.cfg                    T12 (에디터에서 생성)
  docs/.gdignore  dev/.gdignore         T1 — Godot이 문서 폴더를 임포트하지 않게
  addons/gut/                           T1 (GUT 설치)
  assets/fonts/                         T5 Jua-Regular.ttf, Pretendard-SemiBold.otf, Pretendard-Medium.otf
  scripts/
    test.sh                             T1  헤드리스 GUT 실행
    check-sim-purity.sh                 T4  sim/ 의존성 grep 검사
    check-colors.sh                     T5  하드코딩 색 검사
    check-docs.sh                       T13 문서 추적 ID 검사
    check-all.sh                        T13 전체 검사 묶음
    build_theme.gd                      T6  ThemeBuilder → forest_theme.tres 저장
  src/
    sim/input_frame.gd                  T2  InputFrame
    sim/world.gd                        T4  World (tick, snapshot/restore, RNG)
    config/game_config.gd               T2  GameConfig Resource
    config/default_config.tres          T2
    main/fixed_ticker.gd                T3  60Hz 누산기
    main/main.gd, main.tscn             T1(빈 씬) → T10 진입점·루프 연결
    ui/theme/tokens.gd                  T5  DS 토큰 (class_name DS)
    ui/theme/color_utils.gd             T5  WCAG 대비 계산
    ui/theme/theme_builder.gd           T6  토큰 → Theme
    ui/theme/forest_theme.tres          T6  (생성물, 손으로 수정 금지)
    debug/config_schema.gd              T7  GameConfig → 슬라이더 명세
    debug/config_panel.gd               T7  디버그 패널 (DS-CMP-12)
    debug/ds_gallery.gd, ds_gallery.tscn T11 DS 갤러리
    render/camera_framing.gd            T8  프레이밍 수학 (순수)
    render/camera_rig.gd                T8  카메라 노드 (GD-CAM-01)
    render/shaders/soft_toon.gdshader   T9  소프트 툰 (DS-VIS-01)
    render/toon_materials.gd            T9  색별 머티리얼 캐시
    render/environment_rig.gd           T9  태양·환경광·블룸
    render/arena_view.gd                T9  원형 경기장 바닥
    render/props/sphere_cluster.gd      T9  구 클러스터 덤불·나무 (DS-VIS-02)
    render/props/flower_patch.gd        T9  꽃 점
    render/decor_view.gd                T9  장식 배치 (경기장 바깥)
  tests/unit/
    test_smoke.gd                       T1
    test_input_frame.gd                 T2
    test_game_config.gd                 T2
    test_fixed_ticker.gd                T3
    test_world.gd                       T4
    test_color_utils.gd                 T5
    test_tokens.gd                      T5
    test_theme_builder.gd               T6
    test_config_schema.gd               T7
    test_camera_framing.gd              T8
```

**경계 원칙**: 테스트 가능한 계산(`FixedTicker`, `CameraFraming`, `ConfigSchema`, `ColorUtils`, `ThemeBuilder`, `World`)은 노드가 아닌 `RefCounted`/정적 함수로 분리하고, 노드(`CameraRig`, `ConfigPanel`, `ArenaView` 등)는 그 결과를 화면에 옮기기만 한다.

---

### Task 1: 환경 설치 + 프로젝트 골격 + 테스트 러너

**Files:**
- Create: `project.godot`, `.gitignore`, `docs/.gdignore`, `dev/.gdignore`, `scripts/test.sh`, `src/main/main.tscn`, `tests/unit/test_smoke.gd`
- Create (설치): `addons/gut/`

**Interfaces:**
- Consumes: 없음
- Produces: `scripts/test.sh [GUT 추가 인자]` — 헤드리스로 `tests/unit/` 전체 실행, 실패 시 exit ≠ 0. 환경변수 `GODOT`로 바이너리 경로 지정 가능 (기본 `godot`)

- [ ] **Step 1: Godot 설치 (다운로드 — 실행 전 사용자 승인)**

```bash
brew install --cask godot
godot --version
```
Expected: `4.5.x.stable...` 이상. 4.5 미만이면 중단하고 사용자에게 보고.
`godot` 명령이 없으면: `export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`

- [ ] **Step 2: git 저장소 초기화 + .gitignore + .gdignore**

```bash
cd /Users/uicheol_hwang/Games
git init
touch docs/.gdignore dev/.gdignore
```

`.gitignore`:
```gitignore
# Godot
.godot/
/android/
# Build output
build/
# OS
.DS_Store
```

- [ ] **Step 3: project.godot 작성**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Forest Brawl"
config/features=PackedStringArray("4.5", "Mobile")

[debug]

gdscript/warnings/untyped_declaration=2

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=4

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[rendering]

renderer/rendering_method="mobile"
renderer/rendering_method.web="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
```

`window/handheld/orientation=4` = sensor landscape (가로 고정, 좌우 회전 허용).

- [ ] **Step 4: GUT 설치 (다운로드 — 실행 전 사용자 승인)**

https://github.com/bitwes/Gut/releases 에서 Godot 4.5와 호환되는 최신 9.x 릴리스 zip을 받아 `addons/gut/`만 프로젝트에 복사한다.

```bash
ls addons/gut/gut_cmdln.gd addons/gut/plugin.cfg
```
Expected: 두 파일 모두 존재.

- [ ] **Step 5: 테스트 러너 작성**

`scripts/test.sh`:
```bash
#!/usr/bin/env bash
# Runs GUT unit tests headlessly. Extra args are passed to GUT (e.g. -gselect=test_world).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -ginclude_subdirs -gexit "$@"
```

```bash
chmod +x scripts/test.sh
```

- [ ] **Step 6: 실패하는 스모크 테스트 작성**

`tests/unit/test_smoke.gd`:
```gdscript
extends GutTest


func test_static_typing_is_enforced() -> void:
	var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration")
	assert_eq(level, 2, "untyped_declaration must be an error")


func test_renderer_is_mobile_with_web_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.web"), "gl_compatibility")


func test_project_has_main_scene() -> void:
	assert_ne(ProjectSettings.get_setting("application/run/main_scene", ""), "", "main scene must be set")
```

- [ ] **Step 7: 실행해서 실패 확인**

Run: `scripts/test.sh`
Expected: `test_project_has_main_scene` FAIL (main scene 미설정), 나머지 2개 PASS, exit code ≠ 0.

- [ ] **Step 8: 최소 main 씬 추가로 통과시키기**

`src/main/main.tscn`:
```ini
[gd_scene format=3]

[node name="Main" type="Node"]
```

`project.godot`의 `[application]`에 추가:
```ini
run/main_scene="res://src/main/main.tscn"
```

- [ ] **Step 9: 통과 확인**

Run: `scripts/test.sh`
Expected: 3/3 PASS, exit 0.

- [ ] **Step 10: 커밋**

```bash
git add -A
git commit -m "chore: bootstrap Godot project with GUT test runner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: InputFrame + GameConfig

**Files:**
- Create: `src/sim/input_frame.gd`, `src/config/game_config.gd`, `src/config/default_config.tres`
- Test: `tests/unit/test_input_frame.gd`, `tests/unit/test_game_config.gd`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class_name InputFrame extends RefCounted` — 필드 `move_x: float`, `move_z: float`, `jump/light/heavy/guard/grab: bool`; `static func neutral() -> InputFrame`; `func copy() -> InputFrame`
  - `class_name GameConfig extends Resource` — 아래 코드의 모든 `@export_range` 필드. 값을 바꾼 쪽이 `emit_changed()`를 호출해 구독자에게 알린다
  - `res://src/config/default_config.tres` — `GameConfig` 인스턴스

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_input_frame.gd`:
```gdscript
extends GutTest


func test_neutral_frame_has_no_intent() -> void:
	var f := InputFrame.neutral()
	assert_eq(f.move_x, 0.0)
	assert_eq(f.move_z, 0.0)
	assert_false(f.jump or f.light or f.heavy or f.guard or f.grab)


func test_copy_is_independent() -> void:
	var a := InputFrame.neutral()
	a.move_x = 0.5
	a.jump = true
	var b := a.copy()
	b.move_x = -1.0
	b.jump = false
	assert_eq(a.move_x, 0.5)
	assert_true(a.jump)
	assert_eq(b.move_x, -1.0)
```

`tests/unit/test_game_config.gd`:
```gdscript
extends GutTest

const DEFAULT_PATH := "res://src/config/default_config.tres"


func test_defaults_match_prd_section_4_5() -> void:
	var c := GameConfig.new()
	assert_eq(c.move_speed, 6.0)
	assert_eq(c.jump_velocity, 9.0)
	assert_eq(c.gravity, -25.0)
	assert_eq(c.arena_radius, 10.0)
	assert_eq(c.kill_y, -8.0)
	assert_eq(c.hitstun_factor, 0.04)
	assert_eq(c.hitstop_light, 0.06)
	assert_eq(c.hitstop_heavy, 0.1)
	assert_eq(c.guard_damage_mul, 0.2)
	assert_eq(c.guard_knockback_mul, 0.0)
	assert_eq(c.touch_hold_threshold, 0.15)


func test_camera_defaults_match_gd_cam_01() -> void:
	var c := GameConfig.new()
	assert_eq(c.cam_pitch, 60.0)


func test_default_resource_loads_as_game_config() -> void:
	var res := load(DEFAULT_PATH)
	assert_true(res is GameConfig, "default_config.tres must be a GameConfig")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh`
Expected: FAIL — `Identifier "InputFrame" not declared`, `Identifier "GameConfig" not declared` 등 파싱 에러.

- [ ] **Step 3: InputFrame 구현**

`src/sim/input_frame.gd`:
```gdscript
class_name InputFrame
extends RefCounted
## One tick of player intent. Keyboard, touch, bot and network all produce this (PRD §3.1).

var move_x: float = 0.0
var move_z: float = 0.0
var jump: bool = false
var light: bool = false
var heavy: bool = false
var guard: bool = false
var grab: bool = false


static func neutral() -> InputFrame:
	return InputFrame.new()


func copy() -> InputFrame:
	var f := InputFrame.new()
	f.move_x = move_x
	f.move_z = move_z
	f.jump = jump
	f.light = light
	f.heavy = heavy
	f.guard = guard
	f.grab = grab
	return f
```

- [ ] **Step 4: GameConfig 구현**

`src/config/game_config.gd`:
```gdscript
class_name GameConfig
extends Resource
## Every tunable number lives here. The debug panel builds a slider for each @export_range.
## Initial values: docs/PRD.md §4.5. Camera rules: docs/design.md GD-CAM-01.

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 25.0, 0.1) var jump_velocity: float = 9.0
@export_range(-80.0, -5.0, 0.5) var gravity: float = -25.0

@export_group("Arena")
@export_range(4.0, 20.0, 0.1) var arena_radius: float = 10.0
@export_range(-30.0, -2.0, 0.5) var kill_y: float = -8.0

@export_group("Knockback")
@export_range(0.0, 3.0, 0.01) var global_knockback_mul: float = 1.0
@export_range(0.0, 0.2, 0.001) var hitstun_factor: float = 0.04
@export_range(0.0, 0.3, 0.005) var hitstop_light: float = 0.06
@export_range(0.0, 0.3, 0.005) var hitstop_heavy: float = 0.1
@export_range(0.0, 1.0, 0.01) var guard_damage_mul: float = 0.2
@export_range(0.0, 1.0, 0.01) var guard_knockback_mul: float = 0.0

@export_group("Loop")
@export_range(1, 10, 1) var max_ticks_per_frame: int = 5

@export_group("Camera")
@export_range(30.0, 85.0, 0.5) var cam_pitch: float = 60.0
@export_range(0.0, 10.0, 0.1) var cam_margin: float = 3.0
@export_range(5.0, 40.0, 0.5) var cam_zoom_min: float = 14.0
@export_range(10.0, 80.0, 0.5) var cam_zoom_max: float = 40.0
@export_range(0.0, 20.0, 0.1) var cam_smooth: float = 6.0
@export_range(10.0, 70.0, 0.5) var cam_fov: float = 40.0

@export_group("Touch")
@export_range(0.05, 0.5, 0.01) var touch_hold_threshold: float = 0.15
```

`src/config/default_config.tres`:
```ini
[gd_resource type="Resource" script_class="GameConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/config/game_config.gd" id="1"]

[resource]
script = ExtResource("1")
```

- [ ] **Step 5: 통과 확인**

Run: `scripts/test.sh`
Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add src/sim/input_frame.gd src/config tests/unit/test_input_frame.gd tests/unit/test_game_config.gd
git commit -m "feat: add InputFrame and GameConfig with PRD defaults

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: FixedTicker (60Hz 누산기)

**Files:**
- Create: `src/main/fixed_ticker.gd`
- Test: `tests/unit/test_fixed_ticker.gd`

**Interfaces:**
- Consumes: 없음
- Produces: `class_name FixedTicker extends RefCounted`
  - `const TICK_RATE := 60`, `const TICK_DT := 1.0 / 60.0`
  - `var max_ticks_per_frame: int`
  - `func _init(p_max_ticks_per_frame: int = 5) -> void`
  - `func advance(delta: float) -> int` — 이번 프레임에 돌릴 틱 수
  - `func alpha() -> float` — 렌더 보간 계수, 항상 `[0, 1)`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_fixed_ticker.gd`:
```gdscript
extends GutTest


func test_sixty_frames_at_60fps_yield_sixty_ticks() -> void:
	var t := FixedTicker.new(5)
	var total := 0
	for i: int in 60:
		total += t.advance(1.0 / 60.0)
	assert_eq(total, 60)


func test_30fps_frame_runs_two_ticks() -> void:
	var t := FixedTicker.new(5)
	assert_eq(t.advance(1.0 / 30.0), 2)


func test_120fps_frames_alternate_zero_and_one_tick() -> void:
	var t := FixedTicker.new(5)
	assert_eq(t.advance(1.0 / 120.0), 0)
	assert_eq(t.advance(1.0 / 120.0), 1)


func test_variable_deltas_sum_to_one_second() -> void:
	var t := FixedTicker.new(10)
	var total := 0
	for d: float in [0.010, 0.020, 0.005, 0.030, 0.035, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100]:
		total += t.advance(d)
	assert_eq(total, 60)


func test_long_stall_is_capped_and_backlog_dropped() -> void:
	var t := FixedTicker.new(5)
	assert_eq(t.advance(1.0), 5, "cap ticks per frame")
	assert_lt(t.alpha(), 1.0, "backlog beyond cap is dropped")
	assert_eq(t.advance(0.0), 0, "no catch-up spiral on next frame")


func test_alpha_is_fraction_of_next_tick() -> void:
	var t := FixedTicker.new(5)
	t.advance(FixedTicker.TICK_DT * 0.25)
	assert_almost_eq(t.alpha(), 0.25, 0.0001)
```

(`test_variable_deltas_sum_to_one_second`의 delta 합은 1.0초이고, 어느 프레임도 cap 10틱(=0.1667초)을 넘지 않는다.)

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_fixed_ticker`
Expected: FAIL — `Identifier "FixedTicker" not declared`.

- [ ] **Step 3: 구현**

`src/main/fixed_ticker.gd`:
```gdscript
class_name FixedTicker
extends RefCounted
## Fixed 60 Hz accumulator (PRD §5.4). Caps ticks per frame to avoid the spiral of death.

const TICK_RATE := 60
const TICK_DT := 1.0 / TICK_RATE
## Absorbs float drift so 60 frames of 1/60 s give exactly 60 ticks.
const EPSILON := 1e-9

var max_ticks_per_frame: int
var _accumulator: float = 0.0


func _init(p_max_ticks_per_frame: int = 5) -> void:
	max_ticks_per_frame = p_max_ticks_per_frame


func advance(delta: float) -> int:
	_accumulator += maxf(delta, 0.0)
	var ticks := 0
	while _accumulator + EPSILON >= TICK_DT and ticks < max_ticks_per_frame:
		_accumulator -= TICK_DT
		ticks += 1
	if _accumulator + EPSILON >= TICK_DT:
		_accumulator = fmod(_accumulator, TICK_DT)
	_accumulator = maxf(_accumulator, 0.0)
	return ticks


func alpha() -> float:
	return clampf(_accumulator / TICK_DT, 0.0, 0.9999)
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_fixed_ticker`
Expected: 6/6 PASS.

- [ ] **Step 5: 커밋**

```bash
git add src/main/fixed_ticker.gd tests/unit/test_fixed_ticker.gd
git commit -m "feat: add fixed 60Hz ticker with frame cap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: World 골격 (tick · snapshot/restore · 시드 RNG) + sim 순수성 검사

**Files:**
- Create: `src/sim/world.gd`, `scripts/check-sim-purity.sh`
- Test: `tests/unit/test_world.gd`

**Interfaces:**
- Consumes: `InputFrame`, `GameConfig` (Task 2)
- Produces: `class_name World extends RefCounted`
  - `var config: GameConfig`, `var tick_count: int`
  - `func _init(p_config: GameConfig, p_seed: int = 0) -> void`
  - `func tick(inputs: Array[InputFrame]) -> void`
  - `func rand_int(from: int, to: int) -> int` — sim의 유일한 난수원
  - `func state_view() -> Dictionary` — 렌더용 읽기 전용 상태 (Phase 0: `{"tick": int}`)
  - `func snapshot() -> PackedByteArray`, `func restore(data: PackedByteArray) -> bool`
  - `func state_hash() -> int`
- `scripts/check-sim-purity.sh` — 위반 시 exit 1

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_world.gd`:
```gdscript
extends GutTest


func _inputs() -> Array[InputFrame]:
	var a: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	return a


func test_tick_advances_counter() -> void:
	var w := World.new(GameConfig.new(), 1)
	for i: int in 10:
		w.tick(_inputs())
	assert_eq(w.tick_count, 10)
	assert_eq(w.state_view()["tick"], 10)


func test_same_seed_gives_same_random_sequence() -> void:
	var a := World.new(GameConfig.new(), 42)
	var b := World.new(GameConfig.new(), 42)
	for i: int in 5:
		assert_eq(a.rand_int(0, 1000), b.rand_int(0, 1000))


func test_snapshot_restore_round_trip() -> void:
	var w := World.new(GameConfig.new(), 7)
	for i: int in 30:
		w.tick(_inputs())
	w.rand_int(0, 100)
	var snap := w.snapshot()
	var hash_before := w.state_hash()
	var draws_before: Array[int] = [w.rand_int(0, 1000), w.rand_int(0, 1000)]
	for i: int in 5:
		w.tick(_inputs())

	assert_true(w.restore(snap))
	assert_eq(w.tick_count, 30)
	assert_eq(w.state_hash(), hash_before)
	var draws_after: Array[int] = [w.rand_int(0, 1000), w.rand_int(0, 1000)]
	assert_eq(draws_after, draws_before, "RNG state restored")


func test_restore_rejects_garbage() -> void:
	var w := World.new(GameConfig.new(), 1)
	assert_false(w.restore(PackedByteArray([1, 2, 3])))
	assert_eq(w.tick_count, 0, "state untouched on failed restore")
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_world`
Expected: FAIL — `Identifier "World" not declared`.

- [ ] **Step 3: 구현**

`src/sim/world.gd`:
```gdscript
class_name World
extends RefCounted
## Pure game state (PRD §5.2). Never reference Node, SceneTree, Input, RenderingServer or PhysicsServer3D here.

const SNAPSHOT_VERSION := 1

var config: GameConfig
var tick_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_config: GameConfig, p_seed: int = 0) -> void:
	config = p_config
	_rng.seed = p_seed


func tick(_inputs: Array[InputFrame]) -> void:
	tick_count += 1


func rand_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func state_view() -> Dictionary:
	return {"tick": tick_count}


func snapshot() -> PackedByteArray:
	return var_to_bytes({
		"v": SNAPSHOT_VERSION,
		"tick": tick_count,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
	})


func restore(data: PackedByteArray) -> bool:
	var decoded: Variant = bytes_to_var(data) if data.size() > 4 else null
	if not (decoded is Dictionary) or (decoded as Dictionary).get("v") != SNAPSHOT_VERSION:
		push_error("World.restore: incompatible snapshot")
		return false
	var s: Dictionary = decoded
	tick_count = s["tick"]
	_rng.seed = s["rng_seed"]
	_rng.state = s["rng_state"]
	return true


func state_hash() -> int:
	return hash(snapshot())
```

(`seed`를 설정하면 `state`가 초기화되므로 반드시 seed → state 순서로 복원한다.)

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_world`
Expected: 4/4 PASS. (`test_restore_rejects_garbage`는 의도된 `push_error` 로그를 남긴다.)

- [ ] **Step 5: sim 순수성 검사 스크립트**

`scripts/check-sim-purity.sh`:
```bash
#!/usr/bin/env bash
# Fails if src/sim references engine nodes, rendering, physics or input (PRD §5.2-1).
set -euo pipefail
cd "$(dirname "$0")/.."
pattern='extends Node|Node2D|Node3D|SceneTree|get_tree|RenderingServer|PhysicsServer|DisplayServer|InputEvent|(^|[^A-Za-z])Input\.'
if grep -rnE "$pattern" src/sim; then
  echo "FAIL: sim purity violation"
  exit 1
fi
echo "OK: sim purity"
```

```bash
chmod +x scripts/check-sim-purity.sh && scripts/check-sim-purity.sh
```
Expected: `OK: sim purity`

- [ ] **Step 6: 커밋**

```bash
git add src/sim/world.gd scripts/check-sim-purity.sh tests/unit/test_world.gd
git commit -m "feat: add World skeleton with snapshot/restore and seeded RNG

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 디자인 토큰 v0 + 폰트 + 하드코딩 색 검사

**Files:**
- Create: `src/ui/theme/tokens.gd`, `src/ui/theme/color_utils.gd`, `scripts/check-colors.sh`, `ASSETS.md`
- Create (설치): `assets/fonts/Jua-Regular.ttf`, `assets/fonts/Pretendard-SemiBold.otf`, `assets/fonts/Pretendard-Medium.otf`
- Test: `tests/unit/test_color_utils.gd`, `tests/unit/test_tokens.gd`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class_name DS extends RefCounted` — 아래 코드의 모든 상수 (색, `PALETTE: Dictionary`, `DAMAGE_RAMP: Array`, 폰트 경로, `SIZE_*`, `S1..S8`, `RADIUS_*`, `STROKE_FOCUS`, `SHADOW_*`, `MOTION_*`, `TEXT_OUTLINE`)
  - `class_name ColorUtils extends RefCounted` — `static func relative_luminance(c: Color) -> float`, `static func contrast_ratio(a: Color, b: Color) -> float`
  - `scripts/check-colors.sh` — `src/**/*.gd`에서 `tokens.gd`, `debug/config_panel.gd` 외에 `Color(`, `Color.XXX`, `"#rrggbb"`가 나오면 exit 1

- [ ] **Step 1: 폰트 설치 (다운로드 — 실행 전 사용자 승인)**

- Jua (OFL): https://github.com/google/fonts/raw/main/ofl/jua/Jua-Regular.ttf → `assets/fonts/Jua-Regular.ttf`
- Pretendard (OFL): https://github.com/orioncactus/pretendard/releases 최신 zip → `Pretendard-SemiBold.otf`, `Pretendard-Medium.otf`만 `assets/fonts/`로

```bash
ls assets/fonts
```
Expected: 3개 파일.

- [ ] **Step 2: ASSETS.md 작성**

`ASSETS.md`:
```markdown
# 에셋 출처와 라이선스

| 파일 | 출처 | 라이선스 | 추가 Phase |
|---|---|---|---|
| assets/fonts/Jua-Regular.ttf | Google Fonts — Jua (github.com/google/fonts/tree/main/ofl/jua) | SIL OFL 1.1 | 0 |
| assets/fonts/Pretendard-SemiBold.otf | Pretendard (github.com/orioncactus/pretendard) | SIL OFL 1.1 | 0 |
| assets/fonts/Pretendard-Medium.otf | Pretendard (github.com/orioncactus/pretendard) | SIL OFL 1.1 | 0 |
| addons/gut/ | GUT (github.com/bitwes/Gut) — 개발 도구, 빌드 미포함 | MIT | 0 |
```

- [ ] **Step 3: 실패하는 테스트 작성**

`tests/unit/test_color_utils.gd`:
```gdscript
extends GutTest


func test_black_on_white_is_21() -> void:
	assert_almost_eq(ColorUtils.contrast_ratio(Color(0, 0, 0), Color(1, 1, 1)), 21.0, 0.01)


func test_same_color_is_1() -> void:
	assert_almost_eq(ColorUtils.contrast_ratio(Color(0.3, 0.6, 0.2), Color(0.3, 0.6, 0.2)), 1.0, 0.0001)


func test_order_does_not_matter() -> void:
	var a := Color(0.2, 0.3, 0.4)
	var b := Color(0.9, 0.9, 0.8)
	assert_almost_eq(ColorUtils.contrast_ratio(a, b), ColorUtils.contrast_ratio(b, a), 0.0001)
```

`tests/unit/test_tokens.gd`:
```gdscript
extends GutTest


func test_ui_text_meets_wcag_aa_on_surfaces() -> void:
	for bg: Color in [DS.UI_SURFACE, DS.UI_SURFACE_DIM]:
		assert_gt(ColorUtils.contrast_ratio(DS.UI_TEXT, bg), 4.5)
		assert_gt(ColorUtils.contrast_ratio(DS.UI_TEXT_SOFT, bg), 4.5)


func test_palette_has_no_pure_black() -> void:
	for key: String in DS.PALETTE:
		var c: Color = DS.PALETTE[key]
		assert_false(c.r == 0.0 and c.g == 0.0 and c.b == 0.0 and c.a == 1.0, "%s is pure black" % key)


func test_palette_a_anchor_values() -> void:
	assert_eq(DS.GRASS.to_html(false), "a5d65a")
	assert_eq(DS.CANOPY.to_html(false), "2e8c86")
	assert_eq(DS.WATER.to_html(false), "3a9fe3")
	assert_eq(DS.P1.to_html(false), "3e7bf0")


func test_damage_ramp_has_four_stops() -> void:
	assert_eq(DS.DAMAGE_RAMP.size(), 4)


func test_font_files_exist() -> void:
	for path: String in [DS.FONT_DISPLAY_PATH, DS.FONT_BODY_PATH, DS.FONT_CAPTION_PATH]:
		assert_true(ResourceLoader.exists(path), path)
```

- [ ] **Step 4: 실행해서 실패 확인**

Run: `scripts/test.sh`
Expected: FAIL — `Identifier "ColorUtils" not declared`, `Identifier "DS" not declared`.

- [ ] **Step 5: ColorUtils 구현**

`src/ui/theme/color_utils.gd`:
```gdscript
class_name ColorUtils
extends RefCounted
## WCAG 2.x relative luminance and contrast ratio (design.md DS-A11Y).


static func relative_luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


static func contrast_ratio(a: Color, b: Color) -> float:
	var la := relative_luminance(a)
	var lb := relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
```

- [ ] **Step 6: DS 토큰 구현**

`src/ui/theme/tokens.gd`:
```gdscript
class_name DS
extends RefCounted
## Design tokens — the only place colors and UI sizes are defined (docs/design.md §3).
## Palette: option A "한낮 햇살", confirmed 2026-09-28.

# --- World (DS-TOK-01) ---
const GRASS_SUN := Color("#D6EE7C")
const GRASS := Color("#A5D65A")
const GRASS_MID := Color("#7CC04B")
const GRASS_SHADE := Color("#4F9A48")
const CANOPY := Color("#2E8C86")
const CANOPY_DEEP := Color("#17525A")
const WATER := Color("#3A9FE3")
const WATER_DEEP := Color("#2A72C9")
const STONE_CREAM := Color("#F3EEE7")
const STONE_SHADE := Color("#BDB1AC")
const BARK := Color("#6C5A66")
const DIRT := Color("#8A6B55")
const SKY := Color("#C4E8F6")

# --- Accents ---
const PETAL_PINK := Color("#F27DB6")
const PETAL_BLUE := Color("#3E6FE3")
const PETAL_YELLOW := Color("#F5D53D")
const BERRY := Color("#7B5AD8")
const FIRE := Color("#FF9A2E")
const GLOW := Color("#FFF3C4")
const DANGER := Color("#F0584A")

# --- UI ---
const UI_SURFACE := Color("#FFFDF6")
const UI_SURFACE_DIM := Color("#EAF2DC")
const UI_TEXT := CANOPY_DEEP
const UI_TEXT_SOFT := Color("#3F7470")
const UI_SHADOW := Color("#17525A40")
const UI_ACCENT := FIRE
const TRANSPARENT := Color("#FFFFFF00")

# --- Players (always paired with a shape, DS-VIS-03) ---
const P1 := Color("#3E7BF0")
const P2 := Color("#F25C5C")
const P3 := Color("#FFC93C")
const P4 := Color("#B46CF0")

## DamageCounter color stops at 0 / 50 / 100 / 150+ percent.
const DAMAGE_RAMP := [UI_SURFACE, PETAL_YELLOW, FIRE, DANGER]

const PALETTE := {
	"grass_sun": GRASS_SUN, "grass": GRASS, "grass_mid": GRASS_MID, "grass_shade": GRASS_SHADE,
	"canopy": CANOPY, "canopy_deep": CANOPY_DEEP, "water": WATER, "water_deep": WATER_DEEP,
	"stone_cream": STONE_CREAM, "stone_shade": STONE_SHADE, "bark": BARK, "dirt": DIRT, "sky": SKY,
	"petal_pink": PETAL_PINK, "petal_blue": PETAL_BLUE, "petal_yellow": PETAL_YELLOW,
	"berry": BERRY, "fire": FIRE, "glow": GLOW, "danger": DANGER,
	"ui_surface": UI_SURFACE, "ui_surface_dim": UI_SURFACE_DIM, "ui_text": UI_TEXT, "ui_text_soft": UI_TEXT_SOFT,
	"p1": P1, "p2": P2, "p3": P3, "p4": P4,
}

# --- Typography (DS-TOK-02), sizes at 1920x1080 ---
const FONT_DISPLAY_PATH := "res://assets/fonts/Jua-Regular.ttf"
const FONT_BODY_PATH := "res://assets/fonts/Pretendard-SemiBold.otf"
const FONT_CAPTION_PATH := "res://assets/fonts/Pretendard-Medium.otf"
const SIZE_DISPLAY_XL := 96
const SIZE_DISPLAY_L := 64
const SIZE_TITLE := 40
const SIZE_BODY := 28
const SIZE_CAPTION := 22
const TEXT_OUTLINE := 3

# --- Spacing (DS-TOK-03) ---
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32
const S7 := 48
const S8 := 64

# --- Radius, stroke, shadow (DS-TOK-04) ---
const RADIUS_S := 12
const RADIUS_M := 20
const RADIUS_L := 32
const RADIUS_PILL := 999
const STROKE_FOCUS := 4
const SHADOW_SOFT_OFFSET := Vector2(0, 8)
const SHADOW_SOFT_SIZE := 16
const SHADOW_PRESSED_OFFSET := Vector2(0, 2)
const SHADOW_PRESSED_SIZE := 4

# --- Motion (DS-TOK-05), seconds ---
const MOTION_FAST := 0.08
const MOTION_BASE := 0.18
const MOTION_SQUISH := 0.28
const MOTION_SLOW := 0.40
```

- [ ] **Step 7: 통과 확인**

Run: `scripts/test.sh`
Expected: 전부 PASS. `test_ui_text_meets_wcag_aa_on_surfaces`가 실패하면 design.md 값과 대조하고, 토큰을 고칠 때 design.md도 함께 고친다 (README R6).

- [ ] **Step 8: 하드코딩 색 검사 스크립트**

`scripts/check-colors.sh`:
```bash
#!/usr/bin/env bash
# Fails if any GDScript outside tokens.gd / debug panel defines colors directly (design.md DS-GOV-01).
set -euo pipefail
cd "$(dirname "$0")/.."
pattern='Color\(|Color\.[A-Z_]+|"#[0-9A-Fa-f]{6}'
hits=$(grep -rnE --include='*.gd' "$pattern" src \
  | grep -vE '^src/ui/theme/tokens\.gd:|^src/debug/config_panel\.gd:' || true)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: hardcoded colors — use DS tokens"
  exit 1
fi
echo "OK: no hardcoded colors"
```

```bash
chmod +x scripts/check-colors.sh && scripts/check-colors.sh
```
Expected: `OK: no hardcoded colors`

- [ ] **Step 9: 커밋**

```bash
git add src/ui/theme assets/fonts ASSETS.md scripts/check-colors.sh tests/unit/test_color_utils.gd tests/unit/test_tokens.gd
git commit -m "feat: add design tokens v0 (palette A), fonts and color lint

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: ThemeBuilder → forest_theme.tres

**Files:**
- Create: `src/ui/theme/theme_builder.gd`, `scripts/build_theme.gd`, `src/ui/theme/forest_theme.tres` (생성물)
- Modify: `project.godot` (`[gui]` 섹션 추가)
- Test: `tests/unit/test_theme_builder.gd`

**Interfaces:**
- Consumes: `DS` (Task 5)
- Produces:
  - `class_name ThemeBuilder extends RefCounted` — `static func build() -> Theme`
  - `res://src/ui/theme/forest_theme.tres` — 프로젝트 기본 테마 (`gui/theme/custom`)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_theme_builder.gd`:
```gdscript
extends GutTest

const THEME_PATH := "res://src/ui/theme/forest_theme.tres"


func test_panel_uses_surface_and_large_radius() -> void:
	var sb := ThemeBuilder.build().get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_not_null(sb)
	assert_eq(sb.bg_color, DS.UI_SURFACE)
	assert_eq(sb.corner_radius_top_left, DS.RADIUS_L)
	assert_eq(sb.shadow_color, DS.UI_SHADOW)


func test_button_states() -> void:
	var t := ThemeBuilder.build()
	var normal := t.get_stylebox("normal", "Button") as StyleBoxFlat
	var pressed := t.get_stylebox("pressed", "Button") as StyleBoxFlat
	var focus := t.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_eq(normal.shadow_offset, DS.SHADOW_SOFT_OFFSET)
	assert_eq(pressed.shadow_offset, DS.SHADOW_PRESSED_OFFSET)
	assert_eq(focus.border_color, DS.PETAL_YELLOW)
	assert_eq(focus.border_width_top, DS.STROKE_FOCUS)
	assert_false(focus.draw_center)


func test_text_colors_and_font() -> void:
	var t := ThemeBuilder.build()
	assert_eq(t.get_color("font_color", "Label"), DS.UI_TEXT)
	assert_eq(t.get_color("font_color", "Button"), DS.UI_TEXT)
	assert_not_null(t.default_font)
	assert_eq(t.default_font_size, DS.SIZE_BODY)


func test_committed_theme_is_in_sync_with_builder() -> void:
	var saved := load(THEME_PATH) as Theme
	assert_not_null(saved, "run scripts/build_theme.gd")
	var a := saved.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	var b := ThemeBuilder.build().get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_eq(a.bg_color, b.bg_color, "forest_theme.tres is stale — regenerate it")
	assert_eq(a.corner_radius_top_left, b.corner_radius_top_left)


func test_project_uses_forest_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_theme_builder`
Expected: FAIL — `Identifier "ThemeBuilder" not declared`.

- [ ] **Step 3: ThemeBuilder 구현**

`src/ui/theme/theme_builder.gd`:
```gdscript
class_name ThemeBuilder
extends RefCounted
## Builds the project Theme from DS tokens (design.md DS-THM-01). Never hand-edit forest_theme.tres.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(DS.FONT_BODY_PATH) as Font
	theme.default_font_size = DS.SIZE_BODY

	var panel := _surface(DS.RADIUS_L, DS.SHADOW_SOFT_OFFSET, DS.SHADOW_SOFT_SIZE)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	var normal := _surface(DS.RADIUS_PILL, DS.SHADOW_SOFT_OFFSET, DS.SHADOW_SOFT_SIZE)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("pressed", "Button", _surface(DS.RADIUS_PILL, DS.SHADOW_PRESSED_OFFSET, DS.SHADOW_PRESSED_SIZE))
	theme.set_stylebox("disabled", "Button", _flat(DS.UI_SURFACE_DIM, DS.RADIUS_PILL))
	theme.set_stylebox("focus", "Button", _focus_ring())

	for type_name: String in ["Label", "Button"]:
		theme.set_color("font_color", type_name, DS.UI_TEXT)
	theme.set_color("font_hover_color", "Button", DS.UI_TEXT)
	theme.set_color("font_pressed_color", "Button", DS.UI_TEXT)
	theme.set_color("font_disabled_color", "Button", DS.UI_TEXT_SOFT)
	return theme


static func _surface(radius: int, shadow_offset: Vector2, shadow_size: int) -> StyleBoxFlat:
	var sb := _flat(DS.UI_SURFACE, radius)
	sb.shadow_color = DS.UI_SHADOW
	sb.shadow_offset = shadow_offset
	sb.shadow_size = shadow_size
	return sb


static func _flat(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(DS.S4)
	return sb


static func _focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = DS.PETAL_YELLOW
	sb.set_border_width_all(DS.STROKE_FOCUS)
	sb.set_corner_radius_all(DS.RADIUS_PILL)
	return sb
```

- [ ] **Step 4: 테마 생성 스크립트 작성 후 실행**

`scripts/build_theme.gd`:
```gdscript
extends SceneTree
## Regenerates res://src/ui/theme/forest_theme.tres from DS tokens.
## Run: godot --headless --path . -s res://scripts/build_theme.gd

const OUT_PATH := "res://src/ui/theme/forest_theme.tres"


func _init() -> void:
	var err := ResourceSaver.save(ThemeBuilder.build(), OUT_PATH)
	if err != OK:
		push_error("build_theme: save failed (%s)" % error_string(err))
		quit(1)
		return
	print("build_theme: saved %s" % OUT_PATH)
	quit(0)
```

```bash
godot --headless --path . --import >/dev/null
godot --headless --path . -s res://scripts/build_theme.gd
```
Expected: `build_theme: saved res://src/ui/theme/forest_theme.tres`

- [ ] **Step 5: 프로젝트 기본 테마 설정**

`project.godot`에 추가:
```ini
[gui]

theme/custom="res://src/ui/theme/forest_theme.tres"
```

- [ ] **Step 6: 통과 확인**

Run: `scripts/test.sh`
Expected: 전부 PASS.

- [ ] **Step 7: 커밋**

```bash
git add src/ui/theme/theme_builder.gd src/ui/theme/forest_theme.tres scripts/build_theme.gd project.godot tests/unit/test_theme_builder.gd
git commit -m "feat: generate forest theme from design tokens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 디버그 패널 (ConfigSchema + ConfigPanel)

**Files:**
- Create: `src/debug/config_schema.gd`, `src/debug/config_panel.gd`
- Modify: `project.godot` (`[input]` `debug_toggle` 액션)
- Test: `tests/unit/test_config_schema.gd`

**Interfaces:**
- Consumes: `GameConfig` (Task 2)
- Produces:
  - `class_name ConfigSchema extends RefCounted` — `static func sliders_for(res: Resource) -> Array[Dictionary]`, 각 원소 `{"name": String, "group": String, "min": float, "max": float, "step": float, "is_int": bool}`
  - `class_name ConfigPanel extends CanvasLayer` — `func setup(config: GameConfig) -> void`, `func set_info(text: String) -> void`, `func toggle() -> void`. 슬라이더를 움직이면 `config.set()` 후 `config.emit_changed()`
  - InputMap 액션 `debug_toggle` (F1)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_config_schema.gd`:
```gdscript
extends GutTest


func _find(specs: Array[Dictionary], name: String) -> Dictionary:
	for s: Dictionary in specs:
		if s["name"] == name:
			return s
	return {}


func test_arena_radius_slider_spec() -> void:
	var s := _find(ConfigSchema.sliders_for(GameConfig.new()), "arena_radius")
	assert_false(s.is_empty(), "arena_radius must be exposed")
	assert_eq(s["group"], "Arena")
	assert_eq(s["min"], 4.0)
	assert_eq(s["max"], 20.0)
	assert_eq(s["step"], 0.1)
	assert_false(s["is_int"])


func test_int_property_is_flagged() -> void:
	var s := _find(ConfigSchema.sliders_for(GameConfig.new()), "max_ticks_per_frame")
	assert_true(s["is_int"])
	assert_eq(s["group"], "Loop")


func test_every_config_number_is_exposed() -> void:
	var specs := ConfigSchema.sliders_for(GameConfig.new())
	for name: String in ["move_speed", "gravity", "kill_y", "hitstun_factor", "cam_pitch", "cam_fov", "touch_hold_threshold"]:
		assert_false(_find(specs, name).is_empty(), "%s missing" % name)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_config_schema`
Expected: FAIL — `Identifier "ConfigSchema" not declared`.

- [ ] **Step 3: ConfigSchema 구현**

`src/debug/config_schema.gd`:
```gdscript
class_name ConfigSchema
extends RefCounted
## Converts @export_range properties of a Resource into slider specs for the debug panel.

const DEFAULT_STEP := 0.01


static func sliders_for(res: Resource) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group := ""
	for p: Dictionary in res.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			group = p["name"]
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or p["hint"] != PROPERTY_HINT_RANGE:
			continue
		var parts := String(p["hint_string"]).split(",")
		out.append({
			"name": String(p["name"]),
			"group": group,
			"min": float(parts[0]),
			"max": float(parts[1]),
			"step": float(parts[2]) if parts.size() > 2 else DEFAULT_STEP,
			"is_int": p["type"] == TYPE_INT,
		})
	return out
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_config_schema`
Expected: 3/3 PASS.

- [ ] **Step 5: ConfigPanel 구현**

`src/debug/config_panel.gd`:
```gdscript
class_name ConfigPanel
extends CanvasLayer
## Dev-only live tuning panel (design.md DS-CMP-12). Toggle: F1 or a third finger on touch.
## DS exception: default Godot styling and fixed dev sizes are allowed here.

const PANEL_WIDTH := 460.0
const NAME_WIDTH := 190.0
const VALUE_WIDTH := 70.0

var _config: GameConfig
var _root: PanelContainer
var _info: Label


func setup(config: GameConfig) -> void:
	_config = config
	layer = 100
	_root = PanelContainer.new()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_root.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(_root)

	var scroll := ScrollContainer.new()
	_root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	_info = Label.new()
	box.add_child(_info)

	var current_group := ""
	for spec: Dictionary in ConfigSchema.sliders_for(config):
		if spec["group"] != current_group:
			current_group = spec["group"]
			var header := Label.new()
			header.text = "— %s —" % current_group
			box.add_child(header)
		box.add_child(_make_row(spec))


func set_info(text: String) -> void:
	if _info:
		_info.text = text


func toggle() -> void:
	_root.visible = not _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.index == 2:
			toggle()


func _make_row(spec: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = spec["name"]
	name_label.custom_minimum_size.x = NAME_WIDTH
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = spec["min"]
	slider.max_value = spec["max"]
	slider.step = spec["step"]
	slider.value = float(_config.get(spec["name"]))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.text = _format(slider.value, spec["is_int"])
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		_config.set(spec["name"], int(v) if spec["is_int"] else v)
		_config.emit_changed()
		value_label.text = _format(v, spec["is_int"]))
	return row


func _format(v: float, is_int: bool) -> String:
	return str(int(v)) if is_int else "%.3f" % v
```

- [ ] **Step 6: F1 액션 등록**

Godot 에디터 › Project Settings › Input Map에서 `debug_toggle` 추가 → F1(Physical). 또는 `project.godot`에 직접:
```ini
[input]

debug_toggle={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194332,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 7: 전체 테스트 + 색 검사**

Run: `scripts/test.sh && scripts/check-colors.sh`
Expected: 전부 PASS, `OK: no hardcoded colors`.

- [ ] **Step 8: 커밋**

```bash
git add src/debug project.godot tests/unit/test_config_schema.gd
git commit -m "feat: add auto-generated GameConfig debug panel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 카메라 (CameraFraming + CameraRig)

**Files:**
- Create: `src/render/camera_framing.gd`, `src/render/camera_rig.gd`
- Test: `tests/unit/test_camera_framing.gd`

**Interfaces:**
- Consumes: `GameConfig.cam_pitch/cam_margin/cam_zoom_min/cam_zoom_max/cam_smooth/cam_fov` (Task 2)
- Produces:
  - `class_name CameraFraming extends RefCounted` — `static func compute(targets: PackedVector3Array, margin: float, zoom_min: float, zoom_max: float, fov_deg: float) -> Dictionary` → `{"center": Vector3, "distance": float}`
  - `class_name CameraRig extends Node3D` — `func setup(config: GameConfig) -> void`, `func follow(targets: PackedVector3Array, delta: float) -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_camera_framing.gd`:
```gdscript
extends GutTest


func test_no_targets_looks_at_origin_from_min_zoom() -> void:
	var f := CameraFraming.compute(PackedVector3Array(), 3.0, 14.0, 40.0, 40.0)
	assert_eq(f["center"], Vector3.ZERO)
	assert_eq(f["distance"], 14.0)


func test_center_is_midpoint_of_bounds() -> void:
	var pts := PackedVector3Array([Vector3(-2, 0, 4), Vector3(6, 1, 0)])
	var f := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0)
	assert_eq(f["center"], Vector3(2, 0.5, 2))


func test_distance_fits_extent_with_margin() -> void:
	var pts := PackedVector3Array([Vector3(-2, 0, 0), Vector3(2, 0, 0)])
	# half extent 2 + margin 1 = 3; fov 90 -> tan(45) = 1 -> distance 3
	var f := CameraFraming.compute(pts, 1.0, 0.0, 1000.0, 90.0)
	assert_almost_eq(f["distance"], 3.0, 0.0001)


func test_distance_is_clamped() -> void:
	var far := PackedVector3Array([Vector3(-100, 0, 0), Vector3(100, 0, 0)])
	assert_eq(CameraFraming.compute(far, 0.0, 10.0, 40.0, 40.0)["distance"], 40.0)
	var near := PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0, 0)])
	assert_eq(CameraFraming.compute(near, 0.0, 10.0, 40.0, 40.0)["distance"], 10.0)
```

- [ ] **Step 2: 실행해서 실패 확인**

Run: `scripts/test.sh -gselect=test_camera_framing`
Expected: FAIL — `Identifier "CameraFraming" not declared`.

- [ ] **Step 3: CameraFraming 구현**

`src/render/camera_framing.gd`:
```gdscript
class_name CameraFraming
extends RefCounted
## Pure framing math for GD-CAM-01: where to look and how far back to stand.


static func compute(targets: PackedVector3Array, margin: float, zoom_min: float, zoom_max: float, fov_deg: float) -> Dictionary:
	if targets.is_empty():
		return {"center": Vector3.ZERO, "distance": zoom_min}
	var lo := targets[0]
	var hi := targets[0]
	for p: Vector3 in targets:
		lo = lo.min(p)
		hi = hi.max(p)
	var half_extent := maxf(hi.x - lo.x, hi.z - lo.z) * 0.5 + margin
	var distance := half_extent / tan(deg_to_rad(fov_deg) * 0.5)
	return {"center": (lo + hi) * 0.5, "distance": clampf(distance, zoom_min, zoom_max)}
```

- [ ] **Step 4: 통과 확인**

Run: `scripts/test.sh -gselect=test_camera_framing`
Expected: 4/4 PASS.

- [ ] **Step 5: CameraRig 구현**

`src/render/camera_rig.gd`:
```gdscript
class_name CameraRig
extends Node3D
## High top-down camera (reference A, GD-CAM-01). Smoothly frames the given targets.

var _config: GameConfig
var _camera: Camera3D
var _center: Vector3 = Vector3.ZERO
var _distance: float = 0.0


func setup(config: GameConfig) -> void:
	_config = config
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	_distance = config.cam_zoom_max


func follow(targets: PackedVector3Array, delta: float) -> void:
	var frame := CameraFraming.compute(targets, _config.cam_margin, _config.cam_zoom_min, _config.cam_zoom_max, _config.cam_fov)
	var target_center: Vector3 = frame["center"]
	var target_distance: float = frame["distance"]
	var k := 1.0 - exp(-_config.cam_smooth * delta)
	_center = _center.lerp(target_center, k)
	_distance = lerpf(_distance, target_distance, k)

	var pitch := deg_to_rad(_config.cam_pitch)
	_camera.fov = _config.cam_fov
	_camera.position = _center + Vector3(0.0, sin(pitch), cos(pitch)) * _distance
	_camera.look_at(_center, Vector3.UP)
```

- [ ] **Step 6: 전체 테스트 + 색 검사**

Run: `scripts/test.sh && scripts/check-colors.sh`
Expected: PASS / OK.

- [ ] **Step 7: 커밋**

```bash
git add src/render/camera_framing.gd src/render/camera_rig.gd tests/unit/test_camera_framing.gd
git commit -m "feat: add framing camera rig (GD-CAM-01)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: 소프트 툰 셰이더 + 경기장·환경·식생 렌더

**Files:**
- Create: `src/render/shaders/soft_toon.gdshader`, `src/render/toon_materials.gd`, `src/render/environment_rig.gd`, `src/render/arena_view.gd`, `src/render/props/sphere_cluster.gd`, `src/render/props/flower_patch.gd`, `src/render/decor_view.gd`
- Modify: `project.godot` (`[shader_globals]`)

**Interfaces:**
- Consumes: `DS` (Task 5), `GameConfig.arena_radius` + `changed` 시그널 (Task 2)
- Produces:
  - `class_name ToonMaterials extends RefCounted` — `static func toon(color: Color, rim: float = 0.0) -> ShaderMaterial` (색·림별 캐시)
  - `class_name EnvironmentRig extends Node3D` — `func setup() -> void`
  - `class_name ArenaView extends Node3D` — `func setup(config: GameConfig) -> void` (반경 변경 시 재생성)
  - `class_name SphereCluster extends Node3D` — `func setup(color: Color, size: float, seed: int, trunk_height: float = 0.0) -> void`
  - `class_name FlowerPatch extends Node3D` — `func setup(color: Color, seed: int, count: int = 5) -> void`
  - `class_name DecorView extends Node3D` — `func setup(config: GameConfig, seed: int) -> void` (반경 변경 시 재배치)
  - 글로벌 셰이더 파라미터 `ds_shadow_tint: color`, `ds_band_softness: float`

이 태스크는 시각 결과물이라 자동 테스트 대신 **스크린샷**으로 검증한다(Task 10에서 main에 연결한 뒤). 로직은 Task 2·8의 테스트된 코드가 맡는다.

- [ ] **Step 1: 글로벌 셰이더 파라미터 등록**

`project.godot`에 추가 (또는 Project Settings › Shader Globals에서 동일하게):
```ini
[shader_globals]

ds_shadow_tint={
"type": "color",
"value": Color(0.42, 0.6, 0.58, 1)
}
ds_band_softness={
"type": "float",
"value": 0.12
}
```

값의 원천은 design.md DS-VIS-01. 바꿀 때는 design.md와 함께 바꾼다.

- [ ] **Step 2: 셰이더 작성**

`src/render/shaders/soft_toon.gdshader`:
```glsl
shader_type spatial;
// Soft toon (design.md DS-VIS-01): two soft bands, tinted shadows, optional rim, no outline.

global uniform vec4 ds_shadow_tint;
global uniform float ds_band_softness;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-ds_band_softness, ds_band_softness, ndl) * ATTENUATION;
	vec3 band = mix(ds_shadow_tint.rgb, vec3(1.0), lit);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength * lit;
	DIFFUSE_LIGHT += (band + vec3(rim)) * LIGHT_COLOR / PI;
}
```

- [ ] **Step 3: 머티리얼 캐시**

`src/render/toon_materials.gd`:
```gdscript
class_name ToonMaterials
extends RefCounted
## One shared ShaderMaterial per (color, rim) pair.

const SHADER := preload("res://src/render/shaders/soft_toon.gdshader")

static var _cache: Dictionary = {}


static func toon(color: Color, rim: float = 0.0) -> ShaderMaterial:
	var key := "%s|%.3f" % [color.to_html(), rim]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("rim_strength", rim)
	_cache[key] = mat
	return mat
```

- [ ] **Step 4: 환경 (태양·환경광·블룸)**

`src/render/environment_rig.gd`:
```gdscript
class_name EnvironmentRig
extends Node3D
## Warm midday sun, sky ambience and soft bloom (design.md §0 reference A, DS-VIS-01).

const SUN_ROTATION_DEG := Vector3(-55.0, 35.0, 0.0)
const SUN_ENERGY := 1.2
const AMBIENT_ENERGY := 0.55
const GLOW_INTENSITY := 0.35


func setup() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DS.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = DS.SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.light_color = DS.GLOW
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	add_child(sun)
```

- [ ] **Step 5: 경기장 바닥**

`src/render/arena_view.gd`:
```gdscript
class_name ArenaView
extends Node3D
## Round grass arena with a thick dirt edge (DS-VIS-04). Rebuilds when arena_radius changes.

const TOP_THICKNESS := 0.2
const RIM_HEIGHT := 0.8
const RIM_TAPER := 0.92
const SEGMENTS := 64

var _config: GameConfig
var _top: MeshInstance3D
var _rim: MeshInstance3D
var _built_radius: float = -1.0


func setup(config: GameConfig) -> void:
	_config = config
	_top = MeshInstance3D.new()
	_rim = MeshInstance3D.new()
	add_child(_top)
	add_child(_rim)
	_config.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var r := _config.arena_radius
	if is_equal_approx(r, _built_radius):
		return
	_built_radius = r

	var top := CylinderMesh.new()
	top.top_radius = r
	top.bottom_radius = r
	top.height = TOP_THICKNESS
	top.radial_segments = SEGMENTS
	_top.mesh = top
	_top.material_override = ToonMaterials.toon(DS.GRASS)
	_top.position.y = -TOP_THICKNESS * 0.5

	var rim := CylinderMesh.new()
	rim.top_radius = r
	rim.bottom_radius = r * RIM_TAPER
	rim.height = RIM_HEIGHT
	rim.radial_segments = SEGMENTS
	_rim.mesh = rim
	_rim.material_override = ToonMaterials.toon(DS.DIRT)
	_rim.position.y = -TOP_THICKNESS - RIM_HEIGHT * 0.5
```

- [ ] **Step 6: 구 클러스터·꽃 점**

`src/render/props/sphere_cluster.gd`:
```gdscript
class_name SphereCluster
extends Node3D
## Bush or tree canopy made of overlapping spheres (design.md DS-VIS-02 form language).

## x, y, z, radius of each sphere at size 1.
const LAYOUT := [
	Vector4(0.0, 0.9, 0.0, 0.9), Vector4(-0.8, 0.6, 0.2, 0.65), Vector4(0.8, 0.6, 0.1, 0.7),
	Vector4(-0.3, 1.4, -0.3, 0.6), Vector4(0.4, 1.3, 0.4, 0.55), Vector4(0.1, 0.5, 0.8, 0.6),
]
const TRUNK_RADIUS := 0.18
const SPHERE_SEGMENTS := 24
const SPHERE_RINGS := 12


func setup(color: Color, size: float, seed: int, trunk_height: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = SPHERE_SEGMENTS
	sphere.rings = SPHERE_RINGS
	var material := ToonMaterials.toon(color)

	if trunk_height > 0.0:
		var trunk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = TRUNK_RADIUS * size
		cyl.bottom_radius = TRUNK_RADIUS * size
		cyl.height = trunk_height * size
		trunk.mesh = cyl
		trunk.material_override = ToonMaterials.toon(DS.BARK)
		trunk.position.y = trunk_height * size * 0.5
		add_child(trunk)

	for s: Vector4 in LAYOUT:
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = material
		mi.position = Vector3(s.x, s.y + trunk_height, s.z) * size
		mi.scale = Vector3.ONE * s.w * size * rng.randf_range(0.9, 1.1)
		add_child(mi)
```

`src/render/props/flower_patch.gd`:
```gdscript
class_name FlowerPatch
extends Node3D
## A small cluster of colored dots on the grass (reference A "꽃 점").

const DOT_RADIUS := 0.18
const DOT_HEIGHT := 0.03
const DOT_SEGMENTS := 8
const SPREAD := 0.8


func setup(color: Color, seed: int, count: int = 5) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dot := CylinderMesh.new()
	dot.top_radius = DOT_RADIUS
	dot.bottom_radius = DOT_RADIUS
	dot.height = DOT_HEIGHT
	dot.radial_segments = DOT_SEGMENTS
	var material := ToonMaterials.toon(color)
	for i: int in count:
		var mi := MeshInstance3D.new()
		mi.mesh = dot
		mi.material_override = material
		mi.position = Vector3(rng.randf_range(-SPREAD, SPREAD), DOT_HEIGHT * 0.5, rng.randf_range(-SPREAD, SPREAD))
		add_child(mi)
```

- [ ] **Step 7: 장식 배치 (경기장 바깥 원칙)**

`src/render/decor_view.gd`:
```gdscript
class_name DecorView
extends Node3D
## Outer meadow, lake, rock, bushes, trees and flowers around the arena.
## Decor stays outside the ring (design.md DS-VIS-04); re-lays out when arena_radius changes.

const GROUND_Y := -1.0
const GROUND_SIZE := 400.0
const PROP_COUNT := 14
const FLOWER_COUNT := 24
const LAKE_RADIUS := 12.0
const LAKE_OFFSET := 14.0
const LAKE_SEGMENTS := 48
const ROCK_SCALE := Vector3(1.6, 1.1, 1.3)
const FLOWER_COLORS := [DS.PETAL_PINK, DS.PETAL_BLUE, DS.PETAL_YELLOW]

var _config: GameConfig
## Each item: {"node": Node3D, "angle": float, "y": float, and either "offset" (outside ring) or "frac" (inside)}
var _items: Array[Dictionary] = []


func setup(config: GameConfig, seed: int) -> void:
	_config = config
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_add_ground()
	_add_lake()
	_add_rock()
	for i: int in PROP_COUNT:
		var is_tree := i % 3 == 0
		var prop := SphereCluster.new()
		add_child(prop)
		var size := rng.randf_range(0.9, 1.4) * (1.6 if is_tree else 1.0)
		prop.setup(DS.CANOPY if is_tree else DS.GRASS_MID, size, rng.randi(), 1.2 if is_tree else 0.0)
		_items.append({"node": prop, "angle": TAU * i / PROP_COUNT + rng.randf_range(-0.15, 0.15), "offset": rng.randf_range(2.5, 6.0), "y": GROUND_Y})
	for i: int in FLOWER_COUNT:
		var patch := FlowerPatch.new()
		add_child(patch)
		patch.setup(FLOWER_COLORS[i % FLOWER_COLORS.size()], rng.randi())
		var inside := i % 2 == 0
		var item := {"node": patch, "angle": rng.randf_range(0.0, TAU), "y": 0.0 if inside else GROUND_Y}
		if inside:
			item["frac"] = rng.randf_range(0.15, 0.85)
		else:
			item["offset"] = rng.randf_range(1.0, 8.0)
		_items.append(item)
	_config.changed.connect(_layout)
	_layout()


func _layout() -> void:
	var r := _config.arena_radius
	for item: Dictionary in _items:
		var node: Node3D = item["node"]
		var angle: float = item["angle"]
		var dist: float = r * float(item["frac"]) if item.has("frac") else r + float(item["offset"])
		node.position = Vector3(cos(angle) * dist, float(item["y"]), sin(angle) * dist)


func _add_ground() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mi.mesh = plane
	mi.material_override = ToonMaterials.toon(DS.GRASS_MID)
	mi.position.y = GROUND_Y
	add_child(mi)


func _add_lake() -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_RADIUS
	disc.bottom_radius = LAKE_RADIUS
	disc.height = 0.1
	disc.radial_segments = LAKE_SEGMENTS
	mi.mesh = disc
	mi.material_override = ToonMaterials.toon(DS.WATER)
	add_child(mi)
	_items.append({"node": mi, "angle": 0.0, "offset": LAKE_OFFSET, "y": GROUND_Y + 0.05})


func _add_rock() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.scale = ROCK_SCALE
	mi.material_override = ToonMaterials.toon(DS.STONE_CREAM)
	add_child(mi)
	_items.append({"node": mi, "angle": PI * 0.75, "offset": 4.0, "y": GROUND_Y + 0.6})
```

- [ ] **Step 8: 색 검사 + 파싱 확인**

Run: `scripts/check-colors.sh && scripts/test.sh`
Expected: `OK: no hardcoded colors`, 테스트 전부 PASS (새 스크립트의 파싱 에러는 임포트 단계에서 드러난다).

- [ ] **Step 9: 커밋**

```bash
git add src/render project.godot
git commit -m "feat: add soft toon shader and forest arena rendering

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: main 연결 — 루프·카메라·패널

**Files:**
- Create: `src/main/main.gd`
- Modify: `src/main/main.tscn` (스크립트 연결)
- Evidence: `dev/active/phase-0/evidence/desktop-arena.png`, `desktop-panel-radius20.png`

**Interfaces:**
- Consumes: `GameConfig`, `World`, `InputFrame`, `FixedTicker`, `EnvironmentRig`, `ArenaView`, `DecorView`, `CameraRig`, `ConfigPanel`
- Produces: 실행 가능한 메인 씬. Phase 1 뷰가 쓸 `_prev_state`, `_curr_state`, `_alpha` 보간 계약 (PRD §5.4)

- [ ] **Step 1: main.gd 작성**

`src/main/main.gd`:
```gdscript
extends Node
## Entry point: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4).

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := 1
const PLAYER_COUNT := 2

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _camera: CameraRig
var _panel: ConfigPanel
## Render interpolation contract: views lerp prev -> curr by _alpha (consumed from Phase 1).
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _tps_ticks: int = 0
var _tps_time: float = 0.0
var _tps: float = 0.0


func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("main: GameConfig missing at %s" % CONFIG_PATH)
		get_tree().quit(1)
		return
	_world = World.new(_config, SEED)
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
	_panel = ConfigPanel.new()
	add_child(_panel)
	_panel.setup(_config)

	_curr_state = _world.state_view()
	_prev_state = _curr_state


func _process(delta: float) -> void:
	var ticks := _ticker.advance(delta)
	for i: int in ticks:
		_prev_state = _curr_state
		_world.tick(_neutral_inputs())
		_curr_state = _world.state_view()
	_alpha = _ticker.alpha()
	_camera.follow(_arena_bounds(), delta)
	_update_info(delta, ticks)


func _neutral_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	for i: int in PLAYER_COUNT:
		inputs.append(InputFrame.neutral())
	return inputs


func _arena_bounds() -> PackedVector3Array:
	var r := _config.arena_radius
	return PackedVector3Array([Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, -r), Vector3(0, 0, r)])


func _update_info(delta: float, ticks: int) -> void:
	_tps_ticks += ticks
	_tps_time += delta
	if _tps_time >= 1.0:
		_tps = _tps_ticks / _tps_time
		_tps_ticks = 0
		_tps_time = 0.0
	_panel.set_info("tick %d · %.0f tps · alpha %.2f · %d fps" % [_world.tick_count, _tps, _alpha, Engine.get_frames_per_second()])
```

- [ ] **Step 2: main.tscn에 스크립트 연결**

`src/main/main.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/main/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 검사 통과 확인**

Run: `scripts/test.sh && scripts/check-colors.sh && scripts/check-sim-purity.sh`
Expected: 전부 PASS/OK.

- [ ] **Step 4: 데스크톱 실행 수동 검증**

```bash
godot --path .
```
확인 항목:
1. 연두 원형 경기장 + 흙 단면 + 바깥 풀밭·호수·크림 바위·구 클러스터 덤불/나무·꽃 점이 보인다
2. 그림자가 검정이 아니라 청록빛이고, 3D에 외곽선이 없다
3. F1 → 패널 표시, 정보 줄이 `~60 tps`를 보여준다
4. `arena_radius` 슬라이더를 4 → 20으로 움직이면 바닥이 즉시 커지고, 장식이 바깥으로 밀리고, 카메라가 부드럽게 줌아웃한다
5. `cam_pitch` 슬라이더로 부감 각도가 바뀐다

- [ ] **Step 5: 증거 스크린샷**

실행 중 창을 캡처해 `dev/active/phase-0/evidence/desktop-arena.png`, `desktop-panel-radius20.png`로 저장한다 (macOS: `screencapture -w <path>`).

- [ ] **Step 6: 커밋**

```bash
git add src/main dev/active/phase-0/evidence
git commit -m "feat: wire main loop, arena, camera and debug panel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: DS 갤러리 씬

**Files:**
- Create: `src/debug/ds_gallery.gd`, `src/debug/ds_gallery.tscn`
- Evidence: `dev/active/phase-0/evidence/ds-gallery.png`

**Interfaces:**
- Consumes: `DS`, 프로젝트 테마(`forest_theme.tres`), `SphereCluster`, `EnvironmentRig`, `ToonMaterials`
- Produces: `res://src/debug/ds_gallery.tscn` — 토큰 스와치, 타이포 스케일, 소프트 툰 샘플, 등록된 컴포넌트 목록 (design.md DS-GOV-02). Phase 1부터 컴포넌트를 `COMPONENTS`에 추가한다

- [ ] **Step 1: 갤러리 스크립트와 씬 작성**

`src/debug/ds_gallery.gd`:
```gdscript
extends Control
## Design system gallery (design.md DS-GOV-02). Every token, component, shader sample, VFX and SFX is shown here.
## Run: godot --path . res://src/debug/ds_gallery.tscn

const SWATCH_SIZE := Vector2(120, 64)
const SWATCH_COLUMNS := 7
const PREVIEW_SIZE := Vector2i(560, 360)
## Registered components: [display name, scene path]. Phase 1 adds DamageCounter, StockIcons, ...
const COMPONENTS: Array[Array] = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = DS.UI_SURFACE_DIM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.S7)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S6)
	margin.add_child(col)

	col.add_child(_heading("Palette · DS-TOK-01 (A 한낮 햇살)"))
	col.add_child(_swatches())
	col.add_child(_heading("Typography · DS-TOK-02"))
	col.add_child(_type_scale())
	col.add_child(_heading("Soft toon · DS-VIS-01 / DS-VIS-02"))
	col.add_child(_toon_preview())
	col.add_child(_heading("Components · DS-CMP"))
	col.add_child(_components())


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_TITLE)
	return l


func _swatches() -> Control:
	var grid := GridContainer.new()
	grid.columns = SWATCH_COLUMNS
	grid.add_theme_constant_override("h_separation", DS.S3)
	grid.add_theme_constant_override("v_separation", DS.S3)
	for key: String in DS.PALETTE:
		var color: Color = DS.PALETTE[key]
		var cell := VBoxContainer.new()
		var chip := ColorRect.new()
		chip.color = color
		chip.custom_minimum_size = SWATCH_SIZE
		cell.add_child(chip)
		var label := Label.new()
		label.text = "%s\n#%s" % [key, color.to_html(false)]
		label.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
		cell.add_child(label)
		grid.add_child(cell)
	return grid


func _type_scale() -> Control:
	var box := VBoxContainer.new()
	var display := load(DS.FONT_DISPLAY_PATH) as Font
	var caption := load(DS.FONT_CAPTION_PATH) as Font
	var rows: Array[Array] = [
		["display_xl 118%", display, DS.SIZE_DISPLAY_XL],
		["display_l 승리!", display, DS.SIZE_DISPLAY_L],
		["title 호숫가 캠프장", display, DS.SIZE_TITLE],
		["body 상자가 떨어지면 먼저 주워라", null, DS.SIZE_BODY],
		["caption 핑 42ms", caption, DS.SIZE_CAPTION],
	]
	for row: Array in rows:
		var l := Label.new()
		l.text = row[0]
		if row[1] != null:
			l.add_theme_font_override("font", row[1])
		l.add_theme_font_size_override("font_size", row[2])
		box.add_child(l)
	return box


func _toon_preview() -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	var vp := SubViewport.new()
	vp.size = PREVIEW_SIZE
	vp.own_world_3d = true
	container.add_child(vp)

	var env := EnvironmentRig.new()
	vp.add_child(env)
	env.setup()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = ToonMaterials.toon(DS.GRASS)
	vp.add_child(ground)
	var bush := SphereCluster.new()
	vp.add_child(bush)
	bush.setup(DS.GRASS_MID, 1.2, 1)
	bush.position = Vector3(-2.2, 0, 0)
	var tree := SphereCluster.new()
	vp.add_child(tree)
	tree.setup(DS.CANOPY, 1.3, 2, 1.2)
	tree.position = Vector3(2.2, 0, -0.5)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = ToonMaterials.toon(DS.P1, 0.35)
	ball.position = Vector3(0, 0.5, 1.5)
	vp.add_child(ball)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0, 7, 7)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	return container


func _components() -> Control:
	var box := VBoxContainer.new()
	if COMPONENTS.is_empty():
		var l := Label.new()
		l.text = "등록된 컴포넌트 없음 — Phase 1부터 DamageCounter, StockIcons, TouchStick…"
		l.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
		box.add_child(l)
		return box
	for entry: Array in COMPONENTS:
		var title := Label.new()
		title.text = entry[0]
		box.add_child(title)
		box.add_child((load(entry[1]) as PackedScene).instantiate())
	return box
```

`src/debug/ds_gallery.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/debug/ds_gallery.gd" id="1"]

[node name="DSGallery" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 2: 검사**

Run: `scripts/test.sh && scripts/check-colors.sh`
Expected: PASS / OK.

- [ ] **Step 3: 실행 확인 + 스크린샷**

```bash
godot --path . res://src/debug/ds_gallery.tscn
```
확인 항목: 28개 스와치와 hex, Jua·Pretendard 타이포 스케일, 소프트 툰 미리보기(청록 그림자, 외곽선 없음, P1 공의 림 라이트), 컴포넌트 안내 문구.
`dev/active/phase-0/evidence/ds-gallery.png`로 저장.

- [ ] **Step 4: 커밋**

```bash
git add src/debug/ds_gallery.gd src/debug/ds_gallery.tscn dev/active/phase-0/evidence/ds-gallery.png
git commit -m "feat: add design system gallery scene

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Export 프리셋 + 멀티플랫폼 스모크

**Files:**
- Create: `export_presets.cfg` (에디터에서 생성)
- Evidence: `dev/active/phase-0/evidence/{android-arena.png, web-arena.png, export-log.txt}`

**Interfaces:**
- Consumes: 실행 가능한 메인 씬 (Task 10)
- Produces: 프리셋 이름 `macOS`, `Windows Desktop`, `Android`, `Web`, `Linux Server` — Phase 1 이후 CI와 배포가 이 이름을 쓴다

- [ ] **Step 1: 설치 (다운로드 — 실행 전 사용자 승인)**

1. Godot 에디터 › Editor › Manage Export Templates › 현재 버전 템플릿 다운로드
2. JDK 17: `brew install --cask temurin@17`
3. Android SDK: Android Studio 또는 `brew install --cask android-commandlinetools` 후
   `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"`
4. Editor Settings › Export › Android: `java_sdk_path`, `android_sdk_path` 지정 (디버그 키스토어는 에디터가 자동 생성)

- [ ] **Step 2: 프리셋 생성 (에디터 › Project › Export)**

| 프리셋 이름 | 플랫폼 | 필수 설정 |
|---|---|---|
| `macOS` | macOS | Bundle ID `com.forestbrawl.game` |
| `Windows Desktop` | Windows | 기본값 |
| `Android` | Android | Package `com.forestbrawl.game`, Screen Orientation: Sensor Landscape, Architectures: arm64-v8a |
| `Web` | Web | **Thread Support 끔** (variant/thread_support=false), VRAM: ETC2/ASTC 포함 |
| `Linux Server` | Linux | Resources › Export Mode: **Dedicated Server**, x86_64 |

저장하면 `export_presets.cfg`가 생긴다.

- [ ] **Step 3: CLI export**

```bash
mkdir -p build/{macos,android,web,server}
{
godot --headless --path . --export-debug "macOS" build/macos/ForestBrawl.zip
godot --headless --path . --export-debug "Android" build/android/forest-brawl.apk
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Linux Server" build/server/forest-brawl-server.x86_64
} 2>&1 | tee dev/active/phase-0/evidence/export-log.txt
ls -la build/*/
```
Expected: 네 결과물이 모두 생성되고 로그에 `ERROR` 없음.

- [ ] **Step 4: Android 실기기**

```bash
adb install -r build/android/forest-brawl.apk
adb shell monkey -p com.forestbrawl.game 1
adb exec-out screencap -p > dev/active/phase-0/evidence/android-arena.png
```
확인: 가로 화면, 경기장·장식·청록 그림자가 보인다. 세 번째 손가락 터치로 패널이 열리고 `arena_radius`가 반응한다.

- [ ] **Step 5: 웹 브라우저**

```bash
python3 -m http.server 8060 -d build/web
```
http://localhost:8060 을 브라우저에서 열어 경기장이 뜨는지 확인 → `dev/active/phase-0/evidence/web-arena.png`.
확인: Compatibility 렌더러에서 소프트 툰·색 그림자가 유지된다. 블룸이 약하거나 없으면 `phase-0-context.md` "알려진 차이"에 기록한다 (차단 사유 아님).

- [ ] **Step 6: 커밋**

```bash
git add export_presets.cfg dev/active/phase-0/evidence
git commit -m "chore: add export presets and multiplatform smoke evidence

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: 문서 검사 + Phase 0 완료 점검

**Files:**
- Create: `scripts/check-docs.sh`, `scripts/check-all.sh`
- Modify: `docs/PHASES.md` (Phase 0 체크박스), `docs/design.md` (추적표 상태, 버전), `dev/active/phase-0/phase-0-context.md`

**Interfaces:**
- Consumes: 이전 모든 태스크
- Produces: `scripts/check-all.sh` — Phase 공통 완료 체크 중 자동화 가능한 부분 (테스트, sim 순수성, 색, 문서)

- [ ] **Step 1: 검사 스크립트 (README §5)**

`scripts/check-docs.sh`:
```bash
#!/usr/bin/env bash
# Traceability checks between docs (docs/README.md R3, R4).
set -euo pipefail
cd "$(dirname "$0")/../docs"
fail=0
for id in $(grep -oE '(DS|GD)-[A-Z0-9]+-[0-9]+' PHASES.md | sort -u); do
  grep -q "$id" design.md || { echo "undefined in design.md: $id"; fail=1; }
done
for id in $(grep -oE '^\| PRD-[A-Z]+-[0-9]+' PRD.md | tr -d '| '); do
  area=${id%-*}
  grep -qE "$id|$area-[0-9]+~" PHASES.md || { echo "not assigned to a phase: $id"; fail=1; }
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "OK: docs traceability"
```

`scripts/check-all.sh`:
```bash
#!/usr/bin/env bash
# Automated part of the per-phase completion check (docs/PHASES.md).
set -euo pipefail
cd "$(dirname "$0")"
./test.sh
./check-sim-purity.sh
./check-colors.sh
./check-docs.sh
echo "ALL CHECKS PASSED"
```

```bash
chmod +x scripts/check-docs.sh scripts/check-all.sh && scripts/check-all.sh
```
Expected: `ALL CHECKS PASSED`

- [ ] **Step 2: Phase 0 완료 기준 점검 (PHASES.md)**

| 완료 기준 | 증거 |
|---|---|
| 빈 경기장이 데스크톱·Android 실기기·웹에서 뜬다 | `evidence/desktop-arena.png`, `android-arena.png`, `web-arena.png` |
| `arena_radius` 슬라이더 → 바닥 즉시 변경 | `evidence/desktop-panel-radius20.png` |
| 툰 셰이더가 세 플랫폼에서 깨지지 않는다 | 위 세 스크린샷 비교 |
| DS 갤러리가 확정 팔레트·타이포를 보여준다 | `evidence/ds-gallery.png` |
| `test.sh`·하드코딩 색 검사 통과 | `scripts/check-all.sh` 출력 |

증거가 하나라도 없으면 완료를 선언하지 않는다.

- [ ] **Step 3: 코드 리뷰**

`code-reviewer` 에이전트로 Phase 0 전체 커밋 범위를 리뷰하고, CRITICAL/HIGH 지적을 고친 뒤 `scripts/check-all.sh`를 다시 돌린다.

- [ ] **Step 4: 문서 갱신 (README §4 "Phase 완료")**

1. `docs/PHASES.md` Phase 0의 ⚙️/🎨 태스크와 완료 기준 체크박스를 `[x]`로
2. `docs/design.md` §12 추적표: `DS-TOK-02~05`, `DS-THM-01`, `DS-CMP-12` → ✅ / `DS-VIS-01`, `DS-VIS-02`, `GD-CAM-01`, `DS-GOV-01~02` → 🟨 (Phase 3·4에서 계속) / 상단 버전 `0.3`
3. `phase-0-context.md`에 알려진 차이·결정 사항 기록, `Last Updated` 갱신
4. `git mv dev/active/phase-0 dev/done/phase-0`

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "docs: complete phase 0 and update traceability

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review 결과

- **Spec 커버리지 (PHASES.md Phase 0)**: 환경·git → T1 · 폴더·정적 타입 → T1 · GUT·test.sh → T1 · InputFrame·GameConfig → T2 · 틱 누산기·보간·max_ticks → T3, T10 · World 골격 → T4 · 바닥·조명·카메라 → T8, T9, T10 · 디버그 패널 → T7 · Export 프리셋 → T12 · ASSETS.md → T5 · 레퍼런스 이미지 보관 → context.md 사전 조건 · 팔레트 🖼 → 완료됨 · 토큰 v0·폰트·테마 → T5, T6 · DS 갤러리 → T11 · 소프트 툰 프로토·구 클러스터 → T9 · 하드코딩 색 검사 → T5 · 테스트(누산기·라운드트립) → T3, T4
- **타입 일관성**: `GameConfig.cam_*` 이름이 T2·T7·T8·T10에서 동일, `DS.*` 상수가 T5 정의와 T6·T9·T11 사용에서 동일, `World.state_view()`가 T4·T10에서 동일
- **범위 밖으로 둔 것**: 커버리지 80% 측정 도구(GDScript용 표준 도구 없음 → context.md 열린 이슈), iOS export(Phase 3)
