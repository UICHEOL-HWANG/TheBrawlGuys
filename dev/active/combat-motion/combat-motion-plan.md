# combat-motion — 공격 모션 개선 + 마법/필살기/잡기 이펙트

사용자 요청 (2026-10-07): 때리는 모션 부자연스러움, 무기 공격 개선, 마법사·필살기 이펙트 없음, 잡기 모션이 뭘 하는지 안 읽힘.

## 원인
1. 공격 클립 전체(1~1.6초)를 sim 공격 길이(0.23초 등)에 균일 스트레치 → 6배속, 회수 동작이 튐. 3연타 모두 같은 Punch_A.
2. 스타일 무시: 기사(검)도 약=펀치, 강=발차기. timeline은 classic 타이밍이라 weapon(+3/+5틱)·bolt 타이밍과 어긋남.
3. 잡기 = 한 손 Interact 스트레치, HOLD = Unarmed_Pose(정지), HELD = Hit_B 반복.
4. 투사체(볼트/강볼트/화염구)는 sim에만 있고 렌더러 없음. 필살기 시작/발동 이펙트 없음(컷인 배너만).

## 해결
A. 모션(직접): SwingClips(스타일×공격 → 클립, start/contact/end 초) + SwingTiming(sim attack_ticks → 클립 시각, startup ease-in → contact, active 정지감, recovery ease-out). 애니메이터 timed 상태는 BlendTree(Animation→TimeSeek→TimeScale 0)로 매 프레임 seek. 콤보는 두 슬롯 핑퐁으로 짧은 크로스페이드. 잡기 = 두 손 찌르기(Dualwield stab) 앞부분, HOLD = 그 클립의 팔 뻗은 포즈 유지, HELD = 들린(lift) 버둥거림.
B. 이펙트(서브에이전트): ProjectileLayer(볼트/강볼트/화염구 메시+트레일, 발사 섬광, 폭발), SpecialFx(시작 오라·스타일별 발동 이펙트), 잡기 그립 이펙트.
