/* ============================================================================
   03 - Lookup tablolarına veri girişi (25 tablo, veri setindeki tüm değerler)
   BU DOSYA OTOMATİK ÜRETİLMİŞTİR: python database/kaynak/sql_uret.py
   Elle düzenlemeyin; değişiklik gerekiyorsa scripti düzenleyip yeniden çalıştırın.
   ============================================================================ */
USE GelirAnalizDB;
GO
SET NOCOUNT ON;

BEGIN TRANSACTION;

-- SEX: 2 kayıt
INSERT INTO SEX (SexID, SexName) VALUES
    (1, N'Female'),
    (2, N'Male');

-- RACE: 5 kayıt
INSERT INTO RACE (RaceID, RaceName) VALUES
    (1, N'Amer Indian Aleut or Eskimo'),
    (2, N'Asian or Pacific Islander'),
    (3, N'Black'),
    (4, N'Other'),
    (5, N'White');

-- HISPANIC_ORIGIN: 10 kayıt
INSERT INTO HISPANIC_ORIGIN (HispanicOriginID, OriginName) VALUES
    (1, N'All other'),
    (2, N'Central or South American'),
    (3, N'Chicano'),
    (4, N'Cuban'),
    (5, N'Do not know'),
    (6, N'Mexican (Mexicano)'),
    (7, N'Mexican-American'),
    (8, N'NA'),
    (9, N'Other Spanish'),
    (10, N'Puerto Rican');

-- MARITAL_STATUS: 7 kayıt
INSERT INTO MARITAL_STATUS (MaritalStatusID, StatusName) VALUES
    (1, N'Divorced'),
    (2, N'Married-A F spouse present'),
    (3, N'Married-civilian spouse present'),
    (4, N'Married-spouse absent'),
    (5, N'Never married'),
    (6, N'Separated'),
    (7, N'Widowed');

-- EDUCATION: 17 kayıt
INSERT INTO EDUCATION (EducationID, EducationName, EducationLevel) VALUES
    (1, N'Children', 0),
    (2, N'Less than 1st grade', 1),
    (3, N'1st 2nd 3rd or 4th grade', 2),
    (4, N'5th or 6th grade', 3),
    (5, N'7th and 8th grade', 4),
    (6, N'9th grade', 5),
    (7, N'10th grade', 6),
    (8, N'11th grade', 7),
    (9, N'12th grade no diploma', 8),
    (10, N'High school graduate', 9),
    (11, N'Some college but no degree', 10),
    (12, N'Associates degree-occup /vocational', 11),
    (13, N'Associates degree-academic program', 12),
    (14, N'Bachelors degree(BA AB BS)', 13),
    (15, N'Masters degree(MA MS MEng MEd MSW MBA)', 14),
    (16, N'Prof school degree (MD DDS DVM LLB JD)', 15),
    (17, N'Doctorate degree(PhD EdD)', 16);

-- EDU_ENROLLMENT: 3 kayıt
INSERT INTO EDU_ENROLLMENT (EduEnrollmentID, EnrollmentName) VALUES
    (1, N'College or university'),
    (2, N'High school'),
    (3, N'Not in universe');

-- CITIZENSHIP: 5 kayıt
INSERT INTO CITIZENSHIP (CitizenshipID, CitizenshipName) VALUES
    (1, N'Foreign born- Not a citizen of U S'),
    (2, N'Foreign born- U S citizen by naturalization'),
    (3, N'Native- Born abroad of American Parent(s)'),
    (4, N'Native- Born in Puerto Rico or U S Outlying'),
    (5, N'Native- Born in the United States');

-- COUNTRY: 42 kayıt
INSERT INTO COUNTRY (CountryID, CountryName) VALUES
    (1, N'Cambodia'),
    (2, N'Canada'),
    (3, N'China'),
    (4, N'Columbia'),
    (5, N'Cuba'),
    (6, N'Dominican-Republic'),
    (7, N'Ecuador'),
    (8, N'El-Salvador'),
    (9, N'England'),
    (10, N'France'),
    (11, N'Germany'),
    (12, N'Greece'),
    (13, N'Guatemala'),
    (14, N'Haiti'),
    (15, N'Holand-Netherlands'),
    (16, N'Honduras'),
    (17, N'Hong Kong'),
    (18, N'Hungary'),
    (19, N'India'),
    (20, N'Iran'),
    (21, N'Ireland'),
    (22, N'Italy'),
    (23, N'Jamaica'),
    (24, N'Japan'),
    (25, N'Laos'),
    (26, N'Mexico'),
    (27, N'Nicaragua'),
    (28, N'Outlying-U S (Guam USVI etc)'),
    (29, N'Panama'),
    (30, N'Peru'),
    (31, N'Philippines'),
    (32, N'Poland'),
    (33, N'Portugal'),
    (34, N'Puerto-Rico'),
    (35, N'Scotland'),
    (36, N'South Korea'),
    (37, N'Taiwan'),
    (38, N'Thailand'),
    (39, N'Trinadad&Tobago'),
    (40, N'United-States'),
    (41, N'Vietnam'),
    (42, N'Yugoslavia');

