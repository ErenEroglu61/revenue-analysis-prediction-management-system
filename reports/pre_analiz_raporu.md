# Ön Analiz Raporu – Census-Income (KDD)


_Bu dosya `analysis/pre_analiz.py` tarafından otomatik üretilmiştir._


## 1. Genel Bakış

| küme | satır | sütun |
|---|---|---|
| train (census-income.data) | 199,523 | 42 |
| test (census-income.test) | 99,762 | 42 |

- Sayısal (sürekli) sütun: **8** (`instance_weight` dahil)
- Sayı gibi görünen ama kategorik (kod) sütun: **5** → `detailed_industry_recode`, `detailed_occupation_recode`, `own_business_or_self_employed`, `veterans_benefits`, `year`
- Metin kategorik sütun: **28**
- Hedef: `income_over_50k` (0 = 50K altı, 1 = 50K üstü)
- `instance_weight` bir **örnekleme ağırlığıdır**; nüfus analizi için kullanılır ama **modele girdi olarak verilmemelidir** (veri seti açıklaması).


## 2. Hedef Değişken Dağılımı

| küme | 50K altı (0) | 50K üstü (1) | pozitif oran % | ağırlıklı pozitif oran % |
|---|---|---|---|---|
| train | 187,141 | 12,382 | 6.21 | 6.41 |
| test | 93,576 | 6,186 | 6.20 | 6.34 |

> **Sınıflar çok dengesiz.** Her kayda '50K altı' diyen bir model bile ~%94 doğruluk alır. Modellemede accuracy yerine **F1, Precision/Recall, ROC-AUC, PR-AUC** kullanılmalı; `class_weight='balanced'` veya yeniden örnekleme düşünülmeli.


## 3. Sütun Profili (train)

| sütun | tip | farklı değer | eksik (?) | eksik % | en sık değer | en sık % |
|---|---|---|---|---|---|---|
| age | sayısal | 91 | 0 | 0.00 | 34 | 1.75 |
| class_of_worker | kategorik | 9 | 0 | 0.00 | Not in universe | 50.24 |
| detailed_industry_recode | kod (kategorik) | 52 | 0 | 0.00 | 0 | 50.46 |
| detailed_occupation_recode | kod (kategorik) | 47 | 0 | 0.00 | 0 | 50.46 |
| education | kategorik | 17 | 0 | 0.00 | High school graduate | 24.26 |
| wage_per_hour | sayısal | 1,240 | 0 | 0.00 | 0 | 94.33 |
| enroll_in_edu_inst_last_wk | kategorik | 3 | 0 | 0.00 | Not in universe | 93.69 |
| marital_stat | kategorik | 7 | 0 | 0.00 | Never married | 43.35 |
| major_industry_code | kategorik | 24 | 0 | 0.00 | Not in universe or children | 50.46 |
| major_occupation_code | kategorik | 15 | 0 | 0.00 | Not in universe | 50.46 |
| race | kategorik | 5 | 0 | 0.00 | White | 83.88 |
| hispanic_origin | kategorik | 10 | 0 | 0.00 | All other | 86.16 |
| sex | kategorik | 2 | 0 | 0.00 | Female | 52.12 |
| member_of_labor_union | kategorik | 3 | 0 | 0.00 | Not in universe | 90.45 |
| reason_for_unemployment | kategorik | 6 | 0 | 0.00 | Not in universe | 96.96 |
| full_or_part_time_employment_stat | kategorik | 8 | 0 | 0.00 | Children or Armed Forces | 62.03 |
| capital_gains | sayısal | 132 | 0 | 0.00 | 0 | 96.30 |
| capital_losses | sayısal | 113 | 0 | 0.00 | 0 | 98.04 |
| dividends_from_stocks | sayısal | 1,478 | 0 | 0.00 | 0 | 89.40 |
| tax_filer_stat | kategorik | 6 | 0 | 0.00 | Nonfiler | 37.64 |
| region_of_previous_residence | kategorik | 6 | 0 | 0.00 | Not in universe | 92.09 |
| state_of_previous_residence | kategorik | 50 | 708 | 0.35 | Not in universe | 92.09 |
| detailed_household_and_family_stat | kategorik | 38 | 0 | 0.00 | Householder | 26.69 |
| detailed_household_summary_in_household | kategorik | 8 | 0 | 0.00 | Householder | 37.83 |
| instance_weight | sayısal | 99,800 | 0 | 0.00 | 753.23 | 0.02 |
| migration_code_change_in_msa | kategorik | 9 | 99,696 | 49.97 | Nonmover | 49.97 |
| migration_code_change_in_reg | kategorik | 8 | 99,696 | 49.97 | Nonmover | 49.97 |
| migration_code_move_within_reg | kategorik | 9 | 99,696 | 49.97 | Nonmover | 49.97 |
| live_in_this_house_1_year_ago | kategorik | 3 | 0 | 0.00 | Not in universe under 1 year old | 50.73 |
| migration_prev_res_in_sunbelt | kategorik | 3 | 99,696 | 49.97 | Not in universe | 49.97 |
| num_persons_worked_for_employer | sayısal | 7 | 0 | 0.00 | 0 | 48.11 |
| family_members_under_18 | kategorik | 5 | 0 | 0.00 | Not in universe | 72.29 |
| country_of_birth_father | kategorik | 42 | 6,713 | 3.36 | United-States | 79.77 |
| country_of_birth_mother | kategorik | 42 | 6,119 | 3.07 | United-States | 80.43 |
| country_of_birth_self | kategorik | 42 | 3,393 | 1.70 | United-States | 88.71 |
| citizenship | kategorik | 5 | 0 | 0.00 | Native- Born in the United States | 88.71 |
| own_business_or_self_employed | kod (kategorik) | 3 | 0 | 0.00 | 0 | 90.55 |
| fill_inc_questionnaire_for_veterans_admin | kategorik | 3 | 0 | 0.00 | Not in universe | 99.01 |
| veterans_benefits | kod (kategorik) | 3 | 0 | 0.00 | 2 | 75.24 |
| weeks_worked_in_year | sayısal | 53 | 0 | 0.00 | 0 | 48.11 |
| year | kod (kategorik) | 2 | 0 | 0.00 | 94 | 50.03 |
| income_over_50k | hedef | 2 | 0 | 0.00 | 0 | 93.79 |


