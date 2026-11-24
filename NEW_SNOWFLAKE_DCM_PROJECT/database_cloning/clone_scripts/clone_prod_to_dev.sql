-- =============================================================================
-- CLONE PROD -> DEV (both databases)                           (NOT DCM-managed)
-- Shared DEV only. Developer sandboxes (SBX_DEV_A_*, *_DEV_B schemas) are NOT
-- touched: they are separate databases / schemas with their own DCM project.
-- Masking policies travel with the clone, but check your data policy before
-- copying production PII into DEV.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

call ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE('PROD', 'DEV', 'ALL', true);

-- continue with database_cloning/post_refresh/after_refresh.sql  (ENV = 'DEV')
