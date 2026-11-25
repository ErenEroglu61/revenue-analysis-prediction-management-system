/* ============================================================================
   05 - Normalizasyon örnekleri (norm şeması)

   Projenin tabloları zaten normalize olduğu için, her örnekte önce projenin kendi
   verisinden normalize EDİLMEMİŞ bir tablo üretilir (E?_ONCE_...), sonra bu tablo
   ayrıştırılarak normalize tablolar elde edilir (E?_SONRA_...).

   Örnekler:
     E1  1NF  : Çok değerli metrik sütunu          (ML_MODEL  -> ML_MODEL + MODEL_METRIC)
     E2  1NF  : Çok değerli doğum ülkeleri sütunu   (PERSON    -> PERSON + COUNTRY, 3 rol)
     E3  2NF  : Kısmi bağımlılık                   (PREDICTION -> ML_MODEL + SURVEY_RECORD + PREDICTION)
     E4  3NF  : Geçişli bağımlılık (sektör/meslek)  (EMPLOYMENT -> EMPLOYMENT + INDUSTRY + MAJOR_INDUSTRY ...)
     E5  3NF  : Geçişli bağımlılık (eğitim seviyesi)(PERSON    -> PERSON + EDUCATION)
     E6  BCNF : Anahtar olmayan belirleyen          (MODEL_SCORE -> ML_MODEL + PREDICTION)

   Ön koşul: 01-04 numaralı scriptler çalıştırılmış olmalı.
   Her bölümdeki SELECT'lerin sonuçları rapora ekran görüntüsü olarak eklenebilir.
   ============================================================================ */
USE GelirAnalizDB;
GO
SET NOCOUNT ON;

-- Script tekrar çalıştırılabilsin diye eski örnek tablolar silinir (FK sırasına dikkat)
DROP TABLE IF EXISTS norm.E1_SONRA_MODEL_METRIC, norm.E1_SONRA_ML_MODEL, norm.E1_ONCE_ML_MODEL;
DROP TABLE IF EXISTS norm.E2_SONRA_PERSON, norm.E2_SONRA_COUNTRY, norm.E2_ONCE_PERSON;
DROP TABLE IF EXISTS norm.E3_SONRA_PREDICTION, norm.E3_SONRA_ML_MODEL, norm.E3_SONRA_SURVEY_RECORD,
                     norm.E3_ONCE_PREDICTION;
DROP TABLE IF EXISTS norm.E4_SONRA_EMPLOYMENT, norm.E4_SONRA_INDUSTRY, norm.E4_SONRA_MAJOR_INDUSTRY,
                     norm.E4_SONRA_OCCUPATION, norm.E4_SONRA_MAJOR_OCCUPATION, norm.E4_ONCE_EMPLOYMENT;
DROP TABLE IF EXISTS norm.E5_SONRA_PERSON, norm.E5_SONRA_EDUCATION, norm.E5_ONCE_PERSON;
DROP TABLE IF EXISTS norm.E6_SONRA_PREDICTION, norm.E6_SONRA_ML_MODEL, norm.E6_ONCE_MODEL_SCORE;
GO


/* ############################################################################
   E1 - 1NF : ML_MODEL tablosunda çok değerli "TestMetrics" sütunu
   ############################################################################
   ÖNCE : E1_ONCE_ML_MODEL(ModelID PK, ModelName, Algorithm, TestMetrics)
          TestMetrics = 'f1=0.3949; pr_auc=0.5515; ...'  -> tek hücrede birden çok değer
   FB   : ModelID -> ModelName, Algorithm, TestMetrics
          (ModelID, MetricName) -> MetricValue   (hücrenin içine gizlenmiş bağımlılık)
   İHLAL: 1NF - değerler atomik değil.
   ANOMALİ:
     - Güncelleme: tek bir metrik değişince bütün metin yeniden yazılır; yazım hatası fark edilmez.
     - Ekleme   : yeni bir metrik (ör. accuracy) eklemek metni elle düzenlemeyi gerektirir.
     - Sorgu    : "test ROC-AUC > 0.93 olan modeller" gibi bir sorgu ancak metin ayrıştırarak yazılabilir;
                  MetricValue için CHECK / veri tipi kontrolü yapılamaz.
   AYRIŞTIRMA: Tekrarlanan grup ayrı tabloya taşınır; her satıra tek metrik düşer.
   SONRA: E1_SONRA_ML_MODEL(ModelID PK, ModelName, Algorithm)
          E1_SONRA_MODEL_METRIC(ModelID FK, DataSplit, MetricName, MetricValue)
                                PK (ModelID, DataSplit, MetricName)
   ############################################################################ */
