# Phase 2 측정 (2026-09-29, 최종 리뷰 수정 반영)

| 항목 | Phase 1 | Phase 2 | 명령 |
|---|---|---|---|
| 4인 World 1틱 평균 / 최악 (µs), 아이템 2개 포함 | 22.2 / 372 (아이템 없음) | 55.1~56.2 / 89~131 | `godot --headless --path . -s res://scripts/bench_sim.gd` |
| 입력 → 상태 반영 (프레임) | 2 | 2 (창 모드 5회 실행, 5회 모두 2) | `godot --path . -s res://scripts/measure_input_latency.gd` |
| 링아웃 범위 global_knockback_mul (3타 콤보, 100%) | 1.471 (약공격 1타, 최소값) | 1.40 ~ 2.75 (기본값 1.7은 창 폭의 22% 지점) | `godot --headless --path . -s res://scripts/tune_knockback.gd` |

- 테스트: 310개 통과 (`./scripts/test.sh`, 46 스크립트), `check-all.sh` 통과 (ALL CHECKS PASSED)
- 리플레이 골든: 2973674052 (1200틱, E11) — 최종 리뷰 수정에서도 변경 없음
- 측정 환경: Apple M2 데스크톱, Godot 4.7.2.
- `bench_sim.gd`: 봇 4, 600틱. 타이밍 전에 땅 위 아이템 2개(방망이 (-3,0,0), 돌멩이 (3,0,0))를 놓아 줍기·사용·던지기·낙하 비용이 포함된다 (600틱 동안 아이템 이벤트 12개, 출력 끝에 `N item events`로 표시). 3회 실행: 평균 55.1 / 55.9 / 56.2 µs, 최악 89 / 105 / 131 µs. 이전 측정(58.5 / 316)은 상자가 거의 생성되지 않는 실행이었다. 모바일 예산(2 ms = 2000 µs)의 3% 수준.
- 입력 지연: headless 실행은 Phase 1 기준선에서도 2~4프레임으로 흔들려 창 모드로 5회 실행했고 전부 2프레임 (예산 3).
- `tune_knockback.gd`: 이분 탐색을 0.5~4.0 (0.05 간격) 스윕으로 바꿨다. 링아웃은 mul에 대해 단조롭지 않다 (연결타 넉백이 커지면 대상이 3타 사거리 밖으로 밀려나 마무리가 헛친다). 출력:

```
tune_knockback: ring-out window at 100%: 1.40 .. 2.75
tune_knockback: default 1.70 sits 22% of the way through its window
tune_knockback: 0% stays on stage at the default: true
```

  기본값 1.7은 창 하한 1.40보다 약 21% 위(창 폭의 22% 지점)이며 "한가운데"가 아니다. 0.005 간격 수동 스윕의 하한 1.37과 스크립트(0.05 간격)의 하한 1.40 차이는 간격 때문이다. 기본값이 창 밖이거나 0%에서 링아웃하면 종료 코드 1.

## 상자 쟁탈 영상 키 프레임 (봇 대 봇 데모, 사람 플레이어 없음)

`item-race.avi`(로컬, gitignore)는 `src/debug/item_race_demo.tscn`을 Movie Maker(60 fps 고정, 360프레임)로 녹화한 것. 두 파이터 모두 2단계 봇이며 입력 고정 없음 (최종 리뷰 수정에서 neutral 고정을 제거). 상자는 10틱에 중앙에 떨어지도록 놓는다. 프레임 번호는 0부터.

| 파일 | 프레임 | 보이는 것 |
|---|---|---|
| `item-race-030-falling.png` | 30 | 상자(크림색 사각형)가 화면 위쪽에서 떨어지는 중, 경기장 중앙에 작은 그림자. P1(파랑)·P2(빨강)는 이미 중앙 쪽으로 걷는 중 |
| `item-race-058-nearly-landed.png` | 58 | (중앙 확대) 상자가 착지 직전, 두 봇이 그림자 양옆에 거의 도착 |
| `item-race-066-contest.png` | 66 | (중앙 확대) 상자 착지, 두 봇이 상자 양옆에 붙어 쟁탈 |
| `item-race-096-picked-up.png` | 96 | (중앙 확대) P1이 방망이를 들고 있음 (머리 위 흰 막대), P2가 바로 옆 |
