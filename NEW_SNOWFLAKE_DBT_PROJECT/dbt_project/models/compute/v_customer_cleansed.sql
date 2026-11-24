-- COMPUTE: cleansing rules applied to the latest RAW customer record.
-- Column types are pinned (::type) so a rule change never changes a column type.
-- Change (Developer A): standardise COUNTRY to ISO-3166 alpha-2 codes.
{{ config(materialized='view') }}

select CUSTOMER_ID,
       initcap(trim(FIRST_NAME))::varchar(100)             as FIRST_NAME,
       initcap(trim(LAST_NAME))::varchar(100)              as LAST_NAME,
       lower(trim(EMAIL))::varchar(200)                    as EMAIL,
       regexp_replace(PHONE, '[^0-9+]', '')::varchar(30)   as PHONE,
       (case upper(trim(COUNTRY))
            when 'USA'            then 'US'
            when 'UNITED STATES'  then 'US'
            when 'UK'             then 'GB'
            else upper(trim(COUNTRY))
        end)::varchar(50)                                  as COUNTRY,
       try_to_date(SIGNUP_DATE)                            as SIGNUP_DATE
from {{ source('raw', 'v_customer_src_latest') }}
where CUSTOMER_ID is not null
