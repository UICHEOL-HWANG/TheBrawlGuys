# Platform — Tasks

**Last Updated:** 2026-09-30

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| A0 | 문서: PRD·PHASES·design·tracking-plan 갱신 | PRD-AUTH-01, PRD-DATA-03/04 | `check-docs.sh` | ✅ |
| A1 | Secrets 로더 + example + gitignore + 서비스(비공개) 키 차단 | PRD-DATA-03 | `test_secrets` | ✅ |
| A2 | EventCatalog + Analytics autoload (배치·큐·재시도) | PRD-DATA-03 | `test_event_catalog`, `test_analytics` | ✅ |
| A3 | SupabaseClient (auth·rest·refresh) | PRD-DATA-04 | `test_supabase_client` | ✅ |
| A4 | Google OAuth PKCE (웹 리다이렉트·데스크톱 루프백) + 세션 저장 | PRD-AUTH-01 | `test_auth_pkce` + 실로그인 | ✅ |
| A5 | 마이그레이션 SQL + RLS | PRD-DATA-04 | database-reviewer | ✅ |
| A6 | MatchTelemetry + MatchRecorder (Amplitude·Supabase) | PRD-DATA-03/04 | `test_match_telemetry` | ✅ |
| B1 | App 셸 + MatchSetup + 화면 스택 | PRD-UI-02 | `test_app_flow` | ⬜ |
| B2 | MenuBackdrop 궤도 디오라마 | DS-LAY-03 | 캡처 | ⬜ |
| B3 | 🖼 로그인 시안 3개 → LoginPanel 확정 | DS-CMP-14 | 사용자 승인 | ⬜ |
| B4 | MenuButton · Panel | DS-CMP-06/07 | 갤러리 | ⬜ |
| D1 | vercel.json + deploy_web.sh + 배포 | PRD-PLT-03 | Vercel URL 동작 | ⬜ |
| A7 | 리플레이급 입력 로그 `match_inputs` + 재현 메타·`final_state_hash` + 재생 검증, 위치 샘플 행 → `match_timeline` 1Hz 압축 (마이그레이션 0002) | PRD-DATA-04 | `test_input_log`, 재생 일치 | ⬜ |
| A8 | 식별·버전·맥락, 행동 피처 컬럼, 세션·좌절·성능 이벤트 (analytics-strategy §3) | PRD-DATA-03/04 | `test_event_catalog`, `test_match_telemetry` | ⬜ |
| A9 | `analysis/` 워크스페이스: 재생 피처 추출 + 첫 분석 (라이브러리 선택 질문 선행) | PRD-DATA-04 | 스모크 테스트 | ⬜ |
