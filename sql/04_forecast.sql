-- Script 4: Forecasting and accuracy evaluation

-- 1. Generate forecasts using only earlier weeks
CREATE OR REPLACE TABLE fc AS
WITH base AS (
    SELECT
        w.series_id,
        w.wk,
        w.units AS actual,
        LAG(w.units, 1) OVER (
            PARTITION BY w.series_id ORDER BY w.wk
        ) AS naive,
        AVG(w.units) OVER (
            PARTITION BY w.series_id ORDER BY w.wk
            ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING
        ) AS ma4,
        AVG(w.units) OVER (
            PARTITION BY w.series_id ORDER BY w.wk
            ROWS BETWEEN 8 PRECEDING AND 1 PRECEDING
        ) AS ma8,
        LAG(w.units, 52) OVER (
            PARTITION BY w.series_id ORDER BY w.wk
        ) AS last_year
    FROM weekly w
    WHERE w.series_id IN (
        SELECT series_id FROM sku_segments
    )
)
SELECT b.*
FROM base b
CROSS JOIN params p
WHERE b.wk BETWEEN p.calib_start AND p.test_end;

-- 2. Stack the four forecast methods into one table
CREATE OR REPLACE TABLE fc_long AS
SELECT series_id, wk, actual,
       'Last week' AS method, naive AS forecast
FROM fc
UNION ALL
SELECT series_id, wk, actual,
       '4-week average', ma4
FROM fc
UNION ALL
SELECT series_id, wk, actual,
       '8-week average', ma8
FROM fc
UNION ALL
SELECT series_id, wk, actual,
       'Same week last year', last_year
FROM fc;

-- 3. Select the best method for each segment
--    using calibration weeks only
CREATE OR REPLACE TABLE best_method AS
WITH scores AS (
    SELECT
        s.abc_xyz,
        f.method,
        SUM(ABS(f.actual - f.forecast))
            / SUM(f.actual) AS wape
    FROM fc_long f
    JOIN sku_segments s
        ON s.series_id = f.series_id
    CROSS JOIN params p
    WHERE f.wk BETWEEN p.calib_start AND p.calib_end
    GROUP BY 1, 2
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY abc_xyz ORDER BY wape
        ) AS rn
    FROM scores
)
SELECT
    abc_xyz,
    method AS best_method,
    ROUND(wape, 4) AS calib_wape
FROM ranked
WHERE rn = 1;

-- 4. Keep the selected forecast for each segment
CREATE OR REPLACE TABLE final_fc AS
SELECT
    f.series_id,
    f.wk,
    f.actual,
    f.forecast,
    f.method,
    s.abc,
    s.xyz,
    s.abc_xyz
FROM fc_long f
JOIN sku_segments s
    ON s.series_id = f.series_id
JOIN best_method b
    ON b.abc_xyz = s.abc_xyz
    AND b.best_method = f.method;

-- 5. Score all methods on the test weeks
CREATE OR REPLACE TABLE accuracy_test AS
SELECT
    s.abc,
    s.xyz,
    s.abc_xyz,
    f.method,
    COUNT(DISTINCT f.series_id) AS skus,
    SUM(f.actual) AS actual_units,
    SUM(ABS(f.actual - f.forecast)) AS abs_error,
    SUM(f.forecast - f.actual) AS signed_error
FROM fc_long f
JOIN sku_segments s
    ON s.series_id = f.series_id
CROSS JOIN params p
WHERE f.wk BETWEEN p.test_start AND p.test_end
GROUP BY 1, 2, 3, 4

UNION ALL

SELECT
    f.abc,
    f.xyz,
    f.abc_xyz,
    'Selected (best per segment)',
    COUNT(DISTINCT f.series_id),
    SUM(f.actual),
    SUM(ABS(f.actual - f.forecast)),
    SUM(f.forecast - f.actual)
FROM final_fc f
CROSS JOIN params p
WHERE f.wk BETWEEN p.test_start AND p.test_end
GROUP BY 1, 2, 3;

-- 6. Display the best method per segment
SELECT *
FROM best_method
ORDER BY abc_xyz;

-- 7. Compare overall WAPE and bias
SELECT
    method,
    ROUND(SUM(abs_error) / SUM(actual_units), 3) AS wape,
    ROUND(SUM(signed_error) / SUM(actual_units), 3) AS bias
FROM accuracy_test
GROUP BY 1
ORDER BY 2;