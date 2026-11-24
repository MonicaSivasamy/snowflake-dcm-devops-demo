-- =============================================================================
-- ENVIRONMENT QA - deploy                                (runs DCM, then dbt)
-- QA deploys an immutable release commit, never a moving branch.
-- ORDER MATTERS: 1. DCM builds containers + security, 2. dbt builds the
-- transformations inside them and attaches the DCM-defined policies.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

-- 1a. DCM PLAN: infrastructure / security changes (creates nothing)
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_QA
    plan using configuration QA
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 1b. DCM DEPLOY (after review). No alias: aliases must be unique per project.
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_QA
    deploy using configuration QA
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 2a. dbt: take a new version of the dbt files from the same Git ref
alter dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_QA
    add version from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project';

-- 2b. dbt build = run models + run data tests (stops on a failing test)
execute dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_QA args = 'build --target qa';

-- history
show deployments in dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_QA;
show versions in dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_QA;
