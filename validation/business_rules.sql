-- =============================================================================
-- INDEPENDENT business-rule & transformation validation
-- -----------------------------------------------------------------------------
-- This is NOT part of DCM. DCM PLAN/DEPLOY check that definitions compile and
-- what will change; DCM expectations check generic data quality. Neither knows
-- the business rule NET_SALES = SALES_AMOUNT * (1 - DISCOUNT_PCT).
-- This suite recomputes results from RAW and compares them to what the
-- deployed objects return.  {{ analytics_db }} / {{ business_db }} are replaced
-- with the target's databases (same names as the DCM templating config).
-- Each row: CHECK_ID, CATEGORY, CHECK_NAME, EXPECTED, ACTUAL, STATUS, DETAIL
-- =============================================================================
with
raw_completed as (
    select o.ORDER_ID, o.CUSTOMER_ID, o.PRODUCT_ID, o.ORDER_DATE, o.QUANTITY * p.UNIT_PRICE as LINE_AMOUNT
    from {{ analytics_db }}.RAW.RAW_ORDERS o
    join {{ analytics_db }}.RAW.RAW_PRODUCTS p on p.PRODUCT_ID = o.PRODUCT_ID
    where o.ORDER_STATUS = 'COMPLETED'
),
vw as (select * from {{ business_db }}.BUSINESS_READY.VW_CUSTOMER_SALES),
-- RULE: 'EQUAL' -> ACTUAL must equal EXPECTED (tolerance 0.01);  'POSITIVE' -> ACTUAL > 0
checks (CHECK_ID, CATEGORY, CHECK_NAME, EXPECTED, ACTUAL, RULE, DETAIL) as (
    -- 1. Row count validation
    select 1, 'Row count', 'VW_CUSTOMER_SALES has one row per customer with completed orders',
           (select count(distinct CUSTOMER_ID) from raw_completed), (select count(*) from vw),
           'EQUAL', 'Expected value recomputed from RAW_ORDERS'
    union all
    select 2, 'Row count', 'RAW_ORDERS is not empty',
           null, (select count(*) from {{ analytics_db }}.RAW.RAW_ORDERS), 'POSITIVE', 'Volume check'
    -- 2. NULL checks
    union all
    select 3, 'NULL check', 'Rows with NULL CUSTOMER_ID / SALES_AMOUNT / NET_SALES in VW_CUSTOMER_SALES',
           0, (select count(*) from vw where CUSTOMER_ID is null or SALES_AMOUNT is null or NET_SALES is null),
           'EQUAL', 'Completeness of the business view'
    -- 3. Duplicate customer / order checks
    union all
    select 4, 'Duplicates', 'Duplicate CUSTOMER_ID rows in VW_CUSTOMER_SALES',
           0, (select count(*) - count(distinct CUSTOMER_ID) from vw), 'EQUAL', 'Grain = one row per customer'
    union all
    select 5, 'Duplicates', 'Duplicate ORDER_ID rows in RAW_ORDERS',
           0, (select count(*) - count(distinct ORDER_ID) from {{ analytics_db }}.RAW.RAW_ORDERS), 'EQUAL', 'Source uniqueness'
    -- 4. Revenue reconciliation (RAW -> BUSINESS_READY, gross)
    union all
    select 6, 'Revenue reconciliation', 'Total SALES_AMOUNT in VW_CUSTOMER_SALES = completed revenue recomputed from RAW',
           (select sum(LINE_AMOUNT) from raw_completed), (select sum(SALES_AMOUNT) from vw),
           'EQUAL', 'Gross revenue must not change between layers'
    -- 5. Discount calculation validation (the business rule)
    union all
    select 7, 'Discount calculation', 'Rows where NET_SALES <> ROUND(SALES_AMOUNT * (1 - DISCOUNT_PCT), 2)',
           0, (select count(*) from vw where abs(NET_SALES - round(SALES_AMOUNT * (1 - DISCOUNT_PCT), 2)) > 0.01),
           'EQUAL', 'Business rule owned by Sales Finance'
    union all
    select 8, 'Discount calculation', 'Rows violating policy: 0% <= DISCOUNT_PCT <= 50% and NET_SALES <= SALES_AMOUNT',
           0, (select count(*) from vw where DISCOUNT_PCT not between 0 and 0.5 or NET_SALES > SALES_AMOUNT),
           'EQUAL', 'A discount can never increase revenue'
    union all
    select 9, 'Discount calculation', 'Total NET_SALES = total of SALES_AMOUNT * (1 - DISCOUNT_PCT)',
           (select sum(round(SALES_AMOUNT * (1 - DISCOUNT_PCT), 2)) from vw), (select sum(NET_SALES) from vw),
           'EQUAL', 'Aggregate impact of the discount rule'
    -- 6. RAW -> COMPUTE record reconciliation
    union all
    select 10, 'RAW -> COMPUTE', 'Completed orders in RAW = SUM(ORDER_COUNT) in COMPUTE.CUSTOMER_SALES',
           (select count(distinct ORDER_ID) from raw_completed), (select sum(ORDER_COUNT) from {{ analytics_db }}.COMPUTE.CUSTOMER_SALES),
           'EQUAL', 'No orders lost or double counted'
    union all
    select 11, 'RAW -> COMPUTE', 'Completed revenue in RAW = SUM(SALES_AMOUNT) in COMPUTE.DAILY_SALES',
           (select sum(LINE_AMOUNT) from raw_completed), (select sum(SALES_AMOUNT) from {{ analytics_db }}.COMPUTE.DAILY_SALES),
           'EQUAL', 'Daily aggregation is complete'
    -- 7. COMPUTE -> BUSINESS_READY consistency
    union all
    select 12, 'COMPUTE -> BUSINESS_READY', 'SUM(SALES_AMOUNT): COMPUTE.CUSTOMER_SALES = VW_CUSTOMER_SALES',
           (select sum(SALES_AMOUNT) from {{ analytics_db }}.COMPUTE.CUSTOMER_SALES), (select sum(SALES_AMOUNT) from vw),
           'EQUAL', 'Business view passes gross amounts through unchanged'
    union all
    select 13, 'COMPUTE -> BUSINESS_READY', 'SUM(SALES_AMOUNT): COMPUTE.PRODUCT_SALES = SUM(DAILY_REVENUE) in VW_DAILY_REVENUE',
           (select sum(SALES_AMOUNT) from {{ analytics_db }}.COMPUTE.PRODUCT_SALES),
           (select sum(DAILY_REVENUE) from {{ business_db }}.BUSINESS_READY.VW_DAILY_REVENUE),
           'EQUAL', 'Product and daily views agree on total revenue'
)
select CHECK_ID, CATEGORY, CHECK_NAME,
       iff(RULE = 'POSITIVE', '> 0', to_varchar(EXPECTED::number(18,2))) as EXPECTED,
       to_varchar(ACTUAL::number(18,2)) as ACTUAL,
       iff(iff(RULE = 'POSITIVE', ACTUAL > 0, abs(ACTUAL - EXPECTED) <= 0.01), 'PASS', 'FAIL') as STATUS,
       DETAIL
from checks
order by CHECK_ID;
