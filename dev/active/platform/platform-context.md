# Platform (로그인 · 트래킹 · 배포) — Context

**Last Updated:** 2026-09-30
**상태:** 시작
**계획:** [`platform-plan.md`](./platform-plan.md) · **체크리스트:** [`platform-tasks.md`](./platform-tasks.md)

## 범위
계획의 A(플랫폼 레이어), B(앱 셸 + 로그인 화면), Vercel 배포. Phase 4·5 기능의 트래킹 이벤트는 각 Phase 태스크에서 단다.

## 사용자 결정 (2026-09-30)
| 질문 | 선택 |
|---|---|
| 이벤트 입자도 | Amplitude = 핵심 순간 + 경기 요약, Supabase = 원시 행동 로그 |
| Supabase 용도 | 경기 기록(matches · match_players · match_events) + Auth |
| 로그인 | Google OAuth만 (Supabase Auth, PKCE) |
| Vercel | 웹 빌드 배포. 첫 화면 = 로그인 창, 배경은 궤도 카메라 + 봇 난투 디오라마 |
| 로그인 디자인 | 🖼 시안 3개 비교 후 확정 |
| 키 전달 | `config/secrets.local.cfg` (gitignore) 에 사용자가 직접 입력 |

## 핵심 파일
- 신규: `src/platform/{secrets,analytics,supabase,auth}/`, `src/app/`, `supabase/migrations/`, `vercel.json`, `scripts/deploy_web.sh`, `docs/tracking-plan.md`
- 수정: `project.godot` (main scene · autoload), `src/main/main.gd` (MatchSetup 주입, 텔레메트리 훅), `export_presets.cfg` (secrets 포함)

## 결정
- P1: 트래킹은 렌더/앱 쪽에서 sim 이벤트를 **소비만** 한다 → sim·리플레이 해시 불변
- P2: 모바일 Google 로그인(딥링크)은 이번 범위 밖. 모바일 debug 빌드만 "건너뛰기"
- P3: 클라이언트에는 공개 키(Amplitude API key, Supabase anon key)만. 서비스(비공개) 키는 체크 스크립트로 차단
- P4: Supabase/Vercel CLI 미설치 → 마이그레이션은 SQL Editor, 배포는 `npx vercel`

## 사용자 대기
- [x] secrets.local.cfg 입력 (Amplitude·Supabase 키 유효 확인)
- [x] Supabase Google provider 활성화 + Redirect URL 등록 (2026-09-30 확인: authorize → accounts.google.com 302)
- [x] 마이그레이션 SQL 실행 (2026-09-30 확인: 4개 테이블 존재, anon 읽기·쓰기 42501 거부)
- [x] `npx vercel login` — uicheol-hwang / team cheorish (Hobby), 2026-09-30
- [ ] Amplitude MCP 커넥터 인증 (검증용, 선택)
- [ ] (B6 이메일 로그인) Supabase → Authentication → Sign In / Providers → **Email** 켜기 + "Allow new users to sign up" 켜기 (첫 인증 때 계정 생성). Email OTP Length **6**, Email OTP Expiration 600초 권장
- [ ] (B6) Authentication → Emails → Templates: **Magic Link**와 **Confirm signup** 두 템플릿 모두 `{{ .Token }}`을 넣는다 (기존 사용자는 Magic Link, 처음 오는 주소는 Confirm signup 메일을 받는다). 링크(`{{ .ConfirmationURL }}`)는 빼기 권장 — 메일 보안 스캐너가 링크를 먼저 열면 코드가 소모될 수 있음. 붙여넣을 본문은 아래 "B6" 절
- [ ] (B6) Authentication → Emails → SMTP Settings → **커스텀 SMTP** (예: Resend `smtp.resend.com` 465, user `resend`, password = Resend API 키, 보내는 주소는 인증한 도메인 예 `login@thebrawlguys.cloud`). 기본 SMTP는 **프로젝트 팀원 주소로만** 보내고 시간당 몇 통뿐이라 실제 플레이어에게는 안 간다. 커스텀 SMTP 뒤 Authentication → Rate Limits의 이메일 발송 한도를 올린다

## 배포 시점 결정 (2026-09-30)
- 사용자 선택 C: Vercel 프로젝트 생성·도메인 연결·배포는 **Phase 4·5 전부 끝난 뒤** 한 번에 (D1을 맨 마지막으로)
- 영향: 그 전까지 Google 로그인 검증은 **데스크톱 루프백**으로만. 웹 리다이렉트 경로는 단위 테스트로 검증하고, 배포 시 도메인을 Supabase Redirect URLs + `auth.redirect_web`에 등록 후 실동작 확인
- Git Import 아님: Vercel 빌드 환경에 Godot 없음 → 로컬 export 후 `npx vercel deploy` (prebuilt)

## A1–A6 병합 (2026-09-30, merge 59ce731)
- 테스트 496/496, check-all 통과. sim·replay 해시 불변
- 원시 행 보강(984c0a3): `hit`/`guard_hit` payload에 `attack_kind`(이름), `ringout` payload에 `cause`·`attacker_slot`
- 남은 리뷰 항목: 데스크톱 콜백 `state` 검사 없음(PKCE라 코드 주입은 불가, 조기 종료만 가능) → B1에서 redirect_to에 nonce 추가 / 세션 파일 평문 / 업로드 재시도 없음(matches.id가 클라이언트 uuid라 중복은 PK로 막힘) / 계정당 insert 한도 없음
- `AuthService`는 아직 씬에 연결 안 됨 → B1

