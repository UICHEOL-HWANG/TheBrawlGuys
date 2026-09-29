# Phase 2 — 전투 확장 + 아이템 + 4버튼 터치 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 약공격 3타 콤보·강공격 차지·가드·잡기/던지기와 아이템 3종(방망이·폭탄·돌멩이)을 결정적인 sim에 넣고, 키보드 6액션과 터치 스틱 + 4버튼으로 전부 쓸 수 있게 하며, 봇이 가드하고 아이템을 두고 경쟁하게 만든다.

**Architecture:** 공격 수치는 `AttackSet`(종류별 `AttackData` 표)으로 모으고, 조작 상태 전이는 `Actions`, 잡기는 `Grab`, 아이템은 `Item`/`ItemField`/`ItemActions`/`ItemMotion`으로 나눠 `src/sim/`의 순수 로직으로 둔다. `World.tick`이 이 모듈들을 고정 순서로 부르고, `state_view()`에 아이템 목록을 더한다. 입력 레이어는 `HoldLatch`(강공격·가드 홀드), `AttackButtonModel`(터치 탭/홀드), `TouchLayout`(레이아웃 3안), `GrabContext`(잡기 버튼 강조)로 InputFrame 7필드를 전부 채운다. 렌더는 아이템·그림자·가드 버블·잡기 표시·ChargeGauge를 값 데이터에서 그린다.

**Tech Stack:** Godot 4.7.2 (GDScript 정적 타입), GUT 9.7.1, Movie Maker(`--write-movie`)로 영상 증거, Google Stitch(🖼 게이트, 사용자 수행)

**Spec:** [`docs/PRD.md`](../../../docs/PRD.md) §3·§4·§6.4 · [`docs/PHASES.md`](../../../docs/PHASES.md) Phase 2 · [`docs/design.md`](../../../docs/design.md) DS-LAY-01, DS-CMP-04·05, DS-VFX-02, DS-VIS-05 · 결정: [`phase-2-context.md`](./phase-2-context.md) E1~E11

## Global Constraints

- Godot 4.7.2, GDScript 정적 타입 필수 (`untyped_declaration` = 에러) — PRD §5.1
- `src/sim/`은 Node·SceneTree·RenderingServer·PhysicsServer3D·Input·전역 난수·Time·OS·Engine·`load()`를 쓰지 않는다 (`scripts/check-sim-purity.sh`) — PRD §5.2
- sim 안의 난수는 `World._rng`(시드 RNG) 하나뿐, 아이템 생성에서만 쓴다 (E8) — PRD-ARCH-05
- sim은 60Hz 고정 틱, 렌더는 `prev → curr`를 `alpha`로 보간 — PRD §5.4
- `state_view()`는 값 데이터만 (살아 있는 sim 객체 참조 금지)
- 모든 튜닝 수치는 `GameConfig`(`@export_range`, 디버그 패널에 자동 노출), 아트 디렉션 상수는 렌더 코드의 이름 붙은 const, 색·UI 크기는 `DS` 토큰만 (`scripts/check-colors.sh`: `.gd/.tscn/.tres`에서 `Color(`·`"#rrggbb"` 금지, `tokens.gd` 예외) — design.md §2.2
- 넉백 공식 `knockback = (base + damage × scaling) × global_knockback_mul`, 대미지는 넉백 계산 전에 더한다 (Phase 1 D7). 강공격은 여기에 차지 배율, 가드는 가드 배율을 곱한다
- 가드 시 대미지 20% / 넉백 0% (`guard_damage_mul` 0.2, `guard_knockback_mul` 0.0) — PRD §4.5
- 강공격 12% / base 6 / scaling 0.12, 최대 차지 1초 배율 1.6, hitstop 0.1초 — PRD §4.5
- `touch_hold_threshold` 0.15초, 버튼 최소 터치 영역 48dp — PRD §3.3
- 캐시된 `ToonMaterials` 머티리얼은 수정 금지 (필요하면 `duplicate()`)
- GUT는 예상된 `push_error`를 `assert_push_error`로 인정해야 통과
- 새 스크립트의 `.uid` 사이드카는 같은 커밋에 넣는다 (Godot가 `--import` 때 생성: `./scripts/test.sh`가 먼저 import를 돈다)
- 커밋: `<type>: <description>` + 마지막 줄 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (Phase 1 Ruling 7: 실제 작성 모델 이름 허용)
- 리플레이 골든(`tests/replay/test_replay.gd` `GOLDEN_HASH`)이 바뀌는 커밋은 메시지 본문에 이유를 적는다 (Phase 1 Ruling 8)
- 모든 태스크 끝에 `./scripts/check-all.sh` 통과
- 증거 스크린샷·영상은 `dev/active/phase-2/evidence/` (영상 `.avi`는 gitignore)

---

## File Structure

```
src/
  config/game_config.gd        T1  (수정) Combo·HeavyAttack·Grab·Items·Bot·Touch 수치
  sim/
    attack_set.gd              T2  AttackSet: Kind enum + 종류별 AttackData 표
    attack_data.gd             T2  (수정) min_hitstun_ticks
    fighter.gd                 T2  (수정) 상태 CHARGE/GUARD/HOLDING/HELD, 필드 추가
    actions.gd                 T3  Actions: 콤보·차지·가드·잡기 시도·방망이 전이
    motion.gd                  T3  (수정) 상태별 분기를 Actions로 위임
    combat.gd                  T5  (수정) AttackSet, apply_hit(dir, power, guard)
    grab.gd                    T6  Grab: 잡기 판정·들기·던지기·정리
    item.gd                    T7  Item: 아이템 엔티티·직렬화
    item_field.gd              T7  ItemField: 목록·생성 스케줄·직렬화·뷰
    item_actions.gd            T8  ItemActions: 줍기·던지기·떨어뜨리기
    item_motion.gd             T7~T9 ItemMotion: 낙하(T7)·투사체 명중(T8)·폭탄 폭발(T9)
    rules.gd                   T6·T8 (수정) 리스폰·KO 때 새 필드 초기화
    world.gd                   T2~T9 (수정) 틱 순서, snapshot v3→v4, items 뷰
  input/
    hold_latch.gd              T11 HoldLatch: 짧은 탭도 1틱 이상 홀드로
    local_input.gd             T11 (수정) 6액션 + 터치 홀드 입력
    attack_button_model.gd     T12 AttackButtonModel: 탭/홀드 해석
    touch_layout.gd            T12 TouchLayout: 레이아웃 3안 + safe area
    touch_input.gd             T12 (수정) 4버튼, cancel/포커스 처리
    grab_context.gd            T14 GrabContext: 잡기 버튼이 지금 무엇을 하는지
    bot_controller.gd          T18 (수정) 봇 2단계
  render/
    item_view.gd               T16 ItemView: 상자·아이템 모양·낙하 그림자
    item_layer.gd              T16 ItemLayer: id별 ItemView 풀 + 보간
    fighter_view.gd            T16·T17 (수정) 든 아이템·사용 횟수 점, 가드 버블
    grab_hint.gd               T17 GrabHint: 잡기 대상 발밑 노란 링
    camera_rig.gd              T15 (수정) unproject()
    feel/feel_director.gd      T19 (수정) guard_hit·explosion 연출, reset()
  ui/
    theme/tokens.gd            T14·T17 (수정) 버블·그림자 반투명 토큰
    theme/theme_builder.gd     T14 (수정) Button font_focus_color
    components/
      touch_button/            T14 TouchButton v2 (DS-CMP-04)
      touch_button/touch_icons.gd T14 아이콘 4종 (그리기 함수)
      charge_gauge/            T15 ChargeGauge (DS-CMP-05)
    hud.gd                     T19 (수정) safe area 여백
  main/main.gd                 T19 (수정) 아이템·게이지·힌트·터치 강조 연결
  debug/
    feel_scenario.gd           T3  (수정) 3타 콤보로 측정
    ringout_demo.gd            T3  (수정) 3타 콤보로 시연
    item_race_demo.gd/.tscn    T20 상자 쟁탈 영상용 봇 대 봇 씬
    ds_gallery.gd              T14·T15 (수정) 컴포넌트 등록
tests/
  unit/test_attack_set.gd, test_actions.gd, test_charge.gd, test_guard.gd, test_grab.gd,
       test_items.gd, test_item_use.gd, test_bomb.gd, test_hold_latch.gd,
       test_attack_button_model.gd, test_touch_layout.gd, test_grab_context.gd,
       test_charge_gauge.gd, test_item_view.gd  (+ 기존 파일 수정)
  replay/test_replay.gd        T10 (수정) 1200틱 + 새 액션, 봇 커버리지 테스트
```

**경계 원칙:** 규칙·계산은 `RefCounted`/정적 함수(테스트 대상), 노드는 결과를 그리기만 한다. 봇·입력은 sim 밖(`src/input/`)이며 `state_view()` 값만 읽는다.

**틱 순서 (World.tick, T9 이후 최종):**
① 입력 정리(`_resolve_inputs`: 파이터 id별, 없으면 neutral, 사본) → ② `ItemActions.pre_step` (줍기·던지기, 쓴 버튼은 사본에서 지움) → ③ 파이터마다 `Motion.step` → ④ `Motion.separate` → ⑤ `Grab.step` (들기·던지기·시간 초과) → ⑥ `Grab.resolve` (잡기 성공) → ⑦ `Combat.resolve` (근접 명중) → ⑧ `ItemMotion.step` (낙하·투사체·폭발) → ⑨ `ItemField.spawn_step` (상자 생성) → ⑩ `Rules.apply` (링아웃) → ⑪ `Grab.cleanup` (짝 잃은 잡기 풀기) → ⑫ `ItemActions.drop_from_disabled` (맞거나 잡힌 파이터의 아이템 떨어뜨리기) → ⑬ 승패 → ⑭ `tick_count += 1`

**태스크 순서와 의존:** T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 (sim 직렬) · T11 → T12 (입력) · T13 🖼 게이트는 T12 뒤 사용자 수행 · T14 → T15 → T16 → T17 (DS·렌더) · T18 봇 (T9·T11 뒤) · T19 main 연결 (전부 뒤) · T20 증거·마감

---

### Task 1: GameConfig Phase 2 수치

**Files:**
- Modify: `src/config/game_config.gd` (그룹 추가)
- Modify: `tests/replay/test_replay.gd` (`GOLDEN_HASH`만 — 새 필드가 config 지문을 바꿈, Phase 1 D1)
- Test: `tests/unit/test_game_config.gd`, `tests/unit/test_config_schema.gd`

**Interfaces:**
- Consumes: Phase 1 `GameConfig`
- Produces (다음 태스크들이 이 이름을 그대로 쓴다):
  - Combo: `combo_buffer_ticks: int = 10`, `light_link_damage: float = 3.0`, `light_link_base_knockback: float = 1.5`, `light_link_launch_angle_y: float = 0.0`, `light_link_hitstun_ticks: int = 18`
  - HeavyAttack: `heavy_damage = 12.0`, `heavy_base_knockback = 6.0`, `heavy_knockback_scaling = 0.12`, `heavy_launch_angle_y = 0.7`, `heavy_startup_ticks: int = 8`, `heavy_active_ticks: int = 4`, `heavy_recovery_ticks: int = 18`, `heavy_hitbox_forward = 1.0`, `heavy_hitbox_up = 0.9`, `heavy_hitbox_half_width = 0.6`, `heavy_hitbox_half_height = 0.55`, `heavy_charge_max_time = 1.0`, `heavy_charge_max_mul = 1.6`
  - Grab: `grab_startup_ticks: int = 4`, `grab_active_ticks: int = 4`, `grab_recovery_ticks: int = 16`, `grab_forward = 0.8`, `grab_half_width = 0.45`, `grab_hold_max_time = 1.5`, `grab_hold_distance = 0.95`, `throw_damage = 8.0`, `throw_base_knockback = 7.0`, `throw_knockback_scaling = 0.1`, `throw_launch_angle_y = 0.5`
  - Items: `item_spawn_min_time = 10.0`, `item_spawn_max_time = 15.0`, `item_max_on_field: int = 2`, `item_spawn_radius_ratio = 0.7`, `item_drop_height = 12.0`, `item_pickup_radius = 1.2`, `item_radius = 0.35`, `item_throw_speed = 14.0`, `item_throw_up = 4.0`, `bat_uses: int = 5`, `bat_damage = 10.0`, `bat_base_knockback = 8.0`, `bat_knockback_scaling = 0.1`, `bat_launch_angle_y = 0.5`, `bat_startup_ticks: int = 6`, `bat_active_ticks: int = 4`, `bat_recovery_ticks: int = 14`, `bat_hitbox_forward = 1.2`, `bat_hitbox_half_width = 0.6`, `bomb_fuse_time = 2.0`, `bomb_radius = 2.5`, `bomb_damage = 15.0`, `bomb_base_knockback = 9.0`, `bomb_knockback_scaling = 0.12`, `bomb_launch_angle_y = 0.8`, `rock_damage = 6.0`, `rock_base_knockback = 5.0`, `rock_knockback_scaling = 0.08`, `rock_launch_angle_y = 0.3`
  - Bot (추가): `bot_guard_range = 2.2`, `bot_guard_ticks: int = 20`, `bot_item_seek_range = 8.0`, `bot_throw_range = 6.0`
  - Touch (추가): `touch_layout: int = 0` (0 호 / 1 다이아몬드 / 2 2×2, E9), `touch_side_diameter = 116.0` (가드·잡기 버튼)
- 근거: `[PRD-CFG-01]` `[PRD-CMB-01~04]` `[PRD-ITEM-01~04]` `[PRD-BOT-02]` `[PRD-CTL-03]`

- [ ] **Step 1: 실패하는 테스트 추가**

`tests/unit/test_game_config.gd` 끝에 추가:
```gdscript


func test_phase2_defaults_match_prd_4_5() -> void:
	var c := GameConfig.new()
	assert_eq(c.heavy_damage, 12.0)
	assert_eq(c.heavy_base_knockback, 6.0)
	assert_eq(c.heavy_knockback_scaling, 0.12)
	assert_eq(c.heavy_charge_max_time, 1.0)
	assert_eq(c.heavy_charge_max_mul, 1.6)
	assert_eq(c.bomb_fuse_time, 2.0)
	assert_eq(c.bat_uses, 5)
	assert_eq(c.item_spawn_min_time, 10.0)
	assert_eq(c.item_spawn_max_time, 15.0)


func test_item_spawn_window_is_ordered() -> void:
	var c := GameConfig.new()
	assert_lt(c.item_spawn_min_time, c.item_spawn_max_time)
	assert_eq(SimTime.to_ticks(c.bomb_fuse_time), 120, "PHASES test: bomb explodes 120 ticks after the throw")
```

`tests/unit/test_config_schema.gd` 끝에 추가:
```gdscript


func test_phase2_groups_are_exposed() -> void:
	var specs := ConfigSchema.sliders_for(GameConfig.new())
	var expected := {
		"combo_buffer_ticks": "Combo", "heavy_charge_max_mul": "HeavyAttack", "grab_hold_max_time": "Grab",
		"bomb_radius": "Items", "bot_guard_range": "Bot", "touch_layout": "Touch",
	}
	for name: String in expected:
		var s := _find(specs, name)
		assert_false(s.is_empty(), "%s missing" % name)
		assert_eq(s.get("group"), expected[name], "%s group" % name)
	assert_true(_find(specs, "touch_layout")["is_int"])
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_game_config`
Expected: FAIL — `Invalid access to property or key 'heavy_damage'` (또는 파서 에러로 스크립트 로드 실패)

- [ ] **Step 3: GameConfig에 그룹 추가**

`src/config/game_config.gd`에서 `@export_group("Bot")` 블록을 아래로 교체하고, 그 **앞**(LightAttack 그룹 바로 뒤)에 Combo·HeavyAttack·Grab·Items 그룹을 넣는다. Touch 그룹 끝에 두 줄을 더한다.

LightAttack 그룹 뒤에 삽입:
```gdscript

@export_group("Combo")
## A light press while the current light hit has at most this many ticks left queues the next hit (E2).
@export_range(0, 30, 1) var combo_buffer_ticks: int = 10
## Hits 1-2 of the light combo are link hits: small flat knockback plus a hitstun floor so the
## next hit connects. Hit 3 is the finisher and uses the LightAttack values above (E1).
@export_range(0.0, 30.0, 0.5) var light_link_damage: float = 3.0
@export_range(0.0, 30.0, 0.1) var light_link_base_knockback: float = 1.5
@export_range(0.0, 2.0, 0.05) var light_link_launch_angle_y: float = 0.0
@export_range(0, 60, 1) var light_link_hitstun_ticks: int = 18

@export_group("HeavyAttack")
@export_range(0.0, 40.0, 0.5) var heavy_damage: float = 12.0
@export_range(0.0, 30.0, 0.1) var heavy_base_knockback: float = 6.0
@export_range(0.0, 0.5, 0.005) var heavy_knockback_scaling: float = 0.12
@export_range(0.0, 2.0, 0.05) var heavy_launch_angle_y: float = 0.7
@export_range(0, 40, 1) var heavy_startup_ticks: int = 8
@export_range(1, 30, 1) var heavy_active_ticks: int = 4
@export_range(0, 60, 1) var heavy_recovery_ticks: int = 18
@export_range(0.0, 3.0, 0.05) var heavy_hitbox_forward: float = 1.0
@export_range(0.0, 3.0, 0.05) var heavy_hitbox_up: float = 0.9
@export_range(0.1, 2.0, 0.05) var heavy_hitbox_half_width: float = 0.6
@export_range(0.1, 2.0, 0.05) var heavy_hitbox_half_height: float = 0.55
## Holding heavy charges up to this long; the multiplier grows linearly to heavy_charge_max_mul (E3).
@export_range(0.1, 3.0, 0.05) var heavy_charge_max_time: float = 1.0
@export_range(1.0, 3.0, 0.05) var heavy_charge_max_mul: float = 1.6

@export_group("Grab")
@export_range(0, 30, 1) var grab_startup_ticks: int = 4
@export_range(1, 30, 1) var grab_active_ticks: int = 4
@export_range(0, 60, 1) var grab_recovery_ticks: int = 16
@export_range(0.0, 3.0, 0.05) var grab_forward: float = 0.8
@export_range(0.1, 2.0, 0.05) var grab_half_width: float = 0.45
## A hold that is not thrown ends by itself after this long (E5).
@export_range(0.2, 5.0, 0.1) var grab_hold_max_time: float = 1.5
## Distance from the holder to the held fighter while holding.
@export_range(0.5, 2.0, 0.05) var grab_hold_distance: float = 0.95
@export_range(0.0, 30.0, 0.5) var throw_damage: float = 8.0
@export_range(0.0, 30.0, 0.1) var throw_base_knockback: float = 7.0
@export_range(0.0, 0.5, 0.005) var throw_knockback_scaling: float = 0.1
@export_range(0.0, 2.0, 0.05) var throw_launch_angle_y: float = 0.5

@export_group("Items")
@export_range(1.0, 60.0, 0.5) var item_spawn_min_time: float = 10.0
@export_range(1.0, 60.0, 0.5) var item_spawn_max_time: float = 15.0
@export_range(0, 6, 1) var item_max_on_field: int = 2
## Boxes land within this fraction of the arena radius.
@export_range(0.1, 1.0, 0.05) var item_spawn_radius_ratio: float = 0.7
## Drop height; 12 m under the default gravity falls in about 1 s (DS-VIS-05 shadow warning).
@export_range(2.0, 30.0, 0.5) var item_drop_height: float = 12.0
@export_range(0.3, 3.0, 0.05) var item_pickup_radius: float = 1.2
@export_range(0.1, 1.0, 0.05) var item_radius: float = 0.35
@export_range(2.0, 40.0, 0.5) var item_throw_speed: float = 14.0
@export_range(0.0, 20.0, 0.5) var item_throw_up: float = 4.0
@export_range(1, 20, 1) var bat_uses: int = 5
@export_range(0.0, 40.0, 0.5) var bat_damage: float = 10.0
@export_range(0.0, 30.0, 0.1) var bat_base_knockback: float = 8.0
@export_range(0.0, 0.5, 0.005) var bat_knockback_scaling: float = 0.1
@export_range(0.0, 2.0, 0.05) var bat_launch_angle_y: float = 0.5
@export_range(0, 40, 1) var bat_startup_ticks: int = 6
@export_range(1, 30, 1) var bat_active_ticks: int = 4
@export_range(0, 60, 1) var bat_recovery_ticks: int = 14
@export_range(0.0, 3.0, 0.05) var bat_hitbox_forward: float = 1.2
@export_range(0.1, 2.0, 0.05) var bat_hitbox_half_width: float = 0.6
## Lit on throw; explodes this long after (the throw tick counts as the first tick, E7).
@export_range(0.5, 6.0, 0.1) var bomb_fuse_time: float = 2.0
@export_range(0.5, 8.0, 0.1) var bomb_radius: float = 2.5
@export_range(0.0, 40.0, 0.5) var bomb_damage: float = 15.0
@export_range(0.0, 30.0, 0.1) var bomb_base_knockback: float = 9.0
@export_range(0.0, 0.5, 0.005) var bomb_knockback_scaling: float = 0.12
@export_range(0.0, 2.0, 0.05) var bomb_launch_angle_y: float = 0.8
## Thrown rocks and thrown bats hit with these numbers.
@export_range(0.0, 40.0, 0.5) var rock_damage: float = 6.0
@export_range(0.0, 30.0, 0.1) var rock_base_knockback: float = 5.0
@export_range(0.0, 0.5, 0.005) var rock_knockback_scaling: float = 0.08
@export_range(0.0, 2.0, 0.05) var rock_launch_angle_y: float = 0.3
```

Bot 그룹 교체:
```gdscript
@export_group("Bot")
@export_range(0.5, 5.0, 0.1) var bot_attack_range: float = 1.4
@export_range(0, 120, 1) var bot_attack_cooldown_ticks: int = 30
@export_range(0.3, 1.0, 0.01) var bot_edge_ratio: float = 0.8
@export_range(0.5, 6.0, 0.1) var bot_guard_range: float = 2.2
@export_range(1, 90, 1) var bot_guard_ticks: int = 20
@export_range(0.0, 20.0, 0.5) var bot_item_seek_range: float = 8.0
@export_range(1.0, 15.0, 0.5) var bot_throw_range: float = 6.0
```

Touch 그룹 끝에 추가:
```gdscript
## 0 = arc around attack, 1 = diamond, 2 = 2x2 grid (design.md DS-LAY-01, E9).
@export_range(0, 2, 1) var touch_layout: int = 0
@export_range(96.0, 300.0, 2.0) var touch_side_diameter: float = 116.0
```

- [ ] **Step 4: 테스트 통과 확인, 골든 갱신**

Run: `./scripts/test.sh`
Expected: 새 테스트 PASS. `test_golden_hash`만 FAIL하며 메시지에 새 값이 찍힌다 (`update GOLDEN_HASH to <N>`). 새 필드가 config 지문에 들어가기 때문이다 (Phase 1 D1, sim 동작 변화 없음).
`tests/replay/test_replay.gd`의 `const GOLDEN_HASH := 2573264149`를 출력된 `<N>`으로 바꾸고 다시 `./scripts/test.sh` → 전부 PASS.

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh` → `ALL CHECKS PASSED`
```bash
git add src/config/game_config.gd tests/unit/test_game_config.gd tests/unit/test_config_schema.gd tests/replay/test_replay.gd
git commit -m "feat: add phase 2 combat, item, bot and touch tunables" -m "GOLDEN_HASH regenerated: new GameConfig fields change the config fingerprint (no sim behavior change)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: AttackSet + Fighter 상태·필드 확장 (snapshot v3)

동작은 바꾸지 않는다. 공격 표와 파이터 데이터만 준비하고, World는 아직 Phase 1 약공격을 쓴다 (T3에서 전환).

**Files:**
- Create: `src/sim/attack_set.gd`
- Modify: `src/sim/attack_data.gd` (필드 1개), `src/sim/fighter.gd`, `src/sim/world.gd` (`SNAPSHOT_VERSION` 3)
- Modify: `tests/replay/test_replay.gd` (`GOLDEN_HASH` — 스냅샷에 파이터 필드가 늘어 해시가 바뀜)
- Test: `tests/unit/test_attack_set.gd` (신규), `tests/unit/test_fighter.gd`

**Interfaces:**
- Consumes: T1 `GameConfig` 필드
- Produces:
  - `AttackSet.Kind { LIGHT_1, LIGHT_2, LIGHT_3, HEAVY, GRAB, THROW, BAT, ROCK, BOMB }`
  - `static func AttackSet.from_config(config: GameConfig) -> AttackSet`
  - `func AttackSet.get_attack(kind: int) -> AttackData`
  - `static func AttackSet.is_light_chainable(kind: int) -> bool` — LIGHT_1, LIGHT_2만 true
  - `AttackData.min_hitstun_ticks: int` (기본 0) — hitstun 하한 (연결타용)
  - `Fighter.State`에 `CHARGE`(6), `GUARD`(7), `HOLDING`(8), `HELD`(9) 추가 (기존 0~5 유지)
  - `Fighter.NONE := -1`
  - Fighter 필드: `attack_kind: int = 0`, `combo_queued: bool = false`, `charge_ticks: int = 0`, `charge_mul: float = 1.0`, `grab_ticks: int = 0`, `partner_id: int = NONE`, `item_kind: int = NONE`, `item_uses: int = 0` — 모두 `DATA_TYPES`에 포함
  - `to_view()`에 `attack_kind`, `charge_ticks`, `partner_id`, `item_kind`, `item_uses` 추가
- 근거: `[PRD-ARCH-03]` `[PRD-CMB-01~04]` `[PRD-ITEM-02~04]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_attack_set.gd` 신규:
```gdscript
extends GutTest


func test_light_3_is_the_phase_1_light_attack() -> void:
	var c := GameConfig.new()
	var finisher := AttackSet.from_config(c).get_attack(AttackSet.Kind.LIGHT_3)
	var phase1 := AttackData.light_from(c)
	assert_eq(finisher.damage, phase1.damage)
	assert_eq(finisher.base_knockback, phase1.base_knockback)
	assert_eq(finisher.knockback_scaling, phase1.knockback_scaling)
	assert_eq(finisher.launch_angle_y, phase1.launch_angle_y)
	assert_eq(finisher.min_hitstun_ticks, 0)


func test_link_hits_are_small_flat_and_hold_hitstun() -> void:
	var c := GameConfig.new()
	var s := AttackSet.from_config(c)
	for kind: int in [AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2]:
		var a := s.get_attack(kind)
		assert_eq(a.damage, c.light_link_damage)
		assert_eq(a.base_knockback, c.light_link_base_knockback)
		assert_eq(a.knockback_scaling, 0.0, "link knockback must not grow with damage")
		assert_eq(a.launch_angle_y, c.light_link_launch_angle_y)
		assert_eq(a.min_hitstun_ticks, c.light_link_hitstun_ticks)
		assert_eq(a.total_ticks(), c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks)


func test_heavy_bat_and_projectiles_from_config() -> void:
	var c := GameConfig.new()
	var s := AttackSet.from_config(c)
	var heavy := s.get_attack(AttackSet.Kind.HEAVY)
	assert_eq(heavy.damage, 12.0)
	assert_eq(heavy.base_knockback, 6.0)
	assert_eq(heavy.knockback_scaling, 0.12)
	assert_eq(heavy.hitstop_ticks, SimTime.to_ticks(c.hitstop_heavy))
	assert_eq(heavy.total_ticks(), c.heavy_startup_ticks + c.heavy_active_ticks + c.heavy_recovery_ticks)
	var bat := s.get_attack(AttackSet.Kind.BAT)
	assert_eq(bat.damage, c.bat_damage)
	assert_eq(bat.hitbox_forward, c.bat_hitbox_forward)
	assert_eq(s.get_attack(AttackSet.Kind.ROCK).damage, c.rock_damage)
	assert_eq(s.get_attack(AttackSet.Kind.BOMB).base_knockback, c.bomb_base_knockback)
	assert_eq(s.get_attack(AttackSet.Kind.THROW).knockback_scaling, c.throw_knockback_scaling)


func test_grab_box_deals_no_damage() -> void:
	var c := GameConfig.new()
	var grab := AttackSet.from_config(c).get_attack(AttackSet.Kind.GRAB)
	assert_eq(grab.damage, 0.0)
	assert_eq(grab.startup_ticks, c.grab_startup_ticks)
	assert_eq(grab.hitbox_forward, c.grab_forward)


func test_only_first_two_light_hits_chain() -> void:
	assert_true(AttackSet.is_light_chainable(AttackSet.Kind.LIGHT_1))
	assert_true(AttackSet.is_light_chainable(AttackSet.Kind.LIGHT_2))
	for kind: int in [AttackSet.Kind.LIGHT_3, AttackSet.Kind.HEAVY, AttackSet.Kind.BAT, AttackSet.Kind.GRAB]:
		assert_false(AttackSet.is_light_chainable(kind))


func test_table_follows_config_changes() -> void:
	var c := GameConfig.new()
	c.heavy_damage = 20.0
	assert_eq(AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY).damage, 20.0)
```

`tests/unit/test_fighter.gd` 수정 — `_sample()`의 `return f` 앞에 추가:
```gdscript
	f.attack_kind = AttackSet.Kind.HEAVY
	f.combo_queued = true
	f.charge_ticks = 12
	f.charge_mul = 1.3
	f.grab_ticks = 40
	f.partner_id = 0
	f.item_kind = 1
	f.item_uses = 3
```
파일 끝에 추가:
```gdscript


func test_phase2_states_keep_phase1_values() -> void:
	assert_eq(Fighter.State.KO, 5, "HUD/bot/views compare against KO; its value must not move")
	assert_eq(Fighter.State.CHARGE, 6)
	assert_eq(Fighter.State.GUARD, 7)
	assert_eq(Fighter.State.HOLDING, 8)
	assert_eq(Fighter.State.HELD, 9)


func test_new_states_cannot_act() -> void:
	var f := Fighter.new()
	for s: int in [Fighter.State.CHARGE, Fighter.State.GUARD, Fighter.State.HOLDING, Fighter.State.HELD]:
		f.set_state(s)
		assert_false(f.can_act(), "state %d" % s)
		assert_true(f.is_alive())


func test_phase2_fields_default_to_empty() -> void:
	var f := Fighter.new()
	assert_eq(f.partner_id, Fighter.NONE)
	assert_eq(f.item_kind, Fighter.NONE)
	assert_eq(f.item_uses, 0)
	assert_eq(f.charge_mul, 1.0)


func test_view_exposes_phase2_fields() -> void:
	var view := _sample().to_view()
	assert_eq(view["attack_kind"], AttackSet.Kind.HEAVY)
	assert_eq(view["charge_ticks"], 12)
	assert_eq(view["partner_id"], 0)
	assert_eq(view["item_kind"], 1)
	assert_eq(view["item_uses"], 3)
	assert_false(view.has("combo_queued"), "input bookkeeping stays out of views")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_attack_set`