CREATE TABLE norm.E1_ONCE_ML_MODEL (
    ModelID     INT           NOT NULL PRIMARY KEY,
    ModelName   NVARCHAR(100) NOT NULL,
    Algorithm   NVARCHAR(50)  NOT NULL,
    TestMetrics NVARCHAR(400) NOT NULL
);

INSERT INTO norm.E1_ONCE_ML_MODEL (ModelID, ModelName, Algorithm, TestMetrics)
SELECT m.ModelID, m.ModelName, m.Algorithm,
       STRING_AGG(CONCAT(mm.MetricName, '=', CAST(mm.MetricValue AS VARCHAR(10))), '; ')
           WITHIN GROUP (ORDER BY mm.MetricName)
FROM dbo.ML_MODEL m
JOIN dbo.MODEL_METRIC mm ON mm.ModelID = m.ModelID AND mm.DataSplit = 'test'
GROUP BY m.ModelID, m.ModelName, m.Algorithm;

SELECT * FROM norm.E1_ONCE_ML_MODEL;                      -- [EKRAN GÖRÜNTÜSÜ] normalizasyon öncesi

-- Anomali gösterimi: değere göre filtrelemek için metin parçalamak gerekir
SELECT ModelName, TestMetrics
FROM norm.E1_ONCE_ML_MODEL
WHERE TestMetrics LIKE '%roc_auc=0.93%';                   -- kırılgan: 0.94 olsa bulunmaz

-- Ayrıştırma
CREATE TABLE norm.E1_SONRA_ML_MODEL (
    ModelID   INT           NOT NULL PRIMARY KEY,
    ModelName NVARCHAR(100) NOT NULL UNIQUE,
    Algorithm NVARCHAR(50)  NOT NULL
);
CREATE TABLE norm.E1_SONRA_MODEL_METRIC (
    ModelID     INT          NOT NULL REFERENCES norm.E1_SONRA_ML_MODEL (ModelID),
    DataSplit   VARCHAR(5)   NOT NULL,
    MetricName  VARCHAR(20)  NOT NULL,
    MetricValue DECIMAL(6,4) NOT NULL,
    PRIMARY KEY (ModelID, DataSplit, MetricName)
);

INSERT INTO norm.E1_SONRA_ML_MODEL (ModelID, ModelName, Algorithm)
SELECT ModelID, ModelName, Algorithm FROM norm.E1_ONCE_ML_MODEL;

-- Metin STRING_SPLIT ile atomik satırlara bölünür
INSERT INTO norm.E1_SONRA_MODEL_METRIC (ModelID, DataSplit, MetricName, MetricValue)
SELECT o.ModelID, 'test',
       LEFT(p.part, CHARINDEX('=', p.part) - 1),
       CAST(SUBSTRING(p.part, CHARINDEX('=', p.part) + 1, 20) AS DECIMAL(6,4))
FROM norm.E1_ONCE_ML_MODEL o
CROSS APPLY (SELECT LTRIM(RTRIM(value)) AS part FROM STRING_SPLIT(o.TestMetrics, ';')) p;

SELECT * FROM norm.E1_SONRA_ML_MODEL;                     -- [EKRAN GÖRÜNTÜSÜ] sonrası
SELECT * FROM norm.E1_SONRA_MODEL_METRIC ORDER BY ModelID, MetricName;

-- Artık aynı sorgu düz bir WHERE ile yazılır
SELECT m.ModelName, mm.MetricValue AS test_roc_auc
FROM norm.E1_SONRA_ML_MODEL m
JOIN norm.E1_SONRA_MODEL_METRIC mm ON mm.ModelID = m.ModelID
WHERE mm.MetricName = 'roc_auc' AND mm.MetricValue > 0.93;
GO


/* ############################################################################
   E2 - 1NF : PERSON tablosunda çok değerli "BirthCountries" sütunu
   ############################################################################
   ÖNCE : E2_ONCE_PERSON(PersonID PK, Age, BirthCountries)
          BirthCountries = 'Kendi, Baba, Anne' sırasıyla 3 ülke adı ('?' = bilinmiyor)
   FB   : PersonID -> Age, BirthCountries
          PersonID -> (kişinin, babasının, annesinin) doğum ülkesi  (tek hücrede 3 değer)
   İHLAL: 1NF - atomik olmayan, çok değerli sütun; sıra bilgisi metnin içinde gizli.
   ANOMALİ:
     - Sorgu     : "babası Meksika doğumlu kişiler" sorgusu LIKE ile yazılır, anne/baba karışabilir.
     - Güncelleme: bir ülke adı (ör. 'United-States') yüzlerce metnin içinde tekrar eder; ad değişirse
                   hepsi elle düzeltilir, birinin atlanması tutarsızlık doğurur.
     - Bütünlük  : 'Unted-States' gibi hatalı yazımlar engellenemez (FK kontrolü yok).
   AYRIŞTIRMA: Metin 3 atomik role ayrılır; ülke adları tek bir COUNTRY tablosuna taşınır ve
               PERSON bu tabloya 3 ayrı FK ile (rol bazlı ilişki) bağlanır. Bilinmeyen ülke NULL olur.
   SONRA: E2_SONRA_COUNTRY(CountryID PK, CountryName UQ)
          E2_SONRA_PERSON(PersonID PK, Age, BirthCountryID FK, FatherBirthCountryID FK,
                          MotherBirthCountryID FK)
   ############################################################################ */
