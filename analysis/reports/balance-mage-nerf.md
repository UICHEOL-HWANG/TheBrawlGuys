# Mage nerf check (2026-10-01)

Change (b36ffb4): bolt_damage 3.5→3.0, bolt_range 7→6, ranged_knockback_taken 1.1→1.2, fireball_damage 16→13.

Bot-only synthetic data (scripts/gen_dataset.gd, 10×100 matches, seed 1). Before: 596 matches, mage excess +0.097 overall (OR 1.64 vs barbarian). After: 997 matches:

## Win rate by character

| character | n | wins | win_rate | ci_low | ci_high | expected | excess |
|---|---|---|---|---|---|---|---|
| barbarian | 781 | 309 | 0.396 | 0.362 | 0.430 | 0.400 | -0.005 |
| knight | 773 | 324 | 0.419 | 0.385 | 0.454 | 0.415 | 0.004 |
| mage | 750 | 337 | 0.449 | 0.414 | 0.485 | 0.408 | 0.041 |
| rogue | 742 | 271 | 0.365 | 0.331 | 0.400 | 0.406 | -0.041 |

## Win rate by character (1v1 stock only)

| character | n | wins | win_rate | ci_low | ci_high | expected | excess |
|---|---|---|---|---|---|---|---|
| barbarian | 150 | 78 | 0.520 | 0.441 | 0.598 | 0.500 | 0.020 |
| knight | 166 | 82 | 0.494 | 0.419 | 0.569 | 0.500 | -0.006 |
| mage | 137 | 71 | 0.518 | 0.435 | 0.600 | 0.500 | 0.018 |
| rogue | 143 | 67 | 0.469 | 0.389 | 0.550 | 0.500 | -0.031 |
