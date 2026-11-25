/* ============================================================================
   04 - Ana tablolara (24 örnek kişi) ve ML tablolarına örnek veri girişi
   BU DOSYA OTOMATİK ÜRETİLMİŞTİR: python database/kaynak/sql_uret.py
   Elle düzenlemeyin; değişiklik gerekiyorsa scripti düzenleyip yeniden çalıştırın.
   ============================================================================ */
USE GelirAnalizDB;
GO
SET NOCOUNT ON;

BEGIN TRANSACTION;

-- PERSON: 24 kayıt
SET IDENTITY_INSERT PERSON ON;
INSERT INTO PERSON (PersonID, Age, SexID, RaceID, HispanicOriginID, MaritalStatusID, EducationID, EduEnrollmentID, CitizenshipID, BirthCountryID, FatherBirthCountryID, MotherBirthCountryID, VetQuestionnaireAnswerID, VeteransBenefits) VALUES
    (1, 3, 1, 5, 10, 5, 1, 3, 5, 40, 34, 34, 2, 0),
    (2, 18, 1, 5, 1, 5, 9, 2, 5, 40, 40, 40, 2, 2),
    (3, 19, 1, 4, 2, 5, 10, 3, 1, 13, 13, 13, 2, 2),
    (4, 24, 1, 5, 8, 5, 6, 3, 5, 40, 40, 40, 2, 2),
    (5, 31, 2, 5, 9, 5, 15, 3, 1, NULL, NULL, NULL, 2, 2),
    (6, 47, 1, 5, 1, 7, 14, 3, 5, 40, 40, 40, 2, 2),
    (7, 50, 1, 5, 4, 4, 11, 3, 1, 5, 5, 5, 2, 2),
    (8, 68, 1, 5, 1, 7, 14, 3, 5, 40, NULL, 40, 2, 2),
    (9, 1, 1, 5, 1, 5, 1, 3, 5, 40, 40, 40, 2, 0),
    (10, 17, 1, 3, 1, 5, 7, 2, 5, 40, 23, 40, 2, 2),
    (11, 23, 2, 5, 1, 5, 10, 3, 5, 40, 40, 40, 2, 2),
    (12, 41, 2, 5, 1, 3, 14, 3, 5, 40, 40, 40, 2, 2),
    (13, 52, 2, 5, 1, 3, 10, 3, 5, 40, 40, 40, 2, 2),
    (14, 59, 1, 3, 1, 7, 14, 3, 5, 40, 40, 40, 2, 2),
    (15, 29, 1, 5, 7, 3, 12, 3, 5, 40, 40, 40, 2, 2),
    (16, 34, 2, 5, 1, 3, 15, 3, 5, 40, 40, 40, 2, 2),
    (17, 35, 2, 5, 6, 3, 10, 3, 1, 26, 26, 26, 2, 2),
    (18, 40, 2, 5, 2, 3, 14, 3, 1, NULL, NULL, NULL, 2, 2),
    (19, 49, 1, 5, 1, 3, 10, 3, 5, 40, 40, 40, 2, 2),
    (20, 24, 2, 5, 1, 5, 14, 3, 5, 40, 40, 40, 2, 2),
    (21, 39, 2, 5, 1, 3, 15, 3, 5, 40, 40, 40, 2, 2),
    (22, 60, 1, 2, 1, 7, 7, 3, 1, 31, 31, 31, 2, 2),
    (23, 65, 1, 5, 1, 7, 11, 3, 5, 40, 40, 40, 2, 2),
    (24, 78, 2, 5, 1, 3, 5, 3, 5, 40, NULL, NULL, 2, 2);
SET IDENTITY_INSERT PERSON OFF;