Expected: FAIL — `Identifier "AttackSet" not declared` (파서 에러)

- [ ] **Step 3: AttackData 필드 추가**

`src/sim/attack_data.gd`의 `var hitstop_ticks: int = 0` 다음 줄에 추가:
```gdscript
## Hitstun floor in ticks; link hits use it so the next combo hit connects (context E1).
var min_hitstun_ticks: int = 0
```

- [ ] **Step 4: AttackSet 작성**

`src/sim/attack_set.gd`:
```gdscript
class_name AttackSet
extends RefCounted
## Every attack's numbers for one tick, keyed by Kind (PRD §4.3-4.4). Built from GameConfig
## every tick so debug-panel tuning applies at once; Phase 5 styles will build this table instead.
## LIGHT_1/2 are link hits and LIGHT_3 is the Phase 1 light attack (context E1).

enum Kind { LIGHT_1, LIGHT_2, LIGHT_3, HEAVY, GRAB, THROW, BAT, ROCK, BOMB }

var _table: Array[AttackData] = []


static func from_config(config: GameConfig) -> AttackSet:
	var s := AttackSet.new()
	s._table.assign([
		_link(config), _link(config), AttackData.light_from(config), _heavy(config), _grab(config),
		_throw(config), _bat(config), _rock(config), _bomb(config),
	])
	return s


func get_attack(kind: int) -> AttackData:
	return _table[kind]


static func is_light_chainable(kind: int) -> bool:
	return kind == Kind.LIGHT_1 or kind == Kind.LIGHT_2


static func _numbers(damage: float, base: float, scaling: float, angle: float, hitstop_seconds: float) -> AttackData:
	var a := AttackData.new()
	a.damage = damage
	a.base_knockback = base
	a.knockback_scaling = scaling
	a.launch_angle_y = angle
	a.hitstop_ticks = SimTime.to_ticks(hitstop_seconds)
	return a


static func _frames(a: AttackData, startup: int, active: int, recovery: int) -> void:
	a.startup_ticks = startup
	a.active_ticks = active
	a.recovery_ticks = recovery


static func _link(c: GameConfig) -> AttackData:
	var a := _numbers(c.light_link_damage, c.light_link_base_knockback, 0.0, c.light_link_launch_angle_y, c.hitstop_light)
	_frames(a, c.light_startup_ticks, c.light_active_ticks, c.light_recovery_ticks)
	a.hitbox_forward = c.light_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.light_hitbox_half_width, c.light_hitbox_half_height, c.light_hitbox_half_width)
	a.min_hitstun_ticks = c.light_link_hitstun_ticks
	return a


static func _heavy(c: GameConfig) -> AttackData:
	var a := _numbers(c.heavy_damage, c.heavy_base_knockback, c.heavy_knockback_scaling, c.heavy_launch_angle_y, c.hitstop_heavy)
	_frames(a, c.heavy_startup_ticks, c.heavy_active_ticks, c.heavy_recovery_ticks)
	a.hitbox_forward = c.heavy_hitbox_forward
	a.hitbox_up = c.heavy_hitbox_up
	a.hitbox_half = Vector3(c.heavy_hitbox_half_width, c.heavy_hitbox_half_height, c.heavy_hitbox_half_width)
	return a


static func _grab(c: GameConfig) -> AttackData:
	var a := _numbers(0.0, 0.0, 0.0, 0.0, 0.0)
	_frames(a, c.grab_startup_ticks, c.grab_active_ticks, c.grab_recovery_ticks)
	a.hitbox_forward = c.grab_forward
	a.hitbox_up = c.fighter_height * 0.5
	a.hitbox_half = Vector3(c.grab_half_width, c.fighter_height * 0.5, c.grab_half_width)
	return a


static func _throw(c: GameConfig) -> AttackData:
	return _numbers(c.throw_damage, c.throw_base_knockback, c.throw_knockback_scaling, c.throw_launch_angle_y, c.hitstop_heavy)


static func _bat(c: GameConfig) -> AttackData:
	var a := _numbers(c.bat_damage, c.bat_base_knockback, c.bat_knockback_scaling, c.bat_launch_angle_y, c.hitstop_heavy)
	_frames(a, c.bat_startup_ticks, c.bat_active_ticks, c.bat_recovery_ticks)
	a.hitbox_forward = c.bat_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.bat_hitbox_half_width, c.light_hitbox_half_height, c.bat_hitbox_half_width)
	return a


static func _rock(c: GameConfig) -> AttackData:
	return _numbers(c.rock_damage, c.rock_base_knockback, c.rock_knockback_scaling, c.rock_launch_angle_y, c.hitstop_light)


static func _bomb(c: GameConfig) -> AttackData:
	return _numbers(c.bomb_damage, c.bomb_base_knockback, c.bomb_knockback_scaling, c.bomb_launch_angle_y, c.hitstop_heavy)
```

- [ ] **Step 5: Fighter 확장**

`src/sim/fighter.gd` 교체 부분:

주석 3~5행 뒤 enum과 DATA_TYPES를 교체:
```gdscript
## View reading: "launched" = HITSTUN and not on_ground; "respawn" = invuln_ticks > 0.
## New states are appended so Phase 1 values (KO = 5) never move.

enum State { IDLE, MOVE, AIR, ATTACK, HITSTUN, KO, CHARGE, GUARD, HOLDING, HELD }

## "No fighter" / "no item" marker for partner_id and item_kind.
const NONE := -1

const DATA_TYPES := {
	"id": TYPE_INT, "spawn_id": TYPE_INT, "pos": TYPE_VECTOR3, "vel": TYPE_VECTOR3,
	"facing": TYPE_VECTOR3, "state": TYPE_INT, "state_ticks": TYPE_INT, "damage": TYPE_FLOAT,
	"stocks": TYPE_INT, "jumps_left": TYPE_INT, "on_ground": TYPE_BOOL,
	"hitstun_ticks": TYPE_INT, "hitstop_ticks": TYPE_INT, "invuln_ticks": TYPE_INT,
	"attack_ticks": TYPE_INT, "hit_ids": TYPE_ARRAY,
	"attack_kind": TYPE_INT, "combo_queued": TYPE_BOOL, "charge_ticks": TYPE_INT,
	"charge_mul": TYPE_FLOAT, "grab_ticks": TYPE_INT, "partner_id": TYPE_INT,
	"item_kind": TYPE_INT, "item_uses": TYPE_INT,
}
```

`var hit_ids: Array[int] = []` 다음에 추가:
```gdscript
## AttackSet.Kind of the current (or last) attack.
var attack_kind: int = 0
## A light press landed inside the combo buffer; the next hit starts when this one ends (E2).
var combo_queued: bool = false
var charge_ticks: int = 0
## Multiplier for the heavy attack that is currently swinging (E3).
var charge_mul: float = 1.0
## Ticks left before a hold ends by itself (holder only, E5).
var grab_ticks: int = 0
## HOLDING: the fighter being held. HELD: the holder.
var partner_id: int = NONE
## Item.Kind carried in hand, or NONE (E6).
var item_kind: int = NONE
var item_uses: int = 0
```

`to_view()` 교체:
```gdscript
func to_view() -> Dictionary:
	return {
		"id": id, "spawn_id": spawn_id, "pos": pos, "facing": facing, "state": state,
		"on_ground": on_ground, "damage": damage, "stocks": stocks, "jumps_left": jumps_left,
		"invuln_ticks": invuln_ticks, "hitstop_ticks": hitstop_ticks, "attack_ticks": attack_ticks,
		"attack_kind": attack_kind, "charge_ticks": charge_ticks, "partner_id": partner_id,
		"item_kind": item_kind, "item_uses": item_uses,
	}
```
`to_data()` / `from_data()`는 `DATA_TYPES`를 순회하므로 수정 불필요.

- [ ] **Step 6: snapshot 버전 올리기**

`src/sim/world.gd`: `const SNAPSHOT_VERSION := 2` → `const SNAPSHOT_VERSION := 3`, 주석 5행 끝에 ` Snapshot v3 adds the Phase 2 fighter fields.` 추가.

- [ ] **Step 7: 테스트 + 골든**

Run: `./scripts/test.sh`
Expected: 새 테스트 PASS, `test_golden_hash`만 FAIL (스냅샷 바이트에 필드가 늘어남). 출력된 값으로 `GOLDEN_HASH` 갱신 후 재실행 → 전부 PASS.

- [ ] **Step 8: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/attack_set.gd src/sim/attack_set.gd.uid src/sim/attack_data.gd src/sim/fighter.gd src/sim/world.gd tests/unit/test_attack_set.gd tests/unit/test_attack_set.gd.uid tests/unit/test_fighter.gd tests/replay/test_replay.gd
git commit -m "feat: add attack table and phase 2 fighter state" -m "GOLDEN_HASH regenerated: snapshot v3 serializes the new fighter fields (no behavior change)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Actions — 약공격 3타 콤보 + 입력 버퍼, World가 AttackSet 사용

**Files:**
- Create: `src/sim/actions.gd`
- Modify: `src/sim/motion.gd` (`step` 시그니처, 상태 분기), `src/sim/combat.gd` (`resolve`가 AttackSet 사용, hitstun 하한), `src/sim/world.gd` (`AttackSet.from_config`)
- Modify: `src/debug/feel_scenario.gd`, `src/debug/ringout_demo.gd` (3타 콤보로 측정·시연, E1)
- Test: `tests/unit/test_actions.gd` (신규), `tests/unit/test_combat.gd`, `tests/unit/test_ringout_feel.gd` (메시지)
- Modify: `tests/replay/test_replay.gd` (`GOLDEN_HASH` — 첫 약공격이 연결타가 되어 sim 결과가 바뀜)

**Interfaces:**
- Consumes: T2 `AttackSet`, `Fighter.attack_kind`, `Fighter.combo_queued`, `AttackData.min_hitstun_ticks`
- Produces:
  - `static func Actions.try_start(f: Fighter, input: InputFrame, config: GameConfig) -> bool` — 조작 가능한 파이터가 이번 틱 행동을 시작하면 true (T3: 약공격. T4·T5·T6·T8이 차지·가드·잡기·방망이를 더함)
  - `static func Actions.start_attack(f: Fighter, kind: int) -> void`
  - `static func Actions.step_attack(f: Fighter, input: InputFrame, config: GameConfig, attacks: AttackSet) -> void`
  - `static func Motion.step(f: Fighter, input: InputFrame, config: GameConfig, attacks: AttackSet) -> void` (4번째 인자 타입이 `AttackData` → `AttackSet`)
  - `static func Combat.resolve(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]` — 공격자의 `attack_kind`로 수치를 고르고 `GRAB`은 건너뜀. hit 이벤트에 `"attack_kind"` 추가
- 근거: `[PRD-CMB-01]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_actions.gd` 신규:
```gdscript
extends GutTest
## Light combo (context E1, E2): link, link, finisher; a press inside the buffer chains.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _light() -> InputFrame:
	return InputFrame.make(0, 0, false, true)


## P2 stands 1.0 m in front of P1, inside the light hitbox.
func _adjacent_world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	return w


func _total(c: GameConfig) -> int:
	return c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks


## Ticks P1 through its current attack (no target nearby, so no hitstop) pressing light exactly
## when `remaining` ticks of the attack are left, then idles until the attack would end.
func _press_with_remaining(w: World, remaining: int) -> void:
	var total := _total(w.config)
	for t: int in range(1, total + 1):
		var left := total - t
		w.tick(_inputs(_light() if left == remaining else InputFrame.neutral()))


func test_single_press_is_one_link_hit() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_1)


func test_press_inside_buffer_chains_second_hit() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	_press_with_remaining(w, w.config.combo_buffer_ticks)
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_2, "a press with exactly buffer ticks left chains")
	assert_eq(w.fighters[0].attack_ticks, 0, "the next hit starts on the tick the first one ends")


func test_press_outside_buffer_is_dropped() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	_press_with_remaining(w, w.config.combo_buffer_ticks + 1)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE, "an early press does not queue the next hit")


func test_third_hit_does_not_chain_further() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	_press_with_remaining(w, 0)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_2)
	_press_with_remaining(w, 0)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_3)
	_press_with_remaining(w, 0)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE, "after the finisher the combo resets")


func test_link_hit_keeps_target_close_and_stunned() -> void:
	var w := _adjacent_world()
	w.tick(_inputs(_light()))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	var target := w.fighters[1]
	assert_eq(target.state, Fighter.State.HITSTUN)
	assert_eq(target.damage, w.config.light_link_damage)
	assert_gte(target.hitstun_ticks, w.config.light_link_hitstun_ticks, "hitstun floor from the link hit")
	assert_eq(target.vel.y, 0.0, "link hits are flat (launch angle 0)")


func test_full_combo_lands_three_hits() -> void:
	var w := _adjacent_world()
	var hits := 0
	for t: int in 120:
		var attacker := w.fighters[0]
		var mashing := t == 0 or (attacker.state == Fighter.State.ATTACK and AttackSet.is_light_chainable(attacker.attack_kind))
		w.tick(_inputs(_light() if mashing else InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hits += 1
	var c := w.config
	assert_eq(hits, 3, "link, link, finisher all connect from 0%")
	assert_eq(w.fighters[1].damage, c.light_link_damage * 2.0 + c.light_damage)
```

`tests/unit/test_combat.gd` 수정 (첫 약공격이 연결타가 된다):
- `test_light_hits_after_startup_and_applies_damage`를 아래로 교체:
```gdscript
func test_first_light_is_a_link_hit_after_startup() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var target := w.fighters[1]
	var link := AttackSet.from_config(w.config).get_attack(AttackSet.Kind.LIGHT_1)
	assert_eq(target.damage, w.config.light_link_damage)
	assert_eq(target.state, Fighter.State.HITSTUN)
	var events: Array = w.state_view()["events"]
	assert_eq(events.size(), 1)
	var e: Dictionary = events[0]
	assert_eq(e["type"], "hit")
	assert_eq(e["attacker"], 0)
	assert_eq(e["target"], 1)
	assert_eq(e["attack_kind"], AttackSet.Kind.LIGHT_1)
	assert_almost_eq(e["knockback"], Combat.knockback(link, w.config.light_link_damage, w.config), 0.0001)
```
- `test_hitstop_freezes_both_then_target_flies`: `assert_gt(w.fighters[1].pos.y, p2_at_hit.y, "launched upward")` 한 줄 삭제 (연결타는 발사각 0). 나머지 유지.
- `test_one_hit_per_swing`: `assert_eq(w.fighters[1].damage, 4.0)` → `assert_eq(w.fighters[1].damage, w.config.light_link_damage)`.

`tests/unit/test_ringout_feel.gd`의 첫 테스트 메시지 교체:
```gdscript
			"PHASES Phase 1 (context E1): at 100%+ the light combo finisher must send the target out")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_actions`
Expected: FAIL — `test_press_inside_buffer_chains_second_hit` 등 (콤보 없음: attack_kind가 항상 0, 두 번째 타 없음)

- [ ] **Step 3: Actions 작성**

`src/sim/actions.gd`:
```gdscript
class_name Actions
extends RefCounted
## Control-state transitions (PRD §4.3): what a fighter that can act starts this tick and how a
## running attack advances. Motion owns physics and calls into here. Later tasks add heavy
## charge, guard, grab and bat swings to try_start.


## Returns true when the fighter started an action this tick (movement is then skipped).
static func try_start(f: Fighter, input: InputFrame, _config: GameConfig) -> bool:
	if input.light:
		start_attack(f, AttackSet.Kind.LIGHT_1)
		return true
	return false


static func start_attack(f: Fighter, kind: int) -> void:
	f.set_state(Fighter.State.ATTACK)
	f.state_ticks = 0
	f.attack_kind = kind
	f.attack_ticks = 0
	f.combo_queued = false
	f.charge_mul = 1.0
	f.hit_ids.clear()
	if f.on_ground:
		stop_horizontal(f)


## One tick of a running attack. A light press while at most combo_buffer_ticks remain queues
## the next light hit, which starts on the tick this one ends (context E2).
static func step_attack(f: Fighter, input: InputFrame, config: GameConfig, attacks: AttackSet) -> void:
	var attack := attacks.get_attack(f.attack_kind)
	f.attack_ticks += 1
	if f.on_ground:
		stop_horizontal(f)
	var left := attack.total_ticks() - f.attack_ticks
	if input.light and AttackSet.is_light_chainable(f.attack_kind) and left <= config.combo_buffer_ticks:
		f.combo_queued = true
	if left > 0:
		return
	if f.combo_queued:
		start_attack(f, f.attack_kind + 1)
		return
	f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


static func stop_horizontal(f: Fighter) -> void:
	f.vel.x = 0.0
	f.vel.z = 0.0
```
(`_config`는 T4부터 쓰인다. 밑줄 접두사는 GDScript "unused parameter" 경고를 막는다.)

- [ ] **Step 4: Motion을 Actions로 위임**

`src/sim/motion.gd`에서 `step`과 `_step_control`, `_step_attack`을 교체한다 (`separate`, `_step_hitstun`, `_integrate`는 그대로):
```gdscript
static func step(f: Fighter, input: InputFrame, config: GameConfig, attacks: AttackSet) -> void:
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
			Actions.step_attack(f, input, config, attacks)
		_:
			if not Actions.try_start(f, input, config):
				_step_control(f, input, config)
	_integrate(f, config)
	f.state_ticks += 1


static func _step_control(f: Fighter, input: InputFrame, config: GameConfig) -> void:
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
```
(`_step_attack`는 삭제 — Actions.step_attack으로 옮김.)

- [ ] **Step 5: Combat이 AttackSet 사용 + hitstun 하한**

`src/sim/combat.gd`의 `resolve`와 `_apply_hit` 교체:
```gdscript
static func resolve(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for attacker: Fighter in fighters:
		if attacker.state != Fighter.State.ATTACK or attacker.attack_kind == AttackSet.Kind.GRAB:
			continue
		var attack := attacks.get_attack(attacker.attack_kind)
		if not attack.is_active(attacker.attack_ticks):
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
	target.hitstun_ticks = maxi(hitstun_ticks(kb, config), attack.min_hitstun_ticks)
	target.attack_ticks = 0
	target.hit_ids.clear()
	target.set_state(Fighter.State.HITSTUN)
	target.hitstop_ticks = attack.hitstop_ticks
	attacker.hitstop_ticks = attack.hitstop_ticks
	return {
		"type": "hit", "attacker": attacker.id, "target": target.id, "pos": at,
		"knockback": kb, "hitstop_ticks": attack.hitstop_ticks, "attack_kind": attacker.attack_kind,
	}
```

- [ ] **Step 6: World가 AttackSet을 넘김**

`src/sim/world.gd`의 `tick` 안:
```gdscript
		var attacks := AttackSet.from_config(config)
		for f: Fighter in fighters:
			var input: InputFrame = inputs[f.id] if f.id < inputs.size() else InputFrame.neutral()
			Motion.step(f, input, config, attacks)
		Motion.separate(fighters, config)
		_events.append_array(Combat.resolve(fighters, attacks, config))
```
(`var attack := AttackData.light_from(config)` 줄은 삭제)

- [ ] **Step 7: 링아웃 측정을 3타 콤보로**

`src/debug/feel_scenario.gd` 교체:
```gdscript
class_name FeelScenario
extends RefCounted
## The feel check (PRD §1.1 "과장된 넉백"): a target standing halfway between the arena center
## and edge takes the full three-hit light combo starting at the given damage % (context E1:
## hits 1-2 are links, hit 3 is the Phase 1 light attack). Shared by the regression test and
## scripts/tune_knockback.gd so both measure the same thing.

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
	for t: int in MAX_TICKS:
		var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, combo_press(t, attacker)), InputFrame.neutral()]
		w.tick(inputs)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "ringout" and int(e["id"]) == 1:
				return true
	return false


## Presses light on the first tick and on every tick of a chainable hit, so the combo runs to
## the finisher and stops there.
static func combo_press(t: int, attacker: Fighter) -> bool:
	return t == 0 or (attacker.state == Fighter.State.ATTACK and AttackSet.is_light_chainable(attacker.attack_kind))
```

`src/debug/ringout_demo.gd`의 머리 주석 두 줄과 `_gather_inputs` 교체:
```gdscript
## Phase 1/2 evidence scene: the bot stands at 100% halfway to the edge and the player runs the
## three-hit light combo from tick 60 (context E1). Used for the ring-out video and key frames.
```
```gdscript
func _gather_inputs() -> Array[InputFrame]:
	var w := get_world()
	var t := w.tick_count - SWING_TICK
	var press := t >= 0 and FeelScenario.combo_press(t, w.fighters[LOCAL_PLAYER])
	var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, press), InputFrame.neutral()]
	return inputs
```

- [ ] **Step 8: 테스트 + 골든**

Run: `./scripts/test.sh`
Expected: `test_actions` 6개 PASS, `test_ringout_feel` 2개 PASS (100% → 링아웃, 0% → 잔류), `test_golden_hash`만 FAIL. 출력 값으로 `GOLDEN_HASH` 갱신 → 전부 PASS.
`test_ringout_feel`의 0% 케이스가 실패하면(콤보 마무리가 0%에서도 링아웃) `godot --headless --path . -s res://scripts/tune_knockback.gd`로 최소 배율을 확인하고 보고서에 수치를 적은 뒤 멈춘다 (수치 조정은 컨트롤러 판단).

- [ ] **Step 9: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/actions.gd src/sim/actions.gd.uid src/sim/motion.gd src/sim/combat.gd src/sim/world.gd src/debug/feel_scenario.gd src/debug/ringout_demo.gd tests/unit/test_actions.gd tests/unit/test_actions.gd.uid tests/unit/test_combat.gd tests/unit/test_ringout_feel.gd tests/replay/test_replay.gd
git commit -m "feat: add three-hit light combo with input buffer" -m "GOLDEN_HASH regenerated: a single light press is now a link hit (context E1)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 강공격 + 차지

**Files:**
- Modify: `src/sim/actions.gd` (`try_start`에 차지, `step_charge`, `charge_mul`), `src/sim/motion.gd` (CHARGE 분기), `src/sim/combat.gd` (차지 배율)
- Test: `tests/unit/test_charge.gd` (신규)

**Interfaces:**
- Consumes: T3 `Actions`, T2 `Fighter.charge_ticks`/`charge_mul`, `AttackSet.Kind.HEAVY`
- Produces:
  - `static func Actions.charge_mul(charge_ticks: int, config: GameConfig) -> float` — `1 + (heavy_charge_max_mul − 1) × min(charge_ticks / to_ticks(heavy_charge_max_time), 1)`
  - `static func Actions.step_charge(f: Fighter, input: InputFrame, config: GameConfig) -> void`
  - 우선순위: `try_start`는 강공격(heavy)을 약공격보다 먼저 본다
  - `Combat` hit 이벤트에 `"power": float` (강공격이면 차지 배율, 아니면 1.0)
- 근거: `[PRD-CMB-02]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_charge.gd`:
```gdscript
extends GutTest
## Heavy attack charge (context E3). PHASES test: 0 / 0.5 / 1.0 / 1.5 s -> 1.0 / 1.3 / 1.6 / 1.6.


func _inputs(p1: InputFrame) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, InputFrame.neutral()]
	return a


func _heavy() -> InputFrame:
	return InputFrame.make(0, 0, false, false, true)


func test_charge_multiplier_curve() -> void:
	var c := GameConfig.new()
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(0.0), c), 1.0, 0.0001)
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(0.5), c), 1.3, 0.0001)
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(1.0), c), 1.6, 0.0001)
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(1.5), c), 1.6, 0.0001, "capped at the max charge")


func test_holding_heavy_charges_in_place() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_heavy()))
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.CHARGE)
	var start := f.pos
	for i: int in 20:
		w.tick(_inputs(InputFrame.make(1, 0, false, false, true)))
	assert_eq(f.state, Fighter.State.CHARGE)
	assert_eq(f.charge_ticks, 20)
	assert_eq(f.pos, start, "charging on the ground does not move, even with a move input")


func test_charge_ticks_cap_at_max_time() -> void:
	var w := World.new(GameConfig.new(), 1)
	for i: int in 200:
		w.tick(_inputs(_heavy()))
	assert_eq(w.fighters[0].charge_ticks, SimTime.to_ticks(w.config.heavy_charge_max_time))


func test_release_fires_heavy_with_the_charge_multiplier() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_heavy()))
	for i: int in 30:
		w.tick(_inputs(_heavy()))
	w.tick(_inputs(InputFrame.neutral()))
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.ATTACK)
	assert_eq(f.attack_kind, AttackSet.Kind.HEAVY)
	assert_almost_eq(f.charge_mul, 1.3, 0.0001)


func test_one_tick_tap_is_an_uncharged_heavy() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_heavy()))
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.HEAVY)
	assert_eq(w.fighters[0].charge_mul, 1.0)


func test_heavy_takes_priority_over_light() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, false, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.CHARGE)


func test_charged_heavy_scales_damage_and_knockback() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.tick(_inputs(_heavy()))
	for i: int in 30:
		w.tick(_inputs(_heavy()))
	w.tick(_inputs(InputFrame.neutral()))
	var hit: Dictionary = {}
	for i: int in c.heavy_startup_ticks + 2:
		w.tick(_inputs(InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hit = e
	assert_false(hit.is_empty(), "the heavy lands after its startup")
	var heavy := AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY)
	var dmg := c.heavy_damage * 1.3
	assert_almost_eq(w.fighters[1].damage, dmg, 0.0001)
	assert_almost_eq(hit["power"], 1.3, 0.0001)
	assert_almost_eq(hit["knockback"], Combat.knockback(heavy, dmg, c) * 1.3, 0.0001)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_charge`
Expected: FAIL — `Static function "charge_mul()" not found in base "Actions"`

- [ ] **Step 3: Actions에 차지 추가**

`src/sim/actions.gd`의 `try_start` 교체 + 함수 두 개 추가:
```gdscript
## Returns true when the fighter started an action this tick (movement is then skipped).
## Priority: heavy > light.
static func try_start(f: Fighter, input: InputFrame, _config: GameConfig) -> bool:
	if input.heavy:
		f.set_state(Fighter.State.CHARGE)
		f.state_ticks = 0
		f.charge_ticks = 0
		if f.on_ground:
			stop_horizontal(f)
		return true
	if input.light:
		start_attack(f, AttackSet.Kind.LIGHT_1)
		return true
	return false


## heavy is a held level (context E3): charge while it is true, swing on the tick it goes false.
static func step_charge(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	if f.on_ground:
		stop_horizontal(f)
	if input.heavy:
		f.charge_ticks = mini(f.charge_ticks + 1, SimTime.to_ticks(config.heavy_charge_max_time))
		return
	var mul := charge_mul(f.charge_ticks, config)
	start_attack(f, AttackSet.Kind.HEAVY)
	f.charge_mul = mul


static func charge_mul(charge_ticks: int, config: GameConfig) -> float:
	var full := maxi(SimTime.to_ticks(config.heavy_charge_max_time), 1)
	return 1.0 + (config.heavy_charge_max_mul - 1.0) * minf(float(charge_ticks) / full, 1.0)
```

- [ ] **Step 4: Motion에 CHARGE 분기**

`src/sim/motion.gd` `step`의 `match`에 `Fighter.State.ATTACK:` 분기 다음으로 추가:
```gdscript
		Fighter.State.CHARGE:
			Actions.step_charge(f, input, config)
```

- [ ] **Step 5: Combat에 차지 배율**

`src/sim/combat.gd` `_apply_hit`의 앞부분을 교체 (대미지·넉백 모두 배율, E3):
```gdscript
static func _apply_hit(attacker: Fighter, target: Fighter, attack: AttackData,
		config: GameConfig, at: Vector3) -> Dictionary:
	var power := attacker.charge_mul if attacker.attack_kind == AttackSet.Kind.HEAVY else 1.0
	attacker.hit_ids.append(target.id)
	target.damage += attack.damage * power
	var kb := knockback(attack, target.damage, config) * power
```
반환 딕셔너리에 `"power": power,` 추가.

- [ ] **Step 6: 테스트 + 골든 확인**

Run: `./scripts/test.sh`
Expected: 전부 PASS. 리플레이 스크립트는 아직 heavy를 누르지 않으므로 `GOLDEN_HASH`는 그대로여야 한다 (바뀌면 멈추고 원인 보고).

- [ ] **Step 7: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/actions.gd src/sim/motion.gd src/sim/combat.gd tests/unit/test_charge.gd tests/unit/test_charge.gd.uid
git commit -m "feat: add charged heavy attack" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 가드 + Combat.apply_hit 공용화

모든 명중(근접·던지기·투사체·폭발)이 같은 `apply_hit`을 지나도록 바꾸고, 가드 처리를 그 안에 둔다.

**Files:**
- Modify: `src/sim/combat.gd` (`apply_hit` 공개, 가드), `src/sim/actions.gd` (`try_start`에 가드, `step_guard`), `src/sim/motion.gd` (GUARD 분기)
- Test: `tests/unit/test_guard.gd` (신규)

**Interfaces:**
- Consumes: T4 `Combat`, `Actions`
- Produces:
  - `static func Combat.apply_hit(target: Fighter, attack: AttackData, dir: Vector3, power: float, config: GameConfig, at: Vector3, source_id: int) -> Dictionary` — 이벤트 `{"type": "hit" | "guard_hit", "attacker": source_id, "target", "pos", "knockback", "hitstop_ticks", "power"}`. 대상의 hitstop만 설정 (공격자 hitstop은 호출자 책임). T6 던지기, T8 투사체, T9 폭발이 쓴다
  - `static func Actions.step_guard(f: Fighter, input: InputFrame, config: GameConfig) -> void`
  - 우선순위: guard > heavy > light, 가드는 지상에서만 (E4)
