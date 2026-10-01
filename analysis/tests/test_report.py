from pathlib import Path

from conftest import FIXTURE

from brawl_analysis.cli import main


def test_cli_report_writes_markdown_and_charts(tmp_path: Path):
    assert main(["report", "--data", str(FIXTURE), "--out", str(tmp_path)]) == 0
    for name in ["index.md", "balance.md", "churn.md", "win_probability.md",
                 "win_prob_calibration.png", "balance_character.png"]:
        assert (tmp_path / name).stat().st_size > 0
    assert "NEEDS REAL USERS" in (tmp_path / "churn.md").read_text()


def test_cli_missing_data_returns_error(tmp_path: Path):
    assert main(["report", "--data", str(tmp_path / "missing"), "--out", str(tmp_path)]) == 1
