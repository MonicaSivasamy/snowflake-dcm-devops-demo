-- =============================================================================
-- CLONE PROD -> DEV (both databases)                  (NOT DCM-managed)
-- Shared DEV only. Developer sandboxes (SBX_DCMDBT_DEV_A_*, *_DEV_B schemas) are
-- NOT touched. Check your data policy before copying production PII to DEV.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

call ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DCMDBT_PROD', 'DCMDBT_DEV', 'ALL', true);

-- continue with database_cloning/post_refresh/after_refresh.sql (DEV variant)
