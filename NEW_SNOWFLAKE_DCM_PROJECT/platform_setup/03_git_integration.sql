-- =============================================================================
-- PLATFORM SETUP 03 - connect Snowflake to the Git repository (NOT DCM-managed)
-- After this, every branch, tag and commit of the repository is readable
-- inside Snowflake under @ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/...
--   branches/"main"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
--   branches/"feature/dev-a-country-codes"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
--   tags/"ent-dcm-v1.0.0"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
--   commits/7c7309b80ac1c5cff181bf9e15bdcf367b9bf74b/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
-- DCM PLAN / DEPLOY read the project directly from those paths.
-- =============================================================================
use role DCM_DEMO_ADMIN;

create api integration if not exists ENT_DCM_GIT_API
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/MonicaSivasamy/')
    enabled = true
    comment = 'Enterprise DCM project: read access to GitHub';
-- Private repository / Azure DevOps: create a secret and reference it, e.g.
--   create secret ENT_DCM_CTRL_DB.GIT.GIT_PAT type = password username = '<user>' password = '<PAT>';
--   ... api_allowed_prefixes = ('https://dev.azure.com/<org>/') allowed_authentication_secrets = (ENT_DCM_CTRL_DB.GIT.GIT_PAT)
--   and add  git_credentials = ENT_DCM_CTRL_DB.GIT.GIT_PAT  to the repository below.

create git repository if not exists ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO
    api_integration = ENT_DCM_GIT_API
    origin = 'https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo.git'
    comment = 'Enterprise DCM project: Snowflake copy of the GitHub repository';

-- Synchronise with GitHub (run after every push / merge; CI does this automatically)
alter git repository ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO fetch;

show git branches in ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO;
show git tags     in ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO;
ls @ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/main/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project/;
