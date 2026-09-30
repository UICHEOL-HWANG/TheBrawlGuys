# Phase 3 — 캐릭터와 연출 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캡슐과 같은 sim(행동 해시 불변) 위에 KayKit 치비 캐릭터·AnimationTree 애니메이션·소프트 툰 v2·VFX·합성 SFX·BGM 재생 시스템·품질 3단계·iOS 빌드를 얹고, 데스크톱 성능·빌드 크기·웹 툰 룩을 측정해 기록한다.

**Architecture:** sim은 손대지 않는다(F2). T1에서 config 지문을 sim 그룹으로 한정하고 "행동 해시"를 고정해, 이후 모든 태스크가 sim을 바꾸지 않았음을 테스트가 증명한다. 렌더 쪽은 `FighterView`가 캡슐 대신 `CharacterModel`(glb + 툰 머티리얼)과 `CharacterAnimator`(코드로 만든 AnimationTree 상태 머신)를 쓰고, 애니 상태는 순수 함수 `AnimMap`이 뷰 값에서 고른다. VFX·SFX는 sim 이벤트와 렌더 쪽 뷰 차이(`ViewEvents`)에서 발생한다. 오디오는 오프라인으로 구운 wav를 `SfxDirector`·`MusicDirector`가 재생한다.

**Tech Stack:** Godot 4.7.2 (GDScript 정적 타입, Mobile/Compatibility 렌더러), GUT 9.7.1, KayKit Adventurers 1.0 glb (CC0), ffmpeg, Google Chrome headless(웹 캡처), Xcode(iOS export)

**Spec:** [`docs/PRD.md`](../../../docs/PRD.md) §2·§6.3·§7 · [`docs/PHASES.md`](../../../docs/PHASES.md) Phase 3 · [`docs/design.md`](../../../docs/design.md) DS-VIS-01/02, DS-VFX-01~06, DS-SFX-01/02, DS-TOK-05, GD-ANIM-01, GD-FEEL-04 · 결정: [`phase-3-context.md`](./phase-3-context.md) F1~F11

## Global Constraints

- Godot 4.7.2, GDScript 정적 타입 필수 (`untyped_declaration` = 에러) — PRD §5.1
- **sim 동작 불변 (F2):** `src/sim/` 파일은 수정하지 않는다(T1은 `src/config/`의 지문만). T1 이후 `BEHAVIOR_HASH`와 `GOLDEN_HASH`는 어떤 태스크에서도 바뀌면 안 된다 — 바뀌면 멈추고 보고
- `src/sim/`은 Node·SceneTree·RenderingServer·Input·전역 난수·Time·OS·Engine·`load()` 금지 (`scripts/check-sim-purity.sh`)
- 렌더는 `state_view()` 값만 읽는다. 판정 캡슐은 그대로 (`fighter_radius` 0.45, `fighter_height` 1.6)
- 모든 튜닝 수치는 `GameConfig`(`@export_range`), 아트 디렉션 상수는 렌더·오디오 코드의 이름 붙은 const, 색·UI 크기는 `DS` 토큰만 (`scripts/check-colors.sh`: `src/**/*.gd|.tscn|.tres`에서 `Color(`·`"#rrggbb"` 금지, `tokens.gd`·`config_panel.gd`·`forest_theme.tres` 예외)
- 새 GameConfig 그룹은 `GameConfig.SIM_GROUPS` 또는 `NON_SIM_GROUPS`에 반드시 분류 (T1 테스트가 강제)
- 캐시된 `ToonMaterials` 머티리얼은 수정 금지 (필요하면 `duplicate()`)
- 외부 에셋은 `ASSETS.md`에 출처·라이선스 기록 (PRD-NFR-07). 다운로드는 컨트롤러가 사용자 승인을 받은 뒤에만
- 오디오: 16bit mono 44.1kHz wav, 레시피·시퀀스는 결정적(난수는 시드 고정 `RandomNumberGenerator`, 오디오 코드 한정)
- 빌드 크기: 모바일 ≤ 150MB, 웹 초기 로딩 ≤ 40MB — PRD-NFR-05
- 새 스크립트의 `.uid` 사이드카는 같은 커밋에 넣는다
- 커밋: `<type>: <description>` + 마지막 줄 `Co-Authored-By: Claude <모델> <noreply@anthropic.com>`
- 모든 태스크 끝에 `./scripts/check-all.sh` 통과
- 증거는 `dev/active/phase-3/evidence/` (영상 `.avi`·빌드 산출물은 gitignore). 이미지를 만들면 직접 열어 보고 보고서에 설명

---

## File Structure

```
src/
  config/game_config.gd              T1  (수정) SIM_GROUPS 지문 · T4 Look · T8 Quality · T9 FeelVfx · T12 Audio 그룹
  render/
    character/
      character_catalog.gd           T2  캐릭터 4종 경로·숨길 부속 노드 (조사 결과로 작성)
      anim_map.gd                    T3  AnimMap: 뷰 → AnimState
      anim_clips.gd                  T3  AnimClips: 상태별 후보 클립 해석
      character_model.gd             T5  CharacterModel: glb 인스턴스·툰 머티리얼·스케일·부속 숨김
      character_animator.gd          T6  CharacterAnimator: AnimationTree 상태 머신·타임라인 늘이기·히트스톱 정지
    shaders/soft_toon.gdshader       T4  (수정) 텍스처·글로벌 림·채도
    shaders/char_outline.gdshader    T4  캐릭터 전용 외곽선
    look_preset.gd                   T4  LookPreset A/B/C → 글로벌 유니폼
    toon_materials.gd                T4  (수정) character(texture) 머티리얼
    quality.gd                       T8  Quality: 단계 → 설정값, 적용
    blob_shadow.gd                   T8  발밑 블롭 그림자 (LOW)
    environment_rig.gd               T8  (수정) 품질 적용 지점
    fighter_view.gd                  T5·T6·T8 (수정) 캡슐 → 캐릭터
    item_view.gd / item_layer.gd     T10 (수정) 떨어뜨린 아이템은 상자 아님
    feel/
      view_events.gd                 T9  ViewEvents: prev/curr 뷰 차이 → landed/respawned/trail
      dust_puff.gd                   T9  착지 먼지 (DS-VFX-03)
      knockback_trail.gd             T9  넉백 궤적 (DS-VFX-04, GD-FEEL-04)
      ringout_burst.gd               T10 링아웃 물보라·별 폭발 (DS-VFX-05)
      respawn_beam.gd                T10 리스폰 햇살 기둥 (DS-VFX-06)
      charge_glow.gd                 T10 차지 광 (DS-VFX-06)
      feel_director.gd               T9·T10 (수정) 새 VFX 연결, 카메라 펀치
  audio/
    sfx_synth.gd                     T11 SfxSynth: sfxr류 합성 → PackedFloat32Array
    wav_writer.gd                    T11 WavWriter: 샘플 → AudioStreamWAV
    sfx_recipes.gd                   T11 SfxRecipes: 이름 → 파라미터
    audio_buses.gd                   T12 AudioBuses: Master/SFX/Music/UI 버스 보장
    sfx_director.gd                  T12 SfxDirector: 이벤트 → 효과음(피치·볼륨 = k)
    music_sequencer.gd               T13 MusicSequencer: 패턴 → 샘플 (임시곡)
    music_director.gd                T13 MusicDirector: 대전 루프 + 인텐스 레이어
  ui/ui_motion.gd                    T14 UiMotion: 모션 토큰 트윈
  main/main.gd                       T6·T8·T9·T12·T13 (수정) 연결
  debug/ds_gallery.gd                T15 (수정) VFX·SFX 프리뷰
  debug/perf_match.gd/.tscn          T17 4인 봇전 성능 씬
assets/
  characters/kaykit/*.glb            T2  (다운로드, CC0)
  characters/kaykit/animations.txt   T2  클립 목록
  sfx/*.wav                          T11 구운 효과음
  music/*.wav                        T13 임시 BGM
scripts/
  list_animations.gd                 T2  glb 클립·노드 조사
  bake_sfx.gd                        T11 효과음 굽기
  bake_music.gd                      T13 임시 BGM 굽기
  capture_evidence.gd                T4·T8 (수정) --look=A|B|C, --quality=N
  build_all.sh                       T16 Android·iOS·Web export
  check_build_size.sh                T16 크기 검사
  measure_fps.gd                     T17 품질 단계별 프레임 시간
  capture_web.sh                     T17 웹 빌드 헤드리스 Chrome 캡처
tests/
  unit/test_anim_map.gd, test_anim_clips.gd, test_character_model.gd, test_character_animator.gd,
       test_look_preset.gd, test_quality.gd, test_view_events.gd, test_vfx.gd, test_sfx_synth.gd,
       test_audio.gd, test_music.gd, test_ui_motion.gd  (+ 기존 파일 수정)
  replay/test_replay.gd              T1  (수정) BEHAVIOR_HASH
```

**경계 원칙:** 판단·계산은 정적 함수/RefCounted(테스트 대상), 노드는 그리기·재생만. 렌더·오디오는 `state_view()` 값과 이벤트만 읽는다.

**태스크 순서:** T1 (sim 가드) → T2 (에셋, 다운로드 승인 필요) → T3 → T4 → T5 → T6 → T7 🖼(사용자) · T8 → T9 → T10 (품질·VFX) · T11 → T12 → T13 (오디오) · T14 → T15 (UI·갤러리) · T16 → T17 (빌드·측정) · T18 마감

---

### Task 1: config 지문을 sim 그룹으로 한정 + 행동 해시(BEHAVIOR_HASH) 고정

**Files:**
- Modify: `src/config/game_config.gd` (`SIM_GROUPS`, `NON_SIM_GROUPS`, `fingerprint`, `group_names`)
- Modify: `tests/replay/test_replay.gd` (`BEHAVIOR_HASH` 테스트 추가, `GOLDEN_HASH` 갱신)
- Test: `tests/unit/test_game_config.gd`

**Interfaces:**
- Produces:
  - `const GameConfig.SIM_GROUPS: Array[String]` = `["Movement", "Fighter", "Arena", "Rules", "Knockback", "LightAttack", "Combo", "HeavyAttack", "Grab", "Items"]`
  - `const GameConfig.NON_SIM_GROUPS: Array[String]` = `["Bot", "Feel", "Loop", "Camera", "Touch"]` (T4·T8·T9·T12가 새 그룹을 여기에 추가)
  - `func GameConfig.fingerprint() -> int` — SIM_GROUPS에 속한 변수만 해시
  - `static func GameConfig.group_names() -> Array[String]` — 선언된 그룹 이름 순서대로
  - 리플레이 `BEHAVIOR_HASH` — 이후 Phase 3 전체에서 불변
- 근거: `[PRD-ARCH-05]` · PHASES Phase 3 테스트 "리플레이 해시가 Phase 2와 동일" · F1

- [ ] **Step 1: 행동 해시 테스트를 먼저 추가하고 현재 코드의 값으로 고정**

`tests/replay/test_replay.gd`에 상수와 함수를 추가한다 (`GOLDEN_HASH` 줄 아래에 상수, 파일 끝에 함수):
```gdscript
## Sim behavior without the config fingerprint (context F1). Fixed in Phase 3 Task 1 from the
## Phase 2 code before the fingerprint scope changed; it must never change during Phase 3
## (presentation work must not touch the sim).
const BEHAVIOR_HASH := 0
```
```gdscript


## Hash of each tick's snapshot with config_fp removed, so tuning outside the sim cannot move it.
static func _behavior_run(w: World, ticks: int) -> int:
	var seq: Array[int] = []
	for i: int in ticks:
		w.tick(_inputs_at(w.tick_count))
		var s: Dictionary = bytes_to_var(w.snapshot())
		s.erase("config_fp")
		seq.append(hash(s))
	return hash(seq)


func test_behavior_hash() -> void:
	var h := _behavior_run(World.new(GameConfig.new(), SEED), TICKS)
	assert_ne(BEHAVIOR_HASH, 0, "BEHAVIOR_HASH not set yet; set it to %d" % h)
	assert_eq(h, BEHAVIOR_HASH, "sim behavior changed; Phase 3 must not change it (got %d)" % h)
```
Run: `./scripts/test.sh -gselect=test_replay`
Expected: `test_behavior_hash`만 FAIL, 메시지에 `set it to <N>`. `BEHAVIOR_HASH := <N>`으로 바꾸고 재실행 → PASS.
커밋:
```bash
git add tests/replay/test_replay.gd
git commit -m "test: pin the phase 2 sim behavior hash" -m "BEHAVIOR_HASH is the per-tick snapshot hash without config_fp, taken before any Phase 3 change." -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

- [ ] **Step 2: 지문 범위 테스트 작성 (실패)**

`tests/unit/test_game_config.gd` 끝에 추가:
```gdscript


func test_fingerprint_ignores_presentation_groups() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.cam_pitch = 45.0
	b.touch_layout = 2
	b.shake_max = 0.1
	b.bot_attack_range = 3.0
	b.max_ticks_per_frame = 2
	assert_eq(a.fingerprint(), b.fingerprint(), "camera/touch/feel/bot/loop never change a replay")


func test_fingerprint_follows_sim_groups() -> void:
	for name: String in ["move_speed", "fighter_radius", "arena_radius", "stocks", "global_knockback_mul",
			"light_damage", "combo_buffer_ticks", "heavy_damage", "grab_hold_max_time", "bomb_radius"]:
		var a := GameConfig.new()
		var b := GameConfig.new()
		var v: Variant = b.get(name)
		b.set(name, v + 1 if typeof(v) == TYPE_INT else float(v) + 0.5)
		assert_ne(a.fingerprint(), b.fingerprint(), "%s is a sim value" % name)


func test_every_group_is_classified() -> void:
	for group: String in GameConfig.group_names():
		assert_true(GameConfig.SIM_GROUPS.has(group) or GameConfig.NON_SIM_GROUPS.has(group),
				"GameConfig group %s must be listed in SIM_GROUPS or NON_SIM_GROUPS" % group)
	for group: String in GameConfig.SIM_GROUPS:
		assert_false(GameConfig.NON_SIM_GROUPS.has(group), "%s listed twice" % group)
```
Run: `./scripts/test.sh -gselect=test_game_config`
Expected: FAIL — `SIM_GROUPS`/`group_names` 미정의 (파서 에러)

- [ ] **Step 3: 지문 구현**

`src/config/game_config.gd`의 `fingerprint()`와 그 주석을 교체한다:
```gdscript
## Groups whose values change the simulation. Only these enter the fingerprint (context F1):
## camera, touch, feel, bot, loop and later presentation groups never alter a replay, so they
## can be tuned or added without invalidating snapshots and replay hashes.
const SIM_GROUPS: Array[String] = [
	"Movement", "Fighter", "Arena", "Rules", "Knockback", "LightAttack", "Combo", "HeavyAttack", "Grab", "Items",
]
const NON_SIM_GROUPS: Array[String] = ["Bot", "Feel", "Loop", "Camera", "Touch"]


