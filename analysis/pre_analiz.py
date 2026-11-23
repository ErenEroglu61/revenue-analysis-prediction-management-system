"""
Ön analiz (pre-analysis) - Census-Income (KDD) veri seti

Yaptıkları:
  1. Ham veriyi (başlıksız) sütun adlarıyla okur, boşlukları temizler, '?' -> NULL yapar.
  2. Hedef değişkeni 0/1'e çevirir (income_over_50k).
  3. Tekrar eden satırları ve tekrar eden / türetilebilir sütunları inceler.
  4. Eksik değer, 'Not in universe', sayısal özet, train-test karşılaştırması gibi
     incelemeleri yapar.
  5. Temizlenmiş veriyi data/processed/ altına, raporu reports/pre_analiz_raporu.md
     dosyasına yazar.

Çalıştırma (proje kök dizininden):
    python analysis/pre_analiz.py
"""

from __future__ import annotations

import itertools
import numbers
import time
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data"
OUT_DIR = ROOT / "data" / "processed"
REPORT_PATH = ROOT / "reports" / "pre_analiz_raporu.md"

# census-income.names dosyasındaki sıraya göre 42 sütun
# (40 öznitelik + instance_weight + hedef)
COLUMNS = [
    "age",
    "class_of_worker",
    "detailed_industry_recode",
    "detailed_occupation_recode",
    "education",
    "wage_per_hour",
    "enroll_in_edu_inst_last_wk",
    "marital_stat",
    "major_industry_code",
    "major_occupation_code",
    "race",
    "hispanic_origin",
    "sex",
    "member_of_labor_union",
    "reason_for_unemployment",
    "full_or_part_time_employment_stat",
    "capital_gains",
    "capital_losses",
    "dividends_from_stocks",
    "tax_filer_stat",
    "region_of_previous_residence",
    "state_of_previous_residence",
    "detailed_household_and_family_stat",
    "detailed_household_summary_in_household",
    "instance_weight",
    "migration_code_change_in_msa",
    "migration_code_change_in_reg",
    "migration_code_move_within_reg",
    "live_in_this_house_1_year_ago",
    "migration_prev_res_in_sunbelt",
    "num_persons_worked_for_employer",
    "family_members_under_18",
    "country_of_birth_father",
    "country_of_birth_mother",
    "country_of_birth_self",
    "citizenship",
    "own_business_or_self_employed",
    "fill_inc_questionnaire_for_veterans_admin",
    "veterans_benefits",
    "weeks_worked_in_year",
    "year",
    "income",
]

# Gerçekten sürekli (sayısal) olan sütunlar
NUMERIC_COLS = [
    "age",
    "wage_per_hour",
    "capital_gains",
    "capital_losses",
    "dividends_from_stocks",
    "instance_weight",
    "num_persons_worked_for_employer",
    "weeks_worked_in_year",
]
# Sayı gibi görünen ama aslında kategorik (kod) olan sütunlar
CODED_CATEGORICAL_COLS = [
    "detailed_industry_recode",
    "detailed_occupation_recode",
    "own_business_or_self_employed",
    "veterans_benefits",
    "year",
]
TARGET = "income_over_50k"


# --------------------------------------------------------------------------- #
# Yardımcılar
# --------------------------------------------------------------------------- #
def md_table(df: pd.DataFrame, index: bool = True, floatfmt: str = "{:,.2f}") -> str:
    """tabulate bağımlılığı olmadan basit markdown tablo."""
    df = df.reset_index() if index else df

    def fmt(v):
        if isinstance(v, numbers.Integral) and not isinstance(v, bool):
            return f"{v:,}"
        if isinstance(v, numbers.Real):
            return floatfmt.format(v)
        return str(v)

    head = "| " + " | ".join(map(str, df.columns)) + " |"
    sep = "|" + "|".join("---" for _ in df.columns) + "|"
    rows = ["| " + " | ".join(fmt(v) for v in row) + " |" for row in df.itertuples(index=False)]
    return "\n".join([head, sep, *rows])