## 4. Eksik Değerler

### 4.1 `?` ile işaretlenmiş eksik değerler

| sütun | train eksik | train % | test eksik | test % |
|---|---|---|---|---|
| migration_code_change_in_msa | 99,696 | 49.97 | 49,946 | 50.07 |
| migration_code_change_in_reg | 99,696 | 49.97 | 49,946 | 50.07 |
| migration_code_move_within_reg | 99,696 | 49.97 | 49,946 | 50.07 |
| migration_prev_res_in_sunbelt | 99,696 | 49.97 | 49,946 | 50.07 |
| country_of_birth_father | 6,713 | 3.36 | 3,429 | 3.44 |
| country_of_birth_mother | 6,119 | 3.07 | 3,072 | 3.08 |
| country_of_birth_self | 3,393 | 1.70 | 1,764 | 1.77 |
| state_of_previous_residence | 708 | 0.35 | 330 | 0.33 |

### 4.2 `migration_*` sütunlarının yıla göre eksiklik oranı (%)

| year | migration_code_change_in_msa | migration_code_change_in_reg | migration_code_move_within_reg | migration_prev_res_in_sunbelt |
|---|---|---|---|---|
| 94 | 0.00 | 0.00 | 0.00 | 0.00 |
| 95 | 100.00 | 100.00 | 100.00 | 100.00 |

> `migration_*` sütunları **1995 yılı kayıtlarında tamamen boş**, 1994'te ise hiç eksik yok. Yani bu bir rastgele eksiklik değil, 1995 anketinde bu sorular hiç sorulmamış. Bu sütunlar ya modelden çıkarılmalı ya da eksiklik ayrı bir kategori ('Unknown') olarak tutulmalı.


### 4.3 'Not in universe' oranları

'Not in universe' **eksik değer değildir**; sorunun o kişiye uygulanmadığını gösterir (ör. çocuklara meslek sorulmaz). Bu yüzden NULL'a çevrilmedi, ayrı bir kategori olarak bırakıldı.

| sütun | 'Not in universe' % |
|---|---|
| fill_inc_questionnaire_for_veterans_admin | 99.01 |
| reason_for_unemployment | 96.96 |
| enroll_in_edu_inst_last_wk | 93.69 |
| state_of_previous_residence | 92.09 |
| region_of_previous_residence | 92.09 |
| member_of_labor_union | 90.45 |
| family_members_under_18 | 72.29 |
| live_in_this_house_1_year_ago | 50.73 |
| major_industry_code | 50.46 |
| major_occupation_code | 50.46 |
| class_of_worker | 50.24 |
| migration_prev_res_in_sunbelt | 42.13 |
| migration_code_move_within_reg | 0.76 |
| migration_code_change_in_msa | 0.76 |
| migration_code_change_in_reg | 0.76 |


## 5. Tekrar Eden Satırlar