CREATE TABLE norm.E2_ONCE_PERSON (
    PersonID       INT           NOT NULL PRIMARY KEY,
    Age            TINYINT       NOT NULL,
    BirthCountries NVARCHAR(200) NOT NULL       -- 'Kendi, Baba, Anne'
);

INSERT INTO norm.E2_ONCE_PERSON (PersonID, Age, BirthCountries)
SELECT p.PersonID, p.Age,
       CONCAT(ISNULL(cs.CountryName, '?'), ', ', ISNULL(cf.CountryName, '?'), ', ', ISNULL(cm.CountryName, '?'))
FROM dbo.PERSON p
LEFT JOIN dbo.COUNTRY cs ON cs.CountryID = p.BirthCountryID
LEFT JOIN dbo.COUNTRY cf ON cf.CountryID = p.FatherBirthCountryID
LEFT JOIN dbo.COUNTRY cm ON cm.CountryID = p.MotherBirthCountryID;

SELECT * FROM norm.E2_ONCE_PERSON;                        -- [EKRAN GÖRÜNTÜSÜ] öncesi

-- Ayrıştırma
CREATE TABLE norm.E2_SONRA_COUNTRY (
    CountryID   INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CountryName NVARCHAR(50) NOT NULL UNIQUE
);
CREATE TABLE norm.E2_SONRA_PERSON (
    PersonID             INT     NOT NULL PRIMARY KEY,
    Age                  TINYINT NOT NULL,
    BirthCountryID       INT     NULL REFERENCES norm.E2_SONRA_COUNTRY (CountryID),
    FatherBirthCountryID INT     NULL REFERENCES norm.E2_SONRA_COUNTRY (CountryID),
    MotherBirthCountryID INT     NULL REFERENCES norm.E2_SONRA_COUNTRY (CountryID)
);

-- 'A, B, C' metni PARSENAME ile parçalanır (ülke adlarında nokta yoktur)
WITH parcali AS (
    SELECT PersonID, Age,
           PARSENAME(REPLACE(BirthCountries, ', ', '.'), 3) AS Kendi,
           PARSENAME(REPLACE(BirthCountries, ', ', '.'), 2) AS Baba,
           PARSENAME(REPLACE(BirthCountries, ', ', '.'), 1) AS Anne
    FROM norm.E2_ONCE_PERSON
)
INSERT INTO norm.E2_SONRA_COUNTRY (CountryName)
SELECT Ulke FROM (SELECT Kendi AS Ulke FROM parcali
                  UNION SELECT Baba FROM parcali
                  UNION SELECT Anne FROM parcali) u
WHERE Ulke <> '?';

WITH parcali AS (
    SELECT PersonID, Age,
           PARSENAME(REPLACE(BirthCountries, ', ', '.'), 3) AS Kendi,
           PARSENAME(REPLACE(BirthCountries, ', ', '.'), 2) AS Baba,
           PARSENAME(REPLACE(BirthCountries, ', ', '.'), 1) AS Anne
    FROM norm.E2_ONCE_PERSON
)
INSERT INTO norm.E2_SONRA_PERSON (PersonID, Age, BirthCountryID, FatherBirthCountryID, MotherBirthCountryID)
SELECT x.PersonID, x.Age, cs.CountryID, cf.CountryID, cm.CountryID
FROM parcali x
LEFT JOIN norm.E2_SONRA_COUNTRY cs ON cs.CountryName = x.Kendi
LEFT JOIN norm.E2_SONRA_COUNTRY cf ON cf.CountryName = x.Baba
LEFT JOIN norm.E2_SONRA_COUNTRY cm ON cm.CountryName = x.Anne;

SELECT * FROM norm.E2_SONRA_COUNTRY;                      -- [EKRAN GÖRÜNTÜSÜ] sonrası
SELECT * FROM norm.E2_SONRA_PERSON;
GO


