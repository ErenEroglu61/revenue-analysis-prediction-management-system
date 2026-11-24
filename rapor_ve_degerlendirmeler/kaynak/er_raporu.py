"""
Adım 1 – Kavramsal Tasarım (ER Modeli) raporunu üretir.

  * ER diyagramlarını (crow's foot notasyonu) matplotlib ile çizer
  * Veri setinden istatistikleri (kayıt sayıları, fonksiyonel bağımlılık kontrolleri) canlı hesaplar
  * Hepsini tek bir PDF raporda birleştirir

Girdi : data/processed/train_clean.csv, test_clean.csv   (önce analysis/pre_analiz.py çalışmalı)
Çıktı : rapor_ve_degerlendirmeler/01_kavramsal_tasarim_ER_modeli.pdf
        rapor_ve_degerlendirmeler/gorseller/er_*.png

Çalıştırma (proje kök dizininden):
    python rapor_ve_degerlendirmeler/kaynak/er_raporu.py
Gerekli paketler: pandas, matplotlib, reportlab
"""

from __future__ import annotations

import datetime as dt
from pathlib import Path
from xml.sax.saxutils import escape

import matplotlib

matplotlib.use("Agg")
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, Frame, Image, KeepTogether, NextPageTemplate,
                                PageBreak, PageTemplate, Paragraph, Spacer, Table, TableStyle)

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "rapor_ve_degerlendirmeler"
IMG_DIR = OUT_DIR / "gorseller"
PDF_PATH = OUT_DIR / "01_kavramsal_tasarim_ER_modeli.pdf"
PROCESSED = ROOT / "data" / "processed"

# Renkler
C_CORE, C_LOOKUP, C_ML = "#2a78d6", "#5f6b7a", "#eb6834"
C_INK, C_MUTED, C_LINE = "#1b1b1b", "#52514e", "#3d3d3a"

# --------------------------------------------------------------------------- #
# 1) Veri istatistikleri
# --------------------------------------------------------------------------- #
def load_stats() -> dict:
    kw = dict(keep_default_na=False, na_values=[""])
    tr = pd.read_csv(PROCESSED / "train_clean.csv", **kw)
    te = pd.read_csv(PROCESSED / "test_clean.csv", **kw)
    df = pd.concat([tr, te], ignore_index=True)

    def fd_violations(a, b):
        g = df.dropna(subset=[a, b]).groupby(a)[b].nunique()
        return int((g > 1).sum()), int(len(g))

    countries = set()
    for c in ["country_of_birth_self", "country_of_birth_father", "country_of_birth_mother"]:
        countries |= set(df[c].dropna())

    abroad_west = int(((df.state_of_previous_residence == "Abroad")
                       & (df.region_of_previous_residence == "West")).sum())
    state_null = int(df.state_of_previous_residence.isna().sum())
    return {
        "n_train": len(tr), "n_test": len(te), "n": len(df),
        "n_1994": int((df.year == 94).sum()), "n_1995": int((df.year == 95).sum()),
        "nuniq": df.nunique(dropna=True).to_dict(),
        "n_country": len(countries),
        "fd_industry": fd_violations("detailed_industry_recode", "major_industry_code"),
        "fd_occupation": fd_violations("detailed_occupation_recode", "major_occupation_code"),
        "fd_state": fd_violations("state_of_previous_residence", "region_of_previous_residence"),
        "fd_household": fd_violations("detailed_household_and_family_stat",
                                      "detailed_household_summary_in_household"),
        "abroad_west": abroad_west, "state_null": state_null,
        "group_quarters": df.loc[df.detailed_household_and_family_stat == "In group quarters",
                                 "detailed_household_summary_in_household"].nunique(),
        "null_pct": (100 * df.isna().mean()).to_dict(),
        "niu_cells": int(sum(df[c].astype(str).str.startswith("Not in universe").sum()
                             for c in df.select_dtypes(include=["object", "string"]).columns)),
        "text_cells": int(df.select_dtypes(include=["object", "string"]).size),
    }


# --------------------------------------------------------------------------- #
# 2) ER diyagramı çizim yardımcıları (crow's foot)
# --------------------------------------------------------------------------- #
ROW_H, HEAD_H = 2.5, 3.6


class Box:
    def __init__(self, ax, x, top, w, title, attrs, kind="core"):
        self.x, self.top, self.w = x, top, w
        self.h = HEAD_H + ROW_H * len(attrs)
        self.y = top - self.h
        color = {"core": C_CORE, "lookup": C_LOOKUP, "ml": C_ML}[kind]
        ax.add_patch(mpatches.FancyBboxPatch((x, self.y), w, self.h, boxstyle="round,pad=0,rounding_size=0.6",
                                             fc="white", ec=color, lw=1.4, zorder=3))
        ax.add_patch(mpatches.FancyBboxPatch((x, top - HEAD_H), w, HEAD_H,
                                             boxstyle="round,pad=0,rounding_size=0.6",
                                             fc=color, ec=color, lw=1.4, zorder=4))
        ax.text(x + w / 2, top - HEAD_H / 2, title, ha="center", va="center", color="white",
                fontsize=9.5, fontweight="bold", zorder=5)
        for i, (key, name) in enumerate(attrs):
            yy = top - HEAD_H - ROW_H * (i + 0.5)
            if i:
                ax.plot([x + 0.4, x + w - 0.4], [yy + ROW_H / 2] * 2, color="#e6e5e1", lw=0.6, zorder=4)
            if key:
                ax.text(x + 0.8, yy, key, ha="left", va="center", fontsize=6.8, fontweight="bold",
                        color=color, zorder=5)
            ax.text(x + 6.3, yy, name, ha="left", va="center", fontsize=8,
                    color=C_INK, zorder=5, fontweight="bold" if key and "PK" in key else "normal")

    def anchor(self, side, frac=0.5):
        if side == "l":
            return np.array([self.x, self.top - frac * self.h]), np.array([-1.0, 0])
        if side == "r":
            return np.array([self.x + self.w, self.top - frac * self.h]), np.array([1.0, 0])
        if side == "t":
            return np.array([self.x + frac * self.w, self.top]), np.array([0, 1.0])
        return np.array([self.x + frac * self.w, self.y]), np.array([0, -1.0])


def _marker(ax, p, u, kind):
    perp = np.array([-u[1], u[0]])
    kw = dict(color=C_LINE, lw=1.1, zorder=2.5, solid_capstyle="butt")

    def bar(d, half=0.95):
        c = p + u * d
        ax.plot(*zip(c - perp * half, c + perp * half), **kw)

    def circle(d):
        ax.add_patch(mpatches.Circle(p + u * d, 0.55, fc="white", ec=C_LINE, lw=1.1, zorder=2.6))

    def crow():
        base = p + u * 1.7
        for s in (-1.05, 0, 1.05):
            ax.plot(*zip(base, p + perp * s), **kw)

    if kind == "one":
        bar(1.0); bar(1.7)
    elif kind == "zero_one":
        bar(1.0); circle(2.3)
    elif kind == "many":
        crow(); bar(2.3)
    elif kind == "zero_many":
        crow(); circle(2.6)


def link(ax, a, a_side, a_frac, a_card, b, b_side, b_frac, b_card, label=None, label_pos=0.5,
         label_off=(0, 0)):
    """Kutu a ile kutu b arasında düz çizgi ve iki uçta kardinalite işaretleri."""
    p1, n1 = a.anchor(a_side, a_frac)
    p2, n2 = b.anchor(b_side, b_frac)
    # Çizgi kutudan dik çıkar, sonra düz devam eder
    q1, q2 = p1 + n1 * 3.0, p2 + n2 * 3.0
    ax.plot(*zip(p1, q1, q2, p2), color=C_LINE, lw=1.1, zorder=2, solid_joinstyle="round")
    _marker(ax, p1, n1, a_card)
    _marker(ax, p2, n2, b_card)
    if label:
        m = q1 + (q2 - q1) * label_pos + np.array(label_off)
        ax.text(*m, label, ha="center", va="center", fontsize=7, style="italic", color=C_MUTED, zorder=6,
                bbox=dict(fc="white", ec="none", pad=0.6))


