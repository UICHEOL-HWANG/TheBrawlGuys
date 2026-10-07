# arena-ringout plan (2026-10-07)
Branch `feat/arena-ringout` (worktree `.claude/worktrees/arena-ringout`), base main 01cc20c.

## A. Off-stage fall (user: "맵 밖으로 떨어질 때 모션이 부자연스러워")
Evidence `evidence/ringout-classic-{walk,launch}.png` (scripts/capture_ringout.gd):
- falling off plays JUMP (Jump_Idle) upright and stiff the whole way down
- the body sinks through the meadow / lake surface (DecorView.GROUND_Y = -1) and keeps falling
  7 m underground; the ring-out (and burst, shake, sound) only fires at kill_y = -8, ~0.5 s later
Fix:
1. sim: kill_y -8 -> -2 (just past the deepest point a jump can still recover from, ~1.8 m
   under the floor; the meadow sits at -1) so the ring-out lands with the body at the surface
2. render: a real fall pose for a body below the floor lip (Anim.FALL), with a lean/flail
3. re-capture evidence; tests

## B. New arena: frozen pond (사용자 선택: 얼음 연못)
Ice disc over cold water: slippery ground (low grip, long slides after knockback), ice patches
that crack open (BreakablePlatform) and refreeze, water all around = ring-out zone "water".
Theme: snow, pale sky, falling snow. Added to stage list / arena select / tracking docs.

## C. Merge, test.sh, check-all, capture proof, then ask before merge to main / deploy
