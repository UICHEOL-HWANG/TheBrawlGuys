# Phase 1 — Tasks

**Last Updated:** 2026-09-29
상세 단계와 코드: [`phase-1-plan.md`](./phase-1-plan.md) · 결정·이슈: [`phase-1-context.md`](./phase-1-context.md)

## 사전 조건
- [ ] context의 사용자 확인 대기 결정 D1~D8 승인
- [ ] HUD 🖼 게이트용 Stitch 시안 (T12, 사용자 수행 — 지연 시 기본 배치로 진행)
- [ ] Android 실기기 (없으면 터치 완료 기준은 대기 표시)

## 태스크

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | GameConfig Phase 1 수치 + ConfigSchema 가드 | PRD-CFG-01, PRD-RULE-04 | `test_game_config`, `test_config_schema` | ⬜ |
| T2 | InputFrame 양자화 + 버튼 래치 | PRD-CTL-01, D5, D6 | `test_input_frame`, `test_button_latch` | ⬜ |
| T3 | Collision (지면·경계, 캡슐–캡슐, 캡슐–박스) | PRD-ARCH-01 | `test_collision` | ⬜ |
| T4 | AttackData + Fighter 데이터 | PRD-ARCH-03, D4 | `test_fighter` | ⬜ |
| T5 | World 이동·점프·중력·밀어내기 + snapshot v2 | PRD-CTL-02, PRD-ARCH-04, D1 | `test_world`, `test_world_movement` | ⬜ |
| T6 | Combat: 약공격·넉백·hitstun·hitstop | PRD-RULE-01, PRD-RULE-04, PRD-RULE-05, D7 | `test_combat` | ⬜ |
| T7 | Rules: 링아웃·스톡·리스폰·승패 | PRD-RULE-02, PRD-RULE-03 | `test_rules` | ⬜ |
| T8 | 리플레이 하네스 | PRD-ARCH-05, D3 | `tests/replay/test_replay.gd` | ⬜ |
| T9 | 봇 1단계 | PRD-BOT-01 | `test_bot` | ⬜ |
| T10 | 키보드 입력 (InputMap + 래치) | PRD-CTL-02 | `test_input_bindings` | ⬜ |
| T11 | 터치 기본 (스틱 + 점프 + 공격) + TouchStick/TouchButton v1 | PRD-CTL-03, PRD-CTL-04, DS-CMP-03, DS-CMP-04 | `test_touch_stick_model` + 갤러리 | ⬜ |
| T12 | 🖼 HUD 시안 게이트 (Stitch) | DS-LAY-01, DS-LAY-02 | 시안 3안 + 결정 기록 | ⬜ |
| T13 | HUD 컴포넌트 (DamageCounter·StockIcons·ResultBanner) + HUD 배치 | DS-CMP-01, DS-CMP-02, DS-CMP-09, DS-LAY-02, PRD-UI-01 | `test_damage_color` + 갤러리 스크린샷 | ⬜ |
| T14 | FighterView (보간·스냅·링·깜빡임) + 경기장 가장자리 | DS-VIS-03, DS-VIS-04, GD-FEEL-03 | 스크린샷 | ⬜ |
| T15 | 타격감 v1 (흔들림·히트 퍼프) + 카메라 프레이밍 개선 | GD-FEEL-01, GD-FEEL-02, DS-VFX-01, GD-CAM-01, D2 | `test_shake_model`, `test_camera_framing` | ⬜ |
| T16 | main 연결: 경기 루프·입력·봇·HUD·결과·재시작·틱 비용 | PRD-UI-01, PRD-NFR-02 | 수동 + 스크린샷 | ⬜ |
| T17 | 측정·튜닝: sim 벤치, 입력 지연, 넉백 수치 | PRD-NFR-02, PRD-NFR-03, PRD-CORE-01 | 측정 로그 + 튜닝 기록 | ⬜ |
| T18 | Phase 1 마감 (검사·증거·문서) | README R3·R4 | `check-all.sh` | ⬜ |

상태: ⬜ 예정 · 🟨 진행 · ✅ 완료

## Phase 1 완료 기준 (PHASES.md)
- [ ] 봇과 한 판을 끝까지 할 수 있다 — 키보드와 Android 터치 둘 다
- [ ] 대미지 100% 이상에서 약공격 한 방에 경기장 밖으로 날아가는 게 눈에 보인다 (녹화 영상)
- [ ] HUD가 휴대폰 화면에서 한눈에 읽힌다 (실기기 스크린샷)
- [ ] 4인 World(봇 4) 1틱 비용이 측정·기록되어 있다
- [ ] 입력 → 화면 반영 ≤ 3프레임
- [ ] 모든 전투·타격감 수치가 디버그 패널에 있다
