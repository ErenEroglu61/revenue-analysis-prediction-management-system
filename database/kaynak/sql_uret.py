"""
Veri setinden INSERT scriptlerini üretir.

  03_insert_lookup_data.sql : 25 lookup tablosunun TÜM değerleri (train + test'teki farklı değerler)
  04_insert_sample_data.sql : Örnek kişiler (PERSON + 1:1 tablolar) ve ML tablolarına örnek kayıtlar

Örnek kişiler rastgele değil, raporda tekrar / anomali durumlarını gösterebilecek şekilde seçilir:
aynı sektörde çalışan birden çok kişi, 1994 (göç bilgisi var) ve 1995 (yok) kayıtları, ülkesi bilinmeyen
(NULL) kişiler, çocuklar, 50K üstü kazananlar, train ve test kayıtları.

ML tablolarındaki metrikler ve tahminler uydurma değildir: iki basit model (lojistik regresyon ve karar
ağacı) train kümesinde eğitilir, metrikleri test kümesinde hesaplanır.

Girdi : data/processed/train_features.csv, test_features.csv (önce analysis/ scriptleri çalışmalı)
Çalıştırma (proje kök dizininden):  python database/kaynak/sql_uret.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (average_precision_score, f1_score, precision_score, recall_score,
                             roc_auc_score)
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

ROOT = Path(__file__).resolve().parents[2]
PROCESSED = ROOT / "data" / "processed"
DB_DIR = ROOT / "database"
SEED = 42
N_SAMPLE = 24

EDUCATION_LEVELS = {
    "Children": 0, "Less than 1st grade": 1, "1st 2nd 3rd or 4th grade": 2, "5th or 6th grade": 3,
    "7th and 8th grade": 4, "9th grade": 5, "10th grade": 6, "11th grade": 7, "12th grade no diploma": 8,
    "High school graduate": 9, "Some college but no degree": 10, "Associates degree-occup /vocational": 11,
    "Associates degree-academic program": 12, "Bachelors degree(BA AB BS)": 13,
    "Masters degree(MA MS MEng MEd MSW MBA)": 14, "Prof school degree (MD DDS DVM LLB JD)": 15,
    "Doctorate degree(PhD EdD)": 16,
}

# (tablo, id sütunu, ad sütunu, kaynak sütun(lar))
SIMPLE_LOOKUPS = [
    ("SEX", "SexID", "SexName", ["sex"]),
    ("RACE", "RaceID", "RaceName", ["race"]),
    ("HISPANIC_ORIGIN", "HispanicOriginID", "OriginName", ["hispanic_origin"]),
    ("MARITAL_STATUS", "MaritalStatusID", "StatusName", ["marital_stat"]),
    ("EDU_ENROLLMENT", "EduEnrollmentID", "EnrollmentName", ["enroll_in_edu_inst_last_wk"]),
    ("CITIZENSHIP", "CitizenshipID", "CitizenshipName", ["citizenship"]),
    ("COUNTRY", "CountryID", "CountryName",
     ["country_of_birth_self", "country_of_birth_father", "country_of_birth_mother"]),
    ("ANSWER", "AnswerID", "AnswerText",
     ["member_of_labor_union", "fill_inc_questionnaire_for_veterans_admin",
      "live_in_this_house_1_year_ago", "migration_prev_res_in_sunbelt"]),
    ("CLASS_OF_WORKER", "ClassOfWorkerID", "ClassName", ["class_of_worker"]),
    ("MAJOR_INDUSTRY", "MajorIndustryID", "IndustryName", ["major_industry_code"]),
    ("MAJOR_OCCUPATION", "MajorOccupationID", "OccupationName", ["major_occupation_code"]),
    ("EMPLOYMENT_STATUS", "EmploymentStatusID", "StatusName", ["full_or_part_time_employment_stat"]),
    ("UNEMPLOYMENT_REASON", "UnemploymentReasonID", "ReasonName", ["reason_for_unemployment"]),
    ("TAX_FILER_STATUS", "TaxFilerStatusID", "StatusName", ["tax_filer_stat"]),
    ("HOUSEHOLD_DETAIL", "HouseholdDetailID", "DetailName", ["detailed_household_and_family_stat"]),
    ("HOUSEHOLD_SUMMARY", "HouseholdSummaryID", "SummaryName", ["detailed_household_summary_in_household"]),
    ("FAMILY_UNDER_18", "FamilyUnder18ID", "ParentsPresent", ["family_members_under_18"]),
    ("REGION", "RegionID", "RegionName", ["region_of_previous_residence"]),
    ("STATE", "StateID", "StateName", ["state_of_previous_residence"]),
    ("MSA_CHANGE", "MsaChangeID", "ChangeName", ["migration_code_change_in_msa"]),
    ("REGION_CHANGE", "RegionChangeID", "ChangeName", ["migration_code_change_in_reg"]),
    ("WITHIN_REGION_MOVE", "WithinRegionMoveID", "MoveName", ["migration_code_move_within_reg"]),
]

ML_FEATURES = ["age", "education_level", "weeks_worked_in_year", "wage_per_hour", "capital_gains",
               "capital_losses", "dividends_from_stocks", "num_persons_worked_for_employer",
               "is_employed", "full_year_worker", "is_professional_occ", "has_investment",
               "is_householder", "joint_filer", "is_married"]


def q(v) -> str:
    """Python değerini T-SQL literaline çevirir."""
    if v is None or (isinstance(v, float) and np.isnan(v)):
        return "NULL"
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return f"{v:.4f}".rstrip("0").rstrip(".")
    return "N'" + str(v).replace("'", "''") + "'"


def insert_block(table: str, cols: list[str], rows: list[list], identity: bool = False) -> str:
    out = [f"-- {table}: {len(rows)} kayıt"]
    if identity:
        out.append(f"SET IDENTITY_INSERT {table} ON;")
    head = f"INSERT INTO {table} ({', '.join(cols)}) VALUES"
    # SQL Server tek INSERT'te en fazla 1000 satır kabul eder
    for i in range(0, len(rows), 500):
        chunk = rows[i:i + 500]
        out.append(head)
        out.append(",\n".join("    (" + ", ".join(q(v) for v in r) + ")" for r in chunk) + ";")
    if identity:
        out.append(f"SET IDENTITY_INSERT {table} OFF;")
    return "\n".join(out) + "\n"


def load():
    kw = dict(keep_default_na=False, na_values=[""])
    tr = pd.read_csv(PROCESSED / "train_features.csv", **kw).assign(DataSplit="train")
    te = pd.read_csv(PROCESSED / "test_features.csv", **kw).assign(DataSplit="test")
    return tr, te


def build_lookups(df: pd.DataFrame):
    maps, sql = {}, []
    for table, idc, namec, cols in SIMPLE_LOOKUPS:
        vals = sorted(set().union(*[set(df[c].dropna().astype(str)) for c in cols]))
        maps[table] = {v: i + 1 for i, v in enumerate(vals)}
        sql.append(insert_block(table, [idc, namec], [[i + 1, v] for i, v in enumerate(vals)]))
    # EDUCATION: sıralı seviye ile
    edu = sorted(EDUCATION_LEVELS.items(), key=lambda kv: kv[1])
    maps["EDUCATION"] = {name: lvl + 1 for name, lvl in edu}
    sql.insert(4, insert_block("EDUCATION", ["EducationID", "EducationName", "EducationLevel"],
                               [[lvl + 1, name, lvl] for name, lvl in edu]))
    # INDUSTRY / OCCUPATION: detay kod -> üst grup
    for table, code_col, major_col, major_table, cols in [
            ("INDUSTRY", "detailed_industry_recode", "major_industry_code", "MAJOR_INDUSTRY",
             ["IndustryCode", "MajorIndustryID"]),
            ("OCCUPATION", "detailed_occupation_recode", "major_occupation_code", "MAJOR_OCCUPATION",
             ["OccupationCode", "MajorOccupationID"])]:
        pairs = df[[code_col, major_col]].drop_duplicates().sort_values(code_col)
        assert pairs[code_col].is_unique, f"{code_col} -> {major_col} fonksiyonel bağımlılığı bozuk"
        rows = [[int(c), maps[major_table][m]] for c, m in pairs.itertuples(index=False)]
        sql.append(insert_block(table, cols, rows))
    return maps, sql


def pick_sample(tr: pd.DataFrame, te: pd.DataFrame) -> pd.DataFrame:
    """Raporda tekrar/anomali gösterebilecek, çeşitli örnek kişiler seçer."""
    rng = np.random.default_rng(SEED)
    df = pd.concat([tr, te], ignore_index=True)
    picks: list[int] = []

    def take(mask, n):
        idx = df.index[mask & ~df.index.isin(picks)]
        picks.extend(rng.choice(idx, size=min(n, len(idx)), replace=False).tolist())

    adult = df.age >= 18
    # Aynı detay sektörde çalışan 5 kişi (sektör adı tekrarını göstermek için)
    top_ind = df.loc[df.detailed_industry_recode != 0, "detailed_industry_recode"].mode()[0]
    take(adult & (df.detailed_industry_recode == top_ind), 5)
    take(adult & (df.income_over_50k == 1) & (df.DataSplit == "train"), 4)   # 50K üstü
    take(adult & (df.income_over_50k == 1) & (df.DataSplit == "test"), 2)
    take(df.age < 18, 3)                                                       # çocuklar
    take(adult & df.country_of_birth_father.isna(), 2)                          # ülkesi bilinmeyen
    take(adult & (df.year == 94) & (df.migration_code_change_in_msa != "Nonmover"), 3)  # taşınanlar
    take(adult & (df.DataSplit == "test"), N_SAMPLE - len(picks))
    s = df.loc[picks].copy()
    # Okunabilirlik için: önce train, sonra test; yıl ve yaşa göre sıralı
    s = s.sort_values(["DataSplit", "year", "age"], ascending=[False, True, True]).reset_index(drop=True)
    s["PersonID"] = np.arange(1, len(s) + 1)
    s["RecordID"] = s["PersonID"] + 1000   # PersonID ile karışmasın diye farklı aralık
    return s


def build_sample(s: pd.DataFrame, maps: dict) -> list[str]:
    m = lambda t, v: None if pd.isna(v) else maps[t][str(v)]
    sql = []
    sql.append(insert_block("PERSON", [
        "PersonID", "Age", "SexID", "RaceID", "HispanicOriginID", "MaritalStatusID", "EducationID",
        "EduEnrollmentID", "CitizenshipID", "BirthCountryID", "FatherBirthCountryID", "MotherBirthCountryID",
        "VetQuestionnaireAnswerID", "VeteransBenefits"], [[
            r.PersonID, r.age, m("SEX", r.sex), m("RACE", r.race), m("HISPANIC_ORIGIN", r.hispanic_origin),
            m("MARITAL_STATUS", r.marital_stat), m("EDUCATION", r.education),
            m("EDU_ENROLLMENT", r.enroll_in_edu_inst_last_wk), m("CITIZENSHIP", r.citizenship),
            m("COUNTRY", r.country_of_birth_self), m("COUNTRY", r.country_of_birth_father),
            m("COUNTRY", r.country_of_birth_mother),
            m("ANSWER", r.fill_inc_questionnaire_for_veterans_admin), r.veterans_benefits]
        for r in s.itertuples()], identity=True))
    sql.append(insert_block("SURVEY_RECORD", [
        "RecordID", "PersonID", "SurveyYear", "DataSplit", "InstanceWeight", "IncomeOver50K"], [[
            r.RecordID, r.PersonID, 1900 + int(r.year), r.DataSplit, round(float(r.instance_weight), 2),
            r.income_over_50k] for r in s.itertuples()], identity=True))
    sql.append(insert_block("EMPLOYMENT", [
        "PersonID", "ClassOfWorkerID", "IndustryCode", "OccupationCode", "EmploymentStatusID",
        "UnemploymentReasonID", "LaborUnionAnswerID", "WeeksWorkedInYear", "NumPersonsWorkedForEmp",
        "OwnBusinessSelfEmployed"], [[
            r.PersonID, m("CLASS_OF_WORKER", r.class_of_worker), r.detailed_industry_recode,
            r.detailed_occupation_recode, m("EMPLOYMENT_STATUS", r.full_or_part_time_employment_stat),
            m("UNEMPLOYMENT_REASON", r.reason_for_unemployment), m("ANSWER", r.member_of_labor_union),
            r.weeks_worked_in_year, r.num_persons_worked_for_employer, r.own_business_or_self_employed]
        for r in s.itertuples()]))
    sql.append(insert_block("FINANCE", [
        "PersonID", "TaxFilerStatusID", "WagePerHour", "CapitalGains", "CapitalLosses", "DividendsFromStocks"], [[
            r.PersonID, m("TAX_FILER_STATUS", r.tax_filer_stat), r.wage_per_hour, r.capital_gains,
            r.capital_losses, r.dividends_from_stocks] for r in s.itertuples()]))
    sql.append(insert_block("HOUSEHOLD", [
        "PersonID", "HouseholdDetailID", "HouseholdSummaryID", "FamilyUnder18ID"], [[
            r.PersonID, m("HOUSEHOLD_DETAIL", r.detailed_household_and_family_stat),
            m("HOUSEHOLD_SUMMARY", r.detailed_household_summary_in_household),
            m("FAMILY_UNDER_18", r.family_members_under_18)] for r in s.itertuples()]))
    sql.append(insert_block("RESIDENCE", [
        "PersonID", "LivedInHouseAnswerID", "PrevRegionID", "PrevStateID"], [[
            r.PersonID, m("ANSWER", r.live_in_this_house_1_year_ago),
            m("REGION", r.region_of_previous_residence), m("STATE", r.state_of_previous_residence)]
        for r in s.itertuples()]))
    mig = s[s.year == 94]
    sql.append(insert_block("MIGRATION", [
        "PersonID", "MsaChangeID", "RegionChangeID", "SunbeltAnswerID", "WithinRegionMoveID"], [[
            r.PersonID, m("MSA_CHANGE", r.migration_code_change_in_msa),
            m("REGION_CHANGE", r.migration_code_change_in_reg), m("ANSWER", r.migration_prev_res_in_sunbelt),
            m("WITHIN_REGION_MOVE", r.migration_code_move_within_reg)] for r in mig.itertuples()]))
    return sql


def build_ml(tr: pd.DataFrame, te: pd.DataFrame, s: pd.DataFrame) -> list[str]:
    y_tr, y_te = tr.income_over_50k.values, te.income_over_50k.values
    models = [
        ("LogReg_Baseline_v1", "LogisticRegression",
         {"C": 1.0, "class_weight": "balanced", "max_iter": 1000, "scaler": "StandardScaler"},
         make_pipeline(StandardScaler(), LogisticRegression(C=1.0, class_weight="balanced", max_iter=1000))),
        ("DecisionTree_Depth8_v1", "DecisionTreeClassifier",
         {"max_depth": 8, "class_weight": "balanced", "random_state": SEED},
         DecisionTreeClassifier(max_depth=8, class_weight="balanced", random_state=SEED)),
    ]
    model_rows, metric_rows, pred_rows = [], [], []
    for mid, (name, algo, hp, est) in enumerate(models, start=1):
        print(f"  model eğitiliyor: {name}")
        est.fit(tr[ML_FEATURES], y_tr)
        model_rows.append([mid, name, algo, json.dumps(hp), "2026-11-20 14:00:00"])
        for split, X, y in [("train", tr[ML_FEATURES], y_tr), ("test", te[ML_FEATURES], y_te)]:
            p = est.predict_proba(X)[:, 1]
            yhat = (p >= 0.5).astype(int)
            for mname, val in [("roc_auc", roc_auc_score(y, p)), ("pr_auc", average_precision_score(y, p)),
                               ("f1", f1_score(y, yhat)), ("precision", precision_score(y, yhat)),
                               ("recall", recall_score(y, yhat))]:
                metric_rows.append([mid, split, mname, round(float(val), 4)])
        # Örnek kişilerin tahminleri (yalnızca test kayıtları: modelin görmediği veri)
        st = s[s.DataSplit == "test"]
        p = est.predict_proba(st[ML_FEATURES])[:, 1]
        for rec, prob in zip(st.RecordID, p):
            pred_rows.append([mid, int(rec), round(float(prob), 4), int(prob >= 0.5), "2026-11-20 14:05:00"])
    metric_rows = [[i + 1] + r for i, r in enumerate(metric_rows)]
    pred_rows = [[i + 1] + r for i, r in enumerate(pred_rows)]
    return [
        insert_block("ML_MODEL", ["ModelID", "ModelName", "Algorithm", "Hyperparameters", "TrainedAt"],
                     model_rows, identity=True),
        insert_block("MODEL_METRIC", ["MetricID", "ModelID", "DataSplit", "MetricName", "MetricValue"],
                     metric_rows, identity=True),
        insert_block("PREDICTION", ["PredictionID", "ModelID", "RecordID", "PredictedProbability",
                                    "PredictedLabel", "PredictedAt"], pred_rows, identity=True),
    ]


HEADER = """/* ============================================================================
   {title}
   BU DOSYA OTOMATİK ÜRETİLMİŞTİR: python database/kaynak/sql_uret.py
   Elle düzenlemeyin; değişiklik gerekiyorsa scripti düzenleyip yeniden çalıştırın.
   ============================================================================ */
