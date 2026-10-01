# TheBrawlGuys — 트래킹 플랜

> 버전 0.8 · 2026-10-01 (DDA·프로브 봇 트래킹 — `players[]`·`match_players` 봇 트래킹 열, `matches.dda_variant`, `match_events` `probe_stage`·`dda_adjusted`·`bot_intent`(0006) — `event_schema_version` 11) · 0.7 · 2026-10-01 (Phase 6 온라인 로비 — `online_lobby_viewed`·`room_created`·`room_joined`·`room_left`·`peer_connect_failed`, 셋업 `controller`에 `remote`, `screen_viewed.screen`에 `online` — `event_schema_version` 10) · 0.6 · 2026-10-01 (Phase 6 온라인 N1 — 온라인 경기 `match_ended`/`match_abandoned`·`matches`에 네트워크 요약 `net_host`·`rtt_p50`·`rtt_p95`·`corrections`·`disconnects`·`disconnect_reason`, `players[]`·`match_players.disconnect_reason`(0007), 호스트와 클라이언트가 같은 `match_id`, 클라이언트는 Supabase 행을 올리지 않음 — `event_schema_version` 9) · 0.5 · 2026-10-01 (combat-depth A/C 방어·복귀 추적 + analytics-ml Part 1 — 슬롯 요약·`match_players`에 방어·복귀 카운터 11개와 실력·상황 신호 17개(반응 틱·회피 성공·낙법 시도·DI 각도·텀블 생존·가장자리/고% 선택·팀 어시스트, 0004), `rule_selected.focused`, 원시 행 `perfect_guard` 대상·투사체 `owner` 행위자, 웹 `session_ended`(sendBeacon)·30분 세션 분리 — `event_schema_version` 8) · 0.4 · 2026-10-01 (Phase 5 T11 온보딩 튜토리얼 퍼널 — `tutorial_*` 4종, `screen_viewed.screen`에 `tutorial` — `event_schema_version` 6) · 0.3 · 2026-10-01 (Phase 5 캐릭터 선택 — `character_selected`, 캐릭터가 sim에 전달, 슬롯 요약 `character`/`style` — `event_schema_version` 5) · 0.2 · 2026-09-30 (A7 리플레이 로그·재현 헤더, A8 행동 피처·세션/로딩/결과/성능 이벤트 — 3)
> 상위: [`PRD.md`](./PRD.md) §5.8 (`PRD-DATA-03`, `PRD-DATA-04`) · 일정: [`PHASES.md`](./PHASES.md) Phase 4.0 · 문서 규칙: [`README.md`](./README.md)
>
> 이 문서는 **어떤 이벤트를, 어떤 속성으로, 어디에 보내는지**의 단일 원천(SSOT)이다.
> 코드의 `EventCatalog`는 이 표를 그대로 옮긴 것이다. 이벤트를 추가·변경할 때는 이 문서를 먼저 고치고 `EventCatalog`와 테스트를 맞춘다.

---

## 1. 원칙

| # | 원칙 | 의미 |
|---|---|---|
| T1 | **모든 이벤트는 결정에 쓰인다** | §6 "분석 질문 → 이벤트" 표에 연결되지 않는 이벤트는 만들지 않는다 |
| T2 | **입자도 분리** | Amplitude = 핵심 순간 + 경기 요약. 고빈도 행동(타격·가드·잡기·점프)은 Amplitude에 개별로 보내지 않고 `match_ended` 요약 속성 + Supabase `match_events` 원시 로그로 남긴다 |
| T3 | **sim은 모른다** | 트래킹은 렌더·앱 쪽 `MatchTelemetry`가 `World.state_view()["events"]`와 `ViewEvents`를 **소비만** 한다. sim·리플레이 해시는 트래킹 때문에 바뀌지 않는다 |
| T4 | **개인정보 최소** | 사용자 식별은 Supabase `uid`(= `user_id`)와 기기 UUID(`device_id`)뿐. 이메일·이름·IP 기반 위치·자유 입력 텍스트는 속성에 넣지 않는다 |
| T5 | **스키마 강제** | 카탈로그에 없는 이벤트나 필수 속성 누락은 debug 빌드에서 assert, 테스트에서 실패 |
| T6 | **수집 제외 환경** | headless, GUT 테스트, `ds_gallery`, 메뉴 배경 디오라마(봇 난투)에서는 보내지 않는다 |

**이름 규칙**: `snake_case`, `object_action` (과거형 동사). 속성도 `snake_case`. 열거형 값은 소문자 문자열.

**타입 표기**: `str` · `int` · `float` · `bool` · `enum(a|b)` · `list<T>` · `obj`

---

## 2. 전역 속성 (모든 Amplitude 이벤트)

`Analytics`가 자동으로 붙인다. 개별 이벤트 표에서는 반복하지 않는다.

| 속성 | 타입 | 값 / 출처 | Amplitude 필드 |
|---|---|---|---|
| `user_id` | str? | Supabase `auth.uid` (로그인 전·건너뛰기면 없음) | 최상위 `user_id` |
| `device_id` | str | `user://`에 저장한 UUID v4, 설치당 1개 | 최상위 `device_id` |
| `session_id` | int | 앱 세션 시작 시각(epoch ms). 백그라운드 30분 초과 후 복귀하면 새로 발급 | 최상위 `session_id` |
| `platform` | enum(windows\|macos\|linux\|android\|ios\|web) | `OS.get_name()` 정규화 | 최상위 `platform` |
| `os` | str | OS 이름 + 버전 (`OS.get_version()`) | 최상위 `os_name`/`os_version` |
| `build_version` | str | `application/config/version` + 커밋 짧은 해시 | 최상위 `app_version` |
| `locale` | str | `OS.get_locale()` (예: `ko_KR`) | 최상위 `language` |
| `quality` | enum(low\|medium\|high) | 현재 품질 단계 | `event_properties` |
| `input_device` | enum(keyboard\|gamepad\|touch) | P1의 마지막 입력 장치 | `event_properties` |
| `event_schema_version` | int | `EventCatalog.SCHEMA_VERSION` (현재 11 — 봇 트래킹: `players[]`·`match_players`에 `EventCatalog.BOT_TRACKING_KEYS`(§3.4.2), `matches.dda_variant`, `match_events` `probe_stage`·`dda_adjusted`·`bot_intent`(0006). 10 = Phase 6 온라인 로비 이벤트 5종(§3.3.2), 셋업 `controller`에 `remote`. 9 = 온라인 경기 네트워크 요약(`NetSummary.KEYS`, 온라인이면 필수·값은 null 가능)이 `match_ended`/`match_abandoned`·`matches`(0007)에, `disconnect_reason`이 `players[]`·`match_players`(0007)에, 한 온라인 경기의 모든 피어가 호스트의 `match_id`를 공유하고 Supabase 행은 호스트만 올림. 8 = 방어·복귀 카운터 11개와 실력·상황 신호 17개가 `match_ended.players[]`(필수, `EventCatalog.PLAYER_COMBAT_KEYS`)와 `match_players`(0004)에, `rule_selected.focused`, `match_events` 투사체 `actor_slot` = 소유자·`perfect_guard` `target_slot` = 막은 파이터. 7 = combat-depth D 경기 방식: `rule_selected`, 경기 이벤트 `rule`, `players[]` `team`·`score`, `matches.rule`·`match_players.team`·`score`(0004). 6 = 온보딩 튜토리얼. 5 = Phase 5 캐릭터 선택: `character_selected` is_bot·input_device, 캐릭터 id·스타일이 sim·슬롯 요약에 들어감. 4 = 필살기 이벤트·`special_hits` 열). 이벤트 이름·속성·Supabase 행 모양이 바뀔 때마다 올린다 (§7) | `event_properties` |

