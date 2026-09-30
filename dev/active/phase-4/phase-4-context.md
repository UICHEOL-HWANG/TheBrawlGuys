# Phase 4 — Context

**Last Updated:** 2026-09-30
**상태:** 시작
**계획:** [`phase-4-plan.md`](./phase-4-plan.md) (통합 계획의 "Phase 4" 절) · **체크리스트:** [`phase-4-tasks.md`](./phase-4-tasks.md)
**이전 Phase:** [`dev/done/phase-3/phase-3-context.md`](../../done/phase-3/phase-3-context.md)

## 목표
경기장마다 싸우는 방식이 달라진다 (PHASES Phase 4).

## 결정
- G1: `ArenaData`는 sim 쪽 데이터(판정 도형·링아웃·기믹·테마 id). 기본 원형 경기장은 현재와 동일 동작
- G2: 기믹은 전부 sim·결정적, 새 sim 이벤트(`gimmick_damage`, `platform_break`, `bounce`, `fog_start`, `fog_end`)로 렌더·트래킹에 전달
- G3: 리플레이 GOLDEN/BEHAVIOR 해시는 의도적으로 갱신, 커밋 메시지에 사유. 경기장별 해시 추가
- G4: Phase 3 이월 sim 이슈(hitstop 입력 삼킴, 방망이 밸런스, 동틱 상호타격 편향) 이번에 처리
- G5: 트래킹 — `gimmick_triggered`, `gimmick_ringout`, `arena_selected`, `stock_lost.cause/zone`

## 핵심 파일
`src/sim/collision.gd`, `rules.gd`, `world.gd`, 신규 `src/sim/arena/`, `src/render/arena_view.gd`, `decor_view.gd`, `environment_rig.gd`, `tests/replay/test_replay.gd`

## T1–T5 병합 (2026-09-30, merge 6b823a0)
- 테스트 547/547, check-all 통과. 4봇 틱 비용 경기장별 평균 66~80µs (예산 2000µs)
- 경기장 id: classic(기본) · lakeside_camp · log_bridge · mushroom_forest · foggy_forest. `World(config, seed, count, ArenaCatalog.build(id, config))`
- 새 sim 이벤트: gimmick_damage{kind,target,amount,pos} · platform_break/restore{id,pos} · bounce{fighter,pad,pos} · fog_start{id,ticks} · fog_end{id} · ringout.zone(kill_y|blast|lake|water)
- state_view 추가: arena, arena_theme, arena_floors, gimmicks[], fighter.burning
- 해시: GOLDEN 2216053793, BEHAVIOR 11665018 (사유는 각 커밋), ARENA_HASHES는 test_arena_replay.gd
- 봇 미러 교착 방지: `bot_attack_range_spread` (동시 타격 공정화의 부작용)
- 남은 것: T6 렌더(경기장 뷰·테마·위험 표시·안개), T7 선택 화면 — 앱 셸 병합 후

## T6–T8 렌더·선택 화면·아이템 모델 (2026-09-30, 브랜치 feat/phase4-render)
- 렌더는 sim의 `ArenaData`(ArenaCatalog.build(id))를 그대로 읽어 그린다. `ArenaView`(바닥 `FloorMesh`, 링아웃 물 `WaterView`, 기믹 뷰 레지스트리 `GimmickViews`) → `MatchStage.setup(..., arena_id)` / `set_arena()`. main은 `MatchSetup.arena_id`로 무대를 만들고, 메뉴 배경은 재시작마다 `BackdropMatch.ARENA_CYCLE`로 경기장을 돈다
- 파일 구조: 경기장 테마 `src/render/arena/themes/`(1파일/경기장), 장식 `src/render/arena/arenas/*_view.gd`(1파일/경기장, `ArenaDressings` 등록만), 기믹 뷰 `src/render/arena/gimmicks/`(캠프파이어·발판·버섯·안개), 전투원 위험 표시 `src/render/hazards/`(불꽃·안개 실루엣), 아이템 모델 `src/render/props/items/`(상자·방망이·폭탄·돌멩이, `ItemModels` 등록만)
- 장식 가림: 디더 페이드 대신 배치 단계에서 제거 — `DecorOcclusion`(대전 카메라 기본 자세 + `cam_zoom_max`)가 경기장 중심부 시선을 자르는 장식을 빼고 `test_arena_look`가 경기장 5종 모두 검증
- 대전 카메라 앵커는 state_view의 `arena_radius`(경기장 도달 거리)를 쓴다 (통나무 다리가 화면에 들어오게). 물 링아웃(`zone` = lake/water)은 물보라 VFX·SFX
- `soft_toon.gdshader`: 점광원(캠프파이어·버섯)은 ATTENUATION으로 감쇠 — 해의 그림자 틴트 띠만 전역. Compatibility(웹)은 안개 층 알파 ×0.4, 안개 부스트 0.012로 측정 보정 (evidence `*-compat.png`)
- 선택 흐름: 타이틀 → 봇 대전 → `ArenaSelectScreen`(App.SELECT_STEPS, Phase 5는 "character"를 앞에 추가) → 대전, 메뉴로 = `ScreenRouter.pop_to(title)`. 트래킹 `arena_selected{arena, browse_count}`, `select_cancelled{screen:"arena", dwell_ms}`, `screen_viewed`(라우터)
- 든 아이템은 KayKit `handslot.r` 뼈(`CharacterModel.hand_slot()`)에 붙고 모델 스케일을 되돌린다. 손 슬롯 축(유휴 자세): -x 위, +z 몸 바깥 — 캡처로 확인
- 증거: `dev/active/phase-4/evidence/` (arena-*.png, arena-*-compat.png, arena-select-*.png, items-*.png), 캡처 스크립트 `scripts/capture_arenas.gd` · `capture_arena_select.gd` · `capture_items.gd`
- 남은 것: 🖼 T8 모델·T6 경기장 룩 사용자 확인, 실제 웹 export 확인(데스크톱 Compatibility 렌더러로만 확인), 트래킹 `gimmick_*`·`stock_lost` 구역은 텔레메트리 작업 몫

## 사용자 요청 (2026-09-30)
- 아이템 모델을 임시 도형에서 정식 모델로 (T8). 방식: 코드로 만드는 절차적 저폴리 모델(`src/render/props/items/` 아이템당 1파일) — 다운로드·라이선스 없음, 기존 소프트 툰·구 클러스터 룩과 일관. 색은 DS 토큰(BARK·STONE_*·FIRE 등). 🖼 캡처로 확인 후 확정
- 게스트 로그인은 두지 않음 (Google만) — 재확인