def load(path: Path) -> pd.DataFrame:
    df = pd.read_csv(
        path,
        header=None,
        names=COLUMNS,
        sep=",",
        skipinitialspace=True,  # ", " ayracındaki baştaki boşlukları atar
        na_values="?",          # '?' -> NaN
        keep_default_na=False,  # 'NA' gibi gerçek kategori değerleri NaN olmasın
    )
    # Metin sütunlarında kalan baş/son boşlukları temizle
    for c in df.select_dtypes(include=["object", "string"]).columns:
        df[c] = df[c].str.strip()
    # Hedef: '- 50000.' -> 0, '50000+.' -> 1
    mapping = {"- 50000.": 0, "50000+.": 1}
    unknown = set(df["income"].unique()) - set(mapping)
    if unknown:
        raise ValueError(f"Beklenmeyen hedef değerleri: {unknown}")
    df[TARGET] = df.pop("income").map(mapping).astype("int8")
    return df


# --------------------------------------------------------------------------- #
# Analiz bölümleri - her biri markdown metni döndürür
# --------------------------------------------------------------------------- #
def section_overview(train: pd.DataFrame, test: pd.DataFrame) -> str:
    out = ["## 1. Genel Bakış\n"]
    out.append(md_table(pd.DataFrame(
        {"satır": [len(train), len(test)], "sütun": [train.shape[1], test.shape[1]]},
        index=pd.Index(["train (census-income.data)", "test (census-income.test)"], name="küme"),
    )))
    out.append(
        f"\n- Sayısal (sürekli) sütun: **{len(NUMERIC_COLS)}** "
        f"(`instance_weight` dahil)\n"
        f"- Sayı gibi görünen ama kategorik (kod) sütun: **{len(CODED_CATEGORICAL_COLS)}** "
        f"→ {', '.join(f'`{c}`' for c in CODED_CATEGORICAL_COLS)}\n"
        f"- Metin kategorik sütun: "
        f"**{train.shape[1] - len(NUMERIC_COLS) - len(CODED_CATEGORICAL_COLS) - 1}**\n"
        f"- Hedef: `{TARGET}` (0 = 50K altı, 1 = 50K üstü)\n"
        "- `instance_weight` bir **örnekleme ağırlığıdır**; nüfus analizi için kullanılır "
        "ama **modele girdi olarak verilmemelidir** (veri seti açıklaması).\n"
    )
    return "\n".join(out)


def section_target(train: pd.DataFrame, test: pd.DataFrame) -> str:
    rows = {}
    for name, df in [("train", train), ("test", test)]:
        vc = df[TARGET].value_counts()
        w = df.groupby(TARGET)["instance_weight"].sum()
        rows[name] = {
            "50K altı (0)": int(vc.get(0, 0)),
            "50K üstü (1)": int(vc.get(1, 0)),
            "pozitif oran %": 100 * vc.get(1, 0) / len(df),
            "ağırlıklı pozitif oran %": 100 * w.get(1, 0) / w.sum(),
        }
    t = pd.DataFrame(rows).T
    t = t.astype({"50K altı (0)": "int64", "50K üstü (1)": "int64"})
    t.index.name = "küme"
    return (
        "## 2. Hedef Değişken Dağılımı\n\n" + md_table(t) +
        "\n\n> **Sınıflar çok dengesiz.** Her kayda '50K altı' diyen bir model bile ~%94 doğruluk "
        "alır. Modellemede accuracy yerine **F1, Precision/Recall, ROC-AUC, PR-AUC** "
        "kullanılmalı; `class_weight='balanced'` veya yeniden örnekleme düşünülmeli.\n"
    )


def section_columns(train: pd.DataFrame) -> str:
    info = pd.DataFrame({
        "tip": [
            "sayısal" if c in NUMERIC_COLS else
            ("kod (kategorik)" if c in CODED_CATEGORICAL_COLS else
             ("hedef" if c == TARGET else "kategorik"))
            for c in train.columns
        ],
        "farklı değer": train.nunique(dropna=True).values,
        "eksik (?)": train.isna().sum().values,
        "eksik %": (100 * train.isna().mean()).values,
        "en sık değer": [str(train[c].mode(dropna=True).iloc[0]) for c in train.columns],
        "en sık %": [100 * train[c].value_counts(normalize=True, dropna=False).iloc[0]
                     for c in train.columns],
    }, index=pd.Index(train.columns, name="sütun"))
    return "## 3. Sütun Profili (train)\n\n" + md_table(info) + "\n"


