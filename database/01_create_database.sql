/* ============================================================================
   01 - Veritabanını oluşturur
   Gelir Analizi ve Tahmin Yönetim Sistemi  (Census-Income KDD)
   Çalıştırma: SSMS'te bu dosyayı açıp Execute (F5)
   ============================================================================ */
USE master;
GO

IF DB_ID(N'GelirAnalizDB') IS NOT NULL
BEGIN
    ALTER DATABASE GelirAnalizDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GelirAnalizDB;
END
GO

CREATE DATABASE GelirAnalizDB;
GO

USE GelirAnalizDB;
GO

-- Normalizasyon örnekleri (05 numaralı script) ayrı bir şemada tutulur
CREATE SCHEMA norm;
GO
