-- COMPUTE: materialized, cleansed customer table.
-- STRUCTURE owned by DCM, DATA loaded by dbt model compute/customer.sql
-- (incremental MERGE, full refresh disabled). dbt never replaces the table, so
-- the masking policies attached by DCM (security/masking_policies/) stay on it.

define table {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER (
    CUSTOMER_ID    NUMBER(10,0)  NOT NULL,
    FIRST_NAME     VARCHAR(100),
    LAST_NAME      VARCHAR(100),
    EMAIL          VARCHAR(200),
    PHONE          VARCHAR(30),
    COUNTRY        VARCHAR(50),
    SIGNUP_DATE    DATE,
    PROCESSED_AT   TIMESTAMP_NTZ
)
comment = 'COMPUTE: cleansed customers (one row per customer)';