**사용자 속성** (Amplitude `user_properties`, `InstallInfo`가 `user://install.cfg`에 보관, A8):

| 속성 | 타입 | 값 |
|---|---|---|
| `first_seen_at` | str (ISO-8601 UTC) | 이 설치의 첫 실행 시각. 이후 바뀌지 않음 |
| `install_build` | str | 첫 실행 때의 `build_version` |
| `input_device_primary` | enum(keyboard\|gamepad\|touch) | 이 설치에서 경기를 가장 많이 한 입력 장치 (`match_started.input_device` 누적) |
| `viewport_class` | enum(phone\|tablet\|desktop) | 창 짧은 변(CSS px)·터치로 분류 (design.md DS-LAY-04). `app_opened`부터 붙고 창이 바뀌면 갱신 | `event_properties` |
| `orientation` | enum(portrait\|landscape) | 창 가로·세로 | `event_properties` |
| `ui_scale` | float | 적용한 2D UI 배율 (`content_scale_factor`, desktop 1.0) | `event_properties` |

---

## 3. Amplitude 이벤트 카탈로그

목적지 열: **A** = Amplitude, **S** = Supabase. 요구사항은 모두 `PRD-DATA-03` (Supabase 쪽은 `PRD-DATA-04`).

### 3.1 앱·세션

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `app_opened` | 앱 셸 `_ready` (콜드 스타트) 또는 백그라운드 복귀로 새 세션 발급 | `cold_start: bool` | `launch_ms: int` (프로세스 시작 → 첫 화면) | A | 4.0 |
| `app_backgrounded` | 포커스 잃음 / 모바일 일시정지 / 웹 탭 숨김 | `screen: str`, `session_seconds: float` | `in_match: bool` | A | 4.0 |
| `app_closed` | 정상 종료 요청 (`NOTIFICATION_WM_CLOSE_REQUEST`) — 전송 후 flush | `screen: str`, `session_seconds: float`, `matches_played: int` | — | A | 4.0 |
| `perf_sampled` | 경기 종료(`match_ended`) 또는 이탈(`match_abandoned`) 직후 1회 (`PerfSampler`, 경기 동안 렌더 프레임 누적) — `match_id`로 경기와 조인 | `match_id: str`, `fps_p5: float` (느린 쪽 5% 프레임의 fps, nearest rank), `fps_p50: float`, `spike_count: int` (중앙값의 2배를 넘는 프레임 수), `frame_count: int` | — | A | 4.0 (A8) |
| `session_started` | 앱 세션 시작 (Analytics 초기화 직후, `app_opened` 다음) | — | — | A | 4.0 (A8) |
| `session_ended` | 앱 종료 요청, 모바일 일시정지, 웹 탭 숨김·페이지 닫힘 (`visibilitychange`·`pagehide`, `WebLifecycle` → `navigator.sendBeacon`) — 백그라운드로 갈 때마다 1회, 돌아오면 `session_started`. 30분 넘게 떠나 있었으면 `session_id`를 새로 받고 `app_opened`(`cold_start` false)부터 (스키마 8) | `duration_s: float`, `matches: int` (세션 중 `match_started` 수), `last_screen: str` (마지막 `screen_viewed.screen`) | — | A | 4.0 (A8) |
| `load_timed` | 체감 로딩 구간 끝 (세션당 단계별 1회) | `stage: enum(boot_to_login\|login_to_title\|match_load)`, `ms: int` — `boot_to_login` = 엔진 시작 → 첫 로그인 화면, `login_to_title` = 첫 로그인 화면 → 첫 타이틀(세션 복원 포함), `match_load` = 경기 씬 `_ready` 시작 → 첫 틱 | — | A | 4.0 (A8) |

### 3.2 로그인 (`PRD-AUTH-01`)

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `login_viewed` | 로그인 화면 표시 (세션 복원 실패 포함) | `reason: enum(first_run\|no_session\|refresh_failed\|logged_out\|online)` (`online` = 온라인 메뉴의 로그인 안내에서 옴, 스키마 10) | — | A | 4.0 |
| `login_started` | Google 버튼 클릭 / 이메일은 새 주소로 첫 코드 요청이 서버로 나갈 때 (재전송은 `email_code_resent`) | `provider: enum(google\|email)`, `flow: enum(web_redirect\|desktop_loopback)` | — | A | 4.0 |
| `login_completed` | 토큰 교환 성공 / 이메일 코드 확인 성공 | `provider: enum(google\|email)`, `flow: enum(...)`, `duration_ms: int` (started → completed), `is_new_user: bool` | — | A | 4.0 |
| `login_failed` | 교환 실패·취소·타임아웃 / 이메일 요청이 서버에서 실패 | `provider: enum(google\|email)`, `flow: enum(...)`, `reason: enum(cancelled\|timeout\|exchange_error\|network\|port_in_use\|config_missing` · 이메일: `send_rate_limited\|send_invalid_email\|send_error\|verify_wrong_code\|verify_rate_limited\|verify_error)` | `http_status: int` | A | 4.0 |
| `login_skipped` | 모바일 debug 빌드 "건너뛰기" | — | — | A | 4.0 |
| `email_code_requested` | "인증코드 받기"·"코드 다시 받기" 결과 (요청 전 거절 포함) | `result: enum(ok\|rate_limited\|invalid_email\|error)` | — | A | 4.0 |
| `email_code_resent` | 같은 주소로 코드 재전송 요청이 서버로 나감 (쿨다운 뒤) | — | — | A | 4.0 |
| `email_code_verified` | 코드 확인 성공 (`login_completed` 직전) | `attempts: int` (이번 코드로 확인 요청한 횟수) | — | A | 4.0 |
| `session_restored` | 저장된 refresh token으로 갱신 성공 → 로그인 화면 생략 | `session_age_days: float` | — | A | 4.0 |
| `logout` | 설정에서 로그아웃 | — | — | A | 4.0 |

로그인 완료 순간 `Analytics`는 `user_id`를 설정하고, 그 이전 이벤트는 같은 `device_id`로 Amplitude가 병합한다.

이메일 로그인 (T4): 이메일 주소와 인증코드는 **어떤 속성에도 넣지 않는다** — 결과 enum과 횟수만 보낸다. `test_email_otp`가 모든 이메일 흐름 이벤트 속성에 `@`·코드·주소 일부가 없는지 검사한다. 요청 전 거절(형식 오류·쿨다운)은 `email_code_requested`에만 남고 `login_failed`는 서버 응답 실패만 센다.

### 3.3 메뉴 퍼널 (`PRD-UI-02`)

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `screen_viewed` | 화면 스택 전환 완료 | `screen: enum(login\|title\|mode\|rule\|character\|arena\|online\|lobby\|match\|tutorial\|result\|settings)` (`online` = 온라인 메뉴, `lobby` = 대기실, 스키마 10) | `from_screen: str` (이전 화면), `dwell_ms_prev: int` (이전 화면 체류 ms) — `ScreenRouter`가 항상 채운다 | A | 4.0 |
| `mode_selected` | 모드 확정 | `mode: enum(bot\|local_2p\|online)` | — | A | 4.0 |
| `rule_selected` | 경기 방식 화면에서 확정 (뒤로 왔다가 다시 고르면 다시 보냄) | `rule: enum(stock\|team\|timed)` | `browse_count: int` (확정 전 옮겨 본 횟수), `focused: list<str>` (포커스를 받은 방식, 처음 받은 순서로 중복 없이 — 기본값이 첫째, 고려한 후보 vs 선택. 스키마 8) | A | 5 (스키마 7) |
| `character_selected` | 캐릭터 선택 화면에서 모든 사람이 확정한 순간, 슬롯마다 1번 (봇 포함 — 봇 캐릭터는 이때 경기 시드로 뽑힘). 경기장 화면에서 뒤로 와 같은 조합으로 다시 확정하면 다시 보내지 않는다(조합이 바뀌면 새로 보냄) | `slot: int`, `character: enum(barbarian\|rogue\|knight\|mage)`, `style: enum(boxer\|weapon\|ranged)`, `is_bot: bool`, `input_device: str` (사람 = 확정 때 쓴 장치 `keyboard`\|`gamepad`\|`touch`, 마우스 클릭은 `keyboard`, 봇 = `bot`) | `browse_count: int` (사람만, 확정 전 넘겨본 카드 수) | A | 5 (스키마 5) |
| `arena_selected` | 경기장 확정 | `arena: enum(lakeside_camp\|log_bridge\|mushroom_forest\|foggy_forest)` | `browse_count: int` | A | 4 |
| `select_cancelled` | 선택 화면에서 뒤로 | `screen: enum(mode\|rule\|character\|arena)` | `dwell_ms: int` | A | 4.0 |

