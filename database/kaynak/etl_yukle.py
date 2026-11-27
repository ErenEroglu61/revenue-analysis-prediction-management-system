"""
ETL çalıştırıcısı: temizlenmiş CSV'leri MSSQL'e yükler ve normalize tablolara dağıtır.

  1) database/07_etl_staging.sql   -> stg.CENSUS_RAW tablosunu (yeniden) oluşturur
  2) data/processed/*_clean.csv    -> stg.CENSUS_RAW (metin olarak, toplu INSERT)   [Extract]
  3) database/08_etl_transform.sql -> lookup + 7 ana tablo (tek transaction)        [Transform + Load]
  4) database/09_etl_dogrulama.sql -> satır sayıları, içerik ve kayıpsızlık kontrolleri

Ön koşul : 01-03 çalışmış olmalı (veritabanı, tablolar, lookup verileri)
           ve analysis/pre_analiz.py çalışmış olmalı (*_clean.csv).
Gerekli  : pip install pyodbc pandas
Çalıştırma (proje kök dizininden):
    python database/kaynak/etl_yukle.py
    python database/kaynak/etl_yukle.py --server "localhost\\SQLEXPRESS" --database GelirAnalizDB
    python database/kaynak/etl_yukle.py --sadece-dogrula      # yalnızca 09'u çalıştırır
"""

from __future__ import annotations

import argparse
import re
import sys
import time
from pathlib import Path

import pandas as pd
import pyodbc

ROOT = Path(__file__).resolve().parents[2]
PROCESSED = ROOT / "data" / "processed"
DB_DIR = ROOT / "database"
CHUNK = 20_000

GO_RE = re.compile(r"^\s*GO\s*$", re.IGNORECASE | re.MULTILINE)


def baglan(server: str, database: str) -> pyodbc.Connection:
    drivers = [d for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server")
               if d in pyodbc.drivers()]
    if not drivers:
        sys.exit("SQL Server ODBC sürücüsü bulunamadı (ODBC Driver 17 veya 18 kurun).")
    cs = (f"DRIVER={{{drivers[0]}}};SERVER={server};DATABASE={database};"
          "Trusted_Connection=yes;TrustServerCertificate=yes;")
    return pyodbc.connect(cs, autocommit=True)


def sonuclari_yazdir(cur: pyodbc.Cursor) -> None:
    """Bir batch'in tüm sonuç kümelerini ve PRINT mesajlarını yazdırır."""
    while True:
        for _, msg in cur.messages:
            print("   ", re.sub(r"^\[.*?\]\[.*?\]\[.*?\]", "", msg))
        if cur.description:
            cols = [c[0] for c in cur.description]
            rows = cur.fetchall()
            if rows:
                df = pd.DataFrame.from_records(rows, columns=cols)
                print(df.to_string(index=False))
                print()
        if not cur.nextset():
            break


def sql_dosyasi_calistir(conn: pyodbc.Connection, path: Path) -> None:
    print(f"\n>> {path.name}")
    text = path.read_text(encoding="utf-8")
    cur = conn.cursor()
    for batch in GO_RE.split(text):
        if not batch.strip() or re.fullmatch(r"\s*USE\s+\w+\s*;?\s*", batch, re.IGNORECASE):
            continue
        cur.execute(batch)
        sonuclari_yazdir(cur)


def staging_yukle(conn: pyodbc.Connection) -> None:
    print("\n>> CSV -> stg.CENSUS_RAW")
    frames = []
    for split in ("train", "test"):
        f = PROCESSED / f"{split}_clean.csv"
        if not f.exists():
            sys.exit(f"{f} yok. Önce çalıştırın: python analysis/pre_analiz.py")
        # Her şey metin olarak okunur; boş hücre ('?' idi) -> None. Dönüşümü SQL yapar.
        df = pd.read_csv(f, dtype=str, keep_default_na=False, na_values=[""])
        df.insert(0, "SourceRowNo", range(1, len(df) + 1))
        df.insert(0, "DataSplit", split)
        frames.append(df)
        print(f"   {f.name}: {len(df):,} satır")
    df = pd.concat(frames, ignore_index=True)
    df.insert(0, "StagingID", range(1, len(df) + 1))
    df = df.astype(object).where(df.notna(), None)

    cols = list(df.columns)
    sql = (f"INSERT INTO stg.CENSUS_RAW ({', '.join(cols)}) "
           f"VALUES ({', '.join('?' * len(cols))})")
    cur = conn.cursor()
    cur.fast_executemany = True
    rows = df.itertuples(index=False, name=None)
    t0, done = time.time(), 0
    conn.autocommit = False
    try:
        while batch := [r for _, r in zip(range(CHUNK), rows)]:
            cur.executemany(sql, batch)
            done += len(batch)
            print(f"\r   yüklendi: {done:,} / {len(df):,}", end="", flush=True)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.autocommit = True
    print(f"\n   {time.time() - t0:.1f} sn")


def main() -> None:
    ap = argparse.ArgumentParser(description="Census-Income ETL (CSV -> MSSQL)")
    ap.add_argument("--server", default=r"localhost\SQLEXPRESS")
    ap.add_argument("--database", default="GelirAnalizDB")
    ap.add_argument("--sadece-dogrula", action="store_true", help="Yalnızca 09 doğrulamasını çalıştır")
    args = ap.parse_args()

    conn = baglan(args.server, args.database)
    t0 = time.time()
    try:
        if not args.sadece_dogrula:
            sql_dosyasi_calistir(conn, DB_DIR / "07_etl_staging.sql")
            staging_yukle(conn)
            sql_dosyasi_calistir(conn, DB_DIR / "08_etl_transform.sql")
        sql_dosyasi_calistir(conn, DB_DIR / "09_etl_dogrulama.sql")
    except pyodbc.Error as e:
        sys.exit(f"\nETL HATASI: {e}")
    finally:
        conn.close()
    print(f"Toplam süre: {time.time() - t0:.1f} sn")


if __name__ == "__main__":
    main()
