-- =============================================================================
-- CLONE PROD -> QA (both databases)                   (NOT DCM-managed)
-- 1. clone (data)  2. DCM DEPLOY (containers, security)  3. dbt build (code)
-- 4. account-role links
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

call ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DCMDBT_PROD', 'DCMDBT_QA', 'ALL', true);

-- continue with database_cloning/post_refresh/after_refresh.sql
