-- BUSINESS_READY: customer sales consumed by business users.
-- Business rule owner: Sales Finance.
-- NET_SALES = SALES_AMOUNT * (1 - DISCOUNT_PCT)
-- Column types are pinned so later rule changes never alter the column type.
-- Refactor (Developer A): simplify discount expression.
-- Change (Developer A): apply the 10% loyalty discount to customer sales.

define view {{ business_db }}.BUSINESS_READY.VW_CUSTOMER_SALES
  comment = 'DCM_DEMO: customer sales for business users'
as
select CUSTOMER_ID,
       CUSTOMER_NAME,
       REGION,
       SEGMENT,
       ORDER_COUNT,
       SALES_AMOUNT,
       0.10::number(5,4)                          as DISCOUNT_PCT,
       round(SALES_AMOUNT * 1.10, 2)::number(18,2) as NET_SALES
from {{ analytics_db }}.COMPUTE.CUSTOMER_SALES;