## Hash of every sim-group variable (Phase 1 D1, scoped in Phase 3 F1). Snapshots and replays
## store it so a run can only be restored or verified against the same sim tuning.
func fingerprint() -> int:
	var values: Array = []
	var group := ""
	for p: Dictionary in get_property_list():
		var usage := int(p["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			group = String(p["name"])
			continue
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and SIM_GROUPS.has(group):
			values.append([p["name"], get(p["name"])])
	return hash(values)


static func group_names() -> Array[String]:
	var names: Array[String] = []
	for p: Dictionary in GameConfig.new().get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_GROUP:
			names.append(String(p["name"]))
	return names
```

- [ ] **Step 4: 테스트 + 골든 갱신**

Run: `./scripts/test.sh`
Expected: 새 테스트 PASS, `test_behavior_hash` PASS(값 그대로), `test_golden_hash`만 FAIL. 출력 값으로 `GOLDEN_HASH` 갱신 → 전부 PASS. `test_behavior_hash`가 실패하면 멈추고 보고한다(지문 외의 무언가가 바뀐 것).

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/config/game_config.gd tests/unit/test_game_config.gd tests/replay/test_replay.gd
git commit -m "feat: scope the config fingerprint to sim groups" -m "GOLDEN_HASH regenerated: the fingerprint no longer hashes camera/touch/feel/bot/loop values. BEHAVIOR_HASH is unchanged, proving the sim itself did not change." -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 2: KayKit Adventurers 가져오기 + 조사 + CharacterCatalog

> **컨트롤러 선행 조건:** 이 태스크를 배정하기 전에 사용자에게 다운로드 승인을 받는다 — 파일 4개 `Knight.glb`(3.66MB), `Barbarian.glb`(3.61MB), `Mage.glb`(3.59MB), `Rogue.glb`(3.62MB), 출처 `github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0` (`addons/kaykit_character_pack_adventures/Characters/gltf/`), 라이선스 CC0 1.0. 승인 없이는 배정하지 않는다.

**Files:**
- Create: `assets/characters/kaykit/{Knight,Barbarian,Mage,Rogue}.glb` (+ Godot가 만드는 `.import`), `assets/characters/kaykit/LICENSE.txt`, `assets/characters/kaykit/animations.txt`
- Create: `scripts/list_animations.gd`, `src/render/character/character_catalog.gd`
- Modify: `ASSETS.md`
- Test: `tests/unit/test_character_catalog.gd`

**Interfaces:**
- Produces:
  - `CharacterCatalog.DIR := "res://assets/characters/kaykit/"`
  - `const CharacterCatalog.CHARACTERS: Array[Dictionary]` — 각 `{"name": String, "path": String, "hide": Array[String]}` (P1 Knight, P2 Barbarian, P3 Mage, P4 Rogue)
  - `static func CharacterCatalog.for_player(index: int) -> Dictionary` (index % 4)
  - `assets/characters/kaykit/animations.txt` — 캐릭터별 `클립이름<TAB>길이(초)` 목록, 이어서 `MeshInstance3D` 노드 경로 목록 (T3 후보·T5 숨김 판단 근거)
- 근거: `[PRD-FX-01]` `[PRD-NFR-07]` · F3

- [ ] **Step 1: 다운로드 (승인된 경우에만)**

```bash
mkdir -p assets/characters/kaykit
BASE=https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main
for c in Knight Barbarian Mage Rogue; do curl -fL -o assets/characters/kaykit/$c.glb "$BASE/addons/kaykit_character_pack_adventures/Characters/gltf/$c.glb"; done
curl -fL -o assets/characters/kaykit/LICENSE.txt "$BASE/LICENSE.txt"
ls -l assets/characters/kaykit
```
Expected: glb 4개 각 3.5~3.7MB (Git LFS 포인터처럼 수백 바이트면 멈추고 `https://media.githubusercontent.com/media/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/<같은 경로>`로 다시 받는다), LICENSE.txt에 "CC0".
Run: `godot --headless --path . --import` → 각 glb 옆에 `.import` 생성.

- [ ] **Step 2: 조사 스크립트 작성·실행**

`scripts/list_animations.gd`:
```gdscript
extends SceneTree
## Lists every animation clip (name, length) and MeshInstance3D path in the KayKit character
## scenes, writing assets/characters/kaykit/animations.txt (Phase 3 Task 2, context F4).
## Run: godot --headless --path . -s res://scripts/list_animations.gd

const DIR := "res://assets/characters/kaykit/"
const NAMES: Array[String] = ["Knight", "Barbarian", "Mage", "Rogue"]
const OUT := "res://assets/characters/kaykit/animations.txt"


func _init() -> void:
	var lines: PackedStringArray = []
	for n: String in NAMES:
		var scene := load(DIR + n + ".glb") as PackedScene
		if scene == null:
			push_error("list_animations: cannot load %s" % n)
			quit(1)
			return
		var root := scene.instantiate()
		lines.append("# %s" % n)
		var player := _find_player(root)
		if player == null:
			lines.append("  (no AnimationPlayer)")
		else:
			var clips := player.get_animation_list()
			for clip: StringName in clips:
				lines.append("anim\t%s\t%.3f" % [clip, player.get_animation(clip).length])
		for mesh_path: String in _mesh_paths(root, root):
			lines.append("mesh\t%s" % mesh_path)
		root.free()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("list_animations: wrote %s (%d lines)" % [OUT, lines.size()])
	quit(0)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c: Node in node.get_children():
		var p := _find_player(c)
		if p != null:
			return p
	return null


func _mesh_paths(root: Node, node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is MeshInstance3D:
		out.append(String(root.get_path_to(node)))
	for c: Node in node.get_children():
		out.append_array(_mesh_paths(root, c))
	return out
```
Run: `godot --headless --path . -s res://scripts/list_animations.gd`
Expected: `animations.txt` 생성. 보고서에 캐릭터별 클립 개수와 이름 전체, 메시 경로 전체를 붙인다.

- [ ] **Step 3: 실패하는 카탈로그 테스트 작성**

`tests/unit/test_character_catalog.gd`:
```gdscript
extends GutTest
## KayKit characters (context F3): four slots, loadable glb scenes with animations, and every
## hidden accessory name really exists in its scene.


func _mesh_names(node: Node, out: Array[String]) -> void:
	if node is MeshInstance3D:
		out.append(String(node.name))
	for c: Node in node.get_children():
		_mesh_names(c, out)


func test_four_player_slots_cycle() -> void:
	assert_eq(CharacterCatalog.CHARACTERS.size(), 4)
	assert_eq(CharacterCatalog.for_player(0)["name"], "Knight")
	assert_eq(CharacterCatalog.for_player(4)["name"], "Knight", "slots wrap around")


func test_every_character_loads_with_animations() -> void:
	for c: Dictionary in CharacterCatalog.CHARACTERS:
		var scene := load(String(c["path"])) as PackedScene
		assert_not_null(scene, String(c["path"]))
		var root := scene.instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, "%s has one AnimationPlayer" % c["name"])
		assert_gt((players[0] as AnimationPlayer).get_animation_list().size(), 20, "%s ships its clips" % c["name"])
		var meshes: Array[String] = []
		_mesh_names(root, meshes)
		for hidden: String in c["hide"]:
			assert_has(meshes, hidden, "%s: hidden accessory %s exists" % [c["name"], hidden])
		root.free()
```
Run: `./scripts/test.sh -gselect=test_character_catalog` → FAIL (`CharacterCatalog` 미정의).

- [ ] **Step 4: CharacterCatalog 작성 (조사 결과로 hide 목록 채우기)**

`src/render/character/character_catalog.gd` — `hide`에는 Step 2의 메시 목록 중 **무기·방패·모자·망토 같은 부속**(몸통·머리·팔·다리가 아닌 것)의 노드 이름을 넣는다. 판단 기준과 선택 결과를 보고서에 표로 적는다:
```gdscript
class_name CharacterCatalog
extends RefCounted
## KayKit Character Pack: Adventurers 1.0 (CC0, ASSETS.md) per player slot (context F3).
## Accessory meshes (weapons, shields, hats, capes) are hidden: fighters brawl bare-handed and
## carried items use FighterView's own hand mesh. Names come from scripts/list_animations.gd.

const DIR := "res://assets/characters/kaykit/"
const CHARACTERS: Array[Dictionary] = [
	{"name": "Knight", "path": DIR + "Knight.glb", "hide": []},
	{"name": "Barbarian", "path": DIR + "Barbarian.glb", "hide": []},
	{"name": "Mage", "path": DIR + "Mage.glb", "hide": []},
	{"name": "Rogue", "path": DIR + "Rogue.glb", "hide": []},
]


static func for_player(index: int) -> Dictionary:
	return CHARACTERS[posmod(index, CHARACTERS.size())]
```
(`"hide": []`를 조사 결과의 부속 이름 배열로 채운다. 예: `["Knight_Helmet", "1H_Sword", "Round_Shield"]` — 실제 이름은 animations.txt에 있는 그대로.)

- [ ] **Step 5: ASSETS.md 기록**

`ASSETS.md` 표에 행 추가:
```
| assets/characters/kaykit/{Knight,Barbarian,Mage,Rogue}.glb | KayKit Character Pack: Adventurers 1.0 — Kay Lousberg (github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | CC0 1.0 (assets/characters/kaykit/LICENSE.txt) | 3 |
```

- [ ] **Step 6: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS, `BEHAVIOR_HASH`·`GOLDEN_HASH` 그대로. Run: `./scripts/check-all.sh`
```bash
git add assets/characters/kaykit scripts/list_animations.gd scripts/list_animations.gd.uid src/render/character/character_catalog.gd src/render/character/character_catalog.gd.uid tests/unit/test_character_catalog.gd tests/unit/test_character_catalog.gd.uid ASSETS.md
git commit -m "feat: import KayKit adventurer characters with an animation inventory" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 3: AnimMap(뷰 → 애니 상태) + AnimClips(후보 클립 해석)

**Files:**
- Create: `src/render/character/anim_map.gd`, `src/render/character/anim_clips.gd`
- Test: `tests/unit/test_anim_map.gd`, `tests/unit/test_anim_clips.gd`

**Interfaces:**
- Consumes: fighter view 키 `state`, `attack_kind`, `on_ground`, `item_kind`, `charge_ticks`, `hitstop_ticks`; `Fighter.State`, `AttackSet.Kind`; T2 `animations.txt`(후보 이름 근거)
- Produces:
  - `enum AnimMap.Anim { IDLE, RUN, JUMP, FALL, LIGHT, HEAVY, CHARGE, BAT, GRAB, HOLD, HELD, THROW, HIT, LAUNCHED, GUARD, KO }`
  - `static func AnimMap.anim_for(view: Dictionary) -> int`
  - `static func AnimMap.anim_name(anim: int) -> String` — 상태 머신 노드 이름 (`"IDLE"` 등, enum 키 그대로)
  - `static func AnimMap.is_timed(anim: int) -> bool` — LIGHT·HEAVY·BAT·GRAB (sim 공격 길이에 맞춰 늘일 상태)
  - `const AnimClips.CANDIDATES: Dictionary` — `AnimMap.Anim` → 후보 클립 이름 `Array[String]`
  - `static func AnimClips.resolve(available: PackedStringArray) -> Dictionary` — Anim → 실제 클립 이름 (없으면 IDLE의 클립, IDLE도 없으면 첫 클립)
  - `static func AnimClips.loops(anim: int) -> bool` — IDLE·RUN·FALL·CHARGE·HOLD·HELD·GUARD·LAUNCHED 반복
- 근거: `[GD-ANIM-01]` `[PRD-FX-01]` · F4

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_anim_map.gd`:
```gdscript
extends GutTest
## Sim state -> animation state, 1:1 and read-only (design.md GD-ANIM-01).


func _v(state: int, on_ground: bool = true, attack_kind: int = 0) -> Dictionary:
	return {"state": state, "on_ground": on_ground, "attack_kind": attack_kind, "item_kind": Fighter.NONE,
		"charge_ticks": 0, "hitstop_ticks": 0}


func test_ground_and_air_movement() -> void:
	assert_eq(AnimMap.anim_for(_v(Fighter.State.IDLE)), AnimMap.Anim.IDLE)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.MOVE)), AnimMap.Anim.RUN)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.AIR, false)), AnimMap.Anim.JUMP)


func test_attacks_by_kind() -> void:
	for kind: int in [AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2, AttackSet.Kind.LIGHT_3]:
		assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, kind)), AnimMap.Anim.LIGHT)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY)), AnimMap.Anim.HEAVY)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, AttackSet.Kind.BAT)), AnimMap.Anim.BAT)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, AttackSet.Kind.GRAB)), AnimMap.Anim.GRAB)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.CHARGE)), AnimMap.Anim.CHARGE)


func test_hurt_and_special_states() -> void:
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HITSTUN, true)), AnimMap.Anim.HIT)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HITSTUN, false)), AnimMap.Anim.LAUNCHED, "airborne hitstun is a launch")
	assert_eq(AnimMap.anim_for(_v(Fighter.State.GUARD)), AnimMap.Anim.GUARD)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HOLDING)), AnimMap.Anim.HOLD)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HELD)), AnimMap.Anim.HELD)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.KO)), AnimMap.Anim.KO)


func test_every_fighter_state_maps() -> void:
	for s: int in Fighter.State.values():
		var a := AnimMap.anim_for(_v(s))
		assert_true(AnimMap.Anim.values().has(a), "state %d maps to a real anim" % s)


func test_names_and_timing() -> void:
	assert_eq(AnimMap.anim_name(AnimMap.Anim.LAUNCHED), "LAUNCHED")
	for a: int in [AnimMap.Anim.LIGHT, AnimMap.Anim.HEAVY, AnimMap.Anim.BAT, AnimMap.Anim.GRAB]:
		assert_true(AnimMap.is_timed(a))
	assert_false(AnimMap.is_timed(AnimMap.Anim.RUN))
```

`tests/unit/test_anim_clips.gd`:
```gdscript
extends GutTest
## Candidate clip names resolved against what the model really ships (context F4).


func test_first_available_candidate_wins() -> void:
	var available := PackedStringArray(["Idle", "Running_B", "Running_A", "Jump_Idle"])
	var map := AnimClips.resolve(available)
	assert_eq(map[AnimMap.Anim.IDLE], "Idle")
	assert_eq(map[AnimMap.Anim.RUN], AnimClips.first_present(AnimClips.CANDIDATES[AnimMap.Anim.RUN], available))


func test_missing_states_fall_back_to_idle() -> void:
	var map := AnimClips.resolve(PackedStringArray(["Idle"]))
	for a: int in AnimMap.Anim.values():
		assert_eq(map[a], "Idle", "state %d falls back to idle" % a)


func test_no_idle_uses_the_first_clip() -> void:
	var map := AnimClips.resolve(PackedStringArray(["Dance"]))
	assert_eq(map[AnimMap.Anim.KO], "Dance")


func test_every_anim_has_candidates_and_loop_flags() -> void:
	for a: int in AnimMap.Anim.values():
		assert_true(AnimClips.CANDIDATES.has(a), "candidates for %d" % a)
		assert_gt((AnimClips.CANDIDATES[a] as Array).size(), 0)
	assert_true(AnimClips.loops(AnimMap.Anim.RUN))
	assert_false(AnimClips.loops(AnimMap.Anim.LIGHT))


func test_kaykit_models_resolve_the_core_states() -> void:
	# every core state finds a real clip in each imported character (T2), not the idle fallback
	for c: Dictionary in CharacterCatalog.CHARACTERS:
		var root := (load(String(c["path"])) as PackedScene).instantiate()
		var player := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var available := PackedStringArray()
		for n: StringName in player.get_animation_list():
			available.append(String(n))
		var map := AnimClips.resolve(available)
		for a: int in [AnimMap.Anim.RUN, AnimMap.Anim.JUMP, AnimMap.Anim.LIGHT, AnimMap.Anim.HIT, AnimMap.Anim.GUARD]:
			assert_ne(map[a], map[AnimMap.Anim.IDLE], "%s: state %d has its own clip" % [c["name"], a])
		root.free()
```

Run: `./scripts/test.sh -gselect=test_anim` → FAIL (`AnimMap` 미정의)

- [ ] **Step 2: AnimMap 작성**

`src/render/character/anim_map.gd`:
```gdscript
class_name AnimMap
extends RefCounted
## Sim fighter view -> animation state (design.md GD-ANIM-01): a pure, read-only mapping. The
## animation never changes sim timing; attack clips are stretched to the sim length (Task 6).

enum Anim { IDLE, RUN, JUMP, FALL, LIGHT, HEAVY, CHARGE, BAT, GRAB, HOLD, HELD, THROW, HIT, LAUNCHED, GUARD, KO }

const TIMED: Array[int] = [Anim.LIGHT, Anim.HEAVY, Anim.BAT, Anim.GRAB]


static func anim_for(view: Dictionary) -> int:
	var on_ground := bool(view["on_ground"])
	match int(view["state"]):
		Fighter.State.MOVE:
			return Anim.RUN
		Fighter.State.AIR:
			return Anim.JUMP
		Fighter.State.ATTACK:
			return _attack_anim(int(view["attack_kind"]))
		Fighter.State.CHARGE:
			return Anim.CHARGE
		Fighter.State.HITSTUN:
			return Anim.HIT if on_ground else Anim.LAUNCHED
		Fighter.State.GUARD:
			return Anim.GUARD
		Fighter.State.HOLDING:
			return Anim.HOLD
		Fighter.State.HELD:
			return Anim.HELD
		Fighter.State.KO:
			return Anim.KO
	return Anim.IDLE


static func anim_name(anim: int) -> String:
	return Anim.keys()[anim]


static func is_timed(anim: int) -> bool:
	return TIMED.has(anim)


static func _attack_anim(kind: int) -> int:
	match kind:
		AttackSet.Kind.HEAVY:
			return Anim.HEAVY
		AttackSet.Kind.BAT:
			return Anim.BAT
		AttackSet.Kind.GRAB:
			return Anim.GRAB
		AttackSet.Kind.THROW:
			return Anim.THROW
	return Anim.LIGHT
```
(FALL·THROW는 후속 연출용 예약 상태다 — 지금 매핑에서는 JUMP·LIGHT로 충분하지만 상태 머신 노드는 모든 Anim에 대해 만든다.)

- [ ] **Step 3: AnimClips 작성 (후보는 T2 animations.txt 기준으로 조정)**

`src/render/character/anim_clips.gd` — 아래 후보는 KayKit 명명 관례 기준 초안이다. **T2의 animations.txt와 대조해, 각 상태의 첫 후보가 실제로 존재하는 이름이 되도록 순서를 맞추고 없는 이름은 실제 이름으로 바꾼다.** 결정 표(상태 → 고른 클립 → 이유)를 보고서에 적는다:
```gdscript
class_name AnimClips
extends RefCounted
## Candidate clip names per animation state (context F4). resolve() picks the first candidate the
## model really ships, so small naming differences between packs never break the animator.
## Candidates follow KayKit Adventurers 1.0 names (assets/characters/kaykit/animations.txt).

const CANDIDATES := {
	AnimMap.Anim.IDLE: ["Idle", "Unarmed_Idle", "Idle_B"],
	AnimMap.Anim.RUN: ["Running_A", "Running_B", "Running_Strafe_Right", "Walking_A"],
	AnimMap.Anim.JUMP: ["Jump_Idle", "Jump_Full_Short", "Jump_Start"],
	AnimMap.Anim.FALL: ["Jump_Idle", "Jump_Full_Long"],
	AnimMap.Anim.LIGHT: ["Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B", "1H_Melee_Attack_Jab"],
	AnimMap.Anim.HEAVY: ["Unarmed_Melee_Attack_Kick", "2H_Melee_Attack_Slice", "1H_Melee_Attack_Chop"],
	AnimMap.Anim.CHARGE: ["Spellcast_Charge", "2H_Melee_Idle", "Block"],
	AnimMap.Anim.BAT: ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal", "2H_Melee_Attack_Chop"],
	AnimMap.Anim.GRAB: ["Interact", "PickUp", "Unarmed_Melee_Attack_Punch_A"],
	AnimMap.Anim.HOLD: ["Unarmed_Pose", "Block", "Idle"],
	AnimMap.Anim.HELD: ["Hit_B", "Hit_A"],
	AnimMap.Anim.THROW: ["Throw", "1H_Ranged_Shoot"],
	AnimMap.Anim.HIT: ["Hit_A", "Hit_B"],
	AnimMap.Anim.LAUNCHED: ["Hit_B", "Jump_Idle", "Hit_A"],
	AnimMap.Anim.GUARD: ["Blocking", "Block", "Unarmed_Pose"],
	AnimMap.Anim.KO: ["Death_A", "Death_B", "Lie_Idle"],
}
const LOOPING: Array[int] = [
	AnimMap.Anim.IDLE, AnimMap.Anim.RUN, AnimMap.Anim.FALL, AnimMap.Anim.CHARGE, AnimMap.Anim.HOLD,
	AnimMap.Anim.HELD, AnimMap.Anim.GUARD, AnimMap.Anim.LAUNCHED, AnimMap.Anim.JUMP,
]


static func resolve(available: PackedStringArray) -> Dictionary:
	var idle := first_present(CANDIDATES[AnimMap.Anim.IDLE], available)
	if idle.is_empty():
		idle = available[0] if available.size() > 0 else ""
	var out := {}
	for a: int in AnimMap.Anim.values():
		var clip := first_present(CANDIDATES[a], available)
		out[a] = clip if not clip.is_empty() else idle
	return out


static func first_present(candidates: Array, available: PackedStringArray) -> String:
	for c: String in candidates:
		if available.has(c):
			return c
	return ""


static func loops(anim: int) -> bool:
	return LOOPING.has(anim)
```

- [ ] **Step 4: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). `test_kaykit_models_resolve_the_core_states`가 실패하면 후보를 animations.txt에 맞게 고친다 — 테스트를 약하게 만들지 않는다.
Run: `./scripts/check-all.sh`
```bash
git add src/render/character/anim_map.gd src/render/character/anim_map.gd.uid src/render/character/anim_clips.gd src/render/character/anim_clips.gd.uid tests/unit/test_anim_map.gd tests/unit/test_anim_map.gd.uid tests/unit/test_anim_clips.gd tests/unit/test_anim_clips.gd.uid
git commit -m "feat: map sim states to animation states with candidate clips" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 4: 소프트 툰 v2 — 텍스처·글로벌 유니폼 토큰·캐릭터 외곽선·룩 프리셋

**Files:**
- Modify: `src/render/shaders/soft_toon.gdshader`, `src/render/toon_materials.gd`, `project.godot` (`[shader_globals]`), `src/config/game_config.gd` (Look 그룹), `scripts/capture_evidence.gd` (`--look=N`)
- Create: `src/render/shaders/char_outline.gdshader`, `src/render/look_preset.gd`
- Test: `tests/unit/test_look_preset.gd`

**Interfaces:**
- Produces:
  - 셰이더 글로벌 `ds_rim_strength: float`(0.35), `ds_char_saturation: float`(1.0), `ds_outline_width: float`(0.0), `ds_outline_color: color`
  - `soft_toon.gdshader` 유니폼 추가: `albedo_texture: sampler2D`, `use_texture: bool`, `is_character: bool` (캐릭터는 글로벌 림·채도 사용)
  - `static func ToonMaterials.character(texture: Texture2D) -> ShaderMaterial` — 텍스처별 캐시, `next_pass` = 공유 외곽선 머티리얼. 수정 금지
  - `enum LookPreset.Look { A, B, C }`, `const LookPreset.PRESETS: Dictionary`(Look → `{"rim", "saturation", "outline"}`), `static func LookPreset.values_for(look: int) -> Dictionary`, `static func LookPreset.apply(look: int) -> void`
  - `GameConfig.look_preset: int = 0` (Look 그룹, `NON_SIM_GROUPS`에 `"Look"` 추가)
  - `capture_evidence.gd --look=N` (기본 config를 load해 `look_preset` 설정 후 `emit_changed()`)
- 근거: `[DS-VIS-01]` `[PRD-FX-03]` `[PRD-PLT-05]` · F6

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_look_preset.gd`:
```gdscript
extends GutTest
## Soft toon v2 look presets (context F6) and the character material.


func after_each() -> void:
	LookPreset.apply(LookPreset.Look.A)


func test_three_presets_for_the_gate() -> void:
	var a := LookPreset.values_for(LookPreset.Look.A)
	var b := LookPreset.values_for(LookPreset.Look.B)
	var c := LookPreset.values_for(LookPreset.Look.C)
	assert_eq(a["rim"], 0.35, "A is the design.md DS-VIS-01 draft")
	assert_eq(a["outline"], 0.0)
	assert_gt(b["rim"], a["rim"])
	assert_gt(b["saturation"], 1.0)
	assert_gt(c["outline"], 0.0, "C is the character-only outline option")


func test_apply_sets_global_uniforms() -> void:
	LookPreset.apply(LookPreset.Look.C)
	var c := LookPreset.values_for(LookPreset.Look.C)
	assert_almost_eq(float(RenderingServer.global_shader_parameter_get("ds_rim_strength")), float(c["rim"]), 0.0001)
	assert_almost_eq(float(RenderingServer.global_shader_parameter_get("ds_outline_width")), float(c["outline"]), 0.0001)
	assert_eq(RenderingServer.global_shader_parameter_get("ds_outline_color"), DS.CANOPY_DEEP)


func test_unknown_look_falls_back_to_a() -> void:
	assert_eq(LookPreset.values_for(9), LookPreset.values_for(LookPreset.Look.A))


func test_character_material_is_cached_with_outline_pass() -> void:
	var tex := PlaceholderTexture2D.new()
	var m1 := ToonMaterials.character(tex)
	var m2 := ToonMaterials.character(tex)
	assert_same(m1, m2, "one material per texture")
	assert_true(bool(m1.get_shader_parameter("is_character")))
	assert_true(bool(m1.get_shader_parameter("use_texture")))
	assert_not_null(m1.next_pass, "outline pass attached (width 0 hides it)")
	var plain := ToonMaterials.character(null)
	assert_false(bool(plain.get_shader_parameter("use_texture")))


func test_look_group_is_presentation_only() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.look_preset = 2
	assert_eq(a.fingerprint(), b.fingerprint())
```
Run: `./scripts/test.sh -gselect=test_look_preset` → FAIL (`LookPreset` 미정의)

- [ ] **Step 2: 셰이더 글로벌 등록**

`project.godot`의 `[shader_globals]` 끝에 추가 (색은 `DS.CANOPY_DEEP` #17525A와 같은 값 — 런타임에 LookPreset이 토큰으로 다시 설정한다):
```
ds_rim_strength={
"type": "float",
"value": 0.35
}
ds_char_saturation={
"type": "float",
"value": 1.0
}
ds_outline_width={
"type": "float",
"value": 0.0
}
ds_outline_color={
"type": "color",
"value": Color(0.0902, 0.3216, 0.3529, 1)
}
```

- [ ] **Step 3: 셰이더 v2 + 외곽선**

`src/render/shaders/soft_toon.gdshader` 교체:
```glsl
shader_type spatial;
// Soft toon v2 (design.md DS-VIS-01, context F6): two soft bands, tinted shadows, optional rim,
// optional albedo texture, no outline. Characters read the global rim and saturation tokens so
// the look presets (LookPreset) retune every character at once.

global uniform vec4 ds_shadow_tint;
global uniform float ds_band_softness;
global uniform float ds_rim_strength;
global uniform float ds_char_saturation;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool is_character = false;

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) {
		c *= texture(albedo_texture, UV).rgb;
	}
	if (is_character) {
		float luma = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(luma), c, ds_char_saturation);
	}
	ALBEDO = clamp(c, 0.0, 1.0);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-ds_band_softness, ds_band_softness, ndl) * ATTENUATION;
	vec3 band = mix(ds_shadow_tint.rgb, vec3(1.0), lit);
	float rim_amount = is_character ? ds_rim_strength : rim_strength;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount * lit;
	DIFFUSE_LIGHT += (band + vec3(rim)) * LIGHT_COLOR / PI;
}
```
`src/render/shaders/char_outline.gdshader`:
```glsl
shader_type spatial;
render_mode unshaded, cull_front;
// Character-only thin outline (design.md DS-VIS-01 outline option, context F6): an inverted hull
// pushed out along normals. Width 0 (presets A/B) keeps it hidden behind the body.

global uniform float ds_outline_width;
global uniform vec4 ds_outline_color;

void vertex() {
	VERTEX += NORMAL * ds_outline_width;
}

void fragment() {
	ALBEDO = ds_outline_color.rgb;
}
```

- [ ] **Step 4: ToonMaterials.character**

`src/render/toon_materials.gd` 끝에 추가:
```gdscript
const OUTLINE_SHADER := preload("res://src/render/shaders/char_outline.gdshader")

static var _character_cache: Dictionary = {}
static var _outline: ShaderMaterial = null


## Character surface material (context F6): the model's albedo texture (or none), global rim and
## saturation, plus the shared outline pass. One per texture; shared: never mutate.
static func character(texture: Texture2D) -> ShaderMaterial:
	var key: Variant = texture.get_instance_id() if texture != null else 0
	if _character_cache.has(key):
		return _character_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", DS.WHITE)
	mat.set_shader_parameter("is_character", true)
	mat.set_shader_parameter("use_texture", texture != null)
	if texture != null:
		mat.set_shader_parameter("albedo_texture", texture)
	mat.next_pass = _outline_material()
	_character_cache[key] = mat
	return mat


static func _outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline
```
`src/ui/theme/tokens.gd`의 `TRANSPARENT` 줄 다음에 토큰을 추가한다 (`Color.WHITE`는 check-colors 패턴에 걸리므로):
```gdscript
## Multiplier identity for textured materials (soft toon albedo), not a UI color.
const WHITE := Color("#FFFFFF")
```

- [ ] **Step 5: LookPreset + Look 그룹**

`src/render/look_preset.gd`:
```gdscript
class_name LookPreset
extends RefCounted
## Character look presets for the 🖼 gate (design.md DS-VIS-01/02, context F6), applied through
## global shader uniforms so every character material follows at once.
##   A  rim 0.35, no outline (design draft)
##   B  stronger rim, +15% saturation
##   C  softer rim, thin canopy_deep outline (characters only)

enum Look { A, B, C }

const PRESETS := {
	Look.A: {"rim": 0.35, "saturation": 1.0, "outline": 0.0},
	Look.B: {"rim": 0.5, "saturation": 1.15, "outline": 0.0},
	Look.C: {"rim": 0.25, "saturation": 1.0, "outline": 0.012},
}


static func values_for(look: int) -> Dictionary:
	return PRESETS.get(look, PRESETS[Look.A])


static func apply(look: int) -> void:
	var p := values_for(look)
	RenderingServer.global_shader_parameter_set("ds_rim_strength", float(p["rim"]))
	RenderingServer.global_shader_parameter_set("ds_char_saturation", float(p["saturation"]))
	RenderingServer.global_shader_parameter_set("ds_outline_width", float(p["outline"]))
	RenderingServer.global_shader_parameter_set("ds_outline_color", DS.CANOPY_DEEP)
```
`src/config/game_config.gd`: Touch 그룹 뒤에 추가하고 `NON_SIM_GROUPS`에 `"Look"`를 넣는다:
```gdscript

@export_group("Look")
## Character look preset for the 🖼 gate: 0 = A, 1 = B, 2 = C (context F6).
@export_range(0, 2, 1) var look_preset: int = 0
```
`scripts/capture_evidence.gd`: `--touch-layout` 블록 뒤에 같은 방식으로 `--look=N` 추가 (`config.look_preset = int(args["look"])`, `config.emit_changed()`, 그리고 `LookPreset.apply(config.look_preset)`), 사용법 주석에 `[--look=N]`.

- [ ] **Step 6: 테스트 + 해시 확인 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS, `BEHAVIOR_HASH`·`GOLDEN_HASH` 그대로 (Look은 지문 제외). Run: `./scripts/check-all.sh`
```bash
git add src/render/shaders/soft_toon.gdshader src/render/shaders/char_outline.gdshader src/render/look_preset.gd src/render/look_preset.gd.uid src/render/toon_materials.gd src/ui/theme/tokens.gd project.godot src/config/game_config.gd scripts/capture_evidence.gd tests/unit/test_look_preset.gd tests/unit/test_look_preset.gd.uid
git commit -m "feat: soft toon v2 with textures, global look tokens and a character outline" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 5: CharacterModel — glb 인스턴스, 툰 머티리얼, 부속 숨김, 키 맞추기, FighterView 교체

**Files:**
- Create: `src/render/character/character_model.gd`
- Modify: `src/render/fighter_view.gd` (캡슐 → 모델, 실패 시 캡슐 대체)
- Test: `tests/unit/test_character_model.gd`, `tests/unit/test_fighter_view.gd`

**Interfaces:**
- Consumes: T2 `CharacterCatalog`, T4 `ToonMaterials.character`
- Produces:
  - `CharacterModel` (Node3D): `setup(entry: Dictionary, config: GameConfig) -> bool` (로드 실패 시 false + push_error), `animation_player() -> AnimationPlayer`, `visible_height() -> float`, `foot_y() -> float`
  - `CharacterModel.FACING_OFFSET: float` — 모델 정면이 +Z가 아니면 PI (T5 스크린샷으로 확인)
  - `FighterView.model() -> CharacterModel` (없으면 null), 블링크·KO 숨김이 모델에 적용
- 근거: `[PRD-FX-01]` `[PRD-ARCH-01]` · F3

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_character_model.gd`:
```gdscript
extends GutTest
## KayKit character wrapper (context F3): toon materials, hidden accessories, fitted to the
## fighter capsule height with the feet on the floor.


func _model(index: int) -> CharacterModel:
	var m := CharacterModel.new()
	add_child_autofree(m)
	assert_true(m.setup(CharacterCatalog.for_player(index), GameConfig.new()))
	return m


func test_fits_the_capsule_height_with_feet_on_the_floor() -> void:
	var c := GameConfig.new()
	for i: int in 4:
		var m := _model(i)
		assert_almost_eq(m.visible_height(), c.fighter_height, 0.05, "slot %d height" % i)
		assert_almost_eq(m.foot_y(), 0.0, 0.03, "slot %d feet" % i)


func test_uses_soft_toon_and_hides_accessories() -> void:
	var entry := CharacterCatalog.for_player(0)
	var m := _model(0)
	for node: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if (entry["hide"] as Array).has(String(mesh.name)):
			assert_false(mesh.visible, "%s hidden" % mesh.name)
		else:
			var mat := mesh.get_surface_override_material(0) as ShaderMaterial
			assert_not_null(mat, "%s uses a toon override" % mesh.name)
			assert_true(bool(mat.get_shader_parameter("is_character")))


func test_exposes_its_animation_player() -> void:
	assert_not_null(_model(1).animation_player())


func test_bad_entry_reports_failure() -> void:
	var m := CharacterModel.new()
	add_child_autofree(m)
	assert_false(m.setup({"name": "Nope", "path": "res://missing.glb", "hide": []}, GameConfig.new()))
	assert_push_error("CharacterModel")
```
`tests/unit/test_fighter_view.gd` 끝에 추가:
```gdscript


func test_fighter_view_draws_the_catalog_character() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(2, GameConfig.new())
	assert_not_null(v.model(), "slot 2 uses a KayKit character")
	var d := _fighter_view_data(Fighter.NONE, 0)
	d["invuln_ticks"] = 60
	var seen := {}
	for t: int in 30:
		v.apply(d, d, 1.0, t)
		seen[v.model().visible] = true
	assert_eq(seen.size(), 2, "the model blinks while invulnerable")
```
Run: `./scripts/test.sh -gselect=test_character_model` → FAIL

- [ ] **Step 2: CharacterModel 작성**

`src/render/character/character_model.gd`:
```gdscript
class_name CharacterModel
extends Node3D
## One KayKit character (context F3, F6): the glb scene with every visible surface switched to
## the soft toon character material, accessories hidden, scaled so its rest-pose height matches
## the fighter capsule and its feet sit at y = 0. Drawing only; the capsule stays the hitbox.

## Extra yaw if the model's front is not +Z (checked against a screenshot in Task 5).
const FACING_OFFSET := 0.0

var _root: Node3D
var _player: AnimationPlayer


func setup(entry: Dictionary, config: GameConfig) -> bool:
	var scene := load(String(entry["path"])) as PackedScene
	if scene == null:
		push_error("CharacterModel: cannot load %s" % entry["path"])
		return false
	_root = scene.instantiate() as Node3D
	add_child(_root)
	_root.rotation.y = FACING_OFFSET
	var players := _root.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] as AnimationPlayer if players.size() > 0 else null
	var hidden: Array = entry["hide"]
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if hidden.has(String(mesh.name)):
			mesh.visible = false
		else:
			_apply_toon(mesh)
	_fit(config.fighter_height)
	return true


func animation_player() -> AnimationPlayer:
	return _player


func visible_height() -> float:
	return _bounds().size.y


func foot_y() -> float:
	return _bounds().position.y


static func _apply_toon(mesh: MeshInstance3D) -> void:
	for i: int in mesh.get_surface_override_material_count():
		var src := mesh.get_active_material(i)
		var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
		mesh.set_surface_override_material(i, ToonMaterials.character(tex))


func _fit(target_height: float) -> void:
	var b := _bounds()
	if b.size.y <= 0.0001:
		return
	var s := target_height / b.size.y
	_root.scale = Vector3.ONE * s
	_root.position.y -= _bounds().position.y


## Rest-pose bounds of the visible meshes in this node's space.
func _bounds() -> AABB:
	var inv := global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue
		var box := inv * mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
```

- [ ] **Step 3: FighterView 교체**

`src/render/fighter_view.gd`:
- 필드 추가 `var _model: CharacterModel = null`
- `setup`에서 캡슐 `_body` 생성 뒤에 모델을 붙이고, 성공하면 캡슐을 숨긴다:
```gdscript
	_model = CharacterModel.new()
	add_child(_model)
	if _model.setup(CharacterCatalog.for_player(index), config):
		_body.visible = false
	else:
		_model.queue_free()
		_model = null
```
- `apply`의 `_body.visible = blink_visible(...)` 줄을 교체:
```gdscript
	var shown := blink_visible(int(curr["invuln_ticks"]), tick, _config)
	if _model != null:
		_model.visible = shown
	else:
		_body.visible = shown
```
- 함수 추가 `func model() -> CharacterModel: return _model`
- 머리 주석 첫 줄을 `Draws one fighter (design.md DS-VIS-03, GD-FEEL-03): the KayKit character for its slot (capsule fallback if the model fails to load),`로 고친다

- [ ] **Step 4: 테스트 + 정면 확인 스크린샷**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변).
Run (창 모드): `godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out="$PWD/dev/active/phase-3/evidence/characters-rest.png" --frames=90`
이미지를 열어 캐릭터가 서로를 바라보는지(스폰 시 경기장 중심을 향함) 확인한다. 등을 보이면 `FACING_OFFSET := PI`로 바꾸고 다시 찍는다. 부속이 남아 있으면 T2 카탈로그의 hide 목록을 보충한다(보고서에 기록).

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/render/character/character_model.gd src/render/character/character_model.gd.uid src/render/fighter_view.gd tests/unit/test_character_model.gd tests/unit/test_character_model.gd.uid tests/unit/test_fighter_view.gd dev/active/phase-3/evidence/characters-rest.png
git commit -m "feat: draw fighters as KayKit characters in soft toon" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```
(카탈로그를 고쳤다면 `src/render/character/character_catalog.gd`도 함께 add)

---

### Task 6: CharacterAnimator — AnimationTree 상태 머신, sim 길이로 늘이기, 히트스톱 정지

**Files:**
- Create: `src/render/character/character_animator.gd`
- Modify: `src/render/fighter_view.gd` (`animate`), `src/main/main.gd` (`_draw_fighters`에서 delta 전달)
- Test: `tests/unit/test_character_animator.gd`

**Interfaces:**
- Consumes: T3 `AnimMap`, `AnimClips`, T5 `CharacterModel.animation_player()`, `AttackSet.from_config`
- Produces:
  - `CharacterAnimator` (Node): `setup(player: AnimationPlayer, config: GameConfig) -> void`, `apply(view: Dictionary, delta: float) -> void`, `current_anim() -> int`, `clip_for(anim: int) -> String`, `play_position() -> float`, `state_machine() -> AnimationNodeStateMachine`
  - `static func CharacterAnimator.timed_seconds(anim: int, config: GameConfig) -> float` — LIGHT·HEAVY·BAT·GRAB의 `total_ticks / TICK_RATE`
  - `CharacterAnimator.XFADE_SECONDS := 0.08`
  - `FighterView.animate(curr: Dictionary, delta: float) -> void`, `FighterView.animator() -> CharacterAnimator`
- 근거: `[GD-ANIM-01]` `[PRD-FX-01]` · F5

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_character_animator.gd`:
```gdscript
extends GutTest
## AnimationTree state machine driven by sim views (context F5): 1:1 states, attack clips
## stretched to the sim length, frozen during hitstop, combo hits restart the clip.

const CLIPS := ["Idle", "Running_A", "Jump_Idle", "Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Kick",
	"Hit_A", "Hit_B", "Blocking", "Death_A"]


func _player() -> AnimationPlayer:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var player := AnimationPlayer.new()
	holder.add_child(player)
	var lib := AnimationLibrary.new()
	for n: String in CLIPS:
		var a := Animation.new()
		a.length = 1.0
		lib.add_animation(n, a)
	player.add_animation_library("", lib)
	return player


func _animator(config: GameConfig = null) -> CharacterAnimator:
	var player := _player()
	var anim := CharacterAnimator.new()
	player.get_parent().add_child(anim)
	anim.setup(player, config if config != null else GameConfig.new())
	return anim


func _v(state: int, on_ground: bool = true, kind: int = 0, hitstop: int = 0) -> Dictionary:
	return {"state": state, "on_ground": on_ground, "attack_kind": kind, "item_kind": Fighter.NONE,
		"charge_ticks": 0, "hitstop_ticks": hitstop}


func test_follows_sim_states() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.MOVE), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.RUN)
	assert_eq(a.clip_for(AnimMap.Anim.RUN), "Running_A")
	a.apply(_v(Fighter.State.HITSTUN, false), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.LAUNCHED)


func test_every_anim_has_a_state_machine_node() -> void:
	var a := _animator()
	for anim: int in AnimMap.Anim.values():
		assert_true(a.state_machine().has_node(AnimMap.anim_name(anim)), AnimMap.anim_name(anim))


func test_attack_clips_stretch_to_the_sim_length() -> void:
	var c := GameConfig.new()
	var a := _animator(c)
	var node := a.state_machine().get_node("HEAVY") as AnimationNodeAnimation
	assert_true(node.use_custom_timeline)
	assert_true(node.stretch_time_scale)
	var heavy := AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY)
	assert_almost_eq(node.timeline_length, float(heavy.total_ticks()) / SimTime.TICK_RATE, 0.0001)
	assert_almost_eq(CharacterAnimator.timed_seconds(AnimMap.Anim.HEAVY, c), node.timeline_length, 0.0001)


func test_hitstop_freezes_the_animation() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1), 0.05)
	var before := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 3), 0.05)
	assert_almost_eq(a.play_position(), before, 0.0001, "no progress during hitstop")
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1), 0.05)
	assert_gt(a.play_position(), before)


func test_next_combo_hit_restarts_the_clip() -> void:
	var a := _animator()
	for i: int in 5:
		a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1), 0.03)
	var mid := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_2), 0.0)
	assert_lt(a.play_position(), mid, "LIGHT_2 starts the punch again")
```
Run: `./scripts/test.sh -gselect=test_character_animator` → FAIL

- [ ] **Step 2: CharacterAnimator 작성**

`src/render/character/character_animator.gd`:
```gdscript
class_name CharacterAnimator
extends Node
## AnimationTree state machine built in code (design.md GD-ANIM-01, context F5). One node per
## AnimMap.Anim; every pair is linked with a short crossfade. The tree runs in manual mode:
## apply() advances it by the frame delta, or not at all during hitstop. Attack clips use a
## custom timeline stretched to the sim attack length, so the swing lines up with the hitbox.

const XFADE_SECONDS := 0.08

var _tree: AnimationTree
var _machine: AnimationNodeStateMachine
var _playback: AnimationNodeStateMachinePlayback
var _clips: Dictionary = {}
var _current: int = -1
var _last_kind: int = -1


func setup(player: AnimationPlayer, config: GameConfig) -> void:
	var available := PackedStringArray()
	for n: StringName in player.get_animation_list():
		available.append(String(n))
	_clips = AnimClips.resolve(available)
	_machine = AnimationNodeStateMachine.new()
	for anim: int in AnimMap.Anim.values():
		_machine.add_node(AnimMap.anim_name(anim), _node_for(anim, player, config))
	for a: int in AnimMap.Anim.values():
		for b: int in AnimMap.Anim.values():
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = XFADE_SECONDS
				_machine.add_transition(AnimMap.anim_name(a), AnimMap.anim_name(b), t)
	_tree = AnimationTree.new()
	player.get_parent().add_child(_tree)
	_tree.tree_root = _machine
	_tree.anim_player = _tree.get_path_to(player)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_enter(AnimMap.Anim.IDLE)
	_tree.advance(0.0)


func apply(view: Dictionary, delta: float) -> void:
	var anim := AnimMap.anim_for(view)
	var kind := int(view["attack_kind"])
	if anim != _current or (AnimMap.is_timed(anim) and kind != _last_kind):
		_enter(anim)
	_last_kind = kind
	_tree.advance(0.0 if int(view["hitstop_ticks"]) > 0 else delta)


func current_anim() -> int:
	return _current


func clip_for(anim: int) -> String:
	return String(_clips[anim])


func play_position() -> float:
	return _playback.get_current_play_position()


func state_machine() -> AnimationNodeStateMachine:
	return _machine


static func timed_seconds(anim: int, config: GameConfig) -> float:
	var attacks := AttackSet.from_config(config)
	var kind := AttackSet.Kind.LIGHT_1
	match anim:
		AnimMap.Anim.HEAVY:
			kind = AttackSet.Kind.HEAVY
		AnimMap.Anim.BAT:
			kind = AttackSet.Kind.BAT
		AnimMap.Anim.GRAB:
			kind = AttackSet.Kind.GRAB
	return float(attacks.get_attack(kind).total_ticks()) / SimTime.TICK_RATE


func _enter(anim: int) -> void:
	var name := AnimMap.anim_name(anim)
	if AnimMap.is_timed(anim) or _current == -1:
		_playback.start(name, true)  # swings restart from frame 0, no blend
	else:
		_playback.travel(name)
	_current = anim


func _node_for(anim: int, player: AnimationPlayer, config: GameConfig) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	var clip := String(_clips[anim])
	node.animation = StringName(clip)
	node.use_custom_timeline = true
	if AnimMap.is_timed(anim):
		node.timeline_length = timed_seconds(anim, config)
		node.stretch_time_scale = true
		node.loop_mode = Animation.LOOP_NONE
	else:
		node.timeline_length = player.get_animation(clip).length if player.has_animation(clip) else 1.0
		node.stretch_time_scale = false
		node.loop_mode = Animation.LOOP_LINEAR if AnimClips.loops(anim) else Animation.LOOP_NONE
	return node
```
(Godot 4.7 API 차이로 `AnimationNodeAnimation`의 `use_custom_timeline`/`timeline_length`/`stretch_time_scale`/`loop_mode` 중 이름이 다르면 해당 API 문서를 확인해 최소 변경하고 보고서에 적는다.)

- [ ] **Step 3: FighterView·main 연결**

`src/render/fighter_view.gd`:
- 필드 `var _animator: CharacterAnimator = null`
- `setup`에서 모델이 성공한 분기 안, `_body.visible = false` 다음에:
```gdscript
		if _model.animation_player() != null:
			_animator = CharacterAnimator.new()
			add_child(_animator)
			_animator.setup(_model.animation_player(), config)
```
- 함수 추가:
```gdscript
## Advances the character animation from the latest sim view (main calls this every frame).
func animate(curr: Dictionary, delta: float) -> void:
	if _animator != null and int(curr["state"]) != Fighter.State.KO:
		_animator.apply(curr, delta)


func animator() -> CharacterAnimator:
	return _animator
```
`src/main/main.gd`: `_draw_fighters()`를 `_draw_fighters(delta: float)`로 바꾸고 `_process`의 호출을 `_draw_fighters(delta)`로, 루프 안 `_views[i].apply(...)` 다음 줄에 `_views[i].animate(curr[i], delta)`. `src/debug/ringout_demo.gd`·`item_race_demo.gd`가 `_draw_fighters`를 오버라이드하지 않는지 확인(하면 시그니처를 맞춘다).

- [ ] **Step 4: 테스트 + 룩 3안 캡처(🖼 게이트 준비)**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변).
Run (창 모드) — 링아웃 데모로 캐릭터가 공격·피격 중인 장면을 룩별로:
```bash
for n in 0 1 2; do godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ringout_demo.tscn --out="$PWD/dev/active/phase-3/evidence/look-$n.png" --frames=75 --look=$n; done
```
세 장을 열어 A(0)/B(1)/C(2) 차이가 보이는지, 공격 동작이 찍혔는지 확인하고 보고서에 설명한다. 컨트롤러가 T7 게이트에서 사용자에게 보여준다.

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/render/character/character_animator.gd src/render/character/character_animator.gd.uid src/render/fighter_view.gd src/main/main.gd tests/unit/test_character_animator.gd tests/unit/test_character_animator.gd.uid dev/active/phase-3/evidence/look-0.png dev/active/phase-3/evidence/look-1.png dev/active/phase-3/evidence/look-2.png
git commit -m "feat: animate characters with a sim-driven AnimationTree state machine" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 7: 🖼 캐릭터 룩 게이트 (사용자 + 컨트롤러)

