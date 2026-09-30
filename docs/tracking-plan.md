# TheBrawlGuys — 트래킹 플랜

> 버전 0.1 · 2026-09-30
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

---

## 3. Amplitude 이벤트 카탈로그

목적지 열: **A** = Amplitude, **S** = Supabase. 요구사항은 모두 `PRD-DATA-03` (Supabase 쪽은 `PRD-DATA-04`).

### 3.1 앱·세션

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `app_opened` | 앱 셸 `_ready` (콜드 스타트) 또는 백그라운드 복귀로 새 세션 발급 | `cold_start: bool` | `launch_ms: int` (프로세스 시작 → 첫 화면) | A | 4.0 |
| `app_backgrounded` | 포커스 잃음 / 모바일 일시정지 / 웹 탭 숨김 | `screen: str`, `session_seconds: float` | `in_match: bool` | A | 4.0 |
| `app_closed` | 정상 종료 요청 (`NOTIFICATION_WM_CLOSE_REQUEST`) — 전송 후 flush | `screen: str`, `session_seconds: float`, `matches_played: int` | — | A | 4.0 |
| `perf_sampled` | `match_ended` 직후 1회 (경기 동안 누적) | `match_id: str`, `fps_avg: float`, `fps_p95_low: float`, `tick_ms_avg: float`, `tick_ms_p95: float`, `frame_count: int` | `quality_changed_mid: bool` | A | 4.0 |

### 3.2 로그인 (`PRD-AUTH-01`)

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `login_viewed` | 로그인 화면 표시 (세션 복원 실패 포함) | `reason: enum(first_run\|no_session\|refresh_failed\|logged_out)` | — | A | 4.0 |
| `login_started` | Google 버튼 클릭 | `provider: enum(google)`, `flow: enum(web_redirect\|desktop_loopback)` | — | A | 4.0 |
| `login_completed` | 토큰 교환 성공 | `provider: enum(google)`, `flow: enum(...)`, `duration_ms: int` (started → completed), `is_new_user: bool` | — | A | 4.0 |
| `login_failed` | 교환 실패·취소·타임아웃 | `provider: enum(google)`, `flow: enum(...)`, `reason: enum(cancelled\|timeout\|exchange_error\|network\|port_in_use\|config_missing)` | `http_status: int` | A | 4.0 |
| `login_skipped` | 모바일 debug 빌드 "건너뛰기" | — | — | A | 4.0 |
| `session_restored` | 저장된 refresh token으로 갱신 성공 → 로그인 화면 생략 | `session_age_days: float` | — | A | 4.0 |
| `logout` | 설정에서 로그아웃 | — | — | A | 4.0 |

로그인 완료 순간 `Analytics`는 `user_id`를 설정하고, 그 이전 이벤트는 같은 `device_id`로 Amplitude가 병합한다.

### 3.3 메뉴 퍼널 (`PRD-UI-02`)

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `screen_viewed` | 화면 스택 전환 완료 | `screen: enum(login\|title\|mode\|character\|arena\|lobby\|match\|result\|settings)`, `from_screen: str` | `dwell_ms_prev: int` (직전 화면 체류) | A | 4.0 |
| `mode_selected` | 모드 확정 | `mode: enum(bot\|local_2p\|online)` | — | A | 4.0 |
| `character_selected` | 슬롯별 캐릭터 확정 | `slot: int`, `character: enum(barbarian\|rogue\|knight\|mage)`, `style: enum(boxer\|weapon\|ranged)`, `is_bot: bool` | `browse_count: int` (확정 전 넘겨본 카드 수) | A | 5 |
| `arena_selected` | 경기장 확정 | `arena: enum(lakeside_camp\|log_bridge\|mushroom_forest\|foggy_forest)` | `browse_count: int` | A | 4 |
| `select_cancelled` | 선택 화면에서 뒤로 | `screen: enum(mode\|character\|arena)` | `dwell_ms: int` | A | 4.0 |

