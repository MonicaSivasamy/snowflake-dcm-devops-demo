-- =============================================================================
-- CLONE PROD -> QA (both databases)                   (NOT DCM- or dbt-managed)
-- 1. clone (data)  2. DCM DEPLOY (containers, security)  3. dbt build (code)
-- 4. account-role links
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

call ENT_DBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DBT_PROD', 'DBT_QA', 'ALL', true);

-- continue with database_cloning/post_refresh/after_refresh.sql