/* ############################################################################
   E3 - 2NF : PREDICTION tablosunda kısmi bağımlılık
   ############################################################################
   ÖNCE : E3_ONCE_PREDICTION(ModelID, RecordID, ModelName, Algorithm, SurveyYear, IncomeOver50K,
                             PredictedProbability, PredictedLabel)     PK (ModelID, RecordID)
   FB   : ModelID            -> ModelName, Algorithm                      (kısmi)
          RecordID           -> SurveyYear, IncomeOver50K                 (kısmi)
          ModelID, RecordID  -> PredictedProbability, PredictedLabel      (tam)
   İHLAL: 2NF - anahtar olmayan sütunlar bileşik anahtarın yalnızca bir parçasına bağlı.
   ANOMALİ:
     - Güncelleme: model adı her tahmin satırında tekrar eder; adı değiştirmek N satırı günceller.
     - Ekleme   : henüz tahmin üretmemiş bir model kaydedilemez (RecordID anahtarın parçası, NULL olamaz).
     - Silme    : bir kaydın tüm tahminleri silinirse kaydın gerçek etiketi (IncomeOver50K) de kaybolur.
   AYRIŞTIRMA: Her kısmi bağımlılık kendi belirleyeniyle ayrı tabloya taşınır.
   SONRA: E3_SONRA_ML_MODEL(ModelID PK, ModelName, Algorithm)
          E3_SONRA_SURVEY_RECORD(RecordID PK, SurveyYear, IncomeOver50K)
          E3_SONRA_PREDICTION(ModelID FK, RecordID FK, PredictedProbability, PredictedLabel)
                              PK (ModelID, RecordID)
   ############################################################################ */
CREATE TABLE norm.E3_ONCE_PREDICTION (
    ModelID              INT           NOT NULL,
    RecordID             INT           NOT NULL,
    ModelName            NVARCHAR(100) NOT NULL,
    Algorithm            NVARCHAR(50)  NOT NULL,
    SurveyYear           SMALLINT      NOT NULL,
    IncomeOver50K        BIT           NOT NULL,
    PredictedProbability DECIMAL(5,4)  NOT NULL,
    PredictedLabel       BIT           NOT NULL,
    PRIMARY KEY (ModelID, RecordID)
);

INSERT INTO norm.E3_ONCE_PREDICTION
SELECT p.ModelID, p.RecordID, m.ModelName, m.Algorithm, r.SurveyYear, r.IncomeOver50K,
       p.PredictedProbability, p.PredictedLabel
FROM dbo.PREDICTION p
JOIN dbo.ML_MODEL m      ON m.ModelID = p.ModelID
JOIN dbo.SURVEY_RECORD r ON r.RecordID = p.RecordID;

SELECT * FROM norm.E3_ONCE_PREDICTION ORDER BY ModelID, RecordID;   -- [EKRAN GÖRÜNTÜSÜ] öncesi

-- Tekrarın ölçüsü: her model adı kaç kez saklanıyor?
SELECT ModelName, COUNT(*) AS TekrarSayisi FROM norm.E3_ONCE_PREDICTION GROUP BY ModelName;

-- Ayrıştırma
CREATE TABLE norm.E3_SONRA_ML_MODEL (
    ModelID   INT           NOT NULL PRIMARY KEY,
    ModelName NVARCHAR(100) NOT NULL UNIQUE,
    Algorithm NVARCHAR(50)  NOT NULL
);
CREATE TABLE norm.E3_SONRA_SURVEY_RECORD (
    RecordID      INT      NOT NULL PRIMARY KEY,
    SurveyYear    SMALLINT NOT NULL,
    IncomeOver50K BIT      NOT NULL
);
CREATE TABLE norm.E3_SONRA_PREDICTION (
    ModelID              INT          NOT NULL REFERENCES norm.E3_SONRA_ML_MODEL (ModelID),
    RecordID             INT          NOT NULL REFERENCES norm.E3_SONRA_SURVEY_RECORD (RecordID),
    PredictedProbability DECIMAL(5,4) NOT NULL,
    PredictedLabel       BIT          NOT NULL,
    PRIMARY KEY (ModelID, RecordID)
);

INSERT INTO norm.E3_SONRA_ML_MODEL
SELECT DISTINCT ModelID, ModelName, Algorithm FROM norm.E3_ONCE_PREDICTION;
INSERT INTO norm.E3_SONRA_SURVEY_RECORD
SELECT DISTINCT RecordID, SurveyYear, IncomeOver50K FROM norm.E3_ONCE_PREDICTION;
INSERT INTO norm.E3_SONRA_PREDICTION
SELECT ModelID, RecordID, PredictedProbability, PredictedLabel FROM norm.E3_ONCE_PREDICTION;