- 근거: `[PRD-CMB-03]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_guard.gd`:
```gdscript
extends GutTest
## Guard (context E4). PHASES test: a guarded hit deals 20% damage and 0 knockback.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _guard(mx: float = 0.0) -> InputFrame:
	return InputFrame.make(mx, 0, false, false, false, true)


## P2 guards 1.0 m in front of P1.
func _guarding_world(config: GameConfig = null) -> World:
	var w := World.new(config if config != null else GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.tick(_inputs(InputFrame.neutral(), _guard()))
	return w


## P1 presses `press` once; both sides keep their inputs until the swing's startup has passed.
func _swing(w: World, press: InputFrame, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	w.tick(_inputs(press, _guard()))
	for i: int in ticks:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
		for e: Dictionary in w.state_view()["events"]:
			events.append(e)
	return events


func test_guard_holds_in_place() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_guard()))
	var start := w.fighters[0].pos
	for i: int in 10:
		w.tick(_inputs(_guard(1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	assert_eq(w.fighters[0].pos, start, "no movement while guarding")


func test_release_returns_to_idle() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_guard()))
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)


func test_no_guard_in_the_air() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	w.tick(_inputs(_guard()))
	assert_eq(w.fighters[0].state, Fighter.State.AIR)


func test_guard_beats_heavy_and_light_priority() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, false, true, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)


func test_guarded_hit_deals_20_percent_and_no_knockback() -> void:
	var w := _guarding_world()
	var events := _swing(w, InputFrame.make(0, 0, false, true), w.config.light_startup_ticks + 1)
	var target := w.fighters[1]
	assert_almost_eq(target.damage, w.config.light_link_damage * 0.2, 0.0001)
	assert_eq(target.state, Fighter.State.GUARD, "no hitstun through a guard")
	assert_eq(Vector2(target.vel.x, target.vel.z), Vector2.ZERO)
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "guard_hit")
	assert_eq(events[0]["knockback"], 0.0)


func test_guarded_hit_still_hitstops_both() -> void:
	var w := _guarding_world()
	w.tick(_inputs(InputFrame.make(0, 0, false, true), _guard()))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
	var stop := SimTime.to_ticks(w.config.hitstop_light)
	assert_eq(w.fighters[0].hitstop_ticks, stop)
	assert_eq(w.fighters[1].hitstop_ticks, stop)


func test_guarded_heavy_uses_guard_damage_mul() -> void:
	var w := _guarding_world()
	_swing(w, InputFrame.make(0, 0, false, false, true), 1)
	_swing(w, InputFrame.neutral(), w.config.heavy_startup_ticks + 1)
	assert_almost_eq(w.fighters[1].damage, w.config.heavy_damage * 0.2, 0.0001)


func test_guard_knockback_mul_pushes_back_without_breaking_guard() -> void:
	var c := GameConfig.new()
	c.guard_knockback_mul = 0.5
	var w := _guarding_world(c)
	_swing(w, InputFrame.make(0, 0, false, true), c.light_startup_ticks + 1 + SimTime.to_ticks(c.hitstop_light) + 10)
	assert_eq(w.fighters[1].state, Fighter.State.GUARD)
	assert_gt(w.fighters[1].pos.x, w.fighters[0].pos.x + 1.0, "pushed away along the attacker's facing")


func test_apply_hit_uses_the_given_direction() -> void:
	var c := GameConfig.new()
	var target := Fighter.new()
	var rock := AttackSet.from_config(c).get_attack(AttackSet.Kind.ROCK)
	var e := Combat.apply_hit(target, rock, Vector3(0, 0, -1), 1.0, c, Vector3.ZERO, 3)
	assert_eq(e["type"], "hit")
	assert_eq(e["attacker"], 3)
	assert_lt(target.vel.z, 0.0)
	assert_almost_eq(target.vel.x, 0.0, 0.0001)
	assert_eq(target.state, Fighter.State.HITSTUN)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_guard`
Expected: FAIL — `test_guard_holds_in_place`에서 state가 IDLE/MOVE (가드 없음), `apply_hit` 미정의

- [ ] **Step 3: Combat 재구성**

`src/sim/combat.gd`의 `resolve` 안쪽 명중 처리와 `_apply_hit`를 교체한다:
```gdscript
			if Collision.capsule_hits_box(target.pos, config.fighter_radius, config.fighter_height,
					center, yaw, attack.hitbox_half):
				attacker.hit_ids.append(target.id)
				var power := attacker.charge_mul if attacker.attack_kind == AttackSet.Kind.HEAVY else 1.0
				var e := apply_hit(target, attack, attacker.facing, power, config, center, attacker.id)
				e["attack_kind"] = attacker.attack_kind
				attacker.hitstop_ticks = attack.hitstop_ticks
				events.append(e)
	return events


## One hit from any source (melee, throw, projectile, explosion). dir is the push direction,
## power scales damage and knockback (heavy charge). A guarding target takes guard_damage_mul
## of the damage and guard_knockback_mul of the knockback as a flat push, stays in GUARD and
## reports "guard_hit" (context E4). Sets the target's hitstop; the caller sets the attacker's.
static func apply_hit(target: Fighter, attack: AttackData, dir: Vector3, power: float,
		config: GameConfig, at: Vector3, source_id: int) -> Dictionary:
	var guarded := target.state == Fighter.State.GUARD
	target.damage += attack.damage * power * (config.guard_damage_mul if guarded else 1.0)
	var kb := knockback(attack, target.damage, config) * power
	target.hitstop_ticks = attack.hitstop_ticks
	var event := {
		"type": "hit", "attacker": source_id, "target": target.id, "pos": at,
		"knockback": kb, "hitstop_ticks": attack.hitstop_ticks, "power": power,
	}
	if guarded:
		kb *= config.guard_knockback_mul
		var flat := Vector3(dir.x, 0.0, dir.z)
		var push := flat.normalized() * kb if flat.length() > 0.0 else Vector3.ZERO
		target.vel.x = push.x
		target.vel.z = push.z
		event["type"] = "guard_hit"
		event["knockback"] = kb
		return event
	target.vel = launch_velocity(dir, attack, kb)
	if target.vel.y > 0.0:
		target.on_ground = false
	target.hitstun_ticks = maxi(hitstun_ticks(kb, config), attack.min_hitstun_ticks)
	target.attack_ticks = 0
	target.hit_ids.clear()
	target.combo_queued = false
	target.charge_ticks = 0
	target.set_state(Fighter.State.HITSTUN)
	return event
```
파일 머리 주석 2~4행 끝에 `All hit sources share apply_hit, which also handles guard (context E4).`를 덧붙인다.

- [ ] **Step 4: Actions에 가드**

`src/sim/actions.gd` `try_start`의 첫 분기 앞에 넣고, 주석 우선순위를 `guard > heavy > light`로 고친다:
```gdscript
	if input.guard and f.on_ground:
		f.set_state(Fighter.State.GUARD)
		f.state_ticks = 0
		stop_horizontal(f)
		return true
```
함수 추가:
```gdscript
## Guard holds while guard is pressed and the fighter stands on the ground (context E4). A
## guard push (guard_knockback_mul > 0) slides out with the ground friction.
static func step_guard(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	f.vel.x *= config.hitstun_ground_friction
	f.vel.z *= config.hitstun_ground_friction
	if not input.guard or not f.on_ground:
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)
```

- [ ] **Step 5: Motion에 GUARD 분기**

`src/sim/motion.gd` `step`의 `match`에 CHARGE 분기 다음으로:
```gdscript
		Fighter.State.GUARD:
			Actions.step_guard(f, input, config)
```

- [ ] **Step 6: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS, `GOLDEN_HASH` 그대로 (리플레이 스크립트는 guard를 누르지 않음. 바뀌면 멈추고 보고).

- [ ] **Step 7: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/combat.gd src/sim/actions.gd src/sim/motion.gd tests/unit/test_guard.gd tests/unit/test_guard.gd.uid
git commit -m "feat: add guard and a shared hit application path" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 잡기 → 던지기

**Files:**
- Create: `src/sim/grab.gd`
- Modify: `src/sim/actions.gd` (`try_start`에 잡기), `src/sim/motion.gd` (HOLDING/HELD 분기, HELD는 적분 생략), `src/sim/rules.gd` (리스폰·KO 때 행동 필드 초기화), `src/sim/world.gd` (`_resolve_inputs`, Grab 호출)
- Test: `tests/unit/test_grab.gd` (신규), `tests/unit/test_rules.gd`

**Interfaces:**
- Consumes: T5 `Combat.apply_hit`, `Combat.hitbox_center`, `Actions.start_attack`/`stop_horizontal`, `AttackSet.Kind.GRAB`/`THROW`
- Produces:
  - `static func Grab.resolve(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]` — 이벤트 `{"type": "grab", "attacker", "target", "pos"}`
  - `static func Grab.step(fighters: Array[Fighter], inputs: Array[InputFrame], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]` — 들기·방향 전환·던지기(`hit` 이벤트, `attack_kind` = THROW)·시간 초과(`{"type": "grab_release", ...}`). `inputs[i]`는 id가 i인 파이터의 입력
  - `static func Grab.cleanup(fighters: Array[Fighter]) -> void` — 짝이 맞지 않는 HOLDING/HELD를 풀고, 그 외 상태의 `partner_id`를 NONE으로
  - `static func Grab.find(fighters: Array[Fighter], id: int) -> Fighter` (없으면 null)
  - `static func Rules.clear_actions(f: Fighter) -> void` — 공격·차지·콤보·잡기 필드 초기화 (T8에서 아이템 필드 추가)
  - `func World._resolve_inputs(inputs: Array[InputFrame]) -> Array[InputFrame]` — 파이터 id별 사본, 없으면 neutral
  - 우선순위: grab > guard > heavy > light, 잡기는 지상에서만
- 근거: `[PRD-CMB-04]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_grab.gd`:
```gdscript
extends GutTest
## Grab -> hold -> throw (context E5).


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _grab(mx: float = 0.0, mz: float = 0.0) -> InputFrame:
	return InputFrame.make(mx, mz, false, false, false, false, true)


## P2 stands 1.0 m in front of P1; P1 grabs and the hold is established.
func _holding_world(p2_input: InputFrame = null) -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	var p2 := p2_input if p2_input != null else InputFrame.neutral()
	w.tick(_inputs(_grab(), p2))
	for i: int in w.config.grab_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral(), p2))
	return w


func test_grab_press_starts_a_grab_attempt_on_the_ground() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.GRAB)


func test_no_grab_in_the_air() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].state, Fighter.State.AIR)


func test_whiffed_grab_recovers_to_idle() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_grab()))
	var c := w.config
	for i: int in c.grab_startup_ticks + c.grab_active_ticks + c.grab_recovery_ticks:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)


func test_grab_connects_into_hold() -> void:
	var w := _holding_world()
	var holder := w.fighters[0]
	var held := w.fighters[1]
	assert_eq(holder.state, Fighter.State.HOLDING)
	assert_eq(held.state, Fighter.State.HELD)
	assert_eq(holder.partner_id, 1)
	assert_eq(held.partner_id, 0)
	assert_eq(held.damage, 0.0, "the grab itself deals no damage")


func test_grab_ignores_guard() -> void:
	var w := _holding_world(InputFrame.make(0, 0, false, false, false, true))
	assert_eq(w.fighters[1].state, Fighter.State.HELD)


func test_holder_turns_and_carries_the_held_fighter() -> void:
	var w := _holding_world()
	w.tick(_inputs(InputFrame.make(0, 1)))
	var holder := w.fighters[0]
	var held := w.fighters[1]
	assert_eq(holder.facing, Vector3(0, 0, 1))
	assert_true(held.pos.is_equal_approx(holder.pos + Vector3(0, 0, w.config.grab_hold_distance)))
	assert_eq(held.state, Fighter.State.HELD)


func test_second_grab_press_throws_in_the_input_direction() -> void:
	var w := _holding_world()
	w.tick(_inputs(_grab(0, -1)))
	var holder := w.fighters[0]
	var held := w.fighters[1]
	assert_eq(held.state, Fighter.State.HITSTUN)
	assert_eq(held.damage, w.config.throw_damage)
	assert_eq(holder.partner_id, Fighter.NONE)
	assert_eq(held.partner_id, Fighter.NONE)
	assert_eq(holder.state, Fighter.State.IDLE)
	var thrown := false
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == "hit" and e["attack_kind"] == AttackSet.Kind.THROW:
			thrown = true
	assert_true(thrown)
	for i: int in SimTime.to_ticks(w.config.hitstop_heavy) + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_lt(held.vel.z, 0.0, "thrown toward -z (the input at the throw)")


func test_hold_ends_by_itself() -> void:
	var w := _holding_world()
	var released := false
	for i: int in SimTime.to_ticks(w.config.grab_hold_max_time):
		w.tick(_inputs(InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "grab_release":
				released = true
	assert_true(released)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)
	assert_eq(w.fighters[1].state, Fighter.State.IDLE)


func test_cleanup_frees_the_partner_of_a_hit_holder() -> void:
	var w := _holding_world()
	w.fighters[0].set_state(Fighter.State.HITSTUN)
	Grab.cleanup(w.fighters)
	assert_eq(w.fighters[1].state, Fighter.State.IDLE)
	assert_eq(w.fighters[1].partner_id, Fighter.NONE)
	assert_eq(w.fighters[0].partner_id, Fighter.NONE)


func test_holder_ring_out_frees_the_held_fighter() -> void:
	var w := _holding_world()
	w.fighters[0].pos = Vector3(0, w.config.kill_y - 1, 0)
	w.tick(_inputs(InputFrame.neutral()))
	assert_ne(w.fighters[1].state, Fighter.State.HELD)
	assert_eq(w.fighters[1].partner_id, Fighter.NONE)


func test_invulnerable_fighter_cannot_be_grabbed() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[1].invuln_ticks = 100
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.tick(_inputs(_grab()))
	for i: int in w.config.grab_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_ne(w.fighters[1].state, Fighter.State.HELD)
```

`tests/unit/test_rules.gd` 끝에 추가:
```gdscript


func test_respawn_clears_action_fields() -> void:
	var c := GameConfig.new()
	var f := Rules.spawn_fighter(0, 2, c)
	f.partner_id = 1
	f.grab_ticks = 30
	f.charge_ticks = 40
	f.charge_mul = 1.5
	f.combo_queued = true
	Rules.respawn(f, 2, c)
	assert_eq(f.partner_id, Fighter.NONE)
	assert_eq(f.grab_ticks, 0)
	assert_eq(f.charge_ticks, 0)
	assert_eq(f.charge_mul, 1.0)
	assert_false(f.combo_queued)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_grab`
Expected: FAIL — `Identifier "Grab" not declared`

- [ ] **Step 3: Grab 작성**

`src/sim/grab.gd`:
```gdscript
class_name Grab
extends RefCounted
## Grab -> hold -> throw (PRD §4.3, context E5). A grab is an ATTACK of kind GRAB with no damage;
## a connecting grab box turns the pair into HOLDING / HELD. The holder turns with the move
## input and throws with a second grab press; an unthrown hold ends after grab_hold_max_time.
## Grabs ignore guard (context E4). cleanup() frees any pair broken by hits or ring-outs.


static func resolve(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var grab := attacks.get_attack(AttackSet.Kind.GRAB)
	for holder: Fighter in fighters:
		if holder.state != Fighter.State.ATTACK or holder.attack_kind != AttackSet.Kind.GRAB:
			continue
		if not grab.is_active(holder.attack_ticks):
			continue
		var center := Combat.hitbox_center(holder, grab)
		var yaw := Collision.yaw_of(holder.facing)
		for target: Fighter in fighters:
			if not _grabbable(holder, target):
				continue
			if Collision.capsule_hits_box(target.pos, config.fighter_radius, config.fighter_height,
					center, yaw, grab.hitbox_half):
				_start_hold(holder, target, config)
				events.append({"type": "grab", "attacker": holder.id, "target": target.id, "pos": target.pos})
				break
	return events


static func step(fighters: Array[Fighter], inputs: Array[InputFrame], attacks: AttackSet,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for holder: Fighter in fighters:
		if holder.state != Fighter.State.HOLDING or holder.hitstop_ticks > 0:
			continue
		var target := find(fighters, holder.partner_id)
		if target == null or target.state != Fighter.State.HELD or target.partner_id != holder.id:
			continue  # cleanup() frees broken pairs
		var input := inputs[holder.id]
		var dir := Vector3(input.move_x, 0.0, input.move_z)
		if dir.length_squared() > 0.0:
			holder.facing = dir.normalized()
		_place(holder, target, config)
		if input.grab:
			events.append(_throw(holder, target, attacks.get_attack(AttackSet.Kind.THROW), config))
			continue
		holder.grab_ticks -= 1
		if holder.grab_ticks <= 0:
			_release(holder)
			_release(target)
			events.append({"type": "grab_release", "attacker": holder.id, "target": target.id, "pos": target.pos})
	return events


static func cleanup(fighters: Array[Fighter]) -> void:
	for f: Fighter in fighters:
		if f.state == Fighter.State.HOLDING or f.state == Fighter.State.HELD:
			var want := Fighter.State.HELD if f.state == Fighter.State.HOLDING else Fighter.State.HOLDING
			var partner := find(fighters, f.partner_id)
			if partner == null or partner.state != want or partner.partner_id != f.id:
				_release(f)
		elif f.partner_id != Fighter.NONE:
			f.partner_id = Fighter.NONE
			f.grab_ticks = 0


static func find(fighters: Array[Fighter], id: int) -> Fighter:
	for f: Fighter in fighters:
		if f.id == id:
			return f
	return null


static func _grabbable(holder: Fighter, target: Fighter) -> bool:
	return target != holder and target.is_alive() and target.invuln_ticks <= 0 \
			and target.state != Fighter.State.HOLDING and target.state != Fighter.State.HELD


static func _start_hold(holder: Fighter, target: Fighter, config: GameConfig) -> void:
	holder.set_state(Fighter.State.HOLDING)
	holder.partner_id = target.id
	holder.grab_ticks = SimTime.to_ticks(config.grab_hold_max_time)
	holder.hit_ids.clear()
	Actions.stop_horizontal(holder)
	target.set_state(Fighter.State.HELD)
	target.partner_id = holder.id
	target.vel = Vector3.ZERO
	target.hitstun_ticks = 0
	target.attack_ticks = 0
	target.charge_ticks = 0
	target.combo_queued = false
	target.hit_ids.clear()
	_place(holder, target, config)


static func _place(holder: Fighter, target: Fighter, config: GameConfig) -> void:
	target.pos = holder.pos + holder.facing * config.grab_hold_distance
	target.facing = -holder.facing


static func _throw(holder: Fighter, target: Fighter, throw_attack: AttackData, config: GameConfig) -> Dictionary:
	_release(holder)
	target.partner_id = Fighter.NONE
	var e := Combat.apply_hit(target, throw_attack, holder.facing, 1.0, config, target.pos, holder.id)
	e["attack_kind"] = AttackSet.Kind.THROW
	holder.hitstop_ticks = throw_attack.hitstop_ticks
	return e


static func _release(f: Fighter) -> void:
	f.partner_id = Fighter.NONE
	f.grab_ticks = 0
	f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)
```

- [ ] **Step 4: Actions에 잡기 (최우선)**

`src/sim/actions.gd` `try_start`의 가드 분기 앞에 추가, 우선순위 주석을 `grab > guard > heavy > light`로:
```gdscript
	if input.grab and f.on_ground:
		start_attack(f, AttackSet.Kind.GRAB)
		return true
```

- [ ] **Step 5: Motion — HOLDING/HELD**

`src/sim/motion.gd` `step`의 `match`에 GUARD 분기 다음으로 추가하고, `_integrate` 호출을 조건부로 바꾼다:
```gdscript
		Fighter.State.HOLDING, Fighter.State.HELD:
			pass  # Grab.step drives holds; the held fighter's position comes from the holder
		_:
			if not Actions.try_start(f, input, config):
				_step_control(f, input, config)
	if f.state != Fighter.State.HELD:
		_integrate(f, config)
	f.state_ticks += 1
```

- [ ] **Step 6: Rules — 행동 필드 초기화**

`src/sim/rules.gd`에 함수 추가하고 `respawn`과 KO 분기에서 호출:
```gdscript
## Resets attack, charge, combo and grab bookkeeping (respawn and KO).
static func clear_actions(f: Fighter) -> void:
	f.hitstun_ticks = 0
	f.hitstop_ticks = 0
	f.attack_ticks = 0
	f.hit_ids.clear()
	f.combo_queued = false
	f.charge_ticks = 0
	f.charge_mul = 1.0
	f.grab_ticks = 0
	f.partner_id = Fighter.NONE
```
`respawn`에서 `f.hitstun_ticks = 0` ~ `f.hit_ids.clear()` 네 줄을 `clear_actions(f)` 한 줄로 교체. `apply`의 KO 분기:
```gdscript
		else:
			f.vel = Vector3.ZERO
			clear_actions(f)
			f.set_state(Fighter.State.KO)
```

- [ ] **Step 7: World — 입력 정리 + Grab 호출**

`src/sim/world.gd`의 `tick` 본문을 교체하고 `_resolve_inputs` 추가:
```gdscript
func tick(inputs: Array[InputFrame]) -> void:
	_events = []
	if not match_over:
		var attacks := AttackSet.from_config(config)
		var frame := _resolve_inputs(inputs)
		for f: Fighter in fighters:
			Motion.step(f, frame[f.id], config, attacks)
		Motion.separate(fighters, config)
		_events.append_array(Grab.step(fighters, frame, attacks, config))
		_events.append_array(Grab.resolve(fighters, attacks, config))
		_events.append_array(Combat.resolve(fighters, attacks, config))
		_events.append_array(Rules.apply(fighters, config))
		Grab.cleanup(fighters)
		var result := Rules.winner(fighters)
		if result != Rules.ONGOING:
			match_over = true
			winner_id = result
	tick_count += 1


## One input per fighter id (copies, so later steps may clear consumed buttons without touching
## the caller's frames); missing entries are neutral.
func _resolve_inputs(inputs: Array[InputFrame]) -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	for f: Fighter in fighters:
		out.append(inputs[f.id].copy() if f.id < inputs.size() else InputFrame.neutral())
	return out
```
파일 머리 주석 4행(Tick order)을 `## Tick order: Motion.step per fighter -> separate -> Grab.step -> Grab.resolve -> Combat.resolve -> Rules.apply -> Grab.cleanup -> winner.`으로 갱신.

- [ ] **Step 8: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS, `GOLDEN_HASH` 그대로 (스크립트에 grab 입력 없음. 바뀌면 멈추고 보고).

- [ ] **Step 9: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/grab.gd src/sim/grab.gd.uid src/sim/actions.gd src/sim/motion.gd src/sim/rules.gd src/sim/world.gd tests/unit/test_grab.gd tests/unit/test_grab.gd.uid tests/unit/test_rules.gd
git commit -m "feat: add grab, hold and directional throw" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 아이템 엔티티 + 상자 생성기 + 낙하 (snapshot v4)

**Files:**
- Create: `src/sim/item.gd`, `src/sim/item_field.gd`, `src/sim/item_motion.gd`
- Modify: `src/sim/world.gd` (`items`, 틱 순서, snapshot v4, `state_view().items`)
- Modify: `tests/replay/test_replay.gd` (`GOLDEN_HASH` — 생성 스케줄이 RNG를 쓰고 스냅샷에 들어감)
- Test: `tests/unit/test_items.gd` (신규)

**Interfaces:**
- Consumes: `World._rng`, T6 `World.tick` 구조, `Collision.on_arena_floor`
- Produces:
  - `Item.Kind { BAT, BOMB, ROCK }`, `Item.KIND_COUNT := 3`, `Item.State { FALLING, GROUND, THROWN }`, `Item.UNLIT := -1`
  - Item 필드: `id: int`, `kind: int`, `state: int`, `pos: Vector3`, `vel: Vector3`, `uses: int`, `fuse_ticks: int = UNLIT`, `owner_id: int = Fighter.NONE`
  - `func Item.is_pickable() -> bool` (GROUND이고 불 안 붙음), `to_view()`, `to_data()`, `static from_data(d) -> Item`(잘못되면 null)
  - `ItemField`: `var items: Array[Item]`, `var next_spawn_tick: int`, `var next_id: int`, `func spawn_step(tick: int, rng: RandomNumberGenerator, config: GameConfig) -> Array[Dictionary]` (이벤트 `{"type": "item_spawn", "id", "kind", "pos"}`), `func add(kind: int, pos: Vector3, state: int, config: GameConfig) -> Item`, `func remove(it: Item) -> void`, `func views() -> Array[Dictionary]`, `func to_data() -> Dictionary`, `static func from_data(d: Dictionary) -> ItemField`
  - `static func ItemMotion.step(field: ItemField, fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]` — 이벤트 `{"type": "item_land", "id", "kind", "pos"}`
  - `World.items: ItemField` (공개), `state_view()["items"]: Array[Dictionary]` (각 `{"id", "kind", "state", "pos", "uses", "fuse_ticks"}`)
  - `World.SNAPSHOT_VERSION := 4`, 스냅샷 키 `"items": TYPE_DICTIONARY` (ItemField.to_data)
- 근거: `[PRD-ITEM-01]` `[PRD-ARCH-05]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_items.gd`:
```gdscript
extends GutTest
## Item boxes (context E6, E8). PHASES test: same seed -> same drop positions and times.

const LONG_RUN := 3000


func _idle(w: World, ticks: int) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var none: Array[InputFrame] = []
	for i: int in ticks:
		w.tick(none)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "item_spawn":
				var s := e.duplicate()
				s["tick"] = w.tick_count
				spawns.append(s)
	return spawns


func test_same_seed_same_drops() -> void:
	var a := _idle(World.new(GameConfig.new(), 11), LONG_RUN)
	var b := _idle(World.new(GameConfig.new(), 11), LONG_RUN)
	assert_gt(a.size(), 1, "several boxes fall in 50 s")
	assert_eq(a, b)


func test_other_seed_other_drops() -> void:
	assert_ne(_idle(World.new(GameConfig.new(), 11), LONG_RUN), _idle(World.new(GameConfig.new(), 12), LONG_RUN))


func test_first_drop_inside_the_spawn_window_and_area() -> void:
	var c := GameConfig.new()
	var spawns := _idle(World.new(c, 3), SimTime.to_ticks(c.item_spawn_max_time) + 2)
	assert_eq(spawns.size(), 1)
	var s := spawns[0]
	assert_between(int(s["tick"]), SimTime.to_ticks(c.item_spawn_min_time), SimTime.to_ticks(c.item_spawn_max_time) + 1)
	var p: Vector3 = s["pos"]
	assert_almost_eq(p.y, c.item_drop_height, 0.0001)
	assert_lte(Vector2(p.x, p.z).length(), c.arena_radius * c.item_spawn_radius_ratio + 0.0001)
	assert_between(int(s["kind"]), 0, Item.KIND_COUNT - 1)


func test_field_never_exceeds_the_cap() -> void:
	var c := GameConfig.new()
	c.item_max_on_field = 1
	var w := World.new(c, 5)
	var none: Array[InputFrame] = []
	for i: int in LONG_RUN:
		w.tick(none)
		assert_lte(w.items.items.size(), 1)


func test_box_falls_for_about_a_second_then_lands() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var it := w.items.add(Item.Kind.ROCK, Vector3(2, c.item_drop_height, 0), Item.State.FALLING, c)
	var landed_at := -1
	var none: Array[InputFrame] = []
	for i: int in 120:
		w.tick(none)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "item_land" and int(e["id"]) == it.id:
				landed_at = i + 1
	assert_between(landed_at, 55, 65, "12 m at -25 m/s^2 is about 0.98 s")
	assert_eq(it.state, Item.State.GROUND)
	assert_eq(it.pos, Vector3(2, 0, 0))
	assert_true(it.is_pickable())


func test_bat_starts_with_full_uses() -> void:
	var c := GameConfig.new()
	var field := ItemField.new()
	assert_eq(field.add(Item.Kind.BAT, Vector3.ZERO, Item.State.GROUND, c).uses, c.bat_uses)
	assert_eq(field.add(Item.Kind.ROCK, Vector3.ZERO, Item.State.GROUND, c).id, 1, "ids increase")


func test_item_data_round_trip_and_validation() -> void:
	var c := GameConfig.new()
	var field := ItemField.new()
	var it := field.add(Item.Kind.BOMB, Vector3(1, 2, 3), Item.State.THROWN, c)
	it.vel = Vector3(4, 5, 6)
	it.fuse_ticks = 30
	it.owner_id = 1
	var copy := Item.from_data(it.to_data())
	assert_eq(copy.to_data(), it.to_data())
	var bad := it.to_data()
	bad["fuse_ticks"] = "soon"
	assert_null(Item.from_data(bad))
	var restored := ItemField.from_data(field.to_data())
	assert_eq(restored.to_data(), field.to_data())


func test_restore_mid_run_continues_identically() -> void:
	var c := GameConfig.new()
	var a := World.new(c, 9)
	_idle(a, 1000)
	var snap := a.snapshot()
	var b := World.new(c, 9)
	assert_true(b.restore(snap))
	assert_eq(_idle(a, 1500), _idle(b, 1500), "item field and spawn schedule are part of the snapshot")


func test_state_view_items_are_copies() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var it := w.items.add(Item.Kind.BAT, Vector3(1, 0, 1), Item.State.GROUND, c)
	var view: Array = w.state_view()["items"]
	it.pos = Vector3(9, 9, 9)
	assert_eq((view[0] as Dictionary)["pos"], Vector3(1, 0, 1))
	assert_eq((view[0] as Dictionary)["kind"], Item.Kind.BAT)
	assert_false((view[0] as Dictionary).has("vel"), "views carry what renderers need")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_items`
Expected: FAIL — `Identifier "Item" not declared`

- [ ] **Step 3: Item 작성**