| küme | birebir aynı satır | ağırlık hariç aynı | öznitelikler aynı (hedef hariç) | çelişkili grup (aynı öznitelik, farklı hedef) |
|---|---|---|---|---|
| train | 3,229 | 46,627 | 46,716 | 89 |
| test | 883 | 20,898 | 20,936 | 38 |

**Karar:**
- **Birebir aynı** satırlar (ağırlık dahil her şey aynı) gerçek tekrar kabul edildi ve **silindi**: train 199,523 → 196,294, test 99,762 → 98,879.
- **Ağırlık hariç aynı** olan satırlar silinmedi: farklı `instance_weight` değerleri bunların ankette farklı kişiler olduğunu gösteriyor. Bunların çoğu çocuk ve çalışmayan kişiler; neredeyse tüm alanları 'Not in universe' / 0. Veritabanına hepsi kişi olarak girecek. Modelleme aşamasında ayrıca tekilleştirmek istenirse `drop_duplicates(subset=öznitelikler)` kullanılabilir.
- **Çelişkili** gruplar (aynı özellikler, farklı gelir sınıfı) veri setinin doğal gürültüsüdür; hiçbir model bunları %100 doğru ayıramaz.


**Train–test çakışması:** test kümesindeki 98,879 satırdan **25,996** tanesinin (26.3%) öznitelikleri train kümesinde birebir var. Bunlar çoğunlukla çocuk / çalışmayan kişilerin 'boş' profilleri olduğundan veri sızıntısı riski düşük, ama raporlarken bilinmesi iyi olur.


## 6. Tekrar Eden / Türetilebilir Sütunlar

### 6.1 Birebir aynı sütunlar

Yok – hiçbir sütun çifti birebir aynı değil.

### 6.2 Sabit (tek değerli) sütunlar

Yok.

### 6.3 Fonksiyonel bağımlılıklar (A → B)

A'nın değeri B'nin değerini kesin olarak belirliyorsa B, A'dan türetilebilir; yani aynı bilgi iki kez tutuluyor demektir. **Bu, normalizasyon (3NF) için doğrudan girdidir.**

| A (detaylı) | B (özet) | A farklı değer | B farklı değer |
|---|---|---|---|
| detailed_industry_recode | major_industry_code | 52 | 24 |
| detailed_occupation_recode | major_occupation_code | 47 | 15 |

### 6.4 Neredeyse bağımlı sütunlar

- `detailed_household_and_family_stat` (38 değer) → `detailed_household_summary_in_household` (8 değer): satırların **%99.97**'inde detay değer özet değeri belirliyor. Özet sütun büyük ölçüde detaydan türetilmiş.
- `country_of_birth_self` ile `citizenship` ilişkili ama bağımlı değil (yabancı doğumlu biri vatandaş olabilir de olmayabilir de).


**Karar:** Birebir aynı ya da sabit sütun olmadığından temiz dosyadan **hiçbir sütun silinmedi**. `major_industry_code` ve `major_occupation_code` detay kodlardan türetilebiliyor, ancak detay kodlar sadece sayı; okunabilir isimler özet sütunlarda. Bu yüzden bu sütunlar silinmeyip **veritabanı tasarımında ayrı lookup tablolarına taşınacak**:

```
Industry(detailed_industry_code PK, major_industry_id FK)  ->  MajorIndustry(id PK, name)
Occupation(detailed_occupation_code PK, major_occupation_id FK) -> MajorOccupation(id PK, name)
Person(..., detailed_industry_code FK, detailed_occupation_code FK, ...)
```
Böylece özet bilgi `Person` tablosunda tekrar tekrar tutulmaz (geçişli bağımlılık giderilir).


## 7. Sayısal Sütunlar (train)

| sütun | mean | std | min | 25% | 50% | 75% | max | sıfır % |
|---|---|---|---|---|---|---|---|---|
| age | 34.93 | 22.21 | 0.00 | 16.00 | 34.00 | 50.00 | 90.00 | 1.35 |
| wage_per_hour | 56.34 | 277.05 | 0.00 | 0.00 | 0.00 | 0.00 | 9,999.00 | 94.24 |
| capital_gains | 441.87 | 4,735.68 | 0.00 | 0.00 | 0.00 | 0.00 | 99,999.00 | 96.24 |
| capital_losses | 37.93 | 274.08 | 0.00 | 0.00 | 0.00 | 0.00 | 4,608.00 | 98.01 |
| dividends_from_stocks | 200.72 | 2,000.13 | 0.00 | 0.00 | 0.00 | 0.00 | 99,999.00 | 89.23 |
| instance_weight | 1,743.27 | 996.95 | 37.87 | 1,061.53 | 1,620.18 | 2,194.06 | 18,656.30 | 0.00 |
| num_persons_worked_for_employer | 1.99 | 2.37 | 0.00 | 0.00 | 1.00 | 4.00 | 6.00 | 47.26 |
| weeks_worked_in_year | 23.55 | 24.43 | 0.00 | 0.00 | 12.00 | 52.00 | 52.00 | 47.26 |

