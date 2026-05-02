#!/usr/bin/env python3
"""Convert historical .numbers budget files to AppDataCSVImporter-compatible CSV.

Output columns: Type, Date, Amount, Currency, Category, Description, Destination,
                BaseCurrencyAmount, BaseCurrency
"""

import argparse
import csv
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

from numbers_parser import Document

# Categories that are not real expenses — they are inter-account transfers
# (moving money to a savings/deposit account).
EXPENSE_SKIP_CATEGORIES = {"Депозит"}

# Map historical Ukrainian/Russian category names from the .numbers files to
# the canonical app DefaultExpenseCategory rawValues. Every category we may
# encounter must appear here; unknown categories cause a hard error so we
# never silently create new categories during import.
EXPENSE_CATEGORY_MAP = {
    # Sentinel used by 2018 fallback (see extract_expenses_from_table default_category)
    "Other": "Other",
    # Direct matches with default categories
    "Авто": "Auto",
    "Кафе та ресторани": "Cafes",
    "Розваги": "Entertainment",
    "Книги": "Entertainment",
    "Подарунки": "Gifts",
    "Їжа": "Groceries",
    "Продукти": "Groceries",
    "Продукти і супермаркети": "Groceries",
    "Дім": "Home",
    "Медицина": "Medical",
    "Інше": "Other",
    "Особисті речі": "Personal Items",
    "Одяг та взуття": "Shopping",
    "Податки": "Taxes",
    "Подорожі": "Travel",
    "Подорож": "Travel",
    "Комуналка та Інтернет": "Utilities",
    "Утиліти": "Utilities",
    "Рахунки": "Utilities",
    "Поповнення мобільного": "Utilities",
    # New defaults added for this import
    "Благодійність": "Благодійність",
    "Єва": "Family",
    "Марина": "Family",
    "Дитина": "Family",
    "Кредит": "Loans",
    "Кредитка": "Loans",
}

# Used by the gap-filler — must be one of the app defaults.
GAP_FILLER_CATEGORY = "Other"

CSV_HEADER = [
    "Type", "Date", "Amount", "Currency", "Category", "Description",
    "Destination", "BaseCurrencyAmount", "BaseCurrency",
]


class Stats:
    def __init__(self) -> None:
        self.expenses_emitted = 0
        self.incomes_emitted = 0
        self.skipped_empty = 0
        self.skipped_deposit = 0
        self.skipped_zero_income = 0
        self.gap_filler_expenses = 0
        self.unreadable_files = 0
        self.categories_seen: dict[str, int] = {}

    def report(self, where) -> None:
        print(f"--- {where} ---", file=sys.stderr)
        print(f"  expenses emitted:    {self.expenses_emitted}", file=sys.stderr)
        print(f"  incomes emitted:     {self.incomes_emitted}", file=sys.stderr)
        print(f"  skipped (empty):     {self.skipped_empty}", file=sys.stderr)
        print(f"  skipped (deposit):   {self.skipped_deposit}", file=sys.stderr)
        print(f"  skipped (0 income):  {self.skipped_zero_income}", file=sys.stderr)
        print(f"  gap-filler expenses: {self.gap_filler_expenses}", file=sys.stderr)
        print(f"  unreadable files:    {self.unreadable_files}", file=sys.stderr)
        print(f"  categories seen:     {len(self.categories_seen)}", file=sys.stderr)
        for cat, n in sorted(self.categories_seen.items(), key=lambda kv: -kv[1]):
            print(f"    {n:5d}  {cat}", file=sys.stderr)


def safe_sheet_name(sheet) -> str:
    try:
        return sheet.name
    except Exception:
        return "<unreadable>"


def safe_table_name(table) -> str:
    try:
        return table.name
    except Exception:
        return "<unreadable>"


def iter_tables_named(doc, *names: str):
    """Yield (sheet, table) pairs for every table whose name matches any of `names`."""
    name_set = set(names)
    for sheet in doc.sheets:
        for table in sheet.tables:
            if safe_table_name(table) in name_set:
                yield sheet, table