-- SURVEY_RECORD: 24 kayıt
SET IDENTITY_INSERT SURVEY_RECORD ON;
INSERT INTO SURVEY_RECORD (RecordID, PersonID, SurveyYear, DataSplit, InstanceWeight, IncomeOver50K) VALUES
    (1001, 1, 1994, N'train', 1292.5, 0),
    (1002, 2, 1994, N'train', 1385.01, 0),
    (1003, 3, 1994, N'train', 778.66, 0),
    (1004, 4, 1994, N'train', 2658.63, 0),
    (1005, 5, 1994, N'train', 1614.93, 1),
    (1006, 6, 1994, N'train', 496.42, 1),
    (1007, 7, 1994, N'train', 963.65, 0),
    (1008, 8, 1994, N'train', 3494.07, 1),
    (1009, 9, 1995, N'train', 1942.83, 0),
    (1010, 10, 1995, N'train', 2453.08, 0),
    (1011, 11, 1995, N'train', 1362.25, 0),
    (1012, 12, 1995, N'train', 1587.31, 1),
    (1013, 13, 1995, N'train', 737.07, 1),
    (1014, 14, 1995, N'train', 525.84, 0),
    (1015, 15, 1994, N'test', 1048.31, 1),
    (1016, 16, 1994, N'test', 1539.36, 1),
    (1017, 17, 1994, N'test', 948.18, 0),
    (1018, 18, 1994, N'test', 659.41, 0),
    (1019, 19, 1994, N'test', 600.22, 0),
    (1020, 20, 1995, N'test', 1152.9, 0),
    (1021, 21, 1995, N'test', 3519.39, 1),
    (1022, 22, 1995, N'test', 2722.78, 0),
    (1023, 23, 1995, N'test', 223.51, 0),
    (1024, 24, 1995, N'test', 363.86, 0);
SET IDENTITY_INSERT SURVEY_RECORD OFF;

-- EMPLOYMENT: 24 kayıt
INSERT INTO EMPLOYMENT (PersonID, ClassOfWorkerID, IndustryCode, OccupationCode, EmploymentStatusID, UnemploymentReasonID, LaborUnionAnswerID, WeeksWorkedInYear, NumPersonsWorkedForEmp, OwnBusinessSelfEmployed) VALUES
    (1, 4, 0, 0, 1, 4, 2, 0, 0, 0),
    (2, 5, 33, 19, 1, 4, 2, 13, 4, 2),
    (3, 5, 33, 41, 1, 4, 1, 26, 3, 2),
    (4, 4, 0, 0, 1, 4, 2, 12, 2, 2),
    (5, 4, 0, 0, 1, 4, 2, 0, 0, 0),
    (6, 5, 36, 27, 1, 4, 2, 51, 1, 0),
    (7, 5, 33, 29, 1, 4, 2, 52, 2, 0),
    (8, 4, 0, 0, 1, 4, 2, 0, 0, 0),
    (9, 4, 0, 0, 1, 4, 2, 0, 0, 0),
    (10, 4, 0, 0, 3, 4, 2, 0, 0, 0),
    (11, 5, 33, 33, 2, 4, 2, 36, 1, 2),
    (12, 5, 35, 2, 2, 4, 2, 52, 4, 0),
    (13, 5, 25, 36, 2, 4, 2, 52, 6, 0),
    (14, 5, 33, 41, 2, 4, 2, 40, 6, 0),
    (15, 8, 47, 8, 1, 4, 1, 52, 6, 2),
    (16, 5, 32, 5, 1, 4, 2, 52, 6, 1),
    (17, 5, 18, 36, 1, 4, 2, 29, 4, 0),
    (18, 5, 33, 29, 1, 4, 1, 40, 3, 2),
    (19, 5, 33, 19, 1, 4, 2, 52, 6, 2),
    (20, 5, 33, 38, 2, 4, 2, 52, 2, 0),
    (21, 5, 43, 26, 2, 4, 2, 52, 6, 0),
    (22, 5, 41, 31, 2, 4, 2, 52, 3, 0),
    (23, 7, 35, 2, 2, 4, 2, 52, 1, 0),
    (24, 4, 0, 0, 3, 4, 2, 30, 1, 2);

