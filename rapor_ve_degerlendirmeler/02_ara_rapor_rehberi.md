# Ara Rapor 1 (Ödev 2) – Hazırlık Rehberi

Bu dosya raporun kendisi değildir. Ödevdeki her başlık için projede hangi malzemenin hazır olduğunu
ve hangi ekran görüntülerinin alınacağını listeler. Metni kendi cümlelerinizle yazın; ödev, AI ile
üretilmiş metne ağır ceza uyguluyor.

## 0. Ön hazırlık (bir kez)

1. SQL Server 2022 Express veya Developer ve SSMS'i kurun (README → Kurulum).
2. SSMS'te `database/` altındaki scriptleri **sırayla** açıp F5 ile çalıştırın:
   `01_create_database.sql` → `02_create_tables.sql` → `03_insert_lookup_data.sql` →
   `04_insert_sample_data.sql` → `05_normalization_examples.sql`.
   (03 ve 04 hazır üretilmiştir; veriyi değiştirmek isterseniz `python database/kaynak/sql_uret.py`.)
3. Ekran görüntüleri için `06_tablo_goruntuleri.sql` ve `05_...sql` içindeki SELECT'leri seçip çalıştırın.
   Bir sorguyu tek başına çalıştırmak için onu seçip F5'e basın.

## a) Projenin konusu ve amacı

| Kaynak | İçerik |
|---|---|
| `README.md` → Proje Hakkında, Motivasyon | Problem: 42 sütunluk düz anket tablosu, tekrarlar ve tutarsızlık riski |
| `01_kavramsal_tasarim_ER_modeli.pdf` → Bölüm 1–2 | Ham verinin sorunları (tekrar eden metinler, hiyerarşik kodlar, yapısal eksiklik) |

Cevaplanması gerekenler: hangi problem, **kimler** kullanacak (ör. gelir analizi yapan analist,
modelleri eğiten/izleyen ML ekibi, raporları okuyan karar verici), **hangi amaçla**.

## b) Tabloların tanıtımı

- Tablo sayısı: **35** = 7 ana tablo + 25 lookup + 3 ML tablosu.
  (normalizasyon örnekleri `norm` şemasındadır; projenin tablosu sayılmaz.)
- Sütunlar, veri tipleri, PK/FK: `database/02_create_tables.sql` (yorumlu).
  Ekran görüntüsü: `06` → bölüm **1b** sorgusu (Tablo / Sütun / VeriTipi / NULL / Anahtar / ReferansTablo).
- İlişkiler ve kardinaliteler: `01_kavramsal_tasarim_ER_modeli.pdf` → Bölüm 5 ve Şekil 1–4.
- Ödevin istediği ölçüde hepsini tek tek anlatmak uzun olur. Öneri: 7 ana ve 3 ML tablosunu ayrıntılı
  anlatın, 25 lookup tablosunu tek bir tabloda özetleyin (hepsi `ID PK + Ad UQ` yapısındadır;
  farklı olanlar: `EDUCATION.EducationLevel`, `INDUSTRY → MAJOR_INDUSTRY`, `OCCUPATION → MAJOR_OCCUPATION`).

Fiziksel tasarımda verilen kararlar (rapora yazılabilir):

| Karar | Nerede |
|---|---|
| Lookup ID'leri `TINYINT` (en büyük lookup 52 satır) | 02, bölüm A |
| 1:1 tablolarda `PersonID` hem PK hem FK, `ON DELETE CASCADE` | EMPLOYMENT, FINANCE, HOUSEHOLD, RESIDENCE, MIGRATION |
| PERSON–SURVEY_RECORD 1:1 → `SURVEY_RECORD.PersonID UNIQUE` | 02 |
| COUNTRY'ye 3 rol FK'sı, ülke bilinmiyorsa `NULL` | PERSON |
| `CHECK`: yaş 0–120, hafta 0–52, yıl 1994/1995, DataSplit train/test, olasılık 0–1 | 02 |
| `UNIQUE (ModelID, RecordID)`: bir model bir kaydı bir kez tahmin eder | PREDICTION |
| `WagePerHour` cent cinsinden tam sayı | FINANCE |

## c) Örnek veri girişi

