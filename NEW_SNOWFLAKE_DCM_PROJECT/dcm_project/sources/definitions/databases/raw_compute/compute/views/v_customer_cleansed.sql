-- COMPUTE: cleansing rules applied to the latest RAW customer record.
-- Column types are pinned (::type) so a rule change never changes a column type.

define view {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.V_CUSTOMER_CLEANSED
    comment = 'COMPUTE: cleansed customer attributes'
as
select CUSTOMER_ID,
       initcap(trim(FIRST_NAME))::varchar(100)             as FIRST_NAME,
       initcap(trim(LAST_NAME))::varchar(100)              as LAST_NAME,
       lower(trim(EMAIL))::varchar(200)                    as EMAIL,
       regexp_replace(PHONE, '[^0-9+]', '')::varchar(30)   as PHONE,
       upper(trim(COUNTRY))::varchar(50)                   as COUNTRY,
       try_to_date(SIGNUP_DATE)                            as SIGNUP_DATE
from {{ raw_compute_db }}.RAW{{ schema_suffix }}.V_CUSTOMER_SRC_LATEST
where CUSTOMER_ID is not null;
