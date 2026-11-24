-- =============================================================================
-- ENVIRONMENT DEV - deploy                                (runs DCM, then dbt)
-- DEV follows the main branch (every merged pull request).
-- ORDER MATTERS: 1. DCM builds containers + security, 2. dbt builds the
-- transformations inside them and attaches the DCM-defined policies.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

-- 1a. DCM PLAN: infrastructure / security changes (creates nothing)
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV
    plan using configuration DEV
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 1b. DCM DEPLOY (after review). No alias: aliases must be unique per project.
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV
    deploy using configuration DEV
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 2a. dbt: the project object is a versioned copy of the dbt files from Git.
--     First run: CREATE (compiles, so the databases from step 1 must exist).
--     Every later run: ADD VERSION from the same Git ref as the DCM deploy.
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project'
    default_target = 'dev'
    comment = 'Enterprise dbt + DCM project - DEV transformations';

alter dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV
    add version from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project';

-- 2b. dbt build = run models + run data tests (stops on a failing test)
execute dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV args = 'build --target dev';

-- history
show deployments in dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV;
show versions in dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV;
