# Harborline Foods - Engagement Context & Build Spec

**Audience:** the engineer (or AI agent) executing this build. This is the source-of-truth doc. Read it before writing or running anything. Everything else in the repo derives from what is written here.

**How to use it:** the SQL, the DAX, and the validation notebook are all generated against the schema, assumptions, and acceptance criteria below. If an assumption here is wrong, fix it here first, then regenerate downstream. Claude Code: treat the "Build instructions" and "Task specs" sections as your work order.

---

## 1. The engagement in one paragraph

Harborline Foods is a mid-market, multi-brand restaurant group: three brands across 40+ locations, recently combined through two acquisitions. Transactional and financial data lives in three source systems that do not talk to each other (Toast POS, Qu POS, Restaurant365). The CFO, Dana Reyes, wants one executive P&L view across every brand and location. We are in week three of the engagement; the prior engineer left a partially built semantic layer in rough shape, and Dana is frustrated with the delay. Our job is to conform the sources into one trustworthy model and stand up the two views she asked for.

## 2. What Dana asked for

1. **Net Sales and COGS by brand, location, and week**, with a rolling 4-week trend.
2. **A Prime Cost view** (labor + COGS as a percent of net sales), filterable by brand or location.

## 3. Source systems

| System | Scope | Grain of the sample | Key fields |
|---|---|---|---|
| Toast POS | Brand A (28 locations) | one row per transaction | `transaction_id`, `location_id`, `transaction_date`, `net_sales`, `discount_amount`, `covers` |
| Qu POS | Brand B (9 locations) | one row per order | `order_id`, `store_code`, `order_date`, `gross_sales`, `promo_deductions`, `guest_count` |
| Restaurant365 (R365) | All brands | one row per GL entry | `entry_id`, `location_code`, `account_code`, `account_name`, `posting_date`, `amount` |
| `dim_locations` (partial) | All brands | one row per location | `location_key`, `location_name`, `brand`, `region`, `toast_loc_id` |

## 4. The data-quality finding (the heart of this exercise)

`dim_locations` has **no `qu_store_code` column**. Qu identifies stores as `STR-B##` (e.g. `STR-B02`, `STR-B09`). That value exists in the Qu source but was never mapped into the dimension, so **Brand B's 9 locations cannot be joined to their sales**. Net effect: every Brand B dollar is currently missing from the conformed model. That is why Dana's numbers look wrong and why the dashboard stalled. Task 1 fixes it; Task 2 depends on the fix; Task 4 explains it to Dana.

**The larger pattern to surface (AE-III judgment):** a true conformed location dimension needs *all three* source keys, not two. It holds `toast_loc_id`, `qu_store_code`, and `r365_location_code` so any source system can resolve to one `location_key`. Task 1 adds the Qu key. The R365 key is the same pattern and is flagged as the immediate next step (for Brand A, R365's `LOC-##` codes appear to line up with `toast_loc_id`; Brand B's R365 mapping needs the same crosswalk treatment).

## 5. Assumptions log

Stated, reasonable, documented. In a live engagement each of these is a one-line confirm with the client; we make the call and move rather than blocking.

1. **Week = Monday-start fiscal week (Mon-Sun).** Weekly rollups and the rolling 4-week window bucket on Monday week-start. Many restaurant groups run a 4-4-5 calendar; if Harborline does, swap the week logic for a fiscal-calendar dimension. Flag to confirm with Dana.
2. **Toast `net_sales` is already net of discounts.** The column is named `net_sales` and `discount_amount` is carried separately as informational. So Toast net = `net_sales`. (If it turns out to be gross, net = `net_sales - discount_amount` - confirm.)
3. **Qu has no net column; net = `gross_sales - promo_deductions`.** This is the core column-naming difference between the two POS systems.
4. **Join keys:** Toast joins `dim_locations` on `toast_loc_id = toast_transactions.location_id`. Qu joins on `qu_store_code = qu_transactions.store_code` (after the Task 1 backfill).
5. **`qu_store_code` backfill needs an authoritative crosswalk.** There is no deterministic key linking a Qu store code to a `location_key` - that is exactly what was never built. For this exercise we construct a documented mapping (`location_key` -> `STR-B##`) and treat it as the crosswalk we would source from the Qu admin / client in real life. The synthetic data defines this mapping so the fix is reproducible and provable.
6. **R365 sign convention:** GL amounts are stored negative for costs (`-142.00` for COGS). Reporting flips the sign (use `ABS()` or negate) so COGS and Labor read as positive costs.
7. **Account classification (R365):** COGS = `account_code` in the 5xxx range (e.g. 5100 Food COGS); Labor = 6xxx range (e.g. 6000 Labor - Hourly). Net sales for the Prime Cost denominator comes from the conformed POS net sales (Toast + Qu), not from R365 sales accounts, to keep one definition of net sales across the model.
8. **Currency USD; dates are location-local business dates.** Voids (Toast) and any returns are assumed already excluded from `net_sales`. Time zones not modeled at this grain.

## 6. Target model (Kimball / dimensional)

