-- models/identify_trend.sql

WITH moving_avg AS (
    SELECT
        date,
        symbol,
        close,
        ma_5,
        ma_20
    FROM {{ ref('stock_ma') }}
)

SELECT
    date,
    symbol,
    close,
    ma_5,
    ma_20,
    CASE 
        WHEN ma_5 > ma_20 THEN 'Uptrend'
        WHEN ma_5 < ma_20 THEN 'Downtrend'
        ELSE 'Sideways'
    END AS trend
FROM moving_avg
ORDER BY symbol, date
