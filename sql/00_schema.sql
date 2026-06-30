-- =============================================================
-- Harborline Foods - table schema
-- Creates the tables the CSVs load into. 
-- Runs in PostgreSQL; portable to SQL Server (T-SQL) 
-- =============================================================

DROP TABLE IF EXISTS toast_transactions;
DROP TABLE IF EXISTS qu_transactions;
DROP TABLE IF EXISTS r365_gl_entries;
DROP TABLE IF EXISTS qu_location_crosswalk;
DROP TABLE IF EXISTS dim_locations;

-- Conformed location dimension. Grain: one row per location.
-- NOTE: no qu_store_code column yet - that gap is what Task 1 fixes.
CREATE TABLE dim_locations (
    location_key   INT PRIMARY KEY,
    location_name  VARCHAR(100),
    brand          VARCHAR(50),
    region         VARCHAR(50),
    toast_loc_id   VARCHAR(20)      -- Brand A only; NULL for Brand B
);

CREATE TABLE toast_transactions (
    transaction_id    VARCHAR(20),
    location_id       VARCHAR(20),
    transaction_date  DATE,
    net_sales         DECIMAL(12,2),   -- already net of discounts
    discount_amount   DECIMAL(12,2),
    covers            INT
);

CREATE TABLE qu_transactions (
    order_id          VARCHAR(20),
    store_code        VARCHAR(20),     -- STR-B##
    order_date        DATE,
    gross_sales       DECIMAL(12,2),   -- net must be derived: gross - promo
    promo_deductions  DECIMAL(12,2),
    guest_count       INT
);

CREATE TABLE r365_gl_entries (
    entry_id       VARCHAR(20),
    location_code  VARCHAR(20),
    account_code   INT,              -- 5xxx = COGS, 6xxx = Labor
    account_name   VARCHAR(100),
    posting_date   DATE,
    amount         DECIMAL(12,2)     -- costs stored negative
);

-- The authoritative Qu store -> location map (sourced from the Qu admin).
-- This is the crosswalk that was never loaded into dim_locations.
CREATE TABLE qu_location_crosswalk (
    location_key   INT,
    location_name  VARCHAR(100),
    qu_store_code  VARCHAR(20)
);

