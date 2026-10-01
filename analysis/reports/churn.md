# M1 — Early churn (first session → returned within 7 days)

> **NEEDS REAL USERS.** This dataset has no users, so the pipeline ran on a generated stub with known effects. The numbers below only prove the pipeline runs end to end.

- source: GENERATED STUB
- users: 2000
- base return rate: 54.2%
- out-of-fold AUC: 0.626
- out-of-fold log-loss: 0.714

Features (first session only): first_session_matches, first_match_won, first_match_falls, first_match_damage_taken, first_session_losses, first_match_duration_s, input_device.
Label: `returned_7d` — another session within 7 days of the first session's start.
