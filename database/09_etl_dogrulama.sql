/* ============================================================================
   09 - ETL / Adım 3: Yükleme doğrulaması
   08 çalıştıktan sonra normalize tabloları staging (kaynak) ile karşılaştırır.
   Çıktı: her kontrol için Beklenen / Gerçekleşen / Sonuç (OK / HATA) tablosu.

   En güçlü kontrol #14-15: normalize tablolardan JOIN ile 42 sütunluk düz satır geri kurulur ve
   staging ile EXCEPT ile karşılaştırılır. İki yönde de 0 satır = ayrıştırma KAYIPSIZ.
   ============================================================================ */
USE GelirAnalizDB;
GO
SET NOCOUNT ON;

DROP TABLE IF EXISTS #Kontrol;
CREATE TABLE #Kontrol (
    No          INT IDENTITY(1,1),
    Kontrol     NVARCHAR(120),
    Beklenen    DECIMAL(18,2),
    Gerceklesen DECIMAL(18,2)
);

/* ---- Satır sayıları ---- */
INSERT INTO #Kontrol (Kontrol, Beklenen, Gerceklesen)
SELECT N'SURVEY_RECORD train satır sayısı',
       (SELECT COUNT(*) FROM stg.CENSUS_RAW WHERE DataSplit = 'train'),
       (SELECT COUNT(*) FROM dbo.SURVEY_RECORD WHERE DataSplit = 'train')
UNION ALL
SELECT N'SURVEY_RECORD test satır sayısı',
       (SELECT COUNT(*) FROM stg.CENSUS_RAW WHERE DataSplit = 'test'),
       (SELECT COUNT(*) FROM dbo.SURVEY_RECORD WHERE DataSplit = 'test')
UNION ALL
SELECT N'PERSON satır sayısı',      (SELECT COUNT(*) FROM stg.CENSUS_RAW), (SELECT COUNT(*) FROM dbo.PERSON)
UNION ALL
SELECT N'EMPLOYMENT satır sayısı',  (SELECT COUNT(*) FROM stg.CENSUS_RAW), (SELECT COUNT(*) FROM dbo.EMPLOYMENT)
UNION ALL
SELECT N'FINANCE satır sayısı',     (SELECT COUNT(*) FROM stg.CENSUS_RAW), (SELECT COUNT(*) FROM dbo.FINANCE)
UNION ALL
SELECT N'HOUSEHOLD satır sayısı',   (SELECT COUNT(*) FROM stg.CENSUS_RAW), (SELECT COUNT(*) FROM dbo.HOUSEHOLD)
UNION ALL
SELECT N'RESIDENCE satır sayısı',   (SELECT COUNT(*) FROM stg.CENSUS_RAW), (SELECT COUNT(*) FROM dbo.RESIDENCE)
UNION ALL
SELECT N'MIGRATION satır sayısı (= 1994 kayıtları)',
       (SELECT COUNT(*) FROM stg.CENSUS_RAW WHERE year = '94'), (SELECT COUNT(*) FROM dbo.MIGRATION)
UNION ALL
SELECT N'1995 kaydı olup MIGRATION satırı olan kişi (0 olmalı)', 0,
       (SELECT COUNT(*) FROM dbo.MIGRATION m JOIN dbo.SURVEY_RECORD r ON r.PersonID = m.PersonID
        WHERE r.SurveyYear = 1995)
UNION ALL
SELECT N'1:1 tablolarından en az birinde satırı eksik kişi (0 olmalı)', 0,
       (SELECT COUNT(*) FROM dbo.PERSON p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.SURVEY_RECORD x WHERE x.PersonID = p.PersonID)
           OR NOT EXISTS (SELECT 1 FROM dbo.EMPLOYMENT    x WHERE x.PersonID = p.PersonID)
           OR NOT EXISTS (SELECT 1 FROM dbo.FINANCE       x WHERE x.PersonID = p.PersonID)
           OR NOT EXISTS (SELECT 1 FROM dbo.HOUSEHOLD     x WHERE x.PersonID = p.PersonID)
           OR NOT EXISTS (SELECT 1 FROM dbo.RESIDENCE     x WHERE x.PersonID = p.PersonID));

