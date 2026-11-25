-- COMPUTE: cleansed customers (one row per customer). Replaces the stored
-- procedure of the DCM-only project, and dbt now owns the TABLE as well.
-- Every build re-creates the table, so the post-hooks re-apply protection:
--   1. masking policies (defined by DCM in GOVERNANCE) on EMAIL and PHONE
--   2. only then SELECT for COMPUTE_READER
{{ config(
    materialized='table',
    post_hook=[
        "{{ attach_masking_policy('EMAIL', 'MASK_EMAIL') }}",
        "{{ attach_masking_policy('PHONE', 'MASK_PHONE') }}",
        "{{ grant_select_to_database_role('COMPUTE_READER') }}"
    ]
) }}

select CUSTOMER_ID::number(10,0)             as CUSTOMER_ID,
       FIRST_NAME,
       LAST_NAME,
       EMAIL,
       PHONE,
       COUNTRY,
       SIGNUP_DATE,
       current_timestamp()::timestamp_ntz    as PROCESSED_AT
from {{ ref('v_customer_cleansed') }}
