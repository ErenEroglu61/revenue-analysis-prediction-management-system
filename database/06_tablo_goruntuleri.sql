/* ============================================================================
   06 - Veri girişi sonrası tablo görüntüleri (rapor bölüm c için ekran görüntüleri)
   SSMS'te istediğiniz SELECT'i seçip F5 ile çalıştırın; sonuç penceresinin
   ekran görüntüsünü alın.
   ============================================================================ */
USE GelirAnalizDB;
GO

/* ---- 1) Tablo başına kayıt sayıları (tek ekran görüntüsünde özet) ---- */
SELECT t.name AS Tablo, SUM(p.rows) AS KayitSayisi
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE SCHEMA_NAME(t.schema_id) = 'dbo'
GROUP BY t.name
ORDER BY t.name;

/* ---- 1b) Tablo yapısı: sütun, veri tipi, NULL, PK/FK ve referans verilen tablo (rapor bölüm b) ----
   WHERE satırındaki tablo adını değiştirerek her tablo için ayrı görüntü alınabilir. */
SELECT c.TABLE_NAME AS Tablo, c.COLUMN_NAME AS Sutun,
       c.DATA_TYPE + CASE WHEN c.CHARACTER_MAXIMUM_LENGTH = -1 THEN '(MAX)'
                          WHEN c.CHARACTER_MAXIMUM_LENGTH IS NOT NULL THEN '(' + CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR) + ')'
                          WHEN c.DATA_TYPE = 'decimal' THEN '(' + CAST(c.NUMERIC_PRECISION AS VARCHAR) + ',' + CAST(c.NUMERIC_SCALE AS VARCHAR) + ')'
                          ELSE '' END AS VeriTipi,
       c.IS_NULLABLE AS NullOlabilir,
       CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 'PK' ELSE '' END
         + CASE WHEN fk.ReferencedTable IS NOT NULL THEN CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN ', ' ELSE '' END + 'FK' ELSE '' END AS Anahtar,
       fk.ReferencedTable AS ReferansTablo
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN (SELECT ku.TABLE_NAME, ku.COLUMN_NAME
           FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
           JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku ON ku.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
           WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY') pk
       ON pk.TABLE_NAME = c.TABLE_NAME AND pk.COLUMN_NAME = c.COLUMN_NAME
LEFT JOIN (SELECT OBJECT_NAME(f.parent_object_id) AS TableName,
                  COL_NAME(f.parent_object_id, f.parent_column_id) AS ColumnName,
                  OBJECT_NAME(f.referenced_object_id) AS ReferencedTable
           FROM sys.foreign_key_columns f) fk
       ON fk.TableName = c.TABLE_NAME AND fk.ColumnName = c.COLUMN_NAME
WHERE c.TABLE_SCHEMA = 'dbo'
  -- AND c.TABLE_NAME = 'PERSON'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

/* ---- 2) Ana tablolar ---- */
SELECT * FROM PERSON;
SELECT * FROM SURVEY_RECORD;
SELECT * FROM EMPLOYMENT;
SELECT * FROM FINANCE;
SELECT * FROM HOUSEHOLD;
SELECT * FROM RESIDENCE;
SELECT * FROM MIGRATION;          -- yalnızca 1994 kişileri (1:0..1 ilişki)

/* ---- 3) ML tabloları ---- */
SELECT * FROM ML_MODEL;
SELECT * FROM MODEL_METRIC;
SELECT * FROM PREDICTION;

/* ---- 4) Lookup tabloları ---- */
SELECT * FROM SEX;
SELECT * FROM RACE;
SELECT * FROM HISPANIC_ORIGIN;
SELECT * FROM MARITAL_STATUS;
SELECT * FROM EDUCATION ORDER BY EducationLevel;
SELECT * FROM EDU_ENROLLMENT;
SELECT * FROM CITIZENSHIP;
SELECT * FROM COUNTRY;
SELECT * FROM ANSWER;
SELECT * FROM CLASS_OF_WORKER;
SELECT * FROM MAJOR_INDUSTRY;
SELECT * FROM INDUSTRY;
SELECT * FROM MAJOR_OCCUPATION;
SELECT * FROM OCCUPATION;
SELECT * FROM EMPLOYMENT_STATUS;
SELECT * FROM UNEMPLOYMENT_REASON;
SELECT * FROM TAX_FILER_STATUS;
SELECT * FROM HOUSEHOLD_DETAIL;
SELECT * FROM HOUSEHOLD_SUMMARY;
SELECT * FROM FAMILY_UNDER_18;
SELECT * FROM REGION;
SELECT * FROM STATE;
SELECT * FROM MSA_CHANGE;
SELECT * FROM REGION_CHANGE;
SELECT * FROM WITHIN_REGION_MOVE;

/* ---- 5) Okunabilir birleşik görünüm: ID'ler yerine adlar (ilişkilerin çalıştığını gösterir) ---- */
SELECT p.PersonID, p.Age, s.SexName, e.EducationName, ms.StatusName AS MaritalStatus,
       c.CountryName AS BirthCountry, cw.ClassName AS ClassOfWorker,
       mi.IndustryName AS MajorIndustry, mo.OccupationName AS MajorOccupation,
       em.WeeksWorkedInYear, sr.SurveyYear, sr.DataSplit, sr.IncomeOver50K
FROM PERSON p
JOIN SEX s               ON s.SexID = p.SexID
JOIN EDUCATION e         ON e.EducationID = p.EducationID
JOIN MARITAL_STATUS ms   ON ms.MaritalStatusID = p.MaritalStatusID
LEFT JOIN COUNTRY c      ON c.CountryID = p.BirthCountryID
JOIN EMPLOYMENT em       ON em.PersonID = p.PersonID
JOIN CLASS_OF_WORKER cw  ON cw.ClassOfWorkerID = em.ClassOfWorkerID
JOIN INDUSTRY i          ON i.IndustryCode = em.IndustryCode
JOIN MAJOR_INDUSTRY mi   ON mi.MajorIndustryID = i.MajorIndustryID
JOIN OCCUPATION o        ON o.OccupationCode = em.OccupationCode
JOIN MAJOR_OCCUPATION mo ON mo.MajorOccupationID = o.MajorOccupationID
JOIN SURVEY_RECORD sr    ON sr.PersonID = p.PersonID
ORDER BY p.PersonID;

/* ---- 6) Tahmin ile gerçek değerin karşılaştırması (ML tablolarının ilişkisi) ---- */
SELECT m.ModelName, pr.RecordID, sr.IncomeOver50K AS Gercek, pr.PredictedLabel AS Tahmin,
       pr.PredictedProbability AS Olasilik,
       CASE WHEN sr.IncomeOver50K = pr.PredictedLabel THEN 'Doğru' ELSE 'Yanlış' END AS Sonuc
FROM PREDICTION pr
JOIN ML_MODEL m       ON m.ModelID = pr.ModelID
JOIN SURVEY_RECORD sr ON sr.RecordID = pr.RecordID
ORDER BY m.ModelName, pr.RecordID;

/* ---- 7) Kısıtların çalıştığının gösterimi (hepsi HATA vermelidir) ---- */
-- INSERT INTO PERSON (Age, SexID, RaceID, HispanicOriginID, MaritalStatusID, EducationID, EduEnrollmentID,
--                     CitizenshipID, VetQuestionnaireAnswerID, VeteransBenefits)
-- VALUES (30, 99, 1, 1, 1, 1, 1, 1, 1, 0);            -- FK hatası: SexID = 99 yok
-- UPDATE EMPLOYMENT SET WeeksWorkedInYear = 60 WHERE PersonID = 1;   -- CHECK hatası (0-52)
-- INSERT INTO SURVEY_RECORD (PersonID, SurveyYear, DataSplit, InstanceWeight, IncomeOver50K)
-- VALUES (1, 1994, 'train', 1000, 0);                 -- UNIQUE hatası: kişinin zaten kaydı var