-- ANSWER: 4 kayıt
INSERT INTO ANSWER (AnswerID, AnswerText) VALUES
    (1, N'No'),
    (2, N'Not in universe'),
    (3, N'Not in universe under 1 year old'),
    (4, N'Yes');

-- CLASS_OF_WORKER: 9 kayıt
INSERT INTO CLASS_OF_WORKER (ClassOfWorkerID, ClassName) VALUES
    (1, N'Federal government'),
    (2, N'Local government'),
    (3, N'Never worked'),
    (4, N'Not in universe'),
    (5, N'Private'),
    (6, N'Self-employed-incorporated'),
    (7, N'Self-employed-not incorporated'),
    (8, N'State government'),
    (9, N'Without pay');

-- MAJOR_INDUSTRY: 24 kayıt
INSERT INTO MAJOR_INDUSTRY (MajorIndustryID, IndustryName) VALUES
    (1, N'Agriculture'),
    (2, N'Armed Forces'),
    (3, N'Business and repair services'),
    (4, N'Communications'),
    (5, N'Construction'),
    (6, N'Education'),
    (7, N'Entertainment'),
    (8, N'Finance insurance and real estate'),
    (9, N'Forestry and fisheries'),
    (10, N'Hospital services'),
    (11, N'Manufacturing-durable goods'),
    (12, N'Manufacturing-nondurable goods'),
    (13, N'Medical except hospital'),
    (14, N'Mining'),
    (15, N'Not in universe or children'),
    (16, N'Other professional services'),
    (17, N'Personal services except private HH'),
    (18, N'Private household services'),
    (19, N'Public administration'),
    (20, N'Retail trade'),
    (21, N'Social services'),
    (22, N'Transportation'),
    (23, N'Utilities and sanitary services'),
    (24, N'Wholesale trade');

-- MAJOR_OCCUPATION: 15 kayıt
INSERT INTO MAJOR_OCCUPATION (MajorOccupationID, OccupationName) VALUES
    (1, N'Adm support including clerical'),
    (2, N'Armed Forces'),
    (3, N'Executive admin and managerial'),
    (4, N'Farming forestry and fishing'),
    (5, N'Handlers equip cleaners etc'),
    (6, N'Machine operators assmblrs & inspctrs'),
    (7, N'Not in universe'),
    (8, N'Other service'),
    (9, N'Precision production craft & repair'),
    (10, N'Private household services'),
    (11, N'Professional specialty'),
    (12, N'Protective services'),
    (13, N'Sales'),
    (14, N'Technicians and related support'),
    (15, N'Transportation and material moving');

-- EMPLOYMENT_STATUS: 8 kayıt
INSERT INTO EMPLOYMENT_STATUS (EmploymentStatusID, StatusName) VALUES
    (1, N'Children or Armed Forces'),
    (2, N'Full-time schedules'),
    (3, N'Not in labor force'),
    (4, N'PT for econ reasons usually FT'),
    (5, N'PT for econ reasons usually PT'),
    (6, N'PT for non-econ reasons usually FT'),
    (7, N'Unemployed full-time'),
    (8, N'Unemployed part- time');

-- UNEMPLOYMENT_REASON: 6 kayıt
INSERT INTO UNEMPLOYMENT_REASON (UnemploymentReasonID, ReasonName) VALUES
    (1, N'Job leaver'),
    (2, N'Job loser - on layoff'),
    (3, N'New entrant'),
    (4, N'Not in universe'),
    (5, N'Other job loser'),
    (6, N'Re-entrant');

-- TAX_FILER_STATUS: 6 kayıt
INSERT INTO TAX_FILER_STATUS (TaxFilerStatusID, StatusName) VALUES
    (1, N'Head of household'),
    (2, N'Joint both 65+'),
    (3, N'Joint both under 65'),
    (4, N'Joint one under 65 & one 65+'),
    (5, N'Nonfiler'),
    (6, N'Single');