#### 3.3.1 온보딩 튜토리얼 퍼널 (`PRD-UI-02`, Phase 5 T11)

기기에서 처음 로그인하면(세션 복원 포함, `user://settings.cfg` `[onboarding] tutorial`이 비어 있을 때) 타이틀 위에 연습 경기장 튜토리얼이 열린다. 타이틀의 "튜토리얼 다시 보기"로 언제든 다시 할 수 있다. 미션 순서(`step` 값, 바꾸지 않고 추가만 한다): `move` → `jump` → `light_attack` → `heavy_attack` → `guard` → `grab_throw` → `item` → `special`. `index`는 1부터(카드의 "n/8"). 튜토리얼은 경기가 아니다 — `match_*`·`stock_lost` 등 경기 이벤트와 Supabase 행을 보내지 않는다. 성공 판정은 렌더 쪽에서 sim 뷰·이벤트만 읽는다(원칙 T3).

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `tutorial_started` | 튜토리얼 화면이 첫 미션을 연 순간 | `source: enum(first_login\|replay)` | `step_count: int` (미션 수, 지금 8), `input_device: enum(keyboard\|gamepad\|touch)` (시작 때 안내한 장치) | A | 5 (스키마 6) |
| `tutorial_step_completed` | 한 미션의 마지막 목표를 성공한 순간 (잡기·던지기, 줍기·쓰기처럼 목표가 둘이면 둘 다) | `step: str` (위 순서의 id), `index: int` (1..8), `ms_in_step: int` (미션을 연 뒤 성공까지 ms, 건너뛰기 확인창이 떠 있던 시간 포함), `attempts: int` (그 미션의 버튼을 새로 누른 횟수, 최소 1로 보고 — 이동은 중립에서 벗어난 횟수라 스틱 떨림도 센다, 필살기는 강+가드가 함께 눌린 횟수) | — | A | 5 (스키마 6) |
| `tutorial_skipped` | 건너뛰기 확인창에서 "건너뛰기"를 누른 순간 (버튼·Esc·패드 Start로 연 확인창) | `step: str` (그때 진행 중이던 미션 — 성공 피드백 "좋아요!" 1.2초 동안이면 다음 미션, 이때 `ms_in_step` 0), `index: int` | `ms_in_step: int`, `total_ms: int` | A | 5 (스키마 6) |
| `tutorial_completed` | 마지막 미션(`special`)을 성공한 순간 | `total_ms: int` (시작부터) | `step_count: int` | A | 5 (스키마 6) |

퍼널: `tutorial_started` → `tutorial_step_completed` (`index` 1..8) → `tutorial_completed`, 이탈 지점 = `tutorial_skipped.step` 또는 마지막 `tutorial_step_completed` 뒤 `session_ended`. 완료·건너뛰기는 기기에 저장되어 첫 로그인 튜토리얼은 한 번만 열린다(다시 보기에서 건너뛰어도 이전 완료는 유지).

#### 3.3.2 온라인 로비 (`PRD-NET-03`, Phase 6, 스키마 10)

온라인은 WebRTC P2P(방장 = 피어 1, 별 구조)다. 방 코드는 Supabase `rooms`(0005)로 찾고, 시그널링은 Supabase Realtime 브로드캐스트 채널 `realtime:room:<코드>`로 한다. **방 코드는 Amplitude로 보내지 않는다.** 퍼널: `mode_selected{online}` → `online_lobby_viewed` → `room_created`(방장) / `room_joined` → (`peer_connect_failed`) → `room_left` 또는 `match_started{mode: online}`(넷코드 연결 후).

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `online_lobby_viewed` | 타이틀 "온라인"으로 온라인 메뉴가 열린 순간 | `signed_in: bool`, `supported: bool` (이 빌드에서 WebRTC 가능 — 웹 true, 플러그인 없는 데스크톱 false) | — | A | 6 |
| `room_created` | `rooms` 행 insert 성공 (방장) | `attempts: int` (코드 충돌 재시도 포함 시도 수, 1..5), `rule: enum(stock\|team\|timed)`, `arena: str` | — | A | 6 |
| `room_joined` | Realtime 채널 join 성공 = 대기실 표시 (방장·참가자 모두) | `is_host: bool`, `player_count: int` (그 순간 대기실 사람 수, 참가자는 방장 상태를 받기 전이라 0일 수 있음) | — | A | 6 |
| `room_left` | 대기실에서 나감 (join 뒤에만) | `reason: enum(back\|host_left\|full\|error\|started)`, `is_host: bool`, `dwell_ms: int` (대기실 체류) | — | A | 6 |
| `peer_connect_failed` | 연결 실패 1회 | `stage: enum(signaling\|ice\|timeout)` (signaling = Realtime 소켓·join·하트비트 실패 또는 방장이 12초 안에 id를 주지 않음, ice = WebRTC 연결 실패, timeout = 20초 안에 데이터 채널이 안 열림), `is_host: bool` | `peer_id: int` | A | 6 |

### 3.4 경기

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `match_started` | 첫 틱 진입 | `match_id: str` (uuid), `mode: enum(...)`, `rule: enum(stock\|team\|timed)` (스키마 7), `arena: enum(...)`, `player_count: int`, `bot_count: int`, `characters: list<str>` (슬롯 순), `input_device: str` (로컬 슬롯), `loss_streak: int` (이 앱 세션에서 로컬 플레이어의 연속 패배 수, A8) | `user_match_seq: int` (이 설치에서 해당 유저의 n번째 경기, A7) | A + S(`matches`) | 4.0 |
| `match_ended` | 승패 확정 (스톡 0 · 팀 전멸 · 시간 종료/서든 데스) | `match_id: str`, `rule` (스키마 7), `result: enum(win\|loss\|draw)` (P1 기준, 팀전은 P1 팀이 이기면 win), `winner_slot: int`, `duration_s: float`, `duration_ticks: int`, `players: list<obj>` (§3.4.1) · **온라인(`mode` = `online`)만, 스키마 9**: `net_host: bool`, `rtt_p50`/`rtt_p95: float?` (왕복 ms, 샘플 없으면 null), `corrections: int` (클라이언트 자기 캐릭터 예측 보정 수, 호스트 0), `disconnects: int`, `disconnect_reason: str?` (마지막 끊김: 호스트 `timeout`\|`left`, 클라이언트 `host_left`\|`timeout`\|`room_full`) — `match_abandoned`도 같음 | `comeback: bool` (P1이 스톡 열세에서 승리) | A + S(`matches`·`match_players`) | 4.0 |
| `match_abandoned` | 결과 전 재시작·메뉴 이탈·앱 종료 | `match_id: str`, `mode`, `rule` (스키마 7), `arena`, `duration_s: float`, `stock_diff: int` (로컬 스톡 − 가장 많은 상대 스톡, A8), `ms_since_last_ringout: int` (마지막 링아웃 후 경과, 없으면 -1, A8) | — | A + S | 4.0 |
| `result_viewed` | 결과 배너가 닫힐 때 (결과 1회당 1번, A8) | `match_id: str`, `dwell_ms: int` (결과 표시 → 다음 행동), `next: enum(rematch\|menu\|quit)` | — | A | 4.0 (A8) |
| `rematch_clicked` | 결과 화면 "다시" | `match_id: str` (끝난 경기) | — | A | 4.0 |

