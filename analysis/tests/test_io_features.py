from pathlib import Path

import pandas as pd
import pytest

from brawl_analysis.features import (
    ARENAS,
    SIDE_COLS,
    STATE_COLS,
    finished_ids,
    one_hot,
    player_table,
    timeline_matrix,
    timeline_table,
)
from brawl_analysis.io import Dataset, load_dataset


def test_load_reads_all_tables_and_defaults_rule(tiny):
    assert len(tiny.matches) == 8
    assert set(tiny.matches["rule"]) == {"stock", "team", "timed"}
    assert tiny.players["is_bot"].all()
    assert tiny.has_timeline
    ringout = tiny.events[tiny.events["type"] == "ringout"].iloc[0]
    assert "cause" in ringout["payload"]


def test_load_missing_dir_raises(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        load_dataset(tmp_path / "nope")
    with pytest.raises(FileNotFoundError, match="matches"):
        load_dataset(tmp_path)


def test_player_table_expected_share(tiny):
    pt = player_table(tiny)
    assert len(pt) == len(tiny.players)
    team = pt[pt["rule"] == "team"]
    assert (team["expected_win"] == 0.5).all()
    ffa = pt[pt["rule"] != "team"]
    assert (ffa["expected_win"] == 1.0 / ffa["player_count"]).all()
    wins = pt.groupby("match_id")["win"].sum()
    assert wins.loc[team["match_id"].unique()].eq(2).all()


def test_finished_ids_drops_abandoned(tiny):
    players = tiny.players.copy()
    first = players["match_id"].iloc[0]
    players.loc[players["match_id"] == first, "result"] = "abandoned"
    ds = Dataset(tiny.matches, players, tiny.events, tiny.timeline)
    assert first not in finished_ids(ds)


def test_timeline_features_side_and_foe(tiny):
    tl = timeline_table(tiny)
    assert set(STATE_COLS + SIDE_COLS) <= set(tl.columns)
    row = tl[(tl["rule"] == "stock") & (tl["player_count"] == 2)].iloc[0]
    foe = tl[(tl["match_id"] == row["match_id"]) & (tl["tick"] == row["tick"])
             & (tl["slot"] != row["slot"])].iloc[0]
    assert row["stock_diff"] == row["stocks"] - foe["stocks"]
    assert row["damage_diff"] == pytest.approx(foe["damage"] - row["damage"])
    team = tl[tl["rule"] == "team"].iloc[0]
    mates = tl[(tl["match_id"] == team["match_id"]) & (tl["tick"] == team["tick"])
               & (tl["team"] == team["team"])]
    assert team["side_stocks"] == mates["stocks"].sum()


def test_timeline_matrix_has_no_outcome_columns(tiny):
    tl = timeline_table(tiny)
    x, y, groups = timeline_matrix(tl)
    banned = {"win", "result", "duration_ticks", "winner_slot", "match_id"}
    assert not banned & set(x.columns)
    assert len(x) == len(y) == len(groups)
    assert x["time_left_s"].isna().sum() == (tl["rule"] != "timed").sum()


def test_one_hot_fixed_columns():
    df = pd.DataFrame({"c": ["a", "b"]})
    out = one_hot(df, "c", ("a", "b", "z"))
    assert list(out.columns) == ["c_a", "c_b", "c_z"]
    assert out["c_z"].sum() == 0


def test_arenas_cover_every_stage_and_encode_frozen_pond():
    # ArenaCatalog.ids(): "classic" + STAGE_IDS (src/sim/arena/arena_catalog.gd).
    assert ARENAS == ("classic", "lakeside_camp", "log_bridge", "mushroom_forest",
                      "foggy_forest", "frozen_pond")
    df = pd.DataFrame({"arena": ["frozen_pond", "classic"]})
    out = one_hot(df, "arena", ARENAS)
    assert "arena_frozen_pond" in out.columns
    assert out["arena_frozen_pond"].tolist() == [1, 0]
    assert out.sum(axis=1).tolist() == [1, 1]


def test_timeline_matrix_has_an_arena_column_per_arena(tiny):
    x, _, _ = timeline_matrix(timeline_table(tiny))
    assert [c for c in x.columns if c.startswith("arena_")] == [f"arena_{a}" for a in ARENAS]
