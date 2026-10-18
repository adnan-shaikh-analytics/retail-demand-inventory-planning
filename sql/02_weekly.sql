
-- Script 2: Build weekly sales and revenue

-- 1. Keep only complete Saturday-to-Friday weeks
CREATE OR REPLACE TABLE week_index AS
SELECT
    wm_yr_wk,
    MIN("date") AS week_start,
    ROW_NUMBER() OVER (ORDER BY wm_yr_wk) AS wk
FROM calendar
WHERE CAST(SUBSTR(d, 3) AS INTEGER) <= 1941
GROUP BY wm_yr_wk
HAVING COUNT(*) = 7;

-- 2. Store the analysis windows and assumptions
CREATE OR REPLACE TABLE params AS
SELECT
    MAX(wk) AS last_wk,
    MAX(wk) - 12 AS test_start,
    MAX(wk) AS test_end,
    MAX(wk) - 38 AS calib_start,
    MAX(wk) - 13 AS calib_end,
    MAX(wk) - 64 AS class_start,
    MAX(wk) - 13 AS class_end,
    0.70 AS cogs_pct,
    0.25 AS hold_rate
FROM week_index;

-- 3. Aggregate daily sales into weekly SKU-level data
CREATE OR REPLACE TABLE weekly AS
SELECT
    l.item_id || '_' || l.store_id AS series_id,
    l.item_id,
    l.store_id,
    l.dept_id,
    l.cat_id,
    wi.wk,
    wi.wm_yr_wk,
    wi.week_start,
    SUM(l.units) AS units,
    MAX(pr.sell_price) AS sell_price,
    SUM(l.units * COALESCE(pr.sell_price, 0)) AS revenue
FROM sales_long l
JOIN calendar c
    ON c.d = l.d
JOIN week_index wi
    ON wi.wm_yr_wk = c.wm_yr_wk
LEFT JOIN prices pr
    ON pr.item_id = l.item_id
    AND pr.store_id = l.store_id
    AND pr.wm_yr_wk = c.wm_yr_wk
CROSS JOIN params p
WHERE wi.wk >= p.last_wk - 119
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8;

-- 4. Check the analysis settings
SELECT * FROM params;

-- 5. Verify the weekly table
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT series_id) AS skus,
    COUNT(DISTINCT wk) AS weeks,
    MAX(wm_yr_wk) AS last_week_id
FROM weekly;