`src/sim/item.gd`:
```gdscript
class_name Item
extends RefCounted
## One loose item (PRD §4.4, context E6): a box falling from the sky, lying on the ground, or
## flying after a throw. Picking an item up removes it from the field; the fighter then carries
## its kind and uses (Fighter.item_kind / item_uses) until it throws, drops or loses it.

enum Kind { BAT, BOMB, ROCK }
enum State { FALLING, GROUND, THROWN }

const KIND_COUNT := 3
const UNLIT := -1
const DATA_TYPES := {
	"id": TYPE_INT, "kind": TYPE_INT, "state": TYPE_INT, "pos": TYPE_VECTOR3, "vel": TYPE_VECTOR3,
	"uses": TYPE_INT, "fuse_ticks": TYPE_INT, "owner_id": TYPE_INT,
}

var id: int = 0
var kind: int = Kind.BAT
var state: int = State.FALLING
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
## Swings left (bats).
var uses: int = 0
## Ticks until a lit bomb explodes, or UNLIT.
var fuse_ticks: int = UNLIT
## The fighter who threw it (its own projectile never hits it), or Fighter.NONE.
var owner_id: int = Fighter.NONE


func is_pickable() -> bool:
	return state == State.GROUND and fuse_ticks == UNLIT


func to_view() -> Dictionary:
	return {"id": id, "kind": kind, "state": state, "pos": pos, "uses": uses, "fuse_ticks": fuse_ticks}


func to_data() -> Dictionary:
	var d := {}
	for key: String in DATA_TYPES:
		d[key] = get(key)
	return d


static func from_data(d: Dictionary) -> Item:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	var it := Item.new()
	for key: String in DATA_TYPES:
		it.set(key, d[key])
	return it
```

- [ ] **Step 4: ItemField 작성**

`src/sim/item_field.gd`:
```gdscript
class_name ItemField
extends RefCounted
## Loose items plus the box spawner (PRD §4.4, context E6/E8). The spawner is the only user of
## the World RNG and always draws in the same order: next spawn tick, angle, radius, kind. When
## the field is full the drop is skipped but the next one is still scheduled.

const NOT_SCHEDULED := -1

var items: Array[Item] = []
var next_spawn_tick: int = NOT_SCHEDULED
var next_id: int = 0


func spawn_step(tick: int, rng: RandomNumberGenerator, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if next_spawn_tick == NOT_SCHEDULED:
		next_spawn_tick = tick + _interval(rng, config)
		return events
	if tick < next_spawn_tick:
		return events
	next_spawn_tick = tick + _interval(rng, config)
	if items.size() >= config.item_max_on_field:
		return events
	var angle := rng.randf() * TAU
	var r := sqrt(rng.randf()) * config.arena_radius * config.item_spawn_radius_ratio
	var kind := rng.randi_range(0, Item.KIND_COUNT - 1)
	var it := add(kind, Vector3(cos(angle) * r, config.item_drop_height, sin(angle) * r), Item.State.FALLING, config)
	events.append({"type": "item_spawn", "id": it.id, "kind": kind, "pos": it.pos})
	return events


func add(kind: int, pos: Vector3, state: int, config: GameConfig) -> Item:
	var it := Item.new()
	it.id = next_id
	next_id += 1
	it.kind = kind
	it.state = state
	it.pos = pos
	it.uses = config.bat_uses if kind == Item.Kind.BAT else 1
	items.append(it)
	return it


func remove(it: Item) -> void:
	items.erase(it)


func views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Item in items:
		out.append(it.to_view())
	return out


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for it: Item in items:
		list.append(it.to_data())
	return {"items": list, "next_spawn_tick": next_spawn_tick, "next_id": next_id}


static func from_data(d: Dictionary) -> ItemField:
	if typeof(d.get("items")) != TYPE_ARRAY or typeof(d.get("next_spawn_tick")) != TYPE_INT \
			or typeof(d.get("next_id")) != TYPE_INT:
		return null
	var field := ItemField.new()
	for raw: Variant in d["items"]:
		var it: Item = Item.from_data(raw) if raw is Dictionary else null
		if it == null:
			return null
		field.items.append(it)
	field.next_spawn_tick = d["next_spawn_tick"]
	field.next_id = d["next_id"]
	return field


static func _interval(rng: RandomNumberGenerator, config: GameConfig) -> int:
	var lo := SimTime.to_ticks(config.item_spawn_min_time)
	return rng.randi_range(lo, maxi(SimTime.to_ticks(config.item_spawn_max_time), lo))
```

- [ ] **Step 5: ItemMotion 작성 (낙하만)**

`src/sim/item_motion.gd`:
```gdscript
class_name ItemMotion
extends RefCounted
## Loose item physics (PRD §4.4): falling boxes land on the arena floor and items that fall past
## kill_y are removed. Thrown items (Task 8) and bomb fuses (Task 9) extend _advance.

## Same landing rule as fighters (Motion.LAND_TOLERANCE): never snap up from under the floor.
const LAND_TOLERANCE := 0.05


static func step(field: ItemField, _fighters: Array[Fighter], _attacks: AttackSet,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Item] = []
	for it: Item in field.items:
		if _advance(it, config, events):
			keep.append(it)
	field.items = keep
	return events


## Moves one item; returns false when it is gone.
static func _advance(it: Item, config: GameConfig, events: Array[Dictionary]) -> bool:
	if it.state == Item.State.GROUND:
		return true
	var prev_y := it.pos.y
	it.vel.y += config.gravity * SimTime.TICK_DT
	it.pos += it.vel * SimTime.TICK_DT
	if _landed(it, prev_y, config):
		it.pos.y = 0.0
		it.vel = Vector3.ZERO
		it.state = Item.State.GROUND
		events.append({"type": "item_land", "id": it.id, "kind": it.kind, "pos": it.pos})
		return true
	return it.pos.y >= config.kill_y


static func _landed(it: Item, prev_y: float, config: GameConfig) -> bool:
	return Collision.on_arena_floor(it.pos, config.arena_radius) and it.pos.y <= 0.0 \
			and prev_y >= -LAND_TOLERANCE and it.vel.y <= 0.0
```

- [ ] **Step 6: World 통합**

`src/sim/world.gd`:
- `const SNAPSHOT_VERSION := 4`, `SNAPSHOT_TYPES`에 `"items": TYPE_DICTIONARY` 추가
- `var fighters: Array[Fighter] = []` 다음에 `var items: ItemField = ItemField.new()`
- `tick`의 `Combat.resolve` 다음 두 줄:
```gdscript
		_events.append_array(ItemMotion.step(items, fighters, attacks, config))
		_events.append_array(items.spawn_step(tick_count, _rng, config))
```
- `state_view()` 딕셔너리에 `"items": items.views(),`
- `snapshot()` 딕셔너리에 `"items": items.to_data(),`
- `restore()`에서 fighters 검증 뒤, 상태 대입 전에:
```gdscript
	var restored_items := ItemField.from_data(s["items"])
	if restored_items == null:
		push_error("World.restore: invalid item data")
		return false
```
  그리고 대입부에 `items = restored_items`
- 머리 주석의 Tick order에 `-> ItemMotion.step -> ItemField.spawn_step`을 Combat.resolve 뒤에 넣고, `Snapshot v4 adds the item field.`를 덧붙인다

- [ ] **Step 7: 테스트 + 골든**

Run: `./scripts/test.sh`
Expected: `test_items` 9개 PASS, `test_golden_hash`만 FAIL. 출력 값으로 `GOLDEN_HASH` 갱신 → 전부 PASS. (`tests/unit/test_world.gd`의 스냅샷 거부 테스트는 `World.SNAPSHOT_VERSION`을 참조하므로 그대로 통과해야 한다.)

- [ ] **Step 8: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/item.gd src/sim/item.gd.uid src/sim/item_field.gd src/sim/item_field.gd.uid src/sim/item_motion.gd src/sim/item_motion.gd.uid src/sim/world.gd tests/unit/test_items.gd tests/unit/test_items.gd.uid tests/replay/test_replay.gd
git commit -m "feat: add seeded item boxes that fall into the arena" -m "GOLDEN_HASH regenerated: the box spawner draws from the world RNG and snapshot v4 stores the item field." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 줍기·사용·던지기·떨어뜨리기 (방망이 5회, 돌멩이 투사체)

**Files:**
- Create: `src/sim/item_actions.gd`
- Modify: `src/sim/item_motion.gd` (던진 아이템 명중·깨짐), `src/sim/actions.gd` (방망이 휘두르기), `src/sim/rules.gd` (`clear_actions`에 아이템 필드), `src/sim/world.gd` (pre_step, drop 호출)
- Test: `tests/unit/test_item_use.gd` (신규)

**Interfaces:**
- Consumes: T7 `ItemField`/`Item`, T6 `World._resolve_inputs`/`Rules.clear_actions`, T5 `Combat.apply_hit`
- Produces:
  - `static func ItemActions.pre_step(fighters: Array[Fighter], inputs: Array[InputFrame], field: ItemField, config: GameConfig) -> Array[Dictionary]` — 이벤트 `item_pickup {"id", "kind", "fighter", "pos"}`, `item_throw {"id", "kind", "fighter", "pos"}`. 쓴 버튼은 `inputs[i]`(사본)에서 false로
  - `static func ItemActions.drop_from_disabled(fighters: Array[Fighter], field: ItemField, config: GameConfig) -> Array[Dictionary]` — HITSTUN·HELD 파이터의 아이템을 FALLING으로 떨어뜨림, 이벤트 `item_drop {"id", "kind", "fighter", "pos"}`
  - `static func ItemActions.nearest_pickable(field: ItemField, pos: Vector3, radius: float) -> Item` (수평 거리, 동률이면 id가 작은 것, 없으면 null)
  - `ItemActions.HAND_HEIGHT_RATIO := 0.6` (손 높이 = fighter_height × 0.6)
  - `ItemMotion` 던진 돌멩이·방망이: 첫 상대에게 `hit` 이벤트(`attack_kind` = ROCK, `item_kind`) 후 사라짐, 땅에 닿으면 `item_break {"id", "kind", "pos"}` 후 사라짐. 던진 폭탄은 몸에 닿으면 수평 속도 0, 땅에 닿으면 GROUND (불은 T9)
  - `Actions.try_start`: 방망이를 들고 약공격 → `AttackSet.Kind.BAT`, `item_uses` 1 감소, 0이 되면 `item_kind = NONE` (E7)
- 근거: `[PRD-ITEM-01]` `[PRD-ITEM-02]` `[PRD-ITEM-04]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_item_use.gd`:
```gdscript
extends GutTest
## Picking up, using, throwing and dropping items (context E6, E7).
## PHASES test: a bat disappears after 5 uses.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _grab() -> InputFrame:
	return InputFrame.make(0, 0, false, false, false, false, true)


func _light() -> InputFrame:
	return InputFrame.make(0, 0, false, true)


func _world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 8)  # out of the way
	return w


func _events_of(w: World, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == type:
			out.append(e)
	return out


func test_grab_near_an_item_picks_it_up() -> void:
	var w := _world()
	var it := w.items.add(Item.Kind.ROCK, w.fighters[0].pos + Vector3(0.5, 0, 0), Item.State.GROUND, w.config)
	w.tick(_inputs(_grab()))
	var f := w.fighters[0]
	assert_eq(f.item_kind, Item.Kind.ROCK)
	assert_eq(w.items.items.size(), 0)
	assert_eq(_events_of(w, "item_pickup").size(), 1)
	assert_eq(_events_of(w, "item_pickup")[0]["id"], it.id)
	assert_ne(f.state, Fighter.State.ATTACK, "the grab press was spent on the pickup, not a grab attempt")


func test_grab_with_no_item_in_reach_is_a_grab_attempt() -> void:
	var w := _world()
	w.items.add(Item.Kind.ROCK, w.fighters[0].pos + Vector3(3, 0, 0), Item.State.GROUND, w.config)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.GRAB)


func test_nearest_item_wins_and_lit_bombs_are_not_pickable() -> void:
	var w := _world()
	var c := w.config
	var p := w.fighters[0].pos
	var lit := w.items.add(Item.Kind.BOMB, p + Vector3(0.2, 0, 0), Item.State.GROUND, c)
	lit.fuse_ticks = 60
	w.items.add(Item.Kind.BAT, p + Vector3(0.9, 0, 0), Item.State.GROUND, c)
	w.items.add(Item.Kind.ROCK, p + Vector3(0.5, 0, 0), Item.State.GROUND, c)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].item_kind, Item.Kind.ROCK)


func test_bat_breaks_after_five_swings() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = c.bat_uses
	var swing := c.bat_startup_ticks + c.bat_active_ticks + c.bat_recovery_ticks
	for n: int in c.bat_uses:
		w.tick(_inputs(_light()))
		assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.BAT, "swing %d" % (n + 1))
		for i: int in swing:
			w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE, "the fifth swing used the bat up")
	w.tick(_inputs(_light()))
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_1, "back to bare hands")


func test_bat_swing_hits_with_bat_numbers() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = c.bat_uses
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.tick(_inputs(_light()))
	for i: int in c.bat_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[1].damage, c.bat_damage)


func test_grab_throws_a_rock_that_hits_the_first_fighter() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.fighters[0].item_uses = 1
	w.fighters[1].pos = w.fighters[0].pos + Vector3(3, 0, 0)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(_events_of(w, "item_throw").size(), 1)
	var thrown := w.items.items[0]
	assert_eq(thrown.state, Item.State.THROWN)
	assert_eq(thrown.owner_id, 0)
	assert_gt(thrown.vel.x, 0.0)
	var hit: Dictionary = {}
	for i: int in 60:
		w.tick(_inputs(InputFrame.neutral()))
		for e: Dictionary in _events_of(w, "hit"):
			hit = e
		if not hit.is_empty():
			break
	assert_false(hit.is_empty(), "the rock reaches the fighter 3 m ahead")
	assert_eq(hit["attack_kind"], AttackSet.Kind.ROCK)
	assert_eq(hit["attacker"], 0)
	assert_eq(w.fighters[1].damage, c.rock_damage)
	assert_eq(w.items.items.size(), 0, "a rock is gone after its hit")


func test_light_with_a_rock_also_throws() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.fighters[0].item_uses = 1
	w.tick(_inputs(_light()))
	assert_eq(_events_of(w, "item_throw").size(), 1)
	assert_ne(w.fighters[0].state, Fighter.State.ATTACK, "the light press was spent on the throw")


func test_throw_follows_the_move_input() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.tick(_inputs(InputFrame.make(0, -1, false, false, false, false, true)))
	assert_lt(w.items.items[0].vel.z, 0.0)
	assert_eq(w.fighters[0].facing, Vector3(0, 0, -1))


func test_missed_rock_breaks_on_the_ground() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.tick(_inputs(_grab()))
	var broke := false
	for i: int in 90:
		w.tick(_inputs(InputFrame.neutral()))
		if not _events_of(w, "item_break").is_empty():
			broke = true
	assert_true(broke)
	assert_eq(w.items.items.size(), 0)


func test_thrown_bomb_lands_and_stays() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.BOMB
	w.tick(_inputs(_grab()))
	for i: int in 40:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.items.items.size(), 1)
	assert_eq(w.items.items[0].state, Item.State.GROUND)
	assert_gt(w.items.items[0].fuse_ticks, 0, "lit on throw")
	assert_false(w.items.items[0].is_pickable())


func test_getting_hit_drops_the_item() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[1].facing = Vector3(-1, 0, 0)
	w.tick(_inputs(InputFrame.neutral(), _light()))
	for i: int in c.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.HITSTUN)
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(w.items.items.size(), 1)
	assert_eq(w.items.items[0].state, Item.State.FALLING)
	assert_eq(w.items.items[0].kind, Item.Kind.ROCK)


func test_ring_out_loses_the_item() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = 3
	w.fighters[0].pos = Vector3(0, w.config.kill_y - 1, 0)
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(w.fighters[0].item_uses, 0)
	assert_eq(w.items.items.size(), 0)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_item_use`
Expected: FAIL — 줍기가 없어 `item_kind`가 NONE, 방망이는 LIGHT_1로 나감

- [ ] **Step 3: ItemActions 작성**

`src/sim/item_actions.gd`:
```gdscript
class_name ItemActions
extends RefCounted
## Item handling before movement (PRD §4.4, context E6). A fighter that can act and presses grab
## on the ground next to a pickable item picks it up. With an item in hand, grab throws it and
## light uses it: bats swing (Actions.try_start), bombs and rocks are thrown. Buttons spent here
## are cleared from that fighter's input copy so Actions does not act on them too.

## Items are held and thrown from this fraction of the fighter height.
const HAND_HEIGHT_RATIO := 0.6


static func pre_step(fighters: Array[Fighter], inputs: Array[InputFrame], field: ItemField,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if not f.can_act() or f.hitstop_ticks > 0:
			continue
		var input := inputs[f.id]
		if f.item_kind != Fighter.NONE:
			if input.grab or (input.light and f.item_kind != Item.Kind.BAT):
				events.append(_throw(f, input, field, config))
				input.grab = false
				input.light = false
		elif input.grab and f.on_ground:
			var it := nearest_pickable(field, f.pos, config.item_pickup_radius)
			if it != null:
				f.item_kind = it.kind
				f.item_uses = it.uses
				field.remove(it)
				events.append({"type": "item_pickup", "id": it.id, "kind": it.kind, "fighter": f.id, "pos": it.pos})
				input.grab = false
	return events


## A fighter knocked into hitstun or grabbed lets go of its item, which falls where it stands.
static func drop_from_disabled(fighters: Array[Fighter], field: ItemField, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if f.item_kind == Fighter.NONE:
			continue
		if f.state != Fighter.State.HITSTUN and f.state != Fighter.State.HELD:
			continue
		var it := field.add(f.item_kind, _hand(f, config), Item.State.FALLING, config)
		it.uses = f.item_uses
		f.item_kind = Fighter.NONE
		f.item_uses = 0
		events.append({"type": "item_drop", "id": it.id, "kind": it.kind, "fighter": f.id, "pos": it.pos})
	return events


static func nearest_pickable(field: ItemField, pos: Vector3, radius: float) -> Item:
	var best: Item = null
	var best_dist := radius
	for it: Item in field.items:
		if not it.is_pickable():
			continue
		var d := Vector2(it.pos.x - pos.x, it.pos.z - pos.z).length()
		if d <= best_dist and (best == null or d < best_dist or it.id < best.id):
			best = it
			best_dist = d
	return best


static func _throw(f: Fighter, input: InputFrame, field: ItemField, config: GameConfig) -> Dictionary:
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	if dir.length_squared() > 0.0:
		f.facing = dir.normalized()
	var start := _hand(f, config) + f.facing * (config.fighter_radius + config.item_radius)
	var it := field.add(f.item_kind, start, Item.State.THROWN, config)
	it.uses = f.item_uses
	it.vel = f.facing * config.item_throw_speed + Vector3.UP * config.item_throw_up
	it.owner_id = f.id
	if it.kind == Item.Kind.BOMB:
		it.fuse_ticks = SimTime.to_ticks(config.bomb_fuse_time)
	f.item_kind = Fighter.NONE
	f.item_uses = 0
	return {"type": "item_throw", "id": it.id, "kind": it.kind, "fighter": f.id, "pos": start}


static func _hand(f: Fighter, config: GameConfig) -> Vector3:
	return f.pos + Vector3.UP * (config.fighter_height * HAND_HEIGHT_RATIO)
```

- [ ] **Step 4: ItemMotion — 던진 아이템**

`src/sim/item_motion.gd`의 `step`과 `_advance`를 교체하고 함수 두 개를 추가한다 (`_landed`는 그대로). 머리 주석의 두 번째 문장을 `Thrown rocks and bats hit the first fighter they touch (never their thrower) and break on the ground; thrown bombs stop on bodies and land (context E7).`로 바꾼다:
```gdscript
static func step(field: ItemField, fighters: Array[Fighter], attacks: AttackSet,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Item] = []
	for it: Item in field.items:
		if _advance(it, fighters, attacks, config, events):
			keep.append(it)
	field.items = keep
	return events


## Moves one item; returns false when it is gone.
static func _advance(it: Item, fighters: Array[Fighter], attacks: AttackSet, config: GameConfig,
		events: Array[Dictionary]) -> bool:
	if it.state == Item.State.GROUND:
		return true
	var prev_y := it.pos.y
	it.vel.y += config.gravity * SimTime.TICK_DT
	it.pos += it.vel * SimTime.TICK_DT
	if it.state == Item.State.THROWN:
		var target := _first_hit(it, fighters, config)
		if target != null:
			if it.kind == Item.Kind.BOMB:
				it.vel.x = 0.0
				it.vel.z = 0.0
			else:
				events.append(_projectile_hit(it, target, attacks.get_attack(AttackSet.Kind.ROCK), config))
				return false
	if _landed(it, prev_y, config):
		if it.state == Item.State.THROWN and it.kind != Item.Kind.BOMB:
			events.append({"type": "item_break", "id": it.id, "kind": it.kind, "pos": it.pos})
			return false
		it.pos.y = 0.0
		it.vel = Vector3.ZERO
		it.state = Item.State.GROUND
		events.append({"type": "item_land", "id": it.id, "kind": it.kind, "pos": it.pos})
		return true
	return it.pos.y >= config.kill_y


static func _first_hit(it: Item, fighters: Array[Fighter], config: GameConfig) -> Fighter:
	var half := Vector3.ONE * config.item_radius
	for f: Fighter in fighters:
		if f.id == it.owner_id or not f.is_alive() or f.invuln_ticks > 0:
			continue
		if Collision.capsule_hits_box(f.pos, config.fighter_radius, config.fighter_height, it.pos, 0.0, half):
			return f
	return null


static func _projectile_hit(it: Item, target: Fighter, attack: AttackData, config: GameConfig) -> Dictionary:
	var e := Combat.apply_hit(target, attack, Vector3(it.vel.x, 0.0, it.vel.z), 1.0, config, it.pos, it.owner_id)
	e["attack_kind"] = AttackSet.Kind.ROCK
	e["item_kind"] = it.kind
	return e
```

- [ ] **Step 5: Actions — 방망이**

`src/sim/actions.gd` `try_start`의 약공격 분기를 교체:
```gdscript
	if input.light:
		if f.item_kind == Item.Kind.BAT:
			start_attack(f, AttackSet.Kind.BAT)
			f.item_uses -= 1
			if f.item_uses <= 0:
				f.item_kind = Fighter.NONE
				f.item_uses = 0
		else:
			start_attack(f, AttackSet.Kind.LIGHT_1)
		return true
```

- [ ] **Step 6: Rules — 링아웃하면 아이템을 잃음**

`src/sim/rules.gd` `clear_actions` 끝에 추가, 주석에 `and the carried item`을 덧붙인다:
```gdscript
	f.item_kind = Fighter.NONE
	f.item_uses = 0
```

- [ ] **Step 7: World — 호출 추가**

`src/sim/world.gd` `tick`에서:
- `var frame := _resolve_inputs(inputs)` 다음 줄에 `_events.append_array(ItemActions.pre_step(fighters, frame, items, config))`
- `Grab.cleanup(fighters)` 다음 줄에 `_events.append_array(ItemActions.drop_from_disabled(fighters, items, config))`
- 머리 주석 Tick order를 `ItemActions.pre_step -> Motion.step per fighter -> separate -> Grab.step -> Grab.resolve -> Combat.resolve -> ItemMotion.step -> ItemField.spawn_step -> Rules.apply -> Grab.cleanup -> ItemActions.drop_from_disabled -> winner.`로 갱신

- [ ] **Step 8: 테스트**

Run: `./scripts/test.sh`
Expected: `test_item_use` 13개 PASS, 나머지 PASS. `GOLDEN_HASH`는 리플레이 600틱 안에 상자가 착지해도 줍기 입력이 없으면 그대로여야 한다 — 바뀌면 원인을 확인한다 (예: 스크립트의 light 입력으로 줍기가 일어나지는 않음. 원인이 설명되면 갱신하고 커밋 메시지에 이유).

- [ ] **Step 9: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/item_actions.gd src/sim/item_actions.gd.uid src/sim/item_motion.gd src/sim/actions.gd src/sim/rules.gd src/sim/world.gd tests/unit/test_item_use.gd tests/unit/test_item_use.gd.uid
git commit -m "feat: pick up, swing, throw and drop items" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: 폭탄 도화선 + 범위 폭발

**Files:**
- Modify: `src/sim/item_motion.gd` (도화선 감소, `_explode`)
- Test: `tests/unit/test_bomb.gd` (신규)

**Interfaces:**
- Consumes: T8 `ItemMotion`, `ItemActions` (던질 때 `fuse_ticks = to_ticks(bomb_fuse_time)`), T5 `Combat.apply_hit`
- Produces: 이벤트 `{"type": "explosion", "id", "pos", "radius"}` + 반경 안 파이터마다 `hit`/`guard_hit` (`attack_kind` = BOMB). 폭탄은 폭발 후 사라진다. 던진 틱을 1틱째로 세어 120틱째에 터진다 (E7)
- 근거: `[PRD-ITEM-03]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_bomb.gd`:
```gdscript
extends GutTest
## Bombs (context E7). PHASES test: explodes 120 ticks after the throw and hits only inside its radius.


func _neutral() -> Array[InputFrame]:
	var a: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	return a


func _explosions(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == "explosion":
			out.append(e)
	return out


## A lit bomb on the ground at the arena center that explodes on the next tick.
func _armed_world() -> World:
	var w := World.new(GameConfig.new(), 1)
	var bomb := w.items.add(Item.Kind.BOMB, Vector3.ZERO, Item.State.GROUND, w.config)
	bomb.fuse_ticks = 1
	return w


func test_thrown_bomb_explodes_on_the_120th_tick() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].item_kind = Item.Kind.BOMB
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 8)
	var throw: Array[InputFrame] = [InputFrame.make(0, 0, false, false, false, false, true), InputFrame.neutral()]
	w.tick(throw)
	var exploded_at := -1
	if not _explosions(w).is_empty():
		exploded_at = 1
	for t: int in range(2, 200):
		w.tick(_neutral())
		if exploded_at < 0 and not _explosions(w).is_empty():
			exploded_at = t
	assert_eq(exploded_at, 120, "the throw tick is tick 1")
	assert_eq(SimTime.to_ticks(w.config.bomb_fuse_time), 120)


func test_explosion_hits_only_inside_the_radius() -> void:
	var w := _armed_world()
	var c := w.config
	w.fighters[0].pos = Vector3(1.5, 0, 0)
	w.fighters[1].pos = Vector3(c.bomb_radius + c.fighter_radius + 1.0, 0, 0)
	w.tick(_neutral())
	assert_eq(_explosions(w).size(), 1)
	assert_eq(w.fighters[0].damage, c.bomb_damage)
	assert_eq(w.fighters[0].state, Fighter.State.HITSTUN)
	assert_eq(w.fighters[1].damage, 0.0, "outside the blast")
	assert_eq(w.items.items.size(), 0, "the bomb is gone")


func test_blast_pushes_away_from_the_bomb() -> void:
	var w := _armed_world()
	w.fighters[0].pos = Vector3(-1.0, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 1.0)
	w.tick(_neutral())
	assert_lt(w.fighters[0].vel.x, 0.0)
	assert_gt(w.fighters[1].vel.z, 0.0)
	assert_gt(w.fighters[0].vel.y, 0.0, "launched upward")


func test_thrower_is_not_safe() -> void:
	var w := _armed_world()
	w.items.items[0].owner_id = 0
	w.fighters[0].pos = Vector3(1.0, 0, 0)
	w.tick(_neutral())
	assert_eq(w.fighters[0].damage, w.config.bomb_damage)


func test_guard_and_invulnerability_apply() -> void:
	var w := _armed_world()
	var c := w.config
	w.fighters[0].pos = Vector3(1.0, 0, 0)
	w.fighters[0].set_state(Fighter.State.GUARD)
	w.fighters[1].pos = Vector3(-1.0, 0, 0)
	w.fighters[1].invuln_ticks = 60
	var guard: Array[InputFrame] = [InputFrame.make(0, 0, false, false, false, true), InputFrame.neutral()]
	w.tick(guard)
	assert_almost_eq(w.fighters[0].damage, c.bomb_damage * c.guard_damage_mul, 0.0001)
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	assert_eq(w.fighters[1].damage, 0.0)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_bomb`
Expected: FAIL — 폭발 이벤트 없음

- [ ] **Step 3: 도화선 + 폭발**

`src/sim/item_motion.gd`의 `step` 루프를 교체하고 `_explode` 추가. 머리 주석 끝에 `Lit bombs count down every tick and explode at zero, hitting every fighter in bomb_radius, thrower included (context E7).`를 덧붙인다:
```gdscript
static func step(field: ItemField, fighters: Array[Fighter], attacks: AttackSet,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Item] = []
	for it: Item in field.items:
		if it.fuse_ticks > 0:
			it.fuse_ticks -= 1
			if it.fuse_ticks == 0:
				events.append_array(_explode(it, fighters, attacks.get_attack(AttackSet.Kind.BOMB), config))
				continue
		if _advance(it, fighters, attacks, config, events):
			keep.append(it)
	field.items = keep
	return events


static func _explode(it: Item, fighters: Array[Fighter], attack: AttackData, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = [{"type": "explosion", "id": it.id, "pos": it.pos, "radius": config.bomb_radius}]
	for f: Fighter in fighters:
		if not f.is_alive() or f.invuln_ticks > 0:
			continue
		var offset := f.pos + Vector3.UP * (config.fighter_height * 0.5) - it.pos
		if offset.length() > config.bomb_radius + config.fighter_radius:
			continue
		var dir := Vector3(offset.x, 0.0, offset.z)
		if dir.length() < Collision.EPSILON:
			dir = Collision.COINCIDENT_AXIS
		var e := Combat.apply_hit(f, attack, dir, 1.0, config, it.pos, it.owner_id)
		e["attack_kind"] = AttackSet.Kind.BOMB
		events.append(e)
	return events
```

- [ ] **Step 4: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS, `GOLDEN_HASH` 그대로.

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/sim/item_motion.gd tests/unit/test_bomb.gd tests/unit/test_bomb.gd.uid
git commit -m "feat: add bomb fuse and area explosion" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: 리플레이 회귀 갱신 — 1200틱 + 새 액션, 봇 대 봇 커버리지

**Files:**
- Modify: `tests/replay/test_replay.gd`
- Create: `tests/replay/test_bot_coverage.gd`

**Interfaces:**
- Consumes: T1~T9 sim 전체, `BotController` (Phase 1 버전 — T18에서 2단계로 올라가도 이 테스트는 골든이 없으므로 깨지지 않는다)
- Produces: 스크립트 입력 골든(sim 전용, E11), 봇 커버리지 테스트(결정성 + 이벤트 종류)
- 근거: `[PRD-ARCH-05]` · PHASES 완료 기준 "리플레이 회귀 테스트 갱신·통과"

- [ ] **Step 1: 리플레이 스크립트 확장**