USE GelirAnalizDB;
GO
SET NOCOUNT ON;

"""


def main():
    if not (PROCESSED / "train_features.csv").exists():
        raise SystemExit("Önce çalıştırın: python analysis/pre_analiz.py && python analysis/turetilmis_ozellikler.py")
    print("Veri okunuyor...")
    tr, te = load()
    df = pd.concat([tr, te], ignore_index=True)

    maps, lk_sql = build_lookups(df)
    (DB_DIR / "03_insert_lookup_data.sql").write_text(
        HEADER.format(title="03 - Lookup tablolarına veri girişi (25 tablo, veri setindeki tüm değerler)")
        + "BEGIN TRANSACTION;\n\n" + "\n".join(lk_sql) + "\nCOMMIT;\nGO\nPRINT N'Lookup verileri yüklendi.';\n",
        encoding="utf-8")

    s = pick_sample(tr, te)
    sample_sql = build_sample(s, maps)
    ml_sql = build_ml(tr, te, s)
    (DB_DIR / "04_insert_sample_data.sql").write_text(
        HEADER.format(title=f"04 - Ana tablolara ({len(s)} örnek kişi) ve ML tablolarına örnek veri girişi")
        + "BEGIN TRANSACTION;\n\n" + "\n".join(sample_sql + ml_sql)
        + "\nCOMMIT;\nGO\nPRINT N'Örnek veriler yüklendi.';\n", encoding="utf-8")
    print(f"Bitti: {len(s)} örnek kişi, {len(s[s.year == 94])} göç kaydı.")


if __name__ == "__main__":
    main()