def section_missing(train: pd.DataFrame, test: pd.DataFrame) -> str:
    out = ["## 4. Eksik Değerler\n"]
    miss = pd.DataFrame({
        "train eksik": train.isna().sum(),
        "train %": 100 * train.isna().mean(),
        "test eksik": test.isna().sum(),
        "test %": 100 * test.isna().mean(),
    })
    miss = miss[miss["train eksik"] + miss["test eksik"] > 0].sort_values("train %", ascending=False)
    miss.index.name = "sütun"
    out.append("### 4.1 `?` ile işaretlenmiş eksik değerler\n")
    out.append(md_table(miss))

    # migration sütunları neden yarı yarıya boş?
    mig = [c for c in train.columns if c.startswith("migration_")]
    by_year = train.groupby("year")[mig].apply(lambda g: 100 * g.isna().mean())
    by_year.index.name = "year"
    out.append("\n### 4.2 `migration_*` sütunlarının yıla göre eksiklik oranı (%)\n")
    out.append(md_table(by_year))
    out.append(
        "\n> `migration_*` sütunları **1995 yılı kayıtlarında tamamen boş**, 1994'te ise hiç "
        "eksik yok. Yani bu bir rastgele eksiklik değil, 1995 anketinde bu sorular hiç "
        "sorulmamış. Bu sütunlar ya modelden çıkarılmalı ya da eksiklik ayrı bir kategori "
        "('Unknown') olarak tutulmalı.\n"
    )

    # 'Not in universe' - eksik değil, 'uygulanamaz' anlamında
    cat_cols = train.select_dtypes(include=["object", "string"]).columns
    niu = {}
    for c in cat_cols:
        share = train[c].astype(str).str.startswith("Not in universe").mean()
        if share > 0:
            niu[c] = 100 * share
    niu_df = pd.Series(niu, name="'Not in universe' %").sort_values(ascending=False).to_frame()
    niu_df.index.name = "sütun"
    out.append("\n### 4.3 'Not in universe' oranları\n")
    out.append(
        "'Not in universe' **eksik değer değildir**; sorunun o kişiye uygulanmadığını "
        "gösterir (ör. çocuklara meslek sorulmaz). Bu yüzden NULL'a çevrilmedi, ayrı bir "
        "kategori olarak bırakıldı.\n"
    )
    out.append(md_table(niu_df))
    return "\n".join(out) + "\n"