#### 3.4.1 `match_ended.players[]` 슬롯 요약 (= Supabase `match_players` 행)

| 필드 | 타입 | 설명 | Phase |
|---|---|---|---|
| `slot` | int | 0부터 | 4.0 |
| `is_bot` | bool | | 4.0 |
| `character` / `style` | str | 캐릭터 id(`barbarian`\|`rogue`\|`knight`\|`mage`, 캐릭터를 안 고른 경기 = `""` 클래식) / 스타일(`boxer`\|`weapon`\|`ranged`, 클래식 = `classic`). 스키마 5부터 `match_ended.players[]`에도 들어가 스타일별 요약(Q1·Q13)을 Amplitude에서 바로 볼 수 있다. 스키마 4 이하 `match_players.character`는 슬롯 고정 모델 이름(`Knight` 등)이고 sim은 클래식이었다 | 4.0 / 5 |
| `input_device` | str | 로컬 슬롯은 경기 시작 때 그 플레이어의 장치: 패드를 받았으면 `gamepad`, 아니면 P1은 플랫폼 기본(`keyboard`\|`touch`), 로컬 2인 P2는 `keyboard`. 봇은 `bot` (스키마 변경 없음, 2026-09-30 로컬 2인) | 4.0 |
| `result` | enum(win\|loss\|draw) | | 4.0 |
| `stocks_left` | int | | 4.0 |
| `damage_dealt` / `damage_taken` | float | % 합계 | 4.0 |
| `hits` / `guard_hits` / `grabs` / `throws` | int | 고빈도 행동 집계 | 4.0 |
| `whiffs` | int | 헛스윙 (view `attack_kind` 전이 중 hit 없음) | 4.0 |
| `jumps` | int | `ViewEvents` `jumped` 수 | 4.0 |
| `ringouts_scored` / `self_destructs` | int | 마지막 가격자로서의 링아웃 / 가격자 없는 낙사 | 4.0 |
| `team` | int? | 팀전만: 0 = 팀 1(P1·P3), 1 = 팀 2(P2·P4). 다른 방식은 키 없음 (Supabase `match_players.team`, 0004) | 5 (스키마 7) |
| `score` | int? | 시간제만: 경기 끝 점수(크레딧 링아웃 +1, 자멸 −1, sim `ModeState`). 다른 방식은 키 없음 (Supabase `match_players.score`, 0004) | 5 (스키마 7) |
| `items_used` | int | 줍기 후 휘두름·투척 | 4.0 |
| `hits_taken` / `di_inputs` | int | 맞은 클린 히트(`hit` 대상, 가드 제외 = 띄워짐) / 그중 DI 틱(히트스톱이 끝난 첫 틱, sim `LaunchInfluence`가 스틱을 읽는 틱)에 스틱이 중립이 아니었던 수(길이 ≥ 0.3) | 5 (스키마 8) |
| `di_perp_avg` | float? | DI 틱의 스틱이 발사 방향에 수직인 비율(0 = 나란하거나 중립, 1 = 완전히 옆 = 최대 DI)의 평균. view에 속도가 없어 발사 방향 = 그 틱의 수평 이동 방향(이미 최대 `di_max_deg`만큼 꺾인 뒤라 오차 작음). 측정한 발사가 없으면 null (`LaunchFeatures`) | 5 (스키마 8) |
| `tumbles` / `tumbles_survived` | int | 강한 발사로 텀블한 수(view `tumbling` 시작) / 그 텀블이 같은 목숨 안에서 끝난 수 (링아웃 아님) | 5 (스키마 8) |
| `threats_faced` / `reactions` / `reaction_ticks_avg` | int / int / float? | 상대(팀전 아군 제외)가 3 m 안에서 공격을 시작한 수(대기 중인 위협은 하나, 30틱 지나면 새 위협) / 그 뒤 1~30틱 안에 가드를 새로 누른 수(가드·회피 모두 가드 누름으로 시작) / 그 틱 수 평균(없으면 null) (`ReactionFeatures`) | 5 (스키마 8) |
| `roll_evades` | int | 회피(state DODGE, 무적) 중 3 m 안 상대의 공격이 진행됐고 그 공격이 끝날 때까지 나를 맞히지 못한 수 — 방어 결과 4종 = `guards`(가드 성공) · `perfect_guards` · `roll_evades` · `guard_breaks` | 5 (스키마 8) |
| `tech_attempts` | int | 텀블 중 가드를 누른 텀블 수 (성공 = `techs`) | 5 (스키마 8) |
| `edge_guard_presses` / `edge_attack_presses` / `edge_dodges` | int | 경기장 반경 80% 밖(직전 view)에서 가드 누름 / 약·강 누름(틱당 1) / 회피 (`DangerFeatures`) | 5 (스키마 8) |
| `high_dmg_guard_presses` / `high_dmg_attack_presses` / `high_dmg_dodges` / `high_dmg_ticks` | int | 대미지 100% 이상일 때 같은 선택 / 그 상태로 살아 있던 틱 (분모) | 5 (스키마 8) |
| `team_assists` | int | 팀전: 내가 맞힌(`hit`·`special_hit`) 상대를 3초(`StockLoss.WINDOW_TICKS`) 안에 아군이 링아웃시킨 수 (링아웃 크레딧이 그 아군). 다른 방식은 0 (`AssistFeatures`) | 5 (스키마 8) |
| `dodges_roll` / `dodges_air` | int | sim `dodge` `kind` 별 (구르기 / 공중 회피) | 5 (스키마 8) |
| `perfect_guards` | int | sim `perfect_guard`의 `fighter` (막은 쪽) | 5 (스키마 8) |
| `guard_breaks` / `guard_breaks_caused` | int | sim `guard_break` 당한 수 / 깬 수 — 깬 쪽은 피해자가 60틱 안에 마지막으로 막은 `guard_hit`의 공격자(없으면 가드를 오래 쥐고 있다 바닥난 것, 크레딧 없음). 원시 행 payload `attacker_slot`도 같은 규칙 | 5 (스키마 8) |
| `knockdowns` / `techs` | int | 텀블 착지에서 낙법 없이 다운 (`knockdown`) / 낙법 (`tech`, 제자리·구르기 합) — 낙법률 = `techs / (techs + knockdowns)` | 5 (스키마 8) |
| `getups_stand` / `getups_roll` / `getups_attack` | int | 다운에서 일어난 방식 (sim `getup` `kind`) | 5 (스키마 8) |
| `falls_by_gimmick` | int | 기믹이 원인인 스톡 소모 | 4 |
| `specials` / `special_hits` | int | 필살기 발동 수 (`special_start`) / 필살기 적중 수 (`special_hit` 원시 이벤트 수 = 대상 × 타수, 돌진 연타의 다단 히트는 한 타마다 센다) | 5 |
| `controller` / `bot_difficulty` / `bot_params_hash` | str / str? / int? | `local`\|`bot`\|`remote` · 봇 난이도(기본 `normal`) · Bot 설정 그룹 해시 (Supabase 행만, A7) | 4.0 |