`tests/replay/test_replay.gd` 수정:
- `const TICKS := 600` → `1200`, `const HALF := 300` → `600` (첫 상자가 10~15초 = 600~900틱에 떨어지므로 아이템이 스크립트 안에 들어오게)
- `_script_input` 교체:
```gdscript
## P0 walks back and forth with jumps, light presses, a held heavy every 4 s and grab presses;
## P1 walks at P0 with light presses, guards in bursts and grabs now and then. Deterministic
## functions of t only (no bot), so the golden hash guards the sim alone (context E11).
static func _script_input(player: int, t: int) -> InputFrame:
	if player == 0:
		var mx := 1.0 if floori(t / 150.0) % 2 == 0 else -1.0
		var heavy := t % 240 >= 200 and t % 240 < 230
		return InputFrame.make(mx, 0.0, t % 45 == 0, t % 20 == 10, heavy, false, t % 97 == 50)
	var mz := -0.1 if floori(t / 70.0) % 2 == 0 else 0.1
	var guard := t % 180 >= 120 and t % 180 < 150
	return InputFrame.make(-1.0, mz, t % 60 == 30, t % 25 == 5, false, guard, t % 131 == 70)
```
- `test_the_script_actually_fights`를 교체:
```gdscript
func test_the_script_exercises_phase_2_actions() -> void:
	var w := World.new(GameConfig.new(), SEED)
	var seen := {}
	for i: int in TICKS:
		w.tick(_inputs_at(w.tick_count))
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
			if e["type"] == "hit" and e.has("attack_kind"):
				seen["kind_%d" % int(e["attack_kind"])] = true
	for needed: String in ["hit", "item_spawn", "item_land"]:
		assert_true(seen.has(needed), "%s must happen, or the golden hash guards nothing" % needed)
	assert_true(seen.has("kind_%d" % AttackSet.Kind.LIGHT_1), "light combo exercised")
	assert_true(seen.has("guard_hit") or seen.has("kind_%d" % AttackSet.Kind.HEAVY) or seen.has("grab"),
			"at least one of guard, heavy or grab lands")
```

- [ ] **Step 2: 봇 커버리지 테스트 작성**

`tests/replay/test_bot_coverage.gd`:
```gdscript
extends GutTest
## Bot-vs-bot coverage (context E11). No golden hash (bot changes must not break it): two runs with
## the same seed must match tick for tick, and a long match must go through ring-outs, a KO and
## the Phase 2 event types. Covers the Phase 1 carry-over "replay never asserts ring-out/KO".

const SEED := 21
const MAX_TICKS := 60 * 60 * 4


static func _run(seed_value: int, ticks: int) -> Dictionary:
	var c := GameConfig.new()
	var w := World.new(c, seed_value)
	var bots: Array[BotController] = [BotController.new(0, c), BotController.new(1, c)]
	var hashes: Array[int] = []
	var seen := {}
	for i: int in ticks:
		var view := w.state_view()
		var inputs: Array[InputFrame] = [bots[0].sample(view), bots[1].sample(view)]
		w.tick(inputs)
		hashes.append(w.state_hash())
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
		if w.match_over:
			seen["match_over"] = true
			break
	return {"hash": hash(hashes), "seen": seen}


func test_bot_match_is_deterministic() -> void:
	assert_eq(_run(SEED, 1800)["hash"], _run(SEED, 1800)["hash"])


## Event types a bot match must go through. Task 18 (bot step 2) extends this list with
## ringout, item_pickup, guard_hit and grab, and adds the KO assertion.
const REQUIRED_EVENTS: Array[String] = ["hit", "item_spawn", "item_land"]


func test_bot_match_covers_required_events() -> void:
	var seen: Dictionary = _run(SEED, MAX_TICKS)["seen"]
	for needed: String in REQUIRED_EVENTS:
		assert_true(seen.has(needed), "%s never happened in a bot match" % needed)
```
(Phase 1 봇은 약공격을 한 번씩만 눌러 연결타만 나가므로 링아웃이 거의 없다. 링아웃·KO·줍기·가드·잡기 단언은 T18에서 봇 2단계와 함께 추가한다.)

- [ ] **Step 3: 실행 + 골든 갱신**

Run: `./scripts/test.sh -gselect=test_replay`
Expected: `test_golden_hash`만 FAIL(스크립트·틱 수 변경) — 출력 값으로 `GOLDEN_HASH` 갱신. `test_the_script_exercises_phase_2_actions`가 실패하면 어떤 이벤트가 빠졌는지 확인하고 스크립트의 주기 상수(97/131/240/180)를 조정해 해당 액션이 실제로 닿게 만든 뒤 골든을 다시 갱신한다 (조정값은 보고서에 기록).
Run: `./scripts/test.sh`
Expected: 전부 PASS.

- [ ] **Step 4: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add tests/replay/test_replay.gd tests/replay/test_bot_coverage.gd tests/replay/test_bot_coverage.gd.uid
git commit -m "test: extend replay regression to phase 2 actions and add bot coverage" -m "GOLDEN_HASH regenerated: 1200-tick script with heavy, guard and grab inputs." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: HoldLatch + 키보드 6액션

**Files:**
- Create: `src/input/hold_latch.gd`
- Modify: `src/input/local_input.gd`
- Test: `tests/unit/test_hold_latch.gd` (신규), `tests/unit/test_input_bindings.gd`

**Interfaces:**
- Consumes: Phase 1 `LocalInput`, `ButtonLatch`, `InputBindings.P1` (`p1_heavy`=K, `p1_guard`=L, `p1_grab`=U 이미 등록됨)
- Produces:
  - `HoldLatch`: `press() -> void`, `set_held(held: bool) -> void`, `consume() -> bool` (홀드 중 true, 한 번의 짧은 누름도 최소 1회 true), `clear() -> void`, `is_held() -> bool`
  - `LocalInput`: `press_grab() -> void`, `set_touch_heavy(held: bool) -> void`, `set_touch_guard(held: bool) -> void`; `sample()`이 7필드 전부 채움; `reset()`이 5개 래치 모두 비움
- 근거: `[PRD-CTL-01]` `[PRD-CTL-02]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_hold_latch.gd`:
```gdscript
extends GutTest
## Held buttons across frames and ticks (context E3).


func test_held_reads_true_every_tick() -> void:
	var h := HoldLatch.new()
	h.set_held(true)
	assert_true(h.consume())
	assert_true(h.consume())
	h.set_held(false)
	assert_false(h.consume())


func test_tap_between_ticks_still_reaches_one_tick() -> void:
	var h := HoldLatch.new()
	h.set_held(true)
	h.set_held(false)
	assert_true(h.consume(), "pressed and released inside one frame")
	assert_false(h.consume())


func test_press_marks_a_pending_tap() -> void:
	var h := HoldLatch.new()
	h.press()
	assert_true(h.consume())
	assert_false(h.consume())


func test_clear_drops_hold_and_pending() -> void:
	var h := HoldLatch.new()
	h.set_held(true)
	h.clear()
	assert_false(h.is_held())
	assert_false(h.consume())
```

`tests/unit/test_input_bindings.gd` 끝에 추가:
```gdscript


func test_keyboard_heavy_and_guard_are_held_levels() -> void:
	var local := LocalInput.new()
	await get_tree().process_frame
	Input.action_press("p1_heavy")
	Input.action_press("p1_guard")
	local.poll()
	var a := local.sample()
	var b := local.sample()
	assert_true(a.heavy and b.heavy, "heavy stays true while K is held")
	assert_true(a.guard and b.guard, "guard stays true while L is held")
	Input.action_release("p1_heavy")
	Input.action_release("p1_guard")
	await get_tree().process_frame
	local.poll()
	var c := local.sample()
	assert_false(c.heavy or c.guard)


func test_keyboard_grab_is_latched_once() -> void:
	var local := LocalInput.new()
	await get_tree().process_frame
	Input.action_press("p1_grab")
	local.poll()
	assert_true(local.sample().grab)
	assert_false(local.sample().grab, "a press reaches exactly one tick")


func test_touch_heavy_and_guard_feed_the_same_frame() -> void:
	var local := LocalInput.new()
	local.set_touch_heavy(true)
	local.set_touch_guard(true)
	var a := local.sample()
	assert_true(a.heavy and a.guard)
	local.set_touch_heavy(false)
	local.set_touch_guard(false)
	var b := local.sample()
	assert_false(b.heavy or b.guard)


func test_touch_grab_press() -> void:
	var local := LocalInput.new()
	local.press_grab()
	assert_true(local.sample().grab)


func test_reset_clears_every_latch() -> void:
	var local := LocalInput.new()
	local.press_grab()
	local.set_touch_heavy(true)
	local.set_touch_heavy(false)
	local.reset()
	var f := local.sample()
	assert_false(f.grab or f.heavy, "nothing latched before a restart fires in the new match")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_hold_latch`
Expected: FAIL — `Identifier "HoldLatch" not declared`

- [ ] **Step 3: HoldLatch 작성**

`src/input/hold_latch.gd`:
```gdscript
class_name HoldLatch
extends RefCounted
## A held button (heavy, guard) carried from rendered frames to sim ticks (context E3). consume()
## is true while the button is held, and also once for a press released before any tick ran, so
## a quick tap still reaches the sim as a one-tick hold.

var _held: bool = false
var _pending: bool = false


func press() -> void:
	_pending = true


func set_held(held: bool) -> void:
	if held and not _held:
		_pending = true
	_held = held


func consume() -> bool:
	var value := _held or _pending
	_pending = false
	return value


func clear() -> void:
	_held = false
	_pending = false


func is_held() -> bool:
	return _held
```

- [ ] **Step 4: LocalInput 6액션**

`src/input/local_input.gd` 교체:
```gdscript
class_name LocalInput
extends RefCounted
## Local player input (PRD §3.1-3.2): keyboard actions and touch controls -> one InputFrame per
## sim tick. Presses (jump, light, grab) are latched once per rendered frame and consumed per
## tick (Phase 1 D6); held buttons (heavy, guard) go through HoldLatch so a tap is never lost
## (context E3). Touch feeds the same latches through press_* / set_touch_*.

var _jump := ButtonLatch.new()
var _light := ButtonLatch.new()
var _grab := ButtonLatch.new()
var _heavy := HoldLatch.new()
var _guard := HoldLatch.new()
var _touch_heavy: bool = false
var _touch_guard: bool = false
## Set by TouchInput; when the stick is held it overrides the keyboard move vector.
var touch_stick: TouchStickModel = null
## Process frame of the last reset(); poll() ignores keys still "just pressed" in that frame.
var _reset_frame: int = -1


func poll() -> void:
	if Engine.get_process_frames() == _reset_frame:
		return
	if Input.is_action_just_pressed("p1_jump"):
		_jump.press()
	if Input.is_action_just_pressed("p1_light"):
		_light.press()
	if Input.is_action_just_pressed("p1_grab"):
		_grab.press()
	if Input.is_action_just_pressed("p1_heavy"):
		_heavy.press()
	if Input.is_action_just_pressed("p1_guard"):
		_guard.press()
	_heavy.set_held(Input.is_action_pressed("p1_heavy") or _touch_heavy)
	_guard.set_held(Input.is_action_pressed("p1_guard") or _touch_guard)


func press_jump() -> void:
	_jump.press()


func press_light() -> void:
	_light.press()


func press_grab() -> void:
	_grab.press()


func set_touch_heavy(held: bool) -> void:
	_touch_heavy = held
	_heavy.set_held(held or _key_held("p1_heavy"))


func set_touch_guard(held: bool) -> void:
	_touch_guard = held
	_guard.set_held(held or _key_held("p1_guard"))


## Drops any latched press (e.g. the Space that confirmed a restart also counts as p1_jump).
## Called from input handling, so the same frame's poll() must not re-latch the key.
func reset() -> void:
	_reset_frame = Engine.get_process_frames()
	_jump.consume()
	_light.consume()
	_grab.consume()
	_heavy.clear()
	_guard.clear()


func sample() -> InputFrame:
	var move := _move_vector()
	return InputFrame.make(move.x, move.y, _jump.consume(), _light.consume(),
			_heavy.consume(), _guard.consume(), _grab.consume())


func _move_vector() -> Vector2:
	if touch_stick != null and touch_stick.active():
		return touch_stick.vector()
	return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")


static func _key_held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)
```

- [ ] **Step 5: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS (Phase 1 `test_poll_in_the_same_frame_as_reset_is_ignored` 포함).

- [ ] **Step 6: 입력 지연 재측정**

Run: `godot --headless --path . -s res://scripts/measure_input_latency.gd`
Expected: Phase 1과 같은 2프레임 (≤ 3). 출력 한 줄을 보고서에 붙인다.

- [ ] **Step 7: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/input/hold_latch.gd src/input/hold_latch.gd.uid src/input/local_input.gd tests/unit/test_hold_latch.gd tests/unit/test_hold_latch.gd.uid tests/unit/test_input_bindings.gd
git commit -m "feat: wire all six keyboard actions with held-button latching" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: 터치 4버튼 — 탭/홀드 해석, 레이아웃 3안, safe area, cancel·포커스 처리

**Files:**
- Create: `src/input/attack_button_model.gd`, `src/input/touch_layout.gd`, `src/ui/safe_area.gd`
- Modify: `src/input/touch_input.gd` (전면 교체)
- Test: `tests/unit/test_attack_button_model.gd`, `tests/unit/test_touch_layout.gd` (신규), `tests/unit/test_touch_input.gd`

**Interfaces:**
- Consumes: T11 `LocalInput.press_grab`/`set_touch_heavy`/`set_touch_guard`, T1 `touch_layout`/`touch_side_diameter`, Phase 1 `TouchButton` v1(`set_state`, `contains`, `diameter`) + 이 태스크에서 추가하는 `set_diameter(d: float)`, `TouchStickModel`, `TouchStick`
- Produces:
  - `AttackButtonModel.new(threshold: float)`, `enum Result { NONE, LIGHT, HEAVY_RELEASE }`, `press(t: float)`, `is_down() -> bool`, `holding_heavy(t: float) -> bool`, `charge_time(t: float) -> float`, `release(t: float, canceled: bool = false) -> int`
  - `TouchLayout.Variant { ARC, DIAMOND, GRID }`, `TouchLayout.BUTTONS := ["attack", "jump", "guard", "grab"]`, `static func TouchLayout.centers(variant: int, safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary` (이름 → 중심 `Vector2`)
  - `static func SafeArea.rect(viewport: Viewport) -> Rect2` — 모바일은 기기 safe area를 뷰포트 좌표로 변환, 그 외는 뷰포트 전체 (T19 HUD도 사용)
  - `TouchInput`: `button_center(name: String) -> Vector2`, `attack_center()`, `jump_center()`, `stick_zone_point()`, `var time_override: float = -1.0` (테스트용 시계), `buttons() -> Dictionary` (이름 → `TouchButton`, T14·T19가 상태 표시에 사용), `attack_charge_time() -> float`
- 근거: `[PRD-CTL-03]` `[PRD-CTL-04]` `[DS-LAY-01]` · Phase 1 이월(터치 cancel·포커스, safe area)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_attack_button_model.gd`:
```gdscript
extends GutTest
## PHASES test: tap < threshold -> one light; hold -> heavy for as long as it is held.

const T := 0.15


func test_tap_is_a_light_on_release() -> void:
	var m := AttackButtonModel.new(T)
	m.press(1.0)
	assert_false(m.holding_heavy(1.1))
	assert_eq(m.release(1.1), AttackButtonModel.Result.LIGHT)
	assert_false(m.is_down())


func test_hold_turns_into_heavy_at_the_threshold() -> void:
	var m := AttackButtonModel.new(T)
	m.press(1.0)
	assert_false(m.holding_heavy(1.0 + T - 0.001))
	assert_true(m.holding_heavy(1.0 + T))
	assert_almost_eq(m.charge_time(1.0 + T + 0.5), 0.5, 0.0001, "charge counts from the threshold")
	assert_eq(m.release(1.0 + T + 0.5), AttackButtonModel.Result.HEAVY_RELEASE)


func test_canceled_tap_does_nothing() -> void:
	var m := AttackButtonModel.new(T)
	m.press(1.0)
	assert_eq(m.release(1.05, true), AttackButtonModel.Result.NONE, "a canceled touch is not an attack")


func test_release_without_press_is_none() -> void:
	assert_eq(AttackButtonModel.new(T).release(2.0), AttackButtonModel.Result.NONE)
	assert_eq(AttackButtonModel.new(T).charge_time(2.0), 0.0)
```

`tests/unit/test_touch_layout.gd`:
```gdscript
extends GutTest
## Touch layouts (design.md DS-LAY-01, context E9): every variant keeps all four buttons inside
## the safe area without overlap, with attack the largest and bottom-right-most.

const SIZES := {"attack": 170.0, "jump": 130.0, "guard": 116.0, "grab": 116.0}
const GAP := 24.0
const MARGIN := 64.0
const SCREENS: Array[Rect2] = [
	Rect2(0, 0, 1920, 1080), Rect2(0, 0, 1280, 720), Rect2(96, 0, 2208, 1032),
]


func _check(variant: int, safe: Rect2) -> void:
	var c := TouchLayout.centers(variant, safe, SIZES, GAP, MARGIN)
	for name: String in TouchLayout.BUTTONS:
		assert_true(c.has(name), "%s placed" % name)
		var r: float = SIZES[name] * 0.5
		var box := Rect2(c[name] - Vector2(r, r), Vector2(r, r) * 2.0)
		assert_true(safe.encloses(box), "variant %d: %s inside %s" % [variant, name, safe])
	for i: int in TouchLayout.BUTTONS.size():
		for j: int in range(i + 1, TouchLayout.BUTTONS.size()):
			var a: String = TouchLayout.BUTTONS[i]
			var b: String = TouchLayout.BUTTONS[j]
			var need: float = (SIZES[a] + SIZES[b]) * 0.5
			assert_gte((c[a] as Vector2).distance_to(c[b]), need, "variant %d: %s/%s overlap" % [variant, a, b])
	var attack: Vector2 = c["attack"]
	assert_gte(attack.x, (c["guard"] as Vector2).x, "attack sits on the thumb side")


func test_all_variants_fit_every_screen() -> void:
	for variant: int in [TouchLayout.Variant.ARC, TouchLayout.Variant.DIAMOND, TouchLayout.Variant.GRID]:
		for safe: Rect2 in SCREENS:
			_check(variant, safe)


func test_arc_puts_attack_in_the_corner() -> void:
	var safe := Rect2(0, 0, 1920, 1080)
	var c := TouchLayout.centers(TouchLayout.Variant.ARC, safe, SIZES, GAP, MARGIN)
	assert_eq(c["attack"], safe.end - Vector2(MARGIN + 85.0, MARGIN + 85.0))


func test_unknown_variant_falls_back_to_arc() -> void:
	var safe := Rect2(0, 0, 1920, 1080)
	assert_eq(TouchLayout.centers(9, safe, SIZES, GAP, MARGIN), TouchLayout.centers(TouchLayout.Variant.ARC, safe, SIZES, GAP, MARGIN))
```

`tests/unit/test_touch_input.gd` 끝에 추가 (기존 5개 유지):
```gdscript


func test_hold_attack_becomes_heavy_and_release_ends_it() -> void:
	_touch.time_override = 10.0
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	_touch.time_override = 10.5
	_touch._process(0.0)
	assert_true(_local.sample().heavy, "held past the threshold -> heavy")
	assert_true(_local.sample().heavy, "stays held")
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), false))
	var f := _local.sample()
	assert_false(f.heavy, "release ends the charge; the sim swings")
	assert_false(f.light, "a hold is not also a light")


func test_short_hold_released_between_frames_still_swings_heavy() -> void:
	_touch.time_override = 10.0
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	_touch.time_override = 10.3
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), false))
	assert_true(_local.sample().heavy, "past the threshold but no frame ran: one tick of heavy")
	assert_false(_local.sample().heavy)


func test_guard_held_while_touched() -> void:
	_touch._unhandled_input(_touch_event(1, _touch.button_center("guard"), true))
	assert_true(_local.sample().guard)
	_touch._unhandled_input(_touch_event(1, _touch.button_center("guard"), false))
	assert_false(_local.sample().guard)


func test_grab_fires_on_press() -> void:
	_touch._unhandled_input(_touch_event(2, _touch.button_center("grab"), true))
	assert_true(_local.sample().grab)


func test_canceled_attack_touch_does_not_attack() -> void:
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	var cancel := _touch_event(0, _touch.attack_center(), false)
	cancel.canceled = true
	_touch._unhandled_input(cancel)
	assert_false(_local.sample().light)


func test_focus_loss_releases_every_finger() -> void:
	var start := _touch.stick_zone_point()
	_touch._unhandled_input(_touch_event(0, start, true))
	_touch._unhandled_input(_drag_event(0, start + Vector2(140, 0)))
	_touch._unhandled_input(_touch_event(1, _touch.button_center("guard"), true))
	_touch._unhandled_input(_touch_event(2, _touch.attack_center(), true))
	_touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var f := _local.sample()
	assert_eq(f.move_x, 0.0, "stick let go")
	assert_false(f.guard, "guard let go")
	assert_false(f.light, "a canceled attack touch is not a tap")


func test_layout_follows_the_config() -> void:
	var c := GameConfig.new()
	var touch := TouchInput.new()
	add_child_autofree(touch)
	touch.setup(LocalInput.new(), c)
	var arc := touch.button_center("guard")
	c.touch_layout = TouchLayout.Variant.GRID
	c.emit_changed()
	assert_ne(touch.button_center("guard"), arc, "debug panel can switch layouts live for the gate")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_attack_button_model`
Expected: FAIL — `Identifier "AttackButtonModel" not declared`

- [ ] **Step 3: AttackButtonModel 작성**

`src/input/attack_button_model.gd`:
```gdscript
class_name AttackButtonModel
extends RefCounted
## Touch attack button gesture (PRD §3.3): a tap shorter than touch_hold_threshold is a light
## attack on release; holding past it is a held heavy (charge) that swings on release. A canceled
## tap does nothing; a canceled charge still releases (the sim cannot un-charge). Time is passed
## in (seconds) so the model stays pure.

enum Result { NONE, LIGHT, HEAVY_RELEASE }

const UP := -1.0

var threshold: float
var _down_at: float = UP


func _init(p_threshold: float) -> void:
	threshold = p_threshold


func press(t: float) -> void:
	_down_at = t


func is_down() -> bool:
	return _down_at != UP


func holding_heavy(t: float) -> bool:
	return is_down() and t - _down_at >= threshold


## Seconds of charge (0 until the hold turns into a heavy).
func charge_time(t: float) -> float:
	return maxf(t - _down_at - threshold, 0.0) if is_down() else 0.0


func release(t: float, canceled: bool = false) -> int:
	if not is_down():
		return Result.NONE
	var heavy := holding_heavy(t)
	_down_at = UP
	if heavy:
		return Result.HEAVY_RELEASE
	return Result.NONE if canceled else Result.LIGHT
```

- [ ] **Step 4: TouchLayout 작성**

`src/input/touch_layout.gd`:
```gdscript
class_name TouchLayout
extends RefCounted
## Touch button placement (design.md DS-LAY-01, context E9): three candidates for the 🖼 gate.
## All keep the attack button (largest) at the bottom-right thumb rest inside the safe area.
##   ARC     jump / guard / grab on an arc around attack (left, up-left, up)
##   DIAMOND attack east, jump south, guard west, grab north
##   GRID    2x2: guard grab / jump attack

enum Variant { ARC, DIAMOND, GRID }

const BUTTONS: Array[String] = ["attack", "jump", "guard", "grab"]
## Arc angles in screen space (y down): left, up-left, up.
const ARC_DEGREES := {"jump": 180.0, "guard": 225.0, "grab": 270.0}


