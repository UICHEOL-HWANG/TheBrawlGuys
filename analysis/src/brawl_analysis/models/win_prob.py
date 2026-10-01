"""M2 win probability: timeline row -> P(this slot's side wins).

HistGradientBoostingClassifier, out-of-fold predictions with GroupKFold by match_id (rows of
one match never sit on both sides of a split). Compared with two baselines: the prior
(1 / player_count, 0.5 in team) and a logistic regression on stock and damage differences.
Permutation importance is measured on one held-out group split.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

import numpy as np
import pandas as pd
from sklearn.calibration import calibration_curve
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, log_loss, roc_auc_score
from sklearn.model_selection import GroupKFold, GroupShuffleSplit

from brawl_analysis.features import timeline_matrix

SEED = 7
FOLDS = 5
CALIBRATION_BINS = 10
IMPORTANCE_REPEATS = 5
# Match-time buckets (seconds) for the per-phase metrics.
TIME_BUCKETS = (0, 15, 30, 60, 120, 1e9)
BASELINE_FEATURES = ["stock_diff", "damage_diff", "score_diff"]


@dataclass(frozen=True)
class WinProbResult:
    metrics: pd.DataFrame          # model x {log_loss, auc, brier}
    by_time: pd.DataFrame          # time bucket x {rows, log_loss, auc, brier}
    calibration: pd.DataFrame      # bin -> predicted, observed
    importance: pd.DataFrame       # feature -> mean, std (drop in log-loss)
    oof: pd.Series                 # out-of-fold P(win) per timeline row
    n_matches: int
    n_rows: int


def make_model() -> HistGradientBoostingClassifier:
    return HistGradientBoostingClassifier(max_iter=300, learning_rate=0.05, max_leaf_nodes=31,
                                          l2_regularization=1.0, random_state=SEED)


def _baseline_logit() -> LogisticRegression:
    return LogisticRegression(max_iter=1000)


def _scores(y: pd.Series, p: np.ndarray) -> dict[str, float]:
    p = np.clip(p, 1e-6, 1 - 1e-6)
    auc = roc_auc_score(y, p) if y.nunique() > 1 else float("nan")
    return {"log_loss": log_loss(y, p, labels=[0, 1]), "auc": auc, "brier": brier_score_loss(y, p)}


def _oof(make: Callable, x: pd.DataFrame, y: pd.Series, groups: pd.Series,
         folds: int) -> np.ndarray:
    out = np.zeros(len(y))
    for train, test in GroupKFold(n_splits=folds).split(x, y, groups):
        model = make().fit(x.iloc[train], y.iloc[train])
        out[test] = model.predict_proba(x.iloc[test])[:, 1]
    return out


def _prior(tl: pd.DataFrame) -> np.ndarray:
    return np.where(tl["rule"] == "team", 0.5, 1.0 / tl["player_count"]).astype(float)


def _by_time(tl: pd.DataFrame, y: pd.Series, p: np.ndarray) -> pd.DataFrame:
    buckets = pd.cut(tl["t"], bins=list(TIME_BUCKETS), right=False)
    rows = []
    for bucket, idx in tl.groupby(buckets, observed=True).groups.items():
        pos = tl.index.get_indexer(idx)
        rows.append({"t_bucket_s": str(bucket), "rows": len(idx), **_scores(y.iloc[pos], p[pos])})
    return pd.DataFrame(rows)


def _importance(x: pd.DataFrame, y: pd.Series, groups: pd.Series) -> pd.DataFrame:
    split = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=SEED)
    train, test = next(split.split(x, y, groups))
    model = make_model().fit(x.iloc[train], y.iloc[train])
    r = permutation_importance(model, x.iloc[test], y.iloc[test], scoring="neg_log_loss",
                               n_repeats=IMPORTANCE_REPEATS, random_state=SEED)
    imp = pd.DataFrame({"feature": x.columns, "mean": r.importances_mean, "std": r.importances_std})
    return imp.sort_values("mean", ascending=False).reset_index(drop=True)


def train_win_prob(tl: pd.DataFrame, folds: int = FOLDS) -> WinProbResult:
    """Grouped-CV evaluation of the win-probability model on a timeline_table frame."""
    tl = tl.reset_index(drop=True)
    x, y, groups = timeline_matrix(tl)
    folds = min(folds, groups.nunique())
    p_model = _oof(make_model, x, y, groups, folds)
    p_logit = _oof(_baseline_logit, x[BASELINE_FEATURES].fillna(0.0), y, groups, folds)
    metrics = pd.DataFrame({
        "prior (1/n)": _scores(y, _prior(tl)),
        "logistic (stock/damage/score diff)": _scores(y, p_logit),
        "HistGradientBoosting": _scores(y, p_model),
    }).T
    observed, predicted = calibration_curve(y, p_model, n_bins=CALIBRATION_BINS)
    return WinProbResult(
        metrics=metrics, by_time=_by_time(tl, y, p_model),
        calibration=pd.DataFrame({"predicted": predicted, "observed": observed}),
        importance=_importance(x, y, groups),
        oof=pd.Series(p_model, index=tl.index, name="p_win"),
        n_matches=int(groups.nunique()), n_rows=len(tl))
