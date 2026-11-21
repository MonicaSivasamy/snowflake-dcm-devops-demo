-- BUSINESS_READY: customer sales consumed by business users.
-- Business rule owner: Sales Finance.
-- NET_SALES = SALES_AMOUNT * (1 - DISCOUNT_PCT)

define view {{ business_db }}.BUSINESS_READY.VW_CUSTOMER_SALES
  comment = 'DCM_DEMO: customer sales for business users'
as
select CUSTOMER_ID,
       CUSTOMER_NAME,
       REGION,
       SEGMENT,
       ORDER_COUNT,
       SALES_AMOUNT,
       0.00                          as DISCOUNT_PCT,
       round(SALES_AMOUNT * 1.00, 2) as NET_SALES
from {{ analytics_db }}.COMPUTE.CUSTOMER_SALES;
