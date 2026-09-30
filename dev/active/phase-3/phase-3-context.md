# Phase 3 — Context

**Last Updated:** 2026-09-30
**상태:** 구현 완료, 최종 리뷰 대기 (🖼 T7 대기, 웹 툰 룩 최종 수정 단계에서 조정 중)
**계획:** [`phase-3-plan.md`](./phase-3-plan.md) · **체크리스트:** [`phase-3-tasks.md`](./phase-3-tasks.md)
**이전 Phase:** [`dev/done/phase-2/phase-2-context.md`](../../done/phase-2/phase-2-context.md)

---

## 목표

캡슐 버전과 조작감이 완전히 같으면서 보기에 재밌게 만든다 (PHASES.md Phase 3). 치비 캐릭터·애니메이션·소프트 툰 최종화·VFX·SFX·BGM 재생 시스템·품질 단계·iOS 빌드를 넣고, 3D 비주얼 시스템과 모바일 성능 예산을 확정한다.

## 사용자 결정 (2026-09-29)

| 질문 | 선택 |
|---|---|
| 캐릭터 모델 | KayKit Character Pack: Adventurers 1.0 (CC0) — 다운로드는 T2 실행 직전 한 번 더 승인 |
| SFX | 코드로 합성해 .wav로 굽기 (100% 오리지널) |
| BGM | 재생 시스템 + 코드 합성 임시곡, 본곡은 사용자 제작 후 같은 파일명으로 교체 |
| iOS·모바일 성능 | 빌드(Xcode 프로젝트 export)까지만, 실기기 60fps 확인은 대기. 데스크톱에서 품질 단계별 측정 |

## 결정 사항

### 사용자 확인 대기 (구조에 영향)

