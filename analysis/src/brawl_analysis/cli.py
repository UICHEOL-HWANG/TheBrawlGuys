"""Command line: ``python -m brawl_analysis report --data <dir> --out analysis/reports``."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from brawl_analysis.io import load_dataset
from brawl_analysis.report import write_all


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="brawl_analysis")
    sub = parser.add_subparsers(dest="command", required=True)
    report = sub.add_parser("report", help="write markdown + PNG reports for a dataset")
    report.add_argument("--data", required=True, type=Path,
                        help="dataset dir (synthetic generator output or Supabase export)")
    report.add_argument("--out", default=Path("reports"), type=Path, help="report directory")
    dump = sub.add_parser("export", help="download Supabase tables as CSV (env credentials)")
    dump.add_argument("--out", default=Path("data/supabase"), type=Path)
    dump.add_argument("--with-inputs", action="store_true", help="also export match_inputs (L0)")
    return parser


def _export(out: Path, with_inputs: bool) -> int:
    from brawl_analysis.export import export

    try:
        written = export(out, with_inputs)
    except RuntimeError as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    for path in written:
        print(f"wrote {path}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.command == "export":
        return _export(args.out, args.with_inputs)
    try:
        ds = load_dataset(args.data)
    except FileNotFoundError as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    for path in write_all(ds, args.out):
        print(f"wrote {path}")
    return 0