def section_duplicate_rows(train: pd.DataFrame, test: pd.DataFrame) -> tuple[str, pd.DataFrame, pd.DataFrame]:
    features = [c for c in train.columns if c not in ("instance_weight", TARGET)]
    out = ["## 5. Tekrar Eden Satırlar\n"]
    stats = {}
    for name, df in [("train", train), ("test", test)]:
        full = int(df.duplicated().sum())
        no_w = int(df.duplicated(subset=features + [TARGET]).sum())
        feat = int(df.duplicated(subset=features).sum())
        conflicting_groups = (
            df.groupby(features, dropna=False)[TARGET].nunique().gt(1).sum()
        )
        stats[name] = {
            "birebir aynı satır": full,
            "ağırlık hariç aynı": no_w,
            "öznitelikler aynı (hedef hariç)": feat,
            "çelişkili grup (aynı öznitelik, farklı hedef)": int(conflicting_groups),
        }
    t = pd.DataFrame(stats).T
    t.index.name = "küme"
    out.append(md_table(t))

    train_d = train.drop_duplicates().reset_index(drop=True)
    test_d = test.drop_duplicates().reset_index(drop=True)
    out.append(
        "\n**Karar:**\n"
        f"- **Birebir aynı** satırlar (ağırlık dahil her şey aynı) gerçek tekrar kabul edildi ve "
        f"**silindi**: train {len(train):,} → {len(train_d):,}, test {len(test):,} → {len(test_d):,}.\n"
        "- **Ağırlık hariç aynı** olan satırlar silinmedi: farklı `instance_weight` değerleri "
        "bunların ankette farklı kişiler olduğunu gösteriyor. Bunların çoğu çocuk ve çalışmayan "
        "kişiler; neredeyse tüm alanları 'Not in universe' / 0. Veritabanına hepsi kişi olarak "
        "girecek. Modelleme aşamasında ayrıca tekilleştirmek istenirse "
        "`drop_duplicates(subset=öznitelikler)` kullanılabilir.\n"
        "- **Çelişkili** gruplar (aynı özellikler, farklı gelir sınıfı) veri setinin doğal "
        "gürültüsüdür; hiçbir model bunları %100 doğru ayıramaz.\n"
    )

    # train-test çakışması
    key = features
    overlap = test_d.merge(train_d[key].drop_duplicates(), on=key, how="inner")
    out.append(
        f"\n**Train–test çakışması:** test kümesindeki {len(test_d):,} satırdan "
        f"**{len(overlap):,}** tanesinin ({100 * len(overlap) / len(test_d):.1f}%) öznitelikleri "
        "train kümesinde birebir var. Bunlar çoğunlukla çocuk / çalışmayan kişilerin 'boş' "
        "profilleri olduğundan veri sızıntısı riski düşük, ama raporlarken bilinmesi iyi olur.\n"
    )
    return "\n".join(out), train_d, test_d


