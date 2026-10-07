# combat-motion context
Last Updated: 2026-10-07 (A1~A4 done; evidence/swings-*.png)

- 애니메이터: src/render/character/{character_animator,anim_map,anim_clips}.gd. view의 attack_ticks(1부터), attack_kind, style 사용.
- 측정 스크립트: scripts/measure_contact.gd (Knight.glb, 뼈 전방 z 최대 시점). 결과 표는 swing_clips.gd 주석.
- TimeSeek(explicit_elapse=false)+TimeScale(0)이면 play position이 seek 값과 정확히 일치 (Godot 4.7.2 확인).
- 이펙트 쪽 파일 소유: 서브에이전트(src/render/feel/*, projectile 레이어, match_stage.gd 연결). 모션 쪽: src/render/character/*, fighter_view.gd.
- 측정: Punch_A hand.r contact 0.50 / Punch_B hand.l 0.33, hand.r 0.48 / Kick foot.r 0.37 / 1H Slice_Diagonal 0.30 / Slice_Horizontal 0.20 / 1H Stab 0.55 / 1H Chop 0.65 / 2H Chop 0.78 / Dualwield Stab 0.6~0.85 양손 뻗음 / Spellcast_Shoot hand.r 0.23 / 1H_Ranged_Shoot 0.30 / Throw 0.77
