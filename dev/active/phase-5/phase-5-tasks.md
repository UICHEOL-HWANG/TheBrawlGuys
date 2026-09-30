# Phase 5 — Tasks

**Last Updated:** 2026-09-30 23:10 KST (feat/p5-cutin: T4 컷인 + T10 필살기 트래킹, test 882/882, check-all 통과)

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | StyleData + AttackSet 스타일 구성 + 이동 오버라이드 | PRD-ARCH-03 | `test_style_data` · `test_classic_compat` | ✅ (feat/phase5-sim) |
| T2 | 권투 · 무기 · 원거리(투사체) | PRD-STYLE-01~03 | 단위 + 투사체 판정 (`test_projectile`) | ✅ (feat/phase5-sim) |
| T3 | 필살기 게이지 · 입력 · 캐릭터별 4종 (sim) | PRD-STYLE-01~03 | `test_special` · `test_character_replay` | ✅ (feat/phase5-sim) |
| T4 | 필살기 컷인 연출 (렌더) | GD-CAM-01 | `test_special_cutin` · 캡처 `evidence/cutin-*.png` | ✅ (feat/p5-cutin) |
| T5 | 봇 스타일 사거리 · 필살기 사용 | PRD-BOT-02 | `test_bot` · `test_bot_style` | ✅ (feat/phase5-sim) |
| T6 | 밸런스 시뮬 100판 → 승률표 30~70% | PRD-STYLE-01~03 | `evidence/balance.csv` (35~67%) | ✅ (feat/phase5-sim) |
| T7 | 로컬 2인 (P2 키 · 게임패드 자동 할당) | PRD-LOCAL-01 | `test_local_input` | ⬜ |
| T8 | 🖼 스타일 실루엣·악센트 시안 → 확정 | DS-VIS-02 | 사용자 승인 | ⬜ |
| T9 | 캐릭터 선택 + PlayerSlot + P1~P4 식별 + 버튼 프롬프트 | DS-CMP-08/10, DS-VIS-03, DS-TOK-06 | 흑백 캡처 | ⬜ |
| T10 | 트래킹: character_selected · special_* · gauge_full · 스타일별 요약 | PRD-DATA-03/04 | `test_match_telemetry` · `test_special_telemetry` | 🟨 필살기 부분 ✅ (feat/p5-cutin: special_used·special_hit·gauge_full, 슬롯 요약 specials·special_hits, press_special, 스키마 4, 마이그레이션 0003). character_selected·스타일별 요약은 T9 이후 |
| T11 | 온보딩 튜토리얼: 첫 로그인 후 연습장에서 이동→점프→약·강공격→가드→잡기·던지기→아이템→(필살기) 단계별 미션, 건너뛰기·다시보기, 단계별 퍼널 트래킹(tutorial_step_*) | PRD-UI-02, PRD-DATA-03 | `test_tutorial_flow` + 캡처 | ⬜ |