| # | 결정 | 이유 | 대안 |
|---|---|---|---|
| F1 | **config 지문을 sim 그룹으로 한정**하고(Phase 2 이월), 리플레이에 **행동 해시(BEHAVIOR_HASH)**를 추가한다. 행동 해시 = 매 틱 스냅샷에서 `config_fp`를 뺀 값의 해시. T1에서 기존 코드로 값을 먼저 고정한 뒤 지문 범위를 바꾸므로, 행동 해시가 그대로임이 "Phase 2와 같은 sim"의 증명이 된다. GOLDEN_HASH는 T1에서 한 번만 바뀌고 그 뒤로는 고정 | Phase 3에서 렌더·오디오·품질 수치를 GameConfig에 더할 때마다 골든이 깨지면 "리플레이 해시가 Phase 2와 동일"(PHASES 테스트)을 증명할 수 없음 | 렌더 수치를 별도 Resource로 분리 (디버그 패널 두 개, 구조 복잡) |
| F2 | **Phase 3는 sim 동작을 바꾸지 않는다.** Phase 2에서 넘어온 sim 항목(히트스톱이 누름을 삼킴, 방망이 밸런스, 같은 틱 상호 타격 편향)은 Phase 4로 다시 넘긴다 | PHASES 완료 기준 "캡슐 버전과 같은 리플레이 해시 → 조작감 동일" | Phase 3에서 고치고 기준을 "의도된 변경만"으로 완화 |
| F3 | **캐릭터 4종 = KayKit Knight·Barbarian·Mage·Rogue** (glb만, 약 14.5MB) → P1~P4. 무기·방패 같은 부속 메시는 숨긴다(맨손 난투, 아이템은 우리 손 메시로 표시). 플레이어 식별은 기존 발밑 링 + P 라벨 유지 | 4인 봇전(PHASES 완료 기준)에 4종 필요. 스타일(권투·무기·원거리) 구분은 Phase 5 | 한 모델에 색만 바꿔 4명 |
| F4 | **애니메이션 클립은 후보 이름 목록으로 런타임 해석**한다 (`AnimClips`). 예: RUN = ["Running_A", "Running_B", "Walking_A"]. 첫 번째로 존재하는 클립을 쓰고, 없으면 IDLE로 대체. T2가 실제 클립 목록을 `assets/characters/kaykit/animations.txt`로 뽑아 후보를 맞춘다 | 계획 시점에 팩 내부 이름을 확정할 수 없음 (다운로드 전). 이름이 조금 달라도 깨지지 않음 | 이름 하드코딩 |
| F5 | **AnimationTree 상태 머신은 코드로 생성**하고 수동 진행(`advance`)한다. sim 상태 → 애니 상태 1:1(GD-ANIM-01). 공격·강공격·잡기 클립은 `use_custom_timeline` + `stretch_time_scale`로 **sim 공격 길이에 맞춰 늘이고**, 뷰의 `hitstop_ticks > 0`이면 진행을 멈춘다 | 애니가 sim 타이밍을 바꾸지 않음. 히트스톱 정지가 화면에서도 보임 | AnimationPlayer 크로스페이드 |
| F6 | **소프트 툰 v2**: 텍스처 지원 + 글로벌 유니폼 토큰(`ds_rim_strength`, `ds_char_saturation`, `ds_outline_width`, `ds_outline_color`) + 캐릭터 전용 inverted-hull 외곽선(next_pass). 🖼 게이트용 룩 프리셋 3안: **A** 림 0.35·외곽선 없음(현 초안) / **B** 림 0.5·채도 +15% / **C** 림 0.25·얇은 `canopy_deep` 외곽선 | design.md DS-VIS-01 "외곽선 정책"·PHASES 🖼 게이트 | — |
| F7 | **품질 3단계** (`quality_level` 0 LOW / 1 MEDIUM / 2 HIGH, GameConfig Quality 그룹, 지문 제외): LOW = 30fps·실시간 그림자 끔(발밑 블롭 그림자)·파티클 50%·블룸 끔, MEDIUM = 60fps·그림자 켬·파티클 100%·블룸 끔, HIGH = 60fps·그림자·블룸 켬. 기본값: 모바일 MEDIUM, 웹 LOW, 데스크톱 HIGH | PRD-NFR-01 "저사양 30fps 모드" | 자동 감지 |
| F8 | **VFX는 전부 렌더 쪽에서 뷰 차이로 감지**: 착지(on_ground false→true), 리스폰(spawn_id 증가), 넉백 궤적(보간 위치 속도 > `trail_speed_threshold`), 차지 광(state CHARGE). sim 이벤트 추가 없음(F2) | sim을 건드리지 않음 | sim에 이벤트 추가 (골든 변경) |
| F9 | **SFX 합성기**: sfxr류 파라미터(파형·주파수 스윕·엔벨로프·비브라토·노이즈) → 16bit mono 44.1kHz. `scripts/bake_sfx.gd`가 레시피대로 `assets/sfx/*.wav`를 굽는다(런타임 합성 없음). 레시피는 `SfxRecipes` 한 파일. 톤: 말랑·통통(DS-SFX-01) | 결정적·오리지널·조절 가능 | 런타임 합성 |
| F10 | **BGM 재생**: 대전 = `AudioStreamSynchronized`(기본 루프 + 인텐스 레이어, 같은 길이·템포) — 누군가 마지막 스톡이면 인텐스 레이어를 `motion_slow`로 페이드인. 메뉴 변주는 별도 스트림(Phase 4 메뉴에서 사용). 임시곡은 `scripts/bake_music.gd`의 작은 시퀀서(150 BPM, 8마디, 드럼·베이스·마림바)로 굽고, 본곡은 `assets/music/battle_base.wav`, `battle_intense.wav`, `menu.wav` 같은 이름(ogg도 허용)으로 교체 | DS-SFX-02, 사용자 결정 | — |
| F11 | **iOS**: export 프리셋 + Xcode 프로젝트 export까지(서명 없음). 빌드 크기 검사 스크립트가 Android APK ≤ 150MB, Web 초기 로딩(.pck+.wasm) ≤ 40MB를 확인 | 사용자 결정, PRD-NFR-05 | — |

