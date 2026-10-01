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
| B6 | 이메일 6자리 인증코드 로그인 (Supabase OTP, 모든 플랫폼) + 카드 이메일 모드 + TextField·CodeInput | PRD-AUTH-01, DS-CMP-14/17/18, PRD-DATA-03 | `test_email_otp`, `test_supabase_otp`, `test_login_email`, `test_form_inputs` + `evidence/login-email-*.png` | ✅ 코드 (feat/email-otp, 미병합) · ⬜ 사용자: Supabase Email·템플릿·SMTP 설정 후 실메일 확인 |
| D1 | vercel.json + deploy_web.sh + 배포 | PRD-PLT-03 | Vercel URL 동작 | ⬜ |
| A7 | 리플레이급 입력 로그 `match_inputs` + 재현 메타·`final_state_hash` + 재생 검증 (마이그레이션 0002). `match_timeline` 1Hz 압축은 보류(사용자 결정, `pos` 행 유지) | PRD-DATA-04 | `test_input_log`, `test_replay_verifier`, `test_match_capture_size` | ✅ (feat/telemetry-v2, 미병합) |
| A8 | 식별·버전·맥락, 행동 피처 컬럼, 세션·좌절·성능 이벤트 (analytics-strategy §3) | PRD-DATA-03/04 | `test_event_catalog`, `test_match_telemetry`, `test_match_features`, `test_match_tracking`, `test_session_tracker`, `test_supabase_schema` | ✅ (feat/telemetry-v2, 미병합) |
| A7u | 👤 Supabase SQL Editor에서 `0002_replay_and_features.sql` 실행 | PRD-DATA-04 | 테이블·열 확인 | ⬜ 사용자 |
| A9 | `analysis/` 워크스페이스: 재생 피처 추출 + 첫 분석 (라이브러리 선택 질문 선행) | PRD-DATA-04 | 스모크 테스트 | 🟡 합성 데이터로 1차 완료 (`analysis/README.md`, `scripts/gen_dataset.gd`), 남음: `match_inputs` 재생 → 실데이터 타임라인, 실사용자로 M1·M5 재실행 |
