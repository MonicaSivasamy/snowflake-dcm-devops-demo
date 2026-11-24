-- =============================================================================
-- ENVIRONMENT QA - PLAN and DEPLOY from Git                 (runs DCM)
-- QA deploys an immutable release TAG, never a moving branch.
-- Snowsight worksheet alternative to:  snow dcm plan|deploy --target QA
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

-- 1. synchronise Snowflake with GitHub
alter git repository ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO fetch;

-- 2. PLAN: what would change? (creates/alters/drops nothing)
execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA
    plan using configuration QA
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/tags/"ent-dcm-v1.0.0"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- 3. DEPLOY: apply exactly what the plan showed (after review / approval)
execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA
    deploy as "ent-dcm-v1.0.0"
    using configuration QA
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/tags/"ent-dcm-v1.0.0"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- 4. deployment history of this environment
show deployments in dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA;