**구현 태스크가 아니다. 서브에이전트에 배정하지 않는다.**

- [ ] **Step 1:** 컨트롤러가 `evidence/look-{0,1,2}.png`(A/B/C)를 레퍼런스 A(design.md §0 설명, `docs/references/`에 이미지가 있으면 함께)와 나란히 보여준다
- [ ] **Step 2:** 사용자가 고른 안을 `GameConfig.look_preset` 기본값으로 반영하고 design.md DS-VIS-01 표·외곽선 정책에 "확정: <안>, 근거"를 적는다
- [ ] **Step 3:** 같은 자리에서 Phase 2 이월 결정을 받는다 — 🖼 4버튼 레이아웃(`dev/done/phase-2/evidence/touch-layout-*.png`), 캐릭터 크기(`cam_margin`, 지문 제외라 골든 영향 없음), HUD 시안
- [ ] **Step 4:** 게이트가 지연되면 A안(0)으로 계속하고 tasks 파일에 `🖼 대기`

---

### Task 8: 품질 3단계 (저사양 30fps, 그림자·블룸·파티클) + 블롭 그림자

**Files:**
- Create: `src/render/quality.gd`, `src/render/blob_shadow.gd`
- Modify: `src/config/game_config.gd` (Quality 그룹), `src/render/environment_rig.gd` (`apply_quality`), `src/render/fighter_view.gd` (블롭 그림자), `src/main/main.gd` (적용·config 변경 반영), `scripts/capture_evidence.gd` (`--quality=N`)
- Test: `tests/unit/test_quality.gd`

