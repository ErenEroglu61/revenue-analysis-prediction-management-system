# Türetilmiş Özellikler Raporu


_Bu dosya `analysis/turetilmis_ozellikler.py` tarafından otomatik üretilmiştir._


AUC: özelliğin tek başına 50K+ / 50K altı ayrımını ne kadar iyi yaptığı (0.5 = hiç, 1.0 = kusursuz). Test kümesindeki değerlerin train ile tutarlı olması, ilişkinin tesadüf olmadığını gösterir.


## Özet

| özellik | train AUC | test AUC |
|---|---|---|
| education_level | 0.85 | 0.84 |
| full_year_worker | 0.76 | 0.76 |
| is_professional_occ | 0.73 | 0.73 |
| has_investment | 0.73 | 0.73 |
| is_employed | 0.73 | 0.73 |
| is_householder | 0.71 | 0.71 |
| joint_filer | 0.70 | 0.70 |
| age_group | 0.69 | 0.69 |
| is_married | 0.68 | 0.69 |


## Değerlere Göre 50K+ Oranı


### education_level

| education_level | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 44,347 | 0.00 | 22,600 | 0.00 |
| 1 | 817 | 0.12 | 416 | 0.24 |
| 2 | 1,799 | 0.72 | 903 | 0.78 |
| 3 | 3,277 | 0.67 | 1,714 | 1.05 |
| 4 | 7,976 | 0.90 | 4,139 | 0.80 |
| 5 | 6,193 | 0.61 | 3,095 | 0.71 |
| 6 | 7,539 | 0.82 | 3,810 | 0.89 |
| 7 | 6,862 | 1.02 | 3,519 | 1.31 |
| 8 | 2,125 | 1.60 | 1,137 | 1.23 |
| 9 | 48,374 | 3.88 | 24,141 | 4.12 |
| 10 | 27,809 | 6.43 | 13,951 | 6.04 |
| 11 | 5,358 | 7.71 | 2,689 | 7.55 |
| 12 | 4,363 | 9.44 | 2,079 | 8.61 |
| 13 | 19,859 | 19.71 | 9,884 | 19.85 |
| 14 | 6,540 | 31.16 | 3,306 | 31.34 |
| 15 | 1,793 | 54.04 | 876 | 54.57 |
| 16 | 1,263 | 52.02 | 620 | 51.13 |


### age_group

| age_group | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0-17 | 52,826 | 0.00 | 26,856 | 0.00 |
| 18-24 | 17,806 | 0.62 | 9,024 | 0.47 |
| 25-34 | 30,880 | 5.82 | 15,514 | 5.46 |
| 35-44 | 31,413 | 12.71 | 15,607 | 12.83 |
| 45-54 | 23,195 | 16.24 | 11,572 | 16.22 |
| 55-64 | 15,906 | 11.10 | 8,011 | 11.80 |
| 65+ | 24,268 | 3.89 | 12,295 | 3.84 |


### is_employed

| is_employed | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 92,770 | 0.64 | 47,009 | 0.66 |
| 1 | 103,524 | 11.38 | 51,870 | 11.33 |


### full_year_worker

| full_year_worker | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 125,986 | 1.57 | 63,828 | 1.55 |
| 1 | 70,308 | 14.80 | 35,051 | 14.82 |


### is_professional_occ

| is_professional_occ | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 169,859 | 3.13 | 85,722 | 3.09 |
| 1 | 26,435 | 26.74 | 13,157 | 26.88 |


### has_investment

| has_investment | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 166,940 | 3.09 | 84,211 | 3.04 |
| 1 | 29,354 | 24.60 | 14,668 | 24.73 |


### is_householder

| is_householder | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 120,833 | 2.26 | 60,940 | 2.25 |
| 1 | 75,461 | 12.79 | 37,939 | 12.69 |


### joint_filer

| joint_filer | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 116,737 | 2.38 | 59,145 | 2.28 |
| 1 | 79,557 | 12.07 | 39,734 | 12.18 |


### is_married

| is_married | train kayıt | train 50K+ % | test kayıt | test 50K+ % |
|---|---|---|---|---|
| 0 | 109,918 | 2.43 | 55,742 | 2.34 |
| 1 | 86,376 | 11.24 | 43,137 | 11.32 |


## Notlar

- `age_group` metin olarak tutuldu; modelde one-hot kodlanmalı ya da sıralı kod olarak kullanılmalı.
- `education_level`, `education` sütunuyla aynı bilgiyi **sıralı** şekilde taşır; modelde ikisinden biri kullanılmalı.
- `is_employed` ve `full_year_worker` aynı sütundan (`weeks_worked_in_year`) türetildiği için birbirleriyle ilişkilidir. Ağaç tabanlı modellerde sorun olmaz; lojistik regresyonda katsayılar yorumlanırken dikkat edilmeli.
- Veritabanında bu özellikler `vw_MLFeatures` view'ında SQL ile hesaplanacak; `education_level` ise `Education` lookup tablosunda `level` sütunu olarak tutulacak.
