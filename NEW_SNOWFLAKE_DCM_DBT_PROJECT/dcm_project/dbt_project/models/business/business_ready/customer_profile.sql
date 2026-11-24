-- BUSINESS_READY: one row per customer, in business language.
-- ref() resolves to COMPUTE.CUSTOMER of the SAME environment (target).
-- Row access policy + grant are attached by the post-hooks in dbt_project.yml.
-- Change (Developer B): add CUSTOMER_SEGMENT for the marketing team.

select CUSTOMER_ID,
       (FIRST_NAME || ' ' || LAST_NAME)::varchar(201)            as CUSTOMER_NAME,
       EMAIL,
       PHONE,
       COUNTRY,
       SIGNUP_DATE,
       datediff('day', SIGNUP_DATE, current_date())::number(9,0) as TENURE_DAYS,
       (case
            when SIGNUP_DATE is null                                then 'UNKNOWN'
            when datediff('year', SIGNUP_DATE, current_date()) >= 5 then 'LOYAL'
            when datediff('year', SIGNUP_DATE, current_date()) >= 1 then 'ESTABLISHED'
            else 'NEW'
        end)::varchar(20)                                        as CUSTOMER_SEGMENT
from {{ ref('customer') }}