**행동 피처 (A8, `MatchFeatures.COLUMNS`, analytics-strategy §3.2)** — `match_ended.players[]`와 `match_players` 열에 같은 이름으로 들어간다. 비율은 0~1, "생존 틱"은 KO가 아닌 틱.

| 필드 | 타입 | 정의 |
|---|---|---|
| `press_light` / `press_heavy` / `press_guard` / `press_grab` / `press_jump` | int | 버튼을 새로 누른 횟수 (눌린 상태 유지는 1회) |
| `press_special` | int | 필살기 입력(강+가드 동시 = X+C)이 새로 성립한 횟수. 두 버튼은 `press_heavy`·`press_guard`에도 각각 센다 (Phase 5, 그 전 빌드는 0) |
| `inputs_per_min` | float | 위 누름 합계 / 경기 분 |
| `direction_changes` | int | 8방향 스틱 방향이 바뀐 횟수 (중립은 방향이 아님) |
| `mash_ratio` | float | 같은 버튼을 10틱(기본 콤보 버퍼) 안에 다시 누른 비율 |
| `guard_hold_ratio` | float | 가드를 누르고 있던 틱 / 전체 틱 |
| `idle_gaps` | int | 5초 이상 완전 중립 입력 구간 수 (자리 비움 vs 포기) |
| `hit_accuracy` | float? | `hits / (hits + whiffs)`, 휘두른 적 없으면 null |
| `max_combo` | int | 같은 상대가 히트스턴에서 풀리기 전 연속 적중의 최대 |
| `damage_per_min` | float | `damage_dealt` / 경기 분 |
| `distance_travelled` | float | 한 목숨 안에서 이동한 거리 합 (m) |
| `avg_nearest_opponent_dist` | float? | 생존 틱마다 가장 가까운 살아 있는 상대까지 거리의 평균 (m) |
| `edge_time_ratio` | float | 경기장 반경 80% 밖에 있던 생존 틱 비율 |
| `air_time_ratio` | float | 공중에 있던 생존 틱 비율 |
| `item_hold_ticks` | obj | 아이템 종류별 들고 있던 틱 `{"bat": n, ...}` |
| `first_item_tick` | int? | 처음 아이템을 주운 틱 (없으면 null) |
| `contested_pickups` | int | 주울 때 살아 있는 상대가 2 m 안에 있던 횟수 |
| `first_blood` | bool | 경기 첫 링아웃의 가격자 |
| `comeback_win` | bool | 한 번이라도 스톡 1개 이상 뒤진 뒤 승리 |

#### 3.4.2 봇 트래킹 열 (스키마 11, `EventCatalog.BOT_TRACKING_KEYS`, 마이그레이션 0006, `PRD-BOT-04`)

모든 `players[]` 항목·`match_players` 행에 항상 실린다 (해당 없으면 null). 값은 `BotSquad.slot_summary`.

| 키 | 타입 | 정의 |
|---|---|---|
| `bot_d_start` · `bot_d_mean` · `bot_d_end` | float? | 봇의 난이도 다이얼 d (0–1): 경기 시작, 틱 평균, 끝. 사람은 null |
| `dda_adjustments` | int? | DDA가 이 봇의 d를 옮긴 횟수 (봇만) |
| `probe_target_slot` | int? | 프로브한 봇의 행에만: 프로브 대상(사람) 슬롯 |
| `probe_features` | obj? | 프로브 피처 `{react_ticks, response_rate, dodge_rate, tech_rate, punish_rate, damage_share, attack_rate, edge_share}` (`ProbeObserver.FEATURES`) |
| `probe_estimate` | float? | 프로브 피처로 낸 실력 추정 d (실력 추정기 모델) |
| `skill_rating` | float? | 사람의 행에만: 이 경기 전 기기 실력 레이팅 (미평가면 null) |

`bot_difficulty`는 봇의 시작 d에 가장 가까운 프리셋 이름(`slow` 0.2 / `normal` 0.5 / `busy` 0.8), `bot_params_hash`는 시작 `BotSkill` 해시. `matches.dda_variant`(`on`|`off`, 사람 없으면 null)는 A/B 변형.

### 3.5 전투 핵심

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `stock_lost` | sim `ringout` | `match_id: str`, `victim_slot: int`, `stocks_left: int`, `damage_at_death: float`, `cause: enum(knockback\|gimmick\|self)`, `attacker_slot: int` (-1 = 없음), `angle_deg: float` (경기장 중심 기준, 0° = +x 동, 90° = −z 북), `zone: str` (8방위 섹터 `n`·`ne`… 또는 경기장 안쪽으로 떨어지면 `below`) | `last_hit_attack: str`, `last_hit_ms_ago: int`, `item: str` | A (+ S 원시 `ringout`) | 4.0 (구역은 4) |
| `gauge_full` | sim `gauge_full` (필살기 게이지 100% 도달) | `match_id: str`, `slot: int`, `character: str` (캐릭터 id, 클래식 `""`), `match_time_s: float` | — | A (+ S 원시) | 5 |
| `special_used` | sim `special_start` | `match_id: str`, `slot: int`, `character: str`, `special: str` (필살기 id), `ms_since_full: int` (게이지가 찬 뒤 살아 있던 시간 — KO 상태로 보낸 시간은 뺀다, 모르면 -1), `target_damage: float` (가장 가까운 살아 있는 상대 %) | — | A (+ S) | 5 |
| `special_hit` | sim `special_hit` (발동 1회당 1번 — 첫 적중으로 열고 판정 뒤 발행) | `match_id: str`, `slot: int`, `character: str`, `special: str`, `targets_hit: int` (이 발동이 맞힌 서로 다른 대상 수), `target_slot: int` (첫 대상), `caused_ringout: bool` | — | A (+ S 원시 전부) | 5 |

`attacker_slot`은 피해자에게 마지막으로 `hit`을 넣은 슬롯이다 (링아웃 전 `ringout_credit_s` 안, config). 없으면 `cause = self`.
`caused_ringout`은 적중 후 같은 창(`StockLoss.WINDOW_TICKS`, 180틱) 안에 맞은 대상이 링아웃되고 그 링아웃이 시전자에게 크레딧될 때(`stock_lost.attacker_slot`과 같은 마지막 가격자 규칙 — 기믹이나 다른 플레이어의 나중 타격이면 false) true — 판정 후 지연 발행한다: 대상이 링아웃되면 즉시(true), 아니면 창이 지나거나 같은 슬롯의 다음 필살기가 시작되거나 경기가 끝날 때(false). sim은 한 틱의 타격을 모두 낸 뒤 링아웃을 낸다(`Rules.apply`가 마지막)라 같은 틱 링아웃도 맞게 잡힌다(`test_special_ringout`). 구현 `SpecialTelemetry`.

### 3.6 아이템

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `item_picked_up` | sim `item_pickup` (사람 슬롯만, 봇은 요약에만) | `match_id: str`, `slot: int`, `item: enum(bat\|bomb\|rock)`, `ms_since_spawn: int`, `contested: bool` (다른 파이터가 2 m 안) | — | A (+ S) | 4.0 |
| `item_used` | 방망이 휘두름 / `item_throw` / 폭탄 `explosion` | `match_id: str`, `slot: int`, `item: enum(...)`, `use: enum(swing\|throw\|explode)` | `uses_left: int` | A (+ S) | 4.0 |
| `item_hit` | 아이템 판정으로 `hit`·`guard_hit` 발생 | `match_id: str`, `slot: int`, `item: enum(...)`, `target_slot: int`, `knockback: float`, `guarded: bool` | — | A (+ S) | 4.0 |

