-- =============================================================================
-- AFTER EVERY REFRESH - restore code and security              (runs DCM)
-- A clone copies the SOURCE environment's objects, including names that
-- point to the source (views reading PROD_RAW_COMPUTE_DB, policies checking
-- PROD_* database roles). DCM DEPLOY of the target puts the target's approved
-- code back in place - this is the "code restoration" step.
--
--   what                         restored by
--   ---------------------------  ------------------------------------------
--   data                         the clone (this is the point of the refresh)
--   tables/views/procedures      DCM DEPLOY of the target (from Git)
--   database roles, grants,      DCM DEPLOY of the target (they are in the
--   masking / row access policies  DCM project under security/)
--   account role -> db role      platform_setup/04_account_roles.sql
--   developer WIP                Git feature branch + redeploy to the sandbox
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO fetch;

-- 1. PLAN shows the drift the clone introduced (expect ALTERs, no drops)
execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA
    plan using configuration QA
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/tags/"ent-dcm-v1.0.0"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- 2. DEPLOY the same release tag QA was on before the refresh
execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA
    deploy as "ent-dcm-v1.0.0 (after refresh)"
    using configuration QA
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/tags/"ent-dcm-v1.0.0"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- 3. verify: the business view must read QA, not PROD
select get_ddl('view', 'QA_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE');

-- 4. security team: re-run platform_setup/04_account_roles.sql with ENV = 'QA'
