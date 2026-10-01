"""Tiny markdown helpers (no tabulate dependency)."""

from __future__ import annotations

import math

import pandas as pd

DECIMALS = 3


def _cell(value: object) -> str:
    if isinstance(value, float):
        return "" if math.isnan(value) else f"{value:.{DECIMALS}f}"
    return str(value)


def table(df: pd.DataFrame, index: bool = False) -> str:
    """A GitHub markdown table for ``df``."""
    frame = df.reset_index() if index else df
    head = "| " + " | ".join(str(c) for c in frame.columns) + " |"
    rule = "|" + "|".join("---" for _ in frame.columns) + "|"
    rows = ["| " + " | ".join(_cell(v) for v in row) + " |"
            for row in frame.itertuples(index=False)]
    return "\n".join([head, rule, *rows])


def pct(value: float) -> str:
    return f"{100 * value:.1f}%"
