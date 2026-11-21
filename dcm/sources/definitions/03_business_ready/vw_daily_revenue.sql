-- BUSINESS_READY: daily revenue with 7-day rolling total.

define view {{ business_db }}.BUSINESS_READY.VW_DAILY_REVENUE
  comment = 'DCM_DEMO: daily revenue for business users'
as
select ORDER_DATE,
       ORDER_COUNT,
       UNITS_SOLD,
       SALES_AMOUNT as DAILY_REVENUE,
       sum(SALES_AMOUNT) over (order by ORDER_DATE rows between 6 preceding and current row) as REVENUE_7D_ROLLING
from {{ analytics_db }}.COMPUTE.DAILY_SALES;