**Interfaces:**
- Produces:
  - `GameConfig.quality_level: int = -1` (Quality 그룹, -1 = 플랫폼 기본, 0 LOW / 1 MEDIUM / 2 HIGH; `NON_SIM_GROUPS`에 `"Quality"`)
  - `enum Quality.Level { LOW, MEDIUM, HIGH }`
  - `static func Quality.resolve(config_level: int, platform: String) -> int` — `platform`은 `"mobile" | "web" | "desktop"`; -1이면 mobile→MEDIUM, web→LOW, desktop→HIGH
  - `static func Quality.platform() -> String` — `OS.has_feature("mobile")`/`OS.has_feature("web")`로 판정
  - `static func Quality.settings(level: int) -> Dictionary` — `{"max_fps": int, "shadows": bool, "glow": bool, "particle_scale": float, "blob_shadows": bool}`
  - `static func Quality.particle_scale(config: GameConfig) -> float` (현재 단계의 값, VFX가 사용)
  - `EnvironmentRig.apply_quality(level: int) -> void`, `EnvironmentRig.environment() -> Environment`, `EnvironmentRig.sun() -> DirectionalLight3D`
  - `BlobShadow` (Node3D): `setup(config: GameConfig)`, 부모 FighterView 아래에서 항상 지면(y=0)에 붙는 원판
  - `FighterView.set_blob_shadow(on: bool) -> void`, `FighterView.blob_visible() -> bool`, `FighterView.blob() -> BlobShadow`
- 근거: `[PRD-NFR-01]` `[DS-VIS-01]` (그림자·블롭 그림자) · F7

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_quality.gd`:
```gdscript
extends GutTest
## Quality levels (context F7): LOW = 30 fps, no realtime shadow (blob shadows), half particles,
## no bloom; MEDIUM = 60 fps, shadows, no bloom; HIGH = everything.

var _saved_fps: int = 0


func before_each() -> void:
	_saved_fps = Engine.max_fps


func after_each() -> void:
	Engine.max_fps = _saved_fps


func test_platform_defaults() -> void:
	assert_eq(Quality.resolve(-1, "mobile"), Quality.Level.MEDIUM)
	assert_eq(Quality.resolve(-1, "web"), Quality.Level.LOW)
	assert_eq(Quality.resolve(-1, "desktop"), Quality.Level.HIGH)
	assert_eq(Quality.resolve(0, "desktop"), Quality.Level.LOW, "an explicit level wins")


func test_level_table() -> void:
	var low := Quality.settings(Quality.Level.LOW)
	assert_eq(low["max_fps"], 30)
	assert_false(low["shadows"])
	assert_true(low["blob_shadows"])
	assert_false(low["glow"])
	assert_eq(low["particle_scale"], 0.5)
	var mid := Quality.settings(Quality.Level.MEDIUM)
	assert_eq(mid["max_fps"], 60)
	assert_true(mid["shadows"])
	assert_false(mid["glow"])
	var high := Quality.settings(Quality.Level.HIGH)
	assert_true(high["shadows"] and high["glow"])
	assert_eq(high["particle_scale"], 1.0)


func test_environment_rig_applies_a_level() -> void:
	var rig := EnvironmentRig.new()
	add_child_autofree(rig)
	rig.setup()
	rig.apply_quality(Quality.Level.LOW)
	assert_false(rig.sun().shadow_enabled)
	assert_false(rig.environment().glow_enabled)
	assert_eq(Engine.max_fps, 30)
	rig.apply_quality(Quality.Level.HIGH)
	assert_true(rig.sun().shadow_enabled)
	assert_true(rig.environment().glow_enabled)
	assert_eq(Engine.max_fps, 60)


func test_blob_shadow_stays_on_the_ground() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new())
	v.set_blob_shadow(true)
	assert_true(v.blob_visible())
	var d := {"id": 0, "spawn_id": 0, "pos": Vector3(1, 3, 2), "facing": Vector3(0, 0, 1),
		"state": Fighter.State.AIR, "on_ground": false, "attack_kind": 0, "invuln_ticks": 0,
		"item_kind": Fighter.NONE, "item_uses": 0, "charge_ticks": 0, "hitstop_ticks": 0}
	v.apply(d, d, 1.0, 0)
	var blob := v.blob()
	assert_almost_eq(blob.global_position.y, BlobShadow.LIFT, 0.001, "shadow sits on the floor while jumping")
	v.set_blob_shadow(false)
	assert_false(v.blob_visible())


func test_quality_group_is_presentation_only() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.quality_level = 0
	assert_eq(a.fingerprint(), b.fingerprint())
```
Run: `./scripts/test.sh -gselect=test_quality` → FAIL

- [ ] **Step 2: Quality + BlobShadow**

`src/render/quality.gd`:
```gdscript
class_name Quality
extends RefCounted
## Render quality levels (PRD-NFR-01, context F7). -1 in GameConfig.quality_level means the
## platform default: mobile MEDIUM, web LOW, desktop HIGH.

enum Level { LOW, MEDIUM, HIGH }

const TABLE := {
	Level.LOW: {"max_fps": 30, "shadows": false, "glow": false, "particle_scale": 0.5, "blob_shadows": true},
	Level.MEDIUM: {"max_fps": 60, "shadows": true, "glow": false, "particle_scale": 1.0, "blob_shadows": false},
	Level.HIGH: {"max_fps": 60, "shadows": true, "glow": true, "particle_scale": 1.0, "blob_shadows": false},
}
const AUTO := -1


static func resolve(config_level: int, platform_name: String) -> int:
	if config_level != AUTO:
		return clampi(config_level, Level.LOW, Level.HIGH)
	match platform_name:
		"mobile":
			return Level.MEDIUM
		"web":
			return Level.LOW
	return Level.HIGH


static func platform() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("mobile"):
		return "mobile"
	return "desktop"


static func settings(level: int) -> Dictionary:
	return TABLE[clampi(level, Level.LOW, Level.HIGH)]


static func particle_scale(config: GameConfig) -> float:
	return float(settings(resolve(config.quality_level, platform()))["particle_scale"])
```
`src/render/blob_shadow.gd`:
```gdscript
class_name BlobShadow
extends Node3D
## Soft round shadow pinned to the floor under a fighter (design.md DS-VIS-01 low-end fallback):
## shown at LOW quality where the realtime sun shadow is off.

const LIFT := 0.02
const HEIGHT := 0.01
const RADIUS_RATIO := 1.3


func setup(config: GameConfig) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = config.fighter_radius * RADIUS_RATIO
	disc.bottom_radius = disc.top_radius
	disc.height = HEIGHT
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = ToonMaterials.translucent(DS.GROUND_SHADOW)
	add_child(mi)
	top_level = true
	visible = false


func follow(ground_point: Vector3) -> void:
	global_position = Vector3(ground_point.x, LIFT, ground_point.z)
```

- [ ] **Step 3: GameConfig·EnvironmentRig·FighterView·main**

`src/config/game_config.gd`: Look 그룹 뒤에 추가, `NON_SIM_GROUPS`에 `"Quality"`:
```gdscript

@export_group("Quality")
## -1 = platform default (mobile MEDIUM, web LOW, desktop HIGH); 0 LOW, 1 MEDIUM, 2 HIGH (context F7).
@export_range(-1, 2, 1) var quality_level: int = -1
```
`src/render/environment_rig.gd`: `setup()`에서 만든 `env`와 `sun`을 필드 `_env: Environment`, `_sun: DirectionalLight3D`에 저장하고(지역 변수 대신), 함수 추가:
```gdscript
func apply_quality(level: int) -> void:
	var s := Quality.settings(level)
	_sun.shadow_enabled = bool(s["shadows"])
	_env.glow_enabled = bool(s["glow"])
	Engine.max_fps = int(s["max_fps"])


func environment() -> Environment:
	return _env


func sun() -> DirectionalLight3D:
	return _sun
```
`src/render/fighter_view.gd`: 필드 `var _blob: BlobShadow`, `setup` 끝에 `_blob = BlobShadow.new(); add_child(_blob); _blob.setup(config)`, `apply`의 `position = ...` 다음 줄에 `_blob.follow(position)`, 함수:
```gdscript
func set_blob_shadow(on: bool) -> void:
	_blob.visible = on


func blob_visible() -> bool:
	return _blob.visible


func blob() -> BlobShadow:
	return _blob
```
(KO로 뷰를 숨길 때 `top_level` 블롭도 숨긴다: `apply`의 KO 분기에 `_blob.visible = false`를 넣고, 다시 보일 때는 품질 설정값으로 되돌리기 위해 `var _blob_wanted: bool`에 `set_blob_shadow` 값을 저장해 `_blob.visible = _blob_wanted`로 복원.)
`src/main/main.gd`: `var _env: EnvironmentRig`로 환경을 필드에 보관하고, `_apply_quality()`를 만들어 `_ready` 끝(`_start_match()` 앞)과 `_config.changed`에 연결:
```gdscript
func _apply_quality() -> void:
	var level := Quality.resolve(_config.quality_level, Quality.platform())
	_env.apply_quality(level)
	var blobs := bool(Quality.settings(level)["blob_shadows"])
	for v: FighterView in _views:
		v.set_blob_shadow(blobs)
```
`scripts/capture_evidence.gd`: `--quality=N` (config.quality_level 설정 + `emit_changed()`), 사용법 주석 갱신.

- [ ] **Step 4: 테스트 + 캡처**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변).
Run (창 모드): `for n in 0 2; do godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out="$PWD/dev/active/phase-3/evidence/quality-$n.png" --frames=90 --quality=$n; done` — LOW는 블롭 그림자, HIGH는 실시간 그림자·블룸이 보이는지 확인.

- [ ] **Step 5: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/render/quality.gd src/render/quality.gd.uid src/render/blob_shadow.gd src/render/blob_shadow.gd.uid src/render/environment_rig.gd src/render/fighter_view.gd src/main/main.gd src/config/game_config.gd scripts/capture_evidence.gd tests/unit/test_quality.gd tests/unit/test_quality.gd.uid dev/active/phase-3/evidence/quality-0.png dev/active/phase-3/evidence/quality-2.png
git commit -m "feat: add three render quality levels with a low-end blob shadow" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 9: ViewEvents(뷰 차이 이벤트) + 착지 먼지 + 넉백 궤적 (GD-FEEL-04)

**Files:**
- Create: `src/render/feel/view_events.gd`, `src/render/feel/dust_puff.gd`, `src/render/feel/knockback_trail.gd`
- Modify: `src/config/game_config.gd` (FeelVfx 그룹), `src/render/feel/feel_director.gd` (`on_view_events`), `src/main/main.gd` (틱마다 ViewEvents 수집)
- Test: `tests/unit/test_view_events.gd`, `tests/unit/test_vfx.gd`

**Interfaces:**
- Consumes: 틱 단위 prev/curr fighter view (`pos`, `on_ground`, `spawn_id`, `state`, `id`), T8 `Quality.particle_scale`
- Produces:
  - `GameConfig` FeelVfx 그룹(`NON_SIM_GROUPS`에 `"FeelVfx"`): `trail_speed_threshold: float = 9.0`, `trail_speed_full: float = 20.0`, `dust_min_fall_speed: float = 4.0`, `dust_full_fall_speed: float = 14.0`
  - `static func ViewEvents.detect(prev: Array, curr: Array, config: GameConfig) -> Array[Dictionary]` — 틱 하나의 차이. 이벤트: `{"type": "landed", "id", "pos", "intensity"}`, `{"type": "respawned", "id", "pos"}`, `{"type": "trail", "id", "pos", "intensity"}`
  - `static func ViewEvents.trail_intensity(speed: float, config: GameConfig) -> float` (threshold 미만 0, full 이상 1, 사이 선형)
  - `static func ViewEvents.dust_intensity(fall_speed: float, config: GameConfig) -> float` (같은 방식, dust_*)
  - `DustPuff` (Node3D): `play(at: Vector3, intensity: float, particle_scale: float)`, 스스로 free
  - `KnockbackTrail` (Node3D): `add_sample(at: Vector3, intensity: float, color: Color, particle_scale: float)` — 플레이어 색 퍼프 + 잎사귀, 스스로 사라짐
  - `FeelDirector.on_view_events(events: Array) -> void`
- 근거: `[DS-VFX-03]` `[DS-VFX-04]` `[GD-FEEL-04]` `[PRD-FX-02]` · F8

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_view_events.gd`:
```gdscript
extends GutTest
## Render-side events from view differences (context F8): no sim events are added.


func _f(id: int, pos: Vector3, on_ground: bool, state: int = Fighter.State.IDLE, spawn_id: int = 0) -> Dictionary:
	return {"id": id, "pos": pos, "on_ground": on_ground, "state": state, "spawn_id": spawn_id}


func test_landing_intensity_follows_fall_speed() -> void:
	var c := GameConfig.new()
	var drop := c.dust_full_fall_speed * SimTime.TICK_DT
	var e := ViewEvents.detect([_f(0, Vector3(0, drop, 0), false)], [_f(0, Vector3.ZERO, true)], c)
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "landed")
	assert_almost_eq(float(e[0]["intensity"]), 1.0, 0.001)


func test_soft_landing_makes_no_dust() -> void:
	var c := GameConfig.new()
	var drop := c.dust_min_fall_speed * 0.5 * SimTime.TICK_DT
	assert_eq(ViewEvents.detect([_f(0, Vector3(0, drop, 0), false)], [_f(0, Vector3.ZERO, true)], c).size(), 0)


func test_respawn_is_a_spawn_id_change() -> void:
	var e := ViewEvents.detect([_f(0, Vector3(0, -9, 0), false, Fighter.State.AIR, 1)],
			[_f(0, Vector3(0, 6, 0), false, Fighter.State.AIR, 2)], GameConfig.new())
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "respawned")
	assert_eq(e[0]["pos"], Vector3(0, 6, 0))


func test_fast_launch_leaves_a_trail() -> void:
	var c := GameConfig.new()
	var step := c.trail_speed_full * SimTime.TICK_DT
	var e := ViewEvents.detect([_f(1, Vector3.ZERO, false, Fighter.State.HITSTUN)],
			[_f(1, Vector3(step, 0, 0), false, Fighter.State.HITSTUN)], c)
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "trail")
	assert_almost_eq(float(e[0]["intensity"]), 1.0, 0.001)


func test_running_is_not_a_trail() -> void:
	var c := GameConfig.new()
	var step := c.trail_speed_full * SimTime.TICK_DT
	var e := ViewEvents.detect([_f(1, Vector3.ZERO, true, Fighter.State.MOVE)],
			[_f(1, Vector3(step, 0, 0), true, Fighter.State.MOVE)], c)
	assert_eq(e.size(), 0, "trails are for launched fighters only")


func test_intensity_ramps() -> void:
	var c := GameConfig.new()
	assert_eq(ViewEvents.trail_intensity(c.trail_speed_threshold - 0.1, c), 0.0)
	assert_eq(ViewEvents.trail_intensity(c.trail_speed_full + 5.0, c), 1.0)
	var mid := (c.trail_speed_threshold + c.trail_speed_full) * 0.5
	assert_almost_eq(ViewEvents.trail_intensity(mid, c), 0.5, 0.001)
```
`tests/unit/test_vfx.gd`:
```gdscript
extends GutTest
## VFX nodes spawn, scale with intensity and free themselves.


func test_dust_puff_frees_itself() -> void:
	var d := DustPuff.new()
	add_child(d)
	d.play(Vector3.ZERO, 1.0, 1.0)
	assert_gt(d.get_child_count(), 0)
	await wait_seconds(DustPuff.LIFETIME + 0.2)
	assert_false(is_instance_valid(d), "dust puff frees itself")


func test_dust_count_scales_with_intensity_and_quality() -> void:
	var big := DustPuff.new()
	add_child_autofree(big)
	big.play(Vector3.ZERO, 1.0, 1.0)
	var small := DustPuff.new()
	add_child_autofree(small)
	small.play(Vector3.ZERO, 1.0, 0.5)
	assert_gt(big.get_child_count(), small.get_child_count(), "LOW quality spawns fewer puffs")


func test_trail_samples_fade_out() -> void:
	var t := KnockbackTrail.new()
	add_child_autofree(t)
	t.add_sample(Vector3.ZERO, 1.0, DS.P1, 1.0)
	assert_gt(t.get_child_count(), 0)
	await wait_seconds(KnockbackTrail.SAMPLE_LIFETIME + 0.2)
	assert_eq(t.get_child_count(), 0, "samples free themselves")
```
Run: `./scripts/test.sh -gselect=test_view_events` → FAIL

- [ ] **Step 2: GameConfig FeelVfx**

Quality 그룹 뒤에 추가, `NON_SIM_GROUPS`에 `"FeelVfx"`:
```gdscript

@export_group("FeelVfx")
## Knockback trail (design.md GD-FEEL-04): off below threshold, full strength at full (m/s).
@export_range(1.0, 40.0, 0.5) var trail_speed_threshold: float = 9.0
@export_range(2.0, 60.0, 0.5) var trail_speed_full: float = 20.0
## Landing dust (DS-VFX-03) by fall speed (m/s).
@export_range(0.0, 20.0, 0.5) var dust_min_fall_speed: float = 4.0
@export_range(1.0, 40.0, 0.5) var dust_full_fall_speed: float = 14.0
```

- [ ] **Step 3: ViewEvents**

`src/render/feel/view_events.gd`:
```gdscript
class_name ViewEvents
extends RefCounted
## Presentation events read from one tick's view difference (context F8): landing (dust),
## respawn (light pillar) and fast launched motion (knockback trail). The sim emits nothing new.


static func detect(prev: Array, curr: Array, config: GameConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in mini(prev.size(), curr.size()):
		var a: Dictionary = prev[i]
		var b: Dictionary = curr[i]
		var id := int(b["id"])
		var pos: Vector3 = b["pos"]
		if int(a["spawn_id"]) != int(b["spawn_id"]):
			out.append({"type": "respawned", "id": id, "pos": pos})
			continue
		var from: Vector3 = a["pos"]
		if not bool(a["on_ground"]) and bool(b["on_ground"]):
			var dust := dust_intensity((from.y - pos.y) / SimTime.TICK_DT, config)
			if dust > 0.0:
				out.append({"type": "landed", "id": id, "pos": pos, "intensity": dust})
		if int(b["state"]) == Fighter.State.HITSTUN:
			var trail := trail_intensity(from.distance_to(pos) / SimTime.TICK_DT, config)
			if trail > 0.0:
				out.append({"type": "trail", "id": id, "pos": pos, "intensity": trail})
	return out


static func trail_intensity(speed: float, config: GameConfig) -> float:
	return _ramp(speed, config.trail_speed_threshold, config.trail_speed_full)


static func dust_intensity(fall_speed: float, config: GameConfig) -> float:
	return _ramp(fall_speed, config.dust_min_fall_speed, config.dust_full_fall_speed)


static func _ramp(v: float, lo: float, hi: float) -> float:
	if v < lo:
		return 0.0
	if hi <= lo:
		return 1.0
	return clampf((v - lo) / (hi - lo), 0.0, 1.0)
```

- [ ] **Step 4: DustPuff + KnockbackTrail**

`src/render/feel/dust_puff.gd`:
```gdscript
class_name DustPuff
extends Node3D
## Landing dust (design.md DS-VFX-03): soft grass-and-dirt cloud puffs that swell outward and
## shrink away. Count and size follow the fall speed; LOW quality halves the count.

const MAX_PUFFS := 8
const MIN_PUFFS := 2
const PUFF_SIZE := 0.22
const SPREAD := 0.6
const LIFETIME := 0.45
const COLORS := [DS.GRASS_SUN, DS.DIRT, DS.GRASS]


func play(at: Vector3, intensity: float, particle_scale: float) -> void:
	position = at
	var count := maxi(roundi(lerpf(MIN_PUFFS, MAX_PUFFS, intensity) * particle_scale), 1)
	for i: int in count:
		var a := TAU * float(i) / count
		var puff := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = PUFF_SIZE * (0.6 + 0.4 * intensity)
		s.height = s.radius * 1.2
		puff.mesh = s
		puff.material_override = ToonMaterials.toon(COLORS[i % COLORS.size()])
		puff.scale = Vector3.ONE * 0.3
		add_child(puff)
		var out := Vector3(cos(a), 0.15, sin(a)) * SPREAD * (0.5 + intensity)
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "position", out, LIFETIME).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ZERO, LIFETIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
```
`src/render/feel/knockback_trail.gd`:
```gdscript
class_name KnockbackTrail
extends Node3D
## Knockback trail (design.md DS-VFX-04, GD-FEEL-04): each tick a launched fighter moves fast,
## a player-colored soft puff (plus a falling leaf at high intensity) is left behind and fades.
## Size follows the intensity (speed / trail_speed_full). Samples live in world space.

const SAMPLE_SIZE := 0.35
const SAMPLE_LIFETIME := 0.35
const LEAF_THRESHOLD := 0.6
const LEAF_SIZE := 0.08
const LEAF_FALL := 0.8


func add_sample(at: Vector3, intensity: float, color: Color, particle_scale: float) -> void:
	_spawn(at, SAMPLE_SIZE * lerpf(0.4, 1.0, intensity), color, Vector3.ZERO)
	if intensity >= LEAF_THRESHOLD and particle_scale >= 1.0:
		_spawn(at, LEAF_SIZE, DS.GRASS_MID, Vector3.DOWN * LEAF_FALL)


func _spawn(at: Vector3, size: float, color: Color, drift: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	mi.mesh = s
	mi.material_override = ToonMaterials.toon(color)
	mi.top_level = true
	add_child(mi)
	mi.global_position = at + Vector3.UP * 0.8
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ZERO, SAMPLE_LIFETIME).set_ease(Tween.EASE_IN)
	if drift != Vector3.ZERO:
		tw.tween_property(mi, "global_position", mi.global_position + drift, SAMPLE_LIFETIME)
	tw.chain().tween_callback(mi.queue_free)
```

- [ ] **Step 5: FeelDirector + main**

`src/render/feel/feel_director.gd`: 필드 `var _trail: KnockbackTrail`, `setup` 끝에 `_trail = KnockbackTrail.new(); add_child(_trail)`, 함수:
```gdscript
## Render-side events from ViewEvents (context F8).
func on_view_events(events: Array) -> void:
	var scale := Quality.particle_scale(_config)
	for e: Dictionary in events:
		match String(e["type"]):
			"landed":
				var dust := DustPuff.new()
				add_child(dust)
				dust.play(e["pos"], float(e["intensity"]), scale)
			"trail":
				_trail.add_sample(e["pos"], float(e["intensity"]), PlayerStyle.color(int(e["id"])), scale)
```
(T10이 `"respawned"` 분기를 더한다.) 머리 주석에 `Landing dust and knockback trails come from ViewEvents.`를 덧붙인다.
`src/main/main.gd`: `_process`의 틱 루프에서 `_curr_state = _world.state_view()` 다음에 `view_events.append_array(ViewEvents.detect(_prev_state["fighters"], _curr_state["fighters"], _config))`를 넣고(`var view_events: Array = []`를 `events` 옆에 선언), `_feel.on_events(events)` 다음에 `_feel.on_view_events(view_events)`.