def new_canvas(w=200, h=125, figw=16):
    fig, ax = plt.subplots(figsize=(figw, figw * h / w))
    ax.set_xlim(0, w); ax.set_ylim(0, h); ax.set_aspect("equal"); ax.axis("off")
    fig.subplots_adjust(0, 0, 1, 1)
    return fig, ax


def lk(ax, x, top, title, pk, extra=("Name",), w=30):
    attrs = [("PK", pk)] + [("FK" if e.endswith("ID") else "", e) for e in extra]
    return Box(ax, x, top, w, title, attrs, "lookup")


def legend(ax, x, y):
    ax.text(x, y + 1, "Notasyon (Crow's Foot)", fontsize=9, fontweight="bold", color=C_INK)
    items = [("one", "tam olarak bir (1)"), ("zero_one", "sıfır ya da bir (0..1)"),
             ("many", "bir ya da çok (1..N)"), ("zero_many", "sıfır ya da çok (0..N)")]
    for i, (k, t) in enumerate(items):
        yy = y - 3.2 - i * 3.2
        p = np.array([x + 9.0, yy])
        ax.plot([x, x + 9.0], [yy, yy], color=C_LINE, lw=1.1)
        _marker(ax, p, np.array([-1.0, 0]), k)
        ax.text(x + 11, yy, t, va="center", fontsize=8, color=C_INK)
    x2 = x + 44
    ax.text(x2, y + 1, "Varlık türleri", fontsize=9, fontweight="bold", color=C_INK)
    for i, (c, t) in enumerate([(C_CORE, "Ana varlık (kişi ve anket verisi)"),
                                (C_LOOKUP, "Lookup / referans varlık"),
                                (C_ML, "ML varlıkları (Adım 10'da kullanılacak)")]):
        yy = y - 3.2 - i * 3.2
        ax.add_patch(mpatches.FancyBboxPatch((x2, yy - 0.9), 4, 1.8, boxstyle="round,pad=0,rounding_size=0.3",
                                             fc=c, ec=c))
        ax.text(x2 + 6, yy, t, va="center", fontsize=8, color=C_INK)
    ax.text(x2, y - 3.2 - 3 * 3.2, "PK = birincil anahtar,  FK = yabancı anahtar,  UQ = benzersiz",
            va="center", fontsize=8, color=C_MUTED)


def diagram_overview(path):
    fig, ax = new_canvas()
    pred = Box(ax, 4, 120, 36, "PREDICTION", [("PK", "PredictionID"), ("FK", "ModelID"), ("FK", "RecordID"),
               ("", "PredictedProbability"), ("", "PredictedLabel"), ("", "PredictedAt")], "ml")
    model = Box(ax, 4, 92, 36, "ML_MODEL", [("PK", "ModelID"), ("", "ModelName"), ("", "Algorithm"),
                ("", "Hyperparameters"), ("", "TrainedAt")], "ml")
    metric = Box(ax, 4, 63, 36, "MODEL_METRIC", [("PK", "MetricID"), ("FK", "ModelID"), ("", "DataSplit"),
                 ("", "MetricName"), ("", "MetricValue")], "ml")
    survey = Box(ax, 52, 120, 36, "SURVEY_RECORD", [("PK", "RecordID"), ("FK,UQ", "PersonID"),
                 ("", "SurveyYear"), ("", "DataSplit"), ("", "InstanceWeight"), ("", "IncomeOver50K")])
    fin = Box(ax, 52, 60, 36, "FINANCE", [("PK,FK", "PersonID"), ("FK", "TaxFilerStatusID"),
              ("", "WagePerHour"), ("", "CapitalGains"), ("", "CapitalLosses"), ("", "DividendsFromStocks")])
    person = Box(ax, 100, 104, 40, "PERSON", [
        ("PK", "PersonID"), ("", "Age"), ("FK", "SexID"), ("FK", "RaceID"), ("FK", "HispanicOriginID"),
        ("FK", "MaritalStatusID"), ("FK", "EducationID"), ("FK", "EduEnrollmentID"), ("FK", "CitizenshipID"),
        ("FK", "BirthCountryID"), ("FK", "FatherBirthCountryID"), ("FK", "MotherBirthCountryID"),
        ("FK", "VetQuestionnaireAnswerID"), ("", "VeteransBenefits")])
    emp = Box(ax, 156, 123, 42, "EMPLOYMENT", [
        ("PK,FK", "PersonID"), ("FK", "ClassOfWorkerID"), ("FK", "IndustryCode"), ("FK", "OccupationCode"),
        ("FK", "EmploymentStatusID"), ("FK", "UnemploymentReasonID"), ("FK", "LaborUnionAnswerID"),
        ("", "WeeksWorkedInYear"), ("", "NumPersonsWorkedForEmp"), ("", "OwnBusinessSelfEmployed")])
    hh = Box(ax, 156, 89, 42, "HOUSEHOLD", [("PK,FK", "PersonID"), ("FK", "HouseholdDetailID"),
             ("FK", "HouseholdSummaryID"), ("FK", "FamilyUnder18ID")])
    res = Box(ax, 156, 70, 42, "RESIDENCE", [("PK,FK", "PersonID"), ("FK", "LivedInHouseAnswerID"),
              ("FK", "PrevRegionID"), ("FK", "PrevStateID")])
    mig = Box(ax, 156, 51, 42, "MIGRATION", [("PK,FK", "PersonID"), ("FK", "MsaChangeID"),
              ("FK", "RegionChangeID"), ("FK", "SunbeltAnswerID"), ("FK", "WithinRegionMoveID")])

    link(ax, person, "l", 0.12, "one", survey, "r", 0.5, "one", "katılır  (1:1)")
    link(ax, person, "l", 0.85, "one", fin, "r", 0.35, "one", "finansal bilgisi  (1:1)")
    link(ax, person, "r", 0.10, "one", emp, "l", 0.35, "one", "çalışma bilgisi (1:1)", 0.5, (0, 1.6))
    link(ax, person, "r", 0.40, "one", hh, "l", 0.5, "one", "hane (1:1)", 0.5, (0, 1.4))
    link(ax, person, "r", 0.70, "one", res, "l", 0.5, "one", "ikamet (1:1)", 0.5, (0, 1.4))
    link(ax, person, "r", 0.95, "one", mig, "l", 0.45, "zero_one", "göç (1:0..1)", 0.62, (0, 1.4))
    link(ax, survey, "l", 0.55, "one", pred, "r", 0.55, "zero_many", "tahmin edilir (1:N)", 0.5, (0, 1.6))
    link(ax, model, "t", 0.5, "one", pred, "b", 0.5, "zero_many", "üretir (1:N)")
    link(ax, model, "b", 0.5, "one", metric, "t", 0.5, "zero_many", "ölçülür (1:N)")
    legend(ax, 50, 26)
    ax.text(156, 24, "Lookup varlıkları ve FK ilişkileri\nŞekil 2–4'te gösterilmiştir.",
            fontsize=8.5, color=C_MUTED, va="top")
    fig.savefig(path, dpi=220); plt.close(fig)


