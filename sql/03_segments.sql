-- 1. Calculate revenue and demand variability for each SKU
CREATE OR REPLACE TABLE sku_stats AS
SELECT
    w.series_id,
    w.item_id,
    w.store_id,
    w.dept_id,
    w.cat_id,
    SUM(w.units) AS units_52w,
    SUM(w.revenue) AS revenue_52w,
    AVG(w.units) AS avg_weekly_units,
    STDDEV_SAMP(w.units) AS sd_weekly_units,
    STDDEV_SAMP(w.units) / NULLIF(AVG(w.units), 0) AS cv,
    SUM(CASE WHEN w.units > 0 THEN 1 ELSE 0 END) AS weeks_with_sales,
    SUM(w.revenue) / NULLIF(SUM(w.units), 0) AS avg_price
FROM weekly w
CROSS JOIN params p
WHERE w.wk BETWEEN p.class_start AND p.class_end
GROUP BY 1, 2, 3, 4, 5;

-- 2. Keep active SKUs and calculate cumulative revenue share
CREATE OR REPLACE TABLE sku_segments AS
WITH active AS (
    SELECT *
    FROM sku_stats
    WHERE weeks_with_sales >= 26
      AND revenue_52w > 0
),
ranked AS (
    SELECT *,
        SUM(revenue_52w) OVER (ORDER BY revenue_52w DESC)
            / SUM(revenue_52w) OVER () AS cum_rev_share
    FROM active
),
labeled AS (
    SELECT *,
        CASE
            WHEN cum_rev_share <= 0.80 THEN 'A'
            WHEN cum_rev_share <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc,
        CASE
            WHEN cv <= 0.5 THEN 'X'
            WHEN cv <= 1.0 THEN 'Y'
            ELSE 'Z'
        END AS xyz
    FROM ranked
)
SELECT *,
    abc || xyz AS abc_xyz
FROM labeled;

-- 3. Count all SKUs and retained SKUs
SELECT
    (SELECT COUNT(*) FROM sku_stats) AS all_skus,
    (SELECT COUNT(*) FROM sku_segments) AS kept_skus;

-- 4. Show the ABC-XYZ grid
SELECT
    abc,
    xyz,
    COUNT(*) AS skus,
    ROUND(SUM(revenue_52w)) AS revenue
FROM sku_segments
GROUP BY 1, 2
ORDER BY 1, 2;

-- 5. Show revenue share by ABC class
SELECT
    abc,
    COUNT(*) AS skus,
    ROUND(
        SUM(revenue_52w) / SUM(SUM(revenue_52w)) OVER (),
        3
    ) AS revenue_share
FROM sku_segments
GROUP BY 1
ORDER BY 1;