/* ---- İçerik özetleri ---- */
INSERT INTO #Kontrol (Kontrol, Beklenen, Gerceklesen)
SELECT N'50K üstü kayıt sayısı',
       (SELECT COUNT(*) FROM stg.CENSUS_RAW WHERE income_over_50k = '1'),
       (SELECT COUNT(*) FROM dbo.SURVEY_RECORD WHERE IncomeOver50K = 1)
UNION ALL
SELECT N'Toplam InstanceWeight (nüfus)',
       (SELECT SUM(CONVERT(DECIMAL(18,2), instance_weight)) FROM stg.CENSUS_RAW),
       (SELECT SUM(CONVERT(DECIMAL(18,2), InstanceWeight)) FROM dbo.SURVEY_RECORD)
UNION ALL
SELECT N'Doğum ülkesi NULL (kişi + baba + anne)',
       (SELECT SUM(CASE WHEN country_of_birth_self   IS NULL THEN 1 ELSE 0 END
                 + CASE WHEN country_of_birth_father IS NULL THEN 1 ELSE 0 END
                 + CASE WHEN country_of_birth_mother IS NULL THEN 1 ELSE 0 END) FROM stg.CENSUS_RAW),
       (SELECT SUM(CASE WHEN BirthCountryID       IS NULL THEN 1 ELSE 0 END
                 + CASE WHEN FatherBirthCountryID IS NULL THEN 1 ELSE 0 END
                 + CASE WHEN MotherBirthCountryID IS NULL THEN 1 ELSE 0 END) FROM dbo.PERSON)
UNION ALL
SELECT N'Önceki eyalet NULL',
       (SELECT COUNT(*) FROM stg.CENSUS_RAW WHERE state_of_previous_residence IS NULL),
       (SELECT COUNT(*) FROM dbo.RESIDENCE WHERE PrevStateID IS NULL);

/* ---- Kayıpsız birleştirme (lossless join) kontrolü ----
   Staging satırı tiplenir; normalize tablolardan aynı satır JOIN ile geri kurulur. */