-- FINANCE: 24 kayıt
INSERT INTO FINANCE (PersonID, TaxFilerStatusID, WagePerHour, CapitalGains, CapitalLosses, DividendsFromStocks) VALUES
    (1, 5, 0, 0, 0, 0),
    (2, 6, 0, 0, 0, 0),
    (3, 6, 500, 0, 0, 0),
    (4, 6, 0, 0, 0, 0),
    (5, 5, 0, 0, 0, 0),
    (6, 1, 0, 25236, 0, 1200),
    (7, 6, 0, 0, 0, 0),
    (8, 6, 0, 0, 0, 0),
    (9, 5, 0, 0, 0, 0),
    (10, 5, 0, 0, 0, 0),
    (11, 6, 0, 0, 0, 0),
    (12, 3, 0, 0, 0, 1000),
    (13, 3, 0, 7298, 0, 1),
    (14, 6, 0, 0, 0, 0),
    (15, 3, 0, 0, 0, 0),
    (16, 3, 0, 0, 0, 0),
    (17, 3, 0, 0, 0, 0),
    (18, 3, 600, 0, 0, 0),
    (19, 3, 0, 0, 0, 0),
    (20, 6, 0, 0, 0, 0),
    (21, 3, 0, 0, 0, 0),
    (22, 6, 0, 0, 0, 0),
    (23, 6, 0, 0, 0, 2000),
    (24, 2, 0, 0, 0, 0);

-- HOUSEHOLD: 24 kayıt
INSERT INTO HOUSEHOLD (PersonID, HouseholdDetailID, HouseholdSummaryID, FamilyUnder18ID) VALUES
    (1, 9, 3, 3),
    (2, 3, 1, 5),
    (3, 27, 7, 5),
    (4, 3, 1, 5),
    (5, 36, 6, 5),
    (6, 21, 5, 5),
    (7, 23, 5, 5),
    (8, 21, 5, 5),
    (9, 9, 3, 2),
    (10, 9, 3, 3),
    (11, 3, 1, 5),
    (12, 38, 8, 5),
    (13, 21, 5, 5),
    (14, 23, 5, 5),
    (15, 21, 5, 5),
    (16, 21, 5, 5),
    (17, 21, 5, 5),
    (18, 38, 8, 5),
    (19, 38, 8, 5),
    (20, 36, 6, 5),
    (21, 21, 5, 5),
    (22, 25, 7, 5),
    (23, 23, 5, 5),
    (24, 21, 5, 5);

-- RESIDENCE: 24 kayıt
INSERT INTO RESIDENCE (PersonID, LivedInHouseAnswerID, PrevRegionID, PrevStateID) VALUES
    (1, 4, 4, 36),
    (2, 1, 3, 32),
    (3, 1, 6, 6),
    (4, 1, 5, 2),
    (5, 4, 4, 36),
    (6, 4, 4, 36),
    (7, 4, 4, 36),
    (8, 4, 4, 36),
    (9, 3, 4, 36),
    (10, 3, 4, 36),
    (11, 3, 4, 36),
    (12, 3, 4, 36),
    (13, 3, 4, 36),
    (14, 3, 4, 36),
    (15, 4, 4, 36),
    (16, 4, 4, 36),
    (17, 1, 2, 15),
    (18, 4, 4, 36),
    (19, 4, 4, 36),
    (20, 3, 4, 36),
    (21, 3, 4, 36),
    (22, 3, 4, 36),
    (23, 3, 4, 36),
    (24, 3, 4, 36);

-- MIGRATION: 13 kayıt
INSERT INTO MIGRATION (PersonID, MsaChangeID, RegionChangeID, SunbeltAnswerID, WithinRegionMoveID) VALUES
    (1, 7, 6, 2, 7),
    (2, 3, 8, 1, 9),
    (3, 3, 8, 4, 9),
    (4, 6, 8, 4, 9),
    (5, 7, 6, 2, 7),
    (6, 7, 6, 2, 7),
    (7, 7, 6, 2, 7),
    (8, 7, 6, 2, 7),
    (15, 7, 6, 2, 7),
    (16, 7, 6, 2, 7),
    (17, 3, 8, 1, 9),
    (18, 7, 6, 2, 7),
    (19, 7, 6, 2, 7);

-- ML_MODEL: 2 kayıt
SET IDENTITY_INSERT ML_MODEL ON;
INSERT INTO ML_MODEL (ModelID, ModelName, Algorithm, Hyperparameters, TrainedAt) VALUES
    (1, N'LogReg_Baseline_v1', N'LogisticRegression', N'{"C": 1.0, "class_weight": "balanced", "max_iter": 1000, "scaler": "StandardScaler"}', N'2026-11-20 14:00:00'),
    (2, N'DecisionTree_Depth8_v1', N'DecisionTreeClassifier', N'{"max_depth": 8, "class_weight": "balanced", "random_state": 42}', N'2026-11-20 14:00:00');
