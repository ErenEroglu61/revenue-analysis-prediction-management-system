# Gelir Analizi ve Tahmin Yönetim Sistemi

> **Census-Income (KDD)** veri seti üzerinde kurulan, normalize edilmiş bir **Microsoft SQL Server** veritabanı
> ve bu veritabanı üzerinde çalışan **gelir analizi + makine öğrenmesi tahmin yönetimi** sistemi.
> *Veri Tabanı Yönetim Sistemleri* dersi kapsamında geliştirilmektedir.

## İçindekiler
 1. [Proje Hakkında](#proje-hakkında)
 2. [Motivasyon](#motivasyon)
 3. [Veri Seti](#veri-seti)
 4. [Yöntem](#yöntem)
 5. [Proje Yapısı](#proje-yapısı)
 6. [Kurulum](#kurulum)
 7. [Kullanım](#kullanım)
 8. [Deneyler](#deneyler)
 9. [Yol Haritası](#yol-haritası)
10. [Ekip](#ekip)
11. [Kaynakça](#kaynakça)

## Proje Hakkında

Proje, ABD Nüfus Bürosu'nun 1994–1995 anket verisinden oluşan ve tek bir düz tablo halinde gelen
**Census-Income (KDD)** veri setini ele alır. Uçtan uca yapılacak işler:

1. Veriyi analiz edip temizlemek (ön analiz ve EDA)
2. Veri için **ER modeli** tasarlamak ve modeli **3NF / BCNF** düzeyinde normalize etmek
3. Modeli **MSSQL** üzerinde tablolar, kısıtlar, indeksler, view'lar, stored procedure'ler ve trigger'larla uygulamak
4. Veriyi ETL süreciyle veritabanına yüklemek ve SQL ile gelir analizleri yapmak
5. Bir kişinin yıllık gelirinin **50.000 $ üzerinde** olup olmadığını tahmin eden ML modelleri eğitmek
6. Modelleri, metrikleri ve tahminleri **veritabanında yönetmek** ("prediction management")

## Motivasyon

- **Ders hedefi:** Bir VTYS projesinin tüm yaşam döngüsünü gerçek ve "kirli" bir veri seti üzerinde uygulamak.
  Bu döngü kavramsal tasarım, normalizasyon, fiziksel tasarım, veri yükleme, sorgulama, programlanabilir
  nesneler, performans, güvenlik ve yedeklemeden oluşur.
- **Veri neden uygun?** Veri seti normalizasyon için çok elverişli:
  - Tekrar eden uzun metinler var; metin hücrelerinin ~%31'i yalnızca "Not in universe".
  - Hiyerarşik kodlar var (detay sektör/meslek kodu → üst grup).
  - Aynı değer kümesini kullanan tekrarlı sütunlar var (anne / baba / kişinin doğum ülkesi).
  - Yapısal eksiklikler var (1995'te sorulmayan göç soruları).
- **Analitik amaç:** Gelir düzeyini etkileyen faktörleri (eğitim, meslek, çalışma süresi, yaş, yatırım geliri …)
  anlamak ve bu bilgiyi hem SQL raporlarıyla hem de ML modelleriyle ortaya koymak.

## Veri Seti

| Özellik | Değer |
|---|---|
| Kaynak | [UCI Machine Learning Repository – Census-Income (KDD)](https://archive.ics.uci.edu/dataset/117/census+income+kdd) |
| Dosyalar | `data/census-income.data` (train), `data/census-income.test` (test), `data/census-income.names` (açıklama) |
| Kayıt sayısı | 199.523 train + 99.762 test (birebir aynı satırlar silindikten sonra 196.294 + 98.879) |
| Sütunlar | 42 = 40 öznitelik + `instance_weight` (örnekleme ağırlığı) + hedef |
| Hedef | `income_over_50k` → 0 = 50K altı, 1 = 50K üstü (yaklaşık **%6 pozitif**, çok dengesiz) |
| Eksik değer | `?` → `NULL`. "Not in universe" eksik değil, ayrı bir kategori olarak tutulur |

> `instance_weight` bir nüfus ağırlığıdır. Ağırlıklı nüfus analizlerinde kullanılır, **ML modeline girdi olarak verilmez**.

## Yöntem

```
Ham CSV ──► Ön analiz / temizleme ──► EDA ──► ER modeli ──► Normalizasyon ──► MSSQL şeması (DDL)
                                                                                │
         ML modelleri ◄── vw_MLFeatures ◄── View / SP / Trigger ◄── ETL (staging → normalize tablolar)
              │
              └──► ML_MODEL / MODEL_METRIC / PREDICTION tabloları (tahmin yönetimi)
```

**Veritabanı tasarımı (özet):**
- **Ana varlıklar:**
  - `PERSON` merkezde yer alır.
  - `SURVEY_RECORD`, `EMPLOYMENT`, `FINANCE`, `HOUSEHOLD` ve `RESIDENCE` PERSON ile **1:1** ilişkilidir.
  - `MIGRATION` PERSON ile **1:0..1** ilişkilidir; yalnızca 1994 kayıtlarında vardır.
- **25 lookup tablosu:** `EDUCATION` (sıra seviyesiyle), `COUNTRY` (3 rolle kullanılır),
  `INDUSTRY → MAJOR_INDUSTRY`, `OCCUPATION → MAJOR_OCCUPATION`, paylaşılan `ANSWER` vb.
- **ML varlıkları:** `ML_MODEL`, `MODEL_METRIC`, `PREDICTION`
- Ayrıntılar ve ER diyagramları için:
  [`rapor_ve_degerlendirmeler/01_kavramsal_tasarim_ER_modeli.pdf`](rapor_ve_degerlendirmeler/01_kavramsal_tasarim_ER_modeli.pdf)

**Makine öğrenmesi (planlanan):**
- Lojistik regresyon taban modeldir (baseline). Random Forest ve Gradient Boosting ile karşılaştırılır.
- Sınıflar dengesiz olduğu için `class_weight='balanced'` kullanılır ve modeller **ROC-AUC, PR-AUC, F1,
  Precision/Recall** ile değerlendirilir; accuracy yanıltıcıdır.

## Proje Yapısı

```
revenue-analysis-prediction-management-system/
├── data/
│   ├── census-income.data / .test / .names   # ham veri (UCI)
│   └── processed/                             # script çıktıları (git'e eklenmez)
├── analysis/
│   ├── pre_analiz.py                          # ön analiz + temizleme → train_clean.csv, test_clean.csv
│   ├── turetilmis_ozellikler.py               # 9 türetilmiş özellik → train_features.csv, test_features.csv
│   └── eda.ipynb                              # görsel keşifsel veri analizi (EDA)
├── reports/
│   ├── pre_analiz_raporu.md                   # ön analiz raporu (otomatik)
│   └── turetilmis_ozellikler_raporu.md        # türetilmiş özellik raporu (otomatik)
├── rapor_ve_degerlendirmeler/
│   ├── 01_kavramsal_tasarim_ER_modeli.pdf     # Adım 1 raporu
│   ├── gorseller/                             # ER diyagramları (PNG)
│   └── kaynak/er_raporu.py                    # PDF ve diyagramları üreten script
├── database/
│   ├── 00_hepsini_calistir.sql                # 01–05'i sırayla çalıştırır (SQLCMD modu)
│   ├── 01_create_database.sql                 # GelirAnalizDB + norm şeması
│   ├── 02_create_tables.sql                   # 35 tablo: PK, FK, CHECK, UNIQUE, DEFAULT
│   ├── 03_insert_lookup_data.sql              # 25 lookup tablosu (otomatik üretilir)
│   ├── 04_insert_sample_data.sql              # 24 örnek kişi + ML tabloları (otomatik üretilir)
│   ├── 05_normalization_examples.sql          # 6 normalizasyon örneği (1NF, 2NF, 3NF, BCNF)
│   ├── 06_tablo_goruntuleri.sql               # rapor için tablo yapısı / içerik sorguları
│   ├── 07_etl_staging.sql                     # ETL: stg.CENSUS_RAW staging tablosu
│   ├── 08_etl_transform.sql                   # ETL: staging → lookup + 7 ana tablo (tek transaction)
│   ├── 09_etl_dogrulama.sql                   # ETL: satır sayısı, içerik ve kayıpsızlık kontrolleri
│   └── kaynak/
│       ├── sql_uret.py                        # 03 ve 04'ü veri setinden üretir
│       └── etl_yukle.py                       # ETL çalıştırıcısı: CSV → staging → 08 → 09
├── ml/                                        # (planlanan) model eğitimi ve tahmin scriptleri
└── README.md
```

## Kurulum

**1. Python ortamı** (Python 3.10+):
```bash
pip install pandas numpy scipy scikit-learn matplotlib jupyter reportlab
```

**2. Veritabanı (Adım 0'da yapılacak):**
- [SQL Server 2022 Developer Edition](https://www.microsoft.com/sql-server/sql-server-downloads) (ücretsiz)
- [SQL Server Management Studio (SSMS)](https://learn.microsoft.com/sql/ssms/download-sql-server-management-studio-ssms)
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)
- Python bağlantısı için:
  ```bash
  pip install pyodbc sqlalchemy
  ```

## Kullanım

Tüm komutlar **proje kök dizininden** çalıştırılır:

```bash
# 1) Ön analiz + temizleme  →  data/processed/*_clean.csv, reports/pre_analiz_raporu.md
python analysis/pre_analiz.py

# 2) Türetilmiş özellikler  →  data/processed/*_features.csv, reports/turetilmis_ozellikler_raporu.md
python analysis/turetilmis_ozellikler.py

# 3) EDA notebook'u (Jupyter veya VS Code'da "Run All")
jupyter notebook analysis/eda.ipynb

# 4) Adım 1 raporu: ER diyagramları + PDF  →  rapor_ve_degerlendirmeler/
python rapor_ve_degerlendirmeler/kaynak/er_raporu.py
```

```bash
# 5) Lookup ve örnek veri INSERT scriptlerini veri setinden yeniden üret (03 ve 04; isteğe bağlı)
python database/kaynak/sql_uret.py
```

**Veritabanını kurmak:** SSMS'te `database/01_…` → `05_…` dosyalarını sırayla açıp çalıştırın (F5).
Ya da komut satırından, `database/` klasörü içindeyken:

```bash
sqlcmd -S localhost\SQLEXPRESS -E -i 00_hepsini_calistir.sql
```

Tablo yapısını ve içeriğini görmek için `06_tablo_goruntuleri.sql` kullanılır. Ara rapor için hangi
görüntünün nereden alınacağı: [`rapor_ve_degerlendirmeler/02_ara_rapor_rehberi.md`](rapor_ve_degerlendirmeler/02_ara_rapor_rehberi.md).

**Tüm veri setini yüklemek (ETL):** 01–03 çalıştıktan sonra, proje kök dizininden:

```bash
python database/kaynak/etl_yukle.py                      # varsayılan sunucu: localhost\SQLEXPRESS
python database/kaynak/etl_yukle.py --sadece-dogrula     # yalnızca 09 doğrulamasını çalıştırır
```

1. `*_clean.csv` dosyaları `stg.CENSUS_RAW` tablosuna metin olarak yüklenir (Extract).
2. `08` önce kalite kontrolü yapar (tip dönüşümü, zorunlu alanlar, kod → üst grup bağımlılığı).
   Ardından tek bir transaction içinde ana ve ML tablolarını boşaltır, lookup'lara yalnızca yeni
   değerleri ekler ve 7 ana tabloyu `INSERT … SELECT` ile doldurur. `PersonID = RecordID = StagingID` olur.
3. `09`, 16 kontrolün sonucunu OK/HATA olarak listeler. En güçlü kontrol kayıpsızlıktır: 42 sütun
   normalize tablolardan geri kurulur ve staging ile iki yönlü `EXCEPT` sonucu 0 satır olmalıdır.

Script tekrar tekrar çalıştırılabilir; yaklaşık 1 dakika sürer. 04'teki 24 örnek kişinin ve örnek ML
kayıtlarının yerini tam veri alır. 05'teki normalizasyon örnekleri örnek veriye göre yazıldığı için
onları göstermek gerektiğinde veritabanı `00_hepsini_calistir.sql` ile yeniden kurulmalıdır.

## Deneyler

### Ön analiz ve EDA bulguları
- **Dengesiz sınıflar:** Kayıtların ~%6'sı 50K üstü. Ağırlıklı (nüfus) oran da benzer (%6.4–6.5).
- **Yapısal eksiklik:** `migration_*` sütunları 1995 kayıtlarında %100 boş, 1994'te hiç eksik yok.
- **Tekrarlar:** Birebir aynı satırlar silindi. Ağırlıkları farklı olan benzer satırlar farklı kişi kabul edildi.
- **Gelirle en güçlü ilişkili faktörler:** Eğitim düzeyi, meslek/sektör, yılın 52 haftası çalışmak, yaş (45–55 zirve),
  yatırım geliri, evlilik/ortak vergi beyanı, cinsiyet.
- Train ve test dağılımları neredeyse aynı (tüm sütunlarda PSI < 0.01).

### Türetilmiş özelliklerin tek başına ayırt ediciliği (ROC-AUC)

| Özellik | Train AUC | Test AUC |
|---|---|---|
| `education_level` | 0.85 | 0.84 |
| `full_year_worker` | 0.76 | 0.76 |
| `is_professional_occ` | 0.73 | 0.73 |
| `has_investment` | 0.73 | 0.73 |
| `is_employed` | 0.73 | 0.73 |
| `is_householder` | 0.71 | 0.71 |
| `joint_filer` | 0.70 | 0.70 |
| `age_group` | 0.69 | 0.69 |
| `is_married` | 0.68 | 0.69 |

Ayrıntılar: [`reports/`](reports/) ve [`analysis/eda.ipynb`](analysis/eda.ipynb).

### Planlanan deneyler
- **İndeks performansı:** İndeks öncesi ve sonrası execution plan karşılaştırması
  (`SET STATISTICS IO/TIME`) (Adım 7).
- **ML modelleri:** Modellerin test kümesinde ROC-AUC / PR-AUC / F1 ile karşılaştırılması.
  Sonuçlar `MODEL_METRIC` tablosunda tutulacak (Adım 10).

## Yol Haritası

| # | Adım | İçerik | Çıktı | Durum |
|---|---|---|---|---|
| – | Ön analiz | Veri okuma, `?` → NULL, tekrar eden satır/sütun analizi, temizleme | `analysis/pre_analiz.py`, `reports/pre_analiz_raporu.md` | ✅ |
| – | Türetilmiş özellikler | 9 özellik (education_level, age_group, full_year_worker …) | `analysis/turetilmis_ozellikler.py` | ✅ |
| – | EDA | Dağılımlar, gelir ilişkileri, korelasyon, Cramér's V, MI, PSI, aykırı değerler | `analysis/eda.ipynb` | ✅ |
| 0 | Ortam kurulumu | SQL Server 2022 Express, SSMS, ODBC Driver 18, `pyodbc` | Çalışan MSSQL bağlantısı | ✅ |
| 1 | Kavramsal tasarım | Varlıklar, ilişkiler, kardinaliteler, ER diyagramları, veri sözlüğü | `rapor_ve_degerlendirmeler/01_...pdf` | ✅ |
| 2 | Normalizasyon | Fonksiyonel bağımlılıklar; 1NF → 2NF → 3NF → BCNF gerekçeleri, 6 örnek | `database/05_normalization_examples.sql`, Ara Rapor 1 | ✅ |
| 3 | Fiziksel tasarım (DDL) | `CREATE DATABASE`, tablolar, veri tipleri, PK/FK, `CHECK`, `UNIQUE`, `DEFAULT`, `NOT NULL`; örnek veri | `database/01`–`04` | ✅ |
| 4 | Veri yükleme (ETL) | Ham CSV → staging tablo (`BULK INSERT` / Python) → `INSERT … SELECT` ile lookup ve ana tablolar; satır sayısı ve FK doğrulaması | `database/07`–`09`, `database/kaynak/etl_yukle.py` | ✅ 295.173 kayıt, 16/16 kontrol OK |
| 5 | Sorgular | `JOIN`, `GROUP BY/HAVING`, alt sorgu, `CTE`, pencere fonksiyonları, `PIVOT`; EDA bulgularının SQL ile tekrarı | Analitik sorgu scriptleri | ⬜ |
| 6 | Programlanabilir nesneler | `vw_PersonFull`, `vw_MLFeatures`; stored procedure, fonksiyon (`fn_AgeGroup`), audit trigger, `TRY…CATCH` ile transaction | View / SP / trigger scriptleri | ⬜ |
| 7 | İndeksleme ve performans | Nonclustered/covering index; execution plan ve `STATISTICS IO/TIME` karşılaştırması | Performans raporu | ⬜ |
| 8 | Güvenlik | Login, user, roller (`analyst`, `ml_service`, `admin`), `GRANT` / `DENY` | Güvenlik scripti | ⬜ |
| 9 | Yedekleme ve geri yükleme | Full + differential `BACKUP`, `RESTORE` testi | Yedekleme scripti ve test sonucu | ⬜ |
| 10 | ML entegrasyonu | `vw_MLFeatures`'tan eğitim; `ML_MODEL`, `MODEL_METRIC`, `PREDICTION` tablolarına yazma; model karşılaştırması | `ml/` scriptleri, model raporu | ⬜ |
| 11 | Dokümantasyon | README, final rapor (ER diyagramı, normalizasyon, sonuçlar), sunum | Final rapor | ⬜ |

✅ tamamlandı · 🟨 kısmen · ⬜ planlandı

## Ekip

| Ad Soyad | Öğrenci No | Rol / Sorumluluk |
|---|---|---|
| | | |
| | | |

## Kaynakça

1. Lane, T. & Kohavi, R. — *Census-Income (KDD)* Data Set, UCI Machine Learning Repository.
   https://archive.ics.uci.edu/dataset/117/census+income+kdd
2. Elmasri, R. & Navathe, S. B. — *Fundamentals of Database Systems*, Pearson.
3. Silberschatz, A., Korth, H. F. & Sudarshan, S. — *Database System Concepts*, McGraw-Hill.
4. Microsoft — *SQL Server Technical Documentation*. https://learn.microsoft.com/sql/sql-server/
5. Pedregosa, F. et al. — *Scikit-learn: Machine Learning in Python*, JMLR 12, 2011.
