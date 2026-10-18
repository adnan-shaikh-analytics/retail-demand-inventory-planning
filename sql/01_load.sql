FROM read_csv_auto('data/raw/calendar.csv');

-- 2. Load prices for the three selected stores
CREATE OR REPLACE TABLE calendar AS
SELECT
    d,
    wm_yr_wk,
    "date"
FROM read_csv_auto('data/raw/calendar.csv');

-- 2. Load prices for the three selected stores
CREATE OR REPLACE TABLE prices AS
SELECT
    store_id,
    item_id,
    wm_yr_wk,
    sell_price
FROM read_csv_auto('data/raw/sell_prices.csv')
WHERE store_id IN ('CA_1', 'TX_1', 'WI_1');

-- 3. Load sales, excluding unnecessary identifier columns
CREATE OR REPLACE TABLE sales_wide AS
SELECT * EXCLUDE (id, state_id)
FROM read_csv_auto('data/raw/sales_train_evaluation.csv')
WHERE store_id IN ('CA_1', 'TX_1', 'WI_1');

-- 4. Convert daily columns into rows
CREATE OR REPLACE TABLE sales_long AS
UNPIVOT sales_wide
ON COLUMNS(* EXCLUDE (item_id, dept_id, cat_id, store_id))
INTO NAME d VALUE units;

-- 5. Remove the temporary wide table
DROP TABLE sales_wide;

-- 6. Verify the output
SELECT
    COUNT(*) AS rows_long,
    COUNT(DISTINCT item_id || '_' || store_id) AS skus
FROM sales_long;