def diagram_person(path):
    fig, ax = new_canvas(200, 118)
    person = Box(ax, 80, 92, 42, "PERSON", [
        ("PK", "PersonID"), ("", "Age"), ("FK", "SexID"), ("FK", "RaceID"), ("FK", "HispanicOriginID"),
        ("FK", "MaritalStatusID"), ("FK", "EducationID"), ("FK", "EduEnrollmentID"), ("FK", "CitizenshipID"),
        ("FK", "BirthCountryID"), ("FK", "FatherBirthCountryID"), ("FK", "MotherBirthCountryID"),
        ("FK", "VetQuestionnaireAnswerID"), ("", "VeteransBenefits")])
    sex = lk(ax, 8, 112, "SEX", "SexID", ("SexName",))
    race = lk(ax, 8, 92, "RACE", "RaceID", ("RaceName",))
    his = lk(ax, 8, 72, "HISPANIC_ORIGIN", "HispanicOriginID", ("OriginName",))
    mar = lk(ax, 8, 52, "MARITAL_STATUS", "MaritalStatusID", ("StatusName",))
    cit = lk(ax, 8, 32, "CITIZENSHIP", "CitizenshipID", ("CitizenshipName",))
    edu = lk(ax, 160, 112, "EDUCATION", "EducationID", ("EducationName", "EducationLevel"), 34)
    enr = lk(ax, 160, 89, "EDU_ENROLLMENT", "EduEnrollmentID", ("EnrollmentName",), 34)
    cty = lk(ax, 160, 62, "COUNTRY", "CountryID", ("CountryName",), 34)
    ans = lk(ax, 160, 30, "ANSWER", "AnswerID", ("AnswerText",), 34)

    def frac(i):  # PERSON'daki i. özniteliğin dikey konumu
        return (HEAD_H + ROW_H * (i + 0.5)) / person.h

    link(ax, sex, "r", 0.6, "one", person, "l", frac(2), "zero_many")
    link(ax, race, "r", 0.6, "one", person, "l", frac(3), "zero_many")
    link(ax, his, "r", 0.6, "one", person, "l", frac(4), "zero_many")
    link(ax, mar, "r", 0.6, "one", person, "l", frac(5), "zero_many")
    link(ax, cit, "r", 0.6, "one", person, "l", frac(8), "zero_many")
    link(ax, edu, "l", 0.6, "one", person, "r", frac(6), "zero_many")
    link(ax, enr, "l", 0.6, "one", person, "r", frac(7), "zero_many")
    link(ax, cty, "l", 0.30, "zero_one", person, "r", frac(9), "zero_many", "doğum yeri", 0.5)
    link(ax, cty, "l", 0.60, "zero_one", person, "r", frac(10), "zero_many", "babanın doğum yeri", 0.5)
    link(ax, cty, "l", 0.90, "zero_one", person, "r", frac(11), "zero_many", "annenin doğum yeri", 0.5)
    link(ax, ans, "l", 0.6, "one", person, "r", frac(12), "zero_many", "gaziler anketi", 0.4, (0, -1.3))
    ax.text(100, 6, "COUNTRY tek tablo, PERSON'a 3 farklı rolle (kendi / baba / anne) bağlanır.  "
            "Ülke bilgisi eksik (?) olabildiği için COUNTRY tarafı 0..1'dir.",
            ha="center", fontsize=8.5, color=C_MUTED)
    fig.savefig(path, dpi=220); plt.close(fig)


def diagram_employment(path):
    fig, ax = new_canvas(200, 118)
    emp = Box(ax, 72, 108, 44, "EMPLOYMENT", [
        ("PK,FK", "PersonID"), ("FK", "ClassOfWorkerID"), ("FK", "IndustryCode"), ("FK", "OccupationCode"),
        ("FK", "EmploymentStatusID"), ("FK", "UnemploymentReasonID"), ("FK", "LaborUnionAnswerID"),
        ("", "WeeksWorkedInYear"), ("", "NumPersonsWorkedForEmp"), ("", "OwnBusinessSelfEmployed")])
    cow = lk(ax, 6, 114, "CLASS_OF_WORKER", "ClassOfWorkerID", ("ClassName",), 34)
    est = lk(ax, 6, 98, "EMPLOYMENT_STATUS", "EmploymentStatusID", ("StatusName",), 34)
    unr = lk(ax, 6, 82, "UNEMPLOYMENT_REASON", "UnemploymentReasonID", ("ReasonName",), 34)
    ans = lk(ax, 6, 66, "ANSWER", "AnswerID", ("AnswerText",), 34)
    ind = lk(ax, 128, 114, "INDUSTRY", "IndustryCode", ("MajorIndustryID",), 32)
    mind = lk(ax, 168, 114, "MAJOR_INDUSTRY", "MajorIndustryID", ("IndustryName",), 30)
    occ = lk(ax, 128, 88, "OCCUPATION", "OccupationCode", ("MajorOccupationID",), 32)
    mocc = lk(ax, 168, 88, "MAJOR_OCCUPATION", "MajorOccupationID", ("OccupationName",), 30)

    def frac(i):
        return (HEAD_H + ROW_H * (i + 0.5)) / emp.h

    link(ax, cow, "r", 0.6, "one", emp, "l", frac(1), "zero_many")
    link(ax, est, "r", 0.6, "one", emp, "l", frac(4), "zero_many")
    link(ax, unr, "r", 0.6, "one", emp, "l", frac(5), "zero_many")
    link(ax, ans, "r", 0.6, "one", emp, "l", frac(6), "zero_many", "sendika üyeliği", 0.5, (0, 1.3))
    link(ax, ind, "l", 0.6, "one", emp, "r", frac(2), "zero_many")
    link(ax, occ, "l", 0.6, "one", emp, "r", frac(3), "zero_many")
    link(ax, mind, "l", 0.6, "one", ind, "r", 0.6, "many")
    link(ax, mocc, "l", 0.6, "one", occ, "r", 0.6, "many")
    ax.text(148, 70, "detailed → major hiyerarşisi:\nIndustryCode ve OccupationCode bilindiğinde\n"
            "üst grup kesin olarak bilinir (fonksiyonel\nbağımlılık), bu yüzden ayrı tabloya taşındı.",
            fontsize=8.3, color=C_MUTED, va="top")

    fin = Box(ax, 72, 46, 44, "FINANCE", [("PK,FK", "PersonID"), ("FK", "TaxFilerStatusID"),
              ("", "WagePerHour"), ("", "CapitalGains"), ("", "CapitalLosses"), ("", "DividendsFromStocks")])
    tax = lk(ax, 6, 40, "TAX_FILER_STATUS", "TaxFilerStatusID", ("StatusName",), 34)
    link(ax, tax, "r", 0.6, "one", fin, "l", (HEAD_H + ROW_H * 1.5) / fin.h, "zero_many")
    fig.savefig(path, dpi=220); plt.close(fig)


def diagram_household(path):
    fig, ax = new_canvas(200, 118)
    hh = Box(ax, 78, 112, 44, "HOUSEHOLD", [("PK,FK", "PersonID"), ("FK", "HouseholdDetailID"),
             ("FK", "HouseholdSummaryID"), ("FK", "FamilyUnder18ID")])
    res = Box(ax, 78, 80, 44, "RESIDENCE", [("PK,FK", "PersonID"), ("FK", "LivedInHouseAnswerID"),
              ("FK", "PrevRegionID"), ("FK", "PrevStateID")])
    mig = Box(ax, 78, 48, 44, "MIGRATION", [("PK,FK", "PersonID"), ("FK", "MsaChangeID"),
              ("FK", "RegionChangeID"), ("FK", "SunbeltAnswerID"), ("FK", "WithinRegionMoveID")])
    hd = lk(ax, 8, 116, "HOUSEHOLD_DETAIL", "HouseholdDetailID", ("DetailName",), 34)
    hs = lk(ax, 8, 102, "HOUSEHOLD_SUMMARY", "HouseholdSummaryID", ("SummaryName",), 34)
    fam = lk(ax, 158, 112, "FAMILY_UNDER_18", "FamilyUnder18ID", ("ParentsPresent",), 34)
    reg = lk(ax, 8, 84, "REGION", "RegionID", ("RegionName",), 34)
    st = lk(ax, 8, 70, "STATE", "StateID", ("StateName",), 34)
    ans = lk(ax, 158, 70, "ANSWER", "AnswerID", ("AnswerText",), 34)
    msa = lk(ax, 8, 50, "MSA_CHANGE", "MsaChangeID", ("ChangeName",), 34)
    rch = lk(ax, 8, 36, "REGION_CHANGE", "RegionChangeID", ("ChangeName",), 34)
    wrm = lk(ax, 158, 38, "WITHIN_REGION_MOVE", "WithinRegionMoveID", ("MoveName",), 34)

    def fr(box, i):
        return (HEAD_H + ROW_H * (i + 0.5)) / box.h

    link(ax, hd, "r", 0.6, "one", hh, "l", fr(hh, 1), "zero_many")
    link(ax, hs, "r", 0.6, "one", hh, "l", fr(hh, 2), "zero_many")
    link(ax, fam, "l", 0.6, "one", hh, "r", fr(hh, 3), "zero_many")
    link(ax, reg, "r", 0.6, "one", res, "l", fr(res, 2), "zero_many")
    link(ax, st, "r", 0.6, "zero_one", res, "l", fr(res, 3), "zero_many")
    link(ax, ans, "l", 0.45, "one", res, "r", fr(res, 1), "zero_many", "1 yıl önce aynı evde mi", 0.5, (0, 1.4))
    link(ax, ans, "l", 0.85, "one", mig, "r", fr(mig, 3), "zero_many", "sunbelt'ten mi", 0.5, (0, 0))
    link(ax, msa, "r", 0.6, "one", mig, "l", fr(mig, 1), "zero_many")
    link(ax, rch, "r", 0.6, "one", mig, "l", fr(mig, 2), "zero_many")
    link(ax, wrm, "l", 0.6, "one", mig, "r", fr(mig, 4), "zero_many")
    ax.text(100, 18, "MIGRATION kaydı yalnızca 1994 anketinde vardır (1995'te bu sorular sorulmamış);\n"
            "bu yüzden PERSON – MIGRATION ilişkisi 1:0..1'dir ve 1995 kişileri için hiç satır tutulmaz.\n"
            "PrevStateID boş (NULL) olabildiğinden STATE tarafı 0..1'dir.",
            ha="center", fontsize=8.5, color=C_MUTED, va="top")
    fig.savefig(path, dpi=220); plt.close(fig)


