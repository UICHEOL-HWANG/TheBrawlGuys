"""Feature builders: per-slot match rows (balance) and per-timeline-row state (win probability).

Leakage rule for the timeline: every feature must be known at that tick. Nothing derived from
``duration_ticks``, final counters (match_players stats) or later rows is used; the label (did
this slot win) comes from match_players.result and is never a feature.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from brawl_analysis.io import Dataset

CHARACTERS = ("barbarian", "rogue", "knight", "mage")
ARENAS = ("classic", "lakeside_camp", "log_bridge", "mushroom_forest", "foggy_forest")
RULES = ("stock", "team", "timed")
# Fighter.State values used as flags (src/sim/fighter.gd).
STATE_HITSTUN, STATE_KO, STATE_KNOCKDOWN = 4, 5, 12
# ModeConfig.timed_duration (seconds) — known before the match starts.
TIMED_DURATION_S = 120.0
FINISHED = ("win", "loss", "draw")

STATE_COLS = ["t", "player_count", "damage", "stocks", "edge_dist", "gauge", "holding_item",
              "on_ground", "guard_hp_ratio", "is_ko", "in_hitstun", "knocked_down", "time_left_s"]
SIDE_COLS = ["side_stocks", "side_damage", "side_score", "foe_best_stocks", "foe_total_stocks",
             "foe_damage", "foe_best_score", "foe_sides_alive", "stock_diff", "damage_diff",
             "score_diff"]


def finished_ids(ds: Dataset) -> pd.Index:
    """Matches where every slot has a final result (abandoned / tick-capped ones dropped)."""
    ok = ds.players.groupby("match_id")["result"].apply(lambda r: r.isin(FINISHED).all())
    return ok[ok].index


def _meta(ds: Dataset) -> pd.DataFrame:
    return ds.matches.rename(columns={"id": "match_id"})[
        ["match_id", "rule", "arena", "player_count"]]


def player_table(ds: Dataset) -> pd.DataFrame:
    """One row per (match, slot) of finished matches, with match context and expected win share."""
    df = ds.players.merge(_meta(ds), on="match_id", how="inner")
    df = df[df["match_id"].isin(finished_ids(ds))].copy()
    df["win"] = (df["result"] == "win").astype(int)
    df["expected_win"] = np.where(df["rule"] == "team", 0.5, 1.0 / df["player_count"])
    return df.reset_index(drop=True)


def one_hot(df: pd.DataFrame, column: str, values: tuple[str, ...]) -> pd.DataFrame:
    """Fixed-category one-hot so tiny datasets get the same columns as big ones."""
    return pd.DataFrame({f"{column}_{v}": (df[column] == v).astype(int) for v in values},
                        index=df.index)


def _sides(tl: pd.DataFrame) -> pd.DataFrame:
    """Per (match, tick, side) totals; a side is the team in team mode, else the slot."""
    return (tl.groupby(["match_id", "tick", "side"], as_index=False)
              .agg(side_stocks=("stocks", "sum"), side_damage=("damage", "mean"),
                   side_score=("score", "sum")))


def _foes(sides: pd.DataFrame) -> pd.DataFrame:
    """For each side, aggregates over the other sides at the same tick."""
    pair = sides.merge(sides, on=["match_id", "tick"], suffixes=("", "_o"))
    pair = pair[pair["side"] != pair["side_o"]].copy()
    pair["alive_o"] = (pair["side_stocks_o"] > 0).astype(int)
    return (pair.groupby(["match_id", "tick", "side"], as_index=False)
                .agg(foe_best_stocks=("side_stocks_o", "max"),
                     foe_total_stocks=("side_stocks_o", "sum"),
                     foe_damage=("side_damage_o", "mean"),
                     foe_best_score=("side_score_o", "max"),
                     foe_sides_alive=("alive_o", "sum")))


def timeline_table(ds: Dataset) -> pd.DataFrame:
    """Timeline rows of finished matches with state, side/foe and context features plus ``win``."""
    if not ds.has_timeline:
        raise ValueError("dataset has no timeline.csv (synthetic data or replay extractor needed)")
    labels = ds.players[["match_id", "slot", "character", "result"]]
    tl = ds.timeline.merge(_meta(ds), on="match_id").merge(labels, on=["match_id", "slot"])
    tl = tl[tl["match_id"].isin(finished_ids(ds))].copy()
    tl["side"] = np.where(tl["rule"] == "team", tl["team"], tl["slot"])
    sides = _sides(tl)
    keys = ["match_id", "tick", "side"]
    tl = tl.merge(sides, on=keys).merge(_foes(sides), on=keys)
    return _derive(tl).reset_index(drop=True)


def _derive(tl: pd.DataFrame) -> pd.DataFrame:
    out = tl.copy()
    out["is_ko"] = (out["state"] == STATE_KO).astype(int)
    out["in_hitstun"] = (out["state"] == STATE_HITSTUN).astype(int)
    out["knocked_down"] = (out["state"] == STATE_KNOCKDOWN).astype(int)
    out["holding_item"] = out["holding_item"].astype(int)
    out["on_ground"] = out["on_ground"].astype(int)
    out["time_left_s"] = np.where(out["rule"] == "timed", TIMED_DURATION_S - out["t"], np.nan)
    out["stock_diff"] = out["side_stocks"] - out["foe_best_stocks"]
    out["damage_diff"] = out["foe_damage"] - out["side_damage"]
    out["score_diff"] = out["side_score"] - out["foe_best_score"]
    out["win"] = (out["result"] == "win").astype(int)
    return out


def timeline_matrix(tl: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series, pd.Series]:
    """(X, y, groups) for the win-probability model; groups = match_id for grouped CV."""
    x = pd.concat([tl[STATE_COLS + SIDE_COLS].astype(float), one_hot(tl, "rule", RULES),
                   one_hot(tl, "arena", ARENAS), one_hot(tl, "character", CHARACTERS)], axis=1)
    return x, tl["win"], tl["match_id"]
