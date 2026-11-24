-- =============================================================================
-- DATABASE-LEVEL ISOLATION - deploy Developer A's branch  (runs DCM, then dbt)
-- CLI equivalent (local working copy, before pushing):
--   snow dcm deploy --target DEV_A --from NEW_SNOWFLAKE_DBT_PROJECT/dcm_project
--   snow dbt deploy ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_A --source NEW_SNOWFLAKE_DBT_PROJECT/dbt_project
--   snow dbt execute ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_A build --target dev_a
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

-- 1. DCM: re-point the cloned containers / policies / grants to SBX_DBT_DEV_A_*
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_A
    plan using configuration DEV_A
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/"feature/dbt-dev-a-country-codes"/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_A
    deploy as "dbt-dev-a-country-codes"
    using configuration DEV_A
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/"feature/dbt-dev-a-country-codes"/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 2. dbt: Developer A's own dbt project object, built from the feature branch
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_A
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/"feature/dbt-dev-a-country-codes"/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project'
    default_target = 'dev_a'
    comment = 'Developer A sandbox - transformations';
-- after further pushes:  alter dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_A add version from '<same path>';

execute dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_A args = 'build --target dev_a';

select CUSTOMER_ID, COUNTRY from SBX_DBT_DEV_A_RAW_COMPUTE_DB.COMPUTE.CUSTOMER order by 1;
