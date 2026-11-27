/* ============================================================================
   07 - ETL / Adım 1: Staging (ara yükleme) tablosu
   Temizlenmiş CSV'ler (data/processed klasöründeki train_clean.csv ve test_clean.csv) bu tabloya OLDUĞU GİBİ, metin olarak yüklenir.
   Tip dönüşümü, lookup eşleştirme ve normalize tablolara dağıtım 08 numaralı scriptte yapılır.

   Neden staging?
     - Ham veri önce veritabanına alınır, sonra SQL ile (INSERT ... SELECT) dönüştürülür.
     - Tip hataları ve eksik lookup değerleri, ana tablolara dokunmadan önce yakalanır.
     - Yükleme sonrası doğrulama (09) staging ile normalize tabloları karşılaştırabilir.

   Bu tabloyu dolduran: python database/kaynak/etl_yukle.py
   ============================================================================ */
USE GelirAnalizDB;
GO

IF SCHEMA_ID(N'stg') IS NULL
    EXEC (N'CREATE SCHEMA stg');
GO

DROP TABLE IF EXISTS stg.CENSUS_RAW;
GO

-- Sütun adları CSV başlığıyla aynıdır; tüm değerler metindir. Boş hücre ('?' idi) = NULL.
CREATE TABLE stg.CENSUS_RAW (
    StagingID                                  INT         NOT NULL CONSTRAINT PK_CENSUS_RAW PRIMARY KEY,
    DataSplit                                  VARCHAR(5)  NOT NULL,   -- 'train' / 'test'
    SourceRowNo                                INT         NOT NULL,   -- CSV'deki veri satırı numarası (1'den başlar)
    age                                        VARCHAR(10) NULL,
    class_of_worker                            VARCHAR(60) NULL,
    detailed_industry_recode                   VARCHAR(10) NULL,
    detailed_occupation_recode                 VARCHAR(10) NULL,
    education                                  VARCHAR(60) NULL,
    wage_per_hour                              VARCHAR(10) NULL,
    enroll_in_edu_inst_last_wk                 VARCHAR(60) NULL,
    marital_stat                               VARCHAR(60) NULL,
    major_industry_code                        VARCHAR(60) NULL,
    major_occupation_code                      VARCHAR(60) NULL,
    race                                       VARCHAR(60) NULL,
    hispanic_origin                            VARCHAR(60) NULL,
    sex                                        VARCHAR(60) NULL,
    member_of_labor_union                      VARCHAR(60) NULL,
    reason_for_unemployment                    VARCHAR(60) NULL,
    full_or_part_time_employment_stat          VARCHAR(60) NULL,
    capital_gains                              VARCHAR(10) NULL,
    capital_losses                             VARCHAR(10) NULL,
    dividends_from_stocks                      VARCHAR(10) NULL,
    tax_filer_stat                             VARCHAR(60) NULL,
    region_of_previous_residence               VARCHAR(60) NULL,
    state_of_previous_residence                VARCHAR(60) NULL,
    detailed_household_and_family_stat         VARCHAR(60) NULL,
    detailed_household_summary_in_household    VARCHAR(60) NULL,
    instance_weight                            VARCHAR(20) NULL,
    migration_code_change_in_msa               VARCHAR(60) NULL,
    migration_code_change_in_reg               VARCHAR(60) NULL,
    migration_code_move_within_reg             VARCHAR(60) NULL,
    live_in_this_house_1_year_ago              VARCHAR(60) NULL,
    migration_prev_res_in_sunbelt              VARCHAR(60) NULL,
    num_persons_worked_for_employer            VARCHAR(10) NULL,
    family_members_under_18                    VARCHAR(60) NULL,
    country_of_birth_father                    VARCHAR(60) NULL,
    country_of_birth_mother                    VARCHAR(60) NULL,
    country_of_birth_self                      VARCHAR(60) NULL,
    citizenship                                VARCHAR(60) NULL,
    own_business_or_self_employed              VARCHAR(10) NULL,
    fill_inc_questionnaire_for_veterans_admin  VARCHAR(60) NULL,
    veterans_benefits                          VARCHAR(10) NULL,
    weeks_worked_in_year                       VARCHAR(10) NULL,
    year                                       VARCHAR(10) NULL,
    income_over_50k                            VARCHAR(10) NULL,
    LoadedAt                                   DATETIME2(0) NOT NULL CONSTRAINT DF_CENSUS_RAW_LoadedAt DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_CENSUS_RAW_Source UNIQUE (DataSplit, SourceRowNo)
);
GO

PRINT N'stg.CENSUS_RAW hazır.';
