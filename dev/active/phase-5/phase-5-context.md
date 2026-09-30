# Phase 5 — Context

**Last Updated:** 2026-10-01 03:00 KST (feat/p5-charselect: 캐릭터 선택·P1~P4 식별·프롬프트·캐릭터 sim 연결)
**상태:** 대기 (Phase 4 · 앱 셸 이후)
**계획:** [`phase-5-plan.md`](./phase-5-plan.md) (통합 계획의 "Phase 5" 절) · **체크리스트:** [`phase-5-tasks.md`](./phase-5-tasks.md)

## 목표
스타일마다 이기는 방법이 다르다 + 필살기 + 로컬 2인.

## 사용자 결정 (2026-09-30, 계획 승인으로 확정)
- 캐릭터 4 = 모델 + 스타일 + 고유 필살기: Barbarian=권투(대지 강타), Rogue=권투(돌진 연타), Knight=무기(회전 베기), Mage=원거리(거대 화염구)
- 필살기: 때리거나 맞으면 차는 게이지, 가득 차면 X+C 동시 입력 1회. sim 결정적, 컷인(완전 확대)은 렌더 전용
- P2 키: WASD 이동 · Q 점프 · F 약 · G 강 · H 가드 · J 잡기 + 게임패드 자동 할당

## 사용자 요청 (2026-09-30)
- 온보딩 필요 → T11. 조작키 바(키 표시·누르면 색, 숨기기 가능)는 Phase 4에서 먼저 구현 중이고 튜토리얼이 이 바를 재사용해 "지금 누를 키"를 강조한다
- 트래킹 용량 최적화(타임라인 압축)는 유저가 적어 보류. 입력 로그·행동 피처는 진행

## Phase 5 sim 구현 결정 (2026-09-30, `feat/phase5-sim`)
- 캐릭터 id는 소문자 `barbarian`·`rogue`·`knight`·`mage`, `""` = Phase 4 클래식 파이터(필살기 없음). `World.new(config, seed, count, arena, characters)`, `CharacterData.resolve`는 렌더 이름("Knight")도 받는다
- 스타일(`src/sim/style/`)은 클래식 공격표를 배율·틱 가감으로 재가공(권투/무기) 또는 투사체로 교체(원거리). `StyleBook`이 틱마다 이동 수치를 만들고 공격표는 첫 사용 때만 만든다(4봇 틱 비용)
- 필살기(`src/sim/specials/`, 파일 1개씩): 게이지 가득 + 강+가드 동시 보유 → 1회. IDLE/MOVE/AIR/GUARD/CHARGE에서 시작, 이동 입력 방향을 조준, 시작 시 `special_invuln_ticks` 무적(선딜 전체를 덮음). 맞으면 끊긴다. 게이지는 링아웃 후에도 유지, 자기 필살기 적중으로는 안 찬다
- 투사체는 `World.projectiles`(스냅샷 v6). 발사·필살기 스폰·돌진 타격 창은 그 틱에 전진한(hitstop 아님) 파이터만 처리해 중복이 없다
- 클래식 동작 불변 증명: `tests/replay/test_classic_compat.gd`(v5 모양으로 되돌린 해시 = Phase 4 BEHAVIOR_HASH)
- 봇: 스타일 사거리(리치 배율), 원거리는 거리 유지→조준→사격, 게이지 가득 + 필살기 사거리 + 지상·같은 높이면 발동. 공격은 facing 방향으로 나가므로 조준 전엔 한 틱 돌아선다(전 봇 공통 버그 수정). 캐릭터 봇은 id 사거리 엇갈림을 쓰지 않는다(미러 매치 슬롯 편향 원인, 필살기가 무한 교환을 끊음)
- 필살기 타격은 2-pass: `SpecialRunner.contacts`가 근접 전투 전(틱 시작 상태) 접촉을 모으고 `SpecialRunner.apply`가 `Combat.resolve` 뒤에 적용. 같은 틱 상호 필살기·근접 교환이 id 순서와 무관하게 모두 들어간다(`test_mirrored_specials_both_land_whatever_the_ids`). 이 변경으로 rogue 리플레이 해시 갱신
- 봇 아이템 경합 수정: 두 봇이 같은 아이템 앞에서 잡기를 누르면 낮은 id가 줍고 다른 쪽 입력은 잡기 공격이 되어 슬롯 0이 잡혀 던져졌다(슬롯 편향, rogue 슬롯0 vs barbarian 16%). 상대도 줍기 거리 안이면 줍지 않고 싸운다(`BotViewQuery.contested`, `test_does_not_press_grab_for_an_item_the_foe_can_also_reach`)
- 밸런스 튜닝(2026-09-30): Knight vs Mage가 양 슬롯 약 25%라 `weapon_knockback_taken` 0.9→0.8, 그 대가로 Knight 공격 `weapon_knockback_mul` 1.25→1.15, Barbarian 우세 완화 `slam_base_knockback` 7→6. 설정 fingerprint 변경으로 GOLDEN_HASH·ARENA_HASHES·CHARACTER_HASHES 갱신(BEHAVIOR_HASH·classic compat 불변)
- 밸런스: `scripts/balance_sim.gd` 결과 `evidence/balance.csv` (16 순서쌍 × 100판, 전부 35~67%)

