"""
Türetilmiş özellikler - Census-Income (KDD)

Ön analizde gelirle en güçlü ilişkiyi gösteren 9 türetilmiş özelliği hesaplar:

    education_level      Eğitim düzeyi, 0 (Children) .. 16 (Doktora) arası sıralı sayı
    age_group            Yaş grubu: 0-17, 18-24, 25-34, 35-44, 45-54, 55-64, 65+
    is_employed          Yıl içinde en az 1 hafta çalışmış mı
    full_year_worker     Yılın 52 haftasının tamamında çalışmış mı
    is_professional_occ  Meslek: Professional specialty / Executive admin and managerial
    has_investment       Sermaye kazancı, sermaye kaybı veya temettüden biri > 0 mı
    is_householder       Hane reisi mi
    joint_filer          Ortak (Joint ...) vergi beyannamesi veriyor mu
    is_married           Evli mi (Married-...)

Girdi : data/processed/train_clean.csv, test_clean.csv  (önce pre_analiz.py çalışmalı)
Çıktı : data/processed/train_features.csv, test_features.csv
        reports/turetilmis_ozellikler_raporu.md

Çalıştırma (proje kök dizininden):
    python analysis/turetilmis_ozellikler.py
"""

from __future__ import annotations

import time
from pathlib import Path

import pandas as pd
from sklearn.metrics import roc_auc_score

ROOT = Path(__file__).resolve().parent.parent
PROCESSED_DIR = ROOT / "data" / "processed"
REPORT_PATH = ROOT / "reports" / "turetilmis_ozellikler_raporu.md"
TARGET = "income_over_50k"

# Eğitim düzeyleri - en düşükten en yükseğe. Bu sıra veritabanında Education
# lookup tablosuna "level" sütunu olarak da girecek.
EDUCATION_LEVELS = {
    "Children": 0,
    "Less than 1st grade": 1,
    "1st 2nd 3rd or 4th grade": 2,
    "5th or 6th grade": 3,
    "7th and 8th grade": 4,
    "9th grade": 5,
    "10th grade": 6,
    "11th grade": 7,
    "12th grade no diploma": 8,
    "High school graduate": 9,
    "Some college but no degree": 10,
    "Associates degree-occup /vocational": 11,
    "Associates degree-academic program": 12,
    "Bachelors degree(BA AB BS)": 13,
    "Masters degree(MA MS MEng MEd MSW MBA)": 14,
    "Prof school degree (MD DDS DVM LLB JD)": 15,
    "Doctorate degree(PhD EdD)": 16,
}

AGE_BINS = [-1, 17, 24, 34, 44, 54, 64, 200]
AGE_LABELS = ["0-17", "18-24", "25-34", "35-44", "45-54", "55-64", "65+"]

PROFESSIONAL_OCCUPATIONS = {"Professional specialty", "Executive admin and managerial"}

DERIVED_COLS = [
    "education_level",
    "age_group",
    "is_employed",
    "full_year_worker",
    "is_professional_occ",
    "has_investment",
    "is_householder",
    "joint_filer",
    "is_married",
]


def add_derived_features(df: pd.DataFrame) -> pd.DataFrame:
    """Temiz veriye türetilmiş özellik sütunlarını ekleyip yeni bir DataFrame döndürür."""
    out = df.copy()

    out["education_level"] = out["education"].map(EDUCATION_LEVELS)
    unmapped = out.loc[out["education_level"].isna(), "education"].unique()
    if len(unmapped):
        raise ValueError(f"Sıralaması tanımlı olmayan eğitim değerleri: {list(unmapped)}")
    out["education_level"] = out["education_level"].astype("int8")

    out["age_group"] = pd.cut(out["age"], bins=AGE_BINS, labels=AGE_LABELS).astype(str)

    out["is_employed"] = (out["weeks_worked_in_year"] > 0).astype("int8")
    out["full_year_worker"] = (out["weeks_worked_in_year"] == 52).astype("int8")
    out["is_professional_occ"] = out["major_occupation_code"].isin(PROFESSIONAL_OCCUPATIONS).astype("int8")
    out["has_investment"] = (
        (out["capital_gains"] > 0) | (out["capital_losses"] > 0) | (out["dividends_from_stocks"] > 0)
    ).astype("int8")
    out["is_householder"] = (out["detailed_household_summary_in_household"] == "Householder").astype("int8")
    out["joint_filer"] = out["tax_filer_stat"].str.startswith("Joint").astype("int8")
    out["is_married"] = out["marital_stat"].str.startswith("Married").astype("int8")
    return out