### 3.4 경기

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `match_started` | 첫 틱 진입 | `match_id: str` (uuid), `mode: enum(...)`, `arena: enum(...)`, `player_count: int`, `bot_count: int`, `characters: list<str>` (슬롯 순), `styles: list<str>`, `input_devices: list<str>`, `seed: int` | `rematch: bool` | A + S(`matches`) | 4.0 |
| `match_ended` | 승패 확정 (스톡 0) | `match_id: str`, `result: enum(win\|loss\|draw)` (P1 기준), `winner_slot: int`, `duration_s: float`, `duration_ticks: int`, `players: list<obj>` (§3.4.1) | `comeback: bool` (P1이 스톡 열세에서 승리) | A + S(`matches`·`match_players`) | 4.0 |
| `match_abandoned` | 결과 전 메뉴 이탈·앱 종료 | `match_id: str`, `elapsed_s: float`, `p1_stocks_left: int`, `opponent_stocks_left: int` | `reason: enum(menu\|app_closed\|disconnect)` | A + S | 4.0 |
| `rematch_clicked` | 결과 화면 "다시" | `match_id: str` (끝난 경기) | — | A | 4.0 |

#### 3.4.1 `match_ended.players[]` 슬롯 요약 (= Supabase `match_players` 행)

| 필드 | 타입 | 설명 | Phase |
|---|---|---|---|
| `slot` | int | 0부터 | 4.0 |
| `is_bot` | bool | | 4.0 |
| `character` / `style` | str | Phase 5 전에는 슬롯 고정 모델·기본 스타일 | 4.0 |
| `input_device` | str | | 4.0 |
| `result` | enum(win\|loss\|draw) | | 4.0 |
| `stocks_left` | int | | 4.0 |
| `damage_dealt` / `damage_taken` | float | % 합계 | 4.0 |
| `hits` / `guard_hits` / `grabs` / `throws` | int | 고빈도 행동 집계 | 4.0 |
| `whiffs` | int | 헛스윙 (view `attack_kind` 전이 중 hit 없음) | 4.0 |
| `jumps` | int | `ViewEvents` `jumped` 수 | 4.0 |
| `ringouts_scored` / `self_destructs` | int | 마지막 가격자로서의 링아웃 / 가격자 없는 낙사 | 4.0 |
| `items_used` | int | 줍기 후 휘두름·투척 | 4.0 |
| `falls_by_gimmick` | int | 기믹이 원인인 스톡 소모 | 4 |
| `specials` / `special_hits` | int | 필살기 발동 / 적중 | 5 |

### 3.5 전투 핵심

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `stock_lost` | sim `ringout` | `match_id: str`, `victim_slot: int`, `stocks_left: int`, `damage_at_death: float`, `cause: enum(knockback\|gimmick\|self)`, `killer_slot: int` (-1 = 없음), `exit_angle_deg: float` (경기장 중심 기준), `exit_zone: str` (경기장 데이터의 구역 이름), `match_time_s: float` | `last_hit_attack: str`, `last_hit_ms_ago: int`, `item: str` | A (+ S 원시 `ringout`) | 4.0 (구역은 4) |
| `gauge_full` | 필살기 게이지 100% 도달 | `match_id: str`, `slot: int`, `character: str`, `match_time_s: float` | — | A | 5 |
| `special_used` | sim `special_start` | `match_id: str`, `slot: int`, `character: str`, `ms_since_full: int`, `target_damage: float` (가장 가까운 상대 %) | — | A (+ S) | 5 |
| `special_hit` | sim `special_hit` (발동 1회당 첫 적중만) | `match_id: str`, `slot: int`, `character: str`, `targets_hit: int`, `caused_ringout: bool` | — | A (+ S 원시 전부) | 5 |

`killer_slot`은 피해자에게 마지막으로 `hit`을 넣은 슬롯이다 (링아웃 전 `ringout_credit_s` 안, config). 없으면 `cause = self`.
`caused_ringout`은 적중 후 같은 창 안에 대상이 링아웃되면 true — 판정 후 지연 발행한다.

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
| `settings_changed` | 설정 값 저장 | `key: str`, `old_value: str`, `new_value: str` | — | A | 4.0 (설정 화면은 6) |
| `quality_changed` | 품질 단계 변경 (수동·자동) | `from: enum(...)`, `to: enum(...)`, `auto: bool` | `fps_avg_before: float` | A | 4.0 |
| `input_device_changed` | P1 입력 장치 전환 | `from: str`, `to: str`, `screen: str` | — | A | 4.0 |
| `touch_layout_changed` | 터치 레이아웃·크기 변경 | `layout: int`, `button_scale: float` | — | A | 4.0 (편집은 6) |

### 3.9 오류

| 이벤트 | 트리거 | 필수 속성 | 선택 속성 | 목적지 | Phase |
|---|---|---|---|---|---|
| `net_error` | Supabase·Amplitude·로비 HTTP 실패 (재시도를 포기할 때 1회) | `endpoint: enum(auth\|rest\|amplitude\|lobby)`, `status: int` (0 = 연결 실패), `retries: int` | `queue_size: int` | A (Amplitude 자신의 실패는 다음 성공 배치에 포함) | 4.0 |

