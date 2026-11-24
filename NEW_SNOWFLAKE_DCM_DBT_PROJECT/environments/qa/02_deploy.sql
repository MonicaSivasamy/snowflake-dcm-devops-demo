-- =============================================================================
-- ENVIRONMENT QA - deploy                                (runs DCM, then dbt)
-- QA deploys an immutable release commit, never a moving branch.
-- Release 1.0.0 = commit 6ae5037 on main (both developer PRs merged).
-- ORDER MATTERS: 1. DCM builds containers + security, 2. dbt builds the
-- transformations inside them and attaches the DCM-defined policies.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO fetch;

-- 1a. DCM PLAN: infrastructure / security changes (creates nothing)
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA
    plan using configuration QA
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/commits/6ae5037d3fe51173a6db36f0c9b39c423ff92822/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';

-- 1b. DCM DEPLOY (after review). No alias: aliases must be unique per project.
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA
    deploy using configuration QA
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/commits/6ae5037d3fe51173a6db36f0c9b39c423ff92822/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';

-- 2a. dbt: a dbt project VERSION is an immutable snapshot of the files.
--     dbt project objects accept BRANCH paths only (not commits/<sha>), so the
--     QA version is taken from main while main = the release commit.
--     Recommended in your organisation: cut a protected release branch
--     (release/dbt-dcm-1.0.0) and use  branches/"release/dbt-dcm-1.0.0"  here.
create dbt project if not exists ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_QA
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/main/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/dbt_project'
    default_target = 'qa'
    comment = 'Enterprise DCM-with-dbt project - QA transformations';
-- next release:
-- alter dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_QA
--     add version from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"release/dbt-dcm-1.1.0"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/dbt_project';

-- 2b. dbt build = run models + run data tests (stops on a failing test)
--     First deployment: load the source data first (environments/load_sample_source_data.sql).
-- run dbt (the same command the DCM-managed task RUN_DBT_BUILD contains):
execute dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_QA args = 'build --target qa';
-- once EXECUTE TASK is granted (platform_setup/01) you can run the DCM task instead:
-- execute task DCMDBT_QA_RAW_COMPUTE_DB.COMPUTE.RUN_DBT_BUILD;

-- history
show deployments in dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA;
show versions in dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_QA;