# --------------------------------------------------------------------------- #
# Rapor
# --------------------------------------------------------------------------- #
def md_table(df: pd.DataFrame) -> str:
    df = df.reset_index()
    head = "| " + " | ".join(map(str, df.columns)) + " |"
    sep = "|" + "|".join("---" for _ in df.columns) + "|"
    rows = []
    for row in df.itertuples(index=False):
        cells = [f"{v:,}" if isinstance(v, int) else (f"{v:.2f}" if isinstance(v, float) else str(v))
                 for v in row]
        rows.append("| " + " | ".join(cells) + " |")
    return "\n".join([head, sep, *rows])


def build_report(train: pd.DataFrame, test: pd.DataFrame) -> str:
    parts = [
        "# Türetilmiş Özellikler Raporu\n",
        "_Bu dosya `analysis/turetilmis_ozellikler.py` tarafından otomatik üretilmiştir._\n",
        "AUC: özelliğin tek başına 50K+ / 50K altı ayrımını ne kadar iyi yaptığı "
        "(0.5 = hiç, 1.0 = kusursuz). Test kümesindeki değerlerin train ile tutarlı olması, "
        "ilişkinin tesadüf olmadığını gösterir.\n",
    ]

    # Özet tablo: her özellik için train ve test AUC
    age_code = {label: i for i, label in enumerate(AGE_LABELS)}
    summary = {}
    for col in DERIVED_COLS:
        row = {}
        for name, df in [("train", train), ("test", test)]:
            x = df[col].map(age_code) if col == "age_group" else df[col]
            auc = roc_auc_score(df[TARGET], x)
            row[f"{name} AUC"] = max(auc, 1 - auc)
        summary[col] = row
    s = pd.DataFrame(summary).T.sort_values("train AUC", ascending=False)
    s.index.name = "özellik"
    parts.append("## Özet\n\n" + md_table(s) + "\n")

    # Her özellik için değer bazında 50K+ oranı
    parts.append("## Değerlere Göre 50K+ Oranı\n")
    for col in DERIVED_COLS:
        t = pd.DataFrame({
            "train kayıt": train.groupby(col).size(),
            "train 50K+ %": 100 * train.groupby(col)[TARGET].mean(),
            "test kayıt": test.groupby(col).size(),
            "test 50K+ %": 100 * test.groupby(col)[TARGET].mean(),
        })
        if col == "age_group":
            t = t.reindex(AGE_LABELS)
        t = t.astype({"train kayıt": "int64", "test kayıt": "int64"})
        t.index.name = col
        parts.append(f"### {col}\n\n" + md_table(t) + "\n")

    parts.append(
        "## Notlar\n\n"
        "- `age_group` metin olarak tutuldu; modelde one-hot kodlanmalı ya da sıralı "
        "kod olarak kullanılmalı.\n"
        "- `education_level`, `education` sütunuyla aynı bilgiyi **sıralı** şekilde taşır; "
        "modelde ikisinden biri kullanılmalı.\n"
        "- `is_employed` ve `full_year_worker` aynı sütundan (`weeks_worked_in_year`) "
        "türetildiği için birbirleriyle ilişkilidir. Ağaç tabanlı modellerde sorun olmaz; "
        "lojistik regresyonda katsayılar yorumlanırken dikkat edilmeli.\n"
        "- Veritabanında bu özellikler `vw_MLFeatures` view'ında SQL ile hesaplanacak; "
        "`education_level` ise `Education` lookup tablosunda `level` sütunu olarak tutulacak.\n"
    )
    return "\n\n".join(parts)


# --------------------------------------------------------------------------- #
def main() -> None:
    start = time.perf_counter()

    def step(msg: str) -> None:
        print(f"[{time.perf_counter() - start:5.1f} sn] {msg}", flush=True)

    train_path = PROCESSED_DIR / "train_clean.csv"
    test_path = PROCESSED_DIR / "test_clean.csv"
    if not train_path.exists() or not test_path.exists():
        raise SystemExit("Temiz veri bulunamadı. Önce şunu çalıştırın: python analysis/pre_analiz.py")

    step("Temiz veri okunuyor...")
    train = pd.read_csv(train_path, keep_default_na=False, na_values=[""])
    test = pd.read_csv(test_path, keep_default_na=False, na_values=[""])

    step("Türetilmiş özellikler hesaplanıyor...")
    train_f = add_derived_features(train)
    test_f = add_derived_features(test)

    step("Rapor hazırlanıyor...")
    report = build_report(train_f, test_f)

    step("Dosyalar yazılıyor...")
    train_f.to_csv(PROCESSED_DIR / "train_features.csv", index=False)
    test_f.to_csv(PROCESSED_DIR / "test_features.csv", index=False)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(report, encoding="utf-8")

    step("Bitti.")
    print(f"Train : {PROCESSED_DIR / 'train_features.csv'}  ({len(train_f):,} satır, {train_f.shape[1]} sütun)")
    print(f"Test  : {PROCESSED_DIR / 'test_features.csv'}  ({len(test_f):,} satır, {test_f.shape[1]} sütun)")
    print(f"Rapor : {REPORT_PATH}")


if __name__ == "__main__":
    main()
