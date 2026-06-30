# Harborline Foods - DAX Measures

All three measures live in the report's Measures table (or a dedicated _Measures table).
They are **measures**, not calculated columns - see the note at the bottom on why that distinction matters here.

Base measures are defined thin on top of the SQL-built model:

```dax
[Net Sales] = SUM(fct_sales[net_sales])
[COGS]      = SUM(fct_gl[cogs_amount])
[Labor]     = SUM(fct_gl[labor_amount])
```

`fct_sales` is the output of `02_conformed_net_sales.sql` joined to `dim_locations`.
`fct_gl` carries COGS and labor from R365 with sign flipped positive (done in SQL).
`dim_date` has one row per day with a `week_start_date` column (Monday anchor).

---

## 1. Net Sales [Current Week]

Returns net sales for whichever week is in the current filter context - typically the most recent complete week when sliced by `dim_date[week_start_date]`.

```dax
Net Sales [Current Week] =
CALCULATE(
    [Net Sales],
    FILTER(
        ALL( dim_date ),
        dim_date[week_start_date] = MAX( dim_date[week_start_date] )
    )
)
```

**Why:** `CALCULATE` replaces the filter context on `dim_date` so this measure resolves to
exactly one week regardless of what else is on the slicer. `MAX(dim_date[week_start_date])`
picks the latest week visible in the current context - so it advances automatically as new
data loads. Brand and location slicers still apply because only the date filter is overridden.

---

## 2. Net Sales [Rolling 4-Week Avg]

Weekly average net sales over the trailing four weeks, ending at the latest date in context.

```dax
Net Sales [Rolling 4-Week Avg] =
VAR LastDateInContext = MAX( dim_date[Date] )
RETURN
CALCULATE(
    AVERAGEX( VALUES( dim_date[week_start_date] ), [Net Sales] ),
    DATESINPERIOD( dim_date[Date], LastDateInContext, -28, DAY )
)
```

**Why:** `DATESINPERIOD` is the time-intelligence function that builds the trailing 28-day
(four-week) window from the last date in the current context, so the measure recomputes
correctly at every point on a trend line. `AVERAGEX` then iterates the distinct weeks in
that window (`VALUES( dim_date[week_start_date] )`) and averages each week's net-sales
total - the right grain for a four-week average, and safe when an early week is only
partially present (it averages the weeks that exist instead of always dividing by 4).
Brand and location slicers still apply, because only the date axis is overridden.

> **Model requirement:** `dim_date` must be marked as the model's official **Date table**
> (Table tools > Mark as date table), with one contiguous row per day, or `DATESINPERIOD`
> and other time-intelligence functions will not resolve.

---

## 3. Prime Cost %

Labor plus COGS as a percentage of net sales. Filterable by brand or location.

```dax
Prime Cost % =
DIVIDE(
    [COGS] + [Labor],
    [Net Sales],
    BLANK()
)
```

**Why:** `DIVIDE` handles zero net sales safely - it returns `BLANK()` instead of an error,
which Power BI treats as empty rather than displaying an infinity symbol. The denominator
uses `[Net Sales]` from the conformed POS model (Toast + Qu combined), not R365 revenue
accounts - keeping one definition of net sales across the entire model. COGS and Labor
are already positive (sign flipped in SQL), so the ratio reads as a cost percentage
without any negation in DAX.

---

## Measures vs. calculated columns - why this matters

A **calculated column** is computed row by row at data refresh time and stored in the model.
It does not respond to slicers or filters applied at report runtime - the value is fixed
the moment the refresh runs. For a metric like "current week net sales" or "prime cost %
for the locations I have filtered," a calculated column would give the same number
regardless of what the user selects.

A **measure** is evaluated on demand inside whatever filter context exists at the moment
a visual renders. When Dana filters to Brand B or drills into a single location, every
measure above recalculates against only the rows that pass through that filter. That is
exactly what she needs for an executive P&L she can slice.

Calculated columns also bloat the in-memory model with a stored value for every row.
Measures add no storage cost - they are formulas that run at query time against already-
compressed columns. For a fact table at transaction grain (17,000+ rows, growing weekly),
keeping aggregation logic in measures is both more correct and more efficient.