-- HOUSEHOLD_DETAIL: 38 kayıt
INSERT INTO HOUSEHOLD_DETAIL (HouseholdDetailID, DetailName) VALUES
    (1, N'Child 18+ ever marr Not in a subfamily'),
    (2, N'Child 18+ ever marr RP of subfamily'),
    (3, N'Child 18+ never marr Not in a subfamily'),
    (4, N'Child 18+ never marr RP of subfamily'),
    (5, N'Child 18+ spouse of subfamily RP'),
    (6, N'Child <18 ever marr RP of subfamily'),
    (7, N'Child <18 ever marr not in subfamily'),
    (8, N'Child <18 never marr RP of subfamily'),
    (9, N'Child <18 never marr not in subfamily'),
    (10, N'Child <18 spouse of subfamily RP'),
    (11, N'Child under 18 of RP of unrel subfamily'),
    (12, N'Grandchild 18+ ever marr RP of subfamily'),
    (13, N'Grandchild 18+ ever marr not in subfamily'),
    (14, N'Grandchild 18+ never marr RP of subfamily'),
    (15, N'Grandchild 18+ never marr not in subfamily'),
    (16, N'Grandchild 18+ spouse of subfamily RP'),
    (17, N'Grandchild <18 ever marr not in subfamily'),
    (18, N'Grandchild <18 never marr RP of subfamily'),
    (19, N'Grandchild <18 never marr child of subfamily RP'),
    (20, N'Grandchild <18 never marr not in subfamily'),
    (21, N'Householder'),
    (22, N'In group quarters'),
    (23, N'Nonfamily householder'),
    (24, N'Other Rel 18+ ever marr RP of subfamily'),
    (25, N'Other Rel 18+ ever marr not in subfamily'),
    (26, N'Other Rel 18+ never marr RP of subfamily'),
    (27, N'Other Rel 18+ never marr not in subfamily'),
    (28, N'Other Rel 18+ spouse of subfamily RP'),
    (29, N'Other Rel <18 ever marr RP of subfamily'),
    (30, N'Other Rel <18 ever marr not in subfamily'),
    (31, N'Other Rel <18 never marr child of subfamily RP'),
    (32, N'Other Rel <18 never marr not in subfamily'),
    (33, N'Other Rel <18 never married RP of subfamily'),
    (34, N'Other Rel <18 spouse of subfamily RP'),
    (35, N'RP of unrelated subfamily'),
    (36, N'Secondary individual'),
    (37, N'Spouse of RP of unrelated subfamily'),
    (38, N'Spouse of householder');

-- HOUSEHOLD_SUMMARY: 8 kayıt
INSERT INTO HOUSEHOLD_SUMMARY (HouseholdSummaryID, SummaryName) VALUES
    (1, N'Child 18 or older'),
    (2, N'Child under 18 ever married'),
    (3, N'Child under 18 never married'),
    (4, N'Group Quarters- Secondary individual'),
    (5, N'Householder'),
    (6, N'Nonrelative of householder'),
    (7, N'Other relative of householder'),
    (8, N'Spouse of householder');

-- FAMILY_UNDER_18: 5 kayıt
INSERT INTO FAMILY_UNDER_18 (FamilyUnder18ID, ParentsPresent) VALUES
    (1, N'Both parents present'),
    (2, N'Father only present'),
    (3, N'Mother only present'),
    (4, N'Neither parent present'),
    (5, N'Not in universe');

-- REGION: 6 kayıt
INSERT INTO REGION (RegionID, RegionName) VALUES
    (1, N'Abroad'),
    (2, N'Midwest'),
    (3, N'Northeast'),
    (4, N'Not in universe'),
    (5, N'South'),
    (6, N'West');

-- STATE: 50 kayıt
INSERT INTO STATE (StateID, StateName) VALUES
    (1, N'Abroad'),
    (2, N'Alabama'),
    (3, N'Alaska'),
    (4, N'Arizona'),
    (5, N'Arkansas'),
    (6, N'California'),
    (7, N'Colorado'),
    (8, N'Connecticut'),
    (9, N'Delaware'),
    (10, N'District of Columbia'),
    (11, N'Florida'),
    (12, N'Georgia'),
    (13, N'Idaho'),
    (14, N'Illinois'),
    (15, N'Indiana'),
    (16, N'Iowa'),
    (17, N'Kansas'),
    (18, N'Kentucky'),
    (19, N'Louisiana'),
    (20, N'Maine'),
    (21, N'Maryland'),
    (22, N'Massachusetts'),
    (23, N'Michigan'),
    (24, N'Minnesota'),
    (25, N'Mississippi'),
    (26, N'Missouri'),
    (27, N'Montana'),
    (28, N'Nebraska'),
    (29, N'Nevada'),
    (30, N'New Hampshire'),
    (31, N'New Jersey'),
    (32, N'New Mexico'),
    (33, N'New York'),
    (34, N'North Carolina'),
    (35, N'North Dakota'),
    (36, N'Not in universe'),
    (37, N'Ohio'),
    (38, N'Oklahoma'),
    (39, N'Oregon'),
    (40, N'Pennsylvania'),
    (41, N'South Carolina'),
    (42, N'South Dakota'),
    (43, N'Tennessee'),
    (44, N'Texas'),
    (45, N'Utah'),
    (46, N'Vermont'),
    (47, N'Virginia'),
    (48, N'West Virginia'),
    (49, N'Wisconsin'),
    (50, N'Wyoming');

