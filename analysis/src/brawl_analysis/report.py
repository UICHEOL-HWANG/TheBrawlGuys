"""Markdown + PNG reports: index, win probability (M2), balance (M5), churn (M1 stub)."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from brawl_analysis import charts
from brawl_analysis.features import finished_ids, player_table, timeline_table
from brawl_analysis.io import Dataset
from brawl_analysis.markdown import pct, table
from brawl_analysis.models import balance, churn
from brawl_analysis.models.win_prob import WinProbResult, train_win_prob

BOT_CAVEAT = ("> **Bot-only data.** Every slot is a scripted BotController (difficulty presets "
              "+ jitter). Results describe how the *bots* use each character and arena, not how "
              "people will. Use them to validate the pipeline and spot gross imbalances only.")


def _write(path: Path, lines: list[str]) -> Path:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def _source(ds: Dataset) -> str:
    if "platform" not in ds.matches:
        return "?"
    return ", ".join(sorted(ds.matches["platform"].astype(str).unique()))


def write_index(ds: Dataset, out: Path) -> Path:
    rules = ds.matches["rule"].value_counts().to_dict()
    counts = ds.matches["player_count"].value_counts().sort_index().to_dict()
    return _write(out / "index.md", [
        "# Analysis reports", "", f"Source platform(s): `{_source(ds)}`", "",
        f"- matches: {len(ds.matches)} (finished: {len(finished_ids(ds))})",
        f"- match_players rows: {len(ds.players)}", f"- match_events rows: {len(ds.events)}",
        f"- timeline rows (1 Hz): {len(ds.timeline)}",
        f"- rules: {rules}", f"- player counts: {counts}", "",
        "Reports: [win probability](win_probability.md) · [balance](balance.md) · "
        "[churn (stub)](churn.md)",
    ])


def _example_match(tl: pd.DataFrame, res: WinProbResult) -> str:
    """The 1v1 stock match whose predicted P(win) moves the most (falls back to any match)."""
    cand = tl[(tl["rule"] == "stock") & (tl["player_count"] == 2)]
    pool = cand if not cand.empty else tl
    spread = res.oof.loc[pool.index].groupby(pool["match_id"]).std()
    return str(spread.idxmax())


def write_win_prob(ds: Dataset, out: Path) -> Path:
    tl = timeline_table(ds)
    res = train_win_prob(tl)
    charts.calibration(res.calibration, out / "win_prob_calibration.png")
    charts.importance(res.importance, out / "win_prob_importance.png")
    charts.match_curve(tl, res.oof, _example_match(tl, res), out / "win_prob_example.png")
    return _write(out / "win_probability.md", [
        "# M2 — Win probability (timeline → does this slot's side win)", "", BOT_CAVEAT, "",
        f"{res.n_rows} timeline rows from {res.n_matches} finished matches, 5-fold GroupKFold "
        "by match_id (out-of-fold predictions). Features are only values known at that tick "
        "(state, side/foe stocks, damage, score, edge distance, gauge, time, rule/arena/"
        "character); no duration or final counters.", "",
        "## Metrics (lower log-loss / Brier is better)", "", table(res.metrics, index=True), "",
        "## By match phase", "", table(res.by_time), "",
        "## Calibration", "", "![calibration](win_prob_calibration.png)", "",
        table(res.calibration), "",
        "## Permutation importance (held-out 25 % of matches)", "",
        "![importance](win_prob_importance.png)", "", table(res.importance.head(15)), "",
        "## Example match", "", "![example](win_prob_example.png)", "",
        "Per-slot probabilities are not renormalised to sum to the number of winners; in "
        "FFA they are independent per-slot estimates.",
    ])


def _balance_tables(pt: pd.DataFrame) -> dict[str, pd.DataFrame]:
    cols = ["n", "wins", "win_rate", "ci_low", "ci_high", "expected", "excess"]
    one_v_one = pt[(pt["rule"] == "stock") & (pt["player_count"] == 2)]
    return {
        "character": balance.win_rates(pt, "character")[["character", *cols]],
        "character (1v1 stock only)": balance.win_rates(one_v_one, "character")[
            ["character", *cols]],
        "style": balance.win_rates(pt, "style")[["style", *cols]],
        "arena x character": balance.win_rates(pt, ["arena", "character"])[
            ["arena", "character", "n", "win_rate", "expected", "excess"]],
        "bot preset (bot_difficulty column)": balance.win_rates(pt, "bot_difficulty")[
            ["bot_difficulty", *cols]],
    }


def write_balance(ds: Dataset, out: Path) -> Path:
    pt = player_table(ds)
    tables = _balance_tables(pt)
    reg = balance.regression(pt)
    ro = balance.ringouts(ds.events, ds.matches)
    by_arena = balance.ringout_table(ro, "arena")
    charts.excess_bars(tables["character"], "character", out / "balance_character.png",
                       "Character win rate vs chance (all rules)")
    charts.ringout_shares(by_arena, "arena", out / "balance_ringouts.png")
    lines = ["# M5 — Balance (character / arena / style)", "", BOT_CAVEAT, "",
             f"{len(pt)} slot rows from {pt['match_id'].nunique()} finished matches. "
             "`expected` = chance share (1/players, 0.5 in team); `excess` = win_rate − expected.",
             "", "![character](balance_character.png)", ""]
    for name, t in tables.items():
        lines += [f"## Win rate by {name}", "", table(t), ""]
    lines += ["## Logistic regression (odds ratios, match-bootstrap 95 % CI)", "",
              "Reference levels: " + ", ".join(f"{k}={v}" for k, v in balance.REFERENCE.items())
              + "; controls: rule, player_count, arena, bot preset.", "", table(reg), "",
              "## Ring-outs by arena (cause / zone share)", "",
              f"{len(ro)} ring-outs; self-destructs: {pct(float(ro['self_destruct'].mean()))}.",
              "", "![ringouts](balance_ringouts.png)", "", table(by_arena)]
    return _write(out / "balance.md", lines)


def write_churn(ds: Dataset, out: Path) -> Path:
    has_users = "user_id" in ds.matches and ds.matches["user_id"].notna().any()
    users = churn.user_table(ds.matches, ds.players) if has_users else churn.stub_users()
    res = churn.evaluate(users, "supabase export" if has_users else "GENERATED STUB")
    note = "" if has_users else ("This dataset has no users, so the pipeline ran on a generated "
                                 "stub with known effects. The numbers below only prove the "
                                 "pipeline runs end to end.")
    return _write(out / "churn.md", [
        "# M1 — Early churn (first session → returned within 7 days)", "",
        "> **NEEDS REAL USERS.** " + note, "",
        f"- source: {res.source}", f"- users: {res.n_users}",
        f"- base return rate: {pct(res.base_rate)}",
        f"- out-of-fold AUC: {res.auc:.3f}", f"- out-of-fold log-loss: {res.log_loss:.3f}", "",
        "Features (first session only): " + ", ".join(churn.NUMERIC + churn.CATEGORICAL) + ".",
        "Label: `returned_7d` — another session within 7 days of the first session's start.",
    ])


def write_all(ds: Dataset, out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    written = [write_index(ds, out), write_balance(ds, out), write_churn(ds, out)]
    if ds.has_timeline:
        written.append(write_win_prob(ds, out))
    return written
