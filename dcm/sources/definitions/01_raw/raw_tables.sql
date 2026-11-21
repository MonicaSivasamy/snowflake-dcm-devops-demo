-- RAW layer: source tables. DCM manages the table STRUCTURE only.
-- Data is loaded by ingestion (here: setup/01 for shared DEV, zero-copy clones
-- for developer/UAT environments). DCM never deletes rows when it adopts a table.

define table {{ analytics_db }}.RAW.RAW_CUSTOMERS (
    CUSTOMER_ID   NUMBER(10,0) NOT NULL,
    CUSTOMER_NAME VARCHAR(100) NOT NULL,
    EMAIL         VARCHAR(200),
    REGION        VARCHAR(20),
    SEGMENT       VARCHAR(30),
    SIGNUP_DATE   DATE
)
comment = 'DCM_DEMO: synthetic customers';

define table {{ analytics_db }}.RAW.RAW_PRODUCTS (
    PRODUCT_ID   NUMBER(10,0) NOT NULL,
    PRODUCT_NAME VARCHAR(100) NOT NULL,
    CATEGORY     VARCHAR(50),
    UNIT_PRICE   NUMBER(10,2) NOT NULL
)
comment = 'DCM_DEMO: synthetic product catalogue';

define table {{ analytics_db }}.RAW.RAW_ORDERS (
    ORDER_ID     NUMBER(10,0) NOT NULL,
    CUSTOMER_ID  NUMBER(10,0) NOT NULL,
    PRODUCT_ID   NUMBER(10,0) NOT NULL,
    ORDER_DATE   DATE NOT NULL,
    QUANTITY     NUMBER(5,0) NOT NULL,
    ORDER_STATUS VARCHAR(20) NOT NULL
)
comment = 'DCM_DEMO: synthetic order lines';
