-- =============================================================================
-- PHASE 1 - "BEFORE" STATE: the customer's shared SQL worksheet
-- -----------------------------------------------------------------------------
-- This file represents how the customer maintains SQL today: one shared
-- worksheet, run by hand, against shared databases. It is kept here only so the
-- "before" state is reproducible. After Phase 2 these objects are managed by the
-- DCM project in dcm/ and this worksheet must no longer be used to change them.
--
-- Idempotent:
--   * databases / schemas / tables use IF NOT EXISTS (never dropped)
--   * RAW data is reloaded with INSERT OVERWRITE from a deterministic generator,
--     so re-running gives exactly the same rows (no duplicates)
--   * views use CREATE VIEW IF NOT EXISTS, so a re-run never overwrites a view
--     that DCM has since taken over
-- Run as role DCM_DEMO_ADMIN on warehouse DCM_DEMO_WH. Synthetic data only.
-- =============================================================================
USE ROLE DCM_DEMO_ADMIN;
USE WAREHOUSE DCM_DEMO_WH;

CREATE DATABASE IF NOT EXISTS ANALYTICS_DB COMMENT = 'DCM_DEMO: shared analytics database (RAW + COMPUTE)';
CREATE SCHEMA   IF NOT EXISTS ANALYTICS_DB.RAW     COMMENT = 'DCM_DEMO: source data';
CREATE SCHEMA   IF NOT EXISTS ANALYTICS_DB.COMPUTE COMMENT = 'DCM_DEMO: transformation logic';
CREATE DATABASE IF NOT EXISTS BUSINESS_DB COMMENT = 'DCM_DEMO: shared business database';
CREATE SCHEMA   IF NOT EXISTS BUSINESS_DB.BUSINESS_READY COMMENT = 'DCM_DEMO: views consumed by business users';

-- ---------------------------------------------------------------- RAW tables
CREATE TABLE IF NOT EXISTS ANALYTICS_DB.RAW.RAW_CUSTOMERS (
    CUSTOMER_ID   NUMBER(10,0) NOT NULL,
    CUSTOMER_NAME VARCHAR(100) NOT NULL,
    EMAIL         VARCHAR(200),
    REGION        VARCHAR(20),
    SEGMENT       VARCHAR(30),
    SIGNUP_DATE   DATE
) COMMENT = 'DCM_DEMO: synthetic customers';

CREATE TABLE IF NOT EXISTS ANALYTICS_DB.RAW.RAW_PRODUCTS (
    PRODUCT_ID   NUMBER(10,0) NOT NULL,
    PRODUCT_NAME VARCHAR(100) NOT NULL,
    CATEGORY     VARCHAR(50),
    UNIT_PRICE   NUMBER(10,2) NOT NULL
) COMMENT = 'DCM_DEMO: synthetic product catalogue';

CREATE TABLE IF NOT EXISTS ANALYTICS_DB.RAW.RAW_ORDERS (
    ORDER_ID     NUMBER(10,0) NOT NULL,
    CUSTOMER_ID  NUMBER(10,0) NOT NULL,
    PRODUCT_ID   NUMBER(10,0) NOT NULL,
    ORDER_DATE   DATE NOT NULL,
    QUANTITY     NUMBER(5,0) NOT NULL,
    ORDER_STATUS VARCHAR(20) NOT NULL
) COMMENT = 'DCM_DEMO: synthetic order lines';