static func centers(variant: int, safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	match variant:
		Variant.DIAMOND:
			return _diamond(safe, sizes, gap, margin)
		Variant.GRID:
			return _grid(safe, sizes, gap, margin)
		_:
			return _arc(safe, sizes, gap, margin)


static func _r(sizes: Dictionary, name: String) -> float:
	return float(sizes[name]) * 0.5


static func _corner(safe: Rect2, sizes: Dictionary, margin: float) -> Vector2:
	var ra := _r(sizes, "attack")
	return safe.end - Vector2(margin + ra, margin + ra)


static func _arc(safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	var attack := _corner(safe, sizes, margin)
	var out := {"attack": attack}
	for name: String in ARC_DEGREES:
		var a := deg_to_rad(float(ARC_DEGREES[name]))
		out[name] = attack + Vector2(cos(a), sin(a)) * (_r(sizes, "attack") + _r(sizes, name) + gap)
	return out


static func _diamond(safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	var ra := _r(sizes, "attack")
	var side := maxf(maxf(_r(sizes, "jump"), _r(sizes, "guard")), _r(sizes, "grab"))
	var arm := (ra + side + gap) * 0.75
	var hub := Vector2(safe.end.x - margin - ra - arm, safe.end.y - margin - _r(sizes, "jump") - arm)
	return {
		"attack": hub + Vector2(arm, 0), "jump": hub + Vector2(0, arm),
		"guard": hub + Vector2(-arm, 0), "grab": hub + Vector2(0, -arm),
	}


static func _grid(safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	var ra := _r(sizes, "attack")
	var attack := _corner(safe, sizes, margin)
	var jump := attack + Vector2(-(ra + _r(sizes, "jump") + gap), ra - _r(sizes, "jump"))
	var grab := attack + Vector2(0, -(ra + _r(sizes, "grab") + gap))
	return {"attack": attack, "jump": jump, "grab": grab, "guard": Vector2(jump.x, grab.y)}
```

- [ ] **Step 5: SafeArea 작성**

`src/ui/safe_area.gd`:
```gdscript
class_name SafeArea
extends RefCounted
## The part of the viewport clear of notches and gesture bars (design.md DS-LAY-02, Phase 1
## carry-over). Mobile only: the device safe area is mapped into viewport coordinates; desktop
## windows use the whole viewport.


static func rect(viewport: Viewport) -> Rect2:
	var vp := viewport.get_visible_rect()
	if not OS.has_feature("mobile"):
		return vp
	var screen := Vector2(DisplayServer.screen_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if screen.x <= 0.0 or screen.y <= 0.0 or sa.size.x <= 0 or sa.size.y <= 0:
		return vp
	var scale := vp.size / screen
	return Rect2(Vector2(sa.position) * scale, Vector2(sa.size) * scale).intersection(vp)
```

- [ ] **Step 6: TouchInput 교체**

`src/input/touch_input.gd`:
```gdscript
class_name TouchInput
extends CanvasLayer
## Touch controls (PRD §3.3, design.md DS-LAY-01): floating stick on the left 40% x bottom 70% of
## the safe area, four buttons bottom-right in the layout chosen by config.touch_layout (E9).
## Attack: tap = light on release, hold = heavy charge (AttackButtonModel). Jump and grab fire on
## press; guard holds while touched. Canceled touches and focus loss release everything without
## firing a tap. Finger index >= 3 (four-finger tap) belongs to the debug panel. Debug builds
## without a touchscreen accept the left mouse button as finger 0 for desktop testing.

const TOUCH_STICK_SCENE := preload("res://src/ui/components/touch_stick/touch_stick.tscn")
const TOUCH_BUTTON_SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")
const LAYER := 10
const STICK_ZONE_WIDTH := 0.4
const STICK_ZONE_TOP := 0.3
const MAX_FINGERS := 3
const MOUSE_FINGER := 0
const NO_FINGER := -1
const LABELS := {"attack": "공격", "jump": "점프", "guard": "가드", "grab": "잡기"}

## Test clock: when >= 0 it replaces the real time in seconds.
var time_override: float = -1.0
var _local: LocalInput
var _config: GameConfig
var _model: TouchStickModel
var _attack_model: AttackButtonModel
var _stick: TouchStick
var _buttons: Dictionary = {}
var _owner: Dictionary = {}
var _stick_finger: int = NO_FINGER
var _heavy_sent: bool = false


func setup(local: LocalInput, config: GameConfig) -> void:
	_local = local
	_config = config
	layer = LAYER
	_model = TouchStickModel.new(config.touch_stick_radius, config.touch_stick_deadzone)
	_attack_model = AttackButtonModel.new(config.touch_hold_threshold)
	local.touch_stick = _model
	_stick = TOUCH_STICK_SCENE.instantiate() as TouchStick
	add_child(_stick)
	for name: String in TouchLayout.BUTTONS:
		var b := TOUCH_BUTTON_SCENE.instantiate() as TouchButton
		b.label_text = LABELS[name]
		add_child(b)
		_buttons[name] = b
		_owner[name] = NO_FINGER
	visible = DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	config.changed.connect(_layout)
	_layout()


func buttons() -> Dictionary:
	return _buttons


func button_center(name: String) -> Vector2:
	return (_buttons[name] as TouchButton).get_global_rect().get_center()


func attack_center() -> Vector2:
	return button_center("attack")


func jump_center() -> Vector2:
	return button_center("jump")


func stick_zone_point() -> Vector2:
	var safe := SafeArea.rect(get_viewport())
	return Vector2(safe.position.x + safe.size.x * STICK_ZONE_WIDTH * 0.5,
			safe.position.y + safe.size.y * (STICK_ZONE_TOP + 1.0) * 0.5)


## Seconds the attack button has been charging (0 when not holding a heavy).
func attack_charge_time() -> float:
	return _attack_model.charge_time(_now())


func _process(_delta: float) -> void:
	if _attack_model != null and not _heavy_sent and _attack_model.holding_heavy(_now()):
		_heavy_sent = true
		_local.set_touch_heavy(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index < MAX_FINGERS:
			if t.pressed:
				_down(t.index, t.position)
			else:
				_up(t.index, t.canceled)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position)
	elif _mouse_as_finger() and event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				_down(MOUSE_FINGER, m.position)
			else:
				_up(MOUSE_FINGER, false)
	elif _mouse_as_finger() and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(MOUSE_FINGER, mm.position)


func _layout() -> void:
	if _config == null:
		return
	var sizes := {
		"attack": _config.touch_attack_diameter, "jump": _config.touch_jump_diameter,
		"guard": _config.touch_side_diameter, "grab": _config.touch_side_diameter,
	}
	var centers := TouchLayout.centers(_config.touch_layout, SafeArea.rect(get_viewport()), sizes, DS.S5, DS.S8)
	for name: String in TouchLayout.BUTTONS:
		var b: TouchButton = _buttons[name]
		b.set_diameter(sizes[name])
		b.position = (centers[name] as Vector2) - Vector2(b.diameter, b.diameter) * 0.5


func _down(index: int, pos: Vector2) -> void:
	visible = true
	for name: String in TouchLayout.BUTTONS:
		var b: TouchButton = _buttons[name]
		if _owner[name] == NO_FINGER and b.contains(pos):
			_owner[name] = index
			b.set_state(TouchButton.State.PRESSED)
			_button_down(name)
			return
	if _stick_finger == NO_FINGER and _in_stick_zone(pos):
		_stick_finger = index
		_model.begin(pos)
		_refresh_stick()


func _up(index: int, canceled: bool) -> void:
	for name: String in TouchLayout.BUTTONS:
		if _owner[name] == index:
			_owner[name] = NO_FINGER
			(_buttons[name] as TouchButton).set_state(TouchButton.State.IDLE)
			_button_up(name, canceled)
	if index == _stick_finger:
		_stick_finger = NO_FINGER
		_model.end()
		_stick.hide_stick()


func _release_all() -> void:
	var fingers: Array[int] = []
	for name: String in TouchLayout.BUTTONS:
		if _owner[name] != NO_FINGER:
			fingers.append(_owner[name])
	if _stick_finger != NO_FINGER:
		fingers.append(_stick_finger)
	for index: int in fingers:
		_up(index, true)


func _button_down(name: String) -> void:
	match name:
		"attack":
			_attack_model.press(_now())
		"jump":
			_local.press_jump()
		"guard":
			_local.set_touch_guard(true)
		"grab":
			_local.press_grab()


func _button_up(name: String, canceled: bool) -> void:
	match name:
		"attack":
			var result := _attack_model.release(_now(), canceled)
			if result == AttackButtonModel.Result.LIGHT:
				_local.press_light()
			elif result == AttackButtonModel.Result.HEAVY_RELEASE:
				_local.set_touch_heavy(true)  # a no-op when _process already sent it
				_local.set_touch_heavy(false)
			_heavy_sent = false
		"guard":
			_local.set_touch_guard(false)


func _drag(index: int, pos: Vector2) -> void:
	if index == _stick_finger:
		_model.move(pos)
		_refresh_stick()


func _refresh_stick() -> void:
	_stick.show_stick(_model.center(), _model.knob(), _model.radius)


func _in_stick_zone(pos: Vector2) -> bool:
	var safe := SafeArea.rect(get_viewport())
	return pos.x <= safe.position.x + safe.size.x * STICK_ZONE_WIDTH \
			and pos.y >= safe.position.y + safe.size.y * STICK_ZONE_TOP


func _now() -> float:
	return time_override if time_override >= 0.0 else Time.get_ticks_msec() / 1000.0


func _mouse_as_finger() -> bool:
	return OS.is_debug_build() and not DisplayServer.is_touchscreen_available()
```

`src/ui/components/touch_button/touch_button.gd`에 크기 변경용 공개 함수 추가 (기존 `_apply_size` 재사용):
```gdscript
## Resizes the button (layouts change sizes at runtime).
func set_diameter(d: float) -> void:
	diameter = d
	_apply_size()
```

- [ ] **Step 7: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS (Phase 1 터치 테스트 5개 포함).

- [ ] **Step 8: 레이아웃 3안 캡처 (🖼 게이트 준비)**

세 레이아웃을 데스크톱 1920×1080에서 캡처한다. `scripts/capture_evidence.gd`에 `--touch-layout=N` 인자를 추가 (`--arena-radius`와 같은 방식: 기본 config를 load해 `touch_layout`을 바꾸고 `emit_changed()`):
```gdscript
	if args.has("touch-layout"):
		var config := load("res://src/config/default_config.tres") as GameConfig
		if config == null:
			push_error("capture_evidence: GameConfig missing at res://src/config/default_config.tres")
			quit(1)
			return
		config.touch_layout = int(args["touch-layout"])
		config.emit_changed()
```
(이 블록은 `if args.has("arena-radius"):` 블록 바로 뒤, 사용법 주석에 `[--touch-layout=N]` 추가.)
Run (창 모드):
```bash
mkdir -p dev/active/phase-2/evidence
for n in 0 1 2; do godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out="$PWD/dev/active/phase-2/evidence/touch-layout-$n.png" --show-touch --touch-layout=$n; done
```
Expected: `touch-layout-0.png`(호) / `-1`(다이아몬드) / `-2`(2×2) 세 장. 보고서에 경로를 적는다 (컨트롤러가 T13 게이트에서 사용자에게 보여줌).

- [ ] **Step 9: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/input/attack_button_model.gd src/input/attack_button_model.gd.uid src/input/touch_layout.gd src/input/touch_layout.gd.uid src/ui/safe_area.gd src/ui/safe_area.gd.uid src/input/touch_input.gd src/ui/components/touch_button/touch_button.gd scripts/capture_evidence.gd tests/unit/test_attack_button_model.gd tests/unit/test_attack_button_model.gd.uid tests/unit/test_touch_layout.gd tests/unit/test_touch_layout.gd.uid tests/unit/test_touch_input.gd dev/active/phase-2/evidence/touch-layout-0.png dev/active/phase-2/evidence/touch-layout-1.png dev/active/phase-2/evidence/touch-layout-2.png
git commit -m "feat: add four-button touch controls with tap/hold attack and three layouts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: 🖼 게이트 — 4버튼 레이아웃 확정 (사용자 + 컨트롤러)

**구현 태스크가 아니다. 서브에이전트에 배정하지 않는다.** 컨트롤러가 사용자와 진행한다.

- [ ] **Step 1:** 사용자가 `docs/stitch-prompts.md` 1번(공통 컨텍스트 + 1번 프롬프트)으로 Stitch 시안 3안(A 호 / B 다이아몬드 / C 2×2)을 만든다. Phase 1에서 미뤄진 HUD 시안도 같은 프롬프트 결과로 함께 본다
- [ ] **Step 2:** 컨트롤러가 T12의 `evidence/touch-layout-{0,1,2}.png`와 Stitch 시안을 나란히 보여주고(시각 비교), 가능하면 Android 실기기에서 디버그 패널 `touch_layout` 슬라이더로 세 안을 직접 눌러 보게 한다
- [ ] **Step 3:** 사용자가 고른 안을 `GameConfig.touch_layout` 기본값으로 반영하고(값만 바꿈, 테스트는 모든 안을 검사하므로 그대로 통과), design.md DS-LAY-01 표에 "확정: <안>, 근거"를 적는다. 캐릭터 크기(카메라 여백 `cam_margin`) 결정도 이때 함께 받는다 — 바꾸면 리플레이 골든 갱신
- [ ] **Step 4:** 게이트가 지연되면 기본값 0(호)으로 계속 진행하고 tasks 파일에 `🖼 대기`로 남긴다

---

### Task 14: TouchButton v2 (강조·비활성·차지 상태, 아이콘) + GrabContext + 테마 포커스 색

**Files:**
- Create: `src/ui/components/touch_button/touch_icons.gd`, `src/input/grab_context.gd`
- Modify: `src/ui/components/touch_button/touch_button.gd`, `src/input/touch_input.gd` (아이콘 지정, 차지 표시, 강조·비활성 API), `src/ui/theme/theme_builder.gd` + `src/ui/theme/forest_theme.tres`(재생성), `src/ui/components/result_banner/result_banner.gd` (개별 override 삭제), `src/debug/ds_gallery.gd`
- Test: `tests/unit/test_touch_button.gd`, `tests/unit/test_grab_context.gd` (신규), `tests/unit/test_theme_builder.gd`, `tests/unit/test_touch_input.gd`

**Interfaces:**
- Consumes: T12 `TouchInput.buttons()`/`attack_charge_time()`, T7 `Item`, T2 view 필드(`item_kind`, `partner_id`, `invuln_ticks`)
- Produces:
  - `TouchButton.State { IDLE, PRESSED, HIGHLIGHT, DISABLED, CHARGING }` (IDLE=0, PRESSED=1 유지), `@export var icon: int`, `@export var dim_when_idle: bool`, `set_charge(value: float) -> void` (0~1), `state() -> int`
  - `TouchIcons.Icon { ATTACK, JUMP, GUARD, GRAB }`, `static func TouchIcons.draw(canvas: CanvasItem, icon: int, center: Vector2, size: float, color: Color) -> void`
  - `GrabContext.Kind { NONE, THROW, ITEM, FIGHTER }`, `static func GrabContext.evaluate(view: Dictionary, self_id: int, config: GameConfig) -> Dictionary` → `{"kind": int, "pos": Vector3}`
  - `TouchInput.set_grab_highlight(on: bool) -> void`, `TouchInput.set_enabled(on: bool) -> void`
- 근거: `[DS-CMP-04]` `[PRD-CTL-03]` `[DS-GOV-02]` · Phase 1 이월(Button 포커스 색)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_touch_button.gd`:
```gdscript
extends GutTest
## TouchButton v2 states (design.md DS-CMP-04).

const SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")


func _button() -> TouchButton:
	var b := SCENE.instantiate() as TouchButton
	add_child_autofree(b)
	return b


func test_phase1_state_values_are_kept() -> void:
	assert_eq(TouchButton.State.IDLE, 0)
	assert_eq(TouchButton.State.PRESSED, 1)


func test_pressed_and_charging_squish_others_do_not() -> void:
	var b := _button()
	for s: int in [TouchButton.State.PRESSED, TouchButton.State.CHARGING]:
		b.set_state(s)
		assert_eq(b.scale, DS.PRESS_SQUISH, "state %d" % s)
	for s: int in [TouchButton.State.IDLE, TouchButton.State.DISABLED]:
		b.set_state(s)
		assert_eq(b.scale, Vector2.ONE, "state %d" % s)


func test_charge_is_clamped() -> void:
	var b := _button()
	b.set_charge(1.7)
	assert_eq(b.charge(), 1.0)
	b.set_charge(-1.0)
	assert_eq(b.charge(), 0.0)


func test_every_icon_draws() -> void:
	for icon: int in [TouchIcons.Icon.ATTACK, TouchIcons.Icon.JUMP, TouchIcons.Icon.GUARD, TouchIcons.Icon.GRAB]:
		var b := _button()
		b.icon = icon
		b.set_state(TouchButton.State.HIGHLIGHT)
		await get_tree().process_frame
		assert_eq(b.state(), TouchButton.State.HIGHLIGHT)
```

`tests/unit/test_grab_context.gd`:
```gdscript
extends GutTest
## What the grab button does right now (DS-CMP-04 highlight, PRD §3.3).


func _world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = Vector3(0, 0, 8)
	return w


func _eval(w: World) -> int:
	return int(GrabContext.evaluate(w.state_view(), 0, w.config)["kind"])


func test_nothing_nearby_is_none() -> void:
	assert_eq(_eval(_world()), GrabContext.Kind.NONE)


func test_item_in_reach() -> void:
	var w := _world()
	var it := w.items.add(Item.Kind.BAT, w.fighters[0].pos + Vector3(0.8, 0, 0), Item.State.GROUND, w.config)
	var r := GrabContext.evaluate(w.state_view(), 0, w.config)
	assert_eq(int(r["kind"]), GrabContext.Kind.ITEM)
	assert_eq(r["pos"], it.pos)


func test_lit_bomb_and_falling_box_do_not_count() -> void:
	var w := _world()
	var bomb := w.items.add(Item.Kind.BOMB, w.fighters[0].pos + Vector3(0.5, 0, 0), Item.State.GROUND, w.config)
	bomb.fuse_ticks = 30
	w.items.add(Item.Kind.ROCK, w.fighters[0].pos + Vector3(0, 3, 0), Item.State.FALLING, w.config)
	assert_eq(_eval(w), GrabContext.Kind.NONE)


func test_fighter_in_reach() -> void:
	var w := _world()
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	assert_eq(_eval(w), GrabContext.Kind.FIGHTER)


func test_invulnerable_or_ko_fighter_does_not_count() -> void:
	var w := _world()
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[1].invuln_ticks = 10
	assert_eq(_eval(w), GrabContext.Kind.NONE)


func test_carrying_an_item_means_throw() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	assert_eq(_eval(w), GrabContext.Kind.THROW)


func test_holding_a_fighter_means_throw() -> void:
	var w := _world()
	w.fighters[0].set_state(Fighter.State.HOLDING)
	assert_eq(_eval(w), GrabContext.Kind.THROW)


func test_busy_or_airborne_is_none() -> void:
	var w := _world()
	w.items.add(Item.Kind.BAT, w.fighters[0].pos + Vector3(0.5, 0, 0), Item.State.GROUND, w.config)
	w.fighters[0].set_state(Fighter.State.HITSTUN)
	assert_eq(_eval(w), GrabContext.Kind.NONE)
	w.fighters[0].set_state(Fighter.State.AIR)
	w.fighters[0].on_ground = false
	assert_eq(_eval(w), GrabContext.Kind.NONE, "pickups and grabs need the ground")
```

`tests/unit/test_theme_builder.gd`의 `test_button_states` 끝에 추가:
```gdscript
	assert_eq(t.get_color("font_focus_color", "Button"), DS.UI_TEXT, "focused buttons keep readable text")
```

`tests/unit/test_touch_input.gd` 끝에 추가:
```gdscript


func test_buttons_carry_their_icons() -> void:
	var b: Dictionary = _touch.buttons()
	assert_eq((b["attack"] as TouchButton).icon, TouchIcons.Icon.ATTACK)
	assert_eq((b["grab"] as TouchButton).icon, TouchIcons.Icon.GRAB)
	assert_true((b["grab"] as TouchButton).dim_when_idle, "grab rests at 60% until it has a target")


func test_grab_highlight_and_disable() -> void:
	var grab := _touch.buttons()["grab"] as TouchButton
	_touch.set_grab_highlight(true)
	assert_eq(grab.state(), TouchButton.State.HIGHLIGHT)
	_touch.set_grab_highlight(false)
	assert_eq(grab.state(), TouchButton.State.IDLE)
	_touch.set_enabled(false)
	for b: TouchButton in _touch.buttons().values():
		assert_eq(b.state(), TouchButton.State.DISABLED)
	_touch._unhandled_input(_touch_event(1, _touch.jump_center(), true))
	assert_false(_local.sample().jump, "disabled buttons ignore touches")


func test_attack_shows_charging_while_held() -> void:
	_touch.time_override = 20.0
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	_touch.time_override = 20.65
	_touch._process(0.0)
	var attack := _touch.buttons()["attack"] as TouchButton
	assert_eq(attack.state(), TouchButton.State.CHARGING)
	assert_almost_eq(attack.charge(), 0.5, 0.01, "(0.65 - 0.15) s of a 1 s max charge")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_grab_context`
Expected: FAIL — `Identifier "GrabContext" not declared`

- [ ] **Step 3: TouchIcons 작성**

`src/ui/components/touch_button/touch_icons.gd`:
```gdscript
class_name TouchIcons
extends RefCounted
## Touch button icons (design.md DS-CMP-04), drawn from round primitives in the form language
## of design.md §3: no sharp spikes. size is the icon's half extent in pixels.

enum Icon { ATTACK, JUMP, GUARD, GRAB }

## Line width as a fraction of the icon size.
const STROKE_RATIO := 0.16
const SEGMENTS := 24


static func draw(canvas: CanvasItem, icon: int, center: Vector2, size: float, color: Color) -> void:
	var w := maxf(size * STROKE_RATIO, 2.0)
	match icon:
		Icon.ATTACK:
			# a round fist: palm circle with three knuckles on top
			canvas.draw_circle(center + Vector2(0, size * 0.15), size * 0.55, color)
			for i: int in 3:
				canvas.draw_circle(center + Vector2((i - 1) * size * 0.42, -size * 0.45), size * 0.24, color)
		Icon.JUMP:
			# two soft upward chevrons
			for k: int in 2:
				var y := center.y + size * (0.35 - k * 0.55)
				canvas.draw_polyline(PackedVector2Array([
					Vector2(center.x - size * 0.6, y + size * 0.3), Vector2(center.x, y - size * 0.25),
					Vector2(center.x + size * 0.6, y + size * 0.3)]), color, w, true)
		Icon.GUARD:
			# rounded shield
			var pts := PackedVector2Array()
			for i: int in SEGMENTS + 1:
				var a := PI * float(i) / SEGMENTS
				pts.append(center + Vector2(cos(a) * size * 0.7, sin(a) * size * 0.9 - size * 0.1))
			pts.append(center + Vector2(-size * 0.7, -size * 0.6))
			pts.append(center + Vector2(size * 0.7, -size * 0.6))
			canvas.draw_colored_polygon(pts, color)
		Icon.GRAB:
			# an open cupped hand: a thick arc with a dot inside
			canvas.draw_arc(center, size * 0.6, deg_to_rad(-60.0), deg_to_rad(240.0), SEGMENTS, color, w * 1.5, true)
			canvas.draw_circle(center, size * 0.22, color)
```

- [ ] **Step 4: TouchButton v2**

`src/ui/components/touch_button/touch_button.gd` 교체:
```gdscript
class_name TouchButton
extends Control
## Touch action button v2 (design.md DS-CMP-04): idle, pressed, highlight (context: petal-yellow
## ring with a soft pulse), disabled and charging (an arc filling from petal yellow to campfire
## orange, glowing when full). Circle hit-test, cream 70% fill (50% when dim_when_idle), press
## squish, icon plus a small label.

enum State { IDLE, PRESSED, HIGHLIGHT, DISABLED, CHARGING }

const PREVIEW_DIAMETER := 150.0
const ICON_RATIO := 0.32
const LABEL_OFFSET_RATIO := 0.62
const RING_WIDTH := DS.STROKE_FOCUS * 2
const PULSE_HZ := 1.5
const PULSE_SCALE := 0.04
const ARC_SEGMENTS := 48

@export var label_text: String = "공격"
@export var diameter: float = PREVIEW_DIAMETER
@export var icon: int = TouchIcons.Icon.ATTACK
## Grab rests fainter until it has something to act on (design.md DS-LAY-01).
@export var dim_when_idle: bool = false

var _state: int = State.IDLE
var _charge: float = 0.0
var _font: Font
var _pulse_time: float = 0.0


func _ready() -> void:
	_font = load(DS.FONT_CAPTION_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_size()


func _process(delta: float) -> void:
	if _state != State.HIGHLIGHT:
		return
	_pulse_time += delta
	scale = Vector2.ONE * (1.0 + PULSE_SCALE * sin(_pulse_time * TAU * PULSE_HZ))


func set_state(s: int) -> void:
	_state = s
	_pulse_time = 0.0
	scale = DS.PRESS_SQUISH if s == State.PRESSED or s == State.CHARGING else Vector2.ONE
	queue_redraw()


func state() -> int:
	return _state


func set_charge(value: float) -> void:
	_charge = clampf(value, 0.0, 1.0)
	queue_redraw()


func charge() -> float:
	return _charge


func contains(point: Vector2) -> bool:
	return point.distance_to(get_global_rect().get_center()) <= diameter * 0.5


func set_diameter(d: float) -> void:
	diameter = d
	_apply_size()


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	diameter = PREVIEW_DIAMETER
	_apply_size()
	set_state(State.HIGHLIGHT)


func _apply_size() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var r := diameter * 0.5
	var c := Vector2(r, r)
	draw_circle(c, r, _fill())
	match _state:
		State.HIGHLIGHT:
			draw_arc(c, r - RING_WIDTH * 0.5, 0.0, TAU, ARC_SEGMENTS, DS.PETAL_YELLOW, RING_WIDTH, true)
		State.CHARGING:
			var color := DS.GLOW if _charge >= 1.0 else DS.PETAL_YELLOW.lerp(DS.FIRE, _charge)
			draw_arc(c, r - RING_WIDTH * 0.5, -PI * 0.5, -PI * 0.5 + TAU * maxf(_charge, 0.01),
					ARC_SEGMENTS, color, RING_WIDTH, true)
	var ink := DS.UI_TEXT_SOFT if _state == State.DISABLED else DS.UI_TEXT
	TouchIcons.draw(self, icon, c - Vector2(0, r * 0.12), r * ICON_RATIO * 2.0, ink)
	if _font != null:
		draw_string(_font, Vector2(0.0, r + r * LABEL_OFFSET_RATIO), label_text,
				HORIZONTAL_ALIGNMENT_CENTER, diameter, DS.SIZE_CAPTION, ink)


func _fill() -> Color:
	match _state:
		State.PRESSED, State.CHARGING:
			return DS.UI_SURFACE_DIM
		State.DISABLED:
			return DS.UI_SURFACE_50
		State.IDLE:
			return DS.UI_SURFACE_50 if dim_when_idle else DS.UI_SURFACE_70
	return DS.UI_SURFACE_70
```

- [ ] **Step 5: GrabContext 작성**

`src/input/grab_context.gd`:
```gdscript
class_name GrabContext
extends RefCounted
## What the grab button would do right now for one fighter (PRD §3.3, DS-CMP-04 highlight):
## throw the carried item or held fighter, pick up an item, grab a fighter in reach, or nothing.
## Reads state_view() values only and mirrors ItemActions / Grab closely enough for a hint.

enum Kind { NONE, THROW, ITEM, FIGHTER }


static func evaluate(view: Dictionary, self_id: int, config: GameConfig) -> Dictionary:
	var me := _fighter(view, self_id)
	if me.is_empty():
		return _none()
	var state := int(me["state"])
	var pos: Vector3 = me["pos"]
	if state == Fighter.State.HOLDING:
		return {"kind": Kind.THROW, "pos": pos}
	if state != Fighter.State.IDLE and state != Fighter.State.MOVE and state != Fighter.State.AIR:
		return _none()
	if int(me["item_kind"]) != Fighter.NONE:
		return {"kind": Kind.THROW, "pos": pos}
	if not bool(me["on_ground"]):
		return _none()
	var item := _nearest_item(view, pos, config.item_pickup_radius)
	if not item.is_empty():
		return {"kind": Kind.ITEM, "pos": item["pos"]}
	var foe := _foe_in_reach(view, self_id, pos, config.grab_forward + config.grab_half_width + config.fighter_radius)
	if not foe.is_empty():
		return {"kind": Kind.FIGHTER, "pos": foe["pos"]}
	return _none()


static func _none() -> Dictionary:
	return {"kind": Kind.NONE, "pos": Vector3.ZERO}


static func _fighter(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _nearest_item(view: Dictionary, pos: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for it: Dictionary in view.get("items", []):
		if int(it["state"]) != Item.State.GROUND or int(it["fuse_ticks"]) != Item.UNLIT:
			continue
		var d := _flat(it["pos"], pos)
		if d <= best_d:
			best = it
			best_d = d
	return best


static func _foe_in_reach(view: Dictionary, self_id: int, pos: Vector3, reach: float) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		var s := int(f["state"])
		if int(f["id"]) == self_id or s == Fighter.State.KO or s == Fighter.State.HELD or s == Fighter.State.HOLDING:
			continue
		if int(f["invuln_ticks"]) > 0:
			continue
		if _flat(f["pos"], pos) <= reach:
			return f
	return {}
```

- [ ] **Step 6: TouchInput — 아이콘·강조·비활성·차지 표시**

`src/input/touch_input.gd`:
- 상수 추가:
```gdscript
const ICONS := {
	"attack": TouchIcons.Icon.ATTACK, "jump": TouchIcons.Icon.JUMP,
	"guard": TouchIcons.Icon.GUARD, "grab": TouchIcons.Icon.GRAB,
}
```
- 필드 추가: `var _enabled: bool = true`, `var _grab_highlight: bool = false`
- `setup`의 버튼 생성 루프에서 `b.label_text = LABELS[name]` 다음에:
```gdscript
		b.icon = ICONS[name]
		b.dim_when_idle = name == "grab"
```
- 공개 함수 추가:
```gdscript
func set_grab_highlight(on: bool) -> void:
	_grab_highlight = on
	_refresh_idle("grab")


func set_enabled(on: bool) -> void:
	if on == _enabled:
		return
	_enabled = on
	if not on:
		_release_all()
	for name: String in TouchLayout.BUTTONS:
		_refresh_idle(name)


## Resting look of a button nobody is touching: disabled, highlighted (grab) or idle.
func _refresh_idle(name: String) -> void:
	if _owner[name] != NO_FINGER:
		return
	var b: TouchButton = _buttons[name]
	if not _enabled:
		b.set_state(TouchButton.State.DISABLED)
	elif name == "grab" and _grab_highlight:
		b.set_state(TouchButton.State.HIGHLIGHT)
	else:
		b.set_state(TouchButton.State.IDLE)
```
- `_down` 첫 줄 `visible = true` 다음에 `if not _enabled: return` 추가
- `_up`에서 `(_buttons[name] as TouchButton).set_state(TouchButton.State.IDLE)`를 `_refresh_idle(name)`로 교체 (소유자를 먼저 비운 뒤 호출하므로 순서 유지: `_owner[name] = NO_FINGER` → `_refresh_idle(name)` → `_button_up(...)`)
- `_process` 교체:
```gdscript
func _process(_delta: float) -> void:
	if _attack_model == null or _owner["attack"] == NO_FINGER:
		return
	var now := _now()
	if _attack_model.holding_heavy(now):
		if not _heavy_sent:
			_heavy_sent = true
			_local.set_touch_heavy(true)
		var attack: TouchButton = _buttons["attack"]
		attack.set_state(TouchButton.State.CHARGING)
		attack.set_charge(_attack_model.charge_time(now) / maxf(_config.heavy_charge_max_time, 0.01))
```

- [ ] **Step 7: 테마 포커스 색**

`src/ui/theme/theme_builder.gd`의 `font_pressed_color` 줄 다음에:
```gdscript
	theme.set_color("font_focus_color", "Button", DS.UI_TEXT)
```
`src/ui/components/result_banner/result_banner.gd` 26행의 `_button.add_theme_color_override("font_focus_color", DS.UI_TEXT)  # theme has no focus font color` 줄 삭제.
Run: `godot --headless --path . -s res://scripts/build_theme.gd` → `forest_theme.tres` 재생성.

- [ ] **Step 8: DS 갤러리 등록**

`src/debug/ds_gallery.gd`:
- `COMPONENTS`의 `["TouchButton v1 · DS-CMP-04", ...]`를 `["TouchButton v2 · DS-CMP-04", ...]`로 이름 변경
- `_components()`의 `return box` 앞에 상태 줄 추가:
```gdscript
	var states_title := Label.new()
	states_title.text = "TouchButton v2 states · idle / pressed / highlight / disabled / charging"
	box.add_child(states_title)
	box.add_child(_touch_button_states())
```
- 함수 추가:
```gdscript
func _touch_button_states() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S5)
	var scene := load("res://src/ui/components/touch_button/touch_button.tscn") as PackedScene
	var icons := [TouchIcons.Icon.ATTACK, TouchIcons.Icon.JUMP, TouchIcons.Icon.GRAB, TouchIcons.Icon.GUARD, TouchIcons.Icon.ATTACK]
	var states := [TouchButton.State.IDLE, TouchButton.State.PRESSED, TouchButton.State.HIGHLIGHT,
			TouchButton.State.DISABLED, TouchButton.State.CHARGING]
	for i: int in states.size():
		var b := scene.instantiate() as TouchButton
		b.icon = icons[i]
		row.add_child(b)
		b.set_state(states[i])
		b.set_charge(0.6)
	return row
```

- [ ] **Step 9: 테스트 + 갤러리 캡처**

Run: `./scripts/test.sh`
Expected: 전부 PASS.
Run (창 모드):
```bash
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ds_gallery.tscn --out="$PWD/dev/active/phase-2/evidence/gallery-touch-button-v2.png" --frames=30 --components-only
```
(갤러리는 같은 사용자 인자 목록에서 `--components-only`를 읽는다 — Phase 1 T13과 같은 방식.) 컨트롤러가 이미지를 확인한다.

- [ ] **Step 10: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/ui/components/touch_button/touch_icons.gd src/ui/components/touch_button/touch_icons.gd.uid src/ui/components/touch_button/touch_button.gd src/input/grab_context.gd src/input/grab_context.gd.uid src/input/touch_input.gd src/ui/theme/theme_builder.gd src/ui/theme/forest_theme.tres src/ui/components/result_banner/result_banner.gd src/debug/ds_gallery.gd tests/unit/test_touch_button.gd tests/unit/test_touch_button.gd.uid tests/unit/test_grab_context.gd tests/unit/test_grab_context.gd.uid tests/unit/test_theme_builder.gd tests/unit/test_touch_input.gd dev/active/phase-2/evidence/gallery-touch-button-v2.png
git commit -m "feat: add TouchButton v2 states, icons and grab context" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: ChargeGauge (DS-CMP-05) + 머리 위 배치 레이어

**Files:**
- Create: `src/ui/components/charge_gauge/charge_gauge.gd`, `src/ui/components/charge_gauge/charge_gauge.tscn`, `src/ui/charge_gauge_layer.gd`
- Modify: `src/render/camera_rig.gd` (`unproject`), `src/debug/ds_gallery.gd` (등록)
- Test: `tests/unit/test_charge_gauge.gd` (신규)

**Interfaces:**
- Consumes: T2 view `charge_ticks`, `Fighter.State.CHARGE`, T1 `heavy_charge_max_time`
- Produces:
  - `ChargeGauge`: `set_value(v: float) -> void` (0~1), `value() -> float`, `is_full() -> bool`, `fill_color() -> Color`, `set_preview() -> void`
  - `ChargeGaugeLayer` (CanvasLayer): `update_from(view: Dictionary, config: GameConfig, project: Callable) -> void` (`project: func(Vector3) -> Vector2`), `gauge(id: int) -> ChargeGauge`
  - `CameraRig.unproject(world: Vector3) -> Vector2`
- 근거: `[DS-CMP-05]` `[PRD-CMB-02]` · E10

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_charge_gauge.gd`:
```gdscript
extends GutTest
## ChargeGauge (design.md DS-CMP-05): petal yellow -> campfire orange, glow when full.

const SCENE := preload("res://src/ui/components/charge_gauge/charge_gauge.tscn")


func _gauge() -> ChargeGauge:
	var g := SCENE.instantiate() as ChargeGauge
	add_child_autofree(g)
	return g


func test_value_is_clamped() -> void:
	var g := _gauge()
	g.set_value(1.4)
	assert_eq(g.value(), 1.0)
	assert_true(g.is_full())
	g.set_value(-0.2)
	assert_eq(g.value(), 0.0)


func test_color_ramp() -> void:
	var g := _gauge()
	g.set_value(0.0)
	assert_eq(g.fill_color(), DS.PETAL_YELLOW)
	g.set_value(0.5)
	assert_eq(g.fill_color(), DS.PETAL_YELLOW.lerp(DS.FIRE, 0.5))
	g.set_value(1.0)
	assert_eq(g.fill_color(), DS.GLOW, "full charge glows")


func test_layer_shows_a_gauge_only_while_charging() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].set_state(Fighter.State.CHARGE)
	w.fighters[0].charge_ticks = SimTime.to_ticks(c.heavy_charge_max_time) / 2
	var layer := ChargeGaugeLayer.new()
	add_child_autofree(layer)
	var project := func(p: Vector3) -> Vector2: return Vector2(p.x * 10.0 + 500.0, p.z * 10.0 + 300.0)
	layer.update_from(w.state_view(), c, project)
	var g0 := layer.gauge(0)
	assert_true(g0.visible)
	assert_almost_eq(g0.value(), 0.5, 0.001)
	var expected: Vector2 = project.call(w.fighters[0].pos + Vector3.UP * (c.fighter_height + ChargeGaugeLayer.HEAD_GAP))
	assert_almost_eq(g0.position + g0.size * 0.5, expected, Vector2(0.01, 0.01))
	assert_false(layer.gauge(1).visible, "idle fighter has no gauge")
	w.fighters[0].set_state(Fighter.State.IDLE)
	layer.update_from(w.state_view(), c, project)
	assert_false(g0.visible)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_charge_gauge`
Expected: FAIL — 씬 preload 실패 (`charge_gauge.tscn` 없음)

- [ ] **Step 3: ChargeGauge 작성**

`src/ui/components/charge_gauge/charge_gauge.gd`:
```gdscript
class_name ChargeGauge
extends Control
## Heavy-attack charge gauge (design.md DS-CMP-05): a small cream pill above the fighter's head
## that fills from petal yellow to campfire orange and glows when the charge is full.

const WIDTH := DS.S8 + DS.S6
const HEIGHT := DS.S4
const PREVIEW_VALUE := 0.7

var _value: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size


func set_value(v: float) -> void:
	_value = clampf(v, 0.0, 1.0)
	queue_redraw()


func value() -> float:
	return _value


func is_full() -> bool:
	return _value >= 1.0


func fill_color() -> Color:
	return DS.GLOW if is_full() else DS.PETAL_YELLOW.lerp(DS.FIRE, _value)


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	set_value(PREVIEW_VALUE)


func _draw() -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = DS.UI_SURFACE_70
	back.set_corner_radius_all(DS.RADIUS_PILL)
	back.shadow_color = DS.UI_SHADOW
	back.shadow_size = DS.SHADOW_PRESSED_SIZE
	draw_style_box(back, Rect2(Vector2.ZERO, size))
	if _value <= 0.0:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color()
	fill.set_corner_radius_all(DS.RADIUS_PILL)
	var inset := float(DS.S1) * 0.5
	draw_style_box(fill, Rect2(Vector2(inset, inset), Vector2((size.x - inset * 2.0) * _value, size.y - inset * 2.0)))
```

`src/ui/components/charge_gauge/charge_gauge.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/components/charge_gauge/charge_gauge.gd" id="1"]

[node name="ChargeGauge" type="Control"]
script = ExtResource("1")
```

- [ ] **Step 4: ChargeGaugeLayer 작성**

`src/ui/charge_gauge_layer.gd`:
```gdscript
class_name ChargeGaugeLayer
extends CanvasLayer
## One ChargeGauge per fighter, shown over its head while it charges a heavy attack (context E10).
## The caller passes the 3D -> screen projection (CameraRig.unproject) so this stays testable.

const SCENE := preload("res://src/ui/components/charge_gauge/charge_gauge.tscn")
const LAYER := 4
## Metres above the top of the capsule.
const HEAD_GAP := 0.9

var _gauges: Dictionary = {}


func _ready() -> void:
	layer = LAYER


func update_from(view: Dictionary, config: GameConfig, project: Callable) -> void:
	var full := float(maxi(SimTime.to_ticks(config.heavy_charge_max_time), 1))
	for f: Dictionary in view["fighters"]:
		var g := gauge(int(f["id"]))
		var charging := int(f["state"]) == Fighter.State.CHARGE
		g.visible = charging
		if not charging:
			continue
		g.set_value(float(f["charge_ticks"]) / full)
		var head: Vector3 = (f["pos"] as Vector3) + Vector3.UP * (config.fighter_height + HEAD_GAP)
		var at: Vector2 = project.call(head)
		g.position = at - g.size * 0.5


func gauge(id: int) -> ChargeGauge:
	if not _gauges.has(id):
		var g := SCENE.instantiate() as ChargeGauge
		add_child(g)
		g.visible = false
		_gauges[id] = g
	return _gauges[id]
```

- [ ] **Step 5: CameraRig.unproject**

`src/render/camera_rig.gd` 끝에 추가:
```gdscript
## Screen position of a world point (HUD elements that follow fighters, context E10).
func unproject(world: Vector3) -> Vector2:
	return _camera.unproject_position(world)
```

- [ ] **Step 6: 갤러리 등록**

`src/debug/ds_gallery.gd`의 `COMPONENTS`에 TouchButton 다음 줄로 추가:
```gdscript
	["ChargeGauge · DS-CMP-05", "res://src/ui/components/charge_gauge/charge_gauge.tscn"],
```

- [ ] **Step 7: 테스트 + 갤러리 캡처**

Run: `./scripts/test.sh`
Expected: 전부 PASS.
Run (창 모드):
```bash
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ds_gallery.tscn --out="$PWD/dev/active/phase-2/evidence/gallery-charge-gauge.png" --frames=30 --components-only
```

- [ ] **Step 8: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/ui/components/charge_gauge src/ui/charge_gauge_layer.gd src/ui/charge_gauge_layer.gd.uid src/render/camera_rig.gd src/debug/ds_gallery.gd tests/unit/test_charge_gauge.gd tests/unit/test_charge_gauge.gd.uid dev/active/phase-2/evidence/gallery-charge-gauge.png
git commit -m "feat: add ChargeGauge component and head-anchored gauge layer" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: 아이템 표시 — 상자·낙하 그림자·아이템 모양·든 아이템과 사용 횟수

**Files:**
- Create: `src/render/item_view.gd`, `src/render/item_layer.gd`
- Modify: `src/render/toon_materials.gd` (`translucent`), `src/ui/theme/tokens.gd` (`GROUND_SHADOW`), `src/render/fighter_view.gd` (든 아이템·점), `src/debug/ds_gallery.gd` (아이템 미리보기)
- Test: `tests/unit/test_item_view.gd` (신규), `tests/unit/test_fighter_view.gd`

**Interfaces:**
- Consumes: T7 `state_view().items` 항목(`id`, `kind`, `state`, `pos`, `uses`, `fuse_ticks`), T2 fighter view `item_kind`/`item_uses`, `ItemActions.HAND_HEIGHT_RATIO`
- Produces:
  - `ItemView` (Node3D): `setup(kind: int, config: GameConfig)`, `apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int)`, `static shadow_scale(height: float, drop_height: float) -> float`, `static fuse_visible(fuse_ticks: int, tick: int) -> bool`, `static kind_color(kind: int) -> Color`, `static shape_mesh(kind: int) -> Mesh`, `box_visible() -> bool`, `shape_visible() -> bool`, `shadow_visible() -> bool`
  - `ItemLayer` (Node3D): `setup(config: GameConfig)`, `sync(prev_items: Array, curr_items: Array, alpha: float, tick: int)`, `view_count() -> int`, `view(id: int) -> ItemView`
  - `ToonMaterials.translucent(color: Color) -> StandardMaterial3D` (색별 캐시, 수정 금지)
  - `DS.GROUND_SHADOW` (deep teal 40%)
  - `FighterView.held_visible() -> bool`, `FighterView.dots_shown() -> int`
- 근거: `[DS-VIS-05]` `[PRD-ITEM-01~04]` `[DS-GOV-02]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_item_view.gd`:
```gdscript
extends GutTest
## Item visuals (design.md DS-VIS-05).


func _item(id: int, kind: int, state: int, pos: Vector3, fuse: int = Item.UNLIT) -> Dictionary:
	return {"id": id, "kind": kind, "state": state, "pos": pos, "uses": 5, "fuse_ticks": fuse}


func test_shadow_grows_as_the_box_falls() -> void:
	assert_almost_eq(ItemView.shadow_scale(12.0, 12.0), ItemView.SHADOW_MIN_SCALE, 0.0001)
	assert_almost_eq(ItemView.shadow_scale(0.0, 12.0), 1.0, 0.0001)
	assert_gt(ItemView.shadow_scale(3.0, 12.0), ItemView.shadow_scale(9.0, 12.0))


func test_fuse_blinks_only_when_lit() -> void:
	assert_false(ItemView.fuse_visible(Item.UNLIT, 0))
	var seen := {}
	for t: int in 60:
		seen[ItemView.fuse_visible(60, t)] = true
	assert_eq(seen.size(), 2, "a lit fuse blinks on and off")


func test_kind_colors_are_point_colors() -> void:
	assert_eq(ItemView.kind_color(Item.Kind.BOMB), DS.BERRY)
	for kind: int in [Item.Kind.BAT, Item.Kind.BOMB, Item.Kind.ROCK]:
		assert_ne(ItemView.kind_color(kind), DS.GRASS, "items must stand out from the grass")


func test_falling_box_shows_box_and_shadow_then_the_item() -> void:
	var v := ItemView.new()
	add_child_autofree(v)
	v.setup(Item.Kind.BAT, GameConfig.new())
	var falling := _item(0, Item.Kind.BAT, Item.State.FALLING, Vector3(1, 6, 1))
	v.apply(falling, falling, 1.0, 0)
	assert_true(v.box_visible())
	assert_true(v.shadow_visible())
	assert_false(v.shape_visible())
	var ground := _item(0, Item.Kind.BAT, Item.State.GROUND, Vector3(1, 0, 1))
	v.apply(falling, ground, 1.0, 1)
	assert_false(v.box_visible())
	assert_false(v.shadow_visible())
	assert_true(v.shape_visible())


func test_layer_tracks_items_by_id() -> void:
	var layer := ItemLayer.new()
	add_child_autofree(layer)
	layer.setup(GameConfig.new())
	var a := _item(3, Item.Kind.ROCK, Item.State.GROUND, Vector3.ZERO)
	var b := _item(4, Item.Kind.BOMB, Item.State.GROUND, Vector3(1, 0, 0))
	layer.sync([], [a, b], 1.0, 0)
	assert_eq(layer.view_count(), 2)
	layer.sync([a, b], [b], 1.0, 1)
	assert_eq(layer.view_count(), 1, "a picked-up item's view goes away")
	assert_not_null(layer.view(4))


func test_layer_interpolates_moving_items() -> void:
	var layer := ItemLayer.new()
	add_child_autofree(layer)
	layer.setup(GameConfig.new())
	var before := _item(1, Item.Kind.ROCK, Item.State.THROWN, Vector3(0, 1, 0))
	var after := _item(1, Item.Kind.ROCK, Item.State.THROWN, Vector3(2, 1, 0))
	layer.sync([before], [after], 0.5, 1)
	assert_eq(layer.view(1).position, Vector3(1, 1, 0))
```

`tests/unit/test_fighter_view.gd` 끝에 추가:
```gdscript


func _fighter_view_data(item_kind: int, uses: int) -> Dictionary:
	return {
		"id": 0, "spawn_id": 0, "pos": Vector3.ZERO, "facing": Vector3(0, 0, 1),
		"state": Fighter.State.IDLE, "invuln_ticks": 0, "item_kind": item_kind, "item_uses": uses,
	}


func test_held_bat_shows_with_use_dots() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new())
	var d := _fighter_view_data(Item.Kind.BAT, 3)
	v.apply(d, d, 1.0, 0)
	assert_true(v.held_visible())
	assert_eq(v.dots_shown(), 3)
	var rock := _fighter_view_data(Item.Kind.ROCK, 1)
	v.apply(rock, rock, 1.0, 1)
	assert_true(v.held_visible())
	assert_eq(v.dots_shown(), 0, "use dots are for bats only")
	var none := _fighter_view_data(Fighter.NONE, 0)
	v.apply(none, none, 1.0, 2)
	assert_false(v.held_visible())
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_item_view`
Expected: FAIL — `Identifier "ItemView" not declared`

- [ ] **Step 3: 토큰 + 반투명 머티리얼**

`src/ui/theme/tokens.gd`의 `UI_SURFACE_70` 줄 다음에:
```gdscript
## Soft ground shadows under falling boxes (design.md DS-VIS-05): deep teal at 40%.
const GROUND_SHADOW := Color("#17525A66")
```
`src/render/toon_materials.gd` 끝에 추가 (파일 머리 주석의 "One shared ShaderMaterial per (color, rim) pair."에 `, plus unshaded translucent materials for shadows and bubbles.`를 덧붙인다):
```gdscript
static var _translucent_cache: Dictionary = {}


## Unshaded alpha-blended material (ground shadows, guard bubbles). Shared: never mutate.
static func translucent(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _translucent_cache.has(key):
		return _translucent_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	_translucent_cache[key] = mat
	return mat
```

- [ ] **Step 4: ItemView 작성**

`src/render/item_view.gd`:
```gdscript
class_name ItemView
extends Node3D
## One loose item (design.md DS-VIS-05): a cream box while falling, with a soft round shadow on
## the ground below that grows as it drops (the race starts here), then the item's own shape in
## a point color with a glow rim. A lit bomb blinks its fuse. Reads item view values only.

const RIM := 0.45
const BOX_SIZE := 0.7
const BAT_RADIUS := 0.1
const BAT_LENGTH := 0.9
const BOMB_RADIUS := 0.3
const ROCK_RADIUS := 0.24
const FUSE_RADIUS := 0.09
const SHADOW_RADIUS := 0.6
const SHADOW_HEIGHT := 0.01
const SHADOW_LIFT := 0.02
const SHADOW_MIN_SCALE := 0.4
const FUSE_BLINK_HZ := 4.0

var _config: GameConfig
var _box: MeshInstance3D
var _shape: MeshInstance3D
var _fuse: MeshInstance3D
var _shadow: MeshInstance3D


static func kind_color(kind: int) -> Color:
	match kind:
		Item.Kind.BOMB:
			return DS.BERRY
		Item.Kind.ROCK:
			return DS.PETAL_BLUE
	return DS.PETAL_PINK


static func shape_mesh(kind: int) -> Mesh:
	match kind:
		Item.Kind.BAT:
			var bat := CapsuleMesh.new()
			bat.radius = BAT_RADIUS
			bat.height = BAT_LENGTH
			return bat
		Item.Kind.BOMB:
			var bomb := SphereMesh.new()
			bomb.radius = BOMB_RADIUS
			bomb.height = BOMB_RADIUS * 2.0
			return bomb
	var rock := SphereMesh.new()
	rock.radius = ROCK_RADIUS
	rock.height = ROCK_RADIUS * 1.6
	return rock


static func shadow_scale(height: float, drop_height: float) -> float:
	var t := 1.0 - clampf(height / maxf(drop_height, 0.01), 0.0, 1.0)
	return lerpf(SHADOW_MIN_SCALE, 1.0, t)


static func fuse_visible(fuse_ticks: int, tick: int) -> bool:
	if fuse_ticks <= 0:
		return false
	return floori(float(tick) * FUSE_BLINK_HZ * 2.0 / SimTime.TICK_RATE) % 2 == 0


func setup(kind: int, config: GameConfig) -> void:
	_config = config
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * BOX_SIZE
	_box = _mesh(box_mesh, ToonMaterials.toon(DS.STONE_CREAM, RIM))
	_box.position.y = BOX_SIZE * 0.5
	_shape = _mesh(shape_mesh(kind), ToonMaterials.toon(kind_color(kind), RIM))
	_shape.position.y = BOMB_RADIUS
	if kind == Item.Kind.BAT:
		_shape.rotation.z = PI * 0.5  # lies on the ground
	var fuse_mesh := SphereMesh.new()
	fuse_mesh.radius = FUSE_RADIUS
	fuse_mesh.height = FUSE_RADIUS * 2.0
	_fuse = _mesh(fuse_mesh, ToonMaterials.toon(DS.FIRE))
	_fuse.position.y = BOMB_RADIUS * 2.0 + FUSE_RADIUS
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_RADIUS
	disc.bottom_radius = SHADOW_RADIUS
	disc.height = SHADOW_HEIGHT
	_shadow = _mesh(disc, ToonMaterials.translucent(DS.GROUND_SHADOW))


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	var to: Vector3 = curr["pos"]
	position = (prev["pos"] as Vector3).lerp(to, alpha) if not prev.is_empty() else to
	var falling := int(curr["state"]) == Item.State.FALLING
	_box.visible = falling
	_shape.visible = not falling
	_shadow.visible = falling
	if falling:
		_shadow.position.y = SHADOW_LIFT - position.y
		var s := shadow_scale(position.y, _config.item_drop_height)
		_shadow.scale = Vector3(s, 1.0, s)
	_fuse.visible = not falling and fuse_visible(int(curr["fuse_ticks"]), tick)


func box_visible() -> bool:
	return _box.visible


func shape_visible() -> bool:
	return _shape.visible


func shadow_visible() -> bool:
	return _shadow.visible


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	add_child(m)
	return m
```

- [ ] **Step 5: ItemLayer 작성**

`src/render/item_layer.gd`:
```gdscript
class_name ItemLayer
extends Node3D
## One ItemView per item id, interpolated prev -> curr like fighters. A new id (a fresh box, or a
## thrown item that was picked up) gets a new view, so nothing slides across the map.

var _config: GameConfig
var _views: Dictionary = {}


func setup(config: GameConfig) -> void:
	_config = config


func sync(prev_items: Array, curr_items: Array, alpha: float, tick: int) -> void:
	var prev_by_id := {}
	for it: Dictionary in prev_items:
		prev_by_id[int(it["id"])] = it
	var alive := {}
	for it: Dictionary in curr_items:
		var id := int(it["id"])
		alive[id] = true
		if not _views.has(id):
			var v := ItemView.new()
			add_child(v)
			v.setup(int(it["kind"]), _config)
			_views[id] = v
		(_views[id] as ItemView).apply(prev_by_id.get(id, {}), it, alpha, tick)
	for id: int in _views.keys():
		if not alive.has(id):
			(_views[id] as ItemView).queue_free()
			_views.erase(id)


func view_count() -> int:
	return _views.size()


func view(id: int) -> ItemView:
	return _views.get(id)
```

- [ ] **Step 6: FighterView — 든 아이템과 사용 횟수 점**

`src/render/fighter_view.gd`:
- 상수 추가:
```gdscript
const HELD_SCALE := 0.75
const HAND_SIDE := 0.9
const HAND_FORWARD := 0.4
const DOT_RADIUS := 0.06
const DOT_SPACING := 0.16
const DOT_GAP := 0.25
```
- 필드 추가: `var _held: MeshInstance3D`, `var _held_kind: int = Fighter.NONE`, `var _dots: Array[MeshInstance3D] = []`
- `setup` 끝에 추가:
```gdscript
	_held = MeshInstance3D.new()
	_held.scale = Vector3.ONE * HELD_SCALE
	_held.position = Vector3(config.fighter_radius * HAND_SIDE,
			config.fighter_height * ItemActions.HAND_HEIGHT_RATIO, config.fighter_radius * HAND_FORWARD)
	_held.visible = false
	add_child(_held)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = DOT_RADIUS
	dot_mesh.height = DOT_RADIUS * 2.0
	for i: int in config.bat_uses:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = ToonMaterials.toon(DS.GLOW)
		dot.position = Vector3((i - (config.bat_uses - 1) * 0.5) * DOT_SPACING, config.fighter_height + DOT_GAP, 0.0)
		dot.visible = false
		add_child(dot)
		_dots.append(dot)
```
- `apply`의 끝(`_body.visible = ...` 다음)에 `_show_item(int(curr.get("item_kind", Fighter.NONE)), int(curr.get("item_uses", 0)))`
- 함수 추가:
```gdscript
func _show_item(kind: int, uses: int) -> void:
	_held.visible = kind != Fighter.NONE
	if kind != Fighter.NONE and kind != _held_kind:
		_held.mesh = ItemView.shape_mesh(kind)
		_held.material_override = ToonMaterials.toon(ItemView.kind_color(kind), ItemView.RIM)
	_held_kind = kind
	for i: int in _dots.size():
		_dots[i].visible = kind == Item.Kind.BAT and i < uses


func held_visible() -> bool:
	return _held.visible


func dots_shown() -> int:
	var n := 0
	for dot: MeshInstance3D in _dots:
		if dot.visible:
			n += 1
	return n
```
- 머리 주석 끝에 `Shows the carried item in hand, with use dots for bats (DS-VIS-05).` 추가

- [ ] **Step 7: 갤러리 아이템 미리보기**

`src/debug/ds_gallery.gd`:
- `_ready()`의 `col.add_child(_toon_preview())` 다음에:
```gdscript
		col.add_child(_heading("Items · DS-VIS-05 (box + shadow / bat / bomb lit / rock)"))
		col.add_child(_items_preview())
```
- 함수 추가 (`_toon_preview`와 같은 SubViewport 구성):
```gdscript
func _items_preview() -> Control:
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
	var config := GameConfig.new()
	var samples: Array[Dictionary] = [
		{"id": 0, "kind": Item.Kind.ROCK, "state": Item.State.FALLING, "pos": Vector3(-3, 3, 0), "uses": 1, "fuse_ticks": Item.UNLIT},
		{"id": 1, "kind": Item.Kind.BAT, "state": Item.State.GROUND, "pos": Vector3(-1, 0, 0), "uses": 5, "fuse_ticks": Item.UNLIT},
		{"id": 2, "kind": Item.Kind.BOMB, "state": Item.State.GROUND, "pos": Vector3(1, 0, 0), "uses": 1, "fuse_ticks": 60},
		{"id": 3, "kind": Item.Kind.ROCK, "state": Item.State.GROUND, "pos": Vector3(3, 0, 0), "uses": 1, "fuse_ticks": Item.UNLIT},
	]
	for s: Dictionary in samples:
		var v := ItemView.new()
		vp.add_child(v)
		v.setup(int(s["kind"]), config)
		v.apply(s, s, 1.0, 0)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 6, 7), Vector3(0, 0.5, 0), Vector3.UP)
	return container
```

- [ ] **Step 8: 테스트 + 갤러리 캡처**

Run: `./scripts/test.sh`
Expected: 전부 PASS.
Run (창 모드): `godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ds_gallery.tscn --out="$PWD/dev/active/phase-2/evidence/gallery-items.png" --frames=30`
(전체 갤러리가 한 화면을 넘으면 스크롤 위쪽만 찍힌다 — 아이템 미리보기가 안 보이면 `--components-only`처럼 `--items-only` 인자를 `ds_gallery.gd`에 추가해 아이템 섹션만 그리게 하고 그 인자로 찍는다.)

- [ ] **Step 9: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/render/item_view.gd src/render/item_view.gd.uid src/render/item_layer.gd src/render/item_layer.gd.uid src/render/toon_materials.gd src/ui/theme/tokens.gd src/render/fighter_view.gd src/debug/ds_gallery.gd tests/unit/test_item_view.gd tests/unit/test_item_view.gd.uid tests/unit/test_fighter_view.gd dev/active/phase-2/evidence/gallery-items.png
git commit -m "feat: draw item boxes, drop shadows, item shapes and held items" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: 가드 버블 + 잡기 대상 표시 (DS-VFX-02)

**Files:**
- Create: `src/render/grab_hint.gd`
- Modify: `src/render/fighter_view.gd` (가드 버블, `wobble`), `src/ui/theme/tokens.gd` (`GUARD_BUBBLE`)
- Test: `tests/unit/test_fighter_view.gd`, `tests/unit/test_grab_hint.gd` (신규)

**Interfaces:**
- Consumes: T16 `ToonMaterials.translucent`, T14 `GrabContext` (T19에서 연결)
- Produces:
  - `FighterView.bubble_visible() -> bool` (state == GUARD일 때), `FighterView.wobble() -> void` (guard_hit 때 비눗방울 출렁임, T19 FeelDirector가 호출)
  - `GrabHint` (Node3D): `setup(config: GameConfig)`, `show_at(pos: Vector3) -> void`, `hide_hint() -> void`, `is_shown() -> bool`
  - `DS.GUARD_BUBBLE` (sky 40%)
- 근거: `[DS-VFX-02]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_fighter_view.gd` 끝에 추가:
```gdscript


func test_guard_bubble_follows_the_guard_state() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new())
	var guard := _fighter_view_data(Fighter.NONE, 0)
	guard["state"] = Fighter.State.GUARD
	v.apply(guard, guard, 1.0, 0)
	assert_true(v.bubble_visible())
	v.wobble()
	var idle := _fighter_view_data(Fighter.NONE, 0)
	v.apply(idle, idle, 1.0, 1)
	assert_false(v.bubble_visible())
