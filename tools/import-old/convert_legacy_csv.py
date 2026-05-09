#!/usr/bin/env python3
"""Convert Numbers-exported CSV trees (used for 2015-2017 where numbers-parser
fails to read the original .numbers files) to AppDataCSVImporter CSV.

Expected directory layout (under --src):

    <Year>.csv                                   # yearly income summary
    <RussianMonth> <Year>/
        Денежные операции-Денежные операции.csv  # transactions
        Бюджет-Итог по категориям.csv            # ignored

Output columns: Type, Date, Amount, Currency, Category, Description, Destination,
                BaseCurrencyAmount, BaseCurrency
"""

import argparse
import csv
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

from convert import (
    CSV_HEADER, EXPENSE_CATEGORY_MAP, EXPENSE_SKIP_CATEGORIES,
    DEFAULT_EXPENSE_CATEGORIES, UA_MONTH,
)

RU_MONTH = {
    "Январь": 1, "Февраль": 2, "Март": 3, "Апрель": 4,
    "Май": 5, "Июнь": 6, "Июль": 7, "Август": 8,
    "Сентябрь": 9, "Октябрь": 10, "Ноябрь": 11, "Декабрь": 12,
}

# Used for matching folder names. Contains both Ukrainian (UA_MONTH) and
# Russian (RU_MONTH) month names.
ANY_MONTH = {**UA_MONTH, **RU_MONTH}

# Russian historical category names → app defaults (in addition to the
# Ukrainian map already in convert.py). Treated as an extension.
LEGACY_RU_CATEGORY_MAP = {
    "Авто": "Auto",
    "Бензин": "Auto",
    "Транспорт": "Auto",
    "Питание": "Groceries",
    "Продукты": "Groceries",
    "Кафе": "Cafes",
    "Кафе и рестораны": "Cafes",
    "Кава": "Cafes",
    "Развлечения": "Entertainment",
    "Книги": "Entertainment",
    "Личные вещи": "Personal Items",
    "Одежда": "Shopping",
    "Одежда и обувь": "Shopping",
    "Покупки": "Shopping",
    "Квартира": "Home",
    "Дом": "Home",
    "Дім": "Home",
    "Медицина": "Medical",
    "Здоровье": "Medical",
    "Иное": "Other",
    "Прочее": "Other",
    "Другое": "Other",
    "Подарки": "Gifts",
    "Налоги": "Taxes",
    "Путешествия": "Travel",
    "Путешествие": "Travel",
    "Поездки": "Travel",
    "Утилиты": "Utilities",
    "Коммуналка": "Utilities",
    "Связь": "Utilities",
    "Мобильный": "Utilities",
    "Кредит": "Loans",
    "Кредитка": "Loans",
    "Кредитная карта": "Loans",
    "Благотворительность": "Благодійність",
    "София": "Family",
    "Софие": "Family",
    "Соня": "Family",
    "Жена": "Family",
    "Семья": "Family",
}

LEGACY_SKIP_CATEGORIES = {"Депозит", "Депозиты", "Накопления"}


def parse_amount(s: str) -> float | None:
    if not s:
        return None
    cleaned = s
    for ch in ("UAH", "\xa0", " ", "(", ")"):
        cleaned = cleaned.replace(ch, "")
    cleaned = cleaned.replace(",", ".").strip()
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def parse_date(s: str, year: int) -> datetime | None:
    """Parse 'd/M/yy', 'd/M/yyyy' (Russian-style) or 'd.M.yy' (Ukrainian-style)."""
    if not s:
        return None
    s = s.strip()
    sep = "/" if "/" in s else "." if "." in s else None
    if sep is None:
        return None
    parts = s.split(sep)
    try:
        if len(parts) == 2:
            # 2017 format: 'd.M' with year implied by --year
            d, m = int(parts[0]), int(parts[1])
            y = year
        elif len(parts) == 3:
            d, m, y = int(parts[0]), int(parts[1]), int(parts[2])
        else:
            return None
    except ValueError:
        return None
    if y < 100:
        y += 2000
    try:
        return datetime(y, m, d)
    except ValueError:
        return None


def find_month_dir(year_dir: Path, month: int) -> Path | None:
    target_names = {n for n, m in ANY_MONTH.items() if m == month}
    for child in year_dir.iterdir():
        if not child.is_dir():
            continue
        first = unicodedata.normalize("NFC", child.name.split(" ")[0]).capitalize()
        if first in target_names:
            return child
    return None


def resolve_category(raw: str, unknown: dict[str, int]) -> str | None:
    """Return canonical app category, None if it should be skipped, or raise sentinel
    via the `unknown` dict (we collect rather than fail on first miss)."""
    if raw in LEGACY_SKIP_CATEGORIES or raw in EXPENSE_SKIP_CATEGORIES:
        return None
    if raw in DEFAULT_EXPENSE_CATEGORIES:
        return raw
    if raw in LEGACY_RU_CATEGORY_MAP:
        return LEGACY_RU_CATEGORY_MAP[raw]
    if raw in EXPENSE_CATEGORY_MAP:
        return EXPENSE_CATEGORY_MAP[raw]
    unknown[raw] = unknown.get(raw, 0) + 1
    return ""  # sentinel for "unknown"