WITH Kaynak AS (
    SELECT s.StagingID, s.DataSplit,
           CONVERT(TINYINT, s.age) AS age, s.class_of_worker,
           CONVERT(TINYINT, s.detailed_industry_recode) AS ind_code,
           CONVERT(TINYINT, s.detailed_occupation_recode) AS occ_code,
           s.education, CONVERT(INT, s.wage_per_hour) AS wage, s.enroll_in_edu_inst_last_wk AS enroll,
           s.marital_stat, s.major_industry_code, s.major_occupation_code, s.race, s.hispanic_origin, s.sex,
           s.member_of_labor_union, s.reason_for_unemployment, s.full_or_part_time_employment_stat,
           CONVERT(INT, s.capital_gains) AS gains, CONVERT(INT, s.capital_losses) AS losses,
           CONVERT(INT, s.dividends_from_stocks) AS dividends, s.tax_filer_stat,
           s.region_of_previous_residence, s.state_of_previous_residence,
           s.detailed_household_and_family_stat, s.detailed_household_summary_in_household,
           CONVERT(DECIMAL(9,2), s.instance_weight) AS weight,
           s.migration_code_change_in_msa, s.migration_code_change_in_reg, s.migration_code_move_within_reg,
           s.live_in_this_house_1_year_ago, s.migration_prev_res_in_sunbelt,
           CONVERT(TINYINT, s.num_persons_worked_for_employer) AS num_persons, s.family_members_under_18,
           s.country_of_birth_father, s.country_of_birth_mother, s.country_of_birth_self, s.citizenship,
           CONVERT(TINYINT, s.own_business_or_self_employed) AS own_business,
           s.fill_inc_questionnaire_for_veterans_admin, CONVERT(TINYINT, s.veterans_benefits) AS vet_benefits,
           CONVERT(TINYINT, s.weeks_worked_in_year) AS weeks, 1900 + CONVERT(SMALLINT, s.year) AS survey_year,
           CONVERT(BIT, s.income_over_50k) AS income
    FROM stg.CENSUS_RAW s
),
GeriKurulan AS (
    SELECT p.PersonID, sr.DataSplit,
           p.Age, cw.ClassName, e.IndustryCode, e.OccupationCode,
           ed.EducationName, f.WagePerHour, en.EnrollmentName,
           ms.StatusName, mi.IndustryName, mo.OccupationName, r.RaceName, ho.OriginName, sx.SexName,
           lu.AnswerText, ur.ReasonName, es.StatusName AS EmpStatus,
           f.CapitalGains, f.CapitalLosses, f.DividendsFromStocks, tf.StatusName AS TaxStatus,
           rg.RegionName, st.StateName,
           hd.DetailName, hs.SummaryName,
           sr.InstanceWeight,
           mc.ChangeName AS MsaChange, rc.ChangeName AS RegChange, wm.MoveName,
           lh.AnswerText AS LivedHouse, sb.AnswerText AS Sunbelt,
           e.NumPersonsWorkedForEmp, fu.ParentsPresent,
           cf.CountryName AS Father, cm.CountryName AS Mother, cs.CountryName AS Self, ct.CitizenshipName,
           e.OwnBusinessSelfEmployed,
           va.AnswerText AS VetQ, p.VeteransBenefits,
           e.WeeksWorkedInYear, sr.SurveyYear,
           sr.IncomeOver50K
    FROM dbo.PERSON p
    JOIN dbo.SURVEY_RECORD       sr ON sr.PersonID = p.PersonID
    JOIN dbo.EMPLOYMENT          e  ON e.PersonID  = p.PersonID
    JOIN dbo.FINANCE             f  ON f.PersonID  = p.PersonID
    JOIN dbo.HOUSEHOLD           h  ON h.PersonID  = p.PersonID
    JOIN dbo.RESIDENCE           re ON re.PersonID = p.PersonID
    LEFT JOIN dbo.MIGRATION      m  ON m.PersonID  = p.PersonID
    JOIN dbo.SEX                 sx ON sx.SexID = p.SexID
    JOIN dbo.RACE                r  ON r.RaceID = p.RaceID
    JOIN dbo.HISPANIC_ORIGIN     ho ON ho.HispanicOriginID = p.HispanicOriginID
    JOIN dbo.MARITAL_STATUS      ms ON ms.MaritalStatusID = p.MaritalStatusID
    JOIN dbo.EDUCATION           ed ON ed.EducationID = p.EducationID
    JOIN dbo.EDU_ENROLLMENT      en ON en.EduEnrollmentID = p.EduEnrollmentID
    JOIN dbo.CITIZENSHIP         ct ON ct.CitizenshipID = p.CitizenshipID
    JOIN dbo.ANSWER              va ON va.AnswerID = p.VetQuestionnaireAnswerID
    LEFT JOIN dbo.COUNTRY        cs ON cs.CountryID = p.BirthCountryID
    LEFT JOIN dbo.COUNTRY        cf ON cf.CountryID = p.FatherBirthCountryID
    LEFT JOIN dbo.COUNTRY        cm ON cm.CountryID = p.MotherBirthCountryID
    JOIN dbo.CLASS_OF_WORKER     cw ON cw.ClassOfWorkerID = e.ClassOfWorkerID
    JOIN dbo.INDUSTRY            i  ON i.IndustryCode = e.IndustryCode
    JOIN dbo.MAJOR_INDUSTRY      mi ON mi.MajorIndustryID = i.MajorIndustryID
    JOIN dbo.OCCUPATION          o  ON o.OccupationCode = e.OccupationCode
    JOIN dbo.MAJOR_OCCUPATION    mo ON mo.MajorOccupationID = o.MajorOccupationID
    JOIN dbo.EMPLOYMENT_STATUS   es ON es.EmploymentStatusID = e.EmploymentStatusID
    JOIN dbo.UNEMPLOYMENT_REASON ur ON ur.UnemploymentReasonID = e.UnemploymentReasonID
    JOIN dbo.ANSWER              lu ON lu.AnswerID = e.LaborUnionAnswerID
    JOIN dbo.TAX_FILER_STATUS    tf ON tf.TaxFilerStatusID = f.TaxFilerStatusID
    JOIN dbo.HOUSEHOLD_DETAIL    hd ON hd.HouseholdDetailID = h.HouseholdDetailID
    JOIN dbo.HOUSEHOLD_SUMMARY   hs ON hs.HouseholdSummaryID = h.HouseholdSummaryID
    JOIN dbo.FAMILY_UNDER_18     fu ON fu.FamilyUnder18ID = h.FamilyUnder18ID
    JOIN dbo.ANSWER              lh ON lh.AnswerID = re.LivedInHouseAnswerID
    JOIN dbo.REGION              rg ON rg.RegionID = re.PrevRegionID
    LEFT JOIN dbo.STATE          st ON st.StateID = re.PrevStateID
    LEFT JOIN dbo.MSA_CHANGE     mc ON mc.MsaChangeID = m.MsaChangeID
    LEFT JOIN dbo.REGION_CHANGE  rc ON rc.RegionChangeID = m.RegionChangeID
    LEFT JOIN dbo.ANSWER         sb ON sb.AnswerID = m.SunbeltAnswerID
    LEFT JOIN dbo.WITHIN_REGION_MOVE wm ON wm.WithinRegionMoveID = m.WithinRegionMoveID
)
SELECT
    (SELECT COUNT(*) FROM (SELECT * FROM Kaynak EXCEPT SELECT * FROM GeriKurulan) x) AS KaynaktaOlupDBdeOlmayan,
    (SELECT COUNT(*) FROM (SELECT * FROM GeriKurulan EXCEPT SELECT * FROM Kaynak) x) AS DBdeOlupKaynaktaOlmayan
