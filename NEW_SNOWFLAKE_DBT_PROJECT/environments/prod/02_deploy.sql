-- =============================================================================
-- ENVIRONMENT PROD - deploy                                (runs DCM, then dbt)
-- PROD deploys exactly the release commit that passed QA.
-- Release 1.0.0 = commit 1630b73 on main (both developer PRs merged).
-- ORDER MATTERS: 1. DCM builds containers + security, 2. dbt builds the
-- transformations inside them and attaches the DCM-defined policies.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

-- 1a. DCM PLAN: infrastructure / security changes (creates nothing)
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD
    plan using configuration PROD
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/1630b7335616069c652e38f1c7cd7eb9632fe024/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 1b. DCM DEPLOY (after review). No alias: aliases must be unique per project.
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD
    deploy using configuration PROD
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/1630b7335616069c652e38f1c7cd7eb9632fe024/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- 2a. dbt: PROD runs EXACTLY the dbt version that passed QA - it is copied
--     from the QA project object, not re-read from Git.
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD
    from 'snow://dbt/ENT_DBT_CTRL_DB.PROJECTS.DBT_QA/versions/live/'
    default_target = 'prod'
    comment = 'Enterprise dbt + DCM project - PROD transformations';
-- next release:
-- alter dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD
--     add version from 'snow://dbt/ENT_DBT_CTRL_DB.PROJECTS.DBT_QA/versions/live/';

-- 2b. dbt build = run models + run data tests (stops on a failing test)
--     First deployment: load the source data first (environments/load_sample_source_data.sql).
execute dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD args = 'build --target prod';

-- history
show deployments in dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD;
show versions in dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD;
