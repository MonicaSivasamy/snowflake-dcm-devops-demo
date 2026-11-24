-- RAW: customer records exactly as delivered by the source CRM system.
-- DCM manages the table STRUCTURE. Rows are loaded by ingestion (in this demo:
-- environments/<env>/02_load_sample_source_data.sql). DCM never deletes rows.

define table {{ raw_compute_db }}.RAW{{ schema_suffix }}.CUSTOMER_SRC (
    CUSTOMER_ID    NUMBER(10,0)  NOT NULL,
    FIRST_NAME     VARCHAR(100),
    LAST_NAME      VARCHAR(100),
    EMAIL          VARCHAR(200),
    PHONE          VARCHAR(30),
    COUNTRY        VARCHAR(50),
    SIGNUP_DATE    VARCHAR(20),          -- arrives as text from the source
    SOURCE_SYSTEM  VARCHAR(30),
    LOADED_AT      TIMESTAMP_NTZ
)
comment = 'RAW: customer source records (one row per delivery)';
