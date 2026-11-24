-- =============================================================================
-- SELECTIVE REFRESH - one database only                        (NOT DCM-managed)
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

-- a) data only: refresh RAW + COMPUTE, keep QA's BUSINESS_DB as is
call ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE('PROD', 'QA', 'RAW_COMPUTE_DB', true);

-- b) business layer only
-- call ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE('PROD', 'QA', 'BUSINESS_DB', true);
--    !! the cloned views still read PROD_RAW_COMPUTE_DB until DCM DEPLOY re-points
--       them to QA_RAW_COMPUTE_DB -> always run post_refresh/after_refresh.sql

-- c) refresh a developer's databases from shared DEV (developer asked for it)
-- call ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE('DEV', 'SBX_DEV_A', 'ALL', true);
--    then redeploy the developer's FEATURE BRANCH (not main) with target DEV_A.
