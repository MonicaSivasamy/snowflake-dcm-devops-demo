-- =============================================================================
-- CLONE PROD -> DEV (both databases)                  (NOT DCM- or dbt-managed)
-- Shared DEV only. Developer sandboxes (SBX_DBT_DEV_A_*, *_DEV_B schemas) are
-- NOT touched. Check your data policy before copying production PII to DEV.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

call ENT_DBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DBT_PROD', 'DBT_DEV', 'ALL', true);

-- continue with database_cloning/post_refresh/after_refresh.sql (DEV variant)
