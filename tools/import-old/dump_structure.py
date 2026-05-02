#!/usr/bin/env python3
"""Dump the structure of a single .numbers file: sheets, tables, headers, sample rows."""

import sys
from pathlib import Path

from numbers_parser import Document


def dump(path: Path, max_rows: int = 8) -> None:
    print(f"=== {path} ===")
    doc = Document(str(path))
    for sheet in doc.sheets:
        print(f"\n  Sheet: {sheet.name!r}")
        for table in sheet.tables:
            rows = table.rows(values_only=True)
            print(f"    Table: {table.name!r}  ({len(rows)} rows x {len(rows[0]) if rows else 0} cols)")
            for i, row in enumerate(rows[:max_rows]):
                cells = [repr(c) if c is not None else "·" for c in row]
                print(f"      [{i}] {' | '.join(cells)}")
            if len(rows) > max_rows:
                print(f"      ... (+{len(rows) - max_rows} more rows)")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: inspect.py <path-to-.numbers> [more paths...]", file=sys.stderr)
        return 2
    for arg in sys.argv[1:]:
        try:
            dump(Path(arg))
        except Exception as e:
            print(f"!! error reading {arg}: {e}", file=sys.stderr)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