SELECT * FROM norm.E3_SONRA_ML_MODEL;                     -- [EKRAN GÖRÜNTÜSÜ] sonrası
SELECT * FROM norm.E3_SONRA_SURVEY_RECORD;
SELECT * FROM norm.E3_SONRA_PREDICTION ORDER BY ModelID, RecordID;

-- Kayıpsız birleştirme (lossless join) kontrolü: 0 satır dönmeli
SELECT ModelID, RecordID, ModelName, Algorithm, SurveyYear, IncomeOver50K, PredictedProbability, PredictedLabel
FROM norm.E3_ONCE_PREDICTION
EXCEPT
SELECT p.ModelID, p.RecordID, m.ModelName, m.Algorithm, r.SurveyYear, r.IncomeOver50K,
       p.PredictedProbability, p.PredictedLabel
FROM norm.E3_SONRA_PREDICTION p
JOIN norm.E3_SONRA_ML_MODEL m      ON m.ModelID = p.ModelID
JOIN norm.E3_SONRA_SURVEY_RECORD r ON r.RecordID = p.RecordID;
GO


/* ############################################################################
   E4 - 3NF : EMPLOYMENT tablosunda geçişli bağımlılık (sektör / meslek hiyerarşisi)
   ############################################################################
   ÖNCE : E4_ONCE_EMPLOYMENT(PersonID PK, IndustryCode, MajorIndustryName,
                             OccupationCode, MajorOccupationName, WeeksWorkedInYear)
   FB   : PersonID       -> IndustryCode, OccupationCode, WeeksWorkedInYear
          IndustryCode   -> MajorIndustryName      (veri setinin tamamında kesin: 52 kod -> 24 grup)
          OccupationCode -> MajorOccupationName    (47 kod -> 15 grup)
          Dolayısıyla PersonID -> IndustryCode -> MajorIndustryName  (geçişli)
   İHLAL: 3NF - anahtar olmayan bir sütun, anahtar olmayan başka bir sütun üzerinden anahtara bağlı.
   ANOMALİ:
     - Güncelleme: 'Retail trade' adı aynı kodla çalışan her kişide tekrar eder; birinde değiştirilirse
                   aynı kod iki farklı üst gruba bağlanmış görünür (aşağıda gösterilmiştir).
     - Ekleme   : yeni bir sektör kodunun üst grubu, o sektörde çalışan biri olmadan kaydedilemez.
     - Silme    : 36 kodlu sektörde çalışan tek kişi silinirse "36 -> Private household services"
                  bilgisi de kaybolur.
   AYRIŞTIRMA: Geçişli bağımlılığın belirleyeni (IndustryCode / OccupationCode) kendi tablosuna,
               üst grup adları da ayrı lookup tablolarına taşınır.
   SONRA: E4_SONRA_MAJOR_INDUSTRY(MajorIndustryID PK, IndustryName UQ)
          E4_SONRA_INDUSTRY(IndustryCode PK, MajorIndustryID FK)
          E4_SONRA_MAJOR_OCCUPATION(MajorOccupationID PK, OccupationName UQ)
          E4_SONRA_OCCUPATION(OccupationCode PK, MajorOccupationID FK)
          E4_SONRA_EMPLOYMENT(PersonID PK, IndustryCode FK, OccupationCode FK, WeeksWorkedInYear)
   ############################################################################ */
CREATE TABLE norm.E4_ONCE_EMPLOYMENT (
    PersonID            INT          NOT NULL PRIMARY KEY,
    IndustryCode        TINYINT      NOT NULL,
    MajorIndustryName   NVARCHAR(60) NOT NULL,
    OccupationCode      TINYINT      NOT NULL,
    MajorOccupationName NVARCHAR(60) NOT NULL,
    WeeksWorkedInYear   TINYINT      NOT NULL
);

INSERT INTO norm.E4_ONCE_EMPLOYMENT
SELECT e.PersonID, e.IndustryCode, mi.IndustryName, e.OccupationCode, mo.OccupationName, e.WeeksWorkedInYear
FROM dbo.EMPLOYMENT e
JOIN dbo.INDUSTRY i          ON i.IndustryCode = e.IndustryCode
JOIN dbo.MAJOR_INDUSTRY mi   ON mi.MajorIndustryID = i.MajorIndustryID
JOIN dbo.OCCUPATION o        ON o.OccupationCode = e.OccupationCode
JOIN dbo.MAJOR_OCCUPATION mo ON mo.MajorOccupationID = o.MajorOccupationID;

SELECT * FROM norm.E4_ONCE_EMPLOYMENT ORDER BY IndustryCode, PersonID;   -- [EKRAN GÖRÜNTÜSÜ] öncesi

