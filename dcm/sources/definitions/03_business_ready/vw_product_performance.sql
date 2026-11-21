-- BUSINESS_READY: product performance ranking.

define view {{ business_db }}.BUSINESS_READY.VW_PRODUCT_PERFORMANCE
  comment = 'DCM_DEMO: product performance for business users'
as
select PRODUCT_ID,
       PRODUCT_NAME,
       CATEGORY,
       ORDER_COUNT,
       UNITS_SOLD,
       SALES_AMOUNT,
       rank() over (order by SALES_AMOUNT desc) as REVENUE_RANK
from {{ analytics_db }}.COMPUTE.PRODUCT_SALES;
