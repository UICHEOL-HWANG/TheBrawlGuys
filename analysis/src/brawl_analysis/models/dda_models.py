"""DDA models exported to the game (PRD-BOT-05/06): skill estimator and win probability with d.

* **Skill estimator** — the probing bot's ``probe_features`` (ProbeObserver.FEATURES) regress the
  true dial value of the "player" it probed (synthetic slot 0, ``bot_d_start``). Ridge on
  standardized features; 5-fold CV MAE / R^2 against the mean baseline.
* **Win probability with d** — logistic regression on the DdaFeatures columns (state, side/foe
  and d_self / d_foe / d_diff from ``timeline.bot_d``), grouped CV by match. Logistic so the game
  can run it exactly in GDScript (src/input/linear_model.gd).

Both export as standardized linear models: ``{"kind", "features", "mean", "scale", "coef",
"intercept", "clip"?, "metrics", "fixtures"}``; fixtures are rows with the Python prediction the
GUT tests replay.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression, LogisticRegression, Ridge
from sklearn.metrics import brier_score_loss, log_loss, mean_absolute_error, r2_score, roc_auc_score
from sklearn.model_selection import GroupKFold, KFold
from sklearn.preprocessing import StandardScaler

from brawl_analysis.features import finished_ids, timeline_table
from brawl_analysis.io import Dataset, _json

SEED = 7
FOLDS = 5
FIXTURES = 12
# src/input/probe_observer.gd FEATURES (same order).
PROBE_FEATURES = [
    "react_ticks",
    "response_rate",
    "dodge_rate",
    "tech_rate",
    "punish_rate",
    "damage_share",
    "attack_rate",
    "edge_share",
]
ESTIMATOR_EXTRA = ["player_count"]
# src/input/dda_features.gd FEATURES (same order and definitions).
DDA_FEATURES = [
    "t",
    "player_count",
    "damage",
    "stocks",
    "edge_dist",
    "side_stocks",
    "side_damage",
    "foe_best_stocks",
    "foe_damage",
    "stock_diff",
    "damage_diff",
    "score_diff",
    "foe_sides_alive",
    "d_self",
    "d_foe",
    "d_diff",
    "is_team",
    "is_timed",
]
# The exported model sees skill only as d_diff: with separate d_self / d_foe terms it learned a
# level effect from the multi-player mix (an even match at d = 0.9 read as p = 0.44), which made
# DDA drift strong bots down. Relative skill keeps an even match even at every level.
WIN_PROB_FEATURES = [f for f in DDA_FEATURES if f not in ("d_self", "d_foe")]
DEFAULT_D = 0.5


@dataclass
class LinearExport:
    """A standardized linear model in the game's JSON shape."""

    name: str
    kind: str
    features: list[str]
    mean: list[float]
    scale: list[float]
    coef: list[float]
    intercept: float
    metrics: dict = field(default_factory=dict)
    fixtures: list[dict] = field(default_factory=list)
    clip: list[float] | None = None

    def to_dict(self) -> dict:
        out = {
            "name": self.name,
            "kind": self.kind,
            "features": self.features,
            "mean": self.mean,
            "scale": self.scale,
            "coef": self.coef,
            "intercept": self.intercept,
            "metrics": self.metrics,
            "fixtures": self.fixtures,
        }
        if self.clip is not None:
            out["clip"] = self.clip
        return out

    def predict(self, x: pd.DataFrame) -> np.ndarray:
        z = self.intercept + (
            (x[self.features].to_numpy(float) - np.array(self.mean)) / np.array(self.scale)
        ) @ np.array(self.coef)
        if self.kind == "logistic":
            return 1.0 / (1.0 + np.exp(-z))
        lo, hi = self.clip or (-np.inf, np.inf)
        return np.clip(z, lo, hi)