def section_duplicate_columns(train: pd.DataFrame) -> str:
    out = ["## 6. Tekrar Eden / Türetilebilir Sütunlar\n"]

    # 6.1 Birebir aynı sütunlar
    # Hız için her sütun bir kez tam sayı kodlarına çevrilir (factorize).
    # İki sütunun kodları aynı değilse değerleri de kesin aynı değildir; kodları aynı
    # çıkanlar için gerçek değerler ayrıca karşılaştırılır.
    identical = []
    cols = list(train.columns)
    codes = {c: pd.factorize(train[c], use_na_sentinel=False)[0] for c in cols}
    nuniq = {c: int(codes[c].max()) + 1 for c in cols}
    for a, b in itertools.combinations(cols, 2):
        if (
            nuniq[a] == nuniq[b]
            and np.array_equal(codes[a], codes[b])
            and train[a].astype(str).equals(train[b].astype(str))
        ):
            identical.append((a, b))
    out.append("### 6.1 Birebir aynı sütunlar\n")
    out.append(
        "Yok – hiçbir sütun çifti birebir aynı değil.\n" if not identical
        else "\n".join(f"- `{a}` = `{b}`" for a, b in identical) + "\n"
    )

    # 6.2 Sabit sütun
    const = [c for c in cols if train[c].nunique(dropna=False) <= 1]
    out.append("### 6.2 Sabit (tek değerli) sütunlar\n")
    out.append("Yok.\n" if not const else "\n".join(f"- `{c}`" for c in const) + "\n")

    # 6.3 Fonksiyonel bağımlılıklar (A -> B): A bilinirse B kesin bilinir.
    # NULL'lar bağımlılıkları yapay olarak oluşturmasın diye yalnızca eksiksiz satırlar
    # ve eksik değeri olmayan sütunlar üzerinden bakılır.
    cand = [
        c for c in cols
        if c not in NUMERIC_COLS and c != TARGET and train[c].notna().all()
        and 1 < train[c].nunique() < 100
    ]
    fds = []
    for a, b in itertools.permutations(cand, 2):
        if nuniq[a] <= nuniq[b]:
            continue  # anlamlı bağımlılık: daha detaylı -> daha özet
        # A -> B ancak (A, B) çiftlerinin farklı sayısı A'nın farklı değer sayısına eşitse
        pair_counts = np.bincount(codes[a] * nuniq[b] + codes[b], minlength=nuniq[a] * nuniq[b])
        if np.count_nonzero(pair_counts) == nuniq[a]:
            fds.append((a, b, nuniq[a], nuniq[b]))
    out.append("### 6.3 Fonksiyonel bağımlılıklar (A → B)\n")
    out.append(
        "A'nın değeri B'nin değerini kesin olarak belirliyorsa B, A'dan türetilebilir; yani "
        "aynı bilgi iki kez tutuluyor demektir. **Bu, normalizasyon (3NF) için doğrudan "
        "girdidir.**\n"
    )
    if fds:
        fd_df = pd.DataFrame(fds, columns=["A (detaylı)", "B (özet)", "A farklı değer", "B farklı değer"])
        out.append(md_table(fd_df, index=False))
    else:
        out.append("Bulunamadı.")

    # 6.4 Neredeyse bağımlı: household detay -> özet
    a, b = "detailed_household_and_family_stat", "detailed_household_summary_in_household"
    purity = train.groupby(a)[b].agg(lambda s: s.value_counts(normalize=True).iloc[0])
    weighted = (purity * train[a].value_counts(normalize=True)).sum()
    out.append(
        f"\n### 6.4 Neredeyse bağımlı sütunlar\n\n"
        f"- `{a}` ({train[a].nunique()} değer) → `{b}` ({train[b].nunique()} değer): "
        f"satırların **%{100 * weighted:.2f}**'inde detay değer özet değeri belirliyor. "
        "Özet sütun büyük ölçüde detaydan türetilmiş.\n"
        "- `country_of_birth_self` ile `citizenship` ilişkili ama bağımlı değil "
        "(yabancı doğumlu biri vatandaş olabilir de olmayabilir de).\n"
    )

    out.append(
        "\n**Karar:** Birebir aynı ya da sabit sütun olmadığından temiz dosyadan **hiçbir sütun "
        "silinmedi**. `major_industry_code` ve `major_occupation_code` detay kodlardan "
        "türetilebiliyor, ancak detay kodlar sadece sayı; okunabilir isimler özet sütunlarda. "
        "Bu yüzden bu sütunlar silinmeyip **veritabanı tasarımında ayrı lookup tablolarına "
        "taşınacak**:\n\n"
        "```\n"
        "Industry(detailed_industry_code PK, major_industry_id FK)  ->  MajorIndustry(id PK, name)\n"
        "Occupation(detailed_occupation_code PK, major_occupation_id FK) -> MajorOccupation(id PK, name)\n"
        "Person(..., detailed_industry_code FK, detailed_occupation_code FK, ...)\n"
        "```\n"
        "Böylece özet bilgi `Person` tablosunda tekrar tekrar tutulmaz (geçişli bağımlılık "
        "giderilir).\n"
    )
    return "\n".join(out)


def section_numeric(train: pd.DataFrame) -> str:
    num = train[NUMERIC_COLS]
    desc = num.describe().T[["mean", "std", "min", "25%", "50%", "75%", "max"]]
    desc["sıfır %"] = 100 * (num == 0).mean()
    desc.index.name = "sütun"
    return (
        "## 7. Sayısal Sütunlar (train)\n\n" + md_table(desc) +
        "\n\n**Gözlemler:**\n"
        "- `wage_per_hour`, `capital_gains`, `capital_losses`, `dividends_from_stocks` "
        "sütunlarında değerlerin %89–98'i **0**. Dağılımlar çok çarpık; modelde "
        "log(1+x) dönüşümü ya da '0 mı değil mi' bayrağı faydalı olabilir.\n"
        "- `wage_per_hour` en fazla 9999. Değer büyük ihtimalle **cent** cinsinden "
        "(9999 = $99.99/saat), üst sınırda kesilmiş (top-coded).\n"
        "- `capital_gains` en fazla 99999. Bu da aynı şekilde kesilmiş bir değer.\n"
        "- `age` 0–90 arasında. 18 yaş altı kayıtlar (çocuklar) verinin büyük bir kısmı ve "
        "neredeyse hepsi 50K altı.\n"
    )


