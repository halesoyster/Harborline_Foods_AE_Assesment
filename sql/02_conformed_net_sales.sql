-- =============================================================
-- TASK 2 - Conformed net sales CTE
-- One conformed net_sales per transaction across Toast + Qu,
-- joined to the conformed location dimension.
-- Output grain: one row per transaction.
-- Columns: net_sales, location_key, transaction_date.
--
-- This query is ANSI-standard - it runs unchanged in PostgreSQL
-- and SQL Server (T-SQL). Run Task 1 first so the Qu join resolves.
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
SELECT
  (SELECT COUNT(*) FROM toast_transactions) AS toast_rows,
  (SELECT COUNT(*) FROM qu_transactions)    AS qu_rows,
  (SELECT COUNT(*) FROM (
        SELECT 1 FROM toast_transactions t JOIN dim_locations d ON d.toast_loc_id = t.location_id
        UNION ALL
        SELECT 1 FROM qu_transactions q JOIN dim_locations d ON d.qu_store_code = q.store_code
   ) z) AS conformed_rows;

-- 2. No orphans: every transaction resolves to a location_key.
--    Qu orphans are non-zero BEFORE Task 1 and zero AFTER - that is the fix.
SELECT
  (SELECT COUNT(*) FROM toast_transactions t
     LEFT JOIN dim_locations d ON d.toast_loc_id = t.location_id
     WHERE d.location_key IS NULL) AS toast_orphans,
  (SELECT COUNT(*) FROM qu_transactions q
     LEFT JOIN dim_locations d ON d.qu_store_code = q.store_code
     WHERE d.location_key IS NULL) AS qu_orphans;

-- 3. Reconciliation: conformed total ties to Toast net + Qu net (independent calc)
SELECT
  (SELECT SUM(net_sales) FROM toast_transactions)                   AS toast_net,
  (SELECT SUM(gross_sales - promo_deductions) FROM qu_transactions) AS qu_net;
-- compare the sum of the two above to SUM(net_sales) from the Task 2 result set.

-- 4. Brand B presence (the money shot): zero before Task 1, real dollars after.
WITH cns AS (
    SELECT d.location_key, t.net_sales AS net_sales
    FROM toast_transactions t JOIN dim_locations d ON d.toast_loc_id = t.location_id
    UNION ALL
    SELECT d.location_key, q.gross_sales - q.promo_deductions
    FROM qu_transactions q JOIN dim_locations d ON d.qu_store_code = q.store_code
)
SELECT d.brand, COUNT(*) AS txns, SUM(cns.net_sales) AS net_sales
FROM cns
JOIN dim_locations d ON d.location_key = cns.location_key
GROUP BY d.brand
ORDER BY d.brand;
