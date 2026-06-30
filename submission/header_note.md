# Submission Note - Harborline Foods Analytics Engineer III Assessment

**Submitted by:** Hale Soyster
**Submitted to:** Megan Ehlers, Blue Margin
**Date:** July 3, 2026

---

## Tools used

- **Claude Opus (Anthropic)** - strategy, engagement framing, core document drafts (context.md, brief.md), initial SQL and DAX structure, CFO note drafts
- **Claude Sonnet (Anthropic)** - technical build execution: SQL validation, DAX measures, T-SQL submission files, validation notebook
- **DuckDB** - in-process SQL engine used for sandbox validation (same ANSI syntax as PostgreSQL/SQL Server; dialect-specific T-SQL deltas noted in comments)
- **Python 3 / pandas / nbformat** - synthetic data generation and notebook construction
- **VS Code** - local development and file review
- **Git / GitHub** - version control and public repo for submission

**Total time:** [FILL IN - approx X hours across Y sessions]

---

## Assumptions

The following assumptions were made in lieu of client confirmation. Each is stated, reasonable, and flagged as a one-line confirm with Dana before the dashboard goes live.

1. **Week = Monday-start fiscal week (Mon-Sun).** Weekly rollups and the rolling 4-week window anchor on Monday. If Harborline runs a 4-4-5 fiscal calendar, the week logic swaps for a fiscal-calendar dimension.
2. **Toast `net_sales` is already net of discounts.** The column name and the presence of a separate `discount_amount` field support this reading. If it is gross, the formula becomes `net_sales - discount_amount`.
3. **Qu net sales = `gross_sales - promo_deductions`.** Qu carries no pre-computed net column; this derivation is the core column-naming difference between the two POS systems.
4. **`qu_store_code` backfill sourced from the Qu admin crosswalk.** There is no deterministic key linking Qu store codes to the location dimension in the provided data - that is exactly what was never built. The crosswalk (`qu_location_crosswalk.csv`) represents the mapping we would confirm with the client in a real engagement.
5. **R365 GL amounts are stored negative for costs.** Reporting flips the sign so COGS and Labor read as positive values. Sign convention confirmed from the synthetic data generator; flag to verify against the live R365 export.
6. **Account classification: COGS = 5xxx range, Labor = 6xxx range.** Prime Cost uses these two account families from R365, with net sales from the conformed POS model as the denominator - keeping one definition of net sales across the entire model.
7. **Currency USD; dates are location-local business dates.** Voids and returns assumed already excluded from `net_sales` in the source systems.

---

## AI usage - how I worked with it

Claude was used as a thinking partner and execution tool throughout, not as a black box. Here is specifically how:

**Strategy and structure (Opus):** I prompted Opus with the assessment brief and walked through the scenario together - identifying the Brand B gap as the core data-quality finding, designing the conformed dimension approach, and structuring the validation plan. I reviewed the output of each prompt before moving forward. Opus drafted the first versions of `context.md`, `brief.md`, the SQL skeleton, and the CFO note; I edited each for accuracy and tone.

**Technical build (Sonnet):** I used a handoff document to brief a new session with the full spec. Sonnet ran the data generation and SQL validation pipeline, built the DAX measures and T-SQL submission files, and constructed the validation notebook. I reviewed each output for correctness - specifically the DAX filter-context reasoning, the T-SQL syntax deltas (ALTER TABLE without COLUMN, UPDATE...FROM alias order), and the validation assertion logic.

**Verification:** every SQL claim in the submission is backed by executed validation output in the notebook. The DAX measures were reviewed line by line for filter-context correctness so they can be defended live in a review.

**Ownership:** I understand every piece of this submission. I can explain the Brand B mapping gap and the fix, walk through the CTE logic, defend the DAX measure vs. calculated column choice, and speak to each assumption above. The AI accelerated the work; the judgment and the accountability are mine.
