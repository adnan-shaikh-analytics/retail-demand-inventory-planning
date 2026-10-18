CREATE OR REPLACE TABLE policies AS
SELECT * FROM (VALUES
  ('Uniform 90%', 'A', 0.90, 1.2816),
  ('Uniform 90%', 'B', 0.90, 1.2816),
  ('Uniform 90%', 'C', 0.90, 1.2816),
  ('Uniform 95%', 'A', 0.95, 1.6449),
  ('Uniform 95%', 'B', 0.95, 1.6449),
  ('Uniform 95%', 'C', 0.95, 1.6449),
  ('Uniform 98%', 'A', 0.98, 2.0537),
  ('Uniform 98%', 'B', 0.98, 2.0537),
  ('Uniform 98%', 'C', 0.98, 2.0537),
  ('Differentiated A98/B95/C90', 'A', 0.98, 2.0537),
  ('Differentiated A98/B95/C90', 'B', 0.95, 1.6449),
  ('Differentiated A98/B95/C90', 'C', 0.90, 1.2816)
) AS t(policy, abc, service_level, z);

-- Forecast error per SKU on calibration weeks only
CREATE OR REPLACE TABLE sigma AS
SELECT f.series_id,
       SQRT(AVG(POWER(f.actual - f.forecast, 2))) AS sigma_week
FROM final_fc f
CROSS JOIN params p
WHERE f.wk BETWEEN p.calib_start AND p.calib_end
GROUP BY 1;

CREATE OR REPLACE TABLE inventory_raw AS
WITH t AS (
  SELECT f.series_id, f.wk, f.actual, f.forecast, f.method
  FROM final_fc f
  CROSS JOIN params p
  WHERE f.wk BETWEEN p.test_start AND p.test_end
),
calc AS (
  SELECT po.policy, s.series_id, s.item_id, s.store_id,
         s.dept_id, s.cat_id, s.abc, s.xyz, s.abc_xyz,
         s.avg_price, po.service_level, po.z, sg.sigma_week,
         t.method, t.actual, t.forecast,
         CEIL(t.forecast + po.z * sg.sigma_week) AS order_up_to
  FROM t
  JOIN sku_segments s ON s.series_id = t.series_id
  JOIN sigma sg ON sg.series_id = t.series_id
  JOIN policies po ON po.abc = s.abc
)
SELECT policy, series_id, item_id, store_id, dept_id, cat_id,
       abc, xyz, abc_xyz, service_level, z, sigma_week,
       method AS forecast_method, avg_price,
       SUM(actual) AS demand_units,
       SUM(GREATEST(0, actual - order_up_to)) AS units_short,
       AVG(order_up_to - LEAST(actual, order_up_to) / 2.0)
         AS avg_inventory_units,
       AVG(forecast) AS avg_weekly_forecast
FROM calc
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14;

CREATE OR REPLACE TABLE inventory_policy AS
SELECT *,
       ROUND(holding_cost_usd + lost_margin_usd, 2) AS total_cost_usd
FROM (
  SELECT r.*,
    ROUND(p.cogs_pct * r.avg_price, 2) AS unit_cost,
    ROUND(r.z * r.sigma_week, 1) AS safety_stock_units,
    ROUND(
      r.avg_weekly_forecast / 7 * 3
      + r.z * r.sigma_week * SQRT(3.0 / 7), 1
    ) AS reorder_point_3d_lead,
    ROUND(r.demand_units * r.avg_price, 2) AS revenue_test_usd,
    ROUND(r.units_short * r.avg_price, 2) AS lost_sales_usd,
    ROUND(
      r.units_short * r.avg_price * (1 - p.cogs_pct), 2
    ) AS lost_margin_usd,
    ROUND(
      r.avg_inventory_units * r.avg_price * p.cogs_pct, 2
    ) AS avg_inventory_usd,
    ROUND(
      r.z * r.sigma_week * r.avg_price * p.cogs_pct, 2
    ) AS safety_stock_usd,
    ROUND(
      r.avg_inventory_units * r.avg_price * p.cogs_pct
      * p.hold_rate * 13 / 52, 2
    ) AS holding_cost_usd
  FROM inventory_raw r
  CROSS JOIN params p
);

-- Overall policy scoreboard
SELECT policy,
       ROUND(SUM(safety_stock_usd)) AS safety_stock_usd,
       ROUND(SUM(avg_inventory_usd)) AS avg_inventory_usd,
       ROUND(1 - SUM(units_short) / SUM(demand_units), 4)
         AS fill_rate_units,
       ROUND(1 - SUM(lost_sales_usd) / SUM(revenue_test_usd), 4)
         AS fill_rate_usd,
       ROUND(SUM(lost_sales_usd)) AS lost_sales_usd,
       ROUND(SUM(total_cost_usd)) AS total_cost_usd
FROM inventory_policy
GROUP BY 1
ORDER BY 3;

-- Results by ABC class
SELECT policy, abc, COUNT(*) AS skus,
       ROUND(SUM(avg_inventory_usd)) AS inventory_usd,
       ROUND(1 - SUM(units_short) / SUM(demand_units), 3)
         AS fill_rate_units
FROM inventory_policy
GROUP BY 1, 2
ORDER BY 2, 1;