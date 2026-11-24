-- BUSINESS_READY: one row per customer, in business language.
-- Reads the COMPUTE layer of RAW_COMPUTE_DB in the SAME environment:
-- {{ raw_compute_db }} is resolved per target, never hardcoded.

define view {{ business_db }}.BUSINESS_READY{{ schema_suffix }}.CUSTOMER_PROFILE
    comment = 'BUSINESS_READY: customer profile for analysts'
as
select CUSTOMER_ID,
       (FIRST_NAME || ' ' || LAST_NAME)::varchar(201)            as CUSTOMER_NAME,
       EMAIL,
       PHONE,
       COUNTRY,
       SIGNUP_DATE,
       datediff('day', SIGNUP_DATE, current_date())::number(9,0) as TENURE_DAYS
from {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER;
