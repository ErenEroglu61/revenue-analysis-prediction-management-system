/* ============================================================================
   08 - ETL / Adım 2: Staging -> normalize tablolar (Transform + Load)

   Ön koşul: 01-03 çalışmış olmalı (tablolar + lookup verileri) ve stg.CENSUS_RAW dolu olmalı
             (07 + python database/kaynak/etl_yukle.py).

   Yapılanlar:
     0) Kalite kontrolü: tip dönüşümü yapılamayan / zorunlu alanı boş satır varsa durur.
     1) Ana tablolardaki ve ML tablolarındaki mevcut veriler (04'teki 24 örnek kişi ve örnek modeller)
        silinir. Script tekrar tekrar çalıştırılabilir (idempotent).
     2) Lookup'larda olmayan yeni kategori değerleri eklenir (ID = mevcut en büyük ID + sıra).
        EDUCATION yeni değer kabul etmez (seviyesi bilinmez). INDUSTRY/OCCUPATION için
        "detay kod -> üst grup" fonksiyonel bağımlılığı kontrol edilir.
     3) PERSON, SURVEY_RECORD, EMPLOYMENT, FINANCE, HOUSEHOLD, RESIDENCE, MIGRATION tabloları
        INSERT ... SELECT + JOIN (metin -> lookup ID) ile doldurulur.
        PersonID = RecordID = StagingID: her satır kaynağına kadar izlenebilir.
     4) Her adımda eklenen satır sayısı beklenenle karşılaştırılır; uyuşmazsa her şey geri alınır.

   Tamamı tek transaction'dır (XACT_ABORT + TRY...CATCH): ya hepsi yüklenir ya hiçbiri.
   ============================================================================ */
USE GelirAnalizDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Toplam INT, @Toplam94 INT, @n INT, @msg NVARCHAR(2048);
DECLARE @Basla DATETIME2 = SYSDATETIME();
DECLARE @YeniLookup TABLE (Tablo SYSNAME, Deger NVARCHAR(60));

SELECT @Toplam = COUNT(*), @Toplam94 = SUM(CASE WHEN year = '94' THEN 1 ELSE 0 END)
FROM stg.CENSUS_RAW;

IF @Toplam = 0
    THROW 50001, N'stg.CENSUS_RAW boş. Önce: python database/kaynak/etl_yukle.py', 1;

/* ---------------------------------------------------------------------------
   0) Veri kalitesi kontrolü (ana tablolara dokunmadan önce)
   --------------------------------------------------------------------------- */
SELECT StagingID, DataSplit, SourceRowNo
INTO #HataliSatir
FROM stg.CENSUS_RAW
WHERE DataSplit NOT IN ('train', 'test')
   OR TRY_CONVERT(TINYINT, age)                             IS NULL
   OR TRY_CONVERT(TINYINT, detailed_industry_recode)        IS NULL
   OR TRY_CONVERT(TINYINT, detailed_occupation_recode)      IS NULL
   OR TRY_CONVERT(INT, wage_per_hour)                       IS NULL
   OR TRY_CONVERT(INT, capital_gains)                       IS NULL
   OR TRY_CONVERT(INT, capital_losses)                      IS NULL
   OR TRY_CONVERT(INT, dividends_from_stocks)               IS NULL
   OR TRY_CONVERT(DECIMAL(9,2), instance_weight)            IS NULL
   OR TRY_CONVERT(TINYINT, num_persons_worked_for_employer) IS NULL
   OR TRY_CONVERT(TINYINT, own_business_or_self_employed)   IS NULL
   OR TRY_CONVERT(TINYINT, veterans_benefits)               IS NULL
   OR TRY_CONVERT(TINYINT, weeks_worked_in_year)            IS NULL
   OR year            NOT IN ('94', '95') OR year IS NULL
   OR income_over_50k NOT IN ('0', '1')   OR income_over_50k IS NULL
   -- Zorunlu (NOT NULL) kategorik alanlar
   OR sex IS NULL OR race IS NULL OR hispanic_origin IS NULL OR marital_stat IS NULL
   OR education IS NULL OR enroll_in_edu_inst_last_wk IS NULL OR citizenship IS NULL
   OR fill_inc_questionnaire_for_veterans_admin IS NULL OR class_of_worker IS NULL
   OR major_industry_code IS NULL OR major_occupation_code IS NULL
   OR full_or_part_time_employment_stat IS NULL OR reason_for_unemployment IS NULL
   OR member_of_labor_union IS NULL OR tax_filer_stat IS NULL
   OR detailed_household_and_family_stat IS NULL OR detailed_household_summary_in_household IS NULL
   OR family_members_under_18 IS NULL OR live_in_this_house_1_year_ago IS NULL
   OR region_of_previous_residence IS NULL
   -- 1994 kayıtlarında göç bilgisi zorunlu
   OR (year = '94' AND (migration_code_change_in_msa IS NULL OR migration_code_change_in_reg IS NULL
                        OR migration_code_move_within_reg IS NULL OR migration_prev_res_in_sunbelt IS NULL));