def read_expenses(month_dir: Path, month: int, year: int, currency: str,
                   unknown: dict[str, int]):
    # Layouts seen across years:
    #   Russian (2015, early 2016): 'Денежные операции-Денежные операции.csv'
    #   Ukrainian (2016+):          'Операції-Операції.csv'
    candidates = [
        month_dir / "Денежные операции-Денежные операции.csv",
        month_dir / "Операції-Операції.csv",
    ]
    p = next((c for c in candidates if c.exists()), None)
    if p is None:
        # Last-ditch: any *.csv file that looks like a transactions table
        fallback = [c for c in month_dir.iterdir()
                    if c.suffix == ".csv" and ("Денежные" in c.name or "Операції" in c.name)]
        if not fallback:
            print(f"  WARNING: no transactions file in {month_dir}", file=sys.stderr)
            return
        p = fallback[0]

    with p.open(newline="") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader:
            if len(row) < 4:
                continue
            # Some months export with a leading empty column (5+ fields).
            if row[0] == "" and len(row) >= 5:
                date_s, desc_s, cat_s, amt_s = row[1], row[2], row[3], row[4]
            else:
                date_s, desc_s, cat_s, amt_s = row[0], row[1], row[2], row[3]
            # Skip header rows (title and column header, RU or UA)
            if date_s.strip() in ("", "Дата") or cat_s.strip() in ("Категория", "Категорія"):
                continue
            date = parse_date(date_s, year)
            if date is None:
                continue
            amt = parse_amount(amt_s)
            if amt is None or amt == 0:
                continue
            raw_cat = cat_s.strip()
            if not raw_cat:
                continue
            resolved = resolve_category(raw_cat, unknown)
            if resolved is None:
                continue
            if resolved == "":
                continue  # unknown — already counted
            yield {
                "Type": "Expense",
                "Date": date.strftime("%Y-%m-%d"),
                "Amount": f"{amt:.2f}",
                "Currency": currency,
                "Category": resolved,
                "Description": desc_s.strip(),
                "Destination": "",
                "BaseCurrencyAmount": "",
                "BaseCurrency": "",
            }


def read_year_income(src: Path, year: int, currency: str):
    """Read monthly income from the yearly summary CSV. Handles two layouts:

    - 2015 style: top-level `<year>.csv` with 'Месяц;Сумма' columns.
    - 2016+ style: `<year>/Загальний прибуток-Дохід по місяцях.csv` with
      'Місяць;Дохід;Витрати;Різниця' columns.
    """
    candidates = [
        src / f"{year}.csv",
        src / str(year) / "Загальний прибуток-Дохід по місяцях.csv",
    ]
    p = next((c for c in candidates if c.exists()), None)
    if p is None:
        return

    print(f"  reading income from {p.relative_to(src)}", file=sys.stderr)
    with p.open(newline="") as f:
        for row in csv.reader(f, delimiter=";"):
            if len(row) < 2:
                continue
            month_name = unicodedata.normalize("NFC", row[0].strip()).capitalize()
            if month_name in ("Месяц", "Місяць", "Всего", "Всього", "Усього", ""):
                continue
            month = ANY_MONTH.get(month_name)
            if month is None:
                continue
            amt = parse_amount(row[1])
            if amt is None or amt == 0:
                continue
            yield {
                "Type": "Income",
                "Date": f"{year:04d}-{month:02d}-01",
                "Amount": f"{amt:.2f}",
                "Currency": currency,
                "Category": "Salary",
                "Description": "",
                "Destination": "",
                "BaseCurrencyAmount": "",
                "BaseCurrency": "",
            }


def convert(src: Path, out_path: Path, year: int, currency: str) -> None:
    rows_out: list[dict] = []
    unknown: dict[str, int] = {}
    expense_n = 0

    for month in range(1, 13):
        d = find_month_dir(src, month)
        if d is None:
            continue
        print(f"  reading {d.name}", file=sys.stderr)
        for row in read_expenses(d, month, year, currency, unknown):
            rows_out.append(row)
            expense_n += 1

    income_n = 0
    for row in read_year_income(src, year, currency):
        rows_out.append(row)
        income_n += 1

    if unknown:
        print("\n!! Unknown categories encountered (add to LEGACY_RU_CATEGORY_MAP):",
              file=sys.stderr)
        for cat, n in sorted(unknown.items(), key=lambda kv: -kv[1]):
            print(f"     {n:5d}  {cat!r}", file=sys.stderr)
        print(file=sys.stderr)
        sys.exit(1)

    rows_out.sort(key=lambda r: (r["Date"], r["Type"]))
    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_HEADER)
        writer.writeheader()
        writer.writerows(rows_out)

    print(f"\n--- {year} -> {out_path} ---", file=sys.stderr)
    print(f"  expenses: {expense_n}", file=sys.stderr)
    print(f"  incomes:  {income_n}", file=sys.stderr)
    print(f"  total rows: {len(rows_out)}", file=sys.stderr)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--year", type=int, required=True)
    p.add_argument("--src", type=Path, required=True,
                   help="Directory containing <Year>.csv and per-month subfolders")
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--currency", default="UAH")
    args = p.parse_args()
    convert(args.src, args.out, args.year, args.currency)
    return 0


if __name__ == "__main__":
    sys.exit(main())