INTO #Kayipsiz;

INSERT INTO #Kontrol (Kontrol, Beklenen, Gerceklesen)
SELECT N'Kayıpsızlık: staging EXCEPT geri kurulan satır (0 olmalı)', 0, KaynaktaOlupDBdeOlmayan FROM #Kayipsiz
UNION ALL
SELECT N'Kayıpsızlık: geri kurulan EXCEPT staging satır (0 olmalı)', 0, DBdeOlupKaynaktaOlmayan FROM #Kayipsiz;

/* ---- Sonuç ---- */
SELECT No, Kontrol, Beklenen, Gerceklesen,
       CASE WHEN Beklenen = Gerceklesen THEN 'OK' ELSE 'HATA' END AS Sonuc
FROM #Kontrol
ORDER BY No;

-- Bilgi amaçlı: veri bölümüne ve yıla göre özet (EDA'daki oranlarla karşılaştırılabilir)
SELECT sr.DataSplit, sr.SurveyYear,
       COUNT(*)                                                    AS KayitSayisi,
       SUM(CONVERT(INT, sr.IncomeOver50K))                         AS Ust50K,
       CAST(100.0 * AVG(CONVERT(FLOAT, sr.IncomeOver50K)) AS DECIMAL(5,2)) AS Ust50K_Yuzde,
       CAST(100.0 * SUM(sr.InstanceWeight * sr.IncomeOver50K) / SUM(sr.InstanceWeight) AS DECIMAL(5,2))
                                                                   AS Ust50K_AgirlikliYuzde
FROM dbo.SURVEY_RECORD sr
GROUP BY sr.DataSplit, sr.SurveyYear
ORDER BY sr.DataSplit DESC, sr.SurveyYear;
GO