# --------------------------------------------------------------------------- #
# 3) PDF
# --------------------------------------------------------------------------- #
def register_fonts():
    fdir = Path(matplotlib.get_data_path()) / "fonts" / "ttf"
    pdfmetrics.registerFont(TTFont("DejaVu", str(fdir / "DejaVuSans.ttf")))
    pdfmetrics.registerFont(TTFont("DejaVu-Bold", str(fdir / "DejaVuSans-Bold.ttf")))
    pdfmetrics.registerFont(TTFont("DejaVu-Oblique", str(fdir / "DejaVuSans-Oblique.ttf")))
    pdfmetrics.registerFontFamily("DejaVu", normal="DejaVu", bold="DejaVu-Bold", italic="DejaVu-Oblique",
                                  boldItalic="DejaVu-Bold")


def styles():
    ss = getSampleStyleSheet()
    base = dict(fontName="DejaVu", textColor=colors.HexColor(C_INK))
    return {
        "title": ParagraphStyle("t", fontSize=22, leading=28, alignment=TA_CENTER, **{**base, "fontName": "DejaVu-Bold"}),
        "sub": ParagraphStyle("s", fontSize=12, leading=17, alignment=TA_CENTER,
                              **{**base, "textColor": colors.HexColor(C_MUTED)}),
        "h1": ParagraphStyle("h1", fontSize=15, leading=20, spaceBefore=10, spaceAfter=6,
                             **{**base, "fontName": "DejaVu-Bold", "textColor": colors.HexColor("#1d4f91")}),
        "h2": ParagraphStyle("h2", fontSize=11.5, leading=15, spaceBefore=8, spaceAfter=4,
                             **{**base, "fontName": "DejaVu-Bold"}),
        "body": ParagraphStyle("b", fontSize=9.5, leading=13.5, spaceAfter=5, **base),
        "bullet": ParagraphStyle("bl", fontSize=9.5, leading=13.5, leftIndent=14, bulletIndent=4,
                                 spaceAfter=2, **base),
        "cell": ParagraphStyle("c", fontSize=8, leading=10, **base),
        "cellb": ParagraphStyle("cb", fontSize=8, leading=10, **{**base, "fontName": "DejaVu-Bold",
                                                                    "textColor": colors.white}),
        "caption": ParagraphStyle("cap", fontSize=8.5, leading=11, alignment=TA_CENTER,
                                  **{**base, "textColor": colors.HexColor(C_MUTED)}),
        "note": ParagraphStyle("n", fontSize=9, leading=12.5, leftIndent=8, borderPadding=6,
                               backColor=colors.HexColor("#f1f5fb"), borderColor=colors.HexColor("#c9dcf3"),
                               borderWidth=0.6, spaceBefore=4, spaceAfter=8, **base),
    }


def table(rows, widths, st, header_color="#1d4f91"):
    data = [[Paragraph(escape(str(c)) if not str(c).startswith("<") else str(c),
                       st["cellb"] if i == 0 else st["cell"]) for c in r] for i, r in enumerate(rows)]
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(header_color)),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f5f6f8")]),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#d5d7db")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    return t


