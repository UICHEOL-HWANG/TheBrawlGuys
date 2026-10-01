"""M1 early churn — pipeline and schema only. NEEDS REAL USERS.

``user_table`` turns a Supabase export (matches with ``user_id`` / ``session_id`` /
``started_at`` + match_players with ``controller``) into one row per user: features from the
user's FIRST session only, label ``returned_7d`` = the user played another session within
7 days after the first one started. Synthetic bot matches have no users, so the report runs
the same model on ``stub_users`` — a generated table with KNOWN effects whose only purpose is
to prove the pipeline end to end. Its metrics say nothing about the game.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import log_loss, roc_auc_score
from sklearn.model_selection import StratifiedKFold, cross_val_predict
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

SEED = 5
FOLDS = 5
RETURN_WINDOW = pd.Timedelta(days=7)
NUMERIC = ["first_session_matches", "first_match_won", "first_match_falls",
           "first_match_damage_taken", "first_session_losses", "first_match_duration_s"]
CATEGORICAL = ["input_device"]
LABEL = "returned_7d"
TICK_RATE = 60.0


@dataclass(frozen=True)
class ChurnResult:
    auc: float
    log_loss: float
    base_rate: float
    n_users: int
    source: str


def _local_rows(players: pd.DataFrame) -> pd.DataFrame:
    """The first human ("local") slot of each match."""
    if "controller" not in players:
        raise ValueError("match_players has no controller column (migration 0002)")
    local = players[players["controller"] == "local"]
    return local.sort_values("slot").drop_duplicates("match_id")


def _first_session_stats(m: pd.DataFrame, first: pd.DataFrame) -> pd.DataFrame:
    keys = first[["session_id"]].reset_index()
    session = m.merge(keys, on=["user_id", "session_id"])
    return session.groupby("user_id").agg(
        first_session_matches=("match_id", "size"),
        first_session_losses=("result", lambda r: int((r == "loss").sum())))


def _returned(m: pd.DataFrame, first: pd.DataFrame) -> pd.Index:
    starts = first[["session_id", "started_at"]].reset_index()
    later = m.merge(starts, on="user_id", suffixes=("", "_first"))
    later = later[(later["session_id"] != later["session_id_first"])
                  & (later["started_at"] - later["started_at_first"] <= RETURN_WINDOW)]
    return pd.Index(later["user_id"].unique())


def user_table(matches: pd.DataFrame, players: pd.DataFrame) -> pd.DataFrame:
    """One row per real user (Supabase export). Needs matches.user_id."""
    if "user_id" not in matches:
        raise ValueError("matches has no user_id: export with the service role (see README)")
    m = matches.rename(columns={"id": "match_id"}).drop(columns=["result"], errors="ignore")
    m["started_at"] = pd.to_datetime(m["started_at"], utc=True)
    m = m.merge(_local_rows(players), on="match_id", how="inner").sort_values("started_at")
    # head(1), not first(): first() fills nulls from later matches (future leakage).
    first = m.groupby("user_id", sort=False).head(1).set_index("user_id")
    # Right-censoring: users whose window has not closed by the export cannot be labelled yet.
    first = first[first["started_at"] <= m["started_at"].max() - RETURN_WINDOW]
    out = _first_session_stats(m, first).join(pd.DataFrame({
        "first_match_won": (first["result"] == "win").astype(int),
        "first_match_falls": first["falls"],
        "first_match_damage_taken": first["damage_taken"],
        "first_match_duration_s": first["duration_ticks"] / TICK_RATE,
        "input_device": first["input_device"],
    }))
    out[LABEL] = out.index.isin(_returned(m, first)).astype(int)
    return out.reset_index()


def stub_users(n: int = 2000, seed: int = SEED) -> pd.DataFrame:
    """Generated users with known effects (winning first and fewer falls -> return)."""
    rng = np.random.default_rng(seed)
    df = pd.DataFrame({
        "first_session_matches": rng.integers(1, 8, n),
        "first_match_won": rng.integers(0, 2, n),
        "first_match_falls": rng.integers(0, 4, n),
        "first_match_damage_taken": rng.gamma(4.0, 40.0, n),
        "first_match_duration_s": rng.normal(110, 30, n).clip(20),
        "input_device": rng.choice(["keyboard", "gamepad", "touch"], n, p=[0.5, 0.2, 0.3]),
    })
    df["first_session_losses"] = rng.binomial(df["first_session_matches"], 0.5)
    logit = (-0.6 + 0.8 * df["first_match_won"] - 0.35 * df["first_match_falls"]
             + 0.25 * df["first_session_matches"] - 0.4 * (df["input_device"] == "touch"))
    df[LABEL] = rng.binomial(1, 1 / (1 + np.exp(-logit)))
    return df


def make_pipeline() -> Pipeline:
    encode = ColumnTransformer([("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL)],
                               remainder="passthrough")
    model = HistGradientBoostingClassifier(max_iter=150, learning_rate=0.05, random_state=SEED)
    return Pipeline([("encode", encode), ("model", model)])


def evaluate(users: pd.DataFrame, source: str) -> ChurnResult:
    """Stratified k-fold out-of-fold AUC / log-loss of the churn pipeline."""
    x, y = users[NUMERIC + CATEGORICAL], users[LABEL]
    folds = StratifiedKFold(n_splits=FOLDS, shuffle=True, random_state=SEED)
    p = cross_val_predict(make_pipeline(), x, y, cv=folds, method="predict_proba")[:, 1]
    return ChurnResult(auc=roc_auc_score(y, p), log_loss=log_loss(y, p),
                       base_rate=float(y.mean()), n_users=len(users), source=source)