## B1–B4 (2026-09-30, 브랜치 feat/app-shell)
- 메인 씬 `src/app/app.tscn`: `MenuBackdrop` + `ScreenRouter`(login → title → match, 커튼 전환, `screen_viewed`) + `LoginGate`(AuthService 래핑, 세션 복원 시 바로 타이틀, 모바일·키 없음은 이유 표시 + debug 건너뛰기 `login_skipped`)
- `MatchSetup`(mode, arena_id→`ArenaCatalog.build`, seed, slots) → `main.tscn`이 재사용 가능한 경기 씬. 단독 실행은 1 vs 봇 기본값. `MatchStage`·`MatchPresentation`·`MatchTracking`·`TickStats`·`LocalHints`로 분리(main.gd 274→170줄)
- 결과 배너 "메뉴로" → 타이틀 복귀(배경 다시 붙임). 타이틀: 봇 대전 / 로컬 2인·온라인 "준비 중" 비활성 / 로그아웃
- 루프백 `state` nonce: redirect_to = `http://127.0.0.1:<port>/callback?state=<nonce>`, 콜백은 nonce 일치 요청만 받음 (다른 요청은 404 후 계속 대기)
- ⚠ Supabase Redirect URLs가 쿼리 붙은 redirect_to를 허용하는지 실로그인으로 확인 필요. 막히면 허용 목록에 `http://127.0.0.1:54321/**` 추가
- 로그인 디자인 결정: 시안 3개 → 하단 박스안 → 최종 **calm forest 레퍼런스**(`docs/references/ref-login-calmforest.webp`) 유리 카드 + 크레스트(`CrestLogo`, 글자 없음, `assets/branding/crest-1024.png`). 증거 `evidence/login-final*.png`(1920·1280, 등장 6프레임씩)
- 배경: 낮은 3/4 궤도(pitch 24°), 난투 중심 추적, 화면별 NDC focus, `haze` 거리 안개 + 헤이즈 오버레이, P1~P4 숨김, 텔레메트리 없음
- 이월: 기존 `scripts/capture_evidence.gd`로 `main.tscn`/`app.tscn`을 `-s` 모드에서 열면 autoload(`Analytics`)가 아직 없어 컴파일 실패 (A6부터 있던 문제). 로그인 캡처는 `scripts/capture_login.gd`(autoload 불필요) 사용. macOS는 가려진 창을 그리지 않으므로 캡처 시 `--always-on-top`

## B6 이메일 인증코드 로그인 (2026-09-30, 브랜치 feat/email-otp)
- 사용자 결정: "이메일로 로그인" 추가 — 비밀번호 없이 6자리 코드. Google 유지
- `EmailOtp`(검사·60초 쿨다운·결과 매핑·트래킹) + `SupabaseClient.send_email_otp`/`verify_email_otp` → 세션은 PKCE 교환과 같은 경로(`_accept_session`)로 저장. `AuthService.send_email_code`/`verify_email_code`, `LoginGate`는 모바일에서도 이메일 허용
- UI: 카드의 ghost "이메일로 계속하기" → `EmailLoginView`(TextField DS-CMP-17 → CodeInput DS-CMP-18), `LoginEmailFlow`가 게이트와 연결. Enter 제출, Esc 뒤로. 증거 `evidence/login-email-{methods,step,code,error}.png` (1280×720, `scripts/capture_login_email.gd`)
- 결과 매핑: send 429 → rate_limited(쿨다운도 시작), 400/422 → invalid_email (단 `email_provider_disabled`·`otp_disabled`·`signup_disabled`·`email_address_not_authorized`는 설정 문제라 error + 경고 로그), 그 밖 → error. verify 4xx → wrong_code, 429 → rate_limited, 그 밖 → error. 4xx는 `net_error`로 보내지 않음
- 트래킹: `login_started/completed/failed {provider: email}`, `email_code_requested {result}`, `email_code_resent`, `email_code_verified {attempts}` — 이메일·코드 없음(테스트로 강제)
- 템플릿 본문 (Magic Link · Confirm signup 둘 다, 제목 `The Brawl Guys 로그인 코드: {{ .Token }}`):
  ```html
  <div style="font-family:sans-serif;max-width:420px;margin:0 auto;padding:24px;color:#17525A">
    <h2 style="margin:0 0 12px">The Brawl Guys 로그인 코드</h2>
    <p style="margin:0 0 16px">게임 화면에 아래 6자리 코드를 입력해 주세요.</p>
    <p style="font-size:32px;font-weight:bold;letter-spacing:8px;margin:0 0 16px">{{ .Token }}</p>
    <p style="margin:0;color:#3F7470;font-size:13px">코드는 10분 뒤 만료돼요. 직접 요청하지 않았다면 이 메일은 무시해 주세요.</p>
  </div>
  ```

## 도메인 (2026-09-30)
- `thebrawlguys.cloud` 구매 완료 (호스팅케이알). 네임서버는 호스팅케이알 기본 유지, 배포(D1) 시 A/CNAME 레코드로 Vercel 연결, HTTPS는 Vercel 자동
- 배포 시: Vercel 프로젝트 도메인 추가 → 호스팅케이알 DNS 레코드 → Supabase Redirect URLs에 `https://thebrawlguys.cloud` → `secrets.local.cfg`의 `auth.redirect_web`
