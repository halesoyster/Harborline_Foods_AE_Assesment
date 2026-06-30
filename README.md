# Harborline Foods - Analytics Engineer III Technical Assessment

A conformed P&L model across three restaurant source systems (Toast POS, Qu POS, Restaurant365) for a fictional multi-brand restaurant group, **Harborline Foods**. Built for the Blue Margin AE III take-home.

> **SQL dialect:** the deliverable targets **T-SQL** (SQL Server / Microsoft Fabric, Blue Margin's stack). It is developed and validated locally in **PostgreSQL**; the handful of dialect differences are marked `-- [T-SQL]` inline in each script.

## How the pieces fit

CSV files are not a database - you cannot run `SELECT * FROM dim_locations` against a folder of CSVs. The data has to be **loaded into Postgres tables** first. The flow:

```
generate_data.py  ->  data/*.csv  ->  load_data.py  ->  Postgres tables  ->  run sql/*.sql
   (make data)        (flat files)   (create + load)    (queryable!)        (the tasks)
```

## Repo layout

```
.
├── README.md
├── requirements.txt
├── .env.example
├── data/                          # synthetic CSVs (committed, reproducible)
├── src/
│   ├── generate_data.py           # builds the synthetic CSVs
│   └── load_data.py               # creates the db + tables, loads the CSVs
├── sql/
│   ├── 00_schema.sql              # table definitions
│   ├── 01_dimension_fix.sql       # Task 1
│   └── 02_conformed_net_sales.sql # Task 2
├── docs/
│   ├── brief.md                   # stakeholder brief
│   └── context.md                 # full build spec + assumptions
└── submission/                    # CFO note, header note (added later)
```

## Run it locally (Postgres.app + VS Code)

**1. Install Postgres.** Download [Postgres.app](https://postgresapp.com), move it to Applications, open it, click **Initialize**. You now have a server on `localhost:5432` (your macOS username is the superuser, no password). Closing the app stops the server.

**2. Python deps.**
```bash
pip install -r requirements.txt
```

**3. Generate the data.**
```bash
python src/generate_data.py
```
Writes five CSVs into `data/`, with Brand B intentionally unmapped so the Task 1 fix is provable.

**4. Load the data into Postgres** (this is the step that makes the tables queryable).
```bash
python src/load_data.py
```
Creates the `harborline` database, builds the tables from `sql/00_schema.sql`, and loads the CSVs. When it finishes, the tables are live.

**5. Run and test the SQL in VS Code.** Install the **SQLTools** extension and the **SQLTools PostgreSQL/Cockroach Driver**. Add a connection:
- Server: `localhost`  Port: `5432`  Database: `harborline`
- Username: your macOS username  Password: (leave blank)

Open `sql/01_dimension_fix.sql`, then `sql/02_conformed_net_sales.sql`, and run them. Each prints before/after and validation output. You can now also run ad-hoc queries like `SELECT * FROM dim_locations;`.

> Prefer a notebook? `jupysql` is already installed. In a `.ipynb`: `%load_ext sql`, then `%sql postgresql+psycopg2://<youruser>@localhost:5432/harborline`, then `%%sql` cells - result tables render inline.

## The tasks

| # | File | What |
|---|------|------|
| 1 | `sql/01_dimension_fix.sql` | Add + backfill `qu_store_code` so Brand B joins to its sales. |
| 2 | `sql/02_conformed_net_sales.sql` | Conformed net sales across Toast + Qu, with validation. |
| 3 | `dax/measures.md` | Power BI DAX measures (Current Week, Rolling 4-Week, Prime Cost %). |
| 4 | `submission/cfo_note.md` | Stakeholder note to the CFO. |

See `docs/brief.md` for the stakeholder framing and `docs/context.md` for the full spec, assumptions, and validation plan.
