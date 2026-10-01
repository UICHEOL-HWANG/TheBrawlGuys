# combat-depth — Tasks
- [x] A: 회피(구르기·공중 회피) + 가드 내구도/브레이크 + 저스트 가드 (feat/defense) — sim `Dodge`/`GuardMeter`, 튜닝 `DefenseConfig`, 봇 `BotDefense`, 연출 `DefenseFx`(DS-VFX-10~13), 스냅샷 v7, 골든 해시 갱신. 증거 스크린샷 `evidence/defense-*.png`, 시트 `evidence/defense-sheet.png` (`scripts/capture_defense.gd`)
- [x] B: 겟앰프드식 타격 연출 (feat/hit-impact) + 증거 스크린샷 (`evidence/hit-*.png`, 비교 `evidence/hit-before-after.png`)
- [x] 병합 → 테스트/체크 → 코드 리뷰(HIGH 1·MEDIUM 5 수정) → 커밋 → 배포(e96320a 빌드)
- [x] 카메라 C안 근접(a28d2ba)
- [ ] 다음: DI, 기상 선택·낙법, 팀전 2:2, 시간제 FFA

## 2차 (2026-10-01 사용자 "나머지 고고")
- [ ] C: DI + 다운/기상 선택/낙법 + hitstop_heavy 0.13 + 봇 저스트 가드 완화 (feat/di-tech)
- [ ] D: 팀전 2:2 + 시간제 FFA + 근접 카메라 HUD 겹침 확인 (feat/modes)