## T4 컷인 · T10 필살기 트래킹 결정 (2026-09-30, `feat/p5-cutin`)
- 컷인은 렌더 전용: `SpecialCutIn`(타이밍 모델, `src/render/feel/`) → `SpecialCutInDirector`(MatchPresentation 소유) → `CameraRig.set_focus(점, 가중치)` + `SpecialCutInBanner`(`src/ui/`, CanvasLayer 3). sim·틱 속도·리플레이 해시 불변(`test_director_..._leaves_the_sim_alone`)
- 타이밍은 DS 모션 토큰: 들어가기 `motion_base` · 유지 = 필살기 sim 길이 − 들어가기(`motion_slow`~`motion_calm`×2로 제한) · 복귀 `motion_slow`. 근접 샷 거리 7 m·피치 38°·가슴 높이 0.9 m는 `SpecialCutIn` 상수(GameConfig은 이미 200줄 초과라 늘리지 않음, Camera 그룹은 fingerprint 밖이라 나중에 옮겨도 해시 무관)
- 슬로우모션은 넣지 않았다: 렌더만 느리게 하면 sim 위치와 어긋나고, 틱을 늦추면 규칙 위반
- 두 번째 필살기는 현재 확대 가중치에서 이어 새 시전자로, 초점은 지수 추적(`FOCUS_FOLLOW` 10/s)으로 팬(팝 없음). 시전자 KO면 마지막 위치에서 즉시 복귀, 경기 재시작은 즉시 해제
- 띠는 화면 84% 높이(확대된 시전자 발밑 아래): 첫 캡처에서 30% 높이 띠가 시전자 머리·P 라벨을 가려 옮김(`test_banner_never_covers_the_zoomed_caster`). 확대 중 화면 밖 전투원의 충전 게이지는 `CameraRig.sees`로 숨김
- reduce motion: 설정 UI가 아직 없어 `SettingsStore` `[accessibility] reduce_motion` 키만 읽는다(카메라 고정, 띠 페이드만). `MatchPresentation.restart()`마다 다시 읽는다. 설정 화면 토글은 후속(tasks)
- 캐릭터 모션: `AnimMap.Anim`에 SLAM·RUSH·SPIN·CAST 추가(기존 인덱스 뒤에), SPECIAL 상태 → view `special` id별 클립. RUSH·SPIN은 반복
- 트래킹: `SpecialTelemetry`(CombatTelemetry 안) — `gauge_full`(match_time_s), `special_used`(ms_since_full, 없으면 -1 / target_damage = 가장 가까운 생존 상대 %), `special_hit`은 발동 1회당 1번(첫 적중으로 열고, 맞은 대상의 링아웃이 StockLoss 규칙으로 시전자에게 크레딧되면 즉시 caused_ringout=true, 아니면 180틱 창 경과·다음 필살기·경기 종료 때 false). 같은 틱은 sim이 타격 → 링아웃 순으로 내므로 사전 스캔 불필요(`test_sim_emits_a_tick_s_hits_before_its_ringouts`로 고정). ms_since_full은 KO로 보낸 틱을 뺀다. 이벤트 키가 빠지면 push_warning 후 무시. `target_slot` 필수 속성
- 슬롯 요약: `specials`(발동), `special_hits`(맞힌 대상 수) → `match_players.special_hits`는 새 마이그레이션 `0003_special_hits.sql`(사용자가 SQL Editor에서 0002 다음 실행해야 업로드 성공). `press_special` = 강+가드 동시 성립 횟수. `EventCatalog.SCHEMA_VERSION` 3 → 4
- 캐릭터 모델은 아직 슬롯 고정(`CharacterCatalog.for_player`)이라 캡처의 외형은 캐릭터와 다를 수 있다 — T9에서 해결

