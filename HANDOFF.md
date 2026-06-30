# HANDOFF - Harborline Foods AE III Assessment (technical execution)

This doc lets a fresh Cowork thread (Sonnet) finish the technical build. Hale can paste the whole thing, or hand off one step at a time to manage tokens. Connect the **job-search** folder in the new thread first.

---

## Read this first (new thread)

You are finishing a take-home technical assessment for Hale - the Analytics Engineer III role at Blue Margin. Strategy and the core files are already done. Your job is technical execution of the remaining steps.

**Before anything, read `blue-margin-assessment/docs/context.md` in the connected job-search folder.** It is the full source-of-truth spec: scenario, schema, assumptions, validation plan, and per-task acceptance criteria. Then skim `docs/brief.md`. Everything you build derives from `context.md`.

**Deadline:** submission due EOD **Thursday, July 3, 2026**, to Megan Ehlers (megan.ehlers@bluemargin.com).

## Guardrails (Hale's preferences - follow exactly)

- **No em-dashes** anywhere in writing. Use a plain hyphen. Hard rule.
- Deliverable SQL dialect is **T-SQL** (SQL Server / Fabric). Develop and validate in **Postgres**; the `.sql` files already mark `-- [T-SQL]` deltas.
- **DAX stays thin**; business logic lives in the SQL layer (their rubric).
- **Validation-first**: every SQL claim is shown with output.
- CFO note: honest, calm, specific; **do not throw the prior engineer under the bus**.
- Write concise and direct. Minimal formatting, no filler.

## Where things live

- **Staging folder (your workspace):** `blue-margin-assessment/` inside the connected job-search folder.
- **Hale's local git repo (you CANNOT reach it** - it is outside the connected folder; Hale or Claude Code copies files there): `~/Documents/GitHub/Harborline_Foods_AE_Assesment`

## Execution environment constraint (important)

The Cowork bash sandbox is an isolated Linux box. **It cannot connect to the Postgres.app running on Hale's Mac.** Two ways to actually run SQL:

- **(a) Hale runs locally** in VS Code against Postgres.app (his primary path - he is setting this up now).
- **(b) You self-validate inside the sandbox** by installing Postgres there:
  ```bash
  sudo apt-get update && sudo apt-get install -y postgresql
  sudo service postgresql start
  sudo -u postgres createdb harborline
  ```
  Then run the pipeline against it. Do this to catch bugs and capture proof output before Hale runs it.

## Already built - do not redo

- `docs/context.md`, `docs/brief.md`
- `src/generate_data.py` (synthetic data; Brand B gap baked in)
- `src/load_data.py` (creates db + tables, loads the CSVs)
- `sql/00_schema.sql`, `sql/01_dimension_fix.sql`, `sql/02_conformed_net_sales.sql`
- `requirements.txt`, `.gitignore`, `.env.example`, `README.md`

---

## Remaining steps

Each step is independent. For each: a kickoff line Hale can paste, what to do, and the done-check.

### Step 1 - Validate the SQL pipeline
**Kickoff:** "Validate the Harborline SQL pipeline end to end and show me the output."
**Do:** install Postgres in the sandbox (option b), run `python src/generate_data.py`, then `python src/load_data.py`, then execute `sql/01_dimension_fix.sql` and `sql/02_conformed_net_sales.sql`. Capture the Brand B before/after, the four validation checks, and Brand A vs Brand B net-sales totals. Fix any SQL errors and note what changed.
**Done:** `qu_orphans = 0` after Task 1; `conformed_rows = toast_rows + qu_rows`; Brand B shows non-zero net sales only after the fix; reconciliation totals tie.

### Step 2 - Task 3 DAX measures
**Kickoff:** "Write the Task 3 DAX measures file."
**Do:** create `dax/measures.md` with three measures - `Net Sales [Current Week]`, `Net Sales [Rolling 4-Week Avg]`, `Prime Cost %` - each with the DAX and a one-to-two sentence why. All three are measures, not calculated columns; explain the placement and filter-context reasoning. Assume a `dim_date` with a Monday-start week. Keep it thin: base `[Net Sales]`, `[COGS]`, `[Labor]` measures sit on the SQL-built model. See `context.md` section 8.
**Done:** three correct, commented measures plus a short "measure vs calculated column" note.

### Step 3 - Task 4 CFO note (2 versions)
**Kickoff:** "Draft two versions of the CFO note."
**Do:** create `submission/cfo_note.md`. A 5-to-8-sentence reply to CFO Dana Reyes on why the dashboard is late: the Brand B locations were never mapped to Qu sales, so totals were incomplete; the fix is in; here is the timeline; confident without overpromising. Apply the Supercommunicators lens (acknowledge the frustration first; match her "give me a plan" conversation type). Two distinct tones (e.g. warm-direct vs crisp-executive). No blame on the predecessor.
**Done:** two versions, each 5-8 sentences, honest + specific + confident, no em-dashes.
**Note:** this is Hale's differentiator (external-facing comms). Hale may have drafted these in the Opus thread already - check with him before rewriting.

### Step 4 - Validation notebook
**Kickoff:** "Build the validation notebook."
**Do:** create `notebook/harborline_validation.ipynb` - loads the CSVs to Postgres (reuse `load_data.py`), runs Task 1 + Task 2 + the validation queries via `jupysql`, with markdown narration and inline result tables. This is the proof harness.
**Done:** the notebook runs top to bottom and shows before/after plus validation output inline.

### Step 5 - Header note + AI-usage log
**Kickoff:** "Write the submission header note."
**Do:** create `submission/header_note.md` - tools used (Claude Opus for strategy and docs, Claude Sonnet for the build, Postgres for validation, VS Code), total time spent (ask Hale), and the assumptions list (from `context.md` section 5). Describe AI usage honestly: how it was prompted, verified, and owned. They grade this.
**Done:** a tight top-of-submission note covering tools / time / assumptions / AI usage.

### Step 6 (optional) - ERD diagram
**Kickoff:** "Make an ERD for the model."
**Do:** a simple entity-relationship diagram (`dim_locations`, the two POS facts, `r365_gl_entries`, the crosswalk) as a PNG or Mermaid, mirroring the clean look of Hale's prior Pewlett-Hackard repo. Save to `images/` or `docs/`.
**Done:** a readable ERD committed.

### Step 7 - Clean T-SQL submission copies
**Kickoff:** "Produce clean T-SQL versions of the SQL for submission."
**Do:** create `submission/tsql/01_dimension_fix.sql` and `02_conformed_net_sales.sql` - the validated logic with T-SQL syntax applied (`ADD` without `COLUMN`, `UPDATE...FROM` alias-first; Task 2 is already portable). These are what goes to Blue Margin.
**Done:** two clean T-SQL files matching the validated logic.

### Step 8 - Assemble + push (Hale or Claude Code does the git part)
**Kickoff:** "Help me assemble and push the submission."
**Do:** confirm the file tree is complete, finalize the README, build a single ZIP of the submission. Hale (or Claude Code on his Mac) copies `blue-margin-assessment/` contents into `~/Documents/GitHub/Harborline_Foods_AE_Assesment`, commits, and pushes. Provide the exact git commands.
**Done:** repo pushed public, ZIP assembled, links ready for the email to Megan.

---

## Suggested order

1 (validate) -> 7 (clean T-SQL, fast once validated) -> 2 (DAX) -> 4 (notebook) -> 3 (CFO note) -> 5 (header) -> 6 (ERD, optional) -> 8 (assemble + push).

## When done

Hand back to Hale: the public repo URL, the ZIP, and a three-line summary for the submission email to Megan.
