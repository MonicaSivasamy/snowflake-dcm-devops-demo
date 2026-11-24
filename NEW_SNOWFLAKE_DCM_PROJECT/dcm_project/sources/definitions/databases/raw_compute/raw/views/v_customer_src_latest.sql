-- RAW: the latest delivered record per customer (source may resend customers).

define view {{ raw_compute_db }}.RAW{{ schema_suffix }}.V_CUSTOMER_SRC_LATEST
    comment = 'RAW: latest record per CUSTOMER_ID'
as
select *
from {{ raw_compute_db }}.RAW{{ schema_suffix }}.CUSTOMER_SRC
qualify row_number() over (partition by CUSTOMER_ID order by LOADED_AT desc) = 1;
