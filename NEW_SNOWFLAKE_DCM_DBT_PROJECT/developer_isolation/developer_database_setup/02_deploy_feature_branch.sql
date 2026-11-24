-- =============================================================================
-- DATABASE-LEVEL ISOLATION - deploy Developer A's branch  (runs DCM, then dbt)
-- CLI equivalent (local working copy, before pushing):
--   snow dcm deploy --target DEV_A --from NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project
--   snow dbt deploy ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_A --source NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/dbt_project
--   snow dbt execute ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_A build --target dev_a
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO fetch;

-- 1. DCM: re-point the cloned containers / policies / grants to SBX_DCMDBT_DEV_A_*
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_A
    plan using configuration DEV_A
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"feature/dcmdbt-dev-a-country-codes"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_A
    deploy                                     -- no alias: sandboxes redeploy often and aliases must be unique
    using configuration DEV_A
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"feature/dcmdbt-dev-a-country-codes"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';

-- 2. dbt: Developer A's own dbt project object, built from the feature branch
-- first run creates the dbt project object; after further pushes run the
-- commented ALTER ... ADD VERSION instead
create dbt project if not exists ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_A
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"feature/dcmdbt-dev-a-country-codes"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/dbt_project'
    default_target = 'dev_a'
    comment = 'Developer A sandbox - transformations';
-- after further pushes:  alter dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_A add version from '<same path>';

-- run dbt (the same command the DCM-managed task RUN_DBT_BUILD contains):
execute dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_A args = 'build --target dev_a';
-- once EXECUTE TASK is granted (platform_setup/01) you can run the DCM task instead:
-- execute task SBX_DCMDBT_DEV_A_RAW_COMPUTE_DB.COMPUTE.RUN_DBT_BUILD;

select CUSTOMER_ID, COUNTRY from SBX_DCMDBT_DEV_A_RAW_COMPUTE_DB.COMPUTE.CUSTOMER order by 1;
