# Phase 4 — Tasks

**Last Updated:** 2026-09-30

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | ArenaData + Collision/Rules 경기장 기반 판정 (기본 원 동작 동일) | PRD-ARCH-03 | `test_arena_data`, `test_collision` | ✅ |
| T2 | 기믹: 화상 영역 · 파괴 발판 · 튕김 발판 · 주기 이벤트 | PRD-ARENA-01~04 | `test_gimmicks` | ✅ |
| T3 | 경기장 4종 데이터 + 봇 가장자리 판단 경기장 대응 | PRD-ARENA-01~04, PRD-BOT-01 | 봇전 완주 테스트 | ✅ |
| T4 | Phase 3 이월 sim 이슈 3건 | PRD-CMB-01, PRD-ITEM-02 | 단위 테스트 | ✅ |
| T5 | 리플레이 해시 갱신 + 경기장별 해시 | PRD-ARCH-05 | `test_replay` | ✅ |
| T6 | 렌더: 경기장 뷰·테마 변형·위험 표시·안개 실루엣·장식 가림 검사 | DS-THM-02, DS-VIS-03/04, GD-CAM-01 | `test_arena_view`, `test_arena_look` + 캡처 5종 (Forward+·Compatibility) | ✅ |
| T7 | SelectCard + 경기장 선택 화면 + 트래킹 | DS-CMP-08, PRD-UI-02, PRD-DATA-03 | `test_select_card`, `test_app_flow` + 캡처 | ✅ |
| T8 | 아이템 모델 정식화: 상자·방망이·폭탄·돌멩이 (소프트 툰 절차적 모델, 들고 있는 자세 오프셋, 폭탄 도화선 불꽃) — 🖼 캡처 비교 | DS-VIS-05, PRD-ITEM-02~04 | `test_item_view`, `test_item_models` + 캡처 | ✅ (🖼 사용자 확인 대기) |