SET IDENTITY_INSERT ML_MODEL OFF;

-- MODEL_METRIC: 20 kayıt
SET IDENTITY_INSERT MODEL_METRIC ON;
INSERT INTO MODEL_METRIC (MetricID, ModelID, DataSplit, MetricName, MetricValue) VALUES
    (1, 1, N'train', N'roc_auc', 0.929),
    (2, 1, N'train', N'pr_auc', 0.546),
    (3, 1, N'train', N'f1', 0.394),
    (4, 1, N'train', N'precision', 0.2538),
    (5, 1, N'train', N'recall', 0.8802),
    (6, 1, N'test', N'roc_auc', 0.9311),
    (7, 1, N'test', N'pr_auc', 0.5515),
    (8, 1, N'test', N'f1', 0.3949),
    (9, 1, N'test', N'precision', 0.2548),
    (10, 1, N'test', N'recall', 0.8776),
    (11, 2, N'train', N'roc_auc', 0.9338),
    (12, 2, N'train', N'pr_auc', 0.5376),
    (13, 2, N'train', N'f1', 0.3956),
    (14, 2, N'train', N'precision', 0.2539),
    (15, 2, N'train', N'recall', 0.8961),
    (16, 2, N'test', N'roc_auc', 0.9274),
    (17, 2, N'test', N'pr_auc', 0.5197),
    (18, 2, N'test', N'f1', 0.3915),
    (19, 2, N'test', N'precision', 0.2514),
    (20, 2, N'test', N'recall', 0.8841);
SET IDENTITY_INSERT MODEL_METRIC OFF;

-- PREDICTION: 20 kayıt
SET IDENTITY_INSERT PREDICTION ON;
INSERT INTO PREDICTION (PredictionID, ModelID, RecordID, PredictedProbability, PredictedLabel, PredictedAt) VALUES
    (1, 1, 1015, 0.7606, 1, N'2026-11-20 14:05:00'),
    (2, 1, 1016, 0.8963, 1, N'2026-11-20 14:05:00'),
    (3, 1, 1017, 0.2077, 0, N'2026-11-20 14:05:00'),
    (4, 1, 1018, 0.3463, 0, N'2026-11-20 14:05:00'),
    (5, 1, 1019, 0.3924, 0, N'2026-11-20 14:05:00'),
    (6, 1, 1020, 0.2328, 0, N'2026-11-20 14:05:00'),
    (7, 1, 1021, 0.8263, 1, N'2026-11-20 14:05:00'),
    (8, 1, 1022, 0.13, 0, N'2026-11-20 14:05:00'),
    (9, 1, 1023, 0.8678, 1, N'2026-11-20 14:05:00'),
    (10, 1, 1024, 0.173, 0, N'2026-11-20 14:05:00'),
    (11, 2, 1015, 0.3381, 0, N'2026-11-20 14:05:00'),
    (12, 2, 1016, 0.8748, 1, N'2026-11-20 14:05:00'),
    (13, 2, 1017, 0.1185, 0, N'2026-11-20 14:05:00'),
    (14, 2, 1018, 0.5463, 1, N'2026-11-20 14:05:00'),
    (15, 2, 1019, 0.2042, 0, N'2026-11-20 14:05:00'),
    (16, 2, 1020, 0.2766, 0, N'2026-11-20 14:05:00'),
    (17, 2, 1021, 0.8748, 1, N'2026-11-20 14:05:00'),
    (18, 2, 1022, 0.2042, 0, N'2026-11-20 14:05:00'),
    (19, 2, 1023, 0.9008, 1, N'2026-11-20 14:05:00'),
    (20, 2, 1024, 0.0544, 0, N'2026-11-20 14:05:00');
SET IDENTITY_INSERT PREDICTION OFF;

COMMIT;
GO
PRINT N'Örnek veriler yüklendi.';