-- Güncelleme anomalisinin gösterimi (geri alınır)
BEGIN TRANSACTION;
    UPDATE norm.E4_ONCE_EMPLOYMENT SET MajorIndustryName = N'Retail Trade & Shops'
    WHERE PersonID = (SELECT MIN(PersonID) FROM norm.E4_ONCE_EMPLOYMENT WHERE IndustryCode = 33);

    -- Aynı kod artık iki farklı üst gruba bağlı görünüyor -> tutarsızlık   [EKRAN GÖRÜNTÜSÜ]
    SELECT IndustryCode, MajorIndustryName, COUNT(*) AS KisiSayisi
    FROM norm.E4_ONCE_EMPLOYMENT
    WHERE IndustryCode = 33
    GROUP BY IndustryCode, MajorIndustryName;
ROLLBACK;

-- Ayrıştırma
CREATE TABLE norm.E4_SONRA_MAJOR_INDUSTRY (
    MajorIndustryID INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IndustryName    NVARCHAR(60) NOT NULL UNIQUE
);
CREATE TABLE norm.E4_SONRA_INDUSTRY (
    IndustryCode    TINYINT NOT NULL PRIMARY KEY,
    MajorIndustryID INT     NOT NULL REFERENCES norm.E4_SONRA_MAJOR_INDUSTRY (MajorIndustryID)
);
CREATE TABLE norm.E4_SONRA_MAJOR_OCCUPATION (
    MajorOccupationID INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    OccupationName    NVARCHAR(60) NOT NULL UNIQUE
);
CREATE TABLE norm.E4_SONRA_OCCUPATION (
    OccupationCode    TINYINT NOT NULL PRIMARY KEY,
    MajorOccupationID INT     NOT NULL REFERENCES norm.E4_SONRA_MAJOR_OCCUPATION (MajorOccupationID)
);
CREATE TABLE norm.E4_SONRA_EMPLOYMENT (
    PersonID          INT     NOT NULL PRIMARY KEY,
    IndustryCode      TINYINT NOT NULL REFERENCES norm.E4_SONRA_INDUSTRY (IndustryCode),
    OccupationCode    TINYINT NOT NULL REFERENCES norm.E4_SONRA_OCCUPATION (OccupationCode),
    WeeksWorkedInYear TINYINT NOT NULL
);

INSERT INTO norm.E4_SONRA_MAJOR_INDUSTRY (IndustryName)
SELECT DISTINCT MajorIndustryName FROM norm.E4_ONCE_EMPLOYMENT;
INSERT INTO norm.E4_SONRA_INDUSTRY (IndustryCode, MajorIndustryID)
SELECT DISTINCT o.IndustryCode, mi.MajorIndustryID
FROM norm.E4_ONCE_EMPLOYMENT o JOIN norm.E4_SONRA_MAJOR_INDUSTRY mi ON mi.IndustryName = o.MajorIndustryName;
INSERT INTO norm.E4_SONRA_MAJOR_OCCUPATION (OccupationName)
SELECT DISTINCT MajorOccupationName FROM norm.E4_ONCE_EMPLOYMENT;
INSERT INTO norm.E4_SONRA_OCCUPATION (OccupationCode, MajorOccupationID)
SELECT DISTINCT o.OccupationCode, mo.MajorOccupationID
FROM norm.E4_ONCE_EMPLOYMENT o JOIN norm.E4_SONRA_MAJOR_OCCUPATION mo ON mo.OccupationName = o.MajorOccupationName;
INSERT INTO norm.E4_SONRA_EMPLOYMENT (PersonID, IndustryCode, OccupationCode, WeeksWorkedInYear)
SELECT PersonID, IndustryCode, OccupationCode, WeeksWorkedInYear FROM norm.E4_ONCE_EMPLOYMENT;

SELECT * FROM norm.E4_SONRA_MAJOR_INDUSTRY;               -- [EKRAN GÖRÜNTÜSÜ] sonrası
SELECT * FROM norm.E4_SONRA_INDUSTRY;
SELECT * FROM norm.E4_SONRA_MAJOR_OCCUPATION;
SELECT * FROM norm.E4_SONRA_OCCUPATION;
SELECT * FROM norm.E4_SONRA_EMPLOYMENT;

-- Artık 'Retail trade' adı yalnızca bir satırda; tek UPDATE ile her yerde değişir
SELECT * FROM norm.E4_SONRA_MAJOR_INDUSTRY WHERE IndustryName = N'Retail trade';
GO


