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
| B1 | App 셸 + MatchSetup + 화면 스택 | PRD-UI-02 | `test_app_flow` | ✅ (feat/app-shell, 미병합) |
| B2 | MenuBackdrop 궤도 디오라마 | DS-LAY-03 | `test_menu_backdrop` + 캡처 | ✅ (feat/app-shell) |
| B3 | 🖼 로그인 → LoginPanel 확정 (calm forest 유리 카드) + CrestLogo | DS-CMP-14/15 | 사용자 결정 + `evidence/login-final*.png` | ✅ (feat/app-shell) |
| B4 | MenuButton · Panel | DS-CMP-06/07 | 갤러리 | ✅ (feat/app-shell) |
| B5 | 데스크톱 실로그인 확인 (nonce 포함 redirect_to 허용 여부) | PRD-AUTH-01 | 실로그인 | ⬜ 사용자 |
| D1 | vercel.json + deploy_web.sh + 배포 | PRD-PLT-03 | Vercel URL 동작 | ⬜ |
