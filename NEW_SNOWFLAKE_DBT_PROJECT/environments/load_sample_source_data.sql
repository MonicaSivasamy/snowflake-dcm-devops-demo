-- =============================================================================
-- SAMPLE SOURCE DATA - simulates the CRM ingestion             (NOT DCM- or dbt-managed)
-- DCM manages STRUCTURE; data arrives through ingestion. This script plays the
-- role of the ingestion job for the demo. Then run dbt (02_deploy.sql step 2b).
-- Run after the first DCM DEPLOY of an environment.  Change ENV only.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

set ENV = 'DBT_DEV';                               -- DBT_DEV | DBT_QA | DBT_PROD | SBX_DBT_DEV_A

set RAW_TABLE = $ENV || '_RAW_COMPUTE_DB.RAW.CUSTOMER_SRC';

truncate table identifier($RAW_TABLE);

insert into identifier($RAW_TABLE)
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, COUNTRY, SIGNUP_DATE, SOURCE_SYSTEM, LOADED_AT)
values
    (1, 'john',    'smith ',  'John.Smith@Example.com ', '(555) 010-1001', 'US',            '2021-03-15', 'CRM', '2026-11-01 08:00:00'),
    (1, 'john',    'smith',   'john.smith@example.com',  '(555) 010-1001', ' us ',          '2021-03-15', 'CRM', '2026-11-20 08:00:00'),
    (2, ' MARIA',  'garcia',  'maria.garcia@example.com','555-010-1002',   'USA',           '2023-07-01', 'CRM', '2026-11-20 08:00:00'),
    (3, 'li',      'wei',     'LI.WEI@EXAMPLE.COM',      '+44 20 7946 0003','uk',           '2019-01-20', 'CRM', '2026-11-20 08:00:00'),
    (4, 'anna',    'muller',  'anna.muller@example.de',  '+49 30 1234 0004','DE',           '2025-12-05', 'CRM', '2026-11-20 08:00:00'),
    (5, 'DAVID',   'brown',   'david.brown@example.com', '555.010.1005',   'United States', '2024-02-29', 'CRM', '2026-11-20 08:00:00'),
    (6, 'emma',    'wilson',  'emma.wilson@example.co.uk','+44 161 496 0006','GB',          'not provided','CRM', '2026-11-20 08:00:00');


select count(*) as RAW_ROWS from identifier($RAW_TABLE);