```

`tests/unit/test_grab_hint.gd`:
```gdscript
extends GutTest


func test_show_and_hide() -> void:
	var hint := GrabHint.new()
	add_child_autofree(hint)
	hint.setup(GameConfig.new())
	assert_false(hint.is_shown())
	hint.show_at(Vector3(2, 0, 3))
	assert_true(hint.is_shown())
	assert_eq(Vector2(hint.position.x, hint.position.z), Vector2(2, 3))
	hint.hide_hint()
	assert_false(hint.is_shown())
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_grab_hint`
Expected: FAIL — `Identifier "GrabHint" not declared`

- [ ] **Step 3: 토큰**

`src/ui/theme/tokens.gd`의 `GROUND_SHADOW` 다음에:
```gdscript
## Guard bubble (design.md DS-VFX-02): sky at 40%, a soap bubble around the guarding fighter.
const GUARD_BUBBLE := Color("#C4E8F666")
```

- [ ] **Step 4: FighterView 가드 버블**

`src/render/fighter_view.gd`:
- 상수: `const BUBBLE_RADIUS_RATIO := 0.62`, `const WOBBLE_SQUASH := Vector3(1.12, 0.88, 1.12)`
- 필드: `var _bubble: MeshInstance3D`
- `setup` 끝에:
```gdscript
	var sphere := SphereMesh.new()
	sphere.radius = config.fighter_height * BUBBLE_RADIUS_RATIO
	sphere.height = sphere.radius * 2.0
	_bubble = MeshInstance3D.new()
	_bubble.mesh = sphere
	_bubble.material_override = ToonMaterials.translucent(DS.GUARD_BUBBLE)
	_bubble.position.y = config.fighter_height * 0.5
	_bubble.visible = false
	add_child(_bubble)
```
- `apply`의 `_show_item(...)` 다음 줄: `_bubble.visible = int(curr["state"]) == Fighter.State.GUARD`
- 함수:
```gdscript
## Soap-bubble wobble when a guarded hit lands (DS-VFX-02).
func wobble() -> void:
	_bubble.scale = WOBBLE_SQUASH
	var tw := create_tween()
	tw.tween_property(_bubble, "scale", Vector3.ONE, DS.MOTION_SQUISH).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func bubble_visible() -> bool:
	return _bubble.visible
```

- [ ] **Step 5: GrabHint 작성**

`src/render/grab_hint.gd`:
```gdscript
class_name GrabHint
extends Node3D
## "Grab can act on this" marker (design.md DS-VFX-02): a petal-yellow ring pulsing softly on
## the ground under the item or fighter the local player's grab button would take.

const RING_INNER_RATIO := 1.2
const RING_OUTER_RATIO := 1.5
const RING_FLATTEN := 0.06
const RING_LIFT := 0.03
const PULSE_HZ := 1.5
const PULSE_SCALE := 0.1

var _ring: MeshInstance3D
var _time: float = 0.0


func setup(config: GameConfig) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = config.fighter_radius * RING_INNER_RATIO
	torus.outer_radius = config.fighter_radius * RING_OUTER_RATIO
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = ToonMaterials.toon(DS.PETAL_YELLOW)
	_ring.position.y = RING_LIFT
	_ring.scale = Vector3(1.0, RING_FLATTEN, 1.0)
	add_child(_ring)
	visible = false


