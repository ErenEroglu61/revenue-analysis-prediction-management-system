/* ============================================================================
   00 - Tüm veritabanını sıfırdan kurar (01 -> 05)

   SSMS'te: Query menüsü -> "SQLCMD Mode" açık olmalı, sonra F5.
   Komut satırından (database klasöründe):
       sqlcmd -S localhost\SQLEXPRESS -E -i 00_hepsini_calistir.sql
   (Sunucu adı kurulumunuza göre değişir: localhost, .\SQLEXPRESS, (localdb)\MSSQLLocalDB ...)
   ============================================================================ */
:on error exit
:r 01_create_database.sql
:r 02_create_tables.sql
:r 03_insert_lookup_data.sql
:r 04_insert_sample_data.sql
:r 05_normalization_examples.sql
