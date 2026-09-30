# Phase 5 — Tasks

**Last Updated:** 2026-10-01 06:00 KST (feat/p5-tutorial: T11 온보딩 튜토리얼)

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | StyleData + AttackSet 스타일 구성 + 이동 오버라이드 | PRD-ARCH-03 | `test_style_data` · `test_classic_compat` | ✅ (feat/phase5-sim) |
| T2 | 권투 · 무기 · 원거리(투사체) | PRD-STYLE-01~03 | 단위 + 투사체 판정 (`test_projectile`) | ✅ (feat/phase5-sim) |
| T3 | 필살기 게이지 · 입력 · 캐릭터별 4종 (sim) | PRD-STYLE-01~03 | `test_special` · `test_character_replay` | ✅ (feat/phase5-sim) |
| T4 | 필살기 컷인 연출 (렌더) | GD-CAM-01 | `test_special_cutin` · 캡처 `evidence/cutin-*.png` | ✅ (feat/p5-cutin) |
| T5 | 봇 스타일 사거리 · 필살기 사용 | PRD-BOT-02 | `test_bot` · `test_bot_style` | ✅ (feat/phase5-sim) |
| T6 | 밸런스 시뮬 100판 → 승률표 30~70% | PRD-STYLE-01~03 | `evidence/balance.csv` (35~67%) | ✅ (feat/phase5-sim) |
| T7 | 로컬 2인 (P2 키 · 게임패드 자동 할당) + 모드 "로컬 2인" + 키 바 필살기 키캡(게이지 링)·플레이어별 바 | PRD-LOCAL-01, DS-CMP-16 | `test_local_input` · `test_local_match` · `test_key_hint_bar` + `evidence/key-hint-*.png` | ✅ (feat/p5-local2p) — 실제 패드·한 키보드 2인 한 판 완주는 사용자 확인 |
| T8 | 🖼 스타일 실루엣·악센트 시안 → 확정 | DS-VIS-02 | 사용자 승인 (`evidence/silhouette-compare.html`) · `test_style_gear` · `test_style_gear_catalog` · `evidence/silhouette-final*.png` | ✅ A(장비) 승인 · 적용 (feat/p5-gear) |
| T9 | 캐릭터 선택 + PlayerSlot + P1~P4 식별 + 버튼 프롬프트 | DS-CMP-08/10, DS-VIS-03, DS-TOK-06 | `test_character_select_{model,input,screen}` · `test_player_slot` · `test_select_prompts` · `test_player_ring_mesh` · `test_app_flow` + `evidence/char-select-*.png`, `player-ids{,-gray}.png` | ✅ (feat/p5-charselect) — 실제 패드·터치 폰 확인은 사용자 |
| T10 | 트래킹: character_selected · special_* · gauge_full · 스타일별 요약 | PRD-DATA-03/04 | `test_match_telemetry` · `test_special_telemetry` | ✅ 필살기 부분 (feat/p5-cutin, 스키마 4, 0003) + character_selected(is_bot·input_device)·select_cancelled(character)·match_ended.players[] character/style (feat/p5-charselect, 스키마 5, 새 마이그레이션 없음) |
| T11 | 온보딩 튜토리얼: 첫 로그인 후 연습장에서 이동→점프→약·강공격→가드→잡기·던지기→아이템→(필살기) 단계별 미션, 건너뛰기·다시보기, 단계별 퍼널 트래킹(tutorial_step_*) | PRD-UI-02, PRD-DATA-03 | `test_tutorial_flow` · `test_tutorial_detector` · `test_tutorial_steps` · `test_tutorial_play`(실제 sim으로 8미션 완주) · `test_tutorial_ui` · `test_app_tutorial` + `evidence/tutorial-*.png` | ✅ (feat/p5-tutorial, 스키마 6) — 실제 폰 터치·패드로 한 바퀴는 사용자 확인 |

### 후속 · 주의 (feat/p5-cutin)
- ⚠️ **배포 전 Supabase `0003_special_hits.sql` 적용 필수** — 이벤트 스키마 4 빌드는 `match_players.special_hits`를 보내므로, 열이 없으면 `match_players` insert 전체가 실패해 경기 기록이 빠진다(0002도 아직 미적용)
- ⬜ 설정 화면에 "모션 줄이기" 토글(`[accessibility] reduce_motion`) + `settings_changed` 트래킹 — 지금은 설정/옵션 화면이 없어 키만 읽는다(경기 시작마다 다시 읽음). Phase 6 DS-A11Y-02와 함께

### 후속 · 주의 (feat/p5-charselect)
- ⚠️ 배포 전 0002·0003 적용 필요는 그대로(0004 없음: `match_players.character/style` 열은 0001부터 있음)
- ⬜ 봇 캐릭터는 경기 시드로 뽑는데 `MatchSetup.seed`가 늘 1이라 같은 사람 선택엔 늘 같은 봇 캐릭터 — 경기마다 시드를 바꾸는 건 별도 결정(리플레이는 시드를 기록하므로 무관)
- ⬜ 실제 게임패드 2개·PS 패드 글리프·터치 폰에서 캐릭터 선택 확인 (사용자)
- ⬜ T8 스타일 장비(p5-gear)와 병합 시 `FighterView`의 gear 훅 두 줄 유지(이 브랜치에서 `FighterIdentity`·`BatUseDots` 분리)

### 후속 · 주의 (feat/p5-tutorial)
- ⬜ 실제 기기로 튜토리얼 한 바퀴: 폰 터치(특히 필살기 = 공격 길게 + 가드 동시), 패드(Start = 건너뛰기), 키 재지정 뒤 문구
- ⬜ 터치 버튼 강조: 터치에서는 키 바가 숨어 문구로만 안내한다. `TouchInput`에 "지금 누를 버튼" 링을 넣으려면 touch_input.gd(270줄, 이미 200줄 초과)부터 나눠야 함
- ⬜ 튜토리얼 진행은 기기(`user://settings.cfg`)에 저장 — 다른 기기에서 같은 계정으로 처음 로그인하면 다시 뜬다(계정 단위 저장은 Supabase 프로필이 생기면)
- ⬜ 퍼널 대시보드: Amplitude에서 `tutorial_started` → `tutorial_step_completed`(index 1..8) → `tutorial_completed` 퍼널 + `tutorial_skipped.step` 분포 (tracking-plan Q18)
