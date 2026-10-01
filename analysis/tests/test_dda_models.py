"""DDA models: probe table, skill estimator, win probability with d, export + GDScript parity."""

import json
import re
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from brawl_analysis.cli import main
from brawl_analysis.io import load_dataset
from brawl_analysis.models.dda_models import (
    DDA_FEATURES,
    PROBE_FEATURES,
    dda_timeline,
    probe_table,
    train_estimator,
    train_win_prob_dda,
)

# gen_dataset --matches=24 --seed=1 --variant=off --models=none, events cut to probe/dda rows and
# the timeline thinned to one sample every 3 s.
FIXTURE = Path(__file__).parent / "fixtures" / "dda_tiny"
REPO = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="module")
def ds():
    return load_dataset(FIXTURE)


def _gd_list(path: Path, const: str) -> list[str]:
    text = path.read_text()
    block = re.search(const + r"[^=]*=\s*\[(.*?)\]", text, re.S).group(1)
    return re.findall(r'"([a-z_0-9]+)"', block)


def test_feature_names_match_the_game():
    assert _gd_list(REPO / "src/input/dda_features.gd", "const FEATURES") == DDA_FEATURES
    assert _gd_list(REPO / "src/input/probe_observer.gd", "const FEATURES") == PROBE_FEATURES


def test_probe_table_labels_with_the_probed_slot_d(ds):
    probes = probe_table(ds)
    assert len(probes) > 0
    assert set(PROBE_FEATURES) <= set(probes.columns)
    players = ds.players.set_index(["match_id", "slot"])
    for row in probes.head(5).itertuples():
        assert row.d == pytest.approx(players.loc[(row.match_id, 0), "bot_d_start"])


def test_estimator_export_matches_its_fixtures_and_reports_metrics(ds):
    exp = train_estimator(probe_table(ds), folds=3)
    for key in ("mae", "r2", "baseline_mae", "rows"):
        assert key in exp.metrics
    assert exp.kind == "linear" and exp.clip == [0.0, 1.0]
    for fx in exp.fixtures:
        x = pd.DataFrame({k: [v] for k, v in fx["x"].items()})
        assert exp.predict(x)[0] == pytest.approx(fx["y"])
        assert 0.0 <= fx["y"] <= 1.0


def test_dda_timeline_has_the_d_columns(ds):
    tl = dda_timeline(ds)
    assert set(DDA_FEATURES) <= set(tl.columns)
    assert np.allclose(tl["d_diff"], tl["d_self"] - tl["d_foe"])
    assert tl["d_self"].between(0, 1).all()


def test_win_prob_export_is_a_logistic_model(ds):
    exp = train_win_prob_dda(dda_timeline(ds), folds=3)
    assert exp.kind == "logistic" and set(exp.features) <= set(DDA_FEATURES)
    assert "d_diff" in exp.features and "d_self" not in exp.features, "relative skill only"
    assert "with_d" in exp.metrics and "without_d" in exp.metrics
    for fx in exp.fixtures:
        assert 0.0 < fx["y"] < 1.0


def test_export_models_cli_writes_game_json(tmp_path):
    models, reports = tmp_path / "models", tmp_path / "reports"
    rc = main(
        ["export-models", "--data", str(FIXTURE), "--models", str(models), "--out", str(reports)]
    )
    assert rc == 0
    for name in ("win_prob.json", "skill_estimator.json"):
        data = json.loads((models / name).read_text())
        n = len(data["features"])
        assert len(data["mean"]) == n == len(data["scale"]) == len(data["coef"])
        assert data["fixtures"]
    assert (reports / "dda.md").exists()
