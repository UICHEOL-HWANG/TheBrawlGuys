# Phase 5 — Context

**Last Updated:** 2026-09-30 23:10 KST
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

## T8 스타일 실루엣 시안 (2026-09-30, `feat/p5-silhouette`) — 🖼 승인 대기
- 디버그 전용 `src/debug/silhouette/` (`StyleMockup` + A `MockupGear` · B `MockupTrim` · C `MockupStance`/`StyleIcon`). 기본 룩(`CharacterCatalog`·`FighterView`)은 건드리지 않음 (`test_style_mockup` 확인)
- 캡처 `scripts/capture_silhouette.gd` → `evidence/silhouette-{base,A,B,C}{,-bw,-sil}.png`, 비교 `evidence/silhouette-compare.html`
- A 장비(장갑·대검·지팡이+구슬, 모자) 실루엣 3/3 · B 악센트 트림 흑백에서 0/3 · C 자세+아이콘 아이콘으로만 3/3. 추천 A (아이템 들 때 장비 숨김 규칙 필요)