- Lookup tabloları: veri setindeki **tüm** değerler (`03_insert_lookup_data.sql`).
- Ana tablolar: **24 örnek kişi** (`04_insert_sample_data.sql`), gerçek veri setinden seçildi:
  - 8 kişi aynı sektörde (*Retail trade*, kod 33) → sektör adı tekrarı
  - 1994 (13 kişi, MIGRATION satırı var) ve 1995 (11 kişi, MIGRATION satırı yok) kayıtları
  - Ülke bilgisi bilinmeyen (`NULL`) kişiler (PersonID 5, 8, 18, 24)
  - Çocuklar, 50K üstü kazananlar, train ve test kayıtları
  - Veri tutarsızlığı örneği: PersonID 2 → önceki eyalet *New Mexico*, bölge *Northeast*
    (eyalet → bölge bağımlılığının neden hiyerarşi yapılmadığını ER raporu Bölüm 8 açıklar)
- ML tabloları: 2 model **gerçekten eğitildi** (lojistik regresyon, karar ağacı). Test metrikleri
  `MODEL_METRIC`'te, 10 test kişisinin tahminleri `PREDICTION`'da.
- Ekran görüntüleri: `06` → bölüm 1 (kayıt sayıları), 2, 3, 4 (her tablo), 5 (adlarla birleşik görünüm),
  6 (tahmin ile gerçek değer). Bölüm 7'deki yorumlu komutlar kısıtların hata verdiğini gösterir (isteğe bağlı).

## d) Normalizasyon uygulamaları (6 örnek, en az 5 isteniyor)

Hepsi `database/05_normalization_examples.sql` içinde. Her örneğin başındaki yorum bloğunda ödevin
istediği 5 madde hazır: önceki yapı, FB'ler (X → Y), ihlal edilen NF ve anomali, ayrıştırma ve gerekçe,
sonraki tablolar (PK/FK). "Önce" tabloları projenin kendi verisinden JOIN ile üretilir; "sonra"
tabloları bu tablodan `INSERT … SELECT DISTINCT` ile ayrıştırılır.

| # | NF | Önce | Ana bağımlılık / sorun | Sonra |
|---|---|---|---|---|
| E1 | 1NF | ML_MODEL + `TestMetrics` metni | Tek hücrede 5 metrik | ML_MODEL + MODEL_METRIC |
| E2 | 1NF | PERSON + `BirthCountries` metni | Tek hücrede 3 ülke | PERSON (3 rol FK) + COUNTRY |
| E3 | 2NF | PREDICTION (ModelID, RecordID) + model ve kayıt bilgisi | ModelID → ModelName; RecordID → IncomeOver50K | ML_MODEL + SURVEY_RECORD + PREDICTION |
| E4 | 3NF | EMPLOYMENT + üst sektör/meslek adı | IndustryCode → MajorIndustryName | EMPLOYMENT + INDUSTRY + MAJOR_INDUSTRY (+ meslek) |
| E5 | 3NF | PERSON + eğitim adı ve seviyesi | EducationName → EducationLevel | PERSON + EDUCATION |
| E6 | BCNF | (RecordID, Algorithm, ModelID, Olasılık) | ModelID → Algorithm, ModelID süper anahtar değil | ML_MODEL + PREDICTION |

Her örnek için alınacak ekran görüntüleri `-- [EKRAN GÖRÜNTÜSÜ]` ile işaretli. Ayrıca:

- **E4 ve E6** güncelleme anomalisini canlı gösterir: bir transaction içinde tek satır değiştirilir,
  tutarsızlık SELECT ile görünür, sonra `ROLLBACK` ile geri alınır.
- **E3** kayıpsız birleştirme kontrolü içerir (`EXCEPT` sorgusu 0 satır döner).
- **E5** ekleme anomalisinin giderildiğini gösterir (kişi olmadan Doktora seviyesi eklenir).
- **E6** BCNF'in bedelini de not eder: `{RecordID, Algorithm} → ModelID` bağımlılığı tek tabloda korunamaz.

## e) Sonuç ve değerlendirme

- Nihai yapı / ER diyagramı: `rapor_ve_degerlendirmeler/gorseller/er_1_genel.png` … `er_4_...png`.
- Ölçülebilir katkılar (örnek veriden, rapora rakam olarak yazılabilir):
  - E3: model adı 10'ar kez tekrar ediyordu → 1 kez.
  - E4: "Retail trade" 8 satırda tekrar ediyordu → 1 satır. Ayrıca güncelleme anomalisinde aynı kod 2 farklı ada bağlandı.
  - Veri setinin tamamında metin hücrelerinin ~%31'i "Not in universe" (ER raporu Bölüm 2): lookup ile her biri 1 kez saklanır.
- Bilinçli olarak normalize **edilmeyen** bağımlılıklar ve nedenleri: eyalet → bölge ve hane detay → özet
  (veride kesin değil; ER raporu Bölüm 8).
