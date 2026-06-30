-- =============================================================
-- TASK 1 - Conformed dimension fix
-- Add qu_store_code to dim_locations and backfill Brand B so
-- qu_transactions can join. Before / after shown.
--
-- Runs in: PostgreSQL (local validation).
-- T-SQL submission deltas are marked  -- [T-SQL].
-- Grain of dim_locations: one row per physical location.
-- A conformed location dimension carries EVERY source system's
-- natural key (toast_loc_id, qu_store_code, and later r365 code)
-- so any system can resolve to one location_key.
-- =============================================================

-- ---- BEFORE: Brand B has no Qu mapping (column does not exist yet) ----------
SELECT location_key, location_name, brand, toast_loc_id
FROM dim_locations
WHERE brand = 'Brand B'
ORDER BY location_key;

-- ---- 1. Add the conformed Qu key -------------------------------------------
ALTER TABLE dim_locations ADD COLUMN qu_store_code VARCHAR(10);
-- [T-SQL] SQL Server omits COLUMN:
--   ALTER TABLE dim_locations ADD qu_store_code VARCHAR(10);

-- ---- 2. Backfill from the authoritative Qu crosswalk -----------------------
-- The crosswalk is the store->location map sourced from the Qu admin;
-- it was simply never loaded into the dimension - that is the bug.
UPDATE dim_locations AS d
SET    qu_store_code = x.qu_store_code
FROM   qu_location_crosswalk AS x
WHERE  d.location_key = x.location_key;
-- [T-SQL] SQL Server puts the alias first in UPDATE...FROM:
--   UPDATE d
--   SET    d.qu_store_code = x.qu_store_code
--   FROM   dim_locations d
--   JOIN   qu_location_crosswalk x ON d.location_key = x.location_key;

-- ---- AFTER: Brand B now carries its Qu store code --------------------------
SELECT location_key, location_name, brand, toast_loc_id, qu_store_code
FROM dim_locations
WHERE brand = 'Brand B'
ORDER BY location_key;

-- ---- VALIDATION ------------------------------------------------------------
-- (a) every Brand B location is now mapped
SELECT
    COUNT(*)                         AS brand_b_locations,
    COUNT(qu_store_code)             AS mapped,
    COUNT(*) - COUNT(qu_store_code)  AS still_missing
FROM dim_locations
WHERE brand = 'Brand B';

-- (b) no Qu store code in the transactions is left without a dimension match
SELECT DISTINCT q.store_code
FROM qu_transactions q
LEFT JOIN dim_locations d ON d.qu_store_code = q.store_code
WHERE d.qu_store_code IS NULL;