## T7 로컬 2인 결정 (2026-09-30, `feat/p5-local2p`)
- 액션 이름 `<prefix>_<name>`(p1/p2 × left·right·up·down·jump·light·heavy·guard·grab). P1처럼 `InputBindings`가 시작 때 코드로 등록한다(project.godot에는 넣지 않음 — 기존 P1 패턴, 키 재지정은 InputMap만 바꿈). `LocalInput.new("p2")`
- 필살기 동시 입력 = 그 플레이어의 강공격+가드가 같은 틱 InputFrame에 함께(sim `SpecialRunner.can_start`). **P1 X+C, P2 G+H, 패드 Y+RB**. 한 틱 전에 G를 탭하고 H를 누르면 HoldLatch 덕에 같은 틱으로 들어간다(P1과 동일한 관대함)
- 게임패드 규칙(`GamepadAssigner`): 패드는 연결 순서로 줄 선다(시작 때 이미 있는 패드는 장치 id 순). 패드 없는 플레이어 중 앞 순서(P1 먼저)가 아직 아무도 안 쓰는 가장 먼저 연결된 패드를 받는다. 끊기면 그 플레이어만 풀리고 기다리던 패드가 바로 넘겨받는다. 키보드 키는 항상 유지. 1인 봇 대전도 같은 규칙(첫 패드 → P1). 바인딩은 장치 id가 박힌 InputMap 이벤트(`PadBindings`)라 두 패드가 섞이지 않는다
- 매치: `MatchSetup.local_versus(n)` = 슬롯 0·1 로컬(P1·P2), 나머지 봇, 기본 캐릭터(`CharacterCatalog.for_player`). 타이틀 "로컬 2인" → 경기장 선택 → 대전(캐릭터 선택은 T9에서 `SELECT_STEPS`에 추가). 터치 전용 모바일은 "로컬 2인 · 데스크톱 전용"으로 꺼둔다. 두 사람이 한 화면이면 결과 배너는 "P2 승리!"처럼 승자를 부른다
- 트래킹: 스키마 변경 없음. 경기 시작 때 `main`이 `LocalPlayers.input_devices()`로 로컬 슬롯의 `input_device`를 채운다(패드 = `gamepad`, P1 기본 = 플랫폼, P2 = `keyboard`) → `match_ended.players[]`/`match_players.input_device`. `match_started.input_device`는 여전히 P1 슬롯
- 키 바: `KeyHintSource.caps(prefix)`, 필살기 키캡(`special`, 동시 입력)이 마지막. 게이지 가득(view `special` ≠ "" 이고 `gauge` ≥ 100)이면 `fire` 링. 로컬 2인은 P1 왼쪽·P2 오른쪽 바 + "P1/P2" 태그, 칩은 P2 바에 하나. 두 바가 안 들어가면 compact(간격·여백만 줄임). 폰 배율 1.6(812×375, 논리 폭 1458)에서 compact로 들어감(`evidence/key-hint-2p-phone.png`)
- 주의: `main.gd`는 아직 `World.new`에 캐릭터를 넘기지 않아 실제 경기에서는 모두 클래식 파이터(필살기 없음) → 게이지 링은 T9에서 캐릭터를 넘기면 보인다(증거 캡처는 파이터 게이지를 강제로 채움). 리플레이 검증기도 캐릭터를 모르므로 T9에서 함께 처리