### 확정 (Phase 3 범위)

- 판정 캡슐은 그대로 (모델은 보이기만) `[PRD-ARCH-01]`
- 모델 높이를 `fighter_height`에 맞춰 스케일, 발은 y=0
- 🖼 캐릭터 룩 게이트(T7)는 사용자 수행. 지연 시 A안으로 진행하고 대기 표시
- Phase 2에서 넘어온 🖼 4버튼(T13)·HUD 시안·Android 실기기·캐릭터 크기 결정은 T7 게이트 때 함께 받는다
- 떨어뜨린 아이템이 상자로 그려지는 문제는 렌더 쪽에서 고친다 (첫 관측이 낙하 높이 근처일 때만 상자, T10)
- 웹(Compatibility)에서 툰 룩 유지: 헤드리스 Chrome으로 웹 빌드 캡처 후 데스크톱과 비교 (T17)

## 핵심 파일 (계획 기준)

| 파일 | 역할 |
|---|---|
| `src/render/character/character_catalog.gd` | 캐릭터 4종 경로·숨길 부속 노드 (T2가 조사 결과로 작성) |
| `src/render/character/anim_map.gd` · `anim_clips.gd` | sim 뷰 → 애니 상태, 후보 클립 해석 |
| `src/render/character/character_model.gd` · `character_animator.gd` | glb 로드·툰 머티리얼·스케일, AnimationTree 상태 머신 |
| `src/render/shaders/soft_toon.gdshader` · `char_outline.gdshader` · `src/render/look_preset.gd` | 툰 v2, 외곽선, 룩 프리셋 |
| `src/render/quality.gd` | 품질 단계 → 렌더 설정 |
| `src/render/feel/view_events.gd` · `dust_puff.gd` · `knockback_trail.gd` · `ringout_burst.gd` · `respawn_beam.gd` · `charge_glow.gd` | 렌더 쪽 이벤트 감지와 VFX |
| `src/audio/sfx_synth.gd` · `sfx_recipes.gd` · `audio_buses.gd` · `sfx_director.gd` · `music_director.gd` · `music_sequencer.gd` | 합성·버스·효과음·BGM |
| `src/ui/ui_motion.gd` | 모션 토큰 트윈 헬퍼 |
| `scripts/bake_sfx.gd` · `bake_music.gd` · `list_animations.gd` · `build_all.sh` · `check_build_size.sh` · `measure_fps.gd` · `capture_web.sh` | 굽기·조사·빌드·측정 |

## 의존성

- Phase 2 산출물 전부
- KayKit Adventurers 1.0 (GitHub `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0`, CC0) — T2에서 다운로드 승인
- Godot 4.7.2 export templates (설치됨), Xcode(iOS export), Google Chrome(웹 캡처), ffmpeg(설치됨)

## 열린 이슈

1. **실기기**: Android·iOS 실기기 60fps 확인 대기 (데스크톱 품질 단계별 측정으로 대체 기록)
2. **본곡**: 사용자 제작 대기 (템포·악기 힌트도 대기)
3. **KayKit 클립 이름**: T2 조사 후 AnimClips 후보 목록 확정
4. **Phase 4로 넘길 sim 항목**: 히트스톱 누름 삼킴, 방망이 밸런스, 같은 틱 상호 타격 편향 (F2)

## 리스크

| 리스크 | 대응 |
|---|---|
| 캐릭터 모델이 모바일에서 무거움 | 품질 단계 + 프로파일, KayKit은 로우폴리(모바일 대상) |
| 애니 타이밍이 sim과 어긋나 보임 | 공격 클립을 sim 길이로 늘이기(F5), 히트스톱 정지 |
| 웹에서 툰 룩이 달라짐 | Compatibility 분기(Phase 0 방식) + 캡처 비교 |
| 합성 효과음이 싸구려처럼 들림 | 레시피를 수치로 조절, 갤러리에서 바로 들어보기(T15) |