- [ ] **Step 6: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). Run: `./scripts/check-all.sh`
```bash
git add src/render/feel/view_events.gd src/render/feel/view_events.gd.uid src/render/feel/dust_puff.gd src/render/feel/dust_puff.gd.uid src/render/feel/knockback_trail.gd src/render/feel/knockback_trail.gd.uid src/render/feel/feel_director.gd src/main/main.gd src/config/game_config.gd tests/unit/test_view_events.gd tests/unit/test_view_events.gd.uid tests/unit/test_vfx.gd tests/unit/test_vfx.gd.uid
git commit -m "feat: add landing dust and speed-scaled knockback trails from view events" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 10: 링아웃 물보라·별 폭발 + 카메라 펀치, 리스폰 햇살 기둥, 차지 광, 떨어뜨린 아이템 모양

**Files:**
- Create: `src/render/feel/ringout_burst.gd`, `src/render/feel/respawn_beam.gd`, `src/render/feel/charge_glow.gd`
- Modify: `src/render/decor_view.gd` (`is_over_lake`), `src/render/camera_rig.gd` (`punch`), `src/render/feel/feel_director.gd`, `src/render/fighter_view.gd` (차지 광), `src/render/item_view.gd` + `src/render/item_layer.gd` (상자 여부)
- Test: `tests/unit/test_vfx.gd`, `tests/unit/test_item_view.gd`

**Interfaces:**
- Produces:
  - `static func DecorView.is_over_lake(pos: Vector3, arena_radius: float) -> bool` — 호수 중심 `(arena_radius + LAKE_OFFSET, _, 0)`, 반경 `LAKE_RADIUS` (수평 거리)
  - `RingoutBurst` (Node3D): `play(at: Vector3, splash: bool, color: Color, particle_scale: float)` — splash면 `DS.WATER`·`DS.SKY` 물방울 기둥, 아니면 플레이어 색 별(둥근 꽃잎) 폭발. 스스로 free
  - `RespawnBeam` (Node3D): `play(at: Vector3)` — `DS.GLOW` 반투명 기둥이 위에서 내려와 사라짐 (`DS.GLOW` 알파 토큰 `RESPAWN_BEAM`)
  - `ChargeGlow` (Node3D): `set_charge(ratio: float)` (0이면 숨김, 1이면 최대 크기 + 맥동)
  - `CameraRig.punch(strength: float) -> void` — 거리를 잠깐 줄였다 복귀 (`PUNCH_DECAY`), `punch_offset() -> float`
  - `FeelDirector`: `"ringout"` 이벤트 → RingoutBurst(splash = `DecorView.is_over_lake`) + `camera.punch`; `"respawned"` 뷰 이벤트 → RespawnBeam
  - `FighterView`: 뷰 `state == CHARGE`면 `ChargeGlow.set_charge(charge_ticks / to_ticks(heavy_charge_max_time))`
  - `ItemView.setup(kind: int, config: GameConfig, boxed: bool = true)`; `ItemLayer`는 처음 보는 아이템이 FALLING이고 `pos.y >= item_drop_height - ItemLayer.BOX_HEIGHT_TOLERANCE`일 때만 boxed
  - 토큰 `DS.RESPAWN_BEAM := Color("#FFF3C466")` (GLOW 40%)
- 근거: `[DS-VFX-05]` `[DS-VFX-06]` `[PRD-FX-02]` · F8 · Phase 2 이월(떨어뜨린 아이템)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_vfx.gd` 끝에 추가:
```gdscript


func test_lake_check_matches_the_decor_layout() -> void:
	var r := 10.0
	assert_true(DecorView.is_over_lake(Vector3(r + DecorView.LAKE_OFFSET, -5, 0), r))
	assert_false(DecorView.is_over_lake(Vector3(-(r + DecorView.LAKE_OFFSET), -5, 0), r))


func test_ringout_burst_both_kinds_free_themselves() -> void:
	for splash: bool in [true, false]:
		var b := RingoutBurst.new()
		add_child(b)
		b.play(Vector3.ZERO, splash, DS.P2, 1.0)
		assert_gt(b.get_child_count(), 0)
		await wait_seconds(RingoutBurst.LIFETIME + 0.2)
		assert_false(is_instance_valid(b))


func test_respawn_beam_frees_itself() -> void:
	var beam := RespawnBeam.new()
	add_child(beam)
	beam.play(Vector3(0, 6, 0))
	await wait_seconds(RespawnBeam.LIFETIME + 0.2)
	assert_false(is_instance_valid(beam))


func test_charge_glow_scales_with_charge() -> void:
	var g := ChargeGlow.new()
	add_child_autofree(g)
	g.set_charge(0.0)
	assert_false(g.visible)
	g.set_charge(0.5)
	var half := g.base_scale()
	g.set_charge(1.0)
	assert_true(g.visible)
	assert_gt(g.base_scale(), half)


func test_camera_punch_decays() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.setup(GameConfig.new())
	rig.punch(1.0)
	assert_gt(rig.punch_offset(), 0.0)
	for i: int in 120:
		rig.follow(PackedVector3Array([Vector3.ZERO]), 1.0 / 60.0)
	assert_almost_eq(rig.punch_offset(), 0.0, 0.01, "punch settles back")
```
`tests/unit/test_item_view.gd` 끝에 추가:
```gdscript


func test_dropped_item_is_not_a_box() -> void:
	var c := GameConfig.new()
	var layer := ItemLayer.new()
	add_child_autofree(layer)
	layer.setup(c)
	var spawned := _item(5, Item.Kind.BAT, Item.State.FALLING, Vector3(0, c.item_drop_height, 0))
	var dropped := _item(6, Item.Kind.ROCK, Item.State.FALLING, Vector3(2, 1.0, 0))
	layer.sync([], [spawned, dropped], 1.0, 0)
	assert_true(layer.view(5).box_visible(), "a box from the sky")
	assert_false(layer.view(6).box_visible(), "a dropped rock keeps its shape")
	assert_true(layer.view(6).shape_visible())
	assert_true(layer.view(6).shadow_visible(), "still casts the landing shadow")
```
Run: `./scripts/test.sh -gselect=test_vfx` → FAIL

- [ ] **Step 2: 구현 — DecorView·CameraRig**

`src/render/decor_view.gd`에 추가:
```gdscript
## True when a point is horizontally over the lake (ring-outs there splash, DS-VFX-05).
static func is_over_lake(pos: Vector3, arena_radius: float) -> bool:
	return Vector2(pos.x - (arena_radius + LAKE_OFFSET), pos.z).length() <= LAKE_RADIUS
```
`src/render/camera_rig.gd`: 상수 `const PUNCH_DISTANCE := 3.0`, `const PUNCH_DECAY := 10.0`, 필드 `var _punch: float = 0.0`, 함수 `punch(strength)`(`_punch = maxf(_punch, clampf(strength, 0.0, 1.0))`), `punch_offset() -> float`(`return _punch * PUNCH_DISTANCE`), `follow`에서 카메라 위치 계산 직전 `_punch = move_toward(_punch, 0.0, PUNCH_DECAY * delta * maxf(_punch, 0.1))`, 위치 계산의 `* _distance`를 `* (_distance - punch_offset())`로.

- [ ] **Step 3: 구현 — VFX 노드**

`src/ui/theme/tokens.gd`의 `GUARD_BUBBLE` 다음에:
```gdscript
## Respawn light pillar (design.md DS-VFX-06): glow at 40%.
const RESPAWN_BEAM := Color("#FFF3C466")
```
`src/render/feel/ringout_burst.gd`:
```gdscript
class_name RingoutBurst
extends Node3D
## Ring-out burst (design.md DS-VFX-05): over the lake a tall water splash of round droplets,
## elsewhere a star burst of round player-colored petals. Frees itself.

const LIFETIME := 0.9
const DROPS := 14
const PETALS := 18
const DROP_SIZE := 0.25
const PETAL_SIZE := 0.18
const SPLASH_HEIGHT := 4.0
const BURST_RADIUS := 3.0


func play(at: Vector3, splash: bool, color: Color, particle_scale: float) -> void:
	position = at
	var count := maxi(roundi((DROPS if splash else PETALS) * particle_scale), 4)
	for i: int in count:
		var a := TAU * float(i) / count
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = DROP_SIZE if splash else PETAL_SIZE
		s.height = s.radius * 2.0
		mi.mesh = s
		mi.material_override = ToonMaterials.toon((DS.WATER if i % 2 == 0 else DS.SKY) if splash else color, 0.3)
		add_child(mi)
		var target := Vector3(cos(a) * 0.8, SPLASH_HEIGHT * (0.6 + 0.4 * float(i % 3) / 2.0), sin(a) * 0.8) if splash \
				else Vector3(cos(a), 0.4 * sin(a * 3.0), sin(a)) * BURST_RADIUS
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", target, LIFETIME * 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ZERO, LIFETIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
```
`src/render/feel/respawn_beam.gd`:
```gdscript
class_name RespawnBeam
extends Node3D
## Respawn light pillar (design.md DS-VFX-06): a soft glow column from the respawn point down to
## the floor that narrows and fades. Frees itself.

const LIFETIME := 0.7
const RADIUS := 0.7


func play(at: Vector3) -> void:
	var height := maxf(at.y, 1.0)
	position = Vector3(at.x, height * 0.5, at.z)
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = RADIUS
	c.bottom_radius = RADIUS
	c.height = height
	mi.mesh = c
	mi.material_override = ToonMaterials.translucent(DS.RESPAWN_BEAM)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.05, 1.0, 0.05), LIFETIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
```
`src/render/feel/charge_glow.gd`:
```gdscript
class_name ChargeGlow
extends Node3D
## Heavy-charge glow (design.md DS-VFX-06): a warm glow orb around the fighter's hands that grows
## with the charge and pulses at full charge. Bloom (HIGH quality) makes it bleed.

const MIN_SCALE := 0.3
const MAX_SCALE := 1.0
const RADIUS := 0.35
const PULSE_HZ := 6.0
const PULSE_AMOUNT := 0.12

var _orb: MeshInstance3D
var _ratio: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	var s := SphereMesh.new()
	s.radius = RADIUS
	s.height = RADIUS * 2.0
	_orb = MeshInstance3D.new()
	_orb.mesh = s
	_orb.material_override = ToonMaterials.toon(DS.GLOW, 0.8)
	add_child(_orb)
	visible = false


func set_charge(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	visible = _ratio > 0.0
	scale = Vector3.ONE * base_scale()


func base_scale() -> float:
	return lerpf(MIN_SCALE, MAX_SCALE, _ratio)


func _process(delta: float) -> void:
	if not visible or _ratio < 1.0:
		return
	_time += delta
	scale = Vector3.ONE * (base_scale() * (1.0 + PULSE_AMOUNT * sin(_time * TAU * PULSE_HZ)))
```

- [ ] **Step 4: 연결 — FeelDirector·FighterView·ItemView/Layer**

`feel_director.gd`:
- `on_events`의 `"ringout"` 분기에 기존 흔들림 다음으로:
```gdscript
				var at: Vector3 = e["pos"]
				var burst := RingoutBurst.new()
				add_child(burst)
				burst.play(at, DecorView.is_over_lake(at, _config.arena_radius), PlayerStyle.color(int(e["id"])),
						Quality.particle_scale(_config))
				if _camera != null:
					_camera.punch(1.0)
```
- `on_view_events`에 분기 추가:
```gdscript
			"respawned":
				var beam := RespawnBeam.new()
				add_child(beam)
				beam.play(e["pos"])
```
`fighter_view.gd`: 필드 `var _charge_glow: ChargeGlow`, `setup` 끝에서 생성해 손 높이(`_held.position`과 같은 자리)에 두고, `apply`에서:
```gdscript
	var charging := int(curr["state"]) == Fighter.State.CHARGE
	_charge_glow.set_charge(float(curr.get("charge_ticks", 0)) / maxf(SimTime.to_ticks(_config.heavy_charge_max_time), 1.0) if charging else 0.0)
```
`item_view.gd`: `setup(kind: int, config: GameConfig, boxed: bool = true)` — 필드 `var _boxed: bool`에 저장하고 `apply`에서 `var falling := ...` 다음 줄을 `var show_box := falling and _boxed`로, `_box.visible = show_box`, `_shape.visible = not show_box`, 그림자는 `falling`일 때 그대로.
`item_layer.gd`: 상수 `const BOX_HEIGHT_TOLERANCE := 0.5`, 새 뷰를 만들 때:
```gdscript
			var p: Vector3 = it["pos"]
			var boxed := int(it["state"]) == Item.State.FALLING and p.y >= _config.item_drop_height - BOX_HEIGHT_TOLERANCE
			v.setup(int(it["kind"]), _config, boxed)
```