- **Grain of the conformed fact:** one row per POS transaction (Task 2 output is `net_sales`, `location_key`, `transaction_date` at this grain). A production build would land a `fct_sales` at transaction grain and a `fct_gl` at GL-entry grain, both conforming to `dim_locations` and `dim_date`.
- **Conformed dimensions:** `dim_locations` (one row per physical location, holding every source system's natural key) and `dim_date` (one row per day, carrying the Mon-start `week_start_date` used for all weekly logic).
- **Why this shape:** Power BI consumes star schemas natively; single-direction filtering dimension -> fact. Keeping net-sales conforming, sign flips, and account classification in the SQL/model layer (not DAX) is both their stated rubric ("logic belongs in the SQL layer, not DAX") and what keeps the measures thin and maintainable.
- **dbt -> Microsoft framing:** staging -> intermediate -> marts maps onto bronze -> silver -> gold. The dimensional models live in the gold/serving layer regardless of platform.

## 7. Validation plan (run these, show the output)

Validation is the headline skill for this role. Every claim gets proof.

- **Grain integrity:** `COUNT(*)` vs `COUNT(DISTINCT <transaction id>)` per source - confirm no accidental fan-out from the dimension join.
- **No lost rows:** conformed row count = Toast rows + Qu rows.
- **No orphan keys:** zero NULL `location_key` after the join. *Before* the Task 1 fix, Brand B rows orphan (proves the bug); *after*, they resolve (proves the fix).
- **Reconciliation:** `SUM(conformed net_sales)` ties to `SUM(Toast net) + SUM(Qu net)` computed independently.
- **Brand B presence:** Brand B net sales = 0 / missing before the fix, non-zero after. This is the money shot - show it as a before/after.
- **Sanity:** date ranges inside the expected window; no unexpected negative net sales.

## 8. Task specs (acceptance criteria)

**Task 1 - Conformed dimension fix** (`sql/01_dimension_fix.sql`)
- `ALTER TABLE dim_locations ADD qu_store_code VARCHAR(10);`
- Backfill `qu_store_code` for Brand B rows from the documented crosswalk.
- Show **before** (Brand B `qu_store_code` NULL) and **after** (populated).
- Comment the grain (one row per location) and the conformed-key intent.
- Acceptance: every Brand B location has a non-null `qu_store_code` that matches a `STR-B##` present in `qu_transactions`.

**Task 2 - Conformed net sales CTE** (`sql/02_conformed_net_sales.sql`)
- A T-SQL CTE returning one row per transaction: `net_sales`, `location_key`, `transaction_date`.
- Toast branch: `net_sales` as-is, join on `toast_loc_id`.
- Qu branch: `gross_sales - promo_deductions` as `net_sales`, `order_date` as `transaction_date`, join on `qu_store_code`.
- `UNION ALL` the branches. Handle the column-name differences explicitly.
- Include the validation queries from section 7 as commented checks.
- Acceptance: row count and net-sales total reconcile; zero NULL `location_key`.

**Task 3 - DAX measures** (`dax/measures.md`)
- `Net Sales [Current Week]`, `Net Sales [Rolling 4-Week Avg]`, `Prime Cost %`.
- All three are **measures**, not calculated columns - with a written why (aggregations evaluated in filter context, must respond to brand/location/week slicers; calculated columns would be static, wrong, and bloat the model).
- Use `CALCULATE`, time intelligence on `dim_date`, and `DIVIDE` for safe division.
- Base measures (`[Net Sales]`, `[COGS]`, `[Labor]`) defined thin on top of the SQL-built model.
- Keep logic in SQL; DAX only shapes filter context.

**Task 4 - CFO stakeholder note** (`submission/cfo_note.md`)
- 5-8 sentences to Dana. Acknowledge the frustration, name the Brand B mapping gap plainly, name the fix, give a concrete timeline, close with confidence and no overpromising. Do not throw the prior engineer under the bus.

**Header note** (`submission/header_note.md`)
- Tools used, total time spent, assumptions (pull from section 5), and the AI-usage log.

## 9. Build instructions (for Claude Code on the Mac)

- Stand up SQL Server locally via Docker (`mcr.microsoft.com/mssql/server` or Azure SQL Edge), creds in `.env` (gitignored; ship `.env.example`).
- Run `src/generate_data.py` to produce the synthetic CSVs into `data/` (commit them - they are fake and keep the build reproducible).
- Create the tables, load the CSVs, run `sql/01_*` then `sql/02_*`, capture before/after + validation output.
- Build `notebook/harborline_validation.ipynb` as the proof harness: generate -> load -> run SQL -> show validation tables inline.
- Keep the submitted `.sql` files clean; the notebook is the evidence.
- Assemble the ZIP, commit, push to the public repo.

## 10. Repo structure

```
Harborline_Foods_AE_Assesment/
  README.md                      # overview + how to run + AI-usage summary
  .gitignore
  .env.example
  docs/
    brief.md                     # Doc 1 - stakeholder brief
    context.md                   # Doc 2 - this file
  data/                          # generated synthetic CSVs (committed)
  src/
    generate_data.py             # synthetic data generator
  sql/
    01_dimension_fix.sql         # Task 1
    02_conformed_net_sales.sql   # Task 2
  dax/
    measures.md                  # Task 3
  notebook/
    harborline_validation.ipynb  # proof harness (Claude Code builds/executes)
  submission/
    cfo_note.md                  # Task 4
    header_note.md               # tools / time / assumptions / AI usage
```

## 11. AI-usage log (fill as we go - this is graded)

They explicitly evaluate whether you prompt effectively, verify output, and own the result. Keep this honest and specific.

- **Cowork (Claude Opus, this session):** strategy, the brief and this context doc, draft SQL/DAX, the CFO note. Used as a thinking partner to structure the conformed-dimension approach and the validation plan.
- **Claude Code (local):** executed the SQL against real SQL Server, ran validation, built the notebook. *To be logged with specifics after the build.*
- **Verification:** every SQL claim is backed by executed validation output in the notebook; DAX reviewed line-by-line for filter-context correctness so it can be defended live.
