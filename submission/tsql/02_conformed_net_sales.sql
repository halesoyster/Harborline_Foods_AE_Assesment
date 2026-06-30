-- =============================================================
-- TASK 2 - Conformed net sales CTE (T-SQL / SQL Server)
-- One conformed net_sales per transaction across Toast + Qu,
-- joined to the conformed location dimension.
-- Output grain: one row per transaction.
-- Columns: net_sales, location_key, transaction_date.
--
-- Dialect: T-SQL (SQL Server / Microsoft Fabric)
-- This query is ANSI-standard - it runs unchanged in PostgreSQL
-- and SQL Server. No syntax deltas from the Postgres version.
-- Run Task 1 first so the Qu join resolves.
-- Validated: conformed_rows=17,897 = toast(14,316) + qu(3,581);
--            net_sales $6,384,775.01 ties to source totals.
-- =============================================================

WITH toast_net AS (
    -- Toast net_sales is ALREADY net of discounts; join on the Toast key.
    SELECT
        d.location_key,
        t.transaction_date            AS transaction_date,
        t.net_sales                   AS net_sales
    FROM toast_transactions t
    JOIN dim_locations d
      ON d.toast_loc_id = t.location_id
),
qu_net AS (
    -- Qu has no net column: derive net = gross_sales - promo_deductions.
    -- Join on the conformed qu_store_code added in Task 1.
    SELECT
        d.location_key,
        q.order_date                        AS transaction_date,
        q.gross_sales - q.promo_deductions  AS net_sales
    FROM qu_transactions q
    JOIN dim_locations d
      ON d.qu_store_code = q.store_code
),
conformed_net_sales AS (
    SELECT location_key, transaction_date, net_sales FROM toast_net
    UNION ALL
    SELECT location_key, transaction_date, net_sales FROM qu_net
)
SELECT location_key, transaction_date, net_sales
FROM conformed_net_sales;

-- =============================================================
-- VALIDATION  (run these to prove the model is correct)
-- =============================================================

-- 1. No rows lost: conformed count = Toast rows + Qu rows
--    Expected: conformed_rows = toast_rows + qu_rows
SELECT
  (SELECT COUNT(*) FROM toast_transactions) AS toast_rows,
  (SELECT COUNT(*) FROM qu_transactions)    AS qu_rows,
  (SELECT COUNT(*) FROM (
        SELECT 1 FROM toast_transactions t JOIN dim_locations d ON d.toast_loc_id = t.location_id
        UNION ALL
        SELECT 1 FROM qu_transactions q JOIN dim_locations d ON d.qu_store_code = q.store_code
   ) z) AS conformed_rows;

-- 2. No orphans: every transaction resolves to a location_key.
--    Expected: toast_orphans=0, qu_orphans=0
SELECT
  (SELECT COUNT(*) FROM toast_transactions t
     LEFT JOIN dim_locations d ON d.toast_loc_id = t.location_id
     WHERE d.location_key IS NULL) AS toast_orphans,
  (SELECT COUNT(*) FROM qu_transactions q
     LEFT JOIN dim_locations d ON d.qu_store_code = q.store_code
     WHERE d.location_key IS NULL) AS qu_orphans;

-- 3. Reconciliation: conformed total ties to Toast net + Qu net (independent calc).
--    Compare the SUM of toast_net + qu_net to SUM(net_sales) from the CTE above.
SELECT
  (SELECT SUM(net_sales) FROM toast_transactions)                   AS toast_net,
  (SELECT SUM(gross_sales - promo_deductions) FROM qu_transactions) AS qu_net;

-- 4. Brand B presence (the money shot): before vs after.
--
-- BEFORE (run before Task 1): Brand B dollars exist in qu_transactions
-- but the join fails because qu_store_code is not in dim_locations.
-- d.brand comes back NULL - the data is there, it is just unreachable.
SELECT d.brand, COUNT(*) AS transactions, SUM(q.gross_sales - q.promo_deductions) AS net_sales
FROM qu_transactions q
LEFT JOIN dim_locations d ON d.qu_store_code = q.store_code
GROUP BY d.brand;
-- Expected before fix: one row with brand = NULL, net_sales = real dollars.
-- The NULL brand proves the join is failing, not that the data is missing.

-- AFTER (run after Task 1): Brand B resolves and appears by name.
WITH cns AS (
    SELECT d.location_key, t.net_sales AS net_sales
    FROM toast_transactions t JOIN dim_locations d ON d.toast_loc_id = t.location_id
    UNION ALL
    SELECT d.location_key, q.gross_sales - q.promo_deductions
    FROM qu_transactions q JOIN dim_locations d ON d.qu_store_code = q.store_code
)
SELECT d.brand, COUNT(*) AS transactions, SUM(cns.net_sales) AS net_sales
FROM cns
JOIN dim_locations d ON d.location_key = cns.location_key
GROUP BY d.brand
ORDER BY d.brand;
-- Expected after fix: Brand A and Brand B both appear with real dollars.
