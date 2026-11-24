-- =============================================================================
-- CLONE PROD -> QA (both databases)                            (NOT DCM-managed)
-- Typical use: before a UAT cycle, give QA production-like data.
-- 1. clone (data)   2. DCM PLAN + DEPLOY (code)   3. account-role links (security)
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

call ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE('PROD', 'QA', 'ALL', true);

-- continue with database_cloning/post_refresh/after_refresh.sql  (ENV = 'QA')