---

## 4. Supabase 원시 테이블 (`PRD-DATA-04`)

마이그레이션: `supabase/migrations/0001_match_telemetry.sql`. 모든 테이블은 RLS로 **본인 `user_id` 행만** insert/select 하고 anon은 막는다.

### 4.1 테이블

| 테이블 | 열 | 설명 |
|---|---|---|
| `profiles` | `id uuid pk = auth.uid`, `display_name text`, `created_at timestamptz` | 첫 로그인 시 생성 |
| `matches` | `id uuid pk`, `user_id uuid`, `mode text`, `arena text`, `player_count int`, `seed bigint`, `started_at timestamptz`, `duration_ticks int`, `winner_slot int`, `build_version text`, `platform text` | 경기 1행. `match_started` 때 insert, `match_ended`/`match_abandoned` 때 update |
| `match_players` | `match_id uuid fk`, `slot int`, `is_bot bool`, `character text`, `style text`, `input_device text`, `result text`, `stocks_left int`, `damage_dealt real`, `damage_taken real`, `hits int`, `ringouts_scored int`, `specials int`, `items_used int`, `falls_by_gimmick int` · pk(`match_id`, `slot`) | §3.4.1 요약의 저장 형태 |
| `match_events` | `id bigserial pk`, `match_id uuid fk`, `tick int`, `type text`, `actor_slot int`, `target_slot int`, `payload jsonb` · 인덱스(`match_id`, `type`) | 원시 행동 로그. 경기 종료 시 500행 청크로 insert |

`payload`에는 이벤트의 나머지 필드(`pos`, `knockback`, `power`, `stocks_left` …)를 그대로 넣는다. `Vector3`는 `[x, y, z]` 배열(소수 2자리).

### 4.2 `match_events.type` 목록

모든 sim 이벤트와 일부 view 이벤트, 주기 위치 샘플을 저장한다.

| 출처 | type | actor / target | 주요 payload | Phase |
|---|---|---|---|---|
| sim | `hit` | attacker / target | `pos`, `knockback`, `power`, `hitstop_ticks` | 4.0 |
| sim | `guard_hit` | attacker / target | `pos`, `knockback` | 4.0 |
| sim | `ringout` | id / — | `pos`, `stocks_left` | 4.0 |
| sim | `grab` · `grab_release` | holder / target | `pos` (release는 던짐 방향 포함) | 4.0 |
| sim | `item_spawn` · `item_pickup` · `item_drop` · `item_throw` · `item_land` · `item_break` | 파이터 / — | `item`, `pos` | 4.0 |
| sim | `explosion` | 던진 파이터 / — | `pos`, 반경 | 4.0 |
| sim (Phase 4) | `gimmick_damage` · `platform_break` · `bounce` · `fog_start` · `fog_end` | 피해자 / — | `kind`, `pos`, `damage` | 4 |
| sim (Phase 5) | `special_start` · `special_hit` · `projectile_spawn` | 시전자 / 대상 | `character`, `pos`, `knockback` | 5 |
| view | `jumped` · `landed` · `respawned` | id / — | `pos` (`landed`는 `intensity`) | 4.0 |
| 샘플 | `pos_sample` | — / — | 전원의 `pos`·`damage`·`state`를 **30틱(0.5초)마다** 1행 | 4.0 |

렌더 전용 `trail`은 저장하지 않는다 (속도에서 재구성할 수 있다).

---

## 5. 전송 규칙

| 항목 | 규칙 |
|---|---|
| Amplitude 배치 | HTTP API v2 `https://api2.amplitude.com/2/httpapi`, 20건 또는 10초마다. `match_ended`·`app_closed`·`app_backgrounded` 직후 즉시 flush |
| 오프라인 | 실패 배치는 `user://analytics_queue.json`에 보존하고 지수 백오프(상한 있음)로 재시도. 큐 상한을 넘으면 오래된 것부터 버리고 `net_error.queue_size`로 알린다 |
| Supabase | `match_events`는 메모리에 모았다가 경기 종료 시 500행 청크 insert. 로그인하지 않았으면 Supabase 전송은 생략하고 Amplitude만 보낸다 |
| 시간 | Amplitude `time`은 클라이언트 epoch ms. 경기 내부 시간은 `tick`(60Hz) 기준 |

