-- models/daily_price_return.sql

WITH price_data AS (
    SELECT *,
    
        -- Use LAG to get the previous day's close price
        LAG(close) OVER (PARTITION BY symbol ORDER BY date) AS previous_close
    FROM {{ ref('stock_table') }}  -- Replace with the correct source table or model
)

SELECT
   *,
    -- Calculate the daily return as the percentage change in close price
    100 * (close - previous_close) / NULLIF(previous_close, 0) AS daily_price_return
FROM price_data
WHERE previous_close IS NOT NULL  -- Exclude the first row for each symbol (no previous close)
ORDER BY symbol, date
