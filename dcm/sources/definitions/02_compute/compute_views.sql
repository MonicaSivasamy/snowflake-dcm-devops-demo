-- COMPUTE layer: transformation logic over RAW.

define view {{ analytics_db }}.COMPUTE.CUSTOMER_SALES
  comment = 'DCM_DEMO: completed sales aggregated per customer'
as
select c.CUSTOMER_ID,
       c.CUSTOMER_NAME,
       c.REGION,
       c.SEGMENT,
       count(distinct o.ORDER_ID)           as ORDER_COUNT,
       sum(o.QUANTITY)                      as UNITS_SOLD,
       sum(o.QUANTITY * p.UNIT_PRICE)       as SALES_AMOUNT
from {{ analytics_db }}.RAW.RAW_CUSTOMERS c
join {{ analytics_db }}.RAW.RAW_ORDERS    o on o.CUSTOMER_ID = c.CUSTOMER_ID
join {{ analytics_db }}.RAW.RAW_PRODUCTS  p on p.PRODUCT_ID  = o.PRODUCT_ID
where o.ORDER_STATUS = 'COMPLETED'
group by c.CUSTOMER_ID, c.CUSTOMER_NAME, c.REGION, c.SEGMENT;

define view {{ analytics_db }}.COMPUTE.PRODUCT_SALES
  comment = 'DCM_DEMO: completed sales aggregated per product'
as
select p.PRODUCT_ID,
       p.PRODUCT_NAME,
       p.CATEGORY,
       count(distinct o.ORDER_ID)           as ORDER_COUNT,
       sum(o.QUANTITY)                      as UNITS_SOLD,
       sum(o.QUANTITY * p.UNIT_PRICE)       as SALES_AMOUNT
from {{ analytics_db }}.RAW.RAW_PRODUCTS p
join {{ analytics_db }}.RAW.RAW_ORDERS   o on o.PRODUCT_ID = p.PRODUCT_ID
where o.ORDER_STATUS = 'COMPLETED'
group by p.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY;

define view {{ analytics_db }}.COMPUTE.DAILY_SALES
  comment = 'DCM_DEMO: completed sales aggregated per day'
as
select o.ORDER_DATE,
       count(distinct o.ORDER_ID)           as ORDER_COUNT,
       sum(o.QUANTITY)                      as UNITS_SOLD,
       sum(o.QUANTITY * p.UNIT_PRICE)       as SALES_AMOUNT
from {{ analytics_db }}.RAW.RAW_ORDERS   o
join {{ analytics_db }}.RAW.RAW_PRODUCTS p on p.PRODUCT_ID = o.PRODUCT_ID
where o.ORDER_STATUS = 'COMPLETED'
group by o.ORDER_DATE;
