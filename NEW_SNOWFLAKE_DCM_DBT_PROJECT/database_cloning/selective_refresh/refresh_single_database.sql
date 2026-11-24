-- =============================================================================
-- SELECTIVE REFRESH - one database only               (NOT DCM-managed)
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

-- a) data only: refresh RAW + COMPUTE, keep QA's BUSINESS_DB as is
call ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DCMDBT_PROD', 'DCMDBT_QA', 'RAW_COMPUTE_DB', true);

-- b) business layer only
-- call ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DCMDBT_PROD', 'DCMDBT_QA', 'BUSINESS_DB', true);
--    !! the cloned dbt views still read DCMDBT_PROD_RAW_COMPUTE_DB until dbt
--       rebuilds them -> always run post_refresh/after_refresh.sql

-- c) a developer's databases from shared DEV (developer asked for it)
-- call ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE('DCMDBT_DEV', 'SBX_DBT_DEV_A', 'ALL', true);
--    then redeploy the developer's FEATURE BRANCH (DCM target DEV_A, dbt target dev_a)
