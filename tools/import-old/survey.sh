#!/usr/bin/env bash
# Run dump_structure.py against one representative monthly file per year.
# Output goes to structure-survey.txt.
set -u
cd "$(dirname "$0")"

BUDGET_ROOT="${HOME}/Documents/Бюджет"
OUT="structure-survey.txt"
: > "$OUT"

for year_dir in "$BUDGET_ROOT"/[0-9][0-9][0-9][0-9]; do
    year=$(basename "$year_dir")
    # Pick the first monthly file (skip the year-summary "<year>.numbers")
    pick=""
    while IFS= read -r f; do
        base=$(basename "$f")
        [[ "$base" == "${year}.numbers" ]] && continue
        pick="$f"
        break
    done < <(find "$year_dir" -maxdepth 1 -name "*.numbers" | sort)

    if [[ -z "$pick" ]]; then
        echo ">>> $year: no monthly file found" >> "$OUT"
        continue
    fi
    echo ">>> $year" >> "$OUT"
    venv/bin/python dump_structure.py "$pick" >> "$OUT" 2>&1
    echo >> "$OUT"
done

echo "Done. See $OUT"