### 3.7 경기장 기믹 (`PRD-ARENA-01~04`)

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `gimmick_triggered` | sim 기믹 이벤트의 **첫 발생** (파이터·기믹 쌍당, 쿨다운은 config) | `match_id: str`, `arena: str`, `kind: enum(burn\|platform_break\|bounce\|fog)`, `victim_slot: int` (-1 = 환경 전체) | `damage: float` | A (+ S 원시 전부) | 4 |
| `gimmick_ringout` | `stock_lost.cause = gimmick`과 같은 순간 | `match_id: str`, `arena: str`, `kind: enum(...)`, `victim_slot: int` | — | A | 4 |

### 3.8 설정·입력

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `settings_changed` | 설정 값 저장 (key 예: `language`, `hud.key_hints`) | `key: str`, `old_value: str`, `new_value: str` | — | A | 4.0 (설정 화면은 6) |
| `quality_changed` | 품질 단계 변경 (수동·자동) | `from: enum(...)`, `to: enum(...)`, `auto: bool` | `fps_avg_before: float` | A | 4.0 |
| `input_device_changed` | P1 입력 장치 전환 | `from: str`, `to: str`, `screen: str` | — | A | 4.0 |
| `touch_layout_changed` | 터치 레이아웃·크기 변경 | `layout: int`, `button_scale: float` | — | A | 4.0 (편집은 6) |

### 3.9 오류

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `net_error` | Supabase·Amplitude·로비 HTTP 실패 (재시도를 포기할 때 1회) | `endpoint: enum(auth\|rest\|amplitude\|lobby)`, `status: int` (0 = 연결 실패), `retries: int` | `queue_size: int` | A (Amplitude 자신의 실패는 다음 성공 배치에 포함) | 4.0 |

---

## 4. Supabase 원시 테이블 (`PRD-DATA-04`)

마이그레이션: `supabase/migrations/0001_match_telemetry.sql` → `0002_replay_and_features.sql` → `0003_special_hits.sql` → `0004_match_rules.sql` → `0005_rooms.sql` → `0006_bot_tracking.sql` → `0007_online_stats.sql` (순서대로; 0005·0006·0007은 서로 독립). **스키마 11 빌드는 모든 `matches` 행에 `dda_variant`, 모든 `match_players` 행에 봇 트래킹 열(§3.4.2)을 보내므로 0006 실행 전에는 경기 업로드 전체가 거절된다.** 온라인 경기는 **호스트만** `matches`·`match_players`·`match_events`·`match_inputs`를 올린다(권위 있는 쪽, 입력 로그가 리플레이됨). 클라이언트는 Amplitude 이벤트만 같은 `match_id`로 보낸다. 0007 전에는 온라인 경기 업로드만 거절되고 오프라인 경기는 영향 없음. **스키마 8 빌드는 모든 `match_players` 행에 방어·복귀 열(0004)을 보내므로 0004를 실행하기 전에는 모든 경기 업로드가 `matches` 행만 남기고 거절된다** (`match_players`부터 실패하면 `match_events`·`match_inputs`도 안 올라감). `matches.rule`·`team`·`score`는 여전히 팀전·시간제에서만 보낸다. 모든 테이블은 RLS로 **본인 `user_id` 행만** insert/select 하고 anon은 막는다.

### 4.1 테이블

| 테이블 | 열 | 설명 |
|---|---|---|
| `profiles` | `id uuid pk = auth.uid`, `display_name text`, `created_at timestamptz` | 첫 로그인 시 생성 |
| `matches` | `id uuid pk`, `user_id uuid`, `mode text`, `arena text`, `player_count int`, `seed bigint`, `started_at timestamptz`, `duration_ticks int`, `winner_slot int`, `result text`, `build_version text`, `platform text` · **재현 헤더 (0002)**: `config_fingerprint bigint` (sim 그룹 `GameConfig.fingerprint()`), `sim_version smallint` (`World.SNAPSHOT_VERSION`), `event_schema_version smallint` (`EventCatalog.SCHEMA_VERSION`), `final_state_hash bigint` (추적 종료 시 `World.state_hash()`), `session_id bigint` (Amplitude 세션), `user_match_seq int` (이 설치에서 해당 유저의 n번째 경기), `config_variant text` (기본 `control`) · **0007 (온라인만)**: `net_host bool`, `rtt_p50 real`, `rtt_p95 real`, `corrections int`, `disconnects int`, `disconnect_reason text` · **0004**: `rule text` (`stock`\|`team`\|`timed`, 기본 `stock` — `mode`는 조작 모드 `bot`\|`local_2p`\|`online` 그대로) | 경기 1행. 경기 종료(`match_ended`/`match_abandoned`) 후 insert |
| `match_players` | `match_id uuid fk`, `slot int`, `is_bot bool`, `character text`, `style text`, `input_device text`, `result text`, `stocks_left int`, `damage_dealt real`, `damage_taken real`, `hits int`, `guards int`, `grabs int`, `jumps int`, `whiffs int`, `ringouts_scored int`, `falls int`, `falls_by_gimmick int`, `specials int`, `items_used int` · **0003**: `special_hits int` · **0004**: `team smallint` (팀전만), `score int` (시간제만), 방어·복귀 `int not null default 0` 11열 (`hits_taken`, `dodges_roll`, `dodges_air`, `perfect_guards`, `guard_breaks`, `guard_breaks_caused`, `knockdowns`, `techs`, `getups_stand`, `getups_roll`, `getups_attack`), 실력·상황 17열 (`threats_faced`, `reactions`, `reaction_ticks_avg real`, `roll_evades`, `tech_attempts`, `di_inputs`, `di_perp_avg real`, `tumbles`, `tumbles_survived`, `edge_*` 3, `high_dmg_*` 4, `team_assists`, §3.4.1) · **0002**: `controller text` (`local`\|`bot`\|`remote`), `bot_difficulty text` (봇만, 기본 `normal`), `bot_params_hash bigint` (봇만, Bot 설정 그룹 해시) · **0007 (온라인만)**: `disconnect_reason text` (그 슬롯 플레이어가 끊긴 이유 `timeout`\|`left`, 없으면 null) · **A8 행동 피처 열** (§3.4.1 표, `item_hold_ticks`는 jsonb) · pk(`match_id`, `slot`) | §3.4.1 요약의 저장 형태 |
| `match_events` | `id bigserial pk`, `match_id uuid fk`, `tick int`, `type text`, `actor_slot int`, `target_slot int`, `payload jsonb` · 인덱스(`match_id`, `type`) | 원시 행동 로그. 경기 종료 시 500행 청크로 insert |
| `match_inputs` (0002) | `match_id uuid fk`, `slot smallint`, `encoding text`, `frames text`, `frame_count int` · pk(`match_id`, `slot`) | **리플레이 로그(L0)**. 슬롯(사람·봇 모두)의 틱별 `InputFrame`을 변화 시점만(런렝스) 바이너리로 묶어 gzip → base64. `encoding = bgil1+gzip+base64`. `scripts/replay_verify.gd`가 재생해 `final_state_hash`와 대조한다. 슬롯 캐릭터는 `match_players.character`에서 읽는다(`event_schema_version` ≥ 5, 그 전 경기는 클래식으로 재생) |

`payload`에는 이벤트의 나머지 필드(`pos`, `knockback`, `power`, `stocks_left` …)를 그대로 넣는다. `Vector3`는 `[x, y, z]` 배열(소수 2자리).

### 4.2 `match_events.type` 목록

모든 sim 이벤트와 일부 view 이벤트, 주기 위치 샘플을 저장한다.

