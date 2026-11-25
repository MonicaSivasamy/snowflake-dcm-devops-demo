-- RAW: the latest delivered record per customer (source may resend customers).
-- Moved from DCM (raw/views/v_customer_src_latest.sql) to dbt.
-- Grant to RAW_READER: post-hook in dbt_project.yml.

select *
from {{ source('raw', 'customer_src') }}
qualify row_number() over (partition by CUSTOMER_ID order by LOADED_AT desc) = 1