def _export(
    name: str,
    kind: str,
    scaler: StandardScaler,
    model,
    features: list[str],
    clip: list[float] | None = None,
) -> LinearExport:
    coef = np.ravel(model.coef_)
    intercept = float(np.ravel([model.intercept_])[0])
    scale = [float(s) if s > 0 else 1.0 for s in scaler.scale_]
    return LinearExport(
        name=name,
        kind=kind,
        features=list(features),
        mean=[float(m) for m in scaler.mean_],
        scale=scale,
        coef=[float(c) for c in coef],
        intercept=intercept,
        clip=clip,
    )


def _fixtures(exp: LinearExport, x: pd.DataFrame) -> list[dict]:
    rows = x.sample(min(FIXTURES, len(x)), random_state=SEED)
    preds = exp.predict(rows)
    return [
        {"x": {k: float(v) for k, v in r.items()}, "y": float(p)}
        for (_, r), p in zip(rows[exp.features].iterrows(), preds, strict=True)
    ]


# --- Skill estimator -------------------------------------------------------------------------


def probe_table(ds: Dataset) -> pd.DataFrame:
    """One row per probed match: probe features + player_count + the probed slot's true d."""
    p = ds.players
    if "probe_features" not in p or "bot_d_start" not in p:
        return pd.DataFrame(columns=PROBE_FEATURES + ESTIMATOR_EXTRA + ["d", "match_id"])
    probers = p[p["probe_target_slot"].notna()].copy()
    feats = pd.DataFrame([_json(v) for v in probers["probe_features"]], index=probers.index)
    probers = pd.concat([probers[["match_id", "probe_target_slot"]], feats], axis=1)
    probers["probe_target_slot"] = probers["probe_target_slot"].astype(int)
    target = p[["match_id", "slot", "bot_d_start"]].rename(
        columns={"slot": "probe_target_slot", "bot_d_start": "d"}
    )
    out = probers.merge(target, on=["match_id", "probe_target_slot"])
    counts = ds.matches.rename(columns={"id": "match_id"})[["match_id", "player_count"]]
    out = out.merge(counts, on="match_id").dropna(subset=PROBE_FEATURES + ["d"])
    return out.reset_index(drop=True)


def train_estimator(probes: pd.DataFrame, folds: int = FOLDS) -> LinearExport:
    """Ridge regression probe features -> d with CV metrics; the export fits on every row."""
    feats = PROBE_FEATURES + ESTIMATOR_EXTRA
    x, y = probes[feats].astype(float), probes["d"].astype(float)
    oof = np.zeros(len(y))
    for train, test in KFold(n_splits=min(folds, len(y)), shuffle=True, random_state=SEED).split(x):
        sc = StandardScaler().fit(x.iloc[train])
        m = Ridge(alpha=1.0).fit(sc.transform(x.iloc[train]), y.iloc[train])
        oof[test] = np.clip(m.predict(sc.transform(x.iloc[test])), 0.0, 1.0)
    sc = StandardScaler().fit(x)
    model = Ridge(alpha=1.0).fit(sc.transform(x), y)
    exp = _export("skill_estimator", "linear", sc, model, feats, clip=[0.0, 1.0])
    one_v_one = (probes["player_count"] == 2).to_numpy()
    exp.metrics = {
        "rows": int(len(y)),
        "mae": float(mean_absolute_error(y, oof)),
        "r2": float(r2_score(y, oof)),
        "baseline_mae": float(mean_absolute_error(y, np.full(len(y), y.mean()))),
        "mae_1v1": float(mean_absolute_error(y[one_v_one], oof[one_v_one]))
        if one_v_one.any()
        else None,
        "r2_1v1": float(r2_score(y[one_v_one], oof[one_v_one])) if one_v_one.sum() > 1 else None,
    }
    exp.fixtures = _fixtures(exp, x)
    return exp


# --- Win probability with d ------------------------------------------------------------------