/* ############################################################################
   E5 - 3NF : PERSON tablosunda geçişli bağımlılık (eğitim adı -> eğitim seviyesi)
   ############################################################################
   ÖNCE : E5_ONCE_PERSON(PersonID PK, Age, EducationName, EducationLevel)
   FB   : PersonID       -> Age, EducationName
          EducationName  -> EducationLevel     (ör. 'Bachelors degree(BA AB BS)' her zaman 13)
          EducationLevel -> EducationName      (17 ad <-> 17 seviye, birebir)
          Dolayısıyla PersonID -> EducationName -> EducationLevel  (geçişli)
   İHLAL: 3NF
   ANOMALİ:
     - Güncelleme: seviye ölçeği değişirse (ör. 'Masters' 14 -> 15) o eğitime sahip herkes güncellenmeli;
                   bir satır atlanırsa aynı eğitim iki farklı seviyeyle görünür.
     - Ekleme   : örnekte doktoralı kimse yok; 'Doctorate degree(PhD EdD) = 16' bilgisi bir kişi
                  eklenmeden kaydedilemez.
     - Silme    : '7th and 8th grade' eğitimli tek kişi (PersonID 24) silinirse
                  "7th and 8th grade = 4" bilgisi de kaybolur.
   AYRIŞTIRMA: EducationName ve EducationLevel ayrı EDUCATION tablosuna taşınır, PERSON yalnızca FK tutar.
   SONRA: E5_SONRA_EDUCATION(EducationID PK, EducationName UQ, EducationLevel UQ)
          E5_SONRA_PERSON(PersonID PK, Age, EducationID FK)
   ############################################################################ */
CREATE TABLE norm.E5_ONCE_PERSON (
    PersonID       INT          NOT NULL PRIMARY KEY,
    Age            TINYINT      NOT NULL,
    EducationName  NVARCHAR(60) NOT NULL,
    EducationLevel TINYINT      NOT NULL
);

INSERT INTO norm.E5_ONCE_PERSON
SELECT p.PersonID, p.Age, e.EducationName, e.EducationLevel
FROM dbo.PERSON p JOIN dbo.EDUCATION e ON e.EducationID = p.EducationID;

SELECT * FROM norm.E5_ONCE_PERSON ORDER BY EducationLevel, PersonID;   -- [EKRAN GÖRÜNTÜSÜ] öncesi

-- Ayrıştırma
CREATE TABLE norm.E5_SONRA_EDUCATION (
    EducationID    INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    EducationName  NVARCHAR(60) NOT NULL UNIQUE,
    EducationLevel TINYINT      NOT NULL CHECK (EducationLevel BETWEEN 0 AND 16) UNIQUE
);
CREATE TABLE norm.E5_SONRA_PERSON (
    PersonID    INT     NOT NULL PRIMARY KEY,
    Age         TINYINT NOT NULL,
    EducationID INT     NOT NULL REFERENCES norm.E5_SONRA_EDUCATION (EducationID)
);

INSERT INTO norm.E5_SONRA_EDUCATION (EducationName, EducationLevel)
SELECT DISTINCT EducationName, EducationLevel FROM norm.E5_ONCE_PERSON;
INSERT INTO norm.E5_SONRA_PERSON (PersonID, Age, EducationID)
SELECT o.PersonID, o.Age, e.EducationID
FROM norm.E5_ONCE_PERSON o JOIN norm.E5_SONRA_EDUCATION e ON e.EducationName = o.EducationName;

-- Ekleme anomalisi giderildi: kişi olmadan yeni eğitim düzeyi eklenebilir
IF NOT EXISTS (SELECT 1 FROM norm.E5_SONRA_EDUCATION WHERE EducationLevel = 16)
    INSERT INTO norm.E5_SONRA_EDUCATION (EducationName, EducationLevel)
    VALUES (N'Doctorate degree(PhD EdD)', 16);

SELECT * FROM norm.E5_SONRA_EDUCATION ORDER BY EducationLevel;   -- [EKRAN GÖRÜNTÜSÜ] sonrası
SELECT * FROM norm.E5_SONRA_PERSON;
GO