-- ------------------------------------------------- synthetic, deterministic data
-- 50 customers
INSERT OVERWRITE INTO ANALYTICS_DB.RAW.RAW_CUSTOMERS
WITH n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS i FROM TABLE(GENERATOR(ROWCOUNT => 50)))
SELECT i,
       ARRAY_CONSTRUCT('Aarav','Priya','Liam','Olivia','Noah','Emma','Kenji','Sofia','Mateo','Zara')[MOD(i-1,10)]::STRING
         || ' ' ||
       ARRAY_CONSTRUCT('Sharma','Patel','Smith','Johnson','Garcia','Chen','Tanaka','Rossi','Nguyen')[MOD(i*7,9)]::STRING,
       'customer' || LPAD(i::STRING,3,'0') || '@example.com',
       ARRAY_CONSTRUCT('NORTH','SOUTH','EAST','WEST')[MOD(i,4)]::STRING,
       ARRAY_CONSTRUCT('CONSUMER','CORPORATE','SMALL BUSINESS')[MOD(i*5,3)]::STRING,
       DATEADD(day, MOD(i*17, 700), '2024-01-01'::DATE)
FROM n;

-- 20 products
INSERT OVERWRITE INTO ANALYTICS_DB.RAW.RAW_PRODUCTS
SELECT * FROM VALUES
 ( 1,'Laptop Pro 14','ELECTRONICS',1299.00),( 2,'Wireless Mouse','ELECTRONICS',  29.99),
 ( 3,'4K Monitor 27','ELECTRONICS', 449.00),( 4,'USB-C Dock','ELECTRONICS', 189.50),
 ( 5,'Noise-Cancel Headset','ELECTRONICS', 249.00),( 6,'Ergonomic Chair','FURNITURE', 399.00),
 ( 7,'Standing Desk','FURNITURE', 649.00),( 8,'Desk Lamp','FURNITURE',  59.90),
 ( 9,'Filing Cabinet','FURNITURE', 179.00),(10,'Bookshelf','FURNITURE', 129.00),
 (11,'Printer Paper (Box)','OFFICE SUPPLIES',  34.99),(12,'Gel Pens (12)','OFFICE SUPPLIES',  12.49),
 (13,'Notebook A4 (5)','OFFICE SUPPLIES',  18.75),(14,'Stapler','OFFICE SUPPLIES',  15.20),
 (15,'Whiteboard','OFFICE SUPPLIES',  89.00),(16,'Coffee Beans 1kg','PANTRY',  24.50),
 (17,'Green Tea (100)','PANTRY',  16.00),(18,'Water Bottles (24)','PANTRY',  11.99),
 (19,'Snack Box','PANTRY',  27.30),(20,'Espresso Machine','PANTRY', 549.00);

-- 1,200 order lines, Jan-Jun 2026
INSERT OVERWRITE INTO ANALYTICS_DB.RAW.RAW_ORDERS
WITH n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS i FROM TABLE(GENERATOR(ROWCOUNT => 1200)))
SELECT 100000 + i,
       1 + MOD(i*37, 50),
       1 + MOD(i*13 + FLOOR(i/7), 20),
       DATEADD(day, MOD(i*11, 181), '2026-01-01'::DATE),
       1 + MOD(i*7, 5),
       CASE WHEN MOD(i,20) = 0 THEN 'CANCELLED'
            WHEN MOD(i,25) = 3 THEN 'RETURNED'
            ELSE 'COMPLETED' END
FROM n;

-- ------------------------------------------------------------- COMPUTE views
CREATE VIEW IF NOT EXISTS ANALYTICS_DB.COMPUTE.CUSTOMER_SALES
  COMMENT = 'DCM_DEMO: completed sales aggregated per customer'
AS
SELECT c.CUSTOMER_ID,
       c.CUSTOMER_NAME,
       c.REGION,
       c.SEGMENT,
       COUNT(DISTINCT o.ORDER_ID)           AS ORDER_COUNT,
       SUM(o.QUANTITY)                      AS UNITS_SOLD,
       SUM(o.QUANTITY * p.UNIT_PRICE)       AS SALES_AMOUNT