---

## 최종 상태 (T18, 2026-09-30)

### F1~F11 결과

| # | 결과 |
|---|---|
| F1 | ✅ `BEHAVIOR_HASH` 1822125224 (61bd3ba에서 고정, Phase 3 내내 불변). `GOLDEN_HASH` 2953754395 (cf80ce7에서 한 번만 변경) |
| F2 | ✅ sim 무변경. 3개 항목은 Phase 4로 이월 |
| F3 | ✅ KayKit Knight·Barbarian·Mage·Rogue, 캐릭터당 클립 76개 |
| F4 | ✅ 후보 이름 해석 (`AnimClips`) |
| F5 | ✅ AnimationTree 상태 머신, sim 길이에 맞춘 늘이기, 히트스톱 정지 |
| F6 | 🟨 툰 v2·글로벌 유니폼·외곽선·프리셋 3안 구현. 🖼 게이트(T7) 미수행, `look_preset` 0 (A) 유지 |
| F7 | ✅ 품질 3단계 |
| F8 | ✅ 렌더 쪽 뷰 이벤트 감지 (sim 이벤트 추가 없음) |
| F9 | ✅ SFX 합성·굽기 |
| F10 | 🟨 BGM 재생 시스템 완료, 임시곡 (본곡 대기) |
| F11 | ✅ 서명 없는 Xcode 프로젝트 export, Android APK, 빌드 크기 검사 |

### 측정값

- 테스트: 388개 (387 통과, 1 보류: `test_apply_sets_global_uniforms`, 헤드리스 렌더러는 글로벌 셰이더 파라미터를 읽지 못함). `check-all.sh` ALL CHECKS PASSED
- 성능 (데스크톱 Mac14,7, 4인 봇전, vsync 끔, `evidence/performance.md`): 상한 해제(Engine.max_fps 0) 측정: LOW 평균 6.9ms/144.9fps (p95 7.3ms, 출시 상한 30), MEDIUM 6.9ms/144.9fps (p95 7.2ms, 상한 60), HIGH 6.9ms/144.9fps (p95 7.2ms, 상한 60). 세 단계가 같은 값으로 수렴하므로 렌더 비용이 창/디스플레이 한계보다 작다는 뜻이며, 60fps 상한(16.7ms) 대비 2배 이상 여유
- 빌드 크기 (`check_build_size.sh`): Android APK 36MB (예산 150). 웹 pck+wasm 원본 47MB, gzip -9 18MB (예산 40). 웹 예산은 압축 전송 크기로 측정한다 (컨트롤러 판정)
- 웹 비교: `evidence/web-toon.png` vs `evidence/desktop-toon.png`. 웹이 데스크톱보다 어둡고 올리브 톤이라 "웹 툰 룩 유지"는 미체크. 최종 수정 단계에서 재캡처 후 갱신

### 알려진 차이

- iOS: 서명 없는 Xcode 프로젝트만 export. 팀 ID는 자리표시 `0000000000`, 앱 아이콘은 자리표시 `assets/app_icon.svg`
- BGM은 임시곡
- 데스크톱 측정은 상한을 해제했지만 세 단계가 6.9ms 근처로 수렴해 단계 간 비용 차이는 분리되지 않음 (창/디스플레이 한계)
- 🖼 캐릭터 룩 T7 미수행: 근접 캡처 `evidence/look-closeup-{0,1,2}.png`

### Phase 4로 넘기는 항목

- sim (F2): 히트스톱이 누름을 삼킴, 방망이 밸런스, 같은 틱 상호 타격 편향
- 실기기: Android·iOS 60fps, 터치 확인
- 본곡 BGM (같은 파일명으로 교체)
- 🖼 대기: 캐릭터 룩(T7), 4버튼 배치, HUD, 캐릭터 크기·`cam_margin`
- 웹: 원본 크기가 문제면 커스텀 템플릿으로 줄이기