/* ############################################################################
   E6 - BCNF : Anahtar olmayan belirleyen (ModelID -> Algorithm)
   ############################################################################
   İş kuralı: Her kayıt, her algoritma için en fazla bir kez puanlanır (o algoritmanın aktif modeliyle);
              her model tek bir algoritmaya aittir.
   ÖNCE : E6_ONCE_MODEL_SCORE(RecordID, Algorithm, ModelID, PredictedProbability)
          Aday anahtarlar: {RecordID, Algorithm}  ve  {RecordID, ModelID}
   FB   : RecordID, Algorithm -> ModelID, PredictedProbability
          RecordID, ModelID   -> Algorithm, PredictedProbability
          ModelID             -> Algorithm
   NORMAL FORM: Tüm sütunlar ya anahtar parçası (asal) ya da tam anahtara bağlı -> 1NF, 2NF ve 3NF
          SAĞLANIR (ModelID -> Algorithm bağımlılığında Algorithm asal özniteliktir).
   İHLAL: BCNF - ModelID bir belirleyen (determinant) ama süper anahtar değil.
   ANOMALİ:
     - Güncelleme: algoritma adı modelin her tahmininde tekrar eder; birinde değişirse aynı model iki
                   algoritmaya ait görünür (aşağıda gösterilmiştir).
     - Ekleme   : henüz tahmin üretmemiş bir modelin hangi algoritmaya ait olduğu kaydedilemez.
     - Silme    : bir modelin son tahmini silinince modelin algoritma bilgisi de kaybolur.
   AYRIŞTIRMA: İhlal eden bağımlılık (ModelID -> Algorithm) ayrı tabloya taşınır:
               R1(ModelID, Algorithm), R2(RecordID, ModelID, PredictedProbability).
               Ortak sütun ModelID, R1'in anahtarı olduğundan ayrıştırma kayıpsızdır.
   NOT : {RecordID, Algorithm} -> ModelID bağımlılığı tek bir tabloda korunamaz (BCNF'in bilinen
         bedeli). Bu kural ileride (Adım 6) bir trigger ile denetlenecektir.
   SONRA: E6_SONRA_ML_MODEL(ModelID PK, Algorithm)
          E6_SONRA_PREDICTION(RecordID, ModelID FK, PredictedProbability)  PK (RecordID, ModelID)
   ############################################################################ */
CREATE TABLE norm.E6_ONCE_MODEL_SCORE (
    RecordID             INT          NOT NULL,
    Algorithm            NVARCHAR(50) NOT NULL,
    ModelID              INT          NOT NULL,
    PredictedProbability DECIMAL(5,4) NOT NULL,
    PRIMARY KEY (RecordID, Algorithm),
    UNIQUE (RecordID, ModelID)
);

INSERT INTO norm.E6_ONCE_MODEL_SCORE
SELECT p.RecordID, m.Algorithm, p.ModelID, p.PredictedProbability
FROM dbo.PREDICTION p JOIN dbo.ML_MODEL m ON m.ModelID = p.ModelID;

SELECT * FROM norm.E6_ONCE_MODEL_SCORE ORDER BY RecordID, Algorithm;   -- [EKRAN GÖRÜNTÜSÜ] öncesi

-- Güncelleme anomalisinin gösterimi (geri alınır): PK ihlal edilmeden tutarsızlık oluşur
BEGIN TRANSACTION;
    UPDATE norm.E6_ONCE_MODEL_SCORE SET Algorithm = N'LogisticRegression(liblinear)'
    WHERE ModelID = 1 AND RecordID = (SELECT MIN(RecordID) FROM norm.E6_ONCE_MODEL_SCORE WHERE ModelID = 1);

    -- Aynı model iki farklı algoritmaya ait görünüyor                [EKRAN GÖRÜNTÜSÜ]
    SELECT ModelID, Algorithm, COUNT(*) AS SatirSayisi
    FROM norm.E6_ONCE_MODEL_SCORE GROUP BY ModelID, Algorithm ORDER BY ModelID;
ROLLBACK;

-- Ayrıştırma
CREATE TABLE norm.E6_SONRA_ML_MODEL (
    ModelID   INT          NOT NULL PRIMARY KEY,
    Algorithm NVARCHAR(50) NOT NULL
);
CREATE TABLE norm.E6_SONRA_PREDICTION (
    RecordID             INT          NOT NULL,
    ModelID              INT          NOT NULL REFERENCES norm.E6_SONRA_ML_MODEL (ModelID),
    PredictedProbability DECIMAL(5,4) NOT NULL,
    PRIMARY KEY (RecordID, ModelID)
);

INSERT INTO norm.E6_SONRA_ML_MODEL SELECT DISTINCT ModelID, Algorithm FROM norm.E6_ONCE_MODEL_SCORE;
INSERT INTO norm.E6_SONRA_PREDICTION SELECT RecordID, ModelID, PredictedProbability FROM norm.E6_ONCE_MODEL_SCORE;

SELECT * FROM norm.E6_SONRA_ML_MODEL;                     -- [EKRAN GÖRÜNTÜSÜ] sonrası
SELECT * FROM norm.E6_SONRA_PREDICTION ORDER BY RecordID, ModelID;
GO

PRINT N'Normalizasyon örnekleri (E1-E6) oluşturuldu.';
