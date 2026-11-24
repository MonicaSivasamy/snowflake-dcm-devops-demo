-- =============================================================================
-- ENVIRONMENT PROD - deploy                                (runs DCM, then dbt)
-- PROD deploys exactly the release commit that passed QA.
-- ORDER MATTERS: 1. DCM builds containers + security, 2. dbt builds the
-- transformations inside them and attaches the DCM-defined policies.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

-- 1a. DCM PLAN: infrastructure / security changes (creates nothing)
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD
    plan using configuration PROD
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 1b. DCM DEPLOY (after review). No alias: aliases must be unique per project.
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD
    deploy using configuration PROD
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 2a. dbt: take a new version of the dbt files from the same Git ref
alter dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD
    add version from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project';

-- 2b. dbt build = run models + run data tests (stops on a failing test)
execute dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD args = 'build --target prod';

-- history
show deployments in dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD;
show versions in dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD;