def dda_timeline(ds: Dataset) -> pd.DataFrame:
    """timeline_table plus the DdaFeatures d columns (d_self, d_foe, d_diff, is_team, is_timed)."""
    tl = timeline_table(ds)
    if "bot_d" not in tl:
        tl["bot_d"] = DEFAULT_D
    tl["bot_d"] = pd.to_numeric(tl["bot_d"], errors="coerce").fillna(DEFAULT_D)
    pair = tl[["match_id", "tick", "slot", "side", "bot_d"]]
    both = pair.merge(pair, on=["match_id", "tick"], suffixes=("", "_o"))
    foes = (
        both[both["side"] != both["side_o"]]
        .groupby(["match_id", "tick", "slot"], as_index=False)
        .agg(d_foe=("bot_d_o", "mean"))
    )
    tl = tl.merge(foes, on=["match_id", "tick", "slot"], how="left")
    tl["d_self"] = tl["bot_d"]
    tl["d_foe"] = tl["d_foe"].fillna(DEFAULT_D)
    tl["d_diff"] = tl["d_self"] - tl["d_foe"]
    tl["is_team"] = (tl["rule"] == "team").astype(float)
    tl["is_timed"] = (tl["rule"] == "timed").astype(float)
    tl["foe_sides_alive"] = tl["foe_sides_alive"].astype(float)
    return tl[tl["match_id"].isin(finished_ids(ds))].reset_index(drop=True)


def _scores(y: pd.Series, p: np.ndarray) -> dict[str, float]:
    p = np.clip(p, 1e-6, 1 - 1e-6)
    auc = float(roc_auc_score(y, p)) if pd.Series(y).nunique() > 1 else float("nan")
    return {
        "log_loss": float(log_loss(y, p, labels=[0, 1])),
        "auc": auc,
        "brier": float(brier_score_loss(y, p)),
    }


def _logit_oof(x: pd.DataFrame, y: pd.Series, groups: pd.Series, folds: int) -> np.ndarray:
    out = np.zeros(len(y))
    for train, test in GroupKFold(n_splits=min(folds, groups.nunique())).split(x, y, groups):
        sc = StandardScaler().fit(x.iloc[train])
        m = LogisticRegression(max_iter=2000).fit(sc.transform(x.iloc[train]), y.iloc[train])
        out[test] = m.predict_proba(sc.transform(x.iloc[test]))[:, 1]
    return out


def train_win_prob_dda(tl: pd.DataFrame, folds: int = FOLDS) -> LinearExport:
    """Logistic win probability on WIN_PROB_FEATURES; metrics with and without d_diff."""
    x, y, groups = tl[WIN_PROB_FEATURES].astype(float).fillna(0.0), tl["win"], tl["match_id"]
    no_d = [f for f in WIN_PROB_FEATURES if not f.startswith("d_")]
    p_full = _logit_oof(x, y, groups, folds)
    p_no_d = _logit_oof(x[no_d], y, groups, folds)
    sc = StandardScaler().fit(x)
    model = LogisticRegression(max_iter=2000).fit(sc.transform(x), y)
    exp = _export("win_prob_dda", "logistic", sc, model, WIN_PROB_FEATURES)
    early = (tl["t"] <= 30).to_numpy()
    exp.metrics = {
        "rows": int(len(y)),
        "matches": int(groups.nunique()),
        "with_d": _scores(y, p_full),
        "without_d": _scores(y, p_no_d),
        "with_d_first_30s": _scores(y[early], p_full[early]) if early.any() else None,
        "without_d_first_30s": _scores(y[early], p_no_d[early]) if early.any() else None,
    }
    exp.fixtures = _fixtures(exp, x)
    return exp


def d_effect(probes: pd.DataFrame) -> pd.DataFrame:
    """Per-feature slope against the true d (how each probe feature moves with skill)."""
    rows = []
    for f in PROBE_FEATURES:
        m = LinearRegression().fit(probes[["d"]], probes[f])
        corr = float(np.corrcoef(probes["d"], probes[f])[0, 1]) if probes[f].std() > 0 else 0.0
        rows.append({"feature": f, "slope_per_d": float(m.coef_[0]), "corr": corr})
    return pd.DataFrame(rows)