**Gözlemler:**
- `wage_per_hour`, `capital_gains`, `capital_losses`, `dividends_from_stocks` sütunlarında değerlerin %89–98'i **0**. Dağılımlar çok çarpık; modelde log(1+x) dönüşümü ya da '0 mı değil mi' bayrağı faydalı olabilir.
- `wage_per_hour` en fazla 9999. Değer büyük ihtimalle **cent** cinsinden (9999 = $99.99/saat), üst sınırda kesilmiş (top-coded).
- `capital_gains` en fazla 99999. Bu da aynı şekilde kesilmiş bir değer.
- `age` 0–90 arasında. 18 yaş altı kayıtlar (çocuklar) verinin büyük bir kısmı ve neredeyse hepsi 50K altı.


## 8. Bazı Öznitelikler ve Yüksek Gelir Oranı (train)

### education

| education | kayıt | 50K+ % |
|---|---|---|
| Prof school degree (MD DDS DVM LLB JD) | 1,793 | 54.04 |
| Doctorate degree(PhD EdD) | 1,263 | 52.02 |
| Masters degree(MA MS MEng MEd MSW MBA) | 6,540 | 31.16 |
| Bachelors degree(BA AB BS) | 19,859 | 19.71 |
| Associates degree-academic program | 4,363 | 9.44 |
| Associates degree-occup /vocational | 5,358 | 7.71 |
| Some college but no degree | 27,809 | 6.43 |
| High school graduate | 48,374 | 3.88 |
| 12th grade no diploma | 2,125 | 1.60 |
| 11th grade | 6,862 | 1.02 |
| 7th and 8th grade | 7,976 | 0.90 |
| 10th grade | 7,539 | 0.82 |
| 1st 2nd 3rd or 4th grade | 1,799 | 0.72 |
| 5th or 6th grade | 3,277 | 0.67 |
| 9th grade | 6,193 | 0.61 |
| Less than 1st grade | 817 | 0.12 |
| Children | 44,347 | 0.00 |

### sex

| sex | kayıt | 50K+ % |
|---|---|---|
| Male | 93,894 | 10.35 |
| Female | 102,400 | 2.60 |

### class_of_worker

| class_of_worker | kayıt | 50K+ % |
|---|---|---|
| Self-employed-incorporated | 3,264 | 34.74 |
| Federal government | 2,925 | 20.41 |
| Self-employed-not incorporated | 8,442 | 12.91 |
| State government | 4,227 | 11.47 |
| Local government | 7,783 | 10.88 |
| Private | 72,021 | 10.17 |
| Not in universe | 97,029 | 0.93 |
| Without pay | 165 | 0.61 |
| Never worked | 438 | 0.46 |

### marital_stat

| marital_stat | kayıt | 50K+ % |
|---|---|---|
| Married-civilian spouse present | 84,194 | 11.40 |
| Divorced | 12,707 | 8.39 |
| Married-spouse absent | 1,517 | 6.33 |
| Separated | 3,459 | 4.57 |
| Widowed | 10,456 | 3.16 |
| Married-A F spouse present | 665 | 2.26 |
| Never married | 83,296 | 1.34 |

### Yaş grubu

| yaş grubu | kayıt | 50K+ % |
|---|---|---|
| 0-17 | 52,826 | 0.00 |
| 18-24 | 17,806 | 0.62 |
| 25-34 | 30,880 | 5.82 |
| 35-44 | 31,413 | 12.71 |
| 45-54 | 23,195 | 16.24 |
| 55-64 | 15,906 | 11.10 |
| 65+ | 24,268 | 3.89 |


## 9. Sonraki Adımlar İçin Notlar

1. **Veritabanı tasarımı:** Kategorik metin sütunları (education, marital_stat, race, country_*, state, ...) lookup tablolarına taşınmalı. `country_of_birth_father / mother / self` aynı `Country` tablosunu referans alacak 3 FK olmalı.
2. **Hiyerarşik kodlar:** detailed → major industry/occupation, Bölüm 6.3'teki gibi iki seviyeli lookup.
3. **NULL'lar:** `?` değerleri veritabanında `NULL` olarak tutulacak; 'Not in universe' ise lookup tablolarında normal bir değer olacak.
4. **ML:** `instance_weight` öznitelik olarak kullanılmayacak (istenirse `sample_weight` olarak verilebilir). `migration_*` sütunları için karar verilmeli. Dengesiz sınıflar için uygun metrik ve `class_weight` kullanılmalı.
