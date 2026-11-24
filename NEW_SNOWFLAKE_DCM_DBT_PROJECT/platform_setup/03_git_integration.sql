-- =============================================================================
-- PLATFORM SETUP 03 - connect Snowflake to the Git repository
--                                                     (NOT DCM-managed)
-- Both tools read the SAME Git commit:
--   DCM: @ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/main/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project
--   dbt: @ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/main/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/dbt_project
-- =============================================================================
use role DCM_DEMO_ADMIN;

create api integration if not exists ENT_DCMDBT_GIT_API
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/MonicaSivasamy/')
    enabled = true
    comment = 'Enterprise DCM-with-dbt project: read access to GitHub';
-- Private repository / Azure DevOps: see NEW_SNOWFLAKE_DCM_PROJECT/platform_setup/03_git_integration.sql

create git repository if not exists ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO
    api_integration = ENT_DCMDBT_GIT_API
    origin = 'https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo.git'
    comment = 'Enterprise DCM-with-dbt project: Snowflake copy of the GitHub repository';

alter git repository ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO fetch;

show git branches in ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO;
ls @ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/main/NEW_SNOWFLAKE_DCM_DBT_PROJECT/;