def section_target_by(train: pd.DataFrame) -> str:
    out = ["## 8. Bazı Öznitelikler ve Yüksek Gelir Oranı (train)\n"]
    for col in ["education", "sex", "class_of_worker", "marital_stat"]:
        g = train.groupby(col)[TARGET].agg(kayıt="size", yuksek_gelir_orani="mean")
        g["yuksek_gelir_orani"] *= 100
        g = g.sort_values("yuksek_gelir_orani", ascending=False)
        g.index.name = col
        out.append(f"### {col}\n\n" + md_table(g.rename(columns={"yuksek_gelir_orani": "50K+ %"})) + "\n")

    bins = [-1, 17, 24, 34, 44, 54, 64, 120]
    labels = ["0-17", "18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    ag = train.groupby(pd.cut(train["age"], bins=bins, labels=labels), observed=True)[TARGET] \
        .agg(kayıt="size", oran="mean")
    ag["oran"] *= 100
    ag.index.name = "yaş grubu"
    out.append("### Yaş grubu\n\n" + md_table(ag.rename(columns={"oran": "50K+ %"})) + "\n")
    return "\n".join(out)


def section_next_steps() -> str:
    return (
        "## 9. Sonraki Adımlar İçin Notlar\n\n"
        "1. **Veritabanı tasarımı:** Kategorik metin sütunları (education, marital_stat, race, "
        "country_*, state, ...) lookup tablolarına taşınmalı. `country_of_birth_father / mother "
        "/ self` aynı `Country` tablosunu referans alacak 3 FK olmalı.\n"
        "2. **Hiyerarşik kodlar:** detailed → major industry/occupation, Bölüm 6.3'teki gibi "
        "iki seviyeli lookup.\n"
        "3. **NULL'lar:** `?` değerleri veritabanında `NULL` olarak tutulacak; 'Not in universe' "
        "ise lookup tablolarında normal bir değer olacak.\n"
        "4. **ML:** `instance_weight` öznitelik olarak kullanılmayacak (istenirse "
        "`sample_weight` olarak verilebilir). `migration_*` sütunları için karar verilmeli. "
        "Dengesiz sınıflar için uygun metrik ve `class_weight` kullanılmalı.\n"
    )


# --------------------------------------------------------------------------- #
def main() -> None:
    start = time.perf_counter()

    def step(msg: str) -> None:
        print(f"[{time.perf_counter() - start:5.1f} sn] {msg}", flush=True)

    step("Veri okunuyor...")
    train = load(RAW_DIR / "census-income.data")
    test = load(RAW_DIR / "census-income.test")

    parts = [
        "# Ön Analiz Raporu – Census-Income (KDD)\n",
        "_Bu dosya `analysis/pre_analiz.py` tarafından otomatik üretilmiştir._\n",
    ]
    step("1-2. Genel bakış ve hedef dağılımı")
    parts += [section_overview(train, test), section_target(train, test)]
    step("3. Sütun profili")
    parts.append(section_columns(train))
    step("4. Eksik değerler")
    parts.append(section_missing(train, test))
    step("5. Tekrar eden satırlar")
    dup_md, train_clean, test_clean = section_duplicate_rows(train, test)
    parts.append(dup_md)
    step("6. Tekrar eden / türetilebilir sütunlar")
    parts.append(section_duplicate_columns(train_clean))
    step("7-8. Sayısal özet ve gelir oranları")
    parts += [section_numeric(train_clean), section_target_by(train_clean), section_next_steps()]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    step("Temiz CSV dosyaları ve rapor yazılıyor...")
    train_clean.to_csv(OUT_DIR / "train_clean.csv", index=False)
    test_clean.to_csv(OUT_DIR / "test_clean.csv", index=False)
    REPORT_PATH.write_text("\n\n".join(parts), encoding="utf-8")

    step("Bitti.")
    print(f"Temiz train : {OUT_DIR / 'train_clean.csv'}  ({len(train_clean):,} satır)")
    print(f"Temiz test  : {OUT_DIR / 'test_clean.csv'}  ({len(test_clean):,} satır)")
    print(f"Rapor       : {REPORT_PATH}")


if __name__ == "__main__":
    main()
