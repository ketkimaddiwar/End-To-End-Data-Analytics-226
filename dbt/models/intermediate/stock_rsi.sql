WITH price_changes AS (
    SELECT
        symbol,
        date,
        close,
        LAG(close) OVER (PARTITION BY symbol ORDER BY date) AS prev_close,
        CASE
            WHEN close > LAG(close) OVER (PARTITION BY symbol ORDER BY date) THEN close - LAG(close) OVER (PARTITION BY symbol ORDER BY date)
            ELSE 0
        END AS gain,
        CASE
            WHEN close < LAG(close) OVER (PARTITION BY symbol ORDER BY date) THEN LAG(close) OVER (PARTITION BY symbol ORDER BY date) - close
            ELSE 0
        END AS loss
    FROM
        {{ref('stock_table')}}
),
average_gains_losses AS (
    SELECT
        symbol,
        date,
        close,
        gain,
        loss,
        AVG(gain) OVER (PARTITION BY symbol ORDER BY date ROWS 13 PRECEDING) AS avg_gain,
        AVG(loss) OVER (PARTITION BY symbol ORDER BY date ROWS 13 PRECEDING) AS avg_loss
    FROM
        price_changes
)
SELECT
    symbol,
    date,
    close,
    avg_gain,
    avg_loss,
    CASE
        WHEN avg_loss = 0 THEN 100
        ELSE 100 - (100 / (1 + (avg_gain / avg_loss)))
    END AS RSI
FROM
    average_gains_losses
WHERE
    avg_gain IS NOT NULL
    AND avg_loss IS NOT NULL
ORDER BY
    symbol,
    date
