import math

import pandas as pd
import pytest

from brawl_analysis.features import player_table, timeline_table
from brawl_analysis.models import balance, churn
from brawl_analysis.models.win_prob import train_win_prob


def test_win_prob_smoke_train(tiny):
    res = train_win_prob(timeline_table(tiny), folds=4)
    assert res.n_matches == 8
    assert set(res.metrics.columns) == {"log_loss", "auc", "brier"}
    assert res.oof.between(0, 1).all()
    assert not res.importance.empty


def test_wilson_interval():
    low, high = balance.wilson(50, 100)
    assert low < 0.5 < high
    assert high - low == pytest.approx(0.192, abs=0.005)
    assert all(math.isnan(v) for v in balance.wilson(0, 0))


def test_win_rates_excess(tiny):
    pt = player_table(tiny)
    t = balance.win_rates(pt, "character")
    assert t["n"].sum() == len(pt)
    assert ((t["ci_low"] <= t["win_rate"]) & (t["win_rate"] <= t["ci_high"])).all()
    assert (t["excess"] == t["win_rate"] - t["expected"]).all()


def test_regression_smoke(tiny):
    reg = balance.regression(player_table(tiny), n_boot=10)
    assert "player_count" in set(reg["term"])
    assert (reg["odds_ratio"] > 0).all()


def test_ringouts_self_destruct_from_cause():
    events = pd.DataFrame({"match_id": ["m", "m"], "type": ["ringout", "ringout"],
                           "actor_slot": [0, 1],
                           "payload": [{"cause": "self", "zone": "kill_y", "attacker_slot": -1},
                                       {"cause": "knockback", "zone": "blast",
                                        "attacker_slot": 0}]})
    matches = pd.DataFrame({"id": ["m"], "arena": ["classic"], "rule": ["stock"]})
    ro = balance.ringouts(events, matches)
    assert ro["self_destruct"].tolist() == [True, False]
    assert balance.ringout_table(ro, "arena")["share"].sum() == pytest.approx(1.0)


def test_churn_stub_pipeline_learns_known_effect():
    res = churn.evaluate(churn.stub_users(n=600), "stub")
    assert res.auc > 0.55
    assert res.n_users == 600


def test_churn_user_table_from_export():
    # u3 joins on 10-20: its 7-day window is still open at export time, so it is censored.
    matches = pd.DataFrame({
        "id": ["a", "b", "c", "d"], "user_id": ["u1", "u1", "u2", "u3"],
        "session_id": [1, 2, 9, 5],
        "started_at": ["2026-10-01T00:00:00Z", "2026-10-03T00:00:00Z", "2026-10-01T00:00:00Z",
                       "2026-10-20T00:00:00Z"],
        "duration_ticks": [600, 600, 1200, 600], "result": ["loss", "win", "win", "win"]})
    players = pd.DataFrame({
        "match_id": ["a", "b", "c", "c", "d"], "slot": [0, 0, 0, 1, 0],
        "controller": ["local", "local", "local", "bot", "local"],
        "result": ["loss", "win", "win", "loss", "win"],
        "falls": [3, 0, None, 3, 0], "damage_taken": [100.0, 10.0, 50.0, 90.0, 5.0],
        "input_device": ["keyboard", "keyboard", "touch", "bot", "gamepad"]})
    users = churn.user_table(matches, players).set_index("user_id")
    assert "u3" not in users.index
    assert pd.isna(users.loc["u2", "first_match_falls"]), "null stays null (no later fill)"
    assert users.loc["u1", churn.LABEL] == 1
    assert users.loc["u2", churn.LABEL] == 0
    assert users.loc["u1", "first_match_won"] == 0
    assert users.loc["u2", "first_match_duration_s"] == 20.0
