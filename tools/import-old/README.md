# import-old

Одноразовий тулінг для конвертації історичних бюджетних `.numbers` файлів
з `~/Documents/Бюджет/` у CSV для імпорту через `AppDataCSVImporter`.

## Setup (один раз)

```bash
cd tools/import-old
python3 -m venv venv
venv/bin/pip install -r requirements.txt
```

## Розвідка структури (Крок 1)

`dump_structure.py` друкує sheet/table/headers/перші рядки одного файлу:

```bash
venv/bin/python dump_structure.py "/Users/yurii/Documents/Бюджет/2020/Травень 2020.numbers"
```

Зібрати survey по одному файлу на рік — див. `survey.sh`, результат у `structure-survey.txt`.

## Конвертація (Крок 2 — TBD)

`convert.py` ще не написаний — додамо після того, як подивимось survey.