def extract_expenses_from_table(table, currency: str, stats: Stats,
                                 default_category: str | None = None):
    """Yield Expense rows from an 'Операції' table.

    Columns: Дата | Опис | Категорія | Сума.
    If `default_category` is set, rows with empty/missing category fall back
    to that value (used for 2018 where description+category were lost).
    """
    rows = table.rows(values_only=True)
    if not rows:
        return
    for row in rows[1:]:  # skip header
        date_v, desc_v, cat_v, amount_v = (list(row) + [None] * 4)[:4]

        if not isinstance(date_v, datetime):
            stats.skipped_empty += 1
            continue
        if amount_v is None or amount_v == 0:
            stats.skipped_empty += 1
            continue
        raw_category = (cat_v or "").strip()
        if not raw_category:
            if default_category is None:
                stats.skipped_empty += 1
                continue
            raw_category = default_category
        if raw_category in EXPENSE_SKIP_CATEGORIES:
            stats.skipped_deposit += 1
            continue
        if raw_category in DEFAULT_EXPENSE_CATEGORIES:
            category = raw_category
        elif raw_category in EXPENSE_CATEGORY_MAP:
            category = EXPENSE_CATEGORY_MAP[raw_category]
        else:
            raise ValueError(
                f"Unknown expense category {raw_category!r} — add it to "
                f"EXPENSE_CATEGORY_MAP in convert.py"
            )

        stats.categories_seen[category] = stats.categories_seen.get(category, 0) + 1
        stats.expenses_emitted += 1
        yield {
            "Type": "Expense",
            "Date": date_v.strftime("%Y-%m-%d"),
            "Amount": f"{float(amount_v):.2f}",
            "Currency": currency,
            "Category": category,
            "Description": (desc_v or "").strip(),
            "Destination": "",
            "BaseCurrencyAmount": "",
            "BaseCurrency": "",
        }


def fill_expense_gaps(summary_table, observed_by_month: dict[int, float],
                       year: int, currency: str, stats: Stats):
    """For months where the Місяці summary reports more expenses than what we
    actually pulled out of the Операції tables, emit a single 'Other' Expense
    row covering the difference.

    Tolerance: <1 UAH is treated as no gap (rounding noise).
    """
    rows = summary_table.rows(values_only=True)
    for row in rows[1:]:
        month_v, _income_v, expenses_v, _diff_v = (list(row) + [None] * 4)[:4]
        if not isinstance(month_v, datetime):
            continue
        if not isinstance(expenses_v, (int, float)):
            continue
        observed = observed_by_month.get(month_v.month, 0.0)
        gap = float(expenses_v) - observed
        if gap < 1.0:
            continue
        date_str = f"{year:04d}-{month_v.month:02d}-01"
        stats.gap_filler_expenses += 1
        stats.categories_seen[GAP_FILLER_CATEGORY] = stats.categories_seen.get(GAP_FILLER_CATEGORY, 0) + 1
        yield {
            "Type": "Expense",
            "Date": date_str,
            "Amount": f"{gap:.2f}",
            "Currency": currency,
            "Category": GAP_FILLER_CATEGORY,
            "Description": "Місячний підсумок (деталі втрачені)",
            "Destination": "",
            "BaseCurrencyAmount": "",
            "BaseCurrency": "",
        }