IF EXISTS (SELECT 1 FROM #HataliSatir)
BEGIN
    SELECT TOP (20) * FROM #HataliSatir ORDER BY StagingID;
    SELECT @n = COUNT(*) FROM #HataliSatir;
    SET @msg = CONCAT(N'Kalite kontrolü başarısız: ', @n, N' satır dönüştürülemiyor. Hiçbir tablo değiştirilmedi.');
    THROW 50002, @msg, 1;
END

-- EDUCATION sıralı seviye taşır; bilinmeyen bir eğitim değeri otomatik eklenemez
IF EXISTS (SELECT 1 FROM stg.CENSUS_RAW s
           WHERE NOT EXISTS (SELECT 1 FROM dbo.EDUCATION e WHERE e.EducationName = s.education))
    THROW 50003, N'EDUCATION tablosunda olmayan bir eğitim değeri var (seviyesi elle tanımlanmalı).', 1;

-- Fonksiyonel bağımlılık: detay kod -> tek bir üst grup
IF EXISTS (SELECT 1 FROM stg.CENSUS_RAW GROUP BY detailed_industry_recode
           HAVING COUNT(DISTINCT major_industry_code) > 1)
    THROW 50004, N'detailed_industry_recode -> major_industry_code bağımlılığı staging verisinde bozuk.', 1;
IF EXISTS (SELECT 1 FROM stg.CENSUS_RAW GROUP BY detailed_occupation_recode
           HAVING COUNT(DISTINCT major_occupation_code) > 1)
    THROW 50005, N'detailed_occupation_recode -> major_occupation_code bağımlılığı staging verisinde bozuk.', 1;

PRINT CONCAT(N'[0] Kalite kontrolü geçti: ', @Toplam, N' satır (', @Toplam94, N' tanesi 1994).');

BEGIN TRY
    BEGIN TRANSACTION;

    /* -----------------------------------------------------------------------
       1) Eski verileri temizle (çocuktan ebeveyne doğru)
       ----------------------------------------------------------------------- */
    DELETE FROM dbo.PREDICTION;
    DELETE FROM dbo.MODEL_METRIC;
    DELETE FROM dbo.ML_MODEL;
    DELETE FROM dbo.MIGRATION;
    DELETE FROM dbo.RESIDENCE;
    DELETE FROM dbo.HOUSEHOLD;
    DELETE FROM dbo.FINANCE;
    DELETE FROM dbo.EMPLOYMENT;
    DELETE FROM dbo.SURVEY_RECORD;
    DELETE FROM dbo.PERSON;
    -- ML tabloları ID'leri 1'den başlasın (ML adımı kendi modellerini yazacak)
    DBCC CHECKIDENT ('dbo.ML_MODEL',     RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.MODEL_METRIC', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.PREDICTION',   RESEED, 0) WITH NO_INFOMSGS;
    PRINT N'[1] Ana ve ML tablolarındaki eski veriler silindi.';

    /* -----------------------------------------------------------------------
       2) Lookup tablolarına yalnızca YENİ değerleri ekle
          Kalıp: ID = MAX(ID) + ROW_NUMBER(), NOT EXISTS ile tekrar engellenir.
          03 tüm veri setinden üretildiği için normalde hiçbir satır eklenmez.
       ----------------------------------------------------------------------- */
    INSERT INTO dbo.SEX (SexID, SexName) OUTPUT N'SEX', inserted.SexName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(SexID) FROM dbo.SEX), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT sex AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.SEX t WHERE t.SexName = v.Deger);

    INSERT INTO dbo.RACE (RaceID, RaceName) OUTPUT N'RACE', inserted.RaceName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(RaceID) FROM dbo.RACE), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT race AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.RACE t WHERE t.RaceName = v.Deger);

    INSERT INTO dbo.HISPANIC_ORIGIN (HispanicOriginID, OriginName) OUTPUT N'HISPANIC_ORIGIN', inserted.OriginName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(HispanicOriginID) FROM dbo.HISPANIC_ORIGIN), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT hispanic_origin AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.HISPANIC_ORIGIN t WHERE t.OriginName = v.Deger);

    INSERT INTO dbo.MARITAL_STATUS (MaritalStatusID, StatusName) OUTPUT N'MARITAL_STATUS', inserted.StatusName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(MaritalStatusID) FROM dbo.MARITAL_STATUS), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT marital_stat AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MARITAL_STATUS t WHERE t.StatusName = v.Deger);

    INSERT INTO dbo.EDU_ENROLLMENT (EduEnrollmentID, EnrollmentName) OUTPUT N'EDU_ENROLLMENT', inserted.EnrollmentName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(EduEnrollmentID) FROM dbo.EDU_ENROLLMENT), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT enroll_in_edu_inst_last_wk AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.EDU_ENROLLMENT t WHERE t.EnrollmentName = v.Deger);

    INSERT INTO dbo.CITIZENSHIP (CitizenshipID, CitizenshipName) OUTPUT N'CITIZENSHIP', inserted.CitizenshipName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(CitizenshipID) FROM dbo.CITIZENSHIP), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT citizenship AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CITIZENSHIP t WHERE t.CitizenshipName = v.Deger);

    -- COUNTRY: 3 sütunun (kişi / baba / anne doğum ülkesi) birleşimi
    INSERT INTO dbo.COUNTRY (CountryID, CountryName) OUTPUT N'COUNTRY', inserted.CountryName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(CountryID) FROM dbo.COUNTRY), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT country_of_birth_self   AS Deger FROM stg.CENSUS_RAW UNION
          SELECT country_of_birth_father          FROM stg.CENSUS_RAW UNION
          SELECT country_of_birth_mother          FROM stg.CENSUS_RAW) v
    WHERE v.Deger IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.COUNTRY t WHERE t.CountryName = v.Deger);

    -- ANSWER: 4 evet/hayır sütununun birleşimi
    INSERT INTO dbo.ANSWER (AnswerID, AnswerText) OUTPUT N'ANSWER', inserted.AnswerText INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(AnswerID) FROM dbo.ANSWER), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT member_of_labor_union                     AS Deger FROM stg.CENSUS_RAW UNION
          SELECT fill_inc_questionnaire_for_veterans_admin          FROM stg.CENSUS_RAW UNION
          SELECT live_in_this_house_1_year_ago                      FROM stg.CENSUS_RAW UNION
          SELECT migration_prev_res_in_sunbelt                      FROM stg.CENSUS_RAW) v
    WHERE v.Deger IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.ANSWER t WHERE t.AnswerText = v.Deger);

    INSERT INTO dbo.CLASS_OF_WORKER (ClassOfWorkerID, ClassName) OUTPUT N'CLASS_OF_WORKER', inserted.ClassName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(ClassOfWorkerID) FROM dbo.CLASS_OF_WORKER), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT class_of_worker AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CLASS_OF_WORKER t WHERE t.ClassName = v.Deger);

    INSERT INTO dbo.MAJOR_INDUSTRY (MajorIndustryID, IndustryName) OUTPUT N'MAJOR_INDUSTRY', inserted.IndustryName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(MajorIndustryID) FROM dbo.MAJOR_INDUSTRY), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT major_industry_code AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MAJOR_INDUSTRY t WHERE t.IndustryName = v.Deger);

    INSERT INTO dbo.MAJOR_OCCUPATION (MajorOccupationID, OccupationName) OUTPUT N'MAJOR_OCCUPATION', inserted.OccupationName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(MajorOccupationID) FROM dbo.MAJOR_OCCUPATION), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT major_occupation_code AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MAJOR_OCCUPATION t WHERE t.OccupationName = v.Deger);

    INSERT INTO dbo.EMPLOYMENT_STATUS (EmploymentStatusID, StatusName) OUTPUT N'EMPLOYMENT_STATUS', inserted.StatusName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(EmploymentStatusID) FROM dbo.EMPLOYMENT_STATUS), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT full_or_part_time_employment_stat AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.EMPLOYMENT_STATUS t WHERE t.StatusName = v.Deger);

    INSERT INTO dbo.UNEMPLOYMENT_REASON (UnemploymentReasonID, ReasonName) OUTPUT N'UNEMPLOYMENT_REASON', inserted.ReasonName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(UnemploymentReasonID) FROM dbo.UNEMPLOYMENT_REASON), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT reason_for_unemployment AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UNEMPLOYMENT_REASON t WHERE t.ReasonName = v.Deger);

    INSERT INTO dbo.TAX_FILER_STATUS (TaxFilerStatusID, StatusName) OUTPUT N'TAX_FILER_STATUS', inserted.StatusName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(TaxFilerStatusID) FROM dbo.TAX_FILER_STATUS), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT tax_filer_stat AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TAX_FILER_STATUS t WHERE t.StatusName = v.Deger);

    INSERT INTO dbo.HOUSEHOLD_DETAIL (HouseholdDetailID, DetailName) OUTPUT N'HOUSEHOLD_DETAIL', inserted.DetailName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(HouseholdDetailID) FROM dbo.HOUSEHOLD_DETAIL), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT detailed_household_and_family_stat AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.HOUSEHOLD_DETAIL t WHERE t.DetailName = v.Deger);

    INSERT INTO dbo.HOUSEHOLD_SUMMARY (HouseholdSummaryID, SummaryName) OUTPUT N'HOUSEHOLD_SUMMARY', inserted.SummaryName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(HouseholdSummaryID) FROM dbo.HOUSEHOLD_SUMMARY), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT detailed_household_summary_in_household AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.HOUSEHOLD_SUMMARY t WHERE t.SummaryName = v.Deger);

    INSERT INTO dbo.FAMILY_UNDER_18 (FamilyUnder18ID, ParentsPresent) OUTPUT N'FAMILY_UNDER_18', inserted.ParentsPresent INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(FamilyUnder18ID) FROM dbo.FAMILY_UNDER_18), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT family_members_under_18 AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.FAMILY_UNDER_18 t WHERE t.ParentsPresent = v.Deger);

    INSERT INTO dbo.REGION (RegionID, RegionName) OUTPUT N'REGION', inserted.RegionName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(RegionID) FROM dbo.REGION), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT region_of_previous_residence AS Deger FROM stg.CENSUS_RAW) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.REGION t WHERE t.RegionName = v.Deger);

    INSERT INTO dbo.STATE (StateID, StateName) OUTPUT N'STATE', inserted.StateName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(StateID) FROM dbo.STATE), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT state_of_previous_residence AS Deger FROM stg.CENSUS_RAW
          WHERE state_of_previous_residence IS NOT NULL) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.STATE t WHERE t.StateName = v.Deger);

    INSERT INTO dbo.MSA_CHANGE (MsaChangeID, ChangeName) OUTPUT N'MSA_CHANGE', inserted.ChangeName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(MsaChangeID) FROM dbo.MSA_CHANGE), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT migration_code_change_in_msa AS Deger FROM stg.CENSUS_RAW
          WHERE migration_code_change_in_msa IS NOT NULL) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MSA_CHANGE t WHERE t.ChangeName = v.Deger);

    INSERT INTO dbo.REGION_CHANGE (RegionChangeID, ChangeName) OUTPUT N'REGION_CHANGE', inserted.ChangeName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(RegionChangeID) FROM dbo.REGION_CHANGE), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT migration_code_change_in_reg AS Deger FROM stg.CENSUS_RAW
          WHERE migration_code_change_in_reg IS NOT NULL) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.REGION_CHANGE t WHERE t.ChangeName = v.Deger);

    INSERT INTO dbo.WITHIN_REGION_MOVE (WithinRegionMoveID, MoveName) OUTPUT N'WITHIN_REGION_MOVE', inserted.MoveName INTO @YeniLookup
    SELECT ISNULL((SELECT MAX(WithinRegionMoveID) FROM dbo.WITHIN_REGION_MOVE), 0) + ROW_NUMBER() OVER (ORDER BY v.Deger), v.Deger
    FROM (SELECT DISTINCT migration_code_move_within_reg AS Deger FROM stg.CENSUS_RAW
          WHERE migration_code_move_within_reg IS NOT NULL) v
    WHERE NOT EXISTS (SELECT 1 FROM dbo.WITHIN_REGION_MOVE t WHERE t.MoveName = v.Deger);

    -- INDUSTRY / OCCUPATION: yeni detay kodlar üst gruplarıyla eklenir
    INSERT INTO dbo.INDUSTRY (IndustryCode, MajorIndustryID) OUTPUT N'INDUSTRY', CONVERT(NVARCHAR(60), inserted.IndustryCode) INTO @YeniLookup
    SELECT DISTINCT CONVERT(TINYINT, s.detailed_industry_recode), mi.MajorIndustryID
    FROM stg.CENSUS_RAW s
    JOIN dbo.MAJOR_INDUSTRY mi ON mi.IndustryName = s.major_industry_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.INDUSTRY i WHERE i.IndustryCode = CONVERT(TINYINT, s.detailed_industry_recode));

    INSERT INTO dbo.OCCUPATION (OccupationCode, MajorOccupationID) OUTPUT N'OCCUPATION', CONVERT(NVARCHAR(60), inserted.OccupationCode) INTO @YeniLookup
    SELECT DISTINCT CONVERT(TINYINT, s.detailed_occupation_recode), mo.MajorOccupationID
    FROM stg.CENSUS_RAW s
    JOIN dbo.MAJOR_OCCUPATION mo ON mo.OccupationName = s.major_occupation_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.OCCUPATION o WHERE o.OccupationCode = CONVERT(TINYINT, s.detailed_occupation_recode));

    -- Var olan kodun üst grubu staging ile çelişiyor mu? (ör. kod 33 başka bir sektöre bağlanmış)
    IF EXISTS (SELECT 1 FROM stg.CENSUS_RAW s
               JOIN dbo.INDUSTRY i        ON i.IndustryCode = CONVERT(TINYINT, s.detailed_industry_recode)
               JOIN dbo.MAJOR_INDUSTRY mi ON mi.MajorIndustryID = i.MajorIndustryID
               WHERE mi.IndustryName <> s.major_industry_code)
        THROW 50006, N'INDUSTRY tablosundaki üst grup ile staging verisi çelişiyor.', 1;
    IF EXISTS (SELECT 1 FROM stg.CENSUS_RAW s
               JOIN dbo.OCCUPATION o        ON o.OccupationCode = CONVERT(TINYINT, s.detailed_occupation_recode)
               JOIN dbo.MAJOR_OCCUPATION mo ON mo.MajorOccupationID = o.MajorOccupationID
               WHERE mo.OccupationName <> s.major_occupation_code)
        THROW 50007, N'OCCUPATION tablosundaki üst grup ile staging verisi çelişiyor.', 1;

    SELECT @n = COUNT(*) FROM @YeniLookup;
    PRINT CONCAT(N'[2] Lookup kontrolü bitti, yeni eklenen değer: ', @n);

    /* -----------------------------------------------------------------------
       3) Ana tablolar. Zorunlu lookup'lar INNER JOIN, NULL olabilenler LEFT JOIN.
          Her INSERT sonrası satır sayısı kontrol edilir: INNER JOIN'in satır
          düşürmesi (eşleşmeyen metin) sessizce geçmez.
       ----------------------------------------------------------------------- */

    -- 3a) PERSON
    SET IDENTITY_INSERT dbo.PERSON ON;
    INSERT INTO dbo.PERSON (PersonID, Age, SexID, RaceID, HispanicOriginID, MaritalStatusID, EducationID,
                            EduEnrollmentID, CitizenshipID, BirthCountryID, FatherBirthCountryID,
                            MotherBirthCountryID, VetQuestionnaireAnswerID, VeteransBenefits)
    SELECT s.StagingID, CONVERT(TINYINT, s.age), sx.SexID, r.RaceID, ho.HispanicOriginID, ms.MaritalStatusID,
           ed.EducationID, en.EduEnrollmentID, ct.CitizenshipID, cs.CountryID, cf.CountryID, cm.CountryID,
           va.AnswerID, CONVERT(TINYINT, s.veterans_benefits)
    FROM stg.CENSUS_RAW s
    JOIN dbo.SEX             sx ON sx.SexName         = s.sex
    JOIN dbo.RACE            r  ON r.RaceName         = s.race
    JOIN dbo.HISPANIC_ORIGIN ho ON ho.OriginName      = s.hispanic_origin
    JOIN dbo.MARITAL_STATUS  ms ON ms.StatusName      = s.marital_stat
    JOIN dbo.EDUCATION       ed ON ed.EducationName   = s.education
    JOIN dbo.EDU_ENROLLMENT  en ON en.EnrollmentName  = s.enroll_in_edu_inst_last_wk
    JOIN dbo.CITIZENSHIP     ct ON ct.CitizenshipName = s.citizenship
    JOIN dbo.ANSWER          va ON va.AnswerText      = s.fill_inc_questionnaire_for_veterans_admin
    LEFT JOIN dbo.COUNTRY    cs ON cs.CountryName     = s.country_of_birth_self
    LEFT JOIN dbo.COUNTRY    cf ON cf.CountryName     = s.country_of_birth_father
    LEFT JOIN dbo.COUNTRY    cm ON cm.CountryName     = s.country_of_birth_mother;
    SET @n = @@ROWCOUNT;
    SET IDENTITY_INSERT dbo.PERSON OFF;
    IF @n <> @Toplam BEGIN SET @msg = CONCAT(N'PERSON: beklenen ', @Toplam, N', eklenen ', @n); THROW 50010, @msg, 1; END
    PRINT CONCAT(N'[3a] PERSON: ', @n);

    -- 3b) SURVEY_RECORD (RecordID = PersonID = StagingID)
    SET IDENTITY_INSERT dbo.SURVEY_RECORD ON;
    INSERT INTO dbo.SURVEY_RECORD (RecordID, PersonID, SurveyYear, DataSplit, InstanceWeight, IncomeOver50K)
    SELECT s.StagingID, s.StagingID, 1900 + CONVERT(SMALLINT, s.year), s.DataSplit,
           CONVERT(DECIMAL(9,2), s.instance_weight), CONVERT(BIT, s.income_over_50k)
    FROM stg.CENSUS_RAW s;
    SET @n = @@ROWCOUNT;
    SET IDENTITY_INSERT dbo.SURVEY_RECORD OFF;
    IF @n <> @Toplam BEGIN SET @msg = CONCAT(N'SURVEY_RECORD: beklenen ', @Toplam, N', eklenen ', @n); THROW 50011, @msg, 1; END
    PRINT CONCAT(N'[3b] SURVEY_RECORD: ', @n);

    -- 3c) EMPLOYMENT
    INSERT INTO dbo.EMPLOYMENT (PersonID, ClassOfWorkerID, IndustryCode, OccupationCode, EmploymentStatusID,
                                UnemploymentReasonID, LaborUnionAnswerID, WeeksWorkedInYear,
                                NumPersonsWorkedForEmp, OwnBusinessSelfEmployed)
    SELECT s.StagingID, cw.ClassOfWorkerID, CONVERT(TINYINT, s.detailed_industry_recode),
           CONVERT(TINYINT, s.detailed_occupation_recode), es.EmploymentStatusID, ur.UnemploymentReasonID,
           lu.AnswerID, CONVERT(TINYINT, s.weeks_worked_in_year),
           CONVERT(TINYINT, s.num_persons_worked_for_employer), CONVERT(TINYINT, s.own_business_or_self_employed)
    FROM stg.CENSUS_RAW s
    JOIN dbo.CLASS_OF_WORKER     cw ON cw.ClassName  = s.class_of_worker
    JOIN dbo.EMPLOYMENT_STATUS   es ON es.StatusName = s.full_or_part_time_employment_stat
    JOIN dbo.UNEMPLOYMENT_REASON ur ON ur.ReasonName = s.reason_for_unemployment
    JOIN dbo.ANSWER              lu ON lu.AnswerText = s.member_of_labor_union;
    SET @n = @@ROWCOUNT;
    IF @n <> @Toplam BEGIN SET @msg = CONCAT(N'EMPLOYMENT: beklenen ', @Toplam, N', eklenen ', @n); THROW 50012, @msg, 1; END
    PRINT CONCAT(N'[3c] EMPLOYMENT: ', @n);

    -- 3d) FINANCE
    INSERT INTO dbo.FINANCE (PersonID, TaxFilerStatusID, WagePerHour, CapitalGains, CapitalLosses, DividendsFromStocks)
    SELECT s.StagingID, tf.TaxFilerStatusID, CONVERT(INT, s.wage_per_hour), CONVERT(INT, s.capital_gains),
           CONVERT(INT, s.capital_losses), CONVERT(INT, s.dividends_from_stocks)
    FROM stg.CENSUS_RAW s
    JOIN dbo.TAX_FILER_STATUS tf ON tf.StatusName = s.tax_filer_stat;
    SET @n = @@ROWCOUNT;
    IF @n <> @Toplam BEGIN SET @msg = CONCAT(N'FINANCE: beklenen ', @Toplam, N', eklenen ', @n); THROW 50013, @msg, 1; END
    PRINT CONCAT(N'[3d] FINANCE: ', @n);

    -- 3e) HOUSEHOLD
    INSERT INTO dbo.HOUSEHOLD (PersonID, HouseholdDetailID, HouseholdSummaryID, FamilyUnder18ID)
    SELECT s.StagingID, hd.HouseholdDetailID, hs.HouseholdSummaryID, fu.FamilyUnder18ID
    FROM stg.CENSUS_RAW s
    JOIN dbo.HOUSEHOLD_DETAIL  hd ON hd.DetailName     = s.detailed_household_and_family_stat
    JOIN dbo.HOUSEHOLD_SUMMARY hs ON hs.SummaryName    = s.detailed_household_summary_in_household
    JOIN dbo.FAMILY_UNDER_18   fu ON fu.ParentsPresent = s.family_members_under_18;
    SET @n = @@ROWCOUNT;
    IF @n <> @Toplam BEGIN SET @msg = CONCAT(N'HOUSEHOLD: beklenen ', @Toplam, N', eklenen ', @n); THROW 50014, @msg, 1; END
    PRINT CONCAT(N'[3e] HOUSEHOLD: ', @n);

    -- 3f) RESIDENCE (önceki eyalet bilinmiyorsa NULL)
    INSERT INTO dbo.RESIDENCE (PersonID, LivedInHouseAnswerID, PrevRegionID, PrevStateID)
    SELECT s.StagingID, lh.AnswerID, rg.RegionID, st.StateID
    FROM stg.CENSUS_RAW s
    JOIN dbo.ANSWER      lh ON lh.AnswerText = s.live_in_this_house_1_year_ago
    JOIN dbo.REGION      rg ON rg.RegionName = s.region_of_previous_residence
    LEFT JOIN dbo.STATE  st ON st.StateName  = s.state_of_previous_residence;
    SET @n = @@ROWCOUNT;
    IF @n <> @Toplam BEGIN SET @msg = CONCAT(N'RESIDENCE: beklenen ', @Toplam, N', eklenen ', @n); THROW 50015, @msg, 1; END
    PRINT CONCAT(N'[3f] RESIDENCE: ', @n);

    -- 3g) MIGRATION: yalnızca 1994 kayıtları (1995'te bu sorular sorulmadı -> satır yok, 1:0..1)
    INSERT INTO dbo.MIGRATION (PersonID, MsaChangeID, RegionChangeID, SunbeltAnswerID, WithinRegionMoveID)
    SELECT s.StagingID, mc.MsaChangeID, rc.RegionChangeID, sb.AnswerID, wm.WithinRegionMoveID
    FROM stg.CENSUS_RAW s
    JOIN dbo.MSA_CHANGE         mc ON mc.ChangeName = s.migration_code_change_in_msa
    JOIN dbo.REGION_CHANGE      rc ON rc.ChangeName = s.migration_code_change_in_reg
    JOIN dbo.ANSWER             sb ON sb.AnswerText = s.migration_prev_res_in_sunbelt
    JOIN dbo.WITHIN_REGION_MOVE wm ON wm.MoveName   = s.migration_code_move_within_reg
    WHERE s.year = '94';
    SET @n = @@ROWCOUNT;
    IF @n <> @Toplam94 BEGIN SET @msg = CONCAT(N'MIGRATION: beklenen ', @Toplam94, N', eklenen ', @n); THROW 50016, @msg, 1; END
    PRINT CONCAT(N'[3g] MIGRATION: ', @n);

    COMMIT TRANSACTION;
    PRINT CONCAT(N'ETL tamamlandı (', DATEDIFF(SECOND, @Basla, SYSDATETIME()), N' sn).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'HATA: tüm değişiklikler geri alındı.';
    THROW;   -- hatayı çağırana (SSMS / Python) aynen ilet
END CATCH;

-- Eklenen yeni lookup değerleri (varsa)
SELECT Tablo, Deger AS YeniDeger FROM @YeniLookup ORDER BY Tablo, Deger;
GO
