-- =============================================================================
-- AFTER EVERY REFRESH - restore code and security        (runs DCM, then dbt)
-- A clone copies the SOURCE environment's objects, including names that point
-- to the source (dbt views reading DCMDBT_PROD_RAW_COMPUTE_DB, ...).
--
--   what                               restored by
--   ---------------------------------  ------------------------------------
--   data                               the clone
--   schemas, RAW, COMPUTE.CUSTOMER,    DCM DEPLOY of the target
--   database roles, grants, policies
--   dbt views + policy attachments     dbt build of the target (from Git)
--   account role -> db role            platform_setup/04_account_roles.sql
--   developer WIP                      Git feature branch + redeploy to sandbox
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO fetch;

-- 1. DCM PLAN shows the drift the clone introduced; DEPLOY the release QA was on
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA
    plan using configuration QA
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/commits/8e9ddd0d4a1b1ed83fef75ddfaa3c8f5a16d5545/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA
    deploy as "release-after-refresh"          -- aliases are unique: change per run
    using configuration QA
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/commits/8e9ddd0d4a1b1ed83fef75ddfaa3c8f5a16d5545/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';

-- 2. dbt rebuilds the views against QA and re-attaches the policies
--    (the dbt project object DBT_QA already holds the release version)
-- run dbt (the same command the DCM-managed task RUN_DBT_BUILD contains):
execute dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_QA args = 'build --target qa';
-- once EXECUTE TASK is granted (platform_setup/01) you can run the DCM task instead:
-- execute task DCMDBT_QA_RAW_COMPUTE_DB.COMPUTE.RUN_DBT_BUILD;

-- 3. verify: the business view must read QA, not PROD
select get_ddl('view', 'DCMDBT_QA_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE');

-- 4. security team: re-run platform_setup/04_account_roles.sql with ENV = 'DCMDBT_QA'