def build_pdf(S, imgs):
    register_fonts()
    st = styles()
    P = lambda t, s="body": Paragraph(t, st[s])
    B = lambda t: Paragraph(t, st["bullet"], bulletText="•")
    fmt = lambda n: f"{n:,}".replace(",", ".")
    nu = S["nuniq"]

    def on_page(canv, doc):
        canv.saveState()
        canv.setFont("DejaVu", 7.5); canv.setFillColor(colors.HexColor(C_MUTED))
        w, h = canv._pagesize
        canv.drawString(1.8 * cm, 1.0 * cm, "Census-Income Veri Tabanı Projesi – Adım 1: Kavramsal Tasarım (ER Modeli)")
        canv.drawRightString(w - 1.8 * cm, 1.0 * cm, f"Sayfa {doc.page}")
        canv.restoreState()

    doc = BaseDocTemplate(str(PDF_PATH), pagesize=A4, title="Adım 1 – Kavramsal Tasarım (ER Modeli)",
                          author="Veri Tabanı Yönetim Sistemleri Proje Ekibi",
                          leftMargin=1.8 * cm, rightMargin=1.8 * cm, topMargin=1.6 * cm, bottomMargin=1.6 * cm)
    pw, ph = A4
    lw, lh = landscape(A4)
    doc.addPageTemplates([
        PageTemplate("portrait", [Frame(1.8 * cm, 1.6 * cm, pw - 3.6 * cm, ph - 3.2 * cm, id="p")],
                     onPage=on_page, pagesize=A4),
        PageTemplate("landscape", [Frame(1.2 * cm, 1.5 * cm, lw - 2.4 * cm, lh - 2.6 * cm, id="l")],
                     onPage=on_page, pagesize=landscape(A4)),
    ])
    FW = pw - 3.6 * cm
    s = []

    # ---- Kapak
    s += [Spacer(1, 5 * cm), P("Gelir Analizi ve Tahmin Yönetim Sistemi", "title"), Spacer(1, 0.4 * cm),
          P("Adım 1 – Kavramsal Tasarım: Varlık-İlişki (ER) Modeli", "sub"), Spacer(1, 0.3 * cm),
          P("Veri Tabanı Yönetim Sistemleri Dersi Projesi", "sub"), Spacer(1, 0.3 * cm),
          P(f"Veri seti: Census-Income (KDD), UCI  ·  {dt.date.today():%d.%m.%Y}", "sub"),
          Spacer(1, 3 * cm)]
    summary = [["Özet", "Değer"],
               ["Ham veri", "1 düz tablo, 42 sütun"],
               ["Kişi sayısı (tekrarsız)", f"{fmt(S['n'])}  (train {fmt(S['n_train'])} + test {fmt(S['n_test'])})"],
               ["Ana varlık sayısı", "7  (PERSON, SURVEY_RECORD, EMPLOYMENT, FINANCE, HOUSEHOLD, RESIDENCE, MIGRATION)"],
               ["Lookup (referans) varlık sayısı", "25"],
               ["ML varlık sayısı (Adım 10)", "3  (ML_MODEL, MODEL_METRIC, PREDICTION)"],
               ["Notasyon", "Crow's Foot (Information Engineering)"]]
    s += [table(summary, [5.5 * cm, FW - 5.5 * cm], st), PageBreak()]

    # ---- 1. Amaç
    s += [P("1. Amaç ve Kapsam", "h1"),
          P("Bu raporun konusu, projenin ilk adımı olan <b>kavramsal tasarımdır</b>. Census-Income (KDD) "
            "veri seti 42 sütunluk tek bir düz tablo olarak gelmektedir. Bu adımda veri seti incelenerek "
            "<b>varlıklar (entity)</b>, <b>öznitelikler (attribute)</b>, <b>ilişkiler (relationship)</b> ve "
            "<b>kardinaliteler</b> belirlenmiş ve ER diyagramları çizilmiştir."),
          P("Tasarım herhangi bir VTYS'den bağımsızdır. MSSQL'e özgü veri tipleri, indeksler ve kısıtlar "
            "Adım 3'te (fiziksel tasarım) ele alınacaktır. Tablo ve sütun adları, SQL Server'daki "
            "uygulamayla uyumlu olsun diye İngilizce verilmiştir."),
          P("Kapsam:", "h2"),
          B("Ham veri setinin yapısal sorunlarının tespiti (Bölüm 2)"),
          B("Tasarım kararları ve gerekçeleri (Bölüm 3)"),
          B("Varlık listesi ve ilişki/kardinalite tablosu (Bölüm 4–5)"),
          B("ER diyagramları (Bölüm 6)"),
          B("Ham sütunlardan varlık özniteliklerine eşleme, yani veri sözlüğü (Bölüm 7)"),
          B("Fonksiyonel bağımlılık kontrolleri (Bölüm 8) ile değerlendirme ve sonraki adımlar (Bölüm 9)")]

    # ---- 2. Ham veri sorunları
    niu_pct = 100 * S["niu_cells"] / S["text_cells"]
    mig_null = S["null_pct"]["migration_code_change_in_msa"]
    s += [P("2. Ham Veri Setinin Yapısı ve Sorunları", "h1"),
          P("Veri setindeki her satır, 1994 veya 1995 Nüfus Anketi'ne (Current Population Survey) katılmış "
            "bir kişiyi temsil eder. Ön analizde birebir aynı satırlar silinmiştir. Geriye kalan "
            f"<b>{fmt(S['n'])}</b> satırın her biri bir kişi olarak kabul edilmiştir. Düz tabloda şu "
            "sorunlar vardır:"),
          B(f"<b>Tekrar eden metinler:</b> Metin hücrelerinin %{niu_pct:.0f}'ı yalnızca \"Not in universe\" "
            "ifadesidir. Eğitim, meslek ve ülke gibi uzun metinler yüz binlerce kez tekrarlanmaktadır. "
            "Bu durum hem yer israfına hem de güncelleme anomalilerine yol açar."),
          B(f"<b>Hiyerarşik kodlar:</b> <i>detailed_industry_recode</i> ({nu['detailed_industry_recode']} değer), "
            f"<i>major_industry_code</i> ({nu['major_industry_code']} değer) bilgisini kesin olarak belirler. "
            "Aynı durum meslek kodları için de geçerlidir. Aynı bilgi iki kez tutulmaktadır (geçişli bağımlılık)."),
          B("<b>Tekrar eden sütun grubu:</b> <i>country_of_birth_self / father / mother</i> aynı değer "
            f"kümesini ({S['n_country']} ülke) kullanan üç ayrı sütundur."),
          B(f"<b>Yapısal eksiklik:</b> <i>migration_*</i> sütunları kayıtların %{mig_null:.1f}'inde boştur. "
            "Bu kayıtların tamamı 1995 anketine aittir; o yıl bu sorular hiç sorulmamıştır."),
          B("<b>Farklı konuların karışması:</b> Kişisel bilgiler, iş, gelir, hane, ikamet ve anket "
            "metaverisi (örnekleme ağırlığı, yıl) aynı satırda tutulmaktadır.")]

    # ---- 3. Tasarım kararları
    s += [P("3. Tasarım Yaklaşımı ve Kararlar", "h1"),
          P("3.1 Konu bazlı ayrıştırma (1:1 varlıklar)", "h2"),
          P("42 sütun anlam bütünlüğüne göre gruplanmıştır. Merkezde <b>PERSON</b> varlığı bulunur. Diğer "
            "konular PERSON ile 1:1 ilişkili ayrı varlıklara ayrılmıştır:"),
          table([["Varlık", "İçerik", "Neden ayrı?"],
                 ["PERSON", "Yaş, cinsiyet, ırk, eğitim, medeni durum, vatandaşlık, doğum ülkeleri", "Merkez varlık"],
                 ["SURVEY_RECORD", "Anket yılı, örnekleme ağırlığı, train/test ayrımı, hedef değişken",
                  "Anket metaverisi ve ML etiketi kişisel bilgiden ayrılır; tahminler bu kayda bağlanır"],
                 ["EMPLOYMENT", "Çalışan sınıfı, sektör, meslek, çalışma durumu, çalışılan hafta",
                  "İş bilgisi kendi içinde bir bütündür; çocuklarda çoğu alan \"Not in universe\""],
                 ["FINANCE", "Saatlik ücret, sermaye kazancı/kaybı, temettü, vergi durumu",
                  "Hassas veri; Adım 8'de ayrı yetkilendirme yapılabilir"],
                 ["HOUSEHOLD", "Hane içindeki konum, 18 yaş altı için ebeveyn durumu", "Hane bilgisi"],
                 ["RESIDENCE", "1 yıl önce aynı evde mi, önceki bölge/eyalet", "Her iki yılda da mevcut"],
                 ["MIGRATION", "MSA/bölge değişimi, bölge içi taşınma, sunbelt",
                  "Yalnızca 1994'te var: opsiyonel (0..1) ilişki ile NULL yığını önlenir"]],
                [3.0 * cm, 7.2 * cm, FW - 10.2 * cm], st),
          Spacer(1, 6),
          P("3.2 Lookup (referans) varlıklar", "h2"),
          P("Sınırlı sayıda değer alan tüm kategorik metin sütunları ayrı lookup varlıklarına taşınmıştır. "
            "Ana varlıklarda bu değerler yalnızca kısa bir yabancı anahtar ile tutulur. Böylece her metin "
            "<b>bir kez</b> saklanır. Bir değerin adı değiştiğinde tek bir satır güncellenir. Ayrıca yalnızca "
            "geçerli değerler girilebilir (referans bütünlüğü)."),
          P("3.3 Özel durumlar", "h2"),
          B("<b>Rol bazlı ilişki:</b> COUNTRY tek bir varlıktır. PERSON'a 3 farklı rolle bağlanır: "
            "<i>BirthCountryID</i>, <i>FatherBirthCountryID</i> ve <i>MotherBirthCountryID</i>."),
          B("<b>Paylaşılan cevap tablosu:</b> Evet/Hayır/\"Not in universe\" tipindeki 4 sütun tek bir "
            "<b>ANSWER</b> lookup'ını paylaşır: sendika üyeliği, gaziler anketi, 1 yıl önce aynı evde "
            "olma ve sunbelt."),
          B("<b>İki seviyeli hiyerarşi:</b> INDUSTRY → MAJOR_INDUSTRY ve OCCUPATION → MAJOR_OCCUPATION. "
            "Detay kodu, kaynak veride zaten sayısal olduğundan doğal anahtar (natural key) olarak kullanılır."),
          B("<b>Sıralı kategori:</b> EDUCATION varlığı, türetilmiş özellikler adımında tanımlanan "
            "0–16 arası <i>EducationLevel</i> özniteliğini taşır."),
          B("<b>Opsiyonel ilişki:</b> PERSON – MIGRATION ilişkisi 1:0..1'dir. 1995 kişileri için MIGRATION "
            "satırı oluşturulmaz."),
          B("<b>Türetilmiş öznitelikler saklanmaz:</b> <i>age_group</i>, <i>is_employed</i> ve benzeri "
            "9 türetilmiş özellik ER modelinde yer almaz. Bunlar Adım 6'da <i>vw_MLFeatures</i> görünümünde "
            "SQL ile hesaplanacaktır."),
          B("<b>Kodlu sayısal sütunlar:</b> <i>own_business_or_self_employed</i> ve <i>veterans_benefits</i> "
            "0/1/2 değerleri alır. Bu kodların anlamı veri seti açıklamasında belgelenmemiştir. Bu yüzden "
            "lookup yerine kısıtlı (0, 1, 2) sayısal öznitelik olarak tutulmuşlardır.")]

    # ---- 4. Varlık listesi
    ents = [["Varlık", "Tür", "Birincil anahtar", "Tahmini kayıt", "Açıklama"],
            ["PERSON", "Ana", "PersonID", fmt(S["n"]), "Ankete katılan kişi"],
            ["SURVEY_RECORD", "Ana", "RecordID", fmt(S["n"]), "Anket kaydı: yıl, ağırlık, train/test, hedef"],
            ["EMPLOYMENT", "Ana (1:1)", "PersonID", fmt(S["n"]), "Çalışma bilgileri"],
            ["FINANCE", "Ana (1:1)", "PersonID", fmt(S["n"]), "Gelir ve yatırım bilgileri"],
            ["HOUSEHOLD", "Ana (1:1)", "PersonID", fmt(S["n"]), "Hane bilgileri"],
            ["RESIDENCE", "Ana (1:1)", "PersonID", fmt(S["n"]), "Önceki ikamet bilgileri"],
            ["MIGRATION", "Ana (1:0..1)", "PersonID", fmt(S["n_1994"]), "Göç bilgileri (yalnızca 1994)"],
            ["ML_MODEL", "ML", "ModelID", "—", "Eğitilen model, algoritma, hiperparametreler"],
            ["MODEL_METRIC", "ML", "MetricID", "—", "Modelin train/test metrikleri (AUC, F1 …)"],
            ["PREDICTION", "ML", "PredictionID", "—", "Bir modelin bir kayıt için tahmini"]]
    lookups = [("SEX", "sex"), ("RACE", "race"), ("HISPANIC_ORIGIN", "hispanic_origin"),
               ("MARITAL_STATUS", "marital_stat"), ("EDUCATION", "education"),
               ("EDU_ENROLLMENT", "enroll_in_edu_inst_last_wk"), ("CITIZENSHIP", "citizenship"),
               ("COUNTRY", None), ("ANSWER", None), ("CLASS_OF_WORKER", "class_of_worker"),
               ("INDUSTRY", "detailed_industry_recode"), ("MAJOR_INDUSTRY", "major_industry_code"),
               ("OCCUPATION", "detailed_occupation_recode"), ("MAJOR_OCCUPATION", "major_occupation_code"),
               ("EMPLOYMENT_STATUS", "full_or_part_time_employment_stat"),
               ("UNEMPLOYMENT_REASON", "reason_for_unemployment"), ("TAX_FILER_STATUS", "tax_filer_stat"),
               ("HOUSEHOLD_DETAIL", "detailed_household_and_family_stat"),
               ("HOUSEHOLD_SUMMARY", "detailed_household_summary_in_household"),
               ("FAMILY_UNDER_18", "family_members_under_18"), ("REGION", "region_of_previous_residence"),
               ("STATE", "state_of_previous_residence"), ("MSA_CHANGE", "migration_code_change_in_msa"),
               ("REGION_CHANGE", "migration_code_change_in_reg"),
               ("WITHIN_REGION_MOVE", "migration_code_move_within_reg")]
    lk_rows = [["Lookup varlık", "Kayıt", "Kaynak sütun"]]
    for name, col in lookups:
        if name == "COUNTRY":
            lk_rows.append([name, S["n_country"], "country_of_birth_self / father / mother"])
        elif name == "ANSWER":
            lk_rows.append([name, 4, "member_of_labor_union, fill_inc_questionnaire_for_veterans_admin, "
                                     "live_in_this_house_1_year_ago, migration_prev_res_in_sunbelt"])
        else:
            lk_rows.append([name, nu[col], col])
    s += [PageBreak(), P("4. Varlıklar", "h1"),
          P("4.1 Ana ve ML varlıkları", "h2"),
          table(ents, [3.1 * cm, 2.4 * cm, 2.6 * cm, 2.2 * cm, FW - 10.3 * cm], st), Spacer(1, 6),
          P("ML varlıkları, projenin \"tahmin yönetimi\" kısmı için baştan modele dahil edilmiştir. "
            "Adım 10'da Python ile eğitilen modeller ve tahminleri bu varlıklara yazılacaktır."),
          P("4.2 Lookup varlıkları (25 adet)", "h2"),
          P("Her lookup varlığı en az bir <i>ID</i> (PK) ve bir <i>Name</i> özniteliğine sahiptir. "
            "Kayıt sayıları veri setindeki farklı değer sayısıdır."),
          table(lk_rows, [4.6 * cm, 1.4 * cm, FW - 6.0 * cm], st, header_color=C_LOOKUP)]

    # ---- 5. İlişkiler
    rels = [["Varlık A", "Varlık B", "İlişki", "Kardinalite", "Katılım", "Açıklama"],
            ["PERSON", "SURVEY_RECORD", "katılır", "1 : 1", "A zorunlu, B zorunlu", "Her kişinin tam bir anket kaydı vardır"],
            ["PERSON", "EMPLOYMENT", "çalışma bilgisi", "1 : 1", "zorunlu / zorunlu", "Çocuklar için değerler \"Not in universe\""],
            ["PERSON", "FINANCE", "finansal bilgisi", "1 : 1", "zorunlu / zorunlu", "Para değerleri 0 olabilir"],
            ["PERSON", "HOUSEHOLD", "hane bilgisi", "1 : 1", "zorunlu / zorunlu", ""],
            ["PERSON", "RESIDENCE", "ikamet bilgisi", "1 : 1", "zorunlu / zorunlu", ""],
            ["PERSON", "MIGRATION", "göç bilgisi", "1 : 0..1", "zorunlu / opsiyonel", "Yalnızca 1994 kayıtları"],
            ["COUNTRY", "PERSON", "doğum yeri (×3 rol)", "0..1 : N", "opsiyonel / opsiyonel", "Ülke bilinmeyebilir (?)"],
            ["EDUCATION, SEX, RACE, …", "PERSON", "sınıflandırır", "1 : N", "zorunlu / opsiyonel", "Demografik lookup'lar"],
            ["MAJOR_INDUSTRY", "INDUSTRY", "kapsar", "1 : 1..N", "zorunlu / zorunlu", "Her üst sektörün en az bir alt kodu var"],
            ["INDUSTRY", "EMPLOYMENT", "sektörü", "1 : N", "zorunlu / opsiyonel", "Kod 0 = Not in universe"],
            ["MAJOR_OCCUPATION", "OCCUPATION", "kapsar", "1 : 1..N", "zorunlu / zorunlu", ""],
            ["OCCUPATION", "EMPLOYMENT", "mesleği", "1 : N", "zorunlu / opsiyonel", ""],
            ["TAX_FILER_STATUS", "FINANCE", "sınıflandırır", "1 : N", "zorunlu / opsiyonel", ""],
            ["STATE", "RESIDENCE", "önceki eyalet", "0..1 : N", "opsiyonel / opsiyonel", f"{fmt(S['state_null'])} kayıtta eyalet bilinmiyor"],
            ["ANSWER", "EMPLOYMENT, PERSON, RESIDENCE, MIGRATION", "cevap", "1 : N", "zorunlu / opsiyonel", "4 farklı rolde kullanılır"],
            ["SURVEY_RECORD", "PREDICTION", "tahmin edilir", "1 : N", "zorunlu / opsiyonel", "Bir kayda birden çok model tahmin üretebilir"],
            ["ML_MODEL", "PREDICTION", "üretir", "1 : N", "zorunlu / opsiyonel", "Model ve kayıt çifti benzersiz (UQ)"],
            ["ML_MODEL", "MODEL_METRIC", "ölçülür", "1 : N", "zorunlu / opsiyonel", ""]]
    s += [PageBreak(), P("5. İlişkiler ve Kardinaliteler", "h1"),
          P("Kardinalite, bir varlığın bir örneğinin diğer varlığın kaç örneğiyle ilişkili olabileceğini "
            "gösterir. Katılım (zorunlu/opsiyonel) ise ilişkinin her örnek için var olmak zorunda olup "
            "olmadığını belirtir. Tablodaki \"Katılım\" sütunu A / B sırasıyla okunur."),
          table(rels, [3.2 * cm, 3.2 * cm, 2.2 * cm, 1.8 * cm, 2.7 * cm, FW - 13.1 * cm], st),
          Spacer(1, 6),
          P("<b>Neden PERSON ile SURVEY_RECORD 1:1 olarak ayrı?</b> Veri setinde bir kişi yalnızca bir kez "
            "ankete katılır; kişiyi yıllar boyunca izleyen bir kimlik bulunmaz. Yine de bu ayrım iki fayda "
            "sağlar. Birincisi, örnekleme ağırlığı ve train/test ayrımı gibi <i>anketle ilgili</i> bilgiler "
            "kişisel özniteliklerden ayrılır. İkincisi, ML etiketi (<i>IncomeOver50K</i>) ve tahminler aynı "
            "kayda bağlanarak gerçek değer ile tahmin kolayca karşılaştırılabilir.", "note")]

    # ---- 6. Diyagramlar (yatay sayfalar)
    lw_img = lw - 2.4 * cm
    caps = ["Şekil 1 – Genel ER diyagramı: ana varlıklar, ML varlıkları ve aralarındaki ilişkiler",
            "Şekil 2 – PERSON ve demografik lookup varlıkları",
            "Şekil 3 – EMPLOYMENT ve FINANCE ile ilgili lookup varlıkları",
            "Şekil 4 – HOUSEHOLD, RESIDENCE ve MIGRATION ile ilgili lookup varlıkları"]
    ratios = [125 / 200, 118 / 200, 118 / 200, 118 / 200]
    s += [NextPageTemplate("landscape"), PageBreak()]
    for i, (img, cap, r) in enumerate(zip(imgs, caps, ratios)):
        h = min(lw_img * r, lh - 4.6 * cm)
        w = h / r
        block = ([P("6. ER Diyagramları", "h1")] if i == 0 else []) + \
                [Image(str(img), width=w, height=h), Spacer(1, 4), P(cap, "caption")]
        s += [KeepTogether(block)]
        if i < len(imgs) - 1:
            s.append(PageBreak())
    s += [NextPageTemplate("portrait"), PageBreak()]

    # ---- 7. Veri sözlüğü
    mapping = [
        ("age", "PERSON.Age", "sayısal"), ("class_of_worker", "EMPLOYMENT.ClassOfWorkerID → CLASS_OF_WORKER", "lookup"),
        ("detailed_industry_recode", "EMPLOYMENT.IndustryCode → INDUSTRY", "lookup (kod)"),
        ("detailed_occupation_recode", "EMPLOYMENT.OccupationCode → OCCUPATION", "lookup (kod)"),
        ("education", "PERSON.EducationID → EDUCATION", "lookup"),
        ("wage_per_hour", "FINANCE.WagePerHour", "sayısal"),
        ("enroll_in_edu_inst_last_wk", "PERSON.EduEnrollmentID → EDU_ENROLLMENT", "lookup"),
        ("marital_stat", "PERSON.MaritalStatusID → MARITAL_STATUS", "lookup"),
        ("major_industry_code", "INDUSTRY.MajorIndustryID → MAJOR_INDUSTRY", "türetilebilir"),
        ("major_occupation_code", "OCCUPATION.MajorOccupationID → MAJOR_OCCUPATION", "türetilebilir"),
        ("race", "PERSON.RaceID → RACE", "lookup"), ("hispanic_origin", "PERSON.HispanicOriginID → HISPANIC_ORIGIN", "lookup"),
        ("sex", "PERSON.SexID → SEX", "lookup"),
        ("member_of_labor_union", "EMPLOYMENT.LaborUnionAnswerID → ANSWER", "lookup (paylaşılan)"),
        ("reason_for_unemployment", "EMPLOYMENT.UnemploymentReasonID → UNEMPLOYMENT_REASON", "lookup"),
        ("full_or_part_time_employment_stat", "EMPLOYMENT.EmploymentStatusID → EMPLOYMENT_STATUS", "lookup"),
        ("capital_gains", "FINANCE.CapitalGains", "sayısal"), ("capital_losses", "FINANCE.CapitalLosses", "sayısal"),
        ("dividends_from_stocks", "FINANCE.DividendsFromStocks", "sayısal"),
        ("tax_filer_stat", "FINANCE.TaxFilerStatusID → TAX_FILER_STATUS", "lookup"),
        ("region_of_previous_residence", "RESIDENCE.PrevRegionID → REGION", "lookup"),
        ("state_of_previous_residence", "RESIDENCE.PrevStateID → STATE", "lookup, NULL olabilir"),
        ("detailed_household_and_family_stat", "HOUSEHOLD.HouseholdDetailID → HOUSEHOLD_DETAIL", "lookup"),
        ("detailed_household_summary_in_household", "HOUSEHOLD.HouseholdSummaryID → HOUSEHOLD_SUMMARY", "lookup"),
        ("instance_weight", "SURVEY_RECORD.InstanceWeight", "sayısal (ML girdisi değil)"),
        ("migration_code_change_in_msa", "MIGRATION.MsaChangeID → MSA_CHANGE", "lookup, yalnızca 1994"),
        ("migration_code_change_in_reg", "MIGRATION.RegionChangeID → REGION_CHANGE", "lookup, yalnızca 1994"),
        ("migration_code_move_within_reg", "MIGRATION.WithinRegionMoveID → WITHIN_REGION_MOVE", "lookup, yalnızca 1994"),
        ("live_in_this_house_1_year_ago", "RESIDENCE.LivedInHouseAnswerID → ANSWER", "lookup (paylaşılan)"),
        ("migration_prev_res_in_sunbelt", "MIGRATION.SunbeltAnswerID → ANSWER", "lookup, yalnızca 1994"),
        ("num_persons_worked_for_employer", "EMPLOYMENT.NumPersonsWorkedForEmp", "sayısal (0–6)"),
        ("family_members_under_18", "HOUSEHOLD.FamilyUnder18ID → FAMILY_UNDER_18", "lookup"),
        ("country_of_birth_father", "PERSON.FatherBirthCountryID → COUNTRY", "lookup (rol), NULL olabilir"),
        ("country_of_birth_mother", "PERSON.MotherBirthCountryID → COUNTRY", "lookup (rol), NULL olabilir"),
        ("country_of_birth_self", "PERSON.BirthCountryID → COUNTRY", "lookup (rol), NULL olabilir"),
        ("citizenship", "PERSON.CitizenshipID → CITIZENSHIP", "lookup"),
        ("own_business_or_self_employed", "EMPLOYMENT.OwnBusinessSelfEmployed", "kod (0/1/2)"),
        ("fill_inc_questionnaire_for_veterans_admin", "PERSON.VetQuestionnaireAnswerID → ANSWER", "lookup (paylaşılan)"),
        ("veterans_benefits", "PERSON.VeteransBenefits", "kod (0/1/2)"),
        ("weeks_worked_in_year", "EMPLOYMENT.WeeksWorkedInYear", "sayısal (0–52)"),
        ("year", "SURVEY_RECORD.SurveyYear", "1994 / 1995"),
        ("income (hedef)", "SURVEY_RECORD.IncomeOver50K", "ikili (0/1)"),
        ("— (yeni)", "SURVEY_RECORD.DataSplit", "train / test (dosya kaynağı)"),
    ]
    dd = [["#", "Ham sütun", "Varlık.Öznitelik → Lookup", "Not"]] + \
         [[i + 1 if not m[0].startswith("—") else "", m[0], m[1], m[2]] for i, m in enumerate(mapping)]
    s += [P("7. Veri Sözlüğü: Ham Sütun → Varlık Eşlemesi", "h1"),
          P("Ham veri setindeki 42 sütunun her biri modelde tam olarak bir yerde karşılık bulur. Hiçbir bilgi "
            "kaybolmaz. Ok (→), özniteliğin hangi lookup varlığına yabancı anahtar olduğunu gösterir."),
          table(dd, [0.9 * cm, 5.6 * cm, 7.3 * cm, FW - 13.8 * cm], st)]

    # ---- 8. Fonksiyonel bağımlılıklar
    fi, fo, fs, fh = S["fd_industry"], S["fd_occupation"], S["fd_state"], S["fd_household"]
    fd_rows = [["Bağımlılık (A → B)", "İhlal eden A değeri", "Sonuç", "Modeldeki karşılığı"],
               ["detailed_industry_recode → major_industry_code", f"{fi[0]} / {fi[1]}", "Kesin bağımlılık",
                "INDUSTRY → MAJOR_INDUSTRY hiyerarşisi"],
               ["detailed_occupation_recode → major_occupation_code", f"{fo[0]} / {fo[1]}", "Kesin bağımlılık",
                "OCCUPATION → MAJOR_OCCUPATION hiyerarşisi"],
               ["state_of_previous_residence → region_of_previous_residence", f"{fs[0]} / {fs[1]}",
                "Neredeyse bağımlı", "Bağımsız iki FK (RESIDENCE.PrevRegionID, PrevStateID)"],
               ["detailed_household_and_family_stat → detailed_household_summary", f"{fh[0]} / {fh[1]}",
                "Neredeyse bağımlı", "Bağımsız iki FK (HOUSEHOLD)"]]
    s += [P("8. Fonksiyonel Bağımlılık Kontrolleri", "h1"),
          P("Hangi bilginin hangi varlıkta tutulacağına karar vermek için sütunlar arası fonksiyonel "
            "bağımlılıklar train ve test verisinin tamamında kontrol edilmiştir. A değeri her zaman tek bir "
            "B değerine karşılık geliyorsa A → B kesin bağımlılıktır."),
          table(fd_rows, [6.3 * cm, 2.4 * cm, 2.6 * cm, FW - 11.3 * cm], st), Spacer(1, 6),
          P("<b>Eyalet → bölge neden lookup hiyerarşisi yapılmadı?</b> Normalde bir eyalet tek bir bölgeye "
            f"aittir. Ancak veride <i>state = \"Abroad\"</i> olan {fmt(S['abroad_west'])} kayıtta bölge "
            f"\"West\" olarak girilmiştir. Ayrıca eyaleti bilinmeyen (?) {fmt(S['state_null'])} kaydın bölgesi "
            "bilinmektedir. STATE → REGION hiyerarşisi kurulursa bu kayıtların bölge bilgisi kaybolur ya da "
            "değişir. Bu yüzden iki bilgi RESIDENCE'ta ayrı FK olarak tutulmuştur. Bu veri tutarsızlığı "
            "raporlanmıştır.", "note"),
          P("<b>Hane detay → özet:</b> \"In group quarters\" detay değeri "
            f"{S['group_quarters']} farklı özet değeriyle eşleşmektedir. Bu nedenle özet bilgi detaydan "
            "türetilemez ve ayrı bir FK olarak tutulur.", "note"),
          P("Kalan bağımlılıklar ve 1NF/2NF/3NF/BCNF analizi Adım 2'de (Normalizasyon) ayrıntılı olarak "
            "ele alınacaktır.")]

    # ---- 9. Değerlendirme
    s += [P("9. Değerlendirme", "h1"),
          P("9.1 Güçlü yönler", "h2"),
          B("Her metin değeri bir kez saklanır. Lookup tabloları sayesinde geçersiz değer girilemez."),
          B("Yapısal eksiklik (1995 göç soruları) NULL sütunlarla değil, opsiyonel bir ilişkiyle modellenir."),
          B("Kaynak verideki hiçbir sütun kaybolmaz (Bölüm 7). Ham veri, view ile tekrar düz tablo olarak "
            "üretilebilir."),
          B("ML varlıkları sayesinde model, metrik ve tahminler aynı veritabanında izlenebilir."),
          P("9.2 Ödünleşimler (trade-off) ve alternatifler", "h2"),
          table([["Karar", "Alternatif", "Neden bu seçildi?"],
                 ["Konulara göre 1:1 varlıklar", "Tek geniş PERSON tablosu",
                  "Okunabilirlik, NULL azaltma ve ayrı yetkilendirme sağlar. Bedeli: düz görünüm için JOIN "
                  "gerekir; bu, bir view ile çözülecek"],
                 ["Paylaşılan ANSWER lookup", "Her sütun için ayrı Yes/No tablosu",
                  "Aynı değer kümesini tekrarlamamak için. Bedeli: \"Not in universe under 1 year old\" "
                  "değeri yalnızca bir sütunda kullanılır"],
                 ["SEX için lookup", "CHAR(1) + CHECK kısıtı",
                  "Diğer kategorik alanlarla tutarlılık için. İki değerli alanlarda CHECK de geçerli bir "
                  "seçenektir; Adım 3'te yeniden değerlendirilebilir"],
                 ["Detay kodlar doğal anahtar", "Yapay (surrogate) ID",
                  "Kaynak veride kod zaten sabit ve sayısal; ETL ve raporlama kolaylaşır"],
                 ["Türetilmiş özellikler view'da", "Tabloda saklamak",
                  "Saklanan türetilmiş veri tutarsızlığa yol açabilir; view her zaman güncel sonuç verir"]],
                [3.6 * cm, 3.8 * cm, FW - 7.4 * cm], st),
          P("9.3 Riskler ve dikkat edilecekler", "h2"),
          B("1:1 ilişkiler veritabanında <i>PersonID</i>'nin hem PK hem FK olmasıyla uygulanacaktır. Yeni "
            "kişi eklerken tüm ilgili satırların tek bir transaction içinde eklenmesi gerekir (Adım 6)."),
          B("\"Not in universe\" lookup'larda normal bir değer olarak kalır; SQL'deki <i>NULL</i> "
            "anlamıyla karıştırılmamalıdır."),
          B("<i>InstanceWeight</i> bir nüfus ağırlığıdır. Raporlarda ağırlıklı sonuç verilecekse kullanılmalı, "
            "ML'de ise öznitelik olarak kullanılmamalıdır."),
          P("9.4 Sonraki adım", "h2"),
          P("Adım 2'de (Normalizasyon) bu modelin 1NF, 2NF, 3NF ve BCNF koşullarını sağladığı fonksiyonel "
            "bağımlılıklarla gösterilecektir. Adım 3'te ise varlıklar MSSQL tablolarına (veri tipleri, PK/FK, "
            "CHECK, UNIQUE kısıtları) dönüştürülecektir.")]

    doc.build(s)


def main():
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    if not (PROCESSED / "train_clean.csv").exists():
        raise SystemExit("Temiz veri yok. Önce çalıştırın: python analysis/pre_analiz.py")
    print("İstatistikler hesaplanıyor...")
    S = load_stats()
    print("Diyagramlar çiziliyor...")
    imgs = [IMG_DIR / f for f in ["er_1_genel.png", "er_2_person.png", "er_3_employment_finance.png",
                                  "er_4_household_residence_migration.png"]]
    diagram_overview(imgs[0]); diagram_person(imgs[1]); diagram_employment(imgs[2]); diagram_household(imgs[3])
    print("PDF oluşturuluyor...")
    build_pdf(S, imgs)
    print(f"Bitti: {PDF_PATH}")


if __name__ == "__main__":
    main()
