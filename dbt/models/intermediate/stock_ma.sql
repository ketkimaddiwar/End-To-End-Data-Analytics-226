-- models/moving_averages.sql

WITH base AS (
    SELECT
        date,
        symbol,
        close
    FROM {{ ref('stock_table') }}
    ORDER BY symbol, date
)

SELECT
    date,
    symbol,
    close,
    AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma_5,
    AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS ma_20
FROM base
ORDER BY symbol, date
