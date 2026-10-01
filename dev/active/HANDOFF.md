# 인수인계 — 다음 세션 시작점

**Last Updated:** 2026-10-01
**main:** `e96320a` (Phase 5 T1~T11 전부 병합, 1116 테스트·check-all 통과). GitHub push 반영.
**배포:** https://thebrawlguys.cloud — main `e96320a` 빌드(Vercel `cheorish/thebrawlguys`). 배포는 `scripts/deploy_web.sh`만. 루트 `vercel.json`이 Git 자동 배포를 끔(지우면 push마다 404 — 메모리 `vercel-git-push-overwrites-prod`)

새 세션은 이 파일 → `dev/active/{platform,phase-5,combat-depth}/*-context.md` → `*-tasks.md` 순으로 읽고 시작한다.
주의: 같은 main 폴더에서 다른 세션(combat-depth 등)이 동시에 작업할 수 있다 — 병합 전 `git status`와 `.git/MERGE_HEAD`를 확인하고, 남의 미커밋 변경은 사용자 확인 후 처리. 훅이 커밋 메시지를 오인하면 `git commit -F <고유 파일명>`.
사용자 규칙: 한국어 대화, .gd ≤200줄·함수 <40줄 모듈화(메모리 `modular-short-files`), 커밋 트레일러 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, `--no-verify` 금지(pre-commit 훅이 키 문자열 차단).

---

## 1. (기록) 병합 대기 브랜치 — ✅ 2026-09-30 21:00 세 개 모두 main 병합(812 테스트·check-all 통과), 재배포(Ready), push `749b3ec`

| 순서 | 브랜치 | 내용 | 테스트 | 예상 충돌 |
|---|---|---|---|---|
| 1 | `fix/phase4-review` | Phase 4 리뷰 수정 #1~#14 + 경기장 선택 레이아웃(카드 세로 중앙, 뒤로 좌하단·안내 우하단) | 748 | 없음(0c7a470 기반) |
| 2 | `feat/mobile-ui` | 폰/태블릿 UI 배율(DS-LAY-04), 세로 모바일 웹 "가로로 돌려주세요", 터치 감지 | 644 | `project.godot` autoload, `analytics.gd`, `login_layout.gd`, docs 표 |
| 3 | `feat/email-otp` | 이메일 6자리 코드 로그인(Supabase OTP), TextField·CodeInput(DS-CMP-17/18) | 680 | docs 3종, platform dev docs, `ds_gallery.gd`, `event_catalog.gd`, `tokens.gd`, `test_event_catalog.gd` — 대부분 목록 추가라 "양쪽 유지" |

병합 절차: 순서대로 `git merge --no-ff <branch>` → 충돌은 양쪽 유지 → 매번 `scripts/test.sh` + `scripts/check-all.sh` → 전부 끝나면 `scripts/deploy_web.sh` → `git push origin main`.
주의: 테스트 중 다른 Godot 프로세스가 54321 포트를 쓰면 `test_login_gate::test_desktop_with_keys_is_available`가 간헐 실패(재실행 시 통과).

## 2. 2026-10-01까지 끝난 것 (Phase 5 완료)
- 병합: phase5-sim · p5-cutin · p5-local2p · p5-charselect · p5-gear · p5-followups · p5-tutorial (+ 다른 세션의 링크 썸네일·앱 아이콘, defense review)
- Phase 5 T1~T11: 스타일·필살기 sim, 컷인, 로컬 2인(P2 필살기 G+H / 패드 Y+RB), 스타일 룩 A 장비(사용자 승인), 캐릭터 선택·P1~P4 모양 링, 트래킹(이벤트 스키마 6), 온보딩 튜토리얼
- 웹 로딩 화면 B(깊은 숲: `deploy/web_shell.html` + `assets/branding/boot-splash.png`), 경기마다 새 시드, 리플레이 -0.0 입력 버그 수정(해시 의도적 갱신)

## 3. 남은 작업 (우선순위)

1. 🧪 사용자 실기 확인: 게임패드 2개/한 키보드 2인 한 판, 폰 터치(캐릭터 선택·튜토리얼·필살기 = 공격 길게+가드), PS 패드 글리프
2. 설정 화면 + "모션 줄이기" 토글(`[accessibility] reduce_motion`, 지금은 키만 읽음) + settings_changed
3. 시각 다듬기: 경기 카메라에서 Knight 대검·Mage 구슬 가독성, 공격 중 검·지팡이 기울기, 튜토리얼 연습 상대 목숨 표시(99인데 3개로 보임), 봇 PlayerSlot 빈 공간, 데스크톱 초상이 조금 작아짐
4. 터치 튜토리얼 버튼 강조 링 — `touch_input.gd`(270줄) 먼저 분리
5. 튜토리얼 진행 상태가 기기(`user://`) 저장 → 계정 단위로 옮길지 결정
6. 🖼 사용자 확인 대기: Phase 4 경기장·아이템 룩(`dev/active/phase-4/evidence/`)
7. 부채: `game_config.gd` 278줄, `touch_input.gd` 270줄, `ds_gallery.gd` 388줄, `capture_evidence.gd`는 `-s` 모드에서 main/app 씬 못 엶, Amplitude 퍼널 대시보드 없음

## 4. 사용자가 해야 할 일 (Supabase / 외부)

- [x] 마이그레이션 0002·0003 실행 (2026-10-01 확인: special_hits·match_inputs 존재) — 안 하면 경기 기록 업로드 실패(`match_inputs` 테이블 없음 확인됨)
- [ ] Authentication → URL Configuration: Site URL = `https://thebrawlguys.cloud`, Redirect URLs = `https://thebrawlguys.cloud`, `https://thebrawlguys.cloud/**`, `https://thebrawlguys.vercel.app`, `https://thebrawlguys.vercel.app/**`, `http://127.0.0.1:54321/**`
- [ ] 이메일 로그인: Email provider 켜기 + 가입 허용, OTP 6자리·600초, Magic Link·Confirm signup 템플릿에 `{{ .Token }}`(템플릿 문구는 feat/email-otp의 platform-context.md), 커스텀 SMTP(Resend 등) — 기본 SMTP는 팀원 주소만
- [ ] 웹 Google 로그인 실사용 확인(강력 새로고침 후) — 가짜 코드로는 멈춤 수정 확인됨, 진짜 로그인은 미확인
- [ ] (선택) Amplitude MCP 커넥터 인증 — 이벤트 수신을 Claude가 직접 조회하려면 필요

## 5. 참고

- 키: `config/secrets.local.cfg`(gitignore, `scripts/set_secrets.sh`로 입력). 웹 빌드에 포함되는 공개 키만.
- 배포: `scripts/deploy_web.sh` (Godot 웹 export → `npx vercel deploy --prod`). `build/web/.env.local`은 `.vercelignore`로 업로드 제외.
- 분석: `supabase/queries/analysis.sql`, 전략 `docs/analytics-strategy.md`, 이벤트 명세 `docs/tracking-plan.md`.