func show_at(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	visible = true


func hide_hint() -> void:
	visible = false


func is_shown() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible or _ring == null:
		return
	_time += delta
	var s := 1.0 + PULSE_SCALE * sin(_time * TAU * PULSE_HZ)
	_ring.scale = Vector3(s, RING_FLATTEN, s)
```

- [ ] **Step 6: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS.

- [ ] **Step 7: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/render/grab_hint.gd src/render/grab_hint.gd.uid src/render/fighter_view.gd src/ui/theme/tokens.gd tests/unit/test_fighter_view.gd tests/unit/test_grab_hint.gd tests/unit/test_grab_hint.gd.uid
git commit -m "feat: add guard bubble and grab target hint" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: 봇 2단계 — 가드·아이템·콤보·잡기

**Files:**
- Modify: `src/input/bot_controller.gd` (전면 교체)
- Modify: `tests/unit/test_bot.gd`, `tests/replay/test_bot_coverage.gd` (필수 이벤트 확장)

**Interfaces:**
- Consumes: T2 view 필드(`item_kind`, `invuln_ticks`, `state`), T7 view `items`, T1 `bot_guard_range`/`bot_guard_ticks`/`bot_item_seek_range`/`bot_throw_range`, `Item`, `Fighter.State`
- Produces: `BotController.sample(view: Dictionary) -> InputFrame` (시그니처 그대로). 우선순위: ① 낙하 복귀 ② 잡고 있으면 경기장 바깥 방향으로 던지기 ③ 가장자리 복귀 ④ 위협(사거리 안 상대의 공격·차지 시작)마다 번갈아 가드 `bot_guard_ticks`틱 ⑤ 콤보 연타 진행 ⑥ 돌멩이·폭탄을 들었으면 사거리 안에서 던지기 ⑦ 빈손이면 `bot_item_seek_range` 안 아이템으로 가서 줍기 ⑧ 가드 중인 상대는 잡기, 사거리 안이면 약공격(방망이면 휘두르기) + 콤보 연타, 아니면 접근
- 근거: `[PRD-BOT-02]` · PHASES 완료 기준 "상자가 떨어지면 플레이어와 봇이 서로 먼저 가려고 한다"

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_bot.gd` 수정:
- `_view` 헬퍼 교체 (Phase 2 view 필드 포함):
```gdscript
func _view(me_pos: Vector3, foe_pos: Vector3, me_on_ground: bool = true, jumps: int = 2) -> Dictionary:
	return {
		"arena_radius": 10.0,
		"items": [],
		"fighters": [
			{"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": Fighter.State.IDLE, "on_ground": true,
				"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0},
			{"id": 1, "pos": me_pos, "facing": Vector3(-1, 0, 0), "state": Fighter.State.IDLE, "on_ground": me_on_ground,
				"jumps_left": jumps, "item_kind": Fighter.NONE, "invuln_ticks": 0},
		],
	}


func _me(v: Dictionary) -> Dictionary:
	return v["fighters"][1]


func _foe(v: Dictionary) -> Dictionary:
	return v["fighters"][0]
```
- `test_attacks_in_range_then_waits_for_cooldown` 교체:
```gdscript
func test_attacks_in_range_mashes_the_combo_then_waits() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	assert_true(bot.sample(v).light, "in range and ready")
	var mash := 0
	while bot.sample(v).light:
		mash += 1
	assert_eq(mash, BotController.combo_mash_ticks(c), "keeps pressing through the combo buffer windows")
	var waited := mash + 1
	while not bot.sample(v).light:
		waited += 1
	# cooldown N set on the attack sample, decremented at the start of each later sample
	assert_eq(waited, c.bot_attack_cooldown_ticks - 1)
```
- 파일 끝에 추가:
```gdscript


func test_guards_every_other_attack_that_starts_in_range() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0))
	bot.sample(v)  # the bot swings first and starts its cooldown; ignore
	var calm := _view(Vector3(3.0, 0, 0), Vector3(0, 0, 0))
	for i: int in BotController.combo_mash_ticks(c) + 1:
		bot.sample(calm)
	var attacking := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0))
	_foe(attacking)["state"] = Fighter.State.ATTACK
	assert_true(bot.sample(attacking).guard, "first threat: guard")
	for i: int in c.bot_guard_ticks:
		bot.sample(calm)
	assert_false(bot.sample(attacking).guard, "second threat: no guard (every other)")


func test_walks_to_a_nearby_item_and_picks_it_up() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(-6, 0, 0))
	v["items"] = [{"id": 0, "kind": Item.Kind.BAT, "state": Item.State.GROUND, "pos": Vector3(4, 0, 0), "uses": 5, "fuse_ticks": Item.UNLIT}]
	var f := bot.sample(v)
	assert_gt(f.move_x, 0.9, "heads for the item, not the foe")
	_me(v)["pos"] = Vector3(3.5, 0, 0)
	assert_true(bot.sample(v).grab, "grabs to pick it up when in reach")


func test_ignores_lit_bombs_and_far_items() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(-6, 0, 0))
	v["items"] = [
		{"id": 0, "kind": Item.Kind.BOMB, "state": Item.State.GROUND, "pos": Vector3(2, 0, 0), "uses": 1, "fuse_ticks": 40},
		{"id": 1, "kind": Item.Kind.ROCK, "state": Item.State.GROUND, "pos": Vector3(0, 0, c.bot_item_seek_range + 1.0), "uses": 1, "fuse_ticks": Item.UNLIT},
	]
	assert_lt(bot.sample(v).move_x, 0.0, "goes for the foe instead")


func test_throws_a_rock_when_the_foe_is_in_range() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(-4, 0, 0))
	_me(v)["item_kind"] = Item.Kind.ROCK
	var f := bot.sample(v)
	assert_true(f.grab)
	assert_lt(f.move_x, 0.0, "aims at the foe")


func test_swings_a_bat_without_mashing() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	_me(v)["item_kind"] = Item.Kind.BAT
	assert_true(bot.sample(v).light)
	assert_false(bot.sample(v).light, "one swing per cooldown with a bat")


func test_grabs_a_guarding_foe() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	_foe(v)["state"] = Fighter.State.GUARD
	assert_true(bot.sample(v).grab)


func test_throws_a_held_foe_away_from_the_center() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(3, 0, 0), Vector3(4, 0, 0))
	_me(v)["state"] = Fighter.State.HOLDING
	var f := bot.sample(v)
	assert_true(f.grab)
	assert_gt(f.move_x, 0.9, "outward from the center")
```

`tests/replay/test_bot_coverage.gd` 수정:
```gdscript
## Event types a bot match must go through (bot step 2, Task 18).
const REQUIRED_EVENTS: Array[String] = ["hit", "ringout", "item_spawn", "item_land", "item_pickup", "guard_hit", "grab"]
```
그리고 `test_bot_match_covers_required_events` 끝에 추가:
```gdscript
	assert_true(seen.has("match_over"), "a bot match ends with a KO within 4 minutes")
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_bot`
Expected: FAIL — `combo_mash_ticks` 미정의, 가드·아이템 테스트 실패

- [ ] **Step 3: BotController 교체**

`src/input/bot_controller.gd`:
```gdscript
class_name BotController
extends RefCounted
## Bot step 2 (PRD §6.4): step 1 (approach, attack in range, retreat from the edge, recover) plus
## guarding every other attack that starts in range (so it can still be hit), racing for nearby
## items, swinging bats, throwing rocks and bombs at range, mashing the light combo, grabbing a
## guarding foe and throwing held fighters away from the center. Reads only state_view() values
## and produces InputFrames — never touches the sim. Deterministic (no randomness).

## Pick up when the item is this deep inside the pickup radius (a margin against rounding).
const PICKUP_REACH_RATIO := 0.8

var _self_id: int
var _config: GameConfig
var _cooldown: int = 0
var _combo_left: int = 0
var _guard_left: int = 0
var _guard_next_threat: bool = true
var _foe_was_threat: bool = false


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config


## Light presses after the first swing so hits 2 and 3 land inside the combo buffer.
static func combo_mash_ticks(config: GameConfig) -> int:
	return 2 * (config.light_startup_ticks + config.light_active_ticks + config.light_recovery_ticks)


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
	if int(me["state"]) == Fighter.State.HOLDING:
		var out := -to_center if to_center != Vector2.ZERO else Vector2(1, 0)
		return InputFrame.make(out.x, out.y, false, false, false, false, true)
	if flat.length() > radius * _config.bot_edge_ratio:
		return InputFrame.make(to_center.x, to_center.y)

	var foe := _nearest_foe(view, my_pos)
	if _update_guard(foe, my_pos):
		return InputFrame.make(0, 0, false, false, false, true)
	if _combo_left > 0:
		_combo_left -= 1
		return InputFrame.make(0, 0, false, true)

	var item_kind := int(me.get("item_kind", Fighter.NONE))
	if item_kind == Item.Kind.BOMB or item_kind == Item.Kind.ROCK:
		return _use_throwable(foe, my_pos)
	if item_kind == Fighter.NONE:
		var it := _nearest_item(view, my_pos)
		if not it.is_empty():
			var to_item := _flat_delta(my_pos, it["pos"])
			if to_item.length() <= _config.item_pickup_radius * PICKUP_REACH_RATIO and bool(me["on_ground"]):
				return InputFrame.make(0, 0, false, false, false, false, true)
			var d := to_item.normalized()
			return InputFrame.make(d.x, d.y)
	return _fight(foe, my_pos, item_kind)


## Starts a guard on every other new threat and keeps it for bot_guard_ticks.
func _update_guard(foe: Dictionary, my_pos: Vector3) -> bool:
	var threat := not foe.is_empty() and _flat_delta(my_pos, foe["pos"]).length() <= _config.bot_guard_range \
			and (int(foe["state"]) == Fighter.State.ATTACK or int(foe["state"]) == Fighter.State.CHARGE)
	if threat and not _foe_was_threat:
		if _guard_next_threat:
			_guard_left = _config.bot_guard_ticks
		_guard_next_threat = not _guard_next_threat
	_foe_was_threat = threat
	if _guard_left > 0:
		_guard_left -= 1
		return true
	return false


func _use_throwable(foe: Dictionary, my_pos: Vector3) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := _flat_delta(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if delta.length() <= _config.bot_throw_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	return InputFrame.make(dir.x, dir.y)


func _fight(foe: Dictionary, my_pos: Vector3, item_kind: int) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := _flat_delta(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	var reach := _config.grab_forward + _config.grab_half_width + _config.fighter_radius
	if int(foe["state"]) == Fighter.State.GUARD and delta.length() <= reach:
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	if delta.length() <= _config.bot_attack_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		if item_kind != Item.Kind.BAT:
			_combo_left = combo_mash_ticks(_config)
		return InputFrame.make(dir.x, dir.y, false, true)
	return InputFrame.make(dir.x, dir.y)


static func _find(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


static func _flat_delta(from: Vector3, to: Vector3) -> Vector2:
	return Vector2(to.x - from.x, to.z - from.z)


func _nearest_foe(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == _self_id or int(f["state"]) == Fighter.State.KO:
			continue
		var d := _flat_delta(my_pos, f["pos"]).length()
		if d < best_dist:
			best_dist = d
			best = f
	return best


func _nearest_item(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := _config.bot_item_seek_range
	for it: Dictionary in view.get("items", []):
		if int(it["state"]) != Item.State.GROUND or int(it["fuse_ticks"]) != Item.UNLIT:
			continue
		var d := _flat_delta(my_pos, it["pos"]).length()
		if d <= best_dist:
			best_dist = d
			best = it
	return best
```

- [ ] **Step 4: 테스트**

Run: `./scripts/test.sh`
Expected: `test_bot` 전부 PASS, `test_bot_coverage` PASS. 커버리지 테스트에서 특정 이벤트(`grab`, `guard_hit` 등)가 4분 안에 한 번도 안 나오면 기대값을 낮추지 말고, 어떤 이벤트가 몇 번 나왔는지 표로 보고하고 멈춘다 (컨트롤러가 봇 규칙 또는 수치를 판단). 리플레이 골든은 봇과 무관하므로 그대로.

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/input/bot_controller.gd tests/unit/test_bot.gd tests/replay/test_bot_coverage.gd
git commit -m "feat: bot step 2 with guarding, item racing, combos and grabs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 19: main 연결 — 아이템·게이지·잡기 표시·터치 강조, 연출, 재시작, HUD safe area

**Files:**
- Modify: `src/main/main.gd`, `src/render/feel/feel_director.gd`, `src/ui/hud.gd`
- Test: `tests/unit/test_main_smoke.gd`, `tests/unit/test_feel_director.gd` (신규), `tests/unit/test_hud.gd`

**Interfaces:**
- Consumes: T14 `GrabContext`, `TouchInput.set_grab_highlight`/`set_enabled`, T15 `ChargeGaugeLayer`, `CameraRig.unproject`, T16 `ItemLayer`, T17 `GrabHint`, `FighterView.wobble`, T12 `SafeArea`
- Produces:
  - `main.gd`: `get_hud() -> Hud`, `get_item_layer() -> ItemLayer` (테스트용)
  - `FeelDirector.reset() -> void`, `FeelDirector.shake_amplitude() -> float`; `guard_hit` → 작은 퍼프, `explosion` → 큰 퍼프 + 화면 흔들림(`shake_max × EXPLOSION_SHAKE_RATIO`)
  - `Hud.frame_margin(side: String) -> int` — safe area 반영 여백
- 근거: `[PRD-UI-01]` `[DS-LAY-02]` `[DS-VFX-01]` `[DS-VFX-02]` · Phase 1 이월(재시작 시 흔들림 초기화, main 재시작 테스트, HUD safe area)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_feel_director.gd`:
```gdscript
extends GutTest


func test_reset_stops_the_shake() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	feel.on_events([{"type": "ringout", "id": 1, "pos": Vector3.ZERO, "stocks_left": 2}])
	feel._process(1.0 / 60.0)
	assert_gt(feel.shake_amplitude(), 0.0)
	feel.reset()
	assert_eq(feel.shake_amplitude(), 0.0, "a restart starts calm")


func test_explosion_shakes_and_guard_hit_puffs() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	feel.on_events([{"type": "guard_hit", "attacker": 0, "target": 1, "pos": Vector3(0, 1, 0), "knockback": 0.0, "hitstop_ticks": 4, "power": 1.0}])
	assert_eq(feel.get_child_count(), 1, "a small puff for a guarded hit")
	feel.on_events([{"type": "explosion", "id": 0, "pos": Vector3.ZERO, "radius": c.bomb_radius}])
	feel._process(1.0 / 60.0)
	assert_gt(feel.shake_amplitude(), 0.0)
	assert_eq(feel.get_child_count(), 2)
```

`tests/unit/test_hud.gd` 끝에 추가:
```gdscript


func test_frame_keeps_the_s5_margin_inside_the_safe_area() -> void:
	# desktop: the safe area is the whole viewport, so the margin is exactly s5
	assert_eq(_hud.frame_margin("left"), DS.S5)
	assert_eq(_hud.frame_margin("top"), DS.S5)
```

`tests/unit/test_main_smoke.gd` 끝에 추가:
```gdscript


func test_restart_after_a_ko_starts_a_clean_match() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_seconds(0.2)
	var hud: Hud = main.call("get_hud")
	assert_true(hud.result_visible(), "the KO ends the match and shows the result")
	hud.restart_requested.emit()
	await wait_frames(1)
	var fresh: World = main.call("get_world")
	assert_ne(fresh, w, "a new world")
	assert_false(hud.result_visible())
	assert_eq(hud.counter_text(1), "0%")
	assert_lt(fresh.tick_count, 30, "the new match just started")


func test_items_in_the_world_get_views() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.items.add(Item.Kind.BOMB, Vector3(0, 0, 0), Item.State.GROUND, w.config)
	await wait_seconds(0.1)
	var layer: ItemLayer = main.call("get_item_layer")
	assert_eq(layer.view_count(), 1)
```

- [ ] **Step 2: 실패 확인**

Run: `./scripts/test.sh -gselect=test_feel_director`
Expected: FAIL — `Invalid call. Nonexistent function 'shake_amplitude'`

- [ ] **Step 3: FeelDirector**

`src/render/feel/feel_director.gd` 교체:
```gdscript
class_name FeelDirector
extends Node3D
## Turns sim events into game feel (design.md §9): hit puffs sized by knockback, screen shake that
## starts when hitstop ends, a full-strength shake on ring-out, a small puff on guarded hits and a
## large puff plus shake on bomb explosions. Render-side only.

## Explosion shake as a fraction of shake_max.
const EXPLOSION_SHAKE_RATIO := 0.8

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
				_spark(e["pos"], kb >= _config.spark_large_threshold)
				_shake.add(kb, float(e["hitstop_ticks"]) / SimTime.TICK_RATE)
			"guard_hit":
				_spark(e["pos"], false)
			"explosion":
				_spark(e["pos"], true)
				_shake.add(_full_shake_knockback() * EXPLOSION_SHAKE_RATIO, 0.0)
			"ringout":
				_shake.add(_full_shake_knockback(), 0.0)


## A restart starts with a still camera (Phase 1 carry-over).
func reset() -> void:
	_shake = ShakeModel.new(_config)
	if _camera != null:
		_camera.set_shake_offset(Vector3.ZERO)


func shake_amplitude() -> float:
	return _shake.amplitude()


func _process(delta: float) -> void:
	if _shake == null:
		return
	var offset := _shake.update(delta)
	if _camera != null:
		_camera.set_shake_offset(offset)


func _spark(at: Vector3, large: bool) -> void:
	var spark := HitSpark.new()
	add_child(spark)
	spark.play(at, large)


## The knockback whose shake reaches shake_max.
func _full_shake_knockback() -> float:
	return _config.shake_max / maxf(_config.shake_per_knockback, 0.0001)
```

- [ ] **Step 4: HUD safe area**

`src/ui/hud.gd`:
- 필드 `var _margin: MarginContainer`
- `_build_frame`에서 `var margin := MarginContainer.new()` → `_margin = MarginContainer.new()`로 바꾸고 이후 `margin` 참조를 `_margin`으로, `for side ... add_theme_constant_override` 루프를 삭제하고 그 자리에 `_apply_safe_area()` 호출, 함수 끝에 `get_viewport().size_changed.connect(_apply_safe_area)` 추가
- 함수 추가:
```gdscript
## Keeps the s5 margin inside the device safe area (DS-LAY-02, Phase 1 carry-over).
func _apply_safe_area() -> void:
	var vp := get_viewport().get_visible_rect()
	var safe := SafeArea.rect(get_viewport())
	_margin.add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S5)
	_margin.add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S5)
	_margin.add_theme_constant_override("margin_top", int(safe.position.y - vp.position.y) + DS.S5)


func frame_margin(side: String) -> int:
	return _margin.get_theme_constant("margin_" + side)
```

- [ ] **Step 5: main 연결**

`src/main/main.gd` 교체:
```gdscript
extends Node
## Entry point: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4).
## Phase 2: local player (keyboard + four-button touch) vs bot step 2, items, HUD, charge gauges,
## grab hints, game feel, result and restart.

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
var _touch: TouchInput
var _bot: BotController
var _views: Array[FighterView] = []
var _item_layer: ItemLayer
var _grab_hint: GrabHint
var _gauges: ChargeGaugeLayer
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
	_item_layer = ItemLayer.new()
	add_child(_item_layer)
	_item_layer.setup(_config)
	_grab_hint = GrabHint.new()
	add_child(_grab_hint)
	_grab_hint.setup(_config)

	_local_input = LocalInput.new()
	_touch = TouchInput.new()
	add_child(_touch)
	_touch.setup(_local_input, _config)
	_gauges = ChargeGaugeLayer.new()
	add_child(_gauges)
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


func get_hud() -> Hud:
	return _hud


func get_item_layer() -> ItemLayer:
	return _item_layer


func _start_match() -> void:
	_local_input.reset()
	_feel.reset()
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
	_item_layer.sync(_prev_state["items"], _curr_state["items"], _alpha, int(_curr_state["tick"]))
	_hud.update_from(_curr_state)
	_feel.on_events(events)
	_wobble_guards(events)
	_update_local_hints()
	_camera.follow(_camera_targets(), delta)
	_gauges.update_from(_curr_state, _config, _camera.unproject)
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


func _wobble_guards(events: Array) -> void:
	for e: Dictionary in events:
		if String(e["type"]) == "guard_hit":
			var id := int(e["target"])
			if id < _views.size():
				_views[id].wobble()


## Grab button highlight, grab target ring and disabled touch buttons for the local player.
func _update_local_hints() -> void:
	var me: Dictionary = _curr_state["fighters"][LOCAL_PLAYER]
	var active := int(me["state"]) != Fighter.State.KO and not bool(_curr_state["match_over"])
	_touch.set_enabled(active)
	var ctx := GrabContext.evaluate(_curr_state, LOCAL_PLAYER, _config)
	var kind := int(ctx["kind"])
	_touch.set_grab_highlight(active and kind != GrabContext.Kind.NONE)
	if active and (kind == GrabContext.Kind.ITEM or kind == GrabContext.Kind.FIGHTER):
		_grab_hint.show_at(ctx["pos"])
	else:
		_grab_hint.hide_hint()


func _camera_targets() -> PackedVector3Array:
	var r := _config.arena_radius
	var pts := PackedVector3Array([Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, -r), Vector3(0, 0, r)])
	for f: Dictionary in _curr_state["fighters"]:
		if int(f["state"]) != Fighter.State.KO:
			pts.append(f["pos"])
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

- [ ] **Step 6: 테스트**

Run: `./scripts/test.sh`
Expected: 전부 PASS (`ringout_demo.gd`는 main을 상속하므로 함께 로드돼야 한다).

- [ ] **Step 7: 화면 증거**

Run (창 모드):
```bash
godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out="$PWD/dev/active/phase-2/evidence/match-hud-touch.png" --show-touch --frames=120
```
Expected: 4버튼(선택된 레이아웃)·HUD·경기장 전체가 보이는 스크린샷. 컨트롤러가 확인한다.

- [ ] **Step 8: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/main/main.gd src/render/feel/feel_director.gd src/ui/hud.gd tests/unit/test_main_smoke.gd tests/unit/test_feel_director.gd tests/unit/test_feel_director.gd.uid tests/unit/test_hud.gd dev/active/phase-2/evidence/match-hud-touch.png
git commit -m "feat: wire items, charge gauges, grab hints and touch states into the match" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 20: 상자 쟁탈 데모 + 측정 + Phase 2 마감

**Files:**
- Create: `src/debug/item_race_demo.gd`, `src/debug/item_race_demo.tscn`, `dev/active/phase-2/evidence/measurements.md`
- Modify: `docs/PHASES.md` (Phase 2 체크), `docs/design.md` (§12 상태, 버전), `docs/PRD.md` (§4.5 표에 Phase 2 수치), `dev/active/phase-2/phase-2-context.md`, `dev/active/phase-2/phase-2-tasks.md`
- (`git mv dev/active/phase-2 dev/done/phase-2`는 **하지 않는다** — 컨트롤러가 최종 리뷰 뒤에 한다)

**Interfaces:**
- Consumes: 전부
- Produces: 증거 영상·스크린샷·측정 기록, 문서 추적성 갱신
- 근거: PHASES Phase 2 완료 기준, README R3·R4·R6

- [ ] **Step 1: 상자 쟁탈 데모 씬**

`src/debug/item_race_demo.gd`:
```gdscript
extends "res://src/main/main.gd"
## Phase 2 evidence scene (PHASES Phase 2 "상자가 떨어지면 서로 먼저 가려고 한다"): both fighters
## are step-2 bots standing on opposite sides; a bat box drops between them at DROP_TICK, so the
## video shows both racing for it.

const DROP_TICK := 60
const START_X := 6.0
const DROP_OFFSET := Vector3(0, 0, 0.5)

var _p1_bot: BotController


func _start_match() -> void:
	super._start_match()
	_p1_bot = BotController.new(LOCAL_PLAYER, _config)
	var w := get_world()
	w.fighters[LOCAL_PLAYER].pos = Vector3(-START_X, 0, 0)
	w.fighters[BOT_PLAYER].pos = Vector3(START_X, 0, 0)


func _gather_inputs() -> Array[InputFrame]:
	var w := get_world()
	if w.tick_count == DROP_TICK:
		w.items.add(Item.Kind.BAT, DROP_OFFSET + Vector3.UP * _config.item_drop_height, Item.State.FALLING, _config)
	var inputs: Array[InputFrame] = [_p1_bot.sample(_curr_state), _bot.sample(_curr_state)]
	return inputs
```
`src/debug/item_race_demo.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/debug/item_race_demo.gd" id="1"]

[node name="ItemRaceDemo" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 녹화 + 핵심 프레임**

```bash
godot --path . --write-movie dev/active/phase-2/evidence/item-race.avi --fixed-fps 60 --resolution 960x540 --quit-after 360 res://src/debug/item_race_demo.tscn
for f in 50 100 130 160; do ffmpeg -loglevel error -y -i dev/active/phase-2/evidence/item-race.avi -vf "select=eq(n\,$f)" -vframes 1 dev/active/phase-2/evidence/item-race-$f.png; done
```
Expected: 50(상자 낙하 시작·그림자) / 100(둘 다 가운데로 달림) / 130(착지 직후 쟁탈) / 160(한쪽이 방망이를 듦) 네 장. 실제 착지·줍기 프레임이 다르면 번호를 조정하고 보고서에 적는다. `item-race.avi`는 gitignore(로컬 보관).

- [ ] **Step 3: 측정**

```bash
godot --headless --path . -s res://scripts/bench_sim.gd
godot --headless --path . -s res://scripts/measure_input_latency.gd
godot --headless --path . -s res://scripts/tune_knockback.gd
```
`dev/active/phase-2/evidence/measurements.md`:
```markdown
# Phase 2 측정 (YYYY-MM-DD)

| 항목 | Phase 1 | Phase 2 | 명령 |
|---|---|---|---|
| 4인 World 1틱 평균 / 최악 (µs) | 22.2 / 372 | <bench 출력> | `scripts/bench_sim.gd` |
| 입력 → 상태 반영 (프레임) | 2 | <출력> | `scripts/measure_input_latency.gd` |
| 링아웃 최소 global_knockback_mul (3타 콤보, 100%) | 1.471 (약공격 1타) | <출력> | `scripts/tune_knockback.gd` |

- 테스트: <N>개 통과 (`./scripts/test.sh`), `check-all.sh` 통과
- 리플레이 골든: <GOLDEN_HASH> (1200틱, E11)
```
(`bench_sim.gd`가 아이템을 포함하지 않으면 그대로 기록하고, 측정 조건을 한 줄로 덧붙인다.)

- [ ] **Step 4: 문서 갱신**

- `docs/PHASES.md` Phase 2:
  - ⚙️·🎨 항목: 구현·리뷰된 항목 체크. 🖼 4버튼 시안 항목은 T13 결과에 따라 체크 또는 ` — Stitch 시안 대기 (T13)`
  - 완료 기준: "상자 쟁탈" ✅ + `evidence/item-race-*.png`·로컬 `item-race.avi`; "터치만으로 6액션" → ` — 실기기 확인 대기` (데스크톱 증거: `test_touch_input` + `match-hud-touch.png`); "인게임 UI가 전부 DS 컴포넌트" ✅ + 갤러리 캡처 경로; "리플레이 회귀 갱신·통과" ✅ + `tests/replay/*`
- `docs/design.md`: 버전 0.5, §12에서 DS-CMP-04 ✅(v2), DS-CMP-05 ✅, DS-VFX-02 ✅, DS-VIS-05 ✅, DS-LAY-01은 T13 결과에 따라 ✅ 또는 🟨
- `docs/PRD.md` §4.5 표 끝에 행 추가 (README R6):
  | combo_buffer_ticks / 연결타 대미지·넉백 | 10틱 / 3% · 1.5 (scaling 0) |
  | 잡기 유지 / 던지기 대미지·base·scaling | 1.5초 / 8% · 7 · 0.1 |
  | 상자 주기 / 필드 최대 | 10~15초 / 2개 |
  | 방망이 / 폭탄 / 돌멩이 대미지 | 10% (5회) / 15% (2초, 반경 2.5 m) / 6% |
  (T13·튜닝으로 값이 바뀌었으면 실제 기본값을 적는다)
- `dev/active/phase-2/phase-2-context.md`: 상태 "구현 완료, 최종 리뷰 대기", E1~E11 최종 상태, 측정값, 알려진 차이, "Phase 3으로 넘기는 항목"(같은 틱 상호 타격 편향, config 지문 범위, 실기기 확인 등 남은 것)
- `dev/active/phase-2/phase-2-tasks.md`: 상태 칸 갱신 (T13은 결과대로)

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh` → `ALL CHECKS PASSED` (docs traceability 포함)
```bash
git add src/debug/item_race_demo.gd src/debug/item_race_demo.gd.uid src/debug/item_race_demo.tscn dev/active/phase-2/evidence docs/PHASES.md docs/design.md docs/PRD.md dev/active/phase-2/phase-2-context.md dev/active/phase-2/phase-2-tasks.md
git commit -m "docs: close phase 2 with evidence and traceability" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
(`item-race.avi`는 gitignore라 `git add dev/active/phase-2/evidence`에 포함되지 않는다.)

---

## Self-Review (계획 작성자 점검 결과)

**PHASES Phase 2 커버리지:**

| PHASES 항목 | 태스크 |
|---|---|
| 약공격 3타 콤보 + 입력 버퍼 `[PRD-CMB-01]` | T3 |
| 강공격 + 차지 (최대 1초, 배율 1.6) `[PRD-CMB-02]` | T4 |
| 가드 (20%, 넉백 0), 가드 중 이동 불가 `[PRD-CMB-03]` | T5 |
| 잡기 → 던지기 (방향 입력) `[PRD-CMB-04]` | T6 |
| `items.gd` 상자 낙하 (10~15초, 시드 RNG), 줍기·들기·던지기 `[PRD-ITEM-01]` `[PRD-ARCH-05]` | T7 (`item_field.gd`로 이름), T8 |
| 방망이(5회)·폭탄(2초 범위)·돌멩이(투사체) `[PRD-ITEM-02~04]` | T8, T9 |
| 터치 4버튼: 탭/홀드, 가드, 잡기 `[PRD-CTL-03]` | T12, T14 |
| 키보드 6액션 `[PRD-CTL-02]` | T11 |
| 봇 2단계: 가드, 아이템 줍기 `[PRD-BOT-02]` | T18 |
| 🖼 4버튼 레이아웃 3안 비교 `[DS-LAY-01]` | T12 (3안 구현·캡처), T13 (게이트) |
| TouchButton v2 `[DS-CMP-04]` | T14 |
| ChargeGauge `[DS-CMP-05]` | T15 |
| 가드 버블, 잡기 가능 표시 `[DS-VFX-02]` | T17 (+ T14 버튼 강조) |
| 상자 낙하 예고 그림자, 들고 있음 표시, 아이템 임시 모델 `[DS-VIS-05]` | T16 |
| 테스트 6종 (콤보 버퍼 / 차지 배율 / 가드 / 방망이·폭탄 / 시드 / 터치 해석) | T3 / T4 / T5 / T8·T9 / T7 / T12 |
| 완료 기준 4개 | T20 (영상), T13·T20 (실기기), T14~T16·T20 (갤러리), T10 (리플레이) |

**이름 일관성 확인:** `AttackSet.Kind`, `Actions.try_start/start_attack/step_attack/step_charge/step_guard/charge_mul/stop_horizontal`, `Combat.apply_hit(target, attack, dir, power, config, at, source_id)`, `Grab.resolve/step/cleanup/find`, `Rules.clear_actions`, `ItemField.spawn_step/add/remove/views/to_data/from_data`, `ItemActions.pre_step/drop_from_disabled/nearest_pickable/HAND_HEIGHT_RATIO`, `ItemMotion.step`, `HoldLatch`, `LocalInput.press_grab/set_touch_heavy/set_touch_guard`, `AttackButtonModel.Result`, `TouchLayout.centers/Variant/BUTTONS`, `SafeArea.rect`, `TouchInput.buttons/button_center/set_grab_highlight/set_enabled/time_override`, `TouchButton.State/set_diameter/set_charge/charge/state`, `GrabContext.evaluate/Kind`, `ChargeGaugeLayer.update_from/gauge/HEAD_GAP`, `CameraRig.unproject`, `ItemLayer.sync/view/view_count`, `ItemView.shape_mesh/kind_color/shadow_scale/fuse_visible/RIM/SHADOW_MIN_SCALE`, `FighterView.wobble/bubble_visible/held_visible/dots_shown`, `GrabHint.show_at/hide_hint/is_shown`, `FeelDirector.reset/shake_amplitude`, `BotController.combo_mash_ticks` — 정의한 태스크와 사용하는 태스크의 시그니처가 같다.

**알려진 판단 지점 (구현 중 멈추고 보고):** T3 0% 콤보 링아웃 여부, T8·T10 골든 변화 원인, T18 봇 커버리지 이벤트 누락.
