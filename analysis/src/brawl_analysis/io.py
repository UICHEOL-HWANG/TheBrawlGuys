"""Load a dataset directory: synthetic (scripts/gen_dataset.gd) or a Supabase export.

Both use the Supabase table names as file names: ``matches.csv``, ``match_players.csv``,
``match_events.csv`` and, for synthetic data only (until the replay extractor runs on real
L0 logs), ``timeline.csv``. A directory may hold the files directly or in sub-directories
(generator shards); all found files of one table are concatenated. ``.parquet`` works too.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

TABLES = ("matches", "match_players", "match_events", "timeline")
REQUIRED = ("matches", "match_players")
# matches.rule only exists from migration 0004; older rows are stock.
DEFAULT_RULE = "stock"


@dataclass(frozen=True)
class Dataset:
    matches: pd.DataFrame
    players: pd.DataFrame
    events: pd.DataFrame
    timeline: pd.DataFrame

    @property
    def has_timeline(self) -> bool:
        return not self.timeline.empty


def _files(root: Path, table: str) -> list[Path]:
    return sorted(root.rglob(f"{table}.csv")) + sorted(root.rglob(f"{table}.parquet"))


def _read(path: Path) -> pd.DataFrame:
    if path.suffix == ".parquet":
        return pd.read_parquet(path)
    try:
        return pd.read_csv(path, low_memory=False)
    except pd.errors.EmptyDataError:  # an exported table with no rows
        return pd.DataFrame()


def load_table(root: Path, table: str) -> pd.DataFrame:
    files = _files(root, table)
    if not files:
        return pd.DataFrame()
    return pd.concat([_read(f) for f in files], ignore_index=True)


def _bool(series: pd.Series) -> pd.Series:
    if series.dtype == bool:
        return series
    return series.astype(str).str.lower().isin(["true", "1", "t"])


def _json(value: object) -> dict:
    if isinstance(value, dict):
        return value
    if not isinstance(value, str) or not value:
        return {}
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _normalize(tables: dict[str, pd.DataFrame]) -> Dataset:
    matches = tables["matches"].copy()
    if "rule" not in matches:
        matches["rule"] = DEFAULT_RULE
    matches["rule"] = matches["rule"].fillna(DEFAULT_RULE)
    players = tables["match_players"].copy()
    players["is_bot"] = _bool(players["is_bot"])
    events = tables["match_events"].copy()
    if not events.empty and "payload" in events:
        events["payload"] = events["payload"].map(_json)
    timeline = tables["timeline"].copy()
    for col in ("holding_item", "on_ground"):
        if col in timeline:
            timeline[col] = _bool(timeline[col])
    return Dataset(matches=matches, players=players, events=events, timeline=timeline)


def load_dataset(path: str | Path) -> Dataset:
    """Load every table under ``path``; raises if a required table is missing."""
    root = Path(path)
    if not root.is_dir():
        raise FileNotFoundError(f"dataset directory not found: {root}")
    tables = {t: load_table(root, t) for t in TABLES}
    missing = [t for t in REQUIRED if tables[t].empty]
    if missing:
        raise FileNotFoundError(f"{root}: missing table(s) {', '.join(missing)}")
    return _normalize(tables)