## T9 캐릭터 선택 · T10 나머지 결정 (2026-10-01, `feat/p5-charselect`)
- 흐름: `App.SELECT_STEPS = [character, arena]` → 모드 → 캐릭터 → 경기장 → 대전. 경기장에서 뒤로 = 캐릭터 화면(모두 다시 고르는 중), 캐릭터에서 고르는 중 취소/뒤로/Esc = 타이틀
- `MatchSetup` 슬롯 `character`는 이제 CharacterData id(기본 `""` = 클래식). `assign_characters(human_picks)` = 사람 선택 + 봇은 `CharacterPicks.for_bots(seed, taken, n)`(사람이 안 고른 캐릭터에서 겹치지 않게, 시드 결정적). 두 사람은 같은 캐릭터 가능(미러)
- 규칙(`CharacterSelectModel`): 사람마다 커서(P1 카드 0, P2 카드 1에서 시작), 확정 = 잠금(준비), 준비 중 취소 = 잠금 해제, 고르는 중 취소 = P1만 화면 나가기(P2의 G/패드 B는 아무것도 안 함 — 실수로 P1 선택을 날리지 않게, 리뷰 반영). 뒤로 버튼·Esc는 P1. 모두 준비되면 즉시 다음 단계
- 입력(`CharacterSelectInput`): 1인 = 모든 키·패드가 P1(화살표, Z/Enter/Space 확정, X/Esc 취소). 2인 = InputBindings로 나눔 — P1 ←→·Z·X(+Enter·Esc), P2 A D·F·G. 패드는 선택 화면 동안 붙는 `GamepadAssigner`(경기와 같은 규칙) 주인에게: 십자키/스틱 고르기(좌석별 StickNav), A 확정, B 취소. 마우스·터치는 P1(호버 = 고르기, 클릭/탭 = 확정). 화면이 가려지면 assigner를 떼서 경기 assigner와 겹치지 않음
- 화면: `SelectCard` 재사용(`follow_focus=false`, `set_thumb(CharacterPortrait)`, `set_marks` 커서 배지), 선택 링 = 잠근 플레이어 색. `PlayerSlot`(DS-CMP-10) 한 줄 머리 + `PromptRow`. 봇 슬롯은 "봇 · 자동 선택 · 준비 완료". 폰(논리 높이 < 900, 창 크기가 바뀌면 다시 판정)은 compact: 초상 112px 머리·가슴 구도, 캡션 한 줄, 간격 s3, 넘치면 FitCenter 스크롤
- 초상은 포커스·선택된 카드만 `UPDATE_WHEN_VISIBLE`(화면이 경기장·경기 아래 숨으면 안 그림), 나머지는 `UPDATE_ONCE`(크기 바뀌면 한 번 다시)
- 프롬프트(`SelectPrompts`/`SeatDevices`): 마지막 사용 장치 → 잡은 패드 → (1인) 터치 → 키보드. PS 계열 패드 이름이면 ✕/○
- P1~P4 식별: `PlayerRingMesh`(모양 띠) → `FighterIdentity`(링+라벨)와 `FogSilhouette`. `FighterView.setup(index, config, character)`가 `CharacterCatalog.for_character`로 모델 선택(클래식은 슬롯 모델). fighter_view.gd 200줄로 줄이려 `BatUseDots` 분리
- sim 연결: `main.gd`가 `World.new(..., setup.characters())`·`MatchStage.setup(..., characters)`. 메뉴 배경·perf 장면은 계속 클래식(해시 불변)
- 리플레이: `ReplayVerifier.characters(export)` = `players[].character`(=`match_players.character`) 슬롯 순, `event_schema_version` ≥ 5일 때만(4 이하 = 모델 이름이 기록됐지만 sim은 클래식). 새 열·마이그레이션 없음. sim·해시 기대값 변경 없음
- 트래킹(스키마 4 → 5): `character_selected` 필수 `slot, character, style, is_bot, input_device`(+사람 `browse_count`) — 모두 확정한 순간 슬롯마다(봇 포함), 같은 조합 재확정은 한 번만(`CharacterSelectTracking.same_as`). `select_cancelled{screen:"character"}`. 슬롯 `style` = `CharacterData.style_of`(클래식 `classic`, 전엔 `default`), `match_ended.players[]`에 `character`·`style` 추가
- 증거: `evidence/char-select-{1p-browse,1p-ready,2p}{,-phone}.png`(폰 = 1624×750 창, UI 배율 1.6), `player-ids.png`·`player-ids-gray.png`(4인, 흑백에서 ●▲■◆ 구분). 캡처 스크립트 `scripts/capture_char_select.gd`, `scripts/capture_player_ids.gd`