def extract_incomes_from_table(table, year: int, currency: str, stats: Stats,
                                positional: bool = False):
    """Yield monthly Income rows from a 'Місяці' table summarizing the year.

    Columns: Місяць | Дохід | Витрати | Різниця. In `positional` mode (used for
    2018's 'Дохід по місяцях' table where headers are empty), rows are bucketed
    by row index — first 12 rows are Jan..Dec, any extra row is treated as a
    totals row and skipped.
    """
    rows = table.rows(values_only=True)
    if not rows:
        return

    if positional:
        # Row 0 is empty headers, rows 1..12 are Jan..Dec, row 13 is the totals.
        for i, row in enumerate(rows[1:13], start=1):
            cells = (list(row) + [None] * 4)[:4]
            income_v = cells[1]
            if not isinstance(income_v, (int, float)) or income_v == 0:
                stats.skipped_zero_income += 1
                continue
            date_str = f"{year:04d}-{i:02d}-01"
            stats.incomes_emitted += 1
            yield {
                "Type": "Income",
                "Date": date_str,
                "Amount": f"{float(income_v):.2f}",
                "Currency": currency,
                "Category": "Salary",
                "Description": "",
                "Destination": "",
                "BaseCurrencyAmount": "",
                "BaseCurrency": "",
            }
        return

    for row in rows[1:]:
        month_v, income_v, _expenses_v, _diff_v = (list(row) + [None] * 4)[:4]

        # The trailing "Всього" totals row has no date — skip it.
        if not isinstance(month_v, datetime):
            continue

        if income_v is None or income_v == 0:
            stats.skipped_zero_income += 1
            continue

        date_str = f"{year:04d}-{month_v.month:02d}-01"
        stats.incomes_emitted += 1
        yield {
            "Type": "Income",
            "Date": date_str,
            "Amount": f"{float(income_v):.2f}",
            "Currency": currency,
            "Category": "Salary",
            "Description": "",
            "Destination": "",
            "BaseCurrencyAmount": "",
            "BaseCurrency": "",
        }


UA_MONTH = {
    "Січень": 1, "Лютий": 2, "Березень": 3, "Квітень": 4,
    "Травень": 5, "Червень": 6, "Червернь": 6,  # 'Червернь' is a known typo
    "Липень": 7, "Серпень": 8, "Вересень": 9,
    "Жовтень": 10, "Листопад": 11, "Грудень": 12,
    # English-named files appear from 2025-06 onward.
    "January": 1, "February": 2, "March": 3, "April": 4,
    "May": 5, "June": 6, "July": 7, "August": 8,
    "September": 9, "October": 10, "November": 11, "December": 12,
}

# Set of canonical app-default category names — when a row's category is
# already one of these (e.g. 2025-06+ files use English names) we pass it
# through without going via EXPENSE_CATEGORY_MAP.
DEFAULT_EXPENSE_CATEGORIES = {
    "Auto", "Cafes", "Entertainment", "Gifts", "Groceries", "Home",
    "Medical", "Other", "Personal Items", "Shopping", "Subscription",
    "Taxes", "Travel", "Utilities", "Благодійність", "Family", "Loans",
}


def find_monthly_files(year_dir: Path, year: int) -> list[tuple[int, Path]]:
    """Find standalone monthly files like 'Січень 2023.numbers' in a year folder.

    Returns sorted list of (month_number, path).
    """
    out = []
    yearly = f"{year}.numbers"
    for p in year_dir.iterdir():
        if p.name == yearly or not p.name.endswith(".numbers"):
            continue
        # Filename: "<UkrainianMonth> <Year>.numbers"
        stem = p.stem  # without .numbers
        parts = stem.split(" ")
        if len(parts) < 2:
            continue
        # macOS HFS+ stores filenames in NFD; our UA_MONTH keys are NFC.
        first = unicodedata.normalize("NFC", parts[0])
        month = UA_MONTH.get(first)
        if month is None:
            continue
        out.append((month, p))
    return sorted(out)


