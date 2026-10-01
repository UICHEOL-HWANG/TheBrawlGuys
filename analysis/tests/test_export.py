from pathlib import Path

import pytest

from brawl_analysis import export
from brawl_analysis.cli import main
from brawl_analysis.io import load_table


def _fake_fetch(pages: dict[str, list[dict]]):
    calls = []

    def fetch(url, headers, params):
        calls.append((url, headers, params))
        rows = pages[url.rsplit("/", 1)[1]]
        offset, limit = int(params["offset"]), int(params["limit"])
        return rows[offset:offset + limit]

    return fetch, calls


def test_export_pages_and_writes_csv(tmp_path: Path, monkeypatch):
    monkeypatch.setenv(export.ENV_URL, "https://example.supabase.co/")
    monkeypatch.setenv(export.ENV_KEY, "test-key")
    monkeypatch.setattr(export, "PAGE", 2)
    pages = {"matches": [{"id": i} for i in range(5)], "match_players": [],
             "match_events": [{"match_id": "m", "payload": {"cause": "self"}}]}
    fetch, calls = _fake_fetch(pages)
    written = export.export(tmp_path, fetch=fetch)
    assert [p.name for p in written] == ["matches.csv", "match_players.csv", "match_events.csv"]
    assert len(load_table(tmp_path, "matches")) == 5
    assert load_table(tmp_path, "match_events")["payload"][0] == '{"cause": "self"}'
    url, headers, params = calls[0]
    assert url == "https://example.supabase.co/rest/v1/matches"
    assert params["order"] == "id", "stable order for limit/offset paging"
    assert headers["Authorization"] == "Bearer test-key"


def test_export_without_credentials_fails(tmp_path: Path, monkeypatch):
    monkeypatch.delenv(export.ENV_URL, raising=False)
    monkeypatch.delenv(export.ENV_KEY, raising=False)
    with pytest.raises(RuntimeError, match="SUPABASE_URL"):
        export.credentials()
    assert main(["export", "--out", str(tmp_path)]) == 1
