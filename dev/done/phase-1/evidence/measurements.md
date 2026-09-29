# Phase 1 측정 기록

| 항목 | 명령 | 결과 | 기준 |
|---|---|---|---|
| sim 비용 (봇 4, 600틱, 데스크톱) | `godot --headless --path . -s res://scripts/bench_sim.gd` | avg 22.2 us/tick, worst 372 us/tick | 모바일 ≤ 2 ms (PRD-NFR-02) |
| 입력 지연 (점프) | `godot --path . -s res://scripts/measure_input_latency.gd` | 2 frames | ≤ 3 (PRD-NFR-03) |
| 넉백 튜닝 | `godot --headless --path . -s res://scripts/tune_knockback.gd` | minimum 1.471, 채택 1.70 | 100% 링아웃 & 0% 잔류 |

- 측정 환경: Apple M2 데스크톱, Godot 4.7.2. 모바일 실측은 기기 확보 후.
- 키 프레임(`ringout-58/70/100/145.png`)은 로컬 영상 `ringout.avi`(60fps 고정)에서 추출: 58 = 타격 직전(100%), 70 = 히트 퍼프(104%), 100 = 경기장 밖으로 비행, 145 = 링아웃 후 P2 스톡 2개·0%로 리스폰.
