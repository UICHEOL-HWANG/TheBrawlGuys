"""PNG charts for the reports (matplotlib, Agg backend, no display needed)."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

ACCENT = "#3b6fb6"
MUTED = "#9aa5b1"
DPI = 120


def _save(fig: plt.Figure, path: Path) -> Path:
    fig.tight_layout()
    fig.savefig(path, dpi=DPI)
    plt.close(fig)
    return path


def calibration(cal: pd.DataFrame, path: Path) -> Path:
    fig, ax = plt.subplots(figsize=(4.5, 4.5))
    ax.plot([0, 1], [0, 1], color=MUTED, linestyle="--", label="perfect")
    ax.plot(cal["predicted"], cal["observed"], marker="o", color=ACCENT, label="model (OOF)")
    ax.set_xlabel("predicted P(win)")
    ax.set_ylabel("observed win rate")
    ax.set_title("Win probability calibration")
    ax.legend(frameon=False)
    return _save(fig, path)


def importance(imp: pd.DataFrame, path: Path, top: int = 15) -> Path:
    head = imp.head(top).iloc[::-1]
    fig, ax = plt.subplots(figsize=(6, 0.32 * len(head) + 1))
    ax.barh(head["feature"], head["mean"], xerr=head["std"], color=ACCENT)
    ax.set_xlabel("log-loss increase when shuffled")
    ax.set_title("Permutation importance (held-out matches)")
    return _save(fig, path)


def match_curve(tl: pd.DataFrame, p: pd.Series, match_id: str, path: Path) -> Path:
    rows = tl.assign(p=p)
    rows = rows[rows["match_id"] == match_id]
    fig, ax = plt.subplots(figsize=(7, 3.5))
    for slot, g in rows.groupby("slot"):
        won = g["win"].iloc[0] == 1
        label = f"slot {slot} {g['character'].iloc[0]}" + (" (won)" if won else "")
        ax.plot(g["t"], g["p"], linewidth=2.2 if won else 1.2, label=label)
    ax.set_ylim(0, 1)
    ax.set_xlabel("match time (s)")
    ax.set_ylabel("P(win)")
    ax.set_title(f"Win probability over one match ({rows['rule'].iloc[0]}, out-of-fold)")
    ax.legend(frameon=False, fontsize=8)
    return _save(fig, path)


def excess_bars(table: pd.DataFrame, key: str, path: Path, title: str) -> Path:
    t = table.sort_values("excess")
    err = [t["win_rate"] - t["ci_low"], t["ci_high"] - t["win_rate"]]
    fig, ax = plt.subplots(figsize=(6, 0.45 * len(t) + 1.2))
    ax.barh(t[key].astype(str), t["excess"], xerr=err, color=ACCENT)
    ax.axvline(0, color=MUTED)
    ax.set_xlabel("win rate - chance share (95% Wilson CI)")
    ax.set_title(title)
    return _save(fig, path)


def ringout_shares(table: pd.DataFrame, by: str, path: Path) -> Path:
    t = table.assign(kind=table["cause"] + "/" + table["zone"])
    pivot = t.pivot_table(index=by, columns="kind", values="share", fill_value=0.0)
    fig, ax = plt.subplots(figsize=(7.5, 3.8))
    pivot.plot(kind="barh", stacked=True, ax=ax, colormap="tab20")
    ax.set_xlabel("share of ring-outs")
    ax.set_title(f"Ring-out cause / zone by {by}")
    ax.legend(frameon=False, fontsize=7, bbox_to_anchor=(1.0, 1.0), loc="upper left")
    return _save(fig, path)