- [ ] **Step 5: 테스트 + 캡처 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변).
Run (창 모드): 링아웃 데모를 녹화해 물보라·별 폭발·카메라 펀치를 확인:
```bash
godot --path . --write-movie dev/active/phase-3/evidence/ringout-vfx.avi --fixed-fps 60 --resolution 960x540 --quit-after 300 res://src/debug/ringout_demo.tscn
ffmpeg -loglevel error -y -i dev/active/phase-3/evidence/ringout-vfx.avi -vf "select=eq(n\,150)" -vframes 1 dev/active/phase-3/evidence/ringout-vfx-150.png
```
(링아웃 순간이 150프레임이 아니면 번호를 조정. 이미지를 열어 확인하고 보고서에 설명.)
Run: `./scripts/check-all.sh`
```bash
git add src/render/feel/ringout_burst.gd src/render/feel/ringout_burst.gd.uid src/render/feel/respawn_beam.gd src/render/feel/respawn_beam.gd.uid src/render/feel/charge_glow.gd src/render/feel/charge_glow.gd.uid src/render/feel/feel_director.gd src/render/decor_view.gd src/render/camera_rig.gd src/render/fighter_view.gd src/render/item_view.gd src/render/item_layer.gd src/ui/theme/tokens.gd tests/unit/test_vfx.gd tests/unit/test_item_view.gd dev/active/phase-3/evidence/ringout-vfx-150.png
git commit -m "feat: add ring-out splash and star burst, respawn beam, charge glow and camera punch" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 11: SfxSynth(합성기) + SfxRecipes + 효과음 굽기

**Files:**
- Create: `src/audio/sfx_synth.gd`, `src/audio/wav_writer.gd`, `src/audio/sfx_recipes.gd`, `scripts/bake_sfx.gd`, `assets/sfx/*.wav` (구운 결과)
- Modify: `ASSETS.md`
- Test: `tests/unit/test_sfx_synth.gd`

**Interfaces:**
- Produces:
  - `SfxSynth.SAMPLE_RATE := 44100`
  - `static func SfxSynth.render(p: Dictionary) -> PackedFloat32Array` — 키: `wave`("square"|"saw"|"sine"|"triangle"|"noise"), `freq_start`, `freq_end`(Hz), `freq_curve`(지수, 1 = 선형), `attack`, `sustain`, `decay`(초), `sustain_level`(0~1), `vibrato_depth`(비율), `vibrato_hz`, `duty`(square), `noise_mix`(0~1), `lowpass`(0~1, 1 = 끔), `volume`(피크 0~1), `seed`(int). 빠진 키는 `SfxSynth.DEFAULTS`
  - `static func SfxSynth.peak(samples: PackedFloat32Array) -> float`
  - `static func WavWriter.to_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV` (16bit mono, -1~1 클램프)
  - `const SfxRecipes.RECIPES: Dictionary` — 이름 → 파라미터. 이름: `hit_light`, `hit_heavy`, `guard`, `jump`, `land`, `ringout_splash`, `ringout_whistle`, `respawn`, `item_pickup`, `item_throw`, `explosion`, `ui_click`, `ui_confirm`, `ui_cancel`
  - `static func SfxRecipes.path(name: String) -> String` = `"res://assets/sfx/%s.wav"`
- 근거: `[DS-SFX-01]` `[PRD-FX-02]` · F9

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_sfx_synth.gd`:
```gdscript
extends GutTest
## Offline SFX synthesis (context F9): deterministic, exact length, peak-normalized, and every
## recipe baked into assets/sfx.


func _zero_crossings(s: PackedFloat32Array, from: int, to: int) -> int:
	var n := 0
	for i: int in range(from + 1, to):
		if (s[i - 1] < 0.0) != (s[i] < 0.0):
			n += 1
	return n


func test_length_follows_the_envelope() -> void:
	var s := SfxSynth.render({"attack": 0.01, "sustain": 0.05, "decay": 0.04})
	assert_eq(s.size(), roundi(0.1 * SfxSynth.SAMPLE_RATE))


func test_deterministic_including_noise() -> void:
	var p := {"wave": "noise", "sustain": 0.1, "seed": 7}
	assert_eq(SfxSynth.render(p), SfxSynth.render(p))
	var q := p.duplicate()
	q["seed"] = 8
	assert_ne(SfxSynth.render(p), SfxSynth.render(q))


func test_peak_is_normalized_to_volume() -> void:
	var s := SfxSynth.render({"wave": "square", "sustain": 0.1, "volume": 0.6})
	assert_almost_eq(SfxSynth.peak(s), 0.6, 0.01)


func test_frequency_sweep_direction() -> void:
	var s := SfxSynth.render({"wave": "sine", "freq_start": 800.0, "freq_end": 200.0, "sustain": 0.4, "attack": 0.0, "decay": 0.0})
	var q := s.size() / 4
	assert_gt(_zero_crossings(s, 0, q), _zero_crossings(s, s.size() - q, s.size()), "falling pitch")


func test_wav_stream_format() -> void:
	var stream := WavWriter.to_stream(PackedFloat32Array([0.0, 1.0, -1.0, 2.0]), SfxSynth.SAMPLE_RATE)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(stream.stereo)
	assert_eq(stream.mix_rate, SfxSynth.SAMPLE_RATE)
	assert_eq(stream.data.size(), 8, "2 bytes per sample")
	assert_eq(stream.data.decode_s16(6), 32767, "clamped to full scale")


func test_every_recipe_is_audible_and_baked() -> void:
	for name: String in SfxRecipes.RECIPES:
		var s := SfxSynth.render(SfxRecipes.RECIPES[name])
		assert_gt(s.size(), 0, name)
		assert_gt(SfxSynth.peak(s), 0.05, "%s is audible" % name)
		assert_lte(SfxSynth.peak(s), 1.0, "%s does not clip" % name)
		assert_true(ResourceLoader.exists(SfxRecipes.path(name)), "%s baked (run scripts/bake_sfx.gd)" % name)
```
Run: `./scripts/test.sh -gselect=test_sfx_synth` → FAIL

- [ ] **Step 2: SfxSynth + WavWriter**

`src/audio/sfx_synth.gd`:
```gdscript
class_name SfxSynth
extends RefCounted
## Tiny sfxr-style synthesizer (context F9): one oscillator (square/saw/sine/triangle/noise) with
## an exponential-curve pitch sweep, vibrato, noise mix, one-pole lowpass and an ADSR-ish
## envelope, peak-normalized to `volume`. Deterministic: noise uses a seeded generator.
## Used offline by scripts/bake_sfx.gd and the music sequencer; nothing synthesizes at runtime.

const SAMPLE_RATE := 44100
const DEFAULTS := {
	"wave": "square", "freq_start": 440.0, "freq_end": 440.0, "freq_curve": 1.0,
	"attack": 0.005, "sustain": 0.08, "decay": 0.12, "sustain_level": 0.7,
	"vibrato_depth": 0.0, "vibrato_hz": 6.0, "duty": 0.5, "noise_mix": 0.0,
	"lowpass": 1.0, "volume": 0.8, "seed": 1,
}


static func render(params: Dictionary) -> PackedFloat32Array:
	var p := DEFAULTS.duplicate()
	p.merge(params, true)
	var attack := float(p["attack"])
	var sustain := float(p["sustain"])
	var decay := float(p["decay"])
	var total := maxi(roundi((attack + sustain + decay) * SAMPLE_RATE), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["seed"])
	var out := PackedFloat32Array()
	out.resize(total)
	var phase := 0.0
	var low := 0.0
	var cutoff := clampf(float(p["lowpass"]), 0.001, 1.0)
	for i: int in total:
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / total
		var f := lerpf(float(p["freq_start"]), float(p["freq_end"]), pow(progress, float(p["freq_curve"])))
		f *= 1.0 + float(p["vibrato_depth"]) * sin(TAU * float(p["vibrato_hz"]) * t)
		phase = fmod(phase + f / SAMPLE_RATE, 1.0)
		var v := _osc(String(p["wave"]), phase, float(p["duty"]), rng)
		v = lerpf(v, rng.randf_range(-1.0, 1.0), float(p["noise_mix"]))
		low += (v - low) * cutoff
		out[i] = low * _envelope(t, attack, sustain, decay, float(p["sustain_level"]))
	var pk := peak(out)
	if pk > 0.0:
		var gain := float(p["volume"]) / pk
		for i: int in total:
			out[i] *= gain
	return out


static func peak(samples: PackedFloat32Array) -> float:
	var m := 0.0
	for s: float in samples:
		m = maxf(m, absf(s))
	return m


static func _osc(wave: String, phase: float, duty: float, rng: RandomNumberGenerator) -> float:
	match wave:
		"saw":
			return phase * 2.0 - 1.0
		"sine":
			return sin(TAU * phase)
		"triangle":
			return 1.0 - 4.0 * absf(phase - 0.5)
		"noise":
			return rng.randf_range(-1.0, 1.0)
	return 1.0 if phase < duty else -1.0


static func _envelope(t: float, attack: float, sustain: float, decay: float, level: float) -> float:
	if t < attack:
		return t / attack
	if t < attack + sustain:
		return lerpf(1.0, level, (t - attack) / maxf(sustain, 0.0001))
	return level * maxf(1.0 - (t - attack - sustain) / maxf(decay, 0.0001), 0.0)
```
`src/audio/wav_writer.gd`:
```gdscript
class_name WavWriter
extends RefCounted
## Float samples -> 16-bit mono AudioStreamWAV (saved with save_to_wav by the bake scripts).

const FULL_SCALE := 32767.0


static func to_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * FULL_SCALE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
```

- [ ] **Step 3: SfxRecipes (말랑·통통 톤)**

`src/audio/sfx_recipes.gd`:
```gdscript
class_name SfxRecipes
extends RefCounted
## Sound recipes (design.md DS-SFX-01): soft, bouncy, wooden/grassy/watery tones — rounded sine
## and triangle bodies, short noise for air and water, no harsh square leads. Every sound is
## original (context F9); scripts/bake_sfx.gd renders them into assets/sfx/<name>.wav.

const RECIPES := {
	"hit_light": {"wave": "triangle", "freq_start": 520.0, "freq_end": 180.0, "freq_curve": 0.5, "attack": 0.002, "sustain": 0.03, "decay": 0.09, "noise_mix": 0.25, "lowpass": 0.5, "volume": 0.7, "seed": 11},
	"hit_heavy": {"wave": "sine", "freq_start": 300.0, "freq_end": 60.0, "freq_curve": 0.4, "attack": 0.002, "sustain": 0.06, "decay": 0.22, "noise_mix": 0.3, "lowpass": 0.35, "volume": 0.9, "seed": 12},
	"guard": {"wave": "sine", "freq_start": 900.0, "freq_end": 700.0, "attack": 0.002, "sustain": 0.02, "decay": 0.15, "vibrato_depth": 0.05, "vibrato_hz": 30.0, "volume": 0.55, "seed": 13},
	"jump": {"wave": "sine", "freq_start": 260.0, "freq_end": 620.0, "freq_curve": 0.7, "attack": 0.005, "sustain": 0.05, "decay": 0.06, "volume": 0.5, "seed": 14},
	"land": {"wave": "noise", "attack": 0.002, "sustain": 0.02, "decay": 0.1, "lowpass": 0.12, "volume": 0.5, "seed": 15},
	"ringout_splash": {"wave": "noise", "attack": 0.01, "sustain": 0.15, "decay": 0.5, "lowpass": 0.3, "sustain_level": 0.5, "volume": 0.85, "seed": 16},
	"ringout_whistle": {"wave": "sine", "freq_start": 1400.0, "freq_end": 380.0, "freq_curve": 1.3, "attack": 0.01, "sustain": 0.5, "decay": 0.2, "vibrato_depth": 0.02, "vibrato_hz": 9.0, "volume": 0.6, "seed": 17},
	"respawn": {"wave": "triangle", "freq_start": 440.0, "freq_end": 990.0, "freq_curve": 0.6, "attack": 0.02, "sustain": 0.2, "decay": 0.25, "vibrato_depth": 0.03, "vibrato_hz": 7.0, "volume": 0.5, "seed": 18},
	"item_pickup": {"wave": "sine", "freq_start": 660.0, "freq_end": 1320.0, "freq_curve": 0.3, "attack": 0.003, "sustain": 0.04, "decay": 0.08, "volume": 0.55, "seed": 19},
	"item_throw": {"wave": "noise", "attack": 0.01, "sustain": 0.08, "decay": 0.1, "lowpass": 0.45, "volume": 0.45, "seed": 20},
	"explosion": {"wave": "noise", "attack": 0.003, "sustain": 0.12, "decay": 0.6, "lowpass": 0.18, "sustain_level": 0.6, "volume": 0.95, "seed": 21},
	"ui_click": {"wave": "sine", "freq_start": 1200.0, "freq_end": 900.0, "attack": 0.001, "sustain": 0.01, "decay": 0.04, "volume": 0.45, "seed": 22},
	"ui_confirm": {"wave": "triangle", "freq_start": 660.0, "freq_end": 990.0, "freq_curve": 0.5, "attack": 0.003, "sustain": 0.05, "decay": 0.12, "volume": 0.5, "seed": 23},
	"ui_cancel": {"wave": "triangle", "freq_start": 700.0, "freq_end": 420.0, "attack": 0.003, "sustain": 0.05, "decay": 0.1, "volume": 0.45, "seed": 24},
}


static func path(name: String) -> String:
	return "res://assets/sfx/%s.wav" % name
```

- [ ] **Step 4: 굽기 스크립트 + 실행**

`scripts/bake_sfx.gd`:
```gdscript
extends SceneTree
## Renders every SfxRecipes entry into assets/sfx/<name>.wav (context F9). Re-run after editing
## a recipe. Run: godot --headless --path . -s res://scripts/bake_sfx.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sfx"))
	for name: String in SfxRecipes.RECIPES:
		var stream := WavWriter.to_stream(SfxSynth.render(SfxRecipes.RECIPES[name]), SfxSynth.SAMPLE_RATE)
		var err := stream.save_to_wav(ProjectSettings.globalize_path(SfxRecipes.path(name)))
		if err != OK:
			push_error("bake_sfx: %s failed (%s)" % [name, error_string(err)])
			quit(1)
			return
	print("bake_sfx: wrote %d sounds" % SfxRecipes.RECIPES.size())
	quit(0)
```
Run: `godot --headless --path . -s res://scripts/bake_sfx.gd` → `godot --headless --path . --import`
`ASSETS.md`에 행 추가: `| assets/sfx/*.wav | 자체 제작 — scripts/bake_sfx.gd + src/audio/sfx_recipes.gd로 합성 | 프로젝트 소유 (오리지널) | 3 |`

- [ ] **Step 5: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). Run: `./scripts/check-all.sh`
```bash
git add src/audio scripts/bake_sfx.gd scripts/bake_sfx.gd.uid assets/sfx tests/unit/test_sfx_synth.gd tests/unit/test_sfx_synth.gd.uid ASSETS.md
git commit -m "feat: synthesize and bake the original sound effect set" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 12: 오디오 버스 + SfxDirector (이벤트 → 효과음, k에 따른 피치·볼륨) + UI 소리

**Files:**
- Create: `src/audio/audio_buses.gd`, `src/audio/sfx_director.gd`
- Modify: `src/config/game_config.gd` (Audio 그룹), `src/render/feel/view_events.gd` (`jumped`), `src/input/touch_input.gd` (`button_pressed` 시그널), `src/ui/components/result_banner/result_banner.gd` (확인 소리 훅), `src/main/main.gd`
- Test: `tests/unit/test_audio.gd`, `tests/unit/test_view_events.gd`

**Interfaces:**
- Produces:
  - `GameConfig` Audio 그룹(`NON_SIM_GROUPS`에 `"Audio"`): `sfx_volume_db: float = 0.0`, `music_volume_db: float = -6.0`, `ui_volume_db: float = -3.0`, `sfx_pitch_per_knockback: float = 0.02`, `music_intense_fade: float = 1.2`
  - `AudioBuses.SFX := "SFX"`, `MUSIC := "Music"`, `UI := "UI"`; `static func AudioBuses.ensure(config: GameConfig) -> void` (없으면 만들고 Master로 보냄, 볼륨 설정, 여러 번 불러도 한 번만)
  - `static func SfxDirector.sound_for(event: Dictionary, config: GameConfig) -> Dictionary` — `{"name": String, "pitch": float, "volume_db": float}` 또는 `{}`(소리 없음). hit: k ≥ `spark_large_threshold`면 `hit_heavy`, 피치 `clamp(1.15 - k × sfx_pitch_per_knockback, 0.7, 1.2)`; guard_hit→guard; ringout→lake면 ringout_splash, 아니면 ringout_whistle; item_pickup/item_throw/explosion; 뷰 이벤트 landed→land(볼륨은 intensity), jumped→jump, respawned→respawn
  - `SfxDirector` (Node): `setup(config: GameConfig)`, `on_events(events: Array)`, `play(name: String, pitch: float = 1.0, volume_db: float = 0.0, bus: String = AudioBuses.SFX)`, `play_ui(name: String)`, `voices() -> int`(풀 크기 `VOICES := 12`)
  - `ViewEvents`: `{"type": "jumped", "id", "pos"}` — 이전 틱 on_ground, 이번 틱 공중이고 y가 올라감
  - `TouchInput` 시그널 `button_pressed(name: String)` (버튼이 눌린 순간)
  - `ResultBanner` 시그널 `restart_requested` 발신 전에 `confirm_sound` 시그널 없이, main이 `restart_requested`에 `play_ui("ui_confirm")`을 연결
- 근거: `[DS-SFX-01]` `[PRD-FX-02]` · F9

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_audio.gd`:
```gdscript
extends GutTest
## Buses and event -> sound mapping (design.md DS-SFX-01).


func test_buses_are_created_once() -> void:
	var c := GameConfig.new()
	AudioBuses.ensure(c)
	var count := AudioServer.bus_count
	AudioBuses.ensure(c)
	assert_eq(AudioServer.bus_count, count, "idempotent")
	for bus: String in [AudioBuses.SFX, AudioBuses.MUSIC, AudioBuses.UI]:
		var idx := AudioServer.get_bus_index(bus)
		assert_ne(idx, -1, bus)
		assert_eq(AudioServer.get_bus_send(idx), &"Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioBuses.MUSIC)), c.music_volume_db, 0.001)


func test_hits_pick_light_or_heavy_and_bend_pitch() -> void:
	var c := GameConfig.new()
	var soft := SfxDirector.sound_for({"type": "hit", "knockback": 2.0, "pos": Vector3.ZERO}, c)
	var hard := SfxDirector.sound_for({"type": "hit", "knockback": c.spark_large_threshold + 4.0, "pos": Vector3.ZERO}, c)
	assert_eq(soft["name"], "hit_light")
	assert_eq(hard["name"], "hit_heavy")
	assert_lt(float(hard["pitch"]), float(soft["pitch"]), "bigger knockback sounds lower")
	assert_between(float(hard["pitch"]), 0.7, 1.2)


func test_ringout_splashes_over_the_lake() -> void:
	var c := GameConfig.new()
	var lake := Vector3(c.arena_radius + DecorView.LAKE_OFFSET, -9, 0)
	assert_eq(SfxDirector.sound_for({"type": "ringout", "pos": lake, "id": 1}, c)["name"], "ringout_splash")
	assert_eq(SfxDirector.sound_for({"type": "ringout", "pos": -lake, "id": 1}, c)["name"], "ringout_whistle")


func test_view_events_and_items_have_sounds() -> void:
	var c := GameConfig.new()
	for pair: Array in [["landed", "land"], ["jumped", "jump"], ["respawned", "respawn"], ["guard_hit", "guard"],
			["item_pickup", "item_pickup"], ["item_throw", "item_throw"], ["explosion", "explosion"]]:
		var e := {"type": pair[0], "pos": Vector3.ZERO, "id": 0, "intensity": 1.0, "knockback": 0.0}
		assert_eq(SfxDirector.sound_for(e, c).get("name", ""), pair[1], String(pair[0]))
	assert_true(SfxDirector.sound_for({"type": "grab", "pos": Vector3.ZERO}, c).is_empty(), "silent events map to {}")


func test_director_plays_through_a_voice_pool() -> void:
	var d := SfxDirector.new()
	add_child_autofree(d)
	d.setup(GameConfig.new())
	assert_eq(d.voices(), SfxDirector.VOICES)
	for i: int in SfxDirector.VOICES + 3:
		d.play("hit_light")
	assert_true(true, "more requests than voices never errors")
```
`tests/unit/test_view_events.gd` 끝에 추가:
```gdscript


func test_takeoff_is_a_jump() -> void:
	var e := ViewEvents.detect([_f(0, Vector3.ZERO, true)], [_f(0, Vector3(0, 0.15, 0), false, Fighter.State.AIR)], GameConfig.new())
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "jumped")


func test_walking_off_an_edge_is_not_a_jump() -> void:
	var e := ViewEvents.detect([_f(0, Vector3.ZERO, true)], [_f(0, Vector3(0, -0.01, 0), false, Fighter.State.AIR)], GameConfig.new())
	assert_eq(e.size(), 0)
```
Run: `./scripts/test.sh -gselect=test_audio` → FAIL

- [ ] **Step 2: Audio 그룹 + AudioBuses**

`game_config.gd` FeelVfx 뒤에 추가, `NON_SIM_GROUPS`에 `"Audio"`:
```gdscript

@export_group("Audio")
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = 0.0
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -6.0
@export_range(-40.0, 6.0, 0.5) var ui_volume_db: float = -3.0
## Hit pitch drops by this much per knockback unit (heavier = lower, design.md DS-SFX-01).
@export_range(0.0, 0.1, 0.001) var sfx_pitch_per_knockback: float = 0.02
## Seconds for the last-stock intensity layer to fade in or out (context F10).
@export_range(0.1, 5.0, 0.1) var music_intense_fade: float = 1.2
```
`src/audio/audio_buses.gd`:
```gdscript
class_name AudioBuses
extends RefCounted
## SFX / Music / UI buses, all sent to Master, volumes from GameConfig (design.md DS-SFX-01/02).

const SFX := "SFX"
const MUSIC := "Music"
const UI := "UI"


static func ensure(config: GameConfig) -> void:
	_bus(SFX, config.sfx_volume_db)
	_bus(MUSIC, config.music_volume_db)
	_bus(UI, config.ui_volume_db)


static func _bus(name: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, volume_db)
```

- [ ] **Step 3: SfxDirector**

`src/audio/sfx_director.gd`:
```gdscript
class_name SfxDirector
extends Node
## Sim and view events -> sound effects (design.md DS-SFX-01). A fixed pool of players; the
## oldest voice is stolen when all are busy. Hit pitch and loudness follow the knockback.

const VOICES := 12
const LIGHT_HIT_VOLUME_DB := -4.0
const LAND_QUIET_DB := -14.0
const MIN_PITCH := 0.7
const MAX_PITCH := 1.2
const BASE_PITCH := 1.15

var _config: GameConfig
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary = {}


func setup(config: GameConfig) -> void:
	_config = config
	AudioBuses.ensure(config)
	for i: int in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for name: String in SfxRecipes.RECIPES:
		var path := SfxRecipes.path(name)
		if ResourceLoader.exists(path):
			_streams[name] = load(path)


static func sound_for(event: Dictionary, config: GameConfig) -> Dictionary:
	match String(event["type"]):
		"hit":
			var k := float(event["knockback"])
			var heavy := k >= config.spark_large_threshold
			return {"name": "hit_heavy" if heavy else "hit_light",
				"pitch": clampf(BASE_PITCH - k * config.sfx_pitch_per_knockback, MIN_PITCH, MAX_PITCH),
				"volume_db": 0.0 if heavy else LIGHT_HIT_VOLUME_DB}
		"guard_hit":
			return {"name": "guard", "pitch": 1.0, "volume_db": 0.0}
		"ringout":
			var lake := DecorView.is_over_lake(event["pos"], config.arena_radius)
			return {"name": "ringout_splash" if lake else "ringout_whistle", "pitch": 1.0, "volume_db": 0.0}
		"landed":
			return {"name": "land", "pitch": 1.0, "volume_db": lerpf(LAND_QUIET_DB, 0.0, float(event["intensity"]))}
		"jumped":
			return {"name": "jump", "pitch": 1.0, "volume_db": 0.0}
		"respawned":
			return {"name": "respawn", "pitch": 1.0, "volume_db": 0.0}
		"item_pickup", "item_throw", "explosion":
			return {"name": String(event["type"]), "pitch": 1.0, "volume_db": 0.0}
	return {}


func on_events(events: Array) -> void:
	for e: Dictionary in events:
		var s := sound_for(e, _config)
		if not s.is_empty():
			play(String(s["name"]), float(s["pitch"]), float(s["volume_db"]))


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0, bus: String = AudioBuses.SFX) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stop()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.bus = bus
	p.play()


func play_ui(name: String) -> void:
	play(name, 1.0, 0.0, AudioBuses.UI)


func voices() -> int:
	return _players.size()
```

- [ ] **Step 4: 점프 뷰 이벤트 + UI 훅 + main 연결**

`view_events.gd`의 `detect`에서 착지 검사 바로 앞에:
```gdscript
		if bool(a["on_ground"]) and not bool(b["on_ground"]) and pos.y > from.y:
			out.append({"type": "jumped", "id": id, "pos": pos})
```
`touch_input.gd`: `signal button_pressed(name: String)`을 선언하고 `_button_down(name)` 첫 줄에 `button_pressed.emit(name)`.
`main.gd`: 필드 `var _sfx: SfxDirector`, `_ready`에서 `_feel` 설정 뒤 `_sfx = SfxDirector.new(); add_child(_sfx); _sfx.setup(_config)`, 터치 설정 뒤 `_touch.button_pressed.connect(func(_n: String) -> void: _sfx.play_ui("ui_click"))`, HUD 설정 뒤 `_hud.restart_requested.connect(func() -> void: _sfx.play_ui("ui_confirm"))`, `_process`에서 `_feel.on_view_events(view_events)` 다음 줄에 `_sfx.on_events(events)`와 `_sfx.on_events(view_events)`, `_config.changed`에 `AudioBuses.ensure(_config)` 연결.
(`result_banner.gd`는 변경 없음 — 확인 소리는 main이 `restart_requested`에서 낸다. Files 목록에서 result_banner는 빼도 된다.)

- [ ] **Step 5: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). Run: `./scripts/check-all.sh`
```bash
git add src/audio/audio_buses.gd src/audio/audio_buses.gd.uid src/audio/sfx_director.gd src/audio/sfx_director.gd.uid src/config/game_config.gd src/render/feel/view_events.gd src/input/touch_input.gd src/main/main.gd tests/unit/test_audio.gd tests/unit/test_audio.gd.uid tests/unit/test_view_events.gd
git commit -m "feat: play event-driven sound effects through audio buses" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 13: MusicDirector (대전 루프 + 마지막 스톡 인텐스 레이어) + 임시 BGM 굽기

**Files:**
- Create: `src/audio/music_sequencer.gd`, `src/audio/music_director.gd`, `scripts/bake_music.gd`, `assets/music/{battle_base,battle_intense,menu}.wav`
- Modify: `src/main/main.gd`, `ASSETS.md`
- Test: `tests/unit/test_music.gd`

**Interfaces:**
- Consumes: T11 `SfxSynth.render`, `WavWriter`, T12 `AudioBuses`, `GameConfig.music_intense_fade`
- Produces:
  - `static var MusicSequencer.SONGS: Dictionary` — `"battle_base"`, `"battle_intense"`, `"menu"` → `{"bpm": float, "bars": int, "tracks": Array}` (트랙 = `{"instrument": String, "notes": Array}`; 노트 = `[beat: float, midi: int, length_beats: float]`, 드럼은 midi 대신 0)
  - `static func MusicSequencer.render(song: Dictionary) -> PackedFloat32Array`, `static func MusicSequencer.length_samples(song: Dictionary) -> int` (= bars × 4 × 60 / bpm × 44100)
  - `static func MusicSequencer.midi_to_hz(midi: int) -> float`
  - `static func MusicDirector.path_for(name: String) -> String` — `res://assets/music/<name>.ogg`가 있으면 그것, 없으면 `.wav` (본곡 교체용)
  - `static func MusicDirector.wants_intense(view: Dictionary) -> bool` — 경기 중이고 살아 있는 누군가의 `stocks == 1`
  - `MusicDirector` (Node): `setup(config: GameConfig)`, `play_battle()`, `play_menu()`, `stop()`, `update_from(view: Dictionary)`, `intense_target_db() -> float`, `is_intense() -> bool`
  - `MusicDirector.SILENT_DB := -60.0`
- 근거: `[DS-SFX-02]` `[PRD-FX-02]` · F10

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_music.gd`:
```gdscript
extends GutTest
## Placeholder BGM and the music director (design.md DS-SFX-02, context F10).


func test_layers_share_length_and_tempo() -> void:
	var base: Dictionary = MusicSequencer.SONGS["battle_base"]
	var intense: Dictionary = MusicSequencer.SONGS["battle_intense"]
	assert_eq(base["bpm"], intense["bpm"])
	assert_eq(MusicSequencer.length_samples(base), MusicSequencer.length_samples(intense), "layers stay in sync")
	assert_eq(MusicSequencer.render(base).size(), MusicSequencer.length_samples(base))


func test_render_is_deterministic_and_audible() -> void:
	var song: Dictionary = MusicSequencer.SONGS["menu"]
	var a := MusicSequencer.render(song)
	assert_eq(a, MusicSequencer.render(song))
	assert_gt(SfxSynth.peak(a), 0.1)
	assert_lte(SfxSynth.peak(a), 1.0)


func test_midi_to_hz() -> void:
	assert_almost_eq(MusicSequencer.midi_to_hz(69), 440.0, 0.001)
	assert_almost_eq(MusicSequencer.midi_to_hz(81), 880.0, 0.001)


func test_intensity_rule() -> void:
	var v := {"match_over": false, "fighters": [{"state": Fighter.State.IDLE, "stocks": 3}, {"state": Fighter.State.IDLE, "stocks": 2}]}
	assert_false(MusicDirector.wants_intense(v))
	(v["fighters"][1] as Dictionary)["stocks"] = 1
	assert_true(MusicDirector.wants_intense(v))
	v["match_over"] = true
	assert_false(MusicDirector.wants_intense(v), "no intensity after the result")


func test_files_are_baked_and_director_switches_layers() -> void:
	for name: String in ["battle_base", "battle_intense", "menu"]:
		assert_true(ResourceLoader.exists(MusicDirector.path_for(name)), "%s baked (run scripts/bake_music.gd)" % name)
	var d := MusicDirector.new()
	add_child_autofree(d)
	d.setup(GameConfig.new())
	d.play_battle()
	assert_eq(d.intense_target_db(), MusicDirector.SILENT_DB)
	d.update_from({"match_over": false, "fighters": [{"state": Fighter.State.IDLE, "stocks": 1}]})
	assert_true(d.is_intense())
	assert_eq(d.intense_target_db(), 0.0)
```
Run: `./scripts/test.sh -gselect=test_music` → FAIL

- [ ] **Step 2: MusicSequencer (오리지널 패턴)**

`src/audio/music_sequencer.gd` — 패턴은 이 파일에서 새로 만든 오리지널이다(레퍼런스 곡의 멜로디·코드 진행을 쓰지 않는다, DS-SFX-02):
```gdscript
class_name MusicSequencer
extends RefCounted
## Tiny offline sequencer for placeholder BGM (design.md DS-SFX-02, context F10): drum, bass and
## marimba-like voices rendered with SfxSynth, mixed and normalized. The patterns below are
## original to this project; the real soundtrack replaces the baked files with the same names.

## static var (not const): the drum patterns are built by _every().
static var SONGS: Dictionary = {
	"battle_base": {"bpm": 150.0, "bars": 8, "tracks": [
		{"instrument": "kick", "notes": _every(0.0, 1.0, 32)},
		{"instrument": "snare", "notes": _every(1.0, 2.0, 16)},
		{"instrument": "bass", "notes": [[0, 45, 0.5], [1.5, 45, 0.5], [2, 48, 0.5], [3, 50, 0.5], [4, 43, 0.5], [5.5, 43, 0.5], [6, 47, 0.5], [7, 50, 0.5],
			[8, 45, 0.5], [9.5, 45, 0.5], [10, 52, 0.5], [11, 50, 0.5], [12, 48, 0.5], [13.5, 47, 0.5], [14, 45, 0.5], [15, 43, 0.5]]},
		{"instrument": "marimba", "notes": [[0, 69, 0.5], [0.5, 72, 0.5], [1, 76, 0.5], [2, 74, 1.0], [3.5, 72, 0.5], [4, 67, 0.5], [4.5, 71, 0.5], [5, 74, 0.5],
			[6, 72, 1.0], [8, 69, 0.5], [8.5, 72, 0.5], [9, 76, 0.5], [10, 79, 1.0], [11.5, 76, 0.5], [12, 74, 0.5], [13, 72, 0.5], [14, 69, 1.5]]},
	]},
	"battle_intense": {"bpm": 150.0, "bars": 8, "tracks": [
		{"instrument": "hat", "notes": _every(0.0, 0.25, 128)},
		{"instrument": "clap", "notes": _every(1.0, 2.0, 16)},
		{"instrument": "whistle", "notes": [[0, 81, 1.0], [1, 79, 0.5], [1.5, 76, 0.5], [2, 79, 2.0], [4, 76, 1.0], [5, 74, 0.5], [5.5, 72, 0.5], [6, 74, 2.0],
			[8, 81, 1.0], [9, 83, 0.5], [9.5, 84, 0.5], [10, 83, 2.0], [12, 79, 1.0], [13, 76, 1.0], [14, 74, 2.0]]},
	]},
	"menu": {"bpm": 100.0, "bars": 8, "tracks": [
		{"instrument": "bass", "notes": [[0, 43, 2.0], [4, 45, 2.0], [8, 48, 2.0], [12, 47, 2.0]]},
		{"instrument": "marimba", "notes": [[0, 67, 1.0], [1, 71, 1.0], [2, 74, 2.0], [4, 69, 1.0], [5, 72, 1.0], [6, 76, 2.0],
			[8, 72, 1.0], [9, 76, 1.0], [10, 79, 2.0], [12, 71, 1.0], [13, 74, 1.0], [14, 78, 2.0]]},
	]},
}
## A written phrase covers 16 beats (4 bars); it repeats to fill the song.
const PHRASE_BEATS := 16.0
const MASTER_PEAK := 0.85


static func length_samples(song: Dictionary) -> int:
	return roundi(float(song["bars"]) * 4.0 * 60.0 / float(song["bpm"]) * SfxSynth.SAMPLE_RATE)


static func midi_to_hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


static func render(song: Dictionary) -> PackedFloat32Array:
	var total := length_samples(song)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var beat_samples := 60.0 / float(song["bpm"]) * SfxSynth.SAMPLE_RATE
	var song_beats := float(song["bars"]) * 4.0
	for track: Dictionary in song["tracks"]:
		for note: Array in track["notes"]:
			var repeat := 0.0
			while float(note[0]) + repeat < song_beats:
				var voice := SfxSynth.render(_voice(String(track["instrument"]), int(note[1]), float(note[2]) * 60.0 / float(song["bpm"])))
				var start := roundi((float(note[0]) + repeat) * beat_samples)
				for i: int in voice.size():
					var j := (start + i) % total  # wrap tails so the loop seam stays seamless
					mix[j] += voice[i]
				repeat += PHRASE_BEATS if String(track["instrument"]) in ["bass", "marimba", "whistle"] else song_beats
	var pk := SfxSynth.peak(mix)
	if pk > 0.0:
		for i: int in total:
			mix[i] *= MASTER_PEAK / pk
	return mix


static func _every(first: float, step: float, count: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append([first + step * i, 0, 0.1])
	return out


static func _voice(instrument: String, midi: int, seconds: float) -> Dictionary:
	match instrument:
		"kick":
			return {"wave": "sine", "freq_start": 130.0, "freq_end": 45.0, "freq_curve": 0.4, "attack": 0.002, "sustain": 0.04, "decay": 0.14, "volume": 0.9, "seed": 31}
		"snare":
			return {"wave": "noise", "attack": 0.002, "sustain": 0.03, "decay": 0.12, "lowpass": 0.55, "volume": 0.5, "seed": 32}
		"hat":
			return {"wave": "noise", "attack": 0.001, "sustain": 0.005, "decay": 0.04, "lowpass": 0.95, "volume": 0.2, "seed": 33}
		"clap":
			return {"wave": "noise", "attack": 0.003, "sustain": 0.02, "decay": 0.09, "lowpass": 0.7, "volume": 0.4, "seed": 34}
		"bass":
			return {"wave": "triangle", "freq_start": midi_to_hz(midi), "freq_end": midi_to_hz(midi), "attack": 0.005, "sustain": seconds * 0.7, "decay": seconds * 0.3, "lowpass": 0.4, "volume": 0.6, "seed": 35}
		"whistle":
			return {"wave": "sine", "freq_start": midi_to_hz(midi), "freq_end": midi_to_hz(midi), "attack": 0.02, "sustain": seconds * 0.8, "decay": seconds * 0.2, "vibrato_depth": 0.01, "vibrato_hz": 5.5, "volume": 0.35, "seed": 36}
	# marimba: bright sine with a fast decay
	return {"wave": "sine", "freq_start": midi_to_hz(midi), "freq_end": midi_to_hz(midi), "attack": 0.002, "sustain": 0.02, "decay": minf(seconds, 0.35), "volume": 0.45, "seed": 37}
```
(`SONGS`는 `_every()` 호출이 들어가므로 const가 아니라 `static var`다. Godot가 static var 초기화에서 정적 함수 호출을 거부하면 `static func songs() -> Dictionary`로 감싸고 호출부를 맞춘 뒤 보고서에 기록한다.)

- [ ] **Step 3: MusicDirector**

`src/audio/music_director.gd`:
```gdscript
class_name MusicDirector
extends Node
## BGM (design.md DS-SFX-02, context F10): the battle loop is an AudioStreamSynchronized of the
## base loop and the intensity layer, which fades in while someone is on their last stock. The
## menu variation is a separate loop. Files named battle_base / battle_intense / menu under
## assets/music can be replaced by the real soundtrack (.ogg preferred, .wav placeholder).

const SILENT_DB := -60.0
const NAMES: Array[String] = ["battle_base", "battle_intense", "menu"]

var _config: GameConfig
var _player: AudioStreamPlayer
var _battle: AudioStreamSynchronized
var _menu: AudioStream
var _intense: bool = false
var _layer_db: float = SILENT_DB


static func path_for(name: String) -> String:
	var ogg := "res://assets/music/%s.ogg" % name
	return ogg if ResourceLoader.exists(ogg) else "res://assets/music/%s.wav" % name


static func wants_intense(view: Dictionary) -> bool:
	if bool(view.get("match_over", false)):
		return false
	for f: Dictionary in view["fighters"]:
		if int(f["state"]) != Fighter.State.KO and int(f["stocks"]) == 1:
			return true
	return false


func setup(config: GameConfig) -> void:
	_config = config
	AudioBuses.ensure(config)
	_player = AudioStreamPlayer.new()
	_player.bus = AudioBuses.MUSIC
	add_child(_player)
	_battle = AudioStreamSynchronized.new()
	_battle.stream_count = 2
	_battle.set_sync_stream(0, _looped(load(path_for("battle_base"))))
	_battle.set_sync_stream(1, _looped(load(path_for("battle_intense"))))
	_battle.set_sync_stream_volume(1, SILENT_DB)
	_menu = _looped(load(path_for("menu")))


func play_battle() -> void:
	_intense = false
	_layer_db = SILENT_DB
	_battle.set_sync_stream_volume(1, SILENT_DB)
	_player.stream = _battle
	_player.play()


func play_menu() -> void:
	_player.stream = _menu
	_player.play()


func stop() -> void:
	_player.stop()


func update_from(view: Dictionary) -> void:
	_intense = wants_intense(view)


func is_intense() -> bool:
	return _intense


func intense_target_db() -> float:
	return 0.0 if _intense else SILENT_DB


func _process(delta: float) -> void:
	if _battle == null:
		return
	var rate := (0.0 - SILENT_DB) / maxf(_config.music_intense_fade, 0.01)
	_layer_db = move_toward(_layer_db, intense_target_db(), rate * delta)
	_battle.set_sync_stream_volume(1, _layer_db)


static func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
```

- [ ] **Step 4: 굽기 + main 연결 + ASSETS**

`scripts/bake_music.gd`:
```gdscript
extends SceneTree
## Renders the placeholder BGM loops into assets/music/<name>.wav (context F10). The real
## soundtrack replaces these files (same names, .ogg allowed). Run:
## godot --headless --path . -s res://scripts/bake_music.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/music"))
	for name: String in MusicDirector.NAMES:
		var samples := MusicSequencer.render(MusicSequencer.SONGS[name])
		var path := ProjectSettings.globalize_path("res://assets/music/%s.wav" % name)
		var err := WavWriter.to_stream(samples, SfxSynth.SAMPLE_RATE).save_to_wav(path)
		if err != OK:
			push_error("bake_music: %s failed (%s)" % [name, error_string(err)])
			quit(1)
			return
	print("bake_music: wrote %d loops" % MusicDirector.NAMES.size())
	quit(0)
```
Run: `godot --headless --path . -s res://scripts/bake_music.gd` → `godot --headless --path . --import`
`main.gd`: 필드 `var _music: MusicDirector`, `_ready`에서 `_sfx` 뒤 `_music = MusicDirector.new(); add_child(_music); _music.setup(_config)`, `_start_match()` 끝에 `_music.play_battle()`, `_process`에서 `_hud.update_from(_curr_state)` 다음에 `_music.update_from(_curr_state)`.
`ASSETS.md`: `| assets/music/*.wav | 임시 BGM — scripts/bake_music.gd + src/audio/music_sequencer.gd (오리지널 패턴). 본곡은 사용자 제작 예정 | 프로젝트 소유 (오리지널) | 3 |`

- [ ] **Step 5: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). Run: `./scripts/check-all.sh`
```bash
git add src/audio/music_sequencer.gd src/audio/music_sequencer.gd.uid src/audio/music_director.gd src/audio/music_director.gd.uid scripts/bake_music.gd scripts/bake_music.gd.uid assets/music src/main/main.gd tests/unit/test_music.gd tests/unit/test_music.gd.uid ASSETS.md
git commit -m "feat: add battle music with a last-stock intensity layer and placeholder loops" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 14: UiMotion — 모션 토큰을 모든 UI 전환에 적용 (DS-TOK-05)

**Files:**
- Create: `src/ui/ui_motion.gd`
- Modify: `src/ui/components/result_banner/result_banner.gd`, `src/ui/components/damage_counter/damage_counter.gd`, `src/ui/components/stock_icons/stock_icons.gd`, `src/ui/components/touch_button/touch_button.gd`, `src/debug/config_panel.gd`
- Test: `tests/unit/test_ui_motion.gd`

**Interfaces:**
- Produces:
  - `enum UiMotion.Token { FAST, BASE, SQUISH, SLOW }`
  - `static func UiMotion.spec(token: int) -> Dictionary` — `{"duration": float, "trans": int, "ease": int}`: FAST 0.08 quad-out, BASE 0.18 quad-out, SQUISH 0.28 elastic-out, SLOW 0.40 cubic-in-out (DS 토큰 값 그대로)
  - `static func UiMotion.pop_in(node: Control, from_scale: float) -> Tween` — 보이게 하고, 스케일 from→1(SQUISH) + 알파 0→1(BASE)
  - `static func UiMotion.fade_out(node: CanvasItem) -> Tween` — 알파 →0(BASE) 후 숨김
  - `static func UiMotion.bump(node: Control, from_scale: float) -> Tween` — 스케일 from→1(SQUISH)
  - `static func UiMotion.release(node: Control) -> Tween` — 눌림 스쿼시 → 1(SQUISH, 탄성 복귀)
  - 적용: ResultBanner 등장 `pop_in`/퇴장 `fade_out`, DamageCounter `_pop` → `bump`, StockIcons 스톡을 잃는 순간 해당 마커 `bump`, TouchButton PRESSED/CHARGING → IDLE·HIGHLIGHT 전환 시 `release`, ConfigPanel 토글 `pop_in`/`fade_out`
- 근거: `[DS-TOK-05]` `[PRD-UI-01]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_ui_motion.gd`:
```gdscript
extends GutTest
## Motion tokens (design.md DS-TOK-05) shared by every UI transition.


func test_token_specs_match_design() -> void:
	var fast := UiMotion.spec(UiMotion.Token.FAST)
	assert_eq(fast["duration"], DS.MOTION_FAST)
	assert_eq(fast["trans"], Tween.TRANS_QUAD)
	assert_eq(fast["ease"], Tween.EASE_OUT)
	assert_eq(UiMotion.spec(UiMotion.Token.BASE)["duration"], DS.MOTION_BASE)
	var squish := UiMotion.spec(UiMotion.Token.SQUISH)
	assert_eq(squish["duration"], DS.MOTION_SQUISH)
	assert_eq(squish["trans"], Tween.TRANS_ELASTIC)
	var slow := UiMotion.spec(UiMotion.Token.SLOW)
	assert_eq(slow["duration"], DS.MOTION_SLOW)
	assert_eq(slow["trans"], Tween.TRANS_CUBIC)
	assert_eq(slow["ease"], Tween.EASE_IN_OUT)


func test_pop_in_then_fade_out() -> void:
	var c := Control.new()
	add_child_autofree(c)
	c.visible = false
	UiMotion.pop_in(c, 0.6)
	assert_true(c.visible)
	await wait_seconds(DS.MOTION_SQUISH + 0.1)
	assert_almost_eq(c.scale.x, 1.0, 0.02)
	assert_almost_eq(c.modulate.a, 1.0, 0.02)
	UiMotion.fade_out(c)
	await wait_seconds(DS.MOTION_BASE + 0.1)
	assert_false(c.visible, "hidden once faded")


func test_banner_and_counter_use_the_tokens() -> void:
	var banner := (load("res://src/ui/components/result_banner/result_banner.tscn") as PackedScene).instantiate() as ResultBanner
	add_child_autofree(banner)
	banner.show_result(0, 0)
	assert_lt(banner.modulate.a, 1.0, "the banner fades in")
	await wait_seconds(DS.MOTION_SQUISH + 0.1)
	assert_almost_eq(banner.modulate.a, 1.0, 0.02)
	banner.hide_result()
	await wait_seconds(DS.MOTION_BASE + 0.1)
	assert_false(banner.visible)


func test_losing_a_stock_bumps_its_marker() -> void:
	var s := (load("res://src/ui/components/stock_icons/stock_icons.tscn") as PackedScene).instantiate() as StockIcons
	add_child_autofree(s)
	s.setup(0, 3)
	await wait_process_frames(1)
	s.set_stocks(2)
	assert_ne((s.get_child(2) as Control).scale, Vector2.ONE, "the lost stock pops")
```
Run: `./scripts/test.sh -gselect=test_ui_motion` → FAIL

- [ ] **Step 2: UiMotion**

`src/ui/ui_motion.gd`:
```gdscript
class_name UiMotion
extends RefCounted
## Motion tokens (design.md DS-TOK-05) as ready-made tweens, so every UI transition uses the
## same timings: fast = press, base = panels, squish = pops and banners, slow = screens.

enum Token { FAST, BASE, SQUISH, SLOW }


static func spec(token: int) -> Dictionary:
	match token:
		Token.FAST:
			return {"duration": DS.MOTION_FAST, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT}
		Token.SQUISH:
			return {"duration": DS.MOTION_SQUISH, "trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT}
		Token.SLOW:
			return {"duration": DS.MOTION_SLOW, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN_OUT}
	return {"duration": DS.MOTION_BASE, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT}


static func pop_in(node: Control, from_scale: float) -> Tween:
	node.visible = true
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	_step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	_step(tw, node, "modulate:a", 1.0, Token.BASE)
	return tw


static func fade_out(node: CanvasItem) -> Tween:
	var tw := node.create_tween()
	_step(tw, node, "modulate:a", 0.0, Token.BASE)
	tw.tween_callback(func() -> void: node.visible = false)
	return tw


static func bump(node: Control, from_scale: float) -> Tween:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	var tw := node.create_tween()
	_step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	return tw


static func release(node: Control) -> Tween:
	var tw := node.create_tween()
	_step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	return tw


static func _step(tw: Tween, node: Object, property: String, to: Variant, token: int) -> void:
	var s := spec(token)
	tw.tween_property(node, property, to, float(s["duration"])).set_trans(int(s["trans"])).set_ease(int(s["ease"]))
```

- [ ] **Step 3: 컴포넌트 적용**

- `result_banner.gd` `show_result`: `visible = true`부터 트윈까지를 `if is_inside_tree(): UiMotion.pop_in(self, POP_FROM); _button.grab_focus() else: visible = true`로 교체. `hide_result`: `if is_inside_tree() and visible: UiMotion.fade_out(self) else: visible = false`. (재시작 테스트 `test_restart_after_a_ko_starts_a_clean_match`가 `result_visible()`을 곧바로 보면 페이드 중에도 visible이 true다 — `Hud.result_visible()`이 페이드 중인 배너를 보이는 것으로 셀 수 있으니 테스트가 깨지면 main 테스트 쪽 대기를 `wait_seconds(DS.MOTION_BASE + 0.1)`로 늘리고 보고서에 적는다.)
- `damage_counter.gd` `_pop`: 본문을 `if is_inside_tree(): UiMotion.bump(self, POP_SCALE)`로 교체.
- `stock_icons.gd` `set_stocks`: 이전에 켜져 있다가 이번에 꺼지는 마커에 `UiMotion.bump(marker, LOST_POP)` (상수 `const LOST_POP := 1.4`), `is_inside_tree()`일 때만.
- `touch_button.gd` `set_state`: 이전 상태가 PRESSED/CHARGING이고 새 상태가 그 둘이 아니면 스케일을 즉시 ONE으로 만들지 말고 `UiMotion.release(self)` (트리 안일 때). HIGHLIGHT 맥동은 기존대로.
- `config_panel.gd` `toggle`: `if _root.visible: UiMotion.fade_out(_root) else: UiMotion.pop_in(_root, 0.96)` (`_root`가 Control이 아니면 `modulate` 페이드만 쓰는 형태로 맞추고 보고서에 기록).

- [ ] **Step 4: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). Run: `./scripts/check-all.sh`
```bash
git add src/ui/ui_motion.gd src/ui/ui_motion.gd.uid src/ui/components/result_banner/result_banner.gd src/ui/components/damage_counter/damage_counter.gd src/ui/components/stock_icons/stock_icons.gd src/ui/components/touch_button/touch_button.gd src/debug/config_panel.gd tests/unit/test_ui_motion.gd tests/unit/test_ui_motion.gd.uid
git commit -m "feat: apply motion tokens to every UI transition" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```
(main 스모크 테스트 대기를 늘렸다면 `tests/unit/test_main_smoke.gd`도 add)

---

### Task 15: DS 갤러리 — VFX·SFX·캐릭터 프리뷰 (DS-GOV-02)

**Files:**
- Modify: `src/debug/ds_gallery.gd`
- Test: `tests/unit/test_gallery.gd` (신규)

**Interfaces:**
- Consumes: T9·T10 VFX 노드, T11 `SfxRecipes`, T12 `SfxDirector`, T13 `MusicDirector`, T5 `CharacterModel`
- Produces:
  - 갤러리 섹션 "Characters · DS-VIS-02"(4종 + 룩 A/B/C 버튼), "VFX · DS-VFX-01~06"(버튼마다 SubViewport에서 재생: hit puff 소·대, dust, trail, ringout splash, star burst, respawn, charge glow), "SFX · DS-SFX-01"(레시피마다 재생 버튼), "BGM · DS-SFX-02"(대전/인텐스 토글/메뉴 버튼)
  - `--vfx-only`, `--audio-only`, `--characters-only` 인자 (캡처용, 기존 `--items-only`와 같은 방식)
  - `func DsGallery.sfx_buttons() -> int` 같은 확인용 함수 대신, 테스트는 버튼 노드 이름 규칙 `"sfx_<name>"`, `"vfx_<kind>"`로 찾는다
- 근거: `[DS-GOV-02]` `[DS-VFX-01~06]` `[DS-SFX-01]` `[DS-SFX-02]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_gallery.gd`:
```gdscript
extends GutTest
## Every sound and effect is previewable in the DS gallery (design.md DS-GOV-02).

const VFX_KINDS: Array[String] = ["hit_small", "hit_large", "dust", "trail", "splash", "star", "respawn", "charge"]


func test_gallery_lists_every_sfx_and_vfx() -> void:
	var g := (load("res://src/debug/ds_gallery.tscn") as PackedScene).instantiate()
	add_child_autofree(g)
	await wait_process_frames(2)
	for name: String in SfxRecipes.RECIPES:
		assert_not_null(g.find_child("sfx_" + name, true, false), "sfx button for %s" % name)
	for kind: String in VFX_KINDS:
		assert_not_null(g.find_child("vfx_" + kind, true, false), "vfx button for %s" % kind)
	for name: String in ["bgm_battle", "bgm_intense", "bgm_menu"]:
		assert_not_null(g.find_child(name, true, false), name)


func test_pressing_a_vfx_button_spawns_the_effect() -> void:
	var g := (load("res://src/debug/ds_gallery.tscn") as PackedScene).instantiate()
	add_child_autofree(g)
	await wait_process_frames(2)
	var stage := g.find_child("vfx_stage", true, false) as Node3D
	var before := stage.get_child_count()
	(g.find_child("vfx_dust", true, false) as Button).pressed.emit()
	assert_gt(stage.get_child_count(), before, "the dust puff appears on the preview stage")
```
Run: `./scripts/test.sh -gselect=test_gallery` → FAIL

- [ ] **Step 2: 갤러리 섹션 추가**

`src/debug/ds_gallery.gd`:
- 인자 상수 `VFX_ONLY_ARG := "--vfx-only"`, `AUDIO_ONLY_ARG := "--audio-only"`, `CHARACTERS_ONLY_ARG := "--characters-only"`; `_ready`에서 각 인자가 있으면 해당 섹션만 그리고 return (기존 `--items-only`와 같은 패턴). 인자가 없으면 기존 섹션 뒤에 세 섹션 모두.
- 필드 `var _sfx: SfxDirector`, `var _music: MusicDirector` — `_ready`에서 만들어 `setup(GameConfig.new())`.
- `_characters_preview() -> Control`: `_toon_preview`와 같은 SubViewport(`PREVIEW_SIZE`)에 `CharacterModel` 4개를 x = -3, -1, 1, 3에 두고 각자 `CharacterAnimator`로 IDLE 재생(매 프레임 `apply({"state": Fighter.State.IDLE, ...}, delta)`을 부를 수 있게 SubViewport 옆에 작은 Node를 두고 `_process`에서 진행), 아래에 룩 버튼 3개(`look_a`/`look_b`/`look_c`, `LookPreset.apply(n)`).
- `_vfx_preview() -> Control`: SubViewport 안에 바닥·환경·카메라 + 이름이 `"vfx_stage"`인 Node3D. 버튼 행: `vfx_hit_small`(HitSpark small), `vfx_hit_large`, `vfx_dust`(DustPuff intensity 1), `vfx_trail`(KnockbackTrail에 x를 따라 6개 샘플), `vfx_splash`(RingoutBurst splash), `vfx_star`(RingoutBurst star, DS.P2), `vfx_respawn`(RespawnBeam at y 4), `vfx_charge`(ChargeGlow set_charge(1)). 각 버튼 `name`은 위 문자열, 효과 노드는 `vfx_stage`의 자식으로 추가.
- `_audio_preview() -> Control`: `SfxRecipes.RECIPES`의 이름마다 `Button`(`name = "sfx_" + name`, text = name, pressed → `_sfx.play(name)`), 그리고 `bgm_battle`(→ `_music.play_battle()`), `bgm_intense`(→ 인텐스 토글: `_music.update_from`에 stocks 1짜리 가짜 뷰), `bgm_menu`(→ `_music.play_menu()`), `bgm_stop`.

- [ ] **Step 3: 테스트 + 캡처**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변).
Run (창 모드): `for a in characters vfx audio; do godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/debug/ds_gallery.tscn --out="$PWD/dev/active/phase-3/evidence/gallery-$a.png" --frames=60 --$a-only; done` — 세 장을 열어 확인하고 설명.

- [ ] **Step 4: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add src/debug/ds_gallery.gd tests/unit/test_gallery.gd tests/unit/test_gallery.gd.uid dev/active/phase-3/evidence/gallery-characters.png dev/active/phase-3/evidence/gallery-vfx.png dev/active/phase-3/evidence/gallery-audio.png
git commit -m "feat: preview characters, VFX, SFX and BGM in the DS gallery" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 16: iOS export + 빌드 스크립트 + 빌드 크기 검사

**Files:**
- Modify: `export_presets.cfg` (iOS 프리셋 추가)
- Create: `scripts/build_all.sh`, `scripts/check_build_size.sh`
- Modify: `.gitignore` (`build/` 하위 산출물 확인)

**Interfaces:**
- Produces:
  - export 프리셋 `"iOS"` (platform `iOS`, `export_path="build/ios/ForestBrawl.xcodeproj"`, 프로젝트만 export — 서명·아카이브 없음, 번들 ID `com.forestbrawl.game`, 가로 고정)
  - `scripts/build_all.sh` — Android(debug APK), iOS(Xcode 프로젝트), Web(release) export. 실패하면 non-zero
  - `scripts/check_build_size.sh` — `build/android/forest-brawl.apk` ≤ 150MB, `build/web/index.pck` + `build/web/index.wasm` ≤ 40MB, 초과 시 exit 1, 크기 표 출력
- 근거: `[PRD-PLT-01]` `[PRD-NFR-05]` · F11

- [ ] **Step 1: iOS 프리셋 추가**

`export_presets.cfg`에 `[preset.5]` / `[preset.5.options]`를 추가한다. 최소 옵션:
```
[preset.5]

name="iOS"
platform="iOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, addons/gut/*, dev/*, docs/*, scripts/*"
export_path="build/ios/ForestBrawl.xcodeproj"

[preset.5.options]

application/export_project_only=true
application/bundle_identifier="com.forestbrawl.game"
application/short_version="0.3"
application/version="0.3"
application/min_ios_version="15.0"
application/targeted_device_family=2
orientation/portrait=false
orientation/portrait_upside_down=false
orientation/landscape_left=true
orientation/landscape_right=true
```
(Godot 4.7.2의 iOS 옵션 이름이 다르면 에디터 기본값을 따른다: `godot --headless --path . --export-debug "iOS" build/ios/ForestBrawl.xcodeproj`를 한 번 돌려 경고로 나오는 옵션을 맞추고, 실제 적용한 옵션을 보고서에 적는다. 기존 Android·Web 프리셋의 `exclude_filter`가 tests·gut을 빼지 않으면 같은 필터를 추가해 빌드 크기를 줄인다.)

- [ ] **Step 2: 빌드 스크립트**

`scripts/build_all.sh`:
```bash
#!/usr/bin/env bash
# Exports the mobile and web builds (PRD-PLT-01/03). iOS is an unsigned Xcode project (context F11).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
mkdir -p build/android build/ios build/web
"$GODOT" --headless --path . --import >/dev/null
"$GODOT" --headless --path . --export-debug "Android" build/android/forest-brawl.apk
"$GODOT" --headless --path . --export-debug "iOS" build/ios/ForestBrawl.xcodeproj
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
echo "build_all: android, ios, web exported"
```
`scripts/check_build_size.sh`:
```bash
#!/usr/bin/env bash
# Build size budget (PRD-NFR-05): mobile <= 150 MB, web initial load (pck + wasm) <= 40 MB.
set -euo pipefail
cd "$(dirname "$0")/.."
MB=$((1024 * 1024))
apk=$(stat -f%z build/android/forest-brawl.apk)
web=$(( $(stat -f%z build/web/index.pck) + $(stat -f%z build/web/index.wasm) ))
printf "android apk: %d MB (budget 150)\nweb pck+wasm: %d MB (budget 40)\n" $((apk / MB)) $((web / MB))
fail=0
[ "$apk" -le $((150 * MB)) ] || { echo "FAIL: apk over budget"; fail=1; }
[ "$web" -le $((40 * MB)) ] || { echo "FAIL: web over budget"; fail=1; }
[ -d build/ios/ForestBrawl.xcodeproj ] || [ -e build/ios/ForestBrawl.xcodeproj ] || { echo "FAIL: iOS project missing"; fail=1; }
exit $fail
```
`chmod +x scripts/build_all.sh scripts/check_build_size.sh`. `.gitignore`에 `build/`가 없으면 추가(이미 산출물은 추적하지 않는지 `git status`로 확인).

- [ ] **Step 3: 실행**

Run: `./scripts/build_all.sh && ./scripts/check_build_size.sh`
Expected: 세 export 성공, 크기 표 출력, exit 0. 출력 전체를 보고서에 붙인다. iOS export가 Xcode 부재·템플릿 문제로 실패하면 에러를 그대로 적고 DONE_WITH_CONCERNS로 보고(Android·Web은 계속).

- [ ] **Step 4: 검사 + 커밋**

Run: `./scripts/check-all.sh`
```bash
git add export_presets.cfg scripts/build_all.sh scripts/check_build_size.sh .gitignore
git commit -m "build: add the iOS export and a mobile/web build size check" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 17: 성능 측정(4인 봇전, 품질 단계별) + 웹 툰 룩 캡처

**Files:**
- Modify: `src/main/main.gd` (`_player_count()` 가상 함수, 봇 목록)
- Create: `src/debug/perf_match.gd`, `src/debug/perf_match.tscn`, `scripts/measure_fps.gd`, `scripts/capture_web.sh`, `dev/active/phase-3/evidence/performance.md`
- Test: `tests/unit/test_main_smoke.gd`

**Interfaces:**
- Produces:
  - `main.gd`: `func _player_count() -> int` (기본 `PLAYER_COUNT`), `_ready`·`_start_match`·HUD가 이 값을 사용, 봇은 `_bots: Array[BotController]`(로컬 플레이어 제외 전원)
  - `perf_match.tscn` — main 상속, 4인 전원 봇, 로컬 입력 없음
  - `scripts/measure_fps.gd` — perf_match를 띄우고 `quality_level` 0/1/2마다 120프레임 워밍업 후 600프레임의 프레임 시간(µs) 평균·p95·최대와 평균 FPS를 출력하고 `dev/active/phase-3/evidence/performance.md` 표에 기록 (vsync 끔)
  - `scripts/capture_web.sh` — `build/web`을 `python3 -m http.server 8060`로 띄우고 헤드리스 Chrome으로 `dev/active/phase-3/evidence/web-toon.png`를 찍은 뒤 서버 종료
- 근거: `[PRD-NFR-01]` `[PRD-PLT-05]` · PHASES 완료 기준(4인 봇전 프로파일, 웹 툰 룩)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/unit/test_main_smoke.gd` 끝에 추가:
```gdscript


func test_perf_match_runs_four_bots() -> void:
	var scene: Node = (load("res://src/debug/perf_match.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_seconds(0.5)
	var w: World = scene.call("get_world")
	assert_eq(w.fighters.size(), 4)
	var moved := 0
	for i: int in 4:
		if w.fighters[i].pos != Rules.spawn_point(i, 4, w.config):
			moved += 1
	assert_eq(moved, 4, "all four fighters are bots")
```
Run: `./scripts/test.sh -gselect=test_main_smoke` → FAIL (씬 없음)

- [ ] **Step 2: main 가상화 + perf 씬**

`src/main/main.gd`:
- `func _player_count() -> int: return PLAYER_COUNT` 추가, `_ready`의 `for i: int in PLAYER_COUNT`, `_start_match`의 `World.new(..., PLAYER_COUNT)`·`_hud.setup(PLAYER_COUNT, ...)`을 `_player_count()`로.
- `var _bot: BotController`를 `var _bots: Array[BotController] = []`로 바꾸고 `_start_match`에서 `LOCAL_PLAYER`를 뺀 모든 id로 채운다. `_gather_inputs`:
```gdscript
func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = [_local_input.sample()]
	for b: BotController in _bots:
		inputs.append(b.sample(_curr_state))
	return inputs
```
- `item_race_demo.gd`가 `_bot`을 쓰면 `_bots[0]`으로 바꾼다(데모 동작 동일 — 보고서에 기록).
`src/debug/perf_match.gd`:
```gdscript
extends "res://src/main/main.gd"
## Performance scene (PRD-NFR-01, Phase 3): a four-fighter match where every fighter, the local
## slot included, is a step-2 bot. Used by scripts/measure_fps.gd.

const PERF_PLAYERS := 4

var _local_bot: BotController


func _player_count() -> int:
	return PERF_PLAYERS


func _start_match() -> void:
	super._start_match()
	_local_bot = BotController.new(LOCAL_PLAYER, _config)


func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = [_local_bot.sample(_curr_state)]
	for b: BotController in _bots:
		inputs.append(b.sample(_curr_state))
	return inputs
```
`src/debug/perf_match.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/debug/perf_match.gd" id="1"]

[node name="PerfMatch" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 측정 스크립트**

`scripts/measure_fps.gd`:
```gdscript
extends SceneTree
## Frame time of the four-bot match per quality level (PRD-NFR-01). Windowed run, vsync off.
## Run: godot --path . -s res://scripts/measure_fps.gd
## Writes dev/active/phase-3/evidence/performance.md.

const WARMUP := 120
const SAMPLES := 600
const OUT := "res://dev/active/phase-3/evidence/performance.md"

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
	_frame = 0
	_times.clear()
	_last_us = Time.get_ticks_usec()


func _tick() -> void:
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
	_rows.append("| %s | %.0f | %d | %d | %.1f |" % [["LOW", "MEDIUM", "HIGH"][_level], avg, p95, _times[-1], 1000000.0 / avg])
	if _level < 2:
		_set_level(_level + 1)
		return
	var text := "# Phase 3 성능 (데스크톱, 4인 봇전, vsync 끔)\n\n| 품질 | 평균 µs | p95 µs | 최대 µs | 평균 FPS |\n|---|---|---|---|---|\n" + "\n".join(_rows) + "\n\n- 기기: %s\n- LOW는 max_fps 30 제한이 걸린다 (프레임 시간은 제한 포함)\n- 모바일 실기기 측정: 대기\n" % OS.get_model_name()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	quit(0)
```
Run (창 모드): `godot --path . -s res://scripts/measure_fps.gd` → performance.md 생성. 보고서에 표를 붙인다.

- [ ] **Step 4: 웹 캡처 스크립트**

`scripts/capture_web.sh`:
```bash
#!/usr/bin/env bash
# Captures the web (Compatibility) build with headless Chrome (PRD-PLT-05 toon look check).
# Needs build/web from scripts/build_all.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-dev/active/phase-3/evidence/web-toon.png}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
python3 -m http.server 8060 -d build/web >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER' EXIT
sleep 1
"$CHROME" --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1280,720 \
  --virtual-time-budget=20000 --screenshot="$PWD/$OUT" http://localhost:8060/index.html
echo "capture_web: $OUT"
```
`chmod +x scripts/capture_web.sh`. Run: `./scripts/capture_web.sh` (T16의 `build/web` 필요). 같은 크기로 데스크톱도 찍는다: `godot --path . -s res://scripts/capture_evidence.gd -- --scene=res://src/main/main.tscn --out="$PWD/dev/active/phase-3/evidence/desktop-toon.png" --frames=120`. 두 장을 열어 캐릭터·잔디 색·그림자 띠가 같은 톤인지 비교해 보고서에 적는다(웹이 로딩 화면만 찍히면 `--virtual-time-budget`을 늘린다).

- [ ] **Step 5: 테스트 + 검사 + 커밋**

Run: `./scripts/test.sh` → 전부 PASS (해시 불변). Run: `./scripts/check-all.sh`
```bash
git add src/main/main.gd src/debug/perf_match.gd src/debug/perf_match.gd.uid src/debug/perf_match.tscn src/debug/item_race_demo.gd scripts/measure_fps.gd scripts/measure_fps.gd.uid scripts/capture_web.sh tests/unit/test_main_smoke.gd dev/active/phase-3/evidence/performance.md dev/active/phase-3/evidence/web-toon.png dev/active/phase-3/evidence/desktop-toon.png
git commit -m "feat: measure four-bot frame time per quality level and capture the web toon look" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

### Task 18: Phase 3 마감 (증거·문서)

**Files:**
- Modify: `docs/PHASES.md` (Phase 3 체크), `docs/design.md` (§12 상태, 버전), `docs/PRD.md` (필요 시 §4.5·§7 수치), `dev/active/phase-3/phase-3-context.md`, `dev/active/phase-3/phase-3-tasks.md`
- (`git mv dev/active/phase-3 dev/done/phase-3`는 하지 않는다 — 컨트롤러가 최종 리뷰 뒤에)

- [ ] **Step 1: 최종 검증**

Run: `./scripts/check-all.sh` → `ALL CHECKS PASSED`. `tests/replay/test_replay.gd`의 `BEHAVIOR_HASH`가 T1 값 그대로인지 `git log -p -- tests/replay/test_replay.gd`로 확인해 보고서에 적는다 (PHASES 완료 기준 "캡슐 버전과 같은 리플레이 해시").

- [ ] **Step 2: 문서 갱신**

- `docs/PHASES.md` Phase 3: 구현·리뷰된 ⚙️·🎨 항목 체크. 🖼 캐릭터 룩은 T7 결과대로(대기면 ` — 🖼 대기 (T7)`). 완료 기준: "같은 리플레이 해시" ✅(`BEHAVIOR_HASH` 불변, T1 커밋 해시 인용); "중급 모바일 60fps" → ` — 실기기 확인 대기` (데스크톱 표: `evidence/performance.md`); "빌드 크기" ✅/❌ (`check_build_size.sh` 출력 인용); "웹 툰 룩" ✅ + `web-toon.png`·`desktop-toon.png`
- `docs/design.md`: 버전 0.6. §12: GD-ANIM-01 ✅, GD-FEEL-04 ✅, DS-VFX-03~06 ✅, DS-SFX-01 ✅, DS-SFX-02 🟨(임시곡, 본곡 대기), DS-TOK-05 ✅(적용), DS-VIS-01·02는 T7 결과대로. DS-VIS-01 표에 `ds_rim_strength`·`ds_char_saturation`·`ds_outline_*` 글로벌 유니폼 추가
- `docs/PRD.md` §7: 측정값이 기준과 다르면 비고만 추가 (기준 자체는 바꾸지 않음)
- `dev/active/phase-3/phase-3-context.md`: 상태 "구현 완료, 최종 리뷰 대기", F1~F11 최종 상태, 측정값(성능 표, 빌드 크기, 웹 비교), 알려진 차이, "Phase 4로 넘기는 항목"(F2의 sim 항목 3개, 실기기, 본곡, 🖼 대기 항목)
- `dev/active/phase-3/phase-3-tasks.md`: 상태 갱신

- [ ] **Step 3: 커밋**

```bash
git add docs/PHASES.md docs/design.md docs/PRD.md dev/active/phase-3/phase-3-context.md dev/active/phase-3/phase-3-tasks.md
git commit -m "docs: close phase 3 with evidence and traceability" -m "Co-Authored-By: Claude <모델> <noreply@anthropic.com>"
```

---

## Self-Review (계획 작성자 점검 결과)

**PHASES Phase 3 커버리지:**

| PHASES 항목 | 태스크 |
|---|---|
| glTF 치비 캐릭터 교체 (KayKit CC0), ASSETS.md `[PRD-FX-01]` `[PRD-NFR-07]` | T2, T5 |
| AnimationTree 상태 머신 (idle~grab), sim 상태를 읽기만 `[GD-ANIM-01]` | T3, T6 |
| 판정 캡슐 유지 `[PRD-ARCH-01]` | T5 (모델은 보이기만), T1 가드 |
| 품질 설정: 저사양 30fps, 파티클·블룸·그림자 단계 `[PRD-NFR-01]` | T8 |
| iOS export `[PRD-PLT-01]` | T16 |
| 🖼 캐릭터 룩 시안 (림·채도·외곽선) `[DS-VIS-01]` `[DS-VIS-02]` | T4 (프리셋), T6 (캡처), T7 (게이트) |
| 소프트 툰 최종화, 글로벌 유니폼 토큰화 `[PRD-FX-03]` | T4 |
| VFX 라이브러리: 히트 퍼프(기존)·착지 먼지·넉백 궤적·링아웃·리스폰·차지 광 `[DS-VFX-01~06]` | T9, T10 |
| 넉백 궤적 강도 = 넉백 크기 `[GD-FEEL-04]` | T9 (속도 기반 강도 — 넉백 크기에 비례하는 발사 속도) |
| SFX 세트 `[DS-SFX-01]` | T11, T12 |
| BGM 대전 루프 + 인텐스 레이어 + 메뉴 변주 `[DS-SFX-02]` | T13 (임시곡, 본곡은 사용자) |
| 모션 토큰 적용 `[DS-TOK-05]` | T14 |
| VFX·SFX 프리뷰 갤러리 `[DS-GOV-02]` | T15 |
| 테스트: 리플레이 해시 Phase 2와 동일 | T1 (`BEHAVIOR_HASH`), 모든 태스크의 "해시 불변" 단계 |
| 완료 기준 4개 | T1·T18 (해시), T17 (성능·웹), T16 (크기) |

**이름 일관성:** `GameConfig.SIM_GROUPS/NON_SIM_GROUPS/group_names/look_preset/quality_level`, `CharacterCatalog.CHARACTERS/for_player`, `AnimMap.Anim/anim_for/anim_name/is_timed`, `AnimClips.CANDIDATES/resolve/first_present/loops`, `LookPreset.Look/PRESETS/values_for/apply`, `ToonMaterials.character`, `CharacterModel.setup/animation_player/visible_height/foot_y/FACING_OFFSET`, `CharacterAnimator.setup/apply/current_anim/clip_for/play_position/state_machine/timed_seconds/XFADE_SECONDS`, `FighterView.model/animate/animator/set_blob_shadow/blob_visible`, `Quality.Level/resolve/platform/settings/particle_scale`, `EnvironmentRig.apply_quality/environment/sun`, `BlobShadow.LIFT/follow`, `ViewEvents.detect/trail_intensity/dust_intensity`, `DustPuff.play/LIFETIME`, `KnockbackTrail.add_sample/SAMPLE_LIFETIME`, `RingoutBurst.play/LIFETIME`, `RespawnBeam.play/LIFETIME`, `ChargeGlow.set_charge/base_scale`, `CameraRig.punch/punch_offset`, `DecorView.is_over_lake`, `ItemLayer.BOX_HEIGHT_TOLERANCE`, `SfxSynth.render/peak/SAMPLE_RATE/DEFAULTS`, `WavWriter.to_stream`, `SfxRecipes.RECIPES/path`, `AudioBuses.ensure/SFX/MUSIC/UI`, `SfxDirector.sound_for/on_events/play/play_ui/voices/VOICES`, `MusicSequencer.SONGS/render/length_samples/midi_to_hz`, `MusicDirector.path_for/wants_intense/setup/play_battle/play_menu/stop/update_from/intense_target_db/is_intense/SILENT_DB/NAMES`, `UiMotion.Token/spec/pop_in/fade_out/bump/release`, `main._player_count/_bots`.

**알려진 판단 지점 (멈추고 보고):** T1 행동 해시 변화, T2 다운로드 승인·LFS 포인터, T3 후보 이름이 실제 클립과 안 맞음, T6 AnimationNodeAnimation API 이름, T13 static var 초기화, T16 iOS export 실패.
