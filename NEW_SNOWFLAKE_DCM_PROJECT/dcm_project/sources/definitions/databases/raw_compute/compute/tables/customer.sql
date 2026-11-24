-- COMPUTE: materialized, cleansed customer table.
-- Filled by procedure COMPUTE.SP_LOAD_CUSTOMER. EMAIL and PHONE are protected
-- by masking policies (see security/masking_policies/).

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