| 출처 | type | actor / target | 주요 payload | Phase |
|---|---|---|---|---|
| sim | `hit` | attacker / target | `pos`, `knockback`, `power`, `hitstop_ticks`, `attack_kind` (공격자 view의 `AttackSet.Kind` 이름, 텔레메트리가 추가) | 4.0 |
| sim | `guard_hit` | attacker / target | `pos`, `knockback`, `attack_kind` | 4.0 |
| sim | `ringout` | id / — | `pos`, `stocks_left`, `cause`, `attacker_slot` (`stock_lost`와 같은 분류, 텔레메트리가 추가) | 4.0 |
| sim (combat-depth D) | `score` · `sudden_death` | 점수 받은 파이터 / — | `delta` (+1 크레딧 링아웃, −1 자멸), `score` (누계), `victim` · `ids` (서든 데스 동점자) | 5 (스키마 7) |
| sim | `grab` · `grab_release` | holder / target | `pos` (release는 던짐 방향 포함) | 4.0 |
| sim | `item_spawn` · `item_pickup` · `item_drop` · `item_throw` · `item_land` · `item_break` | 파이터 / — | `item`, `pos` | 4.0 |
| sim | `explosion` | 던진 파이터 / — | `pos`, 반경 | 4.0 |
| sim (Phase 4) | `gimmick_damage` · `platform_break` · `bounce` · `fog_start` · `fog_end` | 피해자 / — | `kind`, `pos`, `damage` | 4 |
| sim (Phase 5) | `special_start` · `special_hit` · `gauge_full` | 시전자 / 대상 | `character`, `special`, `pos`, `knockback` | 5 |
| sim (Phase 5) | `projectile_spawn` · `projectile_hit` · `projectile_expire` | 소유자(`owner`, 스키마 8부터 — 그 전엔 payload) / 맞은 파이터 | `id`, `kind`, `pos` | 5 |
| sim (combat-depth A) | `dodge` · `guard_break` · `perfect_guard` | 회피·깨진 파이터 / — · `perfect_guard`는 공격자 / 막은 파이터(스키마 8) | `kind` (`roll`\|`air`), `dir`, `pos` · `guard_break`에 `attacker_slot` (텔레메트리가 추가) | 5 (스키마 8) |
| sim (combat-depth C) | `knockdown` · `tech` · `getup` | 파이터 / — | `pos` · `kind` (`place`\|`roll` · `stand`\|`roll`\|`attack`) | 5 (스키마 8) |
| view | `jumped` · `landed` · `respawned` | id / — | `pos` (`landed`는 `intensity`) | 4.0 |
| 샘플 | `pos` | — / — | 전원의 `pos`·`damage`·`state`를 **30틱(0.5초)마다** 1행 | 4.0 |
| 봇 (`PRD-BOT-05`) | `probe_stage` | 프로브한 봇 / 대상 사람 | `stage` (`frontal`\|`edge`\|`ranged`\|`punish`), `result` (그 단계의 프로브 피처) — 단계 끝마다 1행, 경기당 최대 4행 | 5 (스키마 11) |
| 봇 (`PRD-BOT-06`) | `dda_adjusted` | 조정된 봇 / 사람 | `from`, `to` (d), `reason` (`player_ahead`\|`player_behind`), `win_prob` (사람의 상대 승률) | 5 (스키마 11) |
| 봇 (`PRD-BOT-04`) | `bot_intent` | 봇 / 보던 상대 | `intent` (approach·attack·defend·edge·getup·probe_* …), `dist`, `threat` — 의도가 바뀔 때만, 봇당 20틱 간격 이상, **경기당 최대 300행** (`dda_intent_cap`) | 5 (스키마 11) |

렌더 전용 `trail`은 저장하지 않는다 (속도에서 재구성할 수 있다).

---

## 5. 전송 규칙

| 항목 | 규칙 |
|---|---|
| Amplitude 배치 | HTTP API v2 `https://api2.amplitude.com/2/httpapi`, 20건 또는 10초마다. `match_ended`·`app_closed`·`app_backgrounded` 직후 즉시 flush |
| 오프라인 | 실패 배치는 `user://analytics_queue.json`에 보존하고 지수 백오프(상한 있음)로 재시도. 큐 상한을 넘으면 오래된 것부터 버리고 `net_error.queue_size`로 알린다 |
| Supabase | `match_events`는 메모리에 모았다가 경기 종료 시 500행 청크 insert. 로그인하지 않았으면 Supabase 전송은 생략하고 Amplitude만 보낸다 |
| 시간 | Amplitude `time`은 클라이언트 epoch ms. 경기 내부 시간은 `tick`(60Hz) 기준 |
| 웹 페이지 이탈 | 브라우저는 닫기 알림을 주지 않고 열린 fetch를 끊는다. `WebLifecycle`이 `visibilitychange`(hidden)·`pagehide`에서 `app_backgrounded`·`session_ended`를 쌓고 큐 전체를 `navigator.sendBeacon`으로 20건씩 넘긴다(브라우저가 거절한 배치는 큐에 남아 다음 방문 때 전송). 열려 있던 요청은 버리고 같은 이벤트를 비컨에 넣는다 — Amplitude가 `insert_id`로 중복을 지운다 (스키마 8) |

---

## 6. 분석 질문 → 이벤트

모든 이벤트는 아래 질문 중 하나 이상에 답한다 (원칙 T1). 결정 열은 답이 나오면 바꾸는 것이다.

