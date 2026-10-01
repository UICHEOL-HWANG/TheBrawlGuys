"""Supabase export: PostgREST tables -> ``<out>/<table>.csv`` (the layout io.load_dataset reads).

Credentials come only from the environment and are never written anywhere:
``SUPABASE_URL`` (https://<project>.supabase.co) and ``SUPABASE_SERVICE_ROLE_KEY``. RLS lets a
user key read only its own matches, so a full export needs the service role key — keep it in
your shell or an untracked ``analysis/.env``. Needs the optional ``export`` extra (requests).
"""

from __future__ import annotations

import json
import os
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pandas as pd

TABLES = ("matches", "match_players", "match_events")
OPTIONAL_TABLES = ("match_inputs",)
# Primary keys: limit/offset paging needs a stable order or pages overlap / skip rows.
ORDER = {"matches": "id", "match_players": "match_id,slot", "match_events": "id",
         "match_inputs": "match_id,slot"}
PAGE = 1000
TIMEOUT_S = 30
ENV_URL = "SUPABASE_URL"
ENV_KEY = "SUPABASE_SERVICE_ROLE_KEY"

Fetch = Callable[[str, dict[str, str], dict[str, str]], list[dict[str, Any]]]


def credentials() -> tuple[str, str]:
    url, key = os.environ.get(ENV_URL, ""), os.environ.get(ENV_KEY, "")
    if not url or not key:
        raise RuntimeError(f"set {ENV_URL} and {ENV_KEY} in the environment (never commit them)")
    return url.rstrip("/"), key


def _http_fetch(url: str, headers: dict[str, str], params: dict[str, str]) -> list[dict[str, Any]]:
    import requests  # optional dependency (extra "export")

    resp = requests.get(url, headers=headers, params=params, timeout=TIMEOUT_S)
    resp.raise_for_status()
    return resp.json()


def _jsonify(value: Any) -> Any:
    return json.dumps(value) if isinstance(value, dict | list) else value


def fetch_table(base: str, key: str, table: str, fetch: Fetch = _http_fetch) -> pd.DataFrame:
    """All rows of ``table``, paged with limit/offset; jsonb values become JSON text."""
    headers = {"apikey": key, "Authorization": f"Bearer {key}"}
    rows: list[dict[str, Any]] = []
    while True:
        params = {"select": "*", "order": ORDER.get(table, "id"), "limit": str(PAGE),
                  "offset": str(len(rows))}
        page = fetch(f"{base}/rest/v1/{table}", headers, params)
        rows.extend(page)
        if len(page) < PAGE:
            break
    return pd.DataFrame(rows).map(_jsonify) if rows else pd.DataFrame()


def export(out: Path, with_inputs: bool = False, fetch: Fetch = _http_fetch) -> list[Path]:
    """Write every analysis table (plus match_inputs on request) as CSV under ``out``."""
    base, key = credentials()
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for table in TABLES + (OPTIONAL_TABLES if with_inputs else ()):
        path = out / f"{table}.csv"
        fetch_table(base, key, table, fetch).to_csv(path, index=False)
        written.append(path)
    return written
