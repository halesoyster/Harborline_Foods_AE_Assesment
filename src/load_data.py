"""
Load the Harborline synthetic CSVs into a local PostgreSQL database.

THIS is the step that turns the CSV files into queryable tables. After it runs,
`SELECT * FROM dim_locations;` works in any IDE connected to the 'harborline' db.

What it does:
  1. ensures the 'harborline' database exists
  2. runs sql/00_schema.sql to (re)create the tables
  3. loads each CSV into its table with correct data types

Usage:  python src/load_data.py
Connection defaults to Postgres.app conventions (your macOS user, no password).
Override with the DATABASE_URL environment variable if your setup differs.
"""
import getpass
import os

import pandas as pd
import sqlalchemy as sa

USER = getpass.getuser()
DB_NAME = "harborline"
DB_URL = os.environ.get(
    "DATABASE_URL",
    f"postgresql+psycopg2://{USER}@localhost:5432/{DB_NAME}",
)

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
SCHEMA = os.path.join(HERE, "..", "sql", "00_schema.sql")

DATE_COLS = {
    "toast_transactions": ["transaction_date"],
    "qu_transactions": ["order_date"],
    "r365_gl_entries": ["posting_date"],
}
TABLES = [
    "dim_locations", "toast_transactions", "qu_transactions",
    "r365_gl_entries", "qu_location_crosswalk",
]


def ensure_database():
    """Create the harborline db if missing (connect to a maintenance db first)."""
    for maint in (USER, "postgres", "template1"):
        try:
            admin = sa.create_engine(
                f"postgresql+psycopg2://{USER}@localhost:5432/{maint}",
                isolation_level="AUTOCOMMIT",
            )
            with admin.connect() as cx:
                exists = cx.execute(
                    sa.text("SELECT 1 FROM pg_database WHERE datname = :n"),
                    {"n": DB_NAME},
                ).scalar()
                if not exists:
                    cx.execute(sa.text(f'CREATE DATABASE "{DB_NAME}"'))
                    print(f"created database '{DB_NAME}'")
                else:
                    print(f"database '{DB_NAME}' already exists")
            return
        except Exception:
            continue
    print("Could not auto-create the database. Create it manually, e.g.: createdb harborline")


def main():
    ensure_database()
    engine = sa.create_engine(DB_URL)

    with engine.begin() as cx:
        cx.exec_driver_sql(open(SCHEMA).read())
    print("schema created (tables are empty, ready to load)")

    for t in TABLES:
        df = pd.read_csv(os.path.join(DATA, f"{t}.csv"),
                         parse_dates=DATE_COLS.get(t, []))
        df.to_sql(t, engine, if_exists="append", index=False)
        print(f"loaded {t:24s} {len(df):>7,} rows")

    print("\nDone. Tables are live in the 'harborline' database.")
    print("Connect VS Code (SQLTools) to it and run sql/01 then sql/02 -")
    print("or just try:  SELECT brand, COUNT(*) FROM dim_locations GROUP BY brand;")


if __name__ == "__main__":
    main()
