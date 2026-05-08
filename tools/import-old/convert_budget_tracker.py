#!/usr/bin/env python3
"""Convert "Budget Tracker" semicolon-CSV exports to AppDataCSVImporter format.

Source format (two files):
    Transactions
    Date;Description;Category;Amount
    1/6/25;Lidl;Groceries;236,84 PLN
    ...

Date is d/M/yy. Amount uses comma decimal, may contain U+00A0 thousands sep,
ends with currency suffix (PLN or US$).

Output: CSV_HEADER from convert.py, fields:
    Type, Date, Amount, Currency, Category, Description, Destination,
    BaseCurrencyAmount, BaseCurrency

Optional --existing: a full app export (same format as output). Loose dedup
key (type, date, round(amount, 2), currency) — anything matching is dropped.
This is wider than AppDataCSVImporter's fingerprint so duplicates with
different descriptions (e.g. bank-synced "Від: CRELLO LIMITED" vs CSV's
"CRELLO LIMITED") still get caught.
"""

import argparse
import csv
import sys
from collections import defaultdict
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

from convert import CSV_HEADER

EXPENSE_CATEGORIES = {
    "Auto", "Cafes", "Entertainment", "Family", "Gifts", "Groceries",
    "Home", "Loans", "Medical", "Other", "Personal Items", "Shopping",
    "Subscription", "Taxes", "Travel", "Utilities",
}

INCOME_CATEGORY_MAP = {
    "Contract": "Salary",
}

CURRENCY_SUFFIX = {
    "PLN": "PLN",
    "US$": "USD",
    "USD": "USD",
    "EUR": "EUR",
    "€": "EUR",
    "UAH": "UAH",
}


def parse_amount(raw: str) -> tuple[Decimal, str]:
    """`'1 855,00 US$'` → (Decimal('1855.00'), 'USD')."""
    s = raw.strip().replace("\xa0", " ")
    # Currency suffix is the last whitespace-separated token.
    parts = s.rsplit(" ", 1)
    if len(parts) != 2:
        raise ValueError(f"unrecognised amount: {raw!r}")
    number, suffix = parts
    if suffix not in CURRENCY_SUFFIX:
        raise ValueError(f"unknown currency suffix in {raw!r}")
    currency = CURRENCY_SUFFIX[suffix]
    cleaned = number.replace(" ", "").replace(",", ".")
    return Decimal(cleaned), currency


def parse_date(raw: str) -> date:
    return datetime.strptime(raw.strip(), "%d/%m/%y").date()


def parse_source(path: Path, type_: str) -> list[dict]:
    """Parse one Budget Tracker CSV. Returns rows ready for output (pre-dedup)."""
    rows: list[dict] = []
    skipped_empty = 0
    with path.open(encoding="utf-8") as f:
        reader = csv.reader(f, delimiter=";")
        header_seen = False
        for raw in reader:
            if not raw:
                continue
            if not header_seen:
                # Two header lines: "Transactions", then column names.
                if raw[0] == "Transactions":
                    continue
                if raw[0] == "Date":
                    header_seen = True
                    continue
                continue
            if len(raw) < 4:
                continue
            date_s, desc, cat, amount_s = raw[0], raw[1], raw[2], raw[3]
            if not date_s.strip():
                skipped_empty += 1
                continue
            # Empty rows: "2/6/25;;;" or amount "0,00 PLN".
            if not desc.strip() and not cat.strip():
                skipped_empty += 1
                continue
            try:
                amount, currency = parse_amount(amount_s)
            except ValueError as e:
                print(f"  warn: {e} (line skipped)", file=sys.stderr)
                continue
            if amount == 0:
                skipped_empty += 1
                continue
            d = parse_date(date_s)

            if type_ == "Expense":
                if cat not in EXPENSE_CATEGORIES:
                    raise SystemExit(
                        f"Unknown expense category {cat!r} on {date_s} "
                        f"({desc!r}). Add it to EXPENSE_CATEGORIES or fix source."
                    )
                category = cat
            else:
                if cat not in INCOME_CATEGORY_MAP:
                    raise SystemExit(
                        f"Unknown income category {cat!r} on {date_s} "
                        f"({desc!r}). Add to INCOME_CATEGORY_MAP."
                    )
                category = INCOME_CATEGORY_MAP[cat]

            rows.append({
                "Type": type_,
                "Date": d.isoformat(),
                "Amount": format(amount, "f"),
                "Currency": currency,
                "Category": category,
                "Description": desc.strip(),
                "Destination": "",
                "BaseCurrencyAmount": "",
                "BaseCurrency": "",
            })
    print(f"{path.name}: parsed {len(rows)} rows, skipped {skipped_empty} empty/zero")
    return rows


def load_existing_keys(path: Path) -> set[tuple]:
    """Loose dedup keys from an existing app export."""
    keys: set[tuple] = set()
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            t = row.get("Type", "")
            if t not in ("Expense", "Income"):
                continue
            try:
                amount = Decimal(row["Amount"])
            except Exception:
                continue
            key = (t, row["Date"], amount.quantize(Decimal("0.01")), row["Currency"])
            keys.add(key)
    return keys


def loose_key(row: dict) -> tuple:
    return (
        row["Type"],
        row["Date"],
        Decimal(row["Amount"]).quantize(Decimal("0.01")),
        row["Currency"],
    )


def month_breakdown(rows: list[dict]) -> dict:
    by_month: dict[str, dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for r in rows:
        ym = r["Date"][:7]
        cur = r["Currency"]
        by_month[ym][f"{r['Type']}_{cur}"] += Decimal(r["Amount"])
    return by_month


def print_breakdown(title: str, rows: list[dict]) -> None:
    print(f"\n=== {title} ({len(rows)} rows) ===")
    by_month = month_breakdown(rows)
    for ym in sorted(by_month):
        parts = ", ".join(
            f"{k}={v}" for k, v in sorted(by_month[ym].items())
        )
        print(f"  {ym}: {parts}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--expenses", required=True, type=Path)
    p.add_argument("--incomes", required=True, type=Path)
    p.add_argument("--existing", type=Path,
                   help="Full app export CSV to dedup against (optional).")
    p.add_argument("--out", required=True, type=Path)
    args = p.parse_args()

    expense_rows = parse_source(args.expenses, "Expense")
    income_rows = parse_source(args.incomes, "Income")
    all_rows = expense_rows + income_rows

    print_breakdown("Parsed (before dedup)", all_rows)

    if args.existing:
        existing = load_existing_keys(args.existing)
        print(f"\nLoaded {len(existing)} existing loose-keys from {args.existing.name}")
        kept: list[dict] = []
        skipped: list[dict] = []
        for r in all_rows:
            if loose_key(r) in existing:
                skipped.append(r)
            else:
                kept.append(r)
        print_breakdown("Skipped as duplicates", skipped)
        print_breakdown("Kept (will be written)", kept)
        all_rows = kept
    else:
        print("\nNo --existing provided; writing all rows without pre-dedup.")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=CSV_HEADER)
        w.writeheader()
        w.writerows(all_rows)
    print(f"\nWrote {len(all_rows)} rows → {args.out}")


if __name__ == "__main__":
    main()