---

## 6. 분석 질문 → 이벤트

모든 이벤트는 아래 질문 중 하나 이상에 답한다 (원칙 T1). 결정 열은 답이 나오면 바꾸는 것이다.

| # | 분석 질문 | 사용 이벤트 / 테이블 | 결정 |
|---|---|---|---|
| Q1 | **스타일·캐릭터별 승률**이 30~70% 안인가? | `match_ended.players[]` (`character`, `style`, `result`, `is_bot`), `match_players` | `StyleData`·공격 수치 조정 (PRD-STYLE-01~04) |
| Q2 | **경기장별 링아웃 위치·원인**이 다른가? | `stock_lost` (`exit_zone`, `exit_angle_deg`, `cause`), `gimmick_triggered`, `gimmick_ringout`, `match_events` `ringout`·`pos_sample`·기믹 원시 | 기믹 강도·경기장 모양 조정 (Phase 4 완료 기준) |
| Q3 | **로그인 퍼널**의 어디서 이탈하나? | `app_opened` → `login_viewed` → `login_started` → `login_completed` / `login_failed.reason` / `login_skipped` / `session_restored` → `screen_viewed` → `mode_selected` → `match_started` | 로그인 UI·흐름 수정, 건너뛰기 정책 |
| Q4 | **첫 경기 완주율** ≥ 80%인가? (PRD §1.3) | `match_started` → `match_ended` vs `match_abandoned` (사용자 첫 경기) | 난이도·온보딩 조정 |
| Q5 | **필살기 사용률·영향**은? | `gauge_full` → `special_used` (`ms_since_full`), `special_hit.caused_ringout`, `match_ended.players[].specials`, `match_events` `special_*`·`projectile_spawn` | 게이지 증가량·필살기 위력 조정 |
| Q6 | **아이템이 승패에 미치는 영향**은? 눈치 싸움이 생기나? (PRD §1.3) | `item_picked_up` (`ms_since_spawn`, `contested`), `item_used`, `item_hit`, `stock_lost.item`, `match_events` `item_*`·`explosion` | 아이템 수치·스폰 주기 조정 |
| Q7 | **세션 길이·재방문**은? | `app_opened` / `app_backgrounded` / `app_closed` (`session_seconds`, `matches_played`), `session_restored.session_age_days`, `rematch_clicked`, `logout` | 세션 설계, 리매치 흐름 |
| Q8 | **"날아가는 맛"** — 사망 대미지 분포가 적당한가? | `stock_lost.damage_at_death`, `match_events` `hit.knockback`·`guard_hit`·`grab`·`grab_release`, `jumped`·`landed`·`respawned` | `global_knockback_mul`·scaling 조정 |
| Q9 | **모바일 조작** — 입력 장치별 승률 차이 ≤ 20%p인가? (PRD §1.3) | `match_ended.players[].input_device`·`result`, `input_device_changed`, `touch_layout_changed` | 터치 레이아웃·수치 조정 |
| Q10 | **성능** — 플랫폼·품질별 fps가 목표를 지키나? | `perf_sampled`, `quality_changed` | 품질 단계 기본값, 최적화 우선순위 (PRD-NFR-01) |
| Q11 | **메뉴 선택 행동** — 어떤 모드·캐릭터·경기장이 선택되고, 어디서 뒤로 가나? | `screen_viewed.dwell_ms_prev`, `mode_selected`, `character_selected.browse_count`, `arena_selected`, `select_cancelled` | 선택 화면 기본값·정렬 |
| Q12 | **설정·오류** — 어떤 설정을 바꾸고, 어떤 연동이 실패하나? | `settings_changed`, `net_error` | 기본값 변경, 연동 안정화 |
| Q13 | **스타일별 플레이 패턴** — 헛스윙·가드·잡기 비율 | `match_ended.players[]` (`whiffs`, `guard_hits`, `grabs`, `jumps`), `match_events` | 봇 난이도, 스타일 차별화 |

---

## 7. 변경 절차

1. 이 문서에 이벤트·속성 추가 (§6에 연결된 질문 필수)
2. `EventCatalog`에 스키마 추가 → 카탈로그 테스트 갱신
3. `MatchTelemetry`·화면 코드에서 발행 → `test_match_telemetry` 기대값 갱신
4. 이름·타입을 바꿔야 하면 기존 이벤트를 ~~취소선~~ 처리하고 새 이름을 만든다 (Amplitude 과거 데이터와 섞이지 않게)
