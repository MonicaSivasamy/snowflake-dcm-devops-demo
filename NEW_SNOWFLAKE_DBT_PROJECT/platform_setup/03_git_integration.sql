-- =============================================================================
-- PLATFORM SETUP 03 - connect Snowflake to the Git repository
--                                                     (NOT DCM- or dbt-managed)
-- Both tools read the SAME Git commit:
--   DCM: @ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project
--   dbt: @ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project
-- =============================================================================
use role DCM_DEMO_ADMIN;

create api integration if not exists ENT_DBT_GIT_API
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/MonicaSivasamy/')
    enabled = true
    comment = 'Enterprise dbt + DCM project: read access to GitHub';
-- Private repository / Azure DevOps: see NEW_SNOWFLAKE_DCM_PROJECT/platform_setup/03_git_integration.sql

create git repository if not exists ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO
    api_integration = ENT_DBT_GIT_API
    origin = 'https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo.git'
    comment = 'Enterprise dbt + DCM project: Snowflake copy of the GitHub repository';

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

show git branches in ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO;
ls @ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/;
