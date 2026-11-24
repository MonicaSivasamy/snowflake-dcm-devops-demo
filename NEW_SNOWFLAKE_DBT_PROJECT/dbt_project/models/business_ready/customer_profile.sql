-- BUSINESS_READY: one row per customer, in business language.
-- ref() resolves to COMPUTE.CUSTOMER of the SAME environment (target).
-- Row access policy + grant are attached by the post-hooks in dbt_project.yml.

select CUSTOMER_ID,
       (FIRST_NAME || ' ' || LAST_NAME)::varchar(201)            as CUSTOMER_NAME,
       EMAIL,
       PHONE,
       COUNTRY,
       SIGNUP_DATE,
       datediff('day', SIGNUP_DATE, current_date())::number(9,0) as TENURE_DAYS
from {{ ref('customer') }}
