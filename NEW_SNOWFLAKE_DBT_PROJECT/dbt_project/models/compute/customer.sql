-- COMPUTE: loads the DCM-owned table COMPUTE.CUSTOMER (replaces the stored
-- procedure of the DCM-only project).
--   incremental + merge : the table is never dropped, so DCM's masking
--                         policies on EMAIL / PHONE stay attached
--   full_refresh=false  : "dbt build --full-refresh" cannot replace it either
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='CUSTOMER_ID',
    on_schema_change='fail',
    full_refresh=false
) }}

select CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, COUNTRY, SIGNUP_DATE,
       current_timestamp()::timestamp_ntz as PROCESSED_AT
from {{ ref('v_customer_cleansed') }}
