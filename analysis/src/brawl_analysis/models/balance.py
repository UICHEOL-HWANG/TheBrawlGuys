"""M5 balance: character / arena / style win rates and a controlled logistic regression.

Win rates are compared with the share a slot is expected to win by chance (1 / player_count,
0.5 in team mode), so FFA and 1v1 rows can be pooled: ``excess = win_rate - expected``.
Intervals are Wilson 95 % for rates and match-level bootstrap for regression odds ratios
(slots of one match are not independent). Ring-out causes come from match_events.
"""

from __future__ import annotations

import math

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression

from brawl_analysis.features import ARENAS, CHARACTERS, RULES, one_hot

Z95 = 1.959964
SEED = 11
BOOTSTRAP = 200
REGRESSION_C = 10.0
# Synthetic bot presets (scripts/dataset/dataset_spec.gd); real bots report "normal".
DIFFICULTIES = ("slow", "normal", "busy")
# Reference levels dropped from the regression design (odds ratios are relative to them).
REFERENCE = {"character": "barbarian", "arena": "classic", "rule": "stock",
             "bot_difficulty": "normal"}


def wilson(wins: int, n: int, z: float = Z95) -> tuple[float, float]:
    """Wilson score interval for a binomial rate; (nan, nan) when n == 0."""
    if n == 0:
        return float("nan"), float("nan")
    p = wins / n
    denom = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return centre - half, centre + half


def win_rates(pt: pd.DataFrame, by: str | list[str]) -> pd.DataFrame:
    """n, wins, win_rate, Wilson CI, expected (chance) share and excess per group."""
    g = pt.groupby(by, observed=True).agg(n=("win", "size"), wins=("win", "sum"),
                                          expected=("expected_win", "mean"))
    g["win_rate"] = g["wins"] / g["n"]
    ci = [wilson(int(w), int(n)) for w, n in zip(g["wins"], g["n"], strict=True)]
    g["ci_low"] = [c[0] for c in ci]
    g["ci_high"] = [c[1] for c in ci]
    g["excess"] = g["win_rate"] - g["expected"]
    return g.reset_index()


def _design(pt: pd.DataFrame) -> pd.DataFrame:
    parts = [one_hot(pt, "character", CHARACTERS), one_hot(pt, "arena", ARENAS),
             one_hot(pt, "rule", RULES)]
    if "bot_difficulty" in pt and pt["bot_difficulty"].notna().any():
        parts.append(one_hot(pt, "bot_difficulty", DIFFICULTIES))
    x = pd.concat(parts, axis=1)
    x = x.drop(columns=[f"{k}_{v}" for k, v in REFERENCE.items() if f"{k}_{v}" in x])
    x["player_count"] = pt["player_count"].astype(float)
    return x.loc[:, x.std() > 0]


def _fit(x: pd.DataFrame, y: pd.Series) -> np.ndarray:
    # Weak L2: unpenalised fits explode on rare levels that separate perfectly in a resample.
    model = LogisticRegression(C=REGRESSION_C, max_iter=2000).fit(x, y)
    return model.coef_[0]


def regression(pt: pd.DataFrame, n_boot: int = BOOTSTRAP) -> pd.DataFrame:
    """Odds ratios (vs REFERENCE levels) controlling for rule and player count, with
    95 % match-bootstrap intervals."""
    x, y = _design(pt), pt["win"]
    coef = _fit(x, y)
    rng = np.random.default_rng(SEED)
    matches = pt["match_id"].unique()
    rows_of = pt.groupby("match_id").indices
    boots = []
    for _ in range(n_boot):
        pick = rng.choice(matches, size=len(matches), replace=True)
        idx = np.concatenate([rows_of[m] for m in pick])
        if pt["win"].iloc[idx].nunique() < 2:
            continue
        boots.append(_fit(x.iloc[idx], y.iloc[idx]))
    b = np.array(boots)
    return pd.DataFrame({"term": x.columns, "odds_ratio": np.exp(coef),
                         "ci_low": np.exp(np.percentile(b, 2.5, axis=0)),
                         "ci_high": np.exp(np.percentile(b, 97.5, axis=0))})


def ringouts(events: pd.DataFrame, matches: pd.DataFrame) -> pd.DataFrame:
    """One row per ring-out: match, arena, rule, victim, cause, zone, self-destruct flag."""
    cols = ["match_id", "arena", "rule", "actor_slot", "cause", "zone", "self_destruct"]
    if events.empty:
        return pd.DataFrame(columns=cols)
    ro = events[events["type"] == "ringout"].copy()
    ro["cause"] = ro["payload"].map(lambda p: p.get("cause", "unknown"))
    ro["zone"] = ro["payload"].map(lambda p: p.get("zone", "unknown"))
    # attacker_slot is -1 (not null) for uncredited falls; cause "self" marks self-destructs.
    ro["self_destruct"] = ro["cause"] == "self"
    meta = matches.rename(columns={"id": "match_id"})[["match_id", "arena", "rule"]]
    return ro.merge(meta, on="match_id")[cols]


def ringout_table(ro: pd.DataFrame, by: str) -> pd.DataFrame:
    """Share of ring-outs per cause/zone within each ``by`` group."""
    counts = ro.groupby([by, "cause", "zone"]).size().rename("count").reset_index()
    counts["share"] = counts["count"] / counts.groupby(by)["count"].transform("sum")
    return counts.sort_values([by, "count"], ascending=[True, False]).reset_index(drop=True)
