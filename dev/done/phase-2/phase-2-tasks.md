# Phase 2 — Tasks

**Last Updated:** 2026-09-29 (T20 완료, 최종 리뷰 수정 반영)
상세 단계와 코드: [`phase-2-plan.md`](./phase-2-plan.md) · 결정·이슈: [`phase-2-context.md`](./phase-2-context.md)

## 사전 조건
- [x] context의 사용자 확인 대기 결정 E1~E11 승인 (사용자 승인 2026-09-29)
- [ ] 🖼 4버튼 레이아웃 Stitch 시안 (T13, 사용자 수행) — 대기, 기본값 0 호 배치로 진행
- [ ] Android 실기기 — 없음, 터치 완료 기준은 대기 표시

## 태스크

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | GameConfig Phase 2 수치 | PRD-CFG-01, PRD-CMB-01~04, PRD-ITEM-01~04 | `test_game_config`, `test_config_schema` | ✅ |
| T2 | AttackSet + Fighter 상태·필드 (snapshot v3) | PRD-ARCH-03 | `test_attack_set`, `test_fighter` | ✅ |
| T3 | 약공격 3타 콤보 + 입력 버퍼 | PRD-CMB-01, E1, E2 | `test_actions`, `test_ringout_feel` | ✅ |
| T4 | 강공격 + 차지 | PRD-CMB-02, E3 | `test_charge` | ✅ |
| T5 | 가드 + apply_hit 공용화 | PRD-CMB-03, E4 | `test_guard` | ✅ |
| T6 | 잡기 → 던지기 | PRD-CMB-04, E5 | `test_grab`, `test_rules` | ✅ |
| T7 | 아이템 엔티티 + 상자 생성 + 낙하 (snapshot v4) | PRD-ITEM-01, PRD-ARCH-05, E6, E8 | `test_items` | ✅ |
| T8 | 줍기·사용·던지기·떨어뜨리기 | PRD-ITEM-02, PRD-ITEM-04, E6, E7 | `test_item_use` | ✅ |
| T9 | 폭탄 도화선 + 범위 폭발 | PRD-ITEM-03, E7 | `test_bomb` | ✅ |
| T10 | 리플레이 1200틱 + 봇 커버리지 | PRD-ARCH-05, E11 | `tests/replay/*` | ✅ |
| T11 | HoldLatch + 키보드 6액션 | PRD-CTL-01, PRD-CTL-02 | `test_hold_latch`, `test_input_bindings` | ✅ |
| T12 | 터치 4버튼 (탭/홀드, 레이아웃 3안, safe area, cancel) | PRD-CTL-03, PRD-CTL-04, DS-LAY-01, E9 | `test_attack_button_model`, `test_touch_layout`, `test_touch_input` + 캡처 3장 | ✅ |
| T13 | 🖼 4버튼 레이아웃 게이트 (Stitch) | DS-LAY-01 | 시안 3안 + 결정 기록 | 🖼 대기 |
| T14 | TouchButton v2 + GrabContext + 테마 포커스 색 | DS-CMP-04, PRD-CTL-03 | `test_touch_button`, `test_grab_context` + 갤러리 | ✅ |
| T15 | ChargeGauge + 머리 위 레이어 | DS-CMP-05, E10 | `test_charge_gauge` + 갤러리 | ✅ |
| T16 | 아이템 표시 (상자·그림자·모양·든 아이템) | DS-VIS-05 | `test_item_view`, `test_fighter_view` + 갤러리 | ✅ |
| T17 | 가드 버블 + 잡기 대상 표시 | DS-VFX-02 | `test_fighter_view`, `test_grab_hint` | ✅ |
| T18 | 봇 2단계 | PRD-BOT-02 | `test_bot`, `test_bot_coverage` | ✅ |
| T19 | main 연결 + 연출 + 재시작 + HUD safe area | PRD-UI-01, DS-LAY-02, DS-VFX-02 | `test_main_smoke`, `test_feel_director`, `test_hud` + 스크린샷 | ✅ |
| T20 | 상자 쟁탈 데모 + 측정 + 마감 | README R3·R4·R6 | 영상·측정 + `check-all.sh` | ✅ |

상태: ⬜ 예정 · 🟨 진행 · ✅ 완료 · 🖼 대기 (사용자 시안 비교 대기)

## Phase 2 완료 기준 (PHASES.md)
- [x] 상자가 떨어지면 서로 먼저 가려고 한다 (녹화 영상) — 봇 대 봇 데모 씬(두 봇 모두 2단계, 떨어지는 상자에 반응), 사람 플레이어 없음 — `evidence/item-race-*.png`
- [ ] 터치만으로 6액션 전부를 쓸 수 있다 (Android 실기기) — 실기기 확인 대기
- [x] 인게임 UI가 전부 DS 컴포넌트로 구성되어 있다 (갤러리 등록 확인)
- [x] 리플레이 회귀 테스트 갱신·통과
