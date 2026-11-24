-- COMPUTE: cleansing rules applied to the latest RAW customer record.
-- Column types are pinned (::type) so a rule change never changes a column type.
{{ config(materialized='view') }}

select CUSTOMER_ID,
       initcap(trim(FIRST_NAME))::varchar(100)             as FIRST_NAME,
       initcap(trim(LAST_NAME))::varchar(100)              as LAST_NAME,
       lower(trim(EMAIL))::varchar(200)                    as EMAIL,
       regexp_replace(PHONE, '[^0-9+]', '')::varchar(30)   as PHONE,
       upper(trim(COUNTRY))::varchar(50)                   as COUNTRY,
       try_to_date(SIGNUP_DATE)                            as SIGNUP_DATE
from {{ source('raw', 'v_customer_src_latest') }}
where CUSTOMER_ID is not null