-- MSA_CHANGE: 9 kayıt
INSERT INTO MSA_CHANGE (MsaChangeID, ChangeName) VALUES
    (1, N'Abroad to MSA'),
    (2, N'Abroad to nonMSA'),
    (3, N'MSA to MSA'),
    (4, N'MSA to nonMSA'),
    (5, N'NonMSA to MSA'),
    (6, N'NonMSA to nonMSA'),
    (7, N'Nonmover'),
    (8, N'Not identifiable'),
    (9, N'Not in universe');

-- REGION_CHANGE: 8 kayıt
INSERT INTO REGION_CHANGE (RegionChangeID, ChangeName) VALUES
    (1, N'Abroad'),
    (2, N'Different county same state'),
    (3, N'Different division same region'),
    (4, N'Different region'),
    (5, N'Different state same division'),
    (6, N'Nonmover'),
    (7, N'Not in universe'),
    (8, N'Same county');

-- WITHIN_REGION_MOVE: 9 kayıt
INSERT INTO WITHIN_REGION_MOVE (WithinRegionMoveID, MoveName) VALUES
    (1, N'Abroad'),
    (2, N'Different county same state'),
    (3, N'Different state in Midwest'),
    (4, N'Different state in Northeast'),
    (5, N'Different state in South'),
    (6, N'Different state in West'),
    (7, N'Nonmover'),
    (8, N'Not in universe'),
    (9, N'Same county');

-- INDUSTRY: 52 kayıt
INSERT INTO INDUSTRY (IndustryCode, MajorIndustryID) VALUES
    (0, 15),
    (1, 1),
    (2, 1),
    (3, 14),
    (4, 5),
    (5, 11),
    (6, 11),
    (7, 11),
    (8, 11),
    (9, 11),
    (10, 11),
    (11, 11),
    (12, 11),
    (13, 11),
    (14, 11),
    (15, 11),
    (16, 11),
    (17, 11),
    (18, 11),
    (19, 12),
    (20, 12),
    (21, 12),
    (22, 12),
    (23, 12),
    (24, 12),
    (25, 12),
    (26, 12),
    (27, 12),
    (28, 12),
    (29, 22),
    (30, 4),
    (31, 23),
    (32, 24),
    (33, 20),
    (34, 8),
    (35, 8),
    (36, 18),
    (37, 3),
    (38, 3),
    (39, 17),
    (40, 7),
    (41, 10),
    (42, 13),
    (43, 6),
    (44, 21),
    (45, 16),
    (46, 9),
    (47, 19),
    (48, 19),
    (49, 19),
    (50, 19),
    (51, 2);

-- OCCUPATION: 47 kayıt
INSERT INTO OCCUPATION (OccupationCode, MajorOccupationID) VALUES
    (0, 7),
    (1, 3),
    (2, 3),
    (3, 3),
    (4, 11),
    (5, 11),
    (6, 11),
    (7, 11),
    (8, 11),
    (9, 11),
    (10, 11),
    (11, 11),
    (12, 11),
    (13, 14),
    (14, 14),
    (15, 14),
    (16, 13),
    (17, 13),
    (18, 13),
    (19, 13),
    (20, 13),
    (21, 1),
    (22, 1),
    (23, 1),
    (24, 1),
    (25, 1),
    (26, 1),
    (27, 10),
    (28, 12),
    (29, 8),
    (30, 8),
    (31, 8),
    (32, 8),
    (33, 9),
    (34, 9),
    (35, 9),
    (36, 6),
    (37, 6),
    (38, 15),
    (39, 15),
    (40, 5),
    (41, 5),
    (42, 5),
    (43, 4),
    (44, 4),
    (45, 4),
    (46, 2);

COMMIT;
GO
PRINT N'Lookup verileri yüklendi.';