| # | 분석 질문 | 사용 이벤트 / 테이블 | 결정 |
|---|---|---|---|
| Q1 | **스타일·캐릭터별 승률**이 30~70% 안인가? | `match_ended.players[]` (`character`, `style`, `result`, `is_bot`), `match_players` | `StyleData`·공격 수치 조정 (PRD-STYLE-01~04) |
| Q2 | **경기장별 링아웃 위치·원인**이 다른가? | `stock_lost` (`zone`, `angle_deg`, `cause`), `gimmick_triggered`, `gimmick_ringout`, `match_events` `ringout`·`pos`·기믹 원시 | 기믹 강도·경기장 모양 조정 (Phase 4 완료 기준) |
| Q3b | **온라인 퍼널**은 어디서 끊기나? TURN 없이 몇 %가 연결에 실패하나? | `online_lobby_viewed` → `room_created`/`room_joined` → `peer_connect_failed.stage` → `room_left.reason` | TURN 서버 도입(`[net] turn_urls`), 로비 UX |
| Q3 | **로그인 퍼널**의 어디서 이탈하나? | `app_opened` → `login_viewed` → `login_started` → `login_completed` / `login_failed.reason` / `login_skipped` / `session_restored` → `screen_viewed` → `mode_selected` → `match_started` | 로그인 UI·흐름 수정, 건너뛰기 정책 |
| Q4 | **첫 경기 완주율** ≥ 80%인가? (PRD §1.3) | `match_started` → `match_ended` vs `match_abandoned` (사용자 첫 경기) | 난이도·온보딩 조정 |
| Q5 | **필살기 사용률·영향**은? | `gauge_full` → `special_used` (`ms_since_full`), `special_hit` (`targets_hit`, `caused_ringout`), `match_ended.players[].specials`·`special_hits`, `match_events` `special_*`·`projectile_spawn` | 게이지 증가량·필살기 위력 조정 |
| Q6 | **아이템이 승패에 미치는 영향**은? 눈치 싸움이 생기나? (PRD §1.3) | `item_picked_up` (`ms_since_spawn`, `contested`), `item_used`, `item_hit`, `stock_lost.item`, `match_events` `item_*`·`explosion` | 아이템 수치·스폰 주기 조정 |
| Q7 | **세션 길이·재방문**은? | `app_opened` / `app_backgrounded` / `app_closed` (`session_seconds`, `matches_played`), `session_restored.session_age_days`, `rematch_clicked`, `logout` | 세션 설계, 리매치 흐름 |
| Q8 | **"날아가는 맛"** — 사망 대미지 분포가 적당한가? | `stock_lost.damage_at_death`, `match_events` `hit.knockback`·`guard_hit`·`grab`·`grab_release`, `jumped`·`landed`·`respawned` | `global_knockback_mul`·scaling 조정 |
| Q9 | **모바일 조작** — 입력 장치별 승률 차이 ≤ 20%p인가? (PRD §1.3) | `match_ended.players[].input_device`·`result`, `input_device_changed`, `touch_layout_changed` | 터치 레이아웃·수치 조정 |
| Q10 | **성능** — 플랫폼·품질별 fps가 목표를 지키나? | `perf_sampled`, `quality_changed` | 품질 단계 기본값, 최적화 우선순위 (PRD-NFR-01) |
| Q11 | **메뉴 선택 행동** — 어떤 모드·캐릭터·경기장이 선택되고, 어디서 뒤로 가나? | `screen_viewed.dwell_ms_prev`, `mode_selected`, `character_selected.browse_count`, `arena_selected`, `select_cancelled` | 선택 화면 기본값·정렬 |
| Q12 | **설정·오류** — 어떤 설정을 바꾸고, 어떤 연동이 실패하나? | `settings_changed`, `net_error` | 기본값 변경, 연동 안정화 |
| Q13 | **스타일별 플레이 패턴** — 헛스윙·가드·잡기 비율 | `match_ended.players[]` (`whiffs`, `guard_hits`, `grabs`, `jumps`), `match_events` | 봇 난이도, 스타일 차별화 |
| Q14 | **초기 이탈·좌절 신호** (M1·M7) — 첫 경험의 어디서 떠나나? | `session_started`/`session_ended`, `load_timed`, `match_started.loss_streak`·`user_match_seq`, `result_viewed` (`dwell_ms`, `next`), `match_abandoned` (`stock_diff`, `ms_since_last_ringout`), `match_players.idle_gaps`, 사용자 속성 `first_seen_at`·`install_build` | 온보딩·난이도·로딩 최적화 우선순위 |
| Q15 | **플레이 스타일 군집·실력** (M3·M4) | `match_players` 행동 피처 (`press_*`, `mash_ratio`, `edge_time_ratio`, `avg_nearest_opponent_dist`, `hit_accuracy`, `max_combo`, `comeback_win` …), `controller`·`bot_params_hash` | 세그먼트별 튜닝, 봇 난이도 추천 |
| Q16 | **재현 가능한 경기만 분석하고 있나?** (L0 무결성) | `matches` 재현 헤더 (`config_fingerprint`, `sim_version`, `final_state_hash`), `match_inputs`, `scripts/replay_verify.gd` | 불일치 경기 제외, sim 변경 시 버전 관리 |
| Q17 | **체감 성능이 이탈에 주는 영향** | `perf_sampled` (`fps_p5`, `fps_p50`, `spike_count`, `match_id`로 경기와 조인), `load_timed`, `input_device_primary` | 품질 기본값·최적화 우선순위 |
| Q18 | **온보딩 튜토리얼** — 어느 미션에서 오래 걸리거나 건너뛰나? 튜토리얼을 끝낸 사람이 첫 경기를 더 완주하나? | `tutorial_started.source`·`input_device`, `tutorial_step_completed` (`index`, `ms_in_step`, `attempts`), `tutorial_skipped.step`, `tutorial_completed.total_ms`, 이어서 `match_started` → `match_ended` / `match_abandoned` (Q4) | 미션 순서·문구·판정 기준(`TutorialDetector`) 조정, 어려운 미션 빼기 |
| Q19 | **경기 방식** — 어떤 방식을 고르고, 방식별 완주율·경기 길이·재대전율은? 시간제 점수가 링아웃 크레딧으로 공정하게 갈리나(자멸 비율)? | `rule_selected`, `match_started`/`match_ended`/`match_abandoned` `rule`, `match_ended.players[].team`·`score`, `matches.rule`, `match_events` `score`·`sudden_death` | 기본 방식, `timed_duration`, `ringout_credit_time`, 팀전 아군 공격 기본값 |
| Q20 | **방어 수단을 쓰나, 통하나?** — 스타일·캐릭터·입력 장치별 회피(구르기·공중)·퍼펙트 가드 빈도, 반응 속도, 방어 결과(가드·퍼펙트·회피 성공·브레이크), 쓰는 사람의 승률 | `match_players` / `match_ended.players[]` `dodges_roll`·`dodges_air`·`perfect_guards`·`guards`·`roll_evades`·`threats_faced`·`reactions`·`reaction_ticks_avg`·`style`·`character`·`input_device`·`result`, `match_events` `dodge`·`perfect_guard` | 회피·퍼펙트 가드 판정 창(`perfect_guard_ticks`·`roll_*`), 튜토리얼에 방어 미션 추가, 봇이 회피를 쓰게 할지 |
| Q21 | **가드 브레이크가 너무 잦거나 드문가?** 누가 깨나(잡기 대신 압박이 통하나)? | `guard_breaks`·`guard_breaks_caused`, `match_events` `guard_break` (`attacker_slot`), `guard_hit` | `guard_block_mul`·`guard_hold_drain`·`guard_break_stun_ticks` |
| Q22 | **낙법률·기상 선택·DI** — 다운에서의 복귀 기술을 배우나(경기 수에 따라 오르나)? DI가 생존을 늘리나? | `techs / (techs + knockdowns)`, `techs / tech_attempts`, `getups_*`, `di_inputs / hits_taken`, `di_perp_avg`, `tumbles_survived / tumbles`, `matches.user_match_seq`, `match_events` `knockdown`·`tech`·`getup` | 낙법 입력 창, 기상 공격 위력, `di_max_deg`, 튜토리얼·힌트 |
| Q23 | **위험 상황의 선택·팀워크** — 가장자리·고%에서 공격하나 지키나, 그 선택이 생존·승리로 이어지나? 팀전에서 협공이 생기나? | `edge_*`·`high_dmg_*` (`high_dmg_ticks`, `edge_time_ratio`로 정규화), `stock_lost`, `team_assists`, `result` | 넉백 스케일·가장자리 기믹, 팀전 아군 공격·어시스트 보상 |
| Q24 | **경기 방식 선택 고민** — 어떤 방식을 들여다보고 무엇을 고르나? | `rule_selected.focused`·`browse_count`·`rule` | 기본 방식·정렬, 설명 문구 |
| Q25 | **난이도가 맞나?** — 프로브 추정 실력과 레이팅, DDA가 승률을 목표 대역에 묶어 두나, DDA on/off가 재대전·재방문을 바꾸나? | `matches.dda_variant`, `match_players` 봇 트래킹 열(§3.4.2), `match_events` `probe_stage`·`dda_adjusted`·`bot_intent`, `rematch_clicked`, `result` | 다이얼 앵커(`BotDifficulty.ANCHORS`), DDA 대역·스텝·쿨다운(`DDA` 그룹), 프로브 단계 길이 |

---

## 7. 변경 절차

1. 이 문서에 이벤트·속성 추가 (§6에 연결된 질문 필수)
2. `EventCatalog`에 스키마 추가 → 카탈로그 테스트 갱신, `EventCatalog.SCHEMA_VERSION` +1 (Supabase 열이 바뀌면 새 마이그레이션도)
3. `MatchTelemetry`·화면 코드에서 발행 → `test_match_telemetry` 기대값 갱신
4. 이름·타입을 바꿔야 하면 기존 이벤트를 ~~취소선~~ 처리하고 새 이름을 만든다 (Amplitude 과거 데이터와 섞이지 않게)