def convert_year(budget_root: Path, out_path: Path, year: int, currency: str,
                  monthly_currency: str | None = None) -> None:
    """Convert a year's data to CSV.

    Reads:
      - The yearly file (<year>.numbers) if present, with its sheet-per-month
        Операції tables and a `Місяці` income summary.
      - Any standalone monthly files (e.g. 'Січень 2023.numbers') in the same
        folder, treating each as the source of truth for that month's expenses.
    """
    year_dir = budget_root / str(year)
    yearly = year_dir / f"{year}.numbers"
    monthly = find_monthly_files(year_dir, year)

    stats = Stats()
    rows_out: list[dict] = []
    expense_totals_by_sheet_month: dict[int, float] = {m: 0.0 for m in range(1, 13)}
    months_from_monthly_files: set[int] = set()

    # 2018 has empty description/category cells in its monthly files — fall back
    # to "Other" so we at least preserve the date and amount.
    default_cat = "Other" if year == 2018 else None

    # 1. Standalone monthly files first (they take precedence for that month).
    monthly_cur = monthly_currency or currency
    for month, path in monthly:
        months_from_monthly_files.add(month)
        print(f"Reading monthly {path}", file=sys.stderr)
        try:
            doc = Document(str(path))
            tables = list(iter_tables_named(doc, "Операції", "Transactions"))
        except Exception as e:
            print(f"  ERROR reading {path.name}: {e} — skipping", file=sys.stderr)
            stats.unreadable_files += 1
            months_from_monthly_files.discard(month)
            continue
        for _sheet, table in tables:
            try:
                for row in extract_expenses_from_table(table, currency=monthly_cur, stats=stats,
                                                        default_category=default_cat):
                    expense_totals_by_sheet_month[month] += float(row["Amount"])
                    rows_out.append(row)
            except Exception as e:
                print(f"  ERROR reading table in {path.name}: {e} — skipping", file=sys.stderr)
                stats.unreadable_files += 1

    # 2. Yearly file: read sheet-per-month Операції for months NOT in monthly files.
    summary_table = None
    if yearly.exists():
        print(f"Reading yearly {yearly}", file=sys.stderr)
        doc = Document(str(yearly))
        for sheet, table in iter_tables_named(doc, "Операції", "Transactions"):
            sname = safe_sheet_name(sheet)
            sheet_month = UA_MONTH.get(sname)
            if sheet_month is None:
                print(f"  WARNING: sheet {sname!r} has 'Операції' but is not a known month — skipping", file=sys.stderr)
                continue
            if sheet_month in months_from_monthly_files:
                print(f"  skipping yearly sheet {sname!r} — covered by monthly file", file=sys.stderr)
                continue
            print(f"  expenses from sheet {sname!r}", file=sys.stderr)
            for row in extract_expenses_from_table(table, currency=currency, stats=stats):
                expense_totals_by_sheet_month[sheet_month] += float(row["Amount"])
                rows_out.append(row)

        income_tables = list(iter_tables_named(doc, "Місяці"))
        if income_tables:
            summary_table = income_tables[0][1]
            for sheet, table in income_tables:
                print(f"  incomes from sheet {safe_sheet_name(sheet)!r}", file=sys.stderr)
                rows_out.extend(extract_incomes_from_table(table, year=year, currency=currency, stats=stats))
        else:
            # 2018-style: income lives in 'Дохід по місяцях' with empty headers
            old_income = list(iter_tables_named(doc, "Дохід по місяцях"))
            for sheet, table in old_income:
                print(f"  incomes (positional) from sheet {safe_sheet_name(sheet)!r}", file=sys.stderr)
                rows_out.extend(extract_incomes_from_table(
                    table, year=year, currency=currency, stats=stats, positional=True
                ))

    # 3. Fill gaps from Місяці summary.
    if summary_table is not None:
        rows_out.extend(fill_expense_gaps(summary_table, expense_totals_by_sheet_month,
                                           year=year, currency=currency, stats=stats))

    rows_out.sort(key=lambda r: (r["Date"], r["Type"]))

    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_HEADER)
        writer.writeheader()
        writer.writerows(rows_out)

    stats.report(f"{year} -> {out_path}")
    print(f"\nWrote {len(rows_out)} rows to {out_path}", file=sys.stderr)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--year", type=int, required=True,
                   choices=[2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025])
    p.add_argument("--budget-root", type=Path, default=Path.home() / "Documents" / "Бюджет")
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    # 2025 transitions to PLN with the standalone monthly files (June+).
    monthly_cur = "PLN" if args.year == 2025 else None
    convert_year(args.budget_root, args.out, year=args.year, currency="UAH",
                  monthly_currency=monthly_cur)
    return 0


if __name__ == "__main__":
    sys.exit(main())