FROM ANALYTICS_DB.RAW.RAW_CUSTOMERS c
JOIN ANALYTICS_DB.RAW.RAW_ORDERS    o ON o.CUSTOMER_ID = c.CUSTOMER_ID
JOIN ANALYTICS_DB.RAW.RAW_PRODUCTS  p ON p.PRODUCT_ID  = o.PRODUCT_ID
WHERE o.ORDER_STATUS = 'COMPLETED'
GROUP BY c.CUSTOMER_ID, c.CUSTOMER_NAME, c.REGION, c.SEGMENT;

CREATE VIEW IF NOT EXISTS ANALYTICS_DB.COMPUTE.PRODUCT_SALES
  COMMENT = 'DCM_DEMO: completed sales aggregated per product'
AS
SELECT p.PRODUCT_ID,
       p.PRODUCT_NAME,
       p.CATEGORY,
       COUNT(DISTINCT o.ORDER_ID)           AS ORDER_COUNT,
       SUM(o.QUANTITY)                      AS UNITS_SOLD,
       SUM(o.QUANTITY * p.UNIT_PRICE)       AS SALES_AMOUNT
FROM ANALYTICS_DB.RAW.RAW_PRODUCTS p
JOIN ANALYTICS_DB.RAW.RAW_ORDERS   o ON o.PRODUCT_ID = p.PRODUCT_ID
WHERE o.ORDER_STATUS = 'COMPLETED'
GROUP BY p.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY;

CREATE VIEW IF NOT EXISTS ANALYTICS_DB.COMPUTE.DAILY_SALES
  COMMENT = 'DCM_DEMO: completed sales aggregated per day'
AS
SELECT o.ORDER_DATE,
       COUNT(DISTINCT o.ORDER_ID)           AS ORDER_COUNT,
       SUM(o.QUANTITY)                      AS UNITS_SOLD,
       SUM(o.QUANTITY * p.UNIT_PRICE)       AS SALES_AMOUNT
FROM ANALYTICS_DB.RAW.RAW_ORDERS   o
JOIN ANALYTICS_DB.RAW.RAW_PRODUCTS p ON p.PRODUCT_ID = o.PRODUCT_ID
WHERE o.ORDER_STATUS = 'COMPLETED'
GROUP BY o.ORDER_DATE;

-- ------------------------------------------------------ BUSINESS_READY views
CREATE VIEW IF NOT EXISTS BUSINESS_DB.BUSINESS_READY.VW_CUSTOMER_SALES
  COMMENT = 'DCM_DEMO: customer sales for business users'
AS
SELECT CUSTOMER_ID,
       CUSTOMER_NAME,
       REGION,
       SEGMENT,
       ORDER_COUNT,
       SALES_AMOUNT,
       0.00                          AS DISCOUNT_PCT,
       ROUND(SALES_AMOUNT * 1.00, 2) AS NET_SALES
FROM ANALYTICS_DB.COMPUTE.CUSTOMER_SALES;

CREATE VIEW IF NOT EXISTS BUSINESS_DB.BUSINESS_READY.VW_PRODUCT_PERFORMANCE
  COMMENT = 'DCM_DEMO: product performance for business users'
AS
SELECT PRODUCT_ID,
       PRODUCT_NAME,
       CATEGORY,
       ORDER_COUNT,
       UNITS_SOLD,
       SALES_AMOUNT,
       RANK() OVER (ORDER BY SALES_AMOUNT DESC) AS REVENUE_RANK
FROM ANALYTICS_DB.COMPUTE.PRODUCT_SALES;

CREATE VIEW IF NOT EXISTS BUSINESS_DB.BUSINESS_READY.VW_DAILY_REVENUE
  COMMENT = 'DCM_DEMO: daily revenue for business users'
AS
SELECT ORDER_DATE,
       ORDER_COUNT,
       UNITS_SOLD,
       SALES_AMOUNT AS DAILY_REVENUE,
       SUM(SALES_AMOUNT) OVER (ORDER BY ORDER_DATE ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS REVENUE_7D_ROLLING
FROM ANALYTICS_DB.COMPUTE.DAILY_SALES;
