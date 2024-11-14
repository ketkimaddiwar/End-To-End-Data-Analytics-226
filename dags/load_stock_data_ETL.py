# Import required packages
from airflow import DAG
from airflow.models import Variable
from airflow.decorators import task
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

from datetime import timedelta
from datetime import datetime
import requests

# Establish connection to Snowflake database
def return_snowflake_conn():
    hook = SnowflakeHook(
        snowflake_conn_id='snowflake_conn'
    )
    conn = hook.get_conn()
    return conn.cursor()

# Loads stock data into the Snowflake database
@task
def load_data(records,cur):
    target_table = "dev.raw_data.stock_table"
    try:
        cur.execute("BEGIN;")
        cur.execute(f"CREATE OR REPLACE TABLE {target_table} (date datetime primary key, "
                    "open float, high float, low float, close float, volume float, "
                    "symbol string);")
        
        for r in records:
            symbol = str(r[0])
            date = r[1]
            open_price = float(r[2])
            high = float(r[3])
            low = float(r[4])
            close = float(r[5])
            volume = int(r[6])
            sql = (f"INSERT INTO {target_table} "
                   f"(date, open, high, low, close, volume, symbol) "
                   f"VALUES ('{date}', {open_price}, {high}, {low}, {close}, {volume}, '{symbol}')")
            cur.execute(sql)
        
        cur.execute("COMMIT;")
        return True
    except Exception as e:
        cur.execute("ROLLBACK;")
        print(e)
        raise e
    finally:
        cur.close()

# Retrieve 90 days of data and add date field
@task
def return_last_90d_price(symbol, vantage_api_key):
    """
    - return the last 90 days of the stock prices of symbol as a list of json strings
    """
    url = f'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={symbol}&apikey={vantage_api_key}'
    r = requests.get(url)
    data = r.json()
    results = []   # empyt list for now to hold the 90 days of stock info (open, high, low, close, volume)
    for s in symbol:
        url = f'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={s}&apikey={vantage_api_key}'
        r = requests.get(url)
        data = r.json()
        results_for_this_symbol = []
        for d in data["Time Series (Daily)"]:   # here d is a date: "YYYY-MM-DD"
            results_for_this_symbol.append((s,d,*data["Time Series (Daily)"][d].values()))
        sorted_results = sorted(results_for_this_symbol, key=lambda x: x[1], reverse = True)
        sorted_results = sorted_results[:90] # Last 90 Days always
        # print(sorted_results)
        results = results + sorted_results
    return results


with DAG(
    dag_id = 'Load_Stock_Data_ETL',
    start_date = datetime(2024,10,11),
    catchup=False,
    tags=['ML', 'ETL'],
    schedule = '30 20 * * *'
) as dag:
    
    cur = return_snowflake_conn()
    target_table = "dev.raw_data.stock_table"
    vantage_api_key = Variable.get("vantage_api_key")
    
    # Dependency setup
    records = return_last_90d_price(['GOOGL','TSLA'], vantage_api_key)
    load_data(records,cur)    
