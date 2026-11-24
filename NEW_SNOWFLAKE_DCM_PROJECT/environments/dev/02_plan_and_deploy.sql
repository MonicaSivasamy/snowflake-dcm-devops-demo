-- =============================================================================
-- ENVIRONMENT DEV - PLAN and DEPLOY from Git                 (runs DCM)
-- DEV always follows the main branch (every merged pull request).
-- Snowsight worksheet alternative to:  snow dcm plan|deploy --target DEV
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

-- 1. synchronise Snowflake with GitHub
alter git repository ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO fetch;

-- 2. PLAN: what would change? (creates/alters/drops nothing)
execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV
    plan using configuration DEV
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/main/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- 3. DEPLOY: apply exactly what the plan showed (after review / approval)
execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV
    deploy as "main"
    using configuration DEV
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/main/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- 4. deployment history of this environment
show deployments in dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV;
