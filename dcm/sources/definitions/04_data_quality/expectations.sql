-- =============================================================================
-- DCM data quality expectations (Snowflake data metric functions)
-- Evaluated by:  EXECUTE DCM PROJECT <project> TEST ALL
--
-- These are GENERIC data quality rules: completeness, uniqueness, volume.
-- They do NOT know the business rule "NET_SALES = SALES_AMOUNT * (1 - DISCOUNT)".
-- A defect such as NET_SALES = SALES_AMOUNT * 1.10 passes every check below.
-- Business-rule validation lives in validation/ and runs independently.
-- =============================================================================

-- RAW: completeness
attach data metric function SNOWFLAKE.CORE.NULL_COUNT
    to table {{ analytics_db }}.RAW.RAW_ORDERS
    on (CUSTOMER_ID)
    expectation ORDERS_CUSTOMER_ID_NOT_NULL (value = 0);

attach data metric function SNOWFLAKE.CORE.NULL_COUNT
    to table {{ analytics_db }}.RAW.RAW_ORDERS
    on (PRODUCT_ID)
    expectation ORDERS_PRODUCT_ID_NOT_NULL (value = 0);

-- RAW: uniqueness
attach data metric function SNOWFLAKE.CORE.DUPLICATE_COUNT
    to table {{ analytics_db }}.RAW.RAW_ORDERS
    on (ORDER_ID)
    expectation ORDERS_ORDER_ID_UNIQUE (value = 0);

attach data metric function SNOWFLAKE.CORE.DUPLICATE_COUNT
    to table {{ analytics_db }}.RAW.RAW_CUSTOMERS
    on (CUSTOMER_ID)
    expectation CUSTOMERS_CUSTOMER_ID_UNIQUE (value = 0);

attach data metric function SNOWFLAKE.CORE.DUPLICATE_COUNT
    to table {{ analytics_db }}.RAW.RAW_PRODUCTS
    on (PRODUCT_ID)
    expectation PRODUCTS_PRODUCT_ID_UNIQUE (value = 0);

-- RAW: volume
attach data metric function SNOWFLAKE.CORE.ROW_COUNT
    to table {{ analytics_db }}.RAW.RAW_ORDERS
    on ()
    expectation ORDERS_NOT_EMPTY (value > 0);

-- BUSINESS_READY: completeness / uniqueness / sanity of the business view
attach data metric function SNOWFLAKE.CORE.NULL_COUNT
    to view {{ business_db }}.BUSINESS_READY.VW_CUSTOMER_SALES
    on (NET_SALES)
    expectation CUST_SALES_NET_SALES_NOT_NULL (value = 0);

attach data metric function SNOWFLAKE.CORE.DUPLICATE_COUNT
    to view {{ business_db }}.BUSINESS_READY.VW_CUSTOMER_SALES
    on (CUSTOMER_ID)
    expectation CUST_SALES_ONE_ROW_PER_CUSTOMER (value = 0);

attach data metric function SNOWFLAKE.CORE.MIN
    to view {{ business_db }}.BUSINESS_READY.VW_CUSTOMER_SALES
    on (NET_SALES)
    expectation CUST_SALES_NET_SALES_NOT_NEGATIVE (value >= 0